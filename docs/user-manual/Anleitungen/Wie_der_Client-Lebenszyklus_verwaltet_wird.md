# Wie der Client-Lebenszyklus verwaltet wird

Jede Client-Instanz durchläuft am ZETA Guard denselben Lebenszyklus: Sie
registriert sich per
[dynamischer Client-Registrierung](Wie_die_dynamische_Client-Registrierung_funktioniert.md),
ist zunächst unattestiert (`PENDING`), wird mit der ersten erfolgreichen
Anmeldung attestiert (`VALID`) und verschwindet am Ende wieder — durch
Idle-Ablauf, durch Verdrängung beim Erreichen des Client-Limits oder durch
aktiven Widerruf ihrer Sitzungen.

Diese Anleitung beschreibt, wie der Guard diesen Lebenszyklus serverseitig
verwaltet, welche Stellschrauben Betreiber haben und wie sich Löschungen und
administrative Eingriffe nachvollziehen lassen.

## Trust On First Use

Der Guard kennt eine Client-Instanz vor ihrer Registrierung nicht — es gibt
kein vorab verteiltes Geheimnis pro Instanz. Das Vertrauen entsteht bei der
Erstregistrierung (Trust On First Use): Die Instanz erzeugt ihren
Instanzschlüssel im Hardware-Schlüsselspeicher, registriert den öffentlichen
Teil und weist bei jeder späteren Nutzung den Besitz des privaten Schlüssels
nach (`private_key_jwt`, DPoP).

Die eigentliche Attestierung — also der Nachweis, dass es sich um eine
legitime, unveränderte Client-Software handelt — erfolgt je nach Client-Typ:

- **SMC-B-Maschinenclients** liefern beim ersten Token Exchange ein
  SMC-B-signiertes Client Statement; erst danach gilt die Registrierung als
  attestiert und der `refresh_token`-Grant wird freigeschaltet.
- **Mobile Clients** sollen ihre Plattform-Attestierung bereits bei der
  Registrierung nachweisen. Diese Prüfung ist derzeit **gemockt**: Jede
  Registrierung mit Redirect-URIs wird akzeptiert (siehe
  [Aktueller Stand](#aktueller-stand-und-einschränkungen)).

## Client-Limits und automatische Löschung

**Client-Limit pro Nutzer:** Pro Nutzer (Telematik-ID bzw. mobiler Identität)
sind höchstens `SMCB_USER_MAX_CLIENTS` Registrierungen erlaubt (Standard: 256).
Das Limit wird bei der Anmeldung geprüft, wenn ein neuer Client dem Nutzer
zugeordnet wird. Wird es überschritten, wird die neue Registrierung **nicht
abgelehnt**; stattdessen verdrängt der Guard die am längsten nicht mehr
verwendete Registrierung dieses Nutzers (LRU, frühester `lastAccess`). Die
Verdrängung erzeugt das Security-Event `authn_client_deleted` mit Grund
`max_clients_exceeded` (siehe
[Security-Events](../Referenzen/Security-Events.md)). Nur wenn die Verdrängung
fehlschlägt, wird die Anmeldung mit dem Security-Event
`authn_client_registration_fail` (Grund `too_many_clients_registered`)
abgewiesen.

**Ablauf ungenutzter Registrierungen:** Ein wiederkehrender Job räumt ab:

- Registrierungen, die im Attestierungsstatus `PENDING` verharren, nach
  `CLIENT_REGISTRATION_TTL` (Standard: 5 Minuten) — sie erzeugen das
  Security-Event `authn_client_registration_fail` mit Grund
  `registration_expired`,
- attestierte, aber inaktive Clients nach `SMCB_IDLE_CLIENT_TTL`
  (Standard: 1 Jahr),
- inaktive Nutzer samt ihrer Datensätze nach `SMCB_IDLE_USER_TTL`
  (Standard: 1 Jahr).

Der Job läuft im Intervall `CLIENT_REGISTRATION_SCHEDULER_INTERVAL`
(Standard: 5 Minuten), frühestens `CLIENT_REGISTRATION_STARTUP_DELAY`
(Standard: 20 Sekunden) nach dem Serverstart. `lastAccess` wird bei jeder
erfolgreichen Anmeldung bzw. jedem Token Exchange fortgeschrieben. Für Wartungsfenster lässt sich
der Job über das Realm-Attribut `zeta-guard.realm.client_job.disabled=true`
vorübergehend aussetzen. Alle Variablen sind in der
[Konfiguration des PDP Services](../Referenzen/Konfiguration_des_PDP_Services.md)
beschrieben.

## E-Mail-Bindung und -Änderung

Mobile Clients binden ihre Identität bei der ersten Anmeldung an eine
E-Mail-Adresse (OTP-Verfahren) und können die Adresse später identitätsweit
ändern; die Änderung entfernt parallele Registrierungen derselben Identität
mit offener OTP-Challenge und erzeugt das Security-Event `authn_email_change`.
Ablauf, Endpunkte und Einschränkungen sind in
[Wie der mobile Client-Flow funktioniert](Wie_der_mobile_Client-Flow_funktioniert.md)
beschrieben und werden hier nicht wiederholt.

## Sitzungen widerrufen

Für den Fall eines kompromittierten Access Tokens stellt der PDP eine
Fleet-Revocation-API bereit — beide Verben liegen auf derselben URI:

```
/realms/{realm}/zeta-guard-revocation
```

**Token melden (POST):** Der Body ist das betroffene Access Token als
`text/plain`, ohne weitere Autorisierung — die Berechtigung ist der Besitz
eines von diesem Realm signierten Tokens. Der PDP prüft die Signatur gegen die
Realm-Schlüssel (fremde oder unsignierte Tokens können nichts widerrufen),
beendet die zugehörige Session über Keycloak und blockiert die Session-ID bis
zum Ablauf (`exp`) des gemeldeten Tokens. Antwort bei Erfolg: `204 No Content`.

```bash
curl -X POST "https://<as-host>/realms/zeta-guard/zeta-guard-revocation" \
  -H "Content-Type: text/plain" \
  --data "$ACCESS_TOKEN"
```

**Blockliste abonnieren (GET):** Enforcement Points (der PEP HTTP Proxy)
abonnieren die Blockliste als Server-Sent-Events-Stream. Beim Verbindungsaufbau
liefert der Stream zunächst einen Snapshot aller aktiven Blocks und danach
Deltas; ein Reconnect ist damit zugleich der Abgleichmechanismus. Alle
20 Sekunden hält ein Kommentar-Heartbeat die Verbindung offen.

```bash
curl -N -H "Accept: text/event-stream" \
  "https://<as-host>/realms/zeta-guard/zeta-guard-revocation"
```

Jedes Event ist ein JSON-Objekt mit `when` (Meldezeitpunkt), `until` (Ende des
Blocks, Unix-Sekunden) und `what` (Session-ID).

Nicht nur gemeldete Tokens erzeugen Blocks: Der Event-Listener
**`zeta-guard-revocation-events`** übersetzt auch Logouts, Grant-Widerrufe und
das Löschen von Sessions über die Admin-API in Blocks, damit die Enforcement
Points jeden Widerruf erfahren, egal wer ihn ausgelöst hat. Solche Blocks
werden pauschal eine Stunde gehalten. Sessions, die regulär ihr
Lebenszeitende erreichen, erzeugen keinen Block.

Betriebsvoraussetzungen:

- Der Realm muss `zeta-guard-revocation-events` in seinen `eventsListeners`
  führen. Die ausgelieferten Provisionierungsskripte richten das ein; ohne den
  Listener erzeugt nur der Melde-Endpunkt Blocks.
- Die Blocks liegen im Infinispan-Cache `zetaGuardRevocations`. Im
  Embedded-Modus legt der PDP ihn selbst an; bei dediziertem Infinispan muss
  der Cache auf dem Server existieren. Ein fehlender Cache lässt den Start
  fehlschlagen (fail closed), statt Meldungen ins Leere laufen zu lassen.

## Nachvollziehbarkeit

Alle administrativen Änderungen am Realm — dazu zählen auch die von der
Registration-Policy angelegten und vom Expiration-Job gelöschten Clients —
werden vom Event-Listener `zeta-guard-admin-events` in einer
**hash-verketteten** Ereignisliste in der Datenbank protokolliert: Jeder
Eintrag enthält den SHA-256-Hash über Zeitstempel, Vorgänger-Hash und
Event-Inhalt. Der erste Eintrag wird mit dem geheimen Seed **`GENESIS_HASH`**
verkettet, der nur als Umgebungsvariable vorliegt und nicht in der Datenbank
gespeichert wird — nachträgliche Manipulationen am Log brechen die Kette und
sind ohne Kenntnis des Seeds nicht reparierbar. Zum Setzen des Seeds siehe die
[Konfiguration des PDP Services](../Referenzen/Konfiguration_des_PDP_Services.md).

## Client-seitige Abmeldung

Das ZETA SDK bietet zwei Stufen, eine Client-Instanz lokal zurückzusetzen
(siehe [Wie Sie das ZETA SDK integrieren](Wie_Sie_das_ZETA_SDK_integrieren.md)):

- **`clearRegistration()`** löscht Registrierung, Tokens, DPoP-Schlüssel und
  ASL-Session, behält aber den Instanzschlüssel. Beim nächsten Zugriff
  registriert sich das SDK neu.
- **`forget()`** löscht zusätzlich den Instanzschlüssel und alle gespeicherten
  Daten zum Guard — der nächste Zugriff verhält sich wie eine Erstinstallation.

Beide wirken nur lokal: Das SDK ruft keinen serverseitigen Löschendpunkt auf
(es nutzt kein RFC 7592, siehe
[dynamische Client-Registrierung](Wie_die_dynamische_Client-Registrierung_funktioniert.md)).
Die zurückgelassene Registrierung verschwindet serverseitig erst über die
Idle-TTL oder die LRU-Verdrängung.

## Aktueller Stand und Einschränkungen

- **Die Attestierung mobiler Clients ist gemockt**, damit ist auch das
  TOFU-Vertrauen für mobile Registrierungen derzeit nicht belastbar.
  `ZETA_OIDC_FLOW_ENABLED` sollte in produktiven Umgebungen deaktiviert
  bleiben.
- Es gibt **keinen client- oder betreiberseitigen Endpunkt, um eine einzelne
  Registrierung gezielt zu löschen** — das SDK nutzt kein RFC 7592, und eine
  eigene Admin-Fachschnittstelle dafür existiert nicht. Registrierungen
  verschwinden regulär nur über die Idle-TTLs oder die LRU-Verdrängung.
- Die Revocation-API widerruft **Sitzungen, nicht Registrierungen**: Ein
  gemeldetes Token beendet die Session, die Client-Registrierung bleibt
  bestehen und kann sich neu anmelden.
- Blocks aus Keycloak-Ereignissen (Logout, Grant-Widerruf, Session-Löschung)
  werden pauschal eine Stunde gehalten. Vergibt eine OPA-Policy Access Tokens
  mit mehr als einer Stunde Lebensdauer, wäre deren Restlaufzeit nicht
  abgedeckt.
- Der Melde-Endpunkt akzeptiert jedes gültig signierte Token des Realms ohne
  weitere Autorisierung; ein eigenes Rate Limiting existiert nicht.
