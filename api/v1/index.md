---
title: ZETA API v1
parent: ZETA API Versionen
nav_order: 1
---


# ZETA API v1

![gematik logo]({{ site.baseurl }}/images/gematik-logo-small.svg)

## Einführung

Die ZETA API ermöglicht es ZETA Clients, auf geschützte Ressourcen zuzugreifen und dabei Sicherheits- und Authentifizierungsmechanismen zu nutzen.
Der ZETA Client nutzt Endpunkte des ZETA Guard für die Client-Registrierung, Authentifizierung und Autorisierung.

Stationäre Clients verwenden bei der Authentifizierung Endpunkte des Konnektors/TI-Gateways und des ZETA Attestation Service.

Mobile Clients verwenden Endpunkte der betriebssystem-spezifischen Attestierung. Die Authentifizierung erfolgt mit OpenID Connect (OIDC) und der ZETA Guard API.

Die ZETA API ist so konzipiert, dass sie eine sichere und flexible Interaktion zwischen ZETA Clients und geschützten Ressourcen ermöglicht. ZETA basiert auf den Standards des OAuth 2.0 Frameworks und erweitert es um spezifische Anforderungen der gematik.

---

## Voraussetzungen für die ZETA Client Nutzung

Folgende Voraussetzungen müssen für die Nutzung des ZETA Clients erfüllt sein:

- Der **FQDN des Resource Servers** wird vom ZETA Client benötigt, um die ZETA Guard API zu erreichen.
- Die [roots.json](https://download.tsl.ti-dienste.de/ECC/ROOT-CA/roots.json) Datei wird vom ZETA Client benötigt, um die Trust Chain zu validieren. Diese Datei muss wöchentlich aktualisiert werden.

Zusätzlich gibt es anwendungsspezifische Voraussetzungen, die für die Nutzung der ZETA Guard API erforderlich sind.

- **VSDM2:** Für VSDM2 Requests wird ein PoPP (Proof of Patient Presence) Token benötigt. Das PoPP Token muss im [Header PoPP](https://gemspec.gematik.de/docs/gemSpec/gemSpec_ZETA/latest/#A_25669) an den ZETA Client übergeben werden.

## Ablauf

Abhängig vom Zustand des ZETA Clients müssen verschiedene Teilabläufe ausgeführt werden, oder können übersprungen werden. Die ZETA API besteht aus mehreren Endpunkten, die verschiedene Funktionen bereitstellen. Diese Endpunkte sind in verschiedene Unter-Abläufe aufgeteilt:

- **Konfiguration und Discovery:** Der ZETA Client muss die Konfiguration des ZETA Guards ermitteln, um die richtigen Endpunkte zu erreichen.
- **Client-Registrierung:** Jeder ZETA Client muss sich einmalig beim ZETA Guard registrieren, um eine `client_id` zu erhalten und seinen öffentlichen Schlüssel zu hinterlegen.
- **Authentifizierung und Autorisierung:** Der Client muss sich authentifizieren und die Integrität seiner Plattform nachweisen. Zusätzlich muss sich der Nutzer oder beim Primärsystem die Organisation authentifizieren, um ein Access Token für den Zugriff auf geschützte Ressourcen zu erhalten.

Der Gesamtprozess beginnt damit, dass ein **Nutzer** auf einen Endpunkt eines Resource Servers zugreifen möchte. Dieser Zugriff wird über das Primärsystem vom **ZETA Client** im Auftrag des Nutzers ausgeführt; siehe folgende Abbildung.

![tpm-attestation-and-token-exchange-overview]({{ site.baseurl }}/images/tpm-attestation-and-token-exchange/tpm-attestation-and-token-exchange-overview.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 1: Ablauf TPM Attestation und Token Exchange Überblick</em></p>

---

### Konfiguration und Discovery

In dieser Phase ermittelt der ZETA Client die notwendigen Endpunkte und Konfigurationen von den ZETA Guard Komponenten (PEP http Proxy und PDP Authorization Server). Der Client fragt bekannte Endpunkte (`/.well-known/oauth-protected-resource` und `/.well-known/oauth-authorization-server`) ab, um die Konfiguration des Resource Servers und des Authorization Servers zu erhalten. Das folgende Bild zeigt den Ablauf.

![tpm-attestation-and-token-exchange-overview]({{ site.baseurl }}/images/tpm-attestation-and-token-exchange/discovery-and-configuration.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 2: Ablauf Discovery and Configuration</em></p>

### Client-Registrierung

#### Stationäre Clients

Jeder ZETA Client muss sich am ZETA Guard registrieren, über den er auf geschützte Ressourcen zugreifen möchte. Dieser Prozess findet **einmalig pro ZETA Guard-Instanz** statt. Der gesamte Prozess ist zweistufig, um die administrative Einrichtung von der technischen Inbetriebnahme zu trennen:

- **Initiale Registrierung:** Der Client erzeugt ein langlebiges kryptographisches Schlüsselpaar (**Client Instance Key**), sendet den öffentlichen Teil an den Authorization Server und erhält im Gegenzug eine `client_id`. Der Client ist danach im System bekannt, aber sein Status ist `pending_attestation`, d.h. er ist noch nicht für den Zugriff auf Ressourcen freigeschaltet.
- **Aktivierung (Erster Token Exchange):** Der Client wird aktiviert, indem er zum ersten Mal einen Token Exchange mit einer erfolgreichen **Attestierung** durchführt. Damit beweist er nicht nur den Besitz des privaten Schlüssels, sondern (bei der TPM-Attestierung) auch die Integrität der Plattform, auf der er läuft. Nach erfolgreicher Prüfung wird sein Status im ZETA Guard auf `active` gesetzt.

Die Client Registrierung ist in der folgenden Abbildung dargestellt.

![Ablauf Client Registrierung]({{ site.baseurl }}/images/tpm-attestation-and-token-exchange/dynamic-client-registration.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 3: Ablauf Client Registrierung</em></p>

Für die initiale Registrierung sendet der ZETA Client eine Anfrage an den Dynamic Client Registration (DCR) Endpoint. Diese Anfrage enthält alle notwendigen Metadaten, um den Client für die `private_key_jwt` Authentifizierungsmethode vorzubereiten:

- `client_name`: Ein für Menschen lesbarer Name für den Client.
- `token_endpoint_auth_method`: Die geplante Authentifizierungsmethode, hier `private_key_jwt`.
- `grant_types`: Die erlaubten Grant Types (z.B. `urn:ietf:params:oauth:grant-type:token-exchange`, `refresh_token`).
- `jwks`: Ein JSON Web Key Set, das den **öffentlichen Client Instance Key** enthält. Dieser Schlüssel wird vom Authorization Server verwendet, um die Signatur der Client Assertions zu überprüfen.

---

#### Mobile Clients

_Hinweis:_ Der Prozess für Mobile Clients wird in zukünftigen Versionen der API detaillierter beschrieben, sobald die Entwicklung von ZETA Stufe 2 abgeschlossen ist.

### Authentifizierung und Autorisierung

Nach erfolgreicher Registrierung besitzt der ZETA Client eine `client_id` und ein zugehöriges Schlüsselpaar. Um auf einen Fachdienst zugreifen zu können, benötigt der Client ein Access Token vom Authorization Server (AS). Stationäre ZETA Clients verwenden dafür den Token Exchange Flow, während mobile ZETA Clients den Authorization Code Flow mit OpenID Connect nutzen.

#### Stationäre Clients

Die Authentifizierung und Autorisierung für stationäre Clients unterscheidet zwei Hauptfälle:

1. **Token-Austausch mit Attestierung:** Hier wird die Identität der Institution (mittels `subject_token` von der SM(C)-B) nachgewiesen und die Integrität des Clients durch eine Attestierung überprüft. Dieser aufwändigere Prozess wird zu Beginn einer neuen Session (oder zur Re-Attestierung) durchgeführt, um sicherzustellen, dass der ZETA Client und das Primärsystem vertrauenswürdig sind.
2. **Token-Erneuerung (Refresh Token):** Hier wird ein vorhandenes Refresh Token genutzt, um ein neues Access Token zu erhalten. Dieser Prozess ist performanter und verzichtet auf eine erneute Attestierung.

Diese Trennung schafft eine Balance zwischen höchster Sicherheit beim initialen Zugriff und Effizienz bei der Erneuerung bestehender Sitzungen.

Die folgende Abbildung zeigt den Ablauf des Token-Austauschs mit Client Assertion JWT Authentifizierung und DPoP.

![tpm-attestation-and-token-exchange-overview]({{ site.baseurl }}/images/tpm-attestation-and-token-exchange/token-exchange-with-client-assertion-jwt-auth.svg)
<p style="font-size:0.9em; text-align:center;"><em>Abbildung 4: Ablauf Authentifizierung und TPM-Attestation</em></p>

##### Pfad A: Token-Austausch mit Attestierung

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

##### Pfad B: Token-Erneuerung via Refresh Token

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

##### Gemeinsame nachfolgende Schritte

Nach erfolgreicher Validierung in einem der beiden Pfade fragt der AS bei der Policy Engine (PE) an, ob der Zugriff gewährt werden soll. Ist die Entscheidung positiv, stellt der AS ein neues Access Token (gebunden an den DPoP-Schlüssel) und ein neues Refresh Token aus.

---

#### Mobile Clients

Die Authentifizierung für mobile Clients erfolgt mit OpenID Connect und OAuth2 Authorization Code Flow.
Die Beschreibung wird ergänzt, wenn die Entwicklung von ZETA Stufe 2 abgeschlossen ist.

## Endpunkte

Die ZETA API besteht aus mehreren Endpunkten, die verschiedene Funktionen bereitstellen. Diese Endpunkte sind in verschiedene Kategorien unterteilt:

- **ZETA Guard API Endpunkte:** Diese Endpunkte ermöglichen die Interaktion mit dem ZETA Guard, einschließlich der Registrierung von Clients, der Authentifizierung und der Autorisierung.
- **Konnektor/TI-Gateway Endpunkte:** Diese Endpunkte ermöglichen die Interaktion mit dem Konnektor/TI-Gateway, um Karteninformationen zu lesen und Authentifizierungsanfragen zu stellen.
- **ZETA Attestation Service Endpunkte:** Diese Endpunkte ermöglichen die Interaktion mit dem ZETA Attestation Service, um TPM-Attestierungen durchzuführen.

### ZETA Guard API Endpunkte

Die ZETA Guard API Endpunkte sind für die Interaktion mit dem ZETA Guard zuständig. Sie ermöglichen die Registrierung von Clients, die Authentifizierung und Autorisierung sowie den Zugriff auf geschützte Ressourcen.
Die ZETA Guard API Endpunkte sind über HTTPS erreichbar und erfordern eine gültige TLS-Verbindung. Der ZETA Client muss die folgenden Sicherheitsanforderungen erfüllen:

- ZETA Clients müssen TLS 1.3 oder höher unterstützen.
- Es müssen die TLS Anforderungen aus [gemSpec_Krypt Kapitel 3.3.2](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Krypt/latest/#3.3.2) erfüllt werden.

#### OAuth Protected Resource Well-Known Endpoint

Dieser Endpunkt bietet eine standardisierte Methode für OAuth Protected Resources (OPR), um ihre Fähigkeiten und Konfigurationsdetails zu veröffentlichen (RFC 9728). Er ermöglicht es Clients, die notwendigen Informationen über die OPR abzurufen, wie z.B. unterstützte Schemata, Verifizierungsmethoden, Token-Introspektion-Endpunkte und unterstützte Scopes. Der Endpunkt ist unter dem Pfad `/.well-known/oauth-protected-resource` relativ zur Basis-URL der Protected Resource erreichbar.

---

##### Anfragen

Der Endpunkt wird über eine einfache HTTP GET-Anfrage ohne Body aufgerufen.

```http
GET /.well-known/oauth-protected-resource HTTP/1.1
Host: api.example.com
Accept: application/json
```

---

##### Antworten

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
  "zeta_asl_use": "required",
  "api_versions_supported": [
    {
      "major_version": 1,
      "version": "1.4.2",
      "status": "stable",
      "documentation_uri": "https://github.com/gematik/zeta/api/v1"
    },
    {
      "major_version": 2,
      "version": "2.0.0-beta.3",
      "status": "beta",
      "documentation_uri": "https://github.com/gematik/zeta/api/v2"
    },
    {
      "major_version": 1,
      "version": "1.3.0",
      "status": "deprecated",
      "documentation_uri": "https://github.com/gematik/zeta/api/v1"
    }
  ]
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

#### Authorization Server Well-Known Endpoint

Dieser Endpunkt ermöglicht Clients und anderen Parteien die einfache Entdeckung der Konfigurationsmetadaten eines ZETA Guard OAuth 2.0 Autorisierungsservers (AS) und seiner Fähigkeiten. Er ist gemäß RFC 8414 definiert und bietet eine standardisierte Methode, um Informationen wie Endpunkt-URIs, unterstützte Grant Types und Scopes abzurufen.

---

##### Anfragen

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

##### Antworten

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
  ],
  "api_versions_supported": [
    {
      "major_version": 1,
      "version": "1.4.2",
      "status": "stable",
      "documentation_uri": "https://github.com/gematik/zeta/api/v1"
    },
    {
      "major_version": 2,
      "version": "2.0.0-beta.3",
      "status": "beta",
      "documentation_uri": "https://github.com/gematik/zeta/api/v2"
    },
    {
      "major_version": 1,
      "version": "1.3.0",
      "status": "deprecated",
      "documentation_uri": "https://github.com/gematik/zeta/api/v1"
    }
  ],
  "api_versions_supported": [
    {
      "major_version": 1,
      "version": "1.4.2",
      "status": "stable",
      "documentation_uri": "https://github.com/gematik/zeta/api/v1"
    },
    {
      "major_version": 2,
      "version": "2.0.0-beta.3",
      "status": "beta",
      "documentation_uri": "https://github.com/gematik/zeta/api/v2"
    },
    {
      "major_version": 1,
      "version": "1.3.0",
      "status": "deprecated",
      "documentation_uri": "https://github.com/gematik/zeta/api/v1"
    }
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

#### Nonce Endpoint

Dieser Endpunkt ermöglicht Clients das Abrufen eines einmaligen kryptographischen Werts, einer "Nonce". Im Kontext der ZETA-Architektur dient diese Nonce primär dazu, eine spezifische **TPM-Attestierung an eine aktuelle Transaktion zu binden**, um Replay-Angriffe zu verhindern. Sie wird Teil der `attestation_challenge`, die vom TPM signiert wird.

Beim Token Endpunkt wird ebenfalls eine Nonce benötigt, um die Integrität der Transaktion zu gewährleisten. Diese Nonce wird in der Client Assertion verwendet, um Replay-Angriffe zu verhindern und die Bindung zwischen der Client Authentifizierung und der Transaktion sicherzustellen.

---

##### Anfragen

**Beispiel Anfrage:**

```http
GET /nonce HTTP/1.1
Host: api.example.com
Accept: application/json
```

---

##### Antworten

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

#### Dynamic Client Registration Endpoint

Dieser Endpunkt ermöglicht die dynamische Registrierung neuer OAuth 2.0 Clients beim Authorization Server gemäß RFC 7591. Der Prozess dient dazu, eine `client_id` zu erhalten und den öffentlichen **Client Instance Key** zu registrieren, der für die `private_key_jwt` Client-Authentifizierung verwendet wird.

Die Registrierung selbst erfordert **keine** Attestierung. Der Client erhält den Status `pending_attestation` und muss seine Integrität beim ersten Token Exchange beweisen, um aktiviert zu werden. Die Registrierung muss über eine TLS-geschützte Verbindung erfolgen.

_Hinweis:_ Es fehlen noch die Operationen zur Verwaltung von bestehenden Client Registrierungen (z.B. Aktualisierung, Löschung). Diese werden in zukünftigen Versionen der API ergänzt.

---

##### Anfragen für stationäre Clients

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

##### Antworten

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

##### Anfragen für mobile Clients

Die Registrierung für mobile Clients erfolgt ähnlich wie bei stationären Clients, jedoch mit anderen Anforderungen an die Client-Attestation, die auf den jeweiligen Plattformen basieren. Mobile Clients verwenden eine spezifische Attestierungsmethode, die auf den Betriebssystemen basiert (z.B. Android SafetyNet, iOS DeviceCheck).

Die Beschreibung wird in Stufe 2 der ZETA API ergänzt.

#### Token Endpoint

Der Token Endpoint des Autorisierungsservers (AS) ermöglicht den Austausch eines Tokens gegen ein vom Authorizationserver ausgestelltes Access Token, gemäß dem OAuth 2.0 Token Exchange (RFC 8693) oder die Erneuerung von Token (`refresh_token`). Der Client muss sich mit einer JWT Client Assertion gegenüber den Authorization Server authentifizieren.

Der Endpunkt ist ein POST-Endpunkt, der Formular-kodierte Daten (`application/x-www-form-urlencoded`) im Body erwartet und JSON-Objekte im Erfolgsfall oder "Problem Details" im Fehlerfall zurückgibt.

Der Endpunkt unterstützt verschiedene Grant Types, einschließlich `authorization_code` (ab ZETA Stufe 2), `urn:ietf:params:oauth:grant-type:token-exchange`, `refresh_token` und `urn:ietf:params:oauth:grant-type:token-exchange`.

##### Anfragen

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

##### Antworten

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

#### Resource Endpoint

Der Resource Endpoint ist der Endpunkt, der von der geschützten Ressource (Protected Resource) bereitgestellt wird, um auf geschützte Daten zuzugreifen. Er ist durch den ZETA Guard PEP vor unberechtigtem Zugriff geschützt. Für den Zugriff auf die geschützte Ressource wird ein gültiges Access Token und ein gültiges [DPoP Proof](https://www.rfc-editor.org/rfc/rfc9449.html) benötigt. Zusätzlich kann eine Anwendung ein gültiges [PoPP Proof](https://gemspec.gematik.de/docs/gemSpec/gemSpec_ZETA/latest/#A_25669) erfordern.

Der Resource Endpoint unterstützt neben TLS eine zusätzliche Verschlüsselungsschicht [ZETA/ASL](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Krypt/latest/#8) (ZETA/Additional Security Layer).
Im [Well-Known JSON Dokument der geschützten Ressource](#1511-oauth-protected-resource-well-known-endpoint) wird angegeben, ob der Endpunkt ZETA/ASL unterstützt. Der ZETA/ASL Kanal wird nach dem TLS Verbindungsaufbau aufgebaut und verwendet, um die Kommunikation zwischen Client und Resource Endpoint zu sichern.

##### Anfragen

Der ZETA Guard PEP empfängt die Anfragen und prüft das Access Token im Authentication Header sowie das DPoP Proof im DPoP Header.

**HTTP Methode:** wird durch die geschützte Ressource bestimmt (z.B. `GET`, `POST`, `PUT`, `DELETE`).

**Pfad:** wird durch die geschützte Ressource bestimmt (z.B. `/api/resource`).

**Content-Type:** wird durch die geschützte Ressource bestimmt (z.B. `application/json`).

##### Antworten

Die Antwort des Resource Endpoints hängt von der geschützten Ressource ab und kann verschiedene Statuscodes und Datenformate zurückgeben.

### Konnektor/TI-Gateway Endpunkte

Die Endpunkte im Konnektor oder im Highspeed Konnektoren des TI-Gateways werden für die Erstellung von Signaturen mit Der SM(C)-B sowie für die Abfrage des SM(C)-B Zertifikats während der Authentifizierung am ZETA Guard verwendet.

_Hinweis: Perspektivisch ist vorgesehen, dass der Zugriff auf das TI-Gateway über den ZETA Guard erfolgt, um die Sicherheit und Integrität der Kommunikation zu gewährleisten. Während der Authentifizierung wird anstatt der SM(C)-B Identität eine TI-Gateway Identität verwendet._

#### ReadCardCertificate

Die Operation [ReadCardCertificate](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/#TIP1-A_4698-03) ist in der [Konnektor Spezifikation](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/index.html) definiert.

#### ExternalAuthenticate

Die Operation [ExternalAuthenticate](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/#TIP1-A_4698-03) ist in der [Konnektor Spezifikation](https://gemspec.gematik.de/docs/gemSpec/gemSpec_Kon/latest/index.html) definiert.

### ZETA Attestation Service Endpunkte

Der `ZetaAttestationService` stellt einen gRPC-Dienst zur Verfügung, der es stationären Clients (Primärsystem) ermöglicht, signierte Attestierungsinformationen für den Client abzurufen. Diese Informationen basieren auf Integritätsmessungen, die in ausgewählten Platform Configuration Registers (PCRs) des Trusted Platform Module (TPM) gespeichert sind. Der ZETA Guard Authorization Server verwendet diese Attestierungsdaten, um die Integrität und Authentizität der Softwareumgebung des Clients zu verifizieren, bevor Zugriff auf geschützte Ressourcen gewährt wird.

Der ZETA Attestation Service wird vom Hersteller des stationären Clients bereitgestellt und es muss eine Vertrauensbeziehung zwischen stationären Client und ZETA Attestation Service bestehen, um zu gewährleisten, dass die Attestation über die vorgesehenen Software-Komponenten erfolgt.

_Hinweis:_ Während der Installation oder bei Updates des stationären Clients muss auch ein Update des ZETA Attestation Service erfolgen um eine neue Baseline für die Integrität des stationären Clients zu setzen. Die Baseline besteht aus einem Hash über alle unveränderlichen Komponenten des stationären Clients, inkl. ZETA Attestation Service.

_Hinweis:_ Der ZETA Attestation Service muss bei jedem Start des Clients die Messung über die Integrität des Clients durchführen und in das PCR schreiben.

_Hinweis:_ Der ZETA Attestation Service ist nicht für mobile Clients vorgesehen. Mobile Clients verwenden eine andere Attestierungsmethode, die auf den jeweiligen Plattformen basiert (z.B. Android SafetyNet, iOS DeviceCheck).

_Hinweis:_ TODO Umgang mit Messung des Clients weicht von Baseline ab; empfohlenes Verhalten für Client und ZetaAttestationService (z. B. automatisch Support informieren)

#### Dienstdefinition

- **Service Name:** `zeta.attestation.service.v1.ZetaAttestationService`
- **Proto Buffer Spezifikation:** [zeta-attestation-service.proto](/src/gRPC/zeta-attestation-service.proto)

#### RPC Methoden

##### GetAttestation

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

## Verwaltung von Schlüsseln und Session-Daten im ZETA Client

### Einleitung

Ein ZETA Client muss verschiedene kryptografische Schlüssel und Session-Informationen verwalten, um mit einer oder mehreren ZETA Guard Instanzen sicher und persistent kommunizieren zu können. Die Speicherung und Verwaltung dieser Daten ist kritisch für die Sicherheit und Funktionalität des Clients.

Es wird zwischen zwei Arten von Daten unterschieden:

1. **Globale Daten:** Diese sind übergreifend für die Client-Instanz und unabhängig von einer spezifischen ZETA Guard Instanz.
2. **Pro-ZETA-Guard-Instanz Daten:** Diese Daten sind spezifisch für die Session mit einer einzelnen ZETA Guard Instanz.

#### Globale Daten (Client-übergreifend)

Diese Daten definieren die langlebige Identität der Client-Anwendung selbst. Sie müssen persistent über alle Sessions und Neustarts der Anwendung hinweg gespeichert werden.

- `Client Instance Key` (Asymmetrisches Schlüsselpaar)
  - **Beschreibung:** Dies ist das Hauptschlüsselpaar des Clients. Der private Schlüssel wird zur Signierung der Client-Registrierung bei neuen ZETA Guard Instanzen und zur Client Assertion Authentifizierung verwendet. Der öffentliche Schlüssel dient als eindeutiger, kryptografischer Identifikator des Clients.
  - **Speicheranforderung:** Dieses Schlüsselpaar **muss** einmalig bei der ersten Initialisierung des Clients generiert und anschließend sicher und persistent gespeichert werden. Ein Verlust des privaten Schlüssels bedeutet, dass der Client seine Identität verliert und sich bei allen bereits bekannten ZETA Guard Instanzen neu registrieren muss.
  - **Sicherheit:** Der private Schlüssel ist das wertvollste Geheimnis des Clients und **darf niemals** im Klartext gespeichert werden. Siehe Kapitel [1.6.4 Sicherheitsempfehlungen für die Schlüsselspeicherung](#164-sicherheitsempfehlungen-für-die-schlüsselspeicherung).

#### Daten pro ZETA Guard Instanz

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
  - **Beschreibung:** Die eindeutige ID, die der ZETA Guard dem ZETA Client während des Registrierungsprozesses zugewiesen hat. Sie wird für die Token-Anforderung benötigt.
  - **Speicheranforderung:** Muss persistent gespeichert werden, solange die Registrierung beim ZETA Guard gültig sein soll.

- **Discovery-Dokument Daten (Well-Known)**
  - **Beschreibung:** Die Endpunkt-URLs und Konfigurationsdaten aus den Discovery-Dokumenten des ZETA Guards.
  - **Speicheranforderung:** Es wird dringend empfohlen, diese Daten zu cachen, um wiederholte Discovery-Anfragen zu vermeiden. Der Cache sollte eine angemessene Lebensdauer haben (z.B. 24 Stunden), um auf Konfigurationsänderungen am Guard reagieren zu können.

#### Konzeptionelles Speicherlayout

Ein ZETA Client könnte die Daten konzeptionell wie folgt strukturieren:

```json
{
  "client_instance_private_key": "geschützter_speicher_ref",
  "guard_sessions": {
    "https://guard1.example.com": {
      "client_id": "client-id-beim-zeta-guard-1",
      "session_private_key": "geschützter_speicher_ref",
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
      "client_id": "client-id-beim-zeta-guard-2",
      "session_private_key": "...",
      "access_token": "...",
      "refresh_token": null,
      "discovery_cache": { ... }
    }
  }
}
```

### Sicherheitsempfehlungen für die Schlüsselspeicherung

Private Schlüssel (`Client Instance Key`, `DPoP Key`) sind hochsensible Daten. Ihre Kompromittierung ermöglicht es einem Angreifer, die Identität des Clients zu missbrauchen. Sie müssen daher mit den sichersten, vom jeweiligen Betriebssystem bereitgestellten Mitteln geschützt werden.

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

## Versionierung

Um eine stabile und vorhersagbare Entwicklungsumgebung für Client-Anwendungen zu gewährleisten, folgt die ZETA API strikt den Prinzipien von **Semantic Versioning 2.0.0 (SemVer)**. Jede Änderung an der API wird klassifiziert, um die Auswirkungen auf bestehende Clients transparent zu machen.

### Versionierungsschema: MAJOR.MINOR.PATCH

Jede ZETA Guard Instanz deklariert ihre API-Version im Format `MAJOR.MINOR.PATCH` (z.B. `1.2.3`). Die Bedeutung der einzelnen Komponenten ist wie folgt definiert:

- **MAJOR-Version (z.B. `1`.2.3):** Wird erhöht, wenn **rückwärtsinkompatible ("breaking") Änderungen** an der API vorgenommen werden. Dies erfordert eine Anpassung aufseiten des Clients, um weiterhin korrekt zu funktionieren.
  - _Beispiele:_ Entfernen eines Endpunkts, Umbenennung eines JSON-Feldes, Änderung eines Felddatentyps, Hinzufügen eines verpflichtenden Request-Parameters.

- **MINOR-Version (z.B. 1.`2`.3):** Wird erhöht, wenn **neue Funktionalität in einer rückwärtskompatiblen Weise** hinzugefügt wird. Bestehende Clients dürfen durch diese Änderungen nicht beeinträchtigt werden.
  - _Beispiele:_ Hinzufügen eines neuen API-Endpunkts, Hinzufügen eines neuen, optionalen Feldes in einer JSON-Antwort, Hinzufügen eines neuen, optionalen Request-Parameters.

- **PATCH-Version (z.B. 1.2.`3`):** Wird erhöht, wenn **rückwärtskompatible Fehlerbehebungen ("bug fixes")** vorgenommen werden, die das Verhalten der API korrigieren, aber keine neue Funktionalität einführen.
  - _Beispiele:_ Korrektur einer fehlerhaften Validierungslogik, Behebung eines internen Fehlers, der zu einem `500 Internal Server Error` führte.

Zusätzlich können Prerelease-Tags verwendet werden (z.B. `2.0.0-beta.1`), um instabile Vorabversionen zu kennzeichnen.

#### Implementierung der Versionierung

Die Versionierung wird durch eine Kombination aus URL-Pfad, HTTP-Headern und dem Discovery-Dokument umgesetzt.

##### 1. URL-Pfad für die MAJOR-Version

Rückwärtsinkompatible Änderungen sind am einschneidendsten. Daher wird die **MAJOR-Version** direkt und explizit im URL-Pfad der API geführt.

- **Schema:** `https://<guard-base-url>/zeta/v{major-version}/<endpoint>`
- **Beispiel für Version `1.4.2`:** `POST https://guard.example.com/zeta/v1/token`
- **Beispiel für Version `2.0.0`:** `POST https://guard.example.com/zeta/v2/token`

##### 2. Discovery-Dokument als "Source of Truth"

Die Discovery-Dokumente (`/.well-known/oauth-protected-resource` und `/.well-known/oauth-authorization-server`) sind die zentrale Anlaufstelle für einen Client, um die exakten, vom ZETA Guard unterstützten Versionen zu ermitteln.

- **`api_versions_supported`:** Dieses JSON-Objekt listet alle vom ZETA Guard angebotenen MAJOR-Versionen mit ihrer jeweiligen vollen SemVer-Version auf.

```json
// Beispiel-Ausschnitt aus /.well-known/...
{
  "issuer": "https://zeta-guard.example.com",
  // ... andere Endpunkte
  "api_versions_supported": [
    {
      "major_version": 1,
      "version": "1.4.2", // Die volle, stabile SemVer-Version für v1
      "status": "stable",
      "documentation_uri": "https://gematik.github.io/ZETA/v1/"
    },
    {
      "major_version": 2,
      "version": "2.0.0-beta.3", // Eine instabile Vorabversion für v2
      "status": "beta",
      "documentation_uri": "https://gematik.github.io/ZETA/v2/"
    }
  ]
}
```

##### 3. HTTP-Header zur Laufzeit-Identifikation

Jede Antwort des ZETA Guards enthält einen `ZETA-API-Version`-Header, der die exakte SemVer-Version der ausführenden Instanz angibt. Dies ist besonders für Debugging und Logging wertvoll.

- **Beispiel-Response-Header:**
    `HTTP/1.1 200 OK`
    `Content-Type: application/json`
    `ZETA-API-Version: 1.4.2`

#### Client-Verhalten und Kompatibilitätsregeln

Um die Stabilität zu gewährleisten, müssen Clients die folgenden Regeln befolgen:

1. **Toleranz gegenüber MINOR- und PATCH-Versionen:** Ein Client, der für eine bestimmte API-Version entwickelt wurde (z.B. `1.2.0`), **muss** nahtlos mit jeder neueren, rückwärtskompatiblen Version derselben MAJOR-Version (z.B. `1.3.0` oder `1.2.1`) funktionieren. Dies bedeutet konkret:
    - **Unbekannte Felder ignorieren:** Der Client-Parser **muss** unbekannte Felder in JSON-Antworten ignorieren und darf keinen Fehler auslösen.
    - **Reihenfolgeunabhängigkeit:** Der Client darf sich nicht auf die Reihenfolge von Feldern in JSON-Objekten verlassen.

2. **Explizite Wahl der MAJOR-Version:** Der Client wählt die MAJOR-Version aktiv über den verwendeten URL-Pfad (z.B. `/v1/`). Ein Wechsel zu einer neuen MAJOR-Version (z.B. auf `/v2/`) ist eine bewusste Entwicklungsentscheidung und erfordert eine Code-Anpassung.

#### Deprecation Policy (Außerbetriebnahme)

Wenn eine neue MAJOR-Version (z.B. `v2`) den Status `stable` erreicht, wird die vorherige MAJOR-Version (`v1`) als `deprecated` (veraltet) markiert.

1. **Ankündigungsphase:** Die veraltete Version wird im Discovery-Dokument als `deprecated` gekennzeichnet. Anfragen an diese Version können einen `Warning`-HTTP-Header zurückgeben, der auf die bevorstehende Abschaltung hinweist.
2. **Migrationszeitraum:** Es wird einen klar kommunizierten Zeitraum geben, in dem beide MAJOR-Versionen parallel betrieben werden, um Clients eine reibungslose Migration zu ermöglichen. Zusätzlich wird überwacht, welche ZETA Client-Versionen aktiv sind, um die Migration zu unterstützen.
3. **Abschaltung:** Nach Ablauf des Migrationszeitraums und wenn die Überwachung der ZETA Clients ergeben hat, dass keine veralteten Clients mehr aktiv genutzt werden, wird die veraltete Version abgeschaltet. Anfragen an die Endpunkte dieser Version führen dann zu einem `HTTP 410 Gone`-Fehler.

## Performance- und Lastannahmen

Leistungsanforderungen: Informationen über die erwartete Leistung der API, wie z.B. Antwortzeiten und Verfügbarkeit.
Lastannahmen: Informationen über das erwartete Lastverhalten auf der API, wie z.B. die Anzahl der gleichzeitigen Benutzer oder Anfragen pro Sekunde.

- SM(C)-B Signaturerstellung
- TPM Attestation
- ZETA Guard Clientregistrierung
- ZETA Guard Authentifizierung
- ZETA Guard PEP
- ZETA Guard Refresh Token Exchange

## Rate Limits und Einschränkungen

Der OAuth Protected Resource Well-Known Endpoint ist so konfiguriert, dass er eine Rate-Limiting-Strategie implementiert. Der ZETA Client muss die Rate Limits beachten, um eine Überlastung des Endpunkts zu vermeiden. Die genauen Limits können je nach Implementierung variieren, aber typischerweise gelten folgende Richtlinien:

- X-RateLimit-Limit
- X-RateLimit-Remaining
- X-RateLimit-Reset

oder:

- RateLimit-Policy
- RateLimit

**Beispiele:** [Draft RFC für Rate Limits](https://www.ietf.org/archive/id/draft-ietf-httpapi-ratelimit-headers-09.html#name-ratelimit-policy-field)

## Support und Kontaktinformationen

Hilfe: Informationen darüber, wo und wie Benutzer Unterstützung erhalten können (z.B. Forum, E-Mail-Support).
Fehlerberichterstattung: Wie können Nutzer Bugs melden oder Feature-Anfragen stellen?

## FAQs und Troubleshooting

Häufige Fragen: Antworten auf häufige Fragen zur Nutzung der API.
Fehlerbehebung: Leitfaden zur Behebung häufiger Probleme.

## Changelog

Ein detaillierter Verlauf der Änderungen an der API.

## git Branch Modell

In diesem Repository werden Branches verwendet um den Status der Weiterentwicklung und das Review von Änderungen abzubilden.

Folgende Branches werden verwendet

- _main_ (enthält den letzten freigegebenen Stand der Entwicklung; besteht permanent)
- _develop_ (enthält den Stand der fertig entwickelten Features und wird zum Review durch Industriepartner und Gesellschafter verwendet; basiert auf main; nach Freigabe erfolgt ein merge in main und ein Release wird erzeugt; besteht permanent)
- _feature/[name]_ (in feature branches werden neue Features entwickelt; basiert auf develop; nach Fertigstellung erfolgt ein merge in develop; wird nach dem merge gelöscht)
- _hotfix/[name]_ (in hotfix branches werden Hotfixes entwickelt; basiert auf main; nach Fertigstellung erfolgt ein merge in develop und in main; wird nach dem merge gelöscht)
- _concept/[name]_ (in feature branches werden neue Konzepte entwickelt; basiert auf develop; dient der Abstimmung mit Dritten; es erfolgt kein merge; wird nach Bedarf gelöscht)
- _misc/[name]_ (nur für internen Gebrauch der gematik; es erfolgt kein merge; wird nach Bedarf gelöscht)

## Lizenzbedingungen

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
