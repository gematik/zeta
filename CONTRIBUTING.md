# Contributing to ZETA

Vielen Dank für dein Interesse, zum **Zero Trust Access (ZETA)**-Projekt beizutragen!
Dieses Dokument beschreibt, wie du Issues melden, Änderungen vorschlagen und Pull Requests einreichen kannst.

---

## Inhaltsverzeichnis

- [Inhaltsverzeichnis](#inhaltsverzeichnis)
- [Verhaltenskodex](#verhaltenskodex)
- [Jira-Pflicht für Issues und Pull Requests](#jira-pflicht-für-issues-und-pull-requests)
  - [Warum?](#warum)
  - [So geht's](#so-gehts)
  - [Namenskonvention](#namenskonvention)
  - [Beispiel](#beispiel)
- [Issues melden](#issues-melden)
- [Pull Requests einreichen](#pull-requests-einreichen)
  - [PR-Checkliste](#pr-checkliste)
- [Branch-Konventionen](#branch-konventionen)
- [Commit-Konventionen](#commit-konventionen)
- [Code-Qualität](#code-qualität)
- [Sicherheitslücken melden](#sicherheitslücken-melden)
- [Lizenz](#lizenz)

---

## Verhaltenskodex

Wir erwarten von allen Mitwirkenden einen respektvollen und konstruktiven Umgang miteinander.
Bitte halte dich an die gängigen Open-Source-Etikette-Standards.

---

## Jira-Pflicht für Issues und Pull Requests

> **⚠️ Pflichtanforderung:** Für jedes GitHub Issue und jeden Pull Request **muss** ein zugehöriges Jira-Ticket im Projekt **ANFTI2** existieren.

### Warum?

Die interne Nachverfolgung, Planung und Priorisierung aller Arbeiten am ZETA-Projekt erfolgt über das Jira-Projekt **ANFTI2**. GitHub Issues und PRs ohne Jira-Referenz können nicht in den regulären Review- und Merge-Prozess aufgenommen werden.

### So geht's

1. **Erstelle zuerst ein Jira-Ticket** im Projekt `ANFTI2` (falls noch keines existiert).
2. **Notiere die Ticket-ID** (z. B. `ANFTI2-123`).
3. **Füge die Ticket-Referenz** in deinem GitHub Issue bzw. PR ein – sowohl im Titel als auch in der Beschreibung.

### Namenskonvention

| Artefakt           | Format                                         |
| ------------------ | ---------------------------------------------- |
| GitHub Issue Titel | `[ANFTI2-123] Kurze Beschreibung des Problems` |
| Pull Request Titel | `[ANFTI2-123] Kurze Beschreibung der Änderung` |
| Branch-Name        | `feature/ANFTI2-123-kurze-beschreibung`        |

### Beispiel

```
Titel:       [ANFTI2-456] PEP: Authentifizierungs-Header wird bei Redirect nicht weitergeleitet
Beschreibung:
  Jira: https://jira.gematik.de/browse/ANFTI2-456

  ## Problem
  ...
```

Issues oder PRs **ohne gültige ANFTI2-Ticket-Referenz** werden kommentiert und bis zur Nachlieferung der Referenz nicht weiterbearbeitet.

---

## Issues melden

Bevor du ein neues Issue öffnest:

- Durchsuche die [offenen Issues](https://github.com/gematik/zeta/issues), ob das Problem bereits gemeldet wurde.
- Stelle sicher, dass ein **ANFTI2-Jira-Ticket** für dein Anliegen vorhanden ist (siehe [Jira-Pflicht](#jira-pflicht-für-issues-und-pull-requests)).

Ein gutes Issue enthält:

- **Titel:** `[ANFTI2-XXX] Prägnante Beschreibung`
- **Jira-Link** in der Beschreibung
- Eine klare Schilderung des Problems oder Feature-Wunsches
- Schritte zur Reproduktion (bei Bugs)
- Erwartetes vs. tatsächliches Verhalten
- Relevante Umgebungsinformationen (Kubernetes-Version, Cloud-Provider, Konfiguration usw.)

---

## Pull Requests einreichen

1. **Forke** das Repository und erstelle einen neuen Branch (siehe [Branch-Konventionen](#branch-konventionen)).
2. Stelle sicher, dass das zugehörige **ANFTI2-Jira-Ticket** existiert.
3. Implementiere deine Änderungen und stelle sicher, dass alle Tests erfolgreich durchlaufen.
4. Öffne einen Pull Request gegen den `main`-Branch.
5. Fülle die PR-Beschreibung vollständig aus:
   - Jira-Ticket-Referenz (Pflicht)
   - Beschreibung der Änderung
   - Art der Änderung (Bugfix, Feature, Refactoring, Dokumentation …)
   - Hinweise zum Testen

### PR-Checkliste

Bevor du deinen PR einreichst, vergewissere dich:

- [ ] Ein ANFTI2-Jira-Ticket ist vorhanden und im PR-Titel sowie in der Beschreibung referenziert
- [ ] Der Branch folgt der Namenskonvention
- [ ] Der Code wurde lokal getestet
- [ ] Neue oder geänderte Funktionalität ist durch Tests abgedeckt
- [ ] Die Dokumentation wurde ggf. aktualisiert
- [ ] Der Code folgt den Stilrichtlinien des Projekts
- [ ] Kein sensibles Material (Credentials, Zertifikate, interne URLs) ist im Commit enthalten

---

## Branch-Konventionen

Branches sollen nach folgendem Muster benannt werden:

```
<typ>/ANFTI2-<ticket-nr>-<kurze-beschreibung-mit-bindestrichen>
```

Gültige Typen:

| Typ        | Verwendung                                    |
| ---------- | --------------------------------------------- |
| `feature`  | Neue Funktionalität                           |
| `fix`      | Fehlerbehebung                                |
| `docs`     | Reine Dokumentationsänderungen                |
| `refactor` | Code-Umstrukturierung ohne Verhaltensänderung |
| `chore`    | Build, CI, Abhängigkeiten                     |
| `test`     | Neue oder angepasste Tests                    |

Beispiel: `feature/ANFTI2-123-pep-header-forwarding`

---

## Commit-Konventionen

Wir orientieren uns an [Conventional Commits](https://www.conventionalcommits.org/):

```
<typ>(optionaler-scope): ANFTI2-<nr> kurze Beschreibung

Optionaler längerer Erläuterungstext.
```

Beispiele:

```
feat(pep): ANFTI2-123 add mTLS header forwarding on redirect
fix(pdp): ANFTI2-456 correct OPA policy evaluation for empty claims
docs: ANFTI2-789 update deployment guide for GKE
```

---

## Code-Qualität

- **Open Policy Agent (OPA):** Rego-Policies müssen mit `opa test` getestet sein.
- **Kubernetes-Manifeste:** Manifeste sollen mit `kubeval` oder `kubeconform` validiert werden.
- **Markdown:** Alle Markdown-Dateien müssen die Regeln aus `.markdownlint.yaml` einhalten.
- **Allgemein:** Kein toter Code, keine auskommentierten Blöcke ohne Begründung.

---

## Sicherheitslücken melden

Für **kritische Sicherheitslücken** bitte **kein** öffentliches GitHub Issue öffnen.
Folge stattdessen dem Responsible-Disclosure-Prozess unter:

👉 <https://www.gematik.de/datensicherheit#c1227>

Nicht-kritische Bugs und Schwachstellen können als normales Issue gemeldet werden (mit ANFTI2-Jira-Referenz).

---

## Lizenz

Mit deinem Beitrag stimmst du zu, dass dein Code unter der
[Apache License 2.0](./LICENSE.md) veröffentlicht wird,
die für dieses Repository gilt.

---

*Dieses Dokument gilt für das Repository [gematik/zeta](https://github.com/gematik/zeta).*
*Bei Fragen wende dich an das ZETA-Team oder eröffne ein Issue.*