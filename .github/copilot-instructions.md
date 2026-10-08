# Projekt Zeta – Agent Instructions

## Arbeitsweise
- Kurz, technisch, direkt antworten. Keine Floskeln, keine Wiederholungen.
- Nur benötigte Dateien lesen; `grep`/Zeilenbereiche statt ganzer Ordner oder Großdateien.
- Keine Dateien außerhalb von `tmp/claude/` anlegen, außer der Auftrag verlangt es.
- Zwischenstand in der README sichern bei: wichtiger Entscheidung, verworfenem Ansatz, neuem Problem, neuer offener Frage.
- Keine Bildgenerierung aus puml oder drawio Dateien.

## Session-Start
1. Nur `tmp/claude/INDEX.md` lesen.
2. Bei Fortsetzung eines Themas: nur dessen `README.md` lesen. Weitere Dateien nur bei Bedarf.

## Session-Ende (verpflichtend)
1. `README.md` des Themas nach `tmp/claude/_vorlage/README.md` aktualisieren (max. ~40 Zeilen).
2. Zeile in `tmp/claude/INDEX.md` anlegen/aktualisieren.
3. Dauerhafte Erkenntnisse nach `docs/` übernehmen und in der README verlinken (`tmp/` ist gitignored).

## Review
Pflicht bei Spezifikations-, Schema- und sicherheitsrelevanten Änderungen. In neuer Session, nur mit Aufgabe, Themen-README und betroffenen Dateien (kein Chatverlauf). Ergebnis in `review.md` des Themas; Status erst dann `reviewed`.

## Ablage
`tmp/claude/JJJJ-MM-TT-<thema>/` – Datum = Beginn; `<thema>` kurz, lowercase, `-` als Trenner, keine Umlaute.
- `README.md` – Übergabe für Folge-Sessions (Pflicht)
- Unterordner nur bei Bedarf: `skripte/` (mit README: Aufruf, Parameter), `poc/`, `zwischenergebnisse/`, `testcases/` (mit README: Beschreibung der Testfälle), `adr/` (mit README: Architekturentscheidungen), `docs/` (mit README: Dokumentation)
- Diffs nicht ablegen, sondern per `git diff` erzeugen.
