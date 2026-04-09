# Wie sie Ressourcen für ZETA-Guard-Pods verwalten

Der `zeta-Guard`-Chart
unterstützt [Kubernetes Syntax für Resource-Requests und -Limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
Die Requests/Limits werden auf Container- und Pod-Ebene angewandt.
(Ressourcen-Management auf Pod-Ebene erfordert Kubernetes v1.34 oder neuer.)
Hier ist eine Beispielkonfiguration, die die Speicher-Limits aller Kernkomponenten
des Charts überschreibt.

```yaml
authserver:
    resources:
        limits:
            memory: 1Gi
opa:
    resources:
        limits:
            memory: 1Gi
    workloadIdentityFederation:
        worker:
            resources:
                limits:
                    memory: 1Gi
pepproxy:
    resources:
        limits:
            memory: 1Gi
telemetry-gateway:
    resources:
        limits:
            memory: 1Gi
```

Bitte beachten Sie, dass die Limits in diesem Beispiel – `1GI` – **nicht** als
Empfehlung für den Betrieb gewählt wurden.
