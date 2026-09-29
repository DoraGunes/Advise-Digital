# Advise Digital – Meta bağlantısı

Hazır kimlikler:

- App ID: 29337308309220358
- Facebook Login for Business Configuration ID: 1593268158906523
- Business Portfolio: 3649761428513722
- Facebook Page: 1337059552826261
- Instagram: 17841419872324129
- Ad Account: act_1431244522269105
- Callback: https://wages-blocks-baking-coaches.trycloudflare.com/api/meta/oauth/callback

## App Secret

`backend/.env` içindeki `META_APP_SECRET=` satırının sonuna yaz. Ya da paket kökündeki `SET_META_SECRET.ps1` dosyasını çalıştır.

## Çalıştırma

Cloudflare Quick Tunnel açık kalmalı:

```powershell
cloudflared tunnel --url http://localhost:3001
```

Sonra backend:

```powershell
cd backend
npm.cmd start
```

Telefon backend adresi:

`http://192.168.1.61:3001`

> Not: Quick Tunnel adresi geçicidir. Yeni bir tunnel açılırsa Meta'daki callback URL ve `META_REDIRECT_URI` yeni adresle eşleştirilmelidir.
