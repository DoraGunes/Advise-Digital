Android klasoru Flutter surumune gore yeniden olusturuluyor.

ONEMLI MARKALAMA:
1) Bu klasorde ilk kez:
   flutter create --project-name advise_digital .
2) Ardindan mobile klasorunden:
   powershell -ExecutionPolicy Bypass -File .\BRANDING_FIX.ps1
3) Sonra:
   flutter pub get
   flutter analyze
   flutter build apk --release

BRANDING_FIX.ps1 sunlari garanti eder:
- Uygulama gorunen adi: Advise Digital
- Eski proje adı kullanılmaz
- Launcher ikonu: kullanicinin verdigi Advise Software logosu

Android emulatorde backend adresi:
http://10.0.2.2:3001

Gercek telefonda bilgisayarin LAN IP adresini kullan.
Yerel HTTP gelistirmesi gerekiyorsa AndroidManifest.xml icindeki application'a
android:usesCleartextTraffic="true"
eklenmelidir.
