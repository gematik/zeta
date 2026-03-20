#!/bin/bash
set -e
set -o pipefail

# --- Konfiguration (Hier einmalig anpassen) ---
REGION="europe-west3"
IMAGE_AUTHOR="gematik"

# --- Farben für die Ausgabe ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Hilfefunktion (Usage) ---
usage() {
    echo -e "${BLUE}Buildah Provisioning Data Builder & OCI Pusher${NC}"
    echo "Baut ein reines OCI-Daten-Image, fügt Metadaten hinzu und pusht es in die GCP Artifact Registry."
    echo ""
    echo -e "Verwendung: ${GREEN}$0 <imagename:tag> [daten_verzeichnis]${NC}"
    echo ""
    echo "Parameter:"
    echo "  <imagename:tag>      Pflicht: Name und Tag des Ziel-Images (ohne Region-Prefix)."
    echo "  [daten_verzeichnis]  Optional: Pfad zu dem Verzeichnis, das die Daten enthält."
    echo "                       Wird dies weggelassen, wird das aktuelle Verzeichnis ( . ) verwendet."
    echo ""
    echo "Beispiele:"
    echo "  $0 gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:test-latest"
    echo "  $0 gematik-pt-zeta-test/zeta-dcr/zeta-guard-provisioning:v1.2.3 ./my-data"
    echo ""
    exit 1
}

# --- Parameter Prüfung ---
if [ -z "$1" ] || [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
    usage
fi

IMAGE_TAG="$1"
# Zweiter Parameter ist das Verzeichnis, Fallback ist '.'
DATA_DIR="${2:-.}"
FULL_REPO="${REGION}-docker.pkg.dev/${IMAGE_TAG}"

# Prüfen, ob das angegebene Verzeichnis existiert
if [ ! -d "$DATA_DIR" ]; then
    echo -e "${RED}Fehler: Das Daten-Verzeichnis '$DATA_DIR' existiert nicht.${NC}"
    exit 1
fi

# Temporäres Staging-Verzeichnis erstellen und Aufräumen bei Skript-Ende sicherstellen
STAGING_DIR=$(mktemp -d)
trap 'echo -e "${BLUE}--- Aufräumen: Temporäres Verzeichnis wird gelöscht ---${NC}"; rm -rf "$STAGING_DIR"' EXIT

echo -e "${BLUE}--- 1. Authentifizierung bei GCP ---${NC}"
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}Fehler beim Abrufen des GCloud Tokens. Bitte 'gcloud auth login' ausführen.${NC}"
    exit 1
fi

echo "$ACCESS_TOKEN" | buildah login -u oauth2accesstoken --password-stdin "${REGION}-docker.pkg.dev"


echo -e "${BLUE}--- 2. Metadaten vorbereiten ---${NC}"
echo "Daten werden aus Verzeichnis kopiert: $DATA_DIR"
cp -r "$DATA_DIR"/* "$STAGING_DIR/"

# Git revision ermitteln und in Datei schreiben
git_revision=$(git -C "$DATA_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
echo "$git_revision" > "$STAGING_DIR/.revision"
echo "Git Revision: $git_revision"

# Manifest-Datei mit SHA256-Prüfsummen erstellen
echo "Erstelle .manifest Datei..."
(cd "$STAGING_DIR" && find . -type f -print0 | xargs -0 sha256sum) > "$STAGING_DIR/.manifest"


echo -e "${BLUE}--- 3. Buildah Image-Bau (from scratch) ---${NC}"
new_container=$(buildah from scratch)
echo "Temporärer Container erstellt: $new_container"

buildah copy "$new_container" "$STAGING_DIR/." .
echo "Daten und Metadaten in den Container kopiert."

buildah config --author "$IMAGE_AUTHOR" --label git_revision="$git_revision" "$new_container"
echo "Image-Metadaten gesetzt."

IMAGE_ID=$(buildah commit "$new_container" "$FULL_REPO")
echo "Image committed. Lokale ID: $IMAGE_ID"

buildah rm "$new_container"
echo "Temporärer Container gelöscht."


echo -e "${BLUE}--- 4. Buildah Push ---${NC}"
buildah push "$IMAGE_ID" "docker://${FULL_REPO}"

if [ $? -eq 0 ]; then
    echo "----------------------------------------------------"
    echo -e "${GREEN}Erfolg! Daten-Image wurde gebaut und gepusht.${NC}"
    echo -e "Registry-Pfad: ${GREEN}$FULL_REPO${NC}"
    echo -e "Image Digest: ${GREEN}$IMAGE_ID${NC}"
    echo "----------------------------------------------------"
    echo -e "${BLUE}So kannst du das Image inspizieren:${NC}"
    echo ""
    echo -e "  ${GREEN}skopeo inspect docker://$FULL_REPO${NC}"
    echo -e "  ${GREEN}buildah unshare"
    echo -e "  ${GREEN}buildah mount $(buildah from $FULL_REPO)${NC}"
    echo "----------------------------------------------------"
else
    echo -e "${RED}Fehler beim Pushen des Images mit Buildah.${NC}"
    exit 1
fi
