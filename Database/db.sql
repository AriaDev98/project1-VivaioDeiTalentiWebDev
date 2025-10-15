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

    NomeProdotto VARCHAR(50) NOT NULL,
    
    Marchio VARCHAR(50) NOT NULL,

    PrezzoBase DECIMAL(10,2) NOT NULL,
        CHECK (PREZZOBASE > 0),

    IDCategoria INT NOT NULL, 

    FOREIGN KEY (IDCategoria) REFERENCES Categoria(IDCategoria)
);

CREATE TABLE PuntoVendita (
    IDPuntoVendita INT IDENTITY(3001,1) PRIMARY KEY, 

    IDProvincia INT NOT NULL, 

    Indirizzo VARCHAR(50) NOT NULL, 

    FOREIGN KEY (IDProvincia) REFERENCES Provincia(IDProvincia)
);

CREATE TABLE ClienteRegistrato ( --METTERCI ANCHE MAIL E NUM DI TEL?
    /*
    esclusi dai clienti registrati? 
    tutti i clienti tranne quelli che hanno fatto solo (0 o più) acquisti in retail senza mai presentare la tessera 
    */

    --i clienti registrati possono non aver mai fatto acquisti!
    
    IDClienteRegistrato INT IDENTITY(4001,1) PRIMARY KEY, 

    TesseraFedelta BIT NOT NULL, 
    --se è 0 allora allora il cliente registrato in questione ha fatto solo (0 o più) ordini online, non può aver fatto acquisti in retail
    --se è 1 allora allora il cliente registrato in questione ha fatto (0 o più) ordini online e (0 o più) acquisti in retail
    
    IDProvincia INT NOT NULL,

    FOREIGN KEY (IDProvincia) REFERENCES Provincia(IDProvincia)
);

CREATE TABLE Scontrino ( 
    IDScontrino INT IDENTITY(5001,1) PRIMARY KEY,

    DataDiVendita DATE NOT NULL,
        CHECK (DataDiVendita BETWEEN '20250101' AND '20250930'), 

    CodiceSconto BIT NOT NULL,

    IDClienteRegistrato INT,
    --IDClienteRegistrato IS NULL => all'acquisto il cliente non ha presentato TesseraFedeltà (perchè non la ha o perchè l'ha dimenticata a casa) (VOGLIAMO FARE COSI? 
    --  MAGARI E UNA STRATEGIA DELL'AZIENDA PER FARE PIU SOLDI)
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
   
    PrezzoUnitarioScontato DECIMAL(10,2) NOT NULL,
    
    Sconto INT,

    FOREIGN KEY (IDScontrino) REFERENCES Scontrino(IDScontrino),
    FOREIGN KEY (IDProdotto) REFERENCES Prodotto(IDProdotto)
);

CREATE TABLE VenditaProdottoOnline (
    IDOrdine INT NOT NULL,
  
    IDProdotto INT NOT NULL,

    CONSTRAINT PK_VenditaProdottoOnline PRIMARY KEY (IDOrdine, IDProdotto),

    Quantita INT,
        CHECK (Quantita > 0),
   
    PrezzoUnitarioScontato DECIMAL(10,2) NOT NULL,
    
    Sconto INT, 

    FOREIGN KEY (IDOrdine) REFERENCES Ordine(IDOrdine),
    FOREIGN KEY (IDProdotto) REFERENCES Prodotto(IDProdotto)
);




--TRIGGERS:
GO

CREATE TRIGGER trg_CalcolaScontoVenditaProdottoRetail
ON VenditaProdottoRetail
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE VPR
    SET VPR.Sconto = 
        CASE
            WHEN S.CodiceSconto = 1 THEN 30
            WHEN S.CodiceSconto = 0
                 AND (S.IDClienteRegistrato IS NULL
                      OR (S.IDClienteRegistrato IS NOT NULL AND P.PrezzoBase < 50))
                 THEN NULL
            WHEN S.CodiceSconto = 0
                 AND S.IDClienteRegistrato IS NOT NULL
                 AND P.PrezzoBase >= 50
                 AND P.PrezzoBase < 100
                 THEN 20
            WHEN S.CodiceSconto = 0
                 AND S.IDClienteRegistrato IS NOT NULL
                 AND P.PrezzoBase >= 100
                 THEN 10
        END
    FROM VenditaProdottoRetail AS VPR
    INNER JOIN inserted AS I --inserted <- tabella virtuale con le tuple inserite in VenditaProdottoRetail nell'ultimo inserimento/update fatto
        ON VPR.IDScontrino = I.IDScontrino AND VPR.IDProdotto = I.IDProdotto
    INNER JOIN Scontrino AS S
        ON I.IDScontrino = S.IDScontrino
    INNER JOIN Prodotto AS P
        ON I.IDProdotto = P.IDProdotto;
END;

GO

CREATE TRIGGER trg_CalcolaScontoVenditaProdottoOnline
ON VenditaProdottoOnline
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vpo
    SET Sconto = 
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
        ON vpo.IDOrdine = i.IDOrdine 
       AND vpo.IDProdotto = i.IDProdotto
    INNER JOIN Ordine o 
        ON i.IDOrdine = o.IDOrdine
    INNER JOIN ClienteRegistrato c 
        ON o.IDClienteRegistrato = c.IDClienteRegistrato
    INNER JOIN Prodotto p 
        ON i.IDProdotto = p.IDProdotto;
END;

GO

CREATE TRIGGER trg_CalcolaPrezzoUnitarioScontatoVenditaProdottoRetail
ON VenditaProdottoRetail
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vpr
    SET PrezzoUnitarioScontato = ROUND(p.PrezzoBase - ((p.PrezzoBase * ISNULL(vpr.Sconto, 0)) / 100.0), 2)
    FROM VenditaProdottoRetail vpr
    INNER JOIN inserted i ON vpr.IDProdotto = i.IDProdotto
    INNER JOIN Prodotto p ON vpr.IDProdotto = p.IDProdotto;
END;

GO

CREATE TRIGGER trg_CalcolaPrezzoUnitarioScontatoVenditaProdottoOnline
ON VenditaProdottoOnline
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    UPDATE vpo
    SET PrezzoUnitarioScontato = ROUND(p.PrezzoBase - ((p.PrezzoBase * ISNULL(vpo.Sconto, 0)) / 100.0), 2)
    FROM VenditaProdottoOnline vpo
    INNER JOIN inserted i ON vpo.IDProdotto = i.IDProdotto
    INNER JOIN Prodotto p ON vpo.IDProdotto = p.IDProdotto;
END;

GO

CREATE TRIGGER trg_VerificaTesseraFedeltaScontrino
ON Scontrino
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT *
        FROM inserted i
        JOIN ClienteRegistrato c ON i.IDClienteRegistrato = c.IDClienteRegistrato
        WHERE i.IDClienteRegistrato IS NOT NULL
          AND c.TesseraFedelta = 0
    )
    BEGIN
        RAISERROR (
            'ERRORE: Ogni cliente associato allo scontrino deve avere TesseraFedelta = 1.',
            16, 1 --severità e stato dell'errore
        );
        ROLLBACK TRANSACTION;
        RETURN;
    END
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
    ('Tracksuit Hoodie', 'Adidas', 99.99, 1008),
    ('Tracksuit Set', 'Puma', 102.00, 1008),
    ('Cotton Polo Shirt', 'Ralph Lauren', 69.99, 1009),
    ('Classic Polo Cotton', 'Ralph Lauren', 72.99, 1009),
    ('Cotton Polo Classic', 'Ralph Lauren', 75.00, 1009),
    ('Running Sneakers', 'Asics', 120.00, 1010),
    ('Sneakers Everyday', 'Asics', 118.00, 1010),
    ('Sneakers Running', 'New Balance', 115.00, 1010),
    ('Floral Summer Dress', 'Mango', 79.99, 1011),
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

INSERT INTO ClienteRegistrato (TesseraFedelta, IDProvincia) VALUES --100 tuple
    (0, 59),
    (1, 11),
    (0, 58),
    (1, 75);

INSERT INTO Scontrino (DataDiVendita, CodiceSconto, IDClienteRegistrato, IDPuntoVendita) VALUES --80 tuple
    ('20250601', 1, NULL, 3002)

INSERT INTO Ordine (DataDiVendita, CodiceSconto, IDClienteRegistrato) VALUES --80 tuple
    ('20250609', 0, 4004)
    
INSERT INTO VenditaProdottoRetail (IDScontrino, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto) VALUES --240 tuple
    (5001, 2004, 2, 0, 0)

INSERT INTO VenditaProdottoOnline (IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto) VALUES --240 tuple
    (6001, 2010, 1, 0, 0)



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



--QUERY:

/*estrarre dai dati inseriti il valore della somma totale delle vendite (VENDITA = VENDITA SINGOLO PRODOTTO?) e la quantità degli sconti applicati 
(NUMERO DI PRODOTTI VENDUTI SCONTATI?) (sia retail sia e-commerce) organizzati secondo categoria merceologica/articolo e regione/provincia del 
punto vendita; estrarre anche le informazioni relative alle visualizzazioni grafiche*/

--TODO: HO INTERPRETATO BENE LE SEGUENTI QUERY DA FARE?

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

--somma totale dei prodotti venduti in retail e quantità degli sconti applicati in retail per regione
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

--somma totale dei prodotti venduti in retail e quantità degli sconti applicati in retail per provincia
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
from QueryVenditeEScontiRetailPerProvincia

go

/*creare le visualizzazioni per rappresentare le vendite per provincia (sia online che retail? io faccio entrambi...), la maggior categoria merceologica acquistata, 
il mese più proficuo dell’anno, il punto vendita più redditizio e il numero di tessere fedeltà totali*/

--TODO: HO INTERPRETATO BENE LE SEGUENTI QUERY DA FARE?

--numero di prodotti venduti per provincia 
CREATE OR ALTER VIEW QueryProdottiVendutiPerProvincia AS
WITH 
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
    SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline)
SELECT Provincia.NomeProvincia AS Provincia, Provincia.Regione, SUM(VenditaProdotto.Quantita) AS NumeroVendite
FROM VenditaProdotto LEFT JOIN Scontrino ON VenditaProdotto.IDScontrino = Scontrino.IDScontrino LEFT JOIN 
    Ordine ON VenditaProdotto.IDOrdine = Ordine.IDOrdine LEFT JOIN 
    ClienteRegistrato ON Ordine.IDClienteRegistrato = ClienteRegistrato.IDClienteRegistrato LEFT JOIN
    PuntoVendita ON Scontrino.IDPuntoVendita = PuntoVendita.IDPuntoVendita JOIN 
    Provincia ON (PuntoVendita.IDProvincia = Provincia.IDProvincia OR ClienteRegistrato.IDProvincia = Provincia.IDProvincia)
GROUP BY Provincia.IDProvincia, Provincia.NomeProvincia, Provincia.Regione;
--ORDER BY Provincia.NomeProvincia;

go

--test QueryProdottiVendutiPerProvincia
select *
from QueryProdottiVendutiPerProvincia

go

--categoria merceologica più acquistata
CREATE OR ALTER VIEW QueryCategoriaMerceologicaPiuAcquistata AS
WITH
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline),
    tmp AS (SELECT Categoria.CategoriaMerceologica, SUM(VenditaProdotto.Quantita) AS NumeroVendite
            FROM VenditaProdotto JOIN
                Prodotto ON VenditaProdotto.IDProdotto = Prodotto.IDProdotto JOIN 
                Categoria ON Prodotto.IDCategoria = Categoria.IDCategoria
            GROUP BY Categoria.CategoriaMerceologica)
SELECT tmp.CategoriaMerceologica AS CategoriaMerceologicaPiuAcquistata, tmp.NumeroVendite
FROM tmp
WHERE tmp.NumeroVendite = (SELECT MAX(tmp.NumeroVendite) FROM tmp);
--ORDER BY tmp.CategoriaMerceologica;

go

--test QueryCategoriaMerceologicaPiuAcquistata
select *
from QueryCategoriaMerceologicaPiuAcquistata

go

--mese più proficuo dell'anno
CREATE OR ALTER VIEW QueryMesePiuProficuo AS
WITH 
    VenditaProdotto AS (SELECT IDScontrino, NULL AS IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoRetail UNION ALL 
            SELECT NULL AS IDScontrino, IDOrdine, IDProdotto, Quantita, PrezzoUnitarioScontato, Sconto FROM VenditaProdottoOnline),
    DDV AS (SELECT (CASE WHEN Ordine.DataDiVendita IS NULL THEN Scontrino.DataDiVendita ELSE Ordine.DataDiVendita END) AS DataDiVendita, VenditaProdotto.Quantita
            FROM VenditaProdotto LEFT JOIN
                Scontrino ON VenditaProdotto.IDScontrino = Scontrino.IDScontrino LEFT JOIN 
                Ordine ON VenditaProdotto.IDOrdine = Ordine.IDOrdine),
    tmp1 AS (SELECT DDV.DataDiVendita, DATENAME(MONTH, DDV.DataDiVendita) AS MeseDel2025, SUM(DDV.Quantita) AS NumeroVendite
            FROM DDV
            GROUP BY DDV.DataDiVendita),
    tmp2 AS (SELECT tmp1.MeseDel2025, SUM(tmp1.NumeroVendite) AS NumeroVendite
            FROM tmp1
            GROUP BY tmp1.MeseDel2025) 
SELECT tmp2.MeseDel2025 AS MeseDel2025, tmp2.NumeroVendite
FROM tmp2
WHERE tmp2.NumeroVendite = (SELECT MAX(tmp2.NumeroVendite)
    FROM tmp2);
--ORDER BY tmp2.MeseDel2025;

go

--test QueryMesePiuProficuo
select *
from QueryMesePiuProficuo

go

--punto vendita più redditizio
CREATE OR ALTER VIEW QueryPuntoVenditaPiuRedditizio AS
WITH
    tmp1 AS (SELECT PuntoVendita.IDPuntoVendita, PuntoVendita.Indirizzo, Provincia.NomeProvincia AS Provincia, Provincia.Regione,
                (VenditaProdottoRetail.PrezzoUnitarioScontato * VenditaProdottoRetail.Quantita) AS PrezzoComplessivoProdotto
            FROM VenditaProdottoRetail JOIN Scontrino ON VenditaProdottoRetail.IDScontrino = Scontrino.IDScontrino JOIN 
                PuntoVendita ON Scontrino.IDPuntoVendita = PuntoVendita.IDPuntoVendita JOIN
                Provincia ON PuntoVendita.IDProvincia = Provincia.IDProvincia),
    tmp2 AS (SELECT tmp1.IDPuntoVendita, tmp1.Indirizzo, tmp1.Provincia, tmp1.Regione, SUM(tmp1.PrezzoComplessivoProdotto) AS Fatturato
            FROM tmp1
            GROUP BY tmp1.IDPuntoVendita, tmp1.Indirizzo, tmp1.Provincia, tmp1.Regione) 
SELECT tmp2.IDPuntoVendita, tmp2.Indirizzo, tmp2.Provincia, tmp2.Regione, tmp2.Fatturato
FROM tmp2
WHERE tmp2.Fatturato = (SELECT MAX(tmp2.Fatturato) AS Fatturato
    FROM tmp2);
--ORDER BY tmp2.Provincia;

go

--test QueryPuntoVenditaPiuRedditizio
select *
from QueryPuntoVenditaPiuRedditizio

go

--numero di tessere fedeltà
CREATE OR ALTER VIEW QueryNumeroTessereFedelta AS
SELECT SUM(CONVERT(INT, ClienteRegistrato.TesseraFedelta)) NumeroTessere 
FROM ClienteRegistrato;

go

--test QueryNumeroTessereFedelta
select *
from QueryNumeroTessereFedelta

go