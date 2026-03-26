# Wie Sie eine eigenen OCI Registry verwenden

Das ZETA Guard Helm Chart verweist standardmäßig auf Images bei den Upstream
Registries. Für den produktiven Einsatz ist aus Gründen der Verfügbarkeit und
Trafficvermeidung eine puffernde lokale Registry vom Anbieter zu nutzen.

Damit dann die Images von dort bezogen werden, muss dies über Helm Values
entsprechend gesteuert werden:

* allgemeine Konfiguration
    * `global.registry_host` Name der Registry, z.B.
      `my.registry.corp.internal:443`
    * `global.imagePullSecrets` (optional) Liste mit Image Pull Secrets
      im [Syntax von Kubernetes](https://kubernetes.io/docs/reference/kubernetes-api/workload-resources/pod-v1/#containers).
      Erforderlich, wenn Container Images durch Authentifizierung geschützt
      sind.
* Authorization Server
    * `authserver.image.repository` Name des authserver Images auf der Registry
    * `authserver.image.tag` Zu verwendender Image Tag
    * `authserver.image.digest` optionaler Image Digest – überschreibt den Tag,
      wenn vorhanden
    * `authserver.imagePullPolicy` ist standartmäßig `Always`
    * `authserver.imagePullSecrets` (optional) ähnlich `global.imagePullSecrets`
* PEP Http Proxy
    * `pepproxy.image.repository` Name des authserver Images auf der Registry
    * `pepproxy.image.tag` Zu verwendender Image Tag
    * `pepproxy.image.digest` optionaler Image Digest – überschreibt den Tag,
      wenn vorhanden
    * `pepproxy.imagePullPolicy` ist standartmäßig `Always`
    * `pepproxy.imagePullSecrets` (optional) ähnlich `global.imagePullSecrets`
* Analoges wird für die weiteren Images stückweise folgen
