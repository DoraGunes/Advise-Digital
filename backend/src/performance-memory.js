import fs from 'node:fs/promises';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {dataRoot,withDataLock} from './persistence.js';

const file=path.join(dataRoot,'performance_memory.json');
const VERSION=1;
const METRICS=[
  'impressions','reach','clicks','spend','messages','conversations','videoViews',
  'watchTime','reactions','saves','shares','comments','ctr','cpc','cpm','frequency','resultCost'
];
const VALID_STATUS=new Set(['AVAILABLE','UNAVAILABLE','NOT_SUPPORTED']);
const DEFAULT={version:VERSION,tenants:{}};

function clean(value,max=300){return String(value??'').trim().slice(0,max);}
function numberOrNull(value){const n=Number(value);return value==null||value===''||!Number.isFinite(n)?null:n;}
function nowIso(){return new Date().toISOString();}
function tenantDb(db,tenantId){
  const id=clean(tenantId,120)||'system';
  if(!db.tenants[id])db.tenants[id]={records:[]};
  if(!Array.isArray(db.tenants[id].records))db.tenants[id].records=[];
  return db.tenants[id];
}
function metric(value,status){
  const n=numberOrNull(value);
  const explicit=String(status||'').toUpperCase();
  if(n!==null)return {value:n,status:'AVAILABLE'};
  return {value:null,status:VALID_STATUS.has(explicit)?explicit:'UNAVAILABLE'};
}
function normalizeMetric(input,key){
  const raw=input?.[key];
  if(raw&&typeof raw==='object'&&('value'in raw||'status'in raw))return metric(raw.value,raw.status);
  const status=input?.metricStatus?.[key];
  return metric(raw,status);
}
function localParts(timestamp){
  const date=new Date(timestamp||Date.now());
  const safe=Number.isFinite(date.getTime())?date:new Date();
  const parts=new Intl.DateTimeFormat('en-GB',{
    timeZone:'Europe/Istanbul',weekday:'short',hour:'2-digit',hourCycle:'h23',
    year:'numeric',month:'2-digit',day:'2-digit'
  }).formatToParts(safe);
  const get=type=>parts.find(part=>part.type===type)?.value||'';
  return {weekday:get('weekday').toUpperCase(),hour:Number(get('hour')),date:get('year')+'-'+get('month')+'-'+get('day')};
}
function freshness(timestamp){
  const stamp=Date.parse(timestamp||'');
  if(!Number.isFinite(stamp))return {ageHours:null,label:'UNKNOWN'};
  const ageHours=Math.max(0,(Date.now()-stamp)/3600000);
  return {ageHours:Number(ageHours.toFixed(2)),label:ageHours<=24?'FRESH':ageHours<=168?'RECENT':'STALE'};
}
function confidence(sampleSize,freshnessScore=0){
  const score=Math.min(.95,(Math.min(sampleSize,8)/8)*.7+freshnessScore*.25);
  return {score:Number(score.toFixed(2)),label:score>=.75?'HIGH':score>=.45?'MEDIUM':'LOW'};
}
async function readDb(){
  await fs.mkdir(dataRoot,{recursive:true});
  try{
    const parsed=JSON.parse(await fs.readFile(file,'utf8'));
    if(!parsed.tenants||typeof parsed.tenants!=='object'||Array.isArray(parsed.tenants))parsed.tenants={};
    parsed.version=VERSION;
    return parsed;
  }catch(error){
    if(error?.code!=='ENOENT')throw error;
    return structuredClone(DEFAULT);
  }
}
async function writeDb(db){
  await fs.mkdir(dataRoot,{recursive:true});
  const temp=file+'.'+process.pid+'.'+randomUUID()+'.tmp';
  try{
    await fs.writeFile(temp,JSON.stringify(db,null,2),'utf8');
    await fs.rename(temp,file);
  }catch(error){
    await fs.rm(temp,{force:true}).catch(()=>{});
    throw error;
  }
}
function recordKey(input,timestamp){
  const explicit=clean(input.key,220);
  if(explicit)return explicit;
  return [
    clean(input.mode||input.kind,20).toUpperCase()||'PAID',
    clean(input.adId||input.postId||input.campaignId||'unknown',120),
    clean(input.timeRange?.start||timestamp,60),
    clean(input.timeRange?.end||timestamp,60)
  ].join(':');
}
function normalizeRecord(input={}){
  const timestamp=clean(input.timestamp||input.publishedAt||input.launchAt||nowIso(),60);
  const local=localParts(timestamp);
  const metrics={};
  for(const key of METRICS)metrics[key]=normalizeMetric(input.metrics||input,key);
  const sampleSize=Math.max(1,Math.floor(numberOrNull(input.sampleSize)||1));
  const fresh=freshness(input.measuredAt||input.updatedAt||nowIso());
  const freshScore=fresh.label==='FRESH'?1:fresh.label==='RECENT'?.65:fresh.label==='STALE'?.25:0;
  const conf=confidence(sampleSize,freshScore);
  return {
    id:clean(input.id,120)||'perf_'+randomUUID(),
    key:recordKey(input,timestamp),
    mode:String(input.mode||input.kind||'PAID').toUpperCase()==='ORGANIC'?'ORGANIC':'PAID',
    provider:clean(input.provider||'META',40),
    providerStatus:clean(input.providerStatus||'AVAILABLE',40),
    timestamp,
    localTime:{timezone:'Europe/Istanbul',...local},
    placement:clean(input.placement,120)||null,
    mediaType:clean(input.mediaType,40)||null,
    creativeType:clean(input.creativeType,80)||null,
    postId:clean(input.postId,120)||null,
    campaignId:clean(input.campaignId,120)||null,
    adsetId:clean(input.adsetId,120)||null,
    adId:clean(input.adId,120)||null,
    metrics,
    sampleSize,
    confidence:input.confidence&&typeof input.confidence==='object'?input.confidence:conf,
    timeRange:{
      start:clean(input.timeRange?.start,60)||null,
      end:clean(input.timeRange?.end,60)||null
    },
    freshness:fresh,
    measuredAt:clean(input.measuredAt||nowIso(),60),
    updatedAt:nowIso()
  };
}

export async function recordPerformance(tenantId,input={}){
  return withDataLock(async()=>{
    const db=await readDb(),tenant=tenantDb(db,tenantId),next=normalizeRecord(input);
    const existing=tenant.records.find(row=>row.key===next.key);
    if(existing)Object.assign(existing,{...next,id:existing.id});
    else tenant.records.push(next);
    tenant.records=tenant.records.slice(-2000);
    await writeDb(db);
    return existing||next;
  });
}

export function metaInsightToPerformance(row={},context={}){
  const actions=Array.isArray(row.actions)?row.actions:null;
  const actionValue=types=>{
    if(!actions)return null;
    const values=actions.filter(item=>types.includes(String(item.action_type||''))).map(item=>numberOrNull(item.value)).filter(value=>value!==null);
    return values.length?Math.max(...values):0;
  };
  const messages=actionValue([
    'onsite_conversion.messaging_conversation_started_7d',
    'messaging_conversation_started_7d',
    'onsite_conversion.messaging_first_reply'
  ]);
  const reactions=actionValue(['post_reaction','like']);
  const comments=actionValue(['comment','post_comment']);
  const shares=actionValue(['post_share']);
  const videoViews=actionValue(['video_view']);
  const metrics={
    impressions:numberOrNull(row.impressions),
    reach:numberOrNull(row.reach),
    clicks:numberOrNull(row.clicks),
    spend:numberOrNull(row.spend),
    messages,
    conversations:messages,
    videoViews,
    watchTime:null,
    reactions,
    saves:null,
    shares,
    comments,
    ctr:numberOrNull(row.ctr),
    cpc:numberOrNull(row.cpc),
    cpm:numberOrNull(row.cpm),
    frequency:numberOrNull(row.frequency),
    resultCost:messages!=null&&messages>0&&numberOrNull(row.spend)!=null?Number(row.spend)/messages:null
  };
  const metricStatus={
    watchTime:'UNAVAILABLE',
    saves:'UNAVAILABLE',
    frequency:row.frequency==null?'UNAVAILABLE':'AVAILABLE',
    resultCost:metrics.resultCost==null?'UNAVAILABLE':'AVAILABLE'
  };
  return {...context,provider:'META',providerStatus:'AVAILABLE',metrics,metricStatus};
}

function available(row,key){return row?.metrics?.[key]?.status==='AVAILABLE'?numberOrNull(row.metrics[key].value):null;}
function paidSignal(row){
  const messages=available(row,'messages'),ctr=available(row,'ctr'),resultCost=available(row,'resultCost'),cpc=available(row,'cpc');
  const parts=[];
  if(messages!==null)parts.push(Math.min(1,messages/10)*.4);
  if(ctr!==null)parts.push(Math.min(1,ctr/5)*.25);
  if(resultCost!==null)parts.push((1/(1+Math.max(0,resultCost)/10))*.25);
  if(cpc!==null)parts.push((1/(1+Math.max(0,cpc)/5))*.1);
  return parts.length?parts.reduce((a,b)=>a+b,0):null;
}
function organicSignal(row){
  const reach=available(row,'reach'),views=available(row,'videoViews');
  const engagement=['reactions','saves','shares','comments'].map(key=>available(row,key)).filter(v=>v!==null);
  const parts=[];
  if(reach!==null)parts.push(Math.min(1,Math.log10(1+Math.max(0,reach))/4)*.25);
  if(views!==null)parts.push(Math.min(1,Math.log10(1+Math.max(0,views))/4)*.25);
  if(engagement.length)parts.push(Math.min(1,engagement.reduce((a,b)=>a+b,0)/50)*.5);
  return parts.length?parts.reduce((a,b)=>a+b,0):null;
}
function recencyWeight(row){
  const age=row?.freshness?.ageHours;
  return age==null ? .5:Math.exp(-Math.max(0,age)/(24*45));
}

export async function recommendPublishTime(tenantId,input={}){
  return withDataLock(async()=>{
    const db=await readDb(),tenant=tenantDb(db,tenantId);
    const mode=String(input.mode||'ORGANIC').toUpperCase()==='PAID'?'PAID':'ORGANIC';
    const mediaType=clean(input.mediaType||input.format,40).toUpperCase();
    const rows=tenant.records.filter(row=>row.mode===mode).filter(row=>{
      if(!mediaType||mediaType==='AUTO')return true;
      return [row.mediaType,row.creativeType].map(x=>String(x||'').toUpperCase()).includes(mediaType);
    });
    const groups=new Map();
    for(const row of rows){
      const signal=mode==='PAID'?paidSignal(row):organicSignal(row);
      if(signal===null)continue;
      const key=row.localTime.weekday+':'+row.localTime.hour;
      if(!groups.has(key))groups.set(key,{weekday:row.localTime.weekday,hour:row.localTime.hour,rows:[],weighted:0,weight:0});
      const group=groups.get(key),weight=recencyWeight(row);
      group.rows.push(row);group.weighted+=signal*weight;group.weight+=weight;
    }
    const ranked=[...groups.values()].map(group=>{
      const sampleSize=group.rows.reduce((sum,row)=>sum+Math.max(1,Number(row.sampleSize||1)),0);
      const average=group.weight?group.weighted/group.weight:0;
      const freshRatio=group.rows.filter(row=>['FRESH','RECENT'].includes(row.freshness?.label)).length/Math.max(1,group.rows.length);
      return {...group,sampleSize,average,confidence:confidence(sampleSize,freshRatio)};
    }).sort((a,b)=>b.average-a.average||b.sampleSize-a.sampleSize);
    const best=ranked[0];
    if(!best)return {
      memoryType:'PERFORMANCE_TIMING',
      mode,
      recommended:null,
      sampleSize:0,
      confidence:{score:0,label:'NONE'},
      freshness:'UNKNOWN',
      reason:'Bu tenant ve format için ölçülmüş performans örneği henüz yok.',
      evidence:[]
    };
    return {
      memoryType:'PERFORMANCE_TIMING',
      mode,
      recommended:{weekday:best.weekday,hour:best.hour,timezone:'Europe/Istanbul'},
      sampleSize:best.sampleSize,
      confidence:best.confidence,
      freshness:best.rows.some(row=>row.freshness?.label==='FRESH')?'FRESH':best.rows.some(row=>row.freshness?.label==='RECENT')?'RECENT':'STALE',
      reason:'Öneri yalnız bu tenantın gerçek '+mode.toLowerCase()+' geçmişindeki gün/saat, format, sample size, recency ve performans sinyallerinden hesaplandı.',
      evidence:ranked.slice(0,5).map(group=>({weekday:group.weekday,hour:group.hour,sampleSize:group.sampleSize,score:Number(group.average.toFixed(4)),confidence:group.confidence}))
    };
  });
}

export async function getPerformanceMemorySummary(tenantId){
  return withDataLock(async()=>{
    const db=await readDb(),tenant=tenantDb(db,tenantId);
    const records=tenant.records;
    return {
      version:VERSION,
      memoryType:'PERFORMANCE_TIMING',
      recordCount:records.length,
      paidCount:records.filter(row=>row.mode==='PAID').length,
      organicCount:records.filter(row=>row.mode==='ORGANIC').length,
      availableMetrics:Object.fromEntries(METRICS.map(key=>[key,records.filter(row=>row.metrics?.[key]?.status==='AVAILABLE').length])),
      latestMeasuredAt:records.length?[...records].sort((a,b)=>Date.parse(b.measuredAt||0)-Date.parse(a.measuredAt||0))[0].measuredAt:null
    };
  });
}

export const PERFORMANCE_METRICS=Object.freeze([...METRICS]);
