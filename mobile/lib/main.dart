import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';
import 'config.dart';
import 'key_page.dart';
import 'v78_pages.dart';
import 'v13_pro.dart';
import 'social_ads_page.dart';

void main() => runApp(const AdviseDigitalApp());
void _mainGoHome(BuildContext context) {
  Navigator.of(context).popUntil((route) => route.isFirst);
}

Widget _mainHomeLeading(BuildContext context) => IconButton(
  onPressed: () => _mainGoHome(context),
  icon: const Icon(Icons.home_outlined),
);

class AdviseDigitalApp extends StatelessWidget {
  const AdviseDigitalApp({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF4F46E5), brightness: Brightness.light);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: AppConfig.appName,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: scheme,
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0, backgroundColor: Color(0xFFF6F7FB)),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero, elevation: 0, surfaceTintColor: Colors.white),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Color(0xFFE6E8F0))),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: scheme.primary, width: 1.4)),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

String _formatDate(dynamic value) {
  if (value == null || value.toString().isEmpty) return '-';
  final d = DateTime.tryParse(value.toString());
  if (d == null) return value.toString();
  final local = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(local.day)}.${two(local.month)}.${local.year} ${two(local.hour)}:${two(local.minute)}';
}

String _upper(dynamic value) => value?.toString().toUpperCase() ?? '';
String _relativeDate(dynamic value) {
  final d = DateTime.tryParse(value?.toString() ?? '');
  if (d == null) return '-';
  final diff = DateTime.now().difference(d.toLocal());
  if (diff.inMinutes < 1) return 'az önce';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce';
  if (diff.inHours < 24) return '${diff.inHours} sa önce';
  if (diff.inDays < 7) return '${diff.inDays} gün önce';
  return _formatDate(value).split(' ').first;
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final username = TextEditingController();
  final password = TextEditingController();
  bool loading = false;
  bool hidePassword = true;
  String? error;

  @override
  void dispose() {
    username.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (username.text.trim().isEmpty || password.text.isEmpty) {
      setState(() => error = 'Kullanıcı adı ve şifre gerekli.');
      return;
    }
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await Api.login(username.text, password.text);
      final user = Map<String, dynamic>.from(result['user'] ?? const {});
      if (!mounted) return;
      final role = _upper(user['role']);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => role == 'ADMIN' ? const AdminDashboard() : const CustomerDashboard()),
      );
    } catch (e) {
      if (mounted) setState(() => error = e.toString());
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color(0xFFF0F2FF), Color(0xFFF9FAFC)]),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(28), boxShadow: const [BoxShadow(blurRadius: 28, color: Color(0x19000000), offset: Offset(0, 10))]),
                      child: ClipRRect(borderRadius: BorderRadius.circular(20), child: Image.asset('assets/advise_logo.jpg', width: 150, height: 150, fit: BoxFit.contain)),
                    ),
                    const SizedBox(height: 18),
                    const Text('ADVISE DIGITAL', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, letterSpacing: 1.1)),
                    const SizedBox(height: 6),
                    Text('Reklam yönetimi • optimizasyon • otomasyon', style: TextStyle(color: Colors.grey.shade700)),
                    const SizedBox(height: 24),
                    _GlassCard(
                      child: Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _Eyebrow('GÜVENLİ GİRİŞ'),
                            const SizedBox(height: 6),
                            const Text('Hesabına giriş yap', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            const SizedBox(height: 18),
                            TextField(controller: username, textInputAction: TextInputAction.next, decoration: const InputDecoration(labelText: 'Kullanıcı adı', prefixIcon: Icon(Icons.person_outline))),
                            const SizedBox(height: 12),
                            TextField(
                              controller: password,
                              obscureText: hidePassword,
                              onSubmitted: (_) => _login(),
                              decoration: InputDecoration(
                                labelText: 'Şifre',
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(onPressed: () => setState(() => hidePassword = !hidePassword), icon: Icon(hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined)),
                              ),
                            ),
                            if (error != null) ...[
                              const SizedBox(height: 12),
                              Container(width: double.infinity, padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(12)), child: Text(error!, style: const TextStyle(color: Color(0xFFB42318)))),
                            ],
                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: FilledButton.icon(
                                onPressed: loading ? null : _login,
                                icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login_rounded),
                                label: Text(loading ? 'GİRİŞ YAPILIYOR...' : 'GİRİŞ YAP'),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Center(child: TextButton.icon(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const KeyPage())), icon: const Icon(Icons.link_rounded), label: const Text('Bağlantı ayarları'))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    const _PoweredBy(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});
  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  Map<String, dynamic> stats = {};
  List<dynamic> customers = [];
  List<dynamic> licenses = [];
  bool loading = true;
  String search = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    try {
      final result = await Future.wait([Api.adminStats(), Api.adminCustomers(), Api.licenses()]);
      if (!mounted) return;
      setState(() {
        stats = Map<String, dynamic>.from(result[0] as Map);
        customers = List<dynamic>.from(result[1] as List);
        licenses = List<dynamic>.from(result[2] as List);
        loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => loading = false);
      _snack(e.toString());
    }
  }

  void _snack(String text) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text), behavior: SnackBarBehavior.floating));

  Future<void> _logout() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  Future<void> _createCustomer() async {
    final company = TextEditingController();
    final fullName = TextEditingController();
    final user = TextEditingController();
    final pass = TextEditingController(text: 'Advise123!');
    final days = TextEditingController(text: '30');
    String plan = 'PRO';
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Yeni müşteri hesabı'),
          content: SingleChildScrollView(
            child: Column(children: [
              TextField(controller: company, decoration: const InputDecoration(labelText: 'Şirket adı')),
              const SizedBox(height: 10),
              TextField(controller: fullName, decoration: const InputDecoration(labelText: 'Yetkili adı')),
              const SizedBox(height: 10),
              TextField(controller: user, decoration: const InputDecoration(labelText: 'Kullanıcı adı')),
              const SizedBox(height: 10),
              TextField(controller: pass, decoration: const InputDecoration(labelText: 'İlk şifre')),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: plan,
                decoration: const InputDecoration(labelText: 'Paket'),
                items: const [DropdownMenuItem(value: 'BASIC', child: Text('BASIC')), DropdownMenuItem(value: 'PRO', child: Text('PRO')), DropdownMenuItem(value: 'AGENCY', child: Text('AGENCY'))],
                onChanged: (v) => setDialog(() => plan = v ?? 'PRO'),
              ),
              const SizedBox(height: 10),
              TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Abonelik süresi (gün)')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                try {
                  await Api.createCustomer(companyName: company.text, username: user.text, password: pass.text, plan: plan, days: int.tryParse(days.text) ?? 30, fullName: fullName.text);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('OLUŞTUR'),
            ),
          ],
        ),
      ),
    );
    company.dispose();
    fullName.dispose();
    user.dispose();
    pass.dispose();
    days.dispose();
    if (created == true) await _load();
  }

  Future<void> _extend(dynamic customer) async {
    final days = TextEditingController(text: '30');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aboneliği uzat'),
        content: TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Kaç gün?')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              try {
                await Api.extendCustomer(customer['id'].toString(), int.tryParse(days.text) ?? 30);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('UZAT'),
          ),
        ],
      ),
    );
    days.dispose();
    if (ok == true) await _load();
  }

  Future<void> _toggle(dynamic customer) async {
    try {
      await Api.toggleCustomer(customer['id'].toString());
      await _load();
    } catch (e) {
      _snack(e.toString());
    }
  }

  Future<void> _resetPassword(dynamic customer) async {
    final controller = TextEditingController(text: 'Advise123!');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Müşteri şifresi'),
        content: TextField(controller: controller, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni şifre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              try {
                await Api.resetCustomerPassword(customer['id'].toString(), controller.text);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('KAYDET'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (ok == true) _snack('Müşteri şifresi güncellendi.');
  }

  Future<void> _createLicense() async {
    String plan = 'PRO';
    final days = TextEditingController(text: '30');
    final created = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Lisans üret'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              initialValue: plan,
              decoration: const InputDecoration(labelText: 'Paket'),
              items: const [DropdownMenuItem(value: 'BASIC', child: Text('BASIC')), DropdownMenuItem(value: 'PRO', child: Text('PRO')), DropdownMenuItem(value: 'AGENCY', child: Text('AGENCY'))],
              onChanged: (v) => setDialog(() => plan = v ?? 'PRO'),
            ),
            const SizedBox(height: 10),
            TextField(controller: days, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Geçerlilik (gün)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                try {
                  final x = await Api.createLicense(plan, int.tryParse(days.text) ?? 30);
                  if (ctx.mounted) Navigator.pop(ctx, x);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('ÜRET'),
            ),
          ],
        ),
      ),
    );
    days.dispose();
    if (created != null && mounted) {
      await _load();
      _showCode(created['code']?.toString() ?? '-');
    }
  }

  Future<void> _showCode(String code) async {
    await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Lisans hazır'), content: SelectableText(code, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT'))]));
  }

  Future<void> _accountPage() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
  }

  @override
  Widget build(BuildContext context) {
    final filtered = customers.where((c) {
      final q = search.trim().toLowerCase();
      if (q.isEmpty) return true;
      final user = c['user'] is Map ? Map<String, dynamic>.from(c['user']) : <String, dynamic>{};
      return '${c['companyName']} ${user['username']} ${user['fullName']}'.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        leading: Builder(builder: (ctx) => IconButton(tooltip: 'Menü', icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer())),
        title: const Text('Sistem Yönetimi', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: loading ? null : _load, icon: const Icon(Icons.refresh_rounded)), IconButton(onPressed: _logout, icon: const Icon(Icons.logout_rounded))],
      ),
      drawer: _MainDrawer(admin: true, onAccount: _accountPage),
      floatingActionButton: FloatingActionButton.extended(onPressed: _createCustomer, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Müşteri')), 
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 100),
                children: [
                  _DashboardHero(title: 'Kontrol Merkezi', subtitle: 'AdVise AI kiralama, lisans ve müşteri operasyonlarını tek ekrandan yönet.', icon: Icons.admin_panel_settings_rounded, badge: 'SUPER ADMIN'),
                  const SizedBox(height: 14),
                  _AdminMetrics(stats: stats),
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Hızlı işlemler', action: TextButton.icon(onPressed: _createLicense, icon: const Icon(Icons.vpn_key_rounded), label: const Text('Lisans üret'))),
                  _QuickGrid(items: [
                    _QuickAction(title: 'Müşteri oluştur', icon: Icons.person_add_alt_1_rounded, onTap: _createCustomer),
                    _QuickAction(title: 'Lisans üret', icon: Icons.key_rounded, onTap: _createLicense),
                    _QuickAction(title: 'Reklam kararları', icon: Icons.auto_graph_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DecisionHubPage(admin: true)))),
                    _QuickAction(title: 'Sistem ayarları', icon: Icons.tune_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage(admin: true)))),
                    _QuickAction(title: 'Advise Pro', icon: Icons.stars_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProHubPage(admin: true)))),
                  ]),
                  const SizedBox(height: 18),
                  _SectionHeader(title: 'Müşteri portföyü', action: SizedBox(width: 190, child: TextField(onChanged: (v) => setState(() => search = v), decoration: const InputDecoration(isDense: true, hintText: 'Müşteri ara', prefixIcon: Icon(Icons.search_rounded))))),
                  const SizedBox(height: 8),
                  if (filtered.isEmpty) _EmptyState(icon: Icons.people_outline, title: 'Müşteri bulunamadı', subtitle: 'Arama kriterini değiştir veya yeni müşteri oluştur.'),
                  ...filtered.take(50).map((c) => _CustomerCard(customer: c, onToggle: () => _toggle(c), onExtend: () => _extend(c), onReset: () => _resetPassword(c))),
                  const SizedBox(height: 18),
                  _SectionHeader(title: 'Lisans envanteri', action: Text('${licenses.length} kayıt', style: Theme.of(context).textTheme.labelLarge)),
                  const SizedBox(height: 8),
                  if (licenses.isEmpty) _EmptyState(icon: Icons.vpn_key_off_outlined, title: 'Henüz lisans yok', subtitle: 'Yeni lisans üretip müşteriye atayabilirsin.'),
                  ...licenses.take(30).map((l) => _LicenseTile(license: l, onAssign: _upper(l['status']) == 'UNUSED' ? () => _assignLicense(l) : null)),
                  const SizedBox(height: 18),
                  _InfoCard(icon: Icons.security_rounded, title: 'Sistem güvenliği', body: 'JWT oturumu, tenant izolasyonu ve abonelik kontrolü aktif. Müşteri verileri birbirinden ayrılmıştır.'),
                  const SizedBox(height: 14),
                  const _PoweredBy(),
                ],
              ),
            ),
    );
  }

  Future<void> _assignLicense(dynamic license) async {
    final usable = customers.where((x) => x['id'] != null).toList();
    if (usable.isEmpty) {
      _snack('Önce müşteri oluştur.');
      return;
    }
    String? tenantId = usable.first['id']?.toString();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Lisansı müşteriye ata'),
          content: DropdownButtonFormField<String>(
            initialValue: tenantId,
            items: usable.map((c) => DropdownMenuItem(value: c['id'].toString(), child: Text('${c['companyName']}'))).toList(),
            decoration: const InputDecoration(labelText: 'Müşteri'),
            onChanged: (v) => setDialog(() => tenantId = v),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                try {
                  await Api.assignLicense(license['id'].toString(), tenantId!);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
                }
              },
              child: const Text('ATA'),
            ),
          ],
        ),
      ),
    );
    if (ok == true) await _load();
  }
}

class _AdminMetrics extends StatelessWidget {
  final Map<String, dynamic> stats;
  const _AdminMetrics({required this.stats});
  @override
  Widget build(BuildContext context) {
    final list = <_MetricData>[
      _MetricData('Müşteri', '${stats['totalCustomers'] ?? 0}', Icons.business_rounded, 'Toplam'),
      _MetricData('Aktif', '${stats['activeCustomers'] ?? 0}', Icons.check_circle_rounded, 'Kullanımda'),
      _MetricData('Pasif', '${stats['passiveCustomers'] ?? 0}', Icons.pause_circle_rounded, 'Beklemede'),
      _MetricData('Yaklaşan', '${stats['expiringSoon'] ?? 0}', Icons.schedule_rounded, '7 gün içinde'),
      _MetricData('Kullanıcı', '${stats['totalUsers'] ?? 0}', Icons.groups_rounded, 'Hesap'),
      _MetricData('Lisans', '${stats['unusedLicenses'] ?? 0}', Icons.vpn_key_rounded, 'Boş'),
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.55),
      itemCount: list.length,
      itemBuilder: (_, i) => _MetricCard(data: list[i]),
    );
  }
}

class _MetricData {
  final String title, value, hint;
  final IconData icon;
  _MetricData(this.title, this.value, this.icon, this.hint);
}

class _MetricCard extends StatelessWidget {
  final _MetricData data;
  const _MetricCard({required this.data});
  @override
  Widget build(BuildContext context) => _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Icon(data.icon, size: 22, color: Theme.of(context).colorScheme.primary), Text(data.hint, style: Theme.of(context).textTheme.labelSmall)]),
            const Spacer(),
            Text(data.value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            Text(data.title, style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600)),
          ]),
        ),
      );
}

class _CustomerCard extends StatelessWidget {
  final Map<String, dynamic> customer;
  final VoidCallback onToggle, onExtend, onReset;
  const _CustomerCard({required this.customer, required this.onToggle, required this.onExtend, required this.onReset});
  @override
  Widget build(BuildContext context) {
    final user = customer['user'] is Map ? Map<String, dynamic>.from(customer['user']) : <String, dynamic>{};
    final active = customer['active'] == true;
    final expired = customer['expired'] == true;
    final meta = customer['meta'] is Map ? Map<String, dynamic>.from(customer['meta']) : <String, dynamic>{};
    final daysLeft = DateTime.tryParse(customer['subscriptionEnd']?.toString() ?? '')?.difference(DateTime.now()).inDays;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CircleAvatar(radius: 21, child: Text((customer['companyName']?.toString().isNotEmpty == true ? customer['companyName'].toString()[0] : 'A').toUpperCase())),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(customer['companyName']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)), Text('${user['username'] ?? '-'} • ${user['fullName'] ?? ''}', style: TextStyle(color: Colors.grey.shade700))])),
              _StatusBadge(text: expired ? 'SÜRE DOLDU' : (active ? 'AKTİF' : 'PASİF'), positive: active && !expired),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _MiniPill(icon: Icons.workspace_premium_outlined, text: '${customer['plan'] ?? 'BASIC'} PAKET'),
              _MiniPill(icon: Icons.event_outlined, text: 'Bitiş ${_formatDate(customer['subscriptionEnd']).split(' ').first}'),
              _MiniPill(icon: Icons.cloud_done_outlined, text: meta['connected'] == true ? 'Meta bağlı' : 'Meta bekliyor'),
              if (daysLeft != null && daysLeft >= 0) _MiniPill(icon: Icons.hourglass_bottom_rounded, text: '$daysLeft gün'),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: onToggle, icon: Icon(active ? Icons.pause_rounded : Icons.play_arrow_rounded), label: Text(active ? 'Pasife al' : 'Aktifleştir'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: onExtend, icon: const Icon(Icons.event_available_rounded), label: const Text('Süre uzat'))),
              IconButton(tooltip: 'Şifre sıfırla', onPressed: onReset, icon: const Icon(Icons.key_rounded)),
            ]),
            Align(alignment: Alignment.centerRight, child: Text('Oluşturulma: ${_relativeDate(customer['createdAt'])}', style: Theme.of(context).textTheme.labelSmall)),
          ]),
        ),
      ),
    );
  }
}

class _LicenseTile extends StatelessWidget {
  final Map<String, dynamic> license;
  final VoidCallback? onAssign;
  const _LicenseTile({required this.license, this.onAssign});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: _GlassCard(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.vpn_key_rounded)),
            title: SelectableText(license['code']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
            subtitle: Text('${license['plan'] ?? '-'} • ${license['days'] ?? '-'} gün • ${license['status'] ?? '-'}'),
            trailing: onAssign == null ? null : TextButton(onPressed: onAssign, child: const Text('ATA')),
          ),
        ),
      );
}

class CustomerDashboard extends StatefulWidget {
  const CustomerDashboard({super.key});
  @override
  State<CustomerDashboard> createState() => _CustomerDashboardState();
}

class _CustomerDashboardState extends State<CustomerDashboard> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await Api.dashboard();
      if (mounted) setState(() => data = d);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _logout() async {
    await Api.logout();
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => const LoginPage()), (_) => false);
  }

  Future<void> _upload() async {
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Align(alignment: Alignment.centerLeft, child: Text('İçerik türünü seç', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        const SizedBox(height: 10),
        ListTile(leading: const Icon(Icons.image_outlined), title: const Text('Fotoğraf / Gönderi'), onTap: () => Navigator.pop(ctx, 'IMAGE')),
        ListTile(leading: const Icon(Icons.video_library_outlined), title: const Text('Video / Reels'), onTap: () => Navigator.pop(ctx, 'VIDEO')),
      ]))),
    );
    if(mode==null || !mounted) return;
    final picker=ImagePicker();
    final image=mode=='VIDEO' ? await picker.pickVideo(source:ImageSource.gallery) : await picker.pickImage(source:ImageSource.gallery, imageQuality:90);
    if(image==null || !mounted) return;
    final title=TextEditingController(); final caption=TextEditingController(); final link=TextEditingController(); final aiContext=TextEditingController();
    bool autoPublish=true, useAI=true;
    final ok=await showDialog<bool>(context:context,builder:(ctx)=>StatefulBuilder(builder:(ctx,setDialog)=>AlertDialog(
      title:Text(mode=='VIDEO'?'Yeni Reel içeriği':'Yeni gönderi içeriği'),
      content:SingleChildScrollView(child:Column(children:[
        Container(height:150,width:double.infinity,alignment:Alignment.center,decoration:BoxDecoration(color:const Color(0xFFF4F5FA),borderRadius:BorderRadius.circular(16)),child:mode=='VIDEO'?Column(mainAxisAlignment:MainAxisAlignment.center,children:[const Icon(Icons.video_file_outlined,size:50),const SizedBox(height:8),Text(image.name,maxLines:2,overflow:TextOverflow.ellipsis,textAlign:TextAlign.center)]):ClipRRect(borderRadius:BorderRadius.circular(16),child:Image(image:FileImage(File(image.path)),height:150,width:double.infinity,fit:BoxFit.cover))),
        const SizedBox(height:12),
        TextField(controller:title,decoration:const InputDecoration(labelText:'Ürün / başlık')),
        const SizedBox(height:10),TextField(controller:aiContext,maxLines:3,decoration:const InputDecoration(labelText:'AI için ürün bilgisi (opsiyonel)')),
        const SizedBox(height:10),TextField(controller:caption,maxLines:5,decoration:const InputDecoration(labelText:'Reklam metni (AI üretmezse manuel)')),
        const SizedBox(height:10),TextField(controller:link,decoration:const InputDecoration(labelText:'Hedef link (opsiyonel)')),
        const SizedBox(height:4),SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('AI ile metni otomatik üret'),subtitle:const Text('Metin boşsa AdVise AI otomatik doldurur'),value:useAI,onChanged:(v)=>setDialog(()=>useAI=v)),
        SwitchListTile(contentPadding:EdgeInsets.zero,title:const Text('Otomatik yayınla'),subtitle:Text(mode=='VIDEO'?'Video otomatik olarak Reels olarak planlanır':'Fotoğraf otomatik olarak gönderi olarak planlanır'),value:autoPublish,onChanged:(v)=>setDialog(()=>autoPublish=v)),
      ])),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('İptal')),FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('YÜKLE'))],
    )));
    if(ok!=true)return;
    try{
      await Api.uploadPost(image.path,title.text,caption.text,link.text,autoPublish:autoPublish,useAI:useAI,mediaType:mode=='VIDEO'?'VIDEO':'IMAGE',aiContext:aiContext.text);
      if(mounted){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(mode=='VIDEO'?'Reel içeriği kaydedildi ve planlama kuyruğuna alındı.':'İçerik kaydedildi ve planlama kuyruğuna alındı.')));await _load();}
    }catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString())));}finally{title.dispose();caption.dispose();link.dispose();aiContext.dispose();}
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? {};
    final tenant = d['tenant'] is Map ? Map<String, dynamic>.from(d['tenant']) : <String, dynamic>{};
    final settings = d['settings'] is Map ? Map<String, dynamic>.from(d['settings']) : <String, dynamic>{};
    final posts = d['posts'] is List ? List<dynamic>.from(d['posts']) : <dynamic>[];
    final logs = d['logs'] is List ? List<dynamic>.from(d['logs']) : <dynamic>[];
    final features = tenant['features'] is Map ? Map<String, dynamic>.from(tenant['features']) : <String, dynamic>{};
    final metaAvailable = d['metaAvailable'] == true;
    final automationEnabled = settings['enabled'] == true;

    return Scaffold(
      appBar: AppBar(leading: Builder(builder: (ctx) => IconButton(tooltip: 'Menü', icon: const Icon(Icons.menu_rounded), onPressed: () => Scaffold.of(ctx).openDrawer())), title: Text(tenant['companyName']?.toString() ?? 'AdVise AI', style: const TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      drawer: _MainDrawer(admin: false, onAccount: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()))),
      floatingActionButton: FloatingActionButton.extended(onPressed: _upload, icon: const Icon(Icons.add_photo_alternate_rounded), label: const Text('İçerik ekle')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 100),
                children: [
                  _DashboardHero(title: 'Reklam Kontrol Merkezi', subtitle: 'İçeriğini yükle, kuralları belirle, karar motorunu çalıştır.', icon: Icons.auto_awesome_rounded, badge: _upper(tenant['plan'] ?? 'BASIC')),
                  const SizedBox(height: 12),
                  _StatusRibbon(metaConnected: metaAvailable, automationEnabled: automationEnabled, subscriptionActive: tenant['active'] != false),
                  const SizedBox(height: 14),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1.45,
                    children: [
                      _MetricCard(data: _MetricData('İçerik', '${posts.length}', Icons.photo_library_outlined, 'Hazır')),
                      _MetricCard(data: _MetricData('İşlem', '${logs.length}', Icons.history_rounded, 'Kayıt')),
                      _MetricCard(data: _MetricData('Hedef', '${settings['messageCostLimit'] ?? 8} TL', Icons.chat_bubble_outline_rounded, 'Mesaj maliyeti')),
                      _MetricCard(data: _MetricData('Haftalık', '${settings['weeklyBudget'] ?? 0} TL', Icons.account_balance_wallet_outlined, 'Bütçe')),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Hızlı işlemler'),
                  _QuickGrid(items: [
                    _QuickAction(title: 'İçerik yükle', icon: Icons.add_photo_alternate_rounded, onTap: _upload),
                    _QuickAction(title: 'Instagram & Reklamlar', icon: Icons.campaign_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SocialAdsPage()))),
                    _QuickAction(title: 'Karar merkezi', icon: Icons.insights_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DecisionHubPage()))),
                    _QuickAction(title: 'Otomasyon', icon: Icons.bolt_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage())).then((_) => _load())),
                    _QuickAction(title: 'Ekip yönetimi', icon: Icons.groups_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersPage()))),
                    _QuickAction(title: 'V7 + V8', icon: Icons.auto_awesome_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const V78HubPage()))),
                    _QuickAction(title: 'Advise Pro', icon: Icons.stars_rounded, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ProHubPage()))),
                  ]),
                  const SizedBox(height: 16),
                  _RuleOverview(settings: settings, features: features, metaAvailable: metaAvailable),
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'İçerik akışı', action: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PostsPage())).then((_) => _load()), child: const Text('Tümünü gör'))),
                  const SizedBox(height: 8),
                  if (posts.isEmpty) _EmptyState(icon: Icons.photo_library_outlined, title: 'Henüz içerik yok', subtitle: 'İlk içeriğini eklediğinde burada durum, zamanlama ve otomasyon adımlarını göreceksin.'),
                  ...posts.take(5).map((p) => _PostTile(post: p)),
                  const SizedBox(height: 16),
                  _SectionHeader(title: 'Son hareketler', action: TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogsPage())), child: const Text('Loglar'))),
                  if (logs.isEmpty) _EmptyState(icon: Icons.receipt_long_outlined, title: 'Henüz işlem yok', subtitle: 'Yaptığın işlemler burada kronolojik olarak görünecek.'),
                  ...logs.take(6).map((l) => _ActivityTile(log: l)),
                  const SizedBox(height: 16),
                  _InfoCard(icon: Icons.lightbulb_outline_rounded, title: 'Advise önerisi', body: 'İlk haftalarda tek bir reklam sonucuna göre agresif bütçe değişimi yapma. Yeterli veri oluştuğunda sistem performans sinyallerini daha güçlü kullanır.'),
                  const SizedBox(height: 18),
                  const _PoweredBy(),
                ],
              ),
            ),
    );
  }
}

class _RuleOverview extends StatelessWidget {
  final Map<String, dynamic> settings, features;
  final bool metaAvailable;
  const _RuleOverview({required this.settings, required this.features, required this.metaAvailable});
  @override
  Widget build(BuildContext context) => _GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [const Icon(Icons.rule_folder_outlined), const SizedBox(width: 8), const Text('12 saatlik karar motoru', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), const Spacer(), _StatusBadge(text: settings['enabled'] == true ? 'AKTİF' : 'PASİF', positive: settings['enabled'] == true)]),
            const SizedBox(height: 12),
            _RuleLine(icon: Icons.timer_outlined, title: 'Erken pencere', value: '${settings['earlyWindowHours'] ?? 12} saat'),
            _RuleLine(icon: Icons.currency_lira_rounded, title: 'Mesaj hedefi', value: '${settings['earlyMessageCostLimit'] ?? settings['messageCostLimit'] ?? 8} TL'),
            _RuleLine(icon: Icons.pause_circle_outline, title: 'Kötü reklam', value: settings['autoPause'] == true ? 'Otomatik durdur' : 'Manuel karar'),
            _RuleLine(icon: Icons.swap_horiz_rounded, title: 'Bütçe', value: features['budgetReallocation'] == true ? 'Yeniden dağıtım açık' : 'Paketinizde kapalı'),
            _RuleLine(icon: Icons.schedule_rounded, title: 'Meta bağlantısı', value: metaAvailable ? 'Bağlı / veri alınabilir' : 'Planlama modu'),
          ]),
        ),
      );
}

class _RuleLine extends StatelessWidget {
  final IconData icon;
  final String title, value;
  const _RuleLine({required this.icon, required this.title, required this.value});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [Icon(icon, size: 19, color: Colors.grey.shade700), const SizedBox(width: 9), Expanded(child: Text(title)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]));
}

class DecisionCenterPage extends StatefulWidget {
  final bool admin;
  const DecisionCenterPage({super.key, this.admin = false});
  @override
  State<DecisionCenterPage> createState() => _DecisionCenterPageState();
}

class _DecisionCenterPageState extends State<DecisionCenterPage> {
  List<dynamic> ads = [], adsets = [], campaigns = [];
  bool loading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    if (!widget.admin) {
      if (mounted) setState(() { loading = false; error = 'Müşteri tarafında gerçek Meta kararları, müşteri bazlı Meta OAuth bağlantısı açıldığında etkinleşir.'; });
      return;
    }
    try {
      final r = await Future.wait([Api.campaigns(), Api.adsets(), Api.ads()]);
      if (!mounted) return;
      setState(() { campaigns = r[0]; adsets = r[1]; ads = r[2]; loading = false; });
    } catch (e) {
      if (mounted) setState(() { loading = false; error = e.toString(); });
    }
  }

  Future<void> _toggle(dynamic ad) async {
    final current = _upper(ad['status'] ?? ad['effective_status']);
    final next = current == 'PAUSED' ? 'ACTIVE' : 'PAUSED';
    try {
      await Api.status(ad['id'].toString(), next);
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _budget(dynamic ad) async {
    final adSetId = ad['adset_id']?.toString();
    if (adSetId == null || adSetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bu reklamın ad set bilgisi bulunamadı.')));
      return;
    }
    Map<String, dynamic>? adSet;
    for (final x in adsets) {
      if (x is Map && x['id']?.toString() == adSetId) {
        adSet = Map<String, dynamic>.from(x);
        break;
      }
    }
    final current = double.tryParse(adSet?['daily_budget']?.toString() ?? '') ?? 100;
    final controller = TextEditingController(text: current.round().toString());
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Günlük bütçeyi değiştir'),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'TL / gün')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('İptal')), FilledButton(onPressed: () => Navigator.pop(ctx, double.tryParse(controller.text)), child: const Text('UYGULA'))],
      ),
    );
    controller.dispose();
    if (value == null) return;
    try {
      await Api.updateAdSetBudget(adSetId, value);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Günlük bütçe güncellendi.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _insight(dynamic ad) async {
    try {
      final x = await Api.insights(ad['id'].toString());
      if (!mounted) return;
      final data = x['data'] is List && (x['data'] as List).isNotEmpty ? Map<String, dynamic>.from((x['data'] as List).first) : <String, dynamic>{};
      final spend = double.tryParse(data['spend']?.toString() ?? '') ?? 0;
      final clicks = double.tryParse(data['clicks']?.toString() ?? '') ?? 0;
      final impressions = double.tryParse(data['impressions']?.toString() ?? '') ?? 0;
      final messages = _messageCount(data['actions']);
      final cpm = impressions > 0 ? spend / impressions * 1000 : 0;
      final cost = messages > 0 ? spend / messages : null;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: Text(ad['name']?.toString() ?? 'Reklam'), content: Column(mainAxisSize: MainAxisSize.min, children: [ListTile(leading: const Icon(Icons.payments_outlined), title: const Text('Harcama'), trailing: Text('${spend.toStringAsFixed(2)} TL')), ListTile(leading: const Icon(Icons.chat_bubble_outline), title: const Text('Mesaj'), trailing: Text('$messages')), ListTile(leading: const Icon(Icons.sell_outlined), title: const Text('Mesaj maliyeti'), trailing: Text(cost == null ? '-' : '${cost.toStringAsFixed(2)} TL')), ListTile(leading: const Icon(Icons.ads_click_outlined), title: const Text('Tıklama'), trailing: Text('${clicks.toStringAsFixed(0)}')), ListTile(leading: const Icon(Icons.speed_outlined), title: const Text('CPM'), trailing: Text('${cpm.toStringAsFixed(2)} TL'))]), actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT'))]));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(leading: _mainHomeLeading(context), title: const Text('Reklam Karar Merkezi', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]),
      drawer: _MainDrawer(admin: widget.admin),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(14),
              children: [
                _DashboardHero(title: 'Durdur • Devam • Bütçeyi aktar', subtitle: 'Gerçek Meta verisi geldiğinde kararları tek ekrandan uygula.', icon: Icons.swap_calls_rounded, badge: 'KARAR MOTORU'),
                const SizedBox(height: 12),
                _DecisionExplainer(),
                const SizedBox(height: 12),
                _DecisionStats(campaigns: campaigns.length, adsets: adsets.length, ads: ads.length),
                const SizedBox(height: 16),
                if (error != null) _EmptyState(icon: Icons.cloud_off_rounded, title: 'Meta verisi alınamadı', subtitle: 'Bağlantı yoksa bu ekran planlama modunda kalır.\n$error'),
                if (error == null && ads.isEmpty) _EmptyState(icon: Icons.campaign_outlined, title: 'Henüz reklam verisi yok', subtitle: 'Meta bağlantısı hazır olduğunda kampanya, reklam ve bütçe kayıtları burada görünür.'),
                ...ads.take(100).map((ad) => _AdDecisionCard(ad: ad, onToggle: () => _toggle(ad), onBudget: () => _budget(ad), onInsight: () => _insight(ad))),
                const SizedBox(height: 16),
                const _PoweredBy(),
              ],
            ),
    );
  }

  int _messageCount(dynamic actions) {
    if (actions is! List) return 0;
    var total = 0.0;
    for (final item in actions) {
      if (item is! Map) continue;
      final type = item['action_type']?.toString().toLowerCase() ?? '';
      if (type.contains('messaging') || type.contains('conversation')) total += double.tryParse(item['value']?.toString() ?? '') ?? 0;
    }
    return total.round();
  }
}

class _DecisionStats extends StatelessWidget {
  final int campaigns, adsets, ads;
  const _DecisionStats({required this.campaigns, required this.adsets, required this.ads});
  @override
  Widget build(BuildContext context) => GridView.count(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), childAspectRatio: 1.25, children: [
    _MetricCard(data: _MetricData('Kampanya', '$campaigns', Icons.folder_copy_outlined, 'Meta')),
    _MetricCard(data: _MetricData('Ad set', '$adsets', Icons.layers_outlined, 'Meta')),
    _MetricCard(data: _MetricData('Reklam', '$ads', Icons.campaign_outlined, 'Meta')),
  ]);
}

class _DecisionExplainer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => _GlassCard(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text('Önerilen akış', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)), const SizedBox(height: 12), _StepRow(index: '01', title: '12 saatlik pencere', body: 'Yeterli veri oluşana kadar agresif karar verme.'), _StepRow(index: '02', title: 'Mesaj maliyetini ölç', body: 'Hedefin üstünde kalan reklam durdurma adayı olur.'), _StepRow(index: '03', title: 'Bütçe kapasitesini yönlendir', body: 'Serbest gelecek kapasite daha iyi performanslı ad sete aktarılabilir.'), const SizedBox(height: 6), const _PoweredBy(compact: true)])));
}

class _StepRow extends StatelessWidget {
  final String index, title, body;
  const _StepRow({required this.index, required this.title, required this.body});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(width: 34, height: 34, alignment: Alignment.center, decoration: BoxDecoration(color: Theme.of(context).colorScheme.primaryContainer, shape: BoxShape.circle), child: Text(index, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontWeight: FontWeight.w800)), const SizedBox(height: 3), Text(body, style: TextStyle(color: Colors.grey.shade700))]))]));
}

class _AdDecisionCard extends StatelessWidget {
  final Map<String, dynamic> ad;
  final VoidCallback onToggle, onBudget, onInsight;
  const _AdDecisionCard({required this.ad, required this.onToggle, required this.onBudget, required this.onInsight});
  @override
  Widget build(BuildContext context) {
    final status = _upper(ad['status'] ?? ad['effective_status']);
    return Padding(padding: const EdgeInsets.only(bottom: 10), child: _GlassCard(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [const CircleAvatar(child: Icon(Icons.campaign_rounded)), const SizedBox(width: 10), Expanded(child: Text(ad['name']?.toString() ?? 'Ads', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))), _StatusBadge(text: status.isEmpty ? 'UNKNOWN' : status, positive: status == 'ACTIVE')]), const SizedBox(height: 10), Text('Ad ID: ${ad['id'] ?? '-'}', style: Theme.of(context).textTheme.labelSmall), const SizedBox(height: 8), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: onInsight, icon: const Icon(Icons.analytics_outlined), label: const Text('İncele'))), const SizedBox(width: 7), Expanded(child: OutlinedButton.icon(onPressed: onBudget, icon: const Icon(Icons.account_balance_wallet_outlined), label: const Text('Bütçe'))), const SizedBox(width: 7), FilledButton.icon(onPressed: onToggle, icon: Icon(status == 'PAUSED' ? Icons.play_arrow_rounded : Icons.pause_rounded), label: Text(status == 'PAUSED' ? 'AÇ' : 'DUR'))])]))));
  }
}

class PostsPage extends StatefulWidget {
  const PostsPage({super.key});
  @override
  State<PostsPage> createState() => _PostsPageState();
}

class _PostsPageState extends State<PostsPage> {
  List<dynamic> posts = [];
  bool loading = true;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try { final x = await Api.posts(); if (mounted) setState(() => posts = x); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
    finally { if (mounted) setState(() => loading = false); }
  }

  Future<void> _delete(dynamic post) async {
    final ok = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(title: const Text('İçeriği sil?'), content: Text('${post['title'] ?? 'Bu içerik'} kalıcı olarak kaldırılacak.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')), FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('SİL'))]));
    if (ok != true) return;
    try { await Api.deletePost(post['id'].toString()); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  Future<void> _publish(dynamic post) async {
    try { await Api.publishPost(post['id'].toString()); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yayınlama isteği gönderildi.'))); await _load(); } }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: _mainHomeLeading(context), title: const Text('İçerikler', style: TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]), drawer: const _MainDrawer(admin: false), body: loading ? const Center(child: CircularProgressIndicator()) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(14), children: [if (posts.isEmpty) _EmptyState(icon: Icons.photo_library_outlined, title: 'İçerik yok', subtitle: 'Dashboard üzerinden ilk görselini ekleyebilirsin.'), ...posts.map((p) => _PostCard(post: p, onDelete: () => _delete(p), onPublish: () => _publish(p))), const SizedBox(height: 18), const _PoweredBy()])));
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final VoidCallback onDelete, onPublish;
  const _PostCard({required this.post, required this.onDelete, required this.onPublish});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: _GlassCard(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Container(height: 150, width: double.infinity, decoration: BoxDecoration(color: const Color(0xFFF0F1F6), borderRadius: BorderRadius.circular(16)), child: const Icon(Icons.image_outlined, size: 58)), const SizedBox(height: 12), Row(children: [Expanded(child: Text(post['title']?.toString() ?? '-', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))), _StatusBadge(text: _upper(post['publishStatus'] ?? 'READY'), positive: _upper(post['publishStatus']) == 'PUBLISHED')]), const SizedBox(height: 4), Text(post['caption']?.toString() ?? '', maxLines: 3, overflow: TextOverflow.ellipsis), const SizedBox(height: 10), Row(children: [Expanded(child: OutlinedButton.icon(onPressed: onPublish, icon: const Icon(Icons.publish_rounded), label: const Text('Yayınla'))), IconButton(tooltip: 'Sil', onPressed: onDelete, icon: const Icon(Icons.delete_outline_rounded))]), const Align(alignment: Alignment.centerRight, child: _PoweredBy(compact: true))]))));
}

class _PostTile extends StatelessWidget {
  final dynamic post;
  const _PostTile({required this.post});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 8), child: _GlassCard(child: ListTile(leading: const CircleAvatar(child: Icon(Icons.image_outlined)), title: Text(post['title']?.toString() ?? '-'), subtitle: Text('${post['publishStatus'] ?? 'READY'} • ${_relativeDate(post['createdAt'])}'), trailing: const Icon(Icons.chevron_right_rounded))));
}

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});
  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  List<dynamic> users = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final x = await Api.users();
      if (mounted) setState(() => users = x);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _create() async {
    final name = TextEditingController();
    final user = TextEditingController();
    final pass = TextEditingController(text: 'Advise123!');
    String role = 'OPERATOR';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ekip üyesi oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad soyad')),
            const SizedBox(height: 10),
            TextField(controller: user, decoration: const InputDecoration(labelText: 'Kullanıcı adı')),
            const SizedBox(height: 10),
            TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'İlk şifre')),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              initialValue: role,
              decoration: const InputDecoration(labelText: 'Rol'),
              items: const [
                DropdownMenuItem(value: 'MANAGER', child: Text('Yönetici')),
                DropdownMenuItem(value: 'OPERATOR', child: Text('Operatör')),
                DropdownMenuItem(value: 'VIEWER', child: Text('Sadece görüntüleme')),
              ],
              onChanged: (v) => setState(() => role = v ?? 'OPERATOR'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              try {
                await Api.createUser(username: user.text, password: pass.text, fullName: name.text, role: role);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('OLUŞTUR'),
          ),
        ],
      ),
    );
    name.dispose();
    user.dispose();
    pass.dispose();
    if (ok == true) await _load();
  }

  Future<void> _toggle(dynamic u) async {
    try {
      await Api.toggleUser(u['id'].toString());
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _reset(dynamic u) async {
    final p = TextEditingController(text: 'Advise123!');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kullanıcı şifresi'),
        content: TextField(controller: p, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni şifre')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              try {
                await Api.resetUserPassword(u['id'].toString(), p.text);
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString())));
              }
            },
            child: const Text('KAYDET'),
          ),
        ],
      ),
    );
    p.dispose();
    if (ok == true && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifre güncellendi.')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _mainHomeLeading(context),
        title: const Text('Ekip ve kullanıcılar', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))],
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.person_add_alt_1_rounded), label: const Text('Kullanıcı')),
      drawer: const _MainDrawer(admin: false),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 90),
              children: [
                const _InfoCard(
                  icon: Icons.groups_rounded,
                  title: 'Ekip erişimi',
                  body: 'Paketinizin kullanıcı limitine göre operatör hesabı açabilir, pasife alabilir ve şifre sıfırlayabilirsin.',
                ),
                const SizedBox(height: 12),
                ...users.map(
                  (u) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _GlassCard(
                      child: ListTile(
                        leading: CircleAvatar(child: Text((u['fullName']?.toString().isNotEmpty == true ? u['fullName'].toString()[0] : 'U').toUpperCase())),
                        title: Text(u['fullName']?.toString().isNotEmpty == true ? u['fullName'] : u['username']?.toString() ?? '-'),
                        subtitle: Text('${u['username'] ?? '-'} • ${u['role'] ?? '-'}'),
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) => v == 'toggle' ? _toggle(u) : _reset(u),
                          itemBuilder: (_) => [
                            PopupMenuItem(value: 'toggle', child: Text(u['active'] == true ? 'Pasife al' : 'Aktifleştir')),
                            const PopupMenuItem(value: 'reset', child: Text('Şifre sıfırla')),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const _PoweredBy(),
              ],
            ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  final bool admin;
  const SettingsPage({super.key, this.admin = false});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final weekly = TextEditingController();
  final limit = TextEditingController();
  final minSpend = TextEditingController();
  final earlyWindow = TextEditingController();
  final earlyMinSpend = TextEditingController();
  final earlyLimit = TextEditingController();
  final noMessageSpend = TextEditingController();
  final reducePercent = TextEditingController();
  final weeklyDay = TextEditingController();
  final startHour = TextEditingController();
  final startMinute = TextEditingController();
  final duration = TextEditingController();
  final minDaily = TextEditingController();
  final maxDaily = TextEditingController();
  bool enabled = false, autoPause = true, autoReallocate = true, autoBestTime = true, autoPublish = true, aiEnabled = true, autoMediaType = true, preventDuplicate = true;

  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try {
      final s = await Api.settings();
      if (!mounted) return;
      setState(() {
        weekly.text = '${s['weeklyBudget'] ?? 1000}';
        limit.text = '${s['messageCostLimit'] ?? 8}';
        minSpend.text = '${s['minSpendBeforeDecision'] ?? 50}';
        earlyWindow.text = '${s['earlyWindowHours'] ?? 12}';
        earlyMinSpend.text = '${s['earlyMinSpendBeforeDecision'] ?? 50}';
        earlyLimit.text = '${s['earlyMessageCostLimit'] ?? 8}';
        noMessageSpend.text = '${s['earlyNoMessageSpendThreshold'] ?? 75}';
        reducePercent.text = '${s['earlyBudgetReductionPercent'] ?? 30}';
        weeklyDay.text = '${s['weeklyDay'] ?? 1}';
        startHour.text = '${s['startHour'] ?? 19}';
        startMinute.text = '${s['startMinute'] ?? 0}';
        duration.text = '${s['durationHours'] ?? 24}';
        minDaily.text = '${s['minDailyBudget'] ?? 50}';
        maxDaily.text = '${s['maxDailyBudget'] ?? 500}';
        enabled = s['enabled'] == true;
        autoPause = s['autoPause'] != false;
        autoReallocate = s['autoReallocate'] != false;
        autoBestTime = s['autoBestTime'] != false;
        autoPublish = s['autoPublish'] != false;
        aiEnabled = s['aiEnabled'] != false;
        autoMediaType = s['autoMediaType'] != false;
        preventDuplicate = s['preventDuplicateContent'] != false;
      });
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  @override
  void dispose() { for (final c in [weekly, limit, minSpend, earlyWindow, earlyMinSpend, earlyLimit, noMessageSpend, reducePercent, weeklyDay, startHour, startMinute, duration, minDaily, maxDaily]) { c.dispose(); } super.dispose(); }
  Future<void> _save() async {
    try {
      await Api.saveSettings({
        'weeklyBudget': double.tryParse(weekly.text) ?? 1000,
        'messageCostLimit': double.tryParse(limit.text) ?? 8,
        'minSpendBeforeDecision': double.tryParse(minSpend.text) ?? 50,
        'earlyWindowHours': int.tryParse(earlyWindow.text) ?? 12,
        'earlyMinSpendBeforeDecision': double.tryParse(earlyMinSpend.text) ?? 50,
        'earlyMessageCostLimit': double.tryParse(earlyLimit.text) ?? 8,
        'earlyNoMessageSpendThreshold': double.tryParse(noMessageSpend.text) ?? 75,
        'earlyBudgetReductionPercent': double.tryParse(reducePercent.text) ?? 30,
        'weeklyDay': int.tryParse(weeklyDay.text) ?? 1,
        'startHour': int.tryParse(startHour.text) ?? 19,
        'startMinute': int.tryParse(startMinute.text) ?? 0,
        'durationHours': int.tryParse(duration.text) ?? 24,
        'minDailyBudget': double.tryParse(minDaily.text) ?? 50,
        'maxDailyBudget': double.tryParse(maxDaily.text) ?? 500,
        'enabled': enabled,
        'autoPause': autoPause,
        'autoReallocate': autoReallocate,
        'autoBestTime': autoBestTime,
        'autoPublish': autoPublish,
        'aiEnabled': aiEnabled,
        'autoMediaType': autoMediaType,
        'preventDuplicateContent': preventDuplicate,
      });
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ayarlar kaydedildi.'))); Navigator.pop(context); }
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); }
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: _mainHomeLeading(context), title: Text(widget.admin ? 'Sistem Ayarları' : 'Otomasyon Ayarları', style: const TextStyle(fontWeight: FontWeight.w800)), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh_rounded))]), drawer: _MainDrawer(admin: widget.admin), body: ListView(padding: const EdgeInsets.fromLTRB(14, 10, 14, 40), children: [if (widget.admin) const _InfoCard(icon: Icons.settings_suggest_rounded, title: 'Sistem varsayılanları', body: 'Bu alan sistem yöneticisi için global davranış varsayılanlarını düzenler.'), const SizedBox(height: 12), _SettingsSection(title: 'Otomasyon', icon: Icons.bolt_rounded, children: [SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Otomasyonu aktif et'), value: enabled, onChanged: (v) => setState(() => enabled = v)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Hedefi aşan reklamı durdur'), value: autoPause, onChanged: (v) => setState(() => autoPause = v)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Serbest bütçeyi yeniden dağıt'), value: autoReallocate, onChanged: (v) => setState(() => autoReallocate = v)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('En iyi saati otomatik öğren'), value: autoBestTime, onChanged: (v) => setState(() => autoBestTime = v)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('İçeriği otomatik planla'), value: autoPublish, onChanged: (v) => setState(() => autoPublish = v)) ]), const SizedBox(height: 12), _SettingsSection(title: 'AdVise AI ve akıllı yayın', icon: Icons.auto_awesome_rounded, children: [SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('AI modu'), subtitle: const Text('Caption, hook ve CTA üretimini aç'), value: aiEnabled, onChanged: (v) => setState(() => aiEnabled = v)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Post / Reels formatını otomatik seç'), value: autoMediaType, onChanged: (v) => setState(() => autoMediaType = v)), SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Tekrarlanan içeriği engelle'), value: preventDuplicate, onChanged: (v) => setState(() => preventDuplicate = v))]), const SizedBox(height: 12), _SettingsSection(title: 'Bütçe ve hedef', icon: Icons.account_balance_wallet_outlined, children: [_Field(controller: weekly, label: 'Haftalık toplam bütçe (TL)'), _Field(controller: limit, label: 'Genel mesaj maliyeti sınırı (TL)'), _Field(controller: minSpend, label: 'Karar için minimum harcama (TL)'), _Field(controller: minDaily, label: 'Minimum günlük bütçe (TL)'), _Field(controller: maxDaily, label: 'Maksimum günlük bütçe (TL)')]), const SizedBox(height: 12), _SettingsSection(title: '12 saatlik erken karar', icon: Icons.timer_outlined, children: [_Field(controller: earlyWindow, label: 'Kontrol penceresi (saat)'), _Field(controller: earlyMinSpend, label: 'Karar minimum harcaması (TL)'), _Field(controller: earlyLimit, label: 'Erken mesaj maliyeti hedefi (TL)'), _Field(controller: noMessageSpend, label: 'Mesajsız harcama eşiği (TL)'), _Field(controller: reducePercent, label: 'Kötü reklam bütçe azaltma yüzdesi (%)')]), const SizedBox(height: 12), _SettingsSection(title: 'Yayın planı', icon: Icons.schedule_rounded, children: [_Field(controller: weeklyDay, label: 'Haftanın günü (1=Pzt, 7=Paz)'), _Field(controller: startHour, label: 'Başlangıç saati (0-23)'), _Field(controller: startMinute, label: 'Başlangıç dakikası (0-59)'), _Field(controller: duration, label: 'Reklam süresi (saat)')]), const SizedBox(height: 18), SizedBox(height: 54, child: FilledButton.icon(onPressed: _save, icon: const Icon(Icons.save_rounded), label: const Text('AYARLARI KAYDET'))), const SizedBox(height: 16), const _PoweredBy() ]));
}

class _SettingsSection extends StatelessWidget { final String title; final IconData icon; final List<Widget> children; const _SettingsSection({required this.title, required this.icon, required this.children}); @override Widget build(BuildContext context) => _GlassCard(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children: [Icon(icon), const SizedBox(width: 8), Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))]), const SizedBox(height: 10), ...children]))); }
class _Field extends StatelessWidget { final TextEditingController controller; final String label; const _Field({required this.controller, required this.label}); @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: TextField(controller: controller, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: InputDecoration(labelText: label))); }

class AccountPage extends StatefulWidget {
  const AccountPage({super.key});
  @override
  State<AccountPage> createState() => _AccountPageState();
}
class _AccountPageState extends State<AccountPage> {
  final current = TextEditingController(); final next = TextEditingController(); final again = TextEditingController(); bool saving = false;
  @override void dispose() { current.dispose(); next.dispose(); again.dispose(); super.dispose(); }
  Future<void> _save() async { if (next.text != again.text) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Yeni şifreler aynı değil.'))); return; } setState(() => saving = true); try { await Api.changePassword(current.text, next.text); if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Şifren güncellendi.'))); Navigator.pop(context); } } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()))); } finally { if (mounted) setState(() => saving = false); } }
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: _mainHomeLeading(context), title: const Text('Hesabım', style: TextStyle(fontWeight: FontWeight.w800))), body: ListView(padding: const EdgeInsets.all(14), children: [const _InfoCard(icon: Icons.verified_user_outlined, title: 'Hesap güvenliği', body: 'Şifreni düzenli aralıklarla yenile. Paylaşılan cihazlarda oturumunu açık bırakma.'), const SizedBox(height: 12), _GlassCard(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [TextField(controller: current, obscureText: true, decoration: const InputDecoration(labelText: 'Mevcut şifre')), const SizedBox(height: 10), TextField(controller: next, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni şifre')), const SizedBox(height: 10), TextField(controller: again, obscureText: true, decoration: const InputDecoration(labelText: 'Yeni şifre (tekrar)')), const SizedBox(height: 14), SizedBox(width: double.infinity, height: 52, child: FilledButton.icon(onPressed: saving ? null : _save, icon: const Icon(Icons.lock_reset_rounded), label: const Text('ŞİFREYİ GÜNCELLE')))]))), const SizedBox(height: 18), const _PoweredBy()]));
}

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});
  @override
  State<LogsPage> createState() => _LogsPageState();
}
class _LogsPageState extends State<LogsPage> { List<dynamic> logs=[]; bool loading=true; @override void initState(){super.initState();_load();} Future<void> _load() async { try { final x=await Api.logs(); if(mounted)setState(()=>logs=x); } catch(e){ if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(e.toString()))); } finally{ if(mounted)setState(()=>loading=false);} } @override Widget build(BuildContext context)=>Scaffold(appBar: AppBar(leading: _mainHomeLeading(context), title:const Text('İşlem Geçmişi',style:TextStyle(fontWeight:FontWeight.w800)),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded))]),drawer:const _MainDrawer(admin:false),body:loading?const Center(child:CircularProgressIndicator()):RefreshIndicator(onRefresh:_load,child:ListView(padding:const EdgeInsets.all(14),children:[if(logs.isEmpty)_EmptyState(icon:Icons.receipt_long_outlined,title:'Henüz log yok',subtitle:'Sistemde yaptığın tüm işlemler burada görünür.'),...logs.map((l)=>_ActivityTile(log:l)),const SizedBox(height:18),const _PoweredBy()]))); }

class _ActivityTile extends StatelessWidget { final dynamic log; const _ActivityTile({required this.log}); @override Widget build(BuildContext context){ final type=_upper(log['type']??'İŞLEM'); return Padding(padding:const EdgeInsets.only(bottom:7),child:_GlassCard(child:ListTile(leading:CircleAvatar(child:Icon(type.contains('ERROR')?Icons.error_outline:Icons.check_rounded)),title:Text(type.replaceAll('_',' '),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(_formatDate(log['at'])),trailing:const Icon(Icons.chevron_right_rounded)))); } }

class _MainDrawer extends StatelessWidget {
  final bool admin;
  final VoidCallback? onAccount;
  const _MainDrawer({required this.admin, this.onAccount});

  void _go(BuildContext context, Widget page) {
    Navigator.pop(context);
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 14),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                    child: ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.asset('assets/advise_logo.jpg', fit: BoxFit.contain)),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('ADVISE DIGITAL', style: TextStyle(fontWeight: FontWeight.w900)),
                      Text('Yönetim ve otomasyon', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
            ),
            const Divider(),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6), child: Text(admin ? 'SİSTEM' : 'ÇALIŞMA ALANI', style: Theme.of(context).textTheme.labelSmall)),
            if (admin) ...[
              ListTile(leading: const Icon(Icons.dashboard_outlined), title: const Text('Sistem özeti'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.people_outline), title: const Text('Müşteriler'), onTap: () => _go(context, const AdminCustomersPage())),
              ListTile(leading: const Icon(Icons.vpn_key_outlined), title: const Text('Lisanslar'), onTap: () => _go(context, const AdminLicensesPage())),
              ListTile(leading: const Icon(Icons.auto_graph_outlined), title: const Text('Reklam karar merkezi'), onTap: () => _go(context, const DecisionHubPage(admin: true))),
              ListTile(leading: const Icon(Icons.campaign_outlined), title: const Text('Instagram & Reklamlar'), onTap: () => _go(context, const SocialAdsPage())),
              ListTile(leading: const Icon(Icons.tune_outlined), title: const Text('Sistem ayarları'), onTap: () => _go(context, const SettingsPage(admin: true))),
              ListTile(leading: const Icon(Icons.link_outlined), title: const Text('Meta & Instagram bağlantısı'), onTap: () => _go(context, const MetaConnectionPage())),
              ListTile(leading: const Icon(Icons.auto_awesome_outlined), title: const Text('V7 + V8 kontrol merkezi'), onTap: () => _go(context, const V78HubPage(admin: true))),
              ListTile(leading: const Icon(Icons.stars_rounded), title: const Text('Advise Pro Merkezi'), onTap: () => _go(context, const ProHubPage(admin: true))),
              ListTile(leading: const Icon(Icons.link_outlined), title: const Text('Bağlantı ayarları'), onTap: () => _go(context, const KeyPage())),
            ] else ...[
              ListTile(leading: const Icon(Icons.dashboard_outlined), title: const Text('Ana panel'), onTap: () => Navigator.pop(context)),
              ListTile(leading: const Icon(Icons.photo_library_outlined), title: const Text('İçerikler'), onTap: () => _go(context, const PostsPage())),
              ListTile(leading: const Icon(Icons.campaign_outlined), title: const Text('Instagram & Reklamlar'), onTap: () => _go(context, const SocialAdsPage())),
              ListTile(leading: const Icon(Icons.auto_graph_outlined), title: const Text('Karar merkezi'), onTap: () => _go(context, const DecisionHubPage())),
              ListTile(leading: const Icon(Icons.groups_outlined), title: const Text('Ekip ve kullanıcılar'), onTap: () => _go(context, const UsersPage())),
              ListTile(leading: const Icon(Icons.tune_outlined), title: const Text('Otomasyon ayarları'), onTap: () => _go(context, const SettingsPage())),
              ListTile(leading: const Icon(Icons.history_outlined), title: const Text('İşlem geçmişi'), onTap: () => _go(context, const LogsPage())),
              ListTile(leading: const Icon(Icons.link_outlined), title: const Text('Bağlantı ayarları'), onTap: () => _go(context, const KeyPage())),
              ListTile(leading: const Icon(Icons.link_outlined), title: const Text('Meta & Instagram bağlantısı'), onTap: () => _go(context, const MetaConnectionPage())),
              ListTile(leading: const Icon(Icons.auto_awesome_outlined), title: const Text('V7 + V8 kontrol merkezi'), onTap: () => _go(context, const V78HubPage())),
              ListTile(leading: const Icon(Icons.stars_rounded), title: const Text('Advise Pro Merkezi'), onTap: () => _go(context, const ProHubPage())),
            ],
            const Divider(),
            if (onAccount != null) ListTile(leading: const Icon(Icons.account_circle_outlined), title: const Text('Hesabım'), onTap: onAccount),
            ListTile(leading: const Icon(Icons.help_outline_rounded), title: const Text('Yardım & kullanım'), onTap: () => _go(context, const HelpPage())),
            const SizedBox(height: 10),
            const Center(child: _PoweredBy(compact: true)),
            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(leading: _mainHomeLeading(context), title: const Text('Yardım & kullanım', style: TextStyle(fontWeight: FontWeight.w800))), body: ListView(padding: const EdgeInsets.all(14), children: [const _DashboardHero(title: 'AdVise AI nasıl çalışır?', subtitle: 'İçerik → planlama → performans → karar → bütçe yönlendirme.', icon: Icons.menu_book_rounded, badge: 'REHBER'), const SizedBox(height: 14), _HelpSection(title: '1. İçerik ekle', icon: Icons.add_photo_alternate_rounded, body: 'Dashboard üzerinden ürün görseli, reklam metni ve hedef bağlantıyı ekle. Otomatik planlama açıksa sistem içeriği yayın kuyruğuna alır.'), _HelpSection(title: '2. Kuralları belirle', icon: Icons.tune_rounded, body: 'Haftalık bütçe, mesaj maliyeti hedefi, minimum harcama ve 12 saatlik erken karar penceresini ayarlayabilirsin.'), _HelpSection(title: '3. Karar merkezini kullan', icon: Icons.auto_graph_rounded, body: 'Meta verisi hazır olduğunda reklamları inceleyebilir, durdurabilir/devam ettirebilir ve ad set günlük bütçesini değiştirebilirsin.'), _HelpSection(title: '4. Ekip yönetimi', icon: Icons.groups_rounded, body: 'Paket limitin elverdiği sürece operatör kullanıcıları açabilir, pasife alabilir ve şifre sıfırlayabilirsin.'), _HelpSection(title: '5. Lisans / kiralama', icon: Icons.vpn_key_rounded, body: 'Sistem yöneticisi müşteri hesabı oluşturur, paketi belirler, süre uzatır, lisans üretir ve hesabı gerektiğinde pasife alabilir.'), const SizedBox(height: 10), _InfoCard(icon: Icons.lock_outline_rounded, title: 'Güvenlik notu', body: 'Meta erişim belirteçleri APK içine gömülmemelidir. Üretimde HTTPS ve güvenli secret saklama kullanılmalıdır.'), const SizedBox(height: 18), const _PoweredBy()]));
}
class _HelpSection extends StatelessWidget { final String title, body; final IconData icon; const _HelpSection({required this.title,required this.body,required this.icon}); @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:10),child:_GlassCard(child:Padding(padding:const EdgeInsets.all(15),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(child:Icon(icon)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:5),Text(body,style:TextStyle(color:Colors.grey.shade700,height:1.45))]))])))); }

class _DashboardHero extends StatelessWidget {
  final String title, subtitle, badge;
  final IconData icon;
  const _DashboardHero({required this.title, required this.subtitle, required this.icon, required this.badge});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(borderRadius: BorderRadius.circular(24), gradient: const LinearGradient(begin: Alignment.topLeft,end:Alignment.bottomRight,colors:[Color(0xFF252A5A),Color(0xFF4F46E5)]), boxShadow: const [BoxShadow(color:Color(0x22000000),blurRadius:24,offset:Offset(0,12))]), child: Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(width:46,height:46,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.12),borderRadius:BorderRadius.circular(14)),child:Icon(icon,color:Colors.white)),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:5),decoration:BoxDecoration(color:Colors.white.withValues(alpha:.12),borderRadius:BorderRadius.circular(30)),child:Text(badge,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w800,fontSize:11))),const SizedBox(height:8),Text(title,style:const TextStyle(color:Colors.white,fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text(subtitle,style:TextStyle(color:Colors.white.withValues(alpha:.82),height:1.35)),const SizedBox(height:10),const _PoweredBy(inverse:true,compact:true)]))]));
}

class _StatusRibbon extends StatelessWidget { final bool metaConnected, automationEnabled, subscriptionActive; const _StatusRibbon({required this.metaConnected,required this.automationEnabled,required this.subscriptionActive}); @override Widget build(BuildContext context)=>_GlassCard(child:Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),child:Wrap(spacing:16,runSpacing:8,children:[_RibbonItem(icon:subscriptionActive?Icons.verified_rounded:Icons.block_rounded,text:subscriptionActive?'Abonelik aktif':'Abonelik pasif'),_RibbonItem(icon:automationEnabled?Icons.bolt_rounded:Icons.bolt_outlined,text:automationEnabled?'Otomasyon açık':'Otomasyon kapalı'),_RibbonItem(icon:metaConnected?Icons.cloud_done_rounded:Icons.cloud_off_rounded,text:metaConnected?'Meta bağlı':'Planlama modu')]))); }
class _RibbonItem extends StatelessWidget { final IconData icon; final String text; const _RibbonItem({required this.icon,required this.text}); @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:18),const SizedBox(width:6),Text(text,style:const TextStyle(fontWeight:FontWeight.w700))]); }

class _QuickAction { final String title; final IconData icon; final VoidCallback onTap; const _QuickAction({required this.title,required this.icon,required this.onTap}); }
class _QuickGrid extends StatelessWidget { final List<_QuickAction> items; const _QuickGrid({required this.items}); @override Widget build(BuildContext context)=>GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.95),itemCount:items.length,itemBuilder:(_,i){ final x=items[i]; return InkWell(borderRadius:BorderRadius.circular(20),onTap:x.onTap,child:_GlassCard(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.center,children:[Icon(x.icon,size:27,color:Theme.of(context).colorScheme.primary),const SizedBox(height:8),Text(x.title,style:const TextStyle(fontWeight:FontWeight.w800)),const SizedBox(height:2),const Text('Aç',style:TextStyle(fontSize:11))])))); }); }

class _SectionHeader extends StatelessWidget { final String title; final Widget? action; const _SectionHeader({required this.title,this.action}); @override Widget build(BuildContext context)=>Row(children:[Expanded(child:Text(title,style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900))),if(action!=null)action!]); }
class _Eyebrow extends StatelessWidget { final String text; const _Eyebrow(this.text); @override Widget build(BuildContext context)=>Text(text,style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,letterSpacing:1.2,color:Theme.of(context).colorScheme.primary)); }
class _GlassCard extends StatelessWidget { final Widget child; const _GlassCard({required this.child}); @override Widget build(BuildContext context)=>Container(decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(20),border:Border.all(color:const Color(0xFFE9EAF1))),child:child); }
class _StatusBadge extends StatelessWidget { final String text; final bool positive; const _StatusBadge({required this.text,required this.positive}); @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:6),decoration:BoxDecoration(color:positive?const Color(0xFFEAF8EE):const Color(0xFFF1F2F5),borderRadius:BorderRadius.circular(30)),child:Text(text,style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:positive?const Color(0xFF11753A):Colors.grey.shade700))); }
class _MiniPill extends StatelessWidget { final IconData icon; final String text; const _MiniPill({required this.icon,required this.text}); @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),decoration:BoxDecoration(color:const Color(0xFFF7F7FA),borderRadius:BorderRadius.circular(30),border:Border.all(color:const Color(0xFFECECF2))),child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:15),const SizedBox(width:5),Text(text,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))])); }
class _InfoCard extends StatelessWidget { final IconData icon; final String title,body; const _InfoCard({required this.icon,required this.title,required this.body}); @override Widget build(BuildContext context)=>_GlassCard(child:Padding(padding:const EdgeInsets.all(15),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(radius:22,child:Icon(icon)),const SizedBox(width:11),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:5),Text(body,style:TextStyle(color:Colors.grey.shade700,height:1.4))]))]))); }
class _EmptyState extends StatelessWidget { final IconData icon; final String title,subtitle; const _EmptyState({required this.icon,required this.title,required this.subtitle}); @override Widget build(BuildContext context)=>_GlassCard(child:Padding(padding:const EdgeInsets.all(24),child:Column(children:[Icon(icon,size:48,color:Colors.grey.shade500),const SizedBox(height:10),Text(title,style:const TextStyle(fontSize:17,fontWeight:FontWeight.w800)),const SizedBox(height:6),Text(subtitle,textAlign:TextAlign.center,style:TextStyle(color:Colors.grey.shade700,height:1.4))]))); }
class _PoweredBy extends StatelessWidget { final bool inverse,compact; const _PoweredBy({this.inverse=false,this.compact=false}); @override Widget build(BuildContext context){ final c=inverse?Colors.white.withValues(alpha:.70):Colors.grey.shade500; return Center(child:Opacity(opacity:.95,child:Row(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.auto_awesome_rounded,size:compact?12:14,color:c),const SizedBox(width:4),Text('Powered by AdVise AI',style:TextStyle(fontSize:compact?10:11,fontWeight:FontWeight.w700,color:c,letterSpacing:.2))]))); } }

