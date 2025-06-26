---
title: ZETA
nav_order: 1
has_children: true
---

# ZETA Dokumentation
{: .no_toc }

- TOC
{:toc}

Diese Dokumentation beschreibt die ZETA Zero Trust Access Lösung der gematik GmbH. Sie richtet sich an Entwickler, Integratoren und Administratoren, die ZETA in ihre Systeme integrieren oder verwalten möchten.

## Einführung

ZETA ist eine Zero Trust Access Lösung, die eine sichere und flexible Zugriffskontrolle für Cloud-native Anwendungen bietet. Sie basiert auf den Prinzipien des Zero Trust Modells und ermöglicht es, Identitäten, Ressourcen und Richtlinien dynamisch zu verwalten. ZETA besteht aus mehreren Komponenten, die zusammenarbeiten, um eine umfassende Sicherheitsarchitektur zu schaffen.

## ZETA API

Die ZETA API beschreibt die Abläufe und Endpunkte des ZETA Guards aus Clientsicht.

[ZETA API Dokumentation](/api/v1/index.md)

## ZETA Guard

Der ZETA Guard ist die zentrale Komponente von ZETA, die die Zugriffskontrolle auf Anwendungsebene durchsetzt. Er fungiert als Policy Enforcement Point (PEP) und Policy Decision Point (PDP) und ist verantwortlich für die Durchsetzung von Sicherheitsrichtlinien und die Entscheidung über Zugriffsanfragen.

## Branch Modell

In diesem Repository werden Branches verwendet um den Status der Weiterentwicklung und das Review von Änderungen abzubilden.

Folgende Branches werden verwendet

- *main* (enthält den letzten freigegebenen Stand der Entwicklung; besteht permanent)
- *develop* (enthält den Stand der fertig entwickelten Features und wird zum Review durch Industriepartner und Gesellschafter verwendet; basiert auf main; nach Freigabe erfolgt ein merge in main und ein Release wird erzeugt; besteht permanent)
- *feature/name* (in feature branches werden neue Features entwickelt; basiert auf develop; nach Fertigstellung erfolgt ein merge in develop; wird nach dem merge gelöscht)
- *hotfix/name* (in hotfix branches werden Hotfixes entwickelt; basiert auf main; nach Fertigstellung erfolgt ein merge in develop und in main; wird nach dem merge gelöscht)
- *concept/name* (in concept branches werden neue Konzepte entwickelt; basiert auf develop; dient der Abstimmung mit Dritten; es erfolgt kein merge; wird nach Bedarf gelöscht)
- *misc/name* (nur für internen Gebrauch der gematik; es erfolgt kein merge; wird nach Bedarf gelöscht)

## Lizenzbedingungen

Copyright (c) 2022 gematik GmbH

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
