# 5.5 Client Management auf dem implementierten ZETA-Keycloak-Stand (Neufassung – Entwurf)

**Stand:** 2026-09-21 · **Revision 3a** (Konsistenzprüfung) (OTP in der App wie implementiert, Fast Path erhalten, kein Tombstone, keine Consent-Abfrage)
**Bezug:** gemSpec_ZETA V2.0.1_CC, Kapitel 5.5.5 bis 5.5.10; ersetzt diese Abschnitte vollständig. Kapitel 5.3.2.2 wird auf den implementierten Ablauf zurückgeführt (siehe 5.5.10)
**Übersicht und Begründung:** `Client-Management-Keycloak-Uebersicht.md`
**Referenzstand:** `keycloak-zeta` 1.2.3 (ZETA API v2.0.0-draft), Keycloak 26.x

## Vorbemerkung

Diese Neufassung ersetzt die Abschnitte 5.5.5 bis 5.5.10. Sie lässt die implementierte Registrierung (Attestierung, E-Mail-OTP in der App über `POST /register` und `POST /register/verify`, ZETA Attestation Token, Fast Path) unverändert und ergänzt sie um die Bindung an die TI-Identität im OIDC-Flow, drei Operationen auf die eigene Registrierung, die E-Mail-Änderung sowie die Verwaltungs- und Notfallfunktionen über Keycloak-Bordmittel (Account REST API, Admin Console, Admin Events mit Hash-Chain, Event-Listener).

Jede Anforderung behandelt genau einen Prüfgegenstand; eine MUSS- und eine DARF-NICHT-Aussage zum selben Gegenstand sind in einer Afo zusammengefasst. Anforderungen verweisen nicht auf andere Anforderungen dieses Kapitels, nur auf Abschnitte. Begriffe und Zustände sind in 5.5.0 definiert.

**Nummerierung:** Übernommene oder inhaltlich angepasste Anforderungen behalten ihre Basis-ID (mit Suffix `-KC`, wenn sich der Wortlaut ändert). Neue Anforderungen tragen die Kennung `A_KC-nn`. Die verbindliche Vergabe endgültiger Afo-Nummern obliegt der gematik. Abschnitt 5.5.10 enthält die Zuordnung alt → neu.

---

## 5.5.0 Begriffe, Akteure und Zustandsmodell

*Dieser Abschnitt ist nicht normativ.*

### Akteure

| Akteur | Rolle |
| --- | --- |
| ZETA Client | Software auf dem Endgerät; führt DCR mit OTP-Eingabe, OIDC-Anmeldung, Selbstverwaltung über die Account REST API und die Operationen auf die eigene Registrierung aus. |
| Authorization Server | Keycloak-Realm `zeta-guard` des ZETA Guard einschließlich der DCR-Erweiterung (`/register`, `/register/verify`, `/register/{client_id}`), des OIDC-Flows (`redirection_endpoint`) und der Scheduler. |
| Sektoraler IDP | Externer Identity Provider; stellt ausschließlich die Nutzerauthentisierung fest. |
| Notification Service | Komponente des ZETA Guard für Push; optional über einen Event-Listener angebunden. |
| Operator | Person mit Zugang zum Operator-Realm (Admin Console / Admin REST API). |

### Objekte

- **Identitätsdatensatz**: der Keycloak-User des Realms. Username ist der gepeppert gehashte Wert der TI-Identität (KVNR oder Telematik-ID), wie für SMC-B implementiert. Er trägt die gebundene E-Mail-Adresse (`email`, `emailVerified`).
- **Client-Instanz**: der per DCR angelegte Keycloak-Client mit `private_key_jwt`; sein JWKS enthält den Instanzschlüssel (F2). Gepinnte Attribute: `attestation_type`, `platform`, `product_id`, `ak_jkt`, `binding_status`. Für mobile Clients zusätzlich die per OTP verifizierte Adresse `verified_email`.
- **F1 (verifizierte E-Mail)**: die Adresse, die der Nutzer bei der Registrierung angegeben und per OTP in der App bestätigt hat. Auf Identitätsebene wird sie bei der ersten Bindung gepinnt und ist danach für jede weitere Bindung maßgeblich.
- **F2 (Instanzschlüssel)**: das asymmetrische Schlüsselpaar der Client-Instanz; der private Teil verbleibt auf dem Gerät.
- **Bindung**: die Zuordnung einer Client-Instanz zu einem Identitätsdatensatz, hergestellt im OIDC-Flow des Authorization Servers nach Verarbeitung des ID-Tokens (für SMC-B: beim ersten Token Exchange, wie implementiert). Für mobile Clients wird zusätzlich ein Keycloak-UserConsent-Objekt ohne Nutzerabfrage angelegt, damit die Account REST API den Client listet und widerrufen kann.
- **OTP-Transaktion**: der implementierte Mechanismus aus `transaction_id`, Code, Ablauf und Versand, der von `POST /register` und `POST /register/verify` genutzt wird.
- **ZETA Attestation Token**: nach 5.4.7 vom Quell-Guard ausgestellter Token mit `sub`, `user_email`, `email_verified`, `cnf`, `redirect_uris`, `platform`, `jti`, `exp`, `aud=zeta-guard`.
- **Operator-Realm**: eigener Keycloak-Realm für Operator-Konten; Anmeldung unabhängig vom sektoralen IDP.

### Zustände (implementiertes Statusmodell)

| Status | Bedeutung |
| --- | --- |
| `pending_verification` | Registrierung angelegt, ein Verifikationsschritt steht aus (TPM-Activation bzw. E-Mail-OTP). Mobile Clients haben in diesem Status noch keine `client_id`, sondern eine `transaction_id`. |
| `pending_attestation` | Registrierung abgeschlossen, `client_id` vergeben; erste Nutzung mit Client Statement/Posture und die Bindung stehen aus. Für mobile Clients keine Token. Wird nach `CLIENT_REGISTRATION_TTL` gelöscht. |
| aktiv | Gebunden; voller Berechtigungsumfang nach Policy-Entscheidung. Wird nach Idle-TTL gelöscht. |
| gesperrt (Identität) | User `enabled=false`; keine Anmeldung, keine Token-Erneuerung für alle Clients der Identität. |

Die Spec-Zustände `pending_user_binding`, `bound` und `tombstone` entfallen: `pending_user_binding` entspricht `pending_attestation`, `bound` entspricht aktiv, ein Tombstone gibt es nicht.

---

## 5.5.1 Registrierungsdatenformate

Client Assertion JWT, Client Statement und Posture bleiben unverändert (5.5.1 bis 5.5.4 der Spezifikation). Die Registrierung folgt dem implementierten Ablauf: `POST /register` (mobil mit `user_email`, Antwort `202 {transaction_id}`), `POST /register/verify {transaction_id, verify_type=email_otp, code}` (Antwort `201 {client_id, status, zeta_attestation_token}`), Fast Path mit `attestation_type=zeta_attestation_token` (Antwort `201`, kein OTP). A_29658 und Abb-ZETA-DCR-für-mobile-Clients sind entsprechend zurückzuführen (5.5.10).

---

## 5.5.2 Identitätsdatensatz und Fachdienstgrenzen

### A_29898-KC – Fachdienstlokaler Identitätsdatensatz

**ZETA Guard** MUSS Identitätsdatensätze, Bindungen und Sperrzustände ausschließlich im Realm des eigenen Fachdienstes führen, ohne sie mit einem anderen ZETA Guard zu teilen oder von diesem zu beziehen.

### A_29899 – Keine fachdienstübergreifende Korrelation

**ZETA Guard** DARF NICHT Identitätsdatensätze fachdienstübergreifend verknüpfen oder zur Korrelation eines Nutzers über mehrere Fachdienste hinweg verwenden.

### A_29900-KC – TI-Identität als Username

**Authorization Server** MUSS den Identitätsdatensatz eines Versicherten mit dem gepeppert gehashten Wert der KVNR aus dem ID-Token des sektoralen IDP als Username anlegen (Verfahren wie für die Telematik-ID implementiert) und diesen Username unveränderlich führen.

### A_29901-KC – Trennung von Identitäts- und Client-Ebene

**Authorization Server** MUSS die gebundene E-Mail (F1) als Attribut des Identitätsdatensatzes und den Instanzschlüssel (F2), die gepinnten Attestierungsattribute sowie die per OTP verifizierte Adresse als Attribute der Client-Instanz führen.

### A_29903-KC – Bindung nur aus der Nutzerauthentisierung

**Authorization Server** MUSS die Bindung einer Client-Instanz an einen Identitätsdatensatz ausschließlich im OIDC-Flow nach erfolgreicher Verarbeitung des ID-Tokens des sektoralen IDP (bzw. für SMC-B beim Token Exchange) herstellen; ein Registrierungsabschluss, ein ZETA Attestation Token oder eine Client-Authentisierung DÜRFEN NICHT für sich allein eine Bindung herstellen.

### A_29896 – IDP-Authentisierung allein nicht hinreichend

**Authorization Server** MUSS sicherstellen, dass eine erfolgreiche Authentisierung des Nutzers gegenüber dem sektoralen IDP allein nicht ausreicht, um eine Client-Instanz an einen Identitätsdatensatz mit bereits gebundener E-Mail zu binden, eine Bindung zu widerrufen oder die gebundene E-Mail zu ändern.

### A_29893-KC – Geltungsbereich

**Authorization Server** MUSS die Anforderungen zu E-Mail-Bindung und E-Mail-Abgleich ausschließlich auf mobile Client-Instanzen anwenden, die im OIDC-Flow an eine TI-Identität gebunden werden; für stationäre Clients mit SMC-B-Token-Exchange und für identitätslose Clients gelten sie nicht.

### A_KC-01 – Keine Consent-Abfrage

**Authorization Server** DARF NICHT bei der Registrierung oder Bindung einer Client-Instanz eine Consent-Abfrage gegenüber dem Nutzer stellen; dies gilt für SMC-B-Clients (wie implementiert) und für mobile Clients.

### A_29894 – Identitätslose Clients

**Authorization Server** MUSS einen ohne TI-Identität registrierten Client ausschließlich über den Instanzschlüssel (F2, Client Assertion nach RFC 7523) und die plattformabhängige Attestierung absichern, ohne einen Identitätsdatensatz anzulegen oder eine E-Mail zu verlangen.

### A_29895 – Identitätslose Clients: Rollover zulässig, keine Recovery

**Authorization Server** MUSS den Schlüssel-Rollover (5.5.6) auch für identitätslose Clients zulassen; bei Verlust des Instanzschlüssels MUSS sich der Client neu registrieren.

---

## 5.5.3 Registrierung mit E-Mail-OTP (implementiert)

*Die folgenden Anforderungen fixieren den implementierten Ablauf normativ, damit Kapitel 5.3.2.2 darauf verweisen kann.*

### A_25432-01-KC – Ablauf der mobilen Registrierung

**ZETA Client** MUSS bei der Registrierung eine vom Nutzer angegebene, strukturell gültige E-Mail-Adresse im Feld `user_email` des DCR-Requests übermitteln, den per E-Mail zugestellten Code vom Nutzer in der App entgegennehmen und mit `POST /register/verify {transaction_id, verify_type=email_otp, code}` bestätigen.

### A_30085-KC – OTP-Transaktion bei der Registrierung

**Authorization Server** MUSS bei einer mobilen Registrierung ohne ZETA Attestation Token ein Einmalpasswort an `user_email` senden (N7), mit `202 {transaction_id, expires_in}` antworten, die `client_id` erst nach erfolgreicher Verifikation vergeben und die verifizierte Adresse als `verified_email` an der Client-Instanz speichern.

### A_KC-02 – Eigenschaften des Einmalpassworts

**Authorization Server** MUSS ein Einmalpasswort mit mindestens sechs Ziffern und einer Gültigkeit von höchstens 10 Minuten erzeugen, die Transaktion nach höchstens fünf Fehlversuchen verwerfen und je `transaction_id` und Empfängeradresse genau ein Einmalpasswort führen.

### A_30217-KC – Rate-Limiting

**Authorization Server** MUSS je `user_email` einen Mindestabstand von 60 Sekunden zwischen zwei Versandvorgängen und höchstens fünf Versandvorgänge je Stunde erzwingen.

### A_30200 – Einmalpasswörter nur per E-Mail

**Authorization Server** MUSS Einmalpasswörter ausschließlich per E-Mail versenden und DARF NICHT ein Einmalpasswort per Push oder in einer HTTP-Antwort ausliefern.

### A_29907 – Instanzschlüssel im Besitz der Client-Instanz

**Authorization Server** MUSS den Instanzschlüssel (F2) ausschließlich als öffentlichen Schlüssel im JWKS der Client-Instanz führen; der private Schlüssel DARF NICHT an den Authorization Server übertragen werden.

### A_30219-KC – Bereinigung ungebundener Clients

**Authorization Server** MUSS Client-Instanzen im Status `pending_attestation`, die innerhalb der konfigurierten Frist (`CLIENT_REGISTRATION_TTL`) nicht gebunden werden, löschen.

---

## 5.5.4 Bindung an die Identität und Fast Path

*Der Bindungsschritt liegt im OIDC-Flow des Authorization Servers zwischen der Verarbeitung des ID-Tokens und der Ausstellung des AS-Authorization-Codes. Er ersetzt die Folgeregistrierung der Spec: Der Nutzer gibt bei jedem Gerät seine Adresse an und bestätigt den Code; der Abgleich mit der gebundenen Adresse erfolgt serverseitig.*

### A_KC-03 – Erstbindung pinnt die E-Mail (TOFU)

**Authorization Server** MUSS bei der Bindung einer mobilen Client-Instanz an einen Identitätsdatensatz ohne gebundene E-Mail die `verified_email` der Client-Instanz als `email` des Identitätsdatensatzes mit `emailVerified=true` übernehmen.

### A_29910-KC – E-Mail-Abgleich bei weiteren Bindungen

**Authorization Server** MUSS bei der Bindung einer mobilen Client-Instanz an einen Identitätsdatensatz mit gebundener E-Mail die Bindung nur herstellen, wenn `verified_email` der Client-Instanz mit der gebundenen E-Mail übereinstimmt (Vergleich nach Normalisierung gemäß RFC 5321, lokaler Teil byteweise, Domain case-insensitiv).

### A_KC-04 – Ablehnung bei abweichender Adresse

**Authorization Server** MUSS bei abweichender Adresse die Bindung verweigern, den OIDC-Flow mit `403` und `error=email_mismatch` beenden, DARF dabei KEINE Token oder Authorization Codes ausstellen und KANN einen maskierten Hinweis `email_hint` (höchstens erstes Zeichen des lokalen Teils, erstes Zeichen des Domain-Labels und Top-Level-Domain) mitgeben.

### A_KC-05 – Rate-Limit für Fehlbindungen

**Authorization Server** MUSS je Identitätsdatensatz höchstens fünf abgelehnte Bindungen je Stunde zulassen und weitere Bindungsversuche in diesem Zeitraum mit `429` beantworten.

### A_KC-06 – Verhalten des ZETA Clients bei Ablehnung

**ZETA Client** MUSS bei `email_mismatch` den Nutzer auffordern, die Registrierung mit der an diesem Fachdienst gebundenen E-Mail-Adresse zu wiederholen, und DARF NICHT die abgelehnte `client_id` weiterverwenden.

### A_KC-07 – Bindung ohne Consent-Screen mit Consent-Objekt

**Authorization Server** MUSS bei erfolgreicher Bindung einer mobilen Client-Instanz den Client dem Identitätsdatensatz zuordnen (wie für SMC-B implementiert), ein UserConsent-Objekt für den Client ohne Nutzerabfrage anlegen, den Status auf aktiv setzen und die Nachricht N1 auslösen.

### A_25748-02-KC – Höchstzahl gebundener Clients

**Authorization Server** MUSS die Anzahl gebundener Client-Instanzen je Identitätsdatensatz auf einen konfigurierbaren Wert (`USER_MAX_CLIENTS`, analog `SMCB_USER_MAX_CLIENTS`) begrenzen und eine weitere Bindung mit `403` und `error=too_many_clients` ablehnen.

### A_KC-08 – Keine Token vor Bindung

**Authorization Server** DARF NICHT für eine mobile Client-Instanz, die noch nicht an einen Identitätsdatensatz gebunden ist, Access, Refresh oder ID Token ausstellen.

### A_29913-KC – Fast Path

**Authorization Server** MUSS eine Registrierung mit `attestation_type=zeta_attestation_token` nach vollständiger Prüfung des Tokens (Signatur, Zulassung des Ausstellers, `aud`, Besitznachweise, Nonce) ohne erneute Plattform-Attestierung und ohne Einmalpasswort abschließen und `user_email` aus dem Token als `verified_email` der Client-Instanz übernehmen, sofern `email_verified=true` ist.

### A_29914-KC – Inhalt des ZETA Attestation Token

**Authorization Server** MUSS einen ZETA Attestation Token nur akzeptieren, wenn er von einem im Entity Statement des Federation Master aufgeführten ZETA Guard signiert ist und mindestens `cnf` des attestierten Schlüssels, `platform`, `jti`, `exp` und `aud=zeta-guard` sowie für mobile Clients `user_email` mit `email_verified` und `redirect_uris` enthält.

### A_29915-01 – Prüfung des ZETA Attestation Token

Unverändert übernommen (Signatur gegen `jwks_uri` des Ausstellers, Zulassung über Federation Master, `aud`, `signed_hash_puk_client_sig`, `attestation_pop`, Nonce vom `nonce_endpoint`).

### A_29916 – Faktorverankerung des Fast Path

**Authorization Server** MUSS sicherstellen, dass der Fast Path durch `signed_hash_puk_client_sig` und `attestation_pop` autorisiert wird; eine IDP-Authentisierung allein DARF NICHT zur Einlösung ausreichen.

### A_KC-09 – E-Mail-Abgleich auch im Fast Path

**Authorization Server** MUSS die per Fast Path registrierte Client-Instanz bei der Bindung denselben Regeln unterwerfen wie eine per OTP verifizierte (Erstbindung pinnt, weitere Bindung nur bei Übereinstimmung) und MUSS, sofern der Token ein `sub` enthält, die Bindung ablehnen, wenn `sub` nicht dem authentisierten Identitätsdatensatz entspricht.

### A_29918 – Eigenständige Weiterentwicklung nach Fast Path

**ZETA Guard** MUSS die gebundene E-Mail nach einer Fast-Path-Bindung eigenständig führen; eine spätere Änderung an einem Guard DARF NICHT auf andere Guards übertragen werden.

### A_29919 – Keine Persistierung des Quell-Guards

**ZETA Guard** MUSS den Aussteller des ZETA Attestation Token ausschließlich transient zur Prüfung verwenden und DARF NICHT den Quell-Guard als Attribut des Identitätsdatensatzes oder der Client-Instanz speichern.

### A_29920-KC – Benachrichtigung bei Fast Path

**Authorization Server** MUSS bei der Bindung einer per Fast Path registrierten Client-Instanz statt N1 die Nachricht N2 an die gebundene E-Mail auslösen.

---

## 5.5.5 E-Mail-Änderung

*Die Änderung nutzt den vorhandenen OTP-Transaktionsmechanismus. Der Step-up-Nachweis ist das vom Authorization Server selbst ausgestellte Access Token mit frischem `auth_time`.*

### A_29909-KC – Genau eine gebundene E-Mail

**Authorization Server** MUSS je Identitätsdatensatz genau eine gebundene E-Mail-Adresse führen und DARF NICHT deren Bearbeitung durch den Nutzer über die Account Console oder die Account REST API zulassen.

### A_29911-KC – Start der Änderung

**Authorization Server** MUSS `POST /register/{client_id}/email {new_email}` nur annehmen, wenn die Anfrage mit einer gültigen Client Assertion der gebundenen Client-Instanz und einem DPoP-gebundenen Access Token desselben Identitätsdatensatzes autorisiert ist, dessen `auth_time` nicht älter als 300 Sekunden ist; andernfalls MUSS er mit `401` und `error=insufficient_user_authentication` antworten.

### A_KC-10 – Zwei Einmalpasswörter

**Authorization Server** MUSS nach Annahme der Änderung eine OTP-Transaktion anlegen, ein Einmalpasswort an die gebundene Adresse (N8, Nachweis F1) und ein zweites an `new_email` (N8, Verifikation) senden und mit `202 {transaction_id, expires_in}` antworten.

### A_KC-11 – Abschluss der Änderung

**Authorization Server** MUSS die Änderung ausschließlich über `POST /register/verify {transaction_id, verify_type=email_change, code_old, code_new}` abschließen, bei Erfolg `email` des Identitätsdatensatzes ersetzen und `verified_email` aller gebundenen Client-Instanzen dieser Identität aktualisieren.

### A_29912 – Identitätsweite Wirkung

**Authorization Server** MUSS eine wirksame E-Mail-Änderung für alle Client-Instanzen des Identitätsdatensatzes an diesem Fachdienst gelten lassen.

### A_KC-12 – Benachrichtigung bei Änderung

**Authorization Server** MUSS nach wirksamer Änderung die Nachricht N5 an die bisherige und an die neue Adresse auslösen.

### A_30220-KC – Step-up durch den ZETA Client

**ZETA Client** MUSS bei `insufficient_user_authentication` den OIDC-Flow erneut durchlaufen und die Änderung mit dem daraus erhaltenen Access Token wiederholen.

### A_29933-KC – Ersatzgerät bei E-Mail-Verlust

**ZETA Client** SOLL einen Nutzer, der den Zugriff auf die gebundene E-Mail verloren hat und über ein gebundenes Gerät verfügt, anleiten, zunächst von diesem Gerät die Adresse zu ändern und erst danach das Ersatzgerät zu registrieren; ohne gebundenes Gerät SOLL er auf den Notfallpfad des Anbieters (5.5.8) hinweisen.

---

## 5.5.6 Operationen auf die eigene Registrierung

*`GET`, `PUT` und `DELETE /register/{client_id}` liegen in der DCR-Erweiterung und werden mit der Client Assertion der Client-Instanz (F2) autorisiert. Ein Registration Access Token wird nicht ausgestellt.*

### A_30101-KC – Autorisierung mit Client Assertion

**Authorization Server** MUSS `GET`, `PUT` und `DELETE /register/{client_id}` ausschließlich mit einer gültigen Client Assertion (`private_key_jwt`, RFC 7523) der adressierten Client-Instanz autorisieren und DARF NICHT ein Registration Access Token oder ein anderes Bearer-Secret für Operationen auf die eigene Registrierung ausstellen oder akzeptieren.

### A_KC-13 – Einmaligkeit der Client Assertion

**Authorization Server** MUSS die `jti` jeder für Operationen auf die eigene Registrierung und die E-Mail-Änderung verwendeten Client Assertion für deren Gültigkeitsdauer als verbraucht führen und eine Wiederverwendung mit `401` ablehnen.

### A_30005-KC – Zulässige Metadatenänderungen

**Authorization Server** MUSS bei `PUT /register/{client_id}` ausschließlich Änderungen an `client_name` und `jwks` (letzteres nur mit Besitznachweis) übernehmen und Änderungen an `redirect_uris`, `attestation_type`, `platform`, `product_id`, `ak_jkt`, `grant_types`, `token_endpoint_auth_method`, `verified_email` und `user_email` mit `invalid_client_metadata` ablehnen.

### A_29921-KC – Rollover mit Besitznachweis

**Authorization Server** MUSS einen Wechsel des Instanzschlüssels ausschließlich als `PUT /register/{client_id}` zulassen, der mit der Client Assertion des bisherigen Schlüssels autorisiert ist und neben dem neuen `jwks` eine vom `nonce_endpoint` bezogene `nonce` sowie `signed_hash_puk_client_sig` als Selbstsignatur mit dem neuen privaten Instanzschlüssel über SHA-256(PuK.Client.Sig.neu || nonce) enthält; bei fehlender, verbrauchter oder abgelaufener Nonce oder ungültiger Selbstsignatur MUSS er mit `invalid_client_metadata` ablehnen.

### A_KC-14 – Rollover-Intervall

**ZETA Client** MUSS den Instanzschlüssel spätestens nach dem von der gematik festgelegten Intervall (initial 2 Jahre) wechseln.

### A_30188-KC – Re-Verankerung an den Attestation Key

**ZETA Client** SOLL für `attestation_type ≠ software` im `PUT` zusätzlich `attestation_pop` über SHA-256(PuK.Client.Sig.neu || nonce) mitführen; **Authorization Server** MUSS einen vorhandenen `attestation_pop` gegen das gepinnte `ak_jkt` prüfen und bei Fehlschlag ablehnen; fehlt `attestation_pop`, MUSS er den Client als nicht mehr hardware-attestiert kennzeichnen.

### A_29925-KC – Atomarer Schlüsselwechsel

**Authorization Server** MUSS nach erfolgreichem `PUT` ausschließlich den neuen Schlüssel für Client Assertions akzeptieren; ein Übergangszeitraum für den alten Schlüssel ist nicht vorgesehen.

### A_KC-15 – Selbst-Deregistrierung

**Authorization Server** MUSS `DELETE /register/{client_id}` zulassen und dabei die Client-Instanz, ihre Bindung, ihr Consent-Objekt und ihre Sessions entfernen sowie die Nachricht N3 auslösen.

### A_29927-KC – Kein Rollover ohne alten Schlüssel

Bei Verlust des Instanzschlüssels MUSS **ZETA Client** eine neue Registrierung mit der gebundenen E-Mail durchführen und die verwaiste Client-Instanz über die Account REST API entbinden.

---

## 5.5.7 Verwaltung eigener Clients

*Die Account REST API (`/realms/zeta-guard/account/...`) liefert dem Nutzer die Consent-Objekte seiner gebundenen Client-Instanzen und seine Sessions. Sie wird mit dem regulären, DPoP-gebundenen Access Token einer gebundenen Client-Instanz aufgerufen.*

### A_25733-KC – Übersicht über die Account REST API

**ZETA Client** MUSS dem Nutzer die Liste der gebundenen Client-Instanzen aus `GET /account/applications` (`clientId`, `clientName`, `createdDate`, `lastAccessedDate`) darstellen und die Entbindung einzelner Client-Instanzen anbieten.

### A_KC-16 – Audience und Rolle

**Authorization Server** MUSS Access Token gebundener mobiler Client-Instanzen mit der Audience `account` und der Client-Rolle `manage-account` ausstellen.

### A_KC-17 – Nur Nutzer-Token

**Authorization Server** DARF NICHT Aufrufe der Account REST API allein mit einer Client Assertion zulassen; erforderlich ist ein DPoP-gebundenes Access Token des betreffenden Identitätsdatensatzes.

### A_29934-KC – Entbinden anderer Clients

**Authorization Server** MUSS dem Nutzer über `DELETE /account/applications/{clientId}/consent` den Widerruf der Bindung jeder eigenen Client-Instanz erlauben und über das dabei entstehende Event `REVOKE_GRANT` die Nachricht N3 auslösen.

### A_KC-18 – Wirkung des Widerrufs

**Authorization Server** MUSS nach Widerruf jede Token-Erneuerung der entbundenen Client-Instanz mit `invalid_grant` ablehnen und eine erneute Bindung nur über einen neuen OIDC-Flow mit E-Mail-Abgleich zulassen.

### A_29939 – Objektbezogene Autorisierung

**Authorization Server** MUSS den Widerruf auf Client-Instanzen des authentisierten Identitätsdatensatzes beschränken und einen fremden `clientId` mit `404` beantworten.

### A_KC-19 – Bereinigung entbundener Clients

**Authorization Server** MUSS Client-Instanzen, deren Bindung widerrufen wurde und die nach einer konfigurierbaren Frist (Default 7 Tage) nicht erneut gebunden wurden, löschen.

### A_29938-KC – Fortbestand des Identitätsdatensatzes

**Authorization Server** MUSS den Identitätsdatensatz einschließlich gebundener E-Mail erhalten, wenn alle Client-Instanzen entbunden oder gelöscht sind, bis die konfigurierte Idle-TTL des Users abgelaufen ist.

### A_KC-20 – Sessions

**ZETA Client** SOLL dem Nutzer die aktiven Sessions aus `GET /account/sessions` anzeigen und das Beenden einzelner Sessions über `DELETE /account/sessions/{id}` anbieten.

---

## 5.5.8 Außerordentliche Löschung (Out-of-Band)

*Der Notfallpfad wird über Admin Console und Admin REST API im Operator-Realm ausgeführt. Sperre und Löschung sind getrennte Admin-Aktionen, die Keycloak mit der Operator-Identität in der implementierten Admin-Event-Hash-Chain protokolliert. Einen Tombstone gibt es nicht; nach der Löschung ist die nächste Registrierung eine Erstnutzung.*

### A_29949-KC – Operator-Realm und Zugang

**ZETA Guard** MUSS Operator-Konten in einem eigenen Realm führen, dessen Anmeldung über X.509-Client-Zertifikate (mTLS) oder einen vom sektoralen IDP unabhängigen Betreiber-IdP erfolgt, und DARF NICHT den Master-Realm für den Betrieb verwenden.

### A_KC-21 – Rollen der Operatoren

**ZETA Guard** MUSS über Admin Permissions die Rechte der Operatoren auf `view-users`, `manage-users` und `manage-clients` des Realms `zeta-guard` beschränken und DARF NICHT Operatoren Rechte an Realm-Konfiguration, Authentifizierungsflows oder Identity Providern einräumen.

### A_29941 – IDP-unabhängiger Identitätsnachweis

**Anbieter** MUSS für die OOB-Löschung einen vom sektoralen IDP unabhängigen Identitätsnachweis auf hohem Vertrauensniveau verlangen und im Ticket dokumentieren.

### A_29947 – Vorrang der Selbst-Recovery

**Anbieter** SOLL vor einer OOB-Löschung prüfen, ob der Nutzer noch über die gebundene E-Mail oder ein gebundenes Gerät verfügt, und in diesem Fall auf die Selbst-Recovery verweisen.

### A_29942-KC – Sperre statt sofortiger Löschung

**Operator** MUSS als ersten Schritt den Identitätsdatensatz sperren (`enabled=false`, Attribut `zeta.oob.ticket=<Ticket-ID>`) und DARF NICHT im selben Schritt Client-Instanzen oder den Identitätsdatensatz löschen.

### A_KC-22 – Einspruchsfrist

**Anbieter** MUSS zwischen Sperre und Löschung eine dokumentierte Einspruchsfrist von mindestens 14 Tagen einhalten und die gebundene E-Mail zu Beginn der Frist benachrichtigen (N6).

### A_29943-KC – Widerspruch

**Anbieter** MUSS während der Einspruchsfrist einen Widerspruch des Nutzers entgegennehmen, der durch Kontrolle über die gebundene E-Mail belegt wird (Bestätigungscode des Anbieters an die gebundene Adresse), und in diesem Fall die Sperre aufheben (`enabled=true`) und N9 versenden.

### A_29944-KC – Ausführung

**Operator** MUSS bei Ausführung der Löschung alle Client-Instanzen, Bindungen und Sessions des Identitätsdatensatzes und den Identitätsdatensatz selbst löschen und N10 an die zuletzt gebundene Adresse versenden.

### A_29946-KC – Funktionstrennung

**Anbieter** MUSS sicherstellen, dass Sperre und Ausführung von unterschiedlichen Operatoren vorgenommen werden, und dies über die Admin Events (Feld `authDetails.userId`) nachweisen.

### A_29940 – Keine Faktorneubindung durch Operatoren

**Operator** DARF NICHT im Rahmen der OOB-Prozesse E-Mail-Adressen setzen, Bindungen herstellen oder Token ausstellen.

---

## 5.5.9 Protokollierung und Benachrichtigung

### A_29948-KC – Revisionssichere Protokollierung

**Authorization Server** MUSS Registrierung, OTP-Verifikation, Bindung, Ablehnung wegen `email_mismatch`, Rollover, Metadatenänderung, Entbindung und E-Mail-Änderung als User Events mit Zeitstempel sowie alle Operator-Aktionen als Admin Events mit Operator-Identität in der implementierten Hash-Chain protokollieren und beide mindestens für die in A_25738 und A_25749 festgelegte Dauer aufbewahren.

### A_KC-23 – Event-Emission durch die DCR-Erweiterung

**Authorization Server** MUSS die Auslöser der Nachrichten N1 und N2 als Event `GRANT_CONSENT` (N2 mit Detail `fastpath=true`), N3 als `REVOKE_GRANT` bzw. `CLIENT_DELETE` und N5 als `UPDATE_EMAIL` jeweils mit `message_id` als Event-Detail emittieren und die Zustellung per E-Mail über den Event-Listener `email` mit Templates je Event-Typ nach Nachrichtenkatalog vornehmen; N7 und N8 MUSS die DCR-Erweiterung direkt versenden und DARF NICHT den Code in Event-Details aufnehmen.

### A_KC-24 – Nachrichtenkatalog (angepasst)

| Nr | message_id | Auslöser | Versender | E-Mail | Push |
| --- | --- | --- | --- | --- | --- |
| N1 | client_added | Bindung (OTP-Pfad), Event `GRANT_CONSENT` | Event-Listener | MUSS | SOLL |
| N2 | client_added_crossguard | Bindung (Fast Path), Event `GRANT_CONSENT` mit `fastpath=true` | Event-Listener | MUSS | SOLL |
| N3 | client_removed | Entbindung (`REVOKE_GRANT`), Selbst-Deregistrierung (`CLIENT_DELETE`) | Event-Listener | MUSS | SOLL |
| N5 | email_changed | E-Mail-Änderung (`UPDATE_EMAIL`), alte und neue Adresse | Event-Listener | MUSS | SOLL |
| N6 | deletion_scheduled | Sperre durch Operator | Anbieter (Prozess) | MUSS | – |
| N7 | otp_verification | OTP bei Registrierung | DCR-Erweiterung | MUSS | NIE |
| N8 | otp_email_change | OTP bei E-Mail-Änderung | DCR-Erweiterung | MUSS | NIE |
| N9 | deletion_vetoed | Aufhebung der Sperre | Anbieter (Prozess) | MUSS | – |
| N10 | deletion_executed | Löschung | Anbieter (Prozess) | MUSS | – |

N4 (Umbenennen) entfällt. Die Nachricht N7 MUSS den Hinweis enthalten, dass der Empfänger den Code nicht weitergeben und bei unerwartetem Erhalt nichts unternehmen soll.

### A_30200, A_30203 – Kanal- und Inhaltsregeln

Unverändert übernommen: Einmalpasswörter nur per E-Mail; keine KVNR, Telematik-ID, Token oder klickbaren Anmelde- und Zurücksetzen-Links in Nachrichten; genannte E-Mail-Adressen maskiert.

### A_KC-25 – Push über Event-Listener (optional)

**ZETA Guard** KANN einen Event-Listener bereitstellen, der die in diesem Abschnitt genannten Events als Push-Nachrichten mit `message_id` an den Notification Service übergibt.

---

## 5.5.10 Zuordnung der bisherigen Anforderungen

| Bisher (2.0.1) | Disposition | Neu |
| --- | --- | --- |
| A_29892 | entfällt (keine TOFU-Erweiterungsschnittstellen außer `/register/{client_id}(/email)`) | – |
| A_29893 | geändert | A_29893-KC |
| A_29894, A_29895 | übernommen | gleich |
| A_29896 | übernommen | gleich |
| A_29897 | aufgegangen in A_29896 | – |
| A_29898 | geändert | A_29898-KC |
| A_29899 | übernommen | gleich |
| A_29900 | geändert (gehashte KVNR als Username) | A_29900-KC |
| A_29901 | geändert | A_29901-KC |
| A_29902 | aufgegangen in A_KC-17, A_30101-KC | – |
| A_29903 | geändert (Bindung im OIDC-Flow) | A_29903-KC |
| A_30086 | entfällt (implementiertes Statusmodell) | 5.5.0 |
| A_30101 | geändert (Wortlaut, gleiche Aussage) | A_30101-KC |
| A_29905 | aufgegangen in A_KC-08 | – |
| A_30085 | geändert (OTP im Rahmen von `/register`, wie implementiert) | A_30085-KC |
| A_30211 | ersetzt durch E-Mail-Abgleich | A_29910-KC, A_KC-04 |
| A_30212–A_30216, A_30218 | entfällt (keine Bindungs-Token, kein Token Exchange, keine Sonder-Scopes) | A_KC-08 |
| A_30217 | geändert | A_30217-KC, A_KC-02 |
| A_30219 | geändert | A_30219-KC |
| A_29909 | geändert | A_29909-KC |
| A_30195 | aufgegangen in A_30101-KC, A_KC-17 | – |
| A_30005-01 | geändert | A_30005-KC |
| A_29910 | geändert (Abgleich statt erneutem OTP) | A_29910-KC |
| A_29911, A_30220, A_30221 | geändert (eigenes Access Token statt RFC 9470) | A_29911-KC, A_30220-KC |
| A_29912 | übernommen | gleich |
| A_29913 | geändert (implementierter Fast Path) | A_29913-KC, A_KC-09 |
| A_29914 | geändert (`user_email`/`redirect_uris` nur für mobile Clients, `sub` optional bis zur Klärung) | A_29914-KC |
| A_29915-01, A_29916, A_29918, A_29919 | übernommen | gleich |
| A_29920 | geändert | A_29920-KC |
| A_29921 | geändert | A_29921-KC, A_KC-14 |
| A_29922, A_29923 | entfällt (Client Assertion `jti` statt Nonce/Envelope) | A_KC-13 |
| A_29924 | entfällt (kein Overlap) | A_29925-KC |
| A_29925 | geändert | A_29925-KC |
| A_29926 | entfällt (getrennte Mechanismen) | – |
| A_29927 | geändert | A_29927-KC |
| A_29933 | geändert | A_29933-KC |
| A_30188, A_30189 | zusammengeführt | A_30188-KC |
| A_29934 | geändert (Account REST API) | A_29934-KC, A_KC-18 |
| A_29935 | aufgegangen in A_KC-23 | – |
| A_29936 | entfällt (Identität bleibt bestehen) | A_29938-KC |
| A_29937 | aufgegangen in A_29898-KC | – |
| A_29938 | geändert | A_29938-KC |
| A_29939 | übernommen | gleich |
| A_29940 | übernommen | gleich |
| A_29941 | übernommen (Adressat Anbieter) | gleich |
| A_29942, A_29943, A_29946 | geändert (Prozess statt Endpunkte) | A_29942-KC, A_29943-KC, A_29946-KC, A_KC-22 |
| A_29944 | geändert (Löschung statt Tombstone) | A_29944-KC |
| A_29945 | entfällt (kein Tombstone) | – |
| A_29947 | übernommen | gleich |
| A_29948 | geändert (Hash-Chain) | A_29948-KC |
| A_29949 | geändert | A_29949-KC, A_KC-21 |
| A_25432-01, A_25758 | geändert (implementierter Ablauf) | A_25432-01-KC |
| A_25733 | geändert | A_25733-KC |
| A_25734 | offen: Keycloak bietet keine nutzerseitige Ereignisliste; streichen oder als Erweiterung einplanen (Prüfpunkt) | – |
| A_25748-02 | geändert (Konfigurationswert) | A_25748-02-KC |
| A_29658 / Kapitel 5.3.2.2 | zurückführen auf implementierten Ablauf; Bindungsschritt in Abb-ZETA-OIDC-Token-Bezug ergänzen | 5.5.1, 5.5.4 |
| A_30199–A_30210 | anzupassen (Kapitel 5.12.5) | A_KC-24; A_30200, A_30203 unverändert |
| Annex `zeta-guard-client-management.yaml` | reduzieren auf `/register`, `/register/verify`, `/register/{client_id}`, `/register/{client_id}/email` | `verify-request.yaml` um `email_change` ergänzen |
| Annex `zeta-guard-admin-oob.yaml` | entfällt | Betriebshandbuch OOB |
| Annex `zeta-attestation-token.yaml` | unverändert; Zeitpunkt der `sub`-Befüllung klären (Prüfpunkt) | gleich |
