import cron from 'node-cron';
import {getSettings,getPosts,getLogs,addLog,savePosts,getTenants,getTenant} from './store.js';
import {createCampaign,createAdSet,uploadAdImage,createAdCreative,createAdCreativeFromInstagramMedia,createAd,setStatus,instagramPublishMedia,getInstagramContainerStatus,resolveAdGeoTargeting,resolveCredentials} from './meta.js';
import {config} from './config.js';
import {seedTimeScore} from './rules.js';
import {optimizeAds} from './optimizer.js';
import {runGeminiAdReview} from './gemini-ads.js';
import fs from 'node:fs/promises';
import path from 'node:path';
import {withDataLock} from './persistence.js';
import {tenantCredentials,metaReady,budgetGuard} from './automation-safety.js';

function localParts(date=new Date()) {
  const parts=new Intl.DateTimeFormat('en-GB',{timeZone:config.timezone,weekday:'short',hour:'2-digit',minute:'2-digit',hour12:false}).formatToParts(date);
  const get=t=>parts.find(x=>x.type===t)?.value;
  const map={Mon:1,Tue:2,Wed:3,Thu:4,Fri:5,Sat:6,Sun:7};
  return {day:map[get('weekday')],hour:Number(get('hour')),minute:Number(get('minute'))};
}
function weekKey(date=new Date()) {
  const p=localParts(date);
  const d=new Intl.DateTimeFormat('en-CA',{timeZone:config.timezone,year:'numeric',month:'2-digit',day:'2-digit'}).format(date);
  return `${d}-d${p.day}`;
}
function chooseBestStart(settings,logs) {
  const fallback={day:settings.weeklyDay,hour:settings.startHour,minute:settings.startMinute};
  if(!settings.autoBestTime) return fallback;

  const launches=logs.filter(x=>x.type==='WEEKLY_LAUNCH'&&x.launchAt);
  if(launches.length<4) return fallback;

  const launchByAd=new Map(launches.filter(x=>x.adId).map(x=>[x.adId,x]));
  const buckets=new Map();

  const addBucket=(day,hour,score)=>{
    const key=`${day}-${hour}`;
    const old=buckets.get(key)||{count:0,score:0};
    old.count++;
    old.score+=Number(score)||0;
    buckets.set(key,old);
  };

  // Existing launch history provides a fallback learning signal.
  for(const launch of launches) {
    const p=localParts(new Date(launch.launchAt||launch.at));
    if(!p.day||!Number.isFinite(p.hour)) continue;
    const score=Number(launch.selectionScore||0) || seedTimeScore(p.day,p.hour);
    addBucket(p.day,p.hour,score);
  }

  // Once 12-hour reviews exist, prefer real performance over the seeded time model.
  for(const review of logs.filter(x=>x.type==='EARLY_REVIEW_DONE'&&x.adId&&x.metrics)) {
    const launch=launchByAd.get(review.adId);
    if(!launch) continue;

    const p=localParts(new Date(launch.launchAt));
    const m=review.metrics||{};
    const cost=m.messageCost==null ? null : Number(m.messageCost);
    const ctr=Math.max(0,Number(m.ctr||0));
    const messages=Math.max(0,Number(m.messages||0));

    const costScore=cost==null ? 0.25 : 1/(1+Math.max(0,cost));
    const ctrScore=Math.min(1,ctr/3);
    const messageScore=Math.min(1,messages/20);
    const score=
      costScore*0.55+
      ctrScore*0.20+
      messageScore*0.20+
      seedTimeScore(p.day,p.hour)*0.05;

    addBucket(p.day,p.hour,score);
  }

  let best=null;
  for(const [key,v] of buckets) {
    if(v.count<2) continue;
    const [day,hour]=key.split('-').map(Number);
    const score=v.score/v.count;
    if(!best||score>best.score) best={day,hour,score};
  }

  return best
    ? {day:best.day,hour:best.hour,minute:settings.startMinute}
    : fallback;
}
function nextOccurrence({day,hour,minute}) {
  const now=new Date();
  // Search minute-by-minute so the comparison is made in the configured
  // Europe/Istanbul timezone rather than the server OS timezone.
  for(let i=1;i<=7*24*60;i++) {
    const candidate=new Date(now.getTime()+i*60000);
    const p=localParts(candidate);
    if(p.day===day && p.hour===hour && p.minute===minute) return candidate;
  }
  return new Date(now.getTime()+7*86400000);
}

export async function scheduleUploadedPosts(posts, tenantId='system', requestedTime='') {
  const settings=await getSettings(tenantId);
  const logs=await getLogs(tenantId,500);
  const existing=await getPosts(tenantId);
  const start=chooseBestStart(settings,logs);
  let cursor=nextOccurrence(start);
  if (requestedTime) {
    const requested = new Date(requestedTime);
    if (!Number.isFinite(requested.getTime()) || requested.getTime() <= Date.now()) {
      throw new Error('Planlanan paylaşım zamanı gelecekte olmalı.');
    }
    cursor = requested;
  }

  const futureQueued=existing
    .filter(x => ['QUEUED','RETRY'].includes(x.publishStatus) && x.nextPublishAt && new Date(x.nextPublishAt).getTime() > Date.now())
    .map(x => new Date(x.nextPublishAt))
    .filter(d => !Number.isNaN(d.getTime()))
    .sort((a,b)=>a-b);

  if(futureQueued.length && !requestedTime) {
    const latest=futureQueued[futureQueued.length-1];
    if(latest.getTime() >= cursor.getTime()) cursor=new Date(latest.getTime()+86400000);
  }

  for(const post of posts) {
    post.publishStatus='QUEUED';
    post.autoPublish=post.autoPublish !== false;
    post.publishAttempts=Number(post.publishAttempts||0);
    post.publishMaxRetries=Number(settings.publishMaxRetries||3);
    post.nextPublishAt=cursor.toISOString();
    post.selectedTime={...localParts(cursor),timezone:config.timezone,scheduledAt:post.nextPublishAt};
    cursor=new Date(cursor.getTime()+86400000);
  }
  return posts;
}

export async function scheduleUploadedPost(post, tenantId='system', requestedTime='') {
  const result=await scheduleUploadedPosts([post],tenantId,requestedTime);
  return result[0];
}

export async function publishPost(tenantId,postId,{manual=false}={}) {
  return withDataLock(async()=>{
    const posts=await getPosts(tenantId);
    const post=posts.find(row=>row.id===postId);
    if(!post) throw new Error('İçerik bulunamadı.');
    if(post.publishStatus==='PUBLISHED') return post;
    const tenant=await getTenant(tenantId);
    const credentials=tenantCredentials(tenantId,tenant);
    if(!/^https:\/\//i.test(String(post.publicUrl||''))) throw new Error('Instagram paylaşımı için medya HTTPS üzerinden erişilebilir olmalı.');
    if(post.instagramContainerId && ['SUBMITTING','RECONCILE'].includes(post.publishPhase)) {
      let state;
      try { state=await getInstagramContainerStatus(post.instagramContainerId,credentials); }
      catch { throw new Error('Önceki yayının sonucu doğrulanamadı. Çift paylaşımı önlemek için Instagram hesabınızı kontrol edin.'); }
      const status=String(state.status_code||state.status||'').toUpperCase();
      if(status==='PUBLISHED') {
        post.publishStatus='PUBLISHED';post.publishPhase='CONFIRMED';post.publishedAt=new Date().toISOString();post.publishError='';
        await savePosts(tenantId,posts);
        await addLog(tenantId,{type:'INSTAGRAM_POST_PUBLISHED',postId:post.id,reconciled:true});
        return post;
      }
      if(status!=='FINISHED') throw new Error('Önceki yayın henüz doğrulanamadı. İçeriği tekrar paylaşmadan önce Instagram hesabınızı kontrol edin.');
    }
    post.publishStatus='PUBLISHING';post.publishPhase='PREPARING';post.publishAttempts=Number(post.publishAttempts||0)+1;
    post.publishStartedAt=new Date().toISOString();post.publishError='';
    await savePosts(tenantId,posts);
    try {
      const result=await instagramPublishMedia({
        mediaType:post.mediaType||'POST',imageUrl:post.publicUrl,videoUrl:post.publicUrl,caption:post.caption||'',
        coverUrl:post.coverPublicUrl||'',thumbOffset:post.coverThumbOffset,credentials,containerId:post.instagramContainerId||'',
        onContainer:async id=>{post.instagramContainerId=String(id);post.publishPhase='PREPARED';await savePosts(tenantId,posts);},
        onBeforePublish:async()=>{post.publishPhase='SUBMITTING';await savePosts(tenantId,posts);}
      });
      post.publishStatus='PUBLISHED';post.publishPhase='CONFIRMED';post.publishedAt=new Date().toISOString();
      post.instagramPublishResult=result;post.instagramMediaId=String(result.id);post.publishError='';
      await savePosts(tenantId,posts);
      await addLog(tenantId,{type:'INSTAGRAM_POST_PUBLISHED',postId:post.id,mediaType:post.mediaType||'POST',attempt:post.publishAttempts,manual});
      return post;
    } catch(error) {
      const settings=await getSettings(tenantId);
      post.publishError=error.message;
      if(post.publishPhase==='SUBMITTING') {
        post.publishStatus='RECONCILE';post.publishPhase='RECONCILE';
      } else if(post.publishAttempts<Number(post.publishMaxRetries||settings.publishMaxRetries||3)) {
        post.publishStatus='RETRY';post.nextPublishAt=new Date(Date.now()+Number(settings.publishRetryMinutes||10)*60000*Math.min(4,post.publishAttempts)).toISOString();
      } else post.publishStatus='ERROR';
      await savePosts(tenantId,posts);
      await addLog(tenantId,{type:'INSTAGRAM_POST_ERROR',postId:post.id,error:error.message,attempt:post.publishAttempts,status:post.publishStatus});
      throw error;
    }
  });
}

async function publishDuePostsLocked(tenantId='system') {
  const settings=await getSettings(tenantId);
  if(!settings.autoPublish) return {published:0,reason:'autoPublish disabled'};
  const posts=await getPosts(tenantId);
  let published=0;
  for(const post of posts) {
    if(!['QUEUED','RETRY','PUBLISHING'].includes(post.publishStatus)||!post.nextPublishAt||post.autoPublish===false) continue;
    if(new Date(post.nextPublishAt)>new Date()) continue;
    try {
      const result=await publishPost(tenantId,post.id);if(result.publishStatus==='PUBLISHED')published++;
    } catch {}
  }
  return {published};
}

export async function publishDuePosts(tenantId='system') { return withDataLock(()=>publishDuePostsLocked(tenantId)); }

async function weeklySchedulerTickLocked(tenantId='system') {
  const settings=await getSettings(tenantId);
  const tenant=await getTenant(tenantId);
  const credentials=resolveCredentials(tenantCredentials(tenantId,tenant));
  if(!settings.enabled) return {scheduled:false,reason:'disabled'};
  const metaToken=String(credentials?.accessToken || credentials?.metaAccessToken || config.metaAccessToken || '').trim();
  const adAccountId=String(credentials?.adAccountId || config.adAccountId || '').replace(/^act_/,'').trim();
  if(!metaReady(credentials)) return {scheduled:false,reason:'Meta bağlantısı bekleniyor',mode:'PLANNING'};
  const logs=await getLogs(tenantId,500);
  const schedule=chooseBestStart(settings,logs), now=localParts();
  if(now.day!==schedule.day||now.hour!==schedule.hour||now.minute!==schedule.minute) return {scheduled:false};
  const currentWeek=weekKey();
  if(logs.some(x=>['WEEKLY_LAUNCH','WEEKLY_LAUNCH_STARTED'].includes(x.type)&&x.week===currentWeek)) return {scheduled:false,reason:'already launched or awaiting verification',week:currentWeek};
  const posts=await getPosts(tenantId);
  if(!posts.length) return {scheduled:false,reason:'No posts uploaded'};
  const sorted=[...posts].sort((a,b)=>Number(b.performanceScore||0)-Number(a.performanceScore||0)||new Date(b.createdAt)-new Date(a.createdAt));
  const post=sorted[0];
  const dailyBudget=Math.max(settings.minDailyBudget,Math.min(settings.maxDailyBudget,settings.weeklyBudget/Math.max(1,settings.durationHours/24)));
  try {
    await budgetGuard(credentials,settings,{nextBudget:dailyBudget,creating:true});
    const audience=await resolveAdGeoTargeting(settings.adTargetingMode,settings.adTargetingLocations,credentials);
    await addLog(tenantId,{type:'WEEKLY_LAUNCH_STARTED',week:currentWeek,postId:post.id});
    const campaign=await createCampaign({name:`Advise Digital Weekly ${currentWeek}`,objective:'OUTCOME_ENGAGEMENT',status:'PAUSED',credentials});
    const adset=await createAdSet({name:`Weekly ${post.title||post.id}`,campaignId:campaign.id,dailyBudget,targeting:{geo_locations:audience.geo_locations},destinationType:'WHATSAPP',optimizationGoal:'CONVERSATIONS',billingEvent:'IMPRESSIONS',instagramActorId:credentials.instagramUserId,pageId:credentials.pageId,credentials});
    const instagramMediaId=String(post.instagramMediaId||post.instagramPublishResult?.id||'').trim();
    let creative;
    if(instagramMediaId) {
      creative=await createAdCreativeFromInstagramMedia({
        name:`Creative ${post.title||post.id}`,
        instagramMediaId,
        instagramUserId:credentials.instagramUserId||config.instagramUserId,
        pageId:credentials.pageId,
        credentials
      });
    } else {
      const buffer=await fs.readFile(path.resolve(post.filePath));
      const upload=await uploadAdImage(buffer,path.basename(post.filePath),credentials);
      const imageHash=upload?.images?Object.values(upload.images)[0]?.hash:upload?.hash;
      if(!imageHash) throw new Error('Meta image upload hash alınamadı.');
      creative=await createAdCreative({
        name:`Creative ${post.title||post.id}`,
        instagramActorId:credentials.instagramUserId||config.instagramUserId,
        pageId:credentials.pageId,
        imageHash,
        message:post.caption||post.title||'',
        linkUrl:post.linkUrl||'https://instagram.com/',
        credentials
      });
    }
    const ad=await createAd({name:`Ad ${post.title||post.id}`,adsetId:adset.id,creativeId:creative.id,status:'PAUSED',credentials});
    await budgetGuard(credentials,settings,{adSetId:adset.id,activate:true});
    await setStatus(ad.id,'ACTIVE',credentials);
    await setStatus(campaign.id,'ACTIVE',credentials);
    await setStatus(adset.id,'ACTIVE',credentials);
    const selectionScore=Number(post.performanceScore||0);
    const launchAt=new Date().toISOString();
    const result={scheduled:true,campaignId:campaign.id,adsetId:adset.id,adId:ad.id,postId:post.id,week:currentWeek,selectionScore,schedule,launchAt};
    await addLog(tenantId,{type:'WEEKLY_LAUNCH',...result});
    return result;
  } catch(e) { await addLog(tenantId,{type:'WEEKLY_LAUNCH_ERROR',error:e.message,postId:post.id,week:currentWeek}); return {scheduled:false,error:e.message}; }
}

export async function weeklySchedulerTick(tenantId='system') { return withDataLock(()=>weeklySchedulerTickLocked(tenantId)); }

export function startScheduler() {
  if(!config.cronEnabled) return;
  const every=Math.max(1,Math.min(59,config.cronEveryMinutes));
  cron.schedule(`*/${every} * * * *`,async()=>{
    try {
      const tenants=await getTenants();
      for(const tenant of tenants) {
        if(!tenant.active || (tenant.subscriptionEnd && new Date(tenant.subscriptionEnd).getTime()<Date.now())) continue;
        if(tenant.id !== 'system' && !tenant.meta?.connected) continue;
        await publishDuePosts(tenant.id);
        // The 12-hour ad decision engine must run from the scheduler as well;
        // the manual /api/automation/run endpoint is not sufficient for SaaS automation.
        if (tenant.id === 'system' || tenant.meta?.connected) await optimizeAds(tenant.id);
        if (tenant.id === 'system' || tenant.meta?.connected) await runGeminiAdReview(tenant.id);
        await weeklySchedulerTick(tenant.id);
      }
    } catch(e) { console.error('[SCHEDULER]',e.message); }
  });
}
