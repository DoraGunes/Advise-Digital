import test,{after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';

const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-content-memory-'));
Object.assign(process.env,{
  ADVISE_DATA_DIR:path.join(fixture,'data'),
  ADVISE_UPLOAD_DIR:path.join(fixture,'uploads'),
  NODE_ENV:'test'
});
const memory=await import('../src/ai-memory.js');
const style=await import('../src/copy-style.js');

after(async()=>{await fs.rm(fixture,{recursive:true,force:true});});

function pack(overrides={}){
  return {
    source:'GEMINI',
    modelUsed:'fixture-model',
    productName:'Espresso Makinesi',
    brand:'Fixture',
    industry:'Kafe',
    productCategory:'Kahve ekipmanı',
    detectedText:'ESPRESSO',
    detectedOffer:'',
    hook:'Kahvenin ritmini değiştirmeye hazır mısın?',
    hookType:'question',
    caption:'Profesyonel espresso hazırlığı için sade ve güven veren bir içerik.',
    cta:'WhatsApp üzerinden bilgi al.',
    hashtags:['#Espresso','#KahveMakinesi','#BoluKafe'],
    headline:'Espresso deneyimi',
    primaryText:'Profesyonel espresso hazırlığı.',
    description:'Gerçek ürün görseline dayalı içerik.',
    selectedTone:'friendly',
    contentAngle:'Kullanım deneyimi',
    recommendedFormat:'REELS',
    recommendedPostTime:'19:30',
    visualAngle:'Makineyi kullanım anında göster.',
    targetAudience:'Kafe işletmeleri',
    visualSummary:'Tezgâh üzerinde espresso makinesi',
    contentGoal:'WhatsApp mesajı',
    contactChannel:'WHATSAPP',
    styleRecipe:{tone:'friendly',hook:'question',length:'medium',cta:'whatsapp',emoji:'low',hashtags:'balanced'},
    rationaleSummary:'Ürünü gerçek kullanım bağlamında anlat.',
    ...overrides
  };
}

test('original Gemini output remains immutable while user final output becomes learning source',async()=>{
  const generation=await memory.learnFromGeneration('tenant-a',pack(),{mediaType:'REELS'});
  const finalText='Bolu’da kahve molasına yeni bir ritim ☕\n\nEspressoyu daha sade anlatalım.\n\nWhatsApp üzerinden bize ulaş. #Espresso #BoluKafe';
  await memory.linkGenerationToPost('tenant-a',generation.id,'post-a',{caption:finalText});

  const rows=await memory.retrieveContentMemories('tenant-a',{title:'Bolu espresso',industry:'Kafe',mediaType:'REELS'});
  assert.equal(rows.length,1);
  assert.equal(rows[0].originalOutput.caption,'Profesyonel espresso hazırlığı için sade ve güven veren bir içerik.');
  assert.equal(rows[0].finalOutput.caption,finalText);
  assert.equal(rows[0].preferredOutput.caption,finalText);
  assert.ok(rows[0].finalOutput.hashtags.includes('#BoluKafe'));

  const summary=await memory.getMemorySummary('tenant-a');
  assert.equal(summary.version,3);
  assert.equal(summary.memoryType,'CONTENT');
  assert.equal(summary.finalOutputCount,1);
  assert.ok(summary.recentGenerations[0].userEditDistance>0);
  assert.equal(summary.recentGenerations[0].sourceModel,'fixture-model');
});

test('weighted retrieval favors matching sector product media format and user final text',async()=>{
  await memory.learnFromGeneration('tenant-ranking',pack({productName:'Otomobil Lastiği',industry:'Otomotiv',productCategory:'Lastik',recommendedFormat:'POST',caption:'Lastik bakımı.'}),{mediaType:'POST'});
  const matching=await memory.learnFromGeneration('tenant-ranking',pack({productName:'Filtre Kahve',caption:'Filtre kahve için öğütüm notları.'}),{mediaType:'REELS'});
  await memory.linkGenerationToPost('tenant-ranking',matching.id,'coffee-post',{caption:'Bolu kafe için filtre kahve öğütümünü kısa anlattık. #FiltreKahve #BoluKafe'});
  const rows=await memory.retrieveContentMemories('tenant-ranking',{title:'filtre kahve',industry:'Kafe',productCategory:'Kahve ekipmanı',mediaType:'REELS'});
  assert.equal(rows[0].id,matching.id);
  assert.ok(rows[0].components.productSimilarity>0);
  assert.equal(rows[0].components.formatSimilarity,1);
  assert.ok(rows[0].components.userEditSignal>0);
});

test('tenant isolation prevents final copy and style leakage',async()=>{
  const secretPhrase='SADECE_TENANT_A_FINAL_CUMLESI';
  const generation=await memory.learnFromGeneration('tenant-isolated-a',pack(),{mediaType:'REELS'});
  await memory.linkGenerationToPost('tenant-isolated-a',generation.id,'isolated-post',{caption:secretPhrase+' #Espresso'});
  const own=await memory.buildMemoryContext('tenant-isolated-a',{title:'espresso',industry:'Kafe'});
  const other=await memory.buildMemoryContext('tenant-isolated-b',{title:'espresso',industry:'Kafe'});
  assert.match(own,new RegExp(secretPhrase));
  assert.doesNotMatch(other,new RegExp(secretPhrase));
  const otherRows=await memory.retrieveContentMemories('tenant-isolated-b',{title:'espresso'});
  assert.equal(otherRows.length,0);
});

test('copy style engine infers final editing shape and supports explicit override',async()=>{
  const inferred=style.inferCopyStyle({
    text:'Kısa bir metin 🙂 #Bir #Iki',
    hook:'Hazır mısın?',
    cta:'WhatsApp üzerinden yaz.',
    base:{tone:'friendly',hook:'benefit',length:'long',cta:'whatsapp',emoji:'medium',hashtags:'discovery'}
  });
  assert.equal(inferred.tone,'friendly');
  assert.equal(inferred.hookType,'question');
  assert.equal(inferred.captionLength,'short');
  assert.equal(inferred.cta,'whatsapp');
  assert.equal(inferred.emojiDensity,'low');
  assert.equal(inferred.hashtagStrategy,'minimal');

  const recommended=style.recommendCopyStyle([{finalOutput:{caption:'Kısa final.',styleRecipe:inferred},createdAt:new Date().toISOString()}],{industry:'Kafe'},{tone:'premium',captionLength:'long'});
  assert.equal(recommended.recipe.tone,'premium');
  assert.equal(recommended.recipe.captionLength,'long');
  assert.equal(recommended.sampleSize,1);
});

test('near-copy detection is based on preferred final output',async()=>{
  const generation=await memory.learnFromGeneration('tenant-copy',pack({caption:'Orijinal metin farklıydı.'}),{mediaType:'POST'});
  const final='Kahve keyfini Bolu’da sade bir dille anlatıyoruz';
  await memory.linkGenerationToPost('tenant-copy',generation.id,'copy-post',{caption:final});
  const context=await memory.buildMemoryContext('tenant-copy',{title:'Kahve keyfini Bolu’da sade bir dille anlatıyoruz',context:final});
  assert.match(context,/Novelty uyarısı:/);
  assert.match(context,/benzerlik:/);
});
