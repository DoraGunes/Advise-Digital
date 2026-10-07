// Deterministic text checks complement vision; they cannot prove image facts.
export const STYLE_DIMENSIONS = {
  tone: ['professional','friendly','playful','premium','direct','educational'],
  hook: ['question','curiosity','benefit','problem','surprise','story','proof'],
  length: ['short','medium','long'],
  cta: ['whatsapp','dm','profile','store','save','share','comment','learn_more'],
  emoji: ['none','low','medium'],
  hashtags: ['minimal','balanced','discovery'],
};
export const STYLE_SCHEMA = {type:'object',properties:Object.fromEntries(Object.entries(STYLE_DIMENSIONS).map(([key,values])=>[key,{type:'string',enum:values}])),required:Object.keys(STYLE_DIMENSIONS)};
export const ALTERNATIVE_SCHEMA = {type:'object',properties:{hook:{type:'string'},caption:{type:'string'},cta:{type:'string'},visualAngle:{type:'string'}},required:['hook','caption','cta','visualAngle']};
export const normalizedText = value => String(value??'').normalize('NFKC').toLocaleLowerCase('tr-TR').replace(/[^\p{L}\p{N}]+/gu,' ').trim();
const words = value => normalizedText(value).split(' ').filter(x=>x.length>3&&!['ürün','görsel','içerik','için','olan','bize','üzerinden','whatsapp','detaylı','bilgi'].includes(x));
export function phraseOverlap(a,b) {
  const first=new Set(words(a)), second=new Set(words(b));
  return first.size&&second.size?[...first].filter(x=>second.has(x)).length/Math.min(first.size,second.size):0;
}
function schemaErrors(value,schema,path='pack') {
  const issues=[];
  if(schema.type==='object') {
    if(!value||typeof value!=='object'||Array.isArray(value))return [path+':OBJECT'];
    for(const key of schema.required||[])if(!(key in value))issues.push(path+'.'+key+':REQUIRED');
    for(const [key,child]of Object.entries(schema.properties||{}))if(key in value)issues.push(...schemaErrors(value[key],child,path+'.'+key));
  } else if(schema.type==='array') {
    if(!Array.isArray(value))return [path+':ARRAY'];
    if(value.length<(schema.minItems||0)||value.length>(schema.maxItems??50))issues.push(path+':COUNT');
    value.forEach((item,index)=>issues.push(...schemaErrors(item,schema.items,path+'.'+index)));
  } else if(schema.type==='string') {
    if(typeof value!=='string'||value.length>5000)issues.push(path+':STRING');
    else if(schema.enum&&!schema.enum.includes(value))issues.push(path+':ENUM');
  } else if(schema.type==='integer'&&(!Number.isInteger(value)||value<(schema.minimum??-Infinity)||value>(schema.maximum??Infinity)))issues.push(path+':INTEGER');
  return issues;
}
export function validateContentQuality(pack,input,schema) {
  const issues=schemaErrors(pack,schema);
  if(issues.length)return {passed:false,issues,score:0};
  const variants=[pack,...pack.alternatives];
  const evidence=normalizedText([input.context,input.detectedText,...(input.verifiedFacts||[])].filter(Boolean).join(' '));
  for(const [index,variant]of variants.entries()) {
    const prefix=index?'alternative'+index:'main';
    if(variant.caption.trim().length<60||variant.caption.length>2200)issues.push(prefix+':CAPTION_LENGTH');
    if(variant.hook.trim().length<8||!variant.cta.trim()||!variant.visualAngle.trim())issues.push(prefix+':MISSING_COPY');
    const copy=[variant.hook,variant.caption,variant.cta,variant.visualAngle,...(index===0?[pack.headline,pack.primaryText,pack.description,pack.detectedOffer,pack.adRecommendation,pack.nextAction]:[])].join(' ');
    if(/şimdi tam zamanı|kaçırmayın|benzersiz deneyim|kaliteli hizmet|siz de /iu.test(copy))issues.push(prefix+':GENERIC');
    if(/\uFFFD|Ã|Ä±|ÅŸ/u.test(copy))issues.push(prefix+':ENCODING');
    if(!/whatsapp/iu.test(variant.cta)||/\bdm\b|instagram.*mesaj/iu.test(copy))issues.push(prefix+':DESTINATION');
    const claims=copy.match(/\d+(?:[.,]\d+)?\s*(?:TL|₺|%|yıl garanti|ay garanti|GB|TB|MP|W\b|mAh|kg|cm|mm)|%\s*\d+|ücretsiz|garantili|kesin sonuç|en iyi|indirim|kampanya|stokta/giu)||[];
    if(claims.some(claim=>!(' '+evidence+' ').includes(' '+normalizedText(claim)+' ')))issues.push(prefix+':UNSUPPORTED_CLAIM');
    const count=new Map(); for(const word of words(copy))count.set(word,(count.get(word)||0)+1);
    if([...count.values()].some(n=>n>(index===0?9:5)))issues.push(prefix+':REPETITION');
    const anchor=[input.title,input.context,input.visualSummary,pack.visualSummary].filter(Boolean).join(' ');
    if(words(anchor).length&&!words(variant.caption).some(word=>words(anchor).includes(word)))issues.push(prefix+':MEDIA_RELATION');
    if((input.memoryExamples||[]).some(example=>normalizedText(variant.caption)===normalizedText(example.caption)||words(variant.caption).length>=8&&phraseOverlap(variant.caption,example.caption)>=.85))issues.push(prefix+':NEAR_COPY');
  }
  if(!pack.headline.trim()||!pack.primaryText.trim()||!pack.description.trim()||!pack.rationaleSummary.trim())issues.push('MAIN_FIELDS');
  if(!/^(?:[01]\d|2[0-3]):[0-5]\d$/.test(pack.recommendedPublishTime))issues.push('PUBLISH_TIME');
  if(pack.recommendedPublishTime!==pack.recommendedPostTime)issues.push('PUBLISH_TIME_MISMATCH');
  if(pack.styleRecipe.cta!=='whatsapp')issues.push('STYLE_DESTINATION');
  if(new Set(pack.alternatives.map(x=>normalizedText(x.hook))).size<3||new Set(pack.alternatives.map(x=>normalizedText(x.visualAngle))).size<3)issues.push('ALTERNATIVES_DUPLICATED');
  const tags=pack.hashtags.map(normalizedText);
  if(tags.some(x=>!x)||new Set(tags).size!==tags.length)issues.push('HASHTAG_DUPLICATE');
  return {passed:issues.length===0,issues:[...new Set(issues)],score:Math.max(0,100-issues.length*15)};
}
