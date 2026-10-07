import fs from 'node:fs/promises';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {dataRoot, withDataLock} from './persistence.js';
import {normalizeCopyStyle, inferCopyStyle, recommendCopyStyle} from './copy-style.js';

const root=dataRoot;
const memoryFile=path.join(root,'ai_memory.json');
const VERSION=3;
const DEFAULT={version:VERSION,tenants:{}};

function serialized(task){return withDataLock(task);}
function clean(value,max=500){return String(value??'').trim().slice(0,max);}
function finiteOrNull(value){const n=Number(value);return value==null||value===''||!Number.isFinite(n)?null:n;}
function nowIso(){return new Date().toISOString();}

function emptyTenant(){
  return {
    generations:[],
    patterns:{hooks:[],hookTypes:[],angles:[],tones:[],formats:[],times:[],audiences:[],styles:[]},
    outcomes:[]
  };
}

function packSnapshot(pack={}){
  return {
    source:clean(pack.source,80),
    sourceModel:clean(pack.providerModel||pack.modelUsed,120),
    productName:clean(pack.productName,180),
    brand:clean(pack.brand,100),
    model:clean(pack.model,120),
    industry:clean(pack.industry,100),
    productCategory:clean(pack.productCategory,100),
    detectedText:clean(pack.detectedText,900),
    detectedOffer:clean(pack.detectedOffer,300),
    hook:clean(pack.hook,300),
    hookType:clean(pack.hookType||pack.hookCategory,120),
    caption:clean(pack.caption,2200),
    cta:clean(pack.cta,300),
    hashtags:Array.isArray(pack.hashtags)?pack.hashtags.slice(0,30).map(x=>clean(x,80)).filter(Boolean):[],
    headline:clean(pack.headline,180),
    primaryText:clean(pack.primaryText,2200),
    description:clean(pack.description,500),
    selectedTone:clean(pack.selectedTone,120),
    contentAngle:clean(pack.contentAngle,300),
    recommendedFormat:clean(pack.recommendedFormat,40),
    recommendedPostTime:clean(pack.recommendedPostTime||pack.recommendedPublishTime,40),
    visualAngle:clean(pack.visualAngle,700),
    targetAudience:clean(pack.targetAudience,500),
    visualSummary:clean(pack.visualSummary,700),
    contentGoal:clean(pack.contentGoal,120),
    contactChannel:clean(pack.contactChannel,40),
    styleRecipe:normalizeCopyStyle(pack.styleRecipe||{}),
    rationaleSummary:clean(pack.rationaleSummary,700)
  };
}

function extractHashtags(text){
  return [...new Set((String(text??'').match(/#[\p{L}\p{N}_]+/gu)||[]).map(tag=>tag.slice(0,80)))].slice(0,30);
}

function normalizedEditDistance(a,b){
  const left=String(a??'').slice(0,2400),right=String(b??'').slice(0,2400);
  if(left===right)return 0;
  if(!left.length||!right.length)return 1;
  let prev=Array.from({length:right.length+1},(_,i)=>i);
  for(let i=1;i<=left.length;i++){
    const next=[i];
    for(let j=1;j<=right.length;j++){
      next[j]=Math.min(
        next[j-1]+1,
        prev[j]+1,
        prev[j-1]+(left[i-1]===right[j-1]?0:1)
      );
    }
    prev=next;
  }
  return Number((prev[right.length]/Math.max(left.length,right.length)).toFixed(4));
}

function normalizeGeneration(row={},tenantId=''){
  const original=row.originalOutput&&typeof row.originalOutput==='object'
    ? {...packSnapshot(row.originalOutput)}
    : packSnapshot(row);
  const finalRaw=row.finalOutput&&typeof row.finalOutput==='object'?row.finalOutput:null;
  const finalOutput=finalRaw?{
    publishedText:clean(finalRaw.publishedText||finalRaw.caption,2200),
    caption:clean(finalRaw.caption||finalRaw.publishedText,2200),
    hook:clean(finalRaw.hook,300),
    cta:clean(finalRaw.cta,300),
    hashtags:Array.isArray(finalRaw.hashtags)?finalRaw.hashtags.slice(0,30).map(x=>clean(x,80)).filter(Boolean):extractHashtags(finalRaw.caption||finalRaw.publishedText),
    headline:clean(finalRaw.headline,180),
    styleRecipe:normalizeCopyStyle(finalRaw.styleRecipe||row.styleRecipe||original.styleRecipe),
    editedAt:clean(finalRaw.editedAt||row.editedAt,60)
  }:null;
  const createdAt=clean(row.createdAt||row.at,60)||nowIso();
  return {
    ...row,
    id:clean(row.id,120)||'mem_'+randomUUID(),
    tenantId:clean(row.tenantId||tenantId,120),
    accountId:clean(row.accountId,120),
    postId:clean(row.postId,120),
    createdAt,
    at:createdAt,
    linkedAt:clean(row.linkedAt,60),
    publishedAt:clean(row.publishedAt||row.publishTimestamp,60),
    mediaType:clean(row.mediaType,40)||'AUTO',
    industry:clean(row.industry||original.industry,100),
    sector:clean(row.sector||row.industry||original.industry,100),
    productCategory:clean(row.productCategory||original.productCategory,100),
    productName:clean(row.productName||original.productName,180),
    brand:clean(row.brand||original.brand,100),
    model:clean(row.model||original.model,120),
    mediaUnderstanding:row.mediaUnderstanding&&typeof row.mediaUnderstanding==='object'?{
      detectedText:clean(row.mediaUnderstanding.detectedText,900),
      detectedOffer:clean(row.mediaUnderstanding.detectedOffer,300),
      visualSummary:clean(row.mediaUnderstanding.visualSummary,700)
    }:{
      detectedText:original.detectedText,
      detectedOffer:original.detectedOffer,
      visualSummary:original.visualSummary
    },
    productServiceHints:Array.isArray(row.productServiceHints)?row.productServiceHints.slice(0,20).map(x=>clean(x,180)).filter(Boolean):[original.productName,original.productCategory,original.brand,original.model].filter(Boolean),
    originalOutput:original,
    finalOutput,
    hook:finalOutput?.hook||original.hook,
    hookType:clean(row.hookType||original.hookType,120),
    caption:finalOutput?.caption||original.caption,
    cta:finalOutput?.cta||original.cta,
    hashtags:finalOutput?.hashtags||original.hashtags,
    headline:finalOutput?.headline||original.headline,
    selectedTone:clean(row.selectedTone||original.selectedTone,120),
    contentAngle:clean(row.contentAngle||original.contentAngle,300),
    recommendedFormat:clean(row.recommendedFormat||original.recommendedFormat,40),
    recommendedPostTime:clean(row.recommendedPostTime||original.recommendedPostTime,40),
    targetAudience:clean(row.targetAudience||original.targetAudience,500),
    visualSummary:clean(row.visualSummary||original.visualSummary,700),
    visualAngle:clean(row.visualAngle||original.visualAngle,700),
    contentGoal:clean(row.contentGoal||original.contentGoal,120),
    contactChannel:clean(row.contactChannel||original.contactChannel,40),
    styleRecipe:normalizeCopyStyle(finalOutput?.styleRecipe||row.styleRecipe||original.styleRecipe),
    source:clean(row.source||original.source,80),
    modelUsed:clean(row.modelUsed||row.sourceModel||original.sourceModel,120),
    sourceModel:clean(row.sourceModel||row.modelUsed||original.sourceModel,120),
    performanceSummary:row.performanceSummary&&typeof row.performanceSummary==='object'?row.performanceSummary:null,
    userEditDistance:finiteOrNull(row.userEditDistance)??(finalOutput?normalizedEditDistance(original.caption,finalOutput.caption):0),
    userEdited:Boolean(row.userEdited||finalOutput)
  };
}

function normalizeDb(value){
  const db=value&&typeof value==='object'?value:{};
  if(!db.tenants||typeof db.tenants!=='object'||Array.isArray(db.tenants))db.tenants={};
  for(const [id,original] of Object.entries(db.tenants)){
    const tenant=original&&typeof original==='object'?original:{};
    const fresh=emptyTenant();
    tenant.generations=Array.isArray(tenant.generations)?tenant.generations.map(row=>normalizeGeneration(row,id)):fresh.generations;
    tenant.outcomes=Array.isArray(tenant.outcomes)?tenant.outcomes:fresh.outcomes;
    tenant.patterns=tenant.patterns&&typeof tenant.patterns==='object'?tenant.patterns:fresh.patterns;
    for(const key of Object.keys(fresh.patterns))if(!Array.isArray(tenant.patterns[key]))tenant.patterns[key]=[];
    db.tenants[id]=tenant;
  }
  db.version=VERSION;
  return db;
}

async function readMemory(){
  await fs.mkdir(root,{recursive:true});
  try{
    const parsed=JSON.parse(await fs.readFile(memoryFile,'utf8'));
    const previous=Number(parsed?.version||0);
    const normalized=normalizeDb(parsed);
    if(previous!==VERSION)await writeMemory(normalized);
    return normalized;
  }catch(error){
    if(error?.code!=='ENOENT')throw error;
    return structuredClone(DEFAULT);
  }
}

async function writeMemory(data){
  await fs.mkdir(root,{recursive:true});
  const tempFile=memoryFile+'.'+process.pid+'.'+randomUUID()+'.tmp';
  try{
    await fs.writeFile(tempFile,JSON.stringify(data,null,2),'utf8');
    await fs.rename(tempFile,memoryFile);
  }catch(error){
    await fs.rm(tempFile,{force:true}).catch(()=>{});
    throw error;
  }
}

function tenantMemory(db,tenantId){
  const id=clean(tenantId,120)||'system';
  if(!db.tenants[id])db.tenants[id]=emptyTenant();
  return db.tenants[id];
}

function upsertPattern(list,key,value,delta=0,incrementUse=true){
  const text=clean(value,500);
  if(!text)return;
  const row=list.find(x=>x.key===key);
  if(row){
    if(incrementUse)row.uses=Number(row.uses||0)+1;
    row.score=Number(row.score||0)+delta;
    row.lastUsedAt=nowIso();
    row.value=text;
  }else list.push({key,value:text,uses:incrementUse?1:0,score:delta,lastUsedAt:nowIso()});
}

function preferred(generation={}){
  const final=generation.finalOutput;
  if(final&&typeof final==='object'){
    return {
      hook:clean(final.hook,300),
      caption:clean(final.caption||final.publishedText,2200),
      cta:clean(final.cta,300),
      hashtags:Array.isArray(final.hashtags)?final.hashtags:[],
      headline:clean(final.headline,180),
      styleRecipe:normalizeCopyStyle(final.styleRecipe||generation.styleRecipe||generation.originalOutput?.styleRecipe)
    };
  }
  return {
    hook:clean(generation.hook||generation.originalOutput?.hook,300),
    caption:clean(generation.caption||generation.originalOutput?.caption,2200),
    cta:clean(generation.cta||generation.originalOutput?.cta,300),
    hashtags:Array.isArray(generation.hashtags)?generation.hashtags:[],
    headline:clean(generation.headline||generation.originalOutput?.headline,180),
    styleRecipe:normalizeCopyStyle(generation.styleRecipe||generation.originalOutput?.styleRecipe)
  };
}

function learnPatterns(memory,generation,delta=0,incrementUse=true){
  const output=preferred(generation);
  const values={
    hooks:output.hook,
    hookTypes:generation.hookType,
    angles:generation.contentAngle,
    tones:output.styleRecipe.tone||generation.selectedTone,
    formats:generation.recommendedFormat,
    times:generation.recommendedPostTime,
    audiences:generation.targetAudience,
    styles:JSON.stringify(output.styleRecipe)
  };
  for(const [key,value] of Object.entries(values))upsertPattern(memory.patterns[key],value,value,delta,incrementUse);
}

function trimLists(memory){
  memory.generations=memory.generations.slice(-750);
  memory.outcomes=memory.outcomes.slice(-750);
  for(const key of Object.keys(memory.patterns||{})){
    memory.patterns[key]=(memory.patterns[key]||[])
      .sort((a,b)=>Number(b.score||0)-Number(a.score||0)||Number(b.uses||0)-Number(a.uses||0))
      .slice(0,120);
  }
}

export async function learnFromGeneration(tenantId,pack,input={}){
  return serialized(async()=>{
    const db=await readMemory(),memory=tenantMemory(db,tenantId);
    const original=packSnapshot(pack);
    const generation=normalizeGeneration({
      id:clean(input.generationId,120)||'mem_'+randomUUID(),
      tenantId:clean(tenantId,120)||'system',
      accountId:clean(input.accountId,120),
      createdAt:nowIso(),
      postId:clean(input.postId,120),
      mediaType:clean(input.mediaType||pack.mediaType,40)||'AUTO',
      industry:clean(pack.industry,100),
      sector:clean(pack.industry,100),
      productCategory:clean(pack.productCategory,100),
      productName:clean(pack.productName,180),
      brand:clean(pack.brand,100),
      model:clean(pack.model,120),
      mediaUnderstanding:{detectedText:original.detectedText,detectedOffer:original.detectedOffer,visualSummary:original.visualSummary},
      productServiceHints:[original.productName,original.productCategory,original.brand,original.model].filter(Boolean),
      originalOutput:original,
      finalOutput:null,
      styleRecipe:original.styleRecipe,
      source:original.source,
      sourceModel:original.sourceModel,
      userEditDistance:0,
      userEdited:false
    },tenantId);
    memory.generations.push(generation);
    trimLists(memory);
    await writeMemory(db);
    return generation;
  });
}

export async function linkGenerationToPost(tenantId,generationId,postId,input={}){
  const id=clean(generationId,120),post=clean(postId,120);
  if(!id||!post)return null;
  return serialized(async()=>{
    const db=await readMemory(),memory=tenantMemory(db,tenantId);
    const generation=memory.generations.find(row=>row.id===id);
    if(!generation)return null;
    generation.postId=post;
    generation.linkedAt=nowIso();
    if(Object.prototype.hasOwnProperty.call(input||{},'caption')){
      const finalText=clean(input.caption,2200);
      const original=packSnapshot(generation.originalOutput||generation);
      const hashtags=extractHashtags(finalText);
      const originalHook=original.hook&&finalText.includes(original.hook)?original.hook:'';
      const originalCta=original.cta&&finalText.includes(original.cta)?original.cta:'';
      const firstLine=clean(finalText.split(/\n+/).find(Boolean),300);
      const styleRecipe=inferCopyStyle({
        text:finalText,
        hook:originalHook||firstLine,
        cta:originalCta,
        base:generation.styleRecipe||original.styleRecipe,
        hashtags
      });
      generation.finalOutput={
        publishedText:finalText,
        caption:finalText,
        hook:originalHook||firstLine,
        cta:originalCta,
        hashtags,
        headline:clean(input.headline||original.headline,180),
        styleRecipe,
        editedAt:nowIso()
      };
      generation.caption=finalText;
      generation.hook=generation.finalOutput.hook;
      generation.cta=generation.finalOutput.cta;
      generation.hashtags=hashtags;
      generation.headline=generation.finalOutput.headline;
      generation.styleRecipe=styleRecipe;
      generation.userEditDistance=normalizedEditDistance(original.caption,finalText);
      generation.userEdited=generation.userEditDistance>0;
      generation.editedAt=generation.finalOutput.editedAt;
      learnPatterns(memory,generation,0,true);
    }
    if(input.publishedAt){
      generation.publishedAt=clean(input.publishedAt,60);
      generation.publishTimestamp=generation.publishedAt;
    }
    trimLists(memory);
    await writeMemory(db);
    return generation;
  });
}

export async function learnFromOutcome(tenantId,input={}){
  const postId=clean(input.postId,120);
  if(!postId)return null;
  return serialized(async()=>{
    const db=await readMemory(),memory=tenantMemory(db,tenantId);
    const generationId=clean(input.generationId,120);
    const generation=[...memory.generations].reverse().find(row=>generationId?row.id===generationId:row.postId===postId);
    if(!generation)return null;
    const adId=clean(input.adId,120);
    const messageCost=finiteOrNull(input.messageCost);
    const ctr=finiteOrNull(input.ctr);
    const messages=finiteOrNull(input.messages);
    const spend=finiteOrNull(input.spend);
    const costScore=messageCost==null?0:Math.max(-1,Math.min(1,2-messageCost));
    const ctrScore=ctr==null?0:Math.max(-1,Math.min(1,ctr/3));
    const messageScore=messages==null?0:Math.max(-1,Math.min(1,messages/20));
    const outcomeScore=Number(Math.max(-1,Math.min(1,costScore*.55+ctrScore*.25+messageScore*.20)).toFixed(3));
    const key=postId+':'+(adId||'post');
    const previous=memory.outcomes.find(row=>row.key===key);
    if(previous)learnPatterns(memory,generation,-Number(previous.outcomeScore||0),false);
    const outcome={key,at:nowIso(),postId,generationId:generation.id,adId,spend,messages,ctr,messageCost,outcomeScore};
    if(previous)Object.assign(previous,outcome);else memory.outcomes.push(outcome);
    generation.performanceSummary={
      score:outcomeScore,
      kind:adId?'PAID':'ORGANIC',
      measuredAt:outcome.at,
      messageCost,ctr,messages,spend
    };
    if(input.publishedAt){
      generation.publishedAt=clean(input.publishedAt,60);
      generation.publishTimestamp=generation.publishedAt;
    }
    learnPatterns(memory,generation,outcomeScore,false);
    trimLists(memory);
    await writeMemory(db);
    return {postId,outcomeScore,messageCost,ctr,messages};
  });
}

function terms(value){
  return new Set(clean(value,4000).toLocaleLowerCase('tr-TR')
    .normalize('NFD').replace(/[\u0300-\u036f]/g,'').replace(/[^\p{L}\p{N}]+/gu,' ')
    .split(/\s+/).filter(word=>word.length>2));
}
function daysOld(value){const stamp=Date.parse(value||'');return Number.isFinite(stamp)?Math.max(0,(Date.now()-stamp)/86400000):365;}
function similarity(a,b){
  if(!a?.size||!b?.size)return 0;
  let common=0;for(const word of a)if(b.has(word))common++;
  const union=new Set([...a,...b]).size;return union?common/union:0;
}
function sameText(a,b){
  const left=clean(a,180).toLocaleLowerCase('tr-TR'),right=clean(b,180).toLocaleLowerCase('tr-TR');
  return Boolean(left&&right&&left===right);
}

function rankContentMemories(memory,input={},limit=5){
  const sectorQuery=terms([input.sector,input.industry].join(' '));
  const productQuery=terms([input.title,input.productName,input.productCategory,input.brand,input.model,input.context].join(' '));
  const mediaQuery=terms([input.visualSummary,input.detectedText,input.mediaUnderstanding,input.context].join(' '));
  const creativeQuery=terms([input.hook,input.caption,input.title,input.context,input.visualSummary].join(' '));
  const desiredFormat=clean(input.recommendedFormat||input.format||input.mediaType,40).toUpperCase();
  const rows=memory.generations.map(generation=>{
    const output=preferred(generation);
    const sectorSimilarity=similarity(sectorQuery,terms([generation.sector,generation.industry].join(' ')));
    const productSimilarity=similarity(productQuery,terms([generation.productName,generation.productCategory,generation.brand,generation.model,...(generation.productServiceHints||[])].join(' ')));
    const mediaSimilarity=similarity(mediaQuery,terms([generation.mediaUnderstanding?.detectedText,generation.mediaUnderstanding?.visualSummary,generation.visualSummary].join(' ')));
    const formatSimilarity=!desiredFormat||desiredFormat==='AUTO'?0.5:
      [generation.recommendedFormat,generation.mediaType].map(x=>String(x||'').toUpperCase()).includes(desiredFormat)?1:0;
    const performanceScore=Math.max(-1,Math.min(1,Number(generation.performanceSummary?.score||0)));
    const recency=Math.exp(-daysOld(generation.createdAt||generation.at)/120);
    const userEditSignal=generation.finalOutput?Math.min(1,.35+Number(generation.userEditDistance||0)):0;
    const directCreativeQuery=terms([input.hook,input.caption,input.title,input.context].join(' '));
    const directCreativeMemory=terms([output.hook,output.caption].join(' '));
    const creativeSimilarity=Math.max(
      similarity(creativeQuery,terms([output.hook,output.caption,generation.visualSummary].join(' '))),
      similarity(directCreativeQuery,directCreativeMemory)
    );
    const noveltyPenalty=creativeSimilarity>.72?(creativeSimilarity-.72)*5:0;
    const score=
      sectorSimilarity*2.2+
      productSimilarity*3.0+
      mediaSimilarity*2.0+
      formatSimilarity*.8+
      performanceScore*1.8+
      recency*.65+
      userEditSignal*.8-
      noveltyPenalty;
    return {
      generation,
      score,
      components:{sectorSimilarity,productSimilarity,mediaSimilarity,formatSimilarity,performanceScore,recency,userEditSignal,noveltyPenalty},
      creativeSimilarity
    };
  });
  return rows.sort((a,b)=>b.score-a.score||Date.parse(b.generation.createdAt||'')-Date.parse(a.generation.createdAt||'')).slice(0,Math.max(1,Math.min(5,limit)));
}

export async function retrieveContentMemories(tenantId,input={},options={}){
  return serialized(async()=>{
    const db=await readMemory(),memory=tenantMemory(db,tenantId);
    return rankContentMemories(memory,input,options.limit||5).map(row=>({
      id:row.generation.id,
      postId:row.generation.postId,
      score:Number(row.score.toFixed(4)),
      components:Object.fromEntries(Object.entries(row.components).map(([k,v])=>[k,Number(v.toFixed(4))])),
      creativeSimilarity:Number(row.creativeSimilarity.toFixed(4)),
      originalOutput:row.generation.originalOutput,
      finalOutput:row.generation.finalOutput,
      preferredOutput:preferred(row.generation),
      styleRecipe:row.generation.styleRecipe,
      performanceSummary:row.generation.performanceSummary,
      createdAt:row.generation.createdAt
    }));
  });
}

export async function getCopyStyleRecommendation(tenantId,input={},override={}){
  return serialized(async()=>{
    const db=await readMemory(),memory=tenantMemory(db,tenantId);
    const ranked=rankContentMemories(memory,input,5).map(row=>row.generation);
    return recommendCopyStyle(ranked,input,override);
  });
}

export async function buildMemoryContext(tenantId,input={}){
  return serialized(async()=>{
    const db=await readMemory(),memory=tenantMemory(db,tenantId);
    const ranked=rankContentMemories(memory,input,5);
    const examples=ranked.map(row=>{
      const generation=row.generation,output=preferred(generation);
      return {
        ürün:generation.productName,
        sektör:generation.sector||generation.industry,
        kategori:generation.productCategory,
        finalMetin:clean(output.caption,480),
        hook:output.hook,
        CTA:output.cta,
        hashtaglar:output.hashtags,
        stil:output.styleRecipe,
        format:generation.recommendedFormat,
        kitle:generation.targetAudience,
        kullanıcıDüzenlemeMesafesi:generation.userEditDistance,
        performans:generation.performanceSummary?.score==null?'henüz ölçülmedi':generation.performanceSummary.score,
        retrievalSkoru:Number(row.score.toFixed(2))
      };
    });
    const nearCopies=ranked.filter(row=>row.creativeSimilarity>.72).slice(0,3);
    const style=recommendCopyStyle(ranked.map(row=>row.generation),input,input.styleRecipeOverride||{});
    return [
      'ADVISE CONTENT MEMORY PALACE V3:',
      'Hafıza yalnızca aynı tenantın kayıtlarından oluşur. Gemini original çıktı audit için saklanır; öğrenmede kullanıcı final çıktısı varsa o önceliklidir.',
      'Weighted retrieval örnekleri: '+(examples.length?JSON.stringify(examples):'Henüz geçmiş örnek yok.'),
      'Copy Style önerisi: '+JSON.stringify(style),
      'Novelty uyarısı: '+(nearCopies.length?nearCopies.map(row=>(preferred(row.generation).hook||row.generation.productName)+' (benzerlik:'+row.creativeSimilarity.toFixed(2)+')').join(' | '):'Yakın kopya riski görünmüyor.'),
      'KURAL: Final kullanıcı dilinden stil ve yapı öğren; geçmiş metni kopyalama. Yüksek creative similarity varsa yeni hook/açı kullan. Geçmiş fiyat, kampanya, garanti veya performans iddiasını yeni içeriğe taşıma.'
    ].join('\n');
  });
}

export async function getMemorySummary(tenantId){
  return serialized(async()=>{
    const db=await readMemory(),memory=tenantMemory(db,tenantId);
    const linked=new Set(memory.generations.filter(row=>row.postId).map(row=>row.id));
    const recentGenerations=memory.generations.slice(-8).reverse().map(generation=>({
      id:generation.id,
      postId:generation.postId,
      productName:generation.productName,
      hook:preferred(generation).hook,
      recommendedFormat:generation.recommendedFormat,
      mediaType:generation.mediaType,
      createdAt:generation.createdAt,
      publishedAt:generation.publishedAt||null,
      userEdited:Boolean(generation.finalOutput),
      userEditDistance:Number(generation.userEditDistance||0),
      sourceModel:generation.sourceModel||null,
      performanceScore:generation.performanceSummary?.score??null
    }));
    const best=key=>(memory.patterns[key]||[]).filter(row=>Number(row.score)>0).sort((a,b)=>Number(b.score||0)-Number(a.score||0)).slice(0,5);
    const style=recommendCopyStyle(memory.generations.slice(-50),{},{});
    return {
      version:VERSION,
      memoryType:'CONTENT',
      generationCount:memory.generations.length,
      linkedGenerationCount:linked.size,
      finalOutputCount:memory.generations.filter(row=>row.finalOutput).length,
      outcomeCount:memory.outcomes.length,
      learningWins:memory.outcomes.filter(row=>Number(row.outcomeScore)>=.25).length,
      learningLessons:memory.outcomes.filter(row=>Number(row.outcomeScore)<=-.25).length,
      bestHooks:best('hooks'),
      bestHookTypes:best('hookTypes'),
      bestAngles:best('angles'),
      bestTimes:best('times'),
      bestFormats:best('formats'),
      bestAudiences:best('audiences'),
      copyStyleRecommendation:style,
      hasMeasuredInsights:memory.outcomes.length>0,
      recentGenerations
    };
  });
}
