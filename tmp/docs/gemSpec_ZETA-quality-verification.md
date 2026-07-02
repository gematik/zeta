# Qualitäts- und Konsistenzprüfung gemSpec_ZETA 1.4.0

**Prüfgegenstand:** `gemSpec_ZETA_1.4.0.pdf` (Version 1.4.0, Stand 28.04.2026, 149 Seiten)
**Abgeglichen mit:** `src/plantuml/zeta-flows/*.puml` (39 Diagramme) und `src/schemas/*.yaml` (30 Schemata)
**Erstellt:** 02.07.2026
**Prüfumfang:** Interne Konsistenz & fachliche Korrektheit · Abgleich Diagramme · Abgleich Schemata · Sicherheitsanalyse der Flows · Anforderungsqualität (Hersteller/Anbieter) · User Experience

---

## 1. Management Summary

Die Spezifikation ist inhaltlich weit entwickelt und in den OAuth2/OIDC-Kernkonzepten
(Token Exchange, PAR/PKCE, DPoP, Discovery, Attestierung) überwiegend fachlich korrekt.
Grobe RFC-Fehler (falsche Grant-Type-URIs, falsche Claim-Namen) wurden **nicht** gefunden.
Das Zero-Trust-Sicherheitsdesign ist im Kern solide und gegen die klassischen
OAuth-Angriffe (Code-Injection, CSRF, Mix-Up) wirksam gehärtet; das TOFU-Faktormodell
(F1/F2/F3) gegen einen kompromittierten IDP ist ein besonderer Stärkepunkt.

Der mit Version 1.4.0 neu eingearbeitete Stufe-2-Stoff (v. a. Kap. 5.5 Client Management,
Kap. 5.12 Notification Service) ist jedoch **redaktionell und fachlich noch nicht
release-reif**. Die gravierendsten Punkte:

| # | Kernproblem | Schwere | Wirkung |
|---|-------------|---------|---------|
| K1 | **Widerspruch aud-Claim**: URL (A_26681-02, Tab. 19) vs. logischer Bezeichner (5.4.2.2) | Kritisch | Interop ZETA Client ↔ Guard nicht implementierbar |
| K2 | **Widerspruch PEP-Statuscode** 401 (A_28525-02) vs. 403 (A_29676) vs. „401 alternativ" (A_29860) | Kritisch | Interop, nicht testbar |
| K3 | **Account-Recovery-Diagramm** widerspricht A_29928/A_29931 (kein IDP-Step-up, ändert E-Mail F1) | Kritisch (Security: hoch) | Account-Takeover per geleaktem Recovery-Code |
| K4 | **Token Revocation** in Diagramm + Schema, aber nicht in Spec (kein Kapitel, kein `/revoke`) | Kritisch | Normlücke für neue Kernfunktion |
| K5 | **Verweise auf nicht existierende IDs** (A_ZGTOFU_*) und Abbildungen in normativem Text | Kritisch | Anforderungen formal leer/nicht prüfbar |
| K6 | **A_27802 doppelt** (-02 und -03, identischer Text, S. 107) | Kritisch | Versionsführung defekt |
| K7 | **Token-Laufzeiten nirgends beziffert** (A_28527/A_25662) | Kritisch | Nicht testbar; Betrieb & UX nicht planbar |
| K8 | **Leere Normkapitel** 5.12.1–5.12.4 (Notification Service) | Kritisch | Push-Pfad nicht implementier-/betreibbar |
| K9 | **Schema-Bug**: `required: [platform]` in `attestation_result` (policy-engine-client-data) | Kritisch | Jedes konforme Dokument schlägt Validierung fehl |
| K10 | **Redaktions-Platzhalter** „ML-189815 – Missing cross-reference" (S. 18) | Kritisch | QS-Lücke |

**Empfehlung:** Ein konsolidierender Redaktions- und Klärungsdurchgang mit Fokus auf
(a) Token-/Audience-Modell (Kap. 5.4.2 / 5.7), (b) ID- und Statusmodell-Bereinigung
(Kap. 5.5), (c) Fehler-/Statuscode-Modell, (d) Fertigstellung Kap. 5.12 und
(e) Synchronisierung von Spec, Diagrammen und Schemata, bevor 1.4.0 als verbindlich
gilt. Viele Findings sind reine Redaktions-/Synchronisierungsarbeit; die eigentliche
Architektur muss nicht neu entworfen werden.

> **Hinweis zur Methodik:** Jedes Finding ist mit Fundstelle (Seite bzw. Datei:Zeile)
> und – wo möglich – wörtlichem Kurzzitat belegt. Findings, die von mehreren
> unabhängigen Prüfläufen bestätigt wurden, sind mit **[mehrfach bestätigt]** markiert.
> Nicht abschließend verifizierbare Punkte sind als **[unsicher]** gekennzeichnet.

---

## 2. Interne Konsistenz & fachliche Korrektheit

### 2.1 Kritisch

- **K1 – Widerspruch zum Inhalt des `aud`-Claims (URL vs. logischer Bezeichner)** **[mehrfach bestätigt]**
  Kap. 5.4.2.2 (S. 83): „Die Ressourcen-URL wird **NICHT** in den aud-Claim übernommen"
  (logischer Bezeichner aus der Policy Engine). A_26681-02 (S. 86): „Das Access Token
  aud claim und das DPoP Token htu claim MÜSSEN die **URI des Resource Server
  Endpunktes** enthalten." Zusätzlich Tab. 19 (S. 128): „Access Token aud:
  `https://<FQDN>/ASL`" (URL). *Empfehlung:* A_26681-02 und Tab. 19 auf das
  Contract-v2-Modell (logischer Bezeichner) harmonisieren bzw. v1/v2 explizit
  kennzeichnen (`ver`-Claim, 5.4.2.5).

- **K2 – Widerspruch HTTP-Statuscode für Audience-/Scope-Mismatch am PEP** **[mehrfach bestätigt]**
  A_28525-02 (S. 118): „Step-up-Authentifizierung mit HTTP Statuscode **401**"; A_29676
  (S. 120) für denselben Strict-Audience-Fall: „mit dem HTTP-Fehlercode **403** Forbidden
  abweisen"; A_29860 (S. 122): „**403** (alternativ **401** … gemäß API-Design)". Drei
  Aussagen für denselben Fall. *Empfehlung:* Einheitlich festlegen – z. B. 401 +
  `WWW-Authenticate` bei Step-up (RFC 9470), 403 bei endgültiger Ablehnung. RFC 9470
  ins Referenzverzeichnis aufnehmen.

- **K5 – Verweise auf nicht existierende Anforderungen `A_ZGTOFU_*`** **[mehrfach bestätigt]**
  In normativem Text: A_29914 (S. 101, „analog A_ZGTOFU_072"), A_29946 (S. 104,
  „A_ZGTOFU_116 sichert…"); ferner A_ZGTOFU_042/044/050/051/070–075 (S. 99–102). Diese
  internen Arbeits-IDs sind im Dokument nicht definiert → nicht prüfbar. *Empfehlung:*
  auf publizierte A_299xx-IDs mappen.

- **K5b – Normative MUSS-Anforderungen referenzieren nicht existierende/falsche Abbildungen** **[mehrfach bestätigt]**
  A_29809 (S. 66): „gemäß Abbildung Abb-ZETA-DCR-für-mobile-Android-HW-Att-Clients"
  (Kapitel zeigt aber Abb. 19 „…Client-Statement-mit-Android-Attestation"; die
  referenzierte Abbildung existiert in der Spec gar nicht). A_28431 (S. 77):
  „Abb_ZETA-Guard-Dienst-zu-Dienst-Kommunikation" (tatsächlich Abb. 26). A_29878 (S. 81):
  „Abb-ZG-Client-Dienst-zu-Dienst-Kommunikation" (tatsächlich Abb. 27). Da die Abbildung
  jeweils der normative Prüfgegenstand ist, ist der Anforderungsinhalt formal leer.
  *Empfehlung:* Abbildungsnamen korrigieren.

- **K6 – Anforderung A_27802 doppelt in zwei Versionsständen** **[mehrfach bestätigt, verifiziert S. 107]**
  A_27802-**03** (Z. 4271) und A_27802-**02** (Z. 4284) mit identischem Titel
  („ZETA Guard, JWT Prüfung") und identischem Text, in falscher Reihenfolge.
  *Empfehlung:* nur -03 behalten, -02 streichen.

- **K10 – Redaktions-Platzhalter statt Kapitelverweis** **[verifiziert S. 18]**
  Kap. 4.6: „Siehe Kapitel **ML-189815 - Missing cross-reference**." *Empfehlung:*
  auf gemeintes Kapitel setzen (vermutlich 5.5.4 Posture bzw. 5.3.2.3).

### 2.2 Mittel

- **Terminologisch falsch: „Token Exchange" für den Refresh-Token-Grant.** A_29843/
  A_29844/A_29856 (S. 74 f., 124) und die Überschrift 5.3.1.6.4 nennen den Refresh-Grant
  (RFC 6749 §6) „Token Exchange". Token Exchange ist per RFC 8693 der Grant
  `urn:ietf:params:oauth:grant-type:token-exchange`. *Empfehlung:* „Token Request mit
  grant_type=refresh_token" formulieren.

- **Fehlerantworten am Token-Endpunkt weichen von RFC 6749/9470 ab.** Durchgängig „403
  Forbidden" bei Policy-Deny/Validierungsfehler (S. 52; A_25661-01, S. 124), obwohl
  RFC 6749 §5.2 400 (bzw. 401 bei `invalid_client`) vorsieht;
  `insufficient_user_authentication` ist per RFC 9470 eine **401**-Challenge im
  `WWW-Authenticate`-Header, wird aber als 403 mit JSON-Body genutzt (A_29860). Zudem
  differenziert Tab. 7 (S. 91) korrekt 400/401/403, die Ablauftexte pauschalisieren auf
  403. *Empfehlung:* bewusste Abweichung begründen oder RFC-konform gestalten.

- **Inkonsistentes Client-Statusmodell.** Verwendet werden `pending_attestation` (S. 47),
  `pending_verification` (S. 64), `pending_policy_decision` (S. 64), `pending_user_binding`
  (S. 99, „gemäß A_29658" – dort nicht definiert). *Empfehlung:* Statusmodell an einer
  Stelle vollständig definieren; Schema-Enum `dcr-response-202.yaml` angleichen (siehe C).

- **Pauschale PKCE-Pflicht kollidiert mit Token-Exchange-Flow.** A_25781 (S. 89): „Dabei
  MUSS PKCE Flow [RFC7636] verwendet werden." PKCE existiert nur im
  Authorization-Code-Flow; stationäre Clients nutzen Token Exchange mit SM(C)-B (5.3.1.6).
  *Empfehlung:* PKCE-Pflicht auf den Authorization-Code-Flow einschränken.

- **Geltungsbereich ZETA/ASL widersprüchlich.** Glossar (S. 144): „zwischen ZETA Client
  und ZETA Guard **PEP**"; A_28852 (S. 106): „für **PEP und PDP** Endpunkte". Ein
  ASL-Kanal zum Authorization Server ist nirgends mit Schlüsseln (Kap. 5.2) spezifiziert.
  *Empfehlung:* ASL-Terminierungspunkte abschließend definieren.

- **Schlüssel-Nomenklatur (Kap. 5.2) lückenhaft.** Komponenten „ZG", „Ingress" und Zweck
  „IDP" fehlen in den Definitionslisten (S. 33 f.); inkonsistente Paarungen
  „PrK.ZETA-IK.Sig / C.TI-ZETA-IK.Sig" (S. 38); „Sys/Zentrales System" definiert, aber
  ungenutzt. *Empfehlung:* Nomenklatur und Tabellen synchronisieren.

- **Zentrale RFCs/Annexe fehlen im Referenzverzeichnis (7.5).** U. a. RFC 8693 (der
  zentrale Grant!), 8414, 9126, 7591/7592, 7638, 7239, 7519/7515, 9110, 9470 sowie die
  Annexe `zeta-guard-client-management.yaml` / `zeta-guard-admin-oob.yaml`.

- **Weitere:** A_25840 referenziert (A_28960, S. 30), aber nicht definiert; doppelt
  vergebener Abbildungsname „…Apple-AppAttest" (Abb. 11 = Abb. 20, S. 50/67) macht
  A_29810 ambig; inkonsistente Schrittnummerierung 5.3.1.6.4 (S. 54) und 5.3.2.1.2 (S. 62);
  Endpunkt `/refresh` nur in Tab. 22 (S. 138), sonst `POST /token`; redundante
  Doppelregelung A_29848 ≡ A_29856; Titel A_29740 abgeschnitten (S. 113); Selbstreferenz
  A_29900 „(vgl. A_29900)" (S. 98, gemeint A_29901); TOFU-Geltungsbereich mobil vs.
  stationär uneinheitlich (A_25651-Hinweis vs. A_25432-01). **[unsicher]** acr-Wert für
  SMC-B: A_29820 (S. 128) nennt `gematik-ehealth-loa-substantial`; SMC-B als
  Hardware-Smartcard entspricht üblicherweise „hoch" – gegen gemSpec_IDP_Sek prüfen.

### 2.3 Gering (Redaktion)

Ungerenderte Markdown-Artefakte in Kap. 5.5 (Backticks/Sternchen, S. 97–105);
uneinheitliche Schreibweisen „ZETA Guard"/„ZETA-Guard"/„ZETAGuard", „Resource"/
„Ressource Server"; ASL-Langform widersprüchlich (S. 34 „Application Security Layer" vs.
S. 144 „Additional Security Layer"); Abkürzungsverzeichnis unvollständig (ZAS, ASL, DCR,
DPoP, TOFU, OTP, PKCE, KVNR fehlen) und mit Karteileichen (CTS, FBE, SPIFFE …);
Copy-Paste in A_28963 („JWT" statt „DPoP-Proofs", S. 107) und „PPoP" in A_29676 (S. 120);
API-Namen ungenau (`KeyStore.generateKey` statt `KeyPairGenerator` S. 59;
`DCAppAttest.generateAssertion` statt `DCAppAttestService`; `TPM2_GetEventLog()` existiert
nicht); EK nur TPM-Konzept, nicht Secure Enclave (S. 37); diverse Tippfehler („trafen"
statt „tragen" S. 84; „NOR-Netzwerk" statt „TOR" S. 24; „weiterleileiten" S. 106).

---

## 3. Abgleich Spezifikation ↔ PlantUML-Diagramme (zeta-flows)

### 3.1 Kritisch

- **K4 – Token Revocation ohne Spec-Verankerung.** **[mehrfach bestätigt, verifiziert]**
  `Abb-ZETA-Token-Revocation.puml` und `revocation_endpoint*` in
  [as-well-known.yaml:94-120](../../src/schemas/as-well-known.yaml#L94) sind neuer
  Arbeitsstand (Commit 27fab41/367d6a8). Die Spec 1.4.0 kennt weder ein
  Revocation-Kapitel noch `POST /revoke`; Tab. 23 (S. 139) listet nur
  `/nonce`, `/register`, `/authorize`, `/token`. Die einzigen „Revocation"-Treffer im Text
  betreffen TLS-/OCSP-Zertifikatsprüfung (S. 86 f.). Der Fehlercode `refresh_token_revoked`
  (Tab. 7, S. 91) existiert, aber ohne Ablauf. *Empfehlung:* Spec ergänzen (Kapitel +
  Anforderung + Aufnahme in Tab. 22/23), RFC 7009 referenzieren.

- **K3 – DCR-Account-Recovery-Diagramm widerspricht Recovery-Anforderungen.**
  **[mehrfach bestätigt, verifiziert – auch Security-Finding H1]**
  [Abb-ZETA-DCR-Account-Recovery.puml:29-34](../../src/plantuml/zeta-flows/Abb-ZETA-DCR-Account-Recovery.puml#L29):
  Recovery per `POST /register {…, user_email=<neue E-Mail>, recovery_code}` mit „Binde
  neuen Client & **neue E-Mail** an bestehenden Account". Spec verlangt: A_29928 (S. 102)
  „IDP-(Step-up-)Authentisierung **UND** mindestens ein überlebender Faktor" (im Diagramm
  fehlt der IDP-Step-up), A_29931 (S. 102) „DARF NICHT dabei eine identitätsgebundene
  E-Mail (F1) verändern", Schnittstelle `POST /zeta/recover` (nicht `POST /register`).
  *Empfehlung:* **Diagramm ändern** (IDP-Step-up ergänzen, E-Mail-Neubindung entfernen,
  korrekten Endpunkt verwenden).

- **Android Client Statement: anderer Mechanismus als Spec-Text (Abb. 19).**
  [Abb-ZETA-Client-Statement-mit-Android-Attestation.puml:30-41](../../src/plantuml/zeta-flows/Abb-ZETA-Client-Statement-mit-Android-Attestation.puml#L30):
  `clientDataHash = SHA-256(Nonce || Posture || PuK.Client.Sig)`, Signatur mit
  **bestehendem** AK, „kein erneutes Erzeugen eines Schlüsselpaars". Spec 5.3.2.3.1
  (S. 65 f.): `Hash(Nonce + Posture)` **ohne** PuK.Client.Sig und **Erzeugung eines neuen
  Schlüsselpaars** via `KeyPairGenerator` + `setAttestationChallenge`. Zwei verschiedene
  Verfahren. *Empfehlung:* Entscheidung erforderlich, dann Spec oder Diagramm angleichen.

### 3.2 Mittel (Auswahl)

- **Apple-clientDataHash: Spec 5.3.1.6.2 (S. 50) veraltet** – beschreibt dieselbe
  Abbildung 11 anders als 5.3.2.3.2 (S. 66 f.) und das Diagramm (`… || PuK.Client.Sig`).
- **Veraltetes PAR-Diagramm** `Abb-ZETA-OIDC-Authorization-Request-mit-PAR.puml` (einfacher
  `GET`), widerspricht 5.3.2.5.3 (S. 70, `POST /par` + `request_uri`); das
  Übersichtsdiagramm referenziert fälschlich diese veraltete Datei.
- **Token-Exchange-Diagramme unvollständig**: `grant_type`, `resource`/`audience`, `scope`
  fehlen im Request (`Abb-ZETA-Token-Exchange-mit-Attestation.puml:34`,
  `…mit-Refresh-Token.puml:26`); Spec S. 52/74/84 fordert sie.
- **DCR-Varianten weichen ab**: `PuK.AK.Sig`/`signed_Hash` fehlen im stationären
  Apple-Diagramm; `signed_hash_puk_client_sig`/`user_email` fehlen im mobilen
  Apple-HW-Diagramm; Varianten liefern zusätzlich `zeta_attestation_token` (durch A_29842
  gestützt, im Hauptdiagramm nicht gezeigt).
- **Recovery-Code-Vergabe** im mobilen DCR-Flow (`…für-mobile-Clients.puml:74-82`)
  widerspricht Spec-Schnittstelle `POST /zeta/recovery-codes` (S. 99).
- **Duplizierte `@startuml`-IDs** in mehreren Dateien (Kollisionsgefahr bei
  Diagrammgenerierung), z. B. „…Client-Statement-mit-TPM-Attestation" in 3 Dateien.
- **Abb. 8 „Abb-ZETA-SE-Attestation-Key"** (S. 46 referenziert) hat **keine `.puml`-Quelle**
  im Repo (nur PNG/SVG). **Statuscode-Semantik** in Diagrammen pauschal 403 vs. Tab. 7
  (400/401/403). **Endpunkt-Tabellen** (Tab. 22/23) unvollständig: `/par`,
  `/register/verify`, `redirection_endpoint`, künftig `/revoke` fehlen.
- **Notification-Service-Diagramm** ohne Spec-Inhalt (Kap. 5.12 leer; `A_NS_*`-IDs
  existieren nicht).

### 3.3 Gering

Token-Revocation-Diagramm ohne RFC-7009-Fehlerfälle (`invalid_client`-Body,
`unsupported_token_type`); Deny-Response in Diagrammen ohne Pflichtfeld `error`
(Schema-Neuerung); Header-Benennung „PEP header" vs. „ZETA headers" (S. 57);
Spec-„/as"-Suffix statt „/oidc" (S. 73); vier Orphan-Bilder ohne Quelle; redundante
„Vorbereitung-Token-Exchange"-Diagramme (veraltet, Duplikat-IDs).

> **Gesamtergebnis Diagramm-Abgleich:** von 39 Diagrammen sind ~20 konsistent, 3 kritisch
> abweichend (Recovery, Android-Statement, Revocation), ~12 mittel abweichend/unvollständig,
> mehrere ohne Spec-Referenz (veraltete Varianten). Vollständige Zuordnungstabelle siehe
> Anhang A.

---

## 4. Abgleich Spezifikation ↔ Schemata (src/schemas)

### 4.1 Kritisch

- **K9 – Unerfüllbares `required` in `policy-engine-client-data.yaml`.** **[verifiziert]**
  [policy-engine-client-data.yaml:249-250](../../src/schemas/policy-engine-client-data.yaml#L249):
  `attestation_result` hat `required: [platform]`, definiert dort aber nur die Properties
  `tpm`/`android`/`apple`/`software`; `platform` ist ein **Top-Level**-Feld (Z. 256). Da
  `attestation_result` selbst Pflicht ist (Z. 260), schlägt die Validierung für jedes
  konforme Dokument fehl. Schema wird über A_26585-02 (S. 127) normativ. *Empfehlung:*
  Schema korrigieren – `required: [platform]` innerhalb `attestation_result` entfernen.

### 4.2 Mittel (Auswahl)

- **`refresh_token` als Pflichtfeld vs. identitätslose Clients.** **[mehrfach bestätigt]**
  `token-response.yaml#/definitions/successResponse` hat `refresh_token` in `required`;
  A_29894 (S. 98): „es wird **kein** Refresh Token ausgestellt". (Spec-intern zusätzlich
  widersprüchlich: S. 77 Schritt 12 stellt „ein Refresh Token" aus.) *Empfehlung:* Schema
  optional machen; Spec-Widerspruch S. 77 ↔ A_29894 auflösen.
- **Deny-Response `error` ohne Spec-Vorgabe.** `token-response.yaml#/denyResponse` verlangt
  `error` (aus `zeta-error.yaml`); der Spec-Text (A_29953 S. 128, A_25661-01 S. 124)
  definiert für den Policy-Deny keinen error-Code. Die RFC-Codes
  `invalid_client`/`invalid_grant`/`access_denied` aus dem Enum kommen im Text nicht vor.
  *Empfehlung:* Spec – error-Code für Deny normieren (z. B. `access_denied`).
- **`revocation_endpoint*` in `as-well-known.yaml`, aber nicht in Spec** (→ K4).
- **`attestation_type: zeta_cross_guard` fehlt in `dcr-request.yaml`** (Spec S. 100,
  A_29913–A_29915, Bootstrap-Assertion/Fast-Path).
- **`dcr-request.yaml` Apple-Zweig: `user_email` Pflicht auch für stationäre macOS-Clients**
  (TOFU nur mobil, A_29893 S. 98). **Fast-Path**: `signed_hash_puk_client_sig` nicht in
  `required`, obwohl Besitznachweis gefordert (S. 64).
- **`dcr-response-202.yaml`: Status `pending_user_binding` fehlt im Enum** (Spec S. 99).
- **`zeta-attestation-token.yaml`:** `exp` Pflicht vs. „unbegrenzt gültig" (S. 100);
  ungültiges Teilschema in `cnf.jwk` (`description` als Property-Schlüssel, Einrückungsfehler).
- **`client-assertion-jwt.yaml`: Claims `iat`/`nonce` fehlen** (Spec S. 76 f.: „inklusive
  der Nonce", „prüft iat, exp"; auch Tab. 8 S. 94 unvollständig).
- **`zeta-user-info.yaml`:** Tab. 17/18 (S. 125 f.) nennen `profession_oid`/`common_name`/
  `organization_name` (snake_case), Schema definiert `professionOID`/`commonName`/
  `organizationName` (camelCase, wie Tab. 15 S. 121). *Empfehlung:* Spec Tab. 17/18
  angleichen. **Tab. 15 referenziert Access-Token-Claim `identifier`**, den `access-token.yaml`
  nicht kennt (nur `sub`; A_26477-01 spricht von `sub`).

### 4.3 Gering

`posture-software.yaml` Feld `nonce`/Deprecation nicht in Spec (Tab. 11 S. 96);
`client-data.yaml` Zusatzfeld `platform` (A_26590-02 S. 121); `authorization-details.yaml`
(RAR/RFC 9396) komplett ohne Spec-Bezug (IDP-Auswahl läuft über `idp_iss`);
`policy-engine-input.yaml` Felder `version`/`country_code`/`previous_ip_address`/
`delegation_context`/`grant_type=client_credentials` ohne Spec-Grundlage, `amr`/
`previous_ip_address` required kollidiert mit Ablauf ohne Nutzer-Identität;
`subject-token-smb.yaml` `alg: ES256` mit Brainpool-Hinweis (für Brainpool wäre `BP256R1`);
falsche Seitenangaben in `zeta-error.yaml`-Kommentaren; fehlende `pattern`/`maxLength` für
`product_id`/`product_version` (A_25338-01 S. 85); gemischte Namenskonventionen (camelCase
in posture-android/apple, sonst snake_case – in Spec so gespiegelt, aber stilistisch
uneinheitlich); `src/schemas/tmp/` enthält unreferenzierte Entwürfe (`api-catalog.yaml`,
`session.yaml`) – aus `src/schemas` heraushalten oder kennzeichnen.

**Interne Schema-Qualität (positiv):** alle 30 Schemata `$schema: draft-07`; alle
`$ref`-Verweise (auch dateiübergreifend) zeigen auf existierende Ziele; `discriminator`
sauber als Nicht-draft-07 kommentiert. `user-info.yaml` ↔ `zeta-user-info.yaml` bewusst
getrennt (RS-Kompatibilität), kein inhaltlicher Widerspruch – **kein Finding**.

Vollständige Schema-Zuordnungstabelle siehe Anhang B.

---

## 5. Sicherheitsanalyse der Flows

Bewertung gegen bekannte OAuth2/OIDC-, Attestierungs- und Zero-Trust-Angriffsklassen.
Die Kernanforderungen sind überwiegend korrekt und sicher formuliert; die Schwächen liegen
in (a) Inkonsistenzen Text ↔ Diagramm und (b) Kontrollen, die nur als KANN/„konfigurierbar"
statt aktiv erzwungenes MUSS ausgeprägt sind.

### 5.1 Hoch

- **H1 – Account-Takeover per Recovery-Code** (= K3). Wird der Recovery-Flow wie im
  Diagramm implementiert (nur `recovery_code`, kein IDP-Step-up, E-Mail-Neubindung),
  genügt ein einzelner geleakter Recovery-Code + HW-Attestierung auf einem Angreifergerät
  für die vollständige Kontoübernahme inkl. Umbiegen der E-Mail-Bindung. Der Normtext
  (A_29928/A_29931/A_29930) ist korrekt und sicher – das Diagramm ist das Problem.
  *Gegenmaßnahme:* Diagramm an Anforderungen angleichen.

- **H2 – Keine verpflichtende Refresh-Token-Reuse-Detection.** A_25662 (S. 124) fordert
  Rotation/Einmalnutzung; A_29855 entzieht rotierte Token nur bei **aktiver**
  Session-Termination. Es fehlt eine MUSS-Regel, dass die Vorlage eines bereits
  konsumierten/rotierten Refresh Token als Diebstahlindikator die gesamte Token-Familie/
  Session terminiert (OAuth 2.0 Security BCP). Folge: gestohlenes Refresh Token kann
  parallel weiterrotiert werden. *Gegenmaßnahme:* neue MUSS-Anforderung (Reuse → sofortige
  Invalidierung der Session, analog A_29855).

- **H3 – Vertrauen in client-lieferbare `Forwarded`/`X-Forwarded-For`-Header.** Der PDP
  ermittelt die Client-IP aus `Forwarded` (A_28440, S. 126); IP-Binding/Impossible-Travel
  (A_28803) bauen darauf auf. Es fehlt – anders als beim analogen Fall `zeta-user-info`
  (A_25669-01, S. 119: gleichnamige Header MÜSSEN überschrieben werden) – eine MUSS-Regel,
  dass der äußerste PEP untrusted `Forwarded`/`X-Forwarded-For`/`X-Real-IP` verwirft/
  normalisiert. Ein Client kann sonst die IP-Bindung fälschen. *Gegenmaßnahme:* MUSS-Regel
  + definierte Trusted-Hop-Kette.

### 5.2 Mittel

- **DPoP-Proof-Replay am PEP/RS.** A_25667/A_25668-01/A_29676 prüfen Signatur, `iat/exp`
  des Access Tokens, `jkt`, Strict-Audience, `htu` – aber **keine** `jti`-Replay-Prüfung
  des DPoP-Proofs, kein enges `iat`-Fenster, keine serverseitige DPoP-Nonce für den
  Ressourcenzugriff (anders als am Token-Endpunkt via `GET /nonce`). *Gegenmaßnahme:*
  PEP-AFO um jti-Replay-Cache + iat-Fenster bzw. optionale DPoP-Nonce (RFC 9449 §8).
- **Play/Device-Integrity bei Android nur `opt`.** In beiden Android-Diagrammen steht die
  Play-Integrity-Prüfung im `opt`-Block; Key Attestation belegt nur die TEE-Bindung des
  Schlüssels, nicht Boot-/App-Integrität. *Gegenmaßnahme:* für Versicherten-Clients
  verpflichtend (MUSS) bzw. Fehlen als Posture-Faktor durchreichen.
- **Software-Attestierung als client-wählbarer Downgrade-Vektor.** Client wählt
  `attestation_type` selbst; keine normative Regel, dass HW-fähige Geräte kein SW-Fallback
  nutzen dürfen (in nicht spezifizierte Policy verlagert). Zusätzlich schwache DCR-Freshness
  (`attestationChallenge = SHA-256(PuK.Client.Sig)` statt serverseitiger `GET /nonce`).
- **Registrierungs-OTP ohne verpflichtenden Brute-Force-Schutz.** Für Recovery-Codes
  existiert A_29930 (Ratenbegrenzung/Lockout); für das E-Mail-OTP (`POST /register/verify`)
  fehlt ein Pendant; A_26668-02 ist nur „konfigurierbar". *Gegenmaßnahme:* analogen
  Brute-Force-Schutz + OTP-Mindestentropie normieren.
- **Rate Limiting nur „konfigurierbar" statt aktiv** (A_26668-02, S. 107) – `/par`,
  `/token`, `/nonce`, `/register` sonst DoS-/Brute-Force-exponiert. *Gegenmaßnahme:*
  verpflichtende Default-Limits mit Mindestwerten je Endpunkt.
- **Normative Lücke Notification Service (Kap. 5.12).** Sicherheits-/Krypto-Kontrollen
  (mTLS RS↔NS, Envelope-DEK, HSM-KEK-Sealing, HMAC-Pseudonymisierung) existieren nur als
  Diagramm-Notizen (`A_NS_*`), nicht als AFOs. *Gegenmaßnahme:* in nummerierte AFOs überführen.

### 5.3 Gering

TLS 1.2 als Minimum zugelassen (A_27378-01, S. 85; für Gesundheitsdaten TLS 1.3 als
mind. SOLL); SMC-B-Subject-Token nicht an `PuK.Client.Sig`/DPoP-`jkt` gebunden (nur Nonce +
`aud`); D2D-Access-Token als Bearer-Secret in etcd ohne DPoP; ZAS↔Client-Kanal (stationär)
nur prosaisch abgesichert (Kap. 5.4.7, S. 93 – ohne AFO/Mechanismus).

### 5.4 Gesamtbewertung Sicherheit

Solides, verteidigungsfähiges Zero-Trust-Design: PKCE durchgängig (äußerer + innerer Flow),
PAR mit sehr kurzen `request_uri`-Laufzeiten, `state`/`nonce`, gegen Entity-Statements
geprüfte `redirect_uri`-Validierung (Code-Injection/CSRF/Mix-Up adressiert, A_25449);
starkes TOFU-Faktormodell F1/F2/F3 gegen kompromittierten IDP (A_29896/A_29897),
Per-Guard-Isolation, BOLA-Schutz (A_29939), Vier-Augen-OOB-Löschpfad; DPoP-Bindung,
Strict-Audience am PEP (A_29675/A_29676), Contract-Versionierung, Refresh-Token-Rotation.
Die wesentlichen Schwächen sind **nicht konzeptioneller Natur**, sondern (a) Text-↔-
Diagramm-Inkonsistenzen (kritisch beim Recovery-Flow) und (b) zu weiche Verbindlichkeit
(KANN/„konfigurierbar" statt MUSS bei Rate-Limiting, OTP-Brute-Force,
Refresh-Reuse-Detection, DPoP-Replay am PEP) sowie optionale Integritätsprüfungen und
client-wählbare Downgrades, deren Restrisiko in die nicht spezifizierte Policy-Ebene
verlagert wird. Nach Nachschärfung der Verbindlichkeit und Beseitigung der
Diagramm-Widersprüche trägt das „never trust, always verify"-Versprechen lückenlos.

---

## 6. Anforderungsqualität – Eignung für Hersteller & Anbieter

### 6.1 Statistik

| Kennzahl | Wert |
|---|---|
| Eindeutige Anforderungs-IDs (A_xxxxx) | **~358** (359 nominell, A_27802 doppelt) |
| MUSS/DARF-NICHT-dominiert | ~341 (≈95 %) |
| nur SOLL | 7 · nur KANN | 1 |
| Methodikverstoß (kleingeschriebenes „muss") | 2 (A_28756, A_28405, S. 32) |
| Adressaten-Attribut je Anforderung | **existiert nicht** – nur aus Fließtext erschließbar |

Heuristische Adressaten-Verteilung: ZETA Guard/Guard-Komponenten ≈66 %, ZETA Client/
Clientsystem ≈14 %, Anbieter ≈8 %, „Hersteller" (drei nicht abgegrenzte Rollen!) ~20,
gematik/CI-CD ~8, ohne Adressat ~15.

### 6.2 Kritische Anforderungs-Findings

- **K7 – Token-Laufzeiten nirgends beziffert.** A_28527/A_25662 (S. 124): Gültigkeit „aus
  der Policy Decision", Hinweis widerspricht dem Normtext („Refresh Token wird aktuell fest
  konfiguriert … da der Authorization Server dies noch nicht unterstützt"). Kein einziger
  Zahlenwert. Folge: nicht testbar, Betrieb/UX nicht planbar. *Empfehlung:* normative
  Default-Werte/Bereiche je Nutzergruppe; Hinweis und Normtext harmonisieren.
- **Widerspruch Refresh Token bei identitätslosen Clients** (S. 77 „und ein Refresh Token"
  vs. A_29894 „kein Refresh Token"). *Empfehlung:* eine Variante streichen.
- **Widerspruch aud-Claim** (= K1) betrifft direkt die ASL-Prüfung der Hersteller.
- **A_27802 doppelt** (= K6).
- **Verweise auf `A_ZGTOFU_*`** (= K5) – für Hersteller nicht nachvollziehbar.
- **Leere Normkapitel 5.12.1–5.12.4** (= K8) – Push-Pfad (Kernkomponente per A_28789)
  nicht implementier-/betreibbar.
- **Adressaten-/Nachweismodell unklar für ~2/3 aller Anforderungen** – der ZETA Guard
  „wird im Auftrag der gematik entwickelt" (S. 105), dennoch adressieren ~236 AFOs die
  Komponente selbst. Wer erbringt den Konformitätsnachweis? Rollenvermischung: A_28406-01
  (S. 22) adressiert den „Hersteller des TI-2.0-Dienstes" für eine klassische
  **Anbieter**-Aufgabe (Verifikation im Betrieb). *Empfehlung:* Adressaten-Attribut je AFO
  bereits in der Spezifikation ausweisen (wie in den Steckbriefen).
- **Zentrales Kapitel als „Offener Punkt"** – 5.4.3 (S. 87, dienstübergreifende
  Registrierung/„Big Apps") wird „in einer Folgeversion veröffentlicht". Hersteller können
  nicht abschließend implementieren.

### 6.3 Mittlere Anforderungs-Findings (Auswahl)

Normative MUSS-Sätze außerhalb der AFO-Struktur (5.4.2.1–5.4.2.5, S. 83–85 – formal keine
Anforderungen); widersprüchliches Sperrmodell (A_28803 „sperren" vs. A_29847 „KÖNNEN bis
Ablauf weiterverwendet werden") + fehlender Mechanismus, wie der zustandslose PEP ein
einzelnes Access Token sperrt; Step-up 401 vs. 403 (= K2); Abbildungen als alleiniger
normativer Gehalt bei teils fehlenden Fehlerpfaden; unbestimmte extern delegierte Werte in
MUSS-AFOs (Rollover-Intervall „durch gematik", Veto-Fenster ohne Mindestzeit,
Backoff-Parameter „vom Hersteller", Update-Frequenz „z. B. quartalsweise"); A_25769
(export-sicher speichern) vs. Software-Fallback (rein in Software); A_25484-03 Security-KPIs
unterbestimmt („MUSSeinmal täglich", KPI-Definitionen/Datenquellen fehlen);
Konzept-/Begründungstext mit normativem Anstrich (A_29927, A_29946); redundante
TLS-Anforderungen; weiche, nicht testbare Formulierungen („Angriffe erkennen",
„geeignete Maßnahmen", „zeitnah", „relevante Logs").

### 6.4 Was Herstellern (Entwicklern) fehlt

- **Konformitäts-Testsuite / Referenz-Testinstanz** – keine AFO sichert eine erreichbare
  Test-Guard-Instanz zu (nur Test-Registry-Pfad S. 111, PoC-Verweise Kap. 6).
- **Testvektoren** – Beispiel-JWTs, Beispiel-Attestation-Objekte fehlen.
- **Vollständiger Fehlercode-Katalog** – nur fragmentarisch (Tab. 7, `zeta-error.yaml`,
  Einzelcodes); kein durchgängiges Mapping error-Code → Client-Reaktion → Endnutzertext.
- **End-to-End-Beispiele** – kein vollständiges Token-Exchange-Beispiel mit allen vier
  Komponenten (5.4.2.3).
- **ZAS-API** – Vertrauensbeziehung ZAS↔Primärsystem nur beschreibend (S. 42), keine
  prüfbare Anforderung; API nur als Link (S. 93).

### 6.5 Was Anbietern (Betreibern) fehlt

- **Verfügbarkeit/SLA** – Latenz/Durchsatz vorhanden (A_26486 ff.: 75 ms, 300 req/s pro
  Pod), aber **keine** Verfügbarkeitsziele; Self-Checks nur Empfehlung ohne AFO.
- **Backup/Restore/DR** – keine Sicherungs-/Wiederherstellungsanforderungen für die
  PDP-DB (Sessions, Client-Registry, Recovery-Code-Hashes, E-Mail-Bindungen); Datenverlust
  erzwänge Massen-Re-Registrierung. Geo-Redundanz (A_28438-01) regelt nur den Load Balancer.
- **Key-Rotation-Prozesse** – nur Konfigurierbarkeit (A_26281-01), keine Intervalle, kein
  Rollover-Prozess (JWKS-Overlap) für `PrK.AuthS.Sig`.
- **Mengengerüst/Skalierung** – keine erwarteten Client-/Nutzerzahlen; E-Mail-Versand
  (sicherheitskritischer Faktor F1) ohne Kapazitäts-/Zustellbarkeitsanforderung;
  Incident-Prozesse nur für VAU-Konfigurationsänderungen.

---

## 7. User-Experience-Verbesserungen (bei gleicher Sicherheitsleistung)

Journey-Befund: Erstregistrierung stationär = ZAS-Installation (Adminrechte) + DCR mit
TPM-Roundtrip + SMC-B-Token-Exchange; mobil = Schlüsselgenerierung + DCR + E-Mail-OTP +
voller OIDC-Flow mit App-Wechsel; tägliche Anmeldung = Refresh-Rotation, Re-Auth nach
Ablauf – **Frequenz mangels Laufzeitangabe unbekannt**; Mehrfach = einmal je Guard mit
erneuter E-Mail-Verifikation je Client.

| # | Vorschlag | Journey | Heute (Fundstelle) | Sicherheitsbegründung (gleiche Leistung) |
|---|-----------|---------|--------------------|-------------------------------------------|
| U1 | **Längere Refresh-Token-Laufzeit** normieren (z. B. LEI ≥12 h, Versicherte mehrere Tage) | tägliche Anmeldung | unspezifiziert, „fest konfiguriert" (A_28527-Hinweis S. 124) | Token DPoP-gebunden (A_25663), rotiert mit Reuse-Detektion (A_25662), Policy je Einsatz (A_29844), Session-Termination (A_29854/55) – privater Schlüssel bleibt im HW-Modul; Angriffsfläche wächst nicht |
| U2 | **Proaktives Token-Refresh im ZETA Client** (analog ZG Client A_29883) | tägliche Nutzung/Latenz | Client erneuert nur „nach Bedarf" (A_25782, S. 89) | identische Token & Prüfungen (Policy je Refresh); nur Zeitpunkt der ohnehin erlaubten Erneuerung verschiebt sich |
| U3 | **IDP-Session-Wiederverwendung über mehrere Guards** (Silent Re-Auth) normieren | mehrere Fachdienste | nur Hinweis zu A_29899 (SSO), keine AFO | acr/amr unverändert vom IDP bescheinigt und je Guard geprüft; IDP-Session-Dauer in gemSpec_IDP_Sek geregelt – ZETA schwächt nichts, spart Interaktion |
| U4 | **`request_uri`-Gültigkeit 5 s → 60–90 s** | mobile Anmeldung | „sehr kurz von 5 Sekunden" (S. 70); IDP erlaubt 90 s (S. 71) | einmalig einlösbar, an client_id gebunden, PKCE-Challenge – längere Frist verlängert Angriffsfenster nicht substanziell (RFC 9126) |
| U5 | **Nonce per Response-Header** (`DPoP-Nonce`, RFC 9449) statt separatem `GET /nonce` | alle Token-/Attestation-Flows | eigener Roundtrip (S. 49/65/67/76) | serverseitige Einmal-Nonce identisch, nur Transportweg ändert sich |
| U6 | **Cross-Guard-Bootstrap** (Fast-Path A_29913–A_29920) verbindlich + auf stationär ausdehnen; „Big App"-Punkt schließen | Mehrfachregistrierung | „einmalig je Guard" (A_28465), OTP je Guard (A_29910); Fast-Path nur mobil | von der Spec selbst „mindestens so stark wie E-Mail-OTP-Erstnutzung" (S. 100); über F2 (HW-Instanzschlüssel) verankert; Pflicht-Notification (A_29920) bleibt |
| U7 | **Endnutzer-Fehlerkatalog** (kanonische Reason-Codes + lokalisiertes Mapping) | Fehlermeldungen | freie engl. Strings aus OPA (S. 29; A_25752-01) | reine Präsentationsschicht; kodierte Codes geben Angreifern nicht mehr Information – eher weniger |
| U8 | **Netzwechsel: nur Access Token invalidieren**, Refresh Token behalten | Roaming/Dual-Stack | A_28803 sperrt Access **und** Refresh + bricht Operation ab (S. 23); IPv4↔IPv6 löst das aus (A_29872) | Dieb ohne HW-gebundenen DPoP-Schlüssel kann Refresh ohnehin nicht einlösen (A_25663); nächster Refresh erzwingt Policy-Neubewertung – Replay-Schutz bleibt voll |
| U9 | **Registrierungsschritte parallelisieren** (OTP-Versand ∥ OIDC-Flow) | mobile Erstregistrierung | strikt sequenziell (A_29903/29905, S. 99) | Freigabebedingung (E-Mail ∧ Identität ∧ Attestation) unverändert; nur Erhebungsreihenfolge ändert sich |
| U10 | **Recovery-Führung im Client** (A_29933 SOLL→MUSS, Wizard, aktive Bestätigung der Code-Ablage) | Gerätewechsel/Recovery | nur SOLL (A_29933); Codes „einmalig im Klartext" (A_29906) | kein Eingriff ins Faktormodell/Schwellwerte (A_29928); erhöht nur die Chance auf einen überlebenden Faktor → seltener der teure OOB-Pfad (stärkt Sicherheit eher) |
| U11 | **Attestation-Frequenz an Plattform-Rate-Limits koppeln** (Folge-Assertions statt Voll-Attestation) | tägliche Anmeldung mobil | A_25649 „für jede neue Session" (SOLL), Hinweis warnt vor Rate-Limits ohne Fallback | Folge-Assertions kryptografisch an denselben AK + Klon-Schutz-Counter gebunden; Niveau definiert und in Policy abgebildet statt undefiniertem Ad-hoc-Verhalten |

---

## 8. Priorisierte Korrektur-Roadmap

**P0 – vor Freigabe 1.4.0 (Interop-/Security-blockierend):**
1. aud-Claim-Modell vereinheitlichen (K1) – A_26681-02 + Tab. 19 ↔ 5.4.2.2.
2. PEP-Statuscodes vereinheitlichen (K2) – A_28525-02/A_29676/A_29860.
3. Recovery-Diagramm korrigieren (K3/H1) – IDP-Step-up, keine E-Mail-Neubindung, `POST /zeta/recover`.
4. Schema-Bug `attestation_result.required` beheben (K9).
5. A_27802-02 streichen (K6); ML-189815 auflösen (K10).
6. Refresh-Token-Widerspruch S. 77 ↔ A_29894 auflösen; `token-response.yaml` optional (K7-nah).

**P1 – Redaktion/Normvervollständigung:**
7. Token-Laufzeiten normieren (K7).
8. Token Revocation als Kapitel + AFO + Tab. 22/23 nachziehen; RFC 7009 (K4).
9. Kap. 5.12 Notification Service ausarbeiten, `A_NS_*` in AFOs (K8 + Security 5.2).
10. `A_ZGTOFU_*`-IDs mappen (K5); falsche Abbildungsreferenzen korrigieren (K5b).
11. Client-Statusmodell konsolidieren + `dcr-response-202.yaml`-Enum.
12. Referenz-/Abbildungsverzeichnis vervollständigen; @startuml-IDs/Diagrammnamen vereinheitlichen.

**P2 – Sicherheits-Nachschärfung (MUSS statt KANN):**
13. Refresh-Token-Reuse-Detection (H2); untrusted `Forwarded`-Header verwerfen (H3);
    verpflichtende Rate-Limits + OTP-Brute-Force-Schutz; DPoP-jti-Replay am PEP;
    Play-Integrity/SW-Fallback normativ regeln; TLS 1.3 als SOLL.

**P3 – Anforderungsqualität & UX:**
14. Adressaten-Attribut je AFO; Testsuite/Testvektoren/Fehlerkatalog für Hersteller;
    SLA/Backup/Key-Rotation/Mengengerüst für Anbieter; UX-Maßnahmen U1–U11 prüfen.

---

## Anhang A – Diagramm → Spec-Status (Kurzfassung)

Konsistent (~20): Client-Start-TPM-ZAS, TPM-Client-Statement, stationäre DCR (Haupt),
Dienst-zu-Dienst (beide), OAuth-ohne-Nutzer, OIDC-Übersicht/-Nutzerauth/-Token-Bezug,
äußerer+innerer PAR, Schlüsselgen. Android/Apple, Service Discovery, TPM-Attestation-Key,
Token-Exchange-Refresh, Zugriff-auf-RS mit/ohne ASL.
Kritisch abweichend (3): **DCR-Account-Recovery**, **Client-Statement-Android**,
**Token-Revocation** (nicht in Spec).
Mittel/gering abweichend: Apple-Statement (Spec 5.3.1.6.2 veraltet), veraltetes
PAR-Diagramm, Token-Exchange-mit-Attestation (Parameter fehlen), DCR-Varianten
(stationär-Apple / mobil-Apple-HW), Schlüsselgen-Windows-Linux-Split.
Ohne Spec-Referenz / veraltet: „Vorbereitung-Token-Exchange-*" (3×),
„Token-Exchange-Subject-Token", veraltetes „…Request-mit-PAR".
Fehlende Quelle: **Abb. 8 „SE-Attestation-Key"** (in Spec, keine .puml).

## Anhang B – Schema → Spec-Status (Kurzfassung)

Konsistent: access-token, client-statement, dpop-token, federation-master, opr-well-known,
pdp-decision, posture(-tpm/-apple/-android), product-id-*, subject-token-smb, verify-request.
Abweichend: **policy-engine-client-data** (kritischer required-Bug), as-well-known
(revocation_*/openid_providers_endpoint), client-assertion-jwt (iat/nonce), client-data
(platform), dcr-request (zeta_cross_guard/user_email/PoP), dcr-response-202
(pending_user_binding), token-response (error/refresh_token/Keycloak-Felder),
zeta-attestation-token (exp/cnf.jwk), zeta-user-info (Tab. 17/18 snake_case), posture-software
(nonce), policy-engine-input (Zusatzfelder/required).
In Spec nicht beschrieben: authorization-details (RAR), user-info (bewusst, RS-Kompat.),
tmp/api-catalog, tmp/session.
