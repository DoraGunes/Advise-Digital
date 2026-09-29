# AdVise AI V14 – AI + Akıllı Yayın Paketi

## Eklenen çekirdek özellikler

- AI İçerik Stüdyosu: caption + hook + CTA + hashtag + format önerisi.
- AI yoksa güvenli yerel fallback; OPENAI_API_KEY verilirse Responses API üzerinden model çağrısı.
- Fotoğraf otomatik `POST`, video otomatik `REELS` olarak sınıflandırılır.
- Gerçek Instagram yayın katmanı görüntü/video için ayrı çalışır.
- Meta reklam tokenı ile Instagram tokenı birbirinden ayrıldı.
- Otomatik yayın başarısızlıklarında sınırlı retry/backoff eklendi.
- Aynı dosyanın tekrar yüklenmesini SHA-256 hash ile engelleme.
- İçerik kuyruğunda AI metadata ve medya tipi tutulur.
- Uygulama adı görünür alanlarda `AdVise AI` olarak güncellendi.

## İsteğe bağlı AI yapılandırması

Backend `.env` içine kendi anahtarınla:

```env
OPENAI_API_KEY=...
OPENAI_MODEL=gpt-5.6-luna
PUBLISH_MAX_RETRIES=3
PUBLISH_RETRY_MINUTES=10
```

Anahtar APK içine gömülmez; yalnızca backend tarafında tutulur.

## Windows'ta test/build

```powershell
cd backend
npm.cmd install
npm.cmd start

cd ..\mobile
flutter clean
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

> Otomatik Instagram yayınında `PUBLIC_BASE_URL` HTTPS olmalıdır.
