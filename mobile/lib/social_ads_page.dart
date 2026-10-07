import 'package:flutter/material.dart';
import 'dart:math';

import 'api.dart';
import 'app_error.dart';
import 'product_ui.dart';

class SocialAdsPage extends StatefulWidget {
  final String? initialMediaId;
  const SocialAdsPage({super.key, this.initialMediaId});

  @override
  State<SocialAdsPage> createState() => _SocialAdsPageState();
}

class _SocialAdsPageState extends State<SocialAdsPage> {
  List<dynamic> media = [];
  Map<String, dynamic>? selected;
  List<String> availableCities = [];
  List<String> availableRegions = [];
  String locationMode = 'COUNTRY';
  Set<String> selectedLocations = {};
  bool loading = true;
  bool creating = false;
  String? error;
  int _step = 0;
  bool strategyLoading = false;
  bool canOperate = false;
  Map<String, dynamic>? strategyReport;
  String? _adRequestId;
  bool _created = false;
  String? _adFailure;
  String _accountScope = '';
  bool _preflightLoading = false;
  String? _preflightMessage;

  final campaignName =
      TextEditingController(text: 'WhatsApp müşteri kampanyası');
  final adSetName = TextEditingController(text: 'WhatsApp hedef kitle');
  final adName = TextEditingController(text: 'AdVise AI Instagram Reklamı');
  final budget = TextEditingController(text: '150');
  bool activateAd = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    campaignName.dispose();
    adSetName.dispose();
    adName.dispose();
    budget.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final x = await Api.instagramMedia(limit: 50);
      final me = await Api.me();
      if (!mounted) return;
      _accountScope =
          '${(me['tenant'] as Map?)?['id'] ?? ''}:${(me['user'] as Map?)?['id'] ?? ''}';
      canOperate = ['ADMIN', 'CUSTOMER_ADMIN', 'MANAGER', 'OPERATOR']
          .contains((me['user'] as Map?)?['role']);
      Map<String, dynamic> targeting = {};
      try {
        targeting = await Api.adTargetingOptions();
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        media = x;
        if (widget.initialMediaId != null && selected == null) {
          for (final item in media.whereType<Map>()) {
            if (item['id']?.toString() == widget.initialMediaId) {
              selected = Map<String, dynamic>.from(item);
              _step = 2;
              break;
            }
          }
        }
        availableCities = List<String>.from(targeting['cities'] ?? const []);
        availableRegions = List<String>.from(targeting['regions'] ?? const []);
        locationMode = targeting['mode']?.toString() ?? 'COUNTRY';
        selectedLocations =
            Set<String>.from(targeting['locations'] ?? const []);
        loading = false;
        if (selected != null &&
            !media.any((m) =>
                m is Map &&
                m['id']?.toString() == selected!['id']?.toString())) {
          selected = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = AppError.message(e);
        });
      }
    }
  }

  String get _targetingSummary {
    if (locationMode == 'COUNTRY') return 'Türkiye geneli';
    final values = selectedLocations.toList()..sort();
    final kind = locationMode == 'REGION' ? 'bölge' : 'il';
    if (values.isEmpty) return 'Hedef $kind seçilmedi';
    if (values.length <= 3) return values.join(' • ');
    return '${values.take(3).join(' • ')} ve ${values.length - 3} $kind daha';
  }

  Future<void> _chooseTargeting() async {
    if (!canOperate || creating) return;
    var mode = locationMode;
    final chosen = Set<String>.from(selectedLocations);
    final search = TextEditingController();
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          final options = mode == 'REGION' ? availableRegions : availableCities;
          final query = search.text.trim().toLowerCase();
          final visible = options
              .where((name) => name.toLowerCase().contains(query))
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.of(sheetContext).size.height * .88,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 16, 8),
                    child: Row(children: [
                      const Expanded(
                          child: Text('Reklam hedefi',
                              style: TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w900))),
                      IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded)),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: DropdownButtonFormField<String>(
                      initialValue: mode,
                      decoration:
                          const InputDecoration(labelText: 'Hedefleme türü'),
                      items: const [
                        DropdownMenuItem(
                            value: 'COUNTRY', child: Text('Türkiye geneli')),
                        DropdownMenuItem(value: 'CITY', child: Text('İl seç')),
                        DropdownMenuItem(
                            value: 'REGION', child: Text('Bölge seç')),
                      ],
                      onChanged: (value) => setSheetState(() {
                        mode = value ?? 'COUNTRY';
                        chosen.clear();
                        search.clear();
                      }),
                    ),
                  ),
                  if (mode != 'COUNTRY') ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 6),
                      child: TextField(
                        controller: search,
                        onChanged: (_) => setSheetState(() {}),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.search_rounded),
                          hintText: mode == 'REGION' ? 'Bölge ara' : 'İl ara',
                          suffixIcon: search.text.isEmpty
                              ? null
                              : IconButton(
                                  onPressed: () {
                                    search.clear();
                                    setSheetState(() {});
                                  },
                                  icon: const Icon(Icons.close_rounded)),
                        ),
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: visible.length,
                        itemBuilder: (_, index) {
                          final name = visible[index];
                          return CheckboxListTile(
                            value: chosen.contains(name),
                            title: Text(name),
                            onChanged: (value) => setSheetState(() {
                              if (value == true)
                                chosen.add(name);
                              else
                                chosen.remove(name);
                            }),
                          );
                        },
                      ),
                    ),
                  ] else
                    const Expanded(
                      child: Center(
                          child: Padding(
                              padding: EdgeInsets.all(28),
                              child: Text(
                                  'Reklam Türkiye genelinde gösterilir.',
                                  textAlign: TextAlign.center))),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton(
                        onPressed: mode != 'COUNTRY' && chosen.isEmpty
                            ? null
                            : () => Navigator.pop(sheetContext,
                                {'mode': mode, 'locations': chosen.toList()}),
                        child: const Text('HEDEFİ KULLAN'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    search.dispose();
    if (result != null && mounted) {
      final nextMode = result['mode']?.toString() ?? 'COUNTRY';
      final nextLocations = Set<String>.from(result['locations'] ?? const []);
      setState(() {
        locationMode = nextMode;
        selectedLocations = nextLocations;
      });
      try {
        await Api.saveAdTargetingPreferences(
            mode: nextMode, locations: nextLocations.toList());
      } catch (e) {
        if (mounted)
          _snack(
              'Seçim bu kampanyada kullanılacak. İşletme tercihi kaydedilemedi: ${AppError.message(e)}');
      }
    }
  }

  Future<void> _createAd() async {
    if (!canOperate || creating || _created) return;
    final post = selected;
    if (post == null) {
      _snack('Önce reklam vereceğin Instagram gönderisini seç.');
      return;
    }
    final dailyBudget = double.tryParse(budget.text.replaceAll(',', '.'));
    if (dailyBudget == null || dailyBudget < 50) {
      _snack('Günlük bütçe en az 50 TL olmalı.');
      return;
    }

    setState(() => creating = true);
    _adRequestId ??= List.generate(
            24,
            (_) =>
                Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0'))
        .join();
    try {
      _adRequestId = await Api.stableAdRequestId(
          _accountScope,
          {
            'media': post['id'],
            'budget': dailyBudget,
            'campaign': campaignName.text.trim(),
            'adset': adSetName.text.trim(),
            'ad': adName.text.trim(),
            'activate': activateAd,
            'mode': locationMode,
            'locations': selectedLocations.toList()..sort(),
          },
          _adRequestId!);
      if (!mounted) return;
      // A resumed request checks provider prerequisites again on the server.
      // Keeping the same key across UI retries prevents duplicate remote writes.
      final result = await Api.createAdFromInstagramPost(
        requestId: _adRequestId!,
        instagramMediaId: post['id'].toString(),
        campaignName: campaignName.text.trim(),
        adSetName: adSetName.text.trim(),
        adName: adName.text.trim(),
        dailyBudget: dailyBudget,
        activate: activateAd,
        locationMode: locationMode,
        locations: selectedLocations.toList(),
      );
      if (!mounted) return;
      setState(() {
        creating = false;
        _created = true;
      });
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reklam oluşturuldu'),
          content: SelectableText(
            '${campaignName.text}\n'
            'Durum: ${result['activated'] == true ? 'Aktif' : 'Durduruldu'}\n'
            'Mesaj kanalı: WhatsApp\n'
            'Hedef: ${result['targeting']?['locations'] is List ? (result['targeting']['locations'] as List).join(', ') : _targetingSummary}',
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('TAMAM'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _adFailure = AppError.message(e));
        _snack(_adFailure!);
      }
    } finally {
      if (mounted) setState(() => creating = false);
    }
  }

  void _snack(String value) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(value), behavior: SnackBarBehavior.floating),
    );
  }

  String _mediaType(Map<String, dynamic> item) {
    final type = item['media_type']?.toString().toUpperCase() ?? 'MEDIA';
    if (type == 'VIDEO') return 'REELS / VİDEO';
    if (type == 'CAROUSEL_ALBUM') return 'CAROUSEL';
    return 'GÖNDERİ';
  }

  String _date(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '-';
    final d = date.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _preview(Map<String, dynamic> item, {double height = 210}) {
    final type = item['media_type']?.toString().toUpperCase() ?? '';
    final url = (type == 'VIDEO' ? item['thumbnail_url'] : item['media_url'])
            ?.toString() ??
        '';
    if (!url.startsWith('http')) {
      return Container(
        height: height,
        alignment: Alignment.center,
        color: const Color(0xFFF0F1F6),
        child: Icon(
            type == 'VIDEO'
                ? Icons.video_library_outlined
                : Icons.photo_outlined,
            size: 64),
      );
    }
    return Image.network(
      url,
      height: height,
      width: double.infinity,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => Container(
        height: height,
        alignment: Alignment.center,
        color: const Color(0xFFF0F1F6),
        child: const Icon(Icons.broken_image_outlined, size: 52),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Yeni WhatsApp reklamı'), actions: [
          IconButton(
              tooltip: 'Gönderileri yenile',
              onPressed: loading || creating ? null : _load,
              icon: const Icon(Icons.refresh))
        ]),
        body: ProductContent(
            child: loading
                ? const ProductLoadingSkeleton()
                : error != null
                    ? ProductErrorState(message: error!, onRetry: _load)
                    : LayoutBuilder(
                        builder: (ctx, size) => Stepper(
                              type: size.maxWidth >= 900
                                  ? StepperType.horizontal
                                  : StepperType.vertical,
                              currentStep: _step,
                              onStepTapped: creating
                                  ? null
                                  : (i) => setState(() => _step = i),
                              onStepContinue: creating ||
                                      !canOperate ||
                                      _created
                                  ? null
                                  : () {
                                      if (_step == 1 && selected == null) {
                                        _snack('Reklam için bir gönderi seç.');
                                        return;
                                      }
                                      if (_step == 2 &&
                                          (double.tryParse(budget.text
                                                      .replaceAll(',', '.')) ??
                                                  0) <
                                              50) {
                                        _snack(
                                            'Günlük bütçe en az 50 TL olmalı.');
                                        return;
                                      }
                                      if (_step < 4) {
                                        setState(() => _step++);
                                      } else {
                                        _confirmCampaign();
                                      }
                                    },
                              onStepCancel: creating || _step == 0
                                  ? null
                                  : () => setState(() => _step--),
                              controlsBuilder: (ctx, details) => Padding(
                                  padding: const EdgeInsets.only(top: 20),
                                  child: Wrap(
                                      spacing: 12,
                                      runSpacing: 8,
                                      children: [
                                        if (_adRequestId != null)
                                          OutlinedButton.icon(
                                            onPressed: creating
                                                ? null
                                                : () async {
                                                    try {
                                                      final operation =
                                                          await Api.adOperation(
                                                              _adRequestId!);
                                                      if (!mounted) return;
                                                      if (operation['status'] ==
                                                          'SUCCEEDED') {
                                                        setState(() {
                                                          _created = true;
                                                          _adFailure = null;
                                                        });
                                                        _snack(
                                                            'Reklam oluşturuldu.');
                                                      } else {
                                                        _snack(operation[
                                                                    'status'] ==
                                                                'RECONCILE'
                                                            ? 'Meta sonucu belirsiz. Yeni reklam oluşturmadan önce Meta kayıtlarını kontrol edin.'
                                                            : 'İşlem durumu: ${operation['status']}');
                                                      }
                                                    } catch (e) {
                                                      if (mounted)
                                                        _snack(AppError.message(
                                                            e));
                                                    }
                                                  },
                                            icon: const Icon(Icons.sync),
                                            label: const Text(
                                                'İşlem durumunu kontrol et'),
                                          ),
                                        if (_adFailure != null)
                                          Text(_adFailure!),
                                        FilledButton.icon(
                                            onPressed: details.onStepContinue,
                                            icon: Icon(_step == 4
                                                ? Icons.check
                                                : Icons.arrow_forward),
                                            label: Text(_created
                                                ? 'Reklam oluşturuldu'
                                                : creating
                                                    ? 'Oluşturuluyor…'
                                                    : _step == 4
                                                        ? activateAd
                                                            ? 'Onayla ve yayınla'
                                                            : 'Onayla ve reklamı oluştur'
                                                        : 'Devam et')),
                                        if (_step > 0)
                                          TextButton(
                                              onPressed: details.onStepCancel,
                                              child: const Text('Geri'))
                                      ])),
                              steps: [
                                Step(
                                    title: const Text('Amaç'),
                                    isActive: _step >= 0,
                                    content: const ProductInsightCard(
                                        title:
                                            'WhatsApp üzerinden müşteri kazan',
                                        body:
                                            'İnsanları işletmenin WhatsApp görüşmesine yönlendir. Reklam hesabı, Facebook Sayfası ve WhatsApp Business bağlantısı hazır olmalı.',
                                        icon: Icons.chat_outlined)),
                                Step(
                                    title: const Text('İçerik'),
                                    isActive: _step >= 1,
                                    content: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                              'Yayınlanmış Instagram gönderilerinden birini seç.'),
                                          const SizedBox(height: 14),
                                          if (media.isEmpty)
                                            const ProductEmptyState(
                                                title: 'Gönderi bulunamadı',
                                                body:
                                                    'Önce AI Studio’dan içerik yayınla veya Meta bağlantısını kontrol et.',
                                                icon: Icons
                                                    .photo_library_outlined),
                                          SizedBox(
                                              height: media.isEmpty ? 0 : 400,
                                              child: GridView.builder(
                                                  gridDelegate:
                                                      SliverGridDelegateWithFixedCrossAxisCount(
                                                          crossAxisCount: size
                                                                      .maxWidth >=
                                                                  850
                                                              ? 3
                                                              : size.maxWidth >=
                                                                      520
                                                                  ? 2
                                                                  : 1,
                                                          mainAxisExtent: 260,
                                                          crossAxisSpacing: 12,
                                                          mainAxisSpacing: 12),
                                                  itemCount: media.length,
                                                  itemBuilder: (_, i) {
                                                    final m = Map<String,
                                                            dynamic>.from(
                                                        media[i] as Map);
                                                    final chosen =
                                                        selected?['id'] ==
                                                            m['id'];
                                                    return Card(
                                                        clipBehavior:
                                                            Clip.antiAlias,
                                                        child: InkWell(
                                                            onTap: creating
                                                                ? null
                                                                : () => setState(
                                                                    () =>
                                                                        selected =
                                                                            m),
                                                            child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  _preview(m,
                                                                      height:
                                                                          155),
                                                                  Padding(
                                                                      padding: const EdgeInsets
                                                                          .all(
                                                                          12),
                                                                      child: Column(
                                                                          crossAxisAlignment:
                                                                              CrossAxisAlignment.start,
                                                                          children: [
                                                                            Text(m['caption']?.toString() ?? 'Instagram gönderisi',
                                                                                maxLines: 2,
                                                                                overflow: TextOverflow.ellipsis),
                                                                            const SizedBox(height: 8),
                                                                            ProductStatusChip(
                                                                                label: chosen ? 'Seçildi' : _mediaType(m),
                                                                                tone: chosen ? 'success' : 'neutral')
                                                                          ]))
                                                                ])));
                                                  })),
                                        ])),
                                Step(
                                    title: const Text('Bütçe ve bölge'),
                                    isActive: _step >= 2,
                                    content: Column(children: [
                                      TextField(
                                          controller: budget,
                                          keyboardType: const TextInputType
                                              .numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                              labelText: 'Günlük bütçe (TL)',
                                              prefixText: '₺ ',
                                              helperText:
                                                  'Günlük harcama planı. Meta maliyetleri ayrıca uygulanır.')),
                                      const SizedBox(height: 16),
                                      ProductSurface(
                                          child: ListTile(
                                              contentPadding: EdgeInsets.zero,
                                              leading: const Icon(
                                                  Icons.location_on_outlined),
                                              title: const Text(
                                                  'Gösterim bölgesi'),
                                              subtitle: Text(_targetingSummary),
                                              trailing: const Icon(
                                                  Icons.edit_outlined),
                                              onTap: creating || !canOperate
                                                  ? null
                                                  : _chooseTargeting)),
                                      const SizedBox(height: 16),
                                      const ProductInsightCard(
                                          title:
                                              'Hedef kitleyi nasıl seçiyoruz?',
                                          body:
                                              'Seçtiğin il veya bölgeler bu kampanyanın konum hedefini oluşturur. Gemini içerik önerilerinde kaydettiğin bu tercihi dikkate alır; gösterim sonuçları Meta tarafından belirlenir.',
                                          icon: Icons.psychology_outlined),
                                      ExpansionTile(
                                          title:
                                              const Text('Gelişmiş adlandırma'),
                                          children: [
                                            TextField(
                                                controller: campaignName,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText:
                                                            'Kampanya adı')),
                                            const SizedBox(height: 12),
                                            TextField(
                                                controller: adSetName,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText:
                                                            'Reklam grubu adı')),
                                            const SizedBox(height: 12),
                                            TextField(
                                                controller: adName,
                                                decoration:
                                                    const InputDecoration(
                                                        labelText:
                                                            'Reklam adı'))
                                          ]),
                                    ])),
                                Step(
                                    title: const Text('AI önerisi'),
                                    isActive: _step >= 3,
                                    content: _strategyCard()),
                                Step(
                                    title: const Text('Önizle ve onayla'),
                                    isActive: _step >= 4,
                                    content: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          if (selected != null)
                                            ClipRRect(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                child: _preview(selected!,
                                                    height: 230)),
                                          const SizedBox(height: 14),
                                          Text(selected?['caption']
                                                  ?.toString() ??
                                              'Gönderi seçilmedi'),
                                          const SizedBox(height: 14),
                                          ProductSurface(
                                              child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                Text(
                                                    'Hedef: WhatsApp görüşmesi',
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .titleMedium),
                                                const SizedBox(height: 8),
                                                Text(
                                                    'Günlük bütçe: ₺${budget.text}'),
                                                Text(
                                                    'Bölge: $_targetingSummary')
                                              ])),
                                          const SizedBox(height: 12),
                                          SwitchListTile.adaptive(
                                              contentPadding: EdgeInsets.zero,
                                              title: const Text(
                                                  'Onay sonrası hemen aktif et'),
                                              subtitle: const Text(
                                                  'Kapalıysa reklam durdurulmuş durumda oluşturulur.'),
                                              value: activateAd,
                                              onChanged: creating || !canOperate
                                                  ? null
                                                  : (v) => setState(
                                                      () => activateAd = v)),
                                        ])),
                              ],
                            ))),
      );

  Future<void> _confirmCampaign() async {
    if (!canOperate || creating) return;
    if (selected == null) {
      _snack('Önce bir Instagram gönderisi seç.');
      return;
    }
    final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Reklamı onayla'),
                content: Text(
                    "Günlük ₺${budget.text} bütçe ile $_targetingSummary hedefinde WhatsApp reklamı oluşturulacak.${activateAd ? ' Reklam hemen aktif edilecek.' : ' Reklam durdurulmuş durumda kalacak.'}"),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Vazgeç')),
                  FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Onayla'))
                ]));
    if (accepted == true && mounted) await _createAd();
  }

  Future<void> _requestStrategy() async {
    if (!canOperate || creating || strategyLoading) return;
    if (selected == null) {
      _snack('Önce reklam için bir gönderi seç.');
      return;
    }
    setState(() {
      strategyLoading = true;
      strategyReport = null;
    });
    try {
      final response = await Api.productStrategy({
        'instagramMediaId': selected!['id'],
        'title': selected!['caption']?.toString() ?? campaignName.text,
        'dailyBudget': double.tryParse(budget.text.replaceAll(',', '.')) ?? 0,
        'locationMode': locationMode,
        'locations': selectedLocations.toList(),
      });
      if (mounted) setState(() => strategyReport = response);
    } catch (e) {
      if (mounted)
        setState(() => strategyReport = {
              'available': false,
              'error': AppError.message(e)
            });
    } finally {
      if (mounted) setState(() => strategyLoading = false);
    }
  }

  Future<void> _checkMeta() async {
    if (_preflightLoading || creating || !canOperate) return;
    setState(() {
      _preflightLoading = true;
      _preflightMessage = null;
    });
    try {
      final result = await Api.adsPreflight();
      if (mounted)
        setState(() => _preflightMessage = result['ok'] == true
            ? 'Meta bağlantıları doğrulandı. ${result['currency']} · ${result['timezone']} · WhatsApp'
            : 'Meta bağlantısı doğrulanamadı.');
    } catch (error) {
      if (mounted) setState(() => _preflightMessage = AppError.message(error));
    } finally {
      if (mounted) setState(() => _preflightLoading = false);
    }
  }

  Widget _strategyCard() {
    final raw = strategyReport?['strategy'];
    final strategy =
        raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    final available =
        strategyReport?['available'] == true && strategy.isNotEmpty;
    final audience =
        strategy['audience'] is Map ? strategy['audience'] as Map : {};
    final planBudget =
        strategy['budget'] is Map ? strategy['budget'] as Map : {};
    final creative =
        strategy['creative'] is Map ? strategy['creative'] as Map : {};
    final schedule =
        strategy['schedule'] is Map ? strategy['schedule'] as Map : {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      OutlinedButton.icon(
          onPressed:
              _preflightLoading || creating || !canOperate ? null : _checkMeta,
          icon: const Icon(Icons.verified_user_outlined),
          label: Text(_preflightLoading
              ? 'Bağlantı kontrol ediliyor…'
              : 'Meta bağlantısını kontrol et')),
      if (_preflightMessage != null)
        Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(_preflightMessage!)),
      const ProductInsightCard(
          title: 'Bir test planı hazırlayalım',
          body:
              'Gemini işletme bilgilerini, seçtiğin içeriği, gerçek performansı ve Hafıza Sarayı’nı birlikte değerlendirir. Bu adım reklam oluşturmaz.',
          icon: Icons.auto_awesome),
      const SizedBox(height: 16),
      FilledButton.tonalIcon(
          onPressed: strategyLoading || creating || !canOperate
              ? null
              : _requestStrategy,
          icon: const Icon(Icons.psychology_outlined),
          label: Text(strategyLoading
              ? 'Strateji hazırlanıyor…'
              : 'AI kampanya önerisi al')),
      if (strategyReport != null) ...[
        const SizedBox(height: 16),
        if (!available)
          ProductErrorState(
              message: AppError.message(strategyReport!['error'] ??
                  'AI önerisi şu anda hazırlanamadı.'),
              onRetry: strategyLoading || !canOperate ? null : _requestStrategy)
        else
          ProductSurface(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const ProductStatusChip(
                    label: 'Gemini önerisi · Onay bekliyor', tone: 'ai'),
                const SizedBox(height: 16),
                Text('${strategy['goal'] ?? 'WhatsApp mesajları'}',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(
                    'Hedef kitle: ${audience['description'] ?? _targetingSummary}'),
                Text(
                    'Test bütçesi: ${planBudget['dailyBudget'] ?? budget.text} TL / gün'),
                Text(
                    'İçerik: ${creative['format'] ?? 'Gönderi'} · ${creative['angle'] ?? ''}'),
                if (strategy['hook'] != null)
                  Text('Açılış: ${strategy['hook']}'),
                Text(
                    'Önerilen saat: ${schedule['recommendedTime'] ?? '—'} · Türkiye saati'),
                if (schedule['reason'] != null) Text('${schedule['reason']}'),
                Text(
                    'İlk değerlendirme: ${strategy['testDurationDays'] ?? '—'} günlük test'),
                const SizedBox(height: 12),
                for (final reason in (strategy['reasons'] is List
                    ? strategy['reasons'] as List
                    : []))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('• $reason')),
                for (final warning in (strategy['warnings'] is List
                    ? strategy['warnings'] as List
                    : []))
                  Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('Not: $warning')),
                const SizedBox(height: 12),
                const Text(
                    'Öneri harcama veya sonuç garantisi değildir. Bütçe ve bölge seçimlerini kontrol edip sonraki adımda açıkça onayla.'),
              ])),
      ],
    ]);
  }
}
