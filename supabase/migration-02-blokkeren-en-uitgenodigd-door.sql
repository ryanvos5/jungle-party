-- =============================================================
--  Jungle Party - uitbreiding 2
--
--  1. Gasten vullen bij het aanmelden in door wie ze zijn uitgenodigd
--  2. De organisator kan een gast blokkeren; die komt er niet meer in
--
--  Draai dit in de SQL Editor, na schema.sql.
-- =============================================================

-- -------------------------------------------------------------
--  Nieuwe kolommen
-- -------------------------------------------------------------
alter table public.guests add column if not exists invited_by text;
alter table public.guests add column if not exists blocked_at timestamptz;
alter table public.guests add column if not exists blocked_by text;

-- Bestaande aanmeldingen hebben dit veld nog niet ingevuld
update public.guests set invited_by = 'Onbekend' where invited_by is null;

alter table public.guests alter column invited_by set not null;

-- -------------------------------------------------------------
--  register_guest krijgt een veld erbij.
--  De oude versie moet weg: twee functies met dezelfde naam maken
--  de API dubbelzinnig.
-- -------------------------------------------------------------
drop function if exists public.register_guest(text, text, text, text);

create or replace function public.register_guest(
  p_first_name text,
  p_last_name  text,
  p_email      text,
  p_phone      text,
  p_invited_by text
)
returns text
language plpgsql
security definer
set search_path = public
as $fn$
declare
  v_first   text := btrim(coalesce(p_first_name, ''));
  v_last    text := btrim(coalesce(p_last_name,  ''));
  v_email   text := lower(btrim(coalesce(p_email, '')));
  v_phone   text := btrim(coalesce(p_phone, ''));
  v_invited text := btrim(coalesce(p_invited_by, ''));
  v_norm    text := public.normalize_phone(p_phone);
  v_token   text;
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

  if length(v_invited) < 2 or length(v_invited) > 80 then
    raise exception 'INVALID_INVITED_BY';
  end if;

  if exists (select 1 from public.guests g where lower(g.email) = v_email) then
    raise exception 'EMAIL_TAKEN';
  end if;

  if exists (select 1 from public.guests g where g.phone_norm = v_norm) then
    raise exception 'PHONE_TAKEN';
  end if;

  v_token := replace(gen_random_uuid()::text, '-', '');

  insert into public.guests (first_name, last_name, email, phone, phone_norm, token, invited_by)
  values (v_first, v_last, v_email, v_phone, v_norm, v_token, v_invited);

  return v_token;
end;
$fn$;

-- -------------------------------------------------------------
--  scan_ticket: geblokkeerde gasten worden geweigerd.
--  Dit gaat voor op alle andere controles, en zo'n ticket wordt
--  ook niet als 'gescand' weggeschreven.
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

  if g.blocked_at is not null then
    return jsonb_build_object(
      'status',     'blocked',
      'first_name', g.first_name,
      'last_name',  g.last_name,
      'invited_by', g.invited_by
    );
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
    'last_name',  g.last_name,
    'invited_by', g.invited_by
  );
end;
$fn$;

-- -------------------------------------------------------------
--  set_blocked: gast blokkeren of weer vrijgeven.
--  Alleen de organisator.
-- -------------------------------------------------------------
create or replace function public.set_blocked(p_id uuid, p_blocked boolean)
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
     set blocked_at = case when p_blocked then now() else null end,
         blocked_by = case when p_blocked then coalesce(auth.jwt() ->> 'email', 'organisator') else null end
   where id = p_id;
end;
$fn$;

-- -------------------------------------------------------------
--  Rechten
-- -------------------------------------------------------------
revoke all on function public.register_guest(text, text, text, text, text) from public;
revoke all on function public.set_blocked(uuid, boolean)                   from public;

grant execute on function public.register_guest(text, text, text, text, text) to anon, authenticated;
grant execute on function public.set_blocked(uuid, boolean)                   to authenticated;

-- De API opnieuw laten inlezen
notify pgrst, 'reload schema';
