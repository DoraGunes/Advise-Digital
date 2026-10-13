export function summarizePresetResults(records){
 const rows=Array.isArray(records)?records:[];
 const groups=new Map();
 for(const row of rows){
  const group=groups.get(row.presetId)||{presetId:row.presetId,adIds:[],spend:0,conversations:0,complete:true};
  if(group.adIds.includes(row.adId))continue;group.adIds.push(row.adId);
  if(row.currency!=='TRY'||row.available!==true){group.complete=false;groups.set(row.presetId,group);continue;}
  for(const metric of row.data||[]){
   const spend=metric.spend==null||metric.spend===''?NaN:Number(metric.spend);
   const actions=Array.isArray(metric.actions)?metric.actions:null;
   const action=actions?.find(x=>x.action_type==='onsite_conversion.messaging_conversation_started_7d')
    ||actions?.find(x=>x.action_type==='messaging_conversation_started_7d');
   const count=action?(action.value==null||action.value===''?NaN:Number(action.value)):actions?0:NaN;
   if(!Number.isFinite(spend)||spend<0||!Number.isFinite(count)||count<0){group.complete=false;continue;}
   group.spend+=spend;group.conversations+=count;
  }
  groups.set(row.presetId,group);
 }
 return [...groups.values()].map(row=>({...row,currency:'TRY',windowDays:7,
  costPerConversation:row.complete&&row.conversations>0?Math.round(row.spend/row.conversations*100)/100:null,
  status:row.complete&&row.conversations>0?'MEASURED':'UNAVAILABLE',
  source:'META_INSIGHTS',note:'Son 7 gün, Meta konuşma atfı; WhatsApp kipindeki reklamlar. Tekil kişi veya satış sayısı değildir.'}));
}
