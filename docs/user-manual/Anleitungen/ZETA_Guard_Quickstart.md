# ZETA-Guard-Quickstart

Dieses Dokument beschreibt ein generisches Deployment von ZETA-Guard auf einem
Kubernetes-Cluster. Es dient als Referenz- und Einstiegsszenario, um ZETA-Guard
reproduzierbar zu installieren, zu konfigurieren und in einen Fachdienst zu
integrieren.

Die beschriebenen Schritte und Konfigurationen sind bewusst umgebungsneutral
gehalten und lassen sich sowohl auf lokale Entwicklungsumgebungen (siehe auch
[Wie Sie den Cluster lokal mit KIND aufsetzen](Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md))
als auch auf Cloud- oder On-Premise-Cluster übertragen. Spezifische
Anforderungen an Produktivumgebungen – wie Härtung, Hochverfügbarkeit,
Backup-Strategien, Secret-Management oder mandantenspezifische Anpassungen –
sind nicht Bestandteil dieses Dokuments und müssen projektspezifisch ergänzt
werden.

Der Fokus liegt auf:

- einer funktionalen Ende-zu-Ende-Installation von ZETA-Guard,
- einer reproduzierbaren Konfiguration des PDP mittels Terraform,
- sowie der exemplarischen Anbindung eines Fachdienstes über den PEP.

## Inhaltsverzeichnis

- [Installation](#installation)
  - [Benötigte Werkzeuge](#benötigte-werkzeuge)
  - [Installationsschritte](#installationsschritte)
  - [1. Helm aufsetzen](#1-helm-aufsetzen)
  - [2. PDP konfigurieren](#2-pdp-konfigurieren)
    - [Wann und wie oft die PDP-Konfiguration laufen muss](#wann-und-wie-oft-die-pdp-konfiguration-laufen-muss)
  - [3. PEP konfigurieren](#3-pep-konfigurieren)

## Installation

### Benötigte Werkzeuge

* Helm, kubectl und Terraform
* ein Kubernetes-Cluster (für lokale Deployments
  siehe [Wie Sie den Cluster lokal mit KIND aufsetzen](Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md))
    * mit über Stateful Sets provisionierbarem Storage
    * mit eingerichtetem Ingress-Controller (optional, kann über
      `ingressEnabled` deaktiviert werden)
    * den passenden Kontext in kubectl eingerichtet
* ein Fachdienst – in diesem Dokument wird dieser als verfügbar
  unter https://testfachdienst angenommen.

### Installationsschritte

Die Installation gliedert sich grob in folgende Schritte:

1. Helm aufsetzen
2. PDP konfigurieren
3. PEP konfigurieren

### 1. Helm aufsetzen

Das ZETA-Guard-Helm-Chart ist für Helm 4 konzipiert.

Kopieren Sie nun die
Datei [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
in das Arbeitsverzeichnis.
Sie können diese Datei als Konfigurationsvorlage verwenden, umbenennen und
anpassen.

Beim **ersten Deployment** (Initialinstallation) müssen zusätzlich zu den
Admin-Zugangsdaten auch die Werte für `authserver.genesisHash` und
`authserver.smcbHashingPepper` im Values-File gesetzt werden.
Diese Werte sind für die Erstellung der zugehörigen Kubernetes-Secrets
erforderlich und werden bei der ersten Installation zwingend benötigt.

Zum Beispiel:

```yaml
authserver:
    admin:
        username: admin-Name
        password: admin-Passwort
    genesisHash: 4841c2142fef441daa6ee6c57db65c011935964b14e94a6c8f5ec0447b83526c
    smcbHashingPepper: 085c1245-1234-5678-95b4-97496bec6182
```

- Im Produktivbetrieb kann das Passwort z. B. via Helm-Parameter `--set-file`
  von einem CD-Server gesetzt werden.
- Die Werte für `genesisHash` und `smcbHashingPepper` sollten selbst generiert
  werden: ein 64-stelliger Hex-String (`openssl rand -hex 32`) für den
  Genesis-Hash, eine UUID (`uuidgen`) für den Pepper. Siehe
  [Referenz des Helm-Charts – Initiale Secrets](../Referenzen/Referenz_des_Helm_Charts.md#initiale-secrets-genesis-hash-und-smc-b-pepper).
- Nach dem initialen Deployment werden die Secrets im Cluster gespeichert. Bei
  späteren Upgrades müssen die Werte im Values-File **nicht erneut gesetzt
  werden**, solange die Secrets im Cluster bestehen bleiben. Das Helm-Chart
  liest den bestehenden Wert automatisch aus dem Cluster und lässt ihn
  unverändert.
- Um einen dieser Werte bewusst zu **rotieren**, kann er bei einem `helm upgrade`
  explizit im Values-File oder per `--set` angegeben werden. Der neue Wert
  überschreibt dann das bestehende Secret. **Achtung:** Eine Änderung von
  `genesisHash` bricht die Integrität der Admin-Event-Hash-Chain; eine Änderung
  von `smcbHashingPepper` invalidiert alle bestehenden SMC-B-Nutzer-Hashes.

Mit
dieser [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
können Sie ZETA-Guard über
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

Die relevanten Terraform-Templates finden sich im Unterverzeichnis `terraform`
[hier](https://github.com/gematik/zeta-guard-helm).

#### Betriebsmodi

Terraform kann in zwei Modi betrieben werden, gesteuert über die
Terraform-Variable
`use_kubernetes`:

|                         | **Kubernetes-Modus** (Standard)                      | **Lokaler Modus**                             |
|-------------------------|------------------------------------------------------|-----------------------------------------------|
| **State-Backend**       | Kubernetes-Secret im Cluster                         | Lokale `terraform.tfstate`-Datei              |
| **Zugangsdaten**        | `TF_VAR_keycloak_*`, aus `authserver-admin` gefüllt² | `TF_VAR_keycloak_*`²                          |
| **Kubernetes-Provider** | Wird konfiguriert und genutzt                        | Entfällt vollständig¹                         |
| **Cluster-Zugang**      | Erforderlich (kubeconfig)                            | Nicht erforderlich                            |
| **Typischer Einsatz**   | CI/CD-Pipelines, Cluster-Zugang vorhanden            | Lokale Entwicklung, kein Cluster-Zugang nötig |
| **Aktivierung**         | `use_kubernetes = true` (Standard)                   | `use_kubernetes = false`                      |

¹ Im lokalen Modus enthält die generierte Konfiguration keinen einzigen
`kubernetes_*`-Block, sodass `terraform init` das Provider-Plugin gar nicht erst
herunterlädt.

² Die Admin-Zugangsdaten kommen in **beiden** Modi ausschließlich aus
`TF_VAR_keycloak_username` und `TF_VAR_keycloak_password`; beide sind
erforderlich. Terraform liest das Secret `authserver-admin` nicht selbst — das
Ergebnis einer Data Source wird persistiert und hätte das Admin-Passwort im
Klartext im State abgelegt. Das mitgelieferte Skript
`terraform/authserver/scripts/kc-admin-env.sh` füllt die beiden Variablen aus
dem Secret; siehe [Terraform-Variablen definieren](#terraform-variablen-definieren).

`keycloak_username` und `keycloak_password` sind `ephemeral` deklariert. Sie
werden weder in den Terraform-State noch in eine mit `terraform plan -out=…`
gespeicherte Plandatei geschrieben und müssen deshalb bei **jedem**
Terraform-Aufruf erneut bereitgestellt werden — auch bei einem anschließenden
`terraform apply <plandatei>`. Terraform lehnt zudem jede Verwendung in einem
persistierten Kontext mit `Invalid use of ephemeral value` ab; zulässig sind nur
die Provider-Konfiguration und Provisioner-Umgebungen.

#### Voraussetzungen

##### Allgemein (beide Modi)

- Terraform ist installiert, **Version 1.11 oder neuer**. Die Variablen für die
  Keycloak-Admin-Zugangsdaten sind `ephemeral` deklariert (ab Terraform 1.10),
  und das Client-Secret des SMC-B-Identity-Providers nutzt ein write-only-Argument
  (ab Terraform 1.11).
- `curl` und `jq` sind verfügbar (werden vom Policy-Management-Skript benötigt).
- Netzwerkzugang zur Keycloak-Instanz vom ausführenden Rechner.

##### Kubernetes-Modus (Standard)

- Der ZETA-Guard-Cluster läuft und ist über kubectl erreichbar.
- Der PDP (`authserver`) ist im Cluster deployt.
- Keycloak-Admin-Zugangsdaten liegen im Kubernetes-Secret `authserver-admin`
  (wird vom Helm-Chart erzeugt). Terraform liest es nicht selbst — Sie füllen
  daraus zuerst `TF_VAR_keycloak_username` und `TF_VAR_keycloak_password`, am
  einfachsten mit `scripts/kc-admin-env.sh` (siehe
  [Terraform-Variablen definieren](#terraform-variablen-definieren)).
- `kubectl`-Leserecht auf das Secret `authserver-admin` — das braucht jetzt das
  Skript statt Terraform.

##### Lokaler Modus

- `TF_VAR_use_kubernetes=false` als Umgebungsvariable oder im Make-Aufruf
  gesetzt.
- Keycloak-Admin-Zugangsdaten explizit bereitgestellt — beide erforderlich,
  einen Cluster-Fallback gibt es nicht:
    - `TF_VAR_keycloak_username`
    - `TF_VAR_keycloak_password`
- Der Terraform-State wird lokal in `terraform.tfstate` gespeichert.

#### Hinweis: Erforderliche Kubernetes-Rechte für Terraform (nur Kubernetes-Modus)

Im Kubernetes-Modus interagiert Terraform direkt mit dem Cluster. Dafür
benötigt der ausführende Service Account entsprechende Berechtigungen im
Ziel-Namespace.

Insbesondere werden folgende Rechte vorausgesetzt:

- Secrets (`apiGroups: [""]`)
  Terraform speichert seinen State als Kubernetes-Secret (z. B.
  `tfstate-default-state`) und benötigt dafür Lese-, Schreib- und Listenrechte.
- Leases (`apiGroups: ["coordination.k8s.io"]`)
  Um parallele Ausführungen des Terraform-Moduls zu verhindern, wird ein Lock
  über Kubernetes-Leases realisiert.

> **Hinweis zum Schutzbedarf des State-Secrets.** Die Keycloak-Admin-Zugangsdaten
> stehen nicht mehr im Terraform-State (siehe Fußnote ² unter
> [Betriebsmodi](#betriebsmodi)). Das Leserecht auf `authserver-admin` bleibt
> dennoch nötig: Es braucht jetzt `scripts/kc-admin-env.sh` statt Terraform.
>
> Der State ist damit nicht harmlos. Er enthält weiterhin die Client-Secrets und
> das Dummy-Benutzerpasswort des Fake-SekIDP-Testrealms (`use_fake_sekidp_testrealm`
> — in Produktivumgebungen nicht aktivieren). Behandeln Sie
> `tfstate-<workspace>-state` also weiterhin als schützenswert und vergeben Sie
> die obigen Secret-Rechte eng.

Ein `cluster-admin` ist dafür **nicht** erforderlich — alle benötigten Rechte
sind Namespace-lokal. Als Vorlage:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
    name: terraform-pdp-config
    namespace: zeta-demo          # Ziel-Namespace des Deployments
rules:
    # Admin-Zugangsdaten lesen (Secret `authserver-admin`) sowie das
    # State-Secret des kubernetes-Backends (`tfstate-<workspace>-state`)
    # anlegen, lesen, fortschreiben und entfernen.
    - apiGroups: [ "" ]
      resources: [ "secrets" ]
      verbs: [ "get", "list", "create", "update", "patch", "delete" ]
    # State-Locking des kubernetes-Backends
    # (Lease `lock-tfstate-<workspace>-state`).
    - apiGroups: [ "coordination.k8s.io" ]
      resources: [ "leases" ]
      verbs: [ "get", "create", "update", "delete" ]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
    name: terraform-pdp-config
    namespace: zeta-demo
subjects:
    - kind: ServiceAccount
      name: terraform-runner     # ServiceAccount Ihres CI/CD-Runners
      namespace: zeta-demo
roleRef:
    apiGroup: rbac.authorization.k8s.io
    kind: Role
    name: terraform-pdp-config
```

> **Grenze der Einschränkbarkeit:** Die Verben `list` und `create` lassen sich in
> Kubernetes-RBAC nicht über `resourceNames` einschränken. Das
> Backend muss Secrets im Namespace auflisten, um seine Workspaces zu finden —
> die Rolle gewährt damit Leserechte auf **alle** Secrets des Namespace. Wenn das
> nicht tragbar ist, bleiben zwei Wege: den Terraform-State in einen separaten,
> ausschließlich dafür genutzten Namespace legen, oder ein Backend außerhalb von
> Kubernetes verwenden (dann werden nur noch `get`-Rechte auf
> `authserver-admin` benötigt — oder gar keine, wenn die Zugangsdaten über
> `TF_VAR_keycloak_username` / `TF_VAR_keycloak_password` gesetzt werden).

Fehlende Berechtigungen führen typischerweise zu Initialisierungsfehlern beim
Backend (`terraform init`) oder zu Abbrüchen während `apply`.

Im lokalen Modus sind keine Kubernetes-Rechte erforderlich.

#### Terraform-Variablen definieren

Unterteilt in drei Kategorien müssen diese gesetzt werden:

- Admin-Rechte, um den PDP zu konfigurieren
- Informationen, um im Cluster zu agieren (nur Kubernetes-Modus)
- Ihre ZETA-Guard-Konfiguration

##### Setzen Sie Ihre Admin-Zugangsdaten als Umgebungsvariablen, um Terraform den Zugriff auf den PDP zu ermöglichen:

Beide Variablen sind in beiden Betriebsmodi erforderlich; Terraform bricht sonst
mit einer Variablen-Validierung ab.

Im Kubernetes-Modus füllen Sie sie am einfachsten aus dem Secret
`authserver-admin`. Dafür liegt im Repository ein Skript bereit, das Sie in Ihre
Shell **sourcen**:

```shell
cd terraform/authserver
. scripts/kc-admin-env.sh zeta-demo        # Namespace des Deployments
```

Es schreibt nichts auf die Standardausgabe — die Werte erscheinen also weder in
der Prozessliste noch in der Shell-History. In einer POSIX-Shell ohne `bash`
nutzen Sie stattdessen:

```sh
eval "$(bash scripts/kc-admin-env.sh zeta-demo)"
```

Alternativ setzen Sie die Werte selbst, etwa im lokalen Modus oder aus einem
Secret-Manager:

```shell
export TF_VAR_keycloak_username="IhrBenutzername"
export TF_VAR_keycloak_password="IhrPasswort"
```

> **Wichtig:** Wollen Sie damit im Kubernetes-Modus das Secret bewusst
> überschreiben, setzen Sie **beide** Variablen. Das Skript bevorzugt sie nur
> gegenüber dem Secret, wenn Benutzername und Passwort gesetzt sind. Exportieren
> Sie nur das Passwort, greift weiterhin das Secret `authserver-admin` — ohne
> Fehlermeldung, weil beide Werte gültig sind.

Terraform liest das Secret bewusst nicht selbst: Das Ergebnis einer Data Source
wird im State persistiert, wodurch das Admin-Passwort dort im Klartext läge.

Übergeben Sie die Werte auch nicht per `-var` auf der Kommandozeile: Dort landen
sie in der Prozessliste und in der Shell-History. Da beide Variablen `ephemeral`
sind, müssen sie bei jedem Terraform-Aufruf in der Umgebung stehen — auch beim
`apply` eines zuvor mit `-out` gespeicherten Plans.

##### Weisen Sie Terraform auf die zu verwendende kubeconfig und den Namespace hin (nur Kubernetes-Modus):

Die
Datei [demo.backend.hcl](https://github.com/gematik/zeta-guard-helm/blob/main/terraform/authserver/environments/demo.backend.hcl)
ermöglicht es Terraform, mit dem
Cluster und dem Namespace zu interagieren. Passen Sie die Werte an Ihre Umgebung
an.

```hcl
config_path = "~/.kube/config" # Pfad zur kubeconfig-Datei
namespace = "zeta-demo"      # Namespace, in dem ZETA-Guard deployt wurde
```

Im lokalen Modus wird diese Datei nicht benötigt (sie wird leer generiert).

##### Die PDP-Konfiguration wird über eine stage-spezifische Datei gesteuert:

```hcl
# Erforderlich — ohne Standardwert
keycloak_url        = "https://example.domain/auth" # Externe URL des Keycloak-Servers
keycloak_namespace  = "zeta-demo"                   # Namespace des Authservers im Cluster
audience_scope_name = "zero:audience"               # Name des Audience-Scopes (siehe Hinweis)

# Optional — mit ihren Standardwerten
# insecure_tls   = false  # Aktivieren bei selbst signierten Zertifikaten
# use_kubernetes = true   # false für lokalen Modus ohne K8s-Backend
# audience       = ""     # Expliziter Audience-Wert; leer = aus keycloak_url abgeleitet
# pdp_scopes     = []     # Zusätzliche PDP-Scopes, z. B. ["zero:read", "zero:write"]
```

Die Keycloak-Admin-Zugangsdaten gehören **nicht** in diese Datei: Sie sind
`ephemeral` deklariert und kommen ausschließlich aus `TF_VAR_keycloak_username`
und `TF_VAR_keycloak_password` (siehe
[Terraform-Variablen definieren](#terraform-variablen-definieren)).
Eine tfvars-Datei wird üblicherweise versioniert — ein Passwort darin wäre genau
das Leak, das die Ephemeral-Deklaration verhindert.

Die Variable `audience_scope_name` ist **erforderlich** und hat keinen
Standardwert — ein Apply ohne sie schlägt fehl. So ist der Name des
Audience-Scopes in jeder Stage explizit sichtbar, auch wenn ein Fachdienst eine
abweichende Scope-Namenskonvention vorgibt.

> **Hinweis:** Der Audience-Scope trägt die Mapper, die die vom PEP geforderten
> Access-Token-Claims setzen (`aud`, `profession_oid`, `client_id`, `ip_address`,
> `product_id`, `product_version`, `common_name`, `organization_name`). Der Client muss
> diesen Scope anfragen. Verlangt ein Fachdienst einen bestimmten Scope-Namen — zum Beispiel
> `vsdservice` für das VSDM (A_26744) —, setzen Sie `audience_scope_name` auf diesen Wert
> und führen ihn **nicht** zusätzlich in `pdp_scopes` (doppelter Scope-Name → Fehler).
> Sonst fehlen dem Token die Claims und der PEP lehnt die Anfrage vor der Policy ab
> (`missing field 'aud'`). Pro Realm existiert genau ein Audience-Scope.

Siehe [demo.tfvars](https://github.com/gematik/zeta-guard-helm/blob/main/terraform/authserver/environments/demo.tfvars).

#### Backend initialisieren

Vor der Konfiguration müssen die modusabhängigen Dateien generiert und das
Backend initialisiert werden. Das Skript `generate-main-and-backend.sh` erzeugt
aus Templates `main.tf`, `providers.tf`, `mode-assert.tf` und — nur im
Kubernetes-Modus — `sekidp-secret.tf`, dazu die Backend-Konfiguration. Im
lokalen Modus (`use_kubernetes = false`) entfallen der
`provider "kubernetes"`-Block, der zugehörige `required_providers`-Eintrag und
`sekidp-secret.tf` — es wird also kein Cluster-Zugang und keine kubeconfig
benötigt.

> **Hinweis:** Terraform leitet Provider-Anforderungen statisch aus den
> Ressourcentyp-Namen ab, weshalb die `kubernetes_*`-Blöcke in einer je Modus
> erzeugten Datei liegen und nicht per `count = 0` abgeschaltet werden. Im
> Kubernetes-Modus ist `sekidp-secret.tf` deren einzige Quelle; im lokalen Modus
> existiert keine davon, sodass `terraform init` das Provider-Plugin
> `hashicorp/kubernetes` gar nicht erst herunterlädt. Für Umgebungen mit Air-Gap
> oder Registry-Whitelisting heißt das: `hashicorp/kubernetes` muss nur für den
> Kubernetes-Modus verfügbar sein.

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

> Im Standard-Kubernetes-Modus wird `~/.kube/config` als kubeconfig-Pfad
> verwendet.
> Setzen Sie `TF_VAR_config_path`, falls dieser abweicht.

#### Konfiguration anwenden

Sobald Variablen und Backend korrekt eingerichtet sind, spielen Sie die
Konfiguration ein:

```shell
terraform -chdir=terraform/authserver apply \
  -var-file=../../<values-dir>/demo.tfvars \
  -auto-approve
```

> Die Zugangsdaten werden bewusst **nicht** per `-var` übergeben: `terraform`
> liest sie aus `TF_VAR_keycloak_username` / `TF_VAR_keycloak_password`. Über
> `-var` stünde das Passwort in der Prozessliste und in der Shell-History.

Terraform konfiguriert Keycloak dabei so, dass dieser als PDP eingesetzt
werden kann.

> Die Konfiguration ist beliebig wiederholbar; Terraform sorgt dafür, dass nur
> notwendige Änderungen ausgeführt werden.

##### Optional: Konfiguration vor Anwendung prüfen (Dry-Run):

```shell
terraform -chdir=terraform/authserver plan \
  -var-file=../../<values-dir>/demo.tfvars
```

Sollten Sie Ihre Änderungen am PDP vorher prüfen wollen, dann können Sie
den obigen Befehl nutzen. Dieser vergleicht Ihre Konfiguration mit dem
bestehenden State. Die angezeigten Unterschiede werden unterteilt in:

- _create_ (erstellen)
- _update_ (ändern)
- _delete_ (löschen)
- _replace_ (ersetzen, eine Kombination aus _delete_ und _create_)

#### Wann und wie oft die PDP-Konfiguration laufen muss

Die PDP-Konfiguration ist **kein** einmaliger Installationsschritt, aber auch
kein Schritt, der bei jedem Helm-Upgrade nötig ist. Sie ist beliebig
wiederholbar.

##### Zwingend erforderlich

- **Nach der Erstinstallation.** Ohne die Terraform-Konfiguration ist der
  ZETA-Guard nicht betriebsbereit — Realm, Scopes, Client-Registration-Policies
  und Signaturschlüssel existieren erst danach.
- **Nach Änderungen an den `*.tfvars`**, etwa an `pdp_scopes`,
  `audience_scope_name`, `audience` oder `keycloak_url`.
- **Nach einem Release-Upgrade, das die Terraform-Dateien ändert.** Die Release
  Notes des Helm-Charts weisen solche Änderungen aus. Beispiel: kommt ein neuer
  Event-Listener hinzu, muss `keycloak_realm_events` neu angewendet werden, sonst
  ruft Keycloak den Listener nicht auf.
- **Nach dem Aktivieren von Funktionen, die Realm-Konfiguration voraussetzen** —
  HSM-Token-Signing, SekIDP/OIDC-Flow, VAU-DB-Verschlüsselung oder die Scopes
  des Notification Service.
- **Nachdem die Datenbank oder der Realm neu angelegt wurde.** Die interne
  Realm-ID ändert sich dabei, wodurch auch die skriptbasierten Schritte erneut
  ausgeführt werden.

> **Update einer bestehenden Installation.** Ein Versionswechsel ist
> `helm upgrade` plus dieser Konfigurationslauf — eine Neuinstallation ist nie
> erforderlich, und kein Update-Schritt löscht Nutzer oder registrierte Clients.
> Terraform verwaltet ausschließlich Realm-Konfiguration; die Nutzdaten liegen in
> der Datenbank. Wie Sie den Terraform-State dabei schützen und wie Sie einen
> bestehenden Realm nach einem State-Verlust übernehmen, beschreibt
> [Wie Sie ZETA-Guard aktualisieren](Wie_Sie_ZETA_Guard_aktualisieren.md).

##### Nicht erforderlich

Bei Chart-Änderungen ohne Realm-Bezug: Ressourcen-Limits, `replicaCount`,
Image-Tags, NetworkPolicies, Ingress- oder TLS-Einstellungen. Ein zusätzlicher
Lauf schadet hier zwar nicht, ändert aber nichts.

##### Idempotenz

Ein erneuter Lauf ist gefahrlos. Die Keycloak-Ressourcen sind deklarativ, das
heißt Terraform gleicht nur Abweichungen aus. Die skriptbasierten Schritte
(Schlüsselprovider, VAU-Schalter) laufen nur erneut, wenn sich ihre Auslöser
ändern — die interne Realm-ID, der Inhalt des jeweiligen Skripts oder der
zugehörige Funktionsschalter. Das Policy-Management-Skript läuft bei **jedem**
Apply, prüft aber vor jeder Änderung den Istzustand.

Zwei Nebenwirkungen sind beabsichtigt und sollten bekannt sein:

- Die Liste der Event-Listener des Realms wird **vollständig** verwaltet. Manuell
  ergänzte Listener werden bei jedem Lauf entfernt.
- Die Keycloak-Standard-Policies `Trusted Hosts`, `Max Clients Limit` und
  `Consent Required` werden bei jedem Lauf entfernt, falls vorhanden.

### 3. PEP konfigurieren

Die [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
enthält eine PEP-Beispielkonfiguration, die eine
nginx-Welcome-Seite ausliefert.
Für den Demo-Use-Case können Sie diesen Abschnitt überspringen.

Falls der PEP an einen Fachdienst angeschlossen werden soll, geht dies wie
folgt:

Der PEP ist auf Basis von nginx umgesetzt. In
der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
ist im Feld
`pepproxy.nginxConf.fileContent` der Dateiinhalt einer nginx-Konfiguration
(.../nginx.conf) anzugeben.
Dort sind in
der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
die folgenden Direktiven
auf die Konfiguration des PDP abzustimmen:

* `pep_issuer`

  Die Realm-URL des PDP. Sollte z. B. wie folgt aussehen:
  `https://public-name-of-keycloak-here/auth/realms/zeta-guard`

* `proxy_pass`

  Das abzusichernde Ziel.
  In
  der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
  ist das Ausliefern des http-Verzeichnisses via
  `root ...` eingerichtet.
  Der Fachdienst ist in der Regel über die nginx-Standarddirektive `proxy_pass`
  anzubinden.
  In
  der [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
  wäre dann die `root`-Direktive zu ersetzen, z. B. durch
  `proxy_pass https://testfachdienst/`

Anmerkung: Die nginx-Direktive `pep on;` schaltet das PEP-spezifische Verhalten
auf dem entsprechenden Pfad ein. Eine genauere Referenz zur PEP-Konfiguration
findet sich [hier](../Referenzen/Konfiguration_des_PEP_Http_Proxy.md).

Nachdem Sie
die [values-demo.yaml](https://github.com/gematik/zeta-guard-helm/blob/main/charts/zeta-guard/values-demo.yaml)
entsprechend angepasst haben, können Sie Ihre
Änderungen über folgendes Helm-Kommando ausrollen:

```shell
    helm upgrade --install zeta-guard zeta/zeta-guard -f values-demo.yaml --rollback-on-failure --timeout 15m
```

Nun haben Sie den ZETA-Guard eingerichtet und ein Zugriff über den
ZETA-Testclient und das ZETA-Client-SDK ist möglich.

Der ZETA-Guard ist nun fertig installiert. Für einen Test bietet es sich an, den
[Testclient](Wie_Sie_den_ZETA_Demo_client_ausführen.md) oder alternativ den
[Testdriver](Wie_Sie_den_Testdriver_bauen.md) aufzusetzen.
