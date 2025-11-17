# ZETA Guard Integrations-Anleitung

## Inhalt

- [ZETA Guard Integrations-Anleitung](#zeta-guard-integrations-anleitung)
  - [Inhalt](#inhalt)
  - [Einführung](#einführung)
  - [Registrierung der ZETA Guard-Instanz](#registrierung-der-zeta-guard-instanz)
  - [Zulassungsbedingungen](#zulassungsbedingungen)
    - [Erstzulassung](#erstzulassung)
    - [Management von Änderungen (Updates und Upgrades)](#management-von-änderungen-updates-und-upgrades)
  - [Testen der Integration](#testen-der-integration)
  - [Fehlerbehebung und Support](#fehlerbehebung-und-support)
  - [Einsatzszenarien](#einsatzszenarien)
    - [Geo-Redundanz und Multi-Cluster-Betrieb](#geo-redundanz-und-multi-cluster-betrieb)
    - [Betrieb in einer Vertrauenswürdigen Ausführungsumgebung (VAU)](#betrieb-in-einer-vertrauenswürdigen-ausführungsumgebung-vau)
      - [Verschlüsselte Verbindung in die VAU](#verschlüsselte-verbindung-in-die-vau)
    - [Konfiguration und Austausch von Komponenten](#konfiguration-und-austausch-von-komponenten)
    - [Konfiguration von ZETA Guard](#konfiguration-von-zeta-guard)
  - [Lokaler Cache der Artifact Registry](#lokaler-cache-der-artifact-registry)
  - [Tests der gematik](#tests-der-gematik)

## Einführung

In dieser Anleitung werden die Rahmenbedingungen, Szenarien und Schritte für die Integration von ZETA Guard in die IT-Infrastruktur von TI 2.0 Dienst-Anbietern beschrieben.

Die folgende Abbildung zeigt eine typische ZETA Guard-Deployment-Architektur:

![ZETA Guard Deployment](../../../images/zeta-guard-integration-guide/zeta-guard-deployment-view.svg)

Wenn eine WAF vor dem Ingress Controller eingesetzt wird, muss TLS Termination an der WAF oder davor erfolgen. In diesem Fall muss der Ingress Controller so konfiguriert werden, dass er TLS-Verbindungen von der WAF akzeptiert.
Darüber hinaus gibt es Szenarien, in denen TLS in der VAU terminieren muss. Eine WAF kann den Traffic dann nicht analysieren.

## Registrierung der ZETA Guard-Instanz

Die Registrierung der ZETA Guard-Instanz bei der gematik ist ein wesentlicher Schritt, um den Zugriff auf Telemetriedaten-Empfänger und SIEM-Systeme zu ermöglichen und um den ZETA Guard Authorization Server in die TI 2.0 Föderation des Federation Masters aufzunehmen.

Folgende Daten sind für die Registrierung erforderlich:

- **Issuer-Informationen** (Issuer und JWKS URI) für die Authentifizierung der ZETA Guard Instanz. Der Issuer des ZETA Guard ist der OpenID Provider des Kubernetes Clusters, in dem ZETA Guard ausgeführt wird. Diese Daten werden für die Authentifizierung per Workload Identity Federation am Telemetriedaten-Empfänger und SIEM der gematik benötigt.
- **Audiences und Scopes** für den Zugriff auf den Resource Server müssen angegeben werden, um die Kontrolle der Zugriffsrechte der ZETA Guard Policy Engine zu definieren.
- **Der öffentliche Signaturschlüssel** des ZETA Guard Authorization Servers wird für die Validierung von JWTs benötigt, die von ZETA Guard ausgegeben werden. Der Öffentliche Signaturschlüssel wird in die Konfiguration des Federation Masters aufgenommen. Dadurch wird die Vertrauensstellung zwischen dem Federation Master und dem ZETA Guard Authorization Server hergestellt.

## Zulassungsbedingungen

Vor der Inbetriebnahme von ZETA Guard müssen bestimmte Zulassungsbedingungen erfüllt sein. Dieser Abschnitt beschreibt den Prozess der Erstzulassung sowie die Verfahren und Auswirkungen verschiedener Arten von Änderungen an ZETA Guard, um eine kontinuierliche Konformität und Sicherheit zu gewährleisten.

### Erstzulassung

Für die Erstzulassung eines TI 2.0 Dienstes stellt die gematik dem Anbieter ein umfassendes Paket an ZETA Guard Nachweisdokumenten zur Verfügung. Diese Dokumente sind die Grundlage für die Zulassung des Dienstes, der ZETA Guard integriert. Das Paket umfasst:

- **Sicherheitsgutachten (SiGu) und Produktgutachten:** Unabhängige Bewertungen der Sicherheitsarchitektur und Produktreife.
- **Testbericht ZETA-Guard:** Detaillierte Ergebnisse der funktionalen und nicht-funktionalen Tests.
- **Software Bill of Materials (SBOM):** Eine vollständige Liste aller Software-Komponenten, die in ZETA Guard enthalten sind.
- **Report über Sicherheitslücken:** Eine transparente Übersicht bekannter und behobener Sicherheitslücken.

Diese Unterlagen werden vom Anbieter des TI 2.0 Dienstes in die eigene Zulassungsdokumentation eingefügt.

### Management von Änderungen (Updates und Upgrades)

Regelmäßige Updates und Upgrades sind notwendig, um die Sicherheit und Funktionalität von ZETA Guard zu gewährleisten. Befolgen Sie die beschriebenen Vorgehensweisen und testen Sie die Integration nach jedem Update. Der Anbieter muss sicherstellen, dass die Integration nach einem Update weiterhin wie erwartet funktioniert (Generalprobe).

Änderungen an ZETA Guard werden in verschiedene Kategorien eingeteilt, die jeweils unterschiedliche Auswirkungen auf den Betrieb und die Zulassung der Fachanwendung haben. Grundsätzlich werden funktionale Änderungen nur abwärtskompatibel durchgeführt.

- **Hotfix:**
  Ein Hotfix behebt einen kritischen Fehler ohne funktionalen Bezug. Die Anwendung des Hotfixes erfordert keinen erneuten Zulassungsprozess, sondern wird als betrieblicher Change behandelt, sofern keine sicherheitsrelevanten Komponenten betroffen sind.

- **Security Hotfix:**
  Hierbei handelt es sich um einen dringenden Fix zur Behebung einer Sicherheitslücke. Die Anwendung des Security Hotfixes ist oft verpflichtend und muss nach einem vordefinierten, beschleunigten Verfahren erfolgen. Die Änderung erfordert eine Dokumentation im Rahmen des betrieblichen Change-Prozesses.

- **Betrieblicher Change:**
  Dies umfasst reguläre Updates oder Konfigurationsänderungen. Diese Änderungen sind abwärtskompatibel und erfordern keine Neuzulassung.

- **Neuzulassung:**
  Eine Neuzulassung aufgrund von Änderungen an ZETA Guard ist nicht vorgesehen. Wird der TI 2.0 Dienst, unabhängig von ZETA Guard, neu zugelassen, so werden die ZETA Guard Nachweisdokumente in die Zulassungsdokumentation eingefügt.

- **Abkündigung von Endpunkten**
  Die Abwärtskompatibilität von ZETA Guard Versionen kann dazu führen, dass neue Versionen von Endpunkten eingeführt werden. Die Abkündigung älterer Endpunkt-Versionen erfolgt mit langem Vorlauf, um eine reibungslose Migration zu gewährleisten.

## Testen der Integration

Vor der endgültigen Inbetriebnahme sollten umfassende Tests in eigenen Umgebungen des Herstellers und des Anbieters durchgeführt werden, um sicherzustellen, dass ZETA Guard ordnungsgemäß in Ihre Infrastruktur integriert ist. Eine Generalprobe muss bei jeder Änderung in der Produktionsumgebung der Fachanwendung (inklusive ZETA Guard) durchgeführt werden.

## Fehlerbehebung und Support

Bei Problemen während der Integration oder im laufenden Betrieb steht Ihnen das ITSM (IT Service Management) der gematik zur Verfügung. Um eine schnelle und effiziente Bearbeitung zu gewährleisten, nutzen Sie bitte die bereitgestellten Ressourcen zur Fehlerbehebung und halten Sie relevante Informationen wie Log-Auszüge und Konfigurationsdetails bereit.

## Einsatzszenarien

ZETA Guard ist als flexible und anpassbare Sicherheitslösung konzipiert, die sich in verschiedene komplexe IT-Infrastrukturen integrieren lässt. Dieser Abschnitt beschreibt die gängigsten Einsatzszenarien und erläutert die jeweiligen Auswirkungen und Verantwortlichkeiten für den Anbieter.

### Geo-Redundanz und Multi-Cluster-Betrieb

Für hochverfügbare Dienste ist ein geo-redundanter Betrieb unerlässlich. ZETA Guard unterstützt dies durch seine containerisierte Architektur, die den Einsatz in Multi-Cluster-Umgebungen ermöglicht. Die Kernkomponenten von ZETA Guard (z.B. PEP, PDP) sind zustandslos, was den Betrieb über mehrere Standorte hinweg erheblich vereinfacht.

Zwei primäre Lösungsmodelle bieten sich an:

1. **Active-Passive-Betrieb:**
   - **Beschreibung:** Ein primärer Kubernetes-Cluster an einem Standort verarbeitet den gesamten Live-Traffic. Ein zweiter, passiver Cluster an einem geografisch getrennten Standort dient als Hot-Standby. Alle Konfigurationen und zustandsbehafteten Daten (siehe unten) werden kontinuierlich vom aktiven zum passiven Cluster repliziert.
   - **Failover:** Im Falle eines Ausfalls des primären Standorts wird der Traffic manuell oder automatisiert auf den passiven Cluster umgeleitet, der dann die Rolle des aktiven Clusters übernimmt.
   - **Auswirkungen für den Anbieter:** Dieses Modell ist einfacher zu implementieren und zu verwalten. Der Anbieter ist für die Einrichtung der Daten-Replikation und die Implementierung des Failover-Mechanismus (z.B. über DNS-Umschaltung) verantwortlich.

2. **Active-Active-Betrieb:**
   - **Beschreibung:** Mehrere Cluster an verschiedenen Standorten sind gleichzeitig aktiv und verarbeiten den Traffic. Ein globaler Load Balancer verteilt die Anfragen auf die Standorte, z.B. basierend auf Latenz oder Auslastung.
   - **Herausforderung:** Dieses Modell erfordert eine robuste Strategie für die Synchronisation zustandsbehafteter Daten in Echtzeit über alle Standorte hinweg. Während die ZETA Guard Policies und Konfigurationen über ein zentrales Git-Repository (GitOps) konsistent gehalten werden können, müssen insbesondere die Daten der PDP-Datenbank (Keycloak) über eine Multi-Master-Replikation oder eine geo-verteilte Datenbanklösung synchronisiert werden.
   - **Auswirkungen für den Anbieter:** Dieses Modell bietet die höchste Verfügbarkeit und Ausfallsicherheit, ist aber in der Implementierung deutlich komplexer. Der Anbieter trägt die volle Verantwortung für die Auswahl und den Betrieb der globalen Load-Balancing-Lösung und der geo-redundanten Datenbank.

### Betrieb in einer Vertrauenswürdigen Ausführungsumgebung (VAU)

ZETA Guard schreibt keine spezifische Technologie für die Umsetzung einer VAU vor. Als containerisierte Anwendung kann ZETA Guard auf jeder konformen Kubernetes-Distribution betrieben werden. Die Wahl der VAU-Technologie liegt beim Anbieter und hat direkte Auswirkungen auf dessen Sicherheitskonzept und Zulassungsprozess.

#### Verschlüsselte Verbindung in die VAU

ZETA Guard muss so konfiguriert werden, dass eine verschlüsselte Verbindung vom ZETA Client in die VAU verwendet wird. Dies kann durch die TLS-Terminierung oder durch die Terminierung von ZETA/ALS im HTTP Proxy innerhalb der VAU erfolgen. ZETA/ASL kann auch im Resource Server terminiert werden, wenn der HTTP Proxy nicht in der VAU betrieben wird.

### Konfiguration und Austausch von Komponenten

ZETA Guard wird als Helm-Chart ausgeliefert, das eine vollständige, lauffähige Konfiguration enthält. Für eine bessere Integration in bestehende Infrastrukturen und Prozesse können Anbieter jedoch bestimmte Standardkomponenten durch eigene, bereits etablierte Lösungen ersetzen.

**Wichtiger Hinweis:** Wenn eine mitgelieferte Komponente durch eine eigene Lösung ersetzt wird, geht die Verantwortung für den Betrieb, die Sicherheit und die zulassungsrelevanten Nachweise (Testnachweise, SiGu, Produktgutachten) vollständig auf den Anbieter über.

Folgende Komponenten können ausgetauscht werden:

- **Ingress Controller:**
  - **Szenario für Austausch:** Ein Anbieter hat bereits einen zentralen, gehärteten Ingress Controller (z.B. Contour, Traefik) im Einsatz, der unternehmensweite Sicherheitsrichtlinien umsetzt und vom Betriebsteam standardisiert verwaltet wird.
- **Service Mesh (z.B. Istio, Cilium, Linkerd):**
  - **Szenario für Austausch:** Der Anbieter nutzt bereits ein unternehmensweites Service Mesh zur Steuerung von mTLS, Observability und Traffic-Management. Die Integration von ZETA Guard in das bestehende Mesh vermeidet den Betrieb von zwei parallelen Lösungen.
- **PDP-Datenbank (PostgreSQL):**
  - **Szenario für Austausch:** Dies ist ein sehr häufiges Szenario. Anstatt eine PostgreSQL-Instanz innerhalb des Clusters zu betreiben, kann der Anbieter eine externe, gemanagte Datenbank-Lösung anbinden. Dies bietet Vorteile wie Hochverfügbarkeit, automatisierte Backups, Skalierbarkeit und einfachere Wartung.
- **Argo CD (GitOps-Tool):**
  - **Szenario für Austausch:** Der Anbieter verwendet bereits ein anderes GitOps-Werkzeug (z.B. FluxCD) oder betreibt eine zentrale Argo CD-Instanz für alle seine Anwendungen. Die Verwaltung des ZETA Guard-Deployments soll in die bestehenden, etablierten CI/CD-Prozesse integriert werden.

### Konfiguration von ZETA Guard

Die Konfiguration von ZETA Guard erfolgt über das mitgelieferte Helm-Chart und ist entscheidend für die Sicherheit und Funktionalität der Instanz.

- **TLS-Konfiguration:** Die Absicherung der externen Schnittstellen (Ingress) mittels TLS ist zwingend erforderlich. Der Anbieter ist für die Bereitstellung und Verwaltung der TLS-Zertifikate verantwortlich.
- **HSM-Anbindung:** Für höchste Sicherheitsanforderungen kann der ZETA Guard Authorization Server an ein Hardware-Sicherheitsmodul (HSM) angebunden werden, um das Schlüsselmaterial für die Signatur von Token zu schützen. Der Anbieter ist für die Bereitstellung und Konfiguration des HSM sowie des zugehörigen Kubernetes-Plugins (CSI-Treiber) verantwortlich.
- **Telemetriedaten-Erfassung:** ZETA Guard produziert umfangreiche Telemetriedaten (Metriken, Logs, Traces). Die Konfiguration des Exports dieser Daten an zentrale SIEM- und Monitoring-Systeme der gematik ist bereits vorkonfiguriert. Exports an die Anbieter-Systeme können vom Anbieter ergänzt werden.
- **Mehrere Resource Server:** Eine einzelne ZETA Guard-Instanz kann den Zugriff auf mehrere unterschiedliche Resource Server (Fach- und Mehrwertdienste) absichern. Dies wird über die Konfiguration der `audiences` und der entsprechenden OPA-Policies gesteuert.

## Lokaler Cache der Artifact Registry

Für den stabilen und sicheren Betrieb von ZETA Guard **muss** der Anbieter einen lokalen Cache (auch als "Pull-Through-Cache" oder "Proxy-Registry" bezeichnet) für alle externen Artefakte einrichten. Dies ist eine zwingende Anforderung, um die Verfügbarkeit des Dienstes bei Ausfällen externer Registries zu gewährleisten und die Angriffsfläche zu reduzieren.

**Zu cachende Artefakte:**

- **Container-Images:** Alle von ZETA Guard benötigten Container-Images.
- **PIP- und PAP-Daten:** Konfigurationsdaten für die Policy-Entscheidungen, insbesondere die OPA-Bundles.
- **Provisionierungs-Daten:** Externe Konfigurationsquellen wie die TSL (Trust Service Status List), Zertifikate von TPM-Herstellern oder die `roots.json` für die OpenID Federation.

**Empfohlene Open-Source-Tools:**

Für den produktiven Einsatz eignen sich robuste und etablierte Werkzeuge. Die gematik empfiehlt die Prüfung der folgenden Open-Source-Lösungen.
- **Harbor:** Ein Projekt der Cloud Native Computing Foundation (CNCF), das als vollwertige, private Artifact Registry fungiert. Es bietet neben dem Caching auch Features wie Vulnerability Scanning, rollenbasierte Zugriffskontrolle (RBAC) und Replikation zwischen Instanzen. Harbor ist eine ausgezeichnete Wahl für sicherheitskritische Produktionsumgebungen.
- **Sonatype Nexus Repository Manager:** Ein weit verbreiteter und sehr flexibler Artefakt-Manager. Nexus unterstützt eine Vielzahl von Formaten (Container-Images, Java-Bibliotheken, npm-Pakete etc.) und bietet ebenfalls robuste Caching- und Proxy-Funktionen.

Die Einrichtung und der Betrieb des Caches liegen in der alleinigen Verantwortung des Anbieters.

## Tests der gematik

Die gematik führt kontinuierlich eine Reihe von automatisierten und manuellen Tests durch, um die Qualität, Sicherheit und Konformität von ZETA Guard sicherzustellen. Die Ergebnisse dieser Tests fließen in die Zulassungsdokumente ein.

- **CI/CD-Prozess:** Jede Code-Änderung durchläuft eine automatisierte Pipeline mit Unit-, Integrations- und Komponententests.
- **Tests in Referenzumgebungen:** ZETA Guard wird regelmäßig gegen Referenzimplementierungen in gängigen Kubernetes-Umgebungen (z.B. GKE, OpenShift) getestet, um die Konformität sicherzustellen.
- **Sicherheitstests:** Regelmäßige Penetrationstests durch externe Dienstleister sowie kontinuierliches Vulnerability Scanning stellen sicher, dass Sicherheitslücken frühzeitig erkannt und behoben werden.
- **Last- und Performancetests:** Diese Tests stellen sicher, dass ZETA Guard auch unter hoher Last die spezifizierten Antwortzeiten und den erforderlichen Durchsatz erreicht.
