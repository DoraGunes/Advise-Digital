import 'package:flutter/material.dart';

import 'api.dart';
import 'app_error.dart';
import 'config.dart';
import 'product_ui.dart';

class KeyPage extends StatefulWidget {
  const KeyPage({super.key});
  @override
  State<KeyPage> createState() => _KeyPageState();
}

class _KeyPageState extends State<KeyPage> {
  final _controller = TextEditingController();
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _health;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final url = await Api.baseUrl();
    if (mounted) setState(() => _controller.text = url);
  }

  Future<void> _save({bool test = false}) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _health = null;
    });
    try {
      await Api.setBaseUrl(_controller.text.trim());
      final result = test ? await Api.compatibility() : null;
      if (!mounted) return;
      setState(() => _health = result);
      if (!test) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bağlantı adresi kaydedildi.')));
      }
    } catch (e) {
      if (mounted) setState(() => _error = AppError.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Bağlantı ayarları')),
      body: ProductContent(
          maxWidth: 760,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const ProductPageHeader(
                title: 'Çalışma alanının bağlantısı',
                subtitle: 'Uygulamanın bağlandığı sunucuyu kontrol et.'),
            const SizedBox(height: 24),
            const ProductInsightCard(
                title: 'Her cihazdan aynı çalışma alanı',
                body:
                    'AdVise internet üzerinden çalışır. Telefon ve bilgisayarın aynı ağda olması gerekmez. Sunucu adresini yalnızca işletme yöneticinin yönlendirmesiyle değiştir.',
                icon: Icons.cloud_outlined),
            const SizedBox(height: 20),
            ProductSurface(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  TextField(
                      controller: _controller,
                      enabled: !_busy,
                      keyboardType: TextInputType.url,
                      autocorrect: false,
                      decoration: const InputDecoration(
                          labelText: 'Sunucu adresi',
                          hintText: AppConfig.defaultApiBaseUrl,
                          prefixIcon: Icon(Icons.link_outlined))),
                  const SizedBox(height: 12),
                  const Text(
                      'Farklı bir sunucuya geçersen yeniden giriş yapman gerekir.'),
                  const SizedBox(height: 20),
                  Wrap(spacing: 12, runSpacing: 12, children: [
                    FilledButton.icon(
                        onPressed: _busy ? null : () => _save(),
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Kaydet')),
                    OutlinedButton.icon(
                        onPressed: _busy ? null : () => _save(test: true),
                        icon: const Icon(Icons.wifi_tethering_outlined),
                        label: const Text('Bağlantıyı kontrol et')),
                  ]),
                  if (_busy) ...[
                    const SizedBox(height: 16),
                    const LinearProgressIndicator()
                  ],
                ])),
            if (_error != null) ...[
              const SizedBox(height: 20),
              ProductErrorState(message: _error!),
            ],
            if (_health != null) ...[
              const SizedBox(height: 20),
              if (_health!['compatible'] == true)
                const ProductInsightCard(
                    title: 'Bağlantı hazır',
                    body: 'Sunucuya ulaşıldı ve uygulama sürümü destekleniyor.',
                    icon: Icons.check_circle_outline)
              else
                ProductErrorState(
                    message: _health!['message']?.toString() ??
                        'Sunucuya ulaşılamıyor.'),
            ],
          ])));
}
