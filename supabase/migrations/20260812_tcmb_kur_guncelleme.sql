-- TCMB günlük kur entegrasyonu için ek alanlar.
alter table public.erp_doviz_kurlari
  add column if not exists birim numeric(18,6) default 1,
  add column if not exists guncellenme_tarihi timestamptz default now();

create index if not exists idx_erp_doviz_kurlari_para_tarih
  on public.erp_doviz_kurlari(para_birimi, tarih desc);

comment on table public.erp_doviz_kurlari is
  'TCMB veya manuel kaynaktan günlük kurlar. Alış/satış alanları 1 döviz birimi karşılığı TL olarak saklanır.';
