# Wie Sie die ZETA-Apps mit BrowserStack testen

Diese Anleitung unterstützt Tester und Entwickler dabei, die ZETA-Client-Apps
für Android und iOS auf echten Geräten in BrowserStack zu testen.

Die Apps werden in der CI/CD-Pipeline gebaut, signiert und zu BrowserStack
App Automate hochgeladen. Anschließend startet der ZETA-Testdriver über einen
HTTP-Aufruf die zugehörigen Testszenarien.

---

Status: Entwurf

Zielgruppe: Tester und Entwickler

Stand: ZETA-SDK 2.0.0

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Voraussetzungen](#voraussetzungen)
- [Vorgehen](#vorgehen)
    - [Apps bauen und hochladen (Pipeline)](#apps-bauen-und-hochladen-pipeline)
    - [Apps manuell hochladen](#apps-manuell-hochladen)
    - [Tests ausführen](#tests-ausführen)
- [Ergebnis auswerten](#ergebnis-auswerten)

## Überblick

Der Ablauf besteht aus drei Schritten:

1. **Bauen und Signieren:** Die Pipeline baut die Release-Variante des
   ZETA-Clients als APK (Android) bzw. IPA (iOS) und signiert sie.
2. **Hochladen:** Die signierten Apps werden zu BrowserStack App Automate
   hochgeladen. Sie sind dort unter einer festen Kennung (`custom_id`)
   abrufbar:

| Plattform   | `custom_id`           | Pipeline-Variable |
|-------------|-----------------------|-------------------|
| Android     | `ZetaClientAndroid`   | `BS_APP_URL`      |
| iOS         | `ZetaClientIOS`       | `BS_IOS_APP_URL`  |

3. **Testen:** Der Testdriver führt die Feature-Dateien
   `hello_zeta_android.feature` bzw. `hello_zeta_ios.feature` gegen die
   hochgeladene App aus.

## Voraussetzungen

* Zugang zu einem BrowserStack-Konto mit App Automate.
* Berechtigung, Pipelines im SDK-Repository zu starten.
* Ein laufender ZETA-Testdriver (siehe
  [Wie Sie den ZETA-Testdriver bauen](Wie_Sie_den_Testdriver_bauen.md)).

In den CI/CD-Variablen des Repositorys müssen folgende Werte hinterlegt sein:

| Variable                         | Verwendung                                                      |
|----------------------------------|-----------------------------------------------------------------|
| `BS_USER`, `BS_KEY`              | BrowserStack-Benutzername und Access Key                        |
| `ZETA_ENV`                       | Konfigurationsdatei der App (Variablentyp *File*)               |
| `ANDROID_RELEASE_KEYSTORE_B64`   | Android-Release-Keystore (JKS, Base64-kodiert)                  |
| `ANDROID_RELEASE_KEYSTORE_PASS`  | Passwort des Keystores                                          |
| `ANDROID_RELEASE_KEY_ALIAS`      | Alias des Signaturschlüssels                                    |
| `IOS_CERT_P12_B64`               | iOS-Signaturzertifikat (P12, Base64-kodiert)                    |
| `IOS_CERT_PASSWORD`              | Passwort des Zertifikats                                        |
| `IOS_PROFILE_B64`                | Provisioning Profile (Base64-kodiert)                           |

Für den iOS-Build wird ein macOS-Runner mit dem Tag `attestation-vm-macos` benötigt.

## Vorgehen

### Apps bauen und hochladen (Pipeline)

1. Öffnen Sie im SDK-Repository **Build → Pipelines → Run pipeline**.
2. Wählen Sie den gewünschten Branch.
3. Setzen Sie den Input `browserstack`:

| Wert      | Wirkung                                  |
|-----------|------------------------------------------|
| `android` | Baut und lädt nur die Android-App hoch   |
| `ios`     | Baut und lädt nur die iOS-App hoch       |
| `all`     | Baut und lädt beide Apps hoch            |

   Ist `browserstack` gesetzt, laufen ausschließlich die BrowserStack-Jobs;
   alle übrigen Jobs der Pipeline werden übersprungen.
4. Starten Sie die Pipeline.

Die Pipeline führt folgende Jobs aus:

| Job                          | Stage         | Ergebnis                                   |
|------------------------------|---------------|--------------------------------------------|
| `browserstack-android-apk`   | `build`       | Signierte `app-browserstack.apk`           |
| `browserstack-android-upload`| `browserstack`| Upload, `BS_APP_URL`                       |
| `browserstack-ios-ipa`       | `build`       | Signierte `app-browserstack.ipa`           |
| `browserstack-ios-upload`    | `browserstack`| Upload, `BS_IOS_APP_URL`                   |

Die URL der hochgeladenen App (`bs://…`) steht im Job-Log und als
dotenv-Variable für nachfolgende Jobs zur Verfügung. Die gebauten APK/IPA
bleiben eine Woche als Job-Artefakt erhalten.

### Apps manuell hochladen

Alternativ lässt sich eine lokal gebaute und signierte App direkt hochladen:

````
curl -u "<BS_USER>:<BS_KEY>" \
  -X POST "https://api-cloud.browserstack.com/app-automate/upload" \
  -F "file=@app-browserstack.apk" \
  -F "custom_id=ZetaClientAndroid"
````

Für iOS entsprechend mit `file=@app-browserstack.ipa` und
`custom_id=ZetaClientIOS`. Die Antwort enthält die `app_url` der App.

### Tests ausführen

Der Testdriver stellt für jede Plattform einen Endpunkt bereit, der das
zugehörige Testszenario startet:

| Plattform | Endpunkt                                       | Feature-Datei                  |
|-----------|------------------------------------------------|--------------------------------|
| Android   | `GET <TEST_DRIVER_API_PATH>/hellozeta/android` | `hello_zeta_android.feature` |
| iOS       | `GET <TEST_DRIVER_API_PATH>/hellozeta/ios`     | `hello_zeta_ios.feature`     |

Beispiel:

````
curl -i http://<testdriver-host>:8080<TEST_DRIVER_API_PATH>/hellozeta/android
````

Der Aufruf blockiert, bis das Szenario beendet ist.

## Ergebnis auswerten

| HTTP-Status | Bedeutung                                   |
|-------------|---------------------------------------------|
| `200 OK`    | Alle Schritte des Szenarios erfolgreich     |
| `500`       | Mindestens ein Schritt fehlgeschlagen       |

Der Antwort-Body enthält in beiden Fällen das Ergebnis des Testlaufs.

Details zum Testlauf (Video, Geräte-Logs, Appium-Logs) finden Sie im
BrowserStack-Dashboard unter **App Automate**.
