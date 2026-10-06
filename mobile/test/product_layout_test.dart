import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:advise_digital/main.dart';
import 'package:advise_digital/product_dashboard.dart';
import 'package:advise_digital/product_more.dart';
import 'package:advise_digital/product_shell.dart';
import 'package:advise_digital/product_ui.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget app(Widget child) => MaterialApp(
      theme: ProductTheme.light, darkTheme: ProductTheme.dark, home: child);
  Widget shell() => app(ProductShell(
        user: const {'role': 'VIEWER', 'fullName': 'Test Kullanıcı'},
        tenant: const {'companyName': 'Test İşletme'},
        onLogout: () async {},
        destinationBuilders: List.generate(
            5,
            (index) => () => Scaffold(
                  appBar: AppBar(title: Text('Bölüm $index')),
                  body: Builder(
                      builder: (context) => Center(
                              child: FilledButton(
                            onPressed: () => ProductNavigation.of(context).open(
                                const Scaffold(
                                    body:
                                        Center(child: Text('Detay sayfası')))),
                            child: const Text('Detayı aç'),
                          ))),
                )),
      ));

  testWidgets('mobile primary navigation remains visible on nested routes',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('Detayı aç'));
    await tester.pumpAndSettle();
    expect(find.text('Detay sayfası'), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
    await tester.tap(find.text('AI Studio'));
    await tester.pumpAndSettle();
    expect(find.text('Bölüm 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tablet uses rail and desktop uses sidebar', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(shell());
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    await tester.binding.setSurfaceSize(const Size(1360, 900));
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsNothing);
    expect(find.text('Test İşletme'), findsOneWidget);
    expect(find.text('Çıkış yap'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('premium login supports small screen and text scaling',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(const MediaQuery(
        data: MediaQueryData(
            size: Size(320, 640), textScaler: TextScaler.linear(1.4)),
        child: LoginPage())));
    await tester.pumpAndSettle();
    expect(find.text('Kullanıcı adı'), findsOneWidget);
    expect(find.text('Beni hatırla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard shows absent real metrics as unavailable',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(ProductDashboardPage(
      compatibilityLoader: () async => {
        'capabilities': ['productOverview']
      },
      overviewLoader: () async => {
        'metaConnected': false,
        'metrics': {
          'spend': null,
          'activeAds': null,
          'messages': null,
          'cpa': null
        },
        'posts': [],
        'campaigns': [],
        'trend': [],
        'logs': []
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Bugün ne durumda?'), findsOneWidget);
    expect(find.text('—'), findsNWidgets(4));
    expect(find.text('0 TL'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tenant More menu excludes Super Admin controls', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1360, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(app(ProductNavigation(
      user: const {'role': 'VIEWER'},
      tenant: const {},
      go: (_) {},
      open: (_) async {},
      onLogout: () async {},
      child: const ProductMorePage(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Müşteri hesapları'), findsNothing);
    expect(find.text('Lisanslar'), findsNothing);
    expect(find.text('Ekip'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
