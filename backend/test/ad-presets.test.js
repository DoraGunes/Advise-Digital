import test from 'node:test';import assert from 'node:assert/strict';
import {AD_PRESETS,presetPolicy,presetTargeting,assertPresetMedia} from '../src/ad-presets.js';
const input={presetId:'service-all',presetVersion:1,destination:'WHATSAPP',activate:false,dailyBudget:120,locationMode:'RADIUS'};
test('Five campaign presets apply destination, budget ceilings and provider-specific placements',()=>{
 assert.equal(AD_PRESETS.length,5);
 const result=presetPolicy(input,{geminiAdsDailyCap:500,maxDailyBudget:500});
 assert.equal(result.settings.geminiAdsDailyCap,200);assert.equal(result.settings.maxDailyBudget,120);
 assert.equal(result.radius.radius,200);
 assert.equal(presetPolicy(input,{geminiAdsDailyCap:0}).settings.geminiAdsDailyCap,0);
 const reels=presetTargeting(AD_PRESETS[4],{custom_locations:[result.radius]});
 assert.deepEqual(reels.publisher_platforms,['instagram']);assert.deepEqual(reels.instagram_positions,['reels']);
 assert.equal(reels.message_template,undefined);assert.equal(reels.greeting,undefined);
});
test('Preset cannot silently widen region, become ACTIVE, change destination or exceed per-ad budget',()=>{
 for(const change of [{activate:true},{destination:'INSTAGRAM_DIRECT'},{locationMode:'COUNTRY'},{dailyBudget:121},{presetVersion:2},{autoReply:true}]){
  assert.throws(()=>presetPolicy({...input,...change},{geminiAdsDailyCap:200}),{code:'AD_PRESET_INVALID'});
 }
 assert.throws(()=>assertPresetMedia(AD_PRESETS[3],{media_type:'IMAGE'}),{code:'AD_PRESET_INVALID'});
 assert.doesNotThrow(()=>assertPresetMedia(AD_PRESETS[3],{media_type:'VIDEO'}));
 assert.equal(presetPolicy({...input,radius:{radius:200,greeting:'do not forward'}},{}).radius.greeting,undefined);
});
