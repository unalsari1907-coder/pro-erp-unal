import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/erp_detay_dialog.dart';

class VadeYaslandirmaSayfasi extends StatefulWidget {
  const VadeYaslandirmaSayfasi({super.key});
  @override
  State<VadeYaslandirmaSayfasi> createState() => _VadeYaslandirmaSayfasiState();
}

class _VadeYaslandirmaSayfasiState extends State<VadeYaslandirmaSayfasi> {
  bool _yukleniyor = true;
  final Map<String,double> _grup = {'Vadesi Gelmemiş':0,'1-30 Gün':0,'31-60 Gün':0,'61-90 Gün':0,'90+ Gün':0};
  List<Map<String,dynamic>> _liste=[];
  double _n(dynamic v)=>v is num?v.toDouble():double.tryParse('${v??0}'.replaceAll(',','.'))??0;
  @override void initState(){super.initState();_yukle();}
  Future<void> _yukle() async {
    if(mounted)setState(()=>_yukleniyor=true);
    try{
      final r=await SupabaseService.supabase.from('erp_vade_takip').select().order('gecikme_gun',ascending:false);
      final l=List<Map<String,dynamic>>.from(r as List);
      final g={'Vadesi Gelmemiş':0.0,'1-30 Gün':0.0,'31-60 Gün':0.0,'61-90 Gün':0.0,'90+ Gün':0.0};
      for(final x in l){final gun=_n(x['gecikme_gun']).round();final t=_n(x['kalan_tutar']); if(t<=0)continue; if(gun<=0)g['Vadesi Gelmemiş']=g['Vadesi Gelmemiş']!+t; else if(gun<=30)g['1-30 Gün']=g['1-30 Gün']!+t; else if(gun<=60)g['31-60 Gün']=g['31-60 Gün']!+t; else if(gun<=90)g['61-90 Gün']=g['61-90 Gün']!+t; else g['90+ Gün']=g['90+ Gün']!+t;}
      if(!mounted)return; setState((){_liste=l;_grup..clear()..addAll(g);_yukleniyor=false;});
    }catch(_){if(mounted)setState(()=>_yukleniyor=false);}
  }
  bool _grubaUyar(Map<String,dynamic> x, String grup) {
    final gun=_n(x['gecikme_gun']).round(); final t=_n(x['kalan_tutar']);
    if(t<=0) return false;
    if(grup=='Vadesi Gelmemiş') return gun<=0;
    if(grup=='1-30 Gün') return gun>0 && gun<=30;
    if(grup=='31-60 Gün') return gun>30 && gun<=60;
    if(grup=='61-90 Gün') return gun>60 && gun<=90;
    return gun>90;
  }

  Future<void> _grupDetay(String grup) async {
    final rows=_liste.where((x)=>_grubaUyar(x,grup)).toList();
    if(rows.isEmpty){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$grup için açık kayıt yok.')));return;}
    await showDialog<void>(context:context,builder:(ctx)=>AlertDialog(
      title:Text('$grup • Vade Detayı (${rows.length})'),
      content:SizedBox(width:MediaQuery.sizeOf(ctx).width<720?MediaQuery.sizeOf(ctx).width-48:900,height:MediaQuery.sizeOf(ctx).height*(MediaQuery.sizeOf(ctx).width<720?0.78:0.7),child:ListView.separated(
        itemCount:rows.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final x=rows[i];return ListTile(
          title:Text('${x['cari_unvan']??x['cari_adi']??'-'}',style:const TextStyle(fontWeight:FontWeight.w700)),
          subtitle:Text('Belge: ${x['belge_no']??'-'} • Vade: ${x['vade_tarihi']??'-'} • Gecikme: ${x['gecikme_gun']??0} gün'),
          trailing:Text('${_n(x['kalan_tutar']).toStringAsFixed(2)} ₺',style:const TextStyle(fontWeight:FontWeight.bold)),
          onTap:()=>ErpDetayDialog.goster(ctx,baslik:'Vade Kaydı • Detay',veri:x),
        );}
      )),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('Kapat'))],
    ));
  }

  @override
  Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('VADE YAŞLANDIRMA'),actions:[IconButton(onPressed:_yukle,icon:const Icon(Icons.refresh))]),
    body:_yukleniyor?const Center(child:CircularProgressIndicator()):Column(children:[
      Padding(padding:const EdgeInsets.all(12),child:Wrap(spacing:8,runSpacing:8,children:_grup.entries.map((e)=>SizedBox(width:190,child:Card(
        clipBehavior:Clip.antiAlias,
        child:InkWell(onTap:()=>_grupDetay(e.key),child:Padding(padding:const EdgeInsets.all(12),child:Column(children:[
          Row(mainAxisAlignment:MainAxisAlignment.center,children:[Text(e.key),const SizedBox(width:4),const Icon(Icons.chevron_right_rounded,size:18)]),
          const SizedBox(height:5),Text('${e.value.toStringAsFixed(2)} ₺',style:const TextStyle(fontSize:18,fontWeight:FontWeight.bold)),
          const Text('Detay için tıklayın',style:TextStyle(fontSize:10,color:Colors.grey)),
        ]))),
      ))).toList())),
      Expanded(child:ListView.separated(itemCount:_liste.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final x=_liste[i];return ListTile(
        title:Text('${x['cari_unvan']??x['cari_adi']??'-'}'),
        subtitle:Text('Belge: ${x['belge_no']??'-'} • Vade: ${x['vade_tarihi']??'-'} • Gecikme: ${x['gecikme_gun']??0} gün'),
        trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${_n(x['kalan_tutar']).toStringAsFixed(2)} ₺',style:const TextStyle(fontWeight:FontWeight.bold)),const SizedBox(width:8),const Icon(Icons.chevron_right_rounded)]),
        onTap:()=>ErpDetayDialog.goster(context,baslik:'Vade Kaydı • Detay',veri:x),
      );}))
    ])
  );
}
