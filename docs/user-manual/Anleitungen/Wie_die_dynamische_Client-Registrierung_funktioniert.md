# Wie die dynamische Client-Registrierung funktioniert

Jede Client-Instanz — das Primärsystem einer Leistungserbringerinstitution ebenso
wie eine mobile App — registriert sich selbst beim Authentication Service (PDP)
des ZETA Guards, bevor sie Tokens anfordern kann. Die Registrierung folgt der
Dynamic Client Registration (DCR) nach
[RFC 7591](https://www.rfc-editor.org/rfc/rfc7591) und läuft über den
Keycloak-Endpunkt

```
POST /realms/{realm}/clients-registrations/openid-connect
```

(Realm-Name in der Standardauslieferung: `zeta-guard`). Clients sollten den
Endpunkt nicht fest verdrahten, sondern als `registration_endpoint` aus dem
Discovery-Dokument `/.well-known/oauth-authorization-server` beziehen — so macht
es auch das ZETA SDK (siehe
[Konfiguration der Well-Known-Endpunkte](../Referenzen/Konfiguration_der_Well-Known_Endpunkte.md)).

Die Registrierung ist anonym: Es ist kein Initial Access Token nötig. Die
Guard-eigene Registration-Policy `zeta-client-registration-policy` richtet jeden
neu registrierten Client automatisch ein und ersetzt die
Keycloak-Standard-Policies (Trusted Hosts, Consent Required, Max Clients), die
bei der Provisionierung entfernt werden. Ein Limit greift stattdessen pro
Nutzer bei der ersten Anmeldung des Clients (siehe
[Wie der Client-Lebenszyklus verwaltet wird](Wie_der_Client-Lebenszyklus_verwaltet_wird.md)).

Die Erkennung mobiler Clients ist über die Umgebungsvariable
**`ZETA_OIDC_FLOW_ENABLED`** geschaltet (Standard: `false`). Solange sie nicht
gesetzt ist, wird jede Registrierung — auch eine mit `redirect_uris` — als
SMC-B-Maschinenclient eingerichtet.

## Ablauf

1. **Request:** Der Client sendet ein JSON-Dokument mit seinen Metadaten. Die
   wesentlichen Felder:
   - `token_endpoint_auth_method`: `private_key_jwt` — der Client
     authentifiziert sich später am Token-Endpunkt mit einem selbst signierten
     JWT statt mit einem Client Secret.
   - `jwks`: der öffentliche **Client-Instanzschlüssel**. Das ZETA SDK erzeugt
     ihn im Hardware-Schlüsselspeicher der Plattform (TPM, Secure
     Enclave/Secure Element bzw. als Software-Fallback) und exportiert nur den
     öffentlichen Teil.
   - `grant_types`: das SDK registriert `authorization_code`,
     `urn:ietf:params:oauth:grant-type:token-exchange` und `refresh_token`.
   - `redirect_uris`: nur bei mobilen Clients (siehe Schritt 3).
   - `client_name`: frei wählbarer Anzeigename.

   Beispiel (Maschinenclient, gekürzt):

   ```bash
   curl -X POST "https://<as-host>/realms/zeta-guard/clients-registrations/openid-connect" \
     -H "Content-Type: application/json" \
     -d '{
       "token_endpoint_auth_method": "private_key_jwt",
       "grant_types": ["urn:ietf:params:oauth:grant-type:token-exchange", "refresh_token"],
       "response_types": ["token"],
       "client_name": "Mein Primärsystem",
       "jwks": { "keys": [ { "kid": "…", "kty": "EC", "use": "sig", "…": "…" } ] }
     }'
   ```

2. **Vorprüfungen:** Ist der Integrity Provider aktiviert, aber (noch) nicht
   betriebsbereit — etwa direkt nach dem Start —, lehnt der Guard die
   Registrierung mit **`503 Service Unavailable`** ab und erzeugt das
   Security-Event `authn_client_registration_fail` (Grund
   `integrity_provider_unavailable`). Der Client sollte den Versuch später
   wiederholen; das ZETA SDK tut das automatisch (siehe unten).

3. **Client-Typ-Erkennung:** Die Policy unterscheidet anhand der
   `redirect_uris` (nur bei aktivem `ZETA_OIDC_FLOW_ENABLED`):
   - **ohne `redirect_uris`** → SMC-B-Maschinenclient (Primärsystem). Die
     Attestierung erfolgt später beim ersten Token Exchange über das
     SMC-B-signierte Client Statement.
   - **mit `redirect_uris`** → mobiler Client. Die Registrierung durchläuft
     eine Attestierungsprüfung, die derzeit **gemockt** ist (siehe unten), und
     der Client wird für die Anmeldung über den sektoralen IDP eingerichtet —
     Details in
     [Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md).

4. **Automatische Einrichtung:** Die Policy setzt für **jeden** Client:
   - **DPoP-Bindung** (`dpop.bound.access.tokens=true`) — alle Access Tokens
     sind an den DPoP-Schlüssel des Clients gebunden,
   - Token-Exchange-Refresh nur innerhalb derselben Session (`SAME_SESSION`).

   Für **mobile** Clients zusätzlich:
   - den Browser-Flow `zeta-mobile` (erzwungene SekIDP-Weiterleitung),
   - die Client-Scopes `zeta:email-binding` und `zeta:email-verify` für die
     E-Mail-Bindung,
   - Standard-Token-Exchange sowie ein derzeit fest hinterlegtes (gemocktes)
     Client Statement.

5. **Antwort:** Bei Erfolg antwortet der Server mit `201 Created`. Die Antwort
   enthält insbesondere die zugeteilte **`client_id`** — sie ist der Bezeichner
   der Client-Instanz für alle folgenden Token-Requests — sowie ein
   `registration_access_token` (siehe „Verwaltung der Registrierung“). Der Guard
   protokolliert das Security-Event `authn_client_registered` (siehe
   [Security-Events](../Referenzen/Security-Events.md)).

## Registrierungsstatus und Lebensdauern

Zu jedem Client führt der Guard einen Attestierungsstatus:

| Status    | Bedeutung                                                              |
|-----------|------------------------------------------------------------------------|
| `PENDING` | registriert, aber noch nicht attestiert (Zustand direkt nach der DCR)   |
| `VALID`   | attestiert; voller Grant-Umfang                                         |
| `INVALID` | keine Token-Ausstellung möglich                                         |

Ein SMC-B-Client wechselt beim ersten erfolgreichen Token Exchange (mit
SMC-B-signiertem Client Statement) von `PENDING` auf `VALID`; solange er
`PENDING` ist, ist ausschließlich der Token-Exchange-Grant zugelassen, kein
`refresh_token`. Ein mobiler Client ist wegen der (derzeit gemockten)
Attestierungsprüfung sofort nach der Registrierung `VALID`; sein
E-Mail-Bindungsstatus (`EMAIL_CONFIRMATION_REQUIRED` → `OTP_PENDING` →
`CONFIRMED`) wird separat geführt, siehe
[Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md).

Registrierungen, die im Status `PENDING` verharren, räumt ein Scheduler nach
Ablauf von `CLIENT_REGISTRATION_TTL` (Standard: 5 Minuten) wieder ab. Auch
attestierte, aber ungenutzte Clients und Nutzer verfallen nach den Idle-TTLs
(`SMCB_IDLE_CLIENT_TTL`/`SMCB_IDLE_USER_TTL`, Standard: 1 Jahr). Die Variablen
sind in der
[Konfiguration des PDP Services](../Referenzen/Konfiguration_des_PDP_Services.md)
beschrieben, das Verhalten in
[Wie der Client-Lebenszyklus verwaltet wird](Wie_der_Client-Lebenszyklus_verwaltet_wird.md).

## Verwaltung der Registrierung (RFC 7592)

Die Registrierungsantwort enthält ein `registration_access_token` und eine
`registration_client_uri`. Darüber ließe sich die Registrierung nach
[RFC 7592](https://www.rfc-editor.org/rfc/rfc7592) auslesen, ändern oder
löschen.

Das **ZETA SDK nutzt diesen Mechanismus nicht.** Es speichert die
Registrierungsantwort lokal pro Registrierungsendpunkt zusammen mit der `kid`
des verwendeten Instanzschlüssels. Vor jeder Nutzung prüft es, ob die
gespeicherte Registrierung mit dem aktuellen Instanzschlüssel erstellt wurde;
hat sich der Schlüssel geändert (Schlüsselrotation, neu aufgesetztes Gerät,
gelöschter Schlüsselspeicher), **registriert es sich schlicht neu** und erhält
eine neue `client_id`. Die alte Registrierung bleibt serverseitig liegen, bis
sie über die Idle-TTL oder die Verdrängung beim Client-Limit abgeräumt wird.

Schlägt die Registrierung fehl, versucht das SDK sie bis zu **3-mal** mit
steigender Wartezeit (1 s, 2 s) erneut. Bei `403` (abgelehnt) und `409`
(bereits registriert) bricht es sofort ab, ohne erneut zu versuchen.

## Zusammenspiel mit der Token-Ausstellung

Die Registrierung allein berechtigt noch zu nichts — sie legt nur fest, wie die
Instanz sich später ausweist:

- **Client-Authentisierung:** an allen Token-Endpunkten per `private_key_jwt`
  (Client Assertion, signiert mit dem registrierten Instanzschlüssel).
- **SMC-B-Maschinenclients** verwenden den Grant
  `urn:ietf:params:oauth:grant-type:token-exchange`: Sie tauschen ein
  SMC-B-signiertes Subject Token gegen den Token-Satz des Guards. Jede
  Ausstellung durchläuft die OPA-Policy-Entscheidung; auch der
  `refresh_token`-Grant autorisiert bei jedem Refresh erneut über OPA.
- **Mobile Clients** verwenden den `authorization_code`-Grant. Der
  Authorization Request läuft über PAR (Pushed Authorization Requests); das
  Well-Known-Dokument weist `require_pushed_authorization_requests: true` aus.
- **Alle Access und Refresh Tokens sind DPoP-gebunden** (RFC 9449); der Client
  muss bei jedem Token-Request einen DPoP-Proof mitschicken.
- Tokens werden mit **ES256** signiert; in produktiven Deployments liegt der
  Signaturschlüssel im HSM. Ist das HSM aktiviert, aber nicht erreichbar,
  antwortet der Token-Endpunkt fail-closed mit `503` und `Retry-After: 30`,
  statt auf einen Software-Schlüssel auszuweichen.

## Aktueller Stand und Einschränkungen

- **Die Attestierung mobiler Clients ist gemockt:** Jede Registrierung mit
  `redirect_uris` wird akzeptiert (die Attestierungsdaten des Requests werden
  nicht ausgewertet) und erhält ein fest hinterlegtes Client Statement.
  `ZETA_OIDC_FLOW_ENABLED` sollte in produktiven Umgebungen deaktiviert
  bleiben, bis die echte Attestierungsprüfung umgesetzt ist.
- **Resource Indicators (RFC 8707) sind nicht implementiert:** Das
  Well-Known-Dokument weist unter `api_versions_supported` nur die
  Token-Ausstellungs-Vertragsversion 1 aus (A_29691); dienstspezifische
  Audiences per `resource`-Parameter (Vertragsversion 2) fehlen noch.
- `require_pushed_authorization_requests: true` wird ausgewiesen, aber noch
  nicht pro Client erzwungen.
- Die Registrierung ist anonym und ohne eigenes Rate Limiting; die Begrenzung
  greift erst pro Nutzer über `SMCB_USER_MAX_CLIENTS` bei der Anmeldung (siehe
  [Wie der Client-Lebenszyklus verwaltet wird](Wie_der_Client-Lebenszyklus_verwaltet_wird.md)).
