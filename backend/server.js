//Utilizzo di NodeJS, Express e CORS per implementare un server che configura un'API Express che espone 9 endpoints (ciascuno 
//relativo a una tabella o un grafico)

const express = require('express');
const cors = require('cors');
const sql = require('mssql/msnodesqlv8');

const app = express();
app.use(cors());


//CONFIGURAZIONE CONNESSIONE SERVER-DATABASE
const SERVER_NAME = 'localhost';
const DB_NAME = 'Z_glam';

const config = {
    connectionString:
    `Driver={ODBC Driver 18 for SQL Server};Server=${SERVER_NAME};
    Database=${DB_NAME};
    Trusted_Connection=Yes;
    TrustServerCertificate=Yes;`
};


function explain(err){
    return err?.message || err?.originalError?.message || JSON.stringify(err);
}

//ENDPOINTS PER TABELLE
//ENDPOINT: numero di vendite e quantità degli sconti applicati per categoria merceologica
app.get('/sales/by-categoria-merceologica', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT CategoriaMerceologica, NumeroProdottiVenduti, QuantitaScontiApplicati
            FROM QueryVenditeEScontiPerCategoriaMerceologica
            ORDER BY CategoriaMerceologica;
        `);
        res.json(recordset);
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /sales/by-categoria-merceologica):', err);
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /sales/by-categoria-merceologica)');
    }
});

//ENDPOINT: numero di vendite e quantità degli sconti applicati per prodotto
app.get('/sales/by-prodotto', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT Prodotto, NumeroProdottiVenduti, QuantitaScontiApplicati
            FROM QueryVenditeEScontiPerProdotto
            ORDER BY Prodotto;
        `);
        res.json(recordset);
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /sales/by-prodotto):', explain(err));
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /sales/by-prodotto)');
    }
});

//ENDPOINT: numero di vendite e quantità degli sconti applicati (solo retail!) per regione
app.get('/sales/by-regione-retail', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT Regione, NumeroProdottiVenduti, QuantitaScontiApplicati
            FROM QueryVenditeEScontiRetailPerRegione
            ORDER BY Regione;
        `);
        res.json(recordset);
    } catch (err) {
    console.error('Errore richiesta GET al DB (ENDPOINT: /sales/by-regione-retail):', explain(err));
    res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /sales/by-regione-retail)');
    }
});

//ENDPOINT: numero di vendite e quantità degli sconti applicati (solo retail!) per provincia
app.get('/sales/by-provincia-retail', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT Provincia, Regione, NumeroProdottiVenduti, QuantitaScontiApplicati
            FROM QueryVenditeEScontiRetailPerProvincia
            ORDER BY Regione, Provincia;
        `);
        res.json(recordset);
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /sales/by-provincia-retail):', err);
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /sales/by-provincia-retail)');
    }
});

//ENDPOINT: numero di tessere fedeltà
app.get('/tesserefedelta/numero', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT CAST(NumeroTessere AS INT) AS TotaleTessere
            FROM QueryNumeroTessereFedelta;
        `);
        res.json({ TotaleTessere: recordset[0]?.TotaleTessere ?? 0 });
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /tesserefedelta/numero):', explain(err));
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /tesserefedelta/numero)');
    }
})


//ENDPOINTS PER GRAFICI
//ENDPOINT: prodotti venduti per provincia
app.get('/charts/prodotti-per-provincia', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT Provincia, Regione, NumeroVendite
            FROM QueryProdottiVendutiPerProvincia
            ORDER BY NumeroVendite Desc;
        `);
        res.json(recordset);
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /charts/prodotti-per-provincia):', explain(err));
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /charts/prodotti-per-provincia)');
    }
});

//ENDPOINT: vendite per categoria merceologica
app.get('/charts/vendite-per-categoria', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT
                CategoriaMerceologica AS Categoria,
                NumeroVendite
            FROM QueryNumeroVenditeCategoriaMerceologica
            ORDER BY NumeroVendite DESC;
        `);
        res.json(recordset);
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /charts/vendite-per-categoria):', explain(err));
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /charts/vendite-per-categoria)');
    }
});

//ENDPOINT: fatturato mensile
app.get('/charts/fatturato-mese', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT MeseDel2025, Fatturato
            FROM QueryFatturatoMese
        `);
        res.json(recordset);
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /charts/fatturato-mese):', explain(err));
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /charts/fatturato-mese)');
    }
});

//ENDPOINT: fatturato per punto vendita
app.get('/charts/fatturato-per-puntodivendita', async (req, res) => {
    try {
        const pool = await sql.connect(config);
        const { recordset } = await pool.request().query(`
            SELECT
                IDPuntoVendita,
                Indirizzo,
                Provincia,
                Regione,
                Fatturato
            FROM QueryFatturatoPuntoVendita
            ORDER BY Fatturato DESC;
        `);
        res.json(recordset);
    } catch (err) {
        console.error('Errore richiesta GET al DB (ENDPOINT: /charts/fatturato-per-puntodivendita):', explain(err));
        res.status(500).send('Errore richiesta al DB o errore nella query (ENDPOINT: /charts/fatturato-per-puntodivendita)');
    }
});

app.get('/health', (req, res) => res.json({ ok: true, time: new Date().toISOString() }));


//AVVIO SERVER
app.listen(3000, () => {
    console.log('Server attivo su http://localhost:3000');
    console.log('Vendite e sconti per categoria merceologica: http://localhost:3000/sales/by-categoria-merceologica');
    console.log('Vendite e sconti per prodotto: http://localhost:3000/sales/by-prodotto');
    console.log('Vendite e sconti per regione (retail): http://localhost:3000/sales/by-regione-retail');
    console.log('Vendite e sconti per provincia (retail): http://localhost:3000/sales/by-provincia-retail');
    console.log('Tessere fedeltà: http://localhost:3000/tesserefedelta/numero');
    console.log('Grafico vendite per provincia: http://localhost:3000/charts/prodotti-per-provincia');
    console.log('Vendite per categoria merceologica: http://localhost:3000/charts/vendite-per-categoria');
    console.log('Fatturato per mese: http://localhost:3000/charts/fatturato-mese');
    console.log('Fatturato per punto vendita: http://localhost:3000/charts/fatturato-per-puntodivendita');
});
