import {getAds,getAdSets,insights,insightsRange,setStatus,updateAdSetBudget} from './meta.js';
import {getSettings,getPosts,getLogs,addLog,getTenant} from './store.js';
import {config} from './config.js';
import {earlyAdDecision} from './rules.js';
import {learnFromOutcome} from './ai-memory.js';
import {recordPerformance,metaInsightToPerformance} from './performance-memory.js';
import {withTenantLock} from './persistence.js';
import {tenantCredentials,metaReady,minorToMoney,budgetGuard,withAdAccountLock} from './automation-safety.js';

const n=v=>Number.isFinite(Number(v))?Number(v):0;
function messageCount(row) {
  const values=(row?.actions||[])
    .filter(a=>config.messageActionTypes.includes(a.action_type))
    .map(a=>Math.max(0,n(a.value)));
  return values.length?Math.max(...values):0;
}
function metric(row) {
  const spend=n(row?.spend), messages=messageCount(row), ctr=n(row?.ctr);
  return {spend,messages,ctr,cpc:n(row?.cpc),cpm:n(row?.cpm),messageCost:messages>0?spend/messages:null};
}
function score(m,settings) {
  const costScore=m.messageCost==null?0.25:1/(1+m.messageCost);
  const ctrScore=Math.min(1,m.ctr/3);
  const msgScore=Math.min(1,m.messages/20);
  return costScore*settings.selection.messageCostWeight+ctrScore*settings.selection.ctrWeight+msgScore*settings.selection.messagesWeight+settings.selection.explorationWeight;
}
function safeMetaResult(value) {
  if (value == null) return {status:'NOT_CALLED'};
  if (typeof value !== 'object') return {status:'COMPLETED'};
  return {status:'SUCCESS',id:value.id||null,success:value.success===true};
}
export function optimizationPermissionState(settings={},accountId='',mode='CONTINUOUS') {
  const permission=String(settings.optimizationPermission||'OFF').toUpperCase();
  const selected=Array.isArray(settings.optimizationAdAccountIds)
    ? settings.optimizationAdAccountIds.map(x=>String(x).replace(/^act_/,'').trim()) : [];
  const requested=String(mode||'CONTINUOUS').toUpperCase();
  if(!['ONE_TIME','CONTINUOUS'].includes(requested))return {allowed:false,reason:'INVALID_MODE'};
  if(requested==='CONTINUOUS'&&permission!=='CONTINUOUS')return {allowed:false,reason:'CONTINUOUS_PERMISSION_REQUIRED'};
  if(requested==='ONE_TIME'&&!['ONE_TIME','CONTINUOUS'].includes(permission))return {allowed:false,reason:'ONE_TIME_PERMISSION_REQUIRED'};
  if(!accountId||!selected.includes(String(accountId).replace(/^act_/,'').trim()))return {allowed:false,reason:'ACCOUNT_NOT_SELECTED'};
  return {allowed:true,permission,accountId:String(accountId).replace(/^act_/,'').trim()};
}
export function reviewDue(lastReviewAt,now=Date.now(),intervalHours=12) {
  const last=Date.parse(lastReviewAt||'');
  return !Number.isFinite(last)||(Number(now)-last)>=Math.max(1,Number(intervalHours)||12)*3600000;
}

async function optimizeAdsLocked(tenantId='system',options={}) {
  const settings=await getSettings(tenantId);
  const tenant=await getTenant(tenantId);
  const credentials=tenantCredentials(tenantId,tenant);
  const requestedMode=String(options.mode||'CONTINUOUS').toUpperCase();
  const accountId=String(credentials?.adAccountId||'').replace(/^act_/,'').trim();
  const permission=optimizationPermissionState(settings,accountId,requestedMode);
  if (!permission.allowed) return {enabled:false,mode:'BLOCKED',actions:[],reason:permission.reason};

  const metaToken=String(credentials?.accessToken || credentials?.metaAccessToken || config.metaAccessToken || '').trim();
  const adAccountId=String(credentials?.adAccountId || config.adAccountId || '').replace(/^act_/,'').trim();
  if(!metaReady(credentials)) {
    const posts=await getPosts(tenantId);
    return {
      enabled:true,
      mode:'PLANNING',
      actions:[{
        action:'WAIT_META_CONNECTION',
        reason:'Meta erişim tokenı veya reklam hesabı hazır değil.'
      }],
      postsConsidered:posts.length,
      rule:'12h_message_cost'
    };
  }

  const [adsResp,setsResp,posts,logs]=await Promise.all([getAds(credentials),getAdSets(credentials),getPosts(tenantId),getLogs(tenantId,1000)]);
  const ads=adsResp.data||[], adsets=setsResp.data||[], setMap=new Map(adsets.map(x=>[x.id,x]));
  const results=[];
  const launchByAd=new Map();
  for(const l of logs) if(l.type==='WEEKLY_LAUNCH'&&l.adId&&l.launchAt) launchByAd.set(l.adId,l);
  const lastReviewByAd=new Map();
  for(const log of logs.filter(x=>x.type==='EARLY_REVIEW_DONE'&&x.adId)) {
    const at=Date.parse(log.reviewedAt||log.at||'');
    const old=lastReviewByAd.get(String(log.adId));
    if(Number.isFinite(at)&&(!old||at>old))lastReviewByAd.set(String(log.adId),at);
  }

  for(const ad of ads) {
    if(ad.status!=='ACTIVE') continue;
    try {
      const launch=launchByAd.get(ad.id) || (
        ad.created_time ? {adId:ad.id,launchAt:ad.created_time,source:'META_CREATED_TIME'} : null
      );
      if(!launch) { results.push({adId:ad.id,name:ad.name,action:'WAIT_NO_LAUNCH_RECORD'}); continue; }
      const launchAt=new Date(launch.launchAt);
      if(!Number.isFinite(launchAt.getTime())) {
        results.push({adId:ad.id,name:ad.name,action:'WAIT_INVALID_LAUNCH_TIME'}); 
        continue;
      }
      const ageHours=(Date.now()-launchAt.getTime())/3600000;
      if(ageHours < Number(settings.earlyWindowHours||12)) {
        results.push({adId:ad.id,name:ad.name,action:'WAIT_12H',hoursElapsed:Number(ageHours.toFixed(2))});
        continue;
      }
      const lastReview=lastReviewByAd.get(String(ad.id));
      if(lastReview && !reviewDue(new Date(lastReview).toISOString(),Date.now(),Number(settings.earlyWindowHours||12))) {
        results.push({adId:ad.id,name:ad.name,action:'WAIT_REVIEW_INTERVAL'}); continue;
      }

      const since=new Date(launchAt.getTime()-60000);
      const ir=await insightsRange(ad.id,'ad',since,new Date(),credentials);
      const row=(ir.data||[])[0];
      const m=metric(row);
      const measuredAt=new Date().toISOString();
      const linkedPost=launch.postId?posts.find(post=>String(post.id)===String(launch.postId)):null;
      await recordPerformance(tenantId,metaInsightToPerformance(row,{
        key:'META_AD:'+ad.id+':'+since.toISOString()+':'+measuredAt,
        mode:'PAID',
        timestamp:launch.launchAt,
        measuredAt,
        timeRange:{start:since.toISOString(),end:measuredAt},
        postId:launch.postId||null,
        campaignId:ad.campaign_id||null,
        adsetId:ad.adset_id||null,
        adId:ad.id,
        mediaType:linkedPost?.mediaType||null,
        creativeType:linkedPost?.format||linkedPost?.mediaType||null
      }));
      const decision=earlyAdDecision(m,settings);
      if (decision.action==='WAIT') {
        results.push({adId:ad.id,name:ad.name,action:'WAIT_MIN_SPEND',metrics:m,reason:decision.reason});
        continue;
      }
      let previousBudget=null,newBudget=null,statusResult=null,budgetResult=null;
      if(decision.action==='REDUCE' && settings.autoPause !== false) {
        const set=setMap.get(ad.adset_id);
        let released=0;
        if(set) {
          const current=minorToMoney(set.daily_budget);
          previousBudget=current;
          const keep=Math.min(current,Number(settings.minDailyBudget));
          released=Math.max(0,current-keep);
          if(released>0) {
            budgetResult=await updateAdSetBudget(set.id,keep,credentials);
            newBudget=keep;
            set.daily_budget=Math.round(keep*100);
          }
        }
        statusResult=await setStatus(ad.id,'PAUSED',credentials);
        results.push({adId:ad.id,name:ad.name,action:'PAUSED_12H',metrics:m,reason:decision.reason,releasedBudget:released});
        if(released>0 && settings.autoReallocate) {
          const candidates=[];
          for(const other of ads) {
            if(other.id===ad.id||other.status!=='ACTIVE') continue;
            try {
              const oir=await insights(other.id,'ad',1,credentials); const om=metric((oir.data||[])[0]);
              if(om.messageCost!==null && om.messageCost < Number(settings.earlyMessageCostLimit||2)) {
                candidates.push({ad:other,metrics:om,score:score(om,settings)});
              }
            } catch {}
          }
          candidates.sort((a,b)=>b.score-a.score);
          const best=candidates[0];
          if(best) {
            const bestSet=setMap.get(best.ad.adset_id);
            if(bestSet) {
              const before=minorToMoney(bestSet.daily_budget);
              const after=Math.min(Number(settings.maxDailyBudget),before+released);
              const actual=Math.max(0,after-before);
              if(actual>0) {
                await budgetGuard(credentials,settings,{adSetId:bestSet.id,nextBudget:after});
                const transferResult=await updateAdSetBudget(bestSet.id,after,credentials);
                bestSet.daily_budget=Math.round(after*100);
                results.push({adId:best.ad.id,name:best.ad.name,action:'BUDGET_TRANSFERRED',transferredBudget:actual,fromAdId:ad.id,previousBudget:before,newDailyBudget:after,metaApi:safeMetaResult(transferResult)});
              }
            }
          }
        }
      } else if(decision.action==='REDUCE' && settings.autoPause === false) {
        results.push({
          adId:ad.id,
          name:ad.name,
          action:'PAUSE_DISABLED',
          metrics:m,
          reason:'Mesaj maliyeti/mesaj sayısı kuralı durdurma eşiğine ulaştı ancak otomatik durdurma kapalı.'
        });
      } else {
        results.push({adId:ad.id,name:ad.name,action:'KEEP_12H',metrics:m,reason:decision.reason});
      }
      await addLog(tenantId,{type:'AD_OPTIMIZATION_DECISION',adId:ad.id,adSetId:ad.adset_id||null,mode:requestedMode,reason:decision.reason,decision:results.at(-1)?.action||decision.action,previousBudget,newBudget,metaApi:{statusResult:safeMetaResult(statusResult),budgetResult:safeMetaResult(budgetResult)},metrics:m,at:new Date().toISOString()});
      await addLog(tenantId,{
        type:'EARLY_REVIEW_DONE',
        adId:ad.id,
        reviewedAt:new Date().toISOString(),
        decision:(decision.action==='REDUCE' && settings.autoPause === false) ? 'PAUSE_DISABLED' : decision.action,
        metrics:m,previousBudget,newBudget
      });
      if (launch.postId) {
        await learnFromOutcome(tenantId, {
          postId: launch.postId,
          adId: ad.id,
          spend: m.spend,
          messages: m.messages,
          ctr: m.ctr,
          messageCost: m.messageCost,
          optimizationDecision: decision.action,
          optimizationReason: decision.reason,
          previousBudget,
          newBudget,
          metaApiStatus: statusResult ? safeMetaResult(statusResult).status : (budgetResult ? safeMetaResult(budgetResult).status : 'NOT_CALLED')
        });
      }
    } catch(e) { results.push({adId:ad.id,name:ad.name,action:'ERROR',reason:e.message,metaApi:{status:'ERROR'}}); await addLog(tenantId,{type:'AD_OPTIMIZATION_DECISION',adId:ad.id,mode:requestedMode,decision:'ERROR',reason:e.message,metaApi:{status:'ERROR'},at:new Date().toISOString()}); }
  }
  const result={enabled:true,ranAt:new Date().toISOString(),actions:results,postsConsidered:posts.length,rule:'12h_message_cost'};
  await addLog(tenantId,result); return result;
}

export async function optimizeAds(tenantId='system',options={}) { return withTenantLock(tenantId,()=>withAdAccountLock(tenantId,()=>optimizeAdsLocked(tenantId,options))); }

export function selectBestPost(posts,performanceByPost={}) {
  if(!posts.length) return null;
  return posts.map(p=>{const m=performanceByPost[p.id]||{},messages=n(m.messages),cost=n(m.messageCost),engagement=n(m.engagement);return {...p,_score:(messages*3)+(engagement*.5)+(cost>0?100/cost:0)};}).sort((a,b)=>b._score-a._score)[0];
}
