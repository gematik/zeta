# ZETA API v1.3.0

## Dokumenten- und Versionsübersicht

| Attribut            | Wert            |
|---------------------|-----------------|
| Dokumenttitel       | ZETA API v1.3.0 |
| Dokumentversion     | 1.3.0           |
| Stand               | 2026-05-26      |
| Status              | Final Draft     |
| Verantwortlich      | gematik         |
| Gültigkeitsbereich  | ZETA Guard API  |
| Spezifikationsgrundlage | gemSpec_ZETA, Version 1.3.0 |

### Zuordnung zu API- und Implementierungsversionen

Dieses Dokument beschreibt die Schnittstellen und Abläufe der **ZETA API Version v1.3.0**.  
Die beschriebenen Inhalte beziehen sich auf die folgenden Implementierungsversionen.

| Komponente           | Artefakt / Image           | Version | Beschreibung                                      |
|----------------------|---------------------------|---------|--------------------------------------------------|
| ZETA Guard (PEP)     | zeta-guard-pep            | 1.3.0   | Policy Enforcement Point (HTTP Proxy)           |
| ZETA Guard (PDP)     | zeta-guard-pdp            | 1.3.0   | Authorization Server / Policy Decision           |
| ZETA Client SDK      | zeta-sdk                  | 1.3.0   | Clientbibliothek zur Integration                 |
| Helm Charts          | zeta-helm-charts          | 1.3.0   | Helm Charts                                      |
| Terraform            | zeta-guard-terraform      | 0.3.0   | Terraform                                      |
| Provisioning Processor | zeta-guard-provisioning-processor  | 1.3.0   | Provisioning Processor               |

---

### Docker-Image Referenzen

Die oben genannten Komponenten werden als Container bereitgestellt.  

europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr (Docker-Image Repository)

**Produkt**
- PEP (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/ngx_pep:1.3.0)
- PDP (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/keycloak-zeta:1.3.0)
- Provisioning Processor (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/provisioning-processor:1.3.0)
- Nginx Ingress (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/nginx-ingress:1.3.0)
- Nginx-Prometheus-Exporter (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/nginx-prometheus-exporter:1.5.1-zeta2)
- Open Policy Agent (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/opa:1.14.1-static)
- Postgres (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/postgres:17.9-standard-trixie)
- Telemetry Gateway (europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/zeta-telemetry-gateway:v0.151.0-release.3)

**Test**
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

Die API begleitet einen ZETA Client über dessen gesamten Lebenszyklus hinweg und unterstützt sowohl einmalige als auch wiederkehrende Interaktionen. Im Gegensatz zu älteren Entwürfen, bei denen plattformspezifische Abläufe noch nicht detailliert ausgearbeitet waren, bietet diese Spezifikation einen vollständig harmonisierten Ablauf für alle Client-Typen.

## 2. Voraussetzungen für die ZETA Client Nutzung

Folgende Voraussetzungen müssen für die Nutzung des ZETA Clients erfüllt sein:
- **FQDN des Resource Servers:** Wird vom ZETA Client benötigt, um die ZETA Guard API zu erreichen.
- **Trust Anchor Informationen (roots.json):** Die [roots.json](https://download.tsl.ti-dienste.de/ECC/ROOT-CA/roots.json) Datei wird vom ZETA Client benötigt, um die Vertrauenskette zu validieren. Diese Datei muss wöchentlich aktualisiert werden.
- **VSDM2 (anwendungsspezifisch):** Für VSDM2 Requests wird ein PoPP (Proof of Patient Presence) Token benötigt. Das PoPP Token muss im Header `PoPP` an den ZETA Client übergeben werden.

## 3. Discovery und Konfiguration

### 3.1 Zweck
In dieser Phase ermittelt der ZETA Client dynamisch die notwendigen Endpunkte und Konfigurationen, um mit der ZETA Guard Infrastruktur (PEP HTTP Proxy und PDP Authorization Server) zu kommunizieren. Dies stellt sicher, dass sich der Client dynamisch an die bereitgestellte Infrastruktur anpassen kann.

### 3.2 Ablauf
Der Service Discovery-Ablauf ist für stationäre und mobile Clients identisch:

1. **Initiale Voraussetzungen**
   Der Client verfügt über den FQDN des Resource Servers und die `roots.json` zur Validierung der Vertrauenskette.
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
Die Client-Registrierung ist der Prozess, mit dem ein ZETA Client erstmalig gegenüber der ZETA-Infrastruktur registriert wird, um eine eindeutige, kryptografisch überprüfbare Identität (Client Instance Key) zu etablieren. Erst nach erfolgreicher Registrierung erhält der Client eine `client_id` mit dem Status `pending_attestation`. Die Aktivierung des Clients erfolgt beim ersten Token Exchange durch eine erfolgreiche Hardware-Attestierung.

### 4.2 Ablauf für stationäre Clients
Der Bootstrapping- und Registrierungsprozess stationärer Clients gliedert sich in folgende Phasen:

#### 4.2.1 Client Installation und Schlüsselgenerierung
1. **ZAS Installation (Root/Admin):** Der ZETA Attestation Service (ZAS) wird mit administrativen Rechten installiert, um Zugriff auf die privilegierten Funktionen des TPM 2.0 zu erhalten.
2. **Client Installation (User Space):** Der ZETA Client wird im Benutzerkontext installiert. Zwischen ZAS und ZETA Client wird eine sichere IPC-Vertrauensbeziehung mit Code-Signatur-Prüfungen aufgebaut.
3. **Client-Schlüssel generieren:** Der Client erzeugt sein langlebiges Signatur-Schlüsselpaar (**Client Instance Key**: `PrK.Client.Sig` / `PuK.Client.Sig`). Auf Windows/Linux-Systemen erfolgt dies über den TPM Provider, auf macOS-Systemen in der Secure Enclave.
4. **Storage Root Key (SRK) und Attestation Key (AK):** Im TPM wird ein SRK als Vertrauensanker und ein hardwaregebundener Attestierungsschlüssel (**Attestation Key**: `PrK.AK.Sig` / `PuK.AK.Sig`) erzeugt. Der öffentliche Teil `PuK.AK.Sig` wird exportiert.
5. **PCR Register erweitern:** Die Messergebnisse der unberührten Client-Komponenten werden durch den ZAS in PCR 23 (oder 22) geschrieben.

Die Installation und Schlüsselgenerierung auf Windows/Linux und macOS ist in den folgenden Abbildungen dargestellt:

![Abbildung 2: Schlüsselgenerierung auf Windows und Linux](../../../images/zeta-flows/Abb-ZETA-Schlüsselgenerierung-Windows-und-Linux.svg)

![Abbildung 3: Schlüsselgenerierung auf macOS](../../../images/zeta-flows/Abb-ZETA-Schlüsselgenerierung-macOS.svg)

#### 4.2.2 Client-Start
Bei jedem Systemboot und Client-Start führt der ZAS eine erneute Integritätsmessung der Client-Komponenten durch und erweitert das PCR 23. Dies dient der Erstellung einer frischen Baseline des Systems.

![Abbildung 4: Client Start mit TPM und ZAS](../../../images/zeta-flows/Abb-ZETA-Client-Start-mit-TPM-und-ZAS.svg)

#### 4.2.3 Vorbereitung der Client-Registrierung
Der Client sammelt alle kryptografischen Nachweise, um zu belegen, dass der Client Instance Key im selben TPM generiert wurde wie der Attestation Key.
- **TPM (Windows/Linux):** Der ZAS führt eine `TPM2_Certify` Operation über `PuK.Client.Sig` mit dem `PrK.AK.Sig` aus. Es entstehen eine Signatur (`tpmt_signature`) und Zertifizierungsdaten (`tpm2b_attest`). Zudem wird das Endorsement Key Zertifikat (`C.EK.Enc`) ausgelesen.
- **Secure Enclave (macOS):** Das Apple OS attestiert den Client-Schlüssel und liefert das Apple Attestation Object.

![Abbildung 5: Vorbereitung per TPM Attestation Key](../../../images/zeta-flows/Abb-ZETA-TPM-Attestation-Key.svg)

![Abbildung 6: Vorbereitung per Secure Enclave Attestation Key](../../../images/zeta-flows/Abb-ZETA-SE-Attestation-Key.svg)

#### 4.2.4 Dynamic Client Registration (DCR)
Der Client sendet eine POST-Registrierungsanfrage an den `/register`-Endpunkt des PDP Authorization Servers. Die Anfrage entspricht dem Schema [dcr-request.yaml](../../../src/schemas/dcr-request.yaml). Der AS verifiziert die Attestierungsdaten und die Zertifikatskette und speichert bei Erfolg die `client_id` im Status `pending_attestation`.

![Abbildung 7: DCR für stationäre Clients](../../../images/zeta-flows/Abb-ZETA-DCR-für-stationäre-Clients.svg)

### 4.3 Ablauf für mobile Clients
Der Lebenszyklus mobiler Clients (Android/iOS) folgt einer ähnlichen logischen Struktur, berücksichtigt jedoch plattformspezifische Besonderheiten und erfordert eine interaktive Nutzerbindung:

#### 4.3.1 Initialisierung und Schlüsselgenerierung
- **Android:** Der Client fordert über den KeyStore die Generierung des Client Instance Keys in der TEE oder StrongBox an. Ein zweiter hardwaregebundener Attestierungsschlüssel (AK) wird mit einer Challenge (Hash des Client Instance Keys) generiert. Hierdurch wird eine unveränderliche Bindung geschaffen. Das Betriebssystem liefert eine X.509-Zertifikatskette (`android_key_attestation_certificate_chain`). Zudem wird optional ein Integritäts-Token über die Google Play Integrity API bezogen.
- **Apple iOS:** Die Generierung des Client-Instance-Schlüssels erfolgt analog zu macOS in der Secure Enclave.

![Abbildung 8: Schlüsselgenerierung auf Android](../../../images/zeta-flows/Abb-ZETA-Schlüsselgenerierung-Android.svg)

#### 4.3.2 DCR und TOFU-Bindung
Im Rahmen der DCR an den PDP Authorization Server (`POST /register`) erfolgt eine zusätzliche **Trust-On-First-Use (TOFU)** Nutzerbindung:
1. Der Client sendet die DCR-Anfrage inklusive der hardwarebasierten Attestierungsnachweise und der E-Mail-Adresse des Nutzers.
2. Der Authorization Server empfängt die Anfrage, validiert die Signaturen und die Vertrauenskette (z.B. gegen die Google Root CA oder die Apple App Attest Root CA).
3. Der AS sendet einen OTP-Bestätigungscode an die angegebene E-Mail-Adresse des Nutzers.
4. Der Nutzer gibt den Code im Client ein. Der Client sendet den Code an den AS, um die Registrierung abzuschließen. Der Client ist nun mit der `client_id` im Status `pending_attestation` registriert.

![Abbildung 9: DCR für mobile Clients](../../../images/zeta-flows/Abb-ZETA-DCR-für-mobile-Clients.svg)

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

1. **Nonce abrufen:** Der Client fordert eine frische, einmalig gültige Nonce vom AS an (`GET /nonce`).
2. **DPoP-Schlüssel erzeugen:** Der Client generiert ein temporäres, sitzungsbasiertes DPoP-Schlüsselpaar (`PrK.DPoP.Sig` / `PuK.DPoP.Sig`).
3. **Integritätsnachweis erheben:** Der Client berechnet die `attestation_challenge` und fordert beim ZAS die TPM Quote bzw. das Apple Attestation Object an.
4. **Subject Token erstellen:** Der Client erzeugt ein vom Konnektor bzw. der SMC-B signiertes `subject_token` zur Authentifizierung der Institution. Das Subject Token bindet kryptografisch die Hashes des Client Instance Keys und des DPoP-Schlüssels (Claims `client_key` und `dpop_key`).
5. **Client Assertion erstellen:** Der Client erstellt das Client Assertion JWT, signiert es mit dem `PrK.Client.Sig` und bettet das `client_statement` ein.
6. **Token Request:** Der Client sendet eine POST-Anfrage an `/token` mit `grant_type=token-exchange`, dem SMC-B Subject Token, der Client Assertion und dem DPoP-Proof (im DPoP Header).
7. **Verifikation & Policy Engine:** Der AS validiert die Signatur der Client Assertion, das Subject Token und die DPoP-Bindung. Anschließend wertet er die Attestierungsdaten und PCR-Werte aus, indem er eine POST-Anfrage an die Policy Engine (`POST /v1/data/authz`) sendet.
8. **Token-Ausstellung:** Wenn die Policy Engine den Zugriff erlaubt, stellt der AS das Access Token (DPoP-gebunden), ein Refresh Token und ein **ZETA Guard Attestation Token (zg_att_token)** aus.

Der vollständige Token Exchange mit Attestierung ist in der folgenden Abbildung dargestellt:

![Abbildung 12: Token Exchange mit Attestation](../../../images/zeta-flows/Abb-ZETA-Token-Exchange-mit-Attestation.svg)

#### 6.1.2 Pfad B: Token-Erneuerung via Refresh Token
Dieser performante Pfad wird genutzt, solange ein gültiges Refresh Token vorliegt. Auf eine erneute Hardware-Attestierung wird hierbei verzichtet. Der Client sendet eine einfache Client Assertion (ohne embedded Attestierung) zusammen mit dem Refresh Token an den `/token`-Endpunkt. Der AS validiert die Signaturen und führt eine Refresh Token Rotation durch.

![Abbildung 13: Token Exchange mit Refresh Token](../../../images/zeta-flows/Abb-ZETA-Token-Exchange-mit-Refresh-Token.svg)

### 6.2 Mobile Clients
Bei mobilen Clients erfolgt der Token-Abruf über den OIDC Authorization Code Flow mit PKCE:
1. Der Nutzer authentifiziert sich interaktiv gegenüber dem Identity Provider (IDP).
2. Der Client tauscht den Authorization Code am `/token`-Endpunkt gegen die Session-Token aus, indem er seine Client Assertion und seine DPoP-gebundenen Attestierungsnachweise mitsendet.
3. Bei erfolgreicher Validierung stellt der AS die Token (Access Token, Refresh Token, optionales Attestation Token) aus.

### 6.3 Zugriff auf den Resource Server
Nach erfolgreichem Token-Bezug greift der Client auf den Resource Server (RS) zu. Die Absicherung erfolgt über den PEP HTTP Proxy:

- **Zugriff mit ZETA/ASL:** Erfordert die Protected Resource eine zusätzliche Verschlüsselungsebene (ZETA/ASL), wird ein verschlüsselter Tunnel aufgebaut. Der Tunnel kann entweder am PEP (HTTP Proxy) oder direkt am Resource Server (Ende-zu-Ende) terminieren. Der Client verpackt den Fach-Request in einen verschlüsselten `POST /ASL` Request.
- **Zugriff ohne ZETA/ASL:** Der Client sendet den Request direkt an den PEP mit dem Access Token im `Authorization`-Header (DPoP-gebunden) und dem DPoP-Proof im `DPoP`-Header.

Der PEP prüft die Token und Header und leitet bei Erfolg den Request an den Resource Server weiter, wobei er die verifizierten Identitätsdaten in Form von Custom Headern (`zeta-user-info`, `zeta-client-data`) anhängt.

Die beiden Zugriffsszenarien sind in den folgenden Abbildungen dargestellt:

![Abbildung 14: Zugriff auf RS mit ASL](../../../images/zeta-flows/Abb-ZETA-Zugriff-auf-RS-mit-ASL.svg)

![Abbildung 15: Zugriff auf RS ohne ASL](../../../images/zeta-flows/Abb-ZETA-Zugriff-auf-RS-ohne-ASL.svg)

### 6.4 Dienst-zu-Dienst Kommunikation
Für die maschinelle Kommunikation zwischen Backend-Diensten wird die **Workload Identity Federation** eingesetzt. Der PDP des anfragenden Dienstes fungiert als Identity Provider (IDP) und stellt ein Workload-Token (Subject Token) aus, das beim PDP des Zieldienstes per Token-Exchange gegen ein Access Token für den dortigen PEP ausgetauscht wird.

![Abbildung 16: Dienst-zu-Dienst Kommunikation](../../../images/zeta-flows/Abb-ZETA-Dienst-zu-Dienst-Kommunikation.svg)

## 7. Endpunkte

### 7.1 ZETA Guard API Endpunkte

Die ZETA Guard API Endpunkte sind über HTTPS erreichbar und erfordern TLS 1.3 oder höher gemäß den Vorgaben aus [gemSpec_Krypt].

#### 7.1.1 OAuth Protected Resource Well-Known Endpoint
Bietet eine standardisierte Methode, um Konfigurationsdetails einer Protected Resource abzurufen (gemäß RFC 9728).
- **Pfad:** `GET /.well-known/oauth-protected-resource`
- **Schema:** [opr-well-known.yaml](../../../src/schemas/opr-well-known.yaml)

##### 7.1.1.1 Anfrage-Beispiel
```http
GET /.well-known/oauth-protected-resource HTTP/1.1
Host: api.example.com
Accept: application/json
```

##### 7.1.1.2 Antwort-Beispiele
**200 OK (Erfolgreich):**
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

**404 Not Found:**
```http
HTTP/1.1 404 Not Found
Content-Type: application/problem+json

{
  "type": "https://httpstatuses.com/404",
  "title": "OAuth Protected Resource Configuration Not Found",
  "status": 404,
  "detail": "The requested OAuth Protected Resource configuration could not be found at this path.",
  "instance": "/.well-known/oauth-protected-resource"
}
```

**500 Internal Server Error:**
```http
HTTP/1.1 500 Internal Server Error
Content-Type: application/problem+json

{
  "type": "https://httpstatuses.com/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred while processing your request.",
  "instance": "/.well-known/oauth-protected-resource"
}
```

---

#### 7.1.2 Authorization Server Well-Known Endpoint
Bietet Metadaten über den PDP Authorization Server (gemäß RFC 8414).
- **Pfad:** `GET /.well-known/oauth-authorization-server`
- **Schema:** [as-well-known.yaml](../../../src/schemas/as-well-known.yaml)

##### 7.1.2.1 Anfrage-Beispiel
```http
GET /.well-known/oauth-authorization-server HTTP/1.1
Host: auth.example.com
Accept: application/json
```

##### 7.1.2.2 Antwort-Beispiele
**200 OK (Erfolgreich):**
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
Folgen dem RFC 9457 Problem Details JSON-Standard (analog zu Kapitel 7.1.1.2).

---

#### 7.1.3 Nonce Endpoint
Liefert einen frischen 128-Bit-Einmalwert (Nonce) zur Bindung von Attestierungen und zur Absicherung gegen Replay-Angriffe.
- **Pfad:** `GET /nonce`
- **Authentifizierung:** Keine erforderlich.

##### 7.1.3.1 Anfrage-Beispiel
```http
GET /nonce HTTP/1.1
Host: auth.example.com
Accept: application/json
```

##### 7.1.3.2 Antwort-Beispiele
**200 OK (Erfolgreich):**
```http
HTTP/1.1 200 OK
Content-Type: application/json

{
  "nonce": "s.fRzE3M0J_QxL-x.6gA~x",
  "expires_in": 30
}
```

**429 Too Many Requests (Rate-Limit überschritten):**
```http
HTTP/1.1 429 Too Many Requests
Content-Type: application/problem+json
Retry-After: 15

{
  "type": "tag:gematik.de,2026:oauth:nonce:rate_limit_exceeded",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "Sie haben die maximale Anzahl von Nonce-Anfragen überschritten. Bitte warten Sie 15 Sekunden.",
  "instance": "/nonce"
}
```

---

#### 7.1.4 Dynamic Client Registration Endpoint
Ermöglicht die Registrierung neuer Clients beim PDP AS. Die Registrierung verknüpft den Client Instance Key mit einem plattformspezifischen Attestierungsnachweis.
- **Pfad:** `POST /register`
- **Schema:** [dcr-request.yaml](../../../src/schemas/dcr-request.yaml)

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
```http
HTTP/1.1 409 Conflict
Content-Type: application/problem+json

{
  "type": "https://httpstatuses.com/409",
  "title": "Conflict",
  "status": 409,
  "detail": "Ein Client mit dem angegebenen Client_Instance_Public_Key existiert bereits.",
  "instance": "/register"
}
```

#### 7.1.5 Token Endpoint
Ermöglicht den Bezug von Access- und Session-Tokens per Token Exchange.
- **Pfad:** `/token`
- **Methode:** `POST`
- **Content-Type:** `application/x-www-form-urlencoded`

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
```http
HTTP/1.1 400 Bad Request
Content-Type: application/problem+json

{
  "type": "https://httpstatuses.com/400",
  "title": "Bad Request",
  "status": 400,
  "detail": "Der DPoP Proof im Header ist ungültig oder abgelaufen (Nonce-Fehler).",
  "instance": "/token"
}
```

**401 Unauthorized (Client-Authentifizierung fehlgeschlagen):**
```http
HTTP/1.1 401 Unauthorized
Content-Type: application/problem+json

{
  "type": "https://httpstatuses.com/401",
  "title": "Unauthorized",
  "status": 401,
  "detail": "Die Signatur der Client Assertion ist ungültig oder der Client Instance Key unbekannt.",
  "instance": "/token"
}
```

**403 Forbidden (Policy-Entscheidung negativ / Attestierungsfehler):**
```http
HTTP/1.1 403 Forbidden
Content-Type: application/problem+json

{
  "type": "https://httpstatuses.com/403",
  "title": "Forbidden",
  "status": 403,
  "detail": "Geräteattestierung fehlgeschlagen: Die PCR-Messwerte weichen von der Sicherheits-Baseline ab.",
  "instance": "/token"
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
- **E-Mail-Support:** support.zeta@gematik.de
- **Developer Forum:** https://forum.ti-dienste.de/c/zeta-developer
- **Bugtracker & Feature Requests:** https://github.com/gematik/zeta/issues
