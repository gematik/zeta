# ZETA API v1.3.0

## Dokumenten- und Versionsübersicht

| Attribut                    | Wert                        |
|-----------------------------|-----------------------------|
| Dokumenttitel               | ZETA API v1.3.0             |
| Dokumentversion             | 1.3.0                       |
| Stand                       | 2026-05-26                  |
| Status                      | Final Draft                 |
| Verantwortlich              | gematik                     |
| Gültigkeitsbereich          | ZETA Guard API              |
| Spezifikationsgrundlage     | gemSpec_ZETA, Version 1.3.1 |

### Zuordnung zu API- und Implementierungsversionen

Dieses Dokument beschreibt die Schnittstellen und Abläufe der **ZETA API Version v1.3.0**.  
Die beschriebenen Inhalte beziehen sich auf die folgenden Implementierungsversionen.

| Komponente                     | Artefakt / Image                     | Version | Beschreibung                             |
|--------------------------------|--------------------------------------|---------|------------------------------------------|
| ZETA Guard (PEP)               | zeta-guard-pep                       | 1.3.0   | Policy Enforcement Point (HTTP Proxy)    |
| ZETA Guard (PDP)               | zeta-guard-pdp                       | 1.3.0   | Authorization Server / Policy Decision   |
| ZETA Client SDK                | zeta-sdk                             | 1.3.0   | Clientbibliothek zur Integration         |
| Helm Charts                    | zeta-helm-charts                     | 1.3.0   | Helm Charts                              |
| Terraform                      | zeta-guard-terraform                 | 0.3.0   | Terraform                                |
| Provisioning Processor         | zeta-guard-provisioning-processor    | 1.3.0   | Provisioning Processor                   |

---

### Docker-Image Referenzen

Die oben genannten Komponenten werden als OCI-konforme Container Images in der ZETA Artifact Registry bereitgestellt.  

Repository: [europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr](https://europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr)

#### Produkt

- PEP (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/ngx_pep:1.3.0)
- PDP (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/keycloak-zeta:1.3.0)
- Provisioning Processor (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/provisioning-processor:1.3.0)
- Nginx Ingress (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/nginx-ingress:1.3.0)
- Nginx-Prometheus-Exporter (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/nginx-prometheus-exporter:1.5.1-zeta2)
- Open Policy Agent (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/opa:1.14.1-static)
- Postgres (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/postgres:17.9-standard-trixie)
- Telemetry Gateway (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/zeta-telemetry-gateway:v0.151.0-release.3)

#### Test

- Tiger-Testsuite (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/tiger-testsuite:1.3.0)
- Testfachdienst (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/testfachdienst:1.3.0)
- HSM Simulator (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/hsm_sim:1.3.0)
- Zeta-Tigerproxy (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/testproxy:1.3.0)
- Zeta TLS Test Tool (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/zeta-tls-test-tool-service:1.3.0)
- Cert Validation Mock (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/zeta-cert-validation-mock:1.3.0)
- PoPP Token Generator (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/popp-token-generator:1.3.0)

---

## 1. Einführung

Diese API beschreibt die Interaktion eines ZETA Clients mit der ZETA Guard Infrastruktur.
Dabei werden stationäre Clients (z. B. Arbeitsplatz- oder Serversysteme), mobile Clients (z. B. mobile Endgeräte mit iOS oder Android Betriebssystemen) sowie die direkte Dienst-zu-Dienst (Backend-to-Backend) Kommunikation unterstützt.

Unabhängig von der Ausprägung stellt die API Mechanismen zur Verfügung, um:

- eine initiale Vertrauensbeziehung zwischen Client und ZETA-Infrastruktur aufzubauen (Trust Establishment via Dynamic Client Registration),
- den Sicherheits- und Integritätszustand eines Clients kryptografisch zu bewerten (Posture / Attestation unter Verwendung von TPM 2.0, Apple App Attest, Android Key Attestation oder Software-Fallback),
- sowie den Zugriff auf ZETA-geschützte Dienste über Token-basierte Verfahren (OAuth 2.0 Token Exchange, DPoP, und optionale Verschlüsselung über den ZETA/ASL-Kanal) zu authentifizieren und zu autorisieren.

Die API begleitet einen ZETA Client über dessen gesamten Lebenszyklus hinweg und unterstützt sowohl einmalige als auch wiederkehrende Interaktionen.

## 2. Voraussetzungen für die ZETA Client Nutzung

Folgende Voraussetzungen müssen für die Nutzung des ZETA Clients erfüllt sein:

- **FQDN des Resource Servers:** Wird vom ZETA Client benötigt, um die ZETA Guard API zu erreichen.
- **Trust Anchor Informationen (roots.json):** Die [roots.json](https://download.tsl.ti-dienste.de/ECC/ROOT-CA/roots.json) Datei wird vom ZETA Client benötigt, um die Vertrauenskette beim ZETA/ASL Verbindungsaufbau zu validieren. Diese Datei muss wöchentlich aktualisiert werden.
- **VSDM2 (anwendungsspezifisch):** Für VSDM2 Requests wird ein PoPP (Proof of Patient Presence) Token benötigt. Das PoPP Token muss im Header `PoPP` an den ZETA Client übergeben werden.

## 3. Discovery und Konfiguration

### 3.1 Zweck

In dieser Phase ermittelt der ZETA Client dynamisch die notwendigen Endpunkte und Konfigurationen, um mit der ZETA Guard Infrastruktur (PEP HTTP Proxy und PDP Authorization Server) eines TI 2.0 Dienstes zu kommunizieren. Dies stellt sicher, dass sich der Client dynamisch an die bereitgestellte Infrastruktur anpassen kann.

### 3.2 Ablauf

Der Service Discovery-Ablauf ist für stationäre und mobile Clients identisch:

- **Verwendete Endpunkt-Pfade:** `GET /.well-known/oauth-protected-resource` und `GET /.well-known/oauth-authorization-server`

1. **Initiale Voraussetzungen**
   Der Client verfügt über den FQDN des Resource Servers.
2. **Abruf der Resource Server Konfiguration**
   Der Client sendet eine GET-Anfrage an den standardisierten Well-Known-Endpunkt der geschützten Ressource (Protected Resource):

   ```http
   GET /.well-known/oauth-protected-resource HTTP/1.1
   Host: api.example.com
   Accept: application/json
   ```

   Die Antwort entspricht dem Schema [opr-well-known.yaml](../../../src/schemas/opr-well-known.yaml) und liefert unter anderem die URL des PDP Authorization Servers (`authorization_servers`).
3. **Abruf der Authorization Server Konfiguration**
   Der Client sendet eine GET-Anfrage an den Well-Known-Endpunkt des ermittelten PDP Authorization Servers:

   ```http
   GET /.well-known/oauth-authorization-server HTTP/1.1
   Host: auth.example.com
   Accept: application/json
   ```

   Die Antwort entspricht dem Schema [as-well-known.yaml](../../../src/schemas/as-well-known.yaml) und liefert alle Endpunkt-URLs (wie `/register`, `/token`, `/nonce`) und unterstützte kryptografische Algorithmen.
4. **Konfigurations-Update**
   Der Client konfiguriert sich lokal für die Nutzung der ZETA Guard Instanz.

Der detaillierte Discovery-Ablauf ist in der folgenden Abbildung dargestellt:

![Abbildung 1: Ablauf Service Discovery](../../../images/zeta-flows/Abb-ZETA-Service-Discovery.svg)

## 4. Client Registrierung und Trust Bootstrapping

### 4.1 Zweck

Die Client-Registrierung ist der Prozess, mit dem ein ZETA Client erstmalig gegenüber der ZETA-Infrastruktur registriert wird, um eine eindeutige, kryptografisch überprüfbare Identität (Client Instance Key) zu etablieren. Erst nach erfolgreicher Registrierung erhält der Client eine `client_id` mit dem Status `pending_attestation`. Die Aktivierung des Clients erfolgt beim ersten Token Exchange durch eine erfolgreiche Attestierung.

### 4.2 Ablauf für stationäre Clients

Der Bootstrapping- und Registrierungsprozess stationärer Clients wird nachfolgend getrennt nach Plattform beschrieben. Die Plattformpfade durchlaufen dieselben vier logischen Phasen — Installation und Schlüsselgenerierung, Client-Start, Vorbereitung der Registrierung und Dynamic Client Registration — unterscheiden sich jedoch grundlegend in den eingesetzten Sicherheitsmechanismen.

---

#### 4.2.1 Windows und Linux mit TPM 2.0 und ZAS

Unter Windows und Linux basiert der Vertrauensaufbau auf dem **Trusted Platform Module (TPM 2.0)** und dem privilegierten Hintergrunddienst **ZETA Attestation Service (ZAS)**.

##### 4.2.1.1 Installation und Schlüsselgenerierung

- *(01) Privilegierte ZAS-Installation:* Der ZAS wird mit administrativen Rechten (Root/Admin) installiert. Nur so kann er Messungen in TPM PCR-Register schreiben.
- *(02) Unprivilegierte Client-Installation:* Der ZETA Client wird im Benutzerkontext des Primärsystems installiert.
- *(03)–(04) IPC-Vertrauensbeziehung:* Zwischen ZAS (privilegiert) und ZETA Client (User Space) wird eine gegenseitig authentifizierte IPC-Verbindung aufgebaut, gesichert durch Code-Signatur-Prüfungen beider Seiten.
- *(05)–(06) Client Instance Key:* Das langlebige Signatur-Schlüsselpaar (`PrK.Client.Sig` / `PuK.Client.Sig`) wird über den OS- oder TPM-Provider erzeugt. Der öffentliche Schlüssel und das Handle werden dem Client übergeben.
- *(07) Systemmessung:* Der ZAS misst die unveränderlichen Teile des Primärsystems.
- *(08) Storage Root Key (SRK):* Im TPM wird ein SRK als lokaler Vertrauensanker erzeugt.
- *(09)–(12) Attestation Key (AK):* Ein hardwaregebundener Attestierungsschlüssel (`PrK.AK.Sig` / `PuK.AK.Sig`) wird im TPM erzeugt und geladen. Das AK-Handle wird an den ZETA Client übergeben.
- *(13) PCR-Erweiterung:* Die Messwerte der unveränderlichen Systemkomponenten werden in PCR 23 geschrieben und bilden die initiale Baseline.
- *Fallback (14)–(15):* Ist kein TPM vorhanden oder kein PCR frei, erzeugt der ZETA Client das Schlüsselpaar im Software-Kontext (Software-Attestation).

![Abbildung 2: Schlüsselgenerierung auf Windows und Linux](../../../images/zeta-flows/Abb-ZETA-Schlüsselgenerierung-Windows-und-Linux.svg)

##### 4.2.1.2 Client-Start und Baseline-Aktualisierung

Bei jedem Systemboot und jedem Start des Primärsystems führt der ZAS eine erneute Integritätsmessung durch:

- *(01) ZAS-Bootstart:* Der ZAS wird beim Booten als Systemdienst gestartet.
- *(02)–(03) Initiale Messung:* Der ZAS misst unveränderliche Systemteile und erweitert PCR 23.
- *(04)–(08) Client-Startmessung:* Sobald der ZAS den Start des Primärsystems erkennt, führt er eine zweite Messung durch und erweitert erneut PCR 23, um den aktuellen Systemzustand im TPM zu verankern.

![Abbildung 3: Client Start mit TPM und ZAS](../../../images/zeta-flows/Abb-ZETA-Client-Start-mit-TPM-und-ZAS.svg)

##### 4.2.1.3 Vorbereitung der Client-Registrierung (Key Certification)

Vor der Registrierung beim AuthS muss der Client nachweisen, dass `PuK.Client.Sig` auf demselben physischen TPM-Chip existiert wie der AK:

- *(01)–(03) Client-Key laden:* Der ZETA Client übergibt das Schlüssel-Handle und den SHA-256-Hash von `PuK.Client.Sig` an den ZAS. Der ZAS lädt den Client-Schlüssel in das TPM.
- *(04)–(05) TPM2_Certify:* Das TPM führt eine `TPM2_Certify`-Operation durch: Es signiert mit `PrK.AK.Sig` kryptografisch, dass sich `PuK.Client.Sig` im selben TPM-Sicherheitschip befindet. Ergebnis sind `tpm2b_attest` (Zertifizierungsdaten) und `tpmt_signature` (Signatur).
- *(06)–(14) EK und AK auslesen:* Der ZAS liest den öffentlichen Endorsement Key (`PuK.EK.Enc`), den öffentlichen AK (`PuK.AK.Sig`) und das herstellerseitige EK-Zertifikat (`C.EK.Enc`) aus dem TPM und übergibt alle Daten an den ZETA Client.

![Abbildung 4: Vorbereitung per TPM Attestation Key](../../../images/zeta-flows/Abb-ZETA-TPM-Attestation-Key.svg)

##### 4.2.1.4 Dynamic Client Registration (DCR)

- **Verwendete Endpunkt-Pfade (Windows/Linux):** `POST /register` und `POST /register/verify`
- *(01) POST /register:* Der ZETA Client sendet die Registrierungsanfrage gemäß Schema [dcr-request.yaml](../../../src/schemas/dcr-request.yaml) an den PDP AuthS. Der Body enthält `attestation_type: "tpm"`, `PuK.Client.Sig`, `PuK.AK.Sig`, `PuK.EK.Enc`, `C.EK.Enc` und `signed_hash_puk_client_sig`.
- *(02)–(03) MakeCredential:* Der AuthS validiert die EK-Zertifikatskette gegen die Hersteller-CA. Zur Verifikation des Schlüsselbesitzes generiert er ein verschlüsseltes `CredentialBlob` per `TPM2_MakeCredential` (verschlüsselt mit `PuK.EK.Enc`, gebunden an `PuK.AK.Sig`) und antwortet mit `202 Accepted {CredentialBlob}`.
- *(04)–(08) ActivateCredential:* Der ZETA Client leitet das `CredentialBlob` an den ZAS weiter. Der ZAS führt im TPM `TPM2_ActivateCredential` aus — dieser Befehl gelingt nur, wenn EK und AK im selben TPM vorhanden sind. Das entschlüsselte Secret wird an den Client zurückgegeben.
- *(09)–(10) POST /register/verify:* Der Client sendet das Secret an den AuthS. Der AuthS verifiziert das Secret und schließt die Registrierung ab: `201 Created {client_id}` mit Status `pending_attestation`.

![Abbildung 5: DCR für stationäre Clients](../../../images/zeta-flows/Abb-ZETA-DCR-für-stationäre-Clients.svg)

---

#### 4.2.2 macOS mit Secure Enclave

Unter macOS (sowie iOS und iPadOS) basiert der Vertrauensaufbau vollständig auf der hardwareintegrierten **Secure Enclave** und den Apple-eigenen APIs **App Attest** bzw. **DeviceCheck**. Ein separater privilegierter Dienst wie der ZAS ist nicht erforderlich.

##### 4.2.2.1 Installation und Schlüsselgenerierung

- *(01) App-Installation:* Die Anwendung inklusive ZETA Client wird im User Space des Apple-Betriebssystems installiert.
- *(02)–(05) Secure Enclave Key-Generierung:* Der ZETA Client ruft die native Apple API `SecKeyCreateRandomKey` mit dem Parameter `kSecAttrTokenIDSecureEnclave` auf. Das Betriebssystem leitet den Befehl an die isolierte Secure Enclave weiter. Dort wird das Schlüsselpaar (`PrK.Client.Sig` / `PuK.Client.Sig`) erzeugt. **Der private Schlüssel verlässt die Secure Enclave zu keinem Zeitpunkt.** Das OS übergibt dem Client lediglich eine Schlüsselreferenz (`keyId`).
- *Fallback (06):* Ist die Secure Enclave nicht verfügbar, erzeugt der ZETA Client das Schlüsselpaar im regulären Software-Speicher (Software-Fallback ohne Hardwarebindung).

![Abbildung 6: Schlüsselgenerierung auf macOS](../../../images/zeta-flows/Abb-ZETA-Schlüsselgenerierung-macOS.svg)

##### 4.2.2.2 Client-Start und Posture-Erhebung

Unter macOS gibt es keinen privilegierten ZAS-Dienst. Die Integritätsbewertung basiert stattdessen auf der Erhebung von Sicherheitszustandsdaten (Posture):

- *(01)–(03) Systemstart:* Der ZETA Client startet direkt im User Space ohne Voraussetzungen durch einen Admin-Dienst.
- *(04) Posture-Erhebung:* Der Client liest über native macOS APIs die sicherheitsrelevanten Systemzustände aus:
  - System Integrity Protection (SIP): aktiviert / deaktiviert
  - Gatekeeper: aktiviert / deaktiviert
  - Secure Boot Policy: Full / Medium / No Security
  - FileVault-Status
  - Betriebssystemversion und Build-Nummer
- *(05) Initialisierung:* Der Client initialisiert seine internen Sitzungsstrukturen im Benutzerkontext.

##### 4.2.2.3 Vorbereitung der Client-Registrierung (Apple Attestation)

Vor der Registrierung beim AuthS muss der ZETA Client nachweisen, dass der `PuK.Client.Sig` hardwaregebunden in der Secure Enclave vorliegt:

- **Verwendeter Endpunkt-Pfad (macOS/Apple):** `GET /nonce`
- *(01)–(02) Nonce abrufen:* Der Client fordert eine frische Nonce beim PDP AuthS an (`GET /nonce`).
- *(03)–(04) Posture-Daten erheben:* Der Client liest die aktuellen Sicherheitszustände aus (SIP, Gatekeeper, OS-Version, Secure Boot).
- *(05) clientDataHash berechnen:* Der Client berechnet `clientDataHash = SHA256(Nonce ‖ Posture-Daten)`. Dieser Hash bindet den Attestierungsnachweis fest an die aktuelle Transaktion.
- *(06) Apple API aufrufen:* Der Client ruft `DCAppAttestService.shared.attestKey(keyId_AK, clientDataHash)` auf und übergibt den berechneten Hash an die Secure Enclave.
- *(07)–(08) Secure Enclave signiert:* Die Secure Enclave signiert ausschließlich den übergebenen Hash mit `PrK.AK.Sig`. Sie erzeugt zudem einen monoton steigenden Replay-Counter.
- *(09)–(11) Apple Attestation Object:* Das OS verpackt Signatur, Apple-Zertifikatskette und Authenticator-Daten (inkl. Counter) in ein standardisiertes, CBOR-kodiertes **Apple Attestation Object** und übergibt es dem ZETA Client.

![Abbildung 7: Vorbereitung per Secure Enclave Attestation Key](../../../images/zeta-flows/Abb-ZETA-SE-Attestation-Key.svg)

##### 4.2.2.4 Dynamic Client Registration (DCR)

- **Verwendeter Endpunkt-Pfad (macOS/Apple):** `POST /register`
- *(11)–(12) POST /register:* Der ZETA Client sendet die Registrierungsanfrage gemäß Schema [dcr-request.yaml](../../../src/schemas/dcr-request.yaml) an den PDP AuthS. Der Body enthält `attestation_type: "apple"`, `PuK.Client.Sig`, `PuK.AK.Sig` und `apple_attestation_object`.
- *(13) AuthS validiert Apple Attestation Object:* Der AuthS prüft die X.509-Zertifikatskette gegen die offizielle **Apple App Attest Root CA**, verifiziert den Replay-Counter und stellt sicher, dass `PuK.AK.Sig` identisch mit dem Schlüssel in `x5c[0]` des Attestation Objects ist.
- *(14) Hash-Rekonstruktion:* Der AuthS rekonstruiert `clientDataHash` aus der übermittelten Nonce und den Posture-Klartextdaten und prüft die Übereinstimmung mit dem signierten Hash. Nur bei Übereinstimmung ist der Nachweis gültig.
- *(15) signed_hash_puk_client_sig prüfen:* Der AuthS verifiziert, dass `PuK.Client.Sig` durch `PrK.AK.Sig` signiert wurde, was beweist, dass beide Schlüssel auf demselben Gerät kontrolliert werden.
- *(16) Abschluss:* Bei erfolgreicher Validierung antwortet der AuthS mit `201 Created {client_id}` mit Status `pending_attestation`.

![Abbildung 8: DCR für stationäre Clients](../../../images/zeta-flows/Abb-ZETA-DCR-für-stationäre-Clients.svg)

### 4.3 Ablauf für mobile Clients

Der Lebenszyklus mobiler Clients folgt denselben vier logischen Phasen wie bei stationären Clients — Schlüsselgenerierung, Client-Start, Attestierungs-Vorbereitung und DCR. Mobile Clients unterscheiden sich jedoch grundlegend in der eingesetzten Attestierungstechnologie und erfordern zusätzlich eine interaktive **Nutzerbindung (Trust-On-First-Use, TOFU)**. Die Beschreibung ist getrennt nach Android und Apple iOS/iPadOS.

---

#### 4.3.1 Android (TEE / StrongBox)

Unter Android basiert der Vertrauensaufbau auf dem **Trusted Execution Environment (TEE)** oder der hardwaregesicherten **StrongBox** und nutzt die **Android Key Attestation** sowie optional die **Google Play Integrity API**.

##### 4.3.1.1 Schlüsselgenerierung

Android verwendet ein **Zwei-Schlüssel-Modell**: Ein langlebiger Client Instance Key dient der Authentifizierung, ein separater Attestation Key beweist die Hardwarebindung.

- *(01) Client Instance Key anfordern:* Der ZETA Client fordert über den Android `KeyStore` die Generierung des primären Signaturschlüssels (`PrK.Client.Sig` / `PuK.Client.Sig`) an, mit dem Parameter `StrongBoxBacked = true` (Fallback auf TEE).
- *(02)–(03) Schlüssel in Hardware erzeugen:* Das Betriebssystem leitet den Befehl an TEE oder StrongBox weiter. Das Schlüsselpaar wird dort erzeugt. **Der private Schlüssel verlässt die Hardware zu keinem Zeitpunkt.** Der Client erhält nur eine Alias-Referenz zurück.
- *(04) Hash berechnen:* Der Client berechnet `hash_puk_client_sig = SHA256(PuK.Client.Sig)`. Dieser Hash dient als Bindeglied zum Attestation Key.
- *(05) Attestation Key anfordern:* Der Client fordert die Generierung eines zweiten Schlüssels (Attestation Key, `PrK.AK.Sig` / `PuK.AK.Sig`) an und übergibt dabei `hash_puk_client_sig` als `AttestationChallenge`.
- *(06)–(08) AK mit Challenge attestieren:* TEE oder StrongBox erzeugt das AK-Schlüsselpaar und eine X.509-Zertifikatskette. Der Challenge-Hash wird kryptografisch und unveränderlich in das AK-Zertifikat eingebettet — so beweist die Kette, dass `PuK.Client.Sig` zur Schlüsselgenerierung dieses AK gehört.
- *(09) Zertifikatskette übergeben:* Die fertige `android_key_attestation_certificate_chain` (Leaf bis Google Hardware Attestation Root CA) wird an den Client übergeben.
- *(10)–(13) Besitznachweis (Proof of Possession):* Der Client lässt `hash_puk_client_sig` durch den `PrK.AK.Sig` in der Hardware signieren. Ergebnis ist `signed_hash_puk_client_sig` (ECDSA-Signatur).
- *(14)–(15) Play Integrity Token (optional):* Der Client ruft die Google Play Integrity API auf und übergibt `hash_puk_client_sig` als Nonce. Google liefert ein signiertes `play_integrity_token`, das den Laufzeitzustand von Gerät und App bestätigt und an den Client-Schlüssel bindet.

![Abbildung 9: Schlüsselgenerierung auf Android](../../../images/zeta-flows/Abb-ZETA-Schlüsselgenerierung-Android.svg)

##### 4.3.1.2 Client-Start und Posture-Erhebung

Unter Android gibt es keinen separaten privilegierten Dienst. Die Sicherheitszustände werden durch das Betriebssystem bereitgestellt:

- *(01) App-Start:* Der ZETA Client startet im App-Prozess unter dem normalen Android App-Sandbox-Modell.
- *(02) Posture-Erhebung:* Der Client fragt folgende Sicherheitszustände über Android-System-APIs ab:
  - Verified Boot State (`LOCKED` / `UNLOCKED`)
  - Security Patch Level (Monat/Jahr)
  - OS-Version und Build-Fingerprint
  - Hersteller und Gerätemodell
  - `isDeviceSecure` (Bildschirmsperre aktiv?)
- *(03) Initialisierung:* Die internen Sitzungsstrukturen (Token-Speicher, DPoP-Key-Kontext) werden initialisiert.

##### 4.3.1.3 Vorbereitung der Client-Registrierung

Der Attestierungsnachweis steht bereits nach der Schlüsselgenerierung bereit — die `android_key_attestation_certificate_chain` beweist die Hardwarebindung; `signed_hash_puk_client_sig` beweist den Schlüsselbesitz. Eine zusätzliche Challenge-Anfrage an den AuthS ist in dieser Phase nicht erforderlich, da die Challenge (`hash_puk_client_sig`) clientseitig berechnet wurde.

Vor der DCR ruft der Client optional die Play Integrity API erneut auf, um einen frischen `play_integrity_token` mit der aktuellen Nonce zu erhalten.

##### 4.3.1.4 Dynamic Client Registration und TOFU-Nutzerbindung

Falls kein ZETA Attestation Token vorhanden ist, wird der Pfad **Hardware Attestation: Android** durchlaufen.
*Hinweis: Der ZETA Client erhält ein ZETA Attestation Token beim ersten erfolgreichen DCR-Prozess bei einem ZETA Guard und speichert es lokal für zukünftige DCR-Prozesse bei anderen ZETA Guards. Dadurch wird die Notwendigkeit der TOFU-Nutzerbindung beim ersten DCR bei einem neuen ZETA Guard umgangen.*

- **Verwendete Endpunkt-Pfade (Android):** `POST /register` und `POST /register/verify`
- *POST /register:* Der ZETA Client sendet die Registrierungsanfrage gemäß Schema [dcr-request.yaml](../../../src/schemas/dcr-request.yaml) an den PDP AuthS. Der Body enthält:
  - `attestation_type: "android"`
  - `puk_client_sig` (JWK)
  - `puk_ak_sig` (JWK)
  - `android_key_attestation_certificate_chain` (Array von Base64-DER-Zertifikaten)
  - `signed_hash_puk_client_sig` (Base64url-ECDSA-Signatur)
  - `play_integrity_token` (optional)
- *AuthS validiert Zertifikatskette:* Der AuthS prüft die Zertifikatskette gegen die Google Hardware Attestation Root CA und liest den eingebetteten Challenge-Wert (`hash_puk_client_sig`) aus dem AK-Zertifikat aus.
- *AuthS verifiziert Besitznachweis:* Der AuthS verifiziert `signed_hash_puk_client_sig` mit `PuK.AK.Sig` und bestätigt, dass `PuK.Client.Sig` zum selben Hardware-Schlüsselsatz gehört.
- *AuthS validiert Play Integrity (optional):* Der AuthS validiert das `play_integrity_token` gegenüber der Google Play Integrity API, um Laufzeitzustand und App-Integrität zu verifizieren.
- *TOFU E-Mail-Bindung:* Der AuthS sendet einen OTP-Bestätigungscode an die im Request angegebene E-Mail-Adresse des Nutzers. Der Nutzer gibt den Code im Client ein; der Client sendet ihn via `POST /register/verify` an den AuthS.

Falls ein ZETA Attestation Token vorhanden ist, wird der Pfad **ZETA Attestation Token vorhanden (Fast-Path)** durchlaufen.
- *POST /register:* Der ZETA Client sendet die Registrierungsanfrage gemäß Schema [dcr-request.yaml](../../../src/schemas/dcr-request.yaml) an den PDP AuthS. Der Body enthält:
  - `attestation_type: "zeta_attestation_token"`
  - `zeta_attestation_token` (Base64url-kodiertes ZETA Attestation Token)
  - `puk_client_sig` (JWK)
  - `signed_hash_puk_client_sig` (string)

- *Abschluss:* Der AuthS bestätigt die Registrierung mit `201 Created {client_id}` mit Status `pending_user_binding`.

![Abbildung 10: DCR für mobile Clients](../../../images/zeta-flows/Abb-ZETA-DCR-für-mobile-Clients.svg)

---

#### 4.3.2 Apple iOS und iPadOS (Secure Enclave)

Unter iOS und iPadOS basiert der Vertrauensaufbau auf der hardwareintegrierten **Secure Enclave** und der Apple-eigenen **App Attest API** (DeviceCheck-Framework). Der Ablauf ist identisch zu macOS (vgl. Kapitel 4.2.2), unterscheidet sich jedoch in plattformspezifischen Posture-Parametern.

##### 4.3.2.1 Schlüsselgenerierung

- *(01) App-Installation:* Die App inklusive ZETA Client wird über den App Store installiert und im App-Sandbox-Kontext des iOS/iPadOS-Betriebssystems gestartet.
- *(02) Client Instance Key anfordern:* Der ZETA Client ruft `SecKeyCreateRandomKey` mit `kSecAttrTokenIDSecureEnclave` auf, um das Schlüsselpaar (`PrK.Client.Sig` / `PuK.Client.Sig`) in der Secure Enclave zu erzeugen.
- *(03) Schlüssel in Secure Enclave erzeugen:* Das Betriebssystem leitet den Befehl an den isolierten Hardware-Chip weiter. **Der private Schlüssel verlässt die Secure Enclave zu keinem Zeitpunkt.** Der Client erhält nur die Schlüsselreferenz (`keyId`) zurück.
- *(04) Attestation Key erzeugen:* Der Client ruft `DCAppAttestService.shared.generateKey()` auf. Die App Attest API erzeugt ein AK-Schlüsselpaar in der Secure Enclave und gibt eine `keyId_AK` zurück.
- *Fallback (05):* Ist die Secure Enclave nicht verfügbar (ältere Geräte ohne Secure Enclave), werden beide Schlüssel im regulären Software-Speicher erzeugt (Software-Fallback).

![Abbildung 11: Schlüsselgenerierung auf macOS/iOS (Secure Enclave)](../../../images/zeta-flows/Abb-ZETA-Schlüsselgenerierung-macOS.svg)

##### 4.3.2.2 Client-Start und Posture-Erhebung

- *(01) App-Start:* Der ZETA Client startet im App-Prozess unter dem iOS/iPadOS-Sandbox-Modell.
- *(02) Posture-Erhebung:* Der Client liest über native iOS-APIs die sicherheitsrelevanten Systemzustände aus:
  - Betriebssystemversion und Build-Nummer
  - Gerätemodell und Hersteller
  - Jailbreak-Status (Indikator: Schreibzugriff auf `/private` oder Vorhandensein von Cydia)
  - Secure Boot Status (über `MobileGestalt` APIs)
  - App-Signierungsstatus (Distribution vs. Enterprise vs. Ad-hoc)
- *(03) Initialisierung:* Interne Sitzungsstrukturen (Token-Speicher, DPoP-Key-Kontext) werden initialisiert.

##### 4.3.2.3 Vorbereitung der Client-Registrierung (Apple App Attest)

- **Verwendeter Endpunkt-Pfad (iOS/Apple):** `GET /nonce`
- *(01)–(02) Nonce abrufen:* Der Client fordert eine frische Nonce beim PDP AuthS an (`GET /nonce`).
- *(03)–(04) Posture-Daten erheben:* Der Client liest die aktuellen Sicherheitszustände aus (OS-Version, Gerätemodell, Secure Boot, Jailbreak-Indikatoren).
- *(05) clientDataHash berechnen:* `clientDataHash = SHA256(Nonce ‖ Posture-Daten)`. Dieser Hash bindet den Attestierungsnachweis fest an diese Transaktion und verhindert Replay-Angriffe.
- *(06) App Attest API aufrufen:* Der Client ruft `DCAppAttestService.shared.attestKey(keyId_AK, clientDataHash)` auf.
- *(07)–(08) Secure Enclave signiert:* Die Secure Enclave signiert den Hash mit `PrK.AK.Sig` und generiert einen monoton steigenden Replay-Counter (Authenticator Counter).
- *(09)–(10) Apple Attestation Object erstellen:* Das OS bündelt Signatur, X.509-Zertifikatskette (vom AK bis zur Apple App Attest Root CA) und Authenticator-Daten (inkl. Counter und `rpIdHash`) in ein standardisiertes, **CBOR-kodiertes Apple Attestation Object** und gibt es dem Client zurück.

![Abbildung 12: Vorbereitung per Secure Enclave Attestation Key (iOS)](../../../images/zeta-flows/Abb-ZETA-SE-Attestation-Key.svg)

##### 4.3.2.4 Dynamic Client Registration und TOFU-Nutzerbindung

- **Verwendete Endpunkt-Pfade (iOS/Apple):** `POST /register` und `POST /register/verify`
- *(01) POST /register:* Der ZETA Client sendet die Registrierungsanfrage gemäß Schema [dcr-request.yaml](../../../src/schemas/dcr-request.yaml) an den PDP AuthS. Der Body enthält:
  - `attestation_type: "apple"`
  - `puk_client_sig` (JWK)
  - `puk_ak_sig` (JWK)
  - `apple_attestation_object` (Base64-CBOR)
  - `signed_hash_puk_client_sig`
- *(02) AuthS validiert Attestation Object:* Der AuthS prüft die X.509-Zertifikatskette gegen die **Apple App Attest Root CA**, verifiziert den Replay-Counter und stellt sicher, dass `PuK.AK.Sig` identisch mit dem Schlüssel in `x5c[0]` ist.
- *(03) Hash-Rekonstruktion:* Der AuthS rekonstruiert `clientDataHash` aus übermittelter Nonce und Posture-Klartextdaten und prüft die Übereinstimmung mit dem signierten Hash.
- *(04) Besitznachweis prüfen:* Der AuthS verifiziert `signed_hash_puk_client_sig` mit `PuK.AK.Sig`, um zu bestätigen, dass `PuK.Client.Sig` und der AK auf demselben Gerät in der Secure Enclave liegen.
- *(05)–(08) TOFU E-Mail-Bindung:* Analog zu Android: Der AuthS sendet einen OTP-Code an die E-Mail des Nutzers; der Client übermittelt den Code via `POST /register/verify`.
- *(09) Abschluss:* Der AuthS bestätigt die Registrierung mit `201 Created {client_id}` mit Status `pending_attestation`.

![Abbildung 13: DCR für mobile Clients (Apple iOS)](../../../images/zeta-flows/Abb-ZETA-DCR-für-mobile-Clients.svg)

## 5. Attestation und Device Posture Evaluation

### 5.1 Zweck

In der Attestierungsphase wird der genaue Sicherheits- und Integritätszustand (Device Posture) des Clients kryptografisch nachgewiesen. Ziel ist es, sicherzustellen, dass nur unveränderte, den Sicherheitsrichtlinien der gematik entsprechende Clients Zugriff auf TI-Ressourcen erhalten.

### 5.2 Ablauf der Posture-Erhebung

Die Posture-Daten werden in Form eines **Client Statements** strukturiert, das dem JSON-Schema [client-statement.yaml](../../../src/schemas/client-statement.yaml) entspricht und in den Client-Assertion-JWT eingebettet wird. Das genaue Posture-Format hängt vom Client-Typ ab:

- **Windows / Linux (TPM):** Der Client fordert über den ZAS eine TPM-Quote (`TPM2_Quote`) an, die die aktuellen Werte der PCRs 7 und 23 enthält und an die Server-Nonce gebunden ist (`attestation_challenge`). Zusammen mit dem TCG Event Log wird dies im Schema [posture-tpm.yaml](../../../src/schemas/posture-tpm.yaml) verpackt.
- **macOS / iOS (Apple):** Der Client liest Sicherheitsparameter aus (wie System Integrity Protection (SIP), Gatekeeper, Secure Boot) und fordert über die native Apple App Attest API eine Assertion über den Hash-Wert `clientDataHash = HASH(Nonce + Posture-Daten)` an. Dies wird im Schema [posture-apple.yaml](../../../src/schemas/posture-apple.yaml) verpackt.
- **Android:** Der Client stellt die Posture-Daten bestehend aus OS-Version, Boot-Status und dem Play Integrity Token zusammen. Verpackt im Schema [posture-android.yaml](../../../src/schemas/posture-android.yaml).
- **Software-Fallback:** Für Systeme ohne Hardware-Sicherheitsmodule werden OS- und Anwendungsdaten gesammelt und als softwarebasiertes Statement im Schema [posture-software.yaml](../../../src/schemas/posture-software.yaml) ohne Signatur übermittelt.

Die Erhebung von Attestierungsnachweisen für stationäre Clients ist in den folgenden Diagrammen dargestellt:

![Abbildung 10: Client Statement mit TPM Attestation](../../../images/zeta-flows/Abb-ZETA-Client-Statement-mit-TPM-Attestation.svg)

![Abbildung 11: Client Statement mit Apple AppAttest](../../../images/zeta-flows/Abb-ZETA-Client-Statement-mit-Apple-AppAttest.svg)

## 6. Authentifizierung und Autorisierung

Um auf einen Fachdienst zuzugreifen, benötigt der ZETA Client ein kurzlebiges, an einen DPoP-Schlüssel gebundenes Access Token vom PDP Authorization Server.

### 6.1 Stationäre Clients

#### 6.1.1 Pfad A: Token-Austausch mit Attestierung

Dieser Pfad wird beim ersten Session-Aufbau oder zur Re-Attestierung durchlaufen.

- **Verwendete Endpunkt-Pfade:** `GET /nonce`, `POST /token` und Policy-Engine `POST /v1/data/authz`

1. **Nonce abrufen:** Der Client fordert eine frische, einmalig gültige Nonce vom AuthS an (`GET /nonce`).
2. **DPoP-Schlüssel erzeugen:** Der Client generiert ein temporäres, sitzungsbasiertes DPoP-Schlüsselpaar (`PrK.DPoP.Sig` / `PuK.DPoP.Sig`).
3. **Integritätsnachweis erheben:** Der Client berechnet die `attestation_challenge` und fordert beim ZAS die TPM Quote bzw. das Apple Attestation Object an.
4. **Subject Token erstellen:** Der Client erzeugt ein vom Konnektor bzw. der SMC-B signiertes `subject_token` zur Authentifizierung der Institution. Das Subject Token bindet kryptografisch die Hashes des Client Instance Keys und des DPoP-Schlüssels (Claims `client_key` und `dpop_key`).
5. **Client Assertion erstellen:** Der Client erstellt das Client Assertion JWT, signiert es mit dem `PrK.Client.Sig` und bettet das `client_statement` ein.
6. **Token Request:** Der Client sendet eine POST-Anfrage an `/token` mit `grant_type=token-exchange`, dem SMC-B Subject Token, der Client Assertion und dem DPoP-Proof (im DPoP Header).
7. **Verifikation & Policy Engine:** Der AuthS validiert die Signatur der Client Assertion, das Subject Token und die DPoP-Bindung. Anschließend wertet er die Attestierungsdaten und PCR-Werte aus, indem er eine POST-Anfrage an die Policy Engine (`POST /v1/data/authz`) sendet.
8. **Token-Ausstellung:** Wenn die Policy Engine den Zugriff erlaubt, stellt der AuthS das Access Token (DPoP-gebunden), ein Refresh Token und ein **ZETA Guard Attestation Token (zg_att_token)** aus.

Der vollständige Token Exchange mit Attestierung ist in der folgenden Abbildung dargestellt:

![Abbildung 12: Token Exchange mit Attestation](../../../images/zeta-flows/Abb-ZETA-Token-Exchange-mit-Attestation.svg)

#### 6.1.2 Pfad B: Token-Erneuerung via Refresh Token

Dieser performante Pfad wird genutzt, solange ein gültiges Refresh Token vorliegt. Auf eine erneute Hardware-Attestierung wird hierbei verzichtet. Der Client sendet eine einfache Client Assertion (ohne embedded Attestierung) zusammen mit dem Refresh Token an den `/token`-Endpunkt. Der AuthS validiert die Signaturen und führt eine Refresh Token Rotation durch.

- **Verwendeter Endpunkt-Pfad:** `POST /token`

![Abbildung 13: Token Exchange mit Refresh Token](../../../images/zeta-flows/Abb-ZETA-Token-Exchange-mit-Refresh-Token.svg)

### 6.2 Mobile Clients

Bei mobilen Clients erfolgt der Token-Abruf über den OIDC Authorization Code Flow mit PKCE:

- **Verwendeter Endpunkt-Pfad:** `POST /token` (Authorization Code Flow)

1. Der Nutzer authentifiziert sich interaktiv gegenüber dem Identity Provider (IDP).
2. Der Client tauscht den Authorization Code am `/token`-Endpunkt gegen die Session-Token aus, indem er seine Client Assertion und seine DPoP-gebundenen Attestierungsnachweise mitsendet.
3. Bei erfolgreicher Validierung stellt der AuthS die Token (Access Token, Refresh Token, optionales Attestation Token) aus.

### 6.3 Zugriff auf den Resource Server

Nach erfolgreichem Token-Bezug greift der Client auf den Resource Server (RS) zu. Die Absicherung erfolgt über den PEP HTTP Proxy:

- **Verwendete Endpunkt-Pfade:** `GET /api/resource` (bzw. `POST /ASL` bei ZETA/ASL-Verschlüsselung)

- **Zugriff mit ZETA/ASL:** Erfordert die Protected Resource eine zusätzliche Verschlüsselungsebene (ZETA/ASL), wird ein verschlüsselter Tunnel aufgebaut. Der Tunnel kann entweder am PEP (HTTP Proxy) oder direkt am Resource Server (Ende-zu-Ende) terminieren. Der Client verpackt den Fach-Request in einen verschlüsselten `POST /ASL` Request.
- **Zugriff ohne ZETA/ASL:** Der Client sendet den Request direkt an den PEP mit dem Access Token im `Authorization`-Header (DPoP-gebunden) und dem DPoP-Proof im `DPoP`-Header.

Der PEP prüft die Token und Header und leitet bei Erfolg den Request an den Resource Server weiter, wobei er die verifizierten Identitätsdaten in Form von Custom Headern (`zeta-user-info`, `zeta-client-data`) anhängt.

Die beiden Zugriffsszenarien sind in den folgenden Abbildungen dargestellt:

![Abbildung 14: Zugriff auf RS mit ASL](../../../images/zeta-flows/Abb-ZETA-Zugriff-auf-RS-mit-ASL.svg)

![Abbildung 15: Zugriff auf RS ohne ASL](../../../images/zeta-flows/Abb-ZETA-Zugriff-auf-RS-ohne-ASL.svg)

### 6.4 Dienst-zu-Dienst Kommunikation

Für die maschinelle Kommunikation zwischen Backend-Diensten wird die **Workload Identity Federation** eingesetzt.

- **Verwendeter Endpunkt-Pfad:** `POST /token` Der PDP des anfragenden Dienstes fungiert als Identity Provider (IDP) und stellt ein Workload-Token (Subject Token) aus, das beim PDP des Zieldienstes per Token-Exchange gegen ein Access Token für den dortigen PEP ausgetauscht wird.

![Abbildung 16: Dienst-zu-Dienst Kommunikation](../../../images/zeta-flows/Abb-ZETA-Dienst-zu-Dienst-Kommunikation.svg)

## 7. Endpunkte

### 7.1 ZETA Guard API Endpunkte

Die ZETA Guard API Endpunkte sind über HTTPS erreichbar und erfordern TLS 1.3 oder höher gemäß den Vorgaben aus [gemSpec_Krypt].

#### 7.1.1 OAuth Protected Resource Well-Known Endpoint

Bietet eine standardisierte Methode, um Konfigurationsdetails einer Protected Resource abzurufen (gemäß RFC 9728).

- **Pfad:** `GET /.well-known/oauth-protected-resource`
- **Request-Schema:** *Keines (kein Request-Body)*

##### 7.1.1.1 Anfrage-Beispiel

```http
GET /.well-known/oauth-protected-resource HTTP/1.1
Host: api.example.com
Accept: application/json
```

##### 7.1.1.2 Antwort-Beispiele

**200 OK (Erfolgreich):**

- **Response-Schema:** [opr-well-known.yaml](../../../src/schemas/opr-well-known.yaml)

```http
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: public, max-age=86400
ETag: "w/37b12-abc12345"

{
  "resource": "https://api.example.com",
  "authorization_servers": [
    "https://auth.example.com"
  ],
  "scopes_supported": [
    "vsdservice.read",
    "vsdservice.write"
  ],
  "bearer_methods_supported": [
    "header"
  ],
  "dpop_signing_alg_values_supported": [
    "ES256"
  ],
  "dpop_bound_access_tokens_required": true,
  "zeta_asl_use": "required",
  "api_versions_supported": [
    {
      "major_version": 1,
      "version": "1.3.0",
      "status": "stable",
      "documentation_uri": "https://gematik.de/docs/api/v1.3"
    }
  ]
}
```

**404 Not Found (Fehler):**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)

```http
HTTP/1.1 404 Not Found
Content-Type: application/json

{
  "error": "resource_not_found",
  "error_description": "The requested OAuth Protected Resource configuration could not be found at this path.",
  "error_uri": "https://gematik.de/errors/resource_not_found"
}
```

**500 Internal Server Error (Fehler):**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)

```http
HTTP/1.1 500 Internal Server Error
Content-Type: application/json

{
  "error": "server_error",
  "error_description": "An unexpected error occurred while processing your request.",
  "error_uri": "https://gematik.de/errors/server_error"
}
```

---

#### 7.1.2 Authorization Server Well-Known Endpoint

Bietet Metadaten über den PDP Authorization Server (gemäß RFC 8414).

- **Pfad:** `GET /.well-known/oauth-authorization-server`
- **Request-Schema:** *Keines (kein Request-Body)*

##### 7.1.2.1 Anfrage-Beispiel

```http
GET /.well-known/oauth-authorization-server HTTP/1.1
Host: auth.example.com
Accept: application/json
```

##### 7.1.2.2 Antwort-Beispiele

**200 OK (Erfolgreich):**

- **Response-Schema:** [as-well-known.yaml](../../../src/schemas/as-well-known.yaml)

```http
HTTP/1.1 200 OK
Content-Type: application/json
Cache-Control: public, max-age=86400
ETag: "w/98d41-xyz98765"

{
  "issuer": "https://auth.example.com",
  "authorization_endpoint": "https://auth.example.com/auth",
  "token_endpoint": "https://auth.example.com/token",
  "registration_endpoint": "https://auth.example.com/register",
  "jwks_uri": "https://auth.example.com/certs",
  "grant_types_supported": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token",
    "authorization_code"
  ],
  "token_endpoint_auth_methods_supported": [
    "private_key_jwt"
  ],
  "token_endpoint_auth_signing_alg_values_supported": [
    "ES256"
  ],
  "code_challenge_methods_supported": [
    "S256"
  ],
  "api_versions_supported": [
    {
      "major_version": 1,
      "version": "1.3.0",
      "status": "stable",
      "documentation_uri": "https://gematik.de/docs/api/v1.3"
    }
  ]
}
```

**404/500 Errors:**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)
Folgen dem Schema [zeta-error.yaml](../../../src/schemas/zeta-error.yaml) (analog zu Kapitel 7.1.1.2).

---

#### 7.1.3 Nonce Endpoint

Liefert einen frischen 128-Bit-Einmalwert (Nonce) zur Bindung von Attestierungen und zur Absicherung gegen Replay-Angriffe.

- **Pfad:** `GET /nonce`
- **Request-Schema:** *Keines (kein Request-Body)*
- **Authentifizierung:** Keine erforderlich.

##### 7.1.3.1 Anfrage-Beispiel

```http
GET /nonce HTTP/1.1
Host: auth.example.com
Accept: application/json
```

##### 7.1.3.2 Antwort-Beispiele

**200 OK (Erfolgreich):**

- **Response-Schema:** *Kein spezifisches Schema (einfaches JSON)*

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "nonce": "s.fRzE3M0J_QxL-x.6gA~x",
  "expires_in": 30
}
```

**429 Too Many Requests (Rate-Limit überschritten):**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)
- **Rate-Limit-Header (gemSpec_ZETA A_26668-02):**
  - `x-rate-limit-limit`: Maximal erlaubte Anzahl an Anfragen.
  - `x-rate-limit-remaining`: Verbleibende Anzahl an Anfragen (0 bei 429).
  - `x-rate-limit-reset`: Unix-Zeitstempel (UTC), wann das Limit zurückgesetzt wird.

```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/json
Retry-After: 15
x-rate-limit-limit: 10
x-rate-limit-remaining: 0
x-rate-limit-reset: 1779782415

{
  "error": "rate_limit_exceeded",
  "error_description": "Sie haben die maximale Anzahl von Nonce-Anfragen überschritten. Bitte warten Sie 15 Sekunden.",
  "error_uri": "https://gematik.de/errors/rate_limit_exceeded"
}
```

---

#### 7.1.4 Dynamic Client Registration Endpoint

Ermöglicht die Registrierung neuer Clients beim PDP AuthS. Die Registrierung verknüpft den Client Instance Key mit einem plattformspezifischen Attestierungsnachweis.

- **Pfad:** `POST /register`
- **Request-Schema:** [dcr-request.yaml](../../../src/schemas/dcr-request.yaml)

##### 7.1.4.1 Anfrage-Beispiele

**1. TPM Hardware Attestation (Windows / Linux):**

```http
POST /register HTTP/1.1
Host: auth.example.com
Content-Type: application/json

{
  "attestation_type": "tpm",
  "client_name": "Praxis-PC-123",
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "x": "MKBJD5N2457sT_yP...",
        "y": "89sDJNskd98sJDsd...",
        "use": "sig",
        "kid": "client-instance-key-1"
      }
    ]
  },
  "puk_client_sig": {
    "kty": "EC",
    "crv": "P-256",
    "x": "MKBJD5N2457sT_yP...",
    "y": "89sDJNskd98sJDsd...",
    "use": "sig",
    "kid": "client-instance-key-1"
  },
  "puk_ek_enc": {
    "kty": "RSA",
    "n": "0vx7agoebGcQSuuPiLJ...",
    "e": "AQAB"
  },
  "c_ek_enc": "MIIFvTCCA6WgAwIBAgITG3o...",
  "puk_ak_sig": "AABtAFAAFAAAAAAA...",
  "signed_hash_puk_client_sig": "MEQCIE7sYJ89sJDskd..."
}
```

**2. Apple Hardware Attestation (macOS / iOS):**

```http
POST /register HTTP/1.1
Host: auth.example.com
Content-Type: application/json

{
  "attestation_type": "apple",
  "client_name": "iPhone-Dr-Meier",
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "x": "f83OJ3D2xFsgL...",
        "y": "x_daEAdZu928s...",
        "use": "sig",
        "kid": "apple-instance-key-1"
      }
    ]
  },
  "puk_client_sig": {
    "kty": "EC",
    "crv": "P-256",
    "x": "f83OJ3D2xFsgL...",
    "y": "x_daEAdZu928s...",
    "use": "sig",
    "kid": "apple-instance-key-1"
  },
  "apple_attestation_object": "o2ZmbXRsYXBwbGUtYXBwYXR0ZXN0Z2F0dFN0bX..."
}
```

**3. Android Hardware Attestation:**

```http
POST /register HTTP/1.1
Host: auth.example.com
Content-Type: application/json

{
  "attestation_type": "android",
  "client_name": "Tablet-Praxishelfer",
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "x": "h82Jdsa8s98Jsd...",
        "y": "d7sJSD9s82Jskd...",
        "use": "sig",
        "kid": "android-instance-key-1"
      }
    ]
  },
  "puk_client_sig": {
    "kty": "EC",
    "crv": "P-256",
    "x": "h82Jdsa8s98Jsd...",
    "y": "d7sJSD9s82Jskd...",
    "use": "sig",
    "kid": "android-instance-key-1"
  },
  "android_key_attestation_certificate_chain": [
    "MIIFzDCCA7SgAwIBAgIR...",
    "MIIFvTCCA6WgAwIBAgIT...",
    "MIIFwDCCA6SgAwIBAgIU..."
  ],
  "puk_ak_sig": {
    "kty": "EC",
    "crv": "P-256",
    "x": "k92Jdsia92Nskd...",
    "y": "m2Nskdis92Jskd..."
  },
  "signed_hash_puk_client_sig": "MEQCID7sNsjdi9Nskd...",
  "play_integrity_token": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6..."
}
```

**4. ZETA Attestation Token (Fast-Path):**

```http
POST /register HTTP/1.1
Host: auth.example.com
Content-Type: application/json

{
  "attestation_type": "zeta_attestation_token",
  "client_name": "Praxis-PC-123-Reinstall",
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "x": "MKBJD5N2457sT_yP...",
        "y": "89sDJNskd98sJDsd...",
        "use": "sig",
        "kid": "client-instance-key-1"
      }
    ]
  },
  "puk_client_sig": {
    "kty": "EC",
    "crv": "P-256",
    "x": "MKBJD5N2457sT_yP...",
    "y": "89sDJNskd98sJDsd...",
    "use": "sig",
    "kid": "client-instance-key-1"
  },
  "zeta_attestation_token": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2F1dGguZXhhbXBsZS5jb20iLCJzdWIiOiJjbGllbnQtMSIsInB1a19ha19zaWciOiJBMU...XjY",
  "signed_hash_puk_client_sig": "MEQCIE7sYJ89sJDskd..."
}
```

**5. Software Fallback (Legacy / Software):**

```http
POST /register HTTP/1.1
Host: auth.example.com
Content-Type: application/json

{
  "attestation_type": "software",
  "client_name": "Legacy-App-456",
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "x": "z83JDhsn82Nd...",
        "y": "v98NSjds82Js...",
        "use": "sig",
        "kid": "software-key-1"
      }
    ]
  }
}
```

##### 7.1.4.2 Antwort-Beispiele

**201 Created (Erfolgreich):**

- **Response-Schema:** *Kein spezifisches Schema (einfaches JSON)*

```http
HTTP/1.1 201 Created
Content-Type: application/json

{
  "client_id": "zeta-client-abc12345",
  "client_id_issued_at": 1779782400,
  "client_name": "Praxis-PC-123",
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "x": "MKBJD5N2457sT_yP...",
        "y": "89sDJNskd98sJDsd...",
        "use": "sig",
        "kid": "client-instance-key-1"
      }
    ]
  }
}
```

**409 Conflict (Client Instance Key existiert bereits):**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)

```http
HTTP/1.1 409 Conflict
Content-Type: application/json

{
  "error": "conflict",
  "error_description": "Ein Client mit dem angegebenen Client_Instance_Public_Key existiert bereits.",
  "error_uri": "https://gematik.de/errors/conflict"
}
```

#### 7.1.5 Token Endpoint

Ermöglicht den Bezug von Access- und Session-Tokens per Token Exchange.

- **Pfad:** `/token`
- **Methode:** `POST`
- **Content-Type:** `application/x-www-form-urlencoded`
- **Request-Schemas (Referenzen für JWTs im Parameter-Body):**
  - `client_assertion`: [client-assertion-jwt.yaml](../../../src/schemas/client-assertion-jwt.yaml)
  - `subject_token` (SMC-B): [subject-token-smb.yaml](../../../src/schemas/subject-token-smb.yaml)

##### 7.1.5.1 Token Exchange Request mit TPM Attestierung

Die Formular-kodierten Parameter im Body kombinieren das SMC-B Subject Token, die Client Assertion (mit dem embedded Attestierung-Statement) und den DPoP-Proof.

**Anfrage-Payload (URL-decodiert für bessere Lesbarkeit):**

```http
POST /token HTTP/1.1
Host: auth.example.com
Content-Type: application/x-www-form-urlencoded
DPoP: eyJhbGciOiJFUzI1NiIsInR5cCI6ImRwb3Arand0IiwiandrIjp7Imt0eSI6IkVDIiwiY3J2IjoiUC0yNTYiLCJ4IjoiMEp1...",

grant_type=urn:ietf:params:oauth:grant-type:token-exchange
&client_assertion_type=urn:ietf:params:oauth:client-assertion-type:jwt-bearer
&client_assertion=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImNsaWVudC1pbnN0YW5jZS1rZXktMSJ9.eyJpc3MiOiJ6ZXRhLWNsaWVudC1hYmMxMjM0NSIsInN1YiI6InNldGEtY2xpZW50LWFiYzEyMzQ1IiwiYXVkIjoiaHR0cHM6Ly9hdXRoLmV4YW1wbGUuY29tL3Rva2VuIiwiZXhwIjoxNzc5NzgyNzAwLCJqdGkiOiJqdGktYWJjLTEyMyIsImNsaWVudF9zdGF0ZW1lbnQiOnsic3ViIjoiemV0YS1jbGllbnQtYWJjLWUxMjM0NSIsInBsYXRmb3JtIjoid2luZG93cyIsInBvc3R1cmVfdHlwZSI6InRwbSIsInBvc3R1cmUiOnsicHJvZHVjdF9pZCI6IlByYXhpc1N5c3RlbSIsInByb2R1Y3RfdmVyc2lvbiI6IjEuMy4wIiwib3MiOiJ3aW5kb3dzIiwib3NfdmVyc2lvbiI6IjExIiwiYXJjaCI6Ing2NF9oc20iLCJ0cG1fYXR0ZXN0YXRpb25fa2V5IjoiQUFCdEFGQUFGQSIsImRwb3Bfa2V5X2hhc2giOiJjbmYifSwiYXR0ZXN0YXRpb25fdGltZXN0YW1wIjoxNzc5NzgyNDAwfX0.signature
&resource=https://api.example.com/resource
&subject_token_type=urn:ietf:params:oauth:token-type:jwt
&subject_token=eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6InNtY2Ita2V5LTEifQ.eyJqdGkiOiJqdGktc21jYi05ODciLCJpc3MiOiJ6ZXRhLWNsaWVudC1hYmMxMjM0NSIsInN1YiI6IjEtMi1TTUMtQi1UZXN0a2FydGUtODgzMTEwMDAwMTI5MDY4IiwiYXVkIjoiaHR0cHM6Ly9hdXRoLmV4YW1wbGUuY29tL3Rva2VuIiwiZXhwIjoxNzc5NzgyOTAwLCJjbGllbnRfa2V5Ijp7ImprdCI6Ik1LQkpENSJ9LCJkcG9wX2tleSI6eyJqa3QiOiIwSmNPTCJ9fQ.connector_smcb_signature
&scope=vsdservice.read vsdservice.write
```

##### 7.1.5.2 Token-Strukturen und Claims (Decoded)

**1. Client Assertion JWT (`client-assertion-jwt.yaml`):**

```json
{
  "iss": "zeta-client-abc12345",
  "sub": "zeta-client-abc12345",
  "aud": "https://auth.example.com/token",
  "exp": 1779782700,
  "iat": 1779782400,
  "jti": "jti-abc-123",
  "client_statement": {
    "sub": "zeta-client-abc12345",
    "platform": "windows",
    "posture_type": "tpm",
    "posture": {
      "product_id": "Primärsystem-win-v3",
      "product_version": "3.5.0",
      "os": "Windows 11 Pro",
      "os_version": "10.0.22621",
      "arch": "x86_64",
      "tpm_attestation_key": "base64-encoded-tpm-attestation-key...",
      "tpm_quote": "base64-encoded-tpm-quote...",
      "tpm_event_log": "base64-encoded-tpm-event-log...",
      "tpm_ek_certificate_chain": [
        "base64-encoded-ek-cert-1...",
        "base64-encoded-ek-cert-2..."
      ],
      "platform_product_id": {
        "package_family_name": "Primärsystem_123456789"
      }
    },
    "attestation_timestamp": 1779782400
  }
}
```

**2. SMC-B Subject Token (`subject-token-smb.yaml`):**

```json
{
  "jti": "unique-smcb-token-id-abc123",
  "nonce": "bfb76c3e-8b4a-4f91-9d2a-3c7e5f8a1b20",
  "iss": "zeta-client-abc12345",
  "sub": "1-2-SMC-B-Testkarte-883110000129068",
  "aud": [
    "https://auth.example.com/token"
  ],
  "exp": 1779782900,
  "iat": 1779782400,
  "client_key": {
    "jkt": "NzbLsXh8uDCcd-6MNwXF4W_7noWXFZAfHkxZsRGC9Xs"
  },
  "dpop_key": {
    "jkt": "0ZcOCORZNYy-DWpqq30jZyJGHTN0d2HglBV3uiguA4I"
  }
}
```

**3. Access Token (`access-token.yaml`):**

```json
{
  "iss": "https://auth.example.com",
  "sub": "1-2-SMC-B-Testkarte-883110000129068",
  "aud": [
    "https://api.example.com/resource"
  ],
  "client_id": "zeta-client-abc12345",
  "exp": 1779786000,
  "iat": 1779782400,
  "jti": "access-token-id-999",
  "scope": "vsdservice.read vsdservice.write",
  "cnf": {
    "jkt": "0ZcOCORZNYy-DWpqq30jZyJGHTN0d2HglBV3uiguA4I"
  }
}
```

**4. ZETA Guard Attestation Token (`zeta-attestation-token.yaml`):**

```json
{
  "iss": "https://auth.example.com",
  "sub": "zeta-client-abc12345",
  "exp": 1779868800,
  "iat": 1779782400,
  "jti": "attestation-token-id-888",
  "puk_ak_sig": "base64-encoded-tpm-attestation-key...",
  "hardware_bound": true,
  "platform": "windows",
  "verification_status": "SUCCESS"
}
```

##### 7.1.5.3 Antwort-Beispiele

**200 OK (Erfolgreich mit ZETA Attestation Token bei Hardware-Attestierung):**

- **Response-Schema (Token-Inhalte):**
  - `access_token` entspricht: [access-token.yaml](../../../src/schemas/access-token.yaml)
  - `zg_att_token` entspricht: [zeta-attestation-token.yaml](../../../src/schemas/zeta-attestation-token.yaml)

```http
HTTP/1.1 200 OK
Content-Type: application/json
ZETA-API-Version: 1.3.0

{
  "access_token": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImFzLXNpZ25pbmcta2V5LTEifQ.eyJpc3MiOiJodHRwczovL2F1dGguZXhhbXBsZS5jb20iLCJzdWIiOiIxLTItU01DLUItVGVzdGthcnRlLTg4MzExMDAwMDEyOTA2OCIsImF1ZCI6WyJodHRwczovL2FwaS5leGFtcGxlLmNvbS9yZXNvdXJjZSJdLCJjbGllbnRfaWQiOiJ6ZXRhLWNsaWVudC1hYmMxMjM0NSIsImV4cCI6MTc3OTc4NjAwMCwiaWF0IjoxNzc5NzgyNDAwLCJqdGkiOiJhY2Nlc3MtdG9rZW4taWQtOTk5Iiwic2NvcGUiOiJ2c2RzZXJ2aWNlLnJlYWQgdnNkc2VydmljZS53cml0ZSIsImNuZiI6eyJqa3QiOiIwSmNPTCJ9fQ.signature",
  "token_type": "DPoP",
  "expires_in": 3600,
  "scope": "vsdservice.read vsdservice.write",
  "refresh_token": "rt-9821hdnasd9821hdn",
  "issued_token_type": "urn:ietf:params:oauth:token-type:access_token",
  "zg_att_token": "eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJodHRwczovL2F1dGguZXhhbXBsZS5jb20iLCJzdWIiOiJ6ZXRhLWNsaWVudC1hYmMxMjM0NSIsImV4cCI6MTc3OTg2ODgwMCwiaWF0IjoxNzc5NzgyNDAwLCJqdGkiOiJhdHRlc3RhdGlvbi10b2tlbi1pZC04ODgiLCJwdWtfYWtfc2lnIjoiYmFzZTY0LWVuY29kZWQtdHBtLWF0dGVzdGF0aW9uLWtleS4uLiIsImhhcmR3YXJlX2JvdW5kIjp0cnVlLCJwbGF0Zm9ybSI6IndpbmRvd3MiLCJ2ZXJpZmljYXRpb25fc3RhdHVzIjoiU1VDQ0VTUyJ9.signature"
}
```

**400 Bad Request (z. B. Ungültiger DPoP Proof):**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)

```http
HTTP/1.1 400 Bad Request
Content-Type: application/json

{
  "error": "invalid_request",
  "error_description": "Der DPoP Proof im Header ist ungültig oder abgelaufen (Nonce-Fehler).",
  "error_uri": "https://gematik.de/errors/invalid_request"
}
```

**401 Unauthorized (Client-Authentifizierung fehlgeschlagen):**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)

```http
HTTP/1.1 401 Unauthorized
Content-Type: application/json

{
  "error": "invalid_client",
  "error_description": "Die Signatur der Client Assertion ist ungültig oder der Client Instance Key unbekannt.",
  "error_uri": "https://gematik.de/errors/invalid_client"
}
```

**403 Forbidden (Policy-Entscheidung negativ / Attestierungsfehler):**

- **Response-Schema:** [zeta-error.yaml](../../../src/schemas/zeta-error.yaml)

```http
HTTP/1.1 403 Forbidden
Content-Type: application/json

{
  "error": "access_denied",
  "error_description": "Geräteattestierung fehlgeschlagen: Die PCR-Messwerte weichen von der Sicherheits-Baseline ab.",
  "error_uri": "https://gematik.de/errors/access_denied"
}
```

---

#### 7.1.6 Resource Endpoint

Die geschützte API der Fachanwendung (Resource Server). Der Zugriff wird vom PEP HTTP Proxy kontrolliert.

- **Pfad:** `/api/resource` (beispielhaft)
- **Erforderliche Header:**
  - `Authorization: DPoP <access_token>`
  - `DPoP: <dpop_proof>`

Der PEP HTTP Proxy validiert den Token und den Proof und leitet die Anfrage mit folgenden Custom-Headern weiter:

- `zeta-user-info` (Base64URL-kodiertes JSON mapping zu [zeta-user-info.yaml](../../../src/schemas/zeta-user-info.yaml))
- `zeta-client-data` (Base64URL-kodiertes JSON mapping zu [client-data.yaml](../../../src/schemas/client-data.yaml))
- `zeta-popp-token-content` (Base64URL-kodiertes JSON der Patientendaten, falls vorhanden)

##### 7.1.6.1 Weitergeleitete Custom-Header (Decoded)

**1. `zeta-user-info`:**

```json
{
  "identifier": "1-234567890123",
  "professionOID": "1.2.276.0.76.4.50",
  "commonName": "Arztpraxis Dr. Meier",
  "organizationName": "Gemeinschaftspraxis Meier & Kollegen"
}
```

**2. `zeta-client-data`:**

```json
{
  "client_id": "zeta-client-abc12345",
  "product_id": "Primärsystem-win-v3",
  "product_version": "3.5.0",
  "platform": "windows"
}
```

##### 7.1.6.2 Anfrage-Beispiel (Client an PEP HTTP Proxy)

```http
GET /api/resource HTTP/1.1
Host: api.example.com
Authorization: DPoP eyJhbGciOiJFUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6ImFzLXNpZ25pbmcta2V5LTEifQ...
DPoP: eyJhbGciOiJFUzI1NiIsInR5cCI6ImRwb3Arand0IiwiandrIjp7...
Accept: application/json
```

##### 7.1.6.3 Antwort-Beispiel (Resource Server an Client)

```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "status": "success",
  "data": "Sensible Fachdaten erfolgreich abgerufen."
}
```

### 7.2 Konnektor/TI-Gateway Endpunkte

Die Operationen zur Kartenterminal- und Signaturinteraktion sind in den Schnittstellenspezifikationen der gematik (gemSpec_Kon) definiert:

- **ReadCardCertificate:** Abfrage des SMC-B Institutionszertifikats.
- **ExternalAuthenticate:** Signierung des Subject Token Challenges durch den privaten Schlüssel der SMC-B.

---

### 7.3 ZETA Attestation Service Endpunkte

Der gRPC-Dienst `ZetaAttestationService` läuft unter administrativen Rechten auf dem stationären Client-System und dient der Gewinnung von hardwarebasierten TPM-Nachweisen.

- **Service Name:** `zeta.attestation.service.v1.ZetaAttestationService`
- **Proto Buffer Definition:** [zeta-attestation-service.proto](../../../src/gRPC/zeta-attestation-service.proto)

#### 7.3.1 RPC Methode: GetAttestation

Ermöglicht dem ZETA Client im User-Space den Abruf einer TPM-Quote und des Event Logs.

##### 7.3.1.1 GetAttestationRequest (JSON Repräsentation)

```json
{
  "attestation_challenge": "bWlua2V5LXRwbS1jaGFsbGVuZ2UtOTk5LWFiaW9jZGFzaGg=",
  "pcr_indices": [7, 23]
}
```

##### 7.3.1.2 GetAttestationResponse (JSON Repräsentation)

```json
{
  "attestation_quote": "AABtAFAAFAAAAAAAcGNyX2hhc2hfdmFsdWVfaGV4...",
  "current_pcr_values": {
    "7": "OWYzZDRmMmE2YzVlNGUyMWQ4NGM4YTcxM2QzYzM3Y2ZiMWEyZjNhNGIxNGFkOWQ4ZDhkOWMwZTdjOGU3ZTZmNQ==",
    "23": "YjFhMmYzYTRiMTRhZDlkOGQ4ZDljMGU3YzhlN2U2ZjU5ZjNkNGYyYTZjNWU0ZTIxZDg0YzhhNzEzZDNjMzdjZg=="
  },
  "status": "ATTESTATION_STATUS_SUCCESS",
  "status_message": "Integritätsprüfung erfolgreich. PCRs entsprechen der Baseline.",
  "timestamp": "2026-05-26T07:43:49Z",
  "event_log": "dGNnLWV2ZW50LWxvZy1kYXRhLWJ5dGVzLWhlcmU..."
}
```

> [!NOTE]
> Sollten die PCR-Werte von der erwarteten System-Baseline abweichen, antwortet der Dienst mit `ATTESTATION_STATUS_BASELINE_MISMATCH`. In diesem Fall wird automatisch ein herstellerspezifischer Hintergrundprozess angestoßen, der den technischen Support des Herstellers über den Vorfall informiert.

## 8. Verwaltung von Schlüsseln und Session-Daten im ZETA Client

### 8.1 Einleitung

Ein ZETA Client verwaltet langlebige globale Identitätsschlüssel und kurzlebige Session-Daten.

#### 8.1.1 Globale Daten (Client-übergreifend)

- **Client Instance Key (`PrK.Client.Sig` / `PuK.Client.Sig`):** Hauptidentitätsschlüssel des Clients. Wird persistent und hochsicher gespeichert. Private Teile dürfen die Hardware (TPM / Secure Enclave) niemals verlassen.

#### 8.1.2 Daten pro ZETA Guard Instanz

- **DPoP Key (`PrK.DPoP.Sig` / `PuK.DPoP.Sig`):** Kurzlebiges Session-Schlüsselpaar zur Transaktionssignierung. Wird nach Session-Ablauf verworfen.
- **Access Token / Refresh Token / Client ID / Discovery Cache:** Session-Metadaten. Discovery Cache hat ein empfohlenes Ablauf-Limit von 24 Stunden.

### 8.2 Sicherheitsempfehlungen für die Schlüsselspeicherung

Private Schlüssel dürfen niemals unverschlüsselt im Dateisystem liegen:

- **Windows:** Nutzung der **Data Protection API (DPAPI)** (`CryptProtectData`).
- **macOS:** Nutzung des **macOS Keychain** (Schlüsselbund).
- **Linux:** Nutzung des **Secret Service DBus API** (GNOME Keyring / KWallet). Bei Headless-Systemen wird eine dateibasierte Verschlüsselung mit Master-Passwort und restriktiven Dateiberechtigungen (`chmod 600`) erzwungen.

---

## 9. Versionierung

Die ZETA API folgt strikt **Semantic Versioning 2.0.0 (SemVer)** (`MAJOR.MINOR.PATCH`).

- **MAJOR-Version:** Pfad-Versionierung (`/zeta/v1/...`). Bei rückwärtsinkompatiblen Änderungen.
- **MINOR/PATCH-Version:** Abrufbar im Discovery-Dokument (`api_versions_supported`) und im Header `ZETA-API-Version`.
- **Client-Verhalten:** Clients müssen unbekannte JSON-Felder ignorieren (Toleranzprinzip).
- **Deprecation Policy:** Nach Release einer neuen MAJOR-Version läuft ein parallel betriebener Migrationszeitraum. Veraltete APIs liefern einen `Warning`-Header und nach Abschaltung einen `HTTP 410 Gone`-Fehler.

---

## 10. Performance- und Lastannahmen

Die Antwortzeiten des ZETA Guards und seiner Komponenten müssen unter Last die in Tabelle 21 und 22 definierten Kriterien erfüllen:

**PEP HTTP Proxy Bearbeitungszeiten:**

- Request an Fachdienst ohne ASL (Latenz): Mittelwert: 75ms, 90%-Quantil: 100ms, 99%-Quantil: 1s.
- Request an Fachdienst mit ASL (Latenz): Mittelwert: 75ms, 90%-Quantil: 100ms, 99%-Quantil: 1s.
- ASL-Handshake Nachrichten 1-4 (Antwortzeit): Mittelwert: 75ms, 90%-Quantil: 100ms, 99%-Quantil: 1s.
- Auslieferung Well-known (Antwortzeit): Mittelwert: 7.5ms, 90%-Quantil: 10ms, 99%-Quantil: 100ms.

**PDP Authorization Server Antwortzeiten:**

- `/nonce` Endpoint: Mittelwert: 33ms, 90%-Quantil: 50ms, 99%-Quantil: 500ms.
- `/register` Endpoint: Mittelwert: 75ms, 90%-Quantil: 100ms, 99%-Quantil: 1s.
- `/token` Endpoint: Mittelwert: 75ms, 90%-Quantil: 100ms, 99%-Quantil: 1s.
- Token Refresh: Mittelwert: 75ms, 90%-Quantil: 100ms, 99%-Quantil: 1s.

---

## 11. Verhaltensregeln für den Client

### 11.1 Rate Limits und Einschränkungen

Der Client muss HTTP-Ratenbegrenzungen beachten und bei Erhalt des Statuscodes `429 Too Many Requests` die erneuten Verbindungsversuche nach dem Prinzip des **Exponential Backoff mit Jitter** durchführen.

### 11.2 Zertifikatsvalidierung

Clients MÜSSEN alle Zertifikate bei jedem Verbindungsaufbau gegen die TSL (Trust Service Status List) prüfen. Es gilt:

- Hostnamen-Überprüfung (CN / SAN) gegen erwartete FQDNs.
- Gültigkeitsprüfung (Not Before / Not After).
- **Widerrufsprüfung:** Vorzugsweise über **OCSP Stapling** (Antworten MÜSSEN bis zur Angabe `nextUpdate` im Cache vorgehalten werden). Fehlt OCSP Stapling, muss der Widerrufsstatus aktiv über OCSP-Responder oder CRLs abgefragt werden. Bei Fehlern in der Zertifikatskette MUSS der Verbindungsaufbau abgebrochen werden.

---

## 12 Support und Kontaktinformationen

Für Support-Anfragen, Fehlerberichte und organisatorische Fragen zur Zertifizierung von ZETA-Clients wenden Sie sich bitte an den ZETA-Service-Desk der gematik:

- **E-Mail-Support:** <support.zeta@gematik.de>
- **Developer Forum:** <https://forum.ti-dienste.de/c/zeta-developer>
- **Bugtracker & Feature Requests:** <https://github.com/gematik/zeta/issues>
