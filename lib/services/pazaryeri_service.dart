import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PazaryeriService {
  static final SupabaseClient _db = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> kanallar() async {
    try {
      final r = await _db.from('erp_pazaryeri_kanallari').select().order('kanal_adi');
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { debugPrint('pazaryeri kanallar: $e'); return []; }
  }

  static Future<List<Map<String, dynamic>>> siparisler() async {
    try {
      final r = await _db.from('erp_pazaryeri_siparisleri').select().order('siparis_tarihi', ascending: false).limit(500);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { debugPrint('pazaryeri siparis: $e'); return []; }
  }

  static Future<List<Map<String, dynamic>>> urunler() async {
    try {
      final r = await _db.from('erp_pazaryeri_urunleri').select().order('updated_at', ascending: false).limit(500);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { debugPrint('pazaryeri urun: $e'); return []; }
  }

  static Future<List<Map<String, dynamic>>> iadeler() async {
    try {
      final r = await _db.from('erp_pazaryeri_iadeleri').select().order('created_at', ascending: false).limit(300);
      return List<Map<String, dynamic>>.from(r);
    } catch (e) { debugPrint('pazaryeri iade: $e'); return []; }
  }

  static Future<void> kanalKaydet(Map<String, dynamic> data) async {
    final id = data['id'];
    if (id == null) { await _db.from('erp_pazaryeri_kanallari').insert(data); }
    else { final copy = Map<String,dynamic>.from(data)..remove('id'); await _db.from('erp_pazaryeri_kanallari').update(copy).eq('id', id); }
  }
}
