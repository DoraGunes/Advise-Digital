# AdVise Digital V15/V16 ürün güncellemesi

Tarih: 6 Ekim 2026. Bu rapor mevcut branch üzerindeki V15/V16 çalışmasını ve son checkpoint sonrası düzeltmeleri birlikte anlatır. Canlıya alınmış özelliklerle yerelde hazırlanan özellikler aynı kabul edilmemiştir.

## Çalışma alanı ve canlı durum

- Proje: `C:\Users\ANL\Desktop\AdVise AI-FINAL`.
- Branch: `wip/codex-product-redesign-2026-10-05`.
- Doğrulanan HEAD: `52daa82359a2727fe6f60b3d2fad2a8bab78199c`.
- Referansla aynı checkpoint üzerinde devam edildi; geri alma yapılmadı. Son düzeltmeler çalışma alanında commit edilmemiştir.
- Önceden değiştirilmiş `backend/data/*.json` ve `backend/uploads/` korunmuştur. Testler ayrı geçici veri alanlarında çalışır.
- 6 Ekim 2026 09:45 Türkiye saati kontrolünde public API ve yerel 3001 portu `/health` yanıtı başarılıdır; çalışan sürüm **14.0.0**, yeni capability alanları yoktur.
- Kaynaktaki backend ve yeni Flutter sürümü **16.0.0**. Public erişim çalışmaktadır; yeni backend kodunun runtime'a alınması ayrıca gerekir.
- `.env` değiştirilmedi; anahtarlar, Meta tokenları ve JWT değerleri rapora alınmadı. Production deploy, Cloudflare ayarı, commit veya push yapılmadı.

## A. Başlangıçta sistem nasıldı?

Express backend, JSON tabanlı tenant kayıtları, Flutter istemci, Meta/Instagram bağlantısı, Gemini Interactions, Hafıza Sarayı, optimizer ve yayın scheduler zaten vardı. Uygulama çok sayıda ayrı yönetim ekranına dağılıyordu. Bazı ekranlar aynı veriyi farklı dillerde gösteriyor; web tarafında dosya yolu yaklaşımı, oturum geri yükleme ve sürüm farkları tutarsızlık yaratıyordu. Kodda V16 geliştirmeleri olsa da çalışan public servis V14'tü.

Son GitHub checkpointleri özellikle tenant izolasyonu, rol sınırları, atomik dosya yazımı, audit kayıtları ve yayın idempotency korumaları içeriyordu. Bu düzeltmeler korunarak üstlerine devam edildi.

## B. Bulunan UX ve doğruluk problemleri

- Tekrarlayan menüler, teknik ID ağırlığı, dağınık kartlar ve farklı ekran temaları.
- Kullanıcının içerikten taslağa, kesin saate, kuyruğa ve reklama geçişinin belirsizliği.
- Bağlantısız hesapta gerçek olmayan sıfır metrik izlenimi; para biriminin sürekli TL kabul edilmesi.
- Ana sayfanın kuyruk için farklı alan adları kullanması: gerçek kayıt `publishStatus` ve `nextPublishAt` taşır.
- Caption düzenleme isteği PATCH olmasına rağmen merkezi istemci dispatcher'ının PATCH desteklememesi.
- Eski backend'in kesin yayın saatini desteklemediği halde istemcinin sessizce devam edebilmesi.
- Salt okunur rolün bazı AI Studio işlemlerini arayüzde başlatabilmesi.
- Belirsiz Instagram yayın sonucunun yeniden planlama/silme ile bozulabilmesi.
- Bağlantı ayarlarının Cloudflare kullanımına rağmen aynı Wi-Fi zorunluluğu anlatması.
- Koyu tema, büyük yazı ölçeği ve kısa yatay ekranlarda görünürlük/taşma sorunları.

## C. Yeni bilgi mimarisi

Ana Sayfa → AI Studio → Reklamlar → Plan → Daha Fazla.

Daha Fazla: Raporlar, CRM, Medya, Hafıza Sarayı, Otomasyon, Meta bağlantısı, Bildirimler, İşletme kurulumu, Ekip, Abonelik ve Hesap/Ayarlar. Yönetim yetkisi gereken girişler role göre ayrılır. Super Admin araçları yalnızca sistem yöneticisine görünür.

## D. Navigation

600 px altında alt navigation; 600–1023 px arası rail; 1024 px ve üstünde sol sidebar ve üst başlık. Her ana bölümün ayrı, korunan navigation geçmişi vardır. İlk ziyaret edilmeyen ağır ekranlar açılmaz; bölüm değiştirirken düzenlenen ekranın state'i kaybolmaz. Geri tuşu önce bölümdeki alt sayfayı kapatır.

## E. Tasarım sistemi

Merkezi `ProductTheme`, açık/koyu tema, navy yüzeyler, indigo AI vurgusu, kontrollü başarı/uyarı/hata renkleri. Ortak tipografi, spacing, radius, sınır, input ve button stilleri kullanılır. İçerik alanı en fazla 1280 px ile sınırlanır. Ağır animasyon bağımlılığı eklenmedi; küçük geçişler ve Material etkileşimleri tercih edildi.

## F. Yeniden düzenlenen ekranlar

Login ve oturum kapısı; adaptive uygulama kabuğu; ana sayfa; ilk kurulum; AI Studio; içerik planı/kuyruk; WhatsApp kampanya sihirbazı; Reklam Merkezi; Karar Merkezi; Raporlar; CRM; Otomasyon; Hafıza Sarayı; Medya; Bildirimler; Meta hesap/asset seçimi; Bağlantı Ayarları.

Ekip, abonelik, hesap ve Super Admin'in mevcut çalışan işlevleri korunmuştur. Eski yardımcı ekranlar tümüyle silinmemiştir; desteklenmeyen push/email teslimatı gibi seçenekler ana ürün menüsüne çalışan özellik gibi eklenmemiştir.

## G. Ortak bileşenler

`ProductShell`, `ProductNavigation`, `ProductPageHeader`, `ProductContent`, `ProductSurface`, `ProductMetricCard`, `ProductStatusChip`, `ProductInsightCard`, `ProductEmptyState`, `ProductErrorState`, `ProductLoadingSkeleton`, `ProductThemeController`. Dosya seçimi ve önizleme için ortak `MediaAccess`/`MediaPreview`, hata dili için `AppError` kullanılır. Button, input ve dialog ölçüleri tema üzerinden paylaşılır.

## H. AI Studio ve Hafıza Sarayı

Medya seç → Gemini analizi → düzenlenebilir sonuç/önizleme → taslağı kaydet / şimdi paylaş / kesin saate planla / reklama dönüştür.

- WhatsApp odaklı CTA ve tenant bazlı il/bölge tercihi korunur.
- Caption ve hook düzenlenebilir; kaynak/model sonucu ve yerel fallback birbirinden anlaşılır şekilde ayrılır.
- Aynı medya kaydı, yayın denemesi hata verdiğinde tekrar yüklenmez; kaydedilen post ID kullanılır.
- Reklama dönüşüm, mevcut API'nin kullandığı yayınlanmış Instagram media ID üzerinden ilerler.
- Hafıza Sarayı generation kayıtlarını ve ölçülmüş outcome kayıtlarını ayırır. En güçlü hook/hook tipi, format, saat, açı ve hedef kitle yalnızca mevcut ölçümlerden gösterilir.
- Henüz ölçülmemiş saat önerisi test hipotezidir; kanıtlanmış en iyi saat diye sunulmaz.
- İlk kurulumda işletme profilinden isteğe bağlı gerçek Gemini başlangıç önerisi alınabilir. Bu işlem reklam açmaz.

### Gerçek Gemini denemesi

Mevcut marka görseli ayrı temp veri alanında gerçek Interactions isteğine gönderildi. Üst modeller kota/rate-limit verdi; mevcut fallback zincirindeki `gemini-3.5-flash-lite` başarılı `completed` yanıtı verdi. Request/response işaretleri, `hasOutput: true`, `source: GEMINI`, provider model, visual summary ve caption doğrulandı. Generation geçici `ai_memory.json` içine yazılıp sayım/kaynak/model doğrulandı. Hiçbir production memory kaydı üretilmedi.

Video için mevcut logodan bağımlılık kurmadan iki saniyelik, 20 karelik AVI test klibi üretildi. Gerçek Gemini isteğinde üst modeller kota hatası verdi; lite model 45 saniyelik kontrollü denemede `completed` / `hasOutput: true` / `source: GEMINI` döndürdü. Video generation kaydı da ayrı geçici hafızada doğrulandı. İlk kısa süreli deneme timeout ile fallback verdi ve başarı sayılmadı. Sentetik klip, gerçek müşterinin sesli/hareketli MP4 videosunun kalite testinin yerine geçmez. AVI formatının desteği [Google'ın resmi video dokümanından](https://ai.google.dev/gemini-api/docs/video-understanding) kontrol edildi.

## I. Reklam Merkezi ve kampanya

Özet, Kampanyalar, Reklam Setleri ve Reklamlar sekmeleri; desktop tablo/mobil kart yaklaşımı; yerel isim araması; gerçek harcama, mesaj ve maliyet verileri. Bağlantısız durumda metrikler boş/ulaşılamıyor olarak gösterilir.

WhatsApp kampanya sihirbazı: Amaç → Instagram içeriği → Bütçe/Bölge → AI strateji → Önizleme/Onay. Gemini işletme, gerçek 7 günlük rapor, tenant hafızası, seçilen kreatif ve bütçeden öneri hazırlayabilir. AI bütçe/konum/yaratıcı/hook/saat/test süresi/gerekçelerini sunar. Kullanıcı onayı olmadan kampanya açılmaz; varsayılan oluşturma durumu durdurulmuştur.

## J. Karar Merkezi ve Otomasyon

AI önerisi, sistem kararı ve gerçekleşen aksiyon ayrı gösterilir. Manuel durum/bütçe değişimi ve Gemini önerisini uygulama onay ister. VIEWER mutasyon yapamaz; backend de bu sınırı uygular.

Mevcut optimizer korunur. Otomasyon aç/kapat, hesap günlük sınırı, reklam seti sınırı, minimum karar harcaması, hedef mesaj maliyeti, CTR uyarısı ve mevcut otomasyon seçenekleri tek bölümden yönetilir. AI sınırsız artırma yapamaz. Manuel durdurulan reklam otomatik açılamaz. Para birimi kontrolü olmadan TRY limiti başka hesabın parasına uygulanmaz.

Tenant işlemleri için mevcut kilitler korunur. Aynı Meta hesabını kullanan ayrı tenantların eş zamanlı bütçe işlemleri için hesap bazlı ek kilit vardır. Bu koruma dışarıdan Meta Ads Manager üzerinden yapılan eş zamanlı değişiklikleri kilitleyemez.

## K. Ana sayfa

Gerçek bugünkü harcama, aktif reklamlar, mesaj sonucu ve CPA; 7 günlük trend; kısa gerçek veri özeti; aksiyon önerileri; sıradaki planlanan içerik; otomasyon/audit etkinliği; uyarılar ve son CRM kayıtları. Günlük özet deterministik gerçek veri kural motorudur; her yenilemede Gemini çağrısı yapıldığı iddia edilmez. Eksik veri sıfır harcama/başarı gibi gösterilmez.

## L. Windows

Mevcut Flutter native scaffold ve dosya seçici korunmuştur. Sidebar/başlık, sınırlı genişlik, çok kolonlu düzen ve tablolar; AdVise pencere/ikon markalaması; 1360×820 başlangıç boyutu; DPI/monitör çalışma alanına uygun yaklaşık 1100×700 minimum. External-browser OAuth kullanılır; istemciye secret gömülmez. Installer/MSIX/signing altyapısı kurulmadı. Dağıtımda exe ile birlikte DLL ve data dizini gerekir.

## M. PWA

Manifest, marka ikonları, loading görünümü ve masaüstü orientation düzeltildi. Network-first service worker yalnızca public uygulama dosyalarını önbelleğe alır. API, uploads, Authorization, mutasyon ve farklı origin istekleri cache'e girmez. Çevrimdışı shell, çevrimdışı login/rapor/publish desteği anlamına gelmez.

## N. Android

Tek Flutter kod tabanı; küçük ekran, SafeArea, yazı ölçeği, alt navigation, geri tuşu ve mevcut photo picker. Dosya yüklemesi gerçek `XFile` byte içeriğini taşır. Üretim varsayılanı public HTTPS API'dir. Mevcut geliştirme cleartext bayrağı değiştirilmedi. Gerçek cihaz/emülatör olmadığı için build sonucu cihaz E2E geçti demek değildir.

## O. Dosyalar

Branch'in `origin/main` üzerindeki ürün değişikliklerinin dosya envanteri ve son commit edilmemiş düzeltmeler ayrı olarak `docs/V16_CHANGED_FILES.txt` içinde bulunur. Başlıca gruplar:

- Backend: `product.js`, `ai.js`, `ai-memory.js`, `gemini-ads.js`, `automation-safety.js`, `meta-oauth.js`, `persistence.js`, `meta.js`, `optimizer.js`, `scheduler.js`, `server.js`, `store.js`, `pro.js`, `ad-targeting.js`, `config.js`.
- Flutter: `main.dart`, `api.dart`, `product_ui.dart`, `product_shell.dart`, `product_dashboard.dart`, `product_more.dart`, `product_onboarding.dart`, `product_modules.dart`, `key_page.dart`, `v14_ai.dart`, `v78_pages.dart`, `content_queue_page.dart`, `social_ads_page.dart`, `media_access.dart`, `app_error.dart`.
- Platform: `pubspec.yaml`, Windows runner/ikon dosyaları, Android density ikonları, PWA manifest/index/service worker/ikonlar.
- Kanıtlar: backend testleri, Flutter testleri, PWA worker kontrol aracı, marka paketleme aracı, CI workflow ve bu raporlar.

Mevcut dirty `backend/data` ve uploads, bu task için üretilen kaynak değişikliği listesine dahil değildir.

## P. Backend değişiklikleri

- V16 health capability map ve client uyumluluk bilgisi.
- Tenant bazlı gerçek overview/report, kurulumu saklama, gerçek Gemini campaign strategy.
- OAuth'ta güvenli tek kullanım state ve açık Page/Instagram/Ad Account seçimi.
- Rol/plan/tenant enforcement; bağlantısı olmayan tenant için sistem credential'ına düşmeme.
- Actor bilgili audit kayıtları, gerçek olaylardan kalıcı uygulama içi bildirimler.
- Atomik JSON yazımı ve processler arasında kilit; bozuk JSON'u sessizce boşaltmama.
- Yayın container'ının korunması, belirsiz sonuçta RECONCILE, tekrar yayının engellenmesi.
- Bütçe/aktivasyon limiti, manuel pause koruması ve paylaşılan hesap kilidi.
- Gemini metrics alias tekrar sayımının giderilmesi; ulaşılmayan metrics ile otomatik karar almama.
- Memory retrieval/ölçülmüş hook tipi ve outcome kaynakları.
- Güncel dependency lock ve yüksek/kritik npm audit CI kapısı.

## Q. Veri geçişi

**SQL database migration yoktur.** Mevcut JSON persistence korunmuştur. Tenant onboarding, audit actor alanları, memory pattern/metadata ve post yayın phase/container alanları ihtiyaca göre eklenir; eski kayıtlarda güvenli varsayılanlar vardır. Testler production JSON dosyalarını dönüştürmez. Canlıya geçmeden JSON/uploads yedeği ayrıca alınmalıdır.

## R. Test ve kanıt

Nihai komut sonuçları ve build dosya tarihleri platform/backend kanıt raporlarında yer alır. `docs/build-evidence/` komut loglarını içerir. İlk tam Flutter test turundaki fixture/scroll sorunları son yeşil turun yerine kullanılmaz.

- `flutter analyze --no-fatal-infos`: **No issues found**, exit 0.
- `flutter test`: **48/48 başarılı**, exit 0.
- Odaklı UI paketi: 11 smoke + 10 açık/koyu tema contrast kontrolü; **21/21 başarılı**.
- Backend test/syntax/audit nihai sayıları backend raporunda kaydedilir; release çıktıları platform raporunda doğrulanır.

- Backend: izolasyon, roller, gerçek HTTP, bütçe/lock, yayın reconciliation, memory, strategy ve veri doğruluğu.
- Flutter: layout/mobile/tablet/desktop, oturum, API origin değişimi, PATCH, eski backend action guard, dosya byte yükleme, VIEWER, belirsiz yayın ve gerçek currency/empty state.
- Widget smoke: Studio → test medya → mock Gemini sonucu → kesin saat → Planner.
- Gerçek provider: izole Gemini görsel smoke; video sonucu ayrı kaydedilir.
- Browser: public servise login yapılmadan ayrı temp backend ve yerel web build üzerinde mümkün olan ekranlar.
- Gerçek Meta harcaması, production publish ve OAuth yetkilendirmesi bu testlerin parçası değildir.

## S. APK

`C:\Users\ANL\Desktop\AdVise AI-FINAL\mobile\build\app\outputs\flutter-apk\app-release.apk`

## T. Windows

`C:\Users\ANL\Desktop\AdVise AI-FINAL\mobile\build\windows\x64\runner\Release\advise_digital.exe`

Tam Release klasörü ve dağıtım ZIP'i platform raporunda belirtilir. Windows normal exe başlangıcı, mevcut kayıtlı oturumun public API'ye otomatik istek yapmasını önlemek için atlanmıştır; kullanıcının SharedPreferences dosyası açılmamış/değiştirilmemiştir.

## U. Web

`C:\Users\ANL\Desktop\AdVise AI-FINAL\mobile\build\web`

Bu dizinin public hostinge yüklenmesi bu görevde yapılmamıştır. Son build kanıtı platform raporundan kontrol edilmelidir.

## V. Sınırlar ve eksikler

- Public backend V14: V16 capability gerektiren işlemler canlıda henüz etkin değildir.
- Gerçek telefon ve native Windows tam E2E bu ortamda doğrulanamadı.
- Video önizlemesi playable player değildir; seçilen videoyu hazır olarak gösterir. Gerçek uzun MP4/telefon videosu için ayrıca kalite smoke gerekir.
- Windows drag/drop eklenmedi; native picker çalışır durumda korunur.
- Push/email gönderim altyapısı, gerçek ödeme ve Google Ads/TikTok entegrasyonu oluşturulmadı. Bunlar çalışan özellik gibi gösterilmez.
- CRM elle kayıt/stage yönetimini kullanır; Meta lead webhook ingestion ve satış/ROAS attribution için ayrı entegrasyon gerekir.
- Global search yerine modül içi arama vardır. Büyük veri/çok kullanıcı ölçeği için JSON storage yeterlilik sınırı devam eder.
- Bütçe otomasyonu TRY ve desteklenen günlük adset bütçeleri ile sınırlandırılır; unsupported CBO/lifetime/para birimi durumları otomatik harcama kapsamına alınmaz.

## W. Production'a alınması gerekenler

V16 backend kaynak/dependency değişiklikleri, yeni route/capability alanları, eşleşen Web build ve Android/Windows dağıtımları. Önce mevcut verilerin yedeği, sonra yetkilendirilmiş backend restart/deploy ve `/health` doğrulaması gerekir. Bu rapor deploy onayı yerine geçmez; task gereği deploy yapılmadı.

## X. Cloudflare

Public HTTPS yönlendirmesi bugün çalışmaktadır. DNS/route/Worker/secret değişikliği gerektiğine dair bulgu yoktur. Sorun, çalışan uygulama sürümünün geride olmasıdır. Wrangler OAuth önceden hazırlanmıştır; bu taskta Worker deploy veya altyapı değişikliği yapılmadı.

## Y. Güvenlik ve ticari riskler

**Kritik:** canlı/istemci sürüm eşleşmesi ve gerçek hesapla onaylı smoke; dışarıdan eş zamanlı Meta bütçe değişiklikleri; tek makine/JSON storage ölçek sınırı.

**Önemli:** native JWT SharedPreferences içinde mevcut biçimde saklanır; encrypted secure storage ayrı geçiş ister. Browser persistent token storage için XSS/oturum stratejisi ayrıca güçlendirilmelidir. Login rate limit/MFA ve kurtarma akışı ticari sertleştirme konusudur. İki moderate npm advisory için cron major upgrade değerlendirmesi gerekir; mevcut optimizer davranışı sırf major yükseltme için değiştirilmemiştir.

**Daha sonra:** imzalı installer/MSIX, formal accessibility audit, CDN thumbnail pipeline, daha ayrıntılı ürün telemetrisi. Gizli değerler istemciye taşınmamış ve raporda gösterilmemiştir.

## Z. Önerilen sonraki 10 geliştirme

1. Kullanıcı onayıyla V16 backend/Web canlıya geçişi; aynı sürüm health ve gerçek telefon smoke.
2. Onaylı test Instagram hesabıyla publish/reconciliation, WhatsApp kampanya ve küçük kontrollü bütçe smoke.
3. Gerçek kısa/uzun, sesli ve hareketli telefon videosu benchmark; timeout/kota takibi.
4. Native secure token storage, web oturum sertleştirme, login rate limit ve MFA.
5. Çok kullanıcı/çok instance için JSON'dan transactional veritabanı ve kalıcı job queue'ya planlı geçiş.
6. Meta lead webhook + WhatsApp görüşme/satış sonucu attribution.
7. Ölçülen satış gelirinden ROAS ve Hafıza Sarayı'na doğrulanmış satış outcome.
8. CBO/lifetime/farklı currency desteklerini ayrı limit modeliyle genişletme.
9. Native cihaz matrisi, browser refresh/offline ve formal erişilebilirlik kalite kapısı.
10. Gerçek abonelik/ödeme sağlayıcısı ve imzalı Windows dağıtımı; yeni reklam kanallarını bundan sonra ekleme.
