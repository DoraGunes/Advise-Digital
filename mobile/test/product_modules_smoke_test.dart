import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:advise_digital/api.dart';
import 'package:advise_digital/content_queue_page.dart';
import 'package:advise_digital/media_access.dart';
import 'package:advise_digital/product_modules.dart';
import 'package:advise_digital/product_shell.dart';
import 'package:advise_digital/product_ui.dart';
import 'package:advise_digital/v14_ai.dart';
import 'package:advise_digital/main.dart' show LoginPage;

void main() {
  late List<String> mutations;
  late List<Map<String, dynamic>> posts;
  var role = 'OPERATOR';
  var source = 'GEMINI';
  var currency = 'USD';
  var measured = 0;
  var disconnected = false;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.resetRuntimeForTesting();
    mutations = [];
    posts = [];
    role = 'OPERATOR';
    source = 'GEMINI';
    currency = 'USD';
    measured = 0;
    disconnected = false;
    Api.setHttpClientForTesting(MockClient((request) async {
      final path = request.url.path;
      if (request.method != 'GET') mutations.add('${request.method} $path');
      dynamic body;
      if (path == '/health') {
        body = {
          'ok': true,
          'version': '16.0.0',
          'apiVersion': 16,
          'capabilities': {
            'productExperience': true,
            'productOverview': true,
            'productReporting': true,
            'scheduledPublishing': true,
            'onboarding': true
          }
        };
      } else if (path == '/api/me') {
        body = {
          'user': {'id': 'fixture-user', 'role': role},
          'tenant': {'id': 'fixture-tenant', 'companyName': 'Fixture İşletme'}
        };
      } else if (path == '/api/ai/status') {
        body = {'configured': true};
      } else if (path == '/api/ai/memory') {
        body = {
          'generationCount': 1,
          'outcomeCount': measured,
          'learningWins': measured,
          'bestHookTypes': measured > 0
              ? [
                  {'value': 'Soruyla açılış', 'score': .5}
                ]
              : [],
          'recentGenerations': []
        };
      } else if (path == '/api/ai/content-pack-from-file') {
        body = {
          'source': source,
          'productName': 'Fixture ürün',
          'caption': 'Fixture yayın metni',
          'hook': 'Fixture açılış',
          'cta': 'WhatsApp üzerinden yazın',
          'contactChannel': 'WHATSAPP',
          'recommendedFormat': 'POST',
          'recommendedPostTime': '19:30',
          'memoryGenerationId': 'fixture-generation',
          'hashtags': ['#fixture']
        };
      } else if (path == '/api/posts' && request.method == 'POST') {
        final post = <String, dynamic>{
          'id': 'fixture-post',
          'title': 'Fixture ürün',
          'caption': 'Fixture yayın metni',
          'publishStatus': 'MANUAL',
          'mediaType': 'IMAGE',
          'publicUrl': ''
        };
        posts.add(post);
        body = post;
      } else if (path == '/api/posts/fixture-post/queue') {
        final input = jsonDecode(request.body) as Map;
        posts.first['publishStatus'] = 'QUEUED';
        posts.first['nextPublishAt'] = input['scheduleAt'];
        body = posts.first;
      } else if (path == '/api/posts') {
        body = {'data': posts};
      } else if (path == '/api/settings') {
        body = {
          'autoPublish': true,
          'enabled': false,
          'geminiAdsAuto': false,
          'geminiAdsDailyCap': 0,
          'minDailyBudget': 50,
          'maxDailyBudget': 500
        };
      } else if (path == '/api/logs') {
        body = {'data': []};
      } else if (path == '/api/product/overview' ||
          path == '/api/product/report') {
        body = {
          'available': !disconnected,
          'metaConnected': !disconnected,
          'currency': currency,
          'metrics': {
            'spend': disconnected ? null : 12.5,
            'cpa': disconnected ? null : 2.5,
            'activeAds': disconnected ? null : 0,
            'messages': disconnected ? null : 5
          },
          'trend': [],
          'campaigns': []
        };
      } else if (['/api/campaigns', '/api/adsets', '/api/ads', '/api/pro/leads']
          .contains(path)) {
        body = {'data': [], 'connected': !disconnected};
      } else if (path == '/api/pro/alerts') {
        body = {
          'data': [
            {
              'id': 'fixture-alert',
              'title': 'Meta hesabın bağlı',
              'body': 'Meta bağlantısı kontrol edildi. İçerik planın hazır.',
              'read': false,
              'severity': 'INFO'
            }
          ]
        };
      } else {
        return http.Response(
            jsonEncode({'error': 'Fixture endpoint bulunamadı.'}), 404,
            headers: {'content-type': 'application/json'});
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json'});
    }));
  });
  tearDown(() {
    Api.setHttpClientForTesting(null);
    Api.resetRuntimeForTesting();
  });

  Widget host(Widget child,
      {bool dark = false,
      double scale = 1,
      bool withScope = false,
      ThemeData? theme}) {
    final content = withScope
        ? ProductNavigation(
            user: {'role': role},
            tenant: const {},
            go: (_) {},
            open: (_) async {},
            onLogout: () async {},
            child: child)
        : child;
    return MaterialApp(
        theme: theme ?? (dark ? ProductTheme.dark : ProductTheme.light),
        home: MediaQuery(
            data: MediaQueryData(
                size: const Size(390, 844),
                textScaler: TextScaler.linear(scale)),
            child: content));
  }

  Future<void> size(WidgetTester tester,
      {double width = 390, double height = 844}) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  Future<void> scrollTo(WidgetTester tester, Finder target) async {
    await tester.scrollUntilVisible(target, 350,
        scrollable: find.byType(Scrollable).first, maxScrolls: 20);
    await tester.pumpAndSettle();
  }

  for (final entry in {
    'Light': ProductTheme.light,
    'Dark': ProductTheme.dark,
    'Colorful': ProductTheme.colorful
  }.entries) {
    testWidgets(
        '${entry.key} Studio ads queue memory and reports render safely',
        (tester) async {
      await size(tester, width: 390, height: 1100);
      for (final page in [
        const AiContentStudioPage(),
        const AdsCenterPage(),
        const ContentQueuePage(),
        const MemoryInsightsPage(),
        const ProductReportsPage()
      ]) {
        await tester
            .pumpWidget(host(page, theme: entry.value, withScope: true));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull,
            reason: '${page.runtimeType} ${entry.key}');
        // Check the actual inherited default for text in each real module.
        final text = find.byType(Text).first;
        final color = DefaultTextStyle.of(tester.element(text)).style.color!;
        final a = color.computeLuminance();
        final b = entry.value.colorScheme.surface.computeLuminance();
        expect(((a > b ? a : b) + .05) / ((a < b ? a : b) + .05),
            greaterThanOrEqualTo(4.5));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      }
      expect(mutations, isEmpty);
    });
  }

  testWidgets(
      'VIEWER Studio has no actionable generation or publishing controls',
      (tester) async {
    role = 'VIEWER';
    await size(tester);
    await tester.pumpWidget(host(const AiContentStudioPage(), withScope: true));
    await tester.pumpAndSettle();
    expect(find.text('Görüntüleme yetkisi'), findsOneWidget);
    await scrollTo(tester, find.text('AI ile içerik üret'));
    final generate = tester.widget<FilledButton>(find.ancestor(
        of: find.text('AI ile içerik üret'),
        matching: find.byType(FilledButton)));
    expect(generate.onPressed, isNull);
    expect(mutations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'RECONCILE Planner post exposes preview and blocks all mutation actions',
      (tester) async {
    posts = [
      {
        'id': 'ambiguous',
        'title': 'Doğrulama içeriği',
        'publishStatus': 'RECONCILE',
        'caption': 'Instagram sonucu henüz doğrulanmadı.',
        'publicUrl': 'https://fixture.invalid/media.png'
      }
    ];
    await size(tester, width: 320);
    await tester
        .pumpWidget(host(const ContentQueuePage(), dark: true, scale: 1.4));
    await tester.pumpAndSettle();
    final card = find.byKey(const ValueKey('content-post-ambiguous'));
    await scrollTo(tester, card);
    expect(find.descendant(of: card, matching: find.text('DOĞRULAMA BEKLİYOR')),
        findsOneWidget);
    for (final action in ['Şimdi paylaş', 'Düzenle', 'Saat seç'])
      expect(
          find.descendant(of: card, matching: find.text(action)), findsNothing);
    expect(find.descendant(of: card, matching: find.byTooltip('İçeriği sil')),
        findsNothing);
    expect(mutations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('VIEWER Planner and Automation cannot change configuration',
      (tester) async {
    role = 'VIEWER';
    await size(tester);
    await tester.pumpWidget(host(const ProductAutomationPage()));
    await tester.pumpAndSettle();
    expect(find.text('Limitleri kaydet'), findsNothing);
    for (final control
        in tester.widgetList<SwitchListTile>(find.byType(SwitchListTile)))
      expect(control.onChanged, isNull);
    await tester.pumpWidget(host(const ContentQueuePage()));
    await tester.pumpAndSettle();
    expect(find.text('MEDYA SEÇ'), findsNothing);
    expect(mutations, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reports honor actual account currency', (tester) async {
    await size(tester);
    await tester.pumpWidget(host(const ProductReportsPage()));
    await tester.pumpAndSettle();
    expect(find.text('12.50 USD'), findsOneWidget);
    expect(find.textContaining('₺'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('disconnected Ads Center displays unavailable active metric',
      (tester) async {
    disconnected = true;
    role = 'VIEWER';
    await size(tester);
    await tester.pumpWidget(host(const AdsCenterPage()));
    await tester.pumpAndSettle();
    expect(find.text('—'), findsNWidgets(3));
    expect(find.text('0'), findsNothing);
    expect(find.text('Reklam oluştur'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Memory shows measured early hook-type signals without fake threshold',
      (tester) async {
    measured = 1;
    await size(tester);
    await tester.pumpWidget(host(const MemoryInsightsPage()));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('Açılış türleri'));
    expect(find.text('Soruyla açılış'), findsOneWidget);
    expect(find.textContaining('erken sinyal'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Notifications retain normal Meta connection message',
      (tester) async {
    await size(tester);
    await tester.pumpWidget(host(const ProductNotificationsPage()));
    await tester.pumpAndSettle();
    expect(find.text('Meta bağlantısı kontrol edildi. İçerik planın hazır.'),
        findsOneWidget);
    expect(find.textContaining('Sunucuya ulaşılamıyor'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Media Library adapts natural card heights for large text in dark theme',
      (tester) async {
    posts = [
      {
        'id': 'media-fixture',
        'title': 'Uzun ürün başlığı için erişilebilir medya kartı',
        'caption':
            'Daha büyük yazı seçildiğinde bu kartın açıklaması güvenli şekilde yerleşmeli.',
        'mediaType': 'VIDEO',
        'publishStatus': 'MANUAL'
      }
    ];
    await size(tester, width: 320);
    await tester
        .pumpWidget(host(const MediaLibraryPage(), dark: true, scale: 1.8));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('İçeriği görüntüle'));
    expect(tester.takeException(), isNull);
  });

  for (final generatedSource in ['GEMINI', 'GEMINI_REGENERATED']) {
    testWidgets(
        '$generatedSource Studio media -> actual AI result -> scheduled Planner flow',
        (tester) async {
      source = generatedSource;
      final file = XFile.fromData(
          Uint8List.fromList(base64Decode(
              'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aFocAAAAASUVORK5CYII=')),
          name: 'fixture.png',
          mimeType: 'image/png');
      await size(tester);
      await tester.pumpWidget(host(
          AiContentStudioPage(
              mediaPicker: () async => file,
              schedulePicker: () async =>
                  DateTime.now().add(const Duration(days: 1))),
          withScope: true));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('MEDYA SEÇ'));
      await tester.tap(find.text('MEDYA SEÇ'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('AI ile medyayı analiz et'));
      await tester.tap(find.text('AI ile medyayı analiz et'));
      await tester.pumpAndSettle();
      await scrollTo(tester, find.text('Saat seç • Kuyruğa al'));
      await tester.tap(find.text('Saat seç • Kuyruğa al'));
      await tester.pumpAndSettle();
      expect(posts.single['publishStatus'], 'QUEUED');
      expect(posts.single['nextPublishAt'], isNotNull);
      expect(mutations.where((path) => path == 'POST /api/posts').length, 1);
      expect(
          mutations
              .where((path) => path == 'POST /api/posts/fixture-post/queue')
              .length,
          1);
      await tester.tap(find.text('Kuyruk'));
      await tester.pumpAndSettle();
      await scrollTo(
          tester, find.byKey(const ValueKey('content-post-fixture-post')));
      expect(find.text('PLANLANDI'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop login brand panel scrolls with large text',
      (tester) async {
    await size(tester, width: 1100, height: 700);
    await tester.pumpWidget(MaterialApp(
        theme: ProductTheme.dark,
        home: const MediaQuery(
            data: MediaQueryData(
                size: Size(1100, 700), textScaler: TextScaler.linear(1.8)),
            child: LoginPage())));
    await tester.pumpAndSettle();
    expect(find.text('Tekrar hoş geldin'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape module loading and empty states scroll safely',
      (tester) async {
    Api.setHttpClientForTesting(MockClient((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 200));
      return http.Response(
          jsonEncode({
            'available': false,
            'metrics': {},
            'trend': [],
            'campaigns': []
          }),
          200,
          headers: {'content-type': 'application/json'});
    }));
    await size(tester, width: 800, height: 400);
    await tester.pumpWidget(host(const ProductReportsPage(), scale: 1.4));
    await tester.pump(const Duration(milliseconds: 50));
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
