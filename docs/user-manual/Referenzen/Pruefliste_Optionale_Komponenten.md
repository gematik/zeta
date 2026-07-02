# Prüfliste: Optionale Komponenten (eigene Lösungen von Anbieter/Hersteller)

Ziel dieser Prüfliste ist die strukturierte Bewertung, ob bei Verwendung eigener optionaler Komponenten
(Ingress Controller, Service Mesh, PDP-Datenbank) die bereits vorhandenen Anforderungen aus gemSpec_ZETA
abgedeckt und nachweisbar sind.

Hinweis zum Scope:
- Diese Prüfliste konsolidiert bestehende Anforderungen und Dokumentstellen.
- Sie ersetzt keine Zulassungs- oder Sicherheitsprüfung.
- Die Verantwortung für Betrieb, Sicherheit und Nachweise liegt bei Verwendung eigener Komponenten beim Anbieter.

## 1. Überblick je Komponente

| Komponente | Vorhandene normative Basis (Auszug) | Primäre Nachweisquelle | Aktuelle Lücke im Repo |
|---|---|---|---|
| Ingress Controller (eigene Lösung) | A_28432, A_28433, A_25666-01, A_26639, A_26640, A_28790 | gemSpec_ZETA (Extrakt), Integrationsleitfaden, Kubernetes-Konfigurationsanleitung | Kein separates dediziertes Anforderungsset nur für "eigener Ingress" |
| Service Mesh (eigene Lösung) | A_26519, A_28792 | gemSpec_ZETA (Extrakt), Integrationsleitfaden, Kubernetes-Konfigurationsanleitung | Kein separates dediziertes Anforderungsset nur für "eigenes Service Mesh" |
| PDP-Datenbank (eigene Lösung) | A_26587-01, A_28790 | gemSpec_ZETA (Extrakt), Integrationsleitfaden | Kein separates dediziertes Anforderungsset nur für "eigene PDP-Datenbank" |

## 2. Referenzen (Fundstellen)

### 2.1 Normative Basis (gemSpec_ZETA Extrakt)

- A_28790 - Kernkomponenten, Verwendung eigener Lösungen
  - `tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt` (ca. Zeile 3838)
- A_28432 - Ingress optional
  - `tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt` (ca. Zeile 3852)
- A_28433 - Kubernetes Ingress oder eigener Ingress
  - `tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt` (ca. Zeile 3856)
- A_28792 - Hilfskomponenten (inkl. Service Mesh)
  - `tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt` (ca. Zeile 3868)
- A_26519 - Unterstützung von Service-Mesh-Lösungen
  - `tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt` (ca. Zeile 3664)
- A_26587-01 - PDP-Datenbank-Kompatibilität
  - `tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt` (ca. Zeile 4641)
- Ingress-Funktionsanforderungen (TLS, WebSocket, HTTP-Versionen)
  - `tmp/docs/gemSpec_ZETA_1.4.0_fulltext.txt` (ca. Zeilen 3693, 3703, 3705)

### 2.2 Betriebs- und Integrationshinweise

- Austausch optionaler Komponenten und Verantwortungsübergang
  - `docs/zeta-guard/integration-guide/index.md` (Abschnitt "Konfiguration und Austausch von optionalen Komponenten")
- Optionale Voraussetzungen bei Nutzung eigener Ingress-/Mesh-Lösungen
  - `docs/user-manual/Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md`

## 3. Prüfliste Ingress Controller (eigene Lösung)

### 3.1 Normative Mindestabdeckung

- [ ] Eigener Ingress ist als zulässige Variante umgesetzt (A_28432/A_28433).
- [ ] TLS-Terminierung für externe Verbindungen ist nachweisbar unterstützt (A_25666-01).
- [ ] WebSocket-Unterstützung ist vorhanden (A_26639).
- [ ] HTTP/1.1 und HTTP/2 sind vorhanden; HTTP/3 ist bewertet (A_26640).
- [ ] Kompatibilität zur ZETA-Kernkomponentenschicht ist dokumentiert (A_28790).

### 3.2 Nachweisartefakte

- [ ] Architekturdiagramm mit Platzierung des externen Ingress.
- [ ] Konfiguration (IngressClass, TLS-Zertifikate, Weiterleitungsregeln).
- [ ] Testprotokolle für TLS, WebSocket und unterstützte HTTP-Versionen.
- [ ] Sicherheitsnachweise (Härtung, Betriebsprozesse, Monitoring/Logging).

### 3.3 Typische Lücken

- [ ] Kein separates Anforderungsset "eigener Ingress" vorhanden (nur verteilte Anforderungen).
- [ ] Unklare Zuordnung, welche Nachweise vom Anbieter vs. Hersteller zu liefern sind.

## 4. Prüfliste Service Mesh (eigene Lösung)

### 4.1 Normative Mindestabdeckung

- [ ] Einsatz einer Service-Mesh-Lösung ist technisch unterstützt (A_26519).
- [ ] Bei eigener Hilfskomponente ist Kompatibilität zur Kernkomponentenschicht sichergestellt (A_28792).
- [ ] mTLS-/Kommunikationsabsicherung zwischen ZETA-Komponenten ist dokumentiert umgesetzt.

### 4.2 Nachweisartefakte

- [ ] Mesh-Topologie (Namespaces, Sidecars, mTLS-Policies).
- [ ] Nachweis von mTLS zwischen relevanten ZETA-Komponenten.
- [ ] Nachweis von Telemetrie/Observability-Integration (Metriken, Traces, Logs).
- [ ] Betriebsnachweise für Zertifikats-/Policy-Rotation.

### 4.3 Typische Lücken

- [ ] Kein separates Anforderungsset "eigenes Service Mesh" vorhanden (nur verteilte Anforderungen).
- [ ] Fehlende standardisierte Abnahmekriterien für Mesh-spezifische Security Controls im Repo.

## 5. Prüfliste PDP-Datenbank (eigene Lösung)

### 5.1 Normative Mindestabdeckung

- [ ] Datenbank ist mit dem Authorization Server kompatibel (A_26587-01).
- [ ] Bei eigener Kernkomponente sind Anforderungen und Schnittstellenkompatibilität nachgewiesen (A_28790).
- [ ] Betriebsmodell für Session-, Nutzer- und Client-Daten ist konsistent dokumentiert.

### 5.2 Nachweisartefakte

- [ ] Verbindungs- und Authentisierungskonzept zur Datenbank (inkl. TLS, Credentials, Rotation).
- [ ] Backup-/Restore-Konzept und Wiederanlaufverfahren.
- [ ] Last-/Failover-Tests für Datenbankverfügbarkeit.
- [ ] Migrations-/Upgrade-Konzept inkl. Rollback.

### 5.3 Typische Lücken

- [ ] Kein separates Anforderungsset "eigene PDP-Datenbank" vorhanden (nur verteilte Anforderungen).
- [ ] Abnahmegrenzen (Performance/SLA/Sicherheitsmetriken) nicht zentral als Set dokumentiert.

## 6. Querschnitt: Anbieter-/Hersteller-Nachweise

- [ ] Verantwortlichkeiten zwischen Fachdienst-Hersteller und Fachdienst-Betreiber sind vertraglich und technisch eindeutig zugeordnet.
- [ ] Nachweise für "eigene Lösung" sind gegenüber den relevanten gematik-Anforderungen vollständig rückverfolgbar.
- [ ] Für jede ersetzte Komponente existiert eine Risikoanalyse mit Maßnahmen und Restrestrisiko.
- [ ] Testnachweise, SiGu-Input und Produktgutachten-Input sind konsistent vorbereitet.

## 7. Fazit (Stand Repo)

- Es gibt bereits Anforderungen für den Einsatz eigener optionaler Komponenten.
- Diese liegen verteilt in Spezifikation und Handbuch vor.
- Ein dediziertes, separat benanntes Anforderungsset je Austauschkomponente ist im Repo aktuell nicht vorhanden.