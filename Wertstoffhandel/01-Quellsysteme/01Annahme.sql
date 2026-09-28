-- Quellsystem 1: Annahmesystem
-- Wertstoffhandel - Annahme und Ankauf an den Annahmestellen
-- Datenbank: annahme
 
DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;
 
-- Stammdaten
CREATE TABLE standort (
    standort_id     INTEGER      PRIMARY KEY,
    standortcode    CHAR(3)      NOT NULL UNIQUE,   -- Kopplung zu System 2
    bezeichnung     VARCHAR(60)  NOT NULL,
    standorttyp     VARCHAR(10)  NOT NULL
                    CHECK (standorttyp IN ('Land','Stadt')),
    strasse         VARCHAR(80)  NOT NULL,
    plz             CHAR(5)      NOT NULL,
    ort             VARCHAR(60)  NOT NULL,
    eroeffnung      DATE         NOT NULL
);
 
CREATE TABLE kunde (
    kunden_id       INTEGER      PRIMARY KEY,
    kundennummer    VARCHAR(12)  NOT NULL UNIQUE,
    name            VARCHAR(80)  NOT NULL,
    kundentyp       VARCHAR(12)  NOT NULL
                    CHECK (kundentyp IN ('Privat','Handwerk','Gewerbe')),
    strasse         VARCHAR(80),
    plz             CHAR(5),
    ort             VARCHAR(60),
    ausweis_geprueft BOOLEAN     NOT NULL DEFAULT FALSE,
    registriert_am  DATE         NOT NULL
);
 
CREATE TABLE materialart (
    materialart_id  INTEGER      PRIMARY KEY,
    materialcode    VARCHAR(10)  NOT NULL UNIQUE,   -- Kopplung zu System 2
    bezeichnung     VARCHAR(60)  NOT NULL,
    kategorie       VARCHAR(20)  NOT NULL,
    einheit         VARCHAR(5)   NOT NULL DEFAULT 'kg',
    gefaehrlich     BOOLEAN      NOT NULL DEFAULT FALSE
);
 
-- Ankaufspreis je Materialart und Standort, zeitlich gueltig
CREATE TABLE preis (
    preis_id        INTEGER      PRIMARY KEY,
    materialart_id  INTEGER      NOT NULL REFERENCES materialart(materialart_id),
    standort_id     INTEGER      NOT NULL REFERENCES standort(standort_id),
    gueltig_von     DATE         NOT NULL,
    gueltig_bis     DATE         NOT NULL DEFAULT DATE '9999-12-31',
    ankaufspreis_je_t NUMERIC(10,2) NOT NULL CHECK (ankaufspreis_je_t >= 0),
    UNIQUE (materialart_id, standort_id, gueltig_von),
    CHECK (gueltig_bis >= gueltig_von)
);
 
CREATE TABLE dienstleistung (
    dienstleistung_id INTEGER    PRIMARY KEY,
    leistungscode   VARCHAR(10)  NOT NULL UNIQUE,
    bezeichnung     VARCHAR(60)  NOT NULL,
    einheit         VARCHAR(10)  NOT NULL,
    preis_je_einheit NUMERIC(8,2) NOT NULL
);
 
-- Bewegungsdaten
CREATE TABLE anlieferung (
    anlieferung_id  INTEGER      PRIMARY KEY,
    kunden_id       INTEGER      NOT NULL REFERENCES kunde(kunden_id),
    standort_id     INTEGER      NOT NULL REFERENCES standort(standort_id),
    wiegescheinnr   VARCHAR(16)  NOT NULL UNIQUE,
    anlieferdatum   DATE         NOT NULL,
    kennzeichen     VARCHAR(12),
    gewicht_brutto_kg NUMERIC(10,1) NOT NULL CHECK (gewicht_brutto_kg > 0),
    gewicht_tara_kg   NUMERIC(10,1) NOT NULL DEFAULT 0,
    CHECK (gewicht_brutto_kg > gewicht_tara_kg)
);
 
CREATE TABLE anlieferungsposition (
    position_id     INTEGER      PRIMARY KEY,
    anlieferung_id  INTEGER      NOT NULL REFERENCES anlieferung(anlieferung_id),
    materialart_id  INTEGER      NOT NULL REFERENCES materialart(materialart_id),
    menge_kg        NUMERIC(10,1) NOT NULL CHECK (menge_kg > 0),
    preis_je_t      NUMERIC(10,2) NOT NULL,
    betrag_eur      NUMERIC(10,2) NOT NULL
);
 
CREATE TABLE gutschrift (
    gutschrift_id   INTEGER      PRIMARY KEY,
    anlieferung_id  INTEGER      NOT NULL UNIQUE     -- 1:1 zur Anlieferung
                    REFERENCES anlieferung(anlieferung_id),
    gutschriftdatum DATE         NOT NULL,
    betrag_netto    NUMERIC(10,2) NOT NULL,
    auszahlungsart  VARCHAR(12)  NOT NULL
                    CHECK (auszahlungsart IN ('bar','Ueberweisung'))
);
 
CREATE TABLE dienstleistungsposition (
    dlposition_id   INTEGER      PRIMARY KEY,
    anlieferung_id  INTEGER      NOT NULL REFERENCES anlieferung(anlieferung_id),
    dienstleistung_id INTEGER    NOT NULL REFERENCES dienstleistung(dienstleistung_id),
    menge           NUMERIC(8,2) NOT NULL DEFAULT 1,
    betrag_eur      NUMERIC(10,2) NOT NULL
);
 
CREATE TABLE container (
    container_id    INTEGER      PRIMARY KEY,
    standort_id     INTEGER      NOT NULL REFERENCES standort(standort_id),
    materialart_id  INTEGER      NOT NULL REFERENCES materialart(materialart_id),
    containernummer VARCHAR(16)  NOT NULL UNIQUE,    -- Kopplung zu System 2
    status          VARCHAR(12)  NOT NULL
                    CHECK (status IN ('offen','voll','abgeholt')),
    fuellstand_kg   NUMERIC(10,1) NOT NULL DEFAULT 0,
    gestellt_am     DATE         NOT NULL
);
 
CREATE INDEX ix_anlief_datum ON anlieferung(anlieferdatum);
CREATE INDEX ix_anlief_kunde ON anlieferung(kunden_id);
CREATE INDEX ix_pos_anlief   ON anlieferungsposition(anlieferung_id);
CREATE INDEX ix_pos_material ON anlieferungsposition(materialart_id);