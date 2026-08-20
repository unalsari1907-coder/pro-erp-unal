-- PRO ERP 2.5.24 katalog/stok hız indeksleri
-- Supabase SQL Editor'de bir kez çalıştırılabilir.
create index if not exists idx_erp_arac_katalog_parcalar_arac
  on public.erp_arac_katalog_parcalar (arac_id);
create index if not exists idx_stoklar_uretici_kodu
  on public.stoklar (uretici_kodu);
create index if not exists idx_stoklar_urun_adi_lower
  on public.stoklar (lower(urun_adi));
create index if not exists idx_stoklar_oem_no_lower
  on public.stoklar (lower(oem_no));
