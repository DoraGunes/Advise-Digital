import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'product_ui.dart';
import 'app_error.dart';
import 'v14_ai.dart';

void _proHome(BuildContext context) => Navigator.of(context).popUntil((route) => route.isFirst);

class ProHubPage extends StatelessWidget {
  final bool admin;
  const ProHubPage({super.key, this.admin = false});

  @override
  Widget build(BuildContext context) {
    final items = <_ProItem>[
      _ProItem('Advise AI', 'Günün reklam danışmanı', Icons.auto_awesome_rounded, const AiAdvisorPage()),
      _ProItem('AI İçerik Stüdyosu', 'Caption, hook, CTA ve format üret', Icons.auto_awesome_rounded, const AiContentStudioPage()),
      _ProItem('Performans', 'KPI ve reklam sağlığı', Icons.insights_rounded, const ProPerformancePage()),
      _ProItem('Bütçe Simülatörü', 'Bütçeyi önceden planla', Icons.account_balance_wallet_rounded, const BudgetSimulatorPage()),
      _ProItem('Lead CRM', 'Mesajları ve satış fırsatlarını takip et', Icons.view_kanban_rounded, const LeadCrmPage()),
      _ProItem('Uyarı Merkezi', 'Anlık ve sistem uyarıları', Icons.notifications_active_rounded, const AlertsPage()),
      _ProItem('Kreatif Lab', 'Görsel/video kreatif analizi', Icons.palette_rounded, const CreativeLabPage()),
      _ProItem('A/B Test', 'Kreatif varyantlarını deneyin', Icons.science_rounded, const ABTestPage()),
      _ProItem('UTM Builder', 'Takip linklerini tek tıkta üret', Icons.link_rounded, const UtmBuilderPage()),
      _ProItem('Rapor Merkezi', 'Müşteri raporu ve CSV dışa aktarım', Icons.description_rounded, const ReportCenterPage()),
      _ProItem('Ajans Merkezi', 'Çoklu müşteri operasyonu', Icons.account_tree_rounded, const AgencyOverviewPage()),
      _ProItem('Bildirim & Güvenlik', 'Tercihler ve güvenlik özeti', Icons.security_rounded, const SecurityQuickPage()),
    ];
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => _proHome(context), icon: const Icon(Icons.home_outlined)),
        title: const Text('Advise Pro Merkezi', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 36),
        children: [
          const _ProHero(
            title: 'Reklam operasyonunu tek merkezden yönet',
            subtitle: 'AI danışmanı, bütçe simülasyonu, CRM, kreatif testleri ve raporlama aynı çalışma alanında.',
            badge: 'ADVISE PRO',
            icon: Icons.auto_awesome,
          ),
          const SizedBox(height: 14),
          _ProStatusBar(admin: admin),
          const SizedBox(height: 14),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.17),
            itemCount: items.length,
            itemBuilder: (_, i) => _ProTile(item: items[i]),
          ),
          const SizedBox(height: 18),
          const _ProCard(child: _ProPoweredBy()),
        ],
      ),
    );
  }
}

class _ProItem {
  final String title, subtitle;
  final IconData icon;
  final Widget page;
  const _ProItem(this.title, this.subtitle, this.icon, this.page);
}

class _ProTile extends StatelessWidget {
  final _ProItem item;
  const _ProTile({required this.item});
  @override
  Widget build(BuildContext context) => InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item.page)),
        child: _ProCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(item.icon, size: 29, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 9),
              Text(item.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15)),
              const SizedBox(height: 4),
              Text(item.subtitle, maxLines: 3, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade700, height: 1.35)),
            ]),
          ),
        ),
      );
}

class _ProCard extends StatelessWidget {
  final Widget child;
  const _ProCard({required this.child});
  @override
  Widget build(BuildContext context) => Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE8EAF1))), child: child);
}

class _ProHero extends StatelessWidget {
  final String title, subtitle, badge;
  final IconData icon;
  const _ProHero({required this.title, required this.subtitle, required this.badge, required this.icon});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1F2454), Color(0xFF4F46E5)]),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 24, offset: Offset(0, 12))],
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 48, height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: Colors.white, size: 26)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: Colors.white.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)), child: Text(badge, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 11))),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(subtitle, style: TextStyle(color: Colors.white.withValues(alpha: .84), height: 1.4)),
          ])),
        ]),
      );
}

class _ProStatusBar extends StatelessWidget {
  final bool admin;
  const _ProStatusBar({required this.admin});
  @override
  Widget build(BuildContext context) => _ProCard(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Wrap(spacing: 16, runSpacing: 8, children: [
        _ProStatusItem(icon: Icons.flash_on_rounded, text: '12 saat karar motoru'),
        _ProStatusItem(icon: Icons.shield_outlined, text: admin ? 'Super Admin' : 'Workspace'),
        const _ProStatusItem(icon: Icons.verified_rounded, text: 'V14 AI özellik paketi'),
      ])));
}
class _ProStatusItem extends StatelessWidget { final IconData icon; final String text; const _ProStatusItem({required this.icon,required this.text}); @override Widget build(BuildContext context)=>Row(mainAxisSize:MainAxisSize.min,children:[Icon(icon,size:17),const SizedBox(width:5),Text(text,style:const TextStyle(fontWeight:FontWeight.w700,fontSize:12))]); }

class AiAdvisorPage extends StatefulWidget { const AiAdvisorPage({super.key}); @override State<AiAdvisorPage> createState()=>_AiAdvisorPageState(); }
class _AiAdvisorPageState extends State<AiAdvisorPage>{Map<String,dynamic>? data;bool loading=true;@override void initState(){super.initState();_load();}Future<void> _load() async{try{final x=await Api.proAi();if(mounted)setState(()=>data=x);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(AppError.message(e))));}finally{if(mounted)setState(()=>loading=false);}}@override Widget build(BuildContext context){final d=data??{};final list=List<dynamic>.from(d['summary']??const[]);return _ProFrame(title:'Advise AI',loading:loading,onRefresh:_load,children:[_ProHero(title:'Bugünün reklam danışmanı',subtitle:'Kararları açıklar, önce neye bakman gerektiğini söyler.',badge:'AI ADVISOR',icon:Icons.auto_awesome),const SizedBox(height:14),_ProCard(child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Icon(Icons.insights_rounded),const SizedBox(width:8),const Text('Hesap sağlık skoru',style:TextStyle(fontWeight:FontWeight.w800)),const Spacer(),Text('${d['score']??'-'}/100',style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900))]),const SizedBox(height:14),LinearProgressIndicator(value:((d['score']??0) as num).toDouble()/100,minHeight:9),const SizedBox(height:12),for(final x in list)_Bullet(text:x.toString())]))),const SizedBox(height:12),const _ProInfo(text:'Bu sürümde AI açıklamaları güvenli ve kural tabanlıdır; tek bir anomaliyi kesin sonuç gibi sunmaz.'),const SizedBox(height:14),const _ProPoweredBy()] );}}

class ProPerformancePage extends StatefulWidget { const ProPerformancePage({super.key}); @override State<ProPerformancePage> createState()=>_ProPerformancePageState(); }
class _ProPerformancePageState extends State<ProPerformancePage>{Map<String,dynamic>? data;bool loading=true;@override void initState(){super.initState();_load();}Future<void> _load()async{try{final x=await Api.proPerformance();if(mounted)setState(()=>data=x);}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(AppError.message(e))));}finally{if(mounted)setState(()=>loading=false);}}@override Widget build(BuildContext context){final d=data??{};return _ProFrame(title:'Performans',loading:loading,onRefresh:_load,children:[const _ProHero(title:'Reklam sağlığı',subtitle:'Kayıtlı operasyon verilerinin hızlı özeti.',badge:'PERFORMANCE',icon:Icons.insights_rounded),const SizedBox(height:14),GridView.count(crossAxisCount:2,shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.4,children:[_Kpi('İçerik','${d['posts']??0}',Icons.photo_library_outlined),_Kpi('İşlem','${d['logCount']??0}',Icons.receipt_long_outlined),_Kpi('Durdurulan','${d['paused']??0}',Icons.pause_circle_outline),_Kpi('Bütçe değişimi','${d['budgetChanges']??0}',Icons.account_balance_wallet_outlined)]),const SizedBox(height:14),_ProInfo(text:'Gerçek Meta KPI kartları için hesap bağlandığında mevcut Insights akışı bu merkeze eklenebilir.'),const SizedBox(height:14),const _ProPoweredBy()] );}}
class _Kpi extends StatelessWidget{final String title,value;final IconData icon;const _Kpi(this.title,this.value,this.icon);@override Widget build(BuildContext context)=>_ProCard(child:Padding(padding:const EdgeInsets.all(14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon,size:22,color:Theme.of(context).colorScheme.primary),const Spacer(),Text(value,style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900)),Text(title,style:TextStyle(color:Colors.grey.shade700,fontWeight:FontWeight.w700))])));}

class BudgetSimulatorPage extends StatefulWidget {
  const BudgetSimulatorPage({super.key});

  @override
  State<BudgetSimulatorPage> createState() => _BudgetSimulatorPageState();
}

class _BudgetSimulatorPageState extends State<BudgetSimulatorPage> {
  final total = TextEditingController(text: '5000');
  final reserve = TextEditingController(text: '10');
  final rows = <Map<String, dynamic>>[];
  Map<String, dynamic>? result;
  bool loading = false;

  @override
  void dispose() {
    total.dispose();
    reserve.dispose();
    super.dispose();
  }

  void addRow() {
    setState(() {
      rows.add({
        'name': 'Reklam ${rows.length + 1}',
        'messageCost': '8',
        'ctr': '1.5',
        'messages': '5',
        'spend': '50',
      });
    });
  }

  Future<void> run() async {
    setState(() => loading = true);
    try {
      result = await Api.simulateBudget(
        totalBudget: double.tryParse(total.text) ?? 0,
        reservePercent: double.tryParse(reserve.text) ?? 10,
        items: rows
            .map((e) => {
                  'name': e['name'],
                  'messageCost': double.tryParse(e['messageCost']?.toString() ?? '') ?? 0,
                  'ctr': double.tryParse(e['ctr']?.toString() ?? '') ?? 0,
                  'messages': double.tryParse(e['messages']?.toString() ?? '') ?? 0,
                  'spend': double.tryParse(e['spend']?.toString() ?? '') ?? 0,
                })
            .toList(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProFrame(
      title: 'Bütçe Simülatörü',
      loading: loading,
      onRefresh: run,
      children: [
        const _ProHero(
          title: 'Bütçeyi çalıştırmadan önce planla',
          subtitle: 'Toplam bütçeyi performans sinyallerine göre örnekle.',
          badge: 'BUDGET LAB',
          icon: Icons.account_balance_wallet_rounded,
        ),
        const SizedBox(height: 12),
        _ProCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _NumField(total, 'Toplam bütçe (TL)'),
                _NumField(reserve, 'Rezerv (%)'),
                const SizedBox(height: 4),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Reklamlar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty) const _ProInfo(text: 'Önce örnek reklam ekle.'),
                for (final r in rows) _BudgetRow(r),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: addRow,
                        icon: const Icon(Icons.add),
                        label: const Text('Reklam ekle'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: run,
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: const Text('SİMÜLE ET'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (result != null) _BudgetResult(result!),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class _NumField extends StatelessWidget {
  final TextEditingController c;
  final String label;
  const _NumField(this.c, this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: c,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
        ),
      );
}

class _BudgetRow extends StatelessWidget {
  final Map<String, dynamic> row;
  const _BudgetRow(this.row);

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7FA),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(row['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(child: Text('Mesaj ${row['messageCost']} TL', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('CTR ${row['ctr']}%', style: const TextStyle(fontSize: 12))),
                Expanded(child: Text('Mesaj ${row['messages']}', style: const TextStyle(fontSize: 12))),
              ],
            ),
          ],
        ),
      );
}

class _BudgetResult extends StatelessWidget {
  final Map<String, dynamic> r;
  const _BudgetResult(this.r);

  @override
  Widget build(BuildContext context) {
    final list = List<dynamic>.from(r['allocations'] ?? const []);
    return _ProCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Önerilen dağılım', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)),
            const SizedBox(height: 8),
            Text('Rezerv: ${r['reserve'] ?? 0} TL'),
            const SizedBox(height: 10),
            for (final x in list) _BudgetLine(x),
          ],
        ),
      ),
    );
  }
}

class _BudgetLine extends StatelessWidget {
  final dynamic x;
  const _BudgetLine(this.x);

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.compare_arrows_rounded),
        title: Text(x['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: Text('Skor ${x['score'] ?? 0} • Mesaj ${x['messageCost'] ?? 0} TL'),
        trailing: Text('${x['allocation'] ?? 0} TL', style: const TextStyle(fontWeight: FontWeight.w900)),
      );
}


class LeadCrmPage extends StatefulWidget {
  const LeadCrmPage({super.key});

  @override
  State<LeadCrmPage> createState() => _LeadCrmPageState();
}

class _LeadCrmPageState extends State<LeadCrmPage> {
  List<dynamic> leads = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final x = await Api.proLeads();
      if (mounted) setState(() => leads = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final value = TextEditingController(text: '0');
    String status = 'NEW';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const Text('Yeni Lead'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(controller: name, decoration: const InputDecoration(labelText: 'Ad / firma')),
                const SizedBox(height: 10),
                TextField(controller: phone, decoration: const InputDecoration(labelText: 'Telefon')),
                const SizedBox(height: 10),
                TextField(
                  controller: value,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Tahmini değer (TL)'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  items: const [
                    DropdownMenuItem(value: 'NEW', child: Text('Yeni')),
                    DropdownMenuItem(value: 'CONTACTED', child: Text('İletişimde')),
                    DropdownMenuItem(value: 'OFFER', child: Text('Teklif')),
                    DropdownMenuItem(value: 'WON', child: Text('Satış')),
                    DropdownMenuItem(value: 'LOST', child: Text('Kayıp')),
                  ],
                  onChanged: (x) => setDialog(() => status = x ?? 'NEW'),
                  decoration: const InputDecoration(labelText: 'Aşama'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
            FilledButton(
              onPressed: () async {
                try {
                  await Api.createLead(
                    name: name.text,
                    phone: phone.text,
                    value: double.tryParse(value.text) ?? 0,
                    status: status,
                  );
                  if (ctx.mounted) Navigator.pop(ctx, true);
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppError.message(e))));
                  }
                }
              },
              child: const Text('KAYDET'),
            ),
          ],
        ),
      ),
    );

    name.dispose();
    phone.dispose();
    value.dispose();
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _ProFrame(
      title: 'Lead CRM',
      loading: loading,
      onRefresh: _load,
      actions: [IconButton(onPressed: _add, icon: const Icon(Icons.person_add_alt_1_rounded))],
      children: [
        const _ProHero(
          title: 'Mesajdan satışa',
          subtitle: 'Lead kayıtlarını aşamaya göre takip et.',
          badge: 'CRM',
          icon: Icons.view_kanban_rounded,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StageCount(title: 'Yeni', count: leads.where((x) => x['status'] == 'NEW').length)),
            const SizedBox(width: 8),
            Expanded(child: _StageCount(title: 'Teklif', count: leads.where((x) => x['status'] == 'OFFER').length)),
            const SizedBox(width: 8),
            Expanded(child: _StageCount(title: 'Satış', count: leads.where((x) => x['status'] == 'WON').length)),
          ],
        ),
        const SizedBox(height: 12),
        ...leads.map((x) => _LeadCard(x, onRefresh: _load)),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class _StageCount extends StatelessWidget {
  final String title;
  final int count;
  const _StageCount({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return _ProCard(
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          children: [
            Text('$count', style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w900)),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _LeadCard extends StatelessWidget {
  final dynamic lead;
  final Future<void> Function() onRefresh;
  const _LeadCard(this.lead, {required this.onRefresh});

  Future<void> _delete(BuildContext context) async {
    try {
      await Api.deleteLead(lead['id']);
      await onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    }
  }

  Future<void> _next(BuildContext context) async {
    const order = ['NEW', 'CONTACTED', 'OFFER', 'WON'];
    final current = order.indexOf(lead['status']?.toString() ?? 'NEW');
    final nextIndex = (current + 1).clamp(0, order.length - 1);
    try {
      await Api.updateLead(lead['id'], {'status': order[nextIndex]});
      await onRefresh();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = lead['name']?.toString() ?? '-';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _ProCard(
        child: ListTile(
          leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0].toUpperCase() : 'L')),
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${lead['status'] ?? '-'} • ${lead['phone'] ?? ''} • ${lead['value'] ?? 0} TL'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'next') _next(context);
              if (value == 'delete') _delete(context);
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'next', child: Text('Sonraki aşama')),
              PopupMenuItem(value: 'delete', child: Text('Sil')),
            ],
          ),
        ),
      ),
    );
  }
}

class AlertsPage extends StatefulWidget {
  const AlertsPage({super.key});

  @override
  State<AlertsPage> createState() => _AlertsPageState();
}

class _AlertsPageState extends State<AlertsPage> {
  List<dynamic> alerts = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final x = await Api.proAlerts();
      if (mounted) setState(() => alerts = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _demo() async {
    try {
      await Api.createAlert('Advise uyarısı', 'Yeni bir kontrol gerektiren olay oluştu.', 'INFO');
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProFrame(
      title: 'Uyarı Merkezi',
      loading: loading,
      onRefresh: _load,
      actions: [IconButton(onPressed: _demo, icon: const Icon(Icons.add_alert_outlined))],
      children: [
        const _ProHero(
          title: 'Uyarı merkezi',
          subtitle: 'Kritik maliyet, abonelik ve sistem bildirimlerini burada topla.',
          badge: 'ALERTS',
          icon: Icons.notifications_active_rounded,
        ),
        const SizedBox(height: 12),
        if (alerts.isEmpty) const _ProInfo(text: 'Şimdilik uyarı yok.'),
        ...alerts.map((a) => _AlertTile(a, onRefresh: _load)),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class _AlertTile extends StatelessWidget {
  final dynamic alert;
  final Future<void> Function() onRefresh;
  const _AlertTile(this.alert, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final severity = alert['severity']?.toString() ?? 'INFO';
    final icon = severity == 'ERROR'
        ? Icons.error_outline
        : severity == 'WARNING'
            ? Icons.warning_amber_rounded
            : Icons.info_outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _ProCard(
        child: ListTile(
          leading: Icon(icon),
          title: Text(alert['title']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${alert['body'] ?? ''}\n${alert['createdAt'] ?? ''}'),
          isThreeLine: true,
          trailing: alert['read'] == true
              ? const Icon(Icons.done_all)
              : TextButton(
                  onPressed: () async {
                    await Api.markAlert(alert['id']);
                    await onRefresh();
                  },
                  child: const Text('OKUDUM'),
                ),
        ),
      ),
    );
  }
}

class CreativeLabPage extends StatefulWidget {
  const CreativeLabPage({super.key});

  @override
  State<CreativeLabPage> createState() => _CreativeLabPageState();
}

class _CreativeLabPageState extends State<CreativeLabPage> {
  List<dynamic> creatives = [];
  bool loading = true;
  final title = TextEditingController();
  final copy = TextEditingController();
  String type = 'IMAGE';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    title.dispose();
    copy.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final x = await Api.creatives();
      if (mounted) setState(() => creatives = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _analyze() async {
    try {
      await Api.analyzeCreative(title: title.text, copy: copy.text, type: type);
      title.clear();
      copy.clear();
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProFrame(
      title: 'Kreatif Lab',
      loading: loading,
      onRefresh: _load,
      children: [
        const _ProHero(
          title: 'Kreatiflerini puanla',
          subtitle: 'Metin uzunluğu, format ve netlik için hızlı kontrol.',
          badge: 'CREATIVE LAB',
          icon: Icons.palette_rounded,
        ),
        const SizedBox(height: 12),
        _ProCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Kreatif adı')),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  items: const [
                    DropdownMenuItem(value: 'IMAGE', child: Text('Görsel')),
                    DropdownMenuItem(value: 'VIDEO', child: Text('Video')),
                  ],
                  onChanged: (v) => setState(() => type = v ?? 'IMAGE'),
                  decoration: const InputDecoration(labelText: 'Tür'),
                ),
                const SizedBox(height: 8),
                TextField(controller: copy, maxLines: 4, decoration: const InputDecoration(labelText: 'Reklam metni')),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: _analyze,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('ANALİZ ET'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...creatives.map((x) => _CreativeTile(x)),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class _CreativeTile extends StatelessWidget {
  final dynamic creative;
  const _CreativeTile(this.creative);

  @override
  Widget build(BuildContext context) {
    final flags = List<dynamic>.from(creative['flags'] ?? const []);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _ProCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      creative['title']?.toString() ?? '-',
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  Text('${creative['score'] ?? 0}/100', style: const TextStyle(fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${creative['type'] ?? '-'} • ${creative['copy'] ?? ''}',
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              for (final flag in flags) _Bullet(text: flag.toString()),
            ],
          ),
        ),
      ),
    );
  }
}

class ABTestPage extends StatefulWidget {
  const ABTestPage({super.key});

  @override
  State<ABTestPage> createState() => _ABTestPageState();
}

class _ABTestPageState extends State<ABTestPage> {
  List<dynamic> experiments = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final x = await Api.experiments();
      if (mounted) setState(() => experiments = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _add() async {
    final name = TextEditingController(text: 'Kreatif Testi');
    final budget = TextEditingController(text: '500');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('A/B test oluştur'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Test adı')),
            const SizedBox(height: 10),
            TextField(controller: budget, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Bütçe (TL)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          FilledButton(
            onPressed: () async {
              try {
                await Api.createExperiment(
                  name: name.text,
                  budget: double.tryParse(budget.text) ?? 0,
                  variants: const [
                    {'name': 'A', 'goal': 'MESSAGE_COST'},
                    {'name': 'B', 'goal': 'MESSAGE_COST'},
                  ],
                );
                if (ctx.mounted) Navigator.pop(ctx, true);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(AppError.message(e))));
                }
              }
            },
            child: const Text('OLUŞTUR'),
          ),
        ],
      ),
    );
    name.dispose();
    budget.dispose();
    if (ok == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return _ProFrame(
      title: 'A/B Test',
      loading: loading,
      onRefresh: _load,
      actions: [IconButton(onPressed: _add, icon: const Icon(Icons.add_chart_rounded))],
      children: [
        const _ProHero(
          title: 'Varyantlarını test et',
          subtitle: 'Aynı hedefte farklı kreatifleri kontrollü şekilde karşılaştır.',
          badge: 'A/B LAB',
          icon: Icons.science_rounded,
        ),
        const SizedBox(height: 12),
        if (experiments.isEmpty) const _ProInfo(text: 'Henüz A/B testi yok.'),
        ...experiments.map((e) => _ExperimentTile(e, onRefresh: _load)),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class _ExperimentTile extends StatelessWidget {
  final dynamic experiment;
  final Future<void> Function() onRefresh;
  const _ExperimentTile(this.experiment, {required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    final variants = List<dynamic>.from(experiment['variants'] ?? const []);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: _ProCard(
        child: ListTile(
          leading: const CircleAvatar(child: Icon(Icons.science_outlined)),
          title: Text(experiment['name']?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('${experiment['status'] ?? '-'} • ${experiment['budget'] ?? 0} TL • ${variants.length} varyant'),
          trailing: PopupMenuButton<String>(
            onSelected: (value) async {
              try {
                await Api.updateExperimentStatus(experiment['id'], value);
                await onRefresh();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
                }
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'RUNNING', child: Text('Başlat')),
              PopupMenuItem(value: 'PAUSED', child: Text('Duraklat')),
              PopupMenuItem(value: 'DONE', child: Text('Bitir')),
            ],
          ),
        ),
      ),
    );
  }
}

class UtmBuilderPage extends StatefulWidget {
  const UtmBuilderPage({super.key});

  @override
  State<UtmBuilderPage> createState() => _UtmBuilderPageState();
}

class _UtmBuilderPageState extends State<UtmBuilderPage> {
  final base = TextEditingController(text: 'https://example.com');
  final source = TextEditingController(text: 'meta');
  final medium = TextEditingController(text: 'paid-social');
  final campaign = TextEditingController(text: 'advise-campaign');
  final content = TextEditingController(text: 'creative-1');
  String output = '';

  @override
  void dispose() {
    base.dispose();
    source.dispose();
    medium.dispose();
    campaign.dispose();
    content.dispose();
    super.dispose();
  }

  Future<void> _make() async {
    try {
      final r = await Api.buildUtm(
        source: source.text,
        medium: medium.text,
        campaign: campaign.text,
        content: content.text,
      );
      if (mounted) {
        setState(() {
          output = '${base.text}${base.text.contains('?') ? '&' : '?'}${r['query']}';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _ProFrame(
      title: 'UTM Builder',
      children: [
        const _ProHero(
          title: 'Takip linki üret',
          subtitle: 'Reklamların kaynağını temiz şekilde işaretle.',
          badge: 'UTM',
          icon: Icons.link_rounded,
        ),
        const SizedBox(height: 12),
        _ProCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                TextField(controller: base, decoration: const InputDecoration(labelText: 'Temel URL')),
                const SizedBox(height: 8),
                TextField(controller: source, decoration: const InputDecoration(labelText: 'Source')),
                const SizedBox(height: 8),
                TextField(controller: medium, decoration: const InputDecoration(labelText: 'Medium')),
                const SizedBox(height: 8),
                TextField(controller: campaign, decoration: const InputDecoration(labelText: 'Campaign')),
                const SizedBox(height: 8),
                TextField(controller: content, decoration: const InputDecoration(labelText: 'Content')),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(onPressed: _make, icon: const Icon(Icons.link), label: const Text('ÜRET')),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (output.isNotEmpty)
          _ProCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: SelectableText(output, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}


class ReportCenterPage extends StatefulWidget {
  const ReportCenterPage({super.key});

  @override
  State<ReportCenterPage> createState() => _ReportCenterPageState();
}

class _ReportCenterPageState extends State<ReportCenterPage> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final x = await Api.proReport();
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _copy() async {
    final csv = data?['csv']?.toString() ?? '';
    await Clipboard.setData(ClipboardData(text: csv));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV raporu panoya kopyalandı.')));
    }
  }

  Future<void> _preview() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rapor içeriği'),
        content: SingleChildScrollView(child: SelectableText(data?['csv']?.toString() ?? '')),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final report = data ?? <String, dynamic>{};
    final tenant = report['tenant'] is Map ? Map<String, dynamic>.from(report['tenant']) : <String, dynamic>{};
    final summary = report['summary'] is Map ? Map<String, dynamic>.from(report['summary']) : <String, dynamic>{};
    return _ProFrame(
      title: 'Rapor Merkezi',
      loading: loading,
      onRefresh: _load,
      children: [
        const _ProHero(
          title: 'Müşteri raporu',
          subtitle: 'KPI ve AI özetini tek raporda topla.',
          badge: 'REPORTS',
          icon: Icons.description_rounded,
        ),
        const SizedBox(height: 12),
        if (data != null)
          _ProCard(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tenant['companyName']?.toString() ?? 'AdVise AI', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 10),
                  Text('İçerik: ${summary['posts'] ?? 0}'),
                  Text('Durdurulan reklam: ${summary['paused'] ?? 0}'),
                  Text('Bütçe değişimi: ${summary['budgetChanges'] ?? 0}'),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(onPressed: _copy, icon: const Icon(Icons.copy_all), label: const Text('CSV KOPYALA'))),
                      const SizedBox(width: 8),
                      Expanded(child: FilledButton.icon(onPressed: _preview, icon: const Icon(Icons.preview), label: const Text('ÖNİZLE'))),
                    ],
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 12),
        const _ProInfo(text: 'Rapor verisi ve CSV hazır. Doğrudan PDF dışa aktarımı sonraki dosya paylaşım katmanına bağlanabilir.'),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class AgencyOverviewPage extends StatelessWidget {
  const AgencyOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    const modules = [
      'Multi-tenant',
      'Rol ve yetki',
      'Lead CRM',
      'Rapor merkezi',
      'White Label',
      'A/B Test',
      'UTM',
      'AI Advisor',
    ];
    return _ProFrame(
      title: 'Ajans Merkezi',
      children: [
        const _ProHero(
          title: 'Çoklu müşteri operasyonu',
          subtitle: 'Müşterileri tek operasyon mantığında yönet.',
          badge: 'AGENCY',
          icon: Icons.account_tree_rounded,
        ),
        const SizedBox(height: 12),
        _ProCard(
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Hazır modüller', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                for (final module in modules) _Bullet(text: module),
                const SizedBox(height: 10),
                Text(
                  'Tenant geçişi ve gerçek müşteri listesi mevcut admin panelindeki müşteri merkezinden yönetilir.',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _ProInfo(text: 'Agency modu mevcut V12 admin / lisans yapısıyla birlikte çalışır.'),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class SecurityQuickPage extends StatefulWidget {
  const SecurityQuickPage({super.key});

  @override
  State<SecurityQuickPage> createState() => _SecurityQuickPageState();
}

class _SecurityQuickPageState extends State<SecurityQuickPage> {
  Map<String, dynamic>? data;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final x = await Api.securityOverview();
      if (mounted) setState(() => data = x);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = data ?? <String, dynamic>{};
    return _ProFrame(
      title: 'Güvenlik',
      loading: loading,
      onRefresh: _load,
      children: [
        const _ProHero(
          title: 'Güvenlik ve bildirimler',
          subtitle: 'Oturum ve servis durumunu hızlıca kontrol et.',
          badge: 'SECURITY',
          icon: Icons.security_rounded,
        ),
        const SizedBox(height: 12),
        _ProCard(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                _InfoLine('Tenant', d['tenantId']),
                _InfoLine('Kullanıcı', d['userCount']),
                _InfoLine('Son kayıt', d['latestLogAt']),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const _ProInfo(text: 'Üretimde HTTPS, güvenli secret saklama ve erişim loglarını aktif tut.'),
        const SizedBox(height: 14),
        const _ProPoweredBy(),
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final String label;
  final dynamic value;
  const _InfoLine(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      trailing: Text(value?.toString() ?? '-', style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }
}

class _ProFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool loading;
  final Future<void> Function()? onRefresh;
  final List<Widget> actions;

  const _ProFrame({
    required this.title,
    required this.children,
    this.loading = false,
    this.onRefresh,
    this.actions = const [],
  });

  void _goHome(BuildContext context) {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(onPressed: () => _goHome(context), icon: const Icon(Icons.home_outlined)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          if (onRefresh != null)
            IconButton(
              onPressed: loading ? null : onRefresh,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ...actions,
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 36),
              children: children,
            ),
    );
  }
}

class _ProInfo extends StatelessWidget {
  final String text;
  const _ProInfo({required this.text});

  @override
  Widget build(BuildContext context) => _ProCard(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded),
              const SizedBox(width: 9),
              Expanded(child: Text(text, style: TextStyle(color: Colors.grey.shade700, height: 1.4))),
            ],
          ),
        ),
      );
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet({required this.text});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.check_circle_outline, size: 18),
            const SizedBox(width: 7),
            Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
          ],
        ),
      );
}

class _ProPoweredBy extends StatelessWidget {
  const _ProPoweredBy();

  @override
  Widget build(BuildContext context) => Center(
        child: Text(
          'Powered by AdVise AI',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.grey.shade500),
        ),
      );
}
