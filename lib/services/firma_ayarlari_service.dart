import 'supabase_service.dart';

class FirmaAyarlari {
  final String unvan;
  final String adres;
  final String il;
  final String ilce;
  final String telefon;
  final String eposta;
  final String vergiDairesi;
  final String vergiNo;
  final String iban;
  final String logoUrl;

  const FirmaAyarlari({
    this.unvan = 'ÜNAL YEDEK PARÇA',
    this.adres = '',
    this.il = '',
    this.ilce = '',
    this.telefon = '',
    this.eposta = '',
    this.vergiDairesi = '',
    this.vergiNo = '',
    this.iban = '',
    this.logoUrl = '',
  });

  factory FirmaAyarlari.fromMap(Map<String, dynamic>? map) {
    String metin(String alan) => map?[alan]?.toString().trim() ?? '';

    return FirmaAyarlari(
      unvan: metin('unvan').isEmpty ? 'ÜNAL YEDEK PARÇA' : metin('unvan'),
      adres: metin('adres'),
      il: metin('il'),
      ilce: metin('ilce'),
      telefon: metin('telefon'),
      eposta: metin('eposta'),
      vergiDairesi: metin('vergi_dairesi'),
      vergiNo: metin('vergi_no'),
      iban: metin('iban'),
      logoUrl: metin('logo_url'),
    );
  }

  Map<String, dynamic> toMap() => {
        'ayar_id': 1,
        'unvan': unvan.trim(),
        'adres': adres.trim(),
        'il': il.trim(),
        'ilce': ilce.trim(),
        'telefon': telefon.trim(),
        'eposta': eposta.trim(),
        'vergi_dairesi': vergiDairesi.trim(),
        'vergi_no': vergiNo.trim(),
        'iban': iban.trim(),
        'logo_url': logoUrl.trim(),
        'guncellendi': DateTime.now().toUtc().toIso8601String(),
      };
}

class FirmaAyarlariService {
  FirmaAyarlariService._();

  static FirmaAyarlari? _onbellek;

  static Future<FirmaAyarlari> getir({bool zorla = false}) async {
    if (!zorla && _onbellek != null) return _onbellek!;

    try {
      final response = await SupabaseService.supabase
          .from('erp_firma_ayarlari')
          .select()
          .eq('ayar_id', 1)
          .maybeSingle();
      _onbellek = FirmaAyarlari.fromMap(response);
    } catch (_) {
      _onbellek = const FirmaAyarlari();
    }

    return _onbellek!;
  }

  static Future<void> kaydet(FirmaAyarlari ayarlar) async {
    await SupabaseService.supabase
        .from('erp_firma_ayarlari')
        .upsert(ayarlar.toMap(), onConflict: 'ayar_id');
    _onbellek = ayarlar;
  }
}
