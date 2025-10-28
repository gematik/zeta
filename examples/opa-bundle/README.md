# OPA-Richtlinien für ZETA Guard

Dieses Repository enthält die OPA (Open Policy Agent) Richtlinien und Konfigurationsdaten zur Autorisierung von Anfragen im ZETA-Ökosystem.

## Verzeichnisstruktur

-   `policies/`: Enthält alle Rego-Richtliniendateien.
-   `values/`: Enthält alle externen Daten im JSON-Format, die von den Richtlinien verwendet werden.
    -   `professions.json`: Erlaubte Berufs-OIDs.
    -   `products.json`: Erlaubte Client-Produkte und deren Versionen.
    -   `audiences.json`: Erlaubte Ziel-URLs (Audiences).
    -   `token_config.json`: Konfiguration für Token-Gültigkeitsdauern (TTL) und erlaubte Scopes.

## Voraussetzungen

-   [OPA CLI](https://www.openpolicyagent.org/docs/latest/get-started/#1-download-opa)
-   [cosign](https://docs.sigstore.dev/cosign/installation/) (optional, für das Signieren von OCI-Images)

## Anleitung

### Lokales Testen der Richtlinien

Sie können die Richtlinien lokal mit dem `opa eval` Befehl testen. Erstellen Sie eine `input.json`-Datei mit Testdaten und fragen Sie den Endpunkt `data.zeta.authz.decision` ab.

**Beispiel `input.json` (für einen Erfolgsfall):**
```json
{
  "version": "1.0",
  "client_registration_data": {
    "name": "Home-Office-PC",
    "client_id": "cid-win-sw-pqrst",
    "platform": "windows",
    "manufacturer_id": "any-vendor",
    "manufacturer_name": "Any Vendor",
    "owner_mail": "home.office@example.com",
    "registration_timestamp": 1678890000,
    "platform_product_id": {
      "store_id": "9PBLGGH4R0C9"
    }
  },
  "client_assertion": {
    "sub": "cid-win-sw-pqrst",
    "platform": "windows",
    "posture": {
      "platform_product_id": {
        "store_id": "9PBLGGH4R0C9"
      },
      "product_id": "demo_client",
      "product_version": "0.1.0",
      "os": "Windows 11 Home",
      "os_version": "10.0.22000",
      "arch": "amd64",
      "public_key": "base64-encoded-self-signed-public-key...",
      "attestation_challenge": "base64-encoded-signed-nonce-from-as..."
    },
    "attestation_timestamp": 1678890010
  },
  "user_info": {
    "identifier": "A112233445",
    "professionOID": "1.2.276.0.76.4.50"
  },
  "delegation_context": null,
  "authorization_request": {
    "scopes": [
      "openid"
    ],
    "aud": [
      "https://some-service.de/api/v1"
    ],
    "ip_address": "192.0.2.150",
    "grant_type": "authorization_code",
    "amr": [
      "pwd"
    ]
  }
}
```

Überprüfung mit dem opa Tool:

```bash
opa eval --data values/ --data policies/ --input ../schemas/policy-engine-input-windows-software.json "data.zeta.authz.decision"
```
