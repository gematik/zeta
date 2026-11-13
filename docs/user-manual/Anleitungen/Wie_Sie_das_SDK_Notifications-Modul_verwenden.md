# Wie Sie das SDK-Notifications-Modul verwenden

Diese Anleitung beschreibt, wie eine App über das Notifications-Modul des
ZETA-SDK Push-Registrierungen (Pusher) und Benachrichtigungskanäle beim
Notification Service des ZETA-Guards verwaltet, empfangene Push-Nachrichten
entschlüsselt und die Benachrichtigungs-Historie liest. Der Empfang und die
Anzeige der eigentlichen Push-Nachrichten (FCM/APNs) ist Aufgabe der
einbettenden App, nicht des Moduls.

> [!WARNING]
> Push-Benachrichtigungen sind Teil der ZETA-2.0-Spezifikation und derzeit ein
> **Vorschau-Feature**. APIs und Abläufe können sich noch ändern.

---

Status: Entwurf (Vorschau-Feature)

Zielgruppe: Primärsystem-Hersteller / App-Entwickler

Plattformen: Android und iOS über `notifications()`; auf der JVM existiert nur
die interne Test-Variante `notificationsForTesting()` (siehe unten).

Stand: ZETA-SDK 2.0.0

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Token-Handling](#token-handling)
- [Pusher verwalten](#pusher-verwalten)
- [Kanäle verwalten](#kanäle-verwalten)
- [Push-Nachrichten entschlüsseln](#push-nachrichten-entschlüsseln)
- [Benachrichtigungs-Historie lesen](#benachrichtigungs-historie-lesen)
- [Push-Empfang in der App](#push-empfang-in-der-app)
- [Fehlerbehandlung](#fehlerbehandlung)
- [Aktueller Stand und Einschränkungen](#aktueller-stand-und-einschränkungen)

## Voraussetzungen

- Ein über `ZetaSdk.build()` erstellter, registrierter und authentifizierbarer
  Client (siehe [Wie Sie das ZETA-SDK integrieren](Wie_Sie_das_ZETA_SDK_integrieren.md)).
- Der Notification Service muss im ZETA-Guard-Deployment aktiviert sein, siehe
  [Konfiguration des Notification Service](../Referenzen/Konfiguration_des_Notification_Service.md).
- Notifications sind **Opt-in**: In der `BuildConfig` muss ein
  `NotificationConfig` gesetzt sein; `null` (der Default) deaktiviert das
  Modul vollständig.

```kotlin
val sdk = ZetaSdk.build(
    resource,
    BuildConfig(
        // ... übrige Konfiguration wie in der SDK-Integrationsanleitung ...
        notificationConfig = NotificationConfig(),
    ),
)

val notifications = sdk.notifications() // nur Android/iOS
```

Felder von `NotificationConfig` (alle mit Defaults):

| Feld                   | Default                  | Beschreibung                                                                                                      |
|------------------------|--------------------------|-------------------------------------------------------------------------------------------------------------------|
| `wellKnownSubpath`     | `notification-service`   | Subpfad der Well-Known-Metadaten des NS: `https://{resource-host}/.well-known/oauth-protected-resource/{subpath}` |
| `apiBasePath`          | `/push/v1`               | API-Präfix des Notification Service am PEP                                                                        |
| `rateLimitRetryPolicy` | `RateLimitRetryPolicy()` | Retry-Verhalten bei `429` (Default: max. 2 Wiederholungen, Start-Backoff 500 ms)                                  |

Der Notification Service läuft per Definition auf dem Host des Resource
Servers; seine Basis-URL wird daher aus der Resource-URL abgeleitet. Der
Accessor `notifications()` selbst führt keine I/O aus — Discovery des
Notification Service und Token-Beschaffung passieren erst beim ersten
Operationsaufruf, wo auch Fehler sichtbar werden. Ist kein `NotificationConfig`
gesetzt, wirft `notifications()` einen Fehler.

## Token-Handling

Das Token-Handling übernimmt das SDK; die App muss dafür keinen eigenen Code
schreiben:

- Alle Aufrufe verwenden ein **dienstspezifisches Access-Token** für den
  Notification Service, getrennt vom Token für den Resource Server. Das SDK
  fordert es mit der Resource-ID des Notification Service als Audience und mit
  allen `notification.*`-Scopes an, die der Notification Service in seinen
  Well-Known-Metadaten unter `scopes_supported` ausweist (Scope-Tabelle
  A_29979: `notification.pusher.read`/`.write`,
  `notification.channel.read`/`.write`, optional
  `notification.history.read`).
- Das Token entsteht, indem das SDK die primäre Authentifizierung des Clients
  mit dieser Audience und diesen Scopes erneut durchläuft. Es hält das Token
  nur im Arbeitsspeicher der SDK-Instanz und ohne Refresh-Token. Für Clients
  mit SM-B/SMC-B geschieht das ohne Nutzerinteraktion. **Für Clients im
  mobilen Client-Flow (OIDC) bedeutet es jeweils eine Anmeldung im Browser
  über den `AuthorizationLauncher`**: beim ersten Notifications-Aufruf einer
  SDK-Instanz, nach Ablauf des Tokens und bei der Wiederholung nach `401`.
  Laut SDK-Quellcode entfällt das, sobald der Guard dafür einen Token Exchange
  (A_29843 bzw. RFC 8693) unterstützt.
- Zu jedem Request wird ein **frischer DPoP-Proof** signiert.
- Bei `401` wird das gecachte Token verworfen und die gesamte Operation genau
  einmal wiederholt (Token-Beschaffung, DPoP, Request); ein zweites `401`
  erreicht den Aufrufer. `403` (unzureichende Scopes) wird nie wiederholt.
- Bei `429` erfolgt ein begrenzter automatischer Retry mit exponentiellem
  Backoff (A_25339); die Wartezeit ist `max(retry_after_ms aus der Antwort,
  aktueller Backoff)` (A_27007). Nach Ausschöpfen der Versuche wird
  `NotificationRateLimitedException` geworfen, damit die App das Verhalten
  gegenüber dem Nutzer selbst bestimmt. Mit `maxRetries = 0` in der
  `RateLimitRetryPolicy` lassen sich die automatischen Wiederholungen abschalten.
  Die Wiederholung und die typisierten Exceptions für `400` und `429` setzen
  voraus, dass die Antwort das Fehlerformat des Notification Service (JSON mit
  `errorCode`) hat; andere Antworten, etwa eines vorgeschalteten Proxys, führen
  zu einer allgemeinen Exception ohne automatische Wiederholung.

## Pusher verwalten

Ein *Pusher* ist die Push-Registrierung eines Geräts. Der plattformspezifische
Push-Token (z. B. der FCM-Token oder der APNs-Device-Token) kommt von der App
und wird als `pushkey` registriert:

```kotlin
notifications.registerPusher(
    PusherConfig(
        pushkey = fcmToken,                     // Push-Token der Plattform (FCM/APNs)
        appId = "de.example.app",               // Application-ID, unter der das Push Gateway routet
        appDisplayName = "Beispiel-App",        // optional
        deviceDisplayName = "Pixel 9",          // vom Notification Service gefordert
        lang = "de",                            // optional
        data = PusherData(url = pushGatewayUrl),// Basis-URL des Push Gateways, vom Notification Service gefordert
    ),
)
```

`PusherConfig` enthält außerdem das optionale Feld `profileTag`. Der Notification
Service verlangt `deviceDisplayName` und `data`; `data.url` muss **exakt** einer
der im Notification Service erlaubten Push-Gateway-URLs entsprechen (siehe
[Wie der Notification Service funktioniert](Wie_der_Notification_Service_funktioniert.md)).

Bei `registerPusher` gilt:

- Ist derselbe Pusher (gleicher `pushkey` und gleiche `appId`) von diesem Gerät
  bereits registriert und liegt das Schlüsselmaterial vor, tut der Aufruf nichts.
- War von diesem Gerät bereits ein anderer Pusher registriert, wird dieser
  zuerst deregistriert (`kind = null` an `POST /pushers/set`).
- Das SDK erzeugt das ISS-Schlüsselmaterial für die Payload-Verschlüsselung
  (32-Byte-ISS, Methode `aes-hmac-sha256`, Erzeugungsmonat und
  Schlüssel-Kennung) und hängt es an die Registrierung an.
- Der registrierte Pusher (`pushkey`, `appId`) und das daraus abgeleitete
  Schlüsselmaterial werden im SDK-Storage dauerhaft gespeichert, getrennt je
  Resource. So kommen Kanal-, Entschlüsselungs- und Historienoperationen ohne
  expliziten `pushkey` aus.

Weitere Operationen:

```kotlin
val pushers = notifications.getPushers()        // alle Pusher des Nutzers

notifications.updatePusher(                      // identifiziert über appId/pushkey
    PusherConfig(
        pushkey = fcmToken,
        appId = "de.example.app",
        deviceDisplayName = "Pixel 9",
        lang = "en",
        data = PusherData(url = pushGatewayUrl),
    ),
)

notifications.deletePusher(pushkey = fcmToken, appId = "de.example.app")
```

`updatePusher` sendet die Angaben der `PusherConfig` erneut an
`POST /pushers/set`, jedoch ohne neues Schlüsselmaterial; geben Sie daher auch
die vom Notification Service verlangten Felder an. Der aktualisierte Pusher gilt
danach als lokaler Pusher des Geräts – aktualisieren Sie mit `updatePusher` also
nur den Pusher dieses Geräts. Löscht `deletePusher` den lokal registrierten
Pusher, verwirft das SDK auch dessen Schlüsselmaterial.

Erneuert die Plattform den Push-Token (z. B. FCM `onNewToken`), muss die App
den Pusher mit dem neuen Token neu registrieren.

## Kanäle verwalten

Kanäle steuern, welche Benachrichtigungsarten ein Gerät empfängt. Die
Kanal-Konfiguration ist gerätegebunden; für das lokale Gerät verwendet das SDK
automatisch den zuletzt über `registerPusher` (bzw. `updatePusher`)
gespeicherten Pusher:

```kotlin
// Für den Nutzer verfügbare Kanäle inkl. Default-Status
val available = notifications.getAvailableChannels()

// Kanal-Konfiguration des lokalen Geräts
val local = notifications.getLocalChannels()

// Kanäle für das lokale Gerät setzen; nicht genannte Kanäle bleiben unverändert
notifications.setLocalChannels(
    listOf(Channel(id = "epa.documents.new", status = ChannelStatus.ENABLED)),
)
```

`ChannelStatus` kennt drei Werte: `ENABLED`, `DISABLED` und `NOT_SET`
(`not_set` bedeutet: keine explizite Wahl; solche Kanäle lösen wie `disabled`
keine Pushes aus. Der Wert wird vom SDK unverändert durchgereicht).

## Push-Nachrichten entschlüsseln

Verschlüsselte Push-Nachrichten tragen den Chiffretext (`ciphertext`) und den
Monat, in dem sie verschlüsselt wurden (`time_message_encrypted`, Format
`yyyy-MM`). Beide Werte reicht die App an das SDK weiter und erhält den
Klartext:

```kotlin
val message: String = notifications.decryptPushNotification(
    ciphertext = ciphertext,
    timeMessageEncrypted = timeMessageEncrypted,
)
```

Dabei gilt:

- Das SDK nutzt das Schlüsselmaterial des zuletzt über `registerPusher`
  registrierten Pusher; ohne registrierten Pusher schlägt die Entschlüsselung
  fehl.
- Das Schlüsselmaterial rotiert monatlich: Das SDK leitet den Schlüssel für den
  Monat der Nachricht per HKDF-SHA256 aus dem Vormonat ab und entschlüsselt mit
  AES-256-GCM (A_27158-01, A_27170-01). Es bewahrt nur den aktuellen und den
  vorherigen Monat auf (A_27177, A_27180), damit auch eine kurz vor einem
  Monatswechsel verschlüsselte Nachricht lesbar bleibt. Ältere Nachrichten
  lassen sich nicht mehr entschlüsseln.
- Die Nachricht ist vor der Verschlüsselung auf eine feste Länge aufgefüllt
  (A_27610); das SDK entfernt das Padding und liefert nur den eigentlichen
  Nachrichtentext.

`decryptPushNotification` ist eine Methode des `NotificationClient`. Trifft eine
Nachricht in einem Prozess ein, in dem noch kein `ZetaSdkClient` existiert,
muss die App dort einen Client mit derselben Resource, denselben Scopes und
derselben `StorageConfig` erzeugen, damit das SDK das gespeicherte
Schlüsselmaterial findet.

## Benachrichtigungs-Historie lesen

Hat der Betreiber die Historie im Notification Service aktiviert (A_29974),
kann die App die an dieses Gerät gesendeten Benachrichtigungen nachträglich
abrufen:

```kotlin
val history = notifications.getNotifications().notifications   // dieses Gerät, über den gespeicherten pushkey
val one = notifications.getNotification(history.first().identifier)
```

- `identifier` ist die vom Notification Service vergebene Notification-ID. Sie
  ist **nicht** der `identifier` einer empfangenen Push-Nachricht; dieser trägt
  die Referenz des Resource Servers. Eine empfangene Push-Nachricht lässt sich
  daher nicht direkt in der Historie nachschlagen.
- `payload` wird als `JsonObject` so durchgereicht, wie der Notification Service
  es liefert; die Felder legt der Fachdienst fest.
- Das SDK hält die Historie nicht lokal vor; jeder Aufruf geht an den
  Notification Service. Ein fehlerhafter Listeneintrag wird übersprungen, der
  Rest der Liste geliefert.
- `404` bzw. `501` führen zu einer `NotificationHistoryNotFoundException` mit
  dem `errorCode` des Notification Service (z. B. `NOTIFICATION_NOT_FOUND`,
  `PUSHER_NOT_FOUND`). Für eine unbekannte ID und eine deaktivierte Historie
  antwortet der Notification Service gleich; eine deaktivierte Historie zeigt
  sich daher als diese Exception oder als leere Liste.
- Gehört der `pushkey` einem anderen Nutzer, antwortet der Notification Service
  ab Version 2.0.2 mit `403` statt `404`; das SDK wirft dann eine
  `NotificationApiForbiddenException`.

## Push-Empfang in der App

Der Push-Transport (Empfang und Anzeige der Nachrichten) ist **nicht** Teil
des Moduls, sondern Verantwortung der App. Die Demo-App im
zeta-sdk-Repository zeigt beide Plattformen:

- **Android (FCM, optional):** `ZetaFirebaseMessagingService` (Source Set
  `androidNotifications` in `zeta-client`) liest in `onMessageReceived` die
  Felder `ciphertext` und `time_message_encrypted` – auf oberster Ebene der
  Datennutzlast oder, wie sie das Push Gateway 1.0.1 weiterleitet, im Feld
  `content` –, lässt sie vom SDK entschlüsseln und zeigt den Text als
  System-Notification an. Dafür nutzt die Demo-App den SDK-Client, mit dem im
  selben Prozess über „Test Push“ der Pusher registriert wurde; fehlt er, etwa
  nach einem Neustart der App, verwirft sie die Nachricht. Nachrichten ohne
  verschlüsselte Nutzlast zeigt sie mit ihrem Benachrichtigungstext an. In
  `onNewToken` registriert sie den Pusher mit dem erneuerten FCM-Token neu,
  ebenfalls nur bei bestehender Sitzung. Die FCM-Integration ist standardmäßig
  deaktiviert und wird über die Konfiguration der Demo-App eingeschaltet (siehe
  [Wie Sie den ZETA-Demo-Client ausführen](Wie_Sie_den_ZETA_Demo_client_ausführen.md)).
- **iOS (APNs):** Die iOS-Demo-App empfängt Push-Nachrichten direkt über APNs,
  ohne Firebase. `AppDelegate.swift` fragt die Berechtigung für
  Benachrichtigungen ab, registriert die App für Remote Notifications und
  übergibt den Device-Token an `IosPushBridge` (`zeta-client`, iosMain). Als
  `pushkey` dient der APNs-Device-Token (64 Hex-Zeichen); das Push Gateway
  routet über die `app_id` `<bundle-id>.apns`. Nachrichten, die im Vordergrund
  eintreffen, entschlüsselt die App und zeigt den Text an.

## Fehlerbehandlung

Fehler des Notification Service meldet das Modul als Subtypen von
`NotificationApiException`; die ursprüngliche HTTP-Antwort ist jeweils als
`response` verfügbar:

| Exception                               | Auslöser                                                                    |
|-----------------------------------------|-----------------------------------------------------------------------------|
| `InvalidNotificationRequestException`   | `400`, Anfrage vom Notification Service abgelehnt (`errorCode`, `errorDetail`) |
| `NotificationApiUnauthorizedException`  | `401`, Access-Token abgelehnt                                               |
| `NotificationApiForbiddenException`     | `403`, Access-Token ohne die nötige Berechtigung                            |
| `NotificationRateLimitedException`      | `429` nach Ausschöpfen der automatischen Wiederholungen (`retryAfterMs`)    |
| `NotificationHistoryNotFoundException`  | `404` bzw. `501` an den Historien-Endpunkten (`errorCode`)                  |
| `UnexpectedNotificationApiException`    | jeder andere Fehlerstatus                                                   |

Bereits bei der Discovery prüft das SDK die Well-Known-Metadaten des
Notification Service: Sie müssen den Authorization Server des Guards nennen,
DPoP-gebundene Access-Tokens verlangen und mindestens einen
`notification.*`-Scope ausweisen. Andernfalls schlägt der erste
Operationsaufruf mit einer `NotificationDiscoveryException` fehl.

## Aktueller Stand und Einschränkungen

- **Vorschau:** Das Modul ist Teil der ZETA-Stufe 2; APIs können sich ändern.
- **Browser-Anmeldung für das Notification-Service-Token:** Clients im mobilen
  Client-Flow (OIDC) müssen sich für das Token des Notification Service jeweils
  erneut im Browser anmelden (siehe [Token-Handling](#token-handling)).
- `notifications()` existiert nur auf **Android und iOS** (Push-Transport ist
  ein Mobile-Feature). Auf der JVM gibt es `notificationsForTesting()`
  (annotiert mit `@InternalZetaApi`) für Test-Tooling wie den Testdriver; sie
  ist nicht Teil der unterstützten öffentlichen API.
- Die Sprach-Bindings **C#, C++ und Java** enthalten das Notifications-Modul
  derzeit nicht (siehe [SDK-Übersicht](../Referenzen/SDK-Uebersicht.md)).
- Unter iOS hält der Standard-Speicher des SDK die Daten nur im Arbeitsspeicher.
  Ohne eigene `SdkStorage`-Implementierung geht das Schlüsselmaterial mit einem
  Neustart der App verloren; der Pusher muss dann neu registriert werden.
- Im Hintergrund eintreffende Push-Nachrichten kann die iOS-Demo-App nicht
  entschlüsseln; iOS zeigt dann die Platzhaltertexte des Push Gateways an. Dafür
  wären eine Notification Service Extension und ein dauerhafter, mit ihr
  geteilter Speicher nötig.
- `forget()` löscht den lokalen Pusher und das Schlüsselmaterial nur auf dem
  Gerät; die Registrierung beim Notification Service bleibt bestehen. Zum
  Abmelden ruft die App vorher `deletePusher` auf.
