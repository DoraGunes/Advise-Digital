import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:advise_digital/product_ui.dart';

double contrast(Color foreground, Color background) {
  final first = foreground.computeLuminance();
  final second = background.computeLuminance();
  return ((first > second ? first : second) + .05) /
      ((first < second ? first : second) + .05);
}

void main() {
  test('colorful theme keeps the playful palette distinct', () {
    final theme = ProductTheme.colorful;
    expect(theme.scaffoldBackgroundColor, const Color(0xFFEAFBFF));
    expect(theme.colorScheme.primary, const Color(0xFF6D4FE8));
    expect(theme.colorScheme.secondary, const Color(0xFF00A9B8));
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    for (final tone in ['success', 'warning', 'danger', 'ai', 'neutral']) {
      testWidgets('$brightness $tone status label contrast is at least 4.5',
          (tester) async {
        final theme = brightness == Brightness.dark
            ? ProductTheme.dark
            : ProductTheme.light;
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
  }
}
