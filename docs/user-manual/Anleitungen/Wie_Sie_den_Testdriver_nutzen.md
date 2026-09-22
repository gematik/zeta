# Wie Sie den ZETA-Testdriver als Container nutzen

Diese Anleitung unterstützt Tester und Entwickler dabei, den ZETA-Testdriver als
Container zu konfigurieren und zu betreiben.

Der Testdriver ist ein HTTP-Server: Auf der einen Seite nimmt er HTTP-Anfragen
an, auf der anderen leitet er sie über den ZETA-Guard weiter. Damit lässt er
sich einfach für Tests einsetzen.

---

Status: Entwurf

Zielgruppe: Tester und Entwickler

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Ausführen des Containers](#ausführen-des-containers)
- [Nutzen des Testdrivers](#nutzen-des-testdrivers)

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
| POPP_TOKEN                | Wert eines PoPP-Tokens, welches an den PEP mitgegeben wird (optional)                            | eyJhbGciOiJFUzI1NiI......                                  |
| DISABLE_SERVER_VALIDATION | Falls auf `true` gesetzt, wird die TLS-Zertifikatsprüfung des Servers ausgesetzt (für Tests)     |                                                            |

Im Beispiel unten werden die Werte durch Helm-Variablen gesetzt, sodass sie
umgebungsspezifisch gesetzt werden können.

Die Keystore-Datei wird als Kubernetes-Secret gemountet.

Andere Werte werden ebenfalls durch Helm-Variablen gesetzt, etwa das zu nutzende
Container-Repository, die Version etc.

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

| endpoint                     | access type      | purpose                                                                                                                                                                                                                       |
|------------------------------|------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| /proxy/*                     | all HTTP methods | Forward any requests path after the "/proxy/" part to the Fachdienst. According to the SDK API, includes discovery, client registration and authentication if not already done.<br/>Note this includes the websocket protocol |
| /testdriver-api/discover     | GET              | Just the discovery part of the protocol, i.e. reading the .well-known files                                                                                                                                                   |
| /testdriver-api/register     | GET              | Perform client registration (includes discovery if not already done)                                                                                                                                                          |
| /testdriver-api/authenticate | GET              | Retrieve and store an access token (includes client registration and discovery if not already done)                                                                                                                           |
| /testdriver-api/storage      | GET              | Retrieve the stored data (like client instance key, access token etc)                                                                                                                                                         |
| /testdriver-api/reset        | GET              | forget all the stored information, so any call will start triggering a discovery, client registration and authentication again                                                                                                |
| /health                      | GET              | health API for kubernetes                                                                                                                                                                                                     |

