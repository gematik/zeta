# Wie Sie das ZETA SDK integrieren


Diese Anleitung unterstützt Entwickler dabei, das ZETA-SDK zu bauen und in eigene Produkte zu integrieren.

Für mehr Details über die verschiedenen Komponenten des SKDs siehe auch die [Struktur des SDK Repositories](../Referenzen/SDK-Übersicht.md).

---

Status: Grob-Entwurf

Zielgruppe: Entwickler

---

[TOC]

## Überblick

Das ZETA-SDK besteht aus einer Reihe von Modulen, die in [Struktur des SDK Repositories](../Referenzen/SDK-Übersicht.md) beschrieben sind.
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

    fun sdk_halloZetaTest() = runTest {
        // Arrange
        val sdk = ZetaSdk.build(
            "https://<fachdienst-fqdn>/",
            BuildConfig(
                StorageConfig(),
                object : TpmConfig {},
                AuthConfig(listOf(""), "", "", 0),
            ),
        )

        val client = sdk.httpClient()

        val helloResult = client.get("hellozeta")
            .bodyAsText()
    }
}
`````

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
Das in der build() Methode angegebene Config Objekt enthält auch die notwendigen Informationen über die Callbacks.

| Callback            | Called when                                                                                                                                                       | expected return value |
|---------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------|
| registration_cb()   | wenn während register(), authenticate(), or späterer HTTP Methoden eine Client-Registrierung erforderlich ist, und die nötigen Informationen nicht vorhanden sind | A reginfo object      |
| authentication_cb() | wenn während authenticate(), oder dem späteren Aufruf von HTTP Methoden Authentifizierungsinformationennötig sind.                                                | An authinfo object    |
| auth_config         | Konfiguration des Authentication Prozesses, wie Token scopes, Expiry etc.                                                                                         |
| client_config       | Client-Konfigurationsparameter spezifisch für die Installation, wie Verzeichnisse um Dokumente zu speicher o.ä.                                                   |
| http_config         | Konfigurationsparameter für den HTTP Client wie timeouts, retries etc.                                                                                            |

Hinweis: in Implementierungsstufe 1 werden aktuell keine Callbacks erwartet. In Implementierungsstufe 2 können hier Anfragen
zum Beispiel zum Pushed-Authentication-Request an den IDP hinzukommen.

### Reginfo

Reginfo wird vom registration callback registration_cb() zurückgegeben.

| attribute   | value description                                                                        |
|-------------|------------------------------------------------------------------------------------------|
| client_name | name of the client; according to registration-request.yaml chosen by user or application |

### Authinfo

Authinfo wird vom authentication callback authentication_cb() zurückgegeben.

Hinweis: die Details hier sind noch zu klären, da in Stufe 1 nur SM(C)-B Authentifizierung stattfindet.

Für mobile Anwendungen ist hier die OAuth Authentication mit Pushed Authentication Request zu betrachten.
Hier ist u.a. zu klären, wie authcode, oder IDP URL übertragen werden (wenn sie nicht aus dem aufrufenden Client kommen)

### auth_config

Mit dieses Objekt wird die Authentifizierung parameterisiert.

| Attribut          | Beschreibung                                                                            |
|-------------------|-----------------------------------------------------------------------------------------|
| scopes            | Scope-Werte für die Erstellung des Access Tokens                                        |
| connector_address | Adresse des Konnektors für den Aufruf der Signatur-Schnittstelle für SM(C)-B Signaturen |


### client_config

Mit diesem Objekt wird der Client an sich konfiguriert. Hierzu werden z.B. Speicherverzeichnisse, Konnektor-Adressen o.ä. an den Client gegeben.

| Attribut       | Beschreibung                                                                                 |
|----------------|----------------------------------------------------------------------------------------------|
| storage_config | Konfiguration für das Storage Modul - abhängig von der gewählten Implementierung des Storage |
| tpm_config     | Konfiguration des TPM Module - abhängig von der gewählten Implementierung des TPM-Modules    |


### http_config

Mit diesem Objekt wird das HTTP Protokoll parametrisiert.


