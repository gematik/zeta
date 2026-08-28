# Wie Sie Egress-NetworkPolicies konfigurieren

Das ZETA Guard Helm Chart beinhaltet optionale Kubernetes-`NetworkPolicy`-Ressourcen
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
- [IP-Blöcke konfigurieren](#ip-blöcke-konfigurieren)
  - [IP-Adressen ermitteln](#ip-adressen-ermitteln)
- [Warum nur IP-Blöcke — keine DNS-Namen (FQDN)](#warum-nur-ip-blöcke--keine-dns-namen-fqdn)
- [Anbieter-interner Verkehr](#anbieter-interner-verkehr)
- [Egress-Bedarf je Pod](#egress-bedarf-je-pod)
- [Verwandte Dokumentation](#verwandte-dokumentation)

## Aktivieren

```yaml
zeta-guard:
  networkPolicy:
    enabled: true   # Standard: false
```

Solange `enabled: false` (Standard), werden keine NetworkPolicy-Ressourcen erzeugt.

## DNS-Egress

Jede Egress-NetworkPolicy erlaubt die DNS-Auflösung. Der DNS-Peer ist über
`networkPolicy.dns` konfigurierbar und verweist standardmäßig auf den
kube-dns-Dienst von Upstream-Kubernetes / KIND:

```yaml
zeta-guard:
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
zeta-guard:
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

| Schlüssel                                  | Ziel                                                     |
|--------------------------------------------|----------------------------------------------------------|
| `egress.telemetry`                         | gematik Telemetriedaten-Empfänger (OTLP-Endpunkt)        |
| `egress.siem`                              | SIEM der gematik                                         |
| `egress.artifactRegistry`                  | ZETA Artifact Registry bei gematik (OPA-Bundles, Images) |
| `egress.providerArtifactRegistry`          | Anbieter-interne Artifact Registry                       |
| `egress.ocspCabForum`                      | OCSP/CRL für TLS-TSPs nach CAB Forum                     |
| `egress.ocspSmcbTsp`                       | SMC-B TSP OCSP-Responder                                 |
| `egress.ocspTiPki`                         | OCSP-Responder TSP Komponenten-PKI der TI                |
| `egress.pip`                               | PIP — Quelle der OPA Policy Bundles                      |
| `egress.popp`                              | PoPP-Dienst                                              |
| `egress.providerInternal.resourceServers`  | Anbieter-interne Resource Server                         |
| `egress.providerInternal.telemetrySystems` | Anbieter-internes Telemetrie-System                      |

## IP-Blöcke konfigurieren

```yaml
zeta-guard:
  networkPolicy:
    enabled: true
    egress:
      telemetry:
        ipBlocks:
          - "34.117.144.61/32"   # otlp.v1.bd.prod.ccs.gematik.solutions (PU)
      artifactRegistry:
        ipBlocks:
          - "34.90.0.0/16"       # europe-west3-docker.pkg.dev (Google Artifact Registry)
      ocspSmcbTsp:
        ipBlocks:
          - "104.247.81.99/32"   # ocsp.telematik.de
      ocspTiPki:
        ipBlocks:
          - "104.247.81.99/32"   # ocsp.ti.telematik.de
      ocspCabForum:
        ipBlocks:
          - "193.28.71.48/32"    # ocsp.d-trust.net
          - "62.96.224.138/32"   # crl.d-trust.net
```

### IP-Adressen ermitteln

- **gematik-Endpunkte** (telemetry, SIEM, PoPP): `dig +short <hostname>`
- **Google Artifact Registry**: veröffentlichte Edge-Bereiche von Google unter
  <https://www.gstatic.com/ipranges/goog.json>. Die   Freigabe muss sowohl
  `europe-west3-docker.pkg.dev` (Image-Manifest) als auch `storage.googleapis.com`
  (Layer-Blobs) umfassen — siehe Stabilitätshinweis unten
- **OCSP-Responder**: aus der AIA-Extension des jeweiligen Zertifikats:
  `openssl x509 -in <cert.pem> -text | grep -A2 "OCSP"` → `dig +short <ocsp-host>`

> **Stabilitätshinweise:**
> - `artifactRegistry` wird über Google CDN/Anycast ausgeliefert, daher ist eine
    einzelne `/32`-Adresse unzuverlässig — die aufgelöste IP unterscheidet sich je
    nach Standort (z. B. `142.251.x` aus einem Netz, `74.125.x` aus einem anderen),
    und Layer-Blobs kommen von `storage.googleapis.com` auf weiteren IPs. Geben Sie
    Googles veröffentlichte Edge-Bereiche aus
    <https://www.gstatic.com/ipranges/goog.json> frei. Bestätigt für beide Hosts
    (2026-07): `74.125.0.0/16`, `142.250.0.0/15`, `192.178.0.0/15`,
    `172.217.0.0/16`, `216.58.192.0/19`, `209.85.128.0/17`. Vor dem Einsatz erneut
    gegen `goog.json` prüfen.
> - `ocspSmcbTsp` (`ocsp.telematik.de`) und `ocspTiPki` (`ocsp.ti.telematik.de`)
    lösen derzeit auf dieselbe IP auf und sind nur innerhalb des TI-Netzes
    auflösbar — dies sind jedoch separate Dienste, deren Adressen sich unabhängig
    voneinander ändern können. Die maßgebliche Adresse ist jeweils die in der
    AIA-Extension des tatsächlich eingesetzten Zertifikats eingebettete OCSP-URL.

## Warum nur IP-Blöcke — keine DNS-Namen (FQDN)

Standard-Kubernetes-`NetworkPolicy` (`networking.k8s.io/v1`) unterstützt
ausschließlich `ipBlock`-Peers (CIDR) — ein Abgleich des Egress über DNS-Namen /
FQDN ist nicht möglich. Das ist eine Limitierung der Kubernetes-API selbst, keine
Einschränkung von ZETA Guard, und der Grund, warum Betreiber IP-Bereiche auflösen
und pflegen müssen.

FQDN-basierter Egress erfordert einen Mechanismus jenseits der reinen
NetworkPolicy, und jeder solche Mechanismus ist plattformabhängig:

| Mechanismus                                                     | Verfügbarkeit                                                              |
|-----------------------------------------------------------------|----------------------------------------------------------------------------|
| Istio `ServiceEntry` (+ `outboundTrafficPolicy: REGISTRY_ONLY`) | Erfordert Istio. Der in der gemAnbT vorgesehene Weg; folgt separat.        |
| OpenShift `EgressFirewall` (`k8s.ovn.org/v1`, `dnsName`)        | Nur OpenShift / OVN-Kubernetes. Anderer Ressourcentyp als NetworkPolicy.   |
| Cilium `CiliumNetworkPolicy` `toFQDNs`                          | Erfordert die Cilium-CNI.                                                  |

Da Anbieter unterschiedliche Plattformen und Service Meshes betreiben, liefert
ZETA Guard keine universelle FQDN-Lösung. Entsprechend der gemAnbT stellt ZETA
Guard die (Referenz-)NetworkPolicies bereit — perspektivisch die
Istio-Ressourcen; bei einem anderen Service Mesh portiert der Anbieter die
Policies.

## Anbieter-interner Verkehr

Für Egress zu anbieter-internen Zielen stehen zwei Optionen zur Verfügung:

**Option A — Spezifische IP-Blöcke** (empfohlen):

```yaml
zeta-guard:
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
  --set "zeta-guard.networkPolicy.egress.providerInternal.resourceServers.ipBlocks[0]=<ip>/32"
```

**Option B — Gesamten Egress erlauben** (nur für initiales Setup / Debugging):

```yaml
zeta-guard:
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

> **Hinweis:** `authserver` und `pep-proxy` führen den `provisioning-processor` als
> Init-Container aus, der bei jedem Pod-Start ein signiertes OCI-Image zieht. Wird
> das Image in die Anbieter-interne Registry gespiegelt
> (`provisioningProcessor.provisioningContainer`), genügt `providerArtifactRegistry`.
> Das Spiegeln muss zwingend mit `cosign save`/`load` erfolgen, damit neben dem
> Image-Tag auch die zugehörigen Signatur-Artefakte (`.sig`-Tags) übertragen werden
> — siehe [Wie Sie eine eigene OCI Registry verwenden](Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).
> Wird das Image direkt von der gematik-Registry bezogen, ist zusätzlich
> `artifactRegistry` erforderlich.

## Verwandte Dokumentation

- [Wie Sie ZETA Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
- [Referenz des Helm Charts](../Referenzen/Referenz_des_Helm_Charts.md)
