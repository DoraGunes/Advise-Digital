const MODES = new Set(['MINIMAL','BALANCED','DISCOVERY']);
const USES = new Set(['ORGANIC','PAID']);
const GROUPS = ['broad','niche','local','branded','intent'];
const SPAM_KEYS = new Set([
  'follow4follow','followforfollow','like4like','likeforlike','takipetakip',
  'takipcitakipci','spam','fypfyp','freefollowers','freefollow'
]);
const INTENT_KEYS = ['satinal','siparis','fiyat','teklif','randevu','rezervasyon','servis','destek','whatsapp','iletisim'];
const LIMITS = {
  ORGANIC:{MINIMAL:5,BALANCED:12,DISCOVERY:18},
  PAID:{MINIMAL:0,BALANCED:2,DISCOVERY:3}
};
const CAPS = {
  MINIMAL:{broad:1,niche:3,local:1,branded:1,intent:2},
  BALANCED:{broad:3,niche:5,local:2,branded:2,intent:3},
  DISCOVERY:{broad:6,niche:7,local:3,branded:3,intent:4}
};
const ORDERS = {
  MINIMAL:['niche','intent','local','branded','broad'],
  BALANCED:['niche','local','intent','branded','broad'],
  DISCOVERY:['broad','niche','local','intent','branded']
};

export function normalizeHashtagMode(value) {
  const mode=String(value||'BALANCED').trim().toUpperCase();
  return MODES.has(mode)?mode:'BALANCED';
}

export function normalizeHashtagUse(value) {
  const use=String(value||'ORGANIC').trim().toUpperCase();
  return USES.has(use)?use:'ORGANIC';
}

function folded(value) {
  return String(value??'').normalize('NFKC').toLocaleLowerCase('tr-TR')
    .normalize('NFD').replace(/\p{M}+/gu,'')
    .replace(/[^\p{L}\p{N}]+/gu,' ').trim();
}

function compact(values) {
  return values.flatMap(value=>Array.isArray(value)?value:[value])
    .map(value=>String(value??'').trim()).filter(Boolean);
}

function meaningfulWords(value) {
  const stop=new Set(['icin','ile','ve','veya','bir','bu','su','olan','olarak','daha','urun','hizmet','gorsel','video','post','reels','instagram']);
  return folded(value).split(/\s+/).filter(word=>word.length>=3&&!stop.has(word));
}

export function canonicalHashtag(value) {
  const raw=typeof value==='object'&&value
    ? value.hashtag??value.tag??value.value??''
    : value;
  const body=String(raw??'').normalize('NFKC').trim().replace(/^#+/,'')
    .replace(/\s+/g,'').replace(/[^\p{L}\p{N}_]+/gu,'').slice(0,50);
  return body?'#'+body:'';
}

function hashtagKey(value) {
  const tag=canonicalHashtag(value);
  return folded(tag.replace(/^#/,'')).replace(/\s+/g,'');
}

function normalizedGroup(value) {
  const group=String(value||'').trim().toLowerCase();
  return GROUPS.includes(group)?group:'';
}

function deriveCandidates(input) {
  const rows=[];
  const add=(value,group='')=>{
    const tag=canonicalHashtag(value);
    if(tag)rows.push({hashtag:tag,group,derived:true});
  };
  const phrase=value=>{
    const words=String(value??'').normalize('NFKC').trim().split(/[^\p{L}\p{N}]+/u).filter(Boolean);
    if(words.length) add(words.join(''));
  };
  phrase(input.title);
  phrase(input.industry);
  phrase(input.productCategory);
  meaningfulWords(input.title).slice(0,4).forEach(add);
  meaningfulWords(input.industry).slice(0,3).forEach(add);
  meaningfulWords(input.productCategory).slice(0,4).forEach(add);
  compact([input.businessName]).forEach(value=>add(value,'branded'));
  compact(input.locations||[]).slice(0,5).forEach(location=>{
    add(location,'local');
    const category=meaningfulWords(input.productCategory||input.industry)[0];
    if(category)add(location+category,'local');
  });
  return rows;
}

function keyList(values) {
  return compact(values||[]).map(hashtagKey).filter(Boolean);
}

function classify(key,row,ctx) {
  const explicit=normalizedGroup(row?.group);
  if(explicit)return explicit;
  if(ctx.branded.some(item=>key===item||key.includes(item)||item.includes(key)))return 'branded';
  if(ctx.local.some(item=>key===item||key.includes(item)||item.includes(key)))return 'local';
  if(INTENT_KEYS.some(item=>key.includes(item)))return 'intent';
  if(ctx.anchors.some(item=>key.includes(item)||item.includes(key)))return 'niche';
  return 'broad';
}

function rejectedByList(key, list) {
  return list.some(item=>key===item||(item.length>=4&&key.includes(item)));
}

function scoreCandidate(key,group,ctx,derived,index) {
  const base={branded:8,local:7,intent:5,niche:3.5,broad:1.5}[group]||1;
  const overlap=ctx.anchors.filter(item=>key.includes(item)||item.includes(key)).length;
  const repeated=ctx.recent.get(key)||0;
  return base+Math.min(6,overlap*2)+(derived?0.75:0)-Math.min(3,repeated*0.75)-(index*0.0001);
}

function sameSet(a,b) {
  if(a.length!==b.length)return false;
  const first=[...a].map(hashtagKey).sort();
  const second=[...b].map(hashtagKey).sort();
  return first.every((value,index)=>value===second[index]);
}

export function buildHashtagStrategy(input={}) {
  const mode=normalizeHashtagMode(input.mode);
  const contentUse=normalizeHashtagUse(input.contentUse);
  const anchors=[...new Set(meaningfulWords(compact([
    input.title,input.context,input.industry,input.productCategory,input.brand,input.visualSummary
  ]).join(' ')))];
  const branded=keyList([input.businessName,input.brandedKeywords,input.brandedHashtags]);
  const local=keyList(input.locations||[]);
  const competitors=keyList([input.competitors,input.competitorHashtags]);
  const banned=keyList(input.bannedHashtags||[]);
  const recent=new Map();
  const recentSets=(Array.isArray(input.recentHashtagSets)?input.recentHashtagSets:[])
    .filter(Array.isArray).slice(-20);
  for(const set of recentSets)for(const tag of set){
    const key=hashtagKey(tag);
    if(key)recent.set(key,(recent.get(key)||0)+1);
  }
  const ctx={anchors,branded,local,recent};
  const source=[
    ...(Array.isArray(input.candidates)?input.candidates:[]),
    ...deriveCandidates(input)
  ];
  const accepted=[];
  const seen=new Set();
  const rejected={invalid:[],duplicate:[],spam:[],competitor:[],banned:[],irrelevant:[]};

  source.forEach((raw,index)=>{
    const tag=canonicalHashtag(raw);
    const key=hashtagKey(raw);
    if(!tag||!key){rejected.invalid.push(String(raw??''));return;}
    if(seen.has(key)){rejected.duplicate.push(tag);return;}
    seen.add(key);
    if(SPAM_KEYS.has(key)||/follow.*follow|like.*like|takip.*takip/.test(key)){rejected.spam.push(tag);return;}
    if(rejectedByList(key,competitors)){rejected.competitor.push(tag);return;}
    if(rejectedByList(key,banned)){rejected.banned.push(tag);return;}
    const row=raw&&typeof raw==='object'?raw:{};
    const group=classify(key,row,ctx);
    const score=scoreCandidate(key,group,ctx,row.derived===true,index);
    const explicit=Boolean(normalizedGroup(row.group));
    if(anchors.length&&score<3&&!explicit&&!['local','branded','intent'].includes(group)){
      rejected.irrelevant.push(tag);return;
    }
    accepted.push({tag,key,group,score,index});
  });

  accepted.sort((a,b)=>b.score-a.score||a.index-b.index||a.key.localeCompare(b.key,'tr'));
  const limit=LIMITS[contentUse][mode];
  const allowedGroups=contentUse==='PAID'
    ? new Set(['niche','local','branded','intent'])
    : new Set(GROUPS);
  const caps=CAPS[mode];
  const selected=[];
  const counts=Object.fromEntries(GROUPS.map(group=>[group,0]));
  const add=row=>{
    if(selected.length>=limit||!allowedGroups.has(row.group)||counts[row.group]>=caps[row.group]||selected.some(item=>item.key===row.key))return;
    selected.push(row);counts[row.group]++;
  };

  if(limit>0){
    for(const group of ORDERS[mode]){
      const row=accepted.find(item=>item.group===group&&allowedGroups.has(item.group));
      if(row)add(row);
    }
    for(const row of accepted)add(row);
  }

  if(selected.length&&recentSets.some(set=>sameSet(selected.map(row=>row.tag),set))){
    const replacement=accepted.find(row=>!selected.some(item=>item.key===row.key)&&allowedGroups.has(row.group));
    if(replacement){
      const removed=selected.pop();
      counts[removed.group]--;
      add(replacement);
    }
  }

  const groups=Object.fromEntries(GROUPS.map(group=>[
    group,
    selected.filter(row=>row.group===group).map(row=>row.tag)
  ]));
  return {
    strategyVersion:'HASHTAG_V1',
    mode,
    contentUse,
    hashtags:selected.map(row=>row.tag),
    candidates:accepted.map(row=>row.tag),
    groups,
    rejected:Object.fromEntries(Object.entries(rejected).map(([key,value])=>[key,value.slice(0,30)])),
    availableCandidateCount:accepted.length
  };
}
