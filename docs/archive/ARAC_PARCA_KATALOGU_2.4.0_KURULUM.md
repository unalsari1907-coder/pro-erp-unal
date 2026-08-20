# PRO ERP 2.4.0 - Araç → Parça Kataloğu

Bu sürüm mevcut stok ve `erp_arac_uyumluluk` yapısını bozmaz. Yeni normalize katalog tabloları ekler.

## 1) Supabase SQL
SQL Editor'da bir kez çalıştırın:

`supabase/migrations/20260812_arac_parca_katalogu.sql`

## 2) ERP
`flutter pub get`
`flutter run -d chrome`

## 3) Katalog içe aktarma
Kurumsal ERP → Araç → Parça Kataloğu → **Excel / CSV İçe Aktar**.

Beklenen ana kolonlar:
YILLAR, ÜRETİCİ, YIL, MODEL, MOTOR, YAKIT, MOTOR KODU, SASE, NOT, ...parça kolonları..., ARAÇ SAHİBİ.

Başlıklar Türkçe karakterli olabilir. Sistem başlıkları normalize eder. XLSX ve CSV desteklenir.

- `+`, `/`, `,`, `;` ile ayrılmış OEM kodları ayrı kayıt olur.
- BENZINLI, DIZEL, KAMPANA, KAYISLI, ZINCIRLI gibi metinler OEM değil nitelik olarak saklanır.
- Aynı araç tekrar içe aktarılırsa araç güncellenir ve o araca ait katalog parçaları yenilenir.
- Katalog OEM'ine tıklandığında mevcut `urun_ara` RPC üzerinden stok OEM/Cross/Rakip/Üretici kodu eşleşmeleri aranır.
- Eşleşme yoksa "Katalogda var, stokta yok" gösterilir.

## 4) Arama
Üretici, model, yıl, motor, motor kodu veya şase ile arama yapılabilir. Araç seçildiğinde parça grupları kategori halinde açılır.
