// Deterministic, tenant-scoped derivation from saved text and publication records.
const STOP=new Set(['bir','ve','ile','için','bu','da','de','mi','mı','mu','mü','en','çok','daha','olan','olarak','biz','siz']);
export function learnManualHistory(posts=[],{toleranceMinutes=15}={}){
 const rows=Array.isArray(posts)?posts:[];
 const counts=new Map(),hashtags=new Map(),samples=new Map(),timing=new Map();
 const seen=new Set();
 for(const row of rows){
  const caption=String(row.caption||'');
  const words=new Set(caption.toLocaleLowerCase('tr-TR').match(/[\p{L}\p{N}]{3,}/gu)||[]);
  for(const word of words)if(!STOP.has(word))counts.set(word,(counts.get(word)||0)+1);
  for(const tag of new Set(caption.match(/#[\p{L}\p{N}_]+/gu)||[]))hashtags.set(tag,(hashtags.get(tag)||0)+1);
  const mediaType=String(row.mediaType||row.format||'UNKNOWN').toUpperCase();
  if(caption&&!samples.has(mediaType))samples.set(mediaType,[]);
  if(caption&&samples.get(mediaType).length<5)samples.get(mediaType).push({postId:row.id,caption,status:row.publishStatus});
  const providerId=String(row.instagramPublishResult?.id||row.instagramMediaId||'');
  const planned=Date.parse(row.selectedTime?.scheduledAt||'');
  const actual=Date.parse(row.publishedAt||'');
  if(row.publishStatus!=='PUBLISHED'||row.publishPhase!=='CONFIRMED'||!providerId||seen.has(providerId)
    ||!Number.isFinite(planned)||!Number.isFinite(actual))continue;
  seen.add(providerId);
  const parts=new Intl.DateTimeFormat('en-GB',{timeZone:'Europe/Istanbul',
   weekday:'short',hour:'2-digit',minute:'2-digit',hourCycle:'h23'}).formatToParts(new Date(planned));
  const pick=type=>parts.find(x=>x.type===type)?.value;
  const slot=pick('weekday')+' '+pick('hour')+':'+pick('minute');
  const deltaMinutes=Math.round(Math.abs(actual-planned)/60000*10)/10;
  const group=timing.get(slot)||{slot,timezone:'Europe/Istanbul',trials:[]};
  group.trials.push({postId:row.id,instagramMediaId:providerId,plannedAt:new Date(planned).toISOString(),
   recordedPublishedAt:new Date(actual).toISOString(),deltaMinutes,aligned:deltaMinutes<=toleranceMinutes});
  timing.set(slot,group);
 }
 const rank=map=>[...map].sort((a,b)=>b[1]-a[1]||a[0].localeCompare(b[0],'tr')).slice(0,20)
   .map(([text,postCount])=>({text,postCount,evidence:'SAVED_TEXT_FREQUENCY'}));
 return {source:'OWN_SAVED_RECORDS',method:'TEXT_FREQUENCY_AND_MEDIA_TYPE',automaticActions:false,
  note:'Metin tercihleri ve medya türü kullanılır; görsel içeriği analiz edilmez. Sık kullanım başarı kanıtı değildir.',
  keywords:rank(counts),hashtags:rank(hashtags),
  captionSuggestions:[...samples].map(([mediaType,examples])=>({mediaType,examples})),
  timingToleranceMinutes:toleranceMinutes,
  timingChecks:[...timing.values()].map(group=>{
   const alignedCount=group.trials.filter(x=>x.aligned).length;
   return {...group,alignedCount,status:alignedCount>=2?'DOUBLE_TRIAL_ALIGNED':'INSUFFICIENT_ALIGNED_TRIALS',
    label:alignedCount>=2?'Çift denemeden geçti':'İki uyumlu yayın henüz yok',
    evidence:'RECORDED_PUBLICATION_TIMING',
    note:'Seçilen saat ile uygulamada kaydedilen yayın saati karşılaştırılır; erişim, dönüşüm veya reklam başarısı kanıtı değildir.'};
  })};
}
