# Änderungsliste gemSpec_ZETA — Client-Registry für redirect_uris und Erweiterung des Provisioning Images

**Stand:** 2026-09-29 · **Bezug:** gemSpec_ZETA V2.0.0 CC (r1737981)
**Anlass:** Die Spezifikation sagt, dass der Authorization Server beim DCR prüft, ob die übergebenen `redirect_uris`
registriert sind (Hinweis zu Abb-ZETA-DCR-für-mobile-Clients). Sie legt aber nicht fest, woher der AuthS die
registrierten URIs bekommt. Das Provisioning Image (5.6.5.1) enthält sie nicht, die Policy-Daten auch nicht.
Zusätzlich wird das Provisioning Image um ein Zertifikat für die Pseudonymisierung erweitert (Abschnitt B).
**Repo-Stand:** Neues Schema `client-registry.yaml` 1.0.0 mit Beispiel
`examples/schemas/client-registry/client-registry.json`. Querverweise in `dcr-request.yaml` 1.1.2,
`as-entity-statement.yaml` 1.0.1 und `zeta-error.yaml` 1.3.0 (Fehlercode `invalid_redirect_uri`). Diese Liste enthält,
was **in der Spezifikation** noch umzusetzen ist.

## Befund

| Stelle | Heute | Lücke |
| --- | --- | --- |
| A_29723 (5.4.1) | Hersteller meldet `oidc_redirect_uri` und `app_redirect_uri` an die gematik, nur für mobile Apps. | Kein Weg von der gematik zum AuthS. Keine Zuordnung zur `product_id`. Nicht für andere Clients mit Authorization Code Flow. |
| Hinweis zu Abb-ZETA-DCR-für-mobile-Clients (5.3.2.2) | „…der AuthS prüft beim DCR, ob die übergebenen redirect_uris registriert sind.“ | Keine AFO, keine Referenzquelle, keine Fehlerantwort. |
| A_25656 (5.8.2.1) | AuthS weist die Redirect-URLs aller zulässigen Clients im Entity Statement aus. | Quelle der Liste offen. |
| A_29740 (5.6.5.3) | Liste der Trust Anchors aus dem Provisioning Image. | Keine Client-Metadaten. |

## Lösungsansatz

Die gematik legt die gemeldeten Client-Metadaten als **Client-Registry** in das Provisioning Image
(`/client-registry/*.json`, Schema `client-registry.yaml`). Sie enthält nur die Zuordnung `product_id` →
`redirect_uris`. Eine Umgebungsangabe braucht sie nicht, weil jeder ZETA Guard das Provisioning Image seiner Umgebung
(prod/test) bezieht.

Eine `product_id` gilt für genau eine Plattform. Bietet ein Hersteller seine App für Android und Apple an, hat er zwei
`product_id`s, weil sich die Versionen der Plattformen unabhängig ändern. Jede `redirect_uri` ist genau einer
`product_id` zugeordnet.

Warum das Provisioning Image und nicht das OPA-Bundle:

- Das Provisioning Image ist schon der Weg für Daten der gematik, die der AuthS selbst prüft (Trust Anchors,
  vTPM-Wurzeln nach A_30336).
- Die Policy Engine entscheidet beim Token Request, nicht bei der Registrierung (Hinweis in 5.4.8.1). Für eine
  DCR-Prüfung über das OPA-Bundle müsste der AuthS beim DCR zusätzlich die Policy Engine befragen.
- Die Registry ist für alle Fachdienste gleich. Welche Produkte ein Fachdienst zulässt, bleibt in den Policy-Daten
  (`allowed_products`) und wird beim Token Request entschieden.

## A. Zu ändernde Anforderungen

### A_29723 → A_29723-01 (5.4.1) — Meldung von Client-Metadaten

Heute nur für mobile Applikationen und ohne Bezug zur `product_id`.

**Vorschlag:**

> Der Hersteller eines Clientsystems MUSS über einen Prozess der gematik die folgenden Client-Metadaten an die gematik
> melden:
>
> - fortlaufend im Betrieb alle Änderungen von aktiv unterstützten Versionen seines Clients (Claim `product_version`),
> - bei Nutzung von TPM Attestation die kryptografischen Hashes der unveränderlichen Bestandteile (Immutable Code /
>   Binärdateien) jeder gemeldeten Produktversion des Clients,
> - bei Clientsystemen, die einen Authorization Code Flow nutzen, je `product_id` die `oidc_redirect_uri` nach dem Schema
>   `/cb/<app>/oidc` (für die Weiterleitung an den Redirection-Endpunkt des ZETA Guards) und die `app_redirect_uri`
>   nach dem Schema `/cb/<app>/app` (für die Weiterleitung an den Token-Endpunkt des ZETA Guards).
>
> Die Metadaten MÜSSEN je `product_id` gemeldet werden; eine `product_id` gilt für genau eine Plattform. Der Hersteller
> MUSS die Metadaten melden, bevor er eine Version mit neuen oder geänderten Werten ausliefert. Er MUSS eine
> `redirect_uri` zur Entfernung melden, bevor er die Kontrolle über deren Domain aufgibt.

**Begründung Domain-Klausel:** Wer die Domain einer registrierten claimed-HTTPS-URI übernimmt, kann über
`apple-app-site-association` bzw. `assetlinks.json` eine eigene App mit dieser URI verknüpfen.

### Hinweis zu Abb-ZETA-DCR-für-mobile-Clients (5.3.2.2) — Text anpassen

Letzten Satz des Hinweises ersetzen:

> Die App ist inkl. `redirect_uris` bei der gematik registriert (A_29723-01) und in der Client-Registry des
> Provisioning Images aufgeführt; der AuthS prüft beim DCR die übergebenen `redirect_uris` gegen die Client-Registry
> (A_xxxx1).

### A_25656 → A_25656-01 (5.8.2.1) — Entity Statement

**Vorschlag:**

> Der PDP Authorization Server MUSS alle `redirect_uris` der Client-Registry des Provisioning Images, deren letzter
> Pfad-Abschnitt `oidc` ist, als erlaubte Redirect-URLs im Entity Statement ausweisen. Ändert sich diese Menge, MUSS
> er das Entity Statement neu ausstellen (A_28857).

Siehe offenen Punkt D.1 zur Freigabe durch den Federation Master.

## B. Kapitel 5.6.5 — Provisioning Image

Das Provisioning Image erhält zwei neue Verzeichnisse:

| Verzeichnis | Inhalt | Verwendet von | Anlass |
| --- | --- | --- | --- |
| `/client-registry/` | Zuordnung `product_id` → `redirect_uris` nach [client-registry.yaml] | PDP Authorization Server | Prüfung der `redirect_uris` (A_xxxx1, A_xxxx3), Entity Statement (A_25656-01) |
| `/pseudonymization-key/` | X.509-Zertifikat (PEM), mit dem Pseudonyme erzeugt werden | PDP Policy Engine (OPA) | Pseudonymisierung von KVNR und Telematik-ID im Decision Log (A_28867), einheitlich über alle ZETA Guard Instanzen einer Umgebung |

### 5.6.5.1 Struktur und Inhalt — Verzeichnisbaum und Beschreibung ergänzen

Verzeichnisbaum ersetzen (neue Einträge markiert):

```text
 .
 |-- .manifest
 |-- .revision
 |-- ECC-RSA_TSL-test.xml
 |-- TrustedTpm.cab
 |-- android-roots
 |   '-- roots.json
 |-- apple-roots
 |   '-- apple-root.pem
 |-- client-registry                     <- neu
 |   '-- client-registry.json
 |-- federation-master
 |   '-- federation-master.yaml
 |-- federation-master.yaml
 |-- policy-engine-bundle-keys
 |   |-- ca
 |   |   |-- GEM.KOMP-CA8.pem
 |   |   '-- GEM.RCA7.pem
 |   '-- signers
 |       '-- ZETA_PIPPAP_Policies_03.06.2026_16_31.pem
 |-- pseudonymization-key                <- neu
 |   '-- pseudonymization-key.pem
 |-- roots.json
 |-- ti-roots
 |   '-- roots.json
 |-- trusted-tpm
 |   |-- TrustedTpm.cab
 |   '-- vtpm-roots.pem                  <- neu im Baum, siehe Nebenbefund
 '-- tsl
     '-- ECC_PU_TSL_10322.xml
```

Nach dem Absatz zu `.revision` ergänzen:

> `/client-registry/`: Client-Registry nach [client-registry.yaml]. Sie enthält je `product_id` die nach A_29723-01
> gemeldeten `redirect_uris`.
>
> `/pseudonymization-key/`: X.509-Zertifikat im PEM-Format, dessen Schlüssel die PDP Policy Engine zur
> Pseudonymisierung von KVNR und Telematik-ID im Decision Log verwendet (A_xxxx4). Alle ZETA Guard Instanzen einer
> Umgebung erhalten dasselbe Zertifikat und bilden damit für denselben Identifikator dasselbe Pseudonym. So bleiben
> Ereignisse derselben Identität im TI-SIEM über alle Fachdienste hinweg verknüpfbar.

Die Dateinamen in beiden Verzeichnissen sind nach A_29738 dynamisch zu ermitteln.

In die Liste der Annexe `[client-registry.yaml]` mit Link
`https://raw.githubusercontent.com/gematik/zeta/refs/heads/main/src/schemas/client-registry.yaml` aufnehmen.

**Nebenbefund:** A_30336 (Hinweis) und die Anforderung zur vTPM-Attestierung in 5.4.8 verweisen auf
`/trusted-tpm/vtpm-roots.pem`. Der Verzeichnisbaum in 5.6.5.1 führt die Datei bisher nicht auf.

### A_29740 → A_29740-01 (5.6.5.3) — Verwendung der Daten des Provisioning Images

Titel ändern in „PDP Authorization Server, Verwendung Trust Anchor und Client-Registry des Provisioning Images“. Nach
dem Punkt „Plattform-Attestierung“ ergänzen:

> - **Client-Metadaten:** Die Client-Registry unter `/client-registry/` MUSS als Referenz für die Prüfung der
>   `redirect_uris` (A_xxxx1, A_xxxx3) und für die `redirect_uris` im Entity Statement (A_25656-01) verwendet werden.

### Neu: A_xxxx4 (5.6.5.3) — PDP Policy Engine, Pseudonymisierung im Decision Log

> Die PDP Policy Engine MUSS KVNR und Telematik-ID in den Decision Logs nach A_28867 ausschließlich als Pseudonym
> ausweisen. Sie MUSS das Pseudonym mit dem Schlüssel des X.509-Zertifikats aus `/pseudonymization-key/` des
> Provisioning Images bilden und DARF NICHT eigene oder instanzspezifische Schlüssel dafür verwenden. Das gilt für
> die aktive Instanz und die Simulations-Instanz (A_25739-03) und für alle Stellen des Decision Logs, an denen die
> Identifikatoren vorkommen (Input, Result, Reasons).

**Hinweis:** OPA schreibt standardmäßig den vollständigen Input in den Decision Log. Ohne Maskierung stünden KVNR und
Telematik-ID dort im Klartext, z. B. aus den Claims des Subject Tokens bzw. ID Tokens.

Die Integrität des Zertifikats ist über die Signatur des Provisioning Images abgesichert (A_29739). Verfahren und
Umsetzung in OPA sind noch festzulegen (D.5).

### A_29743 → A_29743-01 (5.6.5.4) — Aktualisierung der Provisioning Daten

Heute: „zyklisch“ ohne Intervall. Das Entfernen einer `redirect_uri` ist sicherheitsrelevant und braucht eine
begrenzte Wirkzeit.

**Ergänzen** unter „Erkennung neuer Versionen“:

> Der ZETA Guard MUSS mindestens einmal pro Stunde prüfen, ob eine neue Version vorliegt.

Das Intervall ist ein Vorschlag. Alternativ 60 Sekunden wie beim OPA-Bundle (A_25739-03).

In den Lifecycle-Text vor A_29743 ergänzen:

> Änderungen der Client-Registry stellt die gematik nach Abschluss des Meldeprozesses nach A_29723-01 bereit;
> das Entfernen von `redirect_uris` unverzüglich. Ein Wechsel des Pseudonymisierungszertifikats ändert alle danach
> gebildeten Pseudonyme im Decision Log; die gematik kündigt ihn vorab an.

## C. Neue Anforderungen

### A_xxxx1 (5.8.2, nach A_26585-03) — Prüfung der redirect_uris bei der Registrierung

> Enthält ein Registrierungsrequest (`POST /register`) `redirect_uris`, MUSS der Authorization Server jede übergebene
> URI per exaktem String-Vergleich gegen die `redirect_uris` des Eintrags der Client-Registry zur `product_id` der
> Registrierung prüfen. Die `product_id` entnimmt er bei `attestation_type` `zeta_attestation_token` dem Token, sonst
> dem Request.
>
> Findet der Authorization Server keinen passenden Eintrag oder ist eine URI dort nicht aufgeführt, MUSS er die
> Registrierung mit HTTP 400 und `error` = `invalid_redirect_uri` ([RFC7591] Abschnitt 3.2.2) ablehnen. Er MUSS die
> geprüften `redirect_uris` im Registrierungsdatensatz speichern.

**Hinweis (Legacy):** Ohne `product_id` im Request gibt es keinen Eintrag, der sich bestimmen lässt. Der
Authorization Server MUSS dann gegen die Vereinigungsmenge aller `redirect_uris` der Client-Registry prüfen und SOLL
die Registrierung protokollieren. Das ist abwärtskompatibel, bindet die URI aber nicht an ein Produkt.
Bei der nächsten Major-Version von `dcr-request.yaml` wird `product_id` Pflicht, dann entfällt dieser Fall.

### A_xxxx3 (5.8.2) — Erneute Prüfung beim Authorization Request

> Der Authorization Server MUSS bei PAR und Authorization Request prüfen, dass die übergebene `redirect_uri` weiterhin
> in der Client-Registry für die `product_id` des Registrierungsdatensatzes aufgeführt ist. Ist sie das nicht
> mehr, MUSS er den Request mit `error` = `invalid_request` ablehnen.

**Begründung:** Ohne diese Prüfung wirkt das Entfernen einer URI aus der Registry nur auf neue Registrierungen.
Bereits registrierte Clients würden weiter Codes an eine möglicherweise übernommene Domain erhalten.

## D. Offene Punkte

### D.1 Freigabe geänderter redirect_uris durch den Federation Master

Nach A_27504-01 (Föderation, außerhalb gemSpec_ZETA; siehe `as-entity-statement.yaml` Regel 4) darf eine Relying
Party `redirect_uris` erst nach positiver Rückmeldung des Superiors ändern. Mit A_25656-01 ändert jede neue App das
Entity Statement **jedes** ZETA-AuthS. Einzeln beantragt ist das nicht betreibbar.

Vorschlag zur Abstimmung mit der Föderation: Die gematik holt die Freigabe zentral ein, bevor sie die Client-Registry
veröffentlicht. Der Federation Master behandelt `redirect_uris` von ZETA-AuthS als freigegeben, wenn sie in der
veröffentlichten Client-Registry stehen. Dafür ist eine Ausnahme bzw. Ergänzung zu A_27504-01 nötig.

### D.2 Referenz für die „gepinnte App-Identität“

Die Spezifikation verweist auf eine „gepinnte App-Identität“ (Play-Integrity-Prüfung in 5.3: „`requestPackageName`
zur gepinnten App-Identität passt“; Fast-Path Schritt (23) in 5.3.2.2: „Prüfung des rpIdHash“). Laut
`dcr-request.yaml` prüft der AuthS die `product_id` gegen die attestierte App-Identität. Wogegen, ist nicht festgelegt:
Die Zuordnung `product_id` → Apple App-ID bzw. Android Package-Name und Signaturzertifikat erhält der AuthS nicht.
Die Client-Registry deckt das bewusst nicht ab; die Lücke ist getrennt zu klären.

### D.3 Referenzwerte für TPM-Clients

A_29723 fordert für TPM-Clients die Hashes bzw. den Code-Signatur-Schlüssel je `product_id` (`dcr-request.yaml`:
„Die Referenz MUSS über die gepinnte product_id nachgeschlagen werden“). Auch deren Weg zum AuthS bzw. zur Policy
Engine ist nicht festgelegt. `client-registry.yaml` kann dafür um ein Feld je Eintrag erweitert werden.
Das ist nicht Teil dieses Vorschlags.

### D.4 Serverseitige Clients

Der offene Punkt in 5.4.8.1 (gematik-Registrierung serverseitiger ZETA Clients je `product_id`) kann über dieselbe
Registry gelöst werden, z. B. mit einem Feld für die Betriebsart. Heute steht diese Klassifikation in den
Policy-Daten.

### D.5 Pseudonymisierung im Decision Log mit dem Zertifikat aus `/pseudonymization-key/`

Der Anwendungsbereich steht fest: KVNR und Telematik-ID im Decision Log der PDP Policy Engine (A_28867, A_xxxx4).
Festzulegen sind:

- **Verfahren:** Algorithmus und Eingabeformat. Das Zertifikat liegt im Provisioning Image und ist damit nicht
  geheim. Wird das Pseudonym allein aus dem öffentlichen Schlüssel und dem Identifikator berechnet, kann jeder mit
  Zugriff auf das Image Pseudonyme für geratene Identifikatoren nachrechnen. KVNR und Telematik-ID haben einen
  strukturierten Wertebereich, das ist also eine Wörterbuchsuche. Das Verfahren muss das ausschließen, z. B. durch
  deterministische Verschlüsselung, bei der nur der Inhaber des privaten Schlüssels aufdecken kann.
- **Umsetzung in OPA:** Die Rego-Builtins bieten Hashes, HMAC und JWS-Signaturen, aber keine Verschlüsselung mit
  einem öffentlichen Schlüssel. Eine Decision-Log-Mask-Policy (`system.log.mask`) im OPA-Bundle kann Felder
  ersetzen, ein Verschlüsselungsverfahren aber nicht selbst rechnen. Möglich sind ein eigenes Builtin bzw. Plugin in
  der Policy Engine des Herstellers oder ein Prozessor im Telemetrie-Gateway vor der Ausleitung. Die Anforderung muss
  festlegen, an welcher Stelle pseudonymisiert wird; Klartext darf die Policy Engine bzw. den ZETA Guard nicht
  verlassen.
- **Bereitstellung an OPA:** Wie das Zertifikat aus dem Provisioning Image in die Policy Engine gelangt (analog
  A_29741 für die Bundle-Signer-Keys).
- **Aufdeckung:** Wer den privaten Schlüssel hält (z. B. TI-SIEM bzw. gematik) und unter welchen Bedingungen
  Pseudonyme aufgedeckt werden dürfen.
- **Wechsel:** Übergangszeitraum mit altem und neuem Zertifikat (analog A_29950 beim Root-CA-Wechsel) und
  Auswirkung auf die Verknüpfbarkeit im TI-SIEM über den Wechsel hinweg.
