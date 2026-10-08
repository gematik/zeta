# Wie Sie ZETA-Guard aktualisieren

Ein Update einer bestehenden Installation besteht aus `helm upgrade` für das
Chart und anschließend `terraform apply` für die Realm-Konfiguration.
**Eine vollständige Neuinstallation ist nie erforderlich und kein
Update-Schritt löscht Nutzdaten.** Einzige Ausnahme ist der einmalige
[Pflichtschritt beim Update von 1.3.0/1.3.1 auf 1.3.2](#pflichtschritt-update-von-130131-auf-132),
bei dem die dynamisch registrierten Clients neu aufgebaut werden.

Diese Anleitung beschreibt den unterstützten Weg, wie Sie den Terraform-State
schützen, und wie Sie vorgehen, wenn der State verloren gegangen ist — der Fall,
der bei einem intakten Realm eine ganze Reihe von `409 Conflict`- und
`400 Bad Request`-Fehlern erzeugt.

## Inhaltsverzeichnis

- [Was Terraform verwaltet — und was nicht](#was-terraform-verwaltet--und-was-nicht)
- [Der unterstützte Update-Weg](#der-unterstützte-update-weg)
  - [Ohne Makefile](#ohne-makefile)
- [Der Terraform-State muss das Update überleben](#der-terraform-state-muss-das-update-überleben)
- [Vorgehen bei verlorenem State](#vorgehen-bei-verlorenem-state)
- [Pflichtschritt: Update von 1.3.0/1.3.1 auf 1.3.2](#pflichtschritt-update-von-130131-auf-132)
- [Besonderheiten beim Update auf 1.3.x](#besonderheiten-beim-update-auf-13x)
- [Fehlerbilder](#fehlerbilder)

## Was Terraform verwaltet — und was nicht

Die Terraform-Konfiguration unter `terraform/authserver/` verwaltet
**ausschließlich Realm-Konfiguration**:

- den Realm `zeta-guard` selbst und seine Attribute
- Client-Scopes, Protocol-Mapper und die Liste der optionalen Realm-Scopes
- den SMC-B-Identity-Provider, Client-Policy-Profile und -Policies
- den ES256-Signaturschlüssel-Provider und die Event-Listener-Liste des Realms

Sie verwaltet **nicht** und kann nicht löschen:

- **Nutzer und deren Registrierungen** — Datensätze in der
  CloudNativePG-PostgreSQL-Datenbank (`keycloak-db`)
- **Clients aus der dynamischen Client-Registrierung (DCR)** — jede
  ZETA-Client-Instanz registriert sich zur Laufzeit selbst; für diese Clients
  existiert keine Terraform-Ressource
- Sessions, Access- und Refresh-Tokens

Beides liegt an verschiedenen Stellen. **Ein verlorener Terraform-State bedeutet
deshalb keinen Datenverlust**, und ein Terraform-Lauf gegen einen bestehenden
Realm rührt die Nutzerdatensätze nicht an. `terraform destroy` ist kein
Bestandteil eines Updates — führen Sie es nicht aus.

## Der unterstützte Update-Weg

```shell
# 1. Chart
helm upgrade --install zeta-guard oci://<registry>/zeta-guard:<version> \
  -f values.yaml -n <namespace> --rollback-on-failure --timeout 15m

# 2. Realm-Konfiguration — beliebig wiederholbar und idempotent
make config stage=<stage>
```

Schritt 2 ist nur nötig, wenn das Release die Terraform-Dateien geändert hat
oder Sie eine Funktion aktiviert haben, die Realm-Konfiguration voraussetzt. Die
Release Notes des Helm-Charts weisen solche Änderungen aus; ein zusätzlicher Lauf
schadet nicht. Details dazu, wann die PDP-Konfiguration laufen muss, finden Sie
im [Quickstart](ZETA_Guard_Quickstart.md#wann-und-wie-oft-die-pdp-konfiguration-laufen-muss).

### Ohne Makefile

Das Makefile ist eine Bequemlichkeitshilfe, keine Voraussetzung — jeder Schritt
dieser Anleitung lässt sich mit reinem `terraform` ausführen. Die verwendeten
Targets entsprechen den folgenden Befehlen, alle **aus dem Verzeichnis
`terraform/authserver` heraus** ausgeführt:

| Target               | Entsprechung                                                                                                                            |
|----------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `make config-init`   | der Generator (siehe unten), danach `terraform init -backend-config=environments/<stage>.backend.hcl -reconfigure`                      |
| `make config`        | `terraform apply -parallelism=1 -var-file=../../<values-dir>/<stage>.tfvars -auto-approve`                                              |
| `make config-plan`   | `terraform plan -var-file=../../<values-dir>/<stage>.tfvars -var="skip_external_resources=true"`                                        |
| `make config-import` | `terraform import -var-file=../../<values-dir>/<stage>.tfvars -var="skip_external_resources=true" keycloak_realm.zeta_realm zeta-guard` |

`main.tf`, `providers.tf`, `mode-assert.tf` (im Kubernetes-Modus zusätzlich
`sekidp-secret.tf`) und die Backend-Konfiguration werden **generiert** und sind gitignoriert — ohne sie läuft Terraform nicht. Erzeugen
Sie sie zuerst, dann initialisieren:

```shell
cd terraform/authserver

STAGE=<stage> NAMESPACE=<namespace> \
  TF_VAR_use_kubernetes=true TF_VAR_config_path=~/.kube/config \
  ./generate-main-and-backend.sh

terraform init -backend-config=environments/<stage>.backend.hcl -reconfigure
```

Drei Details, die das Makefile andernfalls für Sie übernimmt:

- **`-parallelism=1` bei jedem Apply.** Parallele Schreibzugriffe auf Keycloak
  laufen in Konflikte und scheitern mit einer Hibernate-
  `StaleObjectStateException` (HTTP 500).
- **Apply wiederholen.** Direkt nach einem Deployment bedient der Authserver die
  Admin-API möglicherweise noch nicht; `make config` versucht es bis zu fünfmal.
- **`-var="skip_external_resources=true"` bei Plan und Import.** Ohne diese
  Variable läuft das externe Policy-Management-Skript mit, was bei einem Plan
  nicht passieren soll.

`<values-dir>` ist das Verzeichnis mit den tfvars-Dateien Ihrer Stage — im
veröffentlichten Repository `local-test/`. `<namespace>` ist standardmäßig
`zeta-<stage>`. Im lokalen Modus setzen Sie `TF_VAR_use_kubernetes=false` und
übergeben die Admin-Zugangsdaten explizit über `TF_VAR_keycloak_username` und
`TF_VAR_keycloak_password`.

## Der Terraform-State muss das Update überleben

Im Kubernetes-Modus liegt der State im Secret `tfstate-default-state` im
Namespace der Stage. Es wird vom Kubernetes-Backend von Terraform angelegt, nicht
von Helm, und trägt keine Helm-Ownership-Metadaten:

| Aktion           | State-Secret | Realm-Daten                                        |
|------------------|--------------|----------------------------------------------------|
| `helm upgrade`   | bleibt       | bleiben                                            |
| `helm uninstall` | bleibt       | **gelöscht** (CNPG-`Cluster` ist Helm-verwaltet, s. u.) |
| `make uninstall` | **gelöscht** | **gelöscht** (CNPG-Cluster inkl. PVCs)             |

`make uninstall` ist ein Entwicklungs-Target. Es löscht State **und** Datenbank
gemeinsam und hält beide damit konsistent — auf einer produktiven Stage ist es
aber nie das richtige Kommando. Es ist keine Terraform-Operation: Die
zerstörenden Kommandos sind `kubectl delete secret tfstate-default-state`,
`kubectl delete cluster keycloak-db` und das Löschen der zugehörigen PVCs.
Vermeiden Sie diese drei auf einer Stage, die Sie behalten wollen — unabhängig
davon, womit Sie Ihr Deployment steuern.

Sichern Sie den State vor jedem Update:

```shell
kubectl -n <namespace> get secret tfstate-default-state -o yaml \
  > tfstate-default-state.$(date +%F).yaml
```

Zurückspielen können Sie diese Datei mit `kubectl apply -f`.

> **Hinweis:** Die Keycloak-Datenbank trägt **keine** Annotation
> `helm.sh/resource-policy: keep` (der Notification-Service-Cluster hingegen
> schon). Ein `helm uninstall` des Releases entfernt daher das `Cluster`-Objekt
> der Keycloak-Datenbank. Legen Sie vor jedem Abbau ein CNPG-Backup an und
> verlassen Sie sich nicht darauf, dass Helm die Datenbank schützt.

Im **lokalen Modus** (`use_kubernetes = false`) liegt der State in der Datei
`terraform/authserver/terraform.tfstate`. Sie ist gitignoriert und existiert nur
auf dem Rechner, der das letzte Apply ausgeführt hat — sichern Sie sie selbst.
Beachten Sie, dass `make clean` sie löscht, zusammen mit `.terraform/`, der
Lock-Datei und den generierten Dateien `main.tf`, `providers.tf`,
`mode-assert.tf` und `sekidp-secret.tf`; führen Sie es (oder ein entsprechendes `rm`) nicht zwischen
zwei Applies aus. Wer das Update ausführt, braucht denselben State wie derjenige,
der das vorige Apply ausgeführt hat.

## Vorgehen bei verlorenem State

**Fehlerbild:** `terraform apply` gegen einen laufenden, funktionierenden Realm
meldet Konflikte für Objekte, die offensichtlich existieren:

```text
Error: error sending POST request to /auth/admin/realms/zeta-guard/identity-provider/instances:
409 Conflict. Response body: {"errorMessage":"Identity Provider zeta-smc-b-oidc already exists"}

Error: error sending POST request to /auth/admin/realms/zeta-guard/client-scopes:
409 Conflict. Response body: {"errorMessage":"Client Scope vsdservice already exists"}

Error: error sending PUT request to /auth/admin/realms/zeta-guard/client-policies/profiles:
400 Bad Request. Response body: {"errorMessage":"proposed client profile name duplicated."}
```

Terraform versucht zu *erstellen*, was bereits vorhanden ist, weil sein State
leer ist. Die Lösung ist, die bestehenden Objekte in den State zu
**übernehmen** (`terraform import`). Keiner der folgenden Schritte löscht
Nutzdaten.

Die vollständige Befehlsliste mit allen Import-Adressen und ID-Formaten steht in
[How to upgrade ZETA Guard](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_upgrade_ZETA_Guard.md)
im Helm-Chart-Repository. Der Ablauf in Kurzform:

1. **Voraussetzungen.** `terraform`, `curl` und `jq`; ein generiertes `main.tf`
   und ein initialisiertes Backend über `make config-init stage=<stage>` — oder
   Generator und `terraform init` aus [Ohne Makefile](#ohne-makefile); ein
   Admin-Token für die Admin-API-Aufrufe (Zugangsdaten im Kubernetes-Modus aus
   dem Secret `authserver-admin`).

2. **Nicht importierbare Objekte vorab entfernen.** Der
   Keycloak-Terraform-Provider unterstützt für drei verwendete Ressourcentypen
   **keinen** Import:

| Ressource                                     | Vorgehen                                                          |
|-----------------------------------------------|-------------------------------------------------------------------|
| `keycloak_realm_client_policy_profile`        | vorher löschen, `apply` legt sie neu an                           |
| `keycloak_realm_client_policy_profile_policy` | vorher löschen, `apply` legt sie neu an                           |
| `keycloak_realm_events`                       | nichts zu tun — der Provider schreibt die Konfiguration per `PUT` |

   Client-Policy-Profil und -Policy sind **reine Konfiguration** (Profilname,
   `dpop-bind-enforcer`-Executor, Client-Typ-Bedingungen). Sie enthalten keine
   Nutzdaten und keinen Client-Zustand, das Löschen und Neuanlegen ist daher
   unkritisch. Löschen Sie die Policy vor dem Profil — eine Policy, die auf ein
   fehlendes Profil verweist, wird abgelehnt.

3. **Keycloak-IDs ermitteln.** Die Import-IDs von Scopes, Mappern und
   Schlüssel-Providern sind UUIDs, die Keycloak beim Anlegen vergeben hat; sie
   müssen aus der laufenden Instanz gelesen werden. `GET
   /admin/realms/zeta-guard/client-scopes` liefert Scopes **und** deren
   Protocol-Mapper in einem Aufruf.

   Achtung bei den EC-Schlüssel-Providern
   (`GET /admin/realms/zeta-guard/components?type=org.keycloak.keys.KeyProvider`):
   Auf Stages mit `enable_sekidp = true` gibt es **zwei** Komponenten mit der
   Provider-ID `ecdsa-generated`. Sie unterscheiden sich nur im Namen — wird eine
   unter der Adresse der anderen importiert, rotiert ein Signaturschlüssel:

| `name`                | Terraform-Adresse                                                 |
|-----------------------|-------------------------------------------------------------------|
| `ES256-generated-key` | `keycloak_realm_keystore_ecdsa_generated.es256`                   |
| `ecdsa-generated`     | `keycloak_realm_keystore_ecdsa_generated.entity_statement_sig[0]` |

4. **Importieren.** Beginnen Sie mit dem Realm — die einzige Adresse, deren
   Import-ID einfach ihr Name ist:

   ```shell
   make config-import stage=<stage>

   # ohne Makefile, aus terraform/authserver:
   terraform import -var-file=../../<values-dir>/<stage>.tfvars \
     -var="skip_external_resources=true" \
     keycloak_realm.zeta_realm zeta-guard
   ```

   Danach folgen Scopes, Mapper, der Identity-Provider, die optionale
   Scope-Liste und der ES256-Schlüssel-Provider. Die `terraform_data`-Ressourcen
   (`remove_rsa_keys`, `vau_db_enc`, `hsm_token_signing`, …) sind lokale Trigger
   ohne Gegenstück in Keycloak und werden **nicht** importiert.

5. **Plan prüfen, bevor Sie anwenden.**

   ```shell
   make config-plan stage=<stage>

   # ohne Makefile, aus terraform/authserver:
   terraform plan -var-file=../../<values-dir>/<stage>.tfvars \
     -var="skip_external_resources=true"
   ```

   Zwei Einträge bedeuten, dass die Übernahme unvollständig ist und ein Apply
   einen Ausfall verursachen würde:

   - **`keycloak_realm.zeta_realm` wird gelöscht oder ersetzt** — abbrechen. Das
     würde den Realm und alle darin enthaltenen Nutzer löschen.
   - **`keycloak_realm_keystore_ecdsa_generated.es256` wird erstellt oder
     ersetzt** — abbrechen und importieren. Ein zweiter ES256-Provider führt
     dazu, dass Keycloak auf einen neuen aktiven Signaturschlüssel wechselt;
     alle bereits ausgegebenen Access-Tokens und der im PEP zwischengespeicherte
     JWKS verlieren ihre Gültigkeit.

   Erwartet und unkritisch sind: erneut laufende `terraform_data`-Ressourcen, das
   Neuanlegen von Client-Policy-Profil und -Policy aus Schritt 2 sowie eine
   Aktualisierung von `keycloak_realm_events`. Alles andere sollte leer sein.

Ist der Plan sauber, wenden Sie ihn an und prüfen Sie mit einem
authentifizierten Request über den PEP, dass Tokens weiterhin validiert werden:

```shell
make config stage=<stage>

# ohne Makefile, aus terraform/authserver — -parallelism=1 beibehalten:
terraform apply -parallelism=1 \
  -var-file=../../<values-dir>/<stage>.tfvars -auto-approve
```

## Pflichtschritt: Update von 1.3.0/1.3.1 auf 1.3.2

**Betroffen sind alle Installationen, die mit 1.3.0 oder 1.3.1 in Betrieb
genommen wurden.** Neuinstallationen ab 1.3.2 und Updates von Versionen vor
1.3.0 sind nicht betroffen.

Der Authserver 1.3.2 korrigiert die Groß-/Kleinschreibung in der
Liquibase-Migration der Plugin-Tabellen `ZETA_USER_DATA` und
`ZETA_CLIENT_DATA` (Datei `jpa-changelog-26.6.3.xml`), die auf Datenbanken mit
Groß-/Kleinschreibung fehlschlug. Die bereits angewendeten Changesets wurden
dabei in der Datei geändert, ihre Liquibase-Prüfsummen stimmen deshalb nicht
mehr mit den in der Datenbank gespeicherten überein. **Ohne Vorbereitung
startet der Authserver 1.3.2 gegen eine mit 1.3.0/1.3.1 migrierte Datenbank
nicht** — die Prüfsummenvalidierung schlägt fehl.

Führen Sie deshalb **vor** dem `helm upgrade` auf 1.3.2 einmalig aus:

1. Authserver anhalten, damit während des Eingriffs keine Instanz auf die
   Tabellen schreibt:

   ```shell
   kubectl -n <namespace> scale deployment/authserver --replicas=0
   kubectl -n <namespace> rollout status deployment/authserver
   ```

2. Beide Tabellen und die zugehörige Liquibase-Buchführung löschen. Die
   Plugin-Migrationen führen ihren Stand in der eigenen Tabelle
   `databasechangelog_zeta_guard` — die Tabellen allein zu löschen genügt
   nicht, die gespeicherten Prüfsummen würden weiterhin die Validierung
   verletzen. Bei der mitgelieferten CloudNativePG-Datenbank:

   ```shell
   PRIMARY=$(kubectl -n <namespace> get cluster keycloak-db \
     -o jsonpath='{.status.currentPrimary}')
   kubectl -n <namespace> exec -i "$PRIMARY" -- psql -U postgres -d keycloak <<'SQL'
   DROP TABLE IF EXISTS zeta_client_data, zeta_user_data CASCADE;
   DELETE FROM databasechangelog_zeta_guard WHERE filename LIKE '%jpa-changelog-26.6.3%';
   SQL
   ```

   Bei einer extern betriebenen **PostgreSQL**-Datenbank führen Sie dieselben
   beiden Anweisungen mit einem Werkzeug Ihrer Wahl gegen die Keycloak-Datenbank
   aus.

3. Update wie gewohnt durchführen (`helm upgrade`, danach `make config`, siehe
   [Der unterstützte Update-Weg](#der-unterstützte-update-weg)). Beim Start
   führt der Authserver die Migration erneut aus und legt beide Tabellen neu an.

**Auswirkung:** Die per dynamischer Client-Registrierung (DCR) registrierten
Clients gehen mit dem Löschen der Tabellen verloren und müssen sich beim
nächsten Zugriff neu registrieren. Die Keycloak-eigenen Tabellen (Realm,
Nutzer, Sessions) sind nicht betroffen. Sichern Sie die Datenbank vor dem
Eingriff (CNPG-Backup oder `pg_dump`), auch wenn kein Rollback der beiden
Tabellen vorgesehen ist.

## Besonderheiten beim Update auf 1.3.x

- **Update von 1.3.0/1.3.1 auf 1.3.2:** siehe
  [Pflichtschritt](#pflichtschritt-update-von-130131-auf-132) oben — ohne die
  dort beschriebene Vorbereitung startet der Authserver nicht.
- **`audience_scope_name` hat keinen Standardwert mehr** und muss in den tfvars
  jeder Stage gesetzt werden. Die Variable benennt den einen Scope, der die vom
  PEP geprüften Claims trägt (`aud`, `profession_oid`, `client_id`, …). Schreibt
  ein Fachdienst einen Scope-Namen vor — VSDM verlangt `scope=vsdservice`
  (A_26744) —, setzen Sie ihn hier und führen ihn **nicht** zusätzlich in
  `pdp_scopes` auf.
- **`zero:register` und `zero:manage` entfallen** samt ihres
  Authorization-Server-Audience-Mappers. Ein `terraform apply` löscht sie aus
  bestehenden Realms. Clients, die einen der beiden Scopes noch anfordern, müssen
  ihn vorher entfernen.
- **Die Event-Listener-Liste des Realms wird vollständig verwaltet.** Manuell
  ergänzte Listener werden bei jedem Apply entfernt. Prüfen Sie den Plan, bevor
  Sie ihn auf einen von Hand konfigurierten Realm anwenden.
- **Keycloak-Versionssprünge benötigen einen Deployment-Cutover.** Ein einfaches
  `helm upgrade` kann hängen, wenn die neue Keycloak-Version eine andere
  JGroups-Protokollversion mitbringt. Siehe den Migrationshinweis zu Release
  1.2.0 in den [Release Notes](../ReleaseNotes/ZetaGuard/ReleaseNotes.md).

## Fehlerbilder

**Authserver 1.3.2 startet nicht; das Log enthält `Validation Failed` mit
Hinweis auf geänderte Prüfsummen (`check sum`) für Changesets aus
`jpa-changelog-26.6.3.xml`.** Der
[Pflichtschritt](#pflichtschritt-update-von-130131-auf-132) wurde ausgelassen
oder nur die Tabellen, nicht aber die Einträge in `databasechangelog_zeta_guard`
gelöscht. Führen Sie beide Anweisungen aus und starten Sie den Authserver neu.

**`Error: Invalid for_each argument … will be known only after apply` bei
`terraform import`.** Im aktuellen Chart behoben. `terraform import` behandelt
Ressourcen, die nicht im State stehen, als unbekannt; ein `for_each`, das auf
eine andere Ressource verweist, kann daher keine bekannten Instanz-Schlüssel
bilden und der Lauf bricht ab, bevor er etwas importiert. Betroffen waren zwei
Notification-Mapper. `plan` und `apply` sind davon nicht betroffen — blockiert
war ausschließlich die Übernahme in den State. Auf einem älteren Chart
aktualisieren Sie zuerst die Terraform-Dateien.

**Der Import gelingt, der Plan will das Objekt aber weiterhin erstellen.**
Adresse oder ID stimmen nicht — etwa ein Mapper, der unter dem Client-Pfad
(`/client/`) statt unter dem Client-Scope-Pfad (`/client-scope/`) importiert
wurde, oder ein `for_each`-Schlüssel, der nicht dem Scope-Namen entspricht.
Entfernen Sie ihn mit `terraform state rm '<adresse>'` und importieren Sie erneut.

**`Error: Resource already managed by Terraform`.** Diese Adresse steht bereits
im State — überspringen Sie sie.

## Weiterführende Dokumentation

- [ZETA-Guard-Quickstart](ZETA_Guard_Quickstart.md)
- [Wie Sie ZETA-Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
- [Konfiguration einer VAU mit verschlüsselter Datenbank](../Referenzen/Konfiguration_VAU.md)
- [Troubleshooting & Debugging](Troubleshooting_und_Debugging.md)
