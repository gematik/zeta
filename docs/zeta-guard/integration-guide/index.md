# ZETA Guard Integrations-Anleitung

## Inhalt

- **Registrierung der Instanz**
  - Bei gematik registrieren (inkl. Federation Master)
  - Audiences
  - Issuer für Zugriff auf Telemetrtiedaten-Empfänger und SIEM der gematik
- **Zulassungsbedingungen**
  - Erstzulassung (was liefert Projekt ZETA SiGu, Produkt-Gutachten, Testbericht ZETA-Guard, SBOM, Report öber Sicherheitslücken)
- **Updates und Upgrades an ZETA-Guard**
  - Vorgehen bei Updates/Upgrades
  - Testen nach Updates/Upgrades
  - Wann Neuzulassung
  - Wann betrieblicher Change
  - Wann Hotfix
  - Bedingungen für Changes an ZETA-Guard
- **Testen der Integration**
  - Generalprobe
- Fehlerbehebung und Support
- **Einsaztszenarien**
  - Geo-Redundanz/Multi-Cluster Betrieb
  - Betrieb in einer VAU
  - Konfiguration
    - TLS
    - Optionale Komponenten
      - ZETA/ASL (Komp-PKI Zertifikat; Beantragung und Konfiguration)
      - Ingress
      - PDP DB
      - Service Mesh
      - Argo CD
    - Telemetriedaten Erfassung
    - HSM Anbindung
    - Mehrere Resource Server hinter einem ZETA Guard
- Lokaler Cache der Artifact Registry
  - Container Images
  - PIP und PAP Daten
  - Konfigurationsdaten (TSL, TPM Hersteller-CAs, roots.json)
- Tests der gematik
  - CI Prozess
  - Test in der gcloud Umgebung
  - Openshift-Konformitätstest
  - Penetrationstest
  - Performance-Test
  - Load-Test
  - Sonstige Tests

## Einführung

In dieser Anleitung werden die Rahmenbedingungen, Szenarien und Schritte für die Integration von ZETA Guard in die IT-Infrastruktur von TI 2.0 Dienst-Anbietern beschrieben.



## Registrierung der Instanz

Die Registrierung Ihrer ZETA Guard-Instanz bei der gematik ist ein wesentlicher Schritt, um den Zugriff auf Telemetriedaten-Empfänger und SIEM-Systeme zu ermöglichen. Stellen Sie sicher, dass Sie die erforderlichen Audiences und Issuer korrekt konfigurieren.

## Zulassungsbedingungen

Vor der Inbetriebnahme von ZETA Guard müssen bestimmte Zulassungsbedingungen erfüllt sein. Dazu gehören die Vorlage von Produkt-Gutachten, Testberichten und Berichten über Sicherheitslücken.

## Updates und Upgrades an ZETA-Guard

Regelmäßige Updates und Upgrades sind notwendig, um die Sicherheit und Funktionalität von ZETA Guard zu gewährleisten. Befolgen Sie die beschriebenen Vorgehensweisen und testen Sie die Integration nach jedem Update.

## Testen der Integration

Vor der endgültigen Inbetriebnahme sollten umfassende Tests durchgeführt werden, um sicherzustellen, dass ZETA Guard ordnungsgemäß in Ihre Infrastruktur integriert ist. Eine Generalprobe wird empfohlen.

## Fehlerbehebung und Support

Bei Problemen während der Integration oder im laufenden Betrieb steht Ihnen unser Support-Team zur Verfügung. Nutzen Sie die bereitgestellten Ressourcen zur Fehlerbehebung.

## Einsaztszenarien

ZETA Guard kann in verschiedenen Szenarien eingesetzt werden, darunter Geo-Redundanz, Multi-Cluster-Betrieb und Betrieb in einer VAU. Detaillierte Konfigurationsanleitungen für TLS, optionale Komponenten und Telemetriedaten-Erfassung sind enthalten.

## Lokaler Cache der Artifact Registry

Ein lokaler Cache der Artifact Registry kann eingerichtet werden, um die Verfügbarkeit von Container-Images, PIP- und PAP-Daten sowie Konfigurationsdaten zu gewährleisten. Dies verbessert die Leistung und reduziert die Abhängigkeit von externen Quellen.

## Tests der gematik

Die gematik führt verschiedene Tests durch, um die Konformität und Sicherheit von ZETA Guard zu gewährleisten. Dazu gehören CI-Prozesse, Tests in der gcloud-Umgebung, Openshift-Konformitätstests, Penetrationstests, Performance-Tests und Load-Tests.
Detaillierte Informationen zu diesen Tests und deren Anforderungen sind in diesem Abschnitt enthalten.
