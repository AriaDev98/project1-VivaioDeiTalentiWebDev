// server.js — API che collega Node.js a SQL Server
const express = require('express');     //Express crea una piccola API HTTP
const cors = require('cors');           //CORS permette alla pagina (Live Server su 127.0.0.1:5500) di chiamare l’API su 3000
const sql = require('mssql/msnodesqlv8');   // msnodesqlv8 è il connettore Node↔SQL Server che usa i driver ODBC di Windows

const app = express();
app.use(cors());        //consente richieste da 127.0.0.1:5500 (Live Server) e simili

// ==========================
// CONFIGURAZIONE DATABASE
// ==========================

const SERVER_NAME = 'localhost';      // o 'localhost\\MSSQLSERVER'
const DB_NAME = 'Z_glam';             // cambia se hai un database diverso

/*Specifica quale driver ODBC usare per connettersi a SQL Server.
In questo caso ho installato il driver Microsoft più recente (ODBC 18).
Serve a dire a Windows: “usa questo connettore ufficiale per parlare col database”.*/
const config = {
  connectionString:
    `Driver={ODBC Driver 18 for SQL Server};Server=${SERVER_NAME};Database=${DB_NAME};Trusted_Connection=Yes;TrustServerCertificate=Yes;`
};

function explain(err){
  return err?.message || err?.originalError?.message || JSON.stringify(err);
}

//========== API ==============
// Endpoint che legge i dati dal DB e li manda al browser in JSON.
/*
crea un endpoint API che:
1) si collega al DB SQL Server,
2) esegue una query SQL complessa con più JOIN,
3) e restituisce i risultati in formato JSON al browser.
*/ 
//app.get → indica che questo endpoint risponde a richieste HTTP di tipo GET (cioè lettura)




// ==========================
// ENDPOINT /data
// ==========================
// Ritorna righe di vendita con campi coerenti per la dashboard (Chart.js)

// ==================== ENDPOINT: CATEGORIA ====================
// View: QueryVenditeEScontiPerCategoriaMerceologica
// Ritorna: CategoriaMerceologica, NumeroProdottiVenduti, QuantitaScontiApplicati
// ▶︎ somma totale dei prodotti venduti e quantità degli sconti applicati per articolo
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
        console.error('Errore DB (/sales/by-categoria-merceologica):', err);
        res.status(500).send('Errore nella query SQL');
      }
    });

// ==================== ENDPOINT: PRODOTTO ====================
// View: QueryVenditeEScontiPerProdotto
// Ritorna: Prodotto, NumeroProdottiVenduti, QuantitaScontiApplicati
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
    console.error('❌ Errore /sales/by-prodotto:', explain(err));
    res.status(500).send('Errore nella query SQL (prodotto)');
  }
});



// ==================== ENDPOINT: RETAIL PER REGIONE ====================
// View: QueryVenditeEScontiRetailPerRegione
// Ritorna: Regione, NumeroProdottiVenduti, QuantitaScontiApplicati
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
    console.error('❌ Errore /sales/by-regione-retail:', explain(err));
    res.status(500).send('Errore nella query SQL (regione retail)');
  }
});

  // ==================== ENDPOINT: PROVINCIA (SOLO RETAIL) ====================
// View: QueryVenditeEScontiRetailPerProvincia
// Campi: Provincia, Regione, NumeroProdottiVenduti, QuantitaScontiApplicati
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
    console.error('❌ Errore /sales/by-provincia-retail:', err);
    res.status(500).send('Errore nella query SQL (provincia retail)');
  }
});

// ==================== ENDPOINT: TESSERE FEDELTÀ ====================
// View: QueryNumeroTessereFedelta
// Ritorna: NumeroTessere (somma di 0/1 su ClienteRegistrato.TesseraFedelta)
app.get('/loyalty/count', async (req, res) => {
  try {
    const pool = await sql.connect(config);
    const { recordset } = await pool.request().query(`
      SELECT CAST(NumeroTessere AS INT) AS TotaleTessere
      FROM QueryNumeroTessereFedelta;
    `);
    res.json({ TotaleTessere: recordset[0]?.TotaleTessere ?? 0 });
  } catch (err) {
    console.error('❌ Errore /loyalty/count:', explain(err));
    res.status(500).send('Errore nella query SQL (tessere fedeltà)');
  }
})

// ====================VISUALIZZAZIOMI GRAFICHE=======================================================
// ==================== ENDPOINT: ENDPOINT: VENDITE PER PROVINCIA (RETAIL+ONLINE) ====================
// View: QueryProdottiVendutiPerProvincia
// Campi: Provincia, Regione, NumeroVendite
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
    console.error('❌ Errore /charts/prodotti-per-provincia:', explain(err));
    res.status(500).send('Errore nella query SQL (prodotti per provincia)');
  }
});

// ============ ENDPOINT: VENDITE PER CATEGORIA (Diagramma a torta) ============
// View: QueryNumeroVenditeCategoriaMerceologica
// Campi: CategoriaMerceologica, NumeroVendite


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
    console.error('❌ Errore /charts/vendite-per-categoria:', explain(err));
    res.status(500).send('Errore nella query SQL (vendite per categoria)');
  }
});

// ============ ENDPOINT: FATTURATO PER MESE (LINE) ============
app.get('/charts/fatturato-mese', async (req, res) => {
  try {
    const pool = await sql.connect(config);
    const { recordset } = await pool.request().query(`
      SELECT MeseDel2025, Fatturato
      FROM QueryFatturatoMese
      Order by MeseDel2025 desc;
    `);
    res.json(recordset);
  } catch (err) {
    console.error('❌ Errore /charts/fatturato-mese:', explain(err));
    res.status(500).send('Errore nella query SQL (fatturato per mese)');
  }
});

// ============ ENDPOINT: FATTURATO PER PUNTO VENDITA (RETAIL) ============
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
    console.error('❌ Errore /charts/fatturato-per-pdv:', explain(err));
    res.status(500).send('Errore nella query SQL (fatturato per punto vendita)');
  }
});

// Aggiungi in server.js
app.get('/health', (req, res) => res.json({ ok: true, time: new Date().toISOString() }));


// ==========================
// AVVIO SERVER
// ==========================

app.listen(3000, () => {
  console.log('✅ Server attivo su http://localhost:3000');
  console.log('   • Categorie view:  http://localhost:3000/sales/by-categoria-merceologica');
  console.log('   • Prodotti view:   http://localhost:3000/sales/by-prodotto');
  console.log('   • RETAIL PER REGIONE view:   http://localhost:3000/sales/by-regione-retail');
  console.log('   • RETAIL PER PROVINCIA view:   http://localhost:3000/sales/by-provincia-retail');
  console.log('   • Tessere fedeltà: http://localhost:3000/loyalty/count');
  console.log('   • Grafico vendite per provincia: http://localhost:3000/charts/prodotti-per-provincia');
  console.log('   • Vendite per categoria: http://localhost:3000/charts/vendite-per-categoria');
  console.log('   • Vendite per categoria: http://localhost:3000/charts/fatturato-mese');
  console.log('   • Vendite per categoria: http://localhost:3000/charts/fatturato-per-puntodivendita');




});
