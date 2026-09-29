import 'package:flutter_test/flutter_test.dart';

import 'package:advise_digital/main.dart';

void main() {
  testWidgets('Advise Digital login ekranı açılır', (WidgetTester tester) async {
    await tester.pumpWidget(const AdviseDigitalApp());
    await tester.pumpAndSettle();

    expect(find.text('ADVISE DIGITAL'), findsOneWidget);
    expect(find.text('Reklam yönetimi • optimizasyon • otomasyon'), findsOneWidget);
    expect(find.text('Kullanıcı adı'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
  });
}
