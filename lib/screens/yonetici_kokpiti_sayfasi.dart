import 'package:flutter/material.dart';
import '../services/supabase_service.dart';
import '../widgets/erp_detay_dialog.dart';

class YoneticiKokpitiSayfasi extends StatefulWidget {
  const YoneticiKokpitiSayfasi({super.key});
  @override
  State<YoneticiKokpitiSayfasi> createState() => _YoneticiKokpitiSayfasiState();
}

class _YoneticiKokpitiSayfasiState extends State<YoneticiKokpitiSayfasi> {
  bool _yukleniyor = true;
  final Map<String, double> _tutar = {};
  final Map<String, int> _adet = {};
  final List<String> _uyarilar = [];

  double _n(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? 0}'.replaceAll(',', '.')) ?? 0;
  bool _iptal(dynamic v) => ['IPTAL', 'İPTAL'].contains('${v ?? ''}'.trim().toUpperCase());

  @override
  void initState() { super.initState(); _yukle(); }

  Future<void> _yukle() async {
    if (mounted) setState(() => _yukleniyor = true);
    final simdi = DateTime.now();
    final bas = DateTime(simdi.year, simdi.month, simdi.day).toIso8601String();
    double ciro = 0, tahsilat = 0, odeme = 0, alacak = 0, borc = 0, brutKar = 0;
    int kritik = 0, satisSip = 0, alisSip = 0, onay = 0, ebelge = 0, geciken = 0;
    final uyarilar = <String>[];

    try {
      final rows = await SupabaseService.supabase.from('satis_baslik').select().gte('tarih', bas);
      for (final r in (rows as List)) {
        final x = Map<String, dynamic>.from(r as Map);
        if (!_iptal(x['durum'])) ciro += _n(x['genel_toplam'] ?? x['toplam_tutar']);
      }
    } catch (_) {}

    try {
      final rows = await SupabaseService.supabase.from('satis_detay').select('miktar,birim_fiyat,indirim,alis_fiyati,created_at').gte('created_at', bas);
      for (final r in (rows as List)) {
        final x = Map<String, dynamic>.from(r as Map);
        final m = _n(x['miktar']);
        final net = m * _n(x['birim_fiyat']) * (1 - _n(x['indirim']) / 100);
        brutKar += net - m * _n(x['alis_fiyati']);
      }
    } catch (_) {}

    try {
      final rows = await SupabaseService.supabase.from('kasa_hareket').select().gte('tarih', bas);
      for (final r in (rows as List)) {
        final x = Map<String, dynamic>.from(r as Map);
        final tip = '${x['tip'] ?? x['islem_tipi'] ?? ''}'.toUpperCase();
        final t = _n(x['tutar']);
        if (tip.contains('TAHSIL') || tip.contains('GIRIS')) tahsilat += t;
        if (tip.contains('ODEME') || tip.contains('ÇIKIŞ') || tip.contains('CIKIS')) odeme += t;
      }
    } catch (_) {}

    try {
      final rows = await SupabaseService.supabase.from('cariler').select('bakiye,cari_tipi');
      for (final r in (rows as List)) {
        final x = Map<String, dynamic>.from(r as Map);
        final b = _n(x['bakiye']);
        final tip = '${x['cari_tipi'] ?? ''}'.toUpperCase();
        if (tip.contains('TEDAR')) borc += b.abs(); else if (b > 0) alacak += b;
      }
    } catch (_) {}

    try {
      final rows = await SupabaseService.supabase.from('stoklar').select('stok_miktari,minimum_stok,aktif');
      for (final r in (rows as List)) {
        final x = Map<String, dynamic>.from(r as Map);
        if (x['aktif'] != false && _n(x['stok_miktari']) <= _n(x['minimum_stok'])) kritik++;
      }
    } catch (_) {}

    Future<int> say(String tablo, String alan, String deger) async {
      try {
        final rows = await SupabaseService.supabase.from(tablo).select().eq(alan, deger).limit(5000);
        return (rows as List).length;
      } catch (_) { return 0; }
    }

    satisSip = await say('satis_siparis_baslik', 'durum', 'BEKLIYOR');
    alisSip = await say('alis_siparis_baslik', 'durum', 'BEKLIYOR');
    onay = await say('erp_onaylar', 'durum', 'BEKLIYOR');
    ebelge = await say('erp_e_belgeler', 'durum', 'HAZIR');

    try {
      final rows = await SupabaseService.supabase.from('erp_vade_takip').select('gecikme_gun,kalan_tutar');
      geciken = (rows as List).where((r) {
        final x = Map<String, dynamic>.from(r as Map);
        return _n(x['gecikme_gun']) > 0 && _n(x['kalan_tutar']) > 0;
      }).length;
    } catch (_) {}

    if (kritik > 0) uyarilar.add('$kritik ürün kritik stok seviyesinde.');
    if (satisSip > 0) uyarilar.add('$satisSip satış siparişi bekliyor.');
    if (alisSip > 0) uyarilar.add('$alisSip alış siparişi bekliyor.');
    if (onay > 0) uyarilar.add('$onay işlem onay bekliyor.');
    if (ebelge > 0) uyarilar.add('$ebelge e-Belge gönderim için hazır.');
    if (geciken > 0) uyarilar.add('$geciken vadesi geçmiş açık kayıt var.');

    if (!mounted) return;
    setState(() {
      _tutar
        ..['Bugünkü Ciro'] = ciro
        ..['Brüt Kâr'] = brutKar
        ..['Tahsilat'] = tahsilat
        ..['Ödeme'] = odeme
        ..['Cari Alacak'] = alacak
        ..['Cari Borç'] = borc;
      _adet
        ..['Kritik Stok'] = kritik
        ..['Bekleyen Satış Siparişi'] = satisSip
        ..['Bekleyen Alış Siparişi'] = alisSip
        ..['Bekleyen Onay'] = onay
        ..['Gönderilecek e-Belge'] = ebelge
        ..['Geciken Vade'] = geciken;
      _uyarilar
        ..clear()
        ..addAll(uyarilar);
      _yukleniyor = false;
    });
  }

  String _para(double n) => '${n.toStringAsFixed(2)} ₺';

  Future<List<Map<String, dynamic>>> _detayVerisi(String baslik) async {
    final simdi = DateTime.now();
    final bas = DateTime(simdi.year, simdi.month, simdi.day).toIso8601String();
    try {
      if (baslik == 'Bugünkü Ciro') {
        final r = await SupabaseService.supabase.from('satis_baslik').select().gte('tarih', bas).order('tarih', ascending: false);
        return List<Map<String,dynamic>>.from(r as List).where((x) => !_iptal(x['durum'])).toList();
      }
      if (baslik == 'Brüt Kâr') {
        final r = await SupabaseService.supabase.from('satis_detay').select().gte('created_at', bas).order('created_at', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Tahsilat' || baslik == 'Ödeme') {
        final r = await SupabaseService.supabase.from('kasa_hareket').select().gte('tarih', bas).order('tarih', ascending: false);
        final l = List<Map<String,dynamic>>.from(r as List);
        return l.where((x) {
          final tip = '${x['tip'] ?? x['islem_tipi'] ?? ''}'.toUpperCase();
          return baslik == 'Tahsilat'
              ? (tip.contains('TAHSIL') || tip.contains('GIRIS'))
              : (tip.contains('ODEME') || tip.contains('ÇIKIŞ') || tip.contains('CIKIS'));
        }).toList();
      }
      if (baslik == 'Cari Alacak' || baslik == 'Cari Borç') {
        final r = await SupabaseService.supabase.from('cariler').select().order('unvan');
        final l = List<Map<String,dynamic>>.from(r as List);
        return l.where((x) {
          final b = _n(x['bakiye']);
          final tip = '${x['cari_tipi'] ?? ''}'.toUpperCase();
          return baslik == 'Cari Borç' ? tip.contains('TEDAR') && b != 0 : !tip.contains('TEDAR') && b > 0;
        }).toList();
      }
      if (baslik == 'Kritik Stok') {
        final r = await SupabaseService.supabase.from('stoklar').select().limit(10000);
        return List<Map<String,dynamic>>.from(r as List).where((x) => x['aktif'] != false && _n(x['stok_miktari']) <= _n(x['minimum_stok'])).toList();
      }
      if (baslik == 'Bekleyen Satış Siparişi') {
        final r = await SupabaseService.supabase.from('satis_siparis_baslik').select().eq('durum', 'BEKLIYOR').order('tarih', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Bekleyen Alış Siparişi') {
        final r = await SupabaseService.supabase.from('alis_siparis_baslik').select().eq('durum', 'BEKLIYOR').order('tarih', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Bekleyen Onay') {
        final r = await SupabaseService.supabase.from('erp_onaylar').select().eq('durum', 'BEKLIYOR').order('olusturma_tarihi', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Gönderilecek e-Belge') {
        final r = await SupabaseService.supabase.from('erp_e_belgeler').select().eq('durum', 'HAZIR').order('olusturma_tarihi', ascending: false);
        return List<Map<String,dynamic>>.from(r as List);
      }
      if (baslik == 'Geciken Vade') {
        final r = await SupabaseService.supabase.from('erp_vade_takip').select().order('gecikme_gun', ascending: false);
        return List<Map<String,dynamic>>.from(r as List).where((x) => _n(x['gecikme_gun']) > 0 && _n(x['kalan_tutar']) > 0).toList();
      }
    } catch (_) {}
    return [];
  }

  Future<void> _detayAc(String baslik) async {
    final beklenen = _adet[baslik];
    if (beklenen == 0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$baslik için bekleyen kayıt bulunmuyor.')));
      return;
    }
    showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    final rows = await _detayVerisi(baslik);
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop();
    if (rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$baslik için detay kaydı bulunamadı.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final mobil = MediaQuery.sizeOf(ctx).width < 720;
        return AlertDialog(
          title: Text('$baslik • Detay (${rows.length})'),
          content: SizedBox(
            width: mobil ? MediaQuery.sizeOf(ctx).width * .94 : 1050,
            height: MediaQuery.sizeOf(ctx).height * .72,
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final x = rows[i];
                final title = '${x['unvan'] ?? x['cari_unvan'] ?? x['urun_adi'] ?? x['fatura_no'] ?? x['siparis_no'] ?? x['belge_no'] ?? x['referans_no'] ?? x['onay_tipi'] ?? x['belge_tipi'] ?? 'Kayıt'}';
                final alt = x.entries.where((e) => e.value != null && '${e.value}'.trim().isNotEmpty).take(5).map((e) => '${e.key}: ${e.value}').join(' • ');
                return ListTile(
                  leading: CircleAvatar(child: Text('${i + 1}')),
                  title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text(alt, maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => ErpDetayDialog.goster(ctx, baslik: '$baslik • Kayıt Detayı', veri: x),
                );
              },
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat'))],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('YÖNETİCİ KOKPİTİ'), actions: [IconButton(onPressed: _yukle, icon: const Icon(Icons.refresh_rounded))]),
      body: _yukleniyor ? const Center(child: CircularProgressIndicator()) : LayoutBuilder(builder: (context, c) {
        final sutun = c.maxWidth < 720 ? 2 : c.maxWidth < 1150 ? 3 : 6;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: sutun,
              childAspectRatio: c.maxWidth < 720 ? 1.65 : 1.45,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: _tutar.entries.map((e) => _kart(e.key, _para(e.value), Icons.account_balance_wallet_rounded, () => _detayAc(e.key))).toList(),
            ),
            const SizedBox(height: 18),
            const Text('Yapılacak İşler', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(spacing: 10, runSpacing: 10, children: _adet.entries.map((e) => _uyariKarti(e.key, e.value, () => _detayAc(e.key))).toList()),
            const SizedBox(height: 18),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Yönetici Uyarıları', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                  const Divider(),
                  if (_uyarilar.isEmpty) const ListTile(leading: Icon(Icons.check_circle_outline_rounded), title: Text('Kritik bekleyen işlem görünmüyor.')),
                  ..._uyarilar.map((u) { final k = _adet.keys.firstWhere((x) => u.toLowerCase().contains(x.toLowerCase().replaceAll('bekleyen ', '').replaceAll('gönderilecek ', '').replaceAll('geciken ', 'vade')), orElse: () => ''); return ListTile(dense: true, leading: const Icon(Icons.notification_important_outlined), title: Text(u), trailing: const Icon(Icons.chevron_right_rounded), onTap: k.isEmpty ? null : () => _detayAc(k)); }),
                ]),
              ),
            ),
          ]),
        );
      }),
    );
  }

  Widget _kart(String b, String d, IconData i, VoidCallback onTap) => Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Row(children: [Icon(i), const Spacer(), const Icon(Icons.open_in_new_rounded, size: 16)]),
          const SizedBox(height: 8), Text(b, style: const TextStyle(fontSize: 12)), const SizedBox(height: 4), FittedBox(child: Text(d, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(height: 3), const Text('Detay için tıklayın', style: TextStyle(fontSize: 10, color: Colors.grey)),
        ]),
      ),
    ),
  );

  Widget _uyariKarti(String b, int d, VoidCallback onTap) => SizedBox(width: 225, child: Card(
    clipBehavior: Clip.antiAlias,
    child: InkWell(onTap: onTap, child: ListTile(
      leading: CircleAvatar(child: Text('$d')),
      title: Text(b, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right_rounded),
    )),
  ));
}
