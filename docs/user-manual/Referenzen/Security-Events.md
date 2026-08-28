# Übersicht über alle Security-Events von ZETA-Guard

In ZETA-Guard sind Security-Events als strukturierte Logs umgesetzt.

## Event authn_client_deleted:clientId

**Beschreibung:** Eine Client-Registrierung wurde von ZETA-Guard gelöscht, z. B. die am längsten
ungenutzte Registrierung eines Nutzers, weil die maximale Anzahl an Client-Registrierungen pro
Nutzer (`SMCB_USER_MAX_CLIENTS`) durch eine neue Registrierung überschritten wurde (A_25748-02)

**Level:** INFO

**Endpoints:** POST
/realms/zeta-guard/protocol/openid-connect/token

**Properties:**

| Key                  | Requirement Level | Value Type | Beschreibung                            | Example Values         |
|----------------------|-------------------|------------|------------------------------------------|-------------------------|
| `auth.client_id`     | mandatory         | string     | Client id des gelöschten Clients          |                         |
| `zeta-client.reason` | mandatory         | string     | Grund, warum der Client gelöscht wurde    | `max_clients_exceeded`  |
| `event_type`         | mandatory         | string     | Security event type                       | `authn_client_deleted`  |

## Event authn_client_registered:clientId

**Beschreibung:** Client-Registrierung am Authorization-Server

**Level:** INFO

**Endpoints:** POST
/realms/zeta-guard/clients-registrations/openid-connect

**Properties:**

| Key              | Requirement Level | Value Type | Beschreibung        | Example Values            |
|------------------|-------------------|------------|---------------------|---------------------------|
| `auth.client_id` | mandatory         | string     | Client id           |                           |
| `event_type`     | mandatory         | string     | Security event type | `authn_client_registered` |

## Event authn_client_registration_fail:clientId

**Beschreibung:** Fehlgeschlagene oder abgelaufene Client-Registrierung am
Authorization-Server

**Level:** INFO

**Endpoints:** POST
/realms/zeta-guard/clients-registrations/openid-connect (Gründe
`integrity_provider_unavailable`, `attestation_failed`); POST
/realms/zeta-guard/protocol/openid-connect/token bzw.
/realms/zeta-guard/broker/zeta-sekidp-oidc/endpoint (Grund
`too_many_clients_registered`, wenn ein Client neu mit einem Nutzer verknüpft
wird — Endpunkt je nach Anmeldeweg); für den Grund `registration_expired`
erzeugt ein interner Scheduler das Event (kein Endpoint)

**Properties:**

| Key                  | Requirement Level | Value Type | Beschreibung        | Example Values                                                                                                |
|----------------------|-------------------|------------|---------------------|---------------------------------------------------------------------------------------------------------------|
| `auth.client_id`     | mandatory         | string     | Client id           |                                                                                                               |
| `event_type`         | mandatory         | string     | Security event type | `authn_client_registration_fail`                                                                              |
| `zeta-client.reason` | mandatory         | string     | Grund des Fehlers   | `integrity_provider_unavailable`, `attestation_failed`, `registration_expired`, `too_many_clients_registered` |

## Event authn_client_deleted:clientId

**Beschreibung:** Löschung einer Client-Registrierung durch den ZETA-Guard,
z.B. die automatische Verdrängung der am längsten inaktiven Registrierung,
wenn die maximale Anzahl von Clients pro Nutzer überschritten wird (A_25748)

**Level:** INFO

**Endpoints:** Die Verdrängung läuft beim Verknüpfen eines Clients mit einem
Nutzer, nicht am Registrierungs-Endpunkt. Je nach Anmeldeweg also entweder POST
/realms/zeta-guard/protocol/openid-connect/token (SMC-B-Token-Exchange) oder
/realms/zeta-guard/broker/zeta-sekidp-oidc/endpoint (Broker-Callback im
mobilen Client-Flow über den SekIDP)

**Properties:**

| Key                  | Requirement Level | Value Type | Beschreibung           | Example Values         |
|----------------------|-------------------|------------|------------------------|------------------------|
| `auth.client_id`     | mandatory         | string     | Gelöschter Client      |                        |
| `event_type`         | mandatory         | string     | Security event type    | `authn_client_deleted` |
| `zeta-client.reason` | mandatory         | string     | Grund der Löschung     | `max_clients_exceeded` |

## Event authn_authorization_code_invalid

**Beschreibung:** Ungültiger Authorization Code im Anmeldefluss über einen
sektoralen IDP (mobiler Client-Flow)

**Level:** INFO

**Endpoints:** POST
/realms/zeta-guard/protocol/openid-connect/token (Grant `authorization_code`)

**Properties:**

| Key                  | Requirement Level | Value Type | Beschreibung                  | Example Values                     |
|----------------------|-------------------|------------|-------------------------------|------------------------------------|
| `event_type`         | mandatory         | string     | Security event type           | `authn_authorization_code_invalid` |
| `zeta-client.reason` | mandatory         | string     | Fehlerbeschreibung (Freitext) |                                    |

## Event authn_email_change:clientId

**Beschreibung:** Die an eine Identität gebundene E-Mail-Adresse wurde ersetzt

**Level:** INFO

**Endpoints:** POST
/realms/zeta-guard/zeta/identity/email

**Properties:**

| Key              | Requirement Level | Value Type | Beschreibung                               | Example Values                         |
|------------------|-------------------|------------|--------------------------------------------|----------------------------------------|
| `auth.client_id` | mandatory         | string     | Client id, der die Änderung ausgeführt hat | `13c32c3e-57e6-42c2-82f1-d8346fcc7ed1` |
| `event_type`     | mandatory         | string     | Security event type                        | `authn_email_change`                   |

## Event authn_token_created:clientId

**Beschreibung:** Token-Exchange am Authorization-Server

**Level:** INFO

**Endpoints:** POST
/realms/zeta-guard/protocol/openid-connect/token

**Properties:**

| Key                                  | Requirement Level       | Value Type | Beschreibung                            | Example Values                |
|--------------------------------------|-------------------------|------------|-----------------------------------------|-------------------------------|
| `auth.client_id`                     | mandatory               | string     | Client id                               |                               |
| `client_registration.client.os.name` | conditionally mandatory | string     | Client operating system name            | `android`                     |
| `client_registration.datetime`       | mandatory               | int        | Timestamp of client registration        | `1784561340`                  |
| `client_registration.result`         | mandatory               | string     | Result of attempted client registration | `PENDING`, `VALID`, `INVALID` |
| `event_type`                         | mandatory               | string     | Security event type                     | `authn_token_created`         |

## Event "Possible attack detected"

**Beschreibung:** Angriffsversuch erkannt

**Level:** WARN

**Endpoints:** unterschiedlich

**Properties:**

| Key                         |           | Value Type | Beschreibung        | Example Values                                                          |
|-----------------------------|-----------|------------|---------------------|-------------------------------------------------------------------------|
| `attackDetection.capecId`   | mandatory | int        | Attack Pattern ID   | `115`                                                                   |
| `attackDetection.capecName` | mandatory | string     | Attack Pattern Name | `"Authentication Bypass"`                                               |
| `attackDetection.clientIP`  | mandatory | string     |                     | `127.0.0.1`                                                             |
| `attackDetection.detail`    | mandatory | string     |                     | `Expected audience not available in the token`                          |
| `attackDetection.origin`    | optional  | string     |                     | `org.keycloak.TokenVerifier$AudienceCheck.test(TokenVerifier.java:163)` |
