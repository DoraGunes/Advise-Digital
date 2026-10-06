# AdVise Digital V16 — Backend inceleme ve doğrulama raporu

Tarih: 6 Ekim 2026. Son inceleme referansı: `52daa82359a2727fe6f60b3d2fad2a8bab78199c`.

Bu rapor backend kapsamını anlatır. Android, web/PWA ve Windows çıktıları ile görsel kalite değerlendirmesi ana ürün raporunda yer alır. Bu çalışma production deploy, Git commit/push, Cloudflare DNS/route/secret değişikliği veya production verisi değişikliği içermemiştir. `.env` içeriği görüntülenmedi, değiştirilmedi veya commit edilmedi; canlı Gemini kontrolü yalnızca mevcut sunucu yapılandırmasını normal çalışma yolu üzerinden kullandı.

## Başlangıç ve korunmuş mimari

- Node.js + Express; Meta/Instagram için sunucu tarafında Graph API; Gemini için mevcut `@google/genai` Interactions akışı.
- Tenant, kullanıcı, ayarlar, içerikler, CRM ve hafıza kayıtları JSON dosyalarında. PostgreSQL bağlantı sağlık kontrolü mevcut, uygulama verisini PostgreSQL'e taşıyan bir katman henüz yok.
- JWT oturumu, bcrypt parola doğrulaması, tenant aktiflik/abonelik denetimi, SaaS planları ve Super Admin müşteri/lisans yönetimi korunuyor.
- 12 saatlik kural motoru, haftalık reklam otomasyonu, zamanlanmış Instagram paylaşımı ve Hafıza Sarayı v2 korunuyor.
- İlk incelemede paket sürümü `12.0.0`, geliştirilmekte olan kaynak `14.1.0` ve geçmişte çalışan production süreci arasında sürüm farkı vardı. Güncel kaynak ve manifest/lock sürümü `16.0.0`; capability denetimi istemcinin eski backend ile sessizce bozulmasını önlüyor.
- Kullanıcının sonradan eklediği tenant kilitleri, aktör bilgili audit kayıtları, hook türü öğrenimi, proaktif öneriler, Multer 2 ve CI değişiklikleri güncel referanstan okunarak korundu. Eski checkout dosyaları kopyalanmadı.

## İlk incelemede bulunan ve V16 kaynakta giderilen temel sorunlar

1. Bağlantısı olmayan müşterinin sistem hesabı token/hesap değerlerine düşmesi: tenant kimlik bilgileri artık sistem yapılandırmasına dönmüyor. Sistem fallback yalnızca açık sistem hesabı bağlamında kullanılabiliyor.
2. Tenant yöneticisinin sistem Instagram bağlantısını kendi hesabına kopyalayabilmesi: tenant OAuth ve gerçek varlık seçimi yolu kullanılıyor.
3. OAuth callback'in Bearer auth arkasında kalması: callback herkese açık callback yolu üzerinde, kısa ömürlü imzalı ve tek kullanımlık state ile doğrulanıyor; mevcut kullanıcı/tenant/yetki ayrıca kontrol ediliyor.
4. Görüntüleyici rolünün içerik, CRM ve otomasyon değiştirebilmesi: yazma işlemlerinde backend rol kontrolü var. Müşteri yönetimi, ekip yönetimi ve Super Admin yetkileri ayrılıyor.
5. Rastgele Meta nesne kimlikleri ile işlem yapılması: nesnenin seçilmiş reklam hesabına ait olduğu kontrol ediliyor.
6. Rapor yanıtında ham tenant tokenlarının bulunması: public tenant dönüşümü ve response sanitization kimlik bilgilerini çıkarıyor.
7. CRM güncellemesinde `tenantId` / `id` değiştirebilme: yalnızca izinli lead alanları güncelleniyor; durum ve değer doğrulanıyor, aktör bilgili audit korunuyor.
8. Meta kuruş birimindeki bütçenin tekrar TL gibi çarpılması: finansal hesaplamalar TL olarak yapılıyor, Graph yazımında bir kez minor unit dönüşümü uygulanıyor.
9. Minimum harcama oluşmadan 12 saatlik değerlendirmenin tamamlandı sayılması: minimum harcama beklenirken tekrar değerlendirme olanağı korunuyor.
10. Elle durdurulmuş reklamın otomatik yeniden açılması: otomatik yeniden açma yalnızca otomasyonun kendi durdurduğu kayıt üzerinden; sonraki manuel durum değişikliği bu izni kaldırıyor.
11. Aynı paylaşımın manuel ve scheduler üzerinden iki kez yayınlanabilmesi: tenant kilidi, kalıcı yayın aşaması, kalıcı Instagram container kimliği ve belirsiz sonuç uzlaştırması eklendi.
12. Herhangi bir tenantın `publish-due` ile sistem hesabının kuyruğunu çalıştırması: uç nokta çağıranın tenantına bağlı.
13. Bozuk JSON okunduğunda dosyanın boş başlangıç değeriyle ezilmesi: bozuk veri korunuyor ve hata veriliyor; yazımlar geçici dosya + rename ile atomik.

## Bu son inceleme turunda eklenenler

### Gerçek kampanya stratejisi

`POST /api/product/strategy` artık gerçek Gemini Interactions yanıtından yapılandırılmış bir kampanya test önerisi üretir. İşletme/sektör, kullanıcının seçtiği test bütçesi ve konum, tenantın kendi kaydedilmiş içerik bilgisi, gerçek son 7 günlük rapor ve tenant Hafıza Sarayı bağlamı birlikte kullanılır.

Bu uç nokta Meta reklamı oluşturmaz, reklam durumunu değiştirmez, bütçe yazmaz veya Instagram yayını yapmaz. Dönüş her zaman `requiresApproval: true`, `created: false`, `published: false` içerir. Gemini yapılandırılmamış veya yanıt doğrulanamamışsa `available: false`, `source: UNAVAILABLE`, `strategy: null` döner; sahte AI stratejisi üretilmez.

İstek alanları:

- `businessName`, `industry`, `dailyBudget`, `title`: isteğe bağlı; mevcut onboarding bilgileri kullanılabilir. Geçerli işletme adı, sektör ve pozitif test bütçesi gerekli.
- `postId`: yalnızca aynı tenantın kaydedilmiş içeriği kabul edilir.
- `instagramMediaId`: yalnızca bağlı hesabın erişilebilir gönderi listesinde doğrulanan içerik kabul edilir.
- `locationMode`: `COUNTRY`, `CITY` veya `REGION`; `locations` gerçek şehir/bölge listesiyle doğrulanır. Bu tercihler kalıcı ayarları değiştirmez.

Başarılı dönüşte `strategy` alanları:

- `goal`: WhatsApp mesajı.
- `audience`: `locationMode`, `locations`, açıklama.
- `budget`: günlük TL önerisi, para birimi ve kayıtlı hesap günlük tavanı. Model önerisi kullanıcı bütçesi, reklam grubu tavanı ve mevcut hesap tavanıyla sınırlandırılır.
- `creative`: başlık, `POST` / `REELS` / `CAROUSEL`, içerik açısı.
- `hook`, `schedule` (`HH:mm`, timezone ve neden), 3–14 günlük test süresi, gerekçeler ve uyarılar.
- `evidence`: raporun gerçekten alınmış olup olmadığı, dönem, hafıza outcome sayısı ve seçili post kimliği.

Sağlık yanıtında `capabilities.campaignStrategy: true` eklenmiştir. Provider modeli ayrı `model` alanındadır; içerikteki ürün model adıyla karıştırılmaz. Başarılı öneri güvenli audit kaydına yazılır; ölçülmüş reklam sonucu gibi Hafıza Sarayı'na işlenmez.

### Gemini performans güvenliği

- Aynı WhatsApp konuşma sonucunu temsil eden Meta action aliasları Gemini reklam değerlendirmesinde de iki kez sayılmaz. Böylece CPA yanlışlıkla yarıya inmez.
- Başarısız insight isteği sıfır performans olarak gösterilmez: `metricsAvailable: false` ve `null` metrikler taşınır.
- Otomatik Gemini aksiyonu; yeterli güven, gerçek metrik ve minimum harcama olmadan uygulanmaz. Kullanıcının bilinçli manuel kararı ayrı kalır.

### Aynı dış reklam hesabına bağlı iki tenant için kilit

İki tenantın aynı Meta reklam hesabını yetkilendirmesi mümkündür. Tenant kilidi tek başına dış hesaptaki ortak bütçe için yeterli değildi. İzole testte iki reklam grubunun toplamı 200 TL, hesap tavanı 220 TL iken eşzamanlı artışların 230 TL'ye çıkabildiği tekrar üretildi.

Finansal Meta işlemlerine iç hesap kilidi eklendi: `withAdAccountLock`. Mevcut tenant kilitleri korunuyor; farklı dış hesaplar birbirini bekletmiyor. HTTP reklam oluşturma/durum/bütçe/karar uygulama, optimizer, haftalık otomasyon ve Gemini karar uygulaması aynı Meta hesap kilidini kullanıyor. Aynı regresyon testi artık toplam bütçeyi 220 TL içinde tutuyor.

### Yayın kaydının korunması ve video MIME uyumluluğu

- Backend PATCH/queue/cover/DELETE yolları `PUBLISHING`, `RECONCILE`, `publishAmbiguous` veya `SUBMITTING` kaydını 409 ile korur. Yayınlanmış içerik de bu yerel düzenleme/silme akışından korunur; paylaşım kanıtı ve uzlaştırma kaydı kaybedilmez.
- Reddedilen cover yüklemeleri temizlenir; mevcut medya ve kayıt değişmez. Taslak silme gerçek dosya bulunmayan kayıtlar için de güvenli çalışır.
- `publish-due` HTTP yolu artık açıkça oturumun tenantını gönderir; başka tenantın veya system kuyruğu çalıştırılmaz.
- Tarayıcıların `video/quicktime`, `video/x-msvideo`, `video/x-m4v` MIME aliasları Gemini için sırasıyla `video/mov`, `video/avi`, `video/mp4` olarak normalleştirilir. Inline ve Files API input yolları test edildi; desteklenmeyen formatlar dönüştürülmüş gibi gösterilmez. [Gemini video belgeleri](https://ai.google.dev/gemini-api/docs/video-understanding) bu canonical formatları desteklenen listede belirtir.

## Desteklenen ürün API'ları

- `/health`: sürüm, API sürümü ve gerçek destek capability haritası.
- `/api/product/overview`: gerçek bugünkü harcama, aktif reklamlar, mesaj ve CPA; 7 günlük trend; içerikler, leadler, audit logları, kalıcı bildirimler, hafıza, onboarding ve güvenli oturum özeti.
- `/api/product/report`: bugün, dün, 7/14/30 gün veya doğrulanmış özel tarih aralığı. Meta verisi alınamazsa ölçülmemiş metrikler `null` ve `available: false` kalır.
- `/api/product/onboarding` GET/PUT: işletme, sektör, hedef, şehir/bölge, bütçe, adım ve tamamlama. Yarım bırakılan adım ve `updatedAt` korunur; varlık bağlantısı tamamlanmadan gerçek tamamlanmış kurulum gösterilmez.
- `/api/product/strategy`: yukarıda açıklanan Gemini önerisi.
- `/api/meta/connect/start`, `/api/meta/assets`, `/api/meta/select`, callback, health/status/disconnect: sunucu tarafı OAuth ve yetkilendirilmiş Page/Instagram/Ad Account seçimi.
- Mevcut kampanya, reklam grubu, reklam, Instagram medya, içerik oluşturma/analiz, görsel/dosya/video analizi, varyant, kreatif skor, hafıza, kuyruk/yayınlama, CRM, alert, UTM, takım, plan/lisans ve Super Admin yolları korunuyor.

AI Daily Brief gerçek veriye dayanan kural özeti olduğunu `REAL_DATA_RULE_ENGINE` kaynağıyla açıklar; Gemini tarafından üretilmiş gibi sunulmaz. Proaktif öneriler gerçek bağlantı/kurulum/yayın/lead/performance durumlarından türetilir.

## Yayınlama ve otomasyon sınırları

- Instagram container kimliği paylaşım gönderilmeden önce kaydedilir. Network sonucu belirsizse `RECONCILE` durumu oluşur; kör biçimde yeni container oluşturulup tekrar yayınlanmaz.
- Aynı post için eşzamanlı ve tekrarlanan publish testinde bir adet dış `media_publish` çağrısı yapıldı.
- `PUBLISHING` ve `RECONCILE` içerikler, yayımlanmış içerikler gibi backend üzerinde düzenleme/yeniden kuyruğa alma/kapak değişikliği/silme akışından korunur; istemci bu durumları anlaşılır gösterir.
- Otomatik bütçe/aktivasyon için hesap günlük tavanı gerekli. Tavan, bu uygulamanın günlük planlanmış reklam grubu bütçesi sınırıdır; Meta harcama garantisi veya ayrı Meta hesap spending cap ayarı değildir.
- TRY dışında veya kampanya bütçesi/lifetime bütçesi kullanılan hesaplarda mevcut otomatik bütçe yolu güvenli şekilde işlemi reddeder. Bunlar destekleniyor gibi gösterilmez.
- Bütçe guard ve uygulama kilidi, AdVise içindeki işlemleri koordine eder. Meta Ads Manager veya başka bir uygulamanın eşzamanlı değişikliklerini kilitleyemez; gerçek performans ve bütçe yeniden okunur, ancak dış servis eventual consistency ve network sonucu sınırları geçerlidir.
- OAuth doğrulaması, app review/Advanced Access, WhatsApp Business/Page ilişkisi ve hesap yetkileri gerçek Meta hesabında tamamlanmalıdır. Credential veya business verification gereksinimleri uydurulmadı.

## Veri formatı / migration

SQL migration yok; PostgreSQL'e otomatik aktarım yapılmadı. Production JSON dosyalarına bu çalışma sırasında migration uygulanmadı.

V16 kaynakta kullanılan additive alanlar:

- Tenant: onboarding bilgileri; geçici OAuth nonce/kullanıcı/varlık seçimi bilgileri; Instagram API türü.
- Ayarlar: ortak günlük hesap tavanı (`geminiAdsDailyCap`) ve Gemini otomasyon tercihi.
- İçerik: Instagram container kimliği, yayın aşaması/başlama zamanı, yayın denemeleri ve doğrulama durumu.
- Alert: kaynak event kimliği; aynı gerçek event için bildirim tekrarı önlenir.
- Audit: aktör kimliği ve işlem kaynağı.
- Hafıza v2: hook türü ve sektöre uygun örnek seçimi; mevcut generation/outcome/pattern kayıtları korunur.

JSON normalizasyonu yeni alanlara başlangıç değerleri verir; yeni kurulumda gereken dosyalar oluşturulabilir. Hafıza legacy sürüm uyarlaması mevcut kod yolunda yapılır. Atomik dosya yazımı ve kilitler, çok dosyalı bir veritabanı transaction'ı değildir. Büyük tenant sayısı, geri kazanılabilir transaction ve yüksek erişilebilirlik için gerçek veri katmanı ayrı bir sonraki projedir.

## Doğrulama sonuçları

### İzole test suite

`npm test`: **38 test / 38 başarılı**.

Üretimden tamamen ayrı `mkdtemp` dizinleri, sentetik oturum/hesap değerleri, kapalı cron ve mock Meta/Gemini taşıması kullanıldı. Testler gerçek Meta bütçesi veya yayını değiştirmedi. Başlıca kanıtlar:

- Tenant fallback, Meta nesne sahipliği, role/tenant admin sınırları ve auth/callback erişimi.
- TL/minor unit, günlük cap, pasif reklam aktivasyonu ve elle durdurulmuş reklam koruması.
- Tenant paralelliği ve aynı dış hesaba bağlı farklı tenantların finansal seri çalışması.
- Bozuk JSON'un korunması, atomik yazım ve paralel tenant post/log kayıtları.
- CRM kimlik/tenant alanlarının korunması ve gerçek aktör audit kaydı.
- Mesaj action aliaslarının deduplikasyonu; eksik metrik/minimum harcama güvenliği.
- Kalıcı container ile tekrarsız publish; belirsiz sonucu uzlaştırma.
- Gerçek HTTP ile yayın durum koruması, reddedilmiş cover upload temizliği ve tenant dışı publish-due çalıştırmama.
- Geçerli sentetik AVI RIFF/frame/index tutarlılığı ve Gemini inline/uploaded video MIME alias normalizasyonu.
- Haftalık başlatma gate'i; açık başarısızlık sonrası güvenli yeniden deneme ve belirsiz başlatmanın engellenmesi.
- Onboarding devam etme, gerçek olmayan tamamlanmayı engelleme, ölçülmemiş hafıza kazananı üretmeme, sektöre göre hafıza örneği seçimi.
- Strateji şeması, limitli bütçe, provider/source bilgisi, bozuk model yanıtında sahte öneri üretmeme, yalnızca tenantın medya/hafıza bağlamı ve sıfır dış Meta write.

### Gerçek Gemini görsel + hafıza smoke

`node test/gemini-smoke.mjs`: **başarılı**. Bu opt-in komut `npm test` kapsamına dahil değildir; normal sunucu yapılandırmasını kullanır, yalnızca yeni temp data/upload dizini ile çalışır ve temp dizinini siler.

Müşteri görseli kullanılmadı: repodaki `mobile/assets/advise_logo.jpg` ile gerçek multimodal istek gönderildi.

- `[AI GEMINI INTERACTIONS REQUEST]`: `hasMedia: true`.
- `gemini-3.8-flash` ve `gemini-3.7-flash`: kota/hız sınırı kategorisi; ilgili modelde ek denemeye girilmeden mevcut fallback izlendi.
- `gemini-3.5-flash-lite`: `status: completed`, `hasOutput: true`.
- Sonuç: `source: GEMINI`, provider modeli `gemini-3.5-flash-lite`, görsel özeti ve caption mevcut.
- Temp `ai_memory.json` içinde generation gerçekten saklandı: `generationCount: 1`, kayıt source `GEMINI`, model `gemini-3.5-flash-lite`.
- API key, JWT, Meta token veya ham provider yanıtı gösterilmedi. Production verisi ve Meta hesabı değişmedi.

Bu kanıt Gemini entegrasyonunun mevcut erişimle fallback modeli üzerinden çalıştığını gösterir. Birincil iki modelin kota sınırı hizmet sağlayıcı tarafındadır; sınırsız veya sürekli birincil model erişimi iddia edilmez. Canlı kampanya stratejisi yanıtı ayrıca gerçek hesapta çağrılmadı; şema/normalizasyon/tenant bağlamı kontrollü provider testleriyle doğrulandı.

### Gerçek provider ile sentetik video smoke

`node test/gemini-smoke.mjs --video`: **başarılı**. Sistemde FFmpeg bulunmadığından bağımlılık kurulmadan mevcut JPEG logodan geçerli MJPEG/RIFF AVI test fixture'ı oluşturuldu: 150×150 piksel, 10 FPS, 20 kare, 2 saniye, 70.152 byte, sessiz ve sabit logo. Frame/header/index tutarlılığı izole birim testinde doğrulandı. [Microsoft AVI RIFF referansı](https://learn.microsoft.com/en-us/windows/win32/directshow/avi-riff-file-reference) dosya yapısının kaynağıdır.

- İlk 15 saniyelik kontrollü smoke'da lite timeout oldu; `LOCAL_FALLBACK_AFTER_AI_ERROR` sonuç başarı sayılmadı, generation saklanmadı.
- Bir kez 45 saniyelik sınırla tekrarlandı. Üst iki modelde kota/hız sınırı; lite modelinde `status: completed`, `hasOutput: true`.
- Sonuç `source: GEMINI`, provider modeli `gemini-3.5-flash-lite`; görsel özeti ve caption mevcut.
- İzole `ai_memory.json` generation kaydı gerçekten saklandı: `generationCount: 1`, `source: GEMINI`, model `gemini-3.5-flash-lite`.
- Müşteri videosu, production upload'u veya Meta hesabı kullanılmadı. Yeni paket kurulmadı, ana uygulamaya video üretici eklenmedi; yalnızca opt-in test fixture yardımcı dosyası var.

Bu gerçek provider video input/çıktı/hafıza akışını doğrular. Hareketli/sesli müşteri videosu, uzun klip ve 20 MB üstü gerçek Files API upload benchmark'ı değildir. Üretim request varsayılanı zaten 60 saniye, explicit yapılandırma korunuyor; istemci AI media HTTP sınırı 450 saniye. Production timeout değiştirilmedi.

### Syntax, lock ve dependency audit

- Backend kaynak ve test dosyalarına `node --check`: başarılı.
- `package.json`, root lock sürümü ve lock package manifest: `16.0.0`; dependency tanımları eşit. Multer lock sürümü `2.4.0`.
- Değişikliklerde `git diff --check`: başarılı.
- `npm audit --audit-level=high`: exit 0; **0 high, 0 critical**.
- Audit'te **2 moderate** kayıt kalıyor: `node-cron` → `uuid` transitive advisory [GHSA-w5hq-g745-h8pq](https://github.com/advisories/GHSA-w5hq-g745-h8pq). Düzeltme npm tarafından `node-cron 4.6.0` major geçişi olarak sunuluyor. Çalışan scheduler mimarisine force upgrade yapılmadı; sürüm geçişi ayrı uyumluluk testi gerektirir.

## Halen tamamlanmamış / dış bağımlı özellikler

- Gerçek Meta reklam oluşturma, bütçe değiştirme ve Instagram yayını production hesabında smoke edilmedi; bu işlemler harcama/yayın etkisi yaratır.
- Gerçek OAuth consent ve varlık seçimi hesabın Meta app izinleriyle canlı uçtan uca onaylanmalı.
- CRM manuel ve kayıtlı attribution alanlarını destekliyor; Meta Lead Ads / WhatsApp webhook otomatik lead toplama altyapısı yok.
- Manuel lisans aboneliği var; gerçek ödeme/cüzdan/iyzico tahsilat altyapısı yok. Tahmini paket bedeli tahsilat kanıtı değildir.
- Alert / in-app bildirim var; gerçek push veya e-posta gönderimi yok.
- UTM üretimi var; harici satın alma/ROAS attribution bağlantısı ve gerçek A/B deney dağıtımı tamamlanmış değil.
- Google Ads/TikTok entegrasyonu yok; çalışan sahte endpoint eklenmedi.
- Gerçek medya kütüphanesi kaydedilmiş upload/post kayıtlarına dayanır; Instagram'ın her arşiv içeriği veya harici dosya sistemi katalogu değildir.
- Tam audit geçmişi için mevcut log retention sınırının ötesinde arşiv/export gereklidir.
- JSON dosya mimarisi, veri yedeği ve kurtarma/transaction altyapısı commercial scale için geliştirilmelidir.

## Production'a geçiş için gerekenler

Backend kaynakların mevcut sunucuya alınması ve onaylı runtime yenilemesi gerekiyor. Yeni istemci capability haritası V16 route'larının gerçekten sunulup sunulmadığını kontrol eder. APK/PWA/Windows güncellemesi tek başına eski çalışan Node sürecine yeni route eklemez.

Deployment sırasında eski aynı data klasörünü kullanan süreçler de değerlendirilmelidir; eski kod yeni dosya/tenant/hesap kilitlerini tanımaz. Veri yedeği, tek geçerli aktif runtime ve health/capability doğrulaması yayın planının parçası olmalıdır. Bu görevde bunlar production üzerinde uygulanmadı. Cloudflare DNS/route/secret değişikliği kendiliğinden gerekli ilan edilmedi; mevcut tunnel/API yayını ayrı onaylı deployment adımında korunur.

## Sonraki öncelikler

**Kritik:** onaylı V16 runtime rollout ve gerçek health/capability kontrolü; production yedek/kurtarma düzeni; gerçek OAuth/Meta/WhatsApp business yetkilerinin doğrulanması.

**Önemli:** hareketli/sesli ve büyük dosya video ölçümü; node-cron 4/uuid uyumluluk güncellemesi; webhook kaynaklı CRM attribution; kalıcı transaction veri katmanı; canlı strateji/kampanya onay akışının ölçümü.

**Daha sonra:** gerçek billing sağlayıcısı; cross-channel entegrasyonlar; uzun dönem audit arşivi ve ticari rapor export'ları.
