-- ============================================================================
-- PRO-ERP 2.5.1 - LIVE DATABASE HARDENING / CLEANUP MASTER
-- Kaynak: 2026-08-13 Supabase tam backend envanteri.
-- Amaç: mevcut çalışan veritabanını bozmadan gereksiz boş legacy yapıları
-- temizlemek, eksik indeksleri eklemek, RLS açıklarını kapatmak ve katalog /
-- pazaryeri altyapısını sağlamlaştırmak.
-- ============================================================================

begin;

-- --------------------------------------------------------------------------
-- 1) Şema sürümü
-- --------------------------------------------------------------------------
create table if not exists public.erp_schema_surumu (
  id smallint primary key default 1 check (id = 1),
  surum text not null,
  guncelleme_tarihi timestamptz not null default now(),
  aciklama text
);
insert into public.erp_schema_surumu(id,surum,aciklama)
values (1,'2.5.1','PRO-ERP live backend audit/hardening 2026-08-13')
on conflict (id) do update
set surum=excluded.surum,
    guncelleme_tarihi=now(),
    aciklama=excluded.aciklama;

-- --------------------------------------------------------------------------
-- 2) updated_at standardı
-- --------------------------------------------------------------------------
create or replace function public.erp_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'erp_arac_katalog_araclar',
    'erp_pazaryeri_kanallari',
    'erp_pazaryeri_urunleri',
    'erp_pazaryeri_siparisleri',
    'erp_pazaryeri_iadeleri'
  ] loop
    if exists (
      select 1 from information_schema.columns
      where table_schema='public' and table_name=t and column_name='updated_at'
    ) then
      execute format('drop trigger if exists trg_%I_updated_at on public.%I',t,t);
      execute format('create trigger trg_%I_updated_at before update on public.%I for each row execute function public.erp_set_updated_at()',t,t);
    end if;
  end loop;
end $$;

-- --------------------------------------------------------------------------
-- 3) Araç kataloğu: aynı şaseyi DB seviyesinde de engelle.
--    Mevcut tekrarlı şase varsa index oluşturulmaz ve NOTICE verir.
-- --------------------------------------------------------------------------
do $$
begin
  if exists (
    select 1
    from public.erp_arac_katalog_araclar
    where nullif(trim(sase),'') is not null
    group by upper(trim(sase))
    having count(*) > 1
  ) then
    raise notice 'Aynı şaseye sahip mevcut kayıt bulundu; unique şase indexi oluşturulmadı.';
  else
    execute 'create unique index if not exists ux_erp_arac_katalog_sase_norm on public.erp_arac_katalog_araclar (upper(trim(sase))) where nullif(trim(sase), '''') is not null';
  end if;
end $$;

-- --------------------------------------------------------------------------
-- 4) FK performans indeksleri (Logo/Tiger ölçeğinde belge detayına iniş için)
-- --------------------------------------------------------------------------
create index if not exists idx_alis_baslik_depo_id on public.alis_baslik(depo_id);
create index if not exists idx_alis_baslik_kasa_id on public.alis_baslik(kasa_id);
create index if not exists idx_alis_detay_depo_id on public.alis_detay(depo_id);
create index if not exists idx_alis_irsaliye_baslik_siparis_id on public.alis_irsaliye_baslik(siparis_id);
create index if not exists idx_alis_irsaliye_detay_siparis_detay_id on public.alis_irsaliye_detay(siparis_detay_id);
create index if not exists idx_alis_siparis_baslik_depo_id on public.alis_siparis_baslik(depo_id);
create index if not exists idx_cari_virman_musteri on public.cari_virman(musteri_cari_id);
create index if not exists idx_cari_virman_tedarikci on public.cari_virman(tedarikci_cari_id);
create index if not exists idx_depo_hareket_kaynak on public.depo_hareketleri(kaynak_depo_id);
create index if not exists idx_depo_hareket_hedef on public.depo_hareketleri(hedef_depo_id);
create index if not exists idx_finans_transfer_kaynak on public.finans_transfer(kaynak_kasa_id);
create index if not exists idx_finans_transfer_hedef on public.finans_transfer(hedef_kasa_id);
create index if not exists idx_iade_detay_iade_id on public.iade_detay(iade_id);
create index if not exists idx_kasa_hareket_cari_id on public.kasa_hareket(cari_id);
create index if not exists idx_satis_baslik_depo_id on public.satis_baslik(depo_id);
create index if not exists idx_satis_baslik_kasa_id on public.satis_baslik(kasa_id);
create index if not exists idx_satis_detay_depo_id on public.satis_detay(depo_id);
create index if not exists idx_satis_irsaliye_baslik_siparis_id on public.satis_irsaliye_baslik(siparis_id);
create index if not exists idx_satis_irsaliye_detay_siparis_detay_id on public.satis_irsaliye_detay(siparis_detay_id);
create index if not exists idx_satis_siparis_baslik_depo_id on public.satis_siparis_baslik(depo_id);
create index if not exists idx_stok_hareket_cari_id on public.stok_hareket(cari_id);
create index if not exists idx_pz_iade_kanal_id on public.erp_pazaryeri_iadeleri(kanal_id);
create index if not exists idx_pz_log_kanal_id on public.erp_pazaryeri_senkron_log(kanal_id);
create index if not exists idx_pz_detay_siparis_id on public.erp_pazaryeri_siparis_detay(siparis_id);
create index if not exists idx_pz_detay_stok_id on public.erp_pazaryeri_siparis_detay(stok_id);

-- --------------------------------------------------------------------------
-- 5) RLS standardı
--    Güvenli giriş KAPALI: anon + authenticated çalışır.
--    Güvenli giriş AÇIK: yalnız authenticated çalışır.
--    Böylece uygulamadaki "guvenli_giris" ayarı gerçekten tüm ERP'ye uygulanır.
-- --------------------------------------------------------------------------
do $$
declare t text;
        p text;
begin
  foreach t in array array[
    'alis_baslik','alis_detay','alis_irsaliye_baslik','alis_irsaliye_detay','alis_irsaliye_fatura',
    'alis_siparis_baslik','alis_siparis_detay','alis_siparis_kabul',
    'cari_hareket','cari_virman','cariler','depo_hareketleri','depolar',
    'erp_arac_katalog_araclar','erp_arac_katalog_parcalar','erp_belge_baglantilari',
    'erp_cek_senet','erp_doviz_kurlari','erp_e_belgeler','erp_fiyat_kurallari','erp_hesap_plani',
    'erp_islem_log','erp_kullanicilar','erp_schema_surumu','erp_kur_farki_fisleri','erp_muhasebe_fisleri',
    'erp_muhasebe_fis_satirlari','erp_onaylar','erp_satin_alma_talepleri',
    'erp_satin_alma_talep_detay','erp_seri_lot','erp_sistem_kontrol_log','erp_teklifler','erp_teklif_detay',
    'erp_pazaryeri_kanallari','erp_pazaryeri_urunleri','erp_pazaryeri_siparisleri',
    'erp_pazaryeri_siparis_detay','erp_pazaryeri_iadeleri','erp_pazaryeri_senkron_log',
    'finans_transfer','giderler','iade_baslik','iade_detay','kasa_hareket','kasalar',
    'satis_baslik','satis_detay','satis_irsaliye_baslik','satis_irsaliye_detay','satis_irsaliye_fatura',
    'satis_siparis_baslik','satis_siparis_detay','satis_siparis_sevk',
    'stok_cross','stok_depo_bakiye','stok_hareket','stok_oem','stok_rakip','stok_resim','stoklar'
  ] loop
    if to_regclass('public.'||t) is not null then
      execute format('alter table public.%I enable row level security',t);
      p := 'pro_erp_gecis_' || t;
      execute format('drop policy if exists %I on public.%I',p,t);
      execute format(
        'create policy %I on public.%I for all to anon, authenticated using ((auth.role() = ''authenticated'') or (not public.erp_guvenli_giris_aktif())) with check ((auth.role() = ''authenticated'') or (not public.erp_guvenli_giris_aktif()))',
        p,t
      );
    end if;
  end loop;
end $$;

-- --------------------------------------------------------------------------
-- 5B) Teklif / Proforma satır hesabı ve başlık toplamı
-- --------------------------------------------------------------------------
create or replace function public.erp_teklif_detay_hesapla()
returns trigger
language plpgsql
as $$
begin
  new.miktar := coalesce(new.miktar, 0);
  new.birim_fiyat := coalesce(new.birim_fiyat, 0);
  new.iskonto_orani := coalesce(new.iskonto_orani, 0);
  new.kdv_orani := coalesce(new.kdv_orani, 0);
  new.toplam := round(
    new.miktar * new.birim_fiyat *
    (1 - new.iskonto_orani / 100) *
    (1 + new.kdv_orani / 100), 2
  );
  return new;
end;
$$;

create or replace function public.erp_teklif_toplam_guncelle()
returns trigger
language plpgsql
as $$
declare v_teklif_id bigint;
begin
  if tg_op = 'DELETE' then
    v_teklif_id := old.teklif_id;
  else
    v_teklif_id := new.teklif_id;
  end if;

  update public.erp_teklifler
     set toplam = coalesce((select sum(toplam) from public.erp_teklif_detay where teklif_id=v_teklif_id),0)
   where teklif_id=v_teklif_id;

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_erp_teklif_detay_hesap on public.erp_teklif_detay;
create trigger trg_erp_teklif_detay_hesap
before insert or update on public.erp_teklif_detay
for each row execute function public.erp_teklif_detay_hesapla();

drop trigger if exists trg_erp_teklif_toplam on public.erp_teklif_detay;
create trigger trg_erp_teklif_toplam
after insert or update or delete on public.erp_teklif_detay
for each row execute function public.erp_teklif_toplam_guncelle();

-- Muhasebe fişi ONAYLI/KESIN duruma geçerken borç-alacak eşitliği zorunlu.
create or replace function public.erp_muhasebe_fis_denge_kontrol()
returns trigger
language plpgsql
as $$
begin
  if upper(coalesce(new.durum,'')) in ('ONAYLI','KESIN','KESİN','KAPALI')
     and abs(coalesce(new.borc_toplam,0)-coalesce(new.alacak_toplam,0)) > 0.01 then
    raise exception 'Muhasebe fişi dengede değil. Borç: %, Alacak: %', new.borc_toplam, new.alacak_toplam;
  end if;
  return new;
end;
$$;

drop trigger if exists trg_erp_muhasebe_fis_denge on public.erp_muhasebe_fisleri;
create trigger trg_erp_muhasebe_fis_denge
before insert or update of durum, borc_toplam, alacak_toplam on public.erp_muhasebe_fisleri
for each row execute function public.erp_muhasebe_fis_denge_kontrol();

-- --------------------------------------------------------------------------
-- 6) Gereksiz legacy tablolar: SADECE tamamen boşlarsa silinir.
--    Yeni PRO-ERP kodu bu yapılara başvurmuyor.
-- --------------------------------------------------------------------------
do $$
declare t text;
        n bigint;
begin
  foreach t in array array[
    'satis_detaylari', -- eski satislar yapısının çocuğu; önce bu
    'satislar',
    'alislar',
    'kullanicilar',
    'personel',
    'raporlar',
    'stok_arac',
    'erp_arac_uyumluluk'
  ] loop
    if to_regclass('public.'||t) is not null then
      execute format('select count(*) from public.%I',t) into n;
      if n = 0 then
        begin
          execute format('drop table public.%I',t);
          raise notice 'Boş legacy tablo silindi: %',t;
        exception when dependent_objects_still_exist then
          raise notice 'Legacy tablo bağımlılık nedeniyle korunuyor: %',t;
        end;
      else
        raise notice 'Legacy aday tablo boş değil; korunuyor: % (% kayıt)',t,n;
      end if;
    end if;
  end loop;
end $$;

-- --------------------------------------------------------------------------
-- 7) Pazaryeri varsayılan kanalları
-- --------------------------------------------------------------------------
insert into public.erp_pazaryeri_kanallari(kanal_kodu,kanal_adi,aktif)
values
 ('TRENDYOL','Trendyol',false),
 ('HEPSIBURADA','Hepsiburada',false),
 ('N11','n11',false),
 ('AMAZON_TR','Amazon Türkiye',false),
 ('WEB','Web Sitesi',false)
on conflict (kanal_kodu) do nothing;

commit;

-- --------------------------------------------------------------------------
-- 8) SON KONTROL (salt-okuma)
-- --------------------------------------------------------------------------
select 'schema_version' as kontrol, surum as sonuc from public.erp_schema_surumu where id=1
union all
select 'duplicate_chassis', count(*)::text
from (
  select upper(trim(sase))
  from public.erp_arac_katalog_araclar
  where nullif(trim(sase),'') is not null
  group by upper(trim(sase)) having count(*)>1
) x
union all
select 'marketplace_channels', count(*)::text from public.erp_pazaryeri_kanallari;
-- PRO-ERP 2.5.2 - Test hareketleri temizlendikten sonra kalan özet alanlarını onarır.
-- Veri olan kartlara dokunmaz; yalnız ilgili hareketi hiç olmayan kartların eski özetini sıfırlar.
BEGIN;

UPDATE public.cariler c
SET bakiye = 0
WHERE COALESCE(c.bakiye,0) <> 0
  AND NOT EXISTS (
    SELECT 1 FROM public.cari_hareket h WHERE h.cari_id = c.cari_id
  );

UPDATE public.stoklar s
SET stok_miktari = 0
WHERE COALESCE(s.stok_miktari,0) <> 0
  AND NOT EXISTS (
    SELECT 1 FROM public.stok_hareket h WHERE h.stok_id = s.stok_id
  );

-- Rapor ve kokpit sorgularının en sık kullandığı alanlar.
CREATE INDEX IF NOT EXISTS idx_stok_hareket_stok_id ON public.stok_hareket(stok_id);
CREATE INDEX IF NOT EXISTS idx_cari_hareket_cari_id ON public.cari_hareket(cari_id);
CREATE INDEX IF NOT EXISTS idx_satis_detay_stok_id ON public.satis_detay(stok_id);
CREATE INDEX IF NOT EXISTS idx_alis_detay_stok_id ON public.alis_detay(stok_id);
CREATE INDEX IF NOT EXISTS idx_satis_baslik_tarih ON public.satis_baslik(tarih);
CREATE INDEX IF NOT EXISTS idx_alis_baslik_tarih ON public.alis_baslik(tarih);

COMMIT;

SELECT
  (SELECT count(*) FROM public.cariler WHERE COALESCE(bakiye,0) <> 0) AS bakiyesi_kalan_cari,
  (SELECT count(*) FROM public.stoklar WHERE COALESCE(stok_miktari,0) <> 0) AS miktari_kalan_stok,
  (SELECT count(*) FROM public.cari_hareket) AS cari_hareket,
  (SELECT count(*) FROM public.stok_hareket) AS stok_hareket;
