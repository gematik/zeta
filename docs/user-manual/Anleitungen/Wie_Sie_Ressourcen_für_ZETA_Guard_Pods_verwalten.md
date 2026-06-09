# Wie Sie Ressourcen für ZETA-Guard-Pods verwalten

Der `zeta-guard`-Chart
unterstützt [Kubernetes Syntax für Resource-Requests und -Limits](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/).
Die Requests/Limits werden auf Container-Ebene angewandt.

## Inhaltsverzeichnis

- [Authserver](#authserver)
- [Provisioning Processor](#provisioning-processor)
- [Weitere Kernkomponenten](#weitere-kernkomponenten)
- [Infinispan](#infinispan)

## Authserver

Beim Authserver können Ressourcen separat für den Hauptcontainer und den
Keycloak-Build-Init-Container konfiguriert werden:

- `authserver.initContainer.resources` — der `kc.sh build`-Schritt beim Start
- `authserver.container.resources` — der laufende Keycloak-Prozess

```yaml
zeta-guard:
    authserver:
        initContainer:
            resources:
                limits:
                    cpu: "2"
                    memory: "2Gi"
                requests:
                    cpu: "500m"
                    memory: "512Mi"
        container:
            resources:
                limits:
                    cpu: "8"
                    memory: "4Gi"
                requests:
                    cpu: "4"
                    memory: "4Gi"
```

> **Migration von 0.5.3:** Die Authserver-Container-Ressourcen wurden von
> `authserver.resources` nach `authserver.container.resources` verschoben.
> Passen Sie Ihre Values-Dateien entsprechend an.

## Provisioning Processor

Der Provisioning Processor ist ein **gemeinsamer** Init-Container, der in den
Deployments von Authserver, PEP-Proxy, OPA und OPA-Simulation läuft. Er wird
einmalig als Top-Level-Key im `zeta-guard`-Subchart konfiguriert — nicht unter
`authserver`:

```yaml
zeta-guard:
    provisioningProcessor:
        resources:
            limits:
                cpu: "1"
                memory: "200Mi"
            requests:
                cpu: "100m"
                memory: "100Mi"
```

## Weitere Kernkomponenten

```yaml
zeta-guard:
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

## Infinispan

Für Infinispan werden die Ressourcen über die globale Konfiguration gesteuert:

```yaml
global:
    infinispanExternal:
        resources:
            limits:
                cpu: "2"
                memory: "1Gi"
            requests:
                cpu: "500m"
                memory: "512Mi"
        extraJavaOptions: "-XX:MaxRAMPercentage=75.0"
```

Bitte beachten Sie, dass die Limits in den Beispielen **nicht** als
Empfehlung für den Betrieb gewählt wurden.
