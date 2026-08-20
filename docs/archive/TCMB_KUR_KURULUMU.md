# TCMB Günlük Kur Entegrasyonu

Bu sürümde Döviz / Kur ekranı TCMB resmi günlük kurlarını Supabase Edge Function üzerinden çeker.
Tarayıcı CORS sorununa takılmaması ve servis anahtarlarının istemciye konmaması için TCMB isteği sunucu tarafında yapılır.

## 1) SQL migration
Supabase SQL Editor'da çalıştırın:

`supabase/migrations/20260812_tcmb_kur_guncelleme.sql`

## 2) Edge Function deploy
Supabase CLI kuruluysa proje kökünde:

```powershell
supabase functions deploy tcmb-kur-guncelle
```

Supabase Dashboard üzerinden de `supabase/functions/tcmb-kur-guncelle/index.ts` içeriğiyle aynı isimde function oluşturabilirsiniz.

## 3) Çalışma şekli
- ERP her gün ilk açıldığında o güne ait kur var mı kontrol eder.
- Yoksa TCMB kurunu otomatik çeker.
- Döviz / Kur ekranındaki **TCMB Kurlarını Güncelle** butonu ile istenildiğinde yeniden çekilebilir.
- **Manuel Kur** butonu servis kesintisinde veya özel kur kullanılacağında devreye girer.
- USD, EUR, GBP, CHF ve JPY varsayılan olarak çekilir.
- JPY gibi TCMB'de 100 birim üzerinden yayımlanabilen kurlar ERP'de hesaplama güvenliği için 1 birime normalize edilir.

## Belge kuru kuralı
Fatura/sipariş gibi bir belge kaydedildiğinde kullanılan para birimi ve kur belge satırına/başlığına sabitlenmelidir. Gelecekteki günlük kur güncellemeleri geçmiş belgenin kurunu değiştirmemelidir.
