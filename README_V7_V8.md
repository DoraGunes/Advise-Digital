# Advise Digital V7 + V8 Ultimate

Bu paket, V6 tabanını tek arşivde V7 teknik ürünleşme ve V8 ticari ürünleşme katmanlarıyla genişletir.

## V7
- Multi-tenant veri modeli ve rol tabanı korunur.
- Tenant bazlı ayarlar, marka ve bildirim tercihleri.
- Analitik özet ekranı.
- Güvenlik/altyapı görünümü.
- Sistem runtime ve veritabanı sağlık kontrolü.
- PostgreSQL için `backend/database/schema.sql` ve opsiyonel `DATABASE_URL` hazırlığı.

## V8
- BASIC / PRO / AGENCY / ENTERPRISE paket kataloğu.
- Ticari merkez ve tahmini MRR görünümü.
- Abonelik özeti.
- Lisans sistemi (mevcut V6 akışı üzerine).
- White-label temel ayarları: ad, logo URL, renk, destek e-postası.
- Bildirim tercihleri.
- Kural tabanlı AI içgörü ekranı.
- Super Admin için V7+V8 kontrol merkezi.

## Önemli
Bu paket gerçek ödeme sağlayıcısı, gerçek Meta OAuth multi-account onboarding veya üretim PostgreSQL migrasyonunu otomatik olarak tamamlamaz; bunlar sağlayıcı/hesap bilgilerine bağlı son entegrasyonlardır. Canlı ödeme bağlanmadan V8 ticari merkezde fiyatlar sadece katalog değeridir. AI içgörüleri şimdilik `RULE_BASED` modundadır.

## Mobil
Backend varsayılan port: `3001`.
Gerçek telefonda örnek: `http://192.168.1.61:3001`

## İlk kurulum
```powershell
cd mobile
flutter pub get
flutter analyze
flutter test
flutter build apk --release
```

Backend:
```powershell
cd backend
npm.cmd install
npm.cmd start
```

İsteğe bağlı PostgreSQL:
1. `DATABASE_URL` ve `DB_SSL` değerlerini `.env` içine gir.
2. `backend/database/schema.sql` dosyasını veritabanında çalıştır.
3. `/api/system/health` ile bağlantıyı kontrol et.
