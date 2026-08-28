# Middleware- und Cloud-Primärsysteme mit ZETA Client — Szenarienanalyse

**Stand:** 2026-08-28
**Gegenstand:** Bewertung zweier Grundsatzoptionen für den Einsatzort des ZETA Clients:
**Szenario 1** — Betrieb des ZETA Clients in einer Middleware bzw. in einem Cloud-Primärsystem wird unterstützt;
**Szenario 2** — nicht unterstützt, jeder Client eines Endnutzers muss einen eigenen ZETA Client enthalten.
Bewertet nach Entwicklung, Wartung, Betrieb, Auswirkung auf Nutzer und Sicherheit, mit abgeleiteter Empfehlung.

**Grundlagen dieser Bewertung (Stand Repository):**

| Artefakt | Relevanz |
|---|---|
| [src/schemas/client-statement.yaml](../../src/schemas/client-statement.yaml) | `platform`, `posture_type` (`android`, `apple`, `software`, `tpm`), `posture`, `attestation_timestamp` |
| [src/schemas/posture-software.yaml](../../src/schemas/posture-software.yaml) | Software-Posture: `product_id`, `product_version`, `os`, `arch`, `public_key`, `nonce` |
| [src/schemas/policy-engine-input.yaml](../../src/schemas/policy-engine-input.yaml) | Entscheidungsgrundlage des PDP inkl. `country_code` (GeoIP der Quell-IP) |
| [src/schemas/subject-token-smb.yaml](../../src/schemas/subject-token-smb.yaml) | SM(C)-B-signiertes Subject Token (Institutionsnachweis) |
| [docs/user-manual/ReadMePrimaersystemHersteller.md](../../docs/user-manual/ReadMePrimaersystemHersteller.md) | verweist bereits auf Testdriver-Proxy „falls ein cloudbasiertes Primärsystem den ZETA-Client ggf. als eigenen Container betreiben möchte (abhängig von Sicherheitsbetrachtungen und Zulassung)" |
| [docs/user-manual/SicherheitsanforderungenClientHersteller.md](../../docs/user-manual/SicherheitsanforderungenClientHersteller.md) | Sicherheitsleistungen, die nicht das SDK, sondern der Client-Hersteller erbringt |

---

## Inhaltsverzeichnis

- [Middleware- und Cloud-Primärsysteme mit ZETA Client — Szenarienanalyse](#middleware--und-cloud-primärsysteme-mit-zeta-client--szenarienanalyse)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [1 Ausgangslage](#1-ausgangslage)
  - [2 Was die ZETA-Vertrauenskette heute tatsächlich zusichert](#2-was-die-zeta-vertrauenskette-heute-tatsächlich-zusichert)
  - [3 Ausprägungen der Anfragen (Varianten M1–M3)](#3-ausprägungen-der-anfragen-varianten-m1m3)
  - [4 Szenario 1: Middleware/Cloud-PS mit ZETA Client wird unterstützt](#4-szenario-1-middlewarecloud-ps-mit-zeta-client-wird-unterstützt)
    - [4.1 Entwicklung](#41-entwicklung)
    - [4.2 Wartung](#42-wartung)
    - [4.3 Betrieb](#43-betrieb)
    - [4.4 Auswirkung auf Nutzer](#44-auswirkung-auf-nutzer)
    - [4.5 Sicherheit (Zusammenfassung, Details in Kapitel 7)](#45-sicherheit-zusammenfassung-details-in-kapitel-7)
  - [5 Szenario 2: Wird nicht unterstützt — ZETA Client in jedem Nutzer-Client](#5-szenario-2-wird-nicht-unterstützt--zeta-client-in-jedem-nutzer-client)
    - [5.1 Entwicklung](#51-entwicklung)
    - [5.2 Wartung](#52-wartung)
    - [5.3 Betrieb](#53-betrieb)
    - [5.4 Auswirkung auf Nutzer](#54-auswirkung-auf-nutzer)
    - [5.5 Sicherheit (Zusammenfassung)](#55-sicherheit-zusammenfassung)
  - [6 Gegenüberstellung](#6-gegenüberstellung)
  - [7 Sicherheitsanalyse im Detail](#7-sicherheitsanalyse-im-detail)
    - [7.1 Was genau verloren geht](#71-was-genau-verloren-geht)
    - [7.2 Neue Risiken, die entstehen](#72-neue-risiken-die-entstehen)
    - [7.3 Was *nicht* verloren geht](#73-was-nicht-verloren-geht)
  - [8 Kompensierende Maßnahmen für Szenario 1](#8-kompensierende-maßnahmen-für-szenario-1)
  - [9 Empfehlung](#9-empfehlung)
  - [10 Umsetzungsschritte der Empfehlung](#10-umsetzungsschritte-der-empfehlung)
  - [11 Offene Punkte und Entscheidungsbedarf](#11-offene-punkte-und-entscheidungsbedarf)

---

## 1 Ausgangslage

Das ZETA-Zielbild geht davon aus, dass der ZETA Client auf dem Rechner des Endnutzers läuft.
Die Attestierung umfasst dann **Gerät und Fach-Client des Nutzers**: der attestierte Zustand ist
derselbe Zustand, in dem der Nutzer fachlich arbeitet. Zugriffsentscheidungen des PDP beziehen sich
damit auf genau die Endpunkt-Instanz, die die Ressource anfasst — das ist der Kern des
Zero-Trust-Ansatzes („kein implizites Vertrauen in Netzwerkposition, Vertrauen wird pro Anfrage aus
Identität *und* Gerätezustand hergeleitet").

Aus dem Markt liegen zwei Anfragen vor, die von diesem Zielbild abweichen:

1. **Cloud-Primärsystem:** Das Primärsystem läuft beim Hersteller/Betreiber in der Cloud, der
   Endnutzer arbeitet über Browser und Web-App auf seinem Gerät. Der ZETA Client läuft in der Cloud.
2. **Middleware:** Auch für klassische Primärsysteme wollen Hersteller ZETA Client und Fach-Clients
   als Middleware anbieten. Das Primärsystem erstellt nur noch fachliche HTTP-Requests und
   verarbeitet Responses; alles andere übernimmt die Middleware.

In beiden Fällen gilt: **attestiert wird die Middleware**. Die eigentlichen Endnutzer-Clients und
-Geräte sind aus ZETA-Sicht unbekannt; es gibt keine Aussage zu ihrem Sicherheitszustand.

Die Fragestellung ist damit keine rein technische, sondern eine **Zulassungs- und
Vertrauensmodell-Entscheidung**: Welche Aussage darf ein Fachdienst aus einem ZETA-Access-Token
ableiten, und darf diese Aussage je nach Deployment unterschiedlich stark sein?

---

## 2 Was die ZETA-Vertrauenskette heute tatsächlich zusichert

Für die Bewertung ist wichtig, präzise zu trennen, welche Glieder der Kette durch eine Middleware
verändert werden und welche nicht.

| Glied der Kette | Aussage | Von Middleware betroffen? |
|---|---|---|
| Client-Instanz-Schlüssel (DCR, `PuK.Client.Sig`) | Diese Software-Instanz besitzt diesen privaten Schlüssel | **Ja** — Instanz ist die Middleware, nicht das Nutzergerät |
| Client Statement / Posture (`posture_type`, `product_id`, `product_version`, `os`) | Produkt und Version der laufenden Client-Software, Zustand der Plattform | **Ja** — beschreibt die Middleware-Plattform |
| Hardware-Attestierung (TPM, geplant) | Integrität der Plattform, auf der der Client läuft | **Ja** — attestiert Server/VM statt Arbeitsplatz |
| DPoP-Bindung des Access Token | Token nur mit dem Besitz des Instanzschlüssels nutzbar | **Ja** — Schlüssel liegt in der Middleware |
| SM(C)-B Subject Token / sektorale IdP-Authentisierung | Identität von Institution bzw. Nutzer | **Teilweise** — Identität bleibt korrekt, aber der Besitznachweis wandert |
| `country_code` (GeoIP der Quell-IP im PDP-Input) | Geografische Herkunft der Anfrage | **Ja** — es wird die Cloud-Region gemessen, nicht der Nutzerstandort |
| PEP-Header-Hygiene, Ressourcenschutz am Fachdienst | Schutz vor client-gesetzten Credentials | Nein |

Die entscheidende Beobachtung: **ZETA verliert in der Middleware-Variante nicht die Authentisierung,
sondern die Aussage über den Endpunkt.** Wer zugreift, bleibt bekannt (SM(C)-B bzw. IdP). Von *wo*
und *womit* zugegriffen wird, ist nicht mehr belegt. Der Teil der Zero-Trust-Kette, der
Endpunkt-Kompromittierung adressiert, endet an der Middleware.

Zweite Beobachtung: Die Strecke **Endnutzer-Gerät → Middleware** ist damit nicht ungeschützt, sondern
**außerhalb der ZETA-Kontrolle**. Sie wird durch die Mittel des Herstellers gesichert (TLS,
Session-Management, Web-App-Sicherheit, ggf. eigenes MDM). Das ist qualitativ derselbe Schutz, den
heute jede Cloud-Fachanwendung bietet — nur eben nicht der, den ZETA zusichert.

---

## 3 Ausprägungen der Anfragen (Varianten M1–M3)

Eine pauschale Ja/Nein-Bewertung wird der Sachlage nicht gerecht, weil die Risikoprofile der
konkreten Ausprägungen stark auseinanderfallen.

| Variante | Beschreibung | Wo läuft der ZETA Client | Netzwerklage der Nutzer-Clients |
|---|---|---|---|
| **M1 — Lokale Middleware** | ZETA Client als Dienst/Container in der Praxis-, Klinik- oder Apotheken-Infrastruktur, Fach-Clients auf Arbeitsplätzen im selben verwalteten Netz | in der Institution des Leistungserbringers | im LAN der Institution, unter deren Verantwortung |
| **M2 — Hersteller-Cloud, ein Mandant je Instanz** | Cloud-PS, je Leistungserbringer eine dedizierte ZETA-Client-Instanz mit eigenem Instanzschlüssel | beim PS-Betreiber | Internet, Browser/Web-App |
| **M3 — Hersteller-Cloud, geteilte Instanz** | Cloud-PS, eine ZETA-Client-Instanz bedient viele Leistungserbringer | beim PS-Betreiber | Internet, Browser/Web-App |

Sicherheitlich gilt: **M1 < M2 < M3** in aufsteigender Risikohöhe. M1 ist im Kern ein Umzug des
Clients an einen anderen Ort *innerhalb derselben Verantwortungssphäre* — vergleichbar mit der
Konnektor-Logik in TI 1.0. M3 dagegen konzentriert Schlüsselmaterial und Zugriffsrechte vieler
Institutionen in einer einzigen Instanz und ist der eigentlich kritische Fall.

Diese Unterscheidung wird in den folgenden Kapiteln durchgehalten.

---

## 4 Szenario 1: Middleware/Cloud-PS mit ZETA Client wird unterstützt

### 4.1 Entwicklung

**Vorteile**

- **Ein Integrationspunkt statt N.** Der Hersteller integriert das SDK einmal in die Middleware statt
  in jede Fach-Client-Variante (Windows-Desktop, Web, mobil). Die im Produkthandbuch beschriebenen
  plattformspezifischen Build-Ketten (Java/Kotlin, C++ mit MinGW/clang, C# über C-ABI) entfallen
  weitgehend zugunsten einer einzigen Zielplattform.
- **Der aufwendige Teil des SDK-Vertrags entfällt für die Fach-Clients.** Die vom Client-Hersteller
  zu erbringenden Leistungen — sichere Ablage von Access Tokens, Konnektor-Anbindung, Log-Ausgabe —
  müssen nur einmal, in der Middleware, umgesetzt und geprüft werden.
- **Bestehende Primärsysteme können weitgehend unverändert bleiben.** Sie sprechen HTTP gegen die
  Middleware; die ZETA-Anteile sind gekapselt. Das senkt die Markteintrittsschwelle für ZETA
  erheblich, gerade für ältere Codebasen ohne aktuelle Toolchain.
- **Cloud-PS wird überhaupt erst realisierbar.** Ein Cloud-Primärsystem mit Browser-Frontend hat
  keinen Ort, an dem ein Endgeräte-ZETA-Client sinnvoll laufen könnte — außer man verlagert die
  ZETA-Funktion in den Browser, was weder für Schlüsselhaltung noch für Attestierung tragfähig ist.

**Nachteile**

- **gematik-seitig entsteht ein zweiter, zu spezifizierender Betriebsmodus.** Client Statement,
  Posture-Schema, OPA-Regelwerk, Registrierungsprozess und Zulassungskriterien brauchen eine
  explizite Ausprägung für „delegierte Attestierung" — sonst wird die Variante faktisch mitgeschleift und die Unterscheidbarkeit am Fachdienst geht verloren.
- **Der Hersteller baut ein sicherheitskritisches Produkt mehr.** Die Middleware ist ein
  Credential-haltender Multi-User-Dienst; Mandantentrennung, Session-Bindung, Autorisierung der
  eigenen Nutzer und Absicherung der Nord-Schnittstelle sind neue, nicht triviale Eigenleistungen —
  genau die Klasse von Fehlern, die ZETA am Endpunkt vermeiden will.
- **Testbarkeit sinkt.** Ende-zu-Ende-Tests decken nur noch Middleware→Fachdienst ab; die Strecke
  Nutzer→Middleware ist herstellerspezifisch und außerhalb der gematik-Testmittel.

### 4.2 Wartung

**Vorteile**

- **Zentrales SDK-Update statt Flottenrollout.** SDK-Versionssprünge, Krypto-Umstellungen und
  Protokolländerungen (z. B. neue Federation-, DPoP- oder PoPP-Anforderungen) werden an einer Stelle
  ausgerollt. Die im Produkthandbuch bislang unbestimmte Wartungssituation („Ein definierter
  Wartungsprozess ist vor Meilenstein 4 aktuell nicht umgesetzt") entschärft sich für den Hersteller
  deutlich.
- **Produktversion und Hash-Meldung an die gematik betreffen ein Artefakt.** Die für die Attestierung
  zu meldenden Angaben (SDK-Version, Fachdienstversionen, Gesamthash der unveränderlichen Dateien)
  fallen je Middleware-Produktversion an, nicht je Client-Variante.
- **Schnellere Reaktion auf Schwachstellen.** Ein kritisches SDK-CVE ist in Stunden bis Tagen
  behoben, nicht in Wochen über den Update-Zyklus tausender Arbeitsplätze.

**Nachteile**

- **Versionsdiversität verschwindet aus dem Blickfeld, nicht aus der Realität.** Die Fach-Clients der
  Nutzer bleiben in beliebigen Versionen und auf beliebigen Betriebssystemen im Feld — nur meldet die
  Posture jetzt einheitlich die Middleware. Die gematik verliert die Grundlage, veraltete oder
  bekannt verwundbare Endnutzer-Stände über Policies auszusteuern.
- **Ein Fehler wirkt sofort für alle.** Dieselbe Zentralität, die Patches beschleunigt, macht
  fehlerhafte Rollouts zum flächigen Ausfall.

### 4.3 Betrieb

**Vorteile**

- **Deutlich weniger Verbindungen zur TI.** OCSP, Federation Master, IdP-Verkehr, Nonce- und
  Token-Beschaffung bündeln sich. Für die Guard-Betreiber sinkt die Zahl aktiver Client-Instanzen und
  damit Registrierungs-, Nonce- und Token-Last spürbar.
- **Egress-Steuerung wird einfach.** Die im Repository beschriebenen Egress-/Forward-Proxy-Themen
  betreffen wenige, gut definierte Systeme statt jedes Arbeitsplatzrechners — ein realer Vorteil in
  Klinikumgebungen mit restriktivem Netz.
- **Professioneller Betrieb statt Endanwenderrechner.** Monitoring, Zeitsynchronisation,
  Zertifikatspflege und Konnektor-/SM(C)-B-Anbindung laufen in einer überwachten Umgebung, nicht auf
  einem beliebigen Praxis-PC.

**Nachteile**

- **Neue Verfügbarkeitsdomäne mit hohem Kritikalitätsgrad.** Die Middleware ist ein Single Point of
  Failure für alle angeschlossenen Leistungserbringer; für M2/M3 zusätzlich abhängig von der
  Erreichbarkeit des Herstellers und dessen Cloud-Provider.
- **Fehlerdiagnose über Verantwortungsgrenzen hinweg.** Bei einer Ablehnung durch den PDP ist ohne
  zusätzliche Korrelations-IDs nicht mehr erkennbar, für welchen Nutzer bzw. Arbeitsplatz sie erfolgte.
- **Anomalieerkennung wird stumpf.** Ratelimits, Nonce-/DPoP-Fehlerraten und Zugriffsmuster werden pro
  Client-Instanz beobachtet. Aggregiert man hunderte Nutzer auf eine Instanz, verschwindet
  auffälliges Einzelverhalten im Rauschen, und legitime Spitzen sind von Missbrauch kaum trennbar.
- **`country_code` verliert seine Aussage.** Der PDP misst die Quell-IP der Middleware. Eine
  geografische Policy trifft die Cloud-Region, nicht den Nutzerstandort — ein Zugriff aus dem Ausland
  bleibt unsichtbar, wenn die Middleware in Deutschland steht.
- **Skalierung kollidiert mit dem Instanzbegriff.** Horizontale Skalierung der Middleware bedeutet
  entweder viele Client-Instanzen (Registrierungs- und Schlüsselverwaltung wird zum Betriebsthema)
  oder geteiltes Instanz-Schlüsselmaterial über Pods hinweg (Bindungsaussage wird schwächer, HSM/KMS
  wird faktisch Pflicht).

### 4.4 Auswirkung auf Nutzer

**Vorteile**

- **Kein ZETA-spezifischer Aufwand am Arbeitsplatz.** Keine lokale Installation, keine
  Client-Registrierung, keine plattformspezifischen Voraussetzungen; Bring-your-own-Device und
  Thin-Client-Umgebungen (VDI, Terminalserver) funktionieren ohne Sonderweg.
- **Nutzung von Geräten, die nie attestierbar wären.** Ältere Windows-Stände ohne TPM 2.0, Linux-
  oder Mac-Arbeitsplätze, Tablets im Stationsalltag bleiben nutzbar.
- **Schnellerer Zugang zu TI-2.0-Diensten**, weil kein Endgeräte-Rollout die Einführung ausbremst.

**Nachteile**

- **Der Nutzer verliert eine Schutzwirkung, die er nicht sieht.** Ist sein Arbeitsplatz kompromittiert,
  erkennt ZETA das nicht mehr; die Middleware setzt den Zugriff mit vollem Vertrauen fort. Die
  Sicherheitszusage der TI 2.0 gilt für ihn faktisch nicht in der beworbenen Tiefe.
- **Vertrauen wird an den Hersteller delegiert.** Der PS-Hersteller wird zur Instanz, die im Namen der
  Institution auf Patientendaten zugreifen kann. Das ist eine datenschutzrechtlich und
  haftungsrechtlich relevante Verschiebung (Auftragsverarbeitung, ggf. Zugriff auf Daten in der VAU-
  bzw. Fachdienstgrenze), die dem Leistungserbringer bewusst sein muss.
- **Sperrung trifft grob.** Eine kompromittierte oder auffällige Middleware-Instanz kann nur als
  Ganzes gesperrt werden — betroffen sind dann alle daran hängenden Praxen, nicht der eine
  auffällige Arbeitsplatz.

### 4.5 Sicherheit (Zusammenfassung, Details in Kapitel 7)

- Endpunkt-Attestierung entfällt für den tatsächlichen Arbeitsplatz — die zentrale
  Zero-Trust-Eigenschaft ist im Geltungsbereich reduziert.
- Konzentration von Schlüsselmaterial und Zugriffsrechten (**Blast Radius**), bei M3 über
  Mandantengrenzen hinweg.
- Neue, herstellerdefinierte Vertrauensgrenze zwischen Nutzer und Middleware, außerhalb der
  ZETA-Prüfung.
- Insider- und Betreiberrisiko beim PS-Hersteller wird sicherheitsrelevant.
- Nutzer-zu-Zugriff-Zuordnung (Forensik, Nachvollziehbarkeit) hängt an der Middleware und ist am
  Fachdienst nicht mehr unabhängig überprüfbar.

---

## 5 Szenario 2: Wird nicht unterstützt — ZETA Client in jedem Nutzer-Client

### 5.1 Entwicklung

**Vorteile**

- **Ein einziges, konsistentes Sicherheitsmodell.** Keine Sonderfälle in Spezifikation, Schemata,
  OPA-Regeln, Zulassung und Dokumentation. Alle Aussagen im Access Token bedeuten immer dasselbe.
- **Klare Anforderungen an die Hersteller.** Die Sicherheitsleistungen für Client-Hersteller sind
  bereits geschnitten und geprüft; es gibt keine Grauzone „was gilt für eine Middleware?".
- **Attestierungsroadmap bleibt tragfähig.** Die geplante TPM-/Plattform-Attestierung entfaltet ihren
  Zweck nur, wenn sie das Gerät des Nutzers misst.

**Nachteile**

- **Hoher Integrationsaufwand je Client und Plattform.** Jede Fach-Client-Variante braucht SDK-
  Integration, sichere Speicherung, Konnektor-Zugriff, Logging und die zugehörige Sicherheitsprüfung.
- **Browser-basierte und Cloud-Primärsysteme sind faktisch ausgeschlossen.** Eine Web-App kann weder
  Instanzschlüssel sicher halten noch Plattform-Attestierung erbringen. Für dieses Marktsegment gibt
  es unter Szenario 2 keinen konformen Weg — das ist keine Erschwernis, sondern ein Marktausschluss.
- **Altsysteme kommen ggf. nicht mit.** Primärsysteme ohne moderne Toolchain müssen erheblich
  umgebaut werden.

### 5.2 Wartung

**Vorteile**

- **Feingranulare Steuerbarkeit.** Veraltete Client-Versionen, unsichere Betriebssystemstände oder
  einzelne kompromittierte Instanzen sind über Policies gezielt aussteuerbar. Das ist die operative
  Kernfähigkeit, die Szenario 1 einbüßt.
- **Kein flächiger Fehlereffekt durch eine zentrale Komponente.**

**Nachteile**

- **Update-Rollout über die Fläche.** Ein sicherheitskritisches SDK-Update muss auf sehr viele
  Installationen; die Update-Geschwindigkeit ist die des langsamsten Herstellers und der langsamsten
  Praxis. Realistisch bedeutet das Wochen bis Monate mit gemischten Ständen im Feld.
- **Hoher Support- und Meldeaufwand.** Produktversionen, Hash-Listen und Registrierungsdaten fallen je
  Client-Variante und Version an.

### 5.3 Betrieb

**Vorteile**

- **Vollständige, feingranulare Telemetrie und Anomalieerkennung.** Jede Client-Instanz ist einzeln
  sichtbar; Ratelimits, Nonce-/DPoP-Fehlerraten und Zugriffsmuster sind aussagekräftig, `country_code`
  misst den tatsächlichen Zugriffsort.
- **Chirurgische Sperrung.** Eine auffällige Instanz wird gesperrt, ohne andere Nutzer zu treffen.
- **Keine zusätzliche kritische Infrastruktur** zwischen Nutzer und Guard.

**Nachteile**

- **Deutlich höhere Last auf Guard und TI-Diensten** (Registrierungen, Nonces, Token, OCSP,
  Federation) — skalierbar, aber dimensionierungsrelevant.
- **Egress-Freigaben an jedem Arbeitsplatz.** In restriktiven Klinik- und Praxisnetzen ist das ein
  realer, wiederkehrender Aufwand.
- **Betriebsqualität hängt am Endgerät:** Uhrzeit, Zertifikatsspeicher, Proxy-Konfiguration und
  Netzwerkfilter sind auf Arbeitsplatzrechnern eine häufige Fehlerquelle und erzeugen
  Support-Aufkommen, das sonst zentral gelöst würde.

### 5.4 Auswirkung auf Nutzer

**Vorteile**

- **Die zugesagte Schutzwirkung greift tatsächlich.** Ein kompromittierter Arbeitsplatz führt zur
  Verweigerung des Zugriffs — das ist der Nutzen, für den ZETA gebaut wird.
- **Zugriffe sind dem Arbeitsplatz zuordenbar** (Nachvollziehbarkeit, Missbrauchsaufklärung).
- **Kein zusätzlicher Dritter** in der Verarbeitungskette.

**Nachteile**

- **Installations-, Registrierungs- und Betriebsaufwand am Arbeitsplatz.**
- **Geräteausschluss:** Arbeitsplätze, die die Anforderungen nicht erfüllen (kein TPM, veraltetes OS,
  VDI-/Thin-Client-Umgebungen), verlieren den Zugang. Das trifft im Klinikumfeld relevante Bestände
  und erzeugt Investitionsdruck.
- **Risiko der Umgehung.** Wird der konforme Weg als unerreichbar empfunden, entstehen inoffizielle
  Workarounds (RDP-/Terminalserver-Nutzung eines einzelnen „ZETA-fähigen" Rechners, Weiterreichen von
  Sessions). Das Ergebnis ist eine faktische Middleware — ohne Spezifikation, ohne Zulassung, ohne
  Sichtbarkeit. **Ein Verbot beseitigt das Muster nicht, es entzieht es der Regulierung.**

### 5.5 Sicherheit (Zusammenfassung)

- Volle Zero-Trust-Eigenschaft: Identität *und* Endpunktzustand pro Anfrage.
- Kleiner Blast Radius je Kompromittierung, kein Sammelziel.
- Keine zusätzliche Vertrauensinstanz.
- Restrisiko: Endgeräte sind heterogen und schlechter gehärtet als ein professionell betriebener
  Dienst; ein schlecht gepflegter Arbeitsplatz mit gültiger Attestierung bleibt ein schlecht
  gepflegter Arbeitsplatz, solange die Posture-Prüfung keine tiefen Integritätsaussagen liefert.
  Die Attestierung ist derzeit software-basiert (`posture_type: software`); die Hardware-Attestierung
  ist noch nicht vollständig spezifiziert. **Der Vorsprung von Szenario 2 ist heute damit kleiner als
  im Zielbild — er wächst erst mit der TPM-Attestierung.**

---

## 6 Gegenüberstellung

| Kriterium | Szenario 1 (Middleware/Cloud-PS unterstützt) | Szenario 2 (nur Endgeräte-Clients) |
|---|---|---|
| Entwicklungsaufwand Hersteller | niedrig (ein Integrationspunkt) | hoch (je Client und Plattform) |
| Spezifikations- und Zulassungsaufwand gematik | **erhöht** (zweiter Betriebsmodus) | niedrig (ein Modell) |
| Patch-Geschwindigkeit | hoch (zentral) | niedrig (Fläche) |
| Steuerbarkeit über Policies | grob (je Middleware) | fein (je Instanz) |
| Aussagekraft der Attestierung | Middleware-Plattform | Nutzergerät |
| `country_code` / Standortbezug | ohne Aussage zum Nutzer | belastbar |
| Anomalieerkennung / Ratelimits | aggregiert, unscharf | pro Instanz, scharf |
| Sperrgranularität | Middleware (viele Nutzer) | einzelne Instanz |
| Blast Radius bei Kompromittierung | hoch (M3 mandantenübergreifend) | niedrig |
| Zusätzliche Vertrauensinstanz | ja (PS-Hersteller/-Betreiber) | nein |
| Verfügbarkeitsrisiko | zentralisiert | verteilt |
| Last auf Guard/TI-Diensten | niedrig | hoch |
| Marktabdeckung (Cloud-PS, VDI, BYOD) | vollständig | Cloud-PS ausgeschlossen |
| Erwartete Umgehungsanreize | gering | **hoch** |
| Übereinstimmung mit dem ZETA-Zielbild | reduziert | vollständig |

---

## 7 Sicherheitsanalyse im Detail

### 7.1 Was genau verloren geht

1. **Endpunkt-Integrität.** Malware auf dem Arbeitsplatz ist für ZETA unsichtbar. Der PDP entscheidet
   über einen Zustand, den der Angreifer nicht berührt hat — die Middleware ist sauber, der Zugriff
   ist es nicht.
2. **Bindung Nutzer ↔ Gerät ↔ Token.** Die DPoP-Bindung schützt den Abschnitt Middleware→Guard. Für
   den Abschnitt Nutzer→Middleware gibt es keine ZETA-Aussage; dessen Sicherheit ist eine
   Session-Frage im Produkt des Herstellers (Session-Fixation, XSS, CSRF, Token im Browser-Storage).
3. **Standort- und Zeitbezug.** Zugriffe aus untypischen Ländern oder zu untypischen Zeiten sind am
   Guard nicht mehr erkennbar, weil alle Zugriffe die Signatur der Middleware tragen.
4. **Granulare Reaktionsfähigkeit.** Incident Response kann nicht mehr gezielt einen Arbeitsplatz
   isolieren; die verfügbare Maßnahme ist die Sperrung der Middleware und trifft Unbeteiligte.

### 7.2 Neue Risiken, die entstehen

| Risiko | M1 (lokal) | M2 (Cloud, je Mandant) | M3 (Cloud, geteilt) |
|---|---|---|---|
| Kompromittierte Middleware → Zugriff auf alle angeschlossenen Sitzungen | mittel (eine Institution) | mittel–hoch | **hoch (mandantenübergreifend)** |
| Fehler in der Mandantentrennung (Cross-Tenant-Datenzugriff) | n/a | gering | **hoch** |
| Insider beim PS-Betreiber mit Zugriff auf Instanzschlüssel/Tokens | gering | hoch | hoch |
| Schlüsselmaterial verlässt die Institution | nein | **ja** | **ja** |
| Verwechslung/Fehlzuordnung von Nutzeridentität zu Anfrage | gering | mittel | hoch |
| Aggregierter Datenabfluss über eine Instanz unbemerkt | gering | mittel | **hoch** |
| SM(C)-B-Nutzung ohne physische Kontrolle der Institution | gering (Konnektor lokal) | hoch (zentrale SM-B-Haltung) | hoch |

Der letzte Punkt verdient besondere Aufmerksamkeit: In der Cloud-Variante muss der Zugriff auf die
SM(C)-B entweder über den Konnektor der Institution zurückgeführt werden (technisch aufwendig, aber
sicherheitlich sauber) oder zentral als SM-B-Datei/HSM beim Betreiber erfolgen. Die zweite Lösung
bedeutet, dass der Institutionsnachweis der TI ohne physische Kontrolle der Institution erzeugt wird
— das berührt das Fundament der Identitätsaussage, nicht nur die Endpunktaussage, und ist der
sicherheitlich schwerwiegendste Aspekt der Cloud-Variante.

### 7.3 Was *nicht* verloren geht

Zur Fairness der Bewertung: Der Fachdienst bleibt hinter dem Guard geschützt; Autorisierung, Scopes,
Audience-Bindung, PoPP-Prüfung, Header-Hygiene am PEP und die Ressourcenschutz-Policies wirken
unverändert. Die Middleware kann nicht mehr Rechte erlangen, als der Institution zustehen. Der Verlust
betrifft die **Qualität der Zugriffsentscheidung**, nicht ihre **Existenz**.

---

## 8 Kompensierende Maßnahmen für Szenario 1

Falls Szenario 1 zugelassen wird, sind folgende Maßnahmen geeignet, den Abstand zum Zielbild zu
verkleinern. Sie sind nach Wirksamkeit sortiert.

1. **Kennzeichnungspflicht im Client Statement.** Ein expliziter `posture_type` bzw. ein zusätzliches
   Attribut (z. B. `deployment_model: endpoint | middleware`) macht die Betriebsart für PDP und
   Fachdienst maschinell unterscheidbar. Ohne diese Maßnahme ist keine der folgenden durchsetzbar.
2. **Differenzierte Policies am PDP.** Middleware-Zugriffe erhalten ein anderes Regelwerk:
   eingeschränkte Scopes, kürzere Token-Lebensdauern, engere Ratelimits, ggf. Ausschluss besonders
   sensitiver Operationen.
3. **Eine Client-Instanz je Mandant (M3 ausschließen).** Getrennte Instanzschlüssel und getrennte
   Registrierungen je Leistungserbringer stellen die Sperrgranularität auf Institutionsebene wieder
   her und begrenzen den Blast Radius.
4. **Durchreichen der Endnutzer-Kennung.** Ein von der Middleware attestierter, am Guard
   protokollierter Endnutzer-Bezug (Nutzerkennung, Arbeitsplatz-ID) stellt Nachvollziehbarkeit
   wieder her — mit dem ausdrücklichen Vorbehalt, dass diese Angabe **nicht** kryptografisch
   verifizierbar ist und nicht als Sicherheitsmerkmal, sondern als Forensikmerkmal zählt.
5. **Schlüsselschutz im HSM/KMS** für Instanzschlüssel und SM-B-Zugriff, mit protokolliertem
   Nutzungsnachweis.
6. **Erhöhte Anforderungen an den Middleware-Betreiber.** Zulassung mit Nachweisen zu
   Mandantentrennung, Session-Sicherheit der Nord-Schnittstelle (OWASP ASVS-Niveau), Betriebssicherheit
   und Meldepflichten — analog den bestehenden Sicherheitsleistungen für Client-Hersteller, aber auf
   einen Multi-User-Dienst zugeschnitten.
7. **Nachweispflicht zur Endgeräteverwaltung.** Für M1 kann die Institution eine Aussage über die
   Verwaltung der angeschlossenen Arbeitsplätze machen (MDM, Patchstand); für M2/M3 ist das
   realistisch nicht durchsetzbar.
8. **Transparenzpflicht gegenüber dem Leistungserbringer.** Er muss wissen, dass sein
   TI-2.0-Zugriff nicht endpunktattestiert ist und wer die Middleware betreibt.

Maßnahme 1 ist die entscheidende: Sie kostet wenig und erhält die Handlungsfähigkeit. Ohne sie ist
die Zulassung von Szenario 1 eine irreversible Aufweichung, weil das Vertrauensniveau am Fachdienst
nicht mehr rekonstruierbar ist.

---

## 9 Empfehlung

**Empfohlen wird eine differenzierte Variante von Szenario 1: Middleware- und Cloud-Betrieb des ZETA
Clients werden unterstützt, aber ausschließlich als eigenständige, gekennzeichnete Betriebsart mit
eigenem Vertrauensniveau, eigener Zulassung und eigenem Policy-Regelwerk — nicht als gleichwertige
Alternative zum Endgeräte-Client.**

Begründung:

1. **Ein Verbot ist nicht durchsetzbar und verschlechtert die Lage.** Der Bedarf ist real (Cloud-PS,
   VDI, BYOD, Altsysteme). Unter Szenario 2 entstehen dieselben Architekturen als nicht
   spezifizierte Workarounds — Terminalserver, Remote-Sessions, geteilte „ZETA-Rechner". Das Ergebnis
   ist dasselbe Risiko *ohne* Kennzeichnung, *ohne* Zulassungsanforderungen und *ohne* Sichtbarkeit
   am Guard. Regulierte Sichtbarkeit ist der sicherheitlich bessere Zustand als unsichtbare Umgehung.
2. **Der aktuelle Vorsprung von Szenario 2 ist geringer als das Zielbild suggeriert.** Solange die
   Attestierung software-basiert ist (`posture_type: software`, Hardware-Attestierung noch nicht
   vollständig spezifiziert), ist der reale Sicherheitsgewinn des Endgeräte-Clients begrenzt. Ein
   striktes Verbot würde heute einen Marktausschluss für einen Schutz erkaufen, der erst mit der
   TPM-Attestierung seine volle Wirkung entfaltet.
3. **Die Unterscheidbarkeit ist der eigentliche Wert.** Ist die Betriebsart im Client Statement
   gekennzeichnet und im PDP-Input auswertbar, können Fachdienste und die gematik risikobasiert
   entscheiden — heute großzügig, später restriktiv, je Fachdienst unterschiedlich. Diese Option
   geht verloren, wenn die Variante entweder verboten (und dann verdeckt praktiziert) oder ununterscheidbar
   zugelassen wird.
4. **Der Wartungsvorteil ist sicherheitsrelevant, nicht nur wirtschaftlich.** Zentrale Patchfähigkeit
   für SDK-Schwachstellen wiegt einen Teil des Attestierungsverlusts auf — Flottenrollouts über
   zehntausende Arbeitsplätze sind erfahrungsgemäß die längere Verwundbarkeitsperiode.

Konkrete Ausgestaltung der Empfehlung:

| Variante | Empfehlung |
|---|---|
| **Endgeräte-Client** | bleibt **Regelfall** und Referenz; Ziel für alle Neuentwicklungen mit lokalem Client |
| **M1 — Lokale Middleware in der Institution** | **zulassen**, mit Kennzeichnung; sicherheitlich weitgehend akzeptabel, da Verantwortungssphäre unverändert |
| **M2 — Cloud-Middleware, eine Instanz je Mandant** | **zulassen unter Auflagen** (Kap. 8, Punkte 1–6), differenzierte Policies, Transparenzpflicht |
| **M3 — Cloud-Middleware, geteilte Instanz über Mandanten** | **nicht zulassen**; Blast Radius und Mandantentrennungsrisiko sind nicht angemessen kompensierbar |
| **ZETA-Funktion im Browser** | **nicht zulassen**; weder Schlüsselhaltung noch Attestierung tragfähig |

Ergänzend wird eine **Perspektivklausel** empfohlen: Sobald die Hardware-Attestierung verfügbar ist,
werden die Policy-Anforderungen für endpunktattestierte Zugriffe angehoben, während
Middleware-Zugriffe auf ihrem Niveau bleiben. Damit entsteht ein wachsender, sachlich begründeter
Anreiz zum Endgeräte-Client, ohne heute einen Marktausschluss auszusprechen.

**Wenn diese Differenzierung nicht umsetzbar ist** — also wenn Kennzeichnung, getrennte Policies und
eigene Zulassung nicht realisierbar sind — **ist Szenario 2 vorzuziehen.** Eine ununterscheidbare
Zulassung von Middleware-Zugriffen entwertet die Attestierungsaussage für alle Teilnehmer und ist
sicherheitlich die schlechteste der drei Möglichkeiten.

---

## 10 Umsetzungsschritte der Empfehlung

| # | Schritt | Artefakt |
|---|---|---|
| 1 | Betriebsarten und Varianten M1/M2 normativ definieren, M3 und Browser-Client ausschließen | gemSpec_ZETA |
| 2 | Client Statement um Kennzeichnung der Betriebsart erweitern (`posture_type` bzw. neues Feld) | [client-statement.yaml](../../src/schemas/client-statement.yaml) |
| 3 | Posture-Schema für Middleware-Plattformen ergänzen (Serverbetrieb, Instanzbezug, Mandanten-ID) | [posture-software.yaml](../../src/schemas/posture-software.yaml), ggf. neues `posture-middleware.yaml` |
| 4 | PDP-Input um die Betriebsart erweitern; `country_code`-Semantik für Middleware klarstellen | [policy-engine-input.yaml](../../src/schemas/policy-engine-input.yaml) |
| 5 | OPA-Regelwerk um betriebsartabhängige Regeln erweitern (Scopes, Token-Lebensdauer, Ratelimits) | [docs/user-manual/Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md](../../docs/user-manual/Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md) |
| 6 | Registrierungsprozess: Betriebsart und Mandantenmodell als Angabe bei der Produktversion | Fachportal / [ReadMePrimaersystemHersteller.md](../../docs/user-manual/ReadMePrimaersystemHersteller.md) |
| 7 | Sicherheitsanforderungen für Middleware-Betreiber ausformulieren (Mandantentrennung, Nord-Schnittstelle, Schlüsselschutz, Meldepflichten) | neu, analog [SicherheitsanforderungenClientHersteller.md](../../docs/user-manual/SicherheitsanforderungenClientHersteller.md) |
| 8 | Betriebs- und Monitoring-Auswirkungen dokumentieren (aggregierte Anomalieerkennung, Sperrgranularität) | [Konzept-Laufzeitueberwachung.md](../../docs/user-manual/Referenzen/Konzept-Laufzeitueberwachung.md) |
| 9 | Hinweis im Produkthandbuch präzisieren — der bestehende Testdriver-Verweis ist derzeit die einzige Aussage zum Cloud-Betrieb und sollte auf die neue Betriebsart verweisen | [ReadMePrimaersystemHersteller.md](../../docs/user-manual/ReadMePrimaersystemHersteller.md) |
| 10 | Transparenzpflicht gegenüber Leistungserbringern festlegen | Zulassungsunterlagen |

---

## 11 Offene Punkte und Entscheidungsbedarf

1. **SM(C)-B im Cloud-Betrieb:** Ist eine zentrale SM-B-Haltung beim PS-Betreiber zulässig, oder muss
   der Konnektor der Institution eingebunden bleiben? Diese Frage ist für die Bewertung von M2
   entscheidend und in dieser Analyse bewusst offengelassen.
2. **Rechtsrahmen:** Auftragsverarbeitung, Haftung und ggf. berufsrechtliche Aspekte beim Zugriff des
   PS-Betreibers auf Patientendaten sind zu klären; sie können die technische Bewertung überstimmen.
3. **Skalierungsmodell der Middleware:** Wie wird der Instanzbegriff bei horizontaler Skalierung
   definiert (Instanz je Pod, geteilter Schlüssel im HSM)? Die Antwort bestimmt Registrierungs- und
   Sperrmechanik.
4. **Zeitpunkt der Perspektivklausel:** Ab welcher Reife der Hardware-Attestierung wird die
   Differenzierung wirksam verschärft?
5. **Bestandsschutz:** Wie werden bereits im Feld befindliche Middleware-Lösungen behandelt, die
   heute ohne Kennzeichnung betrieben werden?
6. **Nachweisbarkeit des Endnutzer-Bezugs:** Soll die durchgereichte Nutzerkennung verpflichtend
   sein, und wie wird verhindert, dass sie als kryptografisch gesicherte Aussage missverstanden wird?
