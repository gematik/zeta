# Konfiguration einer VAU mit verschlüsselter Datenbank

Zum Betrieb einer einer VAU unterstützt 𝛇-Guard die Verschlüsselung wichtiger Spalten in der Datenbank.
Außerdem kann die Datenbank integritätsgeschützt werden, d.h. das manipulierte Daten direkt aufgedeckt werden.
Dazu muss das "Spree Integrity provider plugin" aktiviert und konfiguriert werden.

## Aktivierung

Um dieses Feature zu aktivieren können folgende Umgebungsvariablen im [Helm-Chart](Referenz_des_Helm_Charts.md#spree-integrity-provider) genutzt werden:

- `SPREE_INTEGRITY_PROVIDER_ENABLED`: Aktivierung des Spree integrity providers (Standardwert: "false")
- `SPREE_ENABLE_INTEGRITY_CHECK`: Aktivierung von Integritätsprüfungen und Verschlüsselung (Standardwert: "false")
- `SPREE_ENABLE_INTEGRITY_ROW_CHECK`: Aktivierung von Integritätsprüfungen auf Zeilenebene (Standardwert: "true")
- `SPREE_ENABLE_INTEGRITY_TABLE_CHECK`: Aktivierung von Integritätsprüfungen auf Tabellenebene (Standardwert: "false")
- `SPREE_ENABLE_COLUMN_ENCRYPTION`: Aktivierung der Spaltenverschlüsselung (Standardwert: "true")
- `SPREE_SHUTDOWN_ON_ERROR`: Automatisches Herunterfahren des Containers bei einer Integritätsverletzung (Standardwert: "false")

## Abhängigkeiten

Um dieses Feature zu aktivieren muss außerdem [HSM](Referenz_des_Helm_Charts.md#hsm-konfiguration) konfiguriert sein.
