# Wie Sie einen Ende-zu-Ende-Integrationstest ausführen

Diese Anleitung unterstützt Tester und Entwickler dabei, die
ZETA-Ende-zu-Ende-Tests auszuführen.
Die Testfälle liegen im Testsuite-Repository und lassen sich sowohl lokal als
auch in der Pipeline starten.

---

Status: Entwurf

Zielgruppe: Tester und Entwickler

---

## Überblick

Für einen schnellen End-to-End-Lauf stehen drei Wege bereit - wählen Sie die
Variante, die zu Ihrer Umgebung passt.

## Wichtige Parameter

| Variable              | Zweck                                                 | Beispiel                                  |
|-----------------------|-------------------------------------------------------|-------------------------------------------|
| `ZETA_BASE_URL`       | Ziel-Host (ohne Protokoll) für die Cloud-/Stage-Tests | `zeta-dev.example`                        |
| `TIGER_ENVIRONMENT`   | Wählt die Tiger-Konfiguration (`cloud`, `local`, ...) | `cloud`                                   |
| `CUCUMBER_TAGS`       | Filter für Szenarien                                  | `@smoke`                                  |
| `SERENITY_EXPORT_DIR` | Optionaler Report-Pfad (z. B. im CI-Workspace)        | `$CI_PROJECT_DIR/target/site/serenity`    |
| `FAILSAFE_EXPORT_DIR` | Optionaler Pfad für JUnit/Failsafe-Reports            | `$CI_PROJECT_DIR/target/failsafe-reports` |

Ohne `ZETA_BASE_URL` laufen die Tests nur gegen symbolische Hostnamen wie
`zetaClient` und schlagen erwartungsgemäß fehl.

## Option 1: Docker-Image lokal bauen und mit `@smoke` gegen Ihren Host starten

```bash
cd testsuite
docker build -t testsuite:latest .
docker run --rm \
  -e ZETA_BASE_URL="<ihr-host-ohne-protokoll>" \
  -e CUCUMBER_TAGS="@smoke" \
  -e TIGER_ENVIRONMENT=cloud \
  -v "$PWD/target/site/serenity:/app/target/site/serenity" \
  -v "$PWD/target/failsafe-reports:/app/target/failsafe-reports" \
  testsuite:latest
```

- `ZETA_BASE_URL` muss auf Ihren Ziel-Host zeigen (ohne Protokoll),
  sonst laufen die Szenarien nur gegen symbolische Namen wie `zetaClient`.
- `CUCUMBER_TAGS` wählt die Scopes; der Standard ist `@smoke`.
- Das Image bringt `/usr/local/bin/run-tests.sh` mit und führt headless
  `mvn verify` aus, die Reports landen in den gemounteten Verzeichnissen.

## Option 2: Fertiges Docker-Image direkt in der GitLab-Pipeline nutzen

Das CI-Target `docker-image` baut und published das Image
(`registry.gitlab.com/<gruppe>/testsuite:latest`).
Ein Job, der nur die Smoke-Tests fährt, sieht z. B. so aus:

```yaml
testsuite-smoke:
    image: registry.gitlab.com/<gruppe>/testsuite:latest
    script:
        - cd /app
        - /usr/local/bin/run-tests.sh
    variables:
        ZETA_BASE_URL: <ihr-host-ohne-protokoll>
        TIGER_ENVIRONMENT: cloud
        CUCUMBER_TAGS: "@smoke"
        SERENITY_EXPORT_DIR: "$CI_PROJECT_DIR/target/site/serenity"
        FAILSAFE_EXPORT_DIR: "$CI_PROJECT_DIR/target/failsafe-reports"
    artifacts:
        when: always
        reports:
            junit: target/failsafe-reports/TEST-*.xml
        paths:
            - target/site/serenity
```

- Alle Maven-Flags (headless, Offline, Tiger-Toggles) stecken bereits im
  Wrapper.
- Artefakte werden über die Export-Variablen direkt in den Pipeline-Workspace
  geschrieben.

## Option 3: Repository klonen und lokal per Maven oder IntelliJ starten (optional mit Tiger-UI)

```bash
git clone <git-url>/testsuite.git
cd testsuite
mvn verify \
  "-Dcucumber.filter.tags=@smoke" \
  "-Dzeta_base_url=<ihr-host-ohne-protokoll>" \
  -Denvironment=cloud
```

- In IntelliJ das Maven-Projekt importieren und eine Run-Configuration für
  `verify` (oder einzelne Feature-Dateien) mit denselben Properties anlegen.
- Falls Sie die Tiger Workflow UI sehen möchten, passen Sie in `tiger.yaml`
  unter `lib:` z. B. an:
    - `activateWorkflowUi: true`
    - `startBrowser: true`
    - optional `runTestsOnStart: false` und `enableTestSelection: true`,
      um Szenarien zuerst auszuwählen.
- Für CI sollten UI-Optionen wieder deaktiviert bleiben (`false`),
  damit die Läufe headless und automatisiert durchlaufen.
