import 'package:flutter/material.dart';

import 'api.dart';

class KeyPage extends StatefulWidget {
  const KeyPage({super.key});

  @override
  State<KeyPage> createState() => _KeyPageState();
}

class _KeyPageState extends State<KeyPage> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _testing = false;
  bool? _connected;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    _controller.text = await Api.baseUrl();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Backend adresini gir.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
      _connected = null;
    });
    try {
      await Api.setBaseUrl(value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Backend adresi kaydedildi.')));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _test() async {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Önce backend adresini gir.');
      return;
    }
    await Api.setBaseUrl(value);
    setState(() {
      _testing = true;
      _connected = null;
      _error = null;
    });
    final ok = await Api.health();
    if (mounted) setState(() {
      _testing = false;
      _connected = ok;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bağlantı Ayarları', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(colors: [Color(0xFF252A5A), Color(0xFF4F46E5)]),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cihaz bağlantısı', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                SizedBox(height: 6),
                Text('Advise Digital backend sunucusuna bağlan. Telefon ile bilgisayar aynı ağda olmalı.', style: TextStyle(color: Colors.white70, height: 1.4)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE9EAF1))),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Backend adresi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
                const SizedBox(height: 7),
                Text('Gerçek telefon örneği: http://192.168.1.61:3001', style: TextStyle(color: Colors.grey.shade700)),
                const SizedBox(height: 12),
                TextField(controller: _controller, keyboardType: TextInputType.url, autocorrect: false, decoration: InputDecoration(labelText: 'Backend URL', hintText: 'http://192.168.1.61:3001', errorText: _error)),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: OutlinedButton.icon(onPressed: _testing ? null : _test, icon: _testing ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.wifi_tethering_rounded), label: const Text('BAĞLANTIYI TEST ET'))),
                    const SizedBox(width: 8),
                    Expanded(child: FilledButton.icon(onPressed: _saving ? null : _save, icon: const Icon(Icons.save_rounded), label: const Text('KAYDET'))),
                  ],
                ),
                if (_connected != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: _connected! ? const Color(0xFFEAF8EE) : const Color(0xFFFFF0F0), borderRadius: BorderRadius.circular(12)),
                    child: Row(
                      children: [
                        Icon(_connected! ? Icons.check_circle : Icons.error_outline, color: _connected! ? const Color(0xFF11753A) : const Color(0xFFB42318)),
                        const SizedBox(width: 8),
                        Expanded(child: Text(_connected! ? 'Backend bağlantısı başarılı.' : 'Backend adresine ulaşılamadı.', style: const TextStyle(fontWeight: FontWeight.w700))),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          const _ConnectionHelpCard(),
          const SizedBox(height: 18),
          const _PoweredBy(),
        ],
      ),
    );
  }
}

class _ConnectionHelpCard extends StatelessWidget {
  const _ConnectionHelpCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0xFFE9EAF1))),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Kontrol listesi', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
          SizedBox(height: 9),
          Text(
            '1. Backend PowerShell penceresinde çalışıyor olmalı.\n2. Telefon ve bilgisayar aynı Wi‑Fi üzerinde olmalı.\n3. Windows Firewall 3001 portuna izin vermeli.\n4. Android emülatörde 10.0.2.2:3001 kullanılır.',
            style: TextStyle(height: 1.55),
          ),
        ],
      ),
    );
  }
}

class _PoweredBy extends StatelessWidget {
  final bool compact;
  const _PoweredBy({this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_rounded, size: compact ? 12 : 14, color: Colors.grey.shade500),
          const SizedBox(width: 4),
          Text('Powered by Advise Digital', style: TextStyle(fontSize: compact ? 10 : 11, fontWeight: FontWeight.w700, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}
