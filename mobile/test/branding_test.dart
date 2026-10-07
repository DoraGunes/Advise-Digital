import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advise_digital/main.dart' show LoginPage;
import 'package:advise_digital/product_ui.dart';

void main() {
  testWidgets('canonical logo and app icon are bundled as actual PNG assets',
      (tester) async {
    await tester.runAsync(() async {
      for (final asset in [
        'assets/branding/advise_full_logo.png',
        'assets/branding/advise_app_icon.png'
      ]) {
        final bytes = (await rootBundle.load(asset)).buffer.asUint8List();
        expect(bytes.take(8).toList(), [137, 80, 78, 71, 13, 10, 26, 10]);
        final decoded = await decodeImageFromList(bytes);
        expect(decoded.width, decoded.height);
        decoded.dispose();
      }
    });
  });
  for (final theme in [ProductTheme.light, ProductTheme.dark]) {
    testWidgets('login uses canonical full logo in ${theme.brightness}',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester
          .pumpWidget(MaterialApp(theme: theme, home: const LoginPage()));
      await tester.pumpAndSettle();
      final images = tester.widgetList<Image>(find.byType(Image));
      expect(
          images.any((image) =>
              image.image is AssetImage &&
              (image.image as AssetImage).assetName ==
                  'assets/branding/advise_full_logo.png'),
          true);
      expect(tester.takeException(), isNull);
    });
  }
}
