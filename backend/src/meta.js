import {config} from './config.js';
import {remainingMs} from './operation-budget.js';
import {normalizeLocationName, provinceNamesForTargeting} from './ad-targeting.js';

const base=`https://graph.facebook.com/${config.metaApiVersion}`;

export function resolveCredentials(credentials=null) {
  const system = credentials == null || credentials.systemAccount === true;
  const fallback = system ? config : {};
  return {
    systemAccount:system,
    accessToken: String(credentials?.accessToken || credentials?.metaAccessToken || fallback.metaAccessToken || '').trim(),
    adAccountId: String(credentials?.adAccountId || fallback.adAccountId || '').replace(/^act_/, '').trim(),
    instagramUserId: String(credentials?.instagramUserId || fallback.instagramUserId || '').trim(),
    metaInstagramUserId: String(
      credentials?.metaInstagramUserId ||
      credentials?.instagramBusinessAccountId ||
      fallback.metaInstagramUserId ||
      ''
    ).trim(),
    pageId: String(credentials?.pageId || fallback.metaPageId || '').trim(),
    instagramAccessToken: String(credentials?.instagramAccessToken || fallback.instagramAccessToken || '').trim(),
    instagramUsername: String(credentials?.instagramUsername || fallback.instagramUsername || '').trim(),
    instagramApi: credentials?.instagramApi || 'INSTAGRAM'
  };
}

function requireMeta(credentials={}) {
  const c=resolveCredentials(credentials);
  if(!c.accessToken || !c.adAccountId) throw new Error('Meta bağlantısı için erişim tokenı ve reklam hesabı gerekli.');
  return c;
}

function parse(text) { try { return JSON.parse(text); } catch { return {raw:text}; } }

async function request(path,{method='GET',query={},body={},credentials={},timeoutMs=30000}={}) {
  const c=requireMeta(credentials);
  const url=new URL(`${base}/${String(path).replace(/^\/+/, '')}`);
  const params={...query};
  if(method==='GET') params.access_token=c.accessToken;
  for(const [k,v] of Object.entries(params)) if(v!==undefined&&v!==null) url.searchParams.set(k,String(v));

  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),remainingMs(Math.max(1,Math.min(30000,Number(timeoutMs)||30000))));
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
    if(!r.ok||data.error) {
      const err=data?.error||{};
      const code=Number(err.code)===190?'META_SESSION_EXPIRED':r.status===403||[10,200].includes(Number(err.code))?'META_PERMISSION_DENIED':r.status===429||[4,17,32,613].includes(Number(err.code))?'META_RATE_LIMIT':'META_REJECTED';
      const messages={META_SESSION_EXPIRED:'Meta bağlantısının süresi dolmuş. Bağlantılar ekranından yeniden bağlayın.',META_PERMISSION_DENIED:'Meta bu işlem için izin vermedi. Reklam hesabı ve Sayfa yetkilerini kontrol edin.',META_RATE_LIMIT:'Meta işlem sınırına ulaşıldı. Biraz sonra yeniden deneyin.',META_REJECTED:'Meta reklam isteğini kabul etmedi. Hesap, hedefleme ve WhatsApp bağlantısını kontrol edin.'};
      throw Object.assign(new Error(messages[code]),{code,status:r.status,providerCode:Number(err.code)||null,providerSubcode:Number(err.error_subcode)||null,providerTrace:/^[a-zA-Z0-9_-]{1,120}$/.test(err.fbtrace_id||'')?err.fbtrace_id:null,retryable:code==='META_RATE_LIMIT'||r.status>=500});
    }
    if(data.paging)data.paging={cursors:data.paging.cursors||{},hasNext:Boolean(data.paging.next)};
    return data;
  } catch(e) {
    if(e.name==='AbortError') throw Object.assign(new Error('Meta yanıtı zamanında tamamlanamadı.'),{code:'ETIMEDOUT',retryable:false});
    throw e;
  } finally { clearTimeout(timeout); }
}

async function collection(path,credentials,fields,limit) {
  const rows=[];let after;
  for(let page=0;page<20;page++) {
    const result=await request(path,{credentials,query:{fields,limit,after}});
    rows.push(...(result.data||[]));
    if(!result.paging?.hasNext)return {data:rows};
    const cursor=result.paging?.cursors?.after;
    if(!cursor||cursor===after)throw new Error('Meta kayıtlarının tamamı doğrulanamadı. Yeniden deneyin.');
    after=cursor;
  }
  throw new Error('Hesap kayıtları güvenli sorgu sınırını aşıyor. Destek ekibine başvurun.');
}

export async function getCampaigns(credentials={}) {
  const c=requireMeta(credentials);
  return collection(`act_${c.adAccountId}/campaigns`,c,'id,name,status,effective_status,objective,daily_budget,lifetime_budget,start_time,stop_time',200);
}

export async function getAdSets(credentials={}) {
  const c=requireMeta(credentials);
  return collection(`act_${c.adAccountId}/adsets`,c,'id,name,status,effective_status,campaign_id,daily_budget,lifetime_budget,optimization_goal,billing_event,targeting,start_time,end_time',500);
}

export async function getAds(credentials={}) {
  const c=requireMeta(credentials);
  return collection(`act_${c.adAccountId}/ads`,c,'id,name,status,effective_status,campaign_id,adset_id,created_time,creative{id,name,object_story_id,thumbnail_url,effective_instagram_media_id,source_instagram_media_id}',500);
}

export async function assertMetaOwnership(id,credentials={}) {
  const c=requireMeta(credentials);
  const clean=String(id||'').trim();
  if (!/^(act_)?\d+$/.test(clean)) throw new Error('Geçerli bir Meta hesap veya reklam kimliği gerekli.');
  if (clean===`act_${c.adAccountId}`) return {id:clean,account_id:c.adAccountId};
  const object=await request(clean,{credentials:c,query:{fields:'id,account_id'}});
  if (String(object.account_id||'').replace(/^act_/,'')!==c.adAccountId) {
    throw new Error('Bu reklam seçili reklam hesabına ait değil.');
  }
  return object;
}

export async function getMetaAccount(credentials={}) {
  const c=requireMeta(credentials);
  return request(`act_${c.adAccountId}`,{credentials:c,query:{fields:'id,account_id,name,currency,account_status'}});
}

// No success is inferred from locally stored credentials. Unknown prerequisite
// fields fail closed, and every create/resume runs fresh provider checks.
export async function adsPreflight(credentials={}, {destination='FACEBOOK_INSTAGRAM'}={}) {
  const c=requireMeta(credentials);
  const fail=(code,message)=>{throw Object.assign(new Error(message),{code,retryable:false});};
  const normalizedDestination=String(destination||'FACEBOOK_INSTAGRAM').trim().toUpperCase();
  if(!['FACEBOOK','INSTAGRAM','FACEBOOK_INSTAGRAM','INSTAGRAM_DIRECT','WHATSAPP'].includes(normalizedDestination))fail('META_DESTINATION_INVALID','Geçerli reklam hedefini seçin.');
  const whatsappDestination=normalizedDestination==='WHATSAPP';
  if(!c.pageId||!c.metaInstagramUserId&&!c.instagramUserId)fail('META_ASSETS_MISSING','Reklam oluşturmadan önce Sayfa ve Instagram hesabını bağlayın.');
  const [account,permissions,page]=await Promise.all([
    request(`act_${c.adAccountId}`,{credentials:c,query:{fields:'id,account_id,currency,account_status,disable_reason,timezone_name,user_tasks'}}),
    request('me/permissions',{credentials:c}),
    request(c.pageId,{credentials:c,query:{fields:'id,instagram_business_account,connected_instagram_account,has_whatsapp_business_number,has_whatsapp_number,is_published'}})
  ]);
  if(String(account.account_id)!==c.adAccountId)fail('META_ACCOUNT_MISMATCH','Reklam hesabı bağlantısını yeniden seçin.');
  if(Number(account.account_status)!==1||Number(account.disable_reason||0)!==0)fail('META_ACCOUNT_RESTRICTED','Meta reklam hesabı etkin değil veya kısıtlı. Meta hesap durumunu kontrol edin.');
  if(account.currency!=='TRY')fail('META_CURRENCY_UNSUPPORTED','Bu reklam akışı TRY para birimindeki hesapları destekliyor.');
  if(!account.timezone_name)fail('META_PREFLIGHT_UNAVAILABLE','Reklam hesabının saat dilimi doğrulanamadı. Bağlantıyı kontrol edin.');
  const granted=new Set((permissions.data||[]).filter(row=>row.status==='granted').map(row=>row.permission));
  if(!granted.has('ads_management')||!granted.has('pages_read_engagement'))fail('META_PERMISSION_DENIED','Reklam yönetimi ve Sayfa erişim izinlerini yeniden verin.');
  if(!Array.isArray(account.user_tasks)||!account.user_tasks.some(task=>['ADVERTISE','MANAGE'].includes(task)))fail('META_PERMISSION_DENIED','Seçili reklam hesabında reklam oluşturma yetkisi doğrulanamadı.');
  if(String(page.id)!==c.pageId||page.is_published!==true)fail('META_PAGE_UNAVAILABLE','Bağlı Sayfa erişimi veya yayın durumu doğrulanamadı.');
  const linked=String(page.instagram_business_account?.id||page.connected_instagram_account?.id||'');
  if(!linked||linked!==String(c.metaInstagramUserId||c.instagramUserId))fail('META_INSTAGRAM_MISMATCH','Sayfaya bağlı Instagram hesabını Bağlantılar ekranından yeniden seçin.');
  if(whatsappDestination&&page.has_whatsapp_business_number!==true&&page.has_whatsapp_number!==true)fail('META_WHATSAPP_MISSING','Reklam oluşturmadan önce Meta Sayfanıza WhatsApp numaranızı bağlayın.');
  return {ok:true,accountId:c.adAccountId,pageId:c.pageId,instagramId:linked,currency:account.currency,timezone:account.timezone_name,objective:'OUTCOME_ENGAGEMENT',optimizationGoal:'CONVERSATIONS',destination:normalizedDestination,checkedAt:new Date().toISOString(),limitations:['Meta yaratım sırasında ek işletme, ödeme veya içerik kısıtlaması bildirebilir.']};
}

export async function accountInsights(credentials={}, {since,until,timeIncrement,level='account'}={}) {
  const c=requireMeta(credentials);
  const query={fields:'date_start,date_stop,campaign_id,campaign_name,spend,impressions,reach,clicks,ctr,cpc,cpm,actions,purchase_roas',time_range:JSON.stringify({since,until}),level,limit:500};
  if (timeIncrement) query.time_increment=timeIncrement;
  return request(`act_${c.adAccountId}/insights`,{credentials:c,query});
}

export async function insights(id,level='ad',days=7,credentials={}) {
  const until=new Date();
  const since=new Date(Date.now()-Math.max(1,days)*86400000);
  return insightsRange(id,level,since,until,credentials);
}

export async function insightsRange(id,level='ad',since,until=new Date(),credentials={}) {
  await assertMetaOwnership(id,credentials);
  const f=d=>d.toISOString().slice(0,10);
  return request(`${id}/insights`,{credentials,query:{fields:'spend,impressions,reach,clicks,ctr,cpc,cpm,actions,cost_per_action_type,purchase_roas',time_range:JSON.stringify({since:f(since),until:f(until)}),level}});
}

export async function setStatus(id,status,credentials={}) {
  if(!['ACTIVE','PAUSED'].includes(status)) throw new Error('Status ACTIVE/PAUSED olmalı.');
  await assertMetaOwnership(id,credentials);
  return request(id,{method:'POST',credentials,body:{status}});
}

export async function updateAdSetBudget(id,dailyBudget,credentials={}) {
  const n=Math.round(Number(dailyBudget) * 100);
  if(!Number.isFinite(n)||n<=0) throw new Error('Geçersiz daily budget.');
  await assertMetaOwnership(id,credentials);
  return request(id,{method:'POST',credentials,body:{daily_budget:n}});
}

export async function updateAdSetTargeting(id,targeting,credentials={}) {
  await assertMetaOwnership(id,credentials);
  const value = targeting && typeof targeting === 'object' ? targeting : {};
  const geo = value.geo_locations;
  if (!geo || typeof geo !== 'object' || !(
    (Array.isArray(geo.countries) && geo.countries.length) ||
    (Array.isArray(geo.cities) && geo.cities.length) ||
    (Array.isArray(geo.regions) && geo.regions.length)
  )) throw new Error('Geçerli ve açıkça seçilmiş bir coğrafi hedef kitle gerekli.');
  return request(id,{method:'POST',credentials,body:{targeting:value}});
}

export async function createCampaign({name,objective='OUTCOME_ENGAGEMENT',status='PAUSED',credentials={}}) {
  const c=requireMeta(credentials);
  return request(`act_${c.adAccountId}/campaigns`,{method:'POST',credentials:c,body:{name,objective,status,special_ad_categories:[],is_adset_budget_sharing_enabled:false},timeoutMs:15000});
}

export async function createAdSet({name,campaignId,dailyBudget,targeting,optimizationGoal='CONVERSATIONS',billingEvent='IMPRESSIONS',destinationType='INSTAGRAM_DIRECT',instagramActorId,pageId,credentials={}}) {
  const c=requireMeta(credentials);
  const amountTl=Number(dailyBudget);
  if(!Number.isFinite(amountTl)||amountTl<=0) throw new Error('Geçersiz günlük bütçe.');
  const amountMinor=Math.round(amountTl * 100);
  const body={name,campaign_id:campaignId,daily_budget:amountMinor,billing_event:billingEvent,optimization_goal:optimizationGoal,destination_type:destinationType,bid_strategy:'LOWEST_COST_WITHOUT_CAP',targeting:targeting||{geo_locations:{countries:['TR']}},status:'PAUSED'};
  if(pageId||c.pageId) body.promoted_object={page_id:pageId||c.pageId};
  return request(`act_${c.adAccountId}/adsets`,{method:'POST',credentials:c,body,timeoutMs:15000});
}

const adLocationKeyCache = new Map();

export async function resolveAdGeoTargeting(mode='COUNTRY', locations=[], credentials={}) {
  if (mode === 'COUNTRY') return {geo_locations:{countries:['TR']}, locationMode:'COUNTRY', locations:['Türkiye']};
  const cityNames = provinceNamesForTargeting(mode, locations);
  const c = requireMeta(credentials);
  const missing = [];
  const resolveCity = async name => {
    const cacheKey = normalizeLocationName(name);
    if (adLocationKeyCache.has(cacheKey)) return adLocationKeyCache.get(cacheKey);
    try {
      const result = await request('search', {
        credentials: c,
        query: {
          type: 'adgeolocation',
          location_types: JSON.stringify(['city']),
          country_code: 'TR',
          q: name,
          limit: 20
        }
      });
      const rows = Array.isArray(result?.data) ? result.data : [];
      const exact = rows.find(row =>
        String(row?.country_code || '').toUpperCase() === 'TR' &&
        String(row?.type || '').toLowerCase() === 'city' &&
        normalizeLocationName(row?.name) === cacheKey &&
        String(row?.key || row?.id || '').trim()
      );
      const key = String(exact?.key || exact?.id || '').trim();
      if (!key) {
        missing.push(name);
        return null;
      }
      adLocationKeyCache.set(cacheKey, key);
      return key;
    } catch (error) {
      missing.push(name);
      throw error;
    }
  };
  const cities = [];
  for (let index = 0; index < cityNames.length; index += 6) {
    cities.push(...await Promise.all(cityNames.slice(index, index + 6).map(resolveCity)));
  }
  if (missing.length || cities.some(x => !x)) {
    throw new Error(`Meta hedefleme konumu çözümlenemedi: ${[...new Set(missing)].join(', ')}. Hiçbir reklam oluşturulmadı.`);
  }
  return {
    geo_locations:{cities:cities.map(key => ({key}))},
    locationMode:mode,
    locations:cityNames
  };
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
  return request(`act_${c.adAccountId}/ads`,{method:'POST',credentials:c,body:{name,adset_id:adsetId,creative:{creative_id:creativeId},status},timeoutMs:15000});
}

const igBase='https://graph.instagram.com';

async function instagramRequest(path,{method='GET',body={},accessToken,api='INSTAGRAM'}={}) {
  if(!accessToken) throw new Error('Instagram access token bulunamadı.');
  const url=new URL(`${api==='FACEBOOK'?base:igBase}/${String(path).replace(/^\/+/,'')}`);
  const params=new URLSearchParams();
  params.set('access_token',accessToken);
  for(const [k,v] of Object.entries(body||{})) if(v!==undefined&&v!==null) params.set(k,typeof v==='object'?JSON.stringify(v):String(v));
  if(method==='GET') url.search = params.toString();
  const controller=new AbortController();
  const timeout=setTimeout(()=>controller.abort(),remainingMs(30000));
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

async function waitForReel(containerId,accessToken,api) {
  const started=Date.now();
  while(Date.now()-started<120000) {
    const state=await instagramRequest(containerId,{accessToken,api,body:{fields:'status_code,status'}});
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
    api:c.instagramApi,
    body:{
      fields:'id,caption,media_type,media_url,thumbnail_url,permalink,timestamp,username',
      limit:n
    }
  });
}

async function resolveMetaInstagramIdentity(c, explicitId='', explicitPageId='') {
  const direct=String(explicitId||c.instagramUserId||c.metaInstagramUserId||'').trim();
  let pageId=String(explicitPageId||c.pageId||'').trim();

  // The connected Instagram account ID comes from the Instagram media connection.
  // Prefer it directly; if the page is missing, resolve a Facebook Page that exposes
  // an Instagram Business account matching the requested ID.
  if(direct && pageId) return {instagramUserId:direct,pageId};

  try {
    const result=await request('me/accounts',{
      credentials:c,
      query:{fields:'id,name,instagram_business_account',limit:100}
    });
    const pages=Array.isArray(result?.data) ? result.data : [];
    const match=pages.find(x =>
      x?.instagram_business_account?.id &&
      (!direct || String(x.instagram_business_account.id)===direct)
    ) || pages.find(x=>x?.instagram_business_account?.id);

    if(match) {
      pageId=pageId||String(match.id||'').trim();
      const resolvedIg=String(match.instagram_business_account.id||'').trim();
      return {instagramUserId:direct||resolvedIg,pageId};
    }
  } catch {}

  if(direct) return {instagramUserId:direct,pageId};

  throw new Error('Instagram Business hesap kimliği bulunamadı. Meta/Instagram bağlantısını yeniden doğrulamak gerekiyor.');
}

export async function createAdCreativeFromInstagramMedia({name,instagramMediaId,instagramUserId,pageId,credentials={}}) {
  const c=requireMeta(credentials);
  const mediaId=String(instagramMediaId||'').trim();
  if(!mediaId) throw new Error('Instagram gönderisi seçilmedi.');

  const identity=await resolveMetaInstagramIdentity(c,instagramUserId,pageId);
  if(!identity.pageId) throw new Error('Instagram reklamı için Facebook Page ID gerekli.');
  const body={
    name,
    object_id:identity.pageId,
    instagram_user_id:identity.instagramUserId,
    source_instagram_media_id:mediaId
  };

  return request(`act_${c.adAccountId}/adcreatives`,{method:'POST',credentials:c,body,timeoutMs:15000});
}

export async function instagramPublishMedia({mediaType='IMAGE',imageUrl,videoUrl,caption,carouselUrls=[],coverUrl='',thumbOffset,credentials={},containerId='',onContainer=async()=>{},onBeforePublish=async()=>{}}) {
  const c=resolveCredentials(credentials);
  if(!c.instagramUserId||!c.instagramAccessToken) throw new Error('Instagram bağlantısı için kullanıcı ID ve Instagram erişim tokenı gerekli.');
  const type=String(mediaType||'IMAGE').toUpperCase();
  const body={caption:caption||''};
  let container=containerId?{id:containerId}:null;
  if(!container && type==='CAROUSEL') {
    const urls=[...(Array.isArray(carouselUrls)?carouselUrls:[])].filter(x=>/^https:\/\//i.test(String(x||''))).slice(0,10);
    if(urls.length<2) throw new Error('Carousel için en az 2 HTTPS görsel URL gerekli.');
    const children=[];
    for(const urlValue of urls) {
      const child=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,api:c.instagramApi,body:{image_url:urlValue,is_carousel_item:'true'}});
      if(!child.id) throw new Error('Carousel alt içerik container ID alınamadı.');
      children.push(child.id);
    }
    container=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,api:c.instagramApi,body:{...body,media_type:'CAROUSEL',children}});
  } else if(!container && (type==='REELS'||type==='VIDEO')) {
    if(!/^https:\/\//i.test(String(videoUrl||''))) throw new Error('Reel için HTTPS video URL gerekli.');
    const reelBody={...body,media_type:'REELS',video_url:videoUrl};
    const safeCover=String(coverUrl||'').trim();
    const offset=Number(thumbOffset);
    if(/^https:\/\//i.test(safeCover)) reelBody.cover_url=safeCover;
    else if(Number.isFinite(offset)&&offset>=0) reelBody.thumb_offset=Math.round(offset);
    container=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,api:c.instagramApi,body:reelBody});
  } else if(!container) {
    if(!/^https:\/\//i.test(String(imageUrl||''))) throw new Error('Instagram görsel paylaşımı için HTTPS görsel URL gerekli.');
    container=await instagramRequest(`${c.instagramUserId}/media`,{method:'POST',accessToken:c.instagramAccessToken,api:c.instagramApi,body:{...body,image_url:imageUrl}});
  }
  if(!container?.id) throw new Error('Instagram içerik hazırlama kimliği alınamadı.');
  await onContainer(container.id);
  await waitForReel(container.id,c.instagramAccessToken,c.instagramApi);
  await onBeforePublish();
  const published=await instagramRequest(`${c.instagramUserId}/media_publish`,{method:'POST',accessToken:c.instagramAccessToken,api:c.instagramApi,body:{creation_id:container.id}});
  if (!published?.id) throw new Error('Instagram yayın sonucu doğrulanamadı.');
  return published;
}

export async function getInstagramContainerStatus(containerId,credentials={}) {
  const c=resolveCredentials(credentials);
  return instagramRequest(containerId,{accessToken:c.instagramAccessToken,api:c.instagramApi,body:{fields:'status_code,status'}});
}

export async function instagramHealth(credentials={}) {
  const c=resolveCredentials(credentials);
  if(!c.instagramUserId || !c.instagramAccessToken) return {connected:false,reason:'Instagram token veya kullanıcı ID eksik.'};
  try {
    const me=await instagramRequest(c.instagramApi==='FACEBOOK'?c.instagramUserId:'me',{accessToken:c.instagramAccessToken,api:c.instagramApi,body:{fields:'id,username'}});
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
