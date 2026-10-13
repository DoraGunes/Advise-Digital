import test from 'node:test';import assert from 'node:assert/strict';
import {learnManualHistory} from '../src/memory-learning.js';
const post=(id,planned,actual,provider=id)=>({id,caption:'Televizyon tamiri #TVTamiri',
 mediaType:'IMAGE',publishStatus:'PUBLISHED',publishPhase:'CONFIRMED',
 selectedTime:{scheduledAt:planned},publishedAt:actual,instagramPublishResult:{id:provider}});
test('Two distinct aligned publications earn timing badge, duplicate IDs never do',()=>{
 const a=post('a','2026-10-07T16:30:00Z','2026-10-07T16:35:00Z');
 const b=post('b','2026-10-14T16:30:00Z','2026-10-14T16:40:00Z');
 assert.equal(learnManualHistory([a]).timingChecks[0].alignedCount,1);
 assert.equal(learnManualHistory([a,{...b,instagramPublishResult:{id:'a'}}]).timingChecks[0].alignedCount,1);
 const result=learnManualHistory([a,b]).timingChecks[0];
 assert.equal(result.status,'DOUBLE_TRIAL_ALIGNED');assert.equal(result.alignedCount,2);
});
test('Missing proof, manual unscheduled publications and misaligned times are not double trials',()=>{
 const a=post('a','2026-10-07T16:30:00Z','2026-10-07T16:50:00Z');
 const b=post('b','2026-10-14T16:30:00Z','2026-10-14T16:40:00Z');
 assert.equal(learnManualHistory([a,b]).timingChecks[0].status,'INSUFFICIENT_ALIGNED_TRIALS');
 assert.equal(learnManualHistory([{...a,publishStatus:'READY'},{...b,publishedAt:null}]).timingChecks.length,0);
});
test('Saved text frequency is a preference, not a fabricated conversion score',()=>{
 const result=learnManualHistory([{id:'draft',caption:'Televizyon tamiri #TVTamiri',mediaType:'REELS'}]);
 assert.equal(result.captionSuggestions[0].mediaType,'REELS');
 assert.equal(result.captionSuggestions[0].examples[0].postId,'draft');
 assert.equal(result.hashtags[0].evidence,'SAVED_TEXT_FREQUENCY');
 assert.equal(result.timingChecks.length,0);assert.equal(result.automaticActions,false);
});
