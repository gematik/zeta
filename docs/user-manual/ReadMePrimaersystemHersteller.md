# Informationen für Primärsystem-Hersteller

Primärsystem-Hersteller binden das ZETA-SDK in ihre Primärsystemanwendungen
ein, um Dienste der TI 2.0 aufzurufen.

Hinweis: Die Nutzung eines mobilen Clients ist aktuell nur als Vorschau
vorhanden – siehe dazu auch das entsprechende
[ReadMe](ReadMeMobileClientHersteller.md).

## Betrachtete Nutzungsszenarien

Die ZETA-Komponenten bilden einen weitgehend transparenten Tunnel zwischen
Client und Fachdienst. Für Tests wird daher vorausgesetzt, dass
Primärsystemhersteller mindestens über einen Fachdienst-Simulator – ohne
ZETA-Guard – verfügen. Alternativ dienen eigene oder bestehende
3rd-Party-Test-Fachdienste mit vorhandenem ZETA-Guard; eine weitere Möglichkeit
ist der [gematik Test-Hub](https://github.com/gematik/ti2.0-testhub).

![ZETA-Komponenten für Primärsystemhersteller](assets/images/ZETA-PS-Hersteller.png)

Dieses Dokument betrachtet daher:

1. Integration des ZETA-SDK in ein existierendes Primärsystem
2. Optionaler Aufbau eines ZETA-Guard vor einem Test-Fachdienst

Der Aufbau eines ZETA-Guard vor einem bestehenden Test-Fachdienst entspricht dem
Setup für Fachdienst-Hersteller und ist hier optional; dafür genügt der Verweis
auf den [Abschnitt für Fachdienst-Hersteller](ReadMeFachdienstHersteller.md).

Im Folgenden geht es daher nur um die Voraussetzungen für die Integration des
SDK in Fachdienst-Clients.

## Systemvoraussetzungen

### Registrierung

* Ein Hersteller registriert sein Produkt bei der gematik über das
  Fachportal https://fachportal.gematik.de/formulare-product-id/neuanlage und
  erhält eine von der gematik generierte Product_ID. Existierende Product_IDs
  können wiederverwendet werden und mittels eines Änderungsantrags für die
  Nutzung von TI-2.0-Fachdiensten freigeschaltet werden.
* Registrierung der Produktversion des Clients. Diese Version wird ebenso in die
  Regeln eingetragen.
* Falls das Primärsystem die TPM-Attestierung verwendet, müssen die entsprechenden
  Informationen (wie Liste der unveränderlichen Dateien, Hashwerte) an die gematik
  gemeldet werden, damit diese auch in die OPA-Regeln aufgenommen werden können.
  (Hinweis: Hardwarebasierte Attestierung ist noch nicht vollständig
  spezifiziert, und daher sind die nötigen Informationen noch nicht definiert.)

Die aktuell definierte Liste der Informationen für die Beantragung einer
Produktversion ist:

1. verwendete ZETA-Client-SDK-Version
2. verwendete TI-Fachdienste mit den dazugehörigen Versionen (z. B. ePA 3.2.1)
   (Mehrfachnennung möglich)
3. **bei Nutzung von TPM-Attestierung und ZETA-Attestierungsservice auf dem
   Client**: Übermittlung des Gesamthashes, gebildet über alle einzelnen Hashes
   der unveränderlichen Dateien einer Clientproduktversion

### Zugänge

> **Begriffe:** „(ab) Umsetzungsstufe 2“ bzw. „Stufe 2“ bezeichnet die zweite
> Ausbaustufe der ZETA-Spezifikation (u. a. Anmeldung von Versicherten über
> sektorale IDPs); so markierte Punkte sind für den aktuellen Funktionsumfang
> (Stufe 1) noch nicht erforderlich. „PIP/PAP“ steht für Policy Information
> Point / Policy Administration Point — die Bezugsquelle der signierten
> OPA-Policy-Bundles.

#### Build-Time

* Maven-Repository für die Nutzung der dort abgelegten Module (Java, Kotlin)

#### Test und Betrieb

* Test-Fachdienst mit ZETA-Guard (mit oder ohne ASL, abhängig vom Fachdienst).
  Entweder selbst aufgesetzt oder z. B. aus dem gematik Test-Hub.

* TI-Dienste (MUSS)
    * OCSP-Responder der TI-TSL (d. h. der Responder im Internet, nicht der im
      TI-1.0-Netz)
    * Federation Master (ab Stufe 2)

* TI-Dienste (abhängig vom Fachdienst, ab Umsetzungsstufe 2)
    * Federated IDP bzw. sektorale IDPs

### Eigene Dienste

* Eigene Build- und Deployment-Pipeline, in der die Komponenten
  eingebunden werden können

* anbietereigene Dienste (abhängig vom Fachdienst, ab Umsetzungsstufe 2)
    * Clientsystem-Notification-Service(s) – Apple Push Notifications, Firebase;
      SDK-seitig als Vorschau verfügbar, siehe
      [Wie Sie das SDK-Notifications-Modul verwenden](Anleitungen/Wie_Sie_das_SDK_Notifications-Modul_verwenden.md)
    * E-Mail-Confirmation-Code – Mail-Empfang

### Eigene Client-Komponenten

Um Doppelimplementierungen zu vermeiden und Testaufwände zu verringern, stellt
der Client bzw. das Primärsystem dem SDK mehrere Funktionen bereit:

1. Eine Implementierung für sicheres Speichern von sensitiven Daten wie
   Access-Tokens
2. Eine Konnektor-Anbindung
3. Eine Möglichkeit der Log-Ausgabe

Hinweis: Die aktuell mitgelieferten Komponenten für diese Funktionalitäten
dienen nur der Demonstration und dem Test und sind nicht produktionsgeeignet.

### Infrastruktur

Eigene Infrastruktur ist für Builds und für Tests nötig. Beides setzt dieses
Handbuch als Teil der bestehenden Build- und Testinfrastruktur des Primärsystems
voraus.

### Tooling

Die Anforderungen an das Tooling unterscheiden sich je Plattform; durchgehend
vorausgesetzt sind aber Gradle und damit Java als Build-Tool.

#### Java, Kotlin

Bei beiden Zielplattformen wird Java als Build-Tool sowie als Laufzeitumgebung
verwendet.

* Java
* Gradle als Build-Tool

#### C++

Der C++-Client kann auf zwei Arten gebaut werden: zum einen mit
Java und Gradle als Build-Tool. Dies ist im Ordner `zeta-client-cpp` gezeigt.
Zum anderen als reiner `Makefile`-Build.

Beide Varianten benötigen Java sowie einen C++-Compiler. Die zweite Variante
benötigt zusätzlich `make` als Build-Tool.

##### C++ auf Windows

* Java (für Gradle als Build-Tool) nur für den Gradle-basierten C++-Client
* MinGW (`g++`, `mingw32-make`) für den nativen C++-Client ohne Gradle

##### C++ auf Apple

* Java (für Gradle als Build-Tool) nur für den Gradle-basierten C++-Client
* `clang++`, `make` für den nativen C++-Client ohne Gradle

##### C++ auf Linux

* Java (für Gradle als Build-Tool) nur für den Gradle-basierten C++-Client
  (zeta-client-cpp)
* alternativ Make für einen nativen Build (zeta-nativeclient-cpp)
* `gcc/g++` oder `clang/clang++`, `make` für den nativen C++-Client ohne Gradle

#### C#

Der C#-Client ist ein Wrapper um die Kotlin-Bibliothek und nutzt deren C-ABI.
Daher werden die Voraussetzungen für den C++-Build auf der jeweiligen Plattform
benötigt, zusätzlich die .NET-spezifischen Voraussetzungen.

* die Voraussetzungen für den jeweiligen C++-Build
* .NET 10.0

## Sicherheitsleistungen

Das ZETA-SDK muss in eine Client-Anwendung integriert werden. Die gematik-Anforderungen
bedingen dabei Sicherheitsleistungen, die nur im Rahmen einer Client-Anwendung
zu erfüllen sind.

Diese Sicherheitsleistungen sind in [Sicherheitsleistungen Client-Hersteller](SicherheitsanforderungenClientHersteller.md)
dargelegt.

## Relevante Anleitungen und Referenzen

Die relevanten Anleitungen und Referenzen sind hier verlinkt:

* Für das Integrieren des ZETA-Client-SDK:
  [Wie Sie das ZETA-SDK integrieren](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md)

* Wie die dynamische Client-Registrierung (DCR) am ZETA-Guard abläuft und was
  das SDK dabei automatisch übernimmt:
  [Wie die dynamische Client-Registrierung funktioniert](Anleitungen/Wie_die_dynamische_Client-Registrierung_funktioniert.md)
* Wie Registrierungen ablaufen, verdrängt oder widerrufen werden — und was
  `forget()`/`clearRegistration()` serverseitig bedeuten:
  [Wie der Client-Lebenszyklus verwaltet wird](Anleitungen/Wie_der_Client-Lebenszyklus_verwaltet_wird.md)
* Wie mobile Apps den Anmeldeflow über sektorale IDPs mit dem SDK umsetzen
  (Vorschau):
  [Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen](Anleitungen/Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md)
* Wie mobile Apps Push-Benachrichtigungen über das SDK-Notifications-Modul
  verwalten (Vorschau):
  [Wie Sie das SDK-Notifications-Modul verwenden](Anleitungen/Wie_Sie_das_SDK_Notifications-Modul_verwenden.md)

* Wie Sie einen Ende-zu-Ende-Integrationstest ausführen – dies kann als Beispiel
  für die Nutzung des Tiger-Frameworks zum Aufsetzen von Ende-zu-Ende-Tests
  dienen:
  [Wie Sie einen Ende-zu-Ende-Integrationstest ausführen](Anleitungen/Wie_Sie_einen_Ende_zu_Ende_Integrationstest_ausführen.md)

* [Wie Sie mögliche Probleme im SDK analysieren können](Anleitungen/Wie_Sie_Probleme_im_SDK_analysieren.md)

Falls ein cloudbasiertes Primärsystem den ZETA-Client ggf. als eigenen Container
betreiben möchte (abhängig von Sicherheitsbetrachtungen und Zulassung), können
diese Anleitungen als Basis für Eigenentwicklungen hilfreich sein:

* Für das Bauen des ZETA-Testdrivers (ein ZETA-Client, der als Proxy dient):
  [Wie Sie den Testdriver bauen](Anleitungen/Wie_Sie_den_Testdriver_bauen.md)
* Für das Ausführen des ZETA-Testdrivers:
  [Wie Sie den Testdriver nutzen](Anleitungen/Wie_Sie_den_Testdriver_nutzen.md)

## Known Issues und Fehleranalysen

Bekannte Einschränkungen der serverseitigen ZETA-Guard-Komponenten werden im
Abschnitt „Known Issues“ der
[Release Notes des Helm-Chart-Repositories](https://github.com/gematik/zeta-guard-helm/blob/main/ReleaseNotes.md#known-issues)
geführt.

### Known Issues

* Die Abrufe der OCSP-Responses und der CRL erfolgen mit einem
  Standard-HTTP(S)-Client. Daher werden nur die dem Betriebssystem bekannten CAs
  berücksichtigt. D. h. die dem SDK zusätzlich hinzugefügten CAs werden aktuell
  nicht berücksichtigt. In solchen Fällen sind die zusätzlich notwendigen CAs
  dem Betriebssystem bekannt zu machen. Betroffen sind alle Plattformen (Linux,
  Windows, Mac, Mobile).

* Die Strukturierung der Ablage von gespeicherten Tokens etc. wurde geändert. Es
  hatte sich gezeigt, dass die Index-Schlüssel zu lang wurden. Daher wurden diese
  durch ein neues Verfahren ersetzt. Als Konsequenz werden sich die mobilen
  Clients bei erstmaliger Nutzung der Version 1.3.0 neu beim Guard registrieren.

### Known Issues Mobile Devices

Hinweis: Die Nutzung mit mobilen Geräten ist noch als Vorschau zu bewerten und
nicht produktiv nutzbar.

* Mit Android-API-Versionen < 37 kann die gestapelte OCSP-Response nicht
  extrahiert werden und wird damit aktuell nicht geprüft. In zukünftigen
  Versionen wird eine zusätzliche Bibliothek eingesetzt, die diese
  Funktionalität ermöglicht.

* Unter iOS nutzen wir noch die betriebssystemseitige TLS-Verifikation. Die
  gematik-spezifischen Prüfungen sind daher noch nicht umgesetzt. Im nächsten
  Release wird dies durch den ktor-curl-client ersetzt.

### Weitere Hinweise

* Wie in der Integrationsdokumentation beschrieben, soll das SDK die bestehende
  Infrastruktur des Clients wiederverwenden. Funktionen des Clients und des
  Primärsystems können sich daher überschneiden; in diesem Fall hat die
  bestehende Funktion des Clients Vorrang. Sie binden solche Funktionen über
  Dependency Injection in der Laufzeitkonfiguration des SDK ein. Das betrifft
  vor allem:
  * sichere Speicherung von Daten wie Access-Tokens
  * Zugriff auf SubjectToken (SM-B als Datei bzw. SMC-B via Konnektor)
  * Nutzerinteraktionen (ab Umsetzungsstufe 2)

## Wartung

Updates und Sicherheitspatches werden als neue Releases über die jeweiligen
Artefakt- bzw. Image-Repositories bereitgestellt; die Änderungen je Version
sind in den jeweiligen Release Notes dokumentiert.
Die Melde- und Kommunikationswege für Schwachstellen, Fehler und
Aktualisierungsbedarfe zwischen Hersteller/Betreiber und gematik sind über die
etablierten ITSM-Prozesse abgestimmt.
