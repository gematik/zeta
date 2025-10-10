# Wie Sie ZETA-Guard in einem Kubernetes-Cluster installieren und konfigurieren

---

Status: Grob-Entwurf

Zielgruppe: Systemadministratoren

_Inhalt: Beschreibung der erforderlichen Hardware und Software, mögliche
Betriebssysteme
und -Versionen, vorausgesetzte
Software-Umgebung wie etwa Standardbibliotheken und Laufzeitsysteme. Erläuterung
der Prozeduren zur Installation,
außerdem zur Pflege (Updates) und De-Installation, bei kleinen Produkten eine
Readme-Datei. Zielgruppe sind
Administratoren beim Anwender, die die Software nicht zwangsläufig unmittelbar
selbst nutzen müssen._

---

[TOC]

## Überblick

_To-do: ein Verteilungsdiagramm wäre schöner_

![Abbildung Zero Trust-Architektur der TI 2.0][ZETA]

## Voraussetzungen

* ein Kubernetes-Cluster
    * in dem sich _Resource Server_ und _Application Authorization Backend_
      befinden
    * mit einem Ingress-Controller
    * mit Zugang zu den relevanten Container-Registries
* alle Dienste aus der Liste der Abhängigkeiten unten

* _To-do: sammle Voraussetzungen der einzelnen Bausteine_

## Vorgehen

### 1. Ingress-Controller installieren und Ingress konfigurieren

In dem Cluster muss ein [Ingress-Controller][K8s Ingress Controllers]
installiert sein und erlaubter [Ingress][K8s Ingress] definiert werden.
Nur der HTTP-Proxy des Enforcement-Points, der Authorization-Server des
Decision-Points und der Notification Service dürfen von außerhalb des Clusters
erreichbar sein.

Als Vorlage für einen Ingress mit einem nginx-basierten Ingress-Controller
können Sie [diese Ingress-Definition][ZGchrtNGRSS] verwenden.

### 2. Egress konfigurieren

Richten Sie für den Cluster [Network-Policys][K8s Network Policies] ein, die
unerwarteten Netzwerkverkehr aus dem Cluster unterbinden.

Bekannte, valide Ziele außerhalb des Clusters sind

* Clientsystem Notification Service(s) – Apple Push Notifications, Firebase
* Email Confirmation-Code – Mailversand
* Federated IDP
* Dienstanbieter-Monitoring
* Dienstanbieter-SIEM
* Diensthersteller-Monitoring
* TI-Monitoring
* TI-SIEM
* ZETA Container-Registry
* ZETA Git Repository
* ZETA PAP Service
* ZETA PIP Service

### 3. Management Service (ArgoCD) installieren und konfigurieren

* _Kommt in Meilenstein 2_
* _To-Do: Sidecar Container mit OpenTelemetry Collector_
* _Ggf. mit Zugang zur UI für Administratoren einrichten_

#### Verwandte Dokumentation

* [ArgoCD – Installation](https://argo-cd.readthedocs.io/en/stable/operator-manual/installation/)
* [ArgoCD – Declarative Setup](https://argo-cd.readthedocs.io/en/stable/operator-manual/declarative-setup/)
* [ArgoCD – Metrics](https://argo-cd.readthedocs.io/en/stable/operator-manual/metrics/)

#### Abhängigkeiten / erforderliche Konfiguration

* Adresse von und Credentials für ZETA Container Registry
* Adresse von und Credentials für ZETA Git Repository
* Adresse von und Credentials für `kube-apiserver` zur Verwaltung des
  Kubernetes-Clusters

### 4. Telemetriedaten Service (OpenTelemetry Collector) installieren und konfigurieren

Zunächst erfassen Komponenten-spezifische Collector-Instanzen Telemetriedaten.
Ein zentraler Collector bündelt und filtert diese, bevor sie an die Monitoring-
und SIEM-Dienste der TI weitergeleitet werden.

* _To-do_
* _To-do: als Kubernetes Sidecar Container für jede Komponente_

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

### 5. Notification Service (TI-M Notification Service) installieren und konfigurieren

* _Kommt in Meilenstein 2_
* _To-do: Sidecar Container mit OpenTelemetry Collector_

#### Abhängigkeiten / erforderliche Konfiguration

* APN-Konfiguration (Apple Push Notification)
* Firebase-Konfiguration (Android Push Notification)

### 6. Policy Decision Point installieren und konfigurieren

#### 6.1 PDP Datenbank (PostgreSQL) installieren und konfigurieren

Für Keycloak müssen Sie eine [PostgreSQL-Datenbank][Pstgrs17] installieren und
konfigurieren.
Hierfür können Sie beispielsweise [Zalandos Postgres-Operator][PstgrsOp] verwenden.

Als Anschauungsbeispiel kann [dieser Helm-Chart][ZGchrtPSTGRS] herangezogen
werden.

_To-do: Sidecar Container mit OpenTelemetry Collector_

#### 6.2 Policy Engine (OPA) installieren und konfigurieren

Jede OPA-Instanz muss Policys vom PIP abfragen und Metriken für seinen
OpenTelemetry Collector bereitstellen.

Zur Veranschaulichung dienen Deployment- und Service-Definitionen in
folgendem [Helm-Chart][ZGchrtOPA] als Beispiel.

* _To-do: PIP – kommt in Meilenstein 2_
* _To-do: Sidecar Container mit OpenTelemetry Collector_

##### Verwandte Dokumentation

* [How to Deploy OPA][OPAdplymnt]
* [Deploying OPA on Kubernetes][OPAdplymntK8s]
* [OPA – Configuration][OPAcnfg]
    * [OPA – Monitoring – OpenTelemetry][OPAmntrg]
    * [OPA – Security][OPAscrty]
    * [OPA – Privacy][OPAprvcy]

##### Abhängigkeiten / erforderliche Konfiguration

* PIP stellt Policy Bundles und Bundle Signer Zertifikate bereit

#### 6.3 Authorization Service (Keycloak) installieren und konfigurieren

Keycloak muss mit seiner Datenbank und seinem OPA verbunden sein, einen
eigenen Open Telemetry Collector besitzen und von außerhalb des Clusters
erreichbar sein.

Als Beispiel können Sie die Deployment- und-Service-Definitionen in
folgendem [Helm-Charts][ZGchrtKYCLK] verwenden.

Die Installation erfolgt über den Helm-Chart, während die eigentliche
Konfiguration des deployten Keycloak mittels Terraform vorgenommen wird.

* _To-do: OPA-Verbindung, späterer Meilenstein?_
* _To-do: Sidecar Container mit OpenTelemetry Collector_

##### Abhängigkeiten / erforderliche Konfiguration

###### Datenbankverbindung und Benutzer-Credentials für die PDP Datenbank

Die Konfiguration einer Datenbankverbindung für Keycloak wird
in [dieser Anleitung](https://www.keycloak.org/server/db#_configuring_a_database)
erklärt.
Die für die Datenbankverbindung relevanten Umgebungsvariablen lauten:

* `KC_DB` (Standardwert `postgres`)
* `KC_DB_URL`: (Standardwert `jdbc:postgresql://keycloak-db:5432/keycloak`)
* `KC_DB_USERNAME`: (Technischer Datenbank-User)
* `KC_DB_PASSWORD`: (DB-Passwort)

###### Adresse der Policy Engine (OPA)

##### Verwandte Dokumentation

* [Keycloak – Kubernetes][KyclkK8s]
* [Configuring Keycloak][KyclkCnfg]
* [Keycloak – Configuring the database][KyclkDtbs]
* [Keycloak – Tracking instance status with health checks][KyclkHlth]

### 7. Policy Enforcement Point einrichten

#### 7.1 PEP Datenbank (Infinispan) einrichten

* _Kommt in Meilenstein 2_
* _To-do: Sidecar Container mit OpenTelemetry Collector_

#### 7.2 HTTP Proxy (nginx) installieren und konfigurieren

Zur Veranschaulichung der Installation und Konfiguration des HTTP-Proxys eignet
sich die Deployment-Definition in [diesem Helm-Chart][ZGchrtNGNX].

* _Kommt in Meilenstein 2:_
    * _To-do: Zugang zur PEP-Datenbank_
    * _To-do: Zugang zur PDP-Datenbank (oder zum Authorization Server?)_
    * _To-do: Adresse des Resource Servers_
    * _To-do: Sidecar Container mit OpenTelemetry Collector_

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


[ZETA]: ../assets/images/TI20_Zero_Trust_Architektur.svg

[ZGchrtKYCLK]:  charts/zeta-guard

[ZGchrtNGNX]:   zeta-guard/templates/pep-proxy.yaml

[ZGchrtNGRSS]:  charts/zeta-guard/templates/ingress.yaml

[ZGchrtOPA]:    charts/zeta-guard

[ZGchrtPSTGRS]: charts/zeta-guard/templates/postgres-operator-cluster.yaml
