import {config} from './config.js';

const base=`https://graph.facebook.com/${config.metaApiVersion}`;

function resolveCredentials(credentials={}) {
  return {
    accessToken: String(credentials?.accessToken || config.metaAccessToken || '').trim(),
    adAccountId: String(credentials?.adAccountId || config.adAccountId || '').replace(/^act_/, '').trim(),
    instagramUserId: String(credentials?.instagramUserId || config.instagramUserId || '').trim(),
    pageId: String(credentials?.pageId || '').trim(),
    instagramAccessToken: String(credentials?.instagramAccessToken || config.instagramAccessToken || '').trim()
  };
}

function requireMeta(credentials={}) {
  const c=resolveCredentials(credentials);
  if(!c.accessToken || !c.adAccountId) throw new Error('Meta bağlantısı için erişim tokenı ve reklam hesabı gerekli.');
  return c;
}

function parse(text) { try { return JSON.parse(text); } catch { return {raw:text}; } }

async function request(path,{method='GET',query={},body={},credentials={}}={}) {
  const c=requireMeta(credentials);
  const url=new URL(`${base}/${String(path).replace(/^\/+/, '')}`);
  const params={...query};
  if(method==='GET') params.access_token=c.accessToken;
  for(const [k,v] of Object.entries(params)) if(v!==undefined&&v!==null) url.searchParams.set(k,String(v));

  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),30000);
  try {
    const options={method,signal:controller.signal,headers:{accept:'application/json'}};
    if(method!=='GET'){
      options.headers['content-type']='application/x-www-form-urlencoded';
      options.body=new URLSearchParams({
        access_token:c.accessToken,
        ...Object.fromEntries(Object.entries(body).map(([k,v])=>[k,typeof v==='object' ? JSON.stringify(v) : String(v)]))
      });
    }
    const r=await fetch(url,options);
    const data=parse(await r.text());
    if(!r.ok||data.error) throw new Error(`Meta API ${r.status}: ${data?.error?.message||JSON.stringify(data)}`);
    return data;
  } catch(e) {
    if(e.name==='AbortError') throw new Error('Meta API timeout.');
    throw e;
  } finally { clearTimeout(timeout); }
}

export async function getCampaigns(credentials={}) {
  const c=requireMeta(credentials);
  return request(`act_${c.adAccountId}/campaigns`,{credentials:c,query:{fields:'id,name,status,effective_status,objective,daily_budget,lifetime_budget,start_time,stop_time',limit:200}});
}

export async function getAdSets(credentials={}) {
  const c=requireMeta(credentials);
  return request(`act_${c.adAccountId}/adsets`,{credentials:c,query:{fields:'id,name,status,effective_status,campaign_id,daily_budget,lifetime_budget,optimization_goal,billing_event,targeting,start_time,end_time',limit:500}});
}

export async function getAds(credentials={}) {
  const c=requireMeta(credentials);
  return request(`act_${c.adAccountId}/ads`,{credentials:c,query:{fields:'id,name,status,effective_status,campaign_id,adset_id,created_time,creative{id,name,object_story_id,thumbnail_url,effective_instagram_media_id,source_instagram_media_id}',limit:500}});
}

export async function insights(id,level='ad',days=7,credentials={}) {
  const until=new Date();
  const since=new Date(Date.now()-Math.max(1,days)*86400000);
  return insightsRange(id,level,since,until,credentials);
}

export async function insightsRange(id,level='ad',since,until=new Date(),credentials={}) {
  const f=d=>d.toISOString().slice(0,10);
  return request(`${id}/insights`,{credentials,query:{fields:'spend,impressions,reach,clicks,ctr,cpc,cpm,actions,cost_per_action_type,purchase_roas',time_range:JSON.stringify({since:f(since),until:f(until)}),level}});
}

export async function setStatus(id,status,credentials={}) {
  if(!['ACTIVE','PAUSED'].includes(status)) throw new Error('Status ACTIVE/PAUSED olmalı.');
  return request(id,{method:'POST',credentials,body:{status}});
}

export async function updateAdSetBudget(id,dailyBudget,credentials={}) {
  const n=Math.round(Number(dailyBudget));
  if(!Number.isFinite(n)||n<=0) throw new Error('Geçersiz daily budget.');
  return request(id,{method:'POST',credentials,body:{daily_budget:n}});
}

export async function createCampaign({name,objective='OUTCOME_ENGAGEMENT',status='PAUSED',credentials={}}) {
  const c=requireMeta(credentials);
  return request(`act_${c.adAccountId}/campaigns`,{method:'POST',credentials:c,body:{name,objective,status,special_ad_categories:[]}});
}

export async function createAdSet({name,campaignId,dailyBudget,targeting,optimizationGoal='CONVERSATIONS',billingEvent='IMPRESSIONS',instagramActorId,pageId,credentials={}}) {
  const c=requireMeta(credentials);
  const body={name,campaign_id:campaignId,daily_budget:Math.round(dailyBudget),billing_event:billingEvent,optimization_goal:optimizationGoal,bid_strategy:'LOWEST_COST_WITHOUT_CAP',targeting:targeting||{geo_locations:{countries:['TR']}},status:'PAUSED'};
  if(pageId||c.pageId) body.promoted_object={page_id:pageId||c.pageId};
  return request(`act_${c.adAccountId}/adsets`,{method:'POST',credentials:c,body});
}

export async function uploadAdImage(fileBuffer,fileName,credentials={}) {
  const c=requireMeta(credentials);
  const url=`${base}/act_${c.adAccountId}/adimages`;
  const blob=new Blob([fileBuffer],{type:'image/jpeg'});
  const form=new FormData();
  form.append('access_token',c.accessToken);
  form.append('filename',blob,fileName);
  const r=await fetch(url,{method:'POST',body:form});
  const data=parse(await r.text());
  if(!r.ok||data.error) throw new Error(`Meta image upload ${r.status}: ${data?.error?.message||JSON.stringify(data)}`);
  return data;
}

export async function createAdCreative({name,instagramActorId,pageId,imageHash,message,linkUrl,credentials={}}) {
  const c=requireMeta(credentials);
  const objectStorySpec={link_data:{image_hash:imageHash,message,link:linkUrl||'https://instagram.com/'}};
  const actor=instagramActorId||c.instagramUserId;
  const page=pageId||c.pageId;
  if(actor) objectStorySpec.instagram_user_id=actor;
  if(page) objectStorySpec.page_id=page;
  return request(`act_${c.adAccountId}/adcreatives`,{method:'POST',credentials:c,body:{name,object_story_spec:objectStorySpec}});
}

export async function createAd({name,adsetId,creativeId,status='PAUSED',credentials={}}) {
  const c=requireMeta(credentials);
  return request(`act_${c.adAccountId}/ads`,{method:'POST',credentials:c,body:{name,adset_id:adsetId,creative:{creative_id:creativeId},status}});
}

const igBase='https://graph.instagram.com';

async function instagramRequest(path,{method='GET',body={},accessToken}={}) {
  if(!accessToken) throw new Error('Instagram access token bulunamadı.');
  const url=new URL(`${igBase}/${String(path).replace(/^\/+/,'')}`);
  const params=new URLSearchParams();
  if(method==='GET') params.set('access_token',accessToken);
  for(const [k,v] of Object.entries(body||{})) if(v!==undefined&&v!==null) params.set(k,typeof v==='object'?JSON.stringify(v):String(v));
  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),30000);
  try {
    const response=await fetch(url,{method,body:method==='GET'?undefined:params,headers:{accept:'application/json'},signal:controller.signal});
    const data=parse(await response.text());
    if(!response.ok||data.error) throw new Error(`Instagram API ${response.status}: ${data?.error?.message||JSON.stringify(data)}`);
    return data;
  } catch(e) {
    if(e.name==='AbortError') throw new Error('Instagram API timeout.');
    throw e;
  } finally { clearTimeout(timeout); }
}

async function waitForReel(containerId,accessToken) {
  const started=Date.now();
  while(Date.now()-started<120000) {
    const state=await instagramRequest(containerId,{accessToken});
    const code=String(state.status_code||state.status||'').toUpperCase();
    if(code==='FINISHED'||code==='PUBLISHED') return state;
    if(code==='ERROR'||code==='EXPIRED') throw new Error(`Instagram Reel hazırlama durumu: ${code}`);
    await new Promise(r=>setTimeout(r,3000));
  }
  throw new Error('Instagram Reel hazırlama zaman aşımına uğradı.');
}

export async function getInstagramMedia(credentials={}, limit=50) {
  const c=resolveCredentials(credentials);
  if(!c.instagramUserId || !c.instagramAccessToken) throw new Error('Instagram bağlantısı için kullanıcı ID ve erişim tokenı gerekli.');
  const n=Math.max(1, Math.min(100, Number(limit)||50));
  return instagramRequest(`${c.instagramUserId}/media`, {
    accessToken:c.instagramAccessToken,
    body:{
      fields:'id,caption,media_type,media_url,thumbnail_url,permalink,timestamp,username',
      limit:n
    }
  });
}

export async function createAdCreativeFromInstagramMedia({name,instagramMediaId,instagramUserId,pageId,credentials={}}) {
  const c=requireMeta(credentials);
  const mediaId=String(instagramMediaId||'').trim();
  if(!mediaId) throw new Error('Instagram gönderisi seçilmedi.');
  const igUser=String(instagramUserId||c.instagramUserId||'').trim();
  const page=String(pageId||c.pageId||'').trim();
  if(!igUser) throw new Error('Instagram kullanıcı ID bulunamadı.');

  const body={
    name,
    source_instagram_media_id:mediaId,
    object_story_spec:{
      instagram_user_id:igUser,
      ...(page ? {page_id:page} : {})
    }
  };
  return request(`act_${c.adAccountId}/adcreatives`,{method:'POST',credentials:c,body});
}

export async function instagramPublishMedia({mediaType='IMAGE',imageUrl,videoUrl,caption,carouselUrls=[],credentials={}}) {
  const c=resolveCredentials(credentials);
  if(!c.instagramUserId||!c.instagramAccessToken) throw new Error('Instagram bağlantısı için kullanıcı ID ve Instagram erişim tokenı gerekli.');
  const type=String(mediaType||'IMAGE').toUpperCase();
  const body={caption:caption||''};
  let container;
  if(type==='CAROUSEL') {
    const urls=[...(Array.isArray(carouselUrls)?carouselUrls:[])].filter(x=>/^https:\/\//i.test(String(x||''))).slice(0,10);
    if(urls.length<2) throw new Error('Carousel için en az 2 HTTPS görsel URL gerekli.');
    const children=[];
    for(const urlValue of urls) {
      const child=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,body:{image_url:urlValue,is_carousel_item:'true'}});
      if(!child.id) throw new Error('Carousel alt içerik container ID alınamadı.');
      children.push(child.id);
    }
    container=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,body:{...body,media_type:'CAROUSEL',children}});
  } else if(type==='REELS'||type==='VIDEO') {
    if(!/^https:\/\//i.test(String(videoUrl||''))) throw new Error('Reel için HTTPS video URL gerekli.');
    container=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,body:{...body,media_type:'REELS',video_url:videoUrl}});
    if(!container.id) return container;
    await waitForReel(container.id,c.instagramAccessToken);
  } else {
    if(!/^https:\/\//i.test(String(imageUrl||''))) throw new Error('Instagram görsel paylaşımı için HTTPS görsel URL gerekli.');
    container=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,body:{...body,image_url:imageUrl}});
  }
  if(!container?.id) return container||{};
  return instagramRequest(`${c.instagramUserId}/media_publish`,{method:'POST',accessToken:c.instagramAccessToken,body:{creation_id:container.id}});
}

export async function instagramHealth(credentials={}) {
  const c=resolveCredentials(credentials);
  if(!c.instagramUserId || !c.instagramAccessToken) return {connected:false,reason:'Instagram token veya kullanıcı ID eksik.'};
  try {
    const me=await instagramRequest('me',{accessToken:c.instagramAccessToken,body:{fields:'id,username'}});
    return {connected:true,id:String(me.id||c.instagramUserId),username:String(me.username||''),checkedAt:new Date().toISOString()};
  } catch(e) { return {connected:false,reason:e.message,checkedAt:new Date().toISOString()}; }
}

export async function metaHealth(credentials={}) {
  const c=resolveCredentials(credentials);
  const result={checkedAt:new Date().toISOString(),meta:{connected:false},instagram:{connected:false}};
  if(c.accessToken && c.adAccountId) {
    try {
      const account=await request(`act_${c.adAccountId}`,{credentials:c,query:{fields:'id,account_id,name,account_status,currency'}});
      result.meta={connected:true,adAccountId:account.account_id||c.adAccountId,name:account.name||'',accountStatus:account.account_status,currency:account.currency||''};
    } catch(e) { result.meta={connected:false,reason:e.message}; }
  } else result.meta.reason='Meta access token veya reklam hesabı eksik.';
  result.instagram=await instagramHealth(c);
  result.overall=result.instagram.connected && result.meta.connected;
  return result;
}

export async function instagramPublishImage(args={}) { return instagramPublishMedia({...args,mediaType:'IMAGE'}); }
