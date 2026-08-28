# Herstellerintegritätsprüfung bei der TPM-Attestierung — Szenarienanalyse

**Stand:** 2026-08-28 · **Revision 1**
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
