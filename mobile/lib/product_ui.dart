import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_error.dart';

abstract final class ProductColors {
  static const navy = Color(0xFF171C32);
  static const indigo = Color(0xFF6556E8);
  static const cyan = Color(0xFF1889B7);
  static const success = Color(0xFF16845B);
  static const warning = Color(0xFFB57212);
  static const danger = Color(0xFFC44747);
  static const background = Color(0xFFF5F6FA);
  static const border = Color(0xFFE5E7EF);
}

abstract final class ProductSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const radius = 18.0;
  static const controlHeight = 48.0;
}

abstract final class ProductTheme {
  static ThemeData get light => _create(Brightness.light);
  static ThemeData get dark => _create(Brightness.dark);
  static ThemeData get colorful => _create(Brightness.light, colorful: true);

  static ThemeData _create(Brightness brightness, {bool colorful = false}) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: ProductColors.indigo,
      brightness: brightness,
      surface: dark ? const Color(0xFF202639) : Colors.white,
    ).copyWith(
      onSurface: dark ? const Color(0xFFEAEAF3) : ProductColors.navy,
      onSurfaceVariant:
          dark ? const Color(0xFFC2C6D8) : const Color(0xFF50566A),
      outline: dark ? const Color(0xFF929AAF) : const Color(0xFF747A8F),
      outlineVariant: dark ? const Color(0xFF535D75) : const Color(0xFFB7BDCD),
      secondary: colorful ? const Color(0xFF006B62) : null,
      onSecondary: colorful ? Colors.white : null,
      secondaryContainer: colorful ? const Color(0xFFB5F2E6) : null,
      onSecondaryContainer: colorful ? const Color(0xFF003B34) : null,
      tertiary: colorful ? const Color(0xFF952957) : null,
      onTertiary: colorful ? Colors.white : null,
      tertiaryContainer: colorful ? const Color(0xFFFFD9E7) : null,
      onTertiaryContainer: colorful ? const Color(0xFF53052B) : null,
    );
    final base = ThemeData(useMaterial3: true, colorScheme: scheme);
    final text = base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
              fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -1),
          headlineMedium: const TextStyle(
              fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.7),
          titleLarge: const TextStyle(
              fontSize: 22, fontWeight: FontWeight.w700, letterSpacing: -.4),
          titleMedium:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          bodyLarge: const TextStyle(fontSize: 15, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.45),
          labelLarge:
              const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
        )
        .apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);
    final border = scheme.outlineVariant;
    final background = dark
        ? const Color(0xFF151A29)
        : colorful
            ? const Color(0xFFFFF6D9)
            : ProductColors.background;
    return base.copyWith(
      textTheme: text,
      scaffoldBackgroundColor: background,
      iconTheme: IconThemeData(color: scheme.onSurfaceVariant),
      disabledColor: scheme.onSurfaceVariant,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        titleTextStyle: text.titleLarge,
      ),
      cardTheme: CardThemeData(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ProductSpacing.radius),
            side: BorderSide(color: border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
        helperStyle: TextStyle(color: scheme.onSurfaceVariant),
        errorStyle: TextStyle(color: scheme.error),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outline)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.outline)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: scheme.primary, width: 1.5)),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, ProductSpacing.controlHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        side: BorderSide(color: scheme.outline),
        minimumSize: const Size(48, ProductSpacing.controlHeight),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      )),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        height: 72,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primaryContainer,
        labelTextStyle: WidgetStateProperty.resolveWith((states) =>
            text.labelSmall!.copyWith(
                color: states.contains(WidgetState.selected)
                    ? scheme.onSurface
                    : scheme.onSurfaceVariant)),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            color: states.contains(WidgetState.selected)
                ? scheme.onPrimaryContainer
                : scheme.onSurfaceVariant)),
      ),
      navigationRailTheme: NavigationRailThemeData(
          backgroundColor: scheme.surface,
          indicatorColor: scheme.primaryContainer,
          selectedIconTheme: IconThemeData(color: scheme.onPrimaryContainer),
          unselectedIconTheme: IconThemeData(color: scheme.onSurfaceVariant),
          selectedLabelTextStyle: TextStyle(color: scheme.onSurface),
          unselectedLabelTextStyle: TextStyle(color: scheme.onSurfaceVariant)),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: scheme.inverseSurface,
          contentTextStyle: TextStyle(color: scheme.onInverseSurface),
          actionTextColor: scheme.inversePrimary),
      tooltipTheme: TooltipThemeData(
          decoration: BoxDecoration(
              color: scheme.inverseSurface,
              borderRadius: BorderRadius.circular(8)),
          textStyle: TextStyle(color: scheme.onInverseSurface)),
      dropdownMenuTheme: DropdownMenuThemeData(
          textStyle: TextStyle(color: scheme.onSurface),
          menuStyle: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(scheme.surface))),
      dialogTheme: DialogThemeData(
          backgroundColor: scheme.surface,
          titleTextStyle: text.titleLarge,
          contentTextStyle: text.bodyMedium,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
        TargetPlatform.fuchsia: FadeUpwardsPageTransitionsBuilder(),
      }),
    );
  }
}

enum ProductThemeMode {
  system,
  light,
  dark,
  colorful;

  ThemeMode get materialMode => switch (this) {
        ProductThemeMode.system => ThemeMode.system,
        ProductThemeMode.dark => ThemeMode.dark,
        _ => ThemeMode.light,
      };
}

abstract final class ProductThemeController {
  static final mode = ValueNotifier<ProductThemeMode>(ProductThemeMode.system);
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString('productTheme');
    mode.value = ProductThemeMode.values.firstWhere((e) => e.name == stored,
        orElse: () => ProductThemeMode.system);
  }

  static Future<void> set(ProductThemeMode value) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString('productTheme', value.name)) {
      throw StateError('Görünüm tercihi kaydedilemedi.');
    }
    mode.value = value;
  }

  static Future<void> change(
      BuildContext context, ProductThemeMode value) async {
    try {
      await set(value);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Görünüm tercihi kaydedilemedi. Tekrar deneyin.')));
      }
    }
  }

  static void toggle(BuildContext context) => change(
      context,
      Theme.of(context).brightness == Brightness.dark
          ? ProductThemeMode.light
          : ProductThemeMode.dark);
}

String productFriendlyError(Object? error) => AppError.message(error);

class ProductContent extends StatelessWidget {
  final Widget child;
  final double maxWidth;
  const ProductContent({super.key, required this.child, this.maxWidth = 1280});
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth), child: child));
}

class ProductSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const ProductSurface(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(20)});
  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: padding, child: child));
}

class ProductPageHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  const ProductPageHeader(
      {super.key, required this.title, this.subtitle, this.actions = const []});
  @override
  Widget build(BuildContext context) => LayoutBuilder(builder: (context, size) {
        final heading =
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineMedium),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant))
          ],
        ]);
        return size.maxWidth < 650
            ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                heading,
                if (actions.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Wrap(spacing: 8, runSpacing: 8, children: actions)
                ]
              ])
            : Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(child: heading),
                const SizedBox(width: 16),
                ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: size.maxWidth * .48),
                    child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.end,
                        children: actions))
              ]);
      });
}

class ProductMetricCard extends StatelessWidget {
  final String label, value;
  final String? detail;
  final IconData icon;
  const ProductMetricCard(
      {super.key,
      required this.label,
      required this.value,
      this.detail,
      required this.icon});
  @override
  Widget build(BuildContext context) => ProductSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant))),
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary)
        ]),
        const SizedBox(height: 12),
        Text(value, style: Theme.of(context).textTheme.headlineMedium),
        if (detail != null) ...[
          const SizedBox(height: 4),
          Text(detail!, style: Theme.of(context).textTheme.bodySmall)
        ],
      ]));
}

class ProductStatusChip extends StatelessWidget {
  final String label, tone;
  const ProductStatusChip(
      {super.key, required this.label, this.tone = 'neutral'});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (tone) {
      'success' => dark ? const Color(0xFF68DAAE) : const Color(0xFF087148),
      'warning' => dark ? const Color(0xFFE9BB68) : const Color(0xFF87530A),
      'danger' => dark ? const Color(0xFFF99AA7) : const Color(0xFFA42E35),
      'ai' => dark ? const Color(0xFFBEB2FF) : const Color(0xFF5944C8),
      _ => Theme.of(context).colorScheme.onSurfaceVariant
    };
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .1),
            borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                color: color, fontSize: 11, fontWeight: FontWeight.w700)));
  }
}

class ProductEmptyState extends StatelessWidget {
  final String title, body;
  final IconData icon;
  final Widget? action;
  const ProductEmptyState(
      {super.key,
      required this.title,
      required this.body,
      this.icon = Icons.inbox_outlined,
      this.action});
  @override
  Widget build(BuildContext context) => ProductSurface(
      child: SizedBox(
          width: double.infinity,
          child: Column(children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 12),
            Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            if (action != null) ...[const SizedBox(height: 16), action!],
          ])));
}

class ProductErrorState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;
  const ProductErrorState({super.key, required this.message, this.onRetry});
  @override
  Widget build(BuildContext context) => ProductEmptyState(
      title: 'Bir sorun oluştu',
      body: message,
      icon: Icons.cloud_off_outlined,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Tekrar dene')));
}

class ProductLoadingSkeleton extends StatelessWidget {
  final int count;
  const ProductLoadingSkeleton({super.key, this.count = 3});
  @override
  Widget build(BuildContext context) => Semantics(
      label: 'Veriler yükleniyor',
      child: Column(
          children: List.generate(
              count,
              (i) => Container(
                  height: i == 0 ? 100 : 160,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                      color:
                          Theme.of(context).colorScheme.surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(ProductSpacing.radius))))));
}

class ProductInsightCard extends StatelessWidget {
  final String title, body;
  final IconData icon;
  final Widget? action;
  const ProductInsightCard(
      {super.key,
      required this.title,
      required this.body,
      this.icon = Icons.auto_awesome_rounded,
      this.action});
  @override
  Widget build(BuildContext context) => ProductSurface(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon,
                color: Theme.of(context).colorScheme.onPrimaryContainer)),
        const SizedBox(width: 14),
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body),
          if (action != null) ...[const SizedBox(height: 12), action!]
        ])),
      ]));
}
