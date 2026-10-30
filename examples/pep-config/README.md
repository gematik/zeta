# PEP-Routen der Client-Management-API

Dieses Verzeichnis enthält eine **Beispielkonfiguration** für den PEP HTTP Proxy (nginx mit
`libngx_pep.so`). Sie zeigt, wie die Client-Management-API nach
[zeta-guard-client-management.yaml](../../src/openapi/zeta-guard-client-management.yaml)
(1.0.0-draft) vollständig über den PEP läuft. Sie ist nicht normativ und vor dem Betrieb an die
Umgebung anzupassen.

Geprüft gegen das Helm-Chart `zeta-guard` **v1.2.4**. Für **v1.3.x** ist zusätzlich eine
Ingress-Regel nötig und eine Chart-Änderung empfohlen (Abschnitt [Chart v1.3.x](#chart-v13x)).

| Datei | Inhalt |
| --- | --- |
| [client-management-locations.conf](client-management-locations.conf) | `location`-Blöcke für alle Pfade der API, Pfadfilter und Auffang-Location |
| [zeta-cm-token-route.conf](zeta-cm-token-route.conf) | gemeinsamer Teil der Token-Routen (PEP-Prüfung, Audience, Weiterreichen von Token und DPoP-Proof) |
| [zeta-cm-passthrough-route.conf](zeta-cm-passthrough-route.conf) | gemeinsamer Teil der Durchleitungs-Routen (ohne Token-Prüfung am PEP) |
| [ingress-client-management-v1.3.yaml](ingress-client-management-v1.3.yaml) | zusätzliche Ingress-Regel für Chart v1.3.x |

## Grundsätze

- **Alles über den PEP.** Jede Operation der API ist nur über den PEP HTTP Proxy erreichbar.
- **Eine Klasse je Pfad.** Jeder Pfad hat genau eine `location` und genau eine
  Autorisierungsklasse. Grundlage ist A_25668-01: Audience und Scope hängen am Request-Pfad,
  nicht an der Methode.
- **Nur die Methoden der OpenAPI.** Jede Location lässt genau die Methoden ihres Pfads zu; andere
  beantwortet sie mit `405` und `Allow`-Header. `HEAD` ist nur bei `/zeta/rollover-nonce`
  zugelassen. `limit_except` wird bewusst nicht verwendet: `limit_except GET` erlaubt in nginx
  auch `HEAD` und antwortet mit 403.
- **Kein Präfix als Regel.** Die Locations sind exakt (`location =`) oder als eng gefasste Regex
  (`/register/{client_id}`, `/zeta/clients/{target_client_id}`) angelegt. Jeder andere Pfad unter
  `…/zeta` und `…/register` endet in einer Auffang-Location mit 404, **für jeden Realm-Namen**.
  So gelangt kein unbekannter Pfad über die allgemeine `/auth`-Location ohne PEP-Prüfung zum
  Authorization Server. Keycloak-Pfade wie `…/zeta-guard-nonce` trifft die Auffang-Location nicht.
- **Pfadvarianten.** Ein Pfad unter `/auth/realms/` mit `;` (auch kodiert als `%3B`) wird mit 400
  abgelehnt. nginx wählt die Location nach dem normalisierten Pfad, reicht aber den Roh-Pfad weiter;
  ein JAX-RS-Server (Keycloak) ignoriert Matrix-Parameter beim Routing und kann `..;` als `..`
  deuten. Ohne Filter erreichte etwa `…/zeta;x=1/clients` den Authorization Server über `/auth`
  ohne PEP. Varianten mit `//`, `/./` oder `%2F` normalisiert nginx in die richtige Route.
- **Keine `^~`-Präfixe.** Ein passendes `^~`-Präfix schaltet in nginx die Regex-Locations ab. Es
  gilt die Reihenfolge exakte Location, dann Regex in Dateireihenfolge (Pfadfilter zuerst,
  Auffang zuletzt), dann längstes Präfix.
- **Fehlerformat.** Ablehnungen am PEP (400, 404, 405, 413) liefern JSON nach
  [zeta-error.yaml](../../src/schemas/zeta-error.yaml) mit `error: invalid_request`.

## Routenklassen

| Klasse | Pfade | PEP | Authorization Server |
| --- | --- | --- | --- |
| Durchleitung, selbstauthentisierend | `POST /register`, `POST /register/verify` | `pep off`; Body-Grenze 64 KiB bzw. 16 KiB | prüft Attestierung und Besitznachweis bzw. Aktivierungsgeheimnis |
| Durchleitung, Client Assertion | `GET`/`PUT`/`DELETE /register/{client_id}`, `HEAD /zeta/rollover-nonce`, `GET /zeta/identity/rebind/status` | `pep off`; Body-Grenze 32 KiB bzw. 1 KiB | prüft die Client Assertion einschließlich `jti`-Replay-Cache, `htm`/`htu`, Lebensdauer |
| Token, E-Mail-Binding-Token | `/zeta/identity/bind-email`, `…/resend`, `…/verify`, `/zeta/identity/rebind`, `…/verify` | `pep on`, `pep_require_aud cm_resource`, Scope `zeta:email-binding` bzw. `zeta:email-verify`; Body-Grenze 8 KiB | prüft Token und DPoP-Proof erneut, Status der Registrierung |
| Token, Verwaltungs-Token | `/zeta/identity/email`, `…/verify`, `/zeta/clients`, `/zeta/clients/{target_client_id}`, `/zeta/identity/rebind/cancel`, `/zeta/identity/recovery-code`, `…/verify`, `/zeta/identity/events` | `pep on`, `pep_require_aud cm_resource`, Scope `zeta:client-management` bzw. `zeta:email-change`; Body-Grenze 8 KiB | prüft Token und DPoP-Proof erneut, Objektprüfung, Step-up (acr, Sitzungsalter) |

Der Token-Endpunkt und die übrigen OAuth-Endpunkte des Authorization Servers sind nicht Teil
dieser API; sie laufen weiter über die `/auth`-Location des Helm-Charts.

## Annahmen (Chart v1.2.4)

Die Werte entsprechen dem Helm-Chart `zeta-guard` v1.2.4 (Template
`templates/pep/_pep-nginx-conf.tpl`):

- Der Ingress leitet `/auth` zum PEP; der PEP hat eine allgemeine Location `/auth` ohne
  PEP-Prüfung zum Authorization Server.
- Issuer `https://<host>/auth/realms/zeta-guard`; damit ist der Ressourcenbezeichner der API
  `https://<host>/auth/realms/zeta-guard/zeta`.
- Upstream des Authorization Servers `http://authserver`.
- Logische Audience der API `cm_resource`; sie muss mit der Audience übereinstimmen, die die
  Policy Engine für den Ressourcenbezeichner vergibt.
- Direktiven von `libngx_pep.so` wie im Chart: `pep`, `pep_require_aud`, `pep_require_scope`
  (Liste der geforderten Scopes), `pep_require_popp`, `pep_forward_client_data`.

Einbindung: Inhalt von `client-management-locations.conf` in `pepproxy.nginxConf.locations`; die
beiden Snippet-Dateien neben `proxy_headers.conf` in die ConfigMap des PEP.

## Chart v1.3.x

Im Chart v1.3.3 leitet der Ingress-Minion `zeta-guard-auth` das Präfix `/auth` **direkt** an den
Authorization Server; zum PEP gelangen nur `/auth/admin` und `/`. Die Locations dieses Beispiels
allein reichen dort nicht: Anfragen an die API erreichten den Authorization Server am PEP vorbei
(die API ist aber eine geschützte Ressource hinter dem PEP), die Auffang-Location und der Pfadfilter griffen nie.

Nötig bzw. empfohlen:

1. **Ingress-Regel** (nötig): [ingress-client-management-v1.3.yaml](ingress-client-management-v1.3.yaml)
   leitet `/auth/realms/zeta-guard/zeta` und `/auth/realms/zeta-guard/register` (Präfix, länger als
   `/auth`) zum PEP.
2. **Minion `zeta-guard-auth` absichern** (Chart-Änderung, empfohlen): Pfadvarianten mit `;` und
   Pfade fremder Realms erfasst die Ingress-Regel nicht; sie gingen weiter direkt zum Authorization
   Server. Der Minion setzt bereits `nginx.org/location-snippets`; dort zu ergänzen:

   ```nginx
   location ~ "^/auth/realms/[^?]*;" {
       return 400;
   }
   location ~ "^/auth/realms/[^/]+/(zeta|register)(/|$)" {
       return 404;
   }
   ```

   Die Annotation des Minions ist in v1.3.3 nicht über Values erweiterbar.
3. **Locations einbinden:** Das rohe `pepproxy.nginxConf.locations` ist in v1.3.x abgekündigt und
   schließt `proxyLocations` aus. `proxyLocations` erzeugt Präfix-Locations für einen Fachdienst
   und kann Scope je Pfad nicht abbilden. Empfehlung: die Client-Management-Routen wie die des
   Notification Service fest ins Chart-Template aufnehmen. Übergangsweise geht `locations` nur,
   wenn keine `proxyLocations` genutzt werden.
4. **Upstream:** Bei aktiviertem TLS des Authorization Servers (`authserver.tls.enabled`) den
   Upstream in den Snippets auf `https://authserver` umstellen.

## Bekannte Grenzen

- **Mindest-acr:** `libngx_pep.so` hat keine Direktive für ein Mindest-`acr`. Der Authorization
  Server prüft `acr` und Sitzungsalter selbst; die Sicherheit hängt nicht am PEP. Die
  im Zielbild vorgesehene zusätzliche acr-Prüfung am PEP setzt eine neue Direktive voraus.
- **Weiterreichen von Token und DPoP-Proof:** `proxy_headers.conf` entfernt `Authorization` und
  `DPoP` für den Upstream. Die Token-Routen setzen beide wieder, damit der Authorization Server
  sie erneut prüfen kann. Das Verhalten ist mit nginx 1.27.5 und einer Nachbildung der
  Strips getestet, gegen die `proxy_headers.conf` des PEP-Images noch nicht.
- **Netzwerk:** Der Authorization Server soll Anfragen an die Client-Management-API nur vom PEP
  annehmen (NetworkPolicy). Dann ist die API auch bei einer Fehlkonfiguration des Ingress nicht am
  PEP vorbei erreichbar; ohne PEP fehlt sonst der DPoP-Replay-Schutz.
- **Fehlerformat des PEP selbst:** Die Antworten von `libngx_pep.so` (401, 403) sind nicht Teil
  dieses Beispiels.
- **Referenzdoku:** [Konfiguration_des_PEP_Http_Proxy.md](../../docs/user-manual/Referenzen/Konfiguration_des_PEP_Http_Proxy.md)
  nennt noch ältere Direktivnamen (`pep_issuer`, `pep_require_aud_any`); das Beispiel folgt dem
  Helm-Chart (`pep_pdp_issuer`, `pep_require_aud`).

## Test

Der Routing-Test läuft mit einem Standard-nginx, in dem die `pep*`-Direktiven auskommentiert sind,
und nimmt das Ingress-Verhalten von Chart v1.2.x an (`/auth` zum PEP). Er prüft Syntax, Location
je Pfad, Methoden (405, `Allow`, `HEAD`), Auffang (404, fremde Realms), Pfadvarianten mit `;`
(400), JSON-Fehlerantworten, 413 und das Weiterreichen der Header; nicht geprüft wird die
Token-Validierung des PEP selbst. Ergebnis zum Stand dieser Dateien: 48 von 48 Fällen bestanden
(nginx 1.27.5).
