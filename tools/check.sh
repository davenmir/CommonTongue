#!/usr/bin/env bash
# Runs lint and tests the same way CI does. Usage: tools/check.sh [busted args...]
# On Windows: wsl -d Ubuntu -- bash tools/check.sh
set -uo pipefail
cd "$(dirname "$0")/.."

if command -v luarocks >/dev/null; then
    eval "$(luarocks --lua-version=5.1 path)"
fi

status=0

[ -d CommonTongue/Libs/Ace3 ] || python3 tools/fetch_libs.py || status=1

echo "== luacheck"
luacheck . || status=1

echo "== busted"
busted "$@" || status=1

if [ -f tools/validate_data.lua ]; then
    echo "== validate_data"
    lua5.1 tools/validate_data.lua || status=1
fi

exit $status
