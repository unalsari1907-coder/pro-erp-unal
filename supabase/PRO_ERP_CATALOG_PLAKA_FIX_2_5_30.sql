-- PRO ERP 2.5.30 - Araç kataloğu plaka desteği
-- Bir kez Supabase SQL Editor'da çalıştırın.

alter table if exists public.erp_arac_katalog_araclar
  add column if not exists plaka text;

update public.erp_arac_katalog_araclar
set plaka = upper(regexp_replace(trim(plaka), '\s+', ' ', 'g'))
where plaka is not null and trim(plaka) <> '';

create index if not exists idx_erp_arac_katalog_araclar_plaka
  on public.erp_arac_katalog_araclar ((upper(regexp_replace(coalesce(plaka, ''), '[^A-Za-z0-9]', '', 'g'))));

comment on column public.erp_arac_katalog_araclar.plaka
  is 'Araç plakası; araç kataloğu detayında gösterilir ve aramada kullanılır.';
