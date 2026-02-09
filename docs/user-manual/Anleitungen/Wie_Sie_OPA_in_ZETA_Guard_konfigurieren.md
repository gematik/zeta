# Wie Sie OPA in ZETA Guard konfigurieren

Diese Anleitung erklärt kurz, wie OPA in ZETA Guard eingebunden ist, wie Sie OPA aktivieren und welche Policy‑Quellen unterstützt werden:

- Eingebettete, fest verdrahtete Policy (policyRego)
- OCI‑Bundle aus privater Registry per SecretRef (z. B. GitLab Deploy‑Token)
- OCI‑Bundle aus Google Artifact Registry per Workload Identity Federation (WIF)

Die Anleitung enthält zudem Hinweise zur Signaturprüfung der Bundles, Schema‑Validierungen, Verifikation/Tests und Troubleshooting.

## Überblick

- OPA läuft als Deployment im zeta‑guard Helm‑Chart und wird beim Ausstellen von Tokens durch Authserver (PDP) konsultiert.
- Zwei Betriebsarten:
  - Inline‑Policy: Rego‑Policy wird als ConfigMap gemountet (Standard, einfache Demo/Tests).
  - Bundle‑Modus: Policy+Data werden als OCI‑Bundle aus einer Registry geladen.
- Entscheidungspfad: Aufrufer nutzen `POST /v1/data/zeta/authz/decision` mit `{ "input": { ... } }` und erhalten `{ allow, ttl }` zurück.

## Aktivieren

- Inline‑Policy (Standard): `zeta-guard.opa.bundle.enabled: false`
- Bundle‑Modus: `zeta-guard.opa.bundle.enabled: true` (Registry + Auth konfigurieren)

## Policy‑Quellen

### 1) Fest verdrahtete Policy (policyRego)

Werte (Beispiel):

```yaml
zeta-guard:
  opa:
    bundle:
      enabled: false
  opaPolicy:
    policyRego: |
      package zeta.authz

      # Beispiel: erlauben mit TTL
      decision := {
        "allow": true,
        "ttl": { "access_token": 300, "refresh_token": 86400 }
      }
```

### 2) Bundle aus GitLab (SecretRef, Basic)

Voraussetzung: Secret im Namespace mit Basic‑Credentials (Deploy‑Token o. ä.):

```bash
kubectl -n <namespace> create secret generic opa-bearer \
  --from-literal=token='USERNAME:PASSWORD' \
  --from-literal=scheme='Basic'
```

Werte (Beispiel):

```yaml
zeta-guard:
  opa:
    bundle:
      enabled: true
      serviceName: gitlab
      url: https://registry.example.com:443
      resource: registry.example.com/group/project/pip-pap:latest
      credentials:
        secretRef:
          name: opa-bearer
      verification:
        enabled: false
```

### 3) Bundle aus Google Artifact Registry (workloadIdentityFederation)

workloadIdentityFederation ohne statische Token. Ein CronJob nimmt das KSA‑JWT, tauscht es beim STS und impersoniert die Ziel‑GSA. Der resultierende Access Token wird als Datei in ein Secret geschrieben; OPA liest ihn von dort.

Wichtige Details:
- Dateiinhalt muss exakt `oauth2accesstoken:<ACCESS_TOKEN>` sein.
- OPA nutzt `credentials.bearer.scheme: "Basic"` und `token_path: /var/run/secrets/gcp/token`.
- Secret/SA/RBAC/CronJob werden vom Chart gerendert.

Werte (Beispiel):

```yaml
zeta-guard:
  opa:
    serviceAccountName: opa
    bundle:
      enabled: true
      serviceName: <gar-service-name>
      url: https://<region>-docker.pkg.dev
      resource: <region>-docker.pkg.dev/<PROJECT>/<REPO>/<IMAGE>:<TAG>
      credentials:
        secretRef:
          name: ""   # kein Basic in workloadIdentityFederation‑Modus
      verification:
        enabled: true
        keyId: <KEY_ID>
        algorithm: ES256
        publicKey: |
          -----BEGIN PUBLIC KEY-----
          ...
          -----END PUBLIC KEY-----
    workloadIdentityFederation:
      enabled: true
      sts:
        audience: "//iam.googleapis.com/projects/<PROJECT_NUM>/locations/global/workloadIdentityPools/<pool>/providers/<provider>"
        tokenUrl: https://sts.googleapis.com/v1/token
        iamUrl: https://iamcredentials.googleapis.com
        sa: "<gsa>@<project>.iam.gserviceaccount.com"
        scope: "https://www.googleapis.com/auth/cloud-platform"
      tokenRenewer:
        schedule: "*/45 * * * *"
```

## Signaturprüfung (Bundles)

- Standardmäßig aktiviert im Chart: `zeta-guard.opa.bundle.verification.enabled: true`.
- Registry‑agnostisch: Signaturprüfung funktioniert mit jeder OCI‑Registry (z. B. GitLab, GAR). Entscheidend ist, dass das Bundle signiert ist und OPA den passenden Public Key kennt.
- Wenn aktiviert, verlangt das Schema `verification.keyId` und `verification.publicKey` (PEM). Ohne passende Signatur schlägt OPA fehl.
- Empfehlung:
  - Verifikation aktiviert lassen (Default). Wenn das Bundle (noch) nicht signiert ist, entweder Signatur + Schlüssel konfigurieren oder vorübergehend `verification.enabled: false` setzen.

## Schema‑Validierungen

- `opa.bundle.enabled=true` → `serviceName` und `resource` sind erforderlich (nicht leer).
- `opa.workloadIdentityFederation.enabled=true` → `opa.bundle.credentials.secretRef.name` darf nicht gesetzt sein (workloadIdentityFederation und Basic sind exklusiv).
- `opa.bundle.verification.enabled=true` → `verification.keyId` und `verification.publicKey` sind erforderlich.

## Verifikation und Tests

- Rendern prüfen: `helm template` mit Ihren Values.
- OPA‑Status/Logs:
  - Port‑Forward: `kubectl -n <ns> port-forward svc/opa 8181:8181`
  - Bundle‑Status: `curl -sS http://localhost:8181/status | jq .`
  - Entscheidungen: `curl -sS -H 'Content-Type: application/json' -d '{"input":{}}' http://localhost:8181/v1/data/zeta/authz/decision`
- workloadIdentityFederation‑Token prüfen:
  ```bash
  kubectl -n <ns> get secret opa-gcp-token -o jsonpath='{.data.token}' | base64 -d | sed -n '1p'
  # Erwartet: Zeile beginnt mit "oauth2accesstoken:"
  ```
- Einmalige Token‑Erneuerung nach Deploy (CronJob):
  ```bash
  make renew-now stage=<env>
  ```

## Troubleshooting

- 401/403 beim Laden des Bundles:
  - GitLab/Basic: Secret fehlt/falsch.
  - workloadIdentityFederation: Secret enthält nicht das GAR‑kompatible Format (`oauth2accesstoken:`‑Präfix) oder Token ist abgelaufen.
- OPA Status‑Plugin 404/502 gegen Registry sind unkritisch; ggf. `opaStatusPrometheus: false`.
- Validierungsfehler beim Helm‑Rendern: Schema‑Fehlerhinweise beachten (erforderliche Felder, Exklusivität workloadIdentityFederation/SecretRef, Signaturprüfung).
