import 'package:flutter/material.dart';
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
  Map<String, dynamic>? result;

  @override
  void dispose() {
    title.dispose();
    contextText.dispose();
    super.dispose();
  }

  Future<void> generate() async {
    if (title.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Önce ürün/başlık gir.')),
      );
      return;
    }

    setState(() => loading = true);
    try {
      result = await Api.generateContentPack(
        title: title.text,
        context: contextText.text,
        tone: tone,
        goal: goal,
        mediaType: media,
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

  Widget box(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F7FA),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          SelectableText(
            value.isEmpty ? '-' : value,
            style: const TextStyle(height: 1.4),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'AI İçerik Stüdyosu',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 36),
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
                  'Başlık ver; metni, hook’u, CTA’yı ve uygun formatı tek seferde üret.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  TextField(
                    controller: title,
                    decoration: const InputDecoration(labelText: 'Ürün / başlık'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contextText,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Ürün hakkında ek bilgi (opsiyonel)',
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: tone,
                    decoration: const InputDecoration(labelText: 'Ton'),
                    items: const [
                      DropdownMenuItem(
                        value: 'samimi ve güven veren',
                        child: Text('samimi ve güven veren'),
                      ),
                      DropdownMenuItem(
                        value: 'premium ve şık',
                        child: Text('premium ve şık'),
                      ),
                      DropdownMenuItem(
                        value: 'enerjik ve hızlı',
                        child: Text('enerjik ve hızlı'),
                      ),
                      DropdownMenuItem(
                        value: 'teknik ve uzman',
                        child: Text('teknik ve uzman'),
                      ),
                    ],
                    onChanged: (v) => setState(() => tone = v ?? tone),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: goal,
                    decoration: const InputDecoration(labelText: 'Amaç'),
                    items: const [
                      DropdownMenuItem(value: 'mesaj', child: Text('mesaj')),
                      DropdownMenuItem(value: 'satın alma', child: Text('satın alma')),
                      DropdownMenuItem(value: 'trafik', child: Text('trafik')),
                      DropdownMenuItem(value: 'etkileşim', child: Text('etkileşim')),
                    ],
                    onChanged: (v) => setState(() => goal = v ?? goal),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: media,
                    decoration: const InputDecoration(labelText: 'Medya / format'),
                    items: const [
                      DropdownMenuItem(value: 'AUTO', child: Text('Otomatik')),
                      DropdownMenuItem(value: 'POST', child: Text('Gönderi')),
                      DropdownMenuItem(value: 'REELS', child: Text('Reels')),
                    ],
                    onChanged: (v) => setState(() => media = v ?? media),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: loading ? null : generate,
                      icon: const Icon(Icons.auto_awesome),
                      label: Text(loading ? 'ÜRETİLİYOR...' : 'AI İLE ÜRET'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (result != null) ...[
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.movie_filter_outlined),
                        const SizedBox(width: 8),
                        const Text(
                          'Format önerisi',
                          style: TextStyle(fontWeight: FontWeight.w900),
                        ),
                        const Spacer(),
                        Text(
                          result!['recommendedFormat']?.toString() ?? '-',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    box('HOOK', result!['hook']?.toString() ?? ''),
                    const SizedBox(height: 8),
                    box('CAPTION', result!['caption']?.toString() ?? ''),
                    const SizedBox(height: 8),
                    box('CTA', result!['cta']?.toString() ?? ''),
                    const SizedBox(height: 8),
                    box(
                      'HASHTAGS',
                      result!['hashtags'] is List
                          ? (result!['hashtags'] as List).join(' ')
                          : result!['hashtags']?.toString() ?? '',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kaynak: ${result!['source'] ?? '-'}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 14),
          const Text(
            'Otomatik akış',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),
          const SizedBox(height: 6),
          const Text(
            'Yüklenen görsel otomatik olarak Gönderi, video ise Reels formatına atanır. Yayın saati mevcut öğrenme modeline göre planlanır; yayın başarısız olursa sınırlı tekrar denemesi yapılır.',
            style: TextStyle(color: Colors.black54, height: 1.45),
          ),
        ],
      ),
    );
  }
}
