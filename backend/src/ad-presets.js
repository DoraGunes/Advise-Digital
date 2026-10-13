export const AD_PRESET_VERSION=1;
export const AD_PRESETS=Object.freeze([
 {id:'service-all',name:'Teknik servis · WhatsApp',media:'ANY',placement:'AUTO'},
 {id:'tv-photo',name:'Televizyon servisi · Fotoğraf',media:'IMAGE',placement:'FEEDS'},
 {id:'panel-photo',name:'Panel ve ekran · Fotoğraf',media:'IMAGE',placement:'FEEDS'},
 {id:'service-reels',name:'Servis tanıtımı · Reels',media:'VIDEO',placement:'REELS'},
 {id:'instagram-reels',name:'Instagram Reels · WhatsApp',media:'VIDEO',placement:'INSTAGRAM_REELS'}
]);
export const BOLU_RADIUS={latitude:40.7356,longitude:31.6061,radius:200,distance_unit:'kilometer'};
function reject(message){throw Object.assign(new Error(message),{code:'AD_PRESET_INVALID'});}
export function presetPolicy(body,settings){
 if(!body.presetId)return null;
 if(Number(body.presetVersion)!==AD_PRESET_VERSION)reject('Reklam kipi sürümü sunucuyla uyumsuz.');
 const preset=AD_PRESETS.find(row=>row.id===body.presetId);
 if(!preset)reject('Bilinmeyen reklam kipi.');
 if(body.activate===true||body.destination!=='WHATSAPP'||body.autoReply===true)reject('Hazır kip yalnız WhatsApp, PAUSED ve otomatik yanıtsız çalışır.');
 const budget=Number(body.dailyBudget);
 if(!Number.isFinite(budget)||budget<50||budget>120)reject('Hazır kip günlük bütçesi 50–120 TL olmalı.');
 const mode=String(body.locationMode||'').toUpperCase();
 if(!['RADIUS','CITY','REGION'].includes(mode))reject('Hazır kip için açık hizmet bölgesi seçin; Türkiye geneline otomatik geçilmez.');
 let radius=null;
 if(mode==='RADIUS'){
  const input=body.radius||BOLU_RADIUS;
  radius=Object.fromEntries(Object.keys(BOLU_RADIUS).map(key=>[key,input[key]??BOLU_RADIUS[key]]));
  for(const key of ['latitude','longitude','radius'])radius[key]=Number(radius[key]);
  if(!Number.isFinite(radius.latitude)||Math.abs(radius.latitude)>90
    ||!Number.isFinite(radius.longitude)||Math.abs(radius.longitude)>180
    ||!Number.isFinite(radius.radius)||radius.radius<1||radius.radius>200
    ||radius.distance_unit!=='kilometer')reject('Geçerli merkez ve 1–200 km yarıçap gerekli.');
 }
 const cap=Number(settings.geminiAdsDailyCap||0),max=Number(settings.maxDailyBudget||120);
 return {preset,radius,settings:{...settings,geminiAdsDailyCap:cap>0?Math.min(cap,200):0,maxDailyBudget:Math.min(max,120)}};
}
export function presetTargeting(preset,geo_locations){
 const targeting={geo_locations,age_min:18,age_max:65};
 if(preset.placement==='FEEDS')Object.assign(targeting,{publisher_platforms:['facebook','instagram'],facebook_positions:['feed'],instagram_positions:['stream']});
 if(preset.placement==='REELS')Object.assign(targeting,{publisher_platforms:['facebook','instagram'],facebook_positions:['facebook_reels'],instagram_positions:['reels']});
 if(preset.placement==='INSTAGRAM_REELS')Object.assign(targeting,{publisher_platforms:['instagram'],instagram_positions:['reels']});
 return targeting;
}
export function assertPresetMedia(preset,row){
 const type=String(row?.media_type||'').toUpperCase();
 if(preset.media!=='ANY'&&type!==preset.media)reject(preset.media==='VIDEO'?'Bu kip için yayınlanmış Reels/video seçin.':'Bu kip için yayınlanmış tek fotoğraf seçin.');
}
