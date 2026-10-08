import test from 'node:test';
import assert from 'node:assert/strict';

Object.assign(process.env,{
  DOTENV_CONFIG_PATH:'/tmp/advise-campaign-ai-missing.env',
  JWT_SECRET:'campaign-ai-test-secret',
  ADMIN_USERNAME:'campaign-ai-test-admin',
  ADMIN_PASSWORD:'campaign-ai-test-password',
  GEMINI_API_KEY:'',
  GOOGLE_API_KEY:'',
  ADVISE_NO_LISTEN:'true',
  CRON_ENABLED:'false',
  NODE_ENV:'test'
});
const ai=await import('../src/ai.js');

test('Gemini quota then timeout falls through exactly once per model to rescue',async()=>{
  const calls=[];
  const client={interactions:{create:async(payload,options)=>{
    calls.push({model:payload.model,timeout:options.timeout,retries:options.retries});
    if(payload.model==='gemini-3.8-flash')throw Object.assign(new Error('quota exceeded'),{status:429});
    if(payload.model==='gemini-3.7-flash')throw Object.assign(new Error('socket timed out'),{code:'ETIMEDOUT'});
    return {status:'completed',output_text:'{"ok":true}'};
  }}};
  const result=await ai.callGemini({prompt:'fixture',overallTimeoutMs:3000},{client});
  assert.equal(result.model,'gemini-3.5-flash-lite');
  assert.deepEqual(calls.map(row=>row.model),['gemini-3.8-flash','gemini-3.7-flash','gemini-3.5-flash-lite']);
  assert.ok(calls.every(row=>row.retries.strategy==='none'));
});

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

test('campaign AI normalizes harmless provider formatting and still rejects impossible values',()=>{
  const base={
    objective:'OUTCOME_ENGAGEMENT',optimizationGoal:'CONVERSATIONS',destination:'WHATSAPP',
    audienceHypothesis:'Hipotez',placements:['Instagram Feed'],dailyBudgetMin:200,dailyBudgetMax:100,
    testDurationDays:7,recommendedCreativeFormat:'POST',primaryTextAngle:'Açı',headline:'Başlık',
    cta:'WhatsApp üzerinden bize yazın.',recommendedTime:'19.00',scheduleReason:'Test',
    rationaleSummary:'Gerekçe',confidence:40,assumptions:[],missingPrerequisites:[]
  };
  const normalized=ai.normalizeCampaignStrategy(base,{budgetLimit:300,reportAvailable:true,memoryOutcomeCount:2});
  assert.equal(normalized.dailyBudgetRange.min,100);
  assert.equal(normalized.dailyBudgetRange.max,200);
  assert.equal(normalized.timing.recommendedTime,'19:00');
  assert.ok(normalized.warnings.some(row=>row.includes('normalleştirildi')));
  assert.throws(()=>ai.normalizeCampaignStrategy({...base,dailyBudgetMin:-1,dailyBudgetMax:150},{budgetLimit:300,reportAvailable:true,memoryOutcomeCount:2}));
  assert.throws(()=>ai.normalizeCampaignStrategy({...base,dailyBudgetMin:100,dailyBudgetMax:150,recommendedTime:'25:99'},{budgetLimit:300,reportAvailable:true,memoryOutcomeCount:2}));
});

test('campaign AI separates provider success from recommendation quality failure',async()=>{
  const result=await ai.generateCampaignStrategy({budgetLimit:150},{
    request:async()=>({model:'fixture-gemini',parsed:{
      objective:'OUTCOME_ENGAGEMENT',optimizationGoal:'CONVERSATIONS',destination:'WHATSAPP',
      audienceHypothesis:'',placements:['Instagram Feed'],dailyBudgetMin:100,dailyBudgetMax:150,
      testDurationDays:7,recommendedCreativeFormat:'POST',primaryTextAngle:'Açı',headline:'Başlık',
      cta:'WhatsApp üzerinden bize yazın.',recommendedTime:'19:00',scheduleReason:'Test',
      rationaleSummary:'Gerekçe',confidence:40,assumptions:[],missingPrerequisites:[]
    }})
  });
  assert.equal(result.available,false);
  assert.equal(result.providerSucceeded,true);
  assert.equal(result.model,'fixture-gemini');
  assert.equal(result.errorCategory,'RECOMMENDATION_VALIDATION');
  assert.equal(result.failureStage,'QUALITY_GATE');
});

test('Gemini HTTP 400 is classified as request validation, not connectivity',()=>{
  const error=Object.assign(new Error('INVALID_ARGUMENT'),{status:400});
  const safe=ai.safeGeminiError(error);
  assert.equal(safe.category,'REQUEST_VALIDATION_ERROR');
  assert.equal(safe.status,400);
});
