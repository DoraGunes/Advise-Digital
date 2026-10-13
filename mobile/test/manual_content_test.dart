import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advise_digital/api.dart';
import 'package:advise_digital/v14_ai.dart';
import 'package:advise_digital/media_access.dart';
import 'package:advise_digital/product_shell.dart';
import 'package:advise_digital/social_ads_page.dart';
import 'package:advise_digital/product_ui.dart';

void main() {
  late List<String> requests;
  late String multipart;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    Api.resetRuntimeForTesting();
    requests = []; multipart = '';
    Api.setHttpClientForTesting(MockClient((request) async {
      requests.add('${request.method} ${request.url.path}');
      dynamic data = switch(request.url.path) {
        '/health' => {'ok':true,'apiVersion':16,'version':'16.1.0',
          'capabilities':{'productExperience':true,'scheduledPublishing':true,'adCreateSaga':true}},
        '/api/me' => {'user':{'id':'fixture-user','role':'OPERATOR'},'tenant':{'id':'fixture-tenant'}},
        '/api/memory' => {'postCount':2,'publishedCount':2,'posts':[],
          'performance':{'recordCount':0,'paidCount':0},
          'timing':{'organic':{'sampleSize':0,'reason':'Henüz ölçüm yok.'},
            'paid':{'sampleSize':0,'reason':'Henüz ölçüm yok.'}}},
        '/api/instagram/media' => {'data':[{'id':'fixture-media','caption':'Kendi metnim','media_type':'IMAGE'}]},
        '/api/ads/targeting-options' => {'mode':'COUNTRY','cities':[],'regions':[],'locations':[]},
        _ => {},
      };
      if (request.url.path == '/api/posts' && request.method == 'POST') {
        multipart = utf8.decode(request.bodyBytes,allowMalformed:true);
        data = {'id':'fixture-post','autoPublish':false,'publishStatus':'READY'};
      }
      return http.Response(jsonEncode(data),200,
        headers:{'content-type':'application/json; charset=utf-8'});
    }));
  });
  tearDown(() { Api.setHttpClientForTesting(null); Api.resetRuntimeForTesting(); });

  Widget host(AiContentStudioPage page,{String role='OPERATOR'}) => MaterialApp(
    theme: ProductTheme.light,
    home: ProductNavigation(user:{'role':role},tenant:const {},
      go:(_){},open:(_) async {},onLogout:() async {},child:page));

  Future<void> save(WidgetTester tester) async {
    final button=find.widgetWithText(FilledButton,'Yayın yapmadan kaydet');
    await tester.ensureVisible(button);await tester.tap(button);await tester.pumpAndSettle();
    await tester.tap(find.descendant(of:find.byType(AlertDialog),
      matching:find.widgetWithText(FilledButton,'Yayın yapmadan kaydet')));
    await tester.pumpAndSettle();
  }
  for (final reels in [false,true]) {
    testWidgets('manual ${reels ? 'Reels' : 'photo'} saves user caption and schedule without AI or publication',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900,1500));
        addTearDown(()=>tester.binding.setSurfaceSize(null));
        final Uint8List bytes=reels ? Uint8List.fromList([0,0,0,24,102,116,121,112])
          : base64Decode('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+a9ZkAAAAASUVORK5CYII=');
        final file=XFile.fromData(bytes,name:reels?'fixture.mp4':'fixture.png',
          mimeType:reels?'video/mp4':'image/png');
        final at=DateTime.now().add(const Duration(days:2));
        await tester.pumpWidget(host(AiContentStudioPage(
          mediaPicker:() async=>file,schedulePicker:() async=>at)));
        await tester.pumpAndSettle();
        expect(find.text('AI ile medyayı analiz et'),findsNothing);
        if(reels) { await tester.tap(find.text('Reels'));await tester.pumpAndSettle(); }
        await tester.tap(find.text(reels?'Reels videosu seç':'Fotoğraf seç'));
        await tester.pumpAndSettle();
        expect(requests.where((x)=>x.startsWith('POST')),isEmpty);
        await tester.enterText(find.byType(TextField).at(1),'Kendi açıklamam #poyraz');
        await tester.tap(find.text('Tarih ve saat seç'));await tester.pumpAndSettle();
        await save(tester);
        expect(requests.where((x)=>x.startsWith('POST')).toList(),['POST /api/posts']);
        expect(multipart,contains('Kendi açıklamam #poyraz'));
        expect(multipart,contains(at.toUtc().toIso8601String()));
        expect(multipart,contains('name="useAI"\r\n\r\nfalse'));
        expect(multipart,contains('name="autoPublish"\r\n\r\nfalse'));
        expect(find.text('Kaydedildi: READY'),findsOneWidget);
        expect(requests.where((x)=>x.contains('/api/ai/')||x.contains('/publish')||x.contains('/ads/create')),isEmpty);
      });
  }
  testWidgets('viewer cannot select media or save a manual post',(tester) async {
    await tester.pumpWidget(host(const AiContentStudioPage(),role:'VIEWER'));
    await tester.pumpAndSettle();
    final pick=tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton,'Fotoğraf seç'));
    expect(pick.onPressed,isNull);
    expect(requests.where((x)=>x.startsWith('POST')),isEmpty);
  });
  testWidgets('ad history replaces Gemini strategy and reads without provider writes',(tester) async {
    await tester.binding.setSurfaceSize(const Size(900,1600));
    addTearDown(()=>tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(theme:ProductTheme.light,
      home:const SocialAdsPage(initialMediaId:'fixture-media')));
    await tester.pumpAndSettle();
    final step=find.text('Bağlantı ve geçmiş');
    await tester.ensureVisible(step);await tester.tap(step);await tester.pumpAndSettle();
    final history=find.text('Kendi reklam geçmişimi göster');
    await tester.ensureVisible(history);await tester.tap(history);await tester.pumpAndSettle();
    expect(find.text('Ölçülmüş reklam örneği: 0'),findsOneWidget);
    expect(requests,contains('GET /api/memory'));
    expect(requests.where((x)=>x.startsWith('POST')),isEmpty);
    expect(find.text('AI kampanya önerisi al'),findsNothing);
  });
}
