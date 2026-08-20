-- PRO ERP 2.5.30 - güvenli performans indeksleri
-- Mevcut veriyi değiştirmez. Supabase SQL Editor'de bir kez uygulanabilir.

create index if not exists idx_stok_hareket_tarih_desc
  on public.stok_hareket (tarih desc);

create index if not exists idx_stok_hareket_stok_id
  on public.stok_hareket (stok_id);

create index if not exists idx_stok_hareket_cari_id
  on public.stok_hareket (cari_id);

create index if not exists idx_stok_hareket_depo_id
  on public.stok_hareket (depo_id);

create index if not exists idx_stoklar_uretici_kodu
  on public.stoklar (uretici_kodu);
