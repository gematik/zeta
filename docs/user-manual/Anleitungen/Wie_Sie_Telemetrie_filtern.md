# Wie Sie Telemetrie filtern

Der Telemetry-Service von ZETA-Guard ist mit separaten Filtern für Telemetrie
für TI-SIM (`filter/ti_sim`) und für TI-SIEM (`filter/ti_siem`) konfiguriert.
Telemetrie für Dienst-Hersteller wird standardmäßig nicht gefiltert und besitzt
keinen Filter.

Der Telemetry-Service ist ein OpenTelemetry-Collector,
dessen [Konfiguration](https://opentelemetry.io/docs/collector/configuration/)
vollständig in den Values des ZETA-Guard-Helm-Charts enthalten ist, und beliebig
verändert werden kann. Filter benutzen
den [Filter-Prozessor des OpenTelemetry-Collectors](https://github.com/open-telemetry/opentelemetry-collector-contrib/tree/main/processor/filterprocessor).

_Änderungen an Filtern für Telemetrie in ZETA-Guard sind von den Entwicklern des
Charts nicht vorgesehen, sollten mit der gematik koordiniert werden und können
zu erhöhtem Aufwand bei zukünftigen Updates führen._

Hier ein Beispiel, das die Standardkonfiguration verändert, um zusätzlich Traces
und Spans mit dem Service-Name "OTHER SERVICE" an das TI-SIM zu versenden.

```yaml
telemetry-gateway:
    config:
        processors:
            filter/ti_sim:
                trace_conditions:
                    - >-
                      not (
                        resource.attributes["service.name"] == "resource server" or
                        HasPrefix(resource.attributes["service.name"], "rs.") or
                        resource.attributes["service.name"] == "OTHER SERVICE" or
                        (
                          resource.attributes["service.name"] == "ZETA Guard PEP HTTP proxy" and
                          span.kind == SPAN_KIND_SERVER and
                          (
                            span.attributes["url.path"] != "/status" and
                            span.attributes["http.route"] != "/status"
                          )
                        ) or
                        HasPrefix(resource.attributes["service.name"], "ZETA Guard ") and
                        span.attributes["attackDetection.capecId"] != nil
                      )
```

Bitte beachten Sie, dass die Bedingungen im Filter die vor dem Versandt **zu
entfernende Telemetrie** beschreiben. Nur Telemetrie, die keine der Bedingungen
erfüllt, wird versandt. Und achten Sie darauf, keine Regeln aus der
Standardkonfiguration des Charts unabsichtlich auszulassen.

Alternativ können Sie die Konfiguration eines der Filter in der
Standartkonfiguration kopieren und einen bzw. beide Standardfilter in den
Pipelines ersetzen.

Bitte beachten Sie die Referenz
von [ZETA-Guards Telemetrie-Attributen](../Referenzen/Telemetrie-Attribute.md)
zur Konstruktion effektiver Filter.
