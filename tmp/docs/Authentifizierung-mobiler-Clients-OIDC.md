# 5.3.2.5 Authentifizierung mobiler Clients (OIDC Authorization Code Flow mit PAR und PKCE)

> Hinweis: Dieses Dokument beschreibt den Ablauf zur Übernahme in die Spezifikation
> gemSpec_ZETA, Kapitel 5.3.2 "Abläufe für mobile Clients". Es ist im selben Stil wie die
> Abschnitte 5.3.1.6.3 (Token Exchange mit Attestation) und 5.3.2.4 (Client Registrierung und
> Authentifizierung) verfasst und kann als neuer Abschnitt 5.3.2.5 übernommen werden.

Im Gegensatz zu stationären Clients (Primärsysteme), die sich per OAuth Token Exchange mit einem
SM(C)-B-signierten Subject Token authentisieren, erfolgt die Nutzerauthentisierung bei mobilen
Clients (Android und iOS) interaktiv über einen sektoralen Identity Provider (IDP) der
TI-Föderation.

## 5.3.2.5.1 Rollen von Fach-Client und ZETA Client

Auf dem mobilen Endgerät wirken zwei Komponenten zusammen:

- Der **Fach-Client** enthält die fachliche Logik für die Arbeit mit dem Resource Server. Er wählt
  (bzw. lässt den Nutzer wählen) den zuständigen sektoralen IDP aus (`idp_iss`), erstellt den
  vollständigen fachlichen HTTPS-Request inklusive aller Header und übergibt ihn an den ZETA Client.
  Anschließend wartet er auf die fachliche Response.
- Der **ZETA Client** kümmert sich um Client-Registrierung, Session-, Schlüssel- und
  Token-Verwaltung sowie die Authentifizierung. Er verarbeitet den vom Fach-Client übergebenen
  Request, beschafft bei Bedarf ein gültiges Access Token (über den in diesem Kapitel beschriebenen
  Ablauf) und gibt die erhaltene Response an den Fach-Client zurück.

Diese Aufgabenteilung entspricht dem für stationäre Clients in
Abb-ZETA-Zugriff-auf-RS-mit-ASL dargestellten Zusammenspiel von Fach-Client und ZETA Client.

## 5.3.2.5.2 Überblick

Das folgende Übersichtsdiagramm zeigt das Zusammenspiel der Komponenten. Die eigentliche
Authentifizierung ist als OpenID Connect (OIDC) Authorization Code Flow mit Pushed Authorization
Request (PAR, RFC 9126) und Proof Key for Code Exchange (PKCE, RFC 7636) realisiert und in drei
Teilabläufe **(A)**, **(B)** und **(C)** zerlegt, die in eigenen Diagrammen detailliert sind.

Der PDP Authorization Server des ZETA Guard übernimmt dabei die Rolle der
OpenID-Connect-Relying-Party (Fachdienst) gegenüber dem sektoralen IDP. Aus Sicht des mobilen ZETA
Client agiert der PDP Authorization Server gleichzeitig als der für den Fachdienst zuständige
Authorization Server. Es werden daher zwei ineinander verschachtelte Authorization-Code-Flows
ausgeführt:

- der **äußere Flow** zwischen ZETA Client und PDP Authorization Server (mit `code_challenge_app`)
  und
- der **innere Flow** zwischen PDP Authorization Server und sektoralem IDP (mit `code_challenge_as`).

Die Authentifizierung gegenüber dem sektoralen IDP nutzt `self_signed_tls_client_auth` (mTLS), die
Vertrauensbeziehung zwischen Fachdienst und IDP wird über die OpenID Federation 1.0 (Federation
Master) hergestellt. Das vom IDP ausgestellte ID Token ist verschlüsselt (JWE, ECDH-ES/A256GCM) und
signiert (ES256). Das vom PDP Authorization Server an den ZETA Client ausgestellte Access Token wird
über DPoP kryptografisch an die Sitzung gebunden.

**Vorbedingungen:**

- Die Service Discovery ist abgeschlossen (siehe 5.3.1.3 / 5.3.2.2). Der ZETA Client kennt die
  Endpunkte des PDP Authorization Server.
- Der ZETA Client wurde per Dynamic Client Registration registriert (siehe 5.3.2.4) und besitzt das
  Schlüsselpaar `PrK.Client.Sig` / `PuK.Client.Sig`.
- Der PDP Authorization Server ist als Relying Party (Fachdienst) beim Federation Master registriert.
- App-Link / Universal-Link für ZETA Client und Authenticator-Modul sind im Betriebssystem
  registriert.

Abbildung 21 Abb-ZETA-OIDC-Authentifizierung-mobiler-Clients

![Abb-ZETA-OIDC-Authentifizierung-mobiler-Clients](../../images/zeta-flows/Abb-ZETA-OIDC-Authentifizierung-mobiler-Clients.svg)

(01) Der Nutzer hat im Fach-Client den zuständigen sektoralen IDP ausgewählt (`idp_iss`) und löst den
Zugriff auf den Fachdienst aus.

(02) Der Fach-Client erstellt den vollständigen fachlichen HTTPS-Request (inkl. Header).

(03) Der Fach-Client übergibt den Request (inkl. `idp_iss`) an den ZETA Client. Besitzt der ZETA
Client noch kein gültiges Access Token, führt er die Authentifizierung in den Teilabläufen (A) bis
(C) aus.

(A) **Authorization Request mit PAR** – siehe 5.3.2.5.3 / Abb-ZETA-OIDC-Authorization-Request-mit-PAR.

(B) **Nutzerauthentisierung am sektoralen IDP** – siehe 5.3.2.5.4 / Abb-ZETA-OIDC-Nutzerauthentisierung.

(C) **Token-Bezug und Ausstellung der ZETA Token** – siehe 5.3.2.5.5 / Abb-ZETA-OIDC-Token-Bezug.

Nach Abschluss von (C) besitzt der ZETA Client ein DPoP-gebundenes Access Token. Der eigentliche
Zugriff auf den Resource Server erfolgt gemäß Abb-ZETA-Zugriff-auf-RS-mit-ASL bzw.
Abb-ZETA-Zugriff-auf-RS-ohne-ASL. Der ZETA Client gibt die fachliche Response an den Fach-Client
zurück, der das Ergebnis dem Nutzer anzeigt.

## 5.3.2.5.3 Teilablauf (A): Authorization Request mit PAR

Der ZETA Client startet den äußeren Authorization Code Flow am PDP Authorization Server; dieser
stellt als Relying Party einen Pushed Authorization Request am sektoralen IDP.

Abbildung 22 Abb-ZETA-OIDC-Authorization-Request-mit-PAR

![Abb-ZETA-OIDC-Authorization-Request-mit-PAR](../../images/zeta-flows/Abb-ZETA-OIDC-Authorization-Request-mit-PAR.svg)

(01) Der ZETA Client erzeugt für den äußeren Flow einen PKCE `code_verifier_app`, berechnet daraus
`code_challenge_app = S256(code_verifier_app)` und generiert einen `state_app` zur Bindung von
Anfrage und Antwort.

(02) Der ZETA Client sendet den Authorization Request an den PDP Authorization Server mit
`response_type=code`, `client_id`, `redirect_uri`, `code_challenge_app`,
`code_challenge_method=S256`, den angeforderten `scope`-Werten, `state_app` und dem vom Fach-Client
übergebenen `idp_iss`.

(03) Der PDP Authorization Server erzeugt für den inneren Flow einen eigenen PKCE
`code_verifier_as`, berechnet `code_challenge_as = S256(code_verifier_as)` und generiert `state_as`
sowie eine `nonce`.

(04)–(08) Ist das Entity Statement des sektoralen IDP noch nicht bekannt, ruft der PDP Authorization
Server dessen Entity Statement über `/.well-known/openid-federation` ab und lässt sich über den
`federation_fetch_endpoint` des Federation Master das signierte Entity Statement des IDP bestätigen.
Der PDP Authorization Server validiert die Trust Chain und importiert die Signaturschlüssel des IDP.

(09) Der PDP Authorization Server sendet den Pushed Authorization Request an den PAR-Endpunkt des
sektoralen IDP. Die Authentifizierung des Fachdienstes erfolgt per mTLS
(`self_signed_tls_client_auth`). Der Request enthält `client_id`, `redirect_uri`,
`response_type=code`, `code_challenge_as`, `code_challenge_method=S256`, `scope`, `claims`,
`acr_values` (z. B. `gematik-ehealth-loa-high`), `nonce` und `state_as`.

(10)–(14) Ist das Entity Statement des Fachdienstes beim IDP noch nicht bekannt, ruft der IDP es über
`/.well-known/openid-federation` ab und lässt es sich über den Federation Master bestätigen. Der IDP
validiert die Trust Chain, registriert den Fachdienst per Automatic Registration und importiert
dessen Signatur- und Verschlüsselungsschlüssel.

(15) Der sektorale IDP validiert den PAR (u. a. `redirect_uri`, `scope`, `claims` und das
TLS-Clientzertifikat) und erzeugt eine `request_uri`.

(16) Der IDP antwortet mit `201 Created` und liefert `request_uri` und `expires_in` (Gültigkeit
max. 90 Sekunden) zurück.

(17) Der PDP Authorization Server antwortet dem ZETA Client mit einem `302 Found`. Die `Location`
verweist auf den Authorization-Endpunkt des sektoralen IDP und enthält `client_id` und `request_uri`.

## 5.3.2.5.4 Teilablauf (B): Nutzerauthentisierung am sektoralen IDP

Der ZETA Client delegiert die interaktive Nutzerauthentisierung an das Authenticator-Modul des
sektoralen IDP.

Abbildung 23 Abb-ZETA-OIDC-Nutzerauthentisierung

![Abb-ZETA-OIDC-Nutzerauthentisierung](../../images/zeta-flows/Abb-ZETA-OIDC-Nutzerauthentisierung.svg)

(01) Der ZETA Client öffnet das Authenticator-Modul des sektoralen IDP per Deep-Link bzw.
Universal-Link und übergibt `client_id` und `request_uri`.

(02) Das Authenticator-Modul übermittelt den Authentication Request (`GET /auth` mit `client_id`
und `request_uri`) an den Authorization-Endpunkt des sektoralen IDP.

(03) Der IDP prüft die `request_uri` (Bezug zum zuvor gestellten PAR) und stellt die Consent-Abfrage
gemäß den angeforderten `claims` zusammen.

(04) Der IDP fordert über das Authenticator-Modul die Nutzerauthentisierung und die Consent-Freigabe
an (proprietäres Protokoll des sektoralen IDP).

(05)–(06) Der Nutzer authentisiert sich (z. B. eGK+PIN oder eID) und gibt den Consent frei.

(07) Das Authenticator-Modul bestätigt dem IDP die erfolgreiche Authentisierung.

(08) Der IDP erzeugt einen `AUTHORIZATION_CODE (IDP)` mit einer Gültigkeit von max. 90 Sekunden.

(09) Der IDP antwortet mit einem `302 Found`. Die `Location` verweist auf die `redirect_uri` des
Fachdienstes und enthält `code=AUTH_CODE_IDP` und `state=state_as`.

(10) Das Authenticator-Modul ruft den ZETA Client per App-Link bzw. Universal-Link auf und übergibt
`code=AUTH_CODE_IDP` und `state=state_as`.

## 5.3.2.5.5 Teilablauf (C): Token-Bezug und Ausstellung der ZETA Token

Der PDP Authorization Server löst den Code des IDP ein, entscheidet über die Policy Engine und stellt
dem ZETA Client die DPoP-gebundenen ZETA Token aus.

Abbildung 24 Abb-ZETA-OIDC-Token-Bezug

![Abb-ZETA-OIDC-Token-Bezug](../../images/zeta-flows/Abb-ZETA-OIDC-Token-Bezug.svg)

(01) Der ZETA Client leitet den `AUTHORIZATION_CODE (IDP)` zusammen mit `state=state_as` an den PDP
Authorization Server weiter.

(02) Der PDP Authorization Server löst den Code am Token-Endpunkt des sektoralen IDP ein
(`POST /token` per mTLS, `self_signed_tls_client_auth`) mit `grant_type=authorization_code`,
`code=AUTH_CODE_IDP`, `code_verifier=code_verifier_as`, `client_id` und `redirect_uri`.

(03) Der IDP prüft das TLS-Clientzertifikat, verifiziert `code_verifier_as` gegen `code_challenge_as`
(S256) und invalidiert den `AUTHORIZATION_CODE (IDP)`.

(04) Der IDP antwortet mit `200 OK` und liefert das `id_token` (JWE, ECDH-ES/A256GCM verschlüsselt,
ES256 signiert), ein `access_token`, `token_type=Bearer` und `expires_in` (ID-Token-Gültigkeit
max. 300 Sekunden).

(05) Der PDP Authorization Server entschlüsselt das ID Token, verifiziert dessen Signatur (`kid` /
`x5c`), prüft `iss`, `aud`, `nonce` und `exp` und extrahiert die Identitäts-Claims (z. B. KVNR,
`acr`, `amr`).

(06) Der PDP Authorization Server bereitet die validierten Identitäts-Claims zusammen mit Posture- und
Kontextdaten als Policy Engine Input auf.

(07) Der PDP Authorization Server sendet den Policy Engine Input via `POST /v1/data/authz` an die PDP
Policy Engine.

(08) Die Policy Engine evaluiert die Zugriffsregeln und liefert eine Policy Decision zurück.

Ab hier spaltet sich der Ablauf je nach Policy Decision auf (alt-Block):

**Fall A: [Policy Decision allow] (Schritte 09 – 14)**

(09) Der PDP Authorization Server erzeugt den `AUTHORIZATION_CODE (AS)` des äußeren Flows.

(10) Der PDP Authorization Server antwortet dem ZETA Client mit einem `302 Found`. Die `Location`
verweist auf die `redirect_uri` des Clients und enthält `code=AUTH_CODE_AS` und `state=state_app`.

(11) Der ZETA Client erzeugt ein sitzungsbasiertes DPoP-Schlüsselpaar (`PrK.DPoP.Sig`,
`PuK.DPoP.Sig`) und einen DPoP Proof.

(12) Der ZETA Client löst den `AUTHORIZATION_CODE (AS)` am Token-Endpunkt des PDP Authorization
Server ein (`POST /token`) mit dem `dpop`-Header, `grant_type=authorization_code`,
`code=AUTH_CODE_AS`, `code_verifier=code_verifier_app`, `client_id`, `redirect_uri` sowie einer mit
`PrK.Client.Sig` signierten `client_assertion`.

(13) Der PDP Authorization Server verifiziert `code_verifier_app` gegen `code_challenge_app` (S256),
den DPoP Proof sowie die Client Assertion (Key Binding aus der Dynamic Client Registration).

(14) Der PDP Authorization Server antwortet mit `200 OK` und liefert das DPoP-gebundene
`access_token`, ein `refresh_token`, `token_type=DPoP` und `expires_in`.

**Fall B: [Policy Decision deny] (Schritt 15)**

(15) Verweigert die Policy Engine den Zugriff, antwortet der PDP Authorization Server dem ZETA Client
mit `403 Forbidden` und einer Begründung (`reasons`).

A_2XXXX - ZETA, Ablauf Authentifizierung mobiler Clients (OIDC mit PAR und PKCE)

Der ZETA Guard und der ZETA Client MÜSSEN den Ablauf gemäß den Abbildungen
Abb-ZETA-OIDC-Authentifizierung-mobiler-Clients, Abb-ZETA-OIDC-Authorization-Request-mit-PAR,
Abb-ZETA-OIDC-Nutzerauthentisierung und Abb-ZETA-OIDC-Token-Bezug unterstützen. [<= ]

## 5.3.2.5.6 Empfehlungen für eine gute User Experience

Die folgenden Empfehlungen richten sich an Hersteller mobiler Apps und betreffen das Zusammenspiel von
Fach-Client, ZETA Client und Authenticator-Modul. Sie sind nicht normativ.

### 5.3.2.5.6.1 Klare Aufgabenteilung und ein einziger Einstiegspunkt

- Der Nutzer interagiert ausschließlich mit dem Fach-Client. Der ZETA Client sollte als Bibliothek
  bzw. Hintergrundkomponente ohne eigene sichtbare Oberfläche eingebunden sein, damit der Wechsel
  zwischen den Komponenten für den Nutzer unsichtbar bleibt.
- Die Auswahl des sektoralen IDP (Krankenkasse) erfolgt im Fach-Client. Die zuletzt gewählte
  Krankenkasse sollte gespeichert und vorausgewählt werden, sodass die Auswahl nur einmalig bzw. bei
  Änderung notwendig ist.

### 5.3.2.5.6.2 Nahtlose Sprünge zwischen den Apps

- Für den Wechsel zum Authenticator-Modul und zurück sind ausschließlich **Universal Links (iOS)**
  bzw. **App Links (Android)** zu verwenden (keine Custom-URL-Schemes), um App-Hijacking zu
  verhindern und einen verlässlichen Rücksprung zu garantieren.
- Ist das Authenticator-Modul nicht installiert, sollte der Fach-Client dies erkennen und den Nutzer
  mit einer verständlichen Meldung sowie einem direkten Link zum App-Store führen, statt mit einem
  technischen Fehler abzubrechen.
- Der Rücksprung aus dem Authenticator soll den Nutzer exakt an die Stelle im Fach-Client
  zurückführen, an der er den Vorgang gestartet hat (Erhalt des Anwendungszustands über `state`).

### 5.3.2.5.6.3 Transparenz und Wartezeiten

- Während der ZETA Client im Hintergrund arbeitet (PAR, Token-Bezug, Policy-Entscheidung), sollte der
  Fach-Client einen nicht-blockierenden Fortschrittshinweis anzeigen (z. B. "Sie werden sicher
  angemeldet …").
- Lang laufende Schritte (Federation-Abrufe, Netzlatenz) sollten mit einem Timeout und einer
  Wiederholen-Option versehen sein. Die kurzen Gültigkeiten von `request_uri` und
  `AUTHORIZATION_CODE` (max. 90 s) erfordern eine zügige Nutzerführung; der Nutzer sollte vor dem
  Sprung in den Authenticator darauf hingewiesen werden, die Authentisierung ohne längere
  Unterbrechung abzuschließen.

### 5.3.2.5.6.4 Fehler- und Abbruchbehandlung

- Bricht der Nutzer im Authenticator ab oder verweigert den Consent, muss der Fach-Client den Zustand
  sauber zurücksetzen und eine klare, nicht-technische Meldung anzeigen sowie einen erneuten Versuch
  anbieten.
- Eine `403 Forbidden` der Policy-Entscheidung sollte mit einer fachlich verständlichen Begründung
  (aus `reasons`) übersetzt werden, anstatt rohe Fehlercodes anzuzeigen.
- Abgelaufene `request_uri`/Codes sollten automatisch und transparent zu einem Neustart des Ablaufs
  führen, ohne dass der Nutzer die technischen Hintergründe erfährt.

### 5.3.2.5.6.5 Sitzung und Wiederanmeldung

- Der ZETA Client sollte Access- und Refresh-Token sicher (Keystore/Secure Enclave) verwalten und die
  Session über den Refresh-Token-Flow (Abb-ZETA-Token-Exchange-mit-Refresh-Token) erneuern, damit die
  interaktive Authentisierung über den Authenticator nur dann erforderlich ist, wenn sie
  unvermeidbar ist.
- Vor dem Ablauf der Sitzung kann eine stille Erneuerung im Hintergrund angestoßen werden, um eine
  unterbrechungsfreie Nutzung zu ermöglichen.

### 5.3.2.5.6.6 Barrierefreiheit und Vertrauen

- Alle Hinweise zum App-Wechsel und zur Authentisierung sollten barrierefrei (Screenreader,
  ausreichende Kontraste, Schriftgrößen) gestaltet sein.
- Der Nutzer sollte vor dem ersten Sprung in den Authenticator verständlich darüber informiert
  werden, dass die Anmeldung bei seiner Krankenkasse erfolgt, um Vertrauen herzustellen.
