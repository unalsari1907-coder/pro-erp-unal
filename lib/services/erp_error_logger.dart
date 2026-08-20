import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:postgrest/postgrest.dart';
import 'supabase_service.dart';
import 'yetki_service.dart';

class ErpErrorLogger {
  ErpErrorLogger._();

  static bool _uzakLogDevreDisi = false;

  static Future<void> kaydet(
    Object error,
    StackTrace? stack, {
    String kaynak = 'UYGULAMA',
  }) async {
    debugPrint('PRO ERP HATA [$kaynak]: $error');

    // RLS bu tabloya yazmayı engelliyorsa her Flutter hatasında tekrar tekrar
    // başarısız INSERT denemesi yapıp uygulamayı yavaşlatma.
    if (_uzakLogDevreDisi) return;

    try {
      await SupabaseService.supabase.from('erp_islem_log').insert({
        'tarih': DateTime.now().toUtc().toIso8601String(),
        'tablo': 'SISTEM',
        'islem': 'ERROR',
        'kayit_id': kaynak,
        'kullanici': YetkiService.aktifKullanici,
        'eski_veri': null,
        'yeni_veri': jsonEncode({
          'hata': error.toString(),
          'stack': stack?.toString(),
        }),
      });
    } on PostgrestException catch (logError) {
      if (logError.code == '42501') {
        _uzakLogDevreDisi = true;
        debugPrint(
          'PRO ERP: erp_islem_log RLS yazma izni yok; bu oturumda uzak hata loglama kapatıldı.',
        );
        return;
      }
      debugPrint('PRO ERP hata logu yazılamadı: $logError');
    } catch (logError) {
      debugPrint('PRO ERP hata logu yazılamadı: $logError');
    }
  }
}
