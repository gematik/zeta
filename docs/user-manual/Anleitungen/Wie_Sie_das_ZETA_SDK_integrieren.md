# Wie Sie das ZETA SDK integrieren


Diese Anleitung unterstützt Entwickler dabei, das ZETA-SDK zu bauen und in eigene Produkte zu integrieren.

Für mehr Details über die verschiedenen Komponenten des SKDs siehe auch die [Struktur des SDK Repositories](../Referenzen/SDK-Uebersicht.md).

---

Status: Entwurf

Zielgruppe: Entwickler

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
  - [Client-API](#client-api)
- [Build-Plattformen](#build-plattformen)
  - [kotlin](#kotlin)
  - [Java](#java)
  - [C++](#c)
- [API Übersicht](#api-übersicht)
- [Angebotene API](#angebotene-api)
  - [Konfiguration](#konfiguration)
  - [Reginfo](#reginfo)
  - [Authinfo](#authinfo)
  - [AuthConfig](#authconfig)
  - [StorageConfig](#storageconfig)
  - [ZetaHttpClientBuilder](#zetahttpclientbuilder)

## Überblick

Das ZETA-SDK besteht aus einer Reihe von Modulen, die in [Struktur des SDK Repositories](../Referenzen/SDK-Uebersicht.md) beschrieben sind.
Der Einstieg in des SDK findet dabei über die Klasse *ZetaSdk* statt. Diese bietet ein Builder-Interface, mit dem das ZETA SDK
konfiguriert werden kann.

In der initialen Build-Konfiguration wird auch die Resource mitgegeben, d.h. die URL des Resource Servers. Nach dem build() Aufruf
steht eine Instanz des ZETA SDK für diese Resource zur Verfügung. Auf diese Weise können mehrere Instanzen des ZETA SDK parallel
für mehrere Fachdienste erstellt werden.

## API Konzept

Dieser Abschnitt gibt einen Überblick über die Nutzung der API.
Weitere Details sind im Source Code nachzusehen.

Die hier beschriebene API ist grundsätzlich in analoger Form in allen Sprachen enthalten.
Wo es Abweichungen gibt wird darauf eingegangen.

### Benötigte Parameter

Die API benötigt für den Aufruf eines Fachdienstes nach Spezifikation mehrere Parameter, die zum
Teil aus der Registrierung des Clients stammen, zum Teil aus der Spezifikation des Fachdienstes.

#### Client-Registrierung

Ein ZETA-konformer Client muss bei der gematik registriert werden, bevor er einen Fachdienst über einen
ZETA-Guard aufrufen darf. Die registrierten Informationen werden in die OPA Regeln eingetragen,
mit denen der ZETA-Guard den Aufruf prüft.

| Parameter      | Beschreibung                                             | Kommentar                                                                                                         |
|----------------|----------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------|
| productId      | Eine Identifikation des Produkts, das das SDK integriert | Diese ID wird nach A_25337 bei der Registrierung durch die gematik zugewiesen und entspricht dem Format aus A_25338-01 |
| productVersion | Eine vom Hersteller vergebene Versionsnummer             | Dieser Parameter muss dem Format aus A_25338-01 entprechen                                                    |

Weitere Parameter, die insbesondere Hash-Werte der tatsächlich installierten Dateien für die spezifische Produkt-Version
enthalten werden in einem späteren Update der Spezifikation zur Hardware-Attestierung hinzukommen.

#### Fachdienst-Spezifikation

| Parameter       | Beschreibung                                                         | Kommentar                                                                                                                                                                             |
|-----------------|----------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| scopes          | Eine Liste von scopes, für den jeweiligen Aufruf benötigt werden.    | Diese Liste wird durch die Spezifikation des aufgerufenen Fachdienstes festgelegt. Für den Aufruf des VSDM ist z.B. in A_26744 festgelegt, dass der scope "vsdservice" zu nutzen ist. |
| fachdienstUrl   | Die Basisadresse des aufzurufenden Fachdienstes                      | Dies wird durch die Fachdienst-Spezifikation vorgegeben. Für VSDM ist sie in gemspec_VSDM, Kapitel 4.3.1 definiert                                                                    |
| requiredRoleOid | Die im ASL Zertifikat erwartete OID                                  | Das ASL Zertifikat weist sich damit in der entsprechenden Rolle nach gemspec_OID aus. Für Fachdienste die ASL mit dem ZETA-Guard terminieren wird diese OID die oid_zeta-guard sein. In anderen Fachdiensten, bei denen der ZETA-Guard das ASL Protokoll nur durchleitet (potentiell z.B. e-Rezept oder ePA), werden andere OIDs zum Tragen kommen. |

#### Installationsspezifische Parameter

Weitere Parameter werden bei der konkreten Installation festgelegt.

| Parameter          | Beschreibung                                                       | Kommentar                                                                                                                                                                                                                                               |
|--------------------|--------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| clientName         | Der Name der spezifischen Client-Installation                      | Diese wird im Rahmen der Client-Registrierung mit den Daten nach dem client-statement.yaml Schema [gematik github](https://github.com/gematik/zeta/blob/main/src/schemas/client-statement.yaml) an den ZETA-Guard übertragen                            |
| aslProdEnvironment | Unterscheidung zwischen Produktion und nicht-Produktionssystemen   | Nach A_24628-01 (aus gemspec_krypt) wird das ASL Protokoll unterschiedlich verarbeitet, um Fehlersuche in nicht-Produktionssystemen zu erleichtern. ZETA-Guard hat eine analoge Konfiguration, die für eine erfolgreiche Verbindung übereinstimmen muss |
| exp                | Expiration time (duration in seconds) for the client assertion JWT | Dies definiert die Gültigkeitsdauer des Client Assertion JWT                                                                                                                                                                                            |                                                                                                                                                                                           |
| platformProductId  | Informationen über die Client-Plattform für die Attestierung       | Übergabe z.B. des Betriebssystemtyps oder der Store IDs wie sie für die Attestierung des Clients verwendet werden. Siehe z.B. [gematik Repository](https://github.com/gematik/zeta/blob/main/src/schemas/posture-software.yaml)                         |

Weitere Parameter kommen über die Einbindung existierender Primärsystemfunktionalitäten hinzu, wie z.B. Konnektorzugriffe.

#### Netzwerkkonfiguration

Bei der Nutzung der API können dem HTTP Client innerhalb des SDK verschiedene Netzwerkparameter mitgegeben werden. Hierbei werden bestimmte Defaults genutzt falls diese Parameter nicht angegeben werden. Diese sind in der
Klasse `NetworkConfig` definiert.

| Parameter            | Beschreibung                                                                                        | Kommentar                               |
|----------------------|-----------------------------------------------------------------------------------------------------|-----------------------------------------|
| connect timeout      | Timeout in ms für den Abbruch eines Verbindungsaufbaus                                              | Default ist 15 Sekunden                 |
| request timeout      | Timeout für das Warten auf die Antwort für einen Request                                            | Default ist 30 Sekunden                 |
| socket timeout       | Timeout für das Lesen von Daten auf einem Socket                                                    | Default ist 60 Sekunden                 |
| retry Statuscodes    | HTTP Statuscodes für die ein Retry durchgeführt wird                                                | Default ist keine (damit keine Retries) |
| max retries          | Maximale Anzahl der Retries                                                                         | Default is 0                            |
| only idempotent      | Nur idempotente Aufrufe (GET, HEAD, ...) werden wiederholt wenn true                                | Default ist true                        |
| Custom CAs           | CA PEMs können dem Client mitgegeben werden, um custom Zertifikate zu erlauben                      | default keins                           |
| Log Level und Logger | Der Log Level für die Requests                                                                      | Default ist INFO auf dem Default Logger |
| proxy Config         | Konfiguration eines Proxies für Netzwerkzugriffe, i.e. Typ (HTTP vs SOCKS), Host, Port, Credentials | Default ist kein Proxy                  |


### Wiederverwendung existierender Funktionalität

Um Doppelimplementierungen in einem Primärsystem zu vermeiden, wird Dependency Injection in der API verwendet.
Damit wird z.B. der sichere Speicher, das Logging, oder auch der Zugriff auf den Konnektor dem SDK zur Verfügung gestellt.

#### Storage

Mit diesem Objekt wird der Speicher konfiguriert. Als Default kann eine Simple Dateiablage verwendet werden.
Die Daten werden dabei mit einem in der Konfiguration angegebenen AES Schlüssel verschlüsselt.

Eine Custom-Implementierung zur Wiederverwendung existierender Funktionalität kann die Klasse SdkStorage ableiten und die Methoden
`put()`, `get()`, `remove()`, und `clear()` überschreiben.

Bei Nutzung einer eigenen Implementierung liegt die Verschlüsselung in der Verantwortung des Primärsystems;
der `aesB64Key` wird in diesem Fall ignoriert. Alle übergebenen Pointer müssen für die gesamte Laufzeit
der SDK-Instanz gültig bleiben.

Das Storage Interface umfasst folgende Methoden:

| Methode             | Beschreibung                                   |
|---------------------|------------------------------------------------|
| `put(key, value)`   | Wert unter dem angegebenen Schlüssel speichern |
| `get(key)`          | Wert für den angegebenen Schlüssel lesen       |
| `remove(key)`       | Eintrag für den angegebenen Schlüssel löschen  |
| `clear()`           | Alle gespeicherten Einträge löschen            |


#### Logging

Das Logging wird an zwei Stellen konfiguriert. Zum einen bei der Konfiguration des SDK, sowie beim Erzeugen eines
Clients für einen bestimmten Request. Dies dient im Wesentlichen dazu, dass "Hintergrund"-Aufrufe des SDK wie die zur
Client-Registrierung oder Authentication einen anderen Log-Level haben können als fachliche Aufrufe des Ressource-Servers.

Standardmäßig gibt das SDK Log-Ausgaben nach stdout aus. Über einen eigenen Log-Provider kann die Ausgabe
an das Logging-System des Primärsystems weitergeleitet werden. Der Callback wird synchron aus internen SDK-Threads
aufgerufen. Implementierungen müssen thread-safe sein. Wenn ein eigener Logger gesetzt ist, wird die stdout-Ausgabe unterdrückt.

Der Standard-Log-Level ist `ERROR`. Folgende Log-Level stehen zur Verfügung:

| Level   | Beschreibung                              |
|---------|-------------------------------------------|
| `DEBUG` | Alle Meldungen inkl. ausführlichem Debug  |
| `INFO`  | Informationsmeldungen und höher           |
| `WARN`  | Warnungen und Fehler                      |
| `ERROR` | Nur Fehlermeldungen (Standard)            |
| `NONE`  | Keine Log-Ausgabe                         |

Das Log-Provider Interface umfasst folgende Methoden:

| Methode                       | Beschreibung            |
|-------------------------------|-------------------------|
| `d(tag, message, throwable)`  | DEBUG Meldung ausgeben  |
| `i(tag, message, throwable)`  | INFO Meldung ausgeben   |
| `w(tag, message, throwable)`  | WARN Meldung ausgeben   |
| `e(tag, message, throwable)`  | ERROR Meldung ausgeben  |

#### Konnektor-Zugriff

Zur Erstellung eines SubjectTokens wird der Zugriff auf den Konnektor benötigt. Dies wird in der Regel
in einem Primärsystem bereits umgesetzt sein. Daher bietet die API die Möglichkeit, den Zugriff auf den Konnektor
an den Client, d.h. das Primärsystem an sich, auszulagern.

Hier gibt es einen Unterschied in der Umsetzung der kotlin/Java und C++/C# Varianten. Die kotlin/Java-Implementierungen erwarten eine
Instanz des "SubjectTokenProvider", der die beiden nötigen Konnektor-Aufrufe kapselt und die benötigten Krypto-Operationen durchführt.
Für C++/C# gibt es eine Lösung die nur die Konnektor-API benötigt, während die Krypto-Operationen im SDK gekapselt sind.

Je nach Ansatz werden Implementierungen mitgeliefert, die weitere verschiedene Konfigurationsparameter benötigen.
So benötigt der SmbTokenProvider den Dateipfad der Zertifikatsdatei mit Alias und Passwort. Der SmcbTokenProvider hingegen
benötigt die Adresse des Konnektors sowie weitere für den Konnektoraufruf nötige Parameter wie mandant, handle, etc.

Der CustomSmcbTokenProvider kann genutzt werden eine eigene Implementierung anzubinden. Er erwartet eine ConnectorAPI als
Parameter, der nur die beiden Konnektor-Aufrufe abbildet. Die Instanz muss dabei die Aufrufparameter selbst verwalten.

Bei Nutzung eines eigenen Connectors werden die SMC-B SOAP Felder (`baseUrl`, `mandantId` etc.) ignoriert.
Beide Callbacks müssen genau einmal pro Aufruf aufgerufen werden, auch im Fehlerfall (dann mit size=0).


Das Connector Interface umfasst folgende Methoden:

#### Kotlin / Java / C#

| Methode                                                    | Beschreibung                                                                         |
|------------------------------------------------------------|--------------------------------------------------------------------------------------|
| `readCertificate(): ByteArray`                             | SMC-B X.509 Zertifikat im DER Format zurückgeben                                     |
| `externalAuthenticate(base64Challenge: String): ByteArray` | Base64-kodierten Challenge signieren und die DER-kodierte ECDSA Signatur zurückgeben |

#### C++

| Methode                                                 | Beschreibung                                                                                                                                        |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| `readCertificate(ctx, cb, cbCtx)`                       | SMC-B X.509 Zertifikat im DER Format an das SDK zurückgeben. `cb` muss genau einmal mit dem Ergebnis aufgerufen werden, auch im Fehlerfall (size=0) |
| `externalAuthenticate(ctx, base64Challenge, cb, cbCtx)` | Base64-kodierten Challenge signieren und die DER-kodierte ECDSA Signatur zurückgeben. `cb` muss genau einmal aufgerufen werden, auch im Fehlerfall  |

`ctx` ist der opaque Kontext-Pointer aus der VTable, der unverändert weitergegeben wird. `cbCtx` ist der opaque Kontext-Pointer, der unverändert an den Callback weitergegeben werden muss.

#### TPM-Zugriff

Dieses Objekt ist aktuell noch nicht genutzt. Es wird in einer Weiterentwicklung der Spezifikation ermöglichen,
den Zugriff auf das Hardware-TPM an das Primärsystem auszulagern.


## API Übersicht

Die Nutzung der API besteht aus drei Schritten:

1. Erstellen eines `ZetaSdkClient` Objektes unter Nutzung der Methode `ZetaSdk.build()`, mit der benötigten Konfiguration, pro Fachdienst-Basis-URL. Dies benötigt den Großteil der oben beschriebenen
   Parameter und Konfigurationen. Auf diesem Client kann der Status der Verbindung (inkl. Client Registrierung etc) abgefragt bzw. verändert werden.
2. Im zweiten Schritt wird am ZetaSdkClient ein `ZetaHttpClient` erstellt, der mit den nötigen Netzwerkkonfigurationen konfiguriert werden kann. Zudem kann hier der für fachliche Requests
   spezifische Logger konfiguriert werden.
3. Auf diesem HTTP Client können dann die Aufrufe des Fachdienstes erfolgen.

Hinweis: aufgrund der Technologieunterschiede können sich die Aufrufe in den verschiedenen Implementierungssprachen unterscheiden.
So können insb. Helper Klassen verwendet werden, die die Aufrufe am ZetaSdkClient bzw. dem ZetaHttpClient dann indirekt aufrufen.
Beispiele aus den einzelnen Sprachen sind in den jeweiligen Testclients zu finden und werden unten referenziert.

### ZetaSdkClient API

Das `ZetaSdk` ist die Builder Klasse, mit der ein `ZetaSdkClient` erstellt werden kann.

#### ZetaSdk

| Operation      | Beschreibung                                                                                                                                                                                                                                                 | Return value         | Errors                                                                                                                                                                                   |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| build()        | Statische Methode, um einen neuen SDK Client zu erstellen. Die Resource URL des Endpunkts wird hierbei als Input gegeben. D.h. für jeden Fachdienst kann ein separater Client erzeugt werden. Weitere Parameter sind z.B. notwendige Callback-Informationen. | ZetaSDKClient Object |                                                                                                                                                                                          |

#### ZetaSdkClient

Der `ZetaSdkClient` ist ein Objekt, welches für den Zugriff auf einen bestimmten Fachdienst vorkonfiguriert ist (nach dem Bauen durch `ZetaSdk`).

| Operation      | Beschreibung                                                                                                                                                                                           | Return value                | Errors                                                                                                                                                                                   |
|----------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| forget()       | statische Methode, um alle Informationen zu einem FQDN zu vergessen wie client ID, client instance key, ...                                                                                            | -                           | error codes                                                                                                                                                                              |
| -              |                                                                                                                                                                                                        |                             |                                                                                                                                                                                          |
| discover()     | Umsetzen der Discovery und Configuration. Dieser Call ist optional und wird ggf. automatisch nachgeholt                                                                                                | -                           | Fehler bei der Discovery und Configuration, insb. wenn für die Resource URL keine gültige Endpunkt-Konfiguration (im Sinne eines Eintrags in einer OPR .well-known Datei) gefunden wurde |
| register()     | Ausführen der Client registration, wenn nötig (keine client_id vorhanden). Includiert discover() falls dieses noch nicht ausgeführt wurde.                                                             | -                           | error codes                                                                                                                                                                              |
| authenticate() | Ausführen der Authentifizierung falls nötig (kein AccessToken vorhanden). Falls gültiges Refresh Token vorhanden, wird dieses genutzt. Inkludiert register() falls dieses noch nicht ausgeführt wurde. | -                           | error codes                                                                                                                                                                              |
| httpClient()   | gibt einen HTTP Client zurück, dessen Operationen überschrieben werden um die notwendigen ZETA-spezifischen Protokolle umzusetzen                                                                      | Ein `ZetaHttpClient` Objekt |                                                                                                                                                                                          |
| ws()           | Eröffnen einen WebSockets session                                                                                                                                                                      |                             |                                                                                                                                                                                          |
| status()       | gibt den Status des SdkClients zurück, also ob eine Client-Registrierung vorliegt, ein AccessToken vorliegt usw.                                                                                       | Ein `SdkStatus` Objekt      | -                                                                                                                                                                                        |
| logout()       | Ausloggen aus dem Fachdienst, so dass ein neues Access Token benötigt wird                                                                                                                             | -                           | error codes                                                                                                                                                                              |
| close()        | Schliessen des ZetaSDKclients, ohne relevante Inhalte zu vergessen                                                                                                                                     | -                           | error codes                                                                                                                                                                              |

Die verschiedenen Stufen des ZETA-Protokolls (`discover()`, `register()`, `authenticate()`) werden bei Erstellung des HttpClient bzw. Aufruf einer Resource _automatisch_ ausgeführt.
Zusammen mit der `status()` Methode dienen sie nur der feingranularen Kontrolle durch das Primärsystem, soweit gewünscht.

### Konfiguration für das Erzeugen eines ZetaSdkClient

Statische Informationen, die für die einzelnen Schritte benötigt werden, werden über das Storage Module zwischengespeichert.
Falls diese Informationen nicht vorhanden sein sollten, werden sie über Callbacks abgefragt.
Das in der build() Methode angegebene `BuildConfig` Objekt enthält auch die notwendigen Informationen über die Callbacks.

| Callback            | Called when                                                                                                                                                                                                       | expected return value |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------|
| productId           | Die gematik Produkt-ID                                                                                                                                                                                            |                       |
| productVersion      | die Produktversion                                                                                                                                                                                                |                       |
| clientName          | der Name des Client                                                                                                                                                                                               |                       |
| storageConfig       | Storage provider, der zum Speichern von Daten verwendet wird.                                                                                                                                                     |                       |
| tpmConfig           | Wird in Stufe 2 die Konfiguration des Hardware-TPM enthalten                                                                                                                                                      |                       |
| authConfig          | Konfiguration des Authentication Prozesses, wie Token scopes, Expiry etc. oder auch ASL Tracing flag                                                                                                              |                       |
| platformProductId   | Plattform-Informationen wie Typ des Betriebssystems, store IDs der Anwendung für die Software-Attestierung (siehe [gematik github](https://github.com/gematik/zeta/blob/main/src/schemas/posture-software.yaml)   |                       |
| httpClientBuilder   | Builder für HttpClients; wird für die Aufrufe der PDP APIs verwendet                                                                                                                                              |                       |
| registration_cb()   | wenn während register(), authenticate(), or späterer HTTP Methoden eine Client-Registrierung erforderlich ist, und die nötigen Informationen nicht vorhanden sind                                                 | A reginfo object      |
| authentication_cb() | wenn während authenticate(), oder dem späteren Aufruf von HTTP Methoden Authentifizierungsinformationennötig sind.                                                                                                | An authinfo object    |

Hinweis: in Implementierungsstufe 1 werden aktuell keine Callbacks genutzt. In Implementierungsstufe 2 können hier Anfragen
zum Beispiel zum Pushed-Authentication-Request an den IDP hinzukommen.

### StorageConfig

Mit diesem Objekt wird der Speicher konfiguriert. Wie oben beschrieben kann hier eine Custom-Implementierung eingefügt werden, die die sichere Speicherung an das Primärsystem auslagert.

| Attribut  | Beschreibung                                                                                              |
|-----------|-----------------------------------------------------------------------------------------------------------|
| provider  | Das eigentliche Speicherinterface (optional)                                                              |
| aesB64Key | Verschlüsselungsschlüssel für den Default-Speicher (falls kein eigener Speichermechanismus genutzt wurde) |

Falls kein provider angegeben wird, wird ein verschlüsselter Standard-Speicher verwendet, der mit dem angegebenen
AES key verschlüsselt wird. Details siehe dazu das README im Quellcode des storage Modul bzw. im Umsetzungskonzept.

### AuthConfig

Mit diesem Objekt wird die Authentifizierung parameterisiert.

| Attribut             | Beschreibung                                                                                                                                                               |
|----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| scopes               | Scope-Werte für die Erstellung des Access Tokens                                                                                                                           |
| exp                  | Token expiry des Subject Tokens. Der PDP akzeptiert nur maximal 30 Sekunden                                                                                                |
| aslProdEnvironment   | wenn false, werden die ASL keys (für Testing) als Header im outer ASL Request mitgegeben (A_24628-01)                                                                      |
| subjectTokenProvider | Objekt, mit dem ein Subject Token erzeugt werden kann. Es werden aktuell zwei Implementierungen bereitgestellt, einmal für SM-B Dateien und einmal für SMC-B via Konnektor |
| attestation          | Konfiguriert den Attestierungsmodus und die Verbindung zum Attestierungsservice. Default: `AttestationConfig.software()`                                                   |
| requiredRoleOid      | Die OID, die im TI-Zertifikat des ASL-Servers vorhanden sein muss. Wird beim ASL-Handshake validiert. Z.B. `1.2.276.0.76.4.324` für `oid_zeta-guard` (gemSpec_OID)         |

### ZetaHttpClientBuilder

Mit diesem Objekt wird das HTTP Protokoll parametrisiert.
Es enthält Parameter u.a. für retries und Connection Timeouts.

Das hier mitgegebene Objekt wird für die Aufrufe des PDP verwendet, die im Hintergrund stattfinden wenn
über den ZETA-Guard eine Resource aufgerufen werden soll. Für die Aufrufe der Resource via PEP
wird ein HTTP Client via httpClient() instanziiert, der eine eigene HTTP Client Konfiguration erhalten kann.

## Build-Plattformen

### kotlin

Im Folgenden ist das Beispiel eines Aufrufs einer Resource am Fachdienst in kotlin dargestellt.

Die Konfigurationen sind umfangreicher als hier dargestellt und lassen sich in der API Dokumentation weiter unten bzw. besser
in der IDE anschauen.

`````
        // statischer Aufruf um einen ZetaSdkClient zu erzeugen
        val sdk = ZetaSdk.build(
            "https://<resource-url>",                       // Basis-URL des Fachdienstes
            BuildConfig(                                    // BuildConfig Objekt mit der ganzen Konfiguration
                "demo-client",                              // Produkt ID
                "1.0.0",                                    // Produkt Version
                "client-sdk",                               // Client Name
                StorageConfig.Custom(InMemoryStorage()),    // Konfiguration des sicheren Speichers; InMemoryStorage für Tests
                object : TpmConfig {},                      // Aktuell nicht genutzt - wird mit Hardware-Attestation erweitert
                AuthConfig(                                 // Konfiguration der Authentifizierung
                    listOf(
                        "zero:audience",                    // Liste der scopes
                    ),
                    30,                                     // Expiration des Subject Tokens
                    true,                                   // Ist es ein Produktions-Environment?
                                                            // Der Provider für die Subject Tokens, hier SM-B
                    SmbTokenProvider(SmbTokenProvider.Credentials("<keystore-file>", "<alias>", "<password>")),
                    requiredRoleOid,                        // Die OID, die im ASL Server-Zertifikat erwartet wird
                ),
                platformProductId,                          // Plattform-Informationen für die Attestierung
                httpClientBuilder,                          // Builder Objekt für den HTTP Client für die PDP-Aufrufe
            ),
        )

        // Erzeugung des Http Clients
        val client = sdk.httpClient {                       // erwartet als Parameter ein HttpClientBuilder Objekt
            logging(LogLevel.ALL)                           // Log-Level für fachliche Requests
        }

        // Aufruf einer URL auf dem Fachdienst.
        val helloResult = client.get("/hellozeta")
            .bodyAsText()
`````

Die PlatformProductId lässt sich abhängig von der Plattform wie folgt erzeugen:

`````
    private fun getPlatformProduct(): PlatformProductId {
        return when (val plat = platform()) {
            is Platform.Jvm.Macos, Platform.Native.Macos -> PlatformProductId.AppleProductId("apple", "macos", listOf())
            is Platform.Jvm.Linux, Platform.Native.Linux -> PlatformProductId.LinuxProductId("linux", "", "", "0.5.0")
            is Platform.Jvm.Windows, Platform.Native.Windows -> PlatformProductId.WindowsProductId("windows", "", "")
            else -> error("Unknown platform: $plat")
        }
    }
`````

Die genauen Definitionen sind im Quellcode nachzusehen, wo auch der jeweils aktuelle Stand liegt.

Dann kann das zeta-sdk als Maven Dependency eingebunden und dann wie folgt genutzt werden.
Dazu wird die folgende Maven Dependency in das `pom.xml` aufgenommen (mit der jeweils relevanten Version):
````
<!-- https://mvnrepository.com/artifact/de.gematik.zeta/zeta-sdk-jvm -->
<dependency>
  <groupId>de.gematik.zeta</groupId>
  <artifactId>zeta-sdk</artifactId>
  <version>x.y.z</version>
</dependency>
````

### Java

Das ZETA-SDK kann als Maven-Abhängigkeit in Java-Projekte eingebunden werden:
Vor der Nutzung muss das SDK in das lokale Maven-Repository publiziert werden:
```
./gradlew publishToMavenLocal
```

Dann kann das zeta-sdk als Maven Dependency eingebunden und dann wie folgt genutzt werden.
Dazu wird die folgende Maven Dependency in das `pom.xml` aufgenommen (mit der jeweils relevanten Version):

````
<!-- https://mvnrepository.com/artifact/de.gematik.zeta/zeta-sdk-jvm -->
<dependency>
  <groupId>de.gematik.zeta</groupId>
  <artifactId>zeta-sdk-jvm</artifactId>
  <version>x.y.z</version>
</dependency>
````

#### API Aufruf

Hier ist der API Aufruf
````
        // Erstellen der SDK Instanz
        ZetaSdkClient sdkClient = ZetaSdk.INSTANCE.build(
            getFirstResourceUrl(props),                                 // Fachdienst-URL, hier aus einer Konfigurationsdatei gelesen
            new BuildConfig(                                            // BuildConfig Objekt
                "ZETA-Test-Client",                                     // Produkt ID
                "1.0.0",                                                // Produkt Version
                "sdk-client",                                           // Client Name
                new StorageConfig.Custom(new InMemoryStorage()),        // Storage Implementierung (hier InMemory nur zum Testen)
                new TpmConfig() {                                       // ungenutzt bis die Hardware-Attestierung spezifiziert ist
                },
                new AuthConfig(                                         // Authentication Konfiguration
                    List.of(
                        "zero:audience"                                 // scopes
                    ),
                    30,                                                 // Expiration des Subject Tokens in Sekunden
                    aslProdEnv,                                         // ist es eine Produktivumgebung
                    getTokenProvider(props),                            // SubjectTokenProvider
                    AttestationConfig.software(),                       // Aktuell nur Software-Attestation
                    requiredRoleId                                      // Role OID die im ASL Zertifikat erwartet wird
                ),
                getPlatformProductId(),                                 // Platform Information
                                                                        // ZetaHttpClientBuilder für die PDP Aufrufe, inkl. Logging und möglicher Abschaltung der Server Validierung (für Nutzung im Testsystem)
                new ZetaHttpClientBuilder("").disableServerValidation(disableServerValidation).logging(LogLevel.ALL),
                null,                                                   // ungenutzt - registration Callback für Stufe 2
                null                                                    // ungenutzt - authentication Callback für Stufe 2
            ));

        // Erstellen eines ZetaHttpClients
        // Als Parameter wird ein ZetaHttpClientBuilder erwartet
        httpClient = sdkClient.httpClient(it -> {
            it.logging(LogLevel.ALL);
            it.disableServerValidation(disableServerValidation);
            return Unit.INSTANCE;
        });
````

Für die eigentlichen Aufrufe, können die Methoden am `ZetaHttpClient` direkt verwendet werden.
Um die Aufrufe asynchron umsetzen zu können, wird ein Helper-Objekt verwendet wie in folgendem Beispiel:

````
            HttpClientExtension.getAsync(httpClient, "hellozeta", headers)
                .thenCompose(HttpClientExtension::bodyAsText)
                .whenComplete((body, ex)  -> {
                    if (ex != null){
                        Log.INSTANCE.e(ex, "Http", () -> "Http Get failed");
                    }
                    else {
                        Log.INSTANCE.i(null, "Http", () -> "Body:" + body);
                    }
                }).join();
````

Eine Beispielimplementierung findet sich im [gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-java/src/main/java/de/gematik/zeta/Main.java).

### C++

Das ZETA-SDK kann als native Shared Library (`.dylib` / `.so` / `.dll`) in C++-Projekte eingebunden werden.

#### Schritt 1 — SDK Shared Library bauen
```bash
./gradlew :zeta-sdk:linkDebugSharedMacosArm64   # macOS
./gradlew :zeta-sdk:linkDebugSharedLinuxX64      # Linux
./gradlew :zeta-sdk:linkDebugSharedMingwX64      # Windows
```

#### Schritt 2 — Header einbinden

Das SDK liefert einen einzigen generierten Header:
- `libzeta_sdk_api.h` (Linux / macOS)
- `zeta_sdk_api.h` (Windows)
```cpp
#ifdef _WIN32
    #include "zeta_sdk_api.h"
#else
    #include "libzeta_sdk_api.h"
#endif
```

#### Schritt 3 — Gegen die Library linken
```bash
clang++ main.cpp \
    -I /path/to/sdk/build/bin/macosArm64/debugShared \
    -L /path/to/sdk/build/bin/macosArm64/debugShared \
    -lzeta_sdk \
    -Wl,-rpath,@executable_path \
    -o my-client
```

#### Nutzung der API

Die Nutzung der API ist hier aufwändiger, da die Erstellung der Objekte "manuell" geschehen muss.

##### Erzeugung der Konfigurationsobjekte

````
    ZetaSdk_StorageConfig storageConfig = {
            aesB64Key,                  // Base64-kodierter AES Schlüssel für die Storage-Verschlüsselung
            nullptr,                    // storagePath - Default ist "$HOME/.zeta_sdk_storage (Linux only)
            nullptr,                    // customStorage - Optionales Custom Storage Interface. Bei Nutzung wird aesB64Key ignoriert
    };

    ZetaSdk_TpmConfig tpmConfig = {};

    ZetaSdk_SmbConfig smbConfig = {
            keystoreFile,
            alias,
            password
    };

    ZetaSdk_SmcbConfig smcbConfig = {};

    ZetaSdk_AuthConfig authConfig = {
            const_cast<char**>(scopes), ARRAY_SIZE(scopes), // Liste der scopes
            30,                                             // Expiration des Subject Tokens
            aslProd,                                        // Produktionsumgebung
            &smbConfig, &smcbConfig,                        // SM-B und SMC-B Konfiguration. Nur eines nötig
            requiredRoleOid
    };

    ZetaSdk_LogVTable logVTable = {
            nullptr,                                        // context
            my_log,                                         // Log-Callback Funktion
            ZETA_LOG_LEVEL_ERROR                            // Log-Level (Standard: ERROR)
    };

    // Zusammenbau des BuildConfig Objekts
    ZetaSdk_BuildConfig buildConfig = {
            resource,                                       // Basis-URL des Fachdienstes
            const_cast<char*>(PRODUCT_ID),                  // Produkt ID
            const_cast<char*>(PRODUCT_VERSION),             // Produkt Version
            const_cast<char*>(CLIENT_NAME),                 // Client-Name
            &storageConfig, &tpmConfig, &authConfig,         // Konfigurations-Objekte
            &logVTable                                      // Optionaler Log-Provider
    };
                                                            // Erstellen des ZetaSdk Objekts
    ZetaSdk_Client*     zetaSdkClient  = (ZetaSdk_Client*)ZetaSdk_buildZetaClient(&buildConfig, disableTls);
                                                            // Erstellen des ZetaHttpClient Objekts
    ZetaSdk_HttpClient* zetaHttpClient = (ZetaSdk_HttpClient*)ZetaSdk_buildHttpClient(zetaSdkClient);

````

##### Nutzung einer eigenen Konnektor-Anbindung

Die oben beschriebenen Konfigurationen nutzen die SDK-bereitgestellten Anbindungen an den Konnektor um
ein SMC-B Zertifikat zu erstellen. Um eine eigene Implementierung zu nutzen, kann der
Aufruf auf den Konnektor durch eigene Implementierungen wie folgt ersetzt werden:

````
    // Signaturen der Konnektor-Aufrufe mit Beispiel-Implementierungen

    // Lesen des Zertifikats.
    void my_read_certificate(void* ctx, ZetaSdk_BytesCallback cb, void* cbCtx) {
            // Bereitstellung des Zertifikats - muss durch den Aufruf des Konnektors ersetzt werden
            auto derBytes = base64Decode(SMCB_CERTIFICATE_B64);
            // Rückgabe des Zertifikats an das ZETA SDK
            cb(cbCtx, derBytes.data(), (int)derBytes.size());
    }

    // Aufruf der Authenticate API
    void my_external_authenticate(void* ctx, const char* base64Challenge,
                                        ZetaSdk_BytesCallback cb, void* cbCtx) {
            // Bereitstellung der Signatur - muss durch den Aufruf des Konnektors ersetzt werden
            auto sigBytes = base64Decode(SMCB_SIGNATURE_DER_B64);
            // Rückgabe der Signatur an das ZETA SDK
            cb(cbCtx, sigBytes.data(), (int)sigBytes.size());
    }

    // Bereitstellen einer Struktur mit den Konnektor-Aufrufen
    // Der ctx Pointer wird 1:1 an die Konnektor-Methoden weitergegeben
    ZetaSdk_SmcbVTable smcbVTable = {
            ctx,
            my_read_certificate,
            my_external_authenticate
    };

    // Erstellen der Konfigurationsobjekte für die BuildConfig
    // Hier wird die Struktur mit den Konnektor-Aufrufen in das SMCB Config-Objekt
    ZetaSdk_SmbConfig  smbConfig  = { nullptr, nullptr, nullptr };
    ZetaSdk_SmcbConfig smcbConfig = { .customSmcb = &smcbVTable };
````

##### Nutzung einer eigenen Storage-Implementierung

Um eine eigene Storage-Implementierung zu nutzen, wird in der StorageConfig ein
eigene VTable eingebunden:

````
    ZetaSdk_StorageVTable storageVTable = {
            &myStorage,
            CppStorage::put,
            CppStorage::get,
            CppStorage::remove,
            CppStorage::clear,
    };

    ZetaSdk_StorageConfig storageConfig = {
            nullptr,
            nullptr,
            &storageVTable,
    };

````


##### Nutzung des Clients

Für die Nutzung des Clients werden statische Helfer-Methoden verwendet, die das
jeweils zu nutzende ZetaHttpClient Objekt als Parameter übergeben bekommen:

````

                                                            // Beispiel-Header. Hier ein konfigurierter PoPP Token. (PoPP Token muss durch ein durch den Client dynamisches Token ersetzt werden)
    ZetaSdk_HttpHeader headers[] = {
                {(char*)POPP_HEADER, poppToken}
    };

                                                            // Erstellen des Request Objekts
    ZetaSdk_HttpRequest getRequest = {
                (char*)"hellozeta",                         // Pfad der an die Basis-URL angehängt wird
                NULL,                                       // BODY für POST/PUT requests
                headers,                                    // Zu übergebende Header
                ARRAY_SIZE(headers)
    };

                                                            // Aufruf des Fachdienstes
    ZetaSdk_HttpResponse* response = (ZetaSdk_HttpResponse*)ZetaHttpClient_get(zetaHttpClient, &getRequest);

````

#### Beispielimplementierung

Ein Beispiel findet sich hier im [gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-cpp/).
Dieses nutzt die gradle-Funktionalität zum Bauen.

Für eine Makefile-basierten Build gibt es den [nativeclient im gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-nativeclient-cpp/)

Der Client findet sich in `zeta-nativeclient-cpp/` and besteht aus:
- `hello-http.cpp` — HTTP client sample (GET, POST, PUT, DELETE, HEAD, OPTIONS)
- `hello-ws.cpp` — WebSocket client sample (STOMP connect, subscribe, create, read)
- `Makefile` — cross-platform build and run

Das Makefile erwartet die folgende Ordnerstruktur:
```
zeta-sdk/
├── zeta-sdk/              <- SDK module
│   └── build/bin/
│       ├── macosArm64/debugShared/
│       ├── linuxX64/debugShared/
│       └── mingwX64/debugShared/
└── zeta-nativeclient-cpp/ <- C++ client
    ├── hello-http.cpp
    ├── hello-ws.cpp
    ├── Makefile
    └── .env
```

Das Makefile detektiert automatisch das Betriebssystem und nutzt die korrekte SDK Version:
- **macOS (Apple Silicon)** → `macosArm64/debugShared`
- **Linux** → `linuxX64/debugShared`
- **Windows** → `mingwX64/debugShared`

Falls die Ordnerstruktur davon abweicht, muss die Variable `LIB_DIR` im Makefile entsprechend angepasst werden.

### C#

#### Vorbereitung: Installation .NET 10

Unter MacOS lässt sich das so installieren:

```bash
brew update
brew install dotnet
```

Für Linux und Windows sind Downloads unter [https://dotnet.microsoft.com/download](https://dotnet.microsoft.com/download) zu finden.

#### Native SDK Bauen

```bash
cd ~/Workspace/zeta-sdk
./gradlew :zeta-sdk:linkDebugSharedMacosArm64
./gradlew :zeta-sdk:linkDebugSharedMacosX64
./gradlew :zeta-sdk:linkDebugSharedMingwX64
./gradlew :zeta-sdk:linkDebugSharedLinuxX64
```

Die Bibliothek wird dort abgelegt:
```
build/bin/{osArch}/debugShared/
```

Nach dem Bau des SDK ist die native Library passend für die Zielplattform in den
`runtimes/` Ordner zu kopieren:

| Platform      | Source file                                          | Destination                      |
|---------------|------------------------------------------------------|----------------------------------|
| macOS ARM64   | `build/bin/macosArm64/debugShared/libzeta_sdk.dylib` | `runtimes/osx-arm64/native/`     |
| macOS x64     | `build/bin/macosX64/debugShared/libzeta_sdk.dylib`   | `runtimes/osx-x64/native/`       |
| Linux x64     | `build/bin/linuxX64/debugShared/libzeta_sdk.so`      | `runtimes/linux-x64/native/`     |
| Windows x64   | `build/bin/mingwX64/debugShared/zeta_sdk.dll`        | `runtimes/win-x64/native/`       |

Danach ist der passende `<Content>` Eintrag in
`ZetaSdk.csproj` einzufügen (aus dem Kommentar herauszunehmen), so dass die Bibliothek
im Build Output und im NuGet Package enthalten ist.

```xml
<ItemGroup>
  <!-- Uncomment the block for your target platform -->

  <!--

  <Content Include="runtimes/osx-arm64/native/libzeta_sdk.dylib">
    <PackagePath>runtimes/osx-arm64/native/libzeta_sdk.dylib</PackagePath>
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </Content>

  <Content Include="runtimes/osx-x64/native/libzeta_sdk.dylib">
    <PackagePath>runtimes/osx-x64/native/libzeta_sdk.dylib</PackagePath>
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </Content>

  <Content Include="runtimes/linux-x64/native/libzeta_sdk.so">
    <PackagePath>runtimes/linux-x64/native/libzeta_sdk.so</PackagePath>
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </Content>

  <Content Include="runtimes/win-x64/native/zeta_sdk.dll">
    <PackagePath>runtimes/win-x64/native/zeta_sdk.dll</PackagePath>
    <CopyToOutputDirectory>PreserveNewest</CopyToOutputDirectory>
  </Content>
  -->
</ItemGroup>
```

##### Paketierung als NuGet

```bash
dotnet pack ZetaSdk.csproj --configuration Release --output ./nupkg
```

##### Lokale Nutzung durch ein anderes Projekt

```bash
dotnet nuget add source ./nupkg --name local-zeta
dotnet add package ZetaSdk.Client
```

The `sample/nuget.config` already points to the local `nupkg/` directory, so
the sample project picks up the package automatically after packing.

Publish to NuGet feed:

```bash
dotnet nuget push nupkg/ZetaSdk.Client.0.5.0.nupkg \
  --source "https://gitlab...." \
  --api-key GITLAB_TOKEN
```

#### Nutzung der API

Konfiguration des SDK:

````
var config = new ZetaClientConfig
{
    Resource       = Env("FACHDIENST_URL"),                     // Fachdienst-URL
    ProductId      = "demo-client",                             // Produkt ID
    ProductVersion = "0.5.0",                                   // Produkt Version
    ClientName     = "sdk-client",                              // Client-Name
    Storage = new ZetaStorageConfig                             // Storage Konfiguration
    {
        AesB64Key = Env("STORAGE_AES_KEY"),                     // Base64-kodierter AES-256 Schlüssel
    },
    Logger   = (level, tag, message) =>                         // Optionaler Log-Provider
        Console.WriteLine($"[{level}] [{tag ?? "Zeta"}] {message}"),
    LogLevel = ZetaLogLevel.Info,                               // Log-Level — Standard ist Error
    Auth = new ZetaAuthConfig                                   // Authentication Konfiguration
    {
        Scopes = ["zero:audience"],                             // scopes
                                                                // ist das eine Produktionsumgebung?
        AslProdEnvironment = string.Equals(Env("ASL_PROD", "true"), "true"),
        Smb = new ZetaSmbConfig                                 // optionale SM-B Konfiguration
        {
            KeystoreFile = Env("SMB_KEYSTORE_FILE"),
            Alias        = Env("SMB_KEYSTORE_ALIAS"),
            Password     = Env("SMB_KEYSTORE_PASSWORD")
        },
                                                                // optionale SMC-B Konfiguration
        Smcb = string.IsNullOrEmpty(Environment.GetEnvironmentVariable("SMCB_BASE_URL")) ? null
            : new ZetaSmcbConfig
            {                                                   // Konnektor-Parameter
                BaseUrl        = Env("SMCB_BASE_URL"),
                MandantId      = Env("SMCB_MANDANT_ID"),
                ClientSystemId = Env("SMCB_CLIENT_SYSTEM_ID"),
                WorkspaceId    = Env("SMCB_WORKSPACE_ID"),
                UserId         = Env("SMCB_USER_ID"),
                CardHandle     = Env("SMCB_CARD_HANDLE")
            }
    }
};
````

Erstellung des ZetaSdkClients:
````
    using var client = ZetaClient.Build(config, disableTls);
````

Erstellung des ZetaHttpClient: hier gibt es zwei Möglichkeiten - einmal eine Version mit synchronen Aufrufen,
sowie eine Variante mit asynchronen Aufrufen.

````
using var http = client.CreateHttpClient();

using var httpAsync = client.CreateHttpClientAsync();
````

Aufruf einer Resource, hier in der asynchronen Variante:
````
var getResp = await http.GetAsync("hellozeta", headers);
````

Als Rückgabewert gibt es ein `ZetaHttpResponse` Objekt (siehe ZetaHttpClient.cs Datei).

Eine Beispielimplementerung ist hier im [gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-csharp/sample/)


