import 'package:flutter/widgets.dart';

typedef CalismaSekmesiAcici = bool Function(
  String id,
  String baslik,
  Widget sayfa,
);

/// Liste ekranlarının, Navigator ile ekranın üstüne çıkmak yerine Dashboard
/// içindeki çalışma sekmelerinde form açabilmesini sağlar. Aynı kimlik yeniden
/// istendiğinde mevcut Widget korunur; böylece kaydedilmemiş form kapanmaz.
class CalismaSekmesiService {
  CalismaSekmesiService._();

  static CalismaSekmesiAcici? _acici;

  static void bagla(CalismaSekmesiAcici acici) {
    _acici = acici;
  }

  static void ayir() {
    _acici = null;
  }

  static bool ac(String id, String baslik, Widget sayfa) {
    return _acici?.call(id, baslik, sayfa) ?? false;
  }
}
