import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-manual-'));
Object.assign(process.env,{DOTENV_CONFIG_PATH:path.join(fixture,'absent.env'),
  ADVISE_DATA_DIR:fixture,ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),
  ADVISE_NO_LISTEN:'true',CRON_ENABLED:'false',PUBLIC_BASE_URL:'https://media.fixture.invalid',
  JWT_SECRET:'fixture-only-secret',ADMIN_USERNAME:'fixture-admin',ADMIN_PASSWORD:'fixture-pass',
  GEMINI_API_KEY:'fixture-key-must-never-be-used',META_ACCESS_TOKEN:'',INSTAGRAM_ACCESS_TOKEN:''});
const store=await import('../src/store.js'),auth=await import('../src/auth.js');
const {app}=await import('../src/server.js');
const {buildManualMemory}=await import('../src/manual-memory.js');
const ai=await import('../src/ai.js'),gemini=await import('../src/gemini-ads.js');
const nativeFetch=global.fetch;let externalCalls=0;
global.fetch=async(input,options)=>{
  if(new URL(String(input)).hostname!=='127.0.0.1'){
    externalCalls++;throw new Error('External calls prohibited in manual fixture');}
  return nativeFetch(input,options);
};
const listener=app.listen(0,'127.0.0.1');
await new Promise(resolve=>listener.once('listening',resolve));
const base='http://127.0.0.1:'+listener.address().port;
const session=await auth.login('fixture-admin','fixture-pass');
const headers={authorization:'Bearer '+session.token};
after(async()=>{
  global.fetch=nativeFetch;listener.closeAllConnections();
  await new Promise(resolve=>listener.close(resolve));assert.equal(externalCalls,0);
  assert.ok(fixture.startsWith(os.tmpdir()+path.sep));await fs.rm(fixture,{recursive:true,force:true});
});
async function json(route,method='GET',body){
  const r=await fetch(base+route,{method,headers:{...headers,'content-type':'application/json'},
    ...(body===undefined?{}:{body:JSON.stringify(body)})});
  return {status:r.status,body:await r.json()};
}
async function upload(bytes,type,name,fields={},route='/api/posts',field='image'){
  const form=new FormData();form.append(field,new Blob([bytes],{type}),name);
  for(const [k,v] of Object.entries(fields))form.append(k,String(v));
  const r=await fetch(base+route,{method:'POST',headers,body:form});
  return {status:r.status,body:await r.json()};
}
test('removed AI cannot call a configured provider or apply a legacy ad action',async()=>{
  for(const call of [()=>ai.callGemini({}),()=>ai.generateContentPack({}),
    ()=>ai.generateCaption({}),()=>ai.generateCaptionVariants({}),()=>ai.scoreCreative({}),
    ()=>ai.generateCampaignStrategy({}),()=>ai.analyzeAdPerformance({}),
    ()=>gemini.applyGeminiAdDecision('system',{})])
    await assert.rejects(call,e=>e.code==='AI_REMOVED');
  assert.equal(ai.aiStatus().provider,'NONE');
  assert.deepEqual((await gemini.runGeminiAdReview()).applied,[]);
  for(const route of ['/api/product/strategy','/api/ads/gemini-review','/api/ads/gemini-apply',
    '/api/automation/run','/api/ai/content-pack','/api/ai/caption-variants']){
    const r=await json(route,'POST',{});assert.equal(r.status,410);assert.equal(r.body.code,'AI_REMOVED');}
  const before=await fs.readdir(path.join(fixture,'uploads'));
  assert.equal((await upload(Buffer.from('fixture'),'video/mp4','fixture.mp4',{},
    '/api/ai/content-pack-from-file')).status,410);
  assert.deepEqual(await fs.readdir(path.join(fixture,'uploads')),before);
});
test('saved legacy switches cannot reactivate AI, ads or automatic publication',async()=>{
  await store.saveSettings('system',{aiEnabled:true,geminiAdsAuto:true,enabled:true,
    autoPublish:true,autoBestTime:true,geminiAdsDailyCap:200});
  const s=(await json('/api/settings')).body;
  for(const k of ['aiEnabled','geminiAdsAuto','enabled','autoPublish','autoBestTime'])assert.equal(s[k],false,k);
  assert.equal(s.geminiAdsDailyCap,200);
});
test('manual photo keeps user text and time, becomes JPEG READY and rejects duplicate',async()=>{
  const sharp=(await import('sharp')).default;
  const image=await sharp({create:{width:48,height:64,channels:4,background:'#122334'}}).png().toBuffer();
  const at=new Date(Date.now()+86400000).toISOString(),caption='Kendi açıklamam #poyraz';
  const r=await upload(image,'image/png','fixture.png',
    {title:'Manuel fotoğraf',caption,scheduleAt:at,useAI:true,autoPublish:true});
  assert.equal(r.status,201,JSON.stringify(r.body));assert.equal(r.body.caption,caption);
  assert.equal(r.body.aiGenerated,false);assert.equal(r.body.autoPublish,false);
  assert.equal(r.body.publishStatus,'READY');assert.equal(r.body.nextPublishAt,at);
  assert.equal(r.body.mimeType,'image/jpeg');assert.match(r.body.publicUrl,/^https:\/\//);
  assert.equal((await sharp(await fs.readFile(r.body.filePath)).metadata()).format,'jpeg');
  assert.equal((await upload(image,'image/png','fixture.png',{caption,scheduleAt:at})).status,409);
  assert.equal((await store.getPosts('system')).find(p=>p.id===r.body.id).caption,caption);
});
test('video acceptance preserves bytes, REELS format and manual state; bulk never runs AI',async()=>{
  // Multipart transport fixture; this test does not assert playable video or Meta acceptance.
  const bytes=Buffer.from('isolated MP4 multipart fixture');
  const r=await upload(bytes,'video/mp4','fixture.mp4',{caption:'Kendi Reels metnim',
    scheduleAt:new Date(Date.now()+172800000).toISOString(),useAI:true,autoPublish:true});
  assert.equal(r.status,201);assert.equal(r.body.mediaType,'REELS');
  assert.equal(r.body.publishStatus,'READY');assert.equal(r.body.autoPublish,false);
  assert.equal(r.body.aiGenerated,false);assert.deepEqual(await fs.readFile(r.body.filePath),bytes);
  assert.equal(r.body.instagramPublishResult,undefined);
  const bulk=await upload(Buffer.from('bulk fixture'),'video/mp4','bulk.mp4',
    {useAI:true,autoPublish:true},'/api/posts/bulk','files');
  assert.equal(bulk.status,201);assert.equal(bulk.body.posts[0].publishStatus,'MANUAL');
  assert.equal(bulk.body.posts[0].autoPublish,false);assert.equal(bulk.body.posts[0].aiGenerated,false);
});
test('invalid future time cleans the uncommitted file without a post record',async()=>{
  const before=(await store.getPosts('system')).length,files=await fs.readdir(path.join(fixture,'uploads'));
  const r=await upload(Buffer.from('bad time'),'video/mp4','bad.mp4',{caption:'Taslak',scheduleAt:'not-a-date'});
  assert.equal(r.status,400);assert.equal((await store.getPosts('system')).length,before);
  assert.deepEqual(await fs.readdir(path.join(fixture,'uploads')),files);
});
test('published post cannot be requeued; tenant history omits credentials and preserves records',async()=>{
  const posts=await store.getPosts('system');
  const old={id:'published-fixture',tenantId:'system',title:'Eski gönderi',caption:'Eski metin',
    mediaType:'POST',publishStatus:'PUBLISHED',publishPhase:'CONFIRMED',
    publishedAt:'2026-10-01T10:00:00Z',instagramPublishResult:{id:'fixture-media-id'},
    filePath:'private-local-path',accessToken:'fixture-hidden'};
  await store.savePosts('system',[old,...posts]);const before=JSON.stringify(await store.getPosts('system'));
  assert.equal((await json('/api/posts/published-fixture/queue','POST',
    {scheduleAt:new Date(Date.now()+86400000).toISOString()})).status,409);
  const result=await json('/api/memory');assert.equal(result.status,200);
  assert.equal(result.body.source,'LOCAL_HISTORY');
  const found=result.body.posts.find(row=>row.id===old.id);
  assert.equal(found.instagramMediaId,'fixture-media-id');assert.equal(found.caption,old.caption);
  assert.ok(!JSON.stringify(result.body).includes('private-local-path'));
  assert.ok(!JSON.stringify(result.body).includes('fixture-hidden'));
  assert.equal(JSON.stringify(await store.getPosts('system')),before);
});
test('history never invents measurements or budget for an unmeasured PAUSED ad',()=>{
  const m=buildManualMemory([{id:'new',caption:'Metin',publishStatus:'READY'}],
    [{type:'WEEKLY_LAUNCH',source:'APP_AD_CREATE',adStatus:'PAUSED'}],
    {recordCount:0},{organic:{recommended:null,sampleSize:0}});
  assert.equal(m.performance.recordCount,0);assert.equal(m.timing.organic.recommended,null);
  assert.equal(m.publishedCount,0);assert.equal(m.adHistory[0].dailyBudget,null);
});
