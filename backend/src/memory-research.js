// Curated reference library; never an instruction to publish or spend.
export const MEMORY_RESEARCH = Object.freeze({
 version: 1, reviewedAt: '2026-10-13', automaticActions: false,
 disclaimer: 'Genel araştırma ve deneme adaylarıdır. Bu hesapta başarı veya mesaj maliyeti kanıtı değildir.',
 timing: [
  {weekday:4,hour:9,minute:0,timezone:'Europe/Istanbul'},
  {weekday:3,hour:12,minute:0,timezone:'Europe/Istanbul'},
  {weekday:3,hour:18,minute:0,timezone:'Europe/Istanbul'}
 ].map(slot=>({...slot,source:'BUFFER_2026',evidence:'EXTERNAL_BENCHMARK',accountSampleSize:0})),
 sources:[{id:'BUFFER_2026',title:'Buffer: Instagram posting times, 9.6 million posts',
 url:'https://buffer.com/resources/when-is-the-best-time-to-post-on-instagram/',
 publishedAt:'2026-09-23',scope:'Farklı hesaplar; Poyraz Teknik ölçümü değil.'}],
 hashtagSets:[
  {id:'tv',title:'Televizyon arızası',tags:['#TelevizyonTamiri','#TVTamiri','#TeknikServis']},
  {id:'panel',title:'Panel ve ekran',tags:['#PanelTamiri','#TelevizyonTamiri','#EkranTamiri']},
  {id:'monitor',title:'Monitör servisi',tags:['#MonitorTamiri','#MonitörTamiri','#TeknikServis']},
  {id:'local',title:'Gerçek hizmet yerine göre seç',tags:['#BoluTeknikServis','#BoluTVTamiri']}
 ].map(set=>({...set,evidence:'EDITORIAL_CANDIDATE',accountSampleSize:0,
 reason:'İçerik ve hizmet konusuna uygun başlangıç adayı; popülerlik veya dönüşüm ölçümü yok.'})),
 adDrafts:[
 {id:'tv-whatsapp',title:'TV arıza danışma',caption:'Televizyonunuzun marka/modelini, arızasını ve bulunduğunuz ilçeyi WhatsApp’tan gönderin. Poyraz Teknik ile servis seçeneklerini birlikte değerlendirelim.'},
 {id:'panel-whatsapp',title:'Panel ve ekran arızası',caption:'Ekran kırılması, çizgi veya görüntü kaybı mı var? Marka/model ve arızanın fotoğrafını WhatsApp’tan paylaşın; servis uygunluğunu değerlendirelim.'},
 {id:'monitor-whatsapp',title:'Monitör teknik servis',caption:'Monitörünüzde görüntü sorunu mu var? Marka/model, arıza belirtisi ve ilçenizi WhatsApp’tan iletin.'},
 {id:'reels-whatsapp',title:'Servis Reels tanıtımı',caption:'Teknik servis sürecimizi yakından görün. Cihazınızın marka/modeli ve arıza bilgisiyle WhatsApp’tan bize ulaşın.'}
 ].map(draft=>({...draft,evidence:'UNTESTED_TEMPLATE',destination:'WHATSAPP',
 dailyBudgetTry:120,accountDailyCapTry:200,initialStatus:'PAUSED',
 requestedArea:{center:'Bolu merkez',radiusKm:200,regionalBoundary:false},
 availability:'PREFLIGHT_REQUIRED',
 note:'Metin taslağıdır; Meta nesnesi oluşturmaz. 200 km hedef desteği ve WhatsApp yetkisi doğrulanmadan kullanılamaz.'})),
 evaluation:{primaryMetric:'WhatsApp conversations',costGoalTry:[2,3],
 goalIsGuarantee:false,automaticBid:false,
 note:'Gerçek harcama ve ölçülmüş konuşma sayısı olmadan mesaj maliyeti hesaplanmaz. Organik paylaşım saatleri reklam saatinin kanıtı değildir.'}
});
export function researchMemory(){return JSON.parse(JSON.stringify(MEMORY_RESEARCH));}
