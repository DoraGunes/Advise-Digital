import test, {after} from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import {validateContentQuality} from '../src/content-quality.js';
const fixture=await fs.mkdtemp(path.join(os.tmpdir(),'advise-content-quality-'));
Object.assign(process.env,{DOTENV_CONFIG_PATH:path.join(fixture,'missing.env'),ADVISE_DATA_DIR:path.join(fixture,'data'),JWT_SECRET:'test-only-secret',ADMIN_USERNAME:'fixture',ADMIN_PASSWORD:'fixture',GEMINI_API_KEY:'',CRON_ENABLED:'false'});
const {OUTPUT_SCHEMA,generateContentPack}=await import('../src/ai.js');
after(()=>fs.rm(fixture,{recursive:true,force:true}));
const input={title:'Seramik kahve fincanı',context:'Mavi seramik fincanın yakın plan fotoğrafı.'};
function pack() {
  const result=Object.fromEntries(Object.entries(OUTPUT_SCHEMA.properties).filter(([,x])=>x.type==='string').map(([key])=>[key,'Görselde mavi seramik fincan yer alıyor.']));
  return {...result,productName:'Seramik fincan',hook:'Kahvene hangi fincan eşlik etsin?',caption:'Mavi seramik fincanın formunu yakından inceleyin. Kahve köşenizde nasıl duracağını düşünüyorsanız, detayları WhatsApp üzerinden konuşalım.',cta:'Fincan detayları için WhatsApp üzerinden yazın.',headline:'Mavi fincanı yakından tanıyın',primaryText:'Seramik fincanın yakın plan detaylarına bakın; sorularınızı WhatsApp üzerinden iletin.',description:'Görünen form ve renk üzerine ürün tanıtımı.',visualAngle:'Fincanın mavi rengine odaklan.',visualSummary:'Mavi seramik kahve fincanı.',recommendedFormat:'POST',recommendedPostTime:'19:30',recommendedPublishTime:'19:30',recommendedPostTimeReason:'Ölçülmüş geçmiş yok; deneme saati.',hashtags:['#seramik','#fincan','#kahve'],confidence:35,creativeScore:70,styleRecipe:{tone:'friendly',hook:'question',length:'medium',cta:'whatsapp',emoji:'low',hashtags:'balanced'},alternatives:[
    {hook:'Kahve köşene biraz mavi eklesen?',caption:'Mavi seramik fincanı kahve köşenizde hayal edin. Görseldeki formu daha yakından görmek için WhatsApp üzerinden bize yazabilirsiniz.',cta:'WhatsApp üzerinden detayları sor.',visualAngle:'Kahve köşesi ve renk uyumu.'},
    {hook:'Seramik formun detayına yakından bak.',caption:'Seramik fincanın formu bu yakın planda öne çıkıyor. Görseldeki detaylarla ilgili sorularınızı WhatsApp üzerinden paylaşabilirsiniz.',cta:'WhatsApp üzerinden sorularını ilet.',visualAngle:'Yakın plandaki seramik form.'},
    {hook:'Hangi renk fincanı tercih edersin?',caption:'Mavi fincan sade bir kahve sunumuna eşlik edebilir. Kendi tercihinizi ve sorularınızı WhatsApp üzerinden bizimle paylaşın.',cta:'WhatsApp üzerinden tercihini paylaş.',visualAngle:'Kişisel renk tercihi ve sunum.'},
  ]};
}
test('professional structured package with three distinct alternatives passes',()=>assert.equal(validateContentQuality(pack(),input,OUTPUT_SCHEMA).passed,true));
test('schema, generic, duplicated tags, missing fields and encoding are rejected',()=>{
  for(const mutate of [x=>delete x.headline,x=>x.caption='Şimdi tam zamanı! Kaçırmayın!',x=>x.hashtags=['#fincan','#FİNCAN'],x=>x.caption+=' \uFFFD',x=>x.styleRecipe.cta='dm',x=>x.alternatives[1]=x.alternatives[0]]) {
    const result=pack();mutate(result);assert.equal(validateContentQuality(result,input,OUTPUT_SCHEMA).passed,false);
  }
});
test('unsupported price discount guarantee cannot appear in caption or ad headline',()=>{
  for(const field of ['caption','headline','primaryText','adRecommendation','detectedOffer']) {
    const result=pack();result[field]+=' 500 TL ve %50 indirim, 2 yıl garanti.';
    assert.ok(validateContentQuality(result,input,OUTPUT_SCHEMA).issues.some(x=>x.endsWith('UNSUPPORTED_CLAIM')));
  }
});
test('near copies of final user text are penalized',()=>assert.ok(validateContentQuality(pack(),{...input,memoryExamples:[{caption:pack().caption}]},OUTPUT_SCHEMA).issues.includes('main:NEAR_COPY')));
test('one controlled regeneration succeeds with explicit source and safe telemetry',async()=>{
  let calls=0;const logs=[],original=console.log;console.log=(...x)=>logs.push(x);
  try {
    const result=await generateContentPack(input,{request:async options=>{calls++;assert.equal(options.maxAttempts,1);return {model:'fixture-model',parsed:calls===1?{caption:'Kısa'}:pack()};}});
    assert.equal(calls,2);assert.equal(result.source,'GEMINI_REGENERATED');assert.equal(result.regenerationUsed,true);assert.equal(result.quality.passed,true);assert.equal(result.alternatives.length,3);
    assert.ok(!JSON.stringify(logs).includes(input.context));
  } finally {console.log=original;}
});
test('second weak result falls back and does not silently normalize into Gemini',async()=>{
  let calls=0;const result=await generateContentPack(input,{request:async()=>{calls++;return {model:'fixture-model',parsed:{caption:'Generic'}};}});
  assert.equal(calls,2);assert.equal(result.source,'FALLBACK');assert.equal(result.providerModel,null);assert.equal(result.errorCategory,'QUALITY_REJECTED');assert.equal(result.quality.passed,false);
});
test('provider exception cannot expose secrets and fallback has truthful source',async()=>{
  const result=await generateContentPack(input,{request:async()=>{throw Object.assign(new Error('Unauthorized private-provider-key'),{status:401});}});
  assert.equal(result.source,'FALLBACK');assert.equal(result.errorCategory,'AUTHENTICATION_ERROR');assert.ok(!JSON.stringify(result).includes('private-provider-key'));
});
