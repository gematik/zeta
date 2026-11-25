# Wie Sie die effektive Konfiguration eines Telemetry-Gateways finden

Um neue Receiver, Prozessoren oder Exporter zu Telemetrie-Pipelines im
Telemetry-Gateway hinzuzufügen, muss die aktuelle Konfiguration kopiert und
ergänzt werden. Sie können die aktuelle Konfiguration aus einem Deployment des
ZETA-Guards auslesen[^1], oder aus dem Helm-Chart[^2]. In beiden Fällen müssen
Sie eine `ConfigMap` mit dem Label `app.kubernetes.io/name: telemetry-gateway`
finden. Das Telemetry-Gateway ist ein OpenTelemetry-Collector, und
seine [Konfiguration](https://opentelemetry.io/docs/collector/configuration/)
ist in dieser `ConfigMap`.

[^1]:
`kubectl describe configmaps --selector=app.kubernetes.io/name=telemetry-gateway`

[^2]: `helm template ... | yq eval-all '[select(.kind == "ConfigMap" and .metadata.labels["app.kubernetes.io/name"] == "telemetry-gateway")] | .[0]'`
