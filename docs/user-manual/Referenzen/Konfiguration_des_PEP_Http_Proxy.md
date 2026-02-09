# PEP-Konfiguration

## Übersicht

Der PEP ist über einen nginx mit folgenden ZETA-spezifischen Plugins umgesetzt:

* libngx_pep.so
* libngx_asl.so _(Ist im Prototyp noch nicht enthalten.)_

## libngx_pep.so

Beispielkonfiguration:

```nginx
worker_processes  auto;

load_module modules/libngx_pep.so;

error_log  /dev/stdout debug;
pid        /run/nginx.pid;


events {
    worker_connections 16384;
    multi_accept       on;
    use                epoll;
}

http {
    include       /etc/nginx/mime.types;
    default_type  application/octet-stream;

    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /dev/stdout  main;

    sendfile    on;
    aio         threads;
    aio_write   on;
    tcp_nopush  on;

    keepalive_timeout  65;

    gzip  on;

    pep_issuer https://my.zeta.service.de/auth/realms/zeta-guard;
    # optional http client config, defaults:
    # pep_http_client_idle_timeout 30; # s
    # pep_http_client_max_idle_per_host 64;
    # pep_http_client_tcp_keepalive 30; # s
    # pep_http_client_connect_timeout 2; # s
    # pep_http_client_timeout 10; # s
    # pep_http_client_accept_invalid_certs off;

    server {
        listen 80;
        server_name  pep-proxy-svc;
        location / {
            proxy_pass        https://testfachdienst;
            # potentially useful for some test installations
            # proxy_ssl_verify  off;
        }
        location /pep_secured/ {
            proxy_pass        https://testfachdienst/;

            pep               on;

            # pep_require_aud_any  "account|other"; # optional, multiple values with |, any one match suffices
            # pep_require_scope    "openid profile email"; # optional, exact string match
            # pep_leeway           60; # s

            # potentially useful for some test installations
            # proxy_ssl_verify  off;

            # …you can use any standard nginx directive here as well…
        }
    }
}
```

Die obige Beispielkonfiguration ist eine minimale Konfiguration, die den
Testfachdienst (https://testfachdienst/) unter den beiden Pfaden `/` und
`/pep_secured/` bereitstellt.

Wichtig ist, dass am Anfang das PEP-Plugin geladen wird via
`load_module modules/libngx_pep.so;`.

Der Zugriff über `/` erfolgt dabei wie über einen industrieüblichen Reverse
Proxy ohne nennenswerte Besonderheiten.

Der Zugriff über `/pep_secured/` ist hierbei über die Direktive `pep on;` so
gestaltet, dass PEP-spezifisches Verhalten eingeschaltet wird.
Damit dies funktioniert, ist insbesondere die Direktive
`pep_issuer https://my.zeta.service.de/auth/realms/zeta-guard;` wichtig, die die
Verbindung zum PDP herstellt.

### Konfigurationsparameter

* `pep_issuer`
    * Typ: string
    * Beschreibung: Konfiguriert den zu verifizierenden Issuer in den
      ZETA-Guard-Access-Tokens.
      Dieser ist global für den PEP zu konfigurieren und steuert indirekt auch
      den Abruf der Token-Signaturschlüssel vom PDP.
    * Pflichtfeld: Ja
    * Context: `http`
    * Standardwert: (muss je nach Umgebung gesetzt werden)
* `pep_http_client_idle_timeout`, `pep_http_client_max_idle_per_host`,
  `pep_http_client_tcp_keepalive`, `pep_http_client_connect_timeout`,
  `pep_http_client_timeout`
    * Typ: integer
    * Beschreibung: Konfigurationen für den pep-spezifischen HTTP client. Dieser
      wird *nicht* für nginx-native Verbindungen, wie zu upstream Servern
      verwendet, sondern nur für interne Verbindungen bspw. zum PDP zwecks Abruf
      der
      OpenID-Konfiguration und JWKS.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: siehe Konfigurationsbeispiele oben
* `pep_http_client_accept_invalid_certs`
    * Typ: `on` | `off`
    * Beschreibung: Mit `on` kann der interne http client so konfiguriert
      werden,
      dass auch ungültige TLS-Zertifikate akzeptiert werden, bspw. für eine
      Testinstallation des PDP.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: `off`
* `pep`
    * Typ: `on` | `off`
    * Beschreibung: Konfiguriert, ob der nginx auf diesem Endpunkt sich wie ein
      PEP verhält.
    * Pflichtfeld: Nein
    * Context: `server`
    * Standardwert: `off`
* `pep_require_aud_any`
    * Typ: |-separierte Liste von Audiences. Beispiel: `audience1|audience2`
    * Beschreibung: Prüft ZETA-Guard-Access-Tokens auf das Vorhandensein von
      `aud`-Claims.
      Wenn mehr als eine Audience konfiguriert ist, ist die Anforderung "oder"
      -verknüpft, d.h. das Ergebnis ist "HTTP 401 Unauthorized", wenn keine der
      gelisteten Audiences in den Access-Token-Claims enthalten ist.
      Wenn keine erforderlichen Audiences konfiguriert sind, wird die Prüfung
      übersprungen.
    * Pflichtfeld: Nein
    * Context: `server`
    * Standardwert: `""`
* `pep_require_scope`
    * Typ: string
    * Beschreibung: Konfiguriert den zu verifizierenden Scope in den
      ZETA-Guard-Access-Tokens.
      Wenn konfiguriert, wird auf den exakten String geprüft.
      Es kann nicht auf ein beliebiges aus einer Menge alternativer Scopes
      geprüft werden.
    * Pflichtfeld: Nein
    * Context: `server`
    * Standardwert: `""`
* `pep_leeway`
    * Typ: integer
    * Beschreibung: Erlaubte Toleranz bei der zeitlichen Überprüfung von `exp`
      Claims in Sekunden.
      Hierüber soll eine Abweichung der Uhren zwischen Cluster und Client
      kompensiert werden.
    * Pflichtfeld: Nein
    * Context: `server`
    * Standardwert: `60`

## libngx_asl.so

Mehr Details zu MS2

### Konfigurationsparameter

* `asl`
    * Typ: `on` | `off`
    * Beschreibung: Konfiguriert, ob der nginx ASL spricht (i.d.R. auf `location /ASL`)
    * Pflichtfeld: Nein
    * Context: `server`
    * Standardwert: `off`
