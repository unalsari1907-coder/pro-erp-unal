# PRO ERP 2.3.0 – Logo/Tiger Tarzı Genişletme

Bu paket mevcut çalışan PRO ERP'nin üzerine **silme yapmadan** yeni kurumsal ekranlar ekler.

## Eklenen / güçlendirilen bölümler

- Yönetici Kokpiti: günlük ciro, brüt kâr, tahsilat, ödeme, cari alacak/borç ve operasyon uyarıları.
- Belge Geçmişi / Zinciri: fatura, sipariş, irsaliye, teklif ve cari belgelerde tek arama.
- Mizan / Muhasebe Raporları: hesap planı ve muhasebe fiş satırlarından borç-alacak-bakiye.
- Kur Farkı Fişleri: döviz tutarı ve eski/yeni kurdan kur farkı kaydı.
- Vade Yaşlandırma: gelmemiş, 1-30, 31-60, 61-90 ve 90+ gün grupları.
- Araç → Parça Kataloğu: marka/model/yıl/motor/motor kodu ile uyumlu stok arama.
- Sistem Sağlık Kontrolü: kritik Supabase tablolarına erişim kontrolü.
- Kritik Stok Sipariş Önerisi menüye doğrudan eklendi.
- Mevcut Teklif/Proforma, Çek/Senet, e-Belge, Seri/Lot, Kampanya/Fiyat, Satın Alma Talep/Onay ve TCMB kur modülleri korunur.
- Yedekleme kapsamına yeni tablolar eklendi.

## Supabase kurulumu

Önce daha önce çalıştırılmadıysa:

1. `supabase/migrations/20260812_kurumsal_erp.sql`
2. `supabase/migrations/20260812_tcmb_kur_guncelleme.sql`

Ardından bu sürüm için **bir kez**:

3. `supabase/migrations/20260812_logo_seviye_genisletme.sql`

SQL Editor'da çalıştırın.

> Bu migration mevcut satış, alış, stok, cari ve kasa tablolarını silmez.

## e-Belge notu

ERP tarafında e-Belge merkezi ve kuyruk altyapısı bulunur. Gerçek e-Fatura/e-Arşiv/e-İrsaliye gönderimi için kullanılacak özel entegratörün API adresi ve yetki bilgileri ayrıca tanımlanmalıdır. Bu bilgiler olmadan gerçek mali belge gönderimi otomatikleştirilemez.

## Çalıştırma

```powershell
flutter pub get
flutter run -d chrome
```

GitHub Pages için:

```powershell
flutter build web --release --base-href "/pro-erp-unal/"
```
