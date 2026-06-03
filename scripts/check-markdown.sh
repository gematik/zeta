#!/usr/bin/env bash
#
# check-markdown.sh
#
# Prüft die Qualität eines Markdown-Dokuments:
#   1. Erreichbarkeit aller Links (intern + extern)
#   2. Existenz referenzierter Bilder
#   3. Optional: Lint-Regeln via markdownlint-cli2
#   4. Optional: Rechtschreibung via cspell
#
# Verwendung:
#   ./check-markdown.sh <pfad/zu/datei.md> [weitere.md ...]
#   ./check-markdown.sh docs/                # rekursiv über Verzeichnis
#
# Abhängigkeiten (optional, werden übersprungen falls nicht vorhanden):
#   - lychee            (Link-Checker, schnell, in Rust)   https://github.com/lycheeverse/lychee
#   - markdown-link-check (Fallback, Node.js)
#   - markdownlint-cli2 (Style/Struktur)
#   - cspell            (Rechtschreibung)
#
set -euo pipefail

# Pfad zu diesem Script und zur cspell-Konfig (liegt daneben)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CSPELL_CONFIG="${SCRIPT_DIR}/cspell.json"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

log()  { printf "${BLUE}[INFO]${NC} %s\n" "$*"; }
ok()   { printf "${GREEN}[ OK ]${NC} %s\n" "$*"; }
warn() { printf "${YELLOW}[WARN]${NC} %s\n" "$*"; }
err()  { printf "${RED}[FAIL]${NC} %s\n" "$*"; }

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <file-or-dir.md> [more ...]"
  exit 2
fi

# Dateien sammeln
TARGETS=()
for arg in "$@"; do
  if [[ -d "$arg" ]]; then
    while IFS= read -r -d '' f; do TARGETS+=("$f"); done \
      < <(find "$arg" -type f -name '*.md' -print0)
  elif [[ -f "$arg" ]]; then
    TARGETS+=("$arg")
  else
    warn "Pfad existiert nicht: $arg"
  fi
done

if [[ ${#TARGETS[@]} -eq 0 ]]; then
  err "Keine Markdown-Dateien gefunden."
  exit 2
fi

log "Prüfe ${#TARGETS[@]} Markdown-Datei(en)."

EXIT_CODE=0

# ---------------------------------------------------------------------------
# 1) Link-Check
# ---------------------------------------------------------------------------
if command -v lychee >/dev/null 2>&1; then
  log "Link-Check mit lychee ..."
  if lychee --no-progress --max-concurrency 8 "${TARGETS[@]}"; then
    ok "Alle Links erreichbar."
  else
    err "Defekte Links gefunden."
    EXIT_CODE=1
  fi
elif command -v markdown-link-check >/dev/null 2>&1; then
  log "Link-Check mit markdown-link-check ..."
  for f in "${TARGETS[@]}"; do
    if ! markdown-link-check -q "$f"; then
      err "Defekte Links in $f"
      EXIT_CODE=1
    fi
  done
else
  warn "Weder 'lychee' noch 'markdown-link-check' installiert – Link-Check übersprungen."
  warn "  Installation: cargo install lychee   ODER   npm i -g markdown-link-check"
fi

# ---------------------------------------------------------------------------
# 2) Referenzierte Bilder & relative Pfade prüfen
# ---------------------------------------------------------------------------
log "Prüfe referenzierte lokale Dateien (Bilder, Includes) ..."
LOCAL_FAIL=0
for f in "${TARGETS[@]}"; do
  dir=$(dirname "$f")
  # Markdown-Bild- und Link-Syntax: ![alt](path)  bzw. [text](path)
  while IFS= read -r ref; do
    # Externe URLs, Anker und mailto überspringen
    case "$ref" in
      http://*|https://*|mailto:*|"#"*|"") continue ;;
    esac
    # Anker am Ende abschneiden
    target="${ref%%#*}"
    [[ -z "$target" ]] && continue
    if [[ ! -e "$dir/$target" && ! -e "$target" ]]; then
      err "  $f: referenzierte Datei fehlt -> $ref"
      LOCAL_FAIL=1
    fi
  done < <(grep -oE '\]\(([^)]+)\)' "$f" | sed -E 's/^\]\((.*)\)$/\1/')
done
if [[ $LOCAL_FAIL -eq 0 ]]; then
  ok "Alle lokalen Referenzen vorhanden."
else
  EXIT_CODE=1
fi

# ---------------------------------------------------------------------------
# 3) Markdown-Lint (Style, Struktur, Heading-Hierarchie etc.)
# ---------------------------------------------------------------------------
if command -v markdownlint-cli2 >/dev/null 2>&1; then
  log "Markdown-Lint ..."
  if markdownlint-cli2 "${TARGETS[@]}"; then
    ok "Lint OK."
  else
    err "Lint-Verstöße gefunden."
    EXIT_CODE=1
  fi
else
  warn "markdownlint-cli2 nicht installiert – Lint übersprungen (npm i -g markdownlint-cli2)."
fi

# ---------------------------------------------------------------------------
# 4) Rechtschreibung
# ---------------------------------------------------------------------------
if command -v cspell >/dev/null 2>&1; then
  log "Rechtschreibprüfung mit cspell ..."
  if cspell --no-progress --config "$CSPELL_CONFIG" "${TARGETS[@]}"; then
    ok "Keine Rechtschreibfehler."
  else
    warn "Mögliche Rechtschreibfehler gefunden."
    # Rechtschreibung nur als Warnung, kein Exit-Fehler
  fi
else
  warn "cspell nicht installiert – Rechtschreibprüfung übersprungen (npm i -g cspell @cspell/dict-de-de)."
fi

echo
if [[ $EXIT_CODE -eq 0 ]]; then
  ok "Alle Pflicht-Checks bestanden."
else
  err "Mindestens ein Check fehlgeschlagen."
fi
exit $EXIT_CODE
