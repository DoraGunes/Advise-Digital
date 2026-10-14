import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const source=fs.readFileSync(new URL('../AdVise-Meta-Ad-Identity.ps1',import.meta.url),'utf8');
const body=source.split('// BEGIN_IDENTITY_READER')[1].split('// END_IDENTITY_READER')[0];
const {inspectAdIdentity}=await import('data:text/javascript;base64,'+Buffer.from(body+'\nexport {inspectAdIdentity};').toString('base64'));
async function fixture(mode){
 const calls=[],out=[];
 const token='__PRIVATE_TOKEN__',phone='__PRIVATE_PHONE__';
 const fetcher=async(url,options)=>{
  calls.push({url:new URL(url),options});const path=new URL(url).pathname.split('/').at(-1);let data,status=200;
  if(path==='act_123')data={account_id:'123',account_status:1};
  else if(path==='act_456'){data=mode==='denied'?{error:{code:200}}:{account_id:'456'};if(mode==='denied')status=403;}
  else if(path==='1001'){
   if(mode==='missing'){data={error:{code:100,error_subcode:33}};status=400;}
   else data={id:'1001',account_id:mode==='foreign'?'999':'456',campaign_id:'2001',adset_id:'3001',creative:{id:'4001'}};
  }
  else if(path==='3001')data={id:'3001',account_id:'456',destination_type:'WHATSAPP',optimization_goal:'REPLIES',billing_event:'IMPRESSIONS',promoted_object:{page_id:'789',whatsapp_phone_number:phone}};
  else if(path==='4001')data={id:'4001',account_id:'456',call_to_action_type:'WHATSAPP_MESSAGE',call_to_action:{value:{app_destination:'WHATSAPP'}},object_story_spec:{page_id:'789'},source_instagram_media_id:'9991'};
  else if(path==='ads')data={data:[{id:'5001',adset_id:'6001',campaign_id:'7001',adset:{destination_type:'WHATSAPP',promoted_object:{page_id:'789',whatsapp_phone_number:phone}}}]};
  else throw Error('Unexpected route');
  return {ok:status===200,status,json:async()=>data};
 };
 await inspectAdIdentity({apiVersion:'v24.0',token,currentAccountId:'123',alternativeAccountId:'456',adId:'1001',expectedPageId:'789',fetcher,emit:line=>out.push(line)});
 for(const row of calls){
  assert.equal(row.options.method,'GET');assert.equal(row.options.redirect,'error');
  assert.equal(row.url.origin,'https://graph.facebook.com');
  assert.equal(row.url.searchParams.has('access_token'),false);
  assert.equal(row.options.headers.Authorization,'Bearer '+token);
 }
 assert.ok(!out.join('\n').includes(token));assert.ok(!out.join('\n').includes(phone));
 return {calls,out};
}
test('Actual graph identities determine hierarchy and related reads, while private values are redacted',async()=>{
 const {calls,out}=await fixture('good');
 assert.ok(out.some(line=>line.includes('account=456 campaign=2001 set=3001 creative=4001 currentAccount=false')));
 assert.ok(calls.some(row=>row.url.pathname.endsWith('/3001')));
 assert.ok(calls.some(row=>row.url.pathname.endsWith('/4001')));
 assert.ok(out.some(line=>line.includes('phoneFields=whatsapp_phone_number')));
});
test('Unreadable alternate account or unapproved ownership prevents related-object reads',async()=>{
 for(const mode of ['denied','foreign']){
  const {calls,out}=await fixture(mode);
  assert.ok(!calls.some(row=>row.url.pathname.endsWith('/3001')||row.url.pathname.endsWith('/4001')));
  assert.ok(out.includes('RELATED_READS skipped=True reason=ACCOUNT_NOT_VERIFIED'));
 }
});
test('Missing candidate is reported without fabricated IDs and current-account ads are still read',async()=>{
 const {out}=await fixture('missing');
 assert.ok(out.some(line=>line.startsWith('AD_LOOKUP requested=1001 ok=false http=400 code=100 subcode=33')));
 assert.ok(out.some(line=>line.startsWith('CURRENT_AD ad=5001 set=6001 campaign=7001')));
 assert.ok(!out.some(line=>line.startsWith('AD_IDENTITY ')));
});
