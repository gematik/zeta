# Wie Sie Egress-NetworkPolicies konfigurieren

Das ZETA Guard Helm Chart beinhaltet optionale Kubernetes-`NetworkPolicy`-Ressourcen
(ausgehend/Egress), die den ausgehenden Netzwerkverkehr jedes ZETA-Guard-Pods auf
explizit freigegebene Ziel-IP-Blöcke beschränken.

Interner Cluster-Verkehr (DNS, Pod-zu-Pod-Kommunikation zwischen OPA, Datenbank,
Telemetry-Gateway) ist immer erlaubt und muss nicht gesondert konfiguriert werden.

## Inhaltsverzeichnis

- [Aktivieren](#aktivieren)
- [Konfigurierbare Egress-Kategorien](#konfigurierbare-egress-kategorien)
- [IP-Blöcke konfigurieren](#ip-blöcke-konfigurieren)
  - [IP-Adressen ermitteln](#ip-adressen-ermitteln)
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
- **Google Artifact Registry**: veröffentlichte CIDR-Bereiche unter
  <https://www.gstatic.com/ipranges/cloud.json> (Filter: `europe-west3`),
  siehe Stabilitätshinweis unten
- **OCSP-Responder**: aus der AIA-Extension des jeweiligen Zertifikats:
  `openssl x509 -in <cert.pem> -text | grep -A2 "OCSP"` → `dig +short <ocsp-host>`

> **Stabilitätshinweise:**
> - `artifactRegistry` (`europe-west3-docker.pkg.dev`) wird über Google CDN/Anycast
>   ausgeliefert. Die per DNS aufgelöste IP kann sich ohne Ankündigung ändern. Für
>   Produktivumgebungen empfehlen sich die veröffentlichten CIDR-Bereiche statt
>   einzelner `/32`-Adressen.
> - `ocspSmcbTsp` (`ocsp.telematik.de`) und `ocspTiPki` (`ocsp.ti.telematik.de`)
>   lösen derzeit auf dieselbe IP auf — dies sind jedoch separate Dienste, deren
>   Adressen sich unabhängig voneinander ändern können. Die maßgebliche Adresse
>   ist jeweils die in der AIA-Extension des tatsächlich eingesetzten Zertifikats
>   eingebettete OCSP-URL.

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
