-- Data Warehouse, Schicht 1: Staging
-- Datenbank: dwh
-- Aufgabe: unveraenderte Kopie der benoetigten Quelltabellen

CREATE SCHEMA IF NOT EXISTS stage;

-- Zugriff auf die beiden Quelldatenbanken
-- postgres_fdw blendet fremde Tabellen so ein, als laegen sie hier.
CREATE EXTENSION IF NOT EXISTS postgres_fdw;

DROP SERVER IF EXISTS srv_annahme CASCADE;
DROP SERVER IF EXISTS srv_verwertung CASCADE;

CREATE SERVER srv_annahme FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'annahme');
CREATE SERVER srv_verwertung FOREIGN DATA WRAPPER postgres_fdw
    OPTIONS (host 'localhost', port '5432', dbname 'verwertung');

CREATE USER MAPPING FOR CURRENT_USER SERVER srv_annahme    OPTIONS (user 'postgres');
CREATE USER MAPPING FOR CURRENT_USER SERVER srv_verwertung OPTIONS (user 'postgres');

-- Die Quelltabellen werden in eigene Schemata eingeblendet
DROP SCHEMA IF EXISTS src_annahme CASCADE;
DROP SCHEMA IF EXISTS src_verwertung CASCADE;
CREATE SCHEMA src_annahme;
CREATE SCHEMA src_verwertung;

IMPORT FOREIGN SCHEMA public
    LIMIT TO (standort, kunde, materialart, anlieferung, anlieferungsposition)
    FROM SERVER srv_annahme INTO src_annahme;

IMPORT FOREIGN SCHEMA public
    LIMIT TO (stoffgruppe, sortieranlage, werksanlieferung, charge,
              sortiervorgang, ausbeuteposition, reststoff)
    FROM SERVER srv_verwertung INTO src_verwertung;

-- Staging-Tabellen
-- Namen: an_ fuer das Annahmesystem, vw_ fuer das Verwertungssystem
DROP TABLE IF EXISTS stage.an_standort, stage.an_kunde, stage.an_materialart,
                     stage.an_anlieferung, stage.an_anlieferungsposition,
                     stage.vw_stoffgruppe, stage.vw_sortieranlage,
                     stage.vw_werksanlieferung, stage.vw_charge,
                     stage.vw_sortiervorgang, stage.vw_ausbeuteposition,
                     stage.vw_reststoff CASCADE;

CREATE TABLE stage.an_standort (
    standort_id INTEGER, standortcode CHAR(3), bezeichnung VARCHAR(60),
    standorttyp VARCHAR(10), plz CHAR(5), ort VARCHAR(60),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.an_kunde (
    kunden_id INTEGER, kundennummer VARCHAR(12), name VARCHAR(80),
    kundentyp VARCHAR(12), plz CHAR(5), ort VARCHAR(60), registriert_am DATE,
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.an_materialart (
    materialart_id INTEGER, materialcode VARCHAR(10), bezeichnung VARCHAR(60),
    kategorie VARCHAR(20),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.an_anlieferung (
    anlieferung_id INTEGER, kunden_id INTEGER, standort_id INTEGER,
    wiegescheinnr VARCHAR(16), anlieferdatum DATE,
    gewicht_brutto_kg NUMERIC(10,1), gewicht_tara_kg NUMERIC(10,1),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.an_anlieferungsposition (
    position_id INTEGER, anlieferung_id INTEGER, materialart_id INTEGER,
    menge_kg NUMERIC(10,1), preis_je_t NUMERIC(10,2), betrag_eur NUMERIC(10,2),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.vw_stoffgruppe (
    stoffgruppe_id INTEGER, materialcode VARCHAR(10), bezeichnung VARCHAR(60),
    verwertungsweg VARCHAR(30), zielreinheit_proz NUMERIC(5,2),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.vw_sortieranlage (
    anlage_id INTEGER, bezeichnung VARCHAR(60), anlagentyp VARCHAR(20),
    kapazitaet_t_h NUMERIC(6,2), betriebsstatus VARCHAR(12),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.vw_werksanlieferung (
    werksanlieferung_id INTEGER, stoffgruppe_id INTEGER,
    containernummer VARCHAR(16), herkunft_standortcode CHAR(3),
    ankunft_ts TIMESTAMP, menge_kg NUMERIC(10,1), frachtkosten NUMERIC(10,2),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.vw_charge (
    charge_id INTEGER, werksanlieferung_id INTEGER, stoffgruppe_id INTEGER,
    chargennummer VARCHAR(16), angelegt_ts TIMESTAMP,
    einsatzmenge_kg NUMERIC(10,1),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.vw_sortiervorgang (
    sortiervorgang_id INTEGER, charge_id INTEGER, anlage_id INTEGER,
    beginn_ts TIMESTAMP, ende_ts TIMESTAMP,
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.vw_ausbeuteposition (
    ausbeute_id INTEGER, sortiervorgang_id INTEGER, stoffgruppe_id INTEGER,
    menge_kg NUMERIC(10,1), reinheit_proz NUMERIC(5,2),
    dwh_ladezeit TIMESTAMP DEFAULT now());

CREATE TABLE stage.vw_reststoff (
    reststoff_id INTEGER, sortiervorgang_id INTEGER, menge_kg NUMERIC(10,1),
    entsorgungskosten_je_t NUMERIC(10,2),
    dwh_ladezeit TIMESTAMP DEFAULT now());

-- Beladung: alte Daten loeschen, dann komplett neu einlesen
CREATE OR REPLACE PROCEDURE stage.p_load_all()
LANGUAGE plpgsql AS $$
BEGIN
    TRUNCATE stage.an_standort, stage.an_kunde, stage.an_materialart,
             stage.an_anlieferung, stage.an_anlieferungsposition,
             stage.vw_stoffgruppe, stage.vw_sortieranlage,
             stage.vw_werksanlieferung, stage.vw_charge,
             stage.vw_sortiervorgang, stage.vw_ausbeuteposition,
             stage.vw_reststoff;

    INSERT INTO stage.an_standort (standort_id, standortcode, bezeichnung,
                                   standorttyp, plz, ort)
        SELECT standort_id, standortcode, bezeichnung, standorttyp, plz, ort
        FROM   src_annahme.standort;

    INSERT INTO stage.an_kunde (kunden_id, kundennummer, name, kundentyp,
                                plz, ort, registriert_am)
        SELECT kunden_id, kundennummer, name, kundentyp, plz, ort, registriert_am
        FROM   src_annahme.kunde;

    INSERT INTO stage.an_materialart (materialart_id, materialcode, bezeichnung,
                                      kategorie)
        SELECT materialart_id, materialcode, bezeichnung, kategorie
        FROM   src_annahme.materialart;

    INSERT INTO stage.an_anlieferung (anlieferung_id, kunden_id, standort_id,
                                      wiegescheinnr, anlieferdatum,
                                      gewicht_brutto_kg, gewicht_tara_kg)
        SELECT anlieferung_id, kunden_id, standort_id, wiegescheinnr,
               anlieferdatum, gewicht_brutto_kg, gewicht_tara_kg
        FROM   src_annahme.anlieferung;

    INSERT INTO stage.an_anlieferungsposition (position_id, anlieferung_id,
                                               materialart_id, menge_kg,
                                               preis_je_t, betrag_eur)
        SELECT position_id, anlieferung_id, materialart_id, menge_kg,
               preis_je_t, betrag_eur
        FROM   src_annahme.anlieferungsposition;

    INSERT INTO stage.vw_stoffgruppe (stoffgruppe_id, materialcode, bezeichnung,
                                      verwertungsweg, zielreinheit_proz)
        SELECT stoffgruppe_id, materialcode, bezeichnung, verwertungsweg,
               zielreinheit_proz
        FROM   src_verwertung.stoffgruppe;

    INSERT INTO stage.vw_sortieranlage (anlage_id, bezeichnung, anlagentyp,
                                        kapazitaet_t_h, betriebsstatus)
        SELECT anlage_id, bezeichnung, anlagentyp, kapazitaet_t_h, betriebsstatus
        FROM   src_verwertung.sortieranlage;

    INSERT INTO stage.vw_werksanlieferung (werksanlieferung_id, stoffgruppe_id,
                                           containernummer, herkunft_standortcode,
                                           ankunft_ts, menge_kg, frachtkosten)
        SELECT werksanlieferung_id, stoffgruppe_id, containernummer,
               herkunft_standortcode, ankunft_ts, menge_kg, frachtkosten
        FROM   src_verwertung.werksanlieferung;

    INSERT INTO stage.vw_charge (charge_id, werksanlieferung_id, stoffgruppe_id,
                                 chargennummer, angelegt_ts, einsatzmenge_kg)
        SELECT charge_id, werksanlieferung_id, stoffgruppe_id, chargennummer,
               angelegt_ts, einsatzmenge_kg
        FROM   src_verwertung.charge;

    INSERT INTO stage.vw_sortiervorgang (sortiervorgang_id, charge_id, anlage_id,
                                         beginn_ts, ende_ts)
        SELECT sortiervorgang_id, charge_id, anlage_id, beginn_ts, ende_ts
        FROM   src_verwertung.sortiervorgang;

    INSERT INTO stage.vw_ausbeuteposition (ausbeute_id, sortiervorgang_id,
                                           stoffgruppe_id, menge_kg, reinheit_proz)
        SELECT ausbeute_id, sortiervorgang_id, stoffgruppe_id, menge_kg,
               reinheit_proz
        FROM   src_verwertung.ausbeuteposition;

    INSERT INTO stage.vw_reststoff (reststoff_id, sortiervorgang_id, menge_kg,
                                    entsorgungskosten_je_t)
        SELECT reststoff_id, sortiervorgang_id, menge_kg, entsorgungskosten_je_t
        FROM   src_verwertung.reststoff;
END;
$$;

-- Beladung ausfuehren
CALL stage.p_load_all();