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
    - [cert-manager-Issuer für Ingress-TLS](#cert-manager-issuer-für-ingress-tls)
    - [CloudNativePG-Datenbankverbindung](#cloudnativepg-datenbankverbindung)
    - [Connection Pooling (Keycloak)](#connection-pooling-keycloak)
    - [HSM-Konfiguration](#hsm-konfiguration)
    - [SMC-B OCSP-Sperrprüfung](#smc-b-ocsp-sperrprüfung)
    - [Spree integrity provider (VAU)](#spree-integrity-provider-vau)
    - [Mobiler Client-Flow (OIDC)](#mobiler-client-flow-oidc)
- [PEP-Proxy](#pep-proxy)
    - [ServiceAccount](#serviceaccount-1)
    - [Replicas und Sticky Sessions](#replicas-und-sticky-sessions)
    - [Security Context](#security-context)
    - [Well-Known Discovery Dokument](#well-known-discovery-dokument)
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
    - [Provisioning Container je Umgebung](#provisioning-container-je-umgebung)
    - [Eigene Registry für den Provisioning Container](#eigene-registry-für-den-provisioning-container)
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

Für nginx (PEP) erzeugt der Chart zusätzlich `env`-Direktiven in der
`nginx.conf`. Für Keycloak (Authserver) wird `global.noProxy` automatisch in das
`-Dhttp.nonProxyHosts`-Format konvertiert (Pipe-Trenner, `*`-Wildcard statt
führendem Punkt). Subcharts wie `telemetry-gateway` sind upstream-Charts und
konsumieren `global` nicht — diese müssen bei Bedarf manuell konfiguriert
werden.

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

1. **`/auth/admin` wird an den PEP-Proxy geroutet, der es sperrt** — der Ingress
   `zeta-guard-pep` erhält einen zusätzlichen Pfad `/auth/admin` auf
   `pep-proxy-svc`. Dort gibt ein `location ~ ^/auth/admin`-Block
   `403 Forbidden` zurück, bevor die Anfrage Keycloak erreicht. Alle anderen
   `/auth/*`-Pfade (Token-Exchange, Nonce, Client-Registration,
   Well-Known-Endpunkte) werden über den Ingress `zeta-guard-auth` **direkt** an
   den Authserver geroutet und erreichen den PEP nie.
2. **Separater Admin-Ingress** — für den Admin-Hostnamen werden zwei zusätzliche
   Ingress-Ressourcen erzeugt, die `/auth` direkt an den Authserver routen
   (unter Umgehung des PEP-Proxy-Blocks). Terraform und CI/CD-Runner verwenden
   ausschließlich diesen Hostnamen.

Die Aufteilung funktioniert, weil überlappende Pfad-Prefixe nach dem längsten
Treffer aufgelöst werden — unabhängig von der Reihenfolge, in der sie deklariert
sind. Das garantieren sowohl NGINX als auch die Kubernetes-Ingress-Spezifikation,
`/auth/admin` gewinnt also gegen `/auth`.

Die Absicherung ist ingress-controller-unabhängig und funktioniert mit F5 NIC,
Standard-nginx-Ingress, OpenShift Routes, GKE Ingress und anderen Controllern,
da sie ausschließlich auf Standard-Ingress-Pfad-Routing und der
NGINX-Konfiguration des PEP beruht — nicht auf controller-spezifischen
Annotationen.

```yaml
zeta-guard:
    authserver:
        hostname: "zeta.example.com"
        # Separater Hostname für den Keycloak-Admin-Zugriff.
        # Wenn gesetzt, wird /auth/admin auf dem Haupthostnamen an den PEP-Proxy
        # geroutet und dort mit 403 gesperrt; zusätzlich wird ein dedizierter
        # Admin-Ingress für diesen Hostnamen erzeugt.
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
es auf `""`) und führen Sie `helm upgrade` aus. Der Admin-Ingress, der
`/auth/admin`-Ingress-Pfad und der PEP-Proxy-Location-Block werden automatisch
entfernt — `/auth/admin` ist danach wieder über den Haupthostnamen erreichbar,
da es sonst keinen Zugang mehr gäbe.

> **Einschränkung:** Wenn `routeViaTigerProxy: true` gesetzt ist, wird der
> `/auth/admin`-Ingress-Pfad **nicht** erzeugt: Tiger-Proxy leitet `/auth` intern
> direkt an den Authserver weiter und umgeht den PEP vollständig, ein Routing
> dorthin würde also nichts sperren. Mit F5 NIC greift in diesem Fall noch die
> `location-snippets`-Annotation auf `zeta-guard-auth` und antwortet mit `404`;
> mit jedem anderen Ingress-Controller bleibt `/auth/admin` auf dem
> Haupthostnamen erreichbar. Tiger-Proxy ist ausschließlich ein Testwerkzeug und
> wird in Produktionsdeployments nicht eingesetzt.

> **Der Browser eines Administrators benötigt *beide* Hostnamen.** Die Admin
> Console ist eine Browser-Anwendung, die vom Admin-Hostnamen ausgeliefert wird,
> sich aber gegen den **öffentlichen** Hostnamen authentifiziert: Keycloak gibt
> der Console eine aus `--hostname` abgeleitete `serverBaseUrl`, der
> Login-Redirect geht daher auf
> `https://<haupthost>/auth/realms/master/protocol/openid-connect/auth` und erst
> danach zurück auf den Admin-Hostnamen. Die Admin-REST-Aufrufe und alle
> statischen Ressourcen bleiben dagegen auf dem Admin-Hostnamen
> (`/auth/admin/...`) — deshalb steht die `403`-Sperre auf dem Haupthostnamen der
> Admin UI nicht im Weg.
>
> Folge für den Netzentwurf: Den Admin-Hostnamen auf ein internes Netz zu
> beschränken ist unproblematisch, aber ein Arbeitsplatz, der *ausschließlich*
> den Admin-Hostnamen erreicht, kann den Login nicht abschließen. Terraform und
> CI/CD-Runner sind davon nicht betroffen — sie nutzen die Admin-REST-API direkt
> über `admin-cli` und durchlaufen keinen Browser-Flow.

> **IP-basierte Zugriffsbeschränkung** für den Admin-Hostnamen muss auf
> Infrastrukturebene konfiguriert werden: Cloud Armor (GKE),
> NetworkPolicy/Route-Annotation (OpenShift) oder Firewall-Regeln. Das Chart
> erzwingt keine IP-basierte Zugriffsbeschränkung.

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
referenzierte
`Issuer` muss dann im Deployment-Namespace existieren.

```yaml
zeta-guard:
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
zeta-guard:
    databaseMode: cloudnative
    cloudnativeDbUrl: "jdbc:postgresql://keycloak-db-rw:5432/keycloak"
    cloudnativeDbSecretName: "keycloak-db-app"
    cloudnativeDbSchema: "public"
```

Die Standardwerte verweisen auf den vom CloudNativePG-Operator erzeugten Service
und das zugehörige Secret. Passen Sie diese an, wenn Sie eine abweichende
Datenbankinstanz verwenden.

Tuning-Parameter, die direkt an die PostgreSQL-Konfiguration des
CloudNativePG-Clusters durchgereicht werden, sind unter
`cloudnativePg.parameters`
konfigurierbar:

```yaml
zeta-guard:
    cloudnativePg:
        parameters:
            sharedBuffers: 512MB
            maxConnections: 250
```

| Value                                     | Beschreibung                 | Standard |
|-------------------------------------------|------------------------------|----------|
| `cloudnativePg.parameters.sharedBuffers`  | PostgreSQL `shared_buffers`  | `512MB`  |
| `cloudnativePg.parameters.maxConnections` | PostgreSQL `max_connections` | `250`    |

> **Hinweis:** Die mitgelieferte `values-demo.yaml` verwendet kleinere Werte
> (`sharedBuffers: 24MB`, `maxConnections: 100`) für ressourcenarme
> Test-Cluster.
> `maxConnections` muss zu den Keycloak-Pool-Größen (siehe unten) passen.

### Connection Pooling (Keycloak)

Keycloak hält serverseitig einen JDBC-Datenbank-Pool sowie einen
HTTP-Worker-Pool. Beide sind konfigurierbar:

```yaml
zeta-guard:
    authserver:
        dbPool:
            minSize: 10
            maxSize: 100
        httpPool:
            maxThreads: 300
```

| Value                            | Beschreibung                                     | Standard |
|----------------------------------|--------------------------------------------------|----------|
| `authserver.dbPool.minSize`      | Minimale Größe des JDBC-Connection-Pools         | `10`     |
| `authserver.dbPool.maxSize`      | Maximale Größe des JDBC-Connection-Pools         | `100`    |
| `authserver.httpPool.maxThreads` | Maximale Anzahl der Keycloak-HTTP-Worker-Threads | `300`    |

> **Hinweis:** `replicaCount × dbPool.maxSize` muss (zzgl. Reserve) unter
> `cloudnativePg.parameters.maxConnections` bleiben; das Chart prüft dies beim
> Rendern.

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

### SMC-B OCSP-Sperrprüfung

Beim Token-Exchange prüft der Authorization Service den Sperrstatus des
SMC-B-Zertifikats per OCSP. Die Timeouts der OCSP-Anfrage sowie das Verhalten
bei nicht bestimmbarem Sperrstatus sind konfigurierbar:

```yaml
zeta-guard:
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
> immer abgelehnt. Ist kein OCSP-Signer-Truststore hinterlegt, ist die Prüfung
> deaktiviert und der Token-Exchange läuft ohne Sperrprüfung (nur für
> Testumgebungen).

---

### Spree integrity provider (VAU)

Konfiguration des Spree integrity providers (VAU-DB-Verschlüsselung und
Integritätsprüfungen)

```yaml
authserver:
    dbEnc:
        enabled: false
        columnEncryptionEnabled: false
        integrityChecksEnabled: false
        integrityRowChecksEnabled: false
        integrityTableChecksEnabled: false
        periodicRowChecksEnabled: false
        lockdownOnError: false
        shutdownOnError: false
        bootstrapInterval: "PT30S"
        bootstrapAttempts: 15
        keychainFileName: ""
        keychainGenerator:
            extraVolumeMounts: []
```

| Value                                                  | Beschreibung                                                                                                                                   | Standard |
|--------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `authserver.dbEnc.enabled`                             | Aktivierung des Spree integrity providers                                                                                                      | `false`  |
| `authserver.dbEnc.integrityChecksEnabled`              | Aktivierung von Integritätsprüfungen und Verschlüsselung global                                                                                | `false`  |
| `authserver.dbEnc.columnEncryptionEnabled`             | Aktivierung der Spaltenverschlüsselung gemäß Konfiguration auf Entitätsebene                                                                   | `false`  |
| `authserver.dbEnc.integrityRowChecksEnabled`           | Aktivierung von Integritätsprüfungen auf Datenbank-Zeilenebene                                                                                 | `false`  |
| `authserver.dbEnc.integrityTableChecksEnabled`         | Aktivierung von Integritätsprüfungen auf Tabellenebene                                                                                         | `false`  |
| `authserver.dbEnc.periodicRowChecksEnabled`            | Aktivierung der periodischen Integritätsprüfung auf Datenbank-Zeilenebene; bei Deaktivierung wird weiterhin bei jedem direkten Zugriff geprüft | `false`  |
| `authserver.dbEnc.lockdownOnError`                     | Aktivierung eines internen Fehlerstates, in dem der Authserver weitere Anfragen abweist                                                        | `false`  |
| `authserver.dbEnc.shutdownOnError`                     | Automatisches Herunterfahren des Authservers, wenn Integritätsprüfungen fehlschlagen                                                           | `false`  |
| `authserver.dbEnc.bootstrapAttempts`                   | Anzahl der Versuche das System zu initialisieren                                                                                               | `15`     |
| `authserver.dbEnc.bootstrapInterval`                   | Intervall zwischen den Initialisierungsversuchen                                                                                               | `PT30S`  |
| `authserver.dbEnc.keychainFileName`                    | Pfad zur Keychain-Datei im Container                                                                                                           | `""`     |
| `authserver.dbEnc.keychainGenerator.extraVolumeMounts` | Zusätzliche Volume-Mounts für den Keychain-Generator (Einhängen der Keychain-Datei)                                                            | `[]`     |

Die Keychain-Datei wird über `authserver.extraVolumes` aus einem Secret
bereitgestellt. Ein vollständiges Beispiel siehe
[Wie Sie ZETA Guard in Kubernetes konfigurieren, Abschnitt 10](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#10-besonderheiten-vau-und-keycloak-datenbank).

### Mobiler Client-Flow (OIDC)

```yaml
zeta-guard:
    authserver:
        config:
            oidcFlowEnabled: false
```

| Value                               | Beschreibung                                                                                                                                                             | Standard |
|-------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------|
| `authserver.config.oidcFlowEnabled` | Schaltet den [mobilen Client-Flow](../Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md) frei (setzt die Umgebungsvariable `ZETA_OIDC_FLOW_ENABLED` am Authserver). | `false`  |

Für den OTP-Versand der E-Mail-Bindung muss zusätzlich SMTP im Realm
konfiguriert sein — siehe die SMTP-Variablen unter
[Terraform-Konfiguration (PDP)](#terraform-konfiguration-pdp).

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
denselben PEP-Pod. Dies ist eine Sicherheitsanforderung, da der ASL Session
Cache pro Pod im nginx Shared Memory liegt und nicht zwischen Pods geteilt wird.
Voraussetzung: der Client unterstützt HTTP-Cookies.

Wird ein anderer Ingress Controller verwendet (`nginxIngressEnabled: false`),
muss der Betreiber Sticky Sessions am eigenen Ingress-Layer sicherstellen.

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
unter `/.well-known/oauth-protected-resource` bereit. Die Pfadanteile der beiden
enthaltenen URLs sind konfigurierbar:

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

Das Feld `zeta_asl_use` wird aus `pepproxy.asl_enabled` abgeleitet und ist nicht
fest `required`: bei deaktiviertem ASL — dem Standard — weist das Dokument
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
> Token-Prüfungen
> schlagen fehl.
>
> Die beiden URLs werden durch einfache Verkettung ohne Normalisierung
> gebildet (`resource = wellKnownBase + wellKnownResourceSuffix`). Ein Schema im
> `hostname`, ein doppelter `/` oder ein doppelter Pfadanteil (z.B.
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
das Vorhandensein des `PoPP` -Headers und validiert das Token
(`pep_require_popp on;`); mit `null` ist die PoPP-Prüfung deaktiviert.
`pepproxy.nginxConf.poppValidity` legt die Gültigkeitsdauer des Tokens ab
Ausstellung fest — `quarter` (selbes Kalenderquartal) oder eine feste Dauer
seit `iat` mit Einheit `d`/`h`/`m`/`s` (z.B. `1d`, `86400`).

| Value                             | Beschreibung                                                                                                                                                | Standard  |
|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------|
| `pepproxy.nginxConf.poppIssuer`   | Issuer des PoPP-Servers (Entity Statement unter `/.well-known/openid-federation`). Wenn gesetzt, wird PoPP verlangt und validiert; `null` deaktiviert PoPP. | `null`    |
| `pepproxy.nginxConf.poppValidity` | Gültigkeitsdauer des PoPP-Tokens ab `iat`: `quarter` oder feste Dauer (`d`/`h`/`m`/`s`, Standardeinheit `s`).                                               | `quarter` |

Details zu PEP-Direktiven `pep_require_popp` und`pep_popp_validity` siehe
[PEP-Konfiguration](Konfiguration_des_PEP_Http_Proxy.md).

### nginx-Konfiguration (Fachdienst-Routing)

Das Chart kann die nginx-ConfigMap des PEP-Proxy aus Values generieren
(`generateConfigMap: true`). Die daraus resultierende Konfiguration steuert,
wie eingehende Requests an den Resource Server (Fachdienst) weitergeleitet
werden.

| Value                                             | Beschreibung                                                                                                                                                                                                                              | Standard         |
|---------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|------------------|
| `pepproxy.nginxConf.generateConfigMap`            | Wenn `true`, generiert das Chart die nginx-ConfigMap aus den untenstehenden Values. Bei `false` muss eine ConfigMap mit dem Namen `configMapName` extern bereitgestellt werden; alle weiteren `nginxConf.*`-Values werden dann ignoriert. | `false`          |
| `pepproxy.nginxConf.configMapName`                | Name der ConfigMap, die in den PEP-Pod gemountet wird — unabhängig davon, ob das Chart sie generiert oder sie extern existiert.                                                                                                           | `pep-nginx-conf` |
| `pepproxy.nginxConf.pepIssuer`                    | OIDC-Issuer des Authorization Servers. Wird für die Token-Validierung (`pep_issuer`) und den JWKS-Abruf verwendet.                                                                                                                        | `""`             |
| `pepproxy.nginxConf.requiredAudience`             | Audience, die ein gültiges Access-Token enthalten muss (`pep_require_aud`).                                                                                                                                                               | `""`             |
| `pepproxy.nginxConf.requiredScopes`               | Liste der geforderten Scopes (`pep_require_scope`).                                                                                                                                                                                       | `[]`             |
| `pepproxy.nginxConf.proxyLocations`               | Strukturierte Definition der Fachdienst-Pfade (siehe unten). Kann nicht zusammen mit `locations` verwendet werden.                                                                                                                        | `[]`             |
| `pepproxy.nginxConf.locations`                    | **Deprecated und zur Entfernung vorgesehen.** Roher nginx-Location-Block als Go-Template-String. Schließt sich mit `proxyLocations` aus (siehe Hinweis unten).                                                                            | `""`             |
| `pepproxy.nginxConf.fachdienstUrl`                | **Deprecated.** Optionale Hilfsvariable, die im `locations`-Template referenziert werden kann.                                                                                                                                            | `""`             |
| `pepproxy.nginxConf.httpClientAcceptInvalidCerts` | Akzeptiert ungültige TLS-Zertifikate bei internen HTTP-Verbindungen des PEP (JWKS, OIDC Discovery). **Nur für Testumgebungen.**                                                                                                           | `false`          |
| `pepproxy.nginxConf.aslTestmode`                  | Aktiviert den ASL-Testmodus (deaktiviert Verschlüsselung). **Niemals in Produktion setzen.**                                                                                                                                              | `false`          |
| `pepproxy.nginxConf.noTravel`                     | Aktiviert (`true`) oder deaktiviert (`false`) die No-Travel-Prüfung (IP-Bindung).                                                                                                                                                         | `false`          |

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
[Wie Sie ZETA Guard in Kubernetes konfigurieren](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#7-policy-enforcement-point-nginx-konfigurieren).

### HSM-Konfiguration (TLS)

Der PEP-Proxy kann TLS mit einem privaten Schlüssel terminieren, der im HSM
verbleibt. Dafür wird der OpenSSL-Provider `ossl_hsm` verwendet: Der private
Schlüssel verlässt das HSM zu keinem Zeitpunkt — die Signatur-Operationen des
TLS-Handshakes werden per gRPC an den HSM-Proxy delegiert. Das zugehörige
Zertifikat liegt als gewöhnliche PEM-Datei im Container vor.

```yaml
zeta-guard:
    pepproxy:
        hsmProxyAddr: "hsm-proxy:50051"   # gRPC-Adresse des HSM-Proxy; null deaktiviert die HSM-Anbindung
        hsmTlsKeyId: "tls.p256"           # Schlüssel-ID des TLS-Schlüssels im HSM
        hsmTlsCert: "tls.p256.pem"        # zum HSM-Schlüssel passende Zertifikatsdatei (relativ zu /etc/nginx)
```

Ist `pepproxy.hsmProxyAddr` gesetzt,

- erhält der nginx-Container die Umgebungsvariable `HSM_PROXY_ADDR`, die der
  `ossl_hsm`-Provider ausliest, und
- öffnet der PEP zusätzlich zum HTTP-Listener (Port 8081) einen TLS-Listener auf
  Port 8443 mit `ssl_certificate_key "store:hsm:<hsmTlsKeyId>"` — der Schlüssel
  wird dabei nur über seine Schlüssel-ID im HSM referenziert.

| Value                   | Beschreibung                                                                                                                                                                                                  | Standard       |
|-------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------|
| `pepproxy.hsmProxyAddr` | gRPC-Adresse des HSM-Proxy. Wenn gesetzt, terminiert der PEP TLS auf Port 8443 mit dem HSM-Schlüssel `hsmTlsKeyId` über den `ossl_hsm`-Provider; `null` deaktiviert die HSM-Anbindung.                        | `null`         |
| `pepproxy.hsmTlsKeyId`  | Schlüssel-ID des TLS-Schlüssels im HSM (`ssl_certificate_key "store:hsm:<hsmTlsKeyId>"`). Nur relevant, wenn `hsmProxyAddr` gesetzt ist.                                                                      | `tls.p256`     |
| `pepproxy.hsmTlsCert`   | Zum HSM-Schlüssel passende Zertifikatsdatei, relativ zu `/etc/nginx`. Die Standard-Datei ist im PEP-Image enthalten und passt zum HSM-Simulator; eigene Zertifikate werden per `extraVolumeMounts` gemountet. | `tls.p256.pem` |

> **Hinweis:** Die Schlüssel-ID ist für die gRPC-Schnittstelle ein opaker
> String: Der HSM-Proxy muss die konfigurierte ID auf den passenden Schlüssel
> abbilden — wie der Schlüssel im HSM selbst benannt ist, spielt dabei keine
> Rolle. Das im PEP-Image enthaltene Standard-Zertifikat (`tls.p256.pem`) passt
> zum HSM-Simulator (`hsm-sim`); für ein produktives HSM muss das zum
> HSM-Schlüssel passende Zertifikat über `pepproxy.extraVolumes` /
> `pepproxy.extraVolumeMounts` in den Container gemountet und der Dateiname in
> `pepproxy.hsmTlsCert` eingetragen werden.

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
zeta-guard:
    pepproxy:
        asl_enabled: true
        hsmProxyAddr: "hsm-proxy:50051"
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
[Wie Sie ZETA Guard in Kubernetes konfigurieren](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md).

### Extra Volumes

Über `pepproxy.extraVolumes` und `pepproxy.extraVolumeMounts` lassen sich
beliebige zusätzliche Volumes in den PEP-Container mounten — etwa das
Client-Zertifikat und der Truststore für mTLS zum Resource Server oder ein
eigenes TLS-Zertifikat für die HSM-Konfiguration.

| Value                        | Beschreibung                                                                          | Standard |
|------------------------------|---------------------------------------------------------------------------------------|----------|
| `pepproxy.extraVolumes`      | Zusätzliche `volumes`-Einträge des PEP-Pods (Kubernetes-Syntax, z. B. Secret-Volumes) | `[]`     |
| `pepproxy.extraVolumeMounts` | Zugehörige `volumeMounts`-Einträge des nginx-Containers                               | `[]`     |

Ein vollständiges Beispiel für mTLS zum Resource Server siehe
[Wie Sie ZETA Guard in Kubernetes konfigurieren, Abschnitt 9](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#9-mtls-zum-resource-server-ohne-service-mesh).

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
(„clusterless“ Modus, `KC_CACHE_REMOTE_*`). Bei einer Installation ohne dieses
Subchart müssen Sie deshalb eine selbst betriebene Instanz über
`remote.host`/`remote.port` angeben.

### Verbindung (Remote-Cache)

`remote.host` und `remote.port` steuern, ob das Chart Infinispan selbst deployt.
Sind beide Werte gesetzt, wird kein Infinispan-Deployment erzeugt und der
Authserver verbindet sich gegen die angegebene Adresse. Sind sie leer, deployt
das Subchart Infinispan und der Authserver verwendet den chart-internen Service
`infinispan:11222`. Die Werte wirken nur gemeinsam: ist nur einer gesetzt, gilt
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
| `global.infinispanExternal.replicaCount` | Anzahl der Infinispan-Pods (nur bei chart-eigenem Deployment)          | `3`      |
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
`zeta-guard.opa`.

Dieser Abschnitt ist die reine Value-Referenz. Wie die Policy-Quelle gewählt
wird, wie der Zugriff auf eine private Registry eingerichtet wird und wie sich
fehlgeschlagene Bundle-Downloads diagnostizieren lassen, beschreibt die Anleitung
[Wie Sie OPA in ZETA Guard konfigurieren](../Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md).

### Deployment und Betrieb

```yaml
zeta-guard:
    opa:
        replicaCount: 2
        image:
            repository: opa
            tag: 1.19.0-static
```

| Value                                | Beschreibung                                                                                          | Standard         |
|--------------------------------------|-------------------------------------------------------------------------------------------------------|------------------|
| `opa.replicaCount`                   | Anzahl der OPA-Replicas. OPA ist zustandslos und horizontal skalierbar.                               | `1`              |
| `opa.image.repository`               | Image-Repository                                                                                      | `opa`            |
| `opa.image.tag`                      | Image-Tag                                                                                             | `1.19.0-static`  |
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
| `opa.containerSecurityContext`       | Security Context des OPA-Containers (auch für `opa-simulation`)                                       | PSS `restricted` |
| `opa.cronjobSecurityContext`         | Security Context der Token-Renewer-CronJobs                                                           | s. u.            |

Standardressourcen: `limits.memory: 1Gi`, `requests.cpu: 100m`,
`requests.memory: 200Mi`.

> **Hinweis zu `cronjobSecurityContext`:** Hier wird bewusst **kein** `runAsUser`
> gesetzt. Umgebungen, die für
> `opa.workloadIdentityFederation.worker.image` das Standard-Image
> `google/cloud-sdk` verwenden (läuft als root), müssen `runAsUser` in ihren
> eigenen Stage-Values überschreiben. `readOnlyRootFilesystem` ist hier — anders
> als beim OPA-Container — `false`.

### Logging und Telemetrie

| Value                  | Beschreibung                                                        | Standard |
|------------------------|---------------------------------------------------------------------|----------|
| `opa.logLevel`         | Log-Level des OPA-Servers: `debug`, `info`, `warn` oder `error`     | `info`   |
| `opa.logDecisions`     | Policy-Entscheidungen als Decision Logs auf die Konsole schreiben   | `true`   |
| `opa.logStatusUpdates` | Status-Updates (u. a. Bundle-Aktivierung) auf die Konsole schreiben | `false`  |

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
| `opa.simulation.bundle.resource`     | Eigene Bundle-Referenz für die Simulation. Leer = wird aus `opa.bundle.resource` abgeleitet.                                                         | `""`     |
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

### Provisioning Container je Umgebung

`provisioningProcessor.provisioningContainer` bestimmt, welches
Provisioning-Daten-Image geladen wird. Die Vorbelegung des Charts zeigt auf das
Image der **RU/RUDEV**-Umgebung; für TU und PU ist der Wert vom Betreiber zu
setzen, passend zur jeweiligen Vertrauenskette in
`imageTrustCertchainSecretRef`. Die Image-Referenzen und Bezugsquellen der
Vertrauensanker je Umgebung stehen in
[Wie Sie ZETA Guard in Kubernetes konfigurieren — Provisioning Processor](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#64-provisioning-processor-image-vertrauenskette-konfigurieren).

### Eigene Registry für den Provisioning Container

Standardmäßig lädt der Provisioning Processor das Daten-Image von der
gematik-Registry. Für Umgebungen ohne direkten Internetzugang kann eine eigene
Registry-Spiegelung konfiguriert werden:

```yaml
zeta-guard:
    provisioningProcessor:
        provisioningContainer: "my.registry.corp.internal/zetaguard-provisioning:latest"
```

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
zeta-guard:
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

Die Uhrzeit sollte in eine Phase geringer Last fallen: der Lauf lädt das
signierte Provisioning-Image erneut und prüft dessen cosign-Signatur.

> **Voraussetzung Kubernetes 1.32.** Das Chart setzt mindestens **Kubernetes
> 1.32 (entspr. OpenShift 4.19 oder neuer)** voraus und erzwingt diese
> Untergrenze über `kubeVersion`. Auf älteren Clustern schlägt die Installation
> deshalb mit einer klaren Meldung fehl, statt später im Betrieb aufzufallen.

> **Voraussetzung Image.** Der Sidecar braucht ein Provisioning-Processor-Image,
> das
> `SCHEDULE_TIME` unterstützt, **Version 1.3.0 aufwärts**. Wird
> `provisioningProcessor.image.tag` auf eine ältere Version gepinnt, beendet
> sich der Container nach seinem Lauf und wird
> endlos neu gestartet — inklusive erneutem Laden und Verifizieren des
> signierten
> Provisioning-Images bei jedem Versuch. Erkennbar an einem stetig steigenden
> `RESTARTS`-Zähler des Init-Containers `trust-anchor-provisioning-processor`.

Ein Startup-Probe stellt sicher, dass Keycloak erst startet, wenn der erste Lauf
alle Ergebnisdateien veröffentlicht hat — ein Sidecar muss im Gegensatz zu einem
Init-Container nicht vorher beendet sein.

Die beiden Optionen gehören zusammen: ohne den Sidecar wird zur Laufzeit nichts
neu geschrieben, und ohne den Reload liest Keycloak die Dateien nur beim Start.
Wird eine davon abgeschaltet, verliert die andere ihre Wirkung.

```yaml
zeta-guard:
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
verglichen wird ein Hash über die Dateibytes, gelesen und geparst wird nur bei
einer Änderung. Ein kürzeres Intervall verkürzt damit vor allem die Zeitspanne,
in der eine widerrufene CA noch akzeptiert wird.

Einzelheiten zum
Verhalten: [Konfiguration des Authentication Services](Konfiguration_des_PDP_Services.md#aktualisierung-der-truststores-im-laufenden-betrieb).

> **Hinweis:** Das gespiegelte Image muss zusammen mit seiner cosign-Signatur
> übertragen werden. Ein einfaches `docker pull/push` überträgt die Signatur
> nicht. Siehe
> [Wie Sie eine eigene OCI Registry verwenden](../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).

### CA-Zertifikat für private Registries

Wenn die Registry ein TLS-Zertifikat verwendet, das von einer internen CA
ausgestellt wurde, muss das CA-Zertifikat dem Init-Container mitgegeben werden.
Das Zertifikat wird aus einem Kubernetes Secret als Datei in den Init-Container
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
[Wie Sie eine eigene OCI Registry verwenden](../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).

```yaml
zeta-guard:
    provisioningProcessor:
        provisioningContainerCaSecretRef:
            name: registry-ca        # Name des Kubernetes Secrets
            key: ca.crt              # Key innerhalb des Secrets
```

Alternativ kann das CA-Zertifikat aus einer **ConfigMap** gemountet werden (die
öffentlichen CA-Teile sind nicht geheim). Das passt zum OpenShift-Mechanismus
[„Configuring a custom PKI"](https://docs.openshift.com/container-platform/latest/networking/configuring-a-custom-pki.html),
der das CA-Bundle als ConfigMap bereitstellt.
`provisioningContainerCaSecretRef` und `provisioningContainerCaConfigMapRef`
schließen sich gegenseitig aus; ist beides gesetzt, hat die Secret-Referenz
Vorrang.

```yaml
zeta-guard:
    provisioningProcessor:
        provisioningContainerCaConfigMapRef:
            name: zeta-guard-openshift-ca-bundle   # Name der Kubernetes ConfigMap
            key: ca-bundle.crt                     # Key innerhalb der ConfigMap
```

Für beliebige andere Einbindungen stehen die generischen Werte
`provisioningProcessor.extraEnv`, `extraVolumes` und `extraVolumeMounts` am
Init-Container zur Verfügung. Damit werden Volume, Mount und die
Umgebungsvariable `PROVISIONING_CONTAINER_REGISTRY_CA_FILE` selbst verdrahtet:

```yaml
zeta-guard:
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
einem Kubernetes Secret bereitgestellt werden. Der Init-Container führt damit
vor dem Laden des Images ein `cosign login` aus. Das Secret wird über
`provisioningProcessor.registryCredentialsSecretRef` referenziert.

```yaml
zeta-guard:
    provisioningProcessor:
        registryCredentialsSecretRef:
            name: registry-credentials   # Name des Kubernetes Secrets
            usernameKey: username        # Key des Benutzernamens (Standard: username)
            tokenKey: token              # Key des Tokens (Standard: token)
```

`usernameKey` und `tokenKey` sind optional und müssen nur gesetzt werden, wenn
das Secret abweichende Key-Namen verwendet. Daraus werden die Umgebungsvariablen
`PROVISIONING_CONTAINER_REGISTRY_USERNAME` und
`PROVISIONING_CONTAINER_REGISTRY_TOKEN` im Init-Container verdrahtet. Ohne
gesetzte Referenz erfolgt der Zugriff anonym.

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

Die Zertifikatskette ist von der gematik zu beziehen. Für Testumgebungen enthält
das Helm Chart im Verzeichnis `templates/` ein vorgefertigtes Secret
`gematik-image-signer-test` mit den Testzertifikaten GEM.KOMP-CA61 und GEM.RCA7
(jeweils TEST-ONLY). Der Standardwert in `values-demo.yaml` verweist auf dieses
Test-Secret.

> **Wichtig:** Das Test-Secret `gematik-image-signer-test` enthält
> Testzertifikate und darf **nicht** in Produktivumgebungen verwendet werden.
> Für den Produktivbetrieb muss das Secret mit den von der gematik
> bereitgestellten
> Produktivzertifikaten befüllt werden.

---

## Notification Service

Der Notification Service ist eine Vorschau-Komponente und standardmäßig
deaktiviert. Bei Aktivierung deployt das Chart zwei Varianten desselben Images
(`-rs` für die Resource-Server-API, `-fdv` für die Client-API hinter dem PEP)
sowie im Standardmodus eine dedizierte CNPG-Datenbank.

Zwei Werte sind Pflicht — ohne sie startet der Dienst nicht:

```yaml
zeta-guard:
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

Die PDP-Konfiguration erfolgt über Terraform. Zu den wichtigsten Variablen
gehört:

| Variable                               | Standard                  | Beschreibung                                                                                                                                                        |
|----------------------------------------|---------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `use_kubernetes`                       | `true`                    | Terraform-Betriebsmodus (`true` = K8s-Backend, `false` = lokal)                                                                                                     |
| `keycloak_url`                         | —                         | Externe URL des Keycloak-Servers (bei Admin-API-Absicherung: URL des Admin-Hostnamens)                                                                              |
| `keycloak_namespace`                   | —                         | Kubernetes-Namespace des Authservers                                                                                                                                |
| `pdp_scopes`                           | `[]`                      | Zusätzliche PDP-Scopes                                                                                                                                              |
| `audience_scope_name`                  | `"zero:audience"`         | Name des Audience-Scopes — trägt die Pflicht-Claims des Access-Tokens (siehe Hinweis unter der Tabelle)                                                             |
| `audience`                             | `""`                      | Expliziter Audience-Wert im Access Token. Erforderlich, wenn `keycloak_url` auf einen Admin-Hostnamen zeigt (siehe unten).                                          |
| `insecure_tls`                         | `false`                   | Selbst signierte Zertifikate zulassen                                                                                                                               |
| `smtp_host`                            | `""`                      | SMTP-Server für den Realm (OTP-Versand der E-Mail-Bindung im mobilen Client-Flow). Leer lässt den `smtp_server`-Block des Realms komplett weg.                      |
| `smtp_port`                            | `"25"`                    | SMTP-Port                                                                                                                                                           |
| `smtp_from`                            | `""`                      | Absenderadresse der Realm-Mails — von Keycloak verlangt, sobald `smtp_host` gesetzt ist                                                                             |
| `notification_history_enabled`         | `false`                   | Legt den Keycloak-Scope `notification.history.read` an (A_29974). Manuell synchron zu `notificationService.historyEnabled` halten — nicht automatisch gekoppelt.    |
| `notification_service_resource_suffix` | `"/notification-service"` | Resource-Suffix des Notification Service für den Audience-Mapper der Notification-Scopes. Manuell synchron zu `notificationService.wellKnownResourceSuffix` halten. |

> **Hinweis zu SMTP in Testumgebungen:** Für Test- und Demo-Stages bringt das
> Helm-Repository ein `mailcatcher`-Subchart mit (SMTP-Port `1025`, Web-UI
> `1080`). `smtp_host` wird dann auf den mailcatcher-Service gezeigt, sodass
> OTP-Mails ohne echten Mailserver eingesehen werden können.

> **Hinweis zu `audience_scope_name`:** An diesem Scope hängen die Mapper, die
> die vom PEP
> geforderten Access-Token-Claims setzen (`aud`, `profession_oid`, `client_id`,
> `ip_address`,
> `product_id`, `product_version`, `common_name`, `organization_name`). Der
> Client muss den
> Scope anfragen. Verlangt ein Fachdienst einen bestimmten Scope-Namen — z. B.
> `vsdservice`
> für das VSDM (A_26744) —, setzen Sie `audience_scope_name` auf diesen Wert und
> führen ihn
> **nicht** zusätzlich in `pdp_scopes` (doppelter Scope-Name → Fehler beim
> Apply). Andernfalls
> fehlen dem Token die Claims und der PEP lehnt die Anfrage vor der
> Policy-Auswertung ab.

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
