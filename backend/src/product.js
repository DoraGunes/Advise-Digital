import {getTenant,getSettings,saveSettings,updateTenant,getPosts,getLogs,publicTenant,addLog} from './store.js';
import {getCampaigns,getAds,accountInsights,getMetaAccount} from './meta.js';
import {tenantCredentials,metaReady} from './automation-safety.js';
import {getLeads,getAlerts,createAlert} from './pro.js';
import {getMemorySummary} from './ai-memory.js';
import {config} from './config.js';
import {AD_CITIES,AD_REGIONS,provinceNamesForTargeting} from './ad-targeting.js';
import {withDataLock} from './persistence.js';

const number=value=>Number.isFinite(Number(value))?Number(value):0;
const emptyMetrics=()=>({spend:null,messages:null,cpa:null,ctr:null,reach:null,impressions:null,activeAds:null});
const dateString=value=>new Intl.DateTimeFormat('en-CA',{timeZone:config.timezone,year:'numeric',month:'2-digit',day:'2-digit'}).format(value);
const dateShift=(value,days)=>new Date(new Date(`${value}T12:00:00Z`).getTime()+days*86400000).toISOString().slice(0,10);
const cache=new Map();

export function buildProductRecommendations({metaConnected=false,onboarding={},today={},posts=[],leads=[],memory={},settings={}}={}) {
  const recommendations=[];
  const add=(id,priority,kind,title,body,action,tone='info',evidence={})=>{
    if(recommendations.some(row=>row.id===id))return;
    recommendations.push({id,priority,kind,title,body,action,tone,evidence});
  };
  const postRows=Array.isArray(posts)?posts:[];
  const leadRows=Array.isArray(leads)?leads:[];
  const metrics=today?.metrics||{};
  const queued=postRows.filter(row=>['QUEUED','RETRY'].includes(String(row.publishStatus||'').toUpperCase()));
  const failed=postRows.filter(row=>['ERROR','RECONCILE'].includes(String(row.publishStatus||'').toUpperCase()));
  const published=postRows.filter(row=>String(row.publishStatus||'').toUpperCase()==='PUBLISHED');
  const newLeads=leadRows.filter(row=>String(row.status||'').toUpperCase()==='NEW');
  const activeAds=Number(metrics.activeAds||0);
  const spend=Number(metrics.spend||0);
  const messages=Number(metrics.messages||0);
  const cpa=metrics.cpa==null?null:Number(metrics.cpa);
  const costLimit=Math.max(0,Number(settings.earlyMessageCostLimit||settings.messageCostLimit||0));
  const noMessageSpend=Math.max(0,Number(settings.earlyNoMessageSpendThreshold||settings.minSpendBeforeDecision||0));

  if(!metaConnected) add(
    'connect-meta',100,'CONNECTION','Meta hesabını bağla',
    'Reklam performansı, otomatik optimizasyon ve gerçek sonuç önerileri için Meta/Instagram bağlantısını tamamla.',
    'META_CONNECTION','warning',{metaConnected:false}
  );
  if(onboarding&&onboarding.completed!==true) add(
    'complete-onboarding',95,'SETUP','İşletme kurulumunu tamamla',
    'Hedef, bütçe ve bölge bilgileri tamamlandığında AdVise önerileri işletmene göre daralır.',
    'ONBOARDING','warning',{step:Number(onboarding.step||0)}
  );
  if(failed.length) add(
    'repair-publishing',92,'PUBLISHING','Yayın hatalarını kontrol et',
    `${failed.length} içerik ERROR/RECONCILE durumunda. Çift paylaşım riski oluşturmadan önce yayın durumlarını doğrula.`,
    'PLANNER','danger',{failedPosts:failed.length}
  );
  if(newLeads.length) add(
    'follow-up-leads',88,'CRM','Yeni müşteri adaylarını takip et',
    `${newLeads.length} yeni lead işlem bekliyor. Reklam harcamasının satışa dönmesi için CRM takibini geciktirme.`,
    'CRM','info',{newLeads:newLeads.length}
  );
  if(today?.available===true&&messages===0&&spend>=noMessageSpend&&noMessageSpend>0) add(
    'review-no-message-spend',86,'ADS','Harcama var, mesaj sonucu yok',
    `Bugün ${spend.toFixed(2)} harcama oluştu ancak ölçülmüş mesaj sonucu yok. Reklam Karar Merkezi'nde hedefleme ve kreatifi incele.`,
    'AUTOMATION','danger',{spend,messages,threshold:noMessageSpend}
  );
  if(today?.available===true&&cpa!=null&&costLimit>0&&cpa>=costLimit) add(
    'review-high-cpa',84,'ADS','Mesaj maliyeti eşiğin üzerinde',
    `Mesaj başına maliyet ${cpa.toFixed(2)}; tanımlı erken karar eşiği ${costLimit.toFixed(2)}. Otomasyon kararını ve bütçe dağılımını kontrol et.`,
    'AUTOMATION','warning',{cpa,threshold:costLimit}
  );
  if(metaConnected&&activeAds===0&&published.length) add(
    'launch-campaign',76,'ADS','Yayınlanmış içerikten kampanya başlat',
    `${published.length} yayınlanmış içerik var ancak aktif reklam görünmüyor. Uygun içeriği seçip kontrollü kampanya başlatabilirsin.`,
    'ADS','info',{publishedPosts:published.length,activeAds}
  );
  if(queued.length===0) {
    const hookType=memory?.bestHookTypes?.[0]?.value||'';
    add(
      'prepare-next-content',72,'CONTENT','Sonraki içeriği hazırla',
      hookType
        ? `Yayın kuyruğun boş. Hafıza Sarayı'nda güçlenen ${hookType} hook tipini kopyalamadan yeni bir kreatifte test et.`
        : 'Yayın kuyruğun boş. Yeni medya ekleyip içerik planını devam ettir.',
      'STUDIO','info',{queuedPosts:0,winningHookType:hookType||null}
    );
  }
  if(Number(memory?.outcomeCount||0)>0&&Number(memory?.learningWins||0)>0) {
    const format=memory?.bestFormats?.[0]?.value||'';
    add(
      'use-memory-winner',58,'MEMORY','Kazanan örüntüyü yeni kreatife taşı',
      format
        ? `Hafıza Sarayı ölçülmüş kazananlar buldu. ${format} formatındaki güçlü örüntüyü yeni ürün bağlamında özgün biçimde kullan.`
        : 'Hafıza Sarayı ölçülmüş kazananlar buldu. Kazanan hook ve açıları kopyalamadan yeni kreatife uyarlayabilirsin.',
      'MEMORY','success',{learningWins:Number(memory.learningWins||0),format:format||null}
    );
  }
  if(!recommendations.length) add(
    'review-performance',40,'REPORTING','Performansı gözden geçir',
    'Kritik bir uyarı görünmüyor. Son 7 günlük trendi ve kampanya sonuçlarını karşılaştırarak bir sonraki testi seç.',
    'REPORTS','success',{activeAds,queuedPosts:queued.length}
  );
  return recommendations.sort((a,b)=>b.priority-a.priority).slice(0,5);
}

export function reportRange(input={},now=new Date()) {
  const today=dateString(now),range=String(input.range||'7d').toLowerCase();
  let since=today,until=today;
  if(range==='yesterday')since=until=dateShift(today,-1);
  else if(['7d','14d','30d'].includes(range))since=dateShift(today,1-Number(range.replace('d','')));
  else if(range==='custom') {
    since=String(input.since||'');until=String(input.until||'');
    const valid=value=>/^\d{4}-\d{2}-\d{2}$/.test(value)&&dateShift(value,0)===value;
    if(!valid(since)||!valid(until)||since>until||until>today||(Date.parse(until)-Date.parse(since))/86400000>365)throw new Error('En fazla 366 günlük geçerli bir tarih aralığı seçin.');
  } else if(range!=='today')throw new Error('Geçersiz rapor tarih aralığı.');
  return {range,since,until};
}

export function metricsFor(row={}) {
  const messages=Math.max(0,...(row.actions||[]).filter(action=>config.messageActionTypes.includes(action.action_type)).map(action=>number(action.value)));
  const spend=number(row.spend),impressions=number(row.impressions),clicks=number(row.clicks);
  return {spend,messages,cpa:messages>0?spend/messages:null,ctr:row.ctr==null?(impressions>0?clicks/impressions*100:0):number(row.ctr),reach:number(row.reach),impressions,clicks};
}

export async function productReport(tenantId,input={}) {
  const bounds=reportRange(input);
  const tenant=await getTenant(tenantId),credentials=tenantCredentials(tenantId,tenant);
  const result={available:false,...bounds,metrics:emptyMetrics(),trend:[],campaigns:[],insights:[],generatedAt:new Date().toISOString()};
  if(!metaReady(credentials))return {...result,error:'Gerçek performansı görmek için Meta hesabınızı bağlayın.'};
  const key=`${tenantId}:${bounds.since}:${bounds.until}:${tenant?.meta?.connectedAt||'system'}`;
  const cached=cache.get(key);if(cached&&Date.now()-cached.at<30000)return structuredClone(cached.result);
  try {
    const [totals,trend,byCampaign,campaigns,ads,account]=await Promise.all([
      accountInsights(credentials,bounds),accountInsights(credentials,{...bounds,timeIncrement:1}),
      accountInsights(credentials,{...bounds,level:'campaign'}),getCampaigns(credentials),getAds(credentials),getMetaAccount(credentials)
    ]);
    result.available=true;result.currency=account.currency||null;
    result.metrics={...metricsFor((totals.data||[])[0]),activeAds:(ads.data||[]).filter(row=>String(row.effective_status||row.status)==='ACTIVE').length};
    result.trend=(trend.data||[]).map(row=>({date:row.date_start,...metricsFor(row)}));
    const byId=new Map((byCampaign.data||[]).map(row=>[String(row.campaign_id),metricsFor(row)]));
    result.campaigns=(campaigns.data||[]).map(row=>({id:row.id,name:row.name,status:row.effective_status||row.status,dailyBudget:Number(row.daily_budget)>0?number(row.daily_budget)/100:null,...(byId.get(String(row.id))||{spend:0,messages:0,cpa:null,ctr:0,impressions:0,reach:0})}));
    const measured=result.campaigns.filter(row=>row.messages>0&&row.spend>0).sort((a,b)=>a.cpa-b.cpa);
    if(measured.length)result.insights.push(`Bu dönemde en düşük mesaj maliyeti: ${measured[0].name} (${measured[0].cpa.toFixed(2)} ${result.currency||''}).`);
    if(measured.length>1)result.insights.push(`Karşılaştırmada en yüksek mesaj maliyeti: ${measured[measured.length-1].name}.`);
    if(!measured.length)result.insights.push('Mesaj maliyetini karşılaştırmak için henüz yeterli sonuç yok.');
    cache.set(key,{at:Date.now(),result});
    if(cache.size>100)cache.delete(cache.keys().next().value);
    return structuredClone(result);
  } catch { return {...result,available:false,metrics:emptyMetrics(),trend:[],campaigns:[],error:'Meta performans verisi alınamadı. Bağlantınızı kontrol edip yeniden deneyin.'}; }
}

export async function onboardingStatus(tenantId) {
  const tenant=await getTenant(tenantId),settings=await getSettings(tenantId),c=tenantCredentials(tenantId,tenant);
  const previous=tenant?.onboarding||{};
  return {
    businessName:previous.businessName||tenant?.companyName||'',industry:previous.industry||'',goal:previous.goal||'WhatsApp mesajı',
    locationMode:previous.locationMode||settings.adTargetingMode,locations:previous.locations||settings.adTargetingLocations,
    dailyBudget:Number(previous.dailyBudget||0),step:Number(previous.step||0),completed:previous.completed===true,
    updatedAt:previous.updatedAt||null,
    connection:{meta:metaReady(c),page:Boolean(c.pageId||(tenantId==='system'&&config.metaPageId)),instagram:Boolean(c.instagramUserId&&c.instagramAccessToken)||(tenantId==='system'&&Boolean(config.instagramUserId&&config.instagramAccessToken)),adAccount:Boolean(c.adAccountId)||(tenantId==='system'&&Boolean(config.adAccountId))}
  };
}

export async function saveOnboarding(tenantId,input={}) {
  return withDataLock(async()=>{
    const current=await onboardingStatus(tenantId);
    const next={...current};
    for(const [key,max]of [['businessName',160],['industry',100],['goal',120]])if(input[key]!==undefined)next[key]=String(input[key]).trim().slice(0,max);
    if(input.locationMode!==undefined)next.locationMode=String(input.locationMode).toUpperCase();
    if(!['COUNTRY','CITY','REGION'].includes(next.locationMode))throw new Error('Geçerli bir konum türü seçin.');
    if(input.locations!==undefined)next.locations=[...new Set((Array.isArray(input.locations)?input.locations:[]).map(String))].slice(0,81);
    if(next.locationMode==='COUNTRY')next.locations=[];
    const allowed=next.locationMode==='CITY'?AD_CITIES:Object.keys(AD_REGIONS);
    if(next.locationMode!=='COUNTRY'&&next.locations.some(row=>!allowed.includes(row)))throw new Error('Geçerli şehir veya bölge seçin.');
    if(input.dailyBudget!==undefined)next.dailyBudget=Number(input.dailyBudget);
    if(!Number.isFinite(next.dailyBudget)||next.dailyBudget<0||next.dailyBudget>100000)throw new Error('Bütçe 0 ile 100.000 arasında olmalı.');
    if(input.step!==undefined)next.step=Math.max(0,Math.min(10,Math.floor(Number(input.step)||0)));
    if(input.completed!==undefined)next.completed=input.completed===true;
    if(next.completed&&(!next.businessName||!next.industry||!next.goal||next.dailyBudget<=0||!Object.values(next.connection).every(Boolean)||(next.locationMode!=='COUNTRY'&&!next.locations.length)))throw new Error('Kurulumu tamamlamak için işletme bilgileri, bütçe ve Meta varlıklarını tamamlayın.');
    delete next.connection;
    await updateTenant(tenantId,{onboarding:{...next,updatedAt:new Date().toISOString()}});
    const settings=await getSettings(tenantId);
    const patch={adTargetingMode:next.locationMode,adTargetingLocations:next.locations,aiGoal:next.goal};
    if(next.dailyBudget>0&&!(Number(settings.geminiAdsDailyCap)>0))patch.geminiAdsDailyCap=next.dailyBudget;
    await saveSettings(tenantId,patch);
    return onboardingStatus(tenantId);
  });
}

async function syncNotifications(tenantId,logs) {
  return withDataLock(async()=>{
    const current=await getAlerts(tenantId),known=new Set(current.map(row=>row.sourceEventId));
    const types={INSTAGRAM_POST_PUBLISHED:['İçerik yayınlandı','Planlanan içerik Instagram hesabınıza gönderildi.','SUCCESS'],INSTAGRAM_POST_ERROR:['Yayın tamamlanamadı','İçerik planından durumu kontrol edip güvenli şekilde yeniden deneyin.','WARNING'],META_DISCONNECTED:['Meta bağlantısı kapatıldı','Reklam yönetimi için hesabınızı yeniden bağlayın.','WARNING'],GEMINI_AD_ACTION:['Reklam kararı uygulandı','Karar merkezinden uygulanan değişikliği ve nedenini görebilirsiniz.','INFO'],LEAD_CREATED:['Yeni müşteri adayı','CRM alanında yeni müşteri adayını inceleyin.','INFO'],EARLY_REVIEW_DONE:['Reklam değerlendirmesi tamamlandı','Otomasyon alanından değerlendirme sonucunu inceleyin.','INFO']};
    for(const log of logs.slice(0,50).reverse()) {
      const text=types[log.type];if(!text)continue;
      const event=`${log.type}:${log.at}:${log.postId||log.adSetId||log.adId||log.leadId||''}`;
      if(known.has(event))continue;
      await createAlert(tenantId,{title:text[0],body:text[1],severity:text[2],sourceEventId:event});known.add(event);
    }
    return getAlerts(tenantId);
  });
}

export async function productOverview(tenantId,user) {
  const [today,week,tenant,posts,logs,leads,memory,onboarding,settings]=await Promise.all([productReport(tenantId,{range:'today'}),productReport(tenantId,{range:'7d'}),getTenant(tenantId),getPosts(tenantId),getLogs(tenantId,100),getLeads(tenantId),getMemorySummary(tenantId),onboardingStatus(tenantId),getSettings(tenantId)]);
  const notifications=await syncNotifications(tenantId,logs);
  const metaConnected=metaReady(tenantCredentials(tenantId,tenant));
  const recommendations=buildProductRecommendations({metaConnected,onboarding,today,posts,leads,memory,settings});
  const summary=[];
  if(today.available) {
    summary.push(`Bugün ${today.metrics.activeAds} aktif reklam var. Harcama ${today.metrics.spend.toFixed(2)} ${today.currency||''}.`);
    summary.push(today.metrics.messages>0?`${today.metrics.messages} mesaj sonucu; mesaj başına maliyet ${today.metrics.cpa.toFixed(2)} ${today.currency||''}.`:'Bugün henüz ölçülmüş mesaj sonucu yok.');
  } else summary.push(today.error);
  const next=posts.filter(row=>['QUEUED','RETRY'].includes(row.publishStatus)&&Date.parse(row.nextPublishAt)>=Date.now()).sort((a,b)=>Date.parse(a.nextPublishAt)-Date.parse(b.nextPublishAt))[0];
  if(next)summary.push(`Sonraki içerik ${new Date(next.nextPublishAt).toLocaleString('tr-TR',{timeZone:config.timezone})} için planlandı.`);
  const failures=posts.filter(row=>['ERROR','RECONCILE'].includes(row.publishStatus)).length;
  if(failures)summary.push(`${failures} içerik yayını için durum kontrolü gerekiyor.`);
  if(!memory.outcomeCount)summary.push('AdVise öğreniyor; ölçülmüş sonuçlar biriktikçe öneriler güçlenecek.');
  if(recommendations[0])summary.push(`Öncelikli hamle: ${recommendations[0].title}.`);
  return {...today,metaConnected,trend:week.trend,posts,leads,logs,notifications,memory,onboarding,recommendations,me:{user,tenant:publicTenant(tenant)},dailyBrief:{source:'REAL_DATA_RULE_ENGINE',summary,generatedAt:new Date().toISOString()}};
}
