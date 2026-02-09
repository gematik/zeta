# Konfiguration des Authentication Services (PDP)

Der Authentication Service unterstützt
alle [Standardkonfigurationsparameter von Keycloak](https://www.keycloak.org/server/all-config).

Zusätzlich werden folgende Umgebungsvariablen zur internen Konfiguration
verwendet:

| Name                                     | Standardwert                   | erforderlich? | Beschreibung                                                                                                                                                                                                            |
|------------------------------------------|--------------------------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `GENESIS_HASH`                           | generiert                      | nein          | Wird für die Berechnung des ersten Hashes im Admin Event Log verwendet. Eine zufällige Zeichenketten bis zu 64 Zeichen Länge.                                                                                           |
| `NONCE_TTL`                              | PT1H (1 Stunde)                | nein          | Wird für die Berechnung der Lebensdauer eines vom PDP erzeugten [`nonce`](https://de.wikipedia.org/wiki/Nonce) verwendet. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden. |
| `SERVICE_DOCUMENTATION_URL`              | https://gemspec.gematik.de/... | nein          | URL der Service-Dokumentation, diese wird vom "Well-known"-Endpunkt im Feld `service_documentation` ausgegeben.                                                                                                         |
| `SMCB_USER_MAX_CLIENTS`                  | 256                            | nein          | Maximal erlaubte Anzahl der Clients pro SMC-B-User (pro Telematik-ID)                                                                                                                                                   |
| `SMCB_KEYSTORE_LOCATION`                 |                                | ja            | Absoluter Pfad des zur Validierung der Zertifikate verwendenden Keystore (mount point)                                                                                                                                  |
| `SMCB_KEYSTORE_PASSWORD`                 |                                | ja            | Passwort für den zur Validierung verwendeten Keystore                                                                                                                                                                   |
| `CLIENT_REGISTRATION_TTL`                | PT5M (5 Minuten)               | nein          | Lebensdauer eines registrierten Client im Status "pending", bevor er wieder gelöscht wird. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                |
| `CLIENT_REGISTRATION_SCHEDULER_INTERVAL` | PT2M (2 Minuten)               | nein          | Prüfungsinterval für das Abräumen nicht benutzter Client-Registrierungen. Der Wert muss im [ISO-8601](https://de.wikipedia.org/wiki/ISO_8601)-Format angegbenen werden.                                                 |

