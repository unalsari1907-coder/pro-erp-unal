# PRO-ERP 2.5.1 — Tam Denetim ve Temizlik Raporu

**Denetim kaynağı:** 2026-08-13 tarihinde Supabase SQL Editor’dan alınan tam backend envanteri ve PRO-ERP 2.5.0 Flutter kaynak paketi.

## Backend envanteri

- Nesne: **82** (table/view)
- Kolon: **886**
- RPC / Function: **122**
- View: **8**
- Constraint: **213**
- Index: **215**
- Trigger: **34**
- Foreign key: **73**
- RLS policy: **45

## Flutter ↔ Supabase uyumluluk sonucu

- Flutter doğrudan tablo/view referansı: **49**
- Dinamik kurumsal tablo referansı: **10**
- Flutter RPC çağrısı: **43**
- Eksik tablo/view referansı: **0**
- Eksik RPC: **0**

Bu denetimde mevcut Flutter kodunun çağırdığı tablo/view ve RPC adlarının tamamının canlı Supabase envanterinde karşılığı bulundu.

## Bu sürümde düzeltilenler

- Eski React/Node/MySQL deneme altyapısı (`frontend`, `erp-project`, `server.js`, `package*.json`) kaldırıldı.
- Kullanılmayan eski Flutter ekran/model/service kopyaları kaldırıldı; yerel import kontrolü temiz geçti.
- Eski ve yeni araç uyumluluk modülü çakışması kaldırıldı; tek ana modül **Araç → Parça Kataloğu** olarak bırakıldı.
- Satış/Alış iade menüleri doğru başlangıç tipiyle açılacak şekilde ayrıldı.
- Rapor menüsündeki Satış / Alış / Stok / Cari / Kasa seçenekleri ilgili rapor sekmesini doğrudan açacak şekilde düzeltildi.
- Uygulama sürümü tek noktada **2.5.1** olarak merkezileştirildi; Supabase URL/anon key `--dart-define` ile değiştirilebilir hale getirildi.
- `url_launcher` doğrudan dependency olarak eklendi.
- Yedekleme V3’e geçirildi; view olan `erp_vade_takip` geri yüklenmeye çalışılmıyor, gerçek `stok_depo_bakiye` kullanılıyor ve pazaryeri tabloları yedeğe dahil.
- Geri yüklemede FK sırasından kaynaklanan hatalar için tekrar deneme turları eklendi.
- Sistem Sağlık Kontrolü satış, alış, finans, kurumsal, araç kataloğu, pazaryeri ve sistem gruplarına genişletildi.
- Pazaryeri genel bakış kartları mobilde taşmayacak şekilde responsive hale getirildi.
- Teklif/Proforma, Satın Alma Talebi ve Muhasebe Fişi için alt satır/detay yönetim altyapısı eklendi.
- Master SQL’e teklif satır toplamı ve teklif başlık toplamı trigger’ları ile muhasebe borç/alacak denge kontrolü eklendi.
- Araç şasesi için uygulama kontrolüne ek olarak DB seviyesinde normalize unique-index güvenliği eklendi (mevcut duplicate yoksa).
- FK sorgularını hızlandırmak için eksik kritik indeksler eklendi.
- RLS kapalı kalan aktif işlem/pazaryeri tabloları, güvenli giriş ayarını bozmadan RLS kapsamına alındı.

## Legacy / gereksiz DB yapıları

Master SQL aşağıdaki tabloları **yalnızca boşlarsa** kaldırır; veri varsa otomatik silmez:

- `satis_detaylari` — envanter tahmini kayıt: 0
- `satislar` — envanter tahmini kayıt: 0
- `alislar` — envanter tahmini kayıt: 0
- `kullanicilar` — envanter tahmini kayıt: 0
- `personel` — envanter tahmini kayıt: 0
- `raporlar` — envanter tahmini kayıt: 0
- `stok_arac` — envanter tahmini kayıt: 0
- `erp_arac_uyumluluk` — envanter tahmini kayıt: 0

`stok_anahtarlar` doğrudan Flutter, view, trigger veya RPC tarafından kullanılmıyor görünmesine rağmen envanterde yaklaşık **111.417** kayıt içerdiği için otomatik silinmedi. Canlı kullanım doğrulanmadan veri kaybı riski alınmadı.

## Bilinçli olarak otomatikleştirilmeyen konular

- **e-Fatura/e-Arşiv/e-İrsaliye canlı gönderimi:** Entegratör seçilmeden gerçek API bağlantısı kurulamaz.
- **Trendyol/Hepsiburada/n11/Amazon canlı senkronizasyonu:** Mağaza API bilgileri olmadan yalnız altyapı hazır tutulur.
- **Kampanya/Fiyat Kuralı otomatik satış fiyatı önceliği:** GENEL/MARKA/GRUP/CARİ kurallarının çakışma önceliği iş kuralı olarak netleştirilmeden satış fiyatını otomatik değiştirmek risklidir.
- **Seri/Lot zorunlu stok düşümü:** Hangi ürün gruplarında seri/lot zorunlu olacağı tanımlanmadan genel stok hareketine bağlanmadı.

## Kaynak kodu kurtarma / arşiv

- `supabase/snapshots/SUPABASE_BACKEND_ENVANTERI_20260813.json` — canlı backend envanteri.
- `supabase/snapshots/SUPABASE_FUNCTIONS_20260813.sql` — canlı RPC/function kaynak kodlarının snapshot’ı.
- `supabase/snapshots/SUPABASE_VIEWS_20260813.sql` — canlı view kaynaklarının snapshot’ı.
- `supabase/PRO_ERP_MASTER_2_5_1.sql` — mevcut canlı DB üzerine uygulanacak güvenli hardening/cleanup SQL’i.

## Sonuç

Bu sürümde yeni özellik eklemekten önce **tekilleştirme, kaynak kurtarma, backend eşleşmesi, veri bütünlüğü, yedekleme, güvenlik ve detay akışları** güçlendirildi. Gerçek dış servis entegrasyonları dışında uygulama tarafındaki temel ERP kaynakları tek proje altında toplandı.