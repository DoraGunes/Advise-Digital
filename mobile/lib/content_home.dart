import 'package:flutter/material.dart';
import 'api.dart';
import 'app_error.dart';
import 'product_shell.dart';

class ContentHomePage extends StatefulWidget {
  const ContentHomePage({super.key});
  @override
  State<ContentHomePage> createState() => _ContentHomePageState();
}
class _ContentHomePageState extends State<ContentHomePage> {
  List<dynamic> posts = [];
  bool loading = true;
  String? error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { loading = true; error = null; });
    try {
      final rows = await Api.posts();
      if (mounted) setState(() => posts = rows);
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }
  @override
  Widget build(BuildContext context) {
    final nav = ProductNavigation.of(context);
    final published = posts.where((p) => p is Map && p['publishStatus'] == 'PUBLISHED').length;
    final ready = posts.where((p) => p is Map && p['publishStatus'] == 'READY').length;
    final drafts = posts.where((p) => p is Map && p['publishStatus'] == 'MANUAL').length;
    return Scaffold(
      appBar: AppBar(title: const Text('İçerik çalışma alanı'), actions: [
        IconButton(tooltip: 'Kayıtları yenile', onPressed: loading ? null : _load, icon: const Icon(Icons.refresh)),
      ]),
      body: ListView(padding: const EdgeInsets.all(24), children: [
        Text('Hazırla. Sıraya koy. Paylaş.', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 12),
        const Text('Fotoğraf ve Reels için kendi metnini ve saatini seç. Paylaşım yalnızca sen başlattığında yapılır.'),
        const SizedBox(height: 24),
        if (loading) const LinearProgressIndicator()
        else if (error != null) Text(error!)
        else Text('Taslak: $drafts · Yayına hazır: $ready · Yayınlanan: $published'),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: () => nav.go(ProductDestination.studio),
          icon: const Icon(Icons.add_photo_alternate_outlined), label: const Text('Yeni içerik hazırla')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => nav.go(ProductDestination.planner),
          icon: const Icon(Icons.calendar_month), label: const Text('Sıralı içerik kuyruğu')),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: () => nav.go(ProductDestination.ads),
          icon: const Icon(Icons.psychology_outlined), label: const Text('Hafıza Sarayı')),
        const SizedBox(height: 24),
        const Text('Saat seçmek otomatik paylaşım açmaz. Yayın sonucu belirsizse tekrar göndermek yerine kuyrukta durum kontrolü yap.'),
      ]),
    );
  }
}
