
# RELEASE NOTES

## Version: v2.0.6

This version implements the ZETA protocol for the ZETA client SDK.

It provides SDK bindings for kotlin (as original implementation), Java, C++, and C#

### Included Features:

#### General Protocol:

The implementation covers two main use cases, with a large overlap. The general functions are:

- Discovery of server parameters via .well-known files
- Software-based Client Attestation
- DPoP token generation
- Client Registration
- Access Token handling
- ASL protocol implementation (messages 1-4 as well as payload encryption/decryption)
- Web Sockets

Specifically for practitioner-side implementations ("Stufe 1"), the following features are implemented:

- SM(C)-B Token generation and use
- Support for stationary clients (see below)

For insurant-side implementations ("Stufe 2"), the following features are implemented as preview:

- Dynamic Client Registration (DCR) using e-Mail OTP identity verification
- OIDC-based login using a SekIDP
- Support for mobile clients (see below)

#### Clients:

This section has the available client implementations, all based on the SDK:

- kotlin multiplatform based SDK implementation

The other clients use this SDK and show how to integrate the SDK into the various, supported
runtime environments.

##### Test clients
- testdriver client as container image to use as a proxy for a resource server in test setups, using the JDK-based runtime.
- nativedriver client as container image to use as a proxy for a resource server in test setups, using the native build runtime.
- kotlin-based demo client to manually test against the test Fachdienst (resource server)

##### Stationary clients:
- Java-client example for how to integrate and use the SDK in a Java application
- C++ client build
- C# client build

##### Mobile clients:
- Demo client app for Android
- Demo client app for iOS

### Known issues:

- The SDK does not fully handle paths parts in the AS well-known URL. The AS well-known is defined
  as on the root path, so this is WONTFIX.

### Changes in 2.0.6 (from 2.0.5)

#### Breaking changes

- N/A

#### New

- N/A

#### Bug Fixes

- Fixed missing ASL session recovery for PEP errors `403` with error code 9 ("unknown CID"), 3 or 8 now clears the session and triggers one new handshake instead of aborting.
  The original error code is kept if recovery fails.
- Mobile client flow (OIDC): the Pushed Authorization Request (PAR) now includes the `client_id`.

### Behavioural Changes

- `logout()` now also clears the ASL session.

### Changes in 2.0.5 (from 2.0.4)

#### Breaking changes

- N/A

#### New

- N/A

#### Bug Fixes

- Fixed missing Gradle task dependencies between `commonizeCInterop` and Linux/MinGW metadata tasks, causing Windows CI builds to fail with implicit dependency errors.

### Behavioural Changes

- N/A

### Changes in 2.0.4 (from 2.0.3)

#### Breaking changes

- N/A

#### New

- N/A

#### Bug Fixes

- Guards that publish no usable `api_versions_supported` (missing,
  empty or all versions retired, e.g. ZETA Guard 1.2) are now treated as 1.x. In 2.0.3 they got the 2.x behavior,
  so software registration sent fields introduced in 2.0 and Apple clients without App Attest
  failed with "Invalid combination of »SOFTWARE« and »APPLE«".

### Behavioural Changes

- Without a usable `api_versions_supported`, the SDK now applies the 1.x adaptations
  instead of the standard behavior. 1.3.x guards (`[1.0.0]`) and 2.x guards
  (`[1.0.0, 2.0.0]`) are unaffected.

### Changes in 2.0.3 (from 2.0.2)

#### Breaking changes

- Removed the unused `registrationCallback` from `BuildConfig`. Integrations that set it
  must remove that argument.

#### New

- Compatibility with ZETA Guard 1.3.x and 2.0.x: the SDK reads `api_versions_supported`
  from the authorization server's well-known and adapts to 1.3.x guards: software client
  registration without the fields introduced in 2.0, and no Apple `platform_product_id` in
  software postures. 2.0.x guards, and guards that publish no API versions, keep the
  standard behavior.
- iOS: TLS validation: adds a pre-flight check to obtain the OCSP stapled responses.

#### Bug Fixes

- Fixed OCSP and CRL time checks on native platforms.
- GS_A_4367 - Use secure random for the code verifier and the code challenge

### Behavioural Changes

- N/A


## Changes in 2.0.2 (from 2.0.1)

Hotfix release based on 2.0.1.

### Bug Fixes

- Authorization server configuration is no longer lost when the well-known
  documents are served with `Cache-Control: max-age=0`. The SDK now revalidates
  the cached configuration instead of discarding it. The workaround of setting
  `max-age > 0` on the server side is no longer required.

### Breaking Changes

- N/A

### New Features

- N/A

### Behavioural Changes

- N/A

## Changes in 2.0.1 (from 2.0.0)

### Security

Updated third-party dependencies to fix vulnerabilities reported by Dependency-Track:

- Bouncy Castle (`bcprov-jdk18on`, `bcpkix-jdk18on`): 1.85.2 / 1.85 -> 1.86
    - CVE-2026-17508, CVE-2026-18036, CVE-2026-18040, CVE-2026-71888,
      CVE-2026-71889, CVE-2026-71891, CVE-2026-71892, CVE-2026-97873
- Netty (`netty-codec-http`, `netty-codec-http2`): 4.2.17.Final -> 4.2.19
    - CVE-2026-89044, CVE-2026-93488, CVE-2026-93491, CVE-2026-93492,
      CVE-2026-93558, CVE-2026-93562, CVE-2026-93565, CVE-2026-93566,
      CVE-2026-93567, CVE-2026-93568, CVE-2026-93573, CVE-2026-93574,
      CVE-2026-93579

### Breaking Changes

- N/A

### New Features

- N/A

### Behavioural Changes

- N/A

### Bug Fixes

- N/A

## Changes in 2.0.0 (from 1.3.2)

### Breaking Changes

- `OidcConfig`: `requestUri` has been replaced by two explicit fields. Previously both redirect URIs were derived from `requestUri` (`{requestUri}/app` and `{requestUri}/oidc`):
    - `redirectUri`: final app redirect where Keycloak returns the authorization code.
    - `oidcRedirectUri`: intermediate redirect where the SekIDP returns its `code` and `state`, which are relayed to the Keycloak broker.

  Both must be registered as redirect URIs during client registration.
- `OidcConfig`: the optional `authenticationCallback` has been replaced by the required `authorizationLauncher: AuthorizationLauncher`. The application implements `open(request)`, which shows the login in the system browser, relays the SekIDP `code`/`state` to the broker endpoint in the same browser, and returns the final redirect URL.
  The SDK handles PKCE, `state`, PAR, validation and the token exchange. See the README section "AuthorizationLauncher".
- `ZetaSdkClient.changeEmail` only starts the e-mail change and returns `ChangeEmailResponse.Pending` or `ChangeEmailResponse.Verified`; call `verifyEmailChange(code)` to complete it. Errors are thrown as `ClientManagementException` subclasses.
- TestDriver: `GET /oidc/change-email` has been replaced by `POST /testdriver-api/client-management/identity/email`.

### New Features

- Hardware-based device attestation for Android and iOS
- Push notifications, including key persistence, notification history
- Authentication at token exchange according to A_25338-01
- C# SDK on NuGet: the C# SDK is now packaged for release via NuGet
- Android TestDriver: test driver app for running the automated SDK tests on Android devices
- Client management API: the SDK can list the clients registered for the current identity, de-register a client, change the identity e-mail, and show the registration access log (provided by the server).
- Hardware attestation tests on real devices: the Android and iOS demo apps can now be tested automatically on real devices via BrowserStack
- TestDriver: new endpoint `hellozeta/ios` and `hellozeta/android` to run the Hello ZETA flow on a real Android/iOS device
- TestDriver: client-management endpoints `POST /testdriver-api/client-management/identity/email`, `.../identity/email/resend`, `.../identity/email/verify`, `GET .../clients` and `DELETE .../clients/{client_id}`

### Behavioural Changes

- ANFTI2-997: The SDK now calls the authorization endpoint after the PAR request, fixing an incompatibility in the OIDC flow between ZETA versions. This requires changes to `OidcConfig` (see Breaking Changes).
- When the ASL session has expired on the server, the SDK now automatically re-does the ASL handshake
- Discovery, client registration and authentication are now serialized in the Java client, so parallel requests (e.g. parallel WebSocket connections) no longer trigger them concurrently
- Server certificate validation falls back to the Common Name (CN) when the certificate has no Subject Alternative Name

### Bug Fixes

- ANFTI2-708: An expired refresh token no longer results in a 400 error
- ANFTI2-753: ASL responses now return the inner decrypted response status and headers instead of the outer ASL ones
- ANFTI2-928: Build: `jvmCommonTest` dependencies are now guarded
- TestDriver adjustments for the OIDC no-cookie flow


## Changes in 1.3.2 (from 1.3.0)

### New Features

- Updated Gradle dependencies to the latest compatible versions.
- Refactored time handling across the SDK by introducing the ZetaClock interface,
  allowing a custom clock implementation to be injected.

### Behavioural Changes

- N/A

### Bug Fixes

- Added support for extracting stapled OCSP responses on Android API levels below 37.
- ANFTI2-915 / ANFTI2-781: Updated ktor-client-fork with upstream changes to resolve reported WebSocket issues.
- ANFTI2-889: Updated the RevocationChecker HTTP client to use the configured SDK HTTP settings, including proxy and timeout configuration.
- Fixed OCSP stapled-response handling to comply with A_27379-01.

## Changes in 1.3.0 (from 1.2.5)

### New Features

Please note that mobile device features ("Stufe 2") are preview only.

- Support for mobile clients (using software attestation)
- iOS Mobile demo app (preview)
- Android Mobile demo app (preview)
- SDK API extended to include DCR and OIDC callbacks for gathering user e-Mail and One-Time-Password (OTP).
- SDK API extension to register / unregister for notifications
- Sample (test-client-) integration with the gematik SekIDP reference implementation, with
  OIDC handling and buttons to register / unregister for notifications.

Other new features are:

- new version API to return the (hardcoded at build time) client SDK version.

### Behavioural Changes

- ZETAP-1387: Revocation caching configurable

### Bug Fixes

- ANFTI2-781: C# WebSocket WsSession.ReceiveNext doesn't always return the complete message (frame fragmentation fix)
- ANFTI2-788/-782: regression regarding using handling multiple Guards
- ANFTI2-810: Implementierung zeta-sdk Client C# .NET 10 - TLSServerVerification
- ANFTI2-813: extend .gitignore for Windows / Visual Studio builds
- ANFTI2-843: Fix retry on ASL session expiration
- ANFTI2-859: Bug bei ASL Retry-Logik sowie ggf. zeta-guard
- ANFTI2-875: asl_cert_cache Value für zeta storage zu groß
- OCSP Signature issuer check
- Netty security update
- Avoid hardcoding TLS 1.2 in insecure debug SSLContext
- ZETA Client skips optional refresh attempt after 401/403 from PEP HTTP proxy
- No service discovery after 404, ETags/If-None-Match caching
- CVE-2026-8484: Jansi vulnerability fix
- Bump BouncyCastle to v1.85 to fix vulnerabilities found in v1.84

## Changes in 1.2.5 (from 1.2.4)

- Fix regression in JVM revocation checker
- Use correct timestamp for OCSP cache time

## Changes in 1.2.4 (from 1.2.3)

- RSA key length adapted to requirements for gematik PKI CA infrastructure

## Changes in 1.2.3 (from 1.2.2)

### New Features

- Demo App has more options regarding TLS (burger menu with
  option to enable/disable TLS validation, upload CA files)
  Also now has buttons for explicit discovery, registration, and authentication

### Behavioral Changes

- Adaption of the validation of the TLS certificate chain to achieve compatibility
  with the gematik PKI CA infrastructure. This mainly affects the ASL functionality.

### Bug Fixes

- Caching for TLS/ASL revocation and trust data (OCSP, CRL, ASL certificates)
- ASL error handling (parsing json vs. cbor)
- TLS validation error in C++/C# on windows - using the Windows Certificate store now
- Certificate chain revocation now properly verified for both ASL and TLS
- ANFTI2-636: Fixed Linux shared-lib compilation error (missing -fPIC flag)
- ANFTI2-678: Expose Status to Java client
- ANFTI2-740: Fixed malformed URL in service discovery error logs
- ANFTI2-744: discover/register/authenticate propagate CapabilityResult.Error as a failed Result
- ANFTI2-753: C++ Correct Headers count

## Changes in 1.2.2 (from 1.2.0)

### New Features

- Log verbosity in load driver is configurable

### Bug Fixes

- ANFTI-697: websocket fragmentation
- ANFTI-651: C# Exception Handling
- ANFTI2-735: rework Access Token storage to reduce key size (was too big) and include ability for scope-specific access tokens for the same resource (DiPag)
- Removal of SMCB Subject Token provider as it was a test tool and never meant for production
- Netty CVE finding in testdriver

## Changes in 1.2.0 (from 1.0.2)

### New Features

- More API Methods in C/C# API (discover, authenticate, ...)
- Proxy configuration for C/C# clients
- Security Configuration in C/C# clients (e.g. add your own CAs)
- Cookie management in HTTP client to support load balancing
- clearRegistration() API method added

### Specification Updates

- Schema-Updates for AS-well-known, lenient Json validation
- Use of registration_endpoint,
- Removal of Client Self Assessment (urn:telematik:client-self-assessment attribute)

### Bug fixes

- Use of correct audience in Subject Token and token request parameter
- Findings in OCSP validation (JVM und Native SDKs)
- TLS optimizations and fixes
- Always send Software Statements as those are the ones we support currently
- Remove leftover hardcoded profession OID check
- OCSP validation fixes:
    - issuer cert passed explicitly to OCSP_basic_verify for signature validation
    - nextUpdate handling fixed
- Proxy password sent as literal string instead of pointer representation
- Fixed WebSocket communication in Java client
  Fixed PoPP header duplication in testdriver
- Fixed status always returning REGISTERED_NO_VALID_TOKENS
- Persist `zeta_route` cookie via SdkStorage for sticky session

## Changes in 1.0.2 (from 1.0.1)

- Hotfix: The C# client compilation error has been solved. Missing files have added.

## Changes in 1.0.1 (from 1.0.0)

### New Features
- Custom SMC-B Connector: inject your own SMC-B connector implementation via `AuthConfig`.
- Custom Storage: replace the default platform storage with a custom `SdkStorage` implementation
- Custom Log Provider: redirect SDK log output via `ZetaLogger`, configurable log level (`DEBUG`, `INFO`, `WARN`, `ERROR`, `NONE`), default is `ERROR`

### Bug Fixes
- Step-up authentication: client registration storage is now cleared during step-up, forcing re-registration with a new `client_id` when a 401 is received
- EC curve validation: TLS handshake now enforces allowed EC curves at the OpenSSL level
- Proxy password: not sent as a pointer representation, instead of the actual string value

### Improvements
- Logging now uses a unified implementation across all platforms. SLF4J dependency removed from JVM. Default output now uses `println`
- Ktor HTTP client logging now delegates to the SDK log system

## Changes in 1.0.0 (from 0.5.1)

- C# client
- Bugfixes
- CVE fixes
- Code Quality activities

## Changes from 0.5.0

- Update versions of kotlin, gradle, netty-codec, and others

## Changes from 0.4.2

- Fix TLS Cipher suite validation for TLS 1.2. OkHttp returns IANA names but validator was comparing against OpenSSL names,
- causing all TLS 1.2 connections to fail compliance check.
- Update aus gemspec_ZETA RC 26_1
    - key thumbprints in SubjectToken

## Changes from 0.4.1

- Refactored C++ client: Moved C++ API types and bindings from the example client into the SDK itself The SDK now ships a single header file (`libzeta_sdk_api.h` / `zeta_sdk_api.h`) with full HTTP CRUD and WebSocket STOMP support
- Added standalone C++ native client (`zeta-nativeclient-cpp`) with Makefile for cross-platform builds (macOS, Linux, Windows) without requiring Gradle
- Added all HTTP methods to JVM `HttpClientExtension`: `putAsync`, `patchAsync`, `deleteAsync`, `headAsync`, `optionsAsync`

## Changes from 0.4.0

- C++ API now has length restrictions in the strings
- removed dynamic linking in C++ client
- disable TLS validation configurable in C++ client

## Changes from 0.3.1

- Hinzufügen fehlender dependency Check results zu den reporting Artefakten
- Triggern der Testsuite bei jedem Commit auf einem Merge-Request
- Build-Prozess für den C++ Client in einem Docker Container ermöglicht
- Härtung des TLS durch Einschränkung der cipher suites
- Erweiterung des Testdriver durch ein "load" Interface, um mehrere Client-Instanzen parallel steuern zu können für den Lasttest
    - Dazu die Möglichkeit, das SMC-B Zertifikat als base64-encoded String direkt als Konfiguration zu nutzen
- Fixes bei Headern
    - Forwarded-Header werden im inneren ASL Request herausgefiltert
- Anpassungen am Attestation service, Vorbereitungen für Windows
    - hier werden aktuell noch Spezifikationsänderungen erwartet
- Erweiterungen einiger Logs um Zeitmessungen
- Fix websocket communication in Java client

## Changes from 0.3.0

- Fixed demo client to enable functionalities (add, edit, delete) when the attestation state is unknown

## Changes from 0.2.12

- Attestation service for Linux (TPM based)
- Increase code coverage for modules Crypto and ASL
- Fixes included:
    - Dpop token htu value for request with ASL
    - Proper configuration handling, when PDP and PEP are on different hosts
    - Improvement for reading registration number from SM-B certificate
    - Handling of X-Forwarded headers when using ASL

## Changes from 0.2.11

- Fix websockets on C++ client

- Work on the Client Attestation Service
    - Integrate tpm2-tss library bindings to access TPM (only linux)
    - Implement TPM commands

## Changes from 0.2.10 (internal)

- Add missing copyright header

## Changes from 0.2.9

- Update of release Notes

## Changes from 0.2.8

- Rollback of the netty version due to intermittent errors in the test framework

## Changes from 0.2.7

- Filtering of the included ktor-client-curl library

## Changes from 0.2.6

- Significant adjustments to the C++ client through integration of ktor-client-curl for updated OpenSSL version with support for post-quantum cryptography
- Implemented cryptographic functions for desktop clients using OpenSSL
- ASL debug mode implemented, including new "ASL_PROD" configuration for implemented clients
- Improvements for ASL error handling
- Version updates

## Changes from 0.2.5

- Send clientId and clientIdIssuedAt within client assessment data for token exchange (websockets)

## Changes from 0.2.4

- Correct the field platform name

## Changes from 0.2.3

- fix for asl debug header
- fix for web sockets
- fix for sending client-/user-data

## Changes from 0.2.2

- fix for Host header

## Changes from 0.2.1

- minor bug fixes
- Version updates

