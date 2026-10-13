import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:advise_digital/api.dart';
import 'package:advise_digital/manual_memory.dart';
void main(){
 testWidgets('Memory separates reference suggestions and copies only on explicit choice',(tester) async {
  SharedPreferences.setMockInitialValues({});
  Api.resetRuntimeForTesting();
  final calls=<String>[];String? copied;
  Api.setHttpClientForTesting(MockClient((request)async{
   calls.add('${request.method} ${request.url.path}');
   final body=request.url.path=='/health'
    ? {'ok':true,'apiVersion':16,'capabilities':{'productExperience':true}}
    : {'postCount':0,'posts':[],'research':{
      'disclaimer':'Bu hesapta denenmedi.',
      'hashtagSets':[{'title':'TV','tags':['#TVTamiri'],'reason':'Deneme adayı'}],
      'adDrafts':[{'title':'TV WhatsApp','caption':'Marka ve model gönderin','note':'Ön kontrol gerekli'}],
      'sources':[{'title':'Araştırma','url':'https://example.com/study','publishedAt':'2026-10-13'}]
     }};
   return http.Response(jsonEncode(body),200,headers:{'content-type':'application/json; charset=utf-8'});
  }));
  addTearDown((){Api.setHttpClientForTesting(null);Api.resetRuntimeForTesting();});
  await tester.binding.setSurfaceSize(const Size(1000,1800));
  addTearDown(()=>tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(home:Scaffold(body:SingleChildScrollView(
   child:ManualMemoryPanel(onUseCaption:(value)=>copied=value)))));
  await tester.pumpAndSettle();
  expect(find.text('Bu hesapta denenmedi.'),findsOneWidget);
  expect(find.text('Henüz kaydedilmiş içerik yok.'),findsOneWidget);
  expect(copied,isNull);
  final button=find.text('Yalnız metni taslağa kopyala');
  await tester.ensureVisible(button);await tester.tap(button);await tester.pumpAndSettle();
  expect(copied,'Marka ve model gönderin');
  expect(calls.where((call)=>!call.startsWith('GET ')),isEmpty);
 });
}
