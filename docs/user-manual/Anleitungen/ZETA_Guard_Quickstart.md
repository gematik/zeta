# ZETA-Guard-Quickstart

Dieses Dokument beschreibt ein generisches Deployment von ZETA Guard auf einem
Kubernetes-Cluster. Es dient als Referenz- und Einstiegsszenario, um ZETA Guard
reproduzierbar zu installieren, zu konfigurieren und in einen Fachdienst zu
integrieren.

Die beschriebenen Schritte und Konfigurationen sind bewusst umgebungsneutral
gehalten und lassen sich sowohl auf lokale Entwicklungsumgebungen (siehe auch
[Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md](Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md))
als auch auf Cloud- oder On-Premise-Cluster übertragen. Spezifische
Anforderungen an Produktivumgebungen – wie Härtung, Hochverfügbarkeit,
Backup-Strategien, Secret-Management oder mandantenspezifische Anpassungen –
sind nicht Bestandteil dieses Dokuments und müssen projektspezifisch ergänzt
werden.

Der Fokus liegt auf:
- einer funktionalen End-to-End-Installation von ZETA Guard,
- einer reproduzierbaren Konfiguration des PDP mittels Terraform,
- sowie der exemplarischen Anbindung eines Fachdienstes über den PEP.

[TOC]

## Installation

### Benötigte Werkzeuge

* Helm, kubectl und Terraform
* ein Kubernetes-Cluster (für lokale Deployments siehe [Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md](Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md))
    * mit über Stateful Sets provisionierbarem Storage
    * mit eingerichtetem Ingress-Controller (optional, kann über `ingressEnabled` deaktiviert werden)
    * den passenden Kontext in kubectl eingerichtet
* Einen Fachdienst – in diesem Dokument wird dieser als verfügbar
  unter https://testfachdienst angenommen.

### Installationsschritte

Die Installation gliedert sich grob in folgende Schritte

1. Helm aufsetzen
2. PDP konfigurieren
3. PEP konfigurieren

### 1. Helm aufsetzen

Das ZETA Guard Helm Chart ist für Helm 4 konzipiert.

Kopieren Sie nun die Datei [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) in das Arbeitsverzeichnis.
Sie können diese Datei als Konfigurationsvorlage verwenden, umbenennen und
anpassen.

Beim **ersten Deployment** (Initialinstallation) müssen zusätzlich zu den
Admin-Zugangsdaten auch die Werte für `authserver.genesisHash` und
`authserver.smcbHashingPepper` im Values-File gesetzt werden.
Diese Werte sind für die Erstellung der zugehörigen Kubernetes-Secrets
erforderlich und werden bei der ersten Installation zwingend benötigt

Zum Beispiel:

```yaml
authserver:
  admin:
    username: admin-Name
    password: admin-Passwort
  genesisHash: 4841c2142fef441daa6ee6c57db65c011935964b14e94a6c8f5ec0447b83526c
  smcbHashingPepper: 085c1245-1234-5678-95b4-97496bec6182
```

- Im Produktivbetrieb kann das Passwort z.B. via Helm Parameter `--set-file` von
  einem CD Server gesetzt werden.
- Die Werte für `genesisHash` und `smcbHashingPepper` sollten selbst generiert werden. Z.B. mit `openssl rand -hex 16` für den Pepper und einer UUID für den Genesis Hash.
- Nach dem initialen Deployment werden die Secrets im Cluster gespeichert. Bei späteren Upgrades müssen die Werte im Values-File **nicht erneut gesetzt werden**, solange die Secrets im Cluster bestehen bleiben.

Mit dieser [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) können Sie ZETA Guard über
folgendes Kommando installieren:

```shell
    helm upgrade --install zeta-guard oci://europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-helm/zeta-guard:${TAG} -f values-demo.yaml  --rollback-on-failure --timeout 15m
```

### 2. PDP konfigurieren

Der PDP wird über Terraform konfiguriert. Terraform übernimmt dabei die
vollständige Verwaltung der Keycloak-Konfiguration des ZETA-Guard-Realms:
von TLS-Parametern über die Domain-Zuordnung bis hin zur Erstellung der
benötigten PDP-Scopes. Eine manuelle Einrichtung über die Keycloak-Admin-Konsole
ist nicht erforderlich.

Die folgenden Schritte beschreiben, wie Sie die notwendigen Variablen
definieren, das Terraform-Backend initialisieren und anschließend die gewünschte
Konfiguration sicher und reproduzierbar anwenden.

Die relevanten Terraformtemplates finden sich im Unterverzeichnis `terraform`
[hier](https://github.com/gematik/zeta-guard-helm).

#### Betriebsmodi

Terraform kann in zwei Modi betrieben werden, gesteuert über die Terraform-Variable
`use_kubernetes`:

| | **Kubernetes-Modus** (Standard) | **Lokaler Modus** |
|---|---|---|
| **State-Backend** | Kubernetes-Secret im Cluster | Lokale `terraform.tfstate`-Datei |
| **Zugangsdaten** | Aus Kubernetes-Secret `authserver-admin` | Müssen explizit gesetzt werden |
| **Typischer Einsatz** | CI/CD-Pipelines, Cluster-Zugang vorhanden | Lokale Entwicklung, kein Cluster-Zugang nötig |
| **Aktivierung** | `use_kubernetes = true` (Standard) | `use_kubernetes = false` |

#### Voraussetzungen

##### Allgemein (beide Modi)

- Terraform ist installiert (Version kompatibel mit den verwendeten Providern,
  1.5.x aufwärts).
- `curl` und `jq` sind verfügbar (werden vom Policy-Management-Skript benötigt).
- Netzwerkzugang zur Keycloak-Instanz vom ausführenden Rechner.

##### Kubernetes-Modus (Standard)

- Der ZETA-Guard-Cluster läuft und ist über kubectl erreichbar.
- Der PDP (`authserver`) ist im Cluster deployt.
- Keycloak-Admin-Zugangsdaten liegen im Kubernetes-Secret `authserver-admin`
  (wird vom Helm Chart erzeugt).

##### Lokaler Modus

- `TF_VAR_use_kubernetes=false` als Umgebungsvariable oder im Make-Aufruf
  gesetzt.
- Keycloak-Admin-Zugangsdaten explizit bereitgestellt:
    - `TF_VAR_keycloak_password` (erforderlich)
    - `TF_VAR_keycloak_username` (Standard: `admin`)
- Der Terraform-State wird lokal in `terraform.tfstate` gespeichert.

#### Hinweis: Erforderliche Kubernetes-Rechte für Terraform (nur Kubernetes-Modus)

Im Kubernetes-Modus interagiert Terraform direkt mit dem Cluster. Dafür
benötigt der ausführende Service Account entsprechende Berechtigungen im
Ziel-Namespace.

Insbesondere werden folgende Rechte vorausgesetzt:

- Secrets (`apiGroups: [""]`)
  Terraform speichert seinen State als Kubernetes-Secret (z.B.
  `tfstate-default-state`) und benötigt dafür Lese-, Schreib- und Listenrechte.
- Leases (`apiGroups: ["coordination.k8s.io"]`)
  Um parallele Ausführungen des Terraform-Moduls zu verhindern, wird ein Lock
  über Kubernetes-Leases realisiert.

Fehlende Berechtigungen führen typischerweise zu Initialisierungsfehlern beim
Backend (`terraform init`) oder zu Abbrüchen während `apply`.

Im lokalen Modus sind keine Kubernetes-Rechte erforderlich.

#### Terraform Variablen definieren

Unterteilt in drei Kategorien müssen diese gesetzt werden:
- Admin-Rechte, um den PDP zu konfigurieren
- Informationen, um im Cluster zu agieren (nur Kubernetes-Modus)
- Ihre Zeta-Guard-Konfiguration

##### Setzen Sie Ihr Admin-Passwort als Umgebungsvariable, um Terraform den Zugriff auf den PDP zu ermöglichen:

```shell
export TF_VAR_keycloak_password="IhrPasswort"
```

Im Kubernetes-Modus kann das Passwort auch aus dem Kubernetes-Secret `authserver-admin`
gelesen werden; in diesem Fall ist die Umgebungsvariable optional.

##### Weisen Sie Terraform auf die zu verwendende kubeconfig und den Namespace hin (nur Kubernetes-Modus):

Die Datei [demo.backend.hcl](https://github.com/gematik/zeta-guard-helm/blob/main/terraform/authserver/environments/demo.backend.hcl) ermöglicht es Terraform mit dem
Cluster und dem Namespace zu interagieren. Passen Sie die Werte an Ihre Umgebung
an.

```hcl
config_path = "~/.kube/config" # Pfad zur kubeconfig-Datei
namespace   = "zeta-demo"      # Namespace, in dem Zeta-Guard deployt wurde
```

Im lokalen Modus wird diese Datei nicht benötigt (sie wird leer generiert).

##### Die PDP-Konfiguration wird über eine stage-spezifische Datei gesteuert:

```hcl
insecure_tls       = true                          # Aktivieren bei selbst signierten Zertifikaten (optional, Default ist false)
use_kubernetes     = true                          # false für lokalen Modus ohne K8s-Backend
keycloak_url       = "https://example.domain/auth" # Externe URL des Keycloak-Servers
keycloak_namespace = "zeta-demo"                   # Namespace des Authservers im Cluster
pdp_scopes         = ["zero:read", "zero:write"]   # Zusätzliche PDP-Scopes
```

Siehe [demo.tfvars](https://github.com/gematik/zeta-guard-helm/blob/main/terraform/authserver/environments/demo.tfvars).

#### Backend initialisieren

Vor der Konfiguration muss `main.tf` generiert und das Backend initialisiert
werden. Das Skript `generate-main-and-backend.sh` erzeugt aus Templates die
passende `main.tf` und Backend-Konfiguration, abhängig vom gewählten Modus.

##### Kubernetes-Modus (Standard)

```shell
cd terraform/authserver
STAGE=demo NAMESPACE=zeta-demo ./generate-main-and-backend.sh

terraform init \
  -backend-config=environments/demo.backend.hcl \
  -reconfigure
```

##### Lokaler Modus

```shell
cd terraform/authserver
STAGE=demo NAMESPACE=zeta-demo TF_VAR_use_kubernetes=false ./generate-main-and-backend.sh

terraform init \
  -backend-config=environments/demo.backend.hcl \
  -reconfigure
```

> Im Standard Kubernetes-Modus wird `~/.kube/config` als kubeconfig-Pfad verwendet.
> Setzen Sie `TF_VAR_config_path`, falls dieser abweicht.

#### Konfiguration anwenden

Sobald Variablen und Backend korrekt eingerichtet sind, spielen Sie die
Konfiguration ein:

```shell
terraform -chdir=terraform/authserver apply \
  -var-file=../../<values-dir>/demo.tfvars \
  -var "keycloak_password=${TF_VAR_keycloak_password}" \
  -auto-approve
```

Terraform konfiguriert dabei den Keycloak so, dass dieser als PDP eingesetzt
werden kann.

> Die Konfiguration ist beliebig wiederholbar; Terraform sorgt dafür, dass nur
> notwendige Änderungen ausgeführt werden.

##### Optional: Konfiguration vor Anwendung prüfen (Dry-Run):

```shell
terraform -chdir=terraform/authserver plan \
  -var-file=../../<values-dir>/demo.tfvars \
  -var "keycloak_password=${TF_VAR_keycloak_password}"
```

Sollten Sie Ihre Änderungen an dem PDP vorher prüfen wollen, dann können Sie
den obigen Befehl nutzen. Dieser vergleicht Ihre Konfiguration mit dem
bestehenden State. Die angezeigten Unterschiede werden unterteilt in
- _create_ (erstellen)
- _update_ (ändern)
- _delete_ (löschen)
- _replace_ (ersetzen, eine Kombination aus _delete_ und _create_)

### 3. PEP konfigurieren

Die [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) enthält eine PEP-Beispielkonfiguration, welche eine
nginx-Welcome-Seite ausliefert.
Für den Demo-Use-Case können Sie diesen Abschnitt überspringen.

Falls der PEP an einen Fachdienst angeschlossen werden soll, geht dies wie
folgt:

Der PEP ist auf Basis von nginx umgesetzt. In
der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) ist im Feld
`pepproxy.nginxConf.fileContent` der Dateiinhalt einer nginx-Konfiguration
(.../nginx.conf) anzugeben.
Dort sind in der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) die folgenden Direktiven
auf die Konfiguration des PDP abzustimmen:

* `pep_issuer`

  Die Realm URL des PDP. Sollte z.B. wie folgt aussehen:
  `https://public-name-of-keycloak-here/auth/realms/zeta-guard`

* `proxy_pass`

  Das abzusichernde Ziel.
  In der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) ist das Ausliefern des http-Verzeichnisses via
  `root ...` eingerichtet.
  Der Fachdienst ist in der Regel über die nginx-Standarddirektive `proxy_pass`
  anzubinden.
  In der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) wäre dann die `root`-Direktive zu ersetzen, z.B. durch
  `proxy_pass https://testfachdienst/`

Anmerkung: Die nginx-Direktive `pep on;` schaltet das PEP-spezifische Verhalten
auf dem entsprechenden Pfad ein. Eine genauere Referenz zur PEP-Konfiguration
findet sich [hier](../Referenzen/Konfiguration_des_PEP_Http_Proxy.md).

Nachdem Sie die [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml) entsprechend angepasst haben, können Sie Ihre
Änderungen über folgendes Helm-Kommando ausrollen:

```shell
    helm upgrade --install zeta-guard zeta/zeta-guard -f values-demo.yaml --rollback-on-failure --timeout 15m
```

Nun haben Sie den ZETA-Guard eingerichtet und ein Zugriff über den
ZETA-Testclient und das ZETA-Client-SDK ist möglich.

Der ZETA Guard ist nun fertig installiert. Für einen Test bietet es sich an, den
[Testclient](Wie_Sie_den_ZETA_Demo_client_ausführen.md) oder alternativ
[Testdriver](Wie_Sie_den_Testdriver_bauen.md) aufzusetzen.
