# Wie der mobile Client-Flow funktioniert

Der mobile Client-Flow erlaubt Versicherten die Anmeldung am ZETA Guard mit ihrer
GesundheitsID über einen sektoralen IDP (SekIDP) statt mit einer SMC-B. Er umfasst
die Anbindung an die OpenID-Föderation, einen `authorization_code`-Grant für mobile
Clients und die Bindung der Identität an eine E-Mail-Adresse.

Der gesamte Flow ist über die Umgebungsvariable **`ZETA_OIDC_FLOW_ENABLED`**
geschaltet (Standard: `false`). Solange sie nicht gesetzt ist, verhält sich der
Guard wie bisher; alle unten beschriebenen Endpunkte und Provider sind dann inaktiv.

Die Umsetzung auf Client-Seite beschreibt
[Wie Sie den mobilen Client-Flow mit dem ZETA SDK umsetzen](Wie_Sie_den_mobilen_Client-Flow_mit_dem_ZETA_SDK_umsetzen.md).

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
   Das verschlüsselte ID-Token (ECDH-ES/A256GCM) wird mit dem ENC-Schlüssel des
   Realms entschlüsselt; die ES256-Signatur wird immer gegen die `signed_jwks_uri`
   des IDP geprüft (A_22861). Der Benutzername ist ein Hash der KVNR mit geheimem
   Pepper (`SMCB_HASHING_PEPPER`, siehe
   [Konfiguration des PDP Services](../Referenzen/Konfiguration_des_PDP_Services.md)).
3. **Token-Ausstellung (A_29672):** Der `authorization_code`-Grant prüft den
   Registrierungsstatus des Clients:
   - Status `CONFIRMED` → OPA-Autorisierung, danach der vollwertige Token-Satz.
   - sonst → ein **reduziertes E-Mail-Binding-Token**: 300 s Lebensdauer, kein
     Refresh Token, Audience `zeta-guard-as`, Scopes nur `zeta:email-binding` /
     `zeta:email-verify`. Die Token-Antwort enthält `binding_mode`
     (`collect_email` oder `verify_otp`) und bei `verify_otp` einen `email_hint`;
     in diesem Fall wird sofort ein OTP an die bereits gebundene Adresse gemailt.
4. **E-Mail-Bindung:** Mit dem reduzierten Token ruft die App auf:
   - `POST /realms/{realm}/zeta/identity/bind-email` (Scope `zeta:email-binding`,
     Formfeld `email`) — speichert die Adresse und verschickt ein sechsstelliges
     OTP mit 300 s Gültigkeit,
   - `POST …/bind-email/resend` (Scope `zeta:email-verify`),
   - `POST …/bind-email/verify` (Scope `zeta:email-verify`, Formfeld `code`) —
     markiert die Adresse als verifiziert, Registrierung → `CONFIRMED`, Antwort
     `{"status":"bound"}`.
5. **Token Exchange:** Der Exchange `zeta-email-binding-token-exchange` tauscht
   das reduzierte Token nach bestätigter Bindung gegen den vollwertigen Token-Satz;
   die ursprünglich per PAR angeforderten Scopes werden wiederhergestellt und die
   OPA-Autorisierung läuft erneut.

## Entity Statement des Guards

Unter `GET /realms/{realm}/.well-known/openid-federation` liefert der Guard sein
eigenes Entity Statement (Compact JWS, `typ: entity-statement+jwt`, ES256,
Gültigkeit 3600 s) gemäß A_23034-02. Die RP-Metadaten weisen ausschließlich PAR
und `self_signed_tls_client_auth` aus, enthalten die Schlüssel für die
ID-Token-Verschlüsselung sowie die zulässigen PAR-Scopes (A_29660); die
Redirect-URIs der Clients des Realms werden gemäß A_25656 gelistet.

## OPA-Autorisierung und Token-Inhalte

- Das OPA-Gate deckt jetzt auch den `authorization_code`-Grant ab. Die
  Policy-Entscheidung (Token-Lebensdauern und Eingaben) wird an der Session
  gespeichert, beim `refresh_token`-Grant erneut an OPA gegeben und vom
  Access-Token-Mapper für die vom PDP vorgegebenen Lebensdauern gelesen (A_28527).
- Bei mobilen Sessions ist die **KVNR** das Token-Subject; die Produkt-Claims
  stammen aus dem bei der Registrierung hinterlegten Client Statement.
  Refresh Tokens bleiben DPoP-gebunden (A_25663).
- Die Professions-Liste der OPA-Daten enthält zusätzlich `1.2.276.0.76.4.49`
  (Versicherte).

## Client-Management-Endpunkte

Wie Registrierungen insgesamt ablaufen, verdrängt und widerrufen werden,
beschreibt
[Wie der Client-Lebenszyklus verwaltet wird](Wie_der_Client-Lebenszyklus_verwaltet_wird.md).

- `POST /realms/{realm}/zeta/identity/email` — identitätsweite E-Mail-Änderung
  (A_29912). Autorisiert **ohne Bearer-Token** über den Header `Client-Assertion`:
  ein mit dem registrierten Instanzschlüssel (F2) signiertes JWS mit
  `iss`=`sub`=Client-ID, `aud`=Realm-Issuer, Bindung an Methode und URI über
  `htm`/`htu`, maximal 60 s Lebensdauer und einmalig verwendbarer `jti`
  (A_30101, A_29911, A_25338-01). Nur ein registrierter, bestätigter mobiler
  Client der Identität darf den Aufruf ausführen (A_29909). Die bisherige Adresse
  wird über die Änderung benachrichtigt (A_25750); parallele Registrierungen der
  Identität mit offener OTP-Challenge werden entfernt. Die Änderung erzeugt das
  Security-Event `authn_email_change`
  (siehe [Security-Events](../Referenzen/Security-Events.md)).
- `GET /realms/{realm}/zeta/userinfo/email?id=…` — **Stub**, siehe unten.

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
- **`GET /zeta/userinfo/email` ist ein unauthentifizierter Stub**, der für jede
  Kennung eine statische Adresse zurückgibt.
- **Die E-Mail-Änderung ist derzeit einfaktorig:** `idp_step_up` wird
  entgegengenommen, aber nicht ausgewertet (A_29911), und die alte Bindung wird
  nicht bis zur Bestätigung der neuen gehalten (A_29912). Das Antwortformat
  ändert sich, sobald die OTP-Challenge ergänzt wird (angekündigter Breaking
  Change).
- Für `bind-email/verify` und `resend` gibt es noch **keine
  Versuchsbegrenzung** (Rate Limiting).
- OTP- und Benachrichtigungs-Mails sind fest hinterlegte englische Texte
  (keine Templates, keine Internationalisierung).
- `require_pushed_authorization_requests: true` wird ausgewiesen, aber noch
  nicht pro Client erzwungen.
- Die ausgelieferte IdP-Konfiguration zielt auf die lokale Mock-Föderation
  (`fedmasterUrl` über HTTP); produktive Umgebungen benötigen HTTPS und echte
  Föderations-Endpunkte.
