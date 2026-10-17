import test from 'node:test';
import assert from 'node:assert/strict';
Object.assign(process.env,{DOTENV_CONFIG_PATH:'/tmp/advise-gemini-content-missing.env',JWT_SECRET:'gemini-content-test-secret',ADMIN_USERNAME:'gemini-content-admin',ADMIN_PASSWORD:'gemini-content-password',NODE_ENV:'test',CRON_ENABLED:'false'});
const {runGeminiContent,assessGeminiContent,cleanGeminiContent,geminiContentStatus}=await import('../src/gemini-content.js');

const settings={geminiContentStudioEnabled:true,geminiContentApiKey:'fixture-key',geminiContentModel:'gemini-3.8-flash',geminiContentApiBase:'https://generativelanguage.googleapis.com/v1beta'};
const response=(body,status=200)=>({ok:status>=200&&status<300,status,json:async()=>body});

test('content Gemini returns an editable, cleaned draft without side effects',async()=>{
  const calls=[];
  const result=await runGeminiContent({task:'AD_COPY',input:{title:'Fixture'},settings,transport:async(url,options)=>{calls.push({url,body:JSON.parse(options.body)});return response({modelVersion:'gemini-3.8-flash',usageMetadata:{totalTokenCount:12},candidates:[{content:{parts:[{text:'Başlık ✨\nAna metin #gereksiz\nKesin sonuç garanti eder.'}]}}]});}});
  assert.equal(result.ok,true);assert.equal(result.editable,true);assert.equal(result.model,'gemini-3.8-flash');assert.equal(result.sideEffects.length,0);
  assert.ok(!result.text.includes('✨'));assert.ok(!result.text.includes('#gereksiz'));assert.equal(calls.length,1);assert.match(calls[0].url,/generativelanguage\.googleapis\.com/);assert.ok(!calls[0].body.access_token);assert.ok(!calls[0].body.ad_account_id);
});

test('photo and Reels analysis use inline media only and never Meta or queue',async()=>{
  const calls=[];
  for(const mediaType of ['image/jpeg','video/mp4']) await runGeminiContent({task:'ANALYZE',input:{mediaType},mediaBuffer:Buffer.from('fixture'),mediaType,settings,transport:async(url,options)=>{calls.push({url,body:JSON.parse(options.body)});return response({candidates:[{content:{parts:[{text:'Görülen unsurlar ve doğrulanması gereken noktalar.'}]}}]});}});
  assert.equal(calls.length,2);for(const call of calls){const parts=call.body.contents[0].parts;assert.ok(parts.some(part=>part.inlineData?.data));assert.ok(!/facebook|meta|ads|queue|scheduler/i.test(call.url));}
});

test('Gemini provider failures fail closed and remain retryable only for transient errors',async()=>{
  for(const [status,code,retryable] of [[404,'GEMINI_MODEL_UNAVAILABLE',false],[429,'GEMINI_RATE_LIMIT',true],[503,'GEMINI_PROVIDER_UNAVAILABLE',true]]){
    await assert.rejects(()=>runGeminiContent({task:'STRATEGY',settings,transport:async()=>response({error:{code:status}},status)}),error=>error.code===code&&error.retryable===retryable&&error.providerCode===status);
  }
  await assert.rejects(()=>runGeminiContent({task:'AD_COPY',settings:{...settings,geminiContentStudioEnabled:false},transport:async()=>{throw new Error('must not call');}}),{code:'GEMINI_CONTENT_DISABLED'});
});

test('content quality checks remain explicit and do not invent claims',()=>{
  const checked=assessGeminiContent('Sade ve ölçülü Türkçe metin. #tag ✨',{allowHashtags:false});
  assert.equal(checked.hasEmoji,true);assert.equal(checked.hasUnrequestedHashtag,true);assert.equal(checked.hasUnsupportedClaim,false);
  assert.equal(cleanGeminiContent('Sade #tag ✨ metin'), 'Sade metin');
  assert.deepEqual(geminiContentStatus(settings),{enabled:true,model:'gemini-3.8-flash',provider:'GEMINI',mode:'CONTENT_ONLY',capabilities:['ANALYZE','AD_COPY','STRATEGY'],sideEffects:[]});
});
