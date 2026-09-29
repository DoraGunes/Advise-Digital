# Advise Digital V12 Final kapsamı

## UI / UX
- Advise Software logosu ve `Advise Digital` markası korunur.
- Ana Sayfa butonu ikincil ekranlarda bulunur.
- V7 + V8 kontrol merkezi tek hub'da toplandı.
- Analytics, AI Insights, Billing, Commercial Center, Notifications, Branding, Security, Meta/Instagram, Customers, Licenses ve Diagnostics ekranları bulunur.
- FAB ile yeni müşteri ve lisans oluşturma.
- Arama, düzenleme, aktif/pasif, süre uzatma, şifre sıfırlama, kalıcı silme.

## API / backend
- 3001 portu.
- 0.0.0.0 dinleme.
- 404 veren V7/V8 uçları mevcut.
- Tenant bazlı müşteri, içerik, kullanıcı ve log izolasyonu.
- Müşteri silmede cascade temizleme + upload dosyalarının kaldırılması.
- OAuth start/callback/disconnect/status.
- Meta API fonksiyonları tenant credentials ile çalışabilir; system tenant global `.env` fallback kullanır.
- Tenant bağlıysa dashboard, insight, status, budget ve scheduler tenant Meta hesabına yönlenir.
- Scheduler bağlı tüm aktif tenant'ları dolaşır.

## Reklam motoru
- 12 saatlik erken karar.
- Hedef mesaj maliyeti.
- Minimum veri eşiği.
- Kötü reklamı PAUSED etme.
- Serbest gelecek günlük bütçe kapasitesini iyi performanslı ad set'e yönlendirme.
- Geçmiş saat verisi ile planlama.

## Operasyon
- `BUILD_ADVISE_DIGITAL_APK.ps1`
- `OPEN_PORT_3001_ADMIN.ps1`
- Android cleartext + INTERNET ayarlarını yeniden uygulayan `BRANDING_FIX.ps1`.
- Widget smoke test yeniden oluşturulur.

## Bilinen son entegrasyon bağımlılıkları
- Meta OAuth için kendi Meta Developer App ID/Secret + kayıtlı redirect URI gerekir.
- Canlı Meta yetkileri Meta hesabının/uygulamanın durumuna bağlıdır.
- Online ödeme gerçek sağlayıcı seçilmeden aktive edilmemiştir; billing/lisans altyapısı hazırdır.
- PostgreSQL şeması ve health altyapısı hazırdır; yerel fallback JSON'dur.
