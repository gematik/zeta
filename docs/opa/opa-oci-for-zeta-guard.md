# OPA OCI Bundle-Verwaltung für ZETA Guard

ZETA Guard verwendet OPA (Open Policy Agent) zur Durchsetzung von Richtlinien für die Client-Registrierung und Autorisierung. Die Richtlinien sind in Rego geschrieben und werden als OCI-Bundles bereitgestellt.

Dieses Dokument beschreibt den Prozess zum Erstellen, Signieren, Pushen und Testen eines OPA (Open Policy Agent) OCI-Bundles unter Verwendung der `policy` CLI und der Google Cloud Platform (GCP) Artifact Registry.

---

## Inhaltsverzeichnis

- [OPA OCI Bundle-Verwaltung für ZETA Guard](#opa-oci-bundle-verwaltung-für-zeta-guard)
  - [Inhaltsverzeichnis](#inhaltsverzeichnis)
  - [Überblick](#überblick)
  - [Voraussetzungen](#voraussetzungen)
    - [Verzeichnisstruktur](#verzeichnisstruktur)
  - [Schritt-für-Schritt-Anleitung](#schritt-für-schritt-anleitung)
    - [Schritt 1: Authentifizierung bei der Google Cloud](#schritt-1-authentifizierung-bei-der-google-cloud)
    - [Schritt 2: Bei der Artifact Registry anmelden](#schritt-2-bei-der-artifact-registry-anmelden)
    - [Schritt 3: OPA OCI Bundle erstellen und signieren](#schritt-3-opa-oci-bundle-erstellen-und-signieren)
    - [Schritt 4: Lokale Images auflisten](#schritt-4-lokale-images-auflisten)
    - [Schritt 5: Bundle in die Artifact Registry pushen](#schritt-5-bundle-in-die-artifact-registry-pushen)
    - [Schritt 6: Bundle lokal als Tarball speichern (Optional)](#schritt-6-bundle-lokal-als-tarball-speichern-optional)
    - [Schritt 7: Lokales Bundle evaluieren](#schritt-7-lokales-bundle-evaluieren)
  - [Zusammenfassung der Befehle](#zusammenfassung-der-befehle)
  - [Anhang](#anhang)
    - [Beispiel `input.json` (für einen Erfolgsfall)](#beispiel-inputjson-für-einen-erfolgsfall)

## Überblick

Dieser Leitfaden führt Sie durch den gesamten Lebenszyklus eines OPA-Policy-Bundles als OCI-Artefakt. Der Prozess umfasst:

- **Authentifizierung:** Sicherer Zugriff auf Ihre GCP-Ressourcen.
- **Erstellung & Signierung:** Paketieren Ihrer Rego-Policies in ein OCI-konformes Image und dessen digitale Signierung zur Gewährleistung der Integrität.
- **Veröffentlichung:** Hochladen des signierten Bundles in eine private GCP Artifact Registry.
- **Evaluierung:** Lokales Testen der Policy mit einem Beispiel-Input.

## Voraussetzungen

Stellen Sie sicher, dass die folgenden Werkzeuge installiert und konfiguriert sind:

- **Google Cloud SDK (`gcloud`):** Für die Interaktion mit Ihrer GCP-Umgebung.
- **Policy CLI:** Ein Werkzeug zum Erstellen und Verwalten von OPA-Policies als OCI-Images.
- **OPA (Open Policy Agent):** Zum lokalen Evaluieren der Policies.
- Ein GCP-Projekt mit aktivierter **Artifact Registry API**.
- Ein privater Signierschlüssel für das Signieren des Bundles.
- Ein öffentlicher Schlüssel für die Prüfung der Signatur

### Verzeichnisstruktur

- `policies/`: Enthält alle Rego-Richtliniendateien.
- `audiences/`: Erlaubte Ziel-URLs (Audiences).
- `professions`: Erlaubte Berufs-OIDs.
- `products.json`: Erlaubte Client-Produkte und deren Versionen.
- `token.json`: Konfiguration für Token-Gültigkeitsdauern (TTL) und erlaubte Scopes.

## Schritt-für-Schritt-Anleitung

### Schritt 1: Authentifizierung bei der Google Cloud

Zuerst müssen Sie sich bei Ihrem Google Cloud-Konto anmelden und das richtige Projekt auswählen.

1. **Login:**
    Dieser Befehl öffnet ein Browserfenster zur Authentifizierung.

    ```bash
    gcloud auth login
    ```

2. **Projekt auswählen (Optional):**
    Listen Sie alle Projekte auf, auf die Sie Zugriff haben, um Ihre Projekt-ID zu überprüfen.

    ```bash
    gcloud projects list
    gcloud config set project PROJECT_ID
    ```

### Schritt 2: Bei der Artifact Registry anmelden

Um Images in die Artifact Registry zu pushen, müssen Sie sich mit einem Zugriffstoken authentifizieren.

1. **Zugriffstoken generieren:**
    Erstellen Sie ein kurzlebiges OAuth2-Zugriffstoken aus Ihren `gcloud`-Anmeldeinformationen.

    ```bash
    gcloud auth print-access-token
    <geheim>
    ```

2. **Bei der Registry anmelden:**
    Verwenden Sie das generierte Token, um sich mit der `policy` CLI bei der Artifact Registry anzumelden. Der Benutzername für diesen Anmeldetyp lautet `oauth2accesstoken`.

    ```bash
    policy login --username=oauth2accesstoken --server=europe-west3-docker.pkg.dev --password=<geheim>
    ```

### Schritt 3: OPA OCI Bundle erstellen und signieren

Dieser Befehl kompiliert die OPA-Policies im aktuellen Verzeichnis (`.`), signiert das resultierende Bundle mit Ihrem privaten Schlüssel und tagged es für die Artifact Registry.

- `--signing-key`: Pfad zu Ihrem privaten PEM-Schlüssel.
- `--signing-alg`: Der verwendete Signaturalgorithmus (hier: ES256).
- `-t`: Der Tag für das Image im Format `<region>-docker.pkg.dev/<projekt-id>/<repository-name>/<image-name>:<tag>`.

```bash
policy build . --signing-key=<private-key.pem> --signing-alg="ES256" -t europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-policies/pip-policy-example:latest

Created new image.
digest: sha256:a993a5d0a8ba8a45ed1f46c19143f68af8023e47fee35afd7144f2abb981d75d

Tagging image.
reference: europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-policies/pip-policy-example:latest
```

### Schritt 4: Lokale Images auflisten

Überprüfen Sie, ob das Image erfolgreich erstellt und lokal gespeichert wurde.

```bash
policy images

  REPOSITORY                                             TAG          IMAGE ID      CREATED               SIZE
  gematik-pt-zeta-test/zeta-policies/pip-policy-example  latest       a993a5d0a8ba  2025-11-10T10:55:34Z  911B
```

### Schritt 5: Bundle in die Artifact Registry pushen

Laden Sie das erstellte und getaggte Image in Ihre GCP Artifact Registry hoch.

```bash
policy push gematik-pt-zeta-test/zeta-policies/pip-policy-example:latest

Resolved ref [europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-policies/pip-policy-example:latest].
digest: sha256:a993a5d0a8ba8a45ed1f46c19143f68af8023e47fee35afd7144f2abb981d75d

Pushed ref [europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-policies/pip-policy-example:latest].
digest: sha256:a993a5d0a8ba8a45ed1f46c19143f68af8023e47fee35afd7144f2abb981d75d
```

### Schritt 6: Bundle lokal als Tarball speichern (Optional)

Wenn Sie das Bundle für lokale Tests als `.tar.gz`-Datei benötigen, können Sie es mit dem `save`-Befehl exportieren.

```bash
policy save gematik-pt-zeta-test/zeta-policies/pip-policy-example:latest
```

Dies erzeugt standardmäßig eine Datei namens `bundle.tar.gz` im aktuellen Verzeichnis.

Man kann sich den Inhalt anzeigen lassen mit:

```bash
tar -tf bundle.tar.gz
```

Den Inhalt einer bestimmten Datei im Bundle kann man mit:

```bash
tar -xvf bundle.tar.gz -O /opa-bundle/policies/zeta/authz.rego
```
anzeigen lassen.


### Schritt 7: Lokales Bundle evaluieren

Verwenden Sie den `opa eval`-Befehl, um Ihre Policy lokal gegen eine Beispieldaten-Datei zu testen.

- `-b bundle.tar.gz`: Gibt die zu verwendende Bundle-Datei an.
- `--input ./schemas/policy-engine-input/policy-engine-input-windows-software.json`: Der Pfad zur JSON-Datei mit den Eingabedaten für die Policy-Abfrage.
- `"data.policies.zeta.authz.decision"`: Der Rego-Pfad zur spezifischen Regel, die evaluiert werden soll.

```bash
opa eval -b bundle.tar.gz --input ./schemas/policy-engine-input/policy-engine-input-windows-software.json "data.policies.zeta.authz.decision"
```

## Zusammenfassung der Befehle

```bash
# Authentifizierung
gcloud auth login
gcloud projects list

# Bei Artifact Registry anmelden
ACCESS_TOKEN=$(gcloud auth print-access-token)
policy login --username=oauth2accesstoken --server=europe-west3-docker.pkg.dev --password=$ACCESS_TOKEN

# Bundle erstellen, signieren und pushen
REPO="europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-policies/pip-policy-example:latest"
policy build . --signing-key=/path/to/your/private-key.pem --signing-alg="ES256" -t $REPO
policy push $REPO

# Lokale Evaluierung
policy save $REPO
opa eval -b bundle.tar.gz --input /path/to/input.json "data.policies.zeta.authz.decision"
```

## Anhang

### Beispiel `input.json` (für einen Erfolgsfall)

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
