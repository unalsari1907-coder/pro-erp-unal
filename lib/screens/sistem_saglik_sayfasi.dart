import 'package:flutter/material.dart';
import '../services/supabase_service.dart';

class SistemSaglikSayfasi extends StatefulWidget {
  const SistemSaglikSayfasi({super.key});
  @override State<SistemSaglikSayfasi> createState() => _SistemSaglikSayfasiState();
}

class _SistemSaglikSayfasiState extends State<SistemSaglikSayfasi> {
  bool _yuk = true;
  final List<Map<String, dynamic>> _sonuc = [];

  static const _gruplar = <String, List<String>>{
    'Ana Veriler': ['stoklar','cariler','depolar','kasalar'],
    'Satış': ['satis_baslik','satis_detay','satis_siparis_baslik','satis_siparis_detay','satis_irsaliye_baslik','satis_irsaliye_detay'],
    'Alış': ['alis_baslik','alis_detay','alis_siparis_baslik','alis_siparis_detay','alis_irsaliye_baslik','alis_irsaliye_detay'],
    'Finans': ['stok_hareket','cari_hareket','kasa_hareket','finans_transfer','giderler'],
    'Kurumsal': ['erp_hesap_plani','erp_muhasebe_fisleri','erp_muhasebe_fis_satirlari','erp_cek_senet','erp_e_belgeler','erp_onaylar'],
    'Araç Kataloğu': ['erp_arac_katalog_araclar','erp_arac_katalog_parcalar'],
    'Pazaryeri': ['erp_pazaryeri_kanallari','erp_pazaryeri_urunleri','erp_pazaryeri_siparisleri','erp_pazaryeri_siparis_detay','erp_pazaryeri_iadeleri'],
    'Sistem': ['erp_kullanicilar','erp_firma_ayarlari','erp_sistem_ayarlari','erp_islem_log'],
  };

  @override void initState(){ super.initState(); _kontrol(); }

  Future<void> _kontrol() async {
    if (mounted) setState(() => _yuk = true);
    _sonuc.clear();
    for (final grup in _gruplar.entries) {
      for (final tablo in grup.value) {
        try {
          await SupabaseService.supabase.from(tablo).select().limit(1);
          _sonuc.add({'grup':grup.key,'ad':tablo,'ok':true,'mesaj':'Erişim başarılı'});
        } catch(e) {
          _sonuc.add({'grup':grup.key,'ad':tablo,'ok':false,'mesaj':e.toString()});
        }
      }
    }
    if(mounted) setState(() => _yuk = false);
  }

  @override Widget build(BuildContext context) {
    final hata = _sonuc.where((e)=>e['ok']!=true).length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SİSTEM SAĞLIK KONTROLÜ'),
        actions:[IconButton(onPressed:_yuk?null:_kontrol,icon:const Icon(Icons.refresh_rounded))],
      ),
      body:_yuk
        ? const Center(child:CircularProgressIndicator())
        : Column(children:[
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(child:ListTile(
                leading: Icon(hata==0?Icons.verified_rounded:Icons.warning_amber_rounded,color:hata==0?Colors.green:Colors.orange),
                title: Text(hata==0?'Tüm temel modüller erişilebilir':'$hata kontrol başarısız'),
                subtitle: Text('${_sonuc.length} kritik tablo kontrol edildi.'),
              )),
            ),
            Expanded(child:ListView.builder(
              padding:const EdgeInsets.fromLTRB(12,0,12,12),
              itemCount:_sonuc.length,
              itemBuilder:(_,i){
                final x=_sonuc[i];
                return Card(child:ListTile(
                  leading:Icon(x['ok']==true?Icons.check_circle:Icons.error,color:x['ok']==true?Colors.green:Colors.red),
                  title:Text('${x['ad']}'),
                  subtitle:Text('${x['grup']} • ${x['mesaj']}'),
                ));
              },
            )),
          ]),
    );
  }
}
