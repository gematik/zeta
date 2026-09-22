# Wie Sie einen eigenen Ingress-Controller verwenden

Das ZETA-Guard-Helm-Chart liefert einen Ingress-Controller mit (F5 NGINX Ingress
Controller, im Folgenden **NIC**) und konfiguriert ihn über Annotationen an den
Ingress-Ressourcen sowie über nginx-Snippets in den Controller-Values. Ein Teil
dieser Einstellungen ist F5-spezifisch.

Diese Anleitung zeigt, wie Sie damit umgehen, wenn Sie einen eigenen
Ingress-Controller einsetzen: welche der Einstellungen eine Funktion des
ZETA-Guard tragen und deshalb nachzubilden sind, welche der Absicherung dienen
und welche reine Betriebsparameter des NIC sind und ersatzlos entfallen können.

## Inhaltsverzeichnis

- [Die drei Schalter](#die-drei-schalter)
- [Funktional erforderlich](#funktional-erforderlich)
  - [Sitzungsbindung über das `zeta_route`-Cookie](#sitzungsbindung-über-das-zeta_route-cookie)
  - [WebSocket-Upgrade](#websocket-upgrade)
  - [TLS zum Authserver](#tls-zum-authserver)
  - [Client-seitige Forwarding-Header verwerfen](#client-seitige-forwarding-header-verwerfen)
  - [Revocation-Endpunkt nach außen sperren](#revocation-endpunkt-nach-außen-sperren)
- [Absicherung und AFO-Nachweis](#absicherung-und-afo-nachweis)
- [Reine Betriebsparameter des NIC](#reine-betriebsparameter-des-nic)
- [F5-spezifische Struktur](#f5-spezifische-struktur)
- [Was das Chart unabhängig vom Ingress leistet](#was-das-chart-unabhängig-vom-ingress-leistet)
- [Checkliste](#checkliste)

## Die drei Schalter

Drei Values steuern unabhängig voneinander, was das Chart im Bereich Ingress
erzeugt. Sie werden häufig verwechselt:

| Value                   | Wirkung                                                                                                   | Standard |
|-------------------------|-----------------------------------------------------------------------------------------------------------|----------|
| `nginx-ingress.enabled` | Installiert den **mitgelieferten NIC** als Subchart. `false` installiert keinen Controller.               | `true`   |
| `nginxIngressEnabled`   | Rendert die **F5-spezifischen Annotationen** an den Ingress-Ressourcen. Installiert nichts.               | `true`   |
| `ingressEnabled`        | Erzeugt die **Ingress-Ressourcen** des Charts überhaupt. `false` überlässt sie vollständig dem Betreiber. | `true`   |

Daraus ergeben sich drei sinnvolle Kombinationen:

* **Mitgelieferter NIC** — alle drei auf `true` (Standard). Es ist nichts weiter
  zu tun; dieser Fall ist in dieser Anleitung nicht gemeint.
* **Extern installierter NIC** — `nginx-ingress.enabled: false`, die beiden
  anderen `true`. Der Controller wird außerhalb des Charts betrieben (z. B.
  clusterweit), die F5-Annotationen bleiben wirksam. Die Snippets aus
  `nginx-ingress.controller.config.entries` werden dann **nicht** vom Chart
  gesetzt und müssen am externen NIC hinterlegt werden.
* **Fremder Ingress-Controller** — `nginx-ingress.enabled: false` und
  `nginxIngressEnabled: false`. `ingressClassName` zeigt auf die eigene
  Ingress-Class. Die Ingress-Ressourcen des Charts bleiben nutzbar (reines
  Pfad-Routing), können über `ingressEnabled: false` aber auch vollständig durch
  eigene ersetzt werden. Für diesen Fall gilt der Rest dieser Anleitung.

> **Hinweis:** `nginxIngressEnabled: false` schaltet auch
> `nginx.org/lb-method` ab. Wird ein externer NIC eingesetzt, der die
> `$zeta_route`-Snippets nicht kennt, ist stattdessen `nginxIngressLbMethod:
> false` zu setzen — sonst rendert das Chart eine lb-method, die auf eine im
> Controller nicht definierte Variable verweist.

## Funktional erforderlich

Die folgenden Einstellungen tragen Funktionen des ZETA-Guard. Entfallen sie
ersatzlos, ist der ZETA-Guard in seiner Funktion eingeschränkt.

### Sitzungsbindung über das `zeta_route`-Cookie

Am NIC umgesetzt durch die `http-snippets` (zwei `map`-Blöcke und
`more_set_headers -a "Set-Cookie: $zeta_route_setcookie"`), das `main-snippet`
zum Laden des Moduls
[headers-more](https://github.com/openresty/headers-more-nginx-module) sowie die
Annotation `nginx.org/lb-method: "hash $zeta_route consistent"` an den Minions.

Die Bindung wird an **zwei** Stellen gebraucht:

* **PEP HTTP Proxy:** Die ASL-Sitzungsschlüssel liegen im Shared Memory der
  jeweiligen nginx-Instanz und werden nicht zwischen Pods geteilt. Ohne Bindung
  schlägt bei `pepproxy.replicaCount > 1` jede Anfrage fehl, die auf einem
  anderen Pod landet als der ASL-Handshake.
* **Authorization Server:** Die Nonces des `zeta-guard-nonce`-Endpunkts werden
  pro Instanz gehalten. Eine Nonce muss auf derselben Replica eingelöst werden,
  die sie ausgegeben hat. Ohne Bindung schlägt bei mehreren Authserver-Replicas
  ein Teil der Token-Anforderungen fehl.

**Nachzubilden ist:** eine Cookie-basierte, konsistente Sitzungsaffinität je
Upstream. Das Cookie muss nicht `zeta_route` heißen und nicht vom selben
Mechanismus gesetzt werden — entscheidend ist, dass Anfragen desselben Clients
denselben PEP- bzw. Authserver-Pod erreichen. Ohne eine solche Affinität sind
beide Komponenten auf `replicaCount: 1` beschränkt.

### WebSocket-Upgrade

Am NIC umgesetzt durch `nginx.org/websocket-services` auf einem **eigenen**
Minion-Ingress, der nur die WebSocket-Pfade führt (abgeleitet aus
`pepproxy.nginxConf.proxyLocations` mit `websocket: true`).

**Nachzubilden ist:** die Upgrade-Behandlung (`Upgrade`/`Connection`-Header) für
genau diese Pfade. Ohne sie kommen keine WebSocket-Verbindungen zustande; das
betrifft insbesondere den Notification Service.

Der eigene Minion existiert, weil die NIC-Annotation service-weit wirkt: auf dem
Haupt-Minion würde sie auf *jeder* Location von `pep-proxy-svc` ein
`Connection: close` erzwingen und damit den Upstream-Keepalive aushebeln. Beim
Nachbau mit einem anderen Controller ist dieselbe Eingrenzung sinnvoll.

### TLS zum Authserver

Am NIC umgesetzt durch `nginx.org/ssl-services: "authserver"`, gerendert sobald
`authserver.tls.enabled` oder `authserver.hsm.tls.enabled` gesetzt ist.

**Nachzubilden ist:** Der Ingress muss den Authserver in diesem Fall über HTTPS
ansprechen. Ohne die Einstellung spricht der Controller Klartext-HTTP gegen
einen TLS-Port; die Anfragen scheitern.

### Client-seitige Forwarding-Header verwerfen

Am NIC umgesetzt durch `more_clear_input_headers` in den `http-snippets`.

**Nachzubilden ist:** das Verwerfen aller eingehenden Forwarding- und
Client-Adress-Header an der Außengrenze. Andernfalls kann ein Client den
`ip_address`-Claim seines Access-Tokens selbst bestimmen und damit die
No-Travel-Prüfung sowie ein IP-basiertes Rate Limit umgehen. Header-Liste,
Begründung und der Sonderfall eines vorgelagerten vertrauenswürdigen Proxys
stehen in
[Client-seitige Forwarding-Header verwerfen](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#client-seitige-forwarding-header-verwerfen).

### Revocation-Endpunkt nach außen sperren

Am NIC umgesetzt durch ein `nginx.org/location-snippets` an den `/auth`-Minions,
das `^/auth/realms/[^/]+/zeta-guard-revocation` mit `404` beantwortet.

Die Session-Revocation-API ist ausschließlich für den clusterinternen Gebrauch
bestimmt: Die PEPs erreichen sie direkt über den Service `authserver`. Von außen
darf sie nicht erreichbar sein — über `POST` werden Sitzungen widerrufen, über
`GET` liefert sie die Blockliste mit Session-IDs als Event-Stream.

**Nachzubilden ist:** eine Sperre dieses Pfads für alle von außen erreichbaren
Hostnamen (öffentlicher Hostname und, falls konfiguriert,
`authserver.adminHostname`).

## Absicherung und AFO-Nachweis

Diese Einstellungen sind nicht F5-spezifisch, aber sie erfüllen Anforderungen
der gematik-Spezifikation. Wer TLS an einem eigenen Ingress terminiert, führt
den Nachweis dort selbst.

| Einstellung am NIC                                               | Anforderung                                                       |
|------------------------------------------------------------------|-------------------------------------------------------------------|
| `ssl_protocols TLSv1.3 TLSv1.2`                                  | GS-A_5035, GS-A_4387, A_18464, GS-A_4385, A_18467                 |
| `ssl_ciphers` (TLS 1.2), `ssl_conf_command Ciphersuites` (1.3)   | A_17322, A_21275-01, A_17124-03, GS-A_5016                        |
| `ssl_ecdh_curve`                                                 | GS-A_4359-02, GS-A_4357-02                                        |
| `ssl_session_tickets off` (plus `ssl_session_timeout` < 24 h)    | GS-A_5322 — Rotation bzw. Löschung des Session-Ticket-Schlüssels  |
| `ssl_stapling on`, `ssl_stapling_verify on`                      | A_26964                                                           |
| `ssl_prefer_server_ciphers off`                                  | A_17775 — Reihenfolge des Clients                                 |
| `nginx.org/hsts`, `-max-age`, `-include-subdomains` (Master)     | HSTS mit einem Jahr, inkl. Subdomains                             |

Die Werte im Einzelnen stehen in `nginx-ingress.controller.config.entries` der
`values.yaml` des Charts, jeweils mit der zugehörigen Anforderung als Kommentar.

## Reine Betriebsparameter des NIC

Diese Einstellungen dimensionieren den mitgelieferten Controller. Sie können
entfallen; ein eigener Controller ist stattdessen nach den Maßgaben seines
Herstellers zu dimensionieren. Zwei Punkte sind dabei erfahrungsgemäß relevant:

* **Upstream-Keepalive** (`keepalive: "32"`, `keepalive-requests: "10000"`):
  Ohne ihn öffnet jede weitergeleitete Anfrage eine neue Verbindung zum
  Upstream, deren Port nach dem Schließen 60 Sekunden in `TIME_WAIT` verbleibt.
  Bei etwa 1000 Anfragen pro Sekunde gehen dem Controller-Pod die
  Ephemeral Ports aus.
* **Ephemeral-Port-Bereich** (`sysctl net.ipv4.ip_local_port_range`) und
  `worker-connections` / `worker-rlimit-nofile`: dieselbe Ursache, andere
  Stellschraube.

Ebenfalls rein betrieblich: `ssl-session-cache`, `ssl-session-timeout`, der
Betrieb als DaemonSet und `service.externalTrafficPolicy: Local`. Letzteres
erhält die Quell-IP-Adresse des Clients — ohne eine äquivalente Einstellung ist
die am Ingress ermittelte Adresse die eines Cluster-Knotens, nicht die des
Clients (siehe
[Client-seitige Forwarding-Header verwerfen](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#client-seitige-forwarding-header-verwerfen)).

## F5-spezifische Struktur

`nginx.org/mergeable-ingress-type: "master"` bzw. `"minion"` bildet die
Aufteilung in eine TLS-terminierende Master-Ressource und mehrere
Pfad-Ressourcen ab. Das ist eine F5-Eigenheit ohne Entsprechung in der
Kubernetes-Ingress-API.

Ein fremder Controller ignoriert diese Annotation. Die erzeugten Ressourcen
bleiben trotzdem gültige Ingresses mit Host, TLS und Pfaden — in vielen
Umgebungen genügt das. Wo es nicht genügt, ist `ingressEnabled: false` zu setzen
und eine eigene Ingress-Definition zu pflegen, die dieselben Pfade auf dieselben
Services routet:

| Pfad            | Service         | Anmerkung                                       |
|-----------------|-----------------|-------------------------------------------------|
| `/auth`         | `authserver`    | Realm-Endpunkte (Token, Well-Known, Login)      |
| `/auth/admin`   | `pep-proxy-svc` | nur wenn `authserver.adminHostname` gesetzt ist |
| `/`             | `pep-proxy-svc` | alle Fachdienst-Pfade und die ASL-Endpunkte     |
| WebSocket-Pfade | `pep-proxy-svc` | aus `proxyLocations` mit `websocket: true`      |

Ebenfalls nur mit dem mitgelieferten NIC nutzbar ist `nginxIngressHsm: true`:
Der Value unterdrückt `spec.tls` der Master-Ressource, damit TLS stattdessen
über ein Server-Snippet in `ingressMasterAnnotations` konfiguriert werden kann —
so wird der TLS-Schlüssel über einen OpenSSL-Provider im HSM gehalten. Mit einem
fremden Controller ist die HSM-Anbindung der TLS-Terminierung Sache dieses
Controllers.

## Was das Chart unabhängig vom Ingress leistet

Nicht nachzubilden sind Absicherungen, die bewusst nicht am Ingress hängen:

* **Sperre der Admin-REST-API und -Konsole auf dem öffentlichen Hostnamen.**
  Ist `authserver.adminHostname` gesetzt, routet das Chart `/auth/admin` auf den
  PEP, der mit `403` antwortet. Das funktioniert mit jedem Ingress-Controller,
  weil es nur Pfad-Routing benötigt. Ohne Admin-Hostnamen bleiben Admin-API und
  -Konsole auf dem öffentlichen Hostnamen erreichbar — sonst gäbe es keinen Weg
  zu ihnen.
* **Header-Behandlung an der Upstream-Grenze.** Die `ZETA-*`-Header setzt
  ausschließlich der PEP; vom Client mitgeschickte Kopien verwirft er. Siehe
  [Header-Behandlung und `proxy_headers.conf`](../Referenzen/Konfiguration_des_PEP_Http_Proxy.md#header-behandlung-und-proxy_headersconf).
* **Token- und DPoP-Prüfung.** Sie findet im PEP statt, nicht am Ingress. Ein
  Ingress ohne ZETA-spezifische Konfiguration schwächt sie nicht ab.

## Checkliste

Beim Umstieg auf einen eigenen Ingress-Controller:

1. `nginx-ingress.enabled: false`, `nginxIngressEnabled: false`,
   `ingressClassName` auf die eigene Ingress-Class setzen.
2. Cookie-basierte Sitzungsaffinität für `pep-proxy-svc` **und** `authserver`
   einrichten — oder beide Komponenten auf `replicaCount: 1` belassen.
3. WebSocket-Upgrade für die WebSocket-Pfade konfigurieren, sofern genutzt.
4. Bei aktiviertem Authserver-TLS: HTTPS zum Authserver-Upstream konfigurieren.
5. Eingehende Forwarding- und Client-Adress-Header verwerfen.
6. `^/auth/realms/[^/]+/zeta-guard-revocation` auf allen öffentlichen Hostnamen
   sperren.
7. TLS-Parameter und HSTS gemäß der Tabelle unter
   [Absicherung und AFO-Nachweis](#absicherung-und-afo-nachweis) setzen.
8. Rate Limit einrichten (siehe
   [Rate Limit einrichten](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#rate-limit-einrichten)).
9. Prüfen, ob die Ingress-Ressourcen des Charts genügen; andernfalls
   `ingressEnabled: false` und eigene Ressourcen nach der Pfadtabelle oben.

Die Liste der ingressseitig getragenen Funktionen kann sich mit neuen Releases
ändern. Die [Release Notes](../ReleaseNotes.md) weisen solche Änderungen aus.

## Verwandte Dokumentation

* [Wie Sie ZETA-Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#1-ingress-controller-und-ingress-konfigurieren)
* [Referenz des Helm-Charts — Ingress](../Referenzen/Referenz_des_Helm_Charts.md#ingress)
* [Komponentenübersicht](../Referenzen/Komponentenuebersicht.md)
* [Wie Sie ZETA-Guard auf OpenShift betreiben](ZETA_OpenShift_Kompatibilität.md)
