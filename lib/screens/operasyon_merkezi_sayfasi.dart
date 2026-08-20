import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/erp_detay_dialog.dart';

class OperasyonMerkeziSayfasi extends StatefulWidget {
  const OperasyonMerkeziSayfasi({super.key});
  @override
  State<OperasyonMerkeziSayfasi> createState() => _OperasyonMerkeziSayfasiState();
}

class _OperasyonMerkeziSayfasiState extends State<OperasyonMerkeziSayfasi> {
  bool yukleniyor = true;
  final Map<String, int> sayilar = {};

  @override
  void initState() { super.initState(); _yukle(); }

  Future<int> _say(String tablo, {String? alan, String? deger}) async {
    try {
      dynamic q = SupabaseService.supabase.from(tablo).select('id');
      if (alan != null && deger != null) q = q.eq(alan, deger);
      final r = await q.limit(5000);
      return (r as List).length;
    } catch (_) { return 0; }
  }

  Future<void> _yukle() async {
    if (mounted) setState(() => yukleniyor = true);
    final kritik = await _kritikStok();
    final bekleyenSatisSip = await _say('satis_siparis_baslik', alan: 'durum', deger: 'BEKLIYOR');
    final bekleyenAlisSip = await _say('alis_siparis_baslik', alan: 'durum', deger: 'BEKLIYOR');
    final bekleyenOnay = await _say('erp_onaylar', alan: 'durum', deger: 'BEKLIYOR');
    final eBelge = await _say('erp_e_belgeler', alan: 'durum', deger: 'HAZIR');
    final cekSenet = await _say('erp_cek_senet', alan: 'durum', deger: 'PORTFOYDE');
    if (!mounted) return;
    setState(() {
      sayilar
        ..['Kritik Stok'] = kritik
        ..['Bekleyen Satış Siparişi'] = bekleyenSatisSip
        ..['Bekleyen Alış Siparişi'] = bekleyenAlisSip
        ..['Bekleyen Onay'] = bekleyenOnay
        ..['Gönderilecek e-Belge'] = eBelge
        ..['Portföy Çek/Senet'] = cekSenet;
      yukleniyor = false;
    });
  }

  Future<int> _kritikStok() async {
    try {
      final r = await SupabaseService.supabase.from('stoklar').select('stok_miktari, minimum_stok, aktif').limit(10000);
      return (r as List).where((x) {
        final m = double.tryParse('${x['stok_miktari'] ?? 0}') ?? 0;
        final min = double.tryParse('${x['minimum_stok'] ?? 0}') ?? 0;
        return x['aktif'] != false && m <= min;
      }).length;
    } catch (_) { return 0; }
  }

  Future<List<Map<String,dynamic>>> _detay(String baslik) async {
    try {
      if (baslik == 'Kritik Stok') {
        final r = await SupabaseService.supabase.from('stoklar').select().limit(10000);
        return List<Map<String,dynamic>>.from(r as List).where((x) {
          final m = double.tryParse('${x['stok_miktari'] ?? 0}') ?? 0;
          final min = double.tryParse('${x['minimum_stok'] ?? 0}') ?? 0;
          return x['aktif'] != false && m <= min;
        }).toList();
      }
      if (baslik == 'Bekleyen Satış Siparişi') {
        final r = await SupabaseService.supabase.from('satis_siparis_baslik').select().eq('durum','BEKLIYOR').order('tarih', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Bekleyen Alış Siparişi') {
        final r = await SupabaseService.supabase.from('alis_siparis_baslik').select().eq('durum','BEKLIYOR').order('tarih', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Bekleyen Onay') {
        final r = await SupabaseService.supabase.from('erp_onaylar').select().eq('durum','BEKLIYOR').order('olusturma_tarihi', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Gönderilecek e-Belge') {
        final r = await SupabaseService.supabase.from('erp_e_belgeler').select().eq('durum','HAZIR').order('olusturma_tarihi', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Portföy Çek/Senet') {
        final r = await SupabaseService.supabase.from('erp_cek_senet').select().eq('durum','PORTFOYDE').order('vade_tarihi');
        return List<Map<String,dynamic>>.from(r as List);
      }
    } catch (_) {}
    return [];
  }

  Future<void> _ac(String baslik, int adet) async {
    if (adet == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$baslik için bekleyen kayıt yok.')));
      return;
    }
    final rows = await _detay(baslik);
    if (!mounted) return;
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$baslik detayları alınamadı.')));
      return;
    }
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text('$baslik • Detay (${rows.length})'),
      content: SizedBox(width: MediaQuery.sizeOf(ctx).width < 720 ? MediaQuery.sizeOf(ctx).width - 48 : 950, height: MediaQuery.sizeOf(ctx).height * (MediaQuery.sizeOf(ctx).width < 720 ? 0.78 : 0.7), child: ListView.separated(
        itemCount: rows.length,
        separatorBuilder: (_,__) => const Divider(height:1),
        itemBuilder: (_,i) { final x=rows[i]; return ListTile(
          leading: CircleAvatar(child: Text('${i+1}')),
          title: Text('${x['urun_adi'] ?? x['cari_unvan'] ?? x['siparis_no'] ?? x['referans_no'] ?? x['belge_no'] ?? x['evrak_no'] ?? 'Kayıt'}', style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(x.entries.where((e)=>e.value!=null).take(5).map((e)=>'${e.key}: ${e.value}').join(' • '), maxLines:2, overflow:TextOverflow.ellipsis),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () => ErpDetayDialog.goster(ctx, baslik: '$baslik • Kayıt Detayı', veri: x),
        ); },
      )),
      actions: [TextButton(onPressed:()=>Navigator.pop(ctx), child: const Text('Kapat'))],
    ));
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.sizeOf(context).width < 720;
    return Scaffold(
      appBar: AppBar(title: const Text('YÖNETİCİ / OPERASYON MERKEZİ'), actions: [IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh))]),
      body: yukleniyor ? const Center(child: CircularProgressIndicator()) : SingleChildScrollView(
        padding: EdgeInsets.all(mobil ? 10 : 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Yapılacak İşler ve Uyarılar', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('ERP içindeki bekleyen operasyonları tek ekranda özetler.'),
          const SizedBox(height: 16),
          GridView.count(
            crossAxisCount: mobil ? 1 : 3,
            childAspectRatio: mobil ? 4.2 : 2.5,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            children: sayilar.entries.map((e) => Card(
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => _ac(e.key, e.value),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(children: [
                    CircleAvatar(radius: 24, child: Text('${e.value}', style: const TextStyle(fontWeight: FontWeight.bold))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                      const Text('Detay için tıklayın', style: TextStyle(fontSize: 11, color: Colors.grey)),
                    ])),
                    Icon(e.value > 0 ? Icons.chevron_right_rounded : Icons.check_circle_outline_rounded, color: e.value > 0 ? Colors.orange : Colors.green),
                  ]),
                ),
              ),
            )).toList(),
          ),
          const SizedBox(height: 20),
          const Card(child: Padding(
            padding: EdgeInsets.all(16),
            child: Text('Not: e-Belge gönderimi için GİB/özel entegratör kullanıcı bilgileri ve API sözleşmesi gerekir. ERP bu pakette belge kuyruğu ve durum takibini hazırlar; gerçek gönderim entegratör bilgileri tanımlandıktan sonra aktive edilir.'),
          )),
        ]),
      ),
    );
  }
}
