# SBOM der ZETA-Guard-Lieferung

Jedes veröffentlichte Chart-Tarball enthält eine Software Bill of Materials
(SBOM) im Format [CycloneDX 1.6](https://cyclonedx.org/) als `sbom.cdx.json`.
Sie listet die Container-Images, die das Chart ausbringt, mit Name, Tag,
Digest und Bezugsquelle. Das Chart `zeta-guard` liefert seine eigene SBOM; das
Umbrella-Chart `zeta-testenv` liefert eine SBOM, die zusätzlich die
Testkomponenten umfasst und die SBOM des Guards unter `charts/zeta-guard/`
enthält. Die Dateien werden in der Build-Pipeline aus dem gerenderten Chart
erzeugt und nicht von Hand gepflegt.

Die SBOM dient Betreibern als verbindliche Liste der zu einer Chart-Version
gehörenden Images, zum Beispiel für das Bereitstellen in einer eigenen
Registry oder den Abgleich mit einem laufenden Cluster.

## Zugriff

Die SBOM liegt neben der `Chart.yaml` im Tarball und wird nach dem Entpacken
gelesen:

```sh
helm pull oci://europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-helm/zeta-guard:{TAG} --untar
jq -r '.components[] | select(.type=="container") | .purl' \
    zeta-guard/sbom.cdx.json
```

## Aufbau

- `metadata.component`: das Chart selbst (`type: application`, `name`,
  `version` = Chart-Version).
- `components[]` mit `type: container`: ein Eintrag je Container-Image mit
  `name`, `version` (Tag; bei einem Pin ohne Tag der Digest), `purl` und
  `hashes` (SHA-256 des Manifests, auf das die Referenz zeigt).
- `components[]` mit `type: application`: ein Eintrag je Chart-Abhängigkeit
  (Sub-Chart) mit `name`, `version`, `group` (Chart-Repository) und
  `description` aus dem Sub-Chart sowie `externalReferences` mit der
  Bezugs-URL. Im Tarball gebündelte Sub-Charts haben weder `group` noch
  `externalReferences`.
- `dependencies[]`: die Zugehörigkeit. Das Chart hängt von seinen Images und
  Sub-Charts ab. In der Umbrella-SBOM hängen die Images des Guards unter dem
  Sub-Chart `zeta-guard`, nicht direkt unter der Wurzel.

`purl` folgt dem [package-url](https://github.com/package-url/purl-spec)-Typ
`oci`:

```text
pkg:oci/<name>@<digest>?repository_url=<Registry-Pfad>&tag=<tag>
```

Der Digest identifiziert das Image, der Registry-Pfad nennt die Bezugsquelle,
der Tag ist informativ.

## Properties

Angaben, für die CycloneDX kein Standardfeld vorsieht, stehen als `properties`
mit dem Präfix `zeta:`.

### `zeta:optional`

- An: Image, Sub-Chart
- Typ: `true` oder `false`
- Anzahl: genau 1
- Bedeutung: Die Komponente kann über Values abgeschaltet werden. Sie ist
  dennoch Teil der Lieferung; Betreiber dürfen eine Alternative einsetzen,
  nicht die Funktion weglassen.

### `zeta:k8s-workload`

- An: Image
- Typ: Text in der Form `Kind/Name`
- Anzahl: 1 oder mehr, eine Property je Workload
- Bedeutung: Kubernetes-Workload, dessen Pod-Spezifikation das Image nutzt.
  `Name` ist der gerenderte Ressourcenname; Sub-Charts, die ihm den
  Release-Namen voranstellen, zeigen den Release-Namen des Renderlaufs `sbom`
  (zum Beispiel `DaemonSet/sbom-nginx-ingress-controller`).

### `zeta:image`

- An: Image
- Typ: Text
- Anzahl: genau 1
- Bedeutung: Die Image-Referenz wörtlich wie im gerenderten Manifest, also
  das, was das Kubelet zieht und `kubectl get pods -o yaml` zeigt. Für den
  Abgleich mit einem laufenden Cluster; für alles andere `purl`.

### `zeta:kind`

- An: Image, Sub-Chart, Wurzel
- Typ: `oci-image` oder `helm-chart`
- Anzahl: genau 1
- Bedeutung: Art der Komponente. `type` allein reicht nicht, weil CycloneDX
  für Charts nur das generische `application` kennt.

### `zeta:alias`

- An: Sub-Chart
- Typ: Text
- Anzahl: 0 oder 1
- Bedeutung: Name, unter dem das Chart in den Values und Release-Ressourcen
  angesprochen wird (zum Beispiel `keycloak-db` für das CloudNativePG-Chart
  `cluster`).

## Hinweise

Zwei Images mit gleichem Namen, aber unterschiedlichem Inhalt (zum Beispiel
`notification-service` in den Varianten `-rs` und `-fdv`) werden nach dem
Workload benannt, der sie nutzt (`notification-service-rs`,
`notification-service-fdv`).

`bom-ref`-Werte (`img:<name>:<tag>`, `chart:<name>:<version>`) sind
dokumentinterne Kennungen für `dependencies`; ihr Format ist nicht Teil der
Schnittstelle.
