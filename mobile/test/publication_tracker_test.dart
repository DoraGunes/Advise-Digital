import 'dart:convert';
import 'package:advise_digital/api.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:advise_digital/publication_tracker.dart';
void main(){
 test('Persistent pending marker prevents another POST after client restart',() async {
  SharedPreferences.setMockInitialValues({});
  Api.resetRuntimeForTesting();
  await Api.setBaseUrl('https://fixture.test');
  var writes=0,gets=0;
  Api.setHttpClientForTesting(MockClient((request)async{
   if(request.method=='POST'){writes++;throw Exception('connection lost');}
   gets++;
   return http.Response(jsonEncode({'data':[{'id':'fixture','publishStatus':gets==1?'READY':'PUBLISHED'}]}),
     200,headers:{'content-type':'application/json'});
  }));
  addTearDown((){Api.setHttpClientForTesting(null);Api.resetRuntimeForTesting();});
  final first=await Api.publishPost('fixture',cancelled:()=>gets>0,pause:()async{});
  expect(first['publishStatus'],'PUBLISH_UNKNOWN');
  expect(await Api.pendingPublications(),contains('fixture'));
  Api.resetRuntimeForTesting();
  final second=await Api.publishPost('fixture',pause:()async{});
  expect(second['publishStatus'],'PUBLISHED');
  expect(writes,1);expect(await Api.pendingPublications(),isEmpty);
 });

 test('Lost publish response followed by confirmed GET does not resubmit',() async{
  var writes=0,gets=0,confirmed=0;
  final result=await PublicationTracker.follow(id:'post',submit:true,
    send:() async{writes++;throw Exception('socket lost');},
    read:()async{gets++;return {'id':'post','publishStatus':gets<2?'READY':'PUBLISHED'};},
    confirmed:()async{confirmed++;},pause:()async{});
  expect(result['publishStatus'],'PUBLISHED');expect(writes,1);expect(gets,2);expect(confirmed,1);
 });
 test('Missing or stale reads never authorize a second publication',()async{
  var writes=0,confirmed=0;
  final result=await PublicationTracker.follow(id:'post',submit:true,reads:3,
    send:()async{writes++;throw Exception('timeout');},
    read:()async=>{'id':'post','publishStatus':'READY'},
    confirmed:()async{confirmed++;},pause:()async{});
  expect(result['publishStatus'],'PUBLISH_UNKNOWN');expect(writes,1);expect(confirmed,0);
 });
 test('Reopened pending operation checks only GET and confirms old publication',()async{
  var writes=0;
  final result=await PublicationTracker.follow(id:'post',submit:false,
    send:()async{writes++;return {};},read:()async=>{'id':'post','publishStatus':'PUBLISHED'},
    confirmed:()async{});
  expect(result['publishStatus'],'PUBLISHED');expect(writes,0);
 });
}
