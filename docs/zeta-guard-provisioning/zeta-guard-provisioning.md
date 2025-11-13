# ZETA Guard - Dynamische Konfigurations-Provisionierung in Kubernetes mit CronJob und Shared Volumes

Dieses Dokument beschreibt eine robuste Architektur zur regelmäßigen Verteilung von Konfigurationsdaten (z.B. öffentliche Schlüssel, Zertifikate, Endpunkt-URLs) aus einem OCI-Container an mehrere Anwendungen (wie Nginx, Keycloak, OPA) in einem Kubernetes-Cluster.

**Ziel:** Eine automatisierte, sichere und skalierbare Methode zur Aktualisierung von Konfigurationsdaten, die aufgrund ihrer Größe (> 1 MiB) nicht für `ConfigMaps` geeignet sind.

## Kernkonzepte der Architektur

1. **OCI-Datencontainer (`zeta-guard-provisioning`):** Ein minimales Container-Image, das ausschließlich die benötigten Konfigurationsdateien enthält. Es hat keine laufende Anwendung.
2. **`PersistentVolumeClaim` (PVC):** Ein zentraler, wiederbeschreibbarer Speicherort im Cluster, der als Brücke zwischen dem Provisionierer und den Anwendungen dient.
3. **`CronJob`:** Ein Kubernetes-Objekt, das nach einem Zeitplan einen Job startet. Dieser Job führt unser OCI-Datencontainer aus, um die Daten im PVC zu aktualisieren.
4. **`volumeMounts`:** Die Anwendungen (Nginx, Keycloak, OPA) binden das PVC als schreibgeschütztes Volume in ihr Dateisystem ein, um auf die Daten zuzugreifen.
5. **Reload-Mechanismen:** Strategien, um die Anwendungen dazu zu bringen, die aktualisierten Daten zu erkennen und zu laden, idealerweise ohne einen Neustart.

*(Textuelle Beschreibung des Flows)*
`CronJob` → startet `Provisioner-Pod` → schreibt in `PersistentVolume` → `Nginx/Keycloak/OPA Pods` lesen aus `PersistentVolume`.

---

## Schritt 1: Erstellen des gemeinsamen Speichers (PVC)

Zuerst fordern wir ein persistentes Volume an, das als zentraler Speicher für unsere Daten dient.

**`provisioning-data-pvc.yaml`**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: provisioning-data-pvc
spec:
  # ReadWriteOnce erlaubt es dem CronJob-Pod, exklusiv in das Volume zu schreiben.
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      # Passen Sie die Größe an Ihre Datenmenge an (plus Puffer).
      storage: 1Gi
```

**Anwendung:**

```bash
kubectl apply -f provisioning-data-pvc.yaml
```

---

## Schritt 2: Einrichten des regelmäßigen Provisionierungs-Jobs (CronJob)

Dieser `CronJob` startet periodisch einen Pod, der das Provisionierungs-Image verwendet, um den Inhalt des PVC zu aktualisieren.

**`provisioning-cronjob.yaml`**

```yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: data-provisioner-cronjob
spec:
  # Führt den Job täglich um 2 Uhr nachts aus. Anpassen nach Bedarf.
  # Beispiel für alle 6 Stunden: "0 */6 * * *"
  schedule: "0 2 * * *"
  
  # Verhindert, dass sich Jobs überschneiden.
  concurrencyPolicy: Forbid

  jobTemplate:
    spec:
      template:
        spec:
          restartPolicy: OnFailure
          containers:
          - name: data-provisioner
            image: europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:test-latest
            # Dieser Befehl kopiert die Daten sicher in das Volume.
            command: ["/bin/sh", "-c", "cp -r /zeta-guard-provisioning/. /data-output/"]
            volumeMounts:
            - name: provisioned-data-storage
              mountPath: /data-output/ # Schreib-Zugriff für den Provisionierer
          volumes:
          - name: provisioned-data-storage
            persistentVolumeClaim:
              claimName: provisioning-data-pvc
          # Secret für den Zugriff auf Ihre private Artifact Registry
          imagePullSecrets:
          - name: gcr-json-key
```

**Anwendung:**

```bash
kubectl apply -f provisioning-cronjob.yaml
```

---

## Schritt 3: Bereitstellen der Daten für die Anwendungen

Nun passen Sie die Deployments von Nginx, Keycloak und OPA an, damit sie das Volume einbinden.

Fügen Sie die folgenden `volumes` und `volumeMounts` Abschnitte zur Pod-Spezifikation (`spec.template.spec`) jedes Deployments hinzu.

**Beispiel für das Nginx-Deployment:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-deployment
spec:
  # ... replicas, selector, etc.
  template:
    spec:
      containers:
      - name: nginx
        image: nginx:latest
        # ... ports, etc.
        volumeMounts:
        - name: provisioned-data-storage
          # Der Pfad, unter dem Nginx die Daten erwartet
          mountPath: /etc/nginx/provisioning-data
          # WICHTIG: Nur-Lese-Zugriff für die Anwendung
          readOnly: true
      
      # Gemeinsame Volume-Definition für alle Container im Pod
      volumes:
      - name: provisioned-data-storage
        persistentVolumeClaim:
          claimName: provisioning-data-pvc
```

**Anweisungen für andere Deployments:**

* **Keycloak:** Fügen Sie die identischen `volumes` und `volumeMounts` Blöcke hinzu. Passen Sie den `mountPath` an den Ort an, an dem Keycloak die Zertifikate oder Schlüssel erwartet (z.B. `/opt/keycloak/conf/certs`).
* **OPA:** Fügen Sie die identischen `volumes` und `volumeMounts` Blöcke hinzu. Der `mountPath` könnte z.B. `/etc/opa/policies` sein, wenn Sie Richtlinien oder Datenbündel bereitstellen.

---

## Schritt 4: Umgang mit Updates – Pod-Neustarts vermeiden

Eine Anwendung liest ihre Konfiguration typischerweise nur beim Start. Wenn der `CronJob` die Dateien im Volume aktualisiert, müssen die laufenden Anwendungen darüber informiert werden.

### Option A: Der kontrollierte Neustart (Fallback-Lösung)

Die einfachste Methode ist, ein "Rolling Restart" der Deployments auszulösen, nachdem der `CronJob` gelaufen ist. Kubernetes tauscht dann die Pods kontrolliert aus, sodass keine komplette Downtime entsteht.

**Implementierung:**
Ein weiterer `CronJob`, der kurz nach dem Provisionierer läuft, könnte dies tun:

```bash
kubectl rollout restart deployment/nginx-deployment
kubectl rollout restart deployment/keycloak-deployment
# ... usw.
```

* **Vorteile:** Universell, funktioniert mit jeder Anwendung.
* **Nachteile:** Führt zu kurzen Unterbrechungen für einzelne Verbindungen, nicht "Zero Downtime".

### Option B: Dynamisches Neuladen der Konfiguration (Bevorzugte Lösung)

Diese Methode ist eleganter und vermeidet Neustarts, erfordert aber, dass die Anwendung "Hot Reloads" unterstützt.

#### Für Nginx: Sidecar Reloader

Nginx kann seine Konfiguration über ein `SIGHUP`-Signal ohne Unterbrechung neu laden. Ein kleiner "Sidecar"-Container im selben Pod kann die Dateien überwachen und dieses Signal senden.

**Ergänzung für das Nginx-Deployment:**

```yaml
# In spec.template.spec:
shareProcessNamespace: true # Erlaubt dem Sidecar, den Nginx-Prozess zu sehen

# In spec.template.spec.containers:
# ... (Nginx Container von oben) ...
- name: reloader-sidecar
  image: busybox:stable # Minimales Image
  command: ["/bin/sh", "-c"]
  args:
  - |
    # Endlosschleife zur Überwachung
    while true; do
      # Wartet auf Dateiänderungen (modify, create, delete)
      inotifyd -s modify,create,delete,move /data-watch
      echo "Änderung erkannt, sende SIGHUP an Nginx (PID 1)..."
      kill -HUP 1
      sleep 5 # Kurze Pause
    done
  volumeMounts:
  - name: provisioned-data-storage
    mountPath: /data-watch/
    readOnly: true
```

#### Für OPA: Natives Bundle-Loading

OPA ist darauf ausgelegt, Richtlinien und Daten aus verschiedenen Quellen, einschließlich des Dateisystems, dynamisch zu laden. Ein Sidecar ist oft nicht nötig.

**Konfiguration im OPA-Deployment (Beispiel):**

```yaml
# In spec.template.spec.containers:
- name: opa
  image: openpolicyagent/opa:latest
  args:
    - "run"
    - "--server"
    - "--config-file=/config/opa-config.yaml"
  volumeMounts:
    - name: provisioned-data-storage
      mountPath: /etc/opa/bundles
      readOnly: true
    # ... andere Mounts
```**`opa-config.yaml` (in einer ConfigMap):**
```yaml
services:
  - name: my_service
    url: https://...

bundles:
  authz:
    # OPA wird dieses Verzeichnis überwachen und bei Änderungen neu laden
    resource: file:///etc/opa/bundles/bundle.tar.gz
```

#### Für Keycloak: Herausforderung und Lösungsansätze

Keycloak und viele Java-Anwendungen haben keinen einfachen, signal-basierten Reload-Mechanismus wie Nginx.

1. **Dokumentation prüfen:** Überprüfen Sie, ob Ihre Keycloak-Version oder installierte Plugins eine Funktion zur Überwachung von Konfigurationsdateien bieten.
2. **JMX / Admin API:** Manche Anwendungen bieten eine API, über die ein Reload ausgelöst werden kann. Ein Sidecar könnte `curl` verwenden, um diesen Endpunkt aufzurufen.
3. **Fallback auf Neustart:** Wenn keine der obigen Optionen möglich ist, ist der kontrollierte Neustart (Option A) für Keycloak die pragmatischste und zuverlässigste Lösung.
