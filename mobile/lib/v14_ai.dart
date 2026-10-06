import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'api.dart';
import 'content_queue_page.dart';
import 'media_access.dart';
import 'app_error.dart';
import 'product_ui.dart';
import 'product_shell.dart';
import 'social_ads_page.dart';

class AiContentStudioPage extends StatefulWidget {
  final Future<XFile?> Function()? mediaPicker;
  final Future<DateTime?> Function()? schedulePicker;
  const AiContentStudioPage({super.key, this.mediaPicker, this.schedulePicker});

  @override
  State<AiContentStudioPage> createState() => _AiContentStudioPageState();
}

class _AiContentStudioPageState extends State<AiContentStudioPage> {
  final title = TextEditingController();
  final contextText = TextEditingController();
  final captionDraft = TextEditingController();

  String tone = '';
  String goal = '';
  String media = 'AUTO';

  bool loading = false;
  bool variantsLoading = false;
  bool scoreLoading = false;
  bool draftSaving = false;
  bool _publishPending = false;
  bool _canOperate = false, _accessLoaded = false, _accessStarted = false;
  bool _statusLoading = true, _memoryLoading = true;
  String? _statusError, _memoryError;
  String? savedPostId;
  DateTime? selectedScheduleTime;

  XFile? image;
  Map<String, dynamic>? result;
  List<dynamic> variants = [];
  Map<String, dynamic> score = {};
  Map<String, dynamic> aiStatus = {};
  Map<String, dynamic> memory = {};

  @override
  void initState() {
    super.initState();
    _loadAiStatus();
    _loadMemory();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navigation = ProductNavigation.maybeOf(context);
    if (navigation != null) {
      _canOperate = navigation.canOperate;
      _accessLoaded = true;
    } else if (!_accessStarted) {
      _accessStarted = true;
      _loadAccess();
    }
  }

  Future<void> _loadAccess() async {
    try {
      final me = await Api.me();
      if (mounted)
        setState(() {
          _canOperate = ['ADMIN', 'CUSTOMER_ADMIN', 'MANAGER', 'OPERATOR']
              .contains((me['user'] as Map?)?['role']);
          _accessLoaded = true;
        });
    } catch (_) {
      if (mounted) setState(() => _accessLoaded = true);
    }
  }

  @override
  void dispose() {
    title.dispose();
    contextText.dispose();
    captionDraft.dispose();
    super.dispose();
  }

  Future<void> _loadAiStatus() async {
    if (mounted)
      setState(() {
        _statusLoading = true;
        _statusError = null;
      });
    try {
      final data = await Api.aiStatus();
      if (mounted) setState(() => aiStatus = data);
    } catch (e) {
      if (mounted) setState(() => _statusError = AppError.message(e));
    } finally {
      if (mounted) setState(() => _statusLoading = false);
    }
  }

  Future<void> _loadMemory() async {
    try {
      final data = await Api.aiMemory();
      if (mounted) setState(() => memory = data);
    } catch (e) {
      if (mounted) setState(() => _memoryError = AppError.message(e));
    } finally {
      if (mounted) setState(() => _memoryLoading = false);
    }
  }

  Future<void> _pickMedia() async {
    if (!_canOperate || loading || draftSaving) return;
    final picked = await (widget.mediaPicker ?? MediaAccess.pickOne)();
    if (picked == null || !mounted) return;

    setState(() {
      image = picked;
      result = null;
      variants = [];
      score = {};
      savedPostId = null;
      _publishPending = false;
    });
  }

  bool _selectedMediaIsImage() {
    final name = image?.name.toLowerCase() ?? '';
    return [
      '.jpg',
      '.jpeg',
      '.jfif',
      '.png',
      '.webp',
      '.gif',
      '.bmp',
      '.heic',
      '.heif',
      '.avif',
      '.tif',
      '.tiff'
    ].any(name.endsWith);
  }

  Future<void> _generate() async {
    if (!_canOperate || loading || draftSaving || _publishPending) return;
    if (image == null && title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Önce bir görsel/video seç veya ürün başlığı gir.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final data = image != null
          ? await Api.generateContentPackFromFile(
              image!.path,
              mediaFile: image,
              title: title.text,
              context: contextText.text,
              tone: tone,
              goal: goal,
              mediaType: media,
            )
          : await Api.generateContentPack(
              title: title.text,
              context: contextText.text,
              tone: tone,
              goal: goal,
              mediaType: media,
            );

      if (!mounted) return;
      final generatedTitle = data['productName']?.toString() ?? '';
      if (title.text.trim().isEmpty && generatedTitle.isNotEmpty)
        title.text = generatedTitle;
      captionDraft.text = [
        data['hook']?.toString() ?? '',
        data['caption']?.toString() ?? '',
        data['cta']?.toString() ?? '',
        data['hashtags'] is List ? (data['hashtags'] as List).join(' ') : '',
      ].where((part) => part.trim().isNotEmpty).join('\n\n');
      setState(() => result = data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            data['source'] != 'GEMINI'
                ? 'Yerel içerik önerisi hazırlandı. Medya analizi doğrulanamadı.'
                : image != null
                    ? 'Medya analizi ve içerik paketi hazırlandı.'
                    : 'İçerik paketi hazırlandı.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _generateVariants() async {
    if (!_canOperate || variantsLoading || draftSaving) return;
    if (title.text.trim().isEmpty && result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir içerik üret.')),
      );
      return;
    }

    setState(() => variantsLoading = true);

    try {
      final data = await Api.generateCaptionVariants(
        title: result?['productName']?.toString() ?? title.text,
        context: [
          contextText.text,
          result?['detectedText']?.toString() ?? '',
          result?['detectedOffer']?.toString() ?? '',
          result?['contentAngle']?.toString() ?? '',
        ].where((x) => x.trim().isNotEmpty).join(' | '),
        tone: result?['selectedTone']?.toString() ?? tone,
        goal: result?['contentGoal']?.toString() ?? goal,
        mediaType: result?['recommendedFormat']?.toString() ?? media,
      );

      if (!mounted) return;
      setState(() {
        variants = data['variants'] is List
            ? List<dynamic>.from(data['variants'])
            : [];
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => variantsLoading = false);
    }
  }

  void _applyVariant(Map<String, dynamic> variant) {
    captionDraft.text = [
      variant['hook']?.toString() ?? '',
      variant['caption']?.toString() ?? '',
      variant['cta']?.toString() ?? result?['cta']?.toString() ?? '',
      hashtagsFromResult,
    ].where((part) => part.trim().isNotEmpty).join('\n\n');
    setState(() {
      result = {
        ...?result,
        'hook': variant['hook'] ?? result?['hook'],
        'caption': variant['caption'] ?? result?['caption'],
        'cta': variant['cta'] ?? result?['cta']
      };
    });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Varyant taslağa uygulandı; metni düzenleyebilirsin.')));
  }

  Future<void> _previewDraft() async {
    if (result == null) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Gönderi önizlemesi'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (image != null && _selectedMediaIsImage())
                  ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: MediaPreview(
                          file: image!,
                          height: 220,
                          width: double.infinity,
                          fit: BoxFit.cover))
                else
                  Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF0F1F6),
                          borderRadius: BorderRadius.circular(14)),
                      child:
                          const Icon(Icons.video_library_outlined, size: 46)),
                const SizedBox(height: 12),
                Text(
                    title.text.trim().isEmpty
                        ? 'Yeni gönderi'
                        : title.text.trim(),
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                SelectableText(captionDraft.text.trim(),
                    style: const TextStyle(height: 1.5)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('KAPAT'))
        ],
      ),
    );
  }

  Future<void> _scoreCreative() async {
    if (!_canOperate || scoreLoading || draftSaving) return;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce AI içeriği üret.')),
      );
      return;
    }

    setState(() => scoreLoading = true);

    try {
      final data = await Api.scoreCreative(
        caption: result!['caption']?.toString() ?? '',
        hook: result!['hook']?.toString() ?? '',
        cta: result!['cta']?.toString() ?? '',
        hashtags: result!['hashtags'] is List
            ? List<dynamic>.from(result!['hashtags'])
            : const [],
        mediaType: result!['recommendedFormat']?.toString() ?? media,
      );

      if (!mounted) return;
      setState(() => score = Map<String, dynamic>.from(data));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppError.message(e))),
        );
      }
    } finally {
      if (mounted) setState(() => scoreLoading = false);
    }
  }

  void _copy(String label, String value) {
    Clipboard.setData(ClipboardData(text: value));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label panoya kopyalandı.')),
    );
  }

  String _packText(Map<String, dynamic> pack) {
    final tags =
        pack['hashtags'] is List ? (pack['hashtags'] as List).join(' ') : '';
    return [
      pack['productName'],
      'Hook: ${pack['hook'] ?? ''}',
      pack['caption'],
      'CTA: ${pack['cta'] ?? ''}',
      tags,
      'Format: ${pack['recommendedFormat'] ?? ''}',
      'Paylaşım zamanı: ${pack['recommendedPostTime'] ?? ''}',
      'Hedef kitle: ${pack['targetAudience'] ?? ''}',
      'İçerik açısı: ${pack['contentAngle'] ?? ''}',
      'Görsel analizi: ${pack['visualSummary'] ?? ''}',
    ]
        .where((part) => part != null && part.toString().trim().isNotEmpty)
        .join('\n\n');
  }

  Future<void> _saveAsDraft() async {
    if (!_canOperate || draftSaving || _publishPending) return;
    if (image == null || result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Taslak oluşturmak için önce medya seçip içerik üret.')),
      );
      return;
    }

    setState(() => draftSaving = true);
    try {
      await _storeDraft();
      await _loadMemory();
      if (!mounted) return;
      _clearCurrentDraft();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Taslak kaydedildi ve Hafıza Sarayı’na bağlandı.'),
        action: SnackBarAction(
            label: 'Kuyruğu aç',
            onPressed: () => Navigator.push(context,
                MaterialPageRoute(builder: (_) => const ContentQueuePage()))),
      ));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppError.message(e))));
      }
    } finally {
      if (mounted) setState(() => draftSaving = false);
    }
  }

  Future<Map<String, dynamic>> _storeDraft() async {
    if (savedPostId != null) {
      return Api.updatePost(savedPostId!,
          title: title.text.trim(),
          caption: captionDraft.text.trim(),
          linkUrl: '');
    }
    final saved = await Api.uploadPost(
      image!.path,
      title.text.trim().isNotEmpty
          ? title.text.trim()
          : result!['productName']?.toString() ?? 'Yeni içerik',
      captionDraft.text.trim(),
      '',
      mediaFile: image,
      autoPublish: false,
      useAI: false,
      mediaType: _selectedMediaIsImage() ? 'IMAGE' : 'VIDEO',
      memoryGenerationId: result!['memoryGenerationId']?.toString() ?? '',
    );
    savedPostId = saved['id']?.toString();
    if (savedPostId == null || savedPostId!.isEmpty)
      throw const ApiException('İçerik kaydı doğrulanamadı.');
    return saved;
  }

  Future<void> _publishNow({bool openAd = false}) async {
    if (!_canOperate || draftSaving || _publishPending) return;
    if (image == null || result == null) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
              title: Text(openAd
                  ? 'İçeriği reklam için yayınla'
                  : 'Şimdi Instagram’da yayınla'),
              content: Text(openAd
                  ? 'Mevcut reklam akışı yayınlanmış Instagram gönderilerini kullanır. Önce içeriğin yayınlanacak, ardından bütçe ve bölge seçip reklamı ayrıca onaylayacaksın.'
                  : 'Önizlediğin içerik bağlı Instagram hesabında hemen yayınlanacak.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Vazgeç')),
                FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('İçeriği yayınla'))
              ],
            ));
    if (accepted != true || !mounted) return;
    setState(() => draftSaving = true);
    try {
      await _storeDraft();
      if (mounted) setState(() => _publishPending = true);
      final published = await Api.publishPost(savedPostId!);
      if (!mounted) return;
      if (published['publishStatus'] != 'PUBLISHED') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Instagram sonucu kontrol ediliyor. İçeriğin yeniden gönderilmesi bekletiliyor.')));
        return;
      }
      final mediaId = (published['instagramMediaId'] ??
              published['instagramPostId'] ??
              published['publishedMediaId'])
          ?.toString();
      _clearCurrentDraft();
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İçerik Instagram’da yayınlandı.')));
      if (openAd)
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => SocialAdsPage(initialMediaId: mediaId)));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppError.message(e))));
    } finally {
      if (mounted) setState(() => draftSaving = false);
    }
  }

  DateTime _recommendedSlot() {
    final now = DateTime.now();
    final raw = result?['recommendedPostTime']?.toString() ?? '';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(raw);
    final hour = match == null ? 19 : int.parse(match.group(1)!);
    final minute = match == null ? 30 : int.parse(match.group(2)!);
    var slot = DateTime(now.year, now.month, now.day, hour, minute);
    if (!slot.isAfter(now.add(const Duration(minutes: 2)))) {
      slot = slot.add(const Duration(days: 1));
    }
    return slot;
  }

  Future<DateTime?> _pickPublishTime() async {
    final now = DateTime.now();
    final initial = selectedScheduleTime ?? _recommendedSlot();
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 2),
      helpText: 'Yayın gününü seç',
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
      helpText: 'Yayın saatini seç',
    );
    if (time == null || !mounted) return null;
    final selected =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!selected.isAfter(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Yayın zamanı şu andan sonraki bir saat olmalı.')));
      return null;
    }
    setState(() => selectedScheduleTime = selected);
    return selected;
  }

  Future<void> _queueForPublish() async {
    if (!_canOperate || draftSaving || _publishPending) return;
    if (image == null || result == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Kuyruğa eklemek için önce medya seçip içerik üret.')));
      return;
    }
    final scheduleAt = await (widget.schedulePicker ?? _pickPublishTime)();
    if (scheduleAt == null || !mounted) return;
    setState(() => draftSaving = true);
    try {
      await _storeDraft();
      final queued = await Api.queuePost(savedPostId!,
          scheduleAt: scheduleAt.toUtc().toIso8601String());
      await _loadMemory();
      if (!mounted) return;
      final status = queued['publishStatus']?.toString().toUpperCase();
      final localTime =
          DateTime.tryParse(queued['nextPublishAt']?.toString() ?? '')
                  ?.toLocal() ??
              scheduleAt;
      _clearCurrentDraft();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(status == 'QUEUED'
            ? 'Kuyruğa alındı • ${_dateLabel(localTime)}’de otomatik paylaşılacak.'
            : 'Yayın için hazır • ${_dateLabel(localTime)}. Otomatik yayın ayarını açınca paylaşılacak.'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Kuyruğu aç',
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const ContentQueuePage())),
        ),
      ));
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(AppError.message(e))));
    } finally {
      if (mounted) setState(() => draftSaving = false);
    }
  }

  String _dateLabel(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

  void _clearCurrentDraft() {
    setState(() {
      image = null;
      result = null;
      variants = [];
      score = {};
      selectedScheduleTime = null;
      title.clear();
      contextText.clear();
      captionDraft.clear();
      savedPostId = null;
      _publishPending = false;
    });
  }

  String get hashtagsFromResult => result?['hashtags'] is List
      ? (result!['hashtags'] as List).join(' ')
      : '';

  Future<void> _openQueue() async {
    await Navigator.push(
        context, MaterialPageRoute(builder: (_) => const ContentQueuePage()));
  }

  Widget _section(String title, Widget child) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }

  Widget _resultBox(String label, String value) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w900))),
              if (value.trim().isNotEmpty)
                IconButton(
                  tooltip: 'Kopyala',
                  onPressed: () => _copy(label, value),
                  icon: const Icon(Icons.copy_outlined, size: 19),
                ),
            ],
          ),
          SelectableText(
            value.trim().isEmpty ? '-' : value.trim(),
            style: const TextStyle(height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final source = result?['source']?.toString() ?? '';
    final configured = aiStatus['configured'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI İçerik Stüdyosu',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openQueue,
            icon: const Icon(Icons.calendar_month_rounded, size: 19),
            label: const Text('Kuyruk'),
          ),
          IconButton(
            tooltip: 'AI durumunu yenile',
            onPressed: _loadAiStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ProductContent(
          child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 440),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                  offset: Offset(0, 14 * (1 - value)), child: child),
            ),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: configured
                      ? const [Color(0xFF202143), Color(0xFF4F48AE)]
                      : const [Color(0xFF39405A), Color(0xFF59627A)],
                ),
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(
                      color: Color(0x20352D86),
                      blurRadius: 20,
                      offset: Offset(0, 9))
                ],
              ),
              child: Row(children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                      color: const Color(0x223DE0B0),
                      borderRadius: BorderRadius.circular(14)),
                  child: Icon(
                      configured
                          ? Icons.auto_awesome_rounded
                          : Icons.cloud_off_outlined,
                      color: const Color(0xFFB8F5DE)),
                ),
                const SizedBox(width: 11),
                Expanded(
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                      Text('ADVISE AI STUDIO',
                          style: const TextStyle(
                              color: Color(0xFFB8F5DE),
                              fontSize: 10,
                              letterSpacing: 1.2,
                              fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      Text(
                          _memoryLoading
                              ? 'Öğrenme verisi yükleniyor…'
                              : _memoryError != null
                                  ? 'Öğrenme verisi alınamadı'
                                  : 'AdVise öğreniyor • ${memory['generationCount'] ?? 0} üretim',
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800)),
                      Text(
                          _statusLoading
                              ? 'AI durumu kontrol ediliyor…'
                              : _statusError != null
                                  ? 'AI bağlantısı doğrulanamadı. Yeniden kontrol et.'
                                  : configured
                                      ? 'AI bağlantısı tanımlı. Analiz sonucu ayrıca doğrulanır.'
                                      : 'AI bağlantısı kapalı. Yerel metin önerisi hazırlanabilir.',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: .76),
                              fontSize: 12)),
                    ])),
                IconButton(
                    color: Colors.white,
                    tooltip: 'Durumu yenile',
                    onPressed: _loadAiStatus,
                    icon: const Icon(Icons.refresh_rounded)),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (_accessLoaded && !_canOperate) ...[
            const ProductInsightCard(
                title: 'Görüntüleme yetkisi',
                body:
                    'AI üretimi, taslak kaydı ve yayınlama için işletme yöneticinden işlem yetkisi iste.',
                icon: Icons.lock_outline),
            const SizedBox(height: 12)
          ],
          if (_publishPending) ...[
            ProductInsightCard(
                title: 'Yayın sonucu doğrulanıyor',
                body:
                    'Aynı içerik iki kez paylaşılmasın diye taslak işlemleri bekletiliyor. Son durumu içerik planından kontrol edebilirsin.',
                icon: Icons.hourglass_empty_rounded,
                action: OutlinedButton(
                    onPressed: _openQueue,
                    child: const Text('İçerik planını aç'))),
            const SizedBox(height: 12)
          ],
          Wrap(spacing: 8, runSpacing: 8, children: [
            ProductStatusChip(
                label: '1 · Medya seç',
                tone: image != null ? 'success' : 'neutral'),
            ProductStatusChip(
                label: '2 · Analiz',
                tone: result != null ? 'success' : 'neutral'),
            ProductStatusChip(label: '3 · Düzenle'),
            ProductStatusChip(label: '4 · Yayınla / planla'),
          ]),
          const SizedBox(height: 16),
          _section(
            'İçerik kaynağı',
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: loading || draftSaving || !_canOperate
                        ? null
                        : _pickMedia,
                    icon: const Icon(Icons.perm_media_outlined),
                    label: Text(
                      image == null ? 'MEDYA SEÇ' : 'MEDYAYI DEĞİŞTİR',
                    ),
                  ),
                ),
                if (image != null) ...[
                  const SizedBox(height: 10),
                  if (_selectedMediaIsImage())
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: MediaPreview(
                        file: image!,
                        height: 230,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    )
                  else
                    Container(
                      height: 180,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.video_library_outlined, size: 56),
                          SizedBox(height: 10),
                          Text(
                            'Video seçildi',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          SizedBox(height: 4),
                          Text('Reels / video dosyası hazır'),
                        ],
                      ),
                    ),
                  const SizedBox(height: 7),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      image!.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                TextField(
                  controller: title,
                  readOnly: !_canOperate,
                  decoration: const InputDecoration(
                      labelText: 'Ürün veya gönderi başlığı (isteğe bağlı)',
                      prefixIcon: Icon(Icons.title_rounded)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            'Kreatif notu',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Görseli analiz edip metin, format ve paylaşım zamanı önereceğiz. Metni yayınlamadan önce düzenleyebilirsin.',
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contextText,
                  readOnly: !_canOperate,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'İsteğe bağlı not',
                    hintText: 'Örn. özellikle kampanyayı vurgula...',
                    prefixIcon: Icon(Icons.edit_note_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: loading ||
                            !_canOperate ||
                            draftSaving ||
                            _publishPending
                        ? null
                        : _generate,
                    icon: loading
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      loading
                          ? 'İçeriğin hazırlanıyor…'
                          : image != null
                              ? 'AI ile medyayı analiz et'
                              : 'AI ile içerik üret',
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (result != null) ...[
            const SizedBox(height: 12),
            _section(
              'İçerik taslağı',
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.movie_filter_outlined),
                      const SizedBox(width: 8),
                      const Expanded(
                          child: Text(
                        'Önerilen format',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      )),
                      Chip(
                        label: Text(
                          result!['recommendedFormat']?.toString() ?? '-',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (source.isNotEmpty)
                    ProductStatusChip(
                        label: source == 'GEMINI'
                            ? 'AI analizi tamamlandı'
                            : 'Yerel öneri • medya analizi doğrulanmadı',
                        tone: source == 'GEMINI' ? 'success' : 'warning'),
                  if ((result?['error']?.toString() ?? '').trim().isNotEmpty)
                    _resultBox(
                      'AI bağlantısı',
                      AppError.message(result!['error']),
                    ),
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: TextField(
                      controller: captionDraft,
                      readOnly: !_canOperate || _publishPending,
                      minLines: 5,
                      maxLines: 12,
                      maxLength: 2200,
                      decoration: const InputDecoration(
                        labelText: 'Yayın metni',
                        helperText:
                            'Metne dokunup istemediğin bölümü değiştir.',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded),
                    title: const Text('Önerilen paylaşım saati',
                        style: TextStyle(fontWeight: FontWeight.w800)),
                    subtitle: Text(selectedScheduleTime == null
                        ? '${result!['recommendedPostTime'] ?? '19:30'} önerisi  •  Türkiye saati'
                        : 'Seçilen: ${_dateLabel(selectedScheduleTime!)}  •  Türkiye saati'),
                  ),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color:
                            Theme.of(context).colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14)),
                    child: Row(children: [
                      const Icon(Icons.chat_outlined, size: 19),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text('Dönüş kanalı: WhatsApp',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)))
                    ]),
                  ),
                  const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _previewDraft,
                      icon: const Icon(Icons.preview_outlined),
                      label: const Text('Gönderi önizlemesi'),
                    ),
                  ),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Analiz ve strateji ayrıntıları'),
                    children: [
                      _resultBox('Görseldeki metin',
                          result!['detectedText']?.toString() ?? ''),
                      _resultBox('Görülen teklif',
                          result!['detectedOffer']?.toString() ?? ''),
                      _resultBox(
                          'Marka / model',
                          '${result!['brand'] ?? ''} ${result!['model'] ?? ''}'
                              .trim()),
                      _resultBox('Hook', result!['hook']?.toString() ?? ''),
                      _resultBox('Ton ve içerik açısı',
                          '${result!['selectedTone'] ?? ''} • ${result!['contentAngle'] ?? ''}'),
                      _resultBox('Hedef kitle',
                          result!['targetAudience']?.toString() ?? ''),
                      _resultBox('Reklam önerisi',
                          result!['adRecommendation']?.toString() ?? ''),
                      _resultBox('Görsel analizi',
                          result!['visualSummary']?.toString() ?? ''),
                      _resultBox(
                          'Zaman gerekçesi',
                          result!['recommendedPostTimeReason']?.toString() ??
                              ''),
                      _resultBox('Kreatif skoru',
                          result!['creativeScore']?.toString() ?? ''),
                      _resultBox(
                          'AI güveni', result!['confidence']?.toString() ?? ''),
                    ],
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              variantsLoading || !_canOperate || _publishPending
                                  ? null
                                  : _generateVariants,
                          icon: variantsLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.copy_all_outlined),
                          label: const Text('3 VARYANT'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed:
                              scoreLoading || !_canOperate || _publishPending
                                  ? null
                                  : _scoreCreative,
                          icon: scoreLoading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.analytics_outlined),
                          label: const Text('PUANLA'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _copy('İçerik paketi', _packText(result!)),
                      icon: const Icon(Icons.content_copy_rounded),
                      label: const Text('İçerik paketini kopyala'),
                    ),
                  ),
                  if (image != null && _canOperate) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: [
                      OutlinedButton.icon(
                          onPressed: draftSaving || _publishPending
                              ? null
                              : () => _publishNow(),
                          icon: const Icon(Icons.send_outlined),
                          label: const Text('Şimdi yayınla')),
                      OutlinedButton.icon(
                          onPressed: draftSaving || _publishPending
                              ? null
                              : () => _publishNow(openAd: true),
                          icon: const Icon(Icons.campaign_outlined),
                          label: const Text('Reklama dönüştür')),
                    ]),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: draftSaving || _publishPending
                            ? null
                            : _queueForPublish,
                        icon: draftSaving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.schedule_send_rounded),
                        label: Text(draftSaving
                            ? 'YAYIN PLANI HAZIRLANIYOR…'
                            : 'Saat seç • Kuyruğa al'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: draftSaving || _publishPending
                            ? null
                            : _saveAsDraft,
                        icon: const Icon(Icons.bookmark_add_outlined),
                        label: const Text('Taslak kaydet • Hafızaya bağla'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
          if (variants.isNotEmpty) ...[
            const SizedBox(height: 12),
            _section(
              '4 • Caption varyasyonları',
              Column(
                children: variants.take(3).map((item) {
                  final variant = item is Map
                      ? Map<String, dynamic>.from(item)
                      : <String, dynamic>{};
                  final variantId = variant['id']?.toString() ?? '-';
                  final variantStyle =
                      variant['style']?.toString() ?? 'Varyant';
                  final variantCaption = variant['caption']?.toString() ?? '-';

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                                child: Text(
                              '$variantId • $variantStyle',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w900),
                            )),
                            IconButton(
                              tooltip: 'Varyantı kopyala',
                              onPressed: () =>
                                  _copy('Varyant $variantId', variantCaption),
                              icon: const Icon(Icons.copy_outlined, size: 19),
                            ),
                          ],
                        ),
                        Text(
                          variantCaption,
                          style: const TextStyle(height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _applyVariant(variant),
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('BU VARYANTI TASLAĞA UYGULA'),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (score.isNotEmpty) ...[
            const SizedBox(height: 12),
            _section(
              '5 • Kreatif skoru',
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Text(
                      (score['scores'] is Map
                                  ? (score['scores'] as Map)['overall']
                                  : null)
                              ?.toString() ??
                          '-',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    (score['scores'] is Map
                                ? (score['scores'] as Map)['signal']
                                : null)
                            ?.toString() ??
                        '-',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 10),
                  ..._scoreRows(score['scores']),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          const Center(
            child: Text(
              'Powered by AdVise AI',
              style: TextStyle(fontWeight: FontWeight.w700, color: Colors.grey),
            ),
          ),
        ],
      )),
    );
  }

  List<Widget> _scoreRows(dynamic raw) {
    if (raw is! Map) return [];
    const keys = ['hook', 'caption', 'cta', 'format', 'hashtags'];
    return keys
        .where(raw.containsKey)
        .map(
          (key) => Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    key.toUpperCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Text('${raw[key]?.toString() ?? '-'} / 100'),
              ],
            ),
          ),
        )
        .toList();
  }
}
