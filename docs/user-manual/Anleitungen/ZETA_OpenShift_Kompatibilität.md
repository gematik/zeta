# Wie Sie ZETA-Guard auf OpenShift betreiben – notwendige Anpassungen

Um ZETA-Guard auf OpenShift 4.x zu betreiben, sind folgende Konfigurationsänderungen erforderlich:

> **Mindestversion:** Das Chart setzt mindestens Kubernetes 1.32 voraus, also **OpenShift 4.19
> oder neuer**, und erzwingt das über `kubeVersion`. Auf dieser Untergrenze setzt unter anderem
> `provisioningProcessor.schedule.enabled: true` auf, das einen Sidecar-Init-Container
> (`restartPolicy: Always`) verwendet. Die Option ist standardmäßig aktiviert und muss in
> Prod-Umgebungen aktiviert bleiben. Siehe
> [Referenz des Helm-Charts](../Referenzen/Referenz_des_Helm_Charts.md#zeitgesteuerte-aktualisierung-der-vertrauensanker).

1. **OpenShift-Ingress mit TLS aktivieren:**
   Anstelle eines separaten OpenShift-Route-Objekts wird ein Standard-Kubernetes-Ingress
   mit TLS-Konfiguration verwendet. Der OpenShift-Ingress-to-Route-Controller erzeugt
   daraus automatisch edge-terminated Routes mit TLS-Redirect.

   Folgende Values müssen gesetzt werden:
   ```yaml
   # OpenShift-Ingress-to-Route-Controller mit TLS aktivieren
   openshiftIngress:
     enabled: true
     certName: zeta-guard-tls  # Name des TLS-Secrets für die Ingress-TLS-Blöcke

   # OpenShift-eigene IngressClass verwenden
   ingressClassName: openshift-default

   # NGINX Ingress Controller deaktivieren
   nginxIngressEnabled: false

   # Ingress-Ressourcen aktiviert lassen
   ingressEnabled: true
   ```

   Das TLS-Secret (hier `zeta-guard-tls`) muss im Namespace vorhanden sein und das
   Zertifikat für den konfigurierten Hostnamen enthalten.

2. **Test-Monitoring deaktivieren:**
   `testMonitoringServiceEnabled` auf `false` setzen, da diese Komponente mit dem
   restricted-v2 Security Context Constraint (SCC) von OpenShift nicht kompatibel ist.

3. **Feste User-IDs aus Security Contexts entfernen:**
   OpenShift weist User- und Gruppen-IDs dynamisch pro Namespace/Projekt zu (Security
   Context Constraints, SCC). Fest vorgegebene IDs werden abgelehnt. Dabei sind zwei
   Fälle zu unterscheiden:

   **a) Alle Komponenten außer dem Telemetry-Gateway** (Authserver, OPA, PEP,
   Provisioning-Processor): Das Chart setzt dort von sich aus **kein** `runAsUser`.
   Sie müssen lediglich darauf achten, in Ihren eigenen Values kein `runAsUser: 1000`
   in `securityContext`, `containerSecurityContext` oder
   `initContainerSecurityContext` zu setzen — bereits vorhandene Angaben entfernen.

   **b) Das Telemetry-Gateway** ist die einzige Komponente, für die das Chart
   `securityContext.runAsUser: 1000` und `podSecurityContext.fsGroup: 1000` als
   Default mitbringt. Der Grund: Der Collector braucht eine bekannte Non-Root-Identität,
   die auf den PersistentVolumeClaim der Sending-Queue schreiben kann. Beide Werte
   müssen hier **explizit auf `null`** gesetzt werden:

   ```yaml
   telemetry-gateway:
     podSecurityContext:
       fsGroup: null      # GID wird von der SCC vergeben
     securityContext:
       runAsNonRoot: true
       runAsUser: null    # UID wird von der SCC vergeben
   ```

   > **Wichtig:** Ein bloßes **Weglassen** der Keys genügt hier nicht. Helm **merged**
   > Maps, das heißt eine Values-Datei, die `runAsUser` einfach nicht erwähnt, erbt
   > weiterhin die `1000` aus den Chart-Defaults — der Pod wird dann genauso abgelehnt
   > wie vorher. Ein explizites `null` löscht den Key ebenfalls nicht (das täte nur
   > `--set key=null`), aber der Key trägt dann einen Nil-Wert, das Manifest rendert
   > `runAsUser: null`, und Kubernetes interpretiert das als „nicht gesetzt“ — und
   > genau das erlaubt dem SCC die Vergabe.

   `fsGroup: null` ist auf OpenShift unkritisch, weil die SCC eine eigene `fsGroup`
   zuweist und das Volume damit für die vergebene UID gruppenschreibbar bleibt. Auf
   einem Cluster ohne diesen Admission-Mechanismus muss `fsGroup` gesetzt bleiben —
   ohne den Wert wird das Volume `root:root` gemountet und der Collector kann seine
   Queue nicht schreiben.

4. **StorageClass für den Telemetry-Gateway-PVC setzen:**
   Der PersistentVolumeClaim der Sending-Queue verwendet ohne weitere Angabe die
   Default-StorageClass des Clusters. Auf OpenShift Data Foundation ist das die
   RBD-Block-Klasse, die nur `ReadWriteOnce` bedienen kann. Benötigen Sie
   `ReadWriteMany`, setzen Sie die CephFS-Klasse:

   ```yaml
   telemetryGatewaySendingQueuePVCAccessModes:
     - ReadWriteMany
   telemetryGatewaySendingQueuePVCStorageClass: ocs-storagecluster-cephfs
   ```

   Kann die Default-Klasse von Ihren Nodes nicht angebunden werden, bleibt das Gateway
   dauerhaft in `ContainerCreating` (`FailedAttachVolume`). Beachten Sie, dass eine
   PVC-Spezifikation unveränderlich ist: Ein bereits mit falscher Klasse oder falschem
   AccessMode angelegter PVC muss einmalig gelöscht werden, bevor das nächste Upgrade
   ihn neu anlegt. Details siehe
   [Wie Sie ZETA-Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#4-telemetriedaten-service-opentelemetry-collector-konfigurieren).
