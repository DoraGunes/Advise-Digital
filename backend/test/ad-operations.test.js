import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-ad-operations-'));
Object.assign(process.env,{DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),ADVISE_DATA_DIR:fixture,ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),ADVISE_NO_LISTEN:'true',CRON_ENABLED:'false',JWT_SECRET:'fixture-only-session-secret',ADMIN_USERNAME:'fixture-admin',ADMIN_PASSWORD:'fixture-password',GEMINI_API_KEY:'',GOOGLE_API_KEY:'',META_ACCESS_TOKEN:'fixture-only',META_AD_ACCOUNT_ID:'123'});
const {runAdOperation,getAdOperation,operationFailure}=await import('../src/ad-operations.js');
const {withTenantLock}=await import('../src/persistence.js');
const {boundedRead}=await import('../src/operation-budget.js');
const {callGemini,safeGeminiError}=await import('../src/ai.js');
const {adsPreflight}=await import('../src/meta.js');
after(async()=>{assert.ok(fixture.startsWith(os.tmpdir()));await fs.rm(fixture,{recursive:true,force:true});});
const requestId='fixture-request-id-0001';
const args=(tenantId,steps)=>({tenantId,requestId,payload:{media:'123',budget:100},prepare:async()=>({}),steps,complete:async operation=>({ok:true,ids:operation.ids})});

test('duplicate and concurrent create reuses durably saved Meta IDs',async()=>{
  let calls=0;const input=args('duplicate',[['campaign',async()=>({id:String(++calls)})],['adset',async()=>({id:String(++calls)})]]);
  const results=await Promise.all([runAdOperation(input),runAdOperation(input)]);
  assert.equal(calls,2);assert.deepEqual(results[0],results[1]);
  assert.equal((await getAdOperation('duplicate',requestId)).status,'SUCCEEDED');
  assert.equal(await getAdOperation('other-tenant',requestId),null);
  await assert.rejects(runAdOperation({...input,payload:{budget:200}}),{code:'IDEMPOTENCY_CONFLICT'});
});
test('known provider rejection resumes from partial IDs without another campaign',async()=>{
  let campaignCalls=0,fail=true;
  const input=args('partial',[['campaign',async()=>({id:String(++campaignCalls)})],['adset',async()=>{if(fail)throw Object.assign(new Error('İzin gerekli.'),{code:'META_PERMISSION_DENIED',status:403});return {id:'set-1'};}]]);
  await assert.rejects(runAdOperation(input));
  const saved=await getAdOperation('partial',requestId);assert.equal(saved.status,'PARTIAL_FAILED');assert.equal(saved.ids.campaign,'1');assert.equal(saved.failure.stage,'adset');
  fail=false;await runAdOperation(input);assert.equal(campaignCalls,1);
});
test('network timeout after write is reconcile-only; retry cannot duplicate',async()=>{
  let calls=0;const input=args('ambiguous',[['campaign',async()=>{calls++;throw Object.assign(new Error('timeout'),{code:'ETIMEDOUT'});}]]);
  await assert.rejects(runAdOperation(input));assert.equal((await getAdOperation('ambiguous',requestId)).status,'RECONCILE');
  await assert.rejects(runAdOperation(input),{code:'AD_RECONCILE_REQUIRED'});assert.equal(calls,1);
});
test('crash checkpoint cannot be blindly replayed and missing response ID is ambiguous',async()=>{
  await assert.rejects(runAdOperation(args('missing-id',[['campaign',async()=>({success:true})]])));
  assert.equal((await getAdOperation('missing-id',requestId)).status,'RECONCILE');
});
test('preflight failure makes no remote write and error contract redacts payloads',async()=>{
  let calls=0;const input=args('preflight',[['campaign',async()=>{calls++;return{id:'1'};}]]);
  await assert.rejects(runAdOperation({...input,prepare:async()=>{throw Object.assign(new Error('access_token=fixture-secret'),{code:'META_SESSION_EXPIRED',status:401});}}));
  assert.equal(calls,0);assert.equal((await getAdOperation('preflight',requestId)).status,'FAILED');
  assert.ok(!JSON.stringify(operationFailure(new Error('secret=fixture-secret'),'campaign','safe-id')).includes('fixture-secret'));
});
test('cancelled lock waiter cannot allow a successor to overtake owner',async()=>{
  let release,inside=false;const first=withTenantLock('busy',async()=>{inside=true;await new Promise(resolve=>release=resolve);inside=false;});
  while(!inside)await new Promise(resolve=>setTimeout(resolve,1));
  await assert.rejects(withTenantLock('busy',()=>assert.fail('cancelled waiter ran'),{timeoutMs:10}),{code:'OPERATION_BUSY'});
  let third=false;const last=withTenantLock('busy',()=>{assert.equal(inside,false);third=true;});
  await new Promise(resolve=>setTimeout(resolve,15));assert.equal(third,false);release();await Promise.all([first,last]);assert.equal(third,true);
});
test('Gemini SDK that ignores timeout still terminates within aggregate budget',async()=>{
  const start=Date.now();
  await assert.rejects(callGemini({prompt:'fixture',overallTimeoutMs:30},{client:{interactions:{create:()=>new Promise(()=>{})}}}),{code:'ETIMEDOUT'});
  assert.ok(Date.now()-start<1000);
});
test('Gemini completed JSON returns model and malformed output never claims success',async()=>{
  const result=await callGemini({prompt:'fixture',overallTimeoutMs:30},{client:{interactions:{create:async()=>({status:'completed',output_text:'{"hook":"fixture"}'})}}});assert.equal(result.parsed.hook,'fixture');assert.ok(result.model);
  await assert.rejects(callGemini({prompt:'fixture',overallTimeoutMs:30},{client:{interactions:{create:async()=>({status:'completed',output_text:'{broken'})}}}));
  for(const status of [401,403,429,503])assert.notEqual(safeGeminiError({status,message:'fixture provider error'}).message,'fixture provider error');
});
test('read timeout is bounded and supplies cancellation signal',async()=>{
  let signal;await assert.rejects(boundedRead(value=>{signal=value;return new Promise(()=>{});},10),{code:'ETIMEDOUT'});assert.equal(signal.aborted,true);
});
test('Meta preflight validates actual account, permission, Page, Instagram and WhatsApp evidence',async()=>{
  const native=global.fetch;let failure='';
  global.fetch=async input=>{
    const url=new URL(input),endpoint=url.pathname.split('/').at(-1);
    if(failure==='expired')return new Response(JSON.stringify({error:{code:190,message:'access_token=fixture-secret'}}),{status:400});
    const result=endpoint==='act_123'?{id:'act_123',account_id:'123',currency:'TRY',account_status:1,disable_reason:0,timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']}:endpoint==='permissions'?{data:[{permission:'ads_management',status:failure==='permission'?'declined':'granted'},{permission:'pages_read_engagement',status:'granted'}]}:{id:'456',is_published:true,instagram_business_account:{id:'789'},has_whatsapp_number:failure!=='whatsapp'};
    return new Response(JSON.stringify(result),{status:200});
  };
  const credentials={accessToken:'fixture-only',adAccountId:'123',pageId:'456',instagramUserId:'789'};
  try {
    assert.equal((await adsPreflight(credentials)).destination,'WHATSAPP');
    for(const [value,code]of [['permission','META_PERMISSION_DENIED'],['whatsapp','META_WHATSAPP_MISSING'],['expired','META_SESSION_EXPIRED']]){failure=value;await assert.rejects(adsPreflight(credentials),{code});}
  } finally {global.fetch=native;}
});

test('authenticated HTTP create passes preflight, resumes rejection and returns same completed ad',async()=>{
  const store=await import('../src/store.js'),auth=await import('../src/auth.js');
  const tenant=await store.createTenant({companyName:'Ad operation fixture',plan:'AGENCY'});
  await store.updateTenant(tenant.id,{meta:{connected:true,accessToken:'fixture-only',adAccountId:'123',pageId:'456',instagramUserId:'789',instagramAccessToken:'fixture-instagram-only'}});
  await store.saveSettings(tenant.id,{geminiAdsDailyCap:300,maxDailyBudget:300});
  await auth.createTenantUser({tenantId:tenant.id,username:'fixture-ad-manager',password:'fixture-manager-password',role:'MANAGER'});
  const session=await auth.login('fixture-ad-manager','fixture-manager-password');
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));
  const base=`http://127.0.0.1:${listener.address().port}`,native=global.fetch,counts={campaigns:0,adsets:0,adcreatives:0,ads:0};let rejectAdSet=true;
  global.fetch=async(input,options={})=>{
    const url=new URL(input);if(url.hostname==='127.0.0.1')return native(input,options);
    const endpoint=url.pathname.split('/').at(-1);
    let result;
    if(options.method==='POST') {
      counts[endpoint]++;
      if(endpoint==='adsets'&&rejectAdSet)return new Response(JSON.stringify({error:{code:200,message:'fixture permission denied'}}),{status:403});
      assert.equal(new URLSearchParams(options.body).get('status'),endpoint==='adcreatives'?null:'PAUSED');
      result={id:String({campaigns:1001,adsets:1002,adcreatives:1003,ads:1004}[endpoint])};
    } else if(endpoint==='act_123')result={id:'act_123',account_id:'123',currency:'TRY',account_status:1,disable_reason:0,timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']};
    else if(endpoint==='permissions')result={data:[{permission:'ads_management',status:'granted'},{permission:'pages_read_engagement',status:'granted'}]};
    else if(endpoint==='456')result={id:'456',is_published:true,instagram_business_account:{id:'789'},has_whatsapp_number:true};
    else if(endpoint==='media')result={data:[{id:'901',media_type:'IMAGE'}]};
    else result={data:[]};
    return new Response(JSON.stringify(result),{status:200});
  };
  const body={requestId:'http-fixture-request-0001',instagramMediaId:'901',dailyBudget:100,activate:false};
  const send=()=>native(`${base}/api/ads/create`,{method:'POST',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify(body)});
  try {
    const failure=await send();assert.equal(failure.status,502);const data=await failure.json();assert.equal(data.code,'META_PERMISSION_DENIED');assert.equal(data.stage,'adset');assert.ok(data.correlationId);
    rejectAdSet=false;const success=await send();assert.equal(success.status,201);const result=await success.json();assert.equal(result.ad.id,'1004');assert.equal(result.activated,false);
    const duplicate=await send();assert.equal(duplicate.status,201);assert.deepEqual(await duplicate.json(),result);
    assert.deepEqual(counts,{campaigns:1,adsets:2,adcreatives:1,ads:1});
    const health=await native(`${base}/health`).then(response=>response.json());assert.equal(health.capabilities.adCreateSaga,true);
  } finally {global.fetch=native;listener.closeAllConnections();await new Promise(resolve=>listener.close(resolve));}
});
