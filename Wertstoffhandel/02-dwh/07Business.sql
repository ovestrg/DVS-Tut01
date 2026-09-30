-- Data Warehouse, Schicht 3: Business
-- Aufgabe: zwei Star Schemas für die Auswertung
-- Die fachlichen Schlüssel werden durch künstliche Schluessel ersetzt.

CREATE SCHEMA IF NOT EXISTS business;

DROP TABLE IF EXISTS business.fakt_ankauf, business.fakt_verwertung,
                     business.dim_zeit, business.dim_standort,
                     business.dim_material, business.dim_kunde,
                     business.dim_anlage CASCADE;

-- Dimensionen, jede davon hat eigenen küsntlicchen Schlüssel
-- fachlichen Schlüssel für Rücksprung zum Quellsystem
CREATE TABLE business.dim_zeit (
    zeit_sk        INTEGER PRIMARY KEY,
    datum          DATE NOT NULL UNIQUE,
    jahr           SMALLINT NOT NULL,
    monat          SMALLINT NOT NULL,
    monat_bez      CHAR(7) NOT NULL,
    monatsname     VARCHAR(10) NOT NULL,
    kalenderwoche  SMALLINT NOT NULL,
    wochentagsname VARCHAR(12) NOT NULL);

CREATE TABLE business.dim_standort (
    standort_sk  INTEGER PRIMARY KEY,
    standortcode CHAR(3) NOT NULL,
    bezeichnung  VARCHAR(60) NOT NULL,
    standorttyp  VARCHAR(10) NOT NULL,
    ort          VARCHAR(60));

CREATE TABLE business.dim_material (
    material_sk    INTEGER PRIMARY KEY,
    materialcode   VARCHAR(10) NOT NULL,
    bezeichnung    VARCHAR(60) NOT NULL,
    kategorie      VARCHAR(20) NOT NULL,
    verwertungsweg VARCHAR(30));

CREATE TABLE business.dim_kunde (
    kunde_sk     INTEGER PRIMARY KEY,
    kundennummer VARCHAR(12) NOT NULL,
    name         VARCHAR(80) NOT NULL,
    kundentyp    VARCHAR(12) NOT NULL,
    ort          VARCHAR(60));

CREATE TABLE business.dim_anlage (
    anlage_sk      INTEGER PRIMARY KEY,
    anlagenname    VARCHAR(60) NOT NULL,
    anlagentyp     VARCHAR(20) NOT NULL,
    kapazitaet_t_h NUMERIC(6,2) NOT NULL);

-- Faktentabelle 1: Ankauf
CREATE TABLE business.fakt_ankauf (
    position_nr     INTEGER PRIMARY KEY,
    zeit_sk         INTEGER NOT NULL REFERENCES business.dim_zeit(zeit_sk),
    standort_sk     INTEGER NOT NULL REFERENCES business.dim_standort(standort_sk),
    material_sk     INTEGER NOT NULL REFERENCES business.dim_material(material_sk),
    kunde_sk        INTEGER NOT NULL REFERENCES business.dim_kunde(kunde_sk),
    menge_kg        NUMERIC(10,1) NOT NULL,
    preis_je_t      NUMERIC(10,2) NOT NULL,
    ankaufswert_eur NUMERIC(10,2) NOT NULL);

-- Faktentabelle 2: Verwertung
CREATE TABLE business.fakt_verwertung (
    ausbeute_nr     INTEGER PRIMARY KEY,
    zeit_sk         INTEGER NOT NULL REFERENCES business.dim_zeit(zeit_sk),
    standort_sk     INTEGER NOT NULL REFERENCES business.dim_standort(standort_sk),
    material_sk     INTEGER NOT NULL REFERENCES business.dim_material(material_sk),
    anlage_sk       INTEGER NOT NULL REFERENCES business.dim_anlage(anlage_sk),
    chargennummer   VARCHAR(16) NOT NULL,
    einsatzmenge_kg NUMERIC(10,1) NOT NULL,
    ausbeute_kg     NUMERIC(10,1) NOT NULL,
    reststoff_kg    NUMERIC(10,1) NOT NULL);

-- Beladung
CREATE OR REPLACE PROCEDURE business.p_load_all()
LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM business.fakt_ankauf;
    DELETE FROM business.fakt_verwertung;
    DELETE FROM business.dim_zeit;
    DELETE FROM business.dim_standort;
    DELETE FROM business.dim_material;
    DELETE FROM business.dim_kunde;
    DELETE FROM business.dim_anlage;

    -- Zeitschlüsssel, die übrigen sind fortlaufend nummeriert
    INSERT INTO business.dim_zeit
    SELECT to_char(datum,'YYYYMMDD')::int, datum, jahr, monat, monat_bez,
           monatsname, kalenderwoche, wochentagsname
    FROM   core.dim_zeit;

    INSERT INTO business.dim_standort
    SELECT row_number() OVER (ORDER BY standortcode)::int,
           standortcode, bezeichnung, standorttyp, ort
    FROM   core.dim_standort;

    INSERT INTO business.dim_material
    SELECT row_number() OVER (ORDER BY materialcode)::int,
           materialcode, bezeichnung, kategorie, verwertungsweg
    FROM   core.dim_material;

    INSERT INTO business.dim_kunde
    SELECT row_number() OVER (ORDER BY kundennummer)::int,
           kundennummer, name, kundentyp, ort
    FROM   core.dim_kunde;

    INSERT INTO business.dim_anlage
    SELECT row_number() OVER (ORDER BY anlagenname)::int,
           anlagenname, anlagentyp, kapazitaet_t_h
    FROM   core.dim_anlage;

    -- Fakten: die fachlichen Schlüssel werden gegen die künstlichen Schlüssel getauscht
    INSERT INTO business.fakt_ankauf
    SELECT t.position_nr, z.zeit_sk, s.standort_sk, m.material_sk, k.kunde_sk,
           t.menge_kg, t.preis_je_t, t.ankaufswert_eur
    FROM   core.top_ankauf t
    JOIN   business.dim_zeit     z ON z.datum        = t.anlieferdatum
    JOIN   business.dim_standort s ON s.standortcode = t.standortcode
    JOIN   business.dim_material m ON m.materialcode = t.materialcode
    JOIN   business.dim_kunde    k ON k.kundennummer = t.kundennummer;

    INSERT INTO business.fakt_verwertung
    SELECT t.ausbeute_nr, z.zeit_sk, s.standort_sk, m.material_sk, a.anlage_sk,
           t.chargennummer, t.einsatzmenge_kg, t.ausbeute_kg, t.reststoff_kg
    FROM   core.top_verwertung t
    JOIN   business.dim_zeit     z ON z.datum        = t.sortierdatum
    JOIN   business.dim_standort s ON s.standortcode = t.standortcode
    JOIN   business.dim_material m ON m.materialcode = t.materialcode
    JOIN   business.dim_anlage   a ON a.anlagenname  = t.anlagenname;
END;
$$;

CALL business.p_load_all();
