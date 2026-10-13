import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class AdPresets {
 static const version=1;
 static const seeds=<Map<String,dynamic>>[
  {'id':'service-all','name':'Teknik servis · WhatsApp','media':'ANY','placement':'AUTO'},
  {'id':'tv-photo','name':'Televizyon servisi · Fotoğraf','media':'IMAGE','placement':'FEEDS'},
  {'id':'panel-photo','name':'Panel ve ekran · Fotoğraf','media':'IMAGE','placement':'FEEDS'},
  {'id':'service-reels','name':'Servis tanıtımı · Reels','media':'VIDEO','placement':'REELS'},
  {'id':'instagram-reels','name':'Instagram Reels · WhatsApp','media':'VIDEO','placement':'INSTAGRAM_REELS'},
 ];
 static Map<String,dynamic> defaults(Map<String,dynamic> seed)=>{
  ...seed,'version':version,'destination':'WHATSAPP','dailyBudget':120.0,
  'locationMode':'RADIUS','locations':<String>[],
  'radius':{'latitude':40.7356,'longitude':31.6061,'radius':200,'distance_unit':'kilometer'},
  'activate':false,'autoReply':false,'costGoal':[2,3],
 };
 static String key(String scope)=>'manualAdPresets:$scope';
 static Future<List<Map<String,dynamic>>> load(String scope) async {
  final result=seeds.map(defaults).toList();
  final raw=(await SharedPreferences.getInstance()).getString(key(scope));
  try {
   final saved=jsonDecode(raw??'[]');
   if(saved is List) for(final row in saved){
    if(row is Map&&seeds.any((seed)=>seed['id']==row['id'])){
     result.add({...defaults(Map<String,dynamic>.from(row)),...Map<String,dynamic>.from(row),
       'destination':'WHATSAPP','activate':false,'autoReply':false});
    }
   }
  }catch(_) {}
  return result;
 }
 static Future<void> save(String scope,Map<String,dynamic> value) async {
  final budget=double.tryParse('${value['dailyBudget']}');
  if(scope.isEmpty||budget==null||budget<50||budget>120||
    !seeds.any((seed)=>seed['id']==value['id']))throw ArgumentError('Geçerli kip ve 50–120 TL bütçe gerekli.');
  final rows=await load(scope);
  final custom=rows.skip(seeds.length).toList();
  final next={...value,'destination':'WHATSAPP','activate':false,'autoReply':false};
  custom.removeWhere((row)=>row['name']==next['name']);custom.add(next);
  await (await SharedPreferences.getInstance()).setString(key(scope),jsonEncode(custom.take(30).toList()));
 }
 static bool accepts(Map<String,dynamic> preset,Map<String,dynamic> media)=>
  preset['media']=='ANY'||preset['media']==media['media_type'];
}
