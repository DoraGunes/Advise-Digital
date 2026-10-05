import 'package:flutter/material.dart';

import 'api.dart';
import 'product_dashboard.dart';
import 'product_more.dart';
import 'product_modules.dart';
import 'product_onboarding.dart';
import 'product_ui.dart';
import 'v14_ai.dart';
import 'content_queue_page.dart';

enum ProductDestination { home, studio, ads, planner, more }

class ProductNavigation extends InheritedWidget {
  final void Function(ProductDestination) go;
  final Future<void> Function(Widget) open;
  final Map<String, dynamic> user, tenant;
  final Future<void> Function() onLogout;
  const ProductNavigation(
      {super.key,
      required this.go,
      required this.open,
      required this.user,
      required this.tenant,
      required this.onLogout,
      required super.child});
  static ProductNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProductNavigation>();
  static ProductNavigation of(BuildContext context) => maybeOf(context)!;
  bool get isAdmin => user['role'] == 'ADMIN';
  bool get canManage =>
      const ['ADMIN', 'CUSTOMER_ADMIN'].contains(user['role']);
  bool get canOperate => const [
        'ADMIN',
        'CUSTOMER_ADMIN',
        'MANAGER',
        'OPERATOR'
      ].contains(user['role']);
  @override
  bool updateShouldNotify(ProductNavigation oldWidget) =>
      oldWidget.user != user || oldWidget.tenant != tenant;
}

class ProductShell extends StatefulWidget {
  final Map<String, dynamic> user, tenant;
  final Future<void> Function() onLogout;
  final List<Widget Function()>? destinationBuilders;
  const ProductShell(
      {super.key,
      required this.user,
      this.tenant = const {},
      required this.onLogout,
      this.destinationBuilders})
      : assert(destinationBuilders == null || destinationBuilders.length == 5);
  @override
  State<ProductShell> createState() => _ProductShellState();
}

class _ProductShellState extends State<ProductShell> {
  final _keys = List.generate(5, (_) => GlobalKey<NavigatorState>());
  final _visited = <int>{0};
  final _canPop = List.filled(5, false);
  int _selected = 0;
  static const _labels = [
    'Ana Sayfa',
    'AI Studio',
    'Reklamlar',
    'Plan',
    'Daha Fazla'
  ];
  static const _icons = [
    Icons.space_dashboard_outlined,
    Icons.auto_awesome_outlined,
    Icons.campaign_outlined,
    Icons.calendar_month_outlined,
    Icons.grid_view_rounded
  ];
  static const _activeIcons = [
    Icons.space_dashboard_rounded,
    Icons.auto_awesome_rounded,
    Icons.campaign_rounded,
    Icons.calendar_month_rounded,
    Icons.grid_view_rounded
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _firstRun());
  }

  Future<void> _firstRun() async {
    if (widget.user['role'] != 'CUSTOMER_ADMIN') return;
    try {
      final compatibility = await Api.compatibility();
      final capabilities = compatibility['capabilities'];
      final hasOnboarding = capabilities is Map
          ? capabilities['onboarding'] == true
          : capabilities is List && capabilities.contains('onboarding');
      if (!hasOnboarding) return;
      final profile = await Api.productOnboarding();
      if (!mounted ||
          profile['completed'] == true ||
          profile['updatedAt'] != null ||
          (profile['step'] as num? ?? 0) > 0) return;
      await _open(const ProductOnboardingPage());
    } catch (_) {
      // Dashboard carries connection/compatibility feedback without blocking entry.
    }
  }

  void _go(ProductDestination destination) {
    setState(() {
      _selected = destination.index;
      _visited.add(_selected);
    });
  }

  Future<void> _open(Widget page) async {
    await _keys[_selected]
        .currentState
        ?.push(MaterialPageRoute<void>(builder: (_) => page));
  }

  Widget _root(int index) => widget.destinationBuilders != null
      ? widget.destinationBuilders![index]()
      : switch (index) {
          1 => const AiContentStudioPage(),
          2 => const AdsCenterPage(),
          3 => const ContentQueuePage(),
          4 => const ProductMorePage(),
          _ => const ProductDashboardPage(),
        };

  Widget _navigationBody() => Stack(children: [
        for (final index in _visited)
          Offstage(
              offstage: index != _selected,
              child: TickerMode(
                  enabled: index == _selected,
                  child: Navigator(
                    key: _keys[index],
                    observers: [
                      _ShellObserver(onChange: () {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (!mounted) return;
                          final next =
                              _keys[index].currentState?.canPop() ?? false;
                          if (_canPop[index] != next)
                            setState(() => _canPop[index] = next);
                        });
                      })
                    ],
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: (_) => _root(index)),
                  ))),
      ]);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final scope = ProductNavigation(
      go: _go,
      open: _open,
      user: widget.user,
      tenant: widget.tenant,
      onLogout: widget.onLogout,
      child: LayoutBuilder(builder: (context, bounds) {
        final mobile = bounds.maxWidth < 600;
        final desktop = bounds.maxWidth >= 1024;
        return PopScope(
          canPop: !_canPop[_selected] && _selected == 0,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_keys[_selected].currentState?.canPop() ?? false) {
              _keys[_selected].currentState!.pop();
            } else {
              _go(ProductDestination.home);
            }
          },
          child: Scaffold(
            body: Row(children: [
              if (!mobile) ...[
                if (desktop)
                  _sidebar(context)
                else
                  SafeArea(
                      child: NavigationRail(
                    selectedIndex: _selected,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) =>
                        _go(ProductDestination.values[i]),
                    leading: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: _logo(40)),
                    trailing: Expanded(
                        child: Align(
                            alignment: Alignment.bottomCenter,
                            child: IconButton(
                                tooltip: dark ? 'Açık tema' : 'Koyu tema',
                                onPressed: () =>
                                    ProductThemeController.toggle(context),
                                icon: Icon(dark
                                    ? Icons.light_mode_outlined
                                    : Icons.dark_mode_outlined)))),
                    destinations: List.generate(
                        5,
                        (i) => NavigationRailDestination(
                            icon: Icon(_icons[i]),
                            selectedIcon: Icon(_activeIcons[i]),
                            label: Text(_labels[i]))),
                  )),
                const VerticalDivider(width: 1),
              ],
              Expanded(
                  child: Column(children: [
                if (desktop) _topBar(context),
                Expanded(child: _navigationBody()),
              ])),
            ]),
            bottomNavigationBar: mobile
                ? NavigationBar(
                    selectedIndex: _selected,
                    onDestinationSelected: (i) =>
                        _go(ProductDestination.values[i]),
                    destinations: List.generate(
                        5,
                        (i) => NavigationDestination(
                            icon: Icon(_icons[i]),
                            selectedIcon: Icon(_activeIcons[i]),
                            label: _labels[i])),
                  )
                : null,
          ),
        );
      }),
    );
    return scope;
  }

  Widget _logo(double size) => ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.asset('assets/advise_logo.jpg',
          width: size, height: size, fit: BoxFit.cover));

  Widget _sidebar(BuildContext context) => SizedBox(
        width: 244,
        child: Material(
            color: Theme.of(context).colorScheme.surface,
            child: SafeArea(
                child: Column(children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 28),
              child: Row(children: [
                _logo(44),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('AdVise',
                          style: Theme.of(context).textTheme.titleLarge),
                      Text('Digital',
                          style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              letterSpacing: 2,
                              fontSize: 11))
                    ]))
              ])),
          for (var i = 0; i < 5; i++)
            Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: ListTile(
                  minVerticalPadding: 14,
                  selected: i == _selected,
                  selectedTileColor: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: .55),
                  selectedColor: Theme.of(context).colorScheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: Icon(i == _selected ? _activeIcons[i] : _icons[i],
                      size: 22),
                  title: Text(_labels[i],
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  onTap: () => _go(ProductDestination.values[i]),
                )),
          const Spacer(),
          if (widget.user['role'] == 'ADMIN')
            const Padding(
                padding: EdgeInsets.all(16),
                child: ProductStatusChip(
                    label: 'Sistem yöneticisi', tone: 'warning')),
          Padding(
              padding: const EdgeInsets.all(16),
              child: ProductInsightCard(
                  title: 'AdVise öğreniyor',
                  body:
                      'İçerik ve kampanya sonuçların bir sonraki öneriyi geliştirir.')),
          ListTile(
              leading: const Icon(Icons.logout_rounded),
              title: const Text('Çıkış yap'),
              onTap: widget.onLogout),
          const SizedBox(height: 12),
        ]))),
      );

  Widget _topBar(BuildContext context) => Container(
        height: 72,
        padding: const EdgeInsets.symmetric(horizontal: 28),
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(
                bottom: BorderSide(color: Theme.of(context).dividerColor))),
        child: Row(children: [
          Expanded(
              child: Text(
                  widget.tenant['companyName']?.toString() ?? 'Çalışma alanı',
                  style: Theme.of(context).textTheme.titleMedium)),
          IconButton(
              tooltip: Theme.of(context).brightness == Brightness.dark
                  ? 'Açık tema'
                  : 'Koyu tema',
              onPressed: () => ProductThemeController.toggle(context),
              icon: const Icon(Icons.contrast_rounded)),
          IconButton(
              tooltip: 'Bildirimler',
              onPressed: () => _open(const ProductNotificationsPage()),
              icon: const Icon(Icons.notifications_none_rounded)),
          const SizedBox(width: 12),
          CircleAvatar(
              radius: 18,
              child: Text(
                  (widget.user['fullName']?.toString().isNotEmpty ?? false)
                      ? widget.user['fullName']
                          .toString()
                          .substring(0, 1)
                          .toUpperCase()
                      : 'A')),
          const SizedBox(width: 10),
          Text(widget.user['fullName']?.toString() ??
              widget.user['username']?.toString() ??
              'Hesabım'),
        ]),
      );
}

class _ShellObserver extends NavigatorObserver {
  final VoidCallback onChange;
  _ShellObserver({required this.onChange});
  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();
  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      onChange();
}
