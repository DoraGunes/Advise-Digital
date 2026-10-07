import 'package:flutter/material.dart';

import 'main.dart' show AccountPage, HelpPage, SettingsPage, UsersPage;
import 'product_modules.dart';
import 'product_onboarding.dart';
import 'product_shell.dart';
import 'product_ui.dart';
import 'v78_pages.dart';
import 'v13_pro.dart' show ABTestPage, BudgetSimulatorPage, UtmBuilderPage;

class ProductMorePage extends StatelessWidget {
  const ProductMorePage({super.key});

  @override
  Widget build(BuildContext context) {
    final navigation = ProductNavigation.of(context);
    final groups = <(String, List<_MoreItem>)>[
      (
        'İşletmeni büyüt',
        [
          _MoreItem('Raporlar', 'Harcama ve sonuçlarını incele',
              Icons.bar_chart_rounded, const ProductReportsPage()),
          _MoreItem('CRM ve fırsatlar', 'Müşteri görüşmelerini takip et',
              Icons.people_outline_rounded, const ProductCrmPage()),
          _MoreItem('Medya kütüphanesi', 'İçeriklerini tek yerde bul',
              Icons.photo_library_outlined, const MediaLibraryPage()),
          _MoreItem('AdVise öğreniyor', 'Deneyimlerinden gelen öneriler',
              Icons.psychology_outlined, const MemoryInsightsPage()),
        ]
      ),
      (
        'Çalışma alanı',
        [
          _MoreItem('Otomasyon', 'Kurallar, limitler ve kararlar',
              Icons.tune_rounded, const ProductAutomationPage()),
          _MoreItem('Meta ve Instagram', 'Bağlantını ve hesaplarını kontrol et',
              Icons.link_rounded, const MetaConnectionPage()),
          _MoreItem(
              'Bildirimler',
              'İçerik ve reklam gelişmeleri',
              Icons.notifications_none_rounded,
              const ProductNotificationsPage()),
          if (navigation.canManage)
            _MoreItem('İşletme kurulumu', 'İşletme bilgilerini tamamla',
                Icons.checklist_rounded, const ProductOnboardingPage()),
          if (navigation.canManage)
            _MoreItem('Ekip', 'Kullanıcılar ve yetkiler', Icons.groups_outlined,
                const UsersPage()),
          _MoreItem('Abonelik', 'Paket, süre ve kullanım limitleri',
              Icons.workspace_premium_outlined, const BillingPage()),
        ]
      ),
      (
        'Hesap ve araçlar',
        [
          _MoreItem('Hesabım', 'Şifre ve hesap bilgileri',
              Icons.person_outline_rounded, const AccountPage()),
          if (navigation.canManage)
            _MoreItem(
                'Ayarlar',
                'Yayınlama ve çalışma tercihleri',
                Icons.settings_outlined,
                SettingsPage(admin: navigation.isAdmin)),
          _MoreItem('Bütçe planlama', 'Bir test bütçesini hesapla',
              Icons.calculate_outlined, const BudgetSimulatorPage()),
          _MoreItem('Bağlantı takibi', 'UTM içeren paylaşım bağlantıları',
              Icons.add_link_rounded, const UtmBuilderPage()),
          if (navigation.canOperate)
            _MoreItem('Kreatif deneyleri', 'A/B test kayıtlarını takip et',
                Icons.science_outlined, const ABTestPage()),
          _MoreItem('Yardım', 'AdVise kullanım rehberi',
              Icons.help_outline_rounded, const HelpPage()),
        ]
      ),
      if (navigation.isAdmin)
        (
          'Sistem yönetimi • yalnızca Super Admin',
          [
            _MoreItem('Müşteri hesapları', 'Tenant ve abonelik yönetimi',
                Icons.business_outlined, const AdminCustomersPage()),
            _MoreItem('Lisanslar', 'Lisans oluşturma ve atama',
                Icons.vpn_key_outlined, const AdminLicensesPage()),
            _MoreItem('Ticari merkez', 'Plan ve operasyon özeti',
                Icons.storefront_outlined, const CommercialCenterPage()),
            _MoreItem('Sistem tanılama', 'API ve bağlantı durumu',
                Icons.health_and_safety_outlined, const DiagnosticsPage()),
            _MoreItem('Güvenlik', 'Altyapı ve oturum bilgileri',
                Icons.security_outlined, const SecurityPage()),
          ]
        ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Daha Fazla'), actions: [
        IconButton(
            tooltip: 'Tema değiştir',
            onPressed: () => ProductThemeController.toggle(context),
            icon: const Icon(Icons.contrast_rounded))
      ]),
      body: ProductContent(
          child: ListView(padding: const EdgeInsets.all(24), children: [
        const ProductPageHeader(
            title: 'Çalışma alanın',
            subtitle: 'Raporlar, hesabın ve ihtiyaç duyduğun araçlar.'),
        const SizedBox(height: 24),
        for (final group in groups) ...[
          Text(group.$1, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          LayoutBuilder(builder: (context, box) {
            final columns = box.maxWidth >= 900
                ? 3
                : box.maxWidth >= 550
                    ? 2
                    : 1;
            final width = (box.maxWidth - (columns - 1) * 12) / columns;
            return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: group.$2
                    .map((item) => SizedBox(
                        width: width,
                        child: Card(
                            child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 10),
                          leading: Icon(item.icon,
                              color: Theme.of(context).colorScheme.primary),
                          title: Text(item.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(item.description),
                          trailing:
                              const Icon(Icons.chevron_right_rounded, size: 20),
                          onTap: () => navigation.open(item.page),
                        ))))
                    .toList());
          }),
          const SizedBox(height: 28),
        ],
        ProductSurface(
            child: Row(children: [
          const Icon(Icons.palette_outlined),
          const SizedBox(width: 12),
          const Expanded(child: Text('Görünüm')),
          DropdownButton<ProductThemeMode>(
              value: ProductThemeController.mode.value,
              underline: const SizedBox.shrink(),
              items: const [
                DropdownMenuItem(
                    value: ProductThemeMode.system, child: Text('Sistem')),
                DropdownMenuItem(
                    value: ProductThemeMode.light, child: Text('Açık')),
                DropdownMenuItem(
                    value: ProductThemeMode.dark, child: Text('Koyu')),
                DropdownMenuItem(
                    value: ProductThemeMode.colorful, child: Text('Renkli'))
              ],
              onChanged: (value) {
                if (value != null)
                  ProductThemeController.change(context, value);
              })
        ])),
        const SizedBox(height: 16),
        OutlinedButton.icon(
            onPressed: navigation.onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Çıkış yap')),
        const SizedBox(height: 24),
      ])),
    );
  }
}

class _MoreItem {
  final String title, description;
  final IconData icon;
  final Widget page;
  const _MoreItem(this.title, this.description, this.icon, this.page);
}
