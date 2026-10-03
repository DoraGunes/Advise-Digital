import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';

class ContentQueuePage extends StatefulWidget {
  const ContentQueuePage({super.key});

  @override
  State<ContentQueuePage> createState() => _ContentQueuePageState();
}

class _ContentQueuePageState extends State<ContentQueuePage> {
  final ImagePicker _picker = ImagePicker();
  final TextEditingController _aiContext = TextEditingController();

  List<XFile> _selected = [];
  List<dynamic> _queued = [];
  bool _loading = false;
  bool _autoPublish = true;
  bool _useAI = true;

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
      if (!mounted) return;
      setState(() => _queued = data);
    } catch (_) {}
  }

  Future<void> _pick() async {
    final picked = await _picker.pickMultipleMedia(
      limit: 8,
      requestFullMetadata: false,
    );
    if (!mounted || picked.isEmpty) return;
    setState(() => _selected = List<XFile>.from(picked));
  }

  void _move(int oldIndex, int newIndex) {
    setState(() {
      if (newIndex > oldIndex) newIndex--;
      final item = _selected.removeAt(oldIndex);
      _selected.insert(newIndex, item);
    });
  }

  Future<void> _upload() async {
    if (_selected.isEmpty) {
      _snack('Önce 1-8 adet fotoğraf/video seç.');
      return;
    }

    setState(() => _loading = true);
    try {
      final result = await Api.uploadPostsBulk(
        _selected.map((x) => x.path).toList(),
        autoPublish: _autoPublish,
        useAI: _useAI,
        aiContext: _aiContext.text,
      );

      if (!mounted) return;
      final count = result['count'] ?? _selected.length;
      final skipped = result['skipped'] ?? 0;

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
          content: Text(
            '$count içerik sıraya alındı. $skipped içerik atlandı. '
            'Seçtiğin sıra korunarak yayın saatleri planlandı.',
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
        setState(() => _loading = false);
        _snack(e.toString());
      }
    }
  }

  Future<void> _setCover(Map<String, dynamic> post) async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await Api.uploadPostCover(post['id'].toString(), picked.path);
      await _loadQueue();
      if (mounted) _snack('Reels kapağı güncellendi.');
    } catch (e) {
      if (mounted) _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  String _type(Map<String, dynamic> post) {
    return post['mediaType']?.toString().toUpperCase() == 'REELS'
        ? 'REELS'
        : 'GÖNDERİ';
  }

  String _date(dynamic value) {
    final d = DateTime.tryParse(value?.toString() ?? '')?.toLocal();
    if (d == null) return '-';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'İçerik Kuyruğu',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _loadQueue,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 40),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Toplu Instagram içerik planlama',
                      style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'En fazla 8 fotoğraf + Reels seç. Sıralamayı sürükleyerek belirle. '
                      'AdVise AI her içeriğin metnini hazırlar ve kuyruğa sırayla alır.',
                      style: TextStyle(height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed: _loading ? null : _pick,
                        icon: const Icon(Icons.library_add_outlined),
                        label: Text(
                          _selected.isEmpty
                              ? '1-8 İÇERİK SEÇ'
                              : '${_selected.length} İÇERİK SEÇİLDİ',
                        ),
                      ),
                    ),
                    if (_selected.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 290,
                        child: ReorderableListView.builder(
                          buildDefaultDragHandles: false,
                          itemCount: _selected.length,
                          onReorder: _move,
                          itemBuilder: (ctx, index) {
                            final file = _selected[index];
                            final lower = file.name.toLowerCase();
                            final isVideo = lower.endsWith('.mp4') ||
                                lower.endsWith('.mov') ||
                                lower.endsWith('.m4v') ||
                                lower.endsWith('.webm');
                            return Card(
                              key: ValueKey('${file.path}_$index'),
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                leading: CircleAvatar(child: Text('${index + 1}')),
                                title: Text(
                                  file.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(isVideo ? 'REELS' : 'GÖNDERİ'),
                                trailing: ReorderableDragStartListener(
                                  index: index,
                                  child: const Icon(Icons.drag_handle_rounded),
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
                        labelText: 'AI için ortak bilgi (opsiyonel)',
                        hintText: 'Kampanya, ürün veya hizmet bilgisi',
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
                        'İçerikleri sırayla otomatik yayın kuyruğuna al',
                      ),
                      value: _autoPublish,
                      onChanged: _loading
                          ? null
                          : (v) => setState(() => _autoPublish = v),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _upload,
                        icon: _loading
                            ? const SizedBox(
                                width: 19,
                                height: 19,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.schedule_send_rounded),
                        label: Text(
                          _loading
                              ? 'İŞLENİYOR...'
                              : 'AI ANALİZ ET VE KUYRUĞA AL',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Yayın kuyruğu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            if (_queued.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Henüz planlanmış içerik yok.'),
                ),
              ),
            ..._queued.map((item) {
              final post = item is Map
                  ? Map<String, dynamic>.from(item)
                  : <String, dynamic>{};
              final isReel = _type(post) == 'REELS';
              final cover = post['coverPublicUrl']?.toString() ?? '';
              return Card(
                margin: const EdgeInsets.only(bottom: 9),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Chip(
                            label: Text(_type(post)),
                            avatar: Icon(
                              isReel
                                  ? Icons.video_library_outlined
                                  : Icons.image_outlined,
                              size: 17,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            post['publishStatus']?.toString() ?? '-',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                      Text(
                        post['title']?.toString() ?? '-',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 5),
                      if (post['aiGenerated'] == true)
                        const Text(
                          'AI metni hazır',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                        ),
                      const SizedBox(height: 5),
                      Text(
                        post['nextPublishAt'] == null
                            ? 'Manuel yayın'
                            : 'Planlanan: ${_date(post['nextPublishAt'])}',
                      ),
                      if (isReel) ...[
                        const SizedBox(height: 10),
                        if (cover.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(
                              cover,
                              height: 180,
                              width: double.infinity,
                              fit: BoxFit.cover,
                            ),
                          ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: _loading
                                ? null
                                : () => _setCover(post),
                            icon: const Icon(Icons.photo_camera_back_outlined),
                            label: Text(
                              cover.isEmpty
                                  ? 'REELS KAPAĞI SEÇ'
                                  : 'REELS KAPAĞINI DEĞİŞTİR',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
