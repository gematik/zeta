# Wie Sie Egress-NetworkPolicies konfigurieren

Das ZETA-Guard-Helm-Chart beinhaltet optionale Kubernetes-`NetworkPolicy`-Ressourcen
(ausgehend/Egress), die den ausgehenden Netzwerkverkehr jedes ZETA-Guard-Pods auf
explizit freigegebene Ziel-IP-Blöcke beschränken.

Interner Cluster-Verkehr (Pod-zu-Pod-Kommunikation zwischen OPA, Datenbank,
Telemetry-Gateway) ist immer erlaubt und muss nicht gesondert konfiguriert werden.
DNS ist ebenfalls immer erlaubt; der DNS-*Peer* ist jedoch über
`networkPolicy.dns` konfigurierbar und muss auf OpenShift angepasst werden (siehe
[DNS-Egress](#dns-egress)).

## Inhaltsverzeichnis

- [Aktivieren](#aktivieren)
- [DNS-Egress](#dns-egress)
  - [OpenShift](#openshift)
- [Konfigurierbare Egress-Kategorien](#konfigurierbare-egress-kategorien)
  - [Wofür die drei OCSP-Kategorien stehen](#wofür-die-drei-ocsp-kategorien-stehen)
  - [Zuordnung zur URL-Liste der gematik](#zuordnung-zur-url-liste-der-gematik)
  - [Verhalten bei nicht erreichbarem OCSP-Responder (z. B. RU DEV)](#verhalten-bei-nicht-erreichbarem-ocsp-responder-z-b-ru-dev)
- [IP-Blöcke konfigurieren](#ip-blöcke-konfigurieren)
  - [IP-Adressen ermitteln](#ip-adressen-ermitteln)
- [Warum nur IP-Blöcke — keine DNS-Namen (FQDN)](#warum-nur-ip-blöcke--keine-dns-namen-fqdn)
- [Anbieter-interner Verkehr](#anbieter-interner-verkehr)
- [Egress-Bedarf je Pod](#egress-bedarf-je-pod)
- [Verwandte Dokumentation](#verwandte-dokumentation)

## Aktivieren

```yaml
networkPolicy:
  enabled: true   # Standard: false
```

Solange `enabled: false` (Standard), werden keine NetworkPolicy-Ressourcen erzeugt.

## DNS-Egress

Jede Egress-NetworkPolicy erlaubt die DNS-Auflösung. Der DNS-Peer ist über
`networkPolicy.dns` konfigurierbar und verweist standardmäßig auf den
kube-dns-Dienst von Upstream-Kubernetes / KIND:

```yaml
networkPolicy:
  dns:
    namespaceSelector:
      matchLabels:
        kubernetes.io/metadata.name: kube-system
    podSelector:
      matchLabels:
        k8s-app: kube-dns
    ports:
      - port: 53
        protocol: UDP
      - port: 53
        protocol: TCP
```

Um den DNS-Egress auf einen anderen Dienst zu richten, setzen Sie
`networkPolicy.dns.to` auf eine rohe Liste von `NetworkPolicyPeer`-Einträgen. Sie
wird unverändert übernommen und überschreibt `namespaceSelector`/`podSelector`.

> **Hinweis:** Überschreiben Sie `namespaceSelector`/`podSelector` nicht direkt.
> Helm führt Maps tief zusammen, sodass Ihr Label zum Default `k8s-app: kube-dns`
> hinzugefügt würde. Ein `matchLabels` verknüpft alle Labels mit logischem UND,
> d. h. der Selektor träfe dann keinen Pod und die DNS-Auflösung bräche. Listen
> wie `dns.to` werden dagegen vollständig ersetzt und überschreiben sauber.

### OpenShift

OpenShift betreibt kein kube-dns. DNS wird von CoreDNS-Pods im Namespace
`openshift-dns` bereitgestellt, und da OVN-Kubernetes Egress nach dem DNAT
auswertet, ist der am Pod ankommende Ziel-Port 5353 statt 53:

```yaml
networkPolicy:
  dns:
    to:
      - namespaceSelector:
          matchLabels:
            kubernetes.io/metadata.name: openshift-dns
        podSelector:
          matchLabels:
            dns.operator.openshift.io/daemonset-dns: default
    ports:
      - port: 5353
        protocol: UDP
      - port: 5353
        protocol: TCP
```

## Konfigurierbare Egress-Kategorien

Jede Kategorie akzeptiert eine Liste von CIDR-Strings unter `ipBlocks`. Bleibt die
Liste leer, wird kein externer Egress für diese Kategorie erlaubt.

| Schlüssel                                  | Ziel                                                         |
|--------------------------------------------|--------------------------------------------------------------|
| `egress.telemetry`                         | gematik-Telemetriedaten-Empfänger (OTLP-Endpunkt)            |
| `egress.siem`                              | SIEM der gematik                                             |
| `egress.artifactRegistry`                  | ZETA-Artifact-Registry bei der gematik (OPA-Bundles, Images) |
| `egress.providerArtifactRegistry`          | Anbieter-interne Artifact Registry                           |
| `egress.ocspCabForum`                      | OCSP/CRL für TLS-TSPs nach CAB Forum                         |
| `egress.ocspSmcbTsp`                       | OCSP-Responder des SMC-B-TSP                                 |
| `egress.ocspTiPki`                         | OCSP-Responder des TSP der Komponenten-PKI der TI            |
| `egress.pip`                               | PIP — Quelle der OPA-Policy-Bundles                          |
| `egress.popp`                              | PoPP-Dienst                                                  |
| `egress.providerInternal.resourceServers`  | Anbieter-interne Resource Server                             |
| `egress.providerInternal.telemetrySystems` | Anbieter-internes Telemetrie-System                          |

### Wofür die drei OCSP-Kategorien stehen

Jede der drei Kategorien gehört zu genau einem Zertifikat, dessen Sperrstatus
eine ZETA-Guard-Komponente per OCSP abfragt. Die Responder-URL entnimmt die
Komponente der AIA-Extension dieses Zertifikats (siehe
[IP-Adressen ermitteln](#ip-adressen-ermitteln)). Die Kategorie legt nur fest,
welcher Pod diesen Responder erreichen darf.

| Kategorie      | Geprüftes Zertifikat                                      | Pod          | Aktiv, wenn                     | Steuernde Helm-Values                                                    |
|----------------|-----------------------------------------------------------|--------------|---------------------------------|--------------------------------------------------------------------------|
| `ocspSmcbTsp`  | SMC-B-Zertifikat aus dem `x5c`-Header des `subject_token` | `authserver` | bei jedem SMC-B-Token-Exchange  | `authserver.provider.smcB.ocsp*`, `provisioningProcessor.tslOcspEnabled` |
| `ocspTiPki`    | eigenes ASL-Signer-Zertifikat (Komponenten-PKI der TI)    | `pep-proxy`  | `pepproxy.asl_enabled: true`    | `pepproxy.aslOcsp`, `pepproxy.aslOcspTtl`                                |
| `ocspCabForum` | eigenes TLS-Serverzertifikat (`pepproxy.hsmTlsCert`)      | `pep-proxy`  | `pepproxy.hsmProxyAddr` gesetzt | `pepproxy.tlsConfig` (`ssl_stapling`)                                    |

- **`ocspSmcbTsp`:** Beim SMC-B-Token-Exchange prüft der `authserver` das
  SMC-B-Zertifikat der Leistungserbringerinstitution beim OCSP-Responder des
  ausstellenden SMC-B-TSP. Geprüft wird nur dieses Endzertifikat. Sperrungen
  der SMC-B-CAs und die vertrauenswürdigen OCSP-Signer bezieht der
  `authserver` offline aus der TSL, die der `provisioning-processor`
  bereitstellt. Mit `provisioningProcessor.tslOcspEnabled: false` entfällt die
  OCSP-Prüfung vollständig.
- **`ocspTiPki`:** Der `pep-proxy` holt die OCSP-Antwort für sein eigenes
  ASL-Signer-Zertifikat und schickt sie im ASL-Handshake (Nachricht M2) an den
  ZETA-Client mit. Die Antwort wird zwischengespeichert, standardmäßig bis zu
  24 Stunden (`pepproxy.aslOcspTtl`, A_24624-01). Mit `pepproxy.aslOcsp`
  geben Sie statt der AIA-URL einen eigenen Responder an (dann ist dessen
  Adresse freizugeben) oder schalten die Abfrage mit `"off"` ab.
- **`ocspCabForum`:** Terminiert der `pep-proxy` TLS selbst (Listener 8443,
  aktiv bei gesetztem `pepproxy.hsmProxyAddr`), heftet nginx per OCSP-Stapling
  (`ssl_stapling on;` in `pepproxy.tlsConfig`, A_26964) den Sperrstatus des
  TLS-Serverzertifikats an den Handshake an. Dieses Zertifikat stammt in der
  Regel von einer öffentlichen CA nach den Vorgaben des CA/Browser Forum
  (z. B. D-Trust). Welche Responder freizugeben sind, hängt also von der CA ab,
  die Sie für dieses Zertifikat wählen. Sie stehen deshalb nicht auf der
  URL-Liste der gematik.

> **Hinweis:** Die NetworkPolicy des `pep-proxy` lässt auch `ocspSmcbTsp` zu.
> Der `pep-proxy` prüft derzeit jedoch keine SMC-B-Zertifikate und nutzt diese
> Freigabe nicht. Benötigt wird die Kategorie nur vom `authserver`.

> **Hinweis:** Endet TLS bereits am Ingress, übernimmt der Ingress-Controller
> das Stapling für das Ingress-Zertifikat (`nginx-ingress.controller.config`).
> Für den Ingress-Controller erzeugt das Chart keine Egress-NetworkPolicy, und
> der `pep-proxy` braucht `ocspCabForum` in diesem Fall nicht.

### Zuordnung zur URL-Liste der gematik

Die gematik führt die externen Endpunkte, die ZETA-Guard im Betrieb erreichen
muss, auf der Seite
[ZETA Guard - URL's](https://wiki.gematik.de/spaces/TI2AUSTAUSCH/pages/764644216/ZETA+Guard+-+URL+s)
(Login erforderlich, alternativ über Ihre gematik-Ansprechperson). Für RU DEV,
RU REF und TU gelten die Tabellen „RU/TU“, für die PU die Tabellen „PU“. Die
Abschnitte der Seite entsprechen den Egress-Kategorien wie folgt:

| Abschnitt der gematik-Seite                                               | Egress-Kategorie                                            | Pod                                         |
|---------------------------------------------------------------------------|-------------------------------------------------------------|---------------------------------------------|
| „SMCB-CA's“, Spalte „SSP OCSP“                                            | `ocspSmcbTsp`                                               | `authserver`                                |
| „KOMP-CA's“, Spalte „SSP OCSP“                                            | `ocspTiPki`                                                 | `pep-proxy`                                 |
| „SMCB-CA's“ und „KOMP-CA's“, Spalten „OCSP Signer“ und „OCSP AIA's“       | keine, ZETA-Guard fragt diese Endpunkte nicht ab            | —                                           |
| „Telemetrie“, SIM-Endpunkt                                                | `telemetry`                                                 | `authserver`, `opa`, `telemetry-gateway`    |
| „Telemetrie“, SIEM-Endpunkte                                              | `siem`                                                      | `authserver`, `opa`, `telemetry-gateway`    |
| „Policies“ (`europe-west3-docker.pkg.dev`)                                | `artifactRegistry` bzw. `pip`                               | `opa`, `opa-simulation`                     |
| „Provisioning Container“                                                  | `artifactRegistry` (gespiegelt: `providerArtifactRegistry`) | `authserver`, `pep-proxy`                   |
| „Google Services“ (`sts.googleapis.com`, `iamcredentials.googleapis.com`) | `artifactRegistry` (Googles Edge-Bereiche)                  | wie „Policies“ und „Provisioning Container“ |
| „PoPP Service“                                                            | `popp`                                                      | `pep-proxy`                                 |
| nicht aufgeführt                                                          | `ocspCabForum`                                              | `pep-proxy`                                 |

Die Spalten „OCSP Signer“ und „OCSP AIA's“ betreffen die Zertifikate der CAs
und der OCSP-Signer selbst. Deren Vertrauens- und Sperrinformationen bezieht
ZETA-Guard offline aus der TSL. Die Google-Endpunkte für die Workload Identity
Federation liegen in Googles veröffentlichten Adressbereichen. Pflegen Sie
`artifactRegistry` wie unter [IP-Adressen ermitteln](#ip-adressen-ermitteln)
beschrieben mit diesen Bereichen, sind sie mit abgedeckt.

### Verhalten bei nicht erreichbarem OCSP-Responder (z. B. RU DEV)

Die OCSP-Responder der SMC-B- und Komponenten-CAs liegen überwiegend in
TI-Domänen: für RU DEV, RU REF und TU unter `*.telematik-test`, für die PU
unter `*.telematik`. Diese Namen sind nur über das DNS der TI auflösbar, die
Responder nur über einen TI-Zugang erreichbar. Fehlt dieser Zugang, fehlt die
DNS-Auflösung oder ist die IP-Liste der Kategorie leer oder unvollständig,
verhält sich ZETA-Guard so:

| Prüfung                             | Verhalten                                                                                                                                                                                                                                                                                       | Log                                                   |
|-------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| SMC-B-Zertifikat (`authserver`)     | Mit `ocspFailClosed: false` (Standard) gilt der Sperrstatus als unbestimmt, und der Token-Exchange wird fortgesetzt. Nur eine Antwort „revoked“ führt zur Ablehnung. Mit `ocspFailClosed: true` wird der Token-Exchange abgelehnt. Der unbestimmte Status wird eine Minute zwischengespeichert. | Warnung `OCSP request failed, response not available` |
| ASL-Signer-Zertifikat (`pep-proxy`) | Der ASL-Handshake läuft weiter, M2 enthält aber keine OCSP-Antwort. Der `pep-proxy` versucht es nach einer Minute erneut. Der ZETA-Client fragt den Responder dann selbst ab und braucht dafür seinerseits Zugang zu ihm.                                                                       | Warnung `refresh failed`                              |
| TLS-Serverzertifikat (`pep-proxy`)  | nginx führt den TLS-Handshake ohne angeheftete OCSP-Antwort durch.                                                                                                                                                                                                                              | Meldungen zu `ssl_stapling` bzw. zum OCSP-Responder   |

Eine blockierte Verbindung fällt erst nach dem Verbindungs-Timeout auf (beim
`authserver` `ocspConnectTimeoutMs`, standardmäßig 1 Sekunde). Ein
Token-Exchange kann sich dadurch entsprechend verzögern. Wollen Sie in einer
Umgebung ohne TI-Zugang bewusst auf OCSP verzichten, setzen Sie
`provisioningProcessor.tslOcspEnabled: false` (`authserver`) und
`pepproxy.aslOcsp: "off"` (`pep-proxy`). Für die PU ist das nicht vorgesehen
(A_24624-01).

## IP-Blöcke konfigurieren

```yaml
networkPolicy:
  enabled: true
  egress:
    telemetry:
      ipBlocks:
        - "34.117.144.61/32"   # otlp.v1.bd.prod.ccs.gematik.solutions (alle Umgebungen)
    artifactRegistry:
      ipBlocks:
        - "34.90.0.0/16"       # europe-west3-docker.pkg.dev (Google Artifact Registry)
    ocspSmcbTsp:
      ipBlocks:
        - "192.0.2.10/32"      # Platzhalter: ocsp-smcb.tsi.tsp-smc-b.telematik
    ocspTiPki:
      ipBlocks:
        - "192.0.2.20/32"      # Platzhalter: ocsp2.komp-ca.telematik
    ocspCabForum:
      ipBlocks:
        - "193.28.71.48/32"    # ocsp.d-trust.net
        - "62.96.224.138/32"   # crl.d-trust.net
```

### IP-Adressen ermitteln

- **gematik-Endpunkte** (telemetry, SIEM, PoPP): `dig +short <hostname>`
- **Google Artifact Registry**: veröffentlichte Edge-Bereiche von Google unter
  <https://www.gstatic.com/ipranges/goog.json>. Image-Manifeste und Layer-Blobs
  liefert beide `europe-west3-docker.pkg.dev` aus (Blobs per Redirect auf
  `/artifacts-downloads/…` desselben Hosts) — siehe Stabilitätshinweis unten
- **OCSP-Responder**: aus der AIA-Extension des jeweiligen Zertifikats:
  `openssl x509 -in <cert.pem> -text | grep -A2 "OCSP"` → `dig +short <ocsp-host>`

> **Stabilitätshinweise:**
> - `artifactRegistry` wird über Google CDN/Anycast ausgeliefert, daher ist eine
    einzelne `/32`-Adresse unzuverlässig — die aufgelöste IP unterscheidet sich je
    nach Standort (z. B. `142.251.x` aus einem Netz, `74.125.x` aus einem anderen).
    Geben Sie Googles veröffentlichte Edge-Bereiche aus
    <https://www.gstatic.com/ipranges/goog.json> frei. Bestätigt (2026-07): `74.125.0.0/16`, `142.250.0.0/15`, `192.178.0.0/15`,
    `172.217.0.0/16`, `216.58.192.0/19`, `209.85.128.0/17`. Vor dem Einsatz erneut
    gegen `goog.json` prüfen.
> - Die Responder für `ocspSmcbTsp` und `ocspTiPki` liegen in TI-Domänen
    (`*.telematik`, `*.telematik-test`) und sind nur über das DNS der TI
    auflösbar. Die Adressen im Beispiel oben sind Platzhalter. Die Hostnamen je
    Umgebung stehen auf der URL-Liste der gematik (siehe [Zuordnung zur
    URL-Liste der gematik](#zuordnung-zur-url-liste-der-gematik)).
    Maßgeblich ist jeweils die OCSP-URL in der AIA-Extension des tatsächlich
    eingesetzten Zertifikats.

## Warum nur IP-Blöcke — keine DNS-Namen (FQDN)

Standard-Kubernetes-`NetworkPolicy` (`networking.k8s.io/v1`) unterstützt
ausschließlich `ipBlock`-Peers (CIDR) — ein Abgleich des Egress über DNS-Namen /
FQDN ist nicht möglich. Das ist eine Limitierung der Kubernetes-API selbst, keine
Einschränkung von ZETA-Guard, und der Grund, warum Betreiber IP-Bereiche auflösen
und pflegen müssen.

FQDN-basierter Egress erfordert einen Mechanismus jenseits der reinen
NetworkPolicy, und jeder solche Mechanismus ist plattformabhängig:

| Mechanismus                                                     | Verfügbarkeit                                                            |
|-----------------------------------------------------------------|--------------------------------------------------------------------------|
| Istio `ServiceEntry` (+ `outboundTrafficPolicy: REGISTRY_ONLY`) | Erfordert Istio. Der in der gemAnbT vorgesehene Weg; folgt separat.      |
| OpenShift `EgressFirewall` (`k8s.ovn.org/v1`, `dnsName`)        | Nur OpenShift / OVN-Kubernetes. Anderer Ressourcentyp als NetworkPolicy. |
| Cilium `CiliumNetworkPolicy` `toFQDNs`                          | Erfordert die Cilium-CNI.                                                |

Da Anbieter unterschiedliche Plattformen und Service Meshes betreiben, liefert
ZETA-Guard keine universelle FQDN-Lösung. Entsprechend der gemAnbT stellt
ZETA-Guard die (Referenz-)NetworkPolicies bereit — perspektivisch die
Istio-Ressourcen; bei einem anderen Service Mesh portiert der Anbieter die
Policies.

## Anbieter-interner Verkehr

Für Egress zu anbieter-internen Zielen stehen zwei Optionen zur Verfügung:

**Option A — Spezifische IP-Blöcke** (empfohlen):

```yaml
networkPolicy:
  egress:
    providerInternal:
      resourceServers:
        ipBlocks:
          - "10.0.1.50/32"   # Ingresshostname → IP des Load Balancers
      telemetrySystems:
        ipBlocks:
          - "10.0.1.60/32"
```

IPs für `providerInternal` sind umgebungsspezifisch und unterscheiden sich je nach
Infrastruktur und Deployment-Ziel. Um zu vermeiden, dass Values-Dateien für jede
Umgebung angepasst werden müssen, empfiehlt sich die Übergabe zur Deployzeit:

```shell
helm upgrade --install ... \
  --set "networkPolicy.egress.providerInternal.resourceServers.ipBlocks[0]=<ip>/32"
```

> **Hinweis:** Ruft der PEP sein JWKS über den öffentlichen `pepIssuer` ab
> (Standard), muss hier zusätzlich die IP des Ingress hinterlegt werden. Ist
> `pepproxy.nginxConf.pepInternalUrl` gesetzt (ab Chart-Version 2.0.0), laufen
> Discovery und JWKS-Abruf über den Service `authserver` — ein Egress, den
> `pep-proxy-egress` ohnehin erlaubt. Für diesen Zweck wird der Eintrag dann
> nicht benötigt.

**Option B — Gesamten Egress erlauben** (nur für initiales Setup / Debugging):

```yaml
networkPolicy:
  egress:
    providerInternal:
      allowAll: true
```

## Egress-Bedarf je Pod

| Pod                 | Verwendete Egress-Kategorien                                                                                             |
|---------------------|--------------------------------------------------------------------------------------------------------------------------|
| `opa`               | `pip`, `artifactRegistry`, `providerArtifactRegistry`, `telemetry`, `siem`                                               |
| `opa-simulation`    | `pip`, `artifactRegistry`, `providerArtifactRegistry`                                                                    |
| `authserver`        | `telemetry`, `siem`, `ocspSmcbTsp`, `artifactRegistry`, `providerArtifactRegistry`                                       |
| `pep-proxy`         | `ocspCabForum`, `ocspSmcbTsp`, `ocspTiPki`, `popp`, `artifactRegistry`, `providerArtifactRegistry`, `providerInternal.*` |
| `telemetry-gateway` | `telemetry`, `siem`                                                                                                      |

Die Tabelle zeigt, welche Kategorien die NetworkPolicy des jeweiligen Pods
zulässt. Der `pep-proxy` braucht `ocspTiPki` nur bei aktivem ASL und
`ocspCabForum` nur, wenn er TLS selbst terminiert. `ocspSmcbTsp` nutzt er
derzeit nicht (siehe
[Wofür die drei OCSP-Kategorien stehen](#wofür-die-drei-ocsp-kategorien-stehen)).

> **Hinweis:** `authserver` und `pep-proxy` führen den `provisioning-processor` als
> Init-Container aus, der bei jedem Pod-Start ein signiertes OCI-Image zieht. Wird
> das Image in die Anbieter-interne Registry gespiegelt
> (`provisioningProcessor.provisioningContainer`), genügt `providerArtifactRegistry`.
> Das Spiegeln muss zwingend mit `cosign save`/`load` erfolgen, damit neben dem
> Image-Tag auch die zugehörigen Signatur-Artefakte (`.sig`-Tags) übertragen werden
> — siehe [Wie Sie eine eigene OCI-Registry verwenden](Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).
> Wird das Image direkt von der gematik-Registry bezogen, ist zusätzlich
> `artifactRegistry` erforderlich.

## Verwandte Dokumentation

- [Wie Sie ZETA-Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
- [Referenz des Helm-Charts](../Referenzen/Referenz_des_Helm_Charts.md)
