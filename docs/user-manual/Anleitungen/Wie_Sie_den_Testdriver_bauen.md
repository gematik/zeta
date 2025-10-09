# Wie Sie den ZETA Testdriver als Container erstellen

Diese Anleitung unterstützt Tester dabei, den ZETA-Testclient zu bauen und auszuführen.
Der Testclient nutzt die API des Test-Fachdienstes und bietet eine Benutzerschnittstelle dafür.

Der Testdriver ist ein HttpServer, der auf der einen Seite HTTP Anfragen annimmt, auf der anderen
Seite den Aufruf an den ZETA_Guard weiterleitet. Er kann daher einfach für Tests verwendet werden.

---

Status: Grob-Entwurf

Zielgruppe: Tester und Entwickler

---

[TOC]

## Überblick

In diesem Dokument wird beschrieben, wie, basierend auf dem gebauten SDK (siehe [Wie Sie den ZETA Testclient ausführen](Wie_Sie_den_ZETA_Testclient_ausführen.md))
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

## Ausführen des Containers

Der Container kann mit einer hier beschriebenen deployment.yml installiert werden.

Hierbei sind anzupassen:

| Wert           | Beschreibung                                                                                            | Beispiel                                                   |
|----------------|---------------------------------------------------------------------------------------------------------|------------------------------------------------------------|
| CI_REGISTRY    | Hostname und Port der Container Registry<br/>Hinweis: ggf. ist auch der Pfad und die Version anzupassen | https://registry.host.example.com/                         |
| FACHDIENST_URL | URL des Fachdienstes wie er über den PEP zu erreichen ist                                               | https://fachdienst.host.example.com/pep/fachdienst_url/api |
| AUTHSERVER_URL | URL des Realms des ZETA Guard am PDP Auth Server                                                        | https://pdpauth.host.example.com/realms/fachdienst/        |

Im Beispiel unten werden die Fachdienst- und Authserver-URLs durch helm Variablen gesetzt, so dass sie
umgebungsspezifisch gesetzt werden können.

```
apiVersion: apps/v1
kind: Deployment
metadata:
  name: testdriver
  labels:
    component: testdriver
spec:
  replicas: 1
  selector:
    matchLabels:
      app: testdriver
  template:
    metadata:
      labels:
        app: testdriver
        component: testdrivert
    spec:
      securityContext:
        fsGroup: 1000
      imagePullSecrets:
        - name: gitlab-registry-credentials-zeta-group
      containers:
        - name: testdriver
          image: "CI_REGISTRY/zeta/zeta-client/zeta-sdk/testdriver-image:latest"
          imagePullPolicy: Always
          ports:
            - containerPort: 8080
          env:
            - name: CLIENT_BASE_URL
              value: "http://pep-proxy-svc"
            - name: FACHDIENST_URL
              value: {{ .Values.fachdienst_url }}
            - name: AUTHSERVER_URL
              value: {{ .Values.authserver_url }}

```

Die service.yml dazu sieht wie folgt aus:

```
apiVersion: v1
kind: Service
metadata:
  name: testdriver
spec:
  selector:
    app: testdriver
  ports:
    - name: http
      port: 80
      targetPort: 8080
  type: ClusterIP

```
## Continuous Integration

Die Continuous Integration lässt sich mit Hilfe der enthaltenen

````
.gitlab-ci.yml
.image-ci.yml
````
Dateien aufsetzen.


