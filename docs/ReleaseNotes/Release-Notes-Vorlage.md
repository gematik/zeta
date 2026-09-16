> **Hinweis zur Nutzung dieser Vorlage**
>
> Diese Datei ist die Vorlage für die Release Notes von **ZETA Guard** und
> **ZETA SDK**, abgeleitet aus der gematik-Dokumentvorlagen-Template.
>
> Vorgehen bei einem neuen Release:
>
> 1. Diese Datei kopieren nach `docs/ReleaseNotes/Release-Notes-<x.y.z>.md`
>    (oder den bestehenden Eintrag am Kopf der laufenden Historie ergänzen).
> 2. Platzhalter in spitzen Klammern (`<...>`) ausfüllen bzw. entfernen.
> 3. Den Abschnitt [Kompatibilität](#kompatibilität)  ausfüllen und
>    dabei in der Matrix eine neue Zeile für dieses Release ergänzen. Bestehende
>    Zeilen bleiben als Historie erhalten.
> 4. Diesen Hinweisblock sowie nicht benötigte Platzhaltertabellen entfernen.
> 5. Bei einem neuen Hauptrelease den vorherigen Abschnitt
>    `## Release-Notes zur Produktversion x.y.z` unverändert als eigenes Kapitel
>    weiter unten in der Historie belassen (ältestes Release am Dokumentende).
>
> ---

<img align="right" width="250" height="47" src="../user-manual/assets/images/Gematik_Logo_Flag.png"/> <br/>

# Release Notes – ZETA Guard & ZETA SDK

| Feld | Wert |
|---|---|
| Version | `<n.m.p>` |
| Stand | `<TT.MM.JJJJ>` |
| Status | `<in Bearbeitung \| freigegeben>` |
| Klassifizierung | `<öffentlich \| vertraulich>` |
| Referenzierung | `<AN_xxxxx>` |

## Dokumentinformationen

### Änderungen zur Vorversion

<Kurze Zusammenfassung der wichtigsten Änderungen gegenüber der Vorversion.
Bei der Erstversion: "Es handelt sich um die Erstversion des Dokumentes.">

### Dokumentenhistorie

| Version | Stand | Kap./Seite | Grund der Änderung, besondere Hinweise | Bearbeitung |
|---|---|---|---|---|
| | | | | |

## Release-Notes zur Produktversion x.y.z

### Zusammenfassung

<Kurzbeschreibung des Releases: Motivation, Umfang, wichtigste Highlights.>

### Technische Produktzerlegung

Das Release umfasst die folgenden Komponenten von ZETA Guard (Helm Chart) und
ZETA SDK.

#### ZETA Guard (Helm Chart)

| Komponente | Vorgängerversion (x.y.z-1) | Zielversion (x.y.z) |
|---|---|---|
| authserver (Keycloak) | | |
| pepproxy | | |
| opa | | |
| opa-simulation | | |
| provisioning-processor | | |
| opa-token-renewer | | |
| infinispan | | |
| `<weitere Komponente>` | | |

#### ZETA SDK

| Komponente / Sprachvariante | Vorgängerversion (x.y.z-1) | Zielversion (x.y.z) |
|---|---|---|
| ZETA SDK Kotlin/Java | | |
| ZETA SDK Swift | | |
| ZETA SDK C# | | |
| `<weitere Sprachvariante>` | | |

### Kompatibilität

Dieser Abschnitt ist **verpflichtend** für jeden Release-Note-Eintrag von
ZETA Guard und ZETA SDK. Fehlt er, gilt die Kompatibilitätsangabe als offen
und darf nicht stillschweigend aus einer vorherigen Version übernommen
werden.

#### Status-Kennzeichnung

| Status | Bedeutung |
|---|---|
| `stable` | Kombination ist freigegeben und wird aktiv unterstützt. |
| `beta` | Kombination ist funktional nutzbar, aber noch nicht vollständig verifiziert. |
| `alpha` | Kombination ist experimentell, nur für Testzwecke geeignet. |
| `deprecated` | Kombination funktioniert noch, wird aber nicht mehr empfohlen; ein Migrationspfad auf eine `stable`-Kombination existiert. |
| `retired` | Kombination wird nicht mehr unterstützt. |

#### Matrix ZETA Guard ↔ ZETA SDK

| ZETA Guard (Helm Chart) | ZETA Client SDK | Unterstützte API-Contract-Version(en) | Status | Bekannte Einschränkungen / Breaking Changes |
|---|---|---|---|---|
| `<x.y.z>` | `<Versionsspanne, z. B. >= 1.1.0>` | `<z. B. v1, v2>` | `<stable \| beta \| alpha \| deprecated \| retired>` | `<keine \| Beschreibung + Migrationshinweis-Link>` |

> Mit jedem Release wird oben eine neue Zeile für die aktuelle Kombination
> ergänzt; bestehende Zeilen bleiben als Historie erhalten. Ist eine
> Kombination noch nicht verifiziert, wird sie **nicht** geraten, sondern
> offen gelassen und unter
> [Weitere Hinweise und Kommentare](#weitere-hinweise-und-kommentare)
> vermerkt, bis sie hier ergänzt werden kann.

### Erweiterungen und Anpassungen

<Inhaltliche Funktionsänderungen oder -erweiterungen beschreiben
(nicht Fehlerbehebungen). Nach Produkt gruppieren.>

#### ZETA Guard

##### added

- `<...>`

##### changed

- `<...>`

#### ZETA SDK

##### added

- `<...>`

##### changed

- `<...>`

### Behobene Fehler

| Fehlerreferenz | Titel | Beschreibung (Art und Umfang der Änderung) |
|---|---|---|
| | | |

### Bekannte und offene Fehler

| Fehlerreferenz | Titel | Beschreibung und Fehlerauswirkung |
|---|---|---|
| | | |

### Abgrenzung

Die Release-Notes beschreiben nur die in diesem Dokument sowie den
referenzierten Anlagen aufgeführten Anpassungen am Produkt.

### Testdurchführung

#### Auswirkungsanalyse der Anpassungen für Testscope

<Kurze Analyse des gewählten Testscopes unter Bezugnahme auf die
Produktanpassungen (Auswirkungsanalyse).>

### Umgesetzte Anforderungen

<Verweis auf die aktuelle Anforderungs-Matrix bzw. betroffene A_-Anforderungen
(umgesetzt / nicht umgesetzt / abweichend umgesetzt).>

### Produktänderungen außerhalb der Spezifikationsanforderungen

<Über die Anforderungen der Spezifikation hinausgehende Änderungen.>

### Auswirkungsanalyse

<Beschreibung und Auswirkungen der Änderungen sowie Risikoanalyse.>

### Weitere Hinweise und Kommentare

<Kommentare.>

### Anlagen und Verzeichnisse

#### Abkürzungsverzeichnis

| Begriff | Erläuterung |
|---|---|
| | |

#### Glossar

| Begriff | Erläuterung |
|---|---|
| | |

#### Referenzdokumente

| Verweis | Dokument |
|---|---|
| | |

---

## Release-Notes zur Produktversion x.y.z-1 (Vorgängerrelease)

> Hinweis: Vor Erstellung eines neuen Release-Note-Kapitels den kompletten
> vorherigen Abschnitt `Release-Notes zur Produktversion x.y.z` hierher
> kopieren (als nächstes Kapitel). Die Release-Historie wird damit in diesem
> Dokument fortgeschrieben, wobei das älteste Release am Ende des Dokuments
> steht.

### Zusammenfassung

…
