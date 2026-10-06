import 'package:flutter/material.dart';

import 'api.dart';
import 'product_modules.dart';
import 'product_onboarding.dart';
import 'product_shell.dart';
import 'product_ui.dart';
import 'v78_pages.dart' show MetaConnectionPage;

class ProductDashboardPage extends StatefulWidget {
  final Future<Map<String, dynamic>> Function()? overviewLoader;
  final Future<Map<String, dynamic>> Function()? compatibilityLoader;
  const ProductDashboardPage(
      {super.key, this.overviewLoader, this.compatibilityLoader});
  @override
  State<ProductDashboardPage> createState() => _ProductDashboardPageState();
}

class _ProductDashboardPageState extends State<ProductDashboardPage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error, compatibilityMessage;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final compatibility =
          await (widget.compatibilityLoader ?? Api.compatibility)();
      final capabilities = compatibility['capabilities'];
      final supported = capabilities is Map
          ? capabilities['productOverview'] == true
          : capabilities is List && capabilities.contains('productOverview');
      compatibilityMessage = supported
          ? null
          : 'Sunucunun yeni ürün sürümü henüz etkin değil. Yayın planlama ve yeni analizler için sunucu güncellenmeli.';
      final overview = widget.overviewLoader != null
          ? await widget.overviewLoader!()
          : supported
              ? await Api.productOverview()
              : await _legacyOverview();
      if (mounted) setState(() => data = overview);
    } catch (e) {
      if (mounted) setState(() => error = productFriendlyError(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<Map<String, dynamic>> _legacyOverview() async {
    final legacy = await Api.dashboard();
    final ads = _list(legacy['ads']);
    final posts = _list(legacy['posts']);
    final scheduled = posts
        .where((p) => const ['QUEUED', 'RETRY'].contains(p['publishStatus']))
        .length;
    return {
      'metaConnected': legacy['metaAvailable'] == true,
      'metrics': {
        'activeAds': legacy['metaAvailable'] == true
            ? ads
                .where((a) =>
                    a['effective_status'] == 'ACTIVE' ||
                    a['status'] == 'ACTIVE')
                .length
            : null
      },
      'campaigns': legacy['campaigns'] ?? [],
      'posts': posts,
      'logs': legacy['logs'] ?? [],
      'dailyBrief': {
        'summary': [
          if (legacy['metaAvailable'] == true)
            '${ads.length} reklam hesabından alınan kayıtlarda görünüyor.',
          if (scheduled > 0) '$scheduled içerik yayın için planlandı.',
          if (legacy['metaAvailable'] != true)
            'Meta bağlantısı tamamlandığında reklam performansın burada görünecek.'
        ]
      },
      'trend': [],
      'leads': [],
      'notifications': [],
    };
  }

  List<Map<String, dynamic>> _list(dynamic value) => value is List
      ? value.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
      : [];
  Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : {};
  String _metric(dynamic value, {bool money = false, bool percent = false}) {
    final number = value is num
        ? value.toDouble()
        : double.tryParse(value?.toString() ?? '');
    if (number == null) return '—';
    final formatted = number == number.roundToDouble()
        ? number.toStringAsFixed(0)
        : number.toStringAsFixed(2);
    final currency = data['currency']?.toString() ?? 'TRY';
    return '${formatted.replaceAll('.', ',')}${money ? ' ${currency == 'TRY' ? 'TL' : currency}' : percent ? '%' : ''}';
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (date == null) return 'Zaman seçilmedi';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(date.day)}.${two(date.month)} • ${two(date.hour)}:${two(date.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final navigation = ProductNavigation.maybeOf(context);
    final metrics = _map(data['metrics']);
    final posts = _list(data['posts']);
    final queued = posts
        .where((p) => const ['QUEUED', 'RETRY', 'PUBLISHING', 'RECONCILE']
            .contains(p['publishStatus']))
        .toList()
      ..sort((a, b) => (a['nextPublishAt']?.toString() ?? '')
          .compareTo(b['nextPublishAt']?.toString() ?? ''));
    final campaigns = _list(data['campaigns']);
    final brief = _map(data['dailyBrief'])['summary'];
    final briefLines =
        brief is List ? brief.map((e) => e.toString()).toList() : <String>[];
    final recommendations = _list(data['recommendations']);
    final notifications = _list(data['notifications']);
    final leads = _list(data['leads']);
    final logs = _list(data['logs']);
    final onboarding = _map(data['onboarding']);
    final trend = _list(data['trend']);
    return Scaffold(
      appBar: MediaQuery.sizeOf(context).width < 1024
          ? AppBar(
              title: Text(
                  navigation?.tenant['companyName']?.toString() ?? 'AdVise'),
              actions: [
                IconButton(
                    tooltip: 'Bildirimler',
                    onPressed: () =>
                        navigation?.open(const ProductNotificationsPage()),
                    icon: Badge(
                        isLabelVisible:
                            notifications.any((n) => n['read'] != true),
                        child: const Icon(Icons.notifications_none_rounded))),
                IconButton(
                    tooltip: 'Yenile',
                    onPressed: loading ? null : _load,
                    icon: const Icon(Icons.refresh_rounded)),
              ],
            )
          : null,
      body: ProductContent(
          child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.all(
                    MediaQuery.sizeOf(context).width < 600 ? 16 : 28),
                children: [
                  ProductPageHeader(
                      title: 'Bugün ne durumda?',
                      subtitle: 'İşletmenin reklam ve içerik özeti.',
                      actions: [
                        FilledButton.icon(
                            onPressed: navigation == null
                                ? null
                                : () =>
                                    navigation.go(ProductDestination.studio),
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('İçerik hazırla')),
                        if (MediaQuery.sizeOf(context).width >= 1024)
                          IconButton(
                              tooltip: 'Yenile',
                              onPressed: loading ? null : _load,
                              icon: const Icon(Icons.refresh_rounded)),
                      ]),
                  const SizedBox(height: 24),
                  if (loading)
                    const ProductLoadingSkeleton()
                  else if (error != null)
                    ProductErrorState(message: error!, onRetry: _load)
                  else ...[
                    if (compatibilityMessage != null) ...[
                      ProductInsightCard(
                          title: 'Sunucu güncellemesi gerekiyor',
                          body: compatibilityMessage!,
                          icon: Icons.system_update_outlined),
                      const SizedBox(height: 16)
                    ],
                    if (data['metaConnected'] != true) ...[
                      ProductInsightCard(
                          title: 'Reklam verilerin için Meta hesabını bağla',
                          body:
                              'İçeriklerini hazırlayabilirsin. Harcama ve mesaj sonuçları doğrulanmış bağlantıdan gelir.',
                          icon: Icons.link_outlined,
                          action: OutlinedButton(
                              onPressed: navigation == null
                                  ? null
                                  : () => navigation
                                      .open(const MetaConnectionPage()),
                              child: const Text('Bağlantıyı kontrol et'))),
                      const SizedBox(height: 16),
                    ],
                    if (navigation?.canManage == true &&
                        onboarding.isNotEmpty &&
                        onboarding['completed'] != true) ...[
                      ProductInsightCard(
                          title: 'İşletme kurulumunu tamamla',
                          body:
                              'Hedefini, bölgelerini ve bütçeni belirle. AdVise önerilerini işletmene göre hazırlasın.',
                          icon: Icons.checklist_rounded,
                          action: OutlinedButton(
                              onPressed: () async {
                                await navigation!
                                    .open(const ProductOnboardingPage());
                                if (mounted) _load();
                              },
                              child: const Text('Kuruluma devam et'))),
                      const SizedBox(height: 16),
                    ],
                    LayoutBuilder(builder: (context, box) {
                      final columns = box.maxWidth >= 900
                          ? 4
                          : box.maxWidth >= 360
                              ? 2
                              : 1;
                      final width =
                          (box.maxWidth - (columns - 1) * 12) / columns;
                      final cards = [
                        ProductMetricCard(
                            label: 'Bugünkü harcama',
                            value: _metric(metrics['spend'], money: true),
                            detail: metrics['spend'] == null
                                ? 'Veri henüz alınamadı'
                                : 'Meta hesabı',
                            icon: Icons.account_balance_wallet_outlined),
                        ProductMetricCard(
                            label: 'Aktif reklamlar',
                            value: _metric(metrics['activeAds']),
                            detail: 'Hesabındaki aktif reklamlar',
                            icon: Icons.campaign_outlined),
                        ProductMetricCard(
                            label: 'Mesaj / sonuç',
                            value: _metric(metrics['messages']),
                            detail: 'Bugün alınan sonuçlar',
                            icon: Icons.chat_bubble_outline_rounded),
                        ProductMetricCard(
                            label: 'Mesaj maliyeti',
                            value: _metric(metrics['cpa'], money: true),
                            detail: metrics['cpa'] == null
                                ? 'Sonuç oluşunca hesaplanır'
                                : 'Harcama / sonuç',
                            icon: Icons.insights_rounded),
                      ];
                      return Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: cards
                              .map(
                                  (card) => SizedBox(width: width, child: card))
                              .toList());
                    }),
                    const SizedBox(height: 20),
                    _brief(context, briefLines, navigation),
                    if (recommendations.isNotEmpty) ...[
                      const SizedBox(height: 20),
                      _recommendations(context, recommendations, navigation),
                    ],
                    const SizedBox(height: 20),
                    LayoutBuilder(builder: (context, box) {
                      final left = Column(children: [
                        _campaigns(context, campaigns, navigation),
                        const SizedBox(height: 20),
                        _trend(context, trend, navigation),
                        const SizedBox(height: 20),
                        _activity(context, logs, navigation),
                      ]);
                      final right = Column(children: [
                        _nextContent(context, queued, navigation),
                        const SizedBox(height: 20),
                        _notifications(context, notifications, navigation),
                        const SizedBox(height: 20),
                        _leads(context, leads, navigation),
                      ]);
                      return box.maxWidth >= 900
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Expanded(flex: 3, child: left),
                                  const SizedBox(width: 20),
                                  Expanded(flex: 2, child: right)
                                ])
                          : Column(children: [
                              right,
                              const SizedBox(height: 20),
                              left
                            ]);
                    }),
                  ],
                  const SizedBox(height: 24),
                ],
              ))),
    );
  }

  Widget _brief(BuildContext context, List<String> lines,
          ProductNavigation? navigation) =>
      Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: const LinearGradient(
                colors: [ProductColors.navy, Color(0xFF343063)])),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.auto_awesome_rounded,
                color: Color(0xFFB7ACFF), size: 21),
            SizedBox(width: 10),
            Text('AdVise günlük özet',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 17))
          ]),
          const SizedBox(height: 14),
          if (lines.isEmpty)
            const Text(
                'İçerik ve kampanya verilerin oluştuğunda günlük özetin burada görünecek.',
                style: TextStyle(color: Colors.white70)),
          for (final line in lines.take(5))
            Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $line',
                    style: const TextStyle(
                        color: Color(0xFFE7E4FF), height: 1.5))),
          const SizedBox(height: 8),
          TextButton(
              onPressed: navigation == null
                  ? null
                  : () => navigation.open(const MemoryInsightsPage()),
              style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFFC3BCFF)),
              child: const Text('AdVise neler öğreniyor?')),
        ]),
      );

  Future<void> _openRecommendation(
      String action, ProductNavigation navigation) async {
    switch (action) {
      case 'META_CONNECTION':
        await navigation.open(const MetaConnectionPage());
        return;
      case 'ONBOARDING':
        await navigation.open(const ProductOnboardingPage());
        return;
      case 'PLANNER':
        navigation.go(ProductDestination.planner);
        return;
      case 'ADS':
        navigation.go(ProductDestination.ads);
        return;
      case 'CRM':
        await navigation.open(const ProductCrmPage());
        return;
      case 'AUTOMATION':
        await navigation.open(const ProductAutomationPage());
        return;
      case 'MEMORY':
        await navigation.open(const MemoryInsightsPage());
        return;
      case 'REPORTS':
        await navigation.open(const ProductReportsPage());
        return;
      case 'STUDIO':
      default:
        navigation.go(ProductDestination.studio);
    }
  }

  Widget _recommendations(BuildContext context,
          List<Map<String, dynamic>> items, ProductNavigation? navigation) =>
      _section(
          context,
          'Sonraki hamleler',
          Column(
            children: items.take(5).map((item) {
              final tone = item['tone']?.toString() ?? 'info';
              final icon = switch (item['kind']?.toString()) {
                'CONNECTION' => Icons.link_rounded,
                'SETUP' => Icons.tune_rounded,
                'PUBLISHING' => Icons.sync_problem_rounded,
                'CRM' => Icons.people_alt_outlined,
                'ADS' => Icons.campaign_outlined,
                'MEMORY' => Icons.psychology_alt_outlined,
                'REPORTING' => Icons.analytics_outlined,
                _ => Icons.auto_awesome_rounded,
              };
              final color = switch (tone) {
                'danger' => Theme.of(context).colorScheme.error,
                'warning' => Colors.orange.shade700,
                'success' => Colors.green.shade700,
                _ => Theme.of(context).colorScheme.primary,
              };
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: navigation == null
                      ? null
                      : () => _openRecommendation(
                          item['action']?.toString() ?? 'STUDIO', navigation),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Theme.of(context)
                              .dividerColor
                              .withValues(alpha: .7)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                              color: color.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(10)),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['title']?.toString() ?? 'Öneri',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              const SizedBox(height: 4),
                              Text(item['body']?.toString() ?? '',
                                  style: Theme.of(context).textTheme.bodySmall),
                            ],
                          ),
                        ),
                        if (navigation != null)
                          const Padding(
                            padding: EdgeInsets.only(left: 8, top: 8),
                            child: Icon(Icons.chevron_right_rounded, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ));

  Widget _section(BuildContext context, String title, Widget content,
          {Widget? action}) =>
      ProductSurface(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
              child:
                  Text(title, style: Theme.of(context).textTheme.titleMedium)),
          if (action != null) action
        ]),
        const SizedBox(height: 14),
        content,
      ]));

  Widget _campaigns(BuildContext context, List<Map<String, dynamic>> items,
          ProductNavigation? navigation) =>
      _section(
          context,
          'Kampanyaların',
          items.isEmpty
              ? const Text(
                  'Henüz kampanya yok. Reklamlar bölümünde ilk kampanyanı hazırlayabilirsin.')
              : Column(
                  children: items
                      .take(4)
                      .map((c) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(children: [
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(c['name']?.toString() ?? 'Kampanya',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(
                                      '${_metric(c['spend'], money: true)} • ${_metric(c['messages'])} sonuç',
                                      style:
                                          Theme.of(context).textTheme.bodySmall)
                                ])),
                            const SizedBox(width: 10),
                            ProductStatusChip(
                                label: (c['status'] == 'ACTIVE' ||
                                        c['effective_status'] == 'ACTIVE')
                                    ? 'Aktif'
                                    : 'Kapalı',
                                tone: (c['status'] == 'ACTIVE' ||
                                        c['effective_status'] == 'ACTIVE')
                                    ? 'success'
                                    : 'neutral'),
                          ])))
                      .toList()),
          action: TextButton(
              onPressed: navigation == null
                  ? null
                  : () => navigation.go(ProductDestination.ads),
              child: const Text('Tümü')));

  Widget _nextContent(BuildContext context, List<Map<String, dynamic>> items,
          ProductNavigation? navigation) =>
      _section(
          context,
          'Sıradaki içerik',
          items.isEmpty
              ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Henüz planlanmış içerik yok.'),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                      onPressed: navigation == null
                          ? null
                          : () => navigation.go(ProductDestination.studio),
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('İçerik hazırla'))
                ])
              : Column(
                  children: items
                      .take(3)
                      .map((p) => Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Row(children: [
                            Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primaryContainer,
                                    borderRadius: BorderRadius.circular(10)),
                                child: Icon(
                                    ['VIDEO', 'REELS'].contains(p['mediaType'])
                                        ? Icons.videocam_outlined
                                        : Icons.photo_outlined)),
                            const SizedBox(width: 12),
                            Expanded(
                                child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                  Text(
                                      p['title']?.toString().isNotEmpty == true
                                          ? p['title'].toString()
                                          : 'Instagram içeriği',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  const SizedBox(height: 4),
                                  Text(_date(p['nextPublishAt']),
                                      style:
                                          Theme.of(context).textTheme.bodySmall)
                                ]))
                          ])))
                      .toList()),
          action: TextButton(
              onPressed: navigation == null
                  ? null
                  : () => navigation.go(ProductDestination.planner),
              child: const Text('Plan')));

  Widget _trend(BuildContext context, List<Map<String, dynamic>> items,
      ProductNavigation? navigation) {
    final values = items
        .map((p) => p['spend'])
        .whereType<num>()
        .map((n) => n.toDouble())
        .toList();
    return _section(
        context,
        'Harcama eğilimi • son 7 gün',
        values.length < 2
            ? const Text('Eğilim için henüz yeterli performans verisi yok.')
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Semantics(
                    label:
                        'Son 7 günlük harcama. ${values.map((n) => _metric(n, money: true)).join(', ')}',
                    child: SizedBox(
                        height: 140,
                        width: double.infinity,
                        child: CustomPaint(
                            painter: _TrendPainter(
                                values,
                                Theme.of(context).colorScheme.primary,
                                Theme.of(context).dividerColor)))),
                const SizedBox(height: 8),
                Row(children: [
                  Text(items.first['date']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall),
                  const Spacer(),
                  Text(items.last['date']?.toString() ?? '',
                      style: Theme.of(context).textTheme.bodySmall)
                ])
              ]),
        action: TextButton(
            onPressed: navigation == null
                ? null
                : () => navigation.open(const ProductReportsPage()),
            child: const Text('Rapor')));
  }

  Widget _notifications(BuildContext context, List<Map<String, dynamic>> items,
          ProductNavigation? navigation) =>
      _section(
          context,
          'Dikkat gerektirenler',
          items.isEmpty
              ? const Text('Şu anda yeni bir uyarı bulunmuyor.')
              : Column(
                  children: items
                      .take(3)
                      .map((n) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Icon(Icons.notifications_none_rounded,
                              color: n['severity'] == 'danger'
                                  ? ProductColors.danger
                                  : ProductColors.warning),
                          title: Text(n['title']?.toString() ?? 'Bildirim'),
                          subtitle: Text(n['body']?.toString() ?? '')))
                      .toList()),
          action: TextButton(
              onPressed: navigation == null
                  ? null
                  : () => navigation.open(const ProductNotificationsPage()),
              child: const Text('Tümü')));

  Widget _leads(BuildContext context, List<Map<String, dynamic>> items,
          ProductNavigation? navigation) =>
      _section(
          context,
          'Son fırsatlar',
          items.isEmpty
              ? const Text(
                  'Henüz müşteri fırsatı kaydedilmedi. CRM üzerinden görüşmelerini takip edebilirsin.')
              : Column(
                  children: items
                      .take(3)
                      .map((l) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: const CircleAvatar(
                              child: Icon(Icons.person_outline_rounded)),
                          title: Text(l['name']?.toString() ??
                              l['fullName']?.toString() ??
                              'Müşteri'),
                          subtitle: Text(l['stage']?.toString() ?? 'Yeni')))
                      .toList()),
          action: TextButton(
              onPressed: navigation == null
                  ? null
                  : () => navigation.open(const ProductCrmPage()),
              child: const Text('CRM')));

  Widget _activity(BuildContext context, List<Map<String, dynamic>> items,
          ProductNavigation? navigation) =>
      _section(
          context,
          'Son işlemler',
          items.isEmpty
              ? const Text('İçerik ve reklam işlemlerin burada görünecek.')
              : Column(
                  children: items
                      .take(4)
                      .map((log) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.history_rounded, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                    child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                      Text(log['title']?.toString() ??
                                          log['message']?.toString() ??
                                          'İşlem kaydedildi'),
                                      Text(_date(log['at'] ?? log['createdAt']),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall)
                                    ]))
                              ])))
                      .toList()));
}

class _TrendPainter extends CustomPainter {
  final List<double> values;
  final Color color, gridColor;
  _TrendPainter(this.values, this.color, this.gridColor);
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 1; i <= 3; i++)
      canvas.drawLine(Offset(0, size.height * i / 4),
          Offset(size.width, size.height * i / 4), grid);
    final max = values.reduce((a, b) => a > b ? a : b);
    final denominator = max > 0 ? max : 1.0;
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final point = Offset(size.width * i / (values.length - 1),
          size.height - 8 - (size.height - 16) * values[i] / denominator);
      if (i == 0) {
        path.moveTo(point.dx, point.dy);
      } else {
        path.lineTo(point.dx, point.dy);
      }
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}
