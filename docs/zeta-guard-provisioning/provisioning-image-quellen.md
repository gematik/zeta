# Herkunft und Quellen der Provisioning-Image-Artefakte

Das Provisioning Image stellt kryptografische Vertrauensanker, Sperrlisten und Konfigurationsdaten für den ZETA Guard bereit. Es wird als rein datenführendes OCI-Image durch die gematik signiert zur Verfügung gestellt.

- **Produktivumgebung (PU):** `europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-provisioning/zeta-guard-provisioning:latest`
- **Testumgebung (TU):** `europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-provisioning/zeta-guard-provisioning:latest`

---

## 1. Verzeichnisstruktur (gemSpec_ZETA 5.6.5.1)

```text
.
|-- .manifest
|-- .revision
|-- ECC-RSA_TSL-test.xml
|-- TrustedTpm.cab
|-- android-roots
|   |-- roots.json
|   '-- status.json
|-- apple-roots
|   '-- apple-root.pem
|-- federation-master
|   '-- federation-master.yaml
|-- federation-master.yaml
|-- policy-engine-bundle-keys
|   |-- ca
|   |   |-- GEM.KOMP-CA8.pem
|   |   '-- GEM.RCA7.pem
|   '-- signers
|       '-- ZETA_PIPPAP_Policies_03.06.2026_16_31.pem
|-- redirect-uris
|   '-- redirect-uris.json
|-- roots.json
|-- ti-roots
|   '-- roots.json
|-- trusted-tpm
|   '-- TrustedTpm.cab
'-- tsl
    '-- ECC_PU_TSL_10322.xml
```

---

## 2. Herkunft und Quellen der Artefakte

| Pfad im Image | Beschreibung / Zweck | Offizielle Quelle / Herkunft | Format & Spezifikation |
|---|---|---|---|
| `.manifest` | SHA-256-Prüfsummen aller Dateien zur Integritätsprüfung beim Entpacken | Build-Pipeline (automatisch beim OCI-Build erzeugt) | Text (`<SHA-256-Hex> <Relativer-Pfad>`) |
| `.revision` | Git-Commit-Hash oder Build-Kennung des Datenstands | Build-Pipeline (automatisch beim OCI-Build erzeugt) | Text (Git-SHA / Versionsstring) |
| `android-roots/roots.json` | Google Hardware Attestation Root-Zertifikate zur Verifikation der Key-Attestation-Ketten | [Google Attestation Root](https://android.googleapis.com/attestation/root) | JSON-Array mit Base64-/PEM-X.509-Root-Zertifikaten |
| `android-roots/status.json` | Certificate Revocation Status List für Google Attestation Keys (Sperrliste kompromittierter Attestation Keys) | [Google Attestation Status](https://android.googleapis.com/attestation/status) | JSON (Schema draft-07) mit Zertifikatsseriennummern (Hex) und Status (`REVOKED`, `SUSPENDED`) |
| `apple-roots/apple-root.pem` | Apple App Attest Root CA Zertifikat zur Verifikation der Apple-App-Attest-Objekte | [Apple PKI](https://www.apple.com/certificateauthority/) (Apple App Attest Root CA) | X.509 PEM-Zertifikat |
| `ti-roots/roots.json` | TI-Vertrauensanker (Root CAs der Telematikinfrastruktur) | [gematik TSL-Portal (PU)](https://download.tsl.ti-dienste.de/ECC/ROOT-CA/roots.json) bzw. [Testumgebung](https://download-test.tsl.ti-dienste.de/ECC/ROOT-CA/roots.json) | JSON-Array mit X.509-TI-Root-Zertifikaten |
| `tsl/*.xml` | Trust Service Status List (TSL) der Telematikinfrastruktur | gematik TSL-Download-Dienst: `https://download.tsl.ti-dienste.de/` (PU) bzw. `https://download-test.tsl.ti-dienste.de/` (Test) | XML (ETSI TS 119 612 / gemSpec_PKI) |
| `trusted-tpm/TrustedTpm.cab` | TPM-Root-Zertifikate und Revocation-Listen der Hardware-Hersteller | Microsoft Trusted TPM Repository (`http://trustedtpm.microsoft.com/pki/trustedtpm/TrustedTpm.cab` / Microsoft PKI Catalog) | Signiertes Microsoft Cabinet-Archiv (.cab) |
| `federation-master/federation-master.yaml` | Metadaten und Trust Anchor des OpenID Federation Masters (Entity ID, JWKS-Endpunkt) | gematik OpenID-Föderationsverwaltung der jeweiligen Umgebung (PU / RU / TU) | YAML (OpenID Federation 1.0) |
| `policy-engine-bundle-keys/ca/` | Ausstellende CA-Zertifikate der gematik Komponenten-PKI für Policy-Signer | gematik Komponenten-PKI (aus TSL bzw. TI-PKI) | X.509 PEM-Zertifikate (z. B. `GEM.KOMP-CA8.pem`, `GEM.RCA7.pem`) |
| `policy-engine-bundle-keys/signers/` | Autorisierte Signatur-Zertifikate für OPA Policy Bundles | gematik Policy Management (PIP/PAP-Betrieb) | X.509 PEM-Zertifikat |
| `redirect-uris/redirect-uris.json` | Registrierte und freigegebene `redirect_uris` je gematik `product_id` (Client Registry gem. A_29723-01) | gematik Produkt- und Fachdienst-Registrierung | JSON (`client-registry.json` bzw. `redirect-uris.json`) |
| Wurzelverzeichnis (`roots.json`, `TrustedTpm.cab`, `federation-master.yaml`, `ECC-RSA_TSL-test.xml`) | Abwärtskompatibilitäts-Kopien für ältere ZETA-Guard-Versionen | Identisch mit den entsprechenden Unterverzeichnissen | Entspricht den Quelldateien |

---

## 3. Prüfung der Signatur des Provisioning Images

Das Provisioning Image wird mit **Cosign** signiert. Die Verifikation erfolgt vor dem Entpacken (im Init-Container des ZETA Guard oder CI/CD) gegen die Zertifikatskette der gematik.

### Veröffentlichung des Signaturschlüssels

Die öffentlichen Signaturzertifikate und die zugehörige Zertifikatskette sind öffentlich auf GitHub publiziert:

- **Repository:** [https://github.com/gematik/zeta/tree/main/zeta-guard-prv-signing-key](https://github.com/gematik/zeta/tree/main/zeta-guard-prv-signing-key)
- **Dateien im Repository:**
  - Produktion (`prod/`):
    - Signaturzertifikat: [zeta-guard-prv-signing-key/prod/OCIcontainerimage2.pem](zeta-guard-prv-signing-key/prod/OCIcontainerimage2.pem)
    - CA-Kette: [zeta-guard-prv-signing-key/prod/ca-chain.pem](zeta-guard-prv-signing-key/prod/ca-chain.pem)
  - Test (`test/`):
    - Entsprechende Test-Zertifikate unter [zeta-guard-prv-signing-key/test/](zeta-guard-prv-signing-key/test/)

### Verifikationsbefehl (Beispiel Produktion)

```bash
cosign verify \
  --cert-chain zeta-guard-prv-signing-key/prod/ca-chain.pem \
  --cert zeta-guard-prv-signing-key/prod/OCIcontainerimage2.pem \
  europe-west3-docker.pkg.dev/gematik-pt-zeta-prod/zeta-provisioning/zeta-guard-provisioning:latest
```
