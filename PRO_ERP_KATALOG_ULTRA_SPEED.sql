-- PRO ERP Araç Katalog Ultra Speed
-- Supabase SQL Editor'da bir kez çalıştırın.
create extension if not exists pg_trgm;

create index if not exists idx_erp_arac_katalog_araclar_uretici_trgm
  on public.erp_arac_katalog_araclar using gin (uretici gin_trgm_ops);
create index if not exists idx_erp_arac_katalog_araclar_model_trgm
  on public.erp_arac_katalog_araclar using gin (model gin_trgm_ops);
create index if not exists idx_erp_arac_katalog_araclar_motor_trgm
  on public.erp_arac_katalog_araclar using gin (motor gin_trgm_ops);
create index if not exists idx_erp_arac_katalog_araclar_motor_kodu_trgm
  on public.erp_arac_katalog_araclar using gin (motor_kodu gin_trgm_ops);
create index if not exists idx_erp_arac_katalog_araclar_sase_trgm
  on public.erp_arac_katalog_araclar using gin (sase gin_trgm_ops);

create index if not exists idx_erp_arac_katalog_araclar_sort
  on public.erp_arac_katalog_araclar (uretici, model, yil, arac_id);

create index if not exists idx_erp_arac_katalog_parcalar_arac_sira
  on public.erp_arac_katalog_parcalar (arac_id, sira);
create index if not exists idx_erp_arac_katalog_parcalar_arac_kategori
  on public.erp_arac_katalog_parcalar (arac_id, kategori_kodu);
create index if not exists idx_erp_arac_katalog_parcalar_oem_trgm
  on public.erp_arac_katalog_parcalar using gin (oem_kodu gin_trgm_ops)
  where oem_kodu is not null;

analyze public.erp_arac_katalog_araclar;
analyze public.erp_arac_katalog_parcalar;
