# ZETA-Guard-Quickstart

[TOC]

## Installation

### Benötigte Werkzeuge

* Helm, kubectl und Terraform
* ein Kubernetes-Cluster (für lokale Deployments bietet sich [KIND](https://kind.sigs.k8s.io/) an)
    * mit über Stateful Sets provisionierbarem Storage
    * mit eingerichtetem Ingress-Controller _(zukünftig optionaler Bestandteil
      des ZETA Guard)_
    * lokal den passenden Kontext in kubectl eingerichtet
* Einen Fachdienst – in diesem Dokument wird dieser als verfügbar
  unter https://testfachdienst angenommen.

### Installationsschritte

Die Installation gliedert sich grob in folgende Schritte

1. Helm aufsetzen
2. PDP konfigurieren
3. PEP konfigurieren

#### 1. Helm aufsetzen

Das ZETA Guard Helm Chart ist für Helm 3 konzipiert.

Kopieren Sie nun die Datei [values-demo.yaml](values-demo.yaml) in das Arbeitsverzeichnis.
Sie können diese Datei als Konfigurationsvorlage verwenden, umbenennen und
anpassen.

Unter `authserver` können Sie Name und Passwort des Admin-Accounts für den PDP
festlegen.
Zum Beispiel:

```yaml
authserver:
  admin:
    username: admin-Name
    password: admin-Passwort
```

Im Produktivbetrieb kann das Passwort z.B. via Helm Parameter `--set-file` von
einem CD Server gesetzt werden.

Mit dieser [values-demo.yaml](values-demo.yaml) können Sie ZETA Guard über
folgendes Kommando installieren:

```shell
    helm upgrade --install zeta-guard oci://europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-dcr/zeta-guard-helm/zeta-guard:0.1.2 -f values-demo.yaml --wait --atomic
```

#### 2. PDP konfigurieren

Der PDP wird über Terraform konfiguriert. Terraform übernimmt dabei die
vollständige Verwaltung der Keycloak-Konfiguration des ZETA-Guard-Realms:
von TLS-Parametern über die Domain-Zuordnung bis hin zur Erstellung der
benötigten PDP-Scopes. Eine manuelle Einrichtung über die Keycloak-Admin-Konsole
ist nicht erforderlich.

Die folgenden Schritte beschreiben, wie Sie die notwendigen Variablen
definieren, das Terraform-Backend initialisieren und anschließend die gewünschte
Konfiguration sicher und reproduzierbar anwenden.

Die relevanten Terraform Templates finden sich im Unterverzeichnis `terraform`
[hier](https://github.com/gematik/zeta-guard-helm).

##### Voraussetzungen

Stellen Sie sicher, dass folgende Voraussetzungen erfüllt sind:

- Der ZETA-Guard-Cluster läuft und ist über kubectl erreichbar.
- Terraform ist installiert und befindet sich in einer Version, die mit den
benötigten Providern kompatibel ist (1.5.x aufwärts).
- Der PDP (`authserver`) ist im Cluster deployt.
- Sie verfügen über die Keycloak-Admin-Zugangsdaten, sofern diese nicht im
Cluster-Secret hinterlegt sind (siehe Abschnitt
[Helm aufsetzen](#1-helm-aufsetzen)).

##### Terraform Variablen definieren

Unterteilt in drei Kategorien müssen diese gesetzt werden:
- Admin-Rechte, um den PDP zu konfigurieren
- Informationen, um im Cluster zu agieren
- Ihre Zeta-Guard-Konfiguration

###### Setzen Sie ihr Admin-Passwort als Umgebungsvariablen, um Terraform den Zugriff auf den PDP zu ermöglichen:

```shell
export TF_VAR_keycloak_password="IhrPasswort"
```

###### Weisen Sie Terraform auf die zu verwendende kubeconfig und den Namespace hin:

Die Datei [demo.backend.hcl](demo.backend.hcl) ermöglicht es Terraform mit dem
Cluster und dem Namespace zu interagieren. Passen Sie die Werte an Ihre Umgebung
an.

```hcl
config_path = "~/.kube/config" # Pfad zur kubeconfig-Datei
namespace   = "zeta-demo"      # Namespace, in dem Zeta-Guard deployt wurde
```

###### Die PDP-Konfiguration wird über eine stage-spezifische Datei gesteuert:

```hcl
insecure_tls       = true                          # Aktivieren bei selbst signierten Zertifikaten (optional, Default ist false)
keycloak_url       = "https://example.domain/auth" # Externe URL des Keycloak-Servers
keycloak_namespace = "zeta-demo"                   # Namespace des Authservers im Cluster
pdp_scopes         = ["zero:read", "zero:write"]   # Zusätzliche PDP-Scopes
```

Siehe [demo.tfvars](demo.tfvars).

##### Backend initialisieren

Terraform speichert den zustandsführenden State im Kubernetes-Cluster als Secret
unter dem Namen `tfstate-default-state`.
Vor jeder Konfiguration muss das Backend initialisiert werden:

```shell
terraform -chdir=terraform/authserver init \
  -backend-config=environments/demo.backend.hcl \
  -reconfigure
```

##### Konfiguration anwenden

Sobald Variablen und Backend korrekt eingerichtet sind, spielen Sie die
Konfiguration ein (`common.tfvars` enthält den Realm-Namen):

```shell
terraform -chdir=terraform/authserver apply \
  -var-file=environments/common.tfvars \
  -var-file=demo.tfvars \
  -auto-approve
```

Terraform konfiguriert dabei den Keycloak so, dass dieser als PDP eingesetzt
werden kann.

> Die Konfiguration ist beliebig wiederholbar; Terraform sorgt dafür, dass nur
> notwendige Änderungen ausgeführt werden.

###### Optional: Konfiguration vor Anwendung prüfen:

```shell
terraform -chdir=terraform/authserver plan \
  -var-file=environments/common.tfvars \
  -var-file=demo.tfvars
```

Sollten Sie ihre Änderungen an dem PDP vorher prüfen wollen, dann können Sie
den obigen Terraform-Befehl nutzen.
Dieser vergleicht Ihre Konfiguration mit dem State, der bereits im Cluster
vorhanden ist. Die angezeigten Unterschiede werden unterteilt in
- _create_ (erstellen)
- _update_ (ändern)
- _delete_ (löschen)
- _replace_ (ersetzen, eine Kombination aus _delete_ und _create_)

#### 3. PEP konfigurieren

Die values-demo.yaml enthält eine PEP-Beispielkonfiguration, welche eine
nginx-Welcome-Seite ausliefert.
Für den Demo-Use-Case können Sie diesen Abschnitt überspringen.

Falls der PEP an einen Fachdienst angeschlossen werden soll, geht dies wie
folgt:

Der PEP ist auf Basis von nginx umgesetzt. In
der [values-demo.yaml](values-demo.yaml) ist im Feld
`pepproxy.nginxConf.fileContent` der Dateiinhalt einer nginx-Konfiguration
(.../nginx.conf) anzugeben.
Dort sind in der [values-demo.yaml](values-demo.yaml) die folgenden Direktiven
auf die Konfiguration des PDP abzustimmen:

* `pep_issuer`

  Die Realm URL des PDP. Sollte z.B. wie folgt aussehen:
  `https://public-name-of-keycloak-here/auth/realms/zeta-guard`

* `proxy_pass`

  Das abzusichernde Ziel.
  In der values-demo.yaml ist das Ausliefern des http-Verzeichnisses via
  `root ...` eingerichtet.
  Der Fachdienst ist in der Regel über die nginx-Standarddirektive `proxy_pass`
  anzubinden.
  In der values-demo.yaml wäre dann die `root`-Direktive zu ersetzen, z.B. durch
  `proxy_pass https://testfachdienst/`

Anmerkung: Die nginx-Direktive `pep on;` schaltet das PEP-spezifische Verhalten
auf dem entsprechenden Pfad ein. Eine genauere Referenz zur PEP-Konfiguration
findet sich [hier](../Referenzen/Konfiguration_des_PEP_Http_Proxy.md).

Nachdem Sie die values-demo.yaml entsprechend angepasst haben, können Sie Ihre
Änderungen über folgendes Helm-Kommando ausrollen:

```shell
    helm upgrade --install zeta-guard zeta/zeta-guard -f values-demo.yaml --wait --atomic
```

Nun haben Sie den ZETA-Guard eingerichtet und ein Zugriff über den
ZETA-Testclient und das ZETA-Client-SDK ist möglich.

Der ZETA Guard ist nun fertig installiert. Für einen Test bietet es sich an, den
[Testclient](Wie_Sie_den_ZETA_Demo_client_ausführen.md) oder alternativ
[Testdriver](Wie_Sie_den_Testdriver_bauen.md) aufzusetzen.
