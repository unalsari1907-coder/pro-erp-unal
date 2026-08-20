import 'package:flutter/material.dart';

import '../services/supabase_service.dart';
import '../widgets/erp_detay_dialog.dart';

class KurumsalAlan {
  final String keyName;
  final String label;
  final bool sayi;
  final bool tarih;
  final bool cokSatir;
  final bool saltOkunur;
  final String? varsayilan;

  const KurumsalAlan(
    this.keyName,
    this.label, {
    this.sayi = false,
    this.tarih = false,
    this.cokSatir = false,
    this.saltOkunur = false,
    this.varsayilan,
  });
}

class KurumsalModulTanim {
  final String baslik;
  final String altBaslik;
  final String tablo;
  final String idAlan;
  final IconData ikon;
  final List<KurumsalAlan> alanlar;
  final String? siraAlan;
  final String? detayTablo;
  final String? detayForeignKey;
  final String? detayIdAlan;
  final List<KurumsalAlan> detayAlanlar;

  const KurumsalModulTanim({
    required this.baslik,
    required this.altBaslik,
    required this.tablo,
    required this.idAlan,
    required this.ikon,
    required this.alanlar,
    this.siraAlan,
    this.detayTablo,
    this.detayForeignKey,
    this.detayIdAlan,
    this.detayAlanlar = const [],
  });
}

class KurumsalModuller {
  static const teklif = KurumsalModulTanim(
    baslik: 'Teklif / Proforma',
    altBaslik: 'Teklif, proforma ve teklif durum takibi',
    tablo: 'erp_teklifler',
    idAlan: 'teklif_id',
    ikon: Icons.request_quote_rounded,
    siraAlan: 'tarih',
    detayTablo: 'erp_teklif_detay',
    detayForeignKey: 'teklif_id',
    detayIdAlan: 'detay_id',
    detayAlanlar: [
      KurumsalAlan('stok_id', 'Stok ID', sayi: true),
      KurumsalAlan('uretici_kodu', 'Üretici Kodu'),
      KurumsalAlan('urun_adi', 'Ürün Adı'),
      KurumsalAlan('miktar', 'Miktar', sayi: true, varsayilan: '1'),
      KurumsalAlan('birim_fiyat', 'Birim Fiyat', sayi: true, varsayilan: '0'),
      KurumsalAlan('iskonto_orani', 'İskonto %', sayi: true, varsayilan: '0'),
      KurumsalAlan('kdv_orani', 'KDV %', sayi: true, varsayilan: '20'),
    ],
    alanlar: [
      KurumsalAlan('belge_no', 'Belge No'),
      KurumsalAlan('tarih', 'Tarih', tarih: true),
      KurumsalAlan('cari_unvan', 'Cari'),
      KurumsalAlan('para_birimi', 'Para Birimi', varsayilan: 'TRY'),
      KurumsalAlan('kur', 'Kur', sayi: true, varsayilan: '1'),
      KurumsalAlan('toplam', 'Toplam', sayi: true, varsayilan: '0', saltOkunur: true),
      KurumsalAlan('durum', 'Durum', varsayilan: 'HAZIR'),
      KurumsalAlan('gecerlilik_tarihi', 'Geçerlilik Tarihi', tarih: true),
      KurumsalAlan('aciklama', 'Açıklama', cokSatir: true),
    ],
  );

  static const hesapPlani = KurumsalModulTanim(
    baslik: 'Hesap Planı',
    altBaslik: 'Genel muhasebe hesap kartları',
    tablo: 'erp_hesap_plani',
    idAlan: 'hesap_id',
    ikon: Icons.account_tree_rounded,
    siraAlan: 'hesap_kodu',
    alanlar: [
      KurumsalAlan('hesap_kodu', 'Hesap Kodu'),
      KurumsalAlan('hesap_adi', 'Hesap Adı'),
      KurumsalAlan('hesap_tipi', 'Hesap Tipi'),
      KurumsalAlan('ust_hesap_kodu', 'Üst Hesap Kodu'),
      KurumsalAlan('aktif', 'Aktif (true/false)', varsayilan: 'true'),
    ],
  );

  static const muhasebeFisleri = KurumsalModulTanim(
    baslik: 'Muhasebe Fişleri',
    altBaslik: 'Mahsup, tahsil, tediye ve açılış fişleri',
    tablo: 'erp_muhasebe_fisleri',
    idAlan: 'fis_id',
    ikon: Icons.menu_book_rounded,
    siraAlan: 'tarih',
    detayTablo: 'erp_muhasebe_fis_satirlari',
    detayForeignKey: 'fis_id',
    detayIdAlan: 'satir_id',
    detayAlanlar: [
      KurumsalAlan('hesap_kodu', 'Hesap Kodu'),
      KurumsalAlan('aciklama', 'Açıklama'),
      KurumsalAlan('borc', 'Borç', sayi: true, varsayilan: '0'),
      KurumsalAlan('alacak', 'Alacak', sayi: true, varsayilan: '0'),
      KurumsalAlan('cari_id', 'Cari ID', sayi: true),
      KurumsalAlan('belge_no', 'Belge No'),
    ],
    alanlar: [
      KurumsalAlan('fis_no', 'Fiş No'),
      KurumsalAlan('tarih', 'Tarih', tarih: true),
      KurumsalAlan('fis_tipi', 'Fiş Tipi', varsayilan: 'MAHSUP'),
      KurumsalAlan('aciklama', 'Açıklama', cokSatir: true),
      KurumsalAlan('borc_toplam', 'Borç Toplam', sayi: true, varsayilan: '0', saltOkunur: true),
      KurumsalAlan('alacak_toplam', 'Alacak Toplam', sayi: true, varsayilan: '0', saltOkunur: true),
      KurumsalAlan('durum', 'Durum', varsayilan: 'TASLAK'),
    ],
  );

  static const cekSenet = KurumsalModulTanim(
    baslik: 'Çek / Senet',
    altBaslik: 'Müşteri ve firma çek/senet portföyü',
    tablo: 'erp_cek_senet',
    idAlan: 'evrak_id',
    ikon: Icons.payments_outlined,
    siraAlan: 'vade_tarihi',
    alanlar: [
      KurumsalAlan('evrak_tipi', 'Evrak Tipi', varsayilan: 'ÇEK'),
      KurumsalAlan('evrak_no', 'Evrak No'),
      KurumsalAlan('cari_unvan', 'Cari'),
      KurumsalAlan('banka', 'Banka'),
      KurumsalAlan('vade_tarihi', 'Vade Tarihi', tarih: true),
      KurumsalAlan('tutar', 'Tutar', sayi: true),
      KurumsalAlan('para_birimi', 'Para Birimi', varsayilan: 'TRY'),
      KurumsalAlan('durum', 'Durum', varsayilan: 'PORTFOYDE'),
      KurumsalAlan('aciklama', 'Açıklama', cokSatir: true),
    ],
  );

  static const doviz = KurumsalModulTanim(
    baslik: 'Döviz / Kur',
    altBaslik: 'Döviz kurları ve kur geçmişi',
    tablo: 'erp_doviz_kurlari',
    idAlan: 'kur_id',
    ikon: Icons.currency_exchange_rounded,
    siraAlan: 'tarih',
    alanlar: [
      KurumsalAlan('tarih', 'Tarih', tarih: true),
      KurumsalAlan('para_birimi', 'Para Birimi'),
      KurumsalAlan('alis', 'Alış', sayi: true),
      KurumsalAlan('satis', 'Satış', sayi: true),
      KurumsalAlan('efektif_alis', 'Efektif Alış', sayi: true),
      KurumsalAlan('efektif_satis', 'Efektif Satış', sayi: true),
      KurumsalAlan('kaynak', 'Kaynak', varsayilan: 'MANUEL'),
    ],
  );

  static const eBelge = KurumsalModulTanim(
    baslik: 'e-Belge Merkezi',
    altBaslik: 'e-Fatura, e-Arşiv ve e-İrsaliye gönderim kuyruğu',
    tablo: 'erp_e_belgeler',
    idAlan: 'ebelge_id',
    ikon: Icons.cloud_upload_rounded,
    siraAlan: 'olusturma_tarihi',
    alanlar: [
      KurumsalAlan('belge_tipi', 'Belge Tipi', varsayilan: 'E-FATURA'),
      KurumsalAlan('belge_no', 'Belge No'),
      KurumsalAlan('cari_unvan', 'Cari'),
      KurumsalAlan('vergi_no', 'Vergi / TC No'),
      KurumsalAlan('olusturma_tarihi', 'Oluşturma Tarihi', tarih: true),
      KurumsalAlan('durum', 'Durum', varsayilan: 'HAZIR'),
      KurumsalAlan('entegrator', 'Entegratör'),
      KurumsalAlan('uuid', 'UUID'),
      KurumsalAlan('hata_mesaji', 'Hata Mesajı', cokSatir: true),
    ],
  );

  static const satinAlmaTalep = KurumsalModulTanim(
    baslik: 'Satın Alma Talepleri',
    altBaslik: 'Depo ve kullanıcı bazlı satın alma talep yönetimi',
    tablo: 'erp_satin_alma_talepleri',
    idAlan: 'talep_id',
    ikon: Icons.playlist_add_check_circle_rounded,
    siraAlan: 'tarih',
    detayTablo: 'erp_satin_alma_talep_detay',
    detayForeignKey: 'talep_id',
    detayIdAlan: 'detay_id',
    detayAlanlar: [
      KurumsalAlan('stok_id', 'Stok ID', sayi: true),
      KurumsalAlan('uretici_kodu', 'Üretici Kodu'),
      KurumsalAlan('urun_adi', 'Ürün Adı'),
      KurumsalAlan('miktar', 'Talep Miktarı', sayi: true, varsayilan: '1'),
      KurumsalAlan('mevcut_stok', 'Mevcut Stok', sayi: true, varsayilan: '0'),
      KurumsalAlan('minimum_stok', 'Minimum Stok', sayi: true, varsayilan: '0'),
      KurumsalAlan('aciklama', 'Açıklama', cokSatir: true),
    ],
    alanlar: [
      KurumsalAlan('talep_no', 'Talep No'),
      KurumsalAlan('tarih', 'Tarih', tarih: true),
      KurumsalAlan('talep_eden', 'Talep Eden'),
      KurumsalAlan('depo', 'Depo'),
      KurumsalAlan('oncelik', 'Öncelik', varsayilan: 'NORMAL'),
      KurumsalAlan('durum', 'Durum', varsayilan: 'BEKLIYOR'),
      KurumsalAlan('aciklama', 'Açıklama', cokSatir: true),
    ],
  );

  static const onay = KurumsalModulTanim(
    baslik: 'Onay Merkezi',
    altBaslik: 'Fiyat, iskonto, ödeme ve belge onay akışları',
    tablo: 'erp_onaylar',
    idAlan: 'onay_id',
    ikon: Icons.approval_rounded,
    siraAlan: 'olusturma_tarihi',
    alanlar: [
      KurumsalAlan('onay_tipi', 'Onay Tipi'),
      KurumsalAlan('referans_no', 'Referans No'),
      KurumsalAlan('olusturma_tarihi', 'Oluşturma Tarihi', tarih: true),
      KurumsalAlan('isteyen', 'İsteyen'),
      KurumsalAlan('onaylayan', 'Onaylayan'),
      KurumsalAlan('durum', 'Durum', varsayilan: 'BEKLIYOR'),
      KurumsalAlan('aciklama', 'Açıklama', cokSatir: true),
    ],
  );

  static const seriLot = KurumsalModulTanim(
    baslik: 'Seri / Lot Takibi',
    altBaslik: 'Seri numarası, lot, raf ve son kullanma takibi',
    tablo: 'erp_seri_lot',
    idAlan: 'seri_lot_id',
    ikon: Icons.qr_code_2_rounded,
    siraAlan: 'olusturma_tarihi',
    alanlar: [
      KurumsalAlan('stok_id', 'Stok ID', sayi: true),
      KurumsalAlan('uretici_kodu', 'Üretici Kodu'),
      KurumsalAlan('seri_no', 'Seri No'),
      KurumsalAlan('lot_no', 'Lot No'),
      KurumsalAlan('depo', 'Depo'),
      KurumsalAlan('raf', 'Raf'),
      KurumsalAlan('miktar', 'Miktar', sayi: true, varsayilan: '1'),
      KurumsalAlan('son_kullanma_tarihi', 'Son Kullanma Tarihi', tarih: true),
      KurumsalAlan('durum', 'Durum', varsayilan: 'STOKTA'),
    ],
  );

  static const kampanya = KurumsalModulTanim(
    baslik: 'Kampanya / Fiyat Listeleri',
    altBaslik: 'Cari, marka ve grup bazlı fiyat/iskonto kuralları',
    tablo: 'erp_fiyat_kurallari',
    idAlan: 'kural_id',
    ikon: Icons.price_change_rounded,
    siraAlan: 'baslangic_tarihi',
    alanlar: [
      KurumsalAlan('kural_adi', 'Kural Adı'),
      KurumsalAlan('kapsam_tipi', 'Kapsam Tipi', varsayilan: 'GENEL'),
      KurumsalAlan('kapsam_degeri', 'Kapsam Değeri'),
      KurumsalAlan('iskonto_orani', 'İskonto %', sayi: true, varsayilan: '0'),
      KurumsalAlan('kar_orani', 'Kâr %', sayi: true, varsayilan: '0'),
      KurumsalAlan('baslangic_tarihi', 'Başlangıç Tarihi', tarih: true),
      KurumsalAlan('bitis_tarihi', 'Bitiş Tarihi', tarih: true),
      KurumsalAlan('aktif', 'Aktif (true/false)', varsayilan: 'true'),
    ],
  );


}

class KurumsalModulSayfasi extends StatefulWidget {
  final KurumsalModulTanim tanim;
  const KurumsalModulSayfasi({super.key, required this.tanim});

  @override
  State<KurumsalModulSayfasi> createState() => _KurumsalModulSayfasiState();
}

class _KurumsalModulSayfasiState extends State<KurumsalModulSayfasi> {
  final _arama = TextEditingController();
  bool _yukleniyor = true;
  String? _hata;
  List<Map<String, dynamic>> _kayitlar = [];

  @override
  void initState() {
    super.initState();
    _yukle();
  }

  @override
  void dispose() {
    _arama.dispose();
    super.dispose();
  }

  Future<void> _yukle() async {
    if (!mounted) return;
    setState(() {
      _yukleniyor = true;
      _hata = null;
    });
    try {
      dynamic query = SupabaseService.supabase.from(widget.tanim.tablo).select();
      if (widget.tanim.siraAlan != null) {
        query = query.order(widget.tanim.siraAlan!, ascending: false);
      }
      final sonuc = await query.limit(2000);
      if (!mounted) return;
      setState(() {
        _kayitlar = List<Map<String, dynamic>>.from(sonuc as List);
        _yukleniyor = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _hata = e.toString();
        _yukleniyor = false;
      });
    }
  }

  List<Map<String, dynamic>> get _gorunen {
    final q = _arama.text.toLowerCase().trim();
    if (q.isEmpty) return _kayitlar;
    final kelimeler = q.split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    return _kayitlar.where((x) {
      final metin = x.values.map((e) => e?.toString() ?? '').join(' ').toLowerCase();
      return kelimeler.every(metin.contains);
    }).toList();
  }

  dynamic _deger(KurumsalAlan alan, String metin) {
    final t = metin.trim();
    if (alan.sayi) {
      final n = double.tryParse(t.replaceAll(',', '.')) ?? 0;
      if (alan.keyName.endsWith('_id') && n == n.roundToDouble()) return n.toInt();
      return n;
    }
    if (t.toLowerCase() == 'true') return true;
    if (t.toLowerCase() == 'false') return false;
    if (alan.tarih && t.isNotEmpty) return t;
    return t.isEmpty ? null : t;
  }

  Future<void> _duzenle([Map<String, dynamic>? mevcut]) async {
    final ctrls = <String, TextEditingController>{};
    for (final a in widget.tanim.alanlar) {
      var baslangic = mevcut?[a.keyName]?.toString() ?? a.varsayilan ?? '';
      if (a.tarih && baslangic.contains('T')) baslangic = baslangic.split('T').first;
      ctrls[a.keyName] = TextEditingController(text: baslangic);
    }
    try {
      final kaydet = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final mobil = MediaQuery.sizeOf(ctx).width < 720;
          return AlertDialog(
            title: Text(mevcut == null ? '${widget.tanim.baslik} • Yeni Kayıt' : '${widget.tanim.baslik} • Düzenle'),
            content: SizedBox(
              width: mobil ? MediaQuery.sizeOf(ctx).width * .92 : 720,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.tanim.alanlar.map((a) {
                    return SizedBox(
                      width: mobil || a.cokSatir ? double.infinity : 335,
                      child: TextField(
                        controller: ctrls[a.keyName],
                        enabled: !a.saltOkunur,
                        maxLines: a.cokSatir ? 3 : 1,
                        keyboardType: a.sayi ? const TextInputType.numberWithOptions(decimal: true) : null,
                        decoration: InputDecoration(labelText: a.label, border: const OutlineInputBorder()),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
              FilledButton.icon(onPressed: () => Navigator.pop(ctx, true), icon: const Icon(Icons.save), label: const Text('Kaydet')),
            ],
          );
        },
      );
      if (kaydet != true) return;
      final veri = <String, dynamic>{};
      for (final a in widget.tanim.alanlar) {
        veri[a.keyName] = _deger(a, ctrls[a.keyName]!.text);
      }
      if (mevcut == null) {
        await SupabaseService.supabase.from(widget.tanim.tablo).insert(veri);
      } else {
        await SupabaseService.supabase
            .from(widget.tanim.tablo)
            .update(veri)
            .eq(widget.tanim.idAlan, mevcut[widget.tanim.idAlan]);
      }
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt işlemi başarısız: $e'), backgroundColor: Colors.red));
    } finally {
      for (final c in ctrls.values) {
        c.dispose();
      }
    }
  }


  bool get _detayliModul =>
      widget.tanim.detayTablo != null &&
      widget.tanim.detayForeignKey != null &&
      widget.tanim.detayIdAlan != null &&
      widget.tanim.detayAlanlar.isNotEmpty;

  Future<List<Map<String, dynamic>>> _detaylariGetir(
    Map<String, dynamic> kayit,
  ) async {
    if (!_detayliModul) return const [];
    final sonuc = await SupabaseService.supabase
        .from(widget.tanim.detayTablo!)
        .select()
        .eq(widget.tanim.detayForeignKey!, kayit[widget.tanim.idAlan])
        .order(widget.tanim.detayIdAlan!);
    return List<Map<String, dynamic>>.from(sonuc as List);
  }

  Future<bool> _detaySatirDuzenle(
    Map<String, dynamic> kayit, [
    Map<String, dynamic>? mevcut,
  ]) async {
    final ctrls = <String, TextEditingController>{};
    for (final a in widget.tanim.detayAlanlar) {
      ctrls[a.keyName] = TextEditingController(
        text: mevcut?[a.keyName]?.toString() ?? a.varsayilan ?? '',
      );
    }
    try {
      final kaydet = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          final mobil = MediaQuery.sizeOf(ctx).width < 720;
          return AlertDialog(
            title: Text(mevcut == null ? 'Yeni Detay Satırı' : 'Detay Satırını Düzenle'),
            content: SizedBox(
              width: mobil ? MediaQuery.sizeOf(ctx).width * .92 : 760,
              child: SingleChildScrollView(
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: widget.tanim.detayAlanlar.map((a) {
                    return SizedBox(
                      width: mobil || a.cokSatir ? double.infinity : 350,
                      child: TextField(
                        controller: ctrls[a.keyName],
                        enabled: !a.saltOkunur,
                        maxLines: a.cokSatir ? 3 : 1,
                        keyboardType: a.sayi
                            ? const TextInputType.numberWithOptions(decimal: true)
                            : null,
                        decoration: InputDecoration(
                          labelText: a.label,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Vazgeç'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.pop(ctx, true),
                icon: const Icon(Icons.save_rounded),
                label: const Text('Kaydet'),
              ),
            ],
          );
        },
      );
      if (kaydet != true) return false;

      final veri = <String, dynamic>{
        widget.tanim.detayForeignKey!: kayit[widget.tanim.idAlan],
      };
      for (final a in widget.tanim.detayAlanlar) {
        veri[a.keyName] = _deger(a, ctrls[a.keyName]!.text);
      }

      if (mevcut == null) {
        await SupabaseService.supabase
            .from(widget.tanim.detayTablo!)
            .insert(veri);
      } else {
        await SupabaseService.supabase
            .from(widget.tanim.detayTablo!)
            .update(veri)
            .eq(widget.tanim.detayIdAlan!, mevcut[widget.tanim.detayIdAlan!]);
      }
      return true;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Detay kaydedilemedi: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    } finally {
      for (final c in ctrls.values) {
        c.dispose();
      }
    }
  }

  Future<void> _detaySatirSil(Map<String, dynamic> satir) async {
    await SupabaseService.supabase
        .from(widget.tanim.detayTablo!)
        .delete()
        .eq(widget.tanim.detayIdAlan!, satir[widget.tanim.detayIdAlan!]);
  }

  Future<void> _kayitDetayi(Map<String, dynamic> kayit) async {
    if (!_detayliModul) {
      await ErpDetayDialog.goster(
        context,
        baslik: '${kayit[widget.tanim.alanlar.first.keyName] ?? 'Kayıt'} • Detay',
        altBaslik: widget.tanim.altBaslik,
        veri: kayit,
        etiketler: {for (final a in widget.tanim.alanlar) a.keyName: a.label},
        alanSirasi: [
          widget.tanim.idAlan,
          ...widget.tanim.alanlar.map((a) => a.keyName),
        ],
        onDuzenle: () => _duzenle(kayit),
      );
      return;
    }

    var detaylar = await _detaylariGetir(kayit);
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setLocal) {
          Future<void> yenile() async {
            final yeni = await _detaylariGetir(kayit);
            try {
              final ust = await SupabaseService.supabase
                  .from(widget.tanim.tablo)
                  .select()
                  .eq(widget.tanim.idAlan, kayit[widget.tanim.idAlan])
                  .maybeSingle();
              if (ust != null) {
                kayit
                  ..clear()
                  ..addAll(Map<String, dynamic>.from(ust));
              }
            } catch (_) {}
            if (ctx.mounted) setLocal(() => detaylar = yeni);
            await _yukle();
          }

          final mobil = MediaQuery.sizeOf(ctx).width < 760;
          return Dialog(
            insetPadding: EdgeInsets.all(mobil ? 8 : 24),
            child: SizedBox(
              width: mobil ? MediaQuery.sizeOf(ctx).width : 1080,
              height: MediaQuery.sizeOf(ctx).height * .84,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 10, 10),
                    child: Row(
                      children: [
                        Icon(widget.tanim.ikon),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.tanim.baslik,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                widget.tanim.alanlar
                                    .take(4)
                                    .map((a) => '${a.label}: ${kayit[a.keyName] ?? '-'}')
                                    .join(' • '),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Başlığı düzenle',
                          onPressed: () async {
                            await _duzenle(kayit);
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          icon: const Icon(Icons.edit_rounded),
                        ),
                        IconButton(
                          onPressed: () => Navigator.pop(ctx),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Detay Satırları (${detaylar.length})',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: () async {
                            if (await _detaySatirDuzenle(kayit)) await yenile();
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Satır Ekle'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: detaylar.isEmpty
                        ? const Center(child: Text('Henüz detay satırı yok.'))
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                            itemCount: detaylar.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 4),
                            itemBuilder: (_, i) {
                              final d = detaylar[i];
                              final baslik = '${d['urun_adi'] ?? d['hesap_kodu'] ?? d['uretici_kodu'] ?? (widget.tanim.detayAlanlar.isEmpty ? null : d[widget.tanim.detayAlanlar.first.keyName]) ?? 'Satır ${i + 1}'}';
                              final ozet = widget.tanim.detayAlanlar
                                  .skip(1)
                                  .take(5)
                                  .map((a) => '${a.label}: ${d[a.keyName] ?? '-'}')
                                  .join(' • ');
                              return Card(
                                child: ListTile(
                                  leading: CircleAvatar(child: Text('${i + 1}')),
                                  title: Text(baslik),
                                  subtitle: Text(
                                    ozet,
                                    maxLines: mobil ? 3 : 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Wrap(
                                    spacing: 2,
                                    children: [
                                      IconButton(
                                        tooltip: 'Düzenle',
                                        onPressed: () async {
                                          if (await _detaySatirDuzenle(kayit, d)) await yenile();
                                        },
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        tooltip: 'Sil',
                                        onPressed: () async {
                                          final ok = await showDialog<bool>(
                                            context: ctx,
                                            builder: (c) => AlertDialog(
                                              title: const Text('Detay satırını sil'),
                                              content: const Text('Bu satır silinecek. Devam edilsin mi?'),
                                              actions: [
                                                TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                                                FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('Sil')),
                                              ],
                                            ),
                                          );
                                          if (ok == true) {
                                            await _detaySatirSil(d);
                                            await yenile();
                                          }
                                        },
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _sil(Map<String, dynamic> kayit) async {
    final onay = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Kaydı Sil'),
        content: const Text('Bu kayıt silinecek. Devam edilsin mi?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sil')),
        ],
      ),
    );
    if (onay != true) return;
    try {
      await SupabaseService.supabase
          .from(widget.tanim.tablo)
          .delete()
          .eq(widget.tanim.idAlan, kayit[widget.tanim.idAlan]);
      await _yukle();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silinemedi: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mobil = MediaQuery.sizeOf(context).width < 720;
    final liste = _gorunen;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.tanim.baslik),
        actions: [
          IconButton(onPressed: _yukle, tooltip: 'Yenile', icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: EdgeInsets.all(mobil ? 8 : 16),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(widget.tanim.ikon, size: 30, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(widget.tanim.baslik, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(widget.tanim.altBaslik),
                    ])),
                    FilledButton.icon(onPressed: () => _duzenle(), icon: const Icon(Icons.add), label: Text(mobil ? 'Yeni' : 'Yeni Kayıt')),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _arama,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Kayıtlarda ara...', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _yukleniyor
                  ? const Center(child: CircularProgressIndicator())
                  : _hata != null
                      ? _KurulumUyarisi(hata: _hata!, onYenile: _yukle)
                      : liste.isEmpty
                          ? const Center(child: Text('Henüz kayıt yok.'))
                          : ListView.separated(
                              itemCount: liste.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 6),
                              itemBuilder: (context, i) {
                                final x = liste[i];
                                final ozet = widget.tanim.alanlar.take(4).map((a) => '${a.label}: ${x[a.keyName] ?? '-'}').join('   •   ');
                                final baslik = widget.tanim.alanlar.isEmpty ? 'Kayıt' : (x[widget.tanim.alanlar.first.keyName] ?? 'Kayıt').toString();
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(child: Icon(widget.tanim.ikon)),
                                    title: Text(baslik, style: const TextStyle(fontWeight: FontWeight.w600)),
                                    subtitle: Text(ozet, maxLines: mobil ? 3 : 2, overflow: TextOverflow.ellipsis),
                                    trailing: PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'edit') _duzenle(x);
                                        if (v == 'delete') _sil(x);
                                      },
                                      itemBuilder: (_) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                                        PopupMenuItem(value: 'delete', child: Text('Sil')),
                                      ],
                                    ),
                                    onTap: () => _kayitDetayi(x),
                                  ),
                                );
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _KurulumUyarisi extends StatelessWidget {
  final String hata;
  final VoidCallback onYenile;
  const _KurulumUyarisi({required this.hata, required this.onYenile});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.settings_suggest_rounded, size: 52, color: Colors.orange),
              const SizedBox(height: 10),
              const Text('Kurumsal modül veritabanı kurulumu gerekiyor.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              const Text('Proje içindeki supabase/migrations/20260812_kurumsal_erp.sql dosyasını Supabase SQL Editor’da bir kez çalıştırın. Mevcut tablolar silinmez; yalnız yeni modül tabloları eklenir.', textAlign: TextAlign.center),
              const SizedBox(height: 10),
              SelectableText(hata, maxLines: 5, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onYenile, icon: const Icon(Icons.refresh), label: const Text('Tekrar Dene')),
            ]),
          ),
        ),
      ),
    );
  }
}
