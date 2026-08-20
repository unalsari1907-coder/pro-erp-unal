import 'dart:convert';

import 'dosya_download.dart';
import 'sayfali_veri_service.dart';
import 'supabase_service.dart';

class YedeklemeSonucu {
  final String dosya;
  final int tabloSayisi;
  final int kayitSayisi;
  final List<String> atlananlar;
  const YedeklemeSonucu({required this.dosya, required this.tabloSayisi, required this.kayitSayisi, required this.atlananlar});
}

class GeriYuklemeSonucu {
  final int tabloSayisi;
  final int kayitSayisi;
  final List<String> hataliTablolar;
  const GeriYuklemeSonucu({required this.tabloSayisi, required this.kayitSayisi, required this.hataliTablolar});
}

class YedeklemeService {
  YedeklemeService._();

  // Supabase 2026-08-13 envanteriyle eşleştirilmiş fiziksel tablolar.
  // View'lar (erp_vade_takip vb.) özellikle dahil değildir; yeniden türetilir.
  // Eski/terk edilmiş satislar, satis_detaylari, alislar, kullanicilar,
  // personel, raporlar ve erp_arac_uyumluluk yeni yedeğe alınmaz.
  static const tablolar = <String>[
    'depolar', 'kasalar', 'cariler', 'stoklar',
    'stok_oem', 'stok_cross', 'stok_rakip', 'stok_resim', 'stok_depo_bakiye',
    'belge_numaralari',
    'erp_hesap_plani', 'erp_doviz_kurlari', 'erp_fiyat_kurallari', 'fiyat_politikalari',
    'erp_arac_katalog_araclar', 'erp_arac_katalog_parcalar', 'erp_seri_lot',
    'satis_siparis_baslik', 'satis_siparis_detay', 'satis_siparis_sevk',
    'alis_siparis_baslik', 'alis_siparis_detay', 'alis_siparis_kabul',
    'satis_irsaliye_baslik', 'satis_irsaliye_detay', 'satis_irsaliye_fatura',
    'alis_irsaliye_baslik', 'alis_irsaliye_detay', 'alis_irsaliye_fatura',
    'satis_baslik', 'satis_detay', 'alis_baslik', 'alis_detay',
    'iade_baslik', 'iade_detay',
    'stok_hareket', 'depo_hareketleri', 'cari_hareket', 'kasa_hareket',
    'cari_virman', 'finans_transfer', 'giderler',
    'erp_kasa_gun_sonu', 'erp_teklifler', 'erp_teklif_detay',
    'erp_muhasebe_fisleri', 'erp_muhasebe_fis_satirlari',
    'erp_cek_senet', 'erp_e_belgeler',
    'erp_satin_alma_talepleri', 'erp_satin_alma_talep_detay', 'erp_onaylar',
    'erp_belge_baglantilari', 'erp_kur_farki_fisleri',
    'erp_kullanicilar', 'erp_firma_ayarlari', 'erp_sistem_ayarlari', 'erp_schema_surumu',
    'erp_pazaryeri_kanallari', 'erp_pazaryeri_urunleri',
    'erp_pazaryeri_siparisleri', 'erp_pazaryeri_siparis_detay',
    'erp_pazaryeri_iadeleri', 'erp_pazaryeri_senkron_log',
    'erp_islem_log', 'erp_sistem_kontrol_log',
  ];

  static Future<YedeklemeSonucu> jsonYedegiAl() async {
    final veri = <String, dynamic>{};
    final atlananlar = <String>[];
    var kayitSayisi = 0;
    for (final tablo in tablolar) {
      try {
        final satirlar = await SayfaliVeriService.tumunuGetir(
          (baslangic, bitis) => SupabaseService.supabase.from(tablo).select().range(baslangic, bitis),
        );
        veri[tablo] = satirlar;
        kayitSayisi += satirlar.length;
      } catch (_) {
        atlananlar.add(tablo);
      }
    }
    final simdi = DateTime.now();
    final damga = '${simdi.year.toString().padLeft(4, '0')}${simdi.month.toString().padLeft(2, '0')}${simdi.day.toString().padLeft(2, '0')}_${simdi.hour.toString().padLeft(2, '0')}${simdi.minute.toString().padLeft(2, '0')}';
    final dosyaAdi = 'PRO_ERP_YEDEK_$damga.json';
    final icerik = const JsonEncoder.withIndent('  ').convert({
      'format': 'PRO_ERP_YEDEK_V3',
      'olusturma_zamani': simdi.toUtc().toIso8601String(),
      'tablo_sayisi': veri.length,
      'kayit_sayisi': kayitSayisi,
      'tablolar': veri,
      'atlanmis_tablolar': atlananlar,
    });
    final dosya = await DosyaDownload.kaydet(dosyaAdi: dosyaAdi, bytes: utf8.encode(icerik), mimeType: 'application/json');
    return YedeklemeSonucu(dosya: dosya, tabloSayisi: veri.length, kayitSayisi: kayitSayisi, atlananlar: atlananlar);
  }

  static Map<String, dynamic> yedegiDogrula(List<int> bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map<String, dynamic>) throw const FormatException('Yedek dosyası JSON nesnesi değil.');
    final format = decoded['format']?.toString() ?? '';
    if (!{'PRO_ERP_YEDEK_V1', 'PRO_ERP_YEDEK_V2', 'PRO_ERP_YEDEK_V3'}.contains(format)) {
      throw FormatException('Desteklenmeyen yedek formatı: $format');
    }
    if (decoded['tablolar'] is! Map) throw const FormatException('Yedek içinde tablolar bölümü yok.');
    return decoded;
  }

  static Future<bool> _tabloYukle(String tablo, List<dynamic> rawListe) async {
    final liste = rawListe.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    const parca = 200;
    for (var i = 0; i < liste.length; i += parca) {
      final son = (i + parca < liste.length) ? i + parca : liste.length;
      await SupabaseService.supabase.from(tablo).upsert(liste.sublist(i, son));
    }
    return true;
  }

  static Future<GeriYuklemeSonucu> jsonYedegiGeriYukle(List<int> bytes) async {
    final decoded = yedegiDogrula(bytes);
    final veri = Map<String, dynamic>.from(decoded['tablolar'] as Map);
    final tamamlanan = <String>{};
    final bekleyen = <String>[];
    var kayitSayisi = 0;

    // FK sırasından dolayı başarısız olan tablolar sonraki turlarda tekrar denenir.
    for (final tablo in tablolar) {
      final raw = veri[tablo];
      if (raw is! List || raw.isEmpty) continue;
      try {
        await _tabloYukle(tablo, raw);
        tamamlanan.add(tablo);
        kayitSayisi += raw.length;
      } catch (_) {
        bekleyen.add(tablo);
      }
    }

    for (var tur = 0; tur < 3 && bekleyen.isNotEmpty; tur++) {
      final tekrar = List<String>.from(bekleyen);
      bekleyen.clear();
      for (final tablo in tekrar) {
        final raw = veri[tablo];
        if (raw is! List || raw.isEmpty) continue;
        try {
          await _tabloYukle(tablo, raw);
          tamamlanan.add(tablo);
          kayitSayisi += raw.length;
        } catch (_) {
          bekleyen.add(tablo);
        }
      }
    }

    return GeriYuklemeSonucu(
      tabloSayisi: tamamlanan.length,
      kayitSayisi: kayitSayisi,
      hataliTablolar: bekleyen,
    );
  }
}
