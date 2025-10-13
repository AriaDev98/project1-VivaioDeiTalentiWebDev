// === Regole sconto ===
function round2(x){ return Math.round((x + Number.EPSILON) * 100)/100; }
function prezzoScontato(prezzoBase, tessera, coupon){
  if (coupon) return round2(prezzoBase * 0.70); // 30%
  let disc = 0;
  if (tessera && prezzoBase > 50) disc = Math.max(disc, 0.20); // 20%
  if (prezzoBase > 100)           disc = Math.max(disc, 0.10); // 10%
  return round2(prezzoBase * (1 - disc));
}

// === Carico dati dall'API Node ===
fetch('http://localhost:3000/data')
  .then(r => r.json())
  .then(rows => {
    // Converti tipi e calcola importi
    rows.forEach(r => {
      r.Quantita   = Number(r.Quantita);
      r.PrezzoBase = Number(r.PrezzoBase);
      r.Tessera    = Number(r.Tessera) === 1;
      r.Coupon     = Number(r.Coupon) === 1;
      r.PrezzoUnitCalc = prezzoScontato(r.PrezzoBase, r.Tessera, r.Coupon);
      r.TotaleCalc     = round2(r.PrezzoUnitCalc * r.Quantita);
      r.Mese = String(r.Data).slice(0,7); // YYYY-MM (utile dopo)
    });

    // KPI
    const ricavoTot = rows.reduce((s,r)=>s+r.TotaleCalc,0);
    const nCoupon   = rows.filter(r=>r.Coupon).length;
    const nCard     = rows.filter(r=>r.Tessera).length;
    document.getElementById('tot').textContent     = ricavoTot.toFixed(2) + ' €';
    document.getElementById('nCoupon').textContent = nCoupon;
    document.getElementById('nCard').textContent   = nCard;

    // Raggruppo con AlaSQL (array JS come sorgente)
    const byProv = alasql(
      'SELECT Provincia, SUM(TotaleCalc) AS Tot FROM ? GROUP BY Provincia ORDER BY Tot DESC',
      [rows]
    );

    // Grafico a barre per provincia (Chart.js)
    const ctx = document.getElementById('byProv');
    new Chart(ctx, {
      type: 'bar',
      data: {
        labels: byProv.map(r => r.Provincia || 'N/D'),
        datasets: [{ label: 'Ricavo €', data: byProv.map(r => r.Tot) }]
      }
    });

    // (Facoltativo) Mostra 10 righe di controllo se esiste <pre id="sample">
    const sampleEl = document.getElementById('sample');
    if (sampleEl) sampleEl.textContent = JSON.stringify(rows.slice(0,10), null, 2);
  })
  .catch(err => {
    console.error(err);
    alert('Errore caricamento dati da http://localhost:3000/data');
  });
