# Wie Sie den ZETA Test-Client bauen uns ausführen

Diese Anleitung unterstützt Tester dabei, den ZETA-Testclient zu bauen und auszuführen.
Der Testclient nutzt die API des Test-Fachdienstes und bietet eine Benutzerschnittstelle dafür.

Basierend auf dem Testclient kann ein eigener Testclient für andere Fachdienste entwickelt werden.
Dazu siehe auch die [Struktur des SDK Repositories](../Referenzen/SDK-Übersicht.md).

---

Status: Grob-Entwurf

Zielgruppe: Tester und Entwickler

---

[TOC]

## Überblick

In diesem Dokument wird beschrieben, wie das SDK und der Client mit Hilfe des gradle Build-Werkzeugs gebaut werden kann.

## Voraussetzungen

* Ein PC mit Windows, Linux, oder Mac
* Installiertes Java Development Kit (JDK)
* git client zum Herunterladen des SDK-Repositories, oder der heruntergeladene Inhalt des Repositories
* Installiertes Android Software Development Kit (SDK) mit gesetzter ANDROID_HOME Umgebungsvariable (optional)

Hinweis: das SDK und der Test-Client können grundsätzlich ohne Android SDK gebaut werden. Im Hinblick auf die
spätere Verwendung in mobilen Anwendungen wird hier aber schon der Build für Android (und iOS auf Macs) berücksichtigt.

## Vorgehen

### Abhängigkeiten / Erforderliche Konfiguration

Die wesentliche Konfiguration des Testclient besteht aus:

- Endpunkte des Fachdienst-ZETA-Guards

Diese werden durch eine Konfigurationsdatei bzw. Umgebungsvariablen bereitgestellt.

### Kurzanleitung

Nach der Konfiguration kann der Client mit dieser Kommandozeile gebaut sowie ausgeführt werden:

````
./gradlew :zeta-client:jvmRun -DmainClass="de.gematik.zeta.client.ZetaClientAppKt" --args='--ZETA_ENV_FILE=<Name-der-Parameter-Datei>
````

Die Parameter-Datei enthält dabei die Endpunkte des ZETA Guards wie folgt:

``
ENVIRONMENTS=<Fachdienst1_api_endpunkt> <Fachdienst2_api_endpunkt> ...
AUTH_URL=<PDP realms endpunkt>
``

Hierbei werden mehrere Fachdienst-URLs ermöglicht, zwischen denen in der UI umgeschaltet werden kann.
Diese sind als "ENVIRONMENTS" anzugeben, die in der einen Zeile mit Leerzeichen getrennt aufgeführt werden müssen.

Der Authserver wird ebenso in dieser Datei konfiguriert. Der Authserver muss dabei für alle Fachdienst-URLs gelten.
Die AuthServer URL wird als "AUTH_URL" angegeben.

Sollten unterschiedliche Umgebungen mit verschiedenen PDP Authservern genutzt werden, so
sind diese in unterschiedlichen Dateien anzugeben.


### Anleitung in Schritten

#### Bauen des SDK und Deployment in lokales Maven Repository

Dieser Schritt benötigt _kein_ Android SDK.

````
./gradlew publishJvmPublicationToMavenLocal
./gradlew publishKotlinMultiplatformToMavenLocal
````

#### Remote Maven Repository

Hinweis: sollten Sie das ZETA SDK in ein eigenes Remote Repository submitten wollen, so müssen sie die folgende Konfiguration in der build-logic anpassen:

| Verzeichnis                                                              | Datei                    | Zeile/Variable                                                         | Beschreibung                                                | Beispiel                                                     |
|--------------------------------------------------------------------------|--------------------------|------------------------------------------------------------------------|-------------------------------------------------------------|--------------------------------------------------------------|
| build-logic-root/build-logic/main/kotlin/ com/ey/buildlogic              | BuildLogicPlugin.kt      | 221<br/>URL des Maven Repositories                                     | URL des remote Maven Repositories                           | "https://<repository-host>/api/v4/projects/3/packages/maven" |


#### Vollständige Setups

Die vollständigen Tests und Setups benötigen ein installiertes Android SDK:

##### Vollständiger Build

````
./gradlew build
````

##### Ausführen der Tests

````
./gradlew testAll
````



## Verwandte Dokumentation

