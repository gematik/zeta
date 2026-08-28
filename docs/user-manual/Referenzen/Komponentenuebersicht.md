# Komponentenübersicht

[//]: # (![Abbildung Zero Trust-Architektur der TI 2.0]&#40;../assets/images/TI20_Zero_Trust_Architektur.svg&#41;)

## ZETA-Guard-Komponenten

| Komponente                   | Basistechnologie                                                     |
|------------------------------|----------------------------------------------------------------------|
| **Policy Enforcement Point** |                                                                      |
| HTTP Proxy                   | [nginx](https://nginx.org/en/docs/)                                  |
| PEP Datenbank                | [Infinispan](https://infinispan.org/)                                |
| **Policy Decision Point**    |                                                                      |
| Authorization Server         | [Keycloak](https://www.keycloak.org/)                                |
| PDP Datenbank                | [PostgreSQL](https://www.postgresql.org/docs/current/)               |
| Policy Engine                | [Open Policy Agent](https://www.openpolicyagent.org/docs)            |
| **Andere Komponenten**       |                                                                      |
| Service Mesh                 | TODO                                                                 |
| Notification Service         | Push-Benachrichtigungs-Fassade zwischen Fachdienst, ZETA Client und gematik Push Gateway — Vorschau, standardmäßig deaktiviert ([Anleitung](../Anleitungen/Wie_der_Notification_Service_funktioniert.md), [Referenz](Konfiguration_des_Notification_Service.md)) |
| Telemetriedaten Service      | [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)  |
| Ingresscontroller            | [F5 nginx-ingress](https://docs.nginx.com/nginx-ingress-controller/) |
