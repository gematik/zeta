<img align="right" width="250" height="47" src="assets/images/Gematik_Logo_Flag.png"/> <br/>

# Release Notes des Produkthandbuchs

## Release 2.0.2

### added

- [Keychain des Notification Service](Referenzen/Konfiguration_des_Notification_Service.md#keychain):
  Sealing bezieht DEK und Pseudonymisierungsschlüssel aus einer HSM-gekapselten
  Keychain. Neue Values `notificationService.sealing.keychainFileName`,
  `.rotationInterval`, `.initContainerProvideKeys`, `.initContainerStoreKeys`,
  `.keychainGenerator.*` sowie `notificationService.extraVolumes` und
  `.extraVolumeMounts`; Schlüsselrotation (A_29963, A_29960) und
  Readiness-Prüfung `keychain` beschrieben.
- [Entity Statement des Guards](Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md#entity-statement-des-guards):
  `metadata.federation_entity` mit `name` und `organization_name`
  (gemSpec_IDP_Sek, Tab. 28) aus `authserver.config.entityStatement.clientName`
  und `.organizationName`. Die `redirect_uris` lassen sich über
  `authserver.config.entityStatement.redirectUris` fest vorgeben (A_25656). Die
  feste Liste ersetzt die Redirect-URIs der SekIDP-Clients des Realms; ohne
  Angabe werden sie weiterhin aus diesen abgeleitet.

### changed

- **BREAKING** [Notification Service](Referenzen/Konfiguration_des_Notification_Service.md#datenschutz-sealing-hsm-und-verschlüsselter-push):
  `notificationService.hsm.kek.dekKeyId`, `.hsm.kek.pseudonymKeyId` und
  `.sealing.dekCacheSize` entfallen. Bei aktiviertem Sealing lassen sich
  Datensätze früherer Builds nicht mehr öffnen; Start mit leerer Datenbank.
  Umgebungsvariablen entsprechend aktualisiert.
- **BREAKING** [Besonderheiten beim Update auf 2.0.x](Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md#besonderheiten-beim-update-auf-20x):
  Hinweise zu den im Authserver-Image deaktivierten Keycloak-Features (u. a.
  Account-Konsole, Device Flow, CIBA; ihre Endpunkte antworten mit `404`) und
  zum Umstieg auf die Keychain des Notification Service ergänzt.
- [Geplanter Neustart von OPA](Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md#geplanter-neustart-rollout-restart):
  Speicherlimit des CronJobs `256Mi` (vorher `64Mi`), `concurrencyPolicy:
  Forbid` und Laufzeitbegrenzung auf 5 Minuten.

## Release 2.0.1

### added

- Komponenten-Release-Notes um Keycloak Authserver, PEP Proxy, Notification
  Service und Provisioning Processor 2.0.0 sowie Helm-Chart 2.0.0 und 2.0.1
  ergänzt, mit den Breaking Changes beim Update von 1.3.x
  ([Release Notes ZETA Guard Komponenten](ReleaseNotes/ZetaGuard/ReleaseNotes.md)).
- [Besonderheiten beim Update auf 2.0.x](Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md#besonderheiten-beim-update-auf-20x):
  Breaking Changes für den Betrieb an einer Stelle, u. a. Terraform-Provider
  `keycloak/keycloak` ab 5.9.0.
- [Federation Master für den mobilen Client-Flow](Referenzen/Referenz_des_Helm_Charts.md#federation-master-für-den-mobilen-client-flow):
  `provisioningProcessor.federationMaster.*` (A_29737).
- [Datenschutz: Sealing, HSM und verschlüsselter Push](Referenzen/Konfiguration_des_Notification_Service.md#datenschutz-sealing-hsm-und-verschlüsselter-push):
  `notificationService.sealing.*`, `.hsm.*` und `.env.encryptionEnabled`.
- `notificationService.rs.mtls.enabled` in der
  [Konfiguration des Notification Service](Referenzen/Konfiguration_des_Notification_Service.md#übersicht-split-deployment-und-datenbank)
  (A_29980).
- [Speicherung am Nutzer](Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md#speicherung-am-nutzer-a_26973-02)
  (A_26973-02): KVNR, Anzeigename, Geburtsdatum, Profession-OID und
  Organisation aus dem ID-Token des SekIDP werden bei jeder Anmeldung als
  Attribute am Nutzer gespeichert und abgeglichen, bei aktiviertem Spree
  Integrity Provider verschlüsselt. Ist dieser aktiviert, aber noch nicht
  betriebsbereit, wird die Anmeldung mit HTTP 503 abgelehnt.
- [Mobiler Client-Flow](Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md):
  `GET /realms/{realm}/zeta/userinfo/email?id=<KVNR>` ist kein Stub mehr. Der
  Endpunkt gibt einem Resource Server die verifizierte E-Mail-Adresse des
  Versicherten heraus. Der Resource Server authentisiert sich per mTLS gegen
  einen eigenen Resource-Server-Truststore, ohne diesen gegen Keycloaks
  HTTPS-Truststore. Neue Umgebungsvariablen in der
  [Konfiguration des PDP Services](Referenzen/Konfiguration_des_PDP_Services.md),
  neuer Helm-Abschnitt
  [mTLS für Resource Server](Referenzen/Referenz_des_Helm_Charts.md#mtls-für-resource-server-userinfoemail)
  (`authserver.resourceServerMtls`).
- [Wie der mobile Client-Flow funktioniert](Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md#nutzerdaten-aus-dem-id-token-a_26973-03):
  neuer Abschnitt, welche Claims des SekIDP-ID-Tokens der Guard übernimmt und
  wohin sie gelangen (A_26973-03), dazu die Betriebsvoraussetzungen für den
  Identity Provider (`sekidp_client_id`, Scopes beim Federation Master,
  vertrauenswürdige Zertifikate).
- Terraform-Variable `sekidp_client_id` in der
  [Terraform-Konfiguration (PDP)](Referenzen/Referenz_des_Helm_Charts.md#terraform-konfiguration-pdp)
  dokumentiert: der öffentliche Issuer des Realms, den der IDP
  `zeta-sekidp-oidc` als `client_id` sendet. Setzen, wenn `keycloak_url` auf
  den Admin-Hostnamen zeigt — der SekIDP kann das Entity Statement sonst nicht
  abrufen. Ebenfalls neu in der Tabelle: `master_realm_frontend_url`,
  `sso_session_idle_timeout` und `sso_session_max_lifespan`. Die
  [Admin-API-Absicherung](Referenzen/Referenz_des_Helm_Charts.md#wer-den-authserver-konfigurieren-kann)
  und [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#admin-api-absichern)
  nennen `sekidp_client_id` jetzt neben `audience` als Variable, die bei
  einem Admin-Hostnamen explizit zu setzen ist.
- [Mobiler Client-Flow (OIDC)](Referenzen/Referenz_des_Helm_Charts.md#mobiler-client-flow-oidc)
  in der Helm-Chart-Referenz: `authserver.config.entityStatement.*` und
  `authserver.additionalTrustedCAs` dokumentiert.
- Neuer Abschnitt
  [Datenbank nicht erreichbar / Authserver antwortet nicht](Anleitungen/Troubleshooting_und_Debugging.md#datenbank-nicht-erreichbar--authserver-antwortet-nicht):
  warum ein Neuaufbau des Datenbank-Primary-Pods für den Authserver anders
  aussieht als ein regulärer Datenbank-Neustart (die ClusterIP bleibt gültig,
  die Pakete laufen ins Leere, es kommt kein TCP-Reset), was der Authserver seit
  Release 1.3.2 selbsttätig dagegen tut, wie Sie das über die
  `agroal_*`-Verbindungspool-Metriken diagnostizieren und wie Sie eine nach
  einer abgebrochenen Migration gehaltene Liquibase-Sperre lösen.
- Neuer Referenzabschnitt
  [Clusterinterne Kommunikation mit dem Authserver](Referenzen/Referenz_des_Helm_Charts.md#clusterinterne-kommunikation-mit-dem-authserver)
  in der Helm-Chart-Referenz: warum OIDC-Discovery und JWKS-Abruf des PEP bisher
  über den öffentlichen `pepIssuer` liefen und den Cluster verließen, und wie
  `pepproxy.nginxConf.pepInternalUrl` sie im Cluster hält, ohne die
  Token-Validierung zu verändern. Mit
  [Alternative: hostAliases](Referenzen/Referenz_des_Helm_Charts.md#alternative-hostaliases)
  für Umgebungen, in denen der interne Endpunkt nicht per Service-Namen
  adressierbar ist.
- Neue Values in der Helm-Chart-Referenz dokumentiert:
  `pepproxy.nginxConf.pepInternalUrl` und `pepproxy.hostAliases`.
- Neue Referenzseite [SBOM der ZETA-Guard-Lieferung](Referenzen/SBOM.md):
  jedes Chart-Tarball enthält eine CycloneDX-SBOM der ausgebrachten
  Container-Images (`sbom.cdx.json`). Die Seite beschreibt Zugriff, Aufbau,
  `purl`-Schema und die `zeta:`-Properties.
- [Referenz_des_Helm_Charts.md](Referenzen/Referenz_des_Helm_Charts.md)
  Neue Terraform Variablen zur Konfiguration von Mailservern (u.a. für TLS
  und Authentisierung). Betrifft ANFTI2-1040.
- SDK-Dokumentation auf den Stand des ZETA-SDK 2.0.0 gebracht; die
  [Release Notes des ZETA-SDK](ReleaseNotes/ZetaSDK/ReleaseNotes.md) enthalten
  jetzt die Version 2.0.0.
- [Wie Sie das ZETA-SDK integrieren](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md):
  neue Abschnitte
  [Änderungen in Version 2.0.0](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md#änderungen-in-version-200),
  [Attestierung](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md#attestierung)
  (hardwarebasierte Attestierung mit Android Key Attestation, Play Integrity
  und Apple App Attest; `AttestationConfig`),
  [Android und iOS](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md#android-und-ios)
  (`ZetaInit.initAndroid`, Manifest-Einträge, Network Security Configuration
  für OCSP/CRL, App-Attest-Capability) und
  [Automatisches Verhalten des SDK](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md#automatisches-verhalten-des-sdk)
  (Umgang mit `401`/`403`/`404` des PEP, Wiederholungen, ASL-Neuaufbau).
  Ergänzt sind außerdem `ZetaSdk.getVersion()`, die optionale `ZetaClock`,
  `changeEmail()` und `notifications()` in der API-Übersicht, die
  Java-Helfer `ZetaSdkClientExtension`, die Funktionsübersicht und
  Fehlerbehandlung der C-API (`ZetaSdk_getLastError`) sowie die NuGet-Pakete
  `Zeta.Sdk.Linux`, `Zeta.Sdk.Windows` und `Zeta.Sdk.MacOS` für C#.
- [Wie Sie das SDK-Notifications-Modul verwenden](Anleitungen/Wie_Sie_das_SDK_Notifications-Modul_verwenden.md):
  Entschlüsselung von Push-Nachrichten (`decryptPushNotification`) mit
  dauerhaft gespeichertem, monatlich rotierendem Schlüsselmaterial,
  Benachrichtigungs-Historie (`getNotifications`, `getNotification`),
  APNs-Integration der iOS-Demo-App und Übersicht der Exceptions.
- [Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen](Anleitungen/Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md):
  Implementierung des `AuthorizationLauncher`, Launcher der Demo-App je
  Plattform und Migrationshinweise von Version 1.3.x.
- [ReadMe für Hersteller mobiler Clients](ReadMeMobileClientHersteller.md):
  neuer Abschnitt „Integration in die App“ mit den Voraussetzungen für Android
  und iOS.
- [Wie Sie den ZETA-Demo-Client ausführen](Anleitungen/Wie_Sie_den_ZETA_Demo_client_ausführen.md):
  Abschnitt zu den mobilen Demo-Apps (Konfiguration über `zeta.env`,
  Play Integrity, FCM, APNs).
- [Wie Sie den Testdriver nutzen](Anleitungen/Wie_Sie_den_Testdriver_nutzen.md)
  und [Wie Sie den Testdriver bauen](Anleitungen/Wie_Sie_den_Testdriver_bauen.md):
  Endpunkte für Konfiguration, Notifications und den OIDC-Flow, Load-Driver,
  nativer Testdriver und Android-Testdriver.
- [Wie Sie Probleme im SDK analysieren](Anleitungen/Wie_Sie_Probleme_im_SDK_analysieren.md):
  Log-Level und Request-Logs je Sprache, Fehlermeldungen der nativen API,
  Logs der Sperrprüfung.

### changed

- **BREAKING** [Client-Management-Endpunkte](Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md#client-management-endpunkte):
  `/zeta/clients` und `/zeta/identity/email` laufen über den PEP (Scope
  `zeta:client-management`, DPoP), nicht mehr per `Client-Assertion`.
- **BREAKING** Terraform-Variable `sekidp_fedmaster_url` entfernt; die URL des
  Federation Masters kommt aus dem Provisioning Processor.
- **BREAKING** `notificationService.env.persistenceSealingEnabled` heißt
  `notificationService.sealing.enabled`.
- [Notification Service](Referenzen/Konfiguration_des_Notification_Service.md):
  Sealing und verschlüsselter Push sind keine Stubs mehr; RS-API prüft das
  Client-Zertifikat selbst.
- `pepproxy.nginxConf.noTravel`: Standardwert in der
  [Helm-Chart-Referenz](Referenzen/Referenz_des_Helm_Charts.md) auf `true` korrigiert.
- **BREAKING (ZETA-SDK 2.0.0)**
  [Mobiler Client-Flow](Anleitungen/Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md):
  `OidcConfig` erwartet statt `requestUri` die Felder `redirectUri` und
  `oidcRedirectUri` sowie statt des optionalen `authenticationCallback` den
  verpflichtenden `authorizationLauncher`. `BrowserLauncher` und
  `SystemBrowserAuthenticator` der Demo-App sind entfallen.
- [Wie Sie das ZETA-SDK integrieren](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md):
  `BuildConfig` ohne Authentifizierungs-Callback, dafür mit
  `notificationConfig`; Prüfung von `productId`/`productVersion` nach
  A_25338-01; Standard-Speicher je Plattform (unter iOS nur im
  Arbeitsspeicher, unter Android durch den Android Keystore geschützt);
  Default des Request-Log-Levels ist `NONE`, der Revocation-Cache ist
  konfigurierbar (mindestens 3600 s); `close()` löscht auch das
  `zeta_route`-Cookie. Korrigiert sind das Kotlin-Beispiel (benannte
  Parameter der `AuthConfig`), das C++-Beispiel (Feldreihenfolge von
  `ZetaSdk_AuthConfig`, neue `ZetaSdk_NetworkConfig`) und das C#-Beispiel
  (ohne die entfallene `ZetaSmcbConfig`, mit `Network` und
  `RevocationCacheDurationSeconds`). Hinweise auf die mit 1.2.2 entfernte
  SMC-B-Konnektor-Anbindung des SDK entfernt.
- [ReadMe für Primärsystem-Hersteller](ReadMePrimaersystemHersteller.md):
  Zugänge um den NuGet-Feed ergänzt, Tooling aktualisiert (Laufzeit ab
  Java 21, C# über NuGet-Pakete), Known Issues aktualisiert: Die Einschränkungen
  beim Abruf von OCSP-Responses/CRLs und bei gestapelten OCSP-Responses unter
  Android < API 37 sind seit 1.3.2 behoben; neu sind Hinweise auf die fest
  vorgegebene `platformProductId` der C-API, auf synchrone PUT-/PATCH-Aufrufe
  der C-API ohne Body, auf die Cookie-Verwaltung für Fachdienst-Aufrufe und auf
  `ZetaSdk_getLastError()`.
- [ReadMe für Hersteller mobiler Clients](ReadMeMobileClientHersteller.md):
  Toolchain auf AGP 9.3.2, Kotlin 2.4.10, Gradle 9.7.1 und SKIE 0.10.14
  aktualisiert; eigene Client-Komponenten um Browser-Anbindung, OTP-Oberfläche
  und Push-Empfang ergänzt; neue Known Issues (Speicher, CAs und Proxy unter
  iOS, Entschlüsselung im Hintergrund unter iOS, app-weit geteilte
  Hardware-Schlüssel, Browser-Anmeldung für das Token des Notification Service
  im OIDC-Flow, einmalige Neuregistrierung unter Android nach dem Update auf
  2.0.0).
- [SDK-Übersicht](Referenzen/SDK-Uebersicht.md): Verzeichnisse und
  Plattform- und Feature-Matrix um hardwarebasierte Attestierung,
  Push-Entschlüsselung und Historie sowie die neuen Test-Clients ergänzt.
- [Wie Sie den ZETA-Demo-Client ausführen](Anleitungen/Wie_Sie_den_ZETA_Demo_client_ausführen.md)
  und [Wie Sie den Testdriver nutzen](Anleitungen/Wie_Sie_den_Testdriver_nutzen.md):
  Konfigurationswerte aktualisiert (`STORAGE_AES_KEY`, `REQUIRED_ROLE_OID`,
  `ASL_PROD`, `AUTH_MODE`, `OIDC_*`); die entfallenen `SMCB_*`-Variablen sind
  entfernt.
- [Wie die dynamische Client-Registrierung funktioniert](Anleitungen/Wie_die_dynamische_Client-Registrierung_funktioniert.md)
  und [Wie der Client-Lebenszyklus verwaltet wird](Anleitungen/Wie_der_Client-Lebenszyklus_verwaltet_wird.md):
  SDK-Verhalten präzisiert (Grant-Typen je Client-Typ, Attestierungsnachweis
  bei der Registrierung, Wiederholungsregeln, Wirkung von `logout()`,
  `clearRegistration()` und `forget()`).
- [Wie der Notification Service funktioniert](Anleitungen/Wie_der_Notification_Service_funktioniert.md):
  Einschränkungen zu SDK-Entschlüsselung, Historie und APNs-Demo aktualisiert.
- [Sicherheitsanforderungen an den Client-Hersteller](SicherheitsanforderungenClientHersteller.md):
  Ablage des Client-Instanzschlüssels im Hardware-Schlüsselspeicher unter
  Android und iOS berücksichtigt.
- **BREAKING** [Mobiler Client-Flow](Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md)
  (A_26973-03): `commonName` bzw. `common_name` enthält bei Versicherten den
  Anzeigenamen aus `urn:telematik:claims:display_name`; ein ID-Token ohne diesen
  Claim wird abgelehnt. Der IDP fordert zusätzlich den Scope
  `urn:telematik:geburtsdatum` an — beim Federation Master muss der Guard mit
  diesem Scope registriert sein.
- [Terraform-Konfiguration (PDP)](Referenzen/Referenz_des_Helm_Charts.md#terraform-konfiguration-pdp):
  `config_path` und `sekidp_manage_incluster_fedmaster` sowie die Ausgaben
  `authserver_entity_statement_pubkey_pem`/`authserver_entity_statement_kid`
  entfernt, die es seit dem Wechsel auf gsi-server 8.5.1 nicht mehr gibt.
  Quickstart und Update-Anleitung erwähnen die nicht mehr erzeugte
  `sekidp-secret.tf` nicht mehr; die PDP-Konfiguration benötigt in keinem
  Modus den Provider `hashicorp/kubernetes`.
- [Inhalt des `ZETA-User-Info`-Headers](Referenzen/Konfiguration_des_PEP_Http_Proxy.md#inhalt-des-zeta-user-info-headers):
  **BREAKING** `birthdate` stammt jetzt aus dem einwilligungsabhängigen
  `birthdate`-Claim des sektoralen IDP (A_26973-03) und entfällt ohne Freigabe
  des Nutzers. Die Interimslösung mit festem Datum `1900-01-01` und die Direktive
  `pep_user_info_birthdate` sind entfernt — eine Konfiguration, die sie noch
  setzt, verhindert den Start des PEP. `commonName` enthält bei Versicherten den
  vollständigen Anzeigenamen statt der KVNR.
- [Wie Sie OPA in ZETA Guard konfigurieren](Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md#aktivieren):
  `opa.simulation.bundle.resource` ist im Bundle-Modus mit Simulation jetzt
  Pflicht. Das Chart hängt kein `-sim` mehr an `opa.bundle.resource` an, da die
  gematik Simulations-Bundles je Umgebung unterschiedlich benennt.
- [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#7-policy-enforcement-point-nginx-konfigurieren):
  Abschnitt 7 um die clusterinterne Authserver-Adresse ergänzt und die
  Beschreibung von `pepproxy.nginxConf.pepIssuer` geschärft — der Wert muss der
  öffentliche Issuer bleiben, da er der von jedem Access-Token erwartete `iss`
  ist.
- [Wie Sie Egress NetworkPolicies konfigurieren](Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md):
  Hinweis ergänzt, dass die IP des Ingress in
  `networkPolicy.egress.providerInternal.resourceServers.ipBlocks` für den
  JWK-Abruf des PEP nicht benötigt wird, wenn `pepproxy.nginxConf.pepInternalUrl`
  gesetzt ist.
- Admin-API-Absicherung erweitert: Bei gesetztem `authserver.adminHostname` wird
  neben `/auth/admin` nun auch `/auth/realms/master` auf dem Haupthostnamen mit
  `403` gesperrt — dort wird das Admin-Access-Token ausgestellt. Die
  Authserver-Konfiguration heftet zugleich die Frontend-URL des `master`-Realms
  an den Admin-Hostnamen, damit der Browser-Login der Admin Console nicht auf den
  gesperrten Pfad läuft;
  die neue Terraform-Variable `master_realm_frontend_url` überschreibt den
  abgeleiteten Wert. Der `zeta-guard`-Realm bleibt unverändert. Betrifft
  [Helm-Chart-Referenz](Referenzen/Referenz_des_Helm_Charts.md#admin-api-absicherung)
  und [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md).
- Neue Referenzabschnitte zur Admin-API:
  [Womit die Admin-API abgesichert ist](Referenzen/Referenz_des_Helm_Charts.md#womit-die-admin-api-abgesichert-ist)
  trennt, was das Chart leistet und was Keycloak beiträgt;
  [Was der Betreiber zusätzlich leisten muss](Referenzen/Referenz_des_Helm_Charts.md#was-der-betreiber-zusätzlich-leisten-muss)
  listet die sechs verbleibenden Pflichten, darunter Zugriffsbeschränkung auf den
  Admin-Hostnamen und Brute-Force-Erkennung im `master`-Realm.
  [Unterschiede vor und nach Chart 1.3.3](Referenzen/Referenz_des_Helm_Charts.md#unterschiede-vor-und-nach-chart-133)
  stellt Login-Weg, Angriffsfläche und Konfigurationsberechtigung gegenüber.
- [Helm-Chart-Referenz – Admin-API-Absicherung](Referenzen/Referenz_des_Helm_Charts.md#admin-api-absicherung):
  Versionsgrenze ergänzt. Bis einschließlich Chart 1.2.4 fehlte
  `--hostname-admin` der Kontextpfad `/auth`, wodurch die Admin-Konsole über
  den Admin-Hostnamen nicht erreichbar war; ab 1.3.0 behoben, inklusive
  Workaround für ältere Stände.
- [Wie Sie einen eigenen Ingress-Controller verwenden](Anleitungen/Wie_Sie_einen_eigenen_Ingress_Controller_verwenden.md):
  Die Pfadtabelle nennt jetzt auch den zweiten Ingress für
  `authserver.adminHostname` (`/auth` ohne PEP direkt an den Authserver), die
  Checkliste den zugehörigen Schritt.
- Die Terraform-Variable `keycloak_namespace` wird nur noch im
  Kubernetes-Modus benötigt. Im lokalen Modus (`use_kubernetes = false`)
  verlangte Terraform sie bisher, obwohl sie dort nirgends ausgewertet wird.
  Siehe
  [Quickstart – Betriebsmodi](Anleitungen/ZETA_Guard_Quickstart.md#betriebsmodi).
- [Referenz des Helm-Charts](Referenzen/Referenz_des_Helm_Charts.md#probes): die
  dokumentierten Probe-Werte sind korrigiert; `timeoutSeconds` ist jetzt
  dokumentiert, inklusive der Begründung, warum der Kubernetes-Standard von 1 s
  hier zu knapp ist und warum die Liveness-Probe bewusst datenbankunabhängig
  bleibt.
- [Referenz des Helm-Charts](Referenzen/Referenz_des_Helm_Charts.md#connection-pooling-keycloak):
  `authserver.dbPool.maxLifetime` und `authserver.db.urlProperties` ergänzt,
  dazu ein neuer Unterabschnitt zum Verhalten bei Datenbankausfall.
- [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md):
  Verhalten bei Primary-Wechsel ergänzt; bei der `authserverDb`-Tabelle steht
  jetzt, dass `KC_DB_URL_PROPERTIES` bei gesetztem `KC_DB_URL` wirkungslos ist —
  eine echte Falle im Modus `external`.
- [Wie Sie ZETA Guard aktualisieren](Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md#fehlerbilder):
  zwei Fehlerbilder ergänzt (gehaltene Liquibase-Sperre, `CrashLoopBackOff` nach
  einem Cluster-Patch). Die Startreihenfolge von Datenbank und Authserver ist
  nicht mehr relevant.
- [Deployment-Szenarien](Referenzen/Deploymentszenarien.md):
  ergänzt, was `cloudnativePg.instances: 1` für die Verfügbarkeit bedeutet.
- Für den VAU Betrieb mit externer DB wurde die Konfiguration vereinfacht. Fixt
  Teile von ANFTI2-902. Siehe
  [Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
  **Änderung notwendig**: Bitte alle eventuellen eigenen Werte auf folgenden
  Helm Values entfernen, sodass die Defaults wirksam werden:
  - `authserver.dbEnc.columnEncryptionEnabled`
  - `authserver.dbEnc.integrityChecksEnabled`
  - `authserver.dbEnc.integrityRowChecksEnabled`
  - `authserver.dbEnc.integrityTableChecksEnabled`
  - `authserver.dbEnc.periodicRowChecksEnabled`
  - `authserver.dbEnc.lockdownOnError`
  - `authserver.dbEnc.shutdownOnError`
- Einheitliche Security Contexts: Ohne eigene Values laufen jetzt alle Container
  des Charts PSS-restricted, auch PEP (nginx, Metrics-Sidecar), keychain-generator
  und der Job zur Zertifikatsübernahme. Grundlage sind die neuen chartweiten
  Defaults `defaultContainerSecurityContext` (inkl. `runAsUser: 1000`) und
  `defaultPodSecurityContext` (Seccomp `RuntimeDefault`); die Security-Context-Values
  der Komponenten enthalten nur noch Abweichungen davon, siehe
  [Referenz](Referenzen/Referenz_des_Helm_Charts.md#chartweiter-default-defaultcontainersecuritycontext).
  **Änderung notwendig auf OpenShift:**
  `defaultContainerSecurityContext.runAsUser: null` setzen, mit
  `kpiMetricsPersistence.enabled` zusätzlich die festen IDs des KPI-Prometheus, siehe
  [OpenShift-Kompatibilität](Anleitungen/ZETA_OpenShift_Kompatibilität.md).
- Adresse des Helm-Charts in Helm-Kommandos aktualisiert.
- Referenzen zur – implizit aktuellsten – `values-demo.yaml` durch Referenzen zur `values-demo.yaml` aus dem verwendeten Chart ersetzt.
- `make`-Aufrufe durch die zugrunde liegenden `helm`-, `kubectl`- und
  `terraform`-Befehle ersetzt, das Makefile des Helm-Chart-Repositorys wird
  nicht mehr benötigt:
  [Wie Sie ZETA Guard aktualisieren](Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md#realm-konfiguration-mit-terraform-anwenden),
  [Wie Sie den Cluster lokal mit KIND aufsetzen](Anleitungen/Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md),
  [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md).
- [Fehlerbehandlung gegenüber Clients](Anleitungen/Troubleshooting_und_Debugging.md#fehlerbehandlung-gegenüber-clients)
  und [`pep_require_popp`](Referenzen/Konfiguration_des_PEP_Http_Proxy.md):
  Header `zeta-error-origin: pep` dokumentiert (A_29850). Ausnahme: Bei
  PoPP-Fehlern (`PoPPMissing`, `PoPP`, `PoPPInvalidActor`) setzt der HTTP Proxy
  den Header nicht mehr, und der ZETA-Client reicht die Antwort an den Aufrufer
  durch.

## Release 1.3.3

### changed

- Hotfix-Release: Komponenten-Release-Notes um PEP Proxy 1.3.3 und ZETA Guard
  Helm-Chart 1.3.3 ergänzt
  ([Release Notes ZETA Guard Komponenten](ReleaseNotes/ZetaGuard/ReleaseNotes.md)).
  Der PEP 1.3.3 härtet die Validierung der Ziel-URL bei ASL-Subrequests; das
  Chart 1.3.3 ist bis auf das PEP-Image identisch mit 1.3.2. Alle übrigen
  Inhalte des Handbuchs sind unverändert gegenüber 1.3.2.

## Release 1.3.2

### added

- _Sicherheitsrelevant_ Hinweis für konkret notwendige Werte der DB
  Verschlüsselung bei VAU Betrieb ergänzt. Bezieht sich auf ANFTI2-902.
- Neue Anleitung
  [Wie Sie ZETA Guard aktualisieren](Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md):
  der unterstützte Update-Weg (`helm upgrade` plus PDP-Konfiguration), wie der
  Terraform-State das Update übersteht und wie Sie einen bestehenden Realm nach
  einem State-Verlust übernehmen, statt neu zu installieren. Terraform verwaltet
  ausschließlich Realm-Konfiguration — Nutzer und per DCR registrierte Clients
  liegen in der Datenbank und sind von einem Apply nie betroffen. Mit Querverweis
  aus dem [Quickstart](Anleitungen/ZETA_Guard_Quickstart.md#wann-und-wie-oft-die-pdp-konfiguration-laufen-muss).
- Neuer Abschnitt
  [Pflichtschritt: Update von 1.3.0/1.3.1 auf 1.3.2](Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md#pflichtschritt-update-von-130131-auf-132)
  in der Update-Anleitung: die korrigierte Liquibase-Migration der Tabellen
  `ZETA_USER_DATA`/`ZETA_CLIENT_DATA` verlangt vor dem `helm upgrade` das
  Löschen beider Tabellen samt Liquibase-Buchführung; dynamisch registrierte
  Clients gehen dabei verloren und registrieren sich neu.
- [Konfiguration des Notification Service](Referenzen/Konfiguration_des_Notification_Service.md):
  `notificationService.db.kind` (`NOTIFICATION_DATASOURCE_DB_KIND`, ab Image
  1.3.2 erforderlich) und die variantenspezifischen Tags
  `notificationService.rs.image.tag`/`fdv.image.tag` dokumentiert.
- Komponenten-Release-Notes um Release 1.3.2 ergänzt
  ([Release Notes ZETA Guard Komponenten](ReleaseNotes/ZetaGuard/ReleaseNotes.md)).
- AccessMode und StorageClass des Telemetry-Gateway-PVC sind über
  `telemetryGatewaySendingQueuePVCAccessModes` (Standard `[ReadWriteOnce]`) und
  `telemetryGatewaySendingQueuePVCStorageClass` konfigurierbar — `ReadWriteMany`
  für Shared-Filesystem-Storage. Beide waren vorher im Template festgeschrieben;
  `…StorageClass` war bereits dokumentiert, aber wirkungslos. Siehe
  [4. Telemetriedaten Service konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#4-telemetriedaten-service-opentelemetry-collector-konfigurieren).
- Der `ZETA-User-Info`-Header trägt für Versicherten-Token (`professionOID`
  `1.2.276.0.76.4.49`) jetzt zusätzlich das Feld `birthdate` (A_27558); bei
  SMC-B-/LEI-Token entfällt es. Da der Authorization Server bislang keinen
  `birthdate`-Claim liefert, setzt der PEP als Interimslösung einen festen Wert
  (Standard `1900-01-01`), der über die neue Direktive `pep_user_info_birthdate`
  je Umgebung überschreibbar ist. Neu dokumentiert ist auch die vollständige
  Feldliste des Headers:
  [Inhalt des `ZETA-User-Info`-Headers](Referenzen/Konfiguration_des_PEP_Http_Proxy.md#inhalt-des-zeta-user-info-headers).
- Betreiberpflicht bei eigenem Ingress dokumentiert:
  [Client-seitige Forwarding-Header verwerfen](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#client-seitige-forwarding-header-verwerfen)
  beschreibt, warum der `ip_address`-Claim aus `Forwarded`, `X-Forwarded-For`
  und `X-Real-IP` abgeleitet wird, welche eingehenden Header der mitgelieferte
  Ingress-Controller deshalb an der Außengrenze verwirft und dass dieses
  Verwerfen bei `nginxIngressEnabled: false` selbst sicherzustellen ist — sonst
  kann ein Client seine IP-Adresse wählen und die No-Travel-Prüfung umgehen.
  Mit neuem Referenzabschnitt
  [Client-IP-Ermittlung und Forwarding-Header](Referenzen/Referenz_des_Helm_Charts.md#client-ip-ermittlung-und-forwarding-header).
- Neue Anleitung
  [Wie Sie einen eigenen Ingress Controller verwenden](Anleitungen/Wie_Sie_einen_eigenen_Ingress_Controller_verwenden.md):
  welche der am mitgelieferten F5 NIC konfigurierten Einstellungen eine Funktion
  des ZETA Guard tragen und deshalb nachzubilden sind (Sitzungsaffinität für ASL
  und Nonces, WebSocket-Upgrade, TLS zum Authserver, Verwerfen der
  Forwarding-Header, Sperre des Revocation-Endpunkts), welche dem AFO-Nachweis
  dienen und welche reine Betriebsparameter des NIC sind. Mit Checkliste und
  Pfadtabelle für eigene Ingress-Ressourcen.
- Neuer Referenzabschnitt
  [Ingress](Referenzen/Referenz_des_Helm_Charts.md#ingress) in der
  Helm-Chart-Referenz: `nginx-ingress.enabled` (installiert den Controller),
  `nginxIngressEnabled` (rendert nur die F5-Annotationen) und `ingressEnabled`
  (erzeugt die Ingress-Ressourcen) sind drei unabhängige Schalter; dazu
  `nginxIngressLbMethod`, `nginxIngressHsm`, `ingressClassName` und die
  Annotations-Values.
- [Komponentenübersicht](Referenzen/Komponentenuebersicht.md) um eine Tabelle der
  optionalen Komponenten erweitert: Helm-Schalter, Funktion und Folge des
  Verzichts — Ingress Controller, Telemetriedaten Service, gematik-Anbindung,
  KPI-Persistenz, Notification Service, OPA-Simulation, NetworkPolicies, Istio,
  cert-manager-Issuer, Admin-Hostname, externe Datenbank, externer Infinispan.

### changed

- Fehlermeldungen des PEP bei Fehlkonfiguration nennen jetzt die betroffene
  Direktive. Bisher stand dort wörtlich ``$name`` — jede Fehlkonfiguration
  protokollierte ``nginx: [emerg] `$name`: …``, unabhängig von der Direktive.
  Jetzt z.B. ``nginx: [emerg] `pep_user_info_birthdate`: invalid date
  "01.01.1900", expected YYYY-MM-DD``. Wenn Sie Logauswertungen oder
  SIEM-Regeln auf diesen Text stützen, passen Sie sie an. Die `on`/`off`- und
  Sekunden-Direktiven melden zudem einheitlich, was erwartet wird.
- Ein unlesbarer Wert von `pep_asl_ocsp` (weder `off`/`cert` noch eine
  interpretierbare URL) brach den nginx-Start bisher mit einem Panic ab; jetzt
  wird er wie jede andere Fehlkonfiguration als `[emerg]` mit Angabe der
  Direktive abgelehnt.
- `opa.logDecisions` ist standardmäßig `false`: Decision-Logs gehen nur noch an
  das Telemetry-Gateway, nicht mehr in das Konsolen-Log der OPA-Pods. Angepasst
  in [Referenz des Helm-Charts](Referenzen/Referenz_des_Helm_Charts.md#opa-policy-engine)
  und [Troubleshooting](Anleitungen/Troubleshooting_und_Debugging.md).
- Die `*/dienst_hersteller`-Pipelines des Telemetry-Gateways liefern keine rein
  sicherheitsbezogenen Signale mehr (Attack-Detection-Events, `authn_*`-Events,
  OPA Decision-Logs, Metriken `attack.detection.*`/`zeta_guard_kpi.*`,
  Span-Attribut `app.installation.id`; A_28960). Beschrieben in
  [Wie der Telemetrie-Daten Service funktioniert](Erklärungen/Wie_der_Telemetrie-Daten_Service_funktioniert.md).
- `authserver.provider.smcB.ocspFailClosed` wirkt erst ab Chart 1.3.2 — in
  1.3.0/1.3.1 wurde der Wert nicht an den Authserver durchgereicht. Hinweis in
  der [Referenz des Helm-Charts](Referenzen/Referenz_des_Helm_Charts.md).
- `global.noProxy`: ein führender Punkt am **ersten** Eintrag wurde bis Chart
  1.3.1 nicht in das `http.nonProxyHosts`-Format konvertiert. Hinweis mit
  Workaround für ältere Charts in
  [Wie Sie einen Forward Proxy konfigurieren](Anleitungen/Wie_Sie_einen_Forward_Proxy_konfigurieren.md#empfehlungen-für-noproxy).
- Telemetrie-Doku präzisiert: die Sending-Queue wird nur für die beiden an die
  gematik sendenden Exporter (`otlp_grpc/ti_siem`, `otlp_grpc/ti_sim`) auf den
  PVC persistiert, nicht für alle Exporter. Betrifft
  [4. Telemetriedaten Service konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#4-telemetriedaten-service-opentelemetry-collector-konfigurieren)
  und [Wie der Telemetrie-Daten Service funktioniert](Erklärungen/Wie_der_Telemetrie-Daten_Service_funktioniert.md#resilienz).
- [Wie Sie ZETA Guard auf OpenShift betreiben](Anleitungen/ZETA_OpenShift_Kompatibilität.md):
  Schritt 3 korrigiert. Für das Telemetry-Gateway reicht es **nicht**, `runAsUser`
  einfach wegzulassen — das Chart setzt dort `runAsUser: 1000` und `fsGroup: 1000` als
  Default, und Helm merged Maps. Beide Werte müssen explizit auf `null` gesetzt
  werden. Neuer Schritt 4 zur StorageClass des Sending-Queue-PVC ergänzt.
- [Referenz des Helm-Charts](Referenzen/Referenz_des_Helm_Charts.md#security-contexts):
  Die pauschale Aussage, `runAsUser` werde standardmäßig nicht gesetzt, gilt nicht
  für das Telemetry-Gateway — Ausnahme dokumentiert.
- Telemetrie-Anleitung: Hinweis auf ggf. login-pflichtigen Zugang zum
  gematik-Onboarding-Wiki ergänzt und beschrieben, welche Werte (TI-SIEM-/
  TI-SIM-Audiences und Service-Accounts, WIF-Pool/Projektnummer/Provider) man
  aus dem Onboarding-Prozess erhält.
- Die Terraform-Variable `audience_scope_name` ist jetzt **erforderlich** und hat
  keinen Standardwert mehr — der Name des Audience-Scopes muss in jeder Stage
  gesetzt werden. Angepasst in
  [Quickstart](Anleitungen/ZETA_Guard_Quickstart.md#2-pdp-konfigurieren),
  [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
  und der [Helm-Chart-Referenz](Referenzen/Referenz_des_Helm_Charts.md).
- Die Tabelle der Terraform-Variablen in der Helm-Chart-Referenz führt jetzt
  alle Variablen der PDP-Konfiguration mit ihren Standardwerten.
- Im lokalen Modus (`use_kubernetes = false`) wird der Kubernetes-Provider nicht
  mehr benötigt und von `terraform init` auch nicht mehr heruntergeladen.
  Dokumentation angepasst in
  [Quickstart](Anleitungen/ZETA_Guard_Quickstart.md#2-pdp-konfigurieren) und
  [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md).
- `enable_sekidp = true` funktioniert in beiden Betriebsmodi, also auch mit
  `use_kubernetes = false`. Cluster-Zugriff benötigt allein der Schlüsselabgleich
  mit dem mitgelieferten Test-Fedmaster; die neuen Ausgaben
  `authserver_entity_statement_pubkey_pem` und `authserver_entity_statement_kid` liefern
  den Schlüssel für jeden anderen Fedmaster. Im Kubernetes-Modus überspringt die
  neue Variable `sekidp_manage_incluster_fedmaster = false` den Abgleich dafür.
  Siehe
  [Terraform-Konfiguration (PDP)](Referenzen/Referenz_des_Helm_Charts.md#terraform-konfiguration-pdp).
- Der Fake-SekIDP-Testrealm ist entfallen, zusammen mit den Terraform-Variablen
  `use_fake_sekidp_testrealm`, `dummy_client_for_fake_sekidp_clientsecret` und
  `dummy_user_for_fake_sekidp_password`. Für Tests ohne echten sektoralen IDP
  dient das `sekidp`-Subchart. Die nächste PDP-Konfiguration entfernt den Realm;
  seine Client-Policy nahm `authorization_code`-Clients von der DPoP-Bindung
  aus, diese Ausnahme entfällt damit ebenfalls.
- Für die PDP-Konfiguration wird jetzt **Terraform 1.11 oder neuer** benötigt.
  Die Keycloak-Admin-Zugangsdaten landen nicht mehr im Terraform-State: sie sind
  als `ephemeral` deklariert, in beiden Betriebsmodi erforderlich und müssen bei
  jedem Terraform-Aufruf bereitgestellt werden. Terraform liest das Secret
  `authserver-admin` nicht mehr selbst — das neue Skript
  `terraform/authserver/scripts/kc-admin-env.sh` füllt die Variablen daraus.
  Siehe
  [Quickstart – Terraform Variablen definieren](Anleitungen/ZETA_Guard_Quickstart.md#terraform-variablen-definieren).
- Telemetrie-Doku korrigiert: Beispiel-Pipelines an den aktuellen Chart-Stand
  angeglichen (Connector `spanmetrics` in Receiver- und Exporter-Listen
  ergänzt), Warnung + vollständige Beispiele für `extraVolumes`/`-Mounts`
  (Helm ersetzt Listen — Token-Export und Sending-Queue brachen sonst),
  Collector-Manifest-Links aktualisiert; Telemetrie-Attribute
  (`gematik.zeta.kind`-Wert `spanmetrics`, Quelle von `zeta.client.id/ip`) und
  Security-Events-Referenz (Attack-Event-Endpoint) präzisiert.

### removed

- Anleitung zum Filtern von Telemetrie, die nicht mehr benötigt wird, und nicht
  verwendet werden darf.

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
- Das Helm-Chart setzt `kubeVersion: ">=1.32.0-0"` — die unterstützte
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


