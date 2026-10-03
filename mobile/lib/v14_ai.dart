import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import 'api.dart';

class AiContentStudioPage extends StatefulWidget {
  const AiContentStudioPage({super.key});

  @override
  State<AiContentStudioPage> createState() => _AiContentStudioPageState();
}

class _AiContentStudioPageState extends State<AiContentStudioPage> {
  final title = TextEditingController();
  final contextText = TextEditingController();

  String tone = 'samimi ve güven veren';
  String goal = 'mesaj';
  String media = 'AUTO';

  bool loading = false;
  bool variantsLoading = false;
  bool scoreLoading = false;

  XFile? image;
  Map<String, dynamic>? result;
  List<dynamic> variants = [];
  Map<String, dynamic> score = {};
  Map<String, dynamic> aiStatus = {};

  @override
  void initState() {
    super.initState();
    _loadAiStatus();
  }

  @override
  void dispose() {
    title.dispose();
    contextText.dispose();
    super.dispose();
  }

  Future<void> _loadAiStatus() async {
    try {
      final data = await Api.aiStatus();
      if (mounted) setState(() => aiStatus = data);
    } catch (_) {}
  }

  Future<void> _pickMedia() async {
    final picked = await ImagePicker().pickMedia(
      imageQuality: 92,
    );
    if (picked == null || !mounted) return;

    setState(() {
      image = picked;
      result = null;
      variants = [];
      score = {};
    });
  }

  bool _selectedMediaIsImage() {
    final name = image?.name.toLowerCase() ?? '';
    return [
      '.jpg', '.jpeg', '.jfif', '.png', '.webp', '.gif', '.bmp',
      '.heic', '.heif', '.avif', '.tif', '.tiff'
    ].any(name.endsWith);
  }

  Future<void> _generate() async {
    if (image == null && title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir görsel/video seç veya ürün başlığı gir.')),
      );
      return;
    }

    setState(() => loading = true);

    try {
      final data = image != null
          ? await Api.generateContentPackFromFile(
              image!.path,
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
      setState(() => result = data);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            image != null
                ? 'Görsel analiz edildi ve içerik paketi hazırlandı.'
                : 'İçerik paketi hazırlandı.',
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _generateVariants() async {
    if (title.text.trim().isEmpty && result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce bir içerik üret.')),
      );
      return;
    }

    setState(() => variantsLoading = true);

    try {
      final data = await Api.generateCaptionVariants(
        title: title.text,
        context: contextText.text,
        tone: tone,
        goal: goal,
        mediaType: media,
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
          SnackBar(content: Text(e.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => variantsLoading = false);
    }
  }

  Future<void> _scoreCreative() async {
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
          SnackBar(content: Text(e.toString())),
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
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
              const Spacer(),
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
    final model = aiStatus['model']?.toString() ?? '-';
    final configured = aiStatus['configured'] == true;
    final hashtags = result?['hashtags'] is List
        ? (result!['hashtags'] as List).join(' ')
        : '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI İçerik Stüdyosu',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            tooltip: 'AI durumunu yenile',
            onPressed: _loadAiStatus,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 40),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                colors: [Color(0xFF1F2454), Color(0xFF4F46E5)],
              ),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AdVise AI içerik motoru',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'Görseli yükle → ürünü analiz et → caption, hook, CTA ve format önerisi üret.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: ListTile(
              leading: CircleAvatar(
                child: Icon(
                  configured ? Icons.auto_awesome : Icons.offline_bolt_outlined,
                ),
              ),
              title: Text(
                configured ? 'AI sağlayıcısı bağlı' : 'Yerel AI fallback aktif',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              subtitle: Text('Model: $model'),
            ),
          ),
          const SizedBox(height: 12),
          _section(
            '1 • İçerik kaynağı',
            Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : _pickMedia,
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
                      child: Image.file(
                        File(image!.path),
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
                        border: Border.all(color: Theme.of(context).dividerColor),
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
              ],
            ),
          ),
          const SizedBox(height: 12),
          _section(
            '2 • AI otomatik karar',
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.auto_awesome_rounded),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Senin seçmen gereken sadece medya. AdVise AI ürünü, markayı, görünen bilgileri, içerik açısını, tonu, amacı ve formatı görselden çıkarır.',
                          style: TextStyle(height: 1.45),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: contextText,
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
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: loading ? null : _generate,
                    icon: loading
                        ? const SizedBox(
                            width: 19,
                            height: 19,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome),
                    label: Text(
                      loading
                          ? 'AI GÖRSELİ VE İÇERİĞİ ANALİZ EDİYOR...'
                          : image != null
                              ? 'AI İLE ANALİZ ET VE İÇERİK OLUŞTUR'
                              : 'AI İLE İÇERİK OLUŞTUR',
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
              '3 • AI sonucu',
              Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.movie_filter_outlined),
                      const SizedBox(width: 8),
                      const Text(
                        'Önerilen format',
                        style: TextStyle(fontWeight: FontWeight.w900),
                      ),
                      const Spacer(),
                      Chip(
                        label: Text(
                          result!['recommendedFormat']?.toString() ?? '-',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (source.isNotEmpty)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Kaynak: $source',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  const SizedBox(height: 10),
                  _resultBox('ÜRÜN', result!['productName']?.toString() ?? ''),
                  _resultBox('MARKA', result!['brand']?.toString() ?? ''),
                  _resultBox('MODEL', result!['model']?.toString() ?? ''),
                  _resultBox('GÖRSELDEKİ METİNLER', result!['detectedText']?.toString() ?? ''),
                  _resultBox('GÖRÜLEN TEKLİF', result!['detectedOffer']?.toString() ?? ''),
                  _resultBox('SEÇİLEN TON', result!['selectedTone']?.toString() ?? ''),
                  _resultBox('İÇERİK AÇISI', result!['contentAngle']?.toString() ?? ''),
                  _resultBox('HOOK', result!['hook']?.toString() ?? ''),
                  _resultBox('CTA', result!['cta']?.toString() ?? ''),
                  _resultBox('CAPTION', result!['caption']?.toString() ?? ''),
                  _resultBox('HASHTAGS', hashtags),
                  _resultBox('PAYLAŞIM ZAMANI', result!['recommendedPostTime']?.toString() ?? ''),
                  _resultBox('ZAMAN GEREKÇESİ', result!['recommendedPostTimeReason']?.toString() ?? ''),
                  _resultBox('HEDEF KİTLE', result!['targetAudience']?.toString() ?? ''),
                  _resultBox('İÇERİK AMACI', result!['contentGoal']?.toString() ?? ''),
                  _resultBox('GÖRSEL ANALİZİ', result!['visualSummary']?.toString() ?? ''),
                  _resultBox('REKLAM ÖNERİSİ', result!['adRecommendation']?.toString() ?? ''),
                  _resultBox('SONRAKİ ADIM', result!['nextAction']?.toString() ?? ''),
                  _resultBox('KREATİF SKORU', result!['creativeScore']?.toString() ?? ''),
                  _resultBox('AI GÜVENİ', result!['confidence']?.toString() ?? ''),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: variantsLoading ? null : _generateVariants,
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
                          onPressed: scoreLoading ? null : _scoreCreative,
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
                  final variantCaption =
                      variant['caption']?.toString() ?? '-';

                  return Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 9),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF7F7FA),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '$variantId • $variantStyle',
                              style: const TextStyle(fontWeight: FontWeight.w900),
                            ),
                            const Spacer(),
                            IconButton(
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
      ),
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
