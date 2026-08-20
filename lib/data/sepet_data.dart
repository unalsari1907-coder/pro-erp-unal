import '../models/stok_model.dart';

class SepetItem {
  final StokModel stok;

  int adet;
  double birimFiyat;
  double iskonto;

  SepetItem({
    required this.stok,
    this.adet = 1,
    double? birimFiyat,
    this.iskonto = 0,
  }) : birimFiyat = birimFiyat ?? stok.satisFiyati;

  double get araToplam => adet * birimFiyat;

  double get toplam => araToplam - iskonto;
}

class SepetData {
  static final List<SepetItem> sepet = [];

  static List<SepetItem> get items => sepet;

  static void urunEkle(StokModel urun) {
    final index =
        sepet.indexWhere((e) => e.stok.stokId == urun.stokId);

    if (index >= 0) {
      sepet[index].adet++;
    } else {
      sepet.add(
        SepetItem(
          stok: urun,
          adet: 1,
          birimFiyat: urun.satisFiyati,
        ),
      );
    }
  }

  static void adetArttir(SepetItem item) {
    item.adet++;
  }

  static void adetAzalt(SepetItem item) {
    if (item.adet > 1) {
      item.adet--;
    } else {
      sepet.remove(item);
    }
  }

  static void fiyatDegistir(
    SepetItem item,
    double yeniFiyat,
  ) {
    item.birimFiyat = yeniFiyat;
  }

  static void iskontoDegistir(
    SepetItem item,
    double yeniIskonto,
  ) {
    item.iskonto = yeniIskonto;
  }

  static void urunSil(SepetItem item) {
    sepet.remove(item);
  }

  static void temizle() {
    sepet.clear();
  }
    static double get araToplam {
    double toplam = 0;

    for (final item in sepet) {
      toplam += item.araToplam;
    }

    return toplam;
  }

  static double get toplamIskonto {
    double toplam = 0;

    for (final item in sepet) {
      toplam += item.iskonto;
    }

    return toplam;
  }

  static double get genelToplam {
    double toplam = 0;

    for (final item in sepet) {
      toplam += item.toplam;
    }

    return toplam;
  }

  static int get toplamKalem => sepet.length;

  static int get toplamAdet {
    int adet = 0;

    for (final item in sepet) {
      adet += item.adet;
    }

    return adet;
  }

  static bool get bosMu => sepet.isEmpty;
}