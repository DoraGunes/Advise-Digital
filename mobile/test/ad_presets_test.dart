import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:advise_digital/ad_presets.dart';
import 'package:advise_digital/api.dart';
import 'package:advise_digital/manual_memory_local.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 setUp((){SharedPreferences.setMockInitialValues({});Api.resetRuntimeForTesting();});
 tearDown((){Api.setHttpClientForTesting(null);Api.resetRuntimeForTesting();});
 test('Saved campaign configuration survives restart and stays scoped, paused and without auto-replies',()async{
  final seeds=await AdPresets.load('own');
  expect(seeds.length,5);
  await AdPresets.save('own',{...seeds[3],'name':'Benim Reels kipim','dailyBudget':100,'activate':true,'autoReply':true});
  final own=await AdPresets.load('own');
  expect(own.length,6);expect(own.last['dailyBudget'],100);
  expect(own.last['destination'],'WHATSAPP');expect(own.last['activate'],false);
  expect(own.last['autoReply'],false);expect((own.last['radius'] as Map)['radius'],200);
  expect((await AdPresets.load('other')).length,5);
 });
 test('Old server cannot receive a preset ad POST with ignored settings',()async{
  final calls=<String>[];
  Api.setHttpClientForTesting(MockClient((request)async{
   calls.add('${request.method} ${request.url.path}');
   return http.Response(jsonEncode({'ok':true,'apiVersion':16,'capabilities':{'productExperience':true,'adCreateSaga':true}}),200);
  }));
  await expectLater(Api.createAdFromInstagramPost(instagramMediaId:'fixture',campaignName:'fixture',
   adSetName:'fixture',adName:'fixture',dailyBudget:120,requestId:'fixture-request-123',
   presetId:'service-all',destination:'WHATSAPP',locationMode:'RADIUS'),throwsA(isA<ApiException>()));
  expect(calls.where((row)=>row.startsWith('POST')),isEmpty);
 });
 test('Old backend memory fallback uses tenant-authenticated GET posts without pretending measurements exist',()async{
  Api.setHttpClientForTesting(MockClient((request)async{
   if(request.url.path=='/api/memory')return http.Response('{}',404);
   return http.Response(jsonEncode({'data':[{'id':'own','caption':'Servis #TVTamiri','mediaType':'REELS','publishStatus':'READY'}]}),200);
  }));
  final result=await Api.localMemory();
  expect(result['source'],'CLIENT_READ_ONLY_HISTORY');expect(result['postCount'],1);
  expect((result['performance'] as Map)['recordCount'],0);
 });
 test('Local duplicate publication records do not earn double-trial badge',(){
  final row={'id':'a','caption':'TV servis','mediaType':'REELS','publishStatus':'PUBLISHED','publishPhase':'CONFIRMED',
    'selectedTime':{'scheduledAt':'2026-10-07T16:30:00Z'},'publishedAt':'2026-10-07T16:31:00Z',
    'instagramPublishResult':{'id':'one-provider'}};
  final result=learnLocalPosts([row,{...row,'id':'b'}]);
  expect((result['timingChecks'] as List).single['alignedCount'],1);
 });
}
