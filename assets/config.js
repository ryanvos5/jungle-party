// ---------------------------------------------------------------
//  Jungle Party - verbinding met de database
//
//  Deze twee waarden horen publiek te zijn: de sleutel hieronder is
//  de "publishable key" (anon public). Die geeft op zichzelf geen
//  toegang tot de gastenlijst - dat regelen de beveiligingsregels
//  in de database.
// ---------------------------------------------------------------
window.JUNGLE_CONFIG = {
  SUPABASE_URL: '__SUPABASE_URL__',
  SUPABASE_KEY: '__SUPABASE_KEY__',

  // Naam van het feest, wordt overal op de site getoond
  PARTY_NAME: 'Jungle Party',
};

(function () {
  'use strict';

  var cfg = window.JUNGLE_CONFIG;

  // Zolang de gegevens hierboven nog niet zijn ingevuld, laten we een
  // duidelijke melding zien in plaats van een lege pagina.
  function showSetupNotice(detail) {
    var render = function () {
      var box = document.createElement('div');
      box.setAttribute('role', 'alert');
      box.style.cssText = [
        'position:fixed', 'inset:0', 'z-index:9999',
        'display:flex', 'align-items:center', 'justify-content:center',
        'padding:24px', 'background:#050f0a',
        'font-family:Inter,-apple-system,Segoe UI,Roboto,sans-serif',
        'color:#e9f6ec'
      ].join(';');

      box.innerHTML =
        '<div style="max-width:440px;text-align:center;background:#0d2117;' +
        'border:1px solid #1f4630;border-radius:18px;padding:32px">' +
          '<div style="font-size:40px;line-height:1">🌴</div>' +
          '<h1 style="font-size:20px;margin:14px 0 8px">Nog even geduld</h1>' +
          '<p style="margin:0;color:#8dab97;font-size:15px;line-height:1.55">' +
            'Dit ticketsysteem is nog niet gekoppeld aan de database. ' +
            'De organisator moet de projectgegevens nog invullen in ' +
            '<code style="color:#b6ff3d">assets/config.js</code>.' +
          '</p>' +
          '<p style="margin:14px 0 0;color:#4d6b58;font-size:12px">' + detail + '</p>' +
        '</div>';

      document.body.appendChild(box);
    };

    if (document.body) render();
    else document.addEventListener('DOMContentLoaded', render);
  }

  var notConfigured =
    !cfg.SUPABASE_URL || cfg.SUPABASE_URL.indexOf('__') === 0 ||
    !cfg.SUPABASE_KEY || cfg.SUPABASE_KEY.indexOf('__') === 0;

  if (notConfigured) {
    window.db = null;
    showSetupNotice('Instellingen ontbreken');
    return;
  }

  if (!window.supabase || !window.supabase.createClient) {
    window.db = null;
    showSetupNotice('De databasebibliotheek kon niet worden geladen');
    return;
  }

  try {
    window.db = window.supabase.createClient(cfg.SUPABASE_URL, cfg.SUPABASE_KEY);
  } catch (error) {
    window.db = null;
    showSetupNotice('De verbinding kon niet worden opgezet');
    console.error(error);
  }
})();

// Bouwt de ticket-URL die in de QR-code komt te staan. Wordt afgeleid
// van de huidige locatie, zodat het zowel lokaal als op GitHub Pages werkt.
window.ticketUrl = function (token) {
  var base = window.location.href.split('?')[0].split('#')[0].replace(/[^/]*$/, '');
  return base + 'ticket.html?t=' + encodeURIComponent(token);
};
