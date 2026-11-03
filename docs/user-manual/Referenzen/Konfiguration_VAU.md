# Konfiguration einer VAU mit verschlüsselter Datenbank

Für den Betrieb von ZETA-Guard in einer
[VAU](https://en.wikipedia.org/wiki/Trusted_execution_environment)
(Vertrauenswürdige Ausführungsumgebung) können Sie das Plugin
„Spree Integrity Provider“ (SIP) einsetzen. Es verschlüsselt die
sicherheitsrelevanten Spalten der Datenbank, also diejenigen, die vertrauliche
Informationen enthalten können. Zusätzlich schützt es die Datenbank auf Wunsch
gegen Manipulation: Das System erkennt manipulierte Daten dann unmittelbar und
reagiert mit einer Fehlermeldung bzw. weiteren Maßnahmen.

## Abhängigkeiten

Das SIP setzt ein konfiguriertes
[HSM](Referenz_des_Helm_Charts.md#hsm-konfiguration) voraus. Es verwendet einen
dort vorliegenden „Key Encryption Key“ (KEK), um das eigentliche
Schlüsselmaterial (Keychain) zu sichern, mit dem es die Daten verschlüsselt.

## Aktivierung

**Achtung:** Sie können das SIP nur beim allerersten Start von ZETA-Guard
aktivieren. Nachträglich lässt es sich weder ein- noch ausschalten.

Das SIP liest seine Konfiguration aus Umgebungsvariablen. Im Helm-Chart setzen
Sie diese über die Values unter `authserver.dbEnc`, siehe
[Helm-Chart-Referenz](Referenz_des_Helm_Charts.md#spree-integrity-provider-vau).
Die hier genannten Standardwerte gelten, wenn eine Variable gar nicht gesetzt
ist. Das Helm-Chart setzt die meisten Variablen aber explizit, und dann gelten
die Standardwerte des Helm-Charts.

- `SPREE_INTEGRITY_PROVIDER_ENABLED`: Aktivierung des Spree Integrity Providers
  (Standardwert: `false`)
- `SPREE_ENABLE_INTEGRITY_CHECK`: Aktivierung von Integritätsprüfungen und
  Verschlüsselung (Standardwert: `false`)
- `SPREE_ENABLE_COLUMN_ENCRYPTION`: Aktivierung der Spaltenverschlüsselung;
  wirkt nur, wenn das SIP insgesamt aktiviert ist (Standardwert: `true`)
- `SPREE_ENABLE_INTEGRITY_ROW_CHECK`: Aktivierung von Integritätsprüfungen auf
  Zeilenebene; wirkt nur, wenn Integritätsprüfungen aktiviert sind
  (Standardwert: `true`)
- `SPREE_ENABLE_INTEGRITY_TABLE_CHECK`: Aktivierung von Integritätsprüfungen auf
  Tabellenebene; wirkt nur zusammen mit den Prüfungen auf Zeilenebene
  (Standardwert: `true`)

Folgende Einstellungen lassen sich auch nachträglich noch ändern:

- `SPREE_SHUTDOWN_ON_ERROR`: Automatisches Herunterfahren des Containers bei
  einer Integritätsverletzung (Standardwert: `false`)
- `SPREE_LOCKDOWN_ON_ERROR`: Übergang in einen internen Fehlerzustand bei einer
  Integritätsverletzung, in dem der Authserver weitere Anfragen abweist
  (Standardwert: `true`)
- `SPREE_SCANNER_INTERVAL`: Intervall der periodischen Integritätsprüfung im
  Format [ISO 8601](https://de.wikipedia.org/wiki/ISO_8601)
  (Standardwert: `PT20S`)
- `SPREE_SCANNER_DELAY`: Wartezeit nach dem Start bis zur ersten periodischen
  Integritätsprüfung (Standardwert: `PT5M`)
- `SPREE_PERIODIC_ROW_CHECK`: Prüft die Integrität _aller_ Zeilen zusätzlich
  auch periodisch, anstatt nur bei Verwendung; erhöht Sicherheit zulasten der
  Performance (Standardwert: `true`; Standardwert im Helm-Chart: `false`)

## Keychains

Die Schlüssel für Verschlüsselung und Integritätsprüfsummen liegen in einer
Keychain. Die Keychain ist mit einem Schlüssel aus dem HSM (KEK) verschlüsselt.
Das SIP kennt bis zu drei Keychains gleichzeitig: die aktive (current), eine
angekündigte (future) und eine abgelöste (previous). Die future- und die
previous-Keychain benötigen Sie nur während einer
[Schlüsselrotation](../Anleitungen/Wie_Sie_die_Schlüssel_der_VAU-Datenbank_rotieren.md).

Jede Keychain stellen Sie entweder als Datei oder direkt über
Umgebungsvariablen bereit:

| current                 | future                         | previous                         | Bedeutung                                                                                                |
|-------------------------|--------------------------------|----------------------------------|----------------------------------------------------------------------------------------------------------|
| `SPREE_KEYCHAIN_FILE`   | `SPREE_FUTURE_KEYCHAIN_FILE`   | `SPREE_PREVIOUS_KEYCHAIN_FILE`   | Pfad zur Keychain-Datei, wie sie der Keychain-Generator erzeugt. Hat Vorrang vor den Variablen darunter. |
| `SPREE_KEYCHAIN_DATA`   | `SPREE_FUTURE_KEYCHAIN_DATA`   | `SPREE_PREVIOUS_KEYCHAIN_DATA`   | Verschlüsselte Keychain (Base64)                                                                         |
| `SPREE_KEYCHAIN_KEY`    | `SPREE_FUTURE_KEYCHAIN_KEY`    | `SPREE_PREVIOUS_KEYCHAIN_KEY`    | Mit dem KEK verschlüsselter Keychain-Schlüssel (Base64)                                                  |
| `SPREE_KEYCHAIN_KEK_ID` | `SPREE_FUTURE_KEYCHAIN_KEK_ID` | `SPREE_PREVIOUS_KEYCHAIN_KEK_ID` | ID des KEK im HSM                                                                                        |

Enthält eine Keychain-Datei keine KEK-ID, verwendet das SIP `HSM_PROXY_KEK_ID`.
Dasselbe gilt, wenn Sie eine Keychain über Umgebungsvariablen bereitstellen und
die zugehörige `…_KEK_ID` nicht setzen. Keychain-Dateien aus dem
Keychain-Generator ab Version 2.0.8 enthalten die KEK-ID.

Den KEK können Sie nicht unabhängig von der Keychain austauschen. Ein neuer KEK
erfordert immer eine neue Keychain und damit eine Schlüsselrotation.

## Umschlüsselung

Nach einem Keychain-Wechsel muss das SIP alle verschlüsselten Spalten und
Integritätsprüfsummen auf die neue Keychain umstellen (Crypto Update):

- `SPREE_AUTOMATIC_CRYPTO_UPDATE`: Automatischer Start der Umschlüsselung, wenn
  sich die aktive Keychain geändert hat und die bisherige als previous-Keychain
  konfiguriert ist. Pods mit future-Keychain starten keine Umschlüsselung. Ist
  das Flag ausgeschaltet, müssen Sie die Umschlüsselung über die Admin-API
  starten (Standardwert: `true`; Standardwert im Helm-Chart: `false`)
- `SPREE_CRYPTO_UPDATE_TIMEOUT`: Zeit, nach der eine Umschlüsselungsaufgabe
  eines ausgefallenen Pods wieder freigegeben wird (Standardwert: `PT10M`)

Über die Admin-API unter `/auth/admin/realms/{realm}/crypto-update` können Sie
die Umschlüsselung starten (`POST`), die offenen Aufgaben abfragen (`GET`) und
offene Aufgaben verwerfen (`DELETE`). Dafür ist die Berechtigung `manage-realm`
erforderlich. Die Admin-Schnittstelle ist standardmäßig nur über HTTP
erreichbar und muss in einer VAU je nach Produkttyp zusätzlich abgesichert
werden. Den Ablauf beschreibt
[Wie Sie die Schlüssel der VAU-Datenbank rotieren](../Anleitungen/Wie_Sie_die_Schlüssel_der_VAU-Datenbank_rotieren.md#admin-api-für-die-umschlüsselung).
