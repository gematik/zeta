# Release Notes ZETA Guard Komponenten

## Inhaltsverzeichnis

- [Keycloak Authserver (ZETA PDP)](#keycloak-authserver-zeta-pdp)
- [PEP Proxy (ZETA PEP)](#pep-proxy-zeta-pep)
- [Provisioning Processor](#provisioning-processor)
- [ZETA Guard Helm Charts](#zeta-guard-helm-charts)

## Keycloak Authserver (ZETA PDP)

### Release 1.2.5

#### changed:

- OpenJDK of the hardened Keycloak image updated to 21.0.13.1 (`java-21-openjdk-headless-21.0.13.1.2-1.2.el9`)
  because of CVE-2026-114938 ("java4shell", heap out-of-bounds write in the AVX-512 Base64 decoder of HotSpot on x86-64) and other CVEs

### Release 1.2.4

#### changed:
- **Hardened Dynamic Client Registration against privilege escalation (CVE-2026-15572).**
  Keycloak's native client-registration endpoints (`default`, `install`,
  `saml2-entity-descriptor`) are disabled, and the RFC 7592 update/delete operations
  (`PUT`/`DELETE`) are removed from the OIDC registration — only `POST`/`GET` on
  `/clients-registrations/openid-connect` remain. This closes the mapper type-swap on
  update (an allowed mapper type could be swapped to a disallowed one such as
  `oidc-hardcoded-role-mapper` via the update endpoint, injecting privileged roles) and
  the broad `ClientRepresentation` registration surface it relied on.

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

### Release 1.2.3

#### fixed:

- ASL (hardening, CWE-444, HTTP request smuggling): `/CertData.*` and non-`POST` requests to
  `/ASL` discard an unread request body instead of leaving it on the connection for nginx to
  parse as the next request. The PEP's own connections to nginx are not pooled on this branch,
  so a client cannot reach another client's requests through the ASL relay. The change matters
  when a front proxy or load balancer reuses its connections to the PEP for several clients.
- OpenSSL prefers the default provider for software keys; with a newer OpenSSL in the base image
  the ASL signer key could end up in the HSM provider and the PEP failed to start with
  `asl init: failed to sign ASL keys`

#### changed:

- Bumps:
  - rust 1.100.0
  - nginx 1.31.9 (NOTE: image ref changes from nginxinc/nginx-unprivileged to
    nginx/nginx-unprivileged due to an upstream naming scheme change)
  - nginx-ingress 5.8.0
  - headers-more-nginx-module v0.42

### Release 1.2.2

#### fixed:

- ASL: the inner request's `Host` header is no longer forwarded on the loopback hop; the outer
  request's `Host` is used instead. The loopback hop targets `127.0.0.1`, never follows
  redirects and never uses a proxy (with thanks to Machine Spirits UG)
- ASL: inner request targets are only accepted in origin-form (`/path?query`) and always stay on
  the PEP's own listener; a path like `/http://host/…` no longer redirects the inner request to
  that host (with thanks to Machine Spirits UG)

### Release 1.2.1

#### fixed:

- harden ASL subrequest target URL handling
  (with thanks to Machine Spirits UG)

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

## Provisioning Processor

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

### Release 1.2.7

#### fixed:

- bumped pep and nginx-ingress controller image to `1.2.3` to include ASL
  hardening against HTTP request smuggling and updated nginx/nginx-ingress base
  images (NIC 5.8.0, matching the nginx-ingress chart 2.9.0).
- bumped authserver version to `1.2.5` to include the OpenJDK 21.0.13.1 security
  update (CVE-2026-114938).
- bumped keychain-generator image to `1.3.0-1`, rebuilt on the current JDK base
  image because of CVE-2026-114938.

#### changed:

- updates nginx-ingress chart to 2.9.0 (NIC 5.8.0)

### Release 1.2.6

#### fixed:

- bumped pep version to `1.2.2` to include important security hotfix.

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
