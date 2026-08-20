import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'supabase_service.dart';
import 'yetki_service.dart';

class ErpErrorLogger {
  ErpErrorLogger._();

  static Future<void> kaydet(Object error, StackTrace? stack, {String kaynak = 'UYGULAMA'}) async {
    debugPrint('PRO ERP HATA [$kaynak]: $error');
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
    } catch (logError) {
      debugPrint('PRO ERP hata logu yazılamadı: $logError');
    }
  }
}
