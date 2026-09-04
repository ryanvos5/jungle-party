-- =============================================================
--  Stap 2: wie mag scannen en de gastenlijst zien?
--
--  Vervang het adres hieronder door jouw eigen e-mailadres en
--  draai dit in de SQL Editor van Supabase.
--
--  Let op: maak daarna in Authentication -> Users een gebruiker
--  aan met exact hetzelfde e-mailadres. Zonder allebei werkt
--  inloggen niet.
-- =============================================================

insert into public.owner_emails (email)
values ('jouw@email.nl')
on conflict (email) do nothing;

-- Controle: dit hoort jouw adres terug te geven
select * from public.owner_emails;
