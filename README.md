# Advise Digital V12 Ultimate Final

Advise Digital; Meta/Instagram reklam yönetimi, 12 saatlik erken karar motoru, müşteri/abonelik/lisans yönetimi ve SaaS yönetim ekranlarını tek üründe toplar.

## İçerik
- `backend/` Node.js + Express API
- `mobile/` Flutter Android uygulaması
- `backend/database/schema.sql` PostgreSQL için üretim şeması
- `advise-digital-reklam-karar-modeli.xlsx` karar modeli
- `advise-digital-post-saat-modeli.xlsx` saat öğrenme modeli
- `BUILD_ADVISE_DIGITAL_APK.ps1` Android hazırlama + analyze + test + release build
- `OPEN_PORT_3001_ADMIN.ps1` Windows Firewall yardımcı betiği

## Güncel çalışma adresi

AdVise AI backend:
`http://localhost:3001`

Internet üzerinden AdVise API:
`https://advisedigital.poyrazteknikservis.com.tr`

Bu alan adı Cloudflare Tunnel üzerinden yerel `localhost:3001` servisine yönlendirilir. Windows'taki `cloudflared` servisi otomatik çalışacak şekilde kullanılabilir.

Poyraz Teknik backend ayrı olarak `localhost:3000` portunda çalışır ve aynı Cloudflare Tunnel üzerinden ayrı hostname ile yayınlanabilir.

## İlk kurulum

Backend:
```powershell
cd backend
npm.cmd install
npm.cmd start
```

APK için proje kökünden:
```powershell
powershell -ExecutionPolicy Bypass -File .\\BUILD_ADVISE_DIGITAL_APK.ps1
```

Manuel release build:
```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Varsayılan sistem yöneticisi

`.env` içindeki `ADMIN_USERNAME` ve `ADMIN_PASSWORD` değerleri kullanılır. Üretimde bunları mutlaka değiştir.

## Meta / Instagram

Uygulamada tenant bazlı Meta & Instagram bağlantı ekranı ve OAuth başlangıç/callback akışı vardır. Gerçek bağlantı için Meta Developer uygulamasının App ID/Secret/Redirect URI değerleri backend `.env` içine konur. Redirect URI, Meta uygulamasında kayıtlı URI ile birebir aynı olmalıdır.

Meta reklam işlemleri için `META_ACCESS_TOKEN`, Instagram içerik işlemleri için `INSTAGRAM_ACCESS_TOKEN` kullanılır. Token değerleri mobil uygulamaya gömülmemelidir.

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
- AI içgörüsü
- Güvenlik görünümü
- Sistem tanılama

## Güvenlik / üretim notu

`.env` dosyaları Git'e alınmaz. Üretimde HTTPS, PostgreSQL, güçlü secret yönetimi, token encryption/secret store, rate limiting, yedekleme ve izleme servisi eklenmelidir. JSON fallback geliştirme için tutulur.

## Meta OAuth entegrasyonu

Meta App ID, Configuration ID ve callback kurulum notları `META_CONNECTION_NOW.md` içindedir. App Secret pakete dahil değildir.
