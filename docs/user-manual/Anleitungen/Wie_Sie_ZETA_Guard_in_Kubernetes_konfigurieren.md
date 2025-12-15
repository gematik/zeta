# Wie Sie ZETA-Guard in einem Kubernetes-Cluster installieren und konfigurieren

---

Status: In Arbeit

Zielgruppe: Systemadministratoren der Anbieter

_Inhalt: Beschreibung der erforderlichen Hardware und Software, mögliche
Betriebssysteme und -Versionen, vorausgesetzte Software-Umgebung wie etwa
Standardbibliotheken und Laufzeitsysteme. Erläuterung der Prozeduren zur
Installation, außerdem zur Pflege (Updates) und De-Installation, bei kleinen
Produkten eine Readme-Datei. Zielgruppe sind Administratoren beim Anwender, die
die Software nicht zwangsläufig unmittelbar selbst nutzen müssen._

---

[TOC]

## Überblick

![Abbildung Zero Trust-Architektur der TI 2.0](../assets/images/depl_sc/image-20251121-091130.png)

## Voraussetzungen

* ein Kubernetes-Cluster
    * mindestens in Version 1.32 (entspr. OpenShift 4.19 oder neuer)
    * in dem sich _Resource Server_ und _Application Authorization Backend_
      befinden
    * mit einem Ingress-Controller
    * mit Zugang zu einer anbietereigenen Container Registry
        * für den Testbetrieb kann in Absprache mit der gematik direkt die
          Container Registry der gematik verwendet werden
    * Persistent Volumes mit AccessMode `ReadWriteOnce` müssen verfügbar sein
    * Netzwerkzugang zu diversen externen Diensten
      (siehe [Egress konfigurieren](#2-egress-konfigurieren))
    * eine geeignete Imagesignaturprüfung z.B. via Kyverno (signierte Images
      kommen in späterem Meilenstein)
* eine lokale, cachende OCI Registry
* alle Dienste aus der Liste
  der [Abhängigkeiten unten](#abhängigkeiten--erforderliche-konfiguration)
* einen [OpenTelemetry-Collector](https://opentelemetry.io/docs/collector/)

Optionale Voraussetzungen:

* ein Ingress Controller (alternativ zum ZETA eigenen)
* ein geeignetes Service Mesh mit Verschlüsselung und wechselseitiger
  Authentisierung (alternativ zum ZETA eigenen, welches in einem späteren
  Meilenstein kommt)

## Überblick über die Konfiguration des ZETA Guard

Zentraler Dreh- und Angelpunkt der Konfiguration und auch Installation des ZETA
Guard ist das [ZETA Guard Helm Chart][ZGchrtHelm]. Zusätzlich relevant sind die
[PDP Terraform Templates][ZGchrtTf], welche für diverse Konfiguration des PDP
relevant sind und in dieser Hinsicht das Helm Chart begleitet. Diese beiden
Konfigurationswerkzeuge gehören praktisch mit zum ZETA Guard und werden
ebenfalls in Updates des ZETA Guard gepflegt.

Nicht zu verwechseln mit den [PDP Terraform Templates][ZGchrtTf] sind die
optionalen [Terraform Templates][ZGclusterTf] zum beispielhaften Aufsetzen eines
geeigneten Kubernetes Clusters.

### Empfehlungen für das Konfigurationsmanagement

* Bauen Sie ihr eigenes Helm Chart, welches das ZETA Guard Helm Chart als
  Subchart nutzt. So können Sie Anpassungen an Ihre eigenen Bedürfnisse und
  Infrastruktur konsistent managen.
* Setzen Sie einen CD Server in Verbindung mit einem Versionskontrollsystem für
  die Konfigurationsdateien ein (→ GitOps). Der ZETA Guard beinhaltet zukünftig
  als optionale Komponente einen ArgoCD.

## Vorgehen bei der Installation

Letztlich besteht die Installation aus den 2 Schritten `helm upgrade --install`
und `terraform apply`, wie im [Quickstart](ZETA_Guard_Quickstart_fuer_lokales_deployment.md) beschrieben.
Damit sind dann alle Komponenten des ZETA Guard installiert.

Im Folgenden soll auf die Konfiguration der einzelnen Komponenten etwas mehr
im Detail eingegangen werden. Ergänzend dazu gibt es die
[Referenzdokumente](../Referenzen/Referenzen.md).

## Übersicht zu den wichtigsten Konfigurationsparametern der einzelnen Komponenten

### 1. Ingress-Controller und Ingress konfigurieren

In dem Cluster muss ein [Ingress-Controller][K8s Ingress Controllers]
installiert sein und erlaubter [Ingress][K8s Ingress] definiert werden.
Das ZETA Guard Helm Chart beinhaltet einen optionalen Ingress Controller. Über
die values kann dieser an- bzw. abgewählt werden
(`ingress_controller.enabled: false`).

Der eingesetzte Ingress Controller muss die Kubernetes APIs für
[Ingresses](https://kubernetes.io/docs/concepts/services-networking/ingress/)
und [Gateways](https://kubernetes.io/docs/concepts/services-networking/gateway/)
unterstützen.

Die Verwaltung der TLS Zertifikate obliegt dem Anbieter und erfolgt in der Regel
über Kubernetes Secrets oder eine HSM Anbindung.

TODO: Eine genauere Beschreibung zur Konfiguration des ZETA Guard eigenen
Ingress Controllers folgt.

### 2. Egress konfigurieren

Egresses werden über Kubernetes [Network-Policies][K8s Network Policies]
kontrolliert. Das ZETA Guard Helm Chart wird einige universell für alle ZETA
Guards benötigte Network Policies beinhalten. Weitere Fachdienstabhängige
Network Policies, z.B. für die Kommunikation mit einem anderen Fachdienst und
dessen ZETA Guard, obliegen dem Anbieter.

Bekannte, valide Egress Ziele außerhalb des Clusters sind insbesondere:

* TODO: Momentan werden manche Images (z.B. OPA) noch von docker.io bezogen.
  Dies entfällt mit Meilenstein 3.
* Aufrufende Clients (Responses)
* TI Dienste
    * OCSP Responder der TI TSL (! d.h. der Responder im Internet nicht der im
      TI 1.0 Netz)
    * TI-Monitoring
    * TI-SIEM
    * Federation Master
    * Federated IDP bzw. Sektorale IdPs
* ZETA spezifische TI Dienste
    * ZETA Container-Registry
    * ZETA PIP & Service
* anbietereigene Dienste
    * Dienstanbieter-Monitoring
    * Dienstanbieter-SIEM
    * Diensthersteller-Monitoring
* weitere Dienste
    * Clientsystem Notification Service(s) – Apple Push Notifications, Firebase
    * Email Confirmation-Code – Mailversand
    * im Testbetrieb zu dockerhub

### 3. Management Service (ArgoCD) installieren und konfigurieren

Die Verwendung des Management Service ist optional und das ZETA Guard Helm Chart
beinhaltet einen optionalen Ingress Controller. Über die values kann dieser an-
bzw. abgewählt werden (`management_service.enabled: true`).

* _Kommt mit späterem Meilenstein_
* _To-Do: Sidecar Container mit OpenTelemetry Collector_
* _Ggf. mit Zugang zur UI für Administratoren einrichten_

#### Verwandte Dokumentation

* [ArgoCD – Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
* [ArgoCD – Declarative Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
* [ArgoCD – Metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)

### 4. Telemetriedaten Service (OpenTelemetry Collector) konfigurieren

Zunächst erfassen Komponenten-spezifische Collector-Instanzen Telemetriedaten.
Ein zentraler Collector – das Telemetry-Gateway – bündelt und filtert diese,
bevor sie an die Monitoring- und SIEM-Dienste der TI weitergeleitet werden.

Um eigene Observability-Backends anzuschließen, empfehlen wir einen eigenen
OpenTelemetry-Collector einzurichten, der den Fanout an Ihre
Observability-Backends (wie etwa Prometheus, OpenSearch und Jaeger) vornimmt.
Ferner empfehlen wir Collectoren über das OpenTelemetry Protocol (OTELP)
kommunizieren zu lassen, da es alle Signalarten (Logs, Metriken, und Traces)
übertragen kann und der dafür notwendige Receiver in allen offiziellen
Distributionen enthalten ist.

Der Telemetriedaten Service ist Teil des `zeta-guard`-Charts, und ist
standardmäßig eingeschaltet – benötigt jedoch eine valide Zieladresse für
seinen [OTELP-Exporter](https://github.com/open-telemetry/opentelemetry-collector/blob/main/exporter/otlpexporter/README.md).
Sie können die Konfiguration des Exporters wie folgt überschreiben:

```yaml
telemetry-gateway:
    config:
        exporters:
            otlp/observability-backends:
                endpoint: <Adresse Ihres OTELP-Receivers>
```

Bitte beachten Sie, dass `telemetry-gateway.config` ein direktes Fenster in
die [Konfiguration des Collectors](https://opentelemetry.io/docs/collector/configuration/)
ist, und Sie bei Bedarf weitere Exporter hinzufügen und existierende
deaktivieren können:

```yaml
telemetry-gateway:
    config:
        exporters:
            otlp/observability-backends:
                endpoint: <Adresse Ihres OTELP-Receivers>
                tls: ...
            otlp/gematik:
                endpoint: <Adresse des gematik-OTELP-Receivers>
                tls: ...
        service:
            pipelines:
                logs:
                    exporters: [ debug, otlp/observability-backends, otlp/gematik ]
                metrics:
                    exporters: [ debug, otlp/observability-backends, otlp/gematik ]
                traces:
                    exporters: [ debug, otlp/observability-backends, otlp/gematik ]
```

Das Telemetry-Gateway verwendet die Distribution _opentelemetry-collector-k8s_
(latest). [Hier](https://github.com/open-telemetry/opentelemetry-collector-releases/blob/main/distributions/otelcol-k8s/manifest.yaml)
finden sie das Manifest mit allen Exportern, die Sie verwenden können.

* _To-do: als Kubernetes Sidecar Container für jede Komponente_
* _To-do: Telemetriedatentransfer an gematik einrichten_
* _To-do: Telemetriedatentransfer mit TLS und Authentifizierung absichern_

#### Verwandte Dokumentation

* [OpenTelemetry with Kubernetes][OTelK8s]
* [OpenTelemetry Collector Chart][OTelColChrt]
* [OpenTelemetry – Collector – Configuration][OTelColCnfg]
* ggf. [OpenTelemetry Operator for Kubernetes][OTelO]
* ggf. [OpenTelemetry Operator Chart][OTelOChrt]

#### Abhängigkeiten / erforderliche Konfiguration

* Muss wahrscheinlich die Adressen der Open-Telemetrie-Endpunkte kennen, von
  denen er Telemetrie-Daten einsammeln soll
* Muss ggf. die Adresse des nächsten Telemetrie-Dienstes in der Kette kennen

### 5. Notification Service konfigurieren

* _Kommt erst in Umsetzungsstufe 2_
* _To-do: Sidecar Container mit OpenTelemetry Collector_

#### Abhängigkeiten / erforderliche Konfiguration

* APN-Konfiguration (Apple Push Notification)
* Firebase-Konfiguration (Android Push Notification)

### 6. Policy Decision Point konfigurieren

#### 6.1 PDP Datenbank (PostgreSQL) installieren und konfigurieren

Keycloak benötigt eine [PostgreSQL-Datenbank][Pstgrs17] die aktuell in Form des
[Zalandos Postgres-Operator][PstgrsOp] installiert werden sollte. (Für größere
Deploymentszenarien mit Multicluster ggf. abweichend).

Als Anschauungsbeispiel kann [das entsprechende Terraform Template ][ZTfPSTGRS]
herangezogen werden. Zukünftig wird dieser Teil ggf. noch in das ZETA Guard
Helm Chart integriert.

Die Datenbank wird als Active-Passive eingesetzt. Durch den gut abgestimmten
Einsatz eines verteilten 2nd level Datenbankcaches im PDP skaliert dies trotzdem
gut.

_To-do: Sidecar Container mit OpenTelemetry Collector_

#### 6.2 Policy Engine (OPA) konfigurieren

Jede OPA-Instanz muss Policys vom PIP abfragen und Metriken für seinen
OpenTelemetry Collector bereitstellen.

Zur Veranschaulichung dienen Deployment- und Service-Definitionen in
folgendem [Helm-Chart][ZGchrtOPA] als Beispiel.

OPA kann horizontal skaliert werden (-> helm values).

* _To-do: Skalierung

##### Verwandte Dokumentation

* [How to Deploy OPA][OPAdplymnt]
* [Deploying OPA on Kubernetes][OPAdplymntK8s]
* [OPA – Configuration][OPAcnfg]
    * [OPA – Monitoring – OpenTelemetry][OPAmntrg]
    * [OPA – Security][OPAscrty]
    * [OPA – Privacy][OPAprvcy]

##### Abhängigkeiten / erforderliche Konfiguration

* PIP stellt Policy Bundles und Bundle Signer Zertifikate bereit

#### 6.3 Authorization Service (Keycloak) konfigurieren

Keycloak muss mit seiner Datenbank und seinem OPA verbunden sein, einen
eigenen Open Telemetry Collector besitzen und von außerhalb des Clusters
erreichbar sein.

Die Installation erfolgt über den Helm-Chart. Zusätzlich zur Konfiguration im
Helm Chart erfolgt ein großer Teil der Konfiguration zur Laufzeit des deployten
Keycloak und wird mittels Terraform vorgenommen.

Der Authorization Service kann horizontal skaliert werden (→ helm values).
Ab 4 Knoten ist ein Tuning des Keycloak internen Infinispan Caches angeraten.

* _To-do: Sidecar Container mit OpenTelemetry Collector_

##### Abhängigkeiten / erforderliche Konfiguration

* Der externe Hostname muss konfiguriert werden:
    * in helm via `authserver.hostname=auth.example.com.internal`
    * in Terraform via
        * `keycloak_url = "https://zeta-dev.westeurope.cloudapp.azure.com/auth"`

###### Datenbankverbindung und Benutzer-Credentials für die PDP Datenbank

Das Helm Chart unterstützt einen Datenbankmodus für Testsetups mit einer
Postgres über ein Legacy Bitnami Helm Chart und einen produktivtauglichen
Modus aufbauend auf einem existierenden [Zalando Postgres Operator][PstgrsOp].

Für die Verwendung des Operator ist `databaseMode: operator` als helm value zu
setzen. Weitere Konfiguration ist dann nicht erforderlich, es wird dann über
das Helm Chart vom Operator eine Datenbank angefordert und der Keycloak passend
konfiguriert.

TODO: späterer Meilenstein: Andere Datenbank via Helm Values konfigurierbar
machen. Als Basis dient dann Folgendes:

Die Konfiguration einer Datenbankverbindung für Keycloak wird
in [dieser Anleitung](https://www.keycloak.org/server/db#_configuring_a_database)
erklärt. Die für die Datenbankverbindung relevanten Umgebungsvariablen am
Keycloak sind:

* `KC_DB` (Standardwert `postgres`)
* `KC_DB_URL`: (Standardwert `jdbc:postgresql://keycloak-db:5432/keycloak`)
* `KC_DB_USERNAME`: (Technischer Datenbank-User)
* `KC_DB_PASSWORD`: (DB-Passwort)

##### Verwandte Dokumentation

* [Keycloak – Kubernetes][KyclkK8s]
* [Configuring Keycloak][KyclkCnfg]
* [Keycloak – Configuring the database][KyclkDtbs]
* [Keycloak – Tracking instance status with health checks][KyclkHlth]

### 7. Policy Enforcement Point (nginx) konfigurieren

Zur Veranschaulichung der Installation und Konfiguration des HTTP-Proxys eignet
sich die Deployment-Definition in [diesem Helm-Chart][ZGchrtNGNX].

Für die korrekte Funktion des PEP sind folgende Konfigurationswerte
entscheidend:

* Issuer URL des Authorization Server `pepproxy.nginxConf.pepIssuer`. Diese
  ergibt sich normalerweise aus dem öffentlichen Hostnamen des Authorization
  Server nach dem Muster `https://<authserver_name>/auth/realms/zeta-guard`
* Öffentliche URL des PEP. Diese fließt in das Well-Known Discovery Dokument im
  Value `pepproxy.wellKnownBase` ein nach folgendem Muster: `https://<pep_name>`
* Konfiguration des Fachdienst Resource Server über den Helm Value
  `pepproxy.nginxConf.locations`. Dieser wird
  mit [nginx location Blöcken](https://nginx.org/en/docs/http/ngx_http_core_module.html#location)
  welche `proxy_pass` auf den Fachdienst Resource Server nutzen eingerichtet.
  Wichtig sind hierbei in den Locations folgende 2 Direktiven:
    * `pep on;` damit sich der HTTP Proxy hier wie ein PEP verhält
    * `pep_require_aud https://<pep_name> <other_audiences_here>;` zur
      Validierung der geforderten und mit der gematik abgestimmten Audiences
      (die gematik muss diese in zentrale Policys für den OPA integrieren).
    * Eventuelle Konfiguration für WebSockets findet hier mit nginx
      Standardmethoden statt.
    * TODO: Beschreibung von ASL
        * ASL Zertifikate werden via Kubernetes Secrets bereitgestellt oder in
          der VAU via HSM verfügbar gemacht

* _kommt noch_
    * _To-do: Horizontale Skalierung via Helm Values verfügbar machen_
    * _To-do: Sidecar Container mit OpenTelemetry Collector_

### 7. Servie Mesh konfigurieren

TODO: Das Service Mesh _kommt in Meilenstein 3_. Hier sei trotzdem schon
angedeutet:

Die Verwendung des Management Service ist optional und das ZETA Guard Helm Chart
beinhaltet einen optionalen Ingress Controller. Über die values kann dieser an-
bzw. abgewählt werden (`service_mesh.enabled: true`). Optional bedeutet hier,
dass bei Abwahl des ZETA Guard Service Mesh ein eigenes Service Mesh eingesetzt
werden muss, welches insbesondere Verschlüsselung und wechselseitige
Authentisierung des Clusterinternen Traffics umsetzt.

## Querschnittliche Konzepte

### Verwenden einer eigenen OCI Registry

Das ZETA Guard Helm Chart verweist standardmäßig auf Images bei den Upstream
Registries. Für den produktiven Einsatz ist aus Gründen der Verfügbarkeit und
Trafficvermeidung eine puffernde lokale Registry vom Anbieter zu nutzen.

Damit dann die Images von dort bezogen werden, muss dies über Helm Values
entsprechend gesteuert werden:

* allgemeine Konfiguration
    * `global.registry_host` Name der Registry, z.B.
      `my.registry.corp.internal:443`
    * `global.image_pull_secret` (optional) Name eines Image Pull Secrets.
      Sofern zum Pullen ein Secret erforderlich ist, muss diese als Image Pull
      Secret in Kubernetes eingerichtet werden. Der Name dieses Secrets wird
      dann hier konfiguriert.
* Authorization Server
    * `authserver.image.repository` Name des authserver Images auf der Registry
    * `authserver.image.tag` Zu verwendender Image Tag
* PEP Http Proxy
    * `pepproxy.image.repository` Name des authserver Images auf der Registry
    * `pepproxy.image.tag` Zu verwendender Image Tag
* TODO mit späterem Meilenstein weitere Images

[K8s Ingress]: https://kubernetes.io/docs/concepts/services-networking/ingress/

[K8s Ingress Controllers]: https://kubernetes.io/docs/concepts/services-networking/ingress-controllers/

[K8s Network Policies]: https://kubernetes.io/docs/concepts/services-networking/network-policies/

[KyclkCnfg]:    https://www.keycloak.org/server/configuration

[KyclkDtbs]:    https://www.keycloak.org/server/db

[KyclkHlth]:    https://www.keycloak.org/observability/health

[KyclkK8s]:     https://www.keycloak.org/getting-started/getting-started-kube

[OPAcnfg]:          https://www.openpolicyagent.org/docs/configuration

[OPAdplymnt]:       https://www.openpolicyagent.org/docs/deploy

[OPAdplymntK8s]:    https://www.openpolicyagent.org/docs/deploy/k8s

[OPAmntrg]:         https://www.openpolicyagent.org/docs/monitoring#opentelemetry

[OPAprvcy]:         https://www.openpolicyagent.org/docs/privacy

[OPAscrty]:         https://www.openpolicyagent.org/docs/security

[OTelColChrt]:  https://opentelemetry.io/docs/platforms/kubernetes/helm/collector/

[OTelColCnfg]:  https://opentelemetry.io/docs/collector/configuration/

[OTelK8s]:      https://opentelemetry.io/docs/platforms/kubernetes/

[OTelO]:        https://opentelemetry.io/docs/platforms/kubernetes/operator/

[OTelOChrt]:    https://opentelemetry.io/docs/platforms/kubernetes/helm/operator/

[Pstgrs17]: https://www.postgresql.org/docs/17/admin.html

[PstgrsOp]: https://postgres-operator.readthedocs.io/en/latest/

[ZGchrtNGNX]:   https://github.com/gematik/zeta-guard-helm/tree/main/charts/zeta-guard/templates/pep-proxy.yaml

[ZGchrtOPA]:    https://github.com/gematik/zeta-guard-helm/tree/main/charts/zeta-guard/templates/opa-deployment.yaml

[ZGchrtHelm]:   https://github.com/gematik/zeta-guard-helm/tree/main/charts/zeta-guard

[ZGchrtTf]:     https://github.com/gematik/zeta-guard-helm/tree/main/terraform

[ZTfPSTGRS]:    https://github.com/gematik/zeta-guard-terraform/blob/main/gematik-azure/showcase-stage/postgres-operator.tf

[ZGclusterTf]:    https://github.com/gematik/zeta-guard-terraform/
