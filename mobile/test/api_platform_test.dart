import 'dart:convert';
import 'dart:typed_data';

import 'package:advise_digital/api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.resetRuntimeForTesting();
  });
  tearDown(() {
    Api.setHttpClientForTesting(null);
    Api.resetRuntimeForTesting();
  });

  test('API base URL survives session restart and rejects embedded credentials',
      () async {
    await Api.setBaseUrl('https://api.example.test/');
    Api.resetRuntimeForTesting();
    expect(await Api.baseUrl(), 'https://api.example.test');
    await expectLater(Api.setBaseUrl('https://user:password@api.example.test'),
        throwsA(isA<ApiException>()));
  });

  test('remembered session persists; session-only login clears stored token',
      () async {
    Api.setHttpClientForTesting(MockClient((request) async => http.Response(
        jsonEncode({'token': 'fixture-session', 'user': {}}), 200)));
    await Api.login('fixture-user', 'fixture-password');
    Api.resetRuntimeForTesting();
    expect(await Api.token(), 'fixture-session');
    await Api.login('fixture-user', 'fixture-password', remember: false);
    expect(await Api.token(), 'fixture-session');
    expect(
        (await SharedPreferences.getInstance()).getString('authToken'), isNull);
    Api.resetRuntimeForTesting();
    expect(await Api.token(), isEmpty);
  });

  test('changing API origin clears JWT before any request to the new host',
      () async {
    await Api.setBaseUrl('https://api.example.test');
    await Api.setToken('fixture-session');
    await Api.setBaseUrl('https://api.example.test/v16');
    expect(await Api.token(), 'fixture-session');
    await Api.setBaseUrl('https://api.example.test:443');
    expect(await Api.token(), 'fixture-session');
    await expectLater(Api.setBaseUrl('https://user:password@api.example.test'),
        throwsA(isA<ApiException>()));
    expect(await Api.token(), 'fixture-session');
    await Api.setBaseUrl('https://other.example.test');
    expect(await Api.token(), isEmpty);
    expect(
        (await SharedPreferences.getInstance()).getString('authToken'), isNull);
    Api.setHttpClientForTesting(MockClient((request) async {
      expect(request.url.host, 'other.example.test');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response('{}', 200);
    }));
    await Api.me();
    await Api.setToken('new-fixture-session');
    await Api.setBaseUrl('https://other.example.test:8443');
    expect(await Api.token(), isEmpty);
  });

  test('transient GET retries once but mutations never retry', () async {
    var getCalls = 0;
    var mutationCalls = 0;
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.method == 'GET') {
        getCalls++;
        return getCalls == 1
            ? http.Response('{}', 503)
            : http.Response('{"user":{}}', 200);
      }
      mutationCalls++;
      return http.Response('{"error":"temporary failure"}', 503);
    }));
    await Api.me();
    expect(getCalls, 2);
    await expectLater(
        Api.login('user', 'password'), throwsA(isA<ApiException>()));
    expect(mutationCalls, 1);
    await expectLater(Api.saveProductOnboarding({'companyName': 'Fixture'}),
        throwsA(isA<ApiException>()));
    expect(mutationCalls, 2);
    await expectLater(
        Api.deleteLead('fixture-lead'), throwsA(isA<ApiException>()));
    expect(mutationCalls, 3);
    await expectLater(
        Api.updatePost('fixture-post', title: 'Fixture', caption: 'Caption'),
        throwsA(isA<ApiException>()));
    expect(mutationCalls, 4);
  });

  test('authenticated 401 triggers session expiry', () async {
    await Api.setToken('fixture-session');
    Api.setHttpClientForTesting(MockClient(
        (request) async => http.Response('{"error":"Session expired"}', 401)));
    await expectLater(Api.me(), throwsA(isA<ApiException>()));
    expect(Api.authExpired.value, isTrue);
    await Api.logout();
    expect(Api.authExpired.value, isFalse);
    expect(await Api.token(), isEmpty);
  });

  test('compatibility requires current version and real product capability',
      () {
    expect(
        Api.compatibilityFromHealth(
            {'ok': true, 'version': '14.0.0'})['compatible'],
        isFalse);
    expect(
        Api.compatibilityFromHealth({
          'ok': true,
          'version': '16.0.0',
          'capabilities': {'productExperience': true}
        })['compatible'],
        isTrue);
    expect(
        Api.compatibilityFromHealth({
          'ok': true,
          'version': '16.0.0',
          'capabilities': ['productExperience']
        })['compatible'],
        isFalse);
    expect(Api.compatibilityFromHealth({'ok': false})['message'],
        contains('Sunucuya ulaşılamıyor'));
  });

  test('compatibility reads health without sending credentials', () async {
    await Api.setToken('fixture-session');
    Api.setHttpClientForTesting(MockClient((request) async {
      expect(request.url.path, '/health');
      expect(request.headers.containsKey('Authorization'), isFalse);
      return http.Response(
          '{"ok":true,"version":"16.0.0",'
          '"capabilities":{"productExperience":true}}',
          200);
    }));
    expect((await Api.compatibility())['compatible'], isTrue);
  });

  test('multipart uploads use bytes and selected filename on every platform',
      () async {
    var uploads = 0;
    final file = XFile.fromData(
        Uint8List.fromList([137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3]),
        path: 'chosen.png',
        name: 'chosen.png',
        mimeType: 'image/png');
    Api.setHttpClientForTesting(MockClient((request) async {
      uploads++;
      final body = latin1.decode(request.bodyBytes);
      expect(request.headers['content-type'], contains('multipart/form-data'));
      expect(
          body,
          contains(request.url.path.endsWith('/cover')
              ? 'filename="cover.png"'
              : 'filename="chosen.png"'));
      if (request.url.path.endsWith('/cover'))
        expect(body, contains('content-type: image/png'));
      expect(body, contains(String.fromCharCodes([1, 2, 3])));
      return http.Response('{"id":"fixture-post"}', 200);
    }));
    await Api.uploadPost('', 'Title', 'Caption', '', mediaFile: file);
    await Api.generateContentPackFromFile('', mediaFile: file);
    await Api.uploadPostCover('fixture-post', '', mediaFile: file);
    await Api.uploadPostsBulk([], mediaFiles: [file]);
    expect(uploads, 4);
  });

  test('custom report range reaches existing product endpoint', () async {
    Api.setHttpClientForTesting(MockClient((request) async {
      expect(request.url.path, '/api/product/report');
      expect(request.url.queryParameters,
          {'range': 'custom', 'since': '2026-10-01', 'until': '2026-10-05'});
      return http.Response('{}', 200);
    }));
    await Api.productReport(
        range: 'custom', since: '2026-10-01', until: '2026-10-05');
  });

  test('older backend blocks precise scheduling and Gemini before any mutation',
      () async {
    var mutations = 0;
    var healthRequests = 0;
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/health') {
        healthRequests++;
        return http.Response('{"ok":true,"version":"14.0.0"}', 200);
      }
      mutations++;
      return http.Response('{}', 200);
    }));
    await expectLater(
        Api.queuePost('fixture', scheduleAt: '2026-10-06T16:30:00Z'),
        throwsA(isA<ApiException>()));
    await expectLater(
        Api.uploadPost('', 'Title', 'Caption', '',
            scheduleAt: '2026-10-06T16:30:00Z'),
        throwsA(isA<ApiException>()));
    await expectLater(Api.geminiAdReview(), throwsA(isA<ApiException>()));
    await expectLater(
        Api.applyGeminiAdDecision(adSetId: 'fixture', action: 'PAUSE'),
        throwsA(isA<ApiException>()));
    expect(mutations, 0);
    expect(healthRequests, 1);
  });

  test(
      'supported capabilities allow scheduling and exact metadata is preserved',
      () async {
    var healthRequests = 0;
    var mutations = 0;
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/health') {
        healthRequests++;
        return http.Response(
            jsonEncode({
              'ok': true,
              'version': '16.0.0',
              'capabilities': {
                'productExperience': true,
                'scheduledPublishing': true,
                'geminiAdReview': true,
                'safeAutomationV16': true,
                'campaignStrategy': true
              }
            }),
            200);
      }
      mutations++;
      if (request.url.path.endsWith('/queue')) {
        expect(jsonDecode(request.body)['scheduleAt'], '2026-10-06T16:30:00Z');
      }
      if (request.url.path == '/api/product/strategy') {
        expect(jsonDecode(request.body)['dailyBudget'], 100);
      }
      return http.Response('{}', 200);
    }));
    await Api.queuePost('fixture', scheduleAt: '2026-10-06T16:30:00Z');
    await Api.geminiAdReview();
    await Api.applyGeminiAdDecision(adSetId: 'fixture', action: 'PAUSE');
    await Api.productStrategy({'dailyBudget': 100});
    expect(mutations, 4);
    expect(healthRequests, 1);
    await Api.setBaseUrl('https://other.example.test');
    await Api.queuePost('fixture', scheduleAt: '2026-10-06T16:30:00Z');
    expect(healthRequests, 2);
    await Api.logout();
    await Api.geminiAdReview();
    expect(healthRequests, 3);
  });

  test('campaign strategy surfaces typed quality-gate failure from a 200 response',
      () async {
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/health') {
        return http.Response(jsonEncode({
          'ok': true,
          'version': '16.0.0',
          'capabilities': {
            'productExperience': true,
            'campaignStrategy': true
          }
        }), 200);
      }
      expect(request.url.path, '/api/product/strategy');
      return http.Response(jsonEncode({
        'available': false,
        'code': 'GEMINI_RECOMMENDATION_VALIDATION',
        'stage': 'QUALITY_GATE',
        'retryable': true,
        'correlationId': 'campaign-fixture',
        'userMessage': 'Gemini cevabı alındı ancak kampanya önerisi doğrulama kurallarından geçmedi.'
      }), 200);
    }));
    try {
      await Api.productStrategy({'dailyBudget': 100});
      fail('expected typed campaign AI failure');
    } on ApiException catch (error) {
      expect(error.code, 'GEMINI_RECOMMENDATION_VALIDATION');
      expect(error.stage, 'QUALITY_GATE');
      expect(error.correlationId, 'campaign-fixture');
      expect(error.retryable, isTrue);
      expect(error.userMessage, contains('kalite kontrolünden geçmedi'));
    }
  });

  test('post caption edits use PATCH without retry', () async {
    Api.setHttpClientForTesting(MockClient((request) async {
      expect(request.method, 'PATCH');
      expect(request.url.path, '/api/posts/fixture');
      expect(jsonDecode(request.body)['caption'], 'Updated caption');
      return http.Response('{}', 200);
    }));
    await Api.updatePost('fixture', title: 'Title', caption: 'Updated caption');
  });
}
