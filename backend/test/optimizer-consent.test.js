import test from 'node:test';
import assert from 'node:assert/strict';
Object.assign(process.env,{JWT_SECRET:'optimizer-consent-test-secret',ADMIN_USERNAME:'optimizer-admin',ADMIN_PASSWORD:'optimizer-password',NODE_ENV:'test',CRON_ENABLED:'false'});
const {earlyAdDecision}=await import('../src/rules.js');
const {optimizationPermissionState,reviewDue}=await import('../src/optimizer.js');

test('ad optimization is fail-closed by default and account-scoped',()=>{
  assert.deepEqual(optimizationPermissionState({},'123','CONTINUOUS'),{allowed:false,reason:'CONTINUOUS_PERMISSION_REQUIRED'});
  assert.deepEqual(optimizationPermissionState({optimizationPermission:'CONTINUOUS',optimizationAdAccountIds:['act_123']},'123','CONTINUOUS'),{allowed:true,permission:'CONTINUOUS',accountId:'123'});
  assert.deepEqual(optimizationPermissionState({optimizationPermission:'CONTINUOUS',optimizationAdAccountIds:['456']},'123','CONTINUOUS'),{allowed:false,reason:'ACCOUNT_NOT_SELECTED'});
});

test('one-time permission is separate and review interval is twelve hours',()=>{
  const settings={optimizationPermission:'ONE_TIME',optimizationAdAccountIds:['123']};
  assert.equal(optimizationPermissionState(settings,'123','ONE_TIME').allowed,true);
  assert.equal(optimizationPermissionState(settings,'123','CONTINUOUS').allowed,false);
  const now=Date.parse('2026-10-17T12:00:00Z');
  assert.equal(reviewDue('2026-10-17T00:01:00Z',now,12),false);
  assert.equal(reviewDue('2026-10-16T23:59:00Z',now,12),true);
});

test('optimizer decisions require sufficient spend or message evidence',()=>{
  assert.equal(earlyAdDecision({spend:20,messages:0,messageCost:null},{earlyMinSpendBeforeDecision:50}).action,'WAIT');
  assert.equal(earlyAdDecision({spend:80,messages:0,messageCost:null},{earlyMinSpendBeforeDecision:50,earlyNoMessageSpendThreshold:75}).action,'REDUCE');
  assert.equal(earlyAdDecision({spend:80,messages:5,messageCost:1},{earlyMinSpendBeforeDecision:50,earlyMessageCostLimit:2}).action,'KEEP');
});
