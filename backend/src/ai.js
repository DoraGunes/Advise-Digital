import {config} from './config.js';
import {GoogleGenAI} from '@google/genai';
import fs from 'node:fs/promises';
import {buildMemoryContext} from './ai-memory.js';

const MODEL = process.env.GEMINI_MODEL || config.aiModel || 'gemini-3.8-flash';
const FALLBACK_MODEL = process.env.GEMINI_FALLBACK_MODEL || 'gemini-3.7-flash';
const MAX_INLINE_MEDIA_BYTES = 20 * 1024 * 1024;

const OUTPUT_SCHEMA = {
  type: 'object',
  properties: {
    productName: {type: 'string'},
    brand: {type: 'string'},
    model: {type: 'string'},
    detectedText: {type: 'string'},
    detectedOffer: {type: 'string'},
    selectedTone: {type: 'string'},
    contentAngle: {type: 'string'},
    hook: {type: 'string'},
    caption: {type: 'string'},
    cta: {type: 'string'},
    hashtags: {type: 'array', items: {type: 'string'}},
    recommendedFormat: {type: 'string', enum: ['POST', 'REELS', 'CAROUSEL']},
    recommendedPostTime: {type: 'string'},
    recommendedPostTimeReason: {type: 'string'},
    contentGoal: {type: 'string'},
    targetAudience: {type: 'string'},
    visualSummary: {type: 'string'},
    creativeScore: {type: 'integer', minimum: 0, maximum: 100},
    adRecommendation: {type: 'string'},
    nextAction: {type: 'string'},
    confidence: {type: 'integer', minimum: 0, maximum: 100}
  },
  required: [
    'productName', 'brand', 'model', 'detectedText', 'detectedOffer',
    'selectedTone', 'contentAngle', 'hook', 'caption', 'cta', 'hashtags',
    'recommendedFormat', 'recommendedPostTime', 'recommendedPostTimeReason',
    'contentGoal', 'targetAudience', 'visualSummary', 'creativeScore',
    'adRecommendation', 'nextAction', 'confidence'
  ]
};

const VARIANTS_SCHEMA = {
  type: 'object',
  properties: {
    variants: {
      type: 'array',
      minItems: 3,
      maxItems: 3,
      items: {
        type: 'object',
        properties: {
          id: {type: 'string'},
          caption: {type: 'string'},
          hook: {type: 'string'},
          cta: {type: 'string'},
          style: {type: 'string'}
        },
        required: ['id', 'caption', 'hook', 'cta', 'style']
      }
    }
  },
  required: ['variants']
};

function clean(value, max=1600) {
  return String(value ?? '').trim().slice(0, max);
}

function safeHashtags(value) {
  return (Array.isArray(value) ? value : [])
    .map(function(x) { return clean(x, 60); })
    .filter(Boolean)
    .map(function(x) { return x.startsWith('#') ? x : '#' + x.replace(/^#+/, ''); })
    .slice(0, 12);
}

function localPack(input={}) {
  var title = clean(input.title, 180) || 'Ürün';
  var context = clean(input.context, 900);
  var mediaType = String(input.mediaType || 'AUTO').toUpperCase();
  var format = ['REELS', 'VIDEO'].includes(mediaType) ? 'REELS' : 'POST';
  return {
    source: 'LOCAL_FALLBACK',
    model: null,
    productName: title,
    brand: '',
    model: '',
    detectedText: '',
    detectedOffer: '',
    selectedTone: 'samimi ve güven veren',
    contentAngle: 'Görseldeki gerçek ve doğrulanabilir avantajı öne çıkar.',
    hook: title + ': detayları yakala.',
    caption: title + ' için net ve doğal bir içerik.' + (context ? ' ' + context : '') + ' Detaylı bilgi için mesaj gönderebilirsin.',
    cta: 'Detaylı bilgi için mesaj gönder.',
    hashtags: ['#AdViseAI', '#instagram', '#sosyalmedya', '#reklam'],
    recommendedFormat: format,
    recommendedPostTime: '19:00',
    recommendedPostTimeReason: 'AI yanıtı alınamadığı için genel bir öneri kullanıldı.',
    contentGoal: 'mesaj',
    targetAudience: 'Ürünle ilgilenebilecek potansiyel müşteriler.',
    visualSummary: 'AI analiz edilemedi.',
    creativeScore: 0,
    adRecommendation: 'AI analizi olmadan reklam performansı hakkında kesin sonuç çıkarma.',
    nextAction: 'İçeriği kontrol edip yeniden AI analizi çalıştır.',
    confidence: 0
  };
}

function normalizePack(raw, input={}, model=MODEL) {
  var fallback = localPack(input);
  var pack = raw && typeof raw === 'object' ? raw : {};
  var format = String(pack.recommendedFormat || '').toUpperCase();
  return {
    source: 'GEMINI',
    model: model,
    productName: clean(pack.productName, 180) || fallback.productName,
    brand: clean(pack.brand, 100),
    model: clean(pack.model, 120),
    detectedText: clean(pack.detectedText, 900),
    detectedOffer: clean(pack.detectedOffer, 300),
    selectedTone: clean(pack.selectedTone, 120) || fallback.selectedTone,
    contentAngle: clean(pack.contentAngle, 300) || fallback.contentAngle,
    hook: clean(pack.hook, 300) || fallback.hook,
    caption: clean(pack.caption, 2200) || fallback.caption,
    cta: clean(pack.cta, 300) || fallback.cta,
    hashtags: safeHashtags(pack.hashtags).length ? safeHashtags(pack.hashtags) : fallback.hashtags,
    recommendedFormat: ['POST', 'REELS', 'CAROUSEL'].includes(format) ? format : fallback.recommendedFormat,
    recommendedPostTime: clean(pack.recommendedPostTime, 100) || fallback.recommendedPostTime,
    recommendedPostTimeReason: clean(pack.recommendedPostTimeReason, 500) || fallback.recommendedPostTimeReason,
    contentGoal: clean(pack.contentGoal, 120) || fallback.contentGoal,
    targetAudience: clean(pack.targetAudience, 500) || fallback.targetAudience,
    visualSummary: clean(pack.visualSummary, 700) || fallback.visualSummary,
    creativeScore: Math.max(0, Math.min(100, Number(pack.creativeScore) || 0)),
    adRecommendation: clean(pack.adRecommendation, 700) || fallback.adRecommendation,
    nextAction: clean(pack.nextAction, 500) || fallback.nextAction,
    confidence: Math.max(0, Math.min(100, Number(pack.confidence) || 0))
  };
}

function buildHistoryText(history) {
  if (!Array.isArray(history) || !history.length) return 'Geçmiş performans verisi yok.';
  return history.slice(-20).map(function(item, i) {
    var row = item && typeof item === 'object' ? item : {};
    return [
      'Kayıt ' + (i + 1) + ':',
      'tür=' + clean(row.type, 80),
      'tarih=' + clean(row.createdAt || row.at || '', 60),
      'veri=' + clean(JSON.stringify(row), 900)
    ].join(' ');
  }).join('\n');
}

function getGeminiClient() {
  var apiKey = String(process.env.GEMINI_API_KEY || '').trim();
  if (!apiKey) throw new Error('GEMINI_API_KEY tanımlı değil.');
  return new GoogleGenAI({apiKey: apiKey});
}

function dataUrlToInputPart(dataUrl) {
  var match = String(dataUrl || '').match(/^data:(image\/[a-z0-9.+-]+);base64,(.+)$/is);
  if (!match) return null;
  return {type: 'image', mime_type: match[1].toLowerCase(), data: match[2]};
}

async function uploadGeminiFile(client, filePath, mimeType) {
  var uploaded = await client.files.upload({file: filePath, config: {mimeType: mimeType}});
  var current = uploaded;
  for (var attempt = 0; attempt < 60; attempt++) {
    var state = String(current && current.state || '').toUpperCase();
    if (!state || state === 'ACTIVE') return current;
    if (state === 'FAILED') throw new Error('Gemini dosya işleme başarısız oldu.');
    await new Promise(function(resolve) { setTimeout(resolve, 2000); });
    current = await client.files.get({name: current.name});
  }
  throw new Error('Gemini dosya işleme zaman aşımına uğradı.');
}

async function fileToGeminiInputPart(client, filePath, mimeType, mediaType) {
  if (!filePath) return null;
  var stat = await fs.stat(filePath);
  var isVideo = String(mimeType || '').toLowerCase().startsWith('video/') || String(mediaType || '').toUpperCase() === 'REELS';
  var kind = isVideo ? 'video' : 'image';
  var normalizedMime = String(mimeType || (isVideo ? 'video/mp4' : 'image/jpeg')).toLowerCase();
  if (stat.size <= MAX_INLINE_MEDIA_BYTES) {
    return {
      type: kind,
      data: await fs.readFile(filePath, {encoding: 'base64'}),
      mime_type: normalizedMime
    };
  }
  var uploaded = await uploadGeminiFile(client, filePath, normalizedMime);
  return {
    type: kind,
    uri: uploaded.uri,
    mime_type: uploaded.mimeType || normalizedMime,
    ...(isVideo ? {processing: 'static'} : {})
  };
}

async function imageUrlToInputPart(imageUrl) {
  if (!/^https:\/\//i.test(String(imageUrl || ''))) return null;
  var response = await fetch(imageUrl, {headers: {'accept': 'image/*'}, signal: AbortSignal.timeout(15000)});
  if (!response.ok) throw new Error('Görsel URL alınamadı: HTTP ' + response.status);
  var contentType = String(response.headers.get('content-type') || '').split(';')[0].trim().toLowerCase();
  if (!contentType.startsWith('image/')) throw new Error('Görsel URL image MIME type döndürmedi.');
  var buffer = Buffer.from(await response.arrayBuffer());
  return {type: 'image', data: buffer.toString('base64'), mime_type: contentType};
}

function retryableError(error) {
  var message = String(error && error.message || error || '').toLowerCase();
  var status = Number(error && (error.status || error.code || 0));
  return status === 408 || status === 429 || status === 500 || status === 502 || status === 503 || status === 504 || /high demand|temporar|unavailable|overloaded|rate limit|quota|503|429/.test(message);
}

async function callGemini(options) {
  var client = getGeminiClient();
  var models = Array.from(new Set([MODEL, FALLBACK_MODEL].filter(Boolean)));
  var lastError = null;
  for (var modelIndex = 0; modelIndex < models.length; modelIndex++) {
    var model = models[modelIndex];
    for (var attempt = 1; attempt <= 3; attempt++) {
      try {
        console.log('[AI GEMINI INTERACTIONS REQUEST]', {
          model: model,
          attempt: attempt,
          hasMedia: (options.mediaParts || []).length > 0
        });

        var requestPromise = client.interactions.create({
          model: model,
          input: (options.mediaParts || []).filter(Boolean).concat([{type: 'text', text: options.prompt}]),
          system_instruction: options.systemInstruction || undefined,
          response_format: {
            type: 'text',
            mime_type: 'application/json',
            schema: options.schema || OUTPUT_SCHEMA
          },
          generation_config: {max_output_tokens: options.maxOutputTokens || 1500},
          store: false
        });

        var interaction = await Promise.race([
          requestPromise,
          new Promise(function(_, reject) {
            setTimeout(function() {
              reject(new Error('Gemini isteği 60 saniyede cevap vermedi.'));
            }, 60000);
          })
        ]);
        var outputText = String(interaction && interaction.output_text || '').trim();
        console.log('[AI GEMINI INTERACTIONS RESPONSE]', {model: model, attempt: attempt, status: interaction && interaction.status || '-', hasOutput: Boolean(outputText)});
        if (!outputText) throw new Error('Gemini boş cevap döndürdü. status=' + String(interaction && interaction.status || '-'));
        return {parsed: JSON.parse(outputText), model: model};
      } catch (error) {
        lastError = error;
        console.error('[AI GEMINI INTERACTIONS ERROR]', {model: model, attempt: attempt, error: String(error && error.message || error)});
        if (!retryableError(error) || attempt === 3) break;
        var waitMs = 1000 * Math.pow(2, attempt - 1);
        await new Promise(function(resolve) { setTimeout(resolve, waitMs); });
      }
    }
    if (models[modelIndex + 1]) {
      console.warn('[AI GEMINI MODEL FALLBACK]', {from: model, to: models[modelIndex + 1], reason: String(lastError && lastError.message || '')});
    }
  }
  throw lastError || new Error('Gemini çağrısı başarısız.');
}

export async function generateContentPack(input={}) {
  var safe = {
    title: clean(input.title, 180),
    context: clean(input.context, 1200),
    tone: clean(input.tone, 100) || 'AI seçsin',
    goal: clean(input.goal, 100) || 'AI seçsin',
    language: clean(input.language, 30) || 'Türkçe',
    mediaType: String(input.mediaType || 'AUTO').toUpperCase(),
    imageUrl: clean(input.imageUrl, 1800),
    imageDataUrl: typeof input.imageDataUrl === 'string' && input.imageDataUrl.startsWith('data:image/') ? input.imageDataUrl.slice(0, 16000000) : '',
    filePath: clean(input.filePath, 1200),
    mimeType: clean(input.mimeType, 120),
    mediaNote: clean(input.mediaNote, 500),
    timezone: clean(input.timezone, 80) || config.timezone || 'Europe/Istanbul',
    history: Array.isArray(input.history) ? input.history : [],
    tenantId: clean(input.tenantId, 120)
  };
  if (!String(process.env.GEMINI_API_KEY || '').trim()) return localPack(safe);

  var memoryContext = safe.tenantId ? await buildMemoryContext(safe.tenantId) : 'ADVISE AI HAFIZA SARAYI: tenant hafızası bağlı değil.';

  var prompt = [
    'AdVise AI için sosyal medya içerik paketi oluştur.',
    'Önce medya içeriğini analiz et, sonra içerik stratejisini seç, en son metni yaz.',
    'Görsel/video üzerinde görülen gerçek bilgileri temel al.',
    'Görselde veya kullanıcı notunda olmayan fiyat, kampanya, garanti, stok, teknik özellik veya sonuç uydurma.',
    'Marka/model/yazılar görünüyorsa mümkün olduğunca doğru çıkar.',
    'Ton, format, amaç ve içerik açısını AI kendi seçsin.',
    'Hook kısa ve güçlü; caption doğal Türkçe; CTA tek ve net; hashtag 4-8 adet olsun.',
    'recommendedPostTime Türkiye saatiyle HH:MM olsun.',
    'Geçmiş performans verisi yoksa bunu açıkça belirt; başarı garantisi verme.',
    'Kullanıcı notu: ' + (safe.context || '-'),
    'Ürün başlığı/dosya adı: ' + (safe.title || '-'),
    'Medya tipi: ' + safe.mediaType,
    'Ton tercihi: ' + safe.tone,
    'Amaç tercihi: ' + safe.goal,
    'Zaman dilimi: ' + safe.timezone,
    'Medya notu: ' + (safe.mediaNote || '-'),
    'Geçmiş sinyaller:',
    buildHistoryText(safe.history),
    memoryContext
  ].join('\n');

  try {
    var client = getGeminiClient();
    var mediaParts = [];
    var dataPart = dataUrlToInputPart(safe.imageDataUrl);
    if (dataPart) mediaParts.push(dataPart);
    else if (safe.filePath && safe.mimeType) mediaParts.push(await fileToGeminiInputPart(client, safe.filePath, safe.mimeType, safe.mediaType));
    else if (safe.imageUrl) mediaParts.push(await imageUrlToInputPart(safe.imageUrl));

    var result = await callGemini({
      prompt: prompt,
      systemInstruction: [
        'Sen AdVise AI isimli profesyonel yaratıcı direktörsün.',
        'Fotoğraf ve videoyu gerçek bir kreatif yönetmen gibi incele.',
        'Klişe ve robotik reklam dili kullanma.',
        'Kanıtlanamayan bilgileri kesin gerçek gibi yazma.',
        'Çıktı tamamen Türkçe ve uygulanabilir olsun.'
      ].join('\n'),
      mediaParts: mediaParts,
      schema: OUTPUT_SCHEMA,
      maxOutputTokens: 1500
    });
    return normalizePack(result.parsed, safe, result.model);
  } catch (error) {
    console.error('[AI GEMINI ERROR]', error && error.message || error);
    return {...localPack(safe), source: 'LOCAL_FALLBACK_AFTER_AI_ERROR', error: clean(error && error.message || 'Gemini çağrısı başarısız.', 800)};
  }
}

export async function generateCaption(input={}) {
  return generateContentPack(input);
}

export async function generateCaptionVariants(input={}) {
  var safe = {title: clean(input.title, 180) || 'Ürün', context: clean(input.context, 900), tone: clean(input.tone, 80) || 'samimi ve güven veren', goal: clean(input.goal, 80) || 'mesaj'};
  if (!String(process.env.GEMINI_API_KEY || '').trim()) {
    var base = localPack(safe);
    return {source: 'LOCAL_FALLBACK', model: null, variants: [
      {id: 'A', caption: base.caption, hook: base.hook, cta: base.cta, style: 'Doğrudan'},
      {id: 'B', caption: safe.title + ': Detayları keşfet. ' + base.cta, hook: safe.title + ' hakkında bunu biliyor musun?', cta: base.cta, style: 'Merak uyandıran'},
      {id: 'C', caption: safe.title + ': Kısa, net ve fayda odaklı. ' + base.cta, hook: 'Kısa, net ve fayda odaklı.', cta: base.cta, style: 'Minimal'}
    ]};
  }
  try {
    var result = await callGemini({
      prompt: ['Aynı Instagram içeriğinin 3 farklı caption varyasyonunu üret.', 'Türkçe yaz.', 'Uydurma özellik veya fiyat ekleme.', 'Ürün: ' + safe.title, 'Bilgi: ' + (safe.context || '-'), 'Ton: ' + safe.tone, 'Amaç: ' + safe.goal].join('\n'),
      systemInstruction: 'AdVise AI için kısa, doğal ve farklılaştırılmış Instagram metinleri üret.',
      mediaParts: [],
      schema: VARIANTS_SCHEMA,
      maxOutputTokens: 1000
    });
    return {source: 'GEMINI', model: result.model, variants: Array.isArray(result.parsed.variants) ? result.parsed.variants.slice(0, 3) : []};
  } catch (error) {
    var fallback = localPack(safe);
    return {source: 'LOCAL_FALLBACK_AFTER_AI_ERROR', model: null, error: clean(error && error.message || 'Gemini varyasyon çağrısı başarısız.', 500), variants: [
      {id: 'A', caption: fallback.caption, hook: fallback.hook, cta: fallback.cta, style: 'Doğrudan'},
      {id: 'B', caption: safe.title + ': Detayları keşfet. ' + fallback.cta, hook: safe.title + ' için farklı bir açı.', cta: fallback.cta, style: 'Merak uyandıran'},
      {id: 'C', caption: safe.title + ': Kısa, net ve fayda odaklı. ' + fallback.cta, hook: 'Kısa, net ve fayda odaklı.', cta: fallback.cta, style: 'Minimal'}
    ]};
  }
}

export async function scoreCreative(input={}) {
  var caption = clean(input.caption, 2200);
  var hook = clean(input.hook, 300);
  var cta = clean(input.cta, 300);
  var hashtags = Array.isArray(input.hashtags) ? input.hashtags.length : 0;
  var mediaType = String(input.mediaType || 'POST').toUpperCase();
  var scores = {
    hook: Math.min(100, 30 + (hook.length ? Math.min(45, hook.length) : 0)),
    caption: Math.min(100, 35 + (caption.length ? Math.min(50, Math.round(caption.length / 20)) : 0)),
    cta: cta.length ? 82 : 30,
    format: ['POST', 'REELS', 'CAROUSEL'].includes(mediaType) ? 85 : 55,
    hashtags: Math.min(100, hashtags * 14)
  };
  scores.overall = Math.round(Object.values(scores).reduce(function(a, b) { return a + b; }, 0) / Object.keys(scores).length);
  scores.signal = scores.overall >= 80 ? 'Güçlü hazırlık sinyali' : scores.overall >= 60 ? 'Orta hazırlık sinyali' : 'İyileştirme gerekli';
  return {source: 'HEURISTIC', scores: scores, generatedAt: new Date().toISOString()};
}

export function aiStatus() {
  var configured = Boolean(String(process.env.GEMINI_API_KEY || '').trim());
  return {configured: configured, model: MODEL, provider: configured ? 'GEMINI_INTERACTIONS' : 'LOCAL_FALLBACK'};
}
