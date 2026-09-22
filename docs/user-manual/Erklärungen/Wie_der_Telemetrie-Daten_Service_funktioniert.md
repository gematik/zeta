# Wie der Telemetriedaten-Service funktioniert

Der Telemetriedaten-Service ist
ein [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/).

## OpenTelemetry-Collector-Distribution

Der Telemetriedaten-Service ist eine für ZETA-Guard maßgeschneiderte
Distribution des OpenTelemetry Collectors. Sie besitzt einen Receiver, der
Decision Logs und Status Updates des Open Policy Agent in Logs umwandeln kann.
Dieser Receiver ist nicht Teil einer offiziellen Distribution von OpenTelemetry.

## Datenfluss und -verarbeitung innerhalb des Telemetriedaten-Services

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

Die Pipelines sind unabhängig und nicht mit Connectoren verbunden.

### Zweck und Konfigurierbarkeit der Pipelines

Neue Pipelines hinzuzufügen oder vorkonfigurierte Pipelines zu entfernen ist
nicht vorgesehen. Ebenso ist das Verändern oder Entfernen von Prozessoren nicht
vorgesehen. Die übrige Konfiguration des Telemetriedaten-Services erfolgt über
das Hinzufügen neuer Receiver und Exporter.

Der Dienst-Hersteller ist für den Anschluss des Resource Servers an den
Telemetriedaten-Service verantwortlich und darf bei Bedarf zusätzliche
Receiver in alle Pipelines einbauen.

Für den Anschluss eigener Observability-Backends muss der Dienst-Hersteller
eigene Exporter in die `*/dienst_hersteller`-Pipelines einbauen.

Der Versand von Telemetrie an den gematik-Telemetriedaten-Empfänger und das
gematik-TI-SIEM erfolgt durch die Pipelines `*/ti_siem` bzw. `*/ti_sim`.

### Prozessoren / Signalverarbeitung in den Pipelines

Jede dieser Pipelines verwendet die Prozessoren `memory_limiter`, `filter`,
`batch` und `redaction`. Der `redaction`-Prozessor schwärzt personenbezogene und
sicherheitskritische Daten aus den Signalen in den Pipelines, während der
`filter`-Prozessor Signale für den beabsichtigten Empfänger filtert. Eine
Konfiguration der Prozessoren durch den Dienst-Hersteller ist nicht vorgesehen;
insbesondere darf der `redaction`-Prozessor nicht verändert werden.

Die `*/dienst_hersteller`-Pipelines enthalten zusätzlich die Prozessoren
`filter/dienst_hersteller` und `transform/dienst_hersteller`. Sie entfernen
Signale, die ausschließlich der Sicherheitsüberwachung dienen — die Logs der
Attack-Detection, die Security-Events `authn_client_registered`,
`authn_client_registration_fail`, `authn_client_deleted` und
`authn_token_created`, OPA Decision-Logs, die Metriken `attack.detection.*` und
`zeta_guard_kpi.*` sowie das Span-Attribut `app.installation.id`. Diese Logs
und Metriken erreichen das Observability-Backend des Dienst-Herstellers nicht;
sie werden ausschließlich an TI-SIEM bzw. TI-SIM übermittelt (A_28960).

## Resilienz

Die beiden an die gematik sendenden Exporter (`otlp_grpc/ti_siem` und
`otlp_grpc/ti_sim`) verwenden eine
[Sending Queue](https://opentelemetry.io/docs/collector/resiliency/#sending-queue-in-memory-buffering),
die über die `file_storage`-Extension in einem PersistentVolumeClaim
persistiert wird — angenommene Telemetrie übersteht damit einen Pod-Neustart.
Alle übrigen Exporter puffern nur im Speicher. Größe, AccessModes und
StorageClass des PVC sind konfigurierbar (siehe
[Wie Sie ZETA-Guard in Kubernetes konfigurieren](../Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)).
Eine Message-Queue wie Kafka ist nicht vorgesehen.
