import {config} from './config.js';
import {GoogleGenAI} from '@google/genai';
import fs from 'node:fs/promises';
import {buildMemoryContext} from './ai-memory.js';

const MODEL = process.env.GEMINI_MODEL || config.aiModel || 'gemini-3.8-flash';
const FALLBACK_MODEL = process.env.GEMINI_FALLBACK_MODEL || 'gemini-3.7-flash';
const RESCUE_MODEL = process.env.GEMINI_RESCUE_MODEL || 'gemini-3.5-flash-lite';
const MAX_INLINE_MEDIA_BYTES = 20 * 1024 * 1024;

const OUTPUT_SCHEMA = {
  type: 'object',
  properties: {
    productName: {type: 'string'},
    brand: {type: 'string'},
    model: {type: 'string'},
    industry: {type: 'string'},
    productCategory: {type: 'string'},
    detectedText: {type: 'string'},
    detectedOffer: {type: 'string'},
    selectedTone: {type: 'string'},
    contentAngle: {type: 'string'},
    hook: {type: 'string'},
    hookType: {type: 'string'},
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
    'selectedTone', 'contentAngle', 'hook', 'hookType', 'caption', 'cta', 'hashtags',
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

const AD_DECISIONS_SCHEMA = {
  type: 'object',
  properties: {
    decisions: {
      type: 'array',
      maxItems: 50,
      items: {
        type: 'object',
        properties: {
          adSetId: {type: 'string'},
          action: {type: 'string', enum: ['KEEP', 'PAUSE', 'ACTIVATE', 'INCREASE_BUDGET', 'DECREASE_BUDGET', 'APPLY_SAVED_AUDIENCE']},
          reason: {type: 'string'},
          confidence: {type: 'integer', minimum: 0, maximum: 100}
        },
        required: ['adSetId', 'action', 'reason', 'confidence']
      }
    },
    summary: {type: 'string'}
  },
  required: ['decisions', 'summary']
};

function clean(value, max=1600) {
  return String(value ?? '').trim().slice(0, max);
}

function isWhatsAppGoal(value) {
  return /whatsapp|whats\s*app|\bwp\b/i.test(String(value || ''));
}

function whatsappCta(value) {
  var text = clean(value, 300);
  if (!text || !/whatsapp|whats\s*app|\bwp\b/i.test(text) || /\bdm\b|\binstagram\b|direct/i.test(text)) {
    return 'WhatsApp üzerinden bize yazın.';
  }
  return text;
}

function adTargetingPrompt(value) {
  return clean(value, 600);
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
  var whatsappGoal = isWhatsAppGoal(input.goal);
  var mediaType = String(input.mediaType || 'AUTO').toUpperCase();
  var format = ['REELS', 'VIDEO'].includes(mediaType) ? 'REELS' : 'POST';
  return {
    source: 'LOCAL_FALLBACK',
    providerModel: null,
    modelUsed: null,
    productName: title,
    brand: '',
    model: '',
    detectedText: '',
    detectedOffer: '',
    selectedTone: 'samimi ve güven veren',
    contentAngle: 'Görseldeki gerçek ve doğrulanabilir avantajı öne çıkar.',
    hook: title + ': detayları yakala.',
    hookType: 'DOĞRUDAN',
    caption: title + ' için net ve doğal bir içerik.' + (context ? ' ' + context : '') + (whatsappGoal ? ' Detaylı bilgi için WhatsApp üzerinden bize ulaşabilirsin.' : ' Detaylı bilgi için mesaj gönderebilirsin.'),
    cta: whatsappGoal ? 'WhatsApp üzerinden bize yazın.' : 'Detaylı bilgi için mesaj gönder.',
    contactChannel: whatsappGoal ? 'WHATSAPP' : '',
    hashtags: ['#AdViseAI', '#instagram', '#sosyalmedya', '#reklam'],
    recommendedFormat: format,
    recommendedPostTime: '19:00',
    recommendedPostTimeReason: 'AI yanıtı alınamadığı için genel bir öneri kullanıldı.',
    contentGoal: whatsappGoal ? 'WhatsApp mesajı' : 'mesaj',
    targetAudience: 'Ürünle ilgilenebilecek potansiyel müşteriler.',
    visualSummary: 'AI analiz edilemedi.',
    creativeScore: 0,
    adRecommendation: whatsappGoal ? 'Reklamdan gelen kişileri WhatsApp iletişimine yönlendir; performans ölçümü olmadan sonuç varsayma.' : 'AI analizi olmadan reklam performansı hakkında kesin sonuç çıkarma.',
    nextAction: whatsappGoal ? 'WhatsApp iletişim bağlantının profilde güncel olduğunu kontrol et.' : 'İçeriği kontrol edip yeniden AI analizi çalıştır.',
    confidence: 0
  };
}

function normalizePack(raw, input={}, model=MODEL) {
  var fallback = localPack(input);
  var pack = raw && typeof raw === 'object' ? raw : {};
  var format = String(pack.recommendedFormat || '').toUpperCase();
  var whatsappGoal = isWhatsAppGoal(input.goal);
  return {
    source: 'GEMINI',
    providerModel: model,
    modelUsed: model,
    productName: clean(pack.productName, 180) || fallback.productName,
    brand: clean(pack.brand, 100),
    model: clean(pack.model, 120),
    industry: clean(pack.industry, 100),
    productCategory: clean(pack.productCategory, 100),
    contactChannel: whatsappGoal ? 'WHATSAPP' : clean(pack.contactChannel, 40),
    mediaType: String(input.mediaType || 'AUTO').toUpperCase(),
    detectedText: clean(pack.detectedText, 900),
    detectedOffer: clean(pack.detectedOffer, 300),
    selectedTone: clean(pack.selectedTone, 120) || fallback.selectedTone,
    contentAngle: clean(pack.contentAngle, 300) || fallback.contentAngle,
    hook: clean(pack.hook, 300) || fallback.hook,
    hookType: clean(pack.hookType, 120) || fallback.hookType,
    caption: clean(pack.caption, 2200) || fallback.caption,
    cta: whatsappGoal ? whatsappCta(pack.cta) : clean(pack.cta, 300) || fallback.cta,
    hashtags: safeHashtags(pack.hashtags).length ? safeHashtags(pack.hashtags) : fallback.hashtags,
    recommendedFormat: ['POST', 'REELS', 'CAROUSEL'].includes(format) ? format : fallback.recommendedFormat,
    recommendedPostTime: clean(pack.recommendedPostTime, 100) || fallback.recommendedPostTime,
    recommendedPostTimeReason: clean(pack.recommendedPostTimeReason, 500) || fallback.recommendedPostTimeReason,
    contentGoal: whatsappGoal ? 'WhatsApp mesajı' : clean(pack.contentGoal, 120) || fallback.contentGoal,
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
  if (/daily quota|per day|retry in \d+h|quota exceeded/.test(message)) return false;
  if (String(error && error.code || '') === 'INVALID_JSON_OUTPUT') return true;
  var status = Number(error && (error.status || error.code || 0));
  return status === 408 || status === 429 || status === 500 || status === 502 || status === 503 || status === 504 || /incomplete|high demand|temporar|unavailable|overloaded|rate limit|quota|503|429/.test(message);
}

async function callGemini(options) {
  var client = getGeminiClient();
  var models = Array.from(new Set([MODEL, FALLBACK_MODEL, RESCUE_MODEL].filter(Boolean)));
  var configuredTimeout = Number(process.env.GEMINI_REQUEST_TIMEOUT_MS || 60000);
  var timeoutMs = Number.isFinite(configuredTimeout) ? Math.max(15000, Math.min(90000, configuredTimeout)) : 60000;
  var lastError = null;
  for (var modelIndex = 0; modelIndex < models.length; modelIndex++) {
    var model = models[modelIndex];
    var maxAttempts = 3;
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        console.log('[AI GEMINI INTERACTIONS REQUEST]', {
          model: model,
          attempt: attempt,
          hasMedia: (options.mediaParts || []).length > 0
        });

        var interaction = await client.interactions.create({
          model: model,
          input: (options.mediaParts || []).filter(Boolean).concat([{type: 'text', text: options.prompt}]),
          system_instruction: options.systemInstruction || undefined,
          response_format: {
            type: 'text',
            mime_type: 'application/json',
            schema: options.schema || OUTPUT_SCHEMA
          },
          generation_config: {max_output_tokens: options.maxOutputTokens || 8192, thinking_level: 'low'},
          store: false
        }, {timeout: timeoutMs, maxRetries: 0});
        var status = String(interaction && interaction.status || '').toLowerCase();
        var outputText = String(interaction && interaction.output_text || '').trim();
        console.log('[AI GEMINI INTERACTIONS RESPONSE]', {model: model, attempt: attempt, status: status || '-', hasOutput: Boolean(outputText)});
        if (status !== 'completed') {
          var stateError = new Error('Gemini yanıtı tamamlanmadı. status=' + (status || 'bilinmiyor'));
          stateError.code = status === 'incomplete' ? 'INCOMPLETE' : 'INTERACTION_NOT_COMPLETED';
          throw stateError;
        }
        if (!outputText) throw new Error('Gemini boş cevap döndürdü. status=' + String(interaction && interaction.status || '-'));
        try {
          return {parsed: JSON.parse(outputText), model: model};
        } catch (parseError) {
          parseError.code = 'INVALID_JSON_OUTPUT';
          throw parseError;
        }
      } catch (error) {
        lastError = error;
        console.error('[AI GEMINI INTERACTIONS ERROR]', {model: model, attempt: attempt, error: String(error && error.message || error)});
        if (!retryableError(error) || attempt === maxAttempts) break;
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
    goal: isWhatsAppGoal(input.goal) ? clean(input.goal, 100) : 'WhatsApp mesajı',
    adTargeting: adTargetingPrompt(input.adTargeting),
    language: clean(input.language, 30) || 'Türkçe',
    mediaType: String(input.mediaType || 'AUTO').toUpperCase(),
    imageUrl: clean(input.imageUrl, 1800),
    imageDataUrl: typeof input.imageDataUrl === 'string' && input.imageDataUrl.startsWith('data:image/') ? input.imageDataUrl.slice(0, 16000000) : '',
    filePath: clean(input.filePath, 1200),
    mimeType: clean(input.mimeType, 120),
    mediaNote: clean(input.mediaNote, 500),
    timezone: clean(input.timezone, 80) || config.timezone || 'Europe/Istanbul',
    history: Array.isArray(input.history) ? input.history : [],
    industry: clean(input.industry, 100),
    productCategory: clean(input.productCategory, 100),
    targetAudience: clean(input.targetAudience, 500),
    visualSummary: clean(input.visualSummary, 700),
    brand: clean(input.brand, 100),
    model: clean(input.model, 120),
    hook: clean(input.hook, 300),
    tenantId: clean(input.tenantId, 120)
  };
  if (!String(process.env.GEMINI_API_KEY || '').trim()) return localPack(safe);

  var memoryContext = safe.tenantId ? await buildMemoryContext(safe.tenantId, safe) : 'ADVISE AI HAFIZA SARAYI: tenant hafızası bağlı değil.';

  var prompt = [
    'AdVise AI için sosyal medya içerik paketi oluştur.',
    'Önce medya içeriğini analiz et, sonra içerik stratejisini seç, en son metni yaz.',
    'Görsel/video üzerinde görülen gerçek bilgileri temel al.',
    'Görselde veya kullanıcı notunda olmayan fiyat, kampanya, garanti, stok, teknik özellik veya sonuç uydurma.',
    'Marka/model/yazılar görünüyorsa mümkün olduğunca doğru çıkar.',
    'Ürünün sektörünü ve ürün kategorisini tanımla; emin değilsen tahminini kısa ve temkinli yaz.',
    'Ton, format, amaç ve içerik açısını AI kendi seçsin.',
    'Hook kısa ve güçlü; caption doğal Türkçe; CTA tek ve net; hashtag 4-8 adet olsun.',
    'hookType alanında hook stratejisini kısa kategorik etiketle belirt (ör. SORU, MERAK, FAYDA, SORUN_ÇÖZÜM, TEKLİF, SOSYAL_KANIT, ACİLİYET, HİKAYE, DOĞRUDAN).',
    'recommendedPostTime Türkiye saatiyle HH:MM olsun.',
    'Geçmiş performans verisi yoksa bunu açıkça belirt; başarı garantisi verme.',
    ...(isWhatsAppGoal(safe.goal) ? [
      'İLETİŞİM KANALI WHATSAPP: İşletme müşteri dönüşlerini WhatsApp üzerinden alıyor.',
      'Caption ve CTA içinde Instagram DM, doğrudan mesaj veya yorum yoluyla iletişim isteme; tüm iletişim çağrıları WhatsApp yönlendirmeli olsun.',
      'CTA açıkça WhatsApp üzerinden yazmaya çağırmalı. Kullanıcı vermediyse telefon numarası veya wa.me bağlantısı uydurma.'
    ] : []),
    ...(safe.adTargeting ? [
      'REKLAM HEDEFLEME TERCİHİ: ' + safe.adTargeting,
      'Bu hedeflemeyi adRecommendation alanında uygula; caption içine şehir adlarını ancak kullanıcı notu veya görsel bunu gerektiriyorsa yaz.'
    ] : []),
    'Kullanıcı notu: ' + (safe.context || '-'),
    'Ürün başlığı/dosya adı: ' + (safe.title || '-'),
    'Medya tipi: ' + safe.mediaType,
    'Ton tercihi: ' + safe.tone,
    'Amaç tercihi: ' + safe.goal,
    'Zaman dilimi: ' + safe.timezone,
    'Medya notu: ' + (safe.mediaNote || '-'),
    ...(safe.industry ? ['Bilinen sektör: ' + safe.industry] : []),
    ...(safe.productCategory ? ['Bilinen ürün kategorisi: ' + safe.productCategory] : []),
    ...(safe.targetAudience ? ['Bilinen hedef kitle: ' + safe.targetAudience] : []),
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
        'Çıktı tamamen Türkçe ve uygulanabilir olsun.',
        ...(isWhatsAppGoal(safe.goal) ? ['Dönüş hedefi yalnızca WhatsApp mesajıdır; Instagram DM önerme ve WhatsApp numarası/linki uydurma.'] : [])
      ].join('\n'),
      mediaParts: mediaParts,
      schema: OUTPUT_SCHEMA,
      maxOutputTokens: 8192
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
  var safe = {title: clean(input.title, 180) || 'Ürün', context: clean(input.context, 900), tone: clean(input.tone, 80) || 'samimi ve güven veren', goal: isWhatsAppGoal(input.goal) ? clean(input.goal, 80) : 'WhatsApp mesajı'};
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
      prompt: ['Aynı Instagram içeriğinin 3 farklı caption varyasyonunu üret.', 'Türkçe yaz.', 'Uydurma özellik veya fiyat ekleme.', ...(isWhatsAppGoal(safe.goal) ? ['İşletme yalnızca WhatsApp üzerinden dönüş alıyor. CTA ve caption içinde Instagram DM/yorum isteme; WhatsApp üzerinden iletişim iste. Numara veya wa.me linki uydurma.'] : []), 'Ürün: ' + safe.title, 'Bilgi: ' + (safe.context || '-'), 'Ton: ' + safe.tone, 'Amaç: ' + safe.goal].join('\n'),
      systemInstruction: 'AdVise AI için kısa, doğal ve farklılaştırılmış Instagram metinleri üret.',
      mediaParts: [],
      schema: VARIANTS_SCHEMA,
      maxOutputTokens: 2048
    });
    var variants = Array.isArray(result.parsed.variants) ? result.parsed.variants.slice(0, 3) : [];
    if (isWhatsAppGoal(safe.goal)) variants = variants.map(function(item) { return {...item, cta: whatsappCta(item && item.cta)}; });
    return {source: 'GEMINI', model: result.model, variants: variants};
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

export async function analyzeAdPerformance(input={}) {
  var adSets = (Array.isArray(input.adSets) ? input.adSets : []).slice(0, 50).map(function(row) {
    return {
      adSetId: clean(row.adSetId, 100),
      name: clean(row.name, 120),
      status: clean(row.status, 30),
      dailyBudget: Math.max(0, Number(row.dailyBudget) || 0),
      spend7d: Math.max(0, Number(row.spend7d) || 0),
      impressions7d: Math.max(0, Number(row.impressions7d) || 0),
      clicks7d: Math.max(0, Number(row.clicks7d) || 0),
      ctr7d: Math.max(0, Number(row.ctr7d) || 0),
      messages7d: Math.max(0, Number(row.messages7d) || 0),
      messageCost7d: row.messageCost7d == null ? null : Math.max(0, Number(row.messageCost7d) || 0),
      audienceMode: clean(row.audienceMode, 20),
      usesSavedAudience: Boolean(row.usesSavedAudience)
    };
  });
  if (!String(process.env.GEMINI_API_KEY || '').trim()) {
    return {source:'LOCAL_FALLBACK', model:null, error:'Gemini API anahtarı yapılandırılmamış.', summary:'Reklamlar için Gemini analizi yapılamadı.', decisions:[]};
  }
  try {
    var result = await callGemini({
      prompt: [
        'Meta reklam ad set performansını incele ve her ad set için tek bir uygulanabilir karar üret.',
        'Harcanan bütçe ve metrikler son 7 günlük gerçekleşen değerlerdir; gelecek sonucu garanti etme.',
        'Yetersiz veri varsa KEEP seç. Mesaj maliyetini, harcamayı, CTR ve mesaj sayısını birlikte değerlendir.',
        'Bütçe artırımı sadece hesabın toplam günlük limitini ve ad set günlük üst sınırını aşmamalı; sistem bu sınırları ayrıca zorunlu uygular.',
        'Manuel durdurulmuş bir reklamı ACTIVE önermeden önce dikkatli ol; auto yönetici bu öneriyi kullanıcı onayı olmadan uygulamaz.',
        'Hedefleme değişikliği için yalnızca işletme tarafından önceden kaydedilmiş hedef kitleyi öner: ' + clean(input.savedAudience, 400),
        'Bölge veya şehir kırılımında performans verisi verilmediyse şehirlerin performansını tahmin etme. APPLY_SAVED_AUDIENCE kararını ancak ad set mevcut tercihten farklıysa ver.',
        'İşletmenin reklam mesaj hedefi WhatsApp. Karar metninde farklı bir iletişim kanalı önerme.',
        'Sınırlar: minimum ad set günlük bütçe ' + (Number(input.minDailyBudget)||0) + ' TL; maksimum ad set günlük bütçe ' + (Number(input.maxDailyBudget)||0) + ' TL; tüm hesap günlük bütçe üst sınırı ' + (Number(input.dailyBudgetCap)||0) + ' TL.',
        'Rapor verisi:\n' + JSON.stringify(adSets)
      ].join('\n'),
      systemInstruction: 'Sen AdVise AI reklam optimizasyon analistisin. Yalnızca verilen performans verisine ve sınırlarına göre ölçülü, açıklanabilir kararlar ver. Meta hesabında hiçbir işlemi doğrudan yapma; uygulama kararlarını ayrıca doğrular.',
      mediaParts: [],
      schema: AD_DECISIONS_SCHEMA,
      maxOutputTokens: 4096
    });
    var allowed = new Set(['KEEP', 'PAUSE', 'ACTIVATE', 'INCREASE_BUDGET', 'DECREASE_BUDGET', 'APPLY_SAVED_AUDIENCE']);
    var decisions = Array.isArray(result.parsed?.decisions) ? result.parsed.decisions : [];
    return {
      source:'GEMINI',
      model:result.model,
      summary:clean(result.parsed?.summary, 700),
      decisions:decisions.slice(0,50).map(function(item) {
        return {
          adSetId:clean(item?.adSetId, 100),
          action:allowed.has(String(item?.action||'').toUpperCase()) ? String(item.action).toUpperCase() : 'KEEP',
          reason:clean(item?.reason, 500),
          confidence:Math.max(0,Math.min(100,Number(item?.confidence)||0))
        };
      })
    };
  } catch (error) {
    console.error('[AI GEMINI ADS ERROR]', error && error.message || error);
    return {source:'LOCAL_FALLBACK_AFTER_AI_ERROR', model:null, error:clean(error && error.message || 'Gemini analizi başarısız.', 800), summary:'Gemini şu anda reklam verisini değerlendiremedi; Meta üzerinde işlem yapılmadı.', decisions:[]};
  }
}

export function aiStatus() {
  var configured = Boolean(String(process.env.GEMINI_API_KEY || '').trim());
  return {configured: configured, model: MODEL, provider: configured ? 'GEMINI_INTERACTIONS' : 'LOCAL_FALLBACK'};
}
