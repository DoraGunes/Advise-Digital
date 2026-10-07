import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'media_access.dart' show MediaAccess;
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:shared_preferences/shared_preferences.dart';

import 'app_error.dart';
import 'config.dart';

class ApiException implements Exception, UserFacingFailure {
  final int? statusCode;
  final String message;
  final String? details;
  final String? code;
  final String? stage;
  final String? correlationId;
  final bool retryable;
  const ApiException(this.message,
      {this.statusCode,
      this.details,
      this.code,
      this.stage,
      this.correlationId,
      this.retryable = false});
  @override
  String get userMessage {
    const known = {
      'META_SESSION_EXPIRED':
          'Meta bağlantısının süresi dolmuş. Bağlantılar ekranından yeniden bağlayın.',
      'META_PERMISSION_DENIED':
          'Meta reklam hesabı ve Sayfa yetkilerini kontrol edin.',
      'META_RATE_LIMIT':
          'Meta işlem sınırına ulaştı. Biraz sonra yeniden deneyin.',
      'META_ACCOUNT_RESTRICTED':
          'Meta reklam hesabı kısıtlı veya etkin değil. Hesap durumunu kontrol edin.',
      'META_ACCOUNT_MISMATCH':
          'Reklam hesabını Bağlantılar ekranından yeniden seçin.',
      'META_WHATSAPP_MISSING':
          'Önce Meta Sayfanıza WhatsApp numaranızı bağlayın.',
      'META_INSTAGRAM_MISMATCH':
          'Sayfaya bağlı Instagram hesabını yeniden seçin.',
      'META_ASSETS_MISSING': 'Önce Sayfa ve Instagram hesabınızı bağlayın.',
      'META_PAGE_UNAVAILABLE':
          'Meta Sayfanızın erişimini ve yayın durumunu kontrol edin.',
      'META_PREFLIGHT_UNAVAILABLE':
          'Meta hesap bilgileri doğrulanamadı. Bağlantıyı kontrol edin.',
      'META_CURRENCY_UNSUPPORTED':
          'Bu reklam akışı TRY para birimindeki hesapları destekliyor.',
      'META_REJECTED':
          'Meta isteği kabul etmedi. Hesap, hedefleme ve WhatsApp bağlantısını kontrol edin.',
      'AD_RECONCILE_REQUIRED':
          'Meta sonucu belirsiz. Yeniden reklam oluşturmadan önce mevcut işlemi kontrol edin.',
      'IDEMPOTENCY_CONFLICT':
          'Reklam isteği değişmiş. Önce mevcut işlemin durumunu kontrol edin.',
      'OPERATION_BUSY':
          'Bu hesapta başka bir işlem devam ediyor. Biraz sonra yeniden deneyin.',
      'ETIMEDOUT':
          'İşlem zamanında tamamlanamadı. Mevcut işlem durumunu kontrol edip yeniden deneyin.',
      'AD_CREATE_FAILED':
          'Reklam isteği tamamlanamadı. Hesap ve bağlantı ayarlarını kontrol edin.',
      'AD_LIMIT_REACHED': 'Paketinizin reklam limitine ulaşıldı.',
      'META_MEDIA_MISMATCH':
          'Seçilen Instagram gönderisi bağlı hesaba ait değil.',
      'REQUEST_ID_REQUIRED':
          'Güvenli reklam oluşturma için uygulamayı güncelleyin.',
      'COVER_EMPTY': 'Kapak dosyası okunamadı veya boş.',
      'COVER_TOO_LARGE': 'Kapak görseli en fazla 10 MB olabilir.',
      'COVER_UNSUPPORTED': 'Reels kapağı JPEG, PNG veya WebP olmalı.',
      'COVER_CORRUPT':
          'Kapak görseli açılamadı veya bozuk. Başka bir görsel seçin.',
      'COVER_UPLOAD_FAILED':
          'Kapak yüklenemedi. Dosyayı yeniden seçip deneyin.',
    };
    final safe = known[code];
    if (safe != null) {
      const stages = {
        'preflight': 'bağlantı kontrolü',
        'campaign': 'kampanya',
        'adset': 'reklam seti',
        'creative': 'kreatif',
        'ad': 'reklam',
        'activation': 'etkinleştirme',
        'strategy': 'AI önerisi',
        'lock': 'hesap kilidi'
      };
      final label = stages[stage];
      return label == null ? safe : '$safe (Adım: $label)';
    }
    return AppError.message(message, statusCode: statusCode);
  }

  @override
  String toString() => userMessage;
}

class Api {
  static const String _tokenKey = 'authToken';
  static const String _baseUrlKey = 'apiBaseUrl';
  static String? _sessionToken;
  static http.Client _client = http.Client();
  static Map<String, dynamic>? _cachedCompatibility;
  static DateTime? _compatibilityCheckedAt;
  static final ValueNotifier<bool> authExpired = ValueNotifier<bool>(false);

  @visibleForTesting
  static void setHttpClientForTesting(http.Client? client) {
    _client = client ?? http.Client();
  }

  @visibleForTesting
  static void resetRuntimeForTesting() {
    _runtimeBaseUrl = null;
    _sessionToken = null;
    _clearCompatibility();
    authExpired.value = false;
  }

  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();
  static String _cleanBaseUrl(String value) =>
      value.trim().replaceFirst(RegExp(r'/+$'), '');

  static String? _runtimeBaseUrl;

  static Future<String> baseUrl() async {
    if (_runtimeBaseUrl != null) return _runtimeBaseUrl!;
    final prefs = await _prefs();
    final saved = prefs.getString(_baseUrlKey) ?? '';
    _runtimeBaseUrl = _validBaseUrl(saved)
        ? _cleanBaseUrl(saved)
        : _cleanBaseUrl(AppConfig.defaultApiBaseUrl);
    return _runtimeBaseUrl!;
  }

  static bool _validBaseUrl(String value) {
    final uri = Uri.tryParse(value.trim());
    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty &&
        uri.userInfo.isEmpty &&
        !uri.hasQuery &&
        !uri.hasFragment;
  }

  static Future<void> setBaseUrl(String value) async {
    final v = _cleanBaseUrl(value);
    if (!_validBaseUrl(v)) {
      throw const ApiException(
          'Backend URL http:// veya https:// ile başlamalı.');
    }
    final previous = Uri.tryParse(await baseUrl());
    final next = Uri.tryParse(v);
    final previousOrigin = previous != null &&
            (previous.scheme == 'http' || previous.scheme == 'https') &&
            previous.host.isNotEmpty
        ? previous.origin
        : null;
    if (previousOrigin == null ||
        next == null ||
        previousOrigin != next.origin) {
      // A session belongs to its API origin. Never carry a bearer token to
      // another host, scheme or non-default port when configuration changes.
      await logout();
    }
    final prefs = await _prefs();
    await prefs.setString(_baseUrlKey, v);
    _runtimeBaseUrl = v;
    _clearCompatibility();
  }

  static Future<void> setToken(String token, {bool remember = true}) async {
    _sessionToken = token;
    authExpired.value = false;
    final prefs = await _prefs();
    if (remember) {
      await prefs.setString(_tokenKey, token);
    } else {
      await prefs.remove(_tokenKey);
    }
  }

  static Future<String> token() async {
    if (_sessionToken != null) return _sessionToken!;
    final prefs = await _prefs();
    _sessionToken = prefs.getString(_tokenKey) ?? '';
    return _sessionToken!;
  }

  static Future<void> logout() async {
    _sessionToken = '';
    authExpired.value = false;
    final prefs = await _prefs();
    await prefs.remove(_tokenKey);
    _clearCompatibility();
  }

  static dynamic _decode(String body) {
    if (body.trim().isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(body);
    } catch (_) {
      return <String, dynamic>{'raw': body};
    }
  }

  static String _error(dynamic data) {
    if (data is Map) {
      final error = data['error'] ?? data['message'] ?? data['detail'];
      if (error != null) return error.toString();
    }
    return 'İstek başarısız.';
  }

  static Uri _uri(String base, String path, Map<String, String>? query) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$cleanPath');
    return query == null || query.isEmpty
        ? uri
        : uri.replace(queryParameters: query);
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retry = true,
    bool includeAuth = true,
    Duration? timeout,
  }) async {
    final base = await baseUrl();
    final uri = _uri(base, path, query);
    final authToken = await token();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (includeAuth && authToken.isNotEmpty)
      headers['Authorization'] = 'Bearer $authToken';

    try {
      late final http.Response response;
      final encodedBody = jsonEncode(body ?? <String, dynamic>{});
      switch (method.toUpperCase()) {
        case 'GET':
          response = await _client
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: headers, body: encodedBody)
              .timeout(timeout ?? const Duration(seconds: 90));
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 40));
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 40));
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 30));
          break;
        default:
          throw const ApiException('Desteklenmeyen HTTP metodu.');
      }
      final data = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) return data;
      if (retry &&
          method.toUpperCase() == 'GET' &&
          const {502, 503, 504}.contains(response.statusCode)) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return await _request(method, path,
            body: body, query: query, retry: false, includeAuth: includeAuth);
      }
      if (includeAuth && authToken.isNotEmpty && response.statusCode == 401) {
        authExpired.value = true;
      }
      throw ApiException(_error(data),
          statusCode: response.statusCode,
          code: data is Map ? data['code']?.toString() : null,
          stage: data is Map ? data['stage']?.toString() : null,
          correlationId: data is Map ? data['correlationId']?.toString() : null,
          retryable: data is Map && data['retryable'] == true);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Sunucu zaman aşımına uğradı.');
    } on http.ClientException catch (e) {
      throw ApiException('HTTP bağlantı hatası.', details: e.message);
    } catch (_) {
      throw const ApiException('İşlem tamamlanamadı. Tekrar deneyin.');
    }
  }

  static Future<bool> health() async {
    try {
      final base = await baseUrl();
      final response = await _client
          .get(_uri(base, '/health', null))
          .timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  @visibleForTesting
  static Map<String, dynamic> compatibilityFromHealth(
      Map<String, dynamic> data) {
    final version = data['version']?.toString() ?? '';
    final major = int.tryParse(version.split('.').first) ?? 0;
    final capabilities = data['capabilities'] is Map
        ? Map<String, dynamic>.from(data['capabilities'] as Map)
        : <String, dynamic>{};
    final ok = data['ok'] == true;
    final compatible =
        ok && major >= 16 && capabilities['productExperience'] == true;
    return {
      ...data,
      'ok': ok,
      'version': version,
      'capabilities': capabilities,
      'compatible': compatible,
      'message': !ok
          ? 'Sunucuya ulaşılamıyor. İnternet bağlantınızı kontrol edin.'
          : compatible
              ? ''
              : 'Sunucu güncellemesi bekleniyor. Yeni ürün ekranları bu sunucu sürümünde henüz kullanılamıyor.',
    };
  }

  static Future<Map<String, dynamic>> compatibility() async {
    try {
      final base = await baseUrl();
      final response = await _client
          .get(_uri(base, '/health', null))
          .timeout(const Duration(seconds: 8));
      final data = _decode(response.body);
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          data is Map) {
        return _rememberCompatibility(
            compatibilityFromHealth(Map<String, dynamic>.from(data)));
      }
    } catch (_) {}
    return _rememberCompatibility(compatibilityFromHealth({'ok': false}));
  }

  static void _clearCompatibility() {
    _cachedCompatibility = null;
    _compatibilityCheckedAt = null;
  }

  static Map<String, dynamic> _rememberCompatibility(
      Map<String, dynamic> data) {
    _cachedCompatibility = data;
    _compatibilityCheckedAt = DateTime.now();
    return Map<String, dynamic>.from(data);
  }

  static Future<void> _requireCapability(String capability,
      {required String feature}) async {
    final cachedAt = _compatibilityCheckedAt;
    final cached = _cachedCompatibility;
    final result = cached != null &&
            cachedAt != null &&
            DateTime.now().difference(cachedAt) < const Duration(seconds: 60)
        ? cached
        : await compatibility();
    if (result['ok'] != true) {
      throw const ApiException(
          'Sunucuya ulaşılamıyor. İnternet bağlantınızı kontrol edin.');
    }
    final capabilities = result['capabilities'];
    if (result['compatible'] != true ||
        capabilities is! Map ||
        capabilities[capability] != true) {
      throw ApiException('$feature için sunucu güncellemesi gerekiyor. '
          'Diğer çalışma alanlarını kullanmaya devam edebilirsiniz.');
    }
  }

  static Future<Map<String, dynamic>> productOverview() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/product/overview'));

  static Future<Map<String, dynamic>> productStrategy(
      Map<String, dynamic> values) async {
    await _requireCapability('campaignStrategy',
        feature: 'AI kampanya önerisi');
    return Map<String, dynamic>.from(await _request(
        'POST', '/api/product/strategy',
        body: values, timeout: const Duration(seconds: 65)));
  }

  static Future<Map<String, dynamic>> productReport(
          {String range = '7d', String? since, String? until}) async =>
      Map<String, dynamic>.from(
          await _request('GET', '/api/product/report', query: {
        'range': range,
        if (since != null && since.isNotEmpty) 'since': since,
        if (until != null && until.isNotEmpty) 'until': until,
      }));

  static Future<Map<String, dynamic>> productOnboarding() async =>
      Map<String, dynamic>.from(
          await _request('GET', '/api/product/onboarding'));

  static Future<Map<String, dynamic>> saveProductOnboarding(
          Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(
          await _request('PUT', '/api/product/onboarding', body: values));

  static Future<http.MultipartFile> _mediaPart(String field, String path,
      {XFile? file}) async {
    try {
      final selected = file ?? XFile(path);
      final filename = selected.name
          .split(RegExp(r'[/\\]'))
          .last
          .replaceAll(RegExp(r'[\x00-\x1f]'), '');
      return http.MultipartFile.fromBytes(field, await selected.readAsBytes(),
          filename: filename.isEmpty ? 'media.jpg' : filename);
    } catch (_) {
      throw const ApiException(
          'Seçilen dosya okunamadı. Dosyayı yeniden seçin.');
    }
  }

  static void _checkUploadResponse(
      http.Response response, dynamic data, String authToken) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    if (response.statusCode == 401 && authToken.isNotEmpty) {
      authExpired.value = true;
    }
    throw ApiException(_error(data),
        statusCode: response.statusCode,
        code: data is Map ? data['code']?.toString() : null);
  }

  static Future<Map<String, dynamic>> login(String username, String password,
      {bool remember = true}) async {
    final prefs = await _prefs();
    await prefs.remove(_tokenKey);
    _sessionToken = '';
    authExpired.value = false;
    final data = await _request(
      'POST',
      '/api/auth/login',
      body: {'username': username.trim(), 'password': password},
      includeAuth: false,
    );
    if (data is! Map)
      throw const ApiException('Sunucudan geçersiz giriş cevabı geldi.');
    final tokenValue = data['token']?.toString() ?? '';
    if (tokenValue.isEmpty)
      throw ApiException(data['error']?.toString() ?? 'Giriş yapılamadı.');
    await setToken(tokenValue, remember: remember);
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> me() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/me'));
  static Future<Map<String, dynamic>> dashboard() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/dashboard'));
  static Future<List<dynamic>> campaigns() async => List<dynamic>.from(
      (await _request('GET', '/api/campaigns'))['data'] ?? const []);
  static Future<List<dynamic>> adsets() async {
    final data = await _request('GET', '/api/adsets');
    if (data is! Map) return <dynamic>[];
    return List<dynamic>.from(data['data'] ?? const []);
  }

  static Future<List<dynamic>> ads() async {
    final data = await _request('GET', '/api/ads');
    if (data is! Map) return <dynamic>[];
    return List<dynamic>.from(data['data'] ?? const []);
  }

  static Future<List<dynamic>> instagramMedia({int limit = 50}) async =>
      List<dynamic>.from((await _request(
              'GET', '/api/instagram/media?limit=$limit'))['data'] ??
          const []);

  static Future<Map<String, dynamic>> adTargetingOptions() async =>
      Map<String, dynamic>.from(
          await _request('GET', '/api/ads/targeting-options'));
  static Future<Map<String, dynamic>> saveAdTargetingPreferences({
    required String mode,
    required List<String> locations,
  }) async =>
      Map<String, dynamic>.from(await _request(
        'PUT',
        '/api/ads/targeting-preferences',
        body: {'mode': mode, 'locations': locations},
      ));

  static Future<Map<String, dynamic>> createAdFromInstagramPost({
    required String instagramMediaId,
    required String campaignName,
    required String adSetName,
    required String adName,
    required double dailyBudget,
    bool activate = false,
    required String requestId,
    String locationMode = 'COUNTRY',
    List<String> locations = const [],
  }) async {
    await _requireCapability('adCreateSaga',
        feature: 'Güvenli reklam oluşturma');
    return Map<String, dynamic>.from(
        await _request('POST', '/api/ads/create', body: {
      'requestId': requestId,
      'instagramMediaId': instagramMediaId,
      'campaignName': campaignName,
      'adSetName': adSetName,
      'adName': adName,
      'dailyBudget': dailyBudget,
      'activate': activate,
      'locationMode': locationMode,
      'locations': locations,
    }));
  }

  static Future<Map<String, dynamic>> adsPreflight() async {
    await _requireCapability('adsPreflight', feature: 'Meta bağlantı kontrolü');
    return Map<String, dynamic>.from(
        await _request('GET', '/api/ads/preflight', retry: false));
  }

  static Future<Map<String, dynamic>> adOperation(String requestId) async =>
      Map<String, dynamic>.from(await _request(
          'GET', '/api/ads/operations/$requestId',
          retry: false));

  static Future<String> stableAdRequestId(String accountScope,
      Map<String, dynamic> payload, String candidate) async {
    if (accountScope.isEmpty)
      throw const ApiException(
          'Hesap bilgisi doğrulanamadı. Ekranı yenileyin.');
    final identity = jsonEncode([await baseUrl(), accountScope, payload]);
    final key = 'adCreateRequest:${base64Url.encode(utf8.encode(identity))}';
    final prefs = await _prefs();
    final stored = prefs.getString(key);
    if (stored != null) return stored;
    await prefs.setString(key, candidate);
    return candidate;
  }

  static Future<Map<String, dynamic>> insights(String id) async {
    final data = await _request('GET', '/api/insights/$id');
    if (data is! Map)
      throw const ApiException('Sunucudan geçersiz insight cevabı geldi.');
    return Map<String, dynamic>.from(data);
  }

  static Future<List<dynamic>> posts() async => List<dynamic>.from(
      (await _request('GET', '/api/posts'))['data'] ?? const []);
  static Future<Map<String, dynamic>> settings() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/settings'));
  static Future<Map<String, dynamic>> saveSettings(
          Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(
          await _request('PUT', '/api/settings', body: values));
  static Future<Map<String, dynamic>> runAutomation() async =>
      Map<String, dynamic>.from(await _request('POST', '/api/automation/run'));
  static Future<List<dynamic>> logs() async => List<dynamic>.from(
      (await _request('GET', '/api/logs'))['data'] ?? const []);
  static Future<void> status(String id, String statusValue) async =>
      await _request('POST', '/api/status/$id', body: {'status': statusValue});
  static Future<void> updateAdSetBudget(String id, double dailyBudget) async =>
      await _request('POST', '/api/budget/$id',
          body: {'dailyBudget': dailyBudget});
  static Future<Map<String, dynamic>> geminiAdReview() async {
    await _requireCapability('geminiAdReview',
        feature: 'Gemini reklam analizi');
    return Map<String, dynamic>.from(
        await _request('POST', '/api/ads/gemini-review'));
  }

  static Future<Map<String, dynamic>> applyGeminiAdDecision(
      {required String adSetId, required String action}) async {
    await _requireCapability('safeAutomationV16',
        feature: 'Gemini reklam kararlarını uygulamak');
    return Map<String, dynamic>.from(
        await _request('POST', '/api/ads/gemini-apply', body: {
      'adSetId': adSetId,
      'action': action,
    }));
  }

  static Future<void> deletePost(String id) async =>
      await _request('DELETE', '/api/posts/$id');
  static Future<Map<String, dynamic>> updatePost(String id,
          {required String title,
          required String caption,
          String linkUrl = ''}) async =>
      Map<String, dynamic>.from(
          await _request('PATCH', '/api/posts/$id', body: {
        'title': title,
        'caption': caption,
        'linkUrl': linkUrl,
      }));
  static Future<Map<String, dynamic>> queuePost(String id,
      {String scheduleAt = ''}) async {
    if (scheduleAt.isNotEmpty) {
      await _requireCapability('scheduledPublishing',
          feature: 'Saat seçerek planlama');
    }
    return Map<String, dynamic>.from(await _request(
        'POST', '/api/posts/$id/queue',
        body: scheduleAt.isEmpty ? {} : {'scheduleAt': scheduleAt}));
  }

  static Future<List<dynamic>> reorderQueuedPosts(List<String> postIds) async =>
      List<dynamic>.from((await _request('POST', '/api/posts/reorder',
              body: {'postIds': postIds}))['data'] ??
          const []);
  static Future<Map<String, dynamic>> publishPost(String id) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/posts/$id/publish'));
  static Future<List<dynamic>> users() async => List<dynamic>.from(
      (await _request('GET', '/api/users'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createUser(
          {required String username,
          required String password,
          String fullName = '',
          String role = 'OPERATOR'}) async =>
      Map<String, dynamic>.from(await _request('POST', '/api/users', body: {
        'username': username,
        'password': password,
        'fullName': fullName,
        'role': role
      }));
  static Future<void> toggleUser(String id) async =>
      await _request('POST', '/api/users/$id/toggle');
  static Future<void> resetUserPassword(String id, String password) async =>
      await _request('POST', '/api/users/$id/reset-password',
          body: {'password': password});
  static Future<void> changePassword(
          String currentPassword, String newPassword) async =>
      await _request('POST', '/api/profile/password', body: {
        'currentPassword': currentPassword,
        'newPassword': newPassword
      });
  static Future<Map<String, dynamic>> analyticsSummary() async =>
      Map<String, dynamic>.from(
          await _request('GET', '/api/analytics/summary'));
  static Future<Map<String, dynamic>> aiInsights() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/ai/insights'));
  static Future<Map<String, dynamic>> billing() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/billing'));
  static Future<Map<String, dynamic>> branding() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/branding'));
  static Future<Map<String, dynamic>> saveBranding(
          Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(
          await _request('PUT', '/api/branding', body: values));
  static Future<Map<String, dynamic>> notificationPrefs() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/notifications'));
  static Future<Map<String, dynamic>> saveNotificationPrefs(
          Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(
          await _request('PUT', '/api/notifications', body: values));
  static Future<Map<String, dynamic>> securityOverview() async =>
      Map<String, dynamic>.from(
          await _request('GET', '/api/security/overview'));
  static Future<Map<String, dynamic>> systemHealth() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/system/health'));
  static Future<Map<String, dynamic>> adminOverview() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/admin/overview'));
  static Future<List<dynamic>> adminPlans() async => List<dynamic>.from(
      (await _request('GET', '/api/admin/plans'))['data'] ?? const []);
  static Future<Map<String, dynamic>> adminRuntime() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/admin/runtime'));

  static Future<Map<String, dynamic>> uploadPost(
      String path, String title, String caption, String linkUrl,
      {bool autoPublish = true,
      bool useAI = true,
      XFile? mediaFile,
      String scheduleAt = '',
      String mediaType = 'AUTO',
      String aiContext = '',
      String memoryGenerationId = ''}) async {
    if (scheduleAt.isNotEmpty) {
      await _requireCapability('scheduledPublishing',
          feature: 'Saat seçerek planlama');
    }
    final base = await baseUrl();
    final authToken = await token();
    final request =
        http.MultipartRequest('POST', _uri(base, '/api/posts', null));
    request.headers['Accept'] = 'application/json';
    if (authToken.isNotEmpty)
      request.headers['Authorization'] = 'Bearer $authToken';
    request.fields['title'] = title.trim();
    request.fields['caption'] = caption.trim();
    request.fields['linkUrl'] = linkUrl.trim();
    request.fields['autoPublish'] = autoPublish.toString();
    request.fields['useAI'] = useAI.toString();
    request.fields['mediaType'] = mediaType;
    request.fields['aiContext'] = aiContext;
    if (scheduleAt.isNotEmpty) request.fields['scheduleAt'] = scheduleAt;
    if (memoryGenerationId.trim().isNotEmpty)
      request.fields['memoryGenerationId'] = memoryGenerationId.trim();
    request.files.add(await _mediaPart('image', path, file: mediaFile));
    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 450));
      final data = _decode(response.body);
      _checkUploadResponse(response, data, authToken);
      return Map<String, dynamic>.from(data as Map);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Dosya yükleme zaman aşımına uğradı.');
    } on http.ClientException catch (e) {
      throw ApiException('Dosya yükleme bağlantı hatası.', details: e.message);
    } catch (_) {
      throw const ApiException('Dosya yüklenemedi. Tekrar deneyin.');
    }
  }

  static Future<Map<String, dynamic>> uploadPostsBulk(
    List<String> paths, {
    bool autoPublish = true,
    bool useAI = true,
    String aiContext = '',
    List<XFile>? mediaFiles,
  }) async {
    if (paths.isEmpty && (mediaFiles == null || mediaFiles.isEmpty)) {
      throw const ApiException('En az bir dosya seçmelisin.');
    }
    final base = await baseUrl();
    final authToken = await token();
    final request =
        http.MultipartRequest('POST', _uri(base, '/api/posts/bulk', null));
    request.headers['Accept'] = 'application/json';
    if (authToken.isNotEmpty)
      request.headers['Authorization'] = 'Bearer $authToken';
    request.fields['autoPublish'] = autoPublish.toString();
    request.fields['useAI'] = useAI.toString();
    request.fields['aiContext'] = aiContext.trim();
    final files = mediaFiles ?? paths.map((path) => XFile(path)).toList();
    for (final file in files) {
      request.files.add(await _mediaPart('files', file.path, file: file));
    }
    try {
      final streamed =
          await _client.send(request).timeout(const Duration(seconds: 180));
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response.body);
      _checkUploadResponse(response, data, authToken);
      return Map<String, dynamic>.from(data as Map);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Toplu içerik yükleme zaman aşımına uğradı.');
    } on http.ClientException catch (e) {
      throw ApiException('Toplu içerik yükleme bağlantı hatası.',
          details: e.message);
    } catch (_) {
      throw const ApiException('İçerikler yüklenemedi. Tekrar deneyin.');
    }
  }

  static Future<Map<String, dynamic>> uploadPostCover(
      String postId, String path,
      {XFile? mediaFile}) async {
    final base = await baseUrl();
    final authToken = await token();
    final request = http.MultipartRequest(
        'POST', _uri(base, '/api/posts/$postId/cover', null));
    request.headers['Accept'] = 'application/json';
    if (authToken.isNotEmpty)
      request.headers['Authorization'] = 'Bearer $authToken';
    try {
      final selected = mediaFile ?? XFile(path);
      late final List<int> bytes;
      try {
        if (await selected.length() > 10 * 1024 * 1024)
          throw const ApiException('Kapak görseli en fazla 10 MB olabilir.',
              code: 'COVER_TOO_LARGE');
        bytes = await selected.readAsBytes();
      } on ApiException {
        rethrow;
      } catch (_) {
        throw const ApiException('Kapak dosyası okunamadı. Yeniden seçin.');
      }
      final mime = MediaAccess.coverMime(Uint8List.fromList(bytes));
      if (mime == null)
        throw const ApiException('Reels kapağı JPEG, PNG veya WebP olmalı.',
            code: 'COVER_UNSUPPORTED');
      final extension =
          {'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp'}[mime];
      request.files.add(http.MultipartFile.fromBytes('cover', bytes,
          filename: 'cover.$extension', contentType: MediaType.parse(mime)));
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 60));
      final data = _decode(response.body);
      _checkUploadResponse(response, data, authToken);
      return Map<String, dynamic>.from(data as Map);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Kapak yükleme zaman aşımına uğradı.');
    } on http.ClientException catch (e) {
      throw ApiException('Kapak yükleme bağlantı hatası.', details: e.message);
    } catch (_) {
      throw const ApiException('Kapak yüklenemedi. Tekrar deneyin.');
    }
  }

  // Super Admin API
  static Future<void> deleteCustomer(String tenantId) async =>
      await _request('DELETE', '/api/admin/customers/$tenantId');
  static Future<Map<String, dynamic>> metaStatus() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/meta/status'));
  static Future<Map<String, dynamic>> metaHealth() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/meta/health'));
  static Future<Map<String, dynamic>> metaAssets() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/meta/assets'));
  static Future<Map<String, dynamic>> selectMetaAssets({
    required String pageId,
    required String adAccountId,
  }) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/meta/select', body: {
        'pageId': pageId,
        'adAccountId': adAccountId,
      }));
  static Future<Map<String, dynamic>> aiStatus() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/ai/status'));
  static Future<Map<String, dynamic>> aiMemory() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/ai/memory'));
  static Future<Map<String, dynamic>> generateCaptionVariants(
          {required String title,
          String context = '',
          String tone = '',
          String goal = '',
          String language = 'Türkçe',
          String mediaType = 'AUTO',
          String imageUrl = ''}) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/ai/caption-variants', body: {
        'title': title,
        'context': context,
        'tone': tone,
        'goal': goal,
        'language': language,
        'mediaType': mediaType,
        'imageUrl': imageUrl
      }));
  static Future<Map<String, dynamic>> scoreCreative(
          {String caption = '',
          String hook = '',
          String cta = '',
          List<dynamic> hashtags = const [],
          String mediaType = 'POST'}) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/ai/creative-score', body: {
        'caption': caption,
        'hook': hook,
        'cta': cta,
        'hashtags': hashtags,
        'mediaType': mediaType
      }));
  static Future<Map<String, dynamic>> generateContentPackFromFile(
    String path, {
    XFile? mediaFile,
    String title = '',
    String context = '',
    String tone = '',
    String goal = '',
    String language = 'Türkçe',
    String mediaType = 'AUTO',
  }) async {
    final base = await baseUrl();
    final authToken = await token();
    final request = http.MultipartRequest(
      'POST',
      _uri(base, '/api/ai/content-pack-from-file', null),
    );

    request.headers['Accept'] = 'application/json';
    if (authToken.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $authToken';
    }

    request.fields['title'] = title.trim();
    request.fields['context'] = context.trim();
    request.fields['tone'] = tone.trim();
    request.fields['goal'] = goal.trim();
    request.fields['language'] = language.trim();
    request.fields['mediaType'] = mediaType.trim();

    request.files.add(await _mediaPart('image', path, file: mediaFile));

    try {
      final response = await _client
          .send(request)
          .then(http.Response.fromStream)
          .timeout(const Duration(seconds: 450));
      final data = _decode(response.body);
      _checkUploadResponse(response, data, authToken);

      if (data is! Map) {
        throw const ApiException(
            'AI servisinden geçersiz içerik cevabı geldi.');
      }

      return Map<String, dynamic>.from(data);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('AI görsel analizi zaman aşımına uğradı.');
    } on http.ClientException catch (e) {
      throw ApiException('AI görsel analizi bağlantı hatası.',
          details: e.message);
    } catch (_) {
      throw const ApiException('AI analizi tamamlanamadı. Tekrar deneyin.');
    }
  }

  static Future<Map<String, dynamic>> generateContentPack(
          {required String title,
          String context = '',
          String tone = '',
          String goal = '',
          String language = 'Türkçe',
          String mediaType = 'AUTO',
          String imageUrl = ''}) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/ai/content-pack', body: {
        'title': title,
        'context': context,
        'tone': tone,
        'goal': goal,
        'language': language,
        'mediaType': mediaType,
        'imageUrl': imageUrl
      }));
  static Future<Map<String, dynamic>> generateCaption(
          {required String title,
          String context = '',
          String tone = '',
          String goal = '',
          String language = 'Türkçe',
          String mediaType = 'AUTO',
          String imageUrl = ''}) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/ai/caption', body: {
        'title': title,
        'context': context,
        'tone': tone,
        'goal': goal,
        'language': language,
        'mediaType': mediaType,
        'imageUrl': imageUrl
      }));
  static Future<Map<String, dynamic>> metaConnectStart() async =>
      Map<String, dynamic>.from(
          await _request('GET', '/api/meta/connect/start'));
  static Future<void> metaDisconnect() async =>
      await _request('POST', '/api/meta/disconnect');

  static Future<Map<String, dynamic>> adminStats() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/admin/stats'));
  static Future<List<dynamic>> adminCustomers() async => List<dynamic>.from(
      (await _request('GET', '/api/admin/customers'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createCustomer(
          {required String companyName,
          required String username,
          required String password,
          required String plan,
          required int days,
          String fullName = ''}) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/admin/customers', body: {
        'companyName': companyName,
        'username': username,
        'password': password,
        'plan': plan,
        'days': days,
        'fullName': fullName,
      }));
  static Future<Map<String, dynamic>> updateCustomer(
          String tenantId, Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(await _request(
          'PUT', '/api/admin/customers/$tenantId',
          body: values));
  static Future<Map<String, dynamic>> toggleCustomer(String tenantId) async =>
      Map<String, dynamic>.from(
          await _request('POST', '/api/admin/customers/$tenantId/toggle'));
  static Future<Map<String, dynamic>> extendCustomer(
          String tenantId, int days) async =>
      Map<String, dynamic>.from(await _request(
          'POST', '/api/admin/customers/$tenantId/extend',
          body: {'days': days}));
  static Future<Map<String, dynamic>> resetCustomerPassword(
          String tenantId, String password) async =>
      Map<String, dynamic>.from(await _request(
          'POST', '/api/admin/customers/$tenantId/reset-password',
          body: {'password': password}));
  static Future<List<dynamic>> licenses() async => List<dynamic>.from(
      (await _request('GET', '/api/admin/licenses'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createLicense(
          String plan, int days) async =>
      Map<String, dynamic>.from(await _request('POST', '/api/admin/licenses',
          body: {'plan': plan, 'days': days}));
  static Future<Map<String, dynamic>> assignLicense(
          String licenseId, String tenantId) async =>
      Map<String, dynamic>.from(await _request(
          'POST', '/api/admin/licenses/$licenseId/assign',
          body: {'tenantId': tenantId}));
  static Future<Map<String, dynamic>> proAi() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/pro/ai'));
  static Future<Map<String, dynamic>> proPerformance() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/pro/performance'));
  static Future<List<dynamic>> proAlerts() async => List<dynamic>.from(
      (await _request('GET', '/api/pro/alerts'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createAlert(
          String title, String body, String severity) async =>
      Map<String, dynamic>.from(await _request('POST', '/api/pro/alerts',
          body: {'title': title, 'body': body, 'severity': severity}));
  static Future<void> markAlert(String id) async =>
      await _request('POST', '/api/pro/alerts/$id/read');
  static Future<List<dynamic>> proLeads() async => List<dynamic>.from(
      (await _request('GET', '/api/pro/leads'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createLead(
          {required String name,
          String phone = '',
          String email = '',
          double value = 0,
          String status = 'NEW',
          String source = 'META',
          String notes = ''}) async =>
      Map<String, dynamic>.from(await _request('POST', '/api/pro/leads', body: {
        'name': name,
        'phone': phone,
        'email': email,
        'value': value,
        'status': status,
        'source': source,
        'notes': notes
      }));
  static Future<Map<String, dynamic>> updateLead(
          String id, Map<String, dynamic> values) async =>
      Map<String, dynamic>.from(
          await _request('PUT', '/api/pro/leads/$id', body: values));
  static Future<void> deleteLead(String id) async =>
      await _request('DELETE', '/api/pro/leads/$id');
  static Future<List<dynamic>> creatives() async => List<dynamic>.from(
      (await _request('GET', '/api/pro/creatives'))['data'] ?? const []);
  static Future<Map<String, dynamic>> analyzeCreative(
          {required String title,
          required String copy,
          required String type}) async =>
      Map<String, dynamic>.from(await _request(
          'POST', '/api/pro/creatives/analyze',
          body: {'title': title, 'copy': copy, 'type': type}));
  static Future<Map<String, dynamic>> simulateBudget(
          {required double totalBudget,
          required double reservePercent,
          required List<dynamic> items}) async =>
      Map<String, dynamic>.from(await _request(
          'POST', '/api/pro/budget/simulate', body: {
        'totalBudget': totalBudget,
        'reservePercent': reservePercent,
        'items': items
      }));
  static Future<List<dynamic>> experiments() async => List<dynamic>.from(
      (await _request('GET', '/api/pro/experiments'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createExperiment(
          {required String name,
          required double budget,
          required List<dynamic> variants}) async =>
      Map<String, dynamic>.from(await _request('POST', '/api/pro/experiments',
          body: {'name': name, 'budget': budget, 'variants': variants}));
  static Future<void> updateExperimentStatus(String id, String status) async =>
      await _request('POST', '/api/pro/experiments/$id/status',
          body: {'status': status});
  static Future<Map<String, dynamic>> buildUtm(
          {required String source,
          required String medium,
          required String campaign,
          required String content,
          String term = ''}) async =>
      Map<String, dynamic>.from(await _request('POST', '/api/pro/utm', body: {
        'source': source,
        'medium': medium,
        'campaign': campaign,
        'content': content,
        'term': term
      }));
  static Future<Map<String, dynamic>> proReport() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/pro/report'));
  static Future<Map<String, dynamic>> proAgency() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/pro/agency'));
}
