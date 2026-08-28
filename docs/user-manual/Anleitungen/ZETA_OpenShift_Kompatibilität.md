## ZETA OpenShift-Kompatibilität – notwendige Anpassungen

Um ZETA-Guard auf OpenShift 4.x zu betreiben, sind folgende Konfigurationsänderungen erforderlich:

> **Mindestversion:** Das Chart setzt mindestens Kubernetes 1.32 voraus, also **OpenShift 4.19
> oder neuer**, und erzwingt das über `kubeVersion`. Auf dieser Untergrenze setzt unter anderem
> `provisioningProcessor.schedule.enabled: true` auf, das einen Sidecar-Init-Container
> (`restartPolicy: Always`) verwendet. Die Option ist standardmäßig aktiviert und muss in
> Prod-Umgebungen aktiviert bleiben. Siehe
> [Referenz des Helm Charts](../Referenzen/Referenz_des_Helm_Charts.md#zeitgesteuerte-aktualisierung-der-vertrauensanker).

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
   `runAsUser: 1000`-Angaben aus sämtlichen `securityContext`-Blöcken (`initContainerSecurityContext`, `containerSecurityContext`, `securityContext`) entfernen.
   OpenShift weist User-IDs dynamisch pro Namespace/Projekt zu.
