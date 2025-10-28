# ZETA Guard Integrations-Anleitung

## Inhalt

- **Zulassungsbedingungen**
- **Auswirkungen von Changes an ZETA-Guard**
  - Wann Neuzulassung
  - Wann betrieblicher Change
  - Wann Hotfix
  - Bedingungen für Changes an ZETA-Guard
- **Testen der Integration**
  - Ugos Begriff
- Fehlerbehebung und Support
- **Einsaztszenarien**
  - Geo-Redundanz/Multi-Cluster Betrieb
  - Betrieb in einer VAU
  - Konfiguration
    - TLS
    - Optionale Komponenten
      - ZETA/ASL
      - Ingress
      - PDP DB
      - Service Mesh
      - Argo CD
    - Telemetriedaten Erfassung
    - HSM Anbindung
- **Registrierung der Instanz**
  - Bei gematik registrieren (inkl. Federation Master)
  - Audiences
  - Issuer für Zugriff auf Telemetrtiedaten-Empfänger und SIEM der gematik
- Lokaler Cache der Artifact Registry
  - Container Images
  - PIP und PAP Daten
  - Konfigurationsdaten (TSL, TPM Hersteller-CAs, roots.json)
