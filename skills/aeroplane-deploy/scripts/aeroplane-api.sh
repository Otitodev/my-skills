#!/usr/bin/env sh
# Authenticated request to an Aeroplane control plane.
#
#   aeroplane-api.sh METHOD /api/path [json-body | @file.json]
#
# Reads AEROPLANE_URL and AEROPLANE_API_KEY from the environment. The key is
# never printed. Prints the response body to stdout. On an HTTP error it prints
# "HTTP <code>" to stderr and exits 1. Needs only curl.
set -eu

: "${AEROPLANE_URL:?Set AEROPLANE_URL, for example https://pilot.example.com}"
: "${AEROPLANE_API_KEY:?Set AEROPLANE_API_KEY (System Settings -> API Access in the dashboard)}"

if [ "$#" -lt 2 ]; then
  echo "usage: $0 METHOD /api/path [json-body | @file.json]" >&2
  exit 2
fi

method=$1
path=$2
body=${3-}

case "$path" in
  /api/*) ;;
  *) echo "Path must start with /api/" >&2; exit 2 ;;
esac

base=${AEROPLANE_URL%/}
case "$base" in
  https://*) ;;
  http://*)
    # Exact host match, so http://localhost.example.com is not treated as local.
    host=${base#http://}
    host=${host%%/*}
    host=${host%%:*}
    case "$host" in
      localhost|127.0.0.1) ;;
      *)
        if [ "${AEROPLANE_ALLOW_HTTP:-}" != "1" ]; then
          echo "Refusing to send the API key over plain HTTP to $base." >&2
          echo "Use an https:// URL, or set AEROPLANE_ALLOW_HTTP=1 for a fresh install you accept the risk on." >&2
          exit 2
        fi
        ;;
    esac
    ;;
  *) echo "AEROPLANE_URL must start with https://" >&2; exit 2 ;;
esac

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# The key goes through a curl config on stdin so it never appears in the process list.
if [ -n "$body" ]; then
  code=$(printf 'header = "Authorization: Bearer %s"\n' "$AEROPLANE_API_KEY" |
    curl -sS -K - -o "$tmp" -w '%{http_code}' -X "$method" "$base$path" \
      -H 'Content-Type: application/json' --data-binary "$body")
else
  code=$(printf 'header = "Authorization: Bearer %s"\n' "$AEROPLANE_API_KEY" |
    curl -sS -K - -o "$tmp" -w '%{http_code}' -X "$method" "$base$path")
fi

cat "$tmp"
echo
case "$code" in
  2??) exit 0 ;;
  *) echo "HTTP $code" >&2; exit 1 ;;
esac
