import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advise_digital/api.dart';
import 'package:advise_digital/product_dashboard.dart';
import 'package:advise_digital/product_onboarding.dart';
import 'package:advise_digital/product_ui.dart';

void main() {
  testWidgets('dashboard reads persisted queue status and scheduled timestamp',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1360, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: ProductTheme.light,
        home: ProductDashboardPage(
          compatibilityLoader: () async => {
            'capabilities': {'productOverview': true}
          },
          overviewLoader: () async => {
            'metaConnected': true,
            'currency': 'USD',
            'metrics': {
              'spend': 12.5,
              'activeAds': 1,
              'messages': 2,
              'cpa': 6.25
            },
            'dailyBrief': {
              'summary': ['Gerçek veriden hazırlanan test özeti.']
            },
            'posts': [
              {
                'id': 'queue-fixture',
                'title': 'Planlanmış içerik test kaydı',
                'publishStatus': 'QUEUED',
                'nextPublishAt': '2027-01-03T16:30:00Z',
                'mediaType': 'REELS'
              }
            ],
            'trend': [],
            'campaigns': [],
            'logs': [],
            'notifications': [],
            'leads': [],
          },
        )));
    await tester.pumpAndSettle();
    expect(find.text('12,50 USD'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Sıradaki içerik'), 300);
    await tester.pumpAndSettle();
    expect(find.text('Planlanmış içerik test kaydı'), findsOneWidget);
    expect(find.text('Zaman seçilmedi'), findsNothing);
    expect(find.text('Henüz planlanmış içerik yok.'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'onboarding offers a real strategy request without Meta mutations',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    Api.resetRuntimeForTesting();
    final mutations = <String>[];
    Api.setHttpClientForTesting(MockClient((request) async {
      if (request.method != 'GET') mutations.add(request.url.path);
      final dynamic response = switch (request.url.path) {
        '/health' => {
            'ok': true,
            'version': '16.0.0',
            'capabilities': {
              'productExperience': true,
              'campaignStrategy': true
            }
          },
        '/api/product/onboarding' => {
            'businessName': 'Fixture işletme',
            'industry': 'Teknik servis',
            'goal': 'WhatsApp mesajı',
            'dailyBudget': 150,
            'locationMode': 'COUNTRY',
            'locations': [],
            'step': 4,
            'connection': {
              'meta': true,
              'page': true,
              'instagram': true,
              'adAccount': true
            }
          },
        '/api/product/strategy' => {
            'available': true,
            'source': 'GEMINI',
            'strategy': {
              'hook': 'Fixture işletme önerisi',
              'creative': {'angle': 'Hizmet kalitesi'},
              'audience': {'description': 'Yerel hizmet arayanlar'},
              'reasons': ['İşletmenin hedefi WhatsApp görüşmesi.']
            }
          },
        _ => {'mode': 'COUNTRY', 'locations': [], 'cities': [], 'regions': []}
      };
      return http.Response(jsonEncode(response), 200,
          headers: {'content-type': 'application/json'});
    }));
    addTearDown(() {
      Api.setHttpClientForTesting(null);
      Api.resetRuntimeForTesting();
    });
    await tester.binding.setSurfaceSize(const Size(320, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
        theme: ProductTheme.light,
        home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.4)),
            child: const ProductOnboardingPage())));
    await tester.pumpAndSettle();
    final analyzeButton = find.ancestor(
        of: find.text('AI başlangıç önerisi al'),
        matching: find.byType(OutlinedButton));
    await tester.ensureVisible(analyzeButton);
    await tester.pumpAndSettle();
    await tester.tap(analyzeButton);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Gemini başlangıç önerisi'));
    await tester.pumpAndSettle();
    expect(find.text('Gemini başlangıç önerisi'), findsOneWidget);
    expect(mutations, ['/api/product/strategy']);
    expect(tester.takeException(), isNull);
  });
}
