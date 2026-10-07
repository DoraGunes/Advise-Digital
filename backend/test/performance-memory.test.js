import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-performance-memory-'));
Object.assign(process.env,{
  ADVISE_DATA_DIR:path.join(fixture,'data'),
  ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),
  NODE_ENV:'test'
});
const perf=await import('../src/performance-memory.js');

after(async()=>{await fs.rm(fixture,{recursive:true,force:true});});

test('unknown provider metrics remain explicit null instead of fake zero',async()=>{
  const row=await perf.recordPerformance('tenant-null',{
    key:'null-case',
    mode:'PAID',
    timestamp:'2026-10-06T17:00:00Z',
    metrics:{spend:0,impressions:null,saves:{value:null,status:'NOT_SUPPORTED'}}
  });
  assert.deepEqual(row.metrics.spend,{value:0,status:'AVAILABLE'});
  assert.deepEqual(row.metrics.impressions,{value:null,status:'UNAVAILABLE'});
  assert.deepEqual(row.metrics.saves,{value:null,status:'NOT_SUPPORTED'});
  assert.equal(row.localTime.timezone,'Europe/Istanbul');
  assert.equal(row.localTime.hour,20);
});

test('Meta insight adapter distinguishes unavailable actions from real zero',()=>{
  const unavailable=perf.metaInsightToPerformance({spend:'10',ctr:'2'});
  assert.equal(unavailable.metrics.messages,null);
  assert.equal(unavailable.metricStatus.resultCost,'UNAVAILABLE');

  const zero=perf.metaInsightToPerformance({spend:'10',ctr:'2',actions:[]});
  assert.equal(zero.metrics.messages,0);
  assert.equal(zero.metrics.conversations,0);
});

test('paid and organic timing evidence are isolated',async()=>{
  for(let i=0;i<4;i++){
    await perf.recordPerformance('tenant-modes',{
      key:'paid-'+i,mode:'PAID',timestamp:'2026-10-06T17:0'+i+':00Z',
      mediaType:'REELS',
      metrics:{messages:8,ctr:4,resultCost:2,cpc:1}
    });
  }
  await perf.recordPerformance('tenant-modes',{
    key:'organic-1',mode:'ORGANIC',timestamp:'2026-10-07T08:00:00Z',
    mediaType:'REELS',
    metrics:{reach:1000,reactions:20,saves:5,shares:4,comments:3,videoViews:900}
  });
  const paid=await perf.recommendPublishTime('tenant-modes',{mode:'PAID',mediaType:'REELS'});
  const organic=await perf.recommendPublishTime('tenant-modes',{mode:'ORGANIC',mediaType:'REELS'});
  assert.equal(paid.recommended.hour,20);
  assert.equal(paid.sampleSize,4);
  assert.equal(organic.recommended.hour,11);
  assert.equal(organic.sampleSize,1);
  assert.equal(organic.confidence.label,'LOW');
});

test('timing recommendation is tenant-owned and has no static global fallback',async()=>{
  await perf.recordPerformance('tenant-time-a',{
    key:'a1',mode:'ORGANIC',timestamp:'2026-10-06T16:00:00Z',
    mediaType:'POST',metrics:{reach:500,comments:5}
  });
  const own=await perf.recommendPublishTime('tenant-time-a',{mode:'ORGANIC',mediaType:'POST'});
  const other=await perf.recommendPublishTime('tenant-time-b',{mode:'ORGANIC',mediaType:'POST'});
  assert.equal(own.recommended.hour,19);
  assert.equal(other.recommended,null);
  assert.equal(other.confidence.label,'NONE');
  assert.match(other.reason,/henüz yok/);
});

test('same performance key upserts instead of duplicating samples',async()=>{
  await perf.recordPerformance('tenant-upsert',{key:'same',mode:'PAID',metrics:{messages:1,spend:10}});
  await perf.recordPerformance('tenant-upsert',{key:'same',mode:'PAID',metrics:{messages:2,spend:10}});
  const summary=await perf.getPerformanceMemorySummary('tenant-upsert');
  assert.equal(summary.recordCount,1);
  assert.equal(summary.paidCount,1);
  assert.equal(summary.availableMetrics.messages,1);
});

test('confidence rises with repeated tenant evidence but remains bounded',async()=>{
  for(let i=0;i<8;i++){
    await perf.recordPerformance('tenant-confidence',{
      key:'sample-'+i,
      mode:'PAID',
      timestamp:'2026-10-05T17:'+String(i).padStart(2,'0')+':00Z',
      metrics:{messages:5,ctr:3,resultCost:3}
    });
  }
  const result=await perf.recommendPublishTime('tenant-confidence',{mode:'PAID'});
  assert.equal(result.sampleSize,8);
  assert.ok(['MEDIUM','HIGH'].includes(result.confidence.label));
  assert.ok(result.confidence.score<=.95);
});
