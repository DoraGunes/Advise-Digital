import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {fixtureVideoFromJpeg} from './fixture-video.mjs';
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
const ai=await import('../src/ai.js');
const nativeFetch=global.fetch;
const creds={accessToken:'fixture-tenant-token',adAccountId:'123',instagramUserId:'456',instagramAccessToken:'fixture-ig-token',pageId:'789'};
let state={sets:[],ads:[],campaigns:[],calls:[],containerStatus:'FINISHED',failPublish:false,insights:{spend:'10',impressions:'100',reach:'90',clicks:'3',ctr:'3',actions:[{action_type:'messaging_conversation_started_7d',value:'2'}]}};
const reset=()=>state={sets:[],ads:[],campaigns:[],calls:[],containerStatus:'FINISHED',failPublish:false,insights:{spend:'10',impressions:'100',reach:'90',clicks:'3',ctr:'3',actions:[{action_type:'messaging_conversation_started_7d',value:'2'}]}};
const response=data=>new Response(JSON.stringify(data),{status:200,headers:{'content-type':'application/json'}});
global.fetch=async(input,options={})=>{
  const url=new URL(String(input));if(!['graph.facebook.com','graph.instagram.com'].includes(url.host))return nativeFetch(input,options);
  const endpoint=url.pathname.replace(/^\/v\d+\.\d+\//,'').replace(/^\//,'');const body=new URLSearchParams(options.body||'');
  state.calls.push({endpoint,method:options.method||'GET',budget:body.get('daily_budget')});
  if(endpoint.endsWith('/media_publish')){if(state.failPublish)throw new Error('Fixture network lost');if(state.beforePublish)await state.beforePublish();state.containerStatus='PUBLISHED';return response({id:'9002'});}
  if(endpoint.endsWith('/media')&&(options.method||'GET')==='POST'){assert.ok(body.get('access_token'));return response({id:'9001'});}
  if(endpoint==='9001')return response({status_code:state.containerStatus});
  if(endpoint.endsWith('/adsets')) {
    const snapshot=structuredClone(state.sets);
    if(state.accountReadBarrier) {
      const call=state.accountReadCount||0;state.accountReadCount=call+1;
      if(call%2===0)await new Promise(resolve=>{state.releaseAccountRead=resolve;setTimeout(resolve,2000);});
      else state.releaseAccountRead();
    }
    return response({data:snapshot});
  }
  if(endpoint.endsWith('/campaigns'))return response({data:state.campaigns});
  if(endpoint.endsWith('/ads'))return response({data:state.ads});
  if(endpoint.endsWith('/insights'))return response({data:[{date_start:'2026-10-05',...state.insights}]});
  if(endpoint.startsWith('act_'))return response({id:endpoint,account_id:endpoint.slice(4),currency:'TRY',name:'Fixture account'});
  if((options.method||'GET')==='POST') {
    if(body.get('daily_budget')&&state.beforeBudgetWrite)await state.beforeBudgetWrite(endpoint);
    const set=state.sets.find(row=>row.id===endpoint);
    if(set&&body.get('daily_budget'))set.daily_budget=body.get('daily_budget');
    if(set&&body.get('status')){set.status=body.get('status');set.effective_status=body.get('status');}
    return response({success:true});
  }
  return response({id:endpoint,account_id:endpoint==='555'?'other-account':'123'});
};
after(async()=>{global.fetch=nativeFetch;if(!path.resolve(fixture).startsWith(path.resolve(os.tmpdir())+path.sep))throw new Error('Fixture path outside temp');await fs.rm(fixture,{recursive:true,force:true});});

const strategyAnswer={goal:'WhatsApp mesajı',audienceDescription:'Seçilen bölgede işletmenin ürününe ilgi duyan kitle',dailyBudget:200,creativeTitle:'Fixture creative',creativeFormat:'POST',creativeAngle:'Ürünün gerçek faydasını göster',hook:'Ürünü yakından keşfedin',recommendedTime:'19:30',scheduleReason:'Ölçülmüş saat kazananı olmadığı için başlangıç test hipotezi',testDurationDays:7,reasons:['İşletme hedefi WhatsApp mesajı'],warnings:[]};

test('synthetic logo video is a consistent two-second indexed AVI container',async()=>{
  const jpeg=await fs.readFile(new URL('../../mobile/assets/advise_logo.jpg',import.meta.url));const {video,metadata}=fixtureVideoFromJpeg(jpeg);
  assert.equal(video.toString('ascii',0,4),'RIFF');assert.equal(video.readUInt32LE(4),video.length-8);assert.equal(video.toString('ascii',8,12),'AVI ');
  assert.equal(metadata.durationSeconds,2);assert.equal(metadata.frameCount,20);assert.equal(metadata.fps,10);assert.ok(metadata.width>0&&metadata.height>0);
  const movi=video.indexOf(Buffer.from('movi')),idx=video.indexOf(Buffer.from('idx1'));assert.ok(movi>0&&idx>movi);assert.equal(video.readUInt32LE(idx+4),20*16);
  for(let i=0;i<20;i++) {
    const at=idx+8+i*16,frame=movi+video.readUInt32LE(at+8);assert.equal(video.toString('ascii',frame,frame+4),'00dc');assert.equal(video.readUInt32LE(frame+4),jpeg.length);assert.deepEqual(video.subarray(frame+8,frame+8+jpeg.length),jpeg);
  }
});

test('Gemini media maps browser video MIME aliases in inline and uploaded inputs',async()=>{
  assert.equal(ai.normalizeGeminiMediaMime('video/quicktime'),'video/mov');assert.equal(ai.normalizeGeminiMediaMime('video/x-msvideo'),'video/avi');assert.equal(ai.normalizeGeminiMediaMime('video/x-m4v'),'video/mp4');
  assert.equal(ai.normalizeGeminiMediaMime('VIDEO/QUICKTIME; codecs=avc1'),'video/mov');assert.equal(ai.normalizeGeminiMediaMime('video/webm'),'video/webm');assert.equal(ai.normalizeGeminiMediaMime('video/unsupported'),'video/unsupported');
  const small=path.join(fixture,'small.avi');const jpeg=await fs.readFile(new URL('../../mobile/assets/advise_logo.jpg',import.meta.url));await fs.writeFile(small,fixtureVideoFromJpeg(jpeg).video);
  const inline=await ai.fileToGeminiInputPart({},small,'video/x-msvideo','REELS');assert.equal(inline.type,'video');assert.equal(inline.mime_type,'video/avi');assert.ok(inline.data);
  const large=path.join(fixture,'large-fixture.avi');const handle=await fs.open(large,'w');try {await handle.truncate(20*1024*1024+1);} finally {await handle.close();}
  const uploaded=await ai.fileToGeminiInputPart({files:{upload:async options=>{assert.equal(options.config.mimeType,'video/avi');return {state:'ACTIVE',uri:'https://fixture.invalid/provider-file',mimeType:'video/x-msvideo'};}}},large,'video/x-msvideo','REELS');
  assert.equal(uploaded.type,'video');assert.equal(uploaded.mime_type,'video/avi');assert.equal(uploaded.uri,'https://fixture.invalid/provider-file');assert.equal(uploaded.data,undefined);
});

test('campaign strategy is bounded, explicit and never an applied action',async()=>{
  reset();let requested;
  const result=await ai.generateCampaignStrategy({budgetLimit:150,accountDailyCap:300,locationMode:'CITY',locations:['Bolu'],reportAvailable:false,memoryOutcomeCount:0,profile:{businessName:'Fixture'},memoryContext:'tenant-owned context'},{request:async options=>{requested=options;return {model:'fixture-gemini',parsed:{...strategyAnswer,dailyBudget:9999}};}});
  assert.equal(result.available,true);assert.equal(result.source,'GEMINI');assert.equal(result.model,'fixture-gemini');assert.equal(result.published,false);assert.equal(result.created,false);assert.equal(result.requiresApproval,true);
  assert.equal(result.strategy.budget.dailyBudget,150);assert.deepEqual(result.strategy.audience.locations,['Bolu']);assert.ok(result.strategy.warnings.length>=3);
  assert.ok(requested.schema.required.includes('dailyBudgetMin'));assert.ok(requested.schema.required.includes('dailyBudgetMax'));assert.ok(requested.schema.required.includes('missingPrerequisites'));assert.equal(state.calls.length,0);
});

test('invalid campaign strategy output cannot turn into a fake recommendation',async()=>{
  const result=await ai.generateCampaignStrategy({budgetLimit:150},{request:async()=>({model:'fixture-gemini',parsed:{...strategyAnswer,recommendedTime:'25:99'}})});
  assert.equal(result.available,false);assert.equal(result.strategy,null);assert.equal(result.source,'UNAVAILABLE');
});

test('unconfigured Gemini strategy has no fallback creative or remote calls',async()=>{
  reset();const result=await ai.generateCampaignStrategy({budgetLimit:150});
  assert.equal(result.available,false);assert.equal(result.strategy,null);assert.equal(result.model,null);assert.equal(state.calls.length,0);
});

test('Gemini logs and failure DTOs never expose secret-bearing provider exceptions',async()=>{
  const secret='FIXTURE_PROVIDER_SECRET_ONLY',error=new Error(`Unauthorized https://fixture.invalid/?key=${secret} Authorization: Bearer ${secret} provider-body=${secret}`);error.status=401;error.code=secret;
  const captured=[],originals={log:console.log,warn:console.warn,error:console.error};console.log=(...args)=>captured.push(args);console.warn=(...args)=>captured.push(args);console.error=(...args)=>captured.push(args);
  try {
    await assert.rejects(ai.callGemini({prompt:'Synthetic private prompt',mediaParts:[]},{client:{interactions:{create:async()=>{throw error;}}}}));
    const pack=await ai.generateContentPack({title:'Fixture product'},{request:async()=>{throw error;}});
    const strategy=await ai.generateCampaignStrategy({budgetLimit:150},{request:async()=>{throw error;}});
    assert.equal(pack.errorCategory,'AUTHENTICATION_ERROR');assert.equal(strategy.available,false);assert.equal(strategy.errorCategory,'AUTHENTICATION_ERROR');
    const serialized=JSON.stringify({captured,pack,strategy,safe:ai.safeGeminiError(error)});assert.ok(!serialized.includes(secret));assert.ok(!serialized.includes('fixture.invalid'));assert.ok(!serialized.includes('Synthetic private prompt'));
    assert.ok(captured.some(row=>row[0]==='[AI GEMINI INTERACTIONS ERROR]'&&row[1].status===401));
  } finally {Object.assign(console,originals);}
});

test('campaign strategy uses only tenant-owned media memory and real report context',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Strategy fixture',plan:'AGENCY'});
  await store.updateTenant(tenant.id,{meta:{connected:true,...creds},onboarding:{businessName:'Own business',industry:'Retail',dailyBudget:250}});
  await store.saveSettings(tenant.id,{geminiAdsDailyCap:300});await store.savePosts(tenant.id,[{id:'own-media',title:'Owned creative',caption:'Owned caption',mediaType:'POST'}]);
  await memory.learnFromGeneration('other-strategy-tenant',{source:'GEMINI',productName:'FOREIGN_TENANT_ONLY_SECRET',hook:'Foreign hook'});
  let prompt='';const result=await product.productStrategy(tenant.id,{postId:'own-media'},{actorId:'fixture-operator',request:async options=>{prompt=options.prompt;return {model:'fixture-gemini',parsed:strategyAnswer};}});
  assert.equal(result.evidence.selectedPostId,'own-media');assert.equal(result.evidence.reportAvailable,true);assert.ok(prompt.includes('Owned creative'));assert.ok(prompt.includes('"spend":10'));
  assert.ok(!prompt.includes('FOREIGN_TENANT_ONLY_SECRET'));assert.ok(!prompt.includes(creds.accessToken));assert.ok(!state.calls.some(row=>row.method==='POST'));
  assert.equal((await store.getLogs(tenant.id)).find(row=>row.type==='AI_CAMPAIGN_STRATEGY_GENERATED').actorId,'fixture-operator');
  await assert.rejects(product.productStrategy(tenant.id,{postId:'foreign-media'}),/bu hesaba ait değil/);
});

test('Gemini ad metrics deduplicate aliases and missing data blocks automation',()=>{
  const metrics=gemini.actionMetrics({spend:40,actions:[{action_type:'onsite_conversion.messaging_conversation_started_7d',value:4},{action_type:'messaging_conversation_started_7d',value:4}]});
  assert.equal(metrics.messages7d,4);assert.equal(metrics.messageCost7d,10);
  assert.equal(gemini.canAutomateAdDecision({confidence:99,adSet:{metricsAvailable:false,spend7d:null}},{earlyMinSpendBeforeDecision:50}),false);
  assert.equal(gemini.canAutomateAdDecision({confidence:99,adSet:{metricsAvailable:true,spend7d:40}},{earlyMinSpendBeforeDecision:50}),false);
  assert.equal(gemini.canAutomateAdDecision({confidence:99,adSet:{metricsAvailable:true,spend7d:50}},{earlyMinSpendBeforeDecision:50}),true);
});

test('shared Meta account cap serializes mutations from different tenants',async()=>{
  reset();const a=await store.createTenant({companyName:'Shared account A',plan:'AGENCY'}),b=await store.createTenant({companyName:'Shared account B',plan:'AGENCY'});
  for(const tenant of [a,b]){await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});await store.saveSettings(tenant.id,{geminiAdsDailyCap:220});}
  state.sets=[{id:'222',daily_budget:'10000',status:'ACTIVE',effective_status:'ACTIVE',targeting:{geo_locations:{countries:['TR']}}},{id:'223',daily_budget:'10000',status:'ACTIVE',effective_status:'ACTIVE',targeting:{geo_locations:{countries:['TR']}}}];
  state.accountReadBarrier=true;
  await Promise.allSettled([gemini.applyGeminiAdDecision(a.id,{adSetId:'222',action:'INCREASE_BUDGET'}),gemini.applyGeminiAdDecision(b.id,{adSetId:'223',action:'INCREASE_BUDGET'})]);
  const total=state.sets.reduce((sum,row)=>sum+Number(row.daily_budget)/100,0);
  assert.ok(total<=220,`Shared daily cap exceeded: ${total}`);
});

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
test('tenant operation lock serializes one tenant without blocking another tenant',async()=>{
  const sequence=[];let releaseFirst;let markStarted;const hold=new Promise(resolve=>{releaseFirst=resolve;});const started=new Promise(resolve=>{markStarted=resolve;});
  const first=persistence.withTenantLock('tenant-lock-a',async()=>{sequence.push('a-start');markStarted();await hold;sequence.push('a-end');});
  await started;
  const same=persistence.withTenantLock('tenant-lock-a',async()=>sequence.push('a-second'));
  const other=persistence.withTenantLock('tenant-lock-b',async()=>sequence.push('b-run'));
  await other;assert.deepEqual(sequence,['a-start','b-run']);
  releaseFirst();await Promise.all([first,same]);assert.deepEqual(sequence,['a-start','b-run','a-end','a-second']);
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
test('CRM audit records authenticated actor for create update and delete',async()=>{
  const lead=await pro.createLead('crm-audit',{name:'Audit lead',status:'NEW'},{actorId:'user-audit'});
  await pro.updateLead('crm-audit',lead.id,{status:'CONTACTED'},{actorId:'user-audit'});
  await pro.deleteLead('crm-audit',lead.id,{actorId:'user-audit'});
  const logs=await store.getLogs('crm-audit',20);
  const events=logs.filter(row=>['LEAD_CREATED','LEAD_UPDATED','LEAD_DELETED'].includes(row.type));
  assert.deepEqual(events.map(row=>row.type),['LEAD_DELETED','LEAD_UPDATED','LEAD_CREATED']);
  assert.ok(events.every(row=>row.actorId==='user-audit'));
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
test('proactive recommendations rank real operational blockers before growth suggestions',()=>{
  const rows=product.buildProductRecommendations({
    metaConnected:false,
    onboarding:{completed:false,step:2},
    today:{available:true,metrics:{spend:100,messages:0,cpa:null,activeAds:0}},
    posts:[{id:'p1',publishStatus:'ERROR'},{id:'p2',publishStatus:'PUBLISHED'}],
    leads:[{id:'l1',status:'NEW'}],
    memory:{outcomeCount:3,learningWins:1,bestHookTypes:[{value:'SORU'}],bestFormats:[{value:'REELS'}]},
    settings:{earlyNoMessageSpendThreshold:75,earlyMessageCostLimit:2}
  });
  assert.deepEqual(rows.slice(0,4).map(row=>row.id),['connect-meta','complete-onboarding','repair-publishing','follow-up-leads']);
  assert.ok(rows.every(row=>row.evidence&&typeof row.evidence==='object'));
  assert.ok(rows.some(row=>row.action==='STUDIO')===false,'Top five should remain priority-limited when blockers exist');
});
test('proactive recommendations use measured memory when the queue is empty',()=>{
  const rows=product.buildProductRecommendations({metaConnected:true,onboarding:{completed:true},today:{available:true,metrics:{spend:10,messages:5,cpa:2,activeAds:1}},posts:[],leads:[],memory:{outcomeCount:4,learningWins:2,bestHookTypes:[{value:'MERAK'}],bestFormats:[{value:'REELS'}]},settings:{earlyNoMessageSpendThreshold:75,earlyMessageCostLimit:8}});
  const content=rows.find(row=>row.id==='prepare-next-content');assert.ok(content);assert.equal(content.action,'STUDIO');assert.match(content.body,/MERAK/);
  assert.ok(rows.some(row=>row.id==='use-memory-winner'&&row.action==='MEMORY'));
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
  assert.ok(context.indexOf('Espresso Pro')>=0);assert.ok(context.indexOf('Espresso Pro')<context.indexOf('Telefon Kılıfı'));assert.match(context,/ADVISE CONTENT MEMORY PALACE V3:/);assert.match(context,/Copy Style önerisi:/);assert.match(context,/Novelty uyarısı:/);
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
  state.sets=[{id:'224',daily_budget:'10000',status:'ACTIVE',effective_status:'ACTIVE'}];
  await auth.createTenantUser({tenantId:tenant.id,username:'budget-manager',password:'manager-password',role:'MANAGER'});const session=await auth.login('budget-manager','manager-password');
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));const base=`http://127.0.0.1:${listener.address().port}`;
  try {
    const blocked=await nativeFetch(`${base}/api/budget/224`,{method:'POST',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify({dailyBudget:250})});assert.equal(blocked.status,502);assert.equal(state.calls.filter(row=>row.method==='POST').length,0);
    const allowed=await nativeFetch(`${base}/api/budget/224`,{method:'POST',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify({dailyBudget:150})});assert.equal(allowed.status,200);assert.equal(state.calls.filter(row=>row.method==='POST').length,1);
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
    const usersDenied=await nativeFetch(`${base}/api/users`,{headers:{authorization:`Bearer ${session.token}`}});assert.equal(usersDenied.status,403);
    const prefsDenied=await nativeFetch(`${base}/api/notifications`,{method:'PUT',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify({push:false})});assert.equal(prefsDenied.status,403);
    const agency=await nativeFetch(`${base}/api/pro/agency`,{headers:{authorization:`Bearer ${session.token}`}});assert.equal(agency.status,403);
    const overview=await nativeFetch(`${base}/api/product/overview`,{headers:{authorization:`Bearer ${session.token}`}});assert.equal(overview.status,200);const data=await overview.json();assert.equal(data.metrics.spend,null);assert.equal(data.me.tenant.meta.accessToken,undefined);
  } finally {await new Promise(resolve=>listener.close(resolve));}
});

test('HTTP post edit queue cover and delete preserve pending or completed publication',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Publication guard fixture',plan:'AGENCY'});
  await auth.createTenantUser({tenantId:tenant.id,username:'publication-manager',password:'manager-password',role:'MANAGER'});
  const session=await auth.login('publication-manager','manager-password');
  const source=path.join(process.env.ADVISE_UPLOAD_DIR,'protected-fixture.mp4');await fs.writeFile(source,'fixture media');
  const posts=[{id:'publishing',publishStatus:'PUBLISHING'},{id:'reconcile',publishStatus:'RECONCILE'},{id:'published',publishStatus:'PUBLISHED'},{id:'ambiguous',publishStatus:'READY',publishAmbiguous:true},{id:'submitting',publishStatus:'RETRY',publishPhase:'SUBMITTING'}].map(row=>({...row,mediaType:'REELS',filePath:source,caption:'Original caption'}));
  await store.savePosts(tenant.id,posts);const savedBefore=await store.getPosts(tenant.id),filesBefore=await fs.readdir(process.env.ADVISE_UPLOAD_DIR);
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));const base=`http://127.0.0.1:${listener.address().port}`;
  const headers={authorization:`Bearer ${session.token}`};
  try {
    for(const post of posts) {
      const url=`${base}/api/posts/${post.id}`;
      assert.equal((await nativeFetch(url,{method:'PATCH',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({caption:'Must not change'})})).status,409);
      assert.equal((await nativeFetch(`${url}/queue`,{method:'POST',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({scheduleAt:new Date(Date.now()+3600000).toISOString()})})).status,409);
      const form=new FormData();form.append('cover',new Blob(['fixture jpeg'],{type:'image/jpeg'}),'cover.jpg');
      assert.equal((await nativeFetch(`${url}/cover`,{method:'POST',headers,body:form})).status,409);
      assert.equal((await nativeFetch(url,{method:'DELETE',headers})).status,409);
    }
    assert.deepEqual(await store.getPosts(tenant.id),savedBefore);assert.equal(await fs.readFile(source,'utf8'),'fixture media');
    assert.deepEqual(await fs.readdir(process.env.ADVISE_UPLOAD_DIR),filesBefore);assert.equal(state.calls.length,0);
    await store.savePosts(tenant.id,[...posts,{id:'draft-delete',publishStatus:'READY'}]);
    assert.equal((await nativeFetch(`${base}/api/posts/draft-delete`,{method:'DELETE',headers})).status,200);
  } finally {await new Promise(resolve=>listener.close(resolve));}
});

test('HTTP publish-due works only on the authenticated tenant queue',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Tenant publish due fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});
  await auth.createTenantUser({tenantId:tenant.id,username:'publish-due-manager',password:'manager-password',role:'MANAGER'});const session=await auth.login('publish-due-manager','manager-password');
  const pending=id=>({id,publicUrl:'https://fixture.invalid/image.jpg',publishStatus:'QUEUED',nextPublishAt:new Date(Date.now()-10000).toISOString(),autoPublish:true});
  await store.saveSettings(tenant.id,{autoPublish:true});await store.saveSettings('system',{autoPublish:true});
  await store.savePosts('system',[pending('system-only')]);await store.savePosts(tenant.id,[pending('tenant-only')]);
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));const base=`http://127.0.0.1:${listener.address().port}`;
  try {
    const result=await nativeFetch(`${base}/api/automation/publish-due`,{method:'POST',headers:{authorization:`Bearer ${session.token}`}});assert.equal(result.status,200);assert.equal((await result.json()).published,1);
    assert.equal((await store.getPosts('system'))[0].publishStatus,'QUEUED');assert.equal((await store.getPosts(tenant.id))[0].publishStatus,'PUBLISHED');
    assert.ok(state.calls.filter(row=>row.endpoint.endsWith('/media_publish')).every(row=>row.endpoint.startsWith('456/')));
  } finally {await store.savePosts('system',[]);await new Promise(resolve=>listener.close(resolve));}
});

test('HTTP disconnected budget mutation retains the account lock until its handler settles',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Disconnected budget fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});await store.saveSettings(tenant.id,{geminiAdsDailyCap:220,maxDailyBudget:220});
  state.sets=[{id:'22401',daily_budget:'10000',status:'ACTIVE'},{id:'22402',daily_budget:'10000',status:'ACTIVE'}];
  await auth.createTenantUser({tenantId:tenant.id,username:'disconnect-manager',password:'manager-password',role:'MANAGER'});const session=await auth.login('disconnect-manager','manager-password');
  let releaseWrite,writeStarted,writeFinished;const heldWrite=new Promise(resolve=>{releaseWrite=resolve;}),started=new Promise(resolve=>{writeStarted=resolve;}),finished=new Promise(resolve=>{writeFinished=resolve;});
  state.beforeBudgetWrite=async id=>{if(id==='22401'){writeStarted();await heldWrite;queueMicrotask(writeFinished);}};
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));const base=`http://127.0.0.1:${listener.address().port}`;
  const headers={authorization:`Bearer ${session.token}`,'content-type':'application/json'},controller=new AbortController();
  try {
    const first=nativeFetch(`${base}/api/budget/22401`,{method:'POST',headers,body:JSON.stringify({dailyBudget:115}),signal:controller.signal}).catch(error=>error);
    await Promise.race([started,first.then(result=>{throw new Error(`Fixture budget did not reach write: ${result.status||result.name}`);})]);controller.abort();await first;
    await new Promise(resolve=>setTimeout(resolve,100));
    const second=nativeFetch(`${base}/api/budget/22402`,{method:'POST',headers,body:JSON.stringify({dailyBudget:115})});
    await Promise.race([second,new Promise(resolve=>setTimeout(resolve,1000))]);releaseWrite();await finished;await second;
    await persistence.withTenantLock(tenant.id,async()=>{});
    const total=state.sets.reduce((sum,row)=>sum+Number(row.daily_budget)/100,0);assert.ok(total<=220,`Disconnected mutation exceeded cap: ${total}`);
    assert.equal((await nativeFetch(`${base}/api/posts/not-found`,{method:'DELETE',headers})).status,404,'Completed/error handlers must release the tenant lock');
  } finally {releaseWrite();await new Promise(resolve=>listener.close(resolve));}
});

test('HTTP post writes wait for the scheduler publication lock and re-read its final status',async()=>{
  reset();const tenant=await store.createTenant({companyName:'Concurrent publication fixture',plan:'AGENCY'});await store.updateTenant(tenant.id,{meta:{connected:true,...creds}});
  await auth.createTenantUser({tenantId:tenant.id,username:'concurrent-post-manager',password:'manager-password',role:'MANAGER'});const session=await auth.login('concurrent-post-manager','manager-password');
  const source=path.join(process.env.ADVISE_UPLOAD_DIR,'concurrent-post-fixture.mp4');await fs.writeFile(source,'fixture video');
  await store.savePosts(tenant.id,[{id:'held-publication',mediaType:'REELS',caption:'Original',filePath:source,publicUrl:'https://fixture.invalid/video.mp4',publishStatus:'READY'}]);
  const filesBefore=await fs.readdir(process.env.ADVISE_UPLOAD_DIR);let releasePublish,markStarted;const hold=new Promise(resolve=>{releasePublish=resolve;}),started=new Promise(resolve=>{markStarted=resolve;});state.beforePublish=async()=>{markStarted();await hold;};
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));const base=`http://127.0.0.1:${listener.address().port}`,headers={authorization:`Bearer ${session.token}`};
  const publishing=scheduler.publishPost(tenant.id,'held-publication');await started;assert.equal((await store.getPosts(tenant.id))[0].publishStatus,'PUBLISHING');
  try {
    let settled=0;const url=`${base}/api/posts/held-publication`,form=new FormData();form.append('cover',new Blob(['fixture jpeg'],{type:'image/jpeg'}),'cover.jpg');
    const requests=[nativeFetch(url,{method:'PATCH',headers:{...headers,'content-type':'application/json'},body:JSON.stringify({caption:'Must not change'})}),nativeFetch(`${url}/queue`,{method:'POST',headers:{...headers,'content-type':'application/json'},body:'{}'}),nativeFetch(`${url}/cover`,{method:'POST',headers,body:form}),nativeFetch(url,{method:'DELETE',headers})].map(p=>p.then(result=>{settled++;return result;}));
    await new Promise(resolve=>setTimeout(resolve,100));assert.equal(settled,0,'Post writes must wait for the active publisher');
    releasePublish();await publishing;const responses=await Promise.all(requests);assert.ok(responses.every(row=>row.status===409));
    const saved=(await store.getPosts(tenant.id))[0];assert.equal(saved.publishStatus,'PUBLISHED');assert.equal(saved.caption,'Original');assert.equal(await fs.readFile(source,'utf8'),'fixture video');assert.deepEqual(await fs.readdir(process.env.ADVISE_UPLOAD_DIR),filesBefore);
  } finally {releasePublish();await publishing;await new Promise(resolve=>listener.close(resolve));}
});
