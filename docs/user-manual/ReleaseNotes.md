<img align="right" width="250" height="47" src="assets/images/Gematik_Logo_Flag.png"/> <br/>

# Release Notes ZETA SDK und ZETA Guard Helm Charts

## Release 1.0.1

### changed
- Korrektur der ReleaseNotes Version
- Client Codebeispiele korrigiert und aktualisiert
- Updated WIF configuration

### added
- Client Dokumentation für Custom Log Provider, Custom Storage und Custom SMC-B Connector

## Release 1.0.0

### added

- Anleitung zur Konfiguration von Egress-NetworkPolicies hinzugefügt
  (`networkPolicy.enabled`, IP-Blöcke pro Kategorie).
- Admin-API-Absicherung über separaten Admin-Hostnamen dokumentiert
- Terraform-Variable `audience` (Standard: `""`) dokumentiert: Wenn
  `keycloak_url` auf einen Admin-Hostnamen zeigt, muss der Audience-Wert
  explizit auf den öffentlichen Haupthostnamen gesetzt werden.
- Dokumentation für eigene OCI-Registry des Provisioning Containers:
  `provisioningProcessor.provisioningContainer` und
  `provisioningProcessor.provisioningContainerCaSecretRef` — inkl. Anleitung zum
  korrekten Spiegeln des Provisioning-Daten-Images
- Helm-Chart-Referenzdokumentation ausgebaut: ServiceAccounts,
  PodDisruptionBudgets, Security Contexts, Probes,
  CloudNativePG-DB-Einstellungen,
  Infinispan-Konfiguration und Provisioning Processor
- `imageTrustCertchainSecretRef` dokumentiert: Pflicht-Secret mit der
  gematik-Zertifikatskette (`certchain.pem`) zur cosign-Signaturprüfung des
  Provisioning-Daten-Images — wird von Authserver, PEP-Proxy, OPA und
  OPA-Simulation benötigt. Beschreibung in der Helm-Chart-Referenz und in
  der Kubernetes-Konfigurationsanleitung (neuer Abschnitt 6.4) ergänzt.
- Terraform-Variable `audience_scope_name` (Standard: `"zero:audience"`)
  dokumentiert
- Quickstart: Betriebsmodi-Tabelle um Kubernetes-Provider-Zeile ergänzt
- Beschreibung der durch den Guard-Betreiber bzw. Client-Hersteller zu
  leistenden Sicherheitsleistungen.

### changed

- Ressourcenverwaltung aktualisiert: Migration von `authserver.resources` nach
  `authserver.container.resources` dokumentiert, separate Init-Container-
  und Infinispan-Ressourcen beschrieben
- Quickstart: `providers.tf` wird jetzt neben `main.tf` generiert; im lokalen
  Modus ist kein Kubernetes-Provider mehr erforderlich
- Kubernetes-Konfigurationsanleitung: CloudNativePG-Datenbankverbindung ist
  jetzt
  über `cloudnativeDbUrl`, `cloudnativeDbSecretName` und `cloudnativeDbSchema`
  konfigurierbar
- Verweis auf Helm-Chart-Referenz in den querschnittlichen Konzepten ergänzt

## Release 0.5.0

### added

- Beschreibung der No-Travel-Option des PEP
- Hinweis zu forwarded Headers beim Testdriver

### changed

- OpenShift-Kompatibilitätsanleitung aktualisiert: `openshiftRoute` durch
  `openshiftIngress` ersetzt, neue Values-Struktur (`openshiftIngress.enabled`,
  `openshiftIngress.certName`, `ingressClassName`, `nginxIngressEnabled`,
  `ingressEnabled`) dokumentiert.
- Konfigurationshinweise: OpenShift-Abschnitt aktualisiert – Ingress mit
  TLS-Konfiguration statt separater OpenShift-Routes, Verweis auf
  Ingress-to-Route-Controller.
- Kubernetes-Konfigurationsanleitung: OpenShift-Ingress-Unterstützung im
  Ingress-Abschnitt ergänzt, PDP-Abschnitt (Keycloak) um Ingress-Verweis und
  Terraform-Betriebsmodi erweitert.
- Quickstart: PDP-Konfiguration um zwei Terraform-Betriebsmodi erweitert (
  Kubernetes-Modus mit State im Cluster, lokaler Modus ohne Cluster-Zugang).
  Voraussetzungen nach Modus aufgeteilt. `Pods/Exec`-Berechtigung entfernt (
  Policy-Skript nutzt jetzt REST API statt `kubectl exec`). Ingress-Controller
  als optionale Voraussetzung markiert.
- ASL-Konfigurationsbeschreibung aktualisiert
- TLS-Konfiguration für Telemetrie-Exporter aktualisiert
- Dokumentation zu mTLS-Kommunikation überarbeitet

## Release 0.4.0

### added

- OpenShift-Kompatibilitätsanleitung hinzugefügt
- Anleitung zur Anbindung von Observability-Backends
- Anleitung zum Ersetzen des ZETA Guard Log-Collectors durch einen eigenen
  OpenTelemetry Collector
- Dokumentation der ASL-Schlüssel und Konfigurationsparameter
- Dokumentation der Ressourcenverwaltung für ZETA-Guard-Pods
- Horizontale Skalierung für OPA, Authorization Server und PEP mit Helm Values
  dokumentiert
- Dokumentation zu Container Image Digests hinzugefügt
- `verification.scope`-Konfiguration zur OPA-Dokumentation hinzugefügt
- OPA-Simulation-Dokumentation aktualisiert
- Terraform Demo-Dateien verlinkt

### changed

- Ingress-Konfiguration überarbeitet und verbessert
- Quickstart-Anleitung für Helm 4-Kompatibilität und initiale
  Deployment-Voraussetzungen aktualisiert
- Keycloak-Konfigurationstabelle gemäß Helm-Änderungen aktualisiert
- Hashing-Pepper zur Vermeidung von Rainbow-Table-Angriffen dokumentiert
- Datenbankdokumentation aktualisiert (CloudNativePG)
- `imagePullSecrets`-Dokumentation aktualisiert

## Release 0.3.1

### added

- Installationsanleitung für istio Service Mesh hinzugefügt

## Release 0.3.0

### added

- Dokumentation für Ingress Controller hinzugefügt auf F5 nginx-ingress


