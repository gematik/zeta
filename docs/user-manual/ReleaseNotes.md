<img align="right" width="250" height="47" src="assets/images/Gematik_Logo_Flag.png"/> <br/>

# Release Notes ZETA SDK und ZETA Guard Helm Charts

## Release 1.3.1

### changed

- Korrektur der ReleaseNotes Version

## Release 1.3.0

### added

- Neue PEP-Direktiven der [PEP-Konfiguration](Referenzen/Konfiguration_des_PEP_Http_Proxy.md#konfigurationsparameter-pep-basis)
  beschrieben: `pep_revocation_url`, `pep_popp_issuer` und `pep_dpop_validity`
- Die Felder des Well-Known-Dokuments des Authorization Servers sind jetzt
  dokumentiert:
  [Well-Known-Dokument des Authorization Servers](Referenzen/Konfiguration_des_PDP_Services.md#well-known-dokument-des-authorization-servers)
  — darunter `api_versions_supported` (A_29691), `nonce_endpoint`,
  `revocation_endpoint` (A_29996) sowie die Felder des mobilen Client-Flows
  (`pushed_authorization_request_endpoint`,
  `require_pushed_authorization_requests`, `redirection_endpoint`).
- Neuer Referenzabschnitt
  [OPA (Policy Engine)](Referenzen/Referenz_des_Helm_Charts.md#opa-policy-engine)
  in der Helm-Chart-Referenz: Value-Tabellen zu Deployment, Logging und
  Telemetrie, Policy-Bundle, Signaturprüfung, Simulation-Instanz, Workload Identity
  Federation und geplantem Rollout-Restart. Die bisherige Referenz enthielt
  keinen OPA-Abschnitt; die konzeptionellen Erläuterungen bleiben in
  [Wie Sie OPA in ZETA Guard konfigurieren](Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md).
- Neuer Abschnitt
  [Variante mit separatem Admin-Hostnamen](Referenzen/Konfigurationshinweise.md#variante-mit-separatem-admin-hostnamen)
  in den Konfigurationshinweisen: die Abbildung im Abschnitt
  "Auslieferungsstand" ist jetzt ausdrücklich als Variante *ohne*
  `authserver.adminHostname` gekennzeichnet, und die Variante *mit*
  Admin-Hostnamen ist als eigenes Diagramm samt Vergleichstabelle ergänzt.
- Neuer Quickstart-Abschnitt
  [Wann und wie oft die PDP-Konfiguration laufen muss](Anleitungen/ZETA_Guard_Quickstart.md#wann-und-wie-oft-die-pdp-konfiguration-laufen-muss):
  wann der Terraform-Schritt zwingend nötig ist und wann nicht, seine
  Idempotenz und beabsichtigten Nebenwirkungen, Reihenfolge gegenüber dem
  Helm-Deployment sowie das Verhalten bei Abbruch.
- Least-Privilege-RBAC-Vorlage (Role und RoleBinding) für den
  Terraform-Runner im
  [Quickstart](Anleitungen/ZETA_Guard_Quickstart.md#hinweis-erforderliche-kubernetes-rechte-für-terraform-nur-kubernetes-modus)
  — `cluster-admin` ist nicht erforderlich; inklusive der Grenzen der
  Einschränkbarkeit über `resourceNames`.
- Neuer Helm Value `telemetryGatewayHost` — setzt den voll qualifizierten
  Hostnamen, unter dem das Telemetry-Gateway erreicht wird, für Umgebungen, in
  denen der Kurzname des Service nicht auflösbar ist. Dokumentation:
  [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#4-telemetriedaten-service-opentelemetry-collector-konfigurieren).
- Neuer Abschnitt für mTLS zum Resource Server ohne Service Mesh
  (`pepproxy.extraVolumes` / `extraVolumeMounts` + `proxy_ssl_*` via
  `proxyLocations[].extraConfig`); PEP-Abschnitt auf `proxyLocations` umgestellt
- Konfigurierbare Timeouts und Fail-Verhalten für die SMC-B-OCSP-Sperrprüfung (
  `authserver.provider.smcB.ocspConnectTimeoutMs` / `ocspReadTimeoutMs` / `ocspFailClosed`)
- Ausführungen zur Filterung von Telemetrie
- Ergänzungen zum Verwenden einer eigenen OCI Registry
- Das OPA-Policy-Bundle kann jetzt auch aus einer privaten Registry mit eigener CA
  geladen werden; die bisherige Einschränkung auf öffentlich vertrauenswürdige
  Zertifikate entfällt. Dokumentation:
  [Wie Sie eine eigene OCI Registry verwenden](Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md#ca-zertifikat-für-die-registry).
- Neuer Helm Value `opa.bundleHealthCheck` (Standard: `false`) — macht einen
  fehlgeschlagenen Bundle-Download über die Readiness-Probe als `NotReady`
  sichtbar. Dokumentation:
  [Wie Sie OPA in ZETA Guard konfigurieren](Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md#fehlgeschlagene-bundle-downloads-sichtbar-machen).
- Neue Referenzseite [Konfiguration der Well-Known-Endpunkte](Referenzen/Konfiguration_der_Well-Known_Endpunkte.md):
  erläutert, wann und warum die Pfadanteile im
  `/.well-known/oauth-protected-resource` Dokument (`pepproxy.wellKnownBase`,
  `pepproxy.wellKnownResourceSuffix`, `authserver.wellKnownAuthServerPath`) von
  den Defaults abweichen müssen, den Zusammenhang mit `authserver.hostname` /
  `adminHostname` sowie wie doppelte Well-Knowns bei Fehlkonfiguration entstehen
  und vermieden werden.
- Neuer Helm Value `networkPolicy.dns` — macht den DNS-Egress-Peer der
  Egress-NetworkPolicies konfigurierbar (`namespaceSelector`, `podSelector`,
  `ports` oder ein rohes `to:`-Override). Standard bleibt der Upstream-Peer
  `kube-system` / `k8s-app: kube-dns` / Port 53 (keine Änderung für
  Bestandsdeployments). Für OpenShift den `openshift-dns`-Selektor
  (`dns.operator.openshift.io/daemonset-dns: default`) und Port 5353 setzen, da
  DNS dort im Namespace `openshift-dns` läuft und OVN-Kubernetes Egress nach dem
  DNAT auswertet. Dokumentation:
  [Wie Sie Egress-NetworkPolicies konfigurieren](Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md#dns-egress).
- Neuer Helm Value `issuer` — annotiert die Master-Ingress-Ressourcen mit
  `cert-manager.io/issuer` (namespace-lokaler Issuer) statt
  `cert-manager.io/cluster-issuer`. Hat Vorrang vor `clusterIssuer`, sofern
  gesetzt. Ermöglicht den Einsatz eines auf den Namespace beschränkten
  cert-manager-`Issuer` für Betreiber, denen Governance-/Security-Vorgaben das
  Ausrollen clusterweiter `ClusterIssuer`-Ressourcen untersagen. Standardwert
  `""` behält das bisherige ClusterIssuer-Verhalten bei.
  Dokumentation: [Helm-Chart-Referenz – cert-manager-Issuer für Ingress-TLS](Referenzen/Referenz_des_Helm_Charts.md#cert-manager-issuer-für-ingress-tls).
- ASL-Konfiguration des PEP vollständig beschrieben
  ([PEP-Konfiguration — Konfigurationsparameter (ASL)](Referenzen/Konfiguration_des_PEP_Http_Proxy.md#konfigurationsparameter-asl)):
  die Alle-oder-keine-Regel für `pep_asl_signer_cert`, `pep_asl_signer_key`,
  `pep_asl_ca_cert` und `pep_asl_roots_json` (fehlt genau eine, startet der PEP
  nicht), der Wert `cert` von `pep_asl_ocsp` samt dessen Standardverhalten
  (OCSP-URL aus dem Signer-Zertifikat), die Auflösung relativer Pfade gegen das
  nginx-Konfigurationsverzeichnis sowie das `store:`-Präfix, mit dem der
  ASL-Signaturschlüssel im HSM verbleibt. Die Helm-Chart-Referenz enthält dazu
  neu die Values `pepproxy.aslRootCA`, `aslOcsp` und `aslOcspTtl`
  ([ASL-Values](Referenzen/Referenz_des_Helm_Charts.md#asl-values)).
- Die Image-Referenzen des Provisioning Containers und die zugehörigen
  Vertrauensanker (CA Trustchain) sind jetzt je Umgebung (RU/RUDEV, TU, PU)
  dokumentiert. Wichtig für Betreiber: Die Chart-Vorbelegung von
  `provisioningProcessor.provisioningContainer` gilt nur für RU/RUDEV — für TU
  und PU ist der Wert samt passender Vertrauenskette
  (`imageTrustCertchainSecretRef`) zu setzen. Dokumentation:
  [Wie Sie ZETA Guard in Kubernetes konfigurieren — Provisioning Processor](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#64-provisioning-processor-image-vertrauenskette-konfigurieren).
- Neuer Helm Value `provisioningProcessor.provisioningContainerCaConfigMapRef` —
  Alternative zu `provisioningContainerCaSecretRef`, um das CA-Zertifikat der
  Provisioning-Container-Registry aus einer ConfigMap statt einem Secret zu
  mounten. Nützlich z.B. für das von OpenShifts „Configuring a custom PKI"
  bereitgestellte CA-Bundle (die öffentlichen CA-Teile sind nicht geheim).
  Secret- und ConfigMap-Referenz schließen sich aus, das Secret hat Vorrang.
  Dokumentation: [Wie Sie eine eigene OCI Registry verwenden](Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md#ca-zertifikat-für-die-registry).
- Neue Helm Values `provisioningProcessor.extraEnv`, `extraVolumes` und
  `extraVolumeMounts` am Provisioning-Processor-Init-Container ermöglichen die
  generische Einbindung der Registry-CA (oder anderen Materials) aus beliebigen
  Quellen (Secret, ConfigMap, projizierte Volumes, CSI, …).
- Neuer Helm Value `provisioningProcessor.registryCredentialsSecretRef` —
  referenziert ein bestehendes Secret mit
  Benutzername und Token und verdrahtet `PROVISIONING_CONTAINER_REGISTRY_USERNAME`
  / `PROVISIONING_CONTAINER_REGISTRY_TOKEN` in den Init-Container, sodass der
  Provisioning-Container aus Registries ohne anonymen Zugriff geladen werden kann.
  Schlüsselnamen über `usernameKey`/`tokenKey` konfigurierbar (Standard
  `username`/`token`).
  Dokumentation: [Wie Sie eine eigene OCI Registry verwenden](Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md#zugangsdaten-für-die-registry).
- Eine Referenz eigener Telemetrie-Attribute von ZETA-Guard
- Neue Anleitung [Troubleshooting & Debugging](Anleitungen/Troubleshooting_und_Debugging.md)
  für Betreiber: wo sich Logs und Metriken finden, geloggte Ereignisse und
  personenbezogene Daten, Log-Beispiele, Hinweise zu Aufbewahrung, Rotation und
  Alarmierung; die Referenz [Security-Events](Referenzen/Security-Events.md) ist
  nun im Inhaltsverzeichnis verlinkt.
- Verwendete Operatoren mit empfohlenen Versionen
- Vertrauensanker werden im laufenden Betrieb aktualisiert — standardmäßig aktiv und für
  den Produktivbetrieb vorgesehen. Benötigt Kubernetes 1.32 (OpenShift 4.19 oder
  neuer). Dokumentation:
  [Helm-Chart-Referenz – Zeitgesteuerte Aktualisierung der Vertrauensanker](Referenzen/Referenz_des_Helm_Charts.md#zeitgesteuerte-aktualisierung-der-vertrauensanker)
  und [Konfiguration des Authentication Services](Referenzen/Konfiguration_des_PDP_Services.md#aktualisierung-der-truststores-im-laufenden-betrieb).
- Neuer Helm Value `opa.rolloutRestart`. CronJob, der die OPA-Deployments zeitgesteuert per
  `kubectl rollout restart` neu startet, damit ein neuer Signatur-Schlüssel für die
  Policy-Bundles wirksam wird. OPA kann seine Trust-Anchor im Gegensatz zum
  Authentication Service nicht im laufenden Betrieb übernehmen. Dokumentation:
  [Wie Sie OPA in ZETA Guard konfigurieren](Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md#geplanter-neustart-rollout-restart).
- Mobiler Client-Flow (Vorschau, standardmäßig deaktiviert): Anmeldung von
  Versicherten mit der GesundheitsID über einen sektoralen IDP (SekIDP),
  `authorization_code`-Grant für mobile Clients und Bindung der Identität an
  eine E-Mail-Adresse. Zentraler Schalter `ZETA_OIDC_FLOW_ENABLED` (Standard:
  `false`); solange die Attestierungsprüfung mobiler Clients gemockt ist, sollte
  der Schalter in produktiven Umgebungen aus bleiben. Optionales mTLS zum SekIDP
  über die SPI-Optionen des Identity Providers. Neues Security-Event
  `authn_email_change` bei identitätsweiter E-Mail-Änderung. Dokumentation:
  [Wie der mobile Client-Flow funktioniert](Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md),
  [Konfiguration des Authentication Services](Referenzen/Konfiguration_des_PDP_Services.md)
  und [Security-Events](Referenzen/Security-Events.md).
- VAU-Betrieb des Authservers: Verschlüsselung und Integritätsprüfung der
  Keycloak-Datenbank über `authserver.dbEnc.*`. Wird der Authserver innerhalb
  einer VAU betrieben und die Datenbank außerhalb, dürfen sicherheitsrelevante
  Daten die VAU nur verschlüsselt verlassen; zusätzlich erkennt eine
  Integritätsprüfung Manipulationen am Datenbestand. Dokumentation:
  [Wie Sie ZETA Guard in Kubernetes konfigurieren – Besonderheiten VAU und Keycloak-Datenbank](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#10-besonderheiten-vau-und-keycloak-datenbank)
  und [Sicherheitsanforderungen an den Betreiber des ZETA-Guard](SicherheitsanforderungenZETAGuardBetreiber.md#betrieb-des-authservers-in-einer-vau-basierten-umgebung).
- Externer Infinispan für die horizontale Skalierung des Authservers über
  `global.infinispanExternal.*`. Statt der eingebetteten Infinispan-Instanzen
  wird ein eigener Infinispan-Pod gestartet und Keycloak für den
  „clusterless“ Modus konfiguriert; vorgesehen für Clusterszenarien mit vielen
  Keycloak-Instanzen (z.B. im Kontext von PoPP). Dokumentation:
  [Wie Sie ZETA Guard in Kubernetes konfigurieren – Externer Infinispan für horizontale Skalierung des Authservers](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#11-externer-infinispan-für-horizontale-skalierung-des-authservers).
- Notification Service dokumentiert (Vorschau, standardmäßig deaktiviert):
  Funktionsweise der Push-Benachrichtigungen vom Fachdienst über den
  ZETA-Guard und das gematik Push Gateway an mobile Clients, inklusive
  Split-Deployment (`-rs`/`-fdv`), eigener Datenbank, Pflichtwerten
  (Push-Gateway-Allowlist, Kanal-Registry) und Well-Known-Integration.
  Dokumentation:
  [Wie der Notification Service funktioniert](Anleitungen/Wie_der_Notification_Service_funktioniert.md),
  [Konfiguration des Notification Service](Referenzen/Konfiguration_des_Notification_Service.md)
  und [Wie Sie Benachrichtigungen aus dem Fachdienst versenden](Anleitungen/Wie_Sie_Benachrichtigungen_aus_dem_Fachdienst_versenden.md).
- Neue Anleitung zur dynamischen Client-Registrierung (RFC 7591): Ablauf,
  Client-Typ-Erkennung (SMC-B- vs. mobile Clients), automatisch gesetzte
  Richtlinien (DPoP-Bindung), Registrierungsstatus und Zusammenspiel mit der
  Token-Ausstellung. Dokumentation:
  [Wie die dynamische Client-Registrierung funktioniert](Anleitungen/Wie_die_dynamische_Client-Registrierung_funktioniert.md).
- Neue Anleitung zum Client-Lebenszyklus: Limits und automatische Verdrängung
  (LRU), Idle-TTLs, Widerruf von Sitzungen über die Revocation-API,
  Nachvollziehbarkeit über hash-verkettete Admin-Events sowie die
  client-seitigen Abmelde-Funktionen des SDK. Dokumentation:
  [Wie der Client-Lebenszyklus verwaltet wird](Anleitungen/Wie_der_Client-Lebenszyklus_verwaltet_wird.md).
- Neue SDK-Anleitungen (Vorschau): Verwendung des Notifications-Moduls
  (Pusher- und Kanal-Verwaltung, Token-Handling) und Umsetzung des mobilen
  Client-Flows mit dem SDK (`OidcConfig`, Browser-Anbindung, `OtpCallback`
  für die E-Mail-Bindung, `changeEmail()`). Dokumentation:
  [Wie Sie das SDK Notifications-Modul verwenden](Anleitungen/Wie_Sie_das_SDK_Notifications-Modul_verwenden.md)
  und [Wie Sie den mobilen Client-Flow mit dem ZETA SDK umsetzen](Anleitungen/Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).
- Plattform- und Feature-Matrix des SDK in der
  [SDK-Übersicht](Referenzen/SDK-Uebersicht.md): welche Funktionen
  (Kern-Auth-Flow, OIDC, Notifications, `changeEmail`) auf welchen Plattformen
  (Kotlin/Android, iOS, JVM, C#, C++, Java) verfügbar sind.

### changed

- [Konfiguration des Authentication Services](Referenzen/Konfiguration_des_PDP_Services.md)
  listet jetzt alle Umgebungsvariablen der Truststores. **Für Betreiber mit
  eigenem Deployment wichtig:** `SMCB_KEYSTORE_META_LOCATION`,
  `TPM_KEYSTORE_LOCATION` und `TPM_KEYSTORE_PASSWORD` sind Pflicht — fehlt eine
  davon, startet der Authentication Service nicht
  (`Missing environment variable »<NAME>«`).
- Das Helm Chart setzt `kubeVersion: ">=1.32.0-0"` — die unterstützte
  Plattform-Untergrenze, entsprechend OpenShift 4.19 oder neuer. Ältere Cluster
  lehnt Helm bei der Installation ab.
- Admin-API-Absicherung präzisiert: Bei gesetztem `authserver.adminHostname`
  wird nur der Pfad `/auth/admin` an den PEP-Proxy geroutet und dort mit `403`
  gesperrt; alle übrigen `/auth/*`-Pfade gehen direkt an den Authserver. Die
  Absicherung beruht ausschließlich auf Standard-Ingress-Pfad-Routing und ist
  damit unabhängig vom Ingress-Controller. Betrifft
  [Helm-Chart-Referenz](Referenzen/Referenz_des_Helm_Charts.md#admin-api-absicherung)
  und [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md).
- Korrektur zum lokalen Terraform-Modus (`use_kubernetes = false`): Es
  entfallen der `provider "kubernetes"`-Block und der Cluster-Zugang, das
  Provider-Plugin `hashicorp/kubernetes` wird von `terraform init` aber
  weiterhin geladen. Relevant für Air-Gap- und
  Registry-Whitelisting-Umgebungen.
- Beim Erreichen der maximalen Anzahl von Client-Registrierungen pro SMC-B
  (Standard: 256) löscht der ZETA-Guard automatisch die am längsten inaktive
  Registrierung des Nutzers; protokolliert als Security-Event
  `authn_client_deleted`.
- OPA-Anleitung überarbeitet:
  - PIP als einzige Policy-Quelle, Zugriff per WIF
    oder eigene Pull-Through-Registry.
  - WIF-Werte unter `gematik.workloadIdentityFederation.*`
    (statt nicht ausgewerteter `opa.….sts.*`-Keys), `resource` per Tag statt Digest,
    `keyId` für wirksame Signaturprüfung, Status-API-Pfad und Token-Renewer-Kommando.
- Inbetriebnahme-Checklisten (Pflicht/Optional, Schritt-für-Schritt) in den ReadMes
  für Fachdienst-Betreiber und -Hersteller; Platzhalter-Abschnitte (Known Issues,
  Wartung, administrative Aufgaben, DB-Skalierungsbedingungen) durch konkrete
  Inhalte bzw. Verweise ersetzt.
- Abgeschnittener Link zur Rate-Limit-Konfiguration in den Sicherheitsanforderungen
  für ZETA-Guard-Betreiber korrigiert (jetzt relativer Verweis).
- Inhaltsverzeichnis (SUMMARY) vervollständigt: Zielgruppen-Einstiege, Sicherheits-
  anforderungen, Release Notes, Telemetrie-Erklärung und VAU-Konfiguration sind
  jetzt in der Navigation verlinkt.
- Security-Events-Referenz vervollständigt: `authn_client_registration_fail`,
  `authn_client_deleted` und `authn_authorization_code_invalid` dokumentiert
  (inkl. `zeta-client.reason`-Werte); Event-Liste im Troubleshooting angeglichen.
- `global.clusterFQDN` dokumentiert (Pflichtwert für den Telemetrie-Export:
  wird als `server.address` an TI-SIEM/TI-SIM gemeldet; Chart-Default ist der
  Platzhalter „REPLACE ME").
- Begriffserklärungen für Externe ergänzt („Umsetzungsstufe 2", „PIP/PAP" in den
  drei ReadMes); interne Meilenstein-Referenzen entfernt; Widerspruch zwischen
  Telemetrie-Erklärung und Filter-Anleitung aufgelöst (Filterbedingungen sind
  anpassbar, `redaction` nicht).
- Helm-Chart-Referenz gegen die tatsächlichen Chart-Defaults korrigiert:
  CloudNativePG (`sharedBuffers` 512MB, `maxConnections` 250), JDBC-Pool
  (`dbPool` 10/100 inkl. Render-Guard-Hinweis), PoPP-Values unter
  `pepproxy.nginxConf.*`, dbEnc-Tabelle vervollständigt
  (`periodicRowChecksEnabled`, `lockdownOnError`, korrigierte Beschreibungen).
- Die SMC-B-OCSP-Sperrprüfung beim Token-Exchange ist standardmäßig fail-open:
  nur ein `REVOKED`-Zertifikat wird abgelehnt; ein nicht bestimmbarer Sperrstatus
  (Responder nicht erreichbar, Timeout oder `unknown`) wird erlaubt. Über
  `provider.smcB.ocspFailClosed: true` kann fail-closed aktiviert werden.
- Updated information regarding telemetry filtering.
- Added information regarding mandatory telemetry export to TI SIEM.
- Der Platzhalter „Notification Service konfigurieren" (Abschnitt 5 in
  [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md))
  wurde durch eine echte Konfigurationsbeschreibung ersetzt; die veralteten
  Stichpunkte zur direkten APN-/Firebase-Konfiguration entfallen (die Anbindung
  läuft über die Push-Gateway-Allowlist).
- Komponentenübersicht: Der Eintrag „TI-M Notification Service (kommt in
  Meilenstein 2)" wurde durch die tatsächliche Beschreibung des Notification
  Service (Vorschau) ersetzt.
- Well-Known-Referenz um das Resource-Dokument des Notification Service
  (RFC 9728) ergänzt; Helm-Chart-Referenz um die `notificationService.*`-Values,
  den Schalter für den mobilen Client-Flow und die SMTP-Terraform-Variablen
  erweitert; PDP-Referenz um fehlende Truststore-Variablen und Querverweise
  ergänzt.
- PEP-Header-Behandlung geändert: Die Credential-Header `Authorization`, `dpop`
  und `popp` werden zur Erfüllung von A_25669-01 jetzt an den Upstream
  weitergereicht und nicht mehr an der Upstream-Grenze entfernt. Die
  Behandlung der `ZETA-*`-Header (PEP als alleinige Quelle), der
  `Forwarded`-Header und das HTTP-500-Enforcement bei fehlendem
  `proxy_headers.conf` bleiben unverändert. Details:
  [Header-Behandlung und `proxy_headers.conf`](Referenzen/Konfiguration_des_PEP_Http_Proxy.md#header-behandlung-und-proxy_headersconf).

## Release 1.2.1

### added

- Neuer Sicherheitshinweis zur Konfiguration von Rate Limit

### changed

- Klärende Umformulierungen zur Verwenden eines Konnektor mit dem Client SDK


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


