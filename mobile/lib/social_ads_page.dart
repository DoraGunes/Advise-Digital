import 'package:flutter/material.dart';

import 'api.dart';

class SocialAdsPage extends StatefulWidget {
  const SocialAdsPage({super.key});

  @override
  State<SocialAdsPage> createState() => _SocialAdsPageState();
}

class _SocialAdsPageState extends State<SocialAdsPage> {
  List<dynamic> media = [];
  Map<String, dynamic>? selected;
  bool loading = true;
  bool creating = false;
  String? error;

  final campaignName = TextEditingController(text: 'AdVise AI Test Kampanyası');
  final adSetName = TextEditingController(text: 'AdVise AI 150 TL Ad Set');
  final adName = TextEditingController(text: 'AdVise AI Instagram Reklamı');
  final budget = TextEditingController(text: '150');
  bool activateAd = true;

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
      if (!mounted) return;
      setState(() {
        media = x;
        loading = false;
        if (selected != null && !media.any((m) => m is Map && m['id']?.toString() == selected!['id']?.toString())) {
          selected = null;
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          loading = false;
          error = e.toString();
        });
      }
    }
  }

  Future<void> _createAd() async {
    final post = selected;
    if (post == null) {
      _snack('Önce reklam vereceğin Instagram gönderisini seç.');
      return;
    }
    final dailyBudget = double.tryParse(budget.text.replaceAll(',', '.'));
    if (dailyBudget == null || dailyBudget < 1) {
      _snack('Günlük bütçe geçersiz.');
      return;
    }

    setState(() => creating = true);
    try {
      final result = await Api.createAdFromInstagramPost(
        instagramMediaId: post['id'].toString(),
        campaignName: campaignName.text.trim(),
        adSetName: adSetName.text.trim(),
        adName: adName.text.trim(),
        dailyBudget: dailyBudget,
        activate: activateAd,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reklam oluşturuldu'),
          content: SelectableText(
            'Kampanya: ${result['campaign']?['id'] ?? '-'}\n'
            'Ad set: ${result['adset']?['id'] ?? '-'}\n'
            'Reklam: ${result['ad']?['id'] ?? '-'}\n'
            'Durum: ${result['activated'] == true ? 'ACTIVE' : 'PAUSED'}',
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
      if (mounted) _snack(e.toString());
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
    final url = (type == 'VIDEO' ? item['thumbnail_url'] : item['media_url'])?.toString() ?? '';
    if (!url.startsWith('http')) {
      return Container(
        height: height,
        alignment: Alignment.center,
        color: const Color(0xFFF0F1F6),
        child: Icon(type == 'VIDEO' ? Icons.video_library_outlined : Icons.photo_outlined, size: 64),
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Instagram & Reklamlar', style: TextStyle(fontWeight: FontWeight.w900)),
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menü',
            icon: const Icon(Icons.menu_rounded),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            onPressed: loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 20, 18, 14),
                child: Text('ADVISE DIGITAL', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.home_outlined),
                title: const Text('Ana sayfa'),
                onTap: () => Navigator.of(context).popUntil((route) => route.isFirst),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Instagram gönderileri'),
                selected: true,
                onTap: () => Navigator.pop(context),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 16, 18, 6),
                child: Text('SEÇİLİ GÖNDERİ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900)),
              ),
              ListTile(
                leading: Icon(selected == null ? Icons.info_outline : Icons.check_circle_outline),
                title: Text(selected == null ? 'Gönderi seçilmedi' : 'Reklam için seçildi'),
                subtitle: selected == null ? null : Text(selected!['id']?.toString() ?? '-'),
              ),
            ],
          ),
        ),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
                children: [
                  _hero(),
                  const SizedBox(height: 14),
                  if (error != null)
                    _info('Instagram verisi alınamadı', error!, Icons.cloud_off_outlined)
                  else ...[
                    const Text('Instagram gönderilerin', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text(
                      'Reklam vereceğin gönderiyi seç. Önizleme ve açıklama burada görünür.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 12),
                    if (media.isEmpty)
                      _info('Gönderi bulunamadı', 'Bağlı Instagram hesabında görüntülenebilir medya yok.', Icons.photo_library_outlined),
                    ...media.take(50).map((item) {
                      final m = Map<String, dynamic>.from(item as Map);
                      final isSelected = selected?['id']?.toString() == m['id']?.toString();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _preview(m),
                              Padding(
                                padding: const EdgeInsets.all(13),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _mediaType(m),
                                            style: const TextStyle(fontWeight: FontWeight.w900),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Chip(label: Text('SEÇİLDİ'), avatar: Icon(Icons.check, size: 18)),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      m['caption']?.toString().trim().isNotEmpty == true ? m['caption'].toString() : 'Açıklama yok',
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 7),
                                    Text(
                                      '${_date(m['timestamp'])}  •  ID: ${m['id'] ?? '-'}',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                    const SizedBox(height: 10),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: () => setState(() => selected = m),
                                        icon: Icon(isSelected ? Icons.check_circle : Icons.campaign_outlined),
                                        label: Text(isSelected ? 'REKLAM İÇİN SEÇİLDİ' : 'BU GÖNDERİYLE REKLAM VER'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                  const SizedBox(height: 12),
                  _adBuilder(),
                ],
              ),
            ),
    );
  }

  Widget _hero() => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF252A5A), Color(0xFF4F46E5)],
          ),
        ),
        child: const Row(
          children: [
            Icon(Icons.campaign_outlined, color: Colors.white, size: 38),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Instagram gönderisinden reklam', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w900)),
                  SizedBox(height: 5),
                  Text('Gönderiyi seç → bütçeyi belirle → kampanya oluştur → reklamı yayınla.', style: TextStyle(color: Colors.white70, height: 1.35)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _adBuilder() {
    final post = selected;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Reklam oluştur', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
            const SizedBox(height: 5),
            Text(
              post == null
                  ? 'Önce yukarıdan bir Instagram gönderisi seç.'
                  : 'Seçilen gönderi: ${post['id'] ?? '-'}',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            if (post != null) ...[
              const SizedBox(height: 12),
              ClipRRect(borderRadius: BorderRadius.circular(16), child: _preview(post, height: 150)),
              const SizedBox(height: 12),
              TextField(controller: campaignName, decoration: const InputDecoration(labelText: 'Kampanya adı')),
              const SizedBox(height: 10),
              TextField(controller: adSetName, decoration: const InputDecoration(labelText: 'Ad set adı')),
              const SizedBox(height: 10),
              TextField(controller: adName, decoration: const InputDecoration(labelText: 'Reklam adı')),
              const SizedBox(height: 10),
              TextField(
                controller: budget,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Günlük bütçe (TL)', prefixText: '₺ '),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Oluşturunca hemen yayınla'),
                subtitle: const Text('Kapalıysa reklam Meta tarafında PAUSED oluşturulur.'),
                value: activateAd,
                onChanged: creating ? null : (v) => setState(() => activateAd = v),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton.icon(
                  onPressed: creating ? null : _createAd,
                  icon: creating
                      ? const SizedBox(width: 19, height: 19, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.rocket_launch_outlined),
                  label: Text(creating ? 'REKLAM OLUŞTURULUYOR...' : 'REKLAMI OLUŞTUR VE YAYINLA'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _info(String title, String body, IconData icon) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
                    const SizedBox(height: 4),
                    Text(body),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}
