import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-scheduler-test-'));
Object.assign(process.env,{
  DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),
  ADVISE_DATA_DIR:path.join(fixture,'data'),
  ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),
  JWT_SECRET:'scheduler-test-secret',
  ADMIN_USERNAME:'scheduler-admin',
  ADMIN_PASSWORD:'scheduler-password',
  CRON_ENABLED:'false',
  ADVISE_NO_LISTEN:'true',
  NODE_ENV:'test',
  ADVISE_TIMEZONE:'Europe/Istanbul',
  TZ:'UTC'
});
const store=await import('../src/store.js');
const scheduler=await import('../src/scheduler.js');

after(async()=>{await fs.rm(fixture,{recursive:true,force:true});});

test('scheduler preserves explicit scheduledAt and Istanbul local metadata',async()=>{
  const tenant='scheduler-fixture';
  await store.saveSettings(tenant,{autoPublish:true,weeklyDay:2,startHour:19,startMinute:0,publishMaxRetries:3});
  await store.savePosts(tenant,[]);
  const when=new Date(Date.now()+2*3600000);
  const post={id:'scheduled',autoPublish:true,publishStatus:'MANUAL'};
  await scheduler.scheduleUploadedPost(post,tenant,when.toISOString());
  assert.equal(post.nextPublishAt,when.toISOString());
  assert.equal(post.selectedTime.timezone,'Europe/Istanbul');
  const parts=scheduler.schedulerLocalParts(when);
  assert.equal(post.selectedTime.hour,parts.hour);
  assert.equal(post.selectedTime.minute,parts.minute);
});

test('recent in-flight publish is blocked until stale while reconciliable posts remain allowed',()=>{
  const now=Date.now();
  const recent={publishStatus:'PUBLISHING',publishPhase:'PREPARING',publishStartedAt:new Date(now-60_000).toISOString()};
  const stale={...recent,publishStartedAt:new Date(now-11*60_000).toISOString()};
  const reconciliable={...recent,publishPhase:'SUBMITTING',instagramContainerId:'fixture-container'};
  assert.equal(scheduler.publicationRetryGate(recent,now).blocked,true);
  assert.equal(scheduler.publicationRetryGate(stale,now).blocked,false);
  assert.equal(scheduler.publicationRetryGate(reconciliable,now).blocked,false);
});

test('manual queue cancellation keeps content but disables future automatic publishing',()=>{
  const post={id:'queued',publishStatus:'QUEUED',autoPublish:true,nextPublishAt:new Date(Date.now()+3600000).toISOString(),selectedTime:{timezone:'Europe/Istanbul'}};
  const result=scheduler.cancelScheduledPostState(post);
  assert.equal(result.id,'queued');
  assert.equal(result.publishStatus,'MANUAL');
  assert.equal(result.autoPublish,false);
  assert.equal(result.nextPublishAt,null);
  assert.equal(result.selectedTime,null);
  assert.throws(()=>scheduler.cancelScheduledPostState({publishStatus:'PUBLISHED'}));
});
