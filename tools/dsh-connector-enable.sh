#!/usr/bin/env bash
# Install the read-only TRANSAQ connector (dshtrading-connector-transaq) into a
# DSH profile as a standard bundle. By default the profile is the one DeepSeek
# Harness Desktop boots (~/.dsh/profiles/desktop).
#
# The connector package declares `dsh.bundle.patch`, so `dsh plugin add` mounts
# its row automatically. This helper only wraps the standard commands and,
# for non-default settings, writes a profile-level override row (same id, no
# `insert`) for gatewayUrl / tokenRef. Idempotent; backs up package.json and
# cordis.patch.yml next to themselves before every change.
#
#   tools/dsh-connector-enable.sh            # enable
#   tools/dsh-connector-enable.sh --remove   # remove the connector and override
#
# Environment (all optional):
#   DSH_HOME       DSH home (default ~/.dsh)
#   PROFILE        profile name (default desktop)
#   GATEWAY_URL    loopback URL of bin/terminal (default http://127.0.0.1:18095;
#                  18090 is taken by the AI-terminal plugin's own backend)
#   TOKEN_REF      env/credential name holding the gateway token
#                  (default TERMINAL_API_TOKEN)
#   DSH            dsh launcher (default: dsh on PATH, else /usr/local/bin/dsh)
#   SKIP_INSTALL=1 only edit the profile override, do not run `dsh plugin ...`
#   DSH_PLUGIN_ARGS extra pnpm args for the install, e.g. "--offline"
set -u

usage() {
  sed -n '2,24p' "$0"
}

MODE=enable
case "${1:-}" in
  "") ;;
  --remove) MODE=remove ;;
  -h|--help) usage; exit 0 ;;
  *) echo "usage: $0 [--remove]" >&2; exit 2 ;;
esac

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DSH_HOME="${DSH_HOME:-$HOME/.dsh}"
PROFILE="${PROFILE:-desktop}"
GATEWAY_URL="${GATEWAY_URL:-http://127.0.0.1:18095}"
TOKEN_REF="${TOKEN_REF:-TERMINAL_API_TOKEN}"
DSH="${DSH:-$(command -v dsh || echo /usr/local/bin/dsh)}"
P="$DSH_HOME/profiles/$PROFILE"
PKG="@local/dshtrading-connector-transaq"
ROW_ID="dsh-trading-ru-connector-transaq"
HOST="@dshtrading/base"
HOST_SPEC="@dshtrading/base@^0.6.3"

if [ ! -f "$REPO/index.js" ] || [ ! -f "$REPO/cordis.patch.yml" ]; then
  echo "error: connector bundle not found at $REPO (need index.js and cordis.patch.yml)" >&2
  exit 1
fi
if ! command -v "$DSH" >/dev/null 2>&1 && [ ! -x "$DSH" ]; then
  echo "error: dsh launcher not found: $DSH" >&2
  exit 1
fi
if [ ! -f "$P/package.json" ]; then
  echo "error: DSH profile not found: $P (start DSH once, or run: $DSH plugin --profile $PROFILE list)" >&2
  exit 1
fi

# Validate the values the plugin will receive; the same rules live in config.js.
python3 - "$GATEWAY_URL" "$TOKEN_REF" <<'PY' || exit 2
import re, sys, urllib.parse
gateway_url, token_ref = sys.argv[1:3]
try:
    parsed = urllib.parse.urlparse(gateway_url)
    host = parsed.hostname
except ValueError:
    sys.exit("error: GATEWAY_URL must be a valid http:// loopback URL")
try:
    port = parsed.port
except ValueError:
    sys.exit("error: GATEWAY_URL has an invalid port")
if parsed.scheme != "http" or host not in ("127.0.0.1", "localhost", "::1"):
    sys.exit("error: GATEWAY_URL must be an http:// loopback URL (127.0.0.1, localhost or [::1])")
if port is not None and not (1 <= port <= 65535):
    sys.exit("error: GATEWAY_URL has an invalid port")
if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", token_ref):
    sys.exit("error: TOKEN_REF must be an environment variable name")
PY

TS="$(date +%Y%m%d-%H%M%S)-$$"
cp "$P/package.json" "$P/package.json.connector-$TS" || exit 1
[ -f "$P/cordis.patch.yml" ] && cp "$P/cordis.patch.yml" "$P/cordis.patch.yml.connector-$TS"

echo "backup: $P/package.json.connector-$TS"

if [ "${SKIP_INSTALL:-0}" != "1" ] && [ "$MODE" = enable ]; then
  echo "install host bundle $HOST_SPEC..."
  # shellcheck disable=SC2086
  "$DSH" plugin --profile "$PROFILE" add "$HOST_SPEC" ${DSH_PLUGIN_ARGS:-} || {
    echo "install failed; restore with: cp $P/package.json.connector-$TS $P/package.json" >&2
    exit 1
  }
  echo "install connector bundle $PKG from $REPO..."
  # shellcheck disable=SC2086
  "$DSH" plugin --profile "$PROFILE" add "file:$REPO" ${DSH_PLUGIN_ARGS:-} || {
    echo "install failed; restore with: cp $P/package.json.connector-$TS $P/package.json" >&2
    exit 1
  }
fi

# The bundle row carries the defaults. A profile-level row with the same id but
# no `insert` replaces it; this is how non-default gatewayUrl / tokenRef are
# applied without duplicating the row.
python3 - "$P" "$GATEWAY_URL" "$TOKEN_REF" "$MODE" "$ROW_ID" <<'PY' || exit 1
import os, re, sys

profile, gateway_url, token_ref, mode, row_id = sys.argv[1:6]
defaults = (gateway_url == "http://127.0.0.1:18095" and token_ref == "TERMINAL_API_TOKEN")
patch_path = os.path.join(profile, "cordis.patch.yml")
existed = os.path.exists(patch_path)
patch = open(patch_path).read() if existed else ""
row_re = re.compile(
    r"\n?# dshtrading-connector-transaq: BEGIN\n.*?# dshtrading-connector-transaq: END\n",
    re.S,
)
had_block = bool(row_re.search(patch))

if mode == "remove" or defaults:
    patch = row_re.sub("\n", patch)
    if mode == "remove":
        if had_block:
            print("removed: profile override for", row_id)
        else:
            print("no profile override to remove")
    else:
        print("profile override not needed: bundle defaults are in effect")
else:
    row = (
        "# dshtrading-connector-transaq: BEGIN\n"
        "- id: %s\n"
        "  config:\n"
        "    enabled: true\n"
        "    gatewayUrl: '%s'\n"
        "    tokenRef: %s\n"
        "# dshtrading-connector-transaq: END\n"
    ) % (row_id, gateway_url, token_ref)
    patch = row_re.sub("\n", patch)
    if patch and not patch.endswith("\n"):
        patch += "\n"
    patch += "\n" + row
    print("profile override:", row_id, "gatewayUrl", gateway_url, "tokenRef", token_ref)

if not patch.strip():
    patch = "[]\n" if existed else ""
if patch:
    open(patch_path, "w").write(patch)
PY

if [ "${SKIP_INSTALL:-0}" != "1" ] && [ "$MODE" = remove ]; then
  echo "remove connector bundle $PKG..."
  "$DSH" plugin --profile "$PROFILE" remove "$PKG" || {
    echo "warning: failed to remove $PKG from $PROFILE; the profile override was removed" >&2
    echo "         restore package.json with: cp $P/package.json.connector-$TS $P/package.json" >&2
    exit 1
  }
fi

if [ "$MODE" = enable ]; then
  echo "next: start the gateway with the same $TOKEN_REF, make it visible to the app, restart DSH"
  echo "      (see QUICKSTART.md)"
else
  echo "restart DSH: osascript -e 'quit app \"DeepSeek Harness\"'; open -a \"DeepSeek Harness\""
  echo "note: $HOST is left installed; remove it separately if needed"
fi
