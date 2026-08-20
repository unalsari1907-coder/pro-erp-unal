# PRO-ERP 2.5.1 — Uçtan Uca Test Planı

Master SQL başarıyla çalıştıktan sonra testleri bu sırayla yapın. Bir adım hatalıysa sonraki adıma geçmeyin.

1. **Sistem Sağlık Kontrolü** — kırmızı temel tablo kalmamalı.
2. **Stok Kartı** — ürün aç/düzenle, OEM/Cross/Resim, raf ve fiyat alanlarını doğrula.
3. **Alış** — bir cari + depo + kasa ile alış kaydet; stok artmalı, cari/kasa/stok hareketi oluşmalı.
4. **Alış Siparişi → İrsaliye → Fatura** — belge zincirini ve belge numaralarını kontrol et.
5. **Satış** — stokta olan ürünü sat; stok düşmeli, cari/kasa/stok hareketi oluşmalı.
6. **Satış Siparişi → İrsaliye → Fatura** — sevk/faturalama zincirini kontrol et.
7. **Satış İadesi / Alış İadesi** — menülerin doğru iade tipiyle açıldığını ve stok yönünü kontrol et.
8. **Cari Ekstre** — Fatura No, bakiye ve detayda irsaliye bilgilerini doğrula.
9. **Kasa/Banka/POS** — tahsilat, ödeme, transfer/virman ve gün sonunu test et.
10. **Muhasebe Fişi** — borç/alacak satırları ekle; dengesiz fiş ONAYLI/KESİN yapılamamalı.
11. **Teklif/Proforma** — başlık aç, ürün satırları ekle; toplam otomatik güncellenmeli.
12. **Satın Alma Talebi** — talep başlığı ve birden fazla detay satırı ekle.
13. **Araç → Parça Kataloğu** — güçlü arama, yıl aralığı, şase kopyalama, OEM düzenleme, sağ/sol, stok alternatifi ve satışa eklemeyi test et.
14. **Pazaryeri / E-Ticaret** — kanallar ve responsive ekranları kontrol et; gerçek API anahtarı girilmeden canlı senkron beklenmez.
15. **Raporlar** — Satış/Alış/Stok/Cari/Kasa menülerinin doğru sekmeyle açıldığını kontrol et.
16. **Yedekleme** — JSON V3 yedeği al; atlanan tablo olmamalı. Geri yükleme testi mutlaka ayrı test ortamında yapılmalı.
