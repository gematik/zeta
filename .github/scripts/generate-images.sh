#!/usr/bin/env bash
# Generiert PNG- und SVG-Bilder aus PlantUML- und Draw.io-Quellen.
#
# Aufruf: generate-images.sh <puml-liste> <drawio-liste>
# Die Listendateien enthalten einen Quellpfad pro Zeile (relativ zum Repo-Root).
# Leere oder fehlende Listen überspringen den jeweiligen Teil; Pfade, die nicht
# (mehr) existieren, werden übersprungen.
#
# Wird vom Workflow "Automatic Image Generation" sowohl für die eigentliche
# Generierung als auch im Push-Retry (nach Reset auf den Origin-Stand) genutzt.
set -euo pipefail

PUML_LIST="${1:-}"
DRAWIO_LIST="${2:-}"

# Pipe-Modus (-p): Der Ausgabename ergibt sich aus dem Quelldateinamen. Im
# Datei-Modus würde PlantUML nach dem Namen in '@startuml <name>' benennen -
# der weicht in mehreren Dateien vom Dateinamen ab und ist nicht eindeutig.
generate_puml() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo "Skipping missing file: $file"
    return 0
  fi

  local file_dir file_name image_base output_dir
  file_dir=$(dirname "$file")
  file_name=$(basename "$file")
  image_base=$(basename "$file" .puml)
  output_dir="$PWD/$(sed 's|^src/plantuml|images|' <<< "$file_dir")"
  mkdir -p "$output_dir"

  echo "-> PlantUML: $file"
  # cd in einer Subshell, damit relative '!include'-Pfade aufgelöst werden;
  # die Ausgabepfade sind absolut.
  (cd "$file_dir" && java -jar /tmp/plantuml.jar -p -tpng -scale 4 -graphvizdot /usr/bin/dot < "$file_name" > "$output_dir/$image_base.png")
  (cd "$file_dir" && java -jar /tmp/plantuml.jar -p -tsvg -graphvizdot /usr/bin/dot < "$file_name" > "$output_dir/$image_base.svg")

  if [ ! -s "$output_dir/$image_base.png" ] || [ ! -s "$output_dir/$image_base.svg" ]; then
    echo "::error::Generation failed for $file - output files missing or empty."
    return 1
  fi
}
export -f generate_puml

if [ -n "$PUML_LIST" ] && [ -s "$PUML_LIST" ]; then
  # Dateien parallel generieren (eine Datei pro Kern). xargs bricht mit
  # Exit-Code != 0 ab, sobald eine Generierung fehlschlägt.
  xargs -a "$PUML_LIST" -d '\n' -r -P "$(nproc)" -I{} bash -euo pipefail -c 'generate_puml "$1"' _ {}
fi

if [ -n "$DRAWIO_LIST" ] && [ -s "$DRAWIO_LIST" ]; then
  while IFS= read -r file; do
    if [ ! -f "$file" ]; then
      echo "Skipping missing file: $file"
      continue
    fi

    output_dir="$(dirname "$file" | sed 's|^src/drawio|images|')"
    image_base=$(basename "$file" .drawio)
    mkdir -p "$output_dir"

    echo "-> Draw.io: $file"
    xvfb-run --auto-servernum drawio --no-sandbox --export --format png --scale 4 --output "$output_dir/$image_base.png" "$file"
    xvfb-run --auto-servernum drawio --no-sandbox --export --format svg --output "$output_dir/$image_base.svg" "$file"

    if [ ! -s "$output_dir/$image_base.png" ] || [ ! -s "$output_dir/$image_base.svg" ]; then
      echo "::error::Generation failed for $file - output files missing or empty."
      exit 1
    fi
  done < "$DRAWIO_LIST"
fi
