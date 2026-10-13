import 'package:flutter_test/flutter_test.dart';
import 'package:advise_digital/publication_tracker.dart';
void main(){
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
