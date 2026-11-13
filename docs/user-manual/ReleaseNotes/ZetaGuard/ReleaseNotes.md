# Release Notes ZETA Guard Komponenten

## Inhaltsverzeichnis

- [Keycloak Authserver (ZETA PDP)](#keycloak-authserver-zeta-pdp)
- [PEP Proxy (ZETA PEP)](#pep-proxy-zeta-pep)
- [Notification Service](#notification-service)
- [Provisioning Processor](#provisioning-processor)
- [ZETA Guard Helm Charts](#zeta-guard-helm-charts)

## Keycloak Authserver (ZETA PDP)

### Release 2.0.2

#### added:
- Refresh token grant (A_29843): the `scope` parameter may request scopes that were not part of the original grant.
  The new access token carries exactly the requested scopes, provided they are client scopes assigned to the client
  and the policy engine allows them; the OPA input `scopes` now reflects the requested scopes (falling back to the
  originally granted ones if `scope` is absent). Session, consent and token-reuse checks are still applied by Keycloak

#### fixed:
- Mobile flow: the authserver issues KVNR tokens only within a request that passed the policy engine decision for that
  client (or for the reduced e-mail-binding token). Other grants on a SekIDP session no longer yield such tokens
- Keycloak's standard token exchange is disabled in the image; exchanges the 𝝵-Guard providers decline get HTTP 400
- The e-mail-binding token exchange requires a DPoP proof of the key its subject token is bound to
- The well-known configuration announces `response_types_supported` `code` only
- TPM attestation is disabled until the expected protocol update.
- Removed the compromised emSign/eMudhra root CAs (CVE-2026-114406 / CVE-2026-91403) from the hardened Keycloak image's 
  Java truststore (cacerts) and OS trust bundles
- The entity statement at `.well-known/openid-federation` is served with Content-Type `application/entity-statement+jwt`
  as OpenID Federation requires, instead of `application/jwt`. Requests with `Accept: application/entity-statement+jwt`
  no longer fail with 406, so a federation master can fetch it (ANFTI2-1074)
- Entity statement: optimized the query that loads the `redirect_uris`
- The client expiration job no longer removes all expired clients in a single transaction. After a load test with
  hundreds of thousands of clients that transaction exceeded the transaction timeout and was rolled back on every run,
  while memory grew until the container was killed (`OOMKilled`). A run now removes at most
  `CLIENT_REGISTRATION_EXPIRATION_BATCH_SIZE` (default `500`) entries, oldest first, and leaves the rest to the next
  run. With a large backlog, shorten `CLIENT_REGISTRATION_SCHEDULER_INTERVAL` or raise the batch size
- The client expiration job also removes the data of an expired user whose Keycloak user no longer exists (e.g. deleted in
  the admin console). Before, the removal failed every time
- The authserver starts again when a deployment sets `KC_FEATURES_DISABLED` itself. The configured features are now
  added to the hardened set instead of causing a startup failure
- The release notes of 2.0.1 listed the feature `twitter-broker` as disabled. It was never part of the hardened set, as
  it only exists in a coming Keycloak version
- Client Registration: Implemented check that `jwks`, `grant_types`, `client_name` and `token_endpoint_auth_method` are set
- Client Registration: Strip several URI values to prevent Keycloak making requests to attacker controlled targets
- Client Registration: Keycloak's native client-registration endpoints (`default`, `install`,
    `saml2-entity-descriptor`) are disabled, and the RFC 7592 update/delete operations
    (`PUT`/`DELETE`) are removed from the OIDC registration — only `POST`/`GET` on
    `/clients-registrations/openid-connect` remain. This closes the mapper type-swap on
    update (an allowed mapper type could be swapped to a disallowed one such as
    `oidc-hardcoded-role-mapper` via the update endpoint, injecting privileged roles) and
    the broad `ClientRepresentation` registration surface it relied on.
- E-mail binding and e-mail change: a one-time code only confirms the address it was sent to (`400 invalid_code` otherwise).
  Codes issued before the update are rejected the same way (lifetime 5 minutes); a resend issues a valid one

#### changed:
- SM(C)-B user data according to A_26972-03: commonName and organizationName are taken unchanged from the certificate,
  without DN escaping of special characters (e.g. `Praxis Dr. Müller, Zahnarzt` instead of `Praxis Dr. Müller\, Zahnarzt`).
  This applies to the stored user data, the access-token claims `common_name`/`organization_name` and the OPA input
  `user_info`. organizationName is only taken if present in the certificate; otherwise the claim, the OPA input field
  and the user attribute are omitted instead of being set to `Unbekannt`
- Token exchange handles DPoP nonces according to RFC 9449, section 8: a DPoP proof without `nonce` is rejected with
  `use_dpop_nonce` (HTTP 400) and a fresh nonce in the `DPoP-Nonce` response header
- The SekIDP mTLS client (PAR and token requests) is provided as a Keycloak `connections-http-client` provider
  `zeta-sekidp-mtls`. It uses the same SPI configuration as the default HTTP client, plus the SekIDP keystore
- **BREAKING** Token exchange returns HTTP 400 instead of 403 for malformed or invalid requests (e.g. invalid nonce,
  grant type, x5c certificate, client attestation or posture)
- `POST .../zeta/identity/bind-email` answers `409` (`email_already_bound`) if the identity already has a verified e-mail
  address
- Logs and traces for security KPI calculation now also
  carry the attribute `user.roles` indicating a
  `Versicherter`, `Leistungserbringer` or `Unbekannt`-er
  user type.

### Release 2.0.1

#### added:
- The entity statement at `.well-known/openid-federation` carries `metadata.federation_entity` with `name` and
  `organization_name` (gemSpec_IDP_Sek, Tab. 28), taken from `ENTITY_STATEMENT_CLIENT_NAME` and
  `ENTITY_STATEMENT_ORGANIZATION_NAME`
- `ENTITY_STATEMENT_REDIRECT_URIS` configures the entity statement's `openid_relying_party.redirect_uris` statically as a
  comma-separated list. Unset, they are still derived from the realm's SekIDP clients

#### changed:
- **BREAKING** Hardening: Keycloak features not used by 𝝵-Guard are disabled in the image (`KC_FEATURES_DISABLED`):
  `account`, `account-api`, `ciba`, `device-flow`, `jwt-authorization-grant`, `authorization`,
  `admin-fine-grained-authz`, `impersonation`, `workflows`, `identity-brokering-api`, `twitter-broker`, and the
  `.well-known/uma2-configuration` endpoint. Their endpoints (e.g. `/realms/{realm}/account`, device and CIBA
  endpoints) return 404, their grant types are rejected with `unsupported_grant_type`

### Release 2.0.0

#### changed:
- **BREAKING** The SekIDP federation master URL is no longer read from the identity provider config map (`fedmasterUrl`).
  It is now resolved from a provisioned `federation-master.json` file pointed to by the new environment variable
  `FEDERATION_MASTER_LOCATION` (A_29737). Deployments with `ZETA_OIDC_FLOW_ENABLED=true` must set this variable and
  provide the file; otherwise Keycloak will fail to start.
- E-mails sent by the authserver (verification code, notice to the previous address after an e-mail change) are in German
- Updated dependency of VAU Integrity Provider to 2.0.10, for better performance and improved security. If the
  provider is enabled for a VAU deployment: **no rolling update**, make sure to shut down all cluster nodes running
  older software releases before starting the first node with the current release!
- OPA input `client_registration_data.registration_timestamp` (and `client_registration.datetime` of the security event
  `authn_token_created`) is now the time of the initial client registration instead of the client's last access, as
  defined by `policy-engine-client-data.yaml`. It is now also converted to epoch seconds in the server's time zone; before,
  it was off by the UTC offset (e.g. two hours in the future with `Europe/Berlin`)
- **BREAKING** `GET /realms/{realm}/zeta/userinfo/email?id=<KVNR>` is no longer a stub: it returns the user's email,
  and only once it is verified. The calling resource server must authenticate with an mTLS client certificate trusted
  by the resource server truststore, otherwise it gets 401. A missing or malformed KVNR in `id`, an unknown user or an
  unverified email all get the same 404. See [Konfiguration des PDP Services](../../Referenzen/Konfiguration_des_PDP_Services.md).
- the two log lines Keycloak's `nginx` x509cert-lookup writes for every resource server call ("No issuer certificate
  …" and the misleading "Impossible to rebuild end user cert chain …") are demoted to DEBUG via a Quarkus log filter
  in `conf/quarkus.properties`. Only these two messages of `NginxProxySslClientCertificateLookup` are affected; add
  `org.keycloak.services.x509.NginxProxySslClientCertificateLookup:debug` to `KC_LOG_LEVEL` to see them again.
- bump version of spree-integrity-provider (SIP) to 2.0.9, with better support for composite keys; includes DB migration
- **BREAKING** no longer accept dpop-tokens without nonce. Nonce value has to be the same as in the rest of the requests.
  Client-SDK is already compliant.
- JWTs with `crit` or `cty` header parameters are now rejected across token exchange (subject token + client assertion),
  email change und SekIDP federation (A_27802-03)
- MariaDB JDBC driver for Keycloak bumped to version 3.5.9 via override of Jar-Files in the OCI image (CVE-2026-55856, CVE-2026-55857, CVE-2026-55858)
- Netty dependencies for Keycloak bumped to version 4.1.139 via override of Jar-Files in the OCI image
- BouncyCastle dependencies for Keycloak bumped to version 1.86 via override of Jar-Files in the OCI image
- **BREAKING** SekIDP login (A_26973-03): `common_name` in the access token of an insured person is now the display name from
  the ID-token claim `urn:telematik:claims:display_name` instead of the KVNR; an ID token without this claim is rejected. The
  OPA input `user_info.commonName` carries the same value. The identity provider's `defaultScope` must additionally contain
  `urn:telematik:geburtsdatum` (`urn:telematik:display_name urn:telematik:versicherter urn:telematik:geburtsdatum openid`).
- the Apple and Google (Android Key Attestation) truststores and the Google certificate status list
  (`GOOGLE_CERTIFICATE_STATUS_LOCATION`) are now reloaded like the SMC-B, TPM and OCSP truststores: checked every
  `TRUSTSTORE_RELOAD_INTERVAL` and adopted without a restart when a file changed (switched off by
  `TRUSTSTORE_RELOAD_ENABLED=false`). All truststores are loaded once by the new SPI `zeta-guard-trust-material`
  (plugin jar `zeta-commons-plugins.jar`) and shared by token exchange and client registration; a missing or
  unparsable file still fails the startup.
- **BREAKING** `POST .../zeta/identity/email` no longer accepts a `Client-Assertion`; it is reachable only through the PEP
  (see added). The e-mail binding of the registration (`identity/bind-email`, `/resend`, `/verify`) is served behind the PEP
  as well: the binding token carries the Guard audience and ZETA claims via mappers on `zeta:email-verify`, the authserver
  takes the caller from `zeta-client-data`. Deploy the chart (PEP routes, Terraform mappers) before this image.
- Session revocation: reporting a token now also ends an offline session with the same session id, not only the online
  one. Otherwise the offline session could keep refreshing tokens after the block expired.
- PKCS#12 truststores without any entries with friendly names (aliases) are now rejected at startup instead of failing
  later when a certificate is looked up
- Jackson dependencies (`jackson-core`, `jackson-databind`) for Keycloak bumped to version 2.21.7 via override of Jar-Files in the OCI image (CVE-2026-68494, CVE-2026-68497, CVE-2026-89425, CVE-2026-91776, CVE-2026-91777, CVE-2026-89407, CVE-2026-19032, CVE-2026-77310, CVE-2026-83557)
- Jackson dependencies for Keycloak bumped to version 2.21.7 via override of Jar-Files in the OCI image

#### added:
- Client data according to `policy-engine-client-data.yaml` is stored in `ZETA_CLIENT_DATA` (A_26585-02): platform,
  product id and version, device info (os, os version, device model) and the attestation timestamp, taken from the client
  statement of the last successful authentication
- Session data is stored in the PDP database (A_26586-01): `ZETA_CLIENT_DATA.SESSION_DATA` holds the policy engine input
  (`policy-engine-input.yaml`) of the client's last successful authentication or refresh. It is deleted together with the
  client. Both use new nullable columns, added by an additive Liquibase migration
- OPA input `client_registration_data.attestation_timestamp` from the client statement
- Implemented Apple App Attestation for client registration (DCR), mostly following [Apple Guide](https://developer.apple.com/documentation/devicecheck/attestation-object-validation-guide)
- **BREAKING:** New required Environment variables `APPLE_KEYSTORE_LOCATION` and `APPLE_KEYSTORE_PASSWORD` (PKCS#12 truststore containing the
    Apple App Attest root CA). See Helm chart documentation for details.
- Implemented Android Key Attestation for client registration (DCR), following [Android Guide](https://developer.android.com/privacy-and-security/security-key-attestation#verifying):
  certificate chain, attestation challenge, hardware-backed key (TEE/StrongBox), locked bootloader and verified boot state
- **BREAKING:** New required Environment variables `GOOGLE_KEYSTORE_LOCATION`, `GOOGLE_CERTIFICATE_STATUS_LOCATION` and `GOOGLE_KEYSTORE_PASSWORD` (PKCS#12 truststore containing the
    Google Hardware Attestation root CAs). See Helm chart documentation for details.
- **BREAKING** Implemented software attestation for client registration (DCR) (gemSpec_ZETA 5.3.2.3.3): the client data
  signature `signed_hash_puk_client_sig` is verified, and a valid server nonce is mandatory.
- Client management for mobile clients, served behind the PEP with the scope `zeta:client-management` (assigned as a
  default scope at registration), used by the ZETA SDK: `GET /realms/{realm}/zeta/clients` lists the identity's devices
  (`client_id`, `name`), `DELETE .../clients/{client_id}` removes one, e.g. a lost device (the Keycloak client and the
  ZETA data are deleted; its sessions are ended, and once the deletion has committed, their session ids are blocked on
  the revocation stream so that enforcement points reject the device's remaining access tokens), `POST .../identity/email` with
  `/verify` and `/resend` changes the identity's e-mail address, confirmed by a one-time code sent to the new address.
  The authserver takes the caller from the PEP header `zeta-client-data` and checks no token itself; errors are problem+json.
- Client management notifications by e-mail: N1 `client_added` when another client is bound to an identity
  with a verified address, N3 `client_removed` when a client is deleted by the user or removed by ZETA Guard (expiration,
  maximum number of clients, pending clients after an e-mail change), N5 `email_changed` to the previous address. They are
  fired as ZETA-marked Keycloak events (`CLIENT_REGISTER`, `REVOKE_GRANT`, `UPDATE_EMAIL` with detail `zeta_event`) and
  sent once the change has committed
  **The realm must list the new event listener `zeta-guard-notifications` in `eventsListeners`**, otherwise no
  notifications are sent; the existing notice of the previous address after an e-mail change now depends on it too.
- The security event `authn_client_deleted` is now also logged when the user deletes a client (`user_request`), for
  expired clients (`expired`) and for clients removed after an e-mail change (`email_change_pending`), not only when the
  maximum number of clients is exceeded. See [Security-Events](../../Referenzen/Security-Events.md).
- Client management calls are logged as admin events: deleting a client (`DELETE` on `CLIENT`), the
  e-mail change (`UPDATE` on `USER`) and binding another client to an existing identity (`CREATE` on `CLIENT`), with the
  end user and the calling client as actor and the detail `zeta_event`; `zeta_user` names the identity by its ZETA user id (the Keycloak username).
  They reach the event store if admin events are enabled, and the realm's event listeners, i.e. the admin event log of the PDP database (`zeta-guard-admin-events`).
- Client policy executor `zeta-outer-par` (A_29660): the outer PAR request of the SekIDP flow must carry all required values
- New plugin `mobile-authorization-endpoint` and authenticator `SekIdpDirectRedirectAuthenticator`: in
  the `zeta-mobile` browser flow the user is redirected directly to the sectoral IDP, without Keycloak's
  intermediate redirects relying on cookies.
- API Version 2.0.0 listed in authserver well-known
- Configuration `KC_SPI_REALM_RESTAPI_EXTENSION__ZETA__RESOURCE_SERVER_TRUSTSTORE_FILE` / `_PASSWORD`: truststore
  dedicated to resource servers calling `userinfo/email`. It defaults to Keycloak's HTTPS truststore
  (`KC_HTTPS_TRUST_STORE_FILE` / `_PASSWORD`). The client certificate is read via Keycloak's `x509cert-lookup` SPI
  (TLS connection or an ingress header).
- SekIDP login (A_26973-03): the consent-dependent ID-token claim `birthdate` (YYYY-MM-DD) is passed into the access
  token as `birthdate`, from where the PEP writes it into `ZETA-User-Info`. A missing claim is no error; a value that is
  no valid YYYY-MM-DD date is dropped with a warning.
- SekIDP login (A_26973-02): the user data of the ID token — KVNR, display name, birthdate, profession OID and organization —
  is now stored at the user as attributes `zetaguard.mobileuser.*`, encrypted by the integrity provider when it is enabled.
  It is synchronised on every login: a claim the ID token no longer carries, e.g. the birthdate after a withdrawn consent,
  is removed. While the enabled integrity provider is not yet running, the login is refused with HTTP 503.

#### fixed:
- the refresh token's `exp` (and `refresh_expires_in`) no longer outlives the user session behind it: it is capped at
  the realm's SSO session limits, so a refresh before `exp` no longer fails with "Session not active".
  Rotation no longer extends it either — the session ends with the first refresh token's `exp` after full
  authentication (A_25662). Realm session limits must be at least the policy's refresh-token TTL.
- the maximum number of clients per user (`SMCB_USER_MAX_CLIENTS`, A_25748-02) now also holds for concurrent token
  exchanges, across all Keycloak instances. Previously, concurrent requests of the same user could exceed the limit,
  or, with the limit reached, all but one of them were rejected with "Too many clients" instead of evicting the oldest
  client. Binding a new client now locks the user's row in `ZETA_USER_DATA`, so such requests are serialized, and a
  user who already exceeds the limit is brought back to it with the next new client.

### Release 1.3.2

#### changed:
- bumps the BouncyCastle dependencies shipped with Keycloak
- return HTTP 400 instead of 403 for a malformed/invalid client assertion claim, e.g.
  `client_statement` sent as a JSON string instead of an object (A_26661)
- disable Keycloak HTTP-server metrics binder — arbitrary HTTP methods could grow
  `http_server_requests` unbounded → OOM (CVE-2026-40984)
- **BREAKING** fixed inconsistent upper-/lowercase table and column references in the
  `ZETA_USER_DATA`/`ZETA_CLIENT_DATA` Liquibase migration (`jpa-changelog-26.6.3.xml`),
  which broke on case-sensitive databases (MariaDB). Editing the already-applied
  changesets in place changes their Liquibase checksums — **existing deployments must,
  before upgrading, drop the `ZETA_USER_DATA`/`ZETA_CLIENT_DATA` tables AND delete the
  file's Liquibase bookkeeping** — the plugin migrations track state in their own
  `databasechangelog_zeta_guard` table, and dropping the tables alone is not enough (the
  stored checksums still fail validation):
  ```sql
  DROP TABLE IF EXISTS zeta_client_data, zeta_user_data CASCADE;
  DELETE FROM databasechangelog_zeta_guard WHERE filename LIKE '%jpa-changelog-26.6.3%';
  ```
  On startup this release then re-runs the whole changelog and recreates both tables.
  Registered DCR clients are lost by the drop and have to re-register. Step-by-step
  procedure: [Pflichtschritt: Update von 1.3.0/1.3.1 auf 1.3.2](../../Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md#pflichtschritt-update-von-130131-auf-132).

### Release 1.3.1

#### changed:
- bump version of spree-integrity-provider (SPI) to 2.0.5

### Release 1.3.0

#### added:
- OPA input `device_info` (os, os_version, device_model) filled from the attested client statement
- Extend OPA input by amr and acr
- Session revocation: new realm resource at
  `.../realms/{realm}/zeta-guard-revocation`. `POST` an access token (`text/plain`) to
  report it as compromised — it is decoded against the realm's keys, so a foreign or
  unsigned token cannot revoke anything; the session id is blocked until the token's own
  `exp` and the session is ended through Keycloak. `GET` subscribes to the block list as
  server-sent events: the connect delivers a snapshot before deltas, so a reconnect
  doubles as reconciliation and no catch-up endpoint is needed.
  Blocks live in a `zetaGuardRevocations` Infinispan cache keyed by session id. Embedded
  mode declares the cache at startup; dedicated-Infinispan (`clusterless`) deployments
  must provide it themselves, and the provider probes the cache on boot so a missing one
  fails startup instead of answering 500s to reports nobody receives.
  **The realm must list `zeta-guard-revocation-events` in `eventsListeners`** — without
  it only the report endpoint produces blocks, and logouts, grant revocations and admin
  session deletions go unnoticed.
  Sessions that merely reach the end of their own lifetime produce no block: nothing
  withdrew trust ahead of schedule and the remaining exposure is bounded by the `exp`
  that enforcement points already check.
  Blocks derived from an event (logout, grant revocation, admin session deletion) are
  held for a flat hour (assuming no policy grants tokens for longer than that), rather
  than the token's own lifetime: the access token TTL is decided per exchange by the OPA
  policy (`access_ttl`) and kept in a session note that dies with the session, so it is
  not knowable once the session is gone.
- the SMC-B, TPM and OCSP truststores and their meta files are checked every `TRUSTSTORE_RELOAD_INTERVAL`
  (default `PT1H`) and adopted without a restart when the files changed.
- security event `authn_client_deleted` when a client registration is deleted because the
  maximum number of clients per SMC-B user was exceeded (see [Security-Events](../../Referenzen/Security-Events.md#event-authn_client_deletedclientid))
- require certificate meta files, support expired CAs, enforce TSP binding
- OTel integration for fraud detection
- added security event logging for client registration and token exchange
- configurable OCSP request timeout and optional fail-closed mode (`ocspFailClosed`, default off) for the SMC-B revocation check
- Netty dependencies for Keycloak bumped to version 4.1.136 via override of Jar-Files in the OCI image
- ENV-VAR `ZETA_OIDC_FLOW_ENABLED` (default `false`) — master switch for the OIDC client flow; off by default, so existing deployments behave as before
- identity provider `zeta-sekidp-oidc`: the sectoral IDP is chosen per request via `idp_iss`, its PAR, authorization
  and token endpoints are taken from the IDP's entity statement, and the trust chain is resolved through the
  Federation Master.
- the guard's entity statement at `/realms/{realm}/.well-known/openid-federation`, a compact JWS signed with the
  realm's active ES256 key and typed `entity-statement+jwt`, carries these fields:
  - `iss`/`sub` (realm URL), `iat`/`exp` , `authority_hints` (Federation Master)
  - `jwks` — only the key that self-signs the statement
  - `metadata.openid_relying_party` with `redirect_uris`, `response_types=code`, `grant_types=authorization_code`,
    `client_registration_types=automatic`, `require_pushed_authorization_requests=true`,
    `token_endpoint_auth_method=self_signed_tls_client_auth`, `id_token_signed_response_alg=ES256`,
    `id_token_encrypted_response_alg=ECDH-ES`, `id_token_encrypted_response_enc=A256GCM`, `scope` (the SekIDP
    validates the PAR scopes against it, A_29660) and `jwks` with the ECDH-ES key for the encrypted ID token
- `authorization_code` grant for mobile clients: OPA authorizes the token issuance, and a client whose e-mail binding
  is not yet confirmed receives a reduced e-mail-binding token instead of the full token set — 300 s lifetime, no
  refresh token, `binding_mode=collect_email|verify_otp` in the token response, plus `email_hint` for `verify_otp`
- e-mail binding endpoints `POST /realms/{realm}/zeta/identity/bind-email`, `.../bind-email/resend` and
  `.../bind-email/verify`, reachable with the reduced token: a 6-digit OTP valid for 300 s is mailed to the submitted
  address (`collect_email`) or to the address already bound to the identity (`verify_otp`)
- token exchange `zeta-email-binding-token-exchange`: swaps the reduced binding token for the full token set once the
  binding is confirmed, restoring the scopes originally requested via PAR
- identity-scoped e-mail change `POST /realms/{realm}/zeta/identity/email`, authorized by a `Client-Assertion` header
  bound to the request method and URI (A_29911, A_30101); the previous address is notified about the change (A_25750)
  and sibling registrations of the same identity with an open OTP challenge are removed
- `GET /realms/{realm}/zeta/userinfo/email` — stub answering every identifier with a static address
- provisioning of the browser flow `zeta-mobile` (enforced SekIDP redirect, no login screen), the headless
  `zeta-mobile-first-login` flow and the client `zeta-guard-as`, the audience of the reduced binding token

#### changed:
- TLS 1.3 named groups restricted to secp256r1/secp384r1 — secp521r1 is no longer negotiated
- reaching the maximum number of client registrations per SMC-B user (`SMCB_USER_MAX_CLIENTS`,
  default 256) no longer rejects the new registration: the least-recently-used registration of
  that user is deleted instead, so the current registration can proceed (A_25748-02)
- the DPoP reference/test token generator now embeds a minimal JWK (`kty`/`crv`/`x`/`y` only),
  dropping the optional `alg`/`kid`/`use` members so the proof matches the DPoP schema
- updated Keycloak to 26.6.4
- the SMC-B reference/test token generator no longer emits `header.kid` or the `payload.typ`
  (`Bearer`) claim, so the subject token matches subject-token-smb.yaml
- the OPA gate now also covers the `authorization_code` grant; mobile sessions carry their own OPA context, which the
  refresh-token grant replays and the access-token mapper reads for the PDP TTLs (A_28527)
- the policy input of the refresh-token grant now carries `posture_type`, which so far only reached OPA on the
  token-exchange path
- the `zeta-guard` realm provisions an `ecdsa-generated` (P-256) and an `ecdh-generated` (ECDH-ES) key provider —
  required for signing the entity statement and for decrypting the SekIDP's ID token
- the access-token mapper serves both SMC-B and mobile sessions; for mobile sessions the KVNR becomes the token
  subject and the client statement supplies the product claims
- dynamic client registration: a client registering with redirect URIs is set up as a mobile client — mobile browser
  flow override, e-mail-binding client scopes and standard token exchange. NOTE: its attestation is not evaluated yet,
  every mobile registration passes and receives a mocked client statement
- `ZETA_CLIENT_DATA` gains the columns `CLIENT_AUTH_METHOD` (default `SMC_B`) and `CLIENT_REGISTRATION_STATUS`;
  the migration is additive and safe for a rolling upgrade
- the `VERIFY_PROFILE` required action is disabled in the `zeta-guard` realm
- updated spree integrity provider (SPI) to version 2.0.3
- bump BouncyCastle to 1.85

### Release 1.2.3

#### changed:
- token exchange now enforces the SMC-B-signed `client_key`/`dpop_key` bindings; mismatched keys are rejected with `invalid_token`
- bump integrity provider to 1.3.3

### Release 1.2.2

#### changed:
- fix crash when restart with dbEnc enabled

### Release 1.2.1

#### changed:
- bump integrity provider to the public release version
- updated to new policy api schema

### Release 1.2.0

#### added:
- HSM token signing: refuse software-key fallback when HSM is enabled but unreachable (SPI option `failClosed`, default true);
  token-exchange returns `503 temporarily_unavailable` with `Retry-After: 30`
- OPA policy enforcement on the refresh-token grant: each refresh authorizes via OPA before issuing a new token set;
  OPA-unreachable returns `503 temporarily_unavailable` with `Retry-After: 30`
- Client assertion JWT `typ` header validation (`typ=JWT` required per A_25338-01); invalid values are rejected with `400 invalid_request` during client authentication
- SMC-B certs are now subject to OCSP checks


#### changed:
- Keycloak upgraded to 26.6.3
- HSM JCA provider registration moved from runtime (`KeyProviderFactory.postInit()`) to JVM init via
  `-Xbootclasspath/a:` set up in `startup.sh`. Required by Quarkus 3.33's TLS Registry, which resolves `HSMPROXY` before
  any Keycloak SPI initializes.
- Fixed: platform product id in client statement is now optional for Software and TPM attestation
- Fixed: audience parameter is now required on token exchange
- Fixed: audience claim of smc-b tokens is now required to equal the URL of the token endpoint
- Fixed: typ claim of smc-b tokens is now not required to be "Bearer" anymore
- Fixed: "urn:telematik:client-self-assessment" is not required anymore in client assertion jwt
- Fixed: oauth-authorization-server Well-Known document now conforming to schema. Especialle the registration endoint is
  now present.
- Fixed: DPoP is now required for refresh tokens.
- Fixed: OPA-Simulation call is not blocking anymore.
- No-HSM startup mode restored — `startup.sh` no longer aborts when HSM env vars are unset (Scenario 1 in `runtime/compose.yaml`).
- Aligned policy input with schema policy-engine-client-data.yaml v1.3.0

#### removed:

- OPA: `opaEnabled` and `failClosed` config keys — enforcement is always on and fail-closed

### Release 1.0.1-dbEnc

#### added:
- database encryption added in this release (for VAU only)
- database integrity check added in this release, but disabled by default (for VAU only)

### Release 1.0.1

#### added:
- security hotfixes and CVE tracking

#### changed:
- improved CI structure for security hotfixes


### Release 1.0.0

#### added:
- HSM-backed token signing (`hsm-token-signing` plugin) — access tokens, ID tokens, and refresh tokens signed with ES256 via HSM
- HSM KeyProvider configurable via Admin UI (Realm Settings → Keys → Providers → zeta-hsm-token-signing)
- `productID` and `productVersion` from the client attestation are now forwarded to OPA and verified against the `allowed_products` policy data

#### changed:
- OPA simulation calls run asynchronously (bounded fire-and-forget executor) — shadow evaluations no longer block the active OPA decision path

### Release 0.5.1

#### added:
- Integration of `java-hsm-proxy-provider` (`hsm-proxy-provider` plugin)
- TLS via HSM support (Quarkus/Keycloak configuration)

#### changed:
- Keycloak upgraded to 26.5.7

### Release 0.5.0

#### changed:
- Parse Forwarded headers for impossible travel detection

### Release 0.4.1

#### changed:
- Keycloak upgraded to 26.5.6
- Improved OPA decision client logging and error handling
- Improve certificate lookup performance

### Release 0.4.0

#### added:
- TPM attestation validation
- refresh token grant type `grant_type=refresh_token`
- extended access token claims
- OPA simulation instance support
- ENV-VARs
  - `SMCB_HASHING_PEPPER` — **required**; pepper for Telematik-ID hashing
  - `OPA_SIMULATION_BASE_URL` — **optional**; URL of the shadow OPA instance

#### changed:
- **BREAKING** Telematik-ID no longer stored as username
- Keycloak upgraded to 26.5.5 (official release)
- authorization failures return `403` instead of `400`
- audience claim (`aud`) handling corrected

#### removed:
- `CHECK_CLIENT_ATTESTATION_ENABLED` for client software attestation has been removed. Attestation verification is now always enforced.

### Release 0.3.2

#### changed:
- update release notes

### Release 0.3.1

#### changed:
- update release notes

### Release 0.3.0

#### added:
- verification of client's software attestation (currently behind environment variable-based toggle CHECK_CLIENT_ATTESTATION_ENABLED -> do not touch for production, this toggle will be removed in the future)
- client-statement is read from client assertion JWT
- refresh token expiry is now determined by opa policies

#### changed:
- more lenient OID verification for SMCB, so that all SMCBs can be used
- improved test coverage measurement

### Release 0.2.4

#### added:
- mapping userdata and clientdata into access token
- more consistent license headers via maven plugin

#### changed:
- minor updates and improvements

### Release 0.2.3

#### changed:
- minor compliance-specific code formatting changes

### Release 0.2.2

#### added:
- SBOM generation

### Release 0.2.1

#### changed:
- refactoring smc-b keystore for unit tests

### Release 0.2.0

#### added:
- SMC-B token exchange
- storage of user and client data
- client registration according to spec
- nonce endpoint
- ZETA-specific discovery endpoint
- OPA integration for access tokens in token exchange

### Release 0.1.2

#### added:
- Prototype of the ZETA PDP added

## PEP Proxy (ZETA PEP)

### Release 2.0.1

#### fixed

- ASL: a full session cache no longer answers new handshakes with HTTP 500 (`ngx_slab_alloc()
  failed: no memory`). Unfinished handshakes now expire (`pep_asl_handshake_ttl`, default 5m,
  previously never), expired entries are cleaned up at least every 10s without holding the
  write lock for a full scan, and a failing insert drops expired entries, tops up with the
  oldest live ones (handshakes before sessions) and retries. The scan for that runs under the
  read lock, removal happens in small chunks.

- ASL: a request for a cid that is not (or no longer) in the session cache, e.g. after cleanup
  or eviction, is answered with `403`/error code 9 `unknown CID` (gemSpec_Krypt A_26924)
  instead of `500`/102 `internal error: missing`, so clients know to run a new handshake. This
  applies to established sessions as well as to the handshake (M3); an expired handshake is
  answered the same way. Clients matching on error code 102 for this case need to be adapted.

- ASL: an M3 carrying the cid of an established session no longer deletes that session.

- DSA-6572-1: the compromised emSign (eMudhra) root CAs are now explicitly
  distrusted in the `pep` and `nginx-ingress` runtime images (ca-certificates is
  upgraded and the emSign roots are removed from the system trust store)
- ASL: the inner request's `Host` header is no longer forwarded on the loopback hop; the outer
  request's `Host` is used instead. The loopback hop targets `127.0.0.1` and never uses a
  proxy (with thanks to Machine Spirits UG)
- ASL: inner request targets are only accepted in origin-form (`/path?query`) and always stay on
  the PEP's own listener; a path like `/http://host/…` no longer redirects the inner request to
  that host (with thanks to Machine Spirits UG)
- PDP/PoPP key cache: fetched keys and discovery documents are used for at most
  `pep_jwks_max_lifetime` (default `24h`) before they are fetched again in full, without
  `If-None-Match`/`If-Modified-Since`. Previously the response's `Cache-Control: max-age`
  alone decided, and every `304` renewed it, so a key set accepted once with a long `max-age`
  and the server's current `ETag` stayed in use until the next restart. Cached keys are also
  dropped when discovery names a different `jwks_uri` than the one they were fetched from, a
  `304` to an unconditional request is treated as a failed fetch, and an oversized `max-age`
  can no longer overflow the grace-period calculation. The cache is held per worker
  process; `nginx -s reload` replaces the workers and thereby purges it

- **BREAKING** `ossl_hsm`: the provider honours the scheme of `HSM_PROXY_ADDR`. Previously
  every address was dialed in plaintext, `https://` included. `https://` now connects with
  TLS and verifies the proxy's certificate against the configured host name, using the system
  trust store or the CA file named by the new `HSM_PROXY_CA`. `http://` (or no scheme) is only
  accepted for a loopback address; for any other address the provider fails to initialise and
  nginx, when configured with a `store:hsm:` key, does not start.
  `HSM_PROXY_ALLOW_PLAINTEXT=1` restores plaintext to a remote address, for local testing or
  when the link is secured by other means such as a service mesh, and logs a warning at every
  start. A `SignResponse` whose `key_id` is empty or differs from the requested one is
  rejected; HSM proxy implementations must return the `key_id` they signed with. Deployments that configured `https://` need a proxy that
  actually serves TLS; deployments that configured `http://host` must switch to `https://`
  (with thanks to Machine Spirits UG)

#### added

- `hsm_sim`: optional TLS. `--tls-cert`/`--tls-key` serve TLS on `--listen`,
  `--tls-client-ca` additionally demands a client certificate (mTLS), and `--plaintext-listen`
  opens a second, plaintext listener for clients without TLS support. All four can be set
  through `HSM_SIM_TLS_CERT`, `HSM_SIM_TLS_KEY`, `HSM_SIM_TLS_CLIENT_CA` and
  `HSM_SIM_PLAINTEXT_LISTEN`. Without them the simulator serves plaintext as before.
- `ossl_hsm`: the provider can authenticate to the HSM proxy with a client certificate
  (mTLS, A_28830). `HSM_PROXY_CLIENT_CERT` and `HSM_PROXY_CLIENT_KEY` name PEM files with the
  certificate (chain) and its private key; they are read once at start and require an
  `https://` address.
- Security KPI for impossible travel (A_25484-03): the "possible attack detected"
  log of an impossible-travel rejection now carries `attackDetection.type="impossible_travel"`
  (CAPEC 560 is shared with other errors), next to `user.roles` (see below) as the breakdown by
  user role. The metric `zeta.impossible_travel_count` gets the attribute `user.roles` with the
  same values. Country and location data are not part of this change.
- A_25484-03: attack-detection logs (`possible attack detected: …`, carrying
  `attackDetection.capecId`) have the new attribute `user.roles` with the value
  `Versicherter`, `Leistungserbringer` or `Unbekannt`, so the security KPIs can be
  broken down by user role. The role is derived from the professionOID of the validated access
  token according to gemSpec_OID: `oid_versicherter` → `Versicherter`; the Berufsgruppen of
  Tab_PKI_402 and the care-providing institutions of Tab_PKI_403 (Praxen, Krankenhäuser,
  Apotheken, Rettungsdienst, Pflege, Heil- und Hilfsmittel, …) → `Leistungserbringer`; any
  other professionOID (e.g. Kostenträger, Leistungserbringerorganisationen, gematik, technical
  roles) → `Unbekannt`. Without a token, or when its validation failed, it is `Unbekannt`
  as well. The professionOID itself is not logged.
- directives `pep_asl_session_cache_size` (default 100m, min 1m, max 16g), `pep_asl_session_ttl`
  (default 24h, capped at the 24h of the ASL protocol) and `pep_asl_handshake_ttl` (default 5m).
  The cache is per pod. TTL changes apply on reload. The ASL certificates, roots and testing
  flag are read when the zone is created: a reload keeps the zone, its sessions and these
  settings, unless the size changed, in which case it starts over with an empty cache.
- metrics `zeta.asl.sessions.handshaking` (part of `sessions.active`),
  `zeta.asl.session_cache.used`/`.size` (bytes), `zeta.asl.session_cache.alloc_failures` and
  `.evictions`; alert on any increase of `alloc_failures`.

#### changed

- metric `zeta.asl.sessions.active` keeps its meaning (handshakes + sessions), but is an O(1)
  counter now.
- Before performance runs, restart the PEP pod to start with an empty session cache.

### Release 2.0.0

#### fixed

- **BREAKING** `ZETA-User-Info.birthdate` is taken from the access token's `birthdate` claim
  (A_26973-03), which the authorization server forwards from the sectoral IDP's id_token when
  the insured person consented. Without the claim the field is absent; a value that is no
  `YYYY-MM-DD` date is dropped with a warning. The interim fixed date (ANFTI2-922) and its
  directive `pep_user_info_birthdate` are removed — nginx no longer starts with a
  configuration that still sets it.
- ASL: don't panic on short M3
- purl and load_dispenser add nonce in dpop-token for token exchange
- in `pep_require_popp off` locations, `popp` headers are now also verfied and forwaded
  as `ZETA-PoPP-Token-Content` if present, given a `pep_popp_issuer` is configured.
- `pep_forward_client_data` set at `http`/`server` level is now inherited by locations
- ASL: session requests shorter than the session overhead are rejected (`BadFormat`)
  instead of underflowing
- ASL: redirects on inner responses are never followed

#### changed

- A_25669-01: sensitive headers (authorization, dpop, popp) are no longer forwarded to
  upstreams. This can be disabled, by setting corresponding variables either globally in
  the server block, or on a per-location basis (before `include proxy_headers.conf;`):
  before :
  ```nginx.conf
    http {
        server {
            set $zeta_strip_authorization 0;
            set $zeta_strip_dpop 0;
            set $zeta_strip_popp 0;

            location / {
                set $zeta_strip_authorization 0;
                set $zeta_strip_dpop 0;
                set $zeta_strip_popp 0;

                include proxy_headers.conf;

                proxy_pass "http://…/";
            }
        }
    }
  ```

- A_29850: PoPP errors (`PoPPMissing` 400, `PoPP` and `PoPPInvalidActor` 403) no longer carry
  the header `zeta-error-origin: pep`. They are addressed to the caller, who supplies the PoPP
  token, so the ZETA-Client hands them on instead of re-authenticating.
- ASL: an expired session returns the distinct error `AslSessionExpired`, so the client can
  re-handshake and retry
- Bumps nginx version to 1.31.7
- Bumps nginx-ingress version to 5.7.0
- Bumps rust version to 1.99.1

#### added

- A_25669-01: optional `ZETA-Access-Token-Content` upstream header with the full,
  Base64-URL encoded JSON payload of the validated access token
  (`pep_forward_access_token_content on|off`, default off).
- `pep_pdp_url`: optional internal base URL for OIDC discovery and the JWKS fetch.
  `pep_pdp_issuer` stays the trust identity (the expected `iss`), so the PDP can be
  reached over an in-cluster address while tokens keep carrying the public issuer.
  The `jwks_uri` advertised by discovery is rewritten from the issuer prefix onto
  `pep_pdp_url`; a `jwks_uri` outside the issuer is fetched as advertised and logged.
  Unset (default) keeps the previous behaviour.

### Release 1.3.3

#### fixed
- harden ASL subrequest target URL handling
  (with thanks to Machine Spirits UG)

### Release 1.3.2

#### added
- `ZETA-User-Info` carries a `birthdate` field for insurant tokens (ANFTI2-922 / A_27558):
  DiPag rejects insurant requests without it, but no PDP claim carries a birthdate yet.
  **Interim solution** — for tokens with professionOID `1.2.276.0.76.4.49` (Versicherte) the
  PEP emits the fixed date `1900-01-01`, overridable per environment with
  `pep_user_info_birthdate <YYYY-MM-DD>;` (http level); other client types (SMC-B/LEI) get
  no `birthdate`. An invalid value aborts the nginx start. To be replaced by the real claim
  once the authorization server forwards the sectoral IDP's `birthdate`.

#### changed
- Configuration errors now name the offending directive: `conf_handler!` printed the literal
  `` `$name` `` instead of substituting it, so every misconfiguration logged
  ``nginx: [emerg] `$name`: …``. The `on`/`off` and seconds-valued directives now report a
  consistent ``expected `on` or `off`, got "maybe"`` / `invalid seconds value "abc"`.
- `pep_asl_ocsp` with an unparseable responder URL used to panic (`unparseable pep_asl_ocsp`)
  and abort the nginx start; it now fails as a regular `[emerg]` naming the directive.

### Release 1.3.0

#### fixed
- DPoP proofs whose embedded `jwk` omits the optional `alg`/`kid`/`use` members are now accepted;
  previously a missing `jwk` `alg` was rejected with HTTP 401. An explicit `jwk` `alg` other than
  `ES256` is still rejected.
- ASL subrequest now sets `Forwarded.for`; the client ip is determined by the same
  mechanism as elsewhere (forwarded → x-forwarded-for → x-real-ip → socket addr)

#### added
- Session revocation: with `pep_revocation_url` set, the PEP reports the
  offending access token to the PDP when it detects an impossible-travel violation
  (`ip_address` claim != client ip), and subscribes to the PDP's block list as
  server-sent events — the connect delivers a snapshot, so a reconnect is also the
  reconciliation. Blocked session ids live in a shared memory zone, so every worker
  enforces what one of them learned; requests presenting a blocked `sid` are rejected
  with `401` / `RevokedSession`.
- Metrics for the above: `zeta.session.blocked_count` (sessions added to the block
  list — **replicated across pods, query with `max`, never `sum`**),
  `zeta.blocked_request_count` and `zeta.impossible_travel_count` (both per-request,
  so `sum` is correct).
- Implement otel traces,logs,metrics.
  W3C context is used to re-parent inner ASL requests, and forward tracecontext upstream.
  Metrics only cover items that could not be determined from spanmetrics already (e.g.
  upstream time histogram, /ASL→inner timings, etc.).
- if the validation fails, then a header zeta-error-origin: pep is returned.
  A missing header does not imply an error in the service (Fachdienst).
- logging indications of possible attacks. This logs are enriched with capec categorization. (A_25404)

#### changed
- Bumps nginx version to 1.31.3
- Bumps nginx-ingress version to 5.5.4
- Bumps rust version to 1.97.1
- Bumps headers more to 0.40
- To fulfill A_25669-01 the authorization, dpop and popp headers are forwarded
  to the upstream and not overridden by PEP. In future versions this will be configurable.

### Release 1.2.1

#### fixed
- bugfix

### Release 1.2.0

#### added

- zeta-cause: proxy handling

#### changed

- Invalid access token headers (unparseable JWT) now return HTTP 401 instead of HTTP 500
- Missing or unsupported `kid`/`alg` in access token header now consistently return HTTP 401
- Bumps nginx version to 1.31.2
- Bumps nginx-ingress version to 5.5
- Bumps rust version to 1.95

#### fixed

- PEP now strips all client-supplied ZETA-* request headers it controls (`ZETA-User-Info`, `ZETA-Client-Data`,
  `ZETA-PoPP-Token-Content`, `ZETA-API-Version`) and overwrites them with its own values, instead of aborting with
  HTTP 500 on a conflicting value (A_25669-01)
- PEP now updates the `Forwarded` header (RFC 7239) on the upstream request with its own element
  (`by=_zetapep`/`for`/`host`/`proto`; `host` and `for` emitted as quoted-strings as required). On the plain
  proxy path any existing value is preserved and the element appended; on the ASL path a fresh element is set
  (the inner request's untrusted `Forwarded`/`X-Forwarded-*` are dropped). `for` carries the observed client IP
  (A_28440). (A_28439)

### Release 1.0.1

#### added

- pep_forward_client_data config to set, default off. "zeta-client-data" upstream
  header was always set previously (A_26492-02)

#### fixed

- rare deadlock and u-a-f under load-test conditions (ngx-tickle 0.2.4)

#### changed

- low-level performance optimizations regarding ASL session locks, client body reading,
  tickle coaslescing (ngx-tickle)
- increased max. ASL session cache size to 100MiB

#### removed

- pipelining and keep-alive in the internal http client. This hurt performance because
  it introduced locking overhead; it is faster to establish new connections in the
  ASL→internal use-case, and JWK cache didn't need it

### Release 1.0.0

#### added:

- nginx-ingress build that has ossl_hsm and can use it to externalize TLS to an HSM
- popp:
    - validate actorId == access_token.sub
    - quarter-based validity can now be configured, relative validity now also takes
      duration strings like "10d"
- hsm_sim:
    - Enable brainpool curves, and remove p521. supported now:
        - Nid::X9_62_PRIME256V1 (key id suffix .p256)
        - Nid::SECP384R1 (.p384)
        - Nid::BRAINPOOL_P256R1 (.bp256)
        - Nid::BRAINPOOL_P384R1 (.bp384)
        - Nid::BRAINPOOL_P512R1 (.bp512)
- ossl_hsm:
    - support all aforementioned curves
- asl:
    - switch to openssl in ASL key generation, to enable HSM signatures via ossl_hsm
- jwk_cache:
    - can do conditional requests when the JWKS server responds with etag or
      last-modified, and respects cache-control max-age to postpone the next refresh
    - will retry once when JWKS refresh fails before removing the JWKS from the cache

#### fixed

- hsm_sim:
    - shutdown hang with dead clients
- ossl_hsm:
    - reconnection issue on gRPC connection reset
- popp:
    - missing PoPP token (when required) now returns 400 Bad Request

#### changed:

- dependency upgrades:
    - nginx: 1.29.8
    - ngx-tickle: 0.2.1
- jwk_cache:
    - now sets x-forwarded-for to the client IP when JWKS refreshes are triggered by
      unknown kids, to enable ip-based rate-limiting in the remote server

### Release 0.5.1

#### added:

- ossl_hsm — an openssl provider that can do TLS on a HSM

### Release 0.5.0

#### added:

- provide OCSP stapling for ASL
- implement no-travel enforcement
- support entity statement and signed JWKS for PoPP

#### changed:

- updated to latest libcrux version for ASL crypto
- slimmed down the container image some more to decrease attack surface

#### fixed:

- case-independent handling of authorization schemes

### Release 0.4.0

#### added:

- openvex-based CVE management
- structured errors:
    - ZETA/high-level errors as application/json (schema: zeta-error.yaml)
    - embedded html error pages for long-form descriptions
    - pass errors on the ASL channel as application/cbor to the caller (type: ErrorResponse)
- ASL
    - certificate config (`pep_asl_*` options)
    - /CertData endpoint

#### changed:

- switch to custom nginx build to not be constrained by ngx/vendored and to allow usage
  of nginxinc/nginx-unprivileged base images
- dependency upgrades, notable:
    - Rust 1.94.0
    - nginx 1.29.5
    - ngx-tickle 0.2.0
- sync JSON schemas from gematik/zeta for VSDM2-interop
    - client-data.yaml: ZETA-Client-Data upstream header
    - zeta-user-info.yaml: ZETA-User-Info upstream header
- trim unneeded dependencies from prod. images as part of ongoing CVE mitigations

### Release 0.3.0

#### added:

- Implement integration test harness with code coverage measurements
  This re-uses client functionality of the purl utility, which has been extracted to the
  new client module. purl is now a subpackage in the workspace due to crate type
  requirements.

#### changed:

- Ensure ZETA-API-Version header is set early, so it is always emitted in error cases
- Added default ports for ws (80) and wss (443) for url normalization (relevant for DPoP
  token verification)
- Compile against nginx 1.28.1, upgrade rust to 1.92, and use trixie-based nginx image
  (from bookworm)
- Update client code to extract AdmissionSyntax from SMC-B certificate, pass telematik-id
  to token exchange and provide client-self-assessment, client_statement, and attestation
  challenge (IT, purl)

### Release 0.2.5

#### changed:

- full implementation of ASL test mode (see A_26942 and A_26943)

### Release 0.2.4

#### added:

- url normalization for htu verification
- added htu verification again
- extracting userdata and clientdata from access token and passing it on to the Fachdienst

#### changed:

- minor build and CI changes

### Release 0.2.3

#### changed:

- removed htu verification due to problems with the test setup

### Release 0.2.2

#### added:

- PoPP token verification

### Release 0.2.1

#### added:

- DPoP Verification and enforcement

### Release 0.2.0

#### added:

- token verification as per spec
- Passing user and client information onto the Fachdienst via headers
    - **warning** still contains some mock data
- ASL implementation
    - **warning** not ready for production use yet

### Release 0.1.3

#### added:

- Prototype of the ZETA PEP added

## Notification Service

### Release 2.0.2

#### fixed
- With sealing off, a pushkey longer than about 300 characters (the API allows 512 bytes) made every
  notification to that user fail with `400`: the device history's storage id contained the pushkey and
  exceeded the 450-character id column. The history is now stored under a SHA-256 of user and pushkey.
  Histories under the old id are still read, moved to the new id by the next notification (keeping their
  retention deadline) and deleted with the device. No migration step is needed.
- **Breaking for clients:** an operation on another user's pusher is rejected with
  `403 M_FORBIDDEN` (A_29978) instead of succeeding. Registering an app ID and pushkey another user
  holds, with or without `append`, no longer moves the pusher to the caller and answers `403`;
  deregistering another user's pusher answers `403` instead of `200`; `GET`/`POST
  /channels/{pushkey}` and `GET /history/device/{pushkey}` for a pushkey another user holds answer
  `403` instead of `404 PUSHER_NOT_FOUND`. A pushkey nobody holds still answers `404`, and
  deregistering a pusher nobody holds still `200`. A device that changes accounts has to deregister
  its pusher before the new account registers it; the takeover of 2.0.0-rc1 followed A_27154, which
  does not apply to this service. `append` is still accepted but has no effect. The FdV contract is
  unchanged; see README "Current limitations".
- A new index of the users per pushkey tells the `403` from the `404` on the channel and history
  paths. Pushers registered by an earlier release enter it when their owner registers them again;
  until then another user still gets `404` for them there. Pushers two users shared through
  `append: true` stay shared, and each user keeps managing its own registration. A pushkey the Push
  Gateway rejects is now also removed from the owner index, so it no longer blocks another user from
  registering it.

### Release 2.0.1

#### added
- With sealing on, records are sealed and their storage ids derived with the keys of a keychain the
  operator supplies HSM-wrapped in the new `notification.persistence.sealing.keychain` (JSON; from a
  Kubernetes secret as `NOTIFICATION_PERSISTENCE_SEALING_KEYCHAIN`, or as a file named by
  `notification.persistence.sealing.keychain-file`). Each entry wraps a DEK and a pseudonymization key
  together under its KEK. Each instance unwraps the entries once, on first use, so reads and writes no
  longer call the HSM. Every seal derives its own key from the DEK and a random salt from the pinned
  DRBG (HKDF-Expand); the service no longer generates or wraps keys itself. See README "Record keys".
- Keychain generator image `$CI_REGISTRY_IMAGE/keychain-generator`: draws a DEK and a pseudonymization
  key, has the HSM proxy wrap them and writes the keychain with the entry appended. Configured by
  environment only: `KEYCHAIN_OUTPUT_FILE` is required, and `HSM_PROXY_KEK_ID` for a new keychain
  (extending one, it defaults to the KEK of the newest entry). `HSM_PROXY_ENDPOINT`,
  `KEYCHAIN_INPUT_FILE`, `KEYCHAIN_ENTRY_ID` (defaults to `…-v1` for a new keychain and to the next
  version otherwise) and `KEYCHAIN_EMERGENCY` are optional, and `KEYCHAIN_ACTIVE_FROM`
  defaults to now for a new keychain but is required when extending one. An existing output file is left
  alone and the run ends successfully, so the image can run as an init container.
- Key rotation (A_29963, A_29960): a new keychain entry takes over the writes at its `activeFrom`, and a
  rotation job moves the records of older entries to it, with new storage ids and sealed under the new
  DEK, one minute after boot and then every `notification.persistence.sealing.rotation-interval`
  (default `1h`). Records with a retention period expire under their entry, unless the new entry is an
  emergency entry (`KEYCHAIN_EMERGENCY=true`): then they move too and keep their expiry. A record that
  fails is logged and retried on the next run; ten failures in a row stop the run. The job logs the live
  records per entry as its progress. See the runbook in README "Key rotation".

#### changed
- **Breaking, with sealing on:** records sealed by an earlier build no longer open, and their storage
  ids no longer match; start from an empty database. Migration `V4` drops `sealed_key`, renames
  `storage_record.kek_id` to `keychain_id` (the entry a record is under) and drops the unused
  `storage_record.dek`. `hsm-proxy.kek.dek-key-id`, `hsm-proxy.kek.pseudonym-key-id` and
  `notification.persistence.sealing.dek-cache-size` are gone.
- With sealing on, readiness reports whether the keychain is unwrapped and holds the entry of every live
  record, instead of whether the HSM proxy answers: a broken keychain, or an old entry removed while
  records are still under it, stops a rollout at its first instance, and an HSM proxy outage no longer
  takes instances that hold their keys out of service.
  The readiness check is now named `keychain` instead of `hsm-proxy`.

### Release 2.0.0

#### added
- `notification.history.retention` (default `P30D`): a device's message history expires that long
  after its first entry and is purged with the other expired records (A_29988).
- Optional rate limit on the RS endpoints (A_29987), off by default: `QUARKUS_FAULT_TOLERANCE_GLOBAL_RATE_LIMIT_ENABLED`,
  `_VALUE` (default `1000`), `_WINDOW`, `_WINDOW_UNIT` (default one second). Over the limit the answer is
  `429 RATE_LIMITED` with `Retry-After`.
- Every `503 SERVICE_UNAVAILABLE` carries `Retry-After: 5` (A_29987).

#### changed
- **Breaking:** the RS paths require an mTLS client certificate (A_29980); see README "Authentication".
- A plain (unencrypted) notification payload above 3072 serialized bytes is now rejected with
  `413 PAYLOAD_TOO_LARGE` (A_29987); before, plain mode had no limit beyond the HTTP body size.
- Disabled access log and tracing to prevent logging and tracing of KVNRs and Telematik-IDs. (A_29990)

#### fixed
- The native image boots with an unencrypted EC or RSA client key for the Push Gateway mTLS
  (A_29982); it used to fail with `no such algorithm: EC for provider BC`.

### Release 2.0.0-rc1

#### added
- Each dispatch logs its outcome once: `dispatched` when every device was reached, `failed` when
  none was, `partially_rejected` in between. Not persisted yet; the writeback to the stored
  notification is deferred to a follow-up ticket.
- `push-gateway.batch.max-count` (MAX_BATCH_COUNT, default `100`) and `push-gateway.batch.max-time`
  (MAX_BATCH_TIME, default `PT1S`) for the encrypted batches, gemF_PushNotification A_28212 to
  A_28217. A value above `100` or `PT10S` fails the boot.
- Set up export of logs, metrics, and traces using OTLP. (A_27492-02, A_26988)

#### changed
- The Push Gateway client picks the JVM proxy by the target's scheme: `https://` targets read
  `https.proxyHost`, `https.proxyPort` and `https.nonProxyHosts` (not the JDK's shared
  `http.nonProxyHosts`), `http://` targets the `http.*` ones. Before, an `https://` target without
  `push-gateway.trusted-ca-paths` or mTLS used the `http.*` ones. The released native image does not
  translate `HTTPS_PROXY` / `HTTP_PROXY`: pass the properties as `-D` arguments to `./application`,
  or set `QUARKUS_PROXY_HOST`, `QUARKUS_PROXY_PORT` and `QUARKUS_PROXY_NON_PROXY_HOSTS`, which apply
  to both schemes.
- TLS towards the Push Gateway is pinned for gemSpec_Krypt (A_29991): the client offers only TLS 1.2
  and 1.3, the ECDHE-GCM suites (ECDSA first) plus TLS 1.3 AES-GCM, and only the secp256r1 and
  secp384r1 groups. The gateway's leaf RSA key must have at least 3000 bits, so **a Push Gateway with
  an RSA-2048 certificate now fails the handshake**.
- DEKs, the pseudonymization key and the GCM IVs come from a pinned SP 800-90A DRBG (256-bit)
  instead of the platform's default `SecureRandom` (GS-A_4367 / GS-A_4368).
- `push-gateway.retry.max-attempts` changes its meaning: it now caps how often an item a Push
  Gateway response reports `failed` is sent (default `3`); such items are retried without their
  rejected devices. A value below `1` fails the boot instead of being raised to `1`. Transport errors
  (5xx, 429, connection failures) no longer count against it: they are retried with exponential
  back-off until the new `push-gateway.retry.give-up-after` has passed (default `PT1H`, shorter than
  `notification.persistence.retention` or the boot fails), with the wait capped by the new
  `push-gateway.retry.max-delay` (default `PT5M`) (A_27166).
- The batches for one Push Gateway are sent concurrently, so a later batch no longer waits for the
  answer to an earlier one.
- A pushkey the Push Gateway rejects is now removed from **every** pusher of the notified user,
  whatever app id registered it and whichever dispatch the answer belongs to (A_27374), instead of
  only from the devices of the batch that was just sent.
- Two contract questions are answered in the README under "Current limitations" instead of being
  carried as open gaps: why `reference` is not forwarded on the plain dispatch path
  (`PlainNotification` has no `identifier` field, gemF_PushNotification A_27532), and why the
  dispatch queue stays in-process rather than buffering until delivery (A_27166).
- `POST /pushers/set` now honours `append`. Without it (the contract's default `append: false`),
  registering an app ID and pushkey removes that pusher from every other user who had registered it,
  so a device that changes accounts stops receiving the previous account's notifications.
  `append: true` keeps the other users' registrations, as before. Pushers registered before this
  release are not yet known to the lookup that finds other users, and are removed only after their
  owner registers them again.
- While `notification.history.enabled` is off, both `/history/*` endpoints answer
  `404 HISTORY_DISABLED` (A_29974). `GET /history/{notification_id}` used to answer
  `404 NOTIFICATION_NOT_FOUND`, `GET /history/device/{pushkey}` `200` with no messages. Behind the
  ZETA Guard PEP a client still gets `403`, since the `notification.history.read` scope is not
  issued while the history is off; see "Current limitations" in the README.
- The RS API checks `id_type` against the value: a KVNR-shaped value declared as `telematik-id`, or
  the reverse, is answered with `400 M_INVALID_PARAM` (A_29967). Neither that answer nor
  `404 USER_NOT_FOUND` echoes the identifier any more.
- Deregistering a pusher, a pushkey the Push Gateway rejects, and a pusher taken over by another
  user without `append` now delete the device's message history once the user holds that pushkey
  under no other app ID; registering a pushkey the user does not hold yet starts with an empty
  history (A_29989).
- Added trace information to logs. (A_28796)
- Redacted decrypted notifications in error logs. (A_29990)

#### fixed
- A password-protected mTLS client key (`push-gateway.mtls.client-key-password`) made the service
  fail to start with `UnrecoverableKeyException`.

### Release 1.3.2

#### added
- Support for every database Keycloak supports — PostgreSQL, MariaDB, MySQL, Microsoft SQL Server
  and Oracle. A single image carries all five drivers, and the engine is selected at deploy time by
  the JDBC url alone: `QUARKUS_DATASOURCE_JDBC_URL` / `_USERNAME` / `_PASSWORD` as before, with the
  engine taken from the url's prefix. Only an ambiguous url needs
  `NOTIFICATION_DATASOURCE_DB_KIND` (`postgresql`, `mariadb`, `mysql`, `mssql`, `oracle`) — a
  MariaDB server reached through a `jdbc:mysql:` url, above all.

#### changed
- An existing PostgreSQL deployment needs no configuration change: its
  `QUARKUS_DATASOURCE_JDBC_URL` / `_USERNAME` / `_PASSWORD` keep working unchanged, and
  `jdbc:postgresql:` identifies the engine on its own. Schema migration `V2` converts the table in
  place on first start. The per-engine keys (`QUARKUS_DATASOURCE_POSTGRESQL_*`) are also accepted
  and take precedence, should a deployment prefer to be explicit.
- The scheduled purge now claims a lease with an ordinary compare-and-set write instead of taking a
  PostgreSQL advisory lock. Running several instances remains safe.

### Release 1.3.0

Initial release of the ZETA Notification Service.

#### added
- RS-facing API: resource servers can submit push notifications for delivery.
- FdV-facing channel management API: registration and management of push channels.
- Dispatch (Versand) engine: forwards notifications to the push gateway (APNs/FCM), with exponential backoff for failed push gateway connections.
- Cleanup of sent push notifications, their idempotency data, and invalid pushers.
- Persistent storage on PostgreSQL for notifications, delivery history and idempotency, with Flyway-managed schema migrations.
- Split run modes selectable at build time (both APIs, RS-only, FdV-only) via `notification.api.rs.enabled` / `notification.api.fdv.enabled`.
- Support for configuring additional trusted root CAs and PEM certs for use in mTLS towards the push gateway.
- Health endpoints via SmallRye Health.
- Acceptance test coverage based on the gematik acceptance criteria (AFOs).
- Local development setup with Docker Compose and a mocked push gateway.
- Tagged release pipeline: native-image container images are built, scanned (Trivy) and signed on tag push.

### Release 1.3.0-rc1

#### added
- Support for configuring PEM certs for use in mTLS towards the push gateway
- Exponential backoff for failed push gateway connections

#### fixed
- Cleanup of sent push notifications and their idempotency data
- Remove invalid pushers

### Release 0.1.1

#### added
- Support for configuring additional trusted root CAs.

#### fixed
- Correct decoding of the `zeta-user-info` header.

#### removed
- Dropped the `pg_cron` dependency.

### Release 0.1.0

Initial release of the ZETA Notification Service.

#### added
- RS-facing API: resource servers can submit push notifications for delivery.
- FdV-facing channel management API: registration and management of push channels.
- Dispatch (Versand) engine: forwards notifications to the push gateway (APNs/FCM).
- Persistent storage on PostgreSQL for notifications, delivery history and idempotency, with Flyway-managed schema migrations.
- Split run modes selectable at build time (both APIs, RS-only, FdV-only) via `notification.api.rs.enabled` / `notification.api.fdv.enabled`.
- Health endpoints via SmallRye Health.
- Local development setup with Docker Compose and a mocked push gateway.
- Tagged release pipeline: native-image container images are built, scanned (Trivy) and signed on tag push.

## Provisioning Processor

### Release 2.0.0

#### added:

- Processor for FederationMasterUrl
- Processor for Apple attestation roots.
- Processor for Android attestation roots.

#### fixed:

- SMC-B, TPM and Apple trust stores are written with `-jdktrust anyExtendedKeyUsage` and a CA
  name per certificate, so Java reads them as trusted certificate entries.

### Release 1.3.2

#### fixed:

- `cosign login` was called with `--registry-cacert`, a flag it does not support, so the
  provisioning container could not be fetched from a registry that requires both credentials
  and a private CA (`Error: unknown flag: --registry-cacert`). The registry CA is only needed
  by `cosign save`, which still receives it. (ANFTI2-912)

### Release 1.3.0

#### added:

- option to authenticate against the provisioning container registry (non-anonymous access) via
  `PROVISIONING_CONTAINER_REGISTRY_USERNAME` and `PROVISIONING_CONTAINER_REGISTRY_TOKEN` (used for
  `cosign login` before fetching the image)
- meta file `smcb-trust-roots-meta.json` mapping each SMB CA `friendlyName` to its `tspName` and, for
  revoked CAs, the `revokedSince` date
- meta file `ocsp-signers-meta.json` mapping each OCSP signer `friendlyName` to its `tspName`
- optional `SCHEDULE_TIME` (format `HH:MM`) to keep the container resident and re-run the
  provisioning cycle daily at that time instead of exiting after a single run; invalid values are
  rejected immediately at startup. Evaluated in the timezone set via `TZ` (image now includes
  `tzdata`, so named zones like `Europe/Berlin` work; defaults to UTC if unset)
- `kubectl` added to the image, unrelated to this tool's own job — reused by `zeta-guard-helm`
  elsewhere as a minimal, non-root-by-default alternative to a generic CI tooling image

#### changed:

- revoked SMB CAs of the TSL are now included in the `smcb-trust-roots.p12` truststore (certificates
  issued before the revocation date remain valid; the revocation date is provided in the meta file)
- all processors now write their result file atomically (temp file + `mv`) so a concurrent reader
  never observes a partially written file during a scheduled re-run

### Release 1.2.0

#### added:

- processing of the OCSP signers of the TSL

### Release 1.0.0

#### added:

- processing of `roots.json`
- option to provide the CA of the registry from which the provisioning container is fetched (for TLS) via
  `PROVISIONING_CONTAINER_REGISTRY_CA_FILE`

### Release 0.5.0

#### added:

- processing of the smb CAs of the TSL
- processing of TPM CAs
- processing of policy signer certs

## ZETA Guard Helm Charts

### Release 2.0.4

#### changed:

- updates the ZETA SDK test drivers (testdriver, nativedriver, android-testdriver) to 2.0.6
- updates tiger-proxy to `fork-2.0.4` and zeta-cert-validation-mock to 2.0.4

### Release 2.0.3

#### added:

- Security KPI `zeta_guard_kpi.impossible_travel_24h` (A_25484-03): number of impossible travel
  rejections of the PEP, broken down by `user.roles` (`Versicherter`, `Leistungserbringer`,
  `Unbekannt`). Counted from the PEP's attack log event (`attackDetection.type=impossible_travel`),
  which carries `user.roles` since PEP 2.0.1; needs a PEP that sets both. Country and
  place are not part of it yet.

#### changed:

- **BREAKING** `pepproxy.hsmProxyAddr`: the PEP's `ossl_hsm` provider now honours the scheme of
  the address. `https://` connects with TLS and verifies the HSM Proxy's certificate; `http://`
  or an address without a scheme is only accepted for a loopback address. With a plain-text
  address to another host the PEP does not start. The new
  `pepproxy.hsmProxyPlainTextAccepted: true` (`HSM_PROXY_ALLOW_PLAINTEXT=1`, default `false`)
  restores the previous plain-text behaviour; set it only where the network itself protects the
  channel, e.g. `hsm-sim` in a test cluster.
- the KPI metrics helper CronJob pushes `zeta_guard_kpi.impossible_travel_24h` as one data point per
  `user.roles` instead of a single total, so the breakdown reaches the TI-SIEM (A_25484-03). All
  other KPIs are unchanged (one total data point). A role without events that day has no data
  point. The rounded total is distributed to the roles (largest remainder), so the values add up
  to the total reported before.
- the PEP requires the scope `zeta:email-binding` in addition to `zeta:email-verify` for
  `POST /auth/realms/zeta-guard/zeta/identity/bind-email`; `.../resend` and `.../verify` are
  unchanged and have their own locations in the PEP configuration
- the client policy profile `zeta_client_policy_profile` gets the executor
  `reject-implicit-grant`: implicit and hybrid authorization requests are
  rejected, registrations with `response_types` `token` get the implicit flow
  switched off. See
  [How to upgrade ZETA Guard](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_upgrade_ZETA_Guard.md)
- default database volume `cloudnativePg.storage.size` and
  `keycloak-db.cluster.storage.size` is 32Gi (was 10Gi), a
  size of 10Gi might run full with many registered clients. [How to manage the authserver DB](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_manage_authserver_DB.md)
  now explains how to size the volume and recommends a separate WAL volume
  (`walStorage`) for production. In a VAU (`authserver.dbEnc.enabled: true`) the
  integrity checks need about three times the space per client, 64Gi are
  recommended there
- Updated telemetry attributes attached to security KPIs signifying
  `Versicherter`, `Leistungserbringer` and `Unbekannt`.
- updates keycloak-zeta to 2.0.2, ngx_pep and nginx-ingress to 2.0.1, notification-service and
  notification-keychain-generator to 2.0.2
- updates zeta-telemetry-gateway to v0.157.1
- test environment: updates hsm_sim to 2.0.1, the test drivers to 2.0.5, tiger-proxy to `fork-2.0.3`
  and zeta-cert-validation-mock to 2.0.3

#### fixed:

- Reporting of security KPIs now go directly to TI SIEM in addition to prometheus. The 24h sum through prometheus is now **deprecated**.

### Release 2.0.2

#### added:

- `authserver.config.entityStatement.redirectUris` (optional) sets the
  `redirect_uris` of the authserver's entity
  statement statically (env `ENTITY_STATEMENT_REDIRECT_URIS`, A_25656). Empty,
  they are still derived from the realm's
  SekIDP clients
- the authserver's entity statement carries `metadata.federation_entity`
  (gemSpec_IDP_Sek, Tab. 28) with `name` and
  `organization_name` from `authserver.config.entityStatement.clientName` and
  `.organizationName`
- `notificationService.sealing.*` for the keychain of the notification-service:
  `keychainFileName` (default `/keychain/keychain.json`), `rotationInterval`, the init container
  hooks `initContainerProvideKeys` and `initContainerStoreKeys`, and the `keychainGenerator` init
  container (`enabled`, `kekId` required while it runs, `extraVolumeMounts`, image
  `notification-keychain-generator`). Plus `notificationService.extraVolumes` and
  `notificationService.extraVolumeMounts`, which carry the keychain, e.g. from a Secret. See "HSM-backed sealing" in
  [How to configure the notification service](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_notification_service.md).

#### changed:

- **Breaking:** `notificationService.hsm.kek.dekKeyId`, `notificationService.hsm.kek.pseudonymKeyId` and
  `notificationService.sealing.dekCacheSize` are removed; the chart fails the render when they are
  still set. With sealing on, the chart needs a notification-service build with the keychain, and
  records sealed by an earlier build no longer open: start from an empty database.
- `opa-rollout-restart-cronjob`: memory limit 256Mi (was 64Mi, too small for
  kubectl), `concurrencyPolicy: Forbid`, 5-minute `activeDeadlineSeconds`,
  kubectl `--request-timeout`
- token-renewer CronJobs (`opa-`, `ti-siem-`, `ti-sim-`): `concurrencyPolicy:
  Forbid` and `activeDeadlineSeconds`, so stuck runs no longer pile up

### Release 2.0.1

#### added:

- `notificationService.rs.mtls.enabled` (default `true`) switches the RS
  client-certificate check; `/notification-service-rs` is blocked on the public ingress.

#### changed:

- updates testdriver-smcb, testdriver-oidc, nativedriver and androiddriver to 2.0.1

#### fixed:

- mailcatcher keeps only the newest 1000 messages (`messagesLimit`)

### Release 2.0.0

#### added:

- authserver adds `zeta-guard-admin-events` and `zeta-guard-notifications` (new)
  listeners. They report client management-related events to the log and notify
  users, respectively
- Client management of mobile users (`/zeta/clients`, `/zeta/identity/email`) is served through the
  PEP (scope `zeta:client-management`, DPoP, no PoPP) when `authserver.config.oidcFlowEnabled` is set;
  tiger-proxy route included. The corresponding authserver paths under `/auth/realms/zeta-guard/zeta/`
  are closed (Ingress / tiger-proxy → PEP → `404`). The registration's `bind-email/*` endpoints are served
  through the PEP too (reduced binding token with scope `zeta:email-verify`), on their unchanged path.
- New terraform vars to configure TLS, STARTTLS and auth for SMTP server.
  Resolves ANFTI2-1040.
- `notificationService.historyRetention` (default unset -> the service's
  `P30D`, `NOTIFICATION_HISTORY_RETENTION`): after the first recorded
  notification, a device's complete message history is erased once this
  duration has passed; the next notification restarts it. Needs a
  notification-service build with the history retention; older builds ignore
  it.
- Set up telemetry export from notification-service to telemetry-gateway.
  (A_27492-02)
- Disabled access log of notification-service to prevent logging of KVNRs and
  Telematik-IDs. (A_29990)
- ability to retain {authorization,dpop,popp} headers during forwarding via
  `pepproxy.nginxConf.proxyLocations.*.retain.{authorization,dpop,popp}` (boolean), e.g.:

  ```yaml
  - path: /
    upstream: http://fachdienst:8080
    upstreamPath: /
    retain:
      authorization: true
  ```
- `authserver.dbEnc.automaticCryptoUpdatesEnabled` (default `false`):
  if enabled, automatically starts a key rotation of the VAU DB if
  chnages to the keychain configuration are detected. Requires
  `integrityChecksEnabled`.
- `authserver.dbEnc.{futureKeychainFileName, previousKeychainFileName}`:
  specify the future keychain to use and the previously used keychain during a
  VAU DB key rotation.
- Terraform variable `sekidp_client_id` (default empty): the `client_id` of the
  `zeta-sekidp-oidc` IdP, i.e. the realm's public issuer. It used to be derived
  from `keycloak_url` only, which is the admin hostname wherever Terraform goes
  through it — gsi-server then could not fetch the realm's entity statement.
  Set it in that case; empty keeps the previous derivation.
  See [How to configure the SEK-IDP / Fedmaster test chart](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_sekidp.md#the-idps-client_id-sekidp_client_id).
- `mailcatcher.ingressEnabled` (default `false`): optional direct Ingress for the
  MailCatcher web UI at `httpPath`, for stages without tiger-proxy.
- SBOM: every chart tarball now ships a CycloneDX 1.6 inventory of its container
  images (name, tag, digest, registry) as `sbom.cdx.json`; the umbrella tarball is
  published as well. Structure and properties: see the user manual,
  "SBOM der ZETA-Guard-Lieferung".
- `authserver.dbPool.maxLifetime` (default `PT30M`): recycles every pooled JDBC
  connection after this long, so a socket orphaned by a CloudNativePG switchover
  cannot sit in the pool indefinitely. Keycloak's own default for PostgreSQL is
  unlimited.
- `authserver.db.urlProperties` (default `{ socketTimeout: 120, tcpKeepAlive:
  true }`): pgjdbc parameters appended to `KC_DB_URL` as query parameters. Raise
  `socketTimeout` for a release with a heavy schema migration — it bounds every
  statement, Liquibase DDL included. `connectTimeout` and `targetServerType` are
  rejected at render time: naming either in the URL makes Keycloak stop
  injecting its own default for the other.
- `timeoutSeconds` on all three `authserver.probes` (default `5`), and
  `values.schema.json` now requires it. Left unset, Kubernetes applies its own
  default of **1 s**. That is too tight for the readiness probe: Agroal's
  `invalidCount` never resets, so from the first evicted connection onwards
  Keycloak answers every readiness probe with a real database round-trip instead
  of from pool metrics — and a 1 s budget flaps under load. The upper bound is
  Agroal's acquisition timeout (`PT20S`).
  See [How to configure the authserver](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_authserver.md#probes).
- `authserver.dbPool.{validationQueryTimeout,backgroundValidationInterval,
  foregroundValidationInterval,idleRemovalInterval}` and defaults for
  `authserver.db.urlProperties` (`socketTimeout: 120`, `tcpKeepAlive: true`).
  Together these are what makes the authserver survive a database failover.
  See [How to configure the authserver](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_authserver.md#connection-resilience-and-database-failover).
- `pepproxy.nginxConf.pepInternalUrl`: cluster-internal address of the
  authserver, used only for OIDC discovery and the JWKS fetch. Previously both
  followed the public `pepIssuer` and left the cluster through the ingress.
  `pepIssuer` stays the expected `iss`, tokens are unaffected. **Off by
  default**; set it e.g. to the `authserver` Service,
  `http://authserver/auth/realms/zeta-guard`.
  See [How to configure the authserver](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_authserver.md).
- `pepproxy.nginxConf.pepRevocationUrl`: session revocation endpoint of the
  authserver, previously hardcoded. Defaults to `pepInternalUrl` (or the
  `authserver` Service) plus `/zeta-guard-revocation`.
- `pepproxy.hostAliases`: extra `/etc/hosts` entries for the PEP pod in native
  Kubernetes form, merged with the `global.enableDNSRedirect` entries. Supported
  replacement for driving PEP name resolution through `global.dns.redirects`,
  which is scoped to tiger-proxy/OCSP test routing.
- `notificationService.hsm.*`: HSM Proxy wiring for the notification-service — All
  optional; unset values keep the service defaults, but are only relevant if sealing is enabled.
  Needs a notification-service build that implements the `hsm-proxy.*` properties — 1.3.0 and 1.3.2
  ignore them, current `main` builds and future version implement them.
- `notificationService.sealing.dekCacheSize`: how many unpacked DEKs are kept
  in memory (`NOTIFICATION_PERSISTENCE_SEALING_DEK_CACHE_SIZE`), unset -> the
  service default, must be 1 or larger. `sealing.enabled: true` now requires
  `notificationService.hsm.endpoint`.
- `notificationService.env.encryptionEnabled`: toggles encryption of push
  notification payloads when the notification-service dispatches them.
- Added default configuration for optional `tail_sampling` processor for TI-SIM.
- Added disclaimers regarding the chart-development-only `Makefile`.
- `authserver.resourceServerMtls` (default off): mTLS for resource servers
  calling `GET /auth/realms/<realm>/zeta/userinfo/email`, which now releases the
  verified email of a mobile user. When enabled, the master ingress requests an
  optional client certificate on `authserver.hostname`
  (`ssl_verify_client optional_no_ca`, prepended to any
  `ingressMasterAnnotations."nginx.org/server-snippets"`). The authserver then
  validates the chain against `resourceServerMtls.truststore`, or against
  Keycloak's HTTPS truststore if that is left empty. Requires
  `authserver.config.oidcFlowEnabled: true`. Browsers with client certificates
  installed may show a certificate picker on that host.

#### changed:

- **BREAKING** With `authserver.config.oidcFlowEnabled`, `provisioningProcessor.federationMaster`
  must be enabled (with `environment`); the authserver reads the Fedmaster URL from the
  provisioned `federation-master.json`. Terraform `sekidp_fedmaster_url` is removed.
- updates nginx/nginx-prometheus-exporter to 1.5.3
- updates OPA-Image to 1.21.3-static
- Enabled `pepproxy.nginxConf.noTravel` by default as required per spec.
  This basically fixes a session to an ip address.
- *Action required* only relevent to users of nginx ingress: To sufficiently
  comply with A_26668-02, we had to set a default rate limit. If you have not
  configured your own rate limit yet, you will probably need to set values that
  fit your installation. See
  `ingressMinionAnnotations.nginx.org/limit-req-rate`,
  `ingressMinionAnnotations.nginx.org/limit-req-key` and
  `ingressMinionAnnotations.nginx.org/limit-req-zone-size`.
- updates nginx-ingress chart to 2.8.0 (NIC 5.7.0)
- updates keycloak-zeta, ngx_pep, nginx-ingress, provisioning-processor and notification-service to 2.0.0
- updates keychain-generator to 2.0.10
- updates testdriver-smcb, testdriver-oidc, nativedriver and androiddriver to 2.0.0
- updates testfachdienst and zeta-tls-test-tool-service to 2.0.0, tiger-proxy to fork-2.0.0
- **BREAKING** sekidp (A_26973-03): the `zeta-sekidp-oidc` IdP additionally
  requests `urn:telematik:geburtsdatum`, so the sectoral IDP releases the
  insured
  person's consent-dependent `birthdate`. Re-issue
  `sekidp.gsiServer.entityStatementAboutRp` with that scope — gsi-server rejects
  the PAR otherwise (`invalid_scope`, "exceeds scopes found in entity
  statement").
  See [How to configure the SEK-IDP / Fedmaster test chart](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_sekidp.md).
- sekidp: `gsi-server` and `gsi-fedmaster` use a `startupProbe` instead of a
  fixed 45 s `initialDelaySeconds`, configurable via `sekidp.<component>.probes`.
  Each pod was ready ~50 s after its container started, the two in sequence;
  now as soon as actuator answers.
- Authserver init container `keycloak-build` is now `keycloak-copy`: it only
  copies `/opt/keycloak` into the pod volume, the `kc.sh build` that `startup.sh`
  runs anyway before `start --optimized` is no longer done twice (~30 s less per
  start). Default `authserver.initContainer.resources` shrank accordingly.
- The `/auth` ingress always sets `ssl-client-cert` to the TLS client
  certificate (`$ssl_client_escaped_cert`), so a client can no longer send that
  header itself. The bundled NIC also strips it in `more_clear_input_headers`.

- ⚠️ `opa.simulation.bundle.resource` is now required with bundle mode and
  simulation enabled. The `-sim` tag suffix appended to `opa.bundle.resource` is
  gone:
  gematik names simulation bundles differently per environment, so the derived
  reference 404ed. See [OPA](https://github.com/gematik/zeta-guard-helm/blob/main/docs/reference/OPA.md#simulation-settings).
- `notificationService.env.persistenceSealingEnabled` moved to
  `notificationService.sealing.enabled`, next to the new
  `sealing.dekCacheSize`. The chart fails the render with a pointer when the
  old path is still set.
- The `/authorize` response redirects to the
  SekIDP directly instead of redirecting through the cookie-bound
  `/broker/zeta-sekidp-oidc/login`.
- SekIDP flow: The IdP's `first_broker_login_flow_alias` is removed. Keycloak's
  `SekIDPIdentityProvider` provisions user and Federated Identity itself on
  first login.
- PEP proxy access log: with `pepproxyTracingEnabled: true`, each line now ends
  with `trace_id=<id> span_id=<id>` (OpenTelemetry trace context). Untraced
  requests log empty IDs. With tracing disabled the format is unchanged. The
  telemetry gateway copies them into the OTLP log record's `TraceId`/`SpanId`.
- tiger-proxy image pinned in the umbrella and chart defaults instead of `latest`;
  per-stage overrides dropped.
- The Terraform variable `keycloak_namespace` is only required when
  `use_kubernetes = true`. Local mode reads it nowhere, yet it still made
  `terraform plan` fail with `The argument "keycloak_namespace" is required`.
  See
  [How to configure the authserver](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_authserver.md).
- `enable_sekidp = true` no longer requires `use_kubernetes = true`.
  See [How to configure the SEK-IDP / Fedmaster test chart](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_sekidp.md).
- gsi-server/gsi-fedmaster bumped to 8.5.1: `gsi-server` now validates authserver via a locally mounted entity
  statement (`sekidp.gsiServer.entityStatementAboutRp`).
  See [How to configure the SEK-IDP / Fedmaster test chart](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_sekidp.md).
- Terraform no longer writes the `sekidp-rp01-pubkey` Secret (gsi-server 8.5.1
  gets the entity statement mounted directly, see above). The Kubernetes
  provider and the Terraform variable `config_path` are removed with it.
  (`sekidp-removed.tf`) drops the Secret from the state on the next
  `make config` without touching the cluster.
- new opt-in `keycloak-db.enabled` to provision `keycloak-db` via the upstream
  `cloudnative-pg/cluster` chart instead of the hand-rolled template. Disabled by
  default. Switching it on an already-running, populated cluster triggers a short
  (~3 min on a local test), controlled database restart — no data loss, but plan a
  maintenance window for the switch on a production stage.
- Span attributes from outdated versions of OpenTelemetry's sematic conventions
  will be migrated to their new attribute names across **all** trace
  pipelines – not just the TI-SIEM- and TI-SIM-pipelines.
- Strip embedded metrics from policy engine (OPA) logs before export to TI-SIEM.
- updates zeta-telemetry-gateway to v0.157.0
- `testdriver` was split into `testdriver-smcb` and `testdriver-oidc` with dedicated, prefix ingress routes (`/td-smcb` and `/td-oidc`),
  both variant now only support their respective authentication flows which allows for testing SMCB and OIDC auth with the need to redeploy.
- BREAKING: during testdriver split the `/oidc` route was migrated to `/td-oidc/oidc` of the `testdriver-oidc` and does not longer exists on
  the ingress of the `testdriver-smcb`
- Resolves part of ANFTI2-902. Default values for VAU DB encryption are now fine
  and can be used without further adjustments. **Action required** remove all
  overrides of the following values if you have any:
    - `authserver.dbEnc.columnEncryptionEnabled`
    - `authserver.dbEnc.integrityChecksEnabled`
    - `authserver.dbEnc.integrityRowChecksEnabled`
    - `authserver.dbEnc.integrityTableChecksEnabled`
    - `authserver.dbEnc.periodicRowChecksEnabled`
    - `authserver.dbEnc.lockdownOnError`
    - `authserver.dbEnc.shutdownOnError`

  Only do this on a fresh database or one already converted with these features.
  A database converted while they were `false` (plaintext rows, conversion
  state `DONE`) is never re-converted: the authserver fails with
  `Decryption failed` and crash-loops. Such stages must either keep the
  `false` overrides or wipe the database before switching.

#### fixed:

- `local-test/values.local.yaml`: `sekidp.gsiServer.entityStatementAboutRp`
  re-issued with the `urn:telematik:geburtsdatum` scope and the additional
  redirect URI `de.gematik.zeta://oidc`; the previous statement made gsi-server
  reject the PAR with `invalid_scope`.
- sekidp Ingress: with `sekidp.routeViaTigerProxy: false` the `/sekidp` and
  `/sekidp-fedmaster` prefixes reached gsi-server/gsi-fedmaster unchanged, which
  only serve at `/` — every external request (entity statements, PAR, the
  authserver's federation lookup) answered `404`. The direct route now strips
  the prefix like the tiger-proxy route always did. Stages routing via
  tiger-proxy are unaffected.
- Terraform: keycloak provider constraint raised to `>= 5.9.0`; older
  providers fail with `The attribute client_secret is required`. A stale
  `.terraform.lock.hcl` keeps the old version pinned — delete it and re-run
  `terraform init`.
- **The authserver's liveness probe now targets `/auth-mgmt/health/ready/`.**
  `/health/live` never touches the database, so it could not observe a wedged
  datasource — the pod stayed `Running` and needed a manual restart
  (ANFTI2-881). The liveness probe deliberately stays on the DB-independent
  `/health/live`: making it database-aware would fail it on every authserver pod
  at once during an outage and restart them all, which is why the pool
  recovering
  on its own is the fix rather than a kubelet restart.
- Probe defaults retuned and `timeoutSeconds: 5` set on all three. Leaving it
  unset meant Kubernetes' **1s** default, which flaps: Agroal's `invalidCount`
  never resets, so after the first evicted connection Keycloak performs a real
  database check on every readiness probe instead of answering from pool
  metrics.
  `startup.failureThreshold` raised to 60 (300s) — the previous 100s was tight
  for a cold database plus Liquibase.
- with `networkPolicy.enabled: true`, egress NetworkPolicies for OPA, PEP
  proxy, authserver, opa-simulation and the kpi-metrics-helper CronJob never
  matched telemetry-gateway's pods, silently blocking all telemetry egress to
  it — the podSelector used the vendored chart's literal name
  `opentelemetry-collector`, but telemetry-gateway's Chart.yaml `alias:`
  renders its actual pod label as `telemetry-gateway`. Selectors now match on
  the correct label via a shared `telemetryGateway.selectorLabels` helper.
- the three sekidp entity-statement scripts sent the Keycloak admin credentials
  with plain `-d`, so a password containing `&`, `=`, `+`, `%` or a space failed
  to authenticate. They now use `--data-urlencode`, like every other script in
  `terraform/authserver/scripts/`.
- `data.external.manage_policies` referenced `scripts/managePolicies.sh` without
  the `${path.module}/` prefix, so it only resolved while terraform ran from
  inside `terraform/authserver`. Now module-relative, as every other script
  reference in the module already was.
- When using a HSM for ASL, it is not required to provide a TLS cert for PEP
  anymore. Fixes ANFTI2-959
- New Terraform variables `sso_session_idle_timeout` and
  `sso_session_max_lifespan` (default `24h`, previously Keycloak's 30m/10h) keep
  the authserver session alive for the policy's refresh-token TTL; refreshing an
  idle client no longer returns `400 invalid_grant` "Session not active".
  See [How to configure the authserver](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_configure_authserver.md#session-lifetime).

### Release 1.3.4

#### changed:

- bumped authserver version to `1.3.3` to include important security hotfix.

### Release 1.3.3

#### changed:

- pepproxy image `1.3.3` (hardened ASL subrequest target URL handling)

### Release 1.3.2

#### ⚠️ breaking — read before upgrading from 1.3.0/1.3.1:

- keycloak-zeta 1.3.2 fixes the identifier casing in the `ZETA_USER_DATA`/
  `ZETA_CLIENT_DATA` Liquibase migration. The already-applied changesets were edited in
  place, so their checksums changed: **every stage installed with 1.3.0/1.3.1 must, before
  upgrading, drop the `ZETA_USER_DATA`/`ZETA_CLIENT_DATA` tables AND delete the file's
  Liquibase bookkeeping** in the plugin's own `databasechangelog_zeta_guard` table — dropping
  alone is not enough, the stored checksums still fail validation and the authserver does not
  start:
  ```sql
  DROP TABLE IF EXISTS zeta_client_data, zeta_user_data CASCADE;
  DELETE FROM databasechangelog_zeta_guard WHERE filename LIKE '%jpa-changelog-26.6.3%';
  ```
  On startup the migration then re-runs and recreates both tables. Registered DCR clients
  are lost by the drop and have to re-register. Step-by-step procedure:
  [Pflichtschritt: Update von 1.3.0/1.3.1 auf 1.3.2](../../Anleitungen/Wie_Sie_ZETA_Guard_aktualisieren.md#pflichtschritt-update-von-130131-auf-132).

#### added:

- `telemetryGatewaySendingQueuePVCAccessModes` (default `[ReadWriteOnce]`) and
  `telemetryGatewaySendingQueuePVCStorageClass` (default `""`, i.e. the cluster's default
  class) make the telemetry-gateway's sending-queue PVC match your storage system —
  `ReadWriteMany` for shared filesystems.
- Documented how to run the telemetry-gateway on OpenShift: it is the only component pinning
  `runAsUser`/`fsGroup` and both must be handed to the SCC with an explicit `null` — omitting
  the keys silently inherits the chart default because Helm merges maps.
- `notificationService.db.kind`: database kind for the notification-service
  (`NOTIFICATION_DATASOURCE_DB_KIND`, required by images >= 1.3.2), default `postgresql`;
  cloudnative mode accepts only `postgresql`.
- [How to upgrade ZETA Guard](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_upgrade_ZETA_Guard.md): the
  supported upgrade path (`helm upgrade` + `make config`), what protects the Terraform state,
  and how to adopt an existing realm when the state was lost. Every step is given as both the
  `make` target and the plain `terraform` command.

#### changed:

- updates keycloak-zeta, ngx_pep, notification-service, provisioning-processor, testdriver and
  nativedriver to 1.3.2
- updates zeta-telemetry-gateway to v0.156.0
- updates OPA image to 1.19.1-static
- The Keycloak admin credentials no longer reach the Terraform state. Terraform no longer reads
  the `authserver-admin` Secret at all — the new `terraform/authserver/scripts/kc-admin-env.sh`
  fills `TF_VAR_keycloak_username`/`TF_VAR_keycloak_password` from it, and both are now
  `ephemeral` and required in either mode. The SMC-B identity provider secret moved to the
  provider's write-only argument; bump the new `smc_b_client_secret_version` to push a rotated
  value. **Terraform 1.11 or newer is required.**
- The Terraform variable `audience_scope_name` has no default any more and must be set in every
  stage tfvars. It names the only scope carrying the access-token claims the PEP validates, so a
  silent `zero:audience` fallback hid misconfiguration.
- `terraform/authserver/environments/demo.tfvars` now documents every accepted Terraform
  variable with its default and works as a copy-paste template.
- `enable_sekidp = true` now requires `use_kubernetes = true` and fails the plan otherwise.
- `values-demo.yaml` brought back in sync with `values.yaml`.
- the pre-1.3.0 flat `gematik.idTokenAudience` / `gematik.serviceAccountEmailAddress` are gone
  for good. Setting either value now fails the render with a pointer to `gematik.tiSim.*` /
  `gematik.tiSiem.*` instead of silently renewing a token for an empty service account.
- `gematik.tiSiem` is now also declared in `values.schema.json`.
- Logs, metrics and span attributes that serve solely security purposes are no longer
  available to Dienstherstellers (`filter/dienst_hersteller`, `transform/dienst_hersteller`).
- OPA decision logs are no longer written to console (`opa.logDecisions` default `false`).

#### fixed:

- `notificationService.<rs|fdv>.image.tag` had no effect: the documented per-variant tag
  override was ignored by the image helper (only `image.digest` was honored).
- `terraform import` against an existing realm aborted with `Invalid for_each argument` before
  importing anything; both notification mapper resources now key their `for_each` off a local,
  instance keys are unchanged, so an applied stage plans no changes.
- `make config-import` imported `keycloak_realm.pdp_realm`, an address renamed before 0.2.0,
  and its error fallback swallowed the failure. It now imports `keycloak_realm.zeta_realm`,
  skips a realm already in the state and fails loudly otherwise.
- rendering the chart with a disabled telemetry pipeline
  (`telemetry-gateway.config.service.pipelines.<name>: null`) aborted with
  `index of untyped nil`; the opentelemetry-collector chart's deprecated-name auto-rewrite is
  now off (`telemetry-gateway.rewriteDeprecatedComponentNames: false`), rendered output is
  unchanged.
- With `use_kubernetes = false` the Kubernetes provider is no longer a provider requirement —
  `terraform init` no longer downloads it.
- `authserver.provider.smcB.ocspFailClosed` had no effect: the value was accepted and
  documented, but the authserver deployment never rendered the corresponding env var.
- `global.noProxy`: a leading dot on the **first** entry (e.g. `".cluster.local,…"`, exactly
  what the forward-proxy guide recommends) was not converted to `*.` for
  `http.nonProxyHosts` — Java ignores `.cluster.local`, so Keycloak sent cluster-internal
  traffic through the forward proxy.

#### removed

- The fixed client scopes `zero:register` and `zero:manage` and their authorization-server
  audience mapper. A terraform apply deletes them from existing realms; clients still
  requesting either scope must drop it.

### Release 1.3.1

#### changed:

- Raise tag versions

### Release 1.3.0

#### known issues:

- Database encryption and integrity for VAU: The readiness endpoint becomes
  "ready" prematurely. Under load this leads to bad keycloak instances that
  yield error 500 on most requests.
    - This is **no Problem for VSDM** and other services that don't use the VAU
      dbEnc feature.
    - **Workaround**: Set the `authserver.probes.readiness.initialDelaySeconds`
      in the kubernetes readiness Probe to a high value, so that spree integrity
      provider is ready in that time. A value like `240` should be a safe
      starting point for this.

#### added:

- **ZETA Stufe 2 — OIDC mobile-client flow** (
  `authserver.config.oidcFlowEnabled`,
  default `false`): mobile clients authenticate via a federated sektoraler
  Identity Provider (SekIdP) instead of an SMC-B token exchange.
- **Notification Service** as a bundled, opt-in zeta-guard component
  (`notificationService.enabled`, default `false`) — the ZETA Stufe 2 push
  notification management and forwarding service, with its own PEP routes,
  discovery document, and database.
- Test-support subcharts for exercising the ZETA Stufe 2 flows locally
  (`push-gateway`, `sekidp`, `mailcatcher`, `nativedriver`) — not part of ZETA
  Guard, all disabled by default.
- `authserver.truststoreReload` (`enabled`, `interval`) lets the authserver pick
  up refreshed SMC-B, TPM and OCSP trust anchors while it runs, without a
  restart and without dropping requests. Needs an authserver image > 1.2.3.
- `provisioningProcessor.schedule` (`enabled`, `time`, `timezone`) keeps the
  provisioning processor resident as a native sidecar of the authserver and
  re-runs it daily. Enabled by default; needs Kubernetes >= 1.32 (OpenShift
  4.19) and a
  provisioning-processor image that supports `SCHEDULE_TIME`.
- `spree.config.realm.enabled` is now set to true at the very end in the
  bootstrap process of keycloak by terraform
- `telemetryGatewayHost` — sets the fully-qualified hostname the
  telemetry-gateway
  is reached at, for clusters where its bare service name does not resolve.
- `opa.simulation.bundle.verification` to override bundle signature
  verification for the simulation OPA instance only.
- `pepproxy.hsmTlsKeyId` / `hsmTlsCert` to configure the PEP TLS HSM key ID and
  certificate file (defaults unchanged: `tls.p256` / `tls.p256.pem`).
- `pepproxy.asl_hsm_key` — HSM-backed ASL signer key as `store:hsm:<key-id>`
  URI; replaces the file-based signer key from the `asl-identity` secret and
  drops its mount. Requires `pepproxy.hsmProxyAddr`.
- Session revocation support: `zetaGuardRevocations` cache in the Infinispan
  server config (dedicated-Infinispan deployments only — the authserver refuses
  to start
  without it), `zeta-guard-revocation-events` in the realm's `eventsListeners`
  (`terraform/authserver/events.tf`, which declares the complete list — check
  the plan
  before applying to an existing realm), and `pep_revocation_url` pointing at
  the
  authserver's in-cluster Service. That endpoint is intra-cluster only and
  cannot work
  through an ingress; with NIC it is denied on every exposed hostname.
- `authserver.provider.smcB.ocspConnectTimeoutMs` / `ocspReadTimeoutMs` /
  `ocspFailClosed` (default `false`, fail-open) for the SMC-B OCSP revocation
  check.
- `nginxIngressLbMethod` toggle for the sticky-session lb-method on the minion
  ingress.
- `cloudnativePg.enablePDB` and `cloudnativePg.storage.pvcTemplate` to
  parameterize the CNPG PDB and storage class.
- `cloudnativePg` config surface for `imagePullPolicy`, `affinity`,
  `monitoring`, `pooler`, and `backup` (pooler and backup disabled by default).
- `networkPolicy.dns` — make the DNS egress peer of the egress NetworkPolicies
  configurable (`namespaceSelector`, `podSelector`, `ports`, or a raw `to:`
  override). Defaults to the upstream `kube-system` / `k8s-app: kube-dns` /
  port 53 peer, so existing deployments are unchanged. For OpenShift, set the
  `openshift-dns` selector (`dns.operator.openshift.io/daemonset-dns: default`)
  and port 5353 — DNS runs in the `openshift-dns` namespace and OVN-Kubernetes
  evaluates egress post-DNAT, so the destination pod port is 5353, not 53.
- `pepproxy.nginxConf.proxyLocations` — structured, schema-validated
  configuration of the resource-server proxy locations. Each entry generates an
  http-level `upstream` block with connection keepalive, an exact + prefix
  location pair, and always includes `proxy_headers.conf`; supports
  `websocket`, `bypassAsl`, `keepalive`, and tpl-rendered `extraConfig`.
  Replaces the raw `locations` string, which is now **deprecated** and
  scheduled for removal; setting both at once fails the render (they are
  mutually exclusive — migrate entirely, do not mix).
- Dedicated `zeta-guard-ws-minion` Ingress, derived from `proxyLocations`
  entries with `websocket: true`. The NIC `websocket-services` annotation moves
  to this minion so only WebSocket paths get `Connection: upgrade` handling —
  all other locations regain NIC→PEP upstream keepalive (a blanket annotation
  forced `Connection: close` per request and exhausted NIC ephemeral ports
  under load).
- Stable `nginx-ingress-metrics` Service in front of the NIC's Prometheus
  exporter; the telemetry-gateway now scrapes NIC metrics into the
  Dienst-Hersteller stream.
- Expose additional CloudNativePG options: `cloudnativePg.extraParameters` (
  arbitrary
  reloadable postgres settings), `sharedPreloadLibraries`,
  `storage.storageClass`
  shortcut, and optional dedicated `walStorage` volume
- Specific information from the policy engine's decision logs will be extracted
  into OpenTelemetry attributes for further processing.
- Added counter metrics for ZETA client requests.
- New config options to configure nginx worker processes in pep.
  The defaults are the previous values.
  |value|description|default|
  |---|---|---|
  |pepproxy.workerProcesses|Number of worker processes; "auto"=cpu count|auto|
  |pepproxy.workerConnections|Max. number of connections per worker|16384|
  |pepproxy.workerRlimitNofile|Max. number of open files, per worker. Should be
  at least 2*workerConnections|40960|
- Support for serving the OPA policy bundle from an operator-hosted private
  registry whose TLS certificate is issued by an internal CA. Note the
  full-CA-bundle
  requirement in
  [Wie Sie eine eigene OCI Registry verwenden](../../Anleitungen/Wie_Sie_eine_eigene_OCI_Registry_verwenden.md#ca-zertifikat-für-die-registry).
- `opa.bundleHealthCheck` (default `false`) — surfaces a failed OPA bundle
  download
  as `NotReady` via the readiness probe. See
  [Wie Sie OPA in ZETA Guard konfigurieren](../../Anleitungen/Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md#fehlgeschlagene-bundle-downloads-sichtbar-machen).
- Various client-ip and forward headers are now stripped by default at NIC, and
  externalTrafficPolicy now defaults to `Local`, to preserve client IPs.
    - NIC is now a DaemonSet, so all nodes continue to accept traffic, and don't
      request cpu resources any more
- `opa.rolloutRestart` — optional CronJob that periodically restarts the OPA
  Deployment via `kubectl rollout restart` (default: disabled). Runs on a
  configurable `schedule` (fixed `Europe/Berlin` timezone), reusing
  `provisioningProcessor.image` rather than a separate tooling image. The
  chart creates its own ServiceAccount + minimal RBAC (`get`/`patch` on the
  `opa` Deployment only) unless `opa.rolloutRestart.serviceAccountName` is
  set to an externally pre-provisioned ServiceAccount.

#### changed:

- The chart now declares `kubeVersion: ">=1.32.0-0"`, the supported platform
  baseline
  sidecar init container used by `provisioningProcessor.schedule`.
- The `filter/ti_siem` whitelist now forwards the new security event
  `authn_client_deleted` to TI SIEM.
- Ingresses are split per route, since NIC applies `lb-method`, `ssl-services`
  and
  `location-snippets` per minion: `zeta-guard-pep` (`/`, renamed from
  `zeta-guard-minion`), `zeta-guard-auth` (`/auth`, new) and — with
  `authserver.adminHostname` — `zeta-guard-admin-auth` (`/auth` on that
  hostname, renamed
  from `zeta-guard-admin-minion`). `lb-method` on `/auth` is **required**, not
  tuning:
  nonces are kept per node, so with it off and more than one authserver replica,
  token
  exchange fails with `Invalid nonce value` about half the time.
- `zeta-guard-admin-auth` gained the `ssl-services` annotation it was missing (
  it routes
  to the authserver's `https` port when TLS is enabled).
- with `authserver.adminHostname` set, `/auth/admin` is denied with `403` on the
  public hostname. The `zeta-guard-pep` minion routes that one path to the PEP,
  which denies it, so the block needs nothing but plain Ingress path routing and
  holds for **any** ingress controller — overlapping prefixes resolve
  longest-match-first.
- NIC subchart install is now gated by `nginx-ingress.enabled` (was
  `nginxIngressEnabled`); annotations still gated by `nginxIngressEnabled`.
- Only logs and metrics from resource servers are exported to TI SIM.
- Only spans from resource servers and HTTP server spans from the ZETA guard
  HTTP proxy are exported to TI SIM.
- All logs and spans with a service name starting with "rs." are recognized as
  coming from a resource server.
- Only logs, metrics and spans about specific security events from ZETA guard
  are exported to TI SIEM:
    - Metrics and spans about detected attacks
    - HTTP server spans received by authorization server and HTTP proxy
    - HTTP client spans that trigger policy decisions
- Every log, metric, and span now has the resource attribute `service.version`
  with the chart version as value.
- Configured sending queue, retry behavior and timeout of telemetry exporter
  `otlp_grpc/ti_sim`.
- PEP nginx: `reuseport` on all listeners (per-worker accept queues),
  widened `net.ipv4.ip_local_port_range` via pod sysctl and raised
  `worker_rlimit_nofile`
  to optimize connection handling
- NIC ConfigMap defaults: upstream `keepalive`, `keepalive-requests: "10000"`,
  `worker-connections`, and `worker-rlimit-nofile` — prevents ephemeral-port
  exhaustion (TIME_WAIT churn) on NIC→backend connections under load.
- Resource baselines sized for the 300 rps performance target: authserver
  memory limit 6Gi, PEP 3 CPU / 2Gi requests, CNPG 2 CPU / 2Gi requests
  (3Gi limit), `sharedBuffers: 512MB`, `maxConnections: 250`, and
  `wal_compression: on` (≈3× WAL volume reduction, fewer forced checkpoints).
- The following security events are reported to TI-SIEM:
    - client registrations
    - token exchanges
- Renamed TI-SIM-related values, Secret and CronJob.
    - Replaced value `gematik.idTokenAudience` with
      `gematik.tiSim.idTokenAudience`.
    - Replaced value `gematik.serviceAccountEmailAddress` with
      `gematik.tiSim.serviceAccountEmailAddress`.
- Added separate values, Secret, CronJob, OTLP exporter, etc. for TI-SIEM.
- Any OPA status update log containing error codes will have severity 'error'
  set.
- Any log from ZETA guard with severity 'error' or 'fatal' is exported to
  TI-SIM.
- Repaired counter metric of detected attacks.
- Every log, metric and span passing through the telemetry-gateway receives the
  attribute `server.address` if missing.
- Updated OpenTelemetry collector to version 0.155.0
- Configured telemetry exporters with persistent storage for sending queues.
- updates OPA-Image to 1.19.0-static
- updates PostgreSQL-Image to postgresql:17.11-standard-trixie

#### fixed:

- with `telemetryGatewayEnabled: false`, OPA logged `status update failed, server
  replied with HTTP 403 Forbidden` once per bundle poll: an empty
  `status.service` is silently defaulted by OPA to the first configured
  service — in bundle mode the policy registry, which rejects the status POST.
  `status` and
  `decision_logs` are now rendered only with a sink, never with an empty
  `service`. Policy decisions were never affected.
- with `authserver.adminHostname` set, the Keycloak admin console was
  unreachable: `--hostname-admin` was passed without the `/auth` context path,
  so Keycloak served the console at `/auth/admin/` but redirected to `/admin/` —
  a path neither Keycloak nor the admin Ingress answers. Both hostname flags now
  carry `/auth`. Discovery and the token `iss` are unchanged.
- secure Keycloak admin passwords (containing spaces, `&`, `$`, `+`, `"` or
  backticks) now work in the authserver config
- telemetry-gateway crash-looped on fresh namespaces until the first
  token-renewer CronJob run: the `ti-siem-token` and `ti-sim-token` Secrets now
  always render `data.token` — a placeholder on first install, the live value
  carried forward via `lookup` afterwards — so the pod starts immediately and
  upgrades never drop the renewed tokens. On the first upgrade from the
  pre-split chart, the legacy `gematik-oidc-token` Secret seeds both new
  Secrets so exports keep working until the renewers run.
- cert-manager first-issuance deadlock on fresh namespaces: the chart now
  creates an explicit `Certificate` with
  `cert-manager.io/issue-temporary-certificate`, so the NIC can serve a
  temporary certificate while the real one is being issued (ingress-shim does
  not propagate that annotation, and the ACME HTTP-01 solver could never be
  reached through a TLS-less ingress).

  **Upgrade note for existing namespaces:** previous releases let ingress-shim
  create the `zeta-guard-tls` (and `zeta-guard-admin-tls`) Certificates from
  Ingress annotations, and helm refuses to manage such pre-existing objects
  (`invalid ownership metadata`). The chart handles this automatically: while
  a foreign Certificate exists it is skipped from the release (the existing
  object keeps serving and renewing TLS), and a one-shot
  `post-install`/`post-upgrade` hook Job adopts it into the release —
  including removing the stale `ownerReference`, without which ingress-shim
  would garbage-collect the object once the Ingress annotations are gone. The
  **next** helm operation then renders and manages the Certificate normally
  (adoption is metadata-only: the TLS Secret is untouched and no certificate
  is reissued). Should that operation report a server-side-apply field
  conflict (only possible if the old Certificate's spec drifted from the
  chart values), run it once with `helm upgrade --force-conflicts`.

  When installing with `--no-hooks`, perform the adoption manually before
  upgrading (repeat for `zeta-guard-admin-tls` if present):

  ```sh
  kubectl -n <ns> patch certificate zeta-guard-tls --type=json \
    -p='[{"op":"remove","path":"/metadata/ownerReferences"}]'
  kubectl -n <ns> annotate certificate zeta-guard-tls \
    meta.helm.sh/release-name=<release> meta.helm.sh/release-namespace=<ns>
  kubectl -n <ns> label certificate zeta-guard-tls app.kubernetes.io/managed-by=Helm
  ```
- non-constrained tls 1.3 ciphers (accept only
  `TLS_AES_256_GCM_SHA384:TLS_AES_128_GCM_SHA256`
  instead of all defaults) and GS-A_5322 compliance (disable
  `ssl_session_tickets`
  because we can't guarantee compliant STEK, and enable shared session cache)

#### removed

- all cpu limits in the chart defaults. They lead to issues with dropped
  connections
  during the time processes get “frozen” on quota exhaustion, and other knock-on
  effects.
- dead values `opa.workloadIdentityFederation.sts.{audience,tokenUrl,iamUrl,scope}` and
  `…gar.host` from schema/examples — never read by any template; the schema now rejects
  unknown `sts` keys.

### Release 1.2.5

#### fixed:

- bumped authserver version to 1.2.4 to include important security hotfix.

### Release 1.2.4

#### fixed:

- bumped pep version to include important security hotfix. (with thanks to
  Machine Spirits UG)

### Release 1.2.3

#### added:

- New value `provisioningProcessor.provisioningContainerCaConfigMapRef` — a
  ConfigMap alternative to `provisioningContainerCaSecretRef` for the
  provisioning container registry CA (e.g. the CA bundle generated by
  OpenShift's custom PKI mechanism, which is published as a ConfigMap). Mutually
  exclusive with the Secret reference; the Secret takes precedence if both are
  set.
- New values `provisioningProcessor.extraEnv`,
  `provisioningProcessor.extraVolumes`
  and `provisioningProcessor.extraVolumeMounts` on the provisioning processor
  init container, letting operators mount the registry CA (or other material)
  from any source — Secret, ConfigMap, projected volume, CSI, etc.
- New value `provisioningProcessor.registryCredentialsSecretRef` — references an
  existing Secret (e.g. created from a SealedSecret) holding a username and
  token, wiring `PROVISIONING_CONTAINER_REGISTRY_USERNAME` /
  `PROVISIONING_CONTAINER_REGISTRY_TOKEN` into the init container so the
  provisioning container can be pulled from registries that do not allow
  anonymous access. Configurable key names via `usernameKey`/`tokenKey`
  (defaults `username`/`token`).

#### changed:

- updates OPA-Image to 1.18.2-static

#### fixed:

- `opa-token-renewer-cronjob` annotated the wrong Secret (`gematik-oidc-token`)
  with its `last-updated` timestamp instead of the Secret it actually patches
  (`opa-gcp-token`). With `set -euo pipefail` this aborted the run when
  `gematik-oidc-token` did not exist (e.g. `gematikConnectionEnabled: false`),
  marking the CronJob as failed even though the GAR token had been written
  successfully.

### Release 1.2.2

#### changed:

- VAU related bugfixes
- fixed: Now enforcing client and dpop key binding in smc-b token

### Release 1.2.1

#### changed:

- Update authserver to 1.2.2 with an important VAU related bugfix
  (Note: The authserver version is not a typo. In the 3rd digit release versions
  of the individual components of the helm chart may differ from the helm chart
  version.)
- OTEL config for pep (+spanmetrics). It now emits OTLP logs, traces, and
  metrics (in addition to nginx-otel defaults)
- New value `issuer` — emits the namespace-scoped `cert-manager.io/issuer`
  annotation on the master Ingress resources instead of
  `cert-manager.io/cluster-issuer`. Takes precedence over `clusterIssuer` when
  set. Lets operators who are not permitted to deploy cluster-scoped
  `ClusterIssuer` resources (governance/security policy) use a namespace-scoped
  cert-manager `Issuer`. Default `""` keeps the existing ClusterIssuer behavior.
- Updated OpenTelemetry collector to version 0.154.0 and added spanmetrics
  connector
- Updated metric `attack.detection.count` to count attack spans from all
  sources, instead of attack logs from only the authorization server

### Release 1.2.0

#### migration:

- **Keycloak version bumps require a deployment cutover.** Plain`helm upgrade`
  hangs when the new Keycloak version ships a different JGroups protocol
  version; mixed-version pods can't form a cluster. Liquibase migrations and
  Infinispan cache serialization can also clash across minor versions. Run one
  of the following before/during the upgrade:

  ```sh
  kubectl -n <namespace> delete deployment authserver   # then helm upgrade as usual
  # OR
  helm upgrade --force ...                              # delete + recreate as part of the upgrade
  ```

  Not needed for deploys that don't change the Keycloak image tag (config
  tweaks, label changes, resource bumps).

  NOTE: Once installations are in production this kind of update will be
  avoided / flanked
  with measurements supporting availability.

#### added:

- Added `include proxy_headers.conf;` to each `pep on;` location using
  `proxy_pass` in PEP
- New value `authserver.hsm.tokenSigning.failClosed` (default: `true`) — when
  HSM token signing is enabled, refuse software-key fallback if HSM is
  unreachable.
- configuration for application level db encryption (only for VAU based
  applications)
- New values `pepproxy.wellKnownResourceSuffix` (default: `/pep/`) and
  `authserver.wellKnownAuthServerPath` (default: `/`) make the path components
  of the `/.well-known/oauth-protected-resource` document configurable.
- Forward proxy support for all ZETA Guard components
    - Env vars set in all affected pods: `HTTP_PROXY`, `http_proxy`,
      `HTTPS_PROXY`, `https_proxy`, `NO_PROXY`, `no_proxy`, `ALL_PROXY`,
      `all_proxy`.
    - PEP (nginx): proxy vars propagated to worker processes via `env`
      directives in `nginx.conf`, picked up by the `reqwest` HTTP client at
      worker init.
- Enabled SIEM telemetry delivery to gematik by default
- Enabled metrics delivery to gematik
- Filter telemetry sent to gematik (incl. SIEM).
    - Drop all logs except logs about authorization server, HTTP proxy, policy
      engine, and resource server.
    - Drop all metrics about zeta-guard components.
    - Drop all spans except for HTTP server spans about requests to public
      endpoints of authorization server, HTTP proxy, policy engine, and resource
      server.

#### changed:

- Scope name validation in the Terraform authserver config (`pdp_scopes` and
  `audience_scope_name`) now allows periods (`.`).
- Updated OpenTelemetry collector to version 0.153.0.
- The terraform config step now removes all RSA key providers from the
  `zeta-guard` realm.
  Only ECC keys (ES256 / P-256) remain in the JWKS endpoint
  (`/auth/realms/zeta-guard/protocol/openid-connect/certs`). RSA keys that
  Keycloak creates automatically on realm initialization (e.g.
  `rsa-enc-generated`) are deleted unconditionally as part of every Terraform
  run.
- Copy existing OpenTelemetry attributes to `client.address`,
  `http.request.method`, `http.response.status_code`, `user_agent.original` und
  `server.address`. This is a workaround to fulfill A_27725 required until PEP
  adheres to OpenTelemetry semantic conventions 1.41.
- some APIs of the authserver now conform with gemSpec_ZETA 1.3.0 better but
  break compatibility with the client SDK 1.0.x . This affects OCSP for SMC-Bs
  audiences and some expected token content among other things (See
  keycloak-zeta release notes for more info)

#### removed:

- `authserver.provider.smcB.opa.enabled`, `…opa.failClosed`, and chart-root
  `opa.enabled` — OPA enforcement is now mandatory and always fail-closed.
  **Migration**: stale toggle values in override files are silently ignored
  after upgrade — OPA will start unconditionally and return
  `503 temporarily_unavailable` when unreachable. Remove the keys from values to
  avoid confusion.

#### known issues:

- TLS termination directly at the authserver and PEP does not yet fully conform
  to the spec. Therefore, this feature is *NOT PRODUCTION READY* yet.
  Termination at the ingress controller works as specified and is production
  ready.
- The authserver returns incorrect HTTP status codes for some denied tokens
  (some even return 500). These cases have been investigated, and no negative
  security implications have been identified. Some fixes for these issues depend
  on upstream pull requests.
- Expired clients are not automatically deleted yet. Additionally, clients are
  not removed when the maximum client limit per Telematik ID is reached.
- Request processing by the authserver may be slow under load. Remediation
  appears to be possible with a more powerful database (more memory, CPU, and
  connections).
- OCSP during token exchange does not yet support revoked issuer CAs and does
  not enforce the same TSP for the OCSP signer and the certificate issuer.
- Token signature keys do not yet support automatic rotation.
- Some PEP response codes for denied requests do not match the specification.
- Impossible/no travel is detected (and denied), but sessions are not
  invalidated.
- Telemetry delivery to gematik has some limitations regarding the exact fields
  that are delivered. Delivery from the resource server is passed on correctly,
  however.
- Some security KPIs are missing.
- Caching, ETags, etc., do not work yet.
- Rate limiting can be configured and works. However, communication to the
  client via headers does not work yet.

### Release 1.0.1

#### added:

- configuration for application level db encryption (only for VAU based
  applications)

#### changed:

- When using ASL `pepproxy.nginxConf.locations` are now by default not public
  anymore (nginx directive `deny all;`). This makes misconfiguration harder. In
  case there are locations that should be reachable without using ASL, you will
  now need to add `satisfy all; allow all;` to that location for it to be
  reachable. Make sure this is permitted by your spec.
- session affinity is cookie-based now (zeta-route), instead of relying on
  x-forwarded-for header from downstream

#### removed

- `zeta-guard.sessionAffinity`, it is always enabled now (NIC)

### Release 1.0.0

#### added:

- Egress NetworkPolicies (`networkPolicy.enabled`, default: `false`). When
  enabled, each ZETA
  Guard pod gets a `NetworkPolicy` (egress-only) that restricts outbound traffic
  to explicitly configured IP blocks.
- hsmsim: Allow mounting certs from secret, remove persistent mode (unused)
- ingress: Add `zeta-guard.nginxIngressHsm`. If true (and
  `zeta-guard.nginxIngressEnabled`),
  don't define `tls` on master ingress. This allows to use the ossl_hsm provider
  (controller image `ngx_pep/nginx-ingress` contains it), and inject custom TLS
  configuration.
- Keycloak Admin REST API protection via a dedicated admin hostname
  (`authserver.adminHostname`). When set:
    - The NGINX PEP proxy blocks `GET /auth/admin/*` on the main hostname with
      `403 Forbidden`, without any ingress-controller-specific annotations.
      Works with F5 NIC, standard nginx-ingress, OpenShift Routes, GKE Ingress,
      and others.
    - A separate `zeta-guard-admin` (master) + `zeta-guard-admin-minion` Ingress
      pair is created for the admin hostname, routing `/auth` directly to the
      authserver (no PEP token required).
        - The `/auth` path entry is removed from the main-hostname minion
          ingress;
          `/auth` reaches the PEP proxy via the existing `/` catch-all.
        - Keycloak's `--hostname-admin` flag is set automatically, keeping the
          Admin
          Console reachable exclusively via the admin hostname.
- New Terraform variable `audience` (default `""`). When non-empty, overrides
  the audience value embedded in access tokens by the audience mapper. Required
  when
  `keycloak_url` points to a separate admin hostname (so the audience stays tied
  to the main public hostname, not the admin hostname).
- `zeta-guard.pepproxy.nginxConf.poppValidity` to configure PoPP validity (fixed
  duration since iat or "quarter" mode — valid within current quarter)
- New value `provisioningProcessor.provisioningContainerCaSecretRef` to provide
  the CA certificate of the provisioning container registry as a Kubernetes
  Secret reference (mounted as a file). This avoids the kernel `ARG_MAX` limit
  that can be hit when passing large certificate chains as environment
  variables.
- New value `provisioningProcessor.provisioningContainer` to configure a custom
  registry mirror for the provisioning data image.
- New Terraform variable `audience_scope_name` (default `"zero:audience"`) to
  allow renaming the audience scope for environments that use a different scope
  naming convention. Set in the stage tfvars file:
  ```hcl
  audience_scope_name = "custom:audience"
  ```
- Dedicated ServiceAccount (`automountServiceAccountToken: false`) for
  authserver, PEP-Proxy, infinispan-external, exauthsim, test-driver, and
  tiger-proxy
- PodDisruptionBudget (disabled by default) for authserver,
  infinispan-external, exauthsim, test-driver, and tiger-proxy
- Configurable pod and container security contexts for all workloads; defaults
  include `seccompProfile: RuntimeDefault` and least-privilege container
  settings
- Configurable resources for authserver keycloak-build init container
  (`authserver.initContainer.resources`)
- Configurable probe thresholds for authserver liveness, readiness, and startup
  probes (`authserver.probes`)
- Configurable CloudNativePG database connection (`cloudnativeDbUrl`,
  `cloudnativeDbSecretName`, `cloudnativeDbSchema`)
- Configurable container security context for HSM-Sim and authserver HSM
- HSM-backed JWT token signing (`authserver.hsm.tokenSigning.enabled/keyId`) —
  access, ID, and refresh tokens signed with ES256 via HSM
- Terraform automation for HSM KeyProvider registration and software signing key
  cleanup. New tfvars to enable and configure HSM-backed token signing
- HSM status displayed in Helm NOTES output (hsm, hsm-tls, hsm-token-sign)
- Values schema (`values.schema.json`) extended with reusable `$defs` for
  `K8sServiceAccount`, `K8sPodDisruptionBudget`, and `K8sPodSecurityContext`
- Rename value of audience claim used in generateIdToken renamed from
  `zeta-guard.gematik.clientId` to `zeta-guard.gematik.IdTokenAudience`
- The Authserver (Keycloak) will export its logs to telemetry-gateway
- PDP (OPA) will export its decision logs and status updates to
  telemetry-gateway
- OPA simulation will export its decision logs and status updates to
  telemetry-gateway
- PEP (nginx) will export its logs to telemetry-gateway

#### changed:

- Authserver container resources moved from `authserver.resources` to
  `authserver.container.resources`
- Removed erroneous pod-level `resources` blocks in authserver and PEP-Proxy
  deployments (were rendered twice)
- Authserver KC_DB_URL in cloudnative mode is no longer hardcoded
- Infinispan-external: image and container security context are now configurable
  (previously hardcoded)
- Tiger-proxy nginx sidecar: image template aligned with popp-mocks (supports
  optional registry prefix), `imagePullPolicy` added
- opa image is now configurable in the same way as all the other images
- `main.tf` and `providers.tf` are now generated dynamically from templates
  and gitignored; the backend block and Kubernetes provider are selected based
  on `use_kubernetes`. When `use_kubernetes = false`, neither the
  `hashicorp/kubernetes` required provider nor the `provider "kubernetes"`
  block are emitted, so Terraform no longer requires the Kubernetes provider
  in local/non-cluster mode.
- Updated OpenTelemetry collector to version 0.151.0.
- Authserver (Keycloak) will export traces as intended
- PDP (OPA) will export traces regardless of policy source
- Ingress TLS hardened to ECDSA-only: cert-manager now issues ECDSA P-256
  certificates for the master ingress (`cert-manager.io/private-key-algorithm:
  ECDSA`, `private-key-size: 256`); RSA cipher suites removed from
  `ssl-ciphers` and `@SECLEVEL=3` enforced; `brainpoolP512r1` added to
  `ssl-ecdh-curve`
- New value `nginx-ingress.controller.pod.annotations.config-rev` to force a
  NIC pod restart on TLS/HSM config changes.

### Release 0.5.3

#### changed:

- authserver 0.5.1
- hsm_sim 0.5.0

### Release 0.5.2

#### added:

- authserver hsm support (TLS)
- upgrade cert-manager v1.20.1
- hsm_sim 0.5.0 disabled by default

### Release 0.5.1

#### added:

- pep hsm support (TLS)

### Release 0.5.0

#### added:

- Description and examples for more or less all values in
  `charts/zeta-guard/values.schema.json`
- Support configuration of OCSP stapling for ASL
- Option to enable or disable no-travel enforcement
- Option to deploy hsm proxy simulator for the test setup
- Provisioning Processor (run in sidecars) that downloads the provisioning
  container from gematik and derives the trust anchors from it.
- Terraform configuration now supports Kubernetes and local operating modes. Set
  `use_kubernetes = true` (default) to store state in a K8s Secret and fetch
  credentials from the cluster, or `use_kubernetes = false` to use a local state
  file and explicit credentials.
  See [ZETA Guard Quickstart – PDP konfigurieren](../../Anleitungen/ZETA_Guard_Quickstart.md#2-pdp-konfigurieren).
- Terraform variable validations for `keycloak_namespace`, `keycloak_url`,
  `pdp_scopes`, and a cross-variable check that credentials are provided in
  local mode

#### changed:

- Replaced OpenShift Route (`openshiftRoute`) with Ingress-based TLS support (
  `openshiftIngress`). The custom `openshift-route.yaml` template has been
  removed. Migrate from `openshiftRoute.enabled` / `openshiftRoute.host` /
  `openshiftRoute.issuer` to `openshiftIngress.enabled` +
  `openshiftIngress.certName`. This works with OpenShift's Ingress-to-Route
  controller and creates edge-terminated routes with TLS redirect.
- Testdriver ingress is now configurable: added `ingressEnabled`,
  `nginxIngressEnabled`, and `openshiftIngress` toggles to the testdriver
  subchart.
- Fixed configuration of telemetry-collector in `local-test/values.local.yaml`.
- Fixed erroneous TLS configuration for telemetry-gateway.
- You can now provide your own secrets to the zeta-guard sub chart instead of
  having them created.
- Make it optional for the chart to deploy secrets. It's now possible to
  reference existing secrets.
- `managePolicies.sh` now uses the Keycloak REST API (`curl`+`jq`) instead of
  `kubectl exec` + `kcadm.sh` into the Keycloak pod. No Java or Keycloak CLI
  installation required.
- `main.tf` is now generated dynamically from templates and gitignored; the
  backend block is selected based on `use_kubernetes`
- Keycloak admin username and password are resolved dynamically in both the
  Terraform provider and the policy management script
- `keycloak_password` and `keycloak_username` are now both marked `sensitive` in
  Terraform variables
- Keycloak provider version constraint updated to `>= 5.7.0`
- Updated OpenTelemetry collector to version 0.149.0.

### Release 0.4.1

#### added:

- Configurable authserver DB connection pool and HTTP thread pool
- Configurable resource limits and requests

#### changed:

- Updated OPA and NGINX-Ingress

#### removed:

- Removed log-collector component

### Release 0.4.0

#### added:

- Support for container image digests in compound `image` values
- Support for custom affinities, labels, pod annotations, and tolerances
- Support for individual security context per pod
- Support for OpenShift compatibility
- OPA simulation support
- Enabled telemetry delivery to gematik by default
- Configurable replica counts
- PEP sticky sessions for multi-replica deployments
- Support for external Infinispan

#### changed:

- `GENESIS_HASH` and `SMCB_HASHING_PEPPER` are now provided exclusively via
  Kubernetes Secrets and are no longer configured directly in the template file.
  These values must be present in the respective values.yaml during the initial
  deployment; for upgrades, existing Secrets are retained.
- For external database configurations, both the Keycloak database username and
  password are now expected as keys within the same Kubernetes Secret (
  `authserverDb.kcDbSecretName`).
- Charts have been tested with RedHats local OpenShift testplatform, CodeReady
  Containers (CRC) with standard pod security `restricted-v2`.
- It is now possible to set the `securityContext` on a per-pod basis via Helm
  values.
- Support for lists of image pull secrets and aligned values with Kubernetes
  syntax
- Database modes: only `cloudnative` (CloudNativePG) and `external` are
  supported. Use a single cluster-wide CloudNativePG operator.
- `opa.image` is now a string value instead of a compound value.
- Container images of CronJobs and nginx-prometheus-exporter are now
  configurable.
- Aligned values for image pull policies with Kubernetes syntax.
- Updated OpenTelemetry collector to version 0.147.0.
- Updated OpenPolicyAgent to version 1.14.0-static.
- **BREAKING CHANGE** Pod selectors now use Kubernetes' well-known labels
- Configurable smc-b keystore
- The chart's Ingresses have become optional, and you can configure their
  annotations.
- `nginx-ingress.enabled` has been replaced by `nginxIngressEnabled`.
- k8sattributes processor deactivated for log-collector and telemetry-gateway
- Restricted log collection to OPA pods and containers.

#### removed:

- Support for Bitnami PostgreSQL subchart removed.
- Support for Zalando Postgres Operator removed (`databaseMode: operator` no
  longer available).
- Unused value `global.registry`
- Labels containing container image tags

### Release 0.3.2

#### changed

- authserver-version

### Release 0.3.1

#### added

- websocket support

### Release 0.3.0

#### added:

- added support for postgres operator by documentation and makefile; also in
  local test setup
- telemetry-gateway can redact known kinds of secrets and personal information
  from logs, metrics, and traces
- Mergeable Ingress (F5 NIC: master + minions)

#### changed:

- Helm 4 required; Kubernetes >= 1.25;
- TLS defaults hardened (protocols, ciphers, HSTS)
- **BREAKING CHANGE**. We changed the ingress to F5 nginx-ingress NIC
  mergeable (master + minions).
  If you were using the original community ingress-nginx from the ZETA umbrella
  chart,
  delete the cluster-scoped IngressClass and ValidatingWebhookConfiguration, and
  remove the
  associated Deployment/Services/Lease in your target namespace before deploying
  the new
  version. For example (replace NAMESPACE and STAGE):
  ```shell
  # cluster-scoped admission webhook (community ingress-nginx)
  kubectl delete validatingwebhookconfiguration zeta-testenv-STAGE-ingress-nginx-admission --ignore-not-found

  # namespaced community controller objects
  kubectl -n NAMESPACE delete deploy zeta-testenv-STAGE-ingress-nginx-controller --ignore-not-found
  kubectl -n NAMESPACE delete svc zeta-testenv-STAGE-ingress-nginx-controller --ignore-not-found
  kubectl -n NAMESPACE delete svc zeta-testenv-STAGE-ingress-nginx-controller-admission --ignore-not-found
  kubectl -n NAMESPACE delete lease zeta-testenv-STAGE-ingress-nginx-leader --ignore-not-found

  # cluster-scoped IngressClass used by the old controller
  kubectl delete ingressclass nginx-STAGE --ignore-not-found
  ```
  If Helm fails with lease ownership/validation errors during upgrade:
    - Adopt the existing Lease into the release:
      ```shell
      kubectl -n NAMESPACE annotate lease zeta-testenv-STAGE-nginx-ingress-leader-election meta.helm.sh/release-name=zeta-testenv-STAGE --overwrite
      kubectl -n NAMESPACE annotate lease zeta-testenv-STAGE-nginx-ingress-leader-election meta.helm.sh/release-namespace=NAMESPACE --overwrite
      kubectl -n NAMESPACE label lease zeta-testenv-STAGE-nginx-ingress-leader-election app.kubernetes.io/managed-by=Helm --overwrite
      ```
    - Or delete the Lease and redeploy:
      ```shell
      kubectl -n NAMESPACE delete lease zeta-testenv-STAGE-nginx-ingress-leader-election
      ```

  Notes:
    - Stray community ingress-nginx ValidatingWebhookConfigurations from other
      environments can block Ingress
      applies cluster-wide if their admission Service has no endpoints. Remove
      unused
      `*-ingress-nginx-admission` webhooks (or temporarily set
      `failurePolicy: Ignore`) before deploying.
    - hardened security context for all components

### Release 0.2.8

#### changed:

- authserver and testdriver/exauthsim now have separate keystores/truststores.
  This chart now includes an RU based truststore for the authserver. For the
  testdriver/exauthsim you still need to bring your own cert&key.
- The values for the SMCB keystore have changed slightly. Now they are
  `smcb_keystore.keystore` and `smcb_keystore.password` with the same semantics.
  No changes are needed when using the makefile for the test setup.

### Release 0.2.7

#### added:

- ability to configure external DBs. See helm values authserverDb.* in
  zeta-guard subchart
- improvements for better compliance with some kubernetes security policies

#### changed:

- Makefile: streamlined stage/namespace/values selection; safer templating;
  clearer help
- Enforce admin-password of Authserver on initial deployment

### Release 0.2.6

#### added:

- config for ASL test mode
- improved Betriebsdatenlieferung

#### changed:

- updated versions of several subcomponents

### Release 0.2.5

#### changed:

- fix missing opa service account
- fix popp token config

### Release 0.2.4

#### added:

- missing file(s) for local deployments

#### changed:

- minor doc improvements
- updated individual components to their newes versions
- functional userdata and clientdata headers (beware clientdata schema is still
  subject to change)

### Release 0.2.0

#### added:

- bundling functionality of milestone 2 incl client registration, smcb token
  exchange
- public release of test setup

### Release 0.1.3

#### added:

- Helm chart for the prototype of ZETA Guard added
