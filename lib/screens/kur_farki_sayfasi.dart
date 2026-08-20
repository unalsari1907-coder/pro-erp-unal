import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class KurFarkiSayfasi extends StatefulWidget {
  const KurFarkiSayfasi({super.key});
  @override
  State<KurFarkiSayfasi> createState()=>_KurFarkiSayfasiState();
}
class _KurFarkiSayfasiState extends State<KurFarkiSayfasi>{
  final _cari=TextEditingController(),_pb=TextEditingController(text:'USD'),_tutar=TextEditingController(),_eski=TextEditingController(),_yeni=TextEditingController();
  List<Map<String,dynamic>> _liste=[]; bool _yuk=false;
  double _n(TextEditingController c)=>double.tryParse(c.text.replaceAll(',','.'))??0;
  @override void initState(){super.initState();_yukle();}
  @override void dispose(){_cari.dispose();_pb.dispose();_tutar.dispose();_eski.dispose();_yeni.dispose();super.dispose();}
  Future<void> _yukle()async{try{final r=await SupabaseService.supabase.from('erp_kur_farki_fisleri').select().order('tarih',ascending:false).limit(1000);if(mounted)setState(()=>_liste=List<Map<String,dynamic>>.from(r as List));}catch(_){}}
  Future<void> _kaydet()async{final fark=_n(_tutar)*(_n(_yeni)-_n(_eski));setState(()=>_yuk=true);try{await SupabaseService.supabase.from('erp_kur_farki_fisleri').insert({'tarih':DateTime.now().toIso8601String(),'cari_unvan':_cari.text.trim(),'para_birimi':_pb.text.trim().toUpperCase(),'doviz_tutar':_n(_tutar),'eski_kur':_n(_eski),'yeni_kur':_n(_yeni),'kur_farki':fark,'durum':'KAYITLI'});await _yukle();if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('Kur farkı: ${fark.toStringAsFixed(2)} ₺')));}finally{if(mounted)setState(()=>_yuk=false);}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('KUR FARKI FİŞLERİ')),body:Padding(padding:const EdgeInsets.all(14),child:Column(children:[Wrap(spacing:10,runSpacing:10,children:[_f(_cari,'Cari',220),_f(_pb,'Döviz',100),_f(_tutar,'Döviz Tutar',130),_f(_eski,'Eski Kur',120),_f(_yeni,'Yeni Kur',120),FilledButton.icon(onPressed:_yuk?null:_kaydet,icon:const Icon(Icons.save),label:const Text('Kur Farkı Oluştur'))]),const SizedBox(height:14),Expanded(child:ListView.separated(itemCount:_liste.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i){final x=_liste[i];return ListTile(title:Text('${x['cari_unvan']??'-'} • ${x['para_birimi']??'-'}'),subtitle:Text('${x['doviz_tutar']??0} × (${x['yeni_kur']??0} - ${x['eski_kur']??0})'),trailing:Text('${x['kur_farki']??0} ₺',style:const TextStyle(fontWeight:FontWeight.bold)));}))])));
  Widget _f(TextEditingController c,String l,double w)=>SizedBox(width:w,child:TextField(controller:c,decoration:InputDecoration(labelText:l,border:const OutlineInputBorder())));
}
