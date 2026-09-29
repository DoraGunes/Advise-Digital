ADVISE DIGITAL - REPAIR PACKAGE

Bu paket iki sorunu hedefler:
1) backend/package.json eksikligi nedeniyle npm start ENOENT
2) mobile/lib altinda eski/uyumsuz Dart dosyalari yuzunden toplu analyzer hatalari

Kullanım:
- Bu klasoru zipten çıkar.
- Icindeki REPAIR_EXISTING_PROJECT.ps1 dosyasini PowerShell ile çalıştır.
- Script mevcut C:\Users\ANL\Desktop\meta projesinde degistirdigi dosyaları once yedekler.
- Sonra backend package.json'i geri koyar ve mobile/lib + assets + pubspec.yaml'i temiz V13 kaynakla degistirir.

Ardından:
cd C:\Users\ANL\Desktop\meta\backend
npm.cmd start

ve ayri PowerShell:
cd C:\Users\ANL\Desktop\meta\mobile
flutter pub get
flutter analyze
flutter run

Guncel Meta ayarlari (secret/token içermez):
App ID: 29337308309220358
Configuration ID: 1665669755072632
Business Portfolio ID: 2327995664603987
Ad Account ID: 1627930699026624
Page ID: sonradan girilecek
Instagram ID: sonradan girilecek
