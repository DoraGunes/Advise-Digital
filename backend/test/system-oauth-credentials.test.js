import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-connected-system-'));
Object.assign(process.env,{
 DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),ADVISE_DATA_DIR:fixture,
 ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),ADVISE_NO_LISTEN:'true',CRON_ENABLED:'false',
 JWT_SECRET:'fixture-only-session-secret',ADMIN_USERNAME:'fixture-system-admin',
 ADMIN_PASSWORD:'fixture-password',GEMINI_API_KEY:'',GOOGLE_API_KEY:'',
 META_ACCESS_TOKEN:'fixture-stale-env-token',META_AD_ACCOUNT_ID:'123',
 INSTAGRAM_ACCESS_TOKEN:'fixture-stale-env-instagram',INSTAGRAM_USER_ID:'111',
 META_PAGE_ID:'222',META_INSTAGRAM_ID:'111'
});
const {tenantCredentials}=await import('../src/automation-safety.js');
const {resolveCredentials}=await import('../src/meta.js');
after(async()=>{await fs.rm(fixture,{recursive:true,force:true});});
const meta={connected:true,source:'OAUTH',accessToken:'fixture-selected-oauth',
 instagramAccessToken:'fixture-selected-oauth',instagramApi:'FACEBOOK',
 adAccountId:'246',pageId:'456',instagramUserId:'789'};

test('selected system OAuth credentials never mix with stale environment assets',()=>{
 const selected=resolveCredentials(tenantCredentials('system',{meta}));
 assert.equal(selected.systemAccount,false);
 assert.equal(selected.accessToken,meta.accessToken);
 assert.equal(selected.adAccountId,'246');
 assert.equal(selected.pageId,'456');
 assert.equal(selected.instagramUserId,'789');
 assert.equal(selected.instagramApi,'FACEBOOK');
 assert.equal(selected.metaInstagramUserId,'');
 assert.equal(resolveCredentials(tenantCredentials('system',{meta:{connected:false}})).adAccountId,'123');
 const incomplete=resolveCredentials(tenantCredentials('system',{meta:{connected:true,source:'OAUTH'}}));
 assert.equal(incomplete.accessToken,'');
 assert.equal(incomplete.adAccountId,'');
 assert.equal(resolveCredentials(tenantCredentials('other',{meta:{}})).accessToken,'');
});

test('system media listing, ad creation and publishing all use the already selected OAuth account',async()=>{
 const store=await import('../src/store.js');
 await store.updateTenant('system',{meta});
 await store.saveSettings('system',{geminiAdsDailyCap:300,maxDailyBudget:300});
 await store.savePosts('system',[{id:'system-photo',mediaType:'POST',publicUrl:'https://fixture.invalid/image.jpg',caption:'Fixture',publishStatus:'MANUAL'},{id:'system-reel',mediaType:'REELS',publicUrl:'https://fixture.invalid/video.mp4',caption:'Fixture Reel',publishStatus:'MANUAL'}]);
 const {app}=await import('../src/server.js');
 const auth=await import('../src/auth.js');
 const session=await auth.login('fixture-system-admin','fixture-password');
 const listener=app.listen(0,'127.0.0.1');
 await new Promise(resolve=>listener.once('listening',resolve));
 const base='http://127.0.0.1:'+listener.address().port;
 const native=globalThis.fetch,writes=[];let mediaCreates=0;
 globalThis.fetch=async(input,options={})=>{
  const url=new URL(input);
  if(url.hostname==='127.0.0.1')return native(input,options);
  assert.equal(url.hostname,'graph.facebook.com','Facebook OAuth must use Facebook Graph');
  const token=options.method==='POST'?new URLSearchParams(options.body).get('access_token'):url.searchParams.get('access_token');
  assert.equal(token,'fixture-selected-oauth');
  const endpoint=url.pathname.split('/').at(-1);
  let result;
  if(options.method==='POST'){
   writes.push(endpoint);
   if(endpoint==='media'){
    assert.ok(url.pathname.endsWith('/789/media'));
    const body=new URLSearchParams(options.body);
    if(++mediaCreates===1){assert.equal(body.get('image_url'),'https://fixture.invalid/image.jpg');assert.equal(body.get('media_type'),null);}
    else {assert.equal(body.get('media_type'),'REELS');assert.equal(body.get('video_url'),'https://fixture.invalid/video.mp4');assert.equal(body.get('image_url'),null);}
    result={id:mediaCreates===1?'1005':'1007'};
   }
   else if(endpoint==='media_publish'){assert.ok(url.pathname.endsWith('/789/media_publish'));result={id:new URLSearchParams(options.body).get('creation_id')==='1005'?'1006':'1008'};}
   else {
    assert.ok(url.pathname.includes('/act_246/'));
    result={id:String({campaigns:1001,adsets:1002,adcreatives:1003,ads:1004}[endpoint])};
   }
  }else if(endpoint==='act_246')result={account_id:'246',currency:'TRY',account_status:1,disable_reason:0,timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']};
  else if(endpoint==='permissions')result={data:[{permission:'ads_management',status:'granted'},{permission:'pages_read_engagement',status:'granted'}]};
  else if(endpoint==='456')result={id:'456',is_published:true,instagram_business_account:{id:'789'}};
  else if(endpoint==='media'){assert.ok(url.pathname.endsWith('/789/media'));result={data:[{id:'901',media_type:'IMAGE'}]};}
  else if(['1005','1007'].includes(endpoint))result={status_code:'FINISHED'};
  else if(['campaigns','adsets','ads'].includes(endpoint))result={data:[]};
  else assert.fail('Unexpected fixture provider endpoint');
  return new Response(JSON.stringify(result),{status:200});
 };
 const headers={authorization:'Bearer '+session.token,'content-type':'application/json'};
 try{
  const listing=await native(base+'/api/instagram/media',{headers});
  assert.equal(listing.status,200);
  assert.equal((await listing.json()).data[0].id,'901');
  const created=await native(base+'/api/ads/create',{method:'POST',headers,body:JSON.stringify({requestId:'system-oauth-fixture-request-0001',instagramMediaId:'901',dailyBudget:100,activate:false,destination:'INSTAGRAM_DIRECT',locationMode:'COUNTRY'})});
  assert.equal(created.status,201,JSON.stringify(await created.clone().json()));
  assert.equal((await created.json()).ad.id,'1004');
  const published=await native(base+'/api/posts/system-photo/publish',{method:'POST',headers,body:'{}'});
  assert.equal(published.status,200,JSON.stringify(await published.clone().json()));
  assert.equal((await store.getPosts('system'))[0].instagramMediaId,'1006');
  const reel=await native(base+'/api/posts/system-reel/publish',{method:'POST',headers,body:'{}'});
  assert.equal(reel.status,200,JSON.stringify(await reel.clone().json()));
  assert.equal((await store.getPosts('system'))[1].instagramMediaId,'1008');
  assert.deepEqual(writes,['campaigns','adsets','adcreatives','ads','media','media_publish','media','media_publish']);
 }finally{
  globalThis.fetch=native;
  listener.closeAllConnections();
  await new Promise(resolve=>listener.close(resolve));
 }
});
