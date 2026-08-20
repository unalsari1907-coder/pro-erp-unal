-- PRO-ERP live Supabase view snapshot - 2026-08-13

CREATE OR REPLACE VIEW public.erp_arac_katalog_v AS
 SELECT a.arac_id,
    a.yillar,
    a.uretici,
    a.yil,
    a.model,
    a.motor,
    a.yakit,
    a.motor_kodu,
    a.sase,
    a.notlar,
    a.arac_sahibi,
    p.parca_id,
    p.kategori_kodu,
    p.kategori_adi,
    p.oem_kodu,
    p.ham_deger,
    p.nitelik,
    p.sira
   FROM (erp_arac_katalog_araclar a
     LEFT JOIN erp_arac_katalog_parcalar p ON ((p.arac_id = a.arac_id)));

CREATE OR REPLACE VIEW public.erp_kasa_bakiye_ozet AS
 SELECT k.kasa_id,
    k.kasa_adi,
    (COALESCE(sum(
        CASE
            WHEN (upper(replace((COALESCE(h.tip, ''::character varying))::text, 'İ'::text, 'I'::text)) = ANY (ARRAY['GIRIS'::text, 'TAHSILAT'::text, 'VIRMAN_GIRIS'::text, 'TRANSFER_GIRIS'::text])) THEN COALESCE(h.tutar, (0)::numeric)
            ELSE (- COALESCE(h.tutar, (0)::numeric))
        END), (0)::numeric))::numeric(18,2) AS bakiye
   FROM (kasalar k
     LEFT JOIN kasa_hareket h ON ((h.kasa_id = k.kasa_id)))
  GROUP BY k.kasa_id, k.kasa_adi;

CREATE OR REPLACE VIEW public.erp_mizan AS
 SELECT s.hesap_kodu,
    COALESCE(h.hesap_adi, '-'::text) AS hesap_adi,
    COALESCE(h.hesap_tipi, '-'::text) AS hesap_tipi,
    (COALESCE(sum(s.borc), (0)::numeric))::numeric(18,2) AS borc,
    (COALESCE(sum(s.alacak), (0)::numeric))::numeric(18,2) AS alacak,
    ((COALESCE(sum(s.borc), (0)::numeric) - COALESCE(sum(s.alacak), (0)::numeric)))::numeric(18,2) AS bakiye
   FROM (erp_muhasebe_fis_satirlari s
     LEFT JOIN erp_hesap_plani h ON ((h.hesap_kodu = s.hesap_kodu)))
  GROUP BY s.hesap_kodu, h.hesap_adi, h.hesap_tipi;

CREATE OR REPLACE VIEW public.erp_vade_takip AS
 SELECT 'SATIS'::text AS belge_tipi,
    s.satis_id AS belge_id,
    s.cari_id,
    COALESCE(c.unvan, '-'::character varying) AS cari_unvan,
    s.fatura_no,
    s.tarih,
    s.vade_tarihi,
    COALESCE(s.genel_toplam, s.toplam_tutar, (0)::numeric) AS genel_toplam,
    COALESCE(s.odenen_tutar, (0)::numeric) AS odenen_tutar,
    GREATEST((COALESCE(s.genel_toplam, s.toplam_tutar, (0)::numeric) - COALESCE(s.odenen_tutar, (0)::numeric)), (0)::numeric) AS kalan_tutar,
    GREATEST((CURRENT_DATE - s.vade_tarihi), 0) AS gecikme_gun,
    'ALACAK'::text AS yon,
    s.durum
   FROM (satis_baslik s
     LEFT JOIN cariler c ON ((c.cari_id = s.cari_id)))
  WHERE ((COALESCE(upper((s.durum)::text), ''::text) <> ALL (ARRAY['IPTAL'::text, 'İPTAL'::text])) AND (GREATEST((COALESCE(s.genel_toplam, s.toplam_tutar, (0)::numeric) - COALESCE(s.odenen_tutar, (0)::numeric)), (0)::numeric) > (0)::numeric))
UNION ALL
 SELECT 'ALIS'::text AS belge_tipi,
    a.alis_id AS belge_id,
    a.cari_id,
    COALESCE(c.unvan, '-'::character varying) AS cari_unvan,
    a.fatura_no,
    a.tarih,
    a.vade_tarihi,
    COALESCE(a.genel_toplam, a.toplam_tutar, (0)::numeric) AS genel_toplam,
    COALESCE(a.odenen_tutar, (0)::numeric) AS odenen_tutar,
    GREATEST((COALESCE(a.genel_toplam, a.toplam_tutar, (0)::numeric) - COALESCE(a.odenen_tutar, (0)::numeric)), (0)::numeric) AS kalan_tutar,
    GREATEST((CURRENT_DATE - a.vade_tarihi), 0) AS gecikme_gun,
    'BORC'::text AS yon,
    a.durum
   FROM (alis_baslik a
     LEFT JOIN cariler c ON ((c.cari_id = a.cari_id)))
  WHERE ((COALESCE(upper((a.durum)::text), ''::text) <> ALL (ARRAY['IPTAL'::text, 'İPTAL'::text])) AND (GREATEST((COALESCE(a.genel_toplam, a.toplam_tutar, (0)::numeric) - COALESCE(a.odenen_tutar, (0)::numeric)), (0)::numeric) > (0)::numeric));

CREATE OR REPLACE VIEW public.v_kritik_stok_siparis_oneri AS
 WITH normal_stok AS (
         SELECT v_pro_stok_depo_durumu.stok_id,
            COALESCE(sum(v_pro_stok_depo_durumu.miktar), (0)::numeric) AS mevcut_stok
           FROM v_pro_stok_depo_durumu
          WHERE (upper(COALESCE(v_pro_stok_depo_durumu.depo_tipi, ''::text)) = 'NORMAL'::text)
          GROUP BY v_pro_stok_depo_durumu.stok_id
        )
 SELECT s.stok_id,
    s.urun_adi,
    s.uretici_kodu,
    s.oem_no,
    s.marka,
    s.model,
    s.grup,
    s.raf,
    COALESCE(n.mevcut_stok, (0)::numeric) AS mevcut_stok,
    COALESCE(s.min_stok, (0)::numeric) AS min_stok,
    GREATEST((COALESCE(s.min_stok, (0)::numeric) - COALESCE(n.mevcut_stok, (0)::numeric)), (0)::numeric) AS eksik_miktar,
    GREATEST(((COALESCE(s.min_stok, (0)::numeric) * (2)::numeric) - COALESCE(n.mevcut_stok, (0)::numeric)), (COALESCE(s.min_stok, (0)::numeric) - COALESCE(n.mevcut_stok, (0)::numeric)), (0)::numeric) AS onerilen_siparis,
    s.alis_fiyati
   FROM (stoklar s
     LEFT JOIN normal_stok n ON ((n.stok_id = s.stok_id)))
  WHERE (((s.aktif IS NULL) OR (lower(TRIM(BOTH FROM s.aktif)) = ANY (ARRAY['true'::text, 't'::text, '1'::text, 'evet'::text, 'aktif'::text]))) AND (COALESCE(s.min_stok, (0)::numeric) > (0)::numeric) AND (COALESCE(n.mevcut_stok, (0)::numeric) <= COALESCE(s.min_stok, (0)::numeric)));

CREATE OR REPLACE VIEW public.v_pro_stok_depo_durumu AS
 WITH hareket_ozet AS (
         SELECT h.stok_id,
            h.depo_id,
            (sum(
                CASE
                    WHEN (upper(COALESCE(h.hareket_tipi, ''::text)) = ANY (ARRAY['GIRIS'::text, 'GİRİŞ'::text])) THEN abs(COALESCE(h.miktar, 0))
                    WHEN (upper(COALESCE(h.hareket_tipi, ''::text)) = ANY (ARRAY['CIKIS'::text, 'ÇIKIŞ'::text])) THEN (- abs(COALESCE(h.miktar, 0)))
                    WHEN ((upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ 'ALIS%'::text) OR (upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ 'ALIŞ%'::text)) THEN
                    CASE
                        WHEN ((upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ '%IPTAL%'::text) OR (upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ '%İPTAL%'::text)) THEN (- abs(COALESCE(h.miktar, 0)))
                        ELSE abs(COALESCE(h.miktar, 0))
                    END
                    WHEN ((upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ 'SATIS%'::text) OR (upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ 'SATIŞ%'::text)) THEN
                    CASE
                        WHEN ((upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ '%IPTAL%'::text) OR (upper((COALESCE(h.islem_tipi, ''::character varying))::text) ~~ '%İPTAL%'::text)) THEN abs(COALESCE(h.miktar, 0))
                        ELSE (- abs(COALESCE(h.miktar, 0)))
                    END
                    ELSE 0
                END))::numeric AS miktar
           FROM stok_hareket h
          WHERE ((h.stok_id IS NOT NULL) AND (h.depo_id IS NOT NULL))
          GROUP BY h.stok_id, h.depo_id
        ), ilk_normal_depo AS (
         SELECT d_1.depo_id
           FROM depolar d_1
          WHERE ((COALESCE(d_1.aktif, true) = true) AND (upper(COALESCE(d_1.depo_tipi, 'NORMAL'::text)) = 'NORMAL'::text))
          ORDER BY d_1.depo_id
         LIMIT 1
        ), legacy_stok AS (
         SELECT s_1.stok_id,
            nd.depo_id,
            COALESCE(s_1.stok_miktari, (0)::numeric) AS miktar
           FROM (stoklar s_1
             CROSS JOIN ilk_normal_depo nd)
          WHERE ((NOT (EXISTS ( SELECT 1
                   FROM stok_hareket h
                  WHERE (h.stok_id = s_1.stok_id)))) AND (COALESCE(s_1.stok_miktari, (0)::numeric) <> (0)::numeric))
        ), birlesik AS (
         SELECT hareket_ozet.stok_id,
            hareket_ozet.depo_id,
            hareket_ozet.miktar
           FROM hareket_ozet
        UNION ALL
         SELECT legacy_stok.stok_id,
            legacy_stok.depo_id,
            legacy_stok.miktar
           FROM legacy_stok
        )
 SELECT b.stok_id,
    b.depo_id,
    d.depo_kodu,
    d.depo_adi,
    upper(COALESCE(d.depo_tipi, 'NORMAL'::text)) AS depo_tipi,
    s.urun_adi,
    s.uretici_kodu,
    s.oem_no,
    s.marka,
    s.raf,
    b.miktar
   FROM ((birlesik b
     JOIN stoklar s ON ((s.stok_id = b.stok_id)))
     JOIN depolar d ON ((d.depo_id = b.depo_id)));

CREATE OR REPLACE VIEW public.v_stok_depo_durumu AS
 SELECT sdb.stok_id,
    s.urun_adi,
    s.uretici_kodu,
    sdb.depo_id,
    d.depo_kodu,
    d.depo_adi,
    d.depo_tipi,
    d.satilabilir,
    sdb.miktar,
    sdb.rezerve_miktar,
    GREATEST((sdb.miktar - sdb.rezerve_miktar), (0)::numeric) AS kullanilabilir_miktar,
    sdb.son_guncelleme
   FROM ((stok_depo_bakiye sdb
     JOIN stoklar s ON ((s.stok_id = sdb.stok_id)))
     JOIN depolar d ON ((d.depo_id = sdb.depo_id)));

CREATE OR REPLACE VIEW public.v_stok_ozet AS
 SELECT s.stok_id,
    s.urun_adi,
    s.uretici_kodu,
    COALESCE(sum(sdb.miktar), (0)::numeric) AS fiziksel_toplam_stok,
    COALESCE(sum(
        CASE
            WHEN ((d.satilabilir = true) AND (d.aktif = true)) THEN GREATEST((sdb.miktar - sdb.rezerve_miktar), (0)::numeric)
            ELSE (0)::numeric
        END), (0)::numeric) AS satilabilir_stok,
    COALESCE(sum(
        CASE
            WHEN (d.depo_tipi = 'IADE'::text) THEN sdb.miktar
            ELSE (0)::numeric
        END), (0)::numeric) AS iade_bekleyen_stok,
    COALESCE(sum(
        CASE
            WHEN (d.depo_tipi = 'HASARLI'::text) THEN sdb.miktar
            ELSE (0)::numeric
        END), (0)::numeric) AS hasarli_stok
   FROM ((stoklar s
     LEFT JOIN stok_depo_bakiye sdb ON ((sdb.stok_id = s.stok_id)))
     LEFT JOIN depolar d ON ((d.depo_id = sdb.depo_id)))
  GROUP BY s.stok_id, s.urun_adi, s.uretici_kodu;
