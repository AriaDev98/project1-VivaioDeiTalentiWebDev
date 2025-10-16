DROP TABLE IF EXISTS VenditaProdottoRetail;
DROP TABLE IF EXISTS VenditaProdottoOnline;
DROP TABLE IF EXISTS Ordine;
DROP TABLE IF EXISTS Scontrino;
DROP TABLE IF EXISTS ClienteRegistrato;
DROP TABLE IF EXISTS PuntoVendita;
DROP TABLE IF EXISTS Prodotto;
DROP TABLE IF EXISTS Categoria;
DROP TABLE IF EXISTS Provincia;

USE Z_GLAM;

--TABELLE:
CREATE TABLE Provincia ( 
    IDProvincia INT IDENTITY(1,1) PRIMARY KEY, 

    NomeProvincia VARCHAR(50) NOT NULL,

    Regione VARCHAR(50) NOT NULL
);

CREATE TABLE Categoria ( 
    IDCategoria INT IDENTITY(1001,1) PRIMARY KEY, 

    NomeCategoria VARCHAR(50) NOT NULL,

    Sesso VARCHAR(6) NOT NULL,
        CHECK (Sesso IN ('uomo', 'donna', 'unisex')),

    CategoriaMerceologica VARCHAR(50) NOT NULL
);

CREATE TABLE Prodotto (
    IDProdotto INT IDENTITY(2001,1) PRIMARY KEY, 

    NomeProdotto VARCHAR(100) NOT NULL,
    
    Marchio VARCHAR(50) NOT NULL,

    PrezzoBase DECIMAL(10,2) NOT NULL,
        CHECK (PrezzoBase > 0),

    IDCategoria INT NOT NULL, 

    FOREIGN KEY (IDCategoria) REFERENCES Categoria(IDCategoria)
);

CREATE TABLE PuntoVendita (
    IDPuntoVendita INT IDENTITY(3001,1) PRIMARY KEY, 

    IDProvincia INT NOT NULL, 

    Indirizzo VARCHAR(100) NOT NULL, 

    FOREIGN KEY (IDProvincia) REFERENCES Provincia(IDProvincia)
);

CREATE TABLE ClienteRegistrato (
   
    --esclusi dai clienti registrati tutti i clienti tranne quelli che hanno fatto solo acquisti in retail senza mai presentare la tessera 

    --i clienti registrati possono non aver mai fatto acquisti! (caso cliente registrato online che non ha fatto acquisti)
    
    IDClienteRegistrato INT IDENTITY(4001,1) PRIMARY KEY, 

    Nome VARCHAR(100) NOT NULL,

    Cognome VARCHAR(100) NOT NULL,

    Mail VARCHAR(50) NOT NULL,

    NumeroDiTelefono VARCHAR(30) NOT NULL,

    TesseraFedelta BIT NOT NULL, 
    --se è 0 allora il cliente registrato in questione ha fatto solo (0 o più) ordini online, non può aver fatto acquisti in retail
    --se è 1 allora il cliente registrato in questione ha fatto (0 o più) ordini online e/o (0 o più) acquisti in retail
    
    IDProvincia INT NOT NULL,

    FOREIGN KEY (IDProvincia) REFERENCES Provincia(IDProvincia)
);

CREATE TABLE Scontrino ( 
    IDScontrino INT IDENTITY(5001,1) PRIMARY KEY,

    DataDiVendita DATE NOT NULL,
        CHECK (DataDiVendita BETWEEN '20250101' AND '20250930'), 

    CodiceSconto BIT NOT NULL,

    IDClienteRegistrato INT,
    --IDClienteRegistrato IS NULL => all'acquisto il cliente non ha presentato TesseraFedeltà (perchè non la ha o perchè l'ha dimenticata a casa) 
        --(se ce l'ha ma l'ha dimenticata a casa non è possibile in alcun modo utilizzarla per politiche aziendali (facendo così l'azienda guadagna di più))
        --(se il cliente perde la tessera o gli viene rubata è fregato? deve rifarla? DIREI DI SI (motivo politiche aziendali...)! fare la tessera costa? e se si quanto? direi 25 euro)
    --IDClienteRegistrato NOT NULL => all'acquisto ha presentato la TesseraFedelta (verificato dall'ultimo trigger)
    
    IDPuntoVendita INT NOT NULL,

    FOREIGN KEY (IDClienteRegistrato) REFERENCES ClienteRegistrato(IDClienteRegistrato),
    FOREIGN KEY (IDPuntoVendita) REFERENCES PuntoVendita(IDPuntoVendita)
);

CREATE TABLE Ordine ( 
    IDOrdine INT IDENTITY(6001,1) PRIMARY KEY,

    DataDiVendita DATE NOT NULL,
        CHECK (DataDiVendita BETWEEN '20250101' AND '20250930'),

    CodiceSconto BIT NOT NULL,

    IDClienteRegistrato INT NOT NULL,
    
    FOREIGN KEY (IDClienteRegistrato) REFERENCES ClienteRegistrato(IDClienteRegistrato)
);

CREATE TABLE VenditaProdottoRetail (
    IDScontrino INT NOT NULL,
  
    IDProdotto INT NOT NULL,

    CONSTRAINT PK_VenditaProdottoRetail PRIMARY KEY (IDScontrino, IDProdotto),

    Quantita INT NOT NULL,
        CHECK (Quantita > 0),
   
    PrezzoUnitarioScontato DECIMAL(10,2),
    
    Sconto INT,

    FOREIGN KEY (IDScontrino) REFERENCES Scontrino(IDScontrino),
    FOREIGN KEY (IDProdotto) REFERENCES Prodotto(IDProdotto)
);

CREATE TABLE VenditaProdottoOnline (
    IDOrdine INT NOT NULL,
  
    IDProdotto INT NOT NULL,

    CONSTRAINT PK_VenditaProdottoOnline PRIMARY KEY (IDOrdine, IDProdotto),

    Quantita INT NOT NULL,
        CHECK (Quantita > 0),
   
    PrezzoUnitarioScontato DECIMAL(10,2),
    
    Sconto INT, 

    FOREIGN KEY (IDOrdine) REFERENCES Ordine(IDOrdine),
    FOREIGN KEY (IDProdotto) REFERENCES Prodotto(IDProdotto)
);




--TRIGGERS:
GO

CREATE OR ALTER TRIGGER trg_CalcolaScontoEPrezzo_VenditaProdottoRetail
ON VenditaProdottoRetail
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vpr
    SET vpr.Sconto =
        CASE
            WHEN s.CodiceSconto = 1 THEN 30
            WHEN s.CodiceSconto = 0
                 AND (s.IDClienteRegistrato IS NULL
                      OR (s.IDClienteRegistrato IS NOT NULL AND p.PrezzoBase < 50))
                 THEN NULL
            WHEN s.CodiceSconto = 0
                 AND s.IDClienteRegistrato IS NOT NULL
                 AND p.PrezzoBase >= 50
                 AND p.PrezzoBase < 100
                 THEN 20
            WHEN s.CodiceSconto = 0
                 AND s.IDClienteRegistrato IS NOT NULL
                 AND p.PrezzoBase >= 100
                 THEN 10
        END
    FROM VenditaProdottoRetail vpr
        INNER JOIN inserted i 
            ON vpr.IDScontrino = i.IDScontrino AND vpr.IDProdotto = i.IDProdotto
        INNER JOIN Scontrino s
            ON i.IDScontrino = s.IDScontrino
        INNER JOIN Prodotto p
            ON i.IDProdotto = p.IDProdotto;

    UPDATE vpr
    SET vpr.PrezzoUnitarioScontato = 
        ROUND(p.PrezzoBase - ((p.PrezzoBase * ISNULL(vpr.Sconto, 0)) / 100.0), 2)
    FROM VenditaProdottoRetail vpr
        INNER JOIN inserted i 
            ON vpr.IDScontrino = i.IDScontrino AND vpr.IDProdotto = i.IDProdotto
        INNER JOIN Prodotto p
            ON vpr.IDProdotto = p.IDProdotto;
END;

GO

CREATE OR ALTER TRIGGER trg_CalcolaScontoEPrezzo_VenditaProdottoOnline
ON VenditaProdottoOnline
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vpo
    SET vpo.Sconto =
        CASE 
            WHEN o.CodiceSconto = 1 THEN 30
            WHEN o.CodiceSconto = 0 
                 AND c.TesseraFedelta = 1
                 AND p.PrezzoBase >= 50 
                 AND p.PrezzoBase < 100 THEN 20
            WHEN o.CodiceSconto = 0 
                 AND c.TesseraFedelta = 1
                 AND p.PrezzoBase >= 100 THEN 10
            WHEN o.CodiceSconto = 0 
                 AND (c.TesseraFedelta = 0 OR p.PrezzoBase < 50) THEN NULL
        END
    FROM VenditaProdottoOnline vpo
    INNER JOIN inserted i 
        ON vpo.IDOrdine = i.IDOrdine AND vpo.IDProdotto = i.IDProdotto
    INNER JOIN Ordine o 
        ON i.IDOrdine = o.IDOrdine
    INNER JOIN ClienteRegistrato c 
        ON o.IDClienteRegistrato = c.IDClienteRegistrato
    INNER JOIN Prodotto p 
        ON i.IDProdotto = p.IDProdotto;

    UPDATE vpo
    SET vpo.PrezzoUnitarioScontato = 
        ROUND(p.PrezzoBase - ((p.PrezzoBase * ISNULL(vpo.Sconto, 0)) / 100.0), 2)
    FROM VenditaProdottoOnline vpo
    INNER JOIN inserted i 
        ON vpo.IDOrdine = i.IDOrdine AND vpo.IDProdotto = i.IDProdotto
    INNER JOIN Prodotto p 
        ON vpo.IDProdotto = p.IDProdotto;
END;

GO



--INSERTS:

INSERT INTO Provincia (NomeProvincia, Regione) VALUES --110 tuple
    ('Agrigento', 'Sicilia'),
    ('Alessandria', 'Piemonte'),
    ('Ancona', 'Marche'),
    ('Aosta', 'Valle d''Aosta'),
    ('Arezzo', 'Toscana'),
    ('Ascoli Piceno', 'Marche'),
    ('Asti', 'Piemonte'),
    ('Avellino', 'Campania'),
    ('Bari', 'Puglia'),
    ('Barletta-Andria-Trani', 'Puglia'),
    ('Belluno', 'Veneto'),
    ('Benevento', 'Campania'),
    ('Bergamo', 'Lombardia'),
    ('Biella', 'Piemonte'),
    ('Bologna', 'Emilia-Romagna'),
    ('Bolzano', 'Trentino-Alto Adige'),
    ('Brescia', 'Lombardia'),
    ('Brindisi', 'Puglia'),
    ('Cagliari', 'Sardegna'),
    ('Caltanissetta', 'Sicilia'),
    ('Campobasso', 'Molise'),
    ('Caserta', 'Campania'),
    ('Catania', 'Sicilia'),
    ('Catanzaro', 'Calabria'),
    ('Chieti', 'Abruzzo'),
    ('Como', 'Lombardia'),
    ('Cosenza', 'Calabria'),
    ('Cremona', 'Lombardia'),
    ('Crotone', 'Calabria'),
    ('Cuneo', 'Piemonte'),
    ('Enna', 'Sicilia'),
    ('Fermo', 'Marche'),
    ('Ferrara', 'Emilia-Romagna'),
    ('Firenze', 'Toscana'),
    ('Foggia', 'Puglia'),
    ('Forlì-Cesena', 'Emilia-Romagna'),
    ('Frosinone', 'Lazio'),
    ('Gallura Nord-Est Sardegna', 'Sardegna'),
    ('Genova', 'Liguria'),
    ('Gorizia', 'Friuli-Venezia Giulia'),
    ('Grosseto', 'Toscana'),
    ('Imperia', 'Liguria'),
    ('Isernia', 'Molise'),
    ('L''Aquila', 'Abruzzo'),
    ('La Spezia', 'Liguria'),
    ('Latina', 'Lazio'),
    ('Lecce', 'Puglia'),
    ('Lecco', 'Lombardia'),
    ('Livorno', 'Toscana'),
    ('Lodi', 'Lombardia'),
    ('Lucca', 'Toscana'),
    ('Macerata', 'Marche'),
    ('Mantova', 'Lombardia'),
    ('Massa-Carrara', 'Toscana'),
    ('Matera', 'Basilicata'),
    ('Medio Campidano', 'Sardegna'),
    ('Messina', 'Sicilia'),
    ('Milano', 'Lombardia'),
    ('Modena', 'Emilia-Romagna'),
    ('Monza e Brianza', 'Lombardia'),
    ('Napoli', 'Campania'),
    ('Novara', 'Piemonte'),
    ('Nuoro', 'Sardegna'),
    ('Ogliastra', 'Sardegna'),
    ('Oristano', 'Sardegna'),
    ('Padova', 'Veneto'),
    ('Palermo', 'Sicilia'),
    ('Parma', 'Emilia-Romagna'),
    ('Pavia', 'Lombardia'),
    ('Perugia', 'Umbria'),
    ('Pesaro e Urbino', 'Marche'),
    ('Pescara', 'Abruzzo'),
    ('Piacenza', 'Emilia-Romagna'),
    ('Pisa', 'Toscana'),
    ('Pistoia', 'Toscana'),
    ('Pordenone', 'Friuli-Venezia Giulia'),
    ('Potenza', 'Basilicata'),
    ('Prato', 'Toscana'),
    ('Ragusa', 'Sicilia'),
    ('Ravenna', 'Emilia-Romagna'),
    ('Reggio Calabria', 'Calabria'),
    ('Reggio Emilia', 'Emilia-Romagna'),
    ('Rieti', 'Lazio'),
    ('Rimini', 'Emilia-Romagna'),
    ('Roma', 'Lazio'),
    ('Rovigo', 'Veneto'),
    ('Salerno', 'Campania'),
    ('Sassari', 'Sardegna'),
    ('Savona', 'Liguria'),
    ('Siena', 'Toscana'),
    ('Siracusa', 'Sicilia'),
    ('Sondrio', 'Lombardia'),
    ('Sulcis Iglesiente', 'Sardegna'),
    ('Taranto', 'Puglia'),
    ('Teramo', 'Abruzzo'),
    ('Terni', 'Umbria'),
    ('Torino', 'Piemonte'),
    ('Trapani', 'Sicilia'),
    ('Trento', 'Trentino-Alto Adige'),
    ('Treviso', 'Veneto'),
    ('Trieste', 'Friuli-Venezia Giulia'),
    ('Udine', 'Friuli-Venezia Giulia'),
    ('Varese', 'Lombardia'),
    ('Venezia', 'Veneto'),
    ('Verbano-Cusio-Ossola', 'Piemonte'),
    ('Vercelli', 'Piemonte'),
    ('Verona', 'Veneto'),
    ('Vibo Valentia', 'Calabria'),
    ('Vicenza', 'Veneto'),
    ('Viterbo', 'Lazio');

INSERT INTO Categoria (NomeCategoria, Sesso, CategoriaMerceologica) VALUES --30 tuple
    ('pantaloni cargo', 'uomo', 'pantaloni'),
    ('jeans slim fit', 'uomo', 'pantaloni'),
    ('t-shirt basic', 'uomo', 'magliette'),
    ('camicia a righe', 'uomo', 'camicie'),
    ('felpa con cappuccio', 'uomo', 'felpe'),
    ('giacca di pelle', 'uomo', 'giacche'),
    ('pantaloncini sportivi', 'uomo', 'pantaloncini'),
    ('tuta sportiva', 'uomo', 'tute'),
    ('polo in cotone', 'uomo', 'polo'),
    ('scarpe da ginnastica', 'uomo', 'calzature'),
    ('vestito floreale', 'donna', 'vestiti'),
    ('jeans skinny', 'donna', 'pantaloni'),
    ('t-shirt basic', 'donna', 'magliette'),
    ('giacca di pelle', 'donna', 'giacche'),
    ('pantaloni a zampa', 'donna', 'pantaloni'),
    ('leggings sportivi', 'donna', 'pantaloni'),
    ('felpa corta', 'donna', 'felpe'),
    ('sneakers platform', 'donna', 'calzature'),
    ('borsa a tracolla', 'donna', 'accessori'),
    ('vestito elegante', 'donna', 'vestiti'),
    ('t-shirt oversize', 'unisex', 'magliette'),
    ('felpa minimal', 'unisex', 'felpe'),
    ('pantaloni cargo', 'unisex', 'pantaloni'),
    ('sneakers classiche', 'unisex', 'calzature'),
    ('berretto in lana', 'unisex', 'accessori'),
    ('tuta in cotone', 'unisex', 'tute'),
    ('zaino urbano', 'unisex', 'accessori'),
    ('maglione in cotone', 'unisex', 'maglioni'),
    ('giacca antivento', 'unisex', 'giacche'),
    ('cintura in pelle', 'unisex', 'accessori');

INSERT INTO Prodotto (NomeProdotto, Marchio, PrezzoBase, IDCategoria) VALUES --60 tuple
    ('Slim Cargo Pant', 'G-Star', 85.00, 1001),
    ('Slim Fit Cargo', 'G-Star', 87.00, 1001),
    ('Denim Slim Jeans', 'Levi''s', 92.50, 1002),
    ('Slim Fit Jeans Dark', 'Diesel', 89.50, 1002),
    ('Denim Slim Jeans Dark', 'Diesel', 95.00, 1002),
    ('Basic Cotton T-Shirt', 'H&M', 19.99, 1003),
    ('Basic Tee Crew', 'Zara', 22.99, 1003),
    ('Basic Tee Round', 'Zara', 25.00, 1003),
    ('Striped Casual Shirt', 'Zara', 49.99, 1004),
    ('Checked Shirt Slim', 'H&M', 49.99, 1004),
    ('Checked Shirt Casual', 'H&M', 52.00, 1004),
    ('Hooded Sweatshirt', 'Nike', 59.99, 1005),
    ('Hooded Sweatshirt Zip', 'Nike', 65.00, 1005),
    ('Hooded Sweatshirt Pullover', 'Nike', 68.00, 1005),
    ('Leather Biker Jacket', 'Guess', 249.99, 1006),
    ('Leather Jacket Moto', 'Guess', 259.99, 1006),
    ('Leather Biker Jacket Black', 'Guess', 270.00, 1006),
    ('Sport Shorts Mesh', 'Adidas', 35.00, 1007),
    ('Mesh Sport Shorts', 'Puma', 38.00, 1007),
    ('Sport Shorts Running', 'Adidas', 40.00, 1007),
    ('Tracksuit Essentials', 'Puma', 99.99, 1008),
    ('Tracksuit Hoodie', 'Adidas', 112.99, 1008),
    ('Tracksuit Set', 'Puma', 102.00, 1008),
    ('Cotton Polo Shirt', 'Ralph Lauren', 69.99, 1009),
    ('Classic Polo Cotton', 'Ralph Lauren', 72.99, 1009),
    ('Cotton Polo Classic', 'Ralph Lauren', 75.00, 1009),
    ('Running Sneakers', 'Asics', 120.00, 1010),
    ('Sneakers Everyday', 'Asics', 118.00, 1010),
    ('Sneakers Running', 'New Balance', 115.00, 1010),
    ('Floral Summer Dress', 'Mango', 112.99, 1011),
    ('Maxi Floral Dress', 'Mango', 85.00, 1011),
    ('Leather Jacket Retro', 'Michael Kors', 310.00, 1014),
    ('Flared Pants Chic', 'H&M', 59.99, 1015),
    ('Flared Pants High Waist', 'H&M', 60.00, 1015),
    ('Sport Leggings', 'Adidas', 45.00, 1016),
    ('Leggings Gym', 'Nike', 48.50, 1016),
    ('Cropped Hoodie', 'Nike', 55.00, 1017),
    ('Cropped Hoodie Print', 'Champion', 58.00, 1017),
    ('Platform Sneakers', 'Buffalo', 130.00, 1018),
    ('Platform Sneakers Black', 'Buffalo', 135.00, 1018),
    ('Crossbody Bag', 'Michael Kors', 149.99, 1019),
    ('Mini Crossbody Bag', 'Michael Kors', 155.00, 1019),
    ('Elegant Evening Dress', 'Zara', 129.99, 1020),
    ('Cocktail Dress', 'Zara', 139.99, 1020),
    ('Oversize T-Shirt Logo', 'Champion', 39.99, 1021),
    ('Oversize Graphic Tee', 'Adidas', 42.00, 1021),
    ('Minimal Hoodie', 'Uniqlo', 49.99, 1022),
    ('Minimal Hoodie Zip', 'Uniqlo', 52.00, 1022),
    ('Urban Cargo Pants', 'Carhartt', 92.00, 1023),
    ('Classic Sneakers Black', 'Nike', 115.00, 1024),
    ('Cotton Tracksuit', 'Puma', 95.00, 1026),
    ('Tracksuit Cotton', 'Puma', 98.00, 1026),
    ('Urban Backpack', 'Eastpak', 69.99, 1027),
    ('Cotton Sweater Crew', 'H&M', 59.99, 1028),
    ('Crew Neck Sweater', 'H&M', 61.00, 1028),
    ('Windbreaker Jacket', 'Columbia', 120.00, 1029),
    ('Windbreaker Jacket Hood', 'Columbia', 125.00, 1029),
    ('Leather Belt', 'Gucci', 199.99, 1030),
    ('Leather Belt Classic', 'Gucci', 205.00, 1030),
    ('Leather Belt Signature', 'Gucci', 205.00, 1030);

INSERT INTO PuntoVendita (IDProvincia, Indirizzo) VALUES --10 tuple
    (58, 'Via Torino, 1, 20123'),
    (58, 'Corso Buenos Aires, 2, 20124'),
    (50, 'Corso Roma, 60, 26900'),
    (50, 'Corso Roma, 52, 26900'),
    (66, 'Via Umberto I, 84, 35127'),
    (104, 'Campo della Fava, 5527, 30100'),
    (39, 'Via Roccatagliata Ceccardi, 4, 16121'),
    (15, 'Via della Zecca, 1, 40121'),
    (85, 'Via Città Sant''Angelo, 23, 00179'),
    (61, 'Via Foria, 119, 80137');

INSERT INTO ClienteRegistrato (Nome, Cognome, Mail, NumeroDiTelefono, TesseraFedelta, IDProvincia) VALUES --80 tuple
    ('Luca', 'Rossi', 'luca.rossi@gmail.com', '+39 320 100 1001', 1, 1),
    ('Marco', 'Bianchi', 'marco.bianchi@outlook.com', '+39 320 100 1002', 0, 2),
    ('Giulia', 'Ferrari', 'giulia.ferrari@libero.it', '+39 347 200 2003', 0, 5),
    ('Francesco', 'Romano', 'francesco.romano@yahoo.it', '+39 347 200 2004', 0, 5),
    ('Anna', 'Galli', 'anna.galli@hotmail.it', '+39 331 300 3005', 1, 7),
    ('Matteo', 'Conti', 'matteo.conti@gmail.com', '+39 331 300 3006', 1, 8),
    ('Sara', 'Ricci', 'sara.ricci@protonmail.com', '+39 320 100 1007', 0, 11),
    ('Alessandro', 'Marino', 'alessandro.marino@outlook.com', '+39 347 400 4008', 1, 15),
    ('Federica', 'Greco', 'federica.greco@libero.it', '+39 347 400 4009', 1, 15),
    ('Davide', 'Bruno', 'davide.bruno@gmail.com', '+39 320 100 1010', 1, 15),
    ('Elena', 'Gallo', 'elena.gallo@icloud.com', '+39 331 300 3011', 1, 15),
    ('Stefano', 'Fontana', 'stefano.fontana@outlook.com', '+39 021 234 5612', 0, 15),
    ('Silvia', 'Moretti', 'silvia.moretti@gmail.com', '+39 061 456 6413', 0, 15),
    ('Giorgio', 'Costa', 'giorgio.costa@libero.it', '+39 347 500 5014', 1, 13),
    ('Valentina', 'Giordano', 'valentina.giordano@yahoo.it', '+39 347 500 5015', 0, 17),
    ('Paolo', 'Rinaldi', 'paolo.rinaldi@hotmail.it', '+39 320 100 1016', 0, 18),
    ('Laura', 'Lombardi', 'laura.lombardi@protonmail.com', '+39 331 300 3017', 0, 20),
    ('Riccardo', 'Colombo', 'riccardo.colombo@outlook.com', '+39 320 100 1018', 1, 21),
    ('Chiara', 'Mancini', 'chiara.mancini@gmail.com', '+39 347 600 6019', 1, 23),
    ('Simone', 'Palumbo', 'simone.palumbo@libero.it', '+39 347 600 6020', 0, 25),
    ('Martina', 'Longo', 'martina.longo@yahoo.it', '+39 331 300 3021', 1, 27),
    ('Andrea', 'Marchetti', 'andrea.marchetti@hotmail.it', '+39 022 345 6722', 0, 33),
    ('Michele', 'Martini', 'michele.martini@gmail.com', '+39 062 345 6723', 1, 33),
    ('Roberta', 'Sartori', 'roberta.sartori@outlook.com', '+39 331 300 3024', 0, 33),
    ('Emanuele', 'Ruggiero', 'emanuele.ruggiero@libero.it', '+39 347 700 7025', 1, 33),
    ('Veronica', 'Farina', 'veronica.farina@protonmail.com', '+39 347 700 7026', 1, 33),
    ('Nicola', 'Sorrentino', 'nicola.sorrentino@gmail.com', '+39 320 100 1027', 1, 39),
    ('Beatrice', 'Testa', 'beatrice.testa@virgilio.it', '+39 331 300 3028', 0, 39),
    ('Alberto', 'Grassi', 'alberto.grassi@tiscali.it', '+39 347 800 8029', 1, 39),
    ('Irene', 'Parisi', 'irene.parisi@gmail.com', '+39 063 456 7830', 1, 43),
    ('Carlo', 'Bernardi', 'carlo.bernardi@outlook.com', '+39 023 456 7831', 0, 44),
    ('Monica', 'Pellegrini', 'monica.pellegrini@libero.it', '+39 347 900 9032', 1, 44),
    ('Diego', 'Guerra', 'diego.guerra@gmail.com', '+39 320 100 1033', 1, 50),
    ('Claudia', 'Barbieri', 'claudia.barbieri@outlook.com', '+39 331 300 3034', 1, 50),
    ('Fabio', 'Riva', 'fabio.riva@yahoo.it', '+39 347 900 9035', 0, 50),
    ('Paola', 'Basile', 'paola.basile@hotmail.it', '+39 347 900 9036', 1, 50),
    ('Vincenzo', 'Coppola', 'vincenzo.coppola@protonmail.com', '+39 024 567 8937', 0, 52),
    ('Caterina', 'Gentile', 'caterina.gentile@gmail.com', '+39 331 300 3038', 1, 57),
    ('Grazia', 'Pagano', 'grazia.pagano@outlook.com', '+39 347 100 1039', 1, 57),
    ('Tommaso', 'Amato', 'tommaso.amato@libero.it', '+39 347 100 1040', 0, 58),
    ('Daniela', 'Luca', 'daniela.luca@yahoo.it', '+39 320 100 1041', 1, 58),
    ('Gianluca', 'Caputo', 'gianluca.caputo@hotmail.it', '+39 331 300 3042', 1, 58),
    ('Sofia', 'Monti', 'sofia.monti@gmail.com', '+39 347 200 1043', 1, 58),
    ('Antonio', 'D''Angelo', 'antonio.dangelo@outlook.com', '+39 347 200 1044', 1, 58),
    ('Elisa', 'Bianco', 'elisa.bianco@libero.it', '+39 320 100 1045', 1, 58),
    ('Daniele', 'Sanna', 'daniele.sanna@protonmail.com', '+39 331 300 3046', 1, 58),
    ('Angela', 'Villa', 'angela.villa@gmail.com', '+39 347 300 3047', 1, 61),
    ('Roberto', 'Serra', 'roberto.serra@outlook.com', '+39 347 300 3048', 1, 61),
    ('Marina', 'De Luca', 'marina.deluca@yahoo.it', '+39 025 678 9049', 0, 61),
    ('Salvatore', 'Villa', 'salvatore.villa@hotmail.it', '+39 065 678 9050', 0, 61),
    ('Bianca', 'Fabbri', 'bianca.fabbri@gmail.com', '+39 331 300 3051', 0, 61),
    ('Lorenzo', 'Mirabella', 'lorenzo.mirabella@libero.it', '+39 347 400 4052', 0, 62),
    ('Noemi', 'Sala', 'noemi.sala@outlook.com', '+39 347 400 4053', 1, 65),
    ('Massimo', 'Ferreira', 'massimo.ferreira@gmail.com', '+39 320 100 1054', 0, 66),
    ('Cristina', 'Marche', 'cristina.marche@protonmail.com', '+39 331 300 3055', 0, 66),
    ('Enzo', 'Bellini', 'enzo.bellini@libero.it', '+39 026 789 0156', 0, 67),
    ('Marianna', 'Valentini', 'marianna.valentini@gmail.com', '+39 347 500 5057', 1, 73),
    ('Pietro', 'Catena', 'pietro.catena@outlook.com', '+39 347 500 5058', 1, 73),
    ('Sergio', 'Savini', 'sergio.savini@yahoo.it', '+39 331 300 3059', 0, 77),
    ('Lucia', 'Russo', 'lucia.russo@hotmail.it', '+39 066 789 0160', 0, 80),
    ('Edoardo', 'Pagliaro', 'edoardo.pagliaro@gmail.com', '+39 027 890 1261', 0, 82),
    ('Giovanna', 'Neri', 'giovanna.neri@libero.it', '+39 347 600 6062', 1, 83),
    ('Stefano', 'Orsini', 'stefano.orsini@outlook.com', '+39 347 600 6063', 1, 85),
    ('Marta', 'Cappelletti', 'marta.cappelletti@gmail.com', '+39 331 300 3064', 1, 85),
    ('Rosa', 'Ruggieri', 'rosa.ruggieri@protonmail.com', '+39 347 700 7065', 1, 85),
    ('Gianfranco', 'Moro', 'gianfranco.moro@yahoo.it', '+39 347 700 7066', 0, 85),
    ('Adriana', 'Calabrese', 'adriana.calabrese@hotmail.it', '+39 320 100 1067', 0, 85),
    ('Walter', 'Cavaliere', 'walter.cavaliere@gmail.com', '+39 331 300 3068', 1, 86),
    ('Lidia', 'Donati', 'lidia.donati@outlook.com', '+39 347 800 8069', 1, 88),
    ('Oliviero', 'Palma', 'oliviero.palma@libero.it', '+39 347 800 8070', 1, 88),
    ('Raffaele', 'Monaco', 'raffaele.monaco@gmail.com', '+39 067 890 1271', 1, 88),
    ('Angela', 'Pace', 'angela.pace@protonmail.com', '+39 028 901 2372', 1, 91),
    ('Maurizio', 'Neri', 'maurizio.neri@outlook.com', '+39 331 300 3073', 0, 91),
    ('Rebecca', 'Mariani', 'rebecca.mariani@gmail.com', '+39 347 900 9074', 1, 91),
    ('Orlando', 'Cattaneo', 'orlando.cattaneo@libero.it', '+39 347 900 9075', 1, 99),
    ('Teresa', 'Vitali', 'teresa.vitali@yahoo.it', '+39 320 100 1076', 1, 100),
    ('Gianmarco', 'De Santis', 'gianmarco.desantis@outlook.com', '+39 331 300 3077', 0, 102),
    ('Antonella', 'Benedetti', 'antonella.benedetti@gmail.com', '+39 347 100 1078', 1, 102),
    ('Federico', 'Crespi', 'federico.crespi@protonmail.com', '+39 347 200 1079', 1, 108),
    ('Nadia', 'Bellotti', 'nadia.bellotti@libero.it', '+39 331 300 3080', 1, 110);

INSERT INTO Scontrino (DataDiVendita, CodiceSconto, IDClienteRegistrato, IDPuntoVendita) VALUES --80 tuple
    ('20250101', 1, NULL, 3002),
    ('20250203', 0, 4018, 3001),
    ('20250203', 0, 4014, 3001),
    ('20250305', 1, 4018, 3001),
    ('20250305', 0, NULL, 3004)

INSERT INTO Ordine (DataDiVendita, CodiceSconto, IDClienteRegistrato) VALUES --80 tuple
    ('20250101', 0, 4005),
    ('20250101', 0, 4005),
    ('20250103', 1, 4007),
    ('20250303', 0, 4007),
    ('20250305', 0, 4018)

INSERT INTO VenditaProdottoRetail (IDScontrino, IDProdotto, Quantita) VALUES --240 tuple
    (5001, 2004, 2),
    (5001, 2007, 4),
    (5002, 2022, 1),
    (5003, 2045, 1),
    (5003, 2007, 3),
    (5003, 2022, 6),
    (5004, 2010, 6),
    (5005, 2010, 4)

INSERT INTO VenditaProdottoOnline (IDOrdine, IDProdotto, Quantita) VALUES --240 tuple
    (6001, 2010, 1),
    (6001, 2004, 3),
    (6001, 2011, 4),
    (6002, 2022, 1),
    (6003, 2050, 2),
    (6003, 2007, 3),
    (6003, 2022, 7),
    (6004, 2011, 1),
    (6005, 2011, 5)



--SELECTS:

SELECT * FROM Provincia;
SELECT * FROM Categoria;
SELECT * FROM Prodotto;
SELECT * FROM PuntoVendita;
SELECT * FROM ClienteRegistrato;
SELECT * FROM Scontrino;
SELECT * FROM Ordine;
SELECT * FROM VenditaProdottoRetail;
SELECT * FROM VenditaProdottoOnline;



--QUERY DI CONTROLLO (TABELLA UNICA COMPLETA, ogni tupla la vendita online o retail di un prodotto in certa una quantità): 
WITH
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline),
    ScontrinoOOrdine AS (SELECT IDScontrino, NULL AS IDOrdine, DataDiVendita, CodiceSconto, IDClienteRegistrato, IDPuntoVendita FROM Scontrino UNION ALL
            SELECT NULL AS IDScontrino, IDOrdine, DataDiVendita, CodiceSconto, IDClienteRegistrato, NULL AS IDPuntoVendita FROM Ordine)
SELECT vp.IDScontrino, vp.IDOrdine, vp.IDProdotto, prod.NomeProdotto, prod.Marchio, prod.PrezzoBase, prod.IDCategoria, ca.NomeCategoria, ca.Sesso, ca.CategoriaMerceologica,
    vp.Quantita, vp.PrezzoUnitarioScontato, vp.Sconto, soo.DataDiVendita, soo.CodiceSconto, soo.IDClienteRegistrato, cr.Nome AS NomeCliente, cr.Cognome AS CognomeCliente,  
    cr.Mail, cr.NumeroDiTelefono, cr.TesseraFedelta, cr.IDProvincia AS IDPRovinciaClienteRegistrato, ProvinciaCliente.NomeProvincia AS NomeProvinciaCliente, ProvinciaCliente.Regione AS RegioneCliente, 
    soo.IDPuntoVendita, pv.IDProvincia AS IDPRovinciaPuntoVendita, pv.Indirizzo AS IndirizzoPuntoVendita, ProvinciaPuntoVendita.NomeProvincia AS NomeProvinciaPuntoVendita, ProvinciaPuntoVendita.Regione 
    AS RegionePuntoVendita
FROM VenditaProdotto vp JOIN Prodotto prod ON vp.IDProdotto = prod.IDProdotto JOIN Categoria ca ON prod.IDCategoria = ca.IDCategoria LEFT JOIN 
    ScontrinoOOrdine soo ON (vp.IDScontrino = soo.IDScontrino OR vp.IDOrdine = soo.IDOrdine) LEFT JOIN PuntoVendita pv ON soo.IDPuntoVendita = pv.IDPuntoVendita LEFT JOIN 
    ClienteRegistrato cr ON soo.IDClienteRegistrato = cr.IDClienteRegistrato LEFT JOIN Provincia AS ProvinciaPuntoVendita ON 
    pv.IDProvincia = ProvinciaPuntoVendita.IDProvincia LEFT JOIN Provincia ProvinciaCliente ON cr.IDProvincia = ProvinciaCliente.IDProvincia
ORDER BY vp.IDOrdine, vp.IDScontrino


--QUERY RICHIESTE:

go

--somma totale dei prodotti venduti e quantità degli sconti applicati per categoria merceologica
CREATE OR ALTER VIEW QueryVenditeEScontiPerCategoriaMerceologica AS 
WITH
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline)
SELECT 
    Categoria.CategoriaMerceologica, 
    SUM(VenditaProdotto.Quantita) AS NumeroProdottiVenduti, 
    SUM(CASE 
            WHEN VenditaProdotto.Sconto IS NULL THEN 0
            ELSE VenditaProdotto.Quantita
        END) AS QuantitaScontiApplicati
FROM VenditaProdotto JOIN Prodotto ON VenditaProdotto.IDProdotto = Prodotto.IDProdotto JOIN Categoria ON Prodotto.IDCategoria = Categoria.IDCategoria
GROUP BY Categoria.CategoriaMerceologica;
--ORDER BY Categoria.CategoriaMerceologica ASC;

go

--test QueryVenditeEScontiPerCategoriaMerceologica
select *
from QueryVenditeEScontiPerCategoriaMerceologica

go

--somma totale dei prodotti venduti e quantità degli sconti applicati per articolo
CREATE OR ALTER VIEW QueryVenditeEScontiPerProdotto AS 
WITH
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline)
SELECT 
    Prodotto.NomeProdotto AS Prodotto, 
    SUM(VenditaProdotto.Quantita) AS NumeroProdottiVenduti, 
    SUM(CASE 
            WHEN VenditaProdotto.Sconto IS NULL THEN 0
            ELSE VenditaProdotto.Quantita
        END) AS QuantitaScontiApplicati
FROM VenditaProdotto JOIN Prodotto ON VenditaProdotto.IDProdotto = Prodotto.IDProdotto
GROUP BY Prodotto.IDProdotto, Prodotto.NomeProdotto; 
--ORDER BY Prodotto.NomeProdotto ASC;

go

--test QueryVenditeEScontiPerProdotto
select *
from QueryVenditeEScontiPerProdotto

go

--somma totale dei prodotti venduti e quantità degli sconti applicati (solo in retail) per regione
CREATE OR ALTER VIEW QueryVenditeEScontiRetailPerRegione AS
SELECT 
    Provincia.Regione, 
    SUM(VenditaProdottoRetail.Quantita) AS NumeroProdottiVenduti, 
    SUM(CASE 
            WHEN VenditaProdottoRetail.Sconto IS NULL THEN 0
            ELSE VenditaProdottoRetail.Quantita
        END) AS QuantitaScontiApplicati
FROM VenditaProdottoRetail JOIN Prodotto ON VenditaProdottoRetail.IDProdotto = Prodotto.IDProdotto JOIN 
    Scontrino ON VenditaProdottoRetail.IDScontrino = Scontrino.IDScontrino JOIN 
    PuntoVendita ON Scontrino.IDPuntoVendita = PuntoVendita.IDPuntoVendita JOIN
    Provincia ON PuntoVendita.IDProvincia = Provincia.IDProvincia
GROUP BY Provincia.Regione; 
--ORDER BY Provincia.Regione ASC;

go

--test QueryVenditeEScontiRetailPerRegione
select *
from QueryVenditeEScontiRetailPerRegione

go

--somma totale dei prodotti venduti e quantità degli sconti applicati (solo in retail) per provincia
CREATE OR ALTER VIEW QueryVenditeEScontiRetailPerProvincia AS
SELECT 
    Provincia.NomeProvincia AS Provincia, Provincia.Regione,
    SUM(VenditaProdottoRetail.Quantita) AS NumeroProdottiVenduti, 
    SUM(CASE 
            WHEN VenditaProdottoRetail.Sconto IS NULL THEN 0
            ELSE VenditaProdottoRetail.Quantita
        END) AS QuantitaScontiApplicati
FROM VenditaProdottoRetail JOIN Prodotto ON VenditaProdottoRetail.IDProdotto = Prodotto.IDProdotto JOIN 
    Scontrino ON VenditaProdottoRetail.IDScontrino = Scontrino.IDScontrino JOIN 
    PuntoVendita ON Scontrino.IDPuntoVendita = PuntoVendita.IDPuntoVendita JOIN
    Provincia ON PuntoVendita.IDProvincia = Provincia.IDProvincia
GROUP BY Provincia.IDProvincia, Provincia.NomeProvincia, Provincia.Regione; 
--ORDER BY Provincia.NomeProvincia ASC;

go

--test QueryVenditeEScontiRetailPerProvincia
select *
from QueryVenditeEScontiRetailPerProvincia;

go

--numero di prodotti venduti per provincia (sia online che retail) => grafico 2
CREATE OR ALTER VIEW QueryProdottiVendutiPerProvincia AS
WITH 
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline),
    ScontrinoConProvincia AS (SELECT Scontrino.IDScontrino, Provincia.IDProvincia, Provincia.NomeProvincia AS Provincia, Provincia.Regione
            FROM Scontrino JOIN PuntoVendita ON Scontrino.IDPuntoVendita = PuntoVendita.IDPuntoVendita JOIN Provincia
                ON PuntoVendita.IDProvincia = Provincia.IDProvincia),
    OrdineConProvincia AS (SELECT Ordine.IDOrdine, Provincia.IDProvincia, Provincia.NomeProvincia AS Provincia, Provincia.Regione
            FROM Ordine JOIN ClienteRegistrato ON Ordine.IDClienteRegistrato = ClienteRegistrato.IDClienteRegistrato JOIN Provincia 
                ON ClienteRegistrato.IDProvincia = Provincia.IDProvincia),
    OrdineOScontrinoConProvincia AS (SELECT IDScontrino, NULL AS IDOrdine, IDProvincia, Provincia, Regione FROM ScontrinoConProvincia UNION ALL 
                SELECT NULL AS IDScontrino, IDOrdine, IDProvincia, Provincia, Regione FROM OrdineConProvincia)
SELECT OrdineOScontrinoConProvincia.Provincia, OrdineOScontrinoConProvincia.Regione, SUM(VenditaProdotto.Quantita) AS NumeroVendite
FROM VenditaProdotto LEFT JOIN OrdineOScontrinoConProvincia ON (VenditaProdotto.IDScontrino = OrdineOScontrinoConProvincia.IDScontrino) OR 
    (VenditaProdotto.IDOrdine = OrdineOScontrinoConProvincia.IDOrdine) 
GROUP BY OrdineOScontrinoConProvincia.IDProvincia, OrdineOScontrinoConProvincia.Provincia, OrdineOScontrinoConProvincia.Regione;
--ORDER BY OrdineOScontrinoConProvincia.NomeProvincia;

go

--test QueryProdottiVendutiPerProvincia
select *
from QueryProdottiVendutiPerProvincia;

go

--numero di acquisti per categoria merceologica => grafico 4 
CREATE OR ALTER VIEW QueryNumeroVenditeCategoriaMerceologica AS 
WITH
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline)
SELECT Categoria.CategoriaMerceologica, SUM(VenditaProdotto.Quantita) AS NumeroVendite
        FROM VenditaProdotto JOIN
            Prodotto ON VenditaProdotto.IDProdotto = Prodotto.IDProdotto JOIN 
            Categoria ON Prodotto.IDCategoria = Categoria.IDCategoria
        GROUP BY Categoria.CategoriaMerceologica;
--ORDER BY tmp.CategoriaMerceologica;

go

--test QueryCategoriaMerceologicaPiuAcquistata
select *
from QueryNumeroVenditeCategoriaMerceologica;

go

--fatturato per mese => grafico 1
CREATE OR ALTER VIEW QueryFatturatoMese AS 
WITH 
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline),
    DDV AS (SELECT (CASE WHEN Ordine.DataDiVendita IS NULL THEN Scontrino.DataDiVendita ELSE Ordine.DataDiVendita END) AS DataDiVendita, 
                VenditaProdotto.Quantita * VenditaProdotto.PrezzoUnitarioScontato AS PrezzoComplessivoScontato
            FROM VenditaProdotto LEFT JOIN
                Scontrino ON VenditaProdotto.IDScontrino = Scontrino.IDScontrino LEFT JOIN 
                Ordine ON VenditaProdotto.IDOrdine = Ordine.IDOrdine),
    tmp1 AS (SELECT DDV.DataDiVendita, DATENAME(MONTH, DDV.DataDiVendita) AS MeseDel2025, SUM(DDV.PrezzoComplessivoScontato) AS Fatturato
            FROM DDV
            GROUP BY DDV.DataDiVendita)
SELECT tmp1.MeseDel2025, SUM(tmp1.Fatturato) AS Fatturato
FROM tmp1
GROUP BY tmp1.MeseDel2025;
--ORDER BY tmp2.MeseDel2025;

go

--test QueryMesePiuProficuo
select *
from QueryFatturatoMese;

go

--fatturato per punto vendita => grafico 2
CREATE OR ALTER VIEW QueryFatturatoPuntoVendita AS
WITH
    tmp1 AS (SELECT PuntoVendita.IDPuntoVendita, PuntoVendita.Indirizzo, Provincia.NomeProvincia AS Provincia, Provincia.Regione,
                (VenditaProdottoRetail.PrezzoUnitarioScontato * VenditaProdottoRetail.Quantita) AS PrezzoComplessivoProdotto
            FROM VenditaProdottoRetail JOIN Scontrino ON VenditaProdottoRetail.IDScontrino = Scontrino.IDScontrino JOIN 
                PuntoVendita ON Scontrino.IDPuntoVendita = PuntoVendita.IDPuntoVendita JOIN
                Provincia ON PuntoVendita.IDProvincia = Provincia.IDProvincia)
SELECT tmp1.IDPuntoVendita, tmp1.Indirizzo, tmp1.Provincia, tmp1.Regione, SUM(tmp1.PrezzoComplessivoProdotto) AS Fatturato
FROM tmp1
GROUP BY tmp1.IDPuntoVendita, tmp1.Indirizzo, tmp1.Provincia, tmp1.Regione;
--ORDER BY tmp2.Provincia;

go

--test QueryPuntoVenditaPiuRedditizio
select *
from QueryFatturatoPuntoVendita

go

--numero di tessere fedeltà => nessun grafico
CREATE OR ALTER VIEW QueryNumeroTessereFedelta AS
SELECT SUM(CONVERT(INT, ClienteRegistrato.TesseraFedelta)) NumeroTessere 
FROM ClienteRegistrato;

go

--test QueryNumeroTessereFedelta
select *
from QueryNumeroTessereFedelta

go