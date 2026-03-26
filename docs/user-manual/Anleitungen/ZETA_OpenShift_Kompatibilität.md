## ZETA OpenShift-Kompatibilität – notwendige Anpassungen

Um ZETA-Guard auf OpenShift 4.x zu betreiben, sind folgende Konfigurationsänderungen erforderlich:

1. **OpenShift Route aktivieren:**
   Setzen von `openshiftRoute.enabled` auf `true` und konfigurieren der Route-Parameter in der entsprechenden Values-Datei, um [openshift-route.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/templates/openshift-route.yaml) zu aktivieren.
   ```yaml
   openshiftRoute:
     enabled: true
     host: zeta-guard.example.com
     issuer:
       issuerName: issuerName
       secretName: secretName
   ```

2. **NGINX Ingress deaktivieren:**
   `nginx-ingress` muss auf `false` gesetzt werden, um Konflikte mit dem nativen Routing von OpenShift zu vermeiden.

3. **Test-Monitoring und Log Collector deaktivieren:**
   Sowohl `testMonitoringServiceEnabled` als auch `logCollectorEnabled` auf `false` setzen, da diese Komponenten mit der Standard Pod Security in OpenShift nicht unterstützt werden.

4. **Feste User-IDs aus Security Contexts entfernen:**
   `runAsUser: 1000`-Angaben aus sämtlichen `securityContext`-Blöcken (`initContainerSecurityContext`, `containerSecurityContext`, `securityContext`) entfernen.
   OpenShift weist User-IDs dynamisch pro Namespace/Projekt zu.
