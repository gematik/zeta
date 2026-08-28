# Release Notes ZETA Guard Komponenten

## Keycloak Authserver (ZETA PDP)

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

### Release 1.3.0

#### fixed
- DPoP proofs whose embedded `jwk` omits the optional `alg`/`kid`/`use` members are now accepted;
  previously a missing `jwk` `alg` was rejected with HTTP 401. An explicit `jwk` `alg` other than
  `ES256` is still rejected.
- ASL subrequest now sets `Forwarded.for`; the client ip is determined by the same
  mechanism as elsewhere (forwarded → x-forwarded-for → x-real-ip → socket addr)

#### added
- Session revocation (ZETAP-1010): with `pep_revocation_url` set, the PEP reports the
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
- Implement otel traces,logs,metrics (ZETAP-907).
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

### Release 1.2.0

#### added

- zeta-cause: proxy handling

#### changed

- Invalid access token headers (unparseable JWT) now return HTTP 401 instead of HTTP 500 (ZETAP-1003)
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
