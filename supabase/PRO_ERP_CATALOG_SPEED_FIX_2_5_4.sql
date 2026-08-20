/*
============================================================
 PRO-ERP 2.5.4 - ARAÇ KATALOĞU KESİN HIZLANDIRMA
============================================================
 - Ana parça şablonunu ayrı tabloda tutar.
 - Yeni araç açarken eski araç/parça kayıtlarını istemciye çekmez.
 - 102+ ortak parça, INSERT ... SELECT ile veritabanında tek işlemde eklenir.
 - Yeni global parça da bütün araçlara veritabanı tarafında dağıtılabilir.
============================================================
*/

create table if not exists public.erp_arac_katalog_sablon (
  kategori_kodu text primary key,
  kategori_adi text not null,
  nitelik text,
  sira integer not null default 0,
  updated_at timestamptz not null default now()
);

-- Mevcut katalogdaki bütün benzersiz parça kalemlerini bir defa ana şablona al.
insert into public.erp_arac_katalog_sablon
  (kategori_kodu, kategori_adi, nitelik, sira, updated_at)
select distinct on (p.kategori_kodu)
  p.kategori_kodu,
  p.kategori_adi,
  p.nitelik,
  coalesce(p.sira, 0),
  now()
from public.erp_arac_katalog_parcalar p
where nullif(trim(p.kategori_kodu), '') is not null
order by p.kategori_kodu, p.sira, p.parca_id
on conflict (kategori_kodu) do update
set kategori_adi = excluded.kategori_adi,
    nitelik = coalesce(excluded.nitelik, public.erp_arac_katalog_sablon.nitelik),
    sira = least(public.erp_arac_katalog_sablon.sira, excluded.sira),
    updated_at = now();

create index if not exists idx_erp_arac_katalog_sablon_sira
  on public.erp_arac_katalog_sablon (sira, kategori_kodu);

alter table public.erp_arac_katalog_sablon enable row level security;
drop policy if exists pro_erp_gecis_erp_arac_katalog_sablon on public.erp_arac_katalog_sablon;
create policy pro_erp_gecis_erp_arac_katalog_sablon
on public.erp_arac_katalog_sablon
for all to anon, authenticated
using (true)
with check (true);

grant select, insert, update, delete on public.erp_arac_katalog_sablon to anon, authenticated;

-- Yalnız TEK yeni aracı ana şablonla tamamlar. İstemciye eski kayıt taşımaz.
create or replace function public.erp_arac_katalog_arac_sablon_tamamla(p_arac_id bigint)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_count integer := 0;
begin
  insert into public.erp_arac_katalog_parcalar
    (arac_id, kategori_kodu, kategori_adi, oem_kodu, ham_deger, nitelik, sira)
  select
    p_arac_id,
    s.kategori_kodu,
    s.kategori_adi,
    null,
    null,
    s.nitelik,
    s.sira
  from public.erp_arac_katalog_sablon s
  where not exists (
    select 1
    from public.erp_arac_katalog_parcalar p
    where p.arac_id = p_arac_id
      and p.kategori_kodu = s.kategori_kodu
  )
  order by s.sira, s.kategori_kodu
  on conflict do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.erp_arac_katalog_arac_sablon_tamamla(bigint) to anon, authenticated;

-- Yeni bir ortak parçayı şablona kaydeder ve eksik olan bütün araçlara DB içinde dağıtır.
create or replace function public.erp_arac_katalog_global_parca_yay(
  p_kategori_kodu text,
  p_kategori_adi text,
  p_nitelik text default null
)
returns integer
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_sira integer;
  v_count integer := 0;
begin
  select coalesce(max(sira), -1) + 1
    into v_sira
  from public.erp_arac_katalog_sablon;

  insert into public.erp_arac_katalog_sablon
    (kategori_kodu, kategori_adi, nitelik, sira, updated_at)
  values
    (trim(p_kategori_kodu), trim(p_kategori_adi), p_nitelik, v_sira, now())
  on conflict (kategori_kodu) do update
  set kategori_adi = excluded.kategori_adi,
      nitelik = excluded.nitelik,
      updated_at = now();

  select sira into v_sira
  from public.erp_arac_katalog_sablon
  where kategori_kodu = trim(p_kategori_kodu);

  insert into public.erp_arac_katalog_parcalar
    (arac_id, kategori_kodu, kategori_adi, oem_kodu, ham_deger, nitelik, sira)
  select
    a.arac_id,
    trim(p_kategori_kodu),
    trim(p_kategori_adi),
    null,
    null,
    p_nitelik,
    v_sira
  from public.erp_arac_katalog_araclar a
  where not exists (
    select 1
    from public.erp_arac_katalog_parcalar p
    where p.arac_id = a.arac_id
      and p.kategori_kodu = trim(p_kategori_kodu)
  )
  on conflict do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.erp_arac_katalog_global_parca_yay(text,text,text) to anon, authenticated;

-- Mevcut bütün araçları şablonla topluca eşitlemek istenirse elle çağrılabilir.
-- Uygulama açılışında otomatik çalıştırılmaz.
create or replace function public.erp_arac_katalog_tum_araclari_sablonla()
returns bigint
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_count bigint := 0;
begin
  insert into public.erp_arac_katalog_parcalar
    (arac_id, kategori_kodu, kategori_adi, oem_kodu, ham_deger, nitelik, sira)
  select
    a.arac_id,
    s.kategori_kodu,
    s.kategori_adi,
    null,
    null,
    s.nitelik,
    s.sira
  from public.erp_arac_katalog_araclar a
  cross join public.erp_arac_katalog_sablon s
  where not exists (
    select 1
    from public.erp_arac_katalog_parcalar p
    where p.arac_id = a.arac_id
      and p.kategori_kodu = s.kategori_kodu
  )
  on conflict do nothing;

  get diagnostics v_count = row_count;
  return v_count;
end;
$$;

grant execute on function public.erp_arac_katalog_tum_araclari_sablonla() to anon, authenticated;

analyze public.erp_arac_katalog_sablon;
analyze public.erp_arac_katalog_araclar;
analyze public.erp_arac_katalog_parcalar;

select
  (select count(*) from public.erp_arac_katalog_sablon) as ortak_parca_sayisi,
  (select count(*) from public.erp_arac_katalog_araclar) as arac_sayisi;
