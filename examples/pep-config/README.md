# PEP-Routen der Client-Management-API

Dieses Verzeichnis enthält eine **Beispielkonfiguration** für den PEP HTTP Proxy (nginx mit
`libngx_pep.so`). Sie zeigt, wie die Client-Management-API nach
[zeta-guard-client-management.yaml](../../src/openapi/zeta-guard-client-management.yaml)
(1.0.0-draft) vollständig über den PEP läuft. Sie ist nicht normativ und vor dem Betrieb an die
Umgebung anzupassen.

| Datei | Inhalt |
| --- | --- |
| [client-management-locations.conf](client-management-locations.conf) | `location`-Blöcke für alle Pfade der API und Auffang-Locations |
| [zeta-cm-token-route.conf](zeta-cm-token-route.conf) | gemeinsamer Teil der Token-Routen (PEP-Prüfung, Audience, Weiterreichen von Token und DPoP-Proof) |
| [zeta-cm-passthrough-route.conf](zeta-cm-passthrough-route.conf) | gemeinsamer Teil der Durchleitungs-Routen (ohne Token-Prüfung am PEP) |

## Grundsätze

- **Alles über den PEP.** Jede Operation der API ist nur über den PEP HTTP Proxy erreichbar.
- **Eine Klasse je Pfad.** Jeder Pfad hat genau eine `location` und genau eine
  Autorisierungsklasse. `limit_except` lässt nur die Methoden dieses Pfads zu, andere Methoden
  beantwortet nginx mit 403. Grundlage ist A_25668-01: Audience und Scope hängen am Request-Pfad,
  nicht an der Methode.
- **Kein Präfix als Regel.** Die Locations sind exakt (`location =`) oder als eng gefasste Regex
  (`/register/{client_id}`, `/zeta/clients/{target_client_id}`) angelegt. Jeder andere Pfad unter
  `…/zeta/` und `…/register/` endet in einer Auffang-Location mit 404. So gelangt kein
  unbekannter Pfad über die allgemeine `/auth`-Location ohne PEP-Prüfung zum Authorization Server.
- **Keine `^~`-Präfixe für die Auffang-Locations.** Ein passendes `^~`-Präfix schaltet in nginx
  die Regex-Locations ab. Die Auffang-Locations sind deshalb einfache Präfixe; es gilt die
  Reihenfolge exakte Location, dann Regex, dann längstes Präfix.

## Routenklassen

| Klasse | Pfade | PEP | Authorization Server |
| --- | --- | --- | --- |
| Durchleitung, selbstauthentisierend | `POST /register`, `POST /register/verify` | `pep off`; Body-Grenze 64 KiB bzw. 16 KiB | prüft Attestierung und Besitznachweis bzw. Aktivierungsgeheimnis |
| Durchleitung, Client Assertion | `GET`/`PUT`/`DELETE /register/{client_id}`, `HEAD /zeta/rollover-nonce`, `GET /zeta/identity/rebind/status` | `pep off` | prüft die Client Assertion einschließlich `jti`-Replay-Cache, `htm`/`htu`, Lebensdauer |
| Token, E-Mail-Binding-Token | `/zeta/identity/bind-email`, `…/resend`, `…/verify`, `/zeta/identity/rebind`, `…/verify` | `pep on`, `pep_require_aud cm_resource`, Scope `zeta:email-binding` bzw. `zeta:email-verify` | prüft Token und DPoP-Proof erneut (A_CM-21), Status der Registrierung |
| Token, Verwaltungs-Token | `/zeta/identity/email`, `…/verify`, `/zeta/clients`, `/zeta/clients/{target_client_id}`, `/zeta/identity/rebind/cancel`, `/zeta/identity/recovery-code`, `…/verify`, `/zeta/identity/events` | `pep on`, `pep_require_aud cm_resource`, Scope `zeta:client-management` bzw. `zeta:email-change` | prüft Token und DPoP-Proof erneut, Objektprüfung, Step-up (acr, Sitzungsalter) |

Der Token-Endpunkt und die übrigen OAuth-Endpunkte des Authorization Servers sind nicht Teil
dieser API; sie laufen weiter über die `/auth`-Location des Helm-Charts.

## Annahmen

Die Werte entsprechen dem Helm-Chart `zeta-guard` (Template `templates/pep/_pep-nginx-conf.tpl`):

- Issuer `https://<host>/auth/realms/zeta-guard`; damit ist der Ressourcenbezeichner der API
  `https://<host>/auth/realms/zeta-guard/zeta` (A_CM-22).
- Upstream des Authorization Servers `http://authserver`.
- Logische Audience der API `cm_resource`; sie muss mit der Audience übereinstimmen, die die
  Policy Engine für den Ressourcenbezeichner vergibt.
- Direktiven von `libngx_pep.so` wie im Chart: `pep`, `pep_require_aud`, `pep_require_scope`
  (Liste der geforderten Scopes), `pep_require_popp`, `pep_forward_client_data`.

Einbindung im Chart: Inhalt von `client-management-locations.conf` in
`pepproxy.nginxConf.locations`; die beiden Snippet-Dateien neben `proxy_headers.conf` in die
ConfigMap des PEP.

## Bekannte Grenzen

- **Mindest-acr:** `libngx_pep.so` hat keine Direktive für ein Mindest-`acr`. Der Authorization
  Server prüft `acr` und Sitzungsalter selbst (A_CM-25); die Sicherheit hängt nicht am PEP. Die
  im Zielbild vorgesehene zusätzliche acr-Prüfung am PEP setzt eine neue Direktive voraus.
- **Weiterreichen von Token und DPoP-Proof:** `proxy_headers.conf` entfernt `Authorization` und
  `DPoP` für den Upstream. Die Token-Routen setzen beide wieder, damit der Authorization Server
  sie erneut prüfen kann (A_CM-21). Das Verhalten ist mit nginx 1.27.5 und einer Nachbildung der
  Strips getestet, gegen die `proxy_headers.conf` des PEP-Images noch nicht.
- **Methodenfehler:** `limit_except` antwortet mit 403, nicht mit 405.
- **Referenzdoku:** [Konfiguration_des_PEP_Http_Proxy.md](../../docs/user-manual/Referenzen/Konfiguration_des_PEP_Http_Proxy.md)
  nennt noch ältere Direktivnamen (`pep_issuer`, `pep_require_aud_any`); das Beispiel folgt dem
  Helm-Chart (`pep_pdp_issuer`, `pep_require_aud`).

## Test

Der Routing-Test (Syntax, Location je Pfad, Methoden, Auffang-Locations, Weiterreichen der
Header) läuft mit einem Standard-nginx, in dem die `pep*`-Direktiven auskommentiert sind; er prüft
nicht die Token-Validierung des PEP selbst. Ergebnis zum Stand dieser Dateien: 31 von 31 Fällen
bestanden (nginx 1.27.5).
