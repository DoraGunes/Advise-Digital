# Advise Digital V12 Ultimate Final

Bu paket V7+V8 üzerine V9-V12 kapsamındaki ürünleşme katmanlarını tek sürümde toplar.

## Bilgisayar
1. `backend` klasörünü aç.
2. `npm.cmd install`
3. `npm.cmd start`
4. Backend 3001 portunda çalışır.

Kolay başlatma: `START_ADVISE_DIGITAL_3001.bat`

## Telefon
Telefon ve PC aynı Wi-Fi'da olmalı. Advise Digital -> Bağlantı ayarları:
`http://192.168.1.61:3001`

## Flutter
`mobile` klasöründe:
```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Meta / Instagram bağlantısı
Uygulamaya gerçek OAuth akışı eklendi. Çalışması için backend `.env` içine Meta uygulama bilgileri verilmelidir:
- `META_APP_ID`
- `META_APP_SECRET`
- `META_REDIRECT_URI`
- `META_OAUTH_SCOPES`

`META_REDIRECT_URI` Meta uygulamasındaki OAuth callback URL ile birebir aynı olmalıdır. Yerel `http://192.168...` URL'si, Meta'nın gerektirdiği üretim HTTPS callback senaryosunun yerini tutmaz.

Şirket doğrulaması veya Meta tarafındaki izin/review henüz tamamlanmadıysa Meta bağlantısı ekranının hazır olması gerçek yetki verildiği anlamına gelmez.

## Güvenlik
Access tokenlar APK içine gömülmez. OAuth ile alınan token backend tenant verisinde tutulur ve API yanıtlarında maskelenir. Üretimde HTTPS + PostgreSQL + güçlü secret + güvenli secret store kullanılmalıdır.
