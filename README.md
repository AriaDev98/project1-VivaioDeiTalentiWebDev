# progetto 1 - Vivaio dei Talenti Web Developer

--------------------Guida rapida (Windows) – Avvio progetto Z-Glam Dashboard-----------------------------
Questa guida spiega come avviare backend (API Node/SQL Server) e frontend (dashboard) sul PC del cliente.
0) Requisiti:
	- Windows 10/11 (64-bit)
	- SQL Server in esecuzione sull’istanza locale
	- ODBC Driver 18 for SQL Server (Microsoft) – necessario per il connettore Node.js LTS (>= 18) . installarlo dal sito Microsoft
	- Node.js LTS: installare da https://nodejs.org (dopo l’installazione, chiudere e riaprire il terminale)

1) Preparazione database:
	- Aprire SSMS e connettersi a localhost.
	- Eseguire lo script Database/db.sql presente nel progetto (crea databse, tabelle, viste e dati)
	
     IMPORTANTE: Se il DB non è localhost o il nome non è Z_glam, modificare in seguito il file backend/server.js (variabili SERVER_NAME e DB_NAME).

2) Avvio backend (API):
	- Aprire terminale nella cartella del progetto → backend/
	- Installare le dipendenze (usa il package-lock.json incluso):   npm install  
	- Avviare il server:  node server.js
	- Controllare nel log che sia in ascolto su http://localhost:3000 e che compaiano gli endpoint.

3) Avvio frontend (dashboard):
	 VS Code Live Server -->
				- Aprire la cartella frontend/ in VS Code
				- Click destro su index.html → Open with Live Server. (Abilitare extention Live Server su VScode)
	
	N.B) backend su http://localhost:3000, frontend su http://127.0.0.1:5500/ (Live Server) — le chiamate API sono già CORS-abilitate.

-------------------------- Problemi comuni & soluzioni ---------------------------------------------------------------------

1) “node non è riconosciuto…” --> Node.js non è installato o la shell va riaperta. Installa Node LTS e riapri PowerShell. node -v deve funzionare.
2) “Cannot GET /frontend/index.html” (schermata bianca con testo nero) --> Stai aprendo Live Server con root già puntato a /frontend. Apri http://127.0.0.1:5500/ (senza /frontend/index.html)
3) Grafici vuoti / errori 500 --> Il DB non è popolato o il nome/istanza non coincidono. Verifica SERVER_NAME/DB_NAME in server.js e riesegui Database/db.sql.

---------------------------Cheklist rapido----------------------------------------------------------------------------------

1) Node LTS e ODBC 18 installati.
2) sul terminale : cd backend && npm ci && node server.js.
3) apri frontend/index.html con Live Server e visita http://127.0.0.1:5500/frontend/index.html.
