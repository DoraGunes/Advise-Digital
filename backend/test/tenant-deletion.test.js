import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import test, {after} from 'node:test';

const fixture = await fs.mkdtemp(path.join(os.tmpdir(), 'advise-delete-test-'));
const data = path.join(fixture, 'data');
const uploads = path.join(fixture, 'uploads');
Object.assign(process.env, {
  DOTENV_CONFIG_PATH:path.join(fixture, 'missing.env'),
  ADVISE_DATA_DIR:data,
  ADVISE_UPLOAD_DIR:uploads,
  JWT_SECRET:'delete-test-secret',
  ADMIN_USERNAME:'delete-admin',
  ADMIN_PASSWORD:'delete-password',
  CRON_ENABLED:'false',
  ADVISE_NO_LISTEN:'true',
  NODE_ENV:'test'
});

const store = await import('../src/store.js');
const write = async (name, value) => fs.writeFile(path.join(data, name), JSON.stringify(value, null, 2));
const read = async name => JSON.parse(await fs.readFile(path.join(data, name), 'utf8'));

const tenant = await store.createTenant({companyName:'Delete target', plan:'PRO'});
const other = await store.createTenant({companyName:'Keep target', plan:'PRO'});
const targetFile = path.join(uploads, 'target.jpg');
const targetCover = path.join(uploads, 'target-cover.jpg');
const otherFile = path.join(uploads, 'other.jpg');
await fs.mkdir(uploads, {recursive:true});
await fs.writeFile(targetFile, 'target-file');
await fs.writeFile(targetCover, 'target-cover');
await fs.writeFile(otherFile, 'other-file');
await store.saveUsers([
  {id:'target-user',tenantId:tenant.id,username:'target',active:true},
  {id:'other-user',tenantId:other.id,username:'other',active:true}
]);
await store.savePosts(tenant.id, [{id:'target-post',tenantId:tenant.id,filePath:targetFile,coverPath:targetCover,publishStatus:'MANUAL'}]);
await store.savePosts(other.id, [{id:'other-post',tenantId:other.id,filePath:otherFile,publishStatus:'MANUAL'}]);
await write('settings.json', {[tenant.id]:{tenantOnly:true},[other.id]:{keep:true}});
await write('logs.json', [{tenantId:tenant.id,type:'TARGET_LOG'},{tenantId:other.id,type:'OTHER_LOG'},{tenantId:'system',type:'OLD_SYSTEM_LOG'}]);
await write('pro.json', {leads:[{id:'target-lead',tenantId:tenant.id},{id:'other-lead',tenantId:other.id}],agencyNotes:[{tenantId:tenant.id,note:'target'},{tenantId:other.id,note:'other'}]});
await write('ai_memory.json', {version:3,tenants:{[tenant.id]:{generations:[{id:'target'}]},[other.id]:{generations:[{id:'other'}]}}});
await write('performance_memory.json', {version:1,tenants:{[tenant.id]:{records:[{id:'target'}]},[other.id]:{records:[{id:'other'}]}}});
await write('ad_operations.json', [{tenantId:tenant.id,requestId:'target-op'},{tenantId:other.id,requestId:'other-op'}]);

test('tenant deletion removes target data and uploads while preserving other tenants and audit', async () => {
  const result = await store.deleteTenantCascade(tenant.id, {uploadRoot:uploads, actorId:'admin-1'});
  assert.equal(result.removedPostsCount, 1);
  assert.equal(result.removedUploadCount, 2);
  assert.equal((await store.getTenant(tenant.id)), null);
  assert.equal((await store.getTenant(other.id)).companyName, 'Keep target');
  assert.equal((await read('pro.json')).leads.some(row => row.tenantId === tenant.id), false);
  assert.equal((await read('ai_memory.json')).tenants[tenant.id], undefined);
  assert.equal((await read('performance_memory.json')).tenants[tenant.id], undefined);
  assert.equal((await read('ad_operations.json')).some(row => row.tenantId === tenant.id), false);
  assert.equal((await read('ad_operations.json')).some(row => row.tenantId === other.id), true);
  assert.equal((await read('logs.json')).some(row => row.type === 'CUSTOMER_DELETED' && row.tenantId === 'system' && row.actorId === 'admin-1'), true);
  await assert.rejects(fs.access(targetFile));
  await assert.rejects(fs.access(targetCover));
  await fs.access(otherFile);
});

test('failed deletion rolls back JSON and upload changes', async () => {
  const rollbackTenant = await store.createTenant({companyName:'Rollback target', plan:'BASIC'});
  const rollbackFile = path.join(uploads, 'rollback.jpg');
  await fs.writeFile(rollbackFile, 'rollback-file');
  await store.savePosts(rollbackTenant.id, [{id:'rollback-post',tenantId:rollbackTenant.id,filePath:rollbackFile}]);
  await assert.rejects(
    store.deleteTenantCascade(rollbackTenant.id, {uploadRoot:uploads, onPhase:phase => { if (phase === 'before-upload-delete') throw new Error('test rollback'); }}),
    /test rollback/
  );
  assert.equal((await store.getTenant(rollbackTenant.id)).companyName, 'Rollback target');
  await fs.access(rollbackFile);
  assert.equal((await store.getPosts(rollbackTenant.id)).length, 1);
});

test('system tenant deletion is denied before any mutation', async () => {
  await assert.rejects(store.deleteTenantCascade('system', {uploadRoot:uploads}), /Sistem hesabı silinemez/);
});

after(async () => fs.rm(fixture, {recursive:true, force:true}));
