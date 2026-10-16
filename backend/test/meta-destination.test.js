import test from 'node:test';
import assert from 'node:assert/strict';

Object.assign(process.env,{
  DOTENV_CONFIG_PATH:'/tmp/advise-meta-destination-test-missing.env',
  JWT_SECRET:'meta-destination-test-secret',
  ADMIN_USERNAME:'meta-destination-admin',
  ADMIN_PASSWORD:'meta-destination-password',
  CRON_ENABLED:'false',
  NODE_ENV:'test'
});
const {adsPreflight,createAdSet}=await import('../src/meta.js');

test('Instagram Direct preflight does not incorrectly require WhatsApp assets',async()=>{
  const oldFetch=globalThis.fetch;
  const calls=[];
  globalThis.fetch=async (url,opts={})=>{
    const pathname=new URL(url).pathname;
    calls.push({pathname,method:opts.method||'GET',body:opts.body});
    let data;
    if(pathname.endsWith('/me/permissions'))data={data:[
      {permission:'ads_read',status:'granted'},
      {permission:'ads_management',status:'granted'},
      {permission:'pages_read_engagement',status:'granted'}
    ]};
    else if(pathname.endsWith('/act_12345'))data={account_id:'12345',account_status:1,disable_reason:0,currency:'TRY',timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']};
    else if(pathname.endsWith('/67890'))data={id:'67890',is_published:true,instagram_business_account:{id:'11111'}};
    else if(pathname.endsWith('/act_12345/adsets'))data={id:'adset-1'};
    else throw new Error('Unexpected Meta API call: '+pathname);
    return {ok:true,status:200,text:async()=>JSON.stringify(data)};
  };
  const credentials={accessToken:'test-token',instagramAccessToken:'test-token',instagramUserId:'11111',instagramApi:'FACEBOOK',adAccountId:'12345',pageId:'67890'};
  try {
    const ready=await adsPreflight(credentials,{destination:'INSTAGRAM_DIRECT'});
    assert.equal(ready.ok,true);
    assert.equal(ready.destination,'INSTAGRAM_DIRECT');
    await assert.rejects(()=>adsPreflight(credentials,{destination:'WHATSAPP'}),{code:'META_WHATSAPP_MISSING'});
    const created=await createAdSet({name:'Instagram test',campaignId:'c-1',dailyBudget:150,
      targeting:{geo_locations:{countries:['TR']}},destinationType:'INSTAGRAM_DIRECT',credentials});
    assert.equal(created.id,'adset-1');
    const post=calls.find(x=>x.pathname.endsWith('/adsets'));
    assert.equal(new URLSearchParams(post.body).get('destination_type'),'INSTAGRAM_DIRECT');
    assert.equal(new URLSearchParams(post.body).get('status'),'PAUSED');
  } finally {globalThis.fetch=oldFetch;}
});

test('Meta preflight fails closed when ads_read is missing',async()=>{
  const oldFetch=globalThis.fetch;
  let adWrites=0;
  globalThis.fetch=async (url,opts={})=>{
    const pathname=new URL(url).pathname;
    if(opts.method==='POST') {adWrites++;return {ok:true,status:200,text:async()=>JSON.stringify({id:'unexpected'})};}
    if(pathname.endsWith('/me/permissions'))return {ok:true,status:200,text:async()=>JSON.stringify({data:[
      {permission:'ads_management',status:'granted'},
      {permission:'pages_read_engagement',status:'granted'}
    ]})};
    if(pathname.endsWith('/act_12345'))return {ok:true,status:200,text:async()=>JSON.stringify({account_id:'12345',account_status:1,disable_reason:0,currency:'TRY',timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']})};
    if(pathname.endsWith('/67890'))return {ok:true,status:200,text:async()=>JSON.stringify({id:'67890',is_published:true,instagram_business_account:{id:'11111'}})};
    throw new Error('Unexpected Meta API call: '+pathname);
  };
  const credentials={accessToken:'test-token',instagramAccessToken:'test-token',instagramUserId:'11111',instagramApi:'FACEBOOK',adAccountId:'12345',pageId:'67890'};
  try {
    await assert.rejects(()=>adsPreflight(credentials,{destination:'INSTAGRAM_DIRECT'}),{code:'META_PERMISSION_DENIED'});
    assert.equal(adWrites,0);
  } finally {globalThis.fetch=oldFetch;}
});
