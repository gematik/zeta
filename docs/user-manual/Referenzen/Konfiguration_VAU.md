# Konfiguration einer VAU mit verschlüsselter Datenbank

Für den Betrieb von ZETA-Guard in einer
[VAU](https://en.wikipedia.org/wiki/Trusted_execution_environment)
(Vertrauenswürdige Ausführungsumgebung) können Sie das Plugin
„Spree Integrity Provider“ (SIP) einsetzen. Es verschlüsselt die
sicherheitsrelevanten Spalten der Datenbank, also diejenigen, die vertrauliche
Informationen enthalten können. Zusätzlich schützt es die Datenbank auf Wunsch
gegen Manipulation: Das System erkennt manipulierte Daten dann unmittelbar und
zeigt sie an.

## Abhängigkeiten

Das SIP setzt ein konfiguriertes
[HSM](Referenz_des_Helm_Charts.md#hsm-konfiguration) voraus. Von dort bezieht es
das Schlüsselmaterial, mit dem es die Daten verschlüsselt.

## Aktivierung

**Achtung:** Sie können das SIP nur beim allerersten Start von ZETA-Guard
aktivieren. Nachträglich lässt es sich weder ein- noch ausschalten.

Konfigurieren Sie das SIP über die folgenden Umgebungsvariablen im
[Helm-Chart](Referenz_des_Helm_Charts.md#spree-integrity-provider-vau):

- `SPREE_INTEGRITY_PROVIDER_ENABLED`: Aktivierung des Spree Integrity Providers
  (Standardwert: `false`)
- `SPREE_ENABLE_INTEGRITY_CHECK`: Aktivierung von Integritätsprüfungen und
  Verschlüsselung (Standardwert: `false`)
- `SPREE_ENABLE_COLUMN_ENCRYPTION`: Aktivierung der Spaltenverschlüsselung;
  wirkt nur, wenn das SIP insgesamt aktiviert ist (Standardwert: `true`)
- `SPREE_ENABLE_INTEGRITY_ROW_CHECK`: Aktivierung von Integritätsprüfungen auf
  Zeilenebene (Standardwert: `true`)
- `SPREE_ENABLE_INTEGRITY_TABLE_CHECK`: Aktivierung von Integritätsprüfungen auf
  Tabellenebene (Standardwert: `false`)
- `SPREE_SHUTDOWN_ON_ERROR`: Automatisches Herunterfahren des Containers bei
  einer Integritätsverletzung (Standardwert: `false`)
- `SPREE_LOCKDOWN_ON_ERROR`: Übergang in einen internen Fehlerzustand bei einer
  Integritätsverletzung, in dem der Authserver weitere Anfragen abweist
  (Standardwert: `false`)
- `SPREE_SCANNER_INTERVAL`: Intervall der periodischen Integritätsprüfung im
  Format [ISO 8601](https://de.wikipedia.org/wiki/ISO_8601)
  (Standardwert: `PT20S`)
