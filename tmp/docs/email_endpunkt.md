# E-Mail-Weitergabe an den Resource Server per Endpunkt 

## Status
Umsetzungsvorlage / Architekturvorschlag

## Ziel
Die E-Mail-Adresse eines Nutzers soll einem Resource Server nur bei tatsächlichem Bedarf bereitgestellt werden. Die E-Mail darf weder im Access Token noch im `zeta-user-info` Header transportiert werden. Die Einwilligung des Nutzers zur Verarbeitung bzw. Weitergabe seiner E-Mail-Adresse liegt vollständig in der Verantwortung der Fachanwendung; der ZETA Guard prüft und verwaltet keine Einwilligung. Da jedoch nicht jeder Fachdienst die E-Mail für eine fachliche Verwendung benötigt, muss der ZETA Guard wissen, ob für die jeweilige Kombination aus Identität und Resource Server eine fachliche Verwendung der E-Mail vorgesehen ist.

# 1. Architekturvorschlag

Der ZETA Guard verwaltet identitätsbezogen, ob eine fachliche Verwendung der E-Mail-Adresse vorgesehen ist.
Der Resource Server identifiziert den Nutzer über den bereits vorhandenen `identifier` aus dem `zeta-user-info` Header.
Der aufrufende Resource Server wird ausschließlich über mTLS identifiziert.
Der ZETA Guard prüft:
1. Authentizität des Resource Servers (mTLS)
2. Zuordnung der Identität zum Resource Server
3. Kennzeichnung, dass für diese Kombination eine fachliche Verwendung der E-Mail vorgesehen ist (`email_business_use_intended`)
4. Vorliegen einer gespeicherten E-Mail-Adresse

Erst danach wird die E-Mail zurückgegeben. Die Einwilligung des Nutzers selbst wird ausschließlich von der Fachanwendung eingeholt und verwaltet.

# 2. Zielarchitektur

## Request-Pfad

```text
Client
  -> PEP
      -> Resource Server
          Header: zeta-user-info
              identifier=<identifier>
```

Falls der Resource Server die E-Mail benötigt:

```http
      GET /zeta/email?id=<identifier>
```

Der Guard bestimmt die RS-Identität ausschließlich über das mTLS-Zertifikat.

# 3. Sicherheitsmodell

## Prinzip

Die Berechtigung ergibt sich aus diesen drei Faktoren:

### Faktor 1: Identität des Resource Servers

Der Guard authentisiert den aufrufenden Resource Server mittels Client-Zertifikat.
Aus dem Zertifikat wird eine eindeutige technische RS-Identität ermittelt.

### Faktor 2: Nutzeridentität

Der Resource Server übergibt den Identifier aus dem `zeta-user-info` Header (KVNR eines Versicherten):

```http
GET /zeta/email?id=47114541
```
### Faktor 3: Fachliche Verwendung vorgesehen

Der Guard speichert je Kombination aus Identität und Resource Server:

```json
{
  "identifier": "4711",
  "rs_id": "fd-arztportal",
  "email": "max.mustermann@example.de",
  "email_business_use_intended": true
}
```

Die Kennzeichnung, ob eine fachliche Verwendung vorgesehen ist, wird durch `email_business_use_intended` repräsentiert.
Nur wenn dieser Wert `true` ist, darf die E-Mail zurückgegeben werden.
Dies ist keine Einwilligung des Nutzers, sondern eine technische Kennzeichnung des Fachdienstes, dass er die E-Mail fachlich verwendet.

# 4. Datenmodell

## Datenspeicherung

```text
(identifier, rs-id)
            -> email
            -> email_business_use_intended
```

Damit ist die Kennzeichnung strikt fachdienstbezogen. Die Einwilligung des Nutzers zur Weitergabe der E-Mail wird hier nicht gespeichert; sie ist Sache der Fachanwendung.


# 5. E-Mail-Endpunkt

## Endpoint

```http
GET /zeta/email?id=<identifier>
```

Die RS-Identität wird ausschließlich aus dem mTLS-Zertifikat bestimmt.

## Erfolgsantwort

```json
{
  "email": "max.mustermann@example.de"
}
```

## Fehlercodes

- 401: Kein gültiges mTLS-Zertifikat
- 403: Resource Server nicht berechtigt
- 404: Fachliche Verwendung nicht vorgesehen, keine E-Mail oder kein Datensatz
- 429: Rate Limiting
- 500: Technischer Fehler

# 6. Prüfablauf im Guard

```text
1. mTLS prüfen
2. RS-ID aus Zertifikat bestimmen
3. identifier validieren
4. Datensatz für (identifier, rs-id) laden
5. Datensatz vorhanden?
     nein -> 404
6. email_business_use_intended == true?
     nein -> 404
7. E-Mail vorhanden?
     nein -> 404
8. E-Mail zurückgeben
```

# 8. Datenschutzbewertung

## Datenminimierung

Die E-Mail wird ausschließlich bei Bedarf übertragen.

## Zweckbindung

Die E-Mail wird nur weitergegeben, wenn der Fachdienst für die Kombination aus Identität und Resource Server signalisiert hat, dass eine fachliche Verwendung vorgesehen ist. Die Einwilligung des Nutzers zur Verarbeitung der E-Mail durch den Fachdienst ist nicht Gegenstand dieser Prüfung und liegt in der Verantwortung der Fachanwendung.

## Änderbarkeit des Verwendungs-Flags

Die Kennzeichnung `email_business_use_intended` kann jederzeit durch die Fachanwendung aktualisiert werden und wirkt bei der nächsten Abfrage unmittelbar.

## Kein PII im Token

Die E-Mail erscheint weder im Access Token noch im ID Token noch im `zeta-user-info` Header.

## Audit

Zu protokollieren sind:
- Änderung der Kennzeichnung `email_business_use_intended`
- Abruf

Ohne Speicherung der E-Mail im Klartext innerhalb von Audit-Daten.


# 9. Spezifikationsanpassungen

## A_NEU_E03 — Pull-Endpunkt am ZETA Guard

Der ZETA Guard MUSS einen mTLS-gesicherten Endpunkt `GET /zeta/email` bereitstellen.

Der Endpunkt MUSS eine Anfrage ausschließlich beantworten, wenn:

- der Resource Server mittels mTLS authentisiert wurde,
- der Resource Server berechtigt ist, Informationen für die angefragte Identität abzurufen,
- für die Kombination aus Identität und Resource Server die Kennzeichnung `email_business_use_intended` gesetzt ist.

Fehlende Kennzeichnung und fehlende Daten MÜSSEN identisch mit HTTP 404 beantwortet werden.

Die Einholung und Verwaltung einer Einwilligung des Nutzers zur Weitergabe seiner E-Mail-Adresse ist NICHT Aufgabe des ZETA Guard, sondern der Fachanwendung.

## A_NEU_E02 — Speicherung der Kennzeichnung zur fachlichen Verwendung der E-Mail (Kap. 5.4.3)

Das Clientsystem MUSS selbst sicherstellen, dass eine etwaig erforderliche Einwilligung des Nutzers zur fachlichen Verwendung seiner E-Mail-Adresse vorliegt, bevor es die Kennzeichnung setzt. Der ZETA Guard prüft dies nicht.

Der ZETA Guard MUSS mindestens folgende Informationen je Kombination aus Identität und Resource Server speichern:

- email
- email_business_use_intended

Eine Aktualisierung der Kennzeichnung MUSS möglich sein und spätestens bei der nächsten Abfrage wirksam werden.

## Datenschutz-Verankerung (Kap. 5.1)

Die Weitergabe der E-Mail erfolgt ausschließlich zweckgebunden, fachdienstbezogen und nur auf Anfrage, sofern eine fachliche Verwendung vorgesehen ist. Die Einwilligung des Nutzers zur Verarbeitung der E-Mail durch den Fachdienst wird von der Fachanwendung eingeholt und verwaltet.

Die E-Mail als Sicherheitsfaktor (F1) und die fachlich weitergegebene E-Mail sind inhaltlich identisch aber zweckgetrennt.

## Übermittlung und minimale Speicherung 

Der ZETA Guard speichert je Kombination aus Identität und Resource Server:

- E-Mail-Adresse
- Kennzeichnung, ob eine fachliche Verwendung vorgesehen ist (`email_business_use_intended`)

Die Übermittlung erfolgt im Rahmen der bestehenden Registrierungs- bzw. Aktualisierungsoperationen.

Separate Endpunkte hierfür sind nicht erforderlich.

## GitHub-Datei-Änderungen (Workspace)

#### Neu

`src/openapi/zeta-guard-email-endpoint.yaml`

```yaml
openapi: 3.1.0

info:
  title: ZETA Guard - Email API
  version: 1.0.0
  description: |
    Server-to-server endpoint for retrieving the email address
    of a user, provided the resource server has indicated that
    a business use of the email is intended.

    The email address is never transported in access tokens,
    ID tokens or the zeta-user-info header.

    The Resource Server authenticates via mutual TLS.
    The Resource Server identity is derived exclusively from
    the presented client certificate.

    Consent management for processing the email address is the
    sole responsibility of the client application; the ZETA
    Guard does not check or store consent.

servers:
  - url: "{protocol}://{hostname}{basePath}"
    variables:
      protocol:
        enum:
          - https
        default: https
      hostname:
        default: localhost:8443
      basePath:
        default: /zeta

security:
  - mtls: []

paths:
  /email:
    get:
      operationId: getEmail

      tags:
        - Email

      summary: Retrieve user's email address

      description: |
        Returns the email address associated with the given identity.

        The ZETA Guard returns the email address only if

          1. the Resource Server is authenticated via mTLS,
          2. the Resource Server is authorized for the identity,
          3. a business use of the email is flagged as intended
             (`email_business_use_intended`),
          4. an email address is stored.

        Missing flag and missing email are reported
        identically as HTTP 404.

      parameters:
        - name: id
          in: query
          required: true
          description: |
            User identifier obtained from the zeta-user-info
            header.
          schema:
            type: string
            minLength: 1

      responses:
        "200":
          description: Email address available.
          content:
            application/json:
              schema:
                $ref: "../schemas/email-response.yaml"
              examples:
                success:
                  value:
                    email: "vorname.nachname@example.org"

        "401":
          $ref: "#/components/responses/Unauthorized"

        "403":
          $ref: "#/components/responses/Forbidden"

        "404":
          description: |
            No stored email address or
            business use not flagged as intended.

        "429":
          $ref: "#/components/responses/RateLimited"

        "500":
          $ref: "#/components/responses/InternalServerError"

components:

  securitySchemes:
    mtls:
      type: mutualTLS
      description: |
        Mutual TLS authentication of the Resource Server.

  responses:

    Unauthorized:
      description: Missing or invalid client certificate.
      content:
        application/json:
          schema:
            $ref: "../schemas/zeta-error.yaml"

    Forbidden:
      description: Resource Server is not authorized.
      content:
        application/json:
          schema:
            $ref: "../schemas/zeta-error.yaml"

    RateLimited:
      description: Too many requests.
      content:
        application/json:
          schema:
            $ref: "../schemas/zeta-error.yaml"

    InternalServerError:
      description: Unexpected server error.
      content:
        application/json:
          schema:
            $ref: "../schemas/zeta-error.yaml"
```

`src/schemas/email-response.yaml`

```yaml
$schema: "http://json-schema.org/draft-07/schema#"

schemaVersion: "1.0.0"

title: ZETA Email Response

description: >
  Response returned by GET /zeta/email.

  The response is returned only if

    - a matching identity exists,
    - a business use of the email is flagged as intended,
    - an email address is stored.

type: object

additionalProperties: false

properties:

  email:
    type: string
    format: email
    description: >
      Email address of the user, forwarded to the Resource
      Server for business use.

required:
  - email
```

### Ändern

- `src/openapi/zeta-guard-client-management.yaml`
  - Erweiterung bestehender Registrierungs- oder Update-Operationen um:
    - `email`
    - `email_business_use_intended`


### Email OpenAPI

Der Endpunkt enthält nur noch:

```yaml
parameters:
  - name: id
    in: query
    required: true
```

Die RS-Identität wird ausschließlich aus dem mTLS-Zertifikat abgeleitet.

## 10. Fehler- und Grenzfälle

- Fachliche Verwendung nicht vorgesehen oder kein Wert → 404
- Aktualisierung der Kennzeichnung wirkt sofort
- Fremdabfrage eines nicht berechtigten Resource Servers → 403
- E-Mail niemals loggen oder persistent speichern
