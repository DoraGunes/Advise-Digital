import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'v14_ai.dart';
import 'app_error.dart';
import 'product_ui.dart';
import 'product_modules.dart';
import 'package:url_launcher/url_launcher.dart';

void _goHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

String _text(dynamic value, [String fallback = '-']) {
  if (value == null) return fallback;
  final text = value.toString();
  return text.isEmpty ? fallback : text;
}

String _upper(dynamic value) => _text(value, '').toUpperCase();

String _date(dynamic value) {
  final date = DateTime.tryParse(_text(value, ''));
  if (date == null) return '-';
  final local = date.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year}';
}

class V78HubPage extends StatelessWidget {
  final bool admin;

  const V78HubPage({super.key, this.admin = false});

  @override
  Widget build(BuildContext context) {
    final items = admin
        ? const <_HubItem>[
            _HubItem('Analitik', 'KPI, içerik ve kullanım özeti',
                Icons.analytics_outlined, AnalyticsPage()),
            _HubItem(
                'Reklam Karar Merkezi',
                'Reklam durdur, aç, bütçeyi değiştir',
                Icons.auto_graph_outlined,
                DecisionHubPage(admin: true)),
            _HubItem('Müşteriler', 'Hesap, abonelik ve silme işlemleri',
                Icons.people_alt_outlined, AdminCustomersPage()),
            _HubItem('Lisanslar', 'Üret, kopyala, müşteriye ata',
                Icons.vpn_key_outlined, AdminLicensesPage()),
            _HubItem('Meta & Instagram', 'Bağlantı ve hesap durumu',
                Icons.link_outlined, MetaConnectionPage()),
            _HubItem('Ticari Merkez', 'Planlar, MRR ve SaaS görünümü',
                Icons.storefront_outlined, CommercialCenterPage()),
            _HubItem('Bildirimler', 'Uyarı tercihleri',
                Icons.notifications_outlined, NotificationsPage()),
            _HubItem('Marka / White Label', 'Firma ve destek ayarları',
                Icons.palette_outlined, BrandingPage()),
            _HubItem('Güvenlik', 'Oturum ve altyapı durumu',
                Icons.security_outlined, SecurityPage()),
            _HubItem('Sistem Tanılama', 'Bağlantı ve API uçlarını test et',
                Icons.health_and_safety_outlined, DiagnosticsPage()),
            _HubItem('AI İçgörüleri', 'Veriden türetilen açıklamalar',
                Icons.auto_awesome_outlined, AiInsightsPage()),
            _HubItem('Abonelik', 'Plan ve limitler',
                Icons.workspace_premium_outlined, BillingPage()),
          ]
        : const <_HubItem>[
            _HubItem('Analitik', 'KPI, içerik ve kullanım özeti',
                Icons.analytics_outlined, AnalyticsPage()),
            _HubItem('Karar Merkezi', 'Performans sinyallerini izle',
                Icons.auto_graph_outlined, DecisionHubPage()),
            _HubItem('AI İçgörüleri', 'Kural tabanlı açıklamalar',
                Icons.auto_awesome_outlined, AiInsightsPage()),
            _HubItem('Aboneliğim', 'Paket, süre ve limitler',
                Icons.workspace_premium_outlined, BillingPage()),
            _HubItem('Meta & Instagram', 'Hesabını bağla', Icons.link_outlined,
                MetaConnectionPage()),
            _HubItem('Bildirimler', 'Uyarı tercihleri',
                Icons.notifications_outlined, NotificationsPage()),
            _HubItem('Marka', 'Firma ve destek bilgileri',
                Icons.palette_outlined, BrandingPage()),
            _HubItem('Güvenlik', 'Hesap ve altyapı', Icons.security_outlined,
                SecurityPage()),
            _HubItem('Sistem Tanılama', 'Bağlantı ve API durumu',
                Icons.health_and_safety_outlined, DiagnosticsPage()),
          ];

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => _goHome(context),
          icon: const Icon(Icons.home_outlined),
        ),
        title: const Text(
          'V7 + V8 Kontrol Merkezi',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 36),
        children: [
          _PageHero(
            title: admin
                ? 'SaaS Operasyon Merkezi'
                : 'Advise Digital Çalışma Alanı',
            subtitle:
                'V7 teknik ürünleşme + V8 ticari özellikleri tek merkezde.',
            icon: Icons.auto_awesome,
            badge: admin ? 'SUPER ADMIN' : 'WORKSPACE',
          ),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.14,
            ),
            itemCount: items.length,
            itemBuilder: (_, index) => _HubCard(item: items[index]),
          ),
          const SizedBox(height: 18),
          const _PoweredBy(),
        ],
      ),
    );
  }
}

class _HubItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget page;

  const _HubItem(this.title, this.subtitle, this.icon, this.page);
}

class _HubCard extends StatelessWidget {
  final _HubItem item;

  const _HubCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => item.page),
      ),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                item.icon,
                size: 30,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 10),
              Text(
                item.title,
                style:
                    const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
              ),
              const SizedBox(height: 5),
              Text(
                item.subtitle,
                style: TextStyle(
                    color: Colors.grey.shade700, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AnalyticsPage extends StatefulWidget {
  const AnalyticsPage({super.key});

  @override
  State<AnalyticsPage> createState() => _AnalyticsPageState();
}

class _AnalyticsPageState extends State<AnalyticsPage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      data = await Api.analyticsSummary();
    } catch (e) {
      error = AppError.message(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Analitik',
      onRefresh: _load,
      loading: loading,
      error: error,
      children: [
        const _PageHero(
          title: 'Çalışma özeti',
          subtitle:
              'İçerik, kullanıcı, bütçe ve işlem akışını tek bakışta izle.',
          icon: Icons.analytics_outlined,
          badge: 'V7 ANALİTİK',
        ),
        const SizedBox(height: 14),
        _KpiGrid(
          items: [
            _Kpi('İçerik', _text(data['posts'], '0'),
                Icons.photo_library_outlined),
            _Kpi('Yayınlanan', _text(data['publishedPosts'], '0'),
                Icons.publish_outlined),
            _Kpi('İşlem', _text(data['logCount'], '0'), Icons.history_outlined),
            _Kpi(
                'Kullanıcı',
                '${_text(data['activeUsers'], '0')}/${_text(data['totalUsers'], '0')}',
                Icons.groups_outlined),
            _Kpi('Haftalık bütçe', '${_text(data['weeklyBudget'], '0')} TL',
                Icons.account_balance_wallet_outlined),
            _Kpi('Mesaj hedefi', '${_text(data['messageCostLimit'], '8')} TL',
                Icons.chat_bubble_outline),
            _Kpi(
                'Abonelik',
                '${_text(data['remainingSubscriptionDays'], '-')} gün',
                Icons.workspace_premium_outlined),
            _Kpi(
                'Paket', _text(data['plan'], 'BASIC'), Icons.verified_outlined),
          ],
        ),
        const SizedBox(height: 14),
        _InfoCard(
            title: 'Aktivite özeti', body: _eventSummary(data['eventCounts'])),
        const SizedBox(height: 14),
        const _InfoCard(
          title: 'Kullanım rehberi',
          body:
              'Reklam performansı için Karar Merkezi, otomasyon için ayarlar, şirket ve hesap işlemleri için yönetim ekranları kullanılır.',
        ),
        const SizedBox(height: 18),
        const _PoweredBy(),
      ],
    );
  }

  String _eventSummary(dynamic counts) {
    if (counts is! Map || counts.isEmpty) return 'Henüz işlem tipi oluşmadı.';
    return counts.entries
        .take(8)
        .map((e) => '${e.key}: ${e.value}')
        .join('  •  ');
  }
}

class AiInsightsPage extends StatefulWidget {
  const AiInsightsPage({super.key});
  @override
  State<AiInsightsPage> createState() => _AiInsightsPageState();
}

class _AiInsightsPageState extends State<AiInsightsPage> {
  List<dynamic> items = [];
  Map<String, dynamic> advisor = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      final result = await Future.wait([
        Api.aiInsights(),
        Api.proAi(),
      ]);
      final x = Map<String, dynamic>.from(result[0] as Map);
      advisor = Map<String, dynamic>.from(result[1] as Map);
      items = x['insights'] is List ? List<dynamic>.from(x['insights']) : [];
    } catch (e) {
      error = AppError.message(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
        title: 'AI İçgörüleri',
        onRefresh: _load,
        loading: loading,
        error: error,
        children: [
          const _PageHero(
              title: 'Veriden türetilen içgörüler',
              subtitle:
                  'Kural tabanlı öneriler; canlı Meta verisi geldikçe sinyaller genişler.',
              icon: Icons.auto_awesome_outlined,
              badge: 'AI'),
          const SizedBox(height: 14),
          _AiAdvisorCard(advisor: advisor),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiContentStudioPage()),
              ),
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('AI İÇERİK STÜDYOSUNU AÇ'),
            ),
          ),
          const SizedBox(height: 14),
          if (items.isEmpty)
            const _EmptyCard(
                icon: Icons.lightbulb_outline,
                title: 'Henüz içgörü yok',
                body:
                    'Veri biriktikçe burada daha anlamlı açıklamalar görünür.'),
          ...items.map((x) => _InsightCard(
              item: x is Map
                  ? Map<String, dynamic>.from(x)
                  : const <String, dynamic>{})),
          const SizedBox(height: 18),
          const _PoweredBy(),
        ],
      );
}

class _AiAdvisorCard extends StatelessWidget {
  final Map<String, dynamic> advisor;

  const _AiAdvisorCard({required this.advisor});

  @override
  Widget build(BuildContext context) {
    final score = advisor['score']?.toString() ?? '-';
    final summary = advisor['summary'] is List
        ? List<dynamic>.from(advisor['summary'])
        : <dynamic>[];

    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(child: Icon(Icons.auto_awesome_rounded)),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'AdVise AI danışmanı',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                ),
                if (score != '-') Chip(label: Text('Sinyal $score')),
              ],
            ),
            const SizedBox(height: 8),
            if (summary.isEmpty)
              const Text('Henüz yeterli sinyal oluşmadı.')
            else
              ...summary.take(5).map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text('• ${item.toString()}'),
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _InsightCard({required this.item});
  @override
  Widget build(BuildContext context) {
    final type = _upper(item['type']);
    final icon = type == 'GOOD'
        ? Icons.check_circle_outline
        : type == 'WARN'
            ? Icons.warning_amber_outlined
            : type == 'ACTION'
                ? Icons.bolt_outlined
                : Icons.info_outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        child: ListTile(
          leading: CircleAvatar(child: Icon(icon)),
          title: Text(_text(item['title']),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(_text(item['body']),
                  style: TextStyle(color: Colors.grey.shade700, height: 1.35))),
          isThreeLine: true,
        ),
      ),
    );
  }
}

class BillingPage extends StatefulWidget {
  const BillingPage({super.key});
  @override
  State<BillingPage> createState() => _BillingPageState();
}

class _BillingPageState extends State<BillingPage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      data = await Api.billing();
    } catch (e) {
      error = AppError.message(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => _PageFrame(
          title: 'Aboneliğim',
          onRefresh: _load,
          loading: loading,
          error: error,
          children: [
            const _PageHero(
                title: 'Abonelik merkezi',
                subtitle:
                    'Paket, kalan süre ve kullanım limitlerini görüntüle.',
                icon: Icons.workspace_premium_outlined,
                badge: 'BILLING'),
            const SizedBox(height: 14),
            _KpiGrid(items: [
              _Kpi(
                  'Paket',
                  _text(data['planName'], _text(data['plan'], 'BASIC')),
                  Icons.workspace_premium_outlined),
              _Kpi('Kalan süre', '${_text(data['remainingDays'], '0')} gün',
                  Icons.event_available_outlined),
              _Kpi(
                  'Referans fiyat',
                  '${_text(data['estimatedMonthlyPriceTRY'], '0')} TL',
                  Icons.payments_outlined),
              _Kpi('Faturalama', _text(data['billingMode'], 'MANUAL_LICENSE'),
                  Icons.receipt_long_outlined)
            ]),
            const SizedBox(height: 14),
            _InfoCard(
                title: 'Plan limitleri', body: _limitsText(data['limits'])),
            const SizedBox(height: 12),
            const _InfoCard(
                title: 'Ödeme bağlantısı',
                body:
                    'Lisans ve manuel abonelik akışı hazır. Online ödeme için seçilecek ödeme sağlayıcısının anahtarları ve webhook adresi ayrıca tanımlanır.'),
            const SizedBox(height: 18),
            const _PoweredBy(),
          ]);
  String _limitsText(dynamic x) {
    if (x is! Map) return 'Limit bilgisi yok.';
    return ['maxMetaAccounts', 'maxAds', 'maxUsers']
        .where(x.containsKey)
        .map((k) => '$k: ${x[k]}')
        .join('\n');
  }
}

class CommercialCenterPage extends StatefulWidget {
  const CommercialCenterPage({super.key});

  @override
  State<CommercialCenterPage> createState() => _CommercialCenterPageState();
}

class _CommercialCenterPageState extends State<CommercialCenterPage> {
  Map<String, dynamic> overview = {};
  List<dynamic> plans = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final results = await Future.wait([
        Api.adminOverview(),
        Api.adminPlans(),
      ]);
      overview = Map<String, dynamic>.from(results[0] as Map);
      plans = List<dynamic>.from(results[1] as List);
      error = null;
    } catch (e) {
      error = AppError.message(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'V8 Ticari Merkez',
      onRefresh: _load,
      loading: loading,
      error: error,
      children: [
        const _PageHero(
          title: 'Ticari operasyon',
          subtitle: 'Plan kataloğu, tahmini MRR, lisans ve müşteri ekonomisi.',
          icon: Icons.storefront_outlined,
          badge: 'V8',
        ),
        const SizedBox(height: 14),
        _KpiGrid(
          items: [
            _Kpi(
                'Tahmini MRR',
                '${_text(overview['totalMRREstimateTRY'], '0')} TL',
                Icons.trending_up_outlined),
            _Kpi('Boş lisans', _text(overview['unusedLicenses'], '0'),
                Icons.vpn_key_outlined),
            _Kpi('Planlar', '${plans.length}', Icons.layers_outlined),
            _Kpi('Çalışma', 'HAZIR', Icons.verified_outlined),
          ],
        ),
        const SizedBox(height: 14),
        ...plans.map(
          (plan) => _PlanCard(
            plan: plan is Map
                ? Map<String, dynamic>.from(plan)
                : const <String, dynamic>{},
          ),
        ),
        const SizedBox(height: 18),
        const _PoweredBy(),
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;

  const _PlanCard({required this.plan});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _text(plan['name'], _text(plan['code'], 'Plan')),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Text(
                    '${_text(plan['monthlyPriceTRY'], '0')} TL/ay',
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill('${_text(plan['maxUsers'], '-')} kullanıcı'),
                  _Pill('${_text(plan['maxAds'], '-')} reklam'),
                  _Pill('${_text(plan['maxMetaAccounts'], '-')} Meta hesap'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool email = true;
  bool push = true;
  bool highCost = true;
  bool subscription = true;
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      final data = await Api.notificationPrefs();
      email = data['email'] != false;
      push = data['push'] != false;
      highCost = data['highCost'] != false;
      subscription = data['subscription'] != false;
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await Api.saveNotificationPrefs({
        'email': email,
        'push': push,
        'highCost': highCost,
        'subscription': subscription,
      });
      if (mounted) _snack('Bildirim tercihleri kaydedildi.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Bildirimler',
      onRefresh: _load,
      loading: loading,
      children: [
        const _PageHero(
          title: 'Uyarı merkezi',
          subtitle:
              'Yüksek maliyet ve abonelik bildirimlerinin davranışını belirle.',
          icon: Icons.notifications_active_outlined,
          badge: 'NOTIFY',
        ),
        const SizedBox(height: 14),
        _SwitchCard(
            title: 'E-posta bildirimleri',
            value: email,
            onChanged: (v) => setState(() => email = v)),
        _SwitchCard(
            title: 'Anlık bildirimler',
            value: push,
            onChanged: (v) => setState(() => push = v)),
        _SwitchCard(
            title: 'Yüksek mesaj maliyeti',
            value: highCost,
            onChanged: (v) => setState(() => highCost = v)),
        _SwitchCard(
            title: 'Abonelik süresi',
            value: subscription,
            onChanged: (v) => setState(() => subscription = v)),
        const SizedBox(height: 12),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label:
                Text(saving ? 'KAYDEDİLİYOR...' : 'BİLDİRİM AYARLARINI KAYDET'),
          ),
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Teslimat notu',
          body:
              'Bu ekran tercihleri kaydeder. Gerçek push/e-posta teslimi için bildirim sağlayıcısı ayrıca yapılandırılır.',
        ),
        const SizedBox(height: 18),
        const _PoweredBy(),
      ],
    );
  }
}

class _SwitchCard extends StatelessWidget {
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchCard(
      {required this.title, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          value: value,
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class BrandingPage extends StatefulWidget {
  const BrandingPage({super.key});

  @override
  State<BrandingPage> createState() => _BrandingPageState();
}

class _BrandingPageState extends State<BrandingPage> {
  final appName = TextEditingController();
  final logo = TextEditingController();
  final color = TextEditingController();
  final support = TextEditingController();
  bool loading = true;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.branding();
      appName.text = _text(data['appName'], 'Advise Digital');
      logo.text = _text(data['logoUrl'], '');
      color.text = _text(data['primaryColor'], '#4F46E5');
      support.text = _text(data['supportEmail'], '');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => saving = true);
    try {
      await Api.saveBranding({
        'appName': appName.text,
        'logoUrl': logo.text,
        'primaryColor': color.text,
        'supportEmail': support.text,
      });
      if (mounted) _snack('Marka ayarları kaydedildi.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  void dispose() {
    appName.dispose();
    logo.dispose();
    color.dispose();
    support.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Marka ayarları',
      onRefresh: _load,
      loading: loading,
      children: [
        const _PageHero(
          title: 'White Label',
          subtitle: 'Firma adı, logo, ana renk ve destek bilgisini sakla.',
          icon: Icons.palette_outlined,
          badge: 'BRANDING',
        ),
        const SizedBox(height: 14),
        _TextField(controller: appName, label: 'Uygulama / firma adı'),
        _TextField(controller: logo, label: 'Logo URL (opsiyonel)'),
        _TextField(controller: color, label: 'Ana renk'),
        _TextField(controller: support, label: 'Destek e-postası'),
        const SizedBox(height: 8),
        SizedBox(
          height: 52,
          child: FilledButton.icon(
            onPressed: saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: Text(saving ? 'KAYDEDİLİYOR...' : 'MARKA AYARLARINI KAYDET'),
          ),
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Not',
          body:
              'White Label verisi tenant bazında saklanır. Özel domain ve özel APK dağıtımı üretim ortamında ayrı yapılandırılır.',
        ),
        const SizedBox(height: 18),
        const _PoweredBy(),
      ],
    );
  }
}

class SecurityPage extends StatefulWidget {
  const SecurityPage({super.key});

  @override
  State<SecurityPage> createState() => _SecurityPageState();
}

class _SecurityPageState extends State<SecurityPage> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      data = await Api.securityOverview();
    } catch (e) {
      error = AppError.message(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tenantOk =
        data['tenantIsolated'] == true && data['multiTenant'] == true;
    return _PageFrame(
      title: 'Güvenlik',
      onRefresh: _load,
      loading: loading,
      error: error,
      children: [
        const _PageHero(
          title: 'Platform güvenliği',
          subtitle: 'Oturum, tenant, altyapı ve Meta durumunu kontrol et.',
          icon: Icons.security_outlined,
          badge: 'SECURITY',
        ),
        const SizedBox(height: 14),
        _SecurityTile(
          title: 'Oturum',
          good: tenantOk,
          lines: [
            'JWT: ${_text(data['jwtSessionDays'], '7')} gün',
            'Tenant izolasyonu: ${tenantOk ? 'AKTİF' : 'KONTROL ET'}',
            'Multi-tenant: ${data['multiTenant'] == true ? 'AKTİF' : 'KONTROL ET'}',
          ],
        ),
        _SecurityTile(
          title: 'Altyapı',
          good: data['httpsRecommended'] != true,
          lines: [
            'Ortam: ${_text(data['environment'])}',
            'PostgreSQL: ${data['databaseConfigured'] == true ? 'HAZIR' : 'YAPILANDIRILMADI'}',
            'HTTPS: ${data['httpsRecommended'] == true ? 'ÖNERİLİYOR' : 'UYGUN'}',
            'Meta: ${data['metaConnected'] == true ? 'BAĞLI' : 'BEKLİYOR'}',
          ],
        ),
        _SecurityTile(
          title: 'Kullanıcılar',
          good: true,
          lines: [
            'Toplam: ${_text(data['userCount'], '0')}',
            'Aktif: ${_text(data['activeUserCount'], '0')}',
          ],
        ),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Üretim kontrol listesi',
          body:
              'HTTPS, güçlü secret, PostgreSQL, tokenların backend’de tutulması, rate limit, yedekleme ve audit log.',
        ),
        const SizedBox(height: 18),
        const _PoweredBy(),
      ],
    );
  }
}

class _SecurityTile extends StatelessWidget {
  final String title;
  final List<String> lines;
  final bool good;

  const _SecurityTile(
      {required this.title, required this.lines, required this.good});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(good
                      ? Icons.verified_outlined
                      : Icons.warning_amber_outlined),
                  const SizedBox(width: 8),
                  Text(title,
                      style: const TextStyle(
                          fontWeight: FontWeight.w900, fontSize: 17)),
                ],
              ),
              const SizedBox(height: 8),
              ...lines.map((line) => Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(line,
                        style: TextStyle(color: Colors.grey.shade700)),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class DiagnosticsPage extends StatefulWidget {
  const DiagnosticsPage({super.key});
  @override
  State<DiagnosticsPage> createState() => _DiagnosticsPageState();
}

class _DiagnosticsPageState extends State<DiagnosticsPage> {
  bool loading = true;
  bool health = false;
  Map<String, dynamic> system = {};
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      health = await Api.health();
      system = await Api.systemHealth();
    } catch (e) {
      error = AppError.message(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Sistem Tanılama',
      onRefresh: _load,
      loading: loading,
      error: error,
      children: [
        const _PageHero(
          title: 'Bağlantı ve sistem testi',
          subtitle:
              'Telefon, backend, veritabanı ve sürüm durumunu tek ekranda kontrol et.',
          icon: Icons.health_and_safety_outlined,
          badge: 'DIAGNOSTICS',
        ),
        const SizedBox(height: 14),
        _DiagnosticTile(
            title: 'Backend /health',
            value: health ? 'ÇALIŞIYOR' : 'ULAŞILAMIYOR',
            good: health),
        _DiagnosticTile(
            title: 'Backend sürümü',
            value: _text(system['version']),
            good: system.isNotEmpty),
        _DiagnosticTile(
            title: 'Ortam',
            value: _text(system['environment']),
            good: system.isNotEmpty),
        _DiagnosticTile(
            title: 'Port',
            value: _text(system['port'], '3001'),
            good: system.isNotEmpty),
        _DiagnosticTile(
            title: 'Veritabanı',
            value: system['database'] is Map &&
                    system['database']['connected'] == true
                ? 'BAĞLI'
                : 'JSON / BEKLEMEDE',
            good: system['database'] is Map &&
                system['database']['connected'] == true),
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Telefon bağlantısı',
          body:
              'Yerel kullanımda telefon ve bilgisayar aynı Wi‑Fi üzerinde olmalı. Backend adresi Bağlantı Ayarları ekranından değiştirilebilir.',
        ),
        const SizedBox(height: 18),
        const _PoweredBy(),
      ],
    );
  }
}

class _DiagnosticTile extends StatelessWidget {
  final String title;
  final String value;
  final bool good;
  const _DiagnosticTile(
      {required this.title, required this.value, required this.good});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        child: ListTile(
          leading: Icon(
              good ? Icons.check_circle_outline : Icons.warning_amber_outlined),
          title:
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
          trailing: Text(value,
              style: TextStyle(
                  fontWeight: FontWeight.w900,
                  color:
                      good ? Colors.green.shade700 : Colors.orange.shade800)),
        ),
      ),
    );
  }
}

class MetaConnectionPage extends StatefulWidget {
  const MetaConnectionPage({super.key});

  @override
  State<MetaConnectionPage> createState() => _MetaConnectionPageState();
}

class _MetaConnectionPageState extends State<MetaConnectionPage>
    with WidgetsBindingObserver {
  Map<String, dynamic> data = {};
  bool loading = true;
  bool busy = false;
  String? error;
  Map<String, dynamic> assets = {};
  String? selectedPage, selectedAccount;
  bool canManage = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !loading && !busy) _load();
  }

  Future<void> _load() async {
    if (mounted)
      setState(() {
        loading = true;
        error = null;
      });
    try {
      data = await Api.metaStatus();
      final me = await Api.me();
      canManage =
          ['ADMIN', 'CUSTOMER_ADMIN'].contains((me['user'] as Map?)?['role']);
      if (canManage && data['connected'] != true) {
        try {
          assets = await Api.metaAssets();
        } catch (_) {
          assets = {};
        }
      } else {
        assets = {};
      }
      final pages = (assets['pages'] as List? ?? []).whereType<Map>();
      final accounts = (assets['adAccounts'] as List? ?? []).whereType<Map>();
      if (!pages.any((row) => row['id']?.toString() == selectedPage))
        selectedPage = null;
      if (!accounts.any((row) => row['id']?.toString() == selectedAccount))
        selectedAccount = null;
    } catch (e) {
      error = AppError.message(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _connect() async {
    if (busy) return;
    setState(() => busy = true);
    try {
      final result = await Api.metaConnectStart();
      final url = Uri.tryParse(
          '${result['url'] ?? result['authUrl'] ?? result['authorizationUrl'] ?? ''}');
      if (url != null &&
          url.scheme == 'https' &&
          ['www.facebook.com', 'facebook.com'].contains(url.host)) {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication))
          throw const ApiException('Meta yetkilendirme ekranı açılamadı.');
        if (mounted)
          _snack(
              'Tarayıcıda Meta bağlantısını onayla, sonra bu ekranı yenile.');
        return;
      }
      await _load();
      if (mounted) {
        final username = _text(result['instagramUsername'],
            result['instagramUserId'] ?? 'Instagram');
        _snack(result['connected'] == true
            ? 'Instagram bağlandı: $username'
            : 'Meta bağlantısı için yetkilendirme gerekiyor.');
      }
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _disconnect() async {
    final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Meta bağlantısını kaldır?'),
                content: const Text(
                    'Reklam kontrolleri ve planlı Instagram yayınları bağlantı yeniden kurulana kadar çalışamaz.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Bağlantıyı kaldır'))
                ]));
    if (accepted != true || !mounted) return;
    setState(() => busy = true);
    try {
      await Api.metaDisconnect();
      await _load();
      if (mounted) _snack('Meta bağlantısı kaldırıldı.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _selectAssets() async {
    if (selectedPage == null || selectedAccount == null) return;
    setState(() => busy = true);
    try {
      await Api.selectMetaAssets(
          pageId: selectedPage!, adAccountId: selectedAccount!);
      assets = {};
      await _load();
      if (mounted) _snack('Sayfa, Instagram ve reklam hesabın bağlandı.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return _PageFrame(
      title: 'Meta & Instagram',
      onRefresh: _load,
      loading: loading,
      error: error,
      children: [
        const _PageHero(
          title: 'Meta bağlantı merkezi',
          subtitle:
              'Facebook, Instagram Business ve reklam hesabını tek yerden yönet.',
          icon: Icons.link_outlined,
          badge: 'META CONNECT',
        ),
        const SizedBox(height: 14),
        _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.cloud_done_outlined),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Bağlantı durumu',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w900))),
                    _StatusBadge(
                        text:
                            data['connected'] == true ? 'BAĞLI' : 'BAĞLI DEĞİL',
                        positive: data['connected'] == true),
                  ],
                ),
                const SizedBox(height: 12),
                _Line(
                    label: 'Instagram',
                    value: _text(data['instagramUsername'],
                        _text(data['instagramUserId'], 'Bekliyor'))),
                _Line(
                    label: 'Reklam hesabı',
                    value: _text(data['adAccountId'], 'Bekliyor')),
                _Line(label: 'Sayfa', value: _text(data['pageId'], 'Bekliyor')),
                _Line(
                    label: 'Business',
                    value: _text(data['businessId'], 'Bekliyor')),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: data['connected'] == true
                      ? OutlinedButton.icon(
                          onPressed: busy || !canManage ? null : _disconnect,
                          icon: const Icon(Icons.link_off_outlined),
                          label: const Text('BAĞLANTIYI KES'),
                        )
                      : FilledButton.icon(
                          onPressed: busy || !canManage ? null : _connect,
                          icon: const Icon(Icons.login_outlined),
                          label: Text(
                              busy ? 'AÇILIYOR...' : 'META / INSTAGRAM BAĞLA'),
                        ),
                ),
              ],
            ),
          ),
        ),
        if (assets['available'] == true) ...[
          const SizedBox(height: 16),
          ProductSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Hangi hesapla devam edeceksin?',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                const Text(
                    'Instagram hesabı Sayfana bağlı olmalı. Bağlanacak hesapları açıkça seç.'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    initialValue: selectedPage,
                    isExpanded: true,
                    decoration: const InputDecoration(
                        labelText: 'Facebook Sayfası / Instagram'),
                    items: (assets['pages'] is List
                            ? assets['pages'] as List
                            : [])
                        .whereType<Map>()
                        .map((p) => DropdownMenuItem(
                            value: p['id'].toString(),
                            child: Text(
                                '${p['name'] ?? 'Sayfa'}${(p['instagramUserId']?.toString() ?? '').isEmpty ? ' · Instagram bağlantısı yok' : ''}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged:
                        busy ? null : (v) => setState(() => selectedPage = v)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                    initialValue: selectedAccount,
                    isExpanded: true,
                    decoration:
                        const InputDecoration(labelText: 'Reklam hesabı'),
                    items: (assets['adAccounts'] is List
                            ? assets['adAccounts'] as List
                            : [])
                        .whereType<Map>()
                        .map((a) => DropdownMenuItem(
                            value: a['id'].toString(),
                            child: Text('${a['name'] ?? 'Reklam hesabı'}',
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: busy
                        ? null
                        : (v) => setState(() => selectedAccount = v)),
                const SizedBox(height: 16),
                FilledButton.icon(
                    onPressed:
                        busy || selectedPage == null || selectedAccount == null
                            ? null
                            : _selectAssets,
                    icon: const Icon(Icons.link),
                    label: const Text('Seçili hesapları bağla')),
              ])),
        ],
        const SizedBox(height: 12),
        const _InfoCard(
          title: 'Güvenli bağlantı',
          body:
              'Bağlantıyı tarayıcıda Meta hesabınla onayla. Geri döndüğünde bağlı Sayfa, Instagram ve reklam hesabını kontrol et.',
        ),
        const SizedBox(height: 18),
        const _PoweredBy(),
      ],
    );
  }
}

class AdminCustomersPage extends StatefulWidget {
  const AdminCustomersPage({super.key});

  @override
  State<AdminCustomersPage> createState() => _AdminCustomersPageState();
}

class _AdminCustomersPageState extends State<AdminCustomersPage> {
  List<dynamic> customers = [];
  bool loading = true;
  String search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      customers = await Api.adminCustomers();
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _createCustomer() async {
    final company = TextEditingController();
    final fullName = TextEditingController();
    final username = TextEditingController();
    final password = TextEditingController();
    final days = TextEditingController(text: '30');
    String plan = 'PRO';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            return AlertDialog(
              title: const Text('Yeni müşteri hesabı'),
              content: SingleChildScrollView(
                child: Column(
                  children: [
                    _DialogField(company, 'Şirket adı'),
                    _DialogField(fullName, 'Yetkili adı'),
                    _DialogField(username, 'Kullanıcı adı'),
                    _DialogField(password, 'İlk şifre', obscure: true),
                    DropdownButtonFormField<String>(
                      initialValue: plan,
                      decoration: const InputDecoration(labelText: 'Paket'),
                      items: const [
                        DropdownMenuItem(value: 'BASIC', child: Text('BASIC')),
                        DropdownMenuItem(value: 'PRO', child: Text('PRO')),
                        DropdownMenuItem(
                            value: 'AGENCY', child: Text('AGENCY')),
                        DropdownMenuItem(
                            value: 'ENTERPRISE', child: Text('ENTERPRISE')),
                      ],
                      onChanged: (value) =>
                          setDialog(() => plan = value ?? plan),
                    ),
                    const SizedBox(height: 10),
                    _DialogField(days, 'Abonelik süresi (gün)'),
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('İPTAL')),
                FilledButton(
                  onPressed: () async {
                    try {
                      await Api.createCustomer(
                        companyName: company.text,
                        username: username.text,
                        password: password.text,
                        plan: plan,
                        days: int.tryParse(days.text) ?? 30,
                        fullName: fullName.text,
                      );
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(AppError.message(e))));
                    }
                  },
                  child: const Text('OLUŞTUR'),
                ),
              ],
            );
          },
        );
      },
    );

    company.dispose();
    fullName.dispose();
    username.dispose();
    password.dispose();
    days.dispose();
    if (result == true) await _load();
  }

  Future<void> _editCustomer(dynamic customer) async {
    final company =
        TextEditingController(text: _text(customer['companyName'], ''));
    String plan = _upper(customer['plan']);
    if (!['BASIC', 'PRO', 'AGENCY', 'ENTERPRISE'].contains(plan))
      plan = 'BASIC';

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            return AlertDialog(
              title: const Text('Müşteriyi düzenle'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _DialogField(company, 'Şirket adı'),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: plan,
                    decoration: const InputDecoration(labelText: 'Paket'),
                    items: const [
                      DropdownMenuItem(value: 'BASIC', child: Text('BASIC')),
                      DropdownMenuItem(value: 'PRO', child: Text('PRO')),
                      DropdownMenuItem(value: 'AGENCY', child: Text('AGENCY')),
                      DropdownMenuItem(
                          value: 'ENTERPRISE', child: Text('ENTERPRISE')),
                    ],
                    onChanged: (value) => setDialog(() => plan = value ?? plan),
                  ),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('İPTAL')),
                FilledButton(
                  onPressed: () async {
                    try {
                      await Api.updateCustomer(_text(customer['id']), {
                        'companyName': company.text,
                        'plan': plan,
                      });
                      if (ctx.mounted) Navigator.pop(ctx, true);
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(AppError.message(e))));
                    }
                  },
                  child: const Text('KAYDET'),
                ),
              ],
            );
          },
        );
      },
    );

    company.dispose();
    if (result == true) await _load();
  }

  Future<void> _deleteCustomer(dynamic customer) async {
    final name = _text(customer['companyName'], 'Bu müşteri');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteriyi sil?'),
        content: Text(
            '$name hesabı; kullanıcıları, içerikleri, ayarları ve kayıtları ile birlikte kalıcı olarak silinecek.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İPTAL')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('KALICI SİL')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await Api.deleteCustomer(_text(customer['id']));
      await _load();
      _snack('Müşteri silindi.');
    } catch (e) {
      _snack(AppError.message(e));
    }
  }

  Future<void> _toggleCustomer(dynamic customer) async {
    try {
      await Api.toggleCustomer(_text(customer['id']));
      await _load();
    } catch (e) {
      _snack(AppError.message(e));
    }
  }

  Future<void> _extendCustomer(dynamic customer) async {
    final days = TextEditingController(text: '30');
    final value = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aboneliği uzat'),
        content: TextField(
            controller: days,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Kaç gün?')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('İPTAL')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, int.tryParse(days.text)),
              child: const Text('UZAT')),
        ],
      ),
    );
    days.dispose();
    if (value == null) return;
    try {
      await Api.extendCustomer(_text(customer['id']), value);
      await _load();
    } catch (e) {
      _snack(AppError.message(e));
    }
  }

  Future<void> _resetCustomer(dynamic customer) async {
    final password = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteri şifresi'),
        content: TextField(
            controller: password,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Yeni şifre')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İPTAL')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('KAYDET')),
        ],
      ),
    );
    if (ok == true) {
      try {
        await Api.resetCustomerPassword(_text(customer['id']), password.text);
        _snack('Şifre güncellendi.');
      } catch (e) {
        _snack(AppError.message(e));
      }
    }
    password.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = search.trim().toLowerCase();
    final filtered = customers.where((customer) {
      final user = customer['user'] is Map
          ? Map<String, dynamic>.from(customer['user'])
          : const <String, dynamic>{};
      final haystack =
          '${customer['companyName']} ${user['username']} ${user['fullName']}'
              .toLowerCase();
      return query.isEmpty || haystack.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.home_outlined)),
        title: const Text('Müşteriler',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createCustomer,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('YENİ MÜŞTERİ'),
      ),
      body: ProductContent(
          child: loading
              ? const ProductLoadingSkeleton()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                    children: [
                      const _PageHero(
                        title: 'Müşteri yönetimi',
                        subtitle:
                            'Hesap oluştur, düzenle, aktif/pasif yap, süre uzat, şifre sıfırla veya sil.',
                        icon: Icons.people_alt_outlined,
                        badge: 'CRM',
                      ),
                      const SizedBox(height: 14),
                      TextField(
                        onChanged: (value) => setState(() => search = value),
                        decoration: const InputDecoration(
                            hintText: 'Müşteri ara',
                            prefixIcon: Icon(Icons.search_rounded)),
                      ),
                      const SizedBox(height: 12),
                      if (filtered.isEmpty)
                        const _EmptyCard(
                          icon: Icons.people_outline,
                          title: 'Müşteri bulunamadı',
                          body:
                              'Yeni müşteri oluşturmak için sağ alttaki düğmeyi kullan.',
                        ),
                      ...filtered.map(
                        (customer) => _AdminCustomerCard(
                          customer: Map<String, dynamic>.from(customer),
                          onEdit: () => _editCustomer(customer),
                          onDelete: () => _deleteCustomer(customer),
                          onToggle: () => _toggleCustomer(customer),
                          onExtend: () => _extendCustomer(customer),
                          onReset: () => _resetCustomer(customer),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const _PoweredBy(),
                    ],
                  ),
                )),
    );
  }
}

class _AdminCustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onToggle;
  final VoidCallback onExtend;
  final VoidCallback onReset;

  const _AdminCustomerCard({
    required this.customer,
    required this.onEdit,
    required this.onDelete,
    required this.onToggle,
    required this.onExtend,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final user = customer['user'] is Map
        ? Map<String, dynamic>.from(customer['user'])
        : const <String, dynamic>{};
    final active = customer['active'] == true;
    final expired = customer['expired'] == true;
    final company = _text(customer['companyName'], 'A');
    final metaConnected =
        customer['meta'] is Map && customer['meta']['connected'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(child: Text(company[0].toUpperCase())),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(company,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 17)),
                        Text(
                            '${_text(user['username'])} • ${_text(user['fullName'])}',
                            style: TextStyle(color: Colors.grey.shade700)),
                      ],
                    ),
                  ),
                  _StatusBadge(
                    text: expired
                        ? 'SÜRE DOLDU'
                        : active
                            ? 'AKTİF'
                            : 'PASİF',
                    positive: active && !expired,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _Pill('${_text(customer['plan'])} PAKET'),
                  _Pill('Bitiş ${_date(customer['subscriptionEnd'])}'),
                  _Pill(metaConnected ? 'Meta bağlı' : 'Meta bekliyor'),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('DÜZENLE')),
                  OutlinedButton.icon(
                      onPressed: onToggle,
                      icon: Icon(active
                          ? Icons.pause_outlined
                          : Icons.play_arrow_outlined),
                      label: Text(active ? 'PASİFE AL' : 'AKTİFLEŞTİR')),
                  OutlinedButton.icon(
                      onPressed: onExtend,
                      icon: const Icon(Icons.event_available_outlined),
                      label: const Text('SÜRE UZAT')),
                  IconButton(
                      tooltip: 'Şifre sıfırla',
                      onPressed: onReset,
                      icon: const Icon(Icons.key_outlined)),
                  IconButton(
                      tooltip: 'Kalıcı sil',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded,
                          color: Colors.redAccent)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AdminLicensesPage extends StatefulWidget {
  const AdminLicensesPage({super.key});

  @override
  State<AdminLicensesPage> createState() => _AdminLicensesPageState();
}

class _AdminLicensesPageState extends State<AdminLicensesPage> {
  List<dynamic> licenses = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() => loading = true);
    try {
      licenses = await Api.licenses();
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  void _snack(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _createLicense() async {
    String plan = 'PRO';
    final days = TextEditingController(text: '30');
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialog) {
            return AlertDialog(
              title: const Text('Lisans üret'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: plan,
                    decoration: const InputDecoration(labelText: 'Paket'),
                    items: const [
                      DropdownMenuItem(value: 'BASIC', child: Text('BASIC')),
                      DropdownMenuItem(value: 'PRO', child: Text('PRO')),
                      DropdownMenuItem(value: 'AGENCY', child: Text('AGENCY')),
                      DropdownMenuItem(
                          value: 'ENTERPRISE', child: Text('ENTERPRISE')),
                    ],
                    onChanged: (value) => setDialog(() => plan = value ?? plan),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                      controller: days,
                      keyboardType: TextInputType.number,
                      decoration:
                          const InputDecoration(labelText: 'Geçerlilik (gün)')),
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('İPTAL')),
                FilledButton(
                  onPressed: () async {
                    try {
                      final data = await Api.createLicense(
                          plan, int.tryParse(days.text) ?? 30);
                      if (ctx.mounted) Navigator.pop(ctx, data);
                    } catch (e) {
                      if (ctx.mounted)
                        ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: Text(AppError.message(e))));
                    }
                  },
                  child: const Text('ÜRET'),
                ),
              ],
            );
          },
        );
      },
    );
    days.dispose();

    if (result == null || !mounted) return;
    await _load();
    final code = _text(result['code']);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Lisans hazır'),
        content: SelectableText(code,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT')),
          FilledButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              _snack('Lisans panoya kopyalandı.');
            },
            child: const Text('KOPYALA'),
          ),
        ],
      ),
    );
  }

  Future<void> _assign(dynamic license) async {
    try {
      final customers = await Api.adminCustomers();
      if (customers.isEmpty) {
        _snack('Önce müşteri oluştur.');
        return;
      }
      String tenantId = _text(customers.first['id']);
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (ctx, setDialog) {
              return AlertDialog(
                title: const Text('Lisansı müşteriye ata'),
                content: DropdownButtonFormField<String>(
                  initialValue: tenantId,
                  decoration: const InputDecoration(labelText: 'Müşteri'),
                  items: customers
                      .map((c) => DropdownMenuItem(
                          value: _text(c['id']),
                          child: Text(_text(c['companyName']))))
                      .toList(),
                  onChanged: (value) =>
                      setDialog(() => tenantId = value ?? tenantId),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('İPTAL')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('ATA')),
                ],
              );
            },
          );
        },
      );
      if (ok == true) {
        await Api.assignLicense(_text(license['id']), tenantId);
        await _load();
        _snack('Lisans müşteriye atandı.');
      }
    } catch (e) {
      _snack(AppError.message(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.home_outlined)),
        title: const Text('Lisanslar',
            style: TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createLicense,
        icon: const Icon(Icons.add_circle_outline),
        label: const Text('LİSANS ÜRET'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                children: [
                  const _PageHero(
                    title: 'Lisans kasası',
                    subtitle:
                        'Lisans üret, kopyala ve müşteriye ata. Kullanılmış lisanslar tekrar atanamaz.',
                    icon: Icons.vpn_key_outlined,
                    badge: 'LICENSE',
                  ),
                  const SizedBox(height: 14),
                  if (licenses.isEmpty)
                    const _EmptyCard(
                        icon: Icons.vpn_key_off_outlined,
                        title: 'Lisans yok',
                        body: 'İlk lisansını sağ alttaki düğmeden üret.'),
                  ...licenses.map(
                    (license) => _LicenseCard(
                      license: Map<String, dynamic>.from(license),
                      onAssign: _upper(license['status']) == 'UNUSED'
                          ? () => _assign(license)
                          : null,
                    ),
                  ),
                  const SizedBox(height: 18),
                  const _PoweredBy(),
                ],
              ),
            ),
    );
  }
}

class _LicenseCard extends StatelessWidget {
  final Map<String, dynamic> license;
  final VoidCallback? onAssign;

  const _LicenseCard({required this.license, this.onAssign});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _GlassCard(
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          leading: const CircleAvatar(child: Icon(Icons.vpn_key_outlined)),
          title: SelectableText(_text(license['code']),
              style: const TextStyle(fontWeight: FontWeight.w900)),
          subtitle: Text(
              '${_text(license['plan'])} • ${_text(license['days'])} gün • ${_upper(license['status'])}'),
          trailing: onAssign == null
              ? null
              : TextButton(onPressed: onAssign, child: const Text('ATA')),
        ),
      ),
    );
  }
}

class DecisionHubPage extends StatefulWidget {
  const DecisionHubPage({super.key, this.admin = false});
  final bool admin;
  @override
  State<DecisionHubPage> createState() => _DecisionHubPageState();
}

class _DecisionHubPageState extends State<DecisionHubPage> {
  List<dynamic> ads = [], adsets = [], logs = [];
  Map<String, dynamic> settings = {}, user = {};
  Map<String, dynamic>? report;
  bool loading = true, busy = false;
  String? error;
  bool get canOperate =>
      ['ADMIN', 'CUSTOMER_ADMIN', 'MANAGER', 'OPERATOR'].contains(user['role']);
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Future.wait<dynamic>(
          [Api.ads(), Api.adsets(), Api.logs(), Api.settings(), Api.me()]);
      ads = r[0] as List;
      adsets = r[1] as List;
      logs = r[2] as List;
      settings = Map<String, dynamic>.from(r[3] as Map);
      user = Map<String, dynamic>.from((r[4] as Map)['user'] as Map);
      error = null;
    } catch (e) {
      error = AppError.message(e);
    }
    if (mounted) setState(() => loading = false);
  }

  Future<void> _review() async {
    setState(() => busy = true);
    try {
      final r = await Api.geminiAdReview();
      if (mounted) setState(() => report = r);
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
    if (mounted) setState(() => busy = false);
  }

  String _label(String a) =>
      {
        'PAUSE': 'Durdur',
        'ACTIVATE': 'Yeniden başlat',
        'INCREASE_BUDGET': 'Bütçeyi artır',
        'DECREASE_BUDGET': 'Bütçeyi azalt',
        'APPLY_SAVED_AUDIENCE': 'Kaydedilmiş bölgeyi uygula',
        'KEEP': 'Aynen devam'
      }[a] ??
      'Değerlendir';
  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
          context: context,
          builder: (ctx) =>
              AlertDialog(title: Text(title), content: Text(body), actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Vazgeç')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Onayla ve uygula'))
              ])) ??
      false;
  Future<void> _apply(Map<String, dynamic> row) async {
    final action = _text(row['action'], 'KEEP');
    if (action == 'KEEP' || busy) return;
    if (!await _confirm('${_label(action)}?',
            "${_text(row['reason'])}\n\nBu aksiyon bağlı Meta hesabına uygulanacak.") ||
        !mounted) return;
    setState(() => busy = true);
    try {
      await Api.applyGeminiAdDecision(
          adSetId: _text(row['adSetId']), action: action);
      report = null;
      await _load();
      if (mounted) _snack('Onayladığın aksiyon uygulandı ve kaydedildi.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _toggle(dynamic ad) async {
    final next = _upper(ad['status'] ?? ad['effective_status']) == 'ACTIVE'
        ? 'PAUSED'
        : 'ACTIVE';
    if (!await _confirm(
            next == 'ACTIVE' ? 'Reklamı başlat?' : 'Reklamı durdur?',
            "${_text(ad['name'])} için yayın durumu değiştirilecek.") ||
        !mounted) return;
    setState(() => busy = true);
    try {
      await Api.status(_text(ad['id']), next);
      await _load();
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _budget(dynamic ad) async {
    final id = _text(ad['adset_id'], '');
    Map<String, dynamic> found = {};
    for (final x in adsets.whereType<Map>()) {
      if (_text(x['id']) == id) {
        found = Map<String, dynamic>.from(x);
        break;
      }
    }
    if (found.isEmpty) {
      _snack('Reklam grubu bilgisi bulunamadı.');
      return;
    }
    final before =
        (double.tryParse(_text(found['daily_budget'], '0')) ?? 0) / 100;
    final c = TextEditingController(text: before.toStringAsFixed(2));
    final value = await showDialog<double>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Günlük bütçeyi değiştir'),
                content: TextField(
                    controller: c,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'TL / gün', prefixText: '₺ ')),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(
                          ctx, double.tryParse(c.text.replaceAll(',', '.'))),
                      child: const Text('Devam et'))
                ]));
    c.dispose();
    if (value == null || !mounted) return;
    if (!await _confirm('Bütçe değişikliğini onayla',
            '${before.toStringAsFixed(2)} TL → ${value.toStringAsFixed(2)} TL / gün') ||
        !mounted) return;
    setState(() => busy = true);
    try {
      await Api.updateAdSetBudget(id, value);
      await _load();
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _insight(dynamic ad) async {
    try {
      final data = await Api.insights(_text(ad['id']));
      final rows = data['data'] is List ? data['data'] as List : [];
      if (!mounted) return;
      if (rows.isEmpty) {
        _snack('Bu reklam için henüz performans verisi yok.');
        return;
      }
      final row = Map<String, dynamic>.from(rows.first as Map);
      final spend = double.tryParse(_text(row['spend'], '0')) ?? 0;
      final actions = row['actions'] is List ? row['actions'] as List : [];
      double messages = 0;
      for (final type in [
        'onsite_conversion.messaging_conversation_started_7d',
        'onsite_conversion.messaging_first_reply',
        'messaging_conversation_started_7d'
      ]) {
        final matching = actions
            .whereType<Map>()
            .where((x) => x['action_type'] == type)
            .toList();
        if (matching.isNotEmpty) {
          messages = double.tryParse(_text(matching.first['value'], '0')) ?? 0;
          break;
        }
      }
      await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: Text(_text(ad['name'], 'Reklam')),
                  content: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    _Line(
                        label: 'Harcama',
                        value: '${spend.toStringAsFixed(2)} TL'),
                    _Line(label: 'Mesaj', value: messages.round().toString()),
                    _Line(
                        label: 'Mesaj maliyeti',
                        value: messages > 0
                            ? '${(spend / messages).toStringAsFixed(2)} TL'
                            : 'Henüz sonuç yok'),
                    _Line(label: 'CTR', value: _text(row['ctr'], '—'))
                  ])),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Kapat'))
                  ]));
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(AppError.message(text))));
  @override
  Widget build(BuildContext context) {
    final suggestions =
        report?['decisions'] is List ? report!['decisions'] as List : [];
    return _PageFrame(
        title: 'AI Karar Merkezi',
        onRefresh: _load,
        loading: loading,
        error: error,
        children: [
          ProductPageHeader(
              title: 'Öneri, karar ve aksiyon',
              subtitle:
                  'Gemini son 7 günlük veriyi inceler. Bir öneri, onay veya açık otomasyon olmadan reklamını değiştirmez.',
              actions: [
                FilledButton.icon(
                    onPressed: busy || !canOperate ? null : _review,
                    icon: const Icon(Icons.auto_awesome),
                    label:
                        Text(busy ? 'Analiz ediliyor…' : 'AI ile değerlendir'))
              ]),
          const SizedBox(height: 18),
          ProductInsightCard(
              title: 'Otomasyon kararı',
              body:
                  "12 saatlik pencere, minimum harcama ve hesap bütçe sınırı kontrol edilir. Otomatik yönetim ${settings['geminiAdsAuto'] == true ? 'açık.' : 'kapalı.'}",
              icon: Icons.shield_outlined,
              action: TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProductAutomationPage())),
                  child: const Text('Limitleri ve geçmişi gör'))),
          const SizedBox(height: 18),
          if (report != null)
            ProductSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  ProductStatusChip(
                      label: report!['source'] == 'GEMINI'
                          ? 'AI önerisi'
                          : 'AI analizi tamamlanamadı',
                      tone: report!['source'] == 'GEMINI' ? 'ai' : 'warning'),
                  const SizedBox(height: 12),
                  Text(report!['source'] == 'GEMINI'
                      ? _text(report!['summary'],
                          'Yeterli veriyle değişiklik önerilmedi.')
                      : AppError.message(report!['reason'] ??
                          report!['error'] ??
                          'AI servisine şu anda ulaşılamıyor.')),
                  for (final raw in suggestions.whereType<Map>())
                    Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: ProductSurface(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text(_text(raw['adSet']?['name'], 'Reklam grubu'),
                                  style:
                                      Theme.of(context).textTheme.titleMedium),
                              const SizedBox(height: 6),
                              Text(
                                  "${_label(_text(raw['action'], 'KEEP'))} · Güven: ${_text(raw['confidence'], '—')}%"),
                              const SizedBox(height: 8),
                              Text(_text(raw['reason'])),
                              if (_text(raw['action'], 'KEEP') != 'KEEP' &&
                                  canOperate)
                                Align(
                                    alignment: Alignment.centerRight,
                                    child: TextButton(
                                        onPressed: busy
                                            ? null
                                            : () => _apply(
                                                Map<String, dynamic>.from(raw)),
                                        child: const Text(
                                            'Öneriyi incele ve onayla')))
                            ]))),
                ])),
          const SizedBox(height: 20),
          if (ads.isEmpty)
            const ProductEmptyState(
                title: 'Reklam verisi henüz yok',
                body: 'Meta hesabını bağla ve ilk kampanyanı oluştur.',
                icon: Icons.campaign_outlined),
          ...ads.take(100).whereType<Map>().map((ad) => _AdCard(
              ad: Map<String, dynamic>.from(ad),
              onToggle: canOperate && !busy ? () => _toggle(ad) : null,
              onBudget: canOperate && !busy ? () => _budget(ad) : null,
              onInsight: () => _insight(ad))),
          const SizedBox(height: 24),
          Text('Gerçekleşen aksiyonlar',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          ...logs
              .whereType<Map>()
              .where((x) => [
                    'GEMINI_AD_ACTION',
                    'META_STATUS_CHANGED',
                    'BUDGET_CHANGED',
                    'EARLY_REVIEW_DONE',
                    'PAUSED',
                    'BUDGET_REALLOCATED'
                  ].contains(x['type']))
              .take(15)
              .map((x) => ExpansionTile(
                      title: Text(x['type'] == 'META_STATUS_CHANGED'
                          ? 'Yayın durumu değiştirildi'
                          : x['type'] == 'GEMINI_AD_ACTION'
                              ? 'AI aksiyonu uygulandı'
                              : x['type'] == 'EARLY_REVIEW_DONE'
                                  ? '12 saatlik değerlendirme tamamlandı'
                                  : 'Reklam yönetimi aksiyonu'),
                      subtitle: Text(_date(x['at'])),
                      children: [
                        Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(AppError.message(
                                x['reason'] ?? 'İşlem kayıt altına alındı.')))
                      ])),
        ]);
  }
}

class _AdCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final VoidCallback? onToggle;
  final VoidCallback? onBudget;
  final VoidCallback onInsight;

  const _AdCard(
      {required this.ad,
      required this.onToggle,
      required this.onBudget,
      required this.onInsight});

  @override
  Widget build(BuildContext context) {
    final status = _upper(ad['status'] ?? ad['effective_status']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(child: Icon(Icons.campaign_outlined)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(_text(ad['name'], 'Reklam'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 16))),
                  _StatusBadge(
                      text: status.isEmpty ? 'UNKNOWN' : status,
                      positive: status == 'ACTIVE'),
                ],
              ),
              const SizedBox(height: 8),
              Text('Ad ID: ${_text(ad['id'])}',
                  style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                      onPressed: onInsight,
                      icon: const Icon(Icons.analytics_outlined),
                      label: const Text('İNCELE')),
                  OutlinedButton.icon(
                      onPressed: onBudget,
                      icon: const Icon(Icons.account_balance_wallet_outlined),
                      label: const Text('BÜTÇE')),
                  FilledButton.icon(
                      onPressed: onToggle,
                      icon: Icon(status == 'PAUSED'
                          ? Icons.play_arrow_outlined
                          : Icons.pause_outlined),
                      label: Text(status == 'PAUSED' ? 'AÇ' : 'DUR')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PageFrame extends StatelessWidget {
  final String title;
  final Future<void> Function() onRefresh;
  final bool loading;
  final String? error;
  final List<Widget> children;

  const _PageFrame(
      {required this.title,
      required this.onRefresh,
      required this.loading,
      required this.children,
      this.error});

  @override
  Widget build(BuildContext context) {
    final content = <Widget>[...children];
    if (error != null) {
      content.addAll([
        const SizedBox(height: 12),
        _InfoCard(title: 'Veri isteği başarısız', body: _text(error)),
      ]);
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
            onPressed: () => _goHome(context),
            icon: const Icon(Icons.home_outlined)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        actions: [
          IconButton(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded))
        ],
      ),
      body: ProductContent(
          child: loading
              ? const ProductLoadingSkeleton()
              : RefreshIndicator(
                  onRefresh: onRefresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
                    children: content,
                  ),
                )),
    );
  }
}

class _PageHero extends StatelessWidget {
  final String title, subtitle, badge;
  final IconData icon;
  const _PageHero(
      {required this.title,
      required this.subtitle,
      required this.icon,
      required this.badge});
  @override
  Widget build(BuildContext context) =>
      ProductPageHeader(title: title, subtitle: subtitle);
}

class _Kpi {
  final String title;
  final String value;
  final IconData icon;

  const _Kpi(this.title, this.value, this.icon);
}

class _KpiGrid extends StatelessWidget {
  final List<_Kpi> items;
  const _KpiGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.55,
      ),
      itemCount: items.length,
      itemBuilder: (_, index) {
        final item = items[index];
        return _GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(item.icon,
                    size: 23, color: Theme.of(context).colorScheme.primary),
                const Spacer(),
                Text(item.value,
                    style: const TextStyle(
                        fontSize: 22, fontWeight: FontWeight.w900)),
                Text(item.title,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String body;
  const _InfoCard({required this.title, required this.body});

  @override
  Widget build(BuildContext context) => _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(15),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 7),
              Text(body,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.45)),
            ],
          ),
        ),
      );
}

class _EmptyCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;
  const _EmptyCard(
      {required this.icon, required this.title, required this.body});

  @override
  Widget build(BuildContext context) => _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(25),
          child: Column(
            children: [
              Icon(icon, size: 48, color: Colors.grey.shade500),
              const SizedBox(height: 10),
              Text(title,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w900)),
              const SizedBox(height: 6),
              Text(body,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade700, height: 1.4)),
            ],
          ),
        ),
      );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});
  @override
  Widget build(BuildContext context) =>
      ProductSurface(padding: EdgeInsets.zero, child: child);
}

class _StatusBadge extends StatelessWidget {
  final String text;
  final bool positive;
  const _StatusBadge({required this.text, required this.positive});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: positive ? const Color(0xFFEAF8EE) : const Color(0xFFF1F2F5),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w900,
            color: positive ? const Color(0xFF11753A) : Colors.grey.shade700,
          ),
        ),
      );
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: const Color(0xFFECECF2)),
        ),
        child: Text(text,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      );
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line({required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
                width: 110,
                child: Text(label,
                    style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600))),
            Expanded(
                child: Text(value,
                    style: const TextStyle(fontWeight: FontWeight.w800))),
          ],
        ),
      );
}

class _TextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  const _TextField({required this.controller, required this.label});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
            controller: controller,
            decoration: InputDecoration(labelText: label)),
      );
}

class _DialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscure;
  const _DialogField(this.controller, this.label, {this.obscure = false});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
            controller: controller,
            obscureText: obscure,
            decoration: InputDecoration(labelText: label)),
      );
}

class _PoweredBy extends StatelessWidget {
  final bool inverse;
  final bool compact;
  const _PoweredBy({this.inverse = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final color = inverse ? const Color(0xD9FFFFFF) : Colors.grey.shade500;
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded,
              size: compact ? 12 : 14, color: color),
          const SizedBox(width: 4),
          Text(
            'Powered by Advise Digital',
            style: TextStyle(
                fontSize: compact ? 10 : 11,
                fontWeight: FontWeight.w700,
                color: color),
          ),
        ],
      ),
    );
  }
}
