# Wie Sie den ZETA-Testdriver als Container nutzen

Diese Anleitung unterstützt Tester und Entwickler dabei, den ZETA-Testdriver als
Container zu konfigurieren und zu betreiben.

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
- [Ausführen des Containers](#ausführen-des-containers)
- [Nutzen des Testdrivers](#nutzen-des-testdrivers)
- [Load-Driver für Lasttests](#load-driver-für-lasttests)
- [Android-Testdriver](#android-testdriver)

## Überblick

Dieses Dokument zeigt, wie Sie aus dem gebauten Testdriver-Container-Image
(siehe [Wie Sie den Testdriver bauen](Wie_Sie_den_Testdriver_bauen.md)) einen
Container konfigurieren. Dieser dient in einem Kubernetes-Cluster als Proxy
zwischen einem fachlichen Testtreiber und dem ZETA-Guard.

Konfiguriert wird der Container über Umgebungsvariablen, die die Endpunkte des
ZETA-Guards festlegen; sie sind unten beschrieben.

## Ausführen des Containers

Installieren lässt sich der Container mit der hier beschriebenen
`deployment.yml`.

Hierbei sind anzupassen:

| Wert                      | Beschreibung                                                                                                          | Beispiel                                                   |
|---------------------------|-----------------------------------------------------------------------------------------------------------------------|------------------------------------------------------------|
| FACHDIENST_URL            | URL of the resource server as reachable via the PEP                                                                   | https://fachdienst.host.example.com/pep/fachdienst_url/api |
| AUTH_MODE                 | Anmeldeverfahren: `SMB` (Default) oder `OIDC` (mobiler Client-Flow über den sektoralen IDP)                           | SMB                                                        |
| SMB_KEYSTORE_FILE         | Path to the SM-B Certificate-File (in .p12 format)                                                                    | /smcb-certificates.p12                                     |
| SMB_KEYSTORE_ALIAS        | Alias of the key in the SM-B Certificate file                                                                         |                                                            |
| SMB_KEYSTORE_PASSWORD     | Password for the private key                                                                                          |                                                            |
| SMB_KEYSTORE_B64          | Alternativ zur Datei: der Keystore Base64-kodiert (vor allem für den Load-Driver)                                     |                                                            |
| REQUIRED_ROLE_OID         | Role-OID, die das TI-Zertifikat des ASL-Servers enthalten muss                                                        | 1.2.276.0.76.4.324                                         |
| ASL_PROD                  | Produktiv- (`true`, Default) oder Nicht-Produktivmodus des ASL-Protokolls                                              | false                                                      |
| POPP_TOKEN                | Wert eines PoPP-Tokens, welches an den PEP mitgegeben wird (optional)                                                 | eyJhbGciOiJFUzI1NiI......                                  |
| DISABLE_SERVER_VALIDATION | Falls auf `true` gesetzt, wird die TLS-Zertifikatsprüfung des Servers ausgesetzt (für Tests)                          |                                                            |
| FILTER_HOST_HEADERS       | Falls `true`, leitet der Testdriver die Header `Host`, `Forwarded`, `X-Forwarded-Host` und `X-Forwarded-Port` nicht weiter (weder in der Anfrage noch in der Antwort). Default ist `false`; bei Konfiguration über `CONFIG_FILE` ist der Filter aktiv. Die Testsuite erwartet `false` | false                                                      |
| OIDC_IDP_ISS              | Nur für `AUTH_MODE=OIDC`: Issuer des sektoralen IDP                                                                   |                                                            |
| OIDC_IDP_ALIAS            | Nur für `AUTH_MODE=OIDC`: Alias des IDP im Keycloak-Broker                                                            | zeta-sekidp-oidc                                           |
| OIDC_BASE_URI             | Nur für `AUTH_MODE=OIDC`: Basis-URI der Redirect-URIs (`{OIDC_BASE_URI}/app`, `{OIDC_BASE_URI}/oidc`)                 |                                                            |
| OIDC_TEST_KVNR            | Nur für `AUTH_MODE=OIDC`: KVNR der Testidentität für die Anmeldung beim Test-SekIDP                                   |                                                            |
| OIDC_BINDING_EMAIL        | Nur für `AUTH_MODE=OIDC`: E-Mail-Adresse für die E-Mail-Bindung                                                       |                                                            |
| CONFIG_FILE               | Optional: Pfad einer Konfigurationsdatei mit instanzspezifischen Werten (siehe [Load-Driver](#load-driver-für-lasttests)) |                                                            |
| LISTEN_HOST, LISTEN_PORT  | Optional: Adresse und Port, auf denen der Testdriver lauscht                                                          | 0.0.0.0, 8080                                              |

Die früheren `SMCB_*`-Variablen für eine Konnektor-Anbindung werden seit
Version 1.2.2 nicht mehr ausgewertet.

Im Beispiel unten werden die Werte durch Helm-Variablen gesetzt, sodass sie
umgebungsspezifisch gesetzt werden können.

Die Keystore-Datei wird als Kubernetes-Secret gemountet.

Andere Werte werden ebenfalls durch Helm-Variablen gesetzt, etwa das zu nutzende
Container-Repository, die Version etc. Vollständige Helm-Charts für den
Testdriver – je eines für SM-B (`testdriver-smcb`) und für den mobilen
Client-Flow (`testdriver-oidc`) – finden sich im
[zeta-guard-helm Repository](https://github.com/gematik/zeta-guard-helm/tree/main/charts).

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
        component: testdriver
      {{- if .Values.devMode }}
      annotations:
        zeta.dev/rollout-timestamp: "{{ now | unixEpoch }}"
      {{- end }}
    spec:
      securityContext:
        fsGroup: 1000
      imagePullSecrets:
        - name: gitlab-registry-credentials-zeta-group
      containers:
        - name: testdriver
          image: "{{ default (printf "%s%s" .Values.global.registry_host .Values.registry_name) .Values.image.registry }}{{ .Values.image.repository }}:{{ .Values.image.tag }}"
          imagePullPolicy: "{{ .Values.image.pullPolicy }}"
          ports:
            - containerPort: {{ .Values.containerPort }}
          readinessProbe:
            httpGet:
              path: /health
              port: {{ .Values.containerPort }}
          volumeMounts:
            - name: smcb-keystore
              mountPath: "/smcb-certificates.p12"
              subPath: "smcb-certificates.p12"
              readOnly: true
          env:
            - name: FACHDIENST_URL
              value: {{ .Values.fachdienst_url }}
            - name: DISABLE_SERVER_VALIDATION
              value: {{ quote .Values.disableServerValidation }}
            - name: ASL_PROD
              value: {{ quote .Values.aslProdEnv }}
            - name: POPP_TOKEN
              value: {{ .Values.PoppToken | quote }}
            - name: AUTH_MODE
              value: "SMB"
            - name: SMB_KEYSTORE_FILE
              value: "/smcb-certificates.p12"
            - name: SMB_KEYSTORE_ALIAS
              value: "zeta.c_smcb_aut"
            - name: SMB_KEYSTORE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: pdp-smcb-keystore
                  key: password
            - name: REQUIRED_ROLE_OID
              value: {{ .Values.requiredOid }}
      volumes:
        - name: smcb-keystore
          secret:
            secretName: pdp-smcb-keystore
            items:
              - key: keystore
                path: "smcb-certificates.p12"
```


Die `service.yml` dazu sieht wie folgt aus:

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

## Nutzen des Testdrivers

Mit dem Testdriver richtet etwa ein Testframework seine Aufrufe an den
Fachdienst: Der Testdriver tritt dabei als ZETA-Client auf und leitet über den
ZETA-Guard weiter.

Das Testframework stellt einen normalen HTTP-Request. Der Testdriver leitet ihn
über das ZETA- und ggf. das ASL-Protokoll an den ZETA-Guard weiter, von dort
geht er an den Fachdienst.

So lässt sich mit einfachen Tests prüfen, ob eine ZETA-Guard-Installation
korrekt aufgesetzt ist.

Die URLs, die der Testdriver anbietet, sind dabei diese:

| endpoint                                       | access type      | purpose                                                                                                                                                                                                                       |
|------------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| /proxy/*                                       | all HTTP methods | Forward any requests path after the "/proxy/" part to the Fachdienst. According to the SDK API, includes discovery, client registration and authentication if not already done.<br/>Note this includes the websocket protocol |
| /testdriver-api/discover                       | GET              | Just the discovery part of the protocol, i.e. reading the .well-known files                                                                                                                                                   |
| /testdriver-api/register                       | GET              | Perform client registration (includes discovery if not already done)                                                                                                                                                          |
| /testdriver-api/authenticate                   | GET              | Retrieve and store an access token (includes client registration and discovery if not already done)                                                                                                                           |
| /testdriver-api/storage                        | GET              | Retrieve the stored data (like client instance key, access token etc)                                                                                                                                                         |
| /testdriver-api/reset                          | GET              | forget all the stored information, so any call will start triggering a discovery, client registration and authentication again                                                                                                |
| /testdriver-api/configure                      | POST             | Konfiguriert den Testdriver zur Laufzeit, u. a. TLS-Validierung, Resource-URL und eine zusätzliche CA                                                                                                                         |
| /testdriver-api/notifications/pushers          | GET              | Pusher des angemeldeten Nutzers auflisten (Vorschau)                                                                                                                                                                          |
| /testdriver-api/notifications/pushers          | POST             | Pusher registrieren (JSON-Body `PusherConfigRequest`); das Schlüsselmaterial erzeugt das SDK                                                                                                                                  |
| /testdriver-api/notifications/pushers          | PUT              | Den über `appId`/`pushkey` identifizierten Pusher aktualisieren (JSON-Body `PusherConfigRequest`)                                                                                                                              |
| /testdriver-api/notifications/pushers          | DELETE           | Den über die Query-Parameter `pushkey` und `appId` identifizierten Pusher deregistrieren                                                                                                                                       |
| /testdriver-api/notifications/channels         | GET              | Für den Nutzer verfügbare Kanäle mit Default-Status auflisten                                                                                                                                                                 |
| /testdriver-api/notifications/channels/local   | GET              | Kanal-Konfiguration des lokal registrierten Pushers lesen                                                                                                                                                                     |
| /testdriver-api/notifications/channels/local   | POST             | Kanäle des lokal registrierten Pushers setzen (JSON-Body `SetChannelsRequest`)                                                                                                                                                |
| /oidc/status                                   | GET              | Status der E-Mail-Bindung im OIDC-Flow abfragen (ob E-Mail-Adresse oder OTP erwartet wird)                                                                                                                                   |
| /oidc/collect-email                            | POST             | E-Mail-Adresse für die E-Mail-Bindung übermitteln                                                                                                                                                                             |
| /oidc/verify-otp                               | POST             | OTP zur Bestätigung der E-Mail-Bindung übermitteln                                                                                                                                                                            |
| /oidc/resend-otp                               | POST             | Erneuten Versand des OTP auslösen                                                                                                                                                                                             |
| /oidc/change-email                             | GET              | Die für die E-Mail-Bindung genutzte Adresse ändern                                                                                                                                                                            |
| /oidc/kvnr-email                               | POST             | KVNR der Testidentität und E-Mail-Adresse für die nächste OIDC-Anmeldung setzen (`kvnr`, `email` im Body)                                                                                                                      |
| /health                                        | GET              | health API for kubernetes                                                                                                                                                                                                     |

Die Notifications-Endpunkte nutzen intern die JVM-Testvariante des
Notifications-Moduls (`notificationsForTesting()`) und setzen einen ZETA-Guard
mit aktiviertem Notification Service voraus. Der Notification Service verlangt
bei der Registrierung eines Pushers die Felder `deviceDisplayName` und `data`.
Beispielaufrufe für den OIDC-Flow und die Notifications-Endpunkte enthält die
`README.md` im Ordner `zeta-testdriver` des SDK-Repositorys.

## Load-Driver für Lasttests

Der Testdriver enthält zusätzlich einen Load-Driver, der mehrere unabhängige
SDK-Instanzen parallel betreibt:

| endpoint                                       | access type      | purpose                                                                                                                                         |
|------------------------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------|
| /load/create_instances?count=N&autoInit=true   | POST             | N SDK-Instanzen anlegen; mit `autoInit=true` (Default) werden Discovery und Client-Registrierung parallel ausgeführt, die Authentifizierung folgt beim ersten Aufruf |
| /load/list_instances                           | GET              | Alle Instanzen mit Zustand (`CREATED`, `INITIALIZING`, `READY`, `FAILED`) und ggf. Fehlermeldung auflisten                                      |
| /load/delete_instances                         | DELETE           | Instanzen entfernen; mit `?id=1&id=2` gezielt einzelne, ohne Parameter alle                                                                     |
| /load/{instanceIndex}/*                        | all HTTP methods | Anfrage über eine bestimmte Instanz an den Fachdienst weiterleiten (inkl. WebSocket)                                                           |
| /loaddriver-api/{instanceIndex}/discover       | GET              | wie `/testdriver-api/discover`, für die angegebene Instanz                                                                                      |
| /loaddriver-api/{instanceIndex}/register       | GET              | wie `/testdriver-api/register`, für die angegebene Instanz                                                                                      |
| /loaddriver-api/{instanceIndex}/authenticate   | GET              | wie `/testdriver-api/authenticate`, für die angegebene Instanz                                                                                  |
| /loaddriver-api/{instanceIndex}/reset          | GET              | wie `/testdriver-api/reset`, für die angegebene Instanz                                                                                         |

Die Instanzen lassen sich im Body von `/load/create_instances` konfigurieren
(Feld `instances` mit `id`, `fachdienstUrl`, `smbKeystoreFile`,
`smbKeystoreAlias`, `smbKeystorePassword`) oder über die Datei aus
`CONFIG_FILE`. Diese enthält die Werte der Umgebungsvariablen mit der Nummer der
Instanz als Suffix, z. B. `FACHDIENST_URL_1`, `SMB_KEYSTORE_FILE_1`,
`SMB_KEYSTORE_ALIAS_1` und `SMB_KEYSTORE_PASSWORD_1`. Es gilt die Reihenfolge:
API-Body vor Konfigurationsdatei vor Umgebungsvariablen. Enthält die
Konfigurationsdatei Werte für Instanz 1, nutzt auch der normale Testdriver
diese statt der Umgebungsvariablen.

Hinweis: Die `README.md` des SDK-Repositorys nennt für die Konfigurationsdatei
noch die Schlüssel `SMB_FILE_1`, `SMB_ALIAS_1` und `SMB_PASSWORD_1`; der
Testdriver liest jedoch die oben genannten Schlüssel.

## Android-Testdriver

Der Android-Testdriver (`zeta-android-testdriver`) betreibt das SDK in einer
Android-App mit eingebettetem HTTP-Server. Damit lässt sich das SDK auf einer
echten Android-Laufzeit prüfen, insbesondere die Push-Benachrichtigungen über
Firebase Cloud Messaging von Ende zu Ende. Die App meldet sich über den
mobilen Client-Flow (OIDC) an; das OTP für die E-Mail-Bindung liest sie
selbsttätig aus dem MailCatcher. Als Speicher nutzt sie eine
`InMemoryStorage`.

Der Android-Testdriver bietet eine eigene, kleinere API:

| endpoint                                         | access type | purpose                                                                                     |
|--------------------------------------------------|-------------|---------------------------------------------------------------------------------------------|
| /androidproxy/*                                  | GET         | Den Pfad nach `/androidproxy/` über das SDK an den Fachdienst weiterleiten                   |
| /androiddriver-api/health                        | GET         | Health-Check                                                                                |
| /androiddriver-api/reset                         | GET         | Gespeicherte Daten verwerfen (`forget()`) und den SDK-Client neu aufbauen                   |
| /androiddriver-api/notifications/register        | POST        | Pusher mit dem FCM-Token des Emulators registrieren                                         |
| /androiddriver-api/notifications/subscribe-all   | POST        | Alle verfügbaren Kanäle für den lokalen Pusher einschalten                                  |
| /androiddriver-api/notifications/unsubscribe-all | POST        | Alle Kanäle für den lokalen Pusher ausschalten                                              |
| /androiddriver-api/notifications/received        | GET, DELETE | Empfangene (entschlüsselte) Push-Nachrichten abrufen bzw. die Liste leeren                  |

Die Notifications-Endpunkte stehen nur zur Verfügung, wenn eine
Push-Gateway-URL und Firebase konfiguriert sind.

Der Android-Testdriver lässt sich im Cluster betreiben und aus der CI-Pipeline
steuern. Das Container-Image (`Dockerfile.android-testdriver`) startet einen
Android-Emulator mit der Testdriver-App und stellt die API auf Port 8080
bereit. Konfiguriert wird es über Umgebungsvariablen, mindestens
`FACHDIENST_URL` (bzw. `FACHDIENST_OIDC_URL`), `OIDC_BASE_URI`, `OIDC_IDP_ISS`,
`OIDC_IDP_ALIAS` und `OIDC_TEST_KVNR`; optional u. a. `OIDC_BINDING_EMAIL`,
`POPP_TOKEN`, `PUSH_GATEWAY_URL`, `PUSHER_APP_ID` sowie die
`FIREBASE_*`-Angaben für Firebase Cloud Messaging.
