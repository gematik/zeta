# Wie Sie OPA in ZETA Guard konfigurieren

Diese Anleitung erklärt kurz, wie OPA in ZETA Guard eingebunden ist und wie Sie
den Bezug der Policy‑Bundles konfigurieren. Die Policies stammen immer aus dem
**PIP** (Policy Information Point) der gematik und werden als signierte
OCI‑Bundles bereitgestellt. Für den Zugriff auf die Bundles gibt es zwei
Varianten:

- Direktzugriff auf die gematik‑Registry per Workload Identity Federation (WIF)
- Zugriff über eine eigene Registry als Pull‑Through‑Proxy (SecretRef, Basic)

Die Anleitung enthält zudem Hinweise zur Signaturprüfung der Bundles,
Schema‑Validierungen, Verifikation/Tests und Troubleshooting.

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Aktivieren](#aktivieren)
- [Geplanter Neustart (Rollout-Restart)](#geplanter-neustart-rollout-restart)
- [Policy-Quelle: PIP (OCI-Bundle)](#policy-quelle-pip-oci-bundle)
- [Zugriffsvariante A: Direktzugriff per Workload Identity Federation (WIF)](#zugriffsvariante-a-direktzugriff-per-workload-identity-federation-wif)
- [Zugriffsvariante B: Eigene Registry als Pull-Through-Proxy](#zugriffsvariante-b-eigene-registry-als-pull-through-proxy)
- [Signaturprüfung (Bundles)](#signaturprüfung-bundles)
- [Fehlgeschlagene Bundle-Downloads sichtbar machen](#fehlgeschlagene-bundle-downloads-sichtbar-machen)
- [Schema-Validierungen](#schema-validierungen)
- [Verifikation und Tests](#verifikation-und-tests)
- [Troubleshooting](#troubleshooting)

## Überblick

- OPA läuft im zeta‑guard Helm‑Chart als aktive Instanz (`opa`) und
  Simulations‑Instanz (`opa-simulation`) und wird beim Ausstellen von Tokens
  durch Authserver (PDP) konsultiert.
- OPA ist **verpflichtend** und kann nicht deaktiviert werden. Die früheren
  Toggles `opa.enabled`, `provider.smcB.opa.enabled` und
  `provider.smcB.failClosed` wurden entfernt; in bestehenden Override-Dateien
  werden sie nach dem Upgrade still ignoriert. Ist OPA nicht erreichbar,
  antwortet der Authserver mit HTTP 503 (Service Unavailable) und dem Fehlercode
  `temporarily_unavailable`, statt ohne Policy-Entscheidung ein Token
  auszustellen.
- Policy und Daten werden als **signiertes OCI‑Bundle** aus dem PIP geladen und
  in einem konfigurierbaren Intervall auf Aktualisierungen geprüft
  (`opa.bundle.polling.min_delay_seconds` / `max_delay_seconds`, Standard:
  jeweils 60 Sekunden).
- Entscheidungspfad: Aufrufer nutzen
  `POST /v1/data/policies/zeta/authz/decision` mit `{ "input": { ... } }` und
  erhalten `{ allow, ttl }` zurück.

## Aktivieren

- Bundle‑Modus: `opa.bundle.enabled: true` (Registry + Zugriffsvariante
  konfigurieren, siehe unten). Der Wert muss im Betrieb `true` bleiben — der im
  Chart vorhandene Inline‑Fallback (`opaPolicy.policyRego`, greift nur bei
  `opa.bundle.enabled: false`) ist ausschließlich für Testinstallationen
  gedacht und für den Betrieb nicht zulässig.
- Simulation ist standardmäßig aktiv: `opa.simulation.enabled: true`; Anzahl
  der Replicas über `opa.simulation.replicaCount` (Standard: 1).
- Die Simulations‑Instanz kann ein eigenes Bundle nutzen:
  `opa.simulation.bundle.resource`; sonst wird automatisch
  `<opa.bundle.resource>-sim` verwendet (Suffix am Tag, z. B.
  `…:latest` → `…:latest-sim`).
- Die Simulations‑Instanz kann eine eigene Signaturprüfung verwenden:
  `opa.simulation.bundle.verification` (gleiche Felder wie
  `opa.bundle.verification`; leer = die gemeinsame Konfiguration gilt).

## Geplanter Neustart (Rollout-Restart)

Verfügbar ab zeta-guard-helm-Chart-Version **1.3.0**.

OPA lädt seine Trust-Anchors (SMB-/TPM-/OCSP-Truststores, Policy-Signer-Zertifikat)
einmalig über einen initContainer aus dem Provisioning-Container. Ändern sich diese
Daten (z. B. TSL-Update, widerrufene CAs, rotierter Policy-Signer), übernimmt OPA
das erst mit dem nächsten Pod-Neustart. Ein periodischer, geplanter Neustart hält
die Daten daher aktuell.

- OPA (und, falls aktiviert, `opa-simulation`) kann nach einem konfigurierbaren
  Zeitplan automatisch neu gestartet werden — standardmäßig **deaktiviert**.
- ServiceAccount und RBAC werden bei Aktivierung standardmäßig vom Chart
  selbst angelegt; es ist keine externe Vorbereitung nötig.
- Der Neustart erfolgt über einen CronJob (`kubectl rollout restart`).

Werte (Beispiel):

```yaml
opa:
    rolloutRestart:
        enabled: true
        schedule: "0 3 * * *"   # Standard: täglich 3 Uhr, Europe/Berlin
        backoffLimit: 5         # Standard
        resources:              # Standard
            limits:
                memory: "64Mi"
            requests:
                cpu: "10m"
                memory: "32Mi"
```

Wichtige Details:

- Die Zeitzone ist fest auf `Europe/Berlin` gesetzt (`spec.timeZone` im
  CronJob), unabhängig von der Standardzeitzone des Clusters.
- Alternativ kann ein bereits vorhandener ServiceAccount genutzt werden:
  `opa.rolloutRestart.serviceAccountName: <name>`. Ist dieser Wert gesetzt,
  legt der Chart weder ServiceAccount noch RBAC selbst an — der angegebene
  ServiceAccount muss dann bereits über die nötigen Rechte (`get`/`patch` auf
  das `opa`‑/`opa-simulation`‑Deployment) verfügen.
- Bei aktivierten Egress-NetworkPolicies (`networkPolicy.enabled: true`)
  braucht der CronJob keine eigene NetworkPolicy: Er nutzt dieselben
  Pod-Labels wie `opa` und fällt damit automatisch unter die
  `opa-egress`-NetworkPolicy.
- Der CronJob-Container verwendet `provisioningProcessor.image` — dieses Image
  enthält `kubectl` — samt `provisioningProcessor.containerSecurityContext`,
  statt eines separaten, generischen CI-Tooling-Images.
- Ein Rollout-Neustart ist kein unterbrechungsfreier Reload. Bei
  `replicaCount: 1` ist OPA für die Dauer des Pod-Starts nicht verfügbar, und
  die Policy-Entscheidung ist fail-closed: der Authserver lehnt Token-Exchanges
  in diesem Fenster mit HTTP 503 `temporarily_unavailable` ab. Für den
  Produktivbetrieb daher entweder mehr als eine Replica vorsehen oder eine
  Uhrzeit mit geringer Last wählen.

Einen Lauf sofort auslösen, ohne auf den Zeitplan zu warten:

```bash
kubectl -n <namespace> create job --from=cronjob/opa-rollout-restart-cronjob opa-rollout-restart-test
```

```
deployment.apps/opa restarted
deployment.apps/opa-simulation restarted
```

## Policy-Quelle: PIP (OCI-Bundle)

Der PIP stellt die Policy‑Bundles und die zugehörigen Bundle‑Signer‑Zertifikate
bereit (siehe
[Wie Sie ZETA Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)).
Es gibt genau diese eine Policy‑Quelle; eigene oder fest verdrahtete Policies
sind nicht vorgesehen.

Gemeinsame Konfiguration (unabhängig von der Zugriffsvariante):

```yaml
opa:
    bundle:
        enabled: true
        serviceName: pip
        url: https://<registry-host>
        resource: <registry-host>/<pfad>/<bundle>:latest
        verification:
            enabled: true
            keyId: signer
```

Die Beispiele in dieser Anleitung zeigen Values des zeta-guard-Charts. Wird der
Chart als Subchart eines übergeordneten Charts eingebunden, sind die Values
unter dessen Alias (z.B. `zeta-guard:`) zu verschachteln.

Der öffentliche Schlüssel für die Signaturprüfung wird **nicht** über Helm
Values gepflegt — er wird vom Provisioning‑Daten‑Image bereitgestellt
(siehe [Signaturprüfung](#signaturprüfung-bundles)).

## Zugriffsvariante A: Direktzugriff per Workload Identity Federation (WIF)

WIF ermöglicht den Zugriff auf die gematik‑Registry (Google Artifact Registry)
ohne statische Zugangsdaten. Ein CronJob tauscht das JWT des
Kubernetes‑ServiceAccounts beim Google STS ein und ruft damit im Namen des
Ziel‑Google‑Service‑Accounts (`sts.sa`, Impersonation) einen kurzlebigen Access
Token ab. Dieser wird als Datei in ein Kubernetes‑Secret geschrieben; OPA liest
ihn von dort.

Wichtige Details:

- Dateiinhalt muss exakt `oauth2accesstoken:<ACCESS_TOKEN>` sein.
- OPA nutzt `credentials.bearer.scheme: "Basic"` und
  `token_path: /var/run/secrets/gcp/token`.
- Secret/SA/RBAC/CronJob werden vom Chart gerendert.
- Die STS‑Audience baut das Chart aus den drei Werten unter
  `gematik.workloadIdentityFederation` zusammen
  (`//iam.googleapis.com/projects/<PROJECT_NUM>/locations/global/workloadIdentityPools/<pool>/providers/<provider>`).
  Die Google‑Endpunkte (STS, IAM Credentials) und der Scope
  `cloud-platform` sind fest im CronJob hinterlegt und nicht konfigurierbar.

Alle vier Werte — Projektnummer, Pool, Provider und der zu impersonierende
Google‑Service‑Account — erhalten Sie im Rahmen des
[ZETA‑Onboardings bei der gematik](https://wiki.gematik.de/spaces/TI2AUSTAUSCH/pages/729779095/ZETA+Onboarding)
(Zugang ggf. login‑pflichtig; alternativ über Ihren gematik‑Ansprechpartner).
Dort erfahren Sie auch Registry‑Host und Bundle‑Pfad (`resource`) des PIP.

Werte (Beispiel):

```yaml
gematik:
    workloadIdentityFederation:
        projectNumber: "<PROJECT_NUM>"
        poolId: "<pool>"
        workloadIdentityProvider: "<provider>"
opa:
    serviceAccountName: opa
    bundle:
        enabled: true
        serviceName: <gar-service-name>
        url: https://<region>-docker.pkg.dev
        resource: <region>-docker.pkg.dev/<PROJECT>/<REPO>/<IMAGE>:latest
        credentials:
            secretRef:
                name: ""   # kein Basic im workloadIdentityFederation‑Modus
        verification:
            enabled: true
            keyId: signer
            algorithm: ES256
    workloadIdentityFederation:
        enabled: true
        sts:
            sa: "<gsa>@<project>.iam.gserviceaccount.com"
        tokenRenewer:
            schedule: "*/45 * * * *"
```

> **`resource` immer per Tag referenzieren (z. B. `:latest`), nicht per
> Digest.** Ein Digest‑Pin (`@sha256:…`) friert den Policy‑Stand ein und
> widerspricht dem Update‑Polling; außerdem leitet das Chart daraus die
> Simulations‑Referenz per Suffix ab — aus `@sha256:…` würde die ungültige
> Referenz `@sha256:…-sim`.

## Zugriffsvariante B: Eigene Registry als Pull-Through-Proxy

Wichtige Randbedingungen:

- Die Registry muss als **Pull‑Through‑Cache** arbeiten, nicht als statischer
  Spiegel: OPA prüft das Bundle im Polling‑Intervall auf Aktualisierungen. Eine
  manuell kopierte Bundle‑Version friert den Policy‑Stand ein —
  Policy‑Änderungen der gematik kämen nicht mehr an.
- Die [Signaturprüfung](#signaturprüfung-bundles) bleibt aktiviert. Die
  Signaturen sind Bestandteil des Bundle‑Artefakts und bleiben beim Proxying
  unverändert erhalten.
- Auch das Simulations‑Bundle (`<resource>-sim`) muss über den Proxy erreichbar
  sein.
- Verwendet die Registry ein TLS‑Zertifikat einer eigenen, nicht öffentlich
  vertrauenswürdigen CA, wird diese über
  `provisioningProcessor.provisioningContainerCaSecretRef` (alternativ
  `...CaConfigMapRef`) bereitgestellt — dieselbe Referenz, die auch der
  Init‑Container für das Provisioning‑Daten‑Image nutzt. OPA **ergänzt** die CA
  um den System‑Truststore des Images, die Datei muss für OPA also nur die
  eigene CA enthalten. Details und die Anforderung an die Datei, wenn beide
  Registries verschieden vertrauenswürdig sind, siehe
  [Wie Sie eine eigene OCI Registry verwenden](Wie_Sie_eine_eigene_OCI_Registry_verwenden.md).
- Bei aktivierten Egress‑NetworkPolicies zeigt
  `networkPolicy.egress.pip.ipBlocks` dann auf den Proxy statt auf die
  gematik‑Registry (siehe
  [Wie Sie Egress-NetworkPolicies konfigurieren](Wie_Sie_Egress_NetworkPolicies_konfigurieren.md)).

Erfordert die Registry eine Authentifizierung (Basic), werden die Zugangsdaten
(`USERNAME:PASSWORD`) in einem Kubernetes‑Secret unter dem Key `token` abgelegt
und über `credentials.secretRef` referenziert:

```bash
kubectl -n <namespace> create secret generic opa-bearer \
  --from-literal=token='USERNAME:PASSWORD'
```

Werte (Beispiel):

```yaml
opa:
    bundle:
        enabled: true
        serviceName: pip
        url: https://my.registry.corp.internal:443
        resource: my.registry.corp.internal/<proxy-pfad>/<bundle>:latest
        credentials:
            secretRef:
                name: opa-bearer
        verification:
            enabled: true
            keyId: signer
```

Erlaubt die Registry anonymen Lesezugriff, bleibt `credentials.secretRef.name`
leer.

## Signaturprüfung (Bundles)

- `opa.bundle.verification.enabled` ist im Chart standardmäßig `true` — **wirksam
  wird die Prüfung aber erst, wenn zusätzlich `verification.keyId` gesetzt ist**.
  Der Chart‑Standard für `keyId` ist leer; ohne `keyId` rendert das Chart keinen
  `signing:`‑Block in die OPA‑Konfiguration, und OPA prüft nichts. Setzen Sie
  `keyId: signer` (der Schlüsselname, unter dem das Provisioning‑Daten‑Image den
  Signer‑Schlüssel bereitstellt) daher immer explizit. Mit gesetztem `keyId`
  lehnt OPA Bundles ohne gültige Signatur ab; die Prüfung muss aktiviert bleiben.
- Der öffentliche Schlüssel wird vom Provisioning‑Daten‑Image als Trust‑Anchor
  bereitgestellt und beim Pod‑Start eingebunden; er wird nicht über Helm Values
  konfiguriert.
- Registry‑agnostisch: Die Signaturprüfung funktioniert mit jeder OCI‑Registry —
  auch über einen Pull‑Through‑Proxy. Entscheidend ist, dass das Bundle signiert
  ist und der passende Trust‑Anchor vorliegt.
- `verification.scope` (optional): Wenn das Bundle beim Signieren mit einem
  Scope versehen wurde, muss dieser Wert hier exakt übereinstimmen (z. B.
  `read`). Andernfalls meldet OPA einen „scope mismatch"-Fehler. Wenn das Bundle
  ohne Scope signiert wurde, dieses Feld leer lassen (Standard) — dann prüft OPA
  den Scope nicht.

## Fehlgeschlagene Bundle-Downloads sichtbar machen

Standardmäßig bleibt der OPA‑Pod `Running` und meldet `Ready`, auch wenn kein
Bundle geladen werden konnte. Der Zustand ist nur an drei Stellen erkennbar, von
denen keine im Pod‑Status auftaucht:

- der Logzeile `Bundle load failed` im Konsolen‑Log des OPA‑Pods,
- den Status‑Updates von OPA, die den Bundle‑Status samt Fehler enthalten. Diese
  gehen standardmäßig **nicht** ins Konsolen‑Log (`opa.logStatusUpdates`, Standard
  `false`), sondern nur an das Telemetry‑Gateway,
- den Status‑Metriken, sofern `opaStatusPrometheus: true` gesetzt ist.

Wer nicht gezielt auf Logs oder Telemetrie schaut, übersieht einen
Konfigurations‑ oder Netzwerkfehler daher leicht.

`opa.bundleHealthCheck: true` (Standard: `false`) stellt die Readiness‑Probe auf
`/health?bundles=true` um: Der Pod wird erst `Ready`, wenn ein Bundle
heruntergeladen und aktiviert wurde. Die Liveness‑Probe bleibt auf `/health` —
eine nicht erreichbare Registry darf den Pod nicht in einen CrashLoop treiben.

```yaml
zeta-guard:
    opa:
        bundleHealthCheck: true
```

Abwägung für den Betrieb:

- Bei einem **Rolling Update** bleibt der bisherige Pod aktiv und der Rollout
  bleibt stehen. Eine fehlerhafte Bundle‑Konfiguration kann eine funktionierende
  OPA‑Instanz also nicht ersetzen.
- Ein **neu eingeplanter** Pod (Node‑Drain, Neustart, Hochskalieren) bleibt
  dagegen `NotReady`, solange die Registry nicht erreichbar ist. Bei
  `replicaCount: 1` ist OPA damit außer Betrieb.
- Die Policy‑Entscheidung ist ohnehin **fail‑closed**: Fehlt das Bundle,
  antwortet OPA auf Anfragen ohne Ergebnisfeld, und der Authserver lehnt den
  Token‑Exchange mit HTTP 503 `temporarily_unavailable` ab. Das gilt mit und
  ohne diese Option — es werden in keinem Fall Tokens ohne Policy‑Prüfung
  ausgestellt. Die Option ändert daher nichts am Sicherheitsverhalten, sie macht
  den Fehlerzustand nur in `kubectl get pods` sichtbar statt nur im OPA‑Log.

## Schema-Validierungen

- `opa.bundle.enabled=true` → `serviceName` und `resource` sind erforderlich (
  nicht leer).
- `opa.workloadIdentityFederation.enabled=true` →
  `opa.bundle.credentials.secretRef.name` darf nicht gesetzt sein (
  workloadIdentityFederation und Basic sind exklusiv).

## Verifikation und Tests

- Rendern prüfen: `helm template` mit Ihren Values.
- OPA‑Status/Logs:
    - Port‑Forward: `kubectl -n <ns> port-forward svc/opa 8181:http`
    - Bundle‑Status:
      `curl -sS http://localhost:8181/v1/status | jq '.result.bundles["authz"]'`
    - Entscheidungen:
      `curl --json '{"input":{}}' http://localhost:8181/v1/data/policies/zeta/authz/decision`
- workloadIdentityFederation‑Token prüfen:
  ```bash
  kubectl -n <ns> get secret opa-gcp-token -o jsonpath='{.data.token}' | base64 -d | sed -n '1p'
  # Erwartet: Zeile beginnt mit "oauth2accesstoken:"
  ```
- Einmalige Token‑Erneuerung sofort auslösen, statt auf den Zeitplan zu warten
  (nur Zugriffsvariante A "Direktzugriff per Workload Identity Federation"):
  ```bash
  kubectl -n <ns> create job token-renewer-once --from=cronjob/opa-token-renewer-cronjob
  ```
- Rollout‑Restart manuell auslösen, statt auf den Zeitplan zu warten:
  ```bash
  kubectl -n <ns> create job --from=cronjob/opa-rollout-restart-cronjob opa-rollout-restart-test
  ```

## Troubleshooting

- 401/403 beim Laden des Bundles:
    - SecretRef/Basic: Secret fehlt/falsch, oder der Pull‑Through‑Proxy hat
      selbst keinen Zugriff auf die Upstream‑Registry.
    - workloadIdentityFederation: Secret enthält nicht das GAR‑kompatible
      Format (`oauth2accesstoken:`‑Präfix) oder Token ist abgelaufen.
- Bundle wird geladen, aber Policy‑Änderungen kommen nicht an: Registry arbeitet
  als statischer Spiegel statt als Pull‑Through‑Cache — Proxy‑Konfiguration
  prüfen.
- `x509: certificate signed by unknown authority` beim Laden des Bundles: Das
  Zertifikat der Registry stammt von einer nicht öffentlich vertrauenswürdigen
  CA, die OPA nicht kennt. CA über
  `provisioningProcessor.provisioningContainerCaSecretRef` bereitstellen (siehe
  [Zugriffsvariante B](#zugriffsvariante-b-eigene-registry-als-pull-through-proxy)).
  Der Pod bleibt dabei `Running` und meldet `Ready`; mit
  [`opa.bundleHealthCheck`](#fehlgeschlagene-bundle-downloads-sichtbar-machen)
  wird der Zustand sichtbar.
- Init‑Container `trust-anchor-provisioning-processor` bricht auf Authserver, OPA
  **und** OPA‑Simulation mit
  `Error: signed entity: … x509: certificate signed by unknown authority` ab,
  nachdem eine Registry‑CA hinterlegt wurde: Der Init‑Container übergibt die
  Datei an `cosign` als **einzigen** Trust‑Anchor — anders als OPA, das sie
  ergänzt. Enthält sie nur die interne CA, während das Provisioning‑Daten‑Image
  aus einer öffentlich vertrauenswürdigen Registry kommt, schlägt dessen Abruf
  fehl. Abhilfe: vollständiges CA‑Bundle hinterlegen oder das
  Provisioning‑Daten‑Image in dieselbe private Registry spiegeln (siehe
  [Wie Sie eine eigene OCI Registry verwenden](Wie_Sie_eine_eigene_OCI_Registry_verwenden.md)).
- OPA Status‑Plugin 404/502 gegen Registry sind unkritisch; ggf.
  `opaStatusPrometheus: false`.
- Validierungsfehler beim Helm‑Rendern: Schema‑Fehlerhinweise beachten
  (erforderliche Felder, Exklusivität workloadIdentityFederation/SecretRef).
