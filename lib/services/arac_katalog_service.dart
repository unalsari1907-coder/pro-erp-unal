import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AracKatalogImportSonuc {
  final int aracSayisi;
  final int parcaSayisi;
  final int atlananSatir;
  const AracKatalogImportSonuc({
    required this.aracSayisi,
    required this.parcaSayisi,
    required this.atlananSatir,
  });
}

class AracKatalogService {
  static final SupabaseClient _db = Supabase.instance.client;

  static const Map<String, String> _kategoriAdlari = <String, String>{
    'YAG_FILTRESI': 'Yağ Filtresi',
    'HAVA_FILTRESI': 'Hava Filtresi',
    'YAKIT_FILTRESI': 'Yakıt Filtresi',
    'POLEN_FILTRESI': 'Polen Filtresi',
    'KARTER_TAPASI': 'Karter Tapası',
    'BUJI': 'Buji',
    'ON_DISK': 'Ön Disk',
    'ARKA_DISK': 'Arka Disk',
    'ON_BALATA': 'Ön Balata',
    'ARKA_BALATA': 'Arka Balata',
    'TRIGER_SETI': 'Triger Seti',
    'SU_POMPASI': 'Su Pompası',
    'ALT_KAYIS': 'Alternatör Kayışı',
    'ALT_RULMANI': 'Alternatör Rulmanı',
    'EKS_ZINCIR': 'Eksantrik Zinciri',
    'TERMOSTAT': 'Termostat',
    'KAMPANA': 'Kampana',
    'AVARE_RULMANI': 'Avare Rulmanı',
    'KLIMA_VE_SU_POMPA_KAYISI': 'Klima / Su Pompa Kayışı',
    'DEBRIYAJ_TAKIMI': 'Debriyaj Takımı',
    'DEBRIYAJ_RULMANI': 'Debriyaj Rulmanı',
    'ON_AMORTISOR_R_L': 'Ön Amortisör R/L',
    'ARKA_AMORTISOR_R_L': 'Arka Amortisör R/L',
    'SALINCAK_R_L': 'Salıncak R/L',
    'ROTIL_R_L': 'Rotil R/L',
    'ROTBASI_R_L': 'Rotbaşı R/L',
    'ROT_MILI_R_L': 'Rot Mili R/L',
    'ARKA_Z_ROT_R_L': 'Arka Z Rot R/L',
    'ON_Z_ROT_R_L': 'Ön Z Rot R/L',
    'ON_VIRAJ_LASTIK': 'Ön Viraj Lastiği',
    'ARKA_VIRAJ_LASTIK': 'Arka Viraj Lastiği',
    'ARKA_AMORTISOR_TAKOZU': 'Arka Amortisör Takozu',
    'ON_AMORTISOR_TAKOZU': 'Ön Amortisör Takozu',
    'ON_TEKER_RULMANI': 'Ön Teker Rulmanı',
    'ARKA_TEKER_RULMANI': 'Arka Teker Rulmanı',
    'AKS_KOMPLE_R_L': 'Aks Komple R/L',
    'BOBIN': 'Bobin',
    'ON_AMORTISOR_RULMANI': 'Ön Amortisör Rulmanı',
    'SALINCAK_BURCU_KUCUK': 'Salıncak Burcu Küçük',
    'SALINCAK_BURCU_BUYUK': 'Salıncak Burcu Büyük',
    'ON_KABLO': 'Ön Kablo',
    'ARKA_KABLO': 'Arka Kablo',
    'EL_FREN_BALATASI': 'El Fren Balatası',
    'BUJI_KABLOSU': 'Buji Kablosu',
  };

  // Katalogdaki R/L (Right/Left) alanları ERP'de ayrı Sağ / Sol kayıtları olarak tutulur.
  // Böylece her tarafta tek OEM bulunur ve stok eşleştirme tek kod üzerinden güvenilir çalışır.
  static const Map<String, String> _rlKategoriAdlari = <String, String>{
    'ON_AMORTISOR_R_L': 'Ön Amortisör',
    'ARKA_AMORTISOR_R_L': 'Arka Amortisör',
    'SALINCAK_R_L': 'Salıncak',
    'ROTIL_R_L': 'Rotil',
    'ROTBASI_R_L': 'Rotbaşı',
    'ROT_MILI_R_L': 'Rot Mili',
    'ARKA_Z_ROT_R_L': 'Arka Z Rot',
    'ON_Z_ROT_R_L': 'Ön Z Rot',
    'AKS_KOMPLE_R_L': 'Aks Komple',
  };

  static String _sagKod(String eskiKod) => '${eskiKod}_SAG';
  static String _solKod(String eskiKod) => '${eskiKod}_SOL';

  static Map<String, String> _istenenKategoriAdlari() {
    final out = <String, String>{};
    for (final entry in _kategoriAdlari.entries) {
      final temel = _rlKategoriAdlari[entry.key];
      if (temel == null) {
        out[entry.key] = entry.value;
      } else {
        out[_sagKod(entry.key)] = '$temel Sağ';
        out[_solKod(entry.key)] = '$temel Sol';
      }
    }
    return out;
  }

  static String _norm(String s) {
    var x = s.trim().toUpperCase();
    const from = 'ÇĞİÖŞÜÂÊÎÔÛ';
    const to = 'CGIOSUAEIOU';
    for (var i = 0; i < from.length; i++) {
      x = x.replaceAll(from[i], to[i]);
    }
    x = x.replaceAll(RegExp(r'[^A-Z0-9]+'), '_');
    return x.replaceAll(RegExp(r'_+'), '_').replaceAll(RegExp(r'^_|_$'), '');
  }

  static bool _aractanSilinmis(Map<String, dynamic> row) {
    return _cell(row['nitelik']).toUpperCase() == 'SILINDI';
  }

  static String _cell(dynamic v) {
    if (v == null) return '';
    return v
        .toString()
        .replaceAll('<br>', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static List<List<dynamic>> _xlsx(Uint8List bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return <List<dynamic>>[];
    final sheet = excel.tables.values.first;
    if (sheet == null) return <List<dynamic>>[];
    return sheet.rows
        .map((r) => r.map((c) => c == null ? '' : c.value).toList())
        .toList();
  }

  static List<List<dynamic>> _csv(Uint8List bytes) {
    final text = utf8
        .decode(bytes, allowMalformed: true)
        .replaceAll('\uFEFF', '');
    final first = text.split(RegExp(r'\r?\n')).first;
    final sep = first.split(';').length > first.split(',').length ? ';' : ',';
    return CsvToListConverter(
      fieldDelimiter: sep,
      shouldParseNumbers: false,
    ).convert(text);
  }

  static bool _nitelikMi(String value) {
    final n = _norm(value);
    return <String>{
      'BENZINLI',
      'DIZEL',
      'KAMPANA',
      'KAYISLI',
      'ZINCIRLI',
      'ZINCIR',
      'KAYIS',
    }.contains(n);
  }

  static List<String> _kodlariAyir(String raw) {
    var x = raw.replaceAll(RegExp(r'\([^)]*\)'), ' ');
    x = x.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (x.isEmpty || _nitelikMi(x)) return <String>[];
    final parts = x.split(RegExp(r'[+,/;\n|]+'));
    final out = <String>[];
    for (final p in parts) {
      final v = p.trim();
      if (v.isEmpty || _nitelikMi(v)) continue;
      if (RegExp(r'[0-9]').hasMatch(v) && !out.contains(v)) out.add(v);
    }
    return out;
  }

  static String _anahtar(Map<String, String> r) => <String>[
    r['URETICI'] ?? '',
    r['MODEL'] ?? '',
    r['YIL'] ?? '',
    r['MOTOR'] ?? '',
    r['MOTOR_KODU'] ?? '',
    r['SASE'] ?? '',
  ].map(_norm).join('|');

  static bool _oturumKatalogEsitlendi = false;

  static Future<List<Map<String, dynamic>>> _tumParcaKayitlariniGetir() async {
    final sonuc = <Map<String, dynamic>>[];
    const sayfa = 1000;
    var baslangic = 0;
    while (true) {
      final data = await _db
          .from('erp_arac_katalog_parcalar')
          .select(
            'parca_id,arac_id,kategori_kodu,kategori_adi,oem_kodu,ham_deger,nitelik,sira',
          )
          .range(baslangic, baslangic + sayfa - 1);
      final liste = (data as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      sonuc.addAll(liste);
      if (liste.length < sayfa) break;
      baslangic += sayfa;
    }
    return sonuc;
  }

  static Future<List<int>> _tumAracIdleriniGetir() async {
    final sonuc = <int>[];
    const sayfa = 1000;
    var baslangic = 0;
    while (true) {
      final data = await _db
          .from('erp_arac_katalog_araclar')
          .select('arac_id')
          .range(baslangic, baslangic + sayfa - 1);
      final liste = data as List;
      for (final raw in liste) {
        final id = int.tryParse('${(raw as Map)['arac_id']}');
        if (id != null) sonuc.add(id);
      }
      if (liste.length < sayfa) break;
      baslangic += sayfa;
    }
    return sonuc;
  }

  // Ana katalog şablonu artık yalnız sonradan açılan OZEL_ kayıtlarından değil,
  // katalogda bulunan BÜTÜN benzersiz parça kalemlerinden oluşur. Böylece bir
  // araçta 102 standart kalem varsa aynı 102 kalem diğer araçlara da tamamlanır.
  static Future<List<Map<String, dynamic>>> _ortakParcaSablonlari() async {
    final data = await _tumParcaKayitlariniGetir();
    final sonuc = <Map<String, dynamic>>[];
    final gorulen = <String>{};
    for (final row in data) {
      final kod = '${row['kategori_kodu'] ?? ''}'.trim();
      if (kod.isEmpty || !gorulen.add(kod)) continue;
      sonuc.add(<String, dynamic>{
        'kategori_kodu': kod,
        'kategori_adi': '${row['kategori_adi'] ?? ''}',
        'nitelik': '${row['nitelik'] ?? ''}',
      });
    }
    return sonuc;
  }

  static Future<void> _topluParcaEkle(
    List<Map<String, dynamic>> kayitlar,
  ) async {
    const parcaBoyutu = 400;
    for (var i = 0; i < kayitlar.length; i += parcaBoyutu) {
      final son = (i + parcaBoyutu < kayitlar.length)
          ? i + parcaBoyutu
          : kayitlar.length;
      await _db
          .from('erp_arac_katalog_parcalar')
          .insert(kayitlar.sublist(i, son));
    }
  }

  static Future<void> _ortakParcalariAracaTamamla(
    int aracId, {
    List<Map<String, dynamic>>? sablonlar,
    List<Map<String, dynamic>>? tumKayitlar,
  }) async {
    final sablon = sablonlar ?? await _ortakParcaSablonlari();
    if (sablon.isEmpty) return;

    final mevcut = tumKayitlar == null
        ? ((await _db
                      .from('erp_arac_katalog_parcalar')
                      .select('kategori_kodu,sira')
                      .eq('arac_id', aracId))
                  as List)
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList()
        : tumKayitlar
              .where((e) => int.tryParse('${e['arac_id']}') == aracId)
              .toList();

    final kodlar = mevcut.map((e) => '${e['kategori_kodu'] ?? ''}').toSet();
    var sira = -1;
    for (final e in mevcut) {
      final v = int.tryParse('${e['sira'] ?? -1}') ?? -1;
      if (v > sira) sira = v;
    }

    final eklenecek = <Map<String, dynamic>>[];
    for (final t in sablon) {
      final kod = '${t['kategori_kodu'] ?? ''}'.trim();
      if (kod.isEmpty || kodlar.contains(kod)) continue;
      eklenecek.add(<String, dynamic>{
        'arac_id': aracId,
        'kategori_kodu': kod,
        'kategori_adi': '${t['kategori_adi'] ?? ''}',
        'oem_kodu': null,
        'ham_deger': null,
        'nitelik': '${t['nitelik'] ?? ''}',
        'sira': ++sira,
      });
    }
    if (eklenecek.isNotEmpty) await _topluParcaEkle(eklenecek);
  }

  // Uygulama oturumunda ilk katalog açılışında bir defa tüm araçları ana
  // şablonla eşitler. Sonradan eklenen her yeni parça zaten parcaEkle içinde
  // bütün araçlara dağıtılır; yeni araç da aracEkle içinde şablonla tamamlanır.
  static Future<void> ilkAcilistaTumKataloguEsitle() async {
    if (_oturumKatalogEsitlendi) return;
    _oturumKatalogEsitlendi = true;
    try {
      final tumKayitlar = await _tumParcaKayitlariniGetir();
      final sablonlar = <Map<String, dynamic>>[];
      final gorulen = <String>{};
      for (final row in tumKayitlar) {
        final kod = '${row['kategori_kodu'] ?? ''}'.trim();
        if (kod.isEmpty || !gorulen.add(kod)) continue;
        sablonlar.add(<String, dynamic>{
          'kategori_kodu': kod,
          'kategori_adi': '${row['kategori_adi'] ?? ''}',
          'nitelik': '${row['nitelik'] ?? ''}',
        });
      }
      if (sablonlar.isEmpty) return;

      final araclar = await _tumAracIdleriniGetir();
      final mevcutKodlar = <int, Set<String>>{};
      final maxSira = <int, int>{};
      for (final row in tumKayitlar) {
        final id = int.tryParse('${row['arac_id']}');
        if (id == null) continue;
        mevcutKodlar
            .putIfAbsent(id, () => <String>{})
            .add('${row['kategori_kodu'] ?? ''}');
        final sira = int.tryParse('${row['sira'] ?? -1}') ?? -1;
        if (!maxSira.containsKey(id) || sira > maxSira[id]!) maxSira[id] = sira;
      }

      final eklenecek = <Map<String, dynamic>>[];
      for (final id in araclar) {
        final kodlar = mevcutKodlar.putIfAbsent(id, () => <String>{});
        var sira = maxSira[id] ?? -1;
        for (final t in sablonlar) {
          final kod = '${t['kategori_kodu'] ?? ''}'.trim();
          if (kod.isEmpty || !kodlar.add(kod)) continue;
          eklenecek.add(<String, dynamic>{
            'arac_id': id,
            'kategori_kodu': kod,
            'kategori_adi': '${t['kategori_adi'] ?? ''}',
            'oem_kodu': null,
            'ham_deger': null,
            'nitelik': '${t['nitelik'] ?? ''}',
            'sira': ++sira,
          });
        }
      }
      if (eklenecek.isNotEmpty) await _topluParcaEkle(eklenecek);
    } catch (_) {
      _oturumKatalogEsitlendi = false;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> aracEkle({
    required String uretici,
    required String model,
    String yillar = '',
    int? yil,
    String motor = '',
    String yakit = '',
    String motorKodu = '',
    String sase = '',
    String notlar = '',
    String aracSahibi = '',
  }) async {
    final rec = <String, String>{
      'URETICI': uretici.trim(),
      'MODEL': model.trim(),
      'YIL': yil?.toString() ?? '',
      'MOTOR': motor.trim(),
      'MOTOR_KODU': motorKodu.trim(),
      'SASE': sase.trim(),
    };
    final key = _anahtar(rec);
    final row = await _db
        .from('erp_arac_katalog_araclar')
        .upsert(<String, dynamic>{
          'katalog_anahtar': key,
          'yillar': yillar.trim(),
          'uretici': uretici.trim().toUpperCase(),
          'yil': yil,
          'model': model.trim().toUpperCase(),
          'motor': motor.trim().toUpperCase(),
          'yakit': yakit.trim().toUpperCase(),
          'motor_kodu': motorKodu.trim().toUpperCase(),
          'sase': sase.trim().toUpperCase(),
          'notlar': notlar.trim(),
          'arac_sahibi': aracSahibi.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        }, onConflict: 'katalog_anahtar')
        .select()
        .single();
    final sonuc = Map<String, dynamic>.from(row);

    // 2.5.4: Yeni araçta eski katalog kayıtlarını istemciye çekmek yerine
    // ortak şablonu tamamen PostgreSQL tarafında tek INSERT...SELECT ile ekleriz.
    // Bu işlem araç sayısı / toplam katalog satırı büyüse bile hızlı kalır.
    final aracId = int.parse('${sonuc['arac_id']}');
    try {
      await _db.rpc(
        'erp_arac_katalog_arac_sablon_tamamla',
        params: <String, dynamic>{'p_arac_id': aracId},
      );
    } catch (e) {
      throw Exception(
        'Araç kaydedildi ancak hızlı katalog şablonu uygulanamadı. '
        'Önce PRO_ERP_CATALOG_SPEED_FIX_2_5_4.sql dosyasını Supabase SQL Editor’da çalıştırın. Detay: $e',
      );
    }

    _aracAramaCacheTemizle();
    return sonuc;
  }

  static Future<Map<String, dynamic>> aracGuncelle({
    required int aracId,
    required String uretici,
    required String model,
    String yillar = '',
    int? yil,
    String motor = '',
    String yakit = '',
    String motorKodu = '',
    String sase = '',
    String notlar = '',
    String aracSahibi = '',
  }) async {
    final rec = <String, String>{
      'URETICI': uretici.trim(),
      'MODEL': model.trim(),
      'YIL': yil?.toString() ?? '',
      'MOTOR': motor.trim(),
      'MOTOR_KODU': motorKodu.trim(),
      'SASE': sase.trim(),
    };
    final key = _anahtar(rec);
    final row = await _db
        .from('erp_arac_katalog_araclar')
        .update(<String, dynamic>{
          'katalog_anahtar': key,
          'yillar': yillar.trim(),
          'uretici': uretici.trim().toUpperCase(),
          'yil': yil,
          'model': model.trim().toUpperCase(),
          'motor': motor.trim().toUpperCase(),
          'yakit': yakit.trim().toUpperCase(),
          'motor_kodu': motorKodu.trim().toUpperCase(),
          'sase': sase.trim().toUpperCase(),
          'notlar': notlar.trim(),
          'arac_sahibi': aracSahibi.trim(),
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('arac_id', aracId)
        .select()
        .single();
    _aracAramaCacheTemizle();
    return Map<String, dynamic>.from(row);
  }

  /// Seçili aracı siler. `erp_arac_katalog_parcalar.arac_id` yabancı anahtarı
  /// ON DELETE CASCADE olduğu için yalnız bu araca bağlı katalog satırları da
  /// aynı veritabanı işlemiyle temizlenir.
  static Future<void> aracSil({required int aracId}) async {
    if (aracId <= 0) throw Exception('Silinecek araç kaydı bulunamadı.');

    await _db.from('erp_arac_katalog_araclar').delete().eq('arac_id', aracId);
    _aracAramaCacheTemizle();
  }

  static String _ozelKategoriKodu(String ustKategori, String parcaAdi) {
    final ust = _norm(ustKategori.isEmpty ? 'DIGER' : ustKategori);
    final ad = _norm(parcaAdi);
    return 'OZEL_${ust}_${ad.isEmpty ? 'PARCA' : ad}';
  }

  static List<String> _manuelOemleriAyir(String raw) {
    return raw
        .split(RegExp(r'[,;\n]+'))
        .map((e) => e.trim().toUpperCase())
        .where((e) => e.isNotEmpty)
        .toSet()
        .toList();
  }

  static Future<void> parcaEkle({
    required int aracId,
    required String ustKategori,
    required String parcaAdi,
    String oemKodu = '',
  }) async {
    final ad = _parcaAdiStandartla(parcaAdi);
    if (ad.isEmpty) throw Exception('Parça adı boş bırakılamaz.');
    final ust = ustKategori.trim().isEmpty ? 'Diğer' : ustKategori.trim();
    final kategoriKodu = _ozelKategoriKodu(ust, ad);
    final kodlar = _manuelOemleriAyir(oemKodu);

    // 2.5.4: Yeni ortak parçayı bütün araçlara istemci tarafında yüzlerce
    // kayıt çekerek dağıtmak yerine veritabanında tek işlemle yayarız.
    try {
      await _db.rpc(
        'erp_arac_katalog_global_parca_yay',
        params: <String, dynamic>{
          'p_kategori_kodu': kategoriKodu,
          'p_kategori_adi': ad,
          'p_nitelik': 'UST_KATEGORI:$ust',
        },
      );
    } catch (e) {
      throw Exception(
        'Yeni parça hızlı katalog şablonuna eklenemedi. '
        'PRO_ERP_CATALOG_SPEED_FIX_2_5_4.sql çalıştırılmalı. Detay: $e',
      );
    }

    // Seçili araçta girilen OEM'leri kalıcı olarak ekleriz.
    // Boş şablon varsa ilk OEM onu doldurur; diğer OEM'ler ayrı satır olur.
    if (kodlar.isNotEmpty) {
      final seciliRaw = await _db
          .from('erp_arac_katalog_parcalar')
          .select('parca_id,oem_kodu,sira')
          .eq('arac_id', aracId)
          .eq('kategori_kodu', kategoriKodu)
          .order('sira');
      final secili = (seciliRaw as List)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      final mevcutKodlar = secili
          .map((e) => '${e['oem_kodu'] ?? ''}'.trim().toUpperCase())
          .where((e) => e.isNotEmpty)
          .toSet();
      final bos = secili
          .where((e) => '${e['oem_kodu'] ?? ''}'.trim().isEmpty)
          .toList();
      var sira = secili.fold<int>(-1, (m, e) {
        final v = int.tryParse('${e['sira'] ?? -1}') ?? -1;
        return v > m ? v : m;
      });
      var ilk = true;
      for (final kod in kodlar) {
        if (mevcutKodlar.contains(kod)) continue;
        if (ilk && bos.isNotEmpty) {
          await _db
              .from('erp_arac_katalog_parcalar')
              .update(<String, dynamic>{
                'kategori_adi': ad,
                'oem_kodu': kod,
                'ham_deger': kod,
                'nitelik': 'UST_KATEGORI:$ust',
              })
              .eq('parca_id', bos.first['parca_id']);
        } else {
          await _db.from('erp_arac_katalog_parcalar').insert(<String, dynamic>{
            'arac_id': aracId,
            'kategori_kodu': kategoriKodu,
            'kategori_adi': ad,
            'oem_kodu': kod,
            'ham_deger': kod,
            'nitelik': 'UST_KATEGORI:$ust',
            'sira': ++sira,
          });
        }
        mevcutKodlar.add(kod);
        ilk = false;
      }
    }
  }

  static Future<Map<String, dynamic>?> saseIleAracBul(
    String sase, {
    int? haricAracId,
  }) async {
    final temiz = sase.trim().toUpperCase();
    if (temiz.isEmpty) return null;
    var sorgu = _db
        .from('erp_arac_katalog_araclar')
        .select('arac_id,uretici,model,yil,yillar,motor,motor_kodu,sase')
        .eq('sase', temiz);
    final data = await sorgu.limit(10);
    for (final raw in (data as List)) {
      final row = Map<String, dynamic>.from(raw as Map);
      final id = int.tryParse('${row['arac_id']}');
      if (haricAracId != null && id == haricAracId) continue;
      return row;
    }
    return null;
  }


  static String _parcaAdiStandartla(String raw, {String kategoriKodu = ''}) {
    var x = _norm(raw).replaceAll('_', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    final kod = kategoriKodu.trim().toUpperCase();
    final rl = kod.endsWith('_SAG') ||
        kod.endsWith('_SOL') ||
        RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$').hasMatch(x);
    x = x
        .replaceFirst(RegExp(r'(?:\s+R/L|\s+R L|\s+RL|\s+SAG|\s+SOL)$'), '')
        .trim();
    return rl && x.isNotEmpty ? '$x R/L' : x;
  }

  static List<String> _kategoriKodVaryantlari(String raw) {
    var kod = raw.trim().toUpperCase();
    if (kod.endsWith('_SAG')) kod = kod.substring(0, kod.length - 4);
    if (kod.endsWith('_SOL')) kod = kod.substring(0, kod.length - 4);
    return <String>[kod, '${kod}_SAG', '${kod}_SOL'];
  }

  static Future<Map<int, Map<String, int>>> aracOemDurumlari(
    List<int> aracIds,
  ) async {
    if (aracIds.isEmpty) return <int, Map<String, int>>{};
    final raw = await _db
        .from('erp_arac_katalog_parcalar')
        .select('arac_id,kategori_kodu,oem_kodu,nitelik')
        .inFilter('arac_id', aracIds);
    final toplamKodlar = <int, Set<String>>{};
    final tamamKodlar = <int, Set<String>>{};
    for (final item in (raw as List)) {
      final row = Map<String, dynamic>.from(item as Map);
      final aracId = int.tryParse('${row['arac_id']}') ?? 0;
      if (aracId <= 0) continue;
      var kod = _cell(row['kategori_kodu']).toUpperCase();
      if (kod.endsWith('_SAG')) kod = kod.substring(0, kod.length - 4);
      if (kod.endsWith('_SOL')) kod = kod.substring(0, kod.length - 4);
      if (kod.isEmpty) continue;
      toplamKodlar.putIfAbsent(aracId, () => <String>{}).add(kod);
      if (_cell(row['oem_kodu']).isNotEmpty) {
        tamamKodlar.putIfAbsent(aracId, () => <String>{}).add(kod);
      }
    }
    final sonuc = <int, Map<String, int>>{};
    for (final id in aracIds) {
      sonuc[id] = <String, int>{
        'tamam': tamamKodlar[id]?.length ?? 0,
        'toplam': toplamKodlar[id]?.length ?? 0,
      };
    }
    return sonuc;
  }

  static Future<void> parcaGuncelle({
    required int parcaId,
    required String ustKategori,
    required String parcaAdi,
    required String oemKodu,
    String mevcutKategoriKodu = '',
  }) async {
    final ad = parcaAdi.trim();
    if (ad.isEmpty) throw Exception('Parça adı boş bırakılamaz.');
    final ust = ustKategori.trim().isEmpty ? 'Diğer' : ustKategori.trim();
    final temizOem = oemKodu.trim().toUpperCase();

    // Kategori/parça türü araçtan bağımsızdır. Aynı kategori koduna bağlı
    // bütün araçlarda ad ve üst kategori birlikte güncellenir. Kategori kodu
    // sabit tutulur; böylece mevcut OEM ilişkileri ve benzersiz kayıtlar bozulmaz.
    var eskiKod = mevcutKategoriKodu.trim();
    if (eskiKod.isEmpty) {
      final mevcutRaw = await _db
          .from('erp_arac_katalog_parcalar')
          .select('kategori_kodu')
          .eq('parca_id', parcaId)
          .limit(1);
      final mevcut = mevcutRaw as List;
      if (mevcut.isNotEmpty) {
        eskiKod = '${(mevcut.first as Map)['kategori_kodu'] ?? ''}'.trim();
      }
    }

    if (eskiKod.isNotEmpty) {
      final varyantlar = _kategoriKodVaryantlari(eskiKod);
      for (final kod in varyantlar) {
        await _db
            .from('erp_arac_katalog_parcalar')
            .update(<String, dynamic>{
              'kategori_adi': ad,
              'nitelik': 'UST_KATEGORI:$ust',
            })
            .eq('kategori_kodu', kod);
        try {
          await _db
              .from('erp_arac_katalog_sablon')
              .update(<String, dynamic>{
                'kategori_adi': ad,
                'nitelik': 'UST_KATEGORI:$ust',
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('kategori_kodu', kod);
        } catch (_) {}
      }
    }

    // OEM numarası araç/parça kaydına özeldir; yalnız seçili satır değişir.
    await _db
        .from('erp_arac_katalog_parcalar')
        .update(<String, dynamic>{
          'kategori_adi': ad,
          'oem_kodu': temizOem.isEmpty ? null : temizOem,
          'ham_deger': temizOem.isEmpty ? null : temizOem,
          'nitelik': 'UST_KATEGORI:$ust',
        })
        .eq('parca_id', parcaId);
  }

  static Future<AracKatalogImportSonuc> iceAktar(
    Uint8List bytes,
    String dosyaAdi,
  ) async {
    final rows = dosyaAdi.toLowerCase().endsWith('.csv')
        ? _csv(bytes)
        : _xlsx(bytes);
    if (rows.length < 2)
      throw Exception('Dosyada başlık ve veri satırı bulunamadı.');
    final headers = rows.first.map((e) => _norm(_cell(e))).toList();
    final idx = <String, int>{};
    for (var i = 0; i < headers.length; i++) {
      if (headers[i].isNotEmpty) idx[headers[i]] = i;
    }

    String getVal(List<dynamic> row, String key) {
      final i = idx[key];
      if (i == null || i >= row.length) return '';
      return _cell(row[i]);
    }

    int aracSayisi = 0, parcaSayisi = 0, atlanan = 0;
    for (var ri = 1; ri < rows.length; ri++) {
      final row = rows[ri];
      final rec = <String, String>{
        'YILLAR': getVal(row, 'YILLAR'),
        'URETICI': getVal(row, 'URETICI'),
        'YIL': getVal(row, 'YIL'),
        'MODEL': getVal(row, 'MODEL'),
        'MOTOR': getVal(row, 'MOTOR'),
        'YAKIT': getVal(row, 'YAKIT'),
        'MOTOR_KODU': getVal(row, 'MOTOR_KODU'),
        'SASE': getVal(row, 'SASE'),
        'NOT': getVal(row, 'NOT'),
        'ARAC_SAHIBI': getVal(row, 'ARAC_SAHIBI'),
      };
      if ((rec['URETICI'] ?? '').isEmpty || (rec['MODEL'] ?? '').isEmpty) {
        atlanan++;
        continue;
      }
      final key = _anahtar(rec);
      final yil = int.tryParse(rec['YIL'] ?? '');
      final up = await _db
          .from('erp_arac_katalog_araclar')
          .upsert(<String, dynamic>{
            'katalog_anahtar': key,
            'yillar': rec['YILLAR'],
            'uretici': rec['URETICI'],
            'yil': yil,
            'model': rec['MODEL'],
            'motor': rec['MOTOR'],
            'yakit': rec['YAKIT'],
            'motor_kodu': rec['MOTOR_KODU'],
            'sase': rec['SASE'],
            'notlar': rec['NOT'],
            'arac_sahibi': rec['ARAC_SAHIBI'],
            'updated_at': DateTime.now().toIso8601String(),
          }, onConflict: 'katalog_anahtar')
          .select('arac_id')
          .single();
      final aracId = up['arac_id'];
      await _db
          .from('erp_arac_katalog_parcalar')
          .delete()
          .eq('arac_id', aracId);
      final inserts = <Map<String, dynamic>>[];
      var sira = 0;
      for (final entry in _kategoriAdlari.entries) {
        final raw = getVal(row, entry.key);
        final kodlar = _kodlariAyir(raw);
        final rlTemel = _rlKategoriAdlari[entry.key];

        if (rlTemel != null) {
          // Excel başlığı R/L ise ilk kod Sağ, ikinci kod Sol kabul edilir.
          // Kod yoksa iki taraf da boş oluşturulur; kullanıcı daha sonra ERP'den girebilir.
          final sagOem = kodlar.isNotEmpty ? kodlar[0] : null;
          final solOem = kodlar.length > 1 ? kodlar[1] : null;
          inserts.add(<String, dynamic>{
            'arac_id': aracId,
            'kategori_kodu': _sagKod(entry.key),
            'kategori_adi': '$rlTemel Sağ',
            'oem_kodu': sagOem,
            'ham_deger': sagOem,
            'nitelik': sagOem == null && raw.isNotEmpty ? raw : null,
            'sira': sira++,
          });
          inserts.add(<String, dynamic>{
            'arac_id': aracId,
            'kategori_kodu': _solKod(entry.key),
            'kategori_adi': '$rlTemel Sol',
            'oem_kodu': solOem,
            'ham_deger': solOem,
            'nitelik': solOem == null && raw.isNotEmpty ? raw : null,
            'sira': sira++,
          });
          continue;
        }

        if (kodlar.isEmpty) {
          inserts.add(<String, dynamic>{
            'arac_id': aracId,
            'kategori_kodu': entry.key,
            'kategori_adi': entry.value,
            'oem_kodu': null,
            'ham_deger': raw.isEmpty ? null : raw,
            'nitelik': raw.isEmpty ? null : raw,
            'sira': sira++,
          });
        } else {
          for (final kod in kodlar) {
            inserts.add(<String, dynamic>{
              'arac_id': aracId,
              'kategori_kodu': entry.key,
              'kategori_adi': entry.value,
              'oem_kodu': kod,
              'ham_deger': raw,
              'nitelik': null,
              'sira': sira++,
            });
          }
        }
      }
      if (inserts.isNotEmpty) {
        await _db.from('erp_arac_katalog_parcalar').insert(inserts);
        parcaSayisi += inserts.length;
      }
      // İçe aktarılan araçta ortak şablon eksiklerini DB tarafında tek işlemle tamamla.
      await _db.rpc(
        'erp_arac_katalog_arac_sablon_tamamla',
        params: <String, dynamic>{'p_arac_id': int.parse('$aracId')},
      );
      aracSayisi++;
    }
    return AracKatalogImportSonuc(
      aracSayisi: aracSayisi,
      parcaSayisi: parcaSayisi,
      atlananSatir: atlanan,
    );
  }

  static int? _arananYil(String q) {
    final eslesmeler = RegExp(r'\b(19\d{2}|20\d{2}|21\d{2})\b').allMatches(q);
    if (eslesmeler.isEmpty) return null;
    return int.tryParse(eslesmeler.first.group(1) ?? '');
  }

  static bool _yilAraliginda(Map<String, dynamic> arac, int arananYil) {
    final yil = int.tryParse('${arac['yil'] ?? ''}');
    final ham = _cell(arac['yillar']).replaceAll('–', '-').replaceAll('—', '-');
    if (ham.isEmpty) return yil == null || yil == arananYil;

    final range = RegExp(
      r'(19\d{2}|20\d{2}|21\d{2})\s*-\s*(19\d{2}|20\d{2}|21\d{2})?',
    ).firstMatch(ham);
    if (range != null) {
      final bas = int.tryParse(range.group(1) ?? '');
      final bit = int.tryParse(range.group(2) ?? '');
      if (bas != null && arananYil < bas) return false;
      if (bit != null && arananYil > bit) return false;
      return true;
    }

    final tek = RegExp(r'(19\d{2}|20\d{2}|21\d{2})').firstMatch(ham);
    if (tek != null) {
      final y = int.tryParse(tek.group(1) ?? '');
      return y == null || y == arananYil;
    }
    return yil == null || yil == arananYil;
  }

  static List<String> _aramaKelimeleri(String q, int? yil) {
    var kalan = q.toUpperCase();
    if (yil != null) kalan = kalan.replaceAll('$yil', ' ');

    final sonuc = <String>[];
    // 1.3, 1,3, 2.0 gibi motor hacimlerini tek arama terimi olarak koru.
    for (final m in RegExp(r'\b\d+[\.,]\d+\b').allMatches(kalan)) {
      final v = _norm(m.group(0) ?? '');
      if (v.isNotEmpty && !sonuc.contains(v)) sonuc.add(v);
    }
    kalan = kalan.replaceAll(RegExp(r'\b\d+[\.,]\d+\b'), ' ');
    sonuc.addAll(
      _norm(kalan).split('_').where((e) => e.isNotEmpty && !sonuc.contains(e)),
    );
    return sonuc;
  }

  static int _aramaPuani(
    Map<String, dynamic> x,
    List<String> kelimeler,
    int? yil,
  ) {
    final sase = _norm(_cell(x['sase']));
    final motorKodu = _norm(_cell(x['motor_kodu']));
    final model = _norm(_cell(x['model']));
    final uretici = _norm(_cell(x['uretici']));
    final motor = _norm(_cell(x['motor']));
    final yakit = _norm(_cell(x['yakit']));
    int puan = 0;
    for (final k in kelimeler) {
      if (sase == k) puan += 1000;
      if (motorKodu == k) puan += 700;
      if (model == k) puan += 500;
      if (uretici == k) puan += 350;
      if (motor == k) puan += 250;
      if (yakit == k) puan += 200;
      if (model.contains(k)) puan += 120;
      if (motorKodu.contains(k)) puan += 100;
    }
    if (yil != null && _yilAraliginda(x, yil)) puan += 400;
    return puan;
  }

  static List<Map<String, dynamic>>? _aracAramaCache;
  static DateTime? _aracAramaCacheZamani;

  static void _aracAramaCacheTemizle() {
    _aracAramaCache = null;
    _aracAramaCacheZamani = null;
  }

  static Future<List<Map<String, dynamic>>> _tumAraclariAramaIcinGetir() async {
    final simdi = DateTime.now();
    if (_aracAramaCache != null &&
        _aracAramaCacheZamani != null &&
        simdi.difference(_aracAramaCacheZamani!).inMinutes < 10) {
      return _aracAramaCache!;
    }

    final res = await _db
        .from('erp_arac_katalog_araclar')
        .select()
        .order('uretici')
        .order('model')
        .order('yil')
        .limit(5000);
    _aracAramaCache = List<Map<String, dynamic>>.from(res as List);
    _aracAramaCacheZamani = simdi;
    return _aracAramaCache!;
  }

  static Future<List<Map<String, dynamic>>> aracAra(String q) async {
    final temizQ = q.trim();

    // Katalog ilk açıldığında 5000 aracı çekip taramak yerine yalnız ekranda
    // gösterilecek ilk 500 kayıt gelir. Bu açılışı belirgin şekilde hızlandırır.
    if (temizQ.isEmpty) {
      final res = await _db
          .from('erp_arac_katalog_araclar')
          .select()
          .order('uretici')
          .order('model')
          .order('yil')
          .limit(60);
      return List<Map<String, dynamic>>.from(res as List);
    }

    // Google tarzı yıl aralığı/kısmi eşleşme korunur. İlk dolu aramada bir kere
    // araç listesi belleğe alınır; sonraki aramalar Supabase'e tekrar gitmez.
    final all = await _tumAraclariAramaIcinGetir();
    final arananYil = _arananYil(temizQ);
    final kelimeler = _aramaKelimeleri(temizQ, arananYil);

    final bulunan = all.where((x) {
      if (arananYil != null && !_yilAraliginda(x, arananYil)) return false;
      final hay = _norm(
        <dynamic>[
          x['uretici'],
          x['model'],
          x['motor'],
          x['yakit'],
          x['motor_kodu'],
          x['sase'],
          x['notlar'],
          x['arac_sahibi'],
        ].join(' '),
      );
      return kelimeler.every((k) => hay.contains(k));
    }).toList();

    bulunan.sort((a, b) {
      final pb = _aramaPuani(b, kelimeler, arananYil);
      final pa = _aramaPuani(a, kelimeler, arananYil);
      if (pb != pa) return pb.compareTo(pa);
      final ua = '${a['uretici'] ?? ''} ${a['model'] ?? ''}';
      final ub = '${b['uretici'] ?? ''} ${b['model'] ?? ''}';
      return ua.compareTo(ub);
    });
    return bulunan.take(60).toList();
  }

  static Future<Map<int, int>> aracOemSayilariGetir(
    List<int> aracIdleri,
  ) async {
    if (aracIdleri.isEmpty) return <int, int>{};
    final sonuc = <int, int>{};
    // Tek dev sorgu yerine 100'lük parçalar: URL/filtre limiti ve büyük kataloglarda
    // gecikme kontrol altında kalır.
    for (var i = 0; i < aracIdleri.length; i += 100) {
      final son = (i + 100 < aracIdleri.length) ? i + 100 : aracIdleri.length;
      final ids = aracIdleri.sublist(i, son);
      final res = await _db
          .from('erp_arac_katalog_parcalar')
          .select('arac_id,oem_kodu')
          .inFilter('arac_id', ids);
      for (final raw in (res as List)) {
        final row = Map<String, dynamic>.from(raw as Map);
        final id = int.tryParse('${row['arac_id'] ?? ''}') ?? 0;
        final oem = _cell(row['oem_kodu']);
        if (id > 0 && oem.isNotEmpty) {
          sonuc[id] = (sonuc[id] ?? 0) + 1;
        }
      }
    }
    return sonuc;
  }

  static Future<List<Map<String, dynamic>>> parcalariGetir(int aracId) async {
    var res = await _db
        .from('erp_arac_katalog_parcalar')
        .select()
        .eq('arac_id', aracId)
        .order('sira');
    var liste = List<Map<String, dynamic>>.from(res as List);

    // 2.5.4 hızlı yol: Yeni şablonlu araçlarda eski R/L kalıntısı yoksa ve
    // standart kalemler tamamsa hiçbir ek sorgu / UPDATE / INSERT yapmadan dön.
    // Böylece araç seçimi ve yeni araç sonrası detay açılışı anlık hale gelir.
    final hizliMevcutKodlar = liste
        .map((e) => _cell(e['kategori_kodu']))
        .toSet();
    final legacyRlVar = hizliMevcutKodlar.any(_rlKategoriAdlari.containsKey);
    final standartEksikVar = _istenenKategoriAdlari().keys.any(
      (k) => !hizliMevcutKodlar.contains(k),
    );
    if (!legacyRlVar && !standartEksikVar) {
      return liste.where((e) => !_aractanSilinmis(e)).toList();
    }

    // Eski R/L kayıtlarını bir kereye mahsus gerçek Sağ / Sol kayıtlarına dönüştür.
    // Eski yapıda iki OEM aynı kategori altında iki satır olarak bulunuyordu.
    // Sıralama R/L başlığına göre: ilk satır Sağ, ikinci satır Sol.
    for (final rl in _rlKategoriAdlari.entries) {
      final sagKod = _sagKod(rl.key);
      final solKod = _solKod(rl.key);
      final sagVar = liste.any((e) => _cell(e['kategori_kodu']) == sagKod);
      final solVar = liste.any((e) => _cell(e['kategori_kodu']) == solKod);
      final eskiler =
          liste.where((e) => _cell(e['kategori_kodu']) == rl.key).toList()
            ..sort(
              (a, b) => (int.tryParse('${a['sira'] ?? 0}') ?? 0).compareTo(
                int.tryParse('${b['sira'] ?? 0}') ?? 0,
              ),
            );

      if (!sagVar && eskiler.isNotEmpty) {
        await _db
            .from('erp_arac_katalog_parcalar')
            .update(<String, dynamic>{
              'kategori_kodu': sagKod,
              'kategori_adi': '${rl.value} Sağ',
            })
            .eq('parca_id', eskiler.first['parca_id']);
      }
      if (!solVar && eskiler.length > 1) {
        await _db
            .from('erp_arac_katalog_parcalar')
            .update(<String, dynamic>{
              'kategori_kodu': solKod,
              'kategori_adi': '${rl.value} Sol',
            })
            .eq('parca_id', eskiler[1]['parca_id']);
      }

      // Tek eski kayıt varsa (özellikle OEM boşsa) eksik tarafı boş olarak oluştur.
      if (!solVar && eskiler.length <= 1) {
        final mevcutSol = await _db
            .from('erp_arac_katalog_parcalar')
            .select('parca_id')
            .eq('arac_id', aracId)
            .eq('kategori_kodu', solKod)
            .limit(1);
        if ((mevcutSol as List).isEmpty) {
          final maxSira = liste.isEmpty
              ? 0
              : liste
                    .map((e) => int.tryParse('${e['sira'] ?? 0}') ?? 0)
                    .reduce((a, b) => a > b ? a : b);
          await _db.from('erp_arac_katalog_parcalar').insert(<String, dynamic>{
            'arac_id': aracId,
            'kategori_kodu': solKod,
            'kategori_adi': '${rl.value} Sol',
            'oem_kodu': null,
            'ham_deger': null,
            'nitelik': null,
            'sira': maxSira + 1,
          });
        }
      }
    }

    // R/L dönüşümünden sonra listeyi tazele.
    res = await _db
        .from('erp_arac_katalog_parcalar')
        .select()
        .eq('arac_id', aracId)
        .order('sira');
    liste = List<Map<String, dynamic>>.from(res as List);

    // Eski kataloglarda tamamen boş olan sütunlar veritabanına yazılmamış olabilir.
    // Kullanıcının daha sonra OEM girebilmesi için eksik parça alanlarını otomatik oluştur.
    final istenenler = _istenenKategoriAdlari();
    final mevcut = liste.map((e) => _cell(e['kategori_kodu'])).toSet();
    final eksikler = <Map<String, dynamic>>[];
    var sira = liste.isEmpty
        ? 0
        : (liste
                  .map((e) => int.tryParse('${e['sira'] ?? 0}') ?? 0)
                  .reduce((a, b) => a > b ? a : b) +
              1);
    for (final entry in istenenler.entries) {
      if (mevcut.contains(entry.key)) continue;
      eksikler.add(<String, dynamic>{
        'arac_id': aracId,
        'kategori_kodu': entry.key,
        'kategori_adi': entry.value,
        'oem_kodu': null,
        'ham_deger': null,
        'nitelik': null,
        'sira': sira++,
      });
    }
    if (eksikler.isNotEmpty) {
      await _db.from('erp_arac_katalog_parcalar').insert(eksikler);
      res = await _db
          .from('erp_arac_katalog_parcalar')
          .select()
          .eq('arac_id', aracId)
          .order('sira');
      liste = List<Map<String, dynamic>>.from(res as List);
    }

    // Herhangi bir eski R/L artığı kaldıysa ekranda göstermeyelim.
    return liste
        .where((e) => !_rlKategoriAdlari.containsKey(_cell(e['kategori_kodu'])))
        .where((e) => !_aractanSilinmis(e))
        .toList();
  }

  // 2.5.6: Katalog parçasını yalnız seçili araçtan kaldırır.
  static Future<void> parcaAractanSil({
    required int aracId,
    required String kategoriKodu,
  }) async {
    final kod = kategoriKodu.trim();
    if (kod.isEmpty) throw Exception('Parça kategori kodu bulunamadı.');

    final raw = await _db
        .from('erp_arac_katalog_parcalar')
        .select('parca_id,sira')
        .eq('arac_id', aracId)
        .eq('kategori_kodu', kod)
        .order('sira');

    final rows = List<Map<String, dynamic>>.from(raw as List);
    if (rows.isEmpty) return;

    // Silinen standart parça yeniden otomatik oluşturulmasın diye tek bir
    // görünmez tombstone satırı bırakıyoruz. Böylece kategori "mevcut" sayılır
    // fakat parcalariGetir() bunu kullanıcıya hiçbir zaman göstermez.
    final ilkId = rows.first['parca_id'];
    await _db
        .from('erp_arac_katalog_parcalar')
        .update(<String, dynamic>{
          'oem_kodu': null,
          'ham_deger': null,
          'nitelik': 'SILINDI',
        })
        .eq('parca_id', ilkId);

    if (rows.length > 1) {
      final digerIdler = rows
          .skip(1)
          .map((e) => e['parca_id'])
          .where((e) => e != null)
          .toList();
      if (digerIdler.isNotEmpty) {
        await _db
            .from('erp_arac_katalog_parcalar')
            .delete()
            .inFilter('parca_id', digerIdler);
      }
    }
  }

  // 2.5.6: Yalnız kullanıcının sonradan açtığı OZEL_ parçalar global silinebilir.
  // DB tarafındaki RPC hem ana şablonu hem bütün araç eşleşmelerini tek işlemde siler.
  static Future<int> parcaGlobalSil({required String kategoriKodu}) async {
    final kod = kategoriKodu.trim();
    if (!kod.startsWith('OZEL_')) {
      throw Exception('Standart katalog parçaları tüm katalogdan silinemez.');
    }
    final sonuc = await _db.rpc(
      'erp_arac_katalog_global_parca_sil',
      params: <String, dynamic>{'p_kategori_kodu': kod},
    );
    return int.tryParse('$sonuc') ?? 0;
  }

  static Future<void> parcaOemGuncelle({
    required int parcaId,
    required String oemKodu,
  }) async {
    final temiz = oemKodu.trim();
    await _db
        .from('erp_arac_katalog_parcalar')
        .update(<String, dynamic>{
          'oem_kodu': temiz.isEmpty ? null : temiz,
          'ham_deger': temiz.isEmpty ? null : temiz,
        })
        .eq('parca_id', parcaId);
  }

  // 2.5.5: Aynı araç + parça türü altında birden fazla OEM tutulabilir.
  // Her OEM ayrı satırdır; stok araması yalnız tıklanan OEM için yapılır.
  static Future<void> parcaOemEkle({
    required int aracId,
    required String kategoriKodu,
    required String kategoriAdi,
    required String oemKodu,
    String nitelik = '',
    int sira = 0,
  }) async {
    final temiz = oemKodu.trim().toUpperCase();
    if (temiz.isEmpty) throw Exception('OEM numarası boş bırakılamaz.');

    final mevcut = await _db
        .from('erp_arac_katalog_parcalar')
        .select('parca_id,oem_kodu')
        .eq('arac_id', aracId)
        .eq('kategori_kodu', kategoriKodu);
    final hedef = temiz.replaceAll(RegExp(r'[^A-Z0-9]'), '');
    for (final raw in (mevcut as List)) {
      final row = raw as Map;
      final kod = '${row['oem_kodu'] ?? ''}'.toUpperCase().replaceAll(
        RegExp(r'[^A-Z0-9]'),
        '',
      );
      if (kod.isNotEmpty && kod == hedef) {
        throw Exception('Bu OEM bu parçada zaten kayıtlı.');
      }
    }

    // Parçanın OEM'siz şablon satırı varsa onu doldurmak daha az satır üretir.
    final boslar = (mevcut as List)
        .where((raw) => '${(raw as Map)['oem_kodu'] ?? ''}'.trim().isEmpty)
        .toList();
    if (boslar.isNotEmpty) {
      await _db
          .from('erp_arac_katalog_parcalar')
          .update(<String, dynamic>{
            'oem_kodu': temiz,
            'ham_deger': temiz,
            'nitelik': nitelik.isEmpty ? null : nitelik,
          })
          .eq('parca_id', (boslar.first as Map)['parca_id']);
      return;
    }

    await _db.from('erp_arac_katalog_parcalar').insert(<String, dynamic>{
      'arac_id': aracId,
      'kategori_kodu': kategoriKodu,
      'kategori_adi': kategoriAdi,
      'oem_kodu': temiz,
      'ham_deger': temiz,
      'nitelik': nitelik.isEmpty ? null : nitelik,
      'sira': sira,
    });
  }

  static Future<void> parcaOemSil({required int parcaId}) async {
    final raw = await _db
        .from('erp_arac_katalog_parcalar')
        .select('arac_id,kategori_kodu')
        .eq('parca_id', parcaId)
        .single();
    final row = Map<String, dynamic>.from(raw);
    final aracId = int.parse('${row['arac_id']}');
    final kategoriKodu = '${row['kategori_kodu'] ?? ''}';
    final ayni = await _db
        .from('erp_arac_katalog_parcalar')
        .select('parca_id')
        .eq('arac_id', aracId)
        .eq('kategori_kodu', kategoriKodu);

    // Son OEM siliniyorsa parça kalemi kaybolmasın; OEM'siz şablon satırına dönsün.
    if ((ayni as List).length <= 1) {
      await _db
          .from('erp_arac_katalog_parcalar')
          .update(<String, dynamic>{'oem_kodu': null, 'ham_deger': null})
          .eq('parca_id', parcaId);
    } else {
      await _db
          .from('erp_arac_katalog_parcalar')
          .delete()
          .eq('parca_id', parcaId);
    }
  }
}
