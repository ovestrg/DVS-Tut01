-- Quellsystem 2: Verwertungssystem
-- Sortierung und Verwertung im Werk
-- Datenbank: verwertung

DROP SCHEMA IF EXISTS public CASCADE;
CREATE SCHEMA public;

-- Stoffgruppen; der Materialcode verbindet zu System 1
CREATE TABLE stoffgruppe (
    stoffgruppe_id  INTEGER      PRIMARY KEY,
    materialcode    VARCHAR(10)  NOT NULL UNIQUE,
    bezeichnung     VARCHAR(60)  NOT NULL,
    verwertungsweg  VARCHAR(30)  NOT NULL,
    zielreinheit_proz NUMERIC(5,2) NOT NULL
);

-- Fahrer sind Mitarbeiter der Annahmestellen aus System 1
CREATE TABLE fahrer (
    fahrer_id       INTEGER      PRIMARY KEY,
    personalnummer  VARCHAR(10)  NOT NULL UNIQUE,
    name            VARCHAR(40)  NOT NULL,
    vorname         VARCHAR(40)  NOT NULL,
    annahmestelle_standortcode CHAR(3) NOT NULL
);

-- Mitarbeiter des Verwertungswerks
CREATE TABLE mitarbeiter (
    mitarbeiter_id  INTEGER      PRIMARY KEY,
    personalnummer  VARCHAR(10)  NOT NULL UNIQUE,
    name            VARCHAR(40)  NOT NULL,
    vorname         VARCHAR(40)  NOT NULL,
    qualifikation   VARCHAR(30)  NOT NULL,
    schicht         VARCHAR(10)  NOT NULL
                    CHECK (schicht IN ('Frueh','Spaet','Nacht')),
    stundensatz     NUMERIC(6,2) NOT NULL
);

CREATE TABLE sortieranlage (
    anlage_id       INTEGER      PRIMARY KEY,
    bezeichnung     VARCHAR(60)  NOT NULL,
    anlagentyp      VARCHAR(20)  NOT NULL
                    CHECK (anlagentyp IN ('Schere','Shredder','Sortierband')),
    kapazitaet_t_h  NUMERIC(6,2) NOT NULL,
    inbetriebnahme  DATE         NOT NULL,
    betriebsstatus  VARCHAR(12)  NOT NULL
                    CHECK (betriebsstatus IN ('aktiv','wartung','stillgelegt'))
);

CREATE TABLE abnehmer (
    abnehmer_id     INTEGER      PRIMARY KEY,
    name            VARCHAR(80)  NOT NULL,
    branche         VARCHAR(30)  NOT NULL,
    plz             CHAR(5)      NOT NULL,
    ort             VARCHAR(60)  NOT NULL,
    rahmenvertrag_bis DATE
);

-- Material, das von einer Annahmestelle im Werk ankommt
-- Containernummer und Standortcode stammen aus System 1
CREATE TABLE werksanlieferung (
    werksanlieferung_id INTEGER  PRIMARY KEY,
    fahrer_id       INTEGER      NOT NULL REFERENCES fahrer(fahrer_id),
    stoffgruppe_id  INTEGER      NOT NULL REFERENCES stoffgruppe(stoffgruppe_id),
    containernummer VARCHAR(16)  NOT NULL,
    herkunft_standortcode CHAR(3) NOT NULL,
    ankunft_ts      TIMESTAMP    NOT NULL,
    menge_kg        NUMERIC(10,1) NOT NULL CHECK (menge_kg > 0),
    frachtkosten    NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE TABLE charge (
    charge_id       INTEGER      PRIMARY KEY,
    werksanlieferung_id INTEGER  NOT NULL REFERENCES werksanlieferung(werksanlieferung_id),
    stoffgruppe_id  INTEGER      NOT NULL REFERENCES stoffgruppe(stoffgruppe_id),
    chargennummer   VARCHAR(16)  NOT NULL UNIQUE,
    angelegt_ts     TIMESTAMP    NOT NULL,
    einsatzmenge_kg NUMERIC(10,1) NOT NULL CHECK (einsatzmenge_kg > 0)
);

CREATE TABLE sortiervorgang (
    sortiervorgang_id INTEGER    PRIMARY KEY,
    charge_id       INTEGER      NOT NULL REFERENCES charge(charge_id),
    anlage_id       INTEGER      NOT NULL REFERENCES sortieranlage(anlage_id),
    mitarbeiter_id  INTEGER      NOT NULL REFERENCES mitarbeiter(mitarbeiter_id),
    beginn_ts       TIMESTAMP    NOT NULL,
    ende_ts         TIMESTAMP    NOT NULL,
    energieverbrauch_kwh NUMERIC(10,2) NOT NULL DEFAULT 0,
    stoerung_min    INTEGER      NOT NULL DEFAULT 0,
    CHECK (ende_ts > beginn_ts)
);

-- Abgehende Lieferung an einen Abnehmer oder Entsorger
CREATE TABLE auslieferung (
    auslieferung_id INTEGER      PRIMARY KEY,
    abnehmer_id     INTEGER      NOT NULL REFERENCES abnehmer(abnehmer_id),
    lieferscheinnr  VARCHAR(16)  NOT NULL UNIQUE,
    auslieferdatum  DATE         NOT NULL,
    menge_kg        NUMERIC(10,1) NOT NULL,
    preis_je_t      NUMERIC(10,2) NOT NULL,
    betrag_eur      NUMERIC(10,2) NOT NULL
);

-- Verwertbarer Stoff aus einem Sortiervorgang
-- auslieferung_id bleibt leer, solange der Stoff noch im Lager liegt
CREATE TABLE ausbeuteposition (
    ausbeute_id     INTEGER      PRIMARY KEY,
    sortiervorgang_id INTEGER    NOT NULL REFERENCES sortiervorgang(sortiervorgang_id),
    stoffgruppe_id  INTEGER      NOT NULL REFERENCES stoffgruppe(stoffgruppe_id),
    auslieferung_id INTEGER      REFERENCES auslieferung(auslieferung_id),
    menge_kg        NUMERIC(10,1) NOT NULL CHECK (menge_kg >= 0),
    reinheit_proz   NUMERIC(5,2) NOT NULL
);

-- Nicht verwertbarer Rest aus einem Sortiervorgang
CREATE TABLE reststoff (
    reststoff_id    INTEGER      PRIMARY KEY,
    sortiervorgang_id INTEGER    NOT NULL REFERENCES sortiervorgang(sortiervorgang_id),
    auslieferung_id INTEGER      REFERENCES auslieferung(auslieferung_id),
    abfallschluessel VARCHAR(10) NOT NULL,
    menge_kg        NUMERIC(10,1) NOT NULL CHECK (menge_kg >= 0),
    entsorgungskosten_je_t NUMERIC(10,2) NOT NULL DEFAULT 0
);

CREATE INDEX ix_charge_wa      ON charge(werksanlieferung_id);
CREATE INDEX ix_sortv_charge   ON sortiervorgang(charge_id);
CREATE INDEX ix_ausbeute_sortv ON ausbeuteposition(sortiervorgang_id);
CREATE INDEX ix_reststoff_sortv ON reststoff(sortiervorgang_id);