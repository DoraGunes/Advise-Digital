# Advise Digital V12 Ultimate Final

Advise Digital; Meta/Instagram reklam yönetimi, 12 saatlik erken karar motoru, müşteri/abonelik/lisans yönetimi ve SaaS yönetim ekranlarını tek üründe toplar.

## İçerik
- `backend/` Node.js + Express API
- `mobile/` Flutter Android uygulaması
- `backend/database/schema.sql` PostgreSQL için üretim şeması
- `advise-digital-reklam-karar-modeli.xlsx` karar modeli
- `advise-digital-post-saat-modeli.xlsx` saat öğrenme modeli
- `BUILD_ADVISE_DIGITAL_APK.ps1` tek komutla Android hazırlama + analyze + test + release build
- `OPEN_PORT_3001_ADMIN.ps1` telefonun PC backend'ine ulaşamadığı durum için Windows Firewall kuralı

## İlk kurulum
Backend:
```powershell
cd backend
npm.cmd install
npm.cmd start
```

Telefon için backend adresi:
`http://192.168.1.61:3001`

Telefon ve PC aynı ağda olmalı.

APK için proje kökünden:
```powershell
powershell -ExecutionPolicy Bypass -File .\\BUILD_ADVISE_DIGITAL_APK.ps1
```

İstersen manuel:
```powershell
cd mobile
flutter create --project-name advise_digital .
powershell -ExecutionPolicy Bypass -File .\\BRANDING_FIX.ps1
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Varsayılan sistem yöneticisi
`.env` içindeki `ADMIN_USERNAME` ve `ADMIN_PASSWORD` değerleri kullanılır. Üretimde bunları mutlaka değiştir.

## Meta / Instagram
Uygulamada tenant bazlı Meta & Instagram bağlantı ekranı ve OAuth başlangıç/callback akışı vardır. Gerçek bağlantı için Meta Developer uygulamasının App ID/Secret/Redirect URI değerleri backend `.env` içine konur. Redirect URI, Meta uygulamasında kayıtlı URI ile birebir aynı olmalıdır. Yerel LAN adresi üretim OAuth callback'i olarak düşünülmemelidir.

OAuth ile alınan token backend tarafında tenant kaydına yazılır ve mobil API cevaplarında token değeri açığa çıkarılmaz. Canlı reklam yönetimi, Meta hesabı ve uygulama izinlerinin gerçekten verilmiş olmasına bağlıdır.

## Reklam otomasyonu
- İçerik yükleme
- Haftalık bütçe
- En uygun saat seçimi için geçmiş loglardan puanlama
- İlk 12 saatlik erken değerlendirme
- Mesaj maliyeti hedefi
- Kötü performanslı reklamı durdurma
- Gelecek günlük bütçe kapasitesini daha iyi performanslı ad sete yönlendirme
- Manuel Karar Merkezi
- Tenant bazlı otomasyon

## SaaS
- Super Admin
- Müşteri oluştur/düzenle/pasife al/aktif et/süre uzat/sil
- Müşteri şifresi sıfırlama
- Kullanıcı ve rol yönetimi
- BASIC / PRO / AGENCY / ENTERPRISE
- Lisans üret/ata
- White Label temel alanları
- Bildirim tercihleri
- Billing özeti
- Analitik
- AI içgörüsü (kural tabanlı)
- Güvenlik görünümü
- Sistem tanılama

## Güvenlik / üretim notu
Yerel geliştirmede JSON fallback kullanılır. Ticari üretimde HTTPS, PostgreSQL, güçlü secret yönetimi, token encryption/secret store, rate limiting, yedekleme ve izleme servisi eklenmelidir. Bu paket bu geçiş için şema ve DB health temelini içerir; JSON verisini otomatik olarak PostgreSQL'e taşıyan migration servisi henüz burada çalıştırılmıyor.


## Meta OAuth entegrasyonu

Facebook Login for Business Configuration ID, App ID ve callback ayarları `META_CONNECTION_NOW.md` içinde güncel örneklerle bulunur. App Secret pakete dahil değildir.
