-- GÜVENLİ GİRİŞ AKTİF EDİLDİKTEN SONRA çalıştırın.
-- Yeni kurumsal modülleri yalnız oturum açmış kullanıcılara sınırlar.
do $$
declare t text;
begin
  foreach t in array array[
    'erp_teklifler','erp_hesap_plani','erp_muhasebe_fisleri','erp_cek_senet',
    'erp_doviz_kurlari','erp_e_belgeler','erp_satin_alma_talepleri','erp_onaylar',
    'erp_seri_lot','erp_fiyat_kurallari','erp_arac_uyumluluk'
  ] loop
    execute format('drop policy if exists "pro_erp_gecis_%s" on public.%I', t, t);
    execute format('drop policy if exists "pro_erp_auth_%s" on public.%I', t, t);
    execute format('create policy "pro_erp_auth_%s" on public.%I for all to authenticated using (true) with check (true)', t, t);
  end loop;
end $$;

-- stok-resimleri Storage bucket için güvenli politika örneği:
drop policy if exists "stok_resimleri_insert" on storage.objects;
drop policy if exists "stok_resimleri_update" on storage.objects;
drop policy if exists "stok_resimleri_delete" on storage.objects;
create policy "stok_resimleri_insert_auth" on storage.objects for insert to authenticated with check (bucket_id = 'stok-resimleri');
create policy "stok_resimleri_update_auth" on storage.objects for update to authenticated using (bucket_id = 'stok-resimleri') with check (bucket_id = 'stok-resimleri');
create policy "stok_resimleri_delete_auth" on storage.objects for delete to authenticated using (bucket_id = 'stok-resimleri');

do $$
declare t text;
begin
  foreach t in array array['erp_teklif_detay','erp_muhasebe_fis_satirlari','erp_satin_alma_talep_detay'] loop
    execute format('drop policy if exists "pro_erp_gecis_%s" on public.%I', t, t);
    execute format('drop policy if exists "pro_erp_auth_%s" on public.%I', t, t);
    execute format('create policy "pro_erp_auth_%s" on public.%I for all to authenticated using (true) with check (true)', t, t);
  end loop;
end $$;
