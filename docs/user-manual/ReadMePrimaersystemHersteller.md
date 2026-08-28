
# Informationen für Primärsystem-Betreiber

Primärsystem-Hersteller binden das ZETA-SDK in ihre Primärsystemanwendungen
ein, um Dienste der TI 2.0 aufzurufen.

> [!WARNING]
> **Begrenzte Anzahl von Client-Registrierungen pro SMC-B**
>
> Der ZETA-Guard begrenzt die Anzahl der Client-Registrierungen pro SMC-B
> (Standard: 256). Beim Erreichen des Limits löscht der ZETA-Guard automatisch
> die am längsten inaktive Registrierung des Nutzers. Details siehe
> [Wie der Client-Lebenszyklus verwaltet wird](Anleitungen/Wie_der_Client-Lebenszyklus_verwaltet_wird.md).

Hinweis: die Nutzung eines mobilen Clients ist aktuell nur als Vorschau vorhanden - siehe
dazu auch das entsprechende [ReadMe](ReadMeMobileClientHersteller.md)

## Betrachtete Nutzungsszenarien

Die ZETA-Komponenten bilden im Prinzip einen transparenten Tunnel
zwischen Client und Fachdienst. Es wird hier daher davon ausgegangen,
dass Primärsystemhersteller für Tests mindestens über
einen Fachdienst-Simulator – ohne ZETA-Guard – verfügen. Alternativ können
eigene oder existierende 3rd Party Test-Fachdienste mit bereits vorhandenem ZETA-Guard
genutzt werden. Eine weitere Alternative ist dann die Nutzung des
[gematik Test-Hubs](https://github.com/gematik/ti2.0-testhub).

![ZETA-Komponenten für Primärsystemhersteller](assets/images/ZETA-PS-Hersteller.png)

Es wird daher betrachtet:

1. Integration des ZETA-SDK in ein existierendes Primärsystem
2. Optionaler Aufbau eines ZETA-Guard vor einem Test-Fachdienst

Da der Aufbau des ZETA-Guard vor einem existierenden Test-Fachdienst
dem Setup für Fachdienst-Hersteller entspricht, und hier auch optional
ist, wird hier dafür nur auf den [Abschnitt für Fachdienst-Hersteller](ReadMeFachdienstHersteller.md)
verwiesen.

Im Folgenden wird daher nur auf die Voraussetzungen und Informationen
für die Integration des SDK in Fachdienst-Clients hingewiesen.

## Systemvoraussetzungen

### Registrierung

* Ein Hersteller registriert sein Produkt bei der gematik über das
  Fachportal https://fachportal.gematik.de/formulare-product-id/neuanlage und
  erhält eine von der gematik generierte Product_ID. Existierende Product_IDs
  können wiederverwendet werden und mittels eines Änderungsantrags für die
  Nutzung von TI2.0 Fachdienste freigeschaltet werden.
* Registrierung der Produktversion des Clients. Diese Version wird ebenso in die
  Regeln eingetragen.
* Falls das Primärsystem die TPM-Attestierung verwendet, müssen die entsprechenden
  Informationen (wie Liste der unveränderlichen Dateien, Hashwerte) an die gematik
  gemeldet werden, damit diese auch in die OPA-Regeln aufgenommen werden können.
  (Hinweis: Hardware-basierte Attestierung ist noch nicht vollständig spezifiziert
  und daher sind die nötigen Informationen noch nicht definiert).

Die aktuell definierte Liste der Informationen für die Beantragung einer
Produktversion ist

1. verwendete ZETA Client SDK Version
2. verwendete TI Fachdienste mit den dazugehörigen Versionen (z.B. ePA 3.2.1)
   (Mehrfachnennung möglich)
3. **bei Nutzung von TPM-Attestierung und ZETA-Attestierungsservice auf dem Client**: Übermittlung des Hash
  Gesamthash gebildet über alle einzelnen Hashes der unveränderlichen Dateien einer Clientproduktversion

### Zugänge

> **Begriffe:** „(ab) Umsetzungsstufe 2" bzw. „Stufe 2" bezeichnet die zweite
> Ausbaustufe der ZETA-Spezifikation (u. a. Anmeldung von Versicherten über
> sektorale IDPs); so markierte Punkte sind für den aktuellen Funktionsumfang
> (Stufe 1) noch nicht erforderlich. „PIP/PAP" steht für Policy Information
> Point / Policy Administration Point — die Bezugsquelle der signierten
> OPA-Policy-Bundles.

#### Build-Time

* Maven repository für die Nutzung der dort abgelegten Module (Java, kotlin)

#### Test und Betrieb

* Test-Fachdienst mit ZETA-Guard (mit oder ohne ASL, abhängig vom Fachdienst).
  Entweder selbst aufgesetzt oder z.B. aus dem gematik Test-Hub.

* TI Dienste (MUSS)
    * OCSP Responder der TI TSL (d.h. der Responder im Internet nicht der im
      TI 1.0 Netz)
    * Federation Master (ab Stufe 2)

* TI Dienste (Abhängig von Fachdienst, ab Umsetzungsstufe 2)
    * Federated IDP bzw. Sektorale IdPs

### Eigene Dienste

* Eigene Build- und Deployment-Pipeline, in der die Komponenten
  eingebunden werden können

* anbietereigene Dienste (Abhängig vom Fachdienst, ab Umsetzungsstufe 2)
    * Clientsystem Notification Service(s) – Apple Push Notifications, Firebase;
      SDK-seitig als Vorschau verfügbar, siehe
      [Wie Sie das SDK Notifications-Modul verwenden](Anleitungen/Wie_Sie_das_SDK_Notifications-Modul_verwenden.md)
    * E-Mail Confirmation-Code – Mail-Empfang

### Eigene Client-Komponenten

Um die Doppelimplementierung im Primärsystem zu vermeiden und um Testaufwände
zu verringern, wird erwartet dass verschiedene Funktionalitäten dem SDK
durch den Client / das Primärsystem bereitgestellt wird:

1. Eine Implementierung für sicheres Speichern von sensitiven Daten wie Access Tokens
2. Eine Konnektor-Anbindung
3. Eine Möglichkeit der Log-Ausgabe

Hinweis: die aktuell mitgelieferten Komponenten für diese Funktionalitäten
dienen nur der Demonstration und dem Test und sind nicht Produktionsgeeignet.

### Infrastruktur

Eigene Infrastruktur ist einmal für Builds und einmal für Tests nötig.
Beides wird im Rahmen einer existierenden Build- und Testinfrastruktur für
das Primärsystem vorausgesetzt.

### Tooling

Beim Tooling ergeben sich unterschiedliche Anforderungen pro Plattform.
Hierbei wird aber immer von gradle und damit Java als Build-Tool ausgegangen.

#### Java, kotlin

Bei beiden Zielplattformen wird Java als build-tool sowie als Laufzeitumgebung
verwendet.

* Java
* gradle als build-Tool

#### C++

Der C++ Client kann auf zwei Arten gebaut werden, einmal mit
Java und gradle als Build-Tool. Dies ist im Ordner `zeta-client-cpp` gezeigt.
Zum Anderen als reiner `Makefile` build.

Beide Varianten benötigen Java sowie einen C++ compiler. Die zweite Variante
benötigt zusätzlich `make` als build-tool.

##### C++ auf Windows

* Java (für gradle als build-Tool) nur für den Gradle-basierten C++ Client
* MinGW (`g++`, `mingw32-make`) für den nativen C++ Client ohne Gradle

##### C++ auf Apple

* Java (für gradle als build-Tool) nur für den Gradle-basierten C++ Client
* `clang++`, `make` für den nativen C++ Client ohne Gradle

##### C++ auf Linux

* Java (für gradle als build-Tool) nur für den Gradle-basierten C++ Client (zeta-client-cpp)
* Alternativ Make für einen nativen build (zeta-nativeclient-cpp)
* `gcc/g++` oder `clang/clang++`, `make` für den nativen C++ Client ohne Gradle

#### C#

Der C# Client ist ein Wrapper um die kotlin-Bibliothek und nutzt deren C ABI. Daher werden die Voraussetzungen
für den C++ Build auf der jeweiligen Plattform benötigt, plus die .NET-spezifischen
Voraussetzungen.

* Die Voraussetzungen für den jeweiligen C++ Build
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
  [Wie Sie das ZETA-SDK integrieren.md](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md)

* Wie die dynamische Client-Registrierung (DCR) am ZETA-Guard abläuft und was
  das SDK dabei automatisch übernimmt:
  [Wie die dynamische Client-Registrierung funktioniert](Anleitungen/Wie_die_dynamische_Client-Registrierung_funktioniert.md)
* Wie Registrierungen ablaufen, verdrängt oder widerrufen werden — und was
  `forget()`/`clearRegistration()` serverseitig bedeuten:
  [Wie der Client-Lebenszyklus verwaltet wird](Anleitungen/Wie_der_Client-Lebenszyklus_verwaltet_wird.md)
* Wie mobile Apps den Anmeldeflow über sektorale IDPs mit dem SDK umsetzen
  (Vorschau):
  [Wie Sie den mobilen Client-Flow mit dem ZETA SDK umsetzen](Anleitungen/Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md)
* Wie mobile Apps Push-Benachrichtigungen über das SDK Notifications-Modul
  verwalten (Vorschau):
  [Wie Sie das SDK Notifications-Modul verwenden](Anleitungen/Wie_Sie_das_SDK_Notifications-Modul_verwenden.md)

* Wie Sie einen Ende-zu-Ende-Integrationstest ausführen – dies kann als Beispiel
  für die Nutzung des Tiger-Frameworks zum Aufsetzen von Ende-zu-Ende tests dienen.
  [Wie Sie einen Ende-zu-Ende-Integrationstest ausführen](Anleitungen/Wie_Sie_einen_Ende_zu_Ende_Integrationstest_ausführen.md)

* [Wie sie mögliche Probleme im SDK analysieren können](Anleitungen/Wie_Sie_Probleme_im_SDK_analysieren.md)


Falls ein cloudbasiertes Primärsystem den ZETA-Client ggf. als eigenen Container
betreiben möchte (abhängig von Sicherheitsbetrachtungen und Zulassung), können
diese Anleitungen als Basis für Eigenentwicklungen hilfreich sein:

* Für das Bauen des ZETA-Testdrivers (ein ZETA-Client, der als Proxy dient)
  [Wie Sie den Testdriver bauen](Anleitungen/Wie_Sie_den_Testdriver_bauen.md)
* Für das Ausführen des ZETA-Testdrivers
  [Wie Sie den Testdriver nutzen](Anleitungen/Wie_Sie_den_Testdriver_nutzen.md)

## Known Issues und Fehleranalysen

Bekannte Einschränkungen der serverseitigen ZETA-Guard-Komponenten werden im
Abschnitt „Known Issues" der
[Release Notes des Helm-Chart-Repositories](https://github.com/gematik/zeta-guard-helm/blob/main/ReleaseNotes.md#known-issues)
geführt.

### Known Issues

* Die Abrufe der OCSP Responses und der CRL erfolgen mit einem Standard-HTTP(S)-Client.
  Daher werden nur die dem Betriebssystem bekannten CAs berücksichtigt.
  D.h. die dem SDK zusätzlich hinzugefügten CAs werden aktuell nicht berücksichtigt.
  In solchen Fällen sind die zusätzlich notwendigen CAs dem Betriebssystem bekannt zu machen.
  Es sind alle Plattformen (Linux, Windows, Mac, Mobile) davon betroffen.

* Die Strukturierung der Ablage von gespeicherten Tokens etc wurde geändert. Es
  hatte sich gezeigt, dass die Index-Schlüssel zu lang wurden. Daher wurden diese
  durch ein neues Verfahren ersetzt. Als Konsequenz werden sich die mobilen Client
  bei erstmaliger Nutzung der Version 1.3.0 neu beim Guard registrieren.

### Known Issues Mobile Devices

Hinweis: die Nutzung mit Mobilen Geräten ist noch als Vorschau zu bewerten und
nicht produktiv nutzbar.

* Mit Android API Versionen < 37 kann die Stapled OCSP Response nicht extrahiert werden und
  wird damit aktuell nicht geprüft. In zukünftigen Versionen wird eine zusätzliche
  Bibliothek eingesetzt, die diese Funktionalität ermöglicht.

* In iOS nutzen wir noch die betriebssystemseitige TLS Verifikation. Die gematik-spezfischen
  Prüfungen sind daher noch nicht umgesetzt. Im nächsten Release wird dies durch
  den ktor-curl-client ersetzt.

### Weitere Hinweise

* Wie in der Dokumentation zur Integration beschrieben, ist das SDK darauf ausgelegt,
  bestehende Infrastruktur des existierenden Clients wiederzuverwenden. D.h.
  es kann Überschneidungen in der Funktionalität des Clients mit dem Primärsystem geben.
  In solchen Fällen ist die existierende Funktionalität des Clients vorzuziehen.
  Die Nutzung existierender Funktionen ist über die Injection der
  Funktionalität bei der Laufzeitkonfiguration des SDK möglich. Dies
  betrifft insbesondere:
  * sichere Speicherung von Daten wie Access Tokens
  * Zugriff auf SubjectToken (SM-B als Datei bzw. SMC-B via Konnektor)
  * Nutzerinteraktionen (ab Umsetzungsstufe 2)

## Wartung

Updates und Sicherheitspatches werden als neue Releases über die jeweiligen
Artefakt- bzw. Image-Repositories bereitgestellt; die Änderungen je Version
sind in den jeweiligen Release Notes dokumentiert.
Die Melde- und Kommunikationswege für Schwachstellen, Fehler und
Aktualisierungsbedarfe zwischen Hersteller/Betreiber und gematik sind über die
etablierten ITSM-Prozesse abgestimmt.
