import 'package:flutter/material.dart';
import 'api.dart';
import 'app_error.dart';

class ManualMemoryPage extends StatelessWidget {
  const ManualMemoryPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hafıza Sarayı')),
    body: const SingleChildScrollView(
      padding: EdgeInsets.all(20), child: ManualMemoryPanel()),
  );
}

class ManualMemoryPanel extends StatefulWidget {
  final void Function(String)? onUseCaption;
  const ManualMemoryPanel({super.key, this.onUseCaption});
  @override
  State<ManualMemoryPanel> createState() => _ManualMemoryPanelState();
}
class _ManualMemoryPanelState extends State<ManualMemoryPanel> {
  Map<String, dynamic> data = {};
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final result = await Api.localMemory();
      if (mounted) setState(() => data = result);
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final performance = data['performance'] is Map ? data['performance'] as Map : {};
    final timing = data['timing'] is Map ? data['timing'] as Map : {};
    final posts = data['posts'] is List ? data['posts'] as List : [];
    final learning = data['learning'] is Map ? data['learning'] as Map : {};
    final research = data['research'] is Map ? data['research'] as Map : {};
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('Kendi kayıtlarından Hafıza Sarayı',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
        IconButton(tooltip: 'Hafızayı yenile', onPressed: loading ? null : _load,
          icon: const Icon(Icons.refresh)),
      ]),
      const Text('Kaydedilmiş metinlerin ve seçtiğin paylaşım saatlerin. Yayın saati kendiliğinden değiştirilmez.'),
      const SizedBox(height: 12),
      if (loading) const LinearProgressIndicator()
      else if (error != null) Text(error!)
      else ...[
        const Text('Kendi metin ve saat hafızan',style:TextStyle(fontWeight:FontWeight.bold)),
        Text('${learning['note'] ?? 'Henüz metin analizi yok.'}'),
        for(final row in (learning['keywords'] is List ? learning['keywords'] as List : []))
          if(row is Map) Text('${row['text']} · ${row['postCount']} kayıt'),
        for(final group in (learning['captionSuggestions'] is List ? learning['captionSuggestions'] as List : []))
          if(group is Map) ...[
            Text('${group['mediaType']} için kendi metinlerin'),
            for(final row in (group['examples'] is List ? group['examples'] as List : []))
              if(row is Map) ...[
                Text('${row['caption']}'),
                if(widget.onUseCaption != null)
                  TextButton(onPressed:()=>widget.onUseCaption!('${row['caption']}'),
                    child:const Text('Bu metni taslağa al')),
              ],
          ],
        for(final group in (learning['timingChecks'] is List ? learning['timingChecks'] as List : []))
          if(group is Map) ...[
            Text('${group['slot']} · ${group['timezone']} · ${group['label']}'),
            Text('Uyumlu farklı yayın: ${group['alignedCount']} · tolerans: ${learning['timingToleranceMinutes']} dakika'),
            for(final row in (group['trials'] is List ? group['trials'] as List : []))
              if(row is Map) Text('Seçilen: ${row['plannedAt']} · kayıtlı yayın: ${row['recordedPublishedAt']} · fark: ${row['deltaMinutes']} dk'),
            Text('${group['note']}'),
          ],
        const SizedBox(height:16),
        const Text('Araştırma kitaplığı — henüz bu hesapta denenmedi', style: TextStyle(fontWeight: FontWeight.bold)),
        Text('${research['disclaimer'] ?? 'Sunucu araştırma kitaplığı henüz yok.'}'),
        for (final row in (research['timing'] is List ? research['timing'] as List : []))
          if (row is Map) Text('Deneme saati: gün ${row['weekday']} · ${row['hour']}:00 · ${row['timezone']} · hesap örneği: 0'),
        for (final row in (research['hashtagSets'] is List ? research['hashtagSets'] as List : []))
          if (row is Map) ...[
            Text('${row['title']}: ${row['tags'] is List ? (row['tags'] as List).join(' ') : ''}'),
            Text('${row['reason'] ?? ''}'),
            if (widget.onUseCaption != null && row['tags'] is List)
              TextButton(onPressed: () => widget.onUseCaption!((row['tags'] as List).join(' ')),
                child: const Text('Hashtagleri taslağa kopyala (mevcut metni değiştirir)')),
          ],
        const SizedBox(height: 12),
        for (final row in (research['sources'] is List ? research['sources'] as List : []))
          if (row is Map) SelectableText('Kaynak: ${row['title']} · ${row['url']} · ${row['publishedAt']}'),
        const SizedBox(height: 16),
        if(data['source']=='CLIENT_READ_ONLY_HISTORY') const Text('Hafıza mevcut sunucunun kendi gönderi kayıtlarından hazırlanıyor. Merkezi reklam ölçümü henüz yok.'),
        Text('İçerik: ${data['postCount'] ?? 0} · Yayınlanan: ${data['publishedCount'] ?? 0} · Ölçüm: ${performance['recordCount'] ?? 0}'),
        for (final mode in ['organic']) ...[
          const SizedBox(height: 12),
          Text(mode == 'paid' ? 'Reklam saat geçmişi' : 'Gönderi saat geçmişi',
            style: const TextStyle(fontWeight: FontWeight.bold)),
          if (timing[mode] is Map) ...[
            Text('${(timing[mode] as Map)['reason'] ?? ''}'),
            Text('Örnek: ${(timing[mode] as Map)['sampleSize'] ?? 0}'),
            for (final row in ((timing[mode] as Map)['evidence'] is List
                ? (timing[mode] as Map)['evidence'] as List : []))
              if (row is Map)
                Text('Gün ${row['weekday']} · ${row['hour']}:00 · ${row['sampleSize']} örnek · skor ${row['score']}'),
          ],
        ],
        const SizedBox(height: 16),
        const Text('Kaydettiğin metinler', style: TextStyle(fontWeight: FontWeight.bold)),
        if (posts.isEmpty) const Text('Henüz kaydedilmiş içerik yok.'),
        for (final row in posts.take(10))
          if (row is Map) Card(child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('${row['title'] ?? 'İçerik'} · ${row['mediaType'] ?? ''} · ${row['status'] ?? ''}'),
              Text('${row['caption'] ?? ''}'),
              if (row['selectedTime'] is Map)
                Text('Seçilen saat: ${(row['selectedTime'] as Map)['scheduledAt'] ?? ''}'),
              if (widget.onUseCaption != null && '${row['caption'] ?? ''}'.isNotEmpty)
                TextButton(onPressed: () => widget.onUseCaption!('${row['caption']}'),
                  child: const Text('Yalnız metni taslağa kopyala')),
            ]))),
        const SizedBox(height: 16),
      ],
    ]);
  }
}
