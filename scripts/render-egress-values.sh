#!/usr/bin/env bash
#
# render-egress-values.sh
#
# Erzeugt aus einer EgressTargets-Liste (FQDN + Port) die Helm-Values mit
# ipBlocks fuer die NetworkPolicies des ZETA Guard Charts.
#
# ARBEITSTEILUNG:
#   Die gematik liefert das WAS (FQDN, Port, Zweck) als signiertes OCI-Artefakt.
#   Dieses Skript beantwortet das WELCHE IP HEUTE - beim Betreiber, zum
#   Deployzeitpunkt, gegen dessen eigenen Resolver. Deshalb enthaelt die
#   gelieferte Liste keine IP-Adressen: sie waeren zum Zeitpunkt des Deployments
#   bereits potenziell falsch.
#
# Die Ausgabe ist verderblich. Sie gehoert in die Deploy-Pipeline, nicht
# dauerhaft in eine eingecheckte Values-Datei.
#
# Verwendung:
#   ./render-egress-values.sh <targets.yaml> [--format values|set|check]
#                             [--key <kategorie>] [--resolver <ip>]
#
#   values  (Standard)  YAML-Fragment fuer values.yaml
#   set                 --set-Argumente fuer 'helm upgrade'
#   check                nur aufloesen und berichten, keine Values
#
# Abhaengigkeiten: yq, dig
#
set -euo pipefail

FORMAT="values"
FILTER=""
RESOLVER=""
SRC=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --format)   FORMAT="${2:?}"; shift 2 ;;
    --key)      FILTER="${2:?}"; shift 2 ;;
    --resolver) RESOLVER="${2:?}"; shift 2 ;;
    -h|--help)  sed -n '2,28p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unbekannte Option: $1" >&2; exit 2 ;;
    *)  SRC="$1"; shift ;;
  esac
done

[[ -n "$SRC" ]] || { echo "Usage: $0 <targets.yaml> [--format values|set|check]" >&2; exit 2; }
[[ -r "$SRC" ]] || { echo "Liste nicht lesbar: $SRC" >&2; exit 2; }
command -v yq  >/dev/null || { echo "yq wird benoetigt" >&2; exit 2; }
command -v dig >/dev/null || { echo "dig wird benoetigt" >&2; exit 2; }

STATUS="$(yq -r '.metadata.status // "unknown"' "$SRC")"
ENVIRONMENT="$(yq -r '.metadata.environment // "unknown"' "$SRC")"
EXPIRES="$(yq -r '.metadata.expiresAt // ""' "$SRC")"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

if [[ "$STATUS" != "normative" ]]; then
  echo "WARNUNG: metadata.status ist '${STATUS}', nicht 'normative'." >&2
  echo "         Diese Liste ist eine Formatdemonstration und darf nicht" >&2
  echo "         produktiv verwendet werden." >&2
fi

if [[ -n "$EXPIRES" && "$EXPIRES" < "$NOW" ]]; then
  echo "WARNUNG: Die Liste ist seit ${EXPIRES} abgelaufen. Neu beziehen." >&2
fi

# Zielzeilen einsammeln: key <TAB> fqdn <TAB> port
MAP="$(yq -r '
  .targets[]
  | select(.owner != "operator")
  | .key as $k
  | .endpoints[]
  | [$k, .fqdn, (.port|tostring)] | @tsv
' "$SRC")"

[[ -n "$FILTER" ]] && MAP="$(grep -P "^\Q${FILTER}\E\t" <<<"$MAP" || true)"
[[ -n "$MAP" ]] || { echo "Keine passenden Ziele gefunden." >&2; exit 1; }

DIGOPTS=(+short +time=3 +tries=2)
[[ -n "$RESOLVER" ]] && DIGOPTS+=("@${RESOLVER}")

declare -A BLOCKS
FAILED=0

while IFS=$'\t' read -r key fqdn port; do
  [[ -n "$fqdn" ]] || continue
  ips="$(dig "${DIGOPTS[@]}" A "$fqdn" 2>/dev/null | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' || true)"
  if [[ -z "$ips" ]]; then
    echo "FEHLER: ${fqdn} (Kategorie ${key}) nicht aufloesbar." >&2
    FAILED=$((FAILED + 1))
    continue
  fi
  while read -r ip; do
    [[ -n "$ip" ]] || continue
    entry="${ip}/32|${fqdn}:${port}"
    case " ${BLOCKS[$key]:-} " in
      *" $entry "*) ;;
      *) BLOCKS[$key]="${BLOCKS[$key]:-} $entry" ;;
    esac
  done <<<"$ips"
done <<<"$MAP"

if [[ "$FORMAT" == "check" ]]; then
  echo "Aufloesung gegen ${RESOLVER:-System-Resolver}, ${NOW}, Umgebung ${ENVIRONMENT}"
  for key in $(printf '%s\n' "${!BLOCKS[@]}" | sort); do
    echo "  ${key}:"
    for e in ${BLOCKS[$key]}; do printf '    %-20s %s\n' "${e%%|*}" "${e#*|}"; done
  done
  [[ "$FAILED" -eq 0 ]] || { echo "${FAILED} Ziel(e) nicht aufloesbar." >&2; exit 1; }
  exit 0
fi

if [[ "$FORMAT" == "set" ]]; then
  for key in $(printf '%s\n' "${!BLOCKS[@]}" | sort); do
    i=0
    for e in ${BLOCKS[$key]}; do
      printf -- '--set "zeta-guard.networkPolicy.egress.%s.ipBlocks[%d]=%s" ' "$key" "$i" "${e%%|*}"
      i=$((i + 1))
    done
  done
  echo
  [[ "$FAILED" -eq 0 ]] || exit 1
  exit 0
fi

# --format values
cat <<HEADER
# Generiert von scripts/render-egress-values.sh
# Quelle:     $(basename "$SRC")  (Umgebung ${ENVIRONMENT}, status ${STATUS})
# Aufgeloest: ${NOW} gegen ${RESOLVER:-System-Resolver}
#
# VERDERBLICH: Diese IP-Adressen sind eine Momentaufnahme. Sie gehoeren in die
# Deploy-Pipeline und werden bei jedem Deployment neu erzeugt. Eine
# eingecheckte Kopie veraltet unbemerkt und aeussert sich spaeter als
# Autorisierungsfehler, nicht als Netzwerkfehler.
zeta-guard:
  networkPolicy:
    enabled: true
    egress:
HEADER

for key in $(printf '%s\n' "${!BLOCKS[@]}" | sort); do
  if [[ "$key" == *.* ]]; then
    printf '      %s:\n        %s:\n          ipBlocks:\n' "${key%%.*}" "${key#*.}"
    indent="            "
  else
    printf '      %s:\n        ipBlocks:\n' "$key"
    indent="          "
  fi
  for e in ${BLOCKS[$key]}; do
    printf '%s- "%s"   # %s\n' "$indent" "${e%%|*}" "${e#*|}"
  done
done

[[ "$FAILED" -eq 0 ]] || { echo "Warnung: ${FAILED} Ziel(e) fehlen in der Ausgabe." >&2; exit 1; }
