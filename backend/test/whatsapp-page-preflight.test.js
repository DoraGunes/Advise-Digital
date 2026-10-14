import test from 'node:test';
import assert from 'node:assert/strict';
Object.assign(process.env,{DOTENV_CONFIG_PATH:'/tmp/wa-preflight-missing.env',JWT_SECRET:'fixture',ADMIN_USERNAME:'fixture',ADMIN_PASSWORD:'fixture',CRON_ENABLED:'false'});
const {adsPreflight}=await import('../src/meta.js');
const c={accessToken:'fixture',adAccountId:'123',pageId:'456',instagramUserId:'789',systemAccount:false};
async function fixture({business,number,waba=false,management=false,mismatch=false},check){
 const before=globalThis.fetch,calls=[];
 globalThis.fetch=async(url,options={})=>{
  const path=new URL(url).pathname;calls.push({path,method:options.method||'GET'});
  let body;
  if(path.endsWith('/act_123'))body={account_id:'123',currency:'TRY',account_status:1,disable_reason:0,timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']};
  else if(path.endsWith('/me/permissions'))body={data:['ads_management','pages_read_engagement',...(management?['whatsapp_business_management']:[])].map(permission=>({permission,status:'granted'}))};
  else if(path.endsWith('/456'))body={id:'456',is_published:true,instagram_business_account:{id:'789'},...(business===undefined?{}:{has_whatsapp_business_number:business}),...(number===undefined?{}:{has_whatsapp_number:number})};
  else if(path.endsWith('/999/phone_numbers'))body={data:[{id:mismatch?'different':'888'}]};
  else if(path.endsWith('/999'))body={id:'999'};
  else throw Error('Unexpected request');
  return {ok:true,status:200,text:async()=>JSON.stringify(body)};
 };
 try{await check({...c,...(waba?{metaWhatsappWabaId:'999',metaWhatsappPhoneNumberId:'888'}:{})},calls);}
 finally{globalThis.fetch=before;}
}
test('Page-linked Business app is verified with ads permissions, no WABA or messaging permission',()=>fixture({business:true,number:true},async(c,calls)=>{
 const result=await adsPreflight(c,{destination:'WHATSAPP'});
 assert.equal(result.ok,true);assert.equal(result.whatsappVerificationSource,'PAGE_LINK');
 assert.equal(result.whatsappAssetVerified,true);assert.equal(calls.length,3);
 assert.ok(calls.every(row=>row.method==='GET'));
}));
test('Unknown or false Page linkage fails closed even with stored WABA IDs',async()=>{
 for(const flags of [{},{business:false,number:false}])await fixture({...flags,waba:true,management:true},async(c,calls)=>{
  await assert.rejects(()=>adsPreflight(c,{destination:'WHATSAPP'}),{code:'META_WHATSAPP_MISSING'});
  assert.ok(calls.every(row=>row.method==='GET'));
 });
});
test('Cloud phone fallback requires Page linkage, management permission and matching phone, not message-send permission',async()=>{
 await fixture({business:false,number:true,waba:true,management:true},async c=>{
  const result=await adsPreflight(c,{destination:'WHATSAPP'});
  assert.equal(result.whatsappVerificationSource,'WABA_PHONE_WITH_PAGE');
 });
 await fixture({business:false,number:true,waba:true,management:true,mismatch:true},async c=>{
  await assert.rejects(()=>adsPreflight(c,{destination:'WHATSAPP'}),{code:'META_WHATSAPP_MISSING'});
 });
});
