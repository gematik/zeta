# Wie der Telemetrie-Daten Service funktioniert

Der Telemetrie-Daten Service ist
ein [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/).

## OpenTelemetry Collector Distribution

Der Telemetrie-Daten Service ist eine für ZETA-Guard maßgeschneiderte
Distribution des OpenTelemetry Collectors. Sie besitzt einen Receiver, der
Decision Logs und Status Updates von Open Policy Agent in Logs umwandeln kann.
Dieser Receiver ist nicht Teil einer offiziellen Distribution von OpenTelemetry.

## Datenfluss und -Verarbeitung innerhalb des Telemetrie-Daten Service

Der Collector ist mit folgenden Pipelines vorkonfiguriert:

* `logs/dienst_hersteller`
* `logs/ti_sim`
* `logs/ti_siem`
* `metrics/dienst_hersteller`
* `metrics/ti_sim`
* `metrics/ti_siem`
* `traces/dienst_hersteller`
* `traces/ti_sim`
* `traces/ti_siem`

Die Pipelines sind unabhängig, und nicht mit Connectoren verbunden.

### Zweck und Konfigurierbarkeit der Pipelines

Neue Pipelines hinzuzufügen oder vorkonfigurierte Pipelines zu entfernen ist
nicht vorgesehen. Ebenso ist das Verändern oder Entfernen von Prozessoren nicht
vorgesehen. Die Konfiguration des Telemetrie-Daten Services erfolgt über das
Hinzufügen neuer Receiver und Exporter.

Der Dienst-Hersteller ist für den Anschluss des Resource-Servers an den
Telemetrie-Daten Service verantwortlich und darf bei Bedarf zusätzliche
Receiver in alle Pipelines einbauen.

Für den Anschluss eigener Observability-Backends muss der Dienst-Hersteller
eigene Exporter in die `*/dienst_hersteller`- Pipelines einbauen.

Der Versand von Telemetrie an den gematik-Telemetriedaten-Empfänger und das
gematik-TI-SIEM erfolgt durch die Pipelines `*/gematik` bzw. `*/ti_siem`.

### Prozessoren / Signalverarbeitung in den Pipelines

Jede dieser Pipelines verwendet die Prozessoren `memory_limiter`, `filter`,
`batch` und `redaction`. Der `redaction`-Prozessor schwärzt personenbezogene und
sicherheitskritische Daten aus den Signalen in den Pipelines, während der
`filter`-Prozessor Signale für den beabsichtigten Empfänger filtert.
Konfiguration der Prozessoren durch den Dienst-Hersteller ist nicht vorgesehen.

## Resilienz

Die vorkonfigurierten Exporter des Telemetrie-Daten Service verwenden
eine [Sending Queue mit In-Memory Buffer](https://opentelemetry.io/docs/collector/resiliency/#sending-queue-in-memory-buffering),
jedoch ohne Persistent Storage oder eine Message-Queue wie Kafka.
