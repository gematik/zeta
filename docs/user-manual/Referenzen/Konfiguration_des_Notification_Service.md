# Konfiguration des Notification Service

Der Notification Service ist die Push-Benachrichtigungs-Fassade des ZETA Guard:
Ein Fachdienst (Resource Server) übergibt ihm eine Benachrichtigung für einen
Nutzer und einen Kanal, der Dienst ermittelt die registrierten Geräte mit
aktivem Kanal und leitet den Push asynchron an das Push Gateway der gematik
weiter, das seinerseits APNs bzw. FCM anspricht. Mobile Clients erreichen den
Dienst über das ZETA SDK, um ihre Push-Ziele (Pusher) zu registrieren, Kanäle
zu schalten und optional ihre Nachrichten-Historie zu lesen.

Der Notification Service ist Teil der Umsetzungsstufe 2 und wird als
**Vorschau** ausgeliefert: Er ist im Helm Chart **standardmäßig deaktiviert**
(`notificationService.enabled: false`). Die Einschränkungen des aktuellen Stands sind
[unten](#aktueller-stand-und-einschränkungen) beschrieben.

Zielgruppe sind primär Betreiber von Fachdiensten; der Abschnitt zu den
Umgebungsvariablen richtet sich auch an Fachdienst-Hersteller, die den Dienst
außerhalb des Helm Charts betreiben oder integrieren.

Das Konzeptdokument zum Ablauf findet sich unter
[Wie der Notification Service funktioniert](../Anleitungen/Wie_der_Notification_Service_funktioniert.md).

## Inhaltsverzeichnis

- [Übersicht: Split-Deployment und Datenbank](#übersicht-split-deployment-und-datenbank)
- [Helm-Werte (`notificationService.*`)](#helm-werte-notificationservice)
  - [Grundkonfiguration](#grundkonfiguration)
  - [Pflichtwerte](#pflichtwerte)
  - [Image und Varianten](#image-und-varianten)
  - [Datenbank](#datenbank)
  - [Push-Gateway-Anbindung](#push-gateway-anbindung)
  - [Nachrichten-Historie (`historyEnabled`)](#nachrichten-historie-historyenabled)
  - [Sonstige Werte](#sonstige-werte)
- [Umgebungsvariablen des Dienstes](#umgebungsvariablen-des-dienstes)
- [Well-Known-Integration (RFC 9728)](#well-known-integration-rfc-9728)
- [NetworkPolicies](#networkpolicies)
- [Aktueller Stand und Einschränkungen](#aktueller-stand-und-einschränkungen)

## Übersicht: Split-Deployment und Datenbank

Der Dienst stellt zwei fachlich getrennte HTTP-APIs bereit, die aus **einem**
Quellcode-Stand als zwei Image-Varianten gebaut werden (die API-Auswahl ist in
das Image einkompiliert und zur Laufzeit nicht änderbar). Das Helm Chart
deployt bei aktiviertem Notification Service **beide** Varianten als getrennte
Deployments mit je einem ClusterIP-Service auf Port 8080:

| Variante | Image-Tag           | Deployment/Service         | API                                                                                                                     |
|----------|---------------------|----------------------------|--------------------------------------------------------------------------------------------------------------------------|
| `-rs`    | `<tag>-rs`          | `notification-service-rs`  | Resource-Server-API (`POST /notifications`, `GET /users/{userId}/channels`) — clusterintern vom Fachdienst aufgerufen  |
| `-fdv`   | `<tag>-fdv`         | `notification-service-fdv` | FdV-API (`/pushers`, `/channels`, `/history`) — hängt hinter dem PEP unter dem Pfadpräfix `/push/v1/`                   |

Auf der FdV-Seite prüft der PEP Access Token, DPoP-Bindung und Scopes; der
Dienst selbst vertraut der vom PEP weitergereichten Identität im
`zeta-user-info`-Header (Base64url-kodiertes JSON, mindestens das Feld
`identifier`). Die RS-API wird **nicht** über den PEP geroutet; die
Spezifikation verlangt hier die Authentifizierung eines technischen Nutzers
per mTLS. Der Dienst selbst terminiert dieses mTLS nicht
(`quarkus.http.ssl.client-auth: none`) — die Absicherung muss vorgelagert
erfolgen, z. B. durch das Service Mesh oder einen mTLS-terminierenden
Endpunkt innerhalb der Vertrauensgrenze.

Beide Varianten teilen sich eine **eigene** PostgreSQL-Datenbank, die getrennt
von der PDP-Datenbank (`keycloak-db`) betrieben wird. Im Standardmodus
`cloudnative` erzeugt das Chart dafür eine dedizierte CNPG-`Cluster`-Ressource
`notification-db` mit der Datenbank `notification`.

## Helm-Werte (`notificationService.*`)

Alle Werte liegen im Block `notificationService:` des
[ZETA Guard Helm Charts](Referenz_des_Helm_Charts.md).

### Grundkonfiguration

| Value                                | Standard | Beschreibung                                                                                           |
|--------------------------------------|----------|----------------------------------------------------------------------------------------------------------|
| `notificationService.enabled`        | `false`  | Zentraler Schalter: deployt beide Varianten, die Datenbank, die PEP-Locations und das Well-Known-Dokument |
| `notificationService.replicaCount`   | `1`      | Anzahl der Replikate (gilt je Variante)                                                                |
| `notificationService.serviceAccountName` | `""` | Wenn gesetzt, wird ein dedizierter ServiceAccount erzeugt (`automountServiceAccountToken: false`)      |
| `notificationService.podLabels`      | `{}`     | Zusätzliche Pod-Labels                                                                                 |
| `notificationService.podAnnotations` | `{}`     | Zusätzliche Pod-Annotationen                                                                           |
| `notificationService.affinity`       | `{}`     | Affinity-Regeln der Pods                                                                               |
| `notificationService.tolerations`    | `[]`     | Tolerations der Pods                                                                                   |
| `notificationService.imagePullPolicy`| `Always` | Image-Pull-Policy                                                                                      |
| `notificationService.imagePullSecrets` | `[]`   | Pull-Secrets für die Registry                                                                          |

### Pflichtwerte

Beide Werte haben **keinen Default**; fehlen sie, schlägt die
Konfigurationsvalidierung des Dienstes beim Start fehl:

| Value                                              | Standard | Beschreibung                                                                                                                                  |
|-----------------------------------------------------|----------|--------------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.env.pushGatewayAllowedBaseUrls` | `[]`   | Allowlist der Push-Gateway-Basis-URLs. Die `data.url` eines registrierten Pushers muss **exakt** (inklusive abschließendem `/`) einem Eintrag entsprechen, sonst wird der Versand vor jedem Aufruf als nicht vertrauenswürdiges Ziel abgelehnt. |
| `notificationService.env.channelsAllowed`           | `""`    | Kommaseparierte, statische Kanal-Registry (z. B. `epa.documents.new,epa.consent.changed`). Es gibt keine Laufzeit-Admin-API für Kanäle.        |

```yaml
zeta-guard:
    notificationService:
        enabled: true
        env:
            pushGatewayAllowedBaseUrls:
                - "https://push-gateway.example/push/v1/"
            channelsAllowed: "epa.documents.new,epa.consent.changed"
```

### Image und Varianten

| Value                                    | Standard               | Beschreibung                                                                                     |
|-------------------------------------------|------------------------|-----------------------------------------------------------------------------------------------------|
| `notificationService.image.repository`   | `notification-service` | Image-Repository (Registry-Präfix aus `global.registry_host` + `registry_name`, überschreibbar über `notificationService.image.registry`) |
| `notificationService.image.tag`          | `0.1.2`                | Gemeinsames Tag-Präfix; das Chart hängt pro Variante `-rs` bzw. `-fdv` an                        |
| `notificationService.rs.image.digest`    | `""`                   | Optionaler Digest-Pin der `-rs`-Variante                                                         |
| `notificationService.fdv.image.digest`   | `""`                   | Optionaler Digest-Pin der `-fdv`-Variante                                                        |

Ein variantenspezifisches Tag wird nicht unterstützt; nur der Digest ist pro
Variante pinbar.

### Datenbank

| Value                                   | Standard          | Beschreibung                                                                                                     |
|------------------------------------------|-------------------|-----------------------------------------------------------------------------------------------------------------|
| `notificationService.db.mode`           | `cloudnative`     | `cloudnative` erzeugt eine dedizierte CNPG-`Cluster`-Ressource; `external` verweist auf eine bestehende Postgres |
| `notificationService.db.clusterName`    | `notification-db` | Name des CNPG-Clusters; Service-, Secret- und NetworkPolicy-Namen leiten sich daraus ab                          |
| `notificationService.db.jdbcUrl`        | `""`              | JDBC-URL; leer im `cloudnative`-Modus → `jdbc:postgresql://<clusterName>-rw:5432/notification`                   |
| `notificationService.db.secretName`     | `""`              | Secret mit `username`/`password`; leer im `cloudnative`-Modus → `<clusterName>-app`                              |
| `notificationService.db.waitForDb.enabled` | `true`         | Init-Container (busybox, TCP-Check), der den Pod-Start bis zur Erreichbarkeit der Datenbank verzögert            |
| `notificationService.db.cloudnativePg.instances` | `1`      | Anzahl der Postgres-Instanzen                                                                                    |
| `notificationService.db.cloudnativePg.storage.size` | `2Gi` | Volume-Größe (weitere Felder: `storageClass`, `pvcTemplate`, optional `walStorage`)                              |
| `notificationService.db.cloudnativePg.parameters` | `sharedBuffers: 128MB`, `maxConnections: 100` | Postgres-Parameter; weitere über `extraParameters` |
| `notificationService.db.cloudnativePg.backup.enabled` | `false` | CNPG-Backup (Retention/Object Store über die Unterfelder)                                              |

Die CNPG-Ressource trägt die Annotation `helm.sh/resource-policy: keep` —
Cluster und PVC überleben fehlgeschlagene Upgrades und Rollbacks. Das hat eine
Kehrseite: Wird der Notification Service deaktiviert oder auf
`db.mode: external` umgestellt, bleiben Cluster und PVC verwaist zurück und
müssen vor einer Reaktivierung gelöscht werden, sonst wird eine Datenbank mit
möglicherweise veraltetem Schema übernommen.

### Push-Gateway-Anbindung

Das Push Gateway ist eine externe Komponente des App-Anbieters und wird
direkt über das Internet erreicht — nicht über das Service Mesh.

| Value                                                   | Standard  | Beschreibung                                                                                     |
|----------------------------------------------------------|-----------|---------------------------------------------------------------------------------------------------|
| `notificationService.pushGateway.trustedCAs`             | `[]`      | Zusätzliche CA(s) für das **Server**-Zertifikat des Push Gateway, ergänzend zu den System-Trust-Anchors. Pro Eintrag entweder `secretName`+`secretKey` (bestehendes Secret) oder ein Inline-`cert` (PEM). In Produktion leer lassen. |
| `notificationService.pushGateway.mtls.clientCert.secretName` | `""` | Secret mit dem PEM-Client-Zertifikat für ausgehendes mTLS zum Push Gateway                       |
| `notificationService.pushGateway.mtls.clientCert.secretKey`  | `tls.crt` | Key innerhalb des Secrets                                                                    |
| `notificationService.pushGateway.mtls.clientKey.secretName`  | `""` | Secret mit dem PEM-Private-Key                                                                    |
| `notificationService.pushGateway.mtls.clientKey.secretKey`   | `tls.key` | Key innerhalb des Secrets                                                                    |
| `notificationService.pushGateway.mtls.keyPassword.secretName`/`.secretKey` | `""` | Optionales Passwort eines verschlüsselten Private Keys (nur als Secret-Referenz)   |

mTLS ist aktiv, sobald `clientCert.secretName` **und** `clientKey.secretName`
gesetzt sind; nur einer von beiden bricht das Chart-Rendern mit einem Fehler
ab. Zertifikat und Schlüssel werden unter
`/certs/push-gateway-client/tls.{crt,key}` gemountet, die CAs unter
`/certs/push-gateway/ca-<i>.pem`. Die Hostname-Verifikation bleibt in allen
Fällen aktiv.

### Nachrichten-Historie (`historyEnabled`)

| Value                                | Standard | Beschreibung                                                                                                          |
|---------------------------------------|----------|------------------------------------------------------------------------------------------------------------------------|
| `notificationService.historyEnabled` | `false`  | Aktiviert die Nachrichten-Historie (A_29974): setzt `NOTIFICATION_HISTORY_ENABLED` am Dienst und nimmt den Scope `notification.history.read` in das Well-Known-Dokument auf |

Die Aktivierung der Historie ist laut Spezifikation eine Betreiber-Entscheidung
pro Fachdienst (A_29974). Bei deaktivierter Historie werden keine
Historien-Daten persistiert und die `/history/*`-Endpunkte liefern keine
Inhalte.

> **Wichtig — Kopplung an den Keycloak-Scope ist nicht automatisch:** Damit
> Clients den Scope `notification.history.read` überhaupt anfordern können,
> muss er in Keycloak existieren. Das erledigt die Terraform-Variable
> `notification_history_enabled` (Standard `false`) in
> `terraform/authserver`. Helm-Wert und Terraform-Variable sind **nicht**
> miteinander verdrahtet und müssen manuell synchron gehalten werden — ebenso
> `notificationService.wellKnownResourceSuffix` und die Terraform-Variable
> `notification_service_resource_suffix` (Standard `/notification-service`),
> aus der der Audience-Mapper der Notification-Scopes den `aud`-Wert bildet.

### Sonstige Werte

| Value                                  | Standard | Beschreibung                                                                                  |
|-----------------------------------------|----------|--------------------------------------------------------------------------------------------------|
| `notificationService.wellKnownResourceSuffix` | `/notification-service` | RFC-9728-Resource-Bezeichner (ein einzelnes Pfadsegment mit führendem `/`), siehe [unten](#well-known-integration-rfc-9728) |
| `notificationService.accessLog.enabled` | `false` | Quarkus-HTTP-Access-Log einschalten                                                           |
| `notificationService.accessLog.pattern` | `""`    | Log-Pattern (`QUARKUS_HTTP_ACCESS_LOG_PATTERN`); leer = Quarkus-Format „common"               |
| `notificationService.resources`         | Requests `50m`/`128Mi`, Limits `500m`/`512Mi` | Container-Ressourcen (je Variante)                              |
| `notificationService.containerSecurityContext` | PSS `restricted` | `readOnlyRootFilesystem: true` — `/tmp` ist ein beschreibbares emptyDir               |

## Umgebungsvariablen des Dienstes

Der Dienst ist eine Quarkus-Anwendung; jede Konfigurations-Property ist als
Umgebungsvariable überschreibbar (`push-gateway.allowed-base-urls` →
`PUSH_GATEWAY_ALLOWED_BASE_URLS`). Das Helm Chart setzt die mit ✔
gekennzeichneten Variablen selbst aus den oben beschriebenen Values.

| Umgebungsvariable                          | Standard    | Helm | Beschreibung                                                                                                       |
|---------------------------------------------|-------------|------|--------------------------------------------------------------------------------------------------------------------|
| `PUSH_GATEWAY_ALLOWED_BASE_URLS`            | — (Pflicht) | ✔    | Allowlist der Push-Gateway-Basis-URLs (kommasepariert); leer → Start schlägt fehl                                  |
| `NOTIFICATION_CHANNELS_ALLOWED`             | — (Pflicht) | ✔    | Statische Kanal-Registry (kommasepariert); leer → Start schlägt fehl                                               |
| `NOTIFICATION_HISTORY_ENABLED`              | `false`     | ✔    | Nachrichten-Historie schreiben und ausliefern                                                                      |
| `NOTIFICATION_PERSISTENCE_RETENTION`        | `PT24H`     |      | TTL der Notification-Verarbeitungsdaten — Benachrichtigungen und Idempotenz-Belege (A_29988), ISO-8601-Dauer       |
| `NOTIFICATION_PERSISTENCE_PURGE_INTERVAL`   | `5m`        |      | Löschintervall abgelaufener Datensätze. Der Purge nimmt einen Postgres-Advisory-Lock — Mehrinstanzbetrieb ist sicher |
| `NOTIFICATION_PERSISTENCE_SEALING_ENABLED`  | `false`     | ✔    | HSM-gestütztes Sealing der gespeicherten Daten — **nicht verwenden**, siehe Warnung unten                          |
| `NOTIFICATION_PSEUDONYMIZATION_HMAC_SECRET` | `change-me` |      | HMAC-Secret der Pseudonymisierung; wird nur bei aktiviertem Sealing gelesen                                        |
| `NOTIFICATION_DISPATCH_QUEUE_CAPACITY`      | `10000`     |      | Kapazität der In-Memory-Zustellwarteschlange; volle Queue → `503 SERVICE_UNAVAILABLE` bei der Einlieferung         |
| `APP_AUTH_USER_INFO_HEADER`                 | `zeta-user-info` |  | Name des Headers, aus dem die FdV-API die vom PEP etablierte Identität liest                                       |
| `PUSH_GATEWAY_CONNECT_TIMEOUT`              | `PT3S`      |      | Verbindungs-Timeout zum Push Gateway                                                                               |
| `PUSH_GATEWAY_READ_TIMEOUT`                 | `PT10S`     |      | Lese-Timeout zum Push Gateway                                                                                      |
| `PUSH_GATEWAY_RETRY_MAX_ATTEMPTS`           | `3`         |      | Gesamtzahl der Zustellversuche; nur transiente Fehler werden wiederholt                                            |
| `PUSH_GATEWAY_RETRY_INITIAL_DELAY`          | `PT1S`      |      | Erste Backoff-Wartezeit; verdoppelt sich je weiterem Versuch                                                       |
| `PUSH_GATEWAY_TRUSTED_CA_PATHS`             | —           | ✔    | PEM-CA-Dateien, die zusätzlich zu den System-Trust-Anchors vertraut werden                                         |
| `PUSH_GATEWAY_MTLS_CLIENT_CERTIFICATE_PATH` | —           | ✔    | PEM-Client-Zertifikat für mTLS zum Push Gateway                                                                    |
| `PUSH_GATEWAY_MTLS_CLIENT_KEY_PATH`         | —           | ✔    | PEM-Private-Key; nur zusammen mit dem Zertifikat gültig — nur einer von beiden bricht den Start ab                 |
| `PUSH_GATEWAY_MTLS_CLIENT_KEY_PASSWORD`     | —           | ✔    | Passwort eines verschlüsselten Private Keys                                                                        |
| `QUARKUS_DATASOURCE_JDBC_URL` / `_USERNAME` / `_PASSWORD` | — | ✔ | PostgreSQL-Verbindung; Flyway migriert das Schema beim Start                                                       |
| `NOTIFICATION_API_RS_ENABLED` / `NOTIFICATION_API_FDV_ENABLED` | `true` | | **Build-Zeit**-Schalter der API-Auswahl — wirken nur beim Bauen des Images, nicht zur Laufzeit. Die Varianten `-rs`/`-fdv` sind damit vorgebaut |

> [!WARNING]
> **Sealing, Per-Record-DEK und Pseudonymisierung Stubs ohne Wirkung und
> nicht produktionsreif.** Im Standardbetrieb
> (`NOTIFICATION_PERSISTENCE_SEALING_ENABLED=false`) sind Pseudonymisierung
> und Payload-Verschlüsselung No-Ops: Nutzerkennungen (KVNR/Telematik-ID) und
> Payloads liegen — abgesehen von Schutzmaßnahmen auf Datenbank- bzw.
> Storage-Ebene — **unverschlüsselt** in der Datenbank.
> Betreiben Sie den Dienst nur in Umgebungen, deren Schutzbedarf das
> zulässt

## Well-Known-Integration (RFC 9728)

Der Notification Service ist gegenüber den Clients eine eigene geschützte
Ressource: Bei aktiviertem Notification Service liefert der PEP unter
`/.well-known/oauth-protected-resource<wellKnownResourceSuffix>` ein zweites
OAuth Protected Resource Metadata Dokument nach RFC 9728 aus. Dessen
`resource`-Feld ist zugleich die Audience, die der PEP an den
`/push/v1/`-Locations erzwingt — ein für den Fachdienst ausgestelltes Token
wird am Notification Service abgelehnt und umgekehrt. Der Scope
`notification.history.read` erscheint nur bei `historyEnabled: true`.

Aufbau, Konkatenationsmodell und Prüfbefehle sind beschrieben in
[Konfiguration der Well-Known-Endpunkte — Well-Known-Dokument des Notification Service](Konfiguration_der_Well-Known_Endpunkte.md#well-known-dokument-des-notification-service).

## NetworkPolicies

Bei aktivierten Egress-NetworkPolicies (`networkPolicy.enabled: true`) erzeugt
das Chart pro Variante eine Egress-Policy
(`notification-service-<variant>-egress`) mit drei Regeln: DNS, die eigene
Postgres (Port 5432, nur im `cloudnative`-Modus) und — sofern
`pushGatewayAllowedBaseUrls` gesetzt ist — Port 443 zu den IP-Blöcken aus
`networkPolicy.egress.providerInternal.resourceServers.ipBlocks`. Ein
Push Gateway, das clusterintern oder über einen Proxy erreicht wird, benötigt
eine eigene zusätzliche Regel. Details siehe
[Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md).
Eingehender Verkehr ist über die Egress-Regeln von PEP (FdV-Variante) bzw.
Resource Server (RS-Variante) abgedeckt.

## Aktueller Stand und Einschränkungen

- **Vorschau:** Der Notification Service ist im Helm Chart standardmäßig
  deaktiviert und wird pro Stage bewusst eingeschaltet.
- **Sealing/Pseudonymisierung sind Stubs** — siehe Warnung oben. Daten liegen
  bis auf DB-Ebene unverschlüsselt vor; das HMAC-Secret der (inaktiven)
  Pseudonymisierung stammt aus der Konfiguration statt aus einem Keystore.
- **Nur der unverschlüsselte Zustellpfad wird genutzt:** Der Client für den
  verschlüsselten Push-Gateway-Endpunkt (`notifyEncrypted/batch`) existiert,
  wird vom Dispatch aber nicht aufgerufen. Das optionale `reference`-Feld
  wird persistiert, auf dem unverschlüsselten Pfad jedoch nicht an das
  Push Gateway weitergereicht.
- **RS-API ohne eigene mTLS-Terminierung:** Die von der Spezifikation
  geforderte mTLS-Authentifizierung des technischen Nutzers muss vorgelagert
  sichergestellt werden; das Chart bringt dafür keine eigene Konfiguration
  mit.
- Das im Helm-Repository mitgelieferte `push-gateway`-Subchart ist ein reines
  Test-/Demo-Deployment ohne Authentifizierung und darf nicht produktiv
  betrieben werden. Für produktionsreife Push-Gateway Deployments nutzen Sie
  das von der Gematik bereitgestellte Push-Gateway Helm Chart.
