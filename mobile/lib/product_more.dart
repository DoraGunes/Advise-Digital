import 'package:flutter/material.dart';
import 'main.dart' show AccountPage;
import 'key_page.dart';
import 'product_shell.dart';
import 'product_ui.dart';
import 'v78_pages.dart' show MetaConnectionPage;
class ProductMorePage extends StatelessWidget {
  const ProductMorePage({super.key});
  @override
  Widget build(BuildContext context) {
    final nav = ProductNavigation.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap ve bağlantı')),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text('Fotoğraf ve Reels içeriklerini hazırla, kuyruğa kaydet ve sırayla elle paylaş. Reklamlarını Meta Reklam Yöneticisi üzerinden yönet.'),
        const SizedBox(height: 20),
        ListTile(leading: const Icon(Icons.link), title: const Text('Instagram bağlantısı'),
          onTap: () => nav.open(const MetaConnectionPage())),
        ListTile(leading: const Icon(Icons.person_outline), title: const Text('Hesabım'),
          onTap: () => nav.open(const AccountPage())),
        ListTile(leading: const Icon(Icons.settings_ethernet), title: const Text('API bağlantısı'),
          onTap: () => nav.open(const KeyPage())),
        ListTile(leading: const Icon(Icons.contrast), title: const Text('Tema değiştir'),
          onTap: () => ProductThemeController.toggle(context)),
        const Divider(),
        const Text('Kaydetmek yayın başlatmaz. Belirsiz yayın sonucunda tekrar paylaşmak yerine kayıt durumunu yenile.'),
        TextButton.icon(onPressed: nav.onLogout, icon: const Icon(Icons.logout), label: const Text('Çıkış yap')),
      ]),
    );
  }
}
