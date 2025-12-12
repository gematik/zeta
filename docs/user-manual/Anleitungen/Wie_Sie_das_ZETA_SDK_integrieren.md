# Wie Sie das ZETA SDK integrieren


Diese Anleitung unterstützt Entwickler dabei, das ZETA-SDK zu bauen und in eigene Produkte zu integrieren.

Für mehr Details über die verschiedenen Komponenten des SKDs siehe auch die [Struktur des SDK Repositories](../Referenzen/SDK-Uebersicht.md).

---

Status: Grob-Entwurf

Zielgruppe: Entwickler

---

[TOC]

## Überblick

Das ZETA-SDK besteht aus einer Reihe von Modulen, die in [Struktur des SDK Repositories](../Referenzen/SDK-Uebersicht.md) beschrieben sind.
Der Einstieg in des SDK findet dabei über die Klasse *ZetaSdk* statt. Diese bietet ein Builder-Interface, mit dem das ZETA SDK
konfiguriert werden kann.

In der initialen Build-Konfiguration wird auch die Resource mitgegeben, d.h. die URL des Resource Servers. Nach dem build() Aufruf
steht eine Instanz des ZETA SDK für diese Resource zur Verfügung. Auf diese Weise können mehrere Instanzen des ZETA SDK parallel
für mehrere Fachdienste erstellt werden.

### Client-API

## Build-Plattformen

### kotlin

Im Folgenden ist das Beispiel eines Aufrufs einer Resource am Fachdienst in kotlin dargestellt.

Die Konfigurationen sind umfangreicher als hier dargestellt und lassen sich in der API Dokumentation weiter unten bzw. besser
in der IDE anschauen.

`````
class ZetaSdkTest {
    @Test
    @Ignore
    fun sdk_halloZetaTest() = runTest {
        // Arrange
        val sdk = ZetaSdk.build(
            "https://<resource-url>",
            BuildConfig(
                "demo_client",
                "0.1.0",
                "client-sdk",
                StorageConfig(),
                object : TpmConfig {},
                AuthConfig(
                    listOf(
                        "zero:audience",
                    ),
                    30,
                    true,
                    SmbTokenProvider(SmbTokenProvider.Credentials("", "", "")),
                ),
            ),
        )

        // Act
        val client = sdk.httpClient {
            logging(
                LogLevel.ALL,
                object : Logger {
                    override fun log(message: String) {
                        println("log:" + message)
                    }
                },
            )
        }

        val helloResult = client.get("/hellozeta")
            .bodyAsText()
    }
}
`````

Hierbei wurde darauf geachtet, dass mögliche existierende Funktionalitäten aus den jeweiligen
Client-Implementierungen wiederverwendet werden können, wie z.B. die Bereitstellung
von SM(C)-B Tokens oder eine sichere (verschlüsselte) Ablage von Informationen.

Die genauen Definitionen sind im Quellcode nachzusehen, wo auch der jeweils aktuelle Stand liegt.

## API Übersicht

Dieser Abschnitt gibt einen Überblick über die Nutzung der API.
Weitere Details sind im Source Code nachzusehen.

Hinweis: die hier dargestellte API stellt einen intermediären Zielzustand dar, und kann von der API im Sourcode abweichen,
da bereits API-Features bedacht sind, die im aktuellen Stand des Prototyps noch nicht umgesetzt sind.

## Angebotene API

Die API bietet dem ZETA client die folgenden Operationen an:

| Operation               | Beschreibung                                                                                                                                                                                                                                                 | Return value         | Errors                                                                                                                                                                                   |
|-------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| build(resource, config) | Statische Methode, um einen neuen SDK Client zu erstellen. Die Resource URL des Endpunkts wird hierbei als Input gegeben. D.h. für jeden Fachdienst kann ein separater Client erzeugt werden. Weitere Parameter sind z.B. notwendige Callback-Informationen. | ZetaSDKClient Object |                                                                                                                                                                                          |
| forget(fqdn)            | statische Methode, um alle Informationen zu einem FQDN zu vergessen wie client ID, client instance key, ...                                                                                                                                                  | -                    | error codes                                                                                                                                                                              |
| -                       |                                                                                                                                                                                                                                                              |                      |                                                                                                                                                                                          |
| discover()              | Umsetzen der Discovery und Configuration. Dieser Call ist optional und wird ggf. automatisch nachgeholt                                                                                                                                                      | -                    | Fehler bei der Discovery und Configuration, insb. wenn für die Resource URL keine gültige Endpunkt-Konfiguration (im Sinne eines Eintrags in einer OPR .well-known Datei) gefunden wurde |
| register()              | Ausführen der Client registration, wenn nötig (keine client_id vorhanden). Includiert discover() falls dieses noch nicht ausgeführt wurde.                                                                                                                   | -                    | error codes                                                                                                                                                                              |
| authenticate()          | Ausführen der Authentifizierung falls nötig (kein AccessToken vorhanden). Falls gültiges Refresh Token vorhanden, wird dieses genutzt. Inkludiert register() falls dieses noch nicht ausgeführt wurde.                                                       | -                    | error codes                                                                                                                                                                              |
| httpClient()            | gibt einen HTTP Client zurück, dessen Operationen überschrieben werden um die notwendigen ZETA-spezifischen Protokolle umzusetzen                                                                                                                            |                      |
| close()                 | Schliessen des ZetaSDKclients, ohne relevante Inhalte zu vergessen                                                                                                                                                                                           | -                    | error codes                                                                                                                                                                              |

Innerhalb dieser HTTP Operationen werden die init() und authenticate() Operationen automatisch aufgerufen. Diese sind idempotent und stellen die Configuration, client Registration, sowie Authentication durch.
Die separate Bereitstellung der Methoden erlaubt es dem Client-System, hier flexible Umsetzungen der in den einzelnen Schritten ggf. nötigen Benutzerinteraktionen vorzusehen.

### Konfiguration

Statische Informationen, die für die einzelnen Schritte benötigt werden, werden über das Storage Module zwischengespeichert.
Falls diese Informationen nicht vorhanden sein sollten, werden sie über Callbacks abgefragt.
Das in der build() Methode angegebene BuildConfig Objekt enthält auch die notwendigen Informationen über die Callbacks.

| Callback            | Called when                                                                                                                                                       | expected return value |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------|
| productId           | Die gematik Produkt-ID                                                                                                                                            |
| productVersion      | die Produktversion                                                                                                                                                |
| clientName          | der Name des Client                                                                                                                                               |
| storageConfig       | Storage provider, der zum Speichern von Daten verwendet wird.                                                                                                     |
| tpmConfig           | Wird in Stufe 2 die Konfiguration des Hardware-TPM enthalten                                                                                                      |
| authConfig          | Konfiguration des Authentication Prozesses, wie Token scopes, Expiry etc. oder auch ASL Tracing flag                                                              |
| httpClientConfig    | Builder für HttpClients; wird für die Aufrufe der PDP APIs verwendet                                                                                              |
| registration_cb()   | wenn während register(), authenticate(), or späterer HTTP Methoden eine Client-Registrierung erforderlich ist, und die nötigen Informationen nicht vorhanden sind | A reginfo object      |
| authentication_cb() | wenn während authenticate(), oder dem späteren Aufruf von HTTP Methoden Authentifizierungsinformationennötig sind.                                                | An authinfo object    |

Hinweis: in Implementierungsstufe 1 werden aktuell keine Callbacks erwartet. In Implementierungsstufe 2 können hier Anfragen
zum Beispiel zum Pushed-Authentication-Request an den IDP hinzukommen.

### Reginfo

Reginfo wird vom registration callback registration_cb() zurückgegeben.
Dieses Objekt dient dazu, Benutzerinteraktion während der Client-Registrierung zu steuern.

Es wird in Stufe 2 definiert.

### Authinfo

Authinfo wird vom authentication callback authentication_cb() zurückgegeben.

Hinweis: die Details hier sind noch zu klären, da in Stufe 1 nur SM(C)-B Authentifizierung stattfindet.

Für mobile Anwendungen ist hier die OAuth Authentication mit Pushed Authentication Request zu betrachten.
Hier ist u.a. zu klären, wie authcode, oder IDP URL übertragen werden (wenn sie nicht aus dem aufrufenden Client kommen)

### AuthConfig

Mit dieses Objekt wird die Authentifizierung parameterisiert.

| Attribut               | Beschreibung                                                                                                                                                               |
|------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| scopes                 | Scope-Werte für die Erstellung des Access Tokens                                                                                                                           |
| exp                    | Token expiry                                                                                                                                                               |
| enableAslTracingHeader | wenn true, werden die ASL keys (für Testing) als Header im outer ASL Request mitgegeben                                                                                    |
| subjectTokenProvider   | Objekt, mit dem ein Subject Token erzeugt werden kann. Es werden aktuell zwei Implementierungen bereitgestellt, einmal für SM-B Dateien und einmal für SMC-B via Konnektor |


### StorageConfig

Mit diesem Objekt wird der Speicher konfiguriert.

| Attribut  | Beschreibung                                                                              |
|-----------|-------------------------------------------------------------------------------------------|
| provider  | Das eigentliche Speicherinterface (optional)                                              |
| aesB64Key | Konfiguration des TPM Module - abhängig von der gewählten Implementierung des TPM-Modules |

Falls kein provider angegeben wird, wird ein verschlüsselter Standard-Speicher verwendet, der mit dem angegebenen
AES key verschlüsselt wird. Details siehe dazu das README im Quellcode des storage Modul bzw. im Umsetzungskonzept.

### ZetaHttpClientBuilder

Mit diesem Objekt wird das HTTP Protokoll parametrisiert.
Es enthält Parameter u.a. für retries und Connection Timeouts.

Das hier mitgegebene Objekt wird für die Aufrufe des PDP verwendet, die im Hintergrund stattfinden wenn
über den ZETA-Guard eine Resource aufgerufen werden soll. Für die Aufrufe der Resource via PEP
wird ein HTTP Client via httpClient() instanziiert, der eine eigene HTTP Client Konfiguration erhalten kann.
