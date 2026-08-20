import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';

import 'excel_download.dart';
import 'supabase_service.dart';

class ExcelService {
  static dynamic _deger(dynamic v) {
    if (v == null) return null;
    // excel paketindeki TextCellValue/SharedString gibi nesneleri Supabase'e
    // doğrudan göndermiyoruz. JSON kodlanabilir primitive değere indirger.
    final metin = v.toString();
    if (metin == 'null') return null;
    return metin;
  }

  static String _s(dynamic v) => _deger(v)?.toString() ?? '';

  static String _baslik(String value) {
    var s = value.trim().toLowerCase();
    const tr = <String, String>{
      'ı': 'i', 'İ': 'i', 'ş': 's', 'Ş': 's', 'ğ': 'g', 'Ğ': 'g',
      'ü': 'u', 'Ü': 'u', 'ö': 'o', 'Ö': 'o', 'ç': 'c', 'Ç': 'c',
    };
    tr.forEach((k, v) => s = s.replaceAll(k, v));
    s = s
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    const aliases = <String, String>{
      'urun': 'urun_adi', 'urun_ad': 'urun_adi', 'urun_adi': 'urun_adi',
      'uretici': 'uretici_kodu', 'uretici_kod': 'uretici_kodu',
      'uretici_kodu': 'uretici_kodu',
      'oem': 'oem_no', 'oem_no': 'oem_no', 'oem_kodu': 'oem_no',
      'grup': 'grup_kodu', 'grup_kodu': 'grup_kodu',
      'resim': 'resim_link', 'resim_linki': 'resim_link',
      'resim_url': 'resim_link', 'resim_link': 'resim_link',
      'cross': 'cross_kod', 'cross_kod': 'cross_kod',
      'rakip': 'rakip_kod', 'rakip_kod': 'rakip_kod',
      'minimum_stok': 'min_stok',
      'alis': 'alis_fiyati', 'alis_fiyati': 'alis_fiyati',
      'perakende': 'satis_fiyati_perakende',
      'satis_fiyati': 'satis_fiyati_perakende',
      'toptan': 'satis_fiyati_toptan',
      'stok': 'stok_miktari', 'miktar': 'stok_miktari',
    };
    return aliases[s] ?? s;
  }

  static Future<String> stoklariAktar() async {
    final r = await SupabaseService.supabase.from('stoklar').select().order('urun_adi');
    final l = List<Map<String, dynamic>>.from(r);
    final e = Excel.createExcel();
    final varsayilan = e.getDefaultSheet();
    final s = e['STOKLAR'];
    if (varsayilan != null && varsayilan != 'STOKLAR') {
      e.delete(varsayilan);
    }
    final h = <String>[
      'urun_adi', 'uretici_kodu', 'oem_no', 'marka', 'model', 'arac',
      'urun_ozellik', 'grup_kodu', 'resim_link', 'barkod', 'cross_kod',
      'rakip_kod', 'raf', 'birim', 'min_stok', 'kdv', 'alis_fiyati',
      'satis_fiyati_perakende', 'satis_fiyati_toptan', 'stok_miktari', 'aktif',
    ];
    s.appendRow(h);
    for (final x in l) {
      s.appendRow(h.map((k) => x[k]).toList());
    }
    final b = e.encode();
    if (b == null) throw Exception('Excel oluşturulamadı.');
    return ExcelDownload.kaydet(dosyaAdi: 'PRO_ERP_STOKLAR.xlsx', bytes: b);
  }

  static Future<String> carileriAktar() async {
    final r = await SupabaseService.supabase.from('cariler').select().order('unvan');
    final l = List<Map<String, dynamic>>.from(r);
    final e = Excel.createExcel();
    final varsayilan = e.getDefaultSheet();
    final s = e['CARILER'];
    if (varsayilan != null && varsayilan != 'CARILER') {
      e.delete(varsayilan);
    }
    final h = [
      'cari_id', 'cari_tipi', 'unvan', 'yetkili', 'telefon', 'eposta',
      'adres', 'il', 'ilce', 'risk_limiti', 'vade_gun', 'fiyat_tipi',
      'notlar', 'aktif',
    ];
    s.appendRow(h);
    for (final x in l) {
      s.appendRow(h.map((k) => x[k]).toList());
    }
    final b = e.encode();
    if (b == null) throw Exception('Excel oluşturulamadı.');
    return ExcelDownload.kaydet(dosyaAdi: 'PRO_ERP_CARILER.xlsx', bytes: b);
  }

  static Future<int> stoklariIceAktar() async {
    final p = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (p == null || p.files.isEmpty) return 0;
    final b = p.files.single.bytes;
    if (b == null) throw Exception('Dosya okunamadı.');

    final e = Excel.decodeBytes(b);
    if (e.tables.isEmpty) return 0;
    final sh = e.tables['STOKLAR'] ??
        e.tables.values.firstWhere(
          (t) => t.rows.isNotEmpty &&
              t.rows.any((r) => r.any((c) => _s(c?.value).trim().isNotEmpty)),
          orElse: () => e.tables.values.first,
        );
    if (sh.rows.isEmpty) return 0;

    final h = sh.rows.first.map((c) => _baslik(_s(c?.value))).toList();
    const izinli = <String>{
      'urun_adi', 'uretici_kodu', 'oem_no', 'marka', 'model', 'arac',
      'urun_ozellik', 'grup_kodu', 'resim_link', 'barkod', 'cross_kod',
      'rakip_kod', 'raf', 'birim', 'min_stok', 'kdv', 'alis_fiyati',
      'satis_fiyati_perakende', 'satis_fiyati_toptan', 'aktif',
    };

    int n = 0;
    for (int i = 1; i < sh.rows.length; i++) {
      final cells = sh.rows[i];
      final x = <String, dynamic>{};
      for (int c = 0; c < h.length; c++) {
        final key = h[c];
        if (key.isNotEmpty && c < cells.length) x[key] = _deger(cells[c]?.value);
      }

      final kod = _s(x['uretici_kodu']).trim();
      final ad = _s(x['urun_adi']).trim();
      if (kod.isEmpty && ad.isEmpty) continue;

      x.remove('stok_id');
      x.remove('stok_miktari');

      for (final key in const [
        'min_stok', 'kdv', 'alis_fiyati',
        'satis_fiyati_perakende', 'satis_fiyati_toptan'
      ]) {
        if (x[key] != null) {
          final raw = _s(x[key]).replaceAll(',', '.').trim();
          final n = double.tryParse(raw);
          if (n != null) x[key] = n;
        }
      }
      if (x['aktif'] != null) {
        final raw = _s(x['aktif']).trim().toLowerCase();
        x['aktif'] = !const ['0', 'false', 'hayir', 'hayır', 'pasif'].contains(raw);
      }

      x.removeWhere((k, v) => !izinli.contains(k));
      x.removeWhere((k, v) => v == null || (v is String && v.trim().isEmpty));

      if (kod.isNotEmpty) {
        final m = List<Map<String, dynamic>>.from(
          await SupabaseService.supabase
              .from('stoklar')
              .select('stok_id')
              .eq('uretici_kodu', kod)
              .limit(1),
        );
        if (m.isNotEmpty) {
          await SupabaseService.supabase
              .from('stoklar')
              .update(x)
              .eq('stok_id', m.first['stok_id']);
        } else {
          await SupabaseService.supabase.from('stoklar').insert(x);
        }
      } else {
        await SupabaseService.supabase.from('stoklar').insert(x);
      }
      n++;
    }
    return n;
  }

  static Future<int> carileriIceAktar() async {
    final p = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      withData: true,
    );
    if (p == null || p.files.isEmpty) return 0;
    final b = p.files.single.bytes;
    if (b == null) throw Exception('Dosya okunamadı.');

    final e = Excel.decodeBytes(b);
    if (e.tables.isEmpty) return 0;
    final sh = e.tables['CARILER'] ??
        e.tables.values.firstWhere(
          (t) => t.rows.isNotEmpty &&
              t.rows.any((r) => r.any((c) => _s(c?.value).trim().isNotEmpty)),
          orElse: () => e.tables.values.first,
        );
    if (sh.rows.isEmpty) return 0;

    final h = sh.rows.first.map((c) => _baslik(_s(c?.value))).toList();
    int n = 0;
    for (int i = 1; i < sh.rows.length; i++) {
      final cells = sh.rows[i];
      final x = <String, dynamic>{};
      for (int c = 0; c < h.length; c++) {
        if (h[c].isNotEmpty && c < cells.length) x[h[c]] = _deger(cells[c]?.value);
      }
      final ad = _s(x['unvan']).trim();
      if (ad.isEmpty) continue;

      final id = int.tryParse(_s(x['cari_id']));
      x.remove('cari_id');
      x.removeWhere((k, v) => !const {
        'cari_tipi', 'unvan', 'yetkili', 'telefon', 'eposta', 'adres',
        'il', 'ilce', 'risk_limiti', 'vade_gun', 'fiyat_tipi', 'notlar', 'aktif',
      }.contains(k));

      if (id != null) {
        await SupabaseService.supabase.from('cariler').update(x).eq('cari_id', id);
      } else {
        final m = List<Map<String, dynamic>>.from(
          await SupabaseService.supabase
              .from('cariler')
              .select('cari_id')
              .eq('unvan', ad)
              .limit(1),
        );
        if (m.isNotEmpty) {
          await SupabaseService.supabase
              .from('cariler')
              .update(x)
              .eq('cari_id', m.first['cari_id']);
        } else {
          await SupabaseService.supabase.from('cariler').insert(x);
        }
      }
      n++;
    }
    return n;
  }
}
