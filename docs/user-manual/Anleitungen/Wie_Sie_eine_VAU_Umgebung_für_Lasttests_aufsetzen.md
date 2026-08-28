# Wie Sie eine VAU-Umgebung für Last- und Performance-Tests aufsetzen

---

Status: In Arbeit

Zielgruppe: Systemadministratoren der Fachdienst-Anbieter

_Inhalt: „Kochbuch" für das Aufsetzen einer vollständigen, HSM-gestützten
ZETA-Guard-Umgebung nach VAU-Randbedingungen, die für Last- und
Performance-Tests geeignet ist. Beschreibt Voraussetzungen, Architektur, das
schrittweise Vorgehen sowie Betriebs- und Fehlerbehebungshinweise. Diese
Anleitung fasst die Einzelanleitungen zusammen und ergänzt die Einstellungen,
die die Umgebung hochverfügbar, HSM-gestützt und in sich geschlossen machen._

---

## Inhaltsverzeichnis

- [Überblick](#überblick)
- [Voraussetzungen (Randbedingungen)](#voraussetzungen-randbedingungen)
- [Architektur](#architektur)
- [Kochbuch: Vorgehen](#kochbuch-vorgehen)
    - [1. Cluster-Voraussetzungen](#1-cluster-voraussetzungen)
    - [2. HSM und Schlüssel](#2-hsm-und-schlüssel)
    - [3. Secrets](#3-secrets)
    - [4. Konfiguration der Helm-Werte](#4-konfiguration-der-helm-werte)
    - [5. Deployment](#5-deployment)
    - [6. Nachgelagerte Konfiguration](#6-nachgelagerte-konfiguration)
    - [7. Verifikation](#7-verifikation)
- [Betriebshinweise](#betriebshinweise)
- [Fehlerbehebung](#fehlerbehebung)
- [Verwandte Dokumente](#verwandte-dokumente)

## Überblick

Diese Anleitung beschreibt einen **vollständigen ZETA-Guard-Stack**, der wie
eine
VAU gehärtet und so dimensioniert ist, dass er **Last- und Performance-Tests**
bedienen kann.

| Bereich               | Aufbau                                                                                                 |
|-----------------------|--------------------------------------------------------------------------------------------------------|
| Service Mesh          | Istio aktiviert                                                                                        |
| PEP-Proxy             | **2 Replicas**, ASL aktiviert, TLS über HSM                                                            |
| Authserver (Keycloak) | **2 Replicas**, TLS über HSM, Tokensignierung über HSM, DB-Spaltenverschlüsselung + Integritätsprüfung |
| Session/Cache         | **externer Infinispan** (Hot Rod), TLS über HSM                                                        |
| Datenbank             | **1× CloudNativePG** PostgreSQL                                                                        |
| OCSP                  | **deaktiviert** (PEP-ASL + Authserver-TSL)                                                             |
| Tests                 | Testdriver, Tiger-Proxy, exauthsim, Testfachdienst, Cert-Validation-Mock, TLS-Test-Tool                |
| Observability         | Telemetrie-Gateway + Monitoring-Backend (Prometheus/Grafana)                                           |
| Betrieb               | ausschließlich manuelle Neustarts/Anpassungen; kein Auto-Deploy                                        |

> **ASL über HSM** ist in diesem Rezept **noch nicht** enthalten — der
> ASL-*Signaturschlüssel* wird weiterhin aus einer gemounteten Datei geladen.
> Nur das ASL-*TLS* nutzt das HSM. Die Verlagerung des ASL-Signaturschlüssels
> ins
> HSM wird separat verfolgt (ZETAP-1364).

> **HSM-Umfang:** Dieses Rezept beschreibt den vollen HSM-Ausbau (TLS an
> Authserver, PEP, Infinispan und Ingress sowie Tokensignierung). Für reine
> Lasttests kann der HSM-Einsatz auch auf die DB-Verschlüsselung (KEK)
> beschränkt werden, indem die übrigen `hsm`-Schalter deaktiviert bleiben —
> bisherige Lasttest-Umgebungen liefen in dieser reduzierten Variante. Der
> volle Ausbau ist entsprechend weniger erprobt; planen Sie dafür zusätzliche
> Verifikationsläufe ein.

## Voraussetzungen (Randbedingungen)

- `helm` und `kubectl` im PATH, kubeconfig auf den Ziel-Cluster.
- **cert-manager** installiert.
- **CloudNativePG-Operator** installiert.
- **metrics-server** installiert (für `kubectl top`/HPA und Last-Reserve).
- **Istio** im Cluster installiert (das Chart erzeugt nur `PeerAuthentication`).
- Ein über gRPC erreichbares **HSM** (PKCS#11-Proxy). Für eine Testumgebung kann
  stattdessen der mitgelieferte **HSM-Simulator** (`hsm-sim`) verwendet werden —
  siehe [HSM und Schlüssel](#2-hsm-und-schlüssel).
- Ein **Registry-Pull-Secret** im Namespace.
- **Ressourcen**: Pods so dimensionieren, dass die Hardware bei Lasttests
  *nicht*
  der Flaschenhals ist (vergleichbar mit einer produktionsnahen Stage). Die
  Chart-Defaults für `authserver`/`pepproxy` definieren CPU-/Speicher-Requests
  und ein Speicher-Limit (bewusst kein CPU-Limit); Requests prüfen und ggf.
  anheben — siehe
  [Wie Sie Ressourcen für ZETA Guard Pods verwalten](Wie_Sie_Ressourcen_für_ZETA_Guard_Pods_verwalten.md)
  und [Referenz des Helm Charts](../Referenzen/Referenz_des_Helm_Charts.md).

## Architektur

```
Client → Ingress (NIC, TLS über HSM) → 2× PEP (ASL, TLS über HSM)
                                          → 2× Keycloak (TLS+Tokensignierung über HSM,
                                                         verschlüsselte + integritätsgeprüfte DB)
                                              → OPA (Policy)
                                              → externer Infinispan (TLS über HSM)
                                              → CloudNativePG (1× PostgreSQL)
Daneben: Testsuite (Testdriver, Tiger-Proxy, …) + Telemetrie/Monitoring.
```

## Kochbuch: Vorgehen

### 1. Cluster-Voraussetzungen

Im Ziel-Cluster installieren: cert-manager, CloudNativePG-Operator,
metrics-server und Istio. Namespace und Registry-Pull-Secret anlegen.

### 2. HSM und Schlüssel

Die Umgebung nutzt HSM-gestützte Schlüssel an vier Stellen. Legen Sie diese
Schlüssel-IDs im HSM an (Namen sind Beispiele; mit den Werten unten konsistent
halten):

| Zweck                    | Beispiel-Schlüssel-ID                                | Genutzt von                           |
|--------------------------|------------------------------------------------------|---------------------------------------|
| Authserver- + PEP-TLS    | `zeta-guard-keycloak-tls-es256-v1.p256` / `tls.p256` | Keycloak- & PEP-TLS-Listener          |
| Tokensignierung (ES256)  | `zeta-guard-keycloak-token-es256-v1.p256`            | Keycloak-JWT-Signierung               |
| DB-Verschlüsselung (KEK) | `vau-db-kek-v1`                                      | Wrapping des Keycloak-DB-Keychains    |
| Infinispan-TLS           | `infinispan.p256`                                    | TLS des externen Infinispan (Hot Rod) |

**Echtes HSM (für einen Fachdienst empfohlen):** Komponenten auf Ihren
HSM-Proxy-Endpunkt zeigen lassen und die o. g. Schlüssel importieren/erzeugen.
Die TLS-/Signatur-Zertifikate müssen zu den HSM-Schlüsseln passen.

**HSM-Simulator (`hsm-sim`, nur Test):** das mitgelieferte `hsm-sim`-Subchart
aktivieren. Es *leitet* EC-Schlüssel deterministisch aus der Schlüssel-ID ab
(IDs mit Endung `.p256` → P-256) und stellt passende Zertifikate aus seiner
eigenen CA aus. Die benötigten öffentlichen Zertifikate über `hsmsim.extraKeys`
mounten (z. B. `tls.p256.cert.pem`, `infinispan.p256.cert.pem`). Hinweis: Der
Simulator kann keinen extern erzeugten privaten Schlüssel halten — er dient
Funktions-/Lasttests, nicht dem Produktivbetrieb.

> **KEK-Stabilität:** Die DB-Spaltenverschlüsselung wird mit dem HSM-KEK
> (`vau-db-kek-v1`) entschlüsselt. Verliert/erneuert das HSM (oder `hsm-sim`)
> diesen Schlüssel, kann die bestehende verschlüsselte Datenbank nicht mehr
> entschlüsselt werden und der Authserver bricht mit `ERROR_DECRYPTION` ab. KEK
> stabil halten oder die DB neu aufsetzen.

Zur HSM-TLS-Verdrahtung (`store:hsm:`-Schlüssel über den ossl_hsm-Provider)
siehe
[Konfiguration einer VAU](../Referenzen/Konfiguration_VAU.md) und
[Referenz des Helm Charts](../Referenzen/Referenz_des_Helm_Charts.md).

### 3. Secrets

Vor dem Deployment im Namespace anlegen:

- **Registry-Pull-Secret** — für Image-Pulls.
- **`asl-identity`** — ASL-Signaturzertifikat, Signaturschlüssel und
  Aussteller-Zertifikat (der PEP mountet diese bei `asl_enabled: true`).
- **`hsm-tls`** — das/die öffentliche(n) TLS-Zertifikat(e) für die
  HSM-gestützten TLS-Listener. Hinweis: Das Chart liefert bereits ein
  `hsm-tls`-Secret mit zum `hsm-sim` passenden Test-Zertifikaten mit; bei
  Einsatz eines echten HSM muss es mit den eigenen Zertifikaten überschrieben
  werden.
- **Image-Trust-Chain-Secret** — für die Image-Verifikation des
  Provisioning-Processors.
- **DB-Verschlüsselungs-Keychain** (`zeta-authserver-dbenc`) — Secret mit dem
  Key `keychainFile`, das die Keychain-Datei für die DB-Spaltenverschlüsselung
  enthält. Das Secret muss vor dem Deployment im Namespace vorhanden sein; das
  Chart legt es nicht an. Der Keychain-Generator-Init-Container mountet es
  read-only (Secret-Volumes sind in Kubernetes immer read-only) und verarbeitet
  die Keychain mit dem HSM-KEK (`vau-db-kek-v1`, aus
  `authserver.hsm.dbEnc.keyId`) — er erzeugt das Secret also nicht. Anlegen des
  Secrets und die Verdrahtung der drei zusammengehörigen Values siehe
  [Wie Sie ZETA Guard in Kubernetes konfigurieren, Abschnitt 10 —
  Keychain-Secret bereitstellen](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#keychain-secret-bereitstellen).
- **Truststore-Passwort** (`pdp-truststores-pw`) und optional **`opa-bearer`**
  für OPA-Bundle-Pulls.

### 4. Konfiguration der Helm-Werte

Die Einstellungen, die aus einem Standard-Deployment diesen VAU-/Lasttest-Stack
machen, nach Anforderung gruppiert. In die Werte-Datei Ihrer Umgebung eintragen:

```yaml
global:
    istio:
        enabled: true                 # Istio PeerAuthentication
    infinispanExternal: # externer Infinispan (Session/Cache)
        enabled: true
        replicaCount: 1
        hsm:
            enabled: true               # Infinispan-TLS über HSM
            endpoint: "hsm-sim:50051"   # oder Ihr HSM-Proxy
            keyId: "infinispan.p256"
            caCert: |
                -----BEGIN CERTIFICATE-----
                ...HSM-CA-Zertifikat...
                -----END CERTIFICATE-----

zeta-guard:
    databaseMode: cloudnative       # 1× CloudNativePG PostgreSQL

    authserver:
        replicaCount: 2               # 2× Keycloak
        dbEnc:
            enabled: true               # DB-Spaltenverschlüsselung + Integritätsprüfung
        hsm:
            enabled: true
            endpoint: "hsm-sim:50051"   # oder Ihr HSM-Proxy
            dbEnc:
                keyId: "vau-db-kek-v1"
            tls:
                enabled: true             # Authserver-TLS über HSM
                keyId: "zeta-guard-keycloak-tls-es256-v1.p256"
            tokenSigning:
                enabled: true             # JWT-Signierung über HSM (Realm muss ES256 nutzen)
                keyId: "zeta-guard-keycloak-token-es256-v1.p256"

    pepproxy:
        replicaCount: 2               # 2× PEP
        asl_enabled: true             # ASL
        aslOcsp: "off"                # OCSP aus (PEP-ASL)
        hsmProxyAddr: "hsm-sim:50051" # PEP-TLS über HSM (ossl_hsm)

    nginxIngressHsm: true           # HSM-TLS am NIC-Ingress

    provisioningProcessor:
        tslOcspEnabled: false         # OCSP aus (Authserver/SMC-B-TSL)
```

Hinweise:

- **2× Keycloak erfordert externen Infinispan** (der eingebettete Cache wird
  nicht über Pods geteilt).
- **OCSP aus sind zwei Einstellungen**: `pepproxy.aslOcsp: "off"` (PEP) *und*
  `provisioningProcessor.tslOcspEnabled: false` (Authserver). Wird nur eine
  gesetzt, bleibt OCSP teilweise aktiv.
- **Tokensignierung über HSM** benötigt am Realm `defaultSignatureAlgorithm:
  ES256`; die KeyProvider-Komponente wird bei der nachgelagerten Konfiguration
  registriert, nicht vom Plugin selbst.
- **Monitoring/Telemetrie**: Telemetrie-Gateway und ein Monitoring-Backend
  (Prometheus/Grafana) aktivieren — siehe
  [Wie Sie ein Observability-Backend anschließen](Wie_Sie_ein_Observability-Backend_an_ZETA-Guard_anschließen.md).
- **Testsuite-Komponenten** (Testdriver, Tiger-Proxy, exauthsim, Testfachdienst,
  Cert-Validation-Mock, TLS-Test-Tool) werden über die Umbrella-`tags:` und die
  jeweiligen Subchart-Werte geschaltet — siehe
  [Wie Sie einen Ende-zu-Ende-Integrationstest ausführen](Wie_Sie_einen_Ende_zu_Ende_Integrationstest_ausführen.md).

### 5. Deployment

Das Umbrella-Chart mit Ihrer Werte-Datei deployen — siehe
[Wie Sie ZETA Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md).
Beim **ersten** Install zusätzlich `authserver.admin.password`,
`authserver.genesisHash` und `authserver.smcbHashingPepper` angeben.

### 6. Nachgelagerte Konfiguration

Die Keycloak-Realm-/Policy-Konfiguration (Terraform) ausführen, damit der Realm
existiert und der ES256-HSM-KeyProvider registriert ist. Siehe
[Wie Sie OPA in ZETA Guard konfigurieren](Wie_Sie_OPA_in_ZETA_Guard_konfigurieren.md)
und die nachgelagerte Realm-Konfiguration.

### 7. Verifikation

- `kubectl get pods` — 2× Authserver, 2× PEP, 1× Infinispan, 1× DB, Testsuite
  und
  Monitoring alle „Ready".
- Authserver-Log zeigt den verbundenen externen Infinispan (Hot Rod) und, bei
  deaktiviertem OCSP, `OCSP checking disabled` (kein `ocsp-signers.p12`-Fehler).
- PEP-Log zeigt, dass der ossl_hsm-Provider den TLS-Schlüssel aus dem HSM lädt
  (kein `emerg`), und die Protected-Resource-Metadaten weisen
  `"zeta_asl_use": "required"` aus.
- Ein vollständiger Client-Flow über den PEP (z. B. via Testdriver) erreicht den
  Fachdienst.

## Betriebshinweise

- **Nur manuell.** Diese Umgebung wird nicht automatisch deployt; Neustarts und
  Anpassungen erfolgen manuell/bei Bedarf (z. B. nächtliche und gezielte
  Testläufe tagsüber).
- **PEP-Skalierung / Sticky Sessions.** Bei `pepproxy.replicaCount > 1` ist der
  ASL-Session-Zustand pod-lokal; Client-Anfragen müssen auf demselben PEP-Pod
  bleiben. Der Ingress muss daher ein konsistentes/Sticky-Routing verwenden,
  damit
  ein Client für die Dauer seiner ASL-Session am selben Pod bleibt.
- **Last-Reserve.** CPU-/Speicher-Requests, Speicher-Limits und DB-Pool-Größen
  so anheben, dass die Plattform — nicht ZETA Guard — der begrenzende Faktor
  ist. Die Chart-Defaults setzen bewusst keine CPU-Limits (kein Throttling
  unter Last).
  Infinispan-
  und DB-Pods unter Dauerlast beobachten.
- **HSM-KEK-Stabilität** (siehe Schritt 2) — die häufigste Ursache für ein
  fehlgeschlagenes Re-Deployment.

## Fehlerbehebung

| Symptom                                                                        | Ursache / Behebung                                                                                                                                                                                                 |
|--------------------------------------------------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Authserver `FATAL ... ERROR_DECRYPTION: mac check in GCM failed`               | Die DB wurde mit einem anderen HSM-KEK verschlüsselt als dem jetzt aktiven. KEK stabil halten oder DB neu aufsetzen, damit sie mit dem aktuellen Schlüssel neu verschlüsselt wird.                                 |
| Authserver `No valid data file found ... ocsp-signers.p12`                     | OCSP am Init-Container deaktiviert, aber die OCSP-Keystore-Env ist noch gesetzt. `provisioningProcessor.tslOcspEnabled: false` muss sowohl das Init-Flag als auch die `OCSP_KEYSTORE_*`-Env des Authservers gaten. |
| PEP `Pending`, `secret "asl-identity" not found`                               | Das `asl-identity`-Secret (Schritt 3) vor dem Deployment mit `asl_enabled: true` anlegen.                                                                                                                          |
| PEP `SSL_CTX_use_PrivateKey("store:hsm:…") failed`, verbindet zu `[::1]:50051` | `HSM_PROXY_ADDR` am PEP-Pod nicht gesetzt → `pepproxy.hsmProxyAddr` setzen.                                                                                                                                        |
| Token-Exchange 500, `NumberFormatException` auf einem Realm-Attribut           | Bekannte Wechselwirkung zwischen Spaltenverschlüsselung und dem clusterless/Remote-Realm-Cache — mit den keycloak-zeta-Verantwortlichen klären.                                                                    |

## Verwandte Dokumente

- [Wie Sie ZETA Guard in Kubernetes konfigurieren](Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
- [Wie Sie Ressourcen für ZETA Guard Pods verwalten](Wie_Sie_Ressourcen_für_ZETA_Guard_Pods_verwalten.md)
- [Wie Sie ein Observability-Backend anschließen](Wie_Sie_ein_Observability-Backend_an_ZETA-Guard_anschließen.md)
- [Wie Sie einen Ende-zu-Ende-Integrationstest ausführen](Wie_Sie_einen_Ende_zu_Ende_Integrationstest_ausführen.md)
- [Konfiguration einer VAU (DB-Verschlüsselung/Integrität)](../Referenzen/Konfiguration_VAU.md)
- [Referenz des Helm Charts](../Referenzen/Referenz_des_Helm_Charts.md)
- [Deploymentszenarien](../Referenzen/Deploymentszenarien.md)
