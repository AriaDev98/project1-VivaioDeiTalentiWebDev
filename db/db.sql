DROP TABLE IF EXISTS ORDINE;
DROP TABLE IF EXISTS SCONTRINO;
DROP TABLE IF EXISTS VENDITA;
DROP TABLE IF EXISTS PUNTOVENDITA;
DROP TABLE IF EXISTS CLIENTE;
DROP TABLE IF EXISTS PRODOTTO;
DROP TABLE IF EXISTS CATEGORIA;
DROP TABLE IF EXISTS PROVINCIA;

--TABELLE:

CREATE TABLE PROVINCIA ( 
    NOME NVARCHAR(50) PRIMARY KEY, --devono esserci almeno Milano, Lodi, Padova, Venezia, Genova, Bologna, Roma e Napoli (provincie dei punti vendita)
    REGIONE NVARCHAR(50) NOT NULL
);
--tutte le provincie di italia

CREATE TABLE CATEGORIA (
    ID INT PRIMARY KEY,
        CHECK (ID > 0),

    NOME NVARCHAR(50) NOT NULL,
    CATEGORIAMERCEOLOGICA NVARCHAR(50) NOT NULL
);

CREATE TABLE PRODOTTO (
    ID INT PRIMARY KEY,
        CHECK (ID > 0),

    NOME NVARCHAR(50) NOT NULL,
    
    PREZZO DECIMAL(10,2) NOT NULL, --NON SCONTATO
        CHECK (PREZZO > 0),

    IDCATEGORIA INT NOT NULL, 

    FOREIGN KEY (IDCATEGORIA) REFERENCES CATEGORIA(ID)
);

CREATE TABLE CLIENTE (
    ID INT PRIMARY KEY,
        CHECK (ID > 0),

    NOMEPROVINCIA NVARCHAR(50) NOT NULL,

    TESSERAFEDELTA BIT NOT NULL,

    FOREIGN KEY (NOMEPROVINCIA) REFERENCES PROVINCIA(NOME)
);

CREATE TABLE PUNTOVENDITA (
    ID INT PRIMARY KEY,
        CHECK (ID > 0),

    NOMEPROVINCIA NVARCHAR(50) NOT NULL,
        CHECK (NOMEPROVINCIA IN ('Milano', 'Lodi', 'Padova', 'Venezia', 'Genova', 'Bologna', 'Roma' ,'Napoli')),

    FOREIGN KEY (NOMEPROVINCIA) REFERENCES PROVINCIA(NOME)
);

CREATE TABLE VENDITA ( --minimo 150 tuple
    ID INT PRIMARY KEY,
        CHECK (ID > 0),
    
    TIPO NVARCHAR(50) NOT NULL, 
        CHECK (TIPO IN ('retail', 'online')),

    DATADIVENDITA DATE NOT NULL,
        CHECK (DATADIVENDITA >= '20250101' AND DATADIVENDITA <= '20250930'), --TODO: da testare se funziona

    IDPRODOTTO INT NOT NULL,
   
    PREZZOUNITARIO DECIMAL(10,2) NOT NULL, --SCONTATO, CALCOLATO E NON IMPOSTABILE (SERVE TRIGGER): PREZZOUNITARIO = PRODOTTO.PREZZO - SCONTO(convertito all'intero giusto) * 
                                           --PRODOTTO.PREZZO

    QUANTITA INT NOT NULL,
        CHECK (QUANTITA > 0),
    
    SCONTO VARCHAR(3) NOT NULL, --CALCOLATO E NON IMPOSTABILE (SERVE TRIGGER): se presente la tessera fedeltà, ogni articolo con prezzo superiore a 50€ viene scontato del 20%; 
                                --ogni articolo che supera i 100€ viene scontato del 10%; se viene presentato un codice sconto, vengono annullati gli 
                                --sconti applicati e viene considerata una percentuale del 30% sul totale.
        CHECK (SCONTO IN ('0%', '10%', '20%', '30%')),

    TESSERAFEDELTA BIT NOT NULL, --mettere constraint (SERVE TRIGGER) per cui SE TIPO = 'online' ALLORA TESSERAFEDELTA = CLIENTE.TESSERAFEDELTA
    CODICESCONTO BIT NOT NULL,

    FOREIGN KEY (IDPRODOTTO) REFERENCES PRODOTTO(ID)
);

CREATE TABLE SCONTRINO (
    ID INT PRIMARY KEY,
        CHECK (ID > 0),

    IDPUNTOVENDITA INT NOT NULL,

    IDVENDITA INT NOT NULL,

    FOREIGN KEY (IDPUNTOVENDITA) REFERENCES PUNTOVENDITA(ID),
    FOREIGN KEY (IDVENDITA) REFERENCES VENDITA(ID)
);

CREATE TABLE ORDINE (
    ID INT PRIMARY KEY,
        CHECK (ID > 0),

    IDVENDITA INT NOT NULL,

    IDCLIENTE INT NOT NULL,

    FOREIGN KEY (IDVENDITA) REFERENCES VENDITA(ID),
    FOREIGN KEY (IDCLIENTE) REFERENCES CLIENTE(ID)
);



--INSERTS:

INSERT INTO PROVINCIA (NOME, REGIONE) VALUES
('Milano', 'Lombardia'),
('Lodi', 'Lombardia'),
('Padova', 'Veneto'),
('Venezia', 'Veneto'),
('Genova', 'Liguria'),
('Bologna', 'Emilia-Romagna'),
('Roma', 'Lazio'),
('Napoli', 'Campania'),
('Torino', 'Piemonte'),
('Firenze', 'Toscana');

INSERT INTO CATEGORIA (ID, NOME, CATEGORIAMERCEOLOGICA) VALUES
(201, 'Magliette', 'Abbigliamento Uomo'),
(202, 'Pantaloni', 'Abbigliamento Uomo'),
(203, 'Giacche', 'Abbigliamento Uomo'),
(204, 'Vestiti', 'Abbigliamento Donna'),
(205, 'Gonne', 'Abbigliamento Donna'),
(206, 'Scarpe', 'Calzature'),
(207, 'Accessori', 'Accessori Moda'),
(208, 'Felpe', 'Abbigliamento Unisex'),
(209, 'Cappotti', 'Abbigliamento Invernale'),
(210, 'Borse', 'Accessori Donna');

INSERT INTO PRODOTTO (ID, NOME, PREZZO, IDCATEGORIA) VALUES
(401, 'T-shirt basic bianca', 19.99, 201),
(402, 'Jeans slim fit', 59.90, 202),
(403, 'Giacca di pelle nera', 120.00, 203),
(404, 'Vestito estivo floreale', 75.00, 204),
(405, 'Gonna midi plissettata', 55.00, 205),
(406, 'Sneakers bianche', 85.00, 206),
(407, 'Cintura in pelle', 35.00, 207),
(408, 'Felpa con cappuccio', 60.00, 208),
(409, 'Cappotto di lana', 150.00, 209),
(410, 'Borsa a tracolla', 95.00, 210);

INSERT INTO CLIENTE (ID, NOMEPROVINCIA, TESSERAFEDELTA) VALUES
(601, 'Milano', 1),
(602, 'Lodi', 0),
(603, 'Padova', 1),
(604, 'Venezia', 1),
(605, 'Genova', 0),
(606, 'Bologna', 1),
(607, 'Roma', 0),
(608, 'Napoli', 1),
(609, 'Torino', 1),
(610, 'Firenze', 0);

INSERT INTO PUNTOVENDITA (ID, NOMEPROVINCIA) VALUES
(801, 'Milano'),
(802, 'Lodi'),
(803, 'Padova'),
(804, 'Venezia'),
(805, 'Genova'),
(806, 'Bologna'),
(807, 'Roma'),
(808, 'Napoli'),
(809, 'Milano'),
(810, 'Roma');

INSERT INTO VENDITA (ID, TIPO, DATADIVENDITA, IDPRODOTTO, PREZZOUNITARIO, QUANTITA, SCONTO, TESSERAFEDELTA, CODICESCONTO) VALUES
(1001, 'retail', '2025-01-15', 401, 19.99, 2, '0%', 0, 0),
(1002, 'retail', '2025-02-10', 402, 47.92, 1, '20%', 1, 0),
(1003, 'online', '2025-03-03', 403, 108.00, 1, '10%', 1, 0),
(1004, 'retail', '2025-03-20', 404, 52.50, 1, '30%', 0, 1),
(1005, 'online', '2025-04-05', 405, 49.50, 1, '10%', 1, 0),
(1006, 'retail', '2025-04-12', 406, 68.00, 2, '20%', 1, 0),
(1007, 'retail', '2025-04-25', 407, 35.00, 1, '0%', 0, 0),
(1008, 'online', '2025-05-03', 408, 60.00, 1, '0%', 0, 0),
(1009, 'retail', '2025-05-10', 409, 105.00, 1, '30%', 0, 1),
(1010, 'retail', '2025-06-01', 410, 76.00, 1, '20%', 1, 0),
(1011, 'retail', '2025-06-15', 402, 59.90, 3, '0%', 0, 0),
(1012, 'online', '2025-07-02', 403, 108.00, 1, '10%', 1, 0),
(1013, 'retail', '2025-07-18', 408, 48.00, 2, '20%', 1, 0),
(1014, 'online', '2025-08-05', 406, 59.50, 1, '30%', 0, 1),
(1015, 'retail', '2025-09-10', 409, 135.00, 1, '10%', 1, 0);
--e così via (minimo 150 tuple)

INSERT INTO SCONTRINO (ID, IDPUNTOVENDITA, IDVENDITA) VALUES
(1201, 801, 1001),
(1202, 802, 1002),
(1203, 803, 1004),
(1204, 804, 1005),
(1205, 805, 1006),
(1206, 806, 1007),
(1207, 807, 1009),
(1208, 808, 1010),
(1209, 809, 1011),
(1210, 810, 1013);

INSERT INTO ORDINE (ID, IDVENDITA, IDCLIENTE) VALUES
(1401, 1001, 601),
(1402, 1002, 602),
(1403, 1003, 603),
(1404, 1004, 604),
(1405, 1005, 605),
(1406, 1006, 606),
(1407, 1007, 607),
(1408, 1008, 608),
(1409, 1009, 609),
(1410, 1010, 610);



--SELECTS:

SELECT * FROM PROVINCIA;
SELECT * FROM CATEGORIA;
SELECT * FROM PRODOTTO;
SELECT * FROM CLIENTE;
SELECT * FROM PUNTOVENDITA;
SELECT * FROM VENDITA;
SELECT * FROM SCONTRINO;
SELECT * FROM ORDINE;
