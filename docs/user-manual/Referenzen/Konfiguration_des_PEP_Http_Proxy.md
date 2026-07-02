# PEP-Konfiguration

## Inhaltsverzeichnis

- [Übersicht](#übersicht)
- [libngx_pep.so](#libngxpepso)
  - [Header-Behandlung und `proxy_headers.conf`](#header-behandlung-und-proxy_headersconf)
  - [Konfigurationsparameter (PEP-Basis)](#konfigurationsparameter-pep-basis)
  - [Konfigurationsparameter (ASL)](#konfigurationsparameter-asl)

## Übersicht

Der PEP ist über einen nginx mit dem ZETA-spezifischen Plugin `libngx_pep.so`
umgesetzt.

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

        # Einmal serverweit einbinden: entfernt client-gesetzte Credentials/ZETA-* Header
        # und setzt die vom PEP kontrollierten Header. Alle Locations erben dies automatisch
        # (siehe Abschnitt "Header-Behandlung und proxy_headers.conf").
        include           proxy_headers.conf;

        location / {
            proxy_pass        https://testfachdienst;
            # potentially useful for some test installations
            # proxy_ssl_verify  off;
        }
        location /pep_secured/ {
            proxy_pass        https://testfachdienst/;

            pep               on;

            # Erbt proxy_headers.conf aus dem server-Block. Ein eigenes
            # `include proxy_headers.conf;` ist hier NUR nötig, wenn diese Location eigene
            # proxy_set_header-Direktiven deklariert (z.B. WebSocket-Upgrade) — dann greift
            # nginx' nicht-additive Vererbung (siehe Abschnitt unten).

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

### Header-Behandlung und `proxy_headers.conf`

`proxy_headers.conf` steuert sämtliche Header-Manipulation an der Upstream-Grenze.
Die Datei wird mit dem PEP-Image unter `/etc/nginx/proxy_headers.conf` ausgeliefert.

**Empfehlung — einmal serverweit einbinden:** Setzen Sie `include proxy_headers.conf;`
einmal im `server`-Block. Alle Locations erben es dann automatisch, sodass jede
PEP-geschützte `proxy_pass`-Location die Header-Behandlung erhält, ohne dass Sie das
Include pro Location wiederholen müssen. Inhaltlich bewirkt die Datei:

- **Entfernen client-gesetzter Credentials:** `Authorization`, `dpop` und `popp`
  authentisieren den Aufrufer nur *gegenüber dem PEP* und werden nicht an den
  Upstream weitergereicht.
- **ZETA-\* Header — der PEP ist die alleinige Quelle (A_25669-01):**
  `ZETA-User-Info`, `ZETA-Client-Data` und `ZETA-PoPP-Token-Content` werden
  ausschließlich vom PEP gesetzt; eine vom Client mitgeschickte Kopie dieser
  Header wird verworfen (überschrieben), nicht durchgereicht. `ZETA-Client-Data`
  wird nur dann gesetzt, wenn `pep_forward_client_data on;` konfiguriert ist;
  `ZETA-PoPP-Token-Content` nur, wenn ein PoPP-Token validiert wurde.
- **`Forwarded` (RFC 7239, A_28439):** Der PEP aktualisiert den `Forwarded`-Header
  und hängt sein eigenes Element an (`by=_zetapep`, `for`, `host`, `proto`); ein
  bereits vorhandener `Forwarded`-Wert bleibt erhalten.
- **`ZETA-API-Version`** ist ein Antwort-Header und wird auf dem Request-Pfad
  Richtung Upstream entfernt.

**Enforcement:** Erreicht eine Anfrage eine Location mit `pep on;` und `proxy_pass`,
auf der die Strips nicht wirksam sind (weder geerbt noch lokal eingebunden),
antwortet der PEP bewusst mit HTTP 500 (ProxyHeadersMissing), statt eine Anfrage
zu autorisieren, deren Credentials anschließend ungewollt an den Upstream gelangen
würden.

> **Wichtig — nicht-additive Vererbung:** nginx vererbt `proxy_set_header` *nicht*
> additiv. Eine Location, die eigene `proxy_set_header`-Direktiven deklariert
> (z.B. für WebSocket-Upgrades oder einen Cookie-Strip), erbt das serverweite
> `proxy_headers.conf` nicht und muss es selbst per `include proxy_headers.conf;`
> erneut einbinden — sonst fehlen die Strips dort (und auf `pep on;`-Locations führt
> das zum oben beschriebenen HTTP 500). Umgekehrt lässt sich eine Location über eine
> eigene `proxy_set_header`-Deklaration auch gezielt von der Header-Behandlung
> ausnehmen.

### Konfigurationsparameter (PEP-Basis)

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
* `pep_no_travel`
    * Typ: `on` | `off`
    * Beschreibung: Schaltet die No-Travel-Prüfung ein oder aus.
      Wenn die Prüfung eingeschaltet ist, müssen die IP-Adresse im
      Access-Token und die Client-IP des Aufrufers übereinstimmen.
    * Pflichtfeld: Nein
    * Context: `server`
    * Standardwert: `on`
* `pep_forward_client_data`
    * Typ: `on` | `off`
    * Beschreibung: Steuert, ob der `ZETA-Client-Data`-Header (Base64-URL-kodierte
      Client-Posture aus dem Access-Token) an den Upstream weitergereicht wird
      (A_26492-02). Bei `off` setzt der PEP den Header nicht; eine vom Client
      mitgeschickte Kopie wird in jedem Fall verworfen (siehe
      [Header-Behandlung und `proxy_headers.conf`](#header-behandlung-und-proxy_headersconf)).
    * Pflichtfeld: Nein
    * Context: `server`, `location`
    * Standardwert: `off`

### Konfigurationsparameter (ASL)

Diese Parameter werden nur benötigt, wenn tatsächlich ASL verwendet werden
soll. Pflichtfeld ist in diesem Sinne zu verstehen.

* `asl`
    * Typ: `on` | `off`
    * Beschreibung: Konfiguriert, ob der nginx ASL spricht (i.d.R. auf `location /ASL`)
    * Pflichtfeld: Ja
    * Context: `server`
    * Standardwert: `off`
* `pep_asl_signer_key`, `pep_asl_signer_cert`, `pep_asl_ca_cert`
    * Typ: string
    * Beschreibung: Absoluter Pfad zu den Bestandteilen der
      ASL-Signer-Identität im PEM-Format. Typischerweise ein Secret-Mount.
    * Pflichtfeld: Ja
    * Context: `http`
    * Standardwert: `/etc/nginx/signer_key.pem`, `/etc/nginx/signer_cert.pem`, `/etc/nginx/issuer_cert.pem`
* `pep_asl_roots_json`
    * Typ: string
    * Beschreibung: Absoluter Pfad zum Vertrauensanker roots.json.
      Typischerweise ein Secret-Mount.
    * Pflichtfeld: Ja
    * Context: `http`
    * Standardwert: `/etc/nginx/roots.json`
* `pep_asl_testing`
    * Typ: `on` | `off`
    * Beschreibung: Muss eingeschaltet werden, wenn der PEP in der
      Test/Refertenzumgebung der TI betrieben wird.
    * Pflichtfeld: Nein (aber siehe Beschreibung)
    * Context: `http`
    * Standardwert: `off`
* `pep_asl_root_ca`
    * Typ: string
    * Beschreibung: CN einer anderen Root-CA in roots.json, die anstelle von
      GEM.RCA7 verwendet werden soll (Override).
      Normalerweise nur zu Testzwecken verwendet.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: `""`
* `pep_asl_ocsp`
    * Typ: string
    * Beschreibung: Optionale OCSP-URL, die anstatt der URL in
      `pep_asl_signer_cert` verwendet werden soll (Override).
      Alternativ der Wert `off` um OCSP stapling zu deaktivieren.
      Normalerweise nur zu Testzwecken verwendet.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: `""`
* `pep_asl_ocsp_ttl`
    * Typ: duration
    * Beschreibung: Maximale Gültigkeit einer OCSP-Antwort im Cache bis ein
      erneuter Abruf erforderlich ist. Mögliche Einheiten sind
      `d` Tage, `h` Stunden, `m` Minuten (Standard), oder `s` Sekunden.
      Normalerweise nur zu Testzwecken verwendet.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: `"24h"`

