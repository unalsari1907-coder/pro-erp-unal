class SayfaliVeriService {
  SayfaliVeriService._();

  static Future<List<Map<String, dynamic>>> tumunuGetir(
    Future<dynamic> Function(int baslangic, int bitis) sayfaGetir, {
    int sayfaBoyutu = 500,
  }) async {
    final tumKayitlar = <Map<String, dynamic>>[];
    var baslangic = 0;

    while (true) {
      final response = await sayfaGetir(
        baslangic,
        baslangic + sayfaBoyutu - 1,
      );
      final sayfa = List<Map<String, dynamic>>.from(response as List);
      tumKayitlar.addAll(sayfa);
      if (sayfa.length < sayfaBoyutu) break;
      baslangic += sayfaBoyutu;
    }

    return tumKayitlar;
  }
}
