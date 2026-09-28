-- Data Warehouse: Steuerung der Beladung
-- Ein Aufruf laedt alle drei Schichten nacheinander und protokolliert das.

CREATE SCHEMA IF NOT EXISTS meta;

-- Protokoll der Ladelaeufe
DROP TABLE IF EXISTS meta.etl_lauf;
CREATE TABLE meta.etl_lauf (
    lauf_id   SERIAL PRIMARY KEY,
    schritt   VARCHAR(30) NOT NULL,
    start_ts  TIMESTAMP NOT NULL,
    ende_ts   TIMESTAMP,
    saetze    INTEGER,
    status    VARCHAR(10) NOT NULL);

-- Gesamtlauf: Staging, Core, Business
CREATE OR REPLACE PROCEDURE meta.p_etl_gesamt()
LANGUAGE plpgsql AS $$
DECLARE
    v_start TIMESTAMP;
    v_anz   INTEGER;
BEGIN
    v_start := clock_timestamp();
    CALL stage.p_load_all();
    SELECT count(*) INTO v_anz FROM stage.an_anlieferungsposition;
    INSERT INTO meta.etl_lauf (schritt, start_ts, ende_ts, saetze, status)
    VALUES ('stage', v_start, clock_timestamp(), v_anz, 'ok');

    v_start := clock_timestamp();
    CALL core.p_load_all();
    SELECT count(*) INTO v_anz FROM core.top_ankauf;
    INSERT INTO meta.etl_lauf (schritt, start_ts, ende_ts, saetze, status)
    VALUES ('core', v_start, clock_timestamp(), v_anz, 'ok');

    v_start := clock_timestamp();
    CALL business.p_load_all();
    SELECT count(*) INTO v_anz FROM business.fakt_ankauf;
    INSERT INTO meta.etl_lauf (schritt, start_ts, ende_ts, saetze, status)
    VALUES ('business', v_start, clock_timestamp(), v_anz, 'ok');

    RAISE NOTICE 'ETL-Lauf beendet.';
EXCEPTION WHEN OTHERS THEN
    INSERT INTO meta.etl_lauf (schritt, start_ts, ende_ts, status)
    VALUES ('fehler', v_start, clock_timestamp(), 'fehler');
    RAISE;
END;
$$;

-- Lauf starten
CALL meta.p_etl_gesamt();

-- Ergebnis ansehen
SELECT lauf_id, schritt, saetze, status,
       round(EXTRACT(EPOCH FROM (ende_ts - start_ts))::numeric, 3) AS dauer_sek
FROM   meta.etl_lauf
ORDER  BY lauf_id;