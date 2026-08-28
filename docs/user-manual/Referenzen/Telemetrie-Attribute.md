# Telemetrie-Attribute von ZETA-Guard

Neben den Attributen aus
den [OpenTelemetry Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/)
verwendet ZETA-Guard eigene Attribute. Es folgt eine Aufstellung dieser
Attribute.

## Angriffserkennung

Diese Attribute treten nur bei Logs, Metriken und Spans der Angriffserkennung
auf. Sie
referenzieren [Common Attack Pattern Enumerations and Classifications (CAPEC)](https://capec.mitre.org/).

| Key                         | Value Type | Description         | Example Values                                                          |
|-----------------------------|------------|---------------------|-------------------------------------------------------------------------|
| `attackDetection.capecId`   | int        | Attack Pattern ID   | `115`                                                                   |
| `attackDetection.capecName` | string     | Attack Pattern Name | `"Authentication Bypass"`                                               |
| `attackDetection.clientIP`  | string     |                     | `127.0.0.1`                                                             |
| `attackDetection.detail`    | string     |                     | `Expected audience not available in the token`                          |
| `attackDetection.origin`    | string     |                     | `org.keycloak.TokenVerifier$AudienceCheck.test(TokenVerifier.java:163)` |

## Policy-Entscheidungen

Diese Attribute treten bei Logs und Spans im Zusammenhang mit
Policy-Entscheidungen auf – u.a. bei OPA Decision Logs.

| Key              | Value Type | Description | Example Values |
|------------------|------------|-------------|----------------|
| `zeta.client.id` | string     |             |                |
| `zeta.client.ip` | string     |             |                |

## Test-Monitoring-Service

Folgende Attribute werden vom Test-Monitoring-Service gesetzt, um Telemetrie von
den Exportern für Diensthersteller, TI-SIM und TI-SIEM in ZETA-Guard
unterscheiden zu können. Da der Test-Monitoring-Service nicht für den
Produktiveinsatz gedacht ist, sollten diese Attribute nicht in einem
Produktivsystem erscheinen.

| Key                 | Value Type | Description                                        | Example Values                            |
|---------------------|------------|----------------------------------------------------|-------------------------------------------|
| `gematik.zeta.kind` | string     | Markiert Telemetrie abhängig von Exporter/Receiver | `dienst_hersteller`, `sim`, `siem` |
