import 'dart:convert';
import 'package:flutter/services.dart';
Map<String,dynamic> learnLocalPosts(List<dynamic> input){
 final rows=input.whereType<Map>().toList();
 final words=<String,int>{},seen=<String>{};
 final slots=<String,List<Map<String,dynamic>>>{};
 final examples=<String,List<Map<String,dynamic>>>{};
 for(final row in rows){
  final text='${row['caption']??''}';
  final tokens=text.replaceAll('I','ı').replaceAll('İ','i').toLowerCase()
    .replaceAll(RegExp(r'[^a-zçğıöşü0-9#_\s]'),' ').split(RegExp(r'\s+')).toSet();
  for(final word in tokens.where((w)=>w.length>=3&&!['bir','ile','için','daha','çok'].contains(w))){
   words[word]=(words[word]??0)+1;
  }
  final type='${row['mediaType']??row['format']??'UNKNOWN'}';
  if(text.isNotEmpty){
   final list=examples.putIfAbsent(type,()=>[]);
   if(list.length<5)list.add({'postId':row['id'],'caption':text});
  }
  final result=row['instagramPublishResult'];
  final id='${result is Map?result['id']??'':''}';
  final selected=row['selectedTime'];
  final planned=DateTime.tryParse('${selected is Map?selected['scheduledAt']??'':''}');
  final actual=DateTime.tryParse('${row['publishedAt']??''}');
  if(row['publishStatus']!='PUBLISHED'||row['publishPhase']!='CONFIRMED'||id.isEmpty||
   seen.contains(id)||planned==null||actual==null)continue;
  seen.add(id);
  final local=planned.toUtc().add(const Duration(hours:3));
  const days=['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
  final slot='${days[local.weekday-1]} ${local.hour.toString().padLeft(2,'0')}:${local.minute.toString().padLeft(2,'0')}';
  final delta=actual.difference(planned).inSeconds.abs()/60;
  slots.putIfAbsent(slot,()=>[]).add({'postId':row['id'],'plannedAt':planned.toUtc().toIso8601String(),
   'recordedPublishedAt':actual.toUtc().toIso8601String(),'deltaMinutes':double.parse(delta.toStringAsFixed(1)),
   'aligned':delta<=15});
 }
 final ranked=words.entries.toList()..sort((a,b)=>b.value.compareTo(a.value));
 return {
  'note':'Kendi kayıtlı metinlerin ve medya türü kullanılır; görsel analiz edilmez. Sık kullanım başarı kanıtı değildir.',
  'keywords':ranked.take(20).map((e)=>{'text':e.key,'postCount':e.value}).toList(),
  'captionSuggestions':examples.entries.map((e)=>{'mediaType':e.key,'examples':e.value}).toList(),
  'timingToleranceMinutes':15,
  'timingChecks':slots.entries.map((e){
   final count=e.value.where((row)=>row['aligned']==true).length;
   return {'slot':e.key,'timezone':'Europe/Istanbul','trials':e.value,'alignedCount':count,
    'label':count>=2?'Çift denemeden geçti':'İki uyumlu yayın henüz yok',
    'note':'Kayıtlı yayın saati uyumu; dönüşüm veya reklam başarısı kanıtı değildir.'};
  }).toList(),
 };
}
Future<Map<String,dynamic>> localMemoryFromPosts(List<dynamic> input) async{
 final rows=input.whereType<Map>().toList();
 final library=jsonDecode(await rootBundle.loadString('assets/memory_research.json'));
 return {
  'source':'CLIENT_READ_ONLY_HISTORY','postCount':rows.length,
  'publishedCount':rows.where((row)=>row['publishStatus']=='PUBLISHED').length,
  'performance':{'recordCount':0,'paidCount':0},
  'timing':{'organic':{'sampleSize':0,'reason':'Merkezi performans ölçümü bu sunucu sürümünde yok.'},
   'paid':{'sampleSize':0,'reason':'Reklam mesaj maliyeti henüz ölçülmedi.'}},
  'research':library,'learning':learnLocalPosts(rows),
  'posts':rows.map((row)=>{...row,'status':row['publishStatus']}).toList(),'adHistory':[],
 };
}
