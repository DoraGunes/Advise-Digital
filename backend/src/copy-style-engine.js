const OPENINGS = [
  ['SORU', 'Tek bir doğal soruyla dikkat çek; cevabı caption içinde ver.'],
  ['SORUN_COZUM', 'Önce müşterinin yaşadığı sorunu söyle, ardından çözümü netleştir.'],
  ['FAYDA', 'İlk satırda somut ve doğrulanabilir faydayı öne çıkar.'],
  ['MERAK', 'Abartısız bir merak boşluğu oluştur; clickbait kullanma.'],
  ['HIKAYE', 'Kısa bir günlük hayat anıyla başla ve hizmete bağla.'],
  ['UYARI', 'Gerçek bir riski sakin biçimde belirt; korku sömürüsü yapma.'],
  ['DOĞRUDAN', 'Ne sunduğunu ilk satırda doğrudan söyle.'],
  ['EMPATI', 'Müşterinin durumunu doğal ve samimi biçimde yansıt.'],
  ['KARSILASTIRMA', 'İki durum arasındaki farkı doğrulanabilir biçimde göster.'],
  ['LISTE_HOOK', 'Kısa bir sayı/listeli giriş kullan; içerikte gerçekten karşılığını ver.']
];

const STRUCTURES = [
  ['HOOK_BULLETS_CTA', 'Hook → kısa açıklama → 3-5 okunabilir madde → ayrı CTA satırı.'],
  ['PROBLEM_SOLUTION_CTA', 'Sorun → neden önemli → çözüm → güven unsuru → CTA.'],
  ['HOOK_STORY_CTA', 'Hook → kısa mikro hikâye → çözüm → CTA.'],
  ['MINIMAL', '2-4 kısa paragraf; yalnızca gerekli bilgiler ve CTA.'],
  ['EDUCATIONAL', 'Soruyu açıkla → kısa bilgi ver → ne yapılmalı → CTA.'],
  ['CHECKLIST', 'Kısa giriş → işaretli kontrol listesi → CTA.'],
  ['TRUST_PROOF', 'Hizmet → süreç → güven unsurları → CTA; kanıtlanmayan sayı/iddia yok.'],
  ['VISUAL_COMPANION', 'Görselde zaten yazanları tekrarlama; görseli tamamlayan kısa caption yaz.']
];

const TONES = [
  ['SAMIMI', 'Sıcak, doğal ve günlük Türkçe; yapay reklamcı dili yok.'],
  ['PROFESYONEL', 'Kurumsal ama insani; kısa, net ve güven veren.'],
  ['ENERJIK', 'Canlı ve ritmik; ünlem ve emoji dozunu kaçırma.'],
  ['GUVEN_VEREN', 'Sakin, açıklayıcı ve güven odaklı.'],
  ['PREMIUM', 'Daha rafine, sade ve yüksek kalite hissi veren.'],
  ['ESPRILI', 'Hafif mizah; marka ciddiyetini bozma.'],
  ['UZMAN', 'Bilgilendirici ve teknik ama herkesin anlayacağı dil.'],
  ['YEREL_SAMIMI', 'Mahalle/yerel işletme sıcaklığı; zorlama şehir adı veya argo yok.']
];

const EMOJI_LEVELS = [
  ['NONE', 'Emoji kullanma.'],
  ['LIGHT', 'En fazla 1-2 işlevsel emoji kullan.'],
  ['BALANCED', '3-6 işlevsel emoji kullan; satır başlarında tekrar eden süs emojilerinden kaçın.'],
  ['EXPRESSIVE', 'Görsel eğlenceliyse ölçülü biçimde daha canlı emoji kullan; okunabilirliği bozma.']
];

const LENGTHS = [
  ['MICRO', 'Yaklaşık 120-250 karakter.'],
  ['SHORT', 'Yaklaşık 250-500 karakter.'],
  ['MEDIUM', 'Yaklaşık 500-900 karakter.'],
  ['LONG', 'Yaklaşık 900-1500 karakter; yalnızca içerik gerçekten gerektiriyorsa.']
];

const CTA_STYLES = [
  ['DIRECT', 'Tek ve açık eylem: WhatsApp üzerinden yaz / bilgi al.'],
  ['FRIENDLY', 'Samimi, baskısız bir davet cümlesi.'],
  ['SERVICE_FIRST', 'Önce yardım/çözüm vurgusu, sonra iletişim çağrısı.'],
  ['QUESTION', 'Kullanıcının durumunu soran ve WhatsApp yanıtına yönlendiren CTA.'],
  ['SHORT', '3-7 kelimelik çok kısa CTA.'],
  ['CONFIDENCE', 'Güven hissi veren ama garanti vaat etmeyen CTA.']
];

const RHYTHMS = [
  ['SHORT_LINES', 'Kısa satırlar ve belirgin boşluklarla mobil okunabilirlik.'],
  ['MIXED', 'Kısa hook + 1-2 orta paragraf + ayrı CTA.'],
  ['COMPACT', 'Az satır, yüksek bilgi yoğunluğu.'],
  ['STORY_FLOW', 'Akıcı cümleler; paragraf geçişleri doğal.']
];

const HASHTAG_STYLES = [
  ['FOCUSED', '4-6 yüksek ilgili hashtag.'],
  ['BALANCED', '6-8 marka + kategori + niyet hashtag karışımı.'],
  ['LOCAL', 'Yerel bağlam gerçekten biliniyorsa 1-2 yerel hashtag ekle.'],
  ['MINIMAL', '3-4 güçlü hashtag; gereksiz geniş etiket kullanma.']
];

const BRAND_VOICES = [
  ['HUMAN_HELPER', 'Marka bir insan gibi yardımcı ve ulaşılabilir konuşsun.'],
  ['EXPERT_PARTNER', 'Uzman ama üstten konuşmayan çözüm ortağı tonu.'],
  ['SMART_MODERN', 'Modern, dijital ve akıllı; jargon yükü düşük.'],
  ['LOCAL_TRUST', 'Yerel işletme güveni ve sıcaklığı.'],
  ['PREMIUM_SERVICE', 'Düzenli, rafine ve yüksek hizmet standardı hissi.']
];

export const COPY_STYLE_ENUMS = Object.freeze({
  opening: OPENINGS.map(x => x[0]),
  structure: STRUCTURES.map(x => x[0]),
  tone: TONES.map(x => x[0]),
  emojiLevel: EMOJI_LEVELS.map(x => x[0]),
  length: LENGTHS.map(x => x[0]),
  ctaStyle: CTA_STYLES.map(x => x[0]),
  rhythm: RHYTHMS.map(x => x[0]),
  hashtagStyle: HASHTAG_STYLES.map(x => x[0]),
  brandVoice: BRAND_VOICES.map(x => x[0])
});

export const COPY_STYLE_SPACE_SIZE = Object.values(COPY_STYLE_ENUMS)
  .reduce((total, rows) => total * rows.length, 1);

function clean(value, max=500) {
  return String(value ?? '').trim().slice(0, max);
}

function rowsToText(label, rows) {
  return label + ': ' + rows.map(([id, rule]) => id + '=' + rule).join(' | ');
}

export function buildCopyStyleGuide(input={}) {
  const mediaType = clean(input.mediaType, 40).toUpperCase() || 'AUTO';
  const goal = clean(input.goal, 120);
  const tone = clean(input.tone, 120);
  const industry = clean(input.industry, 120);
  const category = clean(input.productCategory, 120);

  return [
    'ADVISE COPY STYLE ENGINE V3:',
    'Bu bir sabit şablon listesi değildir. Aşağıdaki boyutlar birlikte seçildiğinde ' + COPY_STYLE_SPACE_SIZE.toLocaleString('en-US') + '+ farklı yazım reçetesi oluşur.',
    'Görsel/video analizine göre yalnızca bir reçete seç. Görsel ciddi ve kurumsalsa sadeleş; karikatür/eğlenceli ise samimiyeti artır ama profesyonelliği koru.',
    'Görsel üzerinde çok metin varsa caption aynı cümleleri tekrar etmesin; VISUAL_COMPANION veya MINIMAL yapıya yaklaş.',
    'Hizmet/teknik servis içeriğinde müşteri sorunu görünüyorsa SORUN_COZUM, EMPATI veya SORU açılışları genellikle uygundur.',
    'Görselde hizmet maddeleri/ikonlar varsa CHECKLIST veya HOOK_BULLETS_CTA düşünülebilir.',
    'Emoji yalnızca anlam taşıyorsa kullan. Her satıra emoji koyma. Kurumsal görselde LIGHT/NONE; eğlenceli görselde BALANCED düşünülebilir.',
    'Caption mobil ekranda taranabilir olsun: ilk 2 satır güçlü, paragraf blokları kısa, CTA ayrı satır.',
    'Kullanıcı örneğindeki iyi yazım davranışını taklit et: güçlü başlık/hook, doğal açıklama, gerektiğinde işaretli maddeler, temiz boşluklar, tek CTA, seçilmiş hashtagler. Metni birebir kopyalama.',
    rowsToText('OPENING', OPENINGS),
    rowsToText('STRUCTURE', STRUCTURES),
    rowsToText('TONE', TONES),
    rowsToText('EMOJI', EMOJI_LEVELS),
    rowsToText('LENGTH', LENGTHS),
    rowsToText('CTA_STYLE', CTA_STYLES),
    rowsToText('RHYTHM', RHYTHMS),
    rowsToText('HASHTAG_STYLE', HASHTAG_STYLES),
    rowsToText('BRAND_VOICE', BRAND_VOICES),
    'Mevcut bağlam: mediaType=' + mediaType + '; goal=' + (goal || '-') + '; requestedTone=' + (tone || '-') + '; industry=' + (industry || '-') + '; category=' + (category || '-') + '.',
    'Seçtiğin reçeteyi output alanlarına yaz; caption o reçeteyi gerçekten uygulamalı.'
  ].join('\n');
}

export function normalizeCopyStyle(value={}) {
  const choose = (key, fallback) => {
    const raw = clean(value?.[key], 80).toUpperCase();
    return COPY_STYLE_ENUMS[key].includes(raw) ? raw : fallback;
  };
  return {
    opening: choose('opening', 'SORUN_COZUM'),
    structure: choose('structure', 'HOOK_BULLETS_CTA'),
    tone: choose('tone', 'SAMIMI'),
    emojiLevel: choose('emojiLevel', 'BALANCED'),
    length: choose('length', 'MEDIUM'),
    ctaStyle: choose('ctaStyle', 'FRIENDLY'),
    rhythm: choose('rhythm', 'SHORT_LINES'),
    hashtagStyle: choose('hashtagStyle', 'BALANCED'),
    brandVoice: choose('brandVoice', 'HUMAN_HELPER')
  };
}
