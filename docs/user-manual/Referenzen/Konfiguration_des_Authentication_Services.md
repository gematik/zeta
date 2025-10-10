# Konfiguration des Authentication Services

Der Authentication Service unterstützt
jede [Konfiguration von Keycloak](https://www.keycloak.org/server/all-config).
Zusätzlich werden folgende Umgebungsvariablen unterstützt:

| Name           | Standartwert | erforderlich? | Beschreibung                                                                                                                                                |
|----------------|--------------|---------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `GENESIS_HASH` | zufällig     | nein          | Wird statt dem vorhergehenden Hash für die Berechnung des ersten Hashes im Admin Event Log verwendet. Eine zufällige Zeichenketten bis zu 64 Zeichen Länge. |
