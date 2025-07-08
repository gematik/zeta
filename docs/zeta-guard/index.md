# ZETA Guard v1

ZETA Guard ist die zentrale Komponente von ZETA, die als Policy Enforcement Point (PEP) und Policy Decision Point (PDP) fungiert. ZETA Guard ist verantwortlich für die Durchsetzung von Sicherheitsrichtlinien und die Entscheidung über Zugriffsanfragen auf geschützte Resource Server.
ZETA Guard bietet eine RESTful API, die es ZETA Clients ermöglicht, sich zu registrieren, zu authentifizieren und Autorisierungsanfragen zu stellen. Die API ist so gestaltet, dass sie eine einfache Integration in bestehende Systeme ermöglicht und gleichzeitig die Sicherheitsanforderungen des Zero Trust Modells erfüllt.

---

## Volumen des ausgehenden Traffic

ZETA Guard kommuniziert mit den ZETA Clients und der Telemetriedaten Erfassung. Der ausgehende Traffic von ZETA Guard umfasst:

- **ZETA Clients**: ZETA Guard sendet Service Discovery Daten, Client-Registrierungsdaten und Autorisierungsentscheidungen an die ZETA Clients.
  - **Service Discovery**: < 10 kB (1 x pro Tag und Nutzer)
  - **Client-Registrierung**: < 5 kB  (1 x pro Client einmalig)
  - **Autorisierungsentscheidungen**: 
- **Telemetriedaten Erfassung**: ZETA Guard sendet Telemetriedaten an die Telemetriedaten Erfassung, um die Sicherheit und Leistung des Systems zu überwachen. Diese Daten umfassen Informationen über Zugriffsanfragen, Autorisierungsentscheidungen und Systemereignisse. Die Telemetriedaten Erfassung ermöglicht es, Muster zu erkennen und potenzielle Sicherheitsvorfälle frühzeitig zu identifizieren.
  - Telemetriedaten (Logs, Metriken, Selbstauskunft): < 2 kB (angenommen alle 10 Sekunden; das Sende-Intervall wird in der Testphase abgestimmt und festgelegt)
- 
