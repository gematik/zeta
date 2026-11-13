# Wie der mobile Client-Flow funktioniert

Der mobile Client-Flow erlaubt Versicherten die Anmeldung am ZETA-Guard mit
ihrer GesundheitsID über einen sektoralen IDP (SekIDP) statt mit einer SMC-B. Er
umfasst die Anbindung an die OpenID-Föderation, einen `authorization_code`-Grant
für mobile Clients und die Bindung der Identität an eine E-Mail-Adresse.

Der gesamte Flow ist über die Umgebungsvariable **`ZETA_OIDC_FLOW_ENABLED`**
geschaltet (Standard: `false`). Solange sie nicht gesetzt ist, verhält sich der
Guard wie bisher; alle unten beschriebenen Endpunkte und Provider sind dann
inaktiv.

Die Umsetzung auf Client-Seite beschreibt
[Wie Sie den mobilen Client-Flow mit dem ZETA-SDK umsetzen](Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).

## Ablauf

1. **Registrierung:** Ein Client, der sich per Dynamic Client Registration **mit
   Redirect-URIs** registriert, wird als mobiler Client eingerichtet: Er erhält den
   Browser-Flow `zeta-mobile` (erzwungene SekIDP-Weiterleitung ohne Login-Maske),
   die E-Mail-Binding-Scopes und Standard-Token-Exchange. Details zur
   Registrierung in
   [Wie die dynamische Client-Registrierung funktioniert](Wie_die_dynamische_Client-Registrierung_funktioniert.md).
2. **Anmeldung über den SekIDP (A_29660):** Der Client startet einen
   Authorization Request (PAR) mit den zusätzlichen Parametern `idp_iss`
   (gewählter sektoraler IDP) und `oidc_redirect_uri` (Callback der App, muss eine
   registrierte Redirect-URI sein). Der Identity Provider `zeta-sekidp-oidc`
   ermittelt die PAR-, Authorization- und Token-Endpunkte aus dem Entity Statement
   des SekIDP, prüft die Vertrauenskette über den Federation Master und leitet den
   Nutzer per PAR (PKCE S256, Nonce, `acr_values=gematik-ehealth-loa-high`) weiter.
   Angefordert werden die Scopes `urn:telematik:display_name`,
   `urn:telematik:versicherter`, `urn:telematik:geburtsdatum` und `openid`.
   Das verschlüsselte ID-Token (ECDH-ES/A256GCM) wird mit dem ENC-Schlüssel des
   Realms entschlüsselt; die ES256-Signatur wird immer gegen die `signed_jwks_uri`
   des IDP geprüft (A_22861). Welche Claims der Guard daraus übernimmt, zeigt
   [Nutzerdaten aus dem ID-Token](#nutzerdaten-aus-dem-id-token-a_26973-03). Der
   Benutzername ist ein Hash der KVNR mit geheimem Pepper
   (`SMCB_HASHING_PEPPER`, siehe
   [Konfiguration des PDP Services](../Referenzen/Konfiguration_des_PDP_Services.md)).
3. **Token-Ausstellung (A_29672):** Der `authorization_code`-Grant prüft den
   Registrierungsstatus des Clients:
   - Status `CONFIRMED` → OPA-Autorisierung, danach der vollwertige Token-Satz.
   - sonst → ein **reduziertes E-Mail-Binding-Token**: 300 s Lebensdauer, kein
     Refresh-Token, Audience `zeta-guard-as`, Scope `zeta:email-verify` und —
     nur bei einer Identität ohne verifizierte Adresse — `zeta:email-binding`.
     Die Token-Antwort enthält `binding_mode`
     (`collect_email` oder `verify_otp`) und bei `verify_otp` einen `email_hint`;
     in diesem Fall wird sofort ein OTP an die bereits gebundene Adresse gemailt.
4. **E-Mail-Bindung:** Mit dem reduzierten Token ruft die App über den PEP auf
   (unveränderter Pfad; der PEP prüft Token, DPoP und Scope und reicht den
   Aufrufer als `zeta-client-data` weiter):
   - `POST /realms/{realm}/zeta/identity/bind-email` (Scopes
     `zeta:email-binding` und `zeta:email-verify`, Formfeld `email`) — speichert
     die Adresse und verschickt ein sechsstelliges OTP mit 300 s Gültigkeit. Hat
     die Identität bereits eine verifizierte Adresse, antwortet ZETA mit dem
     Statuscode `409` (`email_already_bound`),
   - `POST …/bind-email/resend` (Scope `zeta:email-verify`),
   - `POST …/bind-email/verify` (Scope `zeta:email-verify`, Formfeld `code`) —
     markiert die Adresse als verifiziert, Registrierung → `CONFIRMED`, Antwort
     `{"status":"bound"}`. Ein Code kann nur die E-Mail-Adresse bestätigen, an
     die er verschickt wurde; sonst lautet die Antwort `400` (`invalid_code`).
5. **Token Exchange:** Der Exchange `zeta-email-binding-token-exchange` tauscht
   das reduzierte Token nach bestätigter Bindung gegen den vollwertigen Token-Satz;
   die ursprünglich per PAR angeforderten Scopes werden wiederhergestellt und die
   OPA-Autorisierung läuft erneut. Der Exchange verlangt einen DPoP-Proof mit
   dem Schlüssel, an den das reduzierte Token gebunden ist.

## Nutzerdaten aus dem ID-Token (A_26973-03)

Der Guard übernimmt folgende Claims aus dem ID-Token des SekIDP in die
Nutzer-Daten der Session. Von dort gelangen sie ins Access-Token und über den
PEP in den Header `ZETA-User-Info` (siehe
[Inhalt des `ZETA-User-Info`-Headers](../Referenzen/Konfiguration_des_PEP_Http_Proxy.md#inhalt-des-zeta-user-info-headers)).

| ID-Token-Claim                      | Access-Token-Claim   | `ZETA-User-Info`   | Fehlt der Claim                       |
|-------------------------------------|----------------------|--------------------|---------------------------------------|
| `urn:telematik:claims:id` (KVNR)    | `sub`                | `identifier`       | Anmeldung wird abgelehnt              |
| `urn:telematik:claims:profession`   | `profession_oid`     | `professionOID`    | Claim entfällt                        |
| `urn:telematik:claims:organization` | `organization_name`  | `organizationName` | Claim entfällt                        |
| `urn:telematik:claims:display_name` | `common_name`        | `commonName`       | Anmeldung wird abgelehnt              |
| `birthdate`                         | `birthdate`          | `birthdate`        | Claim entfällt — kein Fehler          |

- `commonName` ist der vollständige Anzeigename des Versicherten inklusive Titel
  und Namenszusätzen, nicht mehr die KVNR. Denselben Wert erhält die
  OPA-Policy als `user_info.commonName`.
- `birthdate` (Format `YYYY-MM-DD`) gibt der SekIDP nur frei, wenn der Nutzer
  eingewilligt hat. Ein Wert, der kein gültiges Datum in diesem Format ist,
  wird mit einer Warnung verworfen, statt die Anmeldung abzubrechen.

### Speicherung am Nutzer (A_26973-02)

Zusätzlich zur Session speichert der Guard KVNR, Anzeigename, Geburtsdatum,
Profession-OID und Organisation dauerhaft als Attribute am Keycloak-Nutzer
(`zetaguard.mobileuser.kvnr`, `.display_name`, `.birthdate`, `.profession_oid`,
`.organization`). `acr` und `amr` beschreiben nur die einzelne Anmeldung und
bleiben in der Session.

- Der Guard gleicht die Attribute bei jeder Anmeldung mit dem ID-Token ab:
  Geänderte Werte werden aktualisiert, fehlende entfernt. Zieht der Nutzer etwa
  seine Einwilligung zum Geburtsdatum zurück, verschwindet es mit der nächsten
  Anmeldung auch aus der Datenbank.
- Ist der [Spree Integrity Provider](../Referenzen/Konfiguration_VAU.md)
  aktiviert, liegen die Werte verschlüsselt in der Datenbank — er verschlüsselt
  die Werte aller Nutzer-Attribute. Solange er aktiviert, aber noch nicht
  betriebsbereit ist, lehnt der Guard die Anmeldung mit HTTP 503
  (`server_error`) ab, damit keine Nutzerdaten unverschlüsselt gespeichert
  werden.

## Entity Statement des Guards

Unter `GET /realms/{realm}/.well-known/openid-federation` liefert der Guard sein
eigenes Entity Statement (Compact JWS, `typ: entity-statement+jwt`, ES256,
Gültigkeit 3600 s) gemäß A_23034-02, mit dem Content-Type
`application/entity-statement+jwt`. Die RP-Metadaten weisen ausschließlich PAR
und `self_signed_tls_client_auth` aus, enthalten die Schlüssel für die
ID-Token-Verschlüsselung sowie die zulässigen PAR-Scopes (A_29660). Als
Redirect-URIs (A_25656) listet der Guard die der SekIDP-Clients des Realms. Ist
`authserver.config.entityStatement.redirectUris` gesetzt, ersetzt diese feste
Liste die Redirect-URIs der SekIDP-Clients vollständig: Die Redirect-URI eines
später registrierten Clients fehlt dann im Entity Statement, und der SekIDP lehnt
dessen Anfragen ab. Die wirksame Liste steht beim Start im Log des Authservers
(`Entity statement config: … redirect_uris=…`). Daneben tragen die
`federation_entity`-Metadaten `name` und `organization_name` (gemSpec_IDP_Sek,
Tab. 28).

## OPA-Autorisierung und Token-Inhalte

- Das OPA-Gate deckt jetzt auch den `authorization_code`-Grant ab. Die
  Policy-Entscheidung (Token-Lebensdauern und Eingaben) wird an der Session
  gespeichert, beim `refresh_token`-Grant erneut an OPA gegeben und vom
  Access-Token-Mapper für die vom PDP vorgegebenen Lebensdauern gelesen (A_28527).
- Bei mobilen Sessions ist die **KVNR** das Token-Subject, `common_name` der
  Anzeigename und `birthdate` das freigegebene Geburtsdatum (siehe
  [Nutzerdaten aus dem ID-Token](#nutzerdaten-aus-dem-id-token-a_26973-03)); die
  Produkt-Claims stammen aus dem bei der Registrierung hinterlegten Client
  Statement.
  Refresh-Tokens bleiben DPoP-gebunden (A_25663).
- Die Professions-Liste der OPA-Daten enthält zusätzlich `1.2.276.0.76.4.49`
  (Versicherte).

## Client-Management-Endpunkte

Wie Registrierungen insgesamt ablaufen, verdrängt und widerrufen werden,
beschreibt
[Wie der Client-Lebenszyklus verwaltet wird](Wie_der_Client-Lebenszyklus_verwaltet_wird.md).

Die Endpunkte zur Verwaltung der Clients und der E-Mail-Adresse einer Identität
liegen hinter dem PEP. Der PEP prüft Access-Token, DPoP-Bindung, den Scope
`zeta:client-management` (bei der Registrierung als Default-Scope vergeben),
No-Travel und Sperrliste, aber kein PoPP-Token. Der Authserver übernimmt den
Aufrufer aus dem vom PEP gesetzten Header `zeta-client-data` und prüft selbst
kein Token; Fehler beantwortet er als `application/problem+json`. Die Routen
gibt es nur bei `authserver.config.oidcFlowEnabled: true`. Die
Authserver-Pfade `/auth/realms/zeta-guard/zeta/clients` und
`…/zeta/identity/email` sind von außen gesperrt und antworten mit 404.

- `GET /zeta/clients` — listet die Clients (Geräte) der Identität mit
  `client_id` und `name`.
- `DELETE /zeta/clients/{client_id}` — entfernt einen Client, z. B. ein
  verlorenes Gerät. Keycloak-Client und ZETA-Daten werden gelöscht, seine
  Sessions beendet und deren Session-IDs über die Sperrliste an die PEPs
  gemeldet; verbleibende Access-Tokens des Geräts werden dadurch abgelehnt.
- `POST /zeta/identity/email` — identitätsweite E-Mail-Änderung (A_29912),
  Body `{"new_email": …}`. Die neue Adresse wird nur vorgemerkt, an sie geht ein
  Einmalcode; Antwort `202` mit `status: pending` und `email_hint`. Die bisherige
  Adresse bleibt bis zur Bestätigung gültig. Mit `POST /zeta/identity/email/verify`
  (Formfeld `code`) wird die Änderung abgeschlossen, `POST …/email/resend`
  verschickt den Code erneut. Nach der Bestätigung wird die bisherige Adresse
  benachrichtigt (A_25750), parallele Registrierungen der Identität mit offener
  OTP-Challenge werden entfernt, und es entsteht das Security-Event
  `authn_email_change`
  (siehe [Security-Events](../Referenzen/Security-Events.md)). Auch hier kann
  ein Code nur die E-Mail-Adresse bestätigen, an die er verschickt wurde.
- `GET /realms/{realm}/zeta/userinfo/email?id=<KVNR>` — gibt einem Resource
  Server die **verifizierte** E-Mail-Adresse des Versicherten heraus
  (`{"email": "…"}`). Der Resource Server authentisiert sich per mTLS. Seine
  Zertifikatskette muss zu einem Zertifikat des Resource-Server-Truststores
  führen; ohne eigenen Truststore gilt Keycloaks HTTPS-Truststore (siehe
  [Konfiguration des PDP Services](../Referenzen/Konfiguration_des_PDP_Services.md)).
  Fehlt das Zertifikat oder ist es nicht vertrauenswürdig, lautet die Antwort 401.
  Fehlt die Kennung, ist sie keine KVNR (ein Großbuchstabe und neun Ziffern),
  ist der Nutzer unbekannt oder die Adresse noch nicht bestätigt, lautet sie
  einheitlich 404. Beide Antworten haben keinen Body.

## Optionales mTLS zum SekIDP (A_23183)

Standardmäßig deaktiviert. Aktivierung über die SPI-Optionen des Identity
Providers (siehe
[Konfiguration des PDP Services](../Referenzen/Konfiguration_des_PDP_Services.md)):
`…MTLS_ENABLED`, `…MTLS_KEYSTORE_LOCATION`, `…MTLS_KEYSTORE_PASSWORD`. Der
Keystore muss PKCS12 sein und genau einen Eintrag enthalten; Store- und
Schlüsselpasswort sind identisch. Nur PAR- und Token-Requests laufen über den
mTLS-Client; das Client-Zertifikat wird dann im Entity Statement des Guards
(`openid_relying_party.jwks`, `x5c`) veröffentlicht, damit der SekIDP es
matchen kann. Das Server-Vertrauen kommt aus `conf/truststores` (CA des SekIDP
dort ablegen). Unvollständige Konfiguration bricht den Start ab (fail closed).

## Betriebsvoraussetzungen

- `ZETA_OIDC_FLOW_ENABLED=true` sowohl am Keycloak-Container als auch am
  Konfigurations-Container; die zugehörigen Setup-Skripte überspringen sich
  selbst, wenn der Schalter aus ist.
- Den Identity Provider `zeta-sekidp-oidc` legt die PDP-Konfiguration an
  (Terraform-Variablen `enable_sekidp` und `sekidp_client_id`, siehe
  [Terraform-Konfiguration (PDP)](../Referenzen/Referenz_des_Helm_Charts.md#terraform-konfiguration-pdp)).
  Als `client_id` sendet der IDP den öffentlichen Issuer des Realms; der SekIDP
  lädt darüber das Entity Statement des Guards. Zeigt `keycloak_url` auf den
  Admin-Hostnamen, setzen Sie `sekidp_client_id` auf den öffentlichen Issuer
  (`https://<host>/auth/realms/zeta-guard`), sonst kann der SekIDP das Entity
  Statement nicht abrufen.
- Die URL des Federation Masters liest Keycloak aus `federation-master.json`
  (`FEDERATION_MASTER_LOCATION`, A_29737), die der Provisioning Processor aus
  dem Provisioning-Container erzeugt. Im Helm-Betrieb dafür
  `provisioningProcessor.federationMaster.enabled` und `.environment` setzen,
  siehe
  [Federation Master für den mobilen Client-Flow](../Referenzen/Referenz_des_Helm_Charts.md#federation-master-für-den-mobilen-client-flow);
  fehlt die Datei, startet Keycloak nicht.
- Beim Federation Master muss der Guard als Relying Party mit allen
  angeforderten Scopes registriert sein (siehe [Ablauf](#ablauf), Schritt 2),
  sonst lehnt der SekIDP den PAR mit `invalid_scope` ab.
- Keycloak ruft Federation Master und SekIDP selbst per HTTPS auf. Deren
  Zertifikate müssen vertrauenswürdig sein; eine eigene CA hinterlegen Sie über
  [`authserver.additionalTrustedCAs`](../Referenzen/Referenz_des_Helm_Charts.md#mobiler-client-flow-oidc).
- SMTP muss im Realm konfiguriert sein, sonst schlägt `bind-email` beim
  OTP-Versand fehl.
- Der Realm benötigt die Schlüsselprovider `ecdsa-generated` (P-256, signiert das
  Entity Statement) und `ecdh-generated` (ECDH-ES, entschlüsselt das ID-Token des
  SekIDP).
- Die Datenbankmigration ergänzt in `ZETA_CLIENT_DATA` die Spalten
  `CLIENT_AUTH_METHOD` (Standard `SMC_B`) und `CLIENT_REGISTRATION_STATUS` —
  additiv und für ein Rolling Upgrade unkritisch.
- Neue Felder im Well-Known-Dokument: `pushed_authorization_request_endpoint`,
  `require_pushed_authorization_requests`, `redirection_endpoint`
  (Broker-Callback, A_29672), `revocation_endpoint` (A_29996) und
  `api_versions_supported` (A_29691).

## Aktueller Stand und Einschränkungen

- **Die Attestierung mobiler Clients ist gemockt:** Jede Registrierung mit
  Redirect-URIs wird akzeptiert und erhält ein fest hinterlegtes
  Client Statement (`product_id=demo_client`, Plattform `apple`). Alle
  Produkt- und Posture-Eingaben an OPA für mobile Clients stammen aus diesem
  Mock. `ZETA_OIDC_FLOW_ENABLED` sollte in produktiven Umgebungen deaktiviert
  bleiben, bis die echte Attestierungsprüfung umgesetzt ist.
- `GET /zeta/userinfo/email` prüft die Zertifikatskette des Resource Servers
  **ohne Sperrprüfung** (kein OCSP). Darüber hinaus gibt es keine Einschränkung
  auf bestimmte Resource Server: Wem vertraut wird, legt allein der Inhalt des
  Truststores fest.
- Bei der E-Mail-Änderung wird `idp_step_up` entgegengenommen, aber nicht
  ausgewertet (A_29911).
- Für `verify` und `resend` (E-Mail-Bindung und E-Mail-Änderung) gibt es noch
  **keine Versuchsbegrenzung** (Rate Limiting).
- OTP- und Benachrichtigungs-Mails sind fest hinterlegte englische Texte
  (keine Templates, keine Internationalisierung).
- `require_pushed_authorization_requests: true` wird ausgewiesen, aber noch
  nicht pro Client erzwungen.
- Für Testumgebungen mit eigener Föderation lässt sich die URL des Federation
  Masters über `provisioningProcessor.federationMaster.devModeUrl` überschreiben,
  auch mit `http://`; produktive Umgebungen beziehen sie aus dem
  Provisioning-Container.
