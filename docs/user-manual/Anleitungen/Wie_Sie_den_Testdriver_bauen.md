# Wie Sie den ZETA Testdriver als Container erstellen

Diese Anleitung unterstützt Tester dabei, den ZETA-Testclient zu bauen.
Der Testclient nutzt die API des Test-Fachdienstes und bietet eine Benutzerschnittstelle dafür.

Der Testdriver ist ein HttpServer, der auf der einen Seite HTTP Anfragen annimmt, auf der anderen
Seite den Aufruf an den ZETA_Guard weiterleitet. Er kann daher einfach für Tests verwendet werden.

---

Status: Entwurf

Zielgruppe: Tester und Entwickler

---

[TOC]

## Überblick

In diesem Dokument wird beschrieben, wie, basierend auf dem gebauten SDK (siehe [Wie Sie den ZETA Testclient ausführen](Wie_Sie_den_ZETA_Demo_client_ausführen.md))
einen Container erstellen, der in einem Kubernetes als Proxy zwischen einem Fachlichen Testtreiber und dem ZETA-Guard genutzt werden kann.

Die Konfiguration des Containers geschieht dann über Umgebungsvariablen, die die Endpunkte des ZETA Guards festlegen.
Die Definition der Umgebungsvariablen ist unten beschrieben.

## Voraussetzungen

Grundsätzlich sind für die Bereitstellung des Testdriver die gleichen Voraussetzungen nötit wie für die Ausführung des ZETA Testclients.

Desweiteren sind diese Tools nötig:

* Docker build Tool

## Vorgehen

### Bau der Bibliotheken

Die Nötigen Bibliotheken lassen sich mit

````
./gradlew clean jar copyRuntimeLibs
````

bauen. Die Notwendigen Artefakte finden sich dann in

````
**/build/libs/*.jar
**/build/runtime-libs/*.jar
````

### Bau des Containers

Dann lässt sich der Container mit Hilfe des Dockerfiles bauen:
````
docker build -f zeta-testdriver/Dockerfile .
````



