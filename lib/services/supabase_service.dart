// lib/services/supabase_service.dart

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/stok_model.dart';
import 'sayfali_veri_service.dart';

class SupabaseService {
  static final SupabaseClient supabase = Supabase.instance.client;

  //------------------------------------------------------
  // STOK ALT TABLOLARINI GETİR
  //------------------------------------------------------

  static Future<List<String>> _listeGetir({
    required String tablo,
    required String kolon,
    required int stokId,
  }) async {
    try {
      final response = await supabase
          .from(tablo)
          .select(kolon)
          .eq('stok_id', stokId);

      return (response as List)
          .map((item) => item[kolon]?.toString() ?? '')
          .where((deger) => deger.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('_listeGetir hata: $e');
      return [];
    }
  }

  //------------------------------------------------------
  // RESİMLERİ GETİR
  //------------------------------------------------------

  static Future<List<String>> _resimleriGetir(
    int stokId,
  ) async {
    try {
      final response = await supabase
          .from('stok_resim')
          .select('resim_url')
          .eq('stok_id', stokId)
          .order('sira');

      return (response as List)
          .map(
            (item) =>
                item['resim_url']?.toString() ?? '',
          )
          .where((deger) => deger.isNotEmpty)
          .toList();
    } catch (e) {
      debugPrint('_resimleriGetir hata: $e');
      return [];
    }
  }

  //------------------------------------------------------
  // STOKLARI GETİR
  //------------------------------------------------------

  static Future<List<StokModel>> stoklariGetir({
    String? aramaMetni,
    int? limit,
  }) async {
    try {
      dynamic response;

      if (aramaMetni != null &&
          aramaMetni.trim().isNotEmpty) {
        response = await supabase.rpc(
          'urun_ara',
          params: {
            'arama': aramaMetni.trim(),
          },
        );
      } else {
        if (limit != null && limit > 0) {
          response = await supabase
              .from('stoklar')
              .select()
              .order('urun_adi')
              .limit(limit);
        } else {
          response = await SayfaliVeriService.tumunuGetir(
            (baslangic, bitis) => supabase
                .from('stoklar')
                .select()
                .order('urun_adi')
                .range(baslangic, bitis),
          );
        }
      }

      final stokResponse =
          List<Map<String, dynamic>>.from(response);

      return stokResponse
          .map((json) => StokModel.fromJson(json))
          .toList();
    } catch (e) {
      debugPrint('stoklariGetir hata: $e');
      return [];
    }
  }

  //------------------------------------------------------
  // DASHBOARD STOKLARI
  //------------------------------------------------------

  static Future<List<Map<String, dynamic>>>
      getStoklar() async {
    try {
      final response = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => supabase
            .from('stoklar')
            .select(
              'urun_adi, stok_miktari, min_stok, '
              'alis_fiyati, satis_fiyati',
            )
            .range(baslangic, bitis),
      );

      return List<Map<String, dynamic>>.from(
        response,
      );
    } catch (e) {
      debugPrint('❌ getStoklar hatası: $e');
      return [];
    }
  }

  //------------------------------------------------------
  // CARİLER
  //------------------------------------------------------

  static Future<List<Map<String, dynamic>>>
      getCariler() async {
    try {
      final response = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => supabase
            .from('cariler')
            .select('cari_id, unvan, cari_tipi, bakiye')
            .order('unvan')
            .range(baslangic, bitis),
      );

      return List<Map<String, dynamic>>.from(
        response,
      );
    } catch (e) {
      debugPrint('❌ getCariler hatası: $e');
      return [];
    }
  }

  //------------------------------------------------------
  // EN ÇOK SATILANLAR
  //------------------------------------------------------

  static Future<List<Map<String, dynamic>>>
      enCokSatilanUrunleriGetir() async {
    try {
      final response = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => supabase
            .from('satis_detay')
            .select()
            .range(baslangic, bitis),
      );

      return List<Map<String, dynamic>>.from(
        response,
      );
    } catch (e) {
      debugPrint(
        '❌ enCokSatilanUrunleriGetir hatası: $e',
      );
      return [];
    }
  }

  //------------------------------------------------------
  // SATIŞLARI GETİR
  //------------------------------------------------------

  static Future<List<Map<String, dynamic>>>
      getSatislar() async {
    try {
      final response = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => supabase
            .from('satis_baslik')
            .select()
            .order('tarih', ascending: false)
            .range(baslangic, bitis),
      );

      return List<Map<String, dynamic>>.from(
        response,
      );
    } catch (e) {
      debugPrint('❌ getSatislar hatası: $e');
      return [];
    }
  }

  //------------------------------------------------------
  // ALIŞLARI GETİR
  //------------------------------------------------------

  static Future<List<Map<String, dynamic>>>
      getAlislar() async {
    try {
      final response = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => supabase
            .from('alis_baslik')
            .select()
            .order('tarih', ascending: false)
            .range(baslangic, bitis),
      );

      return List<Map<String, dynamic>>.from(
        response,
      );
    } catch (e) {
      debugPrint('❌ getAlislar hatası: $e');
      return [];
    }
  }

  //------------------------------------------------------
  // KÂR ZARAR RAPORU
  //------------------------------------------------------

  static Future<Map<String, dynamic>>
      getKarZararRaporu() async {
    try {
      double sayi(dynamic value) => value is num
          ? value.toDouble()
          : double.tryParse(
                value?.toString().replaceAll(',', '.') ?? '0',
              ) ??
              0;

      final basliklar = await getSatislar();
      final aktifSatislar = <int>{};
      for (final baslik in basliklar) {
        final durum = baslik['durum']?.toString().trim().toUpperCase() ?? '';
        if (durum == 'IPTAL' || durum == 'İPTAL') continue;
        final id = int.tryParse(baslik['satis_id']?.toString() ?? '');
        if (id != null) aktifSatislar.add(id);
      }

      final detaylar = await SayfaliVeriService.tumunuGetir(
        (baslangic, bitis) => supabase
            .from('satis_detay')
            .select(
              'satis_id, miktar, birim_fiyat, alis_fiyati, indirim',
            )
            .range(baslangic, bitis),
      );

      var toplamSatis = 0.0;
      var toplamMaliyet = 0.0;
      for (final detay in detaylar) {
        final satisId = int.tryParse(detay['satis_id']?.toString() ?? '');
        if (satisId == null || !aktifSatislar.contains(satisId)) continue;
        final miktar = sayi(detay['miktar']);
        final indirim = sayi(detay['indirim']);
        toplamSatis += miktar *
            sayi(detay['birim_fiyat']) *
            (1 - indirim / 100);
        toplamMaliyet += miktar * sayi(detay['alis_fiyati']);
      }

      return {
        'toplam_satis': toplamSatis,
        'toplam_maliyet': toplamMaliyet,
        'kar_zarar': toplamSatis - toplamMaliyet,
        'toplam_kar': toplamSatis - toplamMaliyet,
        'toplam_ciro': toplamSatis,
      };
    } catch (e) {
      debugPrint(
        '❌ getKarZararRaporu hatası: $e',
      );
      return {};
    }
  }

  //------------------------------------------------------
  // YENİ BELGE NO GETİR
  //------------------------------------------------------

  static Future<String> yeniBelgeNoGetir({
    required String belgeTipi,
  }) async {
    try {
      final response = await supabase.rpc(
        'yeni_belge_no',
        params: {
          'p_belge_tipi': belgeTipi,
        },
      );

      final belgeNo =
          response?.toString().trim() ?? '';

      if (belgeNo.isEmpty) {
        throw Exception(
          'Yeni belge numarası üretilemedi.',
        );
      }

      return belgeNo;
    } catch (e) {
      debugPrint(
        'Belge numarası oluşturma hatası: $e',
      );
      rethrow;
    }
  }

  //------------------------------------------------------
  // ALIŞ YAP
  //------------------------------------------------------

  static Future<int?> alisYap({
    required int cariId,
    int? kasaId,
    required String odemeTipi,
    required String faturaNo,
    required int depoId,
    required String kullanici,
    required List<Map<String, dynamic>> sepet,
  }) async {
    try {
      if (sepet.isEmpty) {
        throw Exception(
          'Alış kalemleri boş.',
        );
      }

      final odeme =
          odemeTipi.trim().toLowerCase();

      final veresiyeMi =
          odeme == 'veresiye' ||
          odeme == 'hesap';

      if (!veresiyeMi && kasaId == null) {
        throw Exception(
          'Nakit, kart veya havale işleminde '
          'kasa seçilmelidir.',
        );
      }

      final response = await supabase.rpc(
        'alis_olustur',
        params: {
          'p_cari_id': cariId,
          'p_kasa_id':
              veresiyeMi ? null : kasaId,
          'p_odeme_tipi': odemeTipi,
          'p_fatura_no': faturaNo.trim(),
          'p_depo_id': depoId,
          'p_kullanici': kullanici,
          'p_detaylar': sepet,
        },
      );

      final alisId = int.tryParse(
        response?.toString() ?? '',
      );

      if (alisId == null) {
        throw Exception(
          'Alış fonksiyonu geçerli bir '
          'alış ID döndürmedi.',
        );
      }

      debugPrint(
        'ALIŞ BAŞARILI. Alış ID: $alisId',
      );

      return alisId;
    } catch (e, stackTrace) {
      debugPrint('ALIŞ HATASI: $e');

      debugPrintStack(
        stackTrace: stackTrace,
      );

      rethrow;
    }
  }

  //------------------------------------------------------
  // SATIŞ YAP - TEK TRANSACTION
  //------------------------------------------------------

  static Future<int> satisYap({
    required int cariId,
    int? kasaId,
    required String odemeTipi,
    required String faturaNo,
    required String belgeNo,
    required int depoId,
    required String fiyatTipi,
    required String kullanici,
    required List<Map<String, dynamic>> sepet,
  }) async {
    try {
      if (sepet.isEmpty) {
        throw Exception('Satış kalemleri boş.');
      }

      final odeme = odemeTipi.trim().toLowerCase();
      final veresiyeMi = odeme == 'veresiye' || odeme == 'hesap';

      if (!veresiyeMi && kasaId == null) {
        throw Exception(
          'Nakit, kart veya havale satışında kasa seçilmelidir.',
        );
      }

      final response = await supabase.rpc(
        'satis_olustur',
        params: {
          'p_cari_id': cariId,
          'p_kasa_id': veresiyeMi ? null : kasaId,
          'p_odeme_tipi': odemeTipi,
          'p_fatura_no': faturaNo.trim(),
          'p_belge_no': belgeNo.trim(),
          'p_depo_id': depoId,
          'p_fiyat_tipi': fiyatTipi,
          'p_kullanici': kullanici,
          'p_detaylar': sepet,
        },
      );

      final satisId = int.tryParse(response?.toString() ?? '');

      if (satisId == null) {
        throw Exception(
          'Satış fonksiyonu geçerli bir satış ID döndürmedi.',
        );
      }

      debugPrint('SATIŞ BAŞARILI. Satış ID: $satisId');
      return satisId;
    } catch (e, stackTrace) {
      debugPrint('SATIŞ HATASI: $e');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  //------------------------------------------------------
  // DEPOLAR
  //------------------------------------------------------

  static Future<List<Map<String, dynamic>>> depolariGetir() async {
    final response = await supabase
        .from('depolar')
        .select()
        .order('depo_adi');

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<void> depoKaydet({
    int? depoId,
    required String depoKodu,
    required String depoAdi,
    required String depoTipi,
    required bool aktif,
    required bool satilabilir,
    required String aciklama,
  }) async {
    final veri = {
      'depo_kodu': depoKodu,
      'depo_adi': depoAdi,
      'depo_tipi': depoTipi,
      'aktif': aktif,
      'satilabilir': satilabilir,
      'aciklama': aciklama.isEmpty ? null : aciklama,
    };

    if (depoId == null) {
      await supabase.from('depolar').insert(veri);
    } else {
      await supabase
          .from('depolar')
          .update(veri)
          .eq('depo_id', depoId);
    }
  }

  static Future<List<Map<String, dynamic>>> depoStoklariniGetir(
    int depoId,
  ) async {
    final response = await supabase
        .from('v_pro_stok_depo_durumu')
        .select()
        .eq('depo_id', depoId)
        .order('urun_adi');

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<List<Map<String, dynamic>>>
      iadeDeposuStoklariniGetir() async {
    final response = await supabase
        .from('v_pro_stok_depo_durumu')
        .select()
        .eq('depo_tipi', 'IADE')
        .gt('miktar', 0)
        .order('urun_adi');

    return List<Map<String, dynamic>>.from(response);
  }

  static Future<int> depolarArasiTransfer({
    required int stokId,
    required int kaynakDepoId,
    required int hedefDepoId,
    required double miktar,
    String? belgeTipi,
    int? belgeId,
    String? belgeNo,
    String? aciklama,
    required String kullanici,
  }) async {
    final response = await supabase.rpc(
      'depolar_arasi_transfer',
      params: {
        'p_stok_id': stokId,
        'p_kaynak_depo_id': kaynakDepoId,
        'p_hedef_depo_id': hedefDepoId,
        'p_miktar': miktar,
        'p_belge_tipi': belgeTipi ?? 'TRANSFER',
        'p_belge_id': belgeId,
        'p_belge_no': belgeNo,
        'p_aciklama': aciklama,
        'p_kullanici': kullanici,
      },
    );

    return int.tryParse(response?.toString() ?? '') ?? 0;
  }

  static Future<int> iadeKontrolSonucu({
    required int stokId,
    required double miktar,
    required String sonuc,
    int? hedefNormalDepoId,
    String? aciklama,
    required String kullanici,
  }) async {
    final response = await supabase.rpc(
      'iade_kontrol_sonucu',
      params: {
        'p_stok_id': stokId,
        'p_miktar': miktar,
        'p_sonuc': sonuc,
        'p_hedef_normal_depo_id': hedefNormalDepoId,
        'p_aciklama': aciklama,
        'p_kullanici': kullanici,
      },
    );

    return int.tryParse(response?.toString() ?? '') ?? 0;
  }

  static Future<List<Map<String, dynamic>>> stokDepoOzetGetir() async {
    // Tek kaynak: depo bazlı güncel stok görünümü.
    // v_stok_ozet yerine burada doğrudan v_stok_depo_durumu
    // toplanır; böylece NORMAL / IADE / HASARLI ayrımı her ekranda aynıdır.
    final response = await supabase
        .from('v_pro_stok_depo_durumu')
        .select();

    final satirlar =
        List<Map<String, dynamic>>.from(response);

    final ozetler = <int, Map<String, dynamic>>{};

    for (final satir in satirlar) {
      final stokId = int.tryParse(
            satir['stok_id']?.toString() ?? '',
          ) ??
          0;
      if (stokId <= 0) continue;

      final miktar = double.tryParse(
            satir['miktar']?.toString() ?? '0',
          ) ??
          0.0;

      final tip = (satir['depo_tipi']?.toString() ?? '')
          .trim()
          .toUpperCase();

      final ozet = ozetler.putIfAbsent(
        stokId,
        () => <String, dynamic>{
          'stok_id': stokId,
          'urun_adi': satir['urun_adi'],
          'satilabilir_stok': 0.0,
          'iade_bekleyen_stok': 0.0,
          'hasarli_stok': 0.0,
          'fiziksel_toplam_stok': 0.0,
        },
      );

      if (tip == 'NORMAL') {
        ozet['satilabilir_stok'] =
            (ozet['satilabilir_stok'] as double) + miktar;
      } else if (tip == 'IADE' || tip == 'İADE') {
        ozet['iade_bekleyen_stok'] =
            (ozet['iade_bekleyen_stok'] as double) + miktar;
      } else if (tip == 'HASARLI') {
        ozet['hasarli_stok'] =
            (ozet['hasarli_stok'] as double) + miktar;
      }

      // Transit kullanılmıyor; fiziksel toplam sadece işletmenin
      // gerçek depolarındaki NORMAL + IADE + HASARLI miktardır.
      if (tip == 'NORMAL' ||
          tip == 'IADE' ||
          tip == 'İADE' ||
          tip == 'HASARLI') {
        ozet['fiziksel_toplam_stok'] =
            (ozet['fiziksel_toplam_stok'] as double) + miktar;
      }
    }

    return ozetler.values.toList();
  }


  static Future<List<Map<String, dynamic>>>
      depoTipiStoklariniGetir(
    String depoTipi,
  ) async {
    final response = await supabase
        .from('v_pro_stok_depo_durumu')
        .select()
        .eq('depo_tipi', depoTipi)
        .gt('miktar', 0)
        .order('urun_adi');

    return List<Map<String, dynamic>>.from(
      response,
    );
  }

  static Future<Map<String, dynamic>>
      stokDepoDagilimiGetir(
    int stokId,
  ) async {
    final response = await supabase
        .from('v_pro_stok_depo_durumu')
        .select()
        .eq('stok_id', stokId);

    final satirlar =
        List<Map<String, dynamic>>.from(response);

    double normal = 0;
    double iade = 0;
    double hasarli = 0;
    double transit = 0;

    for (final satir in satirlar) {
      final miktar = double.tryParse(
            satir['miktar']?.toString() ?? '0',
          ) ??
          0;

      switch (
          (satir['depo_tipi']?.toString() ?? '').trim().toUpperCase()) {
        case 'NORMAL':
          normal += miktar;
          break;
        case 'IADE':
        case 'İADE':
          iade += miktar;
          break;
        case 'HASARLI':
          hasarli += miktar;
          break;
        case 'TRANSIT':
          transit += miktar;
          break;
      }
    }

    return {
      'normal': normal,
      'iade': iade,
      'hasarli': hasarli,
      'transit': transit,
      'toplam':
          normal + iade + hasarli,
      'satirlar': satirlar,
    };
  }

}
