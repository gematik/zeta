# Wie Sie das ZETA-SDK integrieren

Diese Anleitung unterstützt Entwickler dabei, das ZETA-SDK zu bauen und in eigene Produkte zu integrieren.

Für mehr Details über die verschiedenen Komponenten des SDKs siehe auch die [Struktur des SDK-Repositorys](../Referenzen/SDK-Uebersicht.md).

---

Status: Entwurf

Zielgruppe: Entwickler

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Weitere SDK-Module (Vorschau)](#weitere-sdk-module-vorschau)
- [API-Konzept](#api-konzept)
  - [Benötigte Parameter](#benötigte-parameter)
  - [Wiederverwendung existierender Funktionalität](#wiederverwendung-existierender-funktionalität)
- [API-Übersicht](#api-übersicht)
  - [ZetaSdkClient API](#zetasdkclient-api)
  - [Konfiguration für das Erzeugen eines ZetaSdkClient](#konfiguration-für-das-erzeugen-eines-zetasdkclient)
  - [StorageConfig](#storageconfig)
  - [AuthConfig](#authconfig)
  - [ZetaHttpClientBuilder](#zetahttpclientbuilder)
- [Build-Plattformen](#build-plattformen)
  - [Kotlin](#kotlin)
  - [Java](#java)
  - [C++](#c-1)
  - [C#](#c-2)

## Überblick

Das ZETA-SDK besteht aus einer Reihe von Modulen, die in [Struktur des SDK-Repositorys](../Referenzen/SDK-Uebersicht.md) beschrieben sind.
Einstiegspunkt ist die Klasse *ZetaSdk*. Sie bietet ein Builder-Interface, über das Sie das ZETA-SDK konfigurieren.

Der Build-Konfiguration geben Sie auch die Resource mit, also die URL des
Resource Servers. Nach dem `build()`-Aufruf steht eine SDK-Instanz für genau
diese Resource bereit. So lassen sich mehrere Instanzen parallel für mehrere
Fachdienste betreiben.

## Weitere SDK-Module (Vorschau)

Über den hier beschriebenen Kern-Flow hinaus enthält das SDK zwei Module im
Vorschau-Status: Das Notifications-Modul verwaltet Push-Registrierungen und
Benachrichtigungskanäle beim Notification Service des Guards, siehe
[Wie Sie das SDK-Notifications-Modul verwenden](Wie_Sie_das_SDK_Notifications-Modul_verwenden.md).
Für mobile Clients unterstützt das SDK zudem die interaktive Anmeldung über
einen sektoralen IDP inklusive E-Mail-Bindung, siehe
[Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen](Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).

## API-Konzept

Dieser Abschnitt gibt einen Überblick über die Nutzung der API; Details stehen
im Quellcode.

Die beschriebene API gibt es in analoger Form in allen Sprachen.
Wo es Abweichungen gibt, wird darauf eingegangen.

### Benötigte Parameter

Für den Aufruf eines Fachdienstes braucht die API laut Spezifikation mehrere Parameter. Sie stammen teils aus der Registrierung des Clients, teils aus der Spezifikation des Fachdienstes.

#### Client-Registrierung

Ein ZETA-konformer Client muss bei der gematik registriert werden, bevor er einen Fachdienst über einen
ZETA-Guard aufrufen darf. Die registrierten Informationen werden in die OPA-Regeln eingetragen,
mit denen der ZETA-Guard den Aufruf prüft.

| Parameter      | Beschreibung                                             | Kommentar                                                                                                              |
|----------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------------------------------|
| productId      | Eine Identifikation des Produkts, das das SDK integriert | Diese ID wird nach A_25337 bei der Registrierung durch die gematik zugewiesen und entspricht dem Format aus A_25338-01 |
| productVersion | Eine vom Hersteller vergebene Versionsnummer             | Dieser Parameter muss dem Format aus A_25338-01 entsprechen                                                            |

Weitere Parameter, die insbesondere Hash-Werte der tatsächlich installierten Dateien für die spezifische Produkt-Version
enthalten, werden in einem späteren Update der Spezifikation zur Hardware-Attestierung hinzukommen.

#### Fachdienst-Spezifikation

| Parameter       | Beschreibung                                                          | Kommentar                                                                                                                                                                                                                                                                                                                               |
|-----------------|-----------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| scopes          | Eine Liste von Scopes, die für den jeweiligen Aufruf benötigt werden. | Diese Liste wird durch die Spezifikation des aufgerufenen Fachdienstes festgelegt. Für den Aufruf des VSDM ist z. B. in A_26744 festgelegt, dass der Scope `vsdservice` zu nutzen ist.                                                                                                                                                  |
| fachdienstUrl   | Die Basisadresse des aufzurufenden Fachdienstes                       | Dies wird durch die Fachdienst-Spezifikation vorgegeben. Für VSDM ist sie in gemSpec_VSDM, Kapitel 4.3.1, definiert                                                                                                                                                                                                                     |
| requiredRoleOid | Die im ASL-Zertifikat erwartete OID                                   | Das ASL-Zertifikat weist sich damit in der entsprechenden Rolle nach gemSpec_OID aus. Für Fachdienste, die ASL mit dem ZETA-Guard terminieren, ist diese OID `oid_zeta-guard`. In anderen Fachdiensten, bei denen der ZETA-Guard das ASL-Protokoll nur durchleitet (potenziell z. B. E-Rezept oder ePA), kommen andere OIDs zum Tragen. |

> **Hinweis (Abstimmung mit dem Authserver):** Der hier angefragte `scope` muss auf der
> Authserver-Seite der Name des Audience-Scopes sein, denn an diesem Scope hängen die Mapper,
> die die vom PEP geforderten Token-Claims setzen (`aud`, `profession_oid`, `client_id`,
> `ip_address`, `product_id`, `product_version`, `common_name`, `organization_name`). Fragt
> der Client z. B. `vsdservice` an (A_26744), muss der Betreiber die Terraform-Variable
> `audience_scope_name = "vsdservice"` setzen (siehe
> [Wie Sie ZETA-Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)).
> Anderenfalls enthält das Access-Token diese Claims nicht und der PEP lehnt die Anfrage vor der
> Policy-Auswertung ab. Die generischen Code-Beispiele unten verwenden den Standard-Scope
> `zero:audience`.

#### Installationsspezifische Parameter

Weitere Parameter werden bei der konkreten Installation festgelegt.

| Parameter          | Beschreibung                                                       | Kommentar                                                                                                                                                                                                                                                   |
|--------------------|--------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| clientName         | Der Name der spezifischen Client-Installation                      | Diese wird im Rahmen der Client-Registrierung mit den Daten nach dem `client-statement.yaml`-Schema [gematik github](https://github.com/gematik/zeta/blob/main/src/schemas/client-statement.yaml) an den ZETA-Guard übertragen                              |
| aslProdEnvironment | Unterscheidung zwischen Produktions- und Nicht-Produktionssystemen | Nach A_24628-01 (aus gemSpec_Krypt) wird das ASL-Protokoll unterschiedlich verarbeitet, um die Fehlersuche in Nicht-Produktionssystemen zu erleichtern. ZETA-Guard hat eine analoge Konfiguration, die für eine erfolgreiche Verbindung übereinstimmen muss |
| exp                | Gültigkeitsdauer (in Sekunden) des Client-Assertion-JWT            | Dies definiert die Gültigkeitsdauer des Client-Assertion-JWT                                                                                                                                                                                                |
| platformProductId  | Informationen über die Client-Plattform für die Attestierung       | Übergabe z. B. des Betriebssystemtyps oder der Store-IDs, wie sie für die Attestierung des Clients verwendet werden. Siehe z. B. [gematik Repository](https://github.com/gematik/zeta/blob/main/src/schemas/posture-software.yaml)                          |

Weitere Parameter kommen über die Einbindung existierender Primärsystemfunktionalitäten hinzu, wie z. B. Konnektorzugriffe.

#### Netzwerkkonfiguration

Bei der Nutzung der API können dem HTTP-Client innerhalb des SDK verschiedene Netzwerkparameter mitgegeben werden. Hierbei werden bestimmte Defaults genutzt, falls diese Parameter nicht angegeben werden. Diese sind in der
Klasse `NetworkConfig` definiert.

| Parameter            | Beschreibung                                                                                         | Kommentar                                |
|----------------------|------------------------------------------------------------------------------------------------------|------------------------------------------|
| connect timeout      | Timeout in ms für den Abbruch eines Verbindungsaufbaus                                               | Default ist 15 Sekunden                  |
| request timeout      | Timeout für das Warten auf die Antwort für einen Request                                             | Default ist 30 Sekunden                  |
| socket timeout       | Timeout für das Lesen von Daten auf einem Socket                                                     | Default ist 60 Sekunden                  |
| retry Statuscodes    | HTTP-Statuscodes, für die ein Retry durchgeführt wird                                                | Default ist keiner (damit keine Retries) |
| max retries          | Maximale Anzahl der Retries                                                                          | Default ist 0                            |
| only idempotent      | Nur idempotente Aufrufe (GET, HEAD, ...) werden wiederholt, wenn true                                | Default ist true                         |
| Custom CAs           | CA-PEMs können dem Client mitgegeben werden, um eigene Zertifikate zu erlauben                       | Default ist keins                        |
| Log-Level und Logger | Der Log-Level für die Requests                                                                       | Default ist INFO auf dem Default-Logger  |
| proxy Config         | Konfiguration eines Proxys für Netzwerkzugriffe, d. h. Typ (HTTP vs. SOCKS), Host, Port, Credentials | Default ist kein Proxy                   |

### Wiederverwendung existierender Funktionalität

Um Doppelimplementierungen im Primärsystem zu vermeiden, setzt die API auf Dependency Injection. So reicht der Client dem SDK etwa den sicheren Speicher, das Logging oder den Zugriff auf den Konnektor durch.

#### Storage

Mit diesem Objekt konfigurieren Sie den Speicher. Standardmäßig dient eine
einfache Dateiablage; die Daten verschlüsselt das SDK dabei mit dem AES-Schlüssel
aus der Konfiguration.

Wollen Sie bestehende Funktionalität wiederverwenden, leiten Sie von der Klasse SdkStorage ab und überschreiben die Methoden
`put()`, `get()`, `remove()` und `clear()`.

Bei einer eigenen Implementierung verantwortet das Primärsystem die Verschlüsselung; `aesB64Key` bleibt dann unbeachtet. Alle übergebenen Pointer müssen die gesamte Laufzeit
der SDK-Instanz über gültig bleiben.

Das Storage-Interface umfasst folgende Methoden:

| Methode           | Beschreibung                                   |
|-------------------|------------------------------------------------|
| `put(key, value)` | Wert unter dem angegebenen Schlüssel speichern |
| `get(key)`        | Wert für den angegebenen Schlüssel lesen       |
| `remove(key)`     | Eintrag für den angegebenen Schlüssel löschen  |
| `clear()`         | Alle gespeicherten Einträge löschen            |

#### Logging

Das Logging wird an zwei Stellen konfiguriert. Zum einen bei der Konfiguration des SDK sowie beim Erzeugen eines
Clients für einen bestimmten Request. Dies dient im Wesentlichen dazu, dass „Hintergrund“-Aufrufe des SDK wie die zur
Client-Registrierung oder Authentifizierung einen anderen Log-Level haben können als fachliche Aufrufe des Resource Servers.

Standardmäßig schreibt das SDK seine Log-Ausgaben nach stdout. Über einen eigenen Log-Provider leiten Sie sie an das Logging-System des Primärsystems weiter. Das SDK ruft den Callback synchron aus internen Threads auf; Implementierungen müssen daher thread-safe sein. Sobald ein eigener Logger gesetzt ist, entfällt die stdout-Ausgabe.

Der Standard-Log-Level ist `ERROR`. Folgende Log-Level stehen zur Verfügung:

| Level   | Beschreibung                             |
|---------|------------------------------------------|
| `DEBUG` | Alle Meldungen inkl. ausführlichem Debug |
| `INFO`  | Informationsmeldungen und höher          |
| `WARN`  | Warnungen und Fehler                     |
| `ERROR` | Nur Fehlermeldungen (Standard)           |
| `NONE`  | Keine Log-Ausgabe                        |

Das Log-Provider-Interface umfasst folgende Methoden:

| Methode                      | Beschreibung           |
|------------------------------|------------------------|
| `d(tag, message, throwable)` | DEBUG-Meldung ausgeben |
| `i(tag, message, throwable)` | INFO-Meldung ausgeben  |
| `w(tag, message, throwable)` | WARN-Meldung ausgeben  |
| `e(tag, message, throwable)` | ERROR-Meldung ausgeben |

#### Konnektor-Zugriff

Zur Erstellung eines SubjectTokens wird der Zugriff auf den Konnektor benötigt. Dies wird in der Regel
in einem Primärsystem bereits umgesetzt sein. Daher nutzt die API die Möglichkeit, den Zugriff auf den Konnektor
an den Client, d. h. das Primärsystem an sich, auszulagern.

Dazu implementieren Sie die Konnektor-API. In C++/C# konfigurieren Sie sie
direkt; in der Kotlin-/Java-Variante kapselt ein CustomSmbcTokenProvider die
API, und diesen übernehmen Sie dann in die Konfiguration.

Hinweis: Die Kotlin-/Java-Implementierungen liefern mit SbmcTokenProvider und SmbTokenProvider zwei Implementierungen des `SubjectTokenProvider` mit, die die beiden nötigen Konnektor-Aufrufe kapseln.
Sie rufen eine eigene Konnektor-API auf, die allerdings nur für Testzwecke gedacht ist und beispielsweise kein mTLS für die Authentifizierung
an einem echten Konnektor umsetzt. Nutzen Sie in Kotlin/Java daher den CustomSmcbTokenProvider mit Ihrer eigenen
Konnektor-Anbindung.
Für Tests eignen sich SbmcTokenProvider und SmbTokenProvider; sie brauchen dafür unterschiedliche Konfigurationsparameter.
Der SmbTokenProvider erwartet den Dateipfad der Zertifikatsdatei samt Alias und Passwort, der SmcbTokenProvider
die Adresse des Konnektors und weitere Aufrufparameter wie Mandant, Handle usw.

Der CustomSmcbTokenProvider soll genutzt werden, um eine eigene Implementierung anzubinden. Er erwartet eine ConnectorAPI als
Parameter, der nur die beiden Konnektor-Aufrufe abbildet. Die Instanz muss dabei die Aufrufparameter selbst verwalten.

Bei Nutzung eines eigenen Connectors werden die SMC-B-SOAP-Felder (`baseUrl`, `mandantId` etc.) ignoriert.
Beide Callbacks müssen genau einmal pro Aufruf aufgerufen werden, auch im Fehlerfall (dann mit size=0).

Das Connector-Interface umfasst folgende Methoden:

#### Kotlin / Java / C#

| Methode                                                    | Beschreibung                                                                        |
|------------------------------------------------------------|-------------------------------------------------------------------------------------|
| `readCertificate(): ByteArray`                             | SMC-B-X.509-Zertifikat im DER-Format zurückgeben                                    |
| `externalAuthenticate(base64Challenge: String): ByteArray` | Base64-kodierte Challenge signieren und die DER-kodierte ECDSA-Signatur zurückgeben |

#### C++

| Methode                                                 | Beschreibung                                                                                                                                        |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| `readCertificate(ctx, cb, cbCtx)`                       | SMC-B-X.509-Zertifikat im DER-Format an das SDK zurückgeben. `cb` muss genau einmal mit dem Ergebnis aufgerufen werden, auch im Fehlerfall (size=0) |
| `externalAuthenticate(ctx, base64Challenge, cb, cbCtx)` | Base64-kodierte Challenge signieren und die DER-kodierte ECDSA-Signatur zurückgeben. `cb` muss genau einmal aufgerufen werden, auch im Fehlerfall   |

`ctx` ist der opake Kontext-Pointer aus der VTable, der unverändert weitergegeben wird. `cbCtx` ist der opake Kontext-Pointer, der unverändert an den Callback weitergegeben werden muss.

#### TPM-Zugriff

Dieses Objekt ist aktuell noch nicht genutzt. Es wird in einer Weiterentwicklung der Spezifikation ermöglichen,
den Zugriff auf das Hardware-TPM an das Primärsystem auszulagern.

## API-Übersicht

Die Nutzung der API besteht aus drei Schritten:

1. Je Fachdienst-Basis-URL erzeugen Sie mit `ZetaSdk.build()` ein
`ZetaSdkClient`-Objekt und übergeben dabei die Konfiguration — also den Großteil der oben beschriebenen Parameter. An diesem Client fragen Sie den Verbindungsstatus ab (inkl. Client-Registrierung) und verändern ihn bei Bedarf.
2. Am ZetaSdkClient erzeugen Sie einen `ZetaHttpClient` und geben ihm die nötige Netzwerkkonfiguration mit. Hier setzen Sie auch den Logger für fachliche
   Requests.
3. Über diesen HTTP-Client rufen Sie schließlich den Fachdienst auf.

Hinweis: Wegen der Technologieunterschiede weichen die Aufrufe je Implementierungssprache voneinander ab.
Insbesondere können Helper-Klassen dazwischenliegen, die ZetaSdkClient bzw. ZetaHttpClient indirekt aufrufen.
Beispiele je Sprache finden Sie in den jeweiligen Testclients; sie sind unten verlinkt.

### ZetaSdkClient API

Das `ZetaSdk` ist die Builder-Klasse, mit der ein `ZetaSdkClient` erstellt werden kann.

#### ZetaSdk

| Operation | Beschreibung                                                                                                                                                                                                                                                   | Return value         | Errors |
|-----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|--------|
| build()   | Statische Methode, um einen neuen SDK-Client zu erstellen. Die Resource-URL des Endpunkts wird hierbei als Input gegeben. D. h. für jeden Fachdienst kann ein separater Client erzeugt werden. Weitere Parameter sind z. B. notwendige Callback-Informationen. | ZetaSDKClient Object |        |

#### ZetaSdkClient

Der `ZetaSdkClient` ist ein Objekt, das für den Zugriff auf einen bestimmten Fachdienst vorkonfiguriert ist (nach dem Bauen durch `ZetaSdk`).

| Operation           | Beschreibung                                                                                                                                                                                                       | Return value                | Errors                                                                                                                                                                                     |
|---------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| forget()            | Statische Methode, um alle Informationen zu einem FQDN zu vergessen, wie Client-ID, Client-Instance-Key usw.                                                                                                       | -                           | error codes                                                                                                                                                                                |
| -                   |                                                                                                                                                                                                                    |                             |                                                                                                                                                                                            |
| discover()          | Umsetzen der Discovery und Configuration. Dieser Call ist optional und wird ggf. automatisch nachgeholt                                                                                                            | -                           | Fehler bei der Discovery und Configuration, insb. wenn für die Resource URL keine gültige Endpunkt-Konfiguration (im Sinne eines Eintrags in einer OPR-`.well-known`-Datei) gefunden wurde |
| register()          | Ausführen der Client-Registrierung, wenn nötig (keine client_id vorhanden). Inkludiert `discover()`, falls dieses noch nicht ausgeführt wurde.                                                                     | -                           | error codes                                                                                                                                                                                |
| authenticate()      | Ausführen der Authentifizierung, falls nötig (kein AccessToken vorhanden). Falls ein gültiges Refresh-Token vorhanden ist, wird dieses genutzt. Inkludiert `register()`, falls dieses noch nicht ausgeführt wurde. | -                           | error codes                                                                                                                                                                                |
| httpClient()        | Gibt einen HTTP-Client zurück, dessen Operationen überschrieben werden, um die notwendigen ZETA-spezifischen Protokolle umzusetzen                                                                                 | Ein `ZetaHttpClient`-Objekt |                                                                                                                                                                                            |
| ws()                | Eröffnet eine WebSocket-Session                                                                                                                                                                                    |                             |                                                                                                                                                                                            |
| status()            | Gibt den Status des SdkClients zurück, also ob eine Client-Registrierung vorliegt, ein AccessToken vorliegt usw.                                                                                                   | Ein `SdkStatus`-Objekt      | -                                                                                                                                                                                          |
| logout()            | Ausloggen aus dem Fachdienst, sodass ein neues Access-Token benötigt wird                                                                                                                                          | -                           | error codes                                                                                                                                                                                |
| clearRegistration() | Löscht Client-Registrierung, Tokens und ASL-Session, behält jedoch den Instance-Key.                                                                                                                               | -                           |                                                                                                                                                                                            |
| close()             | Schließen des ZetaSDKClients, ohne relevante Inhalte zu vergessen                                                                                                                                                  | -                           | error codes                                                                                                                                                                                |

Die verschiedenen Stufen des ZETA-Protokolls (`discover()`, `register()`, `authenticate()`) werden bei Erstellung des HttpClient bzw. Aufruf einer Resource _automatisch_ ausgeführt.
Zusammen mit der `status()`-Methode dienen sie nur der feingranularen Kontrolle durch das Primärsystem, soweit gewünscht.

Hinweis: Was `forget()` und `clearRegistration()` serverseitig bewirken und wie
sie sich in den Lebenszyklus eines Clients einordnen, beschreibt
[Wie der Client-Lebenszyklus verwaltet wird](Wie_der_Client-Lebenszyklus_verwaltet_wird.md).

Hinweis: Ändert sich der Instanzschlüssel des Clients (Schlüsselrotation),
erkennt das SDK dies anhand der bei der Registrierung hinterlegten
Schlüssel-ID und führt automatisch eine erneute Client-Registrierung durch.
Details siehe
[Wie die dynamische Client-Registrierung funktioniert](Wie_die_dynamische_Client-Registrierung_funktioniert.md).

### Konfiguration für das Erzeugen eines ZetaSdkClient

Statische Informationen für die einzelnen Schritte liegen im Storage-Modul zwischengespeichert.
Fehlen sie, fragt das SDK sie über Callbacks ab.
Das `BuildConfig`-Objekt, das Sie an `build()` übergeben, beschreibt auch diese Callbacks.

| Callback            | Called when                                                                                                                                                                                                      | expected return value |
|---------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------|
| productId           | Die gematik-Produkt-ID                                                                                                                                                                                           |                       |
| productVersion      | die Produktversion                                                                                                                                                                                               |                       |
| clientName          | der Name des Clients                                                                                                                                                                                             |                       |
| storageConfig       | Storage provider, der zum Speichern von Daten verwendet wird.                                                                                                                                                    |                       |
| tpmConfig           | Wird in Stufe 2 die Konfiguration des Hardware-TPM enthalten                                                                                                                                                     |                       |
| authConfig          | Konfiguration des Authentifizierungsprozesses, wie Token-Scopes, Expiry etc. oder auch das ASL-Tracing-Flag                                                                                                      |                       |
| platformProductId   | Plattform-Informationen wie Typ des Betriebssystems, Store-IDs der Anwendung für die Software-Attestierung (siehe [gematik GitHub](https://github.com/gematik/zeta/blob/main/src/schemas/posture-software.yaml)) |                       |
| httpClientBuilder   | Builder für HttpClients; wird für die Aufrufe der PDP-APIs verwendet                                                                                                                                             |                       |
| registration_cb()   | wenn während register(), authenticate() oder späterer HTTP-Methoden eine Client-Registrierung erforderlich ist und die nötigen Informationen nicht vorhanden sind                                                | A reginfo object      |
| authentication_cb() | wenn während authenticate() oder dem späteren Aufruf von HTTP-Methoden Authentifizierungsinformationen nötig sind.                                                                                               | An authinfo object    |
| logger              | Eigener Log-Provider zur Weiterleitung der SDK-Logs an das Logging-System des Primärsystems                                                                                                                      |                       |

Hinweis: In Implementierungsstufe 1 werden aktuell keine Callbacks genutzt. In
Implementierungsstufe 2 können hier Anfragen zum Beispiel zum
Pushed-Authentication-Request an den IDP hinzukommen.

### StorageConfig

Mit diesem Objekt wird der Speicher konfiguriert. Es gibt zwei Varianten:

| Variante  | Beschreibung                                                                                                    |
|-----------|-----------------------------------------------------------------------------------------------------------------|
| `Default` | Verschlüsselter Standard-Speicher mit einem AES-256-Schlüssel (`aesB64Key`) und optionalem Dateipfad            |
| `Custom`  | Eigene Implementierung des `SdkStorage`-Interface. Verschlüsselung liegt in der Verantwortung des Primärsystems |

**Hinweis:** Das `zeta_route`-Cookie wird automatisch über `SdkStorage` persistiert und bei `logout()`, `forget()` und `clearRegistration()` gelöscht. Eine zusätzliche Konfiguration ist nicht erforderlich.

Falls kein Provider angegeben wird, wird ein verschlüsselter Standard-Speicher verwendet, der mit dem angegebenen
AES-Schlüssel verschlüsselt wird. Details siehe dazu die README im Quellcode des Storage-Moduls bzw. im Umsetzungskonzept.

### AuthConfig

Mit diesem Objekt parametrisieren Sie die Authentifizierung.

| Attribut             | Beschreibung                                                                                                                                                               |
|----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| scopes               | Scope-Werte für die Erstellung des Access-Tokens                                                                                                                           |
| exp                  | Gültigkeitsdauer des Subject-Tokens. Der PDP akzeptiert nur maximal 30 Sekunden                                                                                            |
| aslProdEnvironment   | wenn false, werden die ASL-Schlüssel (für Testzwecke) als Header im äußeren ASL-Request mitgegeben (A_24628-01)                                                            |
| subjectTokenProvider | Objekt, mit dem ein Subject-Token erzeugt werden kann. Es werden aktuell zwei Implementierungen bereitgestellt, einmal für SM-B Dateien und einmal für SMC-B via Konnektor |
| attestation          | Konfiguriert den Attestierungsmodus und die Verbindung zum Attestierungsservice. Default: `AttestationConfig.software()`                                                   |
| requiredRoleOid      | Die OID, die im TI-Zertifikat des ASL-Servers vorhanden sein muss. Wird beim ASL-Handshake validiert. Z. B. `1.2.276.0.76.4.324` für `oid_zeta-guard` (gemSpec_OID)        |

### ZetaHttpClientBuilder

Mit diesem Objekt parametrisieren Sie das HTTP-Protokoll, unter anderem Retries
und Connection-Timeouts.

Das hier übergebene Objekt gilt für die PDP-Aufrufe, die im Hintergrund laufen, sobald eine Resource über den ZETA-Guard angefragt wird. Für die Aufrufe der Resource über den PEP erzeugen Sie mit `httpClient()` einen eigenen HTTP-Client, der eine eigene Konfiguration erhalten kann.

## Build-Plattformen

### Kotlin

Im Folgenden ist das Beispiel eines Aufrufs einer Resource am Fachdienst in Kotlin dargestellt.

Die Konfigurationen sind umfangreicher als hier dargestellt und lassen sich in
der API-Dokumentation weiter unten bzw. besser in der IDE anschauen.

`````
        // statischer Aufruf um einen ZetaSdkClient zu erzeugen
        val sdk = ZetaSdk.build(
            "https://<resource-url>",                       // Basis-URL des Fachdienstes
            BuildConfig(                                    // BuildConfig Objekt mit der ganzen Konfiguration
                "demo-client",                              // Produkt ID
                "1.2.0",                                    // Produkt Version
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

Dann kann das ZETA-SDK als Maven-Abhängigkeit eingebunden und wie folgt genutzt
werden. Dazu wird die folgende Maven-Abhängigkeit in die `pom.xml` aufgenommen
(mit der jeweils relevanten Version):
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

Dann kann das ZETA-SDK als Maven-Abhängigkeit eingebunden und wie folgt genutzt
werden. Dazu wird die folgende Maven-Abhängigkeit in die `pom.xml` aufgenommen
(mit der jeweils relevanten Version):

````
<!-- https://mvnrepository.com/artifact/de.gematik.zeta/zeta-sdk-jvm -->
<dependency>
  <groupId>de.gematik.zeta</groupId>
  <artifactId>zeta-sdk-jvm</artifactId>
  <version>x.y.z</version>
</dependency>
````

#### API-Aufruf

Hier ist der API-Aufruf:
````
        // Erstellen der SDK Instanz
        ZetaSdkClient sdkClient = ZetaSdk.INSTANCE.build(
            getFirstResourceUrl(props),                                 // Fachdienst-URL, hier aus einer Konfigurationsdatei gelesen
            new BuildConfig(                                            // BuildConfig Objekt
                "ZETA-Test-Client",                                     // Produkt ID
                "1.2.0",                                                // Produkt Version
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
                new ZetaHttpClientBuilder().disableServerValidation(disableServerValidation).logging(LogLevel.ALL),
                null,                                                   // ungenutzt - registration Callback für Stufe 2
                null,                                                   // ungenutzt - authentication Callback für Stufe 2
                null                                                    // optional - eigener Log-Provider
            ));

        // Erstellen eines ZetaHttpClients
        // Als Parameter wird ein ZetaHttpClientBuilder erwartet
        httpClient = sdkClient.httpClient(it -> {
            it.logging(LogLevel.ALL);
            it.disableServerValidation(disableServerValidation);
            return Unit.INSTANCE;
        });
````

Für die eigentlichen Aufrufe können die Methoden am `ZetaHttpClient` direkt verwendet werden.
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

#### Schritt 1 — SDK-Shared-Library bauen
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

Die API ist hier aufwändiger zu nutzen, weil Sie die Objekte „manuell“ erzeugen müssen.

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

    ZetaSdk_SecurityConfig security = {};
    security.additionalCaPem = const_cast<char**>(caPem);
    security.additionalCaPemCount = 1;
    //security.additionalCaFile = const_cast<char*>(caPemFile);
    //security.disableServerValidation = disableTls;
    //security.sslVerbose = false;

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

    // Proxy-Konfiguration (optional)
    ZetaSdk_ProxyConfig proxyConfig = {
            "127.0.0.1",    // Host
            8080,           // Port
            "user",         // Username, NULL falls nicht benötigt
            "password",     // Password, NULL falls nicht benötigt
            0               // Typ: 0=HTTP, 1=SOCKS
    };

    // Zusammenbau des BuildConfig Objekts
    ZetaSdk_BuildConfig buildConfig = {
            resource,                                       // Basis-URL des Fachdienstes
            const_cast<char*>(PRODUCT_ID),                  // Produkt ID
            const_cast<char*>(PRODUCT_VERSION),             // Produkt Version
            const_cast<char*>(CLIENT_NAME),                 // Client-Name
            &storageConfig, &tpmConfig, &authConfig,        // Konfigurations-Objekte
            &logVTable                                      // Optionaler Log-Provider
            nullptr,                                        // Optionaler Proxy (hier &proxyConfig einsetzen)
            &security                                       // Optionale Sicherheitskonfiguration
    };
                                                            // Erstellen des ZetaSdk Objekts
    ZetaSdk_Client*     zetaSdkClient  = (ZetaSdk_Client*)ZetaSdk_buildZetaClient(&buildConfig);
                                                            // Erstellen des ZetaHttpClient Objekts
    ZetaSdk_HttpClient* zetaHttpClient = (ZetaSdk_HttpClient*)ZetaSdk_buildHttpClient(zetaSdkClient);

````

##### Nutzung einer eigenen Konnektor-Anbindung

Die oben beschriebenen Konfigurationen nutzen die SDK-seitig bereitgestellten Anbindungen an den Konnektor,
um ein SMC-B-Zertifikat zu erstellen. Um eine eigene Implementierung zu nutzen, kann der
Aufruf auf den Konnektor durch eigene Implementierungen wie folgt ersetzt werden:

````
    // Signaturen der Konnektor-Aufrufe mit Beispiel-Implementierungen

    // Lesen des Zertifikats.
    void my_read_certificate(void* ctx, ZetaSdk_BytesCallback cb, void* cbCtx) {
            // Bereitstellung des Zertifikats - muss durch den Aufruf des Konnektors ersetzt werden
            auto derBytes = base64Decode(SMCB_CERTIFICATE_B64);
            // Rückgabe des Zertifikats an das ZETA-SDK
            cb(cbCtx, derBytes.data(), (int)derBytes.size());
    }

    // Aufruf der Authenticate API
    void my_external_authenticate(void* ctx, const char* base64Challenge,
                                        ZetaSdk_BytesCallback cb, void* cbCtx) {
            // Bereitstellung der Signatur - muss durch den Aufruf des Konnektors ersetzt werden
            auto sigBytes = base64Decode(SMCB_SIGNATURE_DER_B64);
            // Rückgabe der Signatur an das ZETA-SDK
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

Um eine eigene Storage-Implementierung zu nutzen, wird in der StorageConfig eine
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

Den Client bedienen statische Helfer-Methoden, denen Sie das jeweilige
`ZetaHttpClient`-Objekt als Parameter übergeben:

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
Dieses nutzt die Gradle-Funktionalität zum Bauen.

Für einen Makefile-basierten Build gibt es den [nativeclient im gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-nativeclient-cpp/).

Der Client findet sich in `zeta-nativeclient-cpp/` und besteht aus:
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

Das Makefile erkennt automatisch das Betriebssystem und nutzt die korrekte SDK-Version:
- **macOS (Apple Silicon)** → `macosArm64/debugShared`
- **Linux** → `linuxX64/debugShared`
- **Windows** → `mingwX64/debugShared`

Falls die Ordnerstruktur davon abweicht, muss die Variable `LIB_DIR` im Makefile entsprechend angepasst werden.

### C#

#### Vorbereitung: Installation .NET 10

Unter macOS lässt sich das so installieren:

```bash
brew update
brew install dotnet
```

Für Linux und Windows sind Downloads unter [https://dotnet.microsoft.com/download](https://dotnet.microsoft.com/download) zu finden.

#### Natives SDK bauen

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
`runtimes/`-Ordner zu kopieren:

| Platform    | Source file                                          | Destination                  |
|-------------|------------------------------------------------------|------------------------------|
| macOS ARM64 | `build/bin/macosArm64/debugShared/libzeta_sdk.dylib` | `runtimes/osx-arm64/native/` |
| macOS x64   | `build/bin/macosX64/debugShared/libzeta_sdk.dylib`   | `runtimes/osx-x64/native/`   |
| Linux x64   | `build/bin/linuxX64/debugShared/libzeta_sdk.so`      | `runtimes/linux-x64/native/` |
| Windows x64 | `build/bin/mingwX64/debugShared/zeta_sdk.dll`        | `runtimes/win-x64/native/`   |

Danach ist der passende `<Content>`-Eintrag in `ZetaSdk.csproj` einzufügen (aus
dem Kommentar herauszunehmen), sodass die Bibliothek im Build-Output und im
NuGet-Paket enthalten ist.

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

Die `sample/nuget.config` verweist bereits auf das lokale Verzeichnis `nupkg/`,
sodass das Beispielprojekt das Paket nach dem Packen automatisch findet.

Veröffentlichen im NuGet-Feed:

```bash
dotnet nuget push nupkg/ZetaSdk.Client.1.2.0.nupkg \
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
    ProductVersion = "1.2.0",                                   // Produkt Version
    ClientName     = "sdk-client",                              // Client-Name
    Storage = new ZetaStorageConfig                             // Storage Konfiguration
    {
        CustomStorage = new InMemoryStorage(),                  // eigene Storage-Implementierung
        AesB64Key = Env("STORAGE_AES_KEY"),                     // Base64-kodierter AES-256 Schlüssel
    },
    Logger   = (level, tag, message) =>                         // Optionaler Log-Provider
        Console.WriteLine($"[{level}] [{tag ?? "Zeta"}] {message}"),
    LogLevel = ZetaLogLevel.Info,                               // Log-Level — Standard ist Error
    /*Proxy = new ZetaProxyConfig
        {
            Host     = "127.0.0.1",                                // Proxy Host
            Port     = 8080,                                       // Proxy Port
            Username = "user",                                     // Username, null falls nicht benötigt
            Password = "password",                                 // Password, null falls nicht benötigt
            Type     = ZetaProxyType.Http                          // Typ: Http oder Socks
        },*/
       Security = new SecurityConfig
       {
          /*AdditionalCaPem = [
                    """
            -----BEGIN CERTIFICATE-----
            ...
            -----END CERTIFICATE-----
            """
                ],*/
          // AdditionalCaFile = "/path/to/ca.crt",
          DisableServerValidation = false,                  // Nur für Tests
          SslVerbose = false,                               // Nur für Debugging
      },
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
        // CustomSmcb = new MyCustomConnector(),              // optionale eigene Konnektor-Anbindung
        RequiredRoleOid = Env("REQUIRED_ROLE_OID"),           // OID die im ASL Zertifikat erwartet wird
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
    using var client = ZetaClient.Build(config);
````

Erstellung des ZetaHttpClient: Hier gibt es zwei Möglichkeiten – eine Version
mit synchronen Aufrufen sowie eine Variante mit asynchronen Aufrufen.

````
using var http = client.CreateHttpClient();

using var httpAsync = client.CreateHttpClientAsync();
````

Aufruf einer Resource, hier in der asynchronen Variante:
````
var getResp = await http.GetAsync("hellozeta", headers);
````

Als Rückgabewert gibt es ein `ZetaHttpResponse`-Objekt (siehe Datei `ZetaHttpClient.cs`).

Eine Beispielimplementierung findet sich im [gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-csharp/sample/).
