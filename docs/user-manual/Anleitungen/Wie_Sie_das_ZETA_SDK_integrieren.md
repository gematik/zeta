# Wie Sie das ZETA-SDK integrieren

Diese Anleitung unterstützt Entwickler dabei, das ZETA-SDK zu bauen und in eigene Produkte zu integrieren.
Sie beschreibt den Stand des ZETA-SDK 2.0.0.

Für mehr Details über die verschiedenen Komponenten des SDKs siehe auch die [Struktur des SDK-Repositorys](../Referenzen/SDK-Uebersicht.md).

---

Status: Entwurf

Zielgruppe: Entwickler

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Änderungen in Version 2.0.0](#änderungen-in-version-200)
- [Weitere SDK-Module (Vorschau)](#weitere-sdk-module-vorschau)
- [API-Konzept](#api-konzept)
  - [Benötigte Parameter](#benötigte-parameter)
  - [Wiederverwendung existierender Funktionalität](#wiederverwendung-existierender-funktionalität)
  - [Attestierung](#attestierung)
- [API-Übersicht](#api-übersicht)
  - [ZetaSdkClient API](#zetasdkclient-api)
  - [Konfiguration für das Erzeugen eines ZetaSdkClient](#konfiguration-für-das-erzeugen-eines-zetasdkclient)
  - [StorageConfig](#storageconfig)
  - [AuthConfig](#authconfig)
  - [ZetaHttpClientBuilder](#zetahttpclientbuilder)
  - [Automatisches Verhalten des SDK](#automatisches-verhalten-des-sdk)
- [Build-Plattformen](#build-plattformen)
  - [Kotlin](#kotlin)
  - [Android und iOS](#android-und-ios)
  - [Java](#java)
  - [C++](#c-1)
  - [C#](#c-2)

## Überblick

Das ZETA-SDK besteht aus einer Reihe von Modulen, die in [Struktur des SDK-Repositorys](../Referenzen/SDK-Uebersicht.md) beschrieben sind.
Einstiegspunkt ist die Klasse *ZetaSdk*. Sie bietet ein Builder-Interface, über das Sie das ZETA-SDK konfigurieren.

Der Build-Konfiguration geben Sie auch die Resource mit, also die URL des
Resource Servers. Nach dem `build()`-Aufruf steht eine SDK-Instanz für genau
diese Resource bereit. So lassen sich mehrere Instanzen parallel für mehrere
Fachdienste betreiben. Die zwischengespeicherten Daten einer Instanz
(Discovery-Ergebnisse, Client-Registrierung, Tokens, ASL-Session) legt das SDK
je Resource getrennt ab. Ausgenommen sind die Schlüssel im
Hardware-Schlüsselspeicher von Android und iOS, die sich alle Instanzen einer App
teilen (siehe [Attestierung](#attestierung)).

## Änderungen in Version 2.0.0

Die wichtigsten Änderungen für Integratoren gegenüber Version 1.3.x; die
vollständige Liste enthalten die [Release Notes des ZETA-SDK](../ReleaseNotes/ZetaSDK/ReleaseNotes.md).

* **Breaking Change (mobiler Client-Flow, Vorschau):** `OidcConfig` erwartet
  statt `requestUri` die beiden Redirect-URIs `redirectUri` und
  `oidcRedirectUri` sowie statt des optionalen `authenticationCallback` den
  verpflichtenden `AuthorizationLauncher`. Details siehe
  [Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen](Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).
* **Prüfung von `productId` und `productVersion`:** Die `BuildConfig` prüft
  beide Werte gegen das Format aus A_25338-01 und bricht bei ungültigen Werten
  mit einer `IllegalArgumentException` ab (siehe [Client-Registrierung](#client-registrierung)).
* **Hardwarebasierte Attestierung auf Android und iOS:** Das SDK attestiert
  mobile Clients automatisch mit Android Key Attestation bzw. Apple App Attest
  (siehe [Attestierung](#attestierung)).
* **Push-Benachrichtigungen (Vorschau):** Das Notifications-Modul entschlüsselt
  jetzt Push-Nachrichten, speichert das Schlüsselmaterial dauerhaft und liest die
  Benachrichtigungs-Historie.
* **C#:** Das C#-SDK wird als NuGet-Paket je Plattform bereitgestellt
  (siehe [C#](#c-2)).
* **ASL:** Ist die ASL-Session serverseitig abgelaufen, baut das SDK den Kanal
  automatisch neu auf. Bei ASL-Aufrufen liefert die Antwort Status und Header der
  inneren, entschlüsselten Antwort.
* **TLS:** Enthält das Serverzertifikat keinen Subject Alternative Name, prüft
  das SDK den Hostnamen gegen den Common Name.

## Weitere SDK-Module (Vorschau)

Über den hier beschriebenen Kern-Flow hinaus enthält das SDK zwei Module im
Vorschau-Status: Das Notifications-Modul verwaltet Push-Registrierungen und
Benachrichtigungskanäle beim Notification Service des Guards, entschlüsselt
empfangene Push-Nachrichten und liest die Benachrichtigungs-Historie, siehe
[Wie Sie das SDK-Notifications-Modul verwenden](Wie_Sie_das_SDK_Notifications-Modul_verwenden.md).
Für mobile Clients unterstützt das SDK zudem die interaktive Anmeldung über
einen sektoralen IDP inklusive E-Mail-Bindung, siehe
[Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen](Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).

Beide Module stehen nur in der Kotlin-Multiplatform-API zur Verfügung, das
Notifications-Modul nur auf Android und iOS (siehe
[Plattform- und Feature-Matrix](../Referenzen/SDK-Uebersicht.md#plattform--und-feature-matrix)).

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

| Parameter      | Beschreibung                                             | Kommentar                                                                                                                                                                                                                       |
|----------------|----------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| productId      | Eine Identifikation des Produkts, das das SDK integriert | Diese ID wird nach A_25337 bei der Registrierung durch die gematik zugewiesen und entspricht dem Format aus A_25338-01. Das SDK prüft beim Erzeugen der `BuildConfig`, dass die ID aus 1 bis 20 Zeichen aus `[0-9a-zA-Z-]` besteht |
| productVersion | Eine vom Hersteller vergebene Versionsnummer             | Dieser Parameter muss dem Format aus A_25338-01 entsprechen. Das SDK prüft beim Erzeugen der `BuildConfig`, dass die Version aus 1 bis 20 Zeichen aus `[0-9a-zA-Z.-]` besteht                                                  |

Entspricht einer der beiden Werte nicht dem Format, bricht das Erzeugen der
`BuildConfig` mit einer `IllegalArgumentException` ab. Die C-API und das C#-SDK
melden den Fehler über einen fehlgeschlagenen Build-Aufruf (siehe
[Fehlerbehandlung der nativen API](#fehlerbehandlung-der-nativen-api)).

Mobile Clients weisen sich auf Android und iOS bereits über die hardwarebasierte
Attestierung der Plattform aus (siehe [Attestierung](#attestierung)). Für
stationäre Clients kommen weitere Parameter, insbesondere Hash-Werte der
tatsächlich installierten Dateien für die spezifische Produkt-Version, mit der
TPM-basierten Attestierung in einem späteren Update der Spezifikation hinzu.

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
> Policy-Auswertung ab. Die generischen Code-Beispiele unten verwenden beispielhaft
> `zero:audience`.

#### Installationsspezifische Parameter

Weitere Parameter werden bei der konkreten Installation festgelegt.

| Parameter          | Beschreibung                                                                       | Kommentar                                                                                                                                                                                                                                                                                                                                                                               |
|--------------------|------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| clientName         | Der Name der spezifischen Client-Installation                                      | Diese wird im Rahmen der Client-Registrierung mit den Daten nach dem `client-statement.yaml`-Schema [gematik github](https://github.com/gematik/zeta/blob/main/src/schemas/client-statement.yaml) an den ZETA-Guard übertragen                                                                                                                                                          |
| aslProdEnvironment | Unterscheidung zwischen Produktions- und Nicht-Produktionssystemen                 | Nach A_24628-01 (aus gemSpec_Krypt) wird das ASL-Protokoll unterschiedlich verarbeitet, um die Fehlersuche in Nicht-Produktionssystemen zu erleichtern. ZETA-Guard hat eine analoge Konfiguration, die für eine erfolgreiche Verbindung übereinstimmen muss                                                                                                                             |
| exp                | Gültigkeitsdauer (in Sekunden) der vom SDK erzeugten Client-Assertion und des Subject-Tokens | Muss größer als 0 sein. Der PDP akzeptiert nur maximal 30 Sekunden                                                                                                                                                                                                                                                                                                       |
| platformProductId  | Informationen über die Client-Plattform für die Attestierung                       | Je Plattform eine Variante von `PlatformProductId`: `AndroidProductId` (Paketname und SHA-256-Fingerabdrücke der Signaturzertifikate), `AppleProductId` (Plattformtyp und Bundle-IDs), `WindowsProductId` (Store-ID und Package Family Name) bzw. `LinuxProductId` (Paketierungstyp, Application-ID und Version). Schema siehe [gematik Repository](https://github.com/gematik/zeta/blob/main/src/schemas/posture-software.yaml). Auf Android und iOS muss die Variante zur Plattform passen |

Weitere Parameter kommen über die Einbindung existierender Primärsystemfunktionalitäten hinzu, wie z. B. Konnektorzugriffe.

#### Netzwerkkonfiguration

Bei der Nutzung der API können dem HTTP-Client innerhalb des SDK verschiedene Netzwerkparameter mitgegeben werden. Hierbei werden bestimmte Defaults genutzt, falls diese Parameter nicht angegeben werden. Diese sind in den
Klassen `NetworkConfig`, `SecurityConfig` und `MonitoringConfig` definiert und werden über den
[ZetaHttpClientBuilder](#zetahttpclientbuilder) gesetzt.

| Parameter                     | Beschreibung                                                                                                    | Kommentar                                                         |
|-------------------------------|-----------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------|
| connect timeout               | Timeout in ms für den Abbruch eines Verbindungsaufbaus                                                          | Default ist 15 Sekunden                                           |
| request timeout               | Timeout für das Warten auf die Antwort für einen Request                                                        | Default ist 30 Sekunden                                           |
| socket timeout                | Timeout für das Lesen von Daten auf einem Socket                                                                | Default ist 60 Sekunden; sollte nicht kleiner als der request timeout sein |
| retry Statuscodes             | HTTP-Statuscodes, für die ein Retry durchgeführt wird                                                           | Default ist keiner (damit keine Retries)                          |
| max retries                   | Maximale Anzahl der Retries                                                                                     | Default ist 0                                                     |
| only idempotent               | Nur idempotente Aufrufe (GET, HEAD, ...) werden wiederholt, wenn true                                           | Default ist true                                                  |
| Custom CAs                    | CA-PEMs (als Strings oder als PEM-Datei) können dem Client mitgegeben werden, um eigene Zertifikate zu erlauben | Default ist keins                                                 |
| Server-Validierung abschalten | Schaltet die Prüfung des Serverzertifikats und des Hostnamens ab                                                | Default ist false; nur für Tests                                  |
| Revocation-Cache              | Maximale Dauer, für die das SDK OCSP- und CRL-Antworten zwischenspeichert                                       | Default und Mindestwert ist 3600 Sekunden                         |
| Log-Level für Requests        | Der Log-Level für die Request- und Response-Logs des HTTP-Clients                                               | Default ist `NONE` (keine Request-Logs); die Ausgabe erfolgt über den Logger des SDK auf Level INFO |
| proxy Config                  | Konfiguration eines Proxys für Netzwerkzugriffe, d. h. Typ (HTTP vs. SOCKS), Host, Port, Credentials            | Default ist kein Proxy                                            |

Das `zeta_route`-Cookie für Sticky Sessions am ZETA-Guard speichert und sendet
der HTTP-Client automatisch (siehe [StorageConfig](#storageconfig)). Der Client
für die Fachdienst-Aufrufe verwaltet derzeit nur dieses eine Cookie: Er speichert
den Wert jedes empfangenen Cookies als `zeta_route`. Eigene Cookies des
Fachdienstes werden daher nicht unter ihrem Namen zurückgesendet und
überschreiben das `zeta_route`-Cookie.

### Wiederverwendung existierender Funktionalität

Um Doppelimplementierungen im Primärsystem zu vermeiden, setzt die API auf Dependency Injection. So reicht der Client dem SDK etwa den sicheren Speicher, das Logging oder den Zugriff auf den Konnektor durch.

#### Storage

Mit diesem Objekt konfigurieren Sie den Speicher. Ohne eigene Implementierung
(`StorageConfig.Default`) nutzt das SDK einen plattformspezifischen
Standard-Speicher:

| Plattform               | Standard-Speicher                                                                                                                                                                         |
|-------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| JVM (Kotlin, Java)      | Java Preferences des Benutzers, verschlüsselt mit dem AES-Schlüssel aus der Konfiguration; die Schlüsselpaare (Client-Instanz- und DPoP-Schlüssel) legt das SDK, sofern verfügbar, im Schlüsselbund des Betriebssystems ab |
| Android                 | SharedPreferences, verschlüsselt mit einem zufällig erzeugten Schlüssel, der durch einen nicht exportierbaren Android-Keystore-Schlüssel geschützt ist; `aesB64Key` bleibt unbeachtet      |
| iOS                     | **Nur im Arbeitsspeicher** – die Daten überstehen keinen Neustart der App. Für eine dauerhafte Ablage ist eine eigene Implementierung (z. B. auf Basis der Keychain) nötig                |
| Linux (C-API, C#)       | Datei `$HOME/.zeta_sdk_storage` bzw. der konfigurierte Pfad, verschlüsselt mit dem AES-Schlüssel aus der Konfiguration                                                                     |
| macOS (C-API, C#)       | NSUserDefaults, verschlüsselt mit dem AES-Schlüssel aus der Konfiguration                                                                                                                  |
| Windows (C-API, C#)     | Windows-Registry (Schlüssel `SOFTWARE\de.gematik.zeta.sdk` des aktuellen Benutzers), verschlüsselt mit dem AES-Schlüssel aus der Konfiguration                                             |

Der AES-Schlüssel (`aesB64Key`) muss Base64-kodiert sein und dekodiert genau
32 Byte (AES-256) umfassen; anderenfalls bricht das SDK beim Erzeugen des
Clients mit einer Exception ab. Halten Sie den Schlüssel geheim und legen Sie ihn
nicht im Quellcode ab.

Wollen Sie bestehende Funktionalität wiederverwenden, implementieren Sie das Interface `SdkStorage` mit den Methoden
`put()`, `get()`, `remove()` und `clear()`.

Bei einer eigenen Implementierung verantwortet das Primärsystem die Verschlüsselung; `aesB64Key` bleibt dann unbeachtet.
Das SDK ruft die Methoden nebenläufig aus mehreren Coroutinen auf; eigene Implementierungen müssen daher
thread-safe sein (siehe `InMemoryStorage` im SDK als Referenz). In der C-API müssen alle übergebenen Pointer die gesamte Laufzeit
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
Logger und Log-Level gelten prozessweit für alle SDK-Instanzen. In Kotlin und Java setzen Sie den Log-Level mit
`Log.setLogLevel(...)` (in Java `Log.INSTANCE.setLogLevel(...)`), in der C-API über `ZetaSdk_LogVTable.logLevel`
und in C# über `ZetaClientConfig.LogLevel` (wirksam nur zusammen mit einem `Logger`).

Die Request- und Response-Logs des HTTP-Clients gibt das SDK auf Level INFO aus; sie erscheinen daher nur, wenn der
Log-Level des SDK auf INFO oder DEBUG steht. Die C-API und das C#-SDK schreiben diese Logs immer vollständig, also
mit allen Headern und Bodys und damit auch mit Tokens. Setzen Sie INFO oder DEBUG dort nur zur Fehleranalyse.

Der Standard-Log-Level ist `ERROR`. Folgende Log-Level stehen zur Verfügung:

| Level   | Beschreibung                             |
|---------|------------------------------------------|
| `DEBUG` | Alle Meldungen inkl. ausführlichem Debug |
| `INFO`  | Informationsmeldungen und höher          |
| `WARN`  | Warnungen und Fehler                     |
| `ERROR` | Nur Fehlermeldungen (Standard)           |
| `NONE`  | Keine Log-Ausgabe                        |

Das Log-Provider-Interface (`ZetaLogger`) umfasst folgende Methoden:

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

Das SDK enthält selbst keine Konnektor-Anbindung. Der frühere `SmcbTokenProvider`, der den Konnektor
über eine eigene SOAP-Anbindung aufrief, war nur ein Test-Werkzeug und ist seit Version 1.2.2 entfernt.
Als Ausgangspunkt für eine eigene Anbindung eignet sich die mit Konnektoren getestete Implementierung im
[gematik zeta-cli Repository](https://github.com/gematik/zeta-cli/tree/main/connector/src); sie muss
noch in die unten beschriebene Schnittstelle eingebunden werden.

Für den Subject-Token stehen folgende Provider zur Verfügung:

| Provider                  | Einsatz                                                                                                                                                       |
|---------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `SmbTokenProvider`        | SM-B als PKCS#12-Datei (Dateipfad, Alias, Passwort; alternativ der Keystore Base64-kodiert). Für Tests gedacht                                                |
| `CustomSmcbTokenProvider` | SMC-B über die eigene Konnektor-Anbindung des Primärsystems, die die Schnittstelle `CustomConnectorApi` implementiert                                         |
| `OidcTokenProvider`       | Anmeldung von Versicherten über einen sektoralen IDP (mobile Clients, Vorschau), siehe [mobiler Client-Flow](Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md) |

Für die eigene Konnektor-Anbindung implementieren Sie nur die beiden Konnektor-Aufrufe; die Instanz verwaltet
die Aufrufparameter (Mandant, Kartenhandle usw.) selbst. In Kotlin/Java übergeben Sie die Implementierung als
`CustomSmcbTokenProvider` an die `AuthConfig`, in C# als `ZetaAuthConfig.CustomSmcb` und in der C-API als
`ZetaSdk_SmcbVTable` in der `ZetaSdk_SmcbConfig`.

Die Signatur geben Sie als rohe, DER-kodierte ECDSA-Signatur zurück; die Umwandlung in das kompakte
JOSE-Format übernimmt das SDK. In der C-API müssen beide Callbacks genau einmal pro Aufruf aufgerufen werden,
auch im Fehlerfall (dann mit size=0). Ist in der C-API zusätzlich eine SM-B-Datei konfiguriert, hat diese Vorrang.

Das Connector-Interface umfasst folgende Methoden:

#### Kotlin / Java / C#

| Methode                                                    | Beschreibung                                                                        |
|------------------------------------------------------------|-------------------------------------------------------------------------------------|
| `readCertificate(): ByteArray`                             | SMC-B-X.509-Zertifikat als rohe DER-Bytes (nicht PEM) zurückgeben                   |
| `externalAuthenticate(base64Challenge: String): ByteArray` | Base64-kodierte Challenge signieren und die DER-kodierte ECDSA-Signatur zurückgeben |

In Kotlin sind beide Methoden `suspend`-Funktionen; in Java implementieren Sie sie über eine `Continuation`
(siehe die [Beispielimplementierung](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-java/src/main/java/de/gematik/zeta/Main.java)).
In C# heißen sie `ReadCertificateAsync()` und `ExternalAuthenticateAsync(base64Challenge)` und liefern einen `Task<byte[]>`.

#### C++

| Methode                                                 | Beschreibung                                                                                                                                        |
|---------------------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|
| `readCertificate(ctx, cb, cbCtx)`                       | SMC-B-X.509-Zertifikat im DER-Format an das SDK zurückgeben. `cb` muss genau einmal mit dem Ergebnis aufgerufen werden, auch im Fehlerfall (size=0) |
| `externalAuthenticate(ctx, base64Challenge, cb, cbCtx)` | Base64-kodierte Challenge signieren und die DER-kodierte ECDSA-Signatur zurückgeben. `cb` muss genau einmal aufgerufen werden, auch im Fehlerfall   |

`ctx` ist der opake Kontext-Pointer aus der VTable, der unverändert weitergegeben wird. `cbCtx` ist der opake Kontext-Pointer, der unverändert an den Callback weitergegeben werden muss.

#### TPM-Zugriff

Das Objekt `TpmConfig` ist weiterhin ein leerer Platzhalter. Es wird in einer Weiterentwicklung der Spezifikation ermöglichen,
den Zugriff auf das Hardware-TPM an das Primärsystem auszulagern. Die Attestierung selbst konfigurieren Sie über
`AuthConfig.attestation`, siehe [Attestierung](#attestierung).

### Attestierung

Mit der Attestierung weist sich der Client gegenüber dem ZETA-Guard aus. Das SDK nutzt je nach Plattform
zwei Arten:

* **Hardwarebasierte Attestierung (Android und Apple-Plattformen):** wird automatisch genutzt; dafür ist
  keine Konfiguration im SDK nötig.
* **Konfigurierte Attestierung (JVM, Linux, Windows):** wird über `AttestationConfig` gewählt. Sie greift
  auch auf Android und iOS, wenn das Gerät keine hardwarebasierte Attestierung unterstützt.

#### Hardwarebasierte Attestierung

Auf Android und Apple-Plattformen bindet das SDK einen hardwaregestützten Attestierungsschlüssel an den
Client-Instanzschlüssel (`PuK.Client.Sig`) und weist ihn an zwei Stellen nach:

* **Bei der Client-Registrierung (DCR):** Das SDK erzeugt den Attestierungsschlüssel und sendet den
  Attestierungsnachweis der Plattform. Die Challenge ist `SHA-256(PuK.Client.Sig)`.
* **Bei jeder Token-Anfrage:** Das Client Statement in der Client-Assertion enthält aktuelle Nachweise,
  die mit demselben Attestierungsschlüssel signiert sind (Posture-Typ `android` bzw. `apple`).

| Plattform | Verfahren                                                                                        | Nachweis bei der Registrierung                                                                       | Nachweis bei der Token-Anfrage                                                                        |
|-----------|--------------------------------------------------------------------------------------------------|------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------|
| Android   | Android Key Attestation (StrongBox, ersatzweise TEE), optional zusätzlich Google Play Integrity  | Zertifikatskette der Key Attestation, optional ein Play-Integrity-Token                               | Geräte-Posture und eine mit dem Attestierungsschlüssel signierte Prüfsumme, optional Play Integrity |
| iOS       | Apple App Attest (DeviceCheck)                                                                   | Key-ID und Attestierungsobjekt von App Attest                                                         | Geräte-Posture und eine App-Attest-Assertion                                                          |

Den Client-Instanzschlüssel selbst legt das SDK auf diesen Plattformen im Hardware-Schlüsselspeicher ab
(Android Keystore mit StrongBox bzw. TEE, Secure Enclave). Liefert der Token-Endpunkt nach einer
hardwarebasierten Attestierung ein ZETA-Attestierungs-Token, speichert das SDK es und nutzt es für eine
spätere erneute Registrierung (Fast Path), statt die Plattform-Attestierung zu wiederholen.

**Fallback:** Unterstützt das Gerät keine hardwarebasierte Attestierung – etwa Emulatoren, der
iOS-Simulator, Geräte ohne hardwaregestützten Schlüsselspeicher oder ohne App Attest –, nutzt das SDK die
konfigurierte `AttestationConfig` (standardmäßig Software) und registriert den Client mit einer
Software-Posture.

**Lebenszyklus der Schlüssel:**

* Den Attestierungszustand (Key-ID, Attestierungsobjekt bzw. Zertifikatskette, ZETA-Attestierungs-Token)
  speichert das SDK verschlüsselt im SDK-Storage, getrennt je Resource.
* `forget()` löscht den Attestierungszustand. Auf Android löscht es zusätzlich den Attestierungsschlüssel;
  App-Attest-Schlüssel lassen sich nicht löschen und werden auf iOS nur verworfen.
* `clearRegistration()` behält den Attestierungszustand.
* Wird der Attestierungsschlüssel unbrauchbar (auf Android, wenn der Keystore ihn ungültig macht, auf
  iOS, wenn App Attest den Schlüssel als ungültig meldet), verwirft das SDK ihn und attestiert bei der
  nächsten Registrierung einen neuen Schlüssel. Lehnt der Guard eine hardwarebasierte Registrierung mit
  `400` ab, verwirft das SDK den Schlüssel ebenfalls; es fällt in diesem Fall nicht auf die
  Software-Attestierung zurück.
* Den Client-Instanzschlüssel und den Attestierungsschlüssel legt das SDK app-weit unter festen Namen ab
  (Android: `Alias_Client_Sig` und `Alias_AK`). Mehrere SDK-Instanzen einer App, etwa für mehrere
  Fachdienste, teilen sich diese Schlüssel: `forget()` an einer Instanz löscht sie für alle Instanzen, und
  auf Android erzeugt die hardwarebasierte Registrierung einer weiteren Instanz den Attestierungsschlüssel
  neu. Berücksichtigen Sie das, wenn Ihre App mehrere Fachdienste anbindet.

Die Voraussetzungen auf Android (`ZetaInit.initAndroid`, Play Integrity, Manifest-Einträge) und iOS
(App-Attest-Capability) beschreibt der Abschnitt [Android und iOS](#android-und-ios).

#### AttestationConfig

`AttestationConfig` kennt drei Modi:

| Modus     | Factory-Methode                 | Beschreibung                                                                                                                       |
|-----------|---------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| Software  | `AttestationConfig.software()`  | Softwarebasierte Attestierung ohne TPM (Default)                                                                                   |
| TpmHttp   | `AttestationConfig.tpmHttp()`   | TPM-basierte Attestierung über eine HTTP-Verbindung zum lokalen Attestierungsdienst (Endpunkt, PCR-Auswahl – Default PCR 23 – und optional WebSocket-Endpunkt) |
| TpmCustom | `AttestationConfig.tpmCustom()` | TPM-basierte Attestierung über eine eigene `AttestationService`-Implementierung des Clients                                        |

`tpmHttp()` und `tpmCustom()` akzeptieren optional einen `AttestationStatusCallback`, der `OK`,
`Degraded(reason)` oder `KO(reason)` meldet. Die TPM-Modi und der zugehörige Attestierungsdienst im
SDK-Repository werden erst mit einer späteren Version der Spezifikation relevant und sind derzeit weder
genutzt noch erforderlich.

Die C-API und das C#-SDK bieten keine Konfiguration der Attestierung. Unter Linux und Windows nutzen sie die
Software-Attestierung; unter macOS nutzt die native Bibliothek App Attest, sofern verfügbar, und fällt sonst
auf die Software-Attestierung zurück.

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

| Operation                           | Beschreibung                                                                                                                                                                                                                                                                                                                | Return value          | Errors                                              |
|-------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------|-----------------------------------------------------|
| build(resource, config, clock)      | Statische Methode, um einen neuen SDK-Client zu erstellen. Die Resource-URL des Endpunkts wird hierbei als Input gegeben. D. h. für jeden Fachdienst kann ein separater Client erzeugt werden. `config` ist die `BuildConfig`. Optional lässt sich eine eigene Uhr (`ZetaClock`) übergeben, z. B. für Tests; Default ist die Systemuhr | ZetaSdkClient Object  | ungültige Konfiguration (`IllegalArgumentException`) |
| getVersion()                        | Statische Methode, die die Version des ZETA-SDK zurückgibt                                                                                                                                                                                                                                                                  | String                |                                                     |

#### ZetaSdkClient

Der `ZetaSdkClient` ist ein Objekt, das für den Zugriff auf einen bestimmten Fachdienst vorkonfiguriert ist (nach dem Bauen durch `ZetaSdk`).
Die Operationen liefern in Kotlin ein `Result`; Fehler bei Discovery, Registrierung und Authentifizierung werden als fehlgeschlagenes `Result` gemeldet.

| Operation             | Beschreibung                                                                                                                                                                                                                                                                                       | Return value                | Errors                                                                                                                                                                                     |
|-----------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-----------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| discover()            | Umsetzen der Discovery und Configuration. Dieser Call ist optional und wird ggf. automatisch nachgeholt                                                                                                                                                                                            | -                           | Fehler bei der Discovery und Configuration, insb. wenn für die Resource URL keine gültige Endpunkt-Konfiguration (im Sinne eines Eintrags in einer OPR-`.well-known`-Datei) gefunden wurde |
| register()            | Ausführen der Client-Registrierung, wenn nötig (keine client_id vorhanden oder geänderter Instanzschlüssel). Setzt die Ergebnisse von `discover()` voraus                                                                                                                                         | -                           | error codes                                                                                                                                                                                |
| authenticate()        | Ausführen der Authentifizierung, falls nötig (kein AccessToken vorhanden). Falls ein gültiges Refresh-Token vorhanden ist, wird dieses genutzt. Setzt die Ergebnisse von `discover()` und `register()` voraus                                                                                    | -                           | error codes                                                                                                                                                                                |
| httpClient()          | Gibt einen HTTP-Client zurück, dessen Operationen überschrieben werden, um die notwendigen ZETA-spezifischen Protokolle umzusetzen                                                                                                                                                                 | Ein `ZetaHttpClient`-Objekt |                                                                                                                                                                                            |
| ws()                  | Eröffnet eine WebSocket-Session zur angegebenen URL; führt dazu Discovery, Registrierung und Authentifizierung bei Bedarf aus                                                                                                                                                                       |                             | error codes                                                                                                                                                                                |
| status()              | Gibt den Status des SdkClients zurück, also ob eine Client-Registrierung vorliegt, ein AccessToken vorliegt usw.                                                                                                                                                                                   | Ein `SdkStatus`-Wert        | -                                                                                                                                                                                          |
| logout()              | Ausloggen aus dem Fachdienst: löscht die gespeicherten Tokens, die DPoP-Schlüssel und das `zeta_route`-Cookie, sodass ein neues Access-Token benötigt wird                                                                                                                                          | -                           | error codes                                                                                                                                                                                |
| changeEmail(newEmail) | Ändert die an den Client gebundene E-Mail-Adresse (mobiler Client-Flow, Vorschau); führt bei Bedarf `discover()` und `register()` aus                                                                                                                                                             | `ChangeEmailResponse`       | `ChangeEmailException` mit HTTP-Status und Problem Details nach RFC 7807                                                                                                                   |
| notifications()       | Liefert den Client für den Notification Service (nur Android und iOS, Vorschau), siehe [SDK-Notifications-Modul](Wie_Sie_das_SDK_Notifications-Modul_verwenden.md)                                                                                                                                | `NotificationClient`        | Notifications nicht konfiguriert                                                                                                                                                           |
| clearRegistration()   | Löscht Client-Registrierung, Discovery-Daten, Tokens, DPoP-Schlüssel, ASL-Session und das `zeta_route`-Cookie, behält jedoch den Instanzschlüssel und den Attestierungszustand. In Kotlin eine Funktion des Objekts `ZetaSdk`                                                                     | -                           |                                                                                                                                                                                            |
| forget()              | Vergisst alle Informationen zu der Resource: zusätzlich zu `clearRegistration()` den Instanzschlüssel, den Attestierungszustand, den Revocation-Cache sowie den lokal registrierten Pusher und dessen Schlüsselmaterial. Auf Android und iOS betrifft das Löschen der Hardware-Schlüssel alle SDK-Instanzen der App. In Kotlin eine Funktion des Objekts `ZetaSdk`; vor allem für Tests und Abmeldeszenarien gedacht | -                           | error codes                                                                                                                                                                                |
| close()               | Schließen des ZetaSDKClients: schließt die HTTP-Clients und löscht das `zeta_route`-Cookie; Registrierung, Tokens und Schlüssel bleiben erhalten                                                                                                                                                    | -                           | error codes                                                                                                                                                                                |

Die verschiedenen Stufen des ZETA-Protokolls (`discover()`, `register()`, `authenticate()`) führt das SDK bei jedem Aufruf einer Resource über den `ZetaHttpClient` sowie bei `ws()` und `changeEmail()` _automatisch_ in der richtigen Reihenfolge aus; das Erzeugen des HTTP-Clients allein löst noch nichts aus.
Rufen Sie die Methoden explizit auf, dann in der Reihenfolge `discover()`, `register()`, `authenticate()`: Jede setzt die Ergebnisse der vorherigen voraus und schlägt ohne sie fehl, sofern sie nicht bereits zwischengespeichert sind. Die Methoden sind idempotent. Zusammen mit der `status()`-Methode dienen sie nur der feingranularen Kontrolle durch das Primärsystem, soweit gewünscht – etwa um die Authentifizierung beim Start durchzuführen, sodass spätere Fachdienst-Aufrufe nicht durch Nutzerinteraktionen unterbrochen werden.

Öffnet der Client mehrere Verbindungen parallel (z. B. mehrere WebSocket-Sessions), sollte er
`discover()`, `register()` und `authenticate()` vorher einmal nacheinander aufrufen, damit diese
Schritte nicht für jede Verbindung gleichzeitig angestoßen werden. So geht auch das
[Java-Beispiel](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-java/src/main/java/de/gematik/zeta/Main.java) vor.

`status()` liefert einen der folgenden Werte:

| Wert                           | Bedeutung                                                    |
|--------------------------------|--------------------------------------------------------------|
| `NOT_REGISTERED`               | Keine Client-Registrierung vorhanden                         |
| `REGISTERED_NO_VALID_TOKENS`   | Registriert, aber ohne gültiges Refresh-Token (ein Access-Token kann noch gültig sein) |
| `HAS_REFRESH_TOKEN`            | Gültiges Refresh-Token, aber kein gültiges Access-Token      |
| `HAS_ACCESS_AND_REFRESH_TOKEN` | Gültiges Access-Token und Refresh-Token                      |

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
Das `BuildConfig`-Objekt, das Sie an `build()` übergeben, enthält die folgenden Attribute:

| Attribut             | Beschreibung                                                                                                                                                                                                      | Pflicht |
|----------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| productId            | Die gematik-Produkt-ID (Format nach A_25338-01, siehe oben)                                                                                                                                                       | ja      |
| productVersion       | Die Produktversion (Format nach A_25338-01, siehe oben)                                                                                                                                                           | ja      |
| clientName           | Der Name des Clients                                                                                                                                                                                              | ja      |
| storageConfig        | Konfiguration des Speichers, siehe [StorageConfig](#storageconfig)                                                                                                                                                | ja      |
| tpmConfig            | Platzhalter für die Konfiguration des Hardware-TPM, aktuell ohne Funktion                                                                                                                                         | ja      |
| authConfig           | Konfiguration des Authentifizierungsprozesses, wie Token-Scopes, Expiry etc. oder auch das ASL-Tracing-Flag, siehe [AuthConfig](#authconfig)                                                                     | ja      |
| platformProductId    | Plattform-Informationen wie Typ des Betriebssystems, Store-IDs der Anwendung für die Attestierung (siehe [gematik GitHub](https://github.com/gematik/zeta/blob/main/src/schemas/posture-software.yaml))        | ja      |
| httpClientBuilder    | Basis-Konfiguration für alle HTTP-Clients des SDK (PDP-Aufrufe, Sperrprüfung, Ausgangspunkt für `httpClient()` und `ws()`), siehe [ZetaHttpClientBuilder](#zetahttpclientbuilder)                                 | nein    |
| registrationCallback | Callback für Nutzerinteraktionen während der Client-Registrierung; aktuell nicht genutzt                                                                                                                          | nein    |
| logger               | Eigener Log-Provider zur Weiterleitung der SDK-Logs an das Logging-System des Primärsystems                                                                                                                      | nein    |
| notificationConfig   | Aktiviert und konfiguriert die Anbindung an den Notification Service (Vorschau); `null` (Default) deaktiviert sie, siehe [SDK-Notifications-Modul](Wie_Sie_das_SDK_Notifications-Modul_verwenden.md)           | nein    |

Hinweis: Für die Anmeldung von Versicherten (Umsetzungsstufe 2) erfolgen die
Nutzerinteraktionen nicht über Callbacks der `BuildConfig`, sondern über die
Callbacks der `OidcConfig` (`AuthorizationLauncher` für den Browser-Schritt,
`OtpCallback` für die E-Mail-Bindung), siehe
[Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen](Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).

### StorageConfig

Mit diesem Objekt wird der Speicher konfiguriert. Es gibt zwei Varianten:

| Variante  | Beschreibung                                                                                                                                                                                  |
|-----------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `Default` | Verschlüsselter Standard-Speicher der Plattform mit einem AES-256-Schlüssel (`aesB64Key`) und optionalem Dateipfad (`linuxFilePath`, nur Linux), siehe [Storage](#storage) |
| `Custom`  | Eigene Implementierung des `SdkStorage`-Interface (`provider`). Verschlüsselung liegt in der Verantwortung des Primärsystems                                                                   |

**Hinweis:** Das `zeta_route`-Cookie wird automatisch über `SdkStorage` persistiert und bei `logout()`, `forget()`, `clearRegistration()` und `close()` gelöscht. Eine zusätzliche Konfiguration ist nicht erforderlich.

Das SDK speichert u. a. folgende Daten: Discovery-Ergebnisse, die Client-Registrierung, Access- und
Refresh-Token, DPoP-Schlüssel, den Client-Instanzschlüssel (sofern er nicht im Hardware-Schlüsselspeicher
liegt), die ASL-Session, zwischengespeicherte OCSP- und CRL-Antworten, den Attestierungszustand sowie
bei aktivierten Notifications den lokalen Pusher und das Schlüsselmaterial für die Push-Entschlüsselung.

### AuthConfig

Mit diesem Objekt parametrisieren Sie die Authentifizierung.

| Attribut             | Beschreibung                                                                                                                                                                                                                                                       |
|----------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| scopes               | Scope-Werte für die Erstellung des Access-Tokens                                                                                                                                                                                                                   |
| exp                  | Gültigkeitsdauer (in Sekunden) von Client-Assertion und Subject-Token; muss größer als 0 sein. Der PDP akzeptiert nur maximal 30 Sekunden                                                                                                                         |
| aslProdEnvironment   | Default `true`. Wenn false, werden die ASL-Schlüssel (für Testzwecke) als Header im äußeren ASL-Request mitgegeben (A_24628-01)                                                                                                                                    |
| subjectTokenProvider | Objekt, mit dem ein Subject-Token erzeugt wird: `SmbTokenProvider` (SM-B-Datei, für Tests), `CustomSmcbTokenProvider` (SMC-B über die eigene Konnektor-Anbindung) oder `OidcTokenProvider` (Anmeldung über sektoralen IDP, Vorschau), siehe [Konnektor-Zugriff](#konnektor-zugriff) |
| attestation          | Konfiguriert die Attestierung, siehe [AttestationConfig](#attestationconfig). Default: `AttestationConfig.software()`. Auf Android und iOS wird automatisch die hardwarebasierte Attestierung genutzt                                                              |
| requiredRoleOid      | Die OID, die im TI-Zertifikat des ASL-Servers vorhanden sein muss. Wird beim ASL-Handshake validiert. Z. B. `1.2.276.0.76.4.328` für `oid_zeta-guard` (gemSpec_OID)                                                                                               |

### ZetaHttpClientBuilder

Mit diesem Objekt parametrisieren Sie das HTTP-Protokoll, unter anderem Retries
und Connection-Timeouts.

Das in der `BuildConfig` übergebene Objekt bildet die Grundlage für alle HTTP-Clients des SDK: für die PDP-Aufrufe, die im Hintergrund laufen, sobald eine Resource über den ZETA-Guard angefragt wird, für die Sperrprüfung (OCSP/CRL) und als Ausgangspunkt für den mit `httpClient()` erzeugten HTTP-Client für die Aufrufe der Resource über den PEP. Im Lambda von `httpClient()` lassen sich Einstellungen für die fachlichen Aufrufe ergänzen oder überschreiben; die Dauer des Revocation-Caches wertet das SDK jedoch nur aus der `BuildConfig` aus.

| Methode                                          | Beschreibung                                                                                  |
|--------------------------------------------------|-----------------------------------------------------------------------------------------------|
| `timeouts(connectMs, requestMs, socketMs)`       | Setzt die Timeouts in Millisekunden; nicht angegebene Werte bleiben unverändert               |
| `retry(statusCodes, maxRetries, onlyIdempotent)` | Konfiguriert Wiederholungen für die angegebenen HTTP-Statuscodes                              |
| `proxy(proxyConfig)`                             | Setzt einen HTTP- oder SOCKS-Proxy (`ProxyConfig`: Typ, Host, Port, optional Credentials)     |
| `addCaPem(pem)` / `setCaPems(pems)`              | Ergänzt bzw. ersetzt zusätzliche vertrauenswürdige CA-Zertifikate im PEM-Format               |
| `addCaPemFile(path)`                             | Lädt zusätzliche CA-Zertifikate aus einer PEM-Datei                                           |
| `revocationCacheDuration(seconds)`               | Maximale Dauer für das Zwischenspeichern von OCSP- und CRL-Antworten (mindestens 3600 s); nur in der `BuildConfig` wirksam |
| `disableServerValidation(true)`                  | Schaltet die Prüfung von Serverzertifikat und Hostname ab – nur für Tests                     |
| `logging(level)`                                 | Log-Level für die Request- und Response-Logs (Default `NONE`)                                 |

Die JSON-Content-Negotiation (z. B. für `body<T>()`) ist immer aktiv. Unter Windows übernimmt die native Bibliothek
(C-API, C#) zusätzlich automatisch die CAs aus dem Windows-Zertifikatsspeicher. Unter iOS werden zusätzliche CAs
und die Proxy-Konfiguration derzeit nicht ausgewertet (siehe Known Issues im
[ReadMe für Hersteller mobiler Clients](../ReadMeMobileClientHersteller.md#known-issues-mobile-devices)).

### Automatisches Verhalten des SDK

Folgende Abläufe übernimmt das SDK ohne Zutun des Primärsystems:

* **Discovery, Registrierung und Authentifizierung** werden vor dem ersten Fachdienst-Aufruf nachgeholt.
  Ein abgelaufenes Access-Token erneuert das SDK über das Refresh-Token; ist auch dieses abgelaufen,
  fordert es ein neues Token-Paar an.
* **Abgelehnte Tokens:** Antwortet der PEP (Header `zeta-error-origin: pep`) mit `401` oder `403`,
  verwirft das SDK zunächst das Access-Token und authentifiziert sich – soweit möglich über das
  Refresh-Token – neu. Lehnt der PEP auch danach ab, verwirft es alle Tokens und führt eine vollständige
  Authentifizierung durch; lehnt der PEP auch dann ab, bricht das SDK den Aufruf mit einer Exception ab.
  `401` und `403` des Fachdienstes selbst reicht das SDK unverändert an den Aufrufer durch.
* **Discovery-Fehler:** Antwortet der PEP mit `404`, verwirft das SDK die zwischengespeicherten
  Discovery-Daten und wiederholt die Discovery einmal; bleibt es bei `404`, erhält der Aufrufer die Antwort.
* **Überlast und Serverfehler:** Bei `429` wartet das SDK die im Header `Retry-After` genannte Zeit
  (ohne Angabe 5 Sekunden) und wiederholt den Aufruf, bei `502` und `504` nach 5 Sekunden; bei `500`
  verwirft es zusätzlich die ASL-Session. Diese Wiederholungen erfolgen unabhängig von der Einstellung
  „only idempotent“, also auch für POST und PATCH. Nach mehreren erfolglosen Versuchen erhält der Aufrufer
  die letzte Antwort.
* **Übrige Antworten:** `400`, `405` und `409` sowie `401`, `403` und `404`, die nicht vom PEP stammen,
  erhält der Aufrufer als Antwort. Bei anderen Fehlerstatus (z. B. `410`, `422` oder `501`) bricht das SDK
  mit einer Exception (`ZetaClientError`) ab; in der C-API ist dann das Feld `error` der HTTP-Antwort
  gesetzt, das C#-SDK wirft eine `ZetaSdkException`.
* **Fehler in vorbereitenden Schritten:** Scheitert vor dem eigentlichen Aufruf die Discovery, die
  Registrierung oder die Authentifizierung mit einer HTTP-Antwort des Guards, gibt das SDK diese Antwort an
  den Aufrufer zurück – sie stammt dann nicht vom Fachdienst. Ohne Antwort (z. B. bei einem Netzwerkfehler)
  bricht es mit einer Exception ab.
* **Registrierung mit Wiederholung:** Lehnt der Guard die Client-Registrierung ab, unternimmt das SDK
  insgesamt bis zu drei Versuche mit steigender Wartezeit, also höchstens zwei Wiederholungen, außer bei
  Statuscodes, die keine Wiederholung rechtfertigen (siehe
  [Wie die dynamische Client-Registrierung funktioniert](Wie_die_dynamische_Client-Registrierung_funktioniert.md)).
  Netzwerkfehler wiederholt es dabei nicht.
* **ASL-Session:** Meldet der PEP eine abgelaufene ASL-Session (`403` mit dem Fehler `AslSessionExpired`)
  oder antwortet der ASL-Endpunkt mit `500`, verwirft das SDK die Session und baut den ASL-Kanal einmal
  neu auf. Bei ASL-Aufrufen liefert der `ZetaHttpClient` Status und Header der inneren, entschlüsselten
  Antwort.
* **Zertifikatsprüfung:** Das SDK prüft die TLS- und ASL-Zertifikatsketten inklusive Sperrstatus
  (gestapelte OCSP-Antwort, OCSP, CRL) und speichert die Prüfergebnisse zwischen. OCSP- und CRL-Abrufe
  nutzen die konfigurierten Proxy- und Timeout-Einstellungen. Unter iOS gilt für TLS noch eine
  Einschränkung, siehe die Known Issues im
  [ReadMe für Hersteller mobiler Clients](../ReadMeMobileClientHersteller.md#known-issues-mobile-devices).
* **Sticky Sessions:** Das `zeta_route`-Cookie des ZETA-Guards wird gespeichert und mitgesendet.

## Build-Plattformen

### Kotlin

Im Folgenden ist das Beispiel eines Aufrufs einer Resource am Fachdienst in Kotlin dargestellt.

Die Konfigurationen sind umfangreicher als hier dargestellt und lassen sich in
der API-Dokumentation weiter oben bzw. besser in der IDE anschauen.

```kotlin
// statischer Aufruf, um einen ZetaSdkClient zu erzeugen
val sdk = ZetaSdk.build(
    "https://<resource-url>",                                   // Basis-URL des Fachdienstes
    BuildConfig(                                                // BuildConfig-Objekt mit der ganzen Konfiguration
        productId = "demo-client",                              // Produkt-ID (A_25338-01)
        productVersion = "2.0.0",                               // Produktversion (A_25338-01)
        clientName = "client-sdk",                              // Client-Name
        storageConfig = StorageConfig.Default(aesB64Key = storageKey), // verschlüsselter Standard-Speicher
        tpmConfig = object : TpmConfig {},                      // Platzhalter, aktuell ohne Funktion
        authConfig = AuthConfig(                                // Konfiguration der Authentifizierung
            scopes = listOf("zero:audience"),                   // Liste der Scopes
            exp = 30,                                           // Gültigkeit von Client-Assertion und Subject-Token in Sekunden
            aslProdEnvironment = true,                          // Ist es ein Produktions-Environment?
            subjectTokenProvider = SmbTokenProvider(            // Provider für die Subject-Tokens, hier SM-B (nur für Tests)
                SmbTokenProvider.Credentials(
                    keystoreFile = "<keystore-file>",
                    alias = "<alias>",
                    password = "<password>",
                ),
            ),
            attestation = AttestationConfig.software(),         // Default; auf Android/iOS greift automatisch die Hardware-Attestierung
            requiredRoleOid = requiredRoleOid,                  // Die OID, die im ASL-Serverzertifikat erwartet wird
        ),
        platformProductId = platformProductId,                  // Plattform-Informationen für die Attestierung
        httpClientBuilder = ZetaHttpClientBuilder()             // optional: HTTP-Konfiguration für die PDP-Aufrufe
            .timeouts(connectMs = 15_000, requestMs = 30_000),
        logger = myLogger,                                      // optional: eigener Log-Provider
    ),
)

// Erzeugung des HTTP-Clients
val client = sdk.httpClient {                                   // Lambda auf dem ZetaHttpClientBuilder
    logging(LogLevel.INFO)                                      // Log-Level für fachliche Requests
}

// Aufruf einer URL auf dem Fachdienst; die Antwort ist eine ZetaHttpResponse
val helloResult = client.get("hellozeta")
    .bodyAsText()
```

Die `ZetaHttpResponse` liefert `status` und `headers` sowie den Body über
`bodyAsText()`, `bodyAsBytes()` oder `body<T>()`; bei ASL-Aufrufen sind Status
und Header die der inneren Antwort. Neben `get` stehen `post`, `put`, `patch`,
`delete`, `head`, `options` und `request` zur Verfügung.

Eine WebSocket-Verbindung öffnen Sie direkt am `ZetaSdkClient`; der Block läuft
in einer Ktor-WebSocket-Session (`DefaultClientWebSocketSession`):

```kotlin
sdk.ws(
    targetUrl = "wss://<resource-host>/<pfad>/ws",            // WebSocket-URL des Fachdienstes
    customHeaders = mapOf("PoPP" to poppToken),                 // optionale zusätzliche Header
) {
    send(Frame.Text("..."))                                     // z. B. ein STOMP-Frame
    val frame = incoming.receive()
}
```

Die PlatformProductId lässt sich abhängig von der Plattform wie folgt erzeugen:

```kotlin
private fun getPlatformProduct(): PlatformProductId {
    return when (val plat = platform()) {
        is Platform.Jvm.Macos, Platform.Native.Macos -> PlatformProductId.AppleProductId("apple", "macos", listOf())
        is Platform.Jvm.Linux, Platform.Native.Linux -> PlatformProductId.LinuxProductId("linux", "", "", "0.5.0")
        is Platform.Jvm.Windows, Platform.Native.Windows -> PlatformProductId.WindowsProductId("windows", "", "")
        else -> error("Unknown platform: $plat")
    }
}
```

Für Android und iOS siehe [Android und iOS](#android-und-ios).
Die genauen Definitionen sind im Quellcode nachzusehen, wo auch der jeweils aktuelle Stand liegt.

In Gradle-Projekten (Kotlin, Kotlin Multiplatform) binden Sie das SDK über die Multiplatform-Publikation
`de.gematik.zeta:zeta-sdk` ein (mit der jeweils relevanten Version); Gradle wählt anhand der
Gradle-Metadaten die passende Plattform-Variante:

```kotlin
dependencies {
    implementation("de.gematik.zeta:zeta-sdk:x.y.z")
}
```

Maven wertet diese Metadaten nicht aus. Maven-Builds (`pom.xml`) nutzen daher auch für Kotlin das
JVM-Artefakt `zeta-sdk-jvm` (siehe [Java](#java)).

### Android und iOS

Auf Android und iOS wird das SDK über die Kotlin-Multiplatform-API genutzt (iOS über ein XCFramework,
das per CocoaPods-Plugin erzeugt wird). Zusätzlich zum oben gezeigten Aufruf gilt:

**Android**

* Initialisieren Sie das SDK beim Start der App, bevor Sie `ZetaSdk.build()` aufrufen. Der Aufruf übergibt
  den Application Context, registriert den vom SDK benötigten BouncyCastle-Provider und nimmt optional die
  Google-Cloud-Projektnummer für Play Integrity entgegen:

  ```kotlin
  ZetaInit.initAndroid(applicationContext, playIntegrityCloudProjectNumber = 123456789012L)
  ```

* **Play Integrity (optional, empfohlen):** Ohne Projektnummer ist Play Integrity deaktiviert; das SDK nutzt
  dann nur die Key Attestation und protokolliert eine Warnung. Die App muss in der Google Play Console mit dem
  Cloud-Projekt verknüpft sein. Anfragen brechen nach 10 Sekunden ab; schlägt eine Anfrage fehl, sendet das SDK
  den Nachweis ohne Play-Integrity-Token. Es gelten die Kontingente von Play Integrity (klassische Anfragen,
  die nur bei der Registrierung anfallen: 10.000 pro Tag und App, 5 pro Minute und Gerät).
* Das Manifest des SDK ergänzt das Manifest der App um die Berechtigungen `REQUEST_PASSWORD_COMPLEXITY` und
  `USE_BIOMETRIC` sowie einen `<queries>`-Eintrag für `com.google.android.modulemetadata`; das SDK nutzt sie,
  um die Geräte-Posture zu erheben.
* OCSP-Responder und CRL-Verteilpunkte der Zertifikate werden über `http://` erreicht. Da Android
  Klartext-Verkehr standardmäßig blockiert, muss die App diese Hosts in einer Network Security Configuration
  freigeben, sonst schlägt die Sperrprüfung fehl:

  ```xml
  <!-- res/xml/network_security_config.xml, im Manifest referenziert über
       <application android:networkSecurityConfig="@xml/network_security_config"> -->
  <network-security-config>
    <domain-config cleartextTrafficPermitted="true">
      <domain includeSubdomains="true">ocsp.example-ca.de</domain>
      <domain includeSubdomains="true">crl.example-ca.de</domain>
    </domain-config>
  </network-security-config>
  ```

* Die `platformProductId` muss eine `AndroidProductId` sein, z. B. mit dem Paketnamen und den
  SHA-256-Fingerabdrücken der Signaturzertifikate der App:

  ```kotlin
  PlatformProductId.AndroidProductId(
      packageName = context.packageName,
      sha256CertFingerprints = listOf("AB:CD:..."),
  )
  ```

**iOS**

* iOS 15 oder neuer; die App-Attest-Attestierung ist nur auf echten Geräten verfügbar, der Simulator fällt
  auf die konfigurierte Attestierung zurück.
* Aktivieren Sie die Capability **App Attest** der App. Sie ergänzt das Entitlement
  `com.apple.developer.devicecheck.appattest-environment` (`development` während der Entwicklung,
  `production` für App-Store- und TestFlight-Builds).
* Die `platformProductId` muss eine `AppleProductId` sein, z. B.
  `PlatformProductId.AppleProductId("apple", "ios", listOf("<bundle-id>"))`.
* Der Standard-Speicher hält die Daten auf iOS nur im Arbeitsspeicher (siehe [Storage](#storage)). Für eine
  dauerhafte Ablage übergeben Sie eine eigene `SdkStorage`-Implementierung als `StorageConfig.Custom`.

Die Demo-App im SDK-Repository (`zeta-client`, iOS-Projekt in `iosApp`) zeigt die Einbindung auf beiden
Plattformen.

### Java

Das ZETA-SDK kann als Maven-Abhängigkeit in Java-Projekte eingebunden werden. Dazu wird die
folgende Maven-Abhängigkeit in die `pom.xml` aufgenommen (mit der jeweils relevanten Version).
Die `artifactId` trägt gegenüber der Kotlin-Variante den Zusatz `-jvm`:

```xml
<!-- https://mvnrepository.com/artifact/de.gematik.zeta/zeta-sdk-jvm -->
<dependency>
  <groupId>de.gematik.zeta</groupId>
  <artifactId>zeta-sdk-jvm</artifactId>
  <version>x.y.z</version>
</dependency>
```

Die JVM-Artefakte des SDK sind für Java 21 kompiliert und setzen eine entsprechende Laufzeitumgebung voraus.
Wenn Sie das SDK selbst aus dem Quellcode bauen, publizieren Sie es vorher in das lokale
Maven-Repository:

```bash
./gradlew publishJvmPublicationToMavenLocal
```

#### API-Aufruf

Hier ist der API-Aufruf:

```java
// Erstellen der SDK-Instanz
ZetaSdkClient sdkClient = ZetaSdk.INSTANCE.build(
    getFirstResourceUrl(props),                                 // Fachdienst-URL, hier aus einer Konfigurationsdatei gelesen
    new BuildConfig(                                            // BuildConfig-Objekt
        "ZETA-Test-Client",                                     // Produkt-ID (A_25338-01)
        "2.0.0",                                                // Produktversion (A_25338-01)
        "sdk-client",                                           // Client-Name
        new StorageConfig.Custom(new InMemoryStorage()),        // Storage-Implementierung (hier InMemory nur zum Testen)
        new TpmConfig() {                                       // Platzhalter, ungenutzt bis der TPM-Zugriff spezifiziert ist
        },
        new AuthConfig(                                         // Authentication-Konfiguration
            List.of(
                "zero:audience"                                 // Scopes
            ),
            30,                                                 // Gültigkeit von Client-Assertion und Subject-Token in Sekunden
            aslProdEnv,                                         // ist es eine Produktivumgebung
            getTokenProvider(props),                            // SubjectTokenProvider
            AttestationConfig.software(),                       // Software-Attestierung
            requiredRoleId                                      // Role-OID, die im ASL-Zertifikat erwartet wird
        ),
        getPlatformProductId(),                                 // Plattform-Information
                                                                // ZetaHttpClientBuilder für die PDP-Aufrufe, inkl. Logging und möglicher Abschaltung der Server-Validierung (für Nutzung im Testsystem)
        new ZetaHttpClientBuilder().disableServerValidation(disableServerValidation).logging(LogLevel.ALL),
        null,                                                   // optional - registrationCallback, aktuell ungenutzt
        null,                                                   // optional - eigener Log-Provider
        null                                                    // optional - NotificationConfig, nur auf Android/iOS nutzbar
    ));

// Erstellen eines ZetaHttpClients
// Als Parameter wird ein Lambda auf dem ZetaHttpClientBuilder erwartet
httpClient = sdkClient.httpClient(it -> {
    it.logging(LogLevel.ALL);
    it.disableServerValidation(disableServerValidation);
    return Unit.INSTANCE;
});
```

Ein SM-B-Provider entsteht in Java z. B. mit
`new SmbTokenProvider(new SmbTokenProvider.Credentials(keystoreFile, alias, password, ""))`; der vierte
Parameter nimmt alternativ den Base64-kodierten Keystore auf. Eine eigene Konnektor-Anbindung binden Sie
als `new CustomSmcbTokenProvider(new CustomConnectorApi() { ... })` ein.

Da die Kotlin-API mit `suspend`-Funktionen arbeitet, bietet das SDK für Java blockierende Helfer in der
Klasse `ZetaSdkClientExtension`:

| Methode                                       | Beschreibung                                                               |
|-----------------------------------------------|----------------------------------------------------------------------------|
| `discover(client)`                            | Discovery ausführen; liefert `true` bei Erfolg                              |
| `register(client)`                            | Client-Registrierung ausführen; liefert `true` bei Erfolg                   |
| `authenticate(client)`                        | Authentifizierung ausführen; liefert `true` bei Erfolg                      |
| `status(client)`                              | Status des Clients (`SdkStatus`)                                            |
| `logout(client)`                              | Tokens und DPoP-Schlüssel löschen                                           |
| `clearRegistration(client)`                   | Client-Registrierung löschen, Instanzschlüssel behalten                     |
| `forget(client)`                              | Alle gespeicherten Informationen zur Resource löschen                       |
| `close(client)`                               | SDK-Client schließen                                                        |
| `changeEmail(client, newEmail)`               | E-Mail-Adresse ändern (setzt den mobilen Client-Flow voraus)                |

Für die eigentlichen Aufrufe können die Methoden am `ZetaHttpClient` direkt verwendet werden.
Um die Aufrufe asynchron umsetzen zu können, wird das Helper-Objekt `HttpClientExtension` verwendet; es bietet
`getAsync`, `postAsync`, `putAsync`, `patchAsync`, `deleteAsync`, `headAsync` und `optionsAsync`, die jeweils
ein `CompletableFuture<ZetaHttpResponse>` liefern, wie in folgendem Beispiel:

```java
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
```

Für WebSocket-Verbindungen bietet das SDK in Java die Helfer `WsClientExtension.ws(...)` (blockierend, mit
`sendText`, `sendBinary`, `receiveNext` und `close` an der `WsSession`) und `WsClientAsyncExtension.wsAsync(...)`
(asynchron, liefert ein `CompletableFuture`; die `WsAsyncSession` meldet eingehende Nachrichten an einen
registrierten Listener). Die Funktionen `stompConnectFrame`, `stompSubscribeFrame` und `stompSendFrame` erzeugen
STOMP-Frames.

Der mobile Client-Flow (OIDC) und das Notifications-Modul basieren auf `suspend`-Callbacks bzw. sind auf
Android und iOS beschränkt und stehen in Java daher derzeit nicht zur Verfügung.

Eine Beispielimplementierung findet sich im [gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-java/src/main/java/de/gematik/zeta/Main.java).

### C++

Das ZETA-SDK kann als native Shared Library (`.dylib` / `.so` / `.dll`) in C++-Projekte eingebunden werden.

#### Schritt 1 — SDK-Shared-Library bauen
```bash
./gradlew :zeta-sdk:linkDebugSharedMacosArm64   # macOS
./gradlew :zeta-sdk:linkDebugSharedLinuxX64      # Linux
./gradlew :zeta-sdk:linkDebugSharedMingwX64      # Windows
```

Für Release-Builds stehen die entsprechenden `linkRelease…`-Tasks zur Verfügung.

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
Die Reihenfolge der Felder in den Strukturen muss exakt dem generierten Header entsprechen; eine abweichende
Reihenfolge führt nicht zu einem Fehler, sondern dazu, dass Felder falsch gelesen werden. Verwenden Sie daher
möglichst benannte Initialisierer wie unten bei `ZetaSdk_AuthConfig`.

##### Erzeugung der Konfigurationsobjekte

```cpp
    ZetaSdk_StorageConfig storageConfig = {
            aesB64Key,                  // Base64-kodierter AES-256-Schlüssel für die Storage-Verschlüsselung
            nullptr,                    // storagePath - nur Linux; Default ist "$HOME/.zeta_sdk_storage"
            nullptr,                    // customStorage - optionales Custom Storage Interface. Bei Nutzung wird aesB64Key ignoriert
    };

    ZetaSdk_TpmConfig tpmConfig = {};   // reserviert, aktuell ohne Funktion

    ZetaSdk_SmbConfig smbConfig = {
            keystoreFile,
            alias,
            password
    };

    ZetaSdk_SmcbConfig smcbConfig = {}; // customSmcb = NULL, d. h. keine eigene Konnektor-Anbindung

    ZetaSdk_AuthConfig authConfig = {
            .scopes             = scopes,             // Liste der Scopes
            .scopesCount        = ARRAY_SIZE(scopes),
            .exp                = 30,                 // Gültigkeit von Client-Assertion und Subject-Token in Sekunden
            .aslProdEnvironment = aslProd,            // Produktionsumgebung
            .smbConfig          = &smbConfig,         // SM-B-Konfiguration (hat Vorrang, wenn keystoreFile gesetzt ist)
            .requiredOid        = requiredRoleOid,    // OID, die im ASL-Zertifikat erwartet wird
            .smcbConfig         = &smcbConfig,        // SMC-B-Konfiguration mit eigener Konnektor-Anbindung
    };

    ZetaSdk_SecurityConfig security = {};
    security.additionalCaPem = const_cast<char**>(caPem);
    security.additionalCaPemCount = 1;
    //security.additionalCaFile = const_cast<char*>(caPemFile);
    //security.disableServerValidation = disableTls;  // nur für Tests
    //security.sslVerbose = false;
    //security.revocationCacheDurationSeconds = 3600; // 0 = Default (3600 s)

    ZetaSdk_LogVTable logVTable = {
            nullptr,                                        // context
            my_log,                                         // Log-Callback-Funktion
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

    // Timeouts und Retries (optional); 0 bedeutet jeweils SDK-Default
    ZetaSdk_NetworkConfig networkConfig = {
            15000,          // connectTimeoutMillis
            30000,          // requestTimeoutMillis
            60000,          // socketTimeoutMillis
            0,              // maxRetries, 0 = keine Retries
            true            // retryOnlyIdempotent
    };

    // Zusammenbau des BuildConfig-Objekts
    ZetaSdk_BuildConfig buildConfig = {
            resource,                                       // Basis-URL des Fachdienstes
            const_cast<char*>(PRODUCT_ID),                  // Produkt-ID (A_25338-01)
            const_cast<char*>(PRODUCT_VERSION),             // Produktversion (A_25338-01)
            const_cast<char*>(CLIENT_NAME),                 // Client-Name
            &storageConfig, &tpmConfig, &authConfig,        // Konfigurations-Objekte
            &logVTable,                                     // optionaler Log-Provider
            nullptr,                                        // optionaler Proxy (hier &proxyConfig einsetzen)
            &security,                                      // optionale Sicherheitskonfiguration
            &networkConfig                                  // optionale Netzwerkkonfiguration (NULL = Defaults)
    };
                                                            // Erstellen des ZetaSdk-Objekts
    ZetaSdk_Client*     zetaSdkClient  = (ZetaSdk_Client*)ZetaSdk_buildZetaClient(&buildConfig);
                                                            // Erstellen des ZetaHttpClient-Objekts
    ZetaSdk_HttpClient* zetaHttpClient = (ZetaSdk_HttpClient*)ZetaSdk_buildHttpClient(zetaSdkClient);
```

Hinweis: Die C-API setzt die `platformProductId` derzeit fest je Betriebssystem (Linux, Windows, macOS);
sie lässt sich über die `ZetaSdk_BuildConfig` nicht konfigurieren.

##### Nutzung einer eigenen Konnektor-Anbindung

Um ein SMC-B-basiertes Subject-Token zu erstellen, binden Sie Ihre eigene Konnektor-Anbindung über eine
VTable ein:

```cpp
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
    // Die SM-B-Konfiguration bleibt leer, damit die Konnektor-Anbindung genutzt wird
    ZetaSdk_SmbConfig  smbConfig  = { nullptr, nullptr, nullptr };
    ZetaSdk_SmcbConfig smcbConfig = { .customSmcb = &smcbVTable };
```

##### Nutzung einer eigenen Storage-Implementierung

Um eine eigene Storage-Implementierung zu nutzen, wird in der StorageConfig eine
eigene VTable eingebunden. Die Funktionen arbeiten asynchron: Das SDK übergibt
jeweils einen Callback, den die Implementierung genau einmal aufrufen muss.

```cpp
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
```

##### Nutzung des Clients

Den Client bedienen statische Helfer-Methoden, denen Sie das jeweilige
`ZetaHttpClient`-Objekt als Parameter übergeben:

```cpp
                                                            // Beispiel-Header. Hier ein konfigurierter PoPP Token. (PoPP Token muss durch ein durch den Client dynamisches Token ersetzt werden)
    ZetaSdk_HttpHeader headers[] = {
                {(char*)POPP_HEADER, poppToken}
    };

                                                            // Erstellen des Request Objekts
    ZetaSdk_HttpRequest getRequest = {
                (char*)"hellozeta",                         // Pfad der an die Basis-URL angehängt wird
                NULL,                                       // Body, z. B. für POST (siehe Hinweis zu PUT/PATCH unten)
                headers,                                    // Zu übergebende Header
                ARRAY_SIZE(headers)
    };

                                                            // Aufruf des Fachdienstes
    ZetaSdk_HttpResponse* response = (ZetaSdk_HttpResponse*)ZetaHttpClient_get(zetaHttpClient, &getRequest);

    if (response->error == NULL) {
        // response->status, response->body und die Header auswerten
    }
    ZetaHttpResponse_destroy(response);                     // Antwort freigeben

    ZetaSdk_clearHttpClient(zetaHttpClient);                // am Ende: HTTP-Client und SDK-Client freigeben
    ZetaSdk_clearZetaClient(zetaSdkClient);
```

Die C-API stellt folgende Funktionen bereit:

| Bereich                      | Funktionen                                                                                                                                                                                       |
|------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Lebenszyklus                 | `ZetaSdk_buildZetaClient`, `ZetaSdk_clearZetaClient`, `ZetaSdk_close`, `ZetaSdk_status`, `ZetaSdk_getVersion` / `ZetaSdk_freeVersion`, `ZetaSdk_getLastError` / `ZetaSdk_freeLastError`             |
| Registrierung und Anmeldung  | `ZetaSdk_discover`, `ZetaSdk_register`, `ZetaSdk_authenticate`, `ZetaSdk_logout`, `ZetaSdk_clearRegistration`                                                                                     |
| HTTP (synchron)              | `ZetaSdk_buildHttpClient`, `ZetaSdk_clearHttpClient`, `ZetaHttpClient_get/post/put/patch/delete/head/options`, `ZetaHttpResponse_destroy`                                                         |
| HTTP (asynchron)             | `ZetaHttpClient_getAsync/postAsync/putAsync/patchAsync/deleteAsync/headAsync/optionsAsync`; im Fehlerfall wird statt `onSuccess` der Callback `onError(message)` aufgerufen                        |
| WebSocket                    | `ZetaSdk_WSSession_create`, `ZetaSdk_Client_ws`, `ZetaSdk_WSSession_sendText`, `ZetaSdk_WSSession_sendBinary`, `ZetaSdk_WSSession_receiveNext`, `ZetaSdk_WSMessage_destroy`, `ZetaSdk_WSSession_close` |

Hinweis: Die synchronen Funktionen `ZetaHttpClient_put` und `ZetaHttpClient_patch` übertragen derzeit keinen
Body; das Feld `body` des Requests wird ignoriert. Für PUT und PATCH mit Body nutzen Sie die asynchronen
Varianten `ZetaHttpClient_putAsync` bzw. `ZetaHttpClient_patchAsync`.

`ZetaSdk_status` liefert `0` (NOT_REGISTERED), `1` (REGISTERED_NO_VALID_TOKENS), `2` (HAS_REFRESH_TOKEN),
`3` (HAS_ACCESS_AND_REFRESH_TOKEN), `-1` (Fehler, siehe `ZetaSdk_getLastError`) oder `-2` (Status nicht
ermittelbar). Für `ZetaSdk_buildZetaClient` sind eine SM-B-Konfiguration oder eine eigene Konnektor-Anbindung
sowie ein Speicher (`aesB64Key` oder `customStorage`) zwingend; fehlt eines davon, schlägt der Aufruf fehl.

##### Fehlerbehandlung der nativen API

Die exportierten Funktionen werfen keine Ausnahmen über die Sprachgrenze, sondern melden Fehler über den
Rückgabewert:

* Funktionen, die einen Pointer liefern, geben im Fehlerfall `NULL` zurück.
* Funktionen, die einen Integer liefern, geben im Fehlerfall `-1` zurück.
* `void`-Funktionen tun im Fehlerfall nichts und beenden den Prozess nicht.
* Bei HTTP-Aufrufen ist im Fehlerfall das Feld `error` der Antwort gesetzt.

Die Meldung der letzten Ausnahme, die das SDK an der Sprachgrenze abgefangen hat, liefert
`ZetaSdk_getLastError()`; den String geben Sie mit `ZetaSdk_freeLastError()` wieder frei. Die Meldung gilt je
Thread und wird nicht zurückgesetzt, kann also von einem früheren Fehler stammen. `ZetaSdk_discover`,
`ZetaSdk_register`, `ZetaSdk_authenticate`, `ZetaSdk_logout`, `ZetaSdk_clearRegistration` und `ZetaSdk_close`
liefern bei einem fehlgeschlagenen Schritt nur `-1` und schreiben den Grund ins Log (z. B.
`[SDK] register failed: …`), ohne die Fehlermeldung zu setzen.

```cpp
    ZetaSdk_Client* client = (ZetaSdk_Client*)ZetaSdk_buildZetaClient(&buildConfig);
    if (client == NULL) {
        char* err = (char*)ZetaSdk_getLastError();
        fprintf(stderr, "Build failed: %s\n", err ? err : "unknown error");
        ZetaSdk_freeLastError(err);
        return 1;
    }
```

#### Beispielimplementierung

Ein Beispiel findet sich hier im [gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-client-cpp/).
Dieses nutzt die Gradle-Funktionalität zum Bauen.

Für einen Makefile-basierten Build gibt es den [nativeclient im gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-nativeclient-cpp/).

Der Client findet sich in `zeta-nativeclient-cpp/` und besteht aus:
- `hello-http.cpp` — HTTP client sample (GET, POST, PUT, DELETE, HEAD, OPTIONS)
- `hello-ws.cpp` — WebSocket client sample (STOMP connect, subscribe, create, read)
- `Makefile` — cross-platform build and run

Die Konfiguration liest der Client aus einer `.env`-Datei im Ordner `zeta-nativeclient-cpp/`
(u. a. `FACHDIENST_URL`, `SMB_KEYSTORE_FILE`, `SMB_KEYSTORE_ALIAS`, `SMB_KEYSTORE_PASSWORD`,
`STORAGE_AES_KEY`, `REQUIRED_ROLE_OID`, `ASL_PROD`, `POPP_TOKEN`, `WS_BASE_URL`, `WS_SERVER_CONTEXT_PATH`).
Gestartet wird er mit `make run-http` bzw. `make run-ws` (unter Windows `mingw32-make`).

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

Der C#-Client ist ein Wrapper um die native Bibliothek des SDK (P/Invoke) und wird als NuGet-Paket
bereitgestellt. Je Plattform gibt es ein eigenes Paket, das nur die native Bibliothek dieser Plattform enthält:

| Paket              | Plattform (Runtime Identifier) |
|--------------------|--------------------------------|
| `Zeta.Sdk.Linux`   | Linux x64 (`linux-x64`)        |
| `Zeta.Sdk.Windows` | Windows x64 (`win-x64`)        |
| `Zeta.Sdk.MacOS`   | macOS ARM64 (`osx-arm64`)      |

Voraussetzung ist .NET 10. Unter macOS lässt es sich so installieren:

```bash
brew update
brew install dotnet
```

Für Linux und Windows sind Downloads unter [https://dotnet.microsoft.com/download](https://dotnet.microsoft.com/download) zu finden.

#### Einbindung des NuGet-Pakets

Fügen Sie das Paket für Ihre Zielplattform hinzu, z. B.:

```bash
dotnet add package Zeta.Sdk.Windows --version 2.0.0
```

#### Paket selbst bauen

Wenn Sie das Paket aus dem Quellcode bauen, bauen Sie zunächst die native Bibliothek für die Zielplattform:

```bash
./gradlew :zeta-sdk:linkReleaseSharedLinuxX64      # Linux
./gradlew :zeta-sdk:linkReleaseSharedMingwX64      # Windows
./gradlew :zeta-sdk:linkReleaseSharedMacosArm64    # macOS ARM64
```

Die Bibliothek wird unter `zeta-sdk/build/bin/{osArch}/releaseShared/` abgelegt (bei `linkDebug…`-Tasks
unter `debugShared/`). Kopieren Sie sie in den `runtimes/`-Ordner des C#-Projekts `zeta-csharp-nuget`:

| Platform    | Source file                                     | Destination                  |
|-------------|-------------------------------------------------|------------------------------|
| Linux x64   | `linuxX64/releaseShared/libzeta_sdk.so`         | `runtimes/linux-x64/native/` |
| Windows x64 | `mingwX64/releaseShared/zeta_sdk.dll`           | `runtimes/win-x64/native/`   |
| macOS ARM64 | `macosArm64/releaseShared/libzeta_sdk.dylib`    | `runtimes/osx-arm64/native/` |

Dieser Schritt ist nach jedem Neubau der nativen Bibliothek zu wiederholen; fehlt die Bibliothek im
`runtimes/`-Ordner, scheitert der Start mit einer `DllNotFoundException`. Anschließend packen Sie das
Paket für die gewünschte Plattform (`ZetaRid` ist `linux-x64`, `win-x64` oder `osx-arm64`):

```bash
dotnet pack ZetaSdk.csproj --configuration Release --output ./nupkg -p:ZetaRid=linux-x64
```

Das Beispielprojekt in `zeta-csharp-nuget/sample` referenziert standardmäßig direkt das Projekt
`ZetaSdk.csproj`. Mit `-p:ZetaSdkVersion=<version>` nutzt es stattdessen das NuGet-Paket der aktuellen
Plattform (bzw. das mit `-p:ZetaSdkPackage=...` angegebene Paket).

#### Nutzung der API

Konfiguration des SDK. Pflicht sind `Resource`, `Auth` mit `RequiredRoleOid` und entweder `Smb` oder
`CustomSmcb` sowie ein Speicher, also `Storage.AesB64Key` für den Standard-Speicher oder
`Storage.CustomStorage`; fehlt eines davon, wirft `Build` eine `ZetaSdkException`. Alle anderen Werte haben
Defaults:

```csharp
var config = new ZetaClientConfig
{
    Resource       = Env("FACHDIENST_URL"),                     // Fachdienst-URL
    ProductId      = "ZETA-Test-Client",                        // Produkt-ID (A_25338-01)
    ProductVersion = "2.0.0",                                   // Produktversion (A_25338-01)
    ClientName     = "sdk-client",                              // Client-Name
    Storage = new ZetaStorageConfig                             // Storage-Konfiguration
    {
        AesB64Key = Env("STORAGE_AES_KEY"),                     // Base64-kodierter AES-256-Schlüssel für den Standard-Speicher
        // StoragePath   = "/path/to/storage",                  // optional: Pfad des Standard-Speichers (Linux)
        // CustomStorage = new MyStorage(),                     // optional: eigene ICustomStorage-Implementierung
    },
    Logger   = (level, tag, message) =>                         // optionaler Log-Provider
        Console.WriteLine($"[{level}] [{tag ?? "Zeta"}] {message}"),
    LogLevel = ZetaLogLevel.Info,                               // Log-Level - Standard ist Error; wirkt nur zusammen mit Logger
    /*Proxy = new ZetaProxyConfig
    {
        Host     = "127.0.0.1",                                 // Proxy-Host
        Port     = 8080,                                        // Proxy-Port
        Username = "user",                                      // Username, null falls nicht benötigt
        Password = "password",                                  // Password, null falls nicht benötigt
        Type     = ZetaProxyType.Http                           // Typ: Http oder Socks
    },*/
    Security = new SecurityConfig
    {
        // AdditionalCaPem = ["-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----"],
        // AdditionalCaFile = "/path/to/ca.crt",
        DisableServerValidation = false,                        // nur für Tests
        SslVerbose = false,                                     // nur für Debugging
        RevocationCacheDurationSeconds = 3600,                  // optional: OCSP/CRL-Cache (mindestens 3600 s)
    },
    Network = new NetworkConfig                                 // optional: Timeouts und Retries (0 = SDK-Default)
    {
        ConnectTimeoutMillis = 15_000,
        RequestTimeoutMillis = 30_000,
        SocketTimeoutMillis  = 60_000,
        MaxRetries           = 0,
        RetryOnlyIdempotent  = true,
    },
    Auth = new ZetaAuthConfig                                   // Authentication-Konfiguration
    {
        Scopes = ["zero:audience"],                             // Scopes
        ExpirySeconds = 30,                                     // Gültigkeit von Client-Assertion und Subject-Token
                                                                // ist das eine Produktionsumgebung?
        AslProdEnvironment = string.Equals(Env("ASL_PROD", "true"), "true"),
        Smb = new ZetaSmbConfig                                 // SM-B-Konfiguration (für Tests)
        {
            KeystoreFile = Env("SMB_KEYSTORE_FILE"),
            Alias        = Env("SMB_KEYSTORE_ALIAS"),
            Password     = Env("SMB_KEYSTORE_PASSWORD")
        },
        // CustomSmcb = new MyCustomConnector(),                // alternativ: eigene Konnektor-Anbindung (ICustomSmcbConnector)
        RequiredRoleOid = Env("REQUIRED_ROLE_OID"),             // OID, die im ASL-Zertifikat erwartet wird
    }
};
```

Erstellung des ZetaSdkClients. Schlägt der Aufbau fehl, wirft `Build` eine `ZetaSdkException`:

```csharp
using var client = ZetaClient.Build(config);
```

Erstellung des ZetaHttpClient: Hier gibt es zwei Möglichkeiten – eine Version
mit synchronen Aufrufen sowie eine Variante mit asynchronen Aufrufen.

```csharp
using var http = client.CreateHttpClient();

using var httpAsync = client.CreateHttpClientAsync();
```

Aufruf einer Resource, hier in der asynchronen Variante:

```csharp
var getResp = await httpAsync.GetAsync("hellozeta", headers);
```

Als Rückgabewert gibt es ein `ZetaHttpResponse`-Objekt mit `Status`, `Body`, `Headers` sowie
`IsSuccess`, `IsClientError` und `IsServerError`; bei den asynchronen Aufrufen ist `Headers` derzeit leer.
Fehler auf Transportebene werfen eine `ZetaSdkException`. Die synchronen Methoden `Put` und `Patch` übertragen
derzeit keinen Body; nutzen Sie dafür `PutAsync` bzw. `PatchAsync`.

Der `ZetaClient` bietet darüber hinaus folgende Methoden:

| Methode                            | Beschreibung                                                                         |
|------------------------------------|--------------------------------------------------------------------------------------|
| `Discover()`                       | Discovery ausführen; liefert `0` bei Erfolg                                           |
| `Register()`                       | Client-Registrierung ausführen; liefert `0` bei Erfolg                                |
| `Authenticate()`                   | Authentifizierung ausführen; liefert `0` bei Erfolg                                   |
| `GetStatus()`                      | Status des Clients (`ZetaSdkStatus`)                                                  |
| `Logout()`                         | Tokens löschen; die Client-Registrierung bleibt erhalten                              |
| `ClearRegistration()`              | Client-Registrierung löschen, sodass sich der Client neu registriert                  |
| `OpenWebSocket(url, headers, ...)` | WebSocket-/STOMP-Session (`WsSession`) über die ZETA-authentifizierte Verbindung öffnen; liefert `0` oder `-1`, wobei `-1` derzeit auch auf einen früheren Fehler zurückgehen kann (siehe `GetLastError()`) |
| `GetLastError()`                   | Meldung der letzten an der Sprachgrenze abgefangenen Ausnahme lesen; sie wird nicht zurückgesetzt |
| `GetVersion()`                     | Version des nativen SDK                                                               |
| `Dispose()`                        | Native Ressourcen freigeben                                                           |

Eine Beispielimplementierung findet sich im [gematik zeta-sdk Repository](https://github.com/gematik/zeta-sdk/blob/main/zeta-csharp-nuget/sample/).
