# Wie Sie die Schlüssel der VAU-Datenbank rotieren

---

Zielgruppe: Betreiber eines ZETA-Guard in einer VAU

_Inhalt: Schritt-für-Schritt-Anleitung für den Austausch der Schlüssel, mit
denen der Spree Integrity Provider (SIP) die Keycloak-Datenbank verschlüsselt
und ihre Integrität schützt. Die Rotation läuft im laufenden Betrieb, ohne
Downtime und ohne Neuaufsetzen der Datenbank._

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Zwei Verfahren](#zwei-verfahren)
- [Voraussetzungen](#voraussetzungen)
- [Schritt 1: Neue Keychain erzeugen](#schritt-1-neue-keychain-erzeugen)
- [Schritt 2: Neue Keychain ankündigen](#schritt-2-neue-keychain-ankündigen)
- [Schritt 3: Auf die neue Keychain umstellen](#schritt-3-auf-die-neue-keychain-umstellen)
- [Schritt 4: Umschlüsselung starten](#schritt-4-umschlüsselung-starten)
- [Schritt 5: Umschlüsselung überwachen](#schritt-5-umschlüsselung-überwachen)
- [Schritt 6: Alte Keychain entfernen](#schritt-6-alte-keychain-entfernen)
- [Admin-API für die Umschlüsselung](#admin-api-für-die-umschlüsselung)
- [Fehlerbilder](#fehlerbilder)
- [Verwandte Dokumentation](#verwandte-dokumentation)

## Überblick

Das SIP verwendet zwei Schlüsselebenen:

- **Keychain (DB-Schlüssel):** enthält den AES-GCM-Schlüssel für die
  Spaltenverschlüsselung und den HMAC-Schlüssel für die Integritätsprüfsummen.
  Die Keychain liegt verschlüsselt in einer Keychain-Datei, die Sie als
  Kubernetes-Secret bereitstellen.
- **KEK (HSM-Schlüssel):** Key Encryption Key im HSM, mit dem die Keychain
  verschlüsselt ist. Jede Keychain-Datei enthält die ID ihres KEK
  (`SPREE_KEYCHAIN_KEK_ID`).

Eine Rotation tauscht immer die Keychain aus. Rotieren Sie am besten den
HSM-Schlüssel im selben Durchgang mit, indem Sie die neue Keychain immer mit
einem frischen KEK erstellen. Den KEK allein können Sie nicht austauschen: Ein
neuer KEK erfordert immer eine neue Keychain und damit eine Rotation.

Die Schlüssel dürfen im VAU-Kontext nur für eine begrenzte Zeit verwendet
werden. Die genaue Dauer ergibt sich aus den Produkttyp-Anforderungen,
z. B. höchstens drei Monate.
Planen Sie die Rotation deshalb als wiederkehrenden Betriebsprozess ein.

Bei der Rotation verschlüsselt das SIP alle verschlüsselten Datenbankspalten neu
und berechnet alle Integritätsprüfsummen neu („Umschlüsselung“ oder „Crypto
Update“). Damit das ohne Unterbrechung im Rolling Update gelingt, kennt das SIP
bis zu drei Keychains gleichzeitig:

| Rolle        | Helm-Value                                  | Bedeutung                                                                                                     |
|--------------|---------------------------------------------|---------------------------------------------------------------------------------------------------------------|
| **current**  | `authserver.dbEnc.keychainFileName`         | Aktive Keychain. Mit ihr werden alle Daten geschrieben.                                                       |
| **future**   | `authserver.dbEnc.futureKeychainFileName`   | Angekündigte Keychain. Pods können damit verschlüsselte Daten bereits lesen, schreiben aber noch nicht damit. |
| **previous** | `authserver.dbEnc.previousKeychainFileName` | Abgelöste Keychain. Pods können damit verschlüsselte Daten noch lesen, bis die Umschlüsselung fertig ist.     |

Ein Pod, für den eine future-Keychain konfiguriert ist, beteiligt sich nicht an
der Umschlüsselung. Darauf beruht die Reihenfolge der Schritte: Erst wenn alle
Pods mit der neuen Keychain schreiben, beginnt die Umschlüsselung. Sonst könnte
ein Pod mit alter Konfiguration bereits umgeschlüsselte Daten wieder mit der
alten Keychain überschreiben. Wird die alte Keychain danach entfernt, sind diese
Daten nicht mehr lesbar.

## Zwei Verfahren

Die Umschlüsselung lässt sich auf zwei Arten starten. Wählen Sie das Verfahren,
das zu Ihrem Produkttyp und Ihrer Betriebsumgebung passt:

|                          | Verfahren A: automatisch              | Verfahren B: über die Admin-API                                 |
|--------------------------|---------------------------------------|-----------------------------------------------------------------|
| Start der Umschlüsselung | durch eine Konfigurationsänderung     | durch einen Aufruf der Admin-API                                |
| Helm-Upgrades            | vier                                  | drei                                                            |
| Zugriff auf Admin-API    | nicht erforderlich                    | erforderlich                                                    |
| Einstellung              | `automaticCryptoUpdatesEnabled: true` | `automaticCryptoUpdatesEnabled: false` (Standard im Helm-Chart) |

Verfahren A kommt ohne Zugriff auf die Verarbeitungsumgebung aus, braucht dafür
aber ein Helm-Upgrade mehr. Verfahren B setzt voraus, dass Sie die Admin-API des
Authservers erreichen dürfen, siehe
[Admin-API für die Umschlüsselung](#admin-api-für-die-umschlüsselung).

Keychain-Belegung in Verfahren A:

| Keychain       | Schritt 2: ankündigen | Schritt 3: umstellen | Schritt 4: Umschlüsselung | Schritt 6: aufräumen |
|----------------|-----------------------|----------------------|---------------------------|----------------------|
| current        | alt                   | neu                  | neu                       | neu                  |
| future         | neu                   | neu                  | –                         | –                    |
| previous       | –                     | alt                  | alt                       | –                    |
| Umschlüsselung | –                     | –                    | startet von selbst        | –                    |

Keychain-Belegung in Verfahren B:

| Keychain       | Schritt 2: ankündigen | Schritt 3: umstellen | Schritt 4: Umschlüsselung | Schritt 6: aufräumen |
|----------------|-----------------------|----------------------|---------------------------|----------------------|
| current        | alt                   | neu                  | neu (unverändert)         | neu                  |
| future         | neu                   | –                    | –                         | –                    |
| previous       | –                     | alt                  | alt (unverändert)         | –                    |
| Umschlüsselung | –                     | –                    | Start per Admin-API       | –                    |

Die Schritte 2 und 3 verursachen keine Last auf der Datenbank. Sie können sie
deshalb mit Abstand zur Umschlüsselung ausführen, z. B. am Vortag. Erst die
Umschlüsselung in Schritt 4 belastet die Systeme spürbar; legen Sie sie in
Nebenzeiten.

## Voraussetzungen

- ZETA-Guard ab Version 2.0.0 mit aktiviertem SIP
  (`authserver.dbEnc.enabled: true`), eingerichtet wie in
  [Wie Sie ZETA-Guard in Kubernetes konfigurieren, Abschnitt 10](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#10-besonderheiten-vau-und-keycloak-datenbank)
  beschrieben.
- Ein neuer KEK im HSM, falls Sie den HSM-Schlüssel mitrotieren. Wie Sie
  Schlüssel im HSM anlegen, hängt von Ihrem HSM ab.
- Netzwerkzugriff auf den HSM-Proxy für den Keychain-Generator.
- Für Verfahren B: Zugriff auf die Admin-API des Authservers.
- Ein aktuelles Datenbank-Backup.

In den folgenden Beispielen heißt das Secret `zeta-authserver-dbenc`. Die
bisherige Keychain liegt darin unter dem Key `keychainFile`, eingehängt als
`/keychainData/keychain`. Die neue Keychain bekommt einen eigenen Key mit
Datumsbezug, hier `keychainFile-2026-10`. Verwenden Sie für jede Keychain einen
eigenen, unveränderlichen Key. Überschreiben Sie keinen bestehenden Key: Sonst
können Pods, die während des Rolling Updates neu starten, eine Keychain unter
falscher Rolle laden.

**Belassen Sie `authserver.hsm.dbEnc.keyId` bis zu Schritt 6 auf dem bisherigen
KEK.** Keychain-Dateien, die mit einem Keychain-Generator vor Version 2.0.8
erzeugt wurden, enthalten keine KEK-ID. Für sie greift das SIP auf diesen Wert
zurück. Ob Ihre bisherige Datei eine KEK-ID enthält, sehen Sie an einer Zeile
`SPREE_KEYCHAIN_KEK_ID=…` in der Datei.

## Schritt 1: Neue Keychain erzeugen

Erzeugen Sie die neue Keychain-Datei mit dem Keychain-Generator ab Version
2.0.8. Der Generator benötigt Zugriff auf den HSM-Proxy und die ID des KEK, mit
dem er die Keychain verschlüsselt:

```bash
mkdir keychain-out
docker run --rm \
  -e HSM_PROXY_ENDPOINT=<hsm-proxy>:50051 \
  -e HSM_PROXY_KEK_ID=<neue-KEK-ID> \
  -e SPREE_KEYCHAIN_FILE=/opt/keychain-generator/data/keychain \
  -v "$PWD/keychain-out:/opt/keychain-generator/data" \
  <registry>/keychain-generator:<version>
```

Das Ausgabeverzeichnis muss für den Container-Nutzer beschreibbar sein. Eine
bestehende Datei überschreibt der Generator nicht.

Die erzeugte Datei `keychain-out/keychain` sieht so aus:

```
# ID: 0b9f6c1e-…
SPREE_KEYCHAIN_DATA="…"
SPREE_KEYCHAIN_KEY="…"
SPREE_KEYCHAIN_KEK_ID="<neue-KEK-ID>"
```

Die Kommentarzeile nennt die Keychain-ID. Notieren Sie sie: Das SIP
protokolliert diese ID, wenn es die Umschlüsselung startet. Die Datei selbst
enthält kein Schlüsselmaterial im Klartext. Verwenden kann sie nur, wer Zugriff
auf den KEK im HSM hat.

Fügen Sie die Datei dem bestehenden Secret als neuen Key hinzu. Die bisherigen
Keys bleiben dabei erhalten:

```bash
kubectl patch secret zeta-authserver-dbenc -n <namespace> --type merge \
  -p "{\"data\":{\"keychainFile-2026-10\":\"$(base64 < keychain-out/keychain | tr -d '\n')\"}}"
```

## Schritt 2: Neue Keychain ankündigen

Dieser Schritt ist für beide Verfahren gleich. Hängen Sie die neue Keychain ein
und tragen Sie sie als **future** ein:

```yaml
authserver:
  dbEnc:
    keychainFileName: "/keychainData/keychain"
    futureKeychainFileName: "/keychainData/keychain-2026-10"
  extraVolumes:
    - name: spree-keychain
      secret:
        secretName: "zeta-authserver-dbenc"
        items:
          - key: keychainFile
            path: keychain
          - key: keychainFile-2026-10
            path: keychain-2026-10
```

```bash
helm upgrade zeta-guard … -f values.yaml -n <namespace>
kubectl rollout status deployment/authserver -n <namespace>
```

Warten Sie, bis das Rolling Update abgeschlossen ist. Danach kennen alle Pods die
neue Keychain und können damit geschriebene Daten lesen. Die Datenbank ändert
sich in diesem Schritt nicht.

## Schritt 3: Auf die neue Keychain umstellen

Machen Sie die neue Keychain zur **current** und die bisherige zur
**previous**. Ab diesem Schritt schreiben die Pods alle Daten mit der neuen
Keychain. Pods, die das Rolling Update noch nicht erreicht hat, schreiben bis
dahin mit der alten Keychain weiter. Beide Seiten können die Daten der jeweils
anderen lesen.

**Verfahren A:** Lassen Sie die neue Keychain zusätzlich als **future**
stehen, sie ist also zweimal eingetragen. Dadurch beginnt die Umschlüsselung
noch nicht, solange das Rolling Update läuft:

```yaml
authserver:
  dbEnc:
    automaticCryptoUpdatesEnabled: true
    futureKeychainFileName: "/keychainData/keychain-2026-10"
    keychainFileName: "/keychainData/keychain-2026-10"
    previousKeychainFileName: "/keychainData/keychain"
```

**Verfahren B:** `futureKeychainFileName` entfällt. Die Umschlüsselung startet
nicht von selbst, weil `automaticCryptoUpdatesEnabled` ausgeschaltet ist:

```yaml
authserver:
  dbEnc:
    automaticCryptoUpdatesEnabled: false
    keychainFileName: "/keychainData/keychain-2026-10"
    previousKeychainFileName: "/keychainData/keychain"
```

In beiden Fällen:

```bash
helm upgrade zeta-guard … -f values.yaml -n <namespace>
kubectl rollout status deployment/authserver -n <namespace>
```

Warten Sie, bis das Rolling Update abgeschlossen ist. Erst dann schreiben alle
Pods mit der neuen Keychain.

## Schritt 4: Umschlüsselung starten

Die Umschlüsselung belastet Datenbank und Authserver deutlich. Führen Sie
diesen Schritt in Nebenzeiten aus. Bei einer nahezu leeren Datenbank dauert die
Umschlüsselung etwa 20 Minuten; je nach Datenvolumen kann sie mehrere Stunden
dauern. Der Authserver bleibt währenddessen verfügbar.

**Verfahren A:** Entfernen Sie `futureKeychainFileName`:

```yaml
authserver:
  dbEnc:
    automaticCryptoUpdatesEnabled: true
    keychainFileName: "/keychainData/keychain-2026-10"
    previousKeychainFileName: "/keychainData/keychain"
```

```bash
helm upgrade zeta-guard … -f values.yaml -n <namespace>
kubectl rollout status deployment/authserver -n <namespace>
```

Der erste Pod mit dieser Konfiguration erkennt den Keychain-Wechsel und startet
die Umschlüsselung. Das geschieht beim Start des periodischen
Integritätsscanners, standardmäßig etwa fünf Minuten nach dem Pod-Start. Weitere
Pods übernehmen offene Aufgaben, sobald sie ebenfalls ohne future-Keychain
laufen. Im Log erscheint:

```
🛠️️ Key change detected, initiating crypto update to keychain ID »<neue Keychain-ID>«
```

**Verfahren B:** Starten Sie die Umschlüsselung über die Admin-API, siehe
[Admin-API für die Umschlüsselung](#admin-api-für-die-umschlüsselung):

```bash
curl -s -X POST -H "Authorization: Bearer $TOKEN" \
  https://<admin-hostname>/auth/admin/realms/zeta-guard/crypto-update
```

Die Pods teilen die anstehenden Aufgaben untereinander auf. Jeder Pod übernimmt
pro Scan-Zyklus eine Tabelle. Eine Tabelle gilt erst dann als fertig, wenn ein
vollständiger Durchlauf keine Zeile mehr ändert.

## Schritt 5: Umschlüsselung überwachen

Für jede Tabelle protokolliert das SIP Beginn und Ergebnis:

```
🛠️ Crypto update starts for »<Entität>« ...
☑️ Crypto update for »<Entität>« changed <n> row checksums
```

Die Umschlüsselung ist abgeschlossen, wenn alle Pods wieder zur regulären
Integritätsprüfung übergegangen sind. Das erkennen Sie an Log-Einträgen wie:

```
🔎 Scanning »<Entität>« for integrity...
```

Haben Sie Zugriff auf die Admin-API, können Sie den Fortschritt auch direkt
abfragen. `GET …/crypto-update` liefert die Zahl der offenen Aufgaben, eine pro
Tabelle. Bei `0` ist die Umschlüsselung abgeschlossen:

```bash
curl -s -H "Authorization: Bearer $TOKEN" \
  https://<admin-hostname>/auth/admin/realms/zeta-guard/crypto-update
```

## Schritt 6: Alte Keychain entfernen

**Entfernen Sie die previous-Keychain erst, wenn die Umschlüsselung
abgeschlossen ist.** Sonst bleiben Daten zurück, die kein Pod mehr lesen kann.

Das Entfernen ist grundsätzlich optional. Es erhöht aber die Sicherheit: Danach
kann die alte Keychain nicht mehr verwendet werden, und jeder Versuch fällt
sofort als Fehler auf. **War der Anlass der Rotation eine (vermutete)
Kompromittierung der alten Keychain, ist das Entfernen zwingend.**

Entfernen Sie die previous-Keychain aus der Konfiguration und stellen Sie
`authserver.hsm.dbEnc.keyId` auf den neuen KEK um:

```yaml
authserver:
  dbEnc:
    keychainFileName: "/keychainData/keychain-2026-10"
  extraVolumes:
    - name: spree-keychain
      secret:
        secretName: "zeta-authserver-dbenc"
        items:
          - key: keychainFile-2026-10
            path: keychain-2026-10
  hsm:
    dbEnc:
      keyId: "<neue-KEK-ID>"
```

```bash
helm upgrade zeta-guard … -f values.yaml -n <namespace>
kubectl rollout status deployment/authserver -n <namespace>
```

Den alten Key `keychainFile` können Sie anschließend aus dem Secret entfernen.

> **Backups:** Datenbank-Backups von vor der Rotation sind mit der alten
> Keychain verschlüsselt. Bewahren Sie die alte Keychain-Datei auf und
> deaktivieren Sie den alten KEK im HSM erst, wenn kein solches Backup mehr
> wiederhergestellt werden muss. Für die Wiederherstellung eines alten Backups
> konfigurieren Sie die alte Keychain als previous, wie in Schritt 4.

## Admin-API für die Umschlüsselung

Über die Admin-API starten, überwachen und steuern Sie die Umschlüsselung:

| Methode  | Pfad                                                    | Wirkung                                                                                                 |
|----------|---------------------------------------------------------|---------------------------------------------------------------------------------------------------------|
| `POST`   | `/auth/admin/realms/zeta-guard/crypto-update`           | Umschlüsselung aller verschlüsselten Tabellen einplanen                                                 |
| `POST`   | `/auth/admin/realms/zeta-guard/crypto-update/{Entität}` | Umschlüsselung einer einzelnen Tabelle einplanen; `{Entität}` ist der vollqualifizierte JPA-Klassenname |
| `GET`    | `/auth/admin/realms/zeta-guard/crypto-update`           | Anzahl der offenen Aufgaben (Klartext)                                                                  |
| `DELETE` | `/auth/admin/realms/zeta-guard/crypto-update`           | Offene Aufgaben verwerfen; bereits laufende Aufgaben werden noch beendet                                |

Das Einplanen und das Verwerfen von Aufgaben werden als Admin-Events
protokolliert. Fällt ein Pod während einer Aufgabe aus, gibt das SIP die
Aufgabe nach Ablauf von `SPREE_CRYPTO_UPDATE_TIMEOUT` (Standardwert: `PT10M`)
wieder frei. Ein anderer Pod übernimmt sie dann.

Die Admin-API ist über den
[Admin-Hostnamen](../Referenzen/Referenz_des_Helm_Charts.md#admin-api-absicherung)
erreichbar. Das Admin-Token benötigt die Berechtigung `manage-realm`:

```bash
eval "$(bash terraform/authserver/scripts/kc-admin-env.sh <namespace>)"

TOKEN=$(curl -s https://<admin-hostname>/auth/realms/master/protocol/openid-connect/token \
  -d grant_type=password -d client_id=admin-cli \
  --data-urlencode "username=$TF_VAR_keycloak_username" \
  --data-urlencode "password=$TF_VAR_keycloak_password" | jq -r .access_token)
```

> **Absicherung:** Der Authserver stellt die Admin-Schnittstelle standardmäßig
> nur über HTTP bereit. Für Schnittstellen in die Verarbeitungsumgebung einer
> VAU ist das in der Regel nicht zulässig; die Schnittstelle muss dann
> zusätzlich abgesichert werden. Wie genau, legen die Anforderungen Ihres
> Produkttyps fest, z. B. A_27042. Davon hängt ab, ob Sie die
> Admin-API nutzen und Verfahren B einsetzen können.

## Fehlerbilder

| Symptom                                                              | Ursache und Abhilfe                                                                                                                                                                                                                   |
|----------------------------------------------------------------------|---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Offene Aufgaben bleiben stehen, im Log kein Fortschritt              | Mindestens ein Pod muss ohne future-Keychain laufen. Prüfen Sie, dass Schritt 4 ausgerollt ist und `futureKeychainFileName` nicht mehr gesetzt ist.                                                                                   |
| Keine Umschlüsselung nach Schritt 4                                  | Verfahren A: `automaticCryptoUpdatesEnabled` ist `false`, oder `previousKeychainFileName` fehlt. Verfahren B: Umschlüsselung über die Admin-API starten.                                                                              |
| Authserver `FATAL ... Failed to load current keychain` / `ERROR_HSM` | Keychain-Datei nicht gefunden oder der KEK im HSM passt nicht. Pfad, Secret-Key und `items` prüfen; die KEK-ID in der Datei muss im HSM existieren.                                                                                   |
| `Unresolvable Keychain ID` beim Lesen                                | Die Datenbank enthält Daten einer Keychain, die keinem Pod mehr bekannt ist. Typisch: previous-Keychain entfernt, bevor die Umschlüsselung fertig war. Alte Keychain wieder als previous eintragen und Umschlüsselung erneut starten. |

## Verwandte Dokumentation

* [Konfiguration einer VAU mit verschlüsselter Datenbank](../Referenzen/Konfiguration_VAU.md)
* [Helm-Chart-Referenz – Spree Integrity Provider (VAU)](../Referenzen/Referenz_des_Helm_Charts.md#spree-integrity-provider-vau)
* [Wie Sie ZETA-Guard in Kubernetes konfigurieren, Abschnitt 10](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#10-besonderheiten-vau-und-keycloak-datenbank)
* [Sicherheitsanforderungen an den Betreiber des ZETA-Guard – Betrieb des Authservers in einer VAU-basierten Umgebung](../SicherheitsanforderungenZETAGuardBetreiber.md#betrieb-des-authservers-in-einer-vau-basierten-umgebung)
