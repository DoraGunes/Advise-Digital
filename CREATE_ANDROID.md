Flutter'ın Android klasörünü kendi sürümünle üretmesi daha sağlıklıdır.

Eğer `mobile/android` klasörünü oluşturmadıysan:

```bash
cd mobile
flutter create .
```

Sonra bu projedeki `lib/` ve `pubspec.yaml` dosyalarını koru ve
`android/app/src/main/AndroidManifest.xml` dosyasındaki INTERNET / cleartext değişikliğini uygula.

En temiz başlangıç:
```bash
flutter create mobile
```
ardından bu arşivdeki `mobile/lib`, `mobile/pubspec.yaml` ve manifest değişikliklerini üzerine kopyala.
