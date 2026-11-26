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
* Provisioning Processor (Init-Container)
    * `provisioningProcessor.image.repository` Pfad des Provisioning-Processor-Images in der Registry
    * `provisioningProcessor.image.tag` Zu verwendender Image Tag
    * `provisioningProcessor.provisioningContainer` OCI-Image-Referenz des Provisioning-Daten-Images
      (wird zur Laufzeit vom Init-Container geladen, siehe unten)
    * `provisioningProcessor.provisioningContainerCaSecretRef` CA-Zertifikat der Registry als Secret-Referenz (siehe unten)
    * `provisioningProcessor.provisioningContainerCaConfigMapRef` CA-Zertifikat der Registry als ConfigMap-Referenz, Alternative zur Secret-Referenz (ab Helm-Chart 1.2.3, siehe unten)
    * `provisioningProcessor.extraEnv` / `extraVolumes` / `extraVolumeMounts` (optional) generische Einbindung beliebiger Quellen in den Init-Container (ab Helm-Chart 1.2.3, siehe unten)
    * `provisioningProcessor.registryCredentialsSecretRef` (optional) Benutzername und Token für Registries ohne anonymen Zugriff (ab Helm-Chart 1.2.3, siehe unten)
* OPA (Policy Engine)
    * `opa.image.repository` Pfad des OPA-Images in der Registry
    * `opa.image.tag` Zu verwendender Image-Tag
    * `opa.image.digest` optionaler Image-Digest – überschreibt den Tag, wenn
      vorhanden
    * `opa.imagePullPolicy` ist standardmäßig `IfNotPresent`
    * `opa.imagePullSecrets` (optional) ähnlich `global.imagePullSecrets`
    * Die OPA-Simulation nutzt dasselbe Image
* Infinispan (externer Cache, optional)
    * `global.infinispanExternal.image.repository` Pfad des Infinispan-Images in der Registry
    * `global.infinispanExternal.image.tag` Zu verwendender Image-Tag
    * `global.infinispanExternal.imagePullPolicy` ist standardmäßig `Always`
    * `global.infinispanExternal.imagePullSecrets` (optional) ähnlich `global.imagePullSecrets`
* Keychain-Generator (nur bei aktivierter DB-Verschlüsselung für VAU-basierte Anwendungen)
    * `authserver.dbEnc.keychainGenerator.image.repository` Pfad des Images in der Registry
    * `authserver.dbEnc.keychainGenerator.image.tag` Zu verwendender Image-Tag
    * `authserver.dbEnc.keychainGenerator.image.digest` optionaler Image-Digest
      – überschreibt den Tag, wenn vorhanden

## Inhaltsverzeichnis

- [Begriffe: Provisioning Processor und Provisioning-Daten-Image](#begriffe-provisioning-processor-und-provisioning-daten-image)
- [Provisioning-Daten-Image spiegeln](#provisioning-daten-image-spiegeln)
  - [Image mit Signatur in die eigene Registry übertragen](#image-mit-signatur-in-die-eigene-registry-übertragen)
  - [CA-Zertifikat für die Registry](#ca-zertifikat-für-die-registry)
  - [Zugangsdaten für die Registry](#zugangsdaten-für-die-registry)

## Begriffe: Provisioning Processor und Provisioning-Daten-Image

Der **Provisioning Processor** ist ein Init-Container, der beim Start der ZETA Guard
Pods (Authserver, PEP-Proxy, OPA) ausgeführt wird. Er wird über
`provisioningProcessor.image.*` konfiguriert und ist Bestandteil des Helm Charts.
Mehr zur Konfiguration des Provisioning Processors findet sich in der
[Ressourcenverwaltung](Wie_Sie_Ressourcen_für_ZETA_Guard_Pods_verwalten.md).

Das **Provisioning-Daten-Image** (konfiguriert über
`provisioningProcessor.provisioningContainer`) ist ein separates OCI-Image, das der
Provisioning Processor zur Laufzeit aus der Registry herunterlädt und auf seine
cosign-Signatur prüft. Es enthält kryptografisches Material (Trust-Roots,
Zertifikatsketten), das von den ZETA Guard Diensten benötigt wird — z.B. die
SMC-B-Vertrauensanker aus der TSL.

## Provisioning-Daten-Image spiegeln

Das Provisioning-Daten-Image (`zetaguard-provisioning`) wird vom Init-Container
zur Laufzeit aus der Registry geladen und auf seine cosign-Signatur geprüft.
cosign legt Signaturen als separate OCI-Artefakte unter einem `.sig`-Tag in
derselben Registry ab (z.B.
`europe-west3-docker.pkg.dev/.../zeta-guard-provisioning:sha256-<digest>.sig`).

Beim Spiegeln müssen daher **sowohl der Image-Tag als auch der zugehörige
`.sig`-Tag** in die Ziel-Registry übertragen werden. Dafür gibt es mehrere
Möglichkeiten:

- **`cosign save`/`load`** (empfohlen): überträgt Image und alle Signatur-Artefakte
  in einem Schritt, ohne dass der `.sig`-Tag explizit bekannt sein muss.
- **`docker pull`/`push`**: möglich, erfordert aber das explizite Spiegeln des
  `.sig`-Tags zusätzlich zum Image-Tag.
- **`skopeo copy`**: geeignet insbesondere in OpenShift-Umgebungen. Ob `.sig`-Tags
  automatisch mitübertragen werden, hängt vom eingesetzten Registry-Backend ab —
  bei Red Hat Quay müssen die `.sig`-Tags explizit angegeben werden. Das intern
  genutzte Tool und Registry-Produkt sind daher stets zu prüfen.

### Image mit Signatur in die eigene Registry übertragen

Auf einem Rechner mit Zugriff auf die gematik-Registry:

```bash
cosign save \
  --dir /tmp/zetaguard-provisioning-cosign \
  europe-west3-docker.pkg.dev/gematik-pt-zeta-test/zeta-provisioning/zeta-guard-provisioning:latest

tar -czf zetaguard-provisioning-cosign.tar.gz \
  -C /tmp zetaguard-provisioning-cosign
```

Den Tarball auf ein System übertragen, das Zugriff auf die interne Registry hat
(z.B. eine Jumphost-VM im Zielnetz), und dort ausführen:

```bash
tar -xzf zetaguard-provisioning-cosign.tar.gz -C /tmp

cosign load \
  --dir /tmp/zetaguard-provisioning-cosign \
  my.registry.corp.internal/zetaguard-provisioning:latest

# Temporäre Dateien können danach gelöscht werden:
rm -rf /tmp/zetaguard-provisioning-cosign zetaguard-provisioning-cosign.tar.gz
```

`cosign load` überträgt Image **und** Signatur in die Ziel-Registry.

### CA-Zertifikat für die Registry

Wenn die Registry ein Zertifikat von einer Certification Authority (CA) verwendet, die
nicht öffentlich vertrauenswürdig ist (z.B. eine interne CA), muss das CA-Zertifikat
dem Init-Container mitgegeben werden. Das Zertifikat wird als Kubernetes Secret
angelegt und als Datei in den Init-Container gemountet. Diese Variante vermeidet
das Kernel-Limit `ARG_MAX`, das bei der Übergabe großer Zertifikatsketten als
Umgebungsvariable überschritten werden kann.

```bash
kubectl create secret generic registry-ca \
  --from-file=ca.crt=/path/to/ca.pem
```

```yaml
zeta-guard:
    provisioningProcessor:
        provisioningContainerCaSecretRef:
            name: registry-ca
            key: ca.crt
```

#### Alternative: CA-Zertifikat aus einer ConfigMap

Da die öffentlichen Teile eines CA-Zertifikats nicht geheim sind, kann das
Zertifikat statt aus einem Secret auch aus einer **ConfigMap** gemountet werden.
Das ist insbesondere in OpenShift nützlich: Der dortige Standardmechanismus
[„Configuring a custom PKI“](https://docs.openshift.com/container-platform/latest/networking/configuring-a-custom-pki.html)
stellt das unternehmensweite CA-Bundle als ConfigMap bereit und vermeidet so das
händische Pflegen von CA-Bundles.

```bash
kubectl create configmap zeta-guard-openshift-ca-bundle \
  --from-file=ca-bundle.crt=/path/to/ca-bundle.pem
```

```yaml
zeta-guard:
    provisioningProcessor:
        provisioningContainerCaConfigMapRef:
            name: zeta-guard-openshift-ca-bundle
            key: ca-bundle.crt
```

`provisioningContainerCaSecretRef` und `provisioningContainerCaConfigMapRef`
schließen sich gegenseitig aus; ist beides gesetzt, hat die Secret-Referenz
Vorrang.

#### Generische Einbindung über `extraVolumes`/`extraVolumeMounts`/`extraEnv`

Soll das CA-Zertifikat (oder anderes Material) aus einer anderen Quelle
(projizierte Volumes, CSI …) kommen, lässt sich die Einbindung vollständig frei
über generische Werte am Init-Container vornehmen. Volume, Mount und die
Umgebungsvariable `PROVISIONING_CONTAINER_REGISTRY_CA_FILE` werden dabei selbst
verdrahtet:

```yaml
zeta-guard:
    provisioningProcessor:
        extraEnv:
            - name: PROVISIONING_CONTAINER_REGISTRY_CA_FILE
              value: /var/custom-ca/ca.crt
        extraVolumes:
            - name: custom-ca
              configMap:
                  name: my-ca-bundle
        extraVolumeMounts:
            - name: custom-ca
              mountPath: /var/custom-ca
              readOnly: true
```

### Zugangsdaten für die Registry

Viele Registries in Unternehmensumgebungen erlauben keinen anonymen Zugriff. Um
das Provisioning-Daten-Image aus einer solchen Registry zu laden, werden ein
Benutzername und ein Token (bzw. Passwort) benötigt. Der Init-Container führt
damit vor dem Laden des Images ein `cosign login` aus. Verwendet werden dafür die
Umgebungsvariablen `PROVISIONING_CONTAINER_REGISTRY_USERNAME` und
`PROVISIONING_CONTAINER_REGISTRY_TOKEN`.

Die Zugangsdaten stammen aus einem bestehenden Kubernetes-Secret, das über
`provisioningProcessor.registryCredentialsSecretRef` referenziert wird.

```bash
kubectl create secret generic registry-credentials \
  --from-literal=username='<registry-user>' \
  --from-literal=token='<registry-token>'
```

```yaml
zeta-guard:
    provisioningProcessor:
        registryCredentialsSecretRef:
            name: registry-credentials   # Name des Kubernetes-Secrets
            usernameKey: username        # Key des Benutzernamens (Standard: username)
            tokenKey: token              # Key des Tokens (Standard: token)
```

`usernameKey` und `tokenKey` sind optional und müssen nur gesetzt werden, wenn
das Secret abweichende Key-Namen verwendet (Standard: `username` und `token`).
Ohne gesetzte `registryCredentialsSecretRef` erfolgt der Zugriff anonym.
