# HSM Proxy

## Beschreibung

Der HSM Proxy stellt eine einheitliche API für die Interaktion mit Hardware Security Modules (HSM) bereit. Er ermöglicht es, kryptographische Operationen für ECC-Schlüssel durchzuführen. Dabei werden die Anwendungsfälle TLS-Offloading sowie JWT-Signatur und CBOR-Signatur unterstützt. Die Algorithmen sind auf die NIST-Standards (P-256, P-384, P-521) beschränkt.

## Architektur-Übersicht für ZETA Guard

                               +-------------------------+
                               |      ZETA Guard         |
                               |      HSM Proxy          |
                               +-------------------------+
                               |  Core Logic (PKCS#11)   |
                               +-----------+-------------+
                                           |
                   +-----------------------+-----------------------+
                   | (Internes Mapping / Transcoding)              |
                   v                                               v
        [ gRPC Port :50051 ]                            [ HTTP Port :8080 ]
                   ^                                               ^
                   | (Protobuf / HTTP2)                            | (JSON / HTTP1.1)
                   |                                               |
        +----------+----------+                         +----------+----------+
        |      NGINX          |                         |      KEYCLOAK       |
        | (Ingress Controller)|                         |   (Identity Prov.)  |
        +---------------------+                         +---------------------+
        - TLS Offloading                                - JWT Signatur
        - Nutzt C++ Engine                              - Nutzt Java SPI
        - Hoher Durchsatz                               - Einfache Integration

**TLS-Handshake (insbesondere TLS 1.2 und 1.3)**
Der Server (nginx) beweist, dass er den privaten Schlüssel zum Zertifikat besitzt.
**Operation: Sign** (für Zertifikatsverify in TLS 1.3 und TLS 1.2 mit ECDSA/RSA).
Input: Der Hash (Digest) der Handshake-Daten oder ein Pre-Master-Secret.

**CBOR Signatur (nginx / ZETA/ASL)**
ZETA/ASL erstellt CBOR Daten, die mit dem HSM signiert werden.
**Operation: Sign**.
Algorithmen: ES256 (ECDSA mit P-256).
Input: CBOR Daten.

**JWT Signatur (Keycloak / Applikation)**
Keycloak erstellt Tokens (Access Tokens, ID Tokens).
**Operation: Sign**.
Algorithmen: ES256 (ECDSA mit P-256).
Besonderheit: Keycloak muss den Public Key abrufen können, um ihn im JWKS (JSON Web Key Set) Endpunkt zu veröffentlichen.

**Health Check (Monitoring)**
Prüft die Erreichbarkeit des HSM-Backends und den Status des Proxies.
**Operation: HealthCheck**.
Output: Serving Status, Version, HSM Info.

## Implementierung

Der Proxy verwendet gRPC als Kommunikationsprotokoll und bietet eine RESTful API für die Interaktion mit dem HSM. Die google.api.http Annotationen sind enthalten, damit daraus automatisch die OpenAPI/REST Schnittstelle generiert werden kann.

Die Protokolldefinitionen befinden sich in der [hsm-proxy.proto](../../src/gRPC/hsm-proxy.proto) Datei.

### Hinweise zur Implementierung (NIST ECC)

**JWT Signatur (Keycloak)**: Erwartet die Signatur meist als "Raw Format" (Konkatenierung der Koordinaten R und S, z.B. 64 Bytes für P-256).
**TLS (Nginx/OpenSSL)**: Erwartet die Signatur meist im ASN.1 DER Format (Sequence of Integer R, Integer S).

Der Proxy sollte so implementiert werden, dass er Raw (R|S) zurückgibt. Die OpenSSL-Engine für Nginx kann dies leicht in DER umwandeln, falls nötig.

**Kein Decrypt**
Da RSA nicht unterstützt wird, entfällt die Entschlüsselung (RSA Key Exchange).
ECC nutzt für Verschlüsselung ECDH (Elliptic Curve Diffie-Hellman). Dabei wird kein Text entschlüsselt, sondern ein Shared Secret abgeleitet.
In modernen TLS-Setups (TLS 1.3 oder TLS 1.2 mit ECDHE) macht Nginx den Schlüsselaustausch (ECDH) mit Ephemeral Keys (Einmalschlüsseln), die Nginx lokal generiert. Das HSM wird nur zum Signieren des Handshakes benötigt, um die Identität zu beweisen. Daher ist eine Derive oder Decrypt Methode in dieser Schnittstelle für ZETA Guard nicht notwendig.

**Abhängigkeiten**
Um diese .proto Datei zu kompilieren, wird die Datei google/api/annotations.proto benötigt. Diese ist Teil des [googleapis](https://github.com/googleapis/googleapis) Repositories.
