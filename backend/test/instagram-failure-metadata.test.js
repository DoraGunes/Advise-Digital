import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-instagram-failure-'));
Object.assign(process.env,{
 DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),ADVISE_DATA_DIR:fixture,
 ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),ADVISE_NO_LISTEN:'true',CRON_ENABLED:'false',
 JWT_SECRET:'fixture-only-session-secret',ADMIN_USERNAME:'fixture-instagram-admin',
 ADMIN_PASSWORD:'fixture-password',GEMINI_API_KEY:'',GOOGLE_API_KEY:'',
 META_ACCESS_TOKEN:'',INSTAGRAM_ACCESS_TOKEN:''
});
const {getInstagramMedia}=await import('../src/meta.js');
after(async()=>{await fs.rm(fixture,{recursive:true,force:true});});
const credentials={instagramUserId:'789',instagramAccessToken:'fixture-only',instagramApi:'FACEBOOK'};
const secret='DO_NOT_REFLECT_PROVIDER_FIXTURE';
const rejected=(status,code,subcode)=>new Response(JSON.stringify({error:{code,error_subcode:subcode,message:secret+' https://fixture.invalid/?access_token='+secret,fbtrace_id:'https://fixture.invalid/'+secret}}),{status});

for(const [status,providerCode,expected,retryable] of [[400,190,'META_SESSION_EXPIRED',false],[403,200,'META_PERMISSION_DENIED',false],[429,4,'META_RATE_LIMIT',true],[400,100,'INSTAGRAM_REJECTED',false]]){
 test('Instagram read rejection preserves safe metadata for provider '+providerCode,async()=>{
  const native=globalThis.fetch;
  globalThis.fetch=async()=>rejected(status,providerCode,2207009);
  try {
   await assert.rejects(getInstagramMedia(credentials),error=>{
    assert.equal(error.code,expected);assert.equal(error.status,status);
    assert.equal(error.providerCode,providerCode);assert.equal(error.providerSubcode,2207009);
    assert.equal(error.providerTrace,null);assert.equal(error.retryable,retryable);
    assert.ok(!error.message.includes(secret));assert.ok(!error.message.includes('https://'));
    assert.ok(!JSON.stringify(error).includes(secret));
    return true;
   });
  }finally{globalThis.fetch=native;}
 });
}

test('Instagram aborted transport has a stable timeout code',async()=>{
 const native=globalThis.fetch;
 globalThis.fetch=async()=>{throw Object.assign(new Error(secret),{name:'AbortError'});};
 try{await assert.rejects(getInstagramMedia(credentials),error=>error.code==='ETIMEDOUT'&&!error.message.includes(secret));}
 finally{globalThis.fetch=native;}
});

test('publish rejection persists safe provider code and submission phase without leaking provider text',async()=>{
 const store=await import('../src/store.js');
 const tenant=await store.createTenant({companyName:'Instagram error fixture',plan:'AGENCY'});
 await store.updateTenant(tenant.id,{meta:{connected:true,source:'OAUTH',...credentials}});
 await store.savePosts(tenant.id,[{id:'rejected-photo',mediaType:'POST',caption:'Fixture',publicUrl:'https://fixture.invalid/photo.jpg',publishStatus:'MANUAL'}]);
 const {publishPost}=await import('../src/scheduler.js');
 const native=globalThis.fetch;
 globalThis.fetch=async(input,options={})=>{
  const url=new URL(input);
  assert.equal(url.hostname,'graph.facebook.com');
  if(url.pathname.endsWith('/media_publish'))return rejected(400,100,2207009);
  if(options.method==='POST')return new Response(JSON.stringify({id:'1005'}),{status:200});
  return new Response(JSON.stringify({status_code:'FINISHED'}),{status:200});
 };
 try{
  await assert.rejects(publishPost(tenant.id,'rejected-photo'),{code:'INSTAGRAM_REJECTED'});
  const post=(await store.getPosts(tenant.id))[0];
  assert.equal(post.publishStatus,'RECONCILE');
  assert.deepEqual(post.publishFailure,{code:'INSTAGRAM_REJECTED',stage:'SUBMITTING',providerFailure:{status:400,code:100,subcode:2207009}});
  assert.ok(!JSON.stringify(post).includes(secret));
  assert.ok(!JSON.stringify(await store.getLogs(tenant.id)).includes(secret));
 }finally{globalThis.fetch=native;}
});
