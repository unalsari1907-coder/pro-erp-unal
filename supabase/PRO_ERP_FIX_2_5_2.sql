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
