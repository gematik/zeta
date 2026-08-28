# Wie Sie das SDK Notifications-Modul verwenden

Diese Anleitung beschreibt, wie eine App über das Notifications-Modul des
ZETA SDK Push-Registrierungen (Pusher) und Benachrichtigungskanäle beim
Notification Service des ZETA Guards verwaltet. Der Empfang und die Anzeige
der eigentlichen Push-Nachrichten (FCM/APNs) ist Aufgabe der einbettenden App,
nicht des Moduls.

> [!WARNING]
> Push-Benachrichtigungen sind Teil der ZETA-2.0-Spezifikation und derzeit ein
> **Vorschau-Feature**. APIs und Abläufe können sich noch ändern.

---

Status: Entwurf (Vorschau-Feature)

Zielgruppe: Primärsystem-Hersteller / App-Entwickler

Plattformen: Android und iOS über `notifications()`; auf der JVM existiert nur
die interne Test-Variante `notificationsForTesting()` (siehe unten).

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Token-Handling](#token-handling)
- [Pusher verwalten](#pusher-verwalten)
- [Kanäle verwalten](#kanäle-verwalten)
- [Push-Empfang in der App](#push-empfang-in-der-app)
- [Aktueller Stand und Einschränkungen](#aktueller-stand-und-einschränkungen)

## Voraussetzungen

- Ein über `ZetaSdk.build()` erstellter, registrierter und authentifizierbarer
  Client (siehe [Wie Sie das ZETA SDK integrieren](Wie_Sie_das_ZETA_SDK_integrieren.md)).
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

| Feld                   | Default                  | Beschreibung                                                                                                       |
|------------------------|--------------------------|--------------------------------------------------------------------------------------------------------------------|
| `wellKnownSubpath`     | `notification-service`   | Subpfad der Well-Known-Metadaten des NS: `https://{resource-host}/.well-known/oauth-protected-resource/{subpath}` |
| `apiBasePath`          | `/push/v1`               | API-Präfix des Notification Service am PEP                                                                         |
| `rateLimitRetryPolicy` | `RateLimitRetryPolicy()` | Retry-Verhalten bei `429` (Default: max. 2 Wiederholungen, Start-Backoff 500 ms)                                   |

Der Notification Service läuft per Definition auf dem Host des Resource
Servers; seine Basis-URL wird daher aus der Resource-URL abgeleitet. Der
Accessor `notifications()` selbst führt keine I/O aus — Discovery des
Notification Service und Token-Beschaffung passieren erst beim ersten
Operationsaufruf, wo auch Fehler sichtbar werden.

## Token-Handling

Das Token-Handling übernimmt das SDK vollständig, die App muss nichts tun:

- Jeder Aufruf verwendet ein **dienstspezifisches Access Token** für den
  Notification Service (eigene `resource`/Scopes, getrennt vom Token für den
  Resource Server) mit Least-Privilege-Scope pro Operation gemäß der
  normativen Scope-Tabelle (A_29979): `notification.pusher.read`/`.write`,
  `notification.channel.read`/`.write`.
- Zu jedem Request wird ein **frischer DPoP-Proof** signiert.
- Bei `401` wird das gecachte Token verworfen und die gesamte Operation genau
  einmal wiederholt (Token-Beschaffung, DPoP, Request); ein zweites `401`
  erreicht den Aufrufer. `403` (unzureichende Scopes) wird nie wiederholt.
- Bei `429` erfolgt ein begrenzter automatischer Retry mit exponentiellem
  Backoff (A_25339); die Wartezeit ist `max(retry_after_ms aus der Antwort,
  aktueller Backoff)` (A_27007). Nach Ausschöpfen der Versuche wird
  `NotificationRateLimitedException` geworfen, damit die App das Verhalten
  gegenüber dem Nutzer selbst bestimmt.

Fehler werden als Subtypen von `NotificationApiException` gemeldet
(400/401/403/429/sonstige).

## Pusher verwalten

Ein *Pusher* ist die Push-Registrierung eines Geräts. Der plattformspezifische
Push-Token (z. B. der FCM-Token) kommt von der App und wird als `pushkey`
registriert:

```kotlin
notifications.registerPusher(
    PusherConfig(
        pushkey = fcmToken,                     // Push-Token der Plattform (FCM/APNs)
        appId = "de.example.app",               // Bundle-/Application-ID
        appDisplayName = "Beispiel-App",        // optional
        deviceDisplayName = "Pixel 9",          // optional
        lang = "de",                            // optional
    ),
)
```

Bei `registerPusher` gilt:

- War von diesem Gerät bereits ein anderer Pusher registriert, wird dieser
  zuerst deregistriert (`kind = null` an `POST /pushers/set`).
- Das SDK erzeugt das ISS-Schlüsselmaterial für die Payload-Verschlüsselung
  (32-Byte-ISS, `aes-hmac-sha256`) und hängt es an die Registrierung an.
- Der registrierte Pusher (`pushkey`, `appId`) wird lokal gespeichert, damit
  Kanal-Operationen ohne expliziten `pushkey` auskommen.

Weitere Operationen:

```kotlin
val pushers = notifications.getPushers()        // alle Pusher des Nutzers

notifications.updatePusher(                      // identifiziert über appId/pushkey
    PusherConfig(pushkey = fcmToken, appId = "de.example.app", lang = "en"),
)

notifications.deletePusher(pushkey = fcmToken, appId = "de.example.app")
```

Erneuert die Plattform den Push-Token (z. B. FCM `onNewToken`), muss die App
den Pusher mit dem neuen Token neu registrieren.

## Kanäle verwalten

Kanäle steuern, welche Benachrichtigungsarten ein Gerät empfängt. Die
Kanal-Konfiguration ist gerätegebunden; für das lokale Gerät verwendet das SDK
automatisch den zuletzt über `registerPusher` registrierten Pusher:

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
(`not_set` bedeutet: keine explizite Wahl, der Kanal-Default gilt; der Wert
wird vom SDK unverändert durchgereicht).

## Push-Empfang in der App

Der Push-Transport (Empfang und Anzeige der Nachrichten) ist **nicht** Teil
des Moduls, sondern Verantwortung der App. Die Android-Demo-App im
zeta-sdk-Repository zeigt eine FCM-Integration: `ZetaFirebaseMessagingService`
(Source Set `androidNotifications` in `zeta-client`) verarbeitet in
`onMessageReceived` eingehende Nachrichten und zeigt sie als
System-Notification an; in `onNewToken` registriert sie den Pusher mit dem
erneuerten FCM-Token neu.

Ein APNs-Beispiel für iOS existiert noch nicht.

## Aktueller Stand und Einschränkungen

- **Vorschau:** Das Modul ist Teil der ZETA-Stufe 2; APIs können sich ändern.
- `decryptPushNotification` sowie die Nachrichten-Historie
  (`getNotification`, `getNotifications`) sind noch nicht implementiert —
  Aufrufe werfen eine Exception.
- `notifications()` existiert nur auf **Android und iOS** (Push-Transport ist
  ein Mobile-Feature). Auf der JVM gibt es `notificationsForTesting()`
  (annotiert mit `@InternalZetaApi`) für Test-Tooling wie den Testdriver; sie
  ist nicht Teil der unterstützten öffentlichen API.
- Die Sprach-Bindings **C#, C++ und Java** enthalten das Notifications-Modul
  derzeit nicht (siehe [SDK-Übersicht](../Referenzen/SDK-Uebersicht.md)).
- Ein APNs-Integrationsbeispiel steht noch aus; die Demo-App zeigt nur FCM.
