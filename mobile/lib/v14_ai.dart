import 'package:flutter/material.dart';
import 'api.dart';
import 'app_error.dart';
import 'media_access.dart';
import 'content_queue_page.dart';
import 'product_shell.dart';
import 'manual_memory.dart';

// Class name remains compatible with existing navigation. Content is fully manual.
class AiContentStudioPage extends StatefulWidget {
  final Future<XFile?> Function()? mediaPicker;
  final Future<DateTime?> Function()? schedulePicker;
  const AiContentStudioPage({super.key, this.mediaPicker, this.schedulePicker});
  @override
  State<AiContentStudioPage> createState() => _AiContentStudioPageState();
}
class _AiContentStudioPageState extends State<AiContentStudioPage> {
  final title = TextEditingController(), caption = TextEditingController(), aiDraft = TextEditingController();
  XFile? media;
  String format = 'POST';
  DateTime? schedule;
  bool busy = false, aiBusy = false, canOperate = false, accessStarted = false;
  String aiTask = 'AD_COPY';
  bool uncertain = false, confirming = false;
  String? savedId, savedStatus, error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = ProductNavigation.maybeOf(context);
    if (scope != null) {
      canOperate = scope.canOperate;
    } else if (!accessStarted) {
      accessStarted = true;
      _loadAccess();
    }
  }
  Future<void> _loadAccess() async {
    try {
      final me = await Api.me();
      if (mounted) setState(() => canOperate =
        ['ADMIN','CUSTOMER_ADMIN','MANAGER','OPERATOR']
          .contains((me['user'] as Map?)?['role']));
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    }
  }
  @override
  void dispose() { title.dispose(); caption.dispose(); aiDraft.dispose(); super.dispose(); }
  bool get editable => canOperate && !busy && !aiBusy && !confirming && savedId == null && !uncertain;
  Future<void> _pick() async {
    if (!editable) return;
    try {
      final file = await (widget.mediaPicker != null
        ? widget.mediaPicker!()
        : MediaAccess.pickOne(mediaType: format == 'REELS' ? 'VIDEO' : 'IMAGE'));
      if (file == null || !mounted) return;
      final isImage = MediaAccess.isImage(file);
      if ((format == 'POST') != isImage) {
        setState(() => error = 'Fotoğraf için görsel, Reels için video seçin.');
        return;
      }
      if (await file.length() > 100 * 1024 * 1024) {
        if (mounted) setState(() => error = 'Dosya en fazla 100 MB olabilir.');
        return;
      }
      if (mounted) setState(() { media = file; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    }
  }
  Future<void> _pickSchedule() async {
    if (!editable) return;
    DateTime? selected;
    if (widget.schedulePicker != null) {
      selected = await widget.schedulePicker!();
    } else {
      final now = DateTime.now();
      final day = await showDatePicker(context: context,
        initialDate: schedule ?? now.add(const Duration(days: 1)),
        firstDate: DateTime(now.year,now.month,now.day),
        lastDate: now.add(const Duration(days: 365)));
      if (day == null || !mounted) return;
      final time = await showTimePicker(context: context,
        initialTime: schedule == null ? const TimeOfDay(hour:19,minute:0)
          : TimeOfDay.fromDateTime(schedule!));
      if (time == null) return;
      selected = DateTime(day.year,day.month,day.day,time.hour,time.minute);
    }
    if (!mounted || selected == null) return;
    if (!selected.isAfter(DateTime.now())) {
      setState(() => error = 'Yayın saati gelecekte olmalı.');
      return;
    }
    setState(() { schedule = selected; error = null; });
  }
  Future<void> _runAi() async {
    if (!editable || media == null) return;
    setState(() { aiBusy = true; error = null; });
    try {
      final baseInput = <String, dynamic>{
          'title': title.text.trim(),
          'context': caption.text.trim(),
          'mediaType': format,
          'allowHashtags': false,
        };
      Map<String, dynamic> result;
      if (aiTask == 'AD_COPY') {
        // The copy request must carry the analysis; this prevents a generic
        // text-only prompt from losing the selected image's subject.
        final analysis = await Api.contentStudioAiFromFile(media!.path,
          mediaFile: media, task: 'ANALYZE', input: baseInput);
        final analysisText = analysis['text']?.toString().trim() ?? '';
        if (analysisText.isEmpty) {
          throw const FormatException('Görsel güvenilir biçimde tanımlanamadı. Ürün veya hizmet bilgisini girin.');
        }
        result = await Api.contentStudioAi(task: 'AD_COPY', input: {
          ...baseInput,
          'analysis': analysisText,
          'requireGrounded': true,
        });
      } else {
        result = await Api.contentStudioAiFromFile(media!.path,
          mediaFile: media, task: aiTask, input: baseInput);
      }
      final text = result['text']?.toString().trim() ?? '';
      if (text.isEmpty) throw const FormatException('Gemini taslak üretmedi.');
      if (mounted) setState(() { aiDraft.text = text; error = null; });
    } catch (e) {
      if (mounted) setState(() => error = AppError.message(e));
    } finally {
      if (mounted) setState(() => aiBusy = false);
    }
  }
  Future<void> _save() async {
    if (!editable || media == null) return;
    if (caption.text.trim().isEmpty) {
      setState(() => error = 'Gönderi açıklamasını yazın.');
      return;
    }
    if (schedule != null && !schedule!.isAfter(DateTime.now())) {
      setState(() => error = 'Yayın saati geçmişte kaldı. Yeni saat seçin.');
      return;
    }
    setState(() { confirming = true; error = null; });
    try {
      final accepted = await showDialog<bool>(context: context, builder: (ctx) =>
        AlertDialog(title: const Text('İçeriği kaydet'),
          content: Text(schedule == null
            ? 'Medya ve açıklama taslak olarak kaydedilecek. Instagram yayını başlatılmaz.'
            : 'Medya, açıklama ve seçtiğin saat READY olarak kaydedilecek. Otomatik yayın kapalıdır.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx,false),
              child: const Text('Vazgeç')),
            FilledButton(onPressed: () => Navigator.pop(ctx,true),
              child: const Text('Yayın yapmadan kaydet')),
          ]));
      if (accepted != true || !mounted) return;
      setState(() { confirming = false; busy = true; });
      final row = await Api.uploadPost(media!.path,
        title.text.trim().isEmpty ? media!.name : title.text.trim(),
        caption.text.trim(), '', mediaFile: media,
        autoPublish: false, useAI: false,
        mediaType: format == 'REELS' ? 'VIDEO' : 'IMAGE',
        scheduleAt: schedule?.toUtc().toIso8601String() ?? '');
      if (!mounted) return;
      final id = row['id']?.toString() ?? '';
      if (id.isEmpty || row['autoPublish'] != false ||
          !['MANUAL','READY'].contains(row['publishStatus'])) {
        setState(() { uncertain = true;
          error = 'Kayıt sonucu beklenenden farklı. Tekrar yüklemeden İçerik Kuyruğu’nu kontrol edin.'; });
        return;
      }
      setState(() { savedId = id; savedStatus = row['publishStatus'].toString(); });
    } catch (e) {
      if (mounted) setState(() {
        error = '${AppError.message(e)}\nTekrar yüklemeden kuyruğu kontrol edin.';
        uncertain = true;
      });
    } finally {
      if (mounted) setState(() { busy = false; confirming = false; });
    }
  }
  void _queue() => Navigator.push(context,
    MaterialPageRoute(builder: (_) => ContentQueuePage(initialPostId: savedId)));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('İçerik Stüdyosu'), actions: [
      IconButton(onPressed: busy ? null : _queue,
        tooltip: 'İçerik Kuyruğu', icon: const Icon(Icons.calendar_month)),
    ]),
    body: SingleChildScrollView(padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (!canOperate) const Text('Görüntüleme yetkisi'),
        const Text('Fotoğraf veya Reels’i kendin hazırla',
          style: TextStyle(fontWeight: FontWeight.bold,fontSize: 22)),
        const Text('Metni ve yayın saatini sen seç. Kaydetme Instagram paylaşımı başlatmaz.'),
        const SizedBox(height: 16),
        Wrap(spacing: 12,children: [
          for (final item in {'POST':'Fotoğraf','REELS':'Reels'}.entries)
            ChoiceChip(label: Text(item.value), selected: format == item.key,
              onSelected: editable ? (_) => setState(() {
                if (format != item.key) media = null;
                format = item.key; error = null;
              }) : null),
        ]),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: editable ? _pick : null,
          icon: const Icon(Icons.perm_media_outlined),
          label: Text(format == 'REELS' ? 'Reels videosu seç' : 'Fotoğraf seç')),
        if (media != null) ...[
          const SizedBox(height: 12),
          if (MediaAccess.isImage(media!))
            MediaPreview(file: media!,height: 220,width: double.infinity,fit: BoxFit.contain)
          else const ListTile(leading: Icon(Icons.video_library),
            title: Text('Reels videosu seçildi'),
            subtitle: Text('Video dönüştürülmez; yayın uyumluluğu ayrıca doğrulanır.')),
          Text(media!.name),
        ],
        const SizedBox(height: 12),
        TextField(controller: title, enabled: editable,
          decoration: const InputDecoration(labelText: 'Başlık (isteğe bağlı)')),
        const SizedBox(height: 12),
        TextField(controller: caption, enabled: editable,maxLines: 6,
          decoration: const InputDecoration(labelText: 'Gönderi açıklaması ve hashtagler')),
        const SizedBox(height: 14),
        if (canOperate) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('İsteğe bağlı Gemini yardımcısı', style: TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Taslak üretir; Meta reklamı, bütçe, kuyruk ve paylaşım işlemi yapmaz.'),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: aiTask, isExpanded: true, decoration: const InputDecoration(labelText: 'Yardım türü'),
            items: const [
              DropdownMenuItem(value:'ANALYZE',child:Text('Fotoğraf/Reels analizi')),
              DropdownMenuItem(value:'AD_COPY',child:Text('Reklam metni taslağı')),
              DropdownMenuItem(value:'STRATEGY',child:Text('Strateji önerisi')),
            ], onChanged: editable ? (value) { if (value != null) setState(() => aiTask = value); } : null),
          const SizedBox(height: 10),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(onPressed: editable && media != null ? _runAi : null,
            icon: aiBusy ? const SizedBox(width:18,height:18,child:CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.auto_awesome_outlined),
            label: Text(aiBusy ? 'Gemini hazırlanıyor…' : 'Gemini ile taslak hazırla'))),
          if (aiDraft.text.isNotEmpty) ...[
            const SizedBox(height: 10),
            TextField(controller: aiDraft, enabled: editable, maxLines: 8,
              decoration: const InputDecoration(labelText: 'Düzenlenebilir Gemini taslağı')),
            const SizedBox(height: 6),
            SizedBox(width: double.infinity, child: TextButton.icon(onPressed: editable ? () => setState(() => caption.text = aiDraft.text) : null,
              icon: const Icon(Icons.edit_note), label: const Text('Taslağı açıklamaya aktar'))),
          ],
        ]))),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: editable ? _pickSchedule : null,
          icon: const Icon(Icons.schedule),label: const Text('Tarih ve saat seç')),
        if (schedule != null) Text('Cihaz yerel saati: ${schedule!.toLocal()}'),
        const Text('Otomatik yayın kapalı. Saat seçilirse READY; seçilmezse taslak kaydedilir.'),
        const SizedBox(height: 16),
        FilledButton.icon(onPressed: editable && media != null ? _save : null,
          icon: busy ? const SizedBox(width:18,height:18,
            child: CircularProgressIndicator(strokeWidth:2)) : const Icon(Icons.save_outlined),
          label: Text(busy ? 'Kaydediliyor…' : 'Yayın yapmadan kaydet')),
        if (savedId != null) Text('Kaydedildi: $savedStatus'),
        if (error != null) Padding(padding: const EdgeInsets.only(top:12),child: Text(error!)),
        if (savedId != null || uncertain)
          TextButton(onPressed: _queue,child: const Text('Kayıt durumunu kuyruğa bakarak doğrula')),
        const SizedBox(height: 28),
        ManualMemoryPanel(onUseCaption: editable
          ? (text) => setState(() => caption.text = text) : null),
      ])),
  );
}
