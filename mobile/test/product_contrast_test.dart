import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:advise_digital/product_ui.dart';

double contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return ((first > second ? first : second) + .05) /
      ((first < second ? first : second) + .05);
}

void main() {
  test('fixed promotional gradient text remains readable at lightest stop', () {
    for (final pair in [
      (const Color(0xFF4F48AE), .76),
      (const Color(0xFF59627A), .84),
      (const Color(0xFF4E48A8), .84),
      (const Color(0xFF343063), .70),
      (const Color(0xFF4F48AE), .82),
      (const Color(0xFF4F46E5), .84),
    ]) {
      final paint =
          Color.alphaBlend(Colors.white.withValues(alpha: pair.$2), pair.$1);
      expect(contrast(paint, pair.$1), greaterThanOrEqualTo(4.5));
    }
  });
  final themes = {
    'Light': ProductTheme.light,
    'Dark': ProductTheme.dark,
    'Colorful': ProductTheme.colorful,
  };
  for (final entry in themes.entries) {
    final theme = entry.value;
    for (final tone in ['success', 'warning', 'danger', 'ai', 'neutral']) {
      testWidgets('${entry.key} $tone status label contrast is at least 4.5',
          (tester) async {
        await tester.pumpWidget(MaterialApp(
            theme: theme,
            home: Scaffold(
                body: Card(
                    child: ProductStatusChip(label: 'Durum', tone: tone)))));
        final foreground =
            tester.widget<Text>(find.text('Durum')).style!.color!;
        final chip = find.byType(ProductStatusChip);
        final container = tester.widget<Container>(
            find.descendant(of: chip, matching: find.byType(Container)));
        final paint = (container.decoration! as BoxDecoration).color!;
        final background = Color.alphaBlend(paint, theme.colorScheme.surface);
        expect(contrast(foreground, background), greaterThanOrEqualTo(4.5));
      });
    }
    test('${entry.key} semantic text/control pairs meet contrast minimums', () {
      final s = theme.colorScheme;
      final pairs = [
        (s.onSurface, s.surface),
        (s.onSurfaceVariant, s.surface),
        (s.onSurface, theme.scaffoldBackgroundColor),
        (s.onSurfaceVariant, theme.scaffoldBackgroundColor),
        (s.onSurface, s.surfaceContainerHighest),
        (s.onSurfaceVariant, s.surfaceContainerHighest),
        (s.onPrimary, s.primary),
        (s.onPrimaryContainer, s.primaryContainer),
        (s.onSecondary, s.secondary),
        (s.onSecondaryContainer, s.secondaryContainer),
        (s.onTertiary, s.tertiary),
        (s.onTertiaryContainer, s.tertiaryContainer),
        (s.error, s.surface),
        (s.onError, s.error),
        (s.onErrorContainer, s.errorContainer),
        (s.onInverseSurface, s.inverseSurface),
        (s.inversePrimary, s.inverseSurface),
      ];
      for (final pair in pairs) {
        expect(contrast(pair.$1, pair.$2), greaterThanOrEqualTo(4.5),
            reason: '${pair.$1} on ${pair.$2}');
      }
      expect(contrast(s.outline, s.surface), greaterThanOrEqualTo(3));
      final inputBorder =
          theme.inputDecorationTheme.enabledBorder! as OutlineInputBorder;
      expect(
          contrast(inputBorder.borderSide.color,
              theme.inputDecorationTheme.fillColor!),
          greaterThanOrEqualTo(3));
      expect(contrast(theme.textTheme.bodyMedium!.color!, s.surface),
          greaterThanOrEqualTo(4.5));
      expect(contrast(theme.textTheme.headlineLarge!.color!, s.surface),
          greaterThanOrEqualTo(4.5));
    });
    testWidgets('${entry.key} form dropdown dialog and snackbar are readable',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
              body: Builder(
                  builder: (context) => Column(children: [
                        const TextField(
                            decoration: InputDecoration(
                                labelText: 'Başlık', hintText: 'İçerik yazın')),
                        DropdownButton<String>(
                            value: 'POST',
                            items: const [
                              DropdownMenuItem(
                                  value: 'POST', child: Text('Gönderi'))
                            ],
                            onChanged: (_) {}),
                        FilledButton(
                            onPressed: () => showDialog<void>(
                                context: context,
                                builder: (_) => const AlertDialog(
                                    title: Text('Önizleme'),
                                    content: Text('WhatsApp ile iletişim'))),
                            child: const Text('Önizle')),
                        OutlinedButton(
                            onPressed: () => ScaffoldMessenger.of(context)
                                .showSnackBar(const SnackBar(
                                    content: Text('Kuyruğa alındı'))),
                            child: const Text('Kaydet')),
                      ])))));
      await tester.tap(find.text('Gönderi'));
      await tester.pumpAndSettle();
      final menuText = find.text('Gönderi').last;
      final style = DefaultTextStyle.of(tester.element(menuText)).style;
      expect(contrast(style.color!, theme.colorScheme.surface),
          greaterThanOrEqualTo(4.5));
      await tester.tap(menuText);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Önizle'));
      await tester.pumpAndSettle();
      final dialogStyle = DefaultTextStyle.of(
              tester.element(find.text('WhatsApp ile iletişim')))
          .style;
      expect(contrast(dialogStyle.color!, theme.dialogTheme.backgroundColor!),
          greaterThanOrEqualTo(4.5));
      Navigator.of(tester.element(find.byType(AlertDialog))).pop();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Kaydet'));
      await tester.pumpAndSettle();
      final snackStyle =
          DefaultTextStyle.of(tester.element(find.text('Kuyruğa alındı')))
              .style;
      expect(contrast(snackStyle.color!, theme.snackBarTheme.backgroundColor!),
          greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
    });
  }
  for (final mode in ProductThemeMode.values) {
    test('theme ${mode.name} survives preference reload', () async {
      SharedPreferences.setMockInitialValues({});
      await ProductThemeController.set(mode);
      ProductThemeController.mode.value = ProductThemeMode.system;
      await ProductThemeController.load();
      expect(ProductThemeController.mode.value, mode);
    });
  }
  test('existing dark preference migrates and unknown value uses system',
      () async {
    SharedPreferences.setMockInitialValues({'productTheme': 'dark'});
    await ProductThemeController.load();
    expect(ProductThemeController.mode.value, ProductThemeMode.dark);
    SharedPreferences.setMockInitialValues({'productTheme': 'obsolete'});
    await ProductThemeController.load();
    expect(ProductThemeController.mode.value, ProductThemeMode.system);
  });
}
