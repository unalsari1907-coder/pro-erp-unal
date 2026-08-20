-- PRO-ERP live Supabase function snapshot - 2026-08-13
-- Reference source. Existing live database was the source of truth.

-- aktif_fiyat_politikasi()
CREATE OR REPLACE FUNCTION public.aktif_fiyat_politikasi()
 RETURNS TABLE(sfp_orani numeric, sft_orani numeric, sfl_orani numeric, sfi_orani numeric)
 LANGUAGE sql
 STABLE
 SET search_path TO 'public'
AS $function$
    SELECT
        fp.sfp_orani,
        fp.sft_orani,
        fp.sfl_orani,
        fp.sfi_orani
    FROM public.fiyat_politikalari AS fp
    WHERE fp.aktif = true
    ORDER BY fp.politika_id
    LIMIT 1;
$function$;

-- alis_fatura_irsaliye_aktar(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_depo_id bigint, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.alis_fatura_irsaliye_aktar(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_depo_id bigint, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item jsonb;
    v_irsaliye_id bigint;
    v_irsaliye_detay_id bigint;
    v_stok_id bigint;
    v_miktar integer;
    v_birim_fiyat numeric;
    v_indirim numeric;
    v_kdv_orani integer;
    v_detay public.alis_irsaliye_detay%ROWTYPE;
    v_baslik public.alis_irsaliye_baslik%ROWTYPE;
    v_alis_detaylari jsonb := '[]'::jsonb;
    v_alis_id bigint;
    v_kalan_toplam numeric;
BEGIN
    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION 'Tedarikçi / cari seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION 'Depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION 'Faturaya aktarılacak alış irsaliye kalemi yok.';
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_irsaliye_id :=
            nullif(v_item->>'irsaliye_id', '')::bigint;
        v_irsaliye_detay_id :=
            nullif(v_item->>'irsaliye_detay_id', '')::bigint;
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;
        v_miktar :=
            coalesce(nullif(v_item->>'miktar', '')::integer, 0);
        v_birim_fiyat :=
            coalesce(nullif(v_item->>'birim_fiyat', '')::numeric, 0);
        v_indirim :=
            coalesce(nullif(v_item->>'indirim', '')::numeric, 0);
        v_kdv_orani :=
            coalesce(nullif(v_item->>'kdv_orani', '')::integer, 0);

        IF v_irsaliye_id IS NULL OR
           v_irsaliye_detay_id IS NULL THEN
            RAISE EXCEPTION
                'Her fatura satırı kaynak alış irsaliyesine bağlı olmalıdır.';
        END IF;

        SELECT *
        INTO v_baslik
        FROM public.alis_irsaliye_baslik
        WHERE irsaliye_id = v_irsaliye_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Alış irsaliyesi bulunamadı. ID: %',
                v_irsaliye_id;
        END IF;

        IF v_baslik.cari_id <> p_cari_id
           OR v_baslik.depo_id <> p_depo_id THEN
            RAISE EXCEPTION
                'İrsaliye tedarikçi/depo bilgisi faturayla uyuşmuyor. İrsaliye: %',
                v_baslik.irsaliye_no;
        END IF;

        IF upper(coalesce(v_baslik.durum, '')) <> 'ONAYLANDI' THEN
            RAISE EXCEPTION
                'Yalnızca ONAYLANDI alış irsaliyesi faturalanabilir. İrsaliye: %, Durum: %',
                v_baslik.irsaliye_no,
                v_baslik.durum;
        END IF;

        SELECT *
        INTO v_detay
        FROM public.alis_irsaliye_detay
        WHERE detay_id = v_irsaliye_detay_id
          AND irsaliye_id = v_irsaliye_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Alış irsaliye kalemi bulunamadı. Detay ID: %',
                v_irsaliye_detay_id;
        END IF;

        IF v_detay.stok_id <> v_stok_id THEN
            RAISE EXCEPTION
                'İrsaliye kalemi ile stok kartı uyuşmuyor.';
        END IF;

        IF v_miktar <= 0 OR
           v_miktar > v_detay.kalan_miktar THEN
            RAISE EXCEPTION
                'Fatura miktarı kalan irsaliye miktarını aşamaz.';
        END IF;

        v_alis_detaylari :=
            v_alis_detaylari ||
            jsonb_build_array(
                jsonb_build_object(
                    'stok_id', v_stok_id,
                    'miktar', v_miktar,
                    'birim_fiyat', v_birim_fiyat,
                    'indirim', v_indirim,
                    'kdv_orani', v_kdv_orani
                )
            );
    END LOOP;

    v_alis_id := public.alis_olustur(
        p_cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        p_depo_id,
        p_kullanici,
        v_alis_detaylari
    );

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_irsaliye_id :=
            (v_item->>'irsaliye_id')::bigint;
        v_irsaliye_detay_id :=
            (v_item->>'irsaliye_detay_id')::bigint;
        v_stok_id :=
            (v_item->>'stok_id')::bigint;
        v_miktar :=
            (v_item->>'miktar')::integer;

        UPDATE public.stoklar
        SET stok_miktari =
            coalesce(stok_miktari, 0) - v_miktar
        WHERE stok_id = v_stok_id;

        UPDATE public.alis_irsaliye_detay
        SET
            faturalanan_miktar =
                faturalanan_miktar + v_miktar,
            durum = CASE
                WHEN faturalanan_miktar + v_miktar >= miktar
                    THEN 'FATURALANDI'
                ELSE 'KISMI_FATURALANDI'
            END,
            guncelleme_tarihi = now()
        WHERE detay_id = v_irsaliye_detay_id
          AND irsaliye_id = v_irsaliye_id;

        INSERT INTO public.alis_irsaliye_fatura (
            irsaliye_id,
            alis_id,
            tarih,
            kullanici,
            aciklama
        )
        VALUES (
            v_irsaliye_id,
            v_alis_id,
            now(),
            p_kullanici,
            'Alış faturası ekranından İrsaliye Aktar ile faturalandı.'
        )
        ON CONFLICT (irsaliye_id, alis_id)
        DO NOTHING;
    END LOOP;

    FOR v_irsaliye_id IN
        SELECT DISTINCT
            (value->>'irsaliye_id')::bigint
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        SELECT coalesce(sum(kalan_miktar), 0)
        INTO v_kalan_toplam
        FROM public.alis_irsaliye_detay
        WHERE irsaliye_id = v_irsaliye_id
          AND durum <> 'IPTAL';

        UPDATE public.alis_irsaliye_baslik
        SET
            durum = CASE
                WHEN v_kalan_toplam <= 0
                    THEN 'FATURALANDI'
                ELSE 'ONAYLANDI'
            END,
            guncelleme_tarihi = now()
        WHERE irsaliye_id = v_irsaliye_id;
    END LOOP;

    DELETE FROM public.stok_hareket
    WHERE alis_ref = v_alis_id
      AND upper(coalesce(islem_tipi, ''))
          IN ('ALIS', 'ALIŞ');

    RETURN v_alis_id;
END;
$function$;

-- alis_faturasi_iptal_et(p_alis_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.alis_faturasi_iptal_et(p_alis_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_cari_id bigint;
    v_kasa_id bigint;
    v_depo_id bigint;

    v_fatura_no text;
    v_odeme_tipi text;
    v_durum text;

    v_genel_toplam numeric := 0;
    v_veresiye boolean := false;

    v_detay record;

    v_onceki_stok integer;
    v_sonraki_stok integer;
BEGIN
    ------------------------------------------------------
    -- ALIŞ BAŞLIĞINI KİLİTLE VE KONTROL ET
    ------------------------------------------------------

    SELECT
        ab.cari_id,
        ab.kasa_id,
        ab.depo_id,
        ab.fatura_no,
        ab.odeme_tipi,
        ab.durum,
        COALESCE(ab.genel_toplam, 0)
    INTO
        v_cari_id,
        v_kasa_id,
        v_depo_id,
        v_fatura_no,
        v_odeme_tipi,
        v_durum,
        v_genel_toplam
    FROM public.alis_baslik AS ab
    WHERE ab.alis_id = p_alis_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Alış faturası bulunamadı. Alış ID: %',
            p_alis_id;
    END IF;

    IF UPPER(COALESCE(v_durum, '')) IN ('IPTAL', 'İPTAL') THEN
        RAISE EXCEPTION
            'Bu alış faturası daha önce iptal edilmiş.';
    END IF;

    v_veresiye :=
        LOWER(TRIM(COALESCE(v_odeme_tipi, ''))) IN
        ('veresiye', 'hesap');

    ------------------------------------------------------
    -- ALINAN ÜRÜNLERİ STOKTAN GERİ DÜŞ
    ------------------------------------------------------

    FOR v_detay IN
        SELECT
            ad.stok_id,
            COALESCE(ad.miktar, 0)::integer AS miktar,
            COALESCE(ad.birim_fiyat, 0) AS birim_fiyat
        FROM public.alis_detay AS ad
        WHERE ad.alis_id = p_alis_id
        ORDER BY ad.stok_id
    LOOP
        SELECT
            COALESCE(s.stok_miktari, 0)::integer
        INTO
            v_onceki_stok
        FROM public.stoklar AS s
        WHERE s.stok_id = v_detay.stok_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_detay.stok_id;
        END IF;

        IF v_onceki_stok < v_detay.miktar THEN
            RAISE EXCEPTION
                'Alış faturası iptal edilemiyor. '
                'Stok yetersiz. Stok ID: %, Mevcut: %, '
                'İptal edilecek: %',
                v_detay.stok_id,
                v_onceki_stok,
                v_detay.miktar;
        END IF;

        v_sonraki_stok :=
            v_onceki_stok - v_detay.miktar;

        UPDATE public.stoklar
        SET stok_miktari = v_sonraki_stok
        WHERE stok_id = v_detay.stok_id;

        INSERT INTO public.stok_hareket
        (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            miktar,
            belge_no,
            aciklama,
            depo_id,
            cari_id,
            alis_ref,
            fatura_no,
            onceki_stok,
            sonraki_stok,
            birim_maliyet,
            hareket_tipi
        )
        VALUES
        (
            NOW(),
            p_kullanici,
            v_detay.stok_id,
            'ALIS_IPTAL',
            v_detay.miktar,
            v_fatura_no,
            'Alış faturası iptali',
            v_depo_id,
            v_cari_id,
            p_alis_id,
            v_fatura_no,
            v_onceki_stok,
            v_sonraki_stok,
            v_detay.birim_fiyat,
            'CIKIS'
        );
    END LOOP;

    ------------------------------------------------------
    -- TEDARİKÇİ ALIŞ HAREKETİNİ TERS KAYITLA KAPAT
    ------------------------------------------------------

    INSERT INTO public.cari_hareket
    (
        tarih,
        cari_id,
        islem_tipi,
        belge_no,
        borc,
        alacak,
        aciklama,
        kullanici
    )
    VALUES
    (
        NOW(),
        v_cari_id,
        'ALIS_IPTAL',
        v_fatura_no,
        v_genel_toplam,
        0,
        'Alış faturası iptal kaydı',
        p_kullanici
    );

    ------------------------------------------------------
    -- PEŞİN ALIŞTA ÖDEME VE KASAYI TERS ÇEVİR
    ------------------------------------------------------

    IF NOT v_veresiye THEN
        IF v_kasa_id IS NULL THEN
            RAISE EXCEPTION
                'Peşin alışın kasa bilgisi bulunamadı.';
        END IF;

        INSERT INTO public.cari_hareket
        (
            tarih,
            cari_id,
            islem_tipi,
            belge_no,
            borc,
            alacak,
            aciklama,
            kullanici
        )
        VALUES
        (
            NOW(),
            v_cari_id,
            'ODEME_IPTAL',
            v_fatura_no,
            0,
            v_genel_toplam,
            'Alış ödemesi iptal kaydı',
            p_kullanici
        );

        INSERT INTO public.kasa_hareket
        (
            tarih,
            tip,
            tutar,
            aciklama,
            cari_id,
            kullanici,
            kasa_id
        )
        VALUES
        (
            NOW(),
            'GIRIS',
            v_genel_toplam,
            'Alış faturası iptali - Fatura: '
                || COALESCE(v_fatura_no, ''),
            v_cari_id,
            p_kullanici,
            v_kasa_id
        );
    END IF;

    ------------------------------------------------------
    -- CARİ BAKİYESİNİ DÜZELT
    ------------------------------------------------------

    IF v_veresiye THEN
        UPDATE public.cariler
        SET bakiye =
            COALESCE(bakiye, 0) - v_genel_toplam
        WHERE cari_id = v_cari_id;
    END IF;

    ------------------------------------------------------
    -- FATURAYI İPTAL DURUMUNA GETİR
    ------------------------------------------------------

    UPDATE public.alis_baslik
    SET durum = 'IPTAL'
    WHERE alis_id = p_alis_id;
END;
$function$;

-- alis_finans_isle(p_alis_id bigint, p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_genel_toplam numeric, p_fatura_no text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.alis_finans_isle(p_alis_id bigint, p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_genel_toplam numeric, p_fatura_no text, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

    -- Cari Hareketi
    INSERT INTO cari_hareket
    (
        tarih,
        cari_id,
        islem_tipi,
        belge_no,
        borc,
        alacak,
        aciklama,
        kullanici
    )
    VALUES
    (
        now(),
        p_cari_id,
        'ALIS',
        p_fatura_no,
        p_genel_toplam,
        0,
        'Alış Faturası',
        p_kullanici
    );

    -- Cari Bakiyesi
    UPDATE cariler
    SET bakiye = COALESCE(bakiye,0) + p_genel_toplam
    WHERE cari_id = p_cari_id;

    -- Nakit / Kart ise kasa hareketi oluştur
    IF upper(COALESCE(p_odeme_tipi,'')) <> 'VERESIYE' THEN

        INSERT INTO kasa_hareket
        (
            tarih,
            tip,
            tutar,
            aciklama,
            cari_id,
            kullanici,
            kasa_id
        )
        VALUES
        (
            now(),
            'CIKIS',
            p_genel_toplam,
            'Alış Ödemesi',
            p_cari_id,
            p_kullanici,
            p_kasa_id
        );

    END IF;

END;
$function$;

-- alis_irsaliye_aktar_detay(p_irsaliye_ids bigint[])
CREATE OR REPLACE FUNCTION public.alis_irsaliye_aktar_detay(p_irsaliye_ids bigint[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
SELECT coalesce(
    jsonb_agg(
        jsonb_build_object(
            'detay_id',
                d.detay_id,
            'irsaliye_id',
                d.irsaliye_id,
            'irsaliye_no',
                b.irsaliye_no,
            'stok_id',
                d.stok_id,
            'miktar',
                d.miktar,
            'faturalanan_miktar',
                d.faturalanan_miktar,
            'kalan_miktar',
                d.kalan_miktar,
            'birim_fiyat',
                d.birim_fiyat,
            'indirim_orani',
                d.indirim_orani,
            'kdv_orani',
                d.kdv_orani,
            'stok',
                to_jsonb(s)
        )
        ORDER BY
            b.tarih,
            b.irsaliye_id,
            d.detay_id
    ),
    '[]'::jsonb
)
FROM public.alis_irsaliye_detay d
JOIN public.alis_irsaliye_baslik b
  ON b.irsaliye_id = d.irsaliye_id
JOIN public.stoklar s
  ON s.stok_id = d.stok_id
WHERE d.irsaliye_id = ANY(p_irsaliye_ids)
  AND b.durum = 'ONAYLANDI'
  AND d.kalan_miktar > 0
  AND d.durum <> 'IPTAL';
$function$;

-- alis_irsaliye_aktar_listesi(p_cari_id bigint, p_depo_id bigint, p_limit integer, p_offset integer)
CREATE OR REPLACE FUNCTION public.alis_irsaliye_aktar_listesi(p_cari_id bigint, p_depo_id bigint, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
WITH aday AS (
    SELECT
        b.irsaliye_id,
        b.irsaliye_no,
        b.tarih,
        count(d.detay_id) AS kalem_sayisi,
        coalesce(
            sum(d.kalan_miktar),
            0
        ) AS kalan_miktar
    FROM public.alis_irsaliye_baslik b
    JOIN public.alis_irsaliye_detay d
      ON d.irsaliye_id = b.irsaliye_id
     AND d.kalan_miktar > 0
     AND d.durum <> 'IPTAL'
    WHERE b.cari_id = p_cari_id
      AND b.depo_id = p_depo_id
      AND b.durum = 'ONAYLANDI'
    GROUP BY
        b.irsaliye_id,
        b.irsaliye_no,
        b.tarih
    ORDER BY
        b.tarih DESC,
        b.irsaliye_id DESC
    LIMIT greatest(1, least(p_limit, 100)) + 1
    OFFSET greatest(p_offset, 0)
),
sinirli AS (
    SELECT *
    FROM aday
    LIMIT greatest(1, least(p_limit, 100))
)
SELECT jsonb_build_object(
    'items',
    coalesce(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'irsaliye_id',
                        irsaliye_id,
                    'irsaliye_no',
                        irsaliye_no,
                    'tarih',
                        tarih,
                    'kalem_sayisi',
                        kalem_sayisi,
                    'kalan_miktar',
                        kalan_miktar
                )
                ORDER BY
                    tarih DESC,
                    irsaliye_id DESC
            )
            FROM sinirli
        ),
        '[]'::jsonb
    ),
    'has_more',
    (
        SELECT count(*)
        FROM aday
    ) > greatest(
        1,
        least(p_limit, 100)
    )
);
$function$;

-- alis_irsaliye_faturala(p_irsaliye_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_kullanici text, p_fatura_detaylari jsonb)
CREATE OR REPLACE FUNCTION public.alis_irsaliye_faturala(p_irsaliye_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_kullanici text, p_fatura_detaylari jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_baslik public.alis_irsaliye_baslik%ROWTYPE;
    v_detay public.alis_irsaliye_detay%ROWTYPE;
    v_item jsonb;
    v_detay_id bigint;
    v_miktar numeric;
    v_alis_id bigint;
    v_alis_detaylari jsonb := '[]'::jsonb;
    v_kalan_toplam numeric;
BEGIN
    SELECT *
    INTO v_baslik
    FROM public.alis_irsaliye_baslik
    WHERE irsaliye_id = p_irsaliye_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Alış irsaliyesi bulunamadı.';
    END IF;

    IF upper(v_baslik.durum) NOT IN ('ONAYLANDI', 'FATURALANDI') THEN
        RAISE EXCEPTION
            'Alış irsaliyesi faturalanabilir durumda değil. Durum: %',
            v_baslik.durum;
    END IF;

    IF p_fatura_detaylari IS NULL
       OR jsonb_typeof(p_fatura_detaylari) <> 'array'
       OR jsonb_array_length(p_fatura_detaylari) = 0 THEN
        RAISE EXCEPTION 'Faturalanacak kalemler boş olamaz.';
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_fatura_detaylari)
    LOOP
        v_detay_id := nullif(v_item->>'detay_id', '')::bigint;
        v_miktar := coalesce(nullif(v_item->>'miktar', '')::numeric, 0);

        SELECT *
        INTO v_detay
        FROM public.alis_irsaliye_detay
        WHERE detay_id = v_detay_id
          AND irsaliye_id = p_irsaliye_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Alış irsaliye kalemi bulunamadı. Detay ID: %', v_detay_id;
        END IF;

        IF v_miktar <= 0 OR v_miktar > v_detay.kalan_miktar THEN
            RAISE EXCEPTION
                'Fatura miktarı geçersiz. Detay ID: %, Kalan: %, İstenen: %',
                v_detay_id, v_detay.kalan_miktar, v_miktar;
        END IF;

        v_alis_detaylari :=
            v_alis_detaylari ||
            jsonb_build_array(
                jsonb_build_object(
                    'stok_id', v_detay.stok_id,
                    'miktar', v_miktar,
                    'birim_fiyat', v_detay.birim_fiyat,
                    'indirim', v_detay.indirim_orani,
                    'kdv_orani', ROUND(COALESCE(v_detay.kdv_orani, 0))::integer
                )
            );
    END LOOP;

    v_alis_id := public.alis_olustur(
        v_baslik.cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        v_baslik.depo_id,
        p_kullanici,
        v_alis_detaylari
    );

    -- İrsaliye onayında stok zaten artmıştı.
    -- Fatura fonksiyonunun ikinci stok artışını geri al.
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_fatura_detaylari)
    LOOP
        v_detay_id := nullif(v_item->>'detay_id', '')::bigint;
        v_miktar := coalesce(nullif(v_item->>'miktar', '')::numeric, 0);

        SELECT *
        INTO v_detay
        FROM public.alis_irsaliye_detay
        WHERE detay_id = v_detay_id
          AND irsaliye_id = p_irsaliye_id
        FOR UPDATE;

        UPDATE public.stoklar
        SET stok_miktari = stok_miktari - v_miktar
        WHERE stok_id = v_detay.stok_id;

        UPDATE public.alis_irsaliye_detay
        SET
            faturalanan_miktar = faturalanan_miktar + v_miktar,
            durum = CASE
                WHEN faturalanan_miktar + v_miktar >= miktar
                    THEN 'FATURALANDI'
                ELSE 'KISMI_FATURALANDI'
            END
        WHERE detay_id = v_detay_id;
    END LOOP;

    DELETE FROM public.stok_hareket
    WHERE alis_ref = v_alis_id
      AND upper(coalesce(islem_tipi, '')) IN ('ALIS', 'ALIŞ');

    INSERT INTO public.alis_irsaliye_fatura (
        irsaliye_id, alis_id, tarih, kullanici, aciklama
    )
    VALUES (
        p_irsaliye_id, v_alis_id, now(), p_kullanici,
        'Alış irsaliyesinden fatura oluşturuldu.'
    );

    SELECT coalesce(sum(kalan_miktar), 0)
    INTO v_kalan_toplam
    FROM public.alis_irsaliye_detay
    WHERE irsaliye_id = p_irsaliye_id
      AND durum <> 'IPTAL';

    UPDATE public.alis_irsaliye_baslik
    SET durum = CASE
        WHEN v_kalan_toplam <= 0 THEN 'FATURALANDI'
        ELSE 'ONAYLANDI'
    END
    WHERE irsaliye_id = p_irsaliye_id;

    RETURN v_alis_id;
END;
$function$;

-- alis_irsaliye_guncelle(p_irsaliye_id bigint, p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.alis_irsaliye_guncelle(p_irsaliye_id bigint, p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_durum text;
    v_item jsonb;
    v_stok_id bigint;
    v_miktar numeric;
    v_birim_fiyat numeric;
    v_indirim_orani numeric;
    v_kdv_orani numeric;
    v_siparis_detay_id bigint;
BEGIN
    SELECT upper(coalesce(durum, ''))
    INTO v_durum
    FROM public.alis_irsaliye_baslik
    WHERE irsaliye_id = p_irsaliye_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Alış irsaliyesi bulunamadı. ID: %', p_irsaliye_id;
    END IF;

    IF v_durum <> 'HAZIRLANIYOR' THEN
        RAISE EXCEPTION
            'Sadece HAZIRLANIYOR durumundaki alış irsaliyesi düzeltilebilir. Mevcut durum: %',
            v_durum;
    END IF;

    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION 'Tedarikçi / cari seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION 'Depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION 'İrsaliyede en az bir ürün bulunmalıdır.';
    END IF;

    UPDATE public.alis_irsaliye_baslik
    SET
        irsaliye_no = nullif(trim(p_irsaliye_no), ''),
        cari_id = p_cari_id,
        depo_id = p_depo_id,
        aciklama = nullif(trim(coalesce(p_aciklama, '')), ''),
        kullanici = nullif(trim(coalesce(p_kullanici, '')), ''),
        guncelleme_tarihi = now()
    WHERE irsaliye_id = p_irsaliye_id;

    DELETE FROM public.alis_irsaliye_detay
    WHERE irsaliye_id = p_irsaliye_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::numeric,
                0
            );

        v_siparis_detay_id :=
            nullif(
                v_item->>'siparis_detay_id',
                ''
            )::bigint;

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION 'Geçersiz stok ID.';
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'Miktar sıfırdan büyük olmalıdır. Stok ID: %',
                v_stok_id;
        END IF;

        INSERT INTO public.alis_irsaliye_detay (
            irsaliye_id,
            stok_id,
            siparis_detay_id,
            miktar,
            faturalanan_miktar,
            birim_fiyat,
            indirim_orani,
            kdv_orani,
            aciklama,
            durum
        )
        VALUES (
            p_irsaliye_id,
            v_stok_id,
            v_siparis_detay_id,
            v_miktar,
            0,
            v_birim_fiyat,
            v_indirim_orani,
            v_kdv_orani,
            nullif(
                trim(
                    coalesce(
                        v_item->>'aciklama',
                        ''
                    )
                ),
                ''
            ),
            'BEKLIYOR'
        );
    END LOOP;

    RETURN p_irsaliye_id;
END;
$function$;

-- alis_irsaliye_iptal_et(p_irsaliye_id bigint, p_kullanici text, p_aciklama text)
CREATE OR REPLACE FUNCTION public.alis_irsaliye_iptal_et(p_irsaliye_id bigint, p_kullanici text, p_aciklama text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.alis_irsaliye_baslik
    SET
        durum = 'IPTAL',
        iptal_tarihi = now(),
        iptal_kullanici = p_kullanici,
        iptal_aciklama =
            nullif(trim(coalesce(p_aciklama, '')), '')
    WHERE irsaliye_id = p_irsaliye_id
      AND durum = 'HAZIRLANIYOR';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Alış irsaliyesi bulunamadı veya iptal edilebilir durumda değil.';
    END IF;

    UPDATE public.alis_irsaliye_detay
    SET durum = 'IPTAL'
    WHERE irsaliye_id = p_irsaliye_id;
END;
$function$;

-- alis_irsaliye_olustur(p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_siparis_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.alis_irsaliye_olustur(p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_siparis_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_irsaliye_id bigint;
    v_irsaliye_no text;
    v_item jsonb;
    v_stok_id bigint;
    v_miktar numeric;
    v_birim_fiyat numeric;
    v_indirim_orani numeric;
    v_kdv_orani numeric;
    v_siparis_detay_id bigint;
BEGIN
    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION 'Alış irsaliyesi için tedarikçi seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION 'Alış irsaliyesi için depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION 'Alış irsaliyesi kalemleri boş olamaz.';
    END IF;

    v_irsaliye_no :=
        nullif(trim(coalesce(p_irsaliye_no, '')), '');

    IF v_irsaliye_no IS NULL THEN
        v_irsaliye_no := public.yeni_alis_irsaliye_no();
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.alis_irsaliye_baslik
        WHERE upper(trim(irsaliye_no)) =
              upper(trim(v_irsaliye_no))
    ) THEN
        RAISE EXCEPTION
            'Bu alış irsaliye numarası daha önce kullanılmış: %',
            v_irsaliye_no;
    END IF;

    INSERT INTO public.alis_irsaliye_baslik (
        irsaliye_no,
        tarih,
        cari_id,
        depo_id,
        siparis_id,
        durum,
        aciklama,
        kullanici
    )
    VALUES (
        v_irsaliye_no,
        now(),
        p_cari_id,
        p_depo_id,
        p_siparis_id,
        'HAZIRLANIYOR',
        nullif(trim(coalesce(p_aciklama, '')), ''),
        p_kullanici
    )
    RETURNING irsaliye_id
    INTO v_irsaliye_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(nullif(v_item->>'miktar', '')::numeric, 0);

        v_birim_fiyat :=
            coalesce(nullif(v_item->>'birim_fiyat', '')::numeric, 0);

        v_indirim_orani :=
            coalesce(nullif(v_item->>'indirim', '')::numeric, 0);

        v_kdv_orani :=
            coalesce(nullif(v_item->>'kdv_orani', '')::numeric, 0);

        v_siparis_detay_id :=
            nullif(v_item->>'siparis_detay_id', '')::bigint;

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION 'Geçersiz stok ID.';
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'İrsaliye miktarı sıfırdan büyük olmalıdır. Stok ID: %',
                v_stok_id;
        END IF;

        INSERT INTO public.alis_irsaliye_detay (
            irsaliye_id,
            stok_id,
            siparis_detay_id,
            miktar,
            birim_fiyat,
            indirim_orani,
            kdv_orani,
            aciklama,
            durum
        )
        VALUES (
            v_irsaliye_id,
            v_stok_id,
            v_siparis_detay_id,
            v_miktar,
            v_birim_fiyat,
            v_indirim_orani,
            v_kdv_orani,
            nullif(trim(coalesce(v_item->>'aciklama', '')), ''),
            'BEKLIYOR'
        );
    END LOOP;

    RETURN v_irsaliye_id;
END;
$function$;

-- alis_irsaliye_onayla(p_irsaliye_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.alis_irsaliye_onayla(p_irsaliye_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_baslik public.alis_irsaliye_baslik%ROWTYPE;
    v_detay public.alis_irsaliye_detay%ROWTYPE;
    v_onceki_stok numeric;
    v_sonraki_stok numeric;
BEGIN
    SELECT *
    INTO v_baslik
    FROM public.alis_irsaliye_baslik
    WHERE irsaliye_id = p_irsaliye_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Alış irsaliyesi bulunamadı.';
    END IF;

    IF upper(v_baslik.durum) <> 'HAZIRLANIYOR' THEN
        RAISE EXCEPTION
            'Alış irsaliyesi onaylanabilir durumda değil. Durum: %',
            v_baslik.durum;
    END IF;

    FOR v_detay IN
        SELECT *
        FROM public.alis_irsaliye_detay
        WHERE irsaliye_id = p_irsaliye_id
        ORDER BY detay_id
        FOR UPDATE
    LOOP
        SELECT coalesce(stok_miktari, 0)
        INTO v_onceki_stok
        FROM public.stoklar
        WHERE stok_id = v_detay.stok_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_detay.stok_id;
        END IF;

        UPDATE public.stoklar
        SET
            stok_miktari =
                coalesce(stok_miktari, 0) + v_detay.miktar,
            alis_fiyati = CASE
                WHEN v_detay.birim_fiyat > 0
                    THEN v_detay.birim_fiyat
                ELSE alis_fiyati
            END
        WHERE stok_id = v_detay.stok_id
        RETURNING stok_miktari
        INTO v_sonraki_stok;

        INSERT INTO public.stok_hareket (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            miktar,
            belge_no,
            aciklama,
            depo_id,
            cari_id,
            fatura_no,
            onceki_stok,
            sonraki_stok,
            birim_maliyet,
            hareket_tipi
        )
        VALUES (
            now(),
            p_kullanici,
            v_detay.stok_id,
            'ALIS_IRSALIYE',
            v_detay.miktar,
            v_baslik.irsaliye_no,
            'Alış irsaliyesi',
            v_baslik.depo_id,
            v_baslik.cari_id,
            NULL,
            v_onceki_stok,
            v_sonraki_stok,
            v_detay.birim_fiyat,
            'GIRIS'
        );
    END LOOP;

    UPDATE public.alis_irsaliye_baslik
    SET
        durum = 'ONAYLANDI',
        kabul_tarihi = now(),
        kullanici = coalesce(p_kullanici, kullanici)
    WHERE irsaliye_id = p_irsaliye_id;
END;
$function$;

-- alis_irsaliye_toplu_faturala(p_irsaliye_ids bigint[], p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.alis_irsaliye_toplu_faturala(p_irsaliye_ids bigint[], p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_kullanici text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_cari_id bigint;
    v_depo_id bigint;
    v_irsaliye_id bigint;
    v_detay public.alis_irsaliye_detay%ROWTYPE;
    v_alis_id bigint;
    v_alis_detaylari jsonb := '[]'::jsonb;
    v_kalan numeric;
BEGIN
    IF p_irsaliye_ids IS NULL
       OR array_length(p_irsaliye_ids, 1) IS NULL THEN
        RAISE EXCEPTION 'En az bir alış irsaliyesi seçilmelidir.';
    END IF;

    SELECT min(cari_id), min(depo_id)
    INTO v_cari_id, v_depo_id
    FROM public.alis_irsaliye_baslik
    WHERE irsaliye_id = ANY(p_irsaliye_ids);

    IF v_cari_id IS NULL OR v_depo_id IS NULL THEN
        RAISE EXCEPTION 'Seçilen alış irsaliyeleri bulunamadı.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.alis_irsaliye_baslik
        WHERE irsaliye_id = ANY(p_irsaliye_ids)
          AND (
              cari_id <> v_cari_id
              OR depo_id <> v_depo_id
              OR upper(coalesce(durum, '')) <> 'ONAYLANDI'
          )
    ) THEN
        RAISE EXCEPTION
            'Toplu alış faturasında tüm irsaliyelerin carisi ve deposu aynı, durumu ONAYLANDI olmalıdır.';
    END IF;

    IF (
        SELECT count(DISTINCT irsaliye_id)
        FROM public.alis_irsaliye_baslik
        WHERE irsaliye_id = ANY(p_irsaliye_ids)
    ) <> (
        SELECT count(DISTINCT x)
        FROM unnest(p_irsaliye_ids) AS x
    ) THEN
        RAISE EXCEPTION 'Seçilen alış irsaliyelerinden biri bulunamadı.';
    END IF;

    FOR v_irsaliye_id IN
        SELECT DISTINCT x
        FROM unnest(p_irsaliye_ids) AS x
        ORDER BY x
    LOOP
        PERFORM 1
        FROM public.alis_irsaliye_baslik
        WHERE irsaliye_id = v_irsaliye_id
        FOR UPDATE;

        FOR v_detay IN
            SELECT *
            FROM public.alis_irsaliye_detay
            WHERE irsaliye_id = v_irsaliye_id
              AND durum <> 'IPTAL'
              AND kalan_miktar > 0
            ORDER BY detay_id
            FOR UPDATE
        LOOP
            v_alis_detaylari :=
                v_alis_detaylari ||
                jsonb_build_array(
                    jsonb_build_object(
                        'stok_id', v_detay.stok_id,
                        'miktar', v_detay.kalan_miktar,
                        'birim_fiyat', v_detay.birim_fiyat,
                        'indirim', v_detay.indirim_orani,
                        'kdv_orani',
                            ROUND(COALESCE(v_detay.kdv_orani, 0))::integer
                    )
                );
        END LOOP;
    END LOOP;

    IF jsonb_array_length(v_alis_detaylari) = 0 THEN
        RAISE EXCEPTION
            'Seçilen alış irsaliyelerinde faturalanacak kalan kalem yok.';
    END IF;

    v_alis_id := public.alis_olustur(
        v_cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        v_depo_id,
        p_kullanici,
        v_alis_detaylari
    );

    -- alis_olustur stokları ikinci kez artırmıştı; geri al.
    FOR v_irsaliye_id IN
        SELECT DISTINCT x
        FROM unnest(p_irsaliye_ids) AS x
    LOOP
        FOR v_detay IN
            SELECT *
            FROM public.alis_irsaliye_detay
            WHERE irsaliye_id = v_irsaliye_id
              AND durum <> 'IPTAL'
              AND kalan_miktar > 0
            ORDER BY detay_id
            FOR UPDATE
        LOOP
            UPDATE public.stoklar
            SET stok_miktari =
                stok_miktari - v_detay.kalan_miktar
            WHERE stok_id = v_detay.stok_id;

            UPDATE public.alis_irsaliye_detay
            SET
                faturalanan_miktar = miktar,
                durum = 'FATURALANDI'
            WHERE detay_id = v_detay.detay_id;
        END LOOP;

        INSERT INTO public.alis_irsaliye_fatura (
            irsaliye_id,
            alis_id,
            tarih,
            kullanici,
            aciklama
        )
        VALUES (
            v_irsaliye_id,
            v_alis_id,
            now(),
            p_kullanici,
            'Toplu alış faturası oluşturuldu.'
        )
        ON CONFLICT (irsaliye_id, alis_id)
        DO NOTHING;

        SELECT coalesce(sum(kalan_miktar), 0)
        INTO v_kalan
        FROM public.alis_irsaliye_detay
        WHERE irsaliye_id = v_irsaliye_id
          AND durum <> 'IPTAL';

        UPDATE public.alis_irsaliye_baslik
        SET durum = CASE
            WHEN v_kalan <= 0
                THEN 'FATURALANDI'
            ELSE 'ONAYLANDI'
        END
        WHERE irsaliye_id = v_irsaliye_id;
    END LOOP;

    DELETE FROM public.stok_hareket
    WHERE alis_ref = v_alis_id
      AND upper(coalesce(islem_tipi, ''))
          IN ('ALIS', 'ALIŞ');

    RETURN v_alis_id;
END;
$function$;

-- alis_olustur(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_depo_id bigint, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.alis_olustur(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_depo_id bigint, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_alis_id bigint;

    v_item jsonb;
    v_stok_id bigint;
    v_miktar integer;
    v_birim_fiyat numeric;
    v_iskonto_orani numeric;
    v_kdv_orani integer;

    v_brut_tutar numeric;
    v_iskonto_tutari numeric;
    v_net_tutar numeric;
    v_kdv_tutari numeric;

    v_ara_toplam numeric := 0;
    v_toplam_iskonto numeric := 0;
    v_kdv_toplam numeric := 0;
    v_genel_toplam numeric := 0;

    v_onceki_stok integer;
    v_sonraki_stok integer;

    v_veresiye boolean;
BEGIN
    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION 'Tedarikçi seçilmedi.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION 'Depo seçilmedi.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION 'Alış kalemleri boş.';
    END IF;

    v_veresiye :=
        lower(trim(coalesce(p_odeme_tipi, ''))) IN
        ('veresiye', 'hesap');

    IF NOT v_veresiye AND p_kasa_id IS NULL THEN
        RAISE EXCEPTION
            'Nakit, kart veya havale işleminde kasa seçilmelidir.';
    END IF;

    ------------------------------------------------------
    -- TOPLAMLARI HESAPLA
    ------------------------------------------------------

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(nullif(v_item->>'miktar', '')::integer, 0);

        v_birim_fiyat :=
            coalesce(nullif(v_item->>'birim_fiyat', '')::numeric, 0);

        v_iskonto_orani :=
            coalesce(nullif(v_item->>'iskonto', '')::numeric, 0);

        v_kdv_orani :=
            coalesce(nullif(v_item->>'kdv_orani', '')::integer, 0);

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION 'Geçersiz stok ID.';
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'Miktar sıfırdan büyük olmalıdır. Stok: %',
                v_stok_id;
        END IF;

        IF v_birim_fiyat < 0 THEN
            RAISE EXCEPTION
                'Alış fiyatı negatif olamaz. Stok: %',
                v_stok_id;
        END IF;

        IF v_iskonto_orani < 0
           OR v_iskonto_orani > 100 THEN
            RAISE EXCEPTION
                'İskonto oranı 0 ile 100 arasında olmalıdır.';
        END IF;

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_iskonto_tutari :=
            v_brut_tutar * v_iskonto_orani / 100;

        v_net_tutar :=
            v_brut_tutar - v_iskonto_tutari;

        v_kdv_tutari :=
            v_net_tutar * v_kdv_orani / 100;

        v_ara_toplam :=
            v_ara_toplam + v_brut_tutar;

        v_toplam_iskonto :=
            v_toplam_iskonto + v_iskonto_tutari;

        v_kdv_toplam :=
            v_kdv_toplam + v_kdv_tutari;
    END LOOP;

    v_genel_toplam :=
        v_ara_toplam
        - v_toplam_iskonto
        + v_kdv_toplam;

    ------------------------------------------------------
    -- ALIŞ BAŞLIK
    ------------------------------------------------------

    INSERT INTO alis_baslik
    (
        fatura_no,
        tarih,
        cari_id,
        toplam_tutar,
        kdv_toplam,
        genel_toplam,
        durum,
        kullanici,
        depo_id,
        islem_tipi,
        belge_tipi,
        odeme_tipi,
        kasa_id
    )
    VALUES
    (
        nullif(trim(p_fatura_no), ''),
        now(),
        p_cari_id,
        v_ara_toplam - v_toplam_iskonto,
        v_kdv_toplam,
        v_genel_toplam,
        'ONAYLANDI',
        p_kullanici,
        p_depo_id,
        'ALIS',
        'FATURA',
        p_odeme_tipi,
        CASE
            WHEN v_veresiye THEN NULL
            ELSE p_kasa_id
        END
    )
    RETURNING alis_id
    INTO v_alis_id;

    ------------------------------------------------------
    -- DETAY, STOK VE STOK HAREKETLERİ
    ------------------------------------------------------

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(nullif(v_item->>'miktar', '')::integer, 0);

        v_birim_fiyat :=
            coalesce(nullif(v_item->>'birim_fiyat', '')::numeric, 0);

        v_iskonto_orani :=
            coalesce(nullif(v_item->>'iskonto', '')::numeric, 0);

        v_kdv_orani :=
            coalesce(nullif(v_item->>'kdv_orani', '')::integer, 0);

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_iskonto_tutari :=
            v_brut_tutar * v_iskonto_orani / 100;

        v_net_tutar :=
            v_brut_tutar - v_iskonto_tutari;

        SELECT coalesce(stok_miktari, 0)::integer
        INTO v_onceki_stok
        FROM stoklar
        WHERE stok_id = v_stok_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok bulunamadı. Stok ID: %',
                v_stok_id;
        END IF;

        v_sonraki_stok :=
            v_onceki_stok + v_miktar;

        INSERT INTO alis_detay
        (
            alis_id,
            stok_id,
            miktar,
            birim_fiyat,
            tutar,
            tarih,
            depo_id,
            islem_tipi,
            iade_durumu,
            kdv_orani,
            son_alis_fiyati
        )
        VALUES
        (
            v_alis_id,
            v_stok_id,
            v_miktar,
            v_birim_fiyat,
            v_net_tutar,
            now(),
            p_depo_id,
            'ALIS',
            'NORMAL',
            v_kdv_orani,
            v_birim_fiyat
        );

        UPDATE stoklar
        SET
            stok_miktari = v_sonraki_stok,
            miktar = v_sonraki_stok,
            alis_fiyati = v_birim_fiyat,
            son_alis_tarihi = now()
        WHERE stok_id = v_stok_id;

        INSERT INTO stok_hareket
        (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            miktar,
            belge_no,
            aciklama,
            depo_id,
            cari_id,
            alis_ref,
            fatura_no,
            onceki_stok,
            sonraki_stok,
            birim_maliyet,
            hareket_tipi
        )
        VALUES
        (
            now(),
            p_kullanici,
            v_stok_id,
            'ALIS',
            v_miktar,
            p_fatura_no,
            'Satın alma faturası',
            p_depo_id,
            p_cari_id,
            v_alis_id,
            p_fatura_no,
            v_onceki_stok,
            v_sonraki_stok,
            v_birim_fiyat,
            'GIRIS'
        );
    END LOOP;

    ------------------------------------------------------
    -- CARİ FATURA HAREKETİ
    ------------------------------------------------------

    INSERT INTO cari_hareket
    (
        tarih,
        cari_id,
        islem_tipi,
        belge_no,
        borc,
        alacak,
        aciklama,
        kullanici
    )
    VALUES
    (
        now(),
        p_cari_id,
        'ALIS',
        p_fatura_no,
        0,
        v_genel_toplam,
        'Alış faturası',
        p_kullanici
    );

    UPDATE cariler
    SET
        bakiye = coalesce(bakiye, 0) + v_genel_toplam,
        son_alis_tarihi = now()
    WHERE cari_id = p_cari_id;

    ------------------------------------------------------
    -- PEŞİN ÖDEME
    ------------------------------------------------------

    IF NOT v_veresiye THEN
        INSERT INTO kasa_hareket
        (
            tarih,
            tip,
            tutar,
            aciklama,
            cari_id,
            kullanici,
            kasa_id
        )
        VALUES
        (
            now(),
            'CIKIS',
            v_genel_toplam,
            'Alış ödemesi - Fatura: '
                || coalesce(p_fatura_no, ''),
            p_cari_id,
            p_kullanici,
            p_kasa_id
        );

        INSERT INTO cari_hareket
        (
            tarih,
            cari_id,
            islem_tipi,
            belge_no,
            borc,
            alacak,
            aciklama,
            kullanici
        )
        VALUES
        (
            now(),
            p_cari_id,
            'ODEME',
            p_fatura_no,
            v_genel_toplam,
            0,
            'Alış faturası ödemesi',
            p_kullanici
        );

        UPDATE cariler
        SET
            bakiye = coalesce(bakiye, 0) - v_genel_toplam
        WHERE cari_id = p_cari_id;
    END IF;

    RETURN v_alis_id;
END;
$function$;

-- alis_siparis_faturala(p_siparis_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_kullanici text, p_kabul_detaylari jsonb)
CREATE OR REPLACE FUNCTION public.alis_siparis_faturala(p_siparis_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_kullanici text, p_kabul_detaylari jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_siparis public.alis_siparis_baslik%ROWTYPE;
    v_item jsonb;
    v_detay public.alis_siparis_detay%ROWTYPE;

    v_detay_id bigint;
    v_kabul_miktari numeric;
    v_toplam_kabul numeric := 0;

    v_alis_detaylari jsonb := '[]'::jsonb;
    v_alis_id bigint;

    v_kalan_toplam numeric;
    v_kabul_toplam numeric;
BEGIN
    IF p_siparis_id IS NULL THEN
        RAISE EXCEPTION
            'Alış sipariş ID boş olamaz.';
    END IF;

    IF p_kabul_detaylari IS NULL
       OR jsonb_typeof(p_kabul_detaylari) <> 'array'
       OR jsonb_array_length(p_kabul_detaylari) = 0 THEN
        RAISE EXCEPTION
            'Kabul edilecek sipariş kalemleri boş olamaz.';
    END IF;

    SELECT *
    INTO v_siparis
    FROM public.alis_siparis_baslik
    WHERE siparis_id = p_siparis_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Alış siparişi bulunamadı. Sipariş ID: %',
            p_siparis_id;
    END IF;

    IF upper(v_siparis.durum) NOT IN (
        'ONAYLANDI',
        'KISMI_KABUL'
    ) THEN
        RAISE EXCEPTION
            'Alış siparişi faturalanabilir durumda değil. Mevcut durum: %',
            v_siparis.durum;
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_kabul_detaylari)
    LOOP
        v_detay_id :=
            nullif(v_item->>'detay_id', '')::bigint;

        v_kabul_miktari :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        IF v_detay_id IS NULL THEN
            RAISE EXCEPTION
                'Geçersiz alış sipariş detay ID.';
        END IF;

        IF v_kabul_miktari <= 0 THEN
            RAISE EXCEPTION
                'Kabul miktarı sıfırdan büyük olmalıdır. Detay ID: %',
                v_detay_id;
        END IF;

        SELECT *
        INTO v_detay
        FROM public.alis_siparis_detay
        WHERE detay_id = v_detay_id
          AND siparis_id = p_siparis_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Alış siparişi kalemi bulunamadı. Detay ID: %',
                v_detay_id;
        END IF;

        IF upper(v_detay.durum) = 'IPTAL' THEN
            RAISE EXCEPTION
                'İptal edilmiş alış siparişi kalemi kabul edilemez. Detay ID: %',
                v_detay_id;
        END IF;

        IF v_kabul_miktari > v_detay.kalan_miktar THEN
            RAISE EXCEPTION
                'Kabul miktarı kalan sipariş miktarını aşamaz. '
                'Detay ID: %, Kalan: %, İstenen: %',
                v_detay_id,
                v_detay.kalan_miktar,
                v_kabul_miktari;
        END IF;

        v_alis_detaylari :=
            v_alis_detaylari ||
            jsonb_build_array(
                jsonb_build_object(
                    'stok_id', v_detay.stok_id,
                    'miktar', v_kabul_miktari,
                    'birim_fiyat', v_detay.birim_fiyat,
                    'indirim', v_detay.indirim_orani,
                    'kdv_orani', v_detay.kdv_orani
                )
            );

        v_toplam_kabul :=
            v_toplam_kabul + v_kabul_miktari;
    END LOOP;

    IF v_toplam_kabul <= 0 THEN
        RAISE EXCEPTION
            'Toplam kabul miktarı sıfırdan büyük olmalıdır.';
    END IF;

    /*
      Mevcut alis_olustur:
      - alış başlık ve detaylarını oluşturur,
      - stokları artırır,
      - stok hareketini oluşturur,
      - cari ve kasa hareketlerini oluşturur,
      - hata halinde işlemi geri alır.
    */
    v_alis_id := public.alis_olustur(
        v_siparis.cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        v_siparis.depo_id,
        p_kullanici,
        v_alis_detaylari
    );

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_kabul_detaylari)
    LOOP
        v_detay_id :=
            nullif(v_item->>'detay_id', '')::bigint;

        v_kabul_miktari :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        UPDATE public.alis_siparis_detay
        SET
            kabul_edilen_miktar =
                kabul_edilen_miktar + v_kabul_miktari,
            durum = CASE
                WHEN kabul_edilen_miktar + v_kabul_miktari >= miktar
                    THEN 'TAMAMLANDI'
                ELSE 'KISMI_KABUL'
            END
        WHERE detay_id = v_detay_id
          AND siparis_id = p_siparis_id;
    END LOOP;

    INSERT INTO public.alis_siparis_kabul
    (
        siparis_id,
        alis_id,
        tarih,
        kullanici,
        aciklama
    )
    VALUES
    (
        p_siparis_id,
        v_alis_id,
        now(),
        p_kullanici,
        'Alış siparişinden alış faturası oluşturuldu.'
    );

    SELECT
        coalesce(sum(kalan_miktar), 0),
        coalesce(sum(kabul_edilen_miktar), 0)
    INTO
        v_kalan_toplam,
        v_kabul_toplam
    FROM public.alis_siparis_detay
    WHERE siparis_id = p_siparis_id
      AND durum <> 'IPTAL';

    UPDATE public.alis_siparis_baslik
    SET durum = CASE
        WHEN v_kalan_toplam <= 0 THEN 'TAMAMLANDI'
        WHEN v_kabul_toplam > 0 THEN 'KISMI_KABUL'
        ELSE durum
    END
    WHERE siparis_id = p_siparis_id;

    RETURN v_alis_id;
END;
$function$;

-- alis_siparis_guncelleme_tarihi()
CREATE OR REPLACE FUNCTION public.alis_siparis_guncelleme_tarihi()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    NEW.guncelleme_tarihi := now();
    RETURN NEW;
END;
$function$;

-- alis_siparis_iptal_et(p_siparis_id bigint, p_kullanici text, p_aciklama text)
CREATE OR REPLACE FUNCTION public.alis_siparis_iptal_et(p_siparis_id bigint, p_kullanici text, p_aciklama text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.alis_siparis_baslik
    SET
        durum = 'IPTAL',
        iptal_tarihi = now(),
        iptal_kullanici = p_kullanici,
        iptal_aciklama =
            nullif(trim(coalesce(p_aciklama, '')), '')
    WHERE siparis_id = p_siparis_id
      AND durum NOT IN ('TAMAMLANDI', 'IPTAL');

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Alış siparişi bulunamadı, tamamlanmış veya zaten iptal edilmiş.';
    END IF;

    UPDATE public.alis_siparis_detay
    SET durum = 'IPTAL'
    WHERE siparis_id = p_siparis_id
      AND durum <> 'TAMAMLANDI';
END;
$function$;

-- alis_siparis_olustur(p_siparis_no text, p_cari_id bigint, p_depo_id bigint, p_odeme_tipi text, p_termin_tarihi date, p_aciklama text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.alis_siparis_olustur(p_siparis_no text, p_cari_id bigint, p_depo_id bigint, p_odeme_tipi text, p_termin_tarihi date, p_aciklama text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_siparis_id bigint;
    v_siparis_no text;
    v_item jsonb;

    v_stok_id bigint;
    v_miktar numeric;
    v_birim_fiyat numeric;
    v_indirim_orani numeric;
    v_kdv_orani numeric;

    v_brut_tutar numeric;
    v_indirim_tutari numeric;
    v_net_tutar numeric;
    v_kdv_tutari numeric;
    v_satir_genel_toplam numeric;

    v_toplam_tutar numeric := 0;
    v_toplam_indirim numeric := 0;
    v_kdv_toplam numeric := 0;
    v_genel_toplam numeric := 0;
BEGIN
    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION
            'Alış siparişi için tedarikçi seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION
            'Alış siparişi için depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION
            'Alış siparişi kalemleri boş olamaz.';
    END IF;

    PERFORM 1
    FROM public.cariler
    WHERE cari_id = p_cari_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Tedarikçi bulunamadı. Cari ID: %',
            p_cari_id;
    END IF;

    PERFORM 1
    FROM public.depolar
    WHERE depo_id = p_depo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Depo bulunamadı. Depo ID: %',
            p_depo_id;
    END IF;

    v_siparis_no :=
        nullif(trim(coalesce(p_siparis_no, '')), '');

    IF v_siparis_no IS NULL THEN
        v_siparis_no := public.yeni_alis_siparis_no();
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.alis_siparis_baslik
        WHERE upper(trim(siparis_no)) =
              upper(trim(v_siparis_no))
    ) THEN
        RAISE EXCEPTION
            'Bu alış sipariş numarası daha önce kullanılmış: %',
            v_siparis_no;
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::numeric,
                0
            );

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION
                'Geçersiz stok ID.';
        END IF;

        PERFORM 1
        FROM public.stoklar
        WHERE stok_id = v_stok_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'Sipariş miktarı sıfırdan büyük olmalıdır. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_birim_fiyat < 0 THEN
            RAISE EXCEPTION
                'Birim alış fiyatı negatif olamaz. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_indirim_orani < 0
           OR v_indirim_orani > 100 THEN
            RAISE EXCEPTION
                'İndirim oranı 0 ile 100 arasında olmalıdır.';
        END IF;

        IF v_kdv_orani < 0
           OR v_kdv_orani > 100 THEN
            RAISE EXCEPTION
                'KDV oranı 0 ile 100 arasında olmalıdır.';
        END IF;

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_indirim_tutari :=
            v_brut_tutar
            * v_indirim_orani / 100;

        v_net_tutar :=
            v_brut_tutar
            - v_indirim_tutari;

        v_kdv_tutari :=
            v_net_tutar
            * v_kdv_orani / 100;

        v_satir_genel_toplam :=
            v_net_tutar
            + v_kdv_tutari;

        v_toplam_tutar :=
            v_toplam_tutar
            + v_brut_tutar;

        v_toplam_indirim :=
            v_toplam_indirim
            + v_indirim_tutari;

        v_kdv_toplam :=
            v_kdv_toplam
            + v_kdv_tutari;

        v_genel_toplam :=
            v_genel_toplam
            + v_satir_genel_toplam;
    END LOOP;

    INSERT INTO public.alis_siparis_baslik
    (
        siparis_no,
        tarih,
        termin_tarihi,
        cari_id,
        depo_id,
        odeme_tipi,
        durum,
        toplam_tutar,
        toplam_indirim,
        kdv_toplam,
        genel_toplam,
        aciklama,
        kullanici
    )
    VALUES
    (
        v_siparis_no,
        now(),
        p_termin_tarihi,
        p_cari_id,
        p_depo_id,
        nullif(trim(coalesce(p_odeme_tipi, '')), ''),
        'HAZIRLANIYOR',
        v_toplam_tutar,
        v_toplam_indirim,
        v_kdv_toplam,
        v_genel_toplam,
        nullif(trim(coalesce(p_aciklama, '')), ''),
        p_kullanici
    )
    RETURNING siparis_id
    INTO v_siparis_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::numeric,
                0
            );

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_indirim_tutari :=
            v_brut_tutar
            * v_indirim_orani / 100;

        v_net_tutar :=
            v_brut_tutar
            - v_indirim_tutari;

        v_kdv_tutari :=
            v_net_tutar
            * v_kdv_orani / 100;

        v_satir_genel_toplam :=
            v_net_tutar
            + v_kdv_tutari;

        INSERT INTO public.alis_siparis_detay
        (
            siparis_id,
            stok_id,
            miktar,
            kabul_edilen_miktar,
            birim_fiyat,
            indirim_orani,
            indirim_tutari,
            kdv_orani,
            kdv_tutari,
            net_tutar,
            genel_toplam,
            aciklama,
            durum
        )
        VALUES
        (
            v_siparis_id,
            v_stok_id,
            v_miktar,
            0,
            v_birim_fiyat,
            v_indirim_orani,
            v_indirim_tutari,
            v_kdv_orani,
            v_kdv_tutari,
            v_net_tutar,
            v_satir_genel_toplam,
            nullif(
                trim(
                    coalesce(v_item->>'aciklama', '')
                ),
                ''
            ),
            'BEKLIYOR'
        );
    END LOOP;

    RETURN v_siparis_id;
END;
$function$;

-- alis_siparis_onayla(p_siparis_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.alis_siparis_onayla(p_siparis_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.alis_siparis_baslik
    SET
        durum = 'ONAYLANDI',
        kullanici = coalesce(p_kullanici, kullanici)
    WHERE siparis_id = p_siparis_id
      AND durum = 'HAZIRLANIYOR';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Alış siparişi bulunamadı veya onaylanabilir durumda değil.';
    END IF;
END;
$function$;

-- alis_yap_detay(p_alis_id bigint, p_stok_id bigint, p_miktar integer, p_birim_fiyat numeric, p_kdv_orani integer, p_depo_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.alis_yap_detay(p_alis_id bigint, p_stok_id bigint, p_miktar integer, p_birim_fiyat numeric, p_kdv_orani integer, p_depo_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_onceki_stok integer;
    v_yeni_stok integer;
BEGIN

    INSERT INTO alis_detay
    (
        alis_id,
        stok_id,
        miktar,
        birim_fiyat,
        tutar,
        tarih,
        depo_id,
        islem_tipi,
        kdv_orani,
        son_alis_fiyati
    )
    VALUES
    (
        p_alis_id,
        p_stok_id,
        p_miktar,
        p_birim_fiyat,
        p_miktar * p_birim_fiyat,
        now(),
        p_depo_id,
        'ALIS',
        p_kdv_orani,
        p_birim_fiyat
    );

    SELECT stok_miktari
    INTO v_onceki_stok
    FROM stoklar
    WHERE stok_id = p_stok_id
    FOR UPDATE;

    v_yeni_stok := v_onceki_stok + p_miktar;

    UPDATE stoklar
    SET
        stok_miktari = v_yeni_stok,
        alis_fiyati = p_birim_fiyat,
        son_alis_tarihi = now()
    WHERE stok_id = p_stok_id;

    INSERT INTO stok_hareket
    (
        tarih,
        kullanici,
        stok_id,
        islem_tipi,
        miktar,
        onceki_stok,
        sonraki_stok,
        birim_maliyet,
        hareket_tipi,
        alis_ref,
        depo_id
    )
    VALUES
    (
        now(),
        p_kullanici,
        p_stok_id,
        'ALIS',
        p_miktar,
        v_onceki_stok,
        v_yeni_stok,
        p_birim_fiyat,
        'GIRIS',
        p_alis_id,
        p_depo_id
    );

END;
$function$;

-- cari_bakiye_alis()
CREATE OR REPLACE FUNCTION public.cari_bakiye_alis()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Tedarikçiden alış yapıldığında borç eklenir
  UPDATE cariler
  SET bakiye = COALESCE(bakiye,0) + (NEW.miktar * NEW.fiyat)
  WHERE cari_id = NEW.cari_id
    AND cari_tipi = 'Tedarikçi';
  RETURN NEW;
END;
$function$;

-- cari_bakiye_artir()
CREATE OR REPLACE FUNCTION public.cari_bakiye_artir()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE cariler
  SET bakiye = bakiye + (NEW.miktar * NEW.fiyat)
  WHERE cari_id = NEW.cari_id;
  RETURN NEW;
END;
$function$;

-- cari_bakiye_satis()
CREATE OR REPLACE FUNCTION public.cari_bakiye_satis()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Müşteriye satış yapıldığında alacak eklenir
  UPDATE cariler
  SET bakiye = COALESCE(bakiye,0) + (NEW.miktar * NEW.fiyat)
  WHERE cari_id = NEW.cari_id
    AND cari_tipi = 'Müşteri';
  RETURN NEW;
END;
$function$;

-- cari_borc_ekle(p_cari_id bigint, p_tutar numeric)
CREATE OR REPLACE FUNCTION public.cari_borc_ekle(p_cari_id bigint, p_tutar numeric)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

    UPDATE cariler
    SET
        bakiye = COALESCE(bakiye,0) + p_tutar,
        son_alis_tarihi = now()
    WHERE cari_id = p_cari_id;

END;
$function$;

-- cari_virman_kaydet(p_musteri_cari_id bigint, p_tedarikci_cari_id bigint, p_tutar numeric, p_aciklama text, p_tarih timestamp with time zone, p_kullanici text)
CREATE OR REPLACE FUNCTION public.cari_virman_kaydet(p_musteri_cari_id bigint, p_tedarikci_cari_id bigint, p_tutar numeric, p_aciklama text DEFAULT NULL::text, p_tarih timestamp with time zone DEFAULT now(), p_kullanici text DEFAULT 'UNAL'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_virman_no text;
  v_musteri_unvan text;
  v_tedarikci_unvan text;
  v_musteri_bakiye numeric;
  v_tedarikci_bakiye numeric;
  v_musteri_tipi text;
  v_tedarikci_tipi text;
begin
  if p_musteri_cari_id is null or p_tedarikci_cari_id is null then
    raise exception 'Müşteri ve tedarikçi seçilmelidir.';
  end if;

  if p_musteri_cari_id = p_tedarikci_cari_id then
    raise exception 'Aynı cari kendi kendine virman yapılamaz.';
  end if;

  if coalesce(p_tutar, 0) <= 0 then
    raise exception 'Virman tutarı sıfırdan büyük olmalıdır.';
  end if;

  select
    unvan,
    coalesce(bakiye, 0),
    coalesce(cari_tipi::text, '')
  into
    v_musteri_unvan,
    v_musteri_bakiye,
    v_musteri_tipi
  from public.cariler
  where cari_id = p_musteri_cari_id
  for update;

  select
    unvan,
    coalesce(bakiye, 0),
    coalesce(cari_tipi::text, '')
  into
    v_tedarikci_unvan,
    v_tedarikci_bakiye,
    v_tedarikci_tipi
  from public.cariler
  where cari_id = p_tedarikci_cari_id
  for update;

  if v_musteri_unvan is null or v_tedarikci_unvan is null then
    raise exception 'Cari bulunamadı.';
  end if;

  if upper(v_musteri_tipi) not like '%MUSTERI%'
     and upper(v_musteri_tipi) not like '%MÜŞTERİ%' then
    raise exception 'İlk cari müşteri tipinde olmalıdır.';
  end if;

  if upper(v_tedarikci_tipi) not like '%TEDAR%' then
    raise exception 'İkinci cari tedarikçi tipinde olmalıdır.';
  end if;

  if v_musteri_bakiye <= 0 then
    raise exception 'Müşterinin size açık borcu bulunmuyor.';
  end if;

  if v_tedarikci_bakiye <= 0 then
    raise exception 'Tedarikçiye açık borcunuz bulunmuyor.';
  end if;

  if p_tutar > v_musteri_bakiye then
    raise exception 'Virman tutarı müşteri açık bakiyesinden fazla olamaz.';
  end if;

  if p_tutar > v_tedarikci_bakiye then
    raise exception 'Virman tutarı tedarikçi açık bakiyesinden fazla olamaz.';
  end if;

  v_virman_no :=
    'VRM-' ||
    to_char(coalesce(p_tarih, now()), 'YYYYMM') ||
    '-' ||
    lpad(nextval('public.cari_virman_no_seq')::text, 6, '0');

  insert into public.cari_virman(
    virman_no, tarih, musteri_cari_id, tedarikci_cari_id,
    tutar, aciklama, kullanici
  )
  values(
    v_virman_no, coalesce(p_tarih, now()),
    p_musteri_cari_id, p_tedarikci_cari_id,
    p_tutar, nullif(trim(coalesce(p_aciklama, '')), ''), p_kullanici
  );

  -- Müşterinin size olan borcunu azaltır.
  insert into public.cari_hareket(
    tarih, cari_id, islem_tipi, belge_no,
    borc, alacak, aciklama, kullanici
  )
  values(
    coalesce(p_tarih, now()),
    p_musteri_cari_id,
    'VIRMAN_MUSTERI',
    v_virman_no,
    0,
    p_tutar,
    'Cari virman / mahsup → ' || v_tedarikci_unvan ||
      case
        when nullif(trim(coalesce(p_aciklama, '')), '') is null then ''
        else ' | ' || trim(p_aciklama)
      end,
    p_kullanici
  );

  -- Tedarikçiye olan borcunuzu azaltır.
  insert into public.cari_hareket(
    tarih, cari_id, islem_tipi, belge_no,
    borc, alacak, aciklama, kullanici
  )
  values(
    coalesce(p_tarih, now()),
    p_tedarikci_cari_id,
    'VIRMAN_TEDARIKCI',
    v_virman_no,
    0,
    p_tutar,
    'Cari virman / mahsup ← ' || v_musteri_unvan ||
      case
        when nullif(trim(coalesce(p_aciklama, '')), '') is null then ''
        else ' | ' || trim(p_aciklama)
      end,
    p_kullanici
  );

  update public.cariler
  set bakiye = coalesce(bakiye, 0) - p_tutar
  where cari_id in (
    p_musteri_cari_id,
    p_tedarikci_cari_id
  );

  return v_virman_no;
end;
$function$;

-- check_cari_risk_limiti()
CREATE OR REPLACE FUNCTION public.check_cari_risk_limiti()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_mevcut_bakiye numeric := 0;
    v_risk_limiti numeric := 0;
    v_satis_tutari numeric := 0;
BEGIN
    -- Cari olmayan hareketlerde kontrol yapma
    IF NEW.cari_id IS NULL THEN
        RETURN NEW;
    END IF;

    -- Yalnızca satış hareketlerini kontrol et
    IF upper(coalesce(NEW.islem_tipi, '')) NOT IN
       ('SATIS', 'SATIŞ') THEN
        RETURN NEW;
    END IF;

    SELECT
        coalesce(c.bakiye, 0),
        coalesce(c.risk_limiti, 0)
    INTO
        v_mevcut_bakiye,
        v_risk_limiti
    FROM public.cariler AS c
    WHERE c.cari_id = NEW.cari_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Cari bulunamadı. Cari ID: %',
            NEW.cari_id;
    END IF;

    /*
      Risk limiti 0 veya negatifse sınırsız kabul edilir.
      Bu durumda satış engellenmez.
    */
    IF v_risk_limiti <= 0 THEN
        RETURN NEW;
    END IF;

    v_satis_tutari :=
        coalesce(NEW.miktar, 0) *
        coalesce(NEW.birim_maliyet, 0);

    IF v_mevcut_bakiye + v_satis_tutari > v_risk_limiti THEN
        RAISE EXCEPTION
            'Cari risk limiti aşıldı! Cari ID: %, '
            'Mevcut Bakiye: %, İşlem: %, Risk Limiti: %',
            NEW.cari_id,
            v_mevcut_bakiye,
            v_satis_tutari,
            v_risk_limiti;
    END IF;

    RETURN NEW;
END;
$function$;

-- depolar_arasi_transfer(p_stok_id bigint, p_kaynak_depo_id bigint, p_hedef_depo_id bigint, p_miktar numeric, p_belge_tipi text, p_belge_id bigint, p_belge_no text, p_aciklama text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.depolar_arasi_transfer(p_stok_id bigint, p_kaynak_depo_id bigint, p_hedef_depo_id bigint, p_miktar numeric, p_belge_tipi text DEFAULT 'TRANSFER'::text, p_belge_id bigint DEFAULT NULL::bigint, p_belge_no text DEFAULT NULL::text, p_aciklama text DEFAULT NULL::text, p_kullanici text DEFAULT 'UNAL'::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_kaynak_miktar numeric;
    v_hareket_id bigint;
BEGIN
    IF p_stok_id IS NULL THEN
        RAISE EXCEPTION 'Stok seçilmelidir.';
    END IF;

    IF p_kaynak_depo_id IS NULL
       OR p_hedef_depo_id IS NULL THEN
        RAISE EXCEPTION 'Kaynak ve hedef depo seçilmelidir.';
    END IF;

    IF p_kaynak_depo_id = p_hedef_depo_id THEN
        RAISE EXCEPTION 'Kaynak ve hedef depo aynı olamaz.';
    END IF;

    IF COALESCE(p_miktar, 0) <= 0 THEN
        RAISE EXCEPTION 'Transfer miktarı sıfırdan büyük olmalıdır.';
    END IF;

    PERFORM 1
    FROM public.depolar
    WHERE depo_id = p_kaynak_depo_id
      AND aktif = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Kaynak depo bulunamadı veya pasif.';
    END IF;

    PERFORM 1
    FROM public.depolar
    WHERE depo_id = p_hedef_depo_id
      AND aktif = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Hedef depo bulunamadı veya pasif.';
    END IF;

    INSERT INTO public.stok_depo_bakiye (
        stok_id,
        depo_id,
        miktar,
        rezerve_miktar
    )
    VALUES (
        p_stok_id,
        p_kaynak_depo_id,
        0,
        0
    )
    ON CONFLICT (stok_id, depo_id)
    DO NOTHING;

    SELECT miktar
    INTO v_kaynak_miktar
    FROM public.stok_depo_bakiye
    WHERE stok_id = p_stok_id
      AND depo_id = p_kaynak_depo_id
    FOR UPDATE;

    IF COALESCE(v_kaynak_miktar, 0) < p_miktar THEN
        RAISE EXCEPTION
            'Kaynak depoda yeterli stok yok. Mevcut: %, İstenen: %',
            COALESCE(v_kaynak_miktar, 0),
            p_miktar;
    END IF;

    UPDATE public.stok_depo_bakiye
    SET
        miktar = miktar - p_miktar,
        son_guncelleme = now()
    WHERE stok_id = p_stok_id
      AND depo_id = p_kaynak_depo_id;

    INSERT INTO public.stok_depo_bakiye (
        stok_id,
        depo_id,
        miktar,
        rezerve_miktar,
        son_guncelleme
    )
    VALUES (
        p_stok_id,
        p_hedef_depo_id,
        p_miktar,
        0,
        now()
    )
    ON CONFLICT (stok_id, depo_id)
    DO UPDATE SET
        miktar =
            public.stok_depo_bakiye.miktar
            + EXCLUDED.miktar,
        son_guncelleme = now();

    INSERT INTO public.depo_hareketleri (
        stok_id,
        kaynak_depo_id,
        hedef_depo_id,
        hareket_tipi,
        miktar,
        belge_tipi,
        belge_id,
        belge_no,
        aciklama,
        kullanici
    )
    VALUES (
        p_stok_id,
        p_kaynak_depo_id,
        p_hedef_depo_id,
        'TRANSFER',
        p_miktar,
        p_belge_tipi,
        p_belge_id,
        p_belge_no,
        p_aciklama,
        p_kullanici
    )
    RETURNING hareket_id
    INTO v_hareket_id;

    RETURN v_hareket_id;
END;
$function$;

-- erp_audit_trigger()
CREATE OR REPLACE FUNCTION public.erp_audit_trigger()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_old jsonb;
  v_new jsonb;
  v_data jsonb;
  v_user text;
  v_id text;
begin
  if tg_op = 'INSERT' then
    v_old := null;
    v_new := to_jsonb(new);
    v_data := v_new;
  elsif tg_op = 'DELETE' then
    v_old := to_jsonb(old);
    v_new := null;
    v_data := v_old;
  else
    v_old := to_jsonb(old);
    v_new := to_jsonb(new);
    v_data := v_new;
  end if;

  v_user := coalesce(
    v_data->>'kullanici',
    v_data->>'updated_by',
    v_data->>'created_by',
    'SISTEM'
  );

  v_id := coalesce(
    v_data->>'stok_id',
    v_data->>'cari_id',
    v_data->>'satis_id',
    v_data->>'alis_id',
    v_data->>'hareket_id',
    v_data->>'kasa_hareket_id',
    v_data->>'irsaliye_id',
    v_data->>'siparis_id',
    v_data->>'id',
    '-'
  );

  insert into public.erp_islem_log(
    tablo, islem, kayit_id, kullanici, eski_veri, yeni_veri
  ) values (
    tg_table_name, tg_op, v_id, v_user, v_old, v_new
  );

  return coalesce(new, old);
end;
$function$;

-- erp_auth_kullaniciyi_bagla()
CREATE OR REPLACE FUNCTION public.erp_auth_kullaniciyi_bagla()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
  update public.erp_kullanicilar
     set auth_user_id = new.id,
         updated_at = now()
   where lower(coalesce(eposta, '')) = lower(coalesce(new.email, ''))
     and coalesce(new.email, '') <> '';
  return new;
end;
$function$;

-- erp_fatura_vade_ata()
CREATE OR REPLACE FUNCTION public.erp_fatura_vade_ata()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v integer:=0;
begin
 if new.vade_tarihi is null and new.cari_id is not null then
   select coalesce(vade_gun,0) into v from public.cariler where cari_id=new.cari_id;
   new.vade_tarihi:=coalesce(new.tarih::date,current_date)+v;
 end if;
 return new;
end;$function$;

-- erp_guvenli_giris_aktif()
CREATE OR REPLACE FUNCTION public.erp_guvenli_giris_aktif()
 RETURNS boolean
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
  select coalesce(
    (select (deger #>> '{}')::boolean
       from public.erp_sistem_ayarlari
      where anahtar = 'guvenli_giris'),
    false
  );
$function$;

-- erp_kullanici_updated_at()
CREATE OR REPLACE FUNCTION public.erp_kullanici_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
begin
  new.updated_at := now();
  return new;
end;
$function$;

-- erp_muhasebe_fis_toplam_guncelle()
CREATE OR REPLACE FUNCTION public.erp_muhasebe_fis_toplam_guncelle()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare v_fis bigint;
begin
  if TG_OP = 'DELETE' then
    v_fis := old.fis_id;
  else
    v_fis := new.fis_id;
  end if;
  update public.erp_muhasebe_fisleri f
  set borc_toplam = coalesce((select sum(borc) from public.erp_muhasebe_fis_satirlari where fis_id=v_fis),0),
      alacak_toplam = coalesce((select sum(alacak) from public.erp_muhasebe_fis_satirlari where fis_id=v_fis),0)
  where f.fis_id=v_fis;
  if TG_OP = 'DELETE' then
    return old;
  end if;
  return new;
end $function$;

-- erp_vade_odeme_kaydet(p_belge_tipi text, p_belge_id bigint, p_cari_id bigint, p_kasa_id bigint, p_tutar numeric, p_tarih timestamp with time zone, p_kullanici text, p_aciklama text)
CREATE OR REPLACE FUNCTION public.erp_vade_odeme_kaydet(p_belge_tipi text, p_belge_id bigint, p_cari_id bigint, p_kasa_id bigint, p_tutar numeric, p_tarih timestamp with time zone, p_kullanici text, p_aciklama text DEFAULT ''::text)
 RETURNS void
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
declare
  v_tip text := upper(trim(coalesce(p_belge_tipi, '')));
  v_toplam numeric;
  v_odenen numeric;
  v_belge_no text;
begin
  if p_tutar is null or p_tutar <= 0 then
    raise exception 'Ödeme tutarı sıfırdan büyük olmalıdır.';
  end if;

  if v_tip = 'SATIS' then
    select coalesce(genel_toplam, toplam_tutar, 0),
           coalesce(odenen_tutar, 0),
           coalesce(fatura_no, '-')
      into v_toplam, v_odenen, v_belge_no
      from public.satis_baslik
     where satis_id = p_belge_id
     for update;

    if not found then raise exception 'Satış faturası bulunamadı.'; end if;
    if v_odenen + p_tutar > v_toplam + 0.01 then
      raise exception 'Tahsilat kalan tutarı aşıyor.';
    end if;

    perform public.kasa_cari_islemi_kaydet(
      'TAHSILAT', p_cari_id::integer, p_kasa_id::integer, p_tutar,
      v_belge_no, p_aciklama, p_tarih, p_kullanici
    );

    update public.satis_baslik
       set odenen_tutar = coalesce(odenen_tutar, 0) + p_tutar
     where satis_id = p_belge_id;

  elsif v_tip = 'ALIS' then
    select coalesce(genel_toplam, toplam_tutar, 0),
           coalesce(odenen_tutar, 0),
           coalesce(fatura_no, '-')
      into v_toplam, v_odenen, v_belge_no
      from public.alis_baslik
     where alis_id = p_belge_id
     for update;

    if not found then raise exception 'Alış faturası bulunamadı.'; end if;
    if v_odenen + p_tutar > v_toplam + 0.01 then
      raise exception 'Ödeme kalan tutarı aşıyor.';
    end if;

    perform public.kasa_cari_islemi_kaydet(
      'ODEME', p_cari_id::integer, p_kasa_id::integer, p_tutar,
      v_belge_no, p_aciklama, p_tarih, p_kullanici
    );

    update public.alis_baslik
       set odenen_tutar = coalesce(odenen_tutar, 0) + p_tutar
     where alis_id = p_belge_id;
  else
    raise exception 'Belge tipi SATIS veya ALIS olmalıdır.';
  end if;
end;
$function$;

-- faturaya_bagli_iade_olustur(p_iade_tipi text, p_kaynak_fatura_id bigint, p_cari_id bigint, p_depo_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.faturaya_bagli_iade_olustur(p_iade_tipi text, p_kaynak_fatura_id bigint, p_cari_id bigint, p_depo_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_iade_tipi text := upper(trim(p_iade_tipi));
    v_fatura_no text;
    v_fatura_cari_id bigint;
    v_fatura_depo_id bigint;
    v_iade_depo_id bigint;
    v_iade_id bigint;
    v_iade_no text;
    v_item jsonb;
    v_stok_id bigint;
    v_miktar numeric;
    v_birim_fiyat numeric;
    v_indirim numeric;
    v_kdv numeric;
    v_fatura_miktari numeric;
    v_onceki_iade numeric;
    v_brut numeric;
    v_indirim_tutari numeric;
    v_matrah numeric;
    v_kdv_tutari numeric;
    v_genel numeric;
    v_toplam numeric := 0;
    v_kdv_toplam numeric := 0;
    v_genel_toplam numeric := 0;
    v_depo_miktari numeric;
BEGIN
    IF v_iade_tipi NOT IN ('SATIS_IADE', 'ALIS_IADE') THEN
        RAISE EXCEPTION 'Geçersiz iade tipi.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION 'İade kalemleri boş olamaz.';
    END IF;

    IF v_iade_tipi = 'SATIS_IADE' THEN
        SELECT fatura_no, cari_id, depo_id
        INTO v_fatura_no, v_fatura_cari_id, v_fatura_depo_id
        FROM public.satis_baslik
        WHERE satis_id = p_kaynak_fatura_id
          AND upper(coalesce(durum, '')) <> 'IPTAL';

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Satış faturası bulunamadı veya iptal edilmiş.';
        END IF;

        SELECT depo_id
        INTO v_iade_depo_id
        FROM public.depolar
        WHERE depo_tipi = 'IADE'
          AND aktif = true
        ORDER BY depo_id
        LIMIT 1;

        IF v_iade_depo_id IS NULL THEN
            RAISE EXCEPTION 'Aktif İade Deposu bulunamadı.';
        END IF;
    ELSE
        SELECT fatura_no, cari_id, depo_id
        INTO v_fatura_no, v_fatura_cari_id, v_fatura_depo_id
        FROM public.alis_baslik
        WHERE alis_id = p_kaynak_fatura_id
          AND upper(coalesce(durum, '')) <> 'IPTAL';

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Alış faturası bulunamadı veya iptal edilmiş.';
        END IF;
    END IF;

    IF v_fatura_cari_id <> p_cari_id THEN
        RAISE EXCEPTION 'Seçilen cari faturanın carisiyle uyuşmuyor.';
    END IF;

    v_iade_no := public.yeni_iade_no(v_iade_tipi);

    INSERT INTO public.iade_baslik (
        iade_no,
        iade_tipi,
        kaynak_fatura_id,
        kaynak_fatura_no,
        cari_id,
        depo_id,
        aciklama,
        kullanici
    )
    VALUES (
        v_iade_no,
        v_iade_tipi,
        p_kaynak_fatura_id,
        v_fatura_no,
        p_cari_id,
        CASE
            WHEN v_iade_tipi = 'SATIS_IADE'
                THEN v_iade_depo_id
            ELSE p_depo_id
        END,
        nullif(trim(coalesce(p_aciklama, '')), ''),
        p_kullanici
    )
    RETURNING iade_id INTO v_iade_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id := nullif(v_item->>'stok_id', '')::bigint;
        v_miktar := coalesce(nullif(v_item->>'miktar', '')::numeric, 0);
        v_birim_fiyat := coalesce(nullif(v_item->>'birim_fiyat', '')::numeric, 0);
        v_indirim := coalesce(nullif(v_item->>'indirim', '')::numeric, 0);
        v_kdv := coalesce(nullif(v_item->>'kdv_orani', '')::numeric, 0);

        IF v_stok_id IS NULL OR v_miktar <= 0 THEN
            RAISE EXCEPTION 'Geçersiz iade kalemi.';
        END IF;

        IF v_iade_tipi = 'SATIS_IADE' THEN
            SELECT coalesce(sum(miktar), 0)
            INTO v_fatura_miktari
            FROM public.satis_detay
            WHERE satis_id = p_kaynak_fatura_id
              AND stok_id = v_stok_id;
        ELSE
            SELECT coalesce(sum(miktar), 0)
            INTO v_fatura_miktari
            FROM public.alis_detay
            WHERE alis_id = p_kaynak_fatura_id
              AND stok_id = v_stok_id;
        END IF;

        SELECT coalesce(sum(d.miktar), 0)
        INTO v_onceki_iade
        FROM public.iade_detay d
        JOIN public.iade_baslik b
          ON b.iade_id = d.iade_id
        WHERE b.iade_tipi = v_iade_tipi
          AND b.kaynak_fatura_id = p_kaynak_fatura_id
          AND b.durum <> 'IPTAL'
          AND d.stok_id = v_stok_id;

        IF v_miktar + v_onceki_iade > v_fatura_miktari THEN
            RAISE EXCEPTION
                'İade miktarı faturadaki kalan miktarı aşıyor. Stok ID: %, Fatura: %, Önceki iade: %, İstenen: %',
                v_stok_id, v_fatura_miktari, v_onceki_iade, v_miktar;
        END IF;

        v_brut := v_miktar * v_birim_fiyat;
        v_indirim_tutari := v_brut * v_indirim / 100;
        v_matrah := v_brut - v_indirim_tutari;
        v_kdv_tutari := v_matrah * v_kdv / 100;
        v_genel := v_matrah + v_kdv_tutari;

        INSERT INTO public.iade_detay (
            iade_id,
            stok_id,
            miktar,
            birim_fiyat,
            indirim_orani,
            kdv_orani,
            tutar,
            kdv_tutari,
            genel_toplam,
            neden
        )
        VALUES (
            v_iade_id,
            v_stok_id,
            v_miktar,
            v_birim_fiyat,
            v_indirim,
            v_kdv,
            v_matrah,
            v_kdv_tutari,
            v_genel,
            nullif(trim(coalesce(v_item->>'neden', '')), '')
        );

        v_toplam := v_toplam + v_matrah;
        v_kdv_toplam := v_kdv_toplam + v_kdv_tutari;
        v_genel_toplam := v_genel_toplam + v_genel;

        IF v_iade_tipi = 'SATIS_IADE' THEN
            INSERT INTO public.stok_depo_bakiye (
                stok_id, depo_id, miktar, rezerve_miktar
            )
            VALUES (
                v_stok_id, v_iade_depo_id, v_miktar, 0
            )
            ON CONFLICT (stok_id, depo_id)
            DO UPDATE SET
                miktar = public.stok_depo_bakiye.miktar + EXCLUDED.miktar,
                son_guncelleme = now();

            INSERT INTO public.depo_hareketleri (
                stok_id,
                kaynak_depo_id,
                hedef_depo_id,
                hareket_tipi,
                miktar,
                belge_tipi,
                belge_id,
                belge_no,
                aciklama,
                kullanici
            )
            VALUES (
                v_stok_id,
                NULL,
                v_iade_depo_id,
                'SATIS_IADE',
                v_miktar,
                'SATIS_IADE',
                v_iade_id,
                v_iade_no,
                p_aciklama,
                p_kullanici
            );
        ELSE
            INSERT INTO public.stok_depo_bakiye (
                stok_id, depo_id, miktar, rezerve_miktar
            )
            VALUES (
                v_stok_id, p_depo_id, 0, 0
            )
            ON CONFLICT (stok_id, depo_id)
            DO NOTHING;

            SELECT miktar
            INTO v_depo_miktari
            FROM public.stok_depo_bakiye
            WHERE stok_id = v_stok_id
              AND depo_id = p_depo_id
            FOR UPDATE;

            IF coalesce(v_depo_miktari, 0) < v_miktar THEN
                RAISE EXCEPTION
                    'Alış iadesi için depoda yeterli stok yok. Stok ID: %, Mevcut: %, İstenen: %',
                    v_stok_id, coalesce(v_depo_miktari, 0), v_miktar;
            END IF;

            UPDATE public.stok_depo_bakiye
            SET miktar = miktar - v_miktar,
                son_guncelleme = now()
            WHERE stok_id = v_stok_id
              AND depo_id = p_depo_id;

            INSERT INTO public.depo_hareketleri (
                stok_id,
                kaynak_depo_id,
                hedef_depo_id,
                hareket_tipi,
                miktar,
                belge_tipi,
                belge_id,
                belge_no,
                aciklama,
                kullanici
            )
            VALUES (
                v_stok_id,
                p_depo_id,
                NULL,
                'ALIS_IADE',
                v_miktar,
                'ALIS_IADE',
                v_iade_id,
                v_iade_no,
                p_aciklama,
                p_kullanici
            );
        END IF;
    END LOOP;

    UPDATE public.iade_baslik
    SET toplam_tutar = v_toplam,
        kdv_toplam = v_kdv_toplam,
        genel_toplam = v_genel_toplam
    WHERE iade_id = v_iade_id;

    RETURN v_iade_id;
END;
$function$;

-- finans_hesap_transfer_kaydet(p_kaynak_kasa_id bigint, p_hedef_kasa_id bigint, p_tutar numeric, p_aciklama text, p_tarih timestamp with time zone, p_kullanici text)
CREATE OR REPLACE FUNCTION public.finans_hesap_transfer_kaydet(p_kaynak_kasa_id bigint, p_hedef_kasa_id bigint, p_tutar numeric, p_aciklama text DEFAULT NULL::text, p_tarih timestamp with time zone DEFAULT now(), p_kullanici text DEFAULT 'UNAL'::text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_transfer_no text;
  v_kaynak_adi text;
  v_hedef_adi text;
begin
  if p_kaynak_kasa_id is null or p_hedef_kasa_id is null then
    raise exception 'Kaynak ve hedef hesap seçilmelidir.';
  end if;

  if p_kaynak_kasa_id = p_hedef_kasa_id then
    raise exception 'Kaynak ve hedef hesap aynı olamaz.';
  end if;

  if coalesce(p_tutar, 0) <= 0 then
    raise exception 'Transfer tutarı sıfırdan büyük olmalıdır.';
  end if;

  select kasa_adi into v_kaynak_adi
  from public.kasalar
  where kasa_id = p_kaynak_kasa_id;

  select kasa_adi into v_hedef_adi
  from public.kasalar
  where kasa_id = p_hedef_kasa_id;

  if v_kaynak_adi is null or v_hedef_adi is null then
    raise exception 'Kasa/Banka/POS hesabı bulunamadı.';
  end if;

  v_transfer_no :=
    'TRF-' ||
    to_char(coalesce(p_tarih, now()), 'YYYYMM') ||
    '-' ||
    lpad(nextval('public.finans_transfer_no_seq')::text, 6, '0');

  insert into public.finans_transfer(
    transfer_no, tarih, kaynak_kasa_id, hedef_kasa_id,
    tutar, aciklama, kullanici
  )
  values(
    v_transfer_no, coalesce(p_tarih, now()),
    p_kaynak_kasa_id, p_hedef_kasa_id,
    p_tutar, nullif(trim(coalesce(p_aciklama, '')), ''), p_kullanici
  );

  insert into public.kasa_hareket(
    tarih, kasa_id, tip, tutar, aciklama,
    cari_id, kullanici, belge_no
  )
  values(
    coalesce(p_tarih, now()),
    p_kaynak_kasa_id,
    'CIKIS',
    p_tutar,
    'Transfer çıkış → ' || v_hedef_adi ||
      case
        when nullif(trim(coalesce(p_aciklama, '')), '') is null then ''
        else ' | ' || trim(p_aciklama)
      end,
    null,
    p_kullanici,
    v_transfer_no
  );

  insert into public.kasa_hareket(
    tarih, kasa_id, tip, tutar, aciklama,
    cari_id, kullanici, belge_no
  )
  values(
    coalesce(p_tarih, now()),
    p_hedef_kasa_id,
    'GIRIS',
    p_tutar,
    'Transfer giriş ← ' || v_kaynak_adi ||
      case
        when nullif(trim(coalesce(p_aciklama, '')), '') is null then ''
        else ' | ' || trim(p_aciklama)
      end,
    null,
    p_kullanici,
    v_transfer_no
  );

  return v_transfer_no;
end;
$function$;

-- gider_iptal(p_gider_id bigint, p_aciklama text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.gider_iptal(p_gider_id bigint, p_aciklama text DEFAULT NULL::text, p_kullanici text DEFAULT NULL::text)
 RETURNS boolean
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_gider public.giderler%rowtype;
begin
  select *
  into v_gider
  from public.giderler
  where gider_id = p_gider_id
  for update;

  if not found then
    raise exception 'Gider kaydı bulunamadı.';
  end if;

  if v_gider.iptal then
    raise exception 'Bu gider zaten iptal edilmiş.';
  end if;

  update public.giderler
  set
    iptal = true,
    iptal_tarihi = now(),
    iptal_aciklama =
      nullif(trim(coalesce(p_aciklama, '')), '')
  where gider_id = p_gider_id;

  -- Gider iptalinde para tekrar aynı hesaba girer.
  insert into public.kasa_hareket (
    tarih,
    kasa_id,
    tip,
    tutar,
    belge_no,
    aciklama,
    cari_id,
    kullanici
  )
  values (
    now(),
    v_gider.kasa_id,
    'GIRIS',
    v_gider.tutar,
    v_gider.gider_no,
    'GİDER İPTALİ - ' || v_gider.kategori ||
      case
        when nullif(trim(coalesce(p_aciklama, '')), '') is not null
          then ' - ' || trim(p_aciklama)
        else ''
      end,
    v_gider.cari_id,
    nullif(trim(coalesce(p_kullanici, '')), '')
  );

  return true;
end;
$function$;

-- gider_kaydet(p_tarih timestamp with time zone, p_kategori text, p_tutar numeric, p_kasa_id bigint, p_cari_id bigint, p_belge_no text, p_aciklama text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.gider_kaydet(p_tarih timestamp with time zone, p_kategori text, p_tutar numeric, p_kasa_id bigint, p_cari_id bigint DEFAULT NULL::bigint, p_belge_no text DEFAULT NULL::text, p_aciklama text DEFAULT NULL::text, p_kullanici text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_gider_id bigint;
  v_gider_no text;
begin
  if p_tutar is null or p_tutar <= 0 then
    raise exception 'Gider tutarı 0 dan büyük olmalıdır.';
  end if;

  if p_kasa_id is null then
    raise exception 'Ödeme hesabı seçilmelidir.';
  end if;

  if coalesce(trim(p_kategori), '') = '' then
    raise exception 'Gider kategorisi boş olamaz.';
  end if;

  v_gider_no :=
    'GDR-' ||
    to_char(coalesce(p_tarih, now()), 'YYYYMMDD') ||
    '-' ||
    lpad(nextval('public.gider_no_seq')::text, 6, '0');

  insert into public.giderler (
    gider_no,
    tarih,
    kategori,
    tutar,
    kasa_id,
    cari_id,
    belge_no,
    aciklama,
    kullanici
  )
  values (
    v_gider_no,
    coalesce(p_tarih, now()),
    trim(p_kategori),
    p_tutar,
    p_kasa_id,
    p_cari_id,
    nullif(trim(coalesce(p_belge_no, '')), ''),
    nullif(trim(coalesce(p_aciklama, '')), ''),
    nullif(trim(coalesce(p_kullanici, '')), '')
  )
  returning gider_id into v_gider_id;

  insert into public.kasa_hareket (
    tarih,
    kasa_id,
    tip,
    tutar,
    belge_no,
    aciklama,
    cari_id,
    kullanici
  )
  values (
    coalesce(p_tarih, now()),
    p_kasa_id,
    'CIKIS',
    p_tutar,
    v_gider_no,
    'GİDER - ' || trim(p_kategori) ||
      case
        when nullif(trim(coalesce(p_aciklama, '')), '') is not null
          then ' - ' || trim(p_aciklama)
        else ''
      end,
    p_cari_id,
    nullif(trim(coalesce(p_kullanici, '')), '')
  );

  return v_gider_id;
end;
$function$;

-- gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gin_extract_query_trgm(text, internal, smallint, internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_query_trgm$function$;

-- gin_extract_value_trgm(text, internal)
CREATE OR REPLACE FUNCTION public.gin_extract_value_trgm(text, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_extract_value_trgm$function$;

-- gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gin_trgm_consistent(internal, smallint, text, integer, internal, internal, internal, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_consistent$function$;

-- gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gin_trgm_triconsistent(internal, smallint, text, integer, internal, internal, internal)
 RETURNS "char"
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gin_trgm_triconsistent$function$;

-- gtrgm_compress(internal)
CREATE OR REPLACE FUNCTION public.gtrgm_compress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_compress$function$;

-- gtrgm_consistent(internal, text, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gtrgm_consistent(internal, text, smallint, oid, internal)
 RETURNS boolean
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_consistent$function$;

-- gtrgm_decompress(internal)
CREATE OR REPLACE FUNCTION public.gtrgm_decompress(internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_decompress$function$;

-- gtrgm_distance(internal, text, smallint, oid, internal)
CREATE OR REPLACE FUNCTION public.gtrgm_distance(internal, text, smallint, oid, internal)
 RETURNS double precision
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_distance$function$;

-- gtrgm_in(cstring)
CREATE OR REPLACE FUNCTION public.gtrgm_in(cstring)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_in$function$;

-- gtrgm_options(internal)
CREATE OR REPLACE FUNCTION public.gtrgm_options(internal)
 RETURNS void
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE
AS '$libdir/pg_trgm', $function$gtrgm_options$function$;

-- gtrgm_out(gtrgm)
CREATE OR REPLACE FUNCTION public.gtrgm_out(gtrgm)
 RETURNS cstring
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_out$function$;

-- gtrgm_penalty(internal, internal, internal)
CREATE OR REPLACE FUNCTION public.gtrgm_penalty(internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_penalty$function$;

-- gtrgm_picksplit(internal, internal)
CREATE OR REPLACE FUNCTION public.gtrgm_picksplit(internal, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_picksplit$function$;

-- gtrgm_same(gtrgm, gtrgm, internal)
CREATE OR REPLACE FUNCTION public.gtrgm_same(gtrgm, gtrgm, internal)
 RETURNS internal
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_same$function$;

-- gtrgm_union(internal, internal)
CREATE OR REPLACE FUNCTION public.gtrgm_union(internal, internal)
 RETURNS gtrgm
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$gtrgm_union$function$;

-- iade_kontrol_sonucu(p_stok_id bigint, p_miktar numeric, p_sonuc text, p_hedef_normal_depo_id bigint, p_aciklama text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.iade_kontrol_sonucu(p_stok_id bigint, p_miktar numeric, p_sonuc text, p_hedef_normal_depo_id bigint DEFAULT NULL::bigint, p_aciklama text DEFAULT NULL::text, p_kullanici text DEFAULT 'UNAL'::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_iade_depo_id bigint;
    v_hedef_depo_id bigint;
BEGIN
    SELECT depo_id
    INTO v_iade_depo_id
    FROM public.depolar
    WHERE depo_tipi = 'IADE'
      AND aktif = true
    ORDER BY depo_id
    LIMIT 1;

    IF v_iade_depo_id IS NULL THEN
        RAISE EXCEPTION 'Aktif İade Deposu bulunamadı.';
    END IF;

    IF UPPER(TRIM(p_sonuc)) = 'SAGLAM' THEN
        IF p_hedef_normal_depo_id IS NOT NULL THEN
            SELECT depo_id
            INTO v_hedef_depo_id
            FROM public.depolar
            WHERE depo_id = p_hedef_normal_depo_id
              AND depo_tipi = 'NORMAL'
              AND aktif = true
              AND satilabilir = true;
        ELSE
            SELECT depo_id
            INTO v_hedef_depo_id
            FROM public.depolar
            WHERE depo_tipi = 'NORMAL'
              AND aktif = true
              AND satilabilir = true
            ORDER BY depo_id
            LIMIT 1;
        END IF;

        IF v_hedef_depo_id IS NULL THEN
            RAISE EXCEPTION 'Aktif satılabilir normal depo bulunamadı.';
        END IF;

    ELSIF UPPER(TRIM(p_sonuc)) = 'HASARLI' THEN
        SELECT depo_id
        INTO v_hedef_depo_id
        FROM public.depolar
        WHERE depo_tipi = 'HASARLI'
          AND aktif = true
        ORDER BY depo_id
        LIMIT 1;

        IF v_hedef_depo_id IS NULL THEN
            RAISE EXCEPTION 'Aktif Hasarlı Deposu bulunamadı.';
        END IF;

    ELSE
        RAISE EXCEPTION
            'Geçersiz kontrol sonucu. SAGLAM veya HASARLI kullanılmalıdır.';
    END IF;

    RETURN public.depolar_arasi_transfer(
        p_stok_id,
        v_iade_depo_id,
        v_hedef_depo_id,
        p_miktar,
        'IADE_KONTROL',
        NULL,
        NULL,
        p_aciklama,
        p_kullanici
    );
END;
$function$;

-- irsaliye_guncelleme_tarihi()
CREATE OR REPLACE FUNCTION public.irsaliye_guncelleme_tarihi()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    NEW.guncelleme_tarihi := now();
    RETURN NEW;
END;
$function$;

-- kasa_cari_islemi_kaydet(p_islem_tipi text, p_cari_id bigint, p_kasa_id bigint, p_tutar numeric, p_belge_no text, p_aciklama text, p_tarih timestamp with time zone, p_kullanici text)
CREATE OR REPLACE FUNCTION public.kasa_cari_islemi_kaydet(p_islem_tipi text, p_cari_id bigint, p_kasa_id bigint, p_tutar numeric, p_belge_no text, p_aciklama text, p_tarih timestamp with time zone, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_islem_tipi text;
    v_kasa_hareket_tipi text;
    v_cari_borc numeric := 0;
    v_cari_alacak numeric := 0;
BEGIN
    v_islem_tipi :=
        upper(trim(p_islem_tipi));

    IF v_islem_tipi NOT IN (
        'TAHSILAT',
        'ODEME'
    ) THEN
        RAISE EXCEPTION
            'Geçersiz işlem tipi: %',
            p_islem_tipi;
    END IF;

    IF p_tutar IS NULL OR p_tutar <= 0 THEN
        RAISE EXCEPTION
            'Tutar sıfırdan büyük olmalıdır.';
    END IF;

    IF trim(COALESCE(p_belge_no, '')) = '' THEN
        RAISE EXCEPTION
            'Belge numarası boş bırakılamaz.';
    END IF;

    PERFORM 1
    FROM public.cariler
    WHERE cari_id = p_cari_id
      AND COALESCE(aktif, true) = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Cari bulunamadı veya pasif. Cari ID: %',
            p_cari_id;
    END IF;

    PERFORM 1
    FROM public.kasalar
    WHERE kasa_id = p_kasa_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Kasa veya banka bulunamadı. Kasa ID: %',
            p_kasa_id;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.kasa_hareket
        WHERE upper(trim(COALESCE(belge_no, ''))) =
              upper(trim(p_belge_no))
    ) THEN
        RAISE EXCEPTION
            'Bu belge numarası daha önce kullanılmış: %',
            p_belge_no;
    END IF;

    IF v_islem_tipi = 'TAHSILAT' THEN
        v_kasa_hareket_tipi := 'GIRIS';
        v_cari_borc := 0;
        v_cari_alacak := p_tutar;
    ELSE
        v_kasa_hareket_tipi := 'CIKIS';
        v_cari_borc := p_tutar;
        v_cari_alacak := 0;
    END IF;

    INSERT INTO public.kasa_hareket
    (
        tarih,
        kasa_id,
        tip,
        tutar,
        belge_no,
        aciklama,
        cari_id,
        kullanici
    )
    VALUES
    (
        COALESCE(p_tarih, now()),
        p_kasa_id,
        v_kasa_hareket_tipi,
        p_tutar,
        trim(p_belge_no),
        CASE
            WHEN trim(COALESCE(p_aciklama, '')) = ''
            THEN v_islem_tipi
            ELSE trim(p_aciklama)
        END,
        p_cari_id,
        p_kullanici
    );

    INSERT INTO public.cari_hareket
    (
        tarih,
        cari_id,
        islem_tipi,
        belge_no,
        borc,
        alacak,
        aciklama,
        kullanici
    )
    VALUES
    (
        COALESCE(p_tarih, now()),
        p_cari_id,
        v_islem_tipi,
        trim(p_belge_no),
        v_cari_borc,
        v_cari_alacak,
        CASE
            WHEN trim(COALESCE(p_aciklama, '')) = ''
            THEN v_islem_tipi
            ELSE trim(p_aciklama)
        END,
        p_kullanici
    );

    -- Tahsilat da ödeme de açık cari bakiyesini azaltır.
    UPDATE public.cariler
    SET bakiye =
        COALESCE(bakiye, 0) - p_tutar
    WHERE cari_id = p_cari_id;
END;
$function$;

-- kasa_hareket_ekle(p_kasa_id bigint, p_cari_id bigint, p_tip character varying, p_tutar numeric, p_aciklama text, p_kullanici character varying)
CREATE OR REPLACE FUNCTION public.kasa_hareket_ekle(p_kasa_id bigint, p_cari_id bigint, p_tip character varying, p_tutar numeric, p_aciklama text, p_kullanici character varying)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

    INSERT INTO kasa_hareket
    (
        tarih,
        kasa_id,
        cari_id,
        tip,
        tutar,
        aciklama,
        kullanici
    )
    VALUES
    (
        now(),
        p_kasa_id,
        p_cari_id,
        p_tip,
        p_tutar,
        p_aciklama,
        p_kullanici
    );

END;
$function$;

-- kasa_makbuzu_iptal_et(p_hareket_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.kasa_makbuzu_iptal_et(p_hareket_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_cari_id bigint;
    v_kasa_id bigint;
    v_tutar numeric;
    v_belge_no text;
    v_kasa_tipi text;
    v_aciklama text;
    v_islem_tipi text;
    v_ters_kasa_tipi text;
    v_ters_borc numeric := 0;
    v_ters_alacak numeric := 0;
BEGIN
    SELECT
        kh.cari_id,
        kh.kasa_id,
        COALESCE(kh.tutar, 0),
        kh.belge_no,
        kh.tip,
        kh.aciklama
    INTO
        v_cari_id,
        v_kasa_id,
        v_tutar,
        v_belge_no,
        v_kasa_tipi,
        v_aciklama
    FROM public.kasa_hareket AS kh
    WHERE kh.hareket_id = p_hareket_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Kasa hareketi bulunamadı. Hareket ID: %',
            p_hareket_id;
    END IF;

    IF v_cari_id IS NULL THEN
        RAISE EXCEPTION
            'Bu kasa hareketinin cari bilgisi bulunmuyor.';
    END IF;

    IF UPPER(COALESCE(v_aciklama, ''))
        LIKE '%IPTAL EDILDI%'
       OR UPPER(COALESCE(v_aciklama, ''))
        LIKE '%İPTAL EDİLDİ%' THEN
        RAISE EXCEPTION
            'Bu makbuz daha önce iptal edilmiş.';
    END IF;

    SELECT ch.islem_tipi
    INTO v_islem_tipi
    FROM public.cari_hareket AS ch
    WHERE ch.cari_id = v_cari_id
      AND UPPER(TRIM(COALESCE(ch.belge_no, ''))) =
          UPPER(TRIM(COALESCE(v_belge_no, '')))
      AND UPPER(COALESCE(ch.islem_tipi, '')) IN
          ('TAHSILAT', 'TAHSİLAT', 'ODEME', 'ÖDEME')
    ORDER BY ch.hareket_id DESC
    LIMIT 1;

    IF v_islem_tipi IS NULL THEN
        IF UPPER(COALESCE(v_kasa_tipi, '')) IN
            ('GIRIS', 'GİRİŞ') THEN
            v_islem_tipi := 'TAHSILAT';
        ELSE
            v_islem_tipi := 'ODEME';
        END IF;
    END IF;

    IF UPPER(v_islem_tipi) IN
        ('TAHSILAT', 'TAHSİLAT') THEN
        v_ters_kasa_tipi := 'CIKIS';
        v_ters_borc := v_tutar;
        v_ters_alacak := 0;
    ELSE
        v_ters_kasa_tipi := 'GIRIS';
        v_ters_borc := 0;
        v_ters_alacak := v_tutar;
    END IF;

    INSERT INTO public.kasa_hareket
    (
        tarih,
        kasa_id,
        tip,
        tutar,
        belge_no,
        aciklama,
        cari_id,
        kullanici
    )
    VALUES
    (
        NOW(),
        v_kasa_id,
        v_ters_kasa_tipi,
        v_tutar,
        COALESCE(v_belge_no, '') || '-IPTAL',
        'Makbuz iptal ters kaydı. Hareket ID: '
            || p_hareket_id,
        v_cari_id,
        p_kullanici
    );

    INSERT INTO public.cari_hareket
    (
        tarih,
        cari_id,
        islem_tipi,
        belge_no,
        borc,
        alacak,
        aciklama,
        kullanici
    )
    VALUES
    (
        NOW(),
        v_cari_id,
        CASE
            WHEN UPPER(v_islem_tipi) IN
                ('TAHSILAT', 'TAHSİLAT')
            THEN 'TAHSILAT_IPTAL'
            ELSE 'ODEME_IPTAL'
        END,
        COALESCE(v_belge_no, '') || '-IPTAL',
        v_ters_borc,
        v_ters_alacak,
        'Makbuz iptal ters kaydı. Kasa hareket ID: '
            || p_hareket_id,
        p_kullanici
    );

    UPDATE public.kasa_hareket
    SET aciklama =
        COALESCE(aciklama, '')
        || ' | IPTAL EDILDI'
    WHERE hareket_id = p_hareket_id;

    UPDATE public.cariler AS c
    SET bakiye = COALESCE(
        (
            SELECT
                SUM(COALESCE(ch.borc, 0))
                - SUM(COALESCE(ch.alacak, 0))
            FROM public.cari_hareket AS ch
            WHERE ch.cari_id = c.cari_id
        ),
        0
    )
    WHERE c.cari_id = v_cari_id;
END;
$function$;

-- normalize_text(txt text)
CREATE OR REPLACE FUNCTION public.normalize_text(txt text)
 RETURNS text
 LANGUAGE sql
 IMMUTABLE
AS $function$
SELECT regexp_replace(
         public.unaccent(lower(coalesce(txt,''))),
         '[^a-z0-9]+',
         ' ',
         'g'
       );
$function$;

-- pro_konsinye_stok_hareket_tipi()
CREATE OR REPLACE FUNCTION public.pro_konsinye_stok_hareket_tipi()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
begin
    if upper(coalesce(new.islem_tipi, '')) in ('SATIS_IRSALIYE', 'SATIŞ_IRSALIYE') then
        if exists (
            select 1
              from public.satis_irsaliye_baslik b
             where b.irsaliye_no = new.belge_no
               and coalesce(b.konsinye, false) = true
        ) then
            new.islem_tipi := 'KONSINYE_CIKIS';
            new.hareket_tipi := 'CIKIS';
            new.aciklama := coalesce(nullif(new.aciklama, ''), 'Konsinye çıkış');
        end if;
    elsif upper(coalesce(new.islem_tipi, '')) in ('ALIS_IRSALIYE', 'ALIŞ_IRSALIYE') then
        if exists (
            select 1
              from public.alis_irsaliye_baslik b
             where b.irsaliye_no = new.belge_no
               and coalesce(b.konsinye, false) = true
        ) then
            new.islem_tipi := 'KONSINYE_GIRIS';
            new.hareket_tipi := 'GIRIS';
            new.aciklama := coalesce(nullif(new.aciklama, ''), 'Konsinye giriş');
        end if;
    end if;

    return new;
end;
$function$;

-- pro_transfer_stok_hareketleri()
CREATE OR REPLACE FUNCTION public.pro_transfer_stok_hareketleri()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_kaynak_son numeric := 0;
    v_hedef_son numeric := 0;
    v_belge_no text;
begin
    if upper(coalesce(new.hareket_tipi, '')) <> 'TRANSFER' then
        return new;
    end if;

    if new.kaynak_depo_id is null or new.hedef_depo_id is null then
        return new;
    end if;

    select coalesce(miktar, 0)
      into v_kaynak_son
      from public.stok_depo_bakiye
     where stok_id = new.stok_id
       and depo_id = new.kaynak_depo_id
     limit 1;

    select coalesce(miktar, 0)
      into v_hedef_son
      from public.stok_depo_bakiye
     where stok_id = new.stok_id
       and depo_id = new.hedef_depo_id
     limit 1;

    v_belge_no := coalesce(
        nullif(trim(new.belge_no), ''),
        'TRF-' || new.hareket_id::text
    );

    -- Aynı depo_hareketi için tekrar insert edilmesini önle.
    if not exists (
        select 1
          from public.stok_hareket h
         where h.stok_id = new.stok_id
           and h.depo_id = new.kaynak_depo_id
           and h.belge_no = v_belge_no
           and h.islem_tipi = 'TRANSFER_CIKIS'
    ) then
        insert into public.stok_hareket (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            hareket_tipi,
            miktar,
            onceki_stok,
            sonraki_stok,
            belge_no,
            aciklama,
            depo_id
        ) values (
            coalesce(new.tarih, now()),
            coalesce(nullif(trim(new.kullanici), ''), 'UNAL'),
            new.stok_id,
            'TRANSFER_CIKIS',
            'CIKIS',
            abs(new.miktar),
            v_kaynak_son + abs(new.miktar),
            v_kaynak_son,
            v_belge_no,
            'Depolar arası transfer çıkışı',
            new.kaynak_depo_id
        );
    end if;

    if not exists (
        select 1
          from public.stok_hareket h
         where h.stok_id = new.stok_id
           and h.depo_id = new.hedef_depo_id
           and h.belge_no = v_belge_no
           and h.islem_tipi = 'TRANSFER_GIRIS'
    ) then
        insert into public.stok_hareket (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            hareket_tipi,
            miktar,
            onceki_stok,
            sonraki_stok,
            belge_no,
            aciklama,
            depo_id
        ) values (
            coalesce(new.tarih, now()),
            coalesce(nullif(trim(new.kullanici), ''), 'UNAL'),
            new.stok_id,
            'TRANSFER_GIRIS',
            'GIRIS',
            abs(new.miktar),
            greatest(v_hedef_son - abs(new.miktar), 0),
            v_hedef_son,
            v_belge_no,
            'Depolar arası transfer girişi',
            new.hedef_depo_id
        );
    end if;

    return new;
end;
$function$;

-- satis_baslik_irsaliye_no_doldur()
CREATE OR REPLACE FUNCTION public.satis_baslik_irsaliye_no_doldur()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    IF NEW.irsaliye_id IS NOT NULL THEN
        SELECT irsaliye_no
        INTO NEW.irsaliye_no
        FROM public.satis_irsaliye_baslik
        WHERE irsaliye_id = NEW.irsaliye_id;
    ELSE
        NEW.irsaliye_no := NULL;
    END IF;

    RETURN NEW;
END;
$function$;

-- satis_cari_degistir(p_satis_id bigint, p_yeni_cari_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.satis_cari_degistir(p_satis_id bigint, p_yeni_cari_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_eski_cari_id bigint;
    v_genel_toplam numeric;
    v_fatura_no text;
    v_belge_no text;
    v_satis_tarihi timestamptz;
BEGIN
    SELECT
        sb.cari_id,
        COALESCE(sb.genel_toplam, 0),
        sb.fatura_no,
        sb.belge_no,
        sb.tarih
    INTO
        v_eski_cari_id,
        v_genel_toplam,
        v_fatura_no,
        v_belge_no,
        v_satis_tarihi
    FROM public.satis_baslik AS sb
    WHERE sb.satis_id = p_satis_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Satış faturası bulunamadı. Satış ID: %',
            p_satis_id;
    END IF;

    IF v_eski_cari_id = p_yeni_cari_id THEN
        RAISE EXCEPTION
            'Seçilen cari zaten faturanın mevcut carisidir.';
    END IF;

    PERFORM 1
    FROM public.cariler AS c
    WHERE c.cari_id = p_yeni_cari_id
      AND COALESCE(c.aktif, true) = true;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Yeni cari bulunamadı veya pasif. Cari ID: %',
            p_yeni_cari_id;
    END IF;

    UPDATE public.satis_baslik
    SET cari_id = p_yeni_cari_id
    WHERE satis_id = p_satis_id;

    UPDATE public.stok_hareket
    SET cari_id = p_yeni_cari_id
    WHERE satis_ref = p_satis_id;

    UPDATE public.cari_hareket
    SET
        cari_id = p_yeni_cari_id,
        aciklama =
            COALESCE(aciklama, '')
            || ' | Cari değiştirildi. Eski Cari ID: '
            || v_eski_cari_id
            || ', Kullanıcı: '
            || COALESCE(p_kullanici, '')
    WHERE cari_id = v_eski_cari_id
      AND belge_no = COALESCE(
          NULLIF(TRIM(v_belge_no), ''),
          v_fatura_no
      )
      AND UPPER(COALESCE(islem_tipi, '')) IN
          ('SATIS', 'SATIŞ', 'TAHSILAT', 'TAHSİLAT');

    UPDATE public.kasa_hareket
    SET cari_id = p_yeni_cari_id
    WHERE cari_id = v_eski_cari_id
      AND aciklama ILIKE
          '%' || COALESCE(v_fatura_no, '') || '%';

    UPDATE public.cariler AS c
    SET
        bakiye = COALESCE((
            SELECT
                SUM(COALESCE(ch.borc, 0))
                - SUM(COALESCE(ch.alacak, 0))
            FROM public.cari_hareket AS ch
            WHERE ch.cari_id = c.cari_id
        ), 0),
        son_satis_tarihi = (
            SELECT MAX(sb.tarih)
            FROM public.satis_baslik AS sb
            WHERE sb.cari_id = c.cari_id
        )
    WHERE c.cari_id IN (
        v_eski_cari_id,
        p_yeni_cari_id
    );
END;
$function$;

-- satis_fatura_irsaliye_aktar(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_depo_id bigint, p_fiyat_tipi text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.satis_fatura_irsaliye_aktar(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_depo_id bigint, p_fiyat_tipi text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_item jsonb;

    v_irsaliye_id bigint;
    v_irsaliye_detay_id bigint;
    v_stok_id bigint;
    v_miktar integer;
    v_birim_fiyat numeric;
    v_indirim numeric;
    v_kdv_orani integer;

    v_detay public.satis_irsaliye_detay%ROWTYPE;
    v_baslik public.satis_irsaliye_baslik%ROWTYPE;

    v_satis_detaylari jsonb := '[]'::jsonb;
    v_satis_id bigint;
    v_kalan_toplam numeric;
BEGIN
    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION 'Cari seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION 'Depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION 'Faturaya aktarılacak irsaliye kalemi yok.';
    END IF;

    ------------------------------------------------------------
    -- 1. İRSALİYE SATIRLARINI KONTROL ET
    --    ve satis_olustur için geçici olarak stoğu geri koy.
    ------------------------------------------------------------
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_irsaliye_id :=
            nullif(v_item->>'irsaliye_id', '')::bigint;

        v_irsaliye_detay_id :=
            nullif(v_item->>'irsaliye_detay_id', '')::bigint;

        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::integer,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::integer,
                0
            );

        IF v_irsaliye_id IS NULL
           OR v_irsaliye_detay_id IS NULL THEN
            RAISE EXCEPTION
                'İrsaliye aktarımında her satır kaynak irsaliyeye bağlı olmalıdır.';
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'Fatura miktarı sıfırdan büyük olmalıdır.';
        END IF;

        SELECT *
        INTO v_baslik
        FROM public.satis_irsaliye_baslik
        WHERE irsaliye_id = v_irsaliye_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Satış irsaliyesi bulunamadı. ID: %',
                v_irsaliye_id;
        END IF;

        IF v_baslik.cari_id <> p_cari_id
           OR v_baslik.depo_id <> p_depo_id THEN
            RAISE EXCEPTION
                'İrsaliye cari/depo bilgisi faturayla uyuşmuyor. İrsaliye: %',
                v_baslik.irsaliye_no;
        END IF;

        IF upper(coalesce(v_baslik.durum, '')) <> 'ONAYLANDI' THEN
            RAISE EXCEPTION
                'Yalnızca ONAYLANDI durumundaki irsaliye faturalanabilir. İrsaliye: %, Durum: %',
                v_baslik.irsaliye_no,
                v_baslik.durum;
        END IF;

        SELECT *
        INTO v_detay
        FROM public.satis_irsaliye_detay
        WHERE detay_id = v_irsaliye_detay_id
          AND irsaliye_id = v_irsaliye_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'İrsaliye detayı bulunamadı. Detay ID: %',
                v_irsaliye_detay_id;
        END IF;

        IF v_detay.stok_id <> v_stok_id THEN
            RAISE EXCEPTION
                'İrsaliye detayı ile stok kartı uyuşmuyor.';
        END IF;

        IF v_miktar > v_detay.kalan_miktar THEN
            RAISE EXCEPTION
                'Fatura miktarı kalan irsaliye miktarını aşamaz. '
                'İrsaliye: %, Kalan: %, İstenen: %',
                v_baslik.irsaliye_no,
                v_detay.kalan_miktar,
                v_miktar;
        END IF;

        -- İrsaliye ONAYINDA bu miktar stoktan zaten çıktı.
        -- satis_olustur stok kontrolü yapacağı için transaction içinde
        -- miktarı geçici olarak geri koyuyoruz. satis_olustur tekrar
        -- düşürdüğünde fiziksel stok net olarak değişmeyecek.
        UPDATE public.stoklar
        SET stok_miktari =
            coalesce(stok_miktari, 0) + v_miktar
        WHERE stok_id = v_stok_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_stok_id;
        END IF;

        v_satis_detaylari :=
            v_satis_detaylari ||
            jsonb_build_array(
                jsonb_build_object(
                    'stok_id', v_stok_id,
                    'miktar', v_miktar,
                    'birim_fiyat', v_birim_fiyat,
                    'indirim', v_indirim,
                    'kdv_orani', v_kdv_orani
                )
            );
    END LOOP;

    ------------------------------------------------------------
    -- 2. NORMAL SATIŞ FATURASINI OLUŞTUR
    --    Cari, kasa, risk, fiyat, KDV gibi mevcut kurallar aynen çalışır.
    ------------------------------------------------------------
    v_satis_id := public.satis_olustur(
        p_cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        p_belge_no,
        p_depo_id,
        coalesce(
            nullif(trim(p_fiyat_tipi), ''),
            'PERAKENDE'
        ),
        p_kullanici,
        v_satis_detaylari
    );

    ------------------------------------------------------------
    -- 3. İRSALİYE FATURALANAN MİKTARLARINI GÜNCELLE
    ------------------------------------------------------------
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_irsaliye_id :=
            (v_item->>'irsaliye_id')::bigint;

        v_irsaliye_detay_id :=
            (v_item->>'irsaliye_detay_id')::bigint;

        v_miktar :=
            (v_item->>'miktar')::integer;

        UPDATE public.satis_irsaliye_detay
        SET
            faturalanan_miktar =
                faturalanan_miktar + v_miktar,
            durum = CASE
                WHEN faturalanan_miktar + v_miktar >= miktar
                    THEN 'FATURALANDI'
                ELSE 'KISMI_FATURALANDI'
            END,
            guncelleme_tarihi = now()
        WHERE detay_id = v_irsaliye_detay_id
          AND irsaliye_id = v_irsaliye_id;

        INSERT INTO public.satis_irsaliye_fatura (
            irsaliye_id,
            satis_id,
            tarih,
            kullanici,
            aciklama
        )
        VALUES (
            v_irsaliye_id,
            v_satis_id,
            now(),
            p_kullanici,
            'Satış faturası ekranından İrsaliye Aktar ile faturalandı.'
        )
        ON CONFLICT (irsaliye_id, satis_id)
        DO NOTHING;
    END LOOP;

    ------------------------------------------------------------
    -- 4. İRSALİYE BAŞLIK DURUMLARI
    ------------------------------------------------------------
    FOR v_irsaliye_id IN
        SELECT DISTINCT
            (value->>'irsaliye_id')::bigint
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        SELECT coalesce(sum(kalan_miktar), 0)
        INTO v_kalan_toplam
        FROM public.satis_irsaliye_detay
        WHERE irsaliye_id = v_irsaliye_id
          AND durum <> 'IPTAL';

        UPDATE public.satis_irsaliye_baslik
        SET
            durum = CASE
                WHEN v_kalan_toplam <= 0
                    THEN 'FATURALANDI'
                ELSE 'ONAYLANDI'
            END,
            guncelleme_tarihi = now()
        WHERE irsaliye_id = v_irsaliye_id;
    END LOOP;

    ------------------------------------------------------------
    -- 5. STOK HAREKETİNİ SİL
    -- Fiziksel stok irsaliye onayında zaten hareket etmişti.
    -- Fatura yalnızca finansal belge ve irsaliye bağlantısı oluşturur.
    ------------------------------------------------------------
    DELETE FROM public.stok_hareket
    WHERE satis_ref = v_satis_id
      AND upper(coalesce(islem_tipi, ''))
          IN ('SATIS', 'SATIŞ');

    RETURN v_satis_id;
END;
$function$;

-- satis_fatura_no_otomatik()
CREATE OR REPLACE FUNCTION public.satis_fatura_no_otomatik()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    IF coalesce(trim(NEW.fatura_no), '') = '' THEN
        NEW.fatura_no :=
            public.yeni_belge_no('SATIS');
    END IF;

    RETURN NEW;
END;
$function$;

-- satis_faturasi_iptal_et(p_satis_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.satis_faturasi_iptal_et(p_satis_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_cari_id bigint;
    v_kasa_id bigint;
    v_depo_id bigint;

    v_fatura_no text;
    v_belge_no text;
    v_odeme_tipi text;
    v_durum text;

    v_genel_toplam numeric := 0;
    v_veresiye boolean := false;

    v_detay record;

    v_onceki_stok integer;
    v_sonraki_stok integer;
BEGIN
    ------------------------------------------------------
    -- SATIŞ BAŞLIĞINI KİLİTLE VE KONTROL ET
    ------------------------------------------------------

    SELECT
        sb.cari_id,
        sb.kasa_id,
        sb.depo_id,
        sb.fatura_no,
        sb.belge_no,
        sb.odeme_tipi,
        sb.durum,
        COALESCE(sb.genel_toplam, 0)
    INTO
        v_cari_id,
        v_kasa_id,
        v_depo_id,
        v_fatura_no,
        v_belge_no,
        v_odeme_tipi,
        v_durum,
        v_genel_toplam
    FROM public.satis_baslik AS sb
    WHERE sb.satis_id = p_satis_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Satış faturası bulunamadı. Satış ID: %',
            p_satis_id;
    END IF;

    IF UPPER(COALESCE(v_durum, '')) IN ('IPTAL', 'İPTAL') THEN
        RAISE EXCEPTION
            'Bu satış faturası daha önce iptal edilmiş.';
    END IF;

    v_veresiye :=
        LOWER(TRIM(COALESCE(v_odeme_tipi, ''))) IN
        ('veresiye', 'hesap');

    ------------------------------------------------------
    -- SATILAN ÜRÜNLERİ STOĞA GERİ EKLE
    ------------------------------------------------------

    FOR v_detay IN
        SELECT
            sd.stok_id,
            COALESCE(sd.miktar, 0)::integer AS miktar,
            COALESCE(sd.alis_fiyati, 0) AS alis_fiyati
        FROM public.satis_detay AS sd
        WHERE sd.satis_id = p_satis_id
        ORDER BY sd.stok_id
    LOOP
        SELECT
            COALESCE(s.stok_miktari, 0)::integer
        INTO
            v_onceki_stok
        FROM public.stoklar AS s
        WHERE s.stok_id = v_detay.stok_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_detay.stok_id;
        END IF;

        v_sonraki_stok :=
            v_onceki_stok + v_detay.miktar;

        UPDATE public.stoklar
        SET stok_miktari = v_sonraki_stok
        WHERE stok_id = v_detay.stok_id;

        INSERT INTO public.stok_hareket
        (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            miktar,
            belge_no,
            aciklama,
            depo_id,
            cari_id,
            satis_ref,
            fatura_no,
            onceki_stok,
            sonraki_stok,
            birim_maliyet,
            hareket_tipi
        )
        VALUES
        (
            NOW(),
            p_kullanici,
            v_detay.stok_id,
            'SATIS_IPTAL',
            v_detay.miktar,
            COALESCE(
                NULLIF(TRIM(v_belge_no), ''),
                v_fatura_no
            ),
            'Satış faturası iptali',
            v_depo_id,
            v_cari_id,
            p_satis_id,
            v_fatura_no,
            v_onceki_stok,
            v_sonraki_stok,
            v_detay.alis_fiyati,
            'GIRIS'
        );
    END LOOP;

    ------------------------------------------------------
    -- SATIŞ BORCUNU TERS KAYITLA KAPAT
    ------------------------------------------------------

    INSERT INTO public.cari_hareket
    (
        tarih,
        cari_id,
        islem_tipi,
        belge_no,
        borc,
        alacak,
        aciklama,
        kullanici
    )
    VALUES
    (
        NOW(),
        v_cari_id,
        'SATIS_IPTAL',
        COALESCE(
            NULLIF(TRIM(v_belge_no), ''),
            v_fatura_no
        ),
        0,
        v_genel_toplam,
        'Satış faturası iptal kaydı',
        p_kullanici
    );

    ------------------------------------------------------
    -- PEŞİN SATIŞTA TAHSİLATI VE KASAYI TERS ÇEVİR
    ------------------------------------------------------

    IF NOT v_veresiye THEN
        IF v_kasa_id IS NULL THEN
            RAISE EXCEPTION
                'Peşin satışın kasa bilgisi bulunamadı.';
        END IF;

        INSERT INTO public.cari_hareket
        (
            tarih,
            cari_id,
            islem_tipi,
            belge_no,
            borc,
            alacak,
            aciklama,
            kullanici
        )
        VALUES
        (
            NOW(),
            v_cari_id,
            'TAHSILAT_IPTAL',
            COALESCE(
                NULLIF(TRIM(v_belge_no), ''),
                v_fatura_no
            ),
            v_genel_toplam,
            0,
            'Satış tahsilatı iptal kaydı',
            p_kullanici
        );

        INSERT INTO public.kasa_hareket
        (
            tarih,
            tip,
            tutar,
            aciklama,
            cari_id,
            kullanici,
            kasa_id
        )
        VALUES
        (
            NOW(),
            'CIKIS',
            v_genel_toplam,
            'Satış faturası iptali - Fatura: '
                || COALESCE(v_fatura_no, ''),
            v_cari_id,
            p_kullanici,
            v_kasa_id
        );
    END IF;

    ------------------------------------------------------
    -- CARİ BAKİYESİNİ HAREKETLERDEN YENİDEN HESAPLA
    ------------------------------------------------------

    UPDATE public.cariler AS c
    SET bakiye = COALESCE(
        (
            SELECT
                SUM(COALESCE(ch.borc, 0))
                - SUM(COALESCE(ch.alacak, 0))
            FROM public.cari_hareket AS ch
            WHERE ch.cari_id = c.cari_id
        ),
        0
    )
    WHERE c.cari_id = v_cari_id;

    ------------------------------------------------------
    -- FATURAYI İPTAL DURUMUNA GETİR
    ------------------------------------------------------

    UPDATE public.satis_baslik
    SET durum = 'IPTAL'
    WHERE satis_id = p_satis_id;
END;
$function$;

-- satis_hesapla()
CREATE OR REPLACE FUNCTION public.satis_hesapla()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  -- Ara toplam = miktar * fiyat
  NEW.ara_toplam := NEW.miktar * NEW.fiyat;

  -- Genel toplam = ara toplam - iskonto
  NEW.genel_toplam := NEW.ara_toplam - COALESCE(NEW.iskonto,0);

  RETURN NEW;
END;
$function$;

-- satis_iade_deposuna_giris(p_stok_id bigint, p_miktar numeric, p_belge_id bigint, p_belge_no text, p_aciklama text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.satis_iade_deposuna_giris(p_stok_id bigint, p_miktar numeric, p_belge_id bigint DEFAULT NULL::bigint, p_belge_no text DEFAULT NULL::text, p_aciklama text DEFAULT NULL::text, p_kullanici text DEFAULT 'UNAL'::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_iade_depo_id bigint;
    v_hareket_id bigint;
BEGIN
    IF COALESCE(p_miktar, 0) <= 0 THEN
        RAISE EXCEPTION 'İade miktarı sıfırdan büyük olmalıdır.';
    END IF;

    SELECT depo_id
    INTO v_iade_depo_id
    FROM public.depolar
    WHERE depo_tipi = 'IADE'
      AND aktif = true
    ORDER BY depo_id
    LIMIT 1;

    IF v_iade_depo_id IS NULL THEN
        RAISE EXCEPTION 'Aktif İade Deposu bulunamadı.';
    END IF;

    INSERT INTO public.stok_depo_bakiye (
        stok_id,
        depo_id,
        miktar,
        rezerve_miktar,
        son_guncelleme
    )
    VALUES (
        p_stok_id,
        v_iade_depo_id,
        p_miktar,
        0,
        now()
    )
    ON CONFLICT (stok_id, depo_id)
    DO UPDATE SET
        miktar =
            public.stok_depo_bakiye.miktar
            + EXCLUDED.miktar,
        son_guncelleme = now();

    INSERT INTO public.depo_hareketleri (
        stok_id,
        kaynak_depo_id,
        hedef_depo_id,
        hareket_tipi,
        miktar,
        belge_tipi,
        belge_id,
        belge_no,
        aciklama,
        kullanici
    )
    VALUES (
        p_stok_id,
        NULL,
        v_iade_depo_id,
        'SATIS_IADE',
        p_miktar,
        'SATIS_IADE',
        p_belge_id,
        p_belge_no,
        p_aciklama,
        p_kullanici
    )
    RETURNING hareket_id
    INTO v_hareket_id;

    RETURN v_hareket_id;
END;
$function$;

-- satis_irsaliye_aktar_detay(p_irsaliye_ids bigint[])
CREATE OR REPLACE FUNCTION public.satis_irsaliye_aktar_detay(p_irsaliye_ids bigint[])
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
SELECT coalesce(
    jsonb_agg(
        jsonb_build_object(
            'detay_id',
                d.detay_id,
            'irsaliye_id',
                d.irsaliye_id,
            'irsaliye_no',
                b.irsaliye_no,
            'stok_id',
                d.stok_id,
            'miktar',
                d.miktar,
            'faturalanan_miktar',
                d.faturalanan_miktar,
            'kalan_miktar',
                d.kalan_miktar,
            'birim_fiyat',
                d.birim_fiyat,
            'indirim_orani',
                d.indirim_orani,
            'kdv_orani',
                d.kdv_orani,
            'stok',
                to_jsonb(s)
        )
        ORDER BY
            b.tarih,
            b.irsaliye_id,
            d.detay_id
    ),
    '[]'::jsonb
)
FROM public.satis_irsaliye_detay d
JOIN public.satis_irsaliye_baslik b
  ON b.irsaliye_id = d.irsaliye_id
JOIN public.stoklar s
  ON s.stok_id = d.stok_id
WHERE d.irsaliye_id = ANY(p_irsaliye_ids)
  AND b.durum = 'ONAYLANDI'
  AND d.kalan_miktar > 0
  AND d.durum <> 'IPTAL';
$function$;

-- satis_irsaliye_aktar_listesi(p_cari_id bigint, p_depo_id bigint, p_limit integer, p_offset integer)
CREATE OR REPLACE FUNCTION public.satis_irsaliye_aktar_listesi(p_cari_id bigint, p_depo_id bigint, p_limit integer DEFAULT 50, p_offset integer DEFAULT 0)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
WITH aday AS (
    SELECT
        b.irsaliye_id,
        b.irsaliye_no,
        b.tarih,
        count(d.detay_id) AS kalem_sayisi,
        coalesce(
            sum(d.kalan_miktar),
            0
        ) AS kalan_miktar
    FROM public.satis_irsaliye_baslik b
    JOIN public.satis_irsaliye_detay d
      ON d.irsaliye_id = b.irsaliye_id
     AND d.kalan_miktar > 0
     AND d.durum <> 'IPTAL'
    WHERE b.cari_id = p_cari_id
      AND b.depo_id = p_depo_id
      AND b.durum = 'ONAYLANDI'
    GROUP BY
        b.irsaliye_id,
        b.irsaliye_no,
        b.tarih
    ORDER BY
        b.tarih DESC,
        b.irsaliye_id DESC
    LIMIT greatest(1, least(p_limit, 100)) + 1
    OFFSET greatest(p_offset, 0)
),
sinirli AS (
    SELECT *
    FROM aday
    LIMIT greatest(1, least(p_limit, 100))
)
SELECT jsonb_build_object(
    'items',
    coalesce(
        (
            SELECT jsonb_agg(
                jsonb_build_object(
                    'irsaliye_id',
                        irsaliye_id,
                    'irsaliye_no',
                        irsaliye_no,
                    'tarih',
                        tarih,
                    'kalem_sayisi',
                        kalem_sayisi,
                    'kalan_miktar',
                        kalan_miktar
                )
                ORDER BY
                    tarih DESC,
                    irsaliye_id DESC
            )
            FROM sinirli
        ),
        '[]'::jsonb
    ),
    'has_more',
    (
        SELECT count(*)
        FROM aday
    ) > greatest(
        1,
        least(p_limit, 100)
    )
);
$function$;

-- satis_irsaliye_faturala(p_irsaliye_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_fiyat_tipi text, p_kullanici text, p_fatura_detaylari jsonb)
CREATE OR REPLACE FUNCTION public.satis_irsaliye_faturala(p_irsaliye_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_fiyat_tipi text, p_kullanici text, p_fatura_detaylari jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_baslik public.satis_irsaliye_baslik%ROWTYPE;
    v_detay public.satis_irsaliye_detay%ROWTYPE;
    v_item jsonb;
    v_detay_id bigint;
    v_miktar numeric;
    v_satis_id bigint;
    v_satis_detaylari jsonb := '[]'::jsonb;
    v_kalan_toplam numeric;
BEGIN
    SELECT *
    INTO v_baslik
    FROM public.satis_irsaliye_baslik
    WHERE irsaliye_id = p_irsaliye_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Satış irsaliyesi bulunamadı.';
    END IF;

    IF upper(v_baslik.durum) NOT IN ('ONAYLANDI', 'FATURALANDI') THEN
        RAISE EXCEPTION
            'Satış irsaliyesi faturalanabilir durumda değil. Durum: %',
            v_baslik.durum;
    END IF;

    IF p_fatura_detaylari IS NULL
       OR jsonb_typeof(p_fatura_detaylari) <> 'array'
       OR jsonb_array_length(p_fatura_detaylari) = 0 THEN
        RAISE EXCEPTION 'Faturalanacak kalemler boş olamaz.';
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_fatura_detaylari)
    LOOP
        v_detay_id := nullif(v_item->>'detay_id', '')::bigint;
        v_miktar := coalesce(nullif(v_item->>'miktar', '')::numeric, 0);

        SELECT *
        INTO v_detay
        FROM public.satis_irsaliye_detay
        WHERE detay_id = v_detay_id
          AND irsaliye_id = p_irsaliye_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Satış irsaliye kalemi bulunamadı. Detay ID: %', v_detay_id;
        END IF;

        IF v_miktar <= 0 OR v_miktar > v_detay.kalan_miktar THEN
            RAISE EXCEPTION
                'Fatura miktarı geçersiz. Detay ID: %, Kalan: %, İstenen: %',
                v_detay_id, v_detay.kalan_miktar, v_miktar;
        END IF;

        v_satis_detaylari :=
            v_satis_detaylari ||
            jsonb_build_array(
                jsonb_build_object(
                    'stok_id', v_detay.stok_id,
                    'miktar', v_miktar,
                    'birim_fiyat', v_detay.birim_fiyat,
                    'indirim', v_detay.indirim_orani,
                    'kdv_orani', ROUND(COALESCE(v_detay.kdv_orani, 0))::integer
                )
            );
    END LOOP;

    v_satis_id := public.satis_olustur(
        v_baslik.cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        p_belge_no,
        v_baslik.depo_id,
        coalesce(nullif(trim(p_fiyat_tipi), ''), 'PERAKENDE'),
        p_kullanici,
        v_satis_detaylari
    );

    -- İrsaliye onayında stok zaten düşmüştü.
    -- Fatura fonksiyonunun ikinci stok düşümünü geri al.
    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_fatura_detaylari)
    LOOP
        v_detay_id := nullif(v_item->>'detay_id', '')::bigint;
        v_miktar := coalesce(nullif(v_item->>'miktar', '')::numeric, 0);

        SELECT *
        INTO v_detay
        FROM public.satis_irsaliye_detay
        WHERE detay_id = v_detay_id
          AND irsaliye_id = p_irsaliye_id
        FOR UPDATE;

        UPDATE public.stoklar
        SET stok_miktari = stok_miktari + v_miktar
        WHERE stok_id = v_detay.stok_id;

        UPDATE public.satis_irsaliye_detay
        SET
            faturalanan_miktar = faturalanan_miktar + v_miktar,
            durum = CASE
                WHEN faturalanan_miktar + v_miktar >= miktar
                    THEN 'FATURALANDI'
                ELSE 'KISMI_FATURALANDI'
            END
        WHERE detay_id = v_detay_id;
    END LOOP;

    DELETE FROM public.stok_hareket
    WHERE satis_ref = v_satis_id
      AND upper(coalesce(islem_tipi, '')) IN ('SATIS', 'SATIŞ');

    INSERT INTO public.satis_irsaliye_fatura (
        irsaliye_id, satis_id, tarih, kullanici, aciklama
    )
    VALUES (
        p_irsaliye_id, v_satis_id, now(), p_kullanici,
        'Satış irsaliyesinden fatura oluşturuldu.'
    );

    SELECT coalesce(sum(kalan_miktar), 0)
    INTO v_kalan_toplam
    FROM public.satis_irsaliye_detay
    WHERE irsaliye_id = p_irsaliye_id
      AND durum <> 'IPTAL';

    UPDATE public.satis_irsaliye_baslik
    SET durum = CASE
        WHEN v_kalan_toplam <= 0 THEN 'FATURALANDI'
        ELSE 'ONAYLANDI'
    END
    WHERE irsaliye_id = p_irsaliye_id;

    RETURN v_satis_id;
END;
$function$;

-- satis_irsaliye_guncelle(p_irsaliye_id bigint, p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.satis_irsaliye_guncelle(p_irsaliye_id bigint, p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_durum text;
    v_item jsonb;
    v_stok_id bigint;
    v_miktar numeric;
    v_birim_fiyat numeric;
    v_indirim_orani numeric;
    v_kdv_orani numeric;
    v_siparis_detay_id bigint;
BEGIN
    SELECT upper(coalesce(durum, ''))
    INTO v_durum
    FROM public.satis_irsaliye_baslik
    WHERE irsaliye_id = p_irsaliye_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Satış irsaliyesi bulunamadı. ID: %',
            p_irsaliye_id;
    END IF;

    IF v_durum <> 'HAZIRLANIYOR' THEN
        RAISE EXCEPTION
            'Sadece HAZIRLANIYOR durumundaki satış irsaliyesi düzeltilebilir. Mevcut durum: %',
            v_durum;
    END IF;

    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION 'Cari seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION 'Depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION
            'İrsaliyede en az bir ürün bulunmalıdır.';
    END IF;

    UPDATE public.satis_irsaliye_baslik
    SET
        irsaliye_no =
            nullif(trim(p_irsaliye_no), ''),
        cari_id = p_cari_id,
        depo_id = p_depo_id,
        aciklama =
            nullif(trim(coalesce(p_aciklama, '')), ''),
        kullanici =
            nullif(trim(coalesce(p_kullanici, '')), ''),
        guncelleme_tarihi = now()
    WHERE irsaliye_id = p_irsaliye_id;

    DELETE FROM public.satis_irsaliye_detay
    WHERE irsaliye_id = p_irsaliye_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::numeric,
                0
            );

        v_siparis_detay_id :=
            nullif(
                v_item->>'siparis_detay_id',
                ''
            )::bigint;

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION 'Geçersiz stok ID.';
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'İrsaliye miktarı sıfırdan büyük olmalıdır. Stok ID: %',
                v_stok_id;
        END IF;

        INSERT INTO public.satis_irsaliye_detay (
            irsaliye_id,
            stok_id,
            siparis_detay_id,
            miktar,
            birim_fiyat,
            indirim_orani,
            kdv_orani,
            aciklama,
            durum
        )
        VALUES (
            p_irsaliye_id,
            v_stok_id,
            v_siparis_detay_id,
            v_miktar,
            v_birim_fiyat,
            v_indirim_orani,
            v_kdv_orani,
            nullif(
                trim(
                    coalesce(
                        v_item->>'aciklama',
                        ''
                    )
                ),
                ''
            ),
            'BEKLIYOR'
        );
    END LOOP;

    RETURN p_irsaliye_id;
END;
$function$;

-- satis_irsaliye_iptal_et(p_irsaliye_id bigint, p_kullanici text, p_aciklama text)
CREATE OR REPLACE FUNCTION public.satis_irsaliye_iptal_et(p_irsaliye_id bigint, p_kullanici text, p_aciklama text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.satis_irsaliye_baslik
    SET
        durum = 'IPTAL',
        iptal_tarihi = now(),
        iptal_kullanici = p_kullanici,
        iptal_aciklama =
            nullif(trim(coalesce(p_aciklama, '')), '')
    WHERE irsaliye_id = p_irsaliye_id
      AND durum = 'HAZIRLANIYOR';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Satış irsaliyesi bulunamadı veya iptal edilebilir durumda değil.';
    END IF;

    UPDATE public.satis_irsaliye_detay
    SET durum = 'IPTAL'
    WHERE irsaliye_id = p_irsaliye_id;
END;
$function$;

-- satis_irsaliye_olustur(p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_siparis_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.satis_irsaliye_olustur(p_irsaliye_no text, p_cari_id bigint, p_depo_id bigint, p_siparis_id bigint, p_aciklama text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_irsaliye_id bigint;
    v_irsaliye_no text;
    v_item jsonb;
    v_stok_id bigint;
    v_miktar numeric;
    v_birim_fiyat numeric;
    v_indirim_orani numeric;
    v_kdv_orani numeric;
    v_siparis_detay_id bigint;
BEGIN
    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION 'Satış irsaliyesi için cari seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION 'Satış irsaliyesi için depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION 'Satış irsaliyesi kalemleri boş olamaz.';
    END IF;

    PERFORM 1 FROM public.cariler WHERE cari_id = p_cari_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Cari bulunamadı. Cari ID: %', p_cari_id;
    END IF;

    PERFORM 1 FROM public.depolar WHERE depo_id = p_depo_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Depo bulunamadı. Depo ID: %', p_depo_id;
    END IF;

    v_irsaliye_no :=
        nullif(trim(coalesce(p_irsaliye_no, '')), '');

    IF v_irsaliye_no IS NULL THEN
        v_irsaliye_no := public.yeni_satis_irsaliye_no();
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.satis_irsaliye_baslik
        WHERE upper(trim(irsaliye_no)) =
              upper(trim(v_irsaliye_no))
    ) THEN
        RAISE EXCEPTION
            'Bu satış irsaliye numarası daha önce kullanılmış: %',
            v_irsaliye_no;
    END IF;

    INSERT INTO public.satis_irsaliye_baslik (
        irsaliye_no,
        tarih,
        cari_id,
        depo_id,
        siparis_id,
        durum,
        aciklama,
        kullanici
    )
    VALUES (
        v_irsaliye_no,
        now(),
        p_cari_id,
        p_depo_id,
        p_siparis_id,
        'HAZIRLANIYOR',
        nullif(trim(coalesce(p_aciklama, '')), ''),
        p_kullanici
    )
    RETURNING irsaliye_id
    INTO v_irsaliye_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(nullif(v_item->>'miktar', '')::numeric, 0);

        v_birim_fiyat :=
            coalesce(nullif(v_item->>'birim_fiyat', '')::numeric, 0);

        v_indirim_orani :=
            coalesce(nullif(v_item->>'indirim', '')::numeric, 0);

        v_kdv_orani :=
            coalesce(nullif(v_item->>'kdv_orani', '')::numeric, 0);

        v_siparis_detay_id :=
            nullif(v_item->>'siparis_detay_id', '')::bigint;

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION 'Geçersiz stok ID.';
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'İrsaliye miktarı sıfırdan büyük olmalıdır. Stok ID: %',
                v_stok_id;
        END IF;

        INSERT INTO public.satis_irsaliye_detay (
            irsaliye_id,
            stok_id,
            siparis_detay_id,
            miktar,
            birim_fiyat,
            indirim_orani,
            kdv_orani,
            aciklama,
            durum
        )
        VALUES (
            v_irsaliye_id,
            v_stok_id,
            v_siparis_detay_id,
            v_miktar,
            v_birim_fiyat,
            v_indirim_orani,
            v_kdv_orani,
            nullif(trim(coalesce(v_item->>'aciklama', '')), ''),
            'BEKLIYOR'
        );
    END LOOP;

    RETURN v_irsaliye_id;
END;
$function$;

-- satis_irsaliye_onayla(p_irsaliye_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.satis_irsaliye_onayla(p_irsaliye_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_baslik public.satis_irsaliye_baslik%ROWTYPE;
    v_detay public.satis_irsaliye_detay%ROWTYPE;
    v_onceki_stok numeric;
    v_sonraki_stok numeric;
BEGIN
    SELECT *
    INTO v_baslik
    FROM public.satis_irsaliye_baslik
    WHERE irsaliye_id = p_irsaliye_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Satış irsaliyesi bulunamadı.';
    END IF;

    IF upper(v_baslik.durum) <> 'HAZIRLANIYOR' THEN
        RAISE EXCEPTION
            'Satış irsaliyesi onaylanabilir durumda değil. Durum: %',
            v_baslik.durum;
    END IF;

    FOR v_detay IN
        SELECT *
        FROM public.satis_irsaliye_detay
        WHERE irsaliye_id = p_irsaliye_id
        ORDER BY detay_id
        FOR UPDATE
    LOOP
        SELECT coalesce(stok_miktari, 0)
        INTO v_onceki_stok
        FROM public.stoklar
        WHERE stok_id = v_detay.stok_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_detay.stok_id;
        END IF;

        IF v_onceki_stok < v_detay.miktar THEN
            RAISE EXCEPTION
                'Yetersiz stok. Stok ID: %, Mevcut: %, İstenen: %',
                v_detay.stok_id,
                v_onceki_stok,
                v_detay.miktar;
        END IF;

        UPDATE public.stoklar
        SET stok_miktari =
            coalesce(stok_miktari, 0) - v_detay.miktar
        WHERE stok_id = v_detay.stok_id
          AND coalesce(stok_miktari, 0) >= v_detay.miktar
        RETURNING stok_miktari
        INTO v_sonraki_stok;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Yetersiz stok. İşlem iptal edildi. Stok ID: %',
                v_detay.stok_id;
        END IF;

        INSERT INTO public.stok_hareket (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            miktar,
            belge_no,
            aciklama,
            depo_id,
            cari_id,
            fatura_no,
            onceki_stok,
            sonraki_stok,
            birim_maliyet,
            hareket_tipi
        )
        SELECT
            now(),
            p_kullanici,
            v_detay.stok_id,
            'SATIS_IRSALIYE',
            v_detay.miktar,
            v_baslik.irsaliye_no,
            'Satış irsaliyesi',
            v_baslik.depo_id,
            v_baslik.cari_id,
            NULL,
            v_onceki_stok,
            v_sonraki_stok,
            coalesce(s.alis_fiyati, 0),
            'CIKIS'
        FROM public.stoklar AS s
        WHERE s.stok_id = v_detay.stok_id;
    END LOOP;

    UPDATE public.satis_irsaliye_baslik
    SET
        durum = 'ONAYLANDI',
        sevk_tarihi = now(),
        kullanici = coalesce(p_kullanici, kullanici)
    WHERE irsaliye_id = p_irsaliye_id;
END;
$function$;

-- satis_irsaliye_toplu_faturala(p_irsaliye_ids bigint[], p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_fiyat_tipi text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.satis_irsaliye_toplu_faturala(p_irsaliye_ids bigint[], p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_fiyat_tipi text, p_kullanici text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_cari_id bigint;
    v_depo_id bigint;
    v_irsaliye_id bigint;
    v_detay public.satis_irsaliye_detay%ROWTYPE;
    v_satis_id bigint;
    v_satis_detaylari jsonb := '[]'::jsonb;
    v_kalan numeric;
BEGIN
    IF p_irsaliye_ids IS NULL
       OR array_length(p_irsaliye_ids, 1) IS NULL THEN
        RAISE EXCEPTION 'En az bir satış irsaliyesi seçilmelidir.';
    END IF;

    -- Tekrarlanan ID varsa normalize et.
    SELECT min(cari_id), min(depo_id)
    INTO v_cari_id, v_depo_id
    FROM public.satis_irsaliye_baslik
    WHERE irsaliye_id = ANY(p_irsaliye_ids);

    IF v_cari_id IS NULL OR v_depo_id IS NULL THEN
        RAISE EXCEPTION 'Seçilen satış irsaliyeleri bulunamadı.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.satis_irsaliye_baslik
        WHERE irsaliye_id = ANY(p_irsaliye_ids)
          AND (
              cari_id <> v_cari_id
              OR depo_id <> v_depo_id
              OR upper(coalesce(durum, '')) <> 'ONAYLANDI'
          )
    ) THEN
        RAISE EXCEPTION
            'Toplu satış faturasında tüm irsaliyelerin carisi ve deposu aynı, durumu ONAYLANDI olmalıdır.';
    END IF;

    IF (
        SELECT count(DISTINCT irsaliye_id)
        FROM public.satis_irsaliye_baslik
        WHERE irsaliye_id = ANY(p_irsaliye_ids)
    ) <> (
        SELECT count(DISTINCT x)
        FROM unnest(p_irsaliye_ids) AS x
    ) THEN
        RAISE EXCEPTION 'Seçilen satış irsaliyelerinden biri bulunamadı.';
    END IF;

    -- Kilitle ve tüm kalan kalemleri tek satış detayı JSON'unda topla.
    FOR v_irsaliye_id IN
        SELECT DISTINCT x
        FROM unnest(p_irsaliye_ids) AS x
        ORDER BY x
    LOOP
        PERFORM 1
        FROM public.satis_irsaliye_baslik
        WHERE irsaliye_id = v_irsaliye_id
        FOR UPDATE;

        FOR v_detay IN
            SELECT *
            FROM public.satis_irsaliye_detay
            WHERE irsaliye_id = v_irsaliye_id
              AND durum <> 'IPTAL'
              AND kalan_miktar > 0
            ORDER BY detay_id
            FOR UPDATE
        LOOP
            v_satis_detaylari :=
                v_satis_detaylari ||
                jsonb_build_array(
                    jsonb_build_object(
                        'stok_id', v_detay.stok_id,
                        'miktar', v_detay.kalan_miktar,
                        'birim_fiyat', v_detay.birim_fiyat,
                        'indirim', v_detay.indirim_orani,
                        'kdv_orani',
                            ROUND(COALESCE(v_detay.kdv_orani, 0))::integer
                    )
                );
        END LOOP;
    END LOOP;

    IF jsonb_array_length(v_satis_detaylari) = 0 THEN
        RAISE EXCEPTION
            'Seçilen satış irsaliyelerinde faturalanacak kalan kalem yok.';
    END IF;

    v_satis_id := public.satis_olustur(
        v_cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        p_belge_no,
        v_depo_id,
        coalesce(nullif(trim(p_fiyat_tipi), ''), 'PERAKENDE'),
        p_kullanici,
        v_satis_detaylari
    );

    -- satis_olustur stoktan ikinci kez düşmüştü; geri al.
    FOR v_irsaliye_id IN
        SELECT DISTINCT x
        FROM unnest(p_irsaliye_ids) AS x
    LOOP
        FOR v_detay IN
            SELECT *
            FROM public.satis_irsaliye_detay
            WHERE irsaliye_id = v_irsaliye_id
              AND durum <> 'IPTAL'
              AND kalan_miktar > 0
            ORDER BY detay_id
            FOR UPDATE
        LOOP
            UPDATE public.stoklar
            SET stok_miktari =
                stok_miktari + v_detay.kalan_miktar
            WHERE stok_id = v_detay.stok_id;

            UPDATE public.satis_irsaliye_detay
            SET
                faturalanan_miktar = miktar,
                durum = 'FATURALANDI'
            WHERE detay_id = v_detay.detay_id;
        END LOOP;

        INSERT INTO public.satis_irsaliye_fatura (
            irsaliye_id,
            satis_id,
            tarih,
            kullanici,
            aciklama
        )
        VALUES (
            v_irsaliye_id,
            v_satis_id,
            now(),
            p_kullanici,
            'Toplu satış faturası oluşturuldu.'
        )
        ON CONFLICT (irsaliye_id, satis_id)
        DO NOTHING;

        SELECT coalesce(sum(kalan_miktar), 0)
        INTO v_kalan
        FROM public.satis_irsaliye_detay
        WHERE irsaliye_id = v_irsaliye_id
          AND durum <> 'IPTAL';

        UPDATE public.satis_irsaliye_baslik
        SET durum = CASE
            WHEN v_kalan <= 0
                THEN 'FATURALANDI'
            ELSE 'ONAYLANDI'
        END
        WHERE irsaliye_id = v_irsaliye_id;
    END LOOP;

    DELETE FROM public.stok_hareket
    WHERE satis_ref = v_satis_id
      AND upper(coalesce(islem_tipi, ''))
          IN ('SATIS', 'SATIŞ');

    RETURN v_satis_id;
END;
$function$;

-- satis_olustur(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_depo_id bigint, p_fiyat_tipi text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.satis_olustur(p_cari_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_depo_id bigint, p_fiyat_tipi text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_satis_id bigint;

    v_item jsonb;

    v_stok_id bigint;
    v_miktar integer;

    v_birim_fiyat numeric;
    v_indirim_orani numeric;
    v_kdv_orani integer;

    v_alis_fiyati numeric;
    v_net_birim_fiyat numeric;

    v_brut_tutar numeric;
    v_indirim_tutari numeric;
    v_net_tutar numeric;
    v_kdv_tutari numeric;
    v_satir_genel_toplam numeric;
    v_kar_tutari numeric;

    v_ara_toplam numeric := 0;
    v_toplam_indirim numeric := 0;
    v_kdv_toplam numeric := 0;
    v_genel_toplam numeric := 0;

    v_onceki_stok integer;
    v_sonraki_stok integer;

    v_mevcut_bakiye numeric := 0;
    v_risk_limiti numeric := 0;

    v_veresiye boolean;
BEGIN
    ------------------------------------------------------
    -- TEMEL KONTROLLER
    ------------------------------------------------------

    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION
            'Satış için cari seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION
            'Satış için depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION
            'Satış kalemleri boş olamaz.';
    END IF;

    v_veresiye :=
        lower(trim(coalesce(p_odeme_tipi, ''))) IN
        ('veresiye', 'hesap');

    IF NOT v_veresiye AND p_kasa_id IS NULL THEN
        RAISE EXCEPTION
            'Nakit, kart veya havale satışında kasa seçilmelidir.';
    END IF;

    ------------------------------------------------------
    -- SATIRLARI KONTROL ET VE TOPLAMLARI HESAPLA
    ------------------------------------------------------

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::integer,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::integer,
                0
            );

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION
                'Geçersiz stok ID.';
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'Satış miktarı sıfırdan büyük olmalıdır. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_birim_fiyat < 0 THEN
            RAISE EXCEPTION
                'Satış fiyatı negatif olamaz. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_indirim_orani < 0
           OR v_indirim_orani > 100 THEN
            RAISE EXCEPTION
                'İndirim oranı 0 ile 100 arasında olmalıdır.';
        END IF;

        --------------------------------------------------
        -- STOK VE ALIŞ FİYATINI KİLİTLEYEREK OKU
        --------------------------------------------------

        SELECT
            coalesce(s.stok_miktari, 0)::integer,
            coalesce(s.alis_fiyati, 0)
        INTO
            v_onceki_stok,
            v_alis_fiyati
        FROM public.stoklar AS s
        WHERE s.stok_id = v_stok_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_stok_id;
        END IF;

        --------------------------------------------------
        -- YETERSİZ STOK KONTROLÜ
        --------------------------------------------------

        IF v_onceki_stok < v_miktar THEN
            RAISE EXCEPTION
                'Yetersiz stok. Stok ID: %, Mevcut: %, İstenen: %',
                v_stok_id,
                v_onceki_stok,
                v_miktar;
        END IF;

        --------------------------------------------------
        -- MALİYETİN ALTINDA SATIŞ KONTROLÜ
        --------------------------------------------------

        v_net_birim_fiyat :=
            v_birim_fiyat
            * (1 - v_indirim_orani / 100);

        IF v_net_birim_fiyat < v_alis_fiyati THEN
            RAISE EXCEPTION
                'Alış fiyatının altında satış yapılamaz. '
                'Stok ID: %, Alış: %, İndirim sonrası satış: %',
                v_stok_id,
                v_alis_fiyati,
                v_net_birim_fiyat;
        END IF;

        --------------------------------------------------
        -- SATIR TOPLAMLARI
        --------------------------------------------------

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_indirim_tutari :=
            v_brut_tutar
            * v_indirim_orani / 100;

        v_net_tutar :=
            v_brut_tutar
            - v_indirim_tutari;

        v_kdv_tutari :=
            v_net_tutar
            * v_kdv_orani / 100;

        v_satir_genel_toplam :=
            v_net_tutar
            + v_kdv_tutari;

        v_ara_toplam :=
            v_ara_toplam
            + v_brut_tutar;

        v_toplam_indirim :=
            v_toplam_indirim
            + v_indirim_tutari;

        v_kdv_toplam :=
            v_kdv_toplam
            + v_kdv_tutari;
    END LOOP;

    v_genel_toplam :=
        v_ara_toplam
        - v_toplam_indirim
        + v_kdv_toplam;

    ------------------------------------------------------
    -- CARİ VE RİSK LİMİTİ KONTROLÜ
    ------------------------------------------------------

    SELECT
        coalesce(c.bakiye, 0),
        coalesce(c.risk_limiti, 0)
    INTO
        v_mevcut_bakiye,
        v_risk_limiti
    FROM public.cariler AS c
    WHERE c.cari_id = p_cari_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Cari bulunamadı. Cari ID: %',
            p_cari_id;
    END IF;

    /*
      Risk limiti 0 ise sınırsız kabul edilir.
      Risk limiti sıfırdan büyükse veresiye satış kontrol edilir.
    */
    IF v_veresiye
       AND v_risk_limiti > 0
       AND v_mevcut_bakiye + v_genel_toplam > v_risk_limiti THEN
        RAISE EXCEPTION
            'Cari risk limiti aşıldı. '
            'Mevcut bakiye: %, Satış: %, Risk limiti: %',
            v_mevcut_bakiye,
            v_genel_toplam,
            v_risk_limiti;
    END IF;

    ------------------------------------------------------
    -- SATIŞ BAŞLIK
    ------------------------------------------------------

    INSERT INTO public.satis_baslik
    (
        fatura_no,
        tarih,
        cari_id,
        toplam_tutar,
        kdv_toplam,
        genel_toplam,
        durum,
        kullanici,
        depo_id,
        islem_tipi,
        belge_tipi,
        fiyat_tipi,
        belge_no,
        odeme_tipi,
        kasa_id
    )
    VALUES
    (
        nullif(trim(p_fatura_no), ''),
        now(),
        p_cari_id,
        v_ara_toplam - v_toplam_indirim,
        v_kdv_toplam,
        v_genel_toplam,
        'ONAYLANDI',
        p_kullanici,
        p_depo_id,
        'SATIS',
        'FATURA',
        coalesce(
            nullif(trim(p_fiyat_tipi), ''),
            'PERAKENDE'
        ),
        nullif(trim(p_belge_no), ''),
        p_odeme_tipi,
        CASE
            WHEN v_veresiye THEN NULL
            ELSE p_kasa_id
        END
    )
    RETURNING satis_id
    INTO v_satis_id;

    ------------------------------------------------------
    -- SATIŞ DETAY, STOK VE STOK HAREKETLERİ
    ------------------------------------------------------

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::integer,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::integer,
                0
            );

        --------------------------------------------------
        -- GÜNCEL STOK VE MALİYETİ TEKRAR OKU
        --------------------------------------------------

        SELECT
            coalesce(s.stok_miktari, 0)::integer,
            coalesce(s.alis_fiyati, 0)
        INTO
            v_onceki_stok,
            v_alis_fiyati
        FROM public.stoklar AS s
        WHERE s.stok_id = v_stok_id
        FOR UPDATE;

        /*
          Nihai stok düşümü aşağıdaki atomik UPDATE içinde yapılır.
          Burada yalnızca satır tutarları hesaplanır.
        */

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_indirim_tutari :=
            v_brut_tutar
            * v_indirim_orani / 100;

        v_net_tutar :=
            v_brut_tutar
            - v_indirim_tutari;

        v_kdv_tutari :=
            v_net_tutar
            * v_kdv_orani / 100;

        v_satir_genel_toplam :=
            v_net_tutar
            + v_kdv_tutari;

        v_kar_tutari :=
            v_net_tutar
            - (v_alis_fiyati * v_miktar);

        --------------------------------------------------
        -- SATIŞ DETAY
        --------------------------------------------------

        INSERT INTO public.satis_detay
        (
            satis_id,
            stok_id,
            miktar,
            birim_fiyat,
            indirim,
            tutar,
            tarih,
            depo_id,
            islem_tipi,
            iade_durumu,
            kdv_orani,
            alis_fiyati,
            kar_tutari,
            toplam_tutar
        )
        VALUES
        (
            v_satis_id,
            v_stok_id,
            v_miktar,
            v_birim_fiyat,
            v_indirim_orani,
            v_net_tutar,
            now(),
            p_depo_id,
            'SATIS',
            'NORMAL',
            v_kdv_orani,
            v_alis_fiyati,
            v_kar_tutari,
            v_satir_genel_toplam
        );

        --------------------------------------------------
        -- STOK DÜŞ
        --------------------------------------------------

        UPDATE public.stoklar
        SET stok_miktari =
            coalesce(stok_miktari, 0) - v_miktar
        WHERE stok_id = v_stok_id
          AND coalesce(stok_miktari, 0) >= v_miktar
        RETURNING stok_miktari
        INTO v_sonraki_stok;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Yetersiz stok. İşlem iptal edildi. '
                'Stok ID: %, Mevcut: %, İstenen: %',
                v_stok_id,
                v_onceki_stok,
                v_miktar;
        END IF;

        --------------------------------------------------
        -- STOK HAREKET
        --------------------------------------------------

        INSERT INTO public.stok_hareket
        (
            tarih,
            kullanici,
            stok_id,
            islem_tipi,
            miktar,
            belge_no,
            aciklama,
            depo_id,
            cari_id,
            satis_ref,
            fatura_no,
            onceki_stok,
            sonraki_stok,
            birim_maliyet,
            hareket_tipi
        )
        VALUES
        (
            now(),
            p_kullanici,
            v_stok_id,
            'SATIS',
            v_miktar,
            coalesce(
                nullif(trim(p_belge_no), ''),
                p_fatura_no
            ),
            'Satış faturası',
            p_depo_id,
            p_cari_id,
            v_satis_id,
            p_fatura_no,
            v_onceki_stok,
            v_sonraki_stok,
            v_alis_fiyati,
            'CIKIS'
        );
    END LOOP;

    ------------------------------------------------------
    -- CARİ SATIŞ HAREKETİ
    ------------------------------------------------------

    INSERT INTO public.cari_hareket
    (
        tarih,
        cari_id,
        islem_tipi,
        belge_no,
        borc,
        alacak,
        aciklama,
        kullanici
    )
    VALUES
    (
        now(),
        p_cari_id,
        'SATIS',
        coalesce(
            nullif(trim(p_belge_no), ''),
            p_fatura_no
        ),
        v_genel_toplam,
        0,
        'Satış faturası',
        p_kullanici
    );

    UPDATE public.cariler
    SET
        bakiye =
            coalesce(bakiye, 0)
            + v_genel_toplam,
        son_satis_tarihi = now()
    WHERE cari_id = p_cari_id;

    ------------------------------------------------------
    -- PEŞİN SATIŞTA TAHSİLAT VE KASA GİRİŞİ
    ------------------------------------------------------

    IF NOT v_veresiye THEN
        INSERT INTO public.kasa_hareket
        (
            tarih,
            tip,
            tutar,
            aciklama,
            cari_id,
            kullanici,
            kasa_id
        )
        VALUES
        (
            now(),
            'GIRIS',
            v_genel_toplam,
            'Satış tahsilatı - Fatura: '
                || coalesce(p_fatura_no, ''),
            p_cari_id,
            p_kullanici,
            p_kasa_id
        );

        INSERT INTO public.cari_hareket
        (
            tarih,
            cari_id,
            islem_tipi,
            belge_no,
            borc,
            alacak,
            aciklama,
            kullanici
        )
        VALUES
        (
            now(),
            p_cari_id,
            'TAHSILAT',
            coalesce(
                nullif(trim(p_belge_no), ''),
                p_fatura_no
            ),
            0,
            v_genel_toplam,
            'Satış faturası tahsilatı',
            p_kullanici
        );

        UPDATE public.cariler
        SET bakiye =
            coalesce(bakiye, 0)
            - v_genel_toplam
        WHERE cari_id = p_cari_id;
    END IF;

    RETURN v_satis_id;
END;
$function$;

-- satis_siparis_faturala(p_siparis_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_kullanici text, p_sevk_detaylari jsonb)
CREATE OR REPLACE FUNCTION public.satis_siparis_faturala(p_siparis_id bigint, p_kasa_id bigint, p_odeme_tipi text, p_fatura_no text, p_belge_no text, p_kullanici text, p_sevk_detaylari jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_siparis public.satis_siparis_baslik%ROWTYPE;
    v_item jsonb;
    v_detay public.satis_siparis_detay%ROWTYPE;

    v_detay_id bigint;
    v_sevk_miktari numeric;
    v_toplam_sevk numeric := 0;

    v_satis_detaylari jsonb := '[]'::jsonb;
    v_satis_id bigint;

    v_kalan_toplam numeric;
    v_sevk_toplam numeric;
BEGIN
    IF p_siparis_id IS NULL THEN
        RAISE EXCEPTION 'Sipariş ID boş olamaz.';
    END IF;

    IF p_sevk_detaylari IS NULL
       OR jsonb_typeof(p_sevk_detaylari) <> 'array'
       OR jsonb_array_length(p_sevk_detaylari) = 0 THEN
        RAISE EXCEPTION 'Sevk edilecek sipariş kalemleri boş olamaz.';
    END IF;

    SELECT *
    INTO v_siparis
    FROM public.satis_siparis_baslik
    WHERE siparis_id = p_siparis_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Sipariş bulunamadı. Sipariş ID: %', p_siparis_id;
    END IF;

    IF upper(v_siparis.durum) NOT IN ('ONAYLANDI', 'KISMI_SEVK') THEN
        RAISE EXCEPTION
            'Sipariş faturalanabilir durumda değil. Mevcut durum: %',
            v_siparis.durum;
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_sevk_detaylari)
    LOOP
        v_detay_id :=
            nullif(v_item->>'detay_id', '')::bigint;

        v_sevk_miktari :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        IF v_detay_id IS NULL THEN
            RAISE EXCEPTION 'Geçersiz sipariş detay ID.';
        END IF;

        IF v_sevk_miktari <= 0 THEN
            RAISE EXCEPTION
                'Sevk miktarı sıfırdan büyük olmalıdır. Detay ID: %',
                v_detay_id;
        END IF;

        SELECT *
        INTO v_detay
        FROM public.satis_siparis_detay
        WHERE detay_id = v_detay_id
          AND siparis_id = p_siparis_id
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Sipariş kalemi bulunamadı. Detay ID: %',
                v_detay_id;
        END IF;

        IF upper(v_detay.durum) = 'IPTAL' THEN
            RAISE EXCEPTION
                'İptal edilmiş sipariş kalemi sevk edilemez. Detay ID: %',
                v_detay_id;
        END IF;

        IF v_sevk_miktari > v_detay.kalan_miktar THEN
            RAISE EXCEPTION
                'Sevk miktarı kalan sipariş miktarını aşamaz. '
                'Detay ID: %, Kalan: %, İstenen: %',
                v_detay_id,
                v_detay.kalan_miktar,
                v_sevk_miktari;
        END IF;

        v_satis_detaylari :=
            v_satis_detaylari ||
            jsonb_build_array(
                jsonb_build_object(
                    'stok_id', v_detay.stok_id,
                    'miktar', v_sevk_miktari,
                    'birim_fiyat', v_detay.birim_fiyat,
                    'indirim', v_detay.indirim_orani,
                    'kdv_orani', v_detay.kdv_orani
                )
            );

        v_toplam_sevk := v_toplam_sevk + v_sevk_miktari;
    END LOOP;

    IF v_toplam_sevk <= 0 THEN
        RAISE EXCEPTION 'Toplam sevk miktarı sıfırdan büyük olmalıdır.';
    END IF;

    /*
      Mevcut satis_olustur:
      - stokları kilitler ve kontrol eder,
      - satış başlık/detay oluşturur,
      - stok düşer,
      - stok/cari/kasa hareketlerini oluşturur,
      - hata halinde transaction geri alınır.
    */
    v_satis_id := public.satis_olustur(
        v_siparis.cari_id,
        p_kasa_id,
        p_odeme_tipi,
        p_fatura_no,
        p_belge_no,
        v_siparis.depo_id,
        v_siparis.fiyat_tipi,
        p_kullanici,
        v_satis_detaylari
    );

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_sevk_detaylari)
    LOOP
        v_detay_id :=
            nullif(v_item->>'detay_id', '')::bigint;

        v_sevk_miktari :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        UPDATE public.satis_siparis_detay
        SET
            sevk_edilen_miktar =
                sevk_edilen_miktar + v_sevk_miktari,
            durum = CASE
                WHEN sevk_edilen_miktar + v_sevk_miktari >= miktar
                    THEN 'TAMAMLANDI'
                ELSE 'KISMI_SEVK'
            END
        WHERE detay_id = v_detay_id
          AND siparis_id = p_siparis_id;
    END LOOP;

    INSERT INTO public.satis_siparis_sevk
    (
        siparis_id,
        satis_id,
        tarih,
        kullanici,
        aciklama
    )
    VALUES
    (
        p_siparis_id,
        v_satis_id,
        now(),
        p_kullanici,
        'Siparişten satış faturası oluşturuldu.'
    );

    SELECT
        coalesce(sum(kalan_miktar), 0),
        coalesce(sum(sevk_edilen_miktar), 0)
    INTO
        v_kalan_toplam,
        v_sevk_toplam
    FROM public.satis_siparis_detay
    WHERE siparis_id = p_siparis_id
      AND durum <> 'IPTAL';

    UPDATE public.satis_siparis_baslik
    SET durum = CASE
        WHEN v_kalan_toplam <= 0 THEN 'TAMAMLANDI'
        WHEN v_sevk_toplam > 0 THEN 'KISMI_SEVK'
        ELSE durum
    END
    WHERE siparis_id = p_siparis_id;

    RETURN v_satis_id;
END;
$function$;

-- satis_siparis_guncelleme_tarihi()
CREATE OR REPLACE FUNCTION public.satis_siparis_guncelleme_tarihi()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
BEGIN
    NEW.guncelleme_tarihi := now();
    RETURN NEW;
END;
$function$;

-- satis_siparis_iptal_et(p_siparis_id bigint, p_kullanici text, p_aciklama text)
CREATE OR REPLACE FUNCTION public.satis_siparis_iptal_et(p_siparis_id bigint, p_kullanici text, p_aciklama text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.satis_siparis_baslik
    SET
        durum = 'IPTAL',
        iptal_tarihi = now(),
        iptal_kullanici = p_kullanici,
        iptal_aciklama =
            nullif(trim(coalesce(p_aciklama, '')), '')
    WHERE siparis_id = p_siparis_id
      AND durum NOT IN ('TAMAMLANDI', 'IPTAL');

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Sipariş bulunamadı, tamamlanmış veya zaten iptal edilmiş.';
    END IF;

    UPDATE public.satis_siparis_detay
    SET durum = 'IPTAL'
    WHERE siparis_id = p_siparis_id
      AND durum <> 'TAMAMLANDI';
END;
$function$;

-- satis_siparis_olustur(p_siparis_no text, p_cari_id bigint, p_depo_id bigint, p_fiyat_tipi text, p_odeme_tipi text, p_termin_tarihi date, p_aciklama text, p_kullanici text, p_detaylar jsonb)
CREATE OR REPLACE FUNCTION public.satis_siparis_olustur(p_siparis_no text, p_cari_id bigint, p_depo_id bigint, p_fiyat_tipi text, p_odeme_tipi text, p_termin_tarihi date, p_aciklama text, p_kullanici text, p_detaylar jsonb)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_siparis_id bigint;
    v_siparis_no text;
    v_item jsonb;

    v_stok_id bigint;
    v_miktar numeric;
    v_birim_fiyat numeric;
    v_indirim_orani numeric;
    v_kdv_orani numeric;

    v_brut_tutar numeric;
    v_indirim_tutari numeric;
    v_net_tutar numeric;
    v_kdv_tutari numeric;
    v_satir_genel_toplam numeric;

    v_toplam_tutar numeric := 0;
    v_toplam_indirim numeric := 0;
    v_kdv_toplam numeric := 0;
    v_genel_toplam numeric := 0;
BEGIN
    IF p_cari_id IS NULL THEN
        RAISE EXCEPTION
            'Sipariş için cari seçilmelidir.';
    END IF;

    IF p_depo_id IS NULL THEN
        RAISE EXCEPTION
            'Sipariş için depo seçilmelidir.';
    END IF;

    IF p_detaylar IS NULL
       OR jsonb_typeof(p_detaylar) <> 'array'
       OR jsonb_array_length(p_detaylar) = 0 THEN
        RAISE EXCEPTION
            'Sipariş kalemleri boş olamaz.';
    END IF;

    PERFORM 1
    FROM public.cariler
    WHERE cari_id = p_cari_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Cari bulunamadı. Cari ID: %',
            p_cari_id;
    END IF;

    PERFORM 1
    FROM public.depolar
    WHERE depo_id = p_depo_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Depo bulunamadı. Depo ID: %',
            p_depo_id;
    END IF;

    v_siparis_no :=
        nullif(trim(coalesce(p_siparis_no, '')), '');

    IF v_siparis_no IS NULL THEN
        v_siparis_no := public.yeni_satis_siparis_no();
    END IF;

    IF EXISTS (
        SELECT 1
        FROM public.satis_siparis_baslik
        WHERE upper(trim(siparis_no)) =
              upper(trim(v_siparis_no))
    ) THEN
        RAISE EXCEPTION
            'Bu sipariş numarası daha önce kullanılmış: %',
            v_siparis_no;
    END IF;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::numeric,
                0
            );

        IF v_stok_id IS NULL THEN
            RAISE EXCEPTION
                'Geçersiz stok ID.';
        END IF;

        PERFORM 1
        FROM public.stoklar
        WHERE stok_id = v_stok_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Stok kartı bulunamadı. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_miktar <= 0 THEN
            RAISE EXCEPTION
                'Sipariş miktarı sıfırdan büyük olmalıdır. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_birim_fiyat < 0 THEN
            RAISE EXCEPTION
                'Birim fiyat negatif olamaz. Stok ID: %',
                v_stok_id;
        END IF;

        IF v_indirim_orani < 0
           OR v_indirim_orani > 100 THEN
            RAISE EXCEPTION
                'İndirim oranı 0 ile 100 arasında olmalıdır.';
        END IF;

        IF v_kdv_orani < 0
           OR v_kdv_orani > 100 THEN
            RAISE EXCEPTION
                'KDV oranı 0 ile 100 arasında olmalıdır.';
        END IF;

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_indirim_tutari :=
            v_brut_tutar
            * v_indirim_orani / 100;

        v_net_tutar :=
            v_brut_tutar
            - v_indirim_tutari;

        v_kdv_tutari :=
            v_net_tutar
            * v_kdv_orani / 100;

        v_satir_genel_toplam :=
            v_net_tutar
            + v_kdv_tutari;

        v_toplam_tutar :=
            v_toplam_tutar
            + v_brut_tutar;

        v_toplam_indirim :=
            v_toplam_indirim
            + v_indirim_tutari;

        v_kdv_toplam :=
            v_kdv_toplam
            + v_kdv_tutari;

        v_genel_toplam :=
            v_genel_toplam
            + v_satir_genel_toplam;
    END LOOP;

    INSERT INTO public.satis_siparis_baslik
    (
        siparis_no,
        tarih,
        termin_tarihi,
        cari_id,
        depo_id,
        fiyat_tipi,
        odeme_tipi,
        durum,
        toplam_tutar,
        toplam_indirim,
        kdv_toplam,
        genel_toplam,
        aciklama,
        kullanici
    )
    VALUES
    (
        v_siparis_no,
        now(),
        p_termin_tarihi,
        p_cari_id,
        p_depo_id,
        upper(
            coalesce(
                nullif(trim(p_fiyat_tipi), ''),
                'PERAKENDE'
            )
        ),
        nullif(trim(coalesce(p_odeme_tipi, '')), ''),
        'HAZIRLANIYOR',
        v_toplam_tutar,
        v_toplam_indirim,
        v_kdv_toplam,
        v_genel_toplam,
        nullif(trim(coalesce(p_aciklama, '')), ''),
        p_kullanici
    )
    RETURNING siparis_id
    INTO v_siparis_id;

    FOR v_item IN
        SELECT value
        FROM jsonb_array_elements(p_detaylar)
    LOOP
        v_stok_id :=
            nullif(v_item->>'stok_id', '')::bigint;

        v_miktar :=
            coalesce(
                nullif(v_item->>'miktar', '')::numeric,
                0
            );

        v_birim_fiyat :=
            coalesce(
                nullif(v_item->>'birim_fiyat', '')::numeric,
                0
            );

        v_indirim_orani :=
            coalesce(
                nullif(v_item->>'indirim', '')::numeric,
                0
            );

        v_kdv_orani :=
            coalesce(
                nullif(v_item->>'kdv_orani', '')::numeric,
                0
            );

        v_brut_tutar :=
            v_miktar * v_birim_fiyat;

        v_indirim_tutari :=
            v_brut_tutar
            * v_indirim_orani / 100;

        v_net_tutar :=
            v_brut_tutar
            - v_indirim_tutari;

        v_kdv_tutari :=
            v_net_tutar
            * v_kdv_orani / 100;

        v_satir_genel_toplam :=
            v_net_tutar
            + v_kdv_tutari;

        INSERT INTO public.satis_siparis_detay
        (
            siparis_id,
            stok_id,
            miktar,
            sevk_edilen_miktar,
            birim_fiyat,
            indirim_orani,
            indirim_tutari,
            kdv_orani,
            kdv_tutari,
            net_tutar,
            genel_toplam,
            aciklama,
            durum
        )
        VALUES
        (
            v_siparis_id,
            v_stok_id,
            v_miktar,
            0,
            v_birim_fiyat,
            v_indirim_orani,
            v_indirim_tutari,
            v_kdv_orani,
            v_kdv_tutari,
            v_net_tutar,
            v_satir_genel_toplam,
            nullif(
                trim(
                    coalesce(v_item->>'aciklama', '')
                ),
                ''
            ),
            'BEKLIYOR'
        );
    END LOOP;

    RETURN v_siparis_id;
END;
$function$;

-- satis_siparis_onayla(p_siparis_id bigint, p_kullanici text)
CREATE OR REPLACE FUNCTION public.satis_siparis_onayla(p_siparis_id bigint, p_kullanici text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
BEGIN
    UPDATE public.satis_siparis_baslik
    SET
        durum = 'ONAYLANDI',
        kullanici = coalesce(p_kullanici, kullanici)
    WHERE siparis_id = p_siparis_id
      AND durum = 'HAZIRLANIYOR';

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Sipariş bulunamadı veya onaylanabilir durumda değil.';
    END IF;
END;
$function$;

-- set_limit(real)
CREATE OR REPLACE FUNCTION public.set_limit(real)
 RETURNS real
 LANGUAGE c
 STRICT
AS '$libdir/pg_trgm', $function$set_limit$function$;

-- show_limit()
CREATE OR REPLACE FUNCTION public.show_limit()
 RETURNS real
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_limit$function$;

-- show_trgm(text)
CREATE OR REPLACE FUNCTION public.show_trgm(text)
 RETURNS text[]
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$show_trgm$function$;

-- similarity(text, text)
CREATE OR REPLACE FUNCTION public.similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity$function$;

-- similarity_dist(text, text)
CREATE OR REPLACE FUNCTION public.similarity_dist(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_dist$function$;

-- similarity_op(text, text)
CREATE OR REPLACE FUNCTION public.similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$similarity_op$function$;

-- stok_arama_metni()
CREATE OR REPLACE FUNCTION public.stok_arama_metni()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  NEW.arama_metni := LOWER(
    CONCAT_WS(' ',
      NEW.oem_no,
      NEW.uretici_kodu,
      NEW.barkod,
      NEW.urun_adi,
      NEW.marka,
      NEW.grup,
      NEW.raf,
      NEW.urun_ozellik,
      NEW.cross_kod,
      NEW.rakip_kod,
      NEW.arac
    )
  );
  RETURN NEW;
END;
$function$;

-- stok_arama_metni_guncelle()
CREATE OR REPLACE FUNCTION public.stok_arama_metni_guncelle()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.arama_metni := LOWER(
        COALESCE(NEW.urun_adi, '') || ' ' ||
        COALESCE(NEW.uretici_kodu, '') || ' ' ||
        COALESCE(NEW.oem_no, '') || ' ' ||
        COALESCE(NEW.cross_kod, '') || ' ' ||
        COALESCE(NEW.barkod, '') || ' ' ||
        COALESCE(NEW.marka, '') || ' ' ||
        COALESCE(NEW.arac, '') || ' ' ||
        COALESCE(NEW.raf, '') || ' ' ||
        COALESCE(NEW.grup, '') || ' ' ||
        COALESCE(NEW.rakip_kod, '')
    );
    RETURN NEW;
END;
$function$;

-- stok_artir()
CREATE OR REPLACE FUNCTION public.stok_artir()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE stoklar
  SET miktar = miktar + NEW.miktar
  WHERE stok_id = NEW.stok_id;
  RETURN NEW;
END;
$function$;

-- stok_arttir(p_stok_id bigint, p_miktar integer)
CREATE OR REPLACE FUNCTION public.stok_arttir(p_stok_id bigint, p_miktar integer)
 RETURNS void
 LANGUAGE plpgsql
AS $function$
BEGIN

    UPDATE stoklar
    SET
        stok_miktari = COALESCE(stok_miktari,0) + p_miktar,
        son_alis_tarihi = now()
    WHERE stok_id = p_stok_id;

END;
$function$;

-- stok_azalt()
CREATE OR REPLACE FUNCTION public.stok_azalt()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  UPDATE stoklar
  SET miktar = miktar - NEW.miktar
  WHERE stok_id = NEW.stok_id;
  RETURN NEW;
END;
$function$;

-- stok_dus(p_stok_id integer, p_adet integer)
CREATE OR REPLACE FUNCTION public.stok_dus(p_stok_id integer, p_adet integer)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
declare
  mevcut integer;
begin
  if p_adet <= 0 then
    raise exception 'p_adet must be > 0';
  end if;

  select stok_miktari into mevcut from stoklar where id = p_stok_id for update;

  if not found then
    raise exception 'Stok bulunamadı: %', p_stok_id;
  end if;

  if mevcut < p_adet then
    raise exception 'Yetersiz stok: mevcut=% , isteg=%', mevcut, p_adet;
  end if;

  update stoklar set stok_miktari = stok_miktari - p_adet where id = p_stok_id;

  insert into stok_hareket(stok_id, hareket_tipi, miktar, referans, created_at)
  values (p_stok_id, 'SATIS', p_adet, null, now());

  return;
end;
$function$;

-- stok_fiyatlarini_hesapla()
CREATE OR REPLACE FUNCTION public.stok_fiyatlarini_hesapla()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'public'
AS $function$
DECLARE
    v_sfp_orani numeric := 35;
    v_sft_orani numeric := 25;
    v_sfl_orani numeric := 60;
    v_sfi_orani numeric := 18;
    v_kdv_orani numeric := 20;
BEGIN
    SELECT
        fp.sfp_orani,
        fp.sft_orani,
        fp.sfl_orani,
        fp.sfi_orani
    INTO
        v_sfp_orani,
        v_sft_orani,
        v_sfl_orani,
        v_sfi_orani
    FROM public.fiyat_politikalari AS fp
    WHERE fp.aktif = true
    ORDER BY fp.politika_id
    LIMIT 1;

    v_kdv_orani := COALESCE(NEW.kdv, 20);

    NEW.kar_orani_perakende :=
        COALESCE(NEW.kar_orani_perakende, v_sfp_orani);

    NEW.kar_orani_toptan :=
        COALESCE(NEW.kar_orani_toptan, v_sft_orani);

    NEW.kar_orani_liste :=
        COALESCE(NEW.kar_orani_liste, v_sfl_orani);

    NEW.kar_orani_indirimli :=
        COALESCE(NEW.kar_orani_indirimli, v_sfi_orani);

    -- SFP: KDV hariç
    NEW.satis_fiyati_perakende :=
        ROUND(
            COALESCE(NEW.alis_fiyati, 0)
            * (
                1
                + NEW.kar_orani_perakende / 100.0
            ),
            2
        );

    -- SFT: KDV hariç
    NEW.satis_fiyati_toptan :=
        ROUND(
            COALESCE(NEW.alis_fiyati, 0)
            * (
                1
                + NEW.kar_orani_toptan / 100.0
            ),
            2
        );

    -- SFI: KDV hariç
    NEW.satis_fiyati_indirimli :=
        ROUND(
            COALESCE(NEW.alis_fiyati, 0)
            * (
                1
                + NEW.kar_orani_indirimli / 100.0
            ),
            2
        );

    -- SFL: KDV dahil
    NEW.satis_fiyati_liste :=
        ROUND(
            COALESCE(NEW.alis_fiyati, 0)
            * (
                1
                + NEW.kar_orani_liste / 100.0
            )
            * (
                1
                + v_kdv_orani / 100.0
            ),
            2
        );

    RETURN NEW;
END;
$function$;

-- stok_satis_adedi_artir()
CREATE OR REPLACE FUNCTION public.stok_satis_adedi_artir()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    UPDATE stoklar
    SET satis_adedi = satis_adedi + NEW.ara_toplam
    WHERE stok_id = NEW.cari_id; -- Burada stok_id ile eşleşen alanı senin tablo yapına göre ayarlamalıyız
    RETURN NEW;
END;
$function$;

-- stok_satis_fiyatlarini_hesapla()
CREATE OR REPLACE FUNCTION public.stok_satis_fiyatlarini_hesapla()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
    NEW.kar_orani_perakende :=
        COALESCE(NEW.kar_orani_perakende, 35);

    NEW.kar_orani_toptan :=
        COALESCE(NEW.kar_orani_toptan, 25);

    NEW.satis_fiyati_perakende :=
        ROUND(
            COALESCE(NEW.alis_fiyati, 0)
            * (
                1
                + COALESCE(
                    NEW.kar_orani_perakende,
                    35
                ) / 100.0
            ),
            2
        );

    NEW.satis_fiyati_toptan :=
        ROUND(
            COALESCE(NEW.alis_fiyati, 0)
            * (
                1
                + COALESCE(
                    NEW.kar_orani_toptan,
                    25
                ) / 100.0
            ),
            2
        );

    RETURN NEW;
END;
$function$;

-- stok_sayim_duzelt(p_stok_id bigint, p_depo_id bigint, p_sayilan_miktar numeric, p_kullanici text, p_aciklama text)
CREATE OR REPLACE FUNCTION public.stok_sayim_duzelt(p_stok_id bigint, p_depo_id bigint, p_sayilan_miktar numeric, p_kullanici text DEFAULT 'UNAL'::text, p_aciklama text DEFAULT NULL::text)
 RETURNS bigint
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
    v_mevcut numeric := 0;
    v_fark numeric := 0;
    v_hareket_id bigint;
    v_normal_toplam numeric := 0;
begin
    select coalesce(miktar, 0)
      into v_mevcut
      from public.v_pro_stok_depo_durumu
     where stok_id = p_stok_id
       and depo_id = p_depo_id
     limit 1;

    v_fark := coalesce(p_sayilan_miktar, 0) - coalesce(v_mevcut, 0);

    if abs(v_fark) < 0.000001 then
        return 0;
    end if;

    insert into public.stok_hareket (
        tarih,
        stok_id,
        islem_tipi,
        hareket_tipi,
        miktar,
        onceki_stok,
        sonraki_stok,
        belge_no,
        aciklama,
        depo_id,
        kullanici
    )
    values (
        now(),
        p_stok_id,
        'SAYIM',
        case when v_fark > 0 then 'GIRIS' else 'CIKIS' end,
        abs(v_fark),
        v_mevcut,
        p_sayilan_miktar,
        'SAYIM-' || to_char(now(), 'YYYYMMDD-HH24MISS'),
        coalesce(p_aciklama, 'Stok sayım düzeltmesi'),
        p_depo_id,
        coalesce(nullif(trim(p_kullanici), ''), 'UNAL')
    )
    returning hareket_id into v_hareket_id;

    -- stoklar.stok_miktari sadece satılabilir NORMAL depo toplamını taşır.
    select coalesce(sum(v.miktar), 0)
      into v_normal_toplam
      from public.v_pro_stok_depo_durumu v
     where v.stok_id = p_stok_id
       and v.depo_tipi = 'NORMAL';

    update public.stoklar
       set stok_miktari = v_normal_toplam
     where stok_id = p_stok_id;

    return v_hareket_id;
end;
$function$;

-- stok_toplu_fiyat_guncelle(p_fiyat_alani text, p_oran numeric, p_marka text, p_grup text, p_kullanici text)
CREATE OR REPLACE FUNCTION public.stok_toplu_fiyat_guncelle(p_fiyat_alani text, p_oran numeric, p_marka text DEFAULT NULL::text, p_grup text DEFAULT NULL::text, p_kullanici text DEFAULT 'SISTEM'::text)
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
declare
  v_count integer := 0;
  v_factor numeric;
begin
  if p_oran is null or p_oran = 0 then
    raise exception 'Oran 0 olamaz';
  end if;

  v_factor := 1 + (p_oran / 100.0);

  if upper(p_fiyat_alani) = 'ALIS' then
    update public.stoklar
       set alis_fiyati = round(coalesce(alis_fiyati, 0) * v_factor, 2)
     where (p_marka is null or lower(coalesce(marka,'')) = lower(p_marka))
       and (p_grup is null or lower(coalesce(grup,'')) = lower(p_grup));
  elsif upper(p_fiyat_alani) = 'PERAKENDE' then
    update public.stoklar
       set satis_fiyati_perakende = round(coalesce(satis_fiyati_perakende, 0) * v_factor, 2)
     where (p_marka is null or lower(coalesce(marka,'')) = lower(p_marka))
       and (p_grup is null or lower(coalesce(grup,'')) = lower(p_grup));
  elsif upper(p_fiyat_alani) = 'TOPTAN' then
    update public.stoklar
       set satis_fiyati_toptan = round(coalesce(satis_fiyati_toptan, 0) * v_factor, 2)
     where (p_marka is null or lower(coalesce(marka,'')) = lower(p_marka))
       and (p_grup is null or lower(coalesce(grup,'')) = lower(p_grup));
  elsif upper(p_fiyat_alani) = 'INDIRIMLI' then
    update public.stoklar
       set satis_fiyati_indirimli = round(coalesce(satis_fiyati_indirimli, 0) * v_factor, 2)
     where (p_marka is null or lower(coalesce(marka,'')) = lower(p_marka))
       and (p_grup is null or lower(coalesce(grup,'')) = lower(p_grup));
  else
    raise exception 'Gecersiz fiyat alani: %', p_fiyat_alani;
  end if;

  get diagnostics v_count = row_count;
  return v_count;
end;
$function$;

-- stoklar_vector_guncelle()
CREATE OR REPLACE FUNCTION public.stoklar_vector_guncelle()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN

NEW.arama_vector :=
to_tsvector(
'simple',
coalesce(NEW.urun_adi,'')||' '||
coalesce(NEW.uretici_kodu,'')||' '||
coalesce(NEW.oem_no,'')||' '||
coalesce(NEW.cross_kod,'')||' '||
coalesce(NEW.rakip_kod,'')||' '||
coalesce(NEW.barkod,'')||' '||
coalesce(NEW.arac,'')
);

RETURN NEW;

END;
$function$;

-- strict_word_similarity(text, text)
CREATE OR REPLACE FUNCTION public.strict_word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity$function$;

-- strict_word_similarity_commutator_op(text, text)
CREATE OR REPLACE FUNCTION public.strict_word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_commutator_op$function$;

-- strict_word_similarity_dist_commutator_op(text, text)
CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_commutator_op$function$;

-- strict_word_similarity_dist_op(text, text)
CREATE OR REPLACE FUNCTION public.strict_word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_dist_op$function$;

-- strict_word_similarity_op(text, text)
CREATE OR REPLACE FUNCTION public.strict_word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$strict_word_similarity_op$function$;

-- unaccent(regdictionary, text)
CREATE OR REPLACE FUNCTION public.unaccent(regdictionary, text)
 RETURNS text
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/unaccent', $function$unaccent_dict$function$;

-- unaccent(text)
CREATE OR REPLACE FUNCTION public.unaccent(text)
 RETURNS text
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/unaccent', $function$unaccent_dict$function$;

-- unaccent_init(internal)
CREATE OR REPLACE FUNCTION public.unaccent_init(internal)
 RETURNS internal
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/unaccent', $function$unaccent_init$function$;

-- unaccent_lexize(internal, internal, internal, internal)
CREATE OR REPLACE FUNCTION public.unaccent_lexize(internal, internal, internal, internal)
 RETURNS internal
 LANGUAGE c
 PARALLEL SAFE
AS '$libdir/unaccent', $function$unaccent_lexize$function$;

-- update_cari_bakiye()
CREATE OR REPLACE FUNCTION public.update_cari_bakiye()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
  IF NEW.islem_tipi = 'Alış' THEN
    UPDATE cariler 
    SET bakiye = COALESCE(bakiye,0) + (NEW.miktar * NEW.birim_maliyet),
        son_alis_tarihi = NEW.tarih
    WHERE cari_id = NEW.cari_id;
  ELSIF NEW.islem_tipi = 'Satış' THEN
    UPDATE cariler 
    SET bakiye = COALESCE(bakiye,0) - (NEW.miktar * NEW.birim_maliyet),
        son_satis_tarihi = NEW.tarih
    WHERE cari_id = NEW.cari_id;
  END IF;
  RETURN NEW;
END;
$function$;

-- urun_ara(arama text)
CREATE OR REPLACE FUNCTION public.urun_ara(arama text)
 RETURNS SETOF stoklar
 LANGUAGE sql
 STABLE
AS $function$
  select s.*
  from public.stoklar s
  where
    coalesce(trim(arama), '') = ''
    or not exists (
      select 1
      from unnest(
        regexp_split_to_array(
          lower(trim(arama)),
          '\s+'
        )
      ) as kelime
      where lower(
        concat_ws(
          ' ',
          coalesce(s.urun_adi, ''),
          coalesce(s.uretici_kodu, ''),
          coalesce(s.oem_no, ''),
          coalesce(s.marka, ''),
          coalesce(s.model, ''),
          coalesce(s.barkod, ''),
          coalesce(s.cross_kod, ''),
          coalesce(s.rakip_kod, ''),
          coalesce(s.arac, ''),
          coalesce(s.raf, ''),
          coalesce(s.urun_ozellik, ''),
          coalesce(s.arama_metni, '')
        )
      ) not like '%' || kelime || '%'
    )
  order by s.urun_adi;
$function$;

-- word_similarity(text, text)
CREATE OR REPLACE FUNCTION public.word_similarity(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity$function$;

-- word_similarity_commutator_op(text, text)
CREATE OR REPLACE FUNCTION public.word_similarity_commutator_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_commutator_op$function$;

-- word_similarity_dist_commutator_op(text, text)
CREATE OR REPLACE FUNCTION public.word_similarity_dist_commutator_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_commutator_op$function$;

-- word_similarity_dist_op(text, text)
CREATE OR REPLACE FUNCTION public.word_similarity_dist_op(text, text)
 RETURNS real
 LANGUAGE c
 IMMUTABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_dist_op$function$;

-- word_similarity_op(text, text)
CREATE OR REPLACE FUNCTION public.word_similarity_op(text, text)
 RETURNS boolean
 LANGUAGE c
 STABLE PARALLEL SAFE STRICT
AS '$libdir/pg_trgm', $function$word_similarity_op$function$;

-- yeni_alis_irsaliye_no()
CREATE OR REPLACE FUNCTION public.yeni_alis_irsaliye_no()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_yil integer;
    v_son_numara bigint;
BEGIN
    v_yil := extract(year FROM current_date)::integer;

    INSERT INTO public.belge_numaralari (
        belge_tipi,
        yil,
        son_numara
    )
    VALUES (
        'ALIS_IRSALIYE',
        v_yil,
        1
    )
    ON CONFLICT (belge_tipi, yil)
    DO UPDATE
    SET son_numara =
        public.belge_numaralari.son_numara + 1
    RETURNING son_numara
    INTO v_son_numara;

    RETURN
        'AIR-'
        || v_yil
        || '-'
        || lpad(v_son_numara::text, 6, '0');
END;
$function$;

-- yeni_alis_siparis_no()
CREATE OR REPLACE FUNCTION public.yeni_alis_siparis_no()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_yil integer;
    v_son_numara bigint;
BEGIN
    v_yil := extract(year FROM current_date)::integer;

    INSERT INTO public.belge_numaralari
    (
        belge_tipi,
        yil,
        son_numara
    )
    VALUES
    (
        'ALIS_SIPARIS',
        v_yil,
        1
    )
    ON CONFLICT (belge_tipi, yil)
    DO UPDATE
    SET son_numara =
        public.belge_numaralari.son_numara + 1
    RETURNING son_numara
    INTO v_son_numara;

    RETURN
        'ASP-'
        || v_yil
        || '-'
        || lpad(v_son_numara::text, 6, '0');
END;
$function$;

-- yeni_belge_no(p_belge_tipi text)
CREATE OR REPLACE FUNCTION public.yeni_belge_no(p_belge_tipi text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_tip text;
    v_yil integer;
    v_yeni_numara bigint;
    v_prefix text;
BEGIN
    v_tip := upper(trim(p_belge_tipi));
    v_yil := extract(year FROM current_date)::integer;

    IF v_tip = 'ALIS' THEN
        v_prefix := 'AL';
    ELSIF v_tip = 'SATIS' THEN
        v_prefix := 'ST';
    ELSE
        RAISE EXCEPTION
            'Geçersiz belge tipi: %',
            p_belge_tipi;
    END IF;

    INSERT INTO public.belge_numaralari
    (
        belge_tipi,
        yil,
        son_numara
    )
    VALUES
    (
        v_tip,
        v_yil,
        1
    )
    ON CONFLICT (belge_tipi, yil)
    DO UPDATE
    SET son_numara =
        public.belge_numaralari.son_numara + 1
    RETURNING son_numara
    INTO v_yeni_numara;

    RETURN
        v_prefix
        || '-'
        || v_yil
        || '-'
        || lpad(v_yeni_numara::text, 6, '0');
END;
$function$;

-- yeni_iade_no(p_iade_tipi text)
CREATE OR REPLACE FUNCTION public.yeni_iade_no(p_iade_tipi text)
 RETURNS text
 LANGUAGE plpgsql
AS $function$
DECLARE
    v_prefix text;
    v_sira bigint;
BEGIN
    v_prefix := CASE
        WHEN upper(p_iade_tipi) = 'SATIS_IADE' THEN 'SI'
        ELSE 'AI'
    END;

    SELECT coalesce(max(iade_id), 0) + 1
    INTO v_sira
    FROM public.iade_baslik;

    RETURN v_prefix || '-' ||
           to_char(current_date, 'YYYY') || '-' ||
           lpad(v_sira::text, 6, '0');
END;
$function$;

-- yeni_kasa_belge_no(p_islem_tipi text)
CREATE OR REPLACE FUNCTION public.yeni_kasa_belge_no(p_islem_tipi text)
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_tip text;
    v_yil integer;
    v_son_numara bigint;
    v_on_ek text;
BEGIN
    v_tip := upper(trim(p_islem_tipi));
    v_yil := extract(year FROM current_date)::integer;

    IF v_tip = 'TAHSILAT' THEN
        v_on_ek := 'TH';
    ELSIF v_tip = 'ODEME' THEN
        v_on_ek := 'OD';
    ELSE
        RAISE EXCEPTION
            'Geçersiz kasa işlem tipi: %',
            p_islem_tipi;
    END IF;

    INSERT INTO public.belge_numaralari
    (
        belge_tipi,
        yil,
        son_numara
    )
    VALUES
    (
        v_tip,
        v_yil,
        1
    )
    ON CONFLICT (belge_tipi, yil)
    DO UPDATE
    SET son_numara =
        public.belge_numaralari.son_numara + 1
    RETURNING son_numara
    INTO v_son_numara;

    RETURN
        v_on_ek
        || '-'
        || v_yil
        || '-'
        || lpad(v_son_numara::text, 6, '0');
END;
$function$;

-- yeni_satis_irsaliye_no()
CREATE OR REPLACE FUNCTION public.yeni_satis_irsaliye_no()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_yil integer;
    v_son_numara bigint;
BEGIN
    v_yil := extract(year FROM current_date)::integer;

    INSERT INTO public.belge_numaralari (
        belge_tipi,
        yil,
        son_numara
    )
    VALUES (
        'SATIS_IRSALIYE',
        v_yil,
        1
    )
    ON CONFLICT (belge_tipi, yil)
    DO UPDATE
    SET son_numara =
        public.belge_numaralari.son_numara + 1
    RETURNING son_numara
    INTO v_son_numara;

    RETURN
        'SIR-'
        || v_yil
        || '-'
        || lpad(v_son_numara::text, 6, '0');
END;
$function$;

-- yeni_satis_siparis_no()
CREATE OR REPLACE FUNCTION public.yeni_satis_siparis_no()
 RETURNS text
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'public'
AS $function$
DECLARE
    v_yil integer;
    v_son_numara bigint;
BEGIN
    v_yil := extract(year FROM current_date)::integer;

    INSERT INTO public.belge_numaralari
    (
        belge_tipi,
        yil,
        son_numara
    )
    VALUES
    (
        'SATIS_SIPARIS',
        v_yil,
        1
    )
    ON CONFLICT (belge_tipi, yil)
    DO UPDATE
    SET son_numara =
        public.belge_numaralari.son_numara + 1
    RETURNING son_numara
    INTO v_son_numara;

    RETURN
        'SSP-'
        || v_yil
        || '-'
        || lpad(v_son_numara::text, 6, '0');
END;
$function$;
