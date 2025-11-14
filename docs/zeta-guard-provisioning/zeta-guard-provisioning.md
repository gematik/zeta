# Automatisierte ZETA Guard Provisionierung mit CronJob, Shared Volume und Hot-Reloading

Dieser Leitfaden beschreibt, wie ein Kubernetes `CronJob` verwendet wird, um regelmäßig Konfigurationsdaten aus einem OCI-Image bereitzustellen. Dabei wird ein hybrider Ansatz verfolgt:

1. **Große Dateien (> 1 MB)** für Keycloak werden in ein `PersistentVolume` geschrieben, um die etcd-Datenbank nicht zu belasten.
2. **Kleine Konfigurationsdateien** für Nginx und OPA werden als `ConfigMaps` direkt in etcd gespeichert, um sie flexibel in Pods einbinden zu können.
3. Eine **Signaturprüfung** der kritischen Datei `TrustedTPM.cab` wird vor jeder Provisionierung durchgeführt.
4. **Sidecar-Container** werden eingesetzt, um Konfigurationsänderungen zu erkennen und bei Nginx und OPA einen **Hot-Reload ohne Pod-Neustart** auszulösen.

## Architektur-Übersicht

```bash
+---------------------------+
|                           |
|  Provisioning-Image       |
|  (mit kubectl, openssl)   |
|                           |
+-------------+-------------+
              |
              v
+-------------+-------------+      runs on schedule
|       CronJob Pod         | ---------------------->
| (mit RBAC-Berechtigungen) |
+---------------------------+
              | 1. Verifies Signature (openssl)
              |
  +-----------+-----------+
  |                       |
  v                       v
+-----------------+   +-----------------------------+
| PersistentVolume|   |   Kubernetes API (etcd)     |
| (für Keycloak)  |   | (für nginx, opa ConfigMaps) |
+-----------------+   +-----------------------------+
  ^       ^       ^
  |       |       | 2. Pods mount/use resources
  |       |       |
+---------+---------+   +---------+---------+   +---------+---------+
|  Keycloak Pod     |   |   Nginx Pod       |   |   OPA Pod         |
| (mounts PV)       |   | (mounts ConfigMap)|   | (mounts ConfigMap)|
|                   |   | + Reloader Sidecar|   | + Reloader Sidecar|
+-------------------+   +-------------------+   +-------------------+
                              ^                       ^
                              | 3. Triggers Hot-Reload|
                              +-----------------------+
```

---

## Schritt 1: Das Provisionierungs-Image erweitern

Ihr Basis-Image (`busybox`) reicht nicht mehr aus. Es muss `openssl` für die Signaturprüfung und `kubectl` zum Erstellen von ConfigMaps enthalten.

Erstellen Sie eine `Containerfile` (oder `Dockerfile`) für Ihr Image:

**`Containerfile`**

```dockerfile
# Starten Sie mit einem Basis-Image, das einen Paketmanager hat
FROM alpine:latest

# Installieren Sie die benötigten Werkzeuge
RUN apk add --no-cache openssl kubectl

# Kopieren Sie Ihre Provisionierungsdaten in das Image
COPY ./zeta-guard-provisioning /zeta-guard-provisioning
COPY ./tpm-ca-certificate.pem /certs/tpm-ca-certificate.pem

# Setzen Sie Metadaten
LABEL author="gematik"

# Standardbefehl, der nichts tut
CMD ["/bin/true"]
```

Bauen und pushen Sie dieses neue Image mit `buildah` wie zuvor. Stellen Sie sicher, dass Ihr CA-Zertifikat zur Prüfung der Signatur (`tpm-ca-certificate.pem`) ebenfalls im Image enthalten ist.

## Schritt 2: Speicher und Berechtigungen in K8s vorbereiten

### 2.1. PersistentVolumeClaim (PVC) für große Dateien

Dieser PVC stellt den wiederbeschreibbaren Speicher für die Keycloak-Daten bereit.

**`provisioning-data-pvc.yaml`**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: keycloak-provisioning-data-pvc
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi # Passen Sie die Größe an Ihre Bedürfnisse an
```

### 2.2. RBAC: Berechtigungen für den CronJob

Der CronJob benötigt die Erlaubnis, `ConfigMaps` zu erstellen und zu aktualisieren.

**`provisioner-rbac.yaml`**

```yaml
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: provisioner-sa
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: configmap-manager
rules:
- apiGroups: [""] # "" indicates the core API group
  resources: ["configmaps"]
  verbs: ["get", "list", "create", "update", "patch", "delete"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: provisioner-can-manage-configmaps
subjects:
- kind: ServiceAccount
  name: provisioner-sa
roleRef:
  kind: Role
  name: configmap-manager
  apiGroup: rbac.authorization.k8s.io
```

Wenden Sie beide Dateien an:

```bash
kubectl apply -f provisioning-data-pvc.yaml
kubectl apply -f provisioner-rbac.yaml
```

## Schritt 3: Der intelligente CronJob

Dieser `CronJob` führt die Hauptlogik aus: Signaturprüfung, Kopieren großer Dateien und Erstellen/Aktualisieren von ConfigMaps.

**`provisioning-cronjob.yaml`**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-provisioner-cronjob
spec:
  schedule: "0 * * * *" # Jede Stunde
  concurrencyPolicy: Forbid
  jobTemplate:
    spec:
      template:
        spec:
          serviceAccountName: provisioner-sa # WICHTIG: RBAC zuweisen
          restartPolicy: OnFailure
          containers:
          - name: data-provisioner
            image: <IHR-ERWEITERTES-PROVISIONING-IMAGE> # z.B. europe-west3-docker.pkg.dev/...
            command: ["/bin/sh", "-c"]
            args:
            - |
              set -e # Skript bei Fehler sofort beenden

              echo "1. Signatur von TrustedTPM.cab wird geprüft..."
              openssl cms -verify \
                -in /zeta-guard-provisioning/TrustedTPM.cab \
                -inform DER \
                -CAfile /certs/tpm-ca-certificate.pem \
                -noverify > /dev/null # -noverify, da wir nur die Signatur, nicht die Zertifikatskette prüfen

              echo "Signaturprüfung erfolgreich."

              echo "2. Große Dateien für Keycloak werden in das PV kopiert..."
              # Atomares Kopieren, um inkonsistente Zustände zu vermeiden
              cp -r /zeta-guard-provisioning/keycloak-data/. /keycloak-data-output/

              echo "3. ConfigMap für Nginx wird erstellt/aktualisiert..."
              kubectl create configmap nginx-config \
                --from-file=/zeta-guard-provisioning/nginx/nginx.conf \
                --dry-run=client -o yaml | kubectl apply -f -

              echo "4. ConfigMap für OPA wird erstellt/aktualisiert..."
              kubectl create configmap opa-policy \
                --from-file=/zeta-guard-provisioning/opa/policy.rego \
                --dry-run=client -o yaml | kubectl apply -f -
              
              echo "Provisionierung abgeschlossen."
            volumeMounts:
            - name: keycloak-data-storage
              mountPath: /keycloak-data-output
          volumes:
          - name: keycloak-data-storage
            persistentVolumeClaim:
              claimName: keycloak-provisioning-data-pvc
          imagePullSecrets:
          - name: gcr-json-key
```

## Schritt 4: Anwendungs-Deployments anpassen

### 4.1. Keycloak: Mounten des PersistentVolume

Da ein Hot-Reload bei Keycloak oft nicht trivial ist, ist hier ein geplanter Neustart (Rollout) nach der Provisionierung möglicherweise die pragmatischste Lösung.

**`keycloak-deployment.yaml` (Ausschnitt)**

```yaml
# ... spec.template.spec ...
      containers:
      - name: keycloak
        # ...
        volumeMounts:
        - name: keycloak-provisioning-data
          mountPath: /opt/keycloak/data/provisioning # Pfad, wo Keycloak die Daten erwartet
          readOnly: true
      volumes:
      - name: keycloak-provisioning-data
        persistentVolumeClaim:
          claimName: keycloak-provisioning-data-pvc
```

### 4.2. Nginx & OPA: Mounten der ConfigMap mit Reloader-Sidecar

Dies ist die fortschrittliche Methode zur Vermeidung von Neustarts.

**`nginx-deployment.yaml` (Ausschnitt)**

```yaml
# ... spec.template.spec ...
      # WICHTIG: Erlaubt dem Sidecar, den Nginx-Prozess zu signalisieren
      shareProcessNamespace: true 
      containers:
      - name: nginx
        image: nginx:latest
        volumeMounts:
        - name: config-volume
          mountPath: /etc/nginx/conf.d # Nginx liest die Konfig von hier
          readOnly: true
      - name: config-reloader
        image: alpine:latest
        command: ["/bin/sh", "-c"]
        args:
        - |
          apk add --no-cache inotify-tools
          while true; do
            # Warten auf Änderungen im gemounteten ConfigMap-Verzeichnis
            inotifywait -e modify,create,delete,move --timefmt '%d/%m/%y %H:%M' --format '%T %w%f %e' /config-watch/;
            echo "Konfigurationsänderung erkannt! Sende SIGHUP an Nginx (PID 1)."
            # Nginx Master-Prozess (PID 1) signalisieren, die Konfig neu zu laden
            kill -HUP 1
          done
        volumeMounts:
        - name: config-volume
          mountPath: /config-watch/
          readOnly: true
      volumes:
      - name: config-volume
        configMap:
          name: nginx-config
```

* **Für OPA** würden Sie ein identisches Muster anwenden. Der Sidecar müsste statt `kill -HUP 1` den entsprechenden Reload-Mechanismus von OPA aufrufen (z.B. über dessen API, falls vorhanden).

---

## Zusammenfassung der Anwendung

1. Wenden Sie die YAML-Dateien für PVC und RBAC an: `kubectl apply -f provisioning-data-pvc.yaml -f provisioner-rbac.yaml`.
2. Passen Sie die Anwendungs-Deployments (Keycloak, Nginx, OPA) mit den gezeigten `volumeMounts`, `volumes` und (wo nötig) Sidecar-Containern an.
3. Wenden Sie die `provisioning-cronjob.yaml` an.

Der CronJob wird nun stündlich die Signatur prüfen und bei Erfolg die Daten verteilen. Keycloak greift auf die großen Dateien im Volume zu, während Nginx und OPA ihre Konfigurationen ohne Neustart aus den aktualisierten ConfigMaps nachladen.
