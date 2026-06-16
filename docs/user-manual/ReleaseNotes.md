<img align="right" width="250" height="47" src="assets/images/Gematik_Logo_Flag.png"/> <br/>

# Release Notes ZETA SDK und ZETA Guard Helm Charts

## Release 1.2.0

### added

- Neue Helm Values `pepproxy.wellKnownResourceSuffix` (Standard: `/pep/`) und
  `authserver.wellKnownAuthServerPath` (Standard: `/`) ermöglichen die
  Konfiguration der Pfadanteile im `/.well-known/oauth-protected-resource`
  Dokument.
- Forward-Proxy-Unterstützung für alle ZETA-Guard-Komponenten: Die neuen
  globalen Values `global.httpProxy`, `global.httpsProxy`, `global.allProxy`
  und `global.noProxy` leiten den ausgehenden HTTP/HTTPS-Verkehr von
  `pepproxy`, `authserver`, `opa`, `opa-simulation`, `provisioning-processor`
  und `opa-token-renewer` durch einen konfigurierbaren Forward Proxy.
  Für nginx werden `env`-Direktiven in der `nginx.conf` erzeugt; für Keycloak
  wird `noProxy` automatisch ins Java-`http.nonProxyHosts`-Format konvertiert.
  Dokumentation: [Wie Sie einen Forward Proxy konfigurieren](Anleitungen/Wie_Sie_einen_Forward_Proxy_konfigurieren.md),
  [Helm-Chart-Referenz – Globale Proxy-Konfiguration](Referenzen/Referenz_des_Helm_Charts.md#globale-proxy-konfiguration).
- Neue PEP-Direktive `pep_forward_client_data` (`on`/`off`, Standard `off`) steuert,
  ob der `ZETA-Client-Data`-Header an den Upstream weitergereicht wird (A_26492-02).
  Dokumentation: [Konfiguration des PEP Http Proxy](Referenzen/Konfiguration_des_PEP_Http_Proxy.md#konfigurationsparameter-pep-basis).
- Neuer Helm Value `authserver.hsm.tokenSigning.failClosed` (Standard: `true`)
  verhindert einen Software-Key-Fallback bei nicht erreichbarem HSM.
- HSM-gestütztes TLS für Infinispan über `global.infinispanExternal.hsm.*`
  (`enabled`, `endpoint`, `keyId`, `caCert`).
- Konfigurierbare PostgreSQL-Tuning-Parameter des CloudNativePG-Clusters über
  `cloudnativePg.parameters` (`sharedBuffers`, `maxConnections`).
- Dokumentation der Keycloak-Pools `authserver.dbPool` (`minSize`/`maxSize`) und
  `authserver.httpPool.maxThreads`.
- Weitere Dokumentation: [Wie Sie das ZETA SDK integrieren](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md)
    - `clearRegistration()` operation on `ZetaSdkClient`
    - `logger` parameter in `BuildConfig`
    - `Security` configuration (`additionalCaPem`, `additionalCaFile`, `disableServerValidation`, `sslVerbose`)
    - `Proxy` configuration support
    - `RequiredRoleOid` in `AuthConfig` (C#)
    - `CustomStorage` in `ZetaStorageConfig` (C#)
    - `zeta_route` Cookie wird automatisch über `SdkStorage` persistiert

### changed

- Updated documentation to reflect changes in telemetry pipelines.
- PEP-Header-Behandlung an der Upstream-Grenze ist jetzt zentral über
  `proxy_headers.conf` geregelt: Der PEP entfernt client-gesetzte Credentials
  (`Authorization`, `dpop`, `popp`), überschreibt die von ihm kontrollierten
  `ZETA-*`-Header (`ZETA-User-Info`, `ZETA-Client-Data`, `ZETA-PoPP-Token-Content`)
  und aktualisiert den `Forwarded`-Header gemäß RFC 7239 (A_25669-01, A_28439).
  Das Helm-Chart bindet `proxy_headers.conf` serverweit ein; Locations erben die
  Behandlung automatisch. Wichtig für Betreiber mit eigener nginx-Konfiguration:
  Eine Location mit eigenen `proxy_set_header`-Direktiven (z.B. WebSocket-Upgrade)
  erbt sie wegen nginx' nicht-additiver Vererbung nicht und muss
  `include proxy_headers.conf;` selbst erneut enthalten, sonst antwortet der PEP auf
  `pep on;`-Locations mit HTTP 500 (ProxyHeadersMissing). Details:
  [Header-Behandlung und `proxy_headers.conf`](Referenzen/Konfiguration_des_PEP_Http_Proxy.md#header-behandlung-und-proxy_headersconf).
- OPA ist nun verpflichtend und kann nicht mehr deaktiviert werden — die Toggles
  `opa.enabled`, `provider.smcB.opa.enabled` und `provider.smcB.failClosed` wurden
  entfernt. Der Bundle-Modus (`opa.bundle.enabled: true`) ist der neue Chart-Standard;
  bei nicht erreichbarem OPA antwortet der Authserver mit `503 temporarily_unavailable`.
- Sticky Session zwischen Client und PEP-Instanz wird nun chart-seitig über ein
  `zeta_route`-Cookie auf Ingress-Ebene (F5 NIC) unterstützt; der Value
  `ingress.sessionAffinity.enabled` (ip-hash) entfällt.
- Infinispan-Image von `infinispan/server` auf `infinispan-zeta` umgestellt.
- Dokumentation: [Wie Sie das ZETA SDK integrieren](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md)
    - `logout()`, `forget()`, `clearRegistration()` löschen jetzt den `zeta_route` Cookie
    - `StorageConfig` verwendet jetzt `Default`/`Custom` Varianten statt `provider`/`aesB64Key`
    - `ZetaHttpClientBuilder` Konstruktor ohne Parameter verfügbar (kein `baseUrl` mehr erforderlich)

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


