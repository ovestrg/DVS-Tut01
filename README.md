# Data Warehouse Wertstoffhandel

Modul: Datenverarbeitungssysteme (DVS)

Seminargruppe: IT24-1 

Projektmitglieder: Ove Flatow (s3005538) und Linh Thu Nguyen (s3005651)

Duale Hochschule Sachsen

## Szenario

Ein Wertstoffhandel betreibt zwei Annahmestellen. Eine auf dem Land (bspw. Grossenhain) und eine in der Stadt (bspw. Dresden). Die Kunden liefern dort Altmetall an
und erhalten im Gegenzug eine Gutschrift nach Tagespreis. Das Material, welches gesammelt wurde,
wird an ein drittes Werk gefahren und anschließend dort sortiert und verwertet.

Die beiden Bereiche nutzen folgende getrennte Anwendungen:

* **Annahmesystem** (Datenbank `annahme`): Kunden, Anlieferungen, Materialarten,
  Preise, Gutschriften
* **Verwertungssystem** (Datenbank `verwertung`): Werksanlieferungen, Chargen,
  Sortieranlagen, Ausbeute, Reststoff

Die beiden Systeme sind über den **Materialcode**, die
**Containernummer** und den **Standortcode** verbunden.

## Fragestellungen

1. Welches Material kaufen wir an welchem Standort in welcher Menge an und was
   zahlen wir dafür?
2. Wie viel vom angelieferten Material ist nach dem Sortieren noch verwertbar
   und wie unterscheidet sich das zwischen Land und Stadt?

## Aufbau des Data Warehouse

Das DWH liegt in einer eigenen Datenbank `dwh` und ist in drei Schichten
gegliedert:

| Schema     | Aufgabe                                              |
|------------|------------------------------------------------------|
| `stage`    | unveränderte Kopie der benötigten Quelltabellen    |
| `core`     | Integration beider Systeme, Dimensionen, Topictabellen |
| `business` | zwei Star Schemas mit künstlichen Schlüsseln       |

Der Zugriff auf die Quelldatenbanken erfolgt über die Erweiterung
`postgres_fdw`, sodass die gesamte Beladung in SQL bleibt.

## Ausfuehrungsreihenfolge

```
createdb annahme
createdb verwertung
createdb dwh

psql -d annahme    -f 01_quellsysteme/01_annahme_ddl.sql
psql -d annahme    -f 01_quellsysteme/03_annahme_data.sql
psql -d verwertung -f 01_quellsysteme/02_verwertung_ddl.sql
psql -d verwertung -f 01_quellsysteme/04_verwertung_data.sql

psql -d dwh -f 02_dwh/05_dwh_stage.sql
psql -d dwh -f 02_dwh/06_dwh_core.sql
psql -d dwh -f 02_dwh/07_dwh_business.sql
psql -d dwh -f 02_dwh/08_dwh_etl.sql

psql -d dwh -f 03_auswertungen/09_analysen.sql
```

Eine erneute Beladung startet mit einem einzigen Aufruf:

```sql
CALL meta.p_etl_gesamt();
```

## Datenbestand

Zeitraum der Beispieldaten: 01.10.2025 bis 31.12.2025.

| Quellsystem 1        | Saetze | Quellsystem 2      | Saetze |
|----------------------|--------|--------------------|--------|
| kunde                |     24 | werksanlieferung   |     91 |
| anlieferung          |    474 | charge             |     91 |
| anlieferungsposition |    948 | sortiervorgang     |     91 |
| gutschrift           |    474 | ausbeuteposition   |    167 |
|                      |        | reststoff          |     91 |

Im DWH: `fakt_ankauf` 948 Zeilen, `fakt_verwertung` 167 Zeilen.

Die Beispieldaten werden über eine Hashfunktion erzeugt und sind damit bei
jedem Aufbau identisch reproduzierbar.

## Ergebnis - Abfrage mit 09AuswertungBusinessdwh.sql im Ordner 03Auswertung

| Standorttyp | Ankauf   | Preis     | Einsatz  | Ausbeute | Quote  |
|-------------|----------|-----------|----------|----------|--------|
| Land        | 860,3 t  | 219 EUR/t | 523,5 t  | 388,2 t  | 74,2 % |
| Stadt       | 142,9 t  | 1069 EUR/t|  73,0 t  |  63,2 t  | 86,6 % |

Der günstige Ankaufspreis am Landstandort relativiert sich, weil dort
überwiegend Mischschrott angenommen wird, von dem rund ein Viertel als Reststoff
endet.

## Verzeichnisse

```
01_quellsysteme/   DDL und Beispieldaten beider Quellsysteme
02_dwh/            Staging, Core, Business, Beladungssteuerung
03_auswertungen/   Abfragen zu beiden Fragestellungen
04_modelle/        ER-Modelle und Star Schema (draw.io)
```
