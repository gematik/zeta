# Sicherheitsanforderungen an den Betreiber des ZETA-Guard

Die ZETA-Spezifikation definiert eine Reihe von Sicherheitsanforderungen — zum
einen direkt in der gemSpec_ZETA, zum anderen indirekt über referenzierte
Dokumente wie gemSpec_Krypt, OWASP Top 10 oder BSI TR-03161-1.

Nicht alle davon kann der ZETA-Guard erfüllen. Anforderungen an die Absicherung
der Laufzeitumgebung etwa kann nur sein Betreiber umsetzen.

Die folgende Liste führt die Anforderungen auf, die der ZETA-Guard nicht
abdeckt. Sie sind damit Hinweise für die Sicherheitsprüfungen des Fachdienstes,
in dem der ZETA-Guard eingesetzt wird.

Die Liste ist nicht vollständig: Ergänzen Sie sie um die Anforderungen, die die
gematik-Spezifikationen den Betreibern explizit oder implizit zuweisen.

## OWASP Top 10 Kubernetes

Nach gematik-Anforderung A_28961 sind die OWASP Top 10 für
Kubernetes-Installationen durch den Anbieter eines TI-2.0-Dienstes abzudecken.
Informationen zu den OWASP Top Ten für Kubernetes finden sich hier:
https://owasp.org/www-project-kubernetes-top-ten/

## Schutzmaßnahmen gegen die OWASP-Top-10-Risiken

Als Schutzmaßnahme gegen DoS-Attacken auf den ZETA-Guard muss das Rate-Limit
entsprechend den erwarteten Nutzungsszenarien konfiguriert werden.

Die Konfigurationsmöglichkeiten sind im Abschnitt „Rate Limit einrichten“ in
[Wie Sie ZETA-Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#rate-limit-einrichten)
beschrieben.

## Crypto

- A_25402	ZETA-Guard - Schutz der transportierten Daten
(Sicherung aller Endpunkte mit TLS)
bei Nutzung einer betreiberspezifischen Lösung für mTLS
- Seitens der Anbieter ist sicherzustellen, dass in allen Containern die Devices
`/dev/random` und `/dev/urandom` Zufallszahlen entsprechend den Anforderungen
aus BSI-TR-03116-1, 3.8 liefern.

## Storage

- Sichere Speicherung von Kryptomaterial des ZETA-Guard in Secrets (o. Ä.)

## Authentication

- A_28830	HSM-Proxy, Attribute Based Access Control:
Diese Funktionalität wird im HSM-Proxy umgesetzt,
der durch den Betreiber eines VAU-basierten Fachdienstes
beizustellen ist.

## Betrieb des Authservers in einer VAU-basierten Umgebung

Wird der Authserver in einer VAU-basierten Umgebung betrieben und dessen
Datenhaltung (Datenbank) außerhalb der VAU verortet, dürfen die Daten die VAU
nur verschlüsselt verlassen. Dafür kann beim Authserver sowohl Verschlüsselung
als auch eine zusätzliche Datenintegritätsprüfung aktiviert werden.
Für Details siehe [Wie Sie ZETA-Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md#10-besonderheiten-vau-und-keycloak-datenbank).
