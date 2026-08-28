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

    pep_pdp_issuer https://my.zeta.service.de/auth/realms/zeta-guard;
    # optional http client config, defaults:
    # pep_http_client_connect_timeout 2; # s
    # pep_http_client_timeout 10; # s
    # pep_http_client_accept_invalid_certs off;

    server {
        listen 80;
        server_name  pep-proxy-svc;

        # Einmal serverweit einbinden: setzt die vom PEP kontrollierten ZETA-*-Header und
        # verwirft client-gesetzte Kopien davon. Alle Locations erben dies automatisch
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

            # pep_require_aud      "account other"; # optional, space-separated set, ALL must be present
            # pep_require_scope    "openid profile email"; # optional, space-separated set, ALL must be present
            # pep_leeway           60; # s
            # pep_require_popp     on;        # optional, requires and validates PoPP-Token
            # pep_popp_validity    quarter;   # optional, quarter (Standard) or fixed duration (e.g. 1d, 86400)

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
`pep_pdp_issuer https://my.zeta.service.de/auth/realms/zeta-guard;` wichtig, die die
Verbindung zum PDP herstellt.

### Header-Behandlung und `proxy_headers.conf`

`proxy_headers.conf` steuert sämtliche Header-Manipulation an der Upstream-Grenze.
Die Datei wird mit dem PEP-Image unter `/etc/nginx/proxy_headers.conf` ausgeliefert.

**Empfehlung — einmal serverweit einbinden:** Setzen Sie `include proxy_headers.conf;`
einmal im `server`-Block. Alle Locations erben es dann automatisch, sodass jede
PEP-geschützte `proxy_pass`-Location die Header-Behandlung erhält, ohne dass Sie das
Include pro Location wiederholen müssen. Inhaltlich bewirkt die Datei:

- **Credentials `Authorization`, `dpop` und `popp` werden weitergereicht:** Diese
  Header authentisieren den Aufrufer gegenüber dem PEP, werden aber zur Erfüllung
  von A_25669-01 unverändert an den Upstream weitergegeben — der Fachdienst kann
  Access-Token, DPoP-Proof und PoPP-Token damit selbst auswerten. Frühere
  PEP-Versionen haben diese Header an der Upstream-Grenze entfernt; die
  entsprechenden `proxy_set_header`-Zeilen sind in `proxy_headers.conf`
  auskommentiert. Eine PEP-Direktive zur Steuerung dieses Verhaltens gibt es
  nicht.
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
auf der die Header-Behandlung nicht wirksam ist (weder geerbt noch lokal
eingebunden), antwortet der PEP bewusst mit HTTP 500 (ProxyHeadersMissing), statt
eine Anfrage zu autorisieren, deren ZETA-\*-Header anschließend ungefiltert an den
Upstream gelangen würden. Technisch prüft der PEP dazu das Vorhandensein des
Sentinel-Headers `x-zeta-headers-applied` im kompilierten Proxy-Header-Set der
Location.

> **Wichtig — nicht-additive Vererbung:** nginx vererbt `proxy_set_header` *nicht*
> additiv. Eine Location, die eigene `proxy_set_header`-Direktiven deklariert
> (z.B. für WebSocket-Upgrades oder einen Cookie-Strip), erbt das serverweite
> `proxy_headers.conf` nicht und muss es selbst per `include proxy_headers.conf;`
> erneut einbinden — sonst fehlt dort die Header-Behandlung (und auf
> `pep on;`-Locations führt das zum oben beschriebenen HTTP 500). Umgekehrt lässt
> sich eine Location über eine eigene `proxy_set_header`-Deklaration auch gezielt
> von der Header-Behandlung ausnehmen.

### Konfigurationsparameter (PEP-Basis)

* `pep_pdp_issuer`
    * Typ: string
    * Beschreibung: Konfiguriert den zu verifizierenden Issuer in den
      ZETA-Guard-Access-Tokens.
      Dieser ist global für den PEP zu konfigurieren und steuert indirekt auch
      den Abruf der Token-Signaturschlüssel vom PDP.
    * Pflichtfeld: Ja
    * Context: `http`
    * Standardwert: (muss je nach Umgebung gesetzt werden)
* `pep_revocation_url`
    * Typ: string (URL)
    * Beschreibung: Endpunkt der Session-Revocation-API des PDP. Die Direktive
      wirkt in beide Richtungen:
      Der PEP abonniert den Endpunkt als Server-Sent-Event-Stream und pflegt
      daraus eine Block-List gesperrter Sessions. Bei jeder Anfrage prüft er den
      `sid`-Claim des Access-Tokens dagegen und antwortet bei einem Treffer mit
      `HTTP 401 Unauthorized` (`RevokedSession`).
      Zusätzlich *meldet* der PEP über denselben Endpunkt per POST, wenn die
      No-Travel-Prüfung (`pep_no_travel`) eine abweichende Client-IP feststellt.
      Ohne gesetzte Direktive protokolliert der PEP beim Start eine Warnung und
      der Revocation-Stream bleibt deaktiviert; No-Travel-Verstöße werden dann
      weiterhin abgelehnt, nur nicht mehr an den PDP gemeldet.
      Ein leerer oder nicht als URL interpretierbarer Wert wird beim Start
      abgelehnt.
    * Pflichtfeld: Nein (aber siehe Beschreibung)
    * Context: `http`
    * Standardwert: nicht gesetzt
* `pep_popp_issuer`
    * Typ: string
    * Beschreibung: Issuer des PoPP-Servers. Der PEP ermittelt darüber dessen
      Entity Statement und die Signaturschlüssel, mit denen er PoPP-Tokens
      prüft. Erforderlich, sobald auf irgendeiner Location
      `pep_require_popp on;` gesetzt ist. Ein leerer Wert wird beim Start
      abgelehnt.
    * Pflichtfeld: Nein (aber siehe Beschreibung)
    * Context: `http`
    * Standardwert: nicht gesetzt
* `pep_http_client_connect_timeout`, `pep_http_client_timeout`
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
    * Context: `http`, `server`, `location`
    * Standardwert: `off`
* `pep_require_aud`
    * Typ: leerzeichen-separierte Menge von Audiences. Beispiel:
      `audience1 audience2`
    * Beschreibung: Prüft ZETA-Guard-Access-Tokens auf das Vorhandensein von
      `aud`-Claims.
      Die Anforderung ist "und"-verknüpft: **alle** konfigurierten Audiences
      müssen im `aud`-Claim des Access-Tokens enthalten sein. Fehlt eine davon,
      ist das Ergebnis "HTTP 401 Unauthorized".
      Wenn keine erforderlichen Audiences konfiguriert sind, wird die Prüfung
      übersprungen.
    * Pflichtfeld: Nein
    * Context: `http`, `server`, `location`
    * Standardwert: `""`
* `pep_require_scope`
    * Typ: leerzeichen-separierte Menge von Scopes. Beispiel:
      `openid profile email`
    * Beschreibung: Konfiguriert die zu verifizierenden Scopes in den
      ZETA-Guard-Access-Tokens.
      Die Anforderung ist "und"-verknüpft: **alle** konfigurierten Scopes müssen
      im `scope`-Claim des Access-Tokens enthalten sein, wobei die Reihenfolge
      keine Rolle spielt. Fehlt einer davon, ist das Ergebnis
      "HTTP 401 Unauthorized".
      Es kann nicht auf ein beliebiges aus einer Menge alternativer Scopes
      geprüft werden.
    * Pflichtfeld: Nein
    * Context: `http`, `server`, `location`
    * Standardwert: `""`
* `pep_leeway`
    * Typ: integer
    * Beschreibung: Erlaubte Toleranz bei der zeitlichen Überprüfung von `exp`
      Claims in Sekunden.
      Hierüber soll eine Abweichung der Uhren zwischen Cluster und Client
      kompensiert werden.
    * Pflichtfeld: Nein
    * Context: `http`, `server`, `location`
    * Standardwert: `60`
* `pep_dpop_validity`
    * Typ: integer
    * Beschreibung: Gültigkeitsdauer eines DPoP-Proofs ab seinem
      Ausstellungszeitpunkt (`iat`) in Sekunden. Der Proof wird akzeptiert,
      solange `iat + pep_dpop_validity + pep_leeway` noch nicht überschritten
      ist — die Toleranz aus `pep_leeway` kommt also zusätzlich hinzu.
    * Pflichtfeld: Nein
    * Context: `http`, `server`, `location`
    * Standardwert: `300`
* `pep_no_travel`
    * Typ: `on` | `off`
    * Beschreibung: Schaltet die No-Travel-Prüfung ein oder aus.
      Wenn die Prüfung eingeschaltet ist, müssen die IP-Adresse im
      Access-Token und die Client-IP des Aufrufers übereinstimmen.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: `off`
* `pep_forward_client_data`
    * Typ: `on` | `off`
    * Beschreibung: Steuert, ob der `ZETA-Client-Data`-Header (Base64-URL-kodierte
      Client-Posture aus dem Access-Token) an den Upstream weitergereicht wird
      (A_26492-02). Bei `off` setzt der PEP den Header nicht; eine vom Client
      mitgeschickte Kopie wird in jedem Fall verworfen (siehe
      [Header-Behandlung und `proxy_headers.conf`](#header-behandlung-und-proxy_headersconf)).
    * Pflichtfeld: Nein
    * Context: `http`, `server`, `location`
    * Standardwert: `off`
* `pep_require_popp`
    * Typ: `on` | `off`
    * Beschreibung: Verlangt pro Endpunkt das Vorhandensein des `PoPP`-Request-Headers
      und validiert das enthaltene PoPP-Token (A_26477). Geprüft werden u.a. die
      Signatur des PoPP-Servers sowie die Übereinstimmung des Claims
      `actorId` mit dem `sub` der zum Access-Token gehörenden Nutzer-Daten. Die
      dekodierten Claims werden als Header `ZETA-PoPP-Token-Content` an den Upstream
      weitergereicht.
      Fehlt der `PoPP`-Header, obwohl er verlangt wird, antwortet der PEP mit
      `HTTP 400 Bad Request`. Ist die Signatur ungültig oder schlägt eine der
      anderen Prüfungen fehl, antwortet der PEP mit `HTTP 403 Forbidden`.
      Der Issuer des PoPP-Servers wird global über `pep_popp_issuer` konfiguriert.
    * Pflichtfeld: Nein
    * Context: `http`, `server`, `location`
    * Standardwert: `off`
* `pep_popp_validity`
    * Typ: `quarter` | duration
    * Beschreibung: Legt pro Endpunkt die Dauer der Gültigkeit des PoPP-Tokens ab
      Ausstellung (`iat`) fest (A_26477).
      Der Wert `quarter` bedeutet, dass Ausstellungszeitpunkt und Prüfzeitpunkt im
      selben Kalenderquartal (UTC) liegen müssen (siehe gemSpec_ZETA — A_26477).
      Alternativ kann eine feste Dauer seit `iat` angegeben werden. Mögliche
      Einheiten sind `d` Tage, `h` Stunden, `m` Minuten oder `s` Sekunden (Standard,
      wenn keine Einheit angegeben ist), z.B. `1d` oder `86400`.
      In beiden Fällen wird `pep_leeway` als Toleranz addiert.
    * Pflichtfeld: Nein
    * Context: `http`, `server`, `location`
    * Standardwert: `quarter`

### Konfigurationsparameter (ASL)

Diese Parameter werden nur benötigt, wenn tatsächlich ASL verwendet werden
soll. Pflichtfeld ist in diesem Sinne zu verstehen.

**Die Datei-Direktiven haben keinen eingebauten Standardwert.** Ohne Angabe
bleibt der Wert leer; die Pfade in den Beispielen dieses Kapitels und im Helm
Chart sind Konventionen des jeweiligen Deployments, nicht Vorbelegungen des
Moduls. Weiterhin gilt für alle ASL-Direktiven:

- **Leere Werte werden abgelehnt.** `pep_asl_ocsp ""` oder
  `pep_asl_root_ca ""` führen zum Startfehler, statt als „nicht gesetzt"
  behandelt zu werden. Eine Direktive, die nicht wirken soll, lässt man weg.
- **Pfade dürfen relativ sein.** Relative Angaben löst der PEP gegen das
  Konfigurationsverzeichnis des nginx auf (`<nginx-prefix>/conf`).
- **Der ASL-Signer-Schlüssel kann im HSM bleiben.** Beginnt der Wert von
  `pep_asl_signer_key` mit `store:`, lädt der PEP den Schlüssel nicht als Datei,
  sondern über den OpenSSL-Provider `ossl_hsm` (`store:hsm:<key-id>`, im Helm
  Chart über `pepproxy.asl_hsm_key` — siehe
  [HSM-Konfiguration (ASL-Signaturschlüssel)](Referenz_des_Helm_Charts.md#hsm-konfiguration-asl-signaturschlüssel)).
  Für Zertifikate und roots.json gilt das nicht — sie werden immer als Datei
  gelesen.

**Alle-oder-keine-Regel für die vier Datei-Direktiven** `pep_asl_signer_cert`,
`pep_asl_signer_key`, `pep_asl_ca_cert` und `pep_asl_roots_json`:

- Sind **alle vier** gesetzt, initialisiert der PEP ASL beim Start.
- Ist **keine** gesetzt, bleibt ASL unkonfiguriert. Der PEP startet, kann aber
  keine Location mit `asl on;` bedienen.
- Fehlt **genau eine**, bricht der PEP den Start mit der Meldung
  `must have either all or none of ASL signer_cert, signer_key, ca_cert, roots_json`
  ab.

* `asl`
    * Typ: `on` | `off`
    * Beschreibung: Konfiguriert, ob der nginx ASL spricht (i.d.R. auf `location /ASL`)
    * Pflichtfeld: Ja
    * Context: `http`, `server`, `location`
    * Standardwert: `off`
* `pep_asl_signer_key`, `pep_asl_signer_cert`, `pep_asl_ca_cert`
    * Typ: string (Pfad oder `store:`-URI)
    * Beschreibung: Bestandteile der ASL-Signer-Identität im PEM-Format —
      privater Schlüssel, zugehöriges Signer-Zertifikat und Zertifikat der
      ausstellenden CA. Typischerweise ein Secret-Mount.
    * Pflichtfeld: Ja
    * Context: `http`
    * Standardwert: nicht gesetzt (das Helm Chart schreibt
      `/etc/nginx/signer_key.pem`, `/etc/nginx/signer_cert.pem` und
      `/etc/nginx/issuer_cert.pem` in die nginx.conf)
* `pep_asl_roots_json`
    * Typ: string (Pfad)
    * Beschreibung: Pfad zum Vertrauensanker roots.json.
      Typischerweise ein Secret-Mount.
    * Pflichtfeld: Ja
    * Context: `http`
    * Standardwert: nicht gesetzt (das Helm Chart schreibt
      `/var/trust-data/roots.json` in die nginx.conf)
* `pep_asl_testing`
    * Typ: `on` | `off`
    * Beschreibung: Muss eingeschaltet werden, wenn der PEP in der
      Test-/Referenzumgebung der TI betrieben wird.
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
    * Standardwert: nicht gesetzt (es gilt GEM.RCA7)
* `pep_asl_ocsp`
    * Typ: `off` | `cert` | URL
    * Beschreibung: Steuert das OCSP Stapling für das ASL-Signer-Zertifikat.
        * `cert` — der PEP verwendet die OCSP-URL aus dem Signer-Zertifikat
          (AIA-Extension). Enthält das Zertifikat keine, findet kein Stapling
          statt.
        * Eine URL — Override dieser Adresse. Normalerweise nur zu Testzwecken.
        * `off` — deaktiviert das OCSP Stapling. Normalerweise nur zu
          Testzwecken.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: `cert`
* `pep_asl_ocsp_ttl`
    * Typ: duration
    * Beschreibung: Maximale Gültigkeit einer OCSP-Antwort im Cache bis ein
      erneuter Abruf erforderlich ist. Mögliche Einheiten sind
      `d` Tage, `h` Stunden, `m` Minuten (Standard), oder `s` Sekunden.
      Normalerweise nur zu Testzwecken verwendet.
    * Pflichtfeld: Nein
    * Context: `http`
    * Standardwert: `"24h"`

