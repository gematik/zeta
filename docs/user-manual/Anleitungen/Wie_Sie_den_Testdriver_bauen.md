# Wie Sie den ZETA-Testdriver als Container erstellen

Diese Anleitung unterstützt Tester und Entwickler dabei, den ZETA-Testdriver als
Container zu bauen.

Der Testdriver ist ein HTTP-Server: Auf der einen Seite nimmt er HTTP-Anfragen
an, auf der anderen leitet er sie über den ZETA-Guard weiter. Damit lässt er
sich einfach für Tests einsetzen.

---

Status: Entwurf

Zielgruppe: Tester und Entwickler

Stand: ZETA-SDK 2.0.0

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Voraussetzungen](#voraussetzungen)
- [Vorgehen](#vorgehen)
  - [Bau der Bibliotheken](#bau-der-bibliotheken)
  - [Bau des Containers](#bau-des-containers)
- [Weitere Testdriver-Varianten](#weitere-testdriver-varianten)

## Überblick

Dieses Dokument zeigt, wie Sie aus dem gebauten SDK (siehe
[Wie Sie den ZETA-Demo-Client bauen und ausführen](Wie_Sie_den_ZETA_Demo_client_ausführen.md))
einen Container erstellen. Dieser dient in einem Kubernetes-Cluster als Proxy
zwischen einem fachlichen Testtreiber und dem ZETA-Guard.

Konfiguriert wird der Container über Umgebungsvariablen, die die Endpunkte des
ZETA-Guards festlegen; sie sind unten beschrieben.

## Voraussetzungen

Grundsätzlich sind für die Bereitstellung des Testdrivers die gleichen
Voraussetzungen nötig wie für die Ausführung des ZETA-Testclients.

Des Weiteren sind diese Tools nötig:

* Docker-Build-Tool

## Vorgehen

### Bau der Bibliotheken

Die nötigen Bibliotheken lassen sich mit

````
./gradlew clean jar copyRuntimeLibs
````

bauen. Die notwendigen Artefakte finden sich dann in

````
**/build/libs/*.jar
**/build/runtime-libs/*.jar
````

### Bau des Containers

Dann lässt sich der Container mithilfe des Dockerfiles bauen (Basis-Image
`eclipse-temurin:21-jre`, der Testdriver lauscht auf Port 8080):
````
docker build -f zeta-testdriver/Dockerfile .
````

Bevorzugt wird der Bau des Container-Images in einer automatisierten
CI/CD-Pipeline; die Datei `.gitlab-ci.yml` im SDK-Repository zeigt, wie das
geht.

## Weitere Testdriver-Varianten

Neben dem Testdriver auf Basis der JVM enthält das SDK-Repository zwei weitere
Varianten:

* **Native Testdriver** (`zeta-nativetestdriver`): nutzt die native Laufzeit
  des SDK (Kotlin/Native) und lauscht auf Port 8091.

  ````
  ./gradlew :zeta-nativetestdriver:linkReleaseExecutableLinuxX64
  docker build -f zeta-nativetestdriver/Dockerfile .
  ````

* **Android-Testdriver** (`zeta-android-testdriver`): betreibt das SDK in einer
  Android-App, die in einem Android-Emulator im Container läuft (siehe
  [Wie Sie den Testdriver nutzen](Wie_Sie_den_Testdriver_nutzen.md#android-testdriver)).
  Das Image baut auf einem Emulator-Image auf (`Dockerfile.android-emulator`)
  und benötigt die zuvor gebaute App:

  ````
  ./gradlew :zeta-android-testdriver:assembleDebug
  docker build --build-arg BASE_IMAGE=<emulator-image> -f Dockerfile.android-testdriver .
  ````
