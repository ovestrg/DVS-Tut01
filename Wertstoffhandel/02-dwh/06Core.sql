-- Data Warehouse, Schicht 2: Core
-- Aufgabe: Daten beider Quellsysteme zusammenfuehren und bereinigen
-- künstliche Schlüssel in business Schicht

CREATE SCHEMA IF NOT EXISTS core;

DROP TABLE IF EXISTS core.dim_zeit, core.dim_standort, core.dim_material,
                     core.dim_kunde, core.dim_anlage,
                     core.top_ankauf, core.top_verwertung CASCADE;

-- Dimensionen
CREATE TABLE core.dim_zeit (
    datum          DATE PRIMARY KEY,
    jahr           SMALLINT NOT NULL,
    monat          SMALLINT NOT NULL,
    monat_bez      CHAR(7)  NOT NULL,
    monatsname     VARCHAR(10) NOT NULL,
    kalenderwoche  SMALLINT NOT NULL,
    wochentag      SMALLINT NOT NULL,
    wochentagsname VARCHAR(12) NOT NULL);

CREATE TABLE core.dim_standort (
    standortcode CHAR(3) PRIMARY KEY,
    bezeichnung  VARCHAR(60) NOT NULL,
    standorttyp  VARCHAR(10) NOT NULL,
    plz          CHAR(5),
    ort          VARCHAR(60));

-- Bezeichnung und Kategorie stammen aus System 1,
-- der Verwertungsweg aus System 2. Verbunden ueber den Materialcode.
CREATE TABLE core.dim_material (
    materialcode   VARCHAR(10) PRIMARY KEY,
    bezeichnung    VARCHAR(60) NOT NULL,
    kategorie      VARCHAR(20) NOT NULL,
    verwertungsweg VARCHAR(30));

CREATE TABLE core.dim_kunde (
    kundennummer VARCHAR(12) PRIMARY KEY,
    name         VARCHAR(80) NOT NULL,
    kundentyp    VARCHAR(12) NOT NULL,
    ort          VARCHAR(60),
    kunde_seit   DATE);

CREATE TABLE core.dim_anlage (
    anlagenname    VARCHAR(60) PRIMARY KEY,
    anlagentyp     VARCHAR(20) NOT NULL,
    kapazitaet_t_h NUMERIC(6,2) NOT NULL,
    betriebsstatus VARCHAR(12) NOT NULL);

-- Topic-Tabelle Fragestellung 1: Ankauf
CREATE TABLE core.top_ankauf (
    position_nr    INTEGER PRIMARY KEY,
    anlieferdatum  DATE NOT NULL,
    standortcode   CHAR(3) NOT NULL,
    materialcode   VARCHAR(10) NOT NULL,
    kundennummer   VARCHAR(12) NOT NULL,
    menge_kg       NUMERIC(10,1) NOT NULL,
    preis_je_t     NUMERIC(10,2) NOT NULL,
    ankaufswert_eur NUMERIC(10,2) NOT NULL);

-- Topic-Tabelle Fragestellung 2: Verwertung
-- Eine Zeile je Ausbeuteposition. Einsatzmenge und Reststoff gehoeren zur
-- Charge und stehen deshalb nur in der ersten Zeile einer Charge, sonst 0.
-- Sonst wuerden sie bei Mischschrott mehrfach gezaehlt.
CREATE TABLE core.top_verwertung (
    ausbeute_nr      INTEGER PRIMARY KEY,
    sortierdatum     DATE NOT NULL,
    standortcode     CHAR(3) NOT NULL,
    materialcode     VARCHAR(10) NOT NULL,
    anlagenname      VARCHAR(60) NOT NULL,
    chargennummer    VARCHAR(16) NOT NULL,
    einsatzmenge_kg  NUMERIC(10,1) NOT NULL,
    ausbeute_kg      NUMERIC(10,1) NOT NULL,
    reststoff_kg     NUMERIC(10,1) NOT NULL);

-- Beladung
CREATE OR REPLACE PROCEDURE core.p_load_all()
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM core.top_ankauf;
    DELETE FROM core.top_verwertung;
    DELETE FROM core.dim_zeit;
    DELETE FROM core.dim_standort;
    DELETE FROM core.dim_material;
    DELETE FROM core.dim_kunde;
    DELETE FROM core.dim_anlage;

    -- Zeitdimension wird erzeugt, sie stammt aus keinem Quellsystem
    INSERT INTO core.dim_zeit
    SELECT d::date,
           EXTRACT(YEAR  FROM d)::smallint,
           EXTRACT(MONTH FROM d)::smallint,
           to_char(d,'YYYY-MM'),
           trim(to_char(d,'TMMonth')),
           EXTRACT(WEEK  FROM d)::smallint,
           EXTRACT(ISODOW FROM d)::smallint,
           trim(to_char(d,'TMDay'))
    FROM   generate_series(DATE '2025-10-01', DATE '2026-01-31', INTERVAL '1 day') d;

    INSERT INTO core.dim_standort
    SELECT standortcode, bezeichnung, standorttyp, plz, ort
    FROM   stage.an_standort;

    -- Zusammenfuehrung beider Systeme ueber den Materialcode
    INSERT INTO core.dim_material
    SELECT m.materialcode, m.bezeichnung, m.kategorie, s.verwertungsweg
    FROM   stage.an_materialart m
    LEFT   JOIN stage.vw_stoffgruppe s ON s.materialcode = m.materialcode;

    INSERT INTO core.dim_kunde
    SELECT kundennummer, name, kundentyp, ort, registriert_am
    FROM   stage.an_kunde;

    INSERT INTO core.dim_anlage
    SELECT bezeichnung, anlagentyp, kapazitaet_t_h, betriebsstatus
    FROM   stage.vw_sortieranlage;

    -- Topic 1: eine Zeile je Anlieferungsposition
    INSERT INTO core.top_ankauf
    SELECT p.position_id,
           a.anlieferdatum,
           s.standortcode,
           m.materialcode,
           k.kundennummer,
           p.menge_kg,
           p.preis_je_t,
           p.betrag_eur
    FROM   stage.an_anlieferungsposition p
    JOIN   stage.an_anlieferung a ON a.anlieferung_id = p.anlieferung_id
    JOIN   stage.an_standort    s ON s.standort_id    = a.standort_id
    JOIN   stage.an_kunde       k ON k.kunden_id      = a.kunden_id
    JOIN   stage.an_materialart m ON m.materialart_id = p.materialart_id;

    -- Topic 2: eine Zeile je Ausbeuteposition
    INSERT INTO core.top_verwertung
    SELECT x.ausbeute_id,
           x.beginn_ts::date,
           x.herkunft_standortcode,
           x.materialcode,
           x.anlagenname,
           x.chargennummer,
           CASE WHEN x.erste = 1 THEN x.einsatzmenge_kg ELSE 0 END,
           x.menge_kg,
           CASE WHEN x.erste = 1 THEN COALESCE(x.reststoff_kg,0) ELSE 0 END
    FROM  (SELECT ap.ausbeute_id, ap.menge_kg, sv.beginn_ts,
                  w.herkunft_standortcode, sg.materialcode,
                  an.bezeichnung AS anlagenname,
                  c.chargennummer, c.einsatzmenge_kg, r.reststoff_kg,
                  row_number() OVER (PARTITION BY c.charge_id
                                     ORDER BY ap.ausbeute_id) AS erste
           FROM   stage.vw_ausbeuteposition ap
           JOIN   stage.vw_sortiervorgang   sv ON sv.sortiervorgang_id = ap.sortiervorgang_id
           JOIN   stage.vw_charge           c  ON c.charge_id          = sv.charge_id
           JOIN   stage.vw_werksanlieferung w  ON w.werksanlieferung_id = c.werksanlieferung_id
           JOIN   stage.vw_stoffgruppe      sg ON sg.stoffgruppe_id    = ap.stoffgruppe_id
           JOIN   stage.vw_sortieranlage    an ON an.anlage_id         = sv.anlage_id
           LEFT   JOIN (SELECT sortiervorgang_id, SUM(menge_kg) AS reststoff_kg
                        FROM   stage.vw_reststoff GROUP BY 1) r
                  ON r.sortiervorgang_id = sv.sortiervorgang_id) x;
END;
$$;

CALL core.p_load_all();
