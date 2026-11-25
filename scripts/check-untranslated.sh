#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
FLUTTER=${FLUTTER:-flutter}
REPORT=lib/generated/untranslated.json

$FLUTTER gen-l10n >/dev/null
if [ ! -f "$REPORT" ]; then
  echo "gen-l10n wrote no $REPORT" >&2
  exit 1
fi
if [ "$(tr -d '[:space:]' < "$REPORT")" != "{}" ]; then
  echo "Untranslated messages (add them to every ARB file in lib/l10n):" >&2
  cat "$REPORT" >&2
  exit 1
fi
echo "Every ARB file translates every message."
