-- PRO-ERP 2.5.1 TEST İŞLEM VERİLERİNİ TEMİZLE
-- Ana kart/katalog/ayar tablolarına dokunmaz. CASCADE kullanmaz.
DO $$
DECLARE
  t text;
  liste text[] := ARRAY[
    'erp_pazaryeri_siparis_detay','erp_pazaryeri_iadeleri','erp_pazaryeri_siparisleri','erp_pazaryeri_senkron_log',
    'erp_muhasebe_fis_satirlari','erp_muhasebe_fisleri','erp_kur_farki_fisleri','erp_belge_baglantilari',
    'erp_teklif_detay','erp_teklifler','erp_satin_alma_talep_detay','erp_satin_alma_talepleri','erp_onaylar','erp_e_belgeler',
    'satis_siparis_sevk','satis_irsaliye_fatura','satis_irsaliye_detay','satis_irsaliye_baslik','satis_siparis_detay','satis_siparis_baslik','satis_detay','satis_baslik',
    'alis_siparis_kabul','alis_irsaliye_fatura','alis_irsaliye_detay','alis_irsaliye_baslik','alis_siparis_detay','alis_siparis_baslik','alis_detay','alis_baslik',
    'iade_detay','iade_baslik','depo_hareketleri','stok_hareket','cari_virman','cari_hareket','finans_transfer','kasa_hareket','giderler','erp_kasa_gun_sonu'
  ];
  mevcut text[] := ARRAY[]::text[];
BEGIN
  FOREACH t IN ARRAY liste LOOP
    IF EXISTS (
      SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
      WHERE n.nspname='public' AND c.relname=t AND c.relkind IN ('r','p')
    ) THEN
      mevcut := array_append(mevcut,format('public.%I',t));
    END IF;
  END LOOP;
  IF array_length(mevcut,1) IS NOT NULL THEN
    EXECUTE 'TRUNCATE TABLE '||array_to_string(mevcut,', ')||' RESTART IDENTITY';
  END IF;
END $$;
