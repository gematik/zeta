# Egress-Ziele des ZETA Guard

Dieses Verzeichnis enthält eine **Beispieldatei** für das Format der
Egress-Ziel-Liste. Es ist keine Bezugsquelle.

## Warum es diese Liste gibt

Die NetworkPolicies des ZETA Guard beschränken den ausgehenden Verkehr auf
explizit freigegebene Ziele. Für einen Teil dieser Ziele — insbesondere die
OCSP-Responder der SMC-B-TSP — gibt es **keine maschinenlesbare Quelle**.

### Warum die TSL nicht die Quelle ist

Naheliegend wäre die TSL, weil sie die zugelassenen TSP verbindlich führt. Als
Quelle der OCSP-Endpunkte taugt sie jedoch nicht, aus zwei unabhängigen Gründen:

1. **Die `ServiceSupplyPoint`-Einträge zeigen ins TI-Zentralnetz** (`*.telematik`)
   oder sind Platzhalter (`ocsp00.gematik.invalid/not-used`). Ein ZETA Guard, der
   die Responder aus dem Internet erreicht, kann sie nicht verwenden.
2. **Die AIA der CA-Zertifikate zeigt eine Ebene zu hoch.** Nach RFC 5280
   §4.2.2.1 benennt `id-ad-ocsp` den Responder **für dieses Zertifikat**, nicht
   für die davon ausgestellten. Die SMC-B-CAs sind von einer `GEM.RCAx`
   ausgestellt und verweisen deshalb ausnahmslos auf
   `http://ocsp.root-ca.ti-dienste.de/ocsp` — in der PU-TSL bei allen 28 CAs
   identisch. Dieser Responder wird vom ZETA Guard nicht angesprochen.

Der Beleg für Punkt 2 liegt in diesem Repository, an einem Zertifikatspaar
derselben Kette:

| Zertifikat | Aussteller | AIA |
| --- | --- | --- |
| `ZETA PIP/PAP Freigeber` (Endnutzer) | `GEM.KOMP-CA8` | `http://download.crl.ti-dienste.de/ocsp/ec` |
| `GEM.KOMP-CA8` (CA) | `GEM.RCA7` | `http://ocsp.root-ca.ti-dienste.de/ocsp` |

Nur das Endnutzer-Zertifikat trägt die Adresse, die für seine eigene
Statusprüfung gebraucht wird. Für SMC-B gilt dasselbe.

### Was stattdessen die Quelle ist

**Die Benennung durch den TSP im Zulassungsverfahren**, verifiziert an einem
Referenz-Zertifikat. Nur so ist die Liste

- **vollständig** — auch für TSP, deren Zertifikate keine verwertbare AIA
  tragen,
- **vorlaufend** — ein neu zugelassener TSP benennt seinen Endpunkt, bevor seine
  Karten im Umlauf sind; bis dahin gibt es kein Zertifikat zum Auslesen,
- **prüfbar** — `sourceRef` hält je Endpunkt fest, aus welchem Zertifikat oder
  welcher Benennung er stammt.

Damit ergibt sich eine saubere Aufgabenteilung:

| Frage | Quelle |
| --- | --- |
| **Welche** CAs müssen abgedeckt sein? | TSL |
| **Welche URL und welcher Port** gehören dazu? | Benennung durch den TSP, verifiziert am Referenz-Zertifikat |
| **Welche IP** hat das heute? | Resolver des Betreibers, zum Deployzeitpunkt |

Die TSL behält also eine Rolle — aber nur die als Vollständigkeitsprüfung, nicht
als Adressquelle. Genau das leistet `check-egress-coverage.sh`.

## Was das Format leistet

- **Nur FQDN und Port, keine IP-Adressen.** Das Schema erzwingt das strukturell
  (`additionalProperties: false`, plus ein `not`-Muster gegen IP-förmige
  Hostnamen). IP-Adressen wären zum Deployzeitpunkt bereits potenziell falsch;
  sie entstehen erst beim Betreiber.
- **Ports immer explizit**, auch bei 80 und 443 — die SMC-B-Responder verwenden
  teils abweichende Ports (z. B. 8080).
- **Schlüssel identisch mit den Helm-Values** des Charts
  (`zeta-guard.networkPolicy.egress.<key>`), damit nichts abgetippt wird.
- **`source` je Endpunkt** macht sichtbar, ob ein Eintrag abgeleitet
  (`tsl-aia`) oder vom TSP benannt (`declared`) ist.
- **`servesCa` je Endpunkt** trägt die Aufräumregel: Ein Responder darf erst
  entfernt werden, wenn unter keiner der genannten CAs mehr gültige Karten im
  Umlauf sind. SMC-B haben mehrjährige Laufzeiten — die Liste ist die
  Vereinigungsmenge über alle CA-Generationen, nicht die aktuelle Generation.

## Bezug: signiertes OCI-Artefakt, nicht dieses Repository

Die verbindliche Liste wird als OCI-Artefakt aus der ZETA Artifact Registry
bezogen, analog zum Provisioning-Container und zu den OPA-Bundles:

- Sie steuert eine Sicherheitsgrenze und muss signiert und prüfbar sein.
  Eine unsigniert über HTTPS gezogene Liste wäre ein Einschleusvektor für
  Egress-Freigaben.
- Der Betreiber hat ohnehin Egress zur Registry (Kategorie `artifactRegistry`)
  und muss nicht zusätzlich GitHub freigeben.
- Sie ändert sich unabhängig vom Release-Zyklus der Dokumentation.

## Werkzeuge

| Skript | Zweck |
| --- | --- |
| [`scripts/ocsp-endpoints-from-certs.sh`](../../scripts/ocsp-endpoints-from-certs.sh) | Liest die AIA echter Endnutzer-Zertifikate aus und erzeugt Endpunkt-Einträge — die einzige technisch belastbare Ableitung |
| [`scripts/check-egress-coverage.sh`](../../scripts/check-egress-coverage.sh) | Prüft die Liste gegen die TSL: welche zugelassenen SMC-B-CAs haben keinen Endpunkt? |
| [`scripts/render-egress-values.sh`](../../scripts/render-egress-values.sh) | Löst FQDNs beim Betreiber auf und erzeugt die Helm-Values mit `ipBlocks` |

Die Arbeitsteilung ist bewusst so geschnitten: Die gematik liefert das **Was**
(FQDN, Port, Zweck), der Betreiber beantwortet das **Welche IP heute** — zum
Deployzeitpunkt, gegen seinen eigenen Resolver.

### Liste pflegen (gematik)

```shell
# 1. Endpunkte aus Referenz-Zertifikaten der TSP auslesen
./scripts/ocsp-endpoints-from-certs.sh referenz-zertifikate/ --key ocspSmcbTsp

# 2. Fehlende Endpunkte als 'declared' aus der Benennung des TSP ergänzen,
#    jeweils mit sourceRef

# 3. Vollständigkeit gegen die TSL prüfen - CI-Gate
./scripts/check-egress-coverage.sh targets.yaml <tsl.xml> --strict
```

Schritt 3 ist der eigentliche Wächter: Er schlägt an, sobald die TSL eine CA
führt, für die kein Endpunkt hinterlegt ist — also genau dann, wenn ein neuer
TSP zugelassen wurde oder eine CA-Generation gewechselt hat.

### Values erzeugen (Betreiber)

```shell
./scripts/render-egress-values.sh targets.yaml --format check    # Trockenlauf
./scripts/render-egress-values.sh targets.yaml > egress-values.yaml
helm upgrade --install zeta-guard ... -f egress-values.yaml

# oder direkt als --set-Argumente
helm upgrade --install zeta-guard ... \
  $(./scripts/render-egress-values.sh targets.yaml --format set)
```

Die erzeugten Values sind **verderblich**. Sie gehören in die Deploy-Pipeline
und werden bei jedem Deployment neu erzeugt. Eine eingecheckte Kopie veraltet
unbemerkt und äußert sich später als Autorisierungsfehler, nicht als
Netzwerkfehler.

## Pflegeprozess

- **Nur additiv innerhalb einer Release-Linie.** Erst hinzufügen, dann
  kommunizieren, frühestens im übernächsten Release entfernen.
- **Trigger für die Prüfung ist die TSL-Sequenznummer**, nicht ein
  Kalenderintervall. Die TSL liefert nicht die Adresse, aber sie meldet als
  Erste, dass eine neue CA abzudecken ist.
- **Die Benennung des Endpunkts gehört ins Zulassungsverfahren.** Ein TSP,
  dessen CA in der TSL erscheint, ohne dass sein OCSP-Endpunkt benannt ist,
  erzeugt eine Lücke, die erst beim ersten abgelehnten Leistungserbringer
  auffällt. Die Benennung muss der Zulassung vorausgehen, nicht folgen.
- **`metadata.expiresAt`** erzwingt den Neubezug, statt auf Aufmerksamkeit zu
  vertrauen. `render-egress-values.sh` warnt bei abgelaufenen Listen.
- **Erreichbarkeit je Endpunkt einzeln überwachen**, nicht aggregiert — ein
  einzelner ausgefallener TSP verschwindet sonst in der Gesamtfehlerrate.

## Zielbild

Diese Liste macht den IP-basierten Ansatz benutzbarer, sie ist aber nicht das
Ziel. Robuster ist FQDN-Allowlisting über ein Egress Gateway oder
CNI-FQDN-Policies — siehe
[Konzept Laufzeitüberwachung, Abschnitt 4.5](../../docs/user-manual/Referenzen/Konzept-Laufzeitueberwachung.md).
Dieselbe Liste ist die Eingabe für beide Welten; die eine löst sie auf, die
andere nicht.

## Verwandte Dokumentation

- [Schema](../../src/schemas/egress-targets.yaml)
- [Wie Sie Egress-NetworkPolicies konfigurieren](../../docs/user-manual/Anleitungen/Wie_Sie_Egress_NetworkPolicies_konfigurieren.md)
- [Konzept: Laufzeitüberwachung](../../docs/user-manual/Referenzen/Konzept-Laufzeitueberwachung.md)
