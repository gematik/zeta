# Branch Modell

Im [ZETA GitHub Repository](https://github.com/gematik/zeta) werden Branches verwendet um den Status der Weiterentwicklung und das Review von Änderungen abzubilden.

Folgende Branches werden verwendet:

- *main* (enthält den letzten freigegebenen Stand der Entwicklung; besteht permanent)
- *develop* (enthält den Stand der fertig entwickelten Features und wird zum Review durch Industriepartner und Gesellschafter verwendet; basiert auf main; nach Freigabe erfolgt ein merge in main und ein Release wird erzeugt; besteht permanent)
- *feature/name* (in feature branches werden neue Features entwickelt; basiert auf develop; nach Fertigstellung erfolgt ein merge in develop; wird nach dem merge gelöscht)
- *hotfix/name* (in hotfix branches werden Hotfixes entwickelt; basiert auf main; nach Fertigstellung erfolgt ein merge in develop und in main; wird nach dem merge gelöscht)
- *concept/name* (in concept branches werden neue Konzepte entwickelt; basiert auf develop; dient der Abstimmung mit Dritten; es erfolgt kein merge; wird nach Bedarf gelöscht)
- *misc/name* (nur für internen Gebrauch der gematik; es erfolgt kein merge; wird nach Bedarf gelöscht)
