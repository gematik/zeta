# Konfiguration der Well-Known-Endpunkte

Der ZETA-Client (das SDK) findet den Authorization Server und die zu schützende
Ressource ausschließlich über die Discovery-Dokumente unter `/.well-known/`.
Sind die darin enthaltenen URLs falsch konfiguriert, schlägt entweder die
Discovery fehl oder es werden Tokens abgelehnt.

Eine Übersicht über die vier Client-Endpunkte und das grundsätzliche Routing
findet sich in den [Konfigurationshinweisen](Konfigurationshinweise.md). Die
reine Value-Tabelle steht in der
[Referenz des Helm Charts](Referenz_des_Helm_Charts.md#well-known-discovery-dokument).

## Zweck und RFC-Bezug

Der PEP-Proxy stellt unter `/.well-known/oauth-protected-resource` das
OAuth Protected Resource Metadata Dokument nach
[RFC 9728](https://www.rfc-editor.org/rfc/rfc9728) bereit. Es benennt

- unter `resource` den Bezeichner der geschützten Ressource,
- unter `authorization_servers` die zuständigen Authorization Server und
- unter `zeta_asl_use`, ob der Zugriff auf die Ressource ASL verlangt.

Beispiel eines gültigen Dokuments:

```json
{
    "resource": "https://zeta.example.com/pep/",
    "authorization_servers": [
        "https://zeta.example.com/"
    ],
    "zeta_asl_use": "required"
}
```

Das Feld `zeta_asl_use` ist **nicht** fest auf `required` gesetzt, sondern wird
aus dem Helm Value `pepproxy.asl_enabled` abgeleitet: `required`, wenn ASL
aktiviert ist, sonst `not_supported`. Da `asl_enabled` standardmäßig `false` ist,
weist ein unverändertes Deployment `not_supported` aus — der Client verzichtet
dann auf den ASL-Handshake. Wer ASL erwartet, muss `pepproxy.asl_enabled: true`
setzen und den Wert im ausgelieferten Dokument kontrollieren.

## Die Discovery-Kette

Der Client startet mit einer einzigen URL, der Fachdienst-URL, und arbeitet sich
über die Well-Known-Dokumente vor:

1. Der Client nimmt die Fachdienst-URL, extrahiert den Host und lädt
   `https://<pep-host>/.well-known/oauth-protected-resource`.
2. Aus dem Feld `authorization_servers[0]` nimmt er wiederum nur den Hostnamen
   und lädt `https://<as-host>/.well-known/oauth-authorization-server`.
3. Dort stehen die konkreten Endpunkte (Nonce, Token, Registrierung, JWKS usw.).

Daraus folgen zwei zentrale Konsequenzen für die Konfiguration:

- **Zum *Auffinden* der Well-Knowns zählt nur der Hostname (und Port), nicht der
  Pfad.** Ein falscher Pfad führt also nicht automatisch zu einem 404 bei der
  Discovery – der Fehler zeigt sich erst später.
- **Das Feld `resource` wird weiterverwendet.** Der PEP nutzt genau diesen Wert
  als Audience (`aud`) bei der Token-Ausstellung und prüft eingehende Access
  Tokens dagegen. Weicht `resource` von der tatsächlich extern erreichbaren URL
  ab, werden gültige Tokens mit 401/403 abgelehnt.

Deshalb muss `pepproxy.wellKnownBase` immer die von außen (aus Client-Sicht)
erreichbare Basis-URL sein – nicht ein clusterinterner Name.

## Die Values und das Konkatenationsmodell

Das Dokument wird als statisches Template gerendert. Die beiden URLs werden durch
einfache Zeichenketten-Verkettung ohne jede Normalisierung gebildet:

```text
resource               = pepproxy.wellKnownBase + pepproxy.wellKnownResourceSuffix
authorization_servers  = "https://" + authserver.hostname + authserver.wellKnownAuthServerPath
```

Es werden keine `/` ergänzt oder zusammengefasst und kein
Schema (`https://`) validiert. Jeder überzählige oder fehlende Bestandteil landet
unverändert im Dokument – hier entstehen alle unten beschriebenen
Fehlkonfigurationen.

| Value                                | Beschreibung                                                                              | Standard           |
|--------------------------------------|-------------------------------------------------------------------------------------------|--------------------|
| `pepproxy.wellKnownBase`             | Extern erreichbare Basis-URL des PEP (inkl. `https://`), fließt in `resource` ein         | `http://localhost` |
| `pepproxy.wellKnownResourceSuffix`   | Pfad-Suffix, das an `wellKnownBase` angehängt wird (mit führendem und abschließendem `/`) | `/pep/`            |
| `authserver.hostname`                | Hostname des Authorization Servers (ohne Schema), fließt in `authorization_servers` ein   | `""`               |
| `authserver.wellKnownAuthServerPath` | Pfad-Suffix, das an `authserver.hostname` angehängt wird                                  | `/`                |
| `pepproxy.asl_enabled`               | Steuert `zeta_asl_use`: `true` ergibt `required`, `false` ergibt `not_supported`          | `false`            |

> **Achtung – der Default `http://localhost` ist nur für lokale Setups (KIND)
> gedacht.** In jeder erreichbaren Umgebung **muss** `pepproxy.wellKnownBase`
> überschrieben werden, sonst enthält `resource` die von außen unerreichbare URL
> `http://localhost/pep/` und Token-Prüfungen schlagen fehl.

### Zusammenhang mit `authserver.hostname` und `authserver.adminHostname`

`authserver.adminHostname` setzt man, um die Keycloak-Admin-Konsole und -API vom
öffentlichen Zugang zu trennen: Der Admin-Zugang läuft dann über einen eigenen
Hostnamen mit eigenem Ingress, und `/auth/admin` wird am öffentlichen Proxy
gesperrt (Details unter
[Admin-API-Absicherung](Referenz_des_Helm_Charts.md#admin-api-absicherung)).

Das hat eine Nebenwirkung auf die Well-Knowns: Ist `adminHostname` gesetzt, läuft
Keycloak technisch unter dem Pfad `/auth` (`--hostname=https://<hostname>/auth`).
Damit liegt auch der `issuer`, den Keycloak in seinen eigenen Well-Known-Dokumenten
ausweist, unter `/auth`. In diesem Fall muss `authserver.wellKnownAuthServerPath`
konsistent auf `/auth` gesetzt werden, damit der im `oauth-protected-resource`
genannte Authorization Server und der von Keycloak ausgewiesene `issuer`
übereinstimmen – sonst drohen
[doppelte Well-Knowns](#fehlkonfiguration-und-doppelte-well-knowns).

## Wann und warum von den Defaults abweichen

### Szenario 1 – Standard, ein Hostname (Auslieferungsstand)

PEP und Authorization Server sind unter demselben Hostnamen erreichbar, der
Fachdienst hängt unter `/pep/`.

```yaml
zeta-guard:
    pepproxy:
        wellKnownBase: "https://zeta.example.com"
        wellKnownResourceSuffix: /pep/
    authserver:
        hostname: "zeta.example.com"
        wellKnownAuthServerPath: /
```

Ergebnis: `resource = https://zeta.example.com/pep/`,
`authorization_servers = [https://zeta.example.com/]`.

### Szenario 2 – Keycloak unter dem Unterpfad `/auth`

Wird Keycloak unter `/auth` betrieben (u. a. immer dann, wenn
`authserver.adminHostname` gesetzt ist), muss der Well-Known-Pfad des
Authorization Servers das widerspiegeln:

```yaml
zeta-guard:
    authserver:
        hostname: "zeta.example.com"
        wellKnownAuthServerPath: /auth
```

Ergebnis: `authorization_servers = [https://zeta.example.com/auth]`.

### Szenario 3 – Ressource direkt unter der Root-URL

Liegt der Fachdienst nicht unter `/pep/`, sondern direkt unter der Basis-URL
(z. B. in OpenShift-Setups), wird das Suffix auf `/` gesetzt:

```yaml
zeta-guard:
    pepproxy:
        wellKnownBase: "https://zeta.example.com"
        wellKnownResourceSuffix: /
```

Ergebnis: `resource = https://zeta.example.com/`.

### Szenario 4 – Ingress schreibt Pfade um / externer Hostname ≠ intern

Wenn ein vorgelagerter Ingress, Load Balancer oder Reverse Proxy Pfade umschreibt
oder der externe Hostname vom clusterinternen Namen abweicht, **müssen** `base`
und `hostname` die aus **Client-Sicht** erreichbaren Werte tragen. Andernfalls
zeigt `resource` auf eine intern korrekte, aber extern unerreichbare URL – die
Discovery gelingt zwar (nur der Host zählt), die spätere Audience-Prüfung
scheitert jedoch mit **401/403**.

## Fehlkonfiguration und doppelte Well-Knowns

Typische Fälle:

| Fehler                                               | Beispielwert                                 | Ergebnis im Dokument                  |
|------------------------------------------------------|----------------------------------------------|---------------------------------------|
| Schema im `hostname` mitgegeben                      | `hostname: https://zeta.example.com`         | `"https://https://zeta.example.com/"` |
| `wellKnownBase` mit `/` am Ende und Suffix mit `/`   | `.../` + `/pep/`                             | `"https://zeta.example.com//pep/"`    |
| Pfad-Anteil im Suffix doppelt                        | `wellKnownResourceSuffix: /pep/pep/`         | `"https://zeta.example.com/pep/pep/"` |
| `/.well-known/` versehentlich ins Suffix aufgenommen | `wellKnownResourceSuffix: /.well-known/pep/` | doppelter `/.well-known/`-Pfad        |

Alle diese Werte werden ohne Warnung gerendert – der Fehler fällt erst im
Client-Betrieb auf (Discovery findet nichts Erreichbares, oder die
Audience-Prüfung schlägt fehl).

### Doppelte Well-Known-Dokumente

Ein subtilerer Fall sind zwei gleichzeitig erreichbare, aber widersprüchliche
Authorization-Server-Metadaten:

- Der PEP-Proxy beantwortet `/.well-known/oauth-authorization-server`, indem er
  intern an Keycloaks Endpunkt
  `/auth/realms/zeta-guard/.well-known/zeta-guard-well-known` weiterleitet.
- Sobald `/auth` über den Ingress bzw. PEP an Keycloak geroutet wird (u. a. wenn
  `authserver.adminHostname` gesetzt ist), ist Keycloaks eigenes Well-Known
  zusätzlich direkt unter
  `https://<host>/auth/realms/zeta-guard/.well-known/openid-configuration`
  erreichbar.

Stimmt nun `authserver.wellKnownAuthServerPath` nicht mit dem von Keycloak
über `--hostname` gesetzten `issuer` überein, beschreiben zwei erreichbare
Dokumente denselben Authorization Server mit unterschiedlichem `issuer` bzw.
unterschiedlichen Endpunkten. Die Discovery wird dadurch mehrdeutig; je
nachdem, welchen Pfad der Client auflöst, erhält er widersprüchliche Angaben.

**Symptome:** inkonsistenter oder unerwarteter `issuer`, Token-Ablehnungen
(401/403) durch Audience-/Issuer-Mismatch, oder Discovery, die auf einen
unerreichbaren Endpunkt zeigt.

### Prüfung

1. Gerendertes Dokument kontrollieren:

   ```bash
   helm template zeta-guard <chart> \
     --set zeta-guard.pepproxy.wellKnownBase=https://zeta.example.com \
     --set zeta-guard.authserver.hostname=zeta.example.com \
     -s charts/zeta-guard/templates/pep/pep-well-known.yaml
   ```

2. Beide Well-Knowns zur Laufzeit abrufen und auf Konsistenz prüfen – der
   `issuer` im Authorization-Server-Dokument muss zum Eintrag in
   `authorization_servers` passen:

   ```bash
   curl https://zeta.example.com/.well-known/oauth-protected-resource
   curl https://zeta.example.com/.well-known/oauth-authorization-server
   ```

## Well-Known-Dokument des Notification Service

Ist der Notification Service aktiviert (`notificationService.enabled: true` —
Vorschau, Standard `false`), stellt der PEP ein **zweites** Protected Resource
Metadata Dokument nach RFC 9728 bereit, denn der Notification Service ist
gegenüber den Clients eine eigene geschützte Ressource mit eigener Audience:

```
/.well-known/oauth-protected-resource/notification-service
```

Das letzte Pfadsegment stammt aus `notificationService.wellKnownResourceSuffix`
(Standard `/notification-service`); der Wert muss genau ein Pfadsegment mit
führendem `/` sein, sonst bricht das Chart-Rendern ab. Das Dokument wird nach
demselben Konkatenationsmodell gebildet wie das des Fachdiensts:

```text
resource               = pepproxy.wellKnownBase + notificationService.wellKnownResourceSuffix
authorization_servers  = "https://" + authserver.hostname + authserver.wellKnownAuthServerPath
```

Inhaltlich unterscheidet es sich vom Fachdienst-Dokument in drei Punkten:

- **`scopes_supported`** listet die Notification-Scopes
  `notification.pusher.read`, `notification.pusher.write`,
  `notification.channel.read` und `notification.channel.write`. Der Scope
  `notification.history.read` erscheint nur bei
  `notificationService.historyEnabled: true` — und muss dann zusätzlich über
  die Terraform-Variable `notification_history_enabled` in Keycloak angelegt
  werden (die beiden Schalter sind nicht automatisch gekoppelt).
- **`dpop_bound_access_tokens_required: true`** — Access Tokens für den
  Notification Service müssen DPoP-gebunden sein.
- **`zeta_asl_use: "not_supported"`** — die Notification-API wird ohne ASL
  angesprochen.

Der `resource`-Wert ist zugleich die Audience, die der PEP an den
Notification-Locations (`/push/v1/…`) erzwingt: Ein für den Fachdienst
ausgestelltes Token wird dort abgelehnt und umgekehrt. Damit gilt auch hier —
`pepproxy.wellKnownBase` muss die aus Client-Sicht erreichbare Basis-URL sein.

### Prüfung

1. Gerendertes Dokument kontrollieren:

   ```bash
   helm template zeta-guard <chart> \
     --set zeta-guard.notificationService.enabled=true \
     --set zeta-guard.pepproxy.wellKnownBase=https://zeta.example.com \
     --set zeta-guard.authserver.hostname=zeta.example.com \
     -s charts/zeta-guard/templates/pep/pep-well-known-resources.yaml
   ```

2. Zur Laufzeit abrufen und prüfen, dass `resource` zur externen URL passt und
   die Scope-Liste den Stand von `historyEnabled` widerspiegelt:

   ```bash
   curl https://zeta.example.com/.well-known/oauth-protected-resource/notification-service
   ```

Weitere Details zum Notification Service stehen in der
[Konfiguration des Notification Service](Konfiguration_des_Notification_Service.md#well-known-integration-rfc-9728).

## Weiterführende Verweise

- [Konfigurationshinweise](Konfigurationshinweise.md) – Request-Routing und die
  vier Client-Endpunkte
- [Referenz des Helm Charts](Referenz_des_Helm_Charts.md#well-known-discovery-dokument)
  – Value-Tabelle
- [How to deploy ZETA Guard](https://github.com/gematik/zeta-guard-helm/blob/main/docs/how-to_guides/How_to_deploy_ZETA_Guard.md)
  – Deployment-Anleitung im Helm-Repository
