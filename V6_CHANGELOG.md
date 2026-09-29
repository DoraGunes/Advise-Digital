# Advise Digital V6 — Ultimate UI / SaaS polish

Bu sürüm V5 SaaS iskeletinin üzerine kullanıcı deneyimi ve operasyon katmanını genişletir.

## Mobil uygulama
- Yenilenmiş dashboard: KPI kartları, durum şeritleri, hızlı işlemler, kural özeti ve aktivite akışı.
- Sistem yöneticisi kontrol merkezi: müşteri, lisans, abonelik, karar merkezi ve sistem ayarları.
- Müşteri dashboardu: içerik, otomasyon, bütçe, karar merkezi ve ekip yönetimi.
- İçerik yönetimi: otomatik planlama seçeneği, yayın durumu, silme ve yayınlama isteği.
- Reklam Karar Merkezi: Meta bağlı olduğunda reklamı inceleme, durdurma/aktifleştirme ve ad set günlük bütçesi değiştirme.
- Ayrıntılı otomasyon ayarları: 12 saatlik pencere, maliyet hedefi, minimum harcama, bütçe sınırları, yayın planı.
- Ekip kullanıcıları: oluşturma, pasife alma/aktifleştirme, şifre sıfırlama.
- Hesap: kendi şifresini güvenli şekilde değiştirme.
- Bağlantı ayarları: backend URL'si + sağlık testi.
- Yardım/kullanım rehberi.
- Çok noktada “Powered by Advise Digital” markalaması.
- Advise Software logosu ve Advise Digital adı korunur.

## Backend
- Port 3001 / LAN erişimi korunur.
- Kullanıcı CRUD-lite ve ekip erişimi endpoint'leri.
- Kendi şifresini değiştirme endpoint'i.
- Ad set bütçesi değiştirme endpoint'i.
- Post otomatik planlama alanı API'ye bağlandı.
- Health sürümü 6.0.0 olarak güncellendi.

## Üretim notu
Bu sürüm ürünleşmiş bir MVP/operasyon panelidir. Gerçek ticari SaaS için sonraki altyapı adımları PostgreSQL, HTTPS, secret manager, müşteri bazlı Meta OAuth, ödeme sağlayıcısı ve merkezi web Super Admin panelidir.
