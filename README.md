# Jungle Party — ticketsysteem

Gasten melden zich aan via een link, krijgen direct een persoonlijke QR-code,
en de organisator scant die bij de deur. Een gescande code is daarna ongeldig.

## Hoe het werkt

| Pagina | Voor wie | Wat het doet |
|---|---|---|
| `index.html` | gasten | Aanmeldformulier: voornaam, achternaam, e-mail, telefoon (alles verplicht) |
| `ticket.html` | gasten | Persoonlijk ticket met QR-code en de status (geldig / al gescand) |
| `admin.html` | organisator | Inloggen, QR-codes scannen en de complete gastenlijst bekijken |

De site bestaat uit losse HTML-bestanden zonder buildstap en draait gratis op
GitHub Pages. De aanmeldingen staan in een Supabase-database (ook gratis).

## Beveiliging

- Elk ticket heeft een willekeurig token van 32 hextekens (128 bits). Niet te raden.
- Gasten kunnen de gastenlijst **niet** opvragen. Alle toegang loopt via
  database­functies die precies één ticket teruggeven, en die geven bewust
  geen e-mailadres of telefoonnummer terug.
- Scannen en de gastenlijst lezen kan alleen een ingelogd account waarvan het
  e-mailadres in de tabel `owner_emails` staat. Zelf een account aanmaken geeft
  dus geen toegang.
- De sleutel in `assets/config.js` hoort publiek te zijn. Die geeft op zichzelf
  geen toegang tot gegevens — dat regelen de regels in de database.

## Opnieuw opzetten

1. Maak een Supabase-project aan.
2. Draai `supabase/schema.sql` in de SQL Editor.
3. Zet je eigen e-mailadres in de organisator-lijst:
   ```sql
   insert into public.owner_emails (email) values ('jouw@email.nl');
   ```
4. Maak in **Authentication → Users** een gebruiker aan met datzelfde adres.
5. Vul in `assets/config.js` de project-URL en de publishable key in.
6. Zet de bestanden op GitHub en schakel **Settings → Pages** in.

## Gebruik op de avond zelf

- Open `admin.html` op je telefoon en log in.
- Tab **Scannen** → *Camera starten* → richt op de QR van de gast.
  - Groen = welkom, ticket is nu gebruikt
  - Oranje = deze code is al eerder gescand
  - Rood = staat niet op de gastenlijst
- Werkt de camera niet, plak dan de ticketlink in het handmatige veld eronder.
- Tab **Gastenlijst** toont wie zich aanmeldde en wie binnen is, met zoekveld
  en een CSV-export. Per ongeluk gescand? Klik op *Ongedaan*.

> De camera werkt alleen op een `https`-adres. Op GitHub Pages is dat automatisch
> zo; test je lokaal, gebruik dan het handmatige invoerveld.

## Een gast is zijn ticketlink kwijt

Zoek de gast op in de gastenlijst. Het ticket zit op `ticket.html?t=<token>`;
het token haal je op in de Supabase SQL Editor:

```sql
select first_name, last_name, token from public.guests where email = 'gast@email.nl';
```
