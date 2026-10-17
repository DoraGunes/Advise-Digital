import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-auto-publish-consent-'));
Object.assign(process.env,{
  DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),
  ADVISE_DATA_DIR:path.join(fixture,'data'),
  ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),
  JWT_SECRET:'auto-publish-test-secret',
  ADMIN_USERNAME:'auto-publish-admin',
  ADMIN_PASSWORD:'auto-publish-password',
  ADVISE_NO_LISTEN:'true',
  NODE_ENV:'test',
  CRON_ENABLED:'false',
  ADVISE_TIMEZONE:'Europe/Istanbul',
  TZ:'UTC'
});
const store=await import('../src/store.js');
const scheduler=await import('../src/scheduler.js');

after(async()=>{await fs.rm(fixture,{recursive:true,force:true});});

test('enabling automation never publishes a past-due queued post',async()=>{
  const tenant='auto-publish-enable-fixture';
  await store.saveSettings(tenant,{autoPublish:false});
  await store.savePosts(tenant,[
    {id:'past',publishStatus:'QUEUED',autoPublish:true,nextPublishAt:new Date(Date.now()-60000).toISOString(),selectedTime:{scheduledAt:'past'}},
    {id:'future',publishStatus:'QUEUED',autoPublish:true,nextPublishAt:new Date(Date.now()+3600000).toISOString(),selectedTime:{scheduledAt:'future'}}
  ]);
  const result=await scheduler.setPublishingAutomation(tenant,true,'fixture-user');
  const posts=await store.getPosts(tenant);
  assert.equal(result.autoPublish,true);
  assert.equal(result.resetCount,1);
  assert.equal(posts.find(x=>x.id==='past').publishStatus,'READY');
  assert.equal(posts.find(x=>x.id==='past').nextPublishAt,null);
  assert.equal(posts.find(x=>x.id==='future').publishStatus,'QUEUED');
  assert.equal(posts.find(x=>x.id==='future').autoPublish,true);
});

test('disabling automation moves future automatic posts to manual approval',async()=>{
  const tenant='auto-publish-disable-fixture';
  await store.saveSettings(tenant,{autoPublish:true});
  await store.savePosts(tenant,[
    {id:'future',publishStatus:'QUEUED',autoPublish:true,nextPublishAt:new Date(Date.now()+3600000).toISOString(),selectedTime:{scheduledAt:'future'}}
  ]);
  const result=await scheduler.setPublishingAutomation(tenant,false,'fixture-user');
  const post=(await store.getPosts(tenant))[0];
  assert.equal(result.autoPublish,false);
  assert.equal(result.resetCount,1);
  assert.equal(post.publishStatus,'READY');
  assert.equal(post.autoPublish,false);
  assert.equal(post.nextPublishAt,null);
});
