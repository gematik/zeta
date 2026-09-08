# 5.12 Notification Service (Neufassung – Entwurf)

## Vorbemerkung

Diese Neufassung wendet dieselbe Methodik wie die Neufassung von Kapitel 5.5 (Client Management) an:

1. **Atomarität**: Jede Anforderung enthält genau eine MUSS-, SOLL- oder DARF-NICHT-Aussage und entspricht einem einzelnen, durch Gutachter oder Tester durchführbaren Prüfschritt.
2. **Unabhängigkeit**: Anforderungen referenzieren keine anderen Anforderungen dieses Kapitels. Benötigte Begriffe, Akteure, Betriebsvarianten und Statusmodelle werden einmalig in Abschnitt 5.12.0 definiert. Verweise auf externe Dokumente ([gemF_PushNotification], [gemSpec_Krypt], OpenAPI-Dateien) bleiben bestehen, da sie keine Abhängigkeit zwischen zwei Prüfschritten dieses Kapitels erzeugen.
3. **Klare Gliederung**: Jedes Unterkapitel beginnt mit einer kurzen, nicht-normativen Einleitung.
4. **Redundanzvermeidung**: MUSS/DARF-NICHT-Paare, bei denen die DARF-NICHT-Aussage nur die logische Umkehrung einer bereits mit einem Exklusivitätswort („ausschließlich", „genau", „nur") formulierten MUSS-Aussage war, wurden zu einer Anforderung zusammengeführt.

**Nummerierung**: Anforderungs-IDs sind an die Original-Spezifikation angelehnt (Basis-ID, ergänzt um `-01`, `-02` usw. bei Aufteilung). Die verbindliche Vergabe endgültiger Afo-Nummern obliegt der gematik.
**Kritische Scope-Prüfung (Phasing)**: Zusätzlich wurde geprüft, welche Anforderungen für den sicheren Betrieb der Kernfunktion (Zustellung von Push-Benachrichtigungen) nicht akut notwendig sind und ohne Beeinträchtigung von Funktion oder Sicherheit in eine spätere Ausbaustufe verschoben werden können. Die betroffenen Anforderungen wurden aus den fachlichen Abschnitten entfernt und mit Begründung in Abschnitt 5.12.7 gesammelt; keine sicherheitsrelevante Kernanforderung ist davon betroffen.
---

## 5.12.0 Begriffe, Akteure, Betriebsvarianten und Statusmodell

*Dieser Abschnitt ist nicht normativ.*

### Akteure

| Akteur | Rolle |
|---|---|
| ZETA Client Modul / SDK | In der FdV App integrierte Komponente. Registriert und verwaltet Pusher, Schlüssel und Channel-Konfiguration; verarbeitet und entschlüsselt empfangene Push-Nachrichten. |
| Notification Service | Fassade vor den Push Gateways. Nimmt Notification-Events des Resource Servers entgegen, verschlüsselt sie ggf., leitet sie an das Push Gateway weiter und verwaltet Push-Konfigurationen. |
| Notification Service DB | Persistenzschicht des Notification Service für Push-Konfigurationen, Pusher und Statusdaten. |
| ZETA HSM Proxy | Einheitliche Schnittstelle zum Hardware-Sicherheitsmodul (HSM) des Anbieters; stellt Encrypt/Decrypt-Operationen für Schlüssel-Wrapping bereit. |
| Resource Server (Fachdienst) | Erzeugt und versendet Notification-Events; fragt optional aktive Channels ab. |
| Push Gateway | Plattformübergreifende Zustellkomponente zwischen Notification Service und den herstellerspezifischen Push-Diensten (Apple APNs, Google FCM). |
| FdV App | App auf dem Endgerät des Nutzers; empfängt Push-Nachrichten und zeigt sie über das ZETA Client Modul an. |
| Betreiber | Anbieter des TI-2.0-Dienstes, der den Notification Service betreibt. |
| Authorization Server | Komponente des ZETA Guard; stellt Access Token für den Zugriff auf den Notification Service aus. |

### Betriebsvarianten

- **Variante A (mit VAU)**: Notification Service und Resource Server werden gemeinsam in einer Vertrauenswürdigen Ausführungsumgebung (VAU) betrieben. HSM-Anbindung sowie At-rest-Verschlüsselung und Pseudonymisierung sind aktiv (Abschnitt 5.12.2).
- **Variante B (ohne VAU)**: Betrieb ohne VAU. Die HSM-gestützte Verschlüsselung und Pseudonymisierung entfallen; der Schutz persistierter Daten erfolgt durch allgemeine betriebliche und organisatorische Maßnahmen des Betreibers.

### Kryptografische Begriffe (gelten für Variante A)

- **Data Encryption Key (DEK)**: In der VAU erzeugter symmetrischer Schlüssel zur Verschlüsselung persistierter Daten.
- **Key Encryption Key (KEK)**: Im HSM gehaltener Schlüssel, der den DEK und den Pseudonymisierungsschlüssel per Envelope-Verschlüsselung wrappt/entwrappt. Verlässt das HSM nicht im Klartext.
- **Pseudonym**: Schlüsselgebundener MAC über einen Nutzeridentifikator (KVNR oder Telematik-ID), deterministisch gebildet, sodass derselbe Identifikator stets dasselbe Pseudonym ergibt.

### Channel-Status

Ein Channel befindet sich je registriertem Gerät (Pusher/Pushkey) in einem der Zustände `enabled`, `disabled` oder `not_set`; `not_set` wird wie `disabled` behandelt. Ein Channel gilt für einen Nutzer als **aktiv**, sobald mindestens eines seiner registrierten Geräte den Channel auf `enabled` gesetzt hat (Aggregation).

### Terminalstatus einer Notification

- `accepted`: Versand an das Push Gateway ist erfolgt bzw. wird asynchron durchgeführt; ein dauerhafter Notification-Datensatz existiert.
- `no_active_channel`: Der Channel ist im Fachdienst zulässig, aber für den Nutzer auf keinem Gerät aktiv; es existiert kein dauerhafter Notification-Datensatz.

### Scopes des Access Token für das ZETA Client Modul

| Scope | Berechtigt ausschließlich zu |
|---|---|
| `notification.pusher.read` | `GET /pushers` |
| `notification.pusher.write` | `POST /pushers/set` |
| `notification.channel.read` | `GET /channels`, `GET /channels/{pushkey}` |
| `notification.channel.write` | `POST /channels/{pushkey}` |
| `notification.history.read` | `GET /history/*` (nur bei aktiviertem Feature Nachrichten-Historie) |

### Nachrichten-Historie

Optionales Fachdienst-Feature aus [gemF_PushNotification]. In dieser Neufassung als Ausbaustufe (Phase 2) zurückgestellt; siehe Abschnitt 5.12.7.

### Verschlüsselungspflichten aus [gemF_PushNotification]

Soweit der Notification Service verschlüsselt versendet, gelten die dort definierten Pflichten zur Schlüsselableitung (HKDF-SHA256, Ableitungsvektor yyyy-MM), zur AES/GCM-Verschlüsselung mit Base64-Kodierung, zum 1024-Byte-Padding, zur Einbettung des Verschlüsselungszeitpunkts, zum Löschen überholten Schlüsselmaterials nach jeder Ableitung sowie zur UTF-8-Kodierung des Nachrichteninhalts.

---

## 5.12.1 Betriebsvarianten und Geltungsbereich des HSM-Schutzes

### A_29957 – Wahl der Betriebsvariante

**Notification Service** MUSS in Variante A (mit VAU) oder Variante B (ohne VAU) betrieben werden.

### A_29957-01 – Umsetzung der HSM-Anbindung in Variante A

Wird Variante A betrieben, MUSS **Notification Service** die HSM-Anbindung sowie die At-rest-Verschlüsselung und Pseudonymisierung gemäß Abschnitt 5.12.2 umsetzen.

### A_29957-02 – Schutz persistierter Daten in Variante B

Wird Variante B betrieben, MUSS **Betreiber** den Schutz der persistierten Daten durch allgemeine betriebliche und organisatorische Maßnahmen sicherstellen.

---

## 5.12.2 Schlüssel- und Datenschutz in Variante A (VAU/HSM)

Dieser Abschnitt gilt ausschließlich für den Betrieb in Variante A.

### A_29958 – Schlüsselmaterial ausschließlich über den HSM Proxy

**Notification Service** MUSS sämtliches Schlüsselmaterial zur Verschlüsselung und Pseudonymisierung ausschließlich über den ZETA HSM Proxy durch das VAU-HSM schützen.

### A_29958-01 – KEK verlässt das HSM nicht im Klartext

Der KEK DARF das HSM NICHT im Klartext verlassen.

### A_29958-02 – DEK und Pseudonymisierungsschlüssel HSM-versiegelt persistiert

DEK und Pseudonymisierungsschlüssel MÜSSEN in der VAU erzeugt und ausschließlich HSM-KEK-versiegelt persistiert werden.

### A_29958-03 – Entwrappte Schlüssel nur flüchtig

Entwrappte Schlüssel DÜRFEN ausschließlich im flüchtigen Speicher der VAU-Instanz vorgehalten werden und DÜRFEN NICHT persistiert werden.

### A_29958-04 – Sicheres Verwerfen entwrappter Schlüssel

Entwrappte Schlüssel MÜSSEN bei Beendigung der VAU-Instanz sowie bei Schlüsselrotation sicher verworfen werden.

### A_29959 – Verschlüsselung von Pusher- und Statusdaten

**Notification Service** MUSS Pusher-Konfigurationen, Channel-/Geräte-Zuordnungen, Nachrichten-/Versandstatus sowie Push-Schlüsselmaterial vor der Persistierung at-rest verschlüsseln.

### A_29959-01 – Envelope-Verschlüsselung

Die Verschlüsselung nach A_29959 MUSS als Envelope-Verschlüsselung erfolgen: Der DEK wird durch den KEK über den ZETA HSM Proxy gewrappt bzw. entwrappt.

### A_29959-02 – Konformität mit gemSpec_Krypt

Die eingesetzten kryptografischen Verfahren, Schlüssellängen und Nutzungsgrenzen (einschließlich Nonce-/IV-Handhabung) MÜSSEN [gemSpec_Krypt] entsprechen.

### A_29959-03 – Massen-Ver-/Entschlüsselung ausschließlich in der VAU

Die Massen-Ver-/Entschlüsselung mit dem entwrappten DEK DARF ausschließlich innerhalb der VAU erfolgen.

### A_29960 – Pseudonymisierung von KVNR und Telematik-ID

**Notification Service** MUSS Nutzeridentifikatoren (KVNR, Telematik-ID) ausschließlich als Pseudonym persistieren und indizieren.

### A_29960-01 – Bildung des Pseudonyms

Das Pseudonym MUSS als schlüsselgebundener MAC über den Identifikator gebildet werden; das MAC-Verfahren und die Schlüssellänge MÜSSEN [gemSpec_Krypt] entsprechen.

### A_29960-02 – Pseudonymisierungsschlüssel HSM-versiegelt

Der Pseudonymisierungsschlüssel MUSS in der VAU erzeugt und ausschließlich HSM-versiegelt persistiert werden; die MAC-Berechnung MUSS mit dem entwrappten Schlüssel innerhalb der VAU erfolgen.

### A_29960-03 – Deterministische Pseudonymbildung

Die Pseudonymbildung MUSS deterministisch sein: Derselbe Identifikator MUSS stets dasselbe Pseudonym ergeben.

### A_29961 – Domänentrennung der Pseudonyme

**Notification Service** MUSS für KVNR und Telematik-ID unterschiedliche Ableitungsdomänen verwenden (getrenntes Domänen-Label oder getrennte Pseudonymisierungsschlüssel), sodass Pseudonyme nicht über verschiedene Identifikatortypen oder Dienste hinweg verkettet werden können.

### A_29962 – HSM-Zugriff nur durch attestierte VAU-Instanz

**Notification Service** MUSS sicherstellen, dass HSM-Proxy-Operationen ausschließlich durch eine attestierte, integre VAU-Instanz ausgelöst werden können.

### A_29962-01 – Keine Klartextdaten außerhalb der VAU-Vertrauensgrenze

Weder der DEK noch entschlüsselte Inhalte oder Klartext-Identifikatoren DÜRFEN die VAU-Vertrauensgrenze verlassen.

### A_29963 – Vier-Augen-Prinzip bei der KEK-Verwaltung

**Betreiber** MUSS das Einbringen und Verwalten des HSM-KEK ausschließlich im Vier-Augen-Prinzip zulassen.

### A_29963-01 – Unterstützung der Schlüsselrotation

**Notification Service** MUSS eine außerordentliche Schlüsselrotation (z. B. bei Verdacht auf Kompromittierung) für sämtliches eingesetztes Schlüsselmaterial (HSM-KEK, DEK bzw. Wrapping-Keys, Pseudonymisierungsschlüssel) ohne Betriebsunterbrechung der fachlichen Schnittstelle unterstützen.

### A_29963-02 – Entschlüsselbarkeit über die Rotation hinweg

Über eine Rotation hinweg MÜSSEN bereits persistierte Daten weiterhin entschlüsselbar bleiben. Hierzu MUSS je Datensatz die verwendete Schlüsselgeneration nachvollziehbar bleiben, und die vorherige Generation MUSS verfügbar gehalten werden, bis der Bestand vollständig auf die neue Generation überführt ist.

### A_29963-03 – Rotation des Pseudonymisierungsschlüssels ohne Lookup-Bruch

Eine Rotation des Pseudonymisierungsschlüssels MUSS entweder mit einer vollständigen Re-Pseudonymisierung des Bestands einhergehen oder die vorherige Schlüsselgeneration für Lookups vorhalten, bis die Re-Pseudonymisierung abgeschlossen ist.

### A_29963-04 – Verwerfen des entwrappten Schlüssels nach Rotation

Der entwrappte DEK bzw. Pseudonymisierungsschlüssel MUSS bei einer Rotation sicher aus dem VAU-Cache verworfen werden.

---

## 5.12.3 Schnittstelle zum Resource Server

Der Resource Server fragt optional aktive Channels ab und übergibt Notification-Events an den Notification Service, der sie an das Push Gateway weiterleitet.

### A_29964 – Realisierung der Resource-Server-Schnittstelle

**Notification Service** MUSS gegenüber dem Resource Server mindestens die Operationen `getActiveChannels` (`GET /users/{userId}/channels`) und `submitNotification` (`POST /notifications`) gemäß der referenzierten OpenAPI-Spezifikation anbieten.

### A_29965 – Asynchrone Bestätigung

**Notification Service** MUSS eine eingehende Notification nach erfolgreicher Validierung mit HTTP-Statuscode 202 und einer notification_id bestätigen.

### A_29965-01 – Asynchrone Zustellung

**Notification Service** MUSS die Zustellung an das Push Gateway asynchron durchführen.

### A_29965-02 (Adressat: Resource Server) – Keine Fehlinterpretation der 202-Antwort

**Resource Server** DARF NICHT die 202-Antwort als Zustellbestätigung an das Endgerät interpretieren.

### A_29966 – Unbekannter Nutzer

Existiert für den adressierten Identifikator kein registriertes Gerät, MUSS **Notification Service** den Nutzer als unbekannt behandeln und die Anfrage mit HTTP-Statuscode 404 (USER_NOT_FOUND) beantworten.

### A_29966-01 – Synchrone Prüfung der Channel-Aktivität

**Notification Service** MUSS bei Annahme einer Notification synchron prüfen, ob der adressierte Channel für den Nutzer aktiv ist.

### A_29966-02 – Terminaler Status bei inaktivem Channel

Ist der Channel für keines der registrierten Geräte des Nutzers aktiv, MUSS **Notification Service** die Notification nicht an das Push Gateway weiterleiten und den Status `no_active_channel` bereits in der 202-Antwort zurückgeben.

### A_29966-03 – Kein dauerhafter Datensatz bei terminalem Status

Im Fall von A_29966-02 DARF **Notification Service** keinen dauerhaften Notification-Datensatz anlegen; eine zurückgegebene notification_id ist rein transient.

### A_29966-04 – Dauerhafter Datensatz nur bei tatsächlichem Versand

Ein dauerhafter Notification-Datensatz DARF ausschließlich angelegt werden, wenn tatsächlich ein Versand an das Push Gateway erfolgt (Status `accepted`).

### A_29966-05 – Aggregation der Channel-Aktivität über Geräte

**Notification Service** MUSS einen Channel als für den Nutzer aktiv behandeln, sobald mindestens eines der registrierten Geräte des Nutzers diesen Channel auf `enabled` gesetzt hat, und den Versand an jedes Gerät mit `enabled`-Status ausführen.

### A_29967 – Nutzeridentifikation über Identifikatorwert und Typ

**Notification Service** MUSS den Nutzer ausschließlich über die Kombination aus Identifikatorwert und deklariertem Typ (`kvnr` oder `telematik-id`) auflösen und die Werte gegen die definierten Formate validieren.

### A_29968 – Konfigurierbarkeit der Verschlüsselung je Instanz

Die Verschlüsselung der Nachrichten-Payload MUSS ein pro ZETA-Guard-Instanz konfigurierbares Feature sein.

### A_29968-01 – Verschlüsselungsentscheidung ausschließlich aus eigener Konfiguration

**Notification Service** MUSS die Entscheidung, ob und wie eine Notification-Payload verschlüsselt wird, ausschließlich aus der eigenen Instanzkonfiguration ableiten.

### A_29968-02 (Adressat: Resource Server) – Keine Verschlüsselungsanweisung im Request

**Resource Server** DARF NICHT im Request eine Verschlüsselungsanweisung übergeben.

### A_29968-03 – Keine Auswertung einer Verschlüsselungsanweisung

**Notification Service** DARF NICHT eine vom Resource Server übergebene Verschlüsselungsanweisung auswerten.

### A_29968-04 – Zwingende Verschlüsselung bei entsprechender Fachdienst-Spezifikation

Schreibt die Spezifikation des Fachdienstes die Verschlüsselung zwingend vor, MUSS das Verschlüsselungs-Feature in der Instanz aktiv sein; **Betreiber** DARF es NICHT deaktivieren.

### A_29968-05 – Optionale Verschlüsselung bei entsprechender Fachdienst-Spezifikation

Lässt die Spezifikation des Fachdienstes die Verschlüsselung als optional zu, DARF **Betreiber** sie je Instanz aktivieren oder deaktivieren.

### A_29969 (Adressat: Resource Server) – Ausschließliche Nutzung der Notification-Service-Schnittstelle

**Resource Server** MUSS zum Versand von Push Notifications und zur Channel-Abfrage ausschließlich die Schnittstelle des Notification Service verwenden.

### A_29969-01 (Adressat: Resource Server) – PII-freies reference-Feld

**Resource Server** MUSS das reference-Feld, sofern genutzt, als unverschlüsselten Identifier ohne personenbezogene Daten (keine KVNR, kein Name, kein Nachrichteninhalt) befüllen.

### A_29970 – Übernahme der Schlüsselableitungs- und Verschlüsselungspflichten

Soweit **Notification Service** gemäß Konfiguration verschlüsselt versendet, MUSS er die Verschlüsselungs- und Schlüsselableitungspflichten aus [gemF_PushNotification] übernehmen (siehe Abschnitt 5.12.0: HKDF-Ableitung, AES/GCM-Verschlüsselung, Padding, Zeitstempel-Einbettung, Löschung überholten Schlüsselmaterials, UTF-8-Kodierung).

### A_29971 – Übernahme der Versand- und Pusher-Pflege-Pflichten

**Notification Service** MUSS beim Weiterleiten an das Push Gateway die Versandpflichten aus [gemF_PushNotification] übernehmen: Exponential-Backoff bei Nichtverfügbarkeit, Bereinigung ungültig gewordener Pusher, Versand ausschließlich an die registrierte URL.

### A_29971-01 – Endpunktwahl bei unverschlüsseltem Versand

Für unverschlüsselten Versand MUSS **Notification Service** den Endpunkt `POST /notify` (Einzelnachricht) oder `POST /notify/batch` (Stapel) verwenden.

### A_29971-02 – Endpunktwahl bei verschlüsseltem Versand

Für verschlüsselten Versand MUSS **Notification Service** ausschließlich den Endpunkt `POST /notifyEncrypted/batch` verwenden, auch für eine einzelne Nachricht.

### A_29971-03 – Verarbeitung abgelehnter Pushkeys

**Notification Service** MUSS vom Push Gateway zurückgemeldete, abgelehnte Pushkeys auswerten, den Versand an diese einstellen und die zugehörigen Pusher entfernen, auch wenn der abgelehnte Pushkey aus einer früheren Notification stammt.

---

## 5.12.4 Schnittstelle zum ZETA Client Modul / SDK

Das ZETA Client Modul registriert und verwaltet Pusher und Channel-Konfigurationen. Ein dem Notification Service vorgelagerter Policy Enforcement Point kann die Token-Prüfungen dieses Abschnitts anstelle des Notification Service selbst durchführen; die objektbezogene Nutzerbindung (A_29978) verbleibt in jedem Fall beim Notification Service.

### A_29972 – Realisierung der Client-Modul-Schnittstelle

**Notification Service** MUSS für das ZETA Client Modul mindestens die Endpunkte zur Pusher-Registrierung/-Verwaltung und zur Channel-Konfiguration gemäß [gemF_PushNotification] bereitstellen.

### A_29972-01 – Geräteindividuelle Channel-Konfiguration

Die Channel-Konfiguration MUSS geräteindividuell je Pusher gehalten werden.

### A_29972-02 – Nutzerbezogene Sicht als Aggregation

**Notification Service** MUSS eine nutzerbezogene Sicht auf Channels als Aggregation über alle Geräte-Konfigurationen des Nutzers ableiten und DARF sie NICHT als eigenständige, von der geräteindividuellen Konfiguration abweichende Channel-Haltung implementieren.

*Das Feature Nachrichten-Historie ist für die Kernfunktion (Zustellung von Push-Benachrichtigungen) nicht erforderlich und wurde als Ausbaustufe nach Abschnitt 5.12.7 zurückgestellt.*

### A_29975 – Authentisierung über Access Token

**Notification Service** MUSS Aufrufe des ZETA Client Moduls über ein vom Authorization Server ausgestelltes, DPoP-gebundenes Access Token authentisieren.

### A_29975-01 – Ablehnung ohne gültiges Token

**Notification Service** MUSS Aufrufe ohne gültiges Access Token mit HTTP-Statuscode 401 ablehnen.

### A_29976 – Prüfung von Signatur, Gültigkeit, Aussteller und Zielgruppe

**Notification Service** MUSS bei jedem Aufruf des ZETA Client Moduls Signatur, Gültigkeitszeitraum, Aussteller sowie die Zielgruppe (Zielgruppe MUSS der eigenen Resource-Kennung des Notification Service entsprechen) des Access Token prüfen und bei fehlender oder fehlgeschlagener Prüfung mit 401 oder 403 ablehnen.

### A_29976-01 – Prüfung der erforderlichen Scopes

**Notification Service** MUSS die für die angefragte Operation erforderlichen Scopes des Access Token prüfen und die Operation bei fehlendem Scope mit 403 ablehnen.

### A_29977 – Sender-Constrained Token

**Notification Service** MUSS sicherstellen, dass das Access Token sender-constrained ist, und ein Token ohne gültigen Besitznachweis (Proof-of-Possession) ablehnen.

### A_29978 – Bindung von Operationen an den authentisierten Nutzer

**Notification Service** MUSS Schreib-/Leseoperationen des ZETA Client Moduls ausschließlich auf die im Access Token authentisierte Nutzeridentität beziehen und Operationen auf Pusher/Daten anderer Nutzer mit HTTP-Statuscode 403 ablehnen.

### A_29979 – Dienstspezifisches Access Token

Der Zugriff des ZETA Client Moduls auf den Notification Service MUSS mit einem ausschließlich für den Notification Service ausgestellten Access Token erfolgen.

### A_29979-01 – Protected-Resource-Discovery-Dokument

**Notification Service** MUSS ein eigenes Protected-Resource-Discovery-Dokument bereitstellen, das die eigene Resource-Kennung, die zuständigen Authorization Server, die unterstützten Scopes sowie die Pflicht zur DPoP-Bindung deklariert.

### A_29979-02 (Adressat: ZETA Client Modul) – Gezielte Resource-Anforderung

**ZETA Client Modul** MUSS das Access Token beim Token Exchange gezielt für die Resource-Kennung des Notification Service anfordern.

### A_29979-03 – Durchsetzung der Scope-Zuordnung

**Notification Service** MUSS je Operation ausschließlich den in Abschnitt 5.12.0 zugeordneten Scope akzeptieren.

### A_29979-04 (Adressat: Authorization Server) – Beschränkung der ausgestellten Scopes

**Authorization Server** DARF für die Resource-Kennung des Notification Service ausschließlich die in Abschnitt 5.12.0 gelisteten Scopes ausstellen.

---

## 5.12.5 Transportsicherheit und Mandantentrennung

### A_29980 – mTLS-Authentisierung des Resource Servers

**Notification Service** MUSS alle Aufrufe des Resource Servers über gegenseitiges TLS mit einem technischen Nutzer authentisieren, das Client-Zertifikat prüfen und Verbindungen mit fehlendem oder ungültigem Zertifikat mit HTTP-Statuscode 401 ablehnen.

### A_29981 – Zertifikatsverwaltung für die mTLS-Verbindung

**Betreiber** MUSS die für die mTLS-Authentisierung zwischen Notification Service und Resource Server verwendeten Zertifikate gemeinsam mit dem Betreiber des Resource Servers ausstellen, verwalten und die Sperrung bzw. Rotation kompromittierter Zertifikate ermöglichen.

### A_29982 – mTLS mit EV-Zertifikat zum Push Gateway

**Notification Service** MUSS die Verbindung zum Push Gateway über mTLS mit einem Extended-Validation-Zertifikat gemäß den Anforderungen des CA/Browser Forums absichern und ein entsprechendes Zertifikat des Push Gateway prüfen.

### A_29983 – Mandantentrennung nach Fachdienst

**Notification Service** MUSS nach erfolgreicher Authentisierung sicherstellen, dass ein Resource Server ausschließlich Notifications für die ihm zugeordneten Fachdienste/Channels versenden und ausschließlich deren Channel-/Geräteinformationen abfragen kann, und nicht autorisierte Zugriffe mit HTTP-Statuscode 403 ablehnen.

### A_29991 – TLS-/Krypto-Konformität

**Notification Service** MUSS für alle TLS-/mTLS-Verbindungen die in [gemSpec_Krypt] zugelassenen TLS-Versionen, Cipher-Suiten und Schlüssellängen verwenden.

---

## 5.12.6 Betriebs- und Datenschutz-Anforderungen

### A_29984 – Keine personenbezogenen Klartextdaten Richtung Push Gateway

**Notification Service** DARF NICHT personenbezogene Daten (insbesondere KVNR, Telematik-ID, Name) oder unverschlüsselte Nachrichteninhalte an das Push Gateway übermitteln; die Adressierung erfolgt ausschließlich über Pushkey/App-ID.

### A_29985 – Registry zulässiger Channels

**Notification Service** MUSS eine Konfiguration/Registry der je Fachdienst zulässigen Channels führen.

### A_29985-01 – Ablehnung nicht zugeordneter Channels

**Notification Service** MUSS eine Notification für einen dem Fachdienst nicht zugeordneten Channel mit HTTP-Statuscode 403 zurückweisen.

### A_29985-02 – Ablehnung unbekannter Channels

**Notification Service** MUSS eine Notification für einen im Fachdienst zulässigen, aber nicht in der Channel-Registry geführten Channel mit HTTP-Statuscode 422 (UNKNOWN_CHANNEL) zurückweisen.

### A_29986 – Eingabevalidierung

**Notification Service** MUSS alle eingehenden Requests gegen das in der OpenAPI definierte Schema validieren und ungültige Requests mit HTTP-Statuscode 400 ablehnen.

### A_29987 – Rate-Limiting

**Notification Service** MUSS Maßnahmen gegen Überlast implementieren (Rate-Limiting) und bei Überschreitung mit HTTP-Statuscode 429 und einem Retry-After-Header antworten.

### A_29987-01 – Antwort bei Nichtverfügbarkeit

**Notification Service** MUSS bei temporärer Nichtverfügbarkeit mit HTTP-Statuscode 503 und einem Retry-After-Header antworten.

### A_29987-02 – Begrenzung von Payload- und Stapelgrößen

**Notification Service** MUSS Obergrenzen für Payload- und Stapelgrößen durchsetzen und eine zu große Notification mit HTTP-Statuscode 413 (PAYLOAD_TOO_LARGE) zurückweisen.

### A_29988 – Kurze Aufbewahrungsfrist für Statusdaten

**Notification Service** MUSS Notification-Status- und Verarbeitungsdaten nur für eine kurze, definierte Aufbewahrungsfrist speichern und nach deren Ablauf löschen.

### A_29989 – Löschung bei Deregistrierung

**Notification Service** MUSS bei Deregistrierung eines Pushers die zugehörige Push-Konfiguration sowie das gespeicherte kryptografische Schlüsselmaterial löschen.

### A_29990 – Protokollierung ohne Klartext-PII

**Notification Service** MUSS sicherheitsrelevante Ereignisse sowie Betriebs-/Telemetriedaten protokollieren, ohne Klartext-Identifikatoren oder entschlüsselte Nachrichteninhalte zu protokollieren; Identifikatoren sind ausschließlich pseudonymisiert zu protokollieren.

### A_29990-01 – Freiheit von Klartext-PII bei Telemetrie-Übermittlung

Eine Übermittlung an einen Telemetrie-/Monitoring-Dienst MUSS ebenfalls frei von Klartext-personenbezogenen Daten erfolgen.

*Die idempotente Behandlung von Retransmissionen ist für die Kernfunktion (Zustellung von Push-Benachrichtigungen) nicht erforderlich und wurde als Ausbaustufe nach Abschnitt 5.12.7 zurückgestellt.*

---

## 5.12.7 Zurückgestellte Anforderungen (Ausbaustufe/Phase 2)

Dieser Abschnitt dokumentiert Anforderungen, die für den sicheren Betrieb der Kernfunktion des Notification Service — die Zustellung von Push-Benachrichtigungen vom Resource Server an das Endgerät — nicht akut notwendig sind. Sie wurden aus den fachlichen Abschnitten entfernt und können ohne Beeinträchtigung von Funktion oder Sicherheit in einer späteren Ausbaustufe ergänzt werden. Keine der zurückgestellten Anforderungen ist Voraussetzung für Authentisierung, Autorisierung, Transportschutz, Verschlüsselung, Pseudonymisierung oder Protokollierung der übrigen Kapitel.

### Feature Nachrichten-Historie

**Zurückgestellt**: A_29973, A_29973-01, A_29973-02, A_29973-03, A_29974, A_29974-01.

**Begründung**: [gemF_PushNotification] führt die Nachrichten-Historie ausdrücklich als *optionales* Fachdienst-Feature. Die vorherige Neufassung hatte daraus eine verpflichtend zu *implementierende* (wenn auch vom Betreiber deaktivierbare) Funktion gemacht — das verlangt eigene Endpunkte, eine zusätzliche Persistenzschicht mit denselben Verschlüsselungspflichten wie die Kerndaten sowie eine PII-freie Rekonstruktionslogik, ohne dass davon die Zustellung einer einzelnen Push-Benachrichtigung abhängt. Die Kernfunktion (Push-Zustellung, Abschnitte 5.12.3–5.12.5) bleibt ohne dieses Feature vollständig funktions- und sicherheitsfähig.

**Empfehlung**: Bei Bedarf als optionale, vom Betreiber je Fachdienst zu implementierende Erweiterung nachrüsten; die zurückgestellten Anforderungen können dazu unverändert übernommen werden.

### Idempotente Behandlung von Retransmissionen

**Zurückgestellt**: A_29992, A_29992-01.

**Begründung**: Die Basisanforderung war bereits als SOLL formuliert. Ohne Idempotenzbehandlung kann eine erneute Übermittlung durch den Resource Server im ungünstigsten Fall zu einer doppelt zugestellten Push-Benachrichtigung führen — eine Komfort-/Qualitätseinbuße für den Nutzer, keine Verletzung von Vertraulichkeit, Integrität oder Verfügbarkeit der übermittelten Daten.

**Empfehlung**: Bei Bedarf ergänzen, sobald Resource-Server-seitige Retry-Mechanismen produktiv genutzt werden.

### Regelmäßige, geplante Schlüsselrotation

**Geändert (nicht vollständig gestrichen)**: A_29963-02 (vormals: MUSS sowohl regulär als auch außerordentlich rotieren) wurde auf die außerordentliche Rotation (bei Verdacht auf Kompromittierung) reduziert; die zusätzliche Pflicht zu einer *regelmäßigen, geplanten* Rotationscadence wurde zurückgestellt.

**Begründung**: Eine Incident-getriebene Rotationsfähigkeit ist eine Kernanforderung an die Schlüsselverwaltung und bleibt uneingeschränkt in Kraft (siehe A_29963-01). Eine zusätzliche, proaktive Rotation nach festem Zeitplan ist eine Härtungsmaßnahme (Defense-in-Depth), die das Schadensfenster einer noch unentdeckten Kompromittierung verkürzt, aber keine Voraussetzung dafür ist, dass der Notification Service sicher betrieben werden kann, solange die außerordentliche Rotation funktionsfähig ist.

**Empfehlung**: Regelmäßige Rotationscadence (z. B. jährlich) als betriebliche Härtungsmaßnahme nachrüsten, sobald der Rotationsmechanismus produktiv erprobt ist.

### Namensschema der Schlüsselkennung

**Zurückgestellt**: Das Namensschema `[Komponente]-[Zweck]-[Algorithmus]-[Version]` für die key_id des KEK (vormals A_29963-01).

**Begründung**: Reine Betriebs-/Namenskonvention zur besseren Nachvollziehbarkeit im Schlüsselmanagement; sie beeinflusst weder die Vertraulichkeit noch die Verfügbarkeit des Schlüssels selbst. Eine abweichende, aber intern konsistente Benennung gefährdet die Sicherheit nicht.

**Empfehlung**: Bei Einführung eines dokumentierten Schlüsselmanagement-Prozesses (spätestens vor dem ersten Rotationsvorgang) verbindlich nachrüsten.

