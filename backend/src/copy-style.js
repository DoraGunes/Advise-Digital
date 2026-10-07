export const COPY_STYLE_DIMENSIONS = {
  tone:['professional','friendly','playful','premium','direct','educational'],
  hookType:['question','curiosity','benefit','problem','surprise','story','proof'],
  captionLength:['short','medium','long'],
  cta:['whatsapp','dm','visitProfile','visitStore','save','share','comment','learnMore'],
  emojiDensity:['none','low','medium'],
  hashtagStrategy:['minimal','balanced','discovery']
};

const aliases={
  hook:'hookType',
  length:'captionLength',
  emoji:'emojiDensity',
  hashtags:'hashtagStrategy',
  profile:'visitProfile',
  store:'visitStore',
  learn_more:'learnMore'
};

function choice(key,value,fallback){
  const normalized=String(value??'').trim();
  const mapped=aliases[normalized]||normalized;
  return COPY_STYLE_DIMENSIONS[key].includes(mapped)?mapped:fallback;
}

export function normalizeCopyStyle(recipe={}, fallback={}) {
  const source=recipe&&typeof recipe==='object'?recipe:{};
  const base=fallback&&typeof fallback==='object'?fallback:{};
  return {
    tone:choice('tone',source.tone??base.tone,'professional'),
    hookType:choice('hookType',source.hookType??source.hook??base.hookType??base.hook,'benefit'),
    captionLength:choice('captionLength',source.captionLength??source.length??base.captionLength??base.length,'medium'),
    cta:choice('cta',source.cta??base.cta,'whatsapp'),
    emojiDensity:choice('emojiDensity',source.emojiDensity??source.emoji??base.emojiDensity??base.emoji,'low'),
    hashtagStrategy:choice('hashtagStrategy',source.hashtagStrategy??source.hashtags??base.hashtagStrategy??base.hashtags,'balanced')
  };
}

export function toQualityStyleRecipe(recipe={}) {
  const normalized=normalizeCopyStyle(recipe);
  return {
    tone:normalized.tone,
    hook:normalized.hookType,
    length:normalized.captionLength,
    cta:normalized.cta==='visitProfile'?'profile':normalized.cta==='visitStore'?'store':normalized.cta==='learnMore'?'learn_more':normalized.cta,
    emoji:normalized.emojiDensity,
    hashtags:normalized.hashtagStrategy
  };
}

function emojiCount(value){
  return (String(value??'').match(/\p{Extended_Pictographic}/gu)||[]).length;
}

function hashtagCount(value){
  return (String(value??'').match(/(?:^|\s)#[\p{L}\p{N}_]+/gu)||[]).length;
}

export function inferCopyStyle({text='',hook='',cta='',base={},hashtags=[]}={}) {
  const copy=String(text??'').trim();
  const normalized=normalizeCopyStyle(base);
  const words=copy.split(/\s+/).filter(Boolean).length;
  const emojis=emojiCount(copy);
  const tags=Array.isArray(hashtags)?hashtags.length:hashtagCount(copy);
  const hookText=String(hook??'').trim();
  const ctaText=String(cta??'').toLocaleLowerCase('tr-TR');
  return normalizeCopyStyle({
    ...normalized,
    captionLength:words<45?'short':words>130?'long':'medium',
    hookType:hookText.endsWith('?')?'question':normalized.hookType,
    cta:/whatsapp|whats\s*app/.test(ctaText)?'whatsapp':normalized.cta,
    emojiDensity:emojis===0?'none':emojis<=3?'low':'medium',
    hashtagStrategy:tags<=5?'minimal':tags>=14?'discovery':'balanced'
  });
}

function fold(value){
  return String(value??'').normalize('NFKC').toLocaleLowerCase('tr-TR')
    .normalize('NFD').replace(/\p{M}+/gu,'')
    .replace(/[^\p{L}\p{N}]+/gu,' ').trim();
}

function similarity(a,b){
  const left=new Set(fold(a).split(/\s+/).filter(x=>x.length>2));
  const right=new Set(fold(b).split(/\s+/).filter(x=>x.length>2));
  if(!left.size||!right.size)return 0;
  let common=0;
  for(const item of left)if(right.has(item))common++;
  return common/new Set([...left,...right]).size;
}

function daysOld(value){
  const stamp=Date.parse(value||'');
  return Number.isFinite(stamp)?Math.max(0,(Date.now()-stamp)/86400000):365;
}

function finalStyle(memory){
  return normalizeCopyStyle(
    memory?.finalOutput?.styleRecipe||
    memory?.styleRecipe||
    memory?.originalOutput?.styleRecipe||{}
  );
}

export function recommendCopyStyle(memories=[], input={}, override={}) {
  const rows=(Array.isArray(memories)?memories:[]).map(memory=>{
    const finalText=memory?.finalOutput?.caption||memory?.finalOutput?.publishedText||memory?.caption||memory?.originalOutput?.caption||'';
    const relevance=
      similarity([input.industry,input.sector,input.productCategory,input.title,input.context].join(' '),
                 [memory.industry,memory.sector,memory.productCategory,memory.productName,finalText].join(' '));
    const performance=Number(memory?.performanceSummary?.score??memory?.outcomeScore??0);
    const recency=Math.exp(-daysOld(memory.createdAt||memory.at)/120);
    const editSignal=memory?.finalOutput?0.35:0;
    const weight=Math.max(0.05,1+relevance*2+Math.max(-0.75,Math.min(1,performance))+recency*.35+editSignal);
    return {memory,style:finalStyle(memory),weight};
  });
  const selected=rows.sort((a,b)=>b.weight-a.weight).slice(0,5);
  const base=normalizeCopyStyle({});
  for(const key of Object.keys(COPY_STYLE_DIMENSIONS)){
    const totals=new Map();
    for(const row of selected)totals.set(row.style[key],(totals.get(row.style[key])||0)+row.weight);
    if(totals.size)base[key]=[...totals.entries()].sort((a,b)=>b[1]-a[1])[0][0];
  }
  const result=normalizeCopyStyle({...base,...(override&&typeof override==='object'?override:{})});
  const total=selected.reduce((sum,row)=>sum+row.weight,0);
  return {
    recipe:result,
    sampleSize:selected.length,
    confidence:selected.length===0?0:Number(Math.min(.95,(selected.length/5)*.55+Math.min(.4,total/18)).toFixed(2)),
    reason:selected.length
      ? 'Aynı tenantın en alakalı '+selected.length+' final içerik örneğindeki stil tercihleri ağırlıklandırıldı.'
      : 'Henüz yeterli kullanıcı final içeriği yok; güvenli varsayılan stil kullanıldı.'
  };
}
