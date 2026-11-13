# Konfiguration des Notification Service

Der Notification Service ist die Push-Benachrichtigungs-Fassade des ZETA-Guard:
Ein Fachdienst (Resource Server) übergibt ihm eine Benachrichtigung für einen
Nutzer und einen Kanal, der Dienst ermittelt die registrierten Geräte mit
aktivem Kanal und leitet den Push asynchron an das Push Gateway der gematik
weiter, das seinerseits APNs bzw. FCM anspricht. Mobile Clients erreichen den
Dienst über das ZETA-SDK, um ihre Push-Ziele (Pusher) zu registrieren, Kanäle
zu schalten und optional ihre Nachrichten-Historie zu lesen.

Der Notification Service ist Teil der Umsetzungsstufe 2 und wird als
**Vorschau** ausgeliefert: Er ist im Helm-Chart **standardmäßig deaktiviert**
(`notificationService.enabled: false`). Die Einschränkungen des aktuellen Stands sind
[unten](#aktueller-stand-und-einschränkungen) beschrieben.

Zielgruppe sind primär Betreiber von Fachdiensten; der Abschnitt zu den
Umgebungsvariablen richtet sich auch an Fachdienst-Hersteller, die den Dienst
außerhalb des Helm-Charts betreiben oder integrieren.

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
  - [Datenschutz: Sealing, HSM und verschlüsselter Push](#datenschutz-sealing-hsm-und-verschlüsselter-push)
  - [Sonstige Werte](#sonstige-werte)
- [Umgebungsvariablen des Dienstes](#umgebungsvariablen-des-dienstes)
- [Well-Known-Integration (RFC 9728)](#well-known-integration-rfc-9728)
- [NetworkPolicies](#networkpolicies)
- [Aktueller Stand und Einschränkungen](#aktueller-stand-und-einschränkungen)

## Übersicht: Split-Deployment und Datenbank

Der Dienst stellt zwei fachlich getrennte HTTP-APIs bereit, die aus **einem**
Quellcode-Stand als zwei Image-Varianten gebaut werden (die API-Auswahl ist in
das Image einkompiliert und zur Laufzeit nicht änderbar). Das Helm-Chart
deployt bei aktiviertem Notification Service **beide** Varianten als getrennte
Deployments mit je einem ClusterIP-Service auf Port 8080:

| Variante | Image-Tag   | Deployment/Service         | API                                                                                                                   |
|----------|-------------|----------------------------|-----------------------------------------------------------------------------------------------------------------------|
| `-rs`    | `<tag>-rs`  | `notification-service-rs`  | Resource-Server-API (`POST /notifications`, `GET /users/{userId}/channels`) — clusterintern vom Fachdienst aufgerufen |
| `-fdv`   | `<tag>-fdv` | `notification-service-fdv` | FdV-API (`/pushers`, `/channels`, `/history`) — hängt hinter dem PEP unter dem Pfadpräfix `/push/v1/`                 |

Auf der FdV-Seite prüft der PEP Access-Token, DPoP-Bindung und Scopes; der
Dienst selbst vertraut der vom PEP weitergereichten Identität im
`zeta-user-info`-Header (Base64url-kodiertes JSON, mindestens das Feld
`identifier`). Die RS-API wird **nicht** über den PEP geroutet; der öffentliche
Ingress beantwortet `/notification-service-rs` samt Unterpfaden mit `404`. Die
Spezifikation verlangt hier die Authentifizierung eines technischen Nutzers
per mTLS (A_29980): Mit `notificationService.rs.mtls.enabled: true` (Standard)
verlangt die RS-API ein Client-Zertifikat aus ihrem Truststore und antwortet
ohne ein solches mit `401`. Das Chart konfiguriert für die RS-API weder
Serverzertifikat noch Truststore; mit dem Standardwert wird daher jeder
RS-Aufruf abgelehnt. Bis Sie TLS selbst bereitstellen, setzen Sie
`notificationService.rs.mtls.enabled: false` und sichern den Zugang zum
internen Service `notification-service-rs` vorgelagert ab, z. B. mTLS über ein
Service Mesh und eine eigene NetworkPolicy — das Chart bringt für eingehenden
Verkehr zur RS-API keine mit.

Beide Varianten teilen sich eine **eigene** PostgreSQL-Datenbank, die getrennt
von der PDP-Datenbank (`keycloak-db`) betrieben wird. Im Standardmodus
`cloudnative` erzeugt das Chart dafür eine dedizierte CNPG-`Cluster`-Ressource
`notification-db` mit der Datenbank `notification`.

## Helm-Werte (`notificationService.*`)

Alle Werte liegen im Block `notificationService:` des
[ZETA-Guard-Helm-Charts](Referenz_des_Helm_Charts.md).

### Grundkonfiguration

| Value                                    | Standard | Beschreibung                                                                                              |
|------------------------------------------|----------|-----------------------------------------------------------------------------------------------------------|
| `notificationService.enabled`            | `false`  | Zentraler Schalter: deployt beide Varianten, die Datenbank, die PEP-Locations und das Well-Known-Dokument |
| `notificationService.replicaCount`       | `1`      | Anzahl der Replikate (gilt je Variante)                                                                   |
| `notificationService.serviceAccountName` | `""`     | Wenn gesetzt, wird ein dedizierter ServiceAccount erzeugt (`automountServiceAccountToken: false`)         |
| `notificationService.podLabels`          | `{}`     | Zusätzliche Pod-Labels                                                                                    |
| `notificationService.podAnnotations`     | `{}`     | Zusätzliche Pod-Annotationen                                                                              |
| `notificationService.affinity`           | `{}`     | Affinity-Regeln der Pods                                                                                  |
| `notificationService.tolerations`        | `[]`     | Tolerations der Pods                                                                                      |
| `notificationService.imagePullPolicy`    | `Always` | Image-Pull-Policy                                                                                         |
| `notificationService.imagePullSecrets`   | `[]`     | Pull-Secrets für die Registry                                                                             |

### Pflichtwerte

Beide Werte haben **keinen Default**; fehlen sie, schlägt die
Konfigurationsvalidierung des Dienstes beim Start fehl:

| Value                                                | Standard | Beschreibung                                                                                                                                                                                                                                    |
|------------------------------------------------------|----------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.env.pushGatewayAllowedBaseUrls` | `[]`     | Allowlist der Push-Gateway-Basis-URLs. Die `data.url` eines registrierten Pushers muss **exakt** (inklusive abschließendem `/`) einem Eintrag entsprechen, sonst wird der Versand vor jedem Aufruf als nicht vertrauenswürdiges Ziel abgelehnt. |
| `notificationService.env.channelsAllowed`            | `""`     | Kommaseparierte, statische Kanal-Registry (z. B. `epa.documents.new,epa.consent.changed`). Es gibt keine Laufzeit-Admin-API für Kanäle.                                                                                                         |

```yaml
notificationService:
    enabled: true
    env:
        pushGatewayAllowedBaseUrls:
            - "https://push-gateway.example/push/v1/"
        channelsAllowed: "epa.documents.new,epa.consent.changed"
```

### Image und Varianten

| Value                                  | Standard               | Beschreibung                                                                                                                              |
|----------------------------------------|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.image.repository` | `notification-service` | Image-Repository (Registry-Präfix aus `global.registry_host` + `registry_name`, überschreibbar über `notificationService.image.registry`) |
| `notificationService.image.tag`        | `2.0.2`                | Gemeinsames Tag-Präfix; das Chart hängt pro Variante `-rs` bzw. `-fdv` an                                                                 |
| `notificationService.rs.image.tag`     | `""`                   | Variantenspezifisches Tag der `-rs`-Variante; ersetzt das gemeinsame Tag unverändert (kein Suffix)                                        |
| `notificationService.fdv.image.tag`    | `""`                   | Variantenspezifisches Tag der `-fdv`-Variante; ersetzt das gemeinsame Tag unverändert (kein Suffix)                                       |
| `notificationService.rs.image.digest`  | `""`                   | Optionaler Digest-Pin der `-rs`-Variante (wird als `@<digest>` angehängt)                                                                 |
| `notificationService.fdv.image.digest` | `""`                   | Optionaler Digest-Pin der `-fdv`-Variante (wird als `@<digest>` angehängt)                                                                |

Ein variantenspezifisches Tag wird erst ab Chart 1.3.2 berücksichtigt; in
1.3.0/1.3.1 wurde `rs.image.tag`/`fdv.image.tag` ignoriert und nur der Digest
war pro Variante pinbar.

### Datenbank

| Value                                                 | Standard                                      | Beschreibung                                                                                                                                                                                                                                                                                             |
|-------------------------------------------------------|-----------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.db.mode`                         | `cloudnative`                                 | `cloudnative` erzeugt eine dedizierte CNPG-`Cluster`-Ressource; `external` verweist auf eine bestehende Datenbank                                                                                                                                                                                        |
| `notificationService.db.kind`                         | `postgresql`                                  | Datenbank-Typ (`postgresql`, `mariadb`, `mysql`, `mssql`, `oracle`), gesetzt als `NOTIFICATION_DATASOURCE_DB_KIND`. Das Image leitet die Engine sonst aus dem JDBC-URL-Präfix ab; nötig ist der Wert nur bei mehrdeutiger URL (z. B. MariaDB über `jdbc:mysql:`). `cloudnative` erlaubt nur `postgresql` |
| `notificationService.db.clusterName`                  | `notification-db`                             | Name des CNPG-Clusters; Service-, Secret- und NetworkPolicy-Namen leiten sich daraus ab                                                                                                                                                                                                                  |
| `notificationService.db.jdbcUrl`                      | `""`                                          | JDBC-URL; leer im `cloudnative`-Modus → `jdbc:postgresql://<clusterName>-rw:5432/notification`                                                                                                                                                                                                           |
| `notificationService.db.secretName`                   | `""`                                          | Secret mit `username`/`password`; leer im `cloudnative`-Modus → `<clusterName>-app`                                                                                                                                                                                                                      |
| `notificationService.db.waitForDb.enabled`            | `true`                                        | Init-Container (busybox, TCP-Check), der den Pod-Start bis zur Erreichbarkeit der Datenbank verzögert                                                                                                                                                                                                    |
| `notificationService.db.cloudnativePg.instances`      | `1`                                           | Anzahl der Postgres-Instanzen                                                                                                                                                                                                                                                                            |
| `notificationService.db.cloudnativePg.storage.size`   | `2Gi`                                         | Volume-Größe (weitere Felder: `storageClass`, `pvcTemplate`, optional `walStorage`)                                                                                                                                                                                                                      |
| `notificationService.db.cloudnativePg.parameters`     | `sharedBuffers: 128MB`, `maxConnections: 100` | Postgres-Parameter; weitere über `extraParameters`                                                                                                                                                                                                                                                       |
| `notificationService.db.cloudnativePg.backup.enabled` | `false`                                       | CNPG-Backup (Retention/Object Store über die Unterfelder)                                                                                                                                                                                                                                                |

Die CNPG-Ressource trägt die Annotation `helm.sh/resource-policy: keep` —
Cluster und PVC überleben fehlgeschlagene Upgrades und Rollbacks. Das hat eine
Kehrseite: Wird der Notification Service deaktiviert oder auf
`db.mode: external` umgestellt, bleiben Cluster und PVC verwaist zurück und
müssen vor einer Reaktivierung gelöscht werden, sonst wird eine Datenbank mit
möglicherweise veraltetem Schema übernommen.

### Push-Gateway-Anbindung

Das Push Gateway ist eine externe Komponente des App-Anbieters und wird
direkt über das Internet erreicht — nicht über das Service Mesh.

| Value                                                                      | Standard  | Beschreibung                                                                                                                                                                                                                         |
|----------------------------------------------------------------------------|-----------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.pushGateway.trustedCAs`                               | `[]`      | Zusätzliche CA(s) für das **Server**-Zertifikat des Push Gateway, ergänzend zu den System-Trust-Anchors. Pro Eintrag entweder `secretName`+`secretKey` (bestehendes Secret) oder ein Inline-`cert` (PEM). In Produktion leer lassen. |
| `notificationService.pushGateway.mtls.clientCert.secretName`               | `""`      | Secret mit dem PEM-Client-Zertifikat für ausgehendes mTLS zum Push Gateway                                                                                                                                                           |
| `notificationService.pushGateway.mtls.clientCert.secretKey`                | `tls.crt` | Key innerhalb des Secrets                                                                                                                                                                                                            |
| `notificationService.pushGateway.mtls.clientKey.secretName`                | `""`      | Secret mit dem PEM-Private-Key                                                                                                                                                                                                       |
| `notificationService.pushGateway.mtls.clientKey.secretKey`                 | `tls.key` | Key innerhalb des Secrets                                                                                                                                                                                                            |
| `notificationService.pushGateway.mtls.keyPassword.secretName`/`.secretKey` | `""`      | Optionales Passwort eines verschlüsselten Private Keys (nur als Secret-Referenz)                                                                                                                                                     |

mTLS ist aktiv, sobald `clientCert.secretName` **und** `clientKey.secretName`
gesetzt sind; nur einer von beiden bricht das Chart-Rendern mit einem Fehler
ab. Zertifikat und Schlüssel werden unter
`/certs/push-gateway-client/tls.{crt,key}` gemountet, die CAs unter
`/certs/push-gateway/ca-<i>.pem`. Die Hostname-Verifikation bleibt in allen
Fällen aktiv.

### Nachrichten-Historie (`historyEnabled`)

| Value                                  | Standard                 | Beschreibung                                                                                                                                                                                                   |
|----------------------------------------|--------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.historyEnabled`   | `false`                  | Aktiviert die Nachrichten-Historie (A_29974): setzt `NOTIFICATION_HISTORY_ENABLED` am Dienst und nimmt den Scope `notification.history.read` in das Well-Known-Dokument auf                                    |
| `notificationService.historyRetention` | nicht gesetzt (→ `P30D`) | Aufbewahrungsfrist der Historie eines Geräts, gerechnet ab ihrem ersten Eintrag; setzt `NOTIFICATION_HISTORY_RETENTION`. ISO-8601 (`P30D`, `PT720H`) oder Quarkus-Kurzform (`30d`, `720h`), nur positive Werte |

Die Aktivierung der Historie ist laut Spezifikation eine Betreiber-Entscheidung
pro Fachdienst (A_29974). Bei deaktivierter Historie werden keine
Historien-Daten persistiert. Ein Client erhält auf beiden `/history/*`-Endpunkten
bereits vom PEP `403`, weil der Scope `notification.history.read` nicht
ausgestellt wird; der Dienst selbst antwortet `404` mit dem Fehlercode
`HISTORY_DISABLED`. Diese `404` sieht ein Client nur, wenn der Scope dennoch
existiert, also Helm-Wert und Terraform-Variable (siehe unten) auseinanderlaufen.
Die `404` entspricht A_29974 (`404`/`501`); die FdV-Schnittstellenbeschreibung
sieht für diese Endpunkte dagegen nur `200` und `400` vor.

Jedes Gerät bzw. jeder Pushkey hat eine separate Historie. Es können keine
einzelnen Benachrichtigungen aus einer Historie gelöscht werden, und jede
Historie kann nur als Ganzes gelöscht werden. Ist `historyRetention` verstrichen,
nachdem eine Historie angelegt wurde, wird sie gelöscht, und die nächste
Benachrichtigung startet eine neue Historie. Die Historie ist von der kurzen
Aufbewahrungsfrist der Verarbeitungsdaten ausgenommen; ihre Aufbewahrung
richtet sich nach der Betreiber-Konfiguration (A_29988). Unabhängig von der
Frist löscht der Dienst die Historie eines Geräts, sobald der Nutzer keinen
Pusher mit dem Pushkey dieses Geräts mehr registriert hat — bei der Abmeldung
des Pushers oder wenn das Push-Gateway den Pushkey ablehnt. A_29989 verlangt bei der Abmeldung nur das
Löschen von Push-Konfiguration und Schlüsselmaterial; die Historie löscht der
Dienst darüber hinaus mit. Eine erneute Registrierung desselben Pushkeys beginnt
mit leerer Historie. Gelöscht wird auch bei deaktivierter Historie, sodass beim
Abschalten keine Altdaten erhalten bleiben.

> **Wichtig — Kopplung an den Keycloak-Scope ist nicht automatisch:** Damit
> Clients den Scope `notification.history.read` überhaupt anfordern können,
> muss er in Keycloak existieren. Das erledigt die Terraform-Variable
> `notification_history_enabled` (Standard `false`) in
> `terraform/authserver`. Helm-Wert und Terraform-Variable sind **nicht**
> miteinander verdrahtet und müssen manuell synchron gehalten werden — ebenso
> `notificationService.wellKnownResourceSuffix` und die Terraform-Variable
> `notification_service_resource_suffix` (Standard `/notification-service`),
> aus der der Audience-Mapper der Notification-Scopes den `aud`-Wert bildet.

### Datenschutz: Sealing, HSM und verschlüsselter Push

**Sealing** verschlüsselt die gespeicherten Payloads und pseudonymisiert die
Speicher-IDs per HMAC. Die Schlüssel stammen aus einer
[Keychain](#keychain): Jeder Eintrag enthält einen DEK und einen
Pseudonymisierungsschlüssel, gemeinsam unter einem KEK im HSM gekapselt,
angesprochen über den HSM Proxy. Jede Instanz entpackt die Einträge einmal beim
ersten Zugriff; Lese- und Schreibzugriffe rufen das HSM danach nicht mehr auf.
Für jeden Datensatz leitet der Dienst aus dem DEK und einem zufälligen Salt
einen eigenen Schlüssel ab (HKDF-Expand). A_29957 erlaubt diese Speicherung
nur innerhalb einer VAU (Variante A). Ohne VAU (Variante B) muss Sealing aus
bleiben; die Instanz darf dann keine personenbezogenen Kennungen (KVNR,
Telematik-ID) persistieren.

**Verschlüsselter Push** (A_29968) bestimmt, ob Benachrichtigungen
Ende-zu-Ende-verschlüsselt an das Push Gateway gehen. Die Entscheidung trifft
der Betreiber, nicht der Fachdienst; Instanzen für ePA und E-Rezept müssen mit
`true` laufen. Dann muss jede Pusher-Registrierung einen `encryption`-Block
enthalten, Geräte ohne Schlüsselmaterial werden übersprungen statt im Klartext
beliefert, und eine Payload über 1018 Bytes (serialisiert) wird mit
`413 PAYLOAD_TOO_LARGE` abgelehnt. Der Dienst ruft dann ausschließlich den
verschlüsselten Endpunkt des Push Gateway auf (`POST <base-url>notifyEncrypted/batch`).
Bei `false` verwirft er mitgeliefertes Schlüsselmaterial schon bei der
Registrierung und nutzt `notify/batch`.

> **Umschalten einer laufenden Installation:** Pusher, die bei `false`
> registriert wurden, haben kein Schlüsselmaterial gespeichert. Nach dem
> Umschalten auf `true` werden diese Geräte übersprungen, bis sie sich erneut
> registrieren. Das Push Gateway muss den verschlüsselten Batch-Endpunkt
> bereitstellen.

| Value                                                             | Standard                          | Beschreibung                                                                                                                                                                                                      |
|-------------------------------------------------------------------|-----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.env.encryptionEnabled`                       | `false`                           | Verschlüsselter Push (`NOTIFICATION_ENCRYPTION_ENABLED`)                                                                                                                                                          |
| `notificationService.sealing.enabled`                             | `false`                           | Sealing der gespeicherten Daten (`NOTIFICATION_PERSISTENCE_SEALING_ENABLED`); verlangt `notificationService.hsm.endpoint`                                                                                         |
| `notificationService.sealing.keychainFileName`                    | `/keychain/keychain.json`         | Absoluter Pfad der Keychain-Datei (`NOTIFICATION_PERSISTENCE_SEALING_KEYCHAIN_FILE`)                                                                                                                              |
| `notificationService.sealing.rotationInterval`                    | `null`                            | Intervall, in dem der Dienst Datensätze älterer Keychain-Einträge auf den aktuellen umzieht (`NOTIFICATION_PERSISTENCE_SEALING_ROTATION_INTERVAL`); nicht gesetzt → Dienst-Default `1h`                           |
| `notificationService.sealing.initContainerProvideKeys`            | `{}`                              | Container-Spec eines Init-Containers, der eine vorhandene Keychain unter `keychainFileName` ablegt; leer → keiner                                                                                                 |
| `notificationService.sealing.initContainerStoreKeys`              | `{}`                              | Container-Spec eines Init-Containers, der die Keychain unter `keychainFileName` speichert; leer → keiner                                                                                                          |
| `notificationService.sealing.keychainGenerator.enabled`           | `true`                            | Init-Container, der über den HSM Proxy eine erste Keychain erzeugt, wenn unter `keychainFileName` noch keine liegt; nur abschalten, wenn `initContainerProvideKeys` die Keychain immer bereitstellt               |
| `notificationService.sealing.keychainGenerator.kekId`             | `""`                              | KEK, unter dem eine neue Keychain gekapselt wird (`HSM_PROXY_KEK_ID`), Schema `[component]-[purpose]-[algorithm]-v<N>`, z. B. `notification-service-keychain-kek-aesgcm-v1`; Pflicht, solange der Generator läuft |
| `notificationService.sealing.keychainGenerator.image.repository`  | `notification-keychain-generator` | Image-Repository des Keychain-Generators; Registry wie `notificationService.image`                                                                                                                                |
| `notificationService.sealing.keychainGenerator.image.tag`         | `2.0.2`                           | Image-Tag des Keychain-Generators; leer → `notificationService.image.tag` (ohne Varianten-Suffix)                                                                                                                 |
| `notificationService.sealing.keychainGenerator.extraVolumeMounts` | `[]`                              | Volume-Mounts des Keychain-Generators, z. B. für die Keychain                                                                                                                                                     |
| `notificationService.extraVolumes`                                | `[]`                              | Zusätzliche Volumes der Notification-Service-Pods, z. B. ein Secret mit der Keychain                                                                                                                              |
| `notificationService.extraVolumeMounts`                           | `[]`                              | Zusätzliche Volume-Mounts des Notification-Service-Containers, z. B. für die Keychain (read-only genügt)                                                                                                          |
| `notificationService.hsm.endpoint`                                | `""`                              | `host:port` des HSM Proxy (`HSM_PROXY_ENDPOINT`), für Dienst und Keychain-Generator                                                                                                                               |
| `notificationService.hsm.plainTextAccepted`                       | `null`                            | Unverschlüsselten gRPC-Kanal zum HSM Proxy zulassen (`HSM_PROXY_PLAIN_TEXT_ACCEPTED`); bei aktiviertem Sealing derzeit erforderlich, siehe unten                                                                  |

`sealing.enabled: true` verlangt `hsm.endpoint` und, solange der Generator
läuft, `sealing.keychainGenerator.kekId`. Eine Software-Alternative gibt es
nicht; fehlt einer der Werte, bricht das Chart-Rendering ab.

Der Client zum HSM Proxy spricht nur unverschlüsseltes gRPC (mTLS nach A_28830
ist dort nicht umgesetzt). Mit aktiviertem Sealing startet der Dienst daher nur
mit `hsm.plainTextAccepted: true`; den Kanal muss dann das Netzwerk schützen.

Der frühere Value `notificationService.env.persistenceSealingEnabled` heißt
jetzt `notificationService.sealing.enabled`. Die Values
`notificationService.hsm.kek.dekKeyId`, `notificationService.hsm.kek.pseudonymKeyId`
und `notificationService.sealing.dekCacheSize` entfallen ab Chart-Version 2.0.2
mit der Keychain. Ist einer der alten Pfade noch gesetzt, bricht das
Chart-Rendering mit einem Hinweis ab.

> **Breaking ab Chart-Version 2.0.2 bei aktiviertem Sealing:** Datensätze, die
> ein früherer Build des Notification Service versiegelt hat, lassen sich nicht
> mehr öffnen, ihre Speicher-IDs passen nicht mehr. Starten Sie mit einer
> leeren Datenbank.

#### Keychain

Der Dienst liest die Keychain aus der Datei `sealing.keychainFileName`. Ein
Volume dafür bringt das Chart nicht mit: Legen Sie die Keychain auf ein Volume
Ihrer Wahl in `notificationService.extraVolumes`, typischerweise ein Secret.
Hängen Sie es über `notificationService.extraVolumeMounts` in den Dienst
(read-only genügt) und über `sealing.keychainGenerator.extraVolumeMounts` in
den Keychain-Generator ein. Die Init-Container laufen in dieser Reihenfolge:

1. `sealing.initContainerProvideKeys` (optional): ein eigener Container, der
   die vorhandene Keychain unter `keychainFileName` ablegt, z. B. aus einem
   Secret Store.
2. `keychain-generator`: erzeugt über den HSM Proxy eine Keychain mit einem
   ersten Eintrag, gekapselt unter `keychainGenerator.kekId`, wenn unter
   `keychainFileName` noch keine Datei liegt; andernfalls tut er nichts.
3. `sealing.initContainerStoreKeys` (optional): ein eigener Container, der die
   Keychain unter `keychainFileName` speichert.

```yaml
notificationService:
  sealing:
    keychainGenerator:
      kekId: "notification-service-keychain-kek-aesgcm-v1"
      extraVolumeMounts:
        - name: notification-keychain
          mountPath: /keychain
  extraVolumes:
    - name: notification-keychain
      secret:
        secretName: notification-service-keychain   # Key keychain.json
  extraVolumeMounts:
    - name: notification-keychain
      mountPath: /keychain
      readOnly: true
```

Beide API-Varianten (`rs`, `fdv`) und alle Replicas teilen sich eine Datenbank
und müssen deshalb dieselbe Keychain verwenden. Mit einem Secret, das die
Keychain enthält, ist das gegeben. Soll stattdessen der Generator die Keychain
beim ersten Start erzeugen, braucht es ein beschreibbares Volume und einen
Store-Hook. Dieser muss maßgeblich sein: Er speichert die Keychain nur, wenn
noch keine gespeichert ist, und ersetzt andernfalls die lokale durch die
gespeicherte. So übernimmt ein Pod, der beim allerersten Start das Rennen
verliert, die Keychain des Gewinners. Ohne all das kann der Generator die
Keychain nicht auf das schreibgeschützte Root-Dateisystem schreiben, und der
Pod startet nicht.

Der Keychain-Generator benötigt im HSM die Berechtigung `Encrypt` auf dem KEK,
der Dienst nur `Decrypt`.

**Schlüsselrotation** (A_29963, A_29960) steuert das Chart nicht: Erzeugen Sie
den nächsten Keychain-Eintrag mit dem Keychain-Generator außerhalb des Clusters
(Runbook „Key rotation“ im README des Notification Service), legen Sie die
erweiterte Keychain in Ihrem Store ab und rollen Sie beide Deployments neu aus.
Ein neuer Eintrag übernimmt ab seinem `activeFrom` die Schreibzugriffe. Ein
Rotationsjob zieht die Datensätze älterer Einträge eine Minute nach dem Start
und danach alle `sealing.rotationInterval` (Standard `1h`) auf den neuen
Eintrag um.

Mit aktiviertem Sealing meldet die Readiness-Prüfung `keychain` (bisher
`hsm-proxy`), ob die Keychain entpackt ist und den Eintrag jedes noch gültigen
Datensatzes enthält. Eine defekte Keychain oder ein alter Eintrag, der entfernt
wurde, solange noch Datensätze unter ihm liegen, hält einen Rollout bei der
ersten Instanz an. Ein Ausfall des HSM Proxy nimmt Instanzen, die ihre
Schlüssel bereits halten, nicht mehr aus dem Betrieb.

### Sonstige Werte

| Value                                          | Standard                                      | Beschreibung                                                                                                                                                                |
|------------------------------------------------|-----------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `notificationService.rs.mtls.enabled`          | `true`                                        | Client-Zertifikatsprüfung der RS-API (A_29980, `QUARKUS_HTTP_AUTH_PERMISSION_RS_ENABLED`, nur Variante `-rs`); siehe [Übersicht](#übersicht-split-deployment-und-datenbank) |
| `notificationService.wellKnownResourceSuffix`  | `/notification-service`                       | RFC-9728-Resource-Bezeichner (ein einzelnes Pfadsegment mit führendem `/`), siehe [unten](#well-known-integration-rfc-9728)                                                 |
| `notificationService.accessLog.enabled`        | `false`                                       | Quarkus-HTTP-Access-Log einschalten                                                                                                                                         |
| `notificationService.accessLog.pattern`        | `""`                                          | Log-Pattern (`QUARKUS_HTTP_ACCESS_LOG_PATTERN`); leer = Quarkus-Format „common“                                                                                             |
| `notificationService.resources`                | Requests `50m`/`128Mi`, Limits `500m`/`512Mi` | Container-Ressourcen (je Variante)                                                                                                                                          |
| `notificationService.containerSecurityContext` | `{}`                                          | Abweichungen von `defaultContainerSecurityContext`; Root-Dateisystem read-only — `/tmp` ist ein beschreibbares emptyDir                                                     |

## Umgebungsvariablen des Dienstes

Der Dienst ist eine Quarkus-Anwendung; jede Konfigurations-Property ist als
Umgebungsvariable überschreibbar (`push-gateway.allowed-base-urls` →
`PUSH_GATEWAY_ALLOWED_BASE_URLS`). Das Helm-Chart setzt die mit ✔
gekennzeichneten Variablen selbst aus den oben beschriebenen Values.

| Umgebungsvariable                                              | Standard          | Helm | Beschreibung                                                                                                                                                                   |
|----------------------------------------------------------------|-------------------|------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `PUSH_GATEWAY_ALLOWED_BASE_URLS`                               | — (Pflicht)       | ✔    | Allowlist der Push-Gateway-Basis-URLs (kommasepariert); leer → Start schlägt fehl                                                                                              |
| `NOTIFICATION_CHANNELS_ALLOWED`                                | — (Pflicht)       | ✔    | Statische Kanal-Registry (kommasepariert); leer → Start schlägt fehl                                                                                                           |
| `NOTIFICATION_HISTORY_ENABLED`                                 | `false`           | ✔    | Nachrichten-Historie schreiben und ausliefern                                                                                                                                  |
| `NOTIFICATION_HISTORY_RETENTION`                               | `P30D`            | ✔    | Aufbewahrungsfrist der Historie eines Geräts ab ihrem ersten Eintrag; vom Chart nur gesetzt, wenn `historyRetention` gesetzt ist                                               |
| `NOTIFICATION_PERSISTENCE_RETENTION`                           | `PT24H`           |      | TTL der Notification-Verarbeitungsdaten — Benachrichtigungen und Idempotenz-Belege (A_29988), ISO-8601-Dauer                                                                   |
| `NOTIFICATION_PERSISTENCE_PURGE_INTERVAL`                      | `5m`              |      | Löschintervall abgelaufener Datensätze. Der Purge sichert sich eine Lease per Compare-and-Set — Mehrinstanzbetrieb ist sicher                                                  |
| `NOTIFICATION_PERSISTENCE_SEALING_ENABLED`                     | `false`           | ✔    | HSM-gestütztes Sealing der gespeicherten Daten, nur in einer VAU, siehe [Datenschutz](#datenschutz-sealing-hsm-und-verschlüsselter-push)                                       |
| `NOTIFICATION_PERSISTENCE_SEALING_KEYCHAIN_FILE`               | —                 | ✔    | Pfad der Keychain-Datei mit den HSM-gekapselten Schlüsseln, siehe [Keychain](#keychain)                                                                                        |
| `NOTIFICATION_PERSISTENCE_SEALING_ROTATION_INTERVAL`           | `1h`              | ✔    | Intervall des Rotationsjobs, der Datensätze älterer Keychain-Einträge auf den aktuellen umzieht                                                                                |
| `NOTIFICATION_ENCRYPTION_ENABLED`                              | `false`           | ✔    | Verschlüsselter Push zum Push Gateway (A_29968)                                                                                                                                |
| `HSM_PROXY_ENDPOINT`                                           | `localhost:50051` | ✔    | `host:port` des HSM Proxy                                                                                                                                                      |
| `HSM_PROXY_PLAIN_TEXT_ACCEPTED`                                | `false`           | ✔    | Unverschlüsselten gRPC-Kanal zum HSM Proxy zulassen; ohne diesen Wert startet ein Sealing-Deployment nicht                                                                     |
| `NOTIFICATION_DISPATCH_QUEUE_CAPACITY`                         | `10000`           |      | Kapazität der In-Memory-Zustellwarteschlange; volle Queue → `503 SERVICE_UNAVAILABLE` bei der Einlieferung                                                                     |
| `APP_AUTH_USER_INFO_HEADER`                                    | `zeta-user-info`  |      | Name des Headers, aus dem die FdV-API die vom PEP etablierte Identität liest                                                                                                   |
| `PUSH_GATEWAY_CONNECT_TIMEOUT`                                 | `PT3S`            |      | Verbindungs-Timeout zum Push Gateway                                                                                                                                           |
| `PUSH_GATEWAY_READ_TIMEOUT`                                    | `PT10S`           |      | Lese-Timeout zum Push Gateway                                                                                                                                                  |
| `PUSH_GATEWAY_RETRY_MAX_ATTEMPTS`                              | `3`               |      | Gesamtzahl der Zustellversuche; nur transiente Fehler werden wiederholt                                                                                                        |
| `PUSH_GATEWAY_RETRY_INITIAL_DELAY`                             | `PT1S`            |      | Erste Backoff-Wartezeit; verdoppelt sich je weiterem Versuch                                                                                                                   |
| `PUSH_GATEWAY_TRUSTED_CA_PATHS`                                | —                 | ✔    | PEM-CA-Dateien, die zusätzlich zu den System-Trust-Anchors vertraut werden                                                                                                     |
| `PUSH_GATEWAY_MTLS_CLIENT_CERTIFICATE_PATH`                    | —                 | ✔    | PEM-Client-Zertifikat für mTLS zum Push Gateway                                                                                                                                |
| `PUSH_GATEWAY_MTLS_CLIENT_KEY_PATH`                            | —                 | ✔    | PEM-Private-Key; nur zusammen mit dem Zertifikat gültig — nur einer von beiden bricht den Start ab                                                                             |
| `PUSH_GATEWAY_MTLS_CLIENT_KEY_PASSWORD`                        | —                 | ✔    | Passwort eines verschlüsselten Private Keys                                                                                                                                    |
| `QUARKUS_DATASOURCE_JDBC_URL` / `_USERNAME` / `_PASSWORD`      | —                 | ✔    | Datenbankverbindung; der Datenbank-Typ wird aus dem URL-Präfix bestimmt. Flyway migriert das Schema beim Start                                                                 |
| `NOTIFICATION_DATASOURCE_DB_KIND`                              | `postgresql`      | ✔    | Datenbank-Typ (`postgresql`, `mariadb`, `mysql`, `mssql`, `oracle`), aus `notificationService.db.kind`; nur bei mehrdeutiger JDBC-URL nötig (z. B. MariaDB über `jdbc:mysql:`) |
| `NOTIFICATION_API_RS_ENABLED` / `NOTIFICATION_API_FDV_ENABLED` | `true`            |      | **Build-Zeit**-Schalter der API-Auswahl — wirken nur beim Bauen des Images, nicht zur Laufzeit. Die Varianten `-rs`/`-fdv` sind damit vorgebaut                                |

> [!WARNING]
> Ohne Sealing (`NOTIFICATION_PERSISTENCE_SEALING_ENABLED=false`, Standard)
> liegen Nutzerkennungen (KVNR/Telematik-ID) und Payloads — abgesehen von
> Schutzmaßnahmen auf Datenbank- bzw. Storage-Ebene — **unverschlüsselt** in
> der Datenbank. Sealing ist nach A_29957 nur innerhalb einer VAU zulässig,
> siehe [Datenschutz](#datenschutz-sealing-hsm-und-verschlüsselter-push).

## Well-Known-Integration (RFC 9728)

Der Notification Service ist gegenüber den Clients eine eigene geschützte
Ressource: Bei aktiviertem Notification Service liefert der PEP unter
`/.well-known/oauth-protected-resource<wellKnownResourceSuffix>` ein zweites
OAuth-Protected-Resource-Metadata-Dokument nach RFC 9728 aus. Dessen
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
Postgres-Instanz (Port 5432, nur im `cloudnative`-Modus) und — sofern
`pushGatewayAllowedBaseUrls` gesetzt ist — Port 443 zu den IP-Blöcken aus
`networkPolicy.egress.providerInternal.resourceServers.ipBlocks`. Ein
Push Gateway, das clusterintern oder über einen Proxy erreicht wird, benötigt
eine eigene zusätzliche Regel. Eine Regel zum HSM Proxy erzeugt das Chart
nicht: Bei aktiviertem Sealing ergänzen Sie selbst eine `podSelector`- oder
`ipBlock`-Regel. Sie gilt auch für den Keychain-Generator im selben Pod; eigene
Init-Container brauchen zusätzlich den Zugang zu ihrem Store. Details siehe
[Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md).
Eingehender Verkehr ist über die Egress-Regeln von PEP (FdV-Variante) bzw.
Resource Server (RS-Variante) abgedeckt.

## Aktueller Stand und Einschränkungen

- **Vorschau:** Der Notification Service ist im Helm-Chart standardmäßig
  deaktiviert und wird pro Stage bewusst eingeschaltet.
- **Sealing nur in einer VAU:** Außerhalb einer VAU bleibt Sealing aus, Daten
  liegen dann bis auf DB-Ebene unverschlüsselt vor (siehe Warnung oben).
- **Kanal zum HSM Proxy unauthentisiert:** Ein Sealing-Deployment verlangt
  `hsm.plainTextAccepted: true`; den Kanal muss das Netzwerk schützen.
- **Verschlüsselter Push nimmt 1018 Bytes Payload an**, nicht die 3 KB des
  RS-Vertrags; mehr lässt das Padding (A_27610) nicht zu.
- Das optionale `reference`-Feld wird persistiert, auf dem unverschlüsselten
  Zustellpfad jedoch nicht an das Push Gateway weitergereicht.
- **RS-API ohne TLS-Konfiguration im Chart:** Der Dienst prüft das
  Client-Zertifikat selbst, das Chart stellt dafür aber weder Serverzertifikat
  noch Truststore bereit. Mit `notificationService.rs.mtls.enabled: true`
  (Standard) wird jeder RS-Aufruf mit `401` abgelehnt; siehe
  [Übersicht](#übersicht-split-deployment-und-datenbank).
- Das im Helm-Repository mitgelieferte `push-gateway`-Subchart ist ein reines
  Test-/Demo-Deployment ohne Authentifizierung und darf nicht produktiv
  betrieben werden. Für produktionsreife Push-Gateway-Deployments nutzen Sie
  das von der gematik bereitgestellte Push-Gateway-Helm-Chart.
