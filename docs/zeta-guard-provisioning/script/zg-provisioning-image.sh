#!/bin/bash
set -e
set -o pipefail

# --- Konfiguration (Hier einmalig anpassen) ---
REGION="europe-west3"
IMAGE_AUTHOR="gematik"

# --- NEU: Konfiguration für die Signatur ---
# Pfad zum privaten Schlüssel (PEM-Format)
SOURCE_PEM_KEY="/pfad/zu/ihrem/private_key.pem" 
# Pfad zum öffentlichen Zertifikat (PEM-Format)
SIGNING_CERT="/pfad/zu/ihrem/public_key.pem"
CERT_CHAIN="/pfad/zu/ihrem/ca-chain.pem"
# Zieldateien für die von cosign konvertierten Schlüssel
COSIGN_KEY_FILE="/pfad/zu/ihrem/import-cosign.key"
COSIGN_PUB_FILE="/pfad/zu/ihrem/import-cosign.pub"

# --- Farben für die Ausgabe ---
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# --- Hilfefunktion (Usage) ---
usage() {
    echo -e "${BLUE}Buildah Provisioning Data Builder & OCI Pusher (mit Signatur)${NC}"
    echo "Baut ein reines OCI-Daten-Image, fügt Metadaten hinzu und pusht es und signiert es anschließend mit cosign."
    echo ""
    echo -e "Verwendung: ${GREEN}$0 <imagename:tag> [daten_verzeichnis]${NC}"
    echo ""
    echo "Parameter:"
    echo "  <imagename:tag>      Pflicht: Name und Tag des Ziel-Images (ohne Region-Prefix)."
    echo "  [daten_verzeichnis]  Optional: Pfad zu dem Verzeichnis, das die Daten enthält."
    echo "                       Wird dies weggelassen, wird das aktuelle Verzeichnis ( . ) verwendet."
    echo ""
    echo "Beispiel:"
    echo "  $0 gematik-pt-zeta-test/zeta-provisioning/zeta-guard-provisioning:test-latest"
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

# Prüfen, ob Signatur-Schlüssel existieren
if [ ! -f "$SOURCE_PEM_KEY" ] || [ ! -f "$SIGNING_CERT" ]; then
    echo -e "${RED}Fehler: Signaturschlüssel oder Zertifikat nicht gefunden.${NC}"
    echo "Bitte passen Sie die Variablen SOURCE_PEM_KEY und SIGNING_CERT im Skript an."
    exit 1
fi

# Prüfen, ob die Cosign-Schlüssel existieren. Wenn nicht, importieren.
if [ ! -f "$COSIGN_KEY_FILE" ] || [ ! -f "$COSIGN_PUB_FILE" ]; then
    echo -e "${BLUE}Cosign-Schlüssel ('$COSIGN_KEY_FILE') nicht gefunden. Import wird gestartet...${NC}"
    # Cosign erzeugt die Dateien immer mit festem Namen im aktuellen Verzeichnis.
    # Wir fragen das Passwort interaktiv ab. Für CI/CD `export COSIGN_PASSWORD=...` verwenden.
    COSIGN_PASSWORD=""
    cosign import-key-pair --key "$SOURCE_PEM_KEY"
    
    # Umbenennen/Verschieben der erstellten Dateien an die konfigurierten Orte
    mv import-cosign.key "$COSIGN_KEY_FILE"
    mv import-cosign.pub "$COSIGN_PUB_FILE"
    echo -e "${GREEN}Schlüssel erfolgreich nach '$COSIGN_KEY_FILE' und '$COSIGN_PUB_FILE' importiert.${NC}"
else
    echo -e "${GREEN}Bestehende Cosign-Schlüssel gefunden. Import wird übersprungen.${NC}"
fi


# Temporäres Staging-Verzeichnis erstellen und Aufräumen bei Skript-Ende sicherstellen
STAGING_DIR=$(mktemp -d)
trap 'echo -e "${BLUE}--- Aufräumen: Temporäres Verzeichnis wird gelöscht ---${NC}"; rm -rf "$STAGING_DIR"' EXIT

echo -e "${BLUE}--- 1. Authentifizierung bei GCP ---${NC}"
ACCESS_TOKEN=$(gcloud auth print-access-token)
if [ -z "$ACCESS_TOKEN" ]; then
    echo -e "${RED}Fehler beim Abrufen des GCloud Tokens. Bitte 'gcloud auth login' ausführen.${NC}"; exit 1
fi
echo "$ACCESS_TOKEN" | buildah login -u oauth2accesstoken --password-stdin "${REGION}-docker.pkg.dev"


echo -e "${BLUE}--- 2. Metadaten vorbereiten ---${NC}"
echo "Daten werden aus Verzeichnis kopiert: $DATA_DIR"
cp -r "$DATA_DIR"/* "$STAGING_DIR/"

git_revision=$(git -C "$DATA_DIR" rev-parse HEAD 2>/dev/null || echo "unknown")
echo "$git_revision" > "$STAGING_DIR/.revision"
echo "Git Revision: $git_revision"

echo "Erstelle .manifest Datei..."
(cd "$STAGING_DIR" && find . -type f -print0 | xargs -0 sha256sum) > "$STAGING_DIR/.manifest"


echo -e "${BLUE}--- 3. Buildah Image-Bau (from scratch) ---${NC}"
new_container=$(buildah from scratch)
echo "Temporärer Container erstellt: $new_container"

buildah copy "$new_container" "$STAGING_DIR/." .
buildah config --author "$IMAGE_AUTHOR" --label git_revision="$git_revision" "$new_container"

# Wir speichern den Namen lokal, brauchen den Digest hier aber noch nicht zwingend
IMAGE_LOCAL_NAME="localhost/zg-temp-image:latest"
buildah commit "$new_container" "$IMAGE_LOCAL_NAME"
buildah rm "$new_container"

echo -e "${BLUE}--- 4. Buildah Push ---${NC}"
# eine temporäre Datei, um den ECHTEN Manifest-Digest zu erhalten
DIGEST_FILE=$(mktemp)
buildah push --digestfile "$DIGEST_FILE" "$IMAGE_LOCAL_NAME" "docker://${FULL_REPO}"

# Jetzt holen wir den Manifest-Digest (das ist der, den GCP auch anzeigt)
IMAGE_DIGEST=$(cat "$DIGEST_FILE")
rm "$DIGEST_FILE"

echo -e "${GREEN}Image erfolgreich gepusht. Manifest-Digest: $IMAGE_DIGEST${NC}"

# Schritt 5 - Image Signieren (Hier nutzt du nun den korrekten Manifest-Digest)
echo -e "${BLUE}--- 5. Image mit Cosign signieren ---${NC}"

# IMAGE_DIGEST enthält bereits das "sha256:..." Präfix durch die digestfile
cosign sign --key "$COSIGN_KEY_FILE" \
    --cert "$SIGNING_CERT" \
    --cert-chain "$CERT_CHAIN" \
    --tlog-upload=false \
    "${FULL_REPO}@${IMAGE_DIGEST}"

if [ $? -eq 0 ]; then
    echo "----------------------------------------------------"
    echo -e "${GREEN}Erfolg! Image gebaut, gepusht und signiert.${NC}"
    echo -e "Registry-Pfad: ${GREEN}$FULL_REPO${NC}"
    echo -e "Image Digest:  ${GREEN}$IMAGE_DIGEST${NC}"
    echo "----------------------------------------------------"
    echo -e "${BLUE}So kannst du das Image inspizieren:${NC}"
    echo ""
    echo -e "  ${GREEN}skopeo inspect docker://$FULL_REPO${NC}"
    echo -e "  ${GREEN}buildah unshare"
    echo -e "  ${GREEN}buildah mount $(buildah from $FULL_REPO)${NC}"
    echo "----------------------------------------------------"
    echo -e "${BLUE}So kannst du die Signatur überprüfen:${NC}"
    echo ""
    echo -e "  ${GREEN}cosign verify \\"
    echo -e "    --certificate $SIGNING_CERT \\"
    echo -e "    --certificate-chain $CERT_CHAIN \\"
    echo -e "    --certificate-identity \"software-development@gematik.de\" \\"
    echo -e "    --certificate-oidc-issuer-regexp \".*\" \\"
    echo -e "    --insecure-ignore-tlog \\"
    echo -e "    --insecure-ignore-sct \\"
    echo -e "    ${FULL_REPO}@${IMAGE_DIGEST}${NC}"
    echo "----------------------------------------------------"
else
    echo -e "${RED}Fehler beim Signieren des Images mit Cosign.${NC}"
    exit 1
fi