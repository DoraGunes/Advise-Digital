import 'package:flutter/material.dart';
import 'api.dart';
import 'media_access.dart';
import 'product_ui.dart';
import 'app_error.dart';

class ContentQueuePage extends StatefulWidget {
  final String? initialPostId;
  const ContentQueuePage({super.key, this.initialPostId});

  @override
  State<ContentQueuePage> createState() => _ContentQueuePageState();
}

class _ContentQueuePageState extends State<ContentQueuePage> {
  final TextEditingController _aiContext = TextEditingController();

  List<XFile> _selected = [];
  List<dynamic> _queued = [];
  bool _loading = false;
  bool _autoPublish = true;
  bool _useAI = true;
  bool _initialLoading = true, _canEdit = false, _canConfigure = false;
  String? _error;
  String _view = 'ALL', _search = '';
  int _visibleLimit = 30;
  DateTime _calendarDay = DateTime.now();

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  @override
  void dispose() {
    _aiContext.dispose();
    super.dispose();
  }

  Future<void> _loadQueue() async {
    try {
      final data = await Api.posts();
      final me = await Api.me();
      final role = (me['user'] as Map?)?['role'];
      var autoPublish = _autoPublish;
      try {
        final settings = await Api.settings();
        autoPublish = settings['autoPublish'] != false;
      } catch (_) {}
      if (!mounted) return;
      setState(() {
        _queued = data;
        _autoPublish = autoPublish;
        _canEdit =
            ['ADMIN', 'CUSTOMER_ADMIN', 'MANAGER', 'OPERATOR'].contains(role);
        _canConfigure = ['ADMIN', 'CUSTOMER_ADMIN'].contains(role);
        _error = null;
        _initialLoading = false;
      });
    } catch (e) {
      if (mounted)
        setState(() {
          _error = AppError.message(e);
          _initialLoading = false;
        });
    }
  }

  Future<void> _setAutoPublish(bool value) async {
    if (!_canConfigure || _loading) return;
    setState(() => _loading = true);
    try {
      await Api.saveSettings({'autoPublish': value});
      if (mounted) setState(() => _autoPublish = value);
    } catch (e) {
      if (mounted) _snack('Otomatik yayın ayarı kaydedilemedi: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pick() async {
    if (!_canEdit || _loading) return;
    final picked = await MediaAccess.pickMany(limit: 8);
    if (!mounted || picked.isEmpty) return;
    setState(() => _selected = List<XFile>.from(picked));
  }

  void _move(int oldIndex, int newIndex) {
    setState(() {
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
  }

  Future<void> _upload() async {
    if (!_canEdit || _loading) return;
    if (_selected.isEmpty) {
      _snack('Önce 1-8 adet fotoğraf/video seç.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await Api.uploadPostsBulk(
        _selected.map((x) => x.path).toList(),
        mediaFiles: _selected,
        autoPublish: _autoPublish,
        useAI: _useAI,
        aiContext: _aiContext.text,
      );

      if (!mounted) return;
      final count = result['count'] ?? _selected.length;
      final skipped = result['skipped'] ?? 0;
      final savedPosts = result['posts'] is List
          ? List<dynamic>.from(result['posts'])
          : const <dynamic>[];
      final scheduled = savedPosts.any((post) =>
          post is Map && ['QUEUED', 'RETRY'].contains(post['publishStatus']));

      setState(() {
        _selected = [];
        _loading = false;
      });

      await _loadQueue();

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Kuyruk hazır'),
          content: Text(scheduled
              ? '$count içerik kuyruğa alındı. $skipped içerik atlandı. Yayın saatleri seçtiğin sıraya göre planlandı.'
              : '$count içerik taslak olarak kaydedildi. $skipped içerik atlandı. Otomatik yayın açık olduğunda tek dokunuşla sıraya alabilirsin.'),
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
        setState(() => _loading = false);
        _snack(AppError.message(e));
      }
    }
  }

  Future<void> _setCover(Map<String, dynamic> post) async {
    if (!_editable(post) || _loading) return;
    final picked = await MediaAccess.pickOne(mediaType: 'IMAGE');
    if (picked == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await Api.uploadPostCover(post['id'].toString(), picked.path,
          mediaFile: picked);
      await _loadQueue();
      if (mounted) _snack('Reels kapağı güncellendi.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editPost(Map<String, dynamic> post) async {
    if (!_editable(post) || _loading) return;
    final title = TextEditingController(text: post['title']?.toString() ?? '');
    final caption =
        TextEditingController(text: post['caption']?.toString() ?? '');
    final link = TextEditingController(text: post['linkUrl']?.toString() ?? '');
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İçeriği düzenle'),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(
                  controller: title,
                  maxLength: 180,
                  decoration: const InputDecoration(labelText: 'Başlık')),
              const SizedBox(height: 10),
              TextField(
                  controller: caption,
                  minLines: 6,
                  maxLines: 12,
                  maxLength: 2200,
                  decoration: const InputDecoration(
                      labelText: 'Yayın metni', alignLabelWithHint: true)),
              const SizedBox(height: 10),
              TextField(
                  controller: link,
                  decoration: const InputDecoration(
                      labelText: 'Bağlantı (isteğe bağlı)')),
            ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('İptal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('KAYDET')),
        ],
      ),
    );
    if (save == true) {
      try {
        await Api.updatePost(post['id'].toString(),
            title: title.text, caption: caption.text, linkUrl: link.text);
        await _loadQueue();
        if (mounted) _snack('İçerik güncellendi.');
      } catch (e) {
        if (mounted) _snack(AppError.message(e));
      }
    }
    title.dispose();
    caption.dispose();
    link.dispose();
  }

  Future<void> _previewPost(Map<String, dynamic> post) async {
    final cover =
        (post['coverPublicUrl'] ?? post['publicUrl'])?.toString() ?? '';
    final isImage = post['mediaType']?.toString().toUpperCase() != 'REELS';
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Instagram önizlemesi'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isImage && cover.startsWith('http'))
                    ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(cover,
                            height: 220,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _mediaPlaceholder()))
                  else
                    _mediaPlaceholder(),
                  const SizedBox(height: 12),
                  Text(post['title']?.toString() ?? 'Yeni gönderi',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  SelectableText(post['caption']?.toString() ?? '',
                      style: const TextStyle(height: 1.5)),
                  const SizedBox(height: 8),
                  Text(
                      'WhatsApp • ${post['nextPublishAt'] == null ? 'Zaman seçilmedi' : _date(post['nextPublishAt'])}',
                      style: Theme.of(context).textTheme.bodySmall),
                ]),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('KAPAT'))
        ],
      ),
    );
  }

  Widget _mediaPlaceholder() => Container(
        height: 160,
        width: double.infinity,
        decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.video_library_outlined, size: 46),
      );

  DateTime _suggestedSlot(Map<String, dynamic> post) {
    final now = DateTime.now();
    final recommended = post['aiRecommendedPostTime']?.toString() ?? '';
    final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(recommended);
    final hour = match == null ? 19 : int.parse(match.group(1)!);
    final minute = match == null ? 30 : int.parse(match.group(2)!);
    var value = DateTime(now.year, now.month, now.day, hour, minute);
    if (!value.isAfter(now)) value = value.add(const Duration(days: 1));
    return value;
  }

  Future<DateTime?> _pickPublishTime(Map<String, dynamic> post) async {
    final now = DateTime.now();
    final initial = _suggestedSlot(post);
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
    final value =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (!value.isAfter(DateTime.now())) {
      _snack('Yayın zamanı gelecekte olmalı.');
      return null;
    }
    return value;
  }

  Future<void> _queuePost(Map<String, dynamic> post) async {
    if (!_editable(post) || _loading) return;
    final selectedTime = await _pickPublishTime(post);
    if (selectedTime == null || !mounted) return;
    try {
      final updated = await Api.queuePost(post['id'].toString(),
          scheduleAt: selectedTime.toUtc().toIso8601String());
      await _loadQueue();
      final planned =
          DateTime.tryParse(updated['nextPublishAt']?.toString() ?? '')
                  ?.toLocal() ??
              selectedTime;
      if (mounted)
        _snack(updated['publishStatus'] == 'READY'
            ? 'İçerik yayına hazır. Otomatik yayın kapalı olduğu için onayını bekliyor.'
            : 'Kuyruğa alındı • ${_date(planned.toIso8601String())}’de paylaşılacak.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
  }

  Future<void> _publishPost(Map<String, dynamic> post) async {
    if (!_editable(post) || _loading) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Instagram’da paylaş'),
        content: const Text(
            'Bu içerik bağlı Instagram hesabında hemen yayınlanacak. Devam edilsin mi?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('VAZGEÇ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('ŞİMDİ PAYLAŞ')),
        ],
      ),
    );
    if (accepted != true) return;
    setState(() => _loading = true);
    try {
      final result = await Api.publishPost(post['id'].toString());
      await _loadQueue();
      if (mounted)
        _snack(result['publishStatus'] == 'PUBLISHED'
            ? 'Instagram paylaşımı tamamlandı.'
            : 'Instagram yayın sonucu doğrulanıyor. İçerik yeniden gönderilmeyecek.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelQueue(Map<String, dynamic> post) async {
    if (!_editable(post) || _loading) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Planlamayı iptal et'),
        content: const Text(
            'İçerik silinmeyecek; yalnız otomatik yayın kuyruğundan çıkarılıp taslak durumuna alınacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('VAZGEÇ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('PLANLAMAYI İPTAL ET'))
        ],
      ),
    );
    if (accepted != true) return;
    setState(() => _loading = true);
    try {
      await Api.cancelQueuedPost(post['id'].toString());
      await _loadQueue();
      if (mounted) _snack('Planlama iptal edildi. İçerik taslakta kaldı.');
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _moveQueued(Map<String, dynamic> post, int delta) async {
    if (!_editable(post) || _loading) return;
    final pending = _queued
        .where((item) =>
            item is Map && ['QUEUED', 'RETRY'].contains(item['publishStatus']))
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList()
      ..sort((a, b) =>
          DateTime.tryParse(a['nextPublishAt']?.toString() ?? '')?.compareTo(
              DateTime.tryParse(b['nextPublishAt']?.toString() ?? '') ??
                  DateTime(9999)) ??
          0);
    final index = pending
        .indexWhere((item) => item['id']?.toString() == post['id']?.toString());
    final next = index + delta;
    if (index < 0 || next < 0 || next >= pending.length) return;
    final item = pending.removeAt(index);
    pending.insert(next, item);
    setState(() => _loading = true);
    try {
      await Api.reorderQueuedPosts(
          pending.map((x) => x['id'].toString()).toList());
      await _loadQueue();
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePost(Map<String, dynamic> post) async {
    if (!_editable(post) || _loading) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('İçeriği sil'),
        content: const Text(
            'Bu içerik kuyruktan ve yüklenen medyadan kaldırılacak.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('VAZGEÇ')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('SİL'))
        ],
      ),
    );
    if (accepted != true) return;
    try {
      await Api.deletePost(post['id'].toString());
      await _loadQueue();
    } catch (e) {
      if (mounted) _snack(AppError.message(e));
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(AppError.message(message)),
          behavior: SnackBarBehavior.floating),
    );
  }

  String _type(Map<String, dynamic> post) {
    return post['mediaType']?.toString().toUpperCase() == 'REELS'
        ? 'REELS'
        : 'GÖNDERİ';
  }

  String _statusLabel(Map<String, dynamic> post) {
    switch (post['publishStatus']?.toString().toUpperCase()) {
      case 'QUEUED':
        return 'PLANLANDI';
      case 'PUBLISHING':
        return 'YAYINLANIYOR';
      case 'PUBLISH_UNKNOWN':
      case 'RECONCILE':
        return 'DOĞRULAMA BEKLİYOR';
      case 'RETRY':
        return 'TEKRAR DENENECEK';
      case 'READY':
        return 'YAYINA HAZIR';
      case 'PUBLISHED':
        return 'YAYINLANDI';
      case 'ERROR':
        return 'HATA';
      default:
        return 'TASLAK';
    }
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  Widget _statusChip(String text,
      {required bool isQueued, required bool isPublished}) {
    final color = isPublished
        ? const Color(0xFF16784B)
        : isQueued
            ? const Color(0xFF3857C8)
            : const Color(0xFF74613A);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
            color: color.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(99)),
        child: Text(text,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w900, color: color)));
  }

  Widget _postCard(Map<String, dynamic> post) {
    final status = post['publishStatus']?.toString().toUpperCase() ?? 'MANUAL';
    final isQueued = ['QUEUED', 'RETRY'].contains(status);
    final isReady = status == 'READY';
    final isPublished = status == 'PUBLISHED';
    final canEdit = _editable(post);
    final isReel = _type(post) == 'REELS';
    final cover =
        (post['coverPublicUrl'] ?? post['publicUrl'])?.toString() ?? '';
    final canPublish = cover.startsWith('https://');
    final queuedPosts = _queued
        .where((item) =>
            item is Map && ['QUEUED', 'RETRY'].contains(item['publishStatus']))
        .toList();
    final queuedIndex = queuedPosts
        .indexWhere((item) => item['id']?.toString() == post['id']?.toString());
    return Card(
      key: ValueKey('content-post-${post['id']}'),
      margin: const EdgeInsets.only(bottom: 10),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: 76,
              height: 76,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: cover.startsWith('http') && !isReel
                    ? Image.network(cover,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _mediaPlaceholder())
                    : Container(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        child: Icon(
                            isReel
                                ? Icons.play_circle_outline_rounded
                                : Icons.image_outlined,
                            size: 32)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Wrap(spacing: 6, runSpacing: 6, children: [
                    Text(post['title']?.toString() ?? 'Yeni içerik',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(width: 5),
                    _statusChip(_statusLabel(post),
                        isQueued: isQueued, isPublished: isPublished),
                  ]),
                  const SizedBox(height: 6),
                  Text(
                      isQueued
                          ? 'Planlandı • ${_date(post['nextPublishAt'])}'
                          : isReady
                              ? 'Yayın için hazır • önerilen ${_date(post['nextPublishAt'])}'
                              : isPublished
                                  ? 'Paylaşıldı • ${_date(post['publishedAt'])}'
                                  : 'Taslak • henüz yayınlanmadı',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 5),
                  Text(post['caption']?.toString() ?? '',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(height: 1.35)),
                ])),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 7, runSpacing: 6, children: [
            OutlinedButton.icon(
                onPressed: () => _previewPost(post),
                icon: const Icon(Icons.visibility_outlined, size: 18),
                label: const Text('Önizle')),
            if (!isPublished && canEdit)
              OutlinedButton.icon(
                  onPressed: _loading ? null : () => _editPost(post),
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Düzenle')),
            if (!isPublished && canEdit)
              FilledButton.tonalIcon(
                  onPressed: _loading ? null : () => _queuePost(post),
                  icon: const Icon(Icons.schedule_send_rounded, size: 18),
                  label: Text(isQueued
                      ? 'Zamanı değiştir'
                      : status == 'ERROR'
                          ? 'Tekrar planla'
                          : 'Saat seç')),
            if (canEdit && isQueued)
              OutlinedButton.icon(
                  onPressed: _loading ? null : () => _cancelQueue(post),
                  icon: const Icon(Icons.event_busy_outlined, size: 18),
                  label: const Text('Planı iptal et')),
            if (canEdit && isQueued && queuedIndex > 0)
              IconButton.filledTonal(
                  onPressed: _loading ? null : () => _moveQueued(post, -1),
                  tooltip: 'Sırada öne al',
                  icon: const Icon(Icons.arrow_upward_rounded)),
            if (canEdit &&
                isQueued &&
                queuedIndex >= 0 &&
                queuedIndex < queuedPosts.length - 1)
              IconButton.filledTonal(
                  onPressed: _loading ? null : () => _moveQueued(post, 1),
                  tooltip: 'Sırada geriye al',
                  icon: const Icon(Icons.arrow_downward_rounded)),
            if (!isPublished && canEdit)
              FilledButton.icon(
                  onPressed:
                      canPublish && !_loading ? () => _publishPost(post) : null,
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Şimdi paylaş')),
            if (!isPublished && canEdit)
              IconButton(
                  onPressed: _loading ? null : () => _deletePost(post),
                  tooltip: 'İçeriği sil',
                  icon: const Icon(Icons.delete_outline_rounded)),
          ]),
          if (['PUBLISHING', 'RECONCILE', 'PUBLISH_UNKNOWN'].contains(status) ||
              post['publishAmbiguous'] == true)
            const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                    'Instagram sonucu kontrol ediliyor. Aynı içeriğin iki kez yayınlanmasını önlemek için işlemler bekletiliyor.')),
          if (!isPublished && !canPublish)
            Padding(
                padding: EdgeInsets.only(top: 3),
                child: Text(
                    'Doğrudan Instagram yayını için HTTPS medya adresi gerekir.',
                    style: TextStyle(
                        fontSize: 11,
                        color:
                            Theme.of(context).colorScheme.onSurfaceVariant))),
          if (isReel && !isPublished && canEdit) ...[
            const Divider(height: 18),
            SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _setCover(post),
                    icon: const Icon(Icons.photo_camera_back_outlined),
                    label: Text(post['coverPublicUrl'] == null
                        ? 'Reels kapağı seç'
                        : 'Reels kapağını değiştir'))),
          ],
        ]),
      ),
    );
  }

  bool _editable(Map<String, dynamic> post) =>
      _canEdit &&
      !['PUBLISHED', 'PUBLISHING', 'RECONCILE', 'PUBLISH_UNKNOWN']
          .contains(post['publishStatus']?.toString().toUpperCase()) &&
      post['publishAmbiguous'] != true;

  @override
  Widget build(BuildContext context) {
    final visible = _visiblePosts();
    final queuedCount = _queued
        .where((item) =>
            item is Map &&
            ['QUEUED', 'RETRY']
                .contains(item['publishStatus']?.toString().toUpperCase()))
        .length;
    final publishedCount = _queued
        .where((item) =>
            item is Map &&
            item['publishStatus']?.toString().toUpperCase() == 'PUBLISHED')
        .length;
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'İçerik Planı',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ProductContent(
          child: _initialLoading
              ? const SingleChildScrollView(
                  padding: EdgeInsets.all(20), child: ProductLoadingSkeleton())
              : _error != null
                  ? SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: ProductErrorState(
                          message: _error!, onRetry: _loadQueue))
                  : RefreshIndicator(
                      onRefresh: _loadQueue,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: 1),
                            duration: const Duration(milliseconds: 460),
                            curve: Curves.easeOutCubic,
                            builder: (context, value, child) => Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset: Offset(0, 16 * (1 - value)),
                                child: child,
                              ),
                            ),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFF202143),
                                    Color(0xFF4E48A8),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: const [
                                  BoxShadow(
                                      color: Color(0x24352D86),
                                      blurRadius: 22,
                                      offset: Offset(0, 10))
                                ],
                              ),
                              child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('YAYIN AKIŞI',
                                        style: TextStyle(
                                            color: Color(0xFFC8F7E7),
                                            fontSize: 10,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 1.4)),
                                    const SizedBox(height: 7),
                                    const Text('İçeriklerin sıraya girsin.',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 22,
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 5),
                                    Text(
                                        'Bir içeriği planla, sıradakileri ekle; saat yaklaşınca otomatik paylaşım çalışsın.',
                                        style: TextStyle(
                                            color: Colors.white
                                                .withValues(alpha: .84),
                                            height: 1.4)),
                                    const SizedBox(height: 14),
                                    Wrap(spacing: 8, runSpacing: 8, children: [
                                      _queueMetric('$queuedCount sırada',
                                          Icons.schedule_send_rounded),
                                      _queueMetric('$publishedCount paylaşıldı',
                                          Icons.check_circle_outline_rounded),
                                    ]),
                                  ]),
                            ),
                          ),
                          if (_canEdit)
                            Card(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Yeni içerikler',
                                        style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.w900)),
                                    const SizedBox(height: 5),
                                    Text(
                                        'Fotoğraf veya Reels ekle. Metni gözden geçir, sonra taslakta tut ya da planlı kuyruğa al.',
                                        style: TextStyle(
                                            height: 1.4,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .onSurfaceVariant)),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: _loading ? null : _pick,
                                        icon: const Icon(
                                            Icons.library_add_outlined),
                                        label: Text(_selected.isEmpty
                                            ? 'MEDYA SEÇ'
                                            : '${_selected.length} MEDYA SEÇİLDİ'),
                                      ),
                                    ),
                                    if (_selected.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      SizedBox(
                                        height: 290,
                                        child: ReorderableListView.builder(
                                          buildDefaultDragHandles: false,
                                          itemCount: _selected.length,
                                          onReorderItem: _move,
                                          itemBuilder: (ctx, index) {
                                            final file = _selected[index];
                                            final lower =
                                                file.name.toLowerCase();
                                            final isVideo =
                                                lower.endsWith('.mp4') ||
                                                    lower.endsWith('.mov') ||
                                                    lower.endsWith('.m4v') ||
                                                    lower.endsWith('.webm');
                                            return Card(
                                              key: ValueKey(
                                                  '${file.path}_$index'),
                                              margin: const EdgeInsets.only(
                                                  bottom: 6),
                                              child: ListTile(
                                                leading: CircleAvatar(
                                                    child:
                                                        Text('${index + 1}')),
                                                title: Text(
                                                  file.name,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                subtitle: Text(isVideo
                                                    ? 'REELS'
                                                    : 'GÖNDERİ'),
                                                trailing:
                                                    ReorderableDragStartListener(
                                                  index: index,
                                                  child: const Icon(Icons
                                                      .drag_handle_rounded),
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 8),
                                    TextField(
                                      controller: _aiContext,
                                      maxLines: 3,
                                      decoration: const InputDecoration(
                                        labelText:
                                            'AI için ortak bilgi (opsiyonel)',
                                        hintText:
                                            'Kampanya, ürün veya hizmet bilgisi',
                                      ),
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('AI metin üretimi'),
                                      subtitle: const Text(
                                        'Her içerik için caption, hook, CTA ve hashtag',
                                      ),
                                      value: _useAI,
                                      onChanged: _loading
                                          ? null
                                          : (v) => setState(() => _useAI = v),
                                    ),
                                    SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('Otomatik yayınla'),
                                      subtitle: const Text(
                                        'Saatinde otomatik Instagram paylaşımı için aç',
                                      ),
                                      value: _autoPublish,
                                      onChanged: _loading || !_canConfigure
                                          ? null
                                          : _setAutoPublish,
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _loading ? null : _upload,
                                        icon: _loading
                                            ? const SizedBox(
                                                width: 19,
                                                height: 19,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2),
                                              )
                                            : const Icon(
                                                Icons.schedule_send_rounded),
                                        label: Text(
                                          _loading
                                              ? 'İçerikler hazırlanıyor…'
                                              : _useAI
                                                  ? 'AI ile hazırla ve planla'
                                                  : 'İçerikleri planla',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          const SizedBox(height: 14),
                          Row(children: [
                            const Expanded(
                                child: Text('İçerik planı',
                                    style: TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w900))),
                            TextButton.icon(
                                onPressed: _loading ? null : _loadQueue,
                                icon:
                                    const Icon(Icons.refresh_rounded, size: 18),
                                label: const Text('Yenile')),
                          ]),
                          Text(
                              'Saati seç, sırayı değiştir, metni düzenle ve yayın planını önizle.',
                              style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant)),
                          const SizedBox(height: 10),
                          Wrap(spacing: 8, runSpacing: 8, children: [
                            for (final e in {
                              'ALL': 'Tümü',
                              'TODAY': 'Bugün',
                              'TOMORROW': 'Yarın',
                              'WEEK': 'Bu hafta',
                              'CALENDAR': 'Takvim',
                              'DRAFT': 'Taslaklar',
                              'FAILED': 'Başarısız',
                              'PUBLISHED': 'Yayınlananlar'
                            }.entries)
                              ChoiceChip(
                                  label: Text(e.value),
                                  selected: _view == e.key,
                                  onSelected: (_) => setState(() {
                                        _view = e.key;
                                        _visibleLimit = 30;
                                      })),
                          ]),
                          if (_view == 'CALENDAR')
                            CalendarDatePicker(
                                initialDate: _calendarDay,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now()
                                    .add(const Duration(days: 1825)),
                                onDateChanged: (d) =>
                                    setState(() => _calendarDay = d)),
                          const SizedBox(height: 12),
                          TextField(
                              decoration: const InputDecoration(
                                  prefixIcon: Icon(Icons.search),
                                  hintText: 'İçerik ara'),
                              onChanged: (s) => setState(() => _search = s)),
                          const SizedBox(height: 16),
                          if (visible.isEmpty)
                            ProductEmptyState(
                                title: 'Bu görünümde içerik yok',
                                body:
                                    'Başka bir tarih seç veya ilk içeriğini ekle.',
                                icon: Icons.calendar_month_outlined,
                                action: _canEdit
                                    ? OutlinedButton(
                                        onPressed: _pick,
                                        child: const Text('Medya ekle'))
                                    : null),
                          ...visible.take(_visibleLimit).map(_postCard),
                          if (visible.length > _visibleLimit)
                            TextButton(
                                onPressed: () =>
                                    setState(() => _visibleLimit += 30),
                                child: const Text('Daha fazla içerik göster')),
                        ],
                      ),
                    )),
    );
  }

  List<Map<String, dynamic>> _visiblePosts() {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    final weekStart = start.subtract(Duration(days: start.weekday - 1));
    final list = _queued
        .whereType<Map>()
        .map((x) => Map<String, dynamic>.from(x))
        .where((x) {
      final status = '${x['publishStatus'] ?? 'MANUAL'}'.toUpperCase();
      final date =
          DateTime.tryParse('${x['nextPublishAt'] ?? x['publishedAt'] ?? ''}')
              ?.toLocal();
      final query = '${x['title'] ?? ''} ${x['caption'] ?? ''}'.toLowerCase();
      if (!query.contains(_search.toLowerCase())) return false;
      if (_view == 'DRAFT') return ['MANUAL', 'READY'].contains(status);
      if (_view == 'FAILED')
        return ['ERROR', 'RETRY', 'PUBLISH_UNKNOWN'].contains(status) ||
            x['publishAmbiguous'] == true;
      if (_view == 'PUBLISHED') return status == 'PUBLISHED';
      if (_view == 'ALL') return true;
      if (date == null) return false;
      final day = DateTime(date.year, date.month, date.day);
      if (_view == 'TODAY') return day == start;
      if (_view == 'TOMORROW') return day == start.add(const Duration(days: 1));
      if (_view == 'WEEK')
        return !day.isBefore(weekStart) &&
            day.isBefore(weekStart.add(const Duration(days: 7)));
      return day ==
          DateTime(_calendarDay.year, _calendarDay.month, _calendarDay.day);
    }).toList();
    list.sort((a, b) {
      if (a['id'] == widget.initialPostId) return -1;
      if (b['id'] == widget.initialPostId) return 1;
      return '${a['nextPublishAt'] ?? '9999'}'
          .compareTo('${b['nextPublishAt'] ?? '9999'}');
    });
    return list;
  }

  Widget _queueMetric(String label, IconData icon) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .15),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: const Color(0xFFC8F7E7), size: 17),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12)),
        ]),
      );
}
