# Referenz des ZETA-Guard-Helm-Charts

Hier folgt eine Referenzdokumentation der wichtigsten Values des Helm-Charts.
Sie können sie vollständige Standardkonfiguration aus dem Chart auslesen:

```shell
helm show values oci://europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-helm/zeta-guard:{TAG}
```

## Inhaltsverzeichnis

- [Globale Proxy-Konfiguration](#globale-proxy-konfiguration)
- [Ingress](#ingress)
- [Authserver](#authserver)
    - [Initiale Secrets (Genesis-Hash und SMC-B-Pepper)](#initiale-secrets-genesis-hash-und-smc-b-pepper)
    - [ServiceAccount](#serviceaccount)
    - [Replicas und PodDisruptionBudget](#replicas-und-poddisruptionbudget)
    - [Ressourcen](#ressourcen)
    - [Security Contexts](#security-contexts)
    - [Probes](#probes)
    - [Admin-API-Absicherung](#admin-api-absicherung)
    - [cert-manager-Issuer für Ingress-TLS](#cert-manager-issuer-für-ingress-tls)
    - [CloudNativePG-Datenbankverbindung](#cloudnativepg-datenbankverbindung)
    - [Connection Pooling (Keycloak)](#connection-pooling-keycloak)
    - [HSM-Konfiguration](#hsm-konfiguration)
    - [SMC-B OCSP-Sperrprüfung](#smc-b-ocsp-sperrprüfung)
    - [Spree Integrity Provider (VAU)](#spree-integrity-provider-vau)
    - [Mobiler Client-Flow (OIDC)](#mobiler-client-flow-oidc)
- [PEP-Proxy](#pep-proxy)
    - [ServiceAccount](#serviceaccount-1)
    - [Replicas und Sticky Sessions](#replicas-und-sticky-sessions)
    - [Client-IP-Ermittlung und Forwarding-Header](#client-ip-ermittlung-und-forwarding-header)
    - [Security Context](#security-context)
    - [Well-Known-Discovery-Dokument](#well-known-discovery-dokument)
    - [PoPP-Token-Validierung](#popp-token-validierung)
    - [nginx-Konfiguration (Fachdienst-Routing)](#nginx-konfiguration-fachdienst-routing)
    - [HSM-Konfiguration (TLS)](#hsm-konfiguration-tls)
    - [HSM-Konfiguration (ASL-Signaturschlüssel)](#hsm-konfiguration-asl-signaturschlüssel)
    - [Extra Volumes](#extra-volumes)
- [Infinispan](#infinispan)
    - [Verbindung (Remote-Cache)](#verbindung-remote-cache)
    - [Admin-Zugangsdaten](#admin-zugangsdaten)
    - [Image](#image)
    - [ServiceAccount](#serviceaccount-2)
    - [PodDisruptionBudget](#poddisruptionbudget)
    - [Security Contexts](#security-contexts-1)
    - [JVM-Optionen](#jvm-optionen)
    - [HSM-Konfiguration](#hsm-konfiguration-1)
- [OPA (Policy Engine)](#opa-policy-engine)
    - [Deployment und Betrieb](#deployment-und-betrieb)
    - [Logging und Telemetrie](#logging-und-telemetrie)
    - [Policy-Bundle](#policy-bundle)
    - [Signaturprüfung des Bundles](#signaturprüfung-des-bundles)
    - [Simulation-Instanz](#simulation-instanz)
    - [Workload Identity Federation (GAR-Zugriff)](#workload-identity-federation-gar-zugriff)
    - [Geplanter Rollout-Restart](#geplanter-rollout-restart)
- [Provisioning Processor](#provisioning-processor)
    - [Provisioning-Container je Umgebung](#provisioning-container-je-umgebung)
    - [Eigene Registry für den Provisioning-Container](#eigene-registry-für-den-provisioning-container)
    - [CA-Zertifikat für private Registries](#ca-zertifikat-für-private-registries)
    - [Zugangsdaten für die Provisioning-Container-Registry](#zugangsdaten-für-die-provisioning-container-registry)
    - [Cosign-Vertrauenskette für Image-Verifikation](#cosign-vertrauenskette-für-image-verifikation)
- [Notification Service](#notification-service)
- [NetworkPolicy (Egress)](#networkpolicy-egress)
- [Terraform-Konfiguration (PDP)](#terraform-konfiguration-pdp)

## Globale Proxy-Konfiguration

Alle ZETA-Guard-Komponenten können den ausgehenden HTTP/HTTPS-Verkehr über einen
Forward Proxy routen. Die Konfiguration erfolgt einmalig unter `global:`
und wird von Helm automatisch in alle Subcharts propagiert.

| Value               | Typ    | Standard | Beschreibung                                                                                                                                                  |
|---------------------|--------|----------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `global.httpProxy`  | string | `null`   | Proxy-URL für HTTP-Anfragen, z. B. `http://proxy.example.com:8080`                                                                                            |
| `global.httpsProxy` | string | `null`   | Proxy-URL für HTTPS-Anfragen. Hat Vorrang vor `httpProxy` für HTTPS-Verkehr.                                                                                  |
| `global.allProxy`   | string | `null`   | Fallback-Proxy-URL für alle Protokolle, falls kein protokollspezifischer Proxy greift.                                                                        |
| `global.noProxy`    | string | `null`   | Komma-separierte Liste von Hosts / Suffixen, die den Proxy umgehen (z. B. `.cluster.local`). Führender Punkt bedeutet bei den meisten Tools "jede Subdomain". |

```yaml
global:
    httpProxy: "http://proxy.example.com:8080"
    httpsProxy: "http://proxy.example.com:8080"
    allProxy: "http://proxy.example.com:8080"
    noProxy: ".cluster.local"
```

Für nginx (PEP) erzeugt das Chart zusätzlich `env`-Direktiven in der
`nginx.conf`. Für Keycloak (Authserver) wird `global.noProxy` automatisch in das
`-Dhttp.nonProxyHosts`-Format konvertiert (Pipe-Trenner, `*`-Wildcard statt
führendem Punkt; bis Chart 1.3.1 wurde der führende Punkt des **ersten**
Eintrags dabei nicht umgesetzt, siehe
[Wie Sie einen Forward Proxy konfigurieren](../Anleitungen/Wie_Sie_einen_Forward_Proxy_konfigurieren.md#empfehlungen-für-noproxy)). Subcharts wie `telemetry-gateway` sind upstream-Charts und
konsumieren `global` nicht — diese müssen bei Bedarf manuell konfiguriert
werden.

Eine ausführliche Beschreibung der betroffenen Komponenten, der
Konvertierungslogik, der Subchart-Konfiguration und der Überprüfung nach dem
Deployment findet sich in der Anleitung
[Wie Sie einen Forward Proxy konfigurieren](../Anleitungen/Wie_Sie_einen_Forward_Proxy_konfigurieren.md).

## Ingress

Drei Values steuern unabhängig voneinander, was das Chart im Bereich Ingress
erzeugt:

| Value                   | Beschreibung                                                                                                                                                                                                                                     | Standard |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `nginx-ingress.enabled` | Installiert den mitgelieferten F5 NGINX Ingress Controller (NIC) als Subchart. `false`, wenn der NIC clusterweit außerhalb des Charts betrieben wird.                                                                                            | `true`   |
| `nginxIngressEnabled`   | Rendert die F5-spezifischen Annotationen an den Ingress-Ressourcen (`mergeable-ingress-type`, `lb-method`, `websocket-services`, `ssl-services`, HSTS, Location-Snippets). Installiert nichts. Für fremde Ingress-Controller auf `false` setzen. | `true`   |
| `ingressEnabled`        | Erzeugt die Ingress-Ressourcen des Charts. `false` überlässt Definition und Pflege vollständig dem Betreiber.                                                                                                                                    | `true`   |

Ergänzend:

| Value                      | Beschreibung                                                                                                                                                                                                                                             | Standard  |
|----------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|
| `ingressClassName`         | `ingressClassName` der erzeugten Ingress-Ressourcen. Mit dem mitgelieferten NIC identisch mit `nginx-ingress.controller.ingressClass.name` zu halten, sonst auf die eigene Class zu setzen.                                                              | `"nginx"` |
| `nginxIngressLbMethod`     | Rendert die Cookie-basierte Sitzungsaffinität (`lb-method: hash $zeta_route consistent`) an den Minions. Setzt voraus, dass der Controller die `$zeta_route`-Snippets kennt — bei einem extern installierten NIC ohne diese Snippets auf `false` setzen. | `true`    |
| `nginxIngressHsm`          | Unterdrückt `spec.tls` der Master-Ressource, damit TLS über ein Server-Snippet in `ingressMasterAnnotations` konfiguriert werden kann (HSM-gehaltener TLS-Schlüssel über einen OpenSSL-Provider). Nur mit dem mitgelieferten NIC.                        | `false`   |
| `ingressMasterAnnotations` | Zusätzliche Annotationen an den Master-Ressourcen (öffentlicher und Admin-Hostname).                                                                                                                                                                     | `{}`      |
| `ingressMinionAnnotations` | Zusätzliche Annotationen an den Minion-Ressourcen, z. B. für das Rate Limit.                                                                                                                                                                             | `{}`      |
| `openshiftIngress.enabled` | Ergänzt die Ingress-Ressourcen um TLS-Blöcke für den OpenShift-Ingress-to-Route-Controller, siehe [OpenShift-Kompatibilität](../Anleitungen/ZETA_OpenShift_Kompatibilität.md).                                                                           | `false`   |

Ein Teil der ZETA-Guard-Funktionalität hängt an der Konfiguration des
mitgelieferten NIC — Sitzungsaffinität, WebSocket-Upgrade, das Verwerfen
client-gesetzter Forwarding-Header und die Sperre des Revocation-Endpunkts nach
außen. Welche dieser Einstellungen bei einem fremden Ingress-Controller
nachzubilden sind und welche entfallen können, beschreibt
[Wie Sie einen eigenen Ingress-Controller verwenden](../Anleitungen/Wie_Sie_einen_eigenen_Ingress_Controller_verwenden.md).

## Authserver

### Initiale Secrets (Genesis-Hash und SMC-B-Pepper)

Zwei Geheimnisse müssen beim **ersten** `helm install` gesetzt werden; fehlen
sie, bricht das Rendering mit einer `required`-Fehlermeldung ab:

```yaml
authserver:
    # 64-stelliger Hex-String, z. B. $(openssl rand -hex 32)
    genesisHash: "4841c2142fef441daa6ee6c57db65c011935964b14e94a6c8f5ec0447b83526c"
    # UUID, z. B. $(uuidgen)
    smcbHashingPepper: "085c1245-1234-5678-95b4-97496bec6182"
```

Das Chart legt daraus die Secrets `genesis-hash` (Key `hash`) und
`smcb-hashing-pepper` (Key `pepper`) an und reicht sie als `GENESIS_HASH` bzw.
`SMCB_HASHING_PEPPER` in den Authserver-Pod — siehe
[Konfiguration des PDP Services](Konfiguration_des_PDP_Services.md).

Bei **Upgrades** bleiben beide Values leer: Das Chart liest das bestehende
Secret per `lookup` aus dem Cluster und schreibt es unverändert zurück. Ein
explizit gesetzter Wert **rotiert** das Secret. **Achtung:** Eine Änderung von
`genesisHash` bricht die Integrität der Admin-Event-Hash-Chain, eine Änderung
von `smcbHashingPepper` invalidiert alle bestehenden SMC-B-Nutzer-Hashes.

Alternativ lassen sich beide Secrets außerhalb des Charts verwalten und nur
referenzieren. Dann legt das Chart kein eigenes Secret an, und
`genesisHash`/`smcbHashingPepper` entfallen auch bei der Erstinstallation:

```yaml
authserver:
    genesisHashSecretRef: "genesis-hash"                # Secret mit Key 'hash'
    smcbHashingPepperSecretRef: "smcb-hashing-pepper"   # Secret mit Key 'pepper'
```

| Value                                   | Beschreibung                                                                                              | Standard |
|-----------------------------------------|-----------------------------------------------------------------------------------------------------------|----------|
| `authserver.genesisHash`                | Seed der Admin-Event-Hash-Chain. Empfohlenes Format: 64-stelliger Hex-String (`openssl rand -hex 32`)     | `null`   |
| `authserver.smcbHashingPepper`          | Pepper für SMC-B-Nutzer-Hashes. Empfohlenes Format: UUID (`uuidgen`)                                      | `null`   |
| `authserver.genesisHashSecretRef`       | Name eines selbst verwalteten Secrets mit dem Key `hash`. Leer: Das Chart erzeugt `genesis-hash`          | `""`     |
| `authserver.smcbHashingPepperSecretRef` | Name eines selbst verwalteten Secrets mit dem Key `pepper`. Leer: Das Chart erzeugt `smcb-hashing-pepper` | `""`     |

### ServiceAccount

Für den Authserver wird standardmäßig ein dedizierter ServiceAccount erzeugt,
der den automatischen Token-Mount deaktiviert:

```yaml
authserver:
    serviceAccount:
        create: true
        name: authserver
```

Setzen Sie `create: false`, um einen bereits bestehenden ServiceAccount zu
nutzen.

### Replicas und PodDisruptionBudget

```yaml
authserver:
    replicaCount: 2
    podDisruptionBudget:
        enabled: true
        minAvailable: 1
```

Das PodDisruptionBudget ist standardmäßig deaktiviert. Es kann entweder
`minAvailable` oder `maxUnavailable` konfiguriert werden, aber nicht beides
gleichzeitig.

### Ressourcen

Ressourcen werden separat für den Hauptcontainer
(`authserver.container.resources`) und den Keycloak-Build-Init-Container
(`authserver.initContainer.resources`) konfiguriert. Der Provisioning-Processor-Init-Container ist ein gemeinsamer
Container und wird separat unter `provisioningProcessor.*` konfiguriert (siehe
unten und
[Wie Sie Ressourcen für ZETA-Guard-Pods verwalten](../Anleitungen/Wie_Sie_Ressourcen_für_ZETA_Guard_Pods_verwalten.md)):

```yaml
authserver:
    container:
        resources:
            limits:
                cpu: "8"
                memory: "4Gi"
            requests:
                cpu: "4"
                memory: "4Gi"
    initContainer:
        resources:
            limits:
                cpu: "2"
                memory: "2Gi"
            requests:
                cpu: "500m"
                memory: "512Mi"
```

### Security Contexts

Pod- und Container-Security-Contexts sind konfigurierbar. Alle Komponenten bauen auf
zwei chartweiten Defaults auf, `defaultPodSecurityContext` und
[`defaultContainerSecurityContext`](#chartweiter-default-defaultcontainersecuritycontext).
Pro Komponente steht nur, was davon abweicht:

```yaml
defaultPodSecurityContext:
    seccompProfile:
        type: RuntimeDefault
authserver:
    podSecurityContext: {}
    container:
        containerSecurityContext: {}
    initContainer:
        containerSecurityContext: {}
```

`defaultPodSecurityContext` gilt für alle Pods des Charts und wird wie der
Container-Default pro Key gemischt (der PEP ergänzt z. B. nur seine `sysctls`). Das
Seccomp-Profil sitzt bewusst auf Pod-Ebene, damit es auch für Container gilt, die
das Chart nicht selbst rendert (injizierte Sidecars, Debug-Container). `runAsUser`
bleibt dagegen auf Container-Ebene und wird so nicht an einen injizierten
`istio-proxy` vererbt.

#### Chartweiter Default: `defaultContainerSecurityContext`

`defaultContainerSecurityContext` ist die zentrale Stelle für alle
Container-Security-Contexts des Charts (PSS `restricted`). Jeder Key daraus wird
übernommen, sofern der `containerSecurityContext` der Komponente ihn nicht selbst
setzt. Komponenten mit beschreibbarem Root-Dateisystem (Provisioning-Processor,
keychain-generator, CronJobs, Zertifikats-Adoptions-Job) setzen dort nur
`readOnlyRootFilesystem: false`.

```yaml
defaultContainerSecurityContext:
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    runAsNonRoot: true
    runAsUser: 1000
    capabilities:
        drop: [ "ALL" ]
```

Gemischt wird pro Key der obersten Ebene: Setzt eine Komponente `capabilities`,
ersetzt sie die ganze Map — beim Hinzufügen einer Capability also
`drop: [ "ALL" ]` mit angeben.

Die numerische UID ist nötig, weil mehrere Images einen nicht-numerischen User
(Authserver, PEP) oder gar keinen (`google/cloud-sdk`, `python`) deklarieren. Das
Kubelet kann `runAsNonRoot: true` dann nicht prüfen und startet den Container
nicht. Auf OpenShift `defaultContainerSecurityContext.runAsUser` **explizit auf
`null`** setzen, damit die SCC die UID vergibt.

**Ausnahme Telemetry-Gateway:** Als Subchart liest es
`defaultContainerSecurityContext` nicht. Das Chart setzt dort eigens
`securityContext.runAsUser: 1000` und `podSecurityContext.fsGroup: 1000`, weil der
Collector eine bekannte
Non-Root-Identität braucht, die auf den PersistentVolumeClaim der Sending-Queue
schreiben kann. Auf OpenShift müssen beide Werte **explizit auf `null`** gesetzt
werden — ein Weglassen der Keys genügt nicht, da Helm Maps merged und die `1000`
dann aus den Chart-Defaults erhalten bleibt. Siehe
[Wie Sie ZETA-Guard auf OpenShift betreiben](../Anleitungen/ZETA_OpenShift_Kompatibilität.md).

**Ausnahme KPI-Prometheus** (`kpiPrometheus`, nur bei
`kpiMetricsPersistence.enabled`): Auch dieser Subchart liest die chartweiten
Defaults nicht. Die PSS-`restricted`-Werte stehen deshalb eigens unter
`kpiPrometheus.server.securityContext` (Pod), `kpiPrometheus.server.containerSecurityContext`
und `kpiPrometheus.configmapReload.prometheus.containerSecurityContext`. Die IDs
(`runAsUser`, `runAsGroup`, `fsGroup`: `65534`) bringt der Subchart selbst mit; auf
OpenShift müssen sie **explizit auf `null`** gesetzt werden, siehe
[Wie Sie ZETA-Guard auf OpenShift betreiben](../Anleitungen/ZETA_OpenShift_Kompatibilität.md).

### Probes

Die Parameter für Liveness-, Readiness- und Startup-Probes sind konfigurierbar:

```yaml
authserver:
    probes:
        liveness:
            initialDelaySeconds: 0
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 5
        readiness:
            initialDelaySeconds: 0
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
        startup:
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 5
            failureThreshold: 60
```

| Value                           | Beschreibung                                                                                                               | Standard                |
|---------------------------------|----------------------------------------------------------------------------------------------------------------------------|-------------------------|
| `authserver.probes.liveness.*`  | Liveness-Probe auf `/auth-mgmt/health/live/`: `initialDelaySeconds`, `periodSeconds`, `timeoutSeconds`, `failureThreshold` | `0` / `10` / `5` / `5`  |
| `authserver.probes.readiness.*` | Readiness-Probe auf `/auth-mgmt/health/ready/`, gleiche Felder                                                             | `0` / `10` / `5` / `3`  |
| `authserver.probes.startup.*`   | Startup-Probe auf `/auth-mgmt/health/ready/`, gleiche Felder                                                               | `10` / `5` / `5` / `60` |

> **Hinweis:** Der Endpunkt der Liveness-Probe ist nicht konfigurierbar. Sie
> zielt fest auf `/health/live`, das in Keycloak nicht auf die Datenbank
> zugreift, und bleibt damit bewusst datenbankunabhängig: Eine
> datenbankabhängige Liveness-Probe würde bei einem Datenbankausfall *alle*
> Authserver-Pods gleichzeitig neu starten und einen behebbaren Vorfall in eine
> Neustart-Kaskade verwandeln. `failureThreshold: 5` bezieht sich deshalb auf
> eine nicht mehr reagierende JVM, nicht auf die Verfügbarkeit der Datenbank.
> Eine blockierte Verbindung behebt der Verbindungspool selbst — siehe
> [Connection Pooling (Keycloak)](#connection-pooling-keycloak) und
> [Datenbank nicht erreichbar / Authserver antwortet nicht](../Anleitungen/Troubleshooting_und_Debugging.md#datenbank-nicht-erreichbar--authserver-antwortet-nicht).

> **Hinweis:** `timeoutSeconds` sollte nicht ungesetzt bleiben — Kubernetes
> nimmt sonst **1 s** an, was hier zu knapp ist. Der Agroal-Zähler
> `invalidCount` wird nie zurückgesetzt; sobald die Verbindungsvalidierung die
> erste tote Verbindung verworfen hat, führt Keycloak bei **jeder**
> Readiness-Probe eine echte Datenbankprüfung durch, statt aus den Pool-Metriken
> zu antworten. Die Obergrenze ist Agroals Acquisition-Timeout (`PT20S`).

### Admin-API-Absicherung

Die Keycloak-Admin-REST-API und die Admin Console (`/auth/admin/*`) dürfen nicht
über den öffentlichen Hostnamen zugänglich sein — und ebenso wenig der
`master`-Realm (`/auth/realms/master/*`): Dort wird das Admin-Access-Token
ausgestellt (`client_id=admin-cli`, Direct Grant), sodass ein öffentlich
erreichbarer `master`-Realm genau die Angriffsfläche wieder öffnet, die das
Sperren von `/auth/admin` schließen soll. Der `master`-Realm trägt keinen
ZETA-Verkehr; der läuft vollständig über den `zeta-guard`-Realm. Das Helm-Chart
unterstützt eine integrierte Absicherung über einen separaten Admin-Hostnamen.

Wenn `authserver.adminHostname` gesetzt ist, aktiviert das Chart zwei
Schutzschichten:

1. **`/auth/admin` und `/auth/realms/master` werden an den PEP-Proxy geroutet,
   der sie sperrt** — der Ingress `zeta-guard-pep` erhält zusätzliche Pfade
   `/auth/admin` und `/auth/realms/master` auf `pep-proxy-svc`. Dort gibt ein
   `location ~ ^/auth/(admin|realms/master)(/|$)`-Block `403 Forbidden` zurück,
   bevor die Anfrage Keycloak erreicht. Das Suffix `(/|$)` hält das `403` auf
   Segmentgrenzen — passend zum `pathType: Prefix` des Ingress —, sodass ein
   Realm, dessen Name lediglich mit `master` beginnt, nicht gesperrt wird. Er
   erreicht dennoch den PEP, weil der Controller aus dem Ingress-Pfad eine
   einfache NGINX-Prefix-Location macht, die Segmentgrenzen nicht kennt, und
   erhält dort mangels Token ein `401` — genau wie `/auth/admin` sich seit jeher
   etwa gegenüber `/auth/administration` verhält.
   Alle anderen `/auth/*`-Pfade (Token-Exchange, Nonce, Client-Registration,
   Well-Known-Endpunkte und der gesamte `zeta-guard`-Realm) werden über den
   Ingress `zeta-guard-auth` **direkt** an den Authserver geroutet und erreichen
   den PEP nie.
2. **Separater Admin-Ingress** — für den Admin-Hostnamen werden zwei zusätzliche
   Ingress-Ressourcen erzeugt, die `/auth` direkt an den Authserver routen
   (unter Umgehung des PEP-Proxy-Blocks). Terraform und CI/CD-Runner verwenden
   ausschließlich diesen Hostnamen.

Die Aufteilung funktioniert, weil überlappende Pfad-Prefixe nach dem längsten
Treffer aufgelöst werden — unabhängig von der Reihenfolge, in der sie deklariert
sind. Das garantieren sowohl NGINX als auch die Kubernetes-Ingress-Spezifikation,
`/auth/admin` und `/auth/realms/master` gewinnen also gegen `/auth`.

Hinzu kommt ein dritter, von Terraform gesetzter Baustein: Die
Authserver-Konfiguration heftet beim nächsten `terraform apply` die
**Frontend-URL des `master`-Realms** an den Admin-Hostnamen. Die Admin
Console ist ein OIDC-Client des `master`-Realms und leitet ihre `authServerUrl`
aus dessen Frontend-URL ab, die sonst Keycloaks `--hostname` — also dem
öffentlichen Hostnamen — folgt. Ohne diese Bindung liefe der Login-Redirect der
Console auf den nun gesperrten Pfad
`/auth/realms/master/protocol/openid-connect/auth` und der Browser-Login bräche.
Der Wert wird automatisch aus `keycloak_url` abgeleitet, sobald `audience`
gesetzt ist; mit der Terraform-Variable `master_realm_frontend_url` lässt er sich
überschreiben. Betroffen ist ausschließlich der `master`-Realm — der
`zeta-guard`-Realm behält den öffentlichen `issuer`, den jedes Access-Token
trägt.

Die Absicherung ist ingress-controller-unabhängig und funktioniert mit F5 NIC,
Standard-nginx-Ingress, OpenShift Routes, GKE Ingress und anderen Controllern,
da sie ausschließlich auf Standard-Ingress-Pfad-Routing und der
NGINX-Konfiguration des PEP beruht — nicht auf controller-spezifischen
Annotationen.

```yaml
authserver:
    hostname: "zeta.example.com"
    # Separater Hostname für den Keycloak-Admin-Zugriff.
    # Wenn gesetzt, werden /auth/admin und /auth/realms/master auf dem
    # Haupthostnamen an den PEP-Proxy geroutet und dort mit 403 gesperrt;
    # zusätzlich wird ein dedizierter Admin-Ingress für diesen Hostnamen erzeugt.
    adminHostname: "admin.zeta.example.com"
```

Für Umgebungen, in denen kein ClusterIssuer für den Admin-Hostnamen verfügbar
ist (z. B. KIND), kann ein bestehendes TLS-Secret wiederverwendet werden:

```yaml
authserver:
    adminTlsSecretName: "zeta-guard-tls"  # bestehendes Secret wiederverwenden
```

Um die Funktion zu deaktivieren, entfernen Sie `adminHostname` (oder setzen Sie
es auf `""`) und führen Sie `helm upgrade` aus. Der Admin-Ingress, die
Ingress-Pfade `/auth/admin` und `/auth/realms/master` sowie der
PEP-Proxy-Location-Block werden automatisch entfernt — beide sind danach wieder
über den Haupthostnamen erreichbar, da es sonst keinen Zugang mehr gäbe. Die
Frontend-URL des `master`-Realms bleibt dabei stehen; setzen Sie sie bei Bedarf
über `master_realm_frontend_url` zurück.

> **Einschränkung:** Wenn `routeViaTigerProxy: true` gesetzt ist, werden die
> Ingress-Pfade `/auth/admin` und `/auth/realms/master` **nicht** erzeugt:
> Tiger-Proxy leitet `/auth` intern
> direkt an den Authserver weiter und umgeht den PEP vollständig, ein Routing
> dorthin würde also nichts sperren. Mit F5 NIC greift in diesem Fall noch die
> `location-snippets`-Annotation auf `zeta-guard-auth` und antwortet mit `404`;
> mit jedem anderen Ingress-Controller bleiben beide Pfade auf dem
> Haupthostnamen erreichbar. Tiger-Proxy ist ausschließlich ein Testwerkzeug und
> wird in Produktionsdeployments nicht eingesetzt.

> **Der Browser eines Administrators kommt mit dem Admin-Hostnamen aus — sofern
> die Authserver-Konfiguration angewendet wurde.** Die Admin Console ist eine Browser-Anwendung, die
> vom Admin-Hostnamen ausgeliefert wird. Ohne weiteres Zutun authentifiziert sie
> sich jedoch gegen den **öffentlichen** Hostnamen: Keycloak leitet ihre
> `authServerUrl` aus `--hostname` ab, der Login-Redirect ginge daher auf
> `https://<haupthost>/auth/realms/master/protocol/openid-connect/auth` — einen
> Pfad, den die `403`-Sperre nun abweist. Genau deshalb heftet Terraform die
> Frontend-URL des `master`-Realms an den Admin-Hostnamen (siehe oben); danach
> laufen Login-Redirect, Admin-REST-Aufrufe und statische Ressourcen vollständig
> über den Admin-Hostnamen. Wird das Chart mit `adminHostname` ausgerollt, ohne
> dass anschließend die Authserver-Konfiguration angewendet wird, bleibt der
> Browser-Login der Console blockiert.
>
> Folge für den Netzentwurf: Den Admin-Hostnamen auf ein internes Netz zu
> beschränken ist unproblematisch, aber ein Arbeitsplatz, der *ausschließlich*
> den Admin-Hostnamen erreicht, kann den Login nicht abschließen. Terraform und
> CI/CD-Runner sind davon nicht betroffen — sie nutzen die Admin-REST-API direkt
> über `admin-cli` und durchlaufen keinen Browser-Flow.

> **Vollständig nutzbar erst ab Chart 1.3.0.** Bis einschließlich Chart 1.2.4
> übergab das Chart `--hostname-admin` ohne den Kontextpfad `/auth`. Keycloak
> läuft mit `KC_HTTP_RELATIVE_PATH=/auth`, liefert die Admin Console also unter
> `/auth/admin/`, leitete aber auf `/admin/` um — auf einen Pfad, den weder
> Keycloak noch der Admin-Ingress beantwortet. Der Aufruf von
> `https://<haupthost>/auth` endet dadurch auf `https://<adminhost>/admin`, und
> der Admin-Hostname wirkt nicht erreichbar.
>
> Entfernen Sie in diesem Fall **nicht** die Hostname-Parameter: Ohne beide
> leitet Keycloak den `issuer` aus dem `Host`-Header ab und weist im Well-Known
> die clusterinterne Adresse `https://authserver/…` aus; nur mit `--hostname`
> scheitert der 3rd-Party-Cookie-Check der Admin-UI. Bis zum Update auf 1.3.0
> oder neuer hilft ein Deployment-Patch, der `--hostname-admin` auf
> `https://<adminhost>/auth` setzt — denselben Wert, den das Chart ab 1.3.0
> rendert.

#### Womit die Admin-API abgesichert ist

Die Absicherung beruht auf **Trennung nach Hostnamen**, nicht auf einer
Authentisierungsschicht vor der API. Das Chart entzieht dem Haupthostnamen die
administrativen Pfade und bietet sie ausschließlich auf dem Admin-Hostnamen an.
Was dort ankommt, prüft Keycloak selbst: Jeder Aufruf der Admin-REST-API
verlangt ein Admin-Access-Token, das im `master`-Realm per `admin-cli`
ausgestellt wird.

Daraus folgt die Aufgabenteilung:

| Schutzziel                                                | abgedeckt durch                                              |
|-----------------------------------------------------------|--------------------------------------------------------------|
| Admin-Pfade auf dem Haupthostnamen nicht erreichbar       | Chart (PEP-Sperre `403`, bei F5 NIC zusätzlich `404`)        |
| Admin-Pfade nur über den Admin-Hostnamen erreichbar       | Chart (eigener Ingress)                                      |
| Aufruf der Admin-REST-API nur mit gültigem Token          | Keycloak                                                     |
| Login der Admin Console auf dem Admin-Hostnamen           | Authserver-Konfiguration (Frontend-URL des `master`-Realms)  |
| **Wer den Admin-Hostnamen überhaupt erreichen darf**      | **Betreiber** — das Chart schränkt nichts ein                |
| **Begrenzung von Rateversuchen auf Admin-Zugangsdaten**   | **Betreiber** — standardmäßig nicht aktiv                    |
| **Wer die Admin-Zugangsdaten lesen darf**                 | **Betreiber** (Kubernetes-RBAC auf das Secret)               |

Der Admin-Hostname selbst ist durch nichts als TLS geschützt. Ist er öffentlich
auflösbar und nicht weiter eingeschränkt, steht die Admin Console im Netz — die
Hostnamen-Trennung verlagert den Zugang, sie verschließt ihn nicht.

#### Was der Betreiber zusätzlich leisten muss

1. **Zugriff auf den Admin-Hostnamen einschränken.** Das Chart erzwingt keine
   IP-basierte Beschränkung. Je nach Plattform: Cloud Armor (GKE),
   NetworkPolicy oder Route-Annotation (OpenShift), Firewall-Regeln, oder den
   Admin-Hostnamen gar nicht erst öffentlich auflösen lassen.
2. **Brute-Force-Erkennung im `master`-Realm aktivieren.** Keycloak liefert sie
   abgeschaltet aus, und der `master`-Realm wird weder vom Chart noch von der
   Authserver-Konfiguration verwaltet — ohne diesen Schritt sind Rateversuche
   auf das Admin-Passwort unbegrenzt.
3. **Leserecht auf das Secret `authserver-admin` begrenzen.** Wer es im
   Namespace lesen darf, besitzt die Admin-Zugangsdaten. Dasselbe gilt für
   Umgebungen, in denen sie als Variablen hinterlegt sind (CI/CD-Runner).
4. **Admin-Passwort stark wählen und rotieren.** Es ist der einzige Faktor vor
   der Admin-REST-API.
5. **Nach jedem Upgrade die Authserver-Konfiguration anwenden.** Sie heftet die
   Frontend-URL des `master`-Realms an den Admin-Hostnamen; ohne sie ist der
   Browser-Login der Console blockiert (siehe unten).
6. **Den Netzentwurf auf die Admin-Arbeitsplätze abstimmen.** Der
   Admin-Hostname muss von ihnen erreichbar sein, und das TLS-Zertifikat muss
   ihn abdecken — bei gemeinsamer Nutzung des Haupt-Zertifikats über dessen
   SAN-Liste, sonst über ein eigenes Secret (`adminTlsSecretName`).

#### Unterschiede vor und nach Chart 1.3.3

Bis einschließlich Chart 1.3.3 sperrte das Chart ausschließlich `/auth/admin`;
der `master`-Realm blieb auf dem Haupthostnamen offen. Das wirkt sich auf drei
Dinge aus: auf den Weg zur Login-Maske, auf die Angriffsfläche der Admin-API und
darauf, wer den Authserver konfigurieren kann.

##### Zugang zur Login-Maske

Die Admin Console wird in beiden Ständen vom Admin-Hostnamen ausgeliefert. Der
Unterschied liegt darin, wo der Login-Dialog selbst gerendert wird.

| Schritt                    | bis einschließlich 1.3.3                                  | nach 1.3.3                                      |
|----------------------------|-----------------------------------------------------------|-------------------------------------------------|
| Console aufrufen           | `https://<adminhost>/auth/admin/master/console/`          | unverändert                                     |
| Login-Dialog erscheint auf | **Haupthostname**                                         | **Admin-Hostname**                              |
| Browser benötigt           | **beide** Hostnamen                                       | nur den Admin-Hostnamen                         |
| Vorbedingung               | `adminHostname` gesetzt, TLS-Zertifikat deckt beide Namen | zusätzlich: Authserver-Konfiguration angewendet |

Bis einschließlich 1.3.3 leitet die Console auf
`https://<haupthost>/auth/realms/master/protocol/openid-connect/auth` um. Dieser
Pfad ist dort nicht gesperrt, der Login gelingt — aber nur, wenn der Arbeitsplatz
den Haupthostnamen erreicht.

Danach ist derselbe Pfad mit `403` belegt. Damit der Login weiterhin
funktioniert, heftet die Authserver-Konfiguration die Frontend-URL des
`master`-Realms an den Admin-Hostnamen. **Ohne diesen Schritt ist der
Browser-Login nicht möglich**: Die Console verweist dann weiterhin auf den
gesperrten Pfad. Prüfen lässt sich der Zustand an der Console-Konfiguration:

```bash
curl -sk https://<adminhost>/auth/admin/master/console/ | grep -o 'authServerUrl[^,}]*'
```

Der ausgewiesene Wert muss der Admin-Hostname sein.

##### Absicherung der Admin-API

| Schutzebene                                    | bis einschließlich 1.3.3 | nach 1.3.3                      |
|------------------------------------------------|--------------------------|---------------------------------|
| `/auth/admin/*` auf dem Haupthostnamen         | gesperrt (`403`/`404`)   | unverändert                     |
| `/auth/realms/master/*` auf dem Haupthostnamen | **offen**                | gesperrt (`403`/`404`)          |
| Admin-Token per `admin-cli` vom Haupthostnamen | **möglich**              | nicht möglich                   |
| Admin-Hostname selbst                          | nur TLS                  | unverändert: nur TLS            |
| Brute-Force-Schutz im `master`-Realm           | nicht konfiguriert       | unverändert: nicht konfiguriert |
| IP-Beschränkung                                | Sache des Betreibers     | unverändert                     |

Der sicherheitsrelevante Unterschied ist die dritte Zeile. Bis einschließlich
1.3.3 war `/auth/realms/master/protocol/openid-connect/token` von außen
erreichbar, sodass sich Admin-Zugangsdaten über den Haupthostnamen erproben
ließen — ohne Ratenbegrenzung, solange die Brute-Force-Erkennung nicht aktiviert
wurde (Punkt 2 der Betreiberpflichten). Ein erratenes Passwort allein hätte noch
keine Konfigurationsänderung erlaubt, da die Admin-REST-Aufrufe weiterhin den
Admin-Hostnamen verlangen; ein gültiges Admin-Token ist aber eine Vorstufe, die
sich vermeiden lässt.

Die beiden letzten Zeilen bleiben unverändert: Sie liegen in der Verantwortung
des Betreibers, nicht des Charts.

##### Wer den Authserver konfigurieren kann

Erforderlich sind stets **beide** Voraussetzungen: Zugangsdaten und Netzzugang
zum Admin-Endpunkt.

| Voraussetzung                                  | bis einschließlich 1.3.3                                  | nach 1.3.3                   |
|------------------------------------------------|-----------------------------------------------------------|------------------------------|
| Zugangsdaten aus dem Secret `authserver-admin` | wer sie im Namespace lesen darf                           | unverändert                  |
| Zugangsdaten als Umgebungsvariablen            | wer sie kennt                                             | unverändert                  |
| Admin-Token beziehen                           | über **beide** Hostnamen                                  | nur über den Admin-Hostnamen |
| `/auth/admin/realms/…` aufrufen                | nur über den Admin-Hostnamen                              | unverändert                  |
| **effektiv konfigurieren**                     | wer Zugangsdaten hat **und** den Admin-Hostnamen erreicht | unverändert                  |

Der Kreis der tatsächlich Berechtigten ändert sich also nicht; es entfällt
lediglich die Möglichkeit, Zugangsdaten vom Haupthostnamen aus zu erproben. Wer
diesen Kreis enger ziehen will, tut das über die Punkte 1 und 3 der
Betreiberpflichten — nicht über das Chart.

Drei Punkte gehören zum Konfigurationszugang dazu:

- `keycloak_url` muss auf den Admin-Hostnamen zeigen — das galt bereits bis
  einschließlich 1.3.3, da die Admin-REST-Aufrufe dort liegen — und `audience`
  muss explizit gesetzt sein. Andernfalls leitet sich der Audience-Wert vom
  Admin-Hostnamen ab und passt nicht zu den ausgestellten Tokens.
- Ist der [mobile Client-Flow](../Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md)
  aktiv (`enable_sekidp = true`), muss zusätzlich `sekidp_client_id` auf den
  öffentlichen Issuer des `zeta-guard`-Realms gesetzt sein, z. B.
  `https://zeta.example.com/auth/realms/zeta-guard`. Andernfalls leitet sich die
  `client_id` des IDP `zeta-sekidp-oidc` ebenfalls vom Admin-Hostnamen ab. Der
  sektorale IDP lädt über diese URL das Entity Statement des Guards — den
  Admin-Hostnamen erreicht er nicht (und soll es nach Punkt 1 der
  Betreiberpflichten auch nicht), die Anmeldung von Versicherten scheitert dann
  bereits beim Pushed Authorization Request.
- Manuelle Eingriffe per `curl`, etwa aus
  [Wie Sie ZETA Guard aktualisieren](../Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md),
  beziehen ihr Admin-Token über `<KC_URL>/realms/master/…`. Bis einschließlich
  1.3.3 funktionierte das auch mit dem Haupthostnamen; danach muss `KC_URL` der
  Admin-Hostname sein.

---

### cert-manager-Issuer für Ingress-TLS

Das Chart annotiert die Master-Ingress-Ressourcen (Haupt- und Admin-Ingress) so,
dass cert-manager das TLS-Zertifikat automatisch ausstellt. Es gibt zwei sich
ausschließende Varianten:

| Value           | Erzeugte Annotation              | Gültigkeitsbereich des Issuers |
|-----------------|----------------------------------|--------------------------------|
| `clusterIssuer` | `cert-manager.io/cluster-issuer` | clusterweit (`ClusterIssuer`)  |
| `issuer`        | `cert-manager.io/issuer`         | namespace-lokal (`Issuer`)     |

Standardmäßig wird `clusterIssuer` verwendet (Standardwert `letsencrypt`, sofern
nicht überschrieben). Ist `issuer` gesetzt, hat dieser **Vorrang** und das Chart
emittiert ausschließlich die `cert-manager.io/issuer`-Annotation. Der
referenzierte `Issuer` muss dann im Deployment-Namespace existieren.

```yaml
# Namespace-lokaler Issuer — Vorrang vor clusterIssuer
issuer: "letsencrypt-namespaced"
# Clusterweiter Issuer — nur wirksam, wenn issuer leer ist
clusterIssuer: "letsencrypt"
```

> **Wann `issuer` statt `clusterIssuer`?** Wenn Governance- oder
> Security-Vorgaben das Ausrollen clusterweiter `ClusterIssuer`-Ressourcen
> untersagen, kann mit `issuer` ein auf den Namespace beschränkter `Issuer`
> verwendet werden, ohne clusterweite Berechtigungen zu benötigen.

---

### CloudNativePG-Datenbankverbindung

Im Datenbankmodus `cloudnative` sind JDBC-URL, Secret-Name und Schema
konfigurierbar:

```yaml
databaseMode: cloudnative
cloudnativeDbUrl: "jdbc:postgresql://keycloak-db-rw:5432/keycloak"
cloudnativeDbSecretName: "keycloak-db-app"
cloudnativeDbSchema: "public"
```

Die Standardwerte verweisen auf den vom CloudNativePG-Operator erzeugten Service
und das zugehörige Secret. Passen Sie diese an, wenn Sie eine abweichende
Datenbankinstanz verwenden.

Zusätzliche JDBC-Parameter werden über `authserver.db.urlProperties` an diese URL
angehängt (identisch für `databaseMode: external` und `authserverDb.kcDbUrl`):

```yaml
authserver:
    db:
        urlProperties:
            socketTimeout: 600
```

| Value                         | Beschreibung                                                   | Standard                                   |
|-------------------------------|----------------------------------------------------------------|--------------------------------------------|
| `authserver.db.urlProperties` | pgjdbc-Parameter, als Query-Parameter an `KC_DB_URL` angehängt | `socketTimeout: 120`, `tcpKeepAlive: true` |

Treiber-Einstellungen gehören hierher und nicht in
`QUARKUS_DATASOURCE_JDBC_ADDITIONAL_JDBC_PROPERTIES_*`: das ist eine Map, und ein
Umgebungsvariablenname kann den CamelCase-Schlüssel nicht transportieren — aus
`socketTimeout` würde `sockettimeout`, das pgjdbc stillschweigend ignoriert. In der
URL bleibt die Schreibweise erhalten, und pgjdbc wertet URL-Parameter ohnehin
vorrangig aus. Für ein Release mit aufwendiger Schema-Migration lässt sich
`socketTimeout` hier vorübergehend anheben.

> **Hinweis:** `connectTimeout` und `targetServerType` sind hier **nicht
> zulässig**; das Chart bricht das Rendern mit einer Fehlermeldung ab. Keycloak
> setzt beide selbst (`db-connect-timeout` = `10s`,
> `db-postgres-target-server-type` = `primary`), überspringt diese Injektion aber,
> sobald einer der beiden Namen bereits in der URL vorkommt — wer einen davon
> setzt, verliert damit still den anderen. Aus demselben Grund ist
> `KC_DB_URL_PROPERTIES` wirkungslos: Keycloak ignoriert diese Option, sobald
> `db-url` gesetzt ist, was im Chart immer der Fall ist.

Die Anzahl der Datenbankinstanzen bestimmt, was bei einem Ausfall des Primaries
passiert:

| Value                     | Beschreibung                                             | Standard |
|---------------------------|----------------------------------------------------------|----------|
| `cloudnativePg.instances` | Anzahl der PostgreSQL-Instanzen im CloudNativePG-Cluster | `1`      |

> **Hinweis:** `instances: 1` ist nur für Entwicklungs- und Testumgebungen
> geeignet — jeder Ersatz des Primaries ist dann ein vollständiger Ausfall. Ab
> `instances: 3` führt CloudNativePG ein automatisches Failover durch. Damit wird
> ein Primary-Wechsel allerdings zum Regelfall statt zur Ausnahme; die
> Verbindungsresilienz des Authservers (siehe Abschnitt *Connection Pooling*) ist
> deshalb die **Voraussetzung** dafür, dass mehr Instanzen tatsächlich
> Verfügbarkeit bringen.

Tuning-Parameter, die direkt an die PostgreSQL-Konfiguration des
CloudNativePG-Clusters durchgereicht werden, sind unter
`cloudnativePg.parameters` konfigurierbar:

```yaml
cloudnativePg:
    parameters:
        sharedBuffers: 512MB
        maxConnections: 250
```

| Value                                     | Beschreibung                 | Standard |
|-------------------------------------------|------------------------------|----------|
| `cloudnativePg.parameters.sharedBuffers`  | PostgreSQL `shared_buffers`  | `512MB`  |
| `cloudnativePg.parameters.maxConnections` | PostgreSQL `max_connections` | `250`    |

> **Hinweis:** Die `values-demo.yaml` im Chart verwendet kleinere Werte
> (`sharedBuffers: 24MB`, `maxConnections: 100`) für ressourcenarme
> Test-Cluster. `maxConnections` muss zu den Keycloak-Pool-Größen (siehe unten)
> passen.

#### Größe des Datenbank-Volumes

| Value                                | Beschreibung                                                                                                        | Standard |
|--------------------------------------|---------------------------------------------------------------------------------------------------------------------|----------|
| `cloudnativePg.storage.size`         | Größe des Daten-Volumes je Instanz                                                                                  | `32Gi`   |
| `cloudnativePg.storage.storageClass` | StorageClass des Daten-Volumes; leer → Default-StorageClass des Clusters                                            | `""`     |
| `cloudnativePg.walStorage`           | Eigenes Volume für das Write-Ahead-Log (`size`, optional `storageClass`); leer → das WAL liegt auf dem Daten-Volume | `{}`     |

Die Zahl der registrierten Clients bestimmt den Platzbedarf, nicht der Verkehr.
Mit dem Spree Integrity Provider (`authserver.dbEnc.enabled: true`, siehe
[Spree Integrity Provider (VAU)](#spree-integrity-provider-vau)) kommt je
gespeicherter Zeile eine Prüfsumme hinzu. Das Volume füllt sich dadurch ungefähr
dreimal so schnell:

| Variante                                     | Platz je registriertem Client | Faustformel für das Volume     | Clients bei 32Gi | Clients bei 64Gi |
|----------------------------------------------|-------------------------------|--------------------------------|------------------|------------------|
| ohne VAU (`authserver.dbEnc.enabled: false`) | ca. 15 KB                     | `Clients × 15 KB × 1,3 + 3 GB` | ca. 1,4 Mio.     | ca. 3 Mio.       |
| mit VAU (`authserver.dbEnc.enabled: true`)   | ca. 50 KB                     | `Clients × 50 KB × 1,3 + 3 GB` | ca. 400.000      | ca. 900.000      |

Der Faktor 1,3 deckt Bloat und Reindex ab, die 3 GB das WAL und die
Grunddaten. Die Werte stammen aus Messungen an Testinstallationen; prüfen Sie
das tatsächliche Wachstum an Ihrer Installation (`pg_database_size` vor und
nach einer Reihe von Registrierungen).

- **In einer VAU** beginnen Sie mit 64Gi und einem eigenen WAL-Volume.
- Läuft das Volume voll, stoppt PostgreSQL und der Pod startet nicht mehr.
  Überwachen Sie die Belegung und vergrößern Sie rechtzeitig.
- Ein Volume lässt sich im Betrieb vergrößern, wenn die StorageClass
  `allowVolumeExpansion: true` hat: `cloudnativePg.storage.size` anheben und das
  Release aktualisieren. Verkleinern ist nicht möglich.

Ein eigenes WAL-Volume verhindert, dass die Schreibspitzen der Checkpoints die
Commits verzögern. Es empfiehlt sich für den Produktivbetrieb mit
Registrierungsspitzen, in einer VAU und auf Speicher, dessen IOPS von der
Volume-Größe abhängen (üblich bei Cloud-Disks):

```yaml
cloudnativePg:
    storage:
        size: 64Gi
    walStorage:
        size: 16Gi
        storageClass: <schnelle-storage-class>
```

Entscheiden Sie das vor der Erstinstallation; das nachträgliche Ergänzen an
einem bestehenden Cluster ist nicht vorgesehen. 8–16Gi genügen für
`max_wal_size: "2GB"`.

### Connection Pooling (Keycloak)

Keycloak hält serverseitig einen JDBC-Datenbank-Pool sowie einen
HTTP-Worker-Pool. Beide sind konfigurierbar:

```yaml
authserver:
    dbPool:
        minSize: 10
        maxSize: 100
        maxLifetime: PT30M
    httpPool:
        maxThreads: 300
```

| Value                            | Beschreibung                                                          | Standard |
|----------------------------------|-----------------------------------------------------------------------|----------|
| `authserver.dbPool.minSize`      | Minimale Größe des JDBC-Connection-Pools                              | `10`     |
| `authserver.dbPool.maxSize`      | Maximale Größe des JDBC-Connection-Pools                              | `100`    |
| `authserver.dbPool.maxLifetime`  | Lebensdauer einer Pool-Verbindung (ISO-8601), danach wird sie ersetzt | `PT30M`  |
| `authserver.httpPool.maxThreads` | Maximale Anzahl der Keycloak-HTTP-Worker-Threads                      | `300`    |

> **Hinweis:** `replicaCount × dbPool.maxSize` muss (zzgl. Reserve) unter
> `cloudnativePg.parameters.maxConnections` bleiben, sonst weist PostgreSQL
> Verbindungen ab; das Chart prüft dies beim Rendern und bricht mit einer
> Fehlermeldung ab.

#### Verhalten bei Datenbankausfall

Der Verlust des Datenbank-Primaries ist kein sauberer Verbindungsabbruch. Wird
der Primary-**Pod** gelöscht, verschwindet sein Netzwerk-Namespace, während die
ClusterIP `keycloak-db-rw` gültig bleibt — die bestehenden conntrack-Einträge von
kube-proxy zeigen weiter auf eine Pod-IP, die nicht mehr antwortet. Es wird kein
TCP-Reset gesendet, die Pakete werden verworfen. Deshalb erholt sich ein
regulärer Datenbank-*Neustart* von selbst, während ein *Pod-Neuaufbau* den
Authserver früher bis zu einem manuellen Neustart blockierte.

Die Gegenmaßnahmen liefert das Chart:

| Value                                            | Standard | Bedeutung                                                                                                                               |
|--------------------------------------------------|----------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `authserver.db.urlProperties.socketTimeout`      | `120`    | Sekunden. Einzige Schranke für einen blockierenden Lesevorgang — und die einzige für den Aufbau einer *Ersatz*verbindung.               |
| `authserver.db.urlProperties.tcpKeepAlive`       | `true`   | Erkennt manche toten Gegenstellen früher, nicht aber einen eingefrorenen Server.                                                        |
| `authserver.dbPool.validationQueryTimeout`       | `2S`     | Ohne diesen Wert validiert der Pool mit `isValid(0)` — ohne Socket-Timeout — und hängt an genau dem toten Socket, den er erkennen soll. |
| `authserver.dbPool.foregroundValidationInterval` | `5S`     | Prüfung beim Ausleihen, wenn die Verbindung länger als das ungenutzt war. Ohne Vorgabe deaktiviert.                                     |
| `authserver.dbPool.backgroundValidationInterval` | `15S`    | Turnus der Hintergrundprüfung ungenutzter Verbindungen.                                                                                 |
| `authserver.dbPool.idleRemovalInterval`          | `1M`     | Abbau ungenutzter Verbindungen; unterschreitet `dbPool.minSize` nie.                                                                    |

Ergänzt wird das durch `authserver.dbPool.maxLifetime` (oben).

> **Hinweis:** Das Socket-Timeout gilt für **jedes** Statement, auch für
> Liquibase-DDL bei der Schema-Migration. Eine dadurch abgebrochene Migration
> hinterlässt eine gehaltene Sperre in `DATABASECHANGELOGLOCK`; der nächste Start
> wartet dann 30 Minuten und scheitert anschließend. Erwarten Sie eine aufwendige
> Migration, erhöhen Sie den Wert für dieses Release über
> `authserver.db.urlProperties.socketTimeout`. Das Lösen der Sperre ist unter
> [Troubleshooting & Debugging](../Anleitungen/Troubleshooting_und_Debugging.md#datenbank-nicht-erreichbar--authserver-antwortet-nicht)
> beschrieben.

### HSM-Konfiguration

HSM-Integration für TLS und Token-Signierung:

```yaml
authserver:
    hsm:
        enabled: false                                          # HSM-Proxy-Anbindung aktivieren
        endpoint: "hsm-proxy:50051"                             # gRPC-Endpunkt des HSM-Proxy
        tls:
            enabled: false                                      # Pod-Level TLS via HSM
            keyId: "zeta-guard-keycloak-tls-es256-v1.p256"      # Schlüssel-ID für TLS
        tokenSigning:
            enabled: false                                      # HSM_PROXY_TOKEN_KEY_ID setzen
            keyId: "zeta-guard-keycloak-token-es256-v1.p256"    # Schlüssel-ID für Token-Signierung
            failClosed: true                                    # kein Software-Key-Fallback bei nicht erreichbarem HSM
```

| Value                                    | Beschreibung                                                                                                                                                                                                                                                             | Standard |
|------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `authserver.hsm.enabled`                 | HSM-Proxy-Anbindung aktivieren (setzt `HSM_PROXY_ENDPOINT`)                                                                                                                                                                                                              | `false`  |
| `authserver.hsm.endpoint`                | gRPC-Endpunkt des HSM-Proxy                                                                                                                                                                                                                                              | `""`     |
| `authserver.hsm.tls.enabled`             | Pod-Level TLS mit HSM-Schlüssel                                                                                                                                                                                                                                          | `false`  |
| `authserver.hsm.tls.keyId`               | Schlüssel-ID für TLS im HSM                                                                                                                                                                                                                                              | `""`     |
| `authserver.hsm.tokenSigning.enabled`    | Token-Signierung via HSM (setzt `HSM_PROXY_TOKEN_KEY_ID`)                                                                                                                                                                                                                | `false`  |
| `authserver.hsm.tokenSigning.keyId`      | Schlüssel-ID für Token-Signierung im HSM                                                                                                                                                                                                                                 | `""`     |
| `authserver.hsm.tokenSigning.failClosed` | Bei `true` verweigert der `HsmTokenSigningKeyProviderFactory` jeden Software-Key-Fallback, solange das HSM nicht erreichbar ist, statt Keycloak still einen Software-Signaturschlüssel erzeugen zu lassen. Nur für kontrollierte HSM-Wartungsfenster auf `false` setzen. | `true`   |
| `authserver.hsm.dbEnc.keyId`             | Schlüssel-ID des KEK für die Keychain der VAU-Datenbank; nur für den Spree Integrity Provider, siehe [Spree Integrity Provider (VAU)](#spree-integrity-provider-vau)                                                                                                     | `""`     |

> **Hinweis:** Die Helm-Values aktivieren die HSM-Proxy-Verbindung im
> Authorization Service (Keycloak). Die Registrierung des HSM-KeyProviders
> im Keycloak-Realm erfolgt separat über Terraform (siehe
> [Quickstart – PDP konfigurieren](../Anleitungen/ZETA_Guard_Quickstart.md#2-pdp-konfigurieren))
> mit den Variablen `hsm_token_signing_enabled`, `hsm_token_signing_endpoint`
> und `hsm_token_signing_key_id`.

### SMC-B OCSP-Sperrprüfung

Beim Token-Exchange prüft der Authorization Service den Sperrstatus des
SMC-B-Zertifikats per OCSP. Die Timeouts der OCSP-Anfrage sowie das Verhalten
bei nicht bestimmbarem Sperrstatus sind konfigurierbar:

```yaml
authserver:
    provider:
        smcB:
            ocspConnectTimeoutMs: 1000    # Connect-Timeout der OCSP-Anfrage (ms)
            ocspReadTimeoutMs: 3000       # Read-Timeout der OCSP-Anfrage (ms)
            ocspFailClosed: false         # nur bei REVOKED ablehnen; unbestimmter Status erlaubt (fail-open)
```

| Value                                           | Beschreibung                                                         | Standard |
|-------------------------------------------------|----------------------------------------------------------------------|----------|
| `authserver.provider.smcB.ocspConnectTimeoutMs` | Connect-Timeout der SMC-B-OCSP-Anfrage in Millisekunden              | `1000`   |
| `authserver.provider.smcB.ocspReadTimeoutMs`    | Read-Timeout der SMC-B-OCSP-Anfrage in Millisekunden                 | `3000`   |
| `authserver.provider.smcB.ocspFailClosed`       | Zusätzlich ablehnen, wenn der Sperrstatus nicht bestimmt werden kann | `false`  |

> **Hinweis (fail-open / fail-closed):** Standardmäßig (`ocspFailClosed: false`)
> gilt **fail-open**: Nur ein **gesperrtes** (`REVOKED`) Zertifikat führt zur
> Ablehnung (`invalid_token`); ein nicht eindeutig bestimmbarer Status —
> OCSP-Responder nicht erreichbar, Timeout, oder `unknown` — wird **erlaubt**,
> damit der Token-Exchange bei einem OCSP-Ausfall oder Wartungsfenster
> betriebsfähig bleibt. Mit `ocspFailClosed: true` wird zusätzlich abgelehnt,
> wenn der Sperrstatus nicht bestimmt werden kann (strenger, gemäß TUC_PKI_006,
> gemSpec_PKI). Ein `REVOKED`-Zertifikat wird unabhängig von dieser Einstellung
> immer abgelehnt. **`ocspFailClosed` wirkt erst ab Chart 1.3.2** — in 1.3.0/1.3.1
> wurde der Wert zwar angenommen, aber nicht an den Authserver durchgereicht,
> sodass dort immer fail-open galt. Ist kein OCSP-Signer-Truststore hinterlegt, ist die Prüfung
> deaktiviert und der Token-Exchange läuft ohne Sperrprüfung (nur für
> Testumgebungen).

---

### Spree Integrity Provider (VAU)

Konfiguration des Spree Integrity Providers (VAU-DB-Verschlüsselung und
Integritätsprüfungen):

```yaml
authserver:
    dbEnc:
        enabled: false
        columnEncryptionEnabled: true
        integrityChecksEnabled: true
        integrityRowChecksEnabled: true
        integrityTableChecksEnabled: true
        periodicRowChecksEnabled: false
        lockdownOnError: false
        shutdownOnError: false
        automaticCryptoUpdatesEnabled: false
        bootstrapInterval: "PT30S"
        bootstrapAttempts: 15
        keychainFileName: ""
        futureKeychainFileName: ""
        previousKeychainFileName: ""
        keychainGenerator:
            extraVolumeMounts: []
    hsm:
        dbEnc:
            keyId: ""
```

| Value                                                  | Beschreibung                                                                                                                                                                                                   | Standard |
|--------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `authserver.dbEnc.enabled`                             | Aktivierung des Spree Integrity Providers                                                                                                                                                                      | `false`  |
| `authserver.dbEnc.integrityChecksEnabled`              | Aktivierung von Integritätsprüfungen und Verschlüsselung global                                                                                                                                                | `true`   |
| `authserver.dbEnc.columnEncryptionEnabled`             | Aktivierung der Spaltenverschlüsselung gemäß Konfiguration auf Entitätsebene                                                                                                                                   | `true`   |
| `authserver.dbEnc.integrityRowChecksEnabled`           | Aktivierung von Integritätsprüfungen auf Datenbank-Zeilenebene                                                                                                                                                 | `true`   |
| `authserver.dbEnc.integrityTableChecksEnabled`         | Aktivierung von Integritätsprüfungen auf Tabellenebene                                                                                                                                                         | `true`   |
| `authserver.dbEnc.periodicRowChecksEnabled`            | Aktivierung der periodischen Integritätsprüfung auf Datenbank-Zeilenebene; bei Deaktivierung wird weiterhin bei jedem direkten Zugriff geprüft                                                                 | `false`  |
| `authserver.dbEnc.lockdownOnError`                     | Aktivierung eines internen Fehlerstates, in dem der Authserver weitere Anfragen abweist                                                                                                                        | `false`  |
| `authserver.dbEnc.shutdownOnError`                     | Automatisches Herunterfahren des Authservers, wenn Integritätsprüfungen fehlschlagen                                                                                                                           | `false`  |
| `authserver.dbEnc.automaticCryptoUpdatesEnabled`       | Automatischer Start der Umschlüsselung, sobald der Authserver einen Wechsel der aktiven Keychain erkennt; erfordert `previousKeychainFileName`. Bei `false` starten Sie die Umschlüsselung über die Admin-API. | `false`  |
| `authserver.dbEnc.bootstrapAttempts`                   | Anzahl der Versuche das System zu initialisieren                                                                                                                                                               | `15`     |
| `authserver.dbEnc.bootstrapInterval`                   | Intervall zwischen den Initialisierungsversuchen                                                                                                                                                               | `PT30S`  |
| `authserver.dbEnc.keychainFileName`                    | Pfad zur aktiven Keychain-Datei im Container                                                                                                                                                                   | `""`     |
| `authserver.dbEnc.futureKeychainFileName`              | Pfad zur angekündigten Keychain-Datei; nur während einer Schlüsselrotation gesetzt                                                                                                                             | `""`     |
| `authserver.dbEnc.previousKeychainFileName`            | Pfad zur abgelösten Keychain-Datei; nur während einer Schlüsselrotation gesetzt, bis die Umschlüsselung abgeschlossen ist                                                                                      | `""`     |
| `authserver.dbEnc.keychainGenerator.extraVolumeMounts` | Zusätzliche Volume-Mounts für den Keychain-Generator (Einhängen der Keychain-Datei)                                                                                                                            | `[]`     |
| `authserver.hsm.dbEnc.keyId`                           | ID des KEK im HSM. Der Keychain-Generator benötigt sie; im Authserver gilt sie für Keychain-Dateien ohne eigene KEK-ID.                                                                                        | `""`     |

Die Keychain-Dateien werden über `authserver.extraVolumes` aus einem Secret
bereitgestellt und über `authserver.container.extraVolumeMounts` in den
Authserver-Container eingehängt. Ein vollständiges Beispiel siehe
[Wie Sie ZETA-Guard in Kubernetes konfigurieren, Abschnitt 10](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#10-besonderheiten-vau-und-keycloak-datenbank).
Wie Sie `futureKeychainFileName` und `previousKeychainFileName` für einen
Schlüsselwechsel verwenden, beschreibt
[Wie Sie die Schlüssel der VAU-Datenbank rotieren](../Anleitungen/Wie_Sie_die_Schlüssel_der_VAU-Datenbank_rotieren.md).

### Mobiler Client-Flow (OIDC)

```yaml
authserver:
    config:
        oidcFlowEnabled: true
        entityStatement:
            clientName: "zeta-guard"
            organizationName: "<Betreiber>"
            contactEmail: "<kontakt@betreiber.example>"
            # optional; leer = Redirect-URIs der SekIDP-Clients des Realms
            redirectUris:
                - "https://<app.betreiber.example>/cb/oidc"
    additionalTrustedCAs:
        - secretName: <secret-mit-ca>
          secretKey: ca.crt
```

| Value                                                | Beschreibung                                                                                                                                                                                                                                                                       | Standard |
|------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `authserver.config.oidcFlowEnabled`                  | Schaltet den [mobilen Client-Flow](../Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md) frei (setzt die Umgebungsvariable `ZETA_OIDC_FLOW_ENABLED` am Authserver).                                                                                                           | `false`  |
| `authserver.config.entityStatement.clientName`       | `client_name` in den `openid_relying_party`-Metadaten (A_23034-02) und `name` in den `federation_entity`-Metadaten (gemSpec_IDP_Sek, Tab. 28) des Entity Statements des Guards. Erforderlich bei `oidcFlowEnabled: true`.                                                          | —        |
| `authserver.config.entityStatement.organizationName` | `organization_name` in den `openid_relying_party`- und `federation_entity`-Metadaten (gemSpec_IDP_Sek, Tab. 28) des Entity Statements des Guards. Erforderlich bei `oidcFlowEnabled: true`.                                                                                        | —        |
| `authserver.config.entityStatement.contactEmail`     | Kontaktadresse im Entity Statement des Guards. Erforderlich bei `oidcFlowEnabled: true`.                                                                                                                                                                                           | —        |
| `authserver.config.entityStatement.redirectUris`     | Feste Liste der `redirect_uris` in den `openid_relying_party`-Metadaten des Entity Statements (A_25656, setzt `ENTITY_STATEMENT_REDIRECT_URIS`). Leer = die Redirect-URIs der SekIDP-Clients des Realms.                                                                           | `[]`     |
| `authserver.additionalTrustedCAs`                    | CA-Zertifikate, denen Keycloak für eigene ausgehende HTTPS-Aufrufe vertraut, etwa zu Federation Master und SekIDP. Je Eintrag entweder `secretName` + `secretKey` (vorhandenes Secret) oder `cert` (PEM inline, das Chart legt das Secret an). Leer = Standard-Truststore der JVM. | `[]`     |

Den Identity Provider `zeta-sekidp-oidc` legt die PDP-Konfiguration an —
siehe `enable_sekidp` und `sekidp_client_id` unter
[Terraform-Konfiguration (PDP)](#terraform-konfiguration-pdp). Die URL des
Federation Masters kommt aus dem Provisioning Processor, siehe
[Federation Master für den mobilen Client-Flow](#federation-master-für-den-mobilen-client-flow). Für den
OTP-Versand der E-Mail-Bindung muss zusätzlich SMTP im Realm konfiguriert sein
(SMTP-Variablen ebendort).

#### mTLS für Resource Server (`userinfo/email`)

```yaml
authserver:
    resourceServerMtls:
        enabled: false
        truststore:
            secretName: ""
            secretKey: ca.pem
        truststorePassword:
            secretName: ""
            secretKey: ""
        verifyDepth: 3
```

Ein Resource Server ruft die verifizierte E-Mail-Adresse eines Versicherten über
`GET /auth/realms/<realm>/zeta/userinfo/email?id=<KVNR>` ab und authentisiert
sich dabei mit einem TLS-Client-Zertifikat. Ist die Option aktiv, fordert der
Ingress auf `authserver.hostname` von jedem Client optional ein Zertifikat an
(`ssl_verify_client optional_no_ca`). Er prüft es nicht selbst, sondern reicht es
im Header `ssl-client-cert` an den Authserver weiter. Der Authserver prüft die
Zertifikatskette gegen den Resource-Server-Truststore.

| Value                                                 | Beschreibung                                                                                                                                                                                                                                                                      | Standard |
|-------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `authserver.resourceServerMtls.enabled`               | Client-Zertifikate von Resource Servern anfordern und weiterreichen. Setzt `authserver.config.oidcFlowEnabled: true` voraus.                                                                                                                                                      | `false`  |
| `authserver.resourceServerMtls.truststore.secretName` | Bestehendes Secret mit dem eigenen Truststore für Resource Server. Jedes enthaltene Zertifikat ist ein Vertrauensanker. Leer: Es gilt Keycloaks HTTPS-Truststore (`KC_HTTPS_TRUST_STORE_FILE`). Ist keiner von beiden gesetzt, beantwortet `userinfo/email` jede Anfrage mit 401. | `""`     |
| `authserver.resourceServerMtls.truststore.secretKey`  | Schlüssel im Secret. Die Endung bestimmt das Format: `.p12`/`.pfx` (PKCS12), `.jks`, alles andere ist ein PEM-Bundle.                                                                                                                                                             | `ca.pem` |
| `authserver.resourceServerMtls.truststorePassword.*`  | Secret mit dem Truststore-Passwort, nur für PKCS12 und JKS.                                                                                                                                                                                                                       | `""`     |
| `authserver.resourceServerMtls.verifyDepth`           | `ssl_verify_depth` des Ingress: die längste Zertifikatskette, die ein Resource Server vorlegen darf.                                                                                                                                                                              | `3`      |

##### Eigenen Truststore verwenden

Ohne `truststore.secretName` prüft der Authserver gegen Keycloaks
HTTPS-Truststore. Einen eigenen Truststore für Resource Server legen Sie als
Secret im Namespace des Authservers an und verweisen in den Values darauf.

**PEM-Bundle** (ein oder mehrere Zertifikate in einer Datei, kein Passwort):

```bash
kubectl -n <namespace> create secret generic resource-server-truststore \
  --from-file=ca.pem=resource-server-cas.pem
```

```yaml
authserver:
    resourceServerMtls:
        enabled: true
        truststore:
            secretName: resource-server-truststore
            secretKey: ca.pem
```

**PKCS12** (zusätzlich ein Secret mit dem Passwort). Die Endung von `secretKey`
muss `.p12` oder `.pfx` lauten, sonst wird die Datei als PEM gelesen:

```bash
kubectl -n <namespace> create secret generic resource-server-truststore \
  --from-file=truststore.p12=resource-server-cas.p12
kubectl -n <namespace> create secret generic resource-server-truststore-pw \
  --from-file=password=resource-server-cas.pw
```

```yaml
authserver:
    resourceServerMtls:
        enabled: true
        truststore:
            secretName: resource-server-truststore
            secretKey: truststore.p12
        truststorePassword:
            secretName: resource-server-truststore-pw
            secretKey: password
```

Ein JKS-Truststore funktioniert genauso, mit der Endung `.jks`.

Der Authserver liest den Truststore nur beim Start. Nach einer Änderung des
Secrets starten Sie ihn neu (`kubectl -n <namespace> rollout restart
deployment/authserver`). Welcher Truststore aktiv ist, steht im Log des
Authservers:

```text
Resource server truststore »/opt/keycloak/conf/resource-server-truststore/ca.pem« (resourceServerTruststoreFile) loaded with 1 certificates
```

In Klammern steht `resourceServerTruststoreFile` für den eigenen Truststore und
`https-trust-store-file`, wenn der Default greift. Ist keiner von beiden
gesetzt, erscheint stattdessen die Warnung `No resource server truststore
configured, userinfo/email rejects every request`. Ist der eigene Truststore
gesetzt, aber nicht lesbar (falsches Passwort, keine Zertifikate), bricht der
Start ab.

> **Hinweis:** Legen Sie die Resource-Server-CA **nicht** über
> `authserver.additionalTrustedCAs` ab. Alles dort gilt auch für ausgehende
> Verbindungen des Authservers.

> **Hinweis zu Log-Meldungen:** Das Chart setzt am Authserver den
> `x509cert-lookup`-Provider `nginx` mit `trust-proxy-verification=false`. Bei
> `true` würde Keycloak zusätzlich den Header `ssl-client-verify: SUCCESS`
> verlangen. Den sendet ein Ingress mit `optional_no_ca` nie, und jede Anfrage
> würde mit 401 abgelehnt. Mit `false` versucht Keycloak, die Zertifikatskette
> aus seinem eigenen Truststore neu aufzubauen. Für die Resource-Server-CA
> scheitert das. Deshalb erzeugt `NginxProxySslClientCertificateLookup` bei
> jedem Aufruf mit Client-Zertifikat zwei Meldungen: `WARN` „No issuer
> certificate for certificate in certification path found.“ und `INFO`
> „Impossible to rebuild end user cert chain : client certificate
> authentication will fail.“ Beide sind erwartet und harmlos. Die zweite trifft
> hier nicht zu: Das Zertifikat wird trotzdem weitergereicht und gegen den
> Resource-Server-Truststore geprüft.
>
> Das Authserver-Image stuft genau diese beiden Meldungen dieses einen Loggers
> auf `DEBUG` herab; alle anderen Meldungen und `ERROR` generell bleiben
> unverändert. Um sie wieder zu sehen, ergänzen Sie `authserver.log.level` um
> `org.keycloak.services.x509.NginxProxySslClientCertificateLookup:debug`, zum
> Beispiel `INFO,org.keycloak.services.x509.NginxProxySslClientCertificateLookup:debug`.

`ssl_verify_client optional_no_ca` gilt für den gesamten Host. Browser, auf denen
Client-Zertifikate installiert sind, können deshalb einen Auswahldialog zeigen.
Bestehende `nginx.org/server-snippets` aus `ingressMasterAnnotations` bleiben
erhalten; das Chart stellt seine Direktiven davor.

Den Header `ssl-client-cert` setzt der Ingress bei jeder Anfrage an `/auth`
selbst, auch wenn die Option aus ist. Er überschreibt damit einen vom Client
mitgeschickten Header. Der mitgelieferte NGINX Ingress Controller entfernt den
Header zusätzlich über `more_clear_input_headers`. Setzen Sie einen eigenen
Ingress Controller ein, müssen Sie dasselbe sicherstellen. Außerdem darf den
Authserver nichts unter Umgehung des Ingress mit einem gefälschten Header
erreichen (NetworkPolicies, `proxy-trusted-addresses`).

## PEP-Proxy

### ServiceAccount

```yaml
pepproxy:
    serviceAccount:
        create: true
        name: pep-proxy
```

### Replicas und Sticky Sessions

```yaml
pepproxy:
    replicaCount: 3
```

Der Standardwert ist `1`. Bei `replicaCount > 1` werden Sticky Sessions
automatisch über den mitgelieferten NGINX Ingress Controller realisiert: NIC
setzt beim ersten Request ein opakes `zeta_route`-Cookie und routet
nachfolgende Requests desselben Clients via Consistent Hashing konsistent auf
denselben PEP-Pod. Dies ist eine Sicherheitsanforderung, da der
ASL-Session-Cache pro Pod im nginx-Shared-Memory liegt und nicht zwischen Pods
geteilt wird. Voraussetzung: Der Client unterstützt HTTP-Cookies.

Wird ein anderer Ingress-Controller verwendet (`nginxIngressEnabled: false`),
muss der Betreiber Sticky Sessions am eigenen Ingress-Layer sicherstellen.

### Client-IP-Ermittlung und Forwarding-Header

Der Authserver leitet den `ip_address`-Claim des Access-Tokens aus den Headern
`Forwarded`, `X-Forwarded-For` und `X-Real-IP` ab (in dieser Reihenfolge, erst
danach aus der TCP-Quelladresse). Der PEP prüft diesen Claim bei aktivierter
No-Travel-Prüfung (`pepproxy.nginxConf.noTravel`) gegen die Adresse jeder
Anfrage. Der mitgelieferte Ingress-Controller verwirft client-gesetzte
Forwarding-Header deshalb an der Außengrenze — umgesetzt im Value
`nginx-ingress.controller.config.entries.http-snippets`.

Wird ein anderer Ingress-Controller verwendet (`nginxIngressEnabled: false`),
muss der Betreiber diese Header selbst verwerfen oder durch vertrauenswürdige
Werte ersetzen. Andernfalls kann ein Client seine IP-Adresse frei wählen und
damit die No-Travel-Prüfung sowie ein IP-basiertes Rate Limit umgehen.
Die vollständige Header-Liste und der Sonderfall eines vorgelagerten
vertrauenswürdigen Proxys sind beschrieben in
[Client-seitige Forwarding-Header verwerfen](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#client-seitige-forwarding-header-verwerfen).

### Security Context

```yaml
pepproxy:
    podSecurityContext:
        seccompProfile:
            type: RuntimeDefault
```

### Well-Known-Discovery-Dokument

Der PEP-Proxy stellt das OAuth-Protected-Resource-Metadata-Dokument (RFC 9728)
unter `/.well-known/oauth-protected-resource` bereit. Die Pfadanteile der beiden
enthaltenen URLs sind konfigurierbar:

```yaml
pepproxy:
    wellKnownBase: "https://zeta.example.com"   # öffentliche Basis-URL des PEP
    wellKnownResourceSuffix: /pep/              # Pfad-Suffix für das resource-Feld
authserver:
    hostname: "zeta.example.com"
    wellKnownAuthServerPath: /                  # Pfad-Suffix für authorization_servers
```

Das erzeugte Dokument hat dann folgendes Format:

```json
{
    "resource": "https://zeta.example.com/pep/",
    "authorization_servers": [
        "https://zeta.example.com/"
    ],
    "zeta_asl_use": "required"
}
```

Das Feld `zeta_asl_use` wird aus `pepproxy.asl_enabled` abgeleitet und ist nicht
fest `required`: Bei deaktiviertem ASL — dem Standard — weist das Dokument
`not_supported` aus.

| Value                                | Beschreibung                                                                                   | Standard           |
|--------------------------------------|------------------------------------------------------------------------------------------------|--------------------|
| `pepproxy.wellKnownBase`             | Extern erreichbare Basis-URL des PEP (fließt in das `resource`-Feld ein)                       | `http://localhost` |
| `pepproxy.wellKnownResourceSuffix`   | Pfad-Suffix, der an `wellKnownBase` angehängt wird (inkl. führendem und abschließendem `/`)    | `/pep/`            |
| `authserver.wellKnownAuthServerPath` | Pfad-Suffix, der an `authserver.hostname` für das `authorization_servers`-Array angehängt wird | `/`                |
| `pepproxy.asl_enabled`               | Steuert das Feld `zeta_asl_use`: `true` ergibt `required`, `false` ergibt `not_supported`      | `false`            |

> **Achtung:** Der Default `http://localhost` ist nur für lokale Setups (KIND)
> gedacht und **muss** in jeder erreichbaren Umgebung überschrieben werden –
> anderenfalls enthält `resource` eine von außen unerreichbare URL und
> Token-Prüfungen schlagen fehl.
>
> Die beiden URLs werden durch einfache Verkettung ohne Normalisierung
> gebildet (`resource = wellKnownBase + wellKnownResourceSuffix`). Ein Schema im
> `hostname`, ein doppelter `/` oder ein doppelter Pfadanteil (z. B.
> `/pep/pep/`) landet unverändert im Dokument und kann zu doppelten
> Well-Knowns führen.

> **Hinweis:** Bei Deployments, bei denen Keycloak unter einem Unterpfad wie
> `/auth` betrieben wird, ist
> `authserver.wellKnownAuthServerPath: /auth` zu setzen. Wenn die Protected
> Resource direkt unter der Root-URL erreichbar ist, genügt
> `pepproxy.wellKnownResourceSuffix: /`.

Wann und warum von diesen Defaults abzuweichen ist, welche
Konfigurationsszenarien es gibt und wie doppelte Well-Knowns entstehen, ist
ausführlich in
[Konfiguration der Well-Known-Endpunkte](Konfiguration_der_Well-Known_Endpunkte.md)
beschrieben.

### PoPP-Token-Validierung

Steuert die Validierung des PoPP-Tokens am PEP (A_26477). Ist
`pepproxy.nginxConf.poppIssuer` gesetzt, verlangt der PEP auf allen Locations
das Vorhandensein des `PoPP`-Headers und validiert das Token
(`pep_require_popp on;`); mit `null` ist die PoPP-Prüfung deaktiviert.
`pepproxy.nginxConf.poppValidity` legt die Gültigkeitsdauer des Tokens ab
Ausstellung fest — `quarter` (selbes Kalenderquartal) oder eine feste Dauer
seit `iat` mit Einheit `d`/`h`/`m`/`s` (z. B. `1d`, `86400`).

| Value                             | Beschreibung                                                                                                                                                | Standard  |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|
| `pepproxy.nginxConf.poppIssuer`   | Issuer des PoPP-Servers (Entity Statement unter `/.well-known/openid-federation`). Wenn gesetzt, wird PoPP verlangt und validiert; `null` deaktiviert PoPP. | `null`    |
| `pepproxy.nginxConf.poppValidity` | Gültigkeitsdauer des PoPP-Tokens ab `iat`: `quarter` oder feste Dauer (`d`/`h`/`m`/`s`, Standardeinheit `s`).                                               | `quarter` |

Details zu den PEP-Direktiven `pep_require_popp` und `pep_popp_validity` siehe
[PEP-Konfiguration](Konfiguration_des_PEP_Http_Proxy.md).

### nginx-Konfiguration (Fachdienst-Routing)

Das Chart kann die nginx-ConfigMap des PEP-Proxy aus Values generieren
(`generateConfigMap: true`). Die daraus resultierende Konfiguration steuert,
wie eingehende Requests an den Resource Server (Fachdienst) weitergeleitet
werden.

| Value                                             | Beschreibung                                                                                                                                                                                                                                                                                                                                                                                   | Standard                                   |
|---------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------|
| `pepproxy.nginxConf.generateConfigMap`            | Wenn `true`, generiert das Chart die nginx-ConfigMap aus den untenstehenden Values. Bei `false` muss eine ConfigMap mit dem Namen `configMapName` extern bereitgestellt werden; alle weiteren `nginxConf.*`-Values werden dann ignoriert.                                                                                                                                                      | `false`                                    |
| `pepproxy.nginxConf.configMapName`                | Name der ConfigMap, die in den PEP-Pod gemountet wird — unabhängig davon, ob das Chart sie generiert oder sie extern existiert.                                                                                                                                                                                                                                                                | `pep-nginx-conf`                           |
| `pepproxy.nginxConf.pepIssuer`                    | Öffentlicher OIDC-Issuer des Authorization Servers. Immer der `iss`, den der PEP in Access-Tokens erwartet (`pep_pdp_issuer`). Solange `pepInternalUrl` nicht gesetzt ist, dient er zusätzlich als Basis-URL für OIDC-Discovery und JWKS-Abruf.                                                                                                                                                | `""`                                       |
| `pepproxy.nginxConf.pepInternalUrl`               | Clusterinterne Adresse des Authservers, ausschließlich für OIDC-Discovery und JWKS-Abruf (`pep_pdp_url`). Standardmäßig leer: Beide Abrufe laufen über den öffentlichen `pepIssuer` und damit durch die vorgelagerte Infrastruktur. Empfohlen ist `http://authserver/auth/realms/zeta-guard` (PEP-Image ab 2.0.0). Muss die Pfadstruktur des Issuers spiegeln.                                 | `""`                                       |
| `pepproxy.nginxConf.requiredAudience`             | Audience, die ein gültiges Access-Token enthalten muss (`pep_require_aud`).                                                                                                                                                                                                                                                                                                                    | `""`                                       |
| `pepproxy.nginxConf.requiredScopes`               | Liste der geforderten Scopes (`pep_require_scope`).                                                                                                                                                                                                                                                                                                                                            | `[]`                                       |
| `pepproxy.nginxConf.proxyLocations`               | Strukturierte Definition der Fachdienst-Pfade (siehe unten). Kann nicht zusammen mit `locations` verwendet werden.                                                                                                                                                                                                                                                                             | `[]`                                       |
| `pepproxy.nginxConf.locations`                    | **Deprecated und zur Entfernung vorgesehen.** Roher nginx-Location-Block als Go-Template-String. Schließt sich mit `proxyLocations` aus (siehe Hinweis unten).                                                                                                                                                                                                                                 | `""`                                       |
| `pepproxy.nginxConf.fachdienstUrl`                | **Deprecated.** Optionale Hilfsvariable, die im `locations`-Template referenziert werden kann.                                                                                                                                                                                                                                                                                                 | `""`                                       |
| `pepproxy.nginxConf.httpClientAcceptInvalidCerts` | Akzeptiert ungültige TLS-Zertifikate bei internen HTTP-Verbindungen des PEP (JWKS, OIDC Discovery). **Nur für Testumgebungen.**                                                                                                                                                                                                                                                                | `false`                                    |
| `pepproxy.nginxConf.aslTestmode`                  | Aktiviert den ASL-Testmodus (deaktiviert Verschlüsselung). **Niemals in Produktion setzen.**                                                                                                                                                                                                                                                                                                   | `false`                                    |
| `pepproxy.nginxConf.noTravel`                     | Aktiviert (`true`) oder deaktiviert (`false`) die No-Travel-Prüfung (IP-Bindung).                                                                                                                                                                                                                                                                                                              | `true`                                     |

> **Hinweis zu `noTravel`:** Das Chart schaltet die Prüfung standardmäßig ein;
> eine Session ist damit an die IP-Adresse gebunden, mit der das Token
> ausgestellt wurde. Die IP-Bindung ist nur so verlässlich wie die Ermittlung
> der Client-IP-Adresse an der Außengrenze — siehe
> [Client-IP-Ermittlung und Forwarding-Header](#client-ip-ermittlung-und-forwarding-header).

#### ASL-Values

Diese Values liegen direkt unter `pepproxy` (nicht unter `nginxConf`) und
wirken nur bei `pepproxy.asl_enabled: true`. Die Pfade zu Signer-Identität und
roots.json setzt das Chart selbst; die folgenden drei Values schreibt es nur in
die nginx.conf, wenn sie gesetzt sind — andernfalls gelten die Standardwerte des
PEP-Moduls. Leere Strings sind nicht erlaubt (Schema: `minLength: 1`).

| Value                  | Beschreibung                                                                                                                                                 | Standard                         |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------|
| `pepproxy.asl_enabled` | Aktiviert ASL im PEP: mountet die Signer-Identität und schreibt die `pep_asl_*`-Direktiven in die nginx.conf. Steuert außerdem `zeta_asl_use` im Well-Known. | `false`                          |
| `pepproxy.aslRootCA`   | CN einer anderen Root-CA aus roots.json anstelle von GEM.RCA7 (`pep_asl_root_ca`). Nur für Testumgebungen, z. B. `GEM.RCA7 TEST-ONLY`.                       | nicht gesetzt (GEM.RCA7)         |
| `pepproxy.aslOcsp`     | OCSP Stapling für das ASL-Signer-Zertifikat (`pep_asl_ocsp`): `cert`, `off` oder eine Responder-URL als Override.                                            | nicht gesetzt (wirkt wie `cert`) |
| `pepproxy.aslOcspTtl`  | Maximale Cache-Gültigkeit einer OCSP-Antwort (`pep_asl_ocsp_ttl`), z. B. `5m` oder `24h`. Standardeinheit ohne Suffix: Minuten.                              | nicht gesetzt (wirkt wie `24h`)  |

Zur Bedeutung der erzeugten Direktiven und zur Alle-oder-keine-Regel der
Datei-Direktiven siehe
[PEP-Konfiguration — Konfigurationsparameter (ASL)](Konfiguration_des_PEP_Http_Proxy.md#konfigurationsparameter-asl).

> **Migration von `locations` auf `proxyLocations`:** Der rohe
> `locations`-String ist veraltet und wird entfernt, sobald alle Umgebungen
> migriert sind. Beide Values gleichzeitig zu setzen ist kein Konfigurationsfehler
> mit stiller Vorrangregel, sondern **bricht das Rendern des Charts ab**:
>
> ```
> pepproxy.nginxConf: `locations` and `proxyLocations` are mutually exclusive —
> migrate the remaining raw `locations` to `proxyLocations`
> ```
>
> Eine schrittweise Migration einzelner Pfade ist damit nicht möglich; die
> Umstellung erfolgt für alle Pfade eines Deployments gemeinsam. `fachdienstUrl`
> dient ausschließlich dem `locations`-Template und entfällt mit ihm.

#### proxyLocations

Jeder Eintrag in `proxyLocations` generiert einen nginx-`upstream`-Block
(mit Connection Keepalive) sowie ein Location-Paar (exact match + prefix).
`proxy_headers.conf` wird automatisch eingebunden.

```yaml
pepproxy:
    nginxConf:
        proxyLocations:
            - path: /pep
              upstream: https://fachdienst:443
              upstreamPath: /
              websocket: false
              bypassAsl: false
              keepalive: 32
              extraConfig: |
                  proxy_ssl_verify on;
```

| Feld           | Pflicht | Beschreibung                                                                                                        | Standard |
|----------------|---------|---------------------------------------------------------------------------------------------------------------------|----------|
| `path`         | ja      | Öffentlicher Pfad; muss mit `/` beginnen, darf nicht mit `/` enden.                                                 |          |
| `upstream`     | ja      | `scheme://host[:port]` des Backends — ohne Pfadanteil.                                                              |          |
| `upstreamPath` | nein    | URI-Präfix auf dem Backend.                                                                                         | `/`      |
| `websocket`    | nein    | WebSocket-Upgrade-Handling und Routing über den dedizierten Ingress-WebSocket-Minion.                               | `false`  |
| `bypassAsl`    | nein    | Macht den Pfad ohne ASL erreichbar (`satisfy all; allow all;`). Nur wenn die Fachdienst-Spezifikation dies erlaubt. | `false`  |
| `keepalive`    | nein    | Idle-Upstream-Verbindungen pro nginx-Worker.                                                                        | `32`     |
| `extraConfig`  | nein    | Zusätzliche nginx-Direktiven (als Go-Template gerendert), z. B. `proxy_ssl_*` für mTLS.                             | `""`     |

Details zu den vom PEP gesetzten nginx-Direktiven (`pep on`, `pep_require_aud`,
`proxy_headers.conf`) siehe
[PEP-Konfiguration](Konfiguration_des_PEP_Http_Proxy.md).
Für vollständige Konfigurationsbeispiele inkl. mTLS siehe
[Wie Sie ZETA-Guard in Kubernetes konfigurieren](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#7-policy-enforcement-point-nginx-konfigurieren).

### Clusterinterne Kommunikation mit dem Authserver

Der PEP validiert Access-Tokens gegen das JWKS des Authservers. Er findet dieses
JWKS, indem er `<pepIssuer>/.well-known/openid-configuration` abruft und
anschließend der dort ausgewiesenen `jwks_uri` folgt.

`pepIssuer` **muss** der öffentliche Issuer sein — es ist der `iss`, den der PEP
in jedem Access-Token erwartet. Ohne weitere Konfiguration laufen deshalb beide
Abrufe über den öffentlichen Hostnamen, verlassen den Cluster und kommen über
Load Balancer und Ingress wieder herein, obwohl der Authserver direkt neben dem
PEP läuft. In Multi-Cluster-Umgebungen kann das sogar zwischen Standorten
erfolgen.

`pepInternalUrl` hält diesen Verkehr im Cluster:

```yaml
pepproxy:
  nginxConf:
    # öffentlich — bleibt der erwartete `iss` der Access-Tokens
    pepIssuer: "https://<public-host>/auth/realms/zeta-guard"
    # intern — standardmäßig leer (aus); empfohlener Wert:
    pepInternalUrl: "http://authserver/auth/realms/zeta-guard"
```

Das Chart rendert daraus die nginx-Direktive `pep_pdp_url`. Die Discovery wird
dann über den clusterinternen Service abgerufen, und die vom Authserver
ausgewiesene `jwks_uri` wird vom öffentlichen Issuer-Präfix auf `pepInternalUrl`
umgeschrieben.

Hinweise:

- `pepInternalUrl` muss die **Pfadstruktur** des Issuers spiegeln, da nur das
  Issuer-Präfix ersetzt wird. Liegt die ausgewiesene `jwks_uri` nicht unterhalb
  von `pepIssuer`, ruft der PEP sie unverändert ab und protokolliert eine Warnung.
- Die Token-Validierung ändert sich nicht, und die Issuer-Prüfung bleibt scharf.
  Über den internen Service würde Keycloak das Schema sonst aus dem Request
  ableiten und `http://…` ausweisen, wo der PEP `https://…` erwartet. Der PEP
  sendet bei diesen beiden Abrufen deshalb die Origin des öffentlichen Issuers
  (`Host`, `X-Forwarded-Proto`, `X-Forwarded-Host`), sodass der Authserver seine
  Frontend-URLs genau wie bei öffentlichem Verkehr rendert.
- Der interne Hop kann unverschlüsseltes HTTP zum Service `authserver` sein; ein
  für den öffentlichen Hostnamen gültiges Zertifikat wird nicht benötigt.
- Der Kurzname `authserver` genügt, auch unter OpenShift. PEP und Authserver
  rollt das Chart immer gemeinsam in denselben Namespace aus, und Kubernetes löst
  Kurznamen innerhalb des Namespace über die Suchdomänen in `/etc/resolv.conf`
  auf. Der voll qualifizierte Name (`authserver.<namespace>.svc.cluster.local`)
  wird erst nötig, wenn der Authserver in einem anderen Namespace läuft. Dieselbe
  Adresse nutzt `pep_revocation_url` bereits unverändert in allen Umgebungen.
- Ältere PEP-Images kennen die Direktive nicht: Sie starten nicht und geben
  `unknown directive "pep_pdp_url"` aus. Nötig ist ein Image ab 2.0.0 — bei einem
  älteren Image (`pepproxy.image.tag` oder `pepproxy.image.digest` gepinnt)
  `pepInternalUrl` leer lassen.
- Bei aktivierten NetworkPolicies ist der nötige Egress (PEP → Authserver-Pod,
  Port 8080) bereits Teil von `pep-proxy-egress`.

#### Alternative: hostAliases

Lässt sich der interne Endpunkt nicht über den Service-Namen adressieren, kann
der Hostname stattdessen im PEP-Pod aufgelöst werden:

| Value                  | Beschreibung                                                                                                                                                                       | Standard |
|------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `pepproxy.hostAliases` | Zusätzliche `/etc/hosts`-Einträge für den PEP-Pod in nativer Kubernetes-Notation (`[{ip, hostnames: []}]`). Wird mit den Einträgen aus `global.enableDNSRedirect` zusammengeführt. | `[]`     |

```yaml
pepproxy:
  hostAliases:
    - ip: 10.96.1.23          # ClusterIP des *Ingress-Controllers*
      hostnames:
        - <public-host>
```

Dabei die ClusterIP des Ingress-Controllers eintragen, nicht die des Authservers:
Der PEP spricht weiterhin HTTPS mit dem öffentlichen Hostnamen, und nur der
Ingress-Controller liefert ein für diesen Namen gültiges Zertifikat.

`pepInternalUrl` ist vorzuziehen — es kommt ohne IP-Adresse aus (ClusterIPs sind
clusterspezifisch und ändern sich, wenn ein Service neu angelegt wird) und
vermeidet die TLS-Frage vollständig.

### HSM-Konfiguration (TLS)

Der PEP-Proxy kann TLS mit einem privaten Schlüssel terminieren, der im HSM
verbleibt. Dafür wird der OpenSSL-Provider `ossl_hsm` verwendet: Der private
Schlüssel verlässt das HSM zu keinem Zeitpunkt — die Signatur-Operationen des
TLS-Handshakes werden per gRPC an den HSM-Proxy delegiert. Das zugehörige
Zertifikat liegt als gewöhnliche PEM-Datei im Container vor.

```yaml
pepproxy:
    hsmProxyAddr: "https://hsm-proxy:50051"   # gRPC-Adresse des HSM-Proxy; null deaktiviert die HSM-Anbindung
    hsmTlsKeyId: "tls.p256"           # Schlüssel-ID des TLS-Schlüssels im HSM
    hsmTlsCert: "tls.p256.pem"        # zum HSM-Schlüssel passende Zertifikatsdatei (relativ zu /etc/nginx)
```

Ist `pepproxy.hsmProxyAddr` gesetzt,

- erhält der nginx-Container die Umgebungsvariable `HSM_PROXY_ADDR`, die der
  `ossl_hsm`-Provider ausliest,
- richtet sich die Verbindung zum HSM-Proxy nach dem Schema der Adresse:
  `https://` baut TLS auf und prüft das Zertifikat des HSM-Proxy gegen den
  Hostnamen und den System-Truststore des PEP-Images. `http://` oder eine
  Adresse ohne Schema ist nur für eine Loopback-Adresse zulässig; bei einer
  unverschlüsselten Adresse zu einem anderen Host startet der PEP nicht,
  es sei denn, `pepproxy.hsmProxyPlainTextAccepted` ist gesetzt, und
- öffnet der PEP zusätzlich zum HTTP-Listener (Port 8081) einen TLS-Listener auf
  Port 8443 mit `ssl_certificate_key "store:hsm:<hsmTlsKeyId>"` — der Schlüssel
  wird dabei nur über seine Schlüssel-ID im HSM referenziert.

| Value                                | Beschreibung                                                                                                                                                                                                                                                                        | Standard       |
|--------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|
| `pepproxy.hsmProxyAddr`              | gRPC-Adresse des HSM-Proxy. Wenn gesetzt, terminiert der PEP TLS auf Port 8443 mit dem HSM-Schlüssel `hsmTlsKeyId` über den `ossl_hsm`-Provider; `null` deaktiviert die HSM-Anbindung.                                                                                              | `null`         |
| `pepproxy.hsmProxyPlainTextAccepted` | Erlaubt einen unverschlüsselten gRPC-Kanal zu einem HSM-Proxy, der nicht auf der Loopback-Adresse liegt (`HSM_PROXY_ALLOW_PLAINTEXT=1`); der PEP protokolliert dann bei jedem Start eine Warnung. Nur setzen, wo das Netz selbst den Kanal schützt, z. B. `hsm-sim` im Testcluster. | `false`        |
| `pepproxy.hsmTlsKeyId`               | Schlüssel-ID des TLS-Schlüssels im HSM (`ssl_certificate_key "store:hsm:<hsmTlsKeyId>"`). Nur relevant, wenn `hsmProxyAddr` gesetzt ist.                                                                                                                                            | `tls.p256`     |
| `pepproxy.hsmTlsCert`                | Zum HSM-Schlüssel passende Zertifikatsdatei, relativ zu `/etc/nginx`. Die Standard-Datei ist im PEP-Image enthalten und passt zum HSM-Simulator; eigene Zertifikate werden per `extraVolumeMounts` gemountet.                                                                       | `tls.p256.pem` |

> **Hinweis:** Die Schlüssel-ID ist für die gRPC-Schnittstelle ein opaker
> String: Der HSM-Proxy muss die konfigurierte ID auf den passenden Schlüssel
> abbilden — wie der Schlüssel im HSM selbst benannt ist, spielt dabei keine
> Rolle. Das im PEP-Image enthaltene Standard-Zertifikat (`tls.p256.pem`) passt
> zum HSM-Simulator (`hsm-sim`); für ein produktives HSM muss das zum
> HSM-Schlüssel passende Zertifikat über `pepproxy.extraVolumes` /
> `pepproxy.extraVolumeMounts` in den Container gemountet und der Dateiname in
> `pepproxy.hsmTlsCert` eingetragen werden.

> **Hinweis:** Eine eigene CA für das Zertifikat des HSM-Proxy (`HSM_PROXY_CA`)
> und ein Client-Zertifikat für mTLS (`HSM_PROXY_CLIENT_CERT`,
> `HSM_PROXY_CLIENT_KEY`) unterstützt der `ossl_hsm`-Provider, das Helm-Chart
> setzt diese Variablen aber nicht.

> **Hinweis:** `nginx -s reload` initialisiert OpenSSL-Provider nicht neu.
> Änderungen an der HSM-/TLS-Konfiguration erfordern daher einen Neustart der
> betroffenen Pods.

Soll TLS stattdessen am Ingress (NIC) mit einem HSM-Schlüssel terminiert werden
(`nginxIngressHsm`), siehe
[Wie Sie eine VAU-Umgebung für Lasttests aufsetzen](../Anleitungen/Wie_Sie_eine_VAU_Umgebung_für_Lasttests_aufsetzen.md).

### HSM-Konfiguration (ASL-Signaturschlüssel)

Auch der ASL-Signaturschlüssel kann im HSM verbleiben, statt als Datei aus dem
Secret `asl-identity` gemountet zu werden:

```yaml
pepproxy:
    asl_enabled: true
    hsmProxyAddr: "https://hsm-proxy:50051"
    asl_hsm_key: "store:hsm:asl-signer.p256"   # zum Signaturzertifikat passender HSM-Schlüssel, Format store:hsm:<key-id>
```

| Value                  | Beschreibung                                                                                                                                                                                                                         | Standard |
|------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `pepproxy.asl_hsm_key` | ASL-Signaturschlüssel als URI `store:hsm:<key-id>`. Wenn gesetzt, lädt der PEP den Schlüssel über den `ossl_hsm`-Provider aus dem HSM; der Key `signer-key` im Secret `asl-identity` entfällt. Setzt `pepproxy.hsmProxyAddr` voraus. | `null`   |

> **Hinweis:** Nur der private Schlüssel wandert ins HSM. `signer-cert` und
> `issuer-cert` im Secret `asl-identity` bleiben erforderlich, und der
> HSM-Schlüssel muss zum Signaturzertifikat passen — dies wird nicht
> automatisch geprüft; ein nicht passendes Paar führt zu nachgelagert
> abgelehnten ASL-Signaturen.

Siehe auch
[Wie Sie ZETA-Guard in Kubernetes konfigurieren](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md).

### Extra Volumes

Über `pepproxy.extraVolumes` und `pepproxy.extraVolumeMounts` lassen sich
beliebige zusätzliche Volumes in den PEP-Container mounten — etwa das
Client-Zertifikat und den Truststore für mTLS zum Resource Server oder ein
eigenes TLS-Zertifikat für die HSM-Konfiguration.

| Value                        | Beschreibung                                                                          | Standard |
|------------------------------|---------------------------------------------------------------------------------------|----------|
| `pepproxy.extraVolumes`      | Zusätzliche `volumes`-Einträge des PEP-Pods (Kubernetes-Syntax, z. B. Secret-Volumes) | `[]`     |
| `pepproxy.extraVolumeMounts` | Zugehörige `volumeMounts`-Einträge des nginx-Containers                               | `[]`     |

Ein vollständiges Beispiel für mTLS zum Resource Server siehe
[Wie Sie ZETA-Guard in Kubernetes konfigurieren, Abschnitt 9](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#9-mtls-zum-resource-server-ohne-service-mesh).

---

## Infinispan

Infinispan wird über globale Values konfiguriert und kann entweder als
In-Cluster-Deployment oder als Verbindung zu einer externen Instanz genutzt
werden (siehe auch
[Wie Sie externen Infinispan konfigurieren](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_use_external_infinispan.md)).

Die Ressourcen des Infinispan-Deployments stammen aus dem eigenständigen
Subchart `infinispan-external`. Dieses ist eine Dependency des Umbrella-Charts
(Testumgebung `zeta-testenv`, Helm-Tag `infinispan-external`) und nicht des
`zeta-guard`-Charts. Das `zeta-guard`-Chart konsumiert die Values unter
`global.infinispanExternal.*` lediglich, um den Authserver zu konfigurieren
(„clusterless“-Modus, `KC_CACHE_REMOTE_*`). Bei einer Installation ohne dieses
Subchart müssen Sie deshalb eine selbst betriebene Instanz über
`remote.host`/`remote.port` angeben.

### Verbindung (Remote-Cache)

`remote.host` und `remote.port` steuern, ob das Chart Infinispan selbst deployt.
Sind beide Werte gesetzt, wird kein Infinispan-Deployment erzeugt und der
Authserver verbindet sich gegen die angegebene Adresse. Sind sie leer, deployt
das Subchart Infinispan und der Authserver verwendet den chart-internen Service
`infinispan:11222`. Die Werte wirken nur gemeinsam: Ist nur einer gesetzt, gilt
ebenfalls der Fallback `infinispan:11222`.

```yaml
global:
    infinispanExternal:
        enabled: false
        replicaCount: 3
        remote:
            host:   # z. B. "infinispan.infinispan.svc.cluster.local"
            port:   # z. B. 11222
```

| Value                                    | Beschreibung                                                           | Standard |
|------------------------------------------|------------------------------------------------------------------------|----------|
| `global.infinispanExternal.enabled`      | Externen Infinispan aktivieren, Authserver auf „clusterless“ umstellen | `false`  |
| `global.infinispanExternal.replicaCount` | Anzahl der Infinispan-Pods (nur bei chart-eigenem Deployment)          | `1`      |
| `global.infinispanExternal.remote.host`  | Host einer eigenständig betriebenen Infinispan-Instanz                 | leer     |
| `global.infinispanExternal.remote.port`  | Port dieser Instanz                                                    | leer     |

### Admin-Zugangsdaten

```yaml
global:
    infinispanExternal:
        admin:
            username: "please set me"
            password: "please set me"
            secretName:   # Name eines bestehenden Secrets mit Schlüsseln username/password
```

Ist `secretName` gesetzt, legt das Chart kein eigenes Secret an und der
Authserver liest die Zugangsdaten aus dem angegebenen Secret; andernfalls wird
das chart-eigene Secret `infinispan-admin` verwendet.

### Image

```yaml
global:
    infinispanExternal:
        image:
            repository: infinispan-zeta
            tag: "15.2"
        imagePullPolicy: Always
        imagePullSecrets: [ ]
```

### ServiceAccount

```yaml
global:
    infinispanExternal:
        serviceAccount:
            create: true
            name: infinispan
```

### PodDisruptionBudget

```yaml
global:
    infinispanExternal:
        podDisruptionBudget:
            enabled: true
            minAvailable: 1
```

### Security Contexts

```yaml
global:
    infinispanExternal:
        podSecurityContext:
            seccompProfile:
                type: RuntimeDefault
        containerSecurityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsNonRoot: true
            capabilities:
                drop: [ "ALL" ]
```

### JVM-Optionen

Zusätzliche JVM-Optionen können über `extraJavaOptions` konfiguriert werden. Die
Basis-Optionen für JGroups-Clustering werden automatisch gesetzt.

```yaml
global:
    infinispanExternal:
        extraJavaOptions: "-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"
```

### HSM-Konfiguration

Das TLS-Schlüsselmaterial von Infinispan kann optional über den HSM-Proxy
bezogen werden. Ist die HSM-Anbindung aktiviert, verwendet Infinispan einen
HSM-gestützten Keystore (`type`/`provider`: `HSMPROXY`) sowohl für den
Client-Endpunkt als auch für den `cluster-transport`-Realm (JGroups-mTLS).

```yaml
global:
    infinispanExternal:
        hsm:
            enabled: false   # HSM-gestütztes TLS für Infinispan aktivieren
            endpoint: ""     # gRPC-Adresse des HSM-Proxy, z. B. "hsm-sim:50051"
            keyId: ""        # TLS-Schlüssel-ID im HSM, z. B. "zeta-guard-infinispan-tls-es256-v1.p256"
            caCert: |        # CA-Zertifikat zur Validierung der HSM-TLS-Verbindungen
                -----BEGIN CERTIFICATE-----
                -----END CERTIFICATE-----
```

| Value                                    | Beschreibung                                                   | Standard |
|------------------------------------------|----------------------------------------------------------------|----------|
| `global.infinispanExternal.hsm.enabled`  | HSM-gestütztes TLS für Infinispan aktivieren                   | `false`  |
| `global.infinispanExternal.hsm.endpoint` | gRPC-Adresse des HSM-Proxy                                     | `""`     |
| `global.infinispanExternal.hsm.keyId`    | TLS-Schlüssel-ID im HSM                                        | `""`     |
| `global.infinispanExternal.hsm.caCert`   | PEM-CA-Zertifikat für die Validierung der HSM-TLS-Verbindungen | `""`     |

---

## OPA (Policy Engine)

Der Open Policy Agent trifft die Autorisierungsentscheidung, die der
Authorization Service beim Token-Exchange abfragt. Alle Values liegen unter
`opa`.

Dieser Abschnitt ist die reine Value-Referenz. Wie die Policy-Quelle gewählt
wird, wie der Zugriff auf eine private Registry eingerichtet wird und wie sich
fehlgeschlagene Bundle-Downloads diagnostizieren lassen, beschreibt die Anleitung
[Wie Sie OPA in ZETA-Guard konfigurieren](../Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md).

### Deployment und Betrieb

```yaml
opa:
    replicaCount: 2
    image:
        repository: opa
        tag: 1.21.3-static
```

| Value                                | Beschreibung                                                                                          | Standard         |
|--------------------------------------|-------------------------------------------------------------------------------------------------------|------------------|
| `opa.replicaCount`                   | Anzahl der OPA-Replicas. OPA ist zustandslos und horizontal skalierbar.                               | `1`              |
| `opa.image.repository`               | Image-Repository                                                                                      | `opa`            |
| `opa.image.tag`                      | Image-Tag                                                                                             | `1.21.3-static`  |
| `opa.image.registry`                 | Registry-Präfix. Nicht vorbelegt — ohne Angabe aus `global.registry_host` + `registry_name` gebildet. | —                |
| `opa.image.digest`                   | Digest-Pinning. Nicht vorbelegt; wird als `@<digest>` hinter den Tag gehängt.                         | —                |
| `opa.imagePullPolicy`                | Pull-Policy des OPA-Images                                                                            | `IfNotPresent`   |
| `opa.imagePullSecrets`               | Pull-Secrets für das OPA-Image                                                                        | `[]`             |
| `opa.serviceAccountName`             | Bestehenden ServiceAccount verwenden. Leer = Default-ServiceAccount.                                  | `""`             |
| `opa.resources`                      | Ressourcen des OPA-Containers                                                                         | s. u.            |
| `opa.health.liveness.periodSeconds`  | Intervall der Liveness-Probe in Sekunden                                                              | `20`             |
| `opa.health.readiness.periodSeconds` | Intervall der Readiness-Probe in Sekunden                                                             | `20`             |
| `opa.podLabels`                      | Zusätzliche Labels am OPA-Pod                                                                         | `{}`             |
| `opa.podAnnotations`                 | Zusätzliche Annotationen am OPA-Pod                                                                   | `{}`             |
| `opa.affinity`                       | Affinity-Regeln des OPA-Pods                                                                          | `{}`             |
| `opa.tolerations`                    | Tolerations des OPA-Pods                                                                              | `[]`             |
| `opa.containerSecurityContext`       | Abweichungen von `defaultContainerSecurityContext` für den OPA-Container (auch für `opa-simulation`)  | `{}`             |
| `opa.cronjobSecurityContext`         | Abweichungen von `defaultContainerSecurityContext` für die Token-Renewer-CronJobs                     | s. u.            |

Standardressourcen: `limits.memory: 1Gi`, `requests.cpu: 100m`,
`requests.memory: 200Mi`.

> **Hinweis zu `cronjobSecurityContext`:** Setzt nur `readOnlyRootFilesystem: false`,
> alles Übrige kommt aus
> [`defaultContainerSecurityContext`](#chartweiter-default-defaultcontainersecuritycontext) —
> auch `runAsUser`, das für das Standard-Image `google/cloud-sdk` von
> `opa.workloadIdentityFederation.worker.image` (läuft als root) nötig ist.

### Logging und Telemetrie

| Value                  | Beschreibung                                                                                                            | Standard |
|------------------------|-------------------------------------------------------------------------------------------------------------------------|----------|
| `opa.logLevel`         | Log-Level des OPA-Servers: `debug`, `info`, `warn` oder `error`                                                         | `info`   |
| `opa.logDecisions`     | Policy-Entscheidungen zusätzlich als Decision Logs auf die Konsole schreiben (an das Telemetry-Gateway gehen sie immer) | `false`  |
| `opa.logStatusUpdates` | Status-Updates (u. a. Bundle-Aktivierung) auf die Konsole schreiben                                                     | `false`  |

Die beiden folgenden Values liegen **nicht** unter `opa`, sondern auf der
Ebene des `zeta-guard`-Charts:

| Value                          | Beschreibung                                                       | Standard |
|--------------------------------|--------------------------------------------------------------------|----------|
| `opaStatusPrometheus`          | Status-Metriken zu Bundle und Plugins für Prometheus bereitstellen | `true`   |
| `opaDistributedTracingEnabled` | Distributed Tracing für OPA aktivieren                             | `true`   |

### Policy-Bundle

Im Bundle-Modus — dem Standard — lädt OPA seine Policies als OCI-Bundle aus einer
Registry. Ist `opa.bundle.enabled: false`, wird stattdessen die im Chart
hinterlegte Inline-Policy verwendet.

| Value                                   | Beschreibung                                                                                                | Standard                              |
|-----------------------------------------|-------------------------------------------------------------------------------------------------------------|---------------------------------------|
| `opa.bundle.enabled`                    | Policies als OCI-Bundle laden. `false` verwendet die Inline-Policy des Charts.                              | `true`                                |
| `opa.bundle.serviceName`                | Logischer Name des Registry-Service in der OPA-Konfiguration (z. B. `gar`, `gitlab`, `local-proxy`)         | `registry`                            |
| `opa.bundle.url`                        | Basis-URL der Registry                                                                                      | `https://europe-west3-docker.pkg.dev` |
| `opa.bundle.resource`                   | Voll qualifizierte Bundle-Referenz inkl. Registry-Host und Tag                                              | s. `values.yaml`                      |
| `opa.bundle.credentials.secretRef.name` | Secret in der Release-Namespace mit den Registry-Zugangsdaten. Im WIF-Modus leer lassen.                    | `""`                                  |
| `opa.bundle.polling.min_delay_seconds`  | Minimales Abrufintervall des Bundles in Sekunden                                                            | `60`                                  |
| `opa.bundle.polling.max_delay_seconds`  | Maximales Abrufintervall des Bundles in Sekunden                                                            | `60`                                  |
| `opa.bundleHealthCheck`                 | Readiness-Probe auf `/health?bundles=true` umstellen — der Pod wird erst `Ready`, wenn ein Bundle aktiv ist | `false`                               |

> **Achtung bei `bundleHealthCheck: true`:** Bei einem Rolling Update bedient der
> alte Pod weiter (der Rollout bleibt stehen, statt Schaden anzurichten). Ein
> *neu* eingeplanter Pod — nach Node-Drain oder Neustart — bleibt jedoch
> `NotReady`, solange die Registry nicht erreichbar ist. Bei `replicaCount: 1`
> fällt OPA damit aus.

### Signaturprüfung des Bundles

| Value                               | Beschreibung                                                                                                | Standard |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------|----------|
| `opa.bundle.verification.enabled`   | Signatur des Bundles prüfen                                                                                 | `true`   |
| `opa.bundle.verification.keyId`     | Schlüssel-ID des Signaturschlüssels; umgebungsspezifisch zu setzen                                          | `""`     |
| `opa.bundle.verification.algorithm` | Signaturalgorithmus, z. B. `ES256`                                                                          | `""`     |
| `opa.bundle.verification.scope`     | Muss dem in der Bundle-Signatur eingebetteten Scope entsprechen. Weglassen, wenn ohne Scope signiert wurde. | `""`     |

### Simulation-Instanz

Neben der aktiven OPA-Instanz läuft eine zweite Instanz (`opa-simulation`), gegen
die der Authorization Service parallel auswertet, ohne dass deren Ergebnis die
Entscheidung beeinflusst. So lässt sich eine geänderte Policy im laufenden
Betrieb beobachten, bevor sie aktiv geschaltet wird.

| Value                                | Beschreibung                                                                                                                                         | Standard |
|--------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `opa.simulation.enabled`             | Simulation-Instanz deployen                                                                                                                          | `true`   |
| `opa.simulation.replicaCount`        | Anzahl der Replicas der Simulation-Instanz                                                                                                           | `1`      |
| `opa.simulation.bundle.resource`     | Bundle-Referenz der Simulation (Pfad je Umgebung siehe OPA-Anleitung). Pflicht bei Bundle-Modus mit Simulation, wird nicht abgeleitet.               | `""`     |
| `opa.simulation.bundle.verification` | Eigene Signaturprüfung für das Simulation-Bundle (gleiche Schlüssel wie `opa.bundle.verification`). Leer = `opa.bundle.verification` gilt auch hier. | `{}`     |

### Workload Identity Federation (GAR-Zugriff)

Für den Bundle-Abruf aus der Google Artifact Registry ohne langlebige
Zugangsdaten: ein CronJob tauscht das projizierte Kubernetes-ServiceAccount-Token
über Googles STS gegen ein kurzlebiges Zugriffstoken.

| Value                                                      | Beschreibung                                                        | Standard                   |
|------------------------------------------------------------|---------------------------------------------------------------------|----------------------------|
| `opa.workloadIdentityFederation.enabled`                   | Workload Identity Federation aktivieren                             | `false`                    |
| `opa.workloadIdentityFederation.sts.sa`                    | E-Mail-Adresse des zu impersonierenden Google-Service-Accounts      | `""`                       |
| `opa.workloadIdentityFederation.tokenRenewer.enabled`      | CronJob zur Token-Erneuerung deployen                               | `true`                     |
| `opa.workloadIdentityFederation.tokenRenewer.schedule`     | Cron-Ausdruck für die Token-Erneuerung                              | `"*/45 * * * *"`           |
| `opa.workloadIdentityFederation.tokenRenewer.backoffLimit` | Anzahl der Wiederholungen fehlgeschlagener Jobs                     | `5`                        |
| `opa.workloadIdentityFederation.worker.image`              | Image des Token-Renewer-Jobs — erforderlich, wenn WIF aktiviert ist | `google/cloud-sdk:549.0.0` |
| `opa.workloadIdentityFederation.worker.imagePullPolicy`    | Pull-Policy des Worker-Images                                       | `IfNotPresent`             |
| `opa.workloadIdentityFederation.worker.imagePullSecrets`   | Pull-Secrets des Worker-Images                                      | `[]`                       |
| `opa.workloadIdentityFederation.worker.resources`          | Ressourcen des Token-Renewer-Jobs                                   | s. `values.yaml`           |

> **Zwei getrennte Value-Bäume:** Der zu impersonierende Service Account steht
> unter `opa.workloadIdentityFederation.sts.sa`. Die **STS-Audience** wird
> dagegen aus den globalen Werten
> `gematik.workloadIdentityFederation.projectNumber`, `.poolId` und
> `.workloadIdentityProvider` gebildet — nicht aus dem `opa`-Baum. Beide müssen
> gesetzt sein; STS- und IAM-Endpunkte sowie der Scope sind im CronJob fest
> hinterlegt.

Ein sofortiger Lauf außerhalb des Zeitplans lässt sich so auslösen:

```bash
kubectl -n <namespace> create job token-renewer-once --from=cronjob/opa-token-renewer-cronjob
```

### Geplanter Rollout-Restart

Startet die Deployments `opa` und — falls aktiviert — `opa-simulation`
regelmäßig neu. Standardmäßig deaktiviert.

| Value                                   | Beschreibung                                                                                                                                       | Standard         |
|-----------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------|------------------|
| `opa.rolloutRestart.enabled`            | Geplanten Neustart aktivieren                                                                                                                      | `false`          |
| `opa.rolloutRestart.schedule`           | Cron-Ausdruck; die Zeitzone ist im CronJob auf `Europe/Berlin` gesetzt                                                                             | `"0 3 * * *"`    |
| `opa.rolloutRestart.backoffLimit`       | Anzahl der Wiederholungen fehlgeschlagener Jobs                                                                                                    | `5`              |
| `opa.rolloutRestart.serviceAccountName` | Bestehenden ServiceAccount verwenden. Leer = das Chart erzeugt ServiceAccount und minimale RBAC (`get`/`patch` auf die beiden Deployments) selbst. | `""`             |
| `opa.rolloutRestart.resources`          | Ressourcen des Neustart-Jobs                                                                                                                       | s. `values.yaml` |

Der Job verwendet `provisioningProcessor.image` (enthält `kubectl`) samt dessen
Security Context wieder, statt ein generisches, als root laufendes CI-Image
einzuführen.

---

## Provisioning Processor

Der Provisioning Processor ist ein gemeinsamer Init-Container, der von
Authserver, OPA, OPA-Simulation und PEP-Proxy verwendet wird. Beim Authserver
läuft er standardmäßig stattdessen als resident bleibender Sidecar, der die
Vertrauensanker täglich neu erzeugt, siehe
[Zeitgesteuerte Aktualisierung](#zeitgesteuerte-aktualisierung-der-vertrauensanker):

```yaml
provisioningProcessor:
    resources:
        limits:
            cpu: "1"
            memory: "200Mi"
        requests:
            cpu: "100m"
            memory: "100Mi"
    # übrige Keys aus defaultContainerSecurityContext
    containerSecurityContext:
        readOnlyRootFilesystem: false
```

### Provisioning-Container je Umgebung

`provisioningProcessor.provisioningContainer` bestimmt, welches
Provisioning-Daten-Image geladen wird. Die Vorbelegung des Charts zeigt auf das
Image der **RU/RUDEV**-Umgebung; für TU und PU ist der Wert vom Betreiber zu
setzen, passend zur jeweiligen Vertrauenskette in
`imageTrustCertchainSecretRef`. Die Image-Referenzen und Bezugsquellen der
Vertrauensanker je Umgebung stehen in
[Wie Sie ZETA-Guard in Kubernetes konfigurieren — Provisioning Processor](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#64-provisioning-processor-image-vertrauenskette-konfigurieren).

### Eigene Registry für den Provisioning-Container

Standardmäßig lädt der Provisioning Processor das Daten-Image von der
gematik-Registry. Für Umgebungen ohne direkten Internetzugang kann eine eigene
Registry-Spiegelung konfiguriert werden:

```yaml
provisioningProcessor:
    provisioningContainer: "my.registry.corp.internal/zetaguard-provisioning:latest"
```

### Federation Master für den mobilen Client-Flow

Im [mobilen Client-Flow](../Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md)
liest der Authserver die URL des Federation Masters aus der Datei
`/var/trust-data/federation-master.json` (`FEDERATION_MASTER_LOCATION`,
A_29737). Diese Datei erzeugt der Provisioning Processor aus der
Federation-Master-YAML des Provisioning-Containers. Bei
`authserver.config.oidcFlowEnabled: true` muss
`provisioningProcessor.federationMaster.enabled` gesetzt sein, sonst startet
der Authserver nicht.

```yaml
provisioningProcessor:
    federationMaster:
        enabled: true
        environment: "test"
```

| Value                                                 | Beschreibung                                                                                                                                                     | Standard |
|-------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `provisioningProcessor.federationMaster.enabled`      | Federation-Master-URL extrahieren und als `federation-master.json` ablegen. Die Startup-Probe des Authservers wartet dann auch auf diese Datei.                   | `false`  |
| `provisioningProcessor.federationMaster.environment`  | Umgebung, deren URL aus der YAML gelesen wird (z. B. `production`, `test`); muss genau einem Eintrag entsprechen. Pflicht, wenn `enabled: true`.                 | `""`     |
| `provisioningProcessor.federationMaster.devModeUrl`   | Überschreibt die extrahierte URL, auch mit `http://`. Nur für Testumgebungen mit eigener Föderation (z. B. gsi-fedmaster).                                      | `""`     |

### Zeitgesteuerte Aktualisierung der Vertrauensanker

Verfügbar ab zeta-guard-helm-Chart-Version **1.3.0**.

Der Provisioning Processor des Authservers bleibt als Sidecar im Pod und
wiederholt seinen Lauf täglich. Der Authentication Service übernimmt die neu
erzeugten Truststores ohne Neustart und ohne Unterbrechung laufender Anfragen,
siehe
[Konfiguration des Authentication Services](Konfiguration_des_PDP_Services.md#aktualisierung-der-truststores-im-laufenden-betrieb).

Beides ist **für den Produktivbetrieb vorgesehen und standardmäßig aktiv**. Ohne
diese Automatik werden Vertrauensanker erst mit dem nächsten Pod-Neustart
wirksam — eine widerrufene CA bliebe also bis dahin gültig.

```yaml
provisioningProcessor:
    schedule:
        enabled: true
        time: "03:00"
        timezone: "Europe/Berlin"
```

| Value                                     | Beschreibung                                                                                        | Standard          |
|-------------------------------------------|-----------------------------------------------------------------------------------------------------|-------------------|
| `provisioningProcessor.schedule.enabled`  | Prozessor als Sidecar resident halten. `false` ergibt einen einmalig durchlaufenden Init-Container. | `true`            |
| `provisioningProcessor.schedule.time`     | Uhrzeit des täglichen Laufs im Format `HH:MM`. Kein Cron-Ausdruck.                                  | `"03:00"`         |
| `provisioningProcessor.schedule.timezone` | IANA-Zeitzone, in der die Uhrzeit ausgewertet wird.                                                 | `"Europe/Berlin"` |

Die Uhrzeit sollte in eine Phase geringer Last fallen: Der Lauf lädt das
signierte Provisioning-Image erneut und prüft dessen cosign-Signatur.

> **Voraussetzung Kubernetes 1.32.** Das Chart setzt mindestens **Kubernetes
> 1.32 (entspr. OpenShift 4.19 oder neuer)** voraus und erzwingt diese
> Untergrenze über `kubeVersion`. Auf älteren Clustern schlägt die Installation
> deshalb mit einer klaren Meldung fehl, statt später im Betrieb aufzufallen.

> **Voraussetzung Image.** Der Sidecar braucht ein Provisioning-Processor-Image,
> das `SCHEDULE_TIME` unterstützt, **Version 1.3.0 aufwärts**. Wird
> `provisioningProcessor.image.tag` auf eine ältere Version gepinnt, beendet sich
> der Container nach seinem Lauf und wird endlos neu gestartet — inklusive
> erneutem Laden und Verifizieren des signierten Provisioning-Images bei jedem
> Versuch. Erkennbar an einem stetig steigenden
> `RESTARTS`-Zähler des Init-Containers `trust-anchor-provisioning-processor`.

Eine Startup-Probe stellt sicher, dass Keycloak erst startet, wenn der erste
Lauf alle Ergebnisdateien veröffentlicht hat — ein Sidecar muss im Gegensatz zu
einem Init-Container nicht vorher beendet sein.

Die beiden Optionen gehören zusammen: Ohne den Sidecar wird zur Laufzeit nichts
neu geschrieben, und ohne den Reload liest Keycloak die Dateien nur beim Start.
Wird eine davon abgeschaltet, verliert die andere ihre Wirkung.

```yaml
authserver:
    truststoreReload:
        enabled: true
        interval: PT1H
```

| Value                                  | Beschreibung                                                                                                                     | Standard |
|----------------------------------------|----------------------------------------------------------------------------------------------------------------------------------|----------|
| `authserver.truststoreReload.enabled`  | Truststores im laufenden Betrieb neu einlesen. `false` liest sie nur beim Start.                                                 | `true`   |
| `authserver.truststoreReload.interval` | Prüfintervall als ISO-8601-Dauer, höchstens Stunden (`PT1H`, nicht `P1D`). Die erste Prüfung läuft ein Intervall nach dem Start. | `PT1H`   |

Das Prüfintervall darf deutlich kürzer sein als der Provisioning-Lauf:
Verglichen wird ein Hash über die Dateibytes, gelesen und geparst wird nur bei
einer Änderung. Ein kürzeres Intervall verkürzt damit vor allem die Zeitspanne,
in der eine widerrufene CA noch akzeptiert wird.

Einzelheiten zum
Verhalten: [Konfiguration des Authentication Services](Konfiguration_des_PDP_Services.md#aktualisierung-der-truststores-im-laufenden-betrieb).

> **Hinweis:** Das gespiegelte Image muss zusammen mit seiner cosign-Signatur
> übertragen werden. Ein einfaches `docker pull/push` überträgt die Signatur
> nicht. Siehe
> [Wie Sie eine eigene OCI-Registry verwenden](../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).

### CA-Zertifikat für private Registries

Wenn die Registry ein TLS-Zertifikat verwendet, das von einer internen CA
ausgestellt wurde, muss das CA-Zertifikat dem Init-Container mitgegeben werden.
Das Zertifikat wird aus einem Kubernetes-Secret als Datei in den Init-Container
gemountet. Diese Variante vermeidet das Kernel-Limit `ARG_MAX`, das bei der
Übergabe von Zertifikatsketten als Umgebungsvariable überschritten werden kann.

Dieselbe Referenz versorgt zusätzlich die Container `opa` und `opa-simulation`,
die das Zertifikat im Bundle-Modus für den Abruf des Policy-Bundles benötigen.
Für OPA wird die CA dem System-Truststore des Images **hinzugefügt**
(`system_ca_required: true`); der Init-Container verwendet die Datei dagegen als
**einzigen** Trust-Anchor. Werden Provisioning-Daten-Image und Policy-Bundle aus
unterschiedlich vertrauenswürdigen Registries geladen, muss die Datei deshalb
ein vollständiges CA-Bundle enthalten — sonst schlägt der Abruf des
Provisioning-Daten-Images fehl. Details:
[Wie Sie eine eigene OCI-Registry verwenden](../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).

```yaml
provisioningProcessor:
    provisioningContainerCaSecretRef:
        name: registry-ca        # Name des Kubernetes-Secrets
        key: ca.crt              # Key innerhalb des Secrets
```

Alternativ kann das CA-Zertifikat aus einer **ConfigMap** gemountet werden (die
öffentlichen CA-Teile sind nicht geheim). Das passt zum OpenShift-Mechanismus
[„Configuring a custom PKI“](https://docs.openshift.com/container-platform/latest/networking/configuring-a-custom-pki.html),
der das CA-Bundle als ConfigMap bereitstellt.
`provisioningContainerCaSecretRef` und `provisioningContainerCaConfigMapRef`
schließen sich gegenseitig aus; ist beides gesetzt, hat die Secret-Referenz
Vorrang.

```yaml
provisioningProcessor:
    provisioningContainerCaConfigMapRef:
        name: zeta-guard-openshift-ca-bundle   # Name der Kubernetes-ConfigMap
        key: ca-bundle.crt                     # Key innerhalb der ConfigMap
```

Für beliebige andere Einbindungen stehen die generischen Werte
`provisioningProcessor.extraEnv`, `extraVolumes` und `extraVolumeMounts` am
Init-Container zur Verfügung. Damit werden Volume, Mount und die
Umgebungsvariable `PROVISIONING_CONTAINER_REGISTRY_CA_FILE` selbst verdrahtet:

```yaml
provisioningProcessor:
    extraEnv:
        -   name: PROVISIONING_CONTAINER_REGISTRY_CA_FILE
            value: /var/custom-ca/ca.crt
    extraVolumes:
        -   name: custom-ca
            configMap:
                name: my-ca-bundle
    extraVolumeMounts:
        -   name: custom-ca
            mountPath: /var/custom-ca
            readOnly: true
```

### Zugangsdaten für die Provisioning-Container-Registry

Erlaubt die Registry keinen anonymen Zugriff, können Benutzername und Token aus
einem Kubernetes-Secret bereitgestellt werden. Der Init-Container führt damit
vor dem Laden des Images ein `cosign login` aus. Das Secret wird über
`provisioningProcessor.registryCredentialsSecretRef` referenziert.

```yaml
provisioningProcessor:
    registryCredentialsSecretRef:
        name: registry-credentials   # Name des Kubernetes-Secrets
        usernameKey: username        # Key des Benutzernamens (Standard: username)
        tokenKey: token              # Key des Tokens (Standard: token)
```

`usernameKey` und `tokenKey` sind optional und müssen nur gesetzt werden, wenn
das Secret abweichende Key-Namen verwendet. Daraus werden die Umgebungsvariablen
`PROVISIONING_CONTAINER_REGISTRY_USERNAME` und
`PROVISIONING_CONTAINER_REGISTRY_TOKEN` im Init-Container verdrahtet. Ohne
gesetzte Referenz erfolgt der Zugriff anonym.

### Cosign-Vertrauenskette für Image-Verifikation

Der Helm-Value `imageTrustCertchainSecretRef` benennt ein Kubernetes-Secret, das
die CA-Zertifikatskette der gematik enthält. Der Provisioning Processor prüft
damit die cosign-Signatur des Provisioning-Daten-Images beim Pod-Start.

Das Secret muss den Key `certchain.pem` mit einer PEM-kodierten
X.509-Zertifikatskette enthalten (CA- und Zwischenzertifikate, kein
Leaf-Zertifikat). Es wird als Volume `image-trustchain` in den Init-Container
des Provisioning Processors jedes der folgenden Deployments eingebunden:
**Authserver**, **PEP-Proxy**, **OPA** und **OPA-Simulation**. Der Pfad im
Container lautet `/var/image-trustchain/certchain.pem` (Umgebungsvariable
`TRUST_CERTCHAIN_FILE`).

> **Pflichtfeld:** Das Helm-Chart bricht beim Rendern mit einem Fehler ab, wenn
> `imageTrustCertchainSecretRef` nicht gesetzt ist.

```yaml
imageTrustCertchainSecretRef: my-image-signer
```

Das Secret wird typischerweise so angelegt:

```bash
kubectl create secret generic my-image-signer \
  --from-file=certchain.pem=/path/to/gematik-certchain.pem \
  --namespace NAMESPACE
```

Die Zertifikatskette ist von der gematik zu beziehen. Für Testumgebungen enthält
das Helm-Chart im Verzeichnis `templates/` ein vorgefertigtes Secret
`gematik-image-signer-test` mit den Testzertifikaten GEM.KOMP-CA61 und GEM.RCA7
(jeweils TEST-ONLY). Der Standardwert in `values-demo.yaml` im Chart verweist
auf dieses Test-Secret.

> **Wichtig:** Das Test-Secret `gematik-image-signer-test` enthält
> Testzertifikate und darf **nicht** in Produktivumgebungen verwendet werden.
> Für den Produktivbetrieb muss das Secret mit den von der gematik
> bereitgestellten Produktivzertifikaten befüllt werden.

---

## Notification Service

Der Notification Service ist eine Vorschau-Komponente und standardmäßig
deaktiviert. Bei Aktivierung deployt das Chart zwei Varianten desselben Images
(`-rs` für die Resource-Server-API, `-fdv` für die Client-API hinter dem PEP)
sowie im Standardmodus eine dedizierte CNPG-Datenbank.

Zwei Werte sind Pflicht — ohne sie startet der Dienst nicht:

```yaml
notificationService:
    enabled: true
    env:
        pushGatewayAllowedBaseUrls:
            - "https://push-gateway.example/push/v1/"
        channelsAllowed: "epa.documents.new,epa.consent.changed"
```

Alle Werte des Blocks `notificationService.*` (Image und Varianten, Datenbank,
Push-Gateway-Anbindung inkl. mTLS, Nachrichten-Historie, Well-Known,
Ressourcen) sowie das Env-Mapping und die Einschränkungen des aktuellen Stands
sind in der
[Konfiguration des Notification Service](Konfiguration_des_Notification_Service.md)
beschrieben.

---

## NetworkPolicy (Egress)

Das Chart kann optionale Egress-`NetworkPolicy`-Ressourcen erzeugen
(`networkPolicy.enabled`, Standard `false`), die den ausgehenden Verkehr jedes
Pods auf freigegebene Ziel-IP-Blöcke beschränken. Die vollständige Konfiguration
(Kategorien, IP-Blöcke, Anbieter-interner Verkehr) ist in
[Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md)
beschrieben.

Der DNS-Egress-Peer ist über `networkPolicy.dns` konfigurierbar. Standard ist
der kube-dns-Dienst (`kube-system` / `k8s-app: kube-dns` / Port 53), sodass sich
für Bestandsdeployments nichts ändert.

> **OpenShift:** DNS läuft im Namespace `openshift-dns` (Pod-Label
> `dns.operator.openshift.io/daemonset-dns: default`), und da OVN-Kubernetes
> Egress nach dem DNAT auswertet, ist der Ziel-Port am Pod 5353 statt 53.
> Setzen Sie den Peer über `networkPolicy.dns.to` (eine Liste — sie wird
> vollständig ersetzt, im Gegensatz zu den tief zusammengeführten
> Selektor-Maps):
>
> ```yaml
> zeta-guard:
>   networkPolicy:
>     dns:
>       to:
>         - namespaceSelector:
>             matchLabels:
>               kubernetes.io/metadata.name: openshift-dns
>           podSelector:
>             matchLabels:
>               dns.operator.openshift.io/daemonset-dns: default
>       ports:
>         - port: 5353
>           protocol: UDP
>         - port: 5353
>           protocol: TCP
> ```

---

## Terraform-Konfiguration (PDP)

> Wann und wie oft dieser Schritt laufen muss, welche Nebenwirkungen er hat und
> was bei einem Abbruch gilt, beschreibt der Abschnitt
> [Wann und wie oft die PDP-Konfiguration laufen muss](../Anleitungen/ZETA_Guard_Quickstart.md#wann-und-wie-oft-die-pdp-konfiguration-laufen-muss)
> im Quickstart.

Die PDP-Konfiguration erfolgt über Terraform. Variablen ohne Standardwert (`—`)
sind **erforderlich**; ein Apply ohne sie schlägt fehl. Eine kommentierte
Vorlage mit allen Variablen liegt unter
[demo.tfvars](https://github.com/gematik/zeta-guard-helm/blob/main/terraform/authserver/environments/demo.tfvars).

| Variable                                 | Standard                  | Beschreibung                                                                                                                                                                                                                                                                                                                                           |
|------------------------------------------|---------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `keycloak_url`                           | —                         | Externe URL des Keycloak-Servers (bei Admin-API-Absicherung: URL des Admin-Hostnamens)                                                                                                                                                                                                                                                                 |
| `master_realm_frontend_url`              | `""`                      | Browser-URL des `master`-Realms, wenn Terraform Keycloak über einen anderen Endpunkt erreicht als die Administratoren (z. B. Tunnel). Muss auf `/auth` enden; leer = aus `keycloak_url` abgeleitet, sobald `audience` gesetzt ist (siehe [Wann `master_realm_frontend_url` gesetzt werden muss](#wann-master_realm_frontend_url-gesetzt-werden-muss)). |
| `keycloak_namespace`                     | `""`                      | Kubernetes-Namespace des Authservers — erforderlich bei `use_kubernetes = true`, im lokalen Modus ohne Wirkung                                                                                                                                                                                                                                         |
| `audience_scope_name`                    | —                         | Name des Audience-Scopes — trägt die Pflicht-Claims des Access-Tokens (siehe Hinweis unter der Tabelle)                                                                                                                                                                                                                                                |
| `use_kubernetes`                         | `true`                    | Terraform-Betriebsmodus (`true` = K8s-Backend, `false` = lokal)                                                                                                                                                                                                                                                                                        |
| `keycloak_admin_secret`                  | `"authserver-admin"`      | Name des Secrets mit den Keycloak-Admin-Zugangsdaten. Terraform liest es nicht selbst; die mitgelieferten Skripte lösen die Zugangsdaten daraus zur Laufzeit auf.                                                                                                                                                                                      |
| `keycloak_username`                      | `""`                      | Keycloak-Admin-Benutzer. In **beiden** Modi erforderlich, `ephemeral`. Ausschließlich über `TF_VAR_keycloak_username` setzen — nicht in einer tfvars-Datei.                                                                                                                                                                                            |
| `keycloak_password`                      | `""`                      | Keycloak-Admin-Passwort. In **beiden** Modi erforderlich, `ephemeral`. Ausschließlich über `TF_VAR_keycloak_password` setzen — nicht in einer tfvars-Datei.                                                                                                                                                                                            |
| `insecure_tls`                           | `false`                   | Selbst signierte Zertifikate zulassen                                                                                                                                                                                                                                                                                                                  |
| `skip_external_resources`                | `false`                   | Überspringt die externen Skripte, die sonst bereits bei `terraform plan` laufen                                                                                                                                                                                                                                                                        |
| `audience`                               | `""`                      | Expliziter Audience-Wert im Access-Token. Erforderlich, wenn `keycloak_url` auf einen Admin-Hostnamen zeigt (siehe unten). Leer = aus `keycloak_url` abgeleitet.                                                                                                                                                                                       |
| `pdp_scopes`                             | `[]`                      | Zusätzliche PDP-Scopes, als optionale Realm-Scopes angelegt. Sie tragen **keinen** Claim-Mapper und können den Audience-Scope daher nicht ersetzen.                                                                                                                                                                                                    |
| `smc_b_client_secret`                    | `"**********"`            | Client-Secret des SMC-B-Identity-Providers. `ephemeral` und über ein write-only-Argument gesetzt — landet nicht im Terraform-State.                                                                                                                                                                                                                    |
| `smc_b_client_secret_version`            | `1`                       | Hochzählen, wenn `smc_b_client_secret` geändert wird. Ein write-only-Argument ist für Terraform nach dem Apply unsichtbar, ein geändertes Secret allein erzeugt also kein Diff.                                                                                                                                                                        |
| `enable_sekidp`                          | `false`                   | Registriert den IDP `zeta-sekidp-oidc`, die mobilen Browser-/First-Login-Flows, die Entity-Statement-Schlüssel und die E-Mail-Binding-Scopes. Läuft in beiden Betriebsmodi (siehe Hinweis unter der Tabelle).                                                                                                                                          |
| `sekidp_client_id`                       | `""`                      | `client_id` des IDP `zeta-sekidp-oidc`, also der öffentliche Issuer des Realms (z. B. `https://<host>/auth/realms/zeta-guard`). Der SekIDP lädt darüber das Entity Statement des Guards. Leer = `<keycloak_url>/realms/zeta-guard`; **setzen, wenn `keycloak_url` auf den Admin-Hostnamen zeigt**, den der SekIDP nicht erreicht.                      |
| `smtp_host`                              | `""`                      | SMTP-Server für den Realm (OTP-Versand der E-Mail-Bindung im mobilen Client-Flow). Leer lässt den `smtp_server`-Block des Realms komplett weg.                                                                                                                                                                                                         |
| `smtp_port`                              | `"25"`                    | SMTP-Port                                                                                                                                                                                                                                                                                                                                              |
| `smtp_from`                              | `""`                      | Absenderadresse der Realm-Mails — von Keycloak verlangt, sobald `smtp_host` gesetzt ist                                                                                                                                                                                                                                                                |
| `smtp_starttls`                          | `false`                   | Bestimmt ob StartTLS verwendet werden soll. Beachte, ein ggf. notwendiges CA Zertifikat kann über den Helm Value `authserver.additionalTrustedCAs` bereit gestellt werden.                                                                                                                                                                             |
| `smtp_ssl`                               | `false`                   | Bestimmt ob TLS verwendet werden soll. Beachte, ein ggf. notwendiges CA Zertifikat kann über den Helm Value `authserver.additionalTrustedCAs` bereit gestellt werden.                                                                                                                                                                                  |
| `smtp_auth_username`                     | `""`                      | Nutzername am SMTP Severver, sofern Anmeldung notwendig ist.                                                                                                                                                                                                                                                                                           |
| `smtp_auth_password`                     | `""`                      | Passwort am SMTP Severver, sofern Anmeldung notwendig ist.                                                                                                                                                                                                                                                                                             |
| `notification_history_enabled`           | `false`                   | Legt den Keycloak-Scope `notification.history.read` an (A_29974). Manuell synchron zu `notificationService.historyEnabled` halten — nicht automatisch gekoppelt.                                                                                                                                                                                       |
| `notification_service_resource_suffix`   | `"/notification-service"` | Resource-Suffix des Notification Service für den Audience-Mapper der Notification-Scopes. Manuell synchron zu `notificationService.wellKnownResourceSuffix` halten.                                                                                                                                                                                    |
| `hsm_token_signing_enabled`              | `false`                   | Registriert einen HSM-gestützten ES256-KeyProvider im Realm `zeta-guard`                                                                                                                                                                                                                                                                               |
| `hsm_token_signing_endpoint`             | `""`                      | gRPC-Endpunkt des HSM-Proxy (z. B. `hsm-sim:50051`)                                                                                                                                                                                                                                                                                                    |
| `hsm_token_signing_key_id`               | `""`                      | Kennung des Signaturschlüssels im HSM                                                                                                                                                                                                                                                                                                                  |
| `hsm_token_signing_priority`             | `"200"`                   | Priorität des Providers; höher gewinnt (Software-Schlüssel liegen bei `100`)                                                                                                                                                                                                                                                                           |
| `hsm_token_signing_remove_software_keys` | `true`                    | Entfernt die Software-Signaturschlüssel nach der HSM-Registrierung                                                                                                                                                                                                                                                                                     |
| `use_vau_db_enc`                         | `false`                   | Clientseitige Verschlüsselung des Realms. Nur empfohlen beim Betrieb in einer vertrauenswürdigen Ausführungsumgebung (VAU).                                                                                                                                                                                                                            |
| `sso_session_idle_timeout`               | `"24h"`                   | Leerlauf-Timeout der Realm-SSO-Session (Go-Dauer). Mindestens so groß wie die längste Refresh-Token-TTL der Policy, sonst endet die Session vor dem Refresh-Token.                                                                                                                                                                                     |
| `sso_session_max_lifespan`               | `"24h"`                   | Maximale Lebensdauer der Realm-SSO-Session (Go-Dauer). Mindestens so groß wie die längste Refresh-Token-TTL der Policy.                                                                                                                                                                                                                                |

> **Hinweis zu `enable_sekidp`:** Die Registrierung des SekIDP-Brokers
> funktioniert in beiden Betriebsmodi, also auch mit `use_kubernetes = false`
> und lokalem State, und braucht keinen Cluster-Zugriff. Der IDP fordert die
> Scopes `urn:telematik:display_name`, `urn:telematik:versicherter`,
> `urn:telematik:geburtsdatum` und `openid` an; beim Federation Master muss der
> Guard als Relying Party mit genau diesen Scopes registriert sein, sonst lehnt
> der SekIDP den PAR mit `invalid_scope` ab. Sein Entity Statement
> veröffentlicht der Guard selbst unter
> `<sekidp_client_id>/.well-known/openid-federation` — diese URL und die dort
> enthaltenen Schlüssel hinterlegen Sie beim Federation Master. Legen Sie den
> Realm neu an, erzeugt Keycloak neue Schlüssel, die Sie dann erneut
> hinterlegen. Für Tests ohne echten Federation Master siehe das
> `sekidp`-Subchart im Helm-Repository (`How_to_configure_sekidp.md`).

> **Hinweis zu SMTP in Testumgebungen:** Für Test- und Demo-Stages bringt das
> Helm-Repository ein `mailcatcher`-Subchart mit (SMTP-Port `1025`, Web-UI
> `1080`). `smtp_host` zeigt dann auf den mailcatcher-Service, sodass
> OTP-Mails ohne echten Mailserver eingesehen werden können.

> **Hinweis zu `audience_scope_name`:** An diesem Scope hängen die Mapper, die
> die vom PEP geforderten Access-Token-Claims setzen (`aud`, `profession_oid`,
> `client_id`, `ip_address`, `product_id`, `product_version`, `common_name`,
> `organization_name`). Der Client muss den Scope anfragen. Verlangt ein
> Fachdienst einen bestimmten Scope-Namen — z. B. `vsdservice` für das VSDM
> (A_26744) —, setzen Sie `audience_scope_name` auf diesen Wert und führen ihn
> **nicht** zusätzlich in `pdp_scopes` (doppelter Scope-Name → Fehler beim
> Apply). Andernfalls fehlen dem Token die Claims und der PEP lehnt die Anfrage
> vor der
> Policy-Auswertung ab. Pro Realm existiert genau ein Audience-Scope — der
> gesetzte Name ist der einzige, der angelegt wird.

Wenn `adminHostname` gesetzt ist und `keycloak_url` auf den Admin-Hostnamen
zeigt, muss `audience` explizit auf den **öffentlichen Haupthostnamen** gesetzt
werden — andernfalls würde der Audience-Wert aus der URL abgeleitet und stimmte
nicht mit dem überein, was die Access-Tokens tragen:

```hcl
keycloak_url = "https://admin.zeta.example.com/auth"
audience     = "https://zeta.example.com"
```

Ein gesetztes `audience` ist zugleich das Signal, dass `keycloak_url` der
Admin-Hostname ist. Daraus leitet die Authserver-Konfiguration die Frontend-URL
des `master`-Realms ab und heftet sie an diesen Hostnamen — der Schritt, ohne den
der Browser-Login der Admin Console auf dem gesperrten Pfad landet (siehe
[Admin-API-Absicherung](#admin-api-absicherung)). In aller Regel ist dafür kein
eigener Eintrag nötig.

##### Wann `master_realm_frontend_url` gesetzt werden muss

Die Ableitung setzt zwei Dinge gleich, die nur üblicherweise identisch sind: die
URL, mit der **Terraform** spricht, und die URL, die **Administratoren im
Browser** öffnen. Fallen sie auseinander, ist die Variable zu setzen.

Vier Fälle, ausgehend von `authserver.hostname: zeta.example.com` und
`authserver.adminHostname: admin.zeta.example.com`:

| Fall | `keycloak_url`                        | `audience`                 | `master_realm_frontend_url`           | Frontend-URL des `master`-Realms      | Browser-Login der Console |
|------|---------------------------------------|----------------------------|---------------------------------------|---------------------------------------|---------------------------|
| 1    | `https://zeta.example.com/auth`       | nicht gesetzt              | nicht gesetzt                         | nicht gesetzt (kein Admin-Hostname)   | über den Haupthostnamen   |
| 2    | `https://admin.zeta.example.com/auth` | `https://zeta.example.com` | nicht gesetzt                         | `https://admin.zeta.example.com/auth` | funktioniert              |
| 3    | `http://localhost:8080/auth`          | `https://zeta.example.com` | nicht gesetzt                         | `http://localhost:8080/auth`          | **scheitert**             |
| 4    | `http://localhost:8080/auth`          | `https://zeta.example.com` | `https://admin.zeta.example.com/auth` | `https://admin.zeta.example.com/auth` | funktioniert              |

**Fall 1** ist der Auslieferungszustand ohne Admin-Hostnamen: `audience` ist
leer, die Ableitung greift nicht, der `master`-Realm behält die aus `--hostname`
gebildete Frontend-URL.

**Fall 2** ist der Regelfall mit Admin-Hostnamen. Terraform und Browser nutzen
dieselbe URL, die Ableitung trifft sie korrekt — ein eigener Eintrag ist
überflüssig.

**Fall 3** entsteht aus der Absicherung selbst: Ein Admin-Hostname, der bewusst
nicht öffentlich auflöst (siehe
[Was der Betreiber zusätzlich leisten muss](#was-der-betreiber-zusätzlich-leisten-muss)),
zwingt Terraform über einen Tunnel oder eine Portweiterleitung, etwa
`kubectl port-forward`. Die Ableitung trägt dann diesen Tunnel ein. Die Console
weist ihn anschließend als `authServerUrl` aus — erreichbar nur für den, der den
Tunnel offen hält, für jeden anderen Browser ist sie tot.

**Fall 4** ist die Korrektur: Die Variable entkoppelt die Browser-URL von der
Terraform-URL.

```hcl
keycloak_url              = "http://localhost:8080/auth"
audience                  = "https://zeta.example.com"
master_realm_frontend_url = "https://admin.zeta.example.com/auth"
```

Prüfen lässt sich das Ergebnis in allen Fällen an der Console-Konfiguration; der
ausgewiesene Wert muss die URL sein, die Administratoren tatsächlich öffnen:

```bash
curl -sk https://admin.zeta.example.com/auth/admin/master/console/ \
  | grep -o 'authServerUrl[^,}]*'
```

##### Wofür die Variable nicht taugt

**Sie verlegt oder verbirgt die Admin-UI nicht.** Der Wert ist eine Deklaration,
keine Weiterleitung: Keycloak bildet daraus ausschließlich die URLs, die es
*ausweist* — den `issuer`, die Realm-Endpunkte und die `authServerUrl` der
Console. Wo die UI tatsächlich antwortet, entscheiden der Ingress und
`--hostname-admin`.

Ein Wert, der auf einen Hostnamen oder Pfad ohne Route zum Authserver zeigt,
verschiebt die Console deshalb nicht, sondern macht sie unbrauchbar — und
verbirgt sie auch nicht, denn unter ihrer tatsächlichen Adresse bleibt sie
erreichbar. Als Zugriffsschutz ist die Variable ungeeignet.

Der Wert muss auf `/auth` enden: Keycloak hängt den Realm-Pfad unverändert an und
ergänzt den Kontextpfad **nicht**. Bei einem abweichenden Pfad weist die Admin
Console Endpunkte aus, die sie selbst nicht erreicht, und der Browser-Login
scheitert mit `404`. Eine Validierung weist solche Werte bereits beim Planen
zurück; ohne sie zeigte sich der Fehler erst im Browser.

Details zu den Terraform-Betriebsmodi finden sich im
[Quickstart](../Anleitungen/ZETA_Guard_Quickstart.md#2-pdp-konfigurieren).
