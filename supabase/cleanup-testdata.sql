-- =============================================================
--  Testgasten opruimen
--
--  Tijdens het opzetten zijn er twee testaanmeldingen gemaakt.
--  Draai dit in de SQL Editor voordat je de link rondstuurt.
-- =============================================================

delete from public.guests
where email in (
  'test.gast@voorbeeld.nl',
  'proef.aanmelding@voorbeeld.nl',
  'controle.migratie@voorbeeld.nl'
);

-- Controle: hier hoort nu niets meer tussen te staan
select first_name, last_name, email, created_at
from public.guests
order by created_at desc;


-- -------------------------------------------------------------
--  Alles wissen en opnieuw beginnen? Haal dan de regel hieronder
--  uit het commentaar. Let op: dit gooit ALLE aanmeldingen weg.
-- -------------------------------------------------------------
-- truncate table public.guests;
