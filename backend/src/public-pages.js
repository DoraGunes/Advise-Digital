const BRAND = 'AdVise Digital';

const styles = `
  :root{color-scheme:light;--ink:#172033;--muted:#5d687d;--line:#e6eaf0;--accent:#4657d9;--soft:#f6f8fc}
  *{box-sizing:border-box}body{margin:0;background:var(--soft);color:var(--ink);font:16px/1.65 system-ui,-apple-system,Segoe UI,sans-serif}
  main{max-width:860px;margin:0 auto;padding:48px 22px 72px}header{margin-bottom:28px}h1{font-size:clamp(30px,5vw,48px);line-height:1.1;margin:0 0 12px}h2{margin-top:32px;line-height:1.25}p,li{color:var(--muted)}.notice{border:1px solid #e8c66a;background:#fff9e8;border-radius:14px;padding:16px 18px;margin:22px 0}.card{background:#fff;border:1px solid var(--line);border-radius:18px;padding:24px;box-shadow:0 8px 30px #18254a0b}nav{display:flex;gap:14px;flex-wrap:wrap;margin-top:22px}a{color:var(--accent);font-weight:650}small{color:var(--muted)}
`;

const pages = {
  '/': {
    title: 'AdVise Digital',
    intro: 'İçerik ve reklam operasyonlarını daha düzenli yönetmek için hazırlanan AdVise Digital.',
    body: `<div class="notice"><strong>Yayın öncesi bilgi notu:</strong> Bu ana sayfa taslağıdır. İşletme unvanı, iletişim ve sorumlu kişi bilgileri doğrulanıp eklenmeden Live başvurusu için tamamlanmış hukuki kimlik sayfası olarak kullanılmamalıdır.</div>
      <div class="card"><h2>AdVise Digital ne yapar?</h2><p>AdVise Digital; içerik, Instagram medya ve Meta reklam operasyonlarının tek bir çalışma alanında yönetilmesine yardımcı olur. Reklam ve içerik işlemleri kullanıcı onayı ve bağlı hesap izinleri kapsamında yürütülür.</p><nav><a href="/privacy">Gizlilik Politikası</a><a href="/terms">Kullanım Koşulları</a><a href="/data-deletion">Veri Silme</a></nav></div>`,
  },
  '/privacy': {
    title: 'Gizlilik Politikası',
    intro: `${BRAND} için gizlilik politikası taslağı`,
    body: `<div class="notice"><strong>Eksik zorunlu bilgiler:</strong> Yasal işletme unvanı, açık adres, yetkili iletişim adresi, veri sorumlusu bilgisi ve saklama süreleri bu çalışma alanında doğrulanmış değil. Bu alanlar doldurulmadan metin nihai hukuki politika değildir.</div>
      <div class="card"><h2>İşlenen veri kategorileri</h2><ul><li>Hesap ve oturum bilgileri.</li><li>Kullanıcının yüklediği içerik, medya ve yayın tercihleri.</li><li>Kullanıcının bağladığı Meta varlıklarına ilişkin kimlik ve durum bilgileri.</li><li>Uygulama güvenliği, işlem geçmişi ve hata kayıtları.</li></ul>
      <h2>Kullanım amaçları</h2><p>Veriler; hesabı çalıştırmak, seçilen içerik ve reklam işlemlerini yürütmek, güvenliği sağlamak ve hizmet hatalarını incelemek için kullanılır.</p>
      <h2>Üçüncü taraf hizmetler</h2><p>Meta platformları, kullanıcı tarafından bağlantı verildiğinde seçilen reklam ve medya işlemleri için kullanılır. Meta’nın kendi gizlilik ve veri işleme koşulları ayrıca geçerlidir.</p>
      <h2>Saklama ve haklar</h2><p>Saklama süreleri ve başvuru kanalı işletme tarafından doğrulanıp eklenmelidir. Veri sahibi talepleri için bu sayfada doğrulanmış bir iletişim adresi henüz tanımlanmamıştır.</p></div>`,
  },
  '/terms': {
    title: 'Kullanım Koşulları',
    intro: `${BRAND} kullanım koşulları taslağı`,
    body: `<div class="notice"><strong>Nihai kullanım koşulları değildir:</strong> Yasal işletme unvanı, taraf bilgileri, ücretlendirme, fesih, sorumluluk sınırları ve yetkili iletişim bilgileri doğrulanmadan sözleşme metni olarak kullanılmamalıdır.</div>
      <div class="card"><h2>Hizmet kapsamı</h2><p>AdVise Digital, içerik ve Meta reklam operasyonlarını yönetmeye yardımcı olan bir yazılım hizmetidir. Kullanıcı; yüklediği içeriklerin, bağlı hesapların ve verdiği reklam talimatlarının doğruluğundan sorumludur.</p>
      <h2>Meta hesapları</h2><p>Meta bağlantısı kullanıcının açık yetkilendirmesiyle yapılır. Kullanıcı, bağlı hesabı kullanma ve reklam yönetme yetkisine sahip olduğunu doğrulamalıdır. Reklamların yayınlanması, incelemesi ve harcaması Meta’nın kurallarına ve hesap durumuna tabidir.</p>
      <h2>Yayın öncesi tamamlanacak alanlar</h2><ul><li>Hizmet sağlayıcının tam yasal kimliği ve adresi.</li><li>Destek ve resmi bildirim iletişim adresi.</li><li>Ücret, abonelik, iptal ve iade koşulları.</li><li>Uygulanacak hukuk ve uyuşmazlık çözümü.</li></ul></div>`,
  },
  '/data-deletion': {
    title: 'Veri Silme Talebi',
    intro: `${BRAND} veri silme ve erişim talebi`,
    body: `<div class="notice"><strong>İletişim bilgisi bekliyor:</strong> Veri silme taleplerinin yönlendirileceği doğrulanmış işletme e-posta adresi veya resmi başvuru kanalı henüz eklenmedi. Bu sayfa bu bilgi eklenmeden Live başvurusu için tamamlanmış sayılmaz.</div>
      <div class="card"><h2>Talep kapsamı</h2><p>Kullanıcı, hesabına ait verilerin, yüklediği içeriklerin ve bağlantı bilgilerinin silinmesini veya erişim talebinin değerlendirilmesini isteyebilir.</p>
      <h2>Talep nasıl işlenecek?</h2><p>İşletme tarafından doğrulanmış başvuru adresi eklendikten sonra kullanıcı; hesap kimliğini, talep türünü ve doğrulama için gerekli sınırlı bilgiyi bu kanaldan iletebilir. Kimlik doğrulama ve yasal saklama zorunlulukları için gereken asgari kayıtlar, işletme politikasıyla açıklanmalıdır.</p>
      <h2>Meta bağlantısını kaldırma</h2><p>Meta bağlantısı ayrıca Meta hesap ayarlarından kaldırılabilir. Uygulama tarafındaki kayıtların silinmesi için işletmenin doğrulanmış başvuru kanalı kullanılmalıdır.</p></div>`,
  },
};

function html({title, intro, body}) {
  const links = ['/','/privacy','/terms','/data-deletion'].map(path => `<a href="${path}">${path === '/' ? 'Ana sayfa' : path.slice(1)}</a>`).join(' · ');
  return `<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} · ${BRAND}</title><meta name="robots" content="noindex"><style>${styles}</style></head><body><main><header><small>${intro}</small><h1>${title}</h1></header>${body}<footer><p>${links}</p><small>Bu sayfa yayın öncesi içerik taslağıdır; eksik işletme bilgileri tamamlanmadan nihai hukuki bildirim olarak kullanılmamalıdır.</small></footer></main></body></html>`;
}

export function publicPage(pathname) {
  const page = pages[pathname];
  return page ? html(page) : null;
}
