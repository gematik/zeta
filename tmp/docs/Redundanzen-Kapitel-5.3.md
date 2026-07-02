# Übersicht: Redundanzen in Kapitel 5.3 (gemSpec_ZETA, Version 1.3.0)

Diese Übersicht listet inhaltliche Doppelungen und Wiederholungen im Kapitel 5.3 „ZETA Abläufe"
auf. Ziel ist es, Kandidaten für Konsolidierung (Zusammenführen, Verweisen statt Wiederholen) zu
identifizieren. Grundlage ist der extrahierte Text aus `gemSpec_ZETA_1.3.0.pdf` (Seiten 36–66).

## Struktur des Kapitels (zur Orientierung)

- 5.3.1 Abläufe für stationäre Clients (5.3.1.1 – 5.3.1.7)
- 5.3.2 Abläufe für mobile Clients (5.3.2.1 – 5.3.2.4)
- 5.3.3 Dienst-zu-Dienst-Kommunikation
- 5.3.4 Überblick über den Attestierungslebenszyklus (bereits als „zu entfernen" markiert)

---

## 1. Doppelte Beschreibung der macOS/Apple-Schlüsselgenerierung

| Fundstelle | Abbildung | Inhalt |
| --- | --- | --- |
| 5.3.1.1.2 Schlüsselgenerierung auf macOS Systemen | Abb. 5 `Abb-ZETA-Schlüsselgenerierung-macOS` | Secure-Enclave-Pfad + SW-Fallback |
| 5.3.2.1.2 Apple Secure Enclave | Abb. 18 `Abb-ZETA-Schlüsselgenerierung-macOS` | Secure-Enclave-Pfad + SW-Fallback |

- **Identischer Inhalt**: 5.3.2.1.2 stellt selbst fest: „Der Vorgang ist für mobile und stationäre
  Clients identisch (iOS, iPadOS, macOS)."
- **Dieselbe Abbildung** (`Abb-ZETA-Schlüsselgenerierung-macOS`) wird unter zwei Nummern (5 und 18)
  zweimal eingebunden.
- **Empfehlung**: Apple-Schlüsselgenerierung nur einmal beschreiben, aus dem mobilen Kapitel per
  Verweis referenzieren (analog zu 5.3.2.2, siehe Punkt 8).

## 2. Doppelte Beschreibung der Apple-Attestierung (Secure Enclave / App Attest)

Die Apple-Attestierung wird an **drei** Stellen behandelt:

| Fundstelle | Abbildung | Form |
| --- | --- | --- |
| 5.3.1.4.2 Secure Enclave | Abb. 9 `Abb-ZETA-SE-Attestation-Key` | Erzeugung Apple Attestation Object |
| 5.3.1.6.2 Client Statement mit Apple AppAttest | Abb. 12 `Abb-ZETA-Client-Statement-mit-Apple-AppAttest` | Nonce → Posture → Hash → SE-Signatur → Object → Validierung |
| 5.3.2.3.2 Apple | (kein Diagramm) | Nonce → Posture → Hash → SE-Signatur → Object → Validierung |

- 5.3.2.3.2 (mobil, Prosa) wiederholt nahezu wortgleich den Ablauf aus 5.3.1.6.2: identische Schritte
  Nonce-Anforderung, Posture-Erhebung, `clientDataHash = Hash(Nonce + Posture)`, Signatur in der
  Secure Enclave inkl. Counter, Erstellung des Attestation Objects, Validierung (Apple-Zertifikatskette,
  Hash-Rekonstruktion, Signatur- und Counter-Prüfung).
- **Empfehlung**: Apple-Attestierung einmal kanonisch beschreiben; mobile/stationäre Kapitel
  verweisen darauf.

## 3. Parallele Attestierungs-Beschreibungen mobil vs. stationär (TPM/Android)

| Stationär | Mobil | Gemeinsames Muster |
| --- | --- | --- |
| 5.3.1.6.1 Client Statement mit ZAS und TPM | 5.3.2.3.1 Android | Nonce → Posture/Evidence → Signatur → Übermittlung → Validierung |

- Beide beschreiben dasselbe konzeptionelle Muster (nonce-basierter, hardwaregebundener
  Integritätsnachweis), nur mit anderer Hardware (TPM vs. TEE/StrongBox).
- Die mobilen Abschnitte 5.3.2.3.x liegen ausschließlich als Prosa vor und duplizieren das bereits
  in 5.3.1.6.x (mit Diagrammen) erläuterte Konzept.

## 4. Mehrfach wiederholtes Attestierungs-Grundmuster (Nonce → Posture → Sign → Submit → Validate)

Das immer gleiche fünfstufige Attestierungsmuster ist in **fünf** Abschnitten ausformuliert:

- 5.3.1.6.1 (TPM, Client Statement)
- 5.3.1.6.2 (Apple AppAttest, Client Statement)
- 5.3.2.3.1 (Android)
- 5.3.2.3.2 (Apple)
- 5.3.2.3.3 (Software-Attestierung)

- **Empfehlung**: Das generische Muster einmal zentral beschreiben und je Plattform nur die
  Abweichungen (verwendete API, Schlüssel, Artefakte) auflisten.

## 5. Software-Attestation-Fallback an vielen Stellen wiederholt

Die Aussage „Schlüssel im Software-Kontext erzeugt, kein Hardware-Schutz, geringerer Sicherheitsgrad,
nur unter zusätzlicher Policy-Prüfung" taucht u. a. auf in:

- 5.3.1.1.1 (Schritte 14–15, Windows/Linux SW-Fallback)
- 5.3.1.1.2 (Schritt 06, macOS SW-Fallback)
- 5.3.1.6.1 (Schritt 10, SW client_statement)
- 5.3.1.6.2 (Schritt 11, SW client_statement)
- 5.3.2.1.2 (Schritt 06, Apple SW-Fallback)
- 5.3.2.3.3 (eigener Unterabschnitt Software-Attestierung)

- **Empfehlung**: Den Software-Fallback einmal grundsätzlich beschreiben (Eigenschaften,
  Sicherheitsniveau, Policy-Konsequenz) und an den Einzelstellen nur referenzieren.

## 6. DPoP-Erläuterung mehrfach ausformuliert

Die vollständige Erklärung von DPoP („Demonstrating Proof-of-Possession", Signatur zum Schutz des
Access Tokens vor Diebstahl/Replay, an Ziel-URL gebunden) ist mehrfach ausgeschrieben:

- 5.3.1.6.3 (Schritte 04–05)
- 5.3.1.6.4 (Schritt 01)
- 5.3.1.7.1 (Schritt 03)
- 5.3.1.7.2 (Schritt 03)

- **Empfehlung**: DPoP einmal im Glossar/Grundlagenteil erklären, danach nur den Begriff verwenden.

## 7. Identische „Vorbedingung Access Token" mehrfach

Die Vorbedingung „Der ZETA Client hat den Authentifizierungsprozess erfolgreich durchlaufen und
besitzt ein gültiges Access Token" steht nahezu wortgleich in:

- 5.3.1.7 (Einleitung)
- 5.3.1.7.1 (Vorbedingung mit ZETA/ASL)
- 5.3.1.7.2 (Vorbedingung ohne ZETA/ASL)

- **Empfehlung**: Einmal in der Einleitung 5.3.1.7 nennen, in den Unterabschnitten weglassen.

## 8. Identische „Policy-Entscheidung und Response"-Struktur im Token Exchange

5.3.1.6.3 (Token Exchange mit Attestation) und 5.3.1.6.4 (Token Exchange mit Refresh Token) teilen
dieselbe Ablaufstruktur:

- Basis-Validierung → Policy Engine Input → `POST /v1/data/authz` → Policy Decision
- alt-Block: allow → `200 OK` (neues Token-Paar) / deny → `403 Forbidden`
- Fall „Validation fehlerhaft" → `403 Forbidden`, inkl. Hinweis „Policy Engine wird nicht befragt"

- **Empfehlung**: Den Validierungs-/Policy-/Response-Block einmal beschreiben und in beiden
  Token-Exchange-Abschnitten referenzieren.

## 9. Doppelte/dreifache Lebenszyklus- und Phasenübersichten

Dieselbe Phasenaufzählung (Installation → Schlüsselgenerierung → Service Discovery → Key
Preparation/Attestation → DCR → Authentifizierung → Token Exchange → Session-Erneuerung) erscheint
mehrfach:

- 5.3.1 Einleitung + Abb. 3 `Abb-Attestierungsablauf-nach-Betriebssystem` (Bullet-Zusammenfassung)
- 5.3.2 Einleitung (nummerierte Phasenliste 1–8 für mobile Clients)
- 5.3.4 Überblick über den Attestierungslebenszyklus (Fließtext-Wiederholung)

- 5.3.4 ist bereits mit dem Hinweis „<< 5.3.4 bis 5.3.12 muss entfernt werden >>" markiert.
- **Empfehlung**: Eine einzige Lebenszyklus-Übersicht behalten (z. B. Abb. 3), die übrigen entfernen
  oder darauf verweisen.

## 10. Wiederholte „Hardware bevorzugt, Software als Fallback"-Aussage

Die Grundaussage „Hardware-Attestierung wird bevorzugt, Software-Attestierung dient als Fallback"
steht in:

- 5.3.1 (Einleitung)
- 5.3.2 (Einleitung: „Hardware-Attestation SOLL bevorzugt eingesetzt werden …")
- 5.3.4 (Lebenszyklus-Überblick)

## 11. Doppelung innerhalb der Einleitung von 5.3.2

Die Einleitung zu 5.3.2 enthält zwei aufeinanderfolgende Absätze, die nahezu denselben Inhalt
ausdrücken:

- Absatz 1: plattformspezifische Mechanismen (Android Key/ID Attestation, Apple Secure Enclave),
  Software-Fallback, interaktive Nutzerauthentisierung, OIDC + Authorization Code Flow.
- Absatz 2: „Im Unterschied zu stationären Clients …" – wiederholt plattformintegrierte
  Sicherheitsmechanismen, interaktive Nutzerauthentisierung, OIDC Authorization Code Flow + OAuth 2.0.

- **Empfehlung**: Die beiden Absätze zu einem zusammenführen.

## 12. Wiederholte Posture-Datenlisten

Die Aufzählung der erhobenen Posture-/Gerätedaten (OS-Version, Patch-Level, Modell/Hersteller,
Boot-Status/Verified Boot bzw. Secure Boot/SIP, App-Signatur) erscheint mehrfach:

- 5.3.2.3.1 (Android)
- 5.3.2.3.2 (Apple)
- konzeptionell ebenfalls in 5.3.1.6.1 / 5.3.1.6.2 (Client Statement)

## 13. Fast-Path / ZETA Guard Attestation Token doppelt beschrieben

Die beschleunigte Re-Registrierung mittels vorhandenem ZETA Guard Attestation Token ist zweimal
beschrieben:

- 5.3.1.5 (stationär: `attestation_type = "fast_path"`)
- 5.3.2.4 (mobil: „Pfad 2 [ZETA Attestation Token vorhanden (Fast-Path)]", Schritte 17–19)

- Inhaltlich identisches Prinzip (Token-Signatur prüfen, Besitznachweis über `PuK.AK.Sig`, kein
  erneuter vollständiger Attestierungs-/TOFU-Durchlauf).

## 14. DCR-Grundablauf doppelt (stationär vs. mobil)

5.3.1.5 (Abb. 10 `Abb-ZETA-DCR-für-stationäre-Clients`) und 5.3.2.4 (Abb. 19
`Abb-ZETA-DCR-für-mobile-Clients`) teilen denselben Grundaufbau:

- `POST /register`, innerer alt-Block nach `attestation_type` (Apple / Android bzw. TPM / Software)
- Fast-Path mit Attestation Token
- Abschluss `201 Created {client_id}`

- Unterschied: mobil ergänzt die TOFU-E-Mail-Verifikation. Der gemeinsame Rahmen ist redundant.

---

## Zusammenfassung der größten Konsolidierungs-Kandidaten

1. Apple-/macOS-Schlüsselgenerierung (Punkt 1) – identisch, gleiche Abbildung doppelt.
2. Apple-Attestierung (Punkt 2) – dreifach.
3. Generisches Attestierungsmuster (Punkt 4) – fünffach.
4. Software-Fallback (Punkt 5) – sechsfach.
5. DPoP-Erläuterung (Punkt 6) – vierfach.
6. Lebenszyklus-/Phasenübersicht (Punkt 9) – dreifach, 5.3.4 bereits zur Entfernung markiert.

**Generelle Empfehlung**: Das in 5.3.2.2 bereits verwendete Muster „Die Service Discovery ist
identisch für stationäre und mobile Clients. Siehe 5.3.1.3." konsequent auch auf die übrigen
identischen Abläufe (Apple-Schlüsselgenerierung, Apple-/SW-Attestierung, DCR-Rahmen, DPoP,
Policy-Response-Block) anwenden – also einmal kanonisch beschreiben und ansonsten referenzieren.
