# PRO ERP'yi telefondan kullanma ve web yayını

## Telefonda kullanım

Uygulama Flutter Web olarak derlenip internete yayınlandıktan sonra telefonda Chrome veya
Safari üzerinden verilen HTTPS adresi açılır. İlk girişte Supabase yönetici e-posta ve şifresi
kullanılır. Çıkış yapılmadıkça veya tarayıcı verileri temizlenmedikçe oturum cihazda korunur.

Bu sürümde 900 pikselden dar ekranlarda:

- Sol menü hamburger menüsüne dönüşür.
- Menüden sayfa seçilince menü otomatik kapanır.
- Açılmış sayfalar korunur ve menüden tekrar seçilebilir.
- Dashboard kartları telefon genişliğine göre yerleşir.
- Giriş ekranı küçük telefonlarda taşmadan kaydırılabilir.
- Telefon yatay çevrildiğinde geniş tablolar daha rahat kullanılabilir.

## Bilgisayarda kontrol

Komut yazmadan çalıştırmak için `PRO_ERP_CALISTIR.bat` dosyasına çift tıklayabilirsiniz.
Telefon testi için `TELEFONDA_TEST_ET.bat`, yayın klasörü için
`WEB_SURUMU_OLUSTUR.bat` dosyasını kullanabilirsiniz.

Proje klasöründe PowerShell açıp sırasıyla çalıştırın:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter run -d chrome
```

## Aynı Wi-Fi üzerinden geçici telefon testi

Bilgisayar ve telefon aynı Wi-Fi ağına bağlıyken:

```powershell
flutter run -d web-server --web-hostname 0.0.0.0 --web-port 8080
```

Windows'ta `ipconfig` komutuyla bilgisayarın IPv4 adresini bulun. Telefonda örneğin
`http://192.168.1.25:8080` adresini açın. Bilgisayar ve komut penceresi açık kalmalıdır.

## Kalıcı web derlemesi

```powershell
flutter build web --release
```

Yayınlanacak dosyalar `build/web` klasöründe oluşur. Bu klasör seçilen web barındırma
hizmetine yüklenir ve telefondan kullanılacak HTTPS adresi alınır.

## Güvenlik

- Supabase `anon`/`publishable` anahtarı istemci uygulamasında kullanılabilir.
- Supabase `service_role` veya secret anahtarı uygulama koduna konulmamalıdır.
- İnternet yayını öncesinde Supabase RLS ve kullanıcı yetkileri açık olmalıdır.
- ERP sayfası arama motorlarına kapalı olacak şekilde ayarlanmıştır.

## Temiz ZIP oluşturma

Proje paylaşılırken `.dart_tool`, `build` ve `node_modules` klasörlerini ZIP'e eklemeyin.
Bu klasörler yeniden oluşturulabilen geçici dosyalardır.
