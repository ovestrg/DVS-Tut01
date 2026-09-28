-- Auswertungen auf der Business-Schicht
-- Datenbank: dwh

-- A1: Ankauf je Standorttyp (Fragestellung 1)
SELECT s.standorttyp,
       round(sum(f.menge_kg)/1000, 1)   AS menge_t,
       round(sum(f.ankaufswert_eur))    AS wert_eur,
       round(sum(f.ankaufswert_eur)/(sum(f.menge_kg)/1000)) AS eur_je_t
FROM   business.fakt_ankauf f
JOIN   business.dim_standort s ON s.standort_sk = f.standort_sk
GROUP  BY 1
ORDER  BY 1;

-- A2: Ankauf je Materialart, getrennt nach Standorttyp
SELECT m.bezeichnung AS material,
       round(sum(CASE WHEN s.standorttyp='Land'  THEN f.menge_kg ELSE 0 END)/1000,1) AS land_t,
       round(sum(CASE WHEN s.standorttyp='Stadt' THEN f.menge_kg ELSE 0 END)/1000,1) AS stadt_t,
       round(sum(f.ankaufswert_eur)) AS wert_eur
FROM   business.fakt_ankauf f
JOIN   business.dim_standort s ON s.standort_sk = f.standort_sk
JOIN   business.dim_material m ON m.material_sk = f.material_sk
GROUP  BY 1
ORDER  BY 4 DESC;

-- A3: Ankauf je Kundentyp
SELECT k.kundentyp,
       count(*)                       AS posten,
       round(sum(f.menge_kg)/1000, 1) AS menge_t,
       round(sum(f.ankaufswert_eur))  AS wert_eur
FROM   business.fakt_ankauf f
JOIN   business.dim_kunde k ON k.kunde_sk = f.kunde_sk
GROUP  BY 1
ORDER  BY 4 DESC;

-- A4: Ankauf je Monat
SELECT z.monat_bez AS monat,
       round(sum(f.menge_kg)/1000, 1) AS menge_t,
       round(sum(f.ankaufswert_eur))  AS wert_eur
FROM   business.fakt_ankauf f
JOIN   business.dim_zeit z ON z.zeit_sk = f.zeit_sk
GROUP  BY 1
ORDER  BY 1;

-- B1: Ausbeute je Herkunftsstandort (Fragestellung 2)
SELECT s.standorttyp,
       round(sum(f.einsatzmenge_kg)/1000, 1) AS einsatz_t,
       round(sum(f.ausbeute_kg)/1000, 1)     AS ausbeute_t,
       round(sum(f.reststoff_kg)/1000, 1)    AS rest_t,
       round(100*sum(f.ausbeute_kg)/sum(f.einsatzmenge_kg), 1) AS quote_proz
FROM   business.fakt_verwertung f
JOIN   business.dim_standort s ON s.standort_sk = f.standort_sk
GROUP  BY 1
ORDER  BY 1;

-- B2: Welche Stoffgruppen kommen aus der Sortierung heraus
SELECT m.bezeichnung AS stoffgruppe,
       round(sum(f.ausbeute_kg)/1000, 1) AS ausbeute_t
FROM   business.fakt_verwertung f
JOIN   business.dim_material m ON m.material_sk = f.material_sk
GROUP  BY 1
ORDER  BY 2 DESC;

-- B3: Ausbeute je Sortieranlage
SELECT a.anlagenname, a.anlagentyp,
       count(DISTINCT f.chargennummer)       AS chargen,
       round(sum(f.einsatzmenge_kg)/1000, 1) AS einsatz_t,
       round(sum(f.ausbeute_kg)/1000, 1)     AS ausbeute_t,
       round(100*sum(f.ausbeute_kg)/nullif(sum(f.einsatzmenge_kg),0), 1) AS quote_proz
FROM   business.fakt_verwertung f
JOIN   business.dim_anlage a ON a.anlage_sk = f.anlage_sk
GROUP  BY 1,2
ORDER  BY 4 DESC;

-- B4: Ausbeute je Monat
SELECT z.monat_bez AS monat,
       round(sum(f.einsatzmenge_kg)/1000, 1) AS einsatz_t,
       round(sum(f.ausbeute_kg)/1000, 1)     AS ausbeute_t,
       round(100*sum(f.ausbeute_kg)/nullif(sum(f.einsatzmenge_kg),0), 1) AS quote_proz
FROM   business.fakt_verwertung f
JOIN   business.dim_zeit z ON z.zeit_sk = f.zeit_sk
GROUP  BY 1
ORDER  BY 1;