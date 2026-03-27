#!/bin/bash

# --- Konfiguration (Hier einmalig anpassen) ---
REGION="europe-west3"
SIGNING_KEY="/home/cp/pip-pap-keys/zeta_artifact_reg_nist.prv.pem"
SIGNING_ALG="ES256"
OCI_STORE="$HOME/.policy/policies-root"

# --- Farben für die Ausgabe ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Hilfefunktion (Usage) ---
usage() {
    echo -e "${BLUE}Opa Bundle Builder & OCI Pusher${NC}"
    echo "Baut ein OPA Bundle, signiert es und pusht es als OCI Container."
    echo ""
    echo -e "Verwendung: ${GREEN}$0 <imagename:tag>[policy_verzeichnis]${NC}"
    echo ""
    echo "Parameter:"
    echo "  <imagename:tag>      Pflicht: Name und Tag des Ziel-Images (ohne Region-Prefix)."
    echo "  [policy_verzeichnis] Optional: Pfad zu dem Verzeichnis, das die Policies enthält."
    echo "                       Wird dies weggelassen, wird das aktuelle Verzeichnis ( . ) verwendet."
    echo ""
    echo "Beispiele:"
    echo "  $0 gematik-pt-zeta-test/zeta-policies-dev/test-fachdienst-policy:latest"
    echo "  $0 gematik-pt-zeta-test/zeta-policies-dev/test-fachdienst-policy:latest ./my-policies"
    echo ""
    exit 1
}

# --- Parameter Prüfung ---
if [ -z "$1" ] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

IMAGE_TAG="$1"
# Zweiter Parameter ist das Verzeichnis, Fallback ist '.'
POLICY_DIR="${2:-.}" 
FULL_REPO="${REGION}-docker.pkg.dev/${IMAGE_TAG}"

# Prüfen, ob das angegebene Verzeichnis existiert
if [ ! -d "$POLICY_DIR" ]; then
    echo -e "${RED}Fehler: Das Verzeichnis '$POLICY_DIR' existiert nicht.${NC}"
    exit 1
fi

echo -e "${BLUE}--- 1. Authentifizierung ---${NC}"
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ $? -ne 0 ]; then 
    echo -e "${RED}Fehler beim Abrufen des GCloud Tokens${NC}"
    exit 1
fi

policy login --username=oauth2accesstoken --server="${REGION}-docker.pkg.dev" --password="$ACCESS_TOKEN"


echo -e "${BLUE}--- 2. Policy Build & Sign ---${NC}"
echo "Verwende Policy-Verzeichnis: $POLICY_DIR"

# Die git revision wird im Zielverzeichnis abgefragt und beim Build eingetragen
git_revision=$(git -C "$POLICY_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
echo "Git Revision: $git_revision"

# Wir fangen die Ausgabe des Befehls in einer Variablen ab
BUILD_LOG=$(policy build "$POLICY_DIR" --signing-key="$SIGNING_KEY" --signing-alg="$SIGNING_ALG" --revision="$git_revision" -t "$FULL_REPO")

# Ausgabe zur Kontrolle auch im Terminal anzeigen
echo "$BUILD_LOG"


echo -e "${BLUE}--- 3. Digest extrahieren ---${NC}"
# Wir suchen die Zeile, die mit "digest:" beginnt und nehmen das zweite Wort
DIGEST=$(echo "$BUILD_LOG" | grep "digest:" | awk '{print $2}')

if [ -z "$DIGEST" ]; then
    echo -e "${RED}Fehler: Digest konnte nicht aus der 'policy build' Ausgabe extrahiert werden.${NC}"
    exit 1
fi
echo "Extrahierter Digest: $DIGEST"


echo -e "${BLUE}--- 4. Oras Push (Copy) ---${NC}"
# Wichtig: oras cp verwendet das OCI-Layout und den extrahierten Digest
oras cp --from-oci-layout "${OCI_STORE}@${DIGEST}" "$FULL_REPO"

if [ $? -eq 0 ]; then
    echo "----------------------------------------------------"
    echo -e "${GREEN}Erfolg! OPA Bundle wurde gebaut, signiert und gepusht.${NC}"
    echo -e "Registry-Pfad: ${GREEN}$FULL_REPO${NC}"
    echo "----------------------------------------------------"
    echo -e "${BLUE}So kannst du das Image wieder herunterladen und entpacken:${NC}"
    echo ""
    echo -e "  ${GREEN}mkdir test-bundle && cd test-bundle${NC}"
    echo -e "  ${GREEN}policy pull $FULL_REPO${NC}"
    echo -e "  ${GREEN}policy save ${IMAGE_TAG}"
    echo -e "  ${GREEN}tar -xzf bundle.tar.gz${NC}  # Dateiname kann variieren"
    echo ""
    echo "----------------------------------------------------"
else
    echo -e "${RED}Fehler beim Kopieren des Images mit ORAS.${NC}"
    exit 1
fi
