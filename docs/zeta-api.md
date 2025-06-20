# ZETA API

![gematik logo](/images/gematik-logo-small.svg)

## 1.1. Einführung

Die ZETA API ermöglicht es ZETA Clients, auf geschützte Ressourcen zuzugreifen und dabei Sicherheits- und Authentifizierungsmechanismen zu nutzen.
Der ZETA Client nutzt Endpunkte des ZETA Guard für die Client-Registrierung, Authentifizierung und Autorisierung.

Stationäre Clients verwenden bei der Authentifizierung Endpunkte des Konnektors/TI-Gateways und des ZETA Attestation Service.

Mobile Clients verwenden Endpunkte der betriebssystem-spezifischen Attestierung. Die Authentifizierung erfolgt mit OpenID Connect (OIDC) und der ZETA Guard API.

Die ZETA API ist so konzipiert, dass sie eine sichere und flexible Interaktion zwischen ZETA Clients und geschützten Ressourcen ermöglicht. ZETA basiert auf den Standards des OAuth 2.0 Frameworks und erweitert es um spezifische Anforderungen der gematik.

---

## 1.2. Inhalt

- [ZETA API](#zeta-api)
  - [1.1. Einführung](#11-einführung)
  - [1.2. Inhalt](#12-inhalt)
  - [1.3 Voraussetzungen für die ZETA Client Nutzung](#13-voraussetzungen-für-die-zeta-client-nutzung)
  - [1.4 Ablauf](#14-ablauf)
    - [1.4.1 Konfiguration und Discovery](#141-konfiguration-und-discovery)
    - [1.4.2 Client-Registrierung](#142-client-registrierung)
      - [1.4.2.1 Stationäre Clients](#1421-stationäre-clients)
      - [1.4.2.2 Mobile Clients](#1422-mobile-clients)
    - [1.4.3 Authentifizierung und Autorisierung](#143-authentifizierung-und-autorisierung)
      - [1.4.3.1 Stationäre Clients](#1431-stationäre-clients)
        - [1.4.3.1.1 Pfad A: Token-Austausch mit Attestierung](#14311-pfad-a-token-austausch-mit-attestierung)
        - [1.4.3.1.2 Pfad B: Token-Erneuerung via Refresh Token](#14312-pfad-b-token-erneuerung-via-refresh-token)
        - [1.4.3.1.3 Gemeinsame nachfolgende Schritte](#14313-gemeinsame-nachfolgende-schritte)
      - [1.4.3.2 Mobile Clients](#1432-mobile-clients)
  - [1.5. Endpunkte](#15-endpunkte)
    - [1.5.1 ZETA Guard API Endpunkte](#151-zeta-guard-api-endpunkte)
      - [1.5.1.1 OAuth Protected Resource Well-Known Endpoint](#1511-oauth-protected-resource-well-known-endpoint)
        - [1.5.1.1.1 Anfragen](#15111-anfragen)
        - [1.5.1.1.2 Antworten](#15112-antworten)
      - [1.5.1.2 Authorization Server Well-Known Endpoint](#1512-authorization-server-well-known-endpoint)
        - [1.5.1.2.1 Anfragen](#15121-anfragen)
        - [1.5.1.2.2 Antworten](#15122-antworten)
      - [1.5.1.3 Nonce Endpoint](#1513-nonce-endpoint)
        - [1.5.1.3.1 Anfragen](#15131-anfragen)
        - [1.5.1.3.2 Antworten](#15132-antworten)
      - [1.5.1.4 Dynamic Client Registration Endpoint](#1514-dynamic-client-registration-endpoint)
        - [1.5.1.4.1 Anfragen für stationäre Clients](#15141-anfragen-für-stationäre-clients)
        - [1.5.1.4.2 Antworten](#15142-antworten)
        - [1.5.1.4.3 Anfragen für mobile Clients](#15143-anfragen-für-mobile-clients)
      - [1.5.1.5 Token Endpoint](#1515-token-endpoint)
        - [1.5.1.5.1 Anfragen](#15151-anfragen)
        - [1.5.1.5.2 Antworten](#15152-antworten)
      - [1.5.1.6 Resource Endpoint](#1516-resource-endpoint)
        - [1.5.1.6.1 Anfragen](#15161-anfragen)
        - [1.5.1.6.2 Antworten](#15162-antworten)
    - [1.5.2 Konnektor/TI-Gateway Endpunkte](#152-konnektorti-gateway-endpunkte)
      - [1.5.2.1 ReadCardCertificate](#1521-readcardcertificate)
      - [1.5.2.1 ExternalAuthenticate](#1521-externalauthenticate)
    - [1.5.3 ZETA Attestation Service Endpunkte](#153-zeta-attestation-service-endpunkte)
      - [1.5.3.1 Dienstdefinition](#1531-dienstdefinition)
      - [1.5.3.2 RPC Methoden](#1532-rpc-methoden)
        - [1.5.3.2.1 GetAttestation](#15321-getattestation)
          - [Request-Nachricht: `GetAttestationRequest`](#request-nachricht-getattestationrequest)
          - [Response-Nachricht: `GetAttestationResponse`](#response-nachricht-getattestationresponse)
          - [Fehlerbehandlung](#fehlerbehandlung)
          - [Sicherheitsaspekte](#sicherheitsaspekte)
  - [1.6. Verwaltung von Schlüsseln und Session-Daten im ZETA Client](#16-verwaltung-von-schlüsseln-und-session-daten-im-zeta-client)
    - [1.6.1 Einleitung](#161-einleitung)
      - [1.6.2 Globale Daten (Client-übergreifend)](#162-globale-daten-client-übergreifend)
      - [1.6.3 Daten pro ZETA Guard Instanz](#163-daten-pro-zeta-guard-instanz)
      - [Konzeptionelles Speicherlayout](#konzeptionelles-speicherlayout)
    - [1.6.4 Sicherheitsempfehlungen für die Schlüsselspeicherung](#164-sicherheitsempfehlungen-für-die-schlüsselspeicherung)
  - [1.7. Versionierung](#17-versionierung)
  - [1.8. Performance- und Lastannahmen](#18-performance--und-lastannahmen)
  - [1.9. Rate Limits und Einschränkungen](#19-rate-limits-und-einschränkungen)
  - [1.10. Support und Kontaktinformationen](#110-support-und-kontaktinformationen)
  - [1.11. FAQs und Troubleshooting](#111-faqs-und-troubleshooting)
  - [1.12. Interaktive Dokumentation (optional)](#112-interaktive-dokumentation-optional)
  - [1.13. Changelog](#113-changelog)
  - [1.14. git Branch Modell](#114-git-branch-modell)
  - [1.15. Lizenzbedingungen](#115-lizenzbedingungen)

## 1.3 Voraussetzungen für die ZETA Client Nutzung

Folgende Voraussetzungen müssen für die Nutzung des ZETA Clients erfüllt sein:

- Der **FQDN des Resource Servers** wird vom ZETA Client benötigt, um die ZETA Guard API zu erreichen.
- Die **roots.json Datei** wird vom ZETA Client benötigt, um die Trust Chain zu validieren. Diese Datei muss regelmäßig aktualisiert werden.

Zusätzlich gibt es anwendungsspezifische Voraussetzungen, die für die Nutzung der ZETA Guard API erforderlich sind.

- **VSDM2:** Für VSDM2 Requests wird ein PoPP (Proof of Patient Presence) Token benötigt. Das PoPP Token muss im [Header PoPP](https://gemspec.gematik.de/docs/gemSpec/gemSpec_ZETA/latest/#A_25669) an den ZETA Client übergeben werden.

## 1.4 Ablauf

Abhängig vom Zustand des ZETA Clients müssen verschiedene Teilabläufe ausgeführt werden, oder können übersprungen werden. Die ZETA API besteht aus mehreren Endpunkten, die verschiedene Funktionen bereitstellen. Diese Endpunkte sind in verschiedene Unter-Abläufe aufgeteilt:

- **Konfiguration und Discovery:** Der ZETA Client muss die Konfiguration des ZETA Guards ermitteln, um die richtigen Endpunkte zu erreichen.
- **Client-Registrierung:** Jeder ZETA Client muss sich einmalig beim ZETA Guard registrieren, um eine `client_id` zu erhalten und seinen öffentlichen Schlüssel zu hinterlegen.
- **Authentifizierung und Autorisierung:** Der Client muss sich authentifizieren und die Integrität seiner Plattform nachweisen. Zusätzlich muss sich der Nutzer oder beim Primärsystem die Organisation authentifizieren, um ein Access Token für den Zugriff auf geschützte Ressourcen zu erhalten.

Der Gesamtprozess beginnt damit, dass ein **Nutzer** auf einen Endpunkt eines Resource Servers zugreifen möchte. Dieser Zugriff wird über das Primärsystem vom **ZETA Client** im Auftrag des Nutzers ausgeführt; siehe folgende Abbildung.

![tpm-attestation-and-token-exchange-overview](/images/tpm-attestation-and-token-exchange/tpm-attestation-and-token-exchange-overview.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 1: Ablauf TPM Attestation und Token Exchange Überblick</em></p>

---

### 1.4.1 Konfiguration und Discovery

In dieser Phase ermittelt der ZETA Client die notwendigen Endpunkte und Konfigurationen von den ZETA Guard Komponenten (PEP http Proxy und PDP Authorization Server). Der Client fragt bekannte Endpunkte (`/.well-known/oauth-protected-resource` und `/.well-known/oauth-authorization-server`) ab, um die Konfiguration des Resource Servers und des Authorization Servers zu erhalten. Das folgende Bild zeigt den Ablauf.

![tpm-attestation-and-token-exchange-overview](/images/tpm-attestation-and-token-exchange/discovery-and-configuration.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 2: Ablauf Discovery and Configuration</em></p>

### 1.4.2 Client-Registrierung

#### 1.4.2.1 Stationäre Clients

Jeder ZETA Client muss sich am ZETA Guard registrieren, über den er auf geschützte Ressourcen zugreifen möchte. Dieser Prozess findet **einmalig pro ZETA Guard-Instanz** statt. Der gesamte Prozess ist zweistufig, um die administrative Einrichtung von der technischen Inbetriebnahme zu trennen:

- **Initiale Registrierung:** Der Client erzeugt ein langlebiges kryptographisches Schlüsselpaar (**Client Instance Key**), sendet den öffentlichen Teil an den Authorization Server und erhält im Gegenzug eine `client_id`. Der Client ist danach im System bekannt, aber sein Status ist `pending_attestation`, d.h. er ist noch nicht für den Zugriff auf Ressourcen freigeschaltet.
- **Aktivierung (Erster Token Exchange):** Der Client wird aktiviert, indem er zum ersten Mal einen Token Exchange mit einer erfolgreichen **Attestierung** durchführt. Damit beweist er nicht nur den Besitz des privaten Schlüssels, sondern (bei der TPM-Attestierung) auch die Integrität der Plattform, auf der er läuft. Nach erfolgreicher Prüfung wird sein Status im ZETA Guard auf `active` gesetzt.

Die Client Registrierung ist in der folgenden Abbildung dargestellt.

![Ablauf Client Registrierung](/images/tpm-attestation-and-token-exchange/dynamic-client-registration.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 3: Ablauf Client Registrierung</em></p>

Für die initiale Registrierung sendet der ZETA Client eine Anfrage an den Dynamic Client Registration (DCR) Endpoint. Diese Anfrage enthält alle notwendigen Metadaten, um den Client für die `private_key_jwt` Authentifizierungsmethode vorzubereiten:

- `client_name`: Ein für Menschen lesbarer Name für den Client.
- `token_endpoint_auth_method`: Die geplante Authentifizierungsmethode, hier `private_key_jwt`.
- `grant_types`: Die erlaubten Grant Types (z.B. `urn:ietf:params:oauth:grant-type:token-exchange`, `refresh_token`).
- `jwks`: Ein JSON Web Key Set, das den **öffentlichen Client Instance Key** enthält. Dieser Schlüssel wird vom Authorization Server verwendet, um die Signatur der Client Assertions zu überprüfen.

---

#### 1.4.2.2 Mobile Clients

_Hinweis:_ Der Prozess für Mobile Clients wird in zukünftigen Versionen der API detaillierter beschrieben, sobald die Entwicklung von ZETA Stufe 2 abgeschlossen ist.

### 1.4.3 Authentifizierung und Autorisierung

Nach erfolgreicher Registrierung besitzt der ZETA Client eine `client_id` und ein zugehöriges Schlüsselpaar. Um auf einen Fachdienst zugreifen zu können, benötigt der Client ein Access Token vom Authorization Server (AS). Stationäre ZETA Clients verwenden dafür den Token Exchange Flow, während mobile ZETA Clients den Authorization Code Flow mit OpenID Connect nutzen.

#### 1.4.3.1 Stationäre Clients

Die Authentifizierung und Autorisierung für stationäre Clients unterscheidet zwei Hauptfälle:

1. **Token-Austausch mit Attestierung:** Hier wird die Identität der Institution (mittels `subject_token` von der SM(C)-B) nachgewiesen und die Integrität des Clients durch eine Attestierung überprüft. Dieser aufwändigere Prozess wird zu Beginn einer neuen Session (oder zur Re-Attestierung) durchgeführt, um sicherzustellen, dass der ZETA Client und das Primärsystem vertrauenswürdig sind.
2. **Token-Erneuerung (Refresh Token):** Hier wird ein vorhandenes Refresh Token genutzt, um ein neues Access Token zu erhalten. Dieser Prozess ist performanter und verzichtet auf eine erneute Attestierung.

Diese Trennung schafft eine Balance zwischen höchster Sicherheit beim initialen Zugriff und Effizienz bei der Erneuerung bestehender Sitzungen.

Die folgende Abbildung zeigt den Ablauf des Token-Austauschs mit Client Assertion JWT Authentifizierung und DPoP.

![tpm-attestation-and-token-exchange-overview](/images/tpm-attestation-and-token-exchange/token-exchange-with-client-assertion-jwt-auth.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 4: Ablauf Authentifizierung und TPM-Attestation</em></p>

##### 1.4.3.1.1 Pfad A: Token-Austausch mit Attestierung

Dieser Pfad wird beschritten, wenn der Client keine bestehende Session (d.h. kein gültiges Refresh Token) hat.

1. **Vorbereitung:**
    - Der Client fordert eine frische, einmalig gültige `nonce` vom Authorization Server an (`GET /nonce`).
    - Der Client erzeugt ein temporäres, nur für diese Session gültiges DPoP-Schlüsselpaar.

2. **Integritätsprüfung und kryptografische Bindung:**
    - Um zu beweisen, dass die Attestierung für genau diesen Client und diese Transaktion erstellt wurde, erzeugt der Client eine `attestation_challenge`. Diese bindet den Zustand des TPMs an den **öffentlichen Client Instance Key** und die `nonce` des AS: `attestation_challenge = HASH( HASH(Client_Instance_Public_Key_JWK) + nonce )`.
    - Der Client fordert beim ZETA Attestation Service eine TPM Quote an, die diese `attestation_challenge` als `qualifyingData` enthält. Das TPM signiert somit eine Aussage, die mit der Identität des Clients verbunden ist.

3. **Erstellen des Client Statement:** Die Attestierungsartefakte (TPM Quote, Event Log, Zertifikatskette) werden in eine `client_statement`-Struktur gepackt. Im Falle des Fallbacks (Software-Attestierung) enthält diese Struktur andere, softwarebasierte Evidenz.

4. **Erstellen der Client Assertion (mit Attestierung):** Für die Authentifizierung am Token-Endpoint erstellt der Client eine **Client Assertion**. Dieses JWT, mit dem **privaten Client Instance Key** signiert, dient als "Umschlag":
    - Es authentifiziert den Client gegenüber dem AS (`iss` und `sub` sind die `client_id`).
    - Es enthält die `client_statement`-Struktur als Beweis für die Geräteintegrität, verpackt in einem spezifischen Claim (`urn:gematik:params:oauth:client-attestation:tpm2` oder `...:software`).

    ```json
    // Client Assertion für initialen Token-Austausch (Beispiel TPM)
    {
      "iss": "<client_id>", "sub": "<client_id>",
      "aud": "<AS_Token_Endpoint_URL>",
      "exp": ..., "jti": "...",
      // Kapselung des Attestierungsnachweises
      "urn:gematik:params:oauth:client-attestation:tpm2": {
         "attestation_data": "<Base64(client_statement)>",
         "client_statement_format": "client-statement"
       }
    }
    ```

5. **Authentisierung der Institution (SM(C)-B Token):** Parallel dazu erstellt der Client das `subject_token`. Dies ist ein vom ZETA Client erzeugtes JWT, dessen Hash vom Konnektor mittels der SM(C)-B signiert wird und die Identität der Institution (z.B. Praxis) belegt. Die Audience (`aud`) dieses Tokens ist der Ziel-Fachdienst (Resource Server).

6. **Token Request:** Der Client sendet eine `POST`-Anfrage an den `/token`-Endpoint, die alle Teile kombiniert: `grant_type=token-exchange`, das `subject_token`, die `client_assertion` (mit der eingebetteten Attestierung) und den DPoP-Proof.

7. **Validierung durch den AS:** Der AS führt eine umfassende Prüfung durch: Validierung der Client Assertion (Signatur gegen den bei der DCR hinterlegten Public Key), des DPoP-Proofs, des Subject Tokens und insbesondere der **eingebetteten Attestierung** (Prüfung der Quote, der `attestation_challenge` und der PCR-Werte gegen die Sicherheits-Policy).

##### 1.4.3.1.2 Pfad B: Token-Erneuerung via Refresh Token

Dieser effiziente Pfad wird genutzt, wenn ein gültiges Refresh Token vorhanden ist.

1. **Erstellen der Client Assertion (ohne Attestierung):** Der Client erstellt eine einfache `client_assertion`. Sie beweist durch ihre Signatur mit dem Client Instance Key die Identität des Clients. Diese Assertion enthält keine Attestierungsdaten.

    ```json
    // Client Assertion für Refresh-Token-Nutzung
    {
      "iss": "<client_id>",
      "sub": "<client_id>",
      "aud": "<AS_Token_Endpoint_URL>",
      "exp": ..., "jti": "..."
    }
    ```

2. **Token Request:** Der Client sendet eine `POST`-Anfrage an den `/token`-Endpoint mit `grant_type=refresh_token`, dem Refresh Token und der einfachen `client_assertion`.

3. **Validierung durch den AS:** Der AS validiert das Refresh Token, die Signatur der Client Assertion und den DPoP-Proof. Die Prüfung einer TPM-Attestierung entfällt. Bei Erfolg wird das alte Refresh Token invalidiert (Rotation).

---

##### 1.4.3.1.3 Gemeinsame nachfolgende Schritte

Nach erfolgreicher Validierung in einem der beiden Pfade fragt der AS bei der Policy Engine (PE) an, ob der Zugriff gewährt werden soll. Ist die Entscheidung positiv, stellt der AS ein neues Access Token (gebunden an den DPoP-Schlüssel) und ein neues Refresh Token aus.

---

#### 1.4.3.2 Mobile Clients

Die Authentifizierung für mobile Clients erfolgt mit OpenID Connect und OAuth2 Authorization Code Flow.
Die Beschreibung wird ergänzt, wenn die Entwicklung von ZETA Stufe 2 abgeschlossen ist.

## 1.5. Endpunkte

- **TLS:** ZETA Clients müssen TLS 1.3 oder höher unterstützen.
Es müssen die Anforderungen aus [gemSpec_Krypt](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Krypt/latest/#3.3.2) erfüllt werden.

### 1.5.1 ZETA Guard API Endpunkte

#### 1.5.1.1 OAuth Protected Resource Well-Known Endpoint

Dieser Endpunkt bietet eine standardisierte Methode für OAuth Protected Resources (OPR), um ihre Fähigkeiten und Konfigurationsdetails zu veröffentlichen (RFC 9728). Er ermöglicht es Clients, die notwendigen Informationen über die OPR abzurufen, wie z.B. unterstützte Schemata, Verifizierungsmethoden, Token-Introspektion-Endpunkte und unterstützte Scopes. Der Endpunkt ist unter dem Pfad `/.well-known/oauth-protected-resource` relativ zur Basis-URL der Protected Resource erreichbar.

---

##### 1.5.1.1.1 Anfragen

Der Endpunkt wird über eine einfache HTTP GET-Anfrage ohne Body aufgerufen.

```http
GET /.well-known/oauth-protected-resource HTTP/1.1
Host: api.example.com
Accept: application/json
```

---

##### 1.5.1.1.2 Antworten

Wie im obigen Abschnitt dargestellt, ist die typische erfolgreiche API-Antwort ein JSON-Objekt, das der im `opr-well-known.yaml`-Schema definierten Struktur entspricht. Der `Content-Type`-Header der Antwort ist `application/json`.

**Statuscodes:**

- **200 OK:**
  - **Bedeutung:** Die Anfrage war erfolgreich, und die Konfigurationsdaten der Protected Resource wurden als JSON-Objekt im Antwort-Body zurückgegeben.
  Eine erfolgreiche Anfrage liefert ein JSON-Objekt, das die Konfiguration der Protected Resource beschreibt. Die genauen Felder hängen von der Implementierung und den unterstützten Fähigkeiten der geschützten Resource ab.
  - **Beispielantwort:**

Content-Type: application/json

```json
{
  "resource": "https://api.example.com",
  "authorization_servers": [
    "https://auth1.example.com",
    "https://auth2.example.com"
  ],
  "jwks_uri": "https://api.example.com/.well-known/jwks.json",
  "scopes_supported": [
    "read",
    "write",
    "delete"
  ],
  "bearer_methods_supported": [
    "header",
    "body"
  ],
  "resource_signing_alg_values_supported": [
    "RS256",
    "ES256"
  ],
  "resource_name": "Example Protected API",
  "resource_documentation": "https://docs.example.com/api",
  "resource_policy_uri": "https://www.example.com/privacy",
  "resource_tos_uri": "https://www.example.com/terms",
  "tls_client_certificate_bound_access_tokens": true,
  "authorization_details_types_supported": [
    "payment_initiation",
    "account_access"
  ],
  "dpop_signing_alg_values_supported": [
    "ES256",
    "RS512"
  ],
  "dpop_bound_access_tokens_required": true,
  "signed_metadata": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJyZXNvdXJjZSI6Imh0dHBzOi8vYXBpLmV4YW1wbGUuY29tIn0.XYZ123abc456def789",
  "zeta_asl_use": "required"
}
```

- **404 Not Found:**
  - **Bedeutung:** Der angeforderte Well-Known Endpoint konnte auf dem Server nicht gefunden werden. Dies kann daran liegen, dass die Protected Resource diesen Endpunkt nicht hostet oder falsch konfiguriert ist.
  - **Beispielantwort:**

Content-Type: application/problem+json

```json
{
  "type": "https://httpstatuses.com/404",
  "title": "OAuth Protected Resource Configuration Not Found",
  "status": 404,
  "detail": "The requested OAuth Protected Resource Well-Known configuration could not be found at this path.",
  "instance": "/.well-known/oauth-protected-resource"
}
```

- **500 Internal Server Error:**
  - **Bedeutung:** Ein unerwarteter Fehler ist auf dem Server der Protected Resource aufgetreten, der die Verarbeitung der Anfrage verhindert hat.
  - **Beispielantwort:** Ein leerer Body, ein generischer
Content-Type: application/problem+json

```json
{
  "type": "https://httpstatuses.com/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred while processing your request.",
  "instance": "/.well-known/oauth-protected-resource"
}
```

---

#### 1.5.1.2 Authorization Server Well-Known Endpoint

Dieser Endpunkt ermöglicht Clients und anderen Parteien die einfache Entdeckung der Konfigurationsmetadaten eines ZETA Guard OAuth 2.0 Autorisierungsservers (AS) und seiner Fähigkeiten. Er ist gemäß RFC 8414 definiert und bietet eine standardisierte Methode, um Informationen wie Endpunkt-URIs, unterstützte Grant Types und Scopes abzurufen.

---

##### 1.5.1.2.1 Anfragen

Dieser Endpunkt wird über eine HTTP GET-Anfrage ohne Parameter aufgerufen.

**Methode:**
`GET`

**Header:**
Ein `Accept`-Header mit `application/json` wird empfohlen, um die bevorzugte Antwortformat anzugeben.

**Beispiel Anfrage:**

```http
GET /.well-known/oauth-authorization-server HTTP/1.1
Host: api.example.com
Accept: application/json
```

---

##### 1.5.1.2.2 Antworten

**Statuscodes:**

- **200 OK:**
  - **Bedeutung:** Die Anfrage war erfolgreich, und der Server gibt die Konfigurationsmetadaten des Autorisierungsservers als JSON-Objekt zurück.
  - **Content-Type:** `application/json`
  - **Beispiel Antwort:**

```json
{
  "issuer": "https://api.example.com",
  "authorization_endpoint": "https://api.example.com/auth",
  "token_endpoint": "https://api.example.com/token",
  "jwks_uri": "https://api.example.com/certs",
  "response_types_supported": [
    "code",
    "token"
  ],
  "response_modes_supported": [
    "query",
    "fragment",
    "form_post"
  ],
  "grant_types_supported": [
    "authorization_code",
    "token-exchange",
    "refresh_token"
  ],
  "token_endpoint_auth_methods_supported": [
    "private_key_jwt"
  ],
  "token_endpoint_auth_signing_alg_values_supported": [
    "ES256"
  ],
  "service_documentation": "https://api.example.com/docs",
  "code_challenge_methods_supported": [
    "S256"
  ]
}
```

**404 Not Found:**

**Content-Type:**
`application/problem+json`

Dies tritt auf, wenn der Endpunkt unter der angefragten URL nicht gefunden werden kann.

```json
{
  "type": "https://httpstatuses.com/404",
  "title": "Not Found",
  "status": 404,
  "detail": "The requested resource was not found on this server.",
  "instance": "/.well-known/oauth-authorization-server"
}
```

**500 Internal Server Error:**

**Content-Type:**
`application/problem+json`

Dies tritt auf, wenn ein unerwarteter Fehler auf dem Server auftritt, der die Anfrage nicht verarbeiten konnte.

```json
{
  "type": "https://httpstatuses.com/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred while processing your request.",
  "instance": "/.well-known/oauth-authorization-server"
}
```

---

#### 1.5.1.3 Nonce Endpoint

Dieser Endpunkt ermöglicht Clients das Abrufen eines einmaligen kryptographischen Werts, einer "Nonce". Im Kontext der ZETA-Architektur dient diese Nonce primär dazu, eine spezifische **TPM-Attestierung an eine aktuelle Transaktion zu binden**, um Replay-Angriffe zu verhindern. Sie wird Teil der `attestation_challenge`, die vom TPM signiert wird.

Beim Token Endpunkt wird ebenfalls eine Nonce benötigt, um die Integrität der Transaktion zu gewährleisten. Diese Nonce wird in der Client Assertion verwendet, um Replay-Angriffe zu verhindern und die Bindung zwischen der Client Authentifizierung und der Transaktion sicherzustellen.

---

##### 1.5.1.3.1 Anfragen

**Beispiel Anfrage:**

```http
GET /nonce HTTP/1.1
Host: api.example.com
Accept: application/json
```

---

##### 1.5.1.3.2 Antworten

**Statuscodes:**

- **200 OK:**
  - **Bedeutung:** Die Anfrage war erfolgreich, und der Server gibt die Nonce als JSON-Objekt zurück.
  - **Content-Type:** `application/json`
  - **Beispiel Antwort:**

```json
{
  "nonce": "s.fRzE3M0J_QxL-x.6gA~x",
  "expires_in": 30
}
```

**Felder der erfolgreichen Antwort:**

- `nonce` (String): Der generierte, einmalige kryptographische Wert.
- `expires_in` (Integer): Die Gültigkeitsdauer der Nonce in Sekunden, ab dem Zeitpunkt der Ausstellung. Nach Ablauf dieser Zeit sollte die Nonce vom Server nicht mehr akzeptiert werden.

**404 Not Found:**

**Content-Type:**
`application/problem+json`

Dies tritt auf, wenn der Endpunkt unter der angefragten URL nicht gefunden werden kann.

```json
{
  "type": "https://httpstatuses.com/404",
  "title": "Not Found",
  "status": 404,
  "detail": "The requested resource was not found on this server.",
  "instance": "/nonce"
}
```

**429 Too Many Requests:**

Dieser Fehler tritt auf, wenn der Client die vom Server festgelegten Ratenbegrenzungen überschreitet.

**Content-Type:**
`application/problem+json`

**Retry-After:** 60

```json
{
  "type": "tag:authorization.example.com,2023:oauth:nonce:rate_limit_exceeded",
  "title": "Rate Limit Exceeded",
  "status": 429,
  "detail": "You have exceeded the allowed number of nonce requests. Please try again after 60 seconds.",
  "instance": "/nonce"
}
```

- `Retry-After` Header (optional): Gibt an, wie viele Sekunden der Client warten sollte, bevor er eine weitere Anfrage stellt.

**500 Internal Server Error:**

**Content-Type:**
`application/problem+json`

Dies tritt auf, wenn ein unerwarteter Fehler auf dem Server auftritt, der die Anfrage nicht verarbeiten konnte.

```json
{
  "type": "https://httpstatuses.com/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred while processing your request.",
  "instance": "/nonce"
}
```

---

#### 1.5.1.4 Dynamic Client Registration Endpoint

Dieser Endpunkt ermöglicht die dynamische Registrierung neuer OAuth 2.0 Clients beim Authorization Server gemäß RFC 7591. Der Prozess dient dazu, eine `client_id` zu erhalten und den öffentlichen **Client Instance Key** zu registrieren, der für die `private_key_jwt` Client-Authentifizierung verwendet wird.

Die Registrierung selbst erfordert **keine** Attestierung. Der Client erhält den Status `pending_attestation` und muss seine Integrität beim ersten Token Exchange beweisen, um aktiviert zu werden. Die Registrierung muss über eine TLS-geschützte Verbindung erfolgen.

_Hinweis:_ Es fehlen noch die Operationen zur Verwaltung von bestehenden Client Registrierungen (z.B. Aktualisierung, Löschung). Diese werden in zukünftigen Versionen der API ergänzt.

---

##### 1.5.1.4.1 Anfragen für stationäre Clients

Der Client sendet eine `POST`-Anfrage an den `/register`-Endpunkt. Der Anfrage-Body ist ein JSON-Objekt, das die Metadaten des zu registrierenden Clients enthält.

**Beispiel Anfrage:**

```http
POST /register HTTP/1.1
Host: api.example.com
Accept: application/json
Content-type: application/json
```

```json
{
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
        "x": "...",
        "y": "...",
        "use": "sig",
        "kid": "..."
      }
    ]
  },
  "redirect_uris": [
    "https://client.example.org/cb"
  ]
}
```

**Erforderliche Parameter im Anfrage-Body:**

| Parameter                   | Typ      | Beschreibung |
| :-------------------------- | :------- | :----------- |
| `grant_types`               | `array`  | Eine Liste der Grant Types, die der Client verwenden darf. |
| `jwks`                      | `object` | Das JSON Web Key Set [RFC7517] des Clients, das den öffentlichen **Client Instance Key** enthält. |
| `token_endpoint_auth_method`| `string` | Muss `private_key_jwt` sein, um die Client-Authentifizierung mittels signierter JWTs zu erzwingen. |
| `redirect_uris`             | `array`  | Optional für reine Backend-Clients, aber empfohlen. Mindestens eine URI, die für interaktive Flows (z.B. zukünftige mobile Clients) verwendet wird. |
| `client_name`               | `string` | Optional. Ein für Menschen lesbarer Name für den Client. |

---

##### 1.5.1.4.2 Antworten

Der Authorization Server antwortet mit verschiedenen HTTP-Statuscodes und entsprechenden JSON-Objekten, die entweder die erfolgreiche Registrierung oder Fehlermeldungen gemäß RFC 9457 ("Problem Details for HTTP APIs") beschreiben.

**Statuscodes:**

- **201 Created:**
  - **Bedeutung:** Die Registrierung war erfolgreich. Der Server gibt die `client_id` und die registrierten Metadaten zurück.
  - **Content-Type:** `application/json`
  - **Beispiel Antwort:**

    ```json
    {
      "client_id": "1234567890abcdef",
      "client_id_issued_at": 1678886400,
      "grant_types": [
        "urn:ietf:params:oauth:grant-type:token-exchange",
        "refresh_token"
      ],
      "token_endpoint_auth_method": "private_key_jwt",
      "client_name": "Praxis-PC-123",
      "jwks": {
        "keys": [
          {
            "kty": "EC", "crv": "P-256", "x": "...", "y": "...", "use": "sig", "kid": "..."
          }
        ]
      },
       "redirect_uris": [
        "https://client.example.org/cb"
      ]
    }
    ```

- **400 Bad Request:**
  - **Bedeutung:** Die Anfrage war fehlerhaft, z.B. fehlende oder ungültige Parameter.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/400",
  "title": "Bad Request",
  "status": 400,
  "detail": "Invalid request parameters.",
  "instance": "/register"
}
```

- **409 Conflict  :**
  - **Bedeutung:** Ein Client mit dem angegebenen `Client_Instance_Public_Key` existiert bereits.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/409",
  "title": "Conflict",
  "status": 409,
  "detail": "A client with the provided Client_Instance_Public_Key already exists.",
  "instance": "/register"
}
```

- **500 Internal Server Error:**
  - **Bedeutung:** Ein unerwarteter Fehler ist auf dem Server aufgetreten, der die Anfrage nicht verarbeiten konnte.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred while processing your request.",
  "instance": "/register"
}
```

---

##### 1.5.1.4.3 Anfragen für mobile Clients

Die Registrierung für mobile Clients erfolgt ähnlich wie bei stationären Clients, jedoch mit anderen Anforderungen an die Client-Attestation, die auf den jeweiligen Plattformen basieren. Mobile Clients verwenden eine spezifische Attestierungsmethode, die auf den Betriebssystemen basiert (z.B. Android SafetyNet, iOS DeviceCheck).

Die Beschreibung wird in Stufe 2 der ZETA API ergänzt.

#### 1.5.1.5 Token Endpoint

Der Token Endpoint des Autorisierungsservers (AS) ermöglicht den Austausch eines Tokens gegen ein vom Authorizationserver ausgestelltes Access Token, gemäß dem OAuth 2.0 Token Exchange (RFC 8693) oder die Erneuerung von Token (`refresh_token`). Der Client muss sich mit einer JWT Client Assertion gegenüber den Authorization Server authentifizieren.

Der Endpunkt ist ein POST-Endpunkt, der Formular-kodierte Daten (`application/x-www-form-urlencoded`) im Body erwartet und JSON-Objekte im Erfolgsfall oder "Problem Details" im Fehlerfall zurückgibt.

Der Endpunkt unterstützt verschiedene Grant Types, einschließlich `authorization_code` (ab ZETA Stufe 2), `urn:ietf:params:oauth:grant-type:token-exchange`, `refresh_token` und `urn:ietf:params:oauth:grant-type:token-exchange`.

##### 1.5.1.5.1 Anfragen

Der Token Endpoint empfängt POST-Anfragen mit dem Content-Type `application/x-www-form-urlencoded`. Die Anfrage muss die notwendigen Parameter für den Token Exchange Grant Type enthalten, sowie die Client-Authentifizierung mittels JWT Bearer Client Assertion.

**HTTP Methode:** `POST`

**Pfad:** `/token`

**Content-Type:** `application/x-www-form-urlencoded`

**Anfrageparameter:**

| Parameter              | Typ      | Erforderlich | Beschreibung                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| :--------------------- | :------- | :----------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `grant_type`           | `string` | Ja           | Der Grant Type. Für Token Exchange ist dies immer `urn:ietf:params:oauth:grant-type:token-exchange`.|
| `client_assertion_type`| `string` | Ja           | Gibt den Typ der Client Assertion an. Für JWT Bearer Client Assertion ist dies immer `urn:ietf:params:oauth:client-assertion-type:jwt-bearer`.|
| `client_assertion`     | `string` | Ja           | Die JWT, die zur Authentifizierung des Clients dient. Diese JWT muss vom Client signiert sein und folgende Claims enthalten: <br/>- `iss` (Issuer): Die Client ID.<br/>- `sub` (Subject): Die Client ID.<br/>- `aud` (Audience): Die URL des Token Endpoints.<br/>- `exp` (Expiration Time): Die Zeit, nach der die JWT ungültig wird.<br/>- `jti` (JWT ID): Ein eindeutiger Bezeichner für diese JWT, um Replay-Angriffe zu verhindern.<br/>- `iat` (Issued At): Zeitpunkt der Ausstellung der JWT. |
| `resource`        | `string` | Ja           | Eine URI, die den Zieldienst oder die Zielressource angibt, für die der Client das angeforderte Sicherheitstoken verwenden möchte. Dadurch kann der Autorisierungsserver die für das Ziel geeigneten Richtlinien anwenden, z. B. den Typ und Inhalt des auszugebenden Tokens bestimmen oder festlegen, ob und wie das Token verschlüsselt werden soll. |
| `subject_token_type`   | `string` | Ja           | Der Typ des Tokens, das ausgetauscht werden soll. Beispiele könnten sein: `urn:ietf:params:oauth:token-type:access_token`, `urn:ietf:params:oauth:token-type:jwt` oder andere spezifische URIs.|
| `subject_token`        | `string` | Ja           | Das eigentliche Token, das ausgetauscht werden soll. Dies kann ein JWT, ein Referenz-Token oder ein anderes Format sein, abhängig vom `subject_token_type`.|
| `scope`                | `string` | Optional     | Eine durch Leerzeichen getrennte Liste von Scopes, für die der Access Token ausgestellt werden soll. Wenn nicht angegeben, werden die mit dem `subject_token` und/oder Client verbundenen Standard-Scopes verwendet.|

**Beispiel Anfrage:**

```bash
curl -X POST \
  https://as.example.com/token \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  -H 'DPoP: <signed_dpop_jwt>' \
  -d 'grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Atoken-exchange&' \
  -d 'client_assertion_type=urn%3Aietf%3Aparams%3Aoauth%3Aclient-assertion-type%3Ajwt-bearer&' \
  -d 'client_assertion=eyJhbGciOiJFUzI1NiIsImtpZCI6InNvbWVfa2V5X2lkIn0.eyJpc3MiOiJjbGllbnRfaWQwMDEiLCJzdWIiOiJjbGllbnRfaWQwMDEiLCJhdWQiOiJodHRwczovL2F1dGhvcml6YXRpb24uc2VydmVyLmRlL3Rva2VuIiwiZXhwIjoxNjk1NTA0NjAwLCJpYXQiOjE2OTU1MDI4MDAsImp0aSI6ImFiYzEyMzQ1NiJ9.SOME_SIGNATURE_PART_ONE.SOME_SIGNATURE_PART_TWO&' \
  -d 'resource=https%3A%2F%2Fapi.example.com%2F/resource&' \
  -d 'subject_token_type=urn%3Aietf%3Aparams%3Aoauth%3Atoken-type%3Ajwt&' \
  -d 'subject_token=eyJhbGciOiJFUzI1NiIsImtpZCI6InNvbWVfc3ViamVjdF9rZXlfaWQifQ.eyJpc3MiOiJzb21lX3N1YmplY3RfYXV0aG9yaXR5Iiwic3ViIjoiMTIzNDU2Nzg5MCIsImF1ZCI6Imh0dHBzOi8vYXV0aG9yaXphdGlvbi5zZXJ2ZXIuZGUvdG9rZW4iLCJleHAiOjE2OTU1MDI4NjAsImlhdCI6MTY5NTUwMjgwMH0.SM(C)-B_SIGNATURE&' \
  -d 'scope=resource.read%20resource.write'
```

##### 1.5.1.5.2 Antworten

Antworten werden als JSON-Objekte mit dem `Content-Type: application/json` im Erfolgsfall und `application/problem+json` im Fehlerfall zurückgegeben. Fehlerantworten folgen dem "Problem Details for HTTP APIs"-Standard (RFC 9457).

**Statuscodes:**

- **200 OK:**
  - **Bedeutung:** Die Anfrage war erfolgreich, und der Server gibt das Access Token und andere Metadaten zurück.
  - **Content-Type:** `application/json`
  - **Beispiel Antwort:**

```json
{
  "access_token": "eyJhbGciOiJFUzI1NiIsImtpZCI6InRva2VuX2tleV9pZCJ9.eyJpc3MiOiJhdXRoLnNlcnZlci5kZSIsImV4cCI6MTY5NTUwMjgwMCwiYXVkIjpbInJlc291cmNlLnNlcnZlci5kZSJdLCJzdWIiOiIxMjM0NTY3ODkwIiwiY2xpZW50X2lkIjoiZXhhbXBsZV9jbGllbnRfaWQiLCJpYXQiOjE2OTU1MDI4MDAsImp0aSI6ImV4YW1wbGVfamRpX3ZhbHVlIiwic2NvcGUiOiJyZXNvdXJjZS5yZWFkIHJlc291cmNlLndyaXRlIiwiY25mIjp7ImprdCI6ImV4YW1wbGVfamt0X2hhc2gifX0.NEW_SIGNATURE_PLACEHOLDER",
  "token_type": "DPoP",
  "expires_in": 3600,
  "scope": "resource.read resource.write",
  "refresh_token": "some_refresh_token_string",
  "issued_token_type": "urn:ietf:params:oauth:token-type:access_token"
}
```

**Inhalt des Access Tokens:**

```json
{
  "iss": "auth.server.de",
  "exp": 1695502800,
  "aud": ["resource.server.de"],
  "sub": "1234567890",
  "client_id": "my_oauth_client_id",
  "iat": 1695502800,
  "jti": "a_unique_jwt_identifier_12345",
  "scope": "resource.read resource.write",
  "cnf": {
    "jkt": "S7uGv0kQ0g2J_2z8Y_yXm-X_yL0_yXk_Xk_yY1W_Xk"
  }
}
```

- **400 Bad Request:**
  - **Bedeutung:** Die Anfrage war fehlerhaft, z.B. fehlende oder ungültige Parameter.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/400",
  "title": "Bad Request",
  "status": 400,
  "detail": "Invalid request parameters.",
  "instance": "/token"
}
```

- **401 Unauthorized:**
  - **Bedeutung:** Die Client-Authentifizierung ist fehlgeschlagen, z.B. ungültige Client Assertion.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/401",
  "title": "Unauthorized",
  "status": 401,
  "detail": "Client authentication failed.",
  "instance": "/token"
}
```

- **403 Forbidden:**
  - **Bedeutung:** Der Client ist nicht berechtigt, den Token Exchange durchzuführen, z.B. wenn der `subject_token` nicht gültig ist oder der Client nicht die erforderlichen Berechtigungen hat.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/403",
  "title": "Forbidden",
  "status": 403,
  "detail": "The client is not authorized to perform this token exchange.",
  "instance": "/token"
}
```

- **429 Too Many Requests:**
  - **Bedeutung:** Der Client hat die Rate-Limits überschritten.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/429",
  "title": "Too Many Requests",
  "status": 429,
  "detail": "Rate limit exceeded. Please try again later.",
  "instance": "/token"
}
```

- **500 Internal Server Error:**
  - **Bedeutung:** Ein unerwarteter Fehler ist auf dem Server aufgetreten, der die Anfrage nicht verarbeiten konnte.
  - **Content-Type:** `application/problem+json`
  - **Beispiel Antwort:**

```json
{
  "type": "https://httpstatuses.com/500",
  "title": "Internal Server Error",
  "status": 500,
  "detail": "An unexpected error occurred while processing your request.",
  "instance": "/token"
}
```

#### 1.5.1.6 Resource Endpoint

Der Resource Endpoint ist der Endpunkt, der von der geschützten Ressource (Protected Resource) bereitgestellt wird, um auf geschützte Daten zuzugreifen. Er ist durch den ZETA Guard PEP vor unberechtigtem Zugriff geschützt. Für den Zugriff auf die geschützte Ressource wird ein gültiges Access Token benötigt.

##### 1.5.1.6.1 Anfragen

Der ZETA Guard PEP empfängt die Anfragen und prüft das Access Token im Authentication Header sowie das DPoP Proof im DPoP Header.

**HTTP Methode:** wird durch die geschützte Ressource bestimmt (z.B. `GET`, `POST`, `PUT`, `DELETE`).

**Pfad:** wird durch die geschützte Ressource bestimmt (z.B. `/api/resource`).

**Content-Type:** wird durch die geschützte Ressource bestimmt (z.B. `application/json`).

##### 1.5.1.6.2 Antworten

Die Antwort des Resource Endpoints hängt von der geschützten Ressource ab und kann verschiedene Statuscodes und Datenformate zurückgeben.

### 1.5.2 Konnektor/TI-Gateway Endpunkte

Die Endpunkte im Konnektor oder im Highspeed Konnektoren des TI-Gateways werden für die Erstellung von Signaturen mit Der SM(C)-B sowie für die Abfrage des SM(C)-B Zertifikats während der Authentifizierung am ZETA Guard verwendet.

_Hinweis: Perspektivisch ist vorgesehen, dass der Zugriff auf das TI-Gateway über den ZETA Guard erfolgt, um die Sicherheit und Integrität der Kommunikation zu gewährleisten. Während der Authentifizierung wird anstatt der SM(C)-B Identität eine TI-Gateway Identität verwendet._

#### 1.5.2.1 ReadCardCertificate

Die Operation [ReadCardCertificate](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/#TIP1-A_4698-03) ist in der [Konnektor Spezifikation](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/index.html) definiert.

#### 1.5.2.1 ExternalAuthenticate

Die Operation [ExternalAuthenticate](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/#TIP1-A_4698-03) ist in der [Konnektor Spezifikation](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/index.html) definiert.

### 1.5.3 ZETA Attestation Service Endpunkte

Der `ZetaAttestationService` stellt einen gRPC-Dienst zur Verfügung, der es stationären Clients (Primärsystem) ermöglicht, signierte Attestierungsinformationen für den Client abzurufen. Diese Informationen basieren auf Integritätsmessungen, die in ausgewählten Platform Configuration Registers (PCRs) des Trusted Platform Module (TPM) gespeichert sind. Der ZETA Guard Authorization Server verwendet diese Attestierungsdaten, um die Integrität und Authentizität der Softwareumgebung des Clients zu verifizieren, bevor Zugriff auf geschützte Ressourcen gewährt wird.

Der ZETA Attestation Service wird vom Hersteller des stationären Clients bereitgestellt und es muss eine Vertrauensbeziehung zwischen stationären Client und ZETA Attestation Service bestehen, um zu gewährleisten, dass die Attestation über die vorgesehenen Software-Komponenten erfolgt.

_Hinweis:_ Während der Installation oder bei Updates des stationären Clients muss auch ein Update des ZETA Attestation Service erfolgen um eine neue Baseline für die Integrität des stationären Clients zu setzen. Die Baseline besteht aus einem Hash über alle unveränderlichen Komponenten des stationären Clients, inkl. ZETA Attestation Service.

_Hinweis:_ Der ZETA Attestation Service muss bei jedem Start des Clients die Messung über die Integrität des Clients durchführen und in das PCR schreiben.

_Hinweis:_ Der ZETA Attestation Service ist nicht für mobile Clients vorgesehen. Mobile Clients verwenden eine andere Attestierungsmethode, die auf den jeweiligen Plattformen basiert (z.B. Android SafetyNet, iOS DeviceCheck).

_Hinweis:_ TODO Umgang mit Messung des Clients weicht von Baseline ab; empfohlenes Verhalten für Client und ZetaAttestationService (z. B. automatisch Support informieren)

#### 1.5.3.1 Dienstdefinition

- **Service Name:** `zeta.attestation.service.v1.ZetaAttestationService`
- **Proto Buffer Spezifikation:** [zeta-attestation-service.proto](/src/gRPC/zeta-attestation-service.proto)

#### 1.5.3.2 RPC Methoden

##### 1.5.3.2.1 GetAttestation

Diese RPC-Methode ermöglicht es Clients, eine signierte Attestierungs-Quote vom TPM des Systems anzufordern, die spezifische PCR-Werte und eine vom Client bereitgestellte Challenge enthält.

###### Request-Nachricht: `GetAttestationRequest`

Die `GetAttestationRequest`-Nachricht enthält die Parameter, die für die Anforderung einer Attestierung benötigt werden.

| Feld                    | Typ             | Erforderlich | Beschreibung                                                                                                                                                                                                                            |
| :---------------------- | :-------------- | :----------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `attestation_challenge` | `bytes`         | Ja           | Ein SHA-256 Hashwert, berechnet aus der Verkettung des SHA-256 Fingerabdrucks des Public Client Instance Keys und einer Nonce vom ZETA Guard Authorization Server. Dient zur Verhinderung von Replay-Angriffen und zur Korrelation. |
| `pcr_indices`           | `repeated uint32` | Ja           | Eine Liste von TPM PCR-Indizes, deren aktuelle Werte in die Attestierungs-Quote aufgenommen und zurückgegeben werden sollen.|

---

**Berechnung der `attestation_challenge`**:
Der Client ist für die korrekte Berechnung dieses Wertes verantwortlich.

```ini
data_to_hash = sha256_thumbprint_of_public_client_instance_key_bytes || nonce_from_zeta_guard_bytes
attestation_challenge = SHA-256(data_to_hash)
```

**Beispiel (Python) für die Berechnung der `attestation_challenge`:**

```python
import hashlib

# Beispielwerte
thumbprint_hex = "9f3d4f2a6c5e4e21d84c8a713d3c37cfb1a2f3a4b14ad9d8d8d9c0e7c8e7e6f5" # SHA-256 Fingerabdruck
nonce_hex = "a1b2c3d4e5f60718293a4b5c6d7e8f90"

thumbprint_bytes = bytes.fromhex(thumbprint_hex)
nonce_bytes = bytes.fromhex(nonce_hex)

data_to_hash = thumbprint_bytes + nonce_bytes
attestation_challenge_bytes = hashlib.sha256(data_to_hash).digest() # als Bytes
attestation_challenge_hex = hashlib.sha256(data_to_hash).hexdigest() # als Hex-String

print(f"attestation_challenge (hex): {attestation_challenge_hex}")
# In der gRPC Anfrage wird `attestation_challenge_bytes` verwendet.
```

**Empfohlene PCR-Indizes:**

- PCR 4: Boot Loader Code, Digest
- PCR 5: Boot Loader Configuration, Digest
- PCR 7: Secure Boot State / Policy, Digest
- PCR 10:OS Kernel / IMA, Digest
- PCR 11: OS Components / VSM, Digest,
- PCR 22 or 23 (if available) Client Data

###### Response-Nachricht: `GetAttestationResponse`

  Die `GetAttestationResponse`-Nachricht enthält die vom Dienst generierten Attestierungsdaten.

| Feld                   | Typ                                     | Beschreibung                                                                                                                                                                                                  |
| :--------------------- | :-------------------------------------- | :------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `attestation_quote`    | `bytes`                                 | Die rohe, signierte Attestierungs-Quote des TPMs (eine TPM2_ATTEST Struktur). Diese Quote enthält die angefragten PCR-Werte sowie den `attestation_challenge` Wert. Muss clientseitig geparst werden.          |
| `current_pcr_values`   | `map<uint32, bytes>`                    | Eine Abbildung der angefragten PCR-Indizes auf ihre aktuellen, gemessenen Werte. Die Länge der `bytes` hängt vom aktiven Hashing-Algorithmus der jeweiligen PCR-Bank ab (z.B. 20 Bytes für SHA-1, 32 Bytes für SHA-256). |
| `status`               | `AttestationStatus` (enum)              | Der vom ZETA Attestation Service intern ermittelte Status der Attestierung. Gibt an, ob die Messungen erfolgreich waren und ob sie ggf. einer definierten Baseline entsprechen.                               |
| `status_message`       | `string` (optional)                     | Eine menschenlesbare Beschreibung des Attestierungsstatus oder zusätzliche Informationen, insbesondere im Fehlerfall oder bei einem `BASELINE_MISMATCH`.                                                       |
| `timestamp`            | `google.protobuf.Timestamp` (optional)  | Der Zeitstempel der Erstellung der Attestierungs-Quote durch den ZETA Attestation Service. Erfordert `import "google/protobuf/timestamp.proto";`.                                                              |
| `event_log`            | `bytes` (optional)                      | Das TPM-Event-Log im plattformspezifischen Format (z.B. TCG PC Client Platform Firmware Profile Specification). Dieses Log detailliert die Sequenz der Erweiterungen der PCRs und ist essentiell für eine vollständige Validierung. |

**AttestationStatus Enum:**

Definiert die möglichen Statuswerte für die Attestierung, die vom ZETA Attestation Service zurückgegeben werden.

| Wert                               | Numerischer Wert | Beschreibung                                                                                                                                    |
| :--------------------------------- | :--------------- | :---------------------------------------------------------------------------------------------------------------------------------------------- |
| `ATTESTATION_STATUS_UNSPECIFIED`   | 0                | Der Status ist nicht spezifiziert oder konnte nicht ermittelt werden. Dies sollte als Fehler interpretiert werden.                               |
| `ATTESTATION_STATUS_SUCCESS`       | 1                | Die Attestierung war erfolgreich, die Quote wurde generiert und (falls eine Baseline-Prüfung serverseitig erfolgt) die Messungen entsprechen der Baseline. |
| `ATTESTATION_STATUS_BASELINE_MISMATCH` | 2                | Die Attestierung war technisch erfolgreich, aber die aktuellen PCR-Messwerte weichen von der erwarteten Baseline ab.                             |
| `ATTESTATION_STATUS_TPM_ERROR`     | 3                | Ein Fehler ist bei der Kommunikation mit dem TPM oder bei einer TPM-Operation aufgetreten (z.B. TPM nicht bereit, PCR nicht lesbar).|
| `ATTESTATION_STATUS_INVALID_REQUEST` | 4                | Die Anfrageparameter waren ungültig (z.B. `attestation_challenge` fehlt oder hat falsches Format, ungültige oder nicht unterstützte `pcr_indices`). |
| `ATTESTATION_STATUS_INTERNAL_ERROR`| 5                | Ein interner, nicht näher spezifizierter Fehler ist auf Serverseite aufgetreten.|

---

###### Fehlerbehandlung

  Der `ZetaAttestationService` verwendet standardmäßige gRPC-Statuscodes, um das Ergebnis der Operation auf Transportebene zu kommunizieren. Diese werden ergänzt durch den `status`-Feld in der `GetAttestationResponse` für anwendungsspezifische Logik. Die `google.rpc.Status` kann für detailliertere Fehlerinformationen verwendet werden (siehe `import "google/rpc/status.proto";`).

  Häufige gRPC-Statuscodes:

- **`OK` (0):** Die Anfrage war erfolgreich und die `GetAttestationResponse` enthält die Ergebnisse. Der `status`-Feld in der Response gibt den anwendungsspezifischen Erfolg oder Misserfolg an.
- **`INVALID_ARGUMENT` (3):**
  - Einer oder mehrere Parameter der Anfrage waren ungültig.
  - Beispiele: `attestation_challenge` fehlt, hat eine falsche Länge oder ein ungültiges Format; `pcr_indices` ist leer, enthält ungültige oder nicht unterstützte Indizes.
  - Der `status` in der Response könnte `ATTESTATION_STATUS_INVALID_REQUEST` sein.
- **`UNAUTHENTICATED` (16) / `PERMISSION_DENIED` (7):**
  - Der anfragende Client ist nicht authentifiziert oder nicht   autorisiert, diese Anfrage zu stellen.
  - Relevant, wenn Mechanismen wie mTLS oder Token-basierte   Authentifizierung verwendet werden.
- **`UNAVAILABLE` (14):**
  - Der ZETA Attestation Service kann die Attestierung derzeit nicht   durchführen.
  - Beispiele: TPM ist nicht erreichbar oder nicht funktionsfähig;   eine erforderliche Baseline-Konfiguration ist nicht vorhanden.
  - Der `status` in der Response könnte   `ATTESTATION_STATUS_TPM_ERROR` oder   `ATTESTATION_STATUS_INTERNAL_ERROR` sein.
- **`INTERNAL` (13):**
  - Ein unerwarteter serverseitiger Fehler ist aufgetreten, der   nicht spezifischer kategorisiert werden kann.
  - Der `status` in der Response ist typischerweise   `ATTESTATION_STATUS_INTERNAL_ERROR`.

###### Sicherheitsaspekte

- **Transport-Sicherheit:** Es wird dringend empfohlen, die Kommunikation zwischen Client und `ZetaAttestationService` mittels TLS, vorzugsweise mTLS (mutual TLS), abzusichern, um Authentizität, Integrität und Vertraulichkeit der übertragenen Daten zu gewährleisten.
_Hinweis: Es wird empfohlen, dass der Installer des Clients und des ZetaAttestationService die Schlüssel für die mTLS Verbindung erzeugt und sicher speichert._
- **Challenge-Response:** Die `attestation_challenge` ist ein kritischer Bestandteil zur Verhinderung von Replay-Angriffen. Die `nonce` muss für jede Attestierungsanfrage eindeutig sein und sicher vom ZETA Guard Authorization Server generiert und an den Client übermittelt werden.
- **Event Log Validierung:** Die alleinige Überprüfung der PCR-Werte ist oft nicht ausreichend. Eine gründliche Validierung der Attestierung erfordert das Parsen und Überprüfen des `event_log`, um die Kausalkette der Messungen nachzuvollziehen. Dies erfolgt im ZETA Guard Authorization Server.

---

## 1.6. Verwaltung von Schlüsseln und Session-Daten im ZETA Client

### 1.6.1 Einleitung

Ein ZETA Client muss verschiedene kryptografische Schlüssel und Session-Informationen verwalten, um mit einer oder mehreren ZETA Guard Instanzen sicher und persistent kommunizieren zu können. Die Speicherung und Verwaltung dieser Daten ist kritisch für die Sicherheit und Funktionalität des Clients.

Es wird zwischen zwei Arten von Daten unterschieden:

1. **Globale Daten:** Diese sind übergreifend für die Client-Instanz und unabhängig von einer spezifischen ZETA Guard Instanz.
2. **Pro-ZETA-Guard-Instanz Daten:** Diese Daten sind spezifisch für die Session mit einer einzelnen ZETA Guard Instanz.

#### 1.6.2 Globale Daten (Client-übergreifend)

Diese Daten definieren die langlebige Identität der Client-Anwendung selbst. Sie müssen persistent über alle Sessions und Neustarts der Anwendung hinweg gespeichert werden.

- `Client Instance Key` (Asymmetrisches Schlüsselpaar)
  - **Beschreibung:** Dies ist das Hauptschlüsselpaar des Clients. Der private Schlüssel wird zur Signierung der Client-Registrierung bei neuen ZETA Guard Instanzen und zur Client Assertion Authentifizierung verwendet. Der öffentliche Schlüssel dient als eindeutiger, kryptografischer Identifikator des Clients.
  - **Speicheranforderung:** Dieses Schlüsselpaar **muss** einmalig bei der ersten Initialisierung des Clients generiert und anschließend sicher und persistent gespeichert werden. Ein Verlust des privaten Schlüssels bedeutet, dass der Client seine Identität verliert und sich bei allen bereits bekannten ZETA Guard Instanzen neu registrieren muss.
  - **Sicherheit:** Der private Schlüssel ist das wertvollste Geheimnis des Clients und **darf niemals** im Klartext gespeichert werden. Siehe Kapitel [1.6.4 Sicherheitsempfehlungen für die Schlüsselspeicherung](#sicherheitsempfehlungen-fuer-die-schluesselspeicherung).

#### 1.6.3 Daten pro ZETA Guard Instanz

Für jede ZETA Guard Instanz, mit der der Client eine Verbindung aufbaut, müssen die folgenden Daten separat und zugeordnet zur jeweiligen ZETA Guard-Instanz (z.B. über deren Basis-URL) gespeichert werden.

- `DPoP Key` (Asymmetrisches Schlüsselpaar)
  - **Beschreibung:** Für jede aktive Session mit einer ZETA Guard Instanz wird ein eigenes, kurzlebiges Schlüsselpaar generiert. Der private Schlüssel wird verwendet, um einzelne API-Anfragen an den Guard zu signieren (`DPoP`).
  - **Speicheranforderung:** Dieses Schlüsselpaar ist nur für die Dauer einer Session gültig. Es sollte sicher gespeichert, aber nach Beendigung der Session (z.B. durch Logout oder Token-Ablauf ohne Refresh-Möglichkeit) verworfen werden.
  - **Sicherheit:** Auch dieser private Schlüssel muss für seine Lebensdauer sicher aufbewahrt werden.

- `Access Token`
  - **Beschreibung:** Das vom Authorization Server des ZETA Guards ausgestellte OAuth 2.0 Access Token. Es wird im `Authorization`-Header bei jeder authentifizierten API-Anfrage mitgesendet.
  - **Speicheranforderung:** Dieses Token ist kurzlebig und muss nach Ablauf erneuert werden. Es kann im Arbeitsspeicher gehalten oder persistent gespeichert werden, um nach einem Neustart der Anwendung die Session wiederaufnehmen zu können. Es besteht ein Diebstahlschutz durch die Bindung an den DPoP Schlüssel.

- `Refresh Token`
  - **Beschreibung:** Das vom Authorization Server des ZETA Guards ausgestellte OAuth 2.0 Refresh Token. Dieses Token kann verwendet werden, um ein neues Access Token zu erhalten, ohne dass der Benutzer sich erneut authentifizieren muss.
  - **Speicheranforderung:** Das Refresh Token ist langlebiger als das Access Token und stellt einen sensiblen Berechtigungsnachweis dar. Es sollte persistent und sicher gespeichert werden. Es besteht ein Diebstahlschutz durch die Bindung an den DPoP Schlüssel.

- `Client ID`
  - **Beschreibung:** Die eindeutige ID, die der ZETA Guard dem Client während des Registrierungsprozesses zugewiesen hat. Sie wird für die Token-Anforderung benötigt.
  - **Speicheranforderung:** Muss persistent gespeichert werden, solange die Registrierung beim Guard gültig sein soll.

- **Discovery-Dokument Daten (Well-Known)**
  - **Beschreibung:** Die Endpunkt-URLs und Konfigurationsdaten aus dem Discovery-Dokument des Guards (`/.well-known/zeta`).
  - **Speicheranforderung:** Es wird dringend empfohlen, diese Daten zu cachen, um wiederholte Discovery-Anfragen zu vermeiden. Der Cache sollte eine angemessene Lebensdauer haben (z.B. 24 Stunden), um auf Konfigurationsänderungen am Guard reagieren zu können.

#### Konzeptionelles Speicherlayout

Ein ZETA Client könnte die Daten konzeptionell wie folgt strukturieren:

```json
{
  "client_instance_private_key": "geschützter_speicher_ref_oder_verschlüsselt",
  "guard_sessions": {
    "https://guard1.example.com": {
      "client_id": "client-id-beim-guard-1",
      "session_private_key": "geschützter_speicher_ref_oder_verschlüsselt",
      "access_token": "ey...",
      "refresh_token": "def...",
      "discovery_cache": {
        "expires_at": "2024-12-01T10:00:00Z",
        "data": {
          "token_endpoint": "...",
          "jwks_uri": "..."
        }
      }
    },
    "https://guard2.another-provider.de": {
      "client_id": "client-id-beim-guard-2",
      "session_private_key": "...",
      "access_token": "...",
      "refresh_token": null,
      "discovery_cache": { ... }
    }
  }
}
```

### 1.6.4 Sicherheitsempfehlungen für die Schlüsselspeicherung

Private Schlüssel (`Client Instance Key`, `Session Key`) sind hochsensible Daten. Ihre Kompromittierung ermöglicht es einem Angreifer, die Identität des Clients zu missbrauchen. Sie müssen daher mit den sichersten, vom jeweiligen Betriebssystem bereitgestellten Mitteln geschützt werden.

**Grundprinzip:** Speichern Sie private Schlüssel **niemals** unverschlüsselt im Dateisystem oder in einer Klartext-Konfigurationsdatei.

Nutzen Sie stattdessen plattformspezifische, sichere Speicherorte (sog. "Keystores" oder "Secret Vaults"), die die Schlüssel an das Benutzerkonto oder die Maschinenidentität binden.

- **Microsoft Windows:**
  - **Empfehlung:** Verwenden Sie die **Data Protection API (DPAPI)**, die über die Funktionen `CryptProtectData` und `CryptUnprotectData` zugänglich ist.
  - **Funktionsweise:** DPAPI verschlüsselt Daten mithilfe eines Schlüssels, der aus den Anmeldeinformationen des Benutzers abgeleitet wird. Die Daten können somit nur von demselben Benutzer auf demselben Computer wieder entschlüsselt werden. Dies ist ideal für Desktop-Anwendungen. Für Dienste, die unter einem Systemkonto laufen, kann der Schutz an die Maschinenidentität gebunden werden.

- **Apple macOS:**
  - **Empfehlung:** Nutzen Sie den **macOS Keychain (Schlüsselbund)**.
  - **Funktionsweise:** Der Schlüsselbund ist ein zentraler, verschlüsselter Speicher für Passwörter, Zertifikate und Schlüssel. Der Zugriff wird vom Betriebssystem streng kontrolliert und erfordert in der Regel die Zustimmung des Benutzers. Verwenden Sie die `Security` Framework-APIs, um Schlüssel sicher zu speichern und abzurufen.

- **Linux:**
  - **Empfehlung (Desktop-Umgebungen):** Verwenden Sie den **Secret Service DBus API**, der von Diensten wie dem _GNOME Keyring_ oder _KWallet_ implementiert wird. Dies ist der Freedesktop.org-Standard und die bevorzugte Methode für Desktop-Anwendungen.
  - **Empfehlung (Server/Headless-Umgebungen):**
        1. **Dateibasierte Verschlüsselung:** Speichern Sie den Schlüssel in einer Datei, die mit einem Master-Passwort verschlüsselt ist (das z.B. beim Start der Anwendung abgefragt wird).
        2. **Strikte Dateiberechtigungen:** Als absolutes Minimum muss die Schlüsseldatei durch strikte Dateisystemberechtigungen geschützt werden. Der private Schlüssel sollte nur für den Benutzer lesbar sein, unter dem die Anwendung läuft.
            ```bash
            # Setzt die Berechtigung, sodass nur der Eigentümer lesen und schreiben darf
            chmod 600 /pfad/zum/privaten_schluessel.key
            ```
        Diese Methode bietet jedoch keinen Schutz, wenn ein Angreifer Lesezugriff auf das Dateisystem als der betreffende Benutzer erlangt. Sie sollte möglichst mit zusätzlicher Verschlüsselung kombiniert werden.

**Cross-Plattform-Bibliotheken:** Für in höheren Programmiersprachen (z.B. Python, Go, Rust, C#) entwickelte Clients existieren oft Bibliotheken, die die plattformspezifischen Speicher abstrahieren und eine einheitliche API für den Zugriff auf den Windows DPAPI, den macOS Keychain und den Secret Service unter Linux bieten. Die Verwendung solcher Bibliotheken wird empfohlen.

## 1.7. Versionierung

API-Versionierung: Hinweise darauf, wie Versionen der API verwaltet werden und wie Benutzer zwischen verschiedenen Versionen wechseln können.
Änderungsprotokoll: Ein Changelog, das alle wichtigen Änderungen und Updates dokumentiert.

## 1.8. Performance- und Lastannahmen

Leistungsanforderungen: Informationen über die erwartete Leistung der API, wie z.B. Antwortzeiten und Verfügbarkeit.
Lastannahmen: Informationen über das erwartete Lastverhalten auf der API, wie z.B. die Anzahl der gleichzeitigen Benutzer oder Anfragen pro Sekunde.

- SM(C)-B Signaturerstellung
- TPM Attestation
- ZETA Guard Clientregistrierung
- ZETA Guard Authentifizierung
- ZETA Guard PEP
- ZETA Guard Refresh Token Exchange

## 1.9. Rate Limits und Einschränkungen

Der OAuth Protected Resource Well-Known Endpoint ist so konfiguriert, dass er eine Rate-Limiting-Strategie implementiert. Der ZETA Client muss die Rate Limits beachten, um eine Überlastung des Endpunkts zu vermeiden. Die genauen Limits können je nach Implementierung variieren, aber typischerweise gelten folgende Richtlinien:

- X-RateLimit-Limit
- X-RateLimit-Remaining
- X-RateLimit-Reset

oder:

- RateLimit-Policy
- RateLimit

**Beispiele:** [Draft RFC für Rate Limits](https://www.ietf.org/archive/id/draft-ietf-httpapi-ratelimit-headers-09.html#name-ratelimit-policy-field)

## 1.10. Support und Kontaktinformationen

Hilfe: Informationen darüber, wo und wie Benutzer Unterstützung erhalten können (z.B. Forum, E-Mail-Support).
Fehlerberichterstattung: Wie können Nutzer Bugs melden oder Feature-Anfragen stellen?

## 1.11. FAQs und Troubleshooting

Häufige Fragen: Antworten auf häufige Fragen zur Nutzung der API.
Fehlerbehebung: Leitfaden zur Behebung häufiger Probleme.

## 1.12. Interaktive Dokumentation (optional)

Swagger/OpenAPI: Ein interaktives Interface, mit dem Entwickler API-Endpunkte direkt aus der Dokumentation heraus testen können.
API-Sandbox: Eine Testumgebung, in der Entwickler sicher mit der API experimentieren können.
Eine gut strukturierte API-Dokumentation erleichtert es Entwicklern, die API effizient zu nutzen, und trägt dazu bei, häufige Fragen und Probleme zu minimieren.

## 1.13. Changelog

Ein detaillierter Verlauf der Änderungen an der API.

## 1.14. git Branch Modell

In diesem Repository werden Branches verwendet um den Status der Weiterentwicklung und das Review von Änderungen abzubilden.

Folgende Branches werden verwendet

- _main_ (enthält den letzten freigegebenen Stand der Entwicklung; besteht permanent)
- _develop_ (enthält den Stand der fertig entwickelten Features und wird zum Review durch Industriepartner und Gesellschafter verwendet; basiert auf main; nach Freigabe erfolgt ein merge in main und ein Release wird erzeugt; besteht permanent)
- _feature/[name]_ (in feature branches werden neue Features entwickelt; basiert auf develop; nach Fertigstellung erfolgt ein merge in develop; wird nach dem merge gelöscht)
- _hotfix/[name]_ (in hotfix branches werden Hotfixes entwickelt; basiert auf main; nach Fertigstellung erfolgt ein merge in develop und in main; wird nach dem merge gelöscht)
- _concept/[name]_ (in feature branches werden neue Konzepte entwickelt; basiert auf develop; dient der Abstimmung mit Dritten; es erfolgt kein merge; wird nach Bedarf gelöscht)
- _misc/[name]_ (nur für internen Gebrauch der gematik; es erfolgt kein merge; wird nach Bedarf gelöscht)

## 1.15. Lizenzbedingungen

Copyright (c) 2024 gematik GmbH

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
