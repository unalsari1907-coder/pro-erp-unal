import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class KimlikDogrulamaService {
  KimlikDogrulamaService._();

  static Future<bool> guvenliGirisAktifMi() async {
    try {
      final kayit = await SupabaseService.supabase
          .from('erp_sistem_ayarlari')
          .select('deger')
          .eq('anahtar', 'guvenli_giris')
          .maybeSingle();
      final value = kayit?['deger'];
      if (value == null) return true;
      return value != false &&
          value.toString().toLowerCase() != 'false' &&
          value.toString() != '0';
    } catch (_) {
      // Güvenlik ayarı okunamazsa erişimi açık bırakma.
      return true;
    }
  }

  static Future<void> guvenliGirisiAyarla(bool aktif) async {
    if (SupabaseService.supabase.auth.currentUser == null) {
      throw Exception('Önce yönetici hesabıyla giriş yapmalısınız.');
    }
    await SupabaseService.supabase.from('erp_sistem_ayarlari').upsert({
      'anahtar': 'guvenli_giris',
      'deger': aktif,
      'guncellendi': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'anahtar');
  }

  static Future<AuthResponse> girisYap(String eposta, String sifre) {
    return SupabaseService.supabase.auth.signInWithPassword(
      email: eposta.trim(),
      password: sifre,
    );
  }

  static Future<void> cikisYap() => SupabaseService.supabase.auth.signOut();
}
