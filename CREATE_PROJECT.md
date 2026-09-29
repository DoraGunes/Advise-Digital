# Temiz Flutter projesi oluşturma

Bu ZIP'te Flutter'ın sürüme bağlı `android/`, `ios/`, Gradle ve wrapper dosyalarını sabitlemedim.

En temiz yol:

```bash
flutter create mobile
```

Sonra ZIP'teki:
```text
mobile/pubspec.yaml
mobile/lib/
```
dosyalarını yeni oluşan `mobile` klasörünün üzerine koy.

Ardından:

```bash
cd mobile
flutter pub get
flutter run
```

AndroidManifest için `mobile/android/AndroidManifest.additions.xml` içindeki INTERNET iznini ekle.

Gerçek telefonda backend bilgisayarında çalışıyorsa:
```text
http://BILGISAYARIN_IP_ADRESI:3000
```

Android emülatörde:
```text
http://10.0.2.2:3000
```
