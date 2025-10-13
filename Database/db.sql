DROP TABLE IF EXISTS PRODOTTOVENDUTO;
DROP TABLE IF EXISTS ORDINE;
DROP TABLE IF EXISTS SCONTRINO;
DROP TABLE IF EXISTS PUNTOVENDITA;
DROP TABLE IF EXISTS CLIENTE;
DROP TABLE IF EXISTS PRODOTTO;
DROP TABLE IF EXISTS CATEGORIA;
DROP TABLE IF EXISTS PROVINCIA;

USE Z_GLAM;

--TABELLE:
CREATE TABLE PROVINCIA ( 
    IDPROVINCIA INT IDENTITY(1,1) PRIMARY KEY, --motivo: se db esteso all'estero NOME non può fare da chiave primaria (es: Parma USA e Parma IT)

    NOMEPROVINCIA VARCHAR(50) NOT NULL,
    REGIONE VARCHAR(50) NOT NULL
);

CREATE TABLE CATEGORIA ( 
    IDCATEGORIA INT IDENTITY(100,1) PRIMARY KEY, --max 100 categorie

    NOMECATEGORIA VARCHAR(50) NOT NULL,

    SESSO VARCHAR(6) NOT NULL,
    CHECK (SESSO IN ('uomo', 'donna', 'unisex')),

    CATEGORIAMERCEOLOGICA VARCHAR(50) NOT NULL
);

CREATE TABLE PRODOTTO (
    IDPRODOTTO INT IDENTITY(200,1) PRIMARY KEY, --max 100 prodotti

    NOMEPRODOTTO VARCHAR(50) NOT NULL,
    
    MARCHIO VARCHAR(50) NOT NULL,

    PREZZOBASE DECIMAL(10,2) NOT NULL,
        CHECK (PREZZOBASE > 0),

    IDCATEGORIA INT NOT NULL, 

    FOREIGN KEY (IDCATEGORIA) REFERENCES CATEGORIA(IDCATEGORIA)
);

CREATE TABLE CLIENTE (
    IDCLIENTE INT IDENTITY(300,1) PRIMARY KEY, ----max 100 clienti

    IDPROVINCIA INT NOT NULL,

    TESSERAFEDELTA BIT NOT NULL, 

    FOREIGN KEY (IDPROVINCIA) REFERENCES PROVINCIA(IDPROVINCIA)
);

CREATE TABLE PUNTOVENDITA ( --i punti vendita sono 10: 2 a Milano, 2 a Lodi, 1 a Padova, 1 a Venezia, 1 a Genova, 1 a Bologna, 1 a Roma e 1 a Napoli 
    IDPUNTOVENDITA INT IDENTITY(400,1) PRIMARY KEY, 

    IDPROVINCIA INT NOT NULL, 
        --TODO: deve essere realtivo a una provincia tra Milano, Lodi, Padova, Venezia, Genova, Bologna, Roma e Napoli (provincie dei punti vendita)

    INDIRIZZO VARCHAR(50) NOT NULL, 
        --CHECK ((INDIRIZZO LIKE 'via %, %, _____') OR (INDIRIZZO LIKE 'strada %, %, _____') OR (INDIRIZZO LIKE 'corso %, %, _____')),

    FOREIGN KEY (IDPROVINCIA) REFERENCES PROVINCIA(IDPROVINCIA)
);


CREATE TABLE SCONTRINO ( --minimo 75 tuple (massimo 100)
    IDSCONTRINO INT IDENTITY(500,1) PRIMARY KEY,

    IDPUNTOVENDITA INT NOT NULL,

    TESSERAFEDELTA BIT NOT NULL,

    CODICESCONTO BIT NOT NULL, --dovrebbe essere un coupon

    DATADIVENDITA DATE NOT NULL,
        CHECK (DATADIVENDITA BETWEEN '20250101' AND '20250930'),

    FOREIGN KEY (IDPUNTOVENDITA) REFERENCES PUNTOVENDITA(IDPUNTOVENDITA)
);

CREATE TABLE ORDINE ( --minimo 75 tuple (massimo 100)
    IDORDINE INT IDENTITY(600,1) PRIMARY KEY,

    IDCLIENTE INT NOT NULL,

    CODICESCONTO BIT NOT NULL,

    DATADIVENDITA DATE NOT NULL,
        CHECK (DATADIVENDITA BETWEEN '20250101' AND '20250930'),

    FOREIGN KEY (IDCLIENTE) REFERENCES CLIENTE(IDCLIENTE)
);

--numero di tuple di scontrino + numero di tuple di ordine <= 150

CREATE TABLE PRODOTTOVENDUTO ( --ciascuna tupla relativa alla vendita di un SINGOLO prodotto, conteremo il numero di prodotti venduti in una vendita con COUNT
    IDPRODOTTOVENDUTO INT IDENTITY(700,1) PRIMARY KEY,
    
    TIPO VARCHAR(50) NOT NULL, 
        CHECK (TIPO IN ('retail', 'online')),

    IDSCONTRINO INT, 

    IDORDINE INT,

    CHECK (
        (TIPO = 'retail' AND IDSCONTRINO IS NOT NULL AND IDORDINE IS NULL)
        OR
        (TIPO = 'online' AND IDORDINE IS NOT NULL AND IDSCONTRINO IS NULL)
    ),

    IDPRODOTTO INT NOT NULL,
   
    PREZZOSCONTATO DECIMAL(10,2) NOT NULL, --CALCOLATO E NON IMPOSTABILE (SERVE TRIGGER) (TODO)
    
    SCONTO INT NOT NULL, --CALCOLATO E NON IMPOSTABILE (SERVE TRIGGER) (TODO)
        CHECK (SCONTO IN (0, 10, 20, 30)),

    FOREIGN KEY (IDSCONTRINO) REFERENCES SCONTRINO(IDSCONTRINO),
    FOREIGN KEY (IDORDINE) REFERENCES ORDINE(IDORDINE),
    FOREIGN KEY (IDPRODOTTO) REFERENCES PRODOTTO(IDPRODOTTO)
);



--INSERTS:

INSERT INTO PROVINCIA (NOMEPROVINCIA, REGIONE) VALUES
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

INSERT INTO CATEGORIA (NOMECATEGORIA, SESSO, CATEGORIAMERCEOLOGICA) VALUES
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

INSERT INTO PRODOTTO (NOMEPRODOTTO, MARCHIO, PREZZOBASE, IDCATEGORIA) VALUES
    ('Slim Cargo Pant', 'G-Star', 85.00, 100),
    ('Slim Fit Cargo', 'G-Star', 87.00, 100),
    ('Denim Slim Jeans', 'Levi''s', 92.50, 101),
    ('Slim Fit Jeans Dark', 'Diesel', 89.50, 101),
    ('Denim Slim Jeans Dark', 'Diesel', 95.00, 101),
    ('Basic Cotton T-Shirt', 'H&M', 19.99, 102),
    ('Basic Tee Crew', 'Zara', 22.99, 102),
    ('Basic Tee Round', 'Zara', 25.00, 102),
    ('Striped Casual Shirt', 'Zara', 49.99, 103),
    ('Checked Shirt Slim', 'H&M', 49.99, 103),
    ('Checked Shirt Casual', 'H&M', 52.00, 103),
    ('Hooded Sweatshirt', 'Nike', 59.99, 104),
    ('Hooded Sweatshirt Zip', 'Nike', 65.00, 104),
    ('Hooded Sweatshirt Pullover', 'Nike', 68.00, 104),
    ('Leather Biker Jacket', 'Guess', 249.99, 105),
    ('Leather Jacket Moto', 'Guess', 259.99, 105),
    ('Leather Biker Jacket Black', 'Guess', 270.00, 105),
    ('Sport Shorts Mesh', 'Adidas', 35.00, 106),
    ('Mesh Sport Shorts', 'Puma', 38.00, 106),
    ('Sport Shorts Running', 'Adidas', 40.00, 106),
    ('Tracksuit Essentials', 'Puma', 99.99, 107),
    ('Tracksuit Hoodie', 'Adidas', 99.99, 107),
    ('Tracksuit Set', 'Puma', 102.00, 107),
    ('Cotton Polo Shirt', 'Ralph Lauren', 69.99, 108),
    ('Classic Polo Cotton', 'Ralph Lauren', 72.99, 108),
    ('Cotton Polo Classic', 'Ralph Lauren', 75.00, 108),
    ('Running Sneakers', 'Asics', 120.00, 109),
    ('Sneakers Everyday', 'Asics', 118.00, 109),
    ('Sneakers Running', 'New Balance', 115.00, 109),
    ('Floral Summer Dress', 'Mango', 79.99, 110),
    ('Maxi Floral Dress', 'Mango', 85.00, 110),
    ('Leather Jacket Retro', 'Michael Kors', 310.00, 113),
    ('Flared Pants Chic', 'H&M', 59.99, 114),
    ('Flared Pants High Waist', 'H&M', 60.00, 114),
    ('Sport Leggings', 'Adidas', 45.00, 115),
    ('Leggings Gym', 'Nike', 48.50, 115),
    ('Cropped Hoodie', 'Nike', 55.00, 116),
    ('Cropped Hoodie Print', 'Champion', 58.00, 116),
    ('Platform Sneakers', 'Buffalo', 130.00, 117),
    ('Platform Sneakers Black', 'Buffalo', 135.00, 117),
    ('Crossbody Bag', 'Michael Kors', 149.99, 118),
    ('Mini Crossbody Bag', 'Michael Kors', 155.00, 118),
    ('Elegant Evening Dress', 'Zara', 129.99, 119),
    ('Cocktail Dress', 'Zara', 139.99, 119),
    ('Oversize T-Shirt Logo', 'Champion', 39.99, 120),
    ('Oversize Graphic Tee', 'Adidas', 42.00, 120),
    ('Minimal Hoodie', 'Uniqlo', 49.99, 121),
    ('Minimal Hoodie Zip', 'Uniqlo', 52.00, 121),
    ('Urban Cargo Pants', 'Carhartt', 92.00, 122),
    ('Classic Sneakers Black', 'Nike', 115.00, 123),
    ('Cotton Tracksuit', 'Puma', 95.00, 125),
    ('Tracksuit Cotton', 'Puma', 98.00, 125),
    ('Urban Backpack', 'Eastpak', 69.99, 126),
    ('Cotton Sweater Crew', 'H&M', 59.99, 127),
    ('Crew Neck Sweater', 'H&M', 61.00, 127),
    ('Windbreaker Jacket', 'Columbia', 120.00, 128),
    ('Windbreaker Jacket Hood', 'Columbia', 125.00, 128),
    ('Leather Belt', 'Gucci', 199.99, 129),
    ('Leather Belt Classic', 'Gucci', 205.00, 129),
    ('Leather Belt Signature', 'Gucci', 205.00, 129);

INSERT INTO CLIENTE (IDPROVINCIA, TESSERAFEDELTA) VALUES
    (61, 1),
    (55, 0),
    (78, 1),
    (12, 0),
    (92, 1),
    (34, 0),
    (7, 1),
    (50, 0),
    (19, 1),
    (81, 1),
    (3, 0),
    (44, 1),
    (68, 0),
    (27, 1),
    (101, 1),
    (14, 0),
    (88, 1),
    (6, 0),
    (72, 1),
    (33, 0),
    (17, 1),
    (90, 1),
    (24, 0),
    (59, 1),
    (40, 0),
    (2, 1),
    (85, 1),
    (13, 0),
    (48, 1),
    (100, 0),
    (31, 1),
    (64, 1),
    (21, 0),
    (95, 1),
    (10, 0),
    (77, 1),
    (41, 1),
    (22, 0),
    (84, 1),
    (37, 0),
    (52, 1),
    (8, 1),
    (73, 0),
    (29, 1),
    (98, 0),
    (5, 1),
    (66, 1),
    (36, 0),
    (93, 1),
    (25, 0);

INSERT INTO PUNTOVENDITA (IDPROVINCIA, INDIRIZZO) VALUES
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

INSERT INTO SCONTRINO (IDPUNTOVENDITA, TESSERAFEDELTA, CODICESCONTO, DATADIVENDITA) VALUES 
    (400, 1, 0, '20250203'),
    (400, 0, 1, '20250304'),
    (400, 0, 0, '20250412'),
    (400, 1, 1, '20250522'),
    (400, 0, 0, '20250615'),
    (400, 1, 1, '20250708'),
    (400, 1, 0, '20250819'),
    (400, 0, 1, '20250901'),
    (401, 1, 1, '20250115'),
    (401, 0, 0, '20250228'),
    (401, 1, 0, '20250316'),
    (401, 0, 1, '20250407'),
    (401, 0, 1, '20250512'),
    (401, 1, 0, '20250625'),
    (402, 1, 0, '20250703'),
    (402, 0, 1, '20250811'),
    (402, 0, 0, '20250906'),
    (402, 1, 1, '20250122'),
    (402, 1, 1, '20250218'),
    (402, 0, 0, '20250329'),
    (402, 0, 1, '20250414'),
    (402, 1, 0, '20250530'),
    (403, 0, 0, '20250608'),
    (403, 1, 1, '20250719'),
    (403, 1, 0, '20250827'),
    (403, 0, 1, '20250910'),
    (403, 1, 0, '20250103'),
    (403, 0, 1, '20250212'),
    (403, 1, 1, '20250323'),
    (403, 1, 1, '20250423'),
    (403, 0, 0, '20250430'),
    (404, 1, 0, '20250514'),
    (404, 0, 1, '20250621'),
    (404, 0, 0, '20250704'),
    (404, 1, 1, '20250815'),
    (404, 1, 1, '20250926'),
    (404, 0, 0, '20250118'),
    (404, 1, 0, '20250107'),
    (404, 0, 1, '20250816'),
    (404, 1, 1, '20250301'),
    (405, 0, 0, '20250207'),
    (405, 1, 1, '20250311'),
    (405, 1, 0, '20250419'),
    (405, 0, 1, '20250527'),
    (405, 0, 1, '20250612'),
    (405, 1, 0, '20250723'),
    (405, 1, 1, '20250829'),
    (405, 0, 0, '20250905'),
    (406, 1, 0, '20250109'),
    (406, 0, 1, '20250220'),
    (406, 0, 0, '20250330'),
    (406, 1, 1, '20250416'),
    (406, 1, 1, '20250419'),
    (406, 1, 1, '20250524'),
    (406, 0, 0, '20250618'),
    (406, 0, 1, '20250727'),
    (406, 1, 0, '20250809'),
    (407, 0, 0, '20250915'),
    (407, 1, 1, '20250104'),
    (407, 1, 0, '20250217'),
    (407, 0, 1, '20250325'),
    (407, 0, 1, '20250405'),
    (407, 1, 0, '20250509'),
    (407, 0, 0, '20250502'),
    (407, 1, 1, '20250209'),
    (407, 1, 1, '20250622'),
    (408, 1, 0, '20250711'),
    (408, 0, 1, '20250803'),
    (408, 0, 0, '20250921'),
    (408, 1, 1, '20250129'),
    (408, 1, 1, '20250213'),
    (408, 0, 0, '20250308'),
    (409, 0, 0, '20250420'),
    (409, 1, 1, '20250506'),
    (409, 1, 0, '20250613'),
    (409, 0, 1, '20250731'),
    (409, 0, 1, '20250818'),
    (409, 1, 0, '20250902'),
    (409, 0, 1, '20250121'),
    (409, 1, 0, '20250226');

INSERT INTO ORDINE (IDCLIENTE, CODICESCONTO, DATADIVENDITA) VALUES 
    (300, 0, '20250818'),
    (301, 0, '20250512'),
    (302, 1, '20250403'),
    (303, 1, '20250722'),
    (303, 0, '20250621'),
    (304, 0, '20250901'),
    (305, 0, '20250614'),
    (305, 1, '20250620'),
    (306, 1, '20250805'),
    (307, 0, '20250718'),
    (307, 1, '20250725'),
    (308, 1, '20250530'),
    (308, 1, '20250326'),
    (308, 1, '20250210'),
    (308, 1, '20250110'),
    (309, 1, '20250607'),
    (310, 0, '20250415'),
    (310, 1, '20250422'),
    (311, 0, '20250702'),
    (311, 1, '20250710'),
    (312, 0, '20250508'),
    (312, 1, '20250515'),
    (313, 0, '20250905'),
    (314, 0, '20250812'),
    (315, 0, '20250328'),
    (315, 1, '20250330'),
    (316, 0, '20250912'),
    (316, 1, '20250918'),
    (317, 1, '20250625'),
    (317, 1, '20250627'),
    (318, 1, '20250714'),
    (319, 0, '20250505'),
    (319, 1, '20250510'),
    (320, 0, '20250408'),
    (320, 1, '20250412'),
    (321, 0, '20250903'),
    (321, 1, '20250907'),
    (321, 0, '20250910'),
    (322, 0, '20250802'),
    (322, 1, '20250806'),
    (322, 0, '20250809'),
    (323, 1, '20250728'),
    (324, 1, '20250525'),
    (325, 0, '20250430'),
    (326, 0, '20250915'),
    (327, 0, '20250601'),
    (328, 0, '20250325'),
    (328, 0, '20250327'),
    (329, 0, '20250708'),
    (330, 0, '20250617'),
    (330, 0, '20250716'),
    (331, 0, '20250920'),
    (332, 0, '20250418'),
    (333, 0, '20250705'),
    (333, 1, '20250706'),
    (333, 1, '20250707'),
    (334, 0, '20250814'),
    (334, 1, '20250816'),
    (335, 0, '20250908'),
    (335, 1, '20250909'),
    (336, 0, '20250502'),
    (337, 1, '20250425'),
    (337, 1, '20250427'),
    (338, 1, '20250630'),
    (339, 1, '20250712'),
    (340, 0, '20250928'),
    (341, 0, '20250929'),
    (342, 0, '20250612'),
    (342, 0, '20250613'),
    (343, 0, '20250518'),
    (343, 1, '20250519'),
    (344, 0, '20250405'),
    (345, 1, '20250822'),
    (345, 1, '20250823'),
    (346, 0, '20250716'),
    (346, 0, '20250717'),
    (346, 1, '20250718'),
    (347, 0, '20250331'),
    (348, 0, '20250911'),
    (349, 1, '20250514');

    
--FARE L'INSERT DI 400 TUPLE IN PRODOTTOVENDUTO



--SELECTS:

SELECT * FROM PROVINCIA;
SELECT * FROM CATEGORIA;
SELECT * FROM PRODOTTO;
SELECT * FROM CLIENTE;
SELECT * FROM PUNTOVENDITA;
SELECT * FROM SCONTRINO;
SELECT * FROM ORDINE;
SELECT * FROM PRODOTTOVENDUTO;



--QUERY:
