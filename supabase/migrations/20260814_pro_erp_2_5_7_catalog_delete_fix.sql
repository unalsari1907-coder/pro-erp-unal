/* PRO-ERP 2.5.7 - Katalog parça silme 22025 düzeltmesi
   Önceki sürümde LIKE ... ESCAPE ifadesi iki karakterli escape ürettiği için
   PostgreSQL 22025 invalid escape string hatası veriyordu.
   Bu sürüm LIKE/ESCAPE kullanmaz; OZEL_ öneki doğrudan kontrol edilir. */

create or replace function public.erp_arac_katalog_global_parca_sil(
  p_kategori_kodu text
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_kod text := trim(coalesce(p_kategori_kodu, ''));
  v_count integer := 0;
begin
  if v_kod = '' then
    raise exception 'Kategori kodu boş olamaz.';
  end if;

  -- Sadece kullanıcının sonradan oluşturduğu OZEL_ parçalar global silinebilir.
  -- LIKE ... ESCAPE kullanılmadığı için 22025 hatası oluşmaz.
  if left(v_kod, 5) <> 'OZEL_' then
    raise exception 'Standart katalog parçaları tüm katalogdan silinemez.';
  end if;

  delete from public.erp_arac_katalog_parcalar
  where kategori_kodu = v_kod;
  get diagnostics v_count = row_count;

  delete from public.erp_arac_katalog_sablon
  where kategori_kodu = v_kod;

  return v_count;
end;
$$;

grant execute on function public.erp_arac_katalog_global_parca_sil(text)
  to anon, authenticated;

select '2.5.7 katalog silme 22025 düzeltmesi hazır' as durum;
