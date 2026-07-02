# Wie Sie einen Forward Proxy konfigurieren

Der ZETA-Guard unterstützt die Weiterleitung des ausgehenden HTTP/HTTPS-Verkehrs
über einen Forward Proxy. Dies ist in Umgebungen erforderlich, in denen der
Egress-Zugang zu externen Endpunkten – etwa dem PoPP-Aussteller-JWK-Endpunkt,
der OPA-Bundle-Registry oder GCP-Diensten – über einen Unternehmens- oder
Compliance-Proxy geleitet werden muss.

## Inhaltsverzeichnis

- [Betroffene Komponenten](#betroffene-komponenten)
  - [Subcharts (manuelle Konfiguration erforderlich)](#subcharts-manuelle-konfiguration-erforderlich)
- [Konfiguration](#konfiguration)
  - [Was in jedem Pod gesetzt wird](#was-in-jedem-pod-gesetzt-wird)
- [Empfehlungen für noProxy](#empfehlungen-für-noproxy)
- [Kein komponentenspezifisches Opt-out](#kein-komponentenspezifisches-opt-out)
- [Beispiel: minimales Produktions-Overlay](#beispiel-minimales-produktions-overlay)
- [Überprüfung](#überprüfung)

---

## Betroffene Komponenten

Die Proxy-Konfiguration wird automatisch von folgenden Komponenten übernommen:

| Komponente                                | Ausgehende Ziele                                |
|-------------------------------------------|-------------------------------------------------|
| `pepproxy` (nginx / reqwest)              | PoPP-JWK-Endpunkt, externe OIDC-Aussteller-JWKs |
| `authserver` (Keycloak)                   | OCSP, externe OIDC-Validierung                  |
| `opa` / `opa-simulation`                  | OPA-Bundle-Registry (OCI)                       |
| `provisioning-processor` (Init-Container) | OCI-Provisioning-Image-Registry                 |
| `opa-token-renewer` (CronJob)             | GCP STS / IAM APIs                              |

Folgende Komponenten erhalten bewusst keine Proxy-Konfiguration:

| Komponente                            | Grund                                                |
|---------------------------------------|------------------------------------------------------|
| `keycloak-build` Init-Container       | Führt `kc.sh build` lokal aus, kein ausgehender HTTP |
| `keychain-generator` Init-Container   | Nur gRPC zu cluster-internem HSM                     |

### Subcharts (manuelle Konfiguration erforderlich)

Folgende Subcharts werden **nicht** automatisch von `global.httpProxy` erfasst,
da es sich um upstream-Helm-Charts handelt, die keine globalen Proxy-Values
konsumieren. Konfigurieren Sie diese bei Bedarf manuell in Ihrer
Values-Override-Datei:

| Komponente                            | Ausgehende Ziele             | Konfigurationsschlüssel            |
|---------------------------------------|------------------------------|------------------------------------|
| `telemetry-gateway` (OTel Collector)  | gematik-Telemetrie-Endpunkte | `telemetry-gateway.extraEnvs`      |
| `test-monitoring-service` (OTel Demo) | nur cluster-intern           | nicht nötig — kein externer Egress |

Beispiel für `telemetry-gateway` bei aktiviertem `gematikConnectionEnabled: true`:

```yaml
telemetry-gateway:
  extraEnvs:
    - name: HTTP_PROXY
      value: "http://proxy.example.com:8080"
    - name: http_proxy
      value: "http://proxy.example.com:8080"
    - name: HTTPS_PROXY
      value: "http://proxy.example.com:8080"
    - name: https_proxy
      value: "http://proxy.example.com:8080"
    - name: NO_PROXY
      value: ".cluster.local"
    - name: no_proxy
      value: ".cluster.local"
    - name: ALL_PROXY
      value: "http://proxy.example.com:8080"
    - name: all_proxy
      value: "http://proxy.example.com:8080"
```

---

## Konfiguration

Setzen Sie die vier Proxy-Values einmalig unter `global:` in Ihrer
Values-Override-Datei. Helm propagiert `global` automatisch in alle Subcharts,
sodass ein einzelner Eintrag den gesamten Chart abdeckt.

```yaml
global:
  httpProxy: "http://proxy.example.com:8080"
  httpsProxy: "http://proxy.example.com:8080"
  allProxy: "http://proxy.example.com:8080"
  # Komma-separierte Liste von Hosts / Suffixen, die den Proxy umgehen.
  # Führender Punkt (.cluster.local) bedeutet bei den meisten Tools "jede Subdomain".
  noProxy: ".cluster.local,<interne-hosts>"
```

Alle vier Werte haben den Standard `null` (Proxy deaktiviert).

### Was in jedem Pod gesetzt wird

In jedem betroffenen Container setzt der Chart jede Proxy-Variable sowohl in
Groß- als auch in Kleinschreibung — da unterschiedliche HTTP-Clients und Tools
verschiedene Konventionen erwarten (`HTTP_PROXY` vs. `http_proxy`):

| Großschreibung | Kleinschreibung |
|----------------|-----------------|
| `HTTP_PROXY`   | `http_proxy`    |
| `HTTPS_PROXY`  | `https_proxy`   |
| `NO_PROXY`     | `no_proxy`      |
| `ALL_PROXY`    | `all_proxy`     |

Jede Variable wird nur gesetzt, wenn der entsprechende Value nicht `null` ist.

Für **nginx** (PEP) erzeugt der Chart zusätzlich `env HTTP_PROXY;`-Direktiven
in der `nginx.conf`, damit die Worker-Prozesse die Variablen erben. Der
`reqwest`-HTTP-Client liest sie beim Start des Worker-Prozesses ein.

Für **Keycloak** (Authserver) fügt der Chart `-Dhttp.nonProxyHosts=<konvertiert>`
zu `JAVA_OPTS_APPEND` hinzu. Das Java-Format für `http.nonProxyHosts`
unterscheidet sich vom Unix-Format in `NO_PROXY` (Pipe-Trenner, `*`-Wildcard
statt führendem Punkt); der Chart führt die Konvertierung automatisch durch:

| `noProxy`-Eintrag  | `http.nonProxyHosts`-Äquivalent |
|--------------------|---------------------------------|
| `authserver`       | `authserver`                    |
| `.cluster.local`   | `*.cluster.local`               |

---

## Empfehlungen für noProxy

Schließen Sie mindestens das interne DNS-Suffix Ihres Clusters ein, damit
Pod-zu-Pod-Kommunikation nicht über den Proxy läuft:

```yaml
noProxy: ".cluster.local"
```

Der führende Punkt ist eine **De-facto-Konvention** — es gibt keinen RFC-Standard
für die `NO_PROXY`-Syntax. Das Verhalten variiert je nach Tool:

| Tool            | Verhalten von `.cluster.local`                                                                              |
|-----------------|-------------------------------------------------------------------------------------------------------------|
| curl, reqwest   | Suffix-Match — Punkt ist optional; trifft `foo.cluster.local` **und** `cluster.local`                       |
| Go / grpc-go    | Nur Subdomains — trifft `foo.cluster.local`, aber **nicht** `cluster.local` selbst                          |

`.cluster.local` als einzelner Eintrag mit führendem Punkt deckt
`*.pod.cluster.local` und alle anderen Kubernetes-internen FQDNs sowohl bei
curl, reqwest als auch bei Go ab.

Fügen Sie weitere interne oder direkt erreichbare Hostnamen nach Bedarf hinzu.
Dienste, die nur per **Kurzname** (ohne das Suffix `.cluster.local`) referenziert
werden, passen nicht auf das Leading-Dot-Muster und werden an den Proxy
weitergeleitet, wenn sie nicht explizit aufgeführt sind:

```yaml
noProxy: ".cluster.local,authserver,opa"
```

> **Hinweis:** Der Apache HTTP Client von Java (intern in Keycloak verwendet)
> ignoriert die Leading-Dot-Konvention in `NO_PROXY`. Der Chart löst dies, indem
> er `global.noProxy` automatisch ins `http.nonProxyHosts`-Format konvertiert.
> Aus `.cluster.local` wird dabei `*.cluster.local` in der JVM-Systemeigenschaft.

---

## Kein komponentenspezifisches Opt-out

Die Proxy-Konfiguration wird global angewendet — es gibt keinen
komponentenspezifischen Proxy-Value. Sollen die ausgehenden Ziele einer
bestimmten Komponente den Proxy umgehen, tragen Sie diese Ziele in
`global.noProxy` ein, statt den Proxy pro Komponente zu konfigurieren.

Beispiel: Der `provisioning-processor` soll die Provisioning-Container-Registry
direkt erreichen, ohne den Proxy zu nutzen:

```yaml
global:
  httpsProxy: "http://proxy.example.com:8080"
  httpProxy: "http://proxy.example.com:8080"
  noProxy: ".cluster.local,europe-west3-docker.pkg.dev"
```

---

## Beispiel: minimales Produktions-Overlay

```yaml
global:
  httpsProxy: "http://squid.corp.example.com:3128"
  httpProxy: "http://squid.corp.example.com:3128"
  allProxy: "http://squid.corp.example.com:3128"
  noProxy: >-
    .cluster.local,
    <authserver-hostname>,
    <opa-hostname>
```

---

## Überprüfung

Nach dem Deployment können Sie prüfen, ob die Umgebungsvariablen im
PEP-Container gesetzt sind:

```shell
kubectl exec -n <namespace> deploy/pep-deployment -- env | grep -i proxy
```

Erwartete Ausgabe enthält `HTTP_PROXY`, `HTTPS_PROXY`, `NO_PROXY`, `ALL_PROXY`
(groß- und kleingeschrieben).

Prüfen Sie, ob nginx die `env`-Direktiven erhalten hat:

```shell
kubectl exec -n <namespace> deploy/pep-deployment -- \
  sh -c 'grep "^env" /etc/nginx/nginx.conf'
```

Erwartete Ausgabe:

```
env HTTP_PROXY;
env http_proxy;
env HTTPS_PROXY;
env https_proxy;
env ALL_PROXY;
env all_proxy;
env NO_PROXY;
env no_proxy;
```
