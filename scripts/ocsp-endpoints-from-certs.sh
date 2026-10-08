#!/usr/bin/env bash
#
# ocsp-endpoints-from-certs.sh
#
# Liest die OCSP-Responder aus der AIA-Extension echter Endnutzer-Zertifikate
# und gibt sie als Endpunkt-Fragment im Format `zeta.gematik.de/v1
# EgressTargets` aus (siehe src/schemas/egress-targets.yaml).
#
# WARUM ENDNUTZER-ZERTIFIKATE:
#   Nach RFC 5280 4.2.2.1 benennt id-ad-ocsp den Responder FUER DIESES
#   Zertifikat. Nur das Zertifikat, dessen Status geprueft werden soll, traegt
#   also die richtige URL. Ein CA-Zertifikat verweist eine Ebene hoeher.
#
#   Beleg aus diesem Repository:
#     Endnutzer  "ZETA PIP/PAP Freigeber"  (Aussteller GEM.KOMP-CA8)
#       -> http://download.crl.ti-dienste.de/ocsp/ec     <- die gesuchte URL
#     CA         GEM.KOMP-CA8              (Aussteller GEM.RCA7)
#       -> http://ocsp.root-ca.ti-dienste.de/ocsp        <- eine Ebene hoeher
#
#   Fuer SMC-B gilt dasselbe: massgeblich ist die AIA des Karten-Zertifikats.
#   Die TSL ist als Quelle NICHT geeignet - ihre ServiceSupplyPoints verweisen
#   ins TI-Zentralnetz oder sind Platzhalter, und die CA-Zertifikate tragen
#   ausnahmslos die Root-CA-URL.
#
# WOHER DIE ZERTIFIKATE KOMMEN:
#   Je TSP mindestens ein Referenz-Zertifikat aus dem Zulassungsverfahren.
#   Dieses Skript verifiziert damit die Angabe des TSP - es ersetzt sie nicht.
#   Ein neu zugelassener TSP muss seinen Endpunkt benennen, bevor seine Karten
#   im Umlauf sind; bis dahin gibt es kein Zertifikat zum Auslesen.
#
# Verwendung:
#   ./ocsp-endpoints-from-certs.sh <cert|dir> [<cert|dir> ...]
#                                  [--key ocspSmcbTsp] [--strict]
#
#   --strict  Exit 1, wenn ein Zertifikat keine AIA traegt.
#
# Abhaengigkeiten: openssl, awk, sed
#
set -euo pipefail

KEY="ocspSmcbTsp"
PURPOSE="Im Internet erreichbare OCSP-Responder der zugelassenen SMC-B-TSP"
STRICT=0
INPUTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --key)     KEY="${2:?}"; shift 2 ;;
    --purpose) PURPOSE="${2:?}"; shift 2 ;;
    --strict)  STRICT=1; shift ;;
    -h|--help) sed -n '2,40p' "$0" | sed 's/^# \?//'; exit 0 ;;
    -*) echo "Unbekannte Option: $1" >&2; exit 2 ;;
    *)  INPUTS+=("$1"); shift ;;
  esac
done

[[ ${#INPUTS[@]} -gt 0 ]] || { echo "Usage: $0 <cert|dir> [...] [--key <kategorie>] [--strict]" >&2; exit 2; }
command -v openssl >/dev/null || { echo "openssl wird benoetigt" >&2; exit 2; }

WORK="$(mktemp -d)"; trap 'rm -rf "$WORK"' EXIT
: > "$WORK/rows.tsv"; : > "$WORK/noaia.txt"

read_cert() {
  local f="$1" info=""
  info="$(openssl x509 -in "$f" -noout -subject -issuer -ext authorityInfoAccess 2>/dev/null || true)"
  [[ -n "$info" ]] || info="$(openssl x509 -in "$f" -inform DER -noout -subject -issuer -ext authorityInfoAccess 2>/dev/null || true)"
  printf '%s' "$info"
}

while IFS= read -r f; do
  info="$(read_cert "$f")"
  if [[ -z "$info" ]]; then
    echo "WARNUNG: kein Zertifikat lesbar: $f" >&2
    continue
  fi

  subj="$(sed -n 's/^subject=//p' <<<"$info")"
  issuer="$(sed -n 's/^issuer=//p'  <<<"$info")"
  icn="$(sed 's/.*CN[ ]*=[ ]*//; s/,.*//' <<<"$issuer")"
  iorg="$(sed -n 's/.*[[:space:]]O[ ]*=[ ]*\([^,]*\).*/\1/p' <<<"$issuer")"
  uri="$(sed -n 's|.*OCSP - URI:\([^ ]*\).*|\1|p' <<<"$info" | head -1)"

  if [[ -z "$uri" ]]; then
    printf '%s\t%s\n' "$(basename "$f")" "$subj" >> "$WORK/noaia.txt"
    continue
  fi

  scheme="${uri%%://*}"; rest="${uri#*://}"
  hostport="${rest%%/*}"
  if [[ "$rest" == *"/"* ]]; then path="/${rest#*/}"; else path=""; fi
  host="${hostport%%:*}"
  if [[ "$hostport" == *:* ]]; then port="${hostport##*:}"
  elif [[ "$scheme" == "https" ]]; then port=443
  else port=80; fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$scheme" "$host" "$port" "$path" "$icn" "$iorg" >> "$WORK/rows.tsv"
done < <(
  for p in "${INPUTS[@]}"; do
    if [[ -d "$p" ]]; then find "$p" -type f \( -name '*.pem' -o -name '*.crt' -o -name '*.cer' -o -name '*.der' \)
    else printf '%s\n' "$p"; fi
  done
)

[[ -s "$WORK/rows.tsv" ]] || { echo "Keine AIA-Eintraege gefunden." >&2; exit 1; }

{
  echo "# Generiert von scripts/ocsp-endpoints-from-certs.sh"
  echo "# Quelle: AIA-Extension von $(wc -l < "$WORK/rows.tsv") Endnutzer-Zertifikat(en)"
  echo "- key: ${KEY}"
  echo "  purpose: ${PURPOSE}"
  echo "  owner: tsp"
  echo "  stability: stable"
  echo "  consumers: [authserver, pep-proxy]"
  echo "  endpoints:"
  awk -F'\t' '
    {
      k = $1 "\t" $2 "\t" $3 "\t" $4
      if (!(k in seen)) { seen[k] = 1; order[++n] = k }
      if (!((k SUBSEP $5) in ca)) { ca[k, $5] = 1; cas[k] = cas[k] ((cas[k]=="") ? "" : "\n") $5 }
      if ($6 != "") org[k] = $6
    }
    END {
      for (i = 1; i <= n; i++) {
        split(order[i], p, "\t")
        printf "    - fqdn: %s\n", p[2]
        printf "      port: %s\n", p[3]
        printf "      protocol: %s\n", (p[1] == "https") ? "OCSP/HTTPS" : "OCSP/HTTP"
        if (p[4] != "") printf "      path: %s\n", p[4]
        printf "      source: cert-aia\n"
        if (org[order[i]] != "") printf "      tsp: \"%s\"\n", org[order[i]]
        printf "      servesCa:\n"
        m = split(cas[order[i]], c, "\n")
        for (j = 1; j <= m; j++) printf "        - \"%s\"\n", c[j]
      }
    }' "$WORK/rows.tsv"
}

if [[ -s "$WORK/noaia.txt" ]]; then
  {
    echo
    echo "Zertifikate ohne AIA-Extension - kein Responder ableitbar:"
    awk -F'\t' '{printf "  - %s  (%s)\n", $1, $2}' "$WORK/noaia.txt"
    echo "  Diese Endpunkte MUESSEN vom TSP benannt und mit 'source: declared'"
    echo "  ergaenzt werden."
  } >&2
  [[ "$STRICT" -eq 0 ]] || exit 1
fi
