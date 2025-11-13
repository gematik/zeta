# ZETA Guard Provisioning OCI-Image erstellen und in die Artifact Registry hochladen

Dieser Leitfaden beschreibt den schrittweisen Prozess, um aus einem lokalen Verzeichnis ein OCI-konformes Container-Image zu erstellen, es zu konfigurieren und anschließend in eine private Google Cloud Artifact Registry hochzuladen.

## Voraussetzungen

* `buildah` ist auf Ihrem System installiert.
* Die `gcloud` CLI ist installiert und für Ihr Projekt konfiguriert.
* Sie befinden sich im Arbeitsverzeichnis (`~/dev/zeta/examples`), das ein Unterverzeichnis mit den zu verpackenden Daten (`./zeta-guard-provisioning`) enthält.

---

## Schritt 1: Authentifizierung bei der Google Cloud

Bevor Sie mit der Google Cloud interagieren können, müssen Sie sich authentifizieren. Dieser Schritt öffnet einen Browser zur Anmeldung.

```bash
gcloud auth login
```

Navigieren Sie anschließend in Ihr Arbeitsverzeichnis.

```bash
cd dev/zeta/examples/
```

## Schritt 2: OCI-Container-Image erstellen

In diesem Schritt wird das Image von Grund auf mit `buildah` erstellt.

### 2.1. Arbeitscontainer aus einem Basis-Image erstellen**

Wir verwenden `busybox:stable` als minimales Basis-Image, das grundlegende Shell-Werkzeuge enthält. Der Name des temporären Arbeitscontainers wird in einer Variable gespeichert.

```bash
new_container=$(buildah from busybox:stable)
```

Sie können den Namen des Arbeitscontainers überprüfen:

```bash
echo $new_container
# Beispiel-Ausgabe: working-container-1
```

### 2.2. Daten in den Container kopieren

Kopieren Sie den Inhalt des lokalen Verzeichnisses `./zeta-guard-provisioning` in ein gleichnamiges Verzeichnis innerhalb des Containers.

```bash
buildah copy $new_container ./zeta-guard-provisioning ./zeta-guard-provisioning
```

### 2.3. Image-Metadaten konfigurieren

Legen Sie Metadaten für das Image fest, wie den Standardbefehl und den Autor. Der Befehl `/bin/true` sorgt dafür, dass der Container bei einem direkten Start sofort erfolgreich beendet wird, was für reine Datencontainer sinnvoll ist.

```bash
# Setzt den Standardbefehl, der beim Start ausgeführt wird
buildah config --cmd "/bin/true" $new_container

# Setzt den Autor des Images
buildah config --author "gematik" $new_container
```

### 2.4. Arbeitscontainer als Image finalisieren (Commit)

Speichern Sie die Änderungen aus dem Arbeitscontainer als neues, lokales OCI-Image.

```bash
buildah commit --format oci $new_container zeta-guard-provisioning:test-latest
```

* `--format oci`: Stellt sicher, dass das Image im OCI-Format erstellt wird.
* `zeta-guard-provisioning:test-latest`: Der Name und das Tag des neuen lokalen Images.

## Schritt 3: Lokales Image überprüfen

Listen Sie die lokal verfügbaren Buildah-Images auf, um zu bestätigen, dass die Erstellung erfolgreich war.

```bash
buildah images
```

**Beispiel-Ausgabe:**

```bash
REPOSITORY                          TAG           IMAGE ID       CREATED          SIZE
localhost/zeta-guard-provisioning   test-latest   be1f1014e66a   15 seconds ago   3.15 MB
```

## Schritt 4: Image für die Artifact Registry taggen

Um das Image in eine bestimmte Registry hochladen zu können, muss es mit dem vollständigen Pfad dieser Registry getaggt werden.

```bash
buildah tag zeta-guard-provisioning:test-latest europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:test-latest
```

* **Quelle:** `zeta-guard-provisioning:test-latest` (das gerade erstellte lokale Image)
* **Ziel:** `europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:test-latest` (der vollständige Name in Ihrer Artifact Registry)

Eine erneute Überprüfung mit `buildah images` zeigt nun beide Tags für dieselbe Image-ID an.

## Schritt 5: Image in die Google Artifact Registry hochladen (Push)

Laden Sie das getaggte Image in Ihre private Registry hoch. Buildah verwendet die zuvor durch `gcloud` eingerichtete Authentifizierung.

**Hinweis:** Falls der Push fehlschlägt, stellen Sie sicher, dass Sie Docker für die Authentifizierung bei Ihrer Registry konfiguriert haben mit:
`gcloud auth configure-docker europe-west3-docker.pkg.dev`

```bash
buildah push europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:test-latest
```

Die Ausgabe zeigt den Fortschritt des Uploads der einzelnen Layer und des Manifests an.

**Beispiel-Ausgabe bei Erfolg:**

```bash
Getting image source signatures
Copying blob 759f409aed7b done   |
Copying config ee38604b00 done   |
Writing manifest to image destination
```

---

**Ergebnis:** Das Image mit Ihren Provisionierungsdaten ist nun sicher in Ihrer Google Cloud Artifact Registry gespeichert und kann von Diensten wie Kubernetes abgerufen werden.

## Schritt 6: Image-Inhalt anzeigen

Um den Inhalt des erstellten OCI-Images anzuzeigen, können Sie den folgenden Befehl verwenden:

```bash
buildah run zeta-guard-provisioning:test-latest -- ls -lR /zeta-guard-provisioning
```

Dies listet alle Dateien und Verzeichnisse im `/zeta-guard-provisioning`-Verzeichnis des Images auf.

**Beispiel-Ausgabe:**

```bash
/zeta-guard-provisioning:
total 3088
-rwxr-xr-x    1 root     root        573768 Nov 12 09:28 ECC-RSA_TSL-test.xml
-rwxr-xr-x    1 root     root       2535847 Nov 12 09:28 TrustedTpm.cab
-rw-r--r--    1 root     root           349 Nov 13 07:35 federation-master.yaml
drwxr-xr-x    2 root     root          4096 Nov 13 13:18 policy-engine-bundle-keys
-rwxr-xr-x    1 root     root         34340 Nov 12 09:28 roots.json

/zeta-guard-provisioning/policy-engine-bundle-keys:
total 12
-r--------    1 root     root          1081 Nov 13 13:17 GEM.KOMP-CA61-TEST-ONLY.pem
-r--------    1 root     root          1028 Nov 13 13:17 GEM.RCA7-TEST-ONLY.pem
-r--------    1 root     root          1069 Nov 13 13:17 zeta_artifact_reg_nist.pem
```
