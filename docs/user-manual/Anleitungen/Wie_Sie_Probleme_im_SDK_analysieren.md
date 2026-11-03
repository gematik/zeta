# Wie Sie Probleme im SDK analysieren können

Dieser Abschnitt zeigt, wie Sie Probleme im Client analysieren. Er wächst mit
der weiteren Entwicklung.

## Wie komme ich an Log-Informationen?

Das SDK wird in einen Client eingebunden; der Client stellt ihm über die
Konfiguration einen Log-Provider bereit, über den das SDK seine Ausgaben
schreibt. Ohne eigenen Log-Provider schreibt das SDK nach stdout.

Der Provider nimmt Ausgaben bis zum Debug-Level entgegen. Damit lassen sich auch
die Aufrufe und Antworten des Guards genau analysieren. Der Standard-Log-Level
ist `ERROR`; für die Analyse setzen Sie ihn auf `INFO` oder `DEBUG`:

| Sprache       | Log-Level setzen                                   | Request- und Response-Logs                                                                     |
|---------------|----------------------------------------------------|------------------------------------------------------------------------------------------------|
| Kotlin        | `Log.setLogLevel(ZetaLogLevel.DEBUG)`              | über `logging(LogLevel.ALL)` am `ZetaHttpClientBuilder` einschalten (Default: aus)              |
| Java          | `Log.INSTANCE.setLogLevel(ZetaLogLevel.DEBUG)`     | wie Kotlin                                                                                     |
| C/C++         | Feld `logLevel` der `ZetaSdk_LogVTable`            | immer eingeschaltet; sichtbar ab Log-Level `INFO`                                              |
| C#            | `ZetaClientConfig.LogLevel` (nur zusammen mit `Logger`) | immer eingeschaltet; sichtbar ab Log-Level `Info`                                         |

Wie das im Einzelnen aussieht, hängt von der Plattform ab und steht in der
jeweiligen API-Beschreibung, siehe
[Wie Sie das ZETA-SDK integrieren](Wie_Sie_das_ZETA_SDK_integrieren.md#logging).

Beim Erzeugen eines SDK-Clients schreibt das SDK seine Version ins Log
(`[SDK-INIT] ZETA SDK version …`); per API liefern sie `ZetaSdk.getVersion()`,
`ZetaSdk_getVersion()` bzw. `ZetaClient.GetVersion()`. Geben Sie die Version bei
Fehlermeldungen immer mit an.

## Fehlermeldungen der nativen API

Die C-API wirft keine Ausnahmen über die Sprachgrenze, sondern meldet Fehler
über Rückgabewerte (`NULL`, `-1` bzw. das Feld `error` der HTTP-Antwort). Das
C#-SDK setzt diese Rückgabewerte teils in eine `ZetaSdkException` um (beim
Erzeugen des Clients und bei HTTP-Aufrufen), teils gibt es sie als `int` weiter
(`Discover`, `Register`, `Authenticate`, `ClearRegistration`).

`ZetaSdk_getLastError()` (freizugeben mit `ZetaSdk_freeLastError()`) bzw. in C#
`ZetaClient.GetLastError()` liefert die Meldung der letzten Ausnahme, die das
SDK an der Sprachgrenze abgefangen hat. Die Meldung gilt je Thread und wird nicht
zurückgesetzt; sie kann also von einem früheren Fehler stammen. Schlagen
Discovery, Registrierung, Authentifizierung, Logout, `clearRegistration` oder
`close` fehl, liefern diese Funktionen nur `-1` und schreiben den Grund ins Log
(z. B. `[SDK] register failed: …`). Details siehe
[Fehlerbehandlung der nativen API](Wie_Sie_das_ZETA_SDK_integrieren.md#fehlerbehandlung-der-nativen-api).

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
[DEBUG] [Zeta] ASL: 200 transport response. InnerStatus=201
[DEBUG] [Zeta] PROCEED: iteration=1
````

An den Log-Ausgaben des Storage-Moduls lässt sich ablesen, wie das SDK ein vom
Client bereitgestelltes Storage-Modul verwendet.

Bei ASL-Aufrufen unterscheidet das SDK den Status der äußeren
Transport-Antwort (`Raw status`) vom Status der inneren, entschlüsselten
Antwort (`Effective status`); an den Aufrufer gibt es den inneren Status
zurück. Baut das SDK den ASL-Kanal neu auf, etwa weil die ASL-Session
serverseitig abgelaufen ist, protokolliert es das als Warnung, z. B.
`ASL: PEP reports AslSessionExpired. Re-establishing channel`.

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
[DEBUG] [Zeta] [AUTH-TIMING] SubjectTokenIssuance requestAccessToken=38.512ms
...
[INFO] [Zeta] [ENSURE-AUTH-TIMING] hashToken=54.7us
...
[DEBUG] [Zeta] [ORCHESTRATOR-TIMING] handler=EnsureAccessTokenHandler need=de.gematik.zeta.sdk.flow.FlowNeed$Authentication@30f7067 time=15.499ms
...
[DEBUG] [Zeta] [CRYPTO-TIMING] signWithDpopKey(rs:https://zeta-dev.*******/pep/achelos_testfachdienst/:zero:audience)=1.547900ms inputSize=624
````

Die expliziten Aufrufe von Discovery, Registrierung und Authentifizierung
protokolliert das SDK zusätzlich mit `[SDK-TIMING]`.

#### Request- und Response-Logs

Sind die Request- und Response-Logs eingeschaltet (siehe oben), werden im
Log-Level Info die Requests und Responses an den ZETA-Guard geloggt. Dies
betrifft sowohl PDP- als auch PEP-Anfragen.

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

Hinweis: Diese Logs enthalten Tokens und weitere sensible Daten. Schalten Sie
sie nur zur Analyse und nicht im produktiven Betrieb ein. In der C-API und im
C#-SDK sind sie immer eingeschaltet und erscheinen, sobald der Log-Level auf
INFO oder DEBUG steht.

#### Sperrprüfung

Die Prüfung des Sperrstatus von Zertifikaten protokolliert das SDK mit dem
Kennzeichen `[REVOCATION]`. Daraus geht hervor, welche Quelle (gestapelte
OCSP-Antwort, OCSP, CRL) die Prüfung entschieden hat und warum eine Quelle
fehlschlug. Unter Android führt ein fehlender Eintrag in der Network Security
Configuration dazu, dass OCSP- und CRL-Abrufe über `http://` mit
`CLEARTEXT communication to <host> not permitted by network security policy`
scheitern (siehe [Android und iOS](Wie_Sie_das_ZETA_SDK_integrieren.md#android-und-ios)).
