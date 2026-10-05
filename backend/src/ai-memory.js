import fs from 'node:fs/promises';
import path from 'node:path';
import {fileURLToPath} from 'node:url';

const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../data');
const memoryFile = path.join(root, 'ai_memory.json');
const DEFAULT = {version: 1, tenants: {}};

async function readMemory() {
  await fs.mkdir(root, {recursive: true});
  try { return JSON.parse(await fs.readFile(memoryFile, 'utf8')); }
  catch { await fs.writeFile(memoryFile, JSON.stringify(DEFAULT, null, 2)); return JSON.parse(JSON.stringify(DEFAULT)); }
}
async function writeMemory(data) {
  await fs.mkdir(root, {recursive: true});
  await fs.writeFile(memoryFile, JSON.stringify(data, null, 2));
}
function clean(value, max=500) { return String(value ?? '').trim().slice(0, max); }
function tenantMemory(db, tenantId) {
  const id = clean(tenantId, 120) || 'system';
  if (!db.tenants[id]) db.tenants[id] = {generations: [], patterns: {hooks: [], angles: [], tones: [], formats: [], times: [], audiences: []}, outcomes: []};
  return db.tenants[id];
}
function upsertPattern(list, key, value, delta=0) {
  const text = clean(value, 300);
  if (!text) return;
  const row = list.find(x => x.key === key);
  if (row) { row.uses = Number(row.uses || 0) + 1; row.score = Number(row.score || 0) + delta; row.lastUsedAt = new Date().toISOString(); }
  else list.push({key, value: text, uses: 1, score: delta, lastUsedAt: new Date().toISOString()});
}
function trimLists(memory) {
  memory.generations = memory.generations.slice(-300);
  memory.outcomes = memory.outcomes.slice(-300);
  for (const key of Object.keys(memory.patterns || {})) {
    memory.patterns[key] = (memory.patterns[key] || []).sort((a,b) => Number(b.score || 0) - Number(a.score || 0) || Number(b.uses || 0) - Number(a.uses || 0)).slice(0, 100);
  }
}
export async function learnFromGeneration(tenantId, pack, input={}) {
  const db = await readMemory();
  const memory = tenantMemory(db, tenantId);
  const generation = {
    id: 'mem_' + Date.now(), at: new Date().toISOString(), postId: clean(input.postId, 120),
    productName: clean(pack.productName, 180), brand: clean(pack.brand, 100), model: clean(pack.model, 120),
    hook: clean(pack.hook, 300), caption: clean(pack.caption, 2200), cta: clean(pack.cta, 300),
    hashtags: Array.isArray(pack.hashtags) ? pack.hashtags.slice(0, 12).map(x => clean(x, 60)) : [],
    selectedTone: clean(pack.selectedTone, 120), contentAngle: clean(pack.contentAngle, 300),
    recommendedFormat: clean(pack.recommendedFormat, 40), recommendedPostTime: clean(pack.recommendedPostTime, 40),
    contentGoal: clean(pack.contentGoal, 120), targetAudience: clean(pack.targetAudience, 500), visualSummary: clean(pack.visualSummary, 700),
    creativeScore: Number(pack.creativeScore || 0), source: clean(pack.source, 80), modelUsed: clean(pack.model, 100)
  };
  memory.generations.push(generation);
  upsertPattern(memory.patterns.hooks, generation.hook, generation.hook);
  upsertPattern(memory.patterns.angles, generation.contentAngle, generation.contentAngle);
  upsertPattern(memory.patterns.tones, generation.selectedTone, generation.selectedTone);
  upsertPattern(memory.patterns.formats, generation.recommendedFormat, generation.recommendedFormat);
  upsertPattern(memory.patterns.times, generation.recommendedPostTime, generation.recommendedPostTime);
  upsertPattern(memory.patterns.audiences, generation.targetAudience, generation.targetAudience);
  trimLists(memory);
  await writeMemory(db);
  return generation;
}
export async function learnFromOutcome(tenantId, input={}) {
  const db = await readMemory();
  const memory = tenantMemory(db, tenantId);
  const postId = clean(input.postId, 120);
  if (!postId) return null;
  const generation = [...memory.generations].reverse().find(x => x.postId === postId);
  if (!generation) return null;
  const messageCost = input.messageCost == null ? null : Number(input.messageCost);
  const ctr = Number(input.ctr || 0);
  const messages = Number(input.messages || 0);
  const spend = Number(input.spend || 0);
  const costScore = messageCost == null ? 0 : Math.max(-1, Math.min(3, 2 - messageCost));
  const ctrScore = Math.max(-1, Math.min(1, ctr / 3));
  const messageScore = Math.max(-1, Math.min(1, messages / 20));
  const outcomeScore = Number((costScore * 0.55 + ctrScore * 0.25 + messageScore * 0.20).toFixed(3));
  memory.outcomes.push({at: new Date().toISOString(), postId, adId: clean(input.adId, 120), spend, messages, ctr, messageCost, outcomeScore});
  for (const key of ['hooks','angles','tones','formats','times','audiences']) {
    const valueMap = {hooks:generation.hook, angles:generation.contentAngle, tones:generation.selectedTone, formats:generation.recommendedFormat, times:generation.recommendedPostTime, audiences:generation.targetAudience};
    upsertPattern(memory.patterns[key], valueMap[key], valueMap[key], outcomeScore);
  }
  trimLists(memory);
  await writeMemory(db);
  return {postId, outcomeScore, messageCost, ctr, messages};
}
export async function buildMemoryContext(tenantId) {
  const db = await readMemory();
  const memory = tenantMemory(db, tenantId);
  const top = key => (memory.patterns[key] || []).slice(0, 5).map(x => x.value + ' (kullanım:' + x.uses + ', skor:' + Number(x.score || 0).toFixed(2) + ')');
  const recent = memory.generations.slice(-5).reverse().map(x => ({ürün:x.productName, marka:x.brand, hook:x.hook, açı:x.contentAngle, ton:x.selectedTone, format:x.recommendedFormat, saat:x.recommendedPostTime}));
  return [
    'ADVISE AI HAFIZA SARAYI:',
    'Bu hafıza model ağırlıklarını değiştirmez; geçmiş üretim ve performans sinyallerini sonraki Gemini kararlarına bağlayan kalıcı ürün hafızasıdır.',
    'GÜÇLÜ HOOKLAR: ' + (top('hooks').join(' | ') || 'Henüz veri yok.'),
    'GÜÇLÜ İÇERİK AÇILARI: ' + (top('angles').join(' | ') || 'Henüz veri yok.'),
    'GÜÇLÜ TONLAR: ' + (top('tones').join(' | ') || 'Henüz veri yok.'),
    'GÜÇLÜ FORMATLAR: ' + (top('formats').join(' | ') || 'Henüz veri yok.'),
    'GÜÇLÜ SAATLER: ' + (top('times').join(' | ') || 'Henüz veri yok.'),
    'GÜÇLÜ HEDEF KİTLELER: ' + (top('audiences').join(' | ') || 'Henüz veri yok.'),
    'SON ÜRETİMLER: ' + JSON.stringify(recent),
    'KURAL: Hafızayı kopyalama; yeni medyanın bağlamına göre en uygun öğrenilmiş yaklaşımı seç.'
  ].join('\n');
}
export async function getMemorySummary(tenantId) {
  const db = await readMemory();
  const memory = tenantMemory(db, tenantId);
  return {generationCount: memory.generations.length, outcomeCount: memory.outcomes.length, topHooks: memory.patterns.hooks.slice(0, 10), topAngles: memory.patterns.angles.slice(0, 10), topTimes: memory.patterns.times.slice(0, 10)};
}
