# Komponentenübersicht

[//]: # (![Abbildung Zero Trust-Architektur der TI 2.0]&#40;../assets/images/TI20_Zero_Trust_Architektur.svg&#41;)

Der ZETA-Guard wird als Ganzes über das
[ZETA-Guard-Helm-Chart](Referenz_des_Helm_Charts.md) ausgerollt. Ein Teil der
darin enthaltenen Komponenten ist optional: Sie lassen sich abschalten oder
durch eigene Betriebsmittel ersetzen. Diese Seite listet beides — die
Kernkomponenten und die optionalen Komponenten mit ihrem Schalter, ihrer
Funktion und der Folge, wenn sie entfällt.

## Kernkomponenten

Diese Komponenten sind Bestandteil jeder Installation.

| Komponente                   | Basistechnologie                                          | Funktion                                                                                     |
|------------------------------|-----------------------------------------------------------|----------------------------------------------------------------------------------------------|
| **Policy Enforcement Point** |                                                           |                                                                                              |
| HTTP Proxy                   | [nginx](https://nginx.org/en/docs/)                       | Prüft Access-Token, DPoP und PoPP, terminiert ASL und leitet an den Fachdienst weiter        |
| Provisioning Processor       | Container im PEP-Pod                                      | Holt die Vertrauensanker (TSL, TPM, Policy-Signer) aus dem signierten Provisioning-Container |
| **Policy Decision Point**    |                                                           |                                                                                              |
| Authorization Server         | [Keycloak](https://www.keycloak.org/)                     | Token-Exchange gegen SMC-B, dynamische Client-Registrierung, Nonces, Session-Revocation      |
| PDP-Datenbank                | [PostgreSQL](https://www.postgresql.org/docs/current/)    | Realm-, Client- und Sitzungsdaten des Authservers                                            |
| Policy Engine                | [Open Policy Agent](https://www.openpolicyagent.org/docs) | Entscheidet über Zugriffsanfragen anhand der Policies                                        |
| PEP-Datenbank                | [Infinispan](https://infinispan.org/)                     | Sitzungs- und Revocation-Caches; standardmäßig im Authserver eingebettet                     |

## Optionale Komponenten

| Komponente                  | Helm-Schalter                   | Standard      | Funktion und Folge bei Verzicht                                                                                                                                                                                                                                                                                                           |
|-----------------------------|---------------------------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Ingress-Controller (F5 NIC) | `nginx-ingress.enabled`         | `true`        | Terminiert TLS und routet auf PEP und Authserver. Ohne ihn übernimmt der Ingress des Betreibers; mehrere Funktionen sind dann nachzubilden — siehe [Wie Sie einen eigenen Ingress-Controller verwenden](../Anleitungen/Wie_Sie_einen_eigenen_Ingress_Controller_verwenden.md).                                                            |
| Ingress-Ressourcen          | `ingressEnabled`                | `true`        | Erzeugt die Ingress-Objekte des Charts. `false` überlässt Definition und Pflege vollständig dem Betreiber.                                                                                                                                                                                                                                |
| Telemetriedaten-Service     | `telemetryGatewayEnabled`       | `true`        | [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/): nimmt Traces, Metriken und Logs aller Komponenten entgegen, redigiert sie und liefert sie an TI-Monitoring und TI-SIEM. Ohne ihn laufen die OTLP-Exporte der Komponenten ins Leere — keine Telemetrie an die gematik, kein Observability-Backend, keine KPI-Zählung. |
| gematik-Anbindung           | `gematikConnectionEnabled`      | `true`        | CronJobs, die die Zugangstoken für TI-SIM und TI-SIEM gültig halten. Ohne sie ist kein Versand an die gematik möglich, auch wenn der Telemetriedaten-Service läuft.                                                                                                                                                                       |
| Notification Service        | `notificationService.enabled`   | `false`       | Push-Benachrichtigungen zwischen Fachdienst, ZETA-Client und gematik Push Gateway (Vorschau). Siehe [Anleitung](../Anleitungen/Wie_der_Notification_Service_funktioniert.md) und [Referenz](Konfiguration_des_Notification_Service.md).                                                                                                   |
| OPA-Simulationsinstanz      | `opa.simulation.enabled`        | `true`        | Wertet Policies parallel zur aktiven Instanz aus, ohne Entscheidungen zu treffen — dadurch lassen sich Policy-Änderungen vor der Aktivierung beobachten. Ohne sie entfällt diese Vorschau.                                                                                                                                                |
| Egress-NetworkPolicies      | `networkPolicy.enabled`         | `false`       | Beschränken den ausgehenden Verkehr jedes Pods auf freigegebene IP-Blöcke, siehe [Wie Sie Egress-NetworkPolicies konfigurieren](../Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md). Ohne sie gilt die Egress-Policy des Clusters.                                                                                            |
| Service Mesh (Istio)        | `global.istio.enabled`          | `false`       | Namespace-weite `PeerAuthentication` im Modus `STRICT` — mTLS für die clusterinterne Kommunikation. Ohne Mesh sind die Hops im Cluster unverschlüsselt und müssen anderweitig abgesichert werden.                                                                                                                                         |
| cert-manager-Issuer         | `issuer` / `clusterIssuer`      | `""`          | Lässt das TLS-Zertifikat der Ingress-Hostnamen von cert-manager ausstellen. Ohne Issuer stellt der Betreiber das TLS-Secret selbst bereit.                                                                                                                                                                                                |
| Separater Admin-Hostname    | `authserver.adminHostname`      | nicht gesetzt | Eigener Hostname für Admin-REST-API und Admin-Konsole; auf dem öffentlichen Hostnamen werden sie dann gesperrt. Ohne ihn bleiben beide auf dem öffentlichen Hostnamen erreichbar.                                                                                                                                                         |
| CloudNativePG-Datenbank     | `databaseMode`                  | `cloudnative` | `external` ersetzt das vom Chart verwaltete PostgreSQL-Cluster durch eine vom Betreiber bereitgestellte Datenbank (`authserverDb.*`).                                                                                                                                                                                                     |
| Externer Infinispan         | `global.infinispanExternal`     | `{}`          | Löst den eingebetteten Cache des Authservers durch einen dedizierten Infinispan-Server ab — Voraussetzung für die horizontale Skalierung des Authservers. Siehe [Referenz des Helm-Charts — Infinispan](Referenz_des_Helm_Charts.md#infinispan).                                                                                          |

## Hinweise für Betreiber eigener Komponenten

* **Telemetrie darf nicht umgeleitet werden.** Ein eigenes
  Observability-Backend wird als zusätzlicher Exporter *innerhalb* des
  Telemetriedaten-Service angebunden, nicht dadurch, dass die Komponenten auf
  ein anderes Ziel zeigen — die Redaktions- und Filterstufen des Gateways sind
  nicht umgehbar. Siehe
  [Wie Sie ein Observability-Backend anschließen](../Anleitungen/Wie_Sie_ein_Observability-Backend_an_ZETA-Guard_anschließen.md).
* **Horizontale Skalierung setzt Sitzungsaffinität voraus.** PEP (ASL-Sitzungen)
  und Authserver (Nonces) halten Zustand pro Instanz. Ohne die vom
  mitgelieferten Ingress gesetzte Affinität sind beide auf eine Replica
  beschränkt.
* **Läuft eine Komponente außerhalb des Charts, ist der Egress freizugeben.**
  Die Egress-NetworkPolicies erlauben als Ziel nur Pods im selben Namespace;
  externe Ziele sind explizit zu ergänzen.
