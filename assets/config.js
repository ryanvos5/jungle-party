// ---------------------------------------------------------------
//  Jungle Party - verbinding met de database
//
//  Deze twee waarden horen publiek te zijn: de sleutel hieronder is
//  de "publishable key". Die geeft op zichzelf geen toegang tot de
//  gastenlijst - dat regelen de beveiligingsregels in de database.
// ---------------------------------------------------------------
window.JUNGLE_CONFIG = {
  SUPABASE_URL: '__SUPABASE_URL__',
  SUPABASE_KEY: '__SUPABASE_KEY__',

  // Naam van het feest, wordt overal op de site getoond
  PARTY_NAME: 'Jungle Party',
};

// Eén gedeelde client voor alle pagina's
window.db = window.supabase.createClient(
  window.JUNGLE_CONFIG.SUPABASE_URL,
  window.JUNGLE_CONFIG.SUPABASE_KEY
);

// Bouwt de ticket-URL die in de QR-code komt te staan. Wordt afgeleid
// van de huidige locatie, zodat het zowel lokaal als op GitHub Pages werkt.
window.ticketUrl = function (token) {
  const base = window.location.href.replace(/[^/]*$/, '');
  return base + 'ticket.html?t=' + encodeURIComponent(token);
};
