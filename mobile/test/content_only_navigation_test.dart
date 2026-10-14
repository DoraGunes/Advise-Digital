import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:advise_digital/product_shell.dart';

void main() {
  testWidgets('content navigation exposes memory instead of ad creation', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: ProductShell(
      user: const {'role': 'ADMIN'}, onLogout: () async {},
      destinationBuilders: List.generate(5, (i) => () => Text('content tab $i')),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Reklamlar'), findsNothing);
    expect(find.text('İçerik Kuyruğu'), findsOneWidget);
    await tester.tap(find.text('Hafıza Sarayı'));
    await tester.pumpAndSettle();
    expect(find.text('content tab 2'), findsOneWidget);
  });
}
