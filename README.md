# PRO-ERP 2.5.11

ÜNAL YEDEK PARÇA için Flutter + Supabase tabanlı kurumsal yedek parça ERP.

## Çalıştırma

```powershell
flutter pub get
flutter run -d chrome
```

İstenirse Supabase bilgileri kaynak kod değiştirmeden verilebilir:

```powershell
flutter run -d chrome --dart-define=SUPABASE_URL=https://... --dart-define=SUPABASE_ANON_KEY=...
```

## Bu sürümde Supabase

Mevcut canlı veritabanı için önce `supabase/PRO_ERP_MASTER_2_5_1.sql` dosyasını Supabase SQL Editor'da bir kez çalıştırın. Bu SQL, mevcut çalışan yapıyı harden eder; boş legacy tabloları güvenli koşulla temizler ve gerekli indeks/RLS/trigger iyileştirmelerini ekler.

Canlı backend kaynak snapshot'ları `supabase/snapshots/` altındadır.

## Kontrol

Önce `PRO_ERP_2.5.1_DENETIM_RAPORU.md`, sonra `PRO_ERP_TEST_PLANI.md` dosyasını izleyin.

## Mobil / Telefon
2.5.9 mobil son kontrol bilgileri için `TELEFON_MOBIL_SON_KONTROL_2.5.9.md` dosyasına bakın. Telefon performansını debug modunda değerlendirmeyin; `TELEFONDA_TEST_ET.bat` release modunda çalışır.

## Cloudflare Pages

Bu proje Cloudflare Pages üzerindeki `pro-erp-unal` projesine yayınlanır:

`https://pro-erp-unal.pages.dev`

İlk kullanımda `CLOUDFLARE_KONTROL_ET.bat` dosyasını çalıştırın. Giriş istenirse proje klasöründe bir kez `npx wrangler login` çalıştırın.

Canlı yayın için `CLOUDFLARE_YAYINLA.bat` dosyasını çalıştırın. Script sırasıyla temiz release build, kod analizi, Wrangler oturum kontrolü, Pages production dağıtımı ve son dağıtım listesini çalıştırır. Build veya analiz hatası varsa yayın yapılmaz.

Wrangler yapılandırması `wrangler.jsonc`, Pages çıktısı `build/web`, production dalı `main` olarak sabitlenmiştir. Cloudflare tarafında veritabanı oluşturulmaz; bilgisayar ve telefon aynı Supabase veritabanını kullanır.
