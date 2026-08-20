# PRO-ERP 2.5.11 Mobil Derleme Düzeltmesi

Kullanıcının gerçek `flutter analyze` çıktısında derlemeyi durduran dört hata `test/widget_test.dart` içindeydi:

- Eski `config_app.dart` importu güncel `app_config.dart` ile değiştirildi.
- Testteki eski 2.3.0 sürüm beklentisi 2.5.11'e güncellendi.
- Kaldırılmış `KurumsalModuller.aracUyumluluk` testi kaldırıldı ve mevcut `seriLot` modülü ile değiştirildi.
- Release scriptinde warning/info seviyesindeki mevcut teknik borç derlemeyi durdurmayacak şekilde `--no-fatal-warnings --no-fatal-infos` eklendi. Gerçek analyzer hataları yine build'i durdurur.

`file_picker` platform uyarıları ve deprecated API bildirimleri release build engelleyici değildir; bunlar ayrı teknik borç olarak tutulmuştur.
