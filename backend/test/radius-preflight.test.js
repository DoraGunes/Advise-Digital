import test from 'node:test';import assert from 'node:assert/strict';
Object.assign(process.env,{JWT_SECRET:'fixture',ADMIN_USERNAME:'fixture',ADMIN_PASSWORD:'fixture',CRON_ENABLED:'false',DOTENV_CONFIG_PATH:'/tmp/missing-preset.env'});
const {validateRadiusTargeting,createAdCreativeFromInstagramMedia}=await import('../src/meta.js');
const creds={accessToken:'fixture',adAccountId:'123',pageId:'456',instagramUserId:'789',metaInstagramUserId:'789'};
test('Unsupported radius stops after read-only estimate and never changes target or writes Meta',async()=>{
 const old=globalThis.fetch,calls=[];globalThis.fetch=async(url,options)=>{
  calls.push({url:new URL(url),options});return {ok:false,status:400,text:async()=>JSON.stringify({error:{code:100,message:'unsupported radius'}})};
 };
 try{
  await assert.rejects(()=>validateRadiusTargeting({latitude:40.7356,longitude:31.6061,radius:200,distance_unit:'kilometer'},creds),{code:'AD_RADIUS_UNAVAILABLE'});
  assert.equal(calls.length,1);assert.equal(calls[0].options.method,'GET');
  assert.equal(JSON.parse(calls[0].url.searchParams.get('targeting_spec')).geo_locations.custom_locations[0].radius,200);
 }finally{globalThis.fetch=old;}
});
test('WhatsApp creative has a WhatsApp CTA and no automated greeting or bot payload',async()=>{
 const old=globalThis.fetch;let payload;
 globalThis.fetch=async(url,options)=>{
  if(options.method==='POST')payload=new URLSearchParams(options.body);
  return {ok:true,status:200,text:async()=>JSON.stringify(options.method==='POST'?{id:'creative'}:{id:'456',instagram_business_account:{id:'789'}})};
 };
 try{
  await createAdCreativeFromInstagramMedia({name:'fixture',instagramMediaId:'media',instagramUserId:'789',pageId:'456',destination:'WHATSAPP',credentials:creds});
  const cta=JSON.parse(payload.get('call_to_action'));assert.equal(cta.type,'WHATSAPP_MESSAGE');
  assert.equal(cta.value.app_destination,'WHATSAPP');
  for(const key of ['page_welcome_message','message_template','asset_feed_spec','messenger_sponsored_message'])assert.equal(payload.has(key),false);
 }finally{globalThis.fetch=old;}
});
