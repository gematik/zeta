# Wie Sie den ZETA-Testdriver als Container erstellen

Diese Anleitung unterstützt Tester und Entwickler dabei, den ZETA-Testdriver als
Container zu bauen.

Der Testdriver ist ein HTTP-Server: Auf der einen Seite nimmt er HTTP-Anfragen
an, auf der anderen leitet er sie über den ZETA-Guard weiter. Damit lässt er
sich einfach für Tests einsetzen.

---

Status: Entwurf

Zielgruppe: Tester und Entwickler

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Voraussetzungen](#voraussetzungen)
- [Vorgehen](#vorgehen)
  - [Bau der Bibliotheken](#bau-der-bibliotheken)
  - [Bau des Containers](#bau-des-containers)

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

Dann lässt sich der Container mithilfe des Dockerfiles bauen:
````
docker build -f zeta-testdriver/Dockerfile .
````
