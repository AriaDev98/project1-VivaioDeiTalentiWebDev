//script frontend per iniettare nella pagina web le tabelle e i grafici (fatti con Chart.js)
//lo script prende i dati per costruire le tabelle e i grafici tramite fetch che chiamano gli endpoints dell'API del server

(async function () {
    const API = 'http://localhost:3000';
    const ENDPOINTS = {//endpoints per le tabelle
        categoria: `${API}/sales/by-categoria-merceologica`,
        prodotto: `${API}/sales/by-prodotto`,
        regione: `${API}/sales/by-regione-retail`,
        provincia: `${API}/sales/by-provincia-retail`,
    };

    //funzione per riempire una tabella
    function riempiTabella(selettoretbody, matrrighe, colonne) {
        const tb = document.querySelector(selettoretbody);
        tb.innerHTML = '';
        if (!matrrighe || matrrighe.length == 0) {
            tb.innerHTML = `<tr> <td colspan="${colonne.length}" class="muted">Nessun dato</td></tr>`;
            return;
        }
        for (var i = 0; i < matrrighe.length; i++) {
            var tr = document.createElement('tr');
            var celle = '';

            for (var j = 0; j < colonne.length; j++) {
                var col = colonne[j];

                var valore = matrrighe[i][col.key];
                if (valore === null || valore === undefined) {
                    valore = '';
                }

                var classe = 'num';
                if (!col.num) {
                    classe = '';
                }

                celle += '<td class="' + classe + '">' + valore + '</td>';
            }

            tr.innerHTML = celle;
            tb.appendChild(tr);
        }
    }

    //fetch + costruzione tabelle
    
    const [rCat, rProd, rReg, rProv] = await Promise.all([ //fetch per tabelle
        fetch(ENDPOINTS.categoria),
        fetch(ENDPOINTS.prodotto),
        fetch(ENDPOINTS.regione),
        fetch(ENDPOINTS.provincia),
    ]);

    const [cat, prod, reg, prov] = await Promise.all([
        rCat.json(), rProd.json(), rReg.json(), rProv.json()
    ]);

    //riempimento delle 4 tabelle
    riempiTabella('#tb-cat', cat, [
        { key: 'CategoriaMerceologica' },
        { key: 'NumeroProdottiVenduti', num: true },
        { key: 'QuantitaScontiApplicati', num: true },
    ]);

    riempiTabella('#tb-prod', prod, [
        { key: 'Prodotto' },
        { key: 'NumeroProdottiVenduti', num: true },
        { key: 'QuantitaScontiApplicati', num: true },
    ]);

    riempiTabella('#tb-reg', reg, [
        { key: 'Regione' },
        { key: 'NumeroProdottiVenduti', num: true },
        { key: 'QuantitaScontiApplicati', num: true },
    ]);

    riempiTabella('#tb-prov', prov, [
        { key: 'Provincia' },
        { key: 'Regione' },
        { key: 'NumeroProdottiVenduti', num: true },
        { key: 'QuantitaScontiApplicati', num: true },
    ]);

    //fetch e costruzione numero tessere
    async function caricaTessere() {
        const el = document.querySelector('#sottobloccoTessere');
        try {
            const r = await fetch(`${API}/tesserefedelta/numero`);
            if (!r.ok) 
                throw new Error('HTTP ' + r.status);
            const { TotaleTessere } = await r.json();
            el.textContent = TotaleTessere;
        } catch (err) {
            console.error('Errore tessere:', err);
        }
    }

    //fetch e costruzione grafico numero vendite per provincia
    async function drawVenditePerProvincia() {
        try {
            const r = await fetch(`${API}/charts/prodotti-per-provincia`);
            if (!r.ok) 
                throw new Error('HTTP ' + r.status);
            const righe = await r.json();

            if (!righe) 
                return;

            var labels = [];
            var data = [];

            for (var i = 0; i < righe.length; i++) {
                labels.push(righe[i].Provincia);
                if (righe[i].NumeroVendite)
                    data.push(righe[i].NumeroVendite)
                else 
                    data.push(0);
            }


            const H_THRESHOLD = 10;
            const horizontal = labels.length > H_THRESHOLD; 

            const base = [
                'rgba(255, 99, 132, 1)','rgba(54, 162, 235, 1)','rgba(255, 205, 86, 1)','rgba(75, 192, 192, 1)','rgba(153, 102, 255, 1)',
                'rgba(255, 159, 64, 1)','rgba(141, 209, 126, 1)','rgba(201, 203, 207, 1)','rgba(246, 112, 112, 1)','rgba(111, 133, 255, 1)'
            ];
            
            var bg = [];
            var border = [];

            for (var i = 0; i < labels.length; i++) {
                var colore = base[i % base.length];
                border[i] = colore;
                bg[i] = colore;
            }

            const context = document.getElementById('chartProvincie').getContext('2d');
            if(window._chartProvincie)
                window._chartProvincie.destroy();

            window._chartProvincie = new Chart(context, {
                type: 'bar',
                data: {
                    labels,
                    datasets: [{
                        label: 'Numero di prodotti venduti',
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
                    layout: {padding: 8},
                    plugins: {
                        legend: {display: false},
                        tooltip: {
                            callbacks: {
                                label: function(item) {
                                    return ' ' + item.dataset.label + ': ' + item.formattedValue;
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            beginAtZero: true,
                            ticks: {precision: 0}
                        },
                        y: {
                            ticks: {
                                autoSkip: false,
                                callback: function(v, i) {
                                    return labels[i];
                                }
                            }
                        }
                    }
                }
            });
        } catch (err) {
            console.error('Grafico province:', err);
        }
    }

    //fetch e costruzione grafico numero vendite per categoria merceologica
    async function drawVenditePerCategoria() {
        try {
            const r = await fetch(`${API}/charts/vendite-per-categoria`);
            if (!r.ok) 
                throw new Error('HTTP ' + r.status);
            const righe = await r.json();

            if (!righe) 
                return;

            var labels = [];
            var data = [];

            for (var i = 0; i < righe.length; i++) {
                labels.push(righe[i].Categoria);
                if (righe[i].NumeroVendite)
                    data.push(righe[i].NumeroVendite)
                else 
                    data.push(0);
            }

            const colors = [
                'rgba(255, 99, 132, 1)','rgba(54, 162, 235, 1)','rgba(255, 205, 86, 1)','rgba(75, 192, 192, 1)','rgba(153, 102, 255, 1)','rgba(255, 159, 64, 1)',
                'rgba(141, 209, 126, 1)','rgba(201, 203, 207, 1)','rgba(246, 112, 112, 1)','rgba(111, 133, 255, 1)','rgba(179, 139, 89, 1)','rgba(231, 136, 188, 1)',
                'rgba(128, 177, 211, 1)','rgba(251, 128, 114, 1)','rgba(253, 180, 98, 1)','rgba(179, 222, 105, 1)','rgba(252, 207, 230, 1)','rgba(188, 128, 189, 1)'
            ];

            const context = document.getElementById('chartCatVendite').getContext('2d');
            if (window._chartCatVendite)
                window._chartCatVendite.destroy();

            window._chartCatVendite = new Chart(context, {
                type: 'doughnut',
                data: {
                    labels,
                    datasets: [{
                        data,
                        backgroundColor: colors,
                        borderColor: 'rgba(255, 255, 255, 1)',
                        borderWidth: 1
                    }]
                },
                options: {
                    cutout: '40%',
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
                                label: function(context) {
                                    var val = context.parsed;
                                    var tot = 0;

                                    for (var i = 0; i < data.length; i++) {
                                        tot += data[i];
                                    }

                                    var perc;
                                    if (tot !== 0) {
                                        perc = (val / tot * 100).toFixed(1);
                                    } else {
                                        perc = 0;
                                    }

                                    return ' ' + context.label + ': ' + val + ' (' + perc + '%)';
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
        name = name.trim().toLowerCase();
        const IT = ['gennaio','febbraio','marzo','aprile','maggio','giugno','luglio','agosto','settembre','ottobre','novembre','dicembre'];
        const EN = ['january','february','march','april','may','june','july','august','september','october','november','december'];

        var i = IT.indexOf(name);
        if (i >= 0) return i;
        i = EN.indexOf(name);
        if (i >= 0) return i;
        return 99;
    }

    function eur(n) {
        if (!n)
            n = 0
        return n.toLocaleString('it-IT', { style: 'currency', currency: 'EUR', maximumFractionDigits: 0 });
    }

    //fetch e costruzione grafico fatturato per mese
    async function drawFatturatoMese() {
        try {
            const r = await fetch(`${API}/charts/fatturato-mese`);
            if (!r.ok) 
                throw new Error('HTTP ' + r.status);
            const righe = await r.json();

            if (!righe) 
                return;

            righe.sort(function(a, b) {
                return monthIndex(a.MeseDel2025.trim()) - monthIndex(b.MeseDel2025.trim());
            });

            var labels = [];
            var data = [];

            for (var i = 0; i < righe.length; i++) {
                labels.push(righe[i].MeseDel2025);
                if (!(righe[i].Fatturato))
                    data.push(0)
                else
                    data.push(righe[i].Fatturato);
            }

            const context = document.getElementById('chartFatturatoMese').getContext('2d');
            if (window._chartFattMese)
                window._chartFattMese.destroy();

            window._chartFattMese = new Chart(context, {
                type: 'line',
                data: {
                    labels,
                    datasets: [{
                        label: 'Fatturato',
                        data,
                        borderColor: 'rgba(255, 107, 136, 1)',
                        backgroundColor: 'rgba(255, 107, 136, 1)',
                        borderWidth: 3,
                        fill: false,
                        tension: 0.30,
                        pointRadius: 4,
                        pointHoverRadius: 5,
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    layout: {padding: 8},
                    plugins: {
                        legend: {display: false},
                        tooltip: {
                            callbacks: {
                                label: function(context) {
                                    return ' ' + context.dataset.label + ': ' + eur(context.parsed.y);
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            ticks: {maxRotation: 45, minRotation: 45}
                        },
                        y: {
                            beginAtZero: true,
                            ticks: { 
                                callback: function(v) {
                                    return eur(v);
                                }
                             }
                        }
                    }
                }
            });
        } catch (err) {
            console.error('Grafico fatturato mese:', err);
        }
    }

    //fetch e costruzione grafico fatturato per provincia
    async function drawFatturatoPerPDV() {
        try {
            const r = await fetch(`${API}/charts/fatturato-per-puntodivendita`);
            if (!r.ok) 
                throw new Error('HTTP ' + r.status);
            const righe = await r.json(); 

            if (!righe) 
                return;

            var labels = [];
            var data = [];

            for (var i = 0; i < righe.length; i++) {
                labels.push(righe[i].Provincia + ' - ' + righe[i].Indirizzo);
                if (righe[i].Fatturato)
                    data.push(righe[i].Fatturato);
                else
                    data.push(0);
            }

            const base = [
                'rgba(255, 99, 132, 1)','rgba(54, 162, 235, 1)','rgba(255, 205, 86, 1)','rgba(75, 192, 192, 1)','rgba(153, 102, 255, 1)',
                'rgba(255, 159, 64, 1)','rgba(141, 209, 126, 1)','rgba(201, 203, 207, 1)','rgba(246, 112, 112, 1)','rgba(111, 133, 255, 1)'
            ];
            var bg = [];
            var border = [];

            for (var i = 0; i < labels.length; i++) {
                var colore = base[i % base.length];
                border[i] = colore;
                bg[i] = colore;
            }

            const context = document.getElementById('chartFatturatoPDV').getContext('2d');
            if (window._chartFattPuntoVendita)
                window._chartFattPuntoVendita.destroy();

            window._chartFattPuntoVendita = new Chart(context, {
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
                    indexAxis: 'y',
                    responsive: true,
                    maintainAspectRatio: false,
                    layout: {padding: 8},
                    plugins: {
                        legend: {display: false},
                        tooltip: {
                            callbacks: {
                                label: function(item) {
                                    return ' ' + item.dataset.label + ': ' + eur(item.parsed.x);
                                }
                            }
                        }
                    },
                    scales: {
                        x: {
                            beginAtZero: true,
                            ticks: {
                                callback: function(v) {
                                    return eur(v);
                                }
                            }
                        },
                        y: {
                            ticks: {
                                autoSkip: false
                            }
                        }
                    }
                }
            });
        } catch (err) {
            console.error('Grafico fatturato per PDV:', err);
        }
    }


    //chiamata a funzioni per costruire numero tessere e grafici
    caricaTessere();
    drawVenditePerProvincia();
    drawVenditePerCategoria();
    drawFatturatoMese(); 
    drawFatturatoPerPDV();
})();