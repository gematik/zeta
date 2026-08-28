
# Beschreibung des SDK Repository Inhalts

Dieses Dokument beschreibt die Inhalte des zeta-sdk repositories.

Es enthält neben dem eigentlichen SDK, d.h. der Kernfunktionalität des ZETA-Clients, auch verschiedene Test-Clients,
im Sinne eines Monorepos.

## Inhaltsverzeichnis

- [Verzeichnisse](#verzeichnisse)
  - [Fachliche Verzeichnisse](#fachliche-verzeichnisse)
  - [Technische Verzeichnisse](#technische-verzeichnisse)
  - [Strukture der Module](#strukture-der-module)
- [Plattform- und Feature-Matrix](#plattform--und-feature-matrix)

## Verzeichnisse

Die folgenden Verzeichnisse sind in dem Repository vorhanden:

### Fachliche Verzeichnisse

Kern-Verzeichnisse

| Verzeichnis         | Beschreibung                       |
|---------------------|------------------------------------|
| zeta-sdk            | Core SDK Modul                     |
| zeta-client         | Code für die Test-Clients          |
| zeta-testdriver     | Code für den Proxy-Client          |
| docs                | weitere Code-nahe Dokumentation    |

Hier sind die verschiedenen Module abgelegt.

| Folder              | Description                                                |
|---------------------|------------------------------------------------------------|
| common              | commonly used code like logging and platform configuration |
| asl                 | ASL implementation                                         |
| attestation         | Attestation module                                         |
| authentication      | authentication module                                      |
| client-registration | Modul for the client registration                          |
| configuration       | Runtime configuration                                      |
| crypto              | Crypto functionality                                       |
| flow-controller     | Core SDK controller logic                                  |
| network             | Network module (e.g. HttpClient)                           |
| notifications       | Client for the Notification Service (pusher and channel management, preview) |
| storage             | Storage module                                             |
| tpm                 | Access to the TPM or alternate implementations             |

### Technische Verzeichnisse

| Verzeichnis | Beschreibung                                   |
|-------------|------------------------------------------------|
| build-logic | Gradle/Kotlin Code um die Komponenten zu bauen |
| gradle      | Gradle Installation                            |
| build       | Build-Ergebnisse                               |

### Strukture der Module

In den verschiedenen Modulen sind, abhängig von den jeweiligen Gegebenheiten,
plattformspezifische Unterverzeichnisse vorhanden.

Hier ein Beispiel für das Netzwerk-Modul:

![Netzwerk-Modul](../assets/images/sdk-modul-beispiel.png)

Die verschiedenen Verzeichnisse beinhalten gemeinsamen Code - mindestens die API des Moduls,
sowie die ggf. plattformspezifischen Implementierungen der Module.


| Verzeichnis | Beschreibung                                    |
|-------------|-------------------------------------------------|
| common      | gemeinsame API                                  |
| jvm         | Code spezifisch für JVM-Implementierung         |
| android     | Code spezifisch für die Android-Implementierung |
| ios         | Code spezifisch für die iOS-Implementierung     |
| desktop    | Code specific for the desktop implementations (windows, linux, mac) |

Hinweis: nicht alle Plattformen werden aktuell unterstützt.

Weitere Details sind dem Umsetzungskonzept zu entnehmen.

## Plattform- und Feature-Matrix

Die folgende Tabelle zeigt, welche SDK-Funktionen auf welchen Plattformen bzw.
in welchen Sprach-Anbindungen derzeit verfügbar sind. Mit „Vorschau"
gekennzeichnete Funktionen sind Teil der ZETA-Stufe 2 und können sich noch
ändern. „derzeit nicht verfügbar" trifft keine Aussage über eine spätere
Verfügbarkeit.

| Feature                                | Kotlin/Android | iOS       | JVM                              | C#                      | C++                     | Java                    |
|----------------------------------------|----------------|-----------|----------------------------------|-------------------------|-------------------------|-------------------------|
| Kern-Auth-Flow (SM-B/SMC-B)            | verfügbar      | verfügbar | verfügbar                        | verfügbar               | verfügbar               | verfügbar               |
| HTTP- und WebSocket-Aufrufe über den PEP | verfügbar    | verfügbar | verfügbar                        | verfügbar               | verfügbar               | verfügbar               |
| OIDC-Flow mobil (Vorschau)             | verfügbar      | verfügbar | verfügbar                        | derzeit nicht verfügbar | derzeit nicht verfügbar | derzeit nicht verfügbar |
| Notifications (Vorschau)               | verfügbar      | verfügbar | nur für Tests (interne API)      | derzeit nicht verfügbar | derzeit nicht verfügbar | derzeit nicht verfügbar |
| `changeEmail` (Vorschau)               | verfügbar      | verfügbar | verfügbar                        | derzeit nicht verfügbar | derzeit nicht verfügbar | derzeit nicht verfügbar |

Anmerkungen:

- **Notifications auf der JVM:** Es existiert nur die interne Test-Variante
  `notificationsForTesting()` (annotiert mit `@InternalZetaApi`) für den
  Testdriver; die unterstützte `notifications()`-API gibt es nur auf Android
  und iOS. Siehe
  [Wie Sie das SDK Notifications-Modul verwenden](../Anleitungen/Wie_Sie_das_SDK_Notifications-Modul_verwenden.md).
- **OIDC-Flow mobil:** Siehe
  [Wie Sie den mobilen Client-Flow mit dem ZETA SDK umsetzen](../Anleitungen/Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).
- **Java** nutzt das JVM-Artefakt (`zeta-sdk-jvm`); die Kotlin-Klassen der
  Vorschau-Features sind dort zwar enthalten, ihre suspend-basierten
  Callback-Schnittstellen haben aber keine Java-Helfer und sind daher als
  derzeit nicht verfügbar eingestuft.
- **C# und C++** binden das SDK über die native C-API an; diese exportiert
  derzeit nur Build/Lifecycle-, HTTP- und WebSocket-Funktionen.

