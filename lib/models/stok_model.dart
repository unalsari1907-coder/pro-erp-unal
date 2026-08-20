// lib/models/stok_model.dart

class StokModel {
  final int stokId;

  final String urunAdi;
  final String marka;
  final String model;
  final String ureticiKodu;
  final String barkod;
  final String raf;

  final double stokMiktari;
  final double minimumStok;

  final double alisFiyati;
  final double satisFiyatiPerakende;
  final double satisFiyatiToptan;
  final double satisFiyatiIndirimli;
  final double satisFiyatiListe;
  final double kdv;

  final String urunOzellik;
  final String aciklama;

  final bool aktif;

  /// Alt tablolardan gelen çoklu alanlar
  final List<String> oemler;
  final List<String> crossKodlar;
  final List<String> rakipKodlar;
  final List<String> araclar;
  final List<String> resimler;

  const StokModel({
    required this.stokId,
    required this.urunAdi,
    required this.marka,
    required this.model,
    required this.ureticiKodu,
    required this.barkod,
    required this.raf,
    required this.stokMiktari,
    required this.minimumStok,
    required this.alisFiyati,
    required this.satisFiyatiPerakende,
    required this.satisFiyatiToptan,
    required this.satisFiyatiIndirimli,
    required this.satisFiyatiListe,
    required this.kdv,
    required this.urunOzellik,
    required this.aciklama,
    required this.aktif,
    required this.oemler,
    required this.crossKodlar,
    required this.rakipKodlar,
    required this.araclar,
    required this.resimler,
  });

  // ------------------------------------------------------
  // ESKİ EKRANLARLA UYUMLULUK GETTER'LARI
  // ------------------------------------------------------

  int get id => stokId;

  String get stokKodu => ureticiKodu;

  String get stokAdi => urunAdi;

  String get oemNo => oemler.join(',');

  String get cross => crossKodlar.join(',');

  String get rakipKod => rakipKodlar.join(',');

  String get arac => araclar.join(',');

  String get resim => resimler.isNotEmpty ? resimler.first : '';

  /// Eski ekranlarda `satisFiyati` kullanılıyorsa perakende fiyatı döndürür.
  double get satisFiyati => satisFiyatiPerakende;

  // ------------------------------------------------------
  // YARDIMCI DÖNÜŞÜMLER
  // ------------------------------------------------------

  static double _doubleDeger(
    dynamic deger, {
    double varsayilan = 0.0,
  }) {
    if (deger == null) {
      return varsayilan;
    }

    if (deger is num) {
      return deger.toDouble();
    }

    final metin = deger
        .toString()
        .trim()
        .replaceAll('₺', '')
        .replaceAll(' ', '')
        .replaceAll(',', '.');

    return double.tryParse(metin) ?? varsayilan;
  }

  static int _intDeger(
    dynamic deger, {
    int varsayilan = 0,
  }) {
    if (deger == null) {
      return varsayilan;
    }

    if (deger is int) {
      return deger;
    }

    if (deger is num) {
      return deger.toInt();
    }

    return int.tryParse(deger.toString().trim()) ?? varsayilan;
  }

  static bool _boolDeger(
    dynamic deger, {
    bool varsayilan = true,
  }) {
    if (deger == null) {
      return varsayilan;
    }

    if (deger is bool) {
      return deger;
    }

    if (deger is num) {
      return deger != 0;
    }

    final metin = deger.toString().trim().toLowerCase();

    if ([
      'false',
      '0',
      'hayir',
      'hayır',
      'pasif',
      'kapali',
      'kapalı',
    ].contains(metin)) {
      return false;
    }

    if ([
      'true',
      '1',
      'evet',
      'aktif',
      'acik',
      'açık',
    ].contains(metin)) {
      return true;
    }

    return varsayilan;
  }

  static List<String> _listeDeger(dynamic deger) {
    if (deger == null) {
      return const [];
    }

    if (deger is List) {
      return deger
          .map((item) {
            if (item is Map) {
              return (
                item['kod'] ??
                item['deger'] ??
                item['oem_no'] ??
                item['cross_kod'] ??
                item['rakip_kod'] ??
                item['arac'] ??
                item['resim_url'] ??
                item['url'] ??
                ''
              ).toString().trim();
            }

            return item.toString().trim();
          })
          .where((item) => item.isNotEmpty)
          .toList();
    }

    final metin = deger.toString().trim();

    if (metin.isEmpty) {
      return const [];
    }

    return metin
        .split(RegExp(r'[,;\n|]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  static String _metinDeger(dynamic deger) {
    return deger?.toString().trim() ?? '';
  }

  // ------------------------------------------------------
  // JSON / SUPABASE DÖNÜŞÜMÜ
  // ------------------------------------------------------

  factory StokModel.fromJson(Map<String, dynamic> json) {
    final perakendeFiyat = _doubleDeger(
      json['satis_fiyati_perakende'] ??
          json['satis_fiyati'] ??
          json['perakende_fiyat'],
    );

    final toptanFiyat = _doubleDeger(
      json['satis_fiyati_toptan'] ??
          json['toptan_fiyat'],
    );

    final indirimliFiyat = _doubleDeger(
      json['satis_fiyati_indirimli'] ??
          json['indirimli_fiyat'],
    );

    final listeFiyat = _doubleDeger(
      json['satis_fiyati_liste'] ??
          json['liste_fiyat'],
    );

    final oemler = _listeDeger(
      json['oemler'] ??
          json['oem_listesi'] ??
          json['oem_no'],
    );

    final crossKodlar = _listeDeger(
      json['cross_kodlar'] ??
          json['cross_listesi'] ??
          json['cross_kod'] ??
          json['cross'],
    );

    final rakipKodlar = _listeDeger(
      json['rakip_kodlar'] ??
          json['rakip_listesi'] ??
          json['rakip_kod'],
    );

    final araclar = _listeDeger(
      json['araclar'] ??
          json['arac_listesi'] ??
          json['arac'],
    );

    final resimler = _listeDeger(
      json['resimler'] ??
          json['resim_listesi'] ??
          json['resim'],
    );

    return StokModel(
      stokId: _intDeger(
        json['stok_id'] ?? json['id'],
      ),
      urunAdi: _metinDeger(
        json['urun_adi'] ?? json['stok_adi'],
      ),
      marka: _metinDeger(
        json['marka'],
      ),
      model: _metinDeger(
        json['model'],
      ),
      ureticiKodu: _metinDeger(
        json['uretici_kodu'] ?? json['stok_kodu'],
      ),
      barkod: _metinDeger(
        json['barkod'],
      ),
      raf: _metinDeger(
        json['raf'],
      ),
      stokMiktari: _doubleDeger(
        json['stok_miktari'] ?? json['miktar'],
      ),
      minimumStok: _doubleDeger(
        json['minimum_stok'] ??
            json['min_stok'],
      ),
      alisFiyati: _doubleDeger(
        json['alis_fiyati'] ??
            json['son_alis_fiyati'],
      ),
      satisFiyatiPerakende: perakendeFiyat,
      satisFiyatiToptan: toptanFiyat,
      satisFiyatiIndirimli: indirimliFiyat,
      satisFiyatiListe: listeFiyat,
      kdv: _doubleDeger(
        json['kdv'] ??
            json['kdv_orani'],
        varsayilan: 20.0,
      ),
      urunOzellik: _metinDeger(
        json['urun_ozellik'] ??
            json['urun_ozellikleri'],
      ),
      aciklama: _metinDeger(
        json['aciklama'],
      ),
      aktif: _boolDeger(
        json['aktif'],
      ),
      oemler: oemler,
      crossKodlar: crossKodlar,
      rakipKodlar: rakipKodlar,
      araclar: araclar,
      resimler: resimler,
    );
  }

  factory StokModel.fromMap(Map<String, dynamic> map) {
    return StokModel.fromJson(map);
  }

  // ------------------------------------------------------
  // COPY WITH
  // ------------------------------------------------------

  StokModel copyWith({
    int? stokId,
    String? urunAdi,
    String? marka,
    String? model,
    String? ureticiKodu,
    String? barkod,
    String? raf,
    double? stokMiktari,
    double? minimumStok,
    double? alisFiyati,
    double? satisFiyatiPerakende,
    double? satisFiyatiToptan,
    double? satisFiyatiIndirimli,
    double? satisFiyatiListe,
    double? kdv,
    String? urunOzellik,
    String? aciklama,
    bool? aktif,
    List<String>? oemler,
    List<String>? crossKodlar,
    List<String>? rakipKodlar,
    List<String>? araclar,
    List<String>? resimler,
  }) {
    return StokModel(
      stokId: stokId ?? this.stokId,
      urunAdi: urunAdi ?? this.urunAdi,
      marka: marka ?? this.marka,
      model: model ?? this.model,
      ureticiKodu: ureticiKodu ?? this.ureticiKodu,
      barkod: barkod ?? this.barkod,
      raf: raf ?? this.raf,
      stokMiktari: stokMiktari ?? this.stokMiktari,
      minimumStok: minimumStok ?? this.minimumStok,
      alisFiyati: alisFiyati ?? this.alisFiyati,
      satisFiyatiPerakende:
          satisFiyatiPerakende ?? this.satisFiyatiPerakende,
      satisFiyatiToptan:
          satisFiyatiToptan ?? this.satisFiyatiToptan,
      satisFiyatiIndirimli:
          satisFiyatiIndirimli ?? this.satisFiyatiIndirimli,
      satisFiyatiListe:
          satisFiyatiListe ?? this.satisFiyatiListe,
      kdv: kdv ?? this.kdv,
      urunOzellik: urunOzellik ?? this.urunOzellik,
      aciklama: aciklama ?? this.aciklama,
      aktif: aktif ?? this.aktif,
      oemler: oemler ?? this.oemler,
      crossKodlar: crossKodlar ?? this.crossKodlar,
      rakipKodlar: rakipKodlar ?? this.rakipKodlar,
      araclar: araclar ?? this.araclar,
      resimler: resimler ?? this.resimler,
    );
  }

  // ------------------------------------------------------
  // JSON'A DÖNÜŞÜM
  // ------------------------------------------------------

  Map<String, dynamic> toJson() {
    return {
      'stok_id': stokId,
      'urun_adi': urunAdi,
      'marka': marka,
      'model': model,
      'uretici_kodu': ureticiKodu,
      'barkod': barkod,
      'raf': raf,
      'stok_miktari': stokMiktari,
      'min_stok': minimumStok,
      'alis_fiyati': alisFiyati,
      'satis_fiyati_perakende': satisFiyatiPerakende,
      'satis_fiyati_toptan': satisFiyatiToptan,
      'satis_fiyati_indirimli': satisFiyatiIndirimli,
      'satis_fiyati_liste': satisFiyatiListe,
      'kdv': kdv,
      'urun_ozellik': urunOzellik,
      'aciklama': aciklama,
      'aktif': aktif,
      'oemler': oemler,
      'cross_kodlar': crossKodlar,
      'rakip_kodlar': rakipKodlar,
      'araclar': araclar,
      'resimler': resimler,
    };
  }

  @override
  String toString() {
    return 'StokModel('
        'stokId: $stokId, '
        'urunAdi: $urunAdi, '
        'stokMiktari: $stokMiktari, '
        'alisFiyati: $alisFiyati, '
        'satisFiyatiPerakende: $satisFiyatiPerakende, '
        'satisFiyatiToptan: $satisFiyatiToptan, '
        'satisFiyatiListe: $satisFiyatiListe'
        ')';
  }
}