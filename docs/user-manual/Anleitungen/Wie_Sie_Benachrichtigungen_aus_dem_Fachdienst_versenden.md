# Wie Sie Benachrichtigungen aus dem Fachdienst versenden

Diese Anleitung beschreibt, wie ein Fachdienst (Resource Server) über die
RS-seitige API des Notification Service Push-Benachrichtigungen an die Geräte
eines Nutzers versendet. Der Notification Service ist die Push-Fassade vor dem
gematik Push Gateway: Der Fachdienst übergibt eine Benachrichtigung für einen
Nutzer und einen Kanal; der Notification Service ermittelt die registrierten
Geräte, bestätigt die Annahme sofort und leitet die Benachrichtigung asynchron
an das Push Gateway weiter.

> [!WARNING]
> Der Notification Service ist Teil der ZETA-Stufe 2 und derzeit ein
> **Vorschau-Feature**. API und Abläufe können sich noch ändern.

---

Status: Entwurf (Vorschau-Feature)

Zielgruppe: Fachdienst-Hersteller

---

## Inhaltsverzeichnis

- [Voraussetzungen](#voraussetzungen)
- [Kanäle eines Nutzers abfragen](#kanäle-eines-nutzers-abfragen)
- [Benachrichtigung senden](#benachrichtigung-senden)
- [Fehlerbehandlung](#fehlerbehandlung)
- [Test-Umgebung](#test-umgebung)
- [Aktueller Stand und Einschränkungen](#aktueller-stand-und-einschränkungen)

## Voraussetzungen

- **Notification Service aktiviert:** Der Betreiber muss den mitgelieferten
  Notification Service im ZETA-Guard-Deployment einschalten
  (`notificationService.enabled: true` im Helm Chart) und konfigurieren. Details
  siehe [Konfiguration des Notification Service](../Referenzen/Konfiguration_des_Notification_Service.md).
- **mTLS-Zugang zum RS-Deployment:** Die RS-seitige API wird als eigenes
  Deployment mit dem Image-Suffix `-rs` betrieben (getrennt vom FdV-seitigen
  `-fdv`-Deployment für die Client-SDKs). Alle Aufrufe werden über einen
  technischen Nutzer mit **mutual TLS (mTLS)** authentifiziert; die API selbst
  führt keine Token-Prüfung durch. Client- und Server-Zertifikate werden von den
  jeweiligen Betreibern ausgestellt und verwaltet.
- **Erlaubte Kanäle konfiguriert:** Die Kanal-Registry ist statisch und wird per
  Konfiguration gesetzt (`notification.channels.allowed`). Ohne mindestens einen
  erlaubten Kanal startet der Dienst nicht. Ebenso muss die Allow-Liste der
  Push-Gateway-URLs (`push-gateway.allowed-base-urls`) gesetzt sein.

Die normative Schnittstellenbeschreibung ist die OpenAPI-Spezifikation
`notification_service_rs_endpoint.yaml` im Repository des Notification Service
(Standard-Basispfad: `/notification-service/v1`).

## Kanäle eines Nutzers abfragen

`GET /users/{userId}/channels` liefert die Kanäle eines Nutzers mit ihrem
aggregierten Status. Der Nutzer wird über den Pfadparameter `userId` und den
**verpflichtenden** Query-Parameter `id_type` identifiziert:

| Parameter          | Ort   | Pflicht | Beschreibung                                                        |
|--------------------|-------|---------|---------------------------------------------------------------------|
| `userId`           | Pfad  | ja      | Identifikator des Nutzers (KVNR oder Telematik-ID)                  |
| `id_type`          | Query | ja      | `kvnr` oder `telematik-id`                                          |
| `include_inactive` | Query | nein    | `true`: alle bekannten Kanäle; `false` (Default): nur Status `enabled` |

Die Kanal-Konfiguration ist **gerätegebunden** (pro `pushkey`); die Antwort
aggregiert über alle Geräte des Nutzers: Ein Kanal gilt als `enabled`, wenn er
auf mindestens einem registrierten Gerät aktiviert ist.

**404-Semantik:** Ein Nutzer ist dem Notification Service nur bekannt, wenn er
mindestens ein registriertes Gerät (Pusher) hat. Ein Identifikator ohne
registriertes Gerät wird als unbekannt behandelt (`404`, `USER_NOT_FOUND`) —
nicht als bekannter Nutzer ohne Geräte. In einer `200`-Antwort ist
`has_registered_devices` daher immer `true` und `registered_device_count ≥ 1`.

```bash
curl --cert fachdienst.crt --key fachdienst.key \
  "https://<notification-service>/notification-service/v1/users/X110411675/channels?id_type=kvnr"
```

Beispielantwort:

```json
{
  "user": { "id_type": "kvnr", "value": "X110411675" },
  "has_registered_devices": true,
  "registered_device_count": 2,
  "channels": [
    { "id": "epa.documents.new", "status": "enabled" }
  ]
}
```

## Benachrichtigung senden

`POST /notifications` übermittelt eine Benachrichtigung für einen Kanal eines
Nutzers. Die Verarbeitung ist **strikt asynchron**: Eine erfolgreiche Annahme
(`202 Accepted`) bestätigt nur die Annahme zur Verarbeitung, nicht die
Zustellung an das Gerät.

Felder des Request-Bodys:

| Feld        | Pflicht | Beschreibung                                                                                     |
|-------------|---------|---------------------------------------------------------------------------------------------------|
| `user`      | ja      | `{ "id_type": "kvnr" \| "telematik-id", "value": "…" }`                                          |
| `channel`   | ja      | Ziel-Kanal, z. B. `epa.documents.new`                                                            |
| `payload`   | ja      | Use-case-spezifisches JSON-Objekt; das Schema legt die Spezifikation des Fachdienstes fest       |
| `prio`      | nein    | `high` oder `normal` (Default: `normal`)                                                         |
| `reference` | nein    | Fachdienst-seitige Referenz (max. 128 Zeichen), **darf keine personenbezogenen Daten enthalten** |

Die `reference` wird als unverschlüsseltes `identifier`-Property an das Push
Gateway weitergegeben und verlässt damit den verschlüsselten Kanal — daher
keine KVNR, keine Namen, keine Nachrichteninhalte. Der Request darf keine
Verschlüsselungsanweisungen enthalten; ob die Payload verschlüsselt wird,
bestimmt allein die Konfiguration der Notification-Service-Instanz. Bei
verschlüsselter Zustellung gilt zusätzlich die Vorgabe des
gem-push-notifications-Konzepts von exakt 1024 Bytes Klartextblock — die
serialisierte Payload muss dann in dieses Limit passen.

**Idempotency-Key:** Für sichere Wiederholungen (z. B. nach einem Timeout)
sollte der Fachdienst den Header `Idempotency-Key` senden (A_29992): ein
opaker, eindeutiger Schlüssel (1–64 Zeichen, UUID empfohlen), gebunden an die
mTLS-Identität des Aufrufers. Eine wiederholte Einreichung mit demselben
Schlüssel innerhalb der Aufbewahrungsfrist der Verarbeitungsdaten (A_29988)
liefert dieselbe `notification_id` und denselben Status zurück, **ohne erneut
zu versenden**. Das Feld `reference` ist dafür ungeeignet, da es nicht
eindeutig sein muss.

```bash
curl --cert fachdienst.crt --key fachdienst.key \
  -X POST "https://<notification-service>/notification-service/v1/notifications" \
  -H "Content-Type: application/json" \
  -H "Idempotency-Key: 9b5f3f2e-4c2a-4d3b-9c1e-6a0f1b2c3d4e" \
  -d '{
        "user": { "id_type": "kvnr", "value": "X110411675" },
        "channel": "epa.documents.new",
        "prio": "high",
        "payload": { "trigger_id": "abc", "message": "Neues Dokument verfügbar" },
        "reference": "evt-2026-0001"
      }'
```

Die `202`-Antwort enthält `notification_id`, `status`, `channel` und
`accepted_at`. Mögliche Status-Werte:

| Status              | Bedeutung                                                                             |
|---------------------|----------------------------------------------------------------------------------------|
| `accepted`          | Angenommen, Validierung läuft bzw. steht aus                                          |
| `queued`            | Zur Weiterleitung an das Push Gateway eingereiht                                      |
| `no_active_channel` | Terminal: Der Kanal ist auf keinem Gerät des Nutzers aktiv; es erfolgt kein Versand   |

Die Vorbedingung „Kanal aktiv" wird synchron geprüft: Ist der Kanal auf keinem
registrierten Gerät `enabled`, trägt bereits die `202`-Antwort den terminalen
Status `no_active_channel`. Wer solche Einreichungen vermeiden will, fragt
vorab `GET /users/{userId}/channels` ab. Das endgültige Zustellergebnis wird
über diese Schnittstelle **nicht** zurückgemeldet.

## Fehlerbehandlung

Alle Fehler haben die Form `{"errorCode": "…", "errorDetail": "…"}`.

| Status | errorCode (Beispiel)  | Bedeutung                                                                                   |
|--------|-----------------------|------------------------------------------------------------------------------------------------|
| 400    | `INVALID_PARAM`       | Ungültiger Request (z. B. fehlendes `id_type`)                                              |
| 401    | `UNAUTHENTICATED`     | Fehlendes oder ungültiges mTLS-Client-Zertifikat                                            |
| 403    | `FORBIDDEN`           | Technischer Nutzer für diese Operation nicht berechtigt                                     |
| 404    | `USER_NOT_FOUND`      | Kein Nutzer mit registriertem Gerät für den Identifikator bekannt                          |
| 413    | `PAYLOAD_TOO_LARGE`   | Payload überschreitet die Maximalgröße; Implementierungen müssen mindestens 3 KB unterstützen |
| 422    | `UNKNOWN_CHANNEL`     | Syntaktisch gültig, aber nicht verarbeitbar (z. B. Kanal für den Nutzer unbekannt)          |
| 429    | `RATE_LIMITED`        | Rate Limit erreicht; `Retry-After`-Header beachten                                          |
| 500    | `INTERNAL_ERROR`      | Interner Fehler des Notification Service                                                    |
| 503    | `SERVICE_UNAVAILABLE` | Temporär nicht verfügbar (z. B. Dispatch-Queue voll); `Retry-After`-Header beachten         |

## Test-Umgebung

Für lokale Tests ohne echtes Push Gateway bringt das Repository des
Notification Service einen Docker-Compose-Stack mit: Dienst (JVM-Image),
PostgreSQL 17 und ein **WireMock-Container als Push-Gateway-Stub**. Die
Stub-Mappings liegen unter `local-dev/push-gateway/mappings/`
(`notify-batch.json`, `notify-encrypted-batch.json`).

```bash
./gradlew build
docker compose up --build
```

Der Dienst läuft dann auf `http://localhost:8080`, die Admin-API des
WireMock-Stubs auf `http://localhost:8081/__admin/requests` (dort lassen sich
die eingegangenen Push-Gateway-Aufrufe inspizieren). Die `data.url` eines
Pushers muss exakt der erlaubten Basis-URL entsprechen, inklusive
abschließendem Schrägstrich: `http://push-gateway:8080/push/v1/`.

Das Skript `local-dev/e2e-demo.sh` spielt die Abnahmekriterien Ende-zu-Ende
durch (Kanal-Aggregation, asynchrone `202`, Idempotenz, Retry-Verhalten,
Fehler-Mapping) und gibt eine Zusammenfassung aus.

Für Tests im Cluster lässt sich der Notification Service im lokalen
KIND-Setup über das Helm Chart aktivieren (`notificationService.enabled`),
siehe [Wie Sie den Cluster lokal mit KIND aufsetzen](Wie_Sie_den_Cluster_lokal_mit_KIND_aufsetzen.md)
und [Konfiguration des Notification Service](../Referenzen/Konfiguration_des_Notification_Service.md).

## Aktueller Stand und Einschränkungen

- **Die Dispatch-Queue ist prozesslokal:** Angenommene, aber noch nicht
  zugestellte Benachrichtigungen gehen beim Stopp der Instanz verloren; die
  Queue wird nicht zwischen Instanzen geteilt. Eine volle Queue führt zu `503`.
- **Storage Sealing ist nicht implementiert** — eingelieferte Daten liegen
  bis auf DB-Ebene unverschlüsselt vor (siehe
  [Warnung in der Konfigurationsreferenz](../Referenzen/Konfiguration_des_Notification_Service.md#umgebungsvariablen-des-dienstes)).
- **`reference` wird auf dem unverschlüsselten Versandpfad derzeit persistiert,
  aber nicht an das Push Gateway weitergegeben.**
- Die **Nachrichten-Historie** (`/history/*`) ist ein Feature der FdV-seitigen
  Schnittstelle, standardmäßig deaktiviert (`notification.history.enabled:
  false`) und nicht Teil dieser RS-API.
- Die Kanal-Registry ist statisch (Konfiguration); es gibt keine Admin-API zur
  Laufzeit.
