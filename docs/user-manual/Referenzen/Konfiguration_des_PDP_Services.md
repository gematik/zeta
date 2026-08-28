# Konfiguration des Authentication Services (PDP)

Der Authentication Service unterstützt
alle [Standardkonfigurationsparameter von Keycloak](https://www.keycloak.org/server/all-config).

Zusätzlich werden folgende Umgebungsvariablen zur internen Konfiguration
verwendet:

| Name                                                                 | Standardwert                   | erforderlich?         | Beschreibung                                                                                                                                                                                                                                                                                                                                                                 |
|----------------------------------------------------------------------|--------------------------------|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `GENESIS_HASH`                                                       | —                              | ja (Erstinstallation) | Seed-Wert für die Admin-Event-Hash-Chain. Wird einmalig beim ersten Helm-Install über `authserver.genesisHash` gesetzt und danach unveränderlich im Cluster-Secret gespeichert. Empfohlenes Format: 64-stelliger Hex-String (`openssl rand -hex 32`).                                                                                                                        |
| `NONCE_TTL`                                                          | PT1H (1 Stunde)                | nein                  | Wird für die Berechnung der Lebensdauer eines vom PDP erzeugten [`nonce`](https://de.wikipedia.org/wiki/Nonce) verwendet. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                                                                                                                                      |
| `SERVICE_DOCUMENTATION_URL`                                          | https://gemspec.gematik.de/... | nein                  | URL der Service-Dokumentation, diese wird vom "Well-known"-Endpunkt im Feld `service_documentation` ausgegeben.                                                                                                                                                                                                                                                              |
| `SMCB_USER_MAX_CLIENTS`                                              | 256                            | nein                  | Maximal erlaubte Anzahl der Clients pro SMC-B-User (pro Telematik-ID)                                                                                                                                                                                                                                                                                                        |
| `SMCB_HASHING_PEPPER`                                                | —                              | ja (Erstinstallation) | Geheimer Pepper-Wert für SMC-B-Nutzer-Hashes (Schutz vor Rainbow-Table-Angriffen). Wird einmalig beim ersten Helm-Install über `authserver.smcbHashingPepper` gesetzt und danach unveränderlich im Cluster-Secret gespeichert. Empfohlenes Format: UUID (`uuidgen`).                                                                                                         |
| `SMCB_KEYSTORE_LOCATION`                                             |                                | ja                    | Absoluter Pfad des zur Validierung der Zertifikate verwendenden Keystore (mount point)                                                                                                                                                                                                                                                                                       |
| `SMCB_KEYSTORE_PASSWORD`                                             |                                | ja                    | Passwort für den zur Validierung verwendeten Keystore                                                                                                                                                                                                                                                                                                                        |
| `SMCB_KEYSTORE_META_LOCATION`                                        |                                | **ja**                | Absoluter Pfad der Metadaten-Datei zum SMC-B-Truststore. Die JSON-Datei hält je Vertrauensanker `friendlyName`, `tspName` und `revokedSince` und bestimmt damit dessen Sperrstatus. Fehlt zu einem Eintrag die Angabe, gilt er als nicht gesperrt.                                                                                                                           |
| `TPM_KEYSTORE_LOCATION`                                              |                                | **ja**                | Absoluter Pfad des TPM-Truststore (mount point).                                                                                                                                                                                                                                                                                                                             |
| `TPM_KEYSTORE_PASSWORD`                                              |                                | **ja**                | Passwort des TPM-Truststore.                                                                                                                                                                                                                                                                                                                                                 |
| `OCSP_KEYSTORE_LOCATION`                                             |                                | nein (s.u.)           | Absoluter Pfad des Truststore mit den OCSP-Signer-Zertifikaten.                                                                                                                                                                                                                                                                                                              |
| `OCSP_KEYSTORE_META_LOCATION`                                        |                                | nein (s.u.)           | Absoluter Pfad der Metadaten-Datei zum OCSP-Truststore, Aufbau wie bei `SMCB_KEYSTORE_META_LOCATION`.                                                                                                                                                                                                                                                                        |
| `OCSP_KEYSTORE_PASSWORD`                                             |                                | nein (s.u.)           | Passwort des OCSP-Truststore.                                                                                                                                                                                                                                                                                                                                                |
| `CLIENT_REGISTRATION_TTL`                                            | PT5M (5 Minuten)               | nein                  | Lebensdauer eines registrierten Clients im Status "pending", bevor er wieder gelöscht wird. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                                                                                                                                                                    |
| `CLIENT_REGISTRATION_SCHEDULER_INTERVAL`                             | PT2M (2 Minuten)               | nein                  | Prüfungsinterval für das Abräumen nicht (mehr) verwendeter Clients. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                                                                                                                                                                                            |
| `CLIENT_REGISTRATION_STARTUP_DELAY`                                  | PT20S (20 Sekunden)            | nein                  | Ab wann nach Serverstart soll die Prüfungen starten. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                                                                                                                                                                                                           |
| `SMCB_IDLE_CLIENT_TTL`                                               | P1Y (1 Jahr)                   | nein                  | Lebensdauer eines nicht mehr aktiv verwendeten Clients, bevor er gelöscht wird. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                                                                                                                                                                                |
| `SMCB_IDLE_USER_TTL`                                                 | P1Y (1 Jahr)                   | nein                  | Lebensdauer eines nicht mehr aktiv verwendeten Benutzers (entsprechend einer Telematik-ID), bevor er gelöscht wird. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                                                                                                                                            |
| `TRUSTSTORE_RELOAD_ENABLED`                                          | true                           | nein                  | Ob die Truststores (`SMCB_`, `TPM_` und `OCSP_KEYSTORE_LOCATION`) im laufenden Betrieb neu geladen werden. `false` liest sie nur einmal beim Start.                                                                                                                                                                                                                          |
| `TRUSTSTORE_RELOAD_INTERVAL`                                         | PT1H (1 Stunde)                | nein                  | Intervall, in dem die Truststores auf Änderungen geprüft werden. Geändertes Material wird ohne Neustart und ohne Unterbrechung laufender Anfragen übernommen. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format als Dauer von höchstens Stunden angegeben werden (`PT1H`, nicht `P1D`). Die erste Prüfung läuft ein Intervall nach dem Serverstart. |
| `ZETA_OIDC_FLOW_ENABLED`                                             | false                          | nein                  | Zentraler Schalter für den [mobilen Client-Flow](../Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md) (SekIDP, `authorization_code`, E-Mail-Bindung). Muss am Keycloak-Container **und** am Konfigurations-Container gesetzt werden. Solange die zugehörige Attestierungsprüfung gemockt ist, sollte der Schalter in produktiven Umgebungen aus bleiben.               |
| `KC_SPI_IDENTITY_PROVIDER__ZETA_SEKIDP_OIDC__MTLS_ENABLED`           | false                          | nein                  | Aktiviert mTLS (`self_signed_tls_client_auth`, A_23183) für PAR- und Token-Requests an den SekIDP.                                                                                                                                                                                                                                                                           |
| `KC_SPI_IDENTITY_PROVIDER__ZETA_SEKIDP_OIDC__MTLS_KEYSTORE_LOCATION` | —                              | bei mTLS              | Absoluter Pfad des PKCS12-Keystores mit dem TLS-Client-Zertifikat für den SekIDP. Muss genau einen Eintrag enthalten; unvollständige Konfiguration bricht den Start ab.                                                                                                                                                                                                      |
| `KC_SPI_IDENTITY_PROVIDER__ZETA_SEKIDP_OIDC__MTLS_KEYSTORE_PASSWORD` | —                              | bei mTLS              | Passwort des mTLS-Keystores (gilt für Store und Schlüssel).                                                                                                                                                                                                                                                                                                                  |

## Truststores und ihre Metadaten-Dateien

Der Authentication Service lädt beim Start drei Truststores. **SMC-B und TPM sind
Pflicht** — fehlt eine der fünf zugehörigen Variablen
(`SMCB_KEYSTORE_LOCATION`, `SMCB_KEYSTORE_META_LOCATION`,
`SMCB_KEYSTORE_PASSWORD`, `TPM_KEYSTORE_LOCATION`, `TPM_KEYSTORE_PASSWORD`),
bricht der Start mit `Missing environment variable »<NAME>«` ab.

> **Achtung bei Bestandsdeployments:** `SMCB_KEYSTORE_META_LOCATION`,
> `TPM_KEYSTORE_LOCATION` und `TPM_KEYSTORE_PASSWORD` sind mit dem
> Truststore-Reload hinzugekommen. Eine Konfiguration, die nur die beiden
> älteren `SMCB_*`-Variablen setzt, startet nicht mehr. Beim Deployment über das
> Helm Chart werden alle fünf gesetzt; betroffen sind eigene Deployments und
> abweichende Container-Konfigurationen.

Der OCSP-Truststore ist optional, aber **alles oder nichts**: Er wird nur
verwendet, wenn `OCSP_KEYSTORE_LOCATION`, `OCSP_KEYSTORE_META_LOCATION` und
`OCSP_KEYSTORE_PASSWORD` **alle drei** gesetzt sind. Fehlt einer der Werte,
bleibt die OCSP-Sperrprüfung stillschweigend deaktiviert — ohne Fehlermeldung.
Wer eine Sperrprüfung erwartet, sollte daher alle drei Variablen prüfen; zum
Verhalten bei nicht bestimmbarem Sperrstatus siehe
[SMC-B OCSP-Sperrprüfung](Referenz_des_Helm_Charts.md#smc-b-ocsp-sperrprüfung).

Die Metadaten-Datei ist eine JSON-Liste, die den Truststore begleitet und für
jeden Vertrauensanker festhält, ob und seit wann er gesperrt ist. Der
TPM-Truststore hat bewusst keine — seine Einträge tragen keinen Sperrstatus.

## Aktualisierung der Truststores im laufenden Betrieb

Verfügbar ab zeta-guard-helm-Chart-Version **1.3.0**.

Der Authentication Service liest die Truststores beim Start und prüft sie danach im Intervall
`TRUSTSTORE_RELOAD_INTERVAL`. Die erste Prüfung läuft ein Intervall nach dem Serverstart.

Verglichen wird ein Hash über die *Dateibytes* der Truststores und ihrer Metadaten-Dateien. Erst
wenn dieser Hash sich bewegt hat, werden die Dateien erneut gelesen und geparst — der Normalfall
kostet also nur das Lesen weniger Megabyte und kein Parsen der rund 2000 TPM-Zertifikate.

Daraus folgt ein bewusst akzeptiertes Verhalten: **pro Provisioning-Lauf gibt es genau einen
Reload**, auch wenn sich kein Zertifikat geändert hat. Der Provisioning Processor erzeugt seine
PKCS12-Dateien bei jedem Lauf neu, und `openssl pkcs12 -export` wählt dabei jedes Mal einen
frischen Salt — die Bytes unterscheiden sich also immer. Der Vergleich über die Bytes ist trotzdem
der richtige: ein Vergleich über die geparsten Zertifikate übersieht Änderungen am
TPM-Truststore vollständig, weil dessen Einträge ohne `friendlyName` exportiert werden und damit
für `KeyStore.aliases()` unsichtbar sind. Im Log erscheint der TPM-Truststore deshalb dauerhaft
mit `tpm=0`; das ist erwartet und kein Fehler.

Übernommen wird das Material als Ganzes: laufende Anfragen arbeiten mit dem Stand, mit dem sie
begonnen haben, neue Anfragen mit dem neuen. Es gibt keinen Neustart und keine Downtime.

Lässt sich eine Datei nicht lesen, nicht parsen oder bewegt sich der Hash noch zwischen
Prüfung und Lesen — weil etwa ein Provisioning-Lauf gerade mitten in der Veröffentlichung ist —
bleibt das bisherige Material in Benutzung und der Versuch wird im nächsten Intervall wiederholt.
Beide Fälle werden geloggt.

Damit das greift, müssen die Dateien zur Laufzeit überhaupt neu geschrieben werden. Im Helm Chart
leistet das der Provisioning Processor als Sidecar, der standardmäßig aktiv ist; siehe
`provisioningProcessor.schedule` in der
[Referenz des Helm Charts](Referenz_des_Helm_Charts.md).

Ein übernommener Stand wird mit den Anzahlen pro Truststore und den hinzugekommenen bzw.
entfallenen Vertrauensankern geloggt:

```
🔄 Reloaded trust material (smcb=37, tpm=0, ocsp=131): smcb added=[GEM.SMCB-CA55 TEST-ONLY] removed=[]
```

> **Hinweis:** Werden die Truststores als einzelne Dateien gemountet (bei Kubernetes über `subPath`,
> bei Docker als Datei-Bind-Mount), ist die Inode festgenagelt und ein Austausch per Rename bleibt
> im Container unsichtbar. Es muss das *Verzeichnis* gemountet werden.

## Well-Known-Dokument des Authorization Servers

Der Authentication Service veröffentlicht seine Metadaten unter
`/realms/{realm}/.well-known/zeta-guard-well-known` (Schema `as-well-known.yaml`
v1.1.0). Der PEP-Proxy stellt dieses Dokument zusätzlich unter
`/.well-known/oauth-authorization-server` bereit, indem er intern dorthin
weiterleitet — siehe
[Konfiguration der Well-Known-Endpunkte](Konfiguration_der_Well-Known_Endpunkte.md).

Neben den aus OpenID Connect Discovery bekannten Feldern (`issuer`,
`authorization_endpoint`, `token_endpoint`, `jwks_uri`, `registration_endpoint`,
`scopes_supported`, `response_types_supported`, `response_modes_supported`,
`grant_types_supported`, `token_endpoint_auth_methods_supported`,
`token_endpoint_auth_signing_alg_values_supported`) enthält es folgende
ZETA-spezifische bzw. für ZETA festgelegte Felder:

| Feld                                    | Beschreibung                                                                                                                                           |
|-----------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------|
| `api_versions_supported`                | Unterstützte Vertragsversionen der Token-Ausstellung (A_29691). Aufbau je Eintrag: `major_version`, `version`, `status`, optional `documentation_uri`. |
| `nonce_endpoint`                        | Endpunkt, an dem der Client die Nonce für die Client-Assertion abholt.                                                                                 |
| `pushed_authorization_request_endpoint` | Endpunkt für Pushed Authorization Requests (PAR, RFC 9126).                                                                                            |
| `require_pushed_authorization_requests` | In ZETA fest `true` — Authorization Requests sind ausschließlich über PAR zulässig.                                                                    |
| `redirection_endpoint`                  | Broker-Callback, an den der Client den Authorization Code des SekIDP weiterreicht (A_29672).                                                           |
| `revocation_endpoint`                   | Endpunkt zum Widerruf von Tokens (RFC 7009, A_29996).                                                                                                  |
| `code_challenge_methods_supported`      | Unterstützte PKCE-Verfahren.                                                                                                                           |
| `openid_providers_endpoint`             | Endpunkt zu den nutzbaren OpenID Providern. Zeigt derzeit auf dieselbe URL wie `registration_endpoint`.                                                |
| `service_documentation`                 | URL der Service-Dokumentation, konfigurierbar über `SERVICE_DOCUMENTATION_URL` (siehe Tabelle oben).                                                   |

Aktuell wird genau eine Vertragsversion ausgewiesen:

```json
{
    "api_versions_supported": [
        {
            "major_version": 1,
            "version": "1.0.0",
            "status": "stable"
        }
    ]
}
```

> **Hinweis:** Vertragsversion 2 (Resource Indicators nach
> [RFC 8707](https://www.rfc-editor.org/rfc/rfc8707)) ist noch nicht umgesetzt und
> erscheint deshalb nicht in `api_versions_supported`.

Die PAR- und Redirection-Felder gehören zum mobilen Client-Flow; ob dieser aktiv
ist, steuert `ZETA_OIDC_FLOW_ENABLED` (siehe Tabelle oben und
[Wie der mobile Client-Flow funktioniert](../Anleitungen/Wie_der_mobile_Client-Flow_funktioniert.md)).
