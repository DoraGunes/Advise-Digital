const BRAND = 'AdVise Digital';
const OPERATOR = 'KÖROĞLU İMALAT SANAYİ VE TİCARET ANONİM ŞİRKETİ';
const TAX_NUMBER = '5860936453';
const ADDRESS = 'Karacaağaç Mah. D-100 Karayolu 6. Cad. No: 33/A İç Kapı No: 1, Merkez/Bolu';
const EMAIL = 'poyraz14bolu@gmail.com';
const WEBSITE = 'https://advisedigital.poyrazteknikservis.com.tr';

const styles = `
  :root{color-scheme:light;--ink:#172033;--muted:#5d687d;--line:#e6eaf0;--accent:#4657d9;--soft:#f6f8fc}
  *{box-sizing:border-box}body{margin:0;background:var(--soft);color:var(--ink);font:16px/1.65 system-ui,-apple-system,Segoe UI,sans-serif}
  main{max-width:900px;margin:0 auto;padding:42px 22px 72px}header{margin-bottom:28px}h1{font-size:clamp(30px,5vw,48px);line-height:1.1;margin:0 0 12px}h2{margin-top:32px;line-height:1.25}p,li{color:var(--muted)}.card{background:#fff;border:1px solid var(--line);border-radius:18px;padding:24px;box-shadow:0 8px 30px #18254a0b}.identity{display:grid;gap:6px;margin:18px 0 26px}.identity strong{color:var(--ink)}nav{display:flex;gap:14px;flex-wrap:wrap;margin-top:22px}a{color:var(--accent);font-weight:650}small{color:var(--muted)}.warning{border-left:4px solid #c38800;background:#fff9e8;padding:14px 16px;margin:22px 0}
`;

const identity = `<div class="identity"><strong>İşletmeci: ${OPERATOR}</strong><span>VKN: ${TAX_NUMBER}</span><span>Adres: ${ADDRESS}</span><span>İletişim: <a href="mailto:${EMAIL}">${EMAIL}</a></span><span>Web: <a href="${WEBSITE}">${WEBSITE}</a></span></div>`;
const nav = `<nav><a href="/">Ana sayfa</a><a href="/privacy">Gizlilik Politikası</a><a href="/terms">Kullanım Koşulları</a><a href="/data-deletion">Veri Silme</a></nav>`;

const pages = {
  '/': {
    title: BRAND,
    intro: 'İçerik ve Meta reklam operasyonları için dijital çalışma alanı.',
    body: `<div class="card"><p>AdVise Digital; içerik, Instagram medya ve Meta reklam operasyonlarının yönetilmesine yardımcı olur. İşlemler, kullanıcının talimatları ve bağlı hesap izinleri kapsamında yürütülür.</p>${identity}<h2>İletişim</h2><p>Hizmet, gizlilik veya veri silme talepleri için <a href="mailto:${EMAIL}">${EMAIL}</a> adresine başvurabilirsiniz.</p>${nav}</div>`,
  },
  '/privacy': {
    title: 'Gizlilik Politikası',
    intro: `${BRAND} gizlilik politikası`,
    body: `<div class="card">${identity}<p>Bu politika, AdVise Digital’in uygulama içinde işlediği veriler hakkında bilgilendirme amacı taşır.</p>
      <h2>İşlenen veri kategorileri</h2><p>Uygulama kodunda bulunan işlevlerle sınırlı olarak; hesap ve oturum bilgileri, kullanıcının oluşturduğu veya yüklediği içerik ve medya, yayın tercihleri, bağlı Meta varlıklarının kimlik ve durum bilgileri, işlem geçmişi, güvenlik ve hata kayıtları işlenebilir.</p>
      <h2>İşleme amaçları</h2><p>Bu veriler; hesabın çalıştırılması, seçilen içerik ve reklam işlemlerinin yürütülmesi, bağlı Meta varlıklarının gösterilmesi, güvenliğin sağlanması ve teknik sorunların incelenmesi amaçlarıyla kullanılır.</p>
      <h2>Meta ve diğer hizmetler</h2><p>Kullanıcı Meta hesabını bağladığında, seçilen işlevleri sağlamak için Meta platformlarına istek gönderilebilir. Meta’nın kendi hizmet şartları ve gizlilik politikası ayrıca geçerlidir. Uygulama, kullanıcı tarafından yetkilendirilmeyen Meta işlemlerini başlatmamalıdır.</p>
      <h2>Veri güvenliği</h2><p>Uygulama; kimlik doğrulama, yetkilendirme ve işlem güvenliği kontrolleri kullanır. Teknik güvenlik ayrıntıları, kötüye kullanımı kolaylaştırmamak için bu sayfada açıklanmaz.</p>
      <h2>Saklama süreleri ve başvurular</h2><div class="warning"><strong>Doğrulama bekleyen konu:</strong> Veri kategorilerine göre kesin saklama süreleri, silme işleminin tamamlanma süresi, özel hukuki işleme şartları ve başvuruların sonuçlandırılmasına ilişkin şirket politikası bu kod tabanında doğrulanmamıştır. Bu bilgiler işletme tarafından belirlenip bu sayfaya eklenmelidir.</div><p>Gizlilik ve veri talepleri için <a href="mailto:${EMAIL}">${EMAIL}</a> adresine yazabilirsiniz.</p>${nav}</div>`,
  },
  '/terms': {
    title: 'Kullanım Koşulları',
    intro: `${BRAND} kullanım koşulları`,
    body: `<div class="card">${identity}<h2>Hizmetin kapsamı</h2><p>AdVise Digital, içerik ve Meta reklam operasyonlarının yönetimine yardımcı olan bir yazılım hizmetidir. Hizmetin kullanılabilmesi için kullanıcı hesabı ve gerektiğinde kullanıcı tarafından yetkilendirilmiş üçüncü taraf bağlantıları gerekir.</p>
      <h2>Kullanıcı sorumlulukları</h2><ul><li>Kullanıcı, hesabının ve bağlı Meta varlıklarının kullanım yetkisine sahip olmalıdır.</li><li>Yüklenen içerik, reklam metni ve medya üzerinde gerekli haklara sahip olmak kullanıcı sorumluluğundadır.</li><li>Kullanıcı, reklam hesabı ve içerik işlemlerinde verdiği talimatların doğruluğundan sorumludur.</li><li>Meta’nın reklam politikaları, inceleme süreçleri, hesap kısıtları ve ücretlendirmesi AdVise Digital’in kontrolünde değildir.</li></ul>
      <h2>Meta işlemleri</h2><p>Meta bağlantısı kullanıcı yetkilendirmesiyle yapılır. Bağlantının kapsamı ve kullanılabilirliği, Meta’nın izinleri, hesap durumu ve platform kurallarına bağlıdır. Kullanıcı, reklam harcaması veya yayınlama talimatı vermeden önce işlemi ve bütçeyi kontrol etmelidir.</p>
      <h2>Değişiklik ve iletişim</h2><p>Hizmet kapsamı veya bu koşullar değiştiğinde güncel metin bu adreste yayımlanır. Sorular için <a href="mailto:${EMAIL}">${EMAIL}</a> adresine ulaşabilirsiniz.</p>
      <div class="warning"><strong>Doğrulama bekleyen konu:</strong> Ücretlendirme, abonelik, iptal/iade, hizmet seviyesi, uygulanacak hukuk, sorumluluk sınırları ve uyuşmazlık çözümüne ilişkin özel hükümler bu kod tabanında doğrulanmamıştır; işletme tarafından ayrıca onaylanıp eklenmelidir.</div>${nav}</div>`,
  },
  '/data-deletion': {
    title: 'Veri Silme Talebi',
    intro: `${BRAND} veri silme ve erişim talepleri`,
    body: `<div class="card">${identity}<h2>Talep gönderme</h2><p>Hesabınızla veya AdVise Digital kapsamında işlenen verilerle ilgili silme, erişim ya da düzeltme talebinizi <a href="mailto:${EMAIL}?subject=AdVise%20Digital%20veri%20talebi">${EMAIL}</a> adresine gönderebilirsiniz.</p><p>Talebinizde, hesabınızı ayırt etmeye yetecek bilgiyi ve istediğiniz işlemi açıkça belirtin. Gereksiz hassas kişisel verileri e-posta ile göndermeyin. Talebin size ait olduğunu doğrulamak için makul bir doğrulama istenebilir.</p>
      <h2>Meta bağlantısının kaldırılması</h2><p>Meta bağlantısını ayrıca ilgili Meta hesap ayarlarından kaldırabilirsiniz. Uygulama tarafındaki kayıtlar için yukarıdaki e-posta kanalını kullanın.</p>
      <div class="warning"><strong>Doğrulama bekleyen konu:</strong> Talep sonuçlandırma süresi, kimlik doğrulama yöntemi, yasal saklama istisnaları ve silme işleminin teknik kapsamı bu kod tabanında doğrulanmamıştır; işletme tarafından belirlenip bu sayfaya eklenmelidir.</div>${nav}</div>`,
  },
};

function html({title, intro, body}) {
  const canonical = title === BRAND ? `${WEBSITE}/` : `${WEBSITE}/${title === 'Gizlilik Politikası' ? 'privacy' : title === 'Kullanım Koşulları' ? 'terms' : 'data-deletion'}`;
  return `<!doctype html><html lang="tr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>${title} · ${BRAND}</title><link rel="canonical" href="${canonical}"><style>${styles}</style></head><body><main><header><small>${intro}</small><h1>${title}</h1></header>${body}<footer><p>${nav}</p><small>İşletmeci: ${OPERATOR} · <a href="mailto:${EMAIL}">${EMAIL}</a></small></footer></main></body></html>`;
}

export function publicPage(pathname) {
  const page = pages[pathname];
  return page ? html(page) : null;
}
