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
 evaluation:{primaryMetric:'WhatsApp conversations',costGoalTry:[2,3],
 goalIsGuarantee:false,automaticBid:false,
 note:'Gerçek harcama ve ölçülmüş konuşma sayısı olmadan mesaj maliyeti hesaplanmaz. Organik paylaşım saatleri reklam saatinin kanıtı değildir.'}
});
export function researchMemory(){return JSON.parse(JSON.stringify(MEMORY_RESEARCH));}
