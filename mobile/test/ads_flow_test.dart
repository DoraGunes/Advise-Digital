import 'dart:async';
import 'dart:convert';
import 'package:advise_digital/api.dart';
import 'package:advise_digital/app_error.dart';
import 'package:advise_digital/social_ads_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.resetRuntimeForTesting();
  });
  tearDown(() {
    Api.setHttpClientForTesting(null);
    Api.resetRuntimeForTesting();
  });
  test(
      'structured Meta failure retains actionable stage and never exposes raw payload',
      () async {
    Api.setHttpClientForTesting(MockClient((request) async => http.Response(
        jsonEncode({
          'ok': false,
          'code': 'META_PERMISSION_DENIED',
          'stage': 'adset',
          'retryable': false,
          'correlationId': 'fixture-correlation',
          'error': 'access_token=fixture-secret',
        }),
        502)));
    try {
      await Api.adsPreflight();
      fail('expected error');
    } on ApiException catch (error) {
      // Capability check may fail first; request a route without that gate.
      expect(error.details, isNull);
    }
    try {
      await Api.adOperation('fixture-request-id');
      fail('expected error');
    } on ApiException catch (error) {
      expect(error.code, 'META_PERMISSION_DENIED');
      expect(error.correlationId, 'fixture-correlation');
      expect(AppError.message(error), contains('reklam seti'));
      expect(AppError.message(error), isNot(contains('fixture-secret')));
      expect(AppError.message(error), isNot(contains('Hizmet şu anda')));
    }
  });
  test(
      'request identity survives restart and is isolated by account and payload',
      () async {
    await Api.setBaseUrl('https://fixture.test');
    final first = await Api.stableAdRequestId(
        'tenant:user', {'budget': 100}, 'first-request-id');
    Api.resetRuntimeForTesting();
    expect(
        await Api.stableAdRequestId(
            'tenant:user', {'budget': 100}, 'second-request-id'),
        first);
    expect(
        await Api.stableAdRequestId(
            'other:user', {'budget': 100}, 'other-request-id'),
        'other-request-id');
    expect(
        await Api.stableAdRequestId(
            'tenant:user', {'budget': 200}, 'changed-request-id'),
        'changed-request-id');
  });
  Future<void> openStrategy(
      WidgetTester tester, Future<http.Response> Function() action,
      {Future<http.Response> Function(http.Request)? createAction}) async {
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/api/product/strategy') return action();
      if (request.url.path == '/api/ads/create' && createAction != null)
        return createAction(request);
      final dynamic data = switch (request.url.path) {
        '/health' => {
            'ok': true,
            'version': '16.0.0',
            'capabilities': {
              'productExperience': true,
              'campaignStrategy': true,
              'adCreateSaga': true
            }
          },
        '/api/me' => {
            'user': {'id': 'user-1', 'role': 'OPERATOR'},
            'tenant': {'id': 'tenant-1'}
          },
        '/api/instagram/media' => {
            'data': [
              {
                'id': 'media-1',
                'caption': 'Fixture ürün',
                'media_type': 'IMAGE'
              }
            ]
          },
        _ => {'mode': 'COUNTRY', 'cities': [], 'regions': [], 'locations': []},
      };
      return http.Response(jsonEncode(data), 200);
    }));
    await tester.binding.setSurfaceSize(const Size(800, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        const MaterialApp(home: SocialAdsPage(initialMediaId: 'media-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('AI önerisi'));
    await tester.tap(find.text('AI önerisi'));
    await tester.pumpAndSettle();
    final button = find.text('AI kampanya önerisi al');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('AI error clears loading and retry succeeds', (tester) async {
    var calls = 0;
    await openStrategy(tester, () async {
      calls++;
      return http.Response(
          jsonEncode(calls == 1
              ? {'code': 'ETIMEDOUT', 'stage': 'strategy'}
              : {
                  'available': true,
                  'source': 'GEMINI',
                  'strategy': {
                    'hook': 'Özgün ürün açılışı',
                    'budget': {},
                    'creative': {},
                    'audience': {},
                    'schedule': {}
                  }
                }),
          calls == 1 ? 504 : 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    });
    await tester.pumpAndSettle();
    expect(find.text('Hazırlanıyor…'), findsNothing);
    expect(calls, 1);
    final retry = find.text('AI kampanya önerisi al');
    await tester.ensureVisible(retry);
    await tester.tap(retry);
    await tester.pumpAndSettle();
    expect(calls, 2);
    expect(find.textContaining('Özgün ürün açılışı'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('disposed AI widget does not update state after delayed response',
      (tester) async {
    final response = Completer<http.Response>();
    await openStrategy(tester, () => response.future);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    response.complete(http.Response(
        '{"available":false,"error":"Gemini geçici olarak yanıt vermiyor."}',
        200,
        headers: {'content-type': 'application/json; charset=utf-8'}));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'create disables duplicate click and clears spinner before success dialog closes',
      (tester) async {
    final response = Completer<http.Response>();
    var calls = 0;
    await openStrategy(
        tester, () async => http.Response('{"available":false}', 200),
        createAction: (request) {
      calls++;
      final body = jsonDecode(request.body) as Map;
      expect(body['requestId'], isNotEmpty);
      expect(body['activate'], false);
      return response.future;
    });
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Önizle ve onayla'));
    await tester.tap(find.text('Önizle ve onayla'));
    await tester.pumpAndSettle();
    final create = find.text('Onayla ve reklamı oluştur').last;
    await tester.ensureVisible(create);
    await tester.tap(create);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Onayla'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(calls, 1);
    expect(find.text('Oluşturuluyor…'), findsWidgets);
    response.complete(http.Response(
        '{"ok":true,"activated":false,"targeting":{"locations":[]}}', 201));
    await tester.pumpAndSettle();
    expect(find.text('Oluşturuluyor…'), findsNothing);
    expect(find.text('Reklam oluşturuldu'), findsWidgets);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
