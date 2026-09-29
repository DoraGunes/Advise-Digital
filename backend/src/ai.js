import {config} from './config.js';

const MODEL = process.env.OPENAI_MODEL || 'gpt-5.6-luna';
const API_URL = 'https://api.openai.com/v1/responses';

function clean(value, max=1200) {
  return String(value ?? '').trim().slice(0, max);
}

function localPack(input={}) {
  const title = clean(input.title, 180) || 'Ürün';
  const context = clean(input.context, 700);
  const tone = clean(input.tone, 80) || 'samimi ve güven veren';
  const goal = clean(input.goal, 80) || 'mesaj';
  const mediaType = String(input.mediaType || 'AUTO').toUpperCase();
  const format = mediaType === 'VIDEO' || mediaType === 'REELS' ? 'REELS' : 'POST';
  const extra = context ? ` ${context}` : '';
  const caption = `${title} için ${goal} odaklı, ${tone} bir içerik.${extra} Detaylar ve bilgi için bize mesaj gönderebilirsin.\n\n#${title.replace(/[^a-zA-Z0-9ğüşöçıİĞÜŞÖÇ]+/g,'').slice(0,24) || 'AdviseAI'} #PoyrazTeknik #Instagram`;
  return {
    source:'LOCAL_FALLBACK', model:null, caption,
    hook:`${title}: Fark yaratan detay burada.`,
    cta:'Detaylı bilgi ve fiyat için mesaj gönder.',
    hashtags:['#PoyrazTeknik','#kampanya','#fırsat','#ürün'],
    recommendedFormat:format,
    reason: format==='REELS' ? 'Video içerik için Reel formatı seçildi.' : 'Görsel içerik için normal gönderi formatı seçildi.'
  };
}

function parseOutput(text, input={}) {
  const raw=String(text||'').trim();
  if(!raw) return localPack(input);
  const cleaned=raw.replace(/^```[a-z]*\s*/i,'').replace(/\s*```$/,'').trim();
  const lines=cleaned.split(/\r?\n/).map(x=>x.trim()).filter(Boolean);
  const find=(label)=>{
    const row=lines.find(x=>new RegExp(`^${label}\\s*:`,'i').test(x));
    return row ? row.replace(new RegExp(`^${label}\\s*:`,'i'),'').trim() : '';
  };
  const caption=find('CAPTION') || cleaned;
  const hook=find('HOOK');
  const cta=find('CTA');
  const hashtags=find('HASHTAGS');
  const format=find('FORMAT');
  return {
    source:'OPENAI', model:MODEL,
    caption: caption.slice(0,2200),
    hook: hook || 'İlk satırda ürünün faydasını öne çıkar.',
    cta: cta || 'Detaylar için mesaj gönder.',
    hashtags: (hashtags ? hashtags.split(/\s+/).filter(x=>x.startsWith('#')) : []).slice(0,8),
    recommendedFormat: (format||'').toUpperCase().includes('REEL') ? 'REELS' : 'POST',
    reason:'İçerik bilgileri ve seçilen format için AI tarafından üretildi.'
  };
}

export async function generateContentPack(input={}) {
  const safe={
    title:clean(input.title,180), context:clean(input.context,900),
    tone:clean(input.tone,80)||'samimi, profesyonel ve güven veren',
    goal:clean(input.goal,80)||'mesaj', language:clean(input.language,30)||'Türkçe',
    mediaType:String(input.mediaType||'AUTO').toUpperCase(), imageUrl:clean(input.imageUrl,1500)
  };

  const apiKey=String(process.env.OPENAI_API_KEY||'').trim();
  if(!apiKey) return localPack(safe);

  const prompt=`Sen AdVise AI reklam ve sosyal medya içerik motorusun. Türkçe yaz.\nÜrün/başlık: ${safe.title||'-'}\nEk bilgi: ${safe.context||'-'}\nTon: ${safe.tone}\nAmaç: ${safe.goal}\nMedya: ${safe.mediaType}\n\nÇıktıyı tam olarak şu etiketlerle üret:\nCAPTION: kısa, doğal, satış baskısı olmayan ama aksiyona çağıran Instagram metni (en fazla 1200 karakter)\nHOOK: tek cümlelik ilk satır\nCTA: tek cümlelik çağrı\nHASHTAGS: 4-8 alakalı hashtag\nFORMAT: POST veya REELS\nKurgu: ürünün faydasını erken söyle, uydurma özellik/fiyat/indirim yazma, gereksiz emoji kullanma.`;

  const content=[{type:'input_text',text:prompt}];
  if(/^https:\/\//i.test(safe.imageUrl)) content.push({type:'input_image',image_url:safe.imageUrl});

  try {
    const response=await fetch(API_URL,{
      method:'POST',
      headers:{'content-type':'application/json',authorization:`Bearer ${apiKey}`},
      body:JSON.stringify({model:MODEL,input:[{role:'user',content}],max_output_tokens:700})
    });
    const data=await response.json();
    if(!response.ok) throw new Error(data?.error?.message || `AI API ${response.status}`);
    return parseOutput(data.output_text || '', safe);
  } catch (e) {
    const fallback=localPack(safe);
    return {...fallback,source:'LOCAL_FALLBACK_AFTER_AI_ERROR',error:e.message};
  }
}

export async function generateCaption(input={}) { return generateContentPack(input); }
export function aiStatus(){
  return {configured:Boolean(String(process.env.OPENAI_API_KEY||'').trim()), model:MODEL, provider:String(process.env.OPENAI_API_KEY||'').trim()?'OPENAI':'LOCAL_FALLBACK'};
}


function localVariants(input={}) {
  const base=localPack(input);
  const title=clean(input.title,180)||'Ürün';
  return {source:'LOCAL_FALLBACK',model:null,variants:[
    {id:'A',caption:base.caption,hook:base.hook,cta:base.cta,style:'Doğrudan'},
    {id:'B',caption:`${title}: İhtiyacın olan detayları tek yerde keşfet. ${base.cta}`,hook:`${title} hakkında bunu biliyor musun?`,cta:base.cta,style:'Merak uyandıran'},
    {id:'C',caption:`${title} için kısa ve net bilgi. ${base.cta}`,hook:'Kısa, net ve fayda odaklı.',cta:base.cta,style:'Minimal'}
  ]};
}

export async function generateCaptionVariants(input={}) {
  const safe={title:clean(input.title,180),context:clean(input.context,900),tone:clean(input.tone,80)||'samimi ve güven veren',goal:clean(input.goal,80)||'mesaj',language:clean(input.language,30)||'Türkçe',mediaType:String(input.mediaType||'AUTO').toUpperCase(),imageUrl:clean(input.imageUrl,1500)};
  const apiKey=String(process.env.OPENAI_API_KEY||'').trim();
  if(!apiKey) return localVariants(safe);
  const prompt=`AdVise AI için aynı Instagram içeriğinin 3 farklı caption varyasyonunu üret. Türkçe yaz.\nÜrün: ${safe.title||'-'}\nBilgi: ${safe.context||'-'}\nTon: ${safe.tone}\nAmaç: ${safe.goal}\nMedya: ${safe.mediaType}\nJSON döndür: {"variants":[{"id":"A","caption":"...","hook":"...","cta":"...","style":"..."},{"id":"B","caption":"...","hook":"...","cta":"...","style":"..."},{"id":"C","caption":"...","hook":"...","cta":"...","style":"..."}]}. Uydurma fiyat/özellik yazma.`;
  try {
    const r=await fetch(API_URL,{method:'POST',headers:{'content-type':'application/json',authorization:`Bearer ${apiKey}`},body:JSON.stringify({model:MODEL,input:[{role:'user',content:[{type:'input_text',text:prompt}]}],max_output_tokens:1000})});
    const data=await r.json(); if(!r.ok) throw new Error(data?.error?.message||`AI API ${r.status}`);
    const text=String(data.output_text||'').replace(/^```json\s*/i,'').replace(/\s*```$/,'').trim();
    const parsed=JSON.parse(text); if(!Array.isArray(parsed.variants)||parsed.variants.length<1) throw new Error('AI varyasyon cevabı geçersiz.');
    return {source:'OPENAI',model:MODEL,variants:parsed.variants.slice(0,3)};
  } catch(e) { return {...localVariants(safe),source:'LOCAL_FALLBACK_AFTER_AI_ERROR',error:e.message}; }
}

export async function scoreCreative(input={}) {
  const caption=clean(input.caption,2200), hook=clean(input.hook,300), cta=clean(input.cta,300);
  const hashtags=Array.isArray(input.hashtags)?input.hashtags.length:0;
  const mediaType=String(input.mediaType||'POST').toUpperCase();
  const scores={
    hook:Math.min(100,30+(hook.length?Math.min(45,hook.length):0)),
    caption:Math.min(100,35+(caption.length?Math.min(50,Math.round(caption.length/20)):0)),
    cta:Math.min(100,cta.length?82:30),
    format:['POST','REELS','CAROUSEL'].includes(mediaType)?85:55,
    hashtags:Math.min(100,hashtags*14),
  };
  scores.overall=Math.round(Object.values(scores).reduce((a,b)=>a+b,0)/Object.keys(scores).length);
  scores.signal=scores.overall>=80?'Güçlü hazırlık sinyali':scores.overall>=60?'Orta hazırlık sinyali':'İyileştirme gerekli';
  return {source:'HEURISTIC',scores,generatedAt:new Date().toISOString()};
}
