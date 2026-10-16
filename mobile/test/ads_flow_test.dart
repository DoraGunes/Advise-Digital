import 'dart:async';
import 'dart:convert';
import 'package:advise_digital/api.dart';
import 'package:advise_digital/app_error.dart';
import 'package:advise_digital/social_ads_page.dart';
import 'package:advise_digital/product_ui.dart';
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

  testWidgets(
      'ads page offers the Meta connection center when media access is unavailable',
      (tester) async {
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/api/instagram/media') {
        return http.Response(
            jsonEncode({'error': 'Meta bağlantısı kurulmadı.'}), 502,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode({'ok': true}), 200,
          headers: {'content-type': 'application/json'});
    }));
    await tester.pumpWidget(MaterialApp(
        theme: ProductTheme.light, home: const SocialAdsPage()));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Meta bağlantısı gerekli'), findsOneWidget);
    expect(find.text('Meta bağlantısını aç'), findsOneWidget);
    expect(find.text('Tekrar dene'), findsOneWidget);
  });

  Future<void> openStrategy(
      WidgetTester tester, Future<http.Response> Function() action,
      {Future<http.Response> Function(http.Request)? createAction,
      ThemeData? theme,
      bool mediaHasCaption = true}) async {
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.url.path == '/api/memory') return action();
      if (request.url.path == '/api/ads/create' && createAction != null)
        return createAction(request);
      final dynamic data = switch (request.url.path) {
        '/health' => {
            'ok': true,
            'version': '16.0.0',
            'capabilities': {
              'productExperience': true,
              'campaignStrategy': true,
              'adCreateSaga': true,
              'adPresets': true
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
                if (mediaHasCaption) 'caption': 'Fixture ürün',
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
    await tester.pumpWidget(MaterialApp(
        theme: theme ?? ProductTheme.light,
        home: const SocialAdsPage(initialMediaId: 'media-1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Bağlantı ve geçmiş'));
    await tester.tap(find.text('Bağlantı ve geçmiş'));
    await tester.pumpAndSettle();
    final button = find.text('Kendi reklam geçmişimi göster');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
  }

  testWidgets('selected post without caption is not shown as unselected',
      (tester) async {
    await openStrategy(tester, () async => http.Response('{}', 200),
        mediaHasCaption: false);
    await tester.ensureVisible(find.text('Önizle ve onayla'));
    await tester.tap(find.text('Önizle ve onayla'));
    await tester.pumpAndSettle();
    expect(find.text('Seçili Instagram gönderisinin açıklaması yok.'),
        findsOneWidget);
    expect(find.text('Instagram gönderisi seçilmedi'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final entry in {
    'Light': ProductTheme.light,
    'Dark': ProductTheme.dark,
    'Colorful': ProductTheme.colorful
  }.entries) {
    testWidgets('${entry.key} bounded history read retry clears loading and manual retry succeeds',
        (tester) async {
      var calls = 0;
      await openStrategy(tester, () async {
        calls++;
        return http.Response(
            jsonEncode(calls <= 2
                ? {'code': 'ETIMEDOUT', 'stage': 'strategy'}
                : {
                    'performance': {'paidCount': 1},
                    'timing': {'paid': {'reason':'Özgün ürün açılışı','sampleSize':1}},
                    'available': true,
                    'strategy': {
                      'hook': 'Özgün ürün açılışı',
                      'budget': {},
                      'creative': {},
                      'audience': {},
                      'schedule': {}
                    }
                  }),
            calls <= 2 ? 504 : 200,
            headers: {'content-type': 'application/json; charset=utf-8'});
      }, theme: entry.value);
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.text('Geçmiş okunuyor…'), findsNothing);
      expect(calls, 2);
      final retry = find.text('Kendi reklam geçmişimi göster');
      await tester.ensureVisible(retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(calls, 3);
      expect(find.textContaining('Özgün ürün açılışı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('disposed history widget does not update state after delayed response',
      (tester) async {
    final response = Completer<http.Response>();
    await openStrategy(tester, () => response.future);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    response.complete(http.Response(
        '{"available":false,"error":"Geçmiş geçici olarak okunamıyor."}',
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
      expect(body['destination'],'WHATSAPP');
      expect(body['presetId'],'service-all');
      expect(body['autoReply'],false);
      expect(body['dailyBudget'],120);
      expect(body['locationMode'],'RADIUS');
      expect((body['radius'] as Map)['radius'],200);
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
