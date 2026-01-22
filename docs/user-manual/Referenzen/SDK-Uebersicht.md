
# Beschreibung des SDK Repository Inhalts

Dieses Dokument beschreibt die Inhalte des zeta-sdk repositories.

Es enthält neben dem eigentlichen SDK, d.h. der Kernfunktionalität des ZETA-Clients, auch verschiedene Test-Clients,
im Sinne eines Monorepos.

[[_TOC_]]

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

![Netzwerk-Modul](../assets/images/depl_sc/sdk-modul-beispiel.png)

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

