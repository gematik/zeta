# Herstellerintegritätsprüfung bei der TPM-Attestierung — Szenarienanalyse

**Stand:** 2026-08-31 · **Revision 3** (Kapitel 13 ergänzt: technischer Ablauf der ZAS-Signaturprüfung)
**Gegenstand:** Bewertung zweier Grundsatzoptionen dafür, wie der AuthS bei der TPM-Attestierung
prüft, dass die auf dem Client geladene Software tatsächlich vom Hersteller stammt und nicht
manipuliert wurde:
**Szenario 1** — Verwendung eines vom Hersteller gemeldeten TPM-Hash (Gesamthash über die
unveränderlichen Dateien einer Produktversion), abgeglichen gegen den per PCR-Replay ermittelten
Wert;
**Szenario 2** — Verwendung eines Hersteller-Code-Signatur-Schlüssels: der ZAS prüft beim Start
eine Signatur, das Prüfergebnis wird gemessen, der AuthS validiert Zertifikatskette, Sperrstatus
(OCSP) und eine Mindestversion (Rollback-Schutz).
Bewertet nach Entwicklung, Wartung, Betrieb, Auswirkung auf Hersteller und Sicherheit, mit
abgeleiteter Empfehlung.

**Grundlagen dieser Bewertung (Stand Repository):**

| Artefakt | Relevanz |
|---|---|
| [docs/api/v1/index.md, Kapitel 4.1](../api/v1/index.md#41-windows-oder-linux-clients-mit-tpm-attestation) | TPM-Attestierungsablauf (Windows/Linux), Schritt „(04) TPM Attestation Prüfung" |
| [docs/user-manual/ReadMePrimaersystemHersteller.md](../user-manual/ReadMePrimaersystemHersteller.md#registrierung) | Heutiger, manueller Meldeprozess für den TPM-Hash über das gematik-Fachportal |
| [src/schemas/posture-tpm.yaml](../../src/schemas/posture-tpm.yaml) | Posture-Schema für TPM-Attestierung: `tpm_quote`, `tpm_event_log`, `product_version` |
| [src/schemas/policy-engine-client-data.yaml](../../src/schemas/policy-engine-client-data.yaml) | `attestation_result.tpm` — vom AuthS aufbereitete Attestation-Claims für die Policy Engine |
| [src/schemas/zeta-attestation-token.yaml](../../src/schemas/zeta-attestation-token.yaml) | `TpmAttestationToken` — an Fachdienste weitergereichtes Attestierungsergebnis |
| [examples/opa-bundle/products/data.json](../../examples/opa-bundle/products/data.json), [authz.rego](../../examples/opa-bundle/policies/zeta/authz.rego#L52-L59) | Heutiges OPA-Datenmodell für Produkt-/Versions-Allowlist |
| [docs/opa/opa-oci-for-zeta-guard.md](../opa/opa-oci-for-zeta-guard.md) | Verteilmechanismus der OPA-Policy-Bundles (signiert, OCI-Registry) |
| [tmp/docs/00–03](../../tmp/docs/00-uebersicht-herstellerwert-abgleich.md) | Vorarbeiten zu dieser Analyse: verworfene Alternativen (RIM/coRIM, Property-based Attestation), Detailausarbeitung Szenario 2 |

---

## Inhaltsverzeichnis

- [Herstellerintegritätsprüfung bei der TPM-Attestierung — Szenarienanalyse](#herstellerintegritätsprüfung-bei-der-tpm-attestierung--szenarienanalyse)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [1 Ausgangslage](#1-ausgangslage)
  - [2 Was die Herstellerintegritätsprüfung heute tatsächlich zusichert](#2-was-die-herstellerintegritätsprüfung-heute-tatsächlich-zusichert)
  - [3 Ausprägungen von Szenario 2 (Varianten T2a–T2b)](#3-ausprägungen-von-szenario-2-varianten-t2at2b)
  - [4 Szenario 1: TPM-Hash (Gesamthash je Produktversion)](#4-szenario-1-tpm-hash-gesamthash-je-produktversion)
    - [4.1 Entwicklung](#41-entwicklung)
    - [4.2 Wartung](#42-wartung)
    - [4.3 Betrieb](#43-betrieb)
    - [4.4 Auswirkung auf Hersteller](#44-auswirkung-auf-hersteller)
    - [4.5 Sicherheit (Zusammenfassung)](#45-sicherheit-zusammenfassung)
  - [5 Szenario 2: Code-Signatur-Schlüssel-Lösung](#5-szenario-2-code-signatur-schlüssel-lösung)
    - [5.1 Entwicklung](#51-entwicklung)
    - [5.2 Wartung](#52-wartung)
    - [5.3 Betrieb](#53-betrieb)
    - [5.4 Auswirkung auf Hersteller](#54-auswirkung-auf-hersteller)
    - [5.5 Sicherheit (Zusammenfassung)](#55-sicherheit-zusammenfassung)
  - [6 Gegenüberstellung](#6-gegenüberstellung)
  - [7 Sicherheitsanalyse im Detail](#7-sicherheitsanalyse-im-detail)
    - [7.1 Was genau verloren geht](#71-was-genau-verloren-geht)
    - [7.2 Neue Risiken, die entstehen](#72-neue-risiken-die-entstehen)
    - [7.3 Was *nicht* verloren geht](#73-was-nicht-verloren-geht)
  - [8 Kompensierende Maßnahmen für Szenario 2](#8-kompensierende-maßnahmen-für-szenario-2)
  - [9 Empfehlung](#9-empfehlung)
  - [10 Umsetzungsschritte der Empfehlung](#10-umsetzungsschritte-der-empfehlung)
  - [11 Offene Punkte und Entscheidungsbedarf](#11-offene-punkte-und-entscheidungsbedarf)
  - [12 Ergänzende Analyse: Bindung von Version, Signatur und laufendem Prozess](#12-ergänzende-analyse-bindung-von-version-signatur-und-laufendem-prozess)
    - [12.1 Wie stellt der ZAS sicher, dass die laufende PVS-Instanz der signierten Version entspricht?](#121-wie-stellt-der-zas-sicher-dass-die-laufende-pvs-instanz-der-signierten-version-entspricht)
    - [12.2 Warum darf der PCR-/Referenzwert nicht an die Versionsnummer gekoppelt sein?](#122-warum-darf-der-pcr-referenzwert-nicht-an-die-versionsnummer-gekoppelt-sein)
  - [13 Technischer Ablauf der ZAS-Signaturprüfung (Szenario 2)](#13-technischer-ablauf-der-zas-signaturprüfung-szenario-2)
    - [13.1 Aufgabenteilung: ZAS (lokal) vs. AuthS (zentral)](#131-aufgabenteilung-zas-lokal-vs-auths-zentral)
    - [13.2 Windows: Authenticode-Verifikation](#132-windows-authenticode-verifikation)
    - [13.3 Linux: heute offen — Zielarchitektur-Skizze](#133-linux-heute-offen--zielarchitektur-skizze)
    - [13.4 Konstruktion des PCR-Extend-Werts](#134-konstruktion-des-pcr-extend-werts)
    - [13.5 Ablauf bei Fehlschlag der Signaturprüfung](#135-ablauf-bei-fehlschlag-der-signaturprüfung)
    - [13.6 Bezug zu bestehenden Angriffsflächen](#136-bezug-zu-bestehenden-angriffsflächen)

---

## 1 Ausgangslage

Die TPM-Attestierung in ZETA sieht vor, dass der AuthS beim Token Exchange die per TPM-Quote/
Event-Log ermittelten PCR-Werte gegen einen Referenzwert prüft
([docs/api/v1/index.md, Schritt „(04) TPM Attestation Prüfung"](../api/v1/index.md#41-windows-oder-linux-clients-mit-tpm-attestation)).
Ungeklärt ist bislang, **woher** dieser Referenzwert stammt. Die einzige im Repository dokumentierte
Quelle ist ein manueller Meldeprozess: Der Hersteller übermittelt „Liste der unveränderlichen
Dateien, Hashwerte" über das gematik-Fachportal
([ReadMePrimaersystemHersteller.md](../user-manual/ReadMePrimaersystemHersteller.md#registrierung)) —
ausdrücklich als „noch nicht vollständig spezifiziert" gekennzeichnet.

Aus der Praxis liegt dazu ein klarer Einwand der Hersteller vor: Ein Meldevorgang **pro
Produktversion** ist mit modernen, schnellen Release-Zyklen (insbesondere Patches/Hotfixes) nicht
vereinbar und verlangsamt den Rollout neuer Versionen. Daraus ergibt sich die hier bewertete
Grundsatzfrage: Bleibt es bei einem **Hash-basierten Meldeprozess** (ggf. mit Prozessverbesserungen),
oder wird auf eine **Signatur-basierte Prüfung** mit Rollback-Schutz umgestellt, die grundsätzlich
ohne Pro-Version-Meldung auskommt?

Die Fragestellung ist nicht rein technisch: Sie betrifft die Spezifikation
([docs/api/v1/index.md](../api/v1/index.md)), das Datenmodell der Policy Engine
([src/schemas/](../../src/schemas/)), die Kernmesslogik des ZETA Attestation Service (ZAS) und den
Registrierungsprozess der Hersteller gegenüber der gematik gleichermaßen.

---

## 2 Was die Herstellerintegritätsprüfung heute tatsächlich zusichert

| Glied der Kette | Aussage | Durch Szenario 1 (Hash) definiert? | Durch Szenario 2 (Signatur) definiert? |
|---|---|---|---|
| TPM-Quote + Attestation Key | PCR-Wert stammt authentisch von diesem TPM-Chip | ja (unverändert, beide Szenarien identisch) | ja (unverändert, beide Szenarien identisch) |
| PCR-Replay via Event Log | Rechnerische Nachvollziehbarkeit des gemeldeten PCR-Werts | ja (unverändert) | ja (unverändert) |
| Referenzwert für den PCR-Vergleich | Was als „gültiger" Zustand gilt | Gesamthash, manuell gemeldet, Format offen | Signer-Identität + Zertifikatskette, automatisiert erzeugt |
| Registrierungsprozess beim Hersteller | Wie der Referenzwert zur gematik kommt | Formular, pro Produktversion | einmalige Zertifikatsregistrierung, danach kein Pro-Version-Vorgang |
| Rollback-Schutz (alte, verwundbare Version erneut installiert) | — | **nicht vorhanden** | Mindestversion (siehe Kapitel 3) |
| Integrität des ZAS selbst (misst/prüft, bevor es misst) | Ist der Messende vertrauenswürdig? | **nicht spezifiziert** | **nicht spezifiziert** |

Die entscheidende Beobachtung: **Beide Szenarien ändern nur, wonach der AuthS beim PCR-Vergleich
sucht — nicht die TPM-Hardwaremechanik selbst.** Der TPM-Quote-Mechanismus (Attestation Key,
Event-Log-Replay) bleibt in beiden Fällen unverändert und unbetroffen.

Zweite Beobachtung, die für beide Szenarien gleichermaßen gilt und daher **kein
Unterscheidungskriterium** zwischen ihnen ist: Weder der heutige Hash-Ansatz noch der
Signatur-Ansatz verankert die Integrität des ZAS selbst hardwareseitig. Der ZAS ist in beiden Fällen
die Software-Instanz, die entscheidet, was in das PCR geschrieben wird — das TPM validiert diese
Entscheidung nicht gegen. Ein Angreifer mit lokalen Administrator-/Root-Rechten (die der ZAS
laut [4.1.1](../api/v1/index.md#41-windows-oder-linux-clients-mit-tpm-attestation) selbst benötigt)
könnte einen manipulierten ZAS unterschieben, der in beiden Szenarien ein falsches, aber
„erfolgreiches" Prüfergebnis meldet. Diese Lücke ist **unabhängig von der Hash-vs-Signatur-Frage**
und wird in Kapitel 7 gesondert behandelt.

---

## 3 Ausprägungen von Szenario 2 (Varianten T2a–T2b)

Innerhalb von Szenario 2 gibt es eine wesentliche Ausgestaltungsfrage beim Rollback-Schutz, die die
Risikobewertung spürbar verändert:

| Variante | Beschreibung | Umsetzungsaufwand | Schutzwirkung |
|---|---|---|---|
| **T2a — Signierte Mindestversion** | Hersteller signiert gelegentlich eine „Mindestversion", AuthS vergleicht die gemeldete `product_version` dagegen | gering, nutzt vorhandene Signaturinfrastruktur | begrenzt — reine Software-Prüfung, kein hardwareverankerter Zähler |
| **T2b — TPM-NV-Zähler** | Monotoner Zähler im TPM-NVRAM, geräteseitig provisioniert und bei jedem Release inkrementiert | hoch — neue Geräte-Provisionierung, Betriebsprozess für Zähler-Management | stark — hardwareverankert, nicht durch Software-Kompromittierung rückgängig zu machen |

T2a ist der in Kapitel 5 als Ausgangspunkt bewertete, leichtgewichtige Standardfall; T2b wird in
Kapitel 8 als optionale Verstärkung geführt.

---

## 4 Szenario 1: TPM-Hash (Gesamthash je Produktversion)

### 4.1 Entwicklung

**Vorteile**

- **Kein Eingriff in die ZAS-Messlogik.** Der ZAS hasht Dateien und schreibt den Wert ins PCR —
  genau das im Repository bereits skizzierte Verhalten
  ([4.1.1](../api/v1/index.md#41-windows-oder-linux-clients-mit-tpm-attestation)). Es ist keine
  Änderung an einer sicherheitskritischen Komponente nötig.
- **Konzeptionell einfach zu erklären und zu prüfen.** „Hash stimmt überein oder nicht" ist ohne
  PKI-Kenntnisse nachvollziehbar.
- **Keine neue Schlüsselklasse, kein Zertifikatsmanagement** auf Hersteller- oder gematik-Seite
  nötig.

**Nachteile**

- **Format bis heute nicht definiert.** Weder Hash-Algorithmus noch Berechnungsvorschrift für den
  „Gesamthash" sind spezifiziert; das im Anwenderhandbuch selbst als offen markiert
  ([ReadMePrimaersystemHersteller.md](../user-manual/ReadMePrimaersystemHersteller.md#registrierung)).
- **Kein Zielfeld im Datenmodell.** Das OPA-Schema (`allowed_products`,
  [examples/opa-bundle/products/data.json](../../examples/opa-bundle/products/data.json)) kennt nur
  `product_id` → Liste von `product_version`-Strings, kein Hash-Feld.
- **Baseline-Begriff im Ablauf uneindeutig.** Es bleibt unklar, ob der Vergleichswert die lokale,
  selbst etablierte Baseline des Clients oder der gemeldete Hersteller-Hash ist.

### 4.2 Wartung

**Vorteile**

- **Keine Schlüsselrotation zu verwalten** — es gibt keinen Signaturschlüssel, der ablaufen oder
  kompromittiert werden könnte.

**Nachteile**

- **Meldevorgang bei jeder Produktversion.** Ohne die zusätzliche, hier nicht in Szenario 1
  enthaltene Einschränkung auf Major/Minor-Versionen löst jede neue Version — auch Patches und
  Hotfixes — einen manuellen Meldevorgang aus.
- **Kein Rollback-Schutz.** Eine alte, zurückgezogene, aber „passend gehashte" Version kann erneut
  installiert und erfolgreich attestiert werden.
- **Bearbeitungszeit bei gematik bremst den Rollout.** Der Formularprozess über das Fachportal ist
  nicht auf CI/CD-Geschwindigkeit ausgelegt.

### 4.3 Betrieb

**Vorteile**

- **Keine neue Betriebskomponente bei gematik.** Der heutige Formularprozess und die bestehende
  OPA-Bundle-Verteilung ([opa-oci-for-zeta-guard.md](../opa/opa-oci-for-zeta-guard.md)) reichen aus.

**Nachteile**

- **Betriebsprozess ist rein manuell** und skaliert nicht mit der Anzahl der Hersteller und
  Produktversionen.
- **Kein Sperrmechanismus im Vorfall.** Eine als kompromittiert erkannte Version kann nicht zentral
  und sofort gesperrt werden — es gibt keinen äquivalenten Mechanismus zu einer
  Zertifikatssperrliste.

### 4.4 Auswirkung auf Hersteller

**Vorteile**

- **Kein neues technisches Konzept zu implementieren** (Hashing ist Standard-Tooling in jeder
  Build-Pipeline vorhanden).

**Nachteile**

- **Rollout-Verzögerung bei jeder Version.** Genau der eingangs beschriebene Kritikpunkt: Hersteller
  können nicht schneller ausliefern als der gematik-seitige Meldeprozess es zulässt.
- **Unklare Anforderungen erschweren Automatisierung.** Ohne definiertes Format lässt sich der
  Meldevorgang nicht zuverlässig in CI/CD-Pipelines integrieren.

### 4.5 Sicherheit (Zusammenfassung)

- Bindung des Referenzwerts an die Hersteller-Identität ist **nicht kryptografisch abgesichert** —
  die Authentizität hängt allein am Meldekanal (Formular).
- Kein Rollback-Schutz.
- Kein Sperrmechanismus im Kompromittierungsfall.
- Granularität ist grundsätzlich fein (ein Hash pro exakter Version), aber diese Genauigkeit wird
  durch den unklaren Berechnungsalgorithmus faktisch entwertet.

---

## 5 Szenario 2: Code-Signatur-Schlüssel-Lösung

### 5.1 Entwicklung

**Vorteile**

- **Wiederverwendung eines in ZETA bereits etablierten Vertrauensmusters.** Zertifikat + Trust-Store
  + OCSP ist exakt das Modell, das für die SMC-B-Institutionszertifikate bereits produktiv eingesetzt
  wird ([docs/api/v1/index.md, Kapitel 9.2](../api/v1/index.md#9-schlüsselverwaltung)) — kein neues
  Konzept, sondern eine weitere Instanz eines bekannten Musters.
- **Kein externer Standard zu adoptieren.** Anders als ein zwischenzeitlich erwogenes
  Reference-Integrity-Manifest (RIM/coRIM) kommt die Lösung ohne neues Repository-, Serialisierungs-
  oder Betriebskonzept aus (siehe verworfene Alternativen in
  [tmp/docs/00-uebersicht-herstellerwert-abgleich.md](../../tmp/docs/00-uebersicht-herstellerwert-abgleich.md#3-verworfene-alternativen-und-analysepfad)).

**Nachteile**

- **Eingriff in die ZAS-Kernmesslogik.** Der ZAS muss von reiner Hash-Messung auf
  Signaturverifikation umgestellt werden — eine sicherheitskritische Komponente wird verändert, kein
  reiner Prozess-Fix.
- **Linux-Signaturökosystem unausgereift.** Es fehlt ein zu Windows-Authenticode gleichwertiges,
  etabliertes Code-Signing-Verfahren; eine eigene Konvention (z. B. IMA/EVM-basiert) müsste erst
  definiert werden — größtes offenes Umsetzungsrisiko.
- **Neue Schemafelder erforderlich** in
  [posture-tpm.yaml](../../src/schemas/posture-tpm.yaml),
  [policy-engine-client-data.yaml](../../src/schemas/policy-engine-client-data.yaml) und
  [zeta-attestation-token.yaml](../../src/schemas/zeta-attestation-token.yaml)
  (`code_signer_fingerprint`, `code_signature_verified`, `code_signer_trusted`,
  `minimum_version_satisfied`).

### 5.2 Wartung

**Vorteile**

- **Kein Meldevorgang pro Produktversion** — auch nicht bei Major/Minor-Wechseln. Nur die einmalige
  Zertifikatsregistrierung sowie gelegentliche Rotation oder eine seltene
  Mindestversion-Anhebung erfordern Interaktion mit der gematik.
- **Zentrale, sofortige Reaktion im Vorfall.** Eine OCSP-Sperrung des Zertifikats wirkt unmittelbar
  auf alle künftigen Prüfungen — ohne dass einzelne Versionsmeldungen zurückgezogen werden müssen.
- **Rollback-Schutz vorhanden** (Mindestversion, siehe Kapitel 3) — eine Fähigkeit, die Szenario 1
  grundsätzlich fehlt.

**Nachteile**

- **Zertifikatslebenszyklus muss aktiv verwaltet werden** (Rotation alle 2–3 Jahre, Widerrufsprozess),
  auch wenn dieser Aufwand deutlich seltener anfällt als eine Meldung pro Version.
- **Migrationsaufwand für bereits im Feld befindliche Clients**, die auf den bisherigen Hash-Ansatz
  vorbereitet waren.

### 5.3 Betrieb

**Vorteile**

- **Deutlich geringere Betriebslast durch Meldevorgänge** — praktisch keine laufenden
  Pro-Version-Vorgänge mehr, siehe Diagramm in
  [tmp/docs/02-leitfaden-herstellerwert-uebermittlung.md](../../tmp/docs/02-leitfaden-herstellerwert-uebermittlung.md#ablauf-im-überblick-sicht-des-herstellers).
- **Etablierter Betriebsmechanismus wiederverwendbar.** OCSP-Anbindung und Trust-Store-Pflege sind
  bereits für SMC-B vorhanden und lediglich um eine zweite Zertifikatsklasse zu erweitern.

**Nachteile**

- **Neue Betriebskomponente: Hersteller-Trust-Store** beim AuthS, inkl. Registrierungs- und
  Widerrufsprozess — zusätzlich zum bestehenden TSL-Trust-Store zu pflegen.
- **Verfügbarkeitsabhängigkeit vom OCSP-Responder des Hersteller-Zertifikats**, analog zur bereits
  bestehenden Abhängigkeit bei der SMC-B-Sperrprüfung.

### 5.4 Auswirkung auf Hersteller

**Vorteile**

- **Kein Rollout-Bremser mehr.** Signierung ist ein reiner, automatisierbarer Build-Schritt ohne
  Kontakt zur gematik — auch bei Patches und Hotfixes.
- **Klar automatisierbarer Prozess**, geeignet für CI/CD-Integration.

**Nachteile**

- **Einmaliger Umstellungsaufwand** der Build-Pipeline (KMS/HSM-Anbindung, Signing-Service).
- **Neue sicherheitsrelevante Verantwortung:** Der private Signaturschlüssel muss angemessen
  geschützt werden (KMS/HSM); eine Kompromittierung hat größere Tragweite als der Verlust eines
  einzelnen Hash-Meldevorgangs.

### 5.5 Sicherheit (Zusammenfassung)

- Referenzwert ist kryptografisch an eine Hersteller-Identität gebunden (Zertifikat), nicht mehr
  nur an einen Meldekanal.
- Rollback-Schutz vorhanden (Stärke abhängig von der Variante, siehe Kapitel 3).
- Zentraler, sofort wirksamer Sperrmechanismus (OCSP) im Kompromittierungsfall.
- Neuer, hochprivilegierter Vertrauensanker beim Hersteller (Signaturschlüssel) — strukturell
  identisch zum bereits bestehenden Risiko der SMC-B-Institutionszertifikate, siehe Kapitel 7.
- Die in Kapitel 2 beschriebene ZAS-Integritätslücke bleibt **unverändert bestehen** — sie wird
  durch Szenario 2 weder verschärft noch von sich aus geschlossen (siehe Kapitel 7 und 8).

---

## 6 Gegenüberstellung

| Kriterium | Szenario 1 (TPM-Hash) | Szenario 2 (Code-Signatur-Schlüssel) |
|---|---|---|
| Eingriff in ZAS-Messlogik | keiner | ja — Signaturprüfung statt Hash-Extend |
| Meldevorgang bei Patches/Hotfixes | ja, bei jeder Version | nein |
| Meldevorgang bei Major/Minor | ja | nein (nur bei Zertifikatsrotation/Vorfall) |
| Kryptografische Bindung des Referenzwerts | nein | ja (Zertifikat) |
| Rollback-Schutz | nein | ja (T2a/T2b, siehe Kapitel 3) |
| Sperrmechanismus im Vorfall | nicht vorhanden | OCSP-Sperrung, sofort wirksam |
| Wiederverwendung bestehender ZETA-Muster | teilweise (Meldeprozess ähnlich Produkt-ID) | ja (PKI/Trust-Store/OCSP wie SMC-B) |
| Neue Betriebskomponente bei gematik | keine | Hersteller-Trust-Store |
| Format heute spezifiziert | nein | teilweise (Windows ja, Linux offen) |
| Automatisierbarkeit für Hersteller | gering (Formularprozess) | hoch (reiner Build-Schritt) |
| Löst die ZAS-Integritätslücke aus Kapitel 2 | nein | nein (nur durch Kapitel 8 kompensierbar) |

---

## 7 Sicherheitsanalyse im Detail

### 7.1 Was genau verloren geht

Der Umstieg von Szenario 1 auf Szenario 2 verliert nichts an fachlicher Prüftiefe der
Anwendungsintegrität selbst — im Gegenteil, er ergänzt den heute fehlenden Rollback-Schutz. Was sich
ändert, ist die **Art der Fehleranalyse**: Ein Hash-Mismatch zeigt exakt, welches Byte-für-Byte-
Artefakt abweicht; ein Signaturfehler zeigt nur, dass die Signatur ungültig oder der Signer
unbekannt ist, ohne Aussage darüber, *welche* Datei konkret verändert wurde. Für die
Fehlerdiagnose beim Hersteller ist das ein Rückschritt an Detailtiefe, für die reine
Sicherheitsentscheidung des AuthS ist es unerheblich.

### 7.2 Neue Risiken, die entstehen

| Risiko | Szenario 1 (Hash) | Szenario 2 (Signatur) |
|---|---|---|
| Kompromittierter Hersteller-Schlüssel signiert bösartige Software | n/a (kein Schlüssel vorhanden) | **ja** — klassisches Supply-Chain-Risiko, strukturell identisch zum bestehenden SMC-B-Risiko |
| Build-Pipeline vor Signierung kompromittiert | n/a | ja — Signatur bezeugt nur, dass der Hersteller freigegeben hat, nicht dass die Pipeline sauber war |
| Fehlende/unzureichende Linux-Signaturkonvention untergräbt die gesamte Prüfung | n/a | **ja — größtes Einzelrisiko**, siehe Kapitel 5.1 |
| ZAS wird durch Angreifer mit Admin-/Root-Rechten ersetzt oder gepatcht | **ja** (heute bereits vorhanden) | **ja** (unverändert vorhanden, siehe Kapitel 2) |
| Rollback auf alte, verwundbare Version | **ja** (kein Schutz) | abhängig von T2a/T2b (Kapitel 3), aber grundsätzlich adressiert |
| Manuelle Formularmeldung wird sozial manipuliert (falsche Angaben) | ja | entfällt (kein Formularvorgang mehr) |

Die Zeile zum **ZAS-Ersatz** ist die wichtigste Erkenntnis dieser Analyse: Sie ist in **beiden**
Szenarien identisch vorhanden. Ein Sicherheitsgewinn durch den Wechsel zu Szenario 2 entsteht hier
nicht von selbst — er entsteht erst durch die in Kapitel 8 beschriebene, von der
Hash-vs-Signatur-Frage unabhängige Zusatzmaßnahme (Verankerung der ZAS-Integrität via Secure
Boot/Code-Integrity).

### 7.3 Was *nicht* verloren geht

Die TPM-Hardwaremechanik selbst — Attestation Key, `TPM2_Quote`, Event-Log-Replay — bleibt in beiden
Szenarien identisch und unverändert. Ebenso unverändert bleiben die übrigen Glieder der
ZETA-Vertrauenskette (Client-Instanz-Schlüssel, DPoP-Bindung, SM(C)-B-Subject-Token, OPA-
Policy-Auswertung außerhalb der Produkt-/Versionsprüfung). Der Wechsel betrifft ausschließlich die
Herstellerintegritätsprüfung innerhalb des TPM-Attestierungspfads.

---

## 8 Kompensierende Maßnahmen für Szenario 2

Falls Szenario 2 umgesetzt wird, sind folgende Maßnahmen geeignet, die in Kapitel 7 benannten
Risiken zu adressieren. Sie sind nach Wirksamkeit sortiert.

1. **ZAS-Integrität hardwareseitig verankern.** Secure Boot und eine Code-Integrity-Policy (Windows:
   WDAC; Linux: IMA/EVM) müssen bereits vor dem Start des ZAS erzwingen, dass nur signierte Binaries
   geladen werden. Dieser Zustand wird in eine **eigene, frühere PCR-Bank** gemessen, die der AuthS
   zusätzlich zur eigentlichen Anwendungssignaturprüfung validiert. Ohne diese Maßnahme bleibt die
   gesamte Attestierung — unabhängig von Hash oder Signatur — ein reiner Software-Anker.
2. **Linux-Signaturkonvention verbindlich festlegen**, bevor Szenario 2 für Linux-Clients
   freigegeben wird — andernfalls entsteht eine Scheinsicherheit auf dieser Plattform.
3. **KMS/HSM-Pflicht für den Hersteller-Signaturschlüssel**, analog zu den Anforderungen, die bereits
   für andere kryptografische Schlüssel in ZETA gelten.
4. **T2b (TPM-NV-Zähler) für besonders kritische Produktkategorien** erwägen, falls die
   leichtgewichtige Mindestversion (T2a) als nicht ausreichend bewertet wird.
5. **Eigenes Security-Review der geänderten ZAS-Messlogik**, bevor die Spezifikationsänderung final
   freigegeben wird — jede Änderung an einer sicherheitskritischen Kernkomponente sollte diesem
   Prozess unterliegen, unabhängig vom sonstigen Zeitdruck.
6. **Migrationsplan für bereits ausgelieferte Clients**, die auf den heutigen (unspezifizierten)
   Hash-Ansatz vorbereitet waren.

Maßnahme 1 ist die entscheidende: Ohne sie bleibt der in Kapitel 7.2 benannte ZAS-Ersatz-Angriff in
beiden Szenarien unverändert offen, und der Sicherheitsgewinn von Szenario 2 beschränkt sich auf
Rollback-Schutz und Sperrmechanismus, ohne die eigentliche Vertrauenswurzel zu stärken.

---

## 9 Empfehlung

**Empfohlen wird Szenario 2 (Code-Signatur-Schlüssel-Lösung), jedoch nur zusammen mit Maßnahme 1 aus
Kapitel 8 (ZAS-Integritätsverankerung über Secure Boot/Code-Integrity) und vorbehaltlich einer
Klärung der Linux-Signaturkonvention.**

Begründung:

1. **Szenario 1 löst das eigentliche Problem nicht und kann es strukturell nicht lösen.** Ein
   Formular-basierter Meldeprozess ist unabhängig von seiner konkreten Ausgestaltung mit schnellen
   Release-Zyklen nicht vereinbar; das ist der ursprüngliche, unbestrittene Ausgangspunkt dieser
   Bewertung.
2. **Szenario 2 verwendet ein in ZETA bereits bewährtes Vertrauensmodell**, statt einen neuen,
   unreifen externen Standard zu adoptieren (siehe verworfene RIM/coRIM-Alternative in
   [tmp/docs/00-uebersicht-herstellerwert-abgleich.md](../../tmp/docs/00-uebersicht-herstellerwert-abgleich.md)).
3. **Der Rollback-Schutz ist ein echter Sicherheitsgewinn**, den Szenario 1 grundsätzlich nicht
   bieten kann.
4. **Die ZAS-Integritätslücke ist kein Gegenargument gegen Szenario 2** — sie besteht in Szenario 1
   identisch. Sie ist aber ein zwingendes Argument dafür, Szenario 2 **nicht isoliert**, sondern nur
   zusammen mit Maßnahme 1 umzusetzen, da sonst ein falscher Eindruck von Sicherheitsgewinn entsteht.
5. **Die Linux-Signaturfrage ist der einzige Punkt, der eine vollständige, plattformübergreifende
   Umsetzung heute verhindert** — hierzu wird eine gesonderte, zeitnahe Klärung empfohlen, bevor
   Szenario 2 für Linux-Clients verbindlich wird.

**Wenn Maßnahme 1 (ZAS-Integritätsverankerung) nicht umsetzbar ist**, sollte Szenario 2 dennoch
umgesetzt werden — der Rollback-Schutz und die Ablösung des unspezifizierten Formularprozesses sind
bereits für sich genommen ein Fortschritt gegenüber Szenario 1 —, jedoch **mit der ausdrücklichen
Einschränkung**, dass die Herstellerintegritätsprüfung dann weiterhin, wie heute auch, ein
Software-Anker bleibt und nicht als vollwertige Hardware-Attestierung kommuniziert werden darf.

---

## 10 Umsetzungsschritte der Empfehlung

| # | Schritt | Artefakt |
|---|---|---|
| 1 | Ablaufschritt (04) und neuen Abschnitt „Herstellerintegritätsprüfung" in die Spezifikation übernehmen | [docs/api/v1/index.md](../api/v1/index.md), siehe [tmp/docs/01](../../tmp/docs/01-spezifikationsaenderung-herstellerwert-abgleich.md) |
| 2 | Schema-Ergänzungen übernehmen (`code_signer_fingerprint`, `code_signature_verified`, `code_signer_trusted`, `minimum_version_satisfied`) | [posture-tpm.yaml](../../src/schemas/posture-tpm.yaml), [policy-engine-client-data.yaml](../../src/schemas/policy-engine-client-data.yaml), [zeta-attestation-token.yaml](../../src/schemas/zeta-attestation-token.yaml) |
| 3 | OPA-Datenmodell auf Hersteller-Trust-Anchor umstellen (`trusted_code_signers`, `minimum_version`) | `products.json` (z. B. [examples/opa-bundle/products/data.json](../../examples/opa-bundle/products/data.json)) |
| 4 | Leitfaden für Hersteller zur Zertifikatsregistrierung veröffentlichen | [tmp/docs/02](../../tmp/docs/02-leitfaden-herstellerwert-uebermittlung.md) → künftig `docs/user-manual/Anleitungen/` |
| 5 | ZAS-Integritätsverankerung (Secure Boot/WDAC bzw. IMA-EVM) spezifizieren und Security-Review beauftragen | neu, ZAS-Verantwortliche |
| 6 | Linux-Signaturkonvention festlegen | neu |
| 7 | Rollback-Schutz-Variante (T2a vs. T2b) verbindlich entscheiden | siehe Kapitel 3 |
| 8 | Migrationsplan für bereits ausgelieferte Clients erstellen | neu |

---

## 11 Offene Punkte und Entscheidungsbedarf

1. **Linux-Signaturkonvention:** Welches konkrete Verfahren (IMA/EVM, dm-verity-Stil, eigene
   gematik-Konvention) wird verbindlich festgelegt?
2. **Rollback-Mechanismus:** T2a (signierte Mindestversion) oder T2b (TPM-NV-Zähler) — oder je nach
   Produktkategorie unterschiedlich?
3. **Umfang der ZAS-Integritätsverankerung:** Ist eine vollständige WDAC-/IMA-Durchsetzung für alle
   unterstützten Primärsysteme realistisch durchsetzbar, oder wird ein abgestuftes Modell benötigt?
4. **Schlüsselgranularität:** Ein Signaturzertifikat je `product_id` (wie in
   [tmp/docs/01](../../tmp/docs/01-spezifikationsaenderung-herstellerwert-abgleich.md) vorgeschlagen)
   oder je Hersteller-Organisation?
5. **Migration bestehender Clients:** Wie werden bereits im Feld befindliche, auf den heutigen
   Hash-Ansatz vorbereitete Installationen übergeleitet — Parallelbetrieb oder harter Cutover?
6. **Aufwand-Nutzen-Abwägung der KMS-/HSM-Pflicht** für kleinere Primärsystemhersteller ohne
   vorhandene Signing-Infrastruktur.
7. **Extraktion von `product_version` aus dem signierten Artefakt:** Ist das für alle unterstützten
   Primärsystem-Technologiestacks (native PE-Binaries, aber auch z. B. .NET-Assemblies oder
   interpretierte/gehostete Laufzeiten) einheitlich möglich? Siehe [Kapitel 12.1](#121-wie-stellt-der-zas-sicher-dass-die-laufende-pvs-instanz-der-signierten-version-entspricht).
8. **Enforcement- vs. Audit-Modus von WDAC/IMA-EVM (Maßnahme 1, Kapitel 8):** Nur im
   Enforcement-Modus schließt sich die in Kapitel 12.1 beschriebene TOCTOU-Lücke tatsächlich; das
   muss als verbindliche Anforderung und nicht nur als Empfehlung festgeschrieben werden.
9. **Fehlerfall-Verhalten der ZAS-Signaturprüfung:** Erweitert der ZAS das PCR bei ungültiger
   Signatur mit einem expliziten „nicht verifiziert"-Wert (empfohlen, siehe
   [Kapitel 13.5](#135-ablauf-bei-fehlschlag-der-signaturprüfung)), oder erzwingt er einen
   vollständigen Fallback auf Software-Attestation? Muss verbindlich festgelegt werden.
10. **Exaktes PCR-Extend-Format (Kapitel 13.4):** Der in dieser Analyse skizzierte Messwert
    (`code_signer_fingerprint` + Ergebnis-Flag) ist ein Vorschlag und muss mit den
    ZAS-Verantwortlichen sowie im Security-Review (Maßnahme 5, Kapitel 8) verbindlich abgestimmt
    werden.

---

## 12 Ergänzende Analyse: Bindung von Version, Signatur und laufendem Prozess

Zwei Nachfragen zeigen, dass Kapitel 3–8 zwar den Referenzwert selbst (Hash vs. Zertifikat)
bewerten, aber noch nicht explizit machen, (a) **woran** der ZAS die Signaturprüfung tatsächlich
festmacht und (b) **was** konkret in das PCR extended werden darf, ohne den Kernvorteil von
Szenario 2 wieder zu verlieren. Beide Punkte sind Voraussetzung dafür, dass Szenario 2 in der Praxis
das hält, was Kapitel 5–6 ihm zuschreiben.

### 12.1 Wie stellt der ZAS sicher, dass die laufende PVS-Instanz der signierten Version entspricht?

**Problem:** Eine Code-Signaturprüfung beweist zunächst nur, dass *eine bestimmte Datei* vom
Hersteller signiert wurde. Sie beweist nicht automatisch,

1. dass genau diese Datei auch das ist, was aktuell als Prozess im Speicher läuft (Verify-then-Load-
   Lücke/TOCTOU: DLL-Side-Loading, Prozess-Hollowing, nachträgliches In-Memory-Patching nach dem
   Laden), und
2. dass die separat gemeldete `product_version` — heute in
   [posture-tpm.yaml](../../src/schemas/posture-tpm.yaml) ein eigenständiges, freies String-Feld —
   tatsächlich zu genau dem signierten/geladenen Artefakt gehört. `product_version` ist im
   heutigen Schema **nicht kryptografisch an `tpm_quote`/eine künftige `code_signature_verified`
   gebunden**. Ein kompromittierter oder fehlerhafter ZAS könnte grundsätzlich „Signatur gültig"
   und eine falsche (z. B. ältere, bereits zurückgezogene) `product_version` gleichzeitig melden,
   ohne dass AuthS oder Policy Engine das anhand der heutigen Felder erkennen könnten.

**Erforderliche Bausteine, damit Szenario 2 diese Bindung tatsächlich leistet:**

1. **Version MUSS aus dem signierten Artefakt selbst gelesen werden, nicht als separates,
   unabhängiges Feld gemeldet werden.** Der ZAS darf `product_version` nicht als freie Eingabe
   übernehmen, sondern muss sie aus denselben Metadaten extrahieren, die von der Signatur
   mit-abgedeckt sind (z. B. bei Windows-Authenticode ist die Versionsressource Teil der gehashten
   PE-Datei; unter Linux müsste eine Versionsangabe analog in das signierte bzw. IMA-gemessene
   Artefakt eingebettet werden — siehe die in Kapitel 5.1 und 8.2 benannte offene
   Linux-Signaturkonvention). Jede Abweichung zwischen behaupteter und tatsächlich signierter
   Version wird dadurch bereits als Signaturfehler sichtbar, statt unbemerkt zu bleiben.
2. **Die Bindung „geprüfte Datei = laufender Prozess" MUSS auf OS-/Kernel-Ebene erzwungen werden,
   nicht durch eine nachträgliche ZAS-Prüfung.** Das ist der eigentliche Zweck von **Maßnahme 1**
   aus Kapitel 8 (Secure Boot + WDAC/IMA-EVM) — allerdings **nur im Enforcement-Modus**: Nur dort
   verhindert das Betriebssystem selbst das Laden jeder Binärdatei, deren Signatur nicht zum
   erwarteten Herausgeber passt, wodurch eine Diskrepanz zwischen „was signiert wurde" und „was
   tatsächlich läuft" bereits strukturell ausgeschlossen ist. Im (schwächeren) Audit-Modus wird eine
   Abweichung nur protokolliert, aber nicht verhindert — die ZAS-Prüfung bliebe dann ein
   nachträglicher, durch denselben Angreifer umgehbarer Check. Dieser Unterschied ist in Kapitel 8
   bisher nicht explizit benannt und sollte als verbindliche Anforderung (Enforcement, nicht Audit)
   ergänzt werden (siehe neuer Offener Punkt 8 in Kapitel 11).
3. **Messung muss am tatsächlich überwachten Prozess ansetzen, nicht an einem beliebigen
   Installationsartefakt.** Das ZAS-Modell sieht laut
   [5.3.1.2](../api/v1/index.md#41-windows-oder-linux-clients-mit-tpm-attestation) bereits ein
   kontinuierliches Monitoring des Primärsystem-Prozesses vor; die Signaturprüfung muss an genau
   diesem überwachten Prozess-Image ansetzen (Pfad/Hauptmodul des laufenden Prozesses), nicht an
   einer separat abgelegten Kopie des Installationspakets.

**Residuales Risiko, das auch mit allen drei Bausteinen bleibt:** Bei technologischen Stacks, in
denen die eigentliche Anwendungslogik nicht in der signierten Host-Binärdatei selbst liegt, sondern
in nachträglich geladenem, nicht mitsigniertem Code (z. B. interpretierte Skripte, dynamisch
geladene Plugins, gemanagte Assemblies ohne durchgängige Signaturkette), greift Baustein 1 nicht
vollständig — die Versionsangabe des eigentlich sicherheitsrelevanten Codes wäre dann weiterhin
nicht verifizierbar an die Signatur gebunden. Dies ist als **neuer Offener Punkt 7** in Kapitel 11
aufgenommen, da eine plattform-/technologieübergreifende Antwort noch aussteht.

### 12.2 Warum darf der PCR-/Referenzwert nicht an die Versionsnummer gekoppelt sein?

Die Beobachtung ist zutreffend und beschreibt exakt den in Kapitel 1 und 4 hergeleiteten
Kernnachteil von **Szenario 1**: Dort ist der PCR-Wert ein Hash über die unveränderlichen Dateien
*einer bestimmten Produktversion* — jede neue Version (auch ein reines Minor-Update oder ein
Hotfix) ändert diesen Hash und würde, konsequent zu Ende gedacht, einen neuen Meldevorgang
erzwingen. Genau dieser Mechanismus ist der Ausgangspunkt der gesamten Analyse (Kapitel 1) und der
Grund, warum Szenario 1 in Kapitel 4.2/4.4 als mit modernen Release-Zyklen unvereinbar bewertet
wird.

**Deshalb darf in Szenario 2 nicht derselbe Fehler wiederholt werden.** Wie in
[tmp/docs/01, Abschnitt 3](../../tmp/docs/01-spezifikationsaenderung-herstellerwert-abgleich.md#3-zielarchitektur-code-signing-statt-hash-vergleich)
bereits angelegt, erweitert der ZAS das PCR in Szenario 2 **nicht** mit einem rohen Datei-/
Versions-Hash, sondern mit dem **Prüfergebnis der Signaturverifikation** (Signer-Identität,
z. B. Zertifikats-Fingerabdruck + Status „verifiziert"). Dieser Wert bleibt über beliebig viele
Minor-/Patch-Releases hinweg **identisch**, solange derselbe Hersteller-Signaturschlüssel verwendet
wird — er ändert sich nur bei Schlüsselrotation oder Vorfall, nicht bei jedem Release. Das löst das
in der Frage benannte Problem strukturell, statt es zu kompensieren.

Die konkrete Versionsinformation geht dabei **nicht verloren** — sie wird nur nicht mehr für den
PCR-Referenzwertvergleich verwendet:

- `product_version` wird (nach Baustein 1 aus Kapitel 12.1) aus dem signierten Artefakt extrahiert
  und als eigenes, separates Feld an den AuthS gemeldet.
- Der AuthS prüft sie nicht auf Gleichheit gegen einen fixen Referenzwert, sondern als
  **Ordnungsvergleich** gegen `minimum_version` (`minimum_version_satisfied`, siehe
  [tmp/docs/01, Abschnitt 4](../../tmp/docs/01-spezifikationsaenderung-herstellerwert-abgleich.md#4-vorgeschlagene-schema-ergänzungen)) —
  also „ist die gemeldete Version mindestens so neu wie X", nicht „ist die gemeldete Version exakt
  gleich X". `minimum_version` wird dabei nur bei einem bewussten Zurückziehen einer als
  fehlerhaft/kompromittiert erkannten Version angehoben, nicht bei jedem regulären Release.
- Auch der in Kapitel 3 beschriebene TPM-NV-Zähler (T2b) ist bewusst ein reiner, vom Hersteller bei
  sicherheitsrelevanten Releases inkrementierter monotoner Zähler **ohne semantische Bindung** an
  Major/Minor/Patch — auch hier wird dieselbe Kopplungsproblematik absichtlich vermieden.

**Leitplanke für die Umsetzung:** Sollte in einer konkreten Implementierung dennoch erwogen werden,
einen versionsabhängigen Hash weiterhin in das PCR zu extenden (etwa aus Kompatibilitäts- oder
Übergangsgründen zu Szenario 1), wäre das ein Rückfall in exakt das Problem, das Szenario 2 lösen
soll, und sollte explizit vermieden werden.

---

## 13 Technischer Ablauf der ZAS-Signaturprüfung (Szenario 2)

Kapitel 5 und 12 begründen *warum* auf Signaturprüfung umgestellt wird und *woran* sie gebunden sein
muss. Dieses Kapitel beschreibt *wie* der ZAS die Prüfung konkret durchführt — als Präzisierung für
die Sicherheitsbewertung. **Wichtig:** Nur die Windows-Umsetzung (13.2) stützt sich auf ein
etabliertes, produktiv genutztes Verfahren (Authenticode). Die Linux-Skizze (13.3) sowie das
PCR-Extend-Format (13.4) sind **Vorschläge dieser Analyse, kein abgestimmter Beschluss** — beides
ist bereits als offener Punkt in Kapitel 11 (Punkte 1, 9, 10) geführt.

### 13.1 Aufgabenteilung: ZAS (lokal) vs. AuthS (zentral)

Die Prüfung ist bewusst zweigeteilt, konsistent mit Kapitel 3.1 aus
[tmp/docs/01](../../tmp/docs/01-spezifikationsaenderung-herstellerwert-abgleich.md):

| Prüfschritt | Wo | Warum dort |
|---|---|---|
| Kryptografische Signaturgültigkeit der Datei (Hash-Bindung) | **ZAS, lokal** | Braucht keine Netzwerkverbindung, muss auch bei jedem PVS-Start ohne Latenz laufen |
| Extraktion Signer-Identität (Zertifikats-Fingerabdruck) | **ZAS, lokal** | Reines Auslesen, keine Vertrauensentscheidung nötig |
| Extraktion `product_version` aus dem signierten Artefakt | **ZAS, lokal** | Muss aus derselben Datei kommen, die gerade geprüft wurde (Kapitel 12.1) |
| Ist der Signer vertrauenswürdig? (Kettenvalidierung gegen Hersteller-Trust-Store) | **AuthS, zentral** | Der Trust-Store ist eine gematik-seitig gepflegte, zentrale Ressource, kein Client-Artefakt |
| Sperrstatus (OCSP) | **AuthS, zentral** | Erfordert Netzwerkzugriff auf den OCSP-Responder; ZAS-Umgebungen sind ggf. netzwerkeingeschränkt |
| Mindestversion-Vergleich (`minimum_version_satisfied`) | **AuthS, zentral** | Mindestversion wird zentral über die gematik/OPA-Bundle-Distribution verteilt, nicht clientseitig gepflegt |

Der ZAS liefert also **nur Fakten** (Signatur kryptografisch gültig ja/nein, welcher Signer,
welche Version), **keine Vertrauensbewertung** — die Bewertung bleibt vollständig beim AuthS. Das
hält die ZAS-Logik einfach und auditierbar und vermeidet, dass jede Client-Installation einen
aktuellen Hersteller-Trust-Store und OCSP-Konnektivität benötigt.

### 13.2 Windows: Authenticode-Verifikation

1. **Zielartefakt bestimmen:** Der ZAS ermittelt den Dateipfad des Hauptmoduls des Prozesses, den er
   laut [5.3.1.2](../api/v1/index.md#41-windows-oder-linux-clients-mit-tpm-attestation) ohnehin
   kontinuierlich überwacht — nicht eine separat abgelegte Kopie des Installationspakets (siehe
   Kapitel 12.1, Baustein 3).
2. **Signatur prüfen:** Aufruf von `WinVerifyTrust()` mit `WINTRUST_ACTION_GENERIC_VERIFY_V2` und
   `WTD_CHOICE_FILE` auf genau dieser Datei. Das validiert:
   - dass der Authenticode-Hash der Datei (SHA-256 über die PE-Datei, ausgenommen Checksum-Feld und
     Zertifikatstabelle) mit dem im eingebetteten PKCS#7-Blob signierten Hash übereinstimmt (Datei
     seit Signierung unverändert),
   - dass sich strukturell eine Zertifikatskette zum eingebetteten Aussteller aufbauen lässt
     (`CertGetCertificateChain`).
   - Bewusst **`WTD_REVOKE_NONE`**: keine Sperrprüfung im ZAS selbst — das ist laut 13.1 Aufgabe des
     AuthS (OCSP), um den PVS-Start nicht von Netzwerkverfügbarkeit abhängig zu machen.
   - Der ZAS entscheidet an dieser Stelle **nicht**, ob die Wurzel vertrauenswürdig ist — er prüft
     nur die kryptografische Konsistenz der eingebetteten Signatur.
3. **Signer-Identität extrahieren:** SHA-256-Fingerabdruck des Leaf-Zertifikats →
   `code_signer_fingerprint`.
4. **Version aus derselben Datei lesen:** Die `VS_VERSIONINFO`-Ressource ist Bestandteil der
   Authenticode-gehashten PE-Datei — der ZAS liest `product_version` aus dieser Ressource, **nicht**
   aus einem separaten, unabhängigen Feld (setzt Kapitel 12.1, Baustein 1 um).
5. **Ergebnis:** `code_signature_verified` (Schritt 2 erfolgreich), `code_signer_fingerprint`
   (Schritt 3), `product_version` (Schritt 4) — alle drei fließen in das Client Statement
   ([posture-tpm.yaml](../../src/schemas/posture-tpm.yaml)) und in den PCR-Extend-Wert (13.4) ein.

### 13.3 Linux: heute offen — Zielarchitektur-Skizze

Es gibt noch **keine** verbindliche gematik-Konvention (Offener Punkt 1, Kapitel 11); die
Linux-Unreife ist laut Kapitel 5.1/8.2 das größte Einzelrisiko von Szenario 2. Skizze eines
IMA/EVM-basierten Zielbilds, damit die Sicherheitsbewertung nicht im Vagen bleibt:

- **IMA (Integrity Measurement Architecture):** Jede Datei trägt ein `security.ima`-Erweiterungsattribut
  mit einem signierten Datei-Hash. Der öffentliche Prüfschlüssel liegt im Kernel-Keyring, das seinerseits
  beim Boot über Secure Boot/MOK abgesichert sein muss.
- **EVM (Extended Verification Module):** Schützt die Erweiterungsattribute selbst (inkl.
  `security.ima`) gegen Offline-Manipulation am ruhenden Dateisystem.
- Der ZAS würde **nicht** selbst eine eigene PKCS#7-Prüfung implementieren, sondern den vom Kernel
  bereits ermittelten IMA-Appraisal-Status des laufenden Prozess-Binaries auslesen (z. B. über
  `securityfs`/Audit-Log) — die eigentliche Durchsetzung bleibt im Kernel (Enforcement-Modus, siehe
  Kapitel 12.1 Baustein 2), nicht im ZAS-Userspace-Code.
- Versionsauslesung analog zu 13.2 Schritt 4 müsste ebenfalls aus einem signatur-/IMA-gedeckten
  Artefakt erfolgen (z. B. eingebettete ELF-Metadaten oder ein signiertes Begleitmanifest) — Format
  ist nicht spezifiziert.

### 13.4 Konstruktion des PCR-Extend-Werts

Damit Kapitel 12.2 gilt (PCR-Wert darf sich nicht bei jedem Minor-/Patch-Release ändern), darf **nicht**
die Datei oder die Version gehasht werden, sondern ausschließlich das Prüfergebnis:

```text
Messwert = SHA-256( "ZETA-CODE-SIG-v1" || code_signer_fingerprint || Ergebnis-Flag )
Ergebnis-Flag = 0x01, wenn code_signature_verified == true, sonst 0x00
```

Dieses konkrete Format ist ein **Vorschlag dieser Analyse** (neuer Offener Punkt 10, Kapitel 11) und
noch mit den ZAS-Verantwortlichen sowie im Security-Review (Maßnahme 5, Kapitel 8) abzustimmen.
Entscheidend ist nur die Eigenschaft: Der Wert hängt ausschließlich von `code_signer_fingerprint`
und dem Prüfergebnis ab — er ändert sich über beliebig viele Minor-/Patch-Releases **nicht**,
sondern ausschließlich bei Zertifikatsrotation oder einem fehlgeschlagenen Prüfergebnis.

### 13.5 Ablauf bei Fehlschlag der Signaturprüfung

Bislang nirgends spezifiziert (neuer Offener Punkt 9, Kapitel 11) — zwei Optionen:

- **Option A (empfohlen):** Der ZAS extended das PCR trotzdem, aber mit Ergebnis-Flag `0x00`
  („nicht verifiziert"). Der Vorgang wird dadurch nicht verschleiert, sondern über
  `code_signature_verified = false` im Client Statement und im Event Log sichtbar und vom AuthS
  auswertbar zurückweisbar.
- **Option B:** Der ZAS verweigert die PCR-Nutzung vollständig und erzwingt den Fallback auf reine
  Software-Attestation — analog zum bestehenden „PCR bereits belegt"-Fallback in
  [5.3.1.1.1](../api/v1/index.md#41-windows-oder-linux-clients-mit-tpm-attestation).

Option A wird empfohlen, weil sie einen aktiven Manipulationsversuch nicht wie einen harmlosen
Fallback aussehen lässt, sondern explizit und auswertbar protokolliert.

### 13.6 Bezug zu bestehenden Angriffsflächen

Dieser Mechanismus ändert nichts an der in Kapitel 2 und 7 beschriebenen ZAS-Ersatz-Lücke: Ein durch
einen Angreifer mit Admin-/Root-Rechten unterschobener, manipulierter ZAS könnte Schritt 13.2/13.3
schlicht überspringen und trotzdem `code_signature_verified = true` in das PCR extenden — er
kontrolliert ja selbst, was gemessen wird. Genau deshalb bleibt **Maßnahme 1** (Secure Boot +
WDAC/IMA-EVM, zwingend im **Enforcement-Modus**, siehe Kapitel 12.1 Baustein 2) die Voraussetzung
dafür, dass der hier beschriebene Ablauf tatsächlich das leistet, was Kapitel 5–6 ihm zuschreiben.
