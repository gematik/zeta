# Wie Sie den ZETA Testdriver als Container nutzen

Diese Anleitung unterstützt Tester dabei, den ZETA-Testclient auszuführen.
Der Testclient nutzt die API des Test-Fachdienstes und bietet eine Benutzerschnittstelle dafür.

Der Testdriver ist ein HttpServer, der auf der einen Seite HTTP Anfragen annimmt, auf der anderen
Seite den Aufruf an den ZETA_Guard weiterleitet. Er kann daher einfach für Tests verwendet werden.

---

Status: Entwurf

Zielgruppe: Tester und Entwickler

---

[TOC]

## Überblick

In diesem Dokument wird beschrieben, wie, basierend auf dem gebauten Testdriver Container image (siehe [Wie Sie den Testdriver bauen](Wie_Sie_den_Testdriver_bauen.md))
einen Container konfigurieren, der in einem Kubernetes als Proxy zwischen einem Fachlichen Testtreiber und dem ZETA-Guard genutzt werden kann.

Die Konfiguration des Containers geschieht über Umgebungsvariablen, die die Endpunkte des ZETA Guards festlegen.
Die Definition der Umgebungsvariablen ist unten beschrieben.

## Ausführen des Containers

Der Container kann mit einer hier beschriebenen deployment.yml installiert werden.

Hierbei sind anzupassen:

| Wert                      | Beschreibung                                                                                     | Beispiel                                                   |
|---------------------------|--------------------------------------------------------------------------------------------------|------------------------------------------------------------|
| FACHDIENST_URL            | URL of the resource server as reachable via the PEP                                              | https://fachdienst.host.example.com/pep/fachdienst_url/api |
| SMB_KEYSTORE_FILE         | Path to the SM-B Certificate-File (in .p12 format)                                               | /smcb-certificates.p12                                     |
| SMB_KEYSTORE_ALIAS        | Alias of the key in the SM-B Certificate file                                                    |                                                            |
| SMB_KEYSTORE_PASSWORD     | Password for the private key                                                                     |                                                            |
| SMCB_BASE_URL             | base url of the konnektor webservice interface (needs to include the "/ws")                      |                                                            |
| SMCB_MANDANT_ID           | <mandanten-ID>  für den Konnektor-Aufruf                                                         |                                                            |
| SMCB_CLIENT_SYSTEM_ID     | <client_system_id>  für den Konnektor-Aufruf                                                     |                                                            |
| SMCB_WORKSPACE_ID         | <workspace_id>  für den Konnektor-Aufruf                                                         |                                                            |
| SMCB_USER_ID              | <user-id> - diese wird nach Konnektor-Spezifikation für SMC-B Signaturen benötigt aber ignoriert |                                                            |
| SMCB_CARD_HANDLE          | <smcb-card-handle> für den Konnektor-Aufruf                                                      |                                                            |
| POPP_TOKEN                | Wert eines PoPP Tokens, welches an den PEP mitgegeben wird (optional)                            | eyJhbGciOiJFUzI1NiI......                                  |
| DISABLE_SERVER_VALIDATION | falls auf "true" gesetzt, wird die TLS Zertifikateprüfung des Servers ausgesetzt (für Tests)     |                                                            |

Im Beispiel unten werden die Werte durch helm Variablen gesetzt, sodass sie
umgebungsspezifisch gesetzt werden können.

Die Keystore-Datei wird als kubernetes Secret gemounted.

Anderer Werte werden ebenfalls durch helm Variablen gesetzt, wie das zu nutzende Container-Repository,
Version etc.

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
            - name: POPP_TOKEN
              value: {{ .Values.PoppToken | quote }}
            - name: SMB_KEYSTORE_FILE
              value: "/smcb-certificates.p12"
            - name: SMB_KEYSTORE_ALIAS
              value: "zeta.c_smcb_aut"
            - name: SMB_KEYSTORE_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: pdp-smcb-keystore
                  key: password
            - name: SMCB_BASE_URL
              value: {{ .Values.connector_base_url }}
            - name: SMCB_MANDANT_ID
              value: {{ .Values.connector_mandant_id }}
            - name: SMCB_CLIENT_SYSTEM_ID
              value: {{ .Values.connector_client_system_id }}
            - name: SMCB_WORKSPACE_ID
              value: {{ .Values.connector_workspace_id }}
            - name: SMCB_USER_ID
              value: {{ .Values.connector_user_id }}
            - name: SMCB_CARD_HANDLE
              value: {{ .Values.connector_card_handle }}
      volumes:
        - name: smcb-keystore
          secret:
            secretName: pdp-smcb-keystore
            items:
              - key: keystore
                path: "smcb-certificates.p12"
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

## Nutzen des Testdrivers

Der Testdriver erlaubt es, Aufrufe z.B. eines Testframeworks für den Fachdienst
über den Testdriver als ZETA Client, den ZETA-Guard an einen Fachdienst zu stellen.

Der Request an den Fachdienst wird als normaler HTTP Request gestellt, unter
Nutzung des ZETA nund ggf. ASL Protokolls weitergeleitet an den ZETA-Guard, und
von dort an den Fachdienst geleitet.

Dies erlaubt einfache Tests um sicherzustellen dass eine ZETA-Guard Installation
korrrekt erfolgt ist.

Die URLs die der Testdriver anbietet sind dabei diese:

| endpoint                     | access type      | purpose                                                                                                                                                                                                                       |
|------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| /proxy/*                     | all HTTP methods | Forward any requests path after the "/proxy/" part to the Fachdienst. According to the SDK API, includes discovery, client registration and authentication if not already done.<br/>Note this includes the websocket protocol |
| /testdriver-api/discover     | GET              | Just the discovery part of the protocol, i.e. reading the .well-known files                                                                                                                                                   |
| /testdriver-api/register     | GET              | Perform client registration (includes discovery if not already done)                                                                                                                                                          |
| /testdriver-api/authenticate | GET              | Retrieve and store an access token (includes client registration and discovery if not already done)                                                                                                                           |
| /testdriver-api/storage      | GET              | Retrieve the stored data (like client instance key, access token etc)                                                                                                                                                         |
| /testdriver-api/reset        | GET              | forget all the stored information, so any call will start triggering a discovery, client registration and authentication again                                                                                                |
| /health                      | GET              | health API for kubernetes                                                                                                                                                                                                     |

