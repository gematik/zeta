#!/usr/bin/env bash
#
# check-schemas.sh
#
# Prüft die Schemas und OpenAPI-Dateien dieses Repos:
#   1. Metaschema-Prüfung aller src/schemas/*.yaml          (check-jsonschema)
#   2. Beispiele examples/schemas/<name>/*.json gegen
#      src/schemas/<name>.yaml, dazu das AS-Well-known-Beispiel
#   3. OpenAPI-Lint nach redocly.yaml                       (redocly)
#
# Verwendung:
#   ./scripts/check-schemas.sh [-q]
#     -q   nur Fehler und Zusammenfassung ausgeben
#
# Voraussetzungen:
#   pipx install check-jsonschema
#   npm install -g @redocly/cli
#
# Bekannt ungültige Beispiele stehen in KNOWN_INVALID. Sie werden gemeldet,
# zählen aber nicht als Fehler. Wird eines gültig, weist das Skript darauf hin.
#
# Exit-Code: 0 = in Ordnung, 1 = Fehler, 2 = Werkzeug fehlt.
set -u

KNOWN_INVALID=()

QUIET=0
[ "${1:-}" = "-q" ] && QUIET=1

for tool in check-jsonschema redocly; do
  command -v "$tool" >/dev/null 2>&1 || { echo "FEHLT: $tool ist nicht installiert (siehe Kopf dieses Skripts)"; exit 2; }
done
cd "$(dirname "$0")/.." || exit 2

errors=0; known=0
say() { [ "$QUIET" = 1 ] || echo "$@"; }
is_known() { local f; for f in "${KNOWN_INVALID[@]}"; do [ "$f" = "$1" ] && return 0; done; return 1; }

echo "== 1. Metaschema (src/schemas/*.yaml)"
if out=$(check-jsonschema --check-metaschema src/schemas/*.yaml 2>&1); then
  say "   ok ($(ls src/schemas/*.yaml | wc -l) Schemas)"
else
  echo "$out" | sed 's/^/   /'; errors=$((errors+1))
fi

echo "== 2. Beispiele"
check_example() {   # <schema> <beispiel>
  local out
  if out=$(check-jsonschema --schemafile "$1" "$2" 2>&1); then
    if is_known "$2"; then echo "   HINWEIS: $2 ist jetzt gültig – aus KNOWN_INVALID streichen"; else say "   ok   $2"; fi
  elif is_known "$2"; then
    known=$((known+1)); say "   bekannt ungültig: $2"
  else
    errors=$((errors+1)); echo "   FEHLER $2"; echo "$out" | grep -v "^Schema validation errors" | sed 's/^/          /' | head -8
  fi
}
for dir in examples/schemas/*/; do
  name=$(basename "$dir"); schema="src/schemas/$name.yaml"
  if [ ! -f "$schema" ]; then say "   übersprungen: $dir (kein Schema $schema)"; continue; fi
  for ex in "$dir"*.json; do [ -e "$ex" ] && check_example "$schema" "$ex"; done
done
wk="examples/discovery-and-configuration/05-oauth-authorization-server-well-known-response.json"
[ -f "$wk" ] && check_example src/schemas/as-well-known.yaml "$wk"

echo "== 3. OpenAPI-Lint (redocly.yaml)"
out=$(redocly lint 2>&1); rc=$?
summary=$(echo "$out" | grep -E "Validation failed|You have [0-9]+ warning|valid\." | tail -2 | tr '\n' ' ')
if [ $rc -ne 0 ]; then
  errors=$((errors+1)); echo "$out" | grep -B12 "Error was generated" | sed 's/^/   /'; echo "   FEHLER $summary"
else
  say "   ok   $summary"
fi

echo "== Ergebnis: $errors Fehler, $known bekannt ungültige Beispiele"
[ "$errors" -eq 0 ]
