import 'package:flutter/material.dart';
import 'api.dart';

class LogsPage extends StatefulWidget {
  const LogsPage({super.key});
  @override State<LogsPage> createState()=>_LogsPageState();
}

class _LogsPageState extends State<LogsPage> {
  bool loading=true;
  List<dynamic> logs=[];
  String? error;

  @override void initState(){super.initState();load();}

  Future<void> load() async {
    setState(()=>loading=true);
    try {
      final x=await Api.logs();
      if(mounted)setState(()=>logs=x);
    } catch(e) {
      if(mounted)setState(()=>error=e.toString());
    } finally {if(mounted)setState(()=>loading=false);}
  }

  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Otomasyon Geçmişi')),
    body:loading
      ? const Center(child:CircularProgressIndicator())
      : error!=null
        ? Center(child:Text(error!))
        : RefreshIndicator(
          onRefresh:load,
          child:ListView.builder(
            itemCount:logs.length,
            itemBuilder:(_,i){
              final x=logs[i] as Map;
              final actions=(x['actions'] as List?)??const [];
              return Card(child:ExpansionTile(
                title:Text('${x['at']??x['ranAt']??''}'),
                subtitle:Text('${actions.length} işlem'),
                children:actions.map((a)=>ListTile(
                  title:Text('${a['campaign']??''}'),
                  subtitle:Text('${a['reason']??''}'),
                  trailing:Text('${a['action']??''}'),
                )).toList(),
              ));
            },
          ),
        ),
  );
}
