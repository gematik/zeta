# Komponentenübersicht

[//]: # (![Abbildung Zero Trust-Architektur der TI 2.0]&#40;../assets/images/TI20_Zero_Trust_Architektur.svg&#41;)

## ZETA-Guard-Komponenten

| Komponente                   | Basistechnologie                                                     |
|------------------------------|----------------------------------------------------------------------|
| **Policy Enforcement Point** |                                                                      |
| HTTP Proxy                   | [nginx](https://nginx.org/en/docs/)                                  |
| **Policy Decision Point**    |                                                                      |
| Authorization Server         | [Keycloak](https://www.keycloak.org/)                                |
| PDP Datenbank                | [PostgreSQL](https://www.postgresql.org/docs/current/)               |
| PDP Cache                    | [Infinispan](https://infinispan.org/)                                |
| Policy Engine                | [Open Policy Agent](https://www.openpolicyagent.org/docs)            |
| **Andere Komponenten**       |                                                                      |
| Service Mesh                 | TODO                                                                 |
| Notification Service         | TI-M Notification Service (kommt in Meilenstein 2)                   |
| Telemetriedaten Service      | [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)  |
| Ingresscontroller            | [F5 nginx-ingress](https://docs.nginx.com/nginx-ingress-controller/) |

Hinweise zur Zustandshaltung:

* **Infinispan ist der verteilte Cache des Authorization Servers** und damit dem
  PDP zugeordnet. Der PEP greift nicht auf Infinispan zu.
* Der PEP hält keinen instanzübergreifend geteilten Zustand. Einzige Ausnahme
  ist der ASL-Session-Cache, der pro Pod im nginx Shared Memory liegt und
  deshalb bei horizontaler Skalierung Sticky Sessions erfordert – siehe
  [Deployment-Szenarien](Deploymentszenarien.md#zeta-guard-und-datenbank-skalierung).
  Fachdienste ohne ASL-Nutzung benötigen keine Sticky Sessions.
