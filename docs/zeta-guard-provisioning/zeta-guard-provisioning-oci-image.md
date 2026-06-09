# ZETA Guard Provisioning OCI-Image erstellen und in die Artifact Registry hochladen

## Zielsetzung

Dieses Dokument beschreibt den Prozess zur Erstellung eines minimalen, reinen OCI-Daten-Images für das ZETA Guard Provisioning. Das Ziel ist es, einen Container zu bauen, der ausschließlich Provisionierungsdaten enthält, ohne ein Basisbetriebssystem (`from scratch`).

Dieser Ansatz bietet maximale Sicherheit (minimale Angriffsfläche) und Effizienz (minimale Größe). Wichtige Metadaten wie die Git-Revision und ein Datei-Manifest werden automatisch hinzugefügt, um Versionierung und Integrität zu gewährleisten.

Der gesamte Prozess wird durch das Skript `zg-provisioning-image.sh` automatisiert.

## Voraussetzungen

Bevor Sie beginnen, stellen Sie sicher, dass die folgenden Werkzeuge auf Ihrem System installiert und konfiguriert sind:

1.  **Buildah:** Das primäre Werkzeug zum Bauen von OCI-Images.
2.  **Google Cloud CLI (`gcloud`):** Muss installiert und für den Zugriff auf Ihr GCP-Projekt authentifiziert sein (`gcloud auth login`).
3.  **Git:** Wird benötigt, um die Commit-Revision aus dem Datenverzeichnis zu ermitteln.
4.  **Das Skript:** Die Datei `zg-provisioning-image.sh` muss vorhanden und ausführbar sein.

---

## Der Prozess im Detail

Das Skript `zg-provisioning-image.sh` führt die folgenden Schritte automatisiert aus:

### Schritt 1: Vorbereitung & Authentifizierung

Zunächst bereitet das Skript die Umgebung vor und stellt eine sichere Verbindung zur Google Artifact Registry her.

*   **Temporäres Verzeichnis:** Es wird ein temporäres "Staging"-Verzeichnis erstellt. Alle Operationen finden hier statt, um Ihr ursprüngliches Datenverzeichnis sauber zu halten. Dieses Verzeichnis wird am Ende automatisch gelöscht.
*   **Sichere Authentifizierung:** Das Skript ruft ein kurzlebiges Zugriffstoken von der `gcloud`-CLI ab. Dieses Token wird sicher via `stdin` an den `buildah login`-Befehl übergeben. Dadurch werden keine Passwörter oder Tokens auf der Festplatte gespeichert.

### Schritt 2: Sammeln von Metadaten

Um die Nachverfolgbarkeit und Integrität der Daten sicherzustellen, werden zwei wichtige Metadaten-Dateien automatisch generiert und dem Image hinzugefügt:

1.  **Git-Revision (`.revision`):**
    *   **Was:** Der vollständige SHA-Commit-Hash der `HEAD`-Position aus dem Datenverzeichnis wird ermittelt.
    *   **Warum:** Dies ermöglicht es, jederzeit exakt nachzuvollziehen, welcher Stand des Git-Repositorys für den Bau dieses Images verwendet wurde. Die Revision wird in die Datei `.revision` geschrieben.

2.  **Datei-Manifest (`.manifest`):**
    *   **Was:** Das Skript berechnet die SHA256-Prüfsumme für jede einzelne Datei, die dem Image hinzugefügt wird.
    *   **Warum:** Diese Liste dient als "Inhaltsverzeichnis" und ermöglicht es dem konsumierenden Prozess (z.B. dem Kubernetes-CronJob), die Integrität der Dateien nach dem Auspacken zu überprüfen.

### Schritt 3: Der eigentliche Image-Bau

Dies ist der Kern des Prozesses, bei dem `buildah` das OCI-Image konstruiert.

*   **`buildah from scratch`:** Es wird ein absolut leerer Arbeitscontainer ohne jegliches Basisbetriebssystem erstellt. Das finale Image enthält nur die Bytes Ihrer Daten und eine minimale Konfigurations-JSON.
*   **`buildah copy`:** Der gesamte Inhalt des Staging-Verzeichnisses (Ihre Daten plus die generierten `.revision`- und `.manifest`-Dateien) wird in das Wurzelverzeichnis des Containers kopiert.
*   **`buildah config`:** Metadaten wie der Autor und die Git-Revision als `Label` werden in die Image-Konfiguration geschrieben.
*   **`buildah commit`:** Der Zustand des Arbeitscontainers wird als neues, lokales OCI-Image finalisiert.

### Schritt 4: Veröffentlichung in der Registry

Im letzten Schritt wird das lokal erstellte Image in die Google Artifact Registry hochgeladen.

*   **`buildah push`:** Das Image wird sicher und effizient in das in der Befehlszeile angegebene Repository gepusht. Danach ist es für Kubernetes und andere Dienste verfügbar.

---

## Verwendung des Skripts `zg-provisioning-image.sh`

### 1. Vorbereitung

**a) Skript speichern und ausführbar machen:**
Speichern Sie das bereitgestellte Skript unter dem Namen `zg-provisioning-image.sh` und geben Sie ihm Ausführungsrechte:
```bash
chmod +x zg-provisioning-image.sh
```

**b) Datenverzeichnis vorbereiten:**
Stellen Sie sicher, dass Ihr Datenverzeichnis (idealerweise ein Git-Repository) alle benötigten Dateien enthält.

**Beispiel-Struktur:**
```
.
├── zeta-guard-provisioning/   # Dies ist das Datenverzeichnis
│   ├── TrustedTPM.cab
│   ├── tsl.xml
│   ├── roots.json
│   ├── apple-root-ca.pem
│   ├── opa-bundle-sig-key.pem
│   └── .git/               # Ist ein Git-Repo
│
└── zg-provisioning-image.sh  # Hier liegt Ihr Skript
```

### 2. Ausführung

Rufen Sie das Skript mit den erforderlichen Parametern auf.

**Syntax:**
```bash
./zg-provisioning-image.sh <imagename:tag> [daten_verzeichnis]
```

*   **`<imagename:tag>` (Pflicht):** Der vollständige Pfad zu Ihrem Image in der Artifact Registry, beginnend nach `...pkg.dev/`.
*   **`[daten_verzeichnis]` (Optional):** Der Pfad zu dem Verzeichnis mit den Daten. Wenn Sie diesen Parameter weglassen, wird das aktuelle Verzeichnis (`.`) verwendet.

**Konkretes Beispiel:**

```bash
# Baut ein Image aus dem Verzeichnis './zeta-guard-provisioning' und taggt es mit latest
./zg-provisioning-image.sh gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:latest ./zeta-guard-provisioning
```

### 3. Erwartete Ausgabe

Eine erfolgreiche Ausführung des Skripts erzeugt eine Ausgabe, die jeden Schritt protokolliert und am Ende eine Erfolgsmeldung anzeigt:
```
--- 1. Authentifizierung bei GCP ---
Login Succeeded!
--- 2. Metadaten vorbereiten ---
Daten werden aus Verzeichnis kopiert: ./my-provisioning-data
Git Revision: a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2
Erstelle .manifest Datei...
--- 3. Buildah Image-Bau (from scratch) ---
Temporärer Container erstellt: working-container-1
Daten und Metadaten in den Container kopiert.
Image-Metadaten gesetzt.
Image committed. Lokale ID: sha256:ffeeddcc...
Temporärer Container gelöscht.
--- 4. Buildah Push ---
Getting image source signatures
Copying blob sha256:aabbcc... done
Copying config sha256:ffeeddcc... done
Writing manifest to image destination
Storing signatures
----------------------------------------------------
Erfolg! Daten-Image wurde gebaut und gepusht.
Registry-Pfad: europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:v1.2.3
Image Digest: sha256:ffeeddcc...
----------------------------------------------------
So kannst du das Image inspizieren:

  skopeo inspect docker://europe-west3-docker.pkg.dev/...
  buildah mount $(buildah from europe-west3-docker.pkg.dev/...)
----------------------------------------------------
--- Aufräumen: Temporäres Verzeichnis wird gelöscht ---
```

Das resultierende Image ist nun in Ihrer Artifact Registry verfügbar und kann, wie im vorherigen Leitfaden beschrieben, vom Kubernetes-CronJob zur Provisionierung des Clusters verwendet werden.