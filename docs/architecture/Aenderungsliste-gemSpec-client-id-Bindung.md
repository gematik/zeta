# Änderungsliste gemSpec_ZETA — Bindung der `client_id` an Plattform und Attestierungsverfahren

**Stand:** 2026-09-02 · **Bezug:** [gemSpec_ZETA V2.0.0 CC (Draft ZETA 26.2)](https://gemspec.gematik.de/downloads/prereleases/Draft_ZETA_26_2/gemSpec_ZETA_V2.0.0_CC.html)
**Anlass:** Review-Kommentar, dass ein Binding der `client_id` an Plattform und Attestierungsverfahren fehlt.
**Repo-Stand:** Die Annexe sind bereits angepasst (`dcr-request.yaml` 1.1.0, `policy-engine-client-data.yaml` 1.1.0,
`client-statement.yaml` 1.1.0, `zeta-attestation-token.yaml` 1.1.0, `posture-tpm.yaml`,
`zeta-guard-client-management.yaml`, acht DCR-Diagramme, `examples/opa-bundle`). Diese Liste enthält, was **in der
Spezifikation** noch umzusetzen ist.

## Leitplanken

- **Abwärtskompatibel:** Alle neuen Request-Felder sind für Clients SOLL, nie MUSS. Der Authorization Server MUSS
  beide Formen (mit/ohne neues Feld) akzeptieren und das Legacy-Verhalten je Feld beibehalten.
- **Ausnahme ohne Kompatibilitätsproblem:** `attestation_type` und `ak_jkt` werden bei **jeder** Registrierung
  gepinnt — beide ergeben sich aus dem Request selbst (gewählter Schema-Zweig, soeben verifizierter Attestation Key),
  kein Client-Feld nötig.
- **Migration ohne erneute Plattform-Attestierung:** Hardware-Clients migrieren über den Fast-Path
  (`attestation_type: zeta_attestation_token`). Der `attestation_pop` ist eine AK-Signatur (Android/TPM) bzw. eine
  App-Attest-**Assertion** (Apple) — nicht die rate-limitierte Attestierung.
- **Keine Änderung für TPM-Erstregistrierung:** `MakeCredential`/`ActivateCredential` ist bereits Challenge-Response.
  Das sollte im Text stehen, damit die Asymmetrie zu Fast-Path/Software nicht als Lücke gelesen wird.

## A. Zu ändernde Anforderungen

### A_29915 → A_29915-01 (5.5.7) — Prüfung des ZETA Attestation Token durch den Ziel-Guard

Heutiger Text sagt wörtlich: *„der Besitznachweis ist NICHT challenge-gebunden. Der Schutz gegen missbräuchliche
Einlösung ergibt sich aus der Pflicht-Benachrichtigung nach A_29920 (akzeptiertes Restrisiko)."* Das wird durch die
Nonce-Bindung obsolet.

**Nebenbefund korrigieren:** Der heutige Text verlangt in (a) die Signaturprüfung „gegen das Zertifikat eines von der
gematik zugelassenen ZETA Guards (TI-Vertrauensraum/Trust-Liste)". Ein solches Zertifikat gibt es nicht: Der Token wird
mit `PrK.AuthS.Sig` signiert, und Tabelle 4 (5.2.2) sowie A_26281-01 legen fest, dass der zugehörige `PuK.AuthS.Sig` im
JWKS bereitgestellt wird. Der passende Vertrauensanker für guard-übergreifende Signaturen existiert bereits beim HTTP
Proxy (Access Token eines fremden Authorization Servers gültig, wenn dieser „im Entity Statement des Federation Master
aufgeführt ist") und wird hier übernommen. Prüfpunkt (b) setzt den Claim `aud` voraus, den A_29914 fordert; der Annex
`zeta-attestation-token.yaml` definiert ihn erst ab 1.1.0 (siehe E).

**Vorschlag:**

> Der Authorization Server MUSS einen vorgelegten ZETA Attestation Token vollständig prüfen: (a) Signatur gegen einen
> Schlüssel `PuK.AuthS.Sig`, den der ausstellende ZETA Guard (`iss`) über sein JWKS (`jwks_uri` gemäß
> Well-Known-Metadaten) veröffentlicht, wobei der ausstellende ZETA Guard als von der gematik zugelassener ZETA Guard im
> Entity Statement des Federation Master aufgeführt sein MUSS, (b) Empfängerkreis (`aud` = `zeta-guard`), (c) den
> DCR-Besitznachweis `signed_hash_puk_client_sig`, der den neu vorgelegten Instanzschlüssel (F2) bindet, sowie (d) den
> Besitznachweis des attestierten Schlüssels `attestation_pop`. Enthält der Request das Feld `nonce`, MUSS der
> Authorization Server prüfen, dass die Nonce von seinem `nonce_endpoint` stammt, unverbraucht und nicht abgelaufen ist,
> und `attestation_pop` über `SHA-256(PuK.Client.Sig || nonce)` verifizieren. Fehlt `nonce`, MUSS er `attestation_pop`
> über `SHA-256(PuK.Client.Sig)` verifizieren (Legacy-Form) und SOLL die Einlösung protokollieren. Schlägt eine dieser
> Prüfungen fehl, MUSS der Ziel-Guard die Fast-Path-Registrierung ablehnen. Der ZETA Attestation Token ist mehrfach und
> an mehreren Guards einlösbar. Mit `nonce` ist ein mitgeschnittener Registrierungs-Request nicht erneut einlösbar; ohne
> `nonce` bleibt die Wiedereinspielung ein akzeptiertes Restrisiko, das allein durch die Pflicht-Benachrichtigung nach
> A_29920 begrenzt wird. Der ZETA Client SOLL `nonce` setzen.

### A_26585-02 → A_26585-03 (5.8.2) — Client-Daten für die Policy Engine

Heute: Client-Daten gemäß `policy-engine-client-data.yaml` in der PDP-Datenbank verwalten und an die Policy Engine
übergeben.

**Ergänzen:**

> Die identitätsbestimmenden Attribute `posture_type` (= gepinnter `attestation_type`), `platform` und `product_id`
> MÜSSEN aus dem Registrierungsdatensatz stammen und DÜRFEN NICHT aus dem Client Statement der Client Assertion
> übernommen werden, sofern ein gepinnter Wert vorliegt. Der Authorization Server MUSS `binding_status` mit übergeben.
> Für Datensätze mit `binding_status = legacy_unpinned` DARF die Policy Engine aus `posture_type = tpm | apple |
> android` KEIN erhöhtes Vertrauen ableiten.

### A_30005 → A_30005-01 (5.5.7) — Beschränkung der Metadatenaktualisierung

- Liste der abzulehnenden Felder um `attestation_type`, `platform`, `product_id`, `ak_jkt` erweitern.
- **Nebenbefund korrigieren:** Der Text spricht noch von „autorisiert allein durch das Registration Access Token nach
  [RFC7592]"; A_30101 hat das RAT durch die Client Assertion ersetzt.

### A_29901 (5.5.5) — nur Querverweis, keine inhaltliche Änderung

A_29893 beschränkt das gesamte Faktormodell in 5.5.5 auf mobile TOFU-Clients. Das Pinning gilt aber für **alle**
Client-Klassen und gehört deshalb nach 5.8.2 (siehe B.1). In A_29901 genügt ein Verweis: „Die je Client-Instanz
gepinnten Attestierungsattribute regelt A_xxxxx (5.8.2)."

## B. Neue Anforderungen

### B.1 Neu in 5.8.2 — Authorization Server: Pinning der Attestierungsattribute bei der Registrierung

> Der Authorization Server MUSS bei jeder erfolgreichen Client-Registrierung im Registrierungsdatensatz der
> Client-Instanz festhalten: (a) das nachgewiesene Attestierungsverfahren `attestation_type` (im Fast-Path aus dem ZETA
> Attestation Token übernommen), (b) bei Hardware-Attestierung den RFC-7638-Thumbprint des verifizierten Attestation
> Keys (`ak_jkt`), (c) die Plattform (`platform`, aus dem Request oder aus `attestation_type` abgeleitet) sowie (d)
> den gematik-Produktbezeichner `product_id`, sofern im Request übermittelt. Diese Attribute sind über die Lebensdauer
> der `client_id` unveränderlich; ein Wechsel des Attestierungsverfahrens oder der Plattform erfordert eine neue
> Registrierung. Der Authorization Server MUSS `platform` auf Konsistenz mit `attestation_type` prüfen (tpm →
> windows | linux, apple → apple, android → android) und bei Widerspruch die Registrierung ablehnen.

### B.2 Neu in 5.8.2 — Authorization Server: Durchsetzung der Bindung am Token-Endpunkt

> Der Authorization Server MUSS bei jeder Client-Authentisierung am Token-Endpunkt prüfen, dass
> `client_statement.platform` und `client_statement.posture_type` den im Registrierungsdatensatz gepinnten Werten
> entsprechen, und die Anfrage bei Abweichung mit `invalid_client` ablehnen. Die Attestierungs-Evidence des Client
> Statement (TPM-Quote, Apple-Assertion, Android-Signatur) MUSS ausschließlich gegen den gepinnten Attestation Key
> (`ak_jkt`) verifiziert werden; ein im Client Statement mitgelieferter Attestation Key (z. B.
> `posture.tpm_attestation_key`) DARF NICHT als Vertrauensanker verwendet werden und MUSS mit dem gepinnten Schlüssel
> übereinstimmen. Für Datensätze, die vor Einführung des Pinnings angelegt wurden (`binding_status =
> legacy_unpinned`), entfällt der Abgleich; der Authorization Server übernimmt die Werte dann wie bisher aus dem Client
> Statement.

### B.3 Entfällt — Produktreferenz über die gepinnte `product_id` (keine Anforderung an die Spezifikation)

**Entscheidung (2026-09-03):** Die Regeln der Policy Engine werden außerhalb der Spezifikation festgelegt. Eine
Anforderung, die der Policy Engine das Nachschlagen der Herstellerreferenz über die gepinnte `product_id` vorschreibt,
wird deshalb **nicht** in die Spezifikation übernommen. Die Nummer bleibt reserviert, damit die Verweise in dieser
Liste stabil bleiben.

Der Sachverhalt bleibt relevant und wird im Repo umgesetzt: Die Produktregel in `examples/opa-bundle` liest die
gepinnte `product_id` aus `input.client_registration_data` statt aus dem Client Statement der Client Assertion (siehe
E). Damit ist die Zuordnung Signer ↔ Produkt in der Referenz-Policy sichergestellt. Der Spezifikation genügt, was
A_26585-03 und B.1 leisten: Die Policy Engine erhält die gepinnten Werte aus dem Registrierungsdatensatz, nicht aus
der Selbstauskunft des Clients.

Hintergrund (zur Einordnung, nicht normativ): Ohne Zuordnung könnte ein Client `product_id = A` behaupten, während
PCR 23 den Signer von Produkt B zeigt — beide „registriert", aber nicht dasselbe Produkt. Für Apple/Android prüft der
Authorization Server die `product_id` bereits bei der DCR gegen die attestierte App-Identität (rpIdHash bzw.
Package-Name).

### B.4 Neu in 5.5.8 — Authorization Server: Re-Verankerung des Instanzschlüssels beim Rollover

A_29921/A_29922 autorisieren den Rollover allein über den Alt-Schlüssel-PoP. Ein hardware-attestierter Client
verliert damit bei jedem Rollover seine Hardware-Verankerung: `attestation_type` bleibt `tpm | apple | android`, der
aktive Schlüssel ist nur noch software-autorisiert.

> Für Clients mit `attestation_type` ≠ `software` SOLL der ZETA Client im Rollover-Envelope zusätzlich einen
> `attestation_pop` über `SHA-256(neuer PuK.Client.Sig || nonce)` mitführen (Nonce nach A_29923), der gegen den
> gepinnten Attestation Key (`ak_jkt`) verifizierbar ist. Der Authorization Server MUSS einen vorhandenen
> `attestation_pop` prüfen und den Rollover bei Fehlschlag mit `attestationPopRequired` bzw. `invalidBinding`
> ablehnen. Fehlt `attestation_pop`, DARF der Authorization Server den Rollover aus Kompatibilitätsgründen zulassen und
> SOLL den Client dann als nicht mehr hardware-verankert kennzeichnen.

Rate Limits sind nicht betroffen: Apple `generateAssertion` und AK-Signaturen (Android/TPM) unterliegen nicht den
Limits der Attestierungs-APIs.

### B.5 Neu in 5.4.3 — ZETA Client: Nonce-gebundener Besitznachweis bei der Registrierung

> Der ZETA Client SOLL vor einer Registrierung mit `attestation_type = zeta_attestation_token` oder `software` eine
> Nonce vom `nonce_endpoint` des Authorization Servers beziehen, sie im Feld `nonce` des Registrierungs-Requests
> übermitteln und in den signierten Hash des Besitznachweises einbeziehen (`attestation_pop` bzw.
> `signed_hash_puk_client_sig` über `SHA-256(PuK.Client.Sig || nonce)`, Nonce als UTF-8-Bytes). Für
> `attestation_type = tpm` ist keine Nonce vorgesehen (Challenge-Response über
> `MakeCredential`/`ActivateCredential`); für `apple` und `android` ergibt sich die Frische aus der Bindung des
> Instanzschlüssels in `clientDataHash` bzw. `attestationChallenge`.

### B.6 Neu in 5.4.3 / 5.8.2 — Besitznachweis bei Software-Attestierung

Der Software-Zweig von `dcr-request.yaml` 1.0.0 enthält keinen Besitznachweis: Ein Dritter kann einen fremden
öffentlichen Schlüssel registrieren und die spätere Registrierung des Berechtigten per `409 registrationConflict`
blockieren.

> Der ZETA Client SOLL bei einer Registrierung mit `attestation_type = software` den Besitz des Instanzschlüssels
> durch `signed_hash_puk_client_sig` (Selbstsignatur über `SHA-256(PuK.Client.Sig || nonce)`) nachweisen. Der
> Authorization Server MUSS einen vorhandenen Nachweis prüfen und bei Fehlschlag ablehnen; fehlt er, DARF der
> Authorization Server die Registrierung aus Kompatibilitätsgründen annehmen und SOLL das Fehlen protokollieren.

### B.7 Neu in 5.8.2 — Übergangsregel und Auslaufen der Legacy-Formen

> Registrierungsdatensätze, die vor Einführung des Pinnings angelegt wurden, führt der Authorization Server mit
> `binding_status = legacy_unpinned`. Ein solcher Datensatz wechselt nach `pinned`, sobald sich der Client erneut
> registriert; für Hardware-Clients erfolgt dies über den Fast-Path (`attestation_type = zeta_attestation_token`)
> ohne erneute Plattform-Attestierung. Die Legacy-Formen (Registrierung ohne `nonce`, ohne
> `signed_hash_puk_client_sig` im Software-Zweig, Rollover ohne `attestation_pop`) werden zum von der gematik
> festgelegten Stichtag \<Datum/Version\> nicht mehr akzeptiert.

Ohne Stichtag wird aus dem Übergang ein Dauerzustand — das ist die wichtigste Entscheidung in dieser Liste.

## C. Fließtext

### 5.2.2 Übersicht der ZETA Guard Schlüssel

Tabelle 4 nennt als Zweck von `PrK.AuthS.Sig`/`PuK.AuthS.Sig` nur „Signatur von Access- und Refresh-Token sowie des
Entity Statements". Ergänzen: „sowie des ZETA Attestation Token (A_29914)". Damit ist an einer Stelle belegt, welcher
Schlüssel den Token signiert und dass er über das JWKS (nicht über ein Zertifikat) verifiziert wird — Voraussetzung für
A_29915-01 (a).

### 5.3.1.5 Client-Registrierung (stationäre Clients)

Der Abschnitt beschreibt `Abb-ZETA-DCR-für-stationäre-Clients` mit nummerierten Schritten. Das Diagramm wurde in zwei
Punkten geändert: (a) Pinning-Schritt vor „Store Client Placeholder", (b) der Fast-Path ist an
`Abb-ZETA-DCR-für-mobile-Clients` angeglichen — `GET /nonce`, Erzeugung von `signed_Hash_PuK.Client.Sig` und
`attestation_pop` auf dem Client, Nonce-Prüfung und AK-Verifikation des `attestation_pop` im AuthS. Der bisherige
Fast-Path hatte `attestation_pop` weder im Diagramm noch im Text noch im Beispiel, obwohl `dcr-request.yaml` das Feld
im Zweig `zeta_attestation_token` als Pflichtfeld führt; damit wies nichts nach, dass der Registrierende den
Attestation Key besitzt.

**Neue Nummerierung:** (01)–(10) TPM · (11)–(12) macOS · (13) Software · (14)–(24) Fast-Path · (25)–(27) Abschluss.
Die Abschnitte (01)–(12) bleiben unverändert. Ab dem Software-Pfad ersetzt folgender Text den bisherigen:

> **(13) Software-Attestation (Legacy OIDC DCR)**
>
> Im Software-Attestation-Pfad sendet der ZETA Client einen Standard-OIDC-DCR-Request: *[JSON-Beispiel unverändert]*.
> Zusätzlich SOLL der ZETA Client `platform` und `product_id` sowie eine vom `nonce_endpoint` bezogene `nonce` und
> `signed_hash_puk_client_sig` (Selbstsignatur über `SHA-256(PuK.Client.Sig || nonce)` mit `PrK.Client.Sig`)
> übermitteln; der Authorization Server prüft einen vorhandenen Besitznachweis (siehe [dcr-request.yaml], Zweig
> „Software Attestation"). Der Authorization Server legt den Client in der PDP DB an. Erst wenn beim Token Request die
> Policy Engine dem Authorization Server eine `allow: true` Decision übergibt, wird der Client als unterstützter Client
> akzeptiert.
>
> **(14)–(24) Vorbedingung: ZETA Guard Attestation Token vorhanden (Fast-Path)**
>
> Verfügt der ZETA Client über ein gültiges ZETA Guard Attestation Token aus einer vorherigen Authentifizierung, kann
> die erneute Registrierung beschleunigt erfolgen, ohne dass eine erneute Plattform-Attestierung nötig ist.
>
> (14)–(15) Der ZETA Client bezieht eine Nonce vom `nonce_endpoint` des Authorization Servers. (16) Er erzeugt
> `signed_Hash_PuK.Client.Sig` als Selbstsignatur mit `PrK.Client.Sig` über `SHA-256(PuK.Client.Sig || nonce)`.
> (17)–(18) Er lässt denselben Hash mit `PrK.AK.Sig` signieren — bei TPM durch den ZAS, bei macOS als
> App-Attest-Assertion mit `clientDataHash = SHA-256(PuK.Client.Sig || nonce)` — und erhält `attestation_pop`.
> (19) Der ZETA Client sendet `POST /register` mit `attestation_type = "zeta_attestation_token"`, dem Token,
> `PuK.Client.Sig` (in `jwks`), `nonce`, `signed_hash_puk_client_sig` und `attestation_pop`:
>
> *[Beispiel, siehe unten]*
>
> (20) Der Authorization Server prüft die Token-Signatur gegen das JWKS des ausstellenden ZETA Guards (`iss`), dessen
> Zulassung über das Entity Statement des Federation Master sowie `aud = zeta-guard` (A_29915). (21) Er prüft, dass
> die `nonce` von seinem `nonce_endpoint` stammt, unverbraucht und nicht abgelaufen ist. (22) Er prüft
> `signed_Hash_PuK.Client.Sig` als Selbstsignatur mit `PuK.Client.Sig` (Besitznachweis des Instanzschlüssels).
> (23) Er extrahiert `attestation_type` und `PuK.AK.Sig` (`cnf.jwk`) aus dem Token. (24) Er verifiziert
> `attestation_pop` mit `PuK.AK.Sig` über `SHA-256(PuK.Client.Sig || nonce)` — damit ist der neue Instanzschlüssel an
> den bereits attestierten Attestation Key gebunden. Fehlt `nonce`, prüft der Authorization Server abwärtskompatibel
> über `SHA-256(PuK.Client.Sig)` (Legacy-Form, A_29915-01).
>
> **(25)–(27) Abschluss der Registrierung**
>
> (25) Nach erfolgreichem Durchlauf eines der obigen Pfade pinnt der Authorization Server im Registrierungsdatensatz
> der Client-Instanz das nachgewiesene Attestierungsverfahren (`attestation_type`; im Fast-Path aus dem Token
> übernommen), bei Hardware-Attestation den RFC-7638-Thumbprint des verifizierten Attestation Keys (`ak_jkt`), die
> Plattform (`platform`, aus dem Request oder aus `attestation_type` abgeleitet) sowie `product_id`, sofern übermittelt
> (`binding_status = pinned`). Diese Attribute sind über die Lebensdauer der `client_id` unveränderlich; ein Wechsel
> des Attestierungsverfahrens oder der Plattform erfordert eine neue Registrierung. Beim Token Request prüft der
> Authorization Server `client_statement.platform` und `posture_type` gegen die gepinnten Werte und verifiziert die
> Attestierungs-Evidence ausschließlich gegen `ak_jkt` (vgl. A_xxxxx, Kapitel 5.8.2). (26) Der Authorization Server
> legt den Client an. (27) Er antwortet mit `201 Created {client_id}`.

**Beispiel für Schritt (19)** — ersetzt das bisherige Beispiel. Es zeigt einen stationären Windows-Client mit
TPM-Attestierung; `redirect_uris` entfallen, da stationäre Clients den Token Exchange nutzen (das bisherige Beispiel
trug App-Links aus dem mobilen Fall):

```json
{
  "attestation_type": "zeta_attestation_token",
  "client_name": "ZETA Secure Desktop Agent v1.2",
  "token_endpoint_auth_method": "private_key_jwt",
  "grant_types": [
    "urn:ietf:params:oauth:grant-type:token-exchange",
    "refresh_token"
  ],
  "jwks": {
    "keys": [
      {
        "kty": "EC",
        "crv": "P-256",
        "x": "11qYAYKxCrfVS_7TyWQHOg7hcvPapiMlrwIaaPcHURo",
        "y": "eZXwxvO1hvCY0KucrPfKo7yAyMT6Ajc3N7OkAB6VYy8",
        "use": "sig",
        "kid": "client-key-tpm-002"
      }
    ]
  },
  "platform": "windows",
  "product_id": "gematik-desktop-suite-win-v3",
  "product_version": "3.5.0",
  "zeta_attestation_token": "ey...",
  "nonce": "n-0S6_WzA2Mj",
  "signed_hash_puk_client_sig": "MEQ...",
  "attestation_pop": "MEU..."
}
```

Erläuterung der Felder zum Beispiel: `zeta_attestation_token` ist der vom Quell-Guard ausgestellte Token
(`attestation_type = "tpm"`, `cnf.jwk = PuK.AK.Sig`, `aud = "zeta-guard"`); `nonce` stammt aus `GET /nonce`;
`signed_hash_puk_client_sig` ist die Base64url-kodierte ECDSA-Signatur mit `PrK.Client.Sig` über
`SHA-256(PuK.Client.Sig || nonce)`; `attestation_pop` ist die Base64url-kodierte Signatur mit `PrK.AK.Sig` über
denselben Hash, bei `attestation_type = "apple"` stattdessen das Base64-kodierte CBOR-Assertion-Objekt.

A_29375 bleibt unverändert (Verweis auf die Abbildung).

### 5.3.2.2 Client Registrierung und Authentifizierung

Der Abschnitt beschreibt `Abb-ZETA-DCR-für-mobile-Clients` als durchnummerierte Schrittliste (01)–(26). Die
Diagrammänderung fügt im Fast-Path `GET /nonce`, `200 OK {nonce}` und `Prüfe nonce` ein sowie vor dem Abschluss den
Schritt „Pinne attestation_type, platform, product_id, ak_jkt" — **die Nummerierung ab dem Fast-Path verschiebt
sich**. Konkret:

- Neue Schritte vor dem heutigen (20): Nonce beziehen und erhalten.
- Heutiger Schritt (20): Request-Felder um `nonce` ergänzen.
- Neuer Schritt nach (21): Nonce prüfen.
- Heutiger Schritt (24): `clientDataHash == SHA-256(PuK.Client.Sig || nonce)`.
- Heutiger Schritt (25): „Signatur über SHA-256(PuK.Client.Sig || nonce)".
- Neuer Schritt vor (26): Pinning der Attestierungsattribute.
- In den Hardware-Pfaden (Apple, Android) und im Software-Pfad je einen Pinning-Schritt vor dem `201 Created`.

**Vorbestehende Inkonsistenzen im selben Abschnitt, in derselben Runde bereinigen:**

1. Schritte (12)–(19) legen das E-Mail-OTP in `POST /register`, und (01)/(04)/(12) führen „die Nutzer-E-Mail" als
   Registrierungsparameter. Das Diagramm ist seit v2.0.1 weiter: OTP ist nicht mehr Teil von `/register`, die
   E-Mail-Bindung erfolgt nach dem OIDC-Flow über `/zeta/identity/bind-email`.
2. Die Einleitung nennt „Wiederherstellungscode (Recovery Code / Faktor F3)"; 5.5.5 und der Annex legen den
   Faktorsatz auf {F1, F2} fest.

### 5.5.5 Vertrauensmodell

Ein Satz nach der Faktorliste: Die bei der Registrierung gepinnten Attestierungsattribute (`attestation_type`,
`ak_jkt`, `platform`, `product_id`) sind **kein** Faktor, sondern eine Bindungsinvariante der Client-Instanz; sie
werden nicht nachgewiesen, sondern durchgesetzt (A_xxxxx, 5.8.2).

### 5.5.7 Folgeregistrierung

- Absatz „Da der Pfad über den Instanzschlüssel (F2) verankert ist … mindestens so stark wie die
  E-Mail-OTP-Erstnutzung": ergänzen, dass der Besitznachweis mit `nonce` zusätzlich challenge-gebunden ist.
- Schluss-Hinweis „ist die Benachrichtigung des Identitätsinhabers die maßgebliche Erkennungs- und
  Widerspruchsmöglichkeit": relativieren — maßgeblich nur noch für Einlösungen ohne `nonce`; mit `nonce` ist die
  Wiedereinspielung ausgeschlossen, die Benachrichtigung bleibt Defense-in-Depth gegen ein missbräuchliches Vouching
  eines kompromittierten Quell-Guards.

### 5.5.8 Schlüssel-Rollover

Hinweis „Der Client Instance Key soll initial 2 Jahre gültig sein": ergänzen, dass Hardware-Clients beim Rollover die
Verankerung im Attestation Key per `attestation_pop` erneuern (B.4).

### 5.8.2 PDP Authorization Server

Hinweis zu A_25649 (Rate Limits der mobilen Attestation Services): ergänzen, dass Fast-Path-Migration und Rollover
nur Assertions/AK-Signaturen benötigen und daher nicht von den Limits betroffen sind.

### Stelle prüfen: Herstellerregistrierung

Wo die Spezifikation beschreibt, was der Hersteller bei der gematik registriert (`product_id`, Produktversionen, bei
TPM den Code-Signatur-Schlüssel des Primärsystems), sollte stehen, dass diese Werte über die gepinnte `product_id`
(B.1) als Referenz in die Policies eingehen. Die Auswertung selbst ist Sache der Policy Engine und nicht Gegenstand der
Spezifikation (B.3). Im Repo ist der Meldeprozess nur in `ReadMePrimaersystemHersteller.md` beschrieben und dort als
„noch nicht vollständig spezifiziert" markiert.

## D. Abbildungen

Alle Abbildungen der Spezifikation stammen aus `src/plantuml/zeta-flows/` und werden per Workflow
`automatic_image_generation.yml` gerendert — nie SVG/PNG von Hand ändern. Geänderte Quellen:

| Diagramm | Änderung |
| --- | --- |
| `Abb-ZETA-DCR-für-mobile-Clients` | Fast-Path: Nonce-Schritte, nonce-gebundener Hash, Pinning; HW-Zweig: Pinning. **Treibt die Nummerierung in 5.3.2.2.** |
| `Abb-ZETA-DCR-für-mobile-SW-Att-Clients` | `GET /nonce`, Request-Felder, PoP-Prüfung, Pinning, Kompatibilitätsnotiz |
| `Abb-ZETA-DCR-für-stationäre-SW-Att-Clients` | wie vor, zusätzlich Client-seitige Signaturerzeugung |
| `Abb-ZETA-DCR-für-mobile-Apple-HW-Att-Clients` | Pinning-Schritt |
| `Abb-ZETA-DCR-für-mobile-Android-HW-Att-Clients` | Pinning-Schritt |
| `Abb-ZETA-DCR-für-stationäre-Apple-Clients` | Pinning-Schritt |
| `Abb-ZETA-DCR-für-stationäre-Win-Linux-Clients-TPM-Att` | Pinning-Schritt |
| `Abb-ZETA-DCR-für-stationäre-Clients` | Pinning-Schritt (nach dem alt/else); Fast-Path an das mobile Diagramm angeglichen (`GET /nonce`, `attestation_pop`, Nonce-Prüfung, AK-Verifikation). **Treibt die Nummerierung in 5.3.1.5.** |

Nicht geändert, aber in der Spec zu prüfen: `Abb-ZETA-Token-Exchange-mit-Attestation` — falls dort ein Schritt
„Key-Bindings aus der DCR prüfen" existiert, sollte er den Abgleich gegen die gepinnten Attribute benennen.

## E. Annex-Verweise aktualisieren

| Annex | Version | Änderung |
| --- | --- | --- |
| `dcr-request.yaml` | 1.0.0 → 1.1.0 | optionale Felder `nonce`, `platform`, `product_id`, `product_version`; `signed_hash_puk_client_sig` im Software-Zweig; `attestation_pop` mit beiden Hash-Formen |
| `policy-engine-client-data.yaml` | 1.0.0 → 1.1.0 | Herleitung aus Registrierungsdatensatz; optionales `binding_status` |
| `client-statement.yaml` | 1.0.0 → 1.1.0 | `platform`/`posture_type` müssen gepinnten Werten entsprechen |
| `zeta-attestation-token.yaml` | 1.0.0 → 1.1.0 | Angleichung an A_29914: Pflicht-Claim `aud` (`zeta-guard`), `email_verified` (Pflicht bei `user_email`), `iss`/`sub` beschrieben, Signaturmodell (JWKS des Ausstellers) dokumentiert; Altfehler im `cnf.jwk`-Block behoben |
| `posture-tpm.yaml` | — (nur Beschreibung) | `tpm_attestation_key` ist kein Trust Anchor |
| `zeta-guard-client-management.yaml` | 0.1.0-draft | `ClientRegistration` um Pinning-Attribute und `binding_status`; Pinning-Absatz; Nonce-Bindung; Rollover-`attestation_pop`; Fehlercode `attestationPopRequired` |
| `examples/opa-bundle` | — | Produktregel liest `input.client_registration_data` statt `input.client_assertion.posture` |

## F. Offen — nicht in dieser Runde lösbar

- **Byte-Repräsentation von `PuK.Client.Sig`** im Hash `SHA-256(PuK.Client.Sig)` ist auch für die Legacy-Form nirgends
  festgelegt (`posture-software.yaml` nutzt andernorts den JWK-Thumbprint-Input). Muss normativ definiert werden,
  sonst sind Implementierungen nicht interoperabel.
- **`product_id` bei Software-Attestierung** bleibt eine unveränderliche, aber unbelegte Selbstauskunft — prinzipbedingt.
- **Integrität des ZAS selbst** ist in `Szenarienanalyse-TPM-Hash-vs-Code-Signatur.md` als offener Punkt geführt und
  unabhängig von dieser Änderung.
