# Wie der Notification Service funktioniert

Der Notification Service ermöglicht es einem Fachdienst, Push-Benachrichtigungen
an die mobilen Geräte seiner Nutzer zu senden, ohne selbst mit APNs oder FCM zu
sprechen: Der Fachdienst übergibt die Benachrichtigung dem Notification Service,
dieser ermittelt die registrierten Geräte mit aktivem Kanal und leitet den Push
asynchron an das Push Gateway des App-Anbieters weiter, das die Zustellung an
die Plattformdienste (APNs/FCM) übernimmt. Mobile Clients verwalten ihre
Push-Ziele und Kanäle über das ZETA SDK.

Der Notification Service gehört zur Umsetzungsstufe 2 und ist eine
**Vorschau-Komponente**: Er ist über den Helm-Wert
**`notificationService.enabled`** geschaltet (Standard: `false`). Solange der
Wert nicht gesetzt ist, werden weder die Deployments noch die Datenbank, die
PEP-Routen oder das Well-Known-Dokument erzeugt. Die vollständige
Konfigurationsreferenz steht in
[Konfiguration des Notification Service](../Referenzen/Konfiguration_des_Notification_Service.md).

## Ablauf

1. **Pusher registrieren:** Der mobile Client registriert über das SDK sein
   Push-Ziel mit `POST /pushers/set` (über den PEP unter
   `/push/v1/pushers/set`, Scope `notification.pusher.write`). Der `pushkey`
   ist das Zustell-Token der Plattform (APNs-Token bzw. FCM Registration ID),
   `data.url` die Basis-URL des Push Gateway — sie muss **exakt** einem
   Eintrag der Allowlist `notificationService.env.pushGatewayAllowedBaseUrls`
   entsprechen, sonst wird später nichts zugestellt. Derselbe Endpunkt
   aktualisiert (`kind: "http"`) und löscht (`kind: null`) Pusher;
   `GET /pushers` listet sie. Details siehe
   [Wie Sie das SDK Notifications-Modul verwenden](Wie_Sie_das_SDK_Notifications-Modul_verwenden.md).
2. **Kanäle konfigurieren:** `GET /channels` liefert die für den Nutzer
   verfügbaren Kanäle aus der statischen Allowlist
   (`notificationService.env.channelsAllowed`; es gibt keine
   Laufzeit-Admin-API). Mit `GET /channels/{pushkey}` und
   `POST /channels/{pushkey}` liest bzw. setzt der Client die Kanalzustände
   **pro Gerät** (`enabled`, `disabled`, `not_set`; nicht gesetzte Kanäle
   lösen keine Pushes aus). Scopes: `notification.channel.read` /
   `notification.channel.write`.
3. **Fachdienst fragt aktive Kanäle ab:** Über die RS-API ruft der Fachdienst
   `GET /users/{userId}/channels?id_type=kvnr|telematik-id` auf
   (mTLS-authentifizierter technischer Nutzer). Ein Nutzer ist dem Dienst nur
   bekannt, solange mindestens ein Gerät registriert ist — sonst `404`. Die
   Antwort aggregiert über alle Geräte: Ein Kanal gilt als `enabled`, wenn er
   auf mindestens einem Gerät aktiv ist.
4. **Fachdienst sendet eine Benachrichtigung:** `POST /notifications` mit
   Nutzerkennung, Kanal und fachdienstspezifischem `payload`. Die
   Verarbeitung ist strikt asynchron: Die Antwort ist `202 Accepted` mit
   einer `notification_id` — oder terminal `no_active_channel`, wenn kein
   Gerät den Kanal aktiviert hat (dann wird nichts persistiert und nichts
   gesendet). Für sichere Wiederholungen dient der
   `Idempotency-Key`-Header (A_29992). Alle Felder, Statuscodes,
   Payload-Grenzen und curl-Beispiele siehe
   [Wie Sie Benachrichtigungen aus dem Fachdienst versenden](Wie_Sie_Benachrichtigungen_aus_dem_Fachdienst_versenden.md).
5. **Asynchrone Zustellung über das Push Gateway:** Ein Worker arbeitet die
   prozesslokale Warteschlange (Kapazität standardmäßig 10 000) ab und ruft
   das Push Gateway unter der in den Pusher-Daten hinterlegten, gegen die
   Allowlist geprüften Basis-URL auf (`POST <base-url>notify/batch`).
   Transiente Fehler (5xx, 429) werden mit exponentiellem Backoff wiederholt
   (standardmäßig 3 Versuche ab 1 s); vom Push Gateway als `rejected`
   gemeldete Pushkeys führen zur Löschung des betroffenen Pushers. Die
   Zustellung an das Gerät ist Best-Effort — ein Zustellergebnis wird dem
   Fachdienst nicht zurückgemeldet.
6. **Optional — Nachrichten-Historie:** Bei
   `notificationService.historyEnabled: true` persistiert der Dienst die
   gesendeten Nachrichten und der Client kann sie über
   `GET /history/{notification_id}` und `GET /history/device/{pushkey}`
   abrufen (Scope `notification.history.read`, erscheint nur bei aktivierter
   Historie im Well-Known-Dokument und muss zusätzlich per Terraform in
   Keycloak angelegt werden). Bei deaktivierter Historie wird nichts
   persistiert (A_29974).

## Endpunkte und Scopes im Überblick

Die Client-Seite (FdV-API) ist ausschließlich über den PEP erreichbar. Der PEP
bildet die öffentlichen Pfade unter `/push/v1/` auf die Wurzelpfade des
Dienstes ab und verlangt je Route einen Scope:

| Öffentlicher Pfad (PEP)             | Methode | Scope                        | Zweck                                        |
|--------------------------------------|---------|------------------------------|-----------------------------------------------|
| `/push/v1/pushers`                  | GET     | `notification.pusher.read`   | Registrierte Pusher des Nutzers auflisten    |
| `/push/v1/pushers/set`              | POST    | `notification.pusher.write`  | Pusher anlegen, ändern oder löschen          |
| `/push/v1/channels`                 | GET     | `notification.channel.read`  | Verfügbare Kanäle (Allowlist) abrufen        |
| `/push/v1/channels/{pushkey}`       | GET     | `notification.channel.read`  | Kanalzustände eines Geräts lesen             |
| `/push/v1/channels/{pushkey}`       | POST    | `notification.channel.write` | Kanalzustände eines Geräts setzen            |
| `/push/v1/history/…`                | GET     | `notification.history.read`  | Nachrichten-Historie (nur bei `historyEnabled`) |

Alle übrigen Pfade unter `/push/v1/` beantwortet der PEP mit `403`. Die
History-Route existiert im PEP immer; ohne aktivierte Historie wird der
zugehörige Scope jedoch nicht ausgestellt, sodass Zugriffe bereits am PEP
scheitern.

Die Fachdienst-Seite (RS-API) wird nicht über den PEP geroutet, sondern
clusterintern direkt am Service `notification-service-rs` aufgerufen:

| Pfad                          | Methode | Zweck                                                        |
|--------------------------------|---------|---------------------------------------------------------------|
| `/users/{userId}/channels`    | GET     | Aktive Kanäle eines Nutzers abfragen (`id_type` erforderlich) |
| `/notifications`              | POST    | Benachrichtigung einliefern (`202` + `notification_id`)       |

## Authentifizierung

Die beiden APIs des Dienstes sind unterschiedlich abgesichert:

- **FdV-Seite (Client/SDK):** Der PEP prüft Access Token, DPoP-Bindung
  (`dpop_bound_access_tokens_required: true`) und die je Route geforderten
  Scopes; alle nicht gelisteten Pfade unter `/push/v1/` beantwortet der PEP
  mit `403`. Der Dienst selbst vertraut der vom PEP weitergereichten
  Identität im **`zeta-user-info`**-Header (Base64url-kodiertes JSON,
  mindestens `identifier`); fehlt der Header, antwortet er mit `401`. Jede
  Operation ist an dieses Subjekt gebunden — ein Gerät sieht und ändert nur
  die Daten des eigenen Nutzers.
- **RS-Seite (Fachdienst):** Die Spezifikation verlangt einen per mTLS
  authentifizierten technischen Nutzer. Der Dienst terminiert dieses mTLS
  nicht selbst; die Absicherung erfolgt vorgelagert (Service Mesh bzw. ein
  mTLS-terminierender Endpunkt innerhalb der Vertrauensgrenze). Die RS-API
  wird nicht über den PEP geroutet.

## Datenhaltung und Löschung

Der Dienst nutzt eine eigene, von der PDP-Datenbank getrennte
PostgreSQL-Datenbank (im Standardmodus als dediziertes CNPG-Cluster
`notification-db`). Benachrichtigungs-Verarbeitungsdaten — angenommene
Benachrichtigungen und Idempotenz-Belege — verfallen nach der
Aufbewahrungsfrist `NOTIFICATION_PERSISTENCE_RETENTION` (Standard 24 Stunden,
A_29988); ein Purge-Job löscht abgelaufene Datensätze standardmäßig alle
5 Minuten und ist über einen Postgres-Advisory-Lock mehrinstanzsicher. Die
Kanal-Registry selbst ist statische Konfiguration; Pusher und ihre
Kanalzustände bleiben ohne Verfallsdatum gespeichert, bis der Client sie
löscht (`kind: null`) oder das Push Gateway den Pushkey als ungültig
zurückmeldet. Historien-Daten entstehen nur bei aktivierter Historie.

## Betriebsvoraussetzungen

- `notificationService.enabled: true` sowie die beiden Pflichtwerte
  `env.pushGatewayAllowedBaseUrls` und `env.channelsAllowed` — ohne sie
  schlägt der Start des Dienstes fehl.
- Ein erreichbares Push Gateway des App-Anbieters; das Gateway wird direkt
  über das Internet erreicht, bei aktivierten Egress-NetworkPolicies ist der
  Weg dorthin freizugeben (siehe
  [Konfiguration des Notification Service](../Referenzen/Konfiguration_des_Notification_Service.md#networkpolicies)).
- Im Standardmodus `db.mode: cloudnative` ein installierter
  CloudNativePG-Operator; alternativ eine extern bereitgestellte
  PostgreSQL-Datenbank (`db.mode: external`).
- Die Keycloak-Scopes `notification.*` werden von der Terraform-Konfiguration
  des PDP angelegt; bei aktivierter Historie zusätzlich
  `notification_history_enabled = true` setzen (nicht an den Helm-Wert
  gekoppelt, siehe
  [Konfiguration des Notification Service](../Referenzen/Konfiguration_des_Notification_Service.md#nachrichten-historie-historyenabled)).
- `pepproxy.wellKnownBase` muss die von außen erreichbare Basis-URL sein,
  da daraus die Audience der Notification-Service-Tokens gebildet wird
  (siehe
  [Konfiguration der Well-Known-Endpunkte](../Referenzen/Konfiguration_der_Well-Known_Endpunkte.md)).

## Aktueller Stand und Einschränkungen

- **Sealing/Pseudonymisierung sind Stubs:** Das HSM-gestützte Sealing der
  gespeicherten Daten (`persistenceSealingEnabled`) ist nicht implementiert —
  Nutzerkennungen und Payloads liegen bis auf DB-/Storage-Ebene
  unverschlüsselt vor, und das Aktivieren des Schalters führt zu
  Laufzeitfehlern. Details und Warnung siehe
  [Konfiguration des Notification Service](../Referenzen/Konfiguration_des_Notification_Service.md#umgebungsvariablen-des-dienstes).
- **Die Zustellwarteschlange ist prozesslokal (In-Memory):** Beim Stopp einer
  Instanz gehen angenommene, noch nicht zugestellte Benachrichtigungen
  verloren; die Queue wird nicht zwischen Instanzen geteilt.
- **SDK-seitig sind Historie und Entschlüsselung nicht implementiert:**
  `decryptPushNotification`, `getNotification` und `getNotifications` des
  SDK-Notifications-Moduls werfen derzeit Fehler; nutzbar sind Pusher- und
  Kanalverwaltung.
- **Demo-Client:** Der mitgelieferte Demo-Client bringt eine
  FCM-(Firebase-)Integration für Android mit; eine APNs-Integration für iOS
  existiert noch nicht.

Weitere Einschränkungen der jeweiligen Schnittstellen sind in der
[Konfigurationsreferenz](../Referenzen/Konfiguration_des_Notification_Service.md#aktueller-stand-und-einschränkungen)
und der
[Versand-Anleitung](Wie_Sie_Benachrichtigungen_aus_dem_Fachdienst_versenden.md#aktueller-stand-und-einschränkungen)
aufgeführt.
