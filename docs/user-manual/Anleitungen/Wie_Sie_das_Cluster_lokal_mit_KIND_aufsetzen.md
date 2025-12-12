# Wie Sie das Cluster lokal mit KIND aufsetzen

Diese Anleitung unterstützt Tester und Entwickler dabei,
das Cluster lokal mit [KIND](https://kind.sigs.k8s.io/) aufzusetzen und
auszuprobieren.
Dies stellt eine Alternative für das Kubernetes Deployment z. B. in ein
Rechenzentrum dar.

---

Zielgruppe: Tester und Entwickler

---

> [!NOTE]
> Für diese Anleitung werden folgende Dateien/Keys/Tokens benötigt:
> - pdp-keystore.b64: Base-64 kodierter Keystore mit SMCB-Zertifikat, Trust-Chain
    und privatem Schlüssel
> - pdp-keystore-pass: Passwort für Keystore 
> - REGISTRY_URL: Url zu der Registry
> - DOCKER_REGISTRY_TOKEN: Token mit Leserechten für die Docker Registry
    (startet mit `glpat-`)
> - DOCKER_REGISTRY_TOKEN_NAME: Zum Token dazugehöriger Username
> - GIT_URL: URL des Helm-Repositories (SSH oder HTTPS, je nach Git-Host)
> - Docker Desktop (mit aktivierter WSL-Integration) ist vorab installiert
    (https://docs.docker.com/desktop/install/windows-install/). In WSL sollte
    ``docker info`` ohne Fehlermeldung laufen.

## Anleitung für Windows Rechner

Für Linux und MacOS ist die Anleitung ggf. anzupassen.

### Schritt 0: WSL 2 installieren

Eine PowerShell mit Administrator-Rechten starten und die
Default-Linux-Installation, Ubuntu Linux, installieren:

```bash
wsl --install
```

Gegebenenfalls muss die WSL noch geupdated werden.

```bash
wsl.exe --update
```

Falls beim Update Schwierigkeiten auftreten, kann die neuste Version
(bitte identische Versionsnummer zu ``wsl.exe --version`` verwenden) auch aus
dem github heruntergeladen und die Installation repariert werden:
https://github.com/microsoft/WSL/releases/tag/2.6.1
(Download:
https://github.com/microsoft/WSL/releases/download/2.6.1/wsl.2.6.1.0.x64.msi)

Das Starten der WSL erfolgt z. B. via

```bash
wsl.exe -d Ubuntu
```

### Schritt 1: Linux aktualisieren

In der Ubuntu-Shell folgendes eingeben:

```shell
sudo apt-get update && sudo apt-get dist-upgrade
```

### Schritt 2: Benötigte Tools installieren

> [!NOTE]
> Getestet mit (Stand 12/2025):
> - Go 1.25.5,
> - KIND v0.30.0,
> - kubectl v1.34.x,
> - Terraform 1.14.1-6,
> - helm 3.19.2-1,
> - k9s v0.50.16.
>
> Bei anderen Versionen ggf. die Download-URLs bzw. Variablen anpassen.

#### Schritt 2.1: [jq](https://jqlang.org/), unzip und make installieren

In der Ubuntu-Shell Folgendes eingeben:

```shell
sudo apt-get install jq unzip make dnsutils
```

#### Schritt 2.2: [go](https://go.dev/) und [KIND](https://kind.sigs.k8s.io/) installieren

> [!NOTE]
> Die offizielle Anleitung für die Installation von [go](https://go.dev/)
> ist [hier](https://go.dev/doc/install) zu finden und kann auch gerne genutzt
> werden.
> Die offizielle Anleitung für die Installation
> von [KIND](https://kind.sigs.k8s.io/) ist
> [hier](https://kind.sigs.k8s.io/docs/user/quick-start/#installing-from-release-binaries)
> zu finden und kann auch gerne genutzt werden.

Empfohlene, getestete Versionen (Stand 12/2025): ``GO_VERSION=1.25.5`` und
``KIND_VERSION=v0.30.0``.

In der Ubuntu-Shell Folgendes eingeben:

```shell
GO_VERSION=1.25.5
KIND_VERSION=v0.30.0
cd /tmp
mkdir zeta-dev
cd zeta-dev
curl -Lo "./go.tar.gz" "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
sudo rm -rf /usr/local/go
sudo tar -C /usr/local -xzf go.tar.gz
export PATH="$PATH:/usr/local/go/bin"
grep -qx 'export PATH="$PATH:/usr/local/go/bin"' ~/.bashrc 2>/dev/null || echo 'export PATH="$PATH:/usr/local/go/bin"' >> ~/.bashrc
curl -Lo ./kind "https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-linux-amd64"
sudo mv ./kind /usr/local/bin/kind
chmod +x "/usr/local/bin/kind"
cd ..
rm -r zeta-dev
```

Um zu testen, ob beides richtig installiert ist, die folgenden Befehle
ausführen:

```shell
go version
kind --version
```

#### Schritt 2.3: [helm](https://helm.sh/) installieren

> [!NOTE]
> Die offizielle Anleitung für die Installation von [helm](https://helm.sh/)
> ist [hier](https://helm.sh/docs/intro/install/) zu finden und kann auch gerne
> genutzt werden.

In der Ubuntu-Shell Folgendes eingeben:

```shell
sudo apt-get install curl gpg apt-transport-https --yes
curl -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt-get update
sudo apt-get install helm
```

Um zu testen, ob helm richtig installiert ist, den folgenden Befehl ausführen:

```shell
helm version
```

#### Schritt 2.4: [terraform](https://developer.hashicorp.com/terraform) installieren

> [!NOTE]
> Die offizielle Anleitung für die Installation
> von [terraform](https://developer.hashicorp.com/terraform)
> ist [hier](https://developer.hashicorp.com/terraform/install) zu finden und
> kann auch gerne genutzt werden.

In der Ubuntu-Shell Folgendes eingeben:

```shell
wget -O - https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(grep -oP '(?<=UBUNTU_CODENAME=).*' /etc/os-release || lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update
sudo apt install terraform
```

Um zu testen, ob terraform richtig installiert ist, den folgenden Befehl
ausführen:

```shell
terraform version
```

#### Schritt 2.5: [k9s](https://k9scli.io/) installieren

> [!NOTE]
> Die offizielle Anleitung für die Installation
> von [k9s](https://k9scli.io/)
> ist [hier](https://k9scli.io/topics/install/) zu finden und
> kann auch gerne genutzt werden.

In der Ubuntu-Shell Folgendes eingeben:

```shell
K9S_VERSION=v0.50.16
wget "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
tar -xzf k9s_Linux_amd64.tar.gz
chmod +x k9s
sudo mv k9s /usr/local/bin/
rm k9s_Linux_amd64.tar.gz
```

Um zu testen, ob k9s richtig installiert ist, den folgenden Befehl
ausführen:

```shell
k9s version
```

#### Schritt 2.6: [kubectl](https://kubernetes.io/docs/tasks/tools/) installieren

> [!NOTE]
> Die offizielle Anleitung für die Installation von kubectl ist
> [hier](https://kubernetes.io/docs/tasks/tools/install-kubectl-linux/)
> zu finden und kann auch gerne genutzt werden.

In der Ubuntu-Shell Folgendes eingeben:

```shell
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
sudo chmod 644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo chmod 644 /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubectl
```

Um zu testen, ob kubectl richtig installiert ist, den folgenden Befehl
ausführen:

```shell
kubectl version --client
```

## Schritt 3: zeta-kind.com als localhost (127.0.0.1) in der wsl auflösen

localhost ``(127.0.0.1)`` soll als ``zeta-kind.com``
aufgelöst werden.
Dazu muss ein Eintrag in der Datei ``/etc/hosts`` in Ubuntu erfolgen.

Als Trennzeichen zwischen der IP-Adresse und dem Domain-Namen in der Datei
``hosts`` kann entweder ein Leerzeichen oder ein Tab verwendet werden.
Dies sollte konsistent innerhalb der Datei sein.

In der Ubuntu-Shell dafür Folgendes eingeben:

```shell
grep -q "zeta-kind.com" /etc/hosts || \
  echo -e "127.0.0.1\tzeta-kind.com" | sudo tee -a /etc/hosts
```

oder die Datei mit einem Editor bearbeiten:

```shell
sudo nano /etc/hosts
```

Danach prüfen:

```shell
getent hosts zeta-kind.com
```

## Schritt 4: IP-Adresse ermitteln und Windows bekanntgeben

In der Ubuntu-Shell Folgendes eingeben:

```shell
nslookup host.docker.internal
```

Die Ausgabe sieht ähnlich zu dem Folgenden aus:

```text
;; Got recursion not available from 10.255.255.254
Server:         10.255.255.256
Address:        10.255.255.256#44

Name:   host.docker.internal
Address: 192.168.40.10
;; Got recursion not available from 10.255.255.256
```

Die IP-Adresse ist demzufolge: ``192.168.40.10``

Die IP-Adresse mit Domain-Namen in Windows in
``C:\Windows\System32\Drivers\etc\hosts`` eintragen:

> [!NOTE]
> Um dies zu tun braucht man Administratorrechte. Nach einem Neustart von WSL
> ändert sich die IP häufig; daher Schritt 4 bei Bedarf wiederholen.

```text
192.168.40.10 zeta-kind.com
```

Danach in Windows prüfen (als Administrator-Eingabeaufforderung oder
PowerShell):

```bash
ping zeta-kind.com
```

## Schritt 5: Cluster konfigurieren und starten

### Schritt 5.1: Repository clonen

Es wird [git](https://git-scm.com/) unter Windows benutzt.

Unter Windows in einem Terminal in das Projektverzeichnis wechseln und das
helm-Repository clonen:

```shell
cd C:\Users\username\Projects\ZETA\git-zeta
```

Beispiel (PowerShell, SSH oder HTTPS je nach Host):

```shell
$env:GIT_URL="https://github.com/gematik/zeta-guard-helm.git"
git clone $env:GIT_URL
```

Beispiel (Git Bash):

```bash
GIT_URL=https://github.com/gematik/zeta-guard-helm.git
git clone "$GIT_URL"
```

> [!NOTE]
> Bitte das README.md aus dem zeta-guard-helm Repository beachten! Insbesondere 
> die Warnungen zu unsicheren Services und die Hinweise zum base64 
> encodierten SM(C)-B Keystore.


### Schritt 5.2: Keystore und Passwort setzen

Den Keystore und das zugehörige Passwort in einem Verzeichnis parallel zum
zeta-guard-helm Verzeichnis ablegen entpacken.
Dann in Ubuntu die folgenden Umgebungsvariablen setzen:

```shell
export SMB_KEYSTORE_PW_FILE=../help/pdp-keystore-pass
export SMB_KEYSTORE_FILE_B64=../help/pdp-keystore.b64
```

Falls die Dateien direkt neben dem Repository liegen, können die relativen Pfade
oben genutzt werden. Liegen sie außerhalb des Repos, absolute Pfade verwenden
und auf ``chmod 600`` setzen:

```shell
export SMB_KEYSTORE_PW_FILE=/pfad/zum/keystore/pdp-keystore-pass
export SMB_KEYSTORE_FILE_B64=/pfad/zum/keystore/pdp-keystore.b64
```

Diese Exports könne auch in die ``~/.bashrc`` hinterlegt werden,
damit die Exports nicht in jeder neuen Bash neu ausgeführt werden müssen.

### Schritt 5.3 Cluster bauen

> [!NOTE]
> Für diesen Schritt muss Docker Desktop laufen.

In der Ubuntu-Shell in den Ordner vom zeta-guard-helm Repository navigieren und
Folgendes eingeben:

```shell
kind delete cluster --name zeta-local
kind create cluster --config kind-local.yaml
kubectl get namespace zeta-local >/dev/null 2>&1 || kubectl create namespace zeta-local
```

> [!NOTE]
> In ``kind-local.yaml`` sollte der Clustername ``zeta-local`` sein, damit
> Delete/Create und der Kontext in Schritt 5.6 zusammenpassen.
> Falls ein anderer Name verwendet wird, Befehle entsprechend anpassen.

### Schritt 5.4: Docker Secret für die Registry erstellen

In der Ubuntu-Shell folgendes eingeben, dabei docker password (...) und docker
email (username@domain) im Aufruf anpassen:

```shell
kubectl create secret docker-registry gitlab-registry-credentials-zeta-group \
  --docker-server=REGISTRY_URL \
  --docker-username="$(cat /pfad/zum/token-username)" \
  --docker-password="$(cat /pfad/zum/token)" \
  --docker-email=username@domain -n zeta-local
kubectl -n zeta-local create secret generic opa-bearer \
  --from-literal=token="$(cat /pfad/zum/token-username):$(cat /pfad/zum/token)"
```

> [!NOTE]
> Token und Keystore-Dateien nicht ins Repo legen; mit restriktiven Rechten (
``chmod 600``)
> speichern. Die Nutzung von ``$(cat ...)`` verhindert, dass Passwörter in der
> Shell-History landen.

### Schritt 5.5: Komponenten aus der Registry ziehen

In der Ubuntu-Shell Folgendes eingeben:

```shell
make clean deploy stage=local
```

Der Befehl sollte Folgendes zurückgeben:

```text
Thank you for installing zeta-testenv.

Your Fachdienst is at

    https://zeta-kind.com/pep/

and your administration frontend is at

    zeta-kind.com/auth
```

In der Ubuntu-Shell Folgendes eingeben:

```shell
make config stage=local
```

Der Befehl sollte Folgendes zurückgeben:

```text
Apply complete! Resources: 15 added, 0 changed, 0 destroyed.
Outputs:

pdp_supported_optional_scopes = toset([
  "zero:audience",
  "zero:manage",
  "zero:read",
  "zero:register",
  "zero:update",
  "zero:write",
])
pdp_token_signing_algorithm = "ES256"
policy_deletion_results = tomap({
  "Consent Required" = "Consent Required Policy deleted successfully."
  "Max Clients Limit" = "Max Clients Limit Policy deleted successfully."
  "Trusted Hosts" = "Trusted Hosts Policy deleted successfully."
})
```

### Schritt 5.6: Cluster-Status prüfen

Vor dem Aufruf der Web-URLs sicherstellen, dass der richtige kubectl-Kontext
gesetzt
ist und die Pods laufen:

```shell
kubectl config get-contexts
kubectl config use-context kind-zeta-local  # bei anderem Clusternamen Kontext anpassen
kubectl get nodes
kubectl get pods -n zeta-local
```

Alle Pods sollten im Status ``Running`` oder ``Completed`` sein.

## Schritt 6: Deployment verifizieren

Nun zur Verifikation mit folgende URLs im Browser den Tiger Proxy öffnen und
eine Resource Abfrage über den Testtreiber (ZETA-Client) durchführen:

```text
# Tiger Proxy
http://zeta-kind.com:9999
# Tiger Testsuite
http://zeta-kind.com:9010
# Reset Zeta-Client
https://zeta-kind.com/testdriver-api/reset
# Resource Abfrage über Zeta Guard
https://zeta-kind.com/proxy/achelos_testfachdienst/hellozeta
```

> [!NOTE]
> Die Zertifikate sind ggf. selbstsigniert; Browser-Warnungen sind daher
> erwartbar.
> Warnung bestätigen/Umweg wählen, um die Seiten aufzurufen.
