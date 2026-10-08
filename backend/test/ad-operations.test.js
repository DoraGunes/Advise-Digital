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
test('Gemini SDK internal retries are disabled so quota errors reach model fallback promptly',async()=>{
  let sdkOptions;
  const result=await callGemini({prompt:'fixture',overallTimeoutMs:1000,maxAttempts:1},{client:{interactions:{create:async(_payload,options)=>{sdkOptions=options;return {status:'completed',output_text:'{"hook":"fixture"}'};}}}});
  assert.equal(result.parsed.hook,'fixture');
  assert.deepEqual(sdkOptions.retries,{strategy:'none'});
  assert.equal(sdkOptions.maxRetries,undefined);
});
test('Gemini completed JSON returns model and malformed output never claims success',async()=>{
  const result=await callGemini({prompt:'fixture',overallTimeoutMs:30},{client:{interactions:{create:async()=>({status:'completed',output_text:'{"hook":"fixture"}'})}}});assert.equal(result.parsed.hook,'fixture');assert.ok(result.model);
  await assert.rejects(callGemini({prompt:'fixture',overallTimeoutMs:30},{client:{interactions:{create:async()=>({status:'completed',output_text:'{broken'})}}}));
  for(const status of [401,403,429,503])assert.notEqual(safeGeminiError({status,message:'fixture provider error'}).message,'fixture provider error');
});
test('read timeout is bounded and supplies cancellation signal',async()=>{
  let signal;await assert.rejects(boundedRead(value=>{signal=value;return new Promise(()=>{});},10),{code:'ETIMEDOUT'});assert.equal(signal.aborted,true);
});
function mockWhatsAppPreflight({wabaVisible=true,phoneId='phone-789',permissions=['whatsapp_business_management','whatsapp_business_messaging']}={}) {
  let wabaReads=0,phoneReads=0;
  global.fetch=async input=>{
    const url=new URL(input),path=url.pathname.split('/').filter(Boolean),endpoint=path.at(-1);
    let result;
    if(endpoint==='act_123')result={id:'act_123',account_id:'123',currency:'TRY',account_status:1,disable_reason:0,timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']};
    else if(endpoint==='permissions')result={data:[{permission:'ads_management',status:'granted'},{permission:'pages_read_engagement',status:'granted'},...permissions.map(permission=>({permission,status:'granted'}))]};
    else if(endpoint==='456')result={id:'456',is_published:true,instagram_business_account:{id:'789'},has_whatsapp_business_number:false,has_whatsapp_number:false};
    else if(endpoint==='waba-456'){wabaReads++;if(!wabaVisible)return new Response(JSON.stringify({error:{code:200,message:'permission denied'}}),{status:403});result={id:'waba-456'};}
    else if(endpoint==='phone_numbers'){phoneReads++;result={data:[{id:phoneId}]};}
    else result={data:[]};
    return new Response(JSON.stringify(result),{status:200});
  };
  return {get wabaReads(){return wabaReads;},get phoneReads(){return phoneReads;}};
}
const whatsappCredentials={accessToken:'fixture-only',adAccountId:'123',pageId:'456',instagramUserId:'789',metaWhatsappWabaId:'waba-456',metaWhatsappPhoneNumberId:'phone-789'};

test('WhatsApp asset preflight: false Page flags pass with verified configured WABA and phone',async()=>{
  const native=global.fetch,mock=mockWhatsAppPreflight();
  try {const result=await adsPreflight(whatsappCredentials,{destination:'WHATSAPP'});assert.deepEqual(result.whatsappPageFlags,{hasBusinessNumber:false,hasNumber:false});assert.equal(result.whatsappAssetVerified,true);assert.equal(mock.wabaReads,1);assert.equal(mock.phoneReads,1);} finally {global.fetch=native;}
});
test('WhatsApp asset preflight: inaccessible configured WABA fails closed',async()=>{
  const native=global.fetch;mockWhatsAppPreflight({wabaVisible:false});
  try {await assert.rejects(adsPreflight(whatsappCredentials,{destination:'WHATSAPP'}),{code:'META_WHATSAPP_MISSING'});} finally {global.fetch=native;}
});
test('WhatsApp asset preflight: phone ID outside configured WABA fails closed',async()=>{
  const native=global.fetch;mockWhatsAppPreflight({phoneId:'different-phone'});
  try {await assert.rejects(adsPreflight(whatsappCredentials,{destination:'WHATSAPP'}),{code:'META_WHATSAPP_MISSING'});} finally {global.fetch=native;}
});
test('WhatsApp asset preflight: missing business management permission fails closed',async()=>{
  const native=global.fetch;mockWhatsAppPreflight({permissions:['whatsapp_business_messaging']});
  try {await assert.rejects(adsPreflight(whatsappCredentials,{destination:'WHATSAPP'}),{code:'META_WHATSAPP_MISSING'});} finally {global.fetch=native;}
});
test('WhatsApp asset preflight: non-WhatsApp destination skips WhatsApp validation',async()=>{
  const native=global.fetch,mock=mockWhatsAppPreflight({wabaVisible:false,permissions:[]});
  try {const result=await adsPreflight({...whatsappCredentials,metaWhatsappWabaId:'',metaWhatsappPhoneNumberId:''},{destination:'INSTAGRAM'});assert.equal(result.destination,'INSTAGRAM');assert.equal(result.whatsappAssetVerified,false);assert.equal(mock.wabaReads,0);assert.equal(mock.phoneReads,0);} finally {global.fetch=native;}
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

test('WhatsApp preflight failure returns actionable status without creating Meta objects',async()=>{
  const store=await import('../src/store.js'),auth=await import('../src/auth.js');
  const tenant=await store.createTenant({companyName:'WhatsApp preflight fixture',plan:'AGENCY'});
  await store.updateTenant(tenant.id,{meta:{connected:true,accessToken:'fixture-only',adAccountId:'123',pageId:'456',instagramUserId:'789',instagramAccessToken:'fixture-instagram-only'}});
  await store.saveSettings(tenant.id,{geminiAdsDailyCap:300,maxDailyBudget:300});
  await auth.createTenantUser({tenantId:tenant.id,username:'fixture-whatsapp-manager',password:'fixture-manager-password',role:'MANAGER'});
  const session=await auth.login('fixture-whatsapp-manager','fixture-manager-password');
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));
  const base=`http://127.0.0.1:${listener.address().port}`,native=global.fetch;let metaWrites=0;
  global.fetch=async(input,options={})=>{
    const url=new URL(input);if(url.hostname==='127.0.0.1')return native(input,options);
    if(options.method==='POST'){metaWrites++;return new Response(JSON.stringify({id:'unexpected'}),{status:200});}
    const endpoint=url.pathname.split('/').at(-1);
    const result=endpoint==='act_123'?{id:'act_123',account_id:'123',currency:'TRY',account_status:1,disable_reason:0,timezone_name:'Europe/Istanbul',user_tasks:['ADVERTISE']}:endpoint==='permissions'?{data:[{permission:'ads_management',status:'granted'},{permission:'pages_read_engagement',status:'granted'}]}:{id:'456',is_published:true,instagram_business_account:{id:'789'},has_whatsapp_business_number:false,has_whatsapp_number:false};
    return new Response(JSON.stringify(result),{status:200});
  };
  try {
    const response=await native(`${base}/api/ads/create`,{method:'POST',headers:{authorization:`Bearer ${session.token}`,'content-type':'application/json'},body:JSON.stringify({requestId:'whatsapp-preflight-fixture-0001',instagramMediaId:'901',dailyBudget:100,activate:false})});
    const result=await response.json();
    assert.equal(response.status,422);assert.equal(result.code,'META_WHATSAPP_MISSING');assert.equal(result.stage,'preflight');
    assert.equal(metaWrites,0);
    const operation=await getAdOperation(tenant.id,'whatsapp-preflight-fixture-0001');
    assert.equal(operation.status,'FAILED');assert.deepEqual(operation.ids,{});
  } finally {global.fetch=native;listener.closeAllConnections();await new Promise(resolve=>listener.close(resolve));}
});

test('HTTP Reels covers use decoded bytes for JPEG/PNG/WebP/blob/mismatched MIME and preserve old cover on rejection',async()=>{
  const sharp=(await import('sharp')).default,store=await import('../src/store.js'),auth=await import('../src/auth.js');
  const tenant=await store.createTenant({companyName:'Cover fixture',plan:'AGENCY'});
  await auth.createTenantUser({tenantId:tenant.id,username:'fixture-cover-manager',password:'fixture-manager-password',role:'MANAGER'});
  const session=await auth.login('fixture-cover-manager','fixture-manager-password');
  await store.savePosts(tenant.id,[{id:'cover-post',mediaType:'REELS',publishStatus:'MANUAL',caption:'Fixture'}]);
  const {app}=await import('../src/server.js');const listener=app.listen(0,'127.0.0.1');await new Promise(resolve=>listener.once('listening',resolve));
  const url=`http://127.0.0.1:${listener.address().port}/api/posts/cover-post/cover`,headers={authorization:`Bearer ${session.token}`};
  const send=(bytes,name,type)=>{const form=new FormData();form.append('cover',new Blob([bytes],{type}),name);return fetch(url,{method:'POST',headers,body:form});};
  try {
    for(const [format,name,type]of [['jpeg','cover.jpg','image/jpeg'],['jpeg','cover.jpeg','image/jpg'],['jpeg','COVER.JPEG','application/octet-stream'],['jpeg','blob','application/octet-stream'],['png','cover.png','image/jpeg'],['webp','cover.webp','image/webp']]) {
      const bytes=await sharp({create:{width:32,height:48,channels:4,background:'#123456'}}).toFormat(format).toBuffer();
      const response=await send(bytes,name,type);assert.equal(response.status,200,`${name} ${type}`);
      const {post}=await response.json();assert.equal(post.coverMime,'image/jpeg');assert.ok(post.coverPublicUrl.endsWith('.jpg'));
      const normalized=await sharp(await fs.readFile(post.coverPath)).metadata();assert.equal(normalized.format,'jpeg');assert.equal(normalized.width,32);assert.equal(normalized.height,48);
    }
    const before=(await store.getPosts(tenant.id))[0],savedBytes=await fs.readFile(before.coverPath);
    const corrupt=await send(Buffer.from([255,216,255,0]),'valid.JPG','image/jpeg');assert.equal(corrupt.status,400);assert.equal((await corrupt.json()).code,'COVER_CORRUPT');
    assert.deepEqual((await store.getPosts(tenant.id))[0],before);assert.deepEqual(await fs.readFile(before.coverPath),savedBytes);
    assert.equal((await send(Buffer.from('%PDF-fixture'),'cover.jpg','image/jpeg')).status,400);
    const tooBig=await send(Buffer.alloc(10*1024*1024+1),'cover.jpg','image/jpeg');assert.equal(tooBig.status,413);assert.equal((await tooBig.json()).code,'COVER_TOO_LARGE');
  } finally {listener.closeAllConnections();await new Promise(resolve=>listener.close(resolve));}
});
