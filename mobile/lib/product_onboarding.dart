import 'package:flutter/material.dart';

import 'api.dart';
import 'product_shell.dart';
import 'product_ui.dart';
import 'v78_pages.dart' show MetaConnectionPage;

class ProductOnboardingPage extends StatefulWidget {
  const ProductOnboardingPage({super.key});
  @override
  State<ProductOnboardingPage> createState() => _ProductOnboardingPageState();
}

class _ProductOnboardingPageState extends State<ProductOnboardingPage> {
  final name = TextEditingController();
  final industry = TextEditingController();
  final budget = TextEditingController();
  String goal = 'WhatsApp mesajı';
  String locationMode = 'COUNTRY';
  Set<String> locations = {};
  List<String> cities = [], regions = [];
  Map<String, dynamic> connection = {};
  bool loading = true, saving = false, completed = false;
  bool analyzing = false;
  Map<String, dynamic>? initialStrategy;
  String? analysisError;
  int step = 0;
  String? error;
  static const _steps = ['İşletmen', 'Hedefin', 'Bölgen', 'Bütçen', 'Bağlantı'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    name.dispose();
    industry.dispose();
    budget.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final responses = await Future.wait(
          [Api.productOnboarding(), Api.adTargetingOptions()]);
      if (!mounted) return;
      final profile = responses[0];
      final target = responses[1];
      name.text = profile['businessName']?.toString() ?? '';
      industry.text = profile['industry']?.toString() ?? '';
      final amount = profile['dailyBudget'];
      budget.text = amount is num && amount > 0 ? amount.toString() : '';
      goal = profile['goal']?.toString().isNotEmpty == true
          ? profile['goal'].toString()
          : 'WhatsApp mesajı';
      locationMode = profile['locationMode']?.toString() ??
          target['mode']?.toString() ??
          'COUNTRY';
      locations =
          Set<String>.from(profile['locations'] ?? target['locations'] ?? []);
      cities = List<String>.from(target['cities'] ?? []);
      regions = List<String>.from(target['regions'] ?? []);
      connection = Map<String, dynamic>.from(profile['connection'] ?? {});
      completed = profile['completed'] == true;
      step = ((profile['step'] as num?)?.toInt() ?? 0).clamp(0, 4);
    } catch (e) {
      error = productFriendlyError(e);
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Map<String, dynamic> _values({bool finish = false}) => {
        'businessName': name.text.trim(),
        'industry': industry.text.trim(),
        'goal': goal,
        'locationMode': locationMode,
        'locations': locations.toList(),
        'dailyBudget':
            double.tryParse(budget.text.trim().replaceAll(',', '.')) ?? 0,
        'step': step,
        'completed': finish || completed,
      };

  String? _validateStep() => switch (step) {
        0 => name.text.trim().isEmpty || industry.text.trim().isEmpty
            ? 'İşletme adını ve sektörünü gir.'
            : null,
        1 => goal.trim().isEmpty ? 'Bir işletme hedefi seç.' : null,
        2 => locationMode != 'COUNTRY' && locations.isEmpty
            ? 'En az bir il veya bölge seç.'
            : null,
        3 => (double.tryParse(budget.text.replaceAll(',', '.')) ?? 0) <= 0
            ? 'Günlük reklam bütçeni gir.'
            : null,
        _ => null,
      };

  Future<void> _save({bool finish = false, bool leave = false}) async {
    if (saving) return;
    if (!leave) {
      final validation = _validateStep();
      if (validation != null) {
        setState(() => error = validation);
        return;
      }
    }
    setState(() {
      saving = true;
      error = null;
    });
    final previousStep = step;
    try {
      if (!finish && !leave && step < 4) step++;
      final response = await Api.saveProductOnboarding(_values(finish: finish));
      if (previousStep == 2 || finish)
        await Api.saveAdTargetingPreferences(
            mode: locationMode, locations: locations.toList());
      if (!mounted) return;
      if (finish || leave) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(finish
                ? 'İşletme kurulumu tamamlandı.'
                : 'Kurulum kaydedildi. Daha Fazla bölümünden devam edebilirsin.')));
        Navigator.of(context).pop();
      } else {
        setState(() {
          completed = response['completed'] == true;
          connection =
              Map<String, dynamic>.from(response['connection'] ?? connection);
        });
      }
    } catch (e) {
      if (mounted)
        setState(() {
          step = previousStep;
          error = productFriendlyError(e);
        });
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  Future<void> _connect() async {
    final navigation = ProductNavigation.maybeOf(context);
    if (navigation != null) {
      await navigation.open(const MetaConnectionPage());
    } else {
      await Navigator.push(context,
          MaterialPageRoute<void>(builder: (_) => const MetaConnectionPage()));
    }
    if (!mounted) return;
    try {
      final profile = await Api.productOnboarding();
      if (mounted)
        setState(() => connection =
            Map<String, dynamic>.from(profile['connection'] ?? {}));
    } catch (e) {
      if (mounted) setState(() => error = productFriendlyError(e));
    }
  }

  Future<void> _analyzeBusiness() async {
    if (saving || analyzing) return;
    setState(() {
      analyzing = true;
      analysisError = null;
    });
    try {
      final result = await Api.productStrategy(_values());
      if (!mounted) return;
      setState(() {
        initialStrategy =
            result['available'] == true && result['strategy'] is Map
                ? Map<String, dynamic>.from(result['strategy'])
                : null;
        if (initialStrategy == null) {
          analysisError = productFriendlyError(
              result['error'] ?? 'AI başlangıç önerisi hazırlanamadı.');
        }
      });
    } catch (e) {
      if (mounted) setState(() => analysisError = productFriendlyError(e));
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ready = ['meta', 'page', 'instagram', 'adAccount']
        .every((key) => connection[key] == true);
    return Scaffold(
      appBar: AppBar(title: const Text('İşletme kurulumu'), actions: [
        TextButton(
            onPressed: saving || loading ? null : () => _save(leave: true),
            child: const Text('Daha sonra'))
      ]),
      body: ProductContent(
          maxWidth: 820,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const ProductPageHeader(
                title: 'AdVise işletmeni tanısın',
                subtitle:
                    'Hedefini belirle, hesabını bağla ve ilk içeriğine hazırlan.'),
            const SizedBox(height: 24),
            if (loading)
              const ProductLoadingSkeleton()
            else ...[
              LinearProgressIndicator(
                  value: (step + 1) / _steps.length,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(6)),
              const SizedBox(height: 12),
              Text('${step + 1} / ${_steps.length} • ${_steps[step]}',
                  style: Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 24),
              if (error != null) ...[
                ProductErrorState(message: error!),
                const SizedBox(height: 16)
              ],
              ProductSurface(
                  child: switch (step) {
                0 => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('İşletme bilgileri',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                            'İçerik ve reklam önerilerini işletmene göre hazırlayalım.'),
                        const SizedBox(height: 24),
                        TextField(
                            controller: name,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                                labelText: 'İşletme adı',
                                prefixIcon: Icon(Icons.business_outlined))),
                        const SizedBox(height: 16),
                        TextField(
                            controller: industry,
                            textInputAction: TextInputAction.done,
                            decoration: const InputDecoration(
                                labelText: 'Sektör',
                                hintText:
                                    'Örneğin teknik servis, mobilya, restoran'))
                      ]),
                1 => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('İşletme hedefin',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 12),
                        const Text(
                            'WhatsApp üzerinden gelen görüşmeleri büyütmek için öneriler hazırlanır.'),
                        const SizedBox(height: 16),
                        const ProductInsightCard(
                            title: 'WhatsApp mesajları',
                            body:
                                'İçerik çağrıları ve reklam hedefi işletmenle WhatsApp üzerinden iletişime yönlendirilir.',
                            icon: Icons.chat_bubble_outline_rounded),
                        const SizedBox(height: 16),
                        TextFormField(
                            initialValue: goal,
                            readOnly: true,
                            decoration: const InputDecoration(
                                labelText: 'Mevcut reklam hedefi')),
                        const SizedBox(height: 12),
                        const Text(
                            'Görüşmeleri ve satış sonucunu CRM üzerinden takip edebilirsin.')
                      ]),
                2 => _targeting(context),
                3 => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Test için günlük bütçe',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                            'Bir başlangıç önerisi için yaklaşık bütçe. Bu adım reklam açmaz ve Meta bütçeni değiştirmez.'),
                        const SizedBox(height: 24),
                        TextField(
                            controller: budget,
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            decoration: const InputDecoration(
                                labelText: 'Günlük planlama bütçesi',
                                suffixText: 'TL')),
                        const SizedBox(height: 16),
                        const Text(
                            'Otomasyonun günlük limiti ayrıca Otomasyon bölümünden belirlenir.')
                      ]),
                _ => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hesap bağlantın',
                            style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 8),
                        const Text(
                            'Doğrulanmış hesapların olmadan reklam oluşturulmaz. Mevcut Meta bağlantı akışını kullan.'),
                        const SizedBox(height: 20),
                        for (final entry in const {
                          'meta': 'Facebook / Meta',
                          'page': 'Facebook Sayfası',
                          'instagram': 'Instagram hesabı',
                          'adAccount': 'Reklam hesabı'
                        }.entries)
                          ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                  connection[entry.key] == true
                                      ? Icons.check_circle_outline
                                      : Icons.link_off_outlined,
                                  color: connection[entry.key] == true
                                      ? ProductColors.success
                                      : Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant),
                              title: Text(entry.value),
                              trailing: ProductStatusChip(
                                  label: connection[entry.key] == true
                                      ? 'Bağlı'
                                      : 'Bekliyor',
                                  tone: connection[entry.key] == true
                                      ? 'success'
                                      : 'neutral')),
                        const SizedBox(height: 16),
                        OutlinedButton.icon(
                            onPressed: saving ? null : _connect,
                            icon: const Icon(Icons.link_rounded),
                            label: const Text('Meta bağlantı merkezini aç')),
                        if (!ready) ...[
                          const SizedBox(height: 12),
                          const Text(
                              'Bağlantıyı daha sonra tamamlayabilirsin. İçerik hazırlamak için kurulumu kaydetmen yeterli.')
                        ],
                        if (ready) ...[
                          const SizedBox(height: 16),
                          const ProductInsightCard(
                              title: 'İlk içerik için hazırsın',
                              body:
                                  'AI Studio’ya bir fotoğraf veya video ekle. AdVise ürününü analiz edip WhatsApp odaklı bir içerik hazırlasın.'),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                              onPressed:
                                  saving || analyzing ? null : _analyzeBusiness,
                              icon: const Icon(Icons.auto_awesome_outlined),
                              label: Text(analyzing
                                  ? 'İşletme önerisi hazırlanıyor…'
                                  : 'AI başlangıç önerisi al')),
                          const SizedBox(height: 8),
                          const Text(
                              'Bu öneri işletme profilini ve mevcut performansı kullanır. Reklam açmaz veya bütçe değiştirmez.'),
                          if (analysisError != null)
                            ProductErrorState(message: analysisError!),
                          if (initialStrategy != null) ...[
                            const SizedBox(height: 12),
                            ProductInsightCard(
                                title: 'Gemini başlangıç önerisi',
                                body: [
                                  initialStrategy!['hook'],
                                  if (initialStrategy!['creative'] is Map)
                                    initialStrategy!['creative']['angle'],
                                  if (initialStrategy!['audience'] is Map)
                                    initialStrategy!['audience']['description'],
                                  if (initialStrategy!['reasons'] is List)
                                    ...(initialStrategy!['reasons'] as List),
                                ]
                                    .where((value) =>
                                        value != null &&
                                        value.toString().trim().isNotEmpty)
                                    .join('\n')),
                          ],
                        ]
                      ]),
              }),
              const SizedBox(height: 24),
              Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.end,
                  children: [
                    if (step > 0)
                      OutlinedButton(
                          onPressed: saving
                              ? null
                              : () => setState(() {
                                    step--;
                                    error = null;
                                  }),
                          child: const Text('Geri')),
                    FilledButton.icon(
                        onPressed: saving || (step == 4 && !ready)
                            ? null
                            : () => _save(finish: step == 4),
                        icon: saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : Icon(step == 4
                                ? Icons.check_rounded
                                : Icons.arrow_forward_rounded),
                        label: Text(step == 4
                            ? 'Kurulumu tamamla'
                            : 'Kaydet ve devam et')),
                  ]),
            ],
          ])),
    );
  }

  Widget _targeting(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Hangi bölgelerde görünmek istersin?',
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        const Text(
            'Tercihin bu işletmeye kaydedilir. Farklı hesapların kendi bölgeleri olur.'),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
            initialValue: locationMode,
            decoration: const InputDecoration(labelText: 'Lokasyon seçimi'),
            items: const [
              DropdownMenuItem(value: 'COUNTRY', child: Text('Türkiye geneli')),
              DropdownMenuItem(value: 'CITY', child: Text('İl seç')),
              DropdownMenuItem(value: 'REGION', child: Text('Bölge seç'))
            ],
            onChanged: (value) => setState(() {
                  locationMode = value ?? 'COUNTRY';
                  locations.clear();
                })),
        if (locationMode != 'COUNTRY') ...[
          const SizedBox(height: 16),
          Text('${locations.length} seçim',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 12),
          Wrap(
              spacing: 8,
              runSpacing: 8,
              children: (locationMode == 'CITY' ? cities : regions)
                  .map((label) => FilterChip(
                      label: Text(label),
                      selected: locations.contains(label),
                      onSelected: (selected) => setState(() {
                            if (selected)
                              locations.add(label);
                            else
                              locations.remove(label);
                          })))
                  .toList()),
        ],
      ]);
}
