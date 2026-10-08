# Wie Sie Probleme im SDK analysieren können

Dieser Abschnitt zeigt, wie Sie Probleme im Client analysieren. Er wächst mit
der weiteren Entwicklung.

## Wie komme ich an Log-Informationen?

Das SDK wird in einen Client eingebunden; der Client stellt ihm über die
Konfiguration einen Log-Provider bereit, über den das SDK seine Ausgaben
schreibt.

Der Provider nimmt Ausgaben bis zum Debug-Level entgegen. Damit lassen sich auch
die Aufrufe und Antworten des Guards genau analysieren.

Wie das im Einzelnen aussieht, hängt von der Plattform ab und steht in der
jeweiligen API-Beschreibung.

## Beispiel-Ausgaben

### Interne Logs

Interne Logs tragen den Log-Level als Präfix, z. B. `[DEBUG]`. Bei einigen
Modulen kommt ein Modulkenner wie `[STORAGE]` hinzu.

````
[DEBUG] [Zeta] Getting ASL session
[DEBUG] [Zeta] [STORAGE] get key=-5618hc:asl_session_by_resource:-k594xb found=true
[DEBUG] [Zeta] Available attributes: [AttributeKey: OrchestratorBypass, AttributeKey: EngineCapabilities, AttributeKey: ResponseBodySaved, AttributeKey: asl-inner-status, AttributeKey: ExpectSuccessAttributeKey, AttributeKey: asl-inner-headers, AttributeKey: client-config, AttributeKey: CallLogger]
[DEBUG] [Zeta] Has InnerStatusKey? true
[DEBUG] [Zeta] Effective status: 201, Raw status: 200
[DEBUG] [Zeta] Response status: 200 OK
[DEBUG] [Zeta] ASL 200 response. Retrying handshake
[DEBUG] [Zeta] PROCEED: iteration=1
````

An den Log-Ausgaben des Storage-Moduls lässt sich ablesen, wie das SDK ein vom
Client bereitgestelltes Storage-Modul verwendet.

#### Timing-Ausgaben

Verschiedene Funktionen sind mit Zeitmessungen instrumentiert. Diese werden mit
`-TIMING` gekennzeichnet.
````
[DEBUG] [Zeta] [ORCHESTRATOR-TIMING] url=https://zeta-dev.*****/pep/achelos_testfachdienst/api/erezept executeRequest=443.004400ms total=488.275100ms
...
[DEBUG] [Zeta] [ORCHESTRATOR-TIMING] handler=ConfigurationHandler need=de.gematik.zeta.sdk.flow.FlowNeed$ConfigurationFiles@1e203562 time=5.977100ms
...
[INFO] [Zeta] [ENSURE-AUTH-TIMING] getValidToken=3.620500ms getAuthToken_total=12.132200ms
...
[INFO] [Zeta] [ENSURE-AUTH-TIMING] getAuthToken=12.151200ms
...
[DEBUG] [Zeta] [AUTH-TIMING] hash=35.8us
...
[INFO] [Zeta] [ENSURE-AUTH-TIMING] hashToken=54.7us
...
[DEBUG] [Zeta] [ORCHESTRATOR-TIMING] handler=EnsureAccessTokenHandler need=de.gematik.zeta.sdk.flow.FlowNeed$Authentication@30f7067 time=15.499ms
...
[DEBUG] [Zeta] [CRYPTO-TIMING] signWithDpopKey(rs:https://zeta-dev.*******/pep/achelos_testfachdienst/:zero:audience)=1.547900ms inputSize=624
````

#### Request- und Response-Logs

Im Log-Level Info werden weiterhin die Requests und Responses an den ZETA-Guard
geloggt. Dies betrifft sowohl PDP- als auch PEP-Anfragen.

Dabei werden Cookies und Header ebenso mitgeschrieben.

Für ASL-Requests sind allerdings nur die äußeren Requests sichtbar.

````
[INFO] [Zeta] REQUEST: https://zeta-dev.********/ASL/426204a8-f3f7-4697-b1b3-1e50f65675d8
METHOD: POST
COMMON HEADERS
-> Accept: application/json; application/octet-stream
-> Authorization: dpop eyJhbGciOiJFUzI**********************************d7qO2etUhhEdOvQ-Q
-> Cookie: zeta_route=5d26b****************22656c3
-> PoPP: eyJhbGciOiJFUzI1NiIsInR5cC***************************************ZFCKm3LfPG7vVSw
-> dpop: eyJ0eXAiOiJkcG9wK2p3dCIsIm***************************************lc7Ilc3gQNXADKA
-> zeta-asl-nonpu-tracing: Y4Xho**********************PsDVPEgMNw=
CONTENT HEADERS
-> Content-Length: 4539
-> Content-Type: application/octet-stream
BODY Content-Type: application/octet-stream
BODY START
````

Diesen Log-Ausgaben lassen sich alle nötigen Informationen entnehmen — etwa die
JWTs, die Sie dann mit anderen Werkzeugen sichtbar machen.
