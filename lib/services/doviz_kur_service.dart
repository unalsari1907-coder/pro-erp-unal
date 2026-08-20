import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class DovizKurService {
  DovizKurService._();

  static const List<String> varsayilanDovizler = <String>[
    'USD',
    'EUR',
    'GBP',
    'CHF',
    'JPY',
  ];

  static String _bugun() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  static Future<List<Map<String, dynamic>>> kurlariGetir({
    int limit = 250,
  }) async {
    final response = await SupabaseService.supabase
        .from('erp_doviz_kurlari')
        .select()
        .order('tarih', ascending: false)
        .order('para_birimi')
        .limit(limit);
    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<List<Map<String, dynamic>>> bugununKurlariGetir() async {
    final response = await SupabaseService.supabase
        .from('erp_doviz_kurlari')
        .select()
        .eq('tarih', _bugun())
        .order('para_birimi');
    return List<Map<String, dynamic>>.from(response as List);
  }

  static Future<bool> bugununKuruVarMi() async {
    try {
      final response = await SupabaseService.supabase
          .from('erp_doviz_kurlari')
          .select('kur_id')
          .eq('tarih', _bugun())
          .limit(1);
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('bugununKuruVarMi hata: $e');
      return false;
    }
  }

  /// ERP her gün ilk açıldığında çağrılır. O güne ait TCMB kaydı yoksa
  /// Supabase Edge Function üzerinden resmi TCMB kurlarını çeker.
  static Future<void> gunlukKurKontrolEt() async {
    try {
      if (await bugununKuruVarMi()) return;
      await tcmbKurlariniCek();
    } catch (e) {
      // Kur servisi ERP açılışını hiçbir zaman engellemez.
      debugPrint('Günlük kur otomatik çekilemedi: $e');
    }
  }

  static Future<Map<String, dynamic>> tcmbKurlariniCek({
    List<String> dovizler = varsayilanDovizler,
  }) async {
    final response = await SupabaseService.supabase.functions.invoke(
      'tcmb-kur-guncelle',
      body: <String, dynamic>{'dovizler': dovizler},
    );

    final data = response.data;
    if (data is Map) {
      final result = Map<String, dynamic>.from(data);
      if (result['ok'] == false) {
        throw Exception(result['error'] ?? 'TCMB kur güncellemesi başarısız.');
      }
      return result;
    }
    throw Exception('TCMB servisinden geçersiz cevap alındı.');
  }

  static Future<void> manuelKurKaydet({
    required DateTime tarih,
    required String paraBirimi,
    required double alis,
    required double satis,
    double? efektifAlis,
    double? efektifSatis,
  }) async {
    final tarihMetni =
        '${tarih.year.toString().padLeft(4, '0')}-${tarih.month.toString().padLeft(2, '0')}-${tarih.day.toString().padLeft(2, '0')}';

    await SupabaseService.supabase.from('erp_doviz_kurlari').upsert(
      <String, dynamic>{
        'tarih': tarihMetni,
        'para_birimi': paraBirimi.trim().toUpperCase(),
        'alis': alis,
        'satis': satis,
        'efektif_alis': efektifAlis ?? alis,
        'efektif_satis': efektifSatis ?? satis,
        'kaynak': 'MANUEL',
        'guncellenme_tarihi': DateTime.now().toIso8601String(),
      },
      onConflict: 'tarih,para_birimi',
    );
  }

  static Future<Map<String, dynamic>?> belgeKuruGetir(
    String paraBirimi, {
    DateTime? tarih,
  }) async {
    final kod = paraBirimi.trim().toUpperCase();
    if (kod == 'TRY' || kod == 'TL') {
      return <String, dynamic>{
        'para_birimi': 'TRY',
        'alis': 1.0,
        'satis': 1.0,
        'kaynak': 'SABIT',
      };
    }

    final gun = tarih ?? DateTime.now();
    final tarihMetni =
        '${gun.year.toString().padLeft(4, '0')}-${gun.month.toString().padLeft(2, '0')}-${gun.day.toString().padLeft(2, '0')}';

    final response = await SupabaseService.supabase
        .from('erp_doviz_kurlari')
        .select()
        .eq('para_birimi', kod)
        .lte('tarih', tarihMetni)
        .order('tarih', ascending: false)
        .limit(1);

    final liste = List<Map<String, dynamic>>.from(response as List);
    return liste.isEmpty ? null : liste.first;
  }
}
