#!/usr/bin/env bash
#
# check-egress-coverage.sh
#
# Prueft, ob eine EgressTargets-Liste alle SMC-B-CAs abdeckt, die in einer TSL
# gefuehrt sind.
#
# ROLLE DER TSL:
#   Die TSL ist NICHT die Quelle der OCSP-Endpunkte - ihre ServiceSupplyPoints
#   verweisen ins TI-Zentralnetz oder sind Platzhalter, und die AIA der
#   CA-Zertifikate benennt den Root-CA-Responder, nicht den der Karten.
#
#   Die TSL ist aber die autoritative Quelle fuer die GRUNDGESAMTHEIT: sie sagt
#   verbindlich, welche SMC-B-CAs zugelassen sind. Genau dafuer wird sie hier
#   verwendet - als Vollstaendigkeitspruefung gegen eine Liste, deren URLs aus
#   einer anderen Quelle stammen (Benennung durch den TSP, verifiziert an einem
#   Referenz-Zertifikat).
#
#   Damit ist die Aufgabenteilung sauber:
#     TSL          -> WELCHE CAs muessen abgedeckt sein
#     Zertifikat / -> WELCHE URL gehoert dazu
#     TSP-Angabe
#
# Verwendung:
#   ./check-egress-coverage.sh <targets.yaml> <tsl.xml> [--class SMCB] [--strict]
#
# Abhaengigkeiten: yq, openssl (nur fuer die TSL-Auswertung nicht noetig), awk, sed
#
set -euo pipefail

CLASS="SMCB"
STRICT=0
TARGETS=""
TSL=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --class)   CLASS="${2:?}"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) sed -n '2,26p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unbekannte Option: $1" >&2; exit 2 ;;
    *)  if [[ -z "$TARGETS" ]]; then TARGETS="$1"; else TSL="$1"; fi; shift ;;
  esac
done

[[ -n "$TARGETS" && -n "$TSL" ]] || { echo "Usage: $0 <targets.yaml> <tsl.xml> [--class SMCB] [--strict]" >&2; exit 2; }
[[ -r "$TARGETS" ]] || { echo "Liste nicht lesbar: $TARGETS" >&2; exit 2; }
[[ -r "$TSL" ]]     || { echo "TSL nicht lesbar: $TSL" >&2; exit 2; }
command -v yq >/dev/null || { echo "yq wird benoetigt" >&2; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT

# Grundgesamtheit aus der TSL: CN aller CAs dieser Klasse.
tr -d '\n\r' < "$TSL" \
  | sed 's/>[[:space:]]\+</></g' \
  | sed 's|<TSPService>|\n<TSPService>|g' \
  | grep '^<TSPService>' \
  | grep 'Svctype/CA/PKC' \
  | sed 's|.*<ServiceName><Name[^>]*>||; s|</Name>.*||' \
  | grep "\.${CLASS}-CA" \
  | sed 's|^CN=||; s|,.*||' \
  | sort -u > "$WORK/required.txt"

SEQ="$(tr -d '\n\r' < "$TSL" | sed -n 's|.*<TSLSequenceNumber>\([0-9]\+\)</TSLSequenceNumber>.*|\1|p' | head -1)"

# Abdeckung aus der Liste: alle servesCa-Eintraege ueber alle Endpunkte.
yq -r '[.targets[].endpoints[]? | select(has("servesCa")) | .servesCa[]] | .[]' "$TARGETS" 2>/dev/null \
  | sort -u > "$WORK/covered.txt" || : > "$WORK/covered.txt"

comm -23 "$WORK/required.txt" "$WORK/covered.txt" > "$WORK/missing.txt"
comm -13 "$WORK/required.txt" "$WORK/covered.txt" > "$WORK/stale.txt"

TOTAL=$(wc -l < "$WORK/required.txt")
MISS=$(wc -l < "$WORK/missing.txt")
STALE=$(wc -l < "$WORK/stale.txt")

echo "Abdeckungspruefung ${CLASS} gegen TSL-Sequenz ${SEQ:-?}"
echo "  Liste:                    $(basename "$TARGETS")"
echo "  CAs in der TSL:           ${TOTAL}"
echo "  davon abgedeckt:          $(( TOTAL - MISS ))"
echo "  nicht abgedeckt:          ${MISS}"
echo "  in der Liste, nicht (mehr) in der TSL: ${STALE}"

if [[ "$MISS" -gt 0 ]]; then
  echo
  echo "NICHT ABGEDECKT - fuer diese CAs fehlt ein OCSP-Endpunkt. Karten dieser"
  echo "CAs werden bei aktivem Default-Deny-Egress abgelehnt:"
  sed 's/^/  - /' "$WORK/missing.txt"
fi

if [[ "$STALE" -gt 0 ]]; then
  echo
  echo "NICHT MEHR IN DER TSL - NICHT automatisch entfernen. Solange unter diesen"
  echo "CAs noch gueltige Karten im Umlauf sind, wird ihr Responder weiter"
  echo "gebraucht. Erst nach Ablauf der letzten Karte entfernen (validUntil):"
  sed 's/^/  - /' "$WORK/stale.txt"
fi

if [[ "$STRICT" -eq 1 && "$MISS" -gt 0 ]]; then
  echo >&2
  echo "--strict: ${MISS} CA(s) ohne Endpunkt." >&2
  exit 1
fi
