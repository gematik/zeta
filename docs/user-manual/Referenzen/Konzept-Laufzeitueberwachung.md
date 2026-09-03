# Konzept: Laufzeitüberwachung für TI 2.0 Dienste mit ZETA Guard

## 1. Ziel und Abgrenzung

Dieses Konzept beschreibt, wie die **Integrität, Vertraulichkeit und Verfügbarkeit
der ZETA Guard Microservices zur Laufzeit** in einer Kubernetes-Infrastruktur
überwacht und durchgesetzt werden. Es ergänzt die Härtungsmaßnahmen des Deployments
um **Erkennung (Detection)** und **Reaktion (Response)** und ordnet jede Maßnahme
einer verantwortlichen Rolle zu.

Laufzeitüberwachung wird hier in vier Wirkstufen verstanden:

| Stufe | Frage | Beispiel |
| --- | --- | --- |
| **Prävention** | Was darf gar nicht erst starten? | Pod Security Standards, Admission Control |
| **Isolation** | Was darf mit wem sprechen? | NetworkPolicies, Service Mesh, RBAC |
| **Detektion** | Was passiert gerade wirklich? | Tetragon/Falco, K8s-Audit, Telemetrie |
| **Reaktion** | Was tun wir damit? | SIEM-Use-Cases, Alarmierung, Runbooks, Quarantäne |

Eine Maßnahme ohne Detektion ist unvollständig, und eine Detektion ohne definierte
Reaktion erzeugt lediglich Log-Volumen.

### 1.1 Scope

**Im Scope** (ZETA Guard Kernkomponenten, siehe
[Komponentenübersicht](Komponentenuebersicht.md)):

* PEP — HTTP Proxy (nginx)
* PDP — Authorization Server (Keycloak), Policy Engine (OPA), PDP Datenbank
  (PostgreSQL), PDP Cache (Infinispan)
* Telemetriedaten Service / Telemetry-Gateway (OpenTelemetry Collector)
* Notification Service (laut Spezifikation Kap. 3.2 eine **optionale** Komponente;
  im Chart erst ab Umsetzungsstufe 2 enthalten)
* Provisioning Processor (Init-Container von Authserver, PEP-Proxy, OPA und
  OPA-Simulation)
* Token-Renewer-CronJobs (`opa-token-renewer`, `gematik-oidc-token-renewer`) für
  die Workload Identity Federation gegenüber gematik-Diensten

**Im Scope als Hilfskomponenten** (austauschbar, siehe
[Prüfliste Optionale Komponenten](Pruefliste_Optionale_Komponenten.md)):
Ingress Controller, Service Mesh, Management Service (Argo CD), Local Artifact
Registry Cache, Egress Gateway.

**Außerhalb des ZETA Guard, aber im selben Cluster und damit im
Überwachungsscope des Betreibers:**

* **HSM Proxy** — wird vom **Hersteller des TI 2.0 Dienstes** bereitgestellt
* Resource Server und Application Authorization Backend des Fachdienstes

**Nicht im Scope:** ZETA Client / ZETA SDK (siehe
[Sicherheitsanforderungen Client-Hersteller](../SicherheitsanforderungenClientHersteller.md)),
Netzwerkinfrastruktur unterhalb des Clusters.

### 1.2 Verhältnis zu bestehenden Dokumenten

Dieses Konzept konsolidiert und erweitert:

* [Sicherheitsanforderungen an den Betreiber des ZETA-Guard](../SicherheitsanforderungenZETAGuardBetreiber.md)
  (OWASP Top 10 Kubernetes, A_28961)
* [Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md)
* [Wie Sie ein Observability-Backend anschließen](../Anleitungen/Wie_Sie_ein_Observability-Backend_an_ZETA-Guard_anschließen.md)
* [Referenz des Helm Charts](Referenz_des_Helm_Charts.md) (Security Contexts, ServiceAccounts, Cosign-Vertrauenskette)

## 2. Rollenmodell und Grundprinzip der Aufgabenteilung

| Kürzel | Rolle | Liefergegenstand |
| --- | --- | --- |
| **ZGH** | **ZETA Guard Hersteller** (gematik) | Helm Chart, Container-Images, OPA-Policies, Terraform-Templates, Telemetrie-Semantik, Referenz-Policies, Runbooks, Nachweisdokumente |
| **DH** | **TI 2.0 Dienst-Hersteller** | Resource Server, Application Authorization Backend, **HSM Proxy**, Integration in den ZETA Guard |
| **DA** | **TI 2.0 Dienst-Anbieter / Betreiber** | Kubernetes-Plattform, Betrieb, Konfiguration, SIEM/SOC, Incident Response, Zulassungsnachweise |

### 2.1 Trennlinie

Die Aufgabenteilung folgt einem einzigen Prinzip:

> **Der Hersteller liefert das Wissen darüber, was normal ist.
> Der Betreiber liefert die Plattform, die Abweichungen erkennt und darauf reagiert.**

Konkret bedeutet das:

* **Der ZGH kann und muss liefern**, was ohne Kenntnis des Anwendungsinnenlebens
  nicht erstellbar ist: konforme Manifeste, die **Kommunikationsmatrix**, die
  **Prozess- und Dateipfad-Baselines** je Container, die **Telemetrie-Semantik**
  (welches Event bedeutet was), signierte Artefakte und Referenz-Policies.
* **Der DA kann und muss liefern**, was ohne Kenntnis der Betriebsumgebung nicht
  erstellbar ist: Cluster-Härtung, Enforcement-Werkzeuge, IP-Adressen und
  Netzsegmente, SIEM-Anbindung, Alarmierungswege, Bereitschaft und Reaktion.
* **Der DH liefert dasselbe wie der ZGH — für seine eigenen Komponenten**,
  insbesondere für den **HSM Proxy** und den Resource Server. Andernfalls entsteht
  im selben Cluster eine nicht überwachte Zone neben einem hochgradig überwachten
  ZETA Guard.

Eine häufige Fehlannahme ist, Laufzeitüberwachung sei reine Betreiberaufgabe. Das
trifft für die *Werkzeuge* zu, nicht für die *Regeln*: Nur der Hersteller weiß, dass
im PEP-Container niemals eine Shell startet und dass `/etc/nginx` zur Laufzeit
niemals beschrieben wird. Ohne diese Baselines betreibt der DA ein Werkzeug ohne
Regelwerk und erzeugt entweder Blindheit oder Fehlalarme.

## 3. Schichtenmodell

```mermaid
flowchart TB
    subgraph L7["L7 — Detection & Response (DA, Content vom ZGH)"]
        SIEM["SIEM Use Cases · Alarmierung · Runbooks · Forensik"]
    end
    subgraph L6["L6 — Anwendungstelemetrie (ZGH liefert, DA betreibt)"]
        OTEL["Telemetry-Gateway (OTelCol) · Metriken · Logs · Traces"]
    end
    subgraph L5["L5 — Kernel / Syscall (DA betreibt, ZGH liefert Baselines)"]
        TET["Tetragon / Falco · Exec-Monitoring · FIM · Enforcement"]
    end
    subgraph L4["L4 — Service Mesh L7 (DA)"]
        MESH["mTLS · AuthorizationPolicy · Traffic-Observability"]
    end
    subgraph L3["L3 — Netzwerk L3/L4 (ZGH liefert Chart, DA konfiguriert)"]
        NP["Default-Deny NetworkPolicies · Ingress · Egress"]
    end
    subgraph L2["L2 — Workload-Härtung (ZGH liefert konform, DA erzwingt)"]
        PSS["Pod Security Standards restricted · SecurityContexts"]
    end
    subgraph L1["L1 — Admission & Supply Chain (geteilt)"]
        ADM["Kyverno / Gatekeeper · Image-Signaturprüfung · Ressourcenlimits"]
    end
    subgraph L0["L0 — Cluster & Node (DA)"]
        NODE["Node-Härtung · CIS Benchmark · API-Server-Audit · etcd-Encryption"]
    end
    L0 --> L1 --> L2 --> L3 --> L4 --> L5 --> L6 --> L7
```

Die Schichten sind **kumulativ, nicht alternativ**. Insbesondere ersetzt ein
Service Mesh keine NetworkPolicies (ein kompromittierter Sidecar-Bypass umgeht L4,
nicht L3), und Tetragon ersetzt keine Pod Security Standards (Detektion nach dem
Start ist teurer als Verhinderung des Starts).

## 4. Maßnahmen im Detail

### 4.1 Pod Security Standards (PSS)

**Ziel:** Erzwingen minimaler Workload-Privilegien auf Namespace-Ebene.

Für alle ZETA Guard Namespaces wird die Stufe **`restricted`** per Namespace-Label
durchgesetzt:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: zeta-guard
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/enforce-version: latest
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

Damit werden erzwungen: `runAsNonRoot: true`, `privileged: false`,
`allowPrivilegeEscalation: false`, `capabilities.drop: ["ALL"]`,
`seccompProfile.type: RuntimeDefault`, kein `hostNetwork`/`hostPID`/`hostIPC`,
keine `hostPath`-Volumes.

**Stand im ZETA Guard:** Das Helm Chart setzt diese Werte bereits als Defaults
(siehe [Security Contexts](Referenz_des_Helm_Charts.md#security-contexts)). Die
Aktivierung per Namespace-Label ist im
[KIND-Setup](../Anleitungen/Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md)
dokumentiert.

**Präzisierung zu `readOnlyRootFilesystem`:** Dieses Feld ist nicht Bestandteil
des PSS-Profils `restricted`, sondern eine darüber hinausgehende Härtung. Im ZETA
Guard ist es für Authserver und dessen Init-Container auf `true` gesetzt, für
Infinispan und den Provisioning Processor derzeit auf `false`. Es muss daher per
**Admission Policy** (Abschnitt 4.2) erzwungen und für die verbleibenden Workloads
gezielt nachgezogen werden — die pauschale Aussage „PSS erzwingt
`readOnlyRootFilesystem`" ist technisch unzutreffend.

**OpenShift:** Dort gilt statt PSS die `restricted-v2` Security Context Constraint.
`runAsUser` darf nicht gesetzt werden, siehe
[ZETA OpenShift-Kompatibilität](../Anleitungen/ZETA_OpenShift_Kompatibilität.md).

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Liefert `restricted`-konforme Manifeste und Defaults; hält `readOnlyRootFilesystem: true` als Zielzustand für alle Container; dokumentiert notwendige `emptyDir`-Schreibpfade |
| **DH** | Liefert HSM Proxy und Resource Server ebenfalls `restricted`-konform; begründet und dokumentiert jede Ausnahme (z. B. Device-Zugriff des HSM Proxy) |
| **DA** | Setzt Namespace-Labels; verweigert Ausnahmen ohne dokumentierte Begründung; prüft die Wirksamkeit periodisch |

### 4.2 Admission Control

**Ziel:** Nicht-konforme Ressourcen erreichen die Cluster-Datenbank gar nicht erst.

Als Policy-Engine wird **Kyverno** oder **OPA Gatekeeper** eingesetzt. Kyverno wird
empfohlen, weil es Image-Signaturverifikation (`verifyImages`) nativ beherrscht und
keine zweite Policy-Sprache neben Rego einführt — Rego bleibt im ZETA Guard für die
fachliche Autorisierung in der Policy Engine reserviert.

**Mindest-Policy-Set:**

| Policy | Wirkung | Priorität |
| --- | --- | --- |
| `verify-image-signatures` | Nur Images mit gültiger gematik-cosign-Signatur | MUSS |
| `require-resources` | `resources.requests` und `resources.limits` vorhanden | MUSS |
| `disallow-default-serviceaccount` | Kein Pod mit `default`-ServiceAccount | MUSS |
| `require-readonly-rootfs` | `readOnlyRootFilesystem: true` | MUSS |
| `disallow-latest-tag` / `require-digest` | Images per Digest referenziert, nicht per mutablem Tag | MUSS |
| `restrict-image-registries` | Nur Anbieter-Registry-Cache und gematik-Registry als Quelle | MUSS |
| `disable-automount-sa-token` | `automountServiceAccountToken: false`, außer bei Bedarf | SOLL |
| `require-probes` | Liveness-/Readiness-Probes vorhanden | SOLL |
| `require-pdb` | PodDisruptionBudget für HA-Komponenten | SOLL |
| `restrict-nodeport-loadbalancer` | Keine Umgehung des Ingress via NodePort | SOLL |

**Zur Image-Signaturprüfung:** Im ZETA Guard wird die cosign-Vertrauenskette der
gematik bereits als Secret (`imageTrustCertchainSecretRef`) bereitgestellt und vom
Provisioning Processor genutzt, um das **Provisioning-Daten-Image** beim Pod-Start
zu verifizieren. Dieselbe Vertrauenskette ist der Anker für die
Admission-Verifikation der **Komponenten-Images**. Wichtig ist der Hinweis in
[Wie Sie eine eigene OCI Registry verwenden](../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md):
beim Spiegeln in den Registry-Cache muss `cosign save`/`load` verwendet werden,
sonst gehen die `.sig`-Artefakte verloren und die Admission-Policy blockiert das
gesamte Deployment.

**Rollout-Reihenfolge (verbindlich):** Jede neue Policy durchläuft
`Audit` → `Warn` → `Enforce`. Eine Policy direkt im Enforce-Modus einzuführen ist
der häufigste Weg, einen produktiven Dienst durch eine Sicherheitsmaßnahme
auszufallen zu lassen.

**Verfügbarkeitsrisiko:** Ein Validating Webhook mit `failurePolicy: Fail` macht die
Policy-Engine zur Verfügbarkeitsabhängigkeit des gesamten Clusters. Die Engine
selbst MUSS daher hochverfügbar betrieben werden, und ihr eigener Namespace MUSS
über `namespaceSelector` von der Prüfung ausgenommen sein.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Liefert Referenz-Policies als YAML im Repository; liefert signierte Images inkl. SBOM; stellt Trust-Anchor und Signatur-Identität bereit; dokumentiert, welche Policies mit dem Chart kompatibel sind |
| **DH** | Signiert eigene Images (HSM Proxy, Resource Server) mit nachweisbarer Identität; passt Policies auf eigene Registry an |
| **DA** | Betreibt die Policy-Engine HA; führt Policies nach Audit→Warn→Enforce ein; überwacht Admission-Denials als Sicherheitsereignis; verantwortet die Ausnahmeverwaltung |

### 4.3 Kommunikationsmatrix und Network Policies (L3/L4)

**Ziel:** Default-Deny in jedem Namespace, explizite Freigabe nur für
nachgewiesene Kommunikationsbeziehungen. Grundlage dafür ist eine normative
Kommunikationsmatrix — ohne sie entstehen entweder zu weite Policies
(wirkungslos) oder zu enge (Ausfall).

#### 4.3.1 Normative Kommunikationsmatrix

Die folgende Matrix ist aus der ZETA-Architekturübersicht abgeleitet. Die Spalte
**Nr.** verweist auf die Kantennummerierung der Abbildung; die Matrix ist damit
zugleich deren Legende.

![ZETA Guard Architekturübersicht](../../../images/Abb-ZETA-Architektur.svg)

Lesart der Matrix:

* **Quelle** ist immer der **Initiator des Verbindungsaufbaus**, nicht die Richtung
  des Datenflusses. Für NetworkPolicies und `AuthorizationPolicy` ist ausschließlich
  der Verbindungsaufbau maßgeblich.
* **Ports** sind die Zielports der Zielkomponente in der Chart-Standardkonfiguration.
  Weichen Werte in der Betriebsumgebung ab, sind sie beim Ableiten der Policies
  anzupassen. Der DA MUSS die Ports gegen das ausgerollte Chart verifizieren.
* **n. i. B.** = notwendige Beziehung, die in der Abbildung nicht dargestellt ist
  (siehe Hinweis am Ende des Abschnitts).
* **o. Nr.** = in der Abbildung dargestellt, aber unnummeriert.
* Jede Zeile ist eine **Freigabe**. Was nicht in der Matrix steht, DARF NICHT
  möglich sein — das ist der Prüfgegenstand des Negativtests (Abschnitt 4.3.3).

##### A — Eingehend von außen (über Gateway / Ingress Controller)

Alle Zeilen dieser Gruppe MÜSSEN über den Ingress Controller bzw. das Gateway
laufen. Ein direkter Zugriff von außen auf einen Pod des ZETA Guard unter Umgehung
des Gateways DARF NICHT möglich sein.

| Nr. | Quelle | Ziel | Protokoll / Port | Zweck |
| --- | --- | --- | --- | --- |
| (5) | Clientsystem (Fach-Client) | PEP HTTP Proxy | HTTPS 443 → 8081 (8443 bei TLS-Terminierung im PEP) | Abruf des Well-known-Dokuments zur Ermittlung der Resource-Server-URL bei Mandantentrennung (Spezifikation Kap. 3.3) |
| (6) | ZETA Client (SDK) | PEP HTTP Proxy | HTTPS 443 → 8081 (8443) | Service Discovery: `GET /.well-known/oauth-protected-resource` (RFC 9728) |
| (16) | ZETA Client (SDK) | PEP HTTP Proxy | HTTPS 443 → 8081 (8443) | Ressourcenanfrage mit DPoP-gebundenem Access Token |
| (7) | ZETA Client (SDK) | Authorization Server, **über den PEP HTTP Proxy** (`/auth/*`-Weiterleitung) oder je nach Chart-Konfiguration direkt über den Ingress-Pfad `/auth` | HTTPS 443 → 8080 (8443 bei TLS im Pod) | OAuth 2.0: Discovery, DCR, Nonce, PAR, Token Exchange, JWKS |
| o. Nr. | Operator / CI-Runner | Authorization Server, Admin-Ingress (`authserver.adminHostname`) | HTTPS 443 → 8080 (8443) | Keycloak Admin REST API und Admin Console; auf dem öffentlichen Hostnamen blockiert der PEP `/auth/admin` (siehe [Admin-API-Absicherung](Referenz_des_Helm_Charts.md#admin-api-absicherung)) |
| (23) | ZETA Client (SDK) | Notification Service | HTTPS 443, Port im Chart noch nicht festgelegt | Registrierung von Push-Konfigurationen und Abruf von Benachrichtigungen |

> **Port 8080 des PEP ist nicht der Datenport.** Der PEP lauscht für Client-Verkehr
> auf 8081 (Service-Port 80) und bei TLS-Terminierung im Pod auf 8443. Port 8080
> liefert ausschließlich `stub_status` für den Metrik-Exporter. Eine
> Ingress-Freigabe auf 8080 gibt den Status-Endpunkt frei und blockiert den
> Datenverkehr.

##### B — Innerhalb des Clusters (Ost-West)

| Nr. | Quelle | Ziel | Protokoll / Port | Zweck |
| --- | --- | --- | --- | --- |
| (17) | PEP HTTP Proxy | Resource Server | HTTPS, Port fachdienstspezifisch | Weiterleitung der autorisierten Anfrage (`proxy_pass`) |
| n. i. B. | PEP HTTP Proxy | Authorization Server | HTTP 8080 (HTTPS 8443) | Abruf von OpenID-Konfiguration und JWKS zur Token-Prüfung (`pep_issuer`, siehe [PEP-Konfiguration](Konfiguration_des_PEP_Http_Proxy.md)); Weiterleitung von `/auth/*` für (7) |
| (4) | PEP HTTP Proxy | HSM Proxy | gRPC 50051 | Schlüsseloperationen: Pod-TLS-Schlüssel (PrK.PEP.TLS) und Beglaubigung des ASL-Schlüssels mit PrK.PEP.Sig |
| o. Nr. | Authorization Server (inkl. Init-Container `keychain-generator`) | HSM Proxy | gRPC 50051 | Token-Signatur (`HSM_PROXY_TOKEN_KEY_ID`) und Pod-TLS-Schlüssel |
| n. i. B. | PDP Cache (Infinispan) | HSM Proxy | gRPC 50051 | TLS-Schlüsselmaterial für Client-Endpunkt und JGroups-mTLS (`global.infinispanExternal.hsm`) |
| (13) | Authorization Server | Policy Engine (OPA) und OPA-Simulation | HTTP 8181 | Policy-Auswertung bei Tokenausstellung (`POST /v1/data/policies/zeta/authz/decision`); OPA-Simulation für Shadow-Auswertung neuer Bundles |
| (15) | Authorization Server | PDP Datenbank (PostgreSQL) | TCP 5432 | Persistenz von Realm-, Client- und Sitzungsdaten |
| n. i. B. | PDP Datenbank (PostgreSQL-Instanzen), CloudNativePG-Operator (`cnpg-system`) | PDP Datenbank | TCP 5432, 8000 | Streaming-Replikation zwischen den PostgreSQL-Instanzen; Instance-Manager-API des Operators |
| (14) | Authorization Server | Authorization Backend | HTTPS, Port dienstspezifisch | Abruf fachlicher Autorisierungsattribute |
| (24) | Resource Server | Notification Service | HTTPS, mTLS mit technischem Nutzer (A_29980) | Channel-Abfrage und Übergabe von Notification-Events |
| n. i. B. **(geplant)** | Resource Server | Authorization Server, dedizierter mTLS-Endpunkt (`GET /zeta/email`) | HTTPS mit Client-Zertifikat (mTLS) | Abfrage der bei der TOFU-Registrierung hinterlegten E-Mail-Adresse des Nutzers. **Architekturvorschlag**, weder in der Spezifikation noch im Chart enthalten; wird hier geführt, damit die Policies bei Einführung nicht nachgezogen werden müssen |
| (18) | Resource Server | Telemetriedaten Service | OTLP/gRPC 4317 | Traces und Selbstauskunft des Fachdienstes (A_27494-02); weitere OTLP-Receiver nur, wenn im Collector konfiguriert |
| (20) | Telemetriedaten Service | Monitoring (Anbieter) | OTLP | Betriebliche, bereinigte Metriken, Logs, Traces an das Anbieter-Backend (A_27260) |
| n. i. B. | Monitoring (Anbieter, Prometheus) | Authorization Server 9000 (`/metrics`), PEP 9113 (`/metrics`), OPA 8181 (`/metrics`), Telemetriedaten Service 8888/8889 | HTTP | Pull-Scraping der Metrik-Endpunkte. **Nur zulässig, wenn der DA diesen Weg wählt**; Alternative ist Scraping durch den Prometheus-Receiver des Telemetriedaten Service mit Export über (20), dann entfällt diese Zeile |
| (27) | SIEM / Monitoring (Anbieter) | Authorization Server, Admin-Ingress | HTTPS 443 → 8080 (8443) | Auslösen der Session-Termination über die Plug-in-Schnittstelle des Authorization Servers (A_29854 ff.); Endpunkt gegen das Chart prüfen |
| (19) | SIEM (Anbieter) | Telemetriedaten Service | OTLP/gRPC, eigener Port, mTLS | Einspeisung ausgewählter, im Anbieter-SIEM erkannter Sicherheitsereignisse zur Weiterleitung an das TI SIEM (22) — siehe Hinweis 1 |
| n. i. B. | Telemetriedaten Service | SIEM (Anbieter) | OTLP/gRPC 4317, mTLS | Ausleitung **betrieblicher, bereinigter** Telemetrie an das SIEM des Anbieters (A_27260). Sicherheitsrelevante Telemetrie nach A_28783, A_28793, A_28795 und A_28867 DARF NICHT an den Betreiber gehen (A_28960-01), siehe Abschnitt 6 |
| n. i. B. | PEP, Authorization Server, OPA, OPA-Simulation, Notification Service | Telemetriedaten Service | OTLP/gRPC 4317; PEP zusätzlich **Syslog UDP 54526** (nginx Access- und Error-Logs) | Telemetrie der Kernkomponenten; das Gateway ist laut Abschnitt 6 der **einzige** Ausleitungspunkt |
| n. i. B. | Authorization Server | PDP Cache (Infinispan) | TCP 11222 (Hot Rod / REST) | Verteilter Sitzungscache des Authorization Servers; Infinispan ist ein eigener Workload (`infinispan-external`) |
| n. i. B. | PDP Cache (Infinispan) | PDP Cache (Infinispan) | TCP 7800 | JGroups-Cluster-Transport zwischen Infinispan-Replikaten |
| n. i. B. | Authorization Server | Authorization Server | TCP 7800, 57800 | JGroups-Cluster-Transport zwischen Keycloak-Replikaten (Ports sind auf keinem Service deklariert) |
| n. i. B. (Spezifikation: Kante (28)) | Provisioning Processor (Init-Container von Authserver, PEP-Proxy, OPA, OPA-Simulation) | Local Artifact Registry Cache | HTTPS 443 | Abruf des signierten Provisioning-Images bei jedem Pod-Start; gemäß A_29743 zusätzlich zyklische Prüfung auf neue Versionen zur Laufzeit (Hot-Reload), sobald umgesetzt |
| n. i. B. | Token-Renewer-CronJobs; PDP-Datenbank-Pods (CNPG Instance Manager) | Kubernetes API-Server | HTTPS 443 / 6443 | CronJobs schreiben die per Workload Identity Federation bezogenen Access Tokens als Secret; Instance Manager der CNPG-Pods |
| n. i. B. | alle Pods | `kube-dns` / CoreDNS | UDP 53, TCP 53 | Namensauflösung |

##### C — Ausgehend aus dem Cluster (Egress)

Die Spalte **Egress-Kategorie** verweist auf die Konfigurationsschlüssel des Helm
Charts, siehe
[Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md).

| Nr. | Quelle | Ziel | Protokoll / Port | Zweck | Egress-Kategorie |
| --- | --- | --- | --- | --- | --- |
| (1) | Authorization Server | Federation Master (gematik) | HTTPS 443 | Entity Statements, Validierung der Trust Chain der OIDC-Föderation | *(fehlt, siehe Abschnitt 4.3.3)* |
| (11) | Authorization Server | Sektoraler IDP | HTTPS 443 | OIDC: Entity Statement, PAR, Token-Endpunkt, JWKS | *(fehlt, siehe Abschnitt 4.3.3)* |
| (8) | Authorization Server | Mail Relay (Zustellung an den E-Mail Client des Nutzers) | SMTPS 465 bzw. STARTTLS 587 | Versand des TOFU-OTP | *(fehlt, siehe Abschnitt 4.3.3)* |
| (2) | Local Artifact Registry Cache | ZETA Artifact Registry (gematik) | HTTPS 443 | OCI-Images, OPA-Bundles, cosign-Signaturartefakte | — (Hilfskomponente außerhalb des Charts; `artifactRegistry` gilt für die ZETA-Pods selbst, siehe nächste Zeile) |
| (3) | Policy Engine (OPA), OPA-Simulation, Authserver, PEP | ZETA Artifact Registry / PIP (gematik) bzw. Anbieter-Spiegel | HTTPS 443 | Abruf signierter OPA-Policy-Bundles und Provisioning-Images direkt durch die Pods (Spezifikation Kap. 3.3: „direkt aus der ZETA Artifact Registry“) | `pip`, `artifactRegistry`, `providerArtifactRegistry` |
| (21) | Telemetriedaten Service | Telemetriedaten-Empfänger (gematik) | OTLP/gRPC 443 | Telemetrieausleitung an die gematik | `telemetry` |
| (22) | Telemetriedaten Service | TI SIEM (gematik) | OTLP/gRPC 443 | Sicherheitsereignisse des ZETA Guard **und** die über (19) eingespeisten Ereignisse des Anbieter-SIEM | `siem` |
| (25) | Notification Service | Push Gateway (gemF_PushNotification), von dort APNs / FCM | HTTPS 443, mTLS mit EV-Zertifikat (A_29982) | Push-Benachrichtigung; die Kante zum Clientsystem Notification Service in der Abbildung fasst Push Gateway und Plattform-Push-Infrastruktur zusammen | *(fehlt, siehe Abschnitt 4.3.3)* |
| o. Nr. | HSM Proxy | HSM | herstellerspezifisch (PKCS#11 über TCP) | Schlüsseloperationen; Freigabe verantwortet der **DH** | — |
| n. i. B. | Token-Renewer-CronJobs (`opa-token-renewer`, `gematik-oidc-token-renewer`) | GCP STS / IAM Credentials API (Workload Identity Federation) | HTTPS 443 | Tausch des Kubernetes-ServiceAccount-JWT gegen Access Tokens für Artifact Registry und Telemetriedaten-Empfänger | *(fehlt, siehe Abschnitt 4.3.3)* |
| n. i. B. | PEP HTTP Proxy | PoPP-Dienst | HTTPS 443 | Proof of Patient Presence, Abruf des PoPP-JWKS | `popp` |
| n. i. B. | PEP HTTP Proxy | JWKS weiterer Authorization Server der Föderation | HTTPS 443 | Prüfung von Access Tokens fremder, im Entity Statement des Federation Master geführter Authorization Server (A_25668-01); nur bei entsprechender PEP-Konfiguration | *(fehlt, siehe Abschnitt 4.3.3)* |
| n. i. B. | Authorization Server | OCSP-Responder **aller zugelassenen SMC-B-TSP** | HTTP 80, HTTPS 443 | Statusprüfung des SMC-B-Zertifikats bei der Validierung der SMC-B-Signatur | `ocspSmcbTsp` |
| n. i. B. | PEP HTTP Proxy | OCSP-Responder | HTTP 80, HTTPS 443 | OCSP Stapling Zertifikatsstatusprüfung für eigenes TLS-Zertifikat und TI-Komponenten-PKI | eine CA aus `ocspCabForum`, `ocspTiPki` |
| n. i. B. | PEP HTTP Proxy | Anbieter-interne Resource Server | HTTPS | Fachdienst außerhalb des Clusters | `providerInternal.resourceServers` |
| n. i. B. | Telemetriedaten Service | Anbieter-internes Telemetriesystem | OTLP | Observability-Backend des Anbieters | `providerInternal.telemetrySystems` |
| n. i. B. | alle Kernkomponenten (Init-Container) | Anbieter-interne Artifact Registry | HTTPS 443 | gespiegelte Images und Bundles | `providerArtifactRegistry` |

> **SMC-B wird von mehreren TSP ausgegeben.** Der Authorization Server prüft bei
> der Validierung der SMC-B-Signatur den Status des Karten-Zertifikats per OCSP.
> Maßgeblich ist die OCSP-URL aus der AIA-Extension des jeweils vorgelegten
> Zertifikats — und die unterscheidet sich je ausgebendem TSP. `ocspSmcbTsp.ipBlocks`
> MUSS daher die Responder **aller** TSP enthalten, deren SMC-B der Dienst
> akzeptiert; eine einzelne `/32`-Adresse genügt nicht. Ein fehlender TSP
> äußert sich nicht als Netzwerkfehler, sondern als Autorisierungsablehnung für
> genau die Leistungserbringer dieses einen TSP — ein Fehlerbild, das im Betrieb
> schwer zu diagnostizieren ist. Die Liste der TSP ist bei jeder Änderung des
> TSP-Bestands nachzuziehen; Erreichbarkeit und Antwortverhalten jedes Responders
> sind zu überwachen (Abschnitt 5.4).

##### D — Clientseitig, außerhalb des Betreiber-Scopes (informativ)

Diese Beziehungen sind für die Vollständigkeit der Abbildung aufgeführt. Sie sind
**nicht** durch NetworkPolicies des Betreibers durchsetzbar; die Anforderungen
stehen in den
[Sicherheitsanforderungen Client-Hersteller](../SicherheitsanforderungenClientHersteller.md).

| Nr. | Quelle | Ziel | Zweck |
| --- | --- | --- | --- |
| o. Nr. | Nutzer | Clientsystem | Bedienung der Fachanwendung |
| (10) | Clientsystem | SM(C)-B | Karten- und Signaturoperationen über Kartenterminal, Konnektor oder TI-Gateway |
| (12) | Clientsystem | Sektoraler IDP | Authentisierung des Nutzers |
| (9) | E-Mail Client | Nutzer | Anzeige des TOFU-OTP |
| (26) | Clientsystem Notification Service | Clientsystem | Zustellung der Benachrichtigung |

##### E — Explizit unzulässige Beziehungen (Negativliste)

Diese Liste ist das Gegenstück zur Freigabeliste und der Prüfgegenstand des
Wirksamkeitsnachweises. Jede Zeile MUSS im Negativtest nachweislich scheitern.

| # | Unzulässige Beziehung | Begründung |
| --- | --- | --- |
| N1 | Beliebiger Pod oder externer Aufrufer → Authorization Server, außer PEP HTTP Proxy und Ingress Controller (7), Admin-Ingress (o. Nr.) und (27) | Umgehung von Rate Limiting, TLS-Terminierung, Gateway-Kontrollen und der `/auth/admin`-Sperre des PEP |
| N2 | Beliebiger Pod → Policy Engine (OPA) oder OPA-Simulation, außer Authorization Server (13) und, falls in der Matrix freigegeben, Monitoring-Scraping auf `/metrics` | OPA ist nicht authentifiziert; direkter Zugriff erlaubt beliebige Policy-Auswertung und -Auskunft |
| N3 | Beliebiger Pod → PDP Datenbank oder PDP Cache, außer Authorization Server (15, 11222), Replikation und Operator (CNPG) sowie Cluster-Transport der jeweiligen Replikate | Direkter Zugriff auf Sitzungs- und Realm-Daten |
| N4 | Beliebiger Pod → Resource Server, außer PEP HTTP Proxy (17) | **Umgehung des Policy Enforcement Point** — die sicherheitsrelevanteste Beziehung der gesamten Matrix |
| N5 | Beliebiger Pod → HSM Proxy, außer PEP HTTP Proxy (4), Authorization Server inkl. `keychain-generator` (o. Nr.), PDP Cache (Infinispan) und in der VAU-Variante Notification Service (Spezifikation Kap. 5.12, Schritt (H)) | Unkontrollierte Nutzung von Schlüsselmaterial |
| N6 | Resource Server oder Authorization Backend → PEP, Authorization Server, OPA, PDP Datenbank | Es gibt keine Rückrichtung aus dem Fachdienst in den ZETA Guard außer (24), (18) und, sobald umgesetzt, dem dedizierten mTLS-Endpunkt für die TOFU-E-Mail-Abfrage. Insbesondere DÜRFEN die übrigen Endpunkte des Authorization Servers vom Resource Server NICHT erreichbar sein |
| N7 | Kernkomponenten → SIEM, Monitoring oder Telemetriedaten-Empfänger unter Umgehung des Telemetriedaten Service (Push-Export) | Abschnitt 6: das Gateway ist der einzige Ausleitungspunkt für Telemetrie. Pull-Scraping der Metrik-Endpunkte durch das Anbieter-Monitoring ist davon getrennt zu entscheiden und nur zulässig, wenn es in Gruppe B freigegeben ist |
| N8 | Egress aus dem ZETA-Guard-Namespace zu einem Ziel außerhalb der Kategorien der Gruppe C | Exfiltrationspfad; erzeugt Use-Case 3 aus Abschnitt 7 |
| N9 | Zugriff auf die Kubernetes-API aus einem Kernkomponenten-Pod, außer Token-Renewer-CronJobs (Secret-Schreibzugriff) und CNPG-Datenbank-Pods (Instance Manager) | Kein anderer Kernkomponenten-Pod benötigt API-Zugriff, siehe Abschnitt 4.7. Die Ausnahmen sind per RBAC auf die jeweiligen Secrets bzw. Ressourcen zu begrenzen |
| N10 | Beliebiger Pod oder externes System → Annahme-Endpunkt des Telemetriedaten Service für eingespeiste Sicherheitsereignisse, außer dem SIEM des Anbieters (19) | Der Endpunkt leitet nach außen an das TI SIEM weiter; wer ihn erreicht, kann Ereignisse in gematik-Systeme einschleusen |
| N11 | Sicherheitsrelevante Telemetriedaten (A_28783, A_28793, A_28795, A_28867) → SIEM oder Monitoring des Anbieters | Inhaltliche, keine Netzwerkbeziehung: A_28960-01 verbietet die Weitergabe an den Betreiber; durchzusetzen in der Pipeline des Telemetriedaten Service (Abschnitt 6) |

##### Hinweise zur Ableitung aus der Abbildung

Zwei Punkte verdienen beim Lesen der Matrix besondere Beachtung:

1. **Kante (19) ist ein Weiterleitungspfad, kein Telemetrieexport.** Der Anbieter
   speist ausgewählte, in seinem eigenen SIEM erkannte Sicherheitsereignisse in
   den Telemetriedaten Service ein; von dort werden sie über den ohnehin
   bestehenden, mTLS-authentisierten Pfad (22) an das TI SIEM weitergegeben. Die
   Spezifikation beschreibt (19) nur als „empfängt vom SIEM des Anbieters
   Security Events“ (Kap. 3.3) und die Weiterleitung an das gematik-SIEM
   (Kap. 5.13); der Zweck, dem Anbieter-SIEM eine eigene Authentisierung und
   Autorisierung am zentralen SIEM zu ersparen, ist eine Interpretation dieses
   Konzepts. Der Telemetriedaten Service ist damit **nicht nur
   Ausleitungspunkt, sondern auch Annahmestelle** — die einzige Beziehung der
   Matrix, in der ein anbietereigenes System Daten in den ZETA Guard einliefert.
   Daraus folgen drei Festlegungen: der Annahme-Endpunkt MUSS auf einem eigenen
   Port liegen und mTLS mit Client-Zertifikat erzwingen; er DARF ausschließlich
   vom SIEM des Anbieters erreichbar sein (N10); und eingespeiste Ereignisse
   MÜSSEN als anbieterseitig erzeugt gekennzeichnet bleiben, damit sie im TI SIEM
   nicht als Ereignisse des ZETA Guard erscheinen.
   Da der Weiterleitungspfad über eine überwachte Komponente führt, ist er kein
   Ersatz für den direkten Weg des Anbieters in sein eigenes SOC (Abschnitt 6):
   die Erkennung bleibt anbieterseitig und unabhängig vom Gateway, nur die
   Meldung an die gematik nutzt diesen Pfad.
2. **In der Abbildung fehlende Beziehungen.** PEP → Authorization Server
   (JWKS-Abruf und `/auth`-Weiterleitung), PDP Cache (Infinispan), der
   JGroups-Cluster-Transport von Keycloak und Infinispan, Replikation und Operator
   der PDP Datenbank, DNS, der Telemetriepfad der Kernkomponenten inklusive
   Syslog/UDP des PEP, die OCSP-, PIP- und PoPP-Aufrufe, die Token-Renewer-CronJobs
   sowie der Provisioning Processor sind betrieblich notwendig, in der Übersicht
   aber nicht dargestellt. Sie sind oben als `n. i. B.` geführt. Die Spezifikation
   beschreibt den Bezug von Images und Provisioning-Daten als Kante (28), die im
   Bild dieses Repositories fehlt. Eine Kommunikationsmatrix, die nur die
   gezeichneten Kanten enthält, führt zu einem nicht startfähigen Deployment.
3. **Widerspruch in der Spezifikation.** Kap. 5.6.5.1.3 fordert eine
   „vollständige Isolation zwischen ZETA Guard Namespace und
   Resource-Server-Namespace auf Netzwerkebene“. Das ist mit (17) unvereinbar
   und als „Isolation bis auf die in der Matrix freigegebenen Beziehungen“ zu
   lesen. Ebenso nennt Kap. 5.6.5.1.1 `readOnlyRootFilesystem` als Bestandteil
   des PSS-Profils `restricted`, was technisch nicht zutrifft (Abschnitt 4.1).

#### 4.3.2 Ableitung der NetworkPolicies

Aus der Matrix folgen die Manifeste mechanisch: jede Zeile der Gruppen A bis C wird
zu **zwei** Regeln — einer `egress`-Regel beim Initiator und einer `ingress`-Regel
beim Ziel. Bei Default-Deny in beide Richtungen genügt eine Seite nicht.

Die Beispiele verwenden den Namespace `zeta-guard` für die ZETA Guard Services und
den Namespace `fachdienst` für Resource Server, Authorization Backend und HSM Proxy.
Die Workload-Labels folgen dem Chart: `app.kubernetes.io/name: <workload>` für
`pep-proxy`, `authserver`, `opa`, `opa-simulation`; der Telemetry-Gateway trägt
`app.kubernetes.io/name: opentelemetry-collector`, Infinispan `app: infinispan`,
die CloudNativePG-Instanzen `cnpg.io/cluster: <cluster>`. Der mitgelieferte
F5 NGINX Ingress Controller ist ein Subchart im Release-Namespace mit
`app.kubernetes.io/name: nginx-ingress`; die Beispiele nehmen an, dass er dort
läuft. Namespace-Namen, Labels und Ports sind gegen das ausgerollte Chart zu
verifizieren (`kubectl get pods --show-labels`).

##### Baustein 1 — Default-Deny in beide Richtungen und DNS

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
  namespace: zeta-guard
spec:
  podSelector: {}
  policyTypes: [Ingress, Egress]
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-dns-egress            # Matrix B, "alle Pods -> CoreDNS"
  namespace: zeta-guard
spec:
  podSelector: {}
  policyTypes: [Egress]
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
          podSelector:
            matchLabels:
              k8s-app: kube-dns
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

##### Baustein 2 — PEP HTTP Proxy (Matrix A5, A6, A16, A7 · B17, B4, B-JWKS · N4)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pep-proxy
  namespace: zeta-guard
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: pep-proxy
  policyTypes: [Ingress, Egress]
  ingress:
    # (5) (6) (16) (7) - ausschliesslich ueber den Ingress Controller, nicht per CIDR.
    # 8081 ist der Datenport (Service-Port 80), 8443 nur bei TLS-Terminierung im PEP.
    # 8080 (stub_status) und 9113 (Metrik-Exporter) bleiben dem Ingress verschlossen.
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: nginx-ingress
      ports:
        - protocol: TCP
          port: 8081
        - protocol: TCP
          port: 8443
  egress:
    # (17) einziger erlaubter Pfad in den Fachdienst-Namespace
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: resource-server
      ports:
        - protocol: TCP
          port: 8443
    # (n. i. B.) Authorization Server: OpenID-Konfiguration, JWKS, /auth-Weiterleitung (7)
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: authserver
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 8443
    # (4) HSM Proxy
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: hsm-proxy
      ports:
        - protocol: TCP
          port: 50051
    # Telemetrie (n. i. B.) - Abschnitt 6: einziger Ausleitungspunkt.
    # OTLP/gRPC plus Syslog/UDP fuer die nginx Access- und Error-Logs.
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: opentelemetry-collector
      ports:
        - protocol: TCP
          port: 4317
        - protocol: UDP
          port: 54526
    # Egress-Kategorien popp, ocsp*, providerInternal.resourceServers,
    # artifactRegistry, providerArtifactRegistry: ipBlocks aus den Chart-Values
```

> **Syslog/UDP nicht vergessen.** Der PEP sendet seine nginx-Logs per Syslog über
> UDP 54526 an den Collector. Eine Egress-Regel, die nur OTLP/TCP freigibt,
> unterdrückt die Access- und Error-Logs des PEP ohne sichtbaren Fehler — und
> nimmt damit Use-Case 12 aus Abschnitt 7 die Datenquelle. Ein Service Mesh
> deckt UDP nicht ab; diese Regel bleibt auch mit Mesh eine NetworkPolicy.

##### Baustein 3 — Authorization Server (Matrix A7, A-Admin · B13, B15, B14, B27, B-TOFU-Abfrage, B-o.Nr., B-Cluster-Transport · C1, C11, C8)

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: authserver
  namespace: zeta-guard
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: authserver
  policyTypes: [Ingress, Egress]
  ingress:
    # (7) ueber den PEP (/auth-Weiterleitung) und, je nach Chart-Konfiguration,
    # direkt vom Ingress Controller (/auth-Pfad, Admin-Ingress).
    # 8080 ist der Standardport, 8443 nur bei TLS im Pod.
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: pep-proxy
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: nginx-ingress
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 8443
    # JGroups-Cluster-Transport zwischen den Authserver-Replikaten
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: authserver
      ports:
        - protocol: TCP
          port: 7800
        - protocol: TCP
          port: 57800
    # (27) Session-Termination durch das Anbieter-SIEM. Der Endpunkt liegt auf der
    # Plug-in-Schnittstelle des Authorization Servers; ob er ueber den Admin-Ingress
    # oder direkt erreicht wird, ist gegen das Chart zu pruefen.
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: siem
      ports:
        - protocol: TCP
          port: 8080
        - protocol: TCP
          port: 8443
    # GEPLANT: TOFU-E-Mail-Abfrage durch den Resource Server - eigener mTLS-Endpunkt
    # auf eigenem Port. Erst aktivieren, wenn der Endpunkt im Chart existiert;
    # der Port 8444 ist ein Platzhalter.
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: resource-server
      ports:
        - protocol: TCP
          port: 8444
  egress:
    # (13) Policy Engine und OPA-Simulation
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: opa
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: opa-simulation
      ports:
        - protocol: TCP
          port: 8181
    # (15) PDP Datenbank
    - to:
        - podSelector:
            matchLabels:
              cnpg.io/cluster: keycloak-db
      ports:
        - protocol: TCP
          port: 5432
    # PDP Cache (n. i. B.) - Infinispan ist ein eigener Workload
    - to:
        - podSelector:
            matchLabels:
              app: infinispan
      ports:
        - protocol: TCP
          port: 11222
    # JGroups-Cluster-Transport zu den anderen Authserver-Replikaten
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: authserver
      ports:
        - protocol: TCP
          port: 7800
        - protocol: TCP
          port: 57800
    # (14) Authorization Backend, (o. Nr.) HSM Proxy
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: authorization-backend
      ports:
        - protocol: TCP
          port: 8443
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: hsm-proxy
      ports:
        - protocol: TCP
          port: 50051
    - to:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: opentelemetry-collector
      ports:
        - protocol: TCP
          port: 4317
    # (1) Federation Master, (11) Sektoraler IDP, (8) Mail Relay sowie
    # ocspSmcbTsp (Responder ALLER zugelassenen SMC-B-TSP, siehe Hinweis in
    # Abschnitt 4.3.1), artifactRegistry, providerArtifactRegistry: ipBlocks
```

> **Der TOFU-E-Mail-Endpunkt ist ein Architekturvorschlag**, kein Bestandteil
> der Spezifikation oder des Charts. Sobald er umgesetzt ist, wäre er die
> einzige Stelle, an der ein Fachdienst personenbezogene Registrierungsdaten aus
> dem PDP abruft. Er MUSS deshalb auf einem eigenen Port liegen, mTLS mit
> Client-Zertifikat erzwingen und darf ausschließlich vom Resource Server
> erreichbar sein — die NetworkPolicy ist hier die zweite Verteidigungslinie
> hinter der Zertifikatsprüfung, nicht deren Ersatz. Die Abfrage ist als
> fachliches Ereignis zu protokollieren und in Abschnitt 7 als Use-Case zu
> führen: ein Anstieg der Abfragerate ist ein Auskundschaftungssignal.
>
> **Infinispan-Pods** brauchen zusätzlich eine eigene Policy: Ingress 11222 vom
> Authserver, Ingress und Egress 7800 untereinander, Egress 50051 zum HSM Proxy
> bei aktivierter HSM-Anbindung.

##### Baustein 4 — Ziele ohne eigenen Ingress von außen (Matrix N2, N3)

Policy Engine und PDP Datenbank sind die Komponenten, bei denen eine fehlende
Ingress-Regel am teuersten ist: Beide sind nicht eigenständig authentifiziert.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: opa
  namespace: zeta-guard
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: opa      # analog fuer app.kubernetes.io/name: opa-simulation
  policyTypes: [Ingress]
  ingress:
    # (13) - ausschliesslich der Authorization Server, sonst niemand.
    # Metrik-Scraping auf /metrics nur ergaenzen, wenn die Matrix (Gruppe B)
    # diesen Weg freigibt; Pfade kann erst das Service Mesh einschraenken.
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: authserver
      ports:
        - protocol: TCP
          port: 8181
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: pdp-datenbank
  namespace: zeta-guard
spec:
  podSelector:
    matchLabels:
      cnpg.io/cluster: keycloak-db
  policyTypes: [Ingress, Egress]
  ingress:
    # (15)
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: authserver
      ports:
        - protocol: TCP
          port: 5432
    # Streaming-Replikation und Instance-Manager-API zwischen den Instanzen
    - from:
        - podSelector:
            matchLabels:
              cnpg.io/cluster: keycloak-db
      ports:
        - protocol: TCP
          port: 5432
        - protocol: TCP
          port: 8000
    # CloudNativePG-Operator (Status, Backups, Failover)
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: cnpg-system
      ports:
        - protocol: TCP
          port: 8000
  egress:
    # Instance Manager spricht mit dem Kubernetes API-Server; Adresse und Port
    # gegen den Cluster pruefen (kubectl get endpoints kubernetes -n default)
    - to:
        - ipBlock:
            cidr: <api-server-endpoint>/32
      ports:
        - protocol: TCP
          port: 6443
    # Replikation zu den anderen Instanzen
    - to:
        - podSelector:
            matchLabels:
              cnpg.io/cluster: keycloak-db
      ports:
        - protocol: TCP
          port: 5432
        - protocol: TCP
          port: 8000
```

> **CloudNativePG ist kein einzelner Pod.** Eine Ingress-Regel, die nur den
> Authserver zulässt, unterbindet Replikation und Operator-Zugriff; das Cluster
> gerät in einen nicht wiederherstellbaren Zustand. Dieselbe Sorgfalt gilt für
> die Token-Renewer-CronJobs, die den API-Server erreichen müssen, um das
> Access-Token-Secret zu schreiben (Matrix B, Negativliste N9).

##### Baustein 5 — Telemetriedaten Service (Matrix B18, B19, B20 · C21, C22 · N7, N10)

Der Telemetriedaten Service ist die einzige Komponente mit Verkehr in beide
Richtungen zum Anbieter: er liefert Telemetrie an dessen Monitoring und SIEM und
nimmt zugleich über einen eigenen Port die vom Anbieter-SIEM eingespeisten
Sicherheitsereignisse für die Weiterleitung an das TI SIEM entgegen (19).

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: telemetry-gateway
  namespace: zeta-guard
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: opentelemetry-collector
  policyTypes: [Ingress, Egress]
  ingress:
    # Kernkomponenten (n. i. B.): OTLP/gRPC von allen, Syslog/UDP vom PEP
    - from:
        - podSelector: {}
      ports:
        - protocol: TCP
          port: 4317
    - from:
        - podSelector:
            matchLabels:
              app.kubernetes.io/name: pep-proxy
      ports:
        - protocol: UDP
          port: 54526
    # (18) Resource Server des Fachdienstes
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: resource-server
      ports:
        - protocol: TCP
          port: 4317
    # (19) Annahme von Sicherheitsereignissen des Anbieter-SIEM zur Weiterleitung
    # an das TI SIEM. Eigener Receiver auf eigenem Port, mTLS mit Client-Zertifikat;
    # Port gegen das Chart pruefen. Ausschliesslich das SIEM darf ihn erreichen (N10).
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: siem
      ports:
        - protocol: TCP
          port: 4319
  egress:
    # (20) Monitoring des Anbieters
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: monitoring
      ports:
        - protocol: TCP
          port: 4317
    # Telemetrieausleitung an das SIEM des Anbieters (n. i. B., Abschnitt 6)
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: fachdienst
          podSelector:
            matchLabels:
              app: siem
      ports:
        - protocol: TCP
          port: 4317
    # (21) telemetry, (22) siem, providerInternal.telemetrySystems: ipBlocks
```

> **Die Egress-Regel zum Anbieter-SIEM ist eine Netzwerkfreigabe, keine
> inhaltliche.** Welche Daten über diesen Pfad fließen dürfen, bestimmt
> A_28960-01: nur betriebliche, bereinigte Telemetrie (A_27260). Die
> Pipeline-Konfiguration des Collectors muss die sicherheitsrelevanten Signale
> ausschließlich in den `siem`-Exporter (22) leiten.
>
> **Der Annahme-Port ist ein Weiterleitungspfad nach außen.** Wer ihn erreicht,
> kann Ereignisse in das TI SIEM einschleusen, ohne sich dort selbst authentisieren
> zu müssen — genau die Authentisierung, die dieser Pfad einsparen soll. Ein
> `podSelector: {}` oder eine namespace-weite Freigabe wäre hier ein Fehler mit
> Außenwirkung. Der Receiver MUSS zusätzlich zur NetworkPolicy mTLS mit
> Client-Zertifikat erzwingen und die eingespeisten Ereignisse als
> anbieterseitig erzeugt kennzeichnen.

##### Baustein 6 — Fachdienst-Namespace (Matrix N4, N6)

Der Fachdienst-Namespace wird vom **DH** und **DA** verantwortet. Ohne Default-Deny
auch dort ist N4 nicht durchsetzbar: Eine Ingress-Regel am Resource Server nützt
nichts, solange ein beliebiger anderer Pod desselben Namespace ihn erreichen kann.

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: resource-server
  namespace: fachdienst
spec:
  podSelector:
    matchLabels:
      app: resource-server
  policyTypes: [Ingress]
  ingress:
    # (17) - ausschliesslich der PEP. Dies ist die Regel, die den ZETA Guard
    # ueberhaupt erst unumgehbar macht.
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: zeta-guard
          podSelector:
            matchLabels:
              app.kubernetes.io/name: pep-proxy
      ports:
        - protocol: TCP
          port: 8443
```

##### Abbildung der Matrix auf die Chart-Konfiguration

| Matrixgruppe | Durchsetzung |
| --- | --- |
| A — Ingress von außen | Ingress-NetworkPolicies mit `podSelector` (und `namespaceSelector`, falls der Ingress Controller in einem eigenen Namespace läuft) auf den Ingress Controller, **nicht** per `ipBlock`; (7) zusätzlich über den PEP |
| B — Ost-West | Ingress- und Egress-Regeln mit Pod-Selektoren; keine IP-Konfiguration durch den DA erforderlich, außer für den API-Server-Endpunkt (CNPG, Token-Renewer) |
| C — Egress | `networkPolicy.egress.<kategorie>.ipBlocks` des Charts; IP-Pflege durch den DA |
| D — clientseitig | nicht durch NetworkPolicies durchsetzbar |
| E — Negativliste | ergibt sich aus Default-Deny; Prüfgegenstand des Wirksamkeitsnachweises |

#### 4.3.3 Stand im ZETA Guard und verbleibende Lücken

**Stand im ZETA Guard:** Das Helm Chart liefert **Egress**-NetworkPolicies mit
kategorisierten IP-Blöcken (`telemetry`, `siem`, `artifactRegistry`, `pip`, `popp`,
`ocsp*`, `providerInternal.*`), Default `enabled: false`. Siehe
[Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md).

**Lücken, die geschlossen werden müssen:**

1. **Ingress-Richtung fehlt.** Ohne Default-Deny-Ingress kann jeder Pod im Cluster
   den Authorization Server oder OPA direkt ansprechen und den PEP umgehen. Das ist
   die sicherheitsrelevantere Richtung, weil sie den Policy Enforcement Point selbst
   umgeht. Konkret sind heute N1 bis N6 der Negativliste nicht durchsetzbar.
2. **Default `enabled: false`.** Eine Sicherheitsmaßnahme, die standardmäßig
   deaktiviert ist, wird in der Praxis vergessen. Zielzustand ist `enabled: true`
   mit einem klaren Fehlerbild bei fehlender Konfiguration.
3. **IP-basierte Egress-Regeln sind fragil.** Der Betreiber muss CIDRs für
   Google Artifact Registry und OCSP-Responder pflegen, die sich ohne Ankündigung
   ändern. Das ist im Chart korrekt dokumentiert, aber betrieblich fehleranfällig:
   **Ablauf und Erreichbarkeit dieser Ziele MÜSSEN überwacht werden**, sonst
   äußert sich eine veraltete IP als schwer diagnostizierbarer Autorisierungsfehler.
   Mittelfristig ist ein Egress-Gateway mit FQDN-Allowlist (Abschnitt 4.5) die
   robustere Lösung.
   Verschärfend kommt hinzu, dass `ocspSmcbTsp` keine einzelne Adresse ist,
   sondern die Responder aller zugelassenen SMC-B-TSP umfasst — eine Liste, die
   sich mit dem TSP-Bestand ändert und nicht aus dem Chart ableitbar ist.
4. **Egress-Kategorien fehlen für sechs Matrixzeilen.** Für Federation Master (1),
   Sektoraler IDP (11), Mail Relay (8), Push Gateway (25), die GCP-STS/IAM-Endpunkte
   der Token-Renewer-CronJobs und die JWKS weiterer Authorization Server der
   Föderation existiert heute kein Konfigurationsschlüssel. Bei aktivem
   Default-Deny-Egress scheitern damit Föderation, Nutzerauthentisierung,
   TOFU-Registrierung, Benachrichtigungen und die Token-Erneuerung für Artifact
   Registry und Telemetrie-Empfänger. Diese Kategorien sind im Chart zu ergänzen.
5. **Ports und Labels der Beispiele.** Die Bausteine oben sind gegen Chart 1.2.3
   abgeleitet (PEP 8081/8443, Authserver 8080/8443, Syslog UDP 54526,
   `app.kubernetes.io/name`-Labels). Sie sind bei jedem Chart-Release erneut zu
   prüfen; der ZGH MUSS Port- und Label-Änderungen in den Release Notes ausweisen.

**Wirksamkeitsnachweis:** Der DA MUSS für jede Zeile der Negativliste E einen
Konnektivitätstest durchführen und protokollieren — Positivtests allein weisen
nichts nach. Native NetworkPolicies sind L3/L4-Konstrukte auf IP-Adressen und Ports;
für L7-Kontrolle siehe Abschnitt 4.4. Voraussetzung ist ein CNI-Plugin mit
NetworkPolicy-Unterstützung (Calico, Cilium) — bei einem CNI ohne diese Fähigkeit
werden die Ressourcen **stillschweigend ignoriert**. Der DA MUSS die Wirksamkeit
daher aktiv testen, nicht annehmen.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Pflegt die Kommunikationsmatrix aus Abschnitt 4.3.1 als normatives Artefakt; liefert Default-Deny-, Ingress- und Egress-Policies im Chart; liefert einen Konnektivitätstest, der Freigabe- und Negativliste prüft |
| **DH** | Benennt die Kommunikationsbeziehungen von HSM Proxy, Resource Server und Authorization Backend vollständig und meldet Abweichungen von der Matrix; setzt Default-Deny im Fachdienst-Namespace um |
| **DA** | Konfiguriert IP-Blöcke der Gruppe C; stellt CNI mit NetworkPolicy-Support sicher; **testet die Wirksamkeit** gegen die Negativliste E; überwacht Policy-Drops |

### 4.4 Service Mesh (L7 und mTLS)

**Ziel:** Transparente mTLS-Verschlüsselung, dienstspezifische L7-Autorisierung und
Traffic-Observability zwischen den ZETA Guard Komponenten.

Das Service Mesh (Istio, Linkerd oder Cilium) übernimmt:

* **Mutual TLS:** Alle Verbindungen zwischen ZETA Guard Komponenten werden
  verschlüsselt und wechselseitig authentisiert; Zertifikate werden automatisch
  rotiert. Der Modus MUSS `STRICT` sein — `PERMISSIVE` lässt unverschlüsselten
  Verkehr weiterhin zu und erzeugt eine Sicherheitsillusion.
* **Autorisierungsrichtlinien:** `AuthorizationPolicy` (Istio) bzw. `Server`/
  `AuthorizationPolicy` (Linkerd) schränken die Kommunikation auf L7 ein — z. B.
  darf nur der PEP den Resource Server aufrufen, und nur der Authorization Server
  die PDP Datenbank.
* **Traffic-Observability:** Latenz, Fehlerrate, Durchsatz und Traces je
  Dienstbeziehung fließen in das Monitoring.

**Grundlage:** Die L7-Policies leiten sich aus derselben
[Kommunikationsmatrix](#431-normative-kommunikationsmatrix) ab wie die
NetworkPolicies — sie verfeinern deren Zeilen um Methode und Pfad, statt eine
eigene Quelle zu bilden. Die Zeilen der Gruppe B werden zu
`AuthorizationPolicy`-Ressourcen mit `principals` auf dem ServiceAccount der Quelle;
die Negativliste E bleibt unverändert der Prüfgegenstand. In der
[Komponentenübersicht](Komponentenuebersicht.md) ist das Service Mesh derzeit mit
`TODO` als Basistechnologie geführt. Ein aus Chart 1.2.3 abgeleiteter Entwurf der
Referenz-`AuthorizationPolicy`-Ressourcen (Default-Deny, je Workload eine
Allow-Policy, `PeerAuthentication` STRICT, `Sidecar` mit `REGISTRY_ONLY` und
`ServiceEntry` je Egress-Kategorie) liegt vor, ist aber noch nicht Bestandteil
des Charts (Abschnitt 10).

**Sidecar- oder Ambient-Modus — Entscheidung des Betreibers.** Die
[Kubernetes-Anleitung](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
zeigt beispielhaft Istio im **Ambient-Modus** (ztunnel, HBONE); der oben genannte
Policy-Entwurf setzt den **Sidecar-Modus** voraus. Beide erfüllen mTLS `STRICT`
und beide werden vom ZGH unterstützt. Welcher Modus zum Einsatz kommt, legt der
**DA** anhand seiner Betriebsumgebung fest, und zwar aus einem konkreten Grund:

* Im **Sidecar-Modus** läuft der mTLS-Endpunkt im Pod, also innerhalb derselben
  Vertrauensgrenze wie die Anwendung. Bei Betrieb in einer **VAU** ist das die
  Voraussetzung dafür, dass eine verschlüsselte Verbindung direkt aus der VAU
  heraus in eine andere VAU-Instanz aufgebaut wird, ohne dass Klartext die VAU
  verlässt. Die Spezifikation verlangt genau das: die mesh-internen Identitäten
  (PrK.K8s.mTLS) sind innerhalb der VAU zu verwalten, und die
  TLS-Terminierung von Client-Verbindungen muss innerhalb der VAU erfolgen
  (A_28852).
* Im **Ambient-Modus** und bei anderen node-basierten Datenebenen (Istio
  ztunnel, Cilium mit WireGuard oder IPsec, eBPF-basierte Verschlüsselung)
  findet die Verschlüsselung auf Node-Ebene **außerhalb des Pods** statt. Je nach
  VAU-Technologie liegt sie damit außerhalb der VAU-Grenze; der Verkehr zwischen
  Anwendung und Verschlüsselungspunkt ist dann innerhalb des Nodes im Klartext
  und für den Plattformbetreiber einsehbar. Für Deployments ohne VAU oder mit
  einer VAU, die den gesamten Node umschließt, ist das unproblematisch; bei
  Pod-granularer VAU ist der Sidecar-Modus zu wählen.

Für L7-`AuthorizationPolicy` mit Methoden und Pfaden braucht der Ambient-Modus
zusätzlich Waypoint-Proxies je Namespace oder Service. Der ZGH MUSS die
Referenz-Policies so liefern, dass sie in beiden Modi funktionieren, und die
modusabhängigen Punkte (Init-Container-Verhalten, Port-Ausnahmen, Waypoints)
dokumentieren. Der DA MUSS seine Wahl inklusive der VAU-Bewertung im
Zulassungsnachweis begründen (Abschnitt 11). Unabhängig vom Modus gilt:
**UDP-Verkehr (PEP-Syslog 54526) und Workloads ohne Mesh-Anbindung
(CloudNativePG standardmäßig) werden vom Mesh nicht erfasst** — die
NetworkPolicies aus Abschnitt 4.3 bleiben dafür die Durchsetzung.

Beispiel für Matrixzeile B(13) — nur der Authorization Server darf die Policy Engine
aufrufen, und nur den Entscheidungs-Endpunkt:

```yaml
apiVersion: security.istio.io/v1
kind: AuthorizationPolicy
metadata:
  name: opa-nur-authserver
  namespace: zeta-guard
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: opa
  action: ALLOW
  rules:
    - from:
        - source:
            principals: ["cluster.local/ns/zeta-guard/sa/authserver"]
      to:
        - operation:
            methods: ["POST"]
            paths: ["/v1/data/policies/zeta/authz/decision"]
```

**Abgrenzung:** Wird das ZETA-eigene Service Mesh durch eine anbietereigene Lösung
ersetzt, geht die Verantwortung für Betrieb, Sicherheit und Zulassungsnachweise
vollständig auf den Anbieter über. Die Prüfkriterien stehen in der
[Prüfliste Optionale Komponenten](Pruefliste_Optionale_Komponenten.md#4-prüfliste-service-mesh-eigene-lösung).

**Wenn kein Service Mesh eingesetzt wird**, MUSS die TLS-Absicherung der
Komponentenkommunikation auf andere Weise sichergestellt werden — dies ist bereits
als optionale Voraussetzung in
[Wie Sie ZETA Guard in Kubernetes konfigurieren](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
festgehalten. Für die Telemetrie ist die mTLS-Konfiguration des Exporters
dokumentiert.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Verfeinert die Kommunikationsmatrix aus Abschnitt 4.3.1 auf L7 und liefert Referenz-`AuthorizationPolicy`-Ressourcen für Sidecar- und Ambient-Modus; stellt konsistente Workload-Labels bereit; validiert die Kompatibilität der Komponenten mit Sidecar-Injection (Init-Container-Reihenfolge!) und mit Waypoints |
| **DH** | Bindet HSM Proxy und Resource Server in das Mesh ein; benennt zulässige L7-Aufrufer; bewertet, ob die VAU-Grenze den Sidecar-Modus erfordert |
| **DA** | Wählt den Mesh-Modus und begründet ihn im Zulassungsnachweis (VAU-Bewertung); betreibt das Mesh; erzwingt mTLS `STRICT`; verantwortet CA- und Zertifikatsrotation; überwacht mTLS-Abdeckung als Metrik |

> **Betriebshinweis (Sidecar-Modus):** Der Provisioning Processor läuft als
> Init-Container von Authserver, PEP-Proxy, OPA und OPA-Simulation und benötigt
> Netzwerkzugriff auf die Registry. Im Sidecar-Modus ist der Proxy zu diesem
> Zeitpunkt noch nicht bereit, und der Init-Container schlägt fehl. Erforderlich
> ist entweder Istio mit nativen Sidecars (`ENABLE_NATIVE_SIDECARS=true`,
> Kubernetes ≥ 1.29) oder `holdApplicationUntilProxyStarts: true`. Im
> Ambient-Modus tritt das Problem nicht auf, weil ztunnel auf Node-Ebene läuft.
> Die JGroups-Ports 7800/57800 des Authservers sind auf keinem Service deklariert;
> im Sidecar-Modus sind sie entweder als PERMISSIVE zu führen, per Headless
> Service zu deklarieren oder von der Interception auszunehmen.

### 4.5 Ingress und Egress / Gateway

**Ingress Controller:** Externer eingehender Verkehr wird über einen Ingress
Controller (NGINX oder Envoy-basiert) terminiert. Aufgaben: TLS-Terminierung,
Rate Limiting, optional WAF. Es wird ausschließlich HTTPS mit **TLS 1.2 oder höher**
akzeptiert, und die Ingress-Kommunikation wird für **IPv4 und IPv6** bereitgestellt.

Das Rate-Limit MUSS entsprechend den erwarteten Nutzungsszenarien konfiguriert
werden — dies ist bereits als
[Betreiberanforderung](../SicherheitsanforderungenZETAGuardBetreiber.md) gegen
DoS-Angriffe festgehalten. **Ergänzend gehört das Erreichen des Rate-Limits in die
Überwachung**: ein dauerhaft greifendes Limit ist entweder ein Angriff oder eine
Fehlkonfiguration, und beides erfordert eine Reaktion.

**Egress Gateway:** Ausgehender Verkehr (PIP/PAP-Registry, Telemetriedaten-Service,
Identity Provider, OCSP) wird über ein dediziertes Egress Gateway mit gepflegter
Allowlist geleitet, sodass kein unkontrollierter Datenabfluss stattfindet.

> **Umsetzungsstand:** Zunächst verwendet ZETA Guard ausschließlich
> NetworkPolicies als Egress-Funktion. Ein Egress Gateway mit FQDN-Allowlist ist
> Ausbaustufe 3 (Abschnitt 8) und löst zugleich das in 4.3 beschriebene
> Fragilitätsproblem IP-basierter Regeln.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Liefert PEP-seitige Rate-Limit-Defaults und die zugehörigen Metriken; dokumentiert die vollständige Liste externer Ziele inkl. Zweck |
| **DH** | Benennt zusätzliche externe Ziele des Fachdienstes |
| **DA** | Betreibt Ingress und Egress Gateway; stellt TLS-Zertifikate bereit; pflegt die Allowlist; überwacht Rate-Limit-Treffer, TLS-Handshake-Fehler und blockierte Egress-Versuche |

### 4.6 Pod-Überwachung auf Syscall-Ebene (Cilium Tetragon)

**Ziel:** Erkennung und Blockade von Post-Exploitation-Aktivitäten innerhalb
laufender Pods — dort, wo alle vorgelagerten Schichten bereits umgangen wurden.

Cilium Tetragon ist ein eBPF-basiertes Security-Observability- und
Enforcement-Framework. Im Unterschied zu netzwerkorientierten Schutzmechanismen
operiert es im Linux-Kernel und ermöglicht Laufzeitüberwachung auf
Systemaufruf-Ebene innerhalb von Pods und Containern.

> **Berechtigungshinweis:** Da Tetragon über eBPF tief in den Linux-Kernel eingreift
> und clusterweite Ressourcen erstellt, benötigt das installierende Service-Konto
> `cluster-admin`-Rechte. Für den laufenden Betrieb und das Erstellen von Regeln
> genügt ein dediziertes RBAC-Profil für die Cilium-CRDs.

**Fähigkeiten und ihre Anwendung im ZETA Guard:**

* **Process Execution Monitoring:** Jede Prozessausführung innerhalb eines ZETA
  Guard Pods wird erfasst. Unerwartete Prozesse — eine Shell im nginx-Container,
  `curl`/`wget`/`nc` im OPA-Container, ein Paketmanager im Keycloak-Container —
  lösen eine Warnung aus und können im Enforcement Mode direkt blockiert werden.
  Genau dies erkennt Post-Exploitation nach einer Kompromittierung.
* **File Integrity Monitoring (FIM):** Schreibzugriffe auf kritische Pfade —
  nginx-Konfiguration, Keycloak-Konfiguration, gemountete Zertifikate und Schlüssel,
  OPA-Bundle-Verzeichnis, Binary-Pfade — werden überwacht und im Enforcement Mode
  unterbunden.
* **Network Observability auf Syscall-Ebene:** Verbindungen werden anhand der
  tatsächlichen Syscalls (`connect`, `accept`, `sendmsg`) beobachtet. Damit ist jede
  Netzwerkverbindung dem **auslösenden Prozess und Container** zuordenbar — eine
  Attribution, die auf Paketebene nicht möglich ist und die forensische
  Auswertung entscheidend verkürzt.
* **TracingPolicy und Enforcement:** Deklarative Regeln als Custom Resources, die
  der Kernel durchsetzt. Unzulässige Aktionen werden blockiert, **bevor** eine
  Reaktion auf Anwendungsebene möglich wäre.

**Die entscheidende Herstellerleistung:** Eine `TracingPolicy` ist nur so gut wie
die zugrunde liegende Baseline. Der ZGH MUSS je Komponente liefern:

| Komponente | Erwartete Prozesse | Kritische Schreibpfade (FIM) |
| --- | --- | --- |
| PEP (nginx) | `nginx` (Master + Worker); bei `pepproxyMetricsEnabled` zusätzlich `nginx-prometheus-exporter` als Sidecar-Container | `/etc/nginx/**`, TLS-Secret-Mounts, ASL-Schlüssel |
| Authorization Server (Keycloak) | `java`; Init-Container `keycloak-build` (`kc.sh build`), `keychain-generator`, Provisioning Processor | `/opt/keycloak/conf/**`, Truststore, HSM-Konfiguration |
| Policy Engine (OPA), OPA-Simulation | `opa` | Bundle-Verzeichnis, Signaturschlüssel, Token-Secret-Mount |
| PDP Datenbank (PostgreSQL, CNPG) | `postgres`, `manager` (CNPG Instance Manager) | `PGDATA`, Konfigurationsdateien |
| PDP Cache (Infinispan) | `java` | Konfiguration, Keystore |
| Telemetry-Gateway (OTelCol) | `otelcol*` | Collector-Konfiguration, mTLS-Material |
| Notification Service | (herstellerspezifisch) | Konfiguration, Schlüsselmaterial |
| Provisioning Processor | Init-Prozess, cosign-Verifikation | Trust-Certchain-Mount |
| Token-Renewer-CronJobs | Kurzlebiger Prozess (Token Exchange, `kubectl`/API-Client) | keine; Schreibzugriff nur über die Kubernetes-API auf das Token-Secret |

**Alternative/Ergänzung Falco:** Falco deckt einen vergleichbaren Anwendungsfall ab,
bringt ein umfangreiches vorgefertigtes Regelwerk mit und ist in vielen
Betriebsumgebungen bereits etabliert. Wo der DA Falco betreibt, ist das Ziel
identisch — der ZGH liefert die Baselines werkzeugneutral, damit sie in beide
Regelsprachen übersetzbar sind. Der Betrieb **beider** Werkzeuge parallel ist wegen
des Kernel-Overheads nicht zu empfehlen.

**Enforcement-Vorsicht:** Enforcement auf Syscall-Ebene kann einen Dienst
zuverlässiger unterbrechen als jeder Angreifer. Der Rollout MUSS über
Observe-Modus → Alarmierung → selektives Enforcement erfolgen, und Enforcement
zuerst für die eindeutigsten Fälle (Shell-Exec in Applikationscontainern) und
nicht für breite Dateipfad-Regeln.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Liefert Prozess- und FIM-Baselines je Komponente und pflegt sie über Releases; liefert `TracingPolicy`-Referenzressourcen; **meldet Baseline-Änderungen im Release Note**, damit der DA Regeln vor dem Upgrade anpasst |
| **DH** | Liefert dieselben Baselines für **HSM Proxy** und Resource Server |
| **DA** | Installiert und betreibt Tetragon/Falco; führt Enforcement gestuft ein; leitet Events ins SIEM; verantwortet die Reaktion |

### 4.7 RBAC-Härtung

**Ziel:** Least Privilege für alle Subjekte, die auf die Kubernetes-API zugreifen.

* Jeder ZETA Guard Microservice erhält einen **dedizierten ServiceAccount** mit
  minimalen Berechtigungen. Dies ist im Helm Chart bereits umgesetzt (siehe
  [ServiceAccount](Referenz_des_Helm_Charts.md#serviceaccount)); über
  `create: false` kann ein bestehender ServiceAccount verwendet werden.
* Die Verwendung des `default`-ServiceAccounts in Pods wird per Admission Policy
  verboten (Abschnitt 4.2).
* `automountServiceAccountToken: false` überall dort, wo kein API-Zugriff nötig ist
  — für die meisten ZETA Guard Komponenten ist das der Regelfall. Ein gemountetes,
  ungenutztes Token ist bei einer Container-Kompromittierung ein direkter
  Eskalationspfad.
* `ClusterRole`- und `ClusterRoleBinding`-Zuweisungen werden auf das absolute
  Minimum reduziert und **periodisch überprüft** (mindestens quartalsweise, sowie
  nach jedem Cluster-Upgrade).
* API-Server-Zugriff auf das Produktivsystem ist auf dedizierte
  Operator-Identitäten beschränkt; interaktive Zugriffe erfordern **MFA** und werden
  auditiert.
* **Break-Glass-Zugänge** sind benannt, technisch getrennt, zeitlich begrenzt und
  lösen bei Nutzung **automatisch** einen Alarm aus.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Liefert dedizierte ServiceAccounts mit dokumentierten Mindestrechten; setzt `automountServiceAccountToken: false` als Default, wo möglich |
| **DH** | Analog für eigene Komponenten |
| **DA** | Härtet Cluster-RBAC; erzwingt MFA; auditiert privilegierte Zugriffe; führt periodische Rechte-Reviews durch |

## 5. Ergänzende Maßnahmen aus dem Betrieb sicherer Dienste

Die folgenden Maßnahmen sind in den ursprünglichen Überlegungen nicht enthalten,
haben sich im Betrieb sicherheitskritischer Kubernetes-Dienste aber als notwendig
erwiesen.

### 5.1 Kubernetes API-Server-Audit-Logging

Ohne API-Server-Audit-Log ist nach einem Vorfall nicht rekonstruierbar, **wer** was
im Cluster geändert hat. Das ist die wichtigste forensische Quelle überhaupt und
fehlt in vielen Betriebsumgebungen.

Mindestens auf `Metadata`-Level für alle Ressourcen, auf `RequestResponse`-Level für
`secrets`, `configmaps`, `rolebindings`, `clusterrolebindings`, `serviceaccounts`
sowie `pods/exec`, `pods/attach` und `pods/portforward`. Die Logs werden **außerhalb
des Clusters** manipulationssicher (append-only/WORM) gespeichert.

Die Spezifikation macht dazu konkrete Vorgaben, die das Audit-Log erfüllen MUSS:

* **A_28749:** revisionssichere (Tamper-Proof) Protokollierung aller
  dienstrelevanten administrativen Vorgänge auf dem ZETA-Cluster — Anwendungs-,
  Plattform- und Cluster-Administration.
* **A_28750-01:** Löschung eines Admin-Auditeintrags frühestens nach **6 Monaten**
  und nur im Rahmen der gesetzlichen Vorgaben.
* **A_28751:** Kontrolle des Admin-Audit-Logs mindestens **alle 3 Monate im
  Vieraugenprinzip** durch Rollen, die nicht an der Administration des Clusters
  beteiligt sind; Automatisierung ist zulässig, solange das Vieraugenprinzip
  gewahrt bleibt.

Das Admin-Audit-Log ist damit von den übrigen Protokollen zu trennen:
Fehleranalyse-Protokolle sind nach Behebung des Fehlers unverzüglich zu löschen
(A_25747-01), sicherheitsrelevante Telemetrie nach Übermittlung an die gematik
(A_28964). Die WORM-Aufbewahrung gilt für das Audit-Log, nicht pauschal für alle
Logs.

**Verantwortung: DA** (vollständig — der ZGH hat keinen Zugriff auf diese Ebene).

### 5.2 Supply-Chain-Sicherheit über die Signatur hinaus

* **SBOM je Image** (SPDX oder CycloneDX), damit bei einer neuen CVE innerhalb von
  Minuten beantwortbar ist, ob der Dienst betroffen ist.
* **Provenance-Attestierung** (SLSA) für die Build-Kette.
* **Kontinuierliches Vulnerability-Scanning der Images im Registry-Cache** — nicht
  nur zum Build-Zeitpunkt. Ein Image, das vor drei Monaten sauber war, ist es heute
  nicht mehr.
* **Digest-Pinning für Komponenten-Images** statt mutabler Tags, weil sich sonst
  der laufende Dienst bei jedem Pod-Neustart unbemerkt ändern kann. **Ausdrücklich
  ausgenommen ist das Provisioning-Daten-Image:** A_29743 schreibt vor, dass der
  ZETA Guard es über das Tag `latest` zyklisch auf neue Versionen prüft und per
  Hot-Reload einspielt, damit TSL, Vertrauensanker und Federation-Master-URL ohne
  Neustart aktuell bleiben. Die Integrität dieses Images sichert die
  cosign-Signaturprüfung durch den Provisioning Processor, nicht ein Digest. Die
  Admission-Policy `disallow-latest-tag` aus Abschnitt 4.2 betrifft es nicht, weil
  es nicht vom Kubelet, sondern vom Init-Container gezogen wird. Für Komponenten-
  Images (`authserver`, `pepproxy` mit `imagePullPolicy: Always`) bleibt
  Digest-Pinning die Vorgabe.
* **Der lokale Registry-Cache ist Pflicht** (bereits im Integrationsleitfaden
  festgehalten) und damit selbst eine sicherheitskritische Komponente: Er MUSS
  gehärtet, überwacht und in das Backup einbezogen werden.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Signierte Images, SBOM, Provenance, Digest-Referenzen; **CVE-Meldungen und Patch-Releases mit definierter Reaktionszeit** |
| **DH** | Analog für eigene Images |
| **DA** | Registry-Cache betreiben und härten; Laufzeit-Scanning; Patch-Einspielung nach SLA |

### 5.3 Secrets-Management

* **Encryption at Rest für etcd** mit externem KMS — ohne dies liegen alle
  Kubernetes Secrets faktisch im Klartext auf den Control-Plane-Nodes.
* Secrets ausschließlich als Volume, **nicht als Umgebungsvariable** (Env-Variablen
  landen in Crash-Dumps, `/proc` und Debug-Ausgaben).
* **Rotation ohne Downtime** muss für alle Secrets möglich und getestet sein:
  Datenbank-Credentials, mTLS-Material des Telemetry-Gateways, TLS-Zertifikate,
  ASL-Schlüssel, `imageTrustCertchainSecretRef`, Registry-Credentials.
* **Kein Schlüsselmaterial in Logs** — insbesondere nicht in Traces des
  Telemetry-Gateways.
* Anbindung des Authorization Servers an ein **HSM** über den vom **DH**
  bereitgestellten HSM Proxy schützt das Token-Signaturmaterial. Der HSM Proxy ist
  damit selbst hochkritisch und MUSS die gleiche Überwachungstiefe erhalten wie die
  ZETA Guard Kernkomponenten.

| Rolle | Aufgabe |
| --- | --- |
| **ZGH** | Secret-Referenzen statt Inline-Werte; Rotationsfähigkeit; keine Secrets in Logs/Traces |
| **DH** | HSM Proxy: Härtung, Telemetrie, Verfügbarkeit, Schlüsselzugriffs-Audit |
| **DA** | etcd-Encryption mit KMS; Secret-Store-Betrieb; Rotationsprozesse und deren Test |

### 5.4 Zertifikats-, Schlüssel- und Vertrauensanker-Monitoring

Abgelaufene Zertifikate sind in TI-Umgebungen eine der häufigsten Ausfallursachen
und wirken wie ein Sicherheitsvorfall. Zu überwachen sind mindestens:

| Objekt | Alarm bei |
| --- | --- |
| Ingress-TLS-Zertifikat | Restlaufzeit < 30 Tage |
| mTLS-Material Telemetry-Gateway | Restlaufzeit < 30 Tage |
| Token-Signaturschlüssel (AuthS/HSM) | Restlaufzeit < 30 Tage, Rotation fehlgeschlagen |
| cosign-Trust-Certchain | Restlaufzeit < 60 Tage |
| Komponenten-Zertifikate der TI-PKI: C.PEP.Sig, C.AuthS.Sig (Signatur), C.PEP.TLS, C.AuthS.TLS, C.Ingress.TLS (Spezifikation Kap. 4.x, Schlüsseltabelle) | Restlaufzeit < 60 Tage |
| PuK.PEP.ASL (semi-statisch, maximal 1 Monat gültig) | Rotation fehlgeschlagen |
| TSL (Trust Service Status List) | Aktualisierung älter als erwartetes Intervall |
| OCSP-Responder (CAB Forum, TI-PKI) | Nicht erreichbar / Fehlerrate erhöht |
| OCSP-Responder **je SMC-B-TSP einzeln** | Nicht erreichbar / Fehlerrate erhöht |
| Service-Mesh-CA | Rotation fehlgeschlagen |

Die SMC-B-Responder MÜSSEN **je TSP getrennt** überwacht werden. Eine
aggregierte Metrik über alle Responder verdeckt genau den Fall, der im Betrieb
auftritt: ein einzelner TSP ist nicht erreichbar, und nur dessen
Leistungserbringer werden abgelehnt, während die Gesamtfehlerrate unauffällig
bleibt.

Die OCSP-Erreichbarkeit ist hier doppelt relevant, weil sie zugleich anzeigt, ob die
in Abschnitt 4.3 beschriebenen IP-basierten Egress-Regeln noch aktuell sind.

**Verantwortung:** ZGH liefert die Metriken, DA alarmiert und reagiert.

### 5.5 Integrität und Aktualität der Policy-Bundles

Die Policy Engine bezieht ihre OPA-Bundles vom PIP. Zwei Ereignisse sind
sicherheitsrelevant:

* **Signaturprüfung fehlgeschlagen** → sofortiger Alarm, das Bundle wird verworfen.
  Siehe [Wie Sie OPA in ZETA Guard konfigurieren](../Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md).
  Die Spezifikation verlangt dafür eine automatisierte Meldung an das TI SIEM:
  A_25606-02 bei Download- oder Signaturfehlern, A_25485-02 bei jeder
  erfolgreichen Aktualisierung von PIP-Daten und PAP-Policies.
* **Bundle veraltet (staleness)** → der PDP entscheidet auf Basis überholter
  Regeln, ohne dass ein Fehler sichtbar wird. Das Alter des zuletzt erfolgreich
  geladenen Bundles MUSS als Metrik vorliegen und ab einem definierten Schwellwert
  alarmieren.

Ein stiller Rückfall auf ein altes Policy-Bundle ist gefährlicher als ein
Ladefehler, weil er nicht auffällt.

**Verantwortung:** ZGH liefert Metrik und Schwellwertempfehlung, DA alarmiert.

### 5.6 Verfügbarkeit als Sicherheitssignal

Verfügbarkeitsmonitoring gehört in dieses Konzept, weil ein Angriff sich zuerst als
Verfügbarkeitsanomalie zeigt:

* **Golden Signals** je Komponente: Latenz, Traffic, Fehlerrate, Sättigung
* Pod-Restart-Schleifen, `OOMKilled`, `CrashLoopBackOff`
* Erschöpfung des Connection Pools der PDP Datenbank
* Sättigung des ASL-Session-Cache im PEP (pro Pod im nginx Shared Memory, siehe
  [Komponentenübersicht](Komponentenuebersicht.md))
* Auslastung gegen `resources.limits` (siehe
  [Wie Sie Ressourcen für ZETA Guard Pods verwalten](../Anleitungen/Wie_Sie_Ressourcen_für_ZETA_Guard_Pods_verwalten.md))

### 5.7 Autorisierungs-Anomalien (fachliche Laufzeitüberwachung)

Diese Ebene ist ZETA-spezifisch und in generischen Kubernetes-Sicherheitskonzepten
nicht enthalten. Sie ist zugleich die einzige, die einen Angriff **auf die
Zero-Trust-Logik selbst** erkennt:

* Sprunghafter Anstieg von 401/403 am PEP (Credential Stuffing, Token-Raten)
* Gehäufte DPoP-Fehler oder Nonce-Replays
* Token-Ausstellung ohne vorausgegangene erfolgreiche Client-Attestierung
* Auffällige Häufung von Client-Registrierungen
* Ungewöhnliche Verteilung von SMC-B-Identitäten oder Zugriffsmustern über die Zeit
* PoPP-Prüfungen mit erhöhter Fehlerrate
* OPA-Entscheidungen mit auffälligem `deny`-Anteil für einzelne Clients

**Verantwortung:** Der **ZGH** liefert diese Signale als strukturierte Telemetrie
**und deren Interpretation**; der **DA** implementiert Schwellwerte und Alarme im
SIEM. Ohne die Interpretationshilfe des Herstellers kann kein SOC entscheiden, ob
eine erhöhte `deny`-Rate ein Angriff oder eine Policy-Änderung ist.

### 5.8 GitOps-Drift als Sicherheitssignal

Wird der ZETA Guard über Argo CD (Management Service) deployt, ist jeder
`OutOfSync`-Zustand eine nicht durch den Deployment-Prozess autorisierte Änderung am
Cluster — also entweder ein Prozessverstoß oder eine Manipulation. `OutOfSync` MUSS
daher alarmieren, nicht nur im Dashboard sichtbar sein. Für den Betrieb in einer
VAU schreibt die Spezifikation genau das vor: jede Konfigurationsänderung am ZETA
Guard löst eine Sicherheitsmeldung an das SIEM des Anbieters aus (A_28752), und
auf jede dieser Meldungen folgt ein definierter Incident-Management-Prozess
(A_28753). Dieses Konzept wendet die Regel unabhängig von der VAU an.

**Verantwortung: DA.**

### 5.9 Zeitsynchronisation und Log-Integrität

* NTP/chrony auf allen Nodes, Abweichung überwacht — ohne synchrone Zeit ist keine
  Korrelation über Komponenten hinweg und keine gerichtsfeste Forensik möglich.
* Admin-Audit-Log und Plattform-Sicherheitsereignisse append-only/WORM außerhalb
  des Clusters, Aufbewahrung mindestens 6 Monate (A_28750-01). **Nicht** unter
  WORM fallen Fehleranalyse-Protokolle (A_25747-01: Löschung nach Behebung) und
  sicherheitsrelevante Telemetrie (A_28964: Löschung nach Übermittlung an die
  gematik).
* Der Ausfall der Telemetrie-Pipeline selbst MUSS alarmieren — „keine Events" darf
  niemals als „keine Vorfälle" interpretiert werden.

**Verantwortung: DA**, Ausfallmetrik der Pipeline vom **ZGH**.

### 5.10 Backup, Wiederanlauf und Übung

* Backup der PDP Datenbank inkl. **getestetem** Restore
* Dokumentierter Wiederanlauf nach Totalausfall
* Regelmäßige Übungen: Restore-Test, Incident-Response-Drill, Generalprobe nach
  jeder Produktionsänderung (bereits im Integrationsleitfaden gefordert)

**Verantwortung: DA.**

## 6. Telemetrie- und Meldewege

```mermaid
flowchart LR
    subgraph ZG["ZETA Guard"]
        K["Kernkomponenten<br/>PEP · AuthS · OPA · DB"]
        GW["Telemetry-Gateway<br/>[OTelCol]<br/>bündelt · filtert · zensiert"]
        K --> GW
    end
    subgraph PLAT["Plattform (DA)"]
        RT["Tetragon / Falco"]
        AUD["K8s API-Audit"]
        ADM["Admission-Denials"]
        MESH["Service-Mesh-Telemetrie"]
    end
    subgraph DAS["Anbieter (DA)"]
        SOC["SIEM / SOC<br/>Korrelation · Alarmierung"]
    end
    subgraph GEM["gematik"]
        TSIEM["TI SIEM"]
        TMON["Telemetriedaten-Empfänger"]
    end
    GW -->|OTLP mTLS<br/>nur betriebliche, bereinigte Telemetrie| SOC
    GW -->|OTLP mTLS<br/>Sicherheitstelemetrie| TSIEM
    GW -->|OTLP mTLS| TMON
    RT --> SOC
    AUD --> SOC
    ADM --> SOC
    MESH --> SOC
    SOC -->|OTLP mTLS<br/>ausgewählte Si-Ereignisse| GW
```

**Wesentliche Festlegungen:**

* Der **Telemetriedaten Service (Telemetry-Gateway)** ist der einzige
  Ausleitungspunkt für Telemetrie aus dem ZETA Guard. Exporte an gematik-Systeme
  sind vorkonfiguriert, Exporte an Anbieter-Backends werden ergänzt (siehe
  [Wie Sie ein Observability-Backend anschließen](../Anleitungen/Wie_Sie_ein_Observability-Backend_an_ZETA-Guard_anschließen.md)).
* **Sicherheitstelemetrie geht ausschließlich an die gematik.** A_28960-01
  verbietet die Weitergabe der sicherheitsrelevanten Telemetriedaten nach
  A_28783 (Security-Telemetrie PEP/PDP je Anfrage), A_28793 (Policy-
  Entscheidungen), A_28795 (Angriffserkennung) und A_28867 an den Betreiber;
  A_28964 fordert die Löschung der zugehörigen Logs unmittelbar nach erfolgreicher
  Übermittlung. Der Anbieter erhält nur betriebliche, so bereinigte Telemetrie,
  dass keine Profilbildung möglich ist (A_27260). Die Pipeline-Konfiguration
  des Collectors, die diese Trennung erzwingt, ist Herstellerleistung und
  Prüfgegenstand. Für das Anbieter-SOC folgt daraus: Angriffe auf die
  Zero-Trust-Logik (Abschnitt 5.7) sind primär im TI SIEM sichtbar; der Anbieter
  sieht davon nur aggregierte, anonymisierte Metriken.
* **Plattform-Sicherheitsereignisse** (Tetragon/Falco, K8s-Audit,
  Admission-Denials) gehen **nicht** über das Telemetry-Gateway, sondern direkt in
  das SIEM des Anbieters. Das Gateway ist Teil des überwachten Systems und daher
  kein vertrauenswürdiger Transportweg für Ereignisse, die eine Kompromittierung
  ebendieses Systems anzeigen.
* **Rückweg für Meldungen an die gematik:** Ausgewählte Sicherheitsereignisse,
  die der Anbieter in seinem eigenen SIEM erkannt hat, werden **über** das
  Telemetry-Gateway an das TI SIEM weitergeleitet (Kante (19) der
  Kommunikationsmatrix). Damit muss sich das Anbieter-SIEM nicht zusätzlich am
  zentralen SIEM authentisieren und autorisieren — es nutzt den bereits
  bestehenden, mTLS-gesicherten Pfad des Gateways. Dieser Weg ergänzt den
  vorstehenden Punkt, er ersetzt ihn nicht: die **Erkennung** bleibt
  anbieterseitig und unabhängig vom Gateway; nur die **Meldung** an die gematik
  nimmt diesen Umweg. Der Annahme-Endpunkt MUSS auf einem eigenen Port liegen,
  mTLS mit Client-Zertifikat erzwingen und ausschließlich für das SIEM des
  Anbieters erreichbar sein (Negativliste N10). Eingespeiste Ereignisse MÜSSEN
  als anbieterseitig erzeugt gekennzeichnet bleiben und dürfen im TI SIEM nicht
  als Ereignisse des ZETA Guard erscheinen.
* **Datenminimierung:** Es werden keine medizinischen oder personenbezogenen
  Fachdaten in die Telemetrie ausgeleitet. Identitäten werden pseudonymisiert. Das
  Gateway filtert und zensiert entsprechend — diese Filterregeln sind
  Herstellerleistung und Prüfgegenstand.
* Alle Verbindungen zu ZETA-Guard-externen Zielen werden per **mTLS** abgesichert.
  Ohne Service Mesh müssen Receiver und Exporter des Gateways selbst für mTLS
  konfiguriert werden.
* Meldepflichten gegenüber der gematik bei sicherheitsrelevanten Vorfällen bleiben
  unberührt und liegen beim **DA**.

## 7. Detektions-Use-Cases

Der folgende Katalog ist der Mindestumfang. Der **ZGH** liefert ihn als
SIEM-tauglichen Content (Signalquelle, Feldnamen, Schwellwert, Interpretation), der
**DA** implementiert und pflegt ihn.

| # | Signal | Quelle | Schwere | Reaktion |
| --- | --- | --- | --- | --- |
| 1 | `execve` einer Shell oder eines Netzwerktools in PEP/AuthS/OPA/DB | Tetragon | **kritisch** | Pod isolieren (nicht löschen), Forensik, IR |
| 2 | Schreibzugriff auf nginx-/Keycloak-Konfiguration oder Zertifikatsmounts | Tetragon FIM | **kritisch** | Pod isolieren, Integritätsprüfung |
| 3 | Ausgehende Verbindung zu nicht freigegebener IP aus ZETA-Namespace | NetworkPolicy-Drop, Tetragon | **hoch** | Prüfen: Exfiltration oder veraltete Allowlist |
| 4 | Admission-Denial wegen fehlender/ungültiger Image-Signatur | Kyverno/Gatekeeper | **hoch** | Deployment-Kette prüfen, Registry-Spiegelung prüfen |
| 5 | `pods/exec`, `pods/attach`, `pods/portforward` auf ZETA-Namespace | K8s-Audit | **hoch** | Immer alarmieren, gegen Change-Ticket abgleichen |
| 6 | Änderung an `ClusterRoleBinding`, `Role`, `ServiceAccount` | K8s-Audit | **hoch** | Gegen GitOps-Änderung abgleichen |
| 7 | Zugriff auf `secrets` durch unerwartetes Subjekt | K8s-Audit | **hoch** | IR |
| 8 | Nutzung eines Break-Glass-Zugangs | K8s-Audit / IdP | **hoch** | Immer alarmieren, nachträgliche Genehmigung |
| 9 | Argo CD `OutOfSync` in ZETA-Namespace | Management Service | **hoch** | Manuelle Cluster-Änderung untersuchen |
| 10 | OPA-Bundle-Signaturprüfung fehlgeschlagen | Policy Engine | **hoch** | PIP-Kette prüfen, Bundle verwerfen |
| 11 | OPA-Bundle-Alter über Schwellwert | Policy Engine | **mittel** | PIP-Erreichbarkeit prüfen |
| 12 | Sprunghafter Anstieg 401/403 am PEP | PEP-Metriken | **mittel** | Credential Stuffing prüfen, Rate-Limit nachziehen |
| 13 | Gehäufte DPoP-/Nonce-Fehler | AuthS | **mittel** | Replay-Versuch prüfen |
| 14 | Token-Ausstellung ohne vorherige Attestierung | AuthS | **hoch** | Flow-Integrität prüfen, IR |
| 15 | Rate-Limit dauerhaft erreicht | Ingress/PEP | **mittel** | DoS oder Fehlkonfiguration |
| 16 | Zertifikat/Trust-Anchor läuft ab | Metriken | **mittel** | Rotation auslösen |
| 17 | OCSP-Responder nicht erreichbar | PEP/AuthS | **mittel** | Egress-Allowlist und TSP-Status prüfen |
| 18 | `CrashLoopBackOff` / `OOMKilled` in ZETA-Namespace | K8s-Events | **mittel** | Ursache klären, Ressourcen prüfen |
| 19 | mTLS-Abdeckung unter 100 % | Service Mesh | **hoch** | Unverschlüsselten Pfad identifizieren |
| 20 | Telemetrie-Pipeline liefert keine Daten mehr | Gateway-Metriken | **hoch** | Blindflug beenden — höchste Priorität |
| 21 | Neue kritische CVE in eingesetztem Image | Registry-Scanning | **abhängig** | Patch nach SLA |
| 22 | Zeitabweichung eines Nodes über Schwellwert | Node-Monitoring | **mittel** | NTP korrigieren |
| 23 | Abfragerate am TOFU-E-Mail-Endpunkt des AuthS über Schwellwert oder Abfrage ohne zugehörige Fachtransaktion | AuthS | **hoch** | Auskundschaftung von Registrierungsdaten prüfen; Client-Zertifikat des Resource Servers verifizieren |
| 24 | Annahme-Endpunkt (19) liefert keine Ereignisse mehr an das TI SIEM weiter, während das Gateway im Übrigen exportiert | Gateway-Metriken je Receiver und Exporter | **hoch** | Meldeweg an die gematik ist unterbrochen, ohne dass die übrige Telemetrie auffällt |
| 25 | Eingespeistes Ereignis am Annahme-Endpunkt ohne gültiges Client-Zertifikat des Anbieter-SIEM | Gateway / mTLS-Logs | **hoch** | Einschleusversuch in gematik-Systeme; Quelle und NetworkPolicy prüfen |

**Zur Signalquelle von 12, 13, 14, 17 und 23:** Diese Use-Cases beruhen auf
Sicherheitstelemetrie des PEP und des Authorization Servers. Nach A_28960-01
erreicht das Anbieter-SIEM davon nur aggregierte, anonymisierte Metriken (etwa
Zähler je Statuscode und Fehlerklasse), keine anfragebezogenen Traces. Die
anfragebezogene Erkennung dieser Use-Cases findet im TI SIEM statt. Der ZGH
MUSS je Use-Case ausweisen, welche Metrik dem Anbieter zur Verfügung steht und
welche Erkennung der gematik vorbehalten ist. Use-Case 20 ist zugleich eine
Anforderung der Spezifikation: der Anbieter MUSS gewährleisten, dass der ZETA
Guard jederzeit an die gematik liefern kann (A_27796).

**Zur Reaktion auf 1, 2 und 7:** Der Reflex, einen verdächtigen Pod zu löschen, ist
falsch. Er vernichtet den Hauptspeicher und damit den Großteil der forensischen
Evidenz. Richtig ist **Isolation**: Netzwerk per NetworkPolicy kappen, Pod aus dem
Service-Endpunkt nehmen, laufen lassen, Evidenz sichern, danach ersetzen. Der
entsprechende Runbook-Schritt gehört in die Betriebsdokumentation des DA.

## 8. Ausbaustufen

Eine gleichzeitige Einführung aller Maßnahmen ist weder machbar noch sinnvoll. Die
folgende Staffelung priorisiert nach Wirkung pro Aufwand.

### Stufe 1 — MUSS (Voraussetzung für den Produktivbetrieb)

* Pod Security Standards `restricted` per Namespace-Label
* Dedizierte ServiceAccounts, kein `default`-SA, RBAC Least Privilege
* Default-Deny NetworkPolicies **in beiden Richtungen**, abgeleitet aus der
  Kommunikationsmatrix (Abschnitt 4.3.1), inkl. Negativtest gegen Liste E
* TLS ≥ 1.2 am Ingress, IPv4 und IPv6, konfiguriertes Rate-Limit
* Kubernetes API-Server-Audit-Logging außerhalb des Clusters
* Image-Signaturprüfung per Admission Control
* Ressourcen-Requests und -Limits erzwungen
* Telemetrie an SIEM (Anbieter und gematik) inkl. Pipeline-Ausfallalarm
* etcd-Encryption at Rest
* Backup der PDP Datenbank mit getestetem Restore
* Zertifikats-Ablaufüberwachung
* Definierte Alarmierungswege und Bereitschaft

### Stufe 2 — SOLL (innerhalb von 6 Monaten nach Inbetriebnahme)

* Vollständiges Admission-Policy-Set im Enforce-Modus
* Service Mesh mit mTLS `STRICT` und L7-`AuthorizationPolicy`
* Tetragon oder Falco im **Observe-Modus** mit herstellergelieferten Baselines
* Kontinuierliches Vulnerability-Scanning im Registry-Cache, Patch-SLA
* SIEM-Use-Cases 1–20 implementiert
* GitOps-Drift-Alarmierung
* Bundle-Staleness- und Autorisierungs-Anomalie-Erkennung
* Runbooks je Use-Case, Incident-Response-Drill durchgeführt

### Stufe 3 — KANN (Ausbau)

* Tetragon-Enforcement für eindeutige Fälle (Shell-Exec, kritische Schreibpfade)
* Egress Gateway mit FQDN-basierter Allowlist statt IP-Blöcken
* Automatisierte Pod-Quarantäne bei kritischen Runtime-Events
* Verhaltensbasierte Anomalieerkennung auf Autorisierungsdaten
* Purple-Team-Übungen gegen den ZETA Guard
* Confidential Computing / VAU-Technologie nach Wahl des Anbieters

## 9. Verantwortungsmatrix (Übersicht)

`V` = verantwortlich · `M` = mitwirkend · `–` = nicht beteiligt

| # | Maßnahme | ZGH | DH | DA |
| --- | --- | :---: | :---: | :---: |
| 4.1 | `restricted`-konforme Manifeste | **V** | M | M |
| 4.1 | Namespace-Labels PSS durchsetzen | – | – | **V** |
| 4.2 | Referenz-Admission-Policies liefern | **V** | M | M |
| 4.2 | Policy-Engine betreiben und erzwingen | – | – | **V** |
| 4.2 | Images signieren, SBOM, Provenance | **V** | **V** | – |
| 4.3 | NetworkPolicies im Chart (Ingress + Egress) | **V** | M | M |
| 4.3 | IP-Blöcke pflegen, Wirksamkeit testen | M | M | **V** |
| 4.3 | Kommunikationsmatrix (Abschnitt 4.3.1) pflegen und fortschreiben | **V** | **V** | – |
| 4.3 | Negativliste E im Konnektivitätstest nachweisen | M | M | **V** |
| 4.4 | Verfeinerung der Matrix auf L7, Referenz-`AuthorizationPolicy` | **V** | **V** | – |
| 4.4 | Mesh-Modus wählen (VAU-Bewertung), Service Mesh betreiben, mTLS STRICT | M | M | **V** |
| 4.5 | Ingress/Egress Gateway betreiben, TLS-Zertifikate | M | – | **V** |
| 4.5 | Rate-Limit-Defaults und -Metriken | **V** | – | M |
| 4.6 | Prozess-/FIM-Baselines je Komponente | **V** | **V** | M |
| 4.6 | Tetragon/Falco betreiben, Enforcement stufen | – | – | **V** |
| 4.7 | Dedizierte ServiceAccounts, Mindestrechte | **V** | **V** | M |
| 4.7 | Cluster-RBAC, MFA, Break-Glass | – | – | **V** |
| 5.1 | API-Server-Audit-Logging | – | – | **V** |
| 5.2 | CVE-Meldung und Patch-Release | **V** | **V** | M |
| 5.2 | Registry-Cache betreiben, Laufzeit-Scanning | M | – | **V** |
| 5.3 | Secret-Referenzen, Rotationsfähigkeit | **V** | **V** | M |
| 5.3 | etcd-Encryption, Secret-Store, Rotation | – | – | **V** |
| 5.3 | HSM Proxy: Härtung, Telemetrie, Audit | M | **V** | M |
| 5.4 | Zertifikats-/TSL-/OCSP-Metriken | **V** | M | M |
| 5.4 | Ablaufalarmierung und Rotation | – | – | **V** |
| 5.5 | Bundle-Signaturprüfung und Staleness-Metrik | **V** | – | M |
| 5.6 | Golden Signals je Komponente | **V** | M | M |
| 5.7 | Autorisierungs-Anomaliesignale + Interpretation | **V** | – | M |
| 5.7 | SIEM-Regeln und Schwellwerte | M | – | **V** |
| 5.8 | GitOps-Drift-Alarmierung | – | – | **V** |
| 5.9 | Zeitsynchronisation, WORM-Logs, Retention | – | – | **V** |
| 5.10 | Backup, Restore-Test, Wiederanlauf | M | M | **V** |
| 7 | SIEM-Use-Case-Content liefern | **V** | M | M |
| 7 | SIEM-Use-Cases betreiben, IR, Runbooks | M | M | **V** |

**Ablesbares Muster:** Der ZGH ist überall dort verantwortlich, wo **Wissen über das
Produkt** benötigt wird; der DA überall dort, wo **Zugriff auf die Plattform**
benötigt wird. Der DH übernimmt für HSM Proxy und Resource Server exakt die Rolle,
die der ZGH für die ZETA Guard Kernkomponenten hat — dieser Punkt wird in der
Praxis regelmäßig übersehen und führt zu einer unüberwachten Zone neben einem gut
überwachten ZETA Guard.

## 10. Offene Punkte und Empfehlungen an den ZETA Guard Hersteller

Aus dem Abgleich dieses Konzepts mit dem aktuellen Stand des Repositories ergeben
sich konkrete Liefergegenstände, die heute noch fehlen:

| # | Lücke | Empfehlung | Priorität |
| --- | --- | --- | --- |
| 1 | NetworkPolicies decken nur die **Egress**-Richtung ab | Default-Deny-Ingress und Ingress-Allowlist ins Chart aufnehmen | **hoch** |
| 2 | `networkPolicy.enabled` ist standardmäßig `false` | Default auf `true`, mit sprechendem Fehler bei fehlenden IP-Blöcken | **hoch** |
| 3 | Ein Entwurf der Referenz-`AuthorizationPolicy`-Ressourcen (aus Chart 1.2.3, Sidecar-Modus) liegt vor, ist aber nicht im Chart; die Kubernetes-Anleitung zeigt nur den Ambient-Modus; Service Mesh in der Komponentenübersicht als `TODO` | Entwurf in das Chart übernehmen, für den Ambient-Modus um Waypoint-Konfiguration ergänzen und mit Abschnitt 4.3.1 abgleichen. Die Wahl des Modus bleibt beim DA (VAU-Bewertung, Abschnitt 4.4); beide Varianten sind zu dokumentieren | **hoch** |
| 4 | Keine Prozess-/FIM-Baselines je Container | Baselines werkzeugneutral dokumentieren, `TracingPolicy`-Referenzen liefern | **hoch** |
| 5 | Keine Referenz-Admission-Policies im Repository | Kyverno-Policy-Set als YAML mitliefern und gegen das Chart testen | **hoch** |
| 6 | cosign-Verifikation nur für das Provisioning-Daten-Image | Signaturen für alle Komponenten-Images nachziehen (Meilenstein bereits vorgesehen) | **hoch** |
| 7 | Kein SIEM-Use-Case-Katalog mit Feldsemantik | Katalog aus Abschnitt 7 als Herstellerartefakt bereitstellen | **mittel** |
| 8 | `readOnlyRootFilesystem: false` bei Infinispan und Provisioning Processor | Auf `true` umstellen oder Ausnahme dokumentiert begründen | **mittel** |
| 9 | `automountServiceAccountToken` nicht durchgängig deaktiviert | Prüfen und als Default deaktivieren, wo kein API-Zugriff nötig | **mittel** |
| 10 | Komponenten-Images werden per Tag und `imagePullPolicy: Always` referenziert | Digest-Pinning für Komponenten-Images in Produktivumgebungen empfehlen und dokumentieren. Das Provisioning-Daten-Image bleibt gemäß A_29743 auf `latest` (Hot-Reload) und ist ausdrücklich auszunehmen | **mittel** |
| 11 | Keine Metrik für OPA-Bundle-Alter | Staleness-Metrik und Schwellwertempfehlung ergänzen | **mittel** |
| 12 | Kein Runbook je Komponente für Sicherheitsvorfälle | Runbooks inkl. Pod-Isolationsverfahren statt Löschen liefern | **mittel** |
| 13 | Egress-Kategorien fehlen für Federation Master (1), Sektoraler IDP (11), Mail Relay (8), Push Gateway (25), GCP STS/IAM der Token-Renewer-CronJobs und JWKS weiterer Authorization Server der Föderation | Kategorien im Chart ergänzen, sonst scheitern Föderation, Authentisierung, TOFU, Benachrichtigung und Token-Erneuerung bei Default-Deny-Egress | **hoch** |
| 14 | Die Architekturübersicht zeigt die als `n. i. B.` geführten Beziehungen nicht (PEP → Authorization Server, PDP Cache, Cluster-Transport, CNPG-Replikation und -Operator, DNS, Telemetriepfad der Kernkomponenten inkl. Syslog/UDP, OCSP/PIP/PoPP, Token-Renewer-CronJobs, Provisioning Processor, Telemetrieausleitung an das Anbieter-SIEM) und enthält die in der Spezifikation beschriebene Kante (28) nicht | Abbildung ergänzen, damit sie als Legende der Matrix vollständig ist | **mittel** |
| 15 | Der mTLS-Endpunkt zur TOFU-E-Mail-Abfrage ist ein Architekturvorschlag ohne Verankerung in Spezifikation und Chart | Entscheidung herbeiführen; bei Umsetzung Konfigurationsschlüssel für Port, Client-CA und zulässige Aufrufer-Zertifikate sowie Referenz-NetworkPolicy ergänzen und Endpunkt auf eigenem Port führen | **mittel** |
| 16 | Für den Annahme-Endpunkt des Telemetriedaten Service (Kante 19) existiert kein Chart-Schlüssel für Receiver-Port, Client-CA und Kennzeichnung eingespeister Ereignisse | Eigenen OTLP-Receiver mit mTLS-Client-Authentisierung und Quellkennzeichnung im Chart vorsehen; Referenz-NetworkPolicy mitliefern | **hoch** |
| 17 | Die Trennung von Sicherheitstelemetrie (nur TI SIEM, A_28960-01) und betrieblicher Telemetrie (Anbieter, A_27260) ist in der Collector-Pipeline nicht als prüfbares Artefakt dokumentiert | Pipeline-Konfiguration je Exporter dokumentieren; je Use-Case aus Abschnitt 7 ausweisen, welche Metrik der Anbieter erhält | **hoch** |
| 18 | Metrik-Scraping (Prometheus → Authserver 9000, PEP 9113, OPA 8181, Collector 8888/8889) ist nicht festgelegt; es umgeht bei direktem Pull den Telemetriedaten Service | Entscheiden: Scraping nur über den Prometheus-Receiver des Collectors oder explizite Matrixzeilen und Policies für direkten Pull | **mittel** |
| 19 | RBAC der Token-Renewer-CronJobs und der CNPG-Pods (API-Zugriff, Ausnahmen von N9) ist nicht als Mindestrechte-Dokumentation ausgewiesen | Rechte je ServiceAccount dokumentieren (nur `get`/`update` auf das jeweilige Token-Secret) | **mittel** |

## 11. Nachweise für die Zulassung

Für die Zulassungsdokumentation des TI 2.0 Dienstes sind je Maßnahme vorzuhalten:

* Manifeste und Helm-Values der produktiven Konfiguration
* Nachweis der PSS-Durchsetzung (Namespace-Labels, Negativtest)
* Policy-Set der Admission-Engine inkl. Ausnahmeliste mit Begründung
* NetworkPolicy-Wirksamkeitsnachweis (Konnektivitäts-Negativtest)
* Kommunikationsmatrix (Abschnitt 4.3.1) im Abgleich mit der ausgerollten Konfiguration, inkl. Protokoll des Negativtests je Zeile der Liste E
* mTLS-Abdeckungsnachweis des Service Mesh, inklusive Begründung des gewählten
  Mesh-Modus mit Bewertung der VAU-Grenze (Abschnitt 4.4)
* `TracingPolicy`-/Falco-Regelwerk und Nachweis der Alarmzustellung ins SIEM
* RBAC-Review-Protokoll und MFA-Nachweis für privilegierte Zugriffe
* Restore-Testprotokoll der PDP Datenbank
* Incident-Response-Runbooks und Protokoll einer durchgeführten Übung
* Nachweis der Telemetrie-Ausleitung an gematik und Anbieter-SIEM

Die Prüfkriterien für ersetzte optionale Komponenten stehen in der
[Prüfliste Optionale Komponenten](Pruefliste_Optionale_Komponenten.md). Zu beachten
ist: Wird eine mitgelieferte Komponente durch eine eigene Lösung ersetzt, geht die
Verantwortung für Betrieb, Sicherheit und Nachweise **vollständig** auf den Anbieter
über.

## Verwandte Dokumentation

* [Sicherheitsanforderungen an den Betreiber des ZETA-Guard](../SicherheitsanforderungenZETAGuardBetreiber.md)
* [Komponentenübersicht](Komponentenuebersicht.md)
* [Prüfliste Optionale Komponenten](Pruefliste_Optionale_Komponenten.md)
* [Referenz des Helm Charts](Referenz_des_Helm_Charts.md)
* [Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md)
* [Wie Sie ein Observability-Backend anschließen](../Anleitungen/Wie_Sie_ein_Observability-Backend_an_ZETA-Guard_anschließen.md)
* [Wie Sie ZETA Guard in Kubernetes konfigurieren](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
* [Wie Sie eine eigene OCI Registry verwenden](../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md)
