import {config} from './config.js';

const MODEL = process.env.OPENAI_MODEL || config.aiModel || 'gpt-6-luna';
const API_URL = 'https://api.openai.com/v1/responses';

const OUTPUT_SCHEMA = {
  type: 'object',
  additionalProperties: false,
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
    'productName',
    'brand',
    'model',
    'detectedText',
    'detectedOffer',
    'selectedTone',
    'contentAngle',
    'hook',
    'caption',
    'cta',
    'hashtags',
    'recommendedFormat',
    'recommendedPostTime',
    'recommendedPostTimeReason',
    'contentGoal',
    'targetAudience',
    'visualSummary',
    'creativeScore',
    'adRecommendation',
    'nextAction',
    'confidence'
  ]
};

function clean(value, max=1600) {
  return String(value ?? '').trim().slice(0, max);
}

function safeHashtags(value) {
  const list = Array.isArray(value) ? value : [];
  return list
    .map(x => clean(x, 60))
    .filter(Boolean)
    .map(x => x.startsWith('#') ? x : `#${x.replace(/^#+/, '')}`)
    .slice(0, 12);
}

function localPack(input={}) {
  const title = clean(input.title, 180) || 'Ürün';
  const context = clean(input.context, 900);
  const mediaType = String(input.mediaType || 'AUTO').toUpperCase();
  const format = ['REELS', 'VIDEO'].includes(mediaType) ? 'REELS' : 'POST';
  const extra = context ? ` ${context}` : '';
  return {
    source: 'LOCAL_FALLBACK',
    model: null,
    hook: `${title}: Fark yaratan detay burada.`,
    caption: `${title} için fayda odaklı bir içerik.${extra} Detaylar ve bilgi için bize mesaj gönderebilirsin.`,
    cta: 'Detaylı bilgi ve fiyat için mesaj gönder.',
    hashtags: ['#PoyrazTeknik', '#kampanya', '#fırsat', '#ürün'],
    recommendedFormat: format,
    recommendedPostTime: '19:00',
    recommendedPostTimeReason: 'Yerel fallback: geçmiş performans verisi verilmediği için genel bir akşam önerisi kullanıldı.',
    contentGoal: clean(input.goal, 80) || 'mesaj',
    targetAudience: 'Ürünle ilgili yerel ve ilgili potansiyel müşteriler.',
    visualSummary: 'Görsel AI ile analiz edilemedi; yalnızca verilen başlık ve metin kullanıldı.',
    creativeScore: 55,
    adRecommendation: 'İçeriği önce organik olarak test et; yeterli veri oluşunca reklam kararını ver.',
    nextAction: 'İçeriği gözden geçir ve uygun görüyorsan planla.',
    confidence: 35
  };
}

function normalizePack(raw, input={}) {
  const fallback = localPack(input);
  const pack = raw && typeof raw === 'object' ? raw : {};
  return {
    source: 'OPENAI',
    model: MODEL,
    productName: clean(pack.productName, 180) || clean(input.title, 180) || 'Ürün',
    brand: clean(pack.brand, 100),
    model: clean(pack.model, 120),
    detectedText: clean(pack.detectedText, 900),
    detectedOffer: clean(pack.detectedOffer, 300),
    selectedTone: clean(pack.selectedTone, 120) || 'samimi ve güven veren',
    contentAngle: clean(pack.contentAngle, 300) || 'ürünün gerçek avantajlarını net ve doğal biçimde öne çıkar',
    hook: clean(pack.hook, 300) || fallback.hook,
    caption: clean(pack.caption, 2200) || fallback.caption,
    cta: clean(pack.cta, 300) || fallback.cta,
    hashtags: safeHashtags(pack.hashtags).length ? safeHashtags(pack.hashtags) : fallback.hashtags,
    recommendedFormat: ['POST', 'REELS', 'CAROUSEL'].includes(String(pack.recommendedFormat).toUpperCase())
      ? String(pack.recommendedFormat).toUpperCase()
      : fallback.recommendedFormat,
    recommendedPostTime: clean(pack.recommendedPostTime, 100) || fallback.recommendedPostTime,
    recommendedPostTimeReason: clean(pack.recommendedPostTimeReason, 500) || fallback.recommendedPostTimeReason,
    contentGoal: clean(pack.contentGoal, 120) || fallback.contentGoal,
    targetAudience: clean(pack.targetAudience, 500) || fallback.targetAudience,
    visualSummary: clean(pack.visualSummary, 700) || fallback.visualSummary,
    creativeScore: Math.max(0, Math.min(100, Number(pack.creativeScore) || fallback.creativeScore)),
    adRecommendation: clean(pack.adRecommendation, 700) || fallback.adRecommendation,
    nextAction: clean(pack.nextAction, 500) || fallback.nextAction,
    confidence: Math.max(0, Math.min(100, Number(pack.confidence) || fallback.confidence))
  };
}

function buildHistoryText(history) {
  if (!Array.isArray(history) || !history.length) return 'Geçmiş performans verisi yok.';
  return history.slice(-20).map((item, i) => {
    const row = item && typeof item === 'object' ? item : {};
    return [
      `Kayıt ${i + 1}:`,
      `tür=${clean(row.type, 80)}`,
      `tarih=${clean(row.createdAt || row.at || '', 60)}`,
      `veri=${clean(JSON.stringify(row), 900)}`
    ].join(' ');
  }).join('\n');
}

async function callOpenAI({input, maxOutputTokens=1200}) {
  const apiKey = String(process.env.OPENAI_API_KEY || '').trim();
  if (!apiKey) throw new Error('OPENAI_API_KEY tanımlı değil.');

  const response = await fetch(API_URL, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${apiKey}`
    },
    body: JSON.stringify({
      model: MODEL,
      input,
      max_output_tokens: maxOutputTokens,
      text: {
        format: {
          type: 'json_schema',
          name: 'advise_ai_content_pack',
          strict: true,
          schema: OUTPUT_SCHEMA
        }
      }
    })
  });

  const data = await response.json();
  if (!response.ok) {
    throw new Error(data?.error?.message || `OpenAI API ${response.status}`);
  }

  const outputText = String(data.output_text || '').trim();
  if (!outputText) throw new Error('OpenAI boş cevap döndürdü.');
  let parsed;
  try {
    parsed = JSON.parse(outputText);
  } catch {
    throw new Error('OpenAI yapılandırılmış JSON cevabı çözülemedi.');
  }
  return parsed;
}

export async function generateContentPack(input={}) {
  const safe = {
    title: clean(input.title, 180),
    context: clean(input.context, 1200),
    tone: clean(input.tone, 100) || 'AI seçsin',
    goal: clean(input.goal, 100) || 'AI seçsin',
    language: clean(input.language, 30) || 'Türkçe',
    mediaType: String(input.mediaType || 'AUTO').toUpperCase(),
    imageUrl: clean(input.imageUrl, 1800),
    imageDataUrl: typeof input.imageDataUrl === 'string' && input.imageDataUrl.startsWith('data:image/')
      ? input.imageDataUrl.slice(0, 16000000)
      : '',
    mediaNote: clean(input.mediaNote, 500),
    timezone: clean(input.timezone, 80) || config.timezone || 'Europe/Istanbul',
    history: Array.isArray(input.history) ? input.history : []
  };

  if (!String(process.env.OPENAI_API_KEY || '').trim()) {
    return localPack(safe);
  }

  const prompt = [
    'Sen AdVise AI isimli profesyonel sosyal medya ve reklam yaratıcı direktörüsün.',
    'Görevin önce görseli anlamak, sonra içerik stratejisini belirlemek ve en son yüksek kaliteli Türkçe sosyal medya içeriği üretmektir.',
    '',
    'ÇALIŞMA SIRASI:',
    'A) GÖRSELİ ANLA: Görseldeki ana ürünü/hizmeti, marka adını, model bilgisini, görünen yazıları, fiyat/indirim gibi teklifleri ve görselde gerçekten bulunan önemli ayrıntıları tespit et.',
    'B) SADECE KANITLANABİLEN BİLGİYİ KULLAN: Görselde veya kullanıcı notunda olmayan fiyat, indirim, özellik, garanti, stok, kampanya veya teknik bilgi uydurma.',
    'C) ÜRÜNÜ SINIFLANDIR: Ürün adını ve mümkünse marka/modeli doğal bir Türkçe ifadeyle çıkar.',
    'D) İÇERİK AÇISINI SEÇ: Ürünü satmaya çalışan klişe reklam dili yerine görseldeki en güçlü gerçek avantaj/mesaj üzerinden tek bir içerik açısı belirle.',
    'E) TONU OTOMATİK SEÇ: Ürün ve görsel bağlamına göre samimi, premium, enerjik, teknik, güven veren vb. en uygun tonu kendin seç ve selectedTone alanında belirt.',
    'F) FORMAT VE AMAÇ: İçeriğin POST, REELS veya CAROUSEL formatında mı daha anlamlı olduğunu ve amacın mesaj, satış, trafik veya etkileşimden hangisi olduğunu veriye göre seç.',
    'G) METNİ YAZ: Hook kısa ve güçlü olsun. Caption doğal Türkçe olsun; yapay zekâ kokan kalıp cümlelerden, gereksiz ünlemden, klişe ifadelerden ve anlamsız süslü dilden kaçın.',
    'H) CTA: Tek ve net bir eylem çağrısı üret.',
    'I) HASHTAG: 4-8 alakalı hashtag üret; genel spam hashtag doldurma.',
    '',
    `Görsel / ürün başlığı (varsa): ${safe.title || '-'}`,
    `Kullanıcı notu (varsa): ${safe.context || '-'}`,
    `Ton tercihi: ${safe.tone}`,
    `Amaç tercihi: ${safe.goal}`,
    `Medya tipi: ${safe.mediaType}`,
    `Zaman dilimi: ${safe.timezone}`,
    '',
    'Geçmiş performans / uygulama sinyalleri:',
    buildHistoryText(safe.history),
    '',
    'KALİTE KURALLARI:',
    '1) Görselde okunabilen yazıları mümkün olduğunca accurately aktar; okuyamıyorsan tahmin etme.',
    '2) Ürünün ne olduğu belirsizse bunu açıkça belirt ve metni belirsizliği gizleyecek şekilde yaz.',
    '3) Marka/model görünüyorsa productName alanında mümkün olduğunca spesifik ol.',
    '4) detectedOffer yalnızca gerçekten görülen fiyat/indirim/teklif varsa doldur.',
    '5) selectedTone ve contentAngle birbirini desteklesin.',
    '6) recommendedPostTime Türkiye saatiyle HH:MM biçiminde ver.',
    '7) creativeScore yalnızca hazırlık kalitesini değerlendirsin; başarı garantisi verme.',
    '8) adRecommendation bütçe veya performans verisi yoksa kesin satış/sonuç iddiasında bulunmasın.',
    '9) nextAction kullanıcının hemen uygulayabileceği tek sonraki adım olsun.',
    '10) Yanıt tamamen Türkçe olsun.'
  ].join('\n');

  const content = [{type: 'input_text', text: prompt}];
  if (safe.imageDataUrl) {
    content.push({type: 'input_image', image_url: safe.imageDataUrl, detail: 'high'});
  } else if (/^https:\/\//i.test(safe.imageUrl)) {
    content.push({type: 'input_image', image_url: safe.imageUrl, detail: 'high'});
  }

  try {
    const parsed = await callOpenAI({
      input: [{role: 'user', content}],
      maxOutputTokens: 1500
    });
    return normalizePack(parsed, safe);
  } catch (e) {
    console.error('[AI OPENAI ERROR]', e?.message || e);
    return {
      ...localPack(safe),
      source: 'LOCAL_FALLBACK_AFTER_AI_ERROR',
      error: clean(e?.message || 'OpenAI çağrısı başarısız.', 800)
    };
  }
}

export async function generateCaption(input={}) {
  return generateContentPack(input);
}

export async function generateCaptionVariants(input={}) {
  const safe = {
    title: clean(input.title, 180) || 'Ürün',
    context: clean(input.context, 900),
    tone: clean(input.tone, 80) || 'samimi ve güven veren',
    goal: clean(input.goal, 80) || 'mesaj',
    language: clean(input.language, 30) || 'Türkçe'
  };
  const apiKey = String(process.env.OPENAI_API_KEY || '').trim();
  if (!apiKey) {
    const base = localPack(safe);
    return {
      source: 'LOCAL_FALLBACK',
      model: null,
      variants: [
        {id: 'A', caption: base.caption, hook: base.hook, cta: base.cta, style: 'Doğrudan'},
        {id: 'B', caption: `${safe.title}: İhtiyacın olan detayları tek yerde keşfet. ${base.cta}`, hook: `${safe.title} hakkında bunu biliyor musun?`, cta: base.cta, style: 'Merak uyandıran'},
        {id: 'C', caption: `${safe.title} için kısa ve net bilgi. ${base.cta}`, hook: 'Kısa, net ve fayda odaklı.', cta: base.cta, style: 'Minimal'}
      ]
    };
  }

  const prompt = [
    'AdVise AI için aynı Instagram içeriğinin 3 farklı caption varyasyonunu üret.',
    'Türkçe yaz, uydurma özellik veya fiyat ekleme.',
    `Ürün: ${safe.title}`,
    `Bilgi: ${safe.context || '-'}`,
    `Ton: ${safe.tone}`,
    `Amaç: ${safe.goal}`,
    'Her varyant için id, caption, hook, cta ve style döndür.'
  ].join('\n');

  try {
    const r = await fetch(API_URL, {
      method: 'POST',
      headers: {
        'content-type': 'application/json',
        authorization: `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: MODEL,
        input: [{role: 'user', content: [{type: 'input_text', text: prompt}]}],
        max_output_tokens: 1000,
        text: {
          format: {
            type: 'json_schema',
            name: 'advise_ai_caption_variants',
            strict: true,
            schema: {
              type: 'object',
              additionalProperties: false,
              properties: {
                variants: {
                  type: 'array',
                  minItems: 3,
                  maxItems: 3,
                  items: {
                    type: 'object',
                    additionalProperties: false,
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
            }
          }
        }
      })
    });
    const data = await r.json();
    if (!r.ok) throw new Error(data?.error?.message || `OpenAI API ${r.status}`);
    const parsed = JSON.parse(String(data.output_text || '{}'));
    if (!Array.isArray(parsed.variants) || parsed.variants.length < 1) {
      throw new Error('AI varyasyon cevabı geçersiz.');
    }
    return {source: 'OPENAI', model: MODEL, variants: parsed.variants.slice(0, 3)};
  } catch (e) {
    const base = localPack(safe);
    return {
      source: 'LOCAL_FALLBACK_AFTER_AI_ERROR',
      model: null,
      error: clean(e.message, 500),
      variants: [
        {id: 'A', caption: base.caption, hook: base.hook, cta: base.cta, style: 'Doğrudan'},
        {id: 'B', caption: `${safe.title}: Detayları keşfet. ${base.cta}`, hook: `${safe.title} için doğru seçim neden önemli?`, cta: base.cta, style: 'Merak uyandıran'},
        {id: 'C', caption: `${safe.title}: Kısa, net ve fayda odaklı. ${base.cta}`, hook: 'Kısa, net ve fayda odaklı.', cta: base.cta, style: 'Minimal'}
      ]
    };
  }
}

export async function scoreCreative(input={}) {
  const caption = clean(input.caption, 2200);
  const hook = clean(input.hook, 300);
  const cta = clean(input.cta, 300);
  const hashtags = Array.isArray(input.hashtags) ? input.hashtags.length : 0;
  const mediaType = String(input.mediaType || 'POST').toUpperCase();
  const scores = {
    hook: Math.min(100, 30 + (hook.length ? Math.min(45, hook.length) : 0)),
    caption: Math.min(100, 35 + (caption.length ? Math.min(50, Math.round(caption.length / 20)) : 0)),
    cta: Math.min(100, cta.length ? 82 : 30),
    format: ['POST', 'REELS', 'CAROUSEL'].includes(mediaType) ? 85 : 55,
    hashtags: Math.min(100, hashtags * 14)
  };
  scores.overall = Math.round(Object.values(scores).reduce((a, b) => a + b, 0) / Object.keys(scores).length);
  scores.signal = scores.overall >= 80 ? 'Güçlü hazırlık sinyali' : scores.overall >= 60 ? 'Orta hazırlık sinyali' : 'İyileştirme gerekli';
  return {source: 'HEURISTIC', scores, generatedAt: new Date().toISOString()};
}

export function aiStatus() {
  return {
    configured: Boolean(String(process.env.OPENAI_API_KEY || '').trim()),
    model: MODEL,
    provider: String(process.env.OPENAI_API_KEY || '').trim() ? 'OPENAI' : 'LOCAL_FALLBACK'
  };
}
