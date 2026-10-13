import test from 'node:test';
import assert from 'node:assert/strict';
import {buildManualMemory} from '../src/manual-memory.js';
test('Research suggestions never masquerade as tenant results or launch actions',()=>{
 const a=buildManualMemory([{id:'own',caption:'Saved',publishStatus:'PUBLISHED'}]);
 assert.equal(a.publishedCount,1);assert.equal(a.posts[0].caption,'Saved');
 assert.equal(a.research.automaticActions,false);
 assert.equal(a.research.evaluation.goalIsGuarantee,false);
 for(const row of [...a.research.timing,...a.research.hashtagSets]) assert.equal(row.accountSampleSize,0);
 assert.equal(a.research.timing[0].evidence,'EXTERNAL_BENCHMARK');
 assert.equal(a.research.hashtagSets[0].evidence,'EDITORIAL_CANDIDATE');
 a.research.timing[0].hour=1;
 assert.equal(buildManualMemory().research.timing[0].hour,9);
 assert.equal(buildManualMemory().postCount,0);
});

test('Draft ads preserve explicit budgets and geography without promising provider availability',()=>{
 const library=buildManualMemory().research;
 assert.equal(library.adDrafts.length,4);
 for(const draft of library.adDrafts){
  assert.equal(draft.destination,'WHATSAPP');
  assert.equal(draft.dailyBudgetTry,120);
  assert.equal(draft.accountDailyCapTry,200);
  assert.equal(draft.initialStatus,'PAUSED');
  assert.equal(draft.requestedArea.radiusKm,200);
  assert.equal(draft.availability,'PREFLIGHT_REQUIRED');
  assert.equal(draft.evidence,'UNTESTED_TEMPLATE');
 }
});
