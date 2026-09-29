# Advise Digital V6 — Windows hızlı kurulum

## Backend
```powershell
cd backend
npm.cmd install
npm.cmd start
```

Backend:
```text
http://localhost:3001/health
```

## Flutter / Android
`mobile` klasöründe bir kez:
```powershell
flutter create --project-name advise_digital .
powershell -ExecutionPolicy Bypass -File .\BRANDING_FIX.ps1
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

## Telefon bağlantısı
Telefon ve bilgisayar aynı Wi‑Fi üzerinde olmalı. Bu paket mevcut test bilgisayarının LAN adresini kullanır:
```text
http://192.168.1.61:3001
```

PC IP adresi değişirse uygulamada:
**Bağlantı Ayarları → Backend URL**
alanından yeni adresi gir.

Windows Firewall gerekiyorsa Yönetici PowerShell:
```powershell
New-NetFirewallRule -DisplayName "Advise Digital 3001" -Direction Inbound -Protocol TCP -LocalPort 3001 -Action Allow
```
