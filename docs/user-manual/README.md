
# Übersicht

Dieses Produkthandbuch beinhaltet einerseits Anleitungsdokumente unter
[Anleitungen](Anleitungen/Anleitungen.md). Anderseits beinhaltet es Referenzen unter
[Referenzen](Referenzen/Referenzen.md), welche die einzelnen Komponenten des ZETA Guard,
ZETA SDK und ZETA Testclienten im Detail erklären. Die Referenzen werden ggf.
in Zukunft in die jeweiligen Repositories der Subkomponenten verschoben.

Als Einstieg eignen sich folgende Dokumente besonders gut:

* Für ein testweises Installieren eines ZETA Guard:
   [ZETA Guard Quickstart fuer lokales deployment.md](Anleitungen/ZETA_Guard_Quickstart_fuer_lokales_deployment.md)
* Für das Einrichten des ZETA Demo clienten:
   [Wie Sie den ZETA Demo client ausführen.md](Anleitungen/Wie_Sie_den_ZETA_Demo_client_ausf%C3%BChren.md)
* Für das Integrieren des ZETA Client SDK:
   [Wie Sie das ZETA SDK integrieren.md](Anleitungen/Wie_Sie_das_ZETA_SDK_integrieren.md)
* Für das Bauen des ZETA Testdrivers (ein ZETA client, der als Proxy dient)
   [Wie Sie den Testdriver bauen](Anleitungen/Wie_Sie_den_Testdriver_bauen.md)
* Für das Ausführen des ZETA Testdrivers
  [Wie Sie den Testdriver nutzen](Anleitungen/Wie_Sie_den_Testdriver_nutzen.md)
* Wie Sie einen Ende-zu-Ende Integrationstest ausführen
  [Wie Sie einen Ende-zu-Ende Integrationstest ausführen](Anleitungen/Wie_Sie_einen_Ende_zu_Ende_Integrationstest_ausführen.md)
* Wie Sie den ZETA-Guard Cluster lokal in einem `KIND` Setup ausführen
  [Wie Sie das Cluster lokal mit KIND aufsetzen](Anleitungen/Wie_Sie_das_Cluster_lokal_mit_KIND_aufsetzen.md)

> [!WARNING]  
> Beim aktuellen Stand handelt sich um einen funktional vollständigen Stand, bei dem die sicherheitstechnische Prüfung noch nicht abgeschlossen ist. In diesem Kontext fehlt ebenfalls noch eine abschließende Bewertung der Sicherheitsrisiken bei den eingesetzten Drittkomponenten für ZETA SDK und ZETA Guard. Der aktuelle Stand ist nicht für den produktiven Einsatz geeignet, und sollte zusätzlich nur in lokalen Umgebungen für Test- und Integrationszwecke eingesetzt werden. Siehe auch Bewertungen von potenziellen Schwachstellen für [ZETA-Guard](./cve-assessment/ZETA-ZETA-Guard%20Bewertung%20von%20potenziellen%20Schwachstellen-121225-192905.pdf) und [Zeta SDK](./cve-assessment/ZETA-ZETA-SDK%20Bewertung%20von%20Sicherheitsrisiken%20Version%200.2.3-121225-193106.pdf)


Für den produktiven Betrieb des ZETA-Guard empfehlen sich zusätzlich folgende
Dokumente:

* Leitszenarien des Deployments des ZETA-Guard für unterschiedliche Fachdienste:
  [Deploymentszenarien](Referenzen/Deploymentszenarien.md)
* Konfiguration des ZETA Guard mit Details zu allen relevanten Komponenten
  [Wie Sie ZETA Guard in Kubernetes konfigurieren](Anleitungen/Wie_Sie_ZETA_Guard_in_Kubernetes_konfigurieren.md)
