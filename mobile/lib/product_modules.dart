import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api.dart';
import 'app_error.dart';
import 'content_queue_page.dart';
import 'product_ui.dart';
import 'social_ads_page.dart';
import 'v78_pages.dart';

Map<String, dynamic> _map(dynamic value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};
List<Map<String, dynamic>> _rows(dynamic value) => value is List
    ? value.whereType<Map>().map((x) => Map<String, dynamic>.from(x)).toList()
    : [];
double _num(dynamic value) => double.tryParse('$value') ?? 0;
String _money(dynamic value) =>
    value == null ? '—' : '₺${_num(value).toStringAsFixed(2)}';
String _date(dynamic value) {
  final d = DateTime.tryParse('$value')?.toLocal();
  if (d == null) return 'Henüz planlanmadı';
  String two(int n) => '$n'.padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

bool _canManage(Map<String, dynamic> user) =>
    ['ADMIN', 'CUSTOMER_ADMIN', 'MANAGER', 'OPERATOR'].contains(user['role']);
bool _canConfigure(Map<String, dynamic> user) =>
    ['ADMIN', 'CUSTOMER_ADMIN'].contains(user['role']);
void _open(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
void _snack(BuildContext context, Object error) => ScaffoldMessenger.of(context)
    .showSnackBar(SnackBar(content: Text(AppError.message(error))));

class _ModuleFrame extends StatelessWidget {
  const _ModuleFrame(
      {required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      body: ProductContent(child: child));
}

/// One entry point for live Meta resources and explicit AI decisions.
class AdsCenterPage extends StatefulWidget {
  const AdsCenterPage({super.key});
  @override
  State<AdsCenterPage> createState() => _AdsCenterPageState();
}

class _AdsCenterPageState extends State<AdsCenterPage> {
  List<Map<String, dynamic>> campaigns = [], adsets = [], ads = [];
  Map<String, dynamic> overview = {}, user = {};
  bool loading = true;
  String? error;
  String search = '';
  int tab = 0;
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
      final result = await Future.wait<dynamic>([
        Api.campaigns(),
        Api.adsets(),
        Api.ads(),
        Api.me(),
      ]);
      campaigns = _rows(result[0]);
      adsets = _rows(result[1]);
      ads = _rows(result[2]);
      user =
          _map(result[3])['user'] is Map ? _map(_map(result[3])['user']) : {};
      try {
        overview = await Api.productOverview();
      } catch (_) {
        overview = {};
      }
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final source = tab == 1
        ? campaigns
        : tab == 2
            ? adsets
            : ads;
    final filtered = source
        .where((x) =>
            '${x['name'] ?? ''}'.toLowerCase().contains(search.toLowerCase()))
        .toList();
    final metrics = _map(overview['metrics']);
    return _ModuleFrame(
        title: 'Reklam Merkezi',
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: loading ? null : _load,
              icon: const Icon(Icons.refresh)),
        ],
        child: loading
            ? const ProductLoadingSkeleton()
            : error != null
                ? ProductErrorState(message: error!, onRetry: _load)
                : RefreshIndicator(
                    onRefresh: _load,
                    child:
                        ListView(padding: const EdgeInsets.all(20), children: [
                      ProductPageHeader(
                          title: 'Reklamların, tek bakışta',
                          subtitle:
                              'Performansı izle; bütçe ve yayın kararlarını kontrollü yönet.',
                          actions: [
                            if (_canManage(user))
                              FilledButton.icon(
                                  onPressed: () =>
                                      _open(context, const SocialAdsPage()),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Reklam oluştur')),
                            OutlinedButton.icon(
                                onPressed: () =>
                                    _open(context, const DecisionHubPage()),
                                icon: const Icon(Icons.auto_awesome),
                                label: const Text('AI kararları')),
                          ]),
                      const SizedBox(height: 20),
                      SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: SegmentedButton<int>(
                              segments: const [
                                ButtonSegment(
                                    value: 0, label: Text('Genel bakış')),
                                ButtonSegment(
                                    value: 1, label: Text('Kampanyalar')),
                                ButtonSegment(
                                    value: 2, label: Text('Reklam grupları')),
                                ButtonSegment(
                                    value: 3, label: Text('Reklamlar')),
                              ],
                              selected: {
                                tab
                              },
                              onSelectionChanged: (x) =>
                                  setState(() => tab = x.first))),
                      const SizedBox(height: 20),
                      if (tab == 0) ...[
                        Wrap(spacing: 12, runSpacing: 12, children: [
                          SizedBox(
                              width: 225,
                              child: ProductMetricCard(
                                  label: 'Bugünkü harcama',
                                  value: _money(metrics['spend']),
                                  detail: 'Meta · bugün',
                                  icon: Icons.account_balance_wallet_outlined)),
                          SizedBox(
                              width: 225,
                              child: ProductMetricCard(
                                  label: 'Aktif reklam',
                                  value:
                                      '${ads.where((x) => x['effective_status'] == 'ACTIVE' || x['status'] == 'ACTIVE').length}',
                                  detail: 'Bağlı hesaptaki durum',
                                  icon: Icons.campaign_outlined)),
                          SizedBox(
                              width: 225,
                              child: ProductMetricCard(
                                  label: 'Mesaj maliyeti',
                                  value: _money(
                                      metrics['messageCost'] ?? metrics['cpa']),
                                  detail: 'Sonuç varsa hesaplanır',
                                  icon: Icons.chat_outlined)),
                        ]),
                        const SizedBox(height: 20),
                        ProductInsightCard(
                            title: 'Kararları nasıl okuyacaksın?',
                            body:
                                'AI önerisi bir değerlendirmedir. Otomasyon kararı limitleri kontrol eder. Gerçekleşen aksiyon işlem geçmişine kaydedilir.',
                            icon: Icons.insights_outlined,
                            action: TextButton(
                                onPressed: () => _open(
                                    context, const ProductAutomationPage()),
                                child: const Text('Otomasyon limitleri'))),
                        const SizedBox(height: 20),
                      ],
                      TextField(
                          decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.search),
                              hintText: 'Ad veya kampanya ara'),
                          onChanged: (x) => setState(() => search = x)),
                      const SizedBox(height: 16),
                      if (filtered.isEmpty)
                        ProductEmptyState(
                            title: source.isEmpty
                                ? 'Henüz reklam yok'
                                : 'Arama sonucu bulunamadı',
                            body:
                                'Bağlı Instagram gönderilerinden ilk WhatsApp reklamını oluşturabilirsin.',
                            icon: Icons.campaign_outlined,
                            action: _canManage(user)
                                ? FilledButton(
                                    onPressed: () =>
                                        _open(context, const SocialAdsPage()),
                                    child: const Text('İlk reklamını oluştur'))
                                : null)
                      else
                        LayoutBuilder(builder: (context, constraints) {
                          if (constraints.maxWidth >= 850)
                            return SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: DataTable(
                                    columns: const [
                                      DataColumn(label: Text('Ad')),
                                      DataColumn(label: Text('Durum')),
                                      DataColumn(label: Text('Günlük bütçe')),
                                      DataColumn(label: Text('Ayrıntı')),
                                    ],
                                    rows: filtered
                                        .map((x) => DataRow(cells: [
                                              DataCell(SizedBox(
                                                  width: 300,
                                                  child: Text(
                                                      '${x['name'] ?? 'İsimsiz'}',
                                                      maxLines: 2))),
                                              DataCell(_adStatus(x)),
                                              DataCell(Text(x['daily_budget'] ==
                                                      null
                                                  ? '—'
                                                  : _money(
                                                      _num(x['daily_budget']) /
                                                          100))),
                                              DataCell(IconButton(
                                                  tooltip:
                                                      'Performans ve AI kararları',
                                                  onPressed: () => _open(
                                                      context,
                                                      const DecisionHubPage()),
                                                  icon: const Icon(
                                                      Icons.arrow_forward))),
                                            ]))
                                        .toList()));
                          return Column(
                              children: filtered
                                  .map((x) => Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: ProductSurface(
                                          child: ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              title: Text(
                                                  '${x['name'] ?? 'İsimsiz'}'),
                                              subtitle: Text(x[
                                                          'daily_budget'] ==
                                                      null
                                                  ? 'Bütçe reklam grubunda yönetilir'
                                                  : '${_money(_num(x['daily_budget']) / 100)} / gün'),
                                              trailing: _adStatus(x),
                                              onTap: () => _open(context,
                                                  const DecisionHubPage())))))
                                  .toList());
                        }),
                    ])));
  }

  Widget _adStatus(Map<String, dynamic> x) {
    final s = '${x['effective_status'] ?? x['status'] ?? ''}';
    final label = {
          'ACTIVE': 'Aktif',
          'PAUSED': 'Durduruldu',
          'ARCHIVED': 'Arşiv',
          'DELETED': 'Silindi',
          'IN_PROCESS': 'İşleniyor',
          'PENDING_REVIEW': 'İncelemede'
        }[s] ??
        'Kontrol gerekiyor';
    return ProductStatusChip(
        label: label,
        tone: s == 'ACTIVE'
            ? 'success'
            : s == 'PAUSED'
                ? 'warning'
                : 'neutral');
  }
}

class ProductReportsPage extends StatefulWidget {
  const ProductReportsPage({super.key});
  @override
  State<ProductReportsPage> createState() => _ProductReportsPageState();
}

class _ProductReportsPageState extends State<ProductReportsPage> {
  String range = '7d';
  String? error;
  bool loading = true;
  Map<String, dynamic> data = {};
  DateTimeRange? custom;
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
      data = await Api.productReport(
          range: range,
          since: custom?.start.toIso8601String().substring(0, 10),
          until: custom?.end.toIso8601String().substring(0, 10));
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _selectRange(String value) async {
    if (value == 'custom') {
      final picked = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          initialDateRange: custom);
      if (picked == null || !mounted) return;
      custom = picked;
    }
    setState(() => range = value);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _map(data['metrics']);
    final trend = _rows(data['trend']);
    final rows = _rows(data['campaigns']);
    return _ModuleFrame(
        title: 'Raporlar',
        actions: [
          IconButton(
              tooltip: 'Raporu yenile',
              onPressed: _load,
              icon: const Icon(Icons.refresh))
        ],
        child: ListView(padding: const EdgeInsets.all(20), children: [
          const ProductPageHeader(
              title: 'Performansını anla',
              subtitle:
                  'Gerçek Meta verisi. Sonuç olmayan dönemde maliyet ve ROAS gösterilmez.'),
          const SizedBox(height: 18),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: {
                'today': 'Bugün',
                'yesterday': 'Dün',
                '7d': '7 gün',
                '14d': '14 gün',
                '30d': '30 gün',
                'custom': 'Tarih seç'
              }
                  .entries
                  .map((x) => ChoiceChip(
                      label: Text(x.value),
                      selected: range == x.key,
                      onSelected: loading ? null : (_) => _selectRange(x.key)))
                  .toList()),
          if (custom != null && range == 'custom')
            Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                    '${_date(custom!.start).split(' ').first} – ${_date(custom!.end).split(' ').first}')),
          const SizedBox(height: 18),
          if (loading)
            const ProductLoadingSkeleton()
          else if (error != null)
            ProductErrorState(message: error!, onRetry: _load)
          else ...[
            if (data['available'] == false || metrics.isEmpty)
              ProductEmptyState(
                  title: 'Performans verisi henüz yok',
                  body:
                      '${data['reason'] ?? 'Meta hesabını bağladıktan ve reklam sonuçları geldikten sonra rapor burada oluşacak.'}',
                  icon: Icons.insights_outlined,
                  action: OutlinedButton(
                      onPressed: () =>
                          _open(context, const MetaConnectionPage()),
                      child: const Text('Meta bağlantısını kontrol et')))
            else ...[
              Wrap(spacing: 12, runSpacing: 12, children: [
                for (final metric in [
                  ['Harcama', _money(metrics['spend'])],
                  [
                    'Mesaj / sonuç',
                    '${metrics['messages'] ?? metrics['results'] ?? '—'}'
                  ],
                  [
                    'Mesaj maliyeti',
                    _money(metrics['messageCost'] ?? metrics['cpa'])
                  ],
                  [
                    'CTR',
                    metrics['ctr'] == null
                        ? '—'
                        : '%${_num(metrics['ctr']).toStringAsFixed(2)}'
                  ],
                  ['Erişim', '${metrics['reach'] ?? '—'}'],
                  ['Gösterim', '${metrics['impressions'] ?? '—'}'],
                  if (metrics['roas'] != null) ['ROAS', '${metrics['roas']}']
                ])
                  SizedBox(
                      width: 220,
                      child: ProductMetricCard(
                          label: metric[0],
                          value: metric[1],
                          detail: 'Seçili dönem · Meta',
                          icon: Icons.insights_outlined)),
              ]),
              if (trend.isNotEmpty) ...[
                const SizedBox(height: 24),
                ProductSurface(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('Günlük harcama trendi',
                          style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 16),
                      SizedBox(
                          height: 200,
                          width: double.infinity,
                          child: CustomPaint(
                              painter: _TrendPainter(
                                  trend,
                                  Theme.of(context).colorScheme.primary,
                                  Theme.of(context)
                                      .colorScheme
                                      .outlineVariant))),
                      const SizedBox(height: 8),
                      Text(
                          'Y: harcama (TL) · X: tarih · ${trend.first['date'] ?? trend.first['date_start']} – ${trend.last['date'] ?? trend.last['date_start']}',
                          style: Theme.of(context).textTheme.bodySmall)
                    ]))
              ],
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text('Kampanya karşılaştırması',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                        columns: const [
                          DataColumn(label: Text('Kampanya')),
                          DataColumn(label: Text('Harcama')),
                          DataColumn(label: Text('Mesaj')),
                          DataColumn(label: Text('Mesaj maliyeti')),
                          DataColumn(label: Text('CTR'))
                        ],
                        rows: rows
                            .map((x) => DataRow(cells: [
                                  DataCell(Text(
                                      '${x['name'] ?? x['campaign_name'] ?? 'Kampanya'}')),
                                  DataCell(Text(_money(x['spend']))),
                                  DataCell(Text('${x['messages'] ?? '—'}')),
                                  DataCell(Text(
                                      _money(x['messageCost'] ?? x['cpa']))),
                                  DataCell(Text(x['ctr'] == null
                                      ? '—'
                                      : '%${_num(x['ctr']).toStringAsFixed(2)}'))
                                ]))
                            .toList()))
              ],
            ],
            const SizedBox(height: 24),
            ProductInsightCard(
                title: 'Sonuçlardan öğren',
                body:
                    'Hafıza Sarayı üretimi reklam sonucuna bağladığında başarılı hook, format ve saatleri karşılaştırabilir. Ölçüm yokken kazanan ilan edilmez.',
                icon: Icons.psychology_outlined,
                action: TextButton(
                    onPressed: () => _open(context, const MemoryInsightsPage()),
                    child: const Text('AdVise ne öğrendi?'))),
          ],
        ]));
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.rows, this.color, this.grid);
  final List<Map<String, dynamic>> rows;
  final Color color, grid;
  @override
  void paint(Canvas canvas, Size size) {
    final values = rows.map((x) => _num(x['spend'])).toList();
    final max = values.fold<double>(0, (a, b) => a > b ? a : b);
    final usable = Size(size.width - 56, size.height - 22);
    for (var i = 0; i < 4; i++) {
      final y = usable.height * i / 3;
      canvas.drawLine(
          Offset(50, y),
          Offset(size.width, y),
          Paint()
            ..color = grid
            ..strokeWidth = 1);
      final label = TextPainter(
          text: TextSpan(
              text: '${(max * (1 - i / 3)).toStringAsFixed(0)} TL',
              style: TextStyle(fontSize: 11, color: color)),
          textDirection: TextDirection.ltr)
        ..layout(maxWidth: 48);
      label.paint(canvas, Offset(0, y));
    }
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = 50 +
          usable.width * (values.length < 2 ? .5 : i / (values.length - 1));
      final y = usable.height * (1 - (max <= 0 ? 0 : values[i] / max));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
    canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.rows != rows || old.color != color;
}

class ProductCrmPage extends StatefulWidget {
  const ProductCrmPage({super.key});
  @override
  State<ProductCrmPage> createState() => _ProductCrmPageState();
}

class _ProductCrmPageState extends State<ProductCrmPage> {
  List<Map<String, dynamic>> leads = [];
  Map<String, dynamic> user = {};
  bool loading = true, busy = false;
  String? error;
  String search = '', stage = 'ALL';
  static const stages = {
    'NEW': 'Yeni',
    'CONTACTED': 'Görüşüldü',
    'OFFER': 'Teklif verildi',
    'WON': 'Kazanıldı',
    'LOST': 'Kaybedildi'
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await Future.wait<dynamic>([Api.proLeads(), Api.me()]);
      leads = _rows(result[0]);
      user = _map(_map(result[1])['user']);
      error = null;
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _edit([Map<String, dynamic>? lead]) async {
    final name = TextEditingController(text: '${lead?['name'] ?? ''}');
    final phone = TextEditingController(text: '${lead?['phone'] ?? ''}');
    final notes = TextEditingController(text: '${lead?['notes'] ?? ''}');
    var status = '${lead?['status'] ?? 'NEW'}';
    if (!stages.containsKey(status)) status = 'NEW';
    final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (ctx, change) => AlertDialog(
                    title: Text(lead == null
                        ? 'Yeni müşteri adayı'
                        : 'Müşteri adayını düzenle'),
                    content: SizedBox(
                        width: 440,
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              TextField(
                                  controller: name,
                                  decoration: const InputDecoration(
                                      labelText: 'Ad soyad / işletme')),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: phone,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                      labelText: 'WhatsApp telefonu')),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<String>(
                                  initialValue: status,
                                  items: stages.entries
                                      .map((e) => DropdownMenuItem(
                                          value: e.key, child: Text(e.value)))
                                      .toList(),
                                  onChanged: (v) =>
                                      change(() => status = v ?? 'NEW'),
                                  decoration: const InputDecoration(
                                      labelText: 'Aşama')),
                              const SizedBox(height: 12),
                              TextField(
                                  controller: notes,
                                  maxLines: 3,
                                  decoration: const InputDecoration(
                                      labelText: 'Notlar')),
                            ]))),
                    actions: [
                      TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Vazgeç')),
                      FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Kaydet'))
                    ])));
    if (ok == true && name.text.trim().isNotEmpty) {
      if (mounted) setState(() => busy = true);
      try {
        if (lead == null) {
          await Api.createLead(
              name: name.text.trim(),
              phone: phone.text.trim(),
              notes: notes.text.trim(),
              status: status,
              source: 'MANUAL');
        } else {
          await Api.updateLead('${lead['id']}', {
            'name': name.text.trim(),
            'phone': phone.text.trim(),
            'notes': notes.text.trim(),
            'status': status
          });
        }
        await _load();
      } catch (e) {
        if (mounted) _snack(context, e);
      }
      if (mounted) setState(() => busy = false);
    }
    name.dispose();
    phone.dispose();
    notes.dispose();
  }

  Future<void> _whatsapp(Map<String, dynamic> lead) async {
    final phone = '${lead['phone'] ?? ''}'.replaceAll(RegExp(r'\D'), '');
    if (phone.isEmpty) return;
    if (!await launchUrl(Uri.https('wa.me', '/$phone'),
            mode: LaunchMode.externalApplication) &&
        mounted)
      _snack(context, 'WhatsApp açılamadı. Telefon numarasını kontrol et.');
  }

  @override
  Widget build(BuildContext context) {
    final visible = leads
        .where((x) =>
            (stage == 'ALL' || x['status'] == stage) &&
            '${x['name']} ${x['phone']} ${x['notes']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList();
    return _ModuleFrame(
        title: 'Müşteri adayları',
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _load,
              icon: const Icon(Icons.refresh))
        ],
        child: loading
            ? const ProductLoadingSkeleton()
            : error != null
                ? ProductErrorState(message: error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.all(20), children: [
                    ProductPageHeader(
                        title: 'Görüşmeden satışa',
                        subtitle:
                            'Müşteri adaylarını ve WhatsApp görüşmelerini takip et.',
                        actions: [
                          if (_canManage(user))
                            FilledButton.icon(
                                onPressed: busy ? null : () => _edit(),
                                icon: const Icon(Icons.person_add_outlined),
                                label: const Text('Müşteri adayı ekle'))
                        ]),
                    const SizedBox(height: 18),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      ChoiceChip(
                          label: Text('Tümü (${leads.length})'),
                          selected: stage == 'ALL',
                          onSelected: (_) => setState(() => stage = 'ALL')),
                      for (final e in stages.entries)
                        ChoiceChip(
                            label: Text(
                                '${e.value} (${leads.where((x) => x['status'] == e.key).length})'),
                            selected: stage == e.key,
                            onSelected: (_) => setState(() => stage = e.key))
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'İsim, telefon veya not ara'),
                        onChanged: (v) => setState(() => search = v)),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      ProductEmptyState(
                          title: 'Müşteri adayı bulunamadı',
                          body:
                              'İlk adayını ekle. Otomatik Meta lead aktarımı bağlı değilse kayıtları buradan yönetebilirsin.',
                          icon: Icons.people_outline,
                          action: _canManage(user)
                              ? OutlinedButton(
                                  onPressed: () => _edit(),
                                  child: const Text('İlk kaydı ekle'))
                              : null)
                    else
                      LayoutBuilder(builder: (ctx, c) {
                        if (c.maxWidth >= 850)
                          return SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: DataTable(
                                  columns: const [
                                    DataColumn(label: Text('Müşteri')),
                                    DataColumn(label: Text('Telefon')),
                                    DataColumn(label: Text('Aşama')),
                                    DataColumn(label: Text('Kaynak')),
                                    DataColumn(label: Text('İşlem'))
                                  ],
                                  rows: visible
                                      .map((x) => DataRow(cells: [
                                            DataCell(Text('${x['name']}')),
                                            DataCell(
                                                Text('${x['phone'] ?? '—'}')),
                                            DataCell(ProductStatusChip(
                                                label: stages[x['status']] ??
                                                    'Yeni',
                                                tone: x['status'] == 'WON'
                                                    ? 'success'
                                                    : 'neutral')),
                                            DataCell(Text(
                                                '${x['adName'] ?? x['campaignName'] ?? x['source'] ?? 'Manuel'}')),
                                            DataCell(Wrap(children: [
                                              IconButton(
                                                  tooltip: 'WhatsApp görüşmesi',
                                                  onPressed:
                                                      '${x['phone'] ?? ''}'
                                                              .isEmpty
                                                          ? null
                                                          : () => _whatsapp(x),
                                                  icon: const Icon(
                                                      Icons.chat_outlined)),
                                              if (_canManage(user))
                                                IconButton(
                                                    tooltip: 'Düzenle',
                                                    onPressed: busy
                                                        ? null
                                                        : () => _edit(x),
                                                    icon: const Icon(
                                                        Icons.edit_outlined))
                                            ]))
                                          ]))
                                      .toList()));
                        return Column(
                            children: visible
                                .map((x) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: ProductSurface(
                                        child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                          Row(children: [
                                            Expanded(
                                                child: Text('${x['name']}',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium)),
                                            ProductStatusChip(
                                                label: stages[x['status']] ??
                                                    'Yeni',
                                                tone: x['status'] == 'WON'
                                                    ? 'success'
                                                    : 'neutral')
                                          ]),
                                          const SizedBox(height: 8),
                                          Text(
                                              '${x['phone'] ?? 'Telefon eklenmedi'}'),
                                          Text(
                                              'Kaynak: ${x['adName'] ?? x['campaignName'] ?? x['source'] ?? 'Manuel'}'),
                                          if ('${x['notes'] ?? ''}'.isNotEmpty)
                                            Text('${x['notes']}'),
                                          Wrap(spacing: 8, children: [
                                            TextButton.icon(
                                                onPressed: '${x['phone'] ?? ''}'
                                                        .isEmpty
                                                    ? null
                                                    : () => _whatsapp(x),
                                                icon: const Icon(
                                                    Icons.chat_outlined),
                                                label: const Text('WhatsApp')),
                                            if (_canManage(user))
                                              TextButton.icon(
                                                  onPressed: busy
                                                      ? null
                                                      : () => _edit(x),
                                                  icon: const Icon(
                                                      Icons.edit_outlined),
                                                  label: const Text('Düzenle'))
                                          ])
                                        ]))))
                                .toList());
                      }),
                  ]));
  }
}

class ProductAutomationPage extends StatefulWidget {
  const ProductAutomationPage({super.key});
  @override
  State<ProductAutomationPage> createState() => _ProductAutomationPageState();
}

class _ProductAutomationPageState extends State<ProductAutomationPage> {
  Map<String, dynamic> settings = {}, user = {};
  List<Map<String, dynamic>> logs = [];
  bool loading = true, busy = false;
  String? error;
  final fields = <String, TextEditingController>{};
  static const labels = {
    'geminiAdsDailyCap': 'Hesap geneli günlük üst limit (TL)',
    'maxDailyBudget': 'Reklam grubu günlük üst limit (TL)',
    'minDailyBudget': 'Reklam grubu günlük alt limit (TL)',
    'earlyMinSpendBeforeDecision': 'Karar öncesi minimum harcama (TL)',
    'earlyMessageCostLimit': 'Mesaj maliyeti hedefi (TL)',
    'earlyNoMessageSpendThreshold': 'Sonuç yokken harcama sınırı (TL)'
  };
  @override
  void initState() {
    super.initState();
    for (final key in labels.keys) {
      fields[key] = TextEditingController();
    }
    _load();
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final result =
          await Future.wait<dynamic>([Api.settings(), Api.me(), Api.logs()]);
      settings = _map(result[0]);
      user = _map(_map(result[1])['user']);
      logs = _rows(result[2]);
      for (final e in fields.entries) {
        e.value.text = '${settings[e.key] ?? 0}';
      }
      error = null;
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _save() async {
    final values = <String, dynamic>{};
    for (final e in fields.entries) {
      final n = double.tryParse(e.value.text.replaceAll(',', '.'));
      if (n == null || n < 0) {
        _snack(context, 'Limitlere geçerli bir sayı gir.');
        return;
      }
      values[e.key] = n;
    }
    if ((settings['enabled'] == true || settings['geminiAdsAuto'] == true) &&
        _num(values['geminiAdsDailyCap']) < 1) {
      _snack(context,
          'Otomasyonu açmadan önce hesap günlük üst limitini belirle.');
      return;
    }
    if (_num(values['minDailyBudget']) > _num(values['maxDailyBudget'])) {
      _snack(context, 'Alt limit üst limitten büyük olamaz.');
      return;
    }
    for (final key in [
      'enabled',
      'geminiAdsAuto',
      'autoPause',
      'autoReallocate',
      'autoPublish'
    ]) {
      values[key] = settings[key] == true;
    }
    setState(() => busy = true);
    try {
      settings = await Api.saveSettings(values);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Otomasyon limitleri kaydedildi.')));
    } catch (e) {
      if (mounted) _snack(context, e);
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final canEdit = _canConfigure(user);
    return _ModuleFrame(
        title: 'Otomasyon',
        child: loading
            ? const ProductLoadingSkeleton()
            : error != null
                ? ProductErrorState(message: error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.all(20), children: [
                    const ProductPageHeader(
                        title: 'Kontrol sende',
                        subtitle:
                            '12 saatlik değerlendirme, açık limitler ve anlaşılır işlem geçmişi.'),
                    const SizedBox(height: 18),
                    ProductSurface(
                        child: Column(children: [
                      for (final e in {
                        'enabled': 'Kural tabanlı reklam otomasyonu',
                        'geminiAdsAuto': 'Gemini ile otomatik reklam yönetimi',
                        'autoPause': 'Zayıf performansta otomatik durdur',
                        'autoReallocate':
                            'Limitler içinde bütçeyi yeniden dağıt',
                        'autoPublish': 'Planlanan içerikleri otomatik yayınla'
                      }.entries)
                        SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(e.value),
                            value: settings[e.key] == true,
                            onChanged: canEdit && !busy
                                ? (v) => setState(() => settings[e.key] = v)
                                : null),
                    ])),
                    const SizedBox(height: 16),
                    ProductSurface(
                        child: LayoutBuilder(
                            builder: (ctx, c) =>
                                Wrap(spacing: 16, runSpacing: 16, children: [
                                  for (final e in fields.entries)
                                    SizedBox(
                                        width: c.maxWidth >= 650
                                            ? (c.maxWidth - 16) / 2
                                            : c.maxWidth,
                                        child: TextField(
                                            controller: e.value,
                                            enabled: canEdit && !busy,
                                            keyboardType: const TextInputType
                                                .numberWithOptions(
                                                decimal: true),
                                            decoration: InputDecoration(
                                                labelText: labels[e.key])))
                                ]))),
                    const SizedBox(height: 16),
                    ProductInsightCard(
                        title: 'Her aksiyonun bir sınırı var',
                        body:
                            'Hesap üst limiti ve reklam grubu sınırları uygulanır. Elle durdurduğun reklam otomatik açılmaz. Gemini önerisi yalnızca yeterli veri ve güven düzeyiyle otomasyona dönüşür.',
                        icon: Icons.shield_outlined),
                    const SizedBox(height: 16),
                    if (canEdit)
                      Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton.icon(
                              onPressed: busy ? null : _save,
                              icon: const Icon(Icons.check),
                              label: Text(busy
                                  ? 'Kaydediliyor…'
                                  : 'Limitleri kaydet'))),
                    const SizedBox(height: 28),
                    Text('Karar ve aksiyon geçmişi',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    ...logs
                        .where((x) => RegExp(
                                r'GEMINI|BUDGET|PAUSE|OPTIM|EARLY_REVIEW|STATUS_CHANGED')
                            .hasMatch('${x['type']}'))
                        .take(25)
                        .map((x) => _AuditRow(log: x)),
                    if (!logs.any((x) => RegExp(
                            r'GEMINI|BUDGET|PAUSE|OPTIM|EARLY_REVIEW|STATUS_CHANGED')
                        .hasMatch('${x['type']}')))
                      const ProductEmptyState(
                          title: 'Henüz otomasyon kararı yok',
                          body:
                              'İlk değerlendirmeden sonra öneri, karar ve gerçekleşen aksiyon burada görünür.',
                          icon: Icons.history),
                  ]));
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.log});
  final Map<String, dynamic> log;
  @override
  Widget build(BuildContext context) {
    final type = '${log['type'] ?? ''}';
    final title = type.contains('REVIEW')
        ? 'Performans değerlendirildi'
        : type.contains('PAUSE')
            ? 'Reklam durduruldu'
            : type.contains('BUDGET')
                ? 'Bütçe güncellendi'
                : type.contains('STATUS')
                    ? 'Reklam durumu değiştirildi'
                    : type.contains('ACTION')
                        ? 'Reklam aksiyonu uygulandı'
                        : 'Otomasyon kontrolü';
    final actor = log['source'] == 'USER_ACTION' || log['actor'] == 'USER'
        ? 'Kullanıcı'
        : type.contains('GEMINI')
            ? 'AdVise AI'
            : 'Otomasyon';
    return ExpansionTile(
        title: Text(title),
        subtitle: Text('$actor · ${_date(log['at'])}'),
        children: [
          Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                      '${log['reason'] ?? log['summary'] ?? 'İşlem kayıt altına alındı.'}${log['before'] != null && log['after'] != null ? '\nBütçe: ${log['before']} → ${log['after']} TL' : ''}')))
        ]);
  }
}

class MemoryInsightsPage extends StatefulWidget {
  const MemoryInsightsPage({super.key});
  @override
  State<MemoryInsightsPage> createState() => _MemoryInsightsPageState();
}

class _MemoryInsightsPageState extends State<MemoryInsightsPage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      data = await Api.aiMemory();
      error = null;
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final measured = _num(data['outcomeCount']);
    return _ModuleFrame(
        title: 'Hafıza Sarayı',
        actions: [
          IconButton(
              tooltip: 'Öğrenmeyi yenile',
              onPressed: _load,
              icon: const Icon(Icons.refresh))
        ],
        child: loading
            ? const ProductLoadingSkeleton()
            : error != null
                ? ProductErrorState(message: error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.all(20), children: [
                    const ProductPageHeader(
                        title: 'AdVise öğreniyor',
                        subtitle:
                            'Kendi içeriklerin ve ölçülen sonuçların, bir sonraki öneriyi geliştirir.'),
                    const SizedBox(height: 20),
                    Wrap(spacing: 12, runSpacing: 12, children: [
                      SizedBox(
                          width: 230,
                          child: ProductMetricCard(
                              label: 'Üretim',
                              value: '${data['generationCount'] ?? 0}',
                              detail: 'Sana ait içerik deneyimleri',
                              icon: Icons.auto_awesome)),
                      SizedBox(
                          width: 230,
                          child: ProductMetricCard(
                              label: 'Ölçülmüş sonuç',
                              value: '${data['outcomeCount'] ?? 0}',
                              detail: 'Üretime bağlı performans',
                              icon: Icons.insights_outlined)),
                      SizedBox(
                          width: 230,
                          child: ProductMetricCard(
                              label: 'Olumlu sinyal',
                              value: '${data['learningWins'] ?? 0}',
                              detail: 'Garanti değil, öğrenme sinyali',
                              icon: Icons.trending_up))
                    ]),
                    const SizedBox(height: 24),
                    if (measured < 3)
                      const ProductEmptyState(
                          title: 'Henüz yeterli performans verisi yok',
                          body:
                              'İçerik üret, yayınla ve reklam sonucunu ölç. Kazanan hook, format ve saatler yeterli veriyle burada görünür.',
                          icon: Icons.psychology_outlined)
                    else
                      for (final e in {
                        'bestHooks': 'İşe yarayan hooklar',
                        'bestAngles': 'İçerik açıları',
                        'bestTimes': 'Paylaşım saatleri',
                        'bestFormats': 'Formatlar',
                        'bestAudiences': 'Hedef kitleler'
                      }.entries)
                        if (_rows(data[e.key])
                            .where((x) => _num(x['score']) > 0)
                            .isNotEmpty)
                          Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: ProductSurface(
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                    Text(e.value,
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleLarge),
                                    const SizedBox(height: 10),
                                    for (final x in _rows(data[e.key])
                                        .where((x) => _num(x['score']) > 0)
                                        .take(3))
                                      ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          leading: const Icon(
                                              Icons.lightbulb_outline),
                                          title: Text('${x['value']}'),
                                          subtitle: const Text(
                                              'Ölçülmüş sonuçlardan olumlu sinyal'))
                                  ]))),
                    const SizedBox(height: 20),
                    Text('Son içerik deneyimleri',
                        style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 12),
                    for (final row in _rows(data['recentGenerations']))
                      ListTile(
                          leading: const Icon(Icons.description_outlined),
                          title: Text('${row['productName'] ?? 'İçerik'}'),
                          subtitle: Text(
                              '${row['recommendedFormat'] ?? 'Format seçilmedi'} · ${_date(row['at'])}'),
                          trailing: ProductStatusChip(
                              label: row['outcomeScore'] == null
                                  ? 'Ölçüm bekliyor'
                                  : _num(row['outcomeScore']) >= .25
                                      ? 'Olumlu sinyal'
                                      : 'İnceleniyor',
                              tone: row['outcomeScore'] != null &&
                                      _num(row['outcomeScore']) >= .25
                                  ? 'success'
                                  : 'neutral')),
                  ]));
  }
}

class MediaLibraryPage extends StatefulWidget {
  const MediaLibraryPage({super.key});
  @override
  State<MediaLibraryPage> createState() => _MediaLibraryPageState();
}

class _MediaLibraryPageState extends State<MediaLibraryPage> {
  List<Map<String, dynamic>> posts = [];
  bool loading = true;
  String? error;
  String filter = 'Recent', search = '';
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      posts = _rows(await Api.posts());
      error = null;
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final visible = posts
        .where((x) =>
            (filter == 'Recent' ||
                (filter == 'Used'
                    ? x['publishStatus'] == 'PUBLISHED'
                    : x['publishStatus'] != 'PUBLISHED')) &&
            '${x['title']} ${x['caption']}'
                .toLowerCase()
                .contains(search.toLowerCase()))
        .toList()
      ..sort((a, b) =>
          '${b['createdAt'] ?? ''}'.compareTo('${a['createdAt'] ?? ''}'));
    return _ModuleFrame(
        title: 'Medya kütüphanesi',
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _load,
              icon: const Icon(Icons.refresh))
        ],
        child: loading
            ? const ProductLoadingSkeleton()
            : error != null
                ? ProductErrorState(message: error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.all(20), children: [
                    const ProductPageHeader(
                        title: 'İçeriklerin elinin altında',
                        subtitle:
                            'Kaydedilen medyayı yeniden yüklemeden önizle, düzenle ve planla.'),
                    const SizedBox(height: 18),
                    Wrap(spacing: 8, children: [
                      for (final e in {
                        'Recent': 'Son eklenenler',
                        'Used': 'Yayınlananlar',
                        'Unused': 'Henüz kullanılmayanlar'
                      }.entries)
                        ChoiceChip(
                            label: Text(e.value),
                            selected: filter == e.key,
                            onSelected: (_) => setState(() => filter = e.key))
                    ]),
                    const SizedBox(height: 16),
                    TextField(
                        decoration: const InputDecoration(
                            prefixIcon: Icon(Icons.search),
                            hintText: 'İçerik ara'),
                        onChanged: (x) => setState(() => search = x)),
                    const SizedBox(height: 18),
                    if (visible.isEmpty)
                      ProductEmptyState(
                          title: 'Bu görünümde medya yok',
                          body:
                              'AI Studio ile ürettiğin ve kaydettiğin içerikler burada görünür.',
                          icon: Icons.photo_library_outlined,
                          action: OutlinedButton(
                              onPressed: () =>
                                  _open(context, const ContentQueuePage()),
                              child: const Text('İçerik ekle')))
                    else
                      LayoutBuilder(builder: (ctx, c) {
                        final count = c.maxWidth >= 1000
                            ? 4
                            : c.maxWidth >= 650
                                ? 3
                                : c.maxWidth >= 420
                                    ? 2
                                    : 1;
                        return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: count,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                    mainAxisExtent: 310),
                            itemCount: visible.length,
                            itemBuilder: (_, i) {
                              final x = visible[i];
                              final video =
                                  ['VIDEO', 'REELS'].contains(x['mediaType']);
                              final url =
                                  '${x['coverPublicUrl'] ?? x['publicUrl'] ?? ''}';
                              return Card(
                                  clipBehavior: Clip.antiAlias,
                                  child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        if (!video &&
                                            url.startsWith('https://'))
                                          Image.network(url,
                                              height: 160,
                                              width: double.infinity,
                                              fit: BoxFit.cover,
                                              cacheWidth: 600,
                                              errorBuilder: (_, __, ___) =>
                                                  const SizedBox(
                                                      height: 160,
                                                      child: Center(
                                                          child: Icon(
                                                              Icons
                                                                  .broken_image_outlined,
                                                              size: 36))))
                                        else
                                          SizedBox(
                                              height: 160,
                                              child: Center(
                                                  child: Icon(
                                                      video
                                                          ? Icons
                                                              .video_library_outlined
                                                          : Icons
                                                              .image_outlined,
                                                      size: 44))),
                                        Padding(
                                            padding: const EdgeInsets.all(12),
                                            child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                      '${x['title'] ?? 'İçerik'}',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium),
                                                  Text('${x['caption'] ?? ''}',
                                                      maxLines: 2,
                                                      overflow: TextOverflow
                                                          .ellipsis),
                                                  TextButton.icon(
                                                      onPressed: () => _open(
                                                          context,
                                                          ContentQueuePage(
                                                              initialPostId:
                                                                  '${x['id']}')),
                                                      icon: const Icon(Icons
                                                          .calendar_month_outlined),
                                                      label: const Text(
                                                          'Planla / düzenle'))
                                                ]))
                                      ]));
                            });
                      }),
                  ]));
  }
}

class ProductNotificationsPage extends StatefulWidget {
  const ProductNotificationsPage({super.key});
  @override
  State<ProductNotificationsPage> createState() =>
      _ProductNotificationsPageState();
}

class _ProductNotificationsPageState extends State<ProductNotificationsPage> {
  List<Map<String, dynamic>> alerts = [];
  bool loading = true;
  String? error;
  bool unreadOnly = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      alerts = _rows(await Api.proAlerts());
      error = null;
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _read(Map<String, dynamic> row) async {
    try {
      await Api.markAlert('${row['id']}');
      await _load();
    } catch (e) {
      if (mounted) _snack(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = alerts.where((x) => x['read'] != true).length;
    final visible =
        alerts.where((x) => !unreadOnly || x['read'] != true).toList();
    return _ModuleFrame(
        title: 'Bildirimler',
        actions: [
          IconButton(
              tooltip: 'Yenile',
              onPressed: _load,
              icon: const Icon(Icons.refresh))
        ],
        child: loading
            ? const ProductLoadingSkeleton()
            : error != null
                ? ProductErrorState(message: error!, onRetry: _load)
                : ListView(padding: const EdgeInsets.all(20), children: [
                    ProductPageHeader(
                        title: 'Gelişmeleri takip et',
                        subtitle:
                            '$unread okunmamış bildirim · Uygulama içi bildirimler'),
                    const SizedBox(height: 16),
                    FilterChip(
                        label: const Text('Yalnızca okunmamış'),
                        selected: unreadOnly,
                        onSelected: (v) => setState(() => unreadOnly = v)),
                    const SizedBox(height: 16),
                    if (visible.isEmpty)
                      ProductEmptyState(
                          title: unreadOnly
                              ? 'Tüm bildirimleri okudun'
                              : 'Henüz bildirim yok',
                          body:
                              'Yayın ve otomasyon gelişmeleri burada görünür.',
                          icon: Icons.notifications_none,
                          action: OutlinedButton(
                              onPressed: _load, child: const Text('Yenile'))),
                    for (final row in visible)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: ProductSurface(
                              child: ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: Icon(row['severity'] == 'ERROR'
                                      ? Icons.error_outline
                                      : row['severity'] == 'WARN'
                                          ? Icons.warning_amber
                                          : Icons.notifications_outlined),
                                  title: Text('${row['title'] ?? 'Bildirim'}'),
                                  subtitle: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(AppError.message(row['body'] ??
                                            'Yeni bir işlem kaydedildi.')),
                                        const SizedBox(height: 6),
                                        Text(
                                            _date(
                                                row['createdAt'] ?? row['at']),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall)
                                      ]),
                                  trailing: row['read'] == true
                                      ? const Icon(Icons.done_all)
                                      : IconButton(
                                          tooltip: 'Okundu olarak işaretle',
                                          onPressed: () => _read(row),
                                          icon: const Icon(Icons.check))))),
                  ]));
  }
}
