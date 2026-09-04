-- =============================================================
--  Jungle Party - ticketsysteem
--  Database schema voor Supabase (PostgreSQL)
-- =============================================================

-- -------------------------------------------------------------
--  Tabel: owner_emails
--  Allowlist van e-mailadressen die organisator mogen zijn.
--  Alleen accounts met een adres uit deze lijst zien de gastenlijst
--  en mogen scannen. Verder niemand - ook niet wie zelf een
--  account aanmaakt op dit Supabase-project.
-- -------------------------------------------------------------
create table if not exists public.owner_emails (
  email text primary key
);

alter table public.owner_emails enable row level security;
-- Bewust geen policies: deze tabel is alleen bereikbaar via de
-- security-definer functies hieronder en via de service role.

-- -------------------------------------------------------------
--  Tabel: guests
-- -------------------------------------------------------------
create table if not exists public.guests (
  id          uuid primary key default gen_random_uuid(),
  first_name  text        not null,
  last_name   text        not null,
  email       text        not null,
  phone       text        not null,
  phone_norm  text        not null,
  token       text        not null unique,
  created_at  timestamptz not null default now(),
  scanned_at  timestamptz,
  scanned_by  text
);

create unique index if not exists guests_email_uniq  on public.guests (lower(email));
create unique index if not exists guests_phone_uniq  on public.guests (phone_norm);
create index        if not exists guests_created_idx on public.guests (created_at desc);

alter table public.guests enable row level security;

-- -------------------------------------------------------------
--  Helper: is de ingelogde gebruiker de organisator?
-- -------------------------------------------------------------
create or replace function public.is_owner()
returns boolean
language sql
stable
security definer
set search_path = public
as $fn$
  select exists (
    select 1
    from public.owner_emails oe
    where lower(oe.email) = lower(coalesce(auth.jwt() ->> 'email', ''))
  );
$fn$;

-- -------------------------------------------------------------
--  RLS policies op guests
--  Gasten (anon) kunnen NIETS rechtstreeks lezen of schrijven.
--  Zij gaan uitsluitend via de RPC-functies onderaan.
-- -------------------------------------------------------------
drop policy if exists "owner leest alles"   on public.guests;
drop policy if exists "owner wijzigt alles" on public.guests;
drop policy if exists "owner verwijdert"    on public.guests;

create policy "owner leest alles"
  on public.guests for select to authenticated
  using (public.is_owner());

create policy "owner wijzigt alles"
  on public.guests for update to authenticated
  using (public.is_owner()) with check (public.is_owner());

create policy "owner verwijdert"
  on public.guests for delete to authenticated
  using (public.is_owner());

-- -------------------------------------------------------------
--  Helper: telefoonnummer normaliseren naar alleen cijfers, met
--  +31 / 0031 omgezet naar 0, zodat 0612345678 en +31612345678
--  als hetzelfde nummer gelden.
-- -------------------------------------------------------------
create or replace function public.normalize_phone(p text)
returns text
language plpgsql
immutable
as $fn$
declare
  d text := regexp_replace(coalesce(p, ''), '[^0-9]', '', 'g');
begin
  if d like '0031%' then
    return '0' || substr(d, 5);
  elsif d like '31%' and length(d) = 11 then
    return '0' || substr(d, 3);
  else
    return d;
  end if;
end;
$fn$;

-- -------------------------------------------------------------
--  RPC: register_guest
--  Meldt een gast aan en geeft het persoonlijke token terug.
--  Aanroepbaar door iedereen die de link heeft (anon).
-- -------------------------------------------------------------
create or replace function public.register_guest(
  p_first_name text,
  p_last_name  text,
  p_email      text,
  p_phone      text
)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_first text := btrim(coalesce(p_first_name, ''));
  v_last  text := btrim(coalesce(p_last_name,  ''));
  v_email text := lower(btrim(coalesce(p_email, '')));
  v_phone text := btrim(coalesce(p_phone, ''));
  v_norm  text := public.normalize_phone(p_phone);
  v_token text;
begin
  if length(v_first) < 2 or length(v_first) > 60 then
    raise exception 'INVALID_FIRST_NAME';
  end if;

  if length(v_last) < 2 or length(v_last) > 60 then
    raise exception 'INVALID_LAST_NAME';
  end if;

  if v_email !~ '^[^@[:space:]]+@[^@[:space:]]+\.[a-z]{2,}$' or length(v_email) > 160 then
    raise exception 'INVALID_EMAIL';
  end if;

  if length(v_norm) < 8 or length(v_norm) > 15 then
    raise exception 'INVALID_PHONE';
  end if;

  if exists (select 1 from public.guests g where lower(g.email) = v_email) then
    raise exception 'EMAIL_TAKEN';
  end if;

  if exists (select 1 from public.guests g where g.phone_norm = v_norm) then
    raise exception 'PHONE_TAKEN';
  end if;

  -- 32 hex tekens = 128 bits willekeur, niet te raden
  v_token := replace(gen_random_uuid()::text, '-', '');

  insert into public.guests (first_name, last_name, email, phone, phone_norm, token)
  values (v_first, v_last, v_email, v_phone, v_norm, v_token);

  return v_token;
end;
$fn$;

-- -------------------------------------------------------------
--  RPC: get_ticket
--  Haalt 1 ticket op aan de hand van het token. Geeft bewust
--  geen e-mailadres of telefoonnummer terug.
-- -------------------------------------------------------------
create or replace function public.get_ticket(p_token text)
returns table (
  first_name text,
  last_name  text,
  created_at timestamptz,
  scanned_at timestamptz
)
language sql
stable
security definer
set search_path = public
as $fn$
  select g.first_name, g.last_name, g.created_at, g.scanned_at
  from public.guests g
  where g.token = p_token;
$fn$;

-- -------------------------------------------------------------
--  RPC: scan_ticket
--  Alleen de organisator. Zet het ticket op gescand.
--  Een tweede scan wordt geweigerd met status 'already'.
-- -------------------------------------------------------------
create or replace function public.scan_ticket(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $fn$
declare
  g public.guests%rowtype;
begin
  if not public.is_owner() then
    raise exception 'NOT_AUTHORIZED';
  end if;

  select * into g from public.guests where token = p_token;

  if not found then
    return jsonb_build_object('status', 'invalid');
  end if;

  if g.scanned_at is not null then
    return jsonb_build_object(
      'status',     'already',
      'first_name', g.first_name,
      'last_name',  g.last_name,
      'scanned_at', g.scanned_at,
      'scanned_by', g.scanned_by
    );
  end if;

  update public.guests
     set scanned_at = now(),
         scanned_by = coalesce(auth.jwt() ->> 'email', 'organisator')
   where id = g.id;

  return jsonb_build_object(
    'status',     'ok',
    'first_name', g.first_name,
    'last_name',  g.last_name
  );
end;
$fn$;

-- -------------------------------------------------------------
--  RPC: unscan_ticket
--  Alleen de organisator. Maakt een scan ongedaan (bij vergissing).
-- -------------------------------------------------------------
create or replace function public.unscan_ticket(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $fn$
begin
  if not public.is_owner() then
    raise exception 'NOT_AUTHORIZED';
  end if;

  update public.guests
     set scanned_at = null,
         scanned_by = null
   where id = p_id;
end;
$fn$;

-- -------------------------------------------------------------
--  Rechten: dicht by default, daarna gericht uitdelen
-- -------------------------------------------------------------
revoke all on function public.register_guest(text, text, text, text) from public;
revoke all on function public.get_ticket(text)                       from public;
revoke all on function public.scan_ticket(text)                      from public;
revoke all on function public.unscan_ticket(uuid)                    from public;
revoke all on function public.is_owner()                             from public;

grant execute on function public.register_guest(text, text, text, text) to anon, authenticated;
grant execute on function public.get_ticket(text)                       to anon, authenticated;
grant execute on function public.scan_ticket(text)                      to authenticated;
grant execute on function public.unscan_ticket(uuid)                    to authenticated;
grant execute on function public.is_owner()                             to authenticated;
