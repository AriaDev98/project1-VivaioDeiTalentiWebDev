// server.js — API che collega Node.js a SQL Server
const express = require('express');     //Express crea una piccola API HTTP
const cors = require('cors');           //CORS permette alla pagina (Live Server su 127.0.0.1:5500) di chiamare l’API su 3000
const sql = require('mssql/msnodesqlv8');   // msnodesqlv8 è il connettore Node↔SQL Server che usa i driver ODBC di Windows

const app = express();
app.use(cors());

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
// ' /data ' → è il percorso: quindi l’API risponde su http://localhost:3000/data

app.get('/data', async (req, res) => {            //req = la richiesta del client, res =la risposta che invieremo (in JSON).
  try {
    const pool = await sql.connect(config);
    const { recordset } = await pool.request().query(`
      SELECT
        v.ID AS IdVendita,
        v.TIPO AS Tipo,
        CONVERT(date, v.DATADIVENDITA) AS Data,
        v.QUANTITA AS Quantita,
        v.TESSERAFEDELTA AS Tessera,
        v.CODICESCONTO AS Coupon,
        p.NOME AS Prodotto,
        p.PREZZO AS PrezzoBase,
        COALESCE(pv.NOMEPROVINCIA, cl.NOMEPROVINCIA) AS Provincia
      FROM dbo.VENDITA v
      JOIN dbo.PRODOTTO p ON p.ID = v.IDPRODOTTO
      LEFT JOIN dbo.SCONTRINO s ON s.IDVENDITA = v.ID
      LEFT JOIN dbo.PUNTOVENDITA pv ON pv.ID = s.IDPUNTOVENDITA
      LEFT JOIN dbo.ORDINE o ON o.IDVENDITA = v.ID
      LEFT JOIN dbo.CLIENTE cl ON cl.ID = o.IDCLIENTE
      ORDER BY v.DATADIVENDITA, v.ID;
    `);
    res.json(recordset);
  } catch (err) {
      const full = JSON.stringify(err, Object.getOwnPropertyNames(err));
      console.error('❌ Errore DB:', full);
      res.status(500).send('Errore di connessione o query al database');
  }
});

// ==========================
// AVVIO SERVER
// ==========================

app.listen(3000, () => console.log('✅ Server attivo su http://localhost:3000/data'));
