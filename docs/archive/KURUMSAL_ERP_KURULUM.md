# PRO ERP 2.2 — Kurumsal Yedek Parça ERP Paketi

## Bu pakette eklenenler

- Teklif / Proforma altyapısı
- Genel muhasebe: Hesap Planı + Muhasebe Fişleri + fiş satır şeması
- Çek / Senet portföyü
- Döviz / kur yönetimi
- e-Fatura / e-Arşiv / e-İrsaliye belge kuyruğu
- Satın alma talep yönetimi
- Onay merkezi
- Seri / Lot takibi
- Kampanya / fiyat kuralları
- Araç uyumluluk kataloğu (marka, model, yıl, motor, motor kodu, stok)
- Yönetici / Operasyon merkezi
- Genişletilmiş tam yedek + JSON geri yükleme
- Uygulama hata günlüğü
- GitHub Pages için doğru `--base-href /pro-erp-unal/` build komutu
- Sürüm standardizasyonu: 2.3.0+20260812
- Eski örnek Counter testi kaldırıldı; ERP modül smoke testleri eklendi

## 1. Veritabanını kur

Supabase > SQL Editor içinde sırayla çalıştır:

1. `supabase/migrations/20260812_kurumsal_erp.sql`
2. Güvenli giriş tamamen aktif ve test edildikten sonra: `supabase/migrations/20260812_rls_hardening.sql`

İlk SQL mevcut tabloları silmez. Yeni tabloları `IF NOT EXISTS` ile ekler.

## 2. ERP'yi test et

```powershell
cd C:\Users\User\Desktop\UNAL\PRO_ERP\pro_erp
flutter pub get
flutter run -d chrome
```

Kontrol listesi:

- Mevcut Stok / Satış / Alış / Cari / Kasa ekranları açılıyor mu?
- Kurumsal ERP menüsü görünüyor mu?
- Teklif / Proforma yeni kayıt oluşturuyor mu?
- Araç Uyumluluk yeni kayıt oluşturuyor mu?
- Finans / Muhasebe menüsü açılıyor mu?
- Yedekleme ekranından Tam Yedek Al çalışıyor mu?

## 3. GitHub Pages build

`WEB_SURUMU_OLUSTUR.bat` kullan veya:

```powershell
flutter build web --release --base-href "/pro-erp-unal/"
```

Bu ayar GitHub Pages beyaz ekran problemini önler.

## e-Belge hakkında önemli not

e-Fatura/e-Arşiv/e-İrsaliye ekranı ve gönderim kuyruğu hazırdır. Ancak gerçek GİB gönderimi için kullanılan özel entegratörün (Logo, Uyumsoft, EDM, Foriba vb.) API adresi, kullanıcı/anahtar bilgileri ve sözleşmesi gerekir. Bu bilgiler olmadan gerçek mali belge gönderimi teknik olarak yapılamaz. Entegratör bilgileri geldiğinde `erp_e_belgeler` kuyruğu doğrudan entegrasyona bağlanabilir.

## Güvenlik

Geçiş SQL'i mevcut opsiyonel giriş düzenini bozmamak için yeni tablolarda `anon` erişimine izin verir. Canlı üretimde güvenli giriş test edildikten sonra hardening SQL'i çalıştırılarak yeni modüller sadece `authenticated` kullanıcıya daraltılmalıdır.
