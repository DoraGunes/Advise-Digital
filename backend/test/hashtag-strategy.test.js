import test from 'node:test';
import assert from 'node:assert/strict';
import {buildHashtagStrategy,canonicalHashtag,normalizeHashtagMode,normalizeHashtagUse} from '../src/hashtag-strategy.js';

const relevantCandidates=[
  {hashtag:'#Kahve',group:'broad'},
  {hashtag:'#Espresso',group:'niche'},
  {hashtag:'#KahveMakinesi',group:'niche'},
  {hashtag:'#Barista',group:'niche'},
  {hashtag:'#BoluKahve',group:'local'},
  {hashtag:'#Bolu',group:'local'},
  {hashtag:'#PoyrazCafe',group:'branded'},
  {hashtag:'#WhatsAppSipariş',group:'intent'},
  {hashtag:'#KahveSiparişi',group:'intent'},
  {hashtag:'#TürkKahvesi',group:'niche'},
  {hashtag:'#KahveKeyfi',group:'broad'},
  {hashtag:'#KahveTutkusu',group:'broad'},
  {hashtag:'#EspressoKeyfi',group:'broad'},
  {hashtag:'#Kafe',group:'broad'},
  {hashtag:'#TazeKahve',group:'niche'},
  {hashtag:'#KahveMolası',group:'broad'},
  {hashtag:'#BoluKafe',group:'local'},
  {hashtag:'#KahveSeverler',group:'broad'},
  {hashtag:'#KahveDeneyimi',group:'broad'},
];

test('normalization preserves Turkish characters and deduplicates case-insensitively',()=>{
  assert.equal(canonicalHashtag('  ##İstanbul '),'#İstanbul');
  const result=buildHashtagStrategy({candidates:['#İSTANBUL','#istanbul','#Sağlık','#sağlık'],locations:['İstanbul'],mode:'DISCOVERY'});
  assert.deepEqual(result.candidates,['#İSTANBUL','#Sağlık']);
  assert.equal(result.rejected.duplicate.length,2);
});

test('strategy modes are bounded and stable without filler hashtags',()=>{
  const base={candidates:relevantCandidates,title:'Espresso kahve makinesi',context:'Bolu kafesi için espresso ve kahve',businessName:'Poyraz Cafe',locations:['Bolu']};
  const minimal=buildHashtagStrategy({...base,mode:'MINIMAL'});
  const balanced=buildHashtagStrategy({...base,mode:'BALANCED'});
  const discovery=buildHashtagStrategy({...base,mode:'DISCOVERY'});
  assert.ok(minimal.hashtags.length<=5);
  assert.ok(balanced.hashtags.length>=8&&balanced.hashtags.length<=12);
  assert.ok(discovery.hashtags.length>=balanced.hashtags.length&&discovery.hashtags.length<=18);
  assert.deepEqual(buildHashtagStrategy({...base,mode:'BALANCED'}),balanced);
});

test('paid strategy never applies organic hashtag quotas',()=>{
  const minimal=buildHashtagStrategy({candidates:relevantCandidates,mode:'MINIMAL',contentUse:'PAID'});
  const balanced=buildHashtagStrategy({candidates:relevantCandidates,mode:'BALANCED',contentUse:'PAID'});
  const discovery=buildHashtagStrategy({candidates:relevantCandidates,mode:'DISCOVERY',contentUse:'PAID'});
  assert.equal(minimal.hashtags.length,0);
  assert.ok(balanced.hashtags.length<=2);
  assert.ok(discovery.hashtags.length<=3);
  assert.equal(discovery.groups.broad.length,0);
});

test('spam competitor banned and irrelevant candidates are filtered',()=>{
  const result=buildHashtagStrategy({
    candidates:['#follow4follow','#RakipCafe','#YasakEtiket','#Basketbol','#Espresso'],
    title:'Espresso kahve',
    competitors:['Rakip Cafe'],
    bannedHashtags:['#YasakEtiket'],
    mode:'DISCOVERY'
  });
  assert.ok(result.rejected.spam.includes('#follow4follow'));
  assert.ok(result.rejected.competitor.includes('#RakipCafe'));
  assert.ok(result.rejected.banned.includes('#YasakEtiket'));
  assert.ok(result.rejected.irrelevant.includes('#Basketbol'));
  assert.ok(result.hashtags.includes('#Espresso'));
});

test('local and branded candidates are grouped deterministically',()=>{
  const result=buildHashtagStrategy({
    candidates:['#Bolu','#PoyrazCafe','#Espresso'],
    title:'Espresso',
    businessName:'Poyraz Cafe',
    locations:['Bolu'],
    mode:'BALANCED'
  });
  assert.ok(result.groups.local.includes('#Bolu'));
  assert.ok(result.groups.branded.includes('#PoyrazCafe'));
});

test('empty and bad candidates never create spam filler',()=>{
  const empty=buildHashtagStrategy({candidates:[],mode:'BALANCED'});
  assert.deepEqual(empty.hashtags,[]);
  const bad=buildHashtagStrategy({candidates:['###','!!!','#follow4follow'],mode:'DISCOVERY'});
  assert.deepEqual(bad.hashtags,[]);
});

test('recent set repetition is penalized without cross-request state',()=>{
  const base={candidates:relevantCandidates,title:'Kahve espresso',mode:'MINIMAL'};
  const first=buildHashtagStrategy(base);
  const second=buildHashtagStrategy({...base,recentHashtagSets:[first.hashtags]});
  assert.notDeepEqual(second.hashtags,first.hashtags);
  const unrelatedTenant=buildHashtagStrategy(base);
  assert.deepEqual(unrelatedTenant,first);
});

test('invalid modes fall back safely',()=>{
  assert.equal(normalizeHashtagMode('whatever'),'BALANCED');
  assert.equal(normalizeHashtagUse('whatever'),'ORGANIC');
});
