-- PRO ERP 2.5.22 - Katalog SQL/RPC Motoru
-- Supabase SQL Editor'da BIR KEZ çalıştırın.
-- Araç arama, araç parçaları ve OEM araması PostgreSQL tarafında çalışır.

create extension if not exists pg_trgm;

-- Arama alanlarının birleşik trigram indeksi. Çok kelimeli ILIKE aramalarını hızlandırır.
create index if not exists idx_erp_arac_katalog_araclar_search_trgm
on public.erp_arac_katalog_araclar using gin (
  lower(
    coalesce(uretici::text,'') || ' ' ||
    coalesce(model::text,'') || ' ' ||
    coalesce(yil::text,'') || ' ' ||
    coalesce(yillar::text,'') || ' ' ||
    coalesce(motor::text,'') || ' ' ||
    coalesce(yakit::text,'') || ' ' ||
    coalesce(motor_kodu::text,'') || ' ' ||
    coalesce(sase::text,'') || ' ' ||
    coalesce(notlar::text,'') || ' ' ||
    coalesce(arac_sahibi::text,'')
  ) gin_trgm_ops
);

create index if not exists idx_erp_arac_katalog_araclar_sort
  on public.erp_arac_katalog_araclar (uretici, model, yil, arac_id);
create index if not exists idx_erp_arac_katalog_parcalar_arac_sira
  on public.erp_arac_katalog_parcalar (arac_id, sira, parca_id);
create index if not exists idx_erp_arac_katalog_parcalar_arac_kategori
  on public.erp_arac_katalog_parcalar (arac_id, kategori_kodu);
create index if not exists idx_erp_arac_katalog_parcalar_oem_trgm
  on public.erp_arac_katalog_parcalar using gin (lower(coalesce(oem_kodu::text,'')) gin_trgm_ops);

create or replace function public.erp_katalog_arac_ara(
  p_query text default '',
  p_limit integer default 120
)
returns setof jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with p as (
    select
      lower(trim(coalesce(p_query,''))) as q,
      regexp_split_to_array(lower(trim(coalesce(p_query,''))), '\\s+') as tokens,
      greatest(1, least(coalesce(p_limit,120), 250)) as lim
  ), aday as (
    select
      a.*,
      lower(
        coalesce(a.uretici::text,'') || ' ' ||
        coalesce(a.model::text,'') || ' ' ||
        coalesce(a.yil::text,'') || ' ' ||
        coalesce(a.yillar::text,'') || ' ' ||
        coalesce(a.motor::text,'') || ' ' ||
        coalesce(a.yakit::text,'') || ' ' ||
        coalesce(a.motor_kodu::text,'') || ' ' ||
        coalesce(a.sase::text,'') || ' ' ||
        coalesce(a.notlar::text,'') || ' ' ||
        coalesce(a.arac_sahibi::text,'')
      ) as hay
    from public.erp_arac_katalog_araclar a
  )
  select jsonb_build_object(
    'arac_id', a.arac_id,
    'uretici', a.uretici,
    'model', a.model,
    'yil', a.yil,
    'yillar', a.yillar,
    'motor', a.motor,
    'yakit', a.yakit,
    'motor_kodu', a.motor_kodu,
    'sase', a.sase,
    'notlar', a.notlar,
    'arac_sahibi', a.arac_sahibi
  )
  from aday a, p
  where p.q = ''
     or not exists (
       select 1
       from unnest(p.tokens) t
       where length(trim(t)) > 0
         and a.hay not like '%' || trim(t) || '%'
     )
  order by
    case when p.q <> '' and lower(coalesce(a.uretici::text,'')) = p.q then 0 else 1 end,
    case when p.q <> '' and lower(coalesce(a.model::text,'')) = p.q then 0 else 1 end,
    case when p.q <> '' and a.hay like p.q || '%' then 0 else 1 end,
    case when p.q <> '' then similarity(a.hay, p.q) else 0 end desc,
    a.uretici, a.model, a.yil, a.arac_id
  limit (select lim from p);
$$;

create or replace function public.erp_katalog_arac_parcalari(
  p_arac_id bigint
)
returns setof jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'parca_id', p.parca_id,
    'arac_id', p.arac_id,
    'kategori_kodu', p.kategori_kodu,
    'kategori_adi', p.kategori_adi,
    'oem_kodu', p.oem_kodu,
    'ham_deger', p.ham_deger,
    'nitelik', p.nitelik,
    'sira', p.sira
  )
  from public.erp_arac_katalog_parcalar p
  where p.arac_id = p_arac_id
  order by p.sira nulls last, p.parca_id;
$$;

create or replace function public.erp_katalog_oem_ara(
  p_oem text,
  p_limit integer default 100
)
returns setof jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with x as (
    select lower(trim(coalesce(p_oem,''))) q,
           greatest(1, least(coalesce(p_limit,100), 250)) lim
  )
  select jsonb_build_object(
    'parca_id', p.parca_id,
    'arac_id', p.arac_id,
    'kategori_kodu', p.kategori_kodu,
    'kategori_adi', p.kategori_adi,
    'oem_kodu', p.oem_kodu,
    'nitelik', p.nitelik,
    'sira', p.sira,
    'uretici', a.uretici,
    'model', a.model,
    'yil', a.yil,
    'yillar', a.yillar,
    'motor', a.motor,
    'motor_kodu', a.motor_kodu,
    'sase', a.sase
  )
  from public.erp_arac_katalog_parcalar p
  join public.erp_arac_katalog_araclar a on a.arac_id = p.arac_id
  cross join x
  where x.q <> ''
    and lower(coalesce(p.oem_kodu::text,'')) like '%' || x.q || '%'
  order by
    case when lower(coalesce(p.oem_kodu::text,'')) = x.q then 0 else 1 end,
    similarity(lower(coalesce(p.oem_kodu::text,'')), x.q) desc,
    a.uretici, a.model, a.yil, p.sira
  limit (select lim from x);
$$;

-- Supabase API rollerinin RPC'leri çağırabilmesi için.
grant execute on function public.erp_katalog_arac_ara(text, integer) to anon, authenticated, service_role;
grant execute on function public.erp_katalog_arac_parcalari(bigint) to anon, authenticated, service_role;
grant execute on function public.erp_katalog_oem_ara(text, integer) to anon, authenticated, service_role;

analyze public.erp_arac_katalog_araclar;
analyze public.erp_arac_katalog_parcalar;

-- ============================================================================
-- 2.5.22 OEM KALICI SILME KORUMASI
-- Kullanıcının araçtan sildiği OEM, şablon/import tarafından tekrar oluşturulsa
-- bile ekranda geri gelmez. Kullanıcı OEM'i elle yeniden eklerse tombstone kalkar.
-- ============================================================================

create table if not exists public.erp_arac_katalog_silinen_oem (
  arac_id bigint not null,
  kategori_kodu text not null,
  oem_norm text not null,
  oem_kodu text,
  silindi_at timestamptz not null default now(),
  primary key (arac_id, kategori_kodu, oem_norm)
);

create index if not exists idx_erp_arac_katalog_silinen_oem_arac
  on public.erp_arac_katalog_silinen_oem (arac_id, kategori_kodu);

create or replace function public.erp_katalog_oem_kalici_sil(
  p_parca_id bigint
)
returns jsonb
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_row public.erp_arac_katalog_parcalar%rowtype;
  v_norm text;
  v_kalan integer;
begin
  select * into v_row
  from public.erp_arac_katalog_parcalar
  where parca_id = p_parca_id
  for update;

  if not found then
    raise exception 'Katalog OEM kaydı bulunamadı: %', p_parca_id;
  end if;

  if coalesce(trim(v_row.oem_kodu::text), '') = '' then
    raise exception 'Silinecek OEM kodu boş.';
  end if;

  v_norm := regexp_replace(upper(trim(v_row.oem_kodu::text)), '[^A-Z0-9]', '', 'g');

  insert into public.erp_arac_katalog_silinen_oem(
    arac_id, kategori_kodu, oem_norm, oem_kodu, silindi_at
  ) values (
    v_row.arac_id, v_row.kategori_kodu, v_norm, v_row.oem_kodu::text, now()
  )
  on conflict (arac_id, kategori_kodu, oem_norm)
  do update set oem_kodu = excluded.oem_kodu, silindi_at = now();

  select count(*) into v_kalan
  from public.erp_arac_katalog_parcalar p
  where p.arac_id = v_row.arac_id
    and p.kategori_kodu = v_row.kategori_kodu
    and p.parca_id <> v_row.parca_id
    and coalesce(trim(p.oem_kodu::text), '') <> '';

  if v_kalan = 0 then
    update public.erp_arac_katalog_parcalar
       set oem_kodu = null, ham_deger = null
     where parca_id = v_row.parca_id;
  else
    delete from public.erp_arac_katalog_parcalar
     where parca_id = v_row.parca_id;
  end if;

  return jsonb_build_object(
    'ok', true,
    'arac_id', v_row.arac_id,
    'kategori_kodu', v_row.kategori_kodu,
    'oem', v_row.oem_kodu
  );
end;
$$;

create or replace function public.erp_katalog_oem_silme_iptal(
  p_arac_id bigint,
  p_kategori_kodu text,
  p_oem text
)
returns boolean
language plpgsql
security invoker
set search_path = public
as $$
declare
  v_norm text := regexp_replace(upper(trim(coalesce(p_oem, ''))), '[^A-Z0-9]', '', 'g');
begin
  delete from public.erp_arac_katalog_silinen_oem
   where arac_id = p_arac_id
     and kategori_kodu = p_kategori_kodu
     and oem_norm = v_norm;
  return true;
end;
$$;

-- Parça listesini tombstone tablosuna göre filtrele.
create or replace function public.erp_katalog_arac_parcalari(
  p_arac_id bigint
)
returns setof jsonb
language sql
stable
security invoker
set search_path = public
as $$
  select jsonb_build_object(
    'parca_id', p.parca_id,
    'arac_id', p.arac_id,
    'kategori_kodu', p.kategori_kodu,
    'kategori_adi', p.kategori_adi,
    'oem_kodu', p.oem_kodu,
    'ham_deger', p.ham_deger,
    'nitelik', p.nitelik,
    'sira', p.sira
  )
  from public.erp_arac_katalog_parcalar p
  where p.arac_id = p_arac_id
    and (
      coalesce(trim(p.oem_kodu::text), '') = ''
      or not exists (
        select 1
        from public.erp_arac_katalog_silinen_oem s
        where s.arac_id = p.arac_id
          and s.kategori_kodu = p.kategori_kodu
          and s.oem_norm = regexp_replace(upper(trim(p.oem_kodu::text)), '[^A-Z0-9]', '', 'g')
      )
    )
  order by p.sira nulls last, p.parca_id;
$$;

-- Global OEM araması da kullanıcı tarafından araçtan silinen eşleşmeleri döndürmez.
create or replace function public.erp_katalog_oem_ara(
  p_oem text,
  p_limit integer default 100
)
returns setof jsonb
language sql
stable
security invoker
set search_path = public
as $$
  with x as (
    select lower(trim(coalesce(p_oem,''))) q,
           greatest(1, least(coalesce(p_limit,100), 250)) lim
  )
  select jsonb_build_object(
    'parca_id', p.parca_id,
    'arac_id', p.arac_id,
    'kategori_kodu', p.kategori_kodu,
    'kategori_adi', p.kategori_adi,
    'oem_kodu', p.oem_kodu,
    'nitelik', p.nitelik,
    'uretici', a.uretici,
    'model', a.model,
    'yil', a.yil,
    'yillar', a.yillar,
    'motor', a.motor,
    'motor_kodu', a.motor_kodu,
    'sase', a.sase
  )
  from public.erp_arac_katalog_parcalar p
  join public.erp_arac_katalog_araclar a on a.arac_id = p.arac_id
  cross join x
  where x.q <> ''
    and lower(coalesce(p.oem_kodu::text,'')) like '%' || x.q || '%'
    and not exists (
      select 1
      from public.erp_arac_katalog_silinen_oem s
      where s.arac_id = p.arac_id
        and s.kategori_kodu = p.kategori_kodu
        and s.oem_norm = regexp_replace(upper(trim(p.oem_kodu::text)), '[^A-Z0-9]', '', 'g')
    )
  order by
    case when lower(coalesce(p.oem_kodu::text,'')) = x.q then 0 else 1 end,
    similarity(lower(coalesce(p.oem_kodu::text,'')), x.q) desc,
    a.uretici, a.model, p.kategori_adi
  limit (select lim from x);
$$;

grant select, insert, update, delete on public.erp_arac_katalog_silinen_oem to anon, authenticated, service_role;
grant execute on function public.erp_katalog_oem_kalici_sil(bigint) to anon, authenticated, service_role;
grant execute on function public.erp_katalog_oem_silme_iptal(bigint, text, text) to anon, authenticated, service_role;
grant execute on function public.erp_katalog_arac_parcalari(bigint) to anon, authenticated, service_role;
grant execute on function public.erp_katalog_oem_ara(text, integer) to anon, authenticated, service_role;
