# Komponentenübersicht

![Abbildung Zero Trust-Architektur der TI 2.0](../assets/images/TI20_Zero_Trust_Architektur.svg)

## ZETA-Guard-Komponenten

| Komponente                   | Basistechnologie                                                    |
|------------------------------|---------------------------------------------------------------------|
| **Policy Enforcement Point** |                                                                     |
| HTTP Proxy                   | [nginx](https://nginx.org/en/docs/)                                 |
| PEP Datenbank                | [Infinispan](https://infinispan.org/)                               |
| **Policy Decision Point**    |                                                                     |
| Authorization Server         | [Keycloak](https://www.keycloak.org/)                               |
| PDP Datenbank                | [PostgreSQL](https://www.postgresql.org/docs/current/)              |
| Policy Engine                | [Open Policy Agent](https://www.openpolicyagent.org/docs)           |
| **Andere Komponenten**       |                                                                     |
| Management Service           | [ArgoCD](https://argo-cd.readthedocs.io/en/stable/)                 |
| Notification Service         | TI-M Notification Service (kommt in Meilenstein 2)                  |
| Telemetriedaten Service      | [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/) |
