# Sicherheitsanforderungen an den Betreiber des ZETA-Guard

Die ZETA Spezifikation definiert eine Reihe von Sicherheitsanforderungen,
zum einen direkt als Anforderung in der gemspec_ZETA selbst, zum anderen
indirekt über referenzierte Dokumente wie gemspec_krypt, OWASP Top 10,
oder BSI TR-03161-1.

Nicht alle diese Anforderungen können durch den ZETA-Guard sichergestellt werden.
Zum Beispiel gibt es Anforderungen, die sich auf die Absicherung der
Laufzeitumgebung beziehen - dies kann nur durch den Betreiber des ZETA-Guard
abgebildet werden.

Die hier bereitgestellte Liste von Anforderungen wurde identifiziert als nicht
durch das ZETA-Guard abbildbar. Sie sind damit Hinweise für die
Sicherheitsprüfungen des Fachdienstes, in dem der ZETA-Guard verwendet wird.

Diese Liste ist nicht vollständig und muss durch die Prüfung der gematik-Spezifikationen
und den darin explizit oder implizit den Betreibern zugewiesenen
Anforderungen ergänzt werden.

## OWASP-Top 10 kubernetes

Nach gematik Anforderung A_28961 sind die OWASP Top 10 für Kubernetes Installationen durch den Anbieter eines TI 2.0 Dienstes abzudecken.
Informationen zu den kubernetes OWASP Top Ten finden sich hier: https://owasp.org/www-project-kubernetes-top-ten/

## Crypto

- A_25402	ZETA Guard - Schutz der transportierten Daten
(Sicherung aller Endpunkte mit TLS)
bei Nutzung einer betreiberspezifischen Lösung für mTLS
- Seitens der Anbieter ist sicherzustellen, dass in allen Containern die Devices
/dev/random und /dev/urandom Zufallszahlen entsprechend den Anforderungen aus
BSI-TR-03116-1, 3.8 liefern.

## Storage

- Sichere Speicherung von Kryptomaterial des ZETA-Guard in Secrets (o.ä.)

## Authentication

- A_28830	HSM Proxy, Attribute Based Access Control:
Diese Funktionaltät wird im HSM Proxy umgesetzt,
der durch den Betreiber eines VAU-basierten Fachdienstes
beizustellen ist.

