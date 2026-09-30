import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'config.dart';

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? details;
  const ApiException(this.message, {this.statusCode, this.details});
  @override
  String toString() => statusCode == null ? message : 'HTTP $statusCode: $message';
}

class Api {
  static const String _tokenKey = 'authToken';
  static Future<SharedPreferences> _prefs() => SharedPreferences.getInstance();
  static String _cleanBaseUrl(String value) => value.trim().replaceFirst(RegExp(r'/+$'), '');

  static String? _runtimeBaseUrl;

  static Future<String> baseUrl() async {
    return _cleanBaseUrl(_runtimeBaseUrl ?? AppConfig.defaultApiBaseUrl);
  }

  static Future<void> setBaseUrl(String value) async {
    final v = _cleanBaseUrl(value);
    final uri = Uri.tryParse(v);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https') || uri.host.isEmpty) {
      throw const ApiException('Backend URL http:// veya https:// ile başlamalı.');
    }
    _runtimeBaseUrl = v;
  }

  static Future<void> setToken(String token) async {
    final prefs = await _prefs();
    await prefs.setString(_tokenKey, token);
  }

  static Future<String> token() async {
    final prefs = await _prefs();
    return prefs.getString(_tokenKey) ?? '';
  }

  static Future<void> logout() async {
    final prefs = await _prefs();
    await prefs.remove(_tokenKey);
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
      final error = data['error'] ?? data['message'] ?? data['detail'] ?? data['raw'];
      if (error != null) return error.toString();
    }
    return 'İstek başarısız.';
  }

  static Uri _uri(String base, String path, Map<String, String>? query) {
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$base$cleanPath');
    return query == null || query.isEmpty ? uri : uri.replace(queryParameters: query);
  }

  static Future<dynamic> _request(
    String method,
    String path, {
    Map<String, dynamic>? body,
    Map<String, String>? query,
    bool retry = true,
    bool includeAuth = true,
  }) async {
    final base = await baseUrl();
    final uri = _uri(base, path, query);
    final authToken = await token();
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (includeAuth && authToken.isNotEmpty) headers['Authorization'] = 'Bearer $authToken';

    try {
      late final http.Response response;
      final encodedBody = jsonEncode(body ?? <String, dynamic>{});
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(const Duration(seconds: 20));
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 40));
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encodedBody).timeout(const Duration(seconds: 40));
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(const Duration(seconds: 30));
          break;
        default:
          throw const ApiException('Desteklenmeyen HTTP metodu.');
      }
      final data = _decode(response.body);
      if (response.statusCode >= 200 && response.statusCode < 300) return data;
      if (retry && const {502, 503, 504}.contains(response.statusCode)) {
        await Future<void>.delayed(const Duration(milliseconds: 800));
        return await _request(method, path, body: body, query: query, retry: false, includeAuth: includeAuth);
      }
      throw ApiException(_error(data), statusCode: response.statusCode, details: response.body);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Sunucu zaman aşımına uğradı.');
    } on SocketException catch (e) {
      throw ApiException('Backend bağlantısı kurulamadı.', details: e.message);
    } on http.ClientException catch (e) {
      throw ApiException('HTTP bağlantı hatası.', details: e.message);
    }
  }

  static Future<bool> health() async {
    try {
      final base = await baseUrl();
      final response = await http.get(_uri(base, '/health', null)).timeout(const Duration(seconds: 5));
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  static Future<Map<String, dynamic>> login(String username, String password) async {
    final prefs = await _prefs();
    await prefs.remove(_tokenKey);
    final data = await _request(
      'POST',
      '/api/auth/login',
      body: {'username': username.trim(), 'password': password},
      includeAuth: false,
    );
    if (data is! Map) throw const ApiException('Sunucudan geçersiz giriş cevabı geldi.');
    final tokenValue = data['token']?.toString() ?? '';
    if (tokenValue.isEmpty) throw ApiException(data['error']?.toString() ?? 'Giriş yapılamadı.');
    await setToken(tokenValue);
    return Map<String, dynamic>.from(data);
  }

  static Future<Map<String, dynamic>> me() async => Map<String, dynamic>.from(await _request('GET', '/api/me'));
  static Future<Map<String, dynamic>> dashboard() async => Map<String, dynamic>.from(await _request('GET', '/api/dashboard'));
  static Future<List<dynamic>> campaigns() async => List<dynamic>.from((await _request('GET', '/api/campaigns'))['data'] ?? const []);
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
      List<dynamic>.from((await _request('GET', '/api/instagram/media?limit=$limit'))['data'] ?? const []);

  static Future<Map<String, dynamic>> createAdFromInstagramPost({
    required String instagramMediaId,
    required String campaignName,
    required String adSetName,
    required String adName,
    required double dailyBudget,
    bool activate = true,
  }) async =>
      Map<String, dynamic>.from(await _request('POST', '/api/ads/create', body: {
        'instagramMediaId': instagramMediaId,
        'campaignName': campaignName,
        'adSetName': adSetName,
        'adName': adName,
        'dailyBudget': dailyBudget,
        'activate': activate,
      }));

  static Future<Map<String, dynamic>> insights(String id) async {
    final data = await _request('GET', '/api/insights/$id');
    if (data is! Map) throw const ApiException('Sunucudan geçersiz insight cevabı geldi.');
    return Map<String, dynamic>.from(data);
  }
  static Future<List<dynamic>> posts() async => List<dynamic>.from((await _request('GET', '/api/posts'))['data'] ?? const []);
  static Future<Map<String, dynamic>> settings() async => Map<String, dynamic>.from(await _request('GET', '/api/settings'));
  static Future<Map<String, dynamic>> saveSettings(Map<String, dynamic> values) async => Map<String, dynamic>.from(await _request('PUT', '/api/settings', body: values));
  static Future<Map<String, dynamic>> runAutomation() async => Map<String, dynamic>.from(await _request('POST', '/api/automation/run'));
  static Future<List<dynamic>> logs() async => List<dynamic>.from((await _request('GET', '/api/logs'))['data'] ?? const []);
  static Future<void> status(String id, String statusValue) async => await _request('POST', '/api/status/$id', body: {'status': statusValue});
  static Future<void> updateAdSetBudget(String id, double dailyBudget) async => await _request('POST', '/api/budget/$id', body: {'dailyBudget': dailyBudget});
  static Future<void> deletePost(String id) async => await _request('DELETE', '/api/posts/$id');
  static Future<Map<String, dynamic>> publishPost(String id) async => Map<String, dynamic>.from(await _request('POST', '/api/posts/$id/publish'));
  static Future<List<dynamic>> users() async => List<dynamic>.from((await _request('GET', '/api/users'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createUser({required String username, required String password, String fullName = '', String role = 'OPERATOR'}) async => Map<String, dynamic>.from(await _request('POST', '/api/users', body: {'username': username, 'password': password, 'fullName': fullName, 'role': role}));
  static Future<void> toggleUser(String id) async => await _request('POST', '/api/users/$id/toggle');
  static Future<void> resetUserPassword(String id, String password) async => await _request('POST', '/api/users/$id/reset-password', body: {'password': password});
  static Future<void> changePassword(String currentPassword, String newPassword) async => await _request('POST', '/api/profile/password', body: {'currentPassword': currentPassword, 'newPassword': newPassword});
  static Future<Map<String, dynamic>> analyticsSummary() async => Map<String, dynamic>.from(await _request('GET', '/api/analytics/summary'));
  static Future<Map<String, dynamic>> aiInsights() async => Map<String, dynamic>.from(await _request('GET', '/api/ai/insights'));
  static Future<Map<String, dynamic>> billing() async => Map<String, dynamic>.from(await _request('GET', '/api/billing'));
  static Future<Map<String, dynamic>> branding() async => Map<String, dynamic>.from(await _request('GET', '/api/branding'));
  static Future<Map<String, dynamic>> saveBranding(Map<String, dynamic> values) async => Map<String, dynamic>.from(await _request('PUT', '/api/branding', body: values));
  static Future<Map<String, dynamic>> notificationPrefs() async => Map<String, dynamic>.from(await _request('GET', '/api/notifications'));
  static Future<Map<String, dynamic>> saveNotificationPrefs(Map<String, dynamic> values) async => Map<String, dynamic>.from(await _request('PUT', '/api/notifications', body: values));
  static Future<Map<String, dynamic>> securityOverview() async => Map<String, dynamic>.from(await _request('GET', '/api/security/overview'));
  static Future<Map<String, dynamic>> systemHealth() async => Map<String, dynamic>.from(await _request('GET', '/api/system/health'));
  static Future<Map<String, dynamic>> adminOverview() async => Map<String, dynamic>.from(await _request('GET', '/api/admin/overview'));
  static Future<List<dynamic>> adminPlans() async => List<dynamic>.from((await _request('GET', '/api/admin/plans'))['data'] ?? const []);
  static Future<Map<String, dynamic>> adminRuntime() async => Map<String, dynamic>.from(await _request('GET', '/api/admin/runtime'));

  static Future<Map<String, dynamic>> uploadPost(String path, String title, String caption, String linkUrl, {bool autoPublish = true, bool useAI = true, String mediaType = 'AUTO', String aiContext = ''}) async {
    final base = await baseUrl();
    final authToken = await token();
    final request = http.MultipartRequest('POST', _uri(base, '/api/posts', null));
    request.headers['Accept'] = 'application/json';
    if (authToken.isNotEmpty) request.headers['Authorization'] = 'Bearer $authToken';
    request.fields['title'] = title.trim();
    request.fields['caption'] = caption.trim();
    request.fields['linkUrl'] = linkUrl.trim();
    request.fields['autoPublish'] = autoPublish.toString();
    request.fields['useAI'] = useAI.toString();
    request.fields['mediaType'] = mediaType;
    request.fields['aiContext'] = aiContext;
    request.files.add(await http.MultipartFile.fromPath('image', path));
    try {
      final streamed = await request.send().timeout(const Duration(seconds: 60));
      final response = await http.Response.fromStream(streamed);
      final data = _decode(response.body);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(_error(data), statusCode: response.statusCode, details: response.body);
      }
      return Map<String, dynamic>.from(data as Map);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException('Dosya yükleme zaman aşımına uğradı.');
    } on SocketException catch (e) {
      throw ApiException('Dosya yüklenemedi; backend bağlantısı kurulamadı.', details: e.message);
    } on http.ClientException catch (e) {
      throw ApiException('Dosya yükleme bağlantı hatası.', details: e.message);
    }
  }

  // Super Admin API
  static Future<void> deleteCustomer(String tenantId) async => await _request('DELETE', '/api/admin/customers/$tenantId');
  static Future<Map<String, dynamic>> metaStatus() async => Map<String, dynamic>.from(await _request('GET', '/api/meta/status'));
  static Future<Map<String, dynamic>> metaHealth() async => Map<String, dynamic>.from(await _request('GET', '/api/meta/health'));
  static Future<Map<String, dynamic>> aiStatus() async => Map<String, dynamic>.from(await _request('GET', '/api/ai/status'));
  static Future<Map<String, dynamic>> generateCaptionVariants({required String title, String context = '', String tone = '', String goal = '', String language = 'Türkçe', String mediaType = 'AUTO', String imageUrl = ''}) async => Map<String, dynamic>.from(await _request('POST', '/api/ai/caption-variants', body: {'title': title, 'context': context, 'tone': tone, 'goal': goal, 'language': language, 'mediaType': mediaType, 'imageUrl': imageUrl}));
  static Future<Map<String, dynamic>> scoreCreative({String caption = '', String hook = '', String cta = '', List<dynamic> hashtags = const [], String mediaType = 'POST'}) async => Map<String, dynamic>.from(await _request('POST', '/api/ai/creative-score', body: {'caption': caption, 'hook': hook, 'cta': cta, 'hashtags': hashtags, 'mediaType': mediaType}));
  static Future<Map<String, dynamic>> generateContentPack({required String title, String context = '', String tone = '', String goal = '', String language = 'Türkçe', String mediaType = 'AUTO', String imageUrl = ''}) async => Map<String, dynamic>.from(await _request('POST', '/api/ai/content-pack', body: {'title': title, 'context': context, 'tone': tone, 'goal': goal, 'language': language, 'mediaType': mediaType, 'imageUrl': imageUrl}));
  static Future<Map<String, dynamic>> generateCaption({required String title, String context = '', String tone = '', String goal = '', String language = 'Türkçe', String mediaType = 'AUTO', String imageUrl = ''}) async => Map<String, dynamic>.from(await _request('POST', '/api/ai/caption', body: {'title': title, 'context': context, 'tone': tone, 'goal': goal, 'language': language, 'mediaType': mediaType, 'imageUrl': imageUrl}));
  static Future<Map<String, dynamic>> metaConnectStart() async =>
      Map<String, dynamic>.from(await _request('GET', '/api/meta/connect/start'));
static Future<void> metaDisconnect() async => await _request('POST', '/api/meta/disconnect');

  static Future<Map<String, dynamic>> adminStats() async => Map<String, dynamic>.from(await _request('GET', '/api/admin/stats'));
  static Future<List<dynamic>> adminCustomers() async => List<dynamic>.from((await _request('GET', '/api/admin/customers'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createCustomer({required String companyName, required String username, required String password, required String plan, required int days, String fullName = ''}) async => Map<String, dynamic>.from(await _request('POST', '/api/admin/customers', body: {
    'companyName': companyName,
    'username': username,
    'password': password,
    'plan': plan,
    'days': days,
    'fullName': fullName,
  }));
  static Future<Map<String, dynamic>> updateCustomer(String tenantId, Map<String, dynamic> values) async => Map<String, dynamic>.from(await _request('PUT', '/api/admin/customers/$tenantId', body: values));
  static Future<Map<String, dynamic>> toggleCustomer(String tenantId) async => Map<String, dynamic>.from(await _request('POST', '/api/admin/customers/$tenantId/toggle'));
  static Future<Map<String, dynamic>> extendCustomer(String tenantId, int days) async => Map<String, dynamic>.from(await _request('POST', '/api/admin/customers/$tenantId/extend', body: {'days': days}));
  static Future<Map<String, dynamic>> resetCustomerPassword(String tenantId, String password) async => Map<String, dynamic>.from(await _request('POST', '/api/admin/customers/$tenantId/reset-password', body: {'password': password}));
  static Future<List<dynamic>> licenses() async => List<dynamic>.from((await _request('GET', '/api/admin/licenses'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createLicense(String plan, int days) async => Map<String, dynamic>.from(await _request('POST', '/api/admin/licenses', body: {'plan': plan, 'days': days}));
  static Future<Map<String, dynamic>> assignLicense(String licenseId, String tenantId) async => Map<String, dynamic>.from(await _request('POST', '/api/admin/licenses/$licenseId/assign', body: {'tenantId': tenantId}));
  static Future<Map<String, dynamic>> proAi() async => Map<String, dynamic>.from(await _request('GET', '/api/pro/ai'));
  static Future<Map<String, dynamic>> proPerformance() async => Map<String, dynamic>.from(await _request('GET', '/api/pro/performance'));
  static Future<List<dynamic>> proAlerts() async => List<dynamic>.from((await _request('GET', '/api/pro/alerts'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createAlert(String title, String body, String severity) async => Map<String, dynamic>.from(await _request('POST', '/api/pro/alerts', body: {'title': title, 'body': body, 'severity': severity}));
  static Future<void> markAlert(String id) async => await _request('POST', '/api/pro/alerts/$id/read');
  static Future<List<dynamic>> proLeads() async => List<dynamic>.from((await _request('GET', '/api/pro/leads'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createLead({required String name, String phone = '', String email = '', double value = 0, String status = 'NEW', String source = 'META', String notes = ''}) async => Map<String, dynamic>.from(await _request('POST', '/api/pro/leads', body: {'name': name, 'phone': phone, 'email': email, 'value': value, 'status': status, 'source': source, 'notes': notes}));
  static Future<Map<String, dynamic>> updateLead(String id, Map<String, dynamic> values) async => Map<String, dynamic>.from(await _request('PUT', '/api/pro/leads/$id', body: values));
  static Future<void> deleteLead(String id) async => await _request('DELETE', '/api/pro/leads/$id');
  static Future<List<dynamic>> creatives() async => List<dynamic>.from((await _request('GET', '/api/pro/creatives'))['data'] ?? const []);
  static Future<Map<String, dynamic>> analyzeCreative({required String title, required String copy, required String type}) async => Map<String, dynamic>.from(await _request('POST', '/api/pro/creatives/analyze', body: {'title': title, 'copy': copy, 'type': type}));
  static Future<Map<String, dynamic>> simulateBudget({required double totalBudget, required double reservePercent, required List<dynamic> items}) async => Map<String, dynamic>.from(await _request('POST', '/api/pro/budget/simulate', body: {'totalBudget': totalBudget, 'reservePercent': reservePercent, 'items': items}));
  static Future<List<dynamic>> experiments() async => List<dynamic>.from((await _request('GET', '/api/pro/experiments'))['data'] ?? const []);
  static Future<Map<String, dynamic>> createExperiment({required String name, required double budget, required List<dynamic> variants}) async => Map<String, dynamic>.from(await _request('POST', '/api/pro/experiments', body: {'name': name, 'budget': budget, 'variants': variants}));
  static Future<void> updateExperimentStatus(String id, String status) async => await _request('POST', '/api/pro/experiments/$id/status', body: {'status': status});
  static Future<Map<String, dynamic>> buildUtm({required String source, required String medium, required String campaign, required String content, String term = ''}) async => Map<String, dynamic>.from(await _request('POST', '/api/pro/utm', body: {'source': source, 'medium': medium, 'campaign': campaign, 'content': content, 'term': term}));
  static Future<Map<String, dynamic>> proReport() async => Map<String, dynamic>.from(await _request('GET', '/api/pro/report'));
  static Future<Map<String, dynamic>> proAgency() async => Map<String, dynamic>.from(await _request('GET', '/api/pro/agency'));

}
