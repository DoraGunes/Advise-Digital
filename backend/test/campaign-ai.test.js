import test from 'node:test';
import assert from 'node:assert/strict';

process.env.GEMINI_API_KEY='';
const ai=await import('../src/ai.js');

test('campaign AI returns structured recommendation and legacy aliases',()=>{
  const strategy=ai.normalizeCampaignStrategy({
    objective:'OUTCOME_ENGAGEMENT',optimizationGoal:'CONVERSATIONS',destination:'WHATSAPP',
    audienceHypothesis:'Bolu içindeki ilgili kullanıcıları test et.',placements:['Instagram Feed','Instagram Reels'],
    dailyBudgetMin:120,dailyBudgetMax:180,testDurationDays:7,recommendedCreativeFormat:'REELS',
    primaryTextAngle:'Ürünün doğrulanabilir faydasını göster.',headline:'Detayı yakından gör',
    cta:'WhatsApp üzerinden bize yazın.',recommendedTime:'19:00',
    scheduleReason:'Geçmiş veri sınırlı olduğu için başlangıç test saati.',
    rationaleSummary:'Gerçek veri geldikçe plan yeniden ölçülmeli.',confidence:92,
    assumptions:['İçeriğin seçilen kitleyle alakalı olduğu varsayımı'],missingPrerequisites:[]
  },{
    budgetLimit:150,accountDailyCap:300,locationMode:'CITY',locations:['Bolu'],
    timezone:'Europe/Istanbul',reportAvailable:false,memoryOutcomeCount:0
  });
  assert.equal(strategy.destination,'WHATSAPP');
  assert.equal(strategy.dailyBudgetRange.max,150);
  assert.equal(strategy.budget.dailyBudget,150);
  assert.deepEqual(strategy.geography.locations,['Bolu']);
  assert.equal(strategy.recommendedCreativeFormat,'REELS');
  assert.equal(strategy.confidenceLabel,'LOW');
  assert.ok(strategy.confidence<=45);
  assert.ok(strategy.missingPrerequisites.includes('Güncel Meta performans verisi'));
  assert.ok(strategy.missingPrerequisites.includes('Yeterli ölçülmüş kampanya sonucu'));
});

test('campaign AI rejects invalid budget ranges and unsupported time values',()=>{
  const base={
    objective:'OUTCOME_ENGAGEMENT',optimizationGoal:'CONVERSATIONS',destination:'WHATSAPP',
    audienceHypothesis:'Hipotez',placements:['Instagram Feed'],dailyBudgetMin:200,dailyBudgetMax:100,
    testDurationDays:7,recommendedCreativeFormat:'POST',primaryTextAngle:'Açı',headline:'Başlık',
    cta:'WhatsApp üzerinden bize yazın.',recommendedTime:'19:00',scheduleReason:'Test',
    rationaleSummary:'Gerekçe',confidence:40,assumptions:[],missingPrerequisites:[]
  };
  assert.throws(()=>ai.normalizeCampaignStrategy(base,{budgetLimit:300,reportAvailable:true,memoryOutcomeCount:2}));
  assert.throws(()=>ai.normalizeCampaignStrategy({...base,dailyBudgetMin:100,dailyBudgetMax:150,recommendedTime:'25:99'},{budgetLimit:300,reportAvailable:true,memoryOutcomeCount:2}));
});
