# PRO-ERP 2.5.9 — Telefon / Mobil Son Kontrol

Bu paket 2.5.8 kaynaklarının telefon kullanımı için statik ve yapılandırma denetiminden geçirilmiş sürümüdür.

## İncelenen kapsam

- 86 Dart dosyası
- 57 ekran dosyası
- 112 dialog çağrısı
- 13 DataTable kullanımı
- 13 ağ resmi kullanımı
- 4 dosya seçme / içe aktarma noktası
- Android, iOS ve Web/PWA yapılandırmaları
- Ana menü / çoklu sayfa yapısı
- Stok, satış, alış, cari, kasa/banka, raporlar, kurumsal ERP ve araç kataloğu ekranları
- PDF/yazdırma, Excel/CSV, resim seçme, Supabase erişimi ve mobil klavye davranışı

Projede mobil uyum için 200'den fazla MobilUyum/MobilDialogIcerik/MobilTablo/MobilYatayRow/MobilAppBarActions kullanımı bulunmaktadır. Büyük dialog ve tabloların telefon ekranında taşmaması için ek sabit-genişlik kontrolleri de yapıldı.

## 2.5.9'da yapılan telefon düzeltmeleri

1. Android release sürümüne INTERNET izni eklendi. Supabase bağlantısının APK/release ortamında çalışması güvenceye alındı.
2. Android uygulama adı `ÜNAL YEDEK PARÇA ERP` yapıldı.
3. iOS kamera ve fotoğraf arşivi izin açıklamaları eklendi. Stok resmi seçme/çekme sırasında izin hatası oluşmaması hedeflendi.
4. Web viewport `viewport-fit=cover` olarak düzeltildi. Çentikli / safe-area kullanan telefonlarda görünüm iyileştirildi; zorunlu zoom kilidi kaldırıldı.
5. Mobil ana menüde açık ağır ekran sayısı RAM tüketimini sınırlamak için Dashboard + son iki çalışma ekranı ile sınırlandı. Bir önceki ekran korunur, masaüstü sekme davranışı değişmez.
6. Araç kataloğunda telefon AppBar'ındaki uzun `Yeni Araç` ve `Excel/CSV İçe Aktar` metinleri ikon aksiyonlarına çevrildi; başlık sıkışması azaltıldı.
7. Araç detayındaki `Not / Ek Bilgi` 520 px sabit genişlikten çıkarıldı; telefonda ekran genişliğine uyumlu hale getirildi.
8. Araç katalog içe aktarımında 20 MB üstü dosyalar telefonda engellenir. Büyük Excel dosyasının mobil tarayıcı RAM'ini tüketip sekmeyi kapatması önlenir. Büyük aktarım bilgisayardan yapılmalıdır.
9. Stok kartı ana listesindeki masaüstü geniş kart yapısı telefonda güvenli yatay kaydırılabilir hale getirildi. Raf, depo stokları, fiyat şeridi ve işlem butonları kaybolmaz.
10. Operasyon Merkezi, Depolar, Vade Yaşlandırma, Belge Geçmişi ve Cari Seçim dialoglarındaki 720–950 px sabit genişlikler telefon ekranına göre sınırlandı.
11. Mobil klavye açıldığında içerik daralabilsin diye eski ana ekranın `resizeToAvoidBottomInset` davranışı düzeltildi.
12. `TELEFONDA_TEST_ET.bat` artık release modunda telefon testi yapar. Flutter Web debug modu telefonlarda belirgin biçimde yavaş olduğu için release testi esas alınmıştır.
13. `WEB_SURUMU_OLUSTUR.bat` Cloudflare / normal alan adı yayınına uygun hale getirildi. Eski GitHub Pages'e özel `/pro-erp-unal/` base-href kaldırıldı.
14. Build öncesine `flutter analyze` eklendi. Analiz hatası varsa web build/yayın otomatik durur.

## Yayın öncesi zorunlu kontrol

Windows'ta proje klasöründe `MOBIL_RELEASE_HAZIRLA.bat` çalıştırın. Bu dosya sırayla `flutter clean`, `flutter pub get`, `flutter analyze` ve `flutter build web --release` çalıştırır. Dört aşama hatasız tamamlanmadan canlı Cloudflare yayınına geçmeyin.

Bu çalışma ortamında Flutter SDK bulunmadığı için burada gerçek `flutter analyze/build` komutu koşturulamadı. Bunun yerine relative Dart importları, dosya varlıkları, JSON/XML yapılandırmaları ve temel delimiter/sözdizimi bütünlüğü statik olarak kontrol edildi. Son doğrulama kullanıcının Flutter kurulu Windows bilgisayarında `MOBIL_RELEASE_HAZIRLA.bat` ile otomatik yapılacaktır.

## Telefonda kabul testi

- Giriş / çıkış
- Menü drawer aç/kapat
- Dashboard
- Stok arama, raf, stok detayı, resim büyütme
- Satış sepeti, cari seçme, barkod alanı, satış tamamlama
- Alış belgesi ve ürün ekleme
- Cari kart / cari hareket detayı
- Kasa, banka, virman
- Satış/alış siparişi ve irsaliye detayı
- Araç kataloğu arama, şase kopyalama, OEM ekleme/düzenleme/silme, OEM stok arama
- Ürün resmi görüntüleme
- PDF/yazdırma (telefon tarayıcısının yazdırma ekranı)
- Excel/CSV dosya seçme
- Raporlar: özellikle Stok ve Cari
- Ekran döndürme: dikey ve yatay
- Klavye açıkken formun Kaydet butonuna erişim
- Wi-Fi ve mobil veri üzerinden Supabase erişimi

## Telefon kullanım modeli

Önerilen ilk üretim kullanımı Flutter Web/PWA'dır. Bilgisayar ve telefon aynı Supabase veritabanını kullanır; ikinci stok/cari veritabanı oluşturulmaz. Canlı web yayını release build olmalıdır. APK daha sonra ayrıca release-signing ve mağaza kimliğiyle paketlenebilir.
