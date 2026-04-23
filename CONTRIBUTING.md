# Contributing to ZETA

Vielen Dank für dein Interesse, zum **Zero Trust Access (ZETA)**-Projekt beizutragen!
Dieses Dokument beschreibt, wie du Änderungen vorschlagen und Pull Requests einreichen kannst.

---

## Inhaltsverzeichnis

- [Inhaltsverzeichnis](#inhaltsverzeichnis)
- [Verhaltenskodex](#verhaltenskodex)
- [Fehler melden und Feature-Anfragen](#fehler-melden-und-feature-anfragen)
- [Jira-Pflicht für Pull Requests](#jira-pflicht-für-pull-requests)
  - [Warum?](#warum)
  - [So geht's](#so-gehts)
  - [Namenskonvention](#namenskonvention)
  - [Beispiel](#beispiel)
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

## Fehler melden und Feature-Anfragen

GitHub Issues sind in diesem Repository **deaktiviert**. Fehler, Verbesserungsvorschläge und Feature-Anfragen werden ausschließlich über das Jira-Projekt **ANFTI2** verwaltet.

👉 Bitte erstelle dein Ticket direkt unter: [`https://service.gematik.de/servicedesk/customer/portal/37/group/66`](https://service.gematik.de/servicedesk/customer/portal/37/group/66)

---

## Jira-Pflicht für Pull Requests

> **⚠️ Pflichtanforderung:** Für jeden Pull Request **muss** ein zugehöriges Jira-Ticket im Projekt **ANFTI2** existieren.

### Warum?

Die interne Nachverfolgung, Planung und Priorisierung aller Arbeiten am ZETA-Projekt erfolgt ausschließlich über das Jira-Projekt **ANFTI2**. PRs ohne Jira-Referenz können nicht in den regulären Review- und Merge-Prozess aufgenommen werden.

### So geht's

1. **Erstelle zuerst ein Jira-Ticket** im Projekt `ANFTI2` (falls noch keines existiert).
2. **Notiere die Ticket-ID** (z. B. `ANFTI2-123`).
3. **Füge die Ticket-Referenz** in deinem Pull Request ein – sowohl im Titel als auch in der Beschreibung.

### Namenskonvention

| Artefakt           | Format                                         |
| ------------------ | ---------------------------------------------- |
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

PRs **ohne gültige ANFTI2-Ticket-Referenz** werden kommentiert und bis zur Nachlieferung der Referenz nicht weiterbearbeitet.



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

Nicht-kritische Bugs und Schwachstellen bitte direkt als Jira-Ticket im Projekt **ANFTI2** erfassen.

---

## Lizenz

Mit deinem Beitrag stimmst du zu, dass dein Code unter der
[Apache License 2.0](./LICENSE.md) veröffentlicht wird,
die für dieses Repository gilt.

---

*Dieses Dokument gilt für das Repository [gematik/zeta](https://github.com/gematik/zeta) und alle zugehörigen ZETA-Repositories.*
*Bei Fragen wende dich an das ZETA-Team oder erstelle ein Ticket im Jira-Projekt [ANFTI2](https://service.gematik.de/servicedesk/customer/portal/37/group/66).*