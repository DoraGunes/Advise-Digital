abstract interface class UserFacingFailure {
  String get userMessage;
}

/// User-facing errors are kept separate from diagnostics and upstream payloads.
class AppError {
  AppError._();

  static String normalize(Object? error, {int? statusCode}) =>
      message(error, statusCode: statusCode);

  static String message(Object? error, {int? statusCode}) {
    if (error is UserFacingFailure) return error.userMessage;
    final raw = error?.toString().trim() ?? '';
    final lower = raw.toLowerCase();
    if (lower.contains('kullanıcı adı veya şifre') ||
        lower.contains('yanlış parola') ||
        lower.contains('invalid credentials')) {
      return 'Kullanıcı adı veya şifre hatalı. Tekrar deneyin.';
    }
    if (lower.contains('abonelik') &&
        (lower.contains('dol') || lower.contains('expired'))) {
      return 'Aboneliğinizin süresi dolmuş. Hesap yöneticinizle iletişime geçin.';
    }
    if (lower.contains('pasif') || lower.contains('inactive account')) {
      return 'Hesabınız pasif. Hesap yöneticinizle iletişime geçin.';
    }
    if ((lower.contains('meta') || lower.contains('oauth')) &&
        (lower.contains('expired') ||
            lower.contains('süre') ||
            lower.contains('token') ||
            lower.contains('190'))) {
      return 'Meta bağlantınızın süresi dolmuş. Bağlantılar ekranından yeniden bağlayın.';
    }
    if (statusCode == 401) {
      return 'Oturumunuz sona erdi. Lütfen yeniden giriş yapın.';
    }
    if (statusCode == 403) {
      return 'Bu işlem için yetkiniz bulunmuyor.';
    }
    if (statusCode == 404) {
      return 'Bu özellik sunucuda henüz hazır değil. Uygulama ve sunucu sürümleri kontrol edilmeli.';
    }
    if (statusCode == 409) {
      return 'İşlem zaten yapılıyor veya kayıt değişmiş. Ekranı yenileyip tekrar deneyin.';
    }
    if (statusCode == 413) {
      return 'Dosya çok büyük. Daha küçük bir fotoğraf veya video seçin.';
    }
    if (statusCode == 429 ||
        lower.contains('quota') ||
        lower.contains('resource_exhausted') ||
        lower.contains('rate limit')) {
      return 'Hizmet kullanım sınırına ulaştı. Bir süre sonra tekrar deneyin.';
    }
    if (lower.contains('timeout') || lower.contains('zaman aşım')) {
      return 'İşlem beklenenden uzun sürdü. Bağlantınızı kontrol edip tekrar deneyin.';
    }
    if (lower.contains('socketexception') ||
        lower.contains('clientexception') ||
        lower.contains('failed to fetch') ||
        lower.contains('connection') ||
        lower.contains('bağlantı') ||
        lower.contains('ulaşılam') ||
        lower.contains('network')) {
      return 'Sunucuya ulaşılamıyor. İnternet bağlantınızı kontrol edip tekrar deneyin.';
    }
    if (statusCode != null && statusCode >= 500) {
      return 'Hizmet şu anda yanıt veremiyor. Bir süre sonra tekrar deneyin.';
    }
    // Never reflect a stack, HTML, raw JSON, URL, credential, or English
    // infrastructure message in a screen or snack bar.
    final unsafe = raw.isEmpty ||
        raw.length > 220 ||
        RegExp(r'[{}<>]|https?://|\n|\r').hasMatch(raw) ||
        RegExp(r'exception|stack|bearer|jwt|token|secret|api.?key|access.?key|password|\.env|sql|error:|http\s*\d',
                caseSensitive: false)
            .hasMatch(raw);
    final readableTurkish = RegExp(
      r'[çğıöşüÇĞİÖŞÜ]|gerekli|bulunamad|seç|kayded|yüklen|geçersiz|içerik|reklam|dosya|işlem|sunucu',
      caseSensitive: false,
    ).hasMatch(raw);
    if (!unsafe && readableTurkish) return raw;
    return 'İşlem tamamlanamadı. Ekranı yenileyip tekrar deneyin.';
  }
}
