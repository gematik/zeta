#!/usr/bin/env bash
#
# check-afo-refs.sh – Afo-Verweise im Repo gegen einen gemSpec-Stand prüfen.
#
# Verwendung: scripts/check-afo-refs.sh [-v] [<stand-verzeichnis>] [pfad ...]
#   -v                   auch VORSCHLAG-Treffer ausgeben
#   <stand-verzeichnis>  Ordner mit AFOS.md, z. B. tmp/gemSpec_ZETA/gemSpec_ZETA_2.0.1_CC_1757236
#                        (Standard: neuester Stand mit AFOS.md)
#   pfad                 Standard: src docs examples
#
# Meldet je Verweis:
#   FEHLT     ID (Stamm) gibt es im Stand nicht
#   VERALTET  Stamm existiert mit höherem Suffix (Repo zitiert alte Fassung)
#   VORSCHLAG Repo-Suffix höher als im Stand (Änderungsvorschlag, z. B. A_30189-01);
#             zählt nicht als Befund, mit -v ausgeben
#   A_NEU/A_KEK-Entwürfe werden ignoriert.
# Exit-Code: 0 = keine Befunde, 1 = Befunde, 2 = Stand nicht gefunden.
set -u
cd "$(git rev-parse --show-toplevel)" || exit 2

verbose=0; [ "${1:-}" = "-v" ] && { verbose=1; shift; }
if [ -n "${1:-}" ] && [ -f "$1/AFOS.md" ]; then
  stand=${1%/}; shift
else
  stand=$(for d in tmp/gemSpec_ZETA/*/; do [ -f "$d/AFOS.md" ] && echo "${d%/}"; done | sort -V | tail -1)
fi
[ -f "$stand/AFOS.md" ] || { echo "Stand ohne AFOS.md: $stand"; exit 2; }
paths=("$@"); [ ${#paths[@]} -eq 0 ] && paths=(src docs examples)

# Bestand: volle IDs des Stands
known=$(grep -oE '^A_[0-9]{5}(-[0-9]{2})?' "$stand/AFOS.md" | sort -u)

suffix() { case $1 in *-*) echo $((10#${1##*-}));; *) echo 0;; esac; }
found=0; proposals=0
while IFS=: read -r file line id; do
  stem=${id%%-*}
  grep -qx "$id" <<<"$known" && continue
  current=$(grep -E "^${stem}(-[0-9]{2})?$" <<<"$known" | tr '\n' ' ')
  if [ -z "$current" ]; then
    echo "FEHLT     $id  $file:$line"
    found=$((found+1))
  else
    max=0; for c in $current; do n=$(suffix "$c"); [ "$n" -gt "$max" ] && max=$n; done
    if [ "$(suffix "$id")" -gt "$max" ]; then
      proposals=$((proposals+1))
      [ "$verbose" = 1 ] && echo "VORSCHLAG $id (Stand: ${current% })  $file:$line"
    else
      echo "VERALTET  $id → ${current% }  $file:$line"; found=$((found+1))
    fi
  fi
done < <(grep -rnoE '\bA_[0-9]{5}(-[0-9]{2})?\b' "${paths[@]}" \
           --include='*.yaml' --include='*.yml' --include='*.json' --include='*.md' \
           --include='*.puml' --include='*.proto' --include='*.rego' 2>/dev/null \
         | grep -v '/ReleaseNotes/' | sort -u)

echo "== Stand: $(basename "$stand"); Befunde: $found; Vorschläge (nicht gezählt): $proposals"
[ "$found" -eq 0 ]
