class ErpHesaplamaService {
  ErpHesaplamaService._();

  static double kurFarki({
    required double dovizTutar,
    required double eskiKur,
    required double yeniKur,
  }) => dovizTutar * (yeniKur - eskiKur);

  static String vadeGrubu(int gecikmeGun) {
    if (gecikmeGun <= 0) return 'Vadesi Gelmemiş';
    if (gecikmeGun <= 30) return '1-30 Gün';
    if (gecikmeGun <= 60) return '31-60 Gün';
    if (gecikmeGun <= 90) return '61-90 Gün';
    return '90+ Gün';
  }

  static double karOraniFiyati(double maliyet, double karYuzde) {
    return maliyet * (1 + karYuzde / 100);
  }

  static double marjdanSatisFiyati(double maliyet, double hedefMarjYuzde) {
    if (hedefMarjYuzde >= 100) return double.infinity;
    return maliyet / (1 - hedefMarjYuzde / 100);
  }

  static double netFiyat(double fiyat, double iskontoYuzde) {
    return fiyat * (1 - iskontoYuzde / 100);
  }
}
