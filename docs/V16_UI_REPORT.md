# V16 ürün arayüzü ve kalite raporu

## Kapsam ve kaynak

Bu rapor, güncel ana proje üzerinde yapılan V16 arayüz çalışmasını ve son kalite düzeltmelerini açıklar. Eski worktree dosyaları ana projeye kopyalanmadı. Var olan Meta, Gemini, Hafıza Sarayı, yayınlama ve tenant iş mantığı kullanıldı.

Üretim verisine, `.env` dosyasına veya Cloudflare ayarlarına bu UI çalışması sırasında müdahale edilmedi. Test verileri yalnızca Flutter test sürecinde `MockClient` ve bellekteki fixture nesneleriyle oluşturuldu.

## Başlangıçta bulunan kullanıcı deneyimi sorunları

- Ana gezinme drawer menülerine, sürüm merkezlerine ve benzer iş yapan ekranlara bölünmüştü.
- Büyük ekranlarda mobil kartlar ve tam genişlikte listeler kullanılıyordu.
- Oturum kayıtlı olsa bile uygulama giriş formundan başlıyordu.
- İlk dashboard içerik/log sayısı ve yapılandırılmış bütçe gösteriyordu; bunlar ölçülmüş reklam sonuçlarıyla karışabiliyordu.
- AI Studio'da görüntüleme rolü üretim ve yayın butonlarını görebiliyordu.
- İçerik planı `PUBLISH_UNKNOWN` durumunu kontrol ediyordu; backend'in gerçek `RECONCILE` durumu aynı korumaya girmiyordu.
- Raporlar para birimini TL varsayıyor, bağlantısız reklam hesabında aktif reklam sayısı sıfır gibi görünüyordu.
- Bildirim açıklamalarına hata dönüştürücü uygulanması normal bağlantı haberlerini sunucu hatası metnine çevirebiliyordu.
- Medya kartlarının sabit yüksekliği büyük yazı tercihinde taşabiliyordu.

## Yeni bilgi mimarisi

Ana gezinme beş bölümden oluşur:

1. **Ana Sayfa:** gerçek reklam verileri, günlük özet, sıradaki içerik ve önemli gelişmeler.
2. **AI Studio:** medya seçimi, analiz, metin düzenleme ve açık yayın/planlama aksiyonları.
3. **Reklamlar:** genel bakış, kampanya, reklam grubu ve reklamlar; kontrollü kampanya oluşturma ve karar merkezine erişim.
4. **Plan:** taslak, tarih, kuyruk, yayınlama ve doğrulama durumları.
5. **Daha Fazla:** raporlar, CRM, medya, öğrenme, otomasyon, hesap ve çalışma alanı araçları.

Super Admin müşteri, lisans ve sistem yönetimi alanları normal tenant menüsünden ayrıldı. Eski ekranların kodu korunuyor; sürüm numaralı merkezler ana ürün gezinmesinden çıkarıldı.

## Adaptive shell

- 600 pikselin altında alt gezinme çubuğu.
- 600–1023 piksel arasında Navigation Rail.
- 1024 pikselden itibaren sidebar ve üst başlık.
- İçerik alanında azami genişlik, modüle uygun grid/Wrap ve masaüstü tabloları.
- Ana bölüm başına geç yüklenen ve korunabilen nested Navigator. Detay sayfası açılırken ana gezinme görünür kalır.
- Aynı Flutter kodu Android, web/PWA ve Windows için kullanılır.

## Tasarım sistemi

`product_ui.dart`, merkezi açık/koyu tema ve ortak bileşenler sağlar. Temel dil navy/graphite, AI vurgusu indigo, temiz yüzeyler ve sınırlı semantik renklerden oluşur. Gradient yalnızca giriş/AI/plan hero alanlarında kullanılır.

Ortak bileşenler:

- `ProductContent`, `ProductSurface`, `ProductPageHeader`
- `ProductMetricCard`, `ProductStatusChip`, `ProductInsightCard`
- `ProductEmptyState`, `ProductErrorState`, `ProductLoadingSkeleton`
- `ProductTheme`, `ProductThemeController`
- `ProductNavigation`, `ProductShell`

Durum chip'lerinin yazı renkleri açık ve koyu tema için ayrı seçildi. Kontrast regresyonları chip yüzeyinin gerçek alpha blend sonucunu kullanır; beş semantik tonun her iki temada en az 4,5:1 oranını kontrol eder. Bu kontrol tüm uygulamanın eksiksiz WCAG sertifikasyonu anlamına gelmez.

## Giriş ve kurulum

Giriş ekranı mobilde kısa, masaüstünde marka alanı ve form olarak iki kolondur. Masaüstü marka alanı büyük yazıda kayabilir. Parola görünürlüğü, hatırlanan veya yalnızca oturum boyunca tutulan giriş, loading ve Türkçe hata mesajları vardır.

`ProductSessionGate`, kayıtlı oturumu `Api.me()` ile doğrular. Yetki kaybı/oturum bitişi merkezi bildirim üzerinden ele alınır. Yeni bir sosyal giriş veya parola sıfırlama altyapısı varmış gibi buton eklenmedi.

İşletme kurulumu işletme, hedef, bölge, bütçe ve hesap bağlantısı adımlarını kaydeder; sonradan devam edilebilir. Bağlantı statüleri gerçek backend varlıklarından gelir. Hesap/varlık seçimi mevcut Meta akışını kullanır. AI başlangıç önerisi öneri üretir; kendi başına reklam yayımlamaz.

## Ekran davranışları

### Ana Sayfa

Dashboard gerçek product overview verisini kullanır. Harcama ve sonuç olmadığı durumda sıfır üretilmez; bilinmeyen değer `—` olarak gösterilir. Backend eskiyse görünür uyumluluk mesajı ve mevcut API'den alınan sınırlı gerçek özet vardır. Tarihler gerçek `nextPublishAt`, durumlar gerçek `publishStatus` alanlarına bağlıdır.

### AI Studio

Akış medya seç → analiz → düzenle → yayınla/planla/reklama dönüştür şeklindedir. İsteğe bağlı alanlar ana akışı büyütmez; analiz ayrıntıları açılır bölümde tutulur. WhatsApp dönüş kanalı görünürdür.

- Görüntüleme rolünde üretim, puanlama, varyant oluşturma, kayıt ve yayın aksiyonları kapalıdır.
- Yetki kontrolleri yalnızca görünümde değil aksiyon metotlarında da bulunur; backend enforcement ayrıca korunur.
- AI durumunun yüklenmesi/hatası ile üretim sonucunun Gemini veya yerel öneri olması ayrı gösterilir.
- Yerel fallback, doğrulanmış medya analizi gibi sunulmaz.
- Gerçek yayın onaylanmadan başarı mesajı veya reklam akışına otomatik geçiş yapılmaz.
- Yayın sonucu belirsizse aynı taslağı yeniden gönderen aksiyonlar bekletilir.
- Native/browse medya seçimi `XFile` ve bytes üzerinden çalışır. Testte seçici ve saat seçici enjekte edilebilir; üretimde normal seçiciler kullanılır.

### İçerik Planı

Bugün, yarın, hafta, takvim, taslak, başarısız ve yayınlanan görünümleri gerçek kayıtlara bağlıdır. Önerilen saat ile seçilmiş gerçek yayın zamanı ayrı kavramlardır.

`PUBLISHING`, `RECONCILE`, eski uyumluluk durumu `PUBLISH_UNKNOWN` ve belirsiz yayın işareti olan kayıtlarda düzenleme, yeniden sıraya alma, kapak değiştirme, silme ve paylaşma aksiyonları gösterilmez. Önizleme ve anlaşılır doğrulama açıklaması kullanılabilir.

### Reklamlar ve raporlar

Masaüstünde tablo, mobilde kompakt kartlar kullanılır. Rapor tarih aralıkları API'ye gönderilir. Para birimi hesabın gerçek `currency` değerinden gelir; USD hesap TL etiketi taşımaz. Hesap bağlantısı doğrulanmadığında boş reklam listesi “0 aktif reklam” diye sunulmaz.

### Otomasyon

Kural otomasyonu ve Gemini otomasyonu ayrı görünür. Günlük hesap limiti, reklam grubu sınırları ve karar eşikleri görünürdür. Otomasyonu açmadan limit doğrulaması yapılır. Sadece tenant/sistem yöneticisinin ayar kaydetmesine izin veren UI, backend yetkilendirmesini tamamlar.

### Hafıza Sarayı

Üretim sayıları ve sonuç sinyalleri mevcut memory summary'den gelir. Hook türü, format, saat, içerik açısı ve kitle sonuçları pozitif ölçülmüş skoru olduğunda gösterilir. Erken sinyaller garantili kazanan gibi sunulmaz. Yapay bir “en az üç sonuç” UI eşiği yerine gerçek sinyal/ölçüm varlığı kullanılır.

### CRM, medya ve bildirimler

CRM mevcut lead kayıtları ve aşamalarını korur. Reklam kaynağı varsa gösterir, yoksa uydurmaz. Medya kütüphanesi mevcut dosyayı tekrar yüklemeden içeriğin planını açar. Kart yüksekliği yazı boyutuna uyarlanır.

Bildirim merkezi gerçek kayıtlar ve okundu işaretini kullanır. Normal bağlantı haberleri hata mesajına çevrilmez; teknik/tehlikeli payload'lar açıklama olarak yansıtılmaz. Fake push altyapısı eklenmedi.

## Doğrulama ve sınırları

Eklenen UI smoke regresyonları:

- VIEWER için AI Studio, içerik planı ve otomasyon işlemlerinin kapalı olması.
- RECONCILE içerikte hiçbir mutasyon aksiyonunun bulunmaması.
- Gerçek hesap para birimi ve bağlantısız hesaptaki bilinmeyen KPI.
- Ölçülmüş erken hook türü sinyali ve normal Meta bildirim açıklaması.
- 320 piksel / büyük yazı / koyu tema medya ve plan kartları.
- 1100×700 / 1,8 yazı ölçeğinde masaüstü giriş.
- Kısa landscape viewport'ta loading/boş durumlar.
- Mocked medya seç → AI sonuç → tek upload → saatli queue → plan ekranı akışı.
- On semantik chip kontrast kontrolü.

Son hedefli çalıştırma: `flutter test --no-pub test/product_modules_smoke_test.dart test/product_contrast_test.dart` — **21 testin tamamı geçti**. Bu sonuç 11 UI smoke senaryosu ve açık/koyu temadaki 10 semantik kontrast kontrolünü kapsar.

Mocked uçtan uca akışın doğruladığı şey, UI ve API sözleşmesidir. Gerçek bir Gemini kota/hesap testi, gerçek Meta reklam harcaması, Instagram yayını veya fiziksel telefonda kurulum testi değildir. Bunlar üretim bağlantısı ve ayrı açık yayın yetkisi gerektiren dış doğrulamalardır.

Son analyzer, tam test suite ve release build sonuçları `docs/build-evidence/` altındaki yürütme kayıtları ve ana V16 teslim raporunda belirtilmelidir. Başarılı build tek başına tüm ekranların gerçek servislerde doğrulandığı anlamına gelmez.

### Yerel tarayıcı görsel smoke durumu — 6 Ekim 2026

Web release başarıyla derlendi ve yalıtılmış `http://127.0.0.1:8916` test sunucusu hazırlandı. Planlanan kontrol, yalnız geçici fixture hesabıyla giriş → dashboard → Studio → içerik planı → kampanya → reklam/karar → rapor → CRM → ayarlar → çıkış akışıydı. `.env` yüklenmeyen, dış servis çağrıları ve cron kapalı bu ortam üretimden ayrıdır.

Görsel smoke **çalıştırılamadı**: CUA envanteri `apps=[]`, `browsers=[]` döndürdü. Uygulama içi tarayıcı, Chrome ve Edge için ayrı `createBrowserTab` denemeleri `Browser is not available` hatası verdi. Native UI bu oturumda kapalıydı. Yerel sayfa açılmadı, test hesabıyla giriş yapılmadı ve ekran görüntüsü üretilmedi.

Bu nedenle gerçek tarayıcıdaki ikon görünümü, masaüstü/tablet/mobil ekran görünümü ve browser gezinmesi doğrulanmış sayılmaz. Widget testleri ve başarılı web build bu görsel kontrol boşluğunun yerine geçmez. Bağlı bir CUA browser olduğunda aynı yalıtılmış sunucuda tekrar çalıştırılmalıdır.

## Son QA dosyaları

- `mobile/lib/product_modules.dart`
- `mobile/lib/v14_ai.dart`
- `mobile/lib/content_queue_page.dart`
- `mobile/lib/main.dart` (masaüstü giriş overflow düzeltmesi)
- `mobile/lib/product_ui.dart` (semantik kontrast)
- `mobile/test/product_modules_smoke_test.dart`
- `mobile/test/product_contrast_test.dart`

## Üretime geçmeden önce

Yeni APK/web/Windows istemcisi yeni product ve uyumluluk endpoint'lerini bekler. Public backend sürümü ile istemci yetenekleri birlikte doğrulanmalıdır. Üretim deploy, DNS/route/secret değişimi ve commit/push bu UI çalışmasının parçası olarak yapılmadı.

Özellikle belirsiz yayın kayıtlarının korunması ve tüm rol kontrolleri API düzeyinde de uygulanmalıdır. UI'da bir butonun kapalı olması tek başına yetkilendirme sağlamaz.
