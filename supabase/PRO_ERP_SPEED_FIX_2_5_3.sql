/*
  PRO-ERP v2.5.3 - HIZ İYİLEŞTİRME INDEXLERİ
  Güvenlidir: veri silmez/değiştirmez, yalnız eksik indexleri oluşturur.
*/

create index if not exists idx_stoklar_urun_adi_hiz
  on public.stoklar (urun_adi);

create index if not exists idx_arac_katalog_liste_hiz
  on public.erp_arac_katalog_araclar (uretici, model, yil);

create index if not exists idx_satis_baslik_tarih_hiz
  on public.satis_baslik (tarih);

create index if not exists idx_alis_baslik_tarih_hiz
  on public.alis_baslik (tarih);

create index if not exists idx_satis_detay_satis_stok_hiz
  on public.satis_detay (satis_id, stok_id);

create index if not exists idx_alis_detay_alis_stok_hiz
  on public.alis_detay (alis_id, stok_id);

create index if not exists idx_arac_katalog_parca_arac_sira_hiz
  on public.erp_arac_katalog_parcalar (arac_id, sira);

analyze public.stoklar;
analyze public.erp_arac_katalog_araclar;
analyze public.erp_arac_katalog_parcalar;
analyze public.satis_baslik;
analyze public.alis_baslik;
analyze public.satis_detay;
analyze public.alis_detay;
