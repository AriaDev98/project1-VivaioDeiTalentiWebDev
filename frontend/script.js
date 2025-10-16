(async function () {
  const API = 'http://localhost:3000';
  const ENDPOINTS = {
    categoria: `${API}/sales/by-categoria-merceologica`,
    prodotto : `${API}/sales/by-prodotto`,
    regione  : `${API}/sales/by-regione-retail`,
    provincia: `${API}/sales/by-provincia-retail`,
  };


  // ========Funzioni Utili==========
  const $ = sel => document.querySelector(sel);
  const num = v => Number(v ?? 0).toLocaleString('it-IT');
  const setStatus = msg => { const el = $('#status'); if (el) el.textContent = msg; };

  
//===Funzione principale ===
function fillTable(tbodySelector, rows, columns) {
    const tb = $(tbodySelector);
    tb.innerHTML = '';
    if (!rows || !rows.length) {
      tb.innerHTML = `<tr><td colspan="${columns.length}" class="muted">Nessun dato</td></tr>`;
      return;
    }
    for (const r of rows) {
      const tr = document.createElement('tr');
      tr.innerHTML = columns.map(c => {
        const value = r[c.key];
        const content = c.num ? num(value) : (value ?? '');
        return `<td class="${c.num ? 'num' : ''}">${content}</td>`;
      }).join('');
      tb.appendChild(tr);
    }
  }

  try {
    $('#status').textContent = 'Caricamento…';

    // prendo i 4 dataset in parallelo
    const [rCat, rProd, rReg, rProv] = await Promise.all([
      fetch(ENDPOINTS.categoria),
      fetch(ENDPOINTS.prodotto),
      fetch(ENDPOINTS.regione),
      fetch(ENDPOINTS.provincia),
    ]);
    if (![rCat, rProd, rReg, rProv].every(r => r.ok)) {
      throw new Error('Uno o più endpoint hanno risposto con errore.');
    }

    const [cat, prod, reg, prov] = await Promise.all([
      rCat.json(), rProd.json(), rReg.json(), rProv.json()
    ]);

    // 1) tabella categoria 
    fillTable('#tb-cat', cat, [
      { key: 'CategoriaMerceologica' },
      { key: 'NumeroProdottiVenduti', num: true },
      { key: 'QuantitaScontiApplicati', num: true },
    ]);

    // 2) tabella prodotto
    fillTable('#tb-prod', prod, [
      { key: 'Prodotto' },
      { key: 'NumeroProdottiVenduti', num: true },
      { key: 'QuantitaScontiApplicati', num: true },
    ]);

    // 3) tabella regione (retail)
    fillTable('#tb-reg', reg, [
      { key: 'Regione' },
      { key: 'NumeroProdottiVenduti', num: true },
      { key: 'QuantitaScontiApplicati', num: true },
    ]);

    // 4) tabella provincia (retail)
    fillTable('#tb-prov', prov, [
      { key: 'Provincia' },
      { key: 'Regione' },
      { key: 'NumeroProdottiVenduti', num: true },
      { key: 'QuantitaScontiApplicati', num: true },
    ]);

    $('#status').textContent = 'OK';
  } catch (err) {
    console.error(err);
    $('#status').textContent = 'Errore: ' + (err.message || err);
  }
  //t
  async function caricaTessere() {
  const el = document.querySelector('#kpiTessere');
  try {
    const r = await fetch(`${API}/loyalty/count`);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const { TotaleTessere } = await r.json();
    el.textContent = Number(TotaleTessere || 0).toLocaleString('it-IT');
  } catch (err) {
    console.error('Errore tessere:', err);
    if (el) el.textContent = '—';
  }
}


async function drawVenditePerProvincia() {
  try {
    const r = await fetch(`${API}/charts/prodotti-per-provincia`);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const rows = await r.json(); // [{Provincia,Regione,NumeroVendite}, ...]

    if (!rows.length) return;

    // Ordina per # vendite desc
    rows.sort((a, b) => (b.NumeroVendite || 0) - (a.NumeroVendite || 0));

    const labels = rows.map(x => x.Provincia);
    const data   = rows.map(x => Number(x.NumeroVendite || 0));

    // Se le province sono tante => barre orizzontali
    const H_THRESHOLD = 10;                          // soglia
    const horizontal  = labels.length > H_THRESHOLD; // true = indexAxis:'y'

    // Tavolozza
    const base = [
      '#ff6384','#36a2eb','#ffcd56','#4bc0c0','#9966ff',
      '#ff9f40','#8dd17e','#c9cbcf','#f67070','#6f85ff'
    ];
    const bg     = labels.map((_, i) => base[i % base.length] + '99');
    const border = labels.map((_, i) => base[i % base.length]);

    const ctx = document.getElementById('chartProvincie').getContext('2d');
    window._chartProvincie?.destroy();

    window._chartProvincie = new Chart(ctx, {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          label: '# prodotti',
          data,
          backgroundColor: bg,
          borderColor: border,
          borderWidth: 1
        }]
      },
      options: {
        indexAxis: horizontal ? 'y' : 'x', 
        responsive: true,
        maintainAspectRatio: false,
        layout: { padding: 8 },
        plugins: {
          legend: { display: true, position: 'top' },
          tooltip: {
            callbacks: { label: (item) => ` ${item.dataset.label}: ${item.formattedValue}` }
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: { precision: 0 }
          },
          y: {
            ticks: {
              autoSkip: false,         // mostra tutte le province
              callback: (v, i) => labels[i] // etichetta completa
            }
          }
        }
      }
    });
  } catch (err) {
    console.error('Grafico province:', err);
  }
}

async function drawVenditePerCategoria() {
  try {
    const r = await fetch(`${API}/charts/vendite-per-categoria`);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const rows = await r.json(); // [{Categoria, NumeroVendite}, ...]

    if (!rows.length) return;

    // Ordina per valore desc (opzionale, ma rende la leggibilità migliore)
    rows.sort((a, b) => (b.NumeroVendite || 0) - (a.NumeroVendite || 0));

    const labels = rows.map(x => x.Categoria ?? x.CategoriaMerceologica);
    const data   = rows.map(x => Number(x.NumeroVendite || 0));

    // Tavolozza ampia (cicla se le categorie > colori)
    const palette = [
      '#ff6384','#36a2eb','#ffcd56','#4bc0c0','#9966ff','#ff9f40',
      '#8dd17e','#c9cbcf','#f67070','#6f85ff','#b38b59','#e889bd',
      '#80b1d3','#fb8072','#fdb462','#b3de69','#fccde5','#bc80bd'
    ];
    const colors = labels.map((_, i) => palette[i % palette.length]);

    const ctx = document.getElementById('chartCatVendite').getContext('2d');
    // distruggi precedente se esiste (utile in dev)
    window._chartCatVendite?.destroy();

    window._chartCatVendite = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels,
        datasets: [{
          data,
          backgroundColor: colors,
          borderColor: '#ffffff',
          borderWidth: 1
        }]
      },
      options: {
        cutout: '65%',              // “foro” centrale
        responsive: true,
        maintainAspectRatio: false,
        plugins: {
          legend: {
            position: 'top',
            align: 'center',
            labels: { boxWidth: 12, usePointStyle: true }
          },
          tooltip: {
            callbacks: {
              label: (ctx) => {
                const val = ctx.parsed;
                const tot = data.reduce((s, n) => s + n, 0);
                const perc = tot ? ((val / tot) * 100).toFixed(1) : 0;
                return ` ${ctx.label}: ${val} (${perc}%)`;
              }
            }
          }
        }
      }
    });
  } catch (err) {
    console.error('Grafico categorie (doughnut):', err);
  }
}

function monthIndex(name) {
  const IT = ['Gennaio','Febbraio','Marzo','Aprile','Maggio','Giugno','Luglio','Agosto','Settembre','Ottobre','Novembre','Dicembre'];
  const EN = ['January','February','March','April','May','June','July','August','September','October','November','December'];
  let i = IT.indexOf(name);
  if (i >= 0) return i;
  i = EN.indexOf(name);
  if (i >= 0) return i;
  return 99; // in coda se non riconosciuto
}
function eur(n) {
  return new Intl.NumberFormat('it-IT', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 }).format(n || 0);
}

async function drawFatturatoMese() {
  try {
    const r = await fetch(`${API}/charts/fatturato-mese`);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const rows = await r.json(); // [{MeseDel2025, Fatturato}, ...]

    if (!rows.length) return;

    // Ordina Jan→Dec (Italiano/English)
    rows.sort((a, b) => monthIndex(a.MeseDel2025) - monthIndex(b.MeseDel2025));

    const labels = rows.map(x => x.MeseDel2025);
    const data   = rows.map(x => Number(x.Fatturato || 0));

    const ctx = document.getElementById('chartFatturatoMese').getContext('2d');
    window._chartFattMese?.destroy();

    window._chartFattMese = new Chart(ctx, {
      type: 'line',
      data: {
        labels,
        datasets: [{
          label: 'Fatturato',
          data,
          borderColor: '#ff6b88',
          backgroundColor: '#ff6b88',
          borderWidth: 3,
          fill: false,
          tension: 0.30,              // curva morbida
          pointRadius: 4,
          pointHoverRadius: 5,
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        layout: { padding: 8 },
        plugins: {
          legend: { display: true, position: 'top' },
          tooltip: {
            callbacks: {
              label: (ctx) => ` ${ctx.dataset.label}: ${eur(ctx.parsed.y)}`
            }
          }
        },
        scales: {
          x: {
            ticks: { maxRotation: 45, minRotation: 45 }
          },
          y: {
            beginAtZero: true,
            ticks: { callback: (v) => eur(v) }
          }
        }
      }
    });
  } catch (err) {
    console.error('Grafico fatturato mese:', err);
  }
}

async function drawFatturatoPerPDV() {
  try {
    const r = await fetch(`${API}/charts/fatturato-per-puntodivendita`);
    if (!r.ok) throw new Error('HTTP ' + r.status);
    const rows = await r.json(); // [{IDPuntoVendita, Indirizzo, Provincia, Regione, Fatturato}, ...]

    if (!rows.length) return;

    // Etichetta leggibile: "Provincia — Indirizzo" (puoi cambiare come preferisci)
    const labels = rows.map(x => `${x.Provincia} — ${x.Indirizzo}`);
    const data   = rows.map(x => Number(x.Fatturato || 0));

    const base = [
      '#ff6384','#36a2eb','#ffcd56','#4bc0c0','#9966ff',
      '#ff9f40','#8dd17e','#c9cbcf','#f67070','#6f85ff'
    ];
    const bg     = labels.map((_, i) => base[i % base.length] + '99');
    const border = labels.map((_, i) => base[i % base.length]);

    const ctx = document.getElementById('chartFatturatoPDV').getContext('2d');
    window._chartFattPDV?.destroy();

    window._chartFattPDV = new Chart(ctx, {
      type: 'bar',
      data: {
        labels,
        datasets: [{
          label: 'Fatturato',
          data,
          backgroundColor: bg,
          borderColor: border,
          borderWidth: 1,
        }]
      },
      options: {
        // come il grafico province: barre orizzontali
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        layout: { padding: 8 },
        plugins: {
          legend: { display: true, position: 'top' },
          tooltip: {
            callbacks: {
              label: (item) => ` ${item.dataset.label}: ${eur(item.parsed.x)}`
            }
          }
        },
        scales: {
          x: {
            beginAtZero: true,
            ticks: {
              callback: (v) => eur(v)
            }
          },
          y: {
            ticks: {
              autoSkip: false   // mostra tutti i punti vendita
            }
          }
        }
      }
    });
  } catch (err) {
    console.error('Grafico fatturato per PDV:', err);
  }
}



//AVVIO
caricaTessere();
drawVenditePerProvincia();
drawVenditePerCategoria();
drawFatturatoMese(); 
drawFatturatoPerPDV();
})();
   

