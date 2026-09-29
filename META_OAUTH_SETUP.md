# Advise Digital — Meta OAuth Kurulumu

Bu pakette yeni Meta bilgileri hazırlandı:

- App ID: 29337308309220358
- Facebook Login for Business Configuration ID: 1593268158906523
- Business Portfolio: 3649761428513722
- Facebook Page: 1337059552826261
- Instagram Professional Account: 17841419872324129
- Ad Account: 1431244522269105

## 1. App Secret

App Secret'ı sohbet içinde paylaşma.

Kolay yol: kökteki `SET_META_SECRET.ps1` dosyasını çalıştır:

```powershell
powershell -ExecutionPolicy Bypass -File .\SET_META_SECRET.ps1
```

Script senden Secret'ı ister ve `backend/.env` içine yazar. İstersen `.env` dosyasını elle de düzenleyebilirsin.

## 2. Callback

`backend/.env` içinde şu satır gerçek HTTPS adresin olmalı:

`META_REDIRECT_URI=https://SENIN-DOMAININ/api/meta/oauth/callback`

Bu URL Meta Developer içindeki **Geçerli OAuth Yönlendirme URI'ları** alanına birebir eklenmelidir.

`192.168.1.61:3001` yalnızca telefon-bilgisayar yerel bağlantısı için kullanılabilir; Meta callback'i için public HTTPS adresi kullanılmalıdır.

## 3. Backend

```powershell
cd backend
npm.cmd install
npm.cmd start
```

## 4. Telefon

Telefon bağlantısı yine:

`http://192.168.1.61:3001`

## 5. OAuth

Uygulamada **Meta & Instagram → META / INSTAGRAM BAĞLA** düğmesine bas. Backend, Facebook Login for Business Configuration ID'si ile OAuth URL'sini oluşturur. Callback tamamlanınca backend tenant'a token ve keşfedilen Page/Instagram/Ad Account bilgilerini kaydeder.

## Güvenlik

App Secret ve erişim tokenlarını APK içine koyma ve sohbet üzerinden paylaşma. Üretimde HTTPS kullan.
