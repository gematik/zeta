# Client Management auf dem implementierten ZETA-Keycloak-Stand – Architekturübersicht (Vorschlag)

**Stand:** 2026-09-21 · **Revision 3a** (Konsistenzprüfung) (setzt auf dem implementierten Stand von `keycloak-zeta` auf: OTP in der App über `/register` und `/register/verify`, Fast Path mit ZETA Attestation Token, SMC-B-Bindung ohne Consent; kein Tombstone)
**Bezug:** gemSpec_ZETA V2.0.1_CC, Kapitel 2.7, 4.6.1, 5.3.2.2, 5.4.7, 5.5.5 bis 5.5.10, 5.12.5; Annexe `zeta-guard-client-management.yaml`, `zeta-guard-admin-oob.yaml`; implementierter Stand nach `docs/api/v1/index.md` (ZETA API v2.0.0-draft) und `zeta-guard-helm` (Terraform-Realm `zeta-guard`)
**Referenzstand Keycloak:** 26.x (`keycloak-zeta` 1.2.3; DPoP, Standard Token Exchange und Admin Permissions V2 sind seit 26.4 bzw. 26.2 *supported*)
**Charakter:** informativ; die zugehörigen Anforderungen stehen in `Kapitel-5.5-Client-Management-Keycloak-Neufassung.md`

---

## 1 Ausgangslage und Ziel

Das Client Management der Spezifikation 2.0.1 (Kapitel 5.5.5 bis 5.5.10) verlagert die E-Mail-Bindung aus der Registrierung in fünf neue Endpunkte nach der OIDC-Anmeldung (`/zeta/identity/bind-email` ff.), führt dafür Sonder-Scopes, einen Bindungs-Token und einen Token Exchange zur Freischaltung ein, ergänzt neun Client-Operationen unter `/zeta/...`, neun Operator-Operationen, einen Rollover mit verschachtelter JWS und eigenem Nonce-Endpunkt, ein Veto-Verfahren mit geplanter Löschung und einen Tombstone-Zustand. Der implementierte ZETA Guard macht davon nichts; er müsste diese Funktionen als weitere Keycloak-Erweiterungen bauen und pflegen.

Der implementierte Stand (`keycloak-zeta`) bietet bereits:

- **DCR-Erweiterung** `POST /register` mit Attestierungsprüfung, Pinning von `attestation_type`, `platform`, `product_id`, `ak_jkt` (`binding_status`), `POST /register/verify` mit `verify_type` (TPM-Activation, E-Mail-OTP) und `transaction_id`, Statusmodell `pending_verification` → `pending_attestation` → aktiv.
- **E-Mail-OTP in der App**: mobile Clients übergeben `user_email` im DCR-Request, erhalten `202 {transaction_id}`, der Nutzer gibt den per E-Mail zugestellten Code in der App ein, `POST /register/verify {transaction_id, verify_type=email_otp, code}` schließt mit `201 {client_id, zeta_attestation_token}` ab.
- **ZETA Attestation Token** (Ausstellung nach 5.4.7) mit `sub`, `user_email`, `email_verified`, `cnf` (PuK.AK.Sig), `redirect_uris`, `platform`; **Fast Path** `attestation_type=zeta_attestation_token` mit Nonce vom `nonce_endpoint`, `signed_hash_puk_client_sig` und `attestation_pop`; keine erneute Plattform-Attestierung und kein erneutes OTP.
- **OIDC-Flow** mit dem AuthS als Relying Party (PAR, `redirection_endpoint`, eigener Authorization Code, Policy-Entscheidung), Token-Ausstellung mit Client Assertion und DPoP (`dpop-bind-enforcer` per Client Policy).
- **Nutzer und Bindung für SMC-B**: Keycloak-User je Telematik-ID (gepeppert gehasht), Bindung des Clients an den User beim ersten Token Exchange **ohne Consent**, `SMCB_USER_MAX_CLIENTS`, Idle-TTL-Scheduler für Clients und User, Scheduler für nicht abgeschlossene Registrierungen (`CLIENT_REGISTRATION_TTL`).
- **Revisionssichere Admin Events** über eine Hash-Chain (`GENESIS_HASH`), **E-Mail-Endpunkt** für den Resource Server (mTLS, `GET /zeta/email`), `revocation_endpoint`.

Ziel dieses Vorschlags ist ein Client Management, das die Schutzziele des TOFU-Verfahrens erhält, den implementierten Registrierungs- und OTP-Ablauf unverändert lässt und die Verwaltungs- und Notfallfunktionen mit Keycloak-Bordmitteln (Account REST API, Admin Console, Admin Events, Event-Listener) abdeckt. Neu zu bauen bleibt nur, was weder implementiert noch in Keycloak vorhanden ist: die identitätsseitige TOFU-Prüfung bei der Bindung, `PUT`/`DELETE` auf die eigene Registrierung und die E-Mail-Änderung.

## 2 Kernidee: implementierte Registrierung plus Keycloak-Objekte

Im Folgenden zu jedem fachliches Konzept ein Abschnitt:

### Identitätsdatensatz

- Die Clientdaten werden in der **Client Entität von Keycloak** gehalten. ZETA spezifische Daten, die ggf. eine Erweiterung von Keycloak erfordern, werden in der Entität ZetaGuardClientData gehalten. Diese ist über koinzidierende Primärschlüssel an die Keycloak-eigene Entität gebunden.
- Die Identitätsdaten einer TI-Identität werden in der **User Entität von Keycloak** gehalten. ZETA spezifische Daten, die ggf. eine Erweiterung von Keycloak erfordern, werden in der Entität ZetaGuardUserData gehalten. Diese ist über koinzidierende Primärschlüssel an die Keycloak-eigene Entität gebunden.
  - Telematik Id und KVNR werden als dediziertes User Attibut gespeichert.
  - Auch die User-Felder (in Keycloak Pseudo-Attribute) `email` und `emailVerified` werden verwendet.
- Diese Daten werden jeweils in der Keycloak DB gespeichert. Diese gilt pro ZETA Guard Installation. Eine Mandantentrennung innerhalb einer ZETA Guard Installation findet nicht statt.
  - Gleichzeitig ist somit inhärent eine Trennung der Daten unterschiedlicher ZETA Guards gegeben.

### Bindung Client ↔ Identität

- Die Clientdaten werden in der Client Entität von Keycloak gehalten. ZETA spezifische Daten, die ggf. eine Erweiterung von Keycloak erfordern, werden in der Entität ZetaGuardClientData gehalten. Diese ist über koinzidierende Primärschlüssel an die Keycloak-eigene Entität gebunden.
- Die Identitätsdaten werden in der User Entität von Keycloak gehalten. ZETA spezifische Daten, die ggf. eine Erweiterung von Keycloak erfordern, werden in der Entität ZetaGuardUserData gehalten. Diese ist über koinzidierende Primärschlüssel an die Keycloak-eigene Entität gebunden.
- Die Bindung von Client an User erfolgt nicht wie bei Keycloak üblich über Sessions sonder über die ZETA-eigenen Entitäten: ZetaGuardUserData und ZetaGuardClientData sind via Fremdschlüssel aneinander gebunden.
- **Bindungsschritt im OIDC-Flow des AuthS** nach Verarbeitung des ID-Tokens, vor Ausstellung des AS-Authorization-Codes.
  - Im Statusmodell erfolgt hier Folgendes:
    - `pending_user_binding` → `bound`
    - `pending_attestation` → bleibt aktiv
    - Es wird ein stiller Consent des Users für diesen Client angelegt. Dabei **Kein Consent-Screen**, weder für SMC-B noch für mobile Clients. Ebenso wird das Keycloak Event `GRANT_CONSENT` gefeuert.

### Client Self Management

Es wird eine API zur Selbstverwaltung von Clients geschaffen. Diese basiert auf dem Modell und den Operationen der Keycloak Admin API. Die Admin API selbst wird nicht zum Internet exponiert, um die Angriffsfläche gering zu halten. Ebenso entfallen alle nicht genutzten Felder im Datenmodell aus demselben Grund.

Authentisierung erfolgt dort mit dem regulären DPoP-gebundenen Client Assertion Tokens (kein Registration Access Token, konsistent mit A_30101).

- Übersicht und Löschen eigener Clients
  - `GET /zeta/clients`
    - Liste von Clients, die zum selben User gehören, wie der aufrufende Client
    - gibt ein JSON Array mit Client Ids zurück. Die Client Ids sind Strings.
    - _Anmerkung_: Dies ist ein ZETA eigener Endpunkt, der in der Keycloak Admin API kein Analogon hat.
  - `DELETE /zeta/clients/{id}`
    - Löschung eines Clients. Auch der letzte Client kann ohne Besonderheiten gelöscht werden.
    - Deregistrierung erfolgt durch Löschen aller Clients.
    - Response entspricht https://www.keycloak.org/docs-api/latest/rest-api/index.html#_delete_adminrealmsrealmclientsclient_uuid
    - Es ist zu prüfen, dass der aufrufende Client und der zu löschenden Client zum selben User gehören.
    - Es wird das Keycloak Event `REVOKE_GRANT` gefeuert und der Consent des Users zum gelöschten Client aufgehoben.
    - Aufrufe an diese Schnittstelle werden als Admin Event protokolliert. (Umsetzungshinweis, intern die entsprechende DELETE Funktion der Admin API aufrufen)
  - `PUT /zeta/clients/{id}`
    - Use Cases:
      - Umbenennen eines Clients. Durch Schreiben des entsprechenden Display Name Feldes (`name`).
      - Rollover des Client Assertion Schlüssels. Durch schreiben des entsprechenden JWKS Attributes `jwks.string`.
    - Es wird eine vereinfachte Version der ClientRepresentation (https://www.keycloak.org/docs-api/latest/rest-api/index.html#ClientRepresentation) verwendet. Diese ist beschränkt auf folgende Felder (alle anderen Felder werden verworfen):
      - `name`
      - `attributes."jwks.string"`
    - Anmerkung: Beim Rollover ist der Replay Schutz inhärent gut genug gegeben, sofern der neue und alte Schlüssel unterschiedlich sind. Sofern neuer und alter Schlüssel gleich sind, ist die Operation harmlos. Daher kein vorerst nonce notwendig.
    - Es ist zu prüfen, dass der aufrufende Client und der zu bearbeitende Client zum selben User gehören.
      - Eine Fehlbedienung, bei der das JWKS eines anderen Clients am selben Nutzer geändert wird, ist nicht ausgeschlossen.
    - Aufrufe an diese Schnittstelle werden als Admin Event protokolliert. (Umsetzungshinweis, intern die entsprechende PUT Funktion der Admin API aufrufen)
    - **TODO** nochmal mit DCR abgleichen

### Benachrichtigungen

- Es werden Benachrichtigungen an den User bei folgenden Keycloak Events verschickt:
  - `GRANT_CONSENT`,
  - `REVOKE_GRANT`,
  - `UPDATE_EMAIL`
- Die Benachrichtigungen KÖNNEN über den Notification Service versendet werden.
- Die Benachrichtigungen MÜSSEN auf jeden Fall an die E-Mail des Users versendet werden.
- Umsetzungshinweis: Als Keycloak Event Listener implementieren.

**Ab hier TODO**

### E-Mail-Verifikation (F1)

- nach OIDC über `bind-email`/`verify`/`resend`, Scopes `zeta:email-binding`/`zeta:email-verify`, Bindungs-Token, Token Exchange
- **unverändert wie implementiert**: `user_email` im DCR-Request, OTP-Eingabe in der App, `POST /register/verify`. Die fünf Endpunkte, Scopes, Bindungs-Token und Token Exchange entfallen

### TOFU-Schutz gegen kompromittierten IDP

- OTP an die gespeicherte Adresse bei Folgeregistrierung, ansonsten ebenso Verifikation der E-Mail Adresse via OTP.
- **E-Mail-Abgleich bei der Bindung**:
  - Hat der User noch keine E-Mail, wird die per OTP verifizierte Adresse des Clients identitätsweit gepinnt (Erstnutzung) und verifiziert.
  - Hat der User eine E-Mail, wird nur ein Client gebunden, dessen verifizierte Adresse mit ihr übereinstimmt; sonst `403 email_mismatch` mit maskiertem Hinweis und keine Token.
- Ein Angreifer mit kompromittiertem IDP-Konto kann keinen Client mit fremder Adresse anhängen, weil er den Code an die gebundene Adresse nicht erhält.

### Fast Path

- Übernahme von Identität und E-Mail im Ziel-Guard aus dem ZETA Attestation Token.
- **unverändert wie implementiert**; `user_email`/`email_verified` aus dem Token gelten bei der Bindung wie eine per OTP verifizierte Adresse und unterliegen demselben Abgleich. N2 statt N1

### E-Mail-Änderung

- `POST /zeta/identity/email(/verify)`, RFC 9470 Step-up, `idp_step_up`-Token
- Es ist das Keycloak Event `UPDATE_EMAIL` zu feuern.
- **Wiederverwendung des OTP-Transaktionsmechanismus**: `POST /register/{client_id}/email` (Client Assertion plus frisches AS-Access-Token) → `202 {transaction_id}`, Codes an alte und neue Adresse, `POST /register/verify` mit `verify_type=email_change`. Step-up = `auth_time` im eigenen Access Token, kein RFC 9470

### Außerordentliche Löschung (OOB)

- neun Operator-Endpunkte, Vier-Augen-Logik, Tombstone, zweite Bestätigung
- **Admin Console / Admin REST API**, Operator-Realm mit mTLS oder Betreiber-IdP, **Admin-Event-Hash-Chain (implementiert)** als Nachweis; Sperre (`enabled=false`) → Einspruchsfrist → Löschung des Users mit seinen Clients. **Kein Tombstone**; Wiederregistrierung ist eine normale Erstnutzung


## 3 Ablauf aus Sicht des ZETA Clients

### 3.1 Erstnutzung an einem Guard (unverändert bis zur Anmeldung)

1. **DCR** `POST /register` mit Attestierung, `jwks`, `redirect_uris`, `client_name`, `user_email` → `202 {transaction_id, expires_in}`; Code per E-Mail (N7).
2. **OTP in der App**: `POST /register/verify {transaction_id, verify_type=email_otp, code}` → `201 {client_id, status=pending_attestation, zeta_attestation_token}`.
3. **OIDC-Anmeldung** wie implementiert (PAR → sektoraler IDP → `redirection_endpoint`).
4. **Bindung (neu, serverseitig)**: Der AuthS lädt oder legt den User zur KVNR an. Ohne gebundene E-Mail pinnt er die verifizierte Adresse des Clients (TOFU). Er bindet den Client an den User (wie SMC-B), legt das stille Consent-Objekt an, setzt den Client aktiv, emittiert N1 und stellt den AS-Authorization-Code aus.
5. **Token** `POST /token` mit Client Assertion und DPoP wie implementiert.

### 3.2 Weiteres Gerät

Identisch. Der Nutzer gibt beim DCR seine gebundene Adresse an und bestätigt den Code. Bei der Bindung stimmt die Adresse mit der des Users überein. Gibt er eine andere Adresse an, antwortet der AuthS bei der Bindung mit `403 email_mismatch` und `email_hint` (maskiert); der Client wird nicht gebunden, die App fordert zur erneuten Registrierung mit der gebundenen Adresse auf, der ungebundene Client wird vom vorhandenen Scheduler gelöscht.

### 3.3 Fast Path an einem weiteren Guard (unverändert)

`POST /register` mit `attestation_type=zeta_attestation_token`, Nonce, `signed_hash_puk_client_sig`, `attestation_pop` → `201`. Kein OTP. Bei der Bindung gilt der E-Mail-Abgleich mit `user_email` aus dem Token; nach Erfolg N2 an diese Adresse.

### 3.4 Laufender Betrieb

- **Übersicht und Löschen** anderer Geräte: Account REST API mit dem DPoP-gebundenen Access Token (Audience `account`, Rolle `manage-account`). Widerruf des Consents beendet die Token-Erneuerung des Ziel-Clients (N3); der Scheduler entfernt den Client.
- **Umbenennen**: `PUT /register/{client_id}` mit `client_name`, Client Assertion.
- **Rollover**: Nonce vom `nonce_endpoint` holen, `PUT /register/{client_id}` mit neuem `jwks`, `nonce` und `signed_hash_puk_client_sig` (Selbstsignatur des neuen Schlüssels), autorisiert mit der Client Assertion des alten Schlüssels; atomarer Wechsel.
- **E-Mail ändern**: `POST /register/{client_id}/email {new_email}` mit Client Assertion und einem AS-Access-Token, dessen `auth_time` jünger als 5 Minuten ist (sonst `401 insufficient_user_authentication`, die App startet den OIDC-Flow neu); Codes an alte und neue Adresse; `POST /register/verify {transaction_id, verify_type=email_change, code_old, code_new}`; N5 an beide Adressen.
- **Eigenes Gerät abmelden**: `DELETE /register/{client_id}` mit Client Assertion.

### 3.5 Was im ZETA Client entfällt

Aufrufe von `bind-email`/`resend`/`verify`, Behandlung der Sonder-Scopes, Bindungs-Token und Token Exchange zur Freischaltung, `HEAD /zeta/rollover-nonce` und RolloverEnvelope, Veto-Aufruf, RFC-9470-Auswertung. Die Endpunkte `/zeta/clients` werden durch die Account REST API ersetzt.

## 4 Auswirkungen auf den ZETA Guard

### 4.1 Konfiguration (Terraform-Realm)

- Account-Client: Audience `account` und Rolle `manage-account` in den Token mobiler Clients (Client Scope, wie `zero:audience`).
- `email`-Event-Listener mit `include-events` für `GRANT_CONSENT` (N1, N2 über Event-Detail `fastpath`), `REVOKE_GRANT` und `CLIENT_DELETE` (N3), `UPDATE_EMAIL` (N5); Theme mit Templates je Event-Typ nach Nachrichtenkatalog. Keycloak kennt keine eigenen Event-Typen, die Erweiterung verwendet diese Standardtypen. N7/N8 versendet die DCR-Erweiterung weiterhin direkt (kein OTP in Event-Details). SMTP ist bereits konfiguriert.
- Declarative User Profile: `email` nicht durch den Nutzer editierbar (Änderung nur über den OTP-Pfad).
- Operator-Realm mit X.509 oder Betreiber-IdP, Admin Permissions V2 (`view-users`, `manage-users`, `manage-clients` auf `zeta-guard`), Aufbewahrung der Admin Events.
- Umgebungsvariable analog `SMCB_USER_MAX_CLIENTS` für Versicherte (`USER_MAX_CLIENTS`), Idle-TTLs für mobile Clients und User.

### 4.2 Erweiterungen der vorhandenen DCR-Komponente

| Erweiterung | Umfang | Ersetzt in der Spec |
| --- | --- | --- |
| Bindungsschritt für Versicherte im OIDC-Flow: User zur KVNR, E-Mail-Pinning bei Erstnutzung, E-Mail-Abgleich, Bindung wie SMC-B, stilles Consent-Objekt, Event N1/N2, `403 email_mismatch` | Wiederverwendung der SMC-B-Bindungslogik plus Abgleich | A_30085, A_30211–A_30216, A_30218, A_29910, Statusmodell A_30086 |
| `PUT`/`DELETE /register/{client_id}` mit Client Assertion: Umbenennen, Rollover mit Besitznachweis, Selbst-Deregistrierung; Ablehnung gepinnter Felder | drei Operationen, Prüfroutine für `signed_hash_puk_client_sig` vorhanden | A_29921–A_29927, A_30005-01, A_30188/A_30189, `HEAD /zeta/rollover-nonce` |
| `POST /register/{client_id}/email` und `verify_type=email_change` | Wiederverwendung von Transaktions-Cache, OTP-Erzeugung, Versand, Rate-Limit | A_29911, A_29912, A_30220, A_30221, `/zeta/identity/email(/verify)` |
| Event-Emission (N1, N2, N3, N5) statt eigenem Katalog-Versand | Aufrufe des Keycloak `EventBuilder` mit Standard-Event-Typen an den bestehenden Stellen | A_29920, A_29935, Teile von 5.12.5 |
| Scheduler: Clients ohne Bindung nach TTL (vorhanden), Clients mit widerrufenem Consent, idle User | Erweiterung des vorhandenen Schedulers | A_30219, A_30086 (TTL/GC) |
| Optional: Event-Listener → Notification Service (Push) | eine Klasse | Push-Pflichten in 5.12.5 |

### 4.3 Was entfällt

Alle neun `/zeta/...`-Client-Operationen des Annex (`HEAD /zeta/rollover-nonce`, `POST /zeta/identity/bind-email`, `/resend`, `/verify`, `POST /zeta/identity/email`, `/verify`, `GET /zeta/clients`, `DELETE /zeta/clients/{id}`, `POST /zeta/deletions/{id}/veto`); die Geräteverwaltung übernimmt die Account REST API, die E-Mail-Änderung `POST /register/{client_id}/email`. Vom Annex bleiben nur `POST /register`, `POST /register/verify` und `GET`/`PUT`/`DELETE /register/{client_id}`. Ferner alle neun Admin-OOB-Operationen, Sonder-Scopes und Bindungs-Token, Token Exchange zur Freischaltung, Rollover-Nonce-Endpunkt und verschachtelte JWS, Overlap-Fenster, Veto- und Fristenlogik, Tombstone und zweite OOB-Bestätigung, RFC-9470-Step-up.

## 5 Sicherheitsbewertung

**Schutzgut** bleibt die bestehende Registrierung gegenüber einem kompromittierten sektoralen IDP.

| Bedrohung | Spec 2.0.1 | Vorschlag |
| --- | --- | --- |
| Angreifer mit fremdem ID-Token bindet eigenes Gerät | OTP an die gebundene Adresse | Bindung nur bei Übereinstimmung mit der gebundenen Adresse; der Angreifer kann eine fremde Adresse nicht verifizieren und seine eigene nicht binden. Gleichwertig, ohne Folgeregistrierungs-Sonderpfad |
| Angreifer kennt die Adresse des Opfers | OTP an die gebundene Adresse | OTP geht an das Opfer; der Angreifer erhält den Code nicht. Das Opfer sieht einen unerwarteten Code (Hinweistext in N7: „Wenn Sie das nicht waren …“) |
| Angreifer löscht fremde Geräte oder ändert die E-Mail | F1/F2 | Account REST API und E-Mail-Änderung verlangen ein Access Token eines **gebundenen** Clients; ungebundene Clients erhalten keine Token. E-Mail-Änderung zusätzlich Code an die alte Adresse |
| Missbräuchliches Vouching eines Quell-Guards | N2 | identisch; zusätzlich E-Mail-Abgleich am Ziel-Guard, wenn die Identität dort schon bekannt ist |
| Rollover durch Angreifer | Nonce, verschachtelte JWS (außen alt, innen neu) | Client Assertion des alten Schlüssels (Autorisierung) plus Selbstsignatur des neuen Schlüssels über Nonce (Besitznachweis); `jti`-Einmaligkeit. Gleiche zwei Signaturen, aber im vorhandenen Request-Format statt eigenem Envelope |
| Verlust des Geräts | Folgeregistrierung mit OTP | identisch |
| Verlust aller Faktoren | OOB mit Veto und Tombstone | OOB-Sperre, Frist, Löschung; Nachweis über Admin-Event-Hash-Chain. Wiederregistrierung ist Erstnutzung; die zweite unabhängige Bestätigung entfällt (bewusst) |
| Erstnutzungs-Capture | akzeptiert | unverändert |
| Enumeration von Geräten | DPoP-AT der Identität | identisch (Account REST API) |

**Bewusst aufgegebene Eigenschaften**

- Tombstone und zweite OOB-Bestätigung: nach der Löschung kann ein Angreifer mit kompromittiertem IDP-Konto die Identität neu anlegen (Erstnutzungs-Capture). Der rechtmäßige Inhaber bemerkt dies bei seiner eigenen Registrierung (`email_mismatch`) und hat den OOB-Pfad. Das entspricht dem ohnehin akzeptierten Restrisiko der Erstnutzung.
- Vier-Augen-Prinzip und Einspruchsfrist als Betriebsprozess, nachgewiesen über die Hash-Chain.
- Kein Overlap-Fenster beim Rollover; Umbenennen ohne Nachricht (N4).

## 6 Aufwandsvergleich

| Baustein | Spec 2.0.1 (Eigenbau) | Vorschlag |
| --- | --- | --- |
| E-Mail-Bindung | 5 Endpunkte, Scopes, Bindungs-Token, Token Exchange, Umbau von 5.3.2.2 | 0 (implementiert), plus Abgleich im Bindungsschritt |
| Identität/Status | Registry, Statusmodell mit `pending_user_binding`/`bound`/`tombstone` | Keycloak-User wie SMC-B, vorhandenes Statusmodell |
| Client-Verwaltung | 2 Endpunkte, identitätsgescopte Autorisierung | Account REST API; stilles Consent-Objekt |
| Metadaten/Rollover | 3 Operationen, Nonce-Endpunkt, Envelope, Overlap | 3 Operationen, vorhandene Prüfroutine |
| E-Mail-Änderung | 2 Endpunkte, RFC 9470 | 1 Endpunkt plus `verify_type` |
| Veto/Löschung letzter Client | 1 Endpunkt, Fristenlogik | 0 |
| OOB | 9 Endpunkte, mTLS-Kanal, Tombstone-Logik | 0 (Admin Console, Hash-Chain vorhanden) |
| Fast Path | Übernahme in Registry | 0 (implementiert) |
| Benachrichtigungen | Katalog-Versand | Event-Emission plus Templates |

## 7 Offene Punkte und Prüfaufträge

1. **Stilles Consent-Objekt**: Zusammenspiel mit dem implementierten OIDC-Flow des AuthS prüfen (kein Consent-Screen darf erscheinen; `consentRequired=true` nur für mobile Clients). Rückfall: `GET/DELETE /zeta/clients` als zwei Operationen in der DCR-Erweiterung, autorisiert mit dem Nutzer-Access-Token.
2. **Account REST API**: nicht als stabile öffentliche API garantiert; Keycloak-Hauptversion pinnen, Rückfall Account Console im Systembrowser.
3. **`email_mismatch`-UX**: Wortlaut des Hinweises und Verhalten der App (erneutes DCR mit gebundener Adresse); Rate-Limit für wiederholte Fehlbindungen je KVNR.
4. **E-Mail-Änderung**: Entscheidung, ob in Stufe 2 in der App oder zunächst nur über den OOB-Prozess (Operator setzt Adresse nach Identitätsnachweis).
5. **Identitäts-Hashing**: KVNR gepeppert hashen wie die Telematik-ID; Auswirkung auf `GET /zeta/email` (Identifier aus `zeta-user-info`) prüfen.
6. **Passkey**: nur wenn der sekIDP-Flow als Keycloak-Browser-Flow läuft; Prüfauftrag an das Guard-Team.
7. **Push**: E-Mail als alleiniger Pflichtkanal für N1/N2/N3/N5 oder Event-Listener zum Notification Service.
8. **`sub` im ZETA Attestation Token**: `zeta-attestation-token.yaml` verlangt `sub` = KVNR, der implementierte Ablauf stellt den Token aber mit der `201`-Antwort nach dem OTP aus, wenn die KVNR noch unbekannt ist. Zu klären: `sub` erst nach der Bindung befüllen (Neuausstellung über den Attestation Service nach 5.4.7) oder bis dahin weglassen. Der Vorschlag verlangt den Abgleich von `sub` nur, wenn das Feld gesetzt ist.
9. **A_25734 (Zugriffsprotokoll für den Nutzer)**: Keycloak bietet keine nutzerseitige Ereignisliste, nur `GET /account/sessions`. Entweder streichen oder als kleine Erweiterung (Ausgabe der User Events der eigenen Identität) einplanen; nicht Teil dieses Vorschlags.
10. **Revisionssicherheit der User Events**: Die implementierte Hash-Chain deckt Admin Events ab. Ob Registrierung, Bindung und Entbindung (User Events) ebenfalls verkettet werden müssen, ist mit A_29948 zu klären.

## 8 Folgeänderungen in der Spezifikation

- Kapitel 5.3.2.2 zurück auf den implementierten Ablauf (OTP im Rahmen von `/register`, Status `pending_attestation`); Hinweis auf die Bindung im OIDC-Flow (Abb-ZETA-OIDC-Token-Bezug, neuer Schritt zwischen (04) und (05)).
- Kapitel 4.6.1 und 2.7: Folgeregistrierung durch „E-Mail-Abgleich bei der Bindung“ ersetzen; Tombstone streichen.
- Kapitel 5.5.5 bis 5.5.10: Ersatz durch die Neufassung.
- Kapitel 5.12.5: Auslöser auf Events abbilden, N4/N6/N9/N10 als Prozess bzw. gestrichen (siehe Neufassung), A_30200 und A_30203 unverändert.
- `dcr-request.yaml`: Beschreibung von `user_email` auf den implementierten Ablauf zurückführen; `verify-request.yaml`: `verify_type=email_change`; Annex `zeta-guard-client-management.yaml` auf `/register`, `/register/verify`, `/register/{client_id}`, `/register/{client_id}/email` reduzieren; `zeta-guard-admin-oob.yaml` streichen.
