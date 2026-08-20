-- PRO ERP 2.5.31 - Kredi kartı limit takibi
alter table if exists public.kasalar
  add column if not exists kk_limit numeric(14,2) not null default 0;

comment on column public.kasalar.kk_limit is
  'POS/Kredi kartı için tanımlı toplam limit.';

notify pgrst, 'reload schema';
