# PRO-ERP Cloudflare Pages Kurulumu

## Seçilen ürün

- Ürün: Cloudflare Pages
- Pages projesi: `pro-erp-unal`
- Production dalı: `main`
- Adres: `https://pro-erp-unal.pages.dev`
- Yayın klasörü: `build/web`

PRO-ERP bir Flutter Web/PWA istemcisidir ve verileri doğrudan mevcut Supabase projesinden kullanır. Cloudflare tarafında D1, R2, KV, Worker veya Tunnel oluşturulmaz. Böylece bilgisayar ve telefon aynı stok, cari ve satış verilerini kullanmaya devam eder.

## İlk bağlantı kontrolü

`CLOUDFLARE_KONTROL_ET.bat` dosyasını çalıştırın. Script Wrangler'ı hazırlar, Cloudflare oturumunu kontrol eder ve `pro-erp-unal` projesinin son dağıtımlarını listeler.

Oturum yoksa proje klasöründe bir kez şu komutu çalıştırın:

```powershell
npx wrangler login
```

## Production yayını

`CLOUDFLARE_YAYINLA.bat` dosyasını çalıştırın. Script aşağıdaki sırayı uygular:

1. `flutter clean`
2. `flutter pub get`
3. `flutter analyze --no-fatal-warnings --no-fatal-infos`
4. `flutter build web --release`
5. `wrangler whoami`
6. `wrangler pages deploy build/web --project-name=pro-erp-unal --branch=main`
7. Son Pages dağıtımlarını listeleme

Build veya analyzer hatası oluşursa yayın başlamaz.

## Elle çalıştırılabilecek komutlar

```powershell
npm install
npm run cf:whoami
npm run cf:inspect
npm run cf:preview
npm run cf:deploy
```

## Cloudflare dosyaları

- `wrangler.jsonc`: Pages proje adı, build klasörü ve uyumluluk tarihi
- `package.json`: Wrangler sürümü ve kontrol/önizleme/yayın komutları
- `web/_redirects`: Flutter SPA yollarını `index.html` dosyasına yönlendirir
- `web/_headers`: Güvenlik başlıkları ve PWA ana dosyaları için güncel içerik kontrolü
- `.gitignore`: Wrangler'ın yerel çalışma durumunu dışarıda tutar

## Yayın sonrası hızlı kontrol

- Giriş ekranı açılıyor.
- Supabase bağlantısı çalışıyor.
- Telefon ve bilgisayarda aynı veriler görünüyor.
- Sayfa yenilendiğinde 404 oluşmuyor.
- PWA ana ekrana eklenebiliyor.
- Stok arama, satış, alış, cari ve kasa ekranları açılıyor.
- Kamera/resim seçme gereken mobil ekranlarda izin akışı çalışıyor.
