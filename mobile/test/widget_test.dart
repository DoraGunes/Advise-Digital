import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:advise_digital/main.dart';

void main() {
  testWidgets('Advise Digital login ekranı açılır',
      (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const AdviseDigitalApp());
    await tester.pumpAndSettle();

    expect(find.text('AdVise'), findsOneWidget);
    expect(find.text('Çalışma alanına güvenli giriş yap.'), findsOneWidget);
    expect(find.text('Kullanıcı adı'), findsOneWidget);
    expect(find.text('Şifre'), findsOneWidget);
  });
}
