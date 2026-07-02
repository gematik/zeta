# ZETA-Guard Helm Chart Referenz

Hier folgt eine Referenzdokumentation der wichtigsten Values des Helm Charts.
Als vollständige Vorlage mit Standardwerten dient die
[values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml).

## Inhaltsverzeichnis

- [Globale Proxy-Konfiguration](#globale-proxy-konfiguration)
- [Authserver](#authserver)
    - [ServiceAccount](#serviceaccount)
    - [Replicas und PodDisruptionBudget](#replicas-und-poddisruptionbudget)
    - [Ressourcen](#ressourcen)
    - [Security Contexts](#security-contexts)
    - [Probes](#probes)
    - [Admin-API-Absicherung](#admin-api-absicherung)
    - [CloudNativePG-Datenbankverbindung](#cloudnativepg-datenbankverbindung)
    - [Connection Pooling (Keycloak)](#connection-pooling-keycloak)
    - [HSM-Konfiguration](#hsm-konfiguration)
- [PEP-Proxy](#pep-proxy)
    - [ServiceAccount](#serviceaccount-1)
    - [Security Context](#security-context)
    - [Well-Known Discovery Dokument](#well-known-discovery-dokument)
- [Infinispan](#infinispan)
    - [Image](#image)
    - [ServiceAccount](#serviceaccount-2)
    - [PodDisruptionBudget](#poddisruptionbudget)
    - [Security Contexts](#security-contexts-1)
    - [JVM-Optionen](#jvm-optionen)
    - [HSM-Konfiguration](#hsm-konfiguration-1)
- [Provisioning Processor](#provisioning-processor)
    - [Eigene Registry für den Provisioning Container](#eigene-registry-für-den-provisioning-container)
    - [CA-Zertifikat für die Provisioning-Container-Registry](#ca-zertifikat-für-die-provisioning-container-registry)
    - [Cosign-Vertrauenskette für Image-Verifikation](#cosign-vertrauenskette-für-image-verifikation)
- [Terraform-Konfiguration (PDP)](#terraform-konfiguration-pdp)

## Globale Proxy-Konfiguration

Alle ZETA-Guard-Komponenten können den ausgehenden HTTP/HTTPS-Verkehr über
einen Forward Proxy routen. Die Konfiguration erfolgt einmalig unter `global:`
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

Für nginx (PEP) erzeugt der Chart zusätzlich `env`-Direktiven in der `nginx.conf`.
Für Keycloak (Authserver) wird `global.noProxy` automatisch in das
`-Dhttp.nonProxyHosts`-Format konvertiert (Pipe-Trenner, `*`-Wildcard statt
führendem Punkt). Subcharts wie `telemetry-gateway` sind upstream-Charts und
konsumieren `global` nicht — diese müssen bei Bedarf manuell konfiguriert werden.

Eine ausführliche Beschreibung der betroffenen Komponenten, der
Konvertierungslogik, der Subchart-Konfiguration und der Überprüfung nach dem
Deployment findet sich in der Anleitung
[Wie Sie einen Forward Proxy konfigurieren](../Anleitungen/Wie_Sie_einen_Forward_Proxy_konfigurieren.md).

## Authserver

### ServiceAccount

Für den Authserver wird standardmäßig ein dedizierter ServiceAccount erzeugt,
der den automatischen Token-Mount deaktiviert:

```yaml
zeta-guard:
    authserver:
        serviceAccount:
            create: true
            name: authserver
```

Setzen Sie `create: false`, um einen bereits bestehenden ServiceAccount zu
nutzen.

### Replicas und PodDisruptionBudget

```yaml
zeta-guard:
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

Ressourcen werden separat für den Hauptcontainer (
`authserver.container.resources`)
und den Keycloak-Build-Init-Container (`authserver.initContainer.resources`)
konfiguriert. Der Provisioning-Processor-Init-Container ist ein gemeinsamer
Container und wird separat unter `provisioningProcessor.*` konfiguriert (siehe
unten und
[Wie Sie Ressourcen für ZETA-Guard-Pods verwalten](../Anleitungen/Wie_Sie_Ressourcen_für_ZETA_Guard_Pods_verwalten.md)):

```yaml
zeta-guard:
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

Pod- und Container-Security-Contexts sind konfigurierbar:

```yaml
zeta-guard:
    authserver:
        podSecurityContext:
            seccompProfile:
                type: RuntimeDefault
        container:
            containerSecurityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                runAsNonRoot: true
                capabilities:
                    drop: [ "ALL" ]
        initContainer:
            containerSecurityContext:
                allowPrivilegeEscalation: false
                readOnlyRootFilesystem: true
                runAsNonRoot: true
                capabilities:
                    drop: [ "ALL" ]
```

Hinweis: `runAsUser` wird standardmäßig nicht gesetzt, da OpenShift dies nicht
unterstützt.

### Probes

Die Parameter für Liveness-, Readiness- und Startup-Probes sind konfigurierbar:

```yaml
zeta-guard:
    authserver:
        probes:
            liveness:
                initialDelaySeconds: 0
                periodSeconds: 15
                failureThreshold: 5
            readiness:
                initialDelaySeconds: 30
                periodSeconds: 10
                failureThreshold: 5
            startup:
                initialDelaySeconds: 30
                periodSeconds: 10
                failureThreshold: 20
```

### Admin-API-Absicherung

Die Keycloak Admin REST API und die Admin Console (`/auth/admin/*`) dürfen nicht
über den öffentlichen Hostnamen zugänglich sein. Das Helm Chart unterstützt eine
integrierte Absicherung über einen separaten Admin-Hostnamen.

Wenn `authserver.adminHostname` gesetzt ist, aktiviert das Chart zwei
Schutzschichten:

1. **PEP-Proxy blockiert `/auth/admin`** — ein `location ~ ^/auth/admin`-Block
   im NGINX-PEP gibt `403 Forbidden` zurück, bevor die Anfrage Keycloak
   erreicht.
   Alle anderen `/auth/*`-Pfade (Token-Exchange, Well-Known-Endpunkte) werden
   ohne PEP-Token-Prüfung an den Authserver weitergeleitet.
2. **Separater Admin-Ingress** — für den Admin-Hostnamen werden zwei zusätzliche
   Ingress-Ressourcen erzeugt, die `/auth` direkt an den Authserver routen
   (unter Umgehung des PEP-Proxy-Blocks). Terraform und CI/CD-Runner verwenden
   ausschließlich diesen Hostnamen.

Die Absicherung ist ingress-controller-unabhängig und funktioniert mit F5 NIC,
Standard-nginx-Ingress, OpenShift Routes, GKE Ingress und anderen Controllern,
da die Enforcement im PEP-Proxy stattfindet.

```yaml
zeta-guard:
    authserver:
        hostname: "zeta.example.com"
        # Separater Hostname für den Keycloak-Admin-Zugriff.
        # Wenn gesetzt, wird /auth/admin auf dem Haupthostnamen über den PEP-Proxy
        # gesperrt und ein dedizierter Admin-Ingress für diesen Hostnamen erzeugt.
        adminHostname: "admin.zeta.example.com"
```

Für Umgebungen, in denen kein ClusterIssuer für den Admin-Hostnamen verfügbar
ist (z.B. KIND), kann ein bestehendes TLS-Secret wiederverwendet werden:

```yaml
zeta-guard:
    authserver:
        adminTlsSecretName: "zeta-guard-tls"  # bestehendes Secret wiederverwenden
```

Um die Funktion zu deaktivieren, entfernen Sie `adminHostname` (oder setzen Sie
es auf `""`) und führen Sie `helm upgrade` aus. Der Admin-Ingress und die
PEP-Proxy-Location-Blöcke werden automatisch entfernt.

> **Einschränkung:** Wenn `routeViaTigerProxy: true` gesetzt ist, hat die
> Admin-API-Absicherung keine Wirkung, da Tiger-Proxy `/auth` intern direkt an
> den Authserver weiterleitet und die PEP-Proxy-Location-Blöcke umgeht.
> Tiger-Proxy ist ausschließlich ein Testwerkzeug und wird in
> Produktionsdeployments nicht eingesetzt.

> **IP-basierte Zugriffsbeschränkung** für den Admin-Hostnamen muss auf
> Infrastrukturebene konfiguriert werden: Cloud Armor (GKE),
> NetworkPolicy/Route-Annotation (OpenShift) oder Firewall-Regeln. Das Chart
> erzwingt keine IP-basierte Zugriffsbeschränkung.

---

### CloudNativePG-Datenbankverbindung

Im Datenbankmodus `cloudnative` sind JDBC-URL, Secret-Name und Schema
konfigurierbar:

```yaml
zeta-guard:
    databaseMode: cloudnative
    cloudnativeDbUrl: "jdbc:postgresql://keycloak-db-rw:5432/keycloak"
    cloudnativeDbSecretName: "keycloak-db-app"
    cloudnativeDbSchema: "public"
```

Die Standardwerte verweisen auf den vom CloudNativePG-Operator erzeugten
Service und das zugehörige Secret. Passen Sie diese an, wenn Sie eine
abweichende Datenbankinstanz verwenden.

Tuning-Parameter, die direkt an die PostgreSQL-Konfiguration des
CloudNativePG-Clusters durchgereicht werden, sind unter `cloudnativePg.parameters`
konfigurierbar:

```yaml
zeta-guard:
    cloudnativePg:
        parameters:
            sharedBuffers: 128MB
            maxConnections: 400
```

| Value                                     | Beschreibung                 | Standard |
|-------------------------------------------|------------------------------|----------|
| `cloudnativePg.parameters.sharedBuffers`  | PostgreSQL `shared_buffers`  | `128MB`  |
| `cloudnativePg.parameters.maxConnections` | PostgreSQL `max_connections` | `400`    |

> **Hinweis:** Die mitgelieferte `values-demo.yaml` verwendet kleinere Werte
> (`sharedBuffers: 24MB`, `maxConnections: 100`) für ressourcenarme Test-Cluster.
> `maxConnections` muss zu den Keycloak-Pool-Größen (siehe unten) passen.

### Connection Pooling (Keycloak)

Keycloak hält serverseitig einen JDBC-Datenbank-Pool sowie einen HTTP-Worker-Pool.
Beide sind konfigurierbar und wurden für höheren Durchsatz angepasst:

```yaml
zeta-guard:
    authserver:
        dbPool:
            minSize: 100
            maxSize: 500
        httpPool:
            maxThreads: 300
```

| Value                            | Beschreibung                                     | Standard |
|----------------------------------|--------------------------------------------------|----------|
| `authserver.dbPool.minSize`      | Minimale Größe des JDBC-Connection-Pools         | `100`    |
| `authserver.dbPool.maxSize`      | Maximale Größe des JDBC-Connection-Pools         | `500`    |
| `authserver.httpPool.maxThreads` | Maximale Anzahl der Keycloak-HTTP-Worker-Threads | `300`    |

> **Hinweis:** `dbPool.maxSize` (pro Authserver-Replica) muss zusammen mit der
> Replica-Anzahl unter `cloudnativePg.parameters.maxConnections` der Datenbank
> passen, sonst weist PostgreSQL Verbindungen ab.

### HSM-Konfiguration

HSM-Integration für TLS und Token-Signierung:

```yaml
zeta-guard:
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

> **Hinweis:** Die Helm-Values aktivieren die HSM-Proxy-Verbindung im
> Authorization Service (Keycloak). Die Registrierung des HSM-KeyProviders
> im Keycloak-Realm erfolgt separat über Terraform (siehe
> [Quickstart – PDP konfigurieren](../Anleitungen/ZETA_Guard_Quickstart.md#2-pdp-konfigurieren))
> mit den Variablen `hsm_token_signing_enabled`, `hsm_token_signing_endpoint`
> und `hsm_token_signing_key_id`.

---

## PEP-Proxy

### ServiceAccount

```yaml
zeta-guard:
    pepproxy:
        serviceAccount:
            create: true
            name: pep-proxy
```

### Replicas und Sticky Sessions

```yaml
zeta-guard:
    pepproxy:
        replicaCount: 3
```

Der Standardwert ist `1`. Bei `replicaCount > 1` werden Sticky Sessions
automatisch über den mitgelieferten NGINX Ingress Controller realisiert: NIC
setzt beim ersten Request einen opaken `zeta_route`-Cookie und routet
nachfolgende Requests desselben Clients via Consistent Hashing konsistent auf
denselben PEP-Pod. Dies ist eine Sicherheitsanforderung, da der
ASL Session Cache pro Pod im nginx Shared Memory liegt und nicht zwischen
Pods geteilt wird. Voraussetzung: der Client unterstützt HTTP-Cookies.

Wird ein anderer Ingress Controller verwendet
(`nginxIngressEnabled: false`), muss der Betreiber Sticky Sessions am eigenen
Ingress-Layer sicherstellen.

### Security Context

```yaml
zeta-guard:
    pepproxy:
        podSecurityContext:
            seccompProfile:
                type: RuntimeDefault
```

### Well-Known Discovery Dokument

Der PEP-Proxy stellt das OAuth Protected Resource Metadata Dokument (RFC 9728)
unter `/.well-known/oauth-protected-resource` bereit. Die Pfadanteile der
beiden enthaltenen URLs sind konfigurierbar:

```yaml
zeta-guard:
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

| Value                                | Beschreibung                                                                                   | Standard |
|--------------------------------------|------------------------------------------------------------------------------------------------|----------|
| `pepproxy.wellKnownBase`             | Öffentliche Basis-URL des PEP (fließt in das `resource`-Feld ein)                              | `""`     |
| `pepproxy.wellKnownResourceSuffix`   | Pfad-Suffix, der an `wellKnownBase` angehängt wird (inkl. führendem und abschließendem `/`)    | `/pep/`  |
| `authserver.wellKnownAuthServerPath` | Pfad-Suffix, der an `authserver.hostname` für das `authorization_servers`-Array angehängt wird | `/`      |

> **Hinweis:** Bei Deployments, bei denen Keycloak unter einem Unterpfad wie
> `/auth` betrieben wird, ist
> `authserver.wellKnownAuthServerPath: /auth` zu setzen. Wenn die Protected
> Resource direkt unter der Root-URL erreichbar ist, genügt
> `pepproxy.wellKnownResourceSuffix: /`.

---

## Infinispan

Infinispan wird über globale Values konfiguriert und kann entweder als
In-Cluster-Deployment oder als Verbindung zu einer externen Instanz genutzt
werden (siehe auch
[Wie Sie externen Infinispan konfigurieren](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_use_external_infinispan.md)).

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

Zusätzliche JVM-Optionen können über `extraJavaOptions` konfiguriert werden.
Die Basis-Optionen für JGroups-Clustering werden automatisch gesetzt.

```yaml
global:
    infinispanExternal:
        extraJavaOptions: "-XX:MaxRAMPercentage=75.0 -XX:InitialRAMPercentage=50.0"
```

### HSM-Konfiguration

Das TLS-Schlüsselmaterial von Infinispan kann optional über den HSM-Proxy bezogen
werden. Ist die HSM-Anbindung aktiviert, verwendet Infinispan einen
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

## Provisioning Processor

Der Provisioning Processor ist ein gemeinsamer Init-Container, der von
Authserver, OPA, OPA-Simulation und PEP-Proxy verwendet wird:

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
        containerSecurityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            runAsNonRoot: true
            capabilities:
                drop: [ "ALL" ]
```

### Eigene Registry für den Provisioning Container

Standardmäßig lädt der Provisioning Processor das Daten-Image von der
gematik-Registry. Für Umgebungen ohne direkten Internetzugang kann eine
eigene Registry-Spiegelung konfiguriert werden:

```yaml
zeta-guard:
    provisioningProcessor:
        provisioningContainer: "my.registry.corp.internal/zetaguard-provisioning:latest"
```

> **Hinweis:** Das gespiegelte Image muss zusammen mit seiner cosign-Signatur
> übertragen werden. Ein einfaches `docker pull/push` überträgt die Signatur
> nicht. Siehe
> [Wie Sie eine eigene OCI Registry verwenden](../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).

### CA-Zertifikat für die Provisioning-Container-Registry

Wenn die Registry ein TLS-Zertifikat verwendet, das von einer internen CA
ausgestellt wurde, muss das CA-Zertifikat dem Init-Container mitgegeben werden.
Das Zertifikat wird aus einem Kubernetes Secret als Datei in den Init-Container
gemountet. Diese Variante vermeidet das Kernel-Limit `ARG_MAX`, das bei der
Übergabe von Zertifikatsketten als Umgebungsvariable überschritten werden kann.

```yaml
zeta-guard:
    provisioningProcessor:
        provisioningContainerCaSecretRef:
            name: registry-ca        # Name des Kubernetes Secrets
            key: ca.crt              # Key innerhalb des Secrets
```

### Cosign-Vertrauenskette für Image-Verifikation

Der Helm Value `imageTrustCertchainSecretRef` benennt ein Kubernetes Secret, das
die CA-Zertifikatskette der gematik enthält. Der Provisioning Processor prüft
damit die cosign-Signatur des Provisioning-Daten-Images beim Pod-Start.

Das Secret muss den Key `certchain.pem` mit einer PEM-kodierten
X.509-Zertifikatskette enthalten (CA- und Zwischenzertifikate, kein
Leaf-Zertifikat). Es wird als Volume `image-trustchain` in den Init-Container
des Provisioning Processors jedes der folgenden Deployments eingebunden:
**Authserver**, **PEP-Proxy**, **OPA** und **OPA-Simulation**. Der Pfad im
Container lautet `/var/image-trustchain/certchain.pem` (Umgebungsvariable
`TRUST_CERTCHAIN_FILE`).

> **Pflichtfeld:** Das Helm Chart bricht beim Rendern mit einem Fehler ab, wenn
> `imageTrustCertchainSecretRef` nicht gesetzt ist.

```yaml
zeta-guard:
    imageTrustCertchainSecretRef: my-image-signer
```

Das Secret wird typischerweise so angelegt:

```bash
kubectl create secret generic my-image-signer \
  --from-file=certchain.pem=/path/to/gematik-certchain.pem \
  --namespace NAMESPACE
```

Die Zertifikatskette ist von der gematik zu beziehen. Für Testumgebungen
enthält das Helm Chart im Verzeichnis `templates/` ein vorgefertigtes Secret
`gematik-image-signer-test` mit den Testzertifikaten GEM.KOMP-CA61 und
GEM.RCA7 (jeweils TEST-ONLY). Der Standardwert in `values-demo.yaml` verweist
auf dieses Test-Secret.

> **Wichtig:** Das Test-Secret `gematik-image-signer-test` enthält
> Testzertifikate und darf **nicht** in Produktivumgebungen verwendet werden.
> Für den Produktivbetrieb muss das Secret mit den von der gematik
> bereitgestellten
> Produktivzertifikaten befüllt werden.

---

## Terraform-Konfiguration (PDP)

Die PDP-Konfiguration erfolgt über Terraform. Zu den wichtigsten Variablen
gehört:

| Variable              | Standard          | Beschreibung                                                                                                               |
|-----------------------|-------------------|----------------------------------------------------------------------------------------------------------------------------|
| `use_kubernetes`      | `true`            | Terraform-Betriebsmodus (`true` = K8s-Backend, `false` = lokal)                                                            |
| `keycloak_url`        | —                 | Externe URL des Keycloak-Servers (bei Admin-API-Absicherung: URL des Admin-Hostnamens)                                     |
| `keycloak_namespace`  | —                 | Kubernetes-Namespace des Authservers                                                                                       |
| `pdp_scopes`          | `[]`              | Zusätzliche PDP-Scopes                                                                                                     |
| `audience_scope_name` | `"zero:audience"` | Name des Audience-Scopes                                                                                                   |
| `audience`            | `""`              | Expliziter Audience-Wert im Access Token. Erforderlich, wenn `keycloak_url` auf einen Admin-Hostnamen zeigt (siehe unten). |
| `insecure_tls`        | `false`           | Selbst signierte Zertifikate zulassen                                                                                      |

Wenn `adminHostname` gesetzt ist und `keycloak_url` auf den Admin-Hostnamen
zeigt, muss `audience` explizit auf den **öffentlichen Haupthostnamen** gesetzt
werden — andernfalls würde der Audience-Wert aus der URL abgeleitet und stimmte
nicht mit dem überein, was die Access Tokens tragen:

```hcl
keycloak_url = "https://admin.zeta.example.com/auth"
audience     = "https://zeta.example.com"
```

Details zu den Terraform-Betriebsmodi finden sich im
[Quickstart](../Anleitungen/ZETA_Guard_Quickstart.md#2-pdp-konfigurieren).
