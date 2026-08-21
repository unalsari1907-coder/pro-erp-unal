class ErpSekmeService {
  static void Function(String sayfaId)? _acici;

  static void bagla(void Function(String sayfaId) acici) {
    _acici = acici;
  }

  static void baglantiyiKaldir(void Function(String sayfaId) acici) {
    if (identical(_acici, acici)) {
      _acici = null;
    }
  }

  static bool get hazir => _acici != null;

  static void ac(String sayfaId) {
    _acici?.call(sayfaId);
  }
}
