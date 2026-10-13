import test from 'node:test';import assert from 'node:assert/strict';
import {summarizePresetResults} from '../src/ad-preset-results.js';
const row={presetId:'service-all',adId:'one',currency:'TRY',available:true,data:[{spend:'12',actions:[
 {action_type:'onsite_conversion.messaging_conversation_started_7d',value:'4'},
 {action_type:'messaging_conversation_started_7d',value:'4'}]}]};
test('Real Meta attribution is counted once and duplicate ad records never double spending',()=>{
 const result=summarizePresetResults([row,row])[0];
 assert.equal(result.costPerConversation,3);assert.equal(result.spend,12);assert.equal(result.conversations,4);
});
test('No conversations, missing metrics, different currency or failed reads never create a claimed cost',()=>{
 for(const value of [{...row,currency:'USD'},{...row,available:false},{...row,data:[{spend:'12'}]},{...row,data:[{spend:null,actions:row.data[0].actions}]},
 {...row,data:[{spend:'12',actions:[]}]}])assert.equal(summarizePresetResults([value])[0].costPerConversation,null);
});
