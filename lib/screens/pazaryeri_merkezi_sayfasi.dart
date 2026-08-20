import 'package:flutter/material.dart';
import '../services/pazaryeri_service.dart';

class PazaryeriMerkeziSayfasi extends StatefulWidget {
  final int baslangicSekmesi;
  const PazaryeriMerkeziSayfasi({super.key, this.baslangicSekmesi = 0});
  @override State<PazaryeriMerkeziSayfasi> createState()=>_PazaryeriMerkeziSayfasiState();
}
class _PazaryeriMerkeziSayfasiState extends State<PazaryeriMerkeziSayfasi> with SingleTickerProviderStateMixin {
  late TabController _tabs; bool _loading=true;
  List<Map<String,dynamic>> kanallar=[], siparisler=[], urunler=[], iadeler=[];
  double _n(dynamic x)=> x is num ? x.toDouble() : double.tryParse('${x??0}'.replaceAll(',','.'))??0;
  @override void initState(){super.initState();_tabs=TabController(length:5,vsync:this,initialIndex:widget.baslangicSekmesi<0?0:(widget.baslangicSekmesi>4?4:widget.baslangicSekmesi));_yukle();}
  @override void dispose(){_tabs.dispose();super.dispose();}
  Future<void> _yukle() async { setState(()=>_loading=true); final r=await Future.wait([PazaryeriService.kanallar(),PazaryeriService.siparisler(),PazaryeriService.urunler(),PazaryeriService.iadeler()]); if(!mounted)return; setState((){kanallar=r[0];siparisler=r[1];urunler=r[2];iadeler=r[3];_loading=false;}); }
  Widget _kart(String a,String d,IconData i){return Card(child:Padding(padding:const EdgeInsets.all(18),child:Row(children:[Icon(i,size:30),const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(a,style:const TextStyle(fontSize:12)),Text(d,style:const TextStyle(fontSize:21,fontWeight:FontWeight.bold),overflow:TextOverflow.ellipsis)]))])));}
  @override Widget build(BuildContext context){
    final ciro=siparisler.fold<double>(0,(a,e)=>a+_n(e['toplam_tutar']));
    return Scaffold(appBar:AppBar(title:const Text('PAZARYERİ / E-TİCARET MERKEZİ'),actions:[IconButton(onPressed:_yukle,icon:const Icon(Icons.refresh))],bottom:TabBar(controller:_tabs,isScrollable:true,tabs:const [Tab(text:'Genel Bakış'),Tab(text:'Siparişler'),Tab(text:'Ürün / Stok / Fiyat'),Tab(text:'İade / Kargo'),Tab(text:'Mağazalar')])) ,body:_loading?const Center(child:CircularProgressIndicator()):TabBarView(controller:_tabs,children:[
      LayoutBuilder(builder:(context,c){final w=c.maxWidth<760?c.maxWidth:(c.maxWidth-24)/4;return ListView(padding:const EdgeInsets.all(16),children:[Wrap(spacing:8,runSpacing:8,children:[SizedBox(width:w,child:_kart('İnternet Cirosu','${ciro.toStringAsFixed(2)} ₺',Icons.payments)),SizedBox(width:w,child:_kart('Sipariş','${siparisler.length}',Icons.shopping_bag)),SizedBox(width:w,child:_kart('Bağlı Ürün','${urunler.length}',Icons.inventory_2)),SizedBox(width:w,child:_kart('İade','${iadeler.length}',Icons.keyboard_return))]),const SizedBox(height:18),const Card(child:ListTile(leading:Icon(Icons.hub),title:Text('PRO-ERP ana stok ve fiyat merkezi'),subtitle:Text('Pazaryerleri satış kanalıdır. Canlı API bağlantıları mağaza bilgileri girildiğinde aktive edilir. Stok, fiyat, sipariş, kargo, iade, komisyon ve net kâr tek merkezde izlenir.')))]);}),
      _liste(siparisler,(e)=>ListTile(leading:const Icon(Icons.receipt_long),title:Text('${e['kanal']??''} • ${e['siparis_no']??''}'),subtitle:Text('${e['durum']??''} • ${e['musteri_adi']??''}'),trailing:Text('${_n(e['toplam_tutar']).toStringAsFixed(2)} ₺'))),
      _liste(urunler,(e)=>ListTile(leading:const Icon(Icons.inventory_2),title:Text('${e['urun_adi']??e['stok_kodu']??'Ürün'}'),subtitle:Text('${e['kanal']??''} • SKU: ${e['merchant_sku']??'-'} • Stok: ${e['kanal_stok']??0}'),trailing:Text('${_n(e['kanal_fiyati']).toStringAsFixed(2)} ₺'))),
      _liste(iadeler,(e)=>ListTile(leading:const Icon(Icons.assignment_return),title:Text('${e['kanal']??''} • ${e['siparis_no']??''}'),subtitle:Text('${e['durum']??''} • ${e['neden']??''}'))),
      _magazalar(),
    ]));
  }
  Widget _liste(List<Map<String,dynamic>> x,Widget Function(Map<String,dynamic>) b)=>x.isEmpty?const Center(child:Text('Henüz kayıt yok. Altyapı hazır; canlı mağaza bağlandığında veriler burada görünecek.')):ListView.separated(padding:const EdgeInsets.all(16),itemCount:x.length,separatorBuilder:(_,__)=>const Divider(height:1),itemBuilder:(_,i)=>b(x[i]));
  Widget _magazalar(){const hazir=['Trendyol','Hepsiburada','n11','Amazon Türkiye','Web Sitesi'];return ListView(padding:const EdgeInsets.all(16),children:hazir.map((ad){final bulunan=kanallar.where((e)=>e['kanal_adi']==ad).toList();final aktif=bulunan.isNotEmpty && bulunan.first['aktif']==true;return Card(child:ListTile(leading:Icon(aktif?Icons.cloud_done:Icons.cloud_off),title:Text(ad),subtitle:Text(aktif?'Bağlantı yapılandırıldı':'Hazır — API bilgileri satışa başlanınca girilecek'),trailing:Switch(value:aktif,onChanged:(v)async{final m=bulunan.isEmpty?<String,dynamic>{'kanal_adi':ad,'kanal_kodu':ad.toUpperCase().replaceAll(' ', '_'),'aktif':v}:Map<String,dynamic>.from(bulunan.first)..['aktif']=v;await PazaryeriService.kanalKaydet(m);await _yukle();})));}).toList());}
}
