import fs from 'node:fs/promises';
import path from 'node:path';
import {randomUUID} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {dataRoot, withDataLock} from './persistence.js';

const root = dataRoot;
const memoryFile = path.join(root, 'ai_memory.json');
const DEFAULT = {version: 2, tenants: {}};
function serialized(task) {
  return withDataLock(task);
}

function clean(value, max=500) { return String(value ?? '').trim().slice(0, max); }

function emptyTenant() {
  return {generations: [], patterns: {hooks: [], hookTypes: [], angles: [], tones: [], formats: [], times: [], audiences: []}, outcomes: []};
}

function normalizeDb(value) {
  const db = value && typeof value === 'object' ? value : {};
  if (!db.tenants || typeof db.tenants !== 'object' || Array.isArray(db.tenants)) db.tenants = {};
  for (const [id, original] of Object.entries(db.tenants)) {
    const tenant = original && typeof original === 'object' ? original : {};
    const fresh = emptyTenant();
    tenant.generations = Array.isArray(tenant.generations) ? tenant.generations.map(row => ({
      ...row,
      id: clean(row?.id, 120) || `mem_${randomUUID()}`,
      postId: clean(row?.postId, 120),
      mediaType: clean(row?.mediaType, 40) || 'AUTO',
      industry: clean(row?.industry, 100),
      productCategory: clean(row?.productCategory, 100)
    })) : fresh.generations;
    tenant.outcomes = Array.isArray(tenant.outcomes) ? tenant.outcomes : fresh.outcomes;
    tenant.patterns = tenant.patterns && typeof tenant.patterns === 'object' ? tenant.patterns : fresh.patterns;
    for (const key of Object.keys(fresh.patterns)) {
      if (!Array.isArray(tenant.patterns[key])) tenant.patterns[key] = [];
    }
    db.tenants[id] = tenant;
  }
  db.version = 2;
  return db;
}

async function readMemory() {
  await fs.mkdir(root, {recursive: true});
  try {
    const parsed = JSON.parse(await fs.readFile(memoryFile, 'utf8'));
    const normalized = normalizeDb(parsed);
    if (Number(parsed?.version) !== 2) await writeMemory(normalized);
    return normalized;
  }
  catch (error) {
    if (error?.code !== 'ENOENT') throw error;
    return structuredClone(DEFAULT);
  }
}

async function writeMemory(data) {
  await fs.mkdir(root, {recursive: true});
  const tempFile = `${memoryFile}.${process.pid}.${randomUUID()}.tmp`;
  try {
    await fs.writeFile(tempFile, JSON.stringify(data, null, 2), 'utf8');
    await fs.rename(tempFile, memoryFile);
  } catch (error) {
    await fs.rm(tempFile, {force: true}).catch(() => {});
    throw error;
  }
}

function tenantMemory(db, tenantId) {
  const id = clean(tenantId, 120) || 'system';
  if (!db.tenants[id]) db.tenants[id] = emptyTenant();
  return db.tenants[id];
}

function upsertPattern(list, key, value, delta=0, incrementUse=true) {
  const text = clean(value, 300);
  if (!text) return;
  const row = list.find(x => x.key === key);
  if (row) {
    if (incrementUse) row.uses = Number(row.uses || 0) + 1;
    row.score = Number(row.score || 0) + delta;
    row.lastUsedAt = new Date().toISOString();
  } else list.push({key, value: text, uses: incrementUse ? 1 : 0, score: delta, lastUsedAt: new Date().toISOString()});
}

function adjustOutcomePatterns(memory, generation, delta) {
  const values = {
    hooks: generation.hook,
    hookTypes: generation.hookType,
    angles: generation.contentAngle,
    tones: generation.selectedTone,
    formats: generation.recommendedFormat,
    times: generation.recommendedPostTime,
    audiences: generation.targetAudience
  };
  for (const [key, value] of Object.entries(values)) upsertPattern(memory.patterns[key], value, value, delta, false);
}

function trimLists(memory) {
  memory.generations = memory.generations.slice(-500);
  memory.outcomes = memory.outcomes.slice(-500);
  for (const key of Object.keys(memory.patterns || {})) {
    memory.patterns[key] = (memory.patterns[key] || [])
      .sort((a,b) => Number(b.score || 0) - Number(a.score || 0) || Number(b.uses || 0) - Number(a.uses || 0))
      .slice(0, 100);
  }
}

export async function learnFromGeneration(tenantId, pack, input={}) {
  return serialized(async () => {
    const db = await readMemory();
    const memory = tenantMemory(db, tenantId);
    const generation = {
      id: clean(input.generationId, 120) || `mem_${randomUUID()}`,
      at: new Date().toISOString(),
      postId: clean(input.postId, 120),
      productName: clean(pack.productName, 180), brand: clean(pack.brand, 100), model: clean(pack.model, 120),
      industry: clean(pack.industry, 100), productCategory: clean(pack.productCategory, 100),
      hook: clean(pack.hook, 300), hookType: clean(pack.hookType || pack.hookCategory, 120), caption: clean(pack.caption, 2200), cta: clean(pack.cta, 300),
      hashtags: Array.isArray(pack.hashtags) ? pack.hashtags.slice(0, 12).map(x => clean(x, 60)) : [],
      selectedTone: clean(pack.selectedTone, 120), contentAngle: clean(pack.contentAngle, 300),
      recommendedFormat: clean(pack.recommendedFormat, 40), recommendedPostTime: clean(pack.recommendedPostTime, 40),
      mediaType: clean(input.mediaType || pack.mediaType, 40) || 'AUTO',
      contentGoal: clean(pack.contentGoal, 120), contactChannel: clean(pack.contactChannel, 40), targetAudience: clean(pack.targetAudience, 500), visualSummary: clean(pack.visualSummary, 700),
      creativeScore: Number(pack.creativeScore || 0), source: clean(pack.source, 80), modelUsed: clean(pack.providerModel || pack.modelUsed, 100)
    };
    memory.generations.push(generation);
    upsertPattern(memory.patterns.hooks, generation.hook, generation.hook);
    upsertPattern(memory.patterns.hookTypes, generation.hookType, generation.hookType);
    upsertPattern(memory.patterns.angles, generation.contentAngle, generation.contentAngle);
    upsertPattern(memory.patterns.tones, generation.selectedTone, generation.selectedTone);
    upsertPattern(memory.patterns.formats, generation.recommendedFormat, generation.recommendedFormat);
    upsertPattern(memory.patterns.times, generation.recommendedPostTime, generation.recommendedPostTime);
    upsertPattern(memory.patterns.audiences, generation.targetAudience, generation.targetAudience);
    trimLists(memory);
    await writeMemory(db);
    return generation;
  });
}

export async function linkGenerationToPost(tenantId, generationId, postId, input={}) {
  const id = clean(generationId, 120);
  const post = clean(postId, 120);
  if (!id || !post) return null;
  return serialized(async () => {
    const db = await readMemory();
    const memory = tenantMemory(db, tenantId);
    const generation = memory.generations.find(row => row.id === id);
    if (!generation) return null;
    generation.postId = post;
    generation.linkedAt = new Date().toISOString();
    if (Object.prototype.hasOwnProperty.call(input || {}, 'caption')) {
      generation.caption = clean(input.caption, 2200);
      generation.userEdited = true;
      generation.editedAt = new Date().toISOString();
    }
    await writeMemory(db);
    return generation;
  });
}

export async function learnFromOutcome(tenantId, input={}) {
  const postId = clean(input.postId, 120);
  if (!postId) return null;
  return serialized(async () => {
    const db = await readMemory();
    const memory = tenantMemory(db, tenantId);
    const generationId = clean(input.generationId, 120);
    const generation = [...memory.generations].reverse().find(row => generationId ? row.id === generationId : row.postId === postId);
    if (!generation) return null;
    const adId = clean(input.adId, 120);
    const messageCost = input.messageCost == null || !Number.isFinite(Number(input.messageCost)) ? null : Number(input.messageCost);
    const ctr = Number(input.ctr || 0);
    const messages = Number(input.messages || 0);
    const spend = Number(input.spend || 0);
    const costScore = messageCost == null ? 0 : Math.max(-1, Math.min(1, 2 - messageCost));
    const ctrScore = Math.max(-1, Math.min(1, ctr / 3));
    const messageScore = Math.max(-1, Math.min(1, messages / 20));
    const outcomeScore = Number(Math.max(-1, Math.min(1, costScore * 0.55 + ctrScore * 0.25 + messageScore * 0.20)).toFixed(3));
    const key = `${postId}:${adId || 'post'}`;
    const previous = memory.outcomes.find(row => row.key === key);
    if (previous) adjustOutcomePatterns(memory, generation, -Number(previous.outcomeScore || 0));
    const outcome = {key, at: new Date().toISOString(), postId, generationId: generation.id, adId, spend, messages, ctr, messageCost, outcomeScore};
    if (previous) Object.assign(previous, outcome);
    else memory.outcomes.push(outcome);
    adjustOutcomePatterns(memory, generation, outcomeScore);
    trimLists(memory);
    await writeMemory(db);
    return {postId, outcomeScore, messageCost, ctr, messages};
  });
}

function terms(value) {
  return new Set(clean(value, 1600).toLocaleLowerCase('tr-TR')
    .normalize('NFD').replace(/[\u0300-\u036f]/g, '').replace(/[^\p{L}\p{N}]+/gu, ' ')
    .split(/\s+/).filter(word => word.length > 2));
}

function daysOld(value) {
  const stamp = Date.parse(value || '');
  return Number.isFinite(stamp) ? Math.max(0, (Date.now() - stamp) / 86400000) : 365;
}

function similarity(a,b) {
  if(!a?.size || !b?.size) return 0;
  let common=0;
  for(const word of a) if(b.has(word)) common++;
  const union=new Set([...a,...b]).size;
  return union ? common/union : 0;
}

function sameText(a,b) {
  const left=clean(a,180).toLocaleLowerCase('tr-TR');
  const right=clean(b,180).toLocaleLowerCase('tr-TR');
  return Boolean(left && right && left===right);
}

export async function buildMemoryContext(tenantId, input={}) {
  return serialized(async () => {
    const db = await readMemory();
    const memory = tenantMemory(db, tenantId);
    const query = terms([input.title, input.context, input.goal, input.tone, input.industry, input.productCategory, input.targetAudience, input.visualSummary, input.brand, input.model].join(' '));
    const creativeQuery = terms([input.title, input.context, input.visualSummary, input.hook].join(' '));
    const outcomeByGeneration = new Map();
    for (const outcome of memory.outcomes) {
      const current = outcomeByGeneration.get(outcome.generationId);
      if (!current || Date.parse(outcome.at || '') > Date.parse(current.at || '')) outcomeByGeneration.set(outcome.generationId, outcome);
    }
    const scored = memory.generations.map(generation => {
      const termsForGeneration = terms([generation.productName, generation.brand, generation.model, generation.industry, generation.productCategory, generation.contentGoal, generation.targetAudience, generation.visualSummary, generation.hook, generation.caption].join(' '));
      let overlap = 0;
      for (const word of query) if (termsForGeneration.has(word)) overlap++;
      const outcome = outcomeByGeneration.get(generation.id);
      const outcomeScore = Number(outcome?.outcomeScore || 0);
      const mediaMatches = !input.mediaType || String(input.mediaType).toUpperCase() === 'AUTO' || generation.mediaType === String(input.mediaType).toUpperCase();
      const recency = Math.exp(-daysOld(generation.at) / 90);
      const industryMatch = sameText(input.industry,generation.industry) ? 1 : 0;
      const categoryMatch = sameText(input.productCategory,generation.productCategory) ? 1 : 0;
      const creativeSimilarity = similarity(creativeQuery,terms([generation.hook,generation.caption,generation.visualSummary].join(' ')));
      const noveltyPenalty = creativeSimilarity > 0.72 ? (creativeSimilarity - 0.72) * 4 : 0;
      const score = overlap * 1.6 + industryMatch * 1.25 + categoryMatch * 1.5 + (mediaMatches ? 0.35 : 0) + outcomeScore * 1.5 + recency * 0.30 - noveltyPenalty;
      return {generation, outcome, outcomeScore, creativeSimilarity, score};
    });
    const relevant = scored.sort((a,b) => b.score - a.score || Date.parse(b.generation.at || '') - Date.parse(a.generation.at || '')).slice(0, 5);
    const bestHooks = (memory.patterns.hooks || []).filter(row=>Number(row.score)>0).sort((a,b) => Number(b.score || 0) - Number(a.score || 0)).slice(0, 3);
    const bestHookTypes = (memory.patterns.hookTypes || []).filter(row=>Number(row.score)>0).sort((a,b) => Number(b.score || 0) - Number(a.score || 0)).slice(0, 3);
    const nearCopies = scored.filter(row=>row.creativeSimilarity>0.72).sort((a,b)=>b.creativeSimilarity-a.creativeSimilarity).slice(0,3);
    const examples = relevant.map(row => ({
      ürün: row.generation.productName, sektör: row.generation.industry, kategori: row.generation.productCategory,
      hook: row.generation.hook, hookTipi: row.generation.hookType, açı: row.generation.contentAngle, ton: row.generation.selectedTone,
      format: row.generation.recommendedFormat, kitle: row.generation.targetAudience,
      yaratıcıBenzerlik: Number(row.creativeSimilarity.toFixed(2)),
      performans: row.outcome ? (row.outcomeScore >= 0.25 ? 'olumlu sinyal' : row.outcomeScore <= -0.25 ? 'zayıf sinyal' : 'nötr sinyal') : 'henüz ölçülmedi'
    }));
    return [
      'ADVISE AI HAFIZA SARAYI V2:',
      'Hafıza yalnızca aynı tenantın kendi kayıtlarından oluşur. Model ağırlıkları değişmez; gerçek üretim ve yayın performansı sonraki kararı yönlendirir.',
      'Bu medya ve istekle bağlama göre seçilmiş örnekler: ' + (examples.length ? JSON.stringify(examples) : 'Henüz geçmiş örnek yok.'),
      'Performansla güçlenen hooklar: ' + (bestHooks.length ? bestHooks.map(row => `${row.value} (skor:${Number(row.score || 0).toFixed(2)})`).join(' | ') : 'Henüz ölçülmüş kazanan yok.'),
      'Performansla güçlenen hook tipleri: ' + (bestHookTypes.length ? bestHookTypes.map(row => `${row.value} (skor:${Number(row.score || 0).toFixed(2)})`).join(' | ') : 'Henüz ölçülmüş hook tipi yok.'),
      'Novelty uyarısı: ' + (nearCopies.length ? nearCopies.map(row=>`${row.generation.hook || row.generation.productName} (benzerlik:${row.creativeSimilarity.toFixed(2)})`).join(' | ') : 'Yakın kopya riski görünmüyor.'),
      'KURAL: Olumlu sinyalli örneklerden strateji öğren; metni veya görsel fikrini kopyalama. Yaratıcı benzerliği yüksek geçmiş örnekleri yeniden yazmak yerine yeni hook, açı ve anlatım üret. Zayıf sinyalleri aynen tekrar etme. Hafızadaki iddia, fiyat veya sonucu yeni ürüne taşıma.'
    ].join('\n');
  });
}

export async function getMemorySummary(tenantId) {
  return serialized(async () => {
    const db = await readMemory();
    const memory = tenantMemory(db, tenantId);
    const linked = new Set(memory.generations.filter(row => row.postId).map(row => row.id));
    const recentGenerations = memory.generations.slice(-8).reverse().map(generation => {
      const outcome = [...memory.outcomes].reverse().find(row => row.generationId === generation.id);
      return {
        id: generation.id, postId: generation.postId, productName: generation.productName,
        hook: generation.hook, recommendedFormat: generation.recommendedFormat, mediaType: generation.mediaType,
        at: generation.at, outcomeScore: outcome?.outcomeScore ?? null
      };
    });
    const best = key => (memory.patterns[key] || []).filter(row=>Number(row.score)>0).sort((a,b) => Number(b.score || 0) - Number(a.score || 0)).slice(0, 5);
    return {
      version: 2,
      generationCount: memory.generations.length,
      linkedGenerationCount: linked.size,
      outcomeCount: memory.outcomes.length,
      learningWins: memory.outcomes.filter(row => Number(row.outcomeScore) >= 0.25).length,
      learningLessons: memory.outcomes.filter(row => Number(row.outcomeScore) <= -0.25).length,
      bestHooks: best('hooks'),
      bestHookTypes: best('hookTypes'),
      bestAngles: best('angles'),
      bestTimes: best('times'),
      bestFormats:best('formats'),
      bestAudiences:best('audiences'),
      hasMeasuredInsights:memory.outcomes.length>0,
      recentGenerations
    };
  });
}
