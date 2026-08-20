import '../models/stok_model.dart';

class SatisTaslakService {
  SatisTaslakService._();

  static final List<StokModel> _stoklar = <StokModel>[];

  static List<StokModel> get stoklar => List<StokModel>.unmodifiable(_stoklar);

  static bool get bos => _stoklar.isEmpty;

  static void ekle(StokModel stok) => _stoklar.add(stok);

  static void temizle() => _stoklar.clear();
}
