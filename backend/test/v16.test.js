import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-v16-test-'));
Object.assign(process.env,{DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),ADVISE_DATA_DIR:path.join(fixture,'data'),ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),JWT_SECRET:'test-only-session-secret',ADMIN_USERNAME:'fixture-admin',ADMIN_PASSWORD:'fixture-password',CRON_ENABLED:'false',ADVISE_NO_LISTEN:'true',NODE_ENV:'test',META_ACCESS_TOKEN:'fixture-system-token',META_AD_ACCOUNT_ID:'999',INSTAGRAM_ACCESS_TOKEN:'fixture-instagram-token',INSTAGRAM_USER_ID:'888',GEMINI_API_KEY:'',GOOGLE_API_KEY:'',META_APP_ID:'',META_APP_SECRET:'',META_REDIRECT_URI:''});
const persistence=await import('../src/persistence.js');
const store=await import('../src/store.js');
const meta=await import('../src/meta.js');
const safety=await import('../src/automation-safety.js');
const product=await import('../src/product.js');
const pro=await import('../src/pro.js');
const memory=await import('../src/ai-memory.js');
const scheduler=await import('../src/scheduler.js');
const optimizer=await import('../src/optimizer.js');
const gemini=await import('../src/gemini-ads.js');
const auth=await import('../src/auth.js');
const nativeFetch=global.fetch;
const creds={accessToken:'fixture-tenant-token',adAccountId:'123',instagramUserId:'456',instagramAccessToken:'fixture-ig-token',pageId:'789'};
let state={sets:[],ads:[],campaigns:[],calls:[],containerStatus:'FINISHED',failPublish:false,insights:{spend:'10',impressions:'100',reach:'90',clicks:'3',ctr:'3',actions:[{action_type:'messaging_conversation_started_7d',value:'2'}]}};
const reset=()=>state={sets:[],ads:[],campaigns:[],calls:[],containerStatus:'FINISHED',failPublish:false,insights:{spend:'10',impressions:'100',reach:'90',clicks:'3',ctr:'3',actions:[{action_type:'messaging_conversation_started_7d',value:'2'}]}};
const response=data=>new Response(JSON.stringify(data),{status:200,headers:{'content-type':'application/json'}});
global.fetch=async(input,options={})=>{
  const url=new URL(String(input));if(!['graph.facebook.com','graph.instagram.com'].includes(url.host))return nativeFetch(input,options);
  const endpoint=url.pathname.replace(/^\/v\d+\.\d+\//,'').replace(/^\//,'');const body=new URLSearchParams(options.body||'');
  state.calls.push({endpoint,method:options.method||'GET',budget:body.get('daily_budget')});
  if(endpoint.endsWith('/media_publish')){if(state.failPublish)throw new Error('Fixture network lost');state.containerStatus='PUBLISHED';return response({id:'9002'});}
  if(endpoint.endsWith('/media')&&(options.method||'GET')==='POST'){assert.ok(body.get('access_token'));return response({id:'9001'});}
  if(endpoint==='9001')return response({status_code:state.containerStatus});
  if(endpoint.endsWith('/adsets'))return response({data:state.sets});
  if(endpoint.endsWith('/campaigns'))return response({data:state.campaigns});
  if(endpoint.endsWith('/ads'))return response({data:state.ads});
  if(endpoint.endsWith('/insights'))return response({data:[{date_start:'2026-10-05',...state.insights}]});
  if(endpoint.startsWith('act_'))return response({id:endpoint,account_id:endpoint.slice(4),currency:'TRY',name:'Fixture account'});
  if((options.method||'GET')==='POST') {
    const set=state.sets.find(row=>row.id===endpoint);
    if(set&&body.get('daily_budget'))set.daily_budget=body.get('daily_budget');
    if(set&&body.get('status')){set.status=body.get('status');set.effective_status=body.get('status');}
    return response({success:true});
  }
  return response({id:endpoint,account_id:endpoint==='555'?'other-account':'123'});
};
after(async()=>{global.fetch=nativeFetch;if(!path.resolve(fixture).startsWith(path.resolve(os.tmpdir())+path.sep))throw new Error('Fixture path outside temp');await fs.rm(fixture,{recursive:true,force:true});});

test('tenant credentials never use system environment as fallback',()=>{
  assert.equal(meta.resolveCredentials({}).accessToken,'');assert.equal(meta.resolveCredentials({connected:false}).adAccountId,'');
  assert.equal(meta.resolveCredentials({systemAccount:true}).adAccountId,'999');assert.equal(meta.resolveCredentials(creds).adAccountId,'123');
});
test('Meta ownership rejects an object from another account',async()=>{
  await assert.rejects(meta.setStatus('555','PAUSED',creds),/hesabına ait değil/);
});
test('budget helper converts TRY to minor units once',async()=>{
  reset();await meta.updateAdSetBudget('222',50,creds);assert.equal(state.calls.find(row=>row.method==='POST').budget,'5000');
});
test('common budget guard blocks cap overshoot and inactive activation',async()=>{
  reset();state.sets=[{id:'222',daily_budget:'50000',status:'ACTIVE'},{id:'223',daily_budget:'10000',status:'PAUSED'}];
  const settings={maxDailyBudget:700,geminiAdsDailyCap:550};
  await assert.rejects(safety.budgetGuard(creds,settings,{adSetId:'222',nextBudget:600}),/sınırı/);
  await assert.rejects(safety.budgetGuard(creds,settings,{adSetId:'223',activate:true}),/sınırı/);
  const result=await safety.budgetGuard(creds,settings,{adSetId:'222',nextBudget:450});assert.equal(result.next,450);
});
test('atomic storage preserves invalid JSON instead of erasing records',async()=>{
  const file=path.join(fixture,'broken.json');await fs.writeFile(file,'{broken');
  await assert.rejects(persistence.readJsonFile(file,{}),/korunmuştur/);assert.equal(await fs.readFile(file,'utf8'),'{broken');
});
test('reentrant cross-operation lock serializes tasks',async()=>{
  const sequence=[];await Promise.all([persistence.withDataLock(async()=>{sequence.push(1);await persistence.withDataLock(async()=>sequence.push(2));await new Promise(r=>setTimeout(r,20));sequence.push(3);}),persistence.withDataLock(async()=>sequence.push(4))]);
  assert.deepEqual(sequence,[1,2,3,4]);
});
test('parallel post/log mutations keep both tenants',async()=>{
  await Promise.all([store.savePosts('a',[{id:'a1'}]),store.savePosts('b',[{id:'b1'}])]);
  assert.equal((await store.getPosts('a'))[0].id,'a1');assert.equal((await store.getPosts('b'))[0].id,'b1');
  await Promise.all(Array.from({length:8},(_,i)=>store.addLog('a',{type:'FIXTURE',index:i})));
  assert.equal((await store.getLogs('a')).filter(row=>row.type==='FIXTURE').length,8);
});
test('CRM update cannot change tenant or identity',async()=>{
  const lead=await pro.createLead('a',{name:'Fixture lead',status:'NEW'});
  const next=await pro.updateLead('a',lead.id,{tenantId:'b',id:'changed',name:'Updated',status:'WON',adId:'123'});
  assert.equal(next.tenantId,'a');assert.equal(next.id,lead.id);assert.equal(next.status,'WON');
  await assert.rejects(pro.updateLead('b',lead.id,{name:'Cross tenant'}),/bulunamadı/);
  await assert.rejects(pro.updateLead('a',lead.id,{status:'FAKE'}),/durumu/);
});
test('public tenant/report contains no credential fields',async()=>{
  await store.createTenant({companyName:'Fixture',plan:'AGENCY'});const tenant=(await store.getTenants()).find(row=>row.id!=='system');
  await store.updateTenant(tenant.id,{meta:{...creds,oauthAssets:{accessToken:'fixture-pending'}}});
  const report=await pro.reportPack(tenant.id);assert.equal(report.tenant.meta.accessToken,undefined);assert.equal(report.tenant.meta.oauthAssets,undefined);
});
test('report dates use inclusive local calendar boundaries',()=>{
  const now=new Date('2026-10-04T22:00:00Z');assert.deepEqual(product.reportRange({range:'7d'},now),{range:'7d',since:'2026-09-29',until:'2026-10-05'});
  assert.throws(()=>product.reportRange({range:'custom',since:'2026-02-30',until:'2026-10-05'},now));
});
test('equivalent messaging action types are not double counted',()=>{
  const metrics=product.metricsFor({spend:20,actions:[{action_type:'onsite_conversion.messaging_conversation_started_7d',value:4},{action_type:'messaging_conversation_started_7d',value:4}]});
  assert.equal(metrics.messages,4);assert.equal(metrics.cpa,5);
});
test('disconnected tenant reporting has null metrics and no system calls',async()=>{
  reset();const report=await product.productReport('missing-tenant',{range:'today'});assert.equal(report.available,false);assert.equal(report.metrics.spend,null);assert.equal(state.calls.length,0);
});
test('onboarding resumes and requires real connected assets to complete',async()=>{
  const tenant=await store.createTenant({companyName:'Setup fixture',plan:'AGENCY'});
  const next=await product.saveOnboarding(tenant.id,{businessName:'Store',industry:'Retail',dailyBudget:250,locationMode:'REGION',locations:['Karadeniz'],step:3});
  assert.equal(next.step,3);assert.equal((await product.onboardingStatus(tenant.id)).industry,'Retail');
  await assert.rejects(product.saveOnboarding(tenant.id,{completed:true}),/tamamlayın/);
});
test('memory insights remain empty before measured outcomes',async()=>{
  await memory.learnFromGeneration('unmeasured',{source:'GEMINI',hook:'Fixture hook',recommendedFormat:'POST',recommendedPostTime:'19:30'});
  const summary=await memory.getMemorySummary('unmeasured');assert.equal(summary.generationCount,1);assert.equal(summary.hasMeasuredInsights,false);assert.deepEqual(summary.bestHooks,[]);
});
test('Memory Palace v2 learns hook types and ranks sector-relevant examples before unrelated winners',async()=>{
  const tenantId='memory-v2-fixture';
  await memory.learnFromGeneration(tenantId,{productName:'Espresso Pro',brand:'Fixture',model:'E1',industry:'Kafe',productCategory:'Kahve',hook:'Kahven neden istediğin gibi olmuyor?',hookType:'SORU',caption:'Espresso Pro ile kahve hazırlama deneyimini görseldeki gerçek detaylar üzerinden anlat.',contentAngle:'Sorun çözüm',selectedTone:'uzman',recommendedFormat:'REELS',recommendedPostTime:'19:30',targetAudience:'Kahve severler',visualSummary:'Tezgah üzerinde espresso makinesi',source:'GEMINI'},{generationId:'mem-sector',postId:'post-sector',mediaType:'IMAGE'});
  await memory.learnFromOutcome(tenantId,{generationId:'mem-sector',postId:'post-sector',adId:'ad-sector',spend:20,messages:10,ctr:3,messageCost:0.5});
  await memory.learnFromGeneration(tenantId,{productName:'Telefon Kılıfı',industry:'Aksesuar',productCategory:'Telefon Aksesuarı',hook:'Telefonunu koru',hookType:'FAYDA',caption:'Telefon kılıfı için güçlü koruma anlatımı.',contentAngle:'Fayda',selectedTone:'dinamik',recommendedFormat:'POST',recommendedPostTime:'20:00',targetAudience:'Telefon kullanıcıları',visualSummary:'Telefon kılıfı',source:'GEMINI'},{generationId:'mem-unrelated',postId:'post-unrelated',mediaType:'IMAGE'});
  await memory.learnFromOutcome(tenantId,{generationId:'mem-unrelated',postId:'post-unrelated',adId:'ad-unrelated',spend:20,messages:20,ctr:4,messageCost:0.2});
  const context=await memory.buildMemoryContext(tenantId,{title:'Espresso Pro kahve makinesi',context:'espresso kahve hazırlama',industry:'Kafe',productCategory:'Kahve',visualSummary:'Tezgah üzerinde espresso makinesi',mediaType:'IMAGE',hook:'Kahven neden istediğin gibi olmuyor?'});
  assert.ok(context.indexOf('Espresso Pro')>=0);assert.ok(context.indexOf('Espresso Pro')<context.indexOf('Telefon Kılıfı'));assert.match(context,/Performansla güçlenen hook tipleri:/);assert.match(context,/Novelty uyarısı:/);
  const summary=await memory.getMemorySummary(tenantId);assert.ok(summary.bestHookTypes.some(row=>row.value==='SORU'));
});
test('concurrent and repeated publish produces only one remote publish',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Publish fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});
  await store.savePosts(tenant.id,[{id:'post1',publicUrl:'https://fixture.invalid/image.jpg',publishStatus:'QUEUED',nextPublishAt:new Date(Date.now()-10000).toISOString(),autoPublish:true}]);
  const results=await Promise.all([scheduler.publishPost(tenant.id,'post1'),scheduler.publishPost(tenant.id,'post1')]);
  assert.ok(results.every(row=>row.publishStatus==='PUBLISHED'));assert.equal(state.calls.filter(row=>row.endpoint.endsWith('/media_publish')).length,1);
});
test('ambiguous publish holds same container and reconciles instead of duplicating',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Ambiguous fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});
  await store.savePosts(tenant.id,[{id:'ambiguous',publicUrl:'https://fixture.invalid/image.jpg',publishStatus:'QUEUED',nextPublishAt:new Date().toISOString()}]);state.failPublish=true;
  await assert.rejects(scheduler.publishPost(tenant.id,'ambiguous'));let saved=(await store.getPosts(tenant.id))[0];assert.equal(saved.publishStatus,'RECONCILE');assert.equal(saved.instagramContainerId,'9001');
  state.containerStatus='PUBLISHED';state.failPublish=false;await scheduler.publishPost(tenant.id,'ambiguous');
  assert.equal(state.calls.filter(row=>row.endpoint.endsWith('/media_publish')).length,1);
});
test('weekly launch gate retries after an explicit failed attempt but blocks unresolved starts',()=>{
  const week='2026-10-05-d1';
  assert.equal(scheduler.weeklyLaunchGate([{type:'WEEKLY_LAUNCH_STARTED',week,at:'2026-10-05T10:00:00Z'}],week).blocked,true);
  const retry=scheduler.weeklyLaunchGate([{type:'WEEKLY_LAUNCH_ERROR',week,at:'2026-10-05T10:01:00Z',error:'fixture'},{type:'WEEKLY_LAUNCH_STARTED',week,at:'2026-10-05T10:00:00Z'}],week);assert.equal(retry.blocked,false);assert.equal(retry.retry,true);
  assert.equal(scheduler.weeklyLaunchGate([{type:'WEEKLY_LAUNCH',week,at:'2026-10-05T10:02:00Z'},{type:'WEEKLY_LAUNCH_ERROR',week,at:'2026-10-05T10:01:00Z'}],week).blocked,true);
});
test('optimizer does not finish a review before minimum spend is reached',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Optimizer fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});await store.saveSettings(tenant.id,{enabled:true,geminiAdsDailyCap:500});
  state.ads=[{id:'100',adset_id:'222',status:'ACTIVE',created_time:new Date(Date.now()-13*3600000).toISOString()}];state.sets=[{id:'222',daily_budget:'50000',status:'ACTIVE'}];
  const result=await optimizer.optimizeAds(tenant.id);assert.equal(result.actions[0].action,'WAIT_MIN_SPEND');assert.equal((await store.getLogs(tenant.id)).filter(row=>row.type==='EARLY_REVIEW_DONE').length,0);
});
test('optimizer deduplicates equivalent Meta messaging actions before CPA decisions',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Optimizer duplicate fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});await store.saveSettings(tenant.id,{enabled:true,earlyMessageCostLimit:30,earlyMinSpendBeforeDecision:1,autoPause:true,autoReallocate:false,minDailyBudget:25,geminiAdsDailyCap:500});
  state.ads=[{id:'101',adset_id:'221',status:'ACTIVE',created_time:new Date(Date.now()-13*3600000).toISOString()}];state.sets=[{id:'221',daily_budget:'10000',status:'ACTIVE'}];state.insights={spend:'100',impressions:'1000',reach:'900',clicks:'30',ctr:'3',actions:[{action_type:'onsite_conversion.messaging_conversation_started_7d',value:'2'},{action_type:'messaging_conversation_started_7d',value:'2'}]};
  const result=await optimizer.optimizeAds(tenant.id);const review=result.actions.find(row=>row.adId==='101');assert.equal(review.action,'PAUSED_12H',review.reason);assert.equal(review.metrics.messages,2);assert.equal(review.metrics.messageCost,50);
});
test('Gemini automatic activation cannot reopen a manual pause',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Gemini fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});await store.saveSettings(tenant.id,{geminiAdsDailyCap:500});state.sets=[{id:'222',daily_budget:'10000',status:'PAUSED',effective_status:'PAUSED',campaign_id:'333',targeting:{geo_locations:{countries:['TR']}}}];
  await assert.rejects(gemini.applyGeminiAdDecision(tenant.id,{adSetId:'222',action:'ACTIVATE',automatic:true}),/Elle durdurulmuş/);assert.equal(state.calls.filter(row=>row.method==='POST').length,0);
});
test('notifications deduplicate a persisted event and remain readable',async()=>{
  const a=await pro.createAlert('notifications',{title:'Real event',sourceEventId:'event1'}),b=await pro.createAlert('notifications',{title:'Duplicate',sourceEventId:'event1'});assert.equal(a.id,b.id);await pro.markAlert('notifications',a.id,true);assert.equal((await pro.getAlerts('notifications'))[0].read,true);
});
test('manual budget route enforces configured safety caps before mutation',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Budget route fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});await store.saveSettings(tenant.id,{geminiAdsDailyCap:150,maxDailyBudget:200});
  state.sets=[{id:'budget-safe-set',daily_budget:'10000',status:'ACTIVE',effective_status:'ACTIVE'}];
  await auth.createTenantUser({tenantId:tenant.id,username:'budget-manager',password:'manager-password',role:'MANAGER'});const session=await auth.login('budget-manager','manager-password');
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));const base=`http://127.0.0.1:${listener.address().port}`;
  try {
    const blocked=await nativeFetch(`${base}/api/budget/budget-safe-set`,{method:'POST',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify({dailyBudget:250})});assert.equal(blocked.status,502);assert.equal(state.calls.filter(row=>row.method==='POST').length,0);
    const allowed=await nativeFetch(`${base}/api/budget/budget-safe-set`,{method:'POST',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify({dailyBudget:150})});assert.equal(allowed.status,200);assert.equal(state.calls.filter(row=>row.method==='POST').length,1);
  } finally {await new Promise(resolve=>listener.close(resolve));}
});
test('HTTP capability, auth, viewer enforcement and callback reachability',async()=>{
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));const base=`http://127.0.0.1:${listener.address().port}`;
  try {
    const health=await nativeFetch(`${base}/health`).then(r=>r.json());assert.equal(health.version,'16.0.0');assert.equal(health.capabilities.safeAutomationV16,true);
    const callback=await nativeFetch(`${base}/api/meta/oauth/callback?error=access_denied`);assert.equal(callback.status,200);assert.match(await callback.text(),/bağlantısı tamamlanamadı/);
    assert.equal((await nativeFetch(`${base}/api/posts`)).status,401);
    const adminSession=await auth.login('fixture-admin','fixture-password');const connect=await nativeFetch(`${base}/api/meta/connect/start`,{headers:{authorization:`Bearer ${adminSession.token}`}});assert.equal(connect.status,503);assert.match((await connect.json()).error,/Meta bağlantı kurulumu/);assert.equal(state.calls.filter(row=>row.endpoint==='me').length,0);
    const tenant=await store.createTenant({companyName:'Viewer fixture',plan:'AGENCY'});await auth.createTenantUser({tenantId:tenant.id,username:'fixture-viewer',password:'viewer-password',role:'VIEWER'});const session=await auth.login('fixture-viewer','viewer-password');
    const forbidden=await nativeFetch(`${base}/api/pro/leads`,{method:'POST',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify({name:'Should not write'})});assert.equal(forbidden.status,403);
    const agency=await nativeFetch(`${base}/api/pro/agency`,{headers:{authorization:`Bearer ${session.token}`}});assert.equal(agency.status,403);
    const overview=await nativeFetch(`${base}/api/product/overview`,{headers:{authorization:`Bearer ${session.token}`}});assert.equal(overview.status,200);const data=await overview.json();assert.equal(data.metrics.spend,null);assert.equal(data.me.tenant.meta.accessToken,undefined);
  } finally {await new Promise(resolve=>listener.close(resolve));}
});
