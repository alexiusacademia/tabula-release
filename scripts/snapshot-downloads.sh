#!/usr/bin/env bash
#
# Append today's download counts to stats/downloads.csv.
#
# GitHub reports a running total per asset and nothing else — no history, no
# dates, and the counter starts again at zero with every release. So the only
# way to know what a given week looked like is to have written it down at the
# time. This script is that writing-down; the workflow runs it daily.
#
# Re-running on the same day replaces that day's rows rather than doubling
# them, so a manual run alongside the scheduled one is harmless.
#
#   ./scripts/snapshot-downloads.sh            # this repo
#   REPO=owner/name ./scripts/snapshot-downloads.sh
#
set -euo pipefail

REPO="${REPO:-${GITHUB_REPOSITORY:-alexiusacademia/tabula-release}}"
OUT="${OUT:-stats/downloads.csv}"
DATE="$(date -u +%F)"

mkdir -p "$(dirname "$OUT")"
[ -f "$OUT" ] || echo "date,tag,asset,downloads" > "$OUT"

rows="$(gh api --paginate "repos/$REPO/releases" \
  --jq '.[] | .tag_name as $t | .assets[] | [$t, .name, .download_count] | @csv')"

if [ -z "$rows" ]; then
  echo "No release assets found in $REPO — nothing to record." >&2
  exit 0
fi

# Drop any rows already written for today, then append the fresh ones. The
# header doesn't start with a quote, so it survives the filter.
tmp="$(mktemp)"
grep -v "^\"$DATE\"," "$OUT" > "$tmp" || true
mv "$tmp" "$OUT"

while IFS= read -r line; do
  echo "\"$DATE\",$line" >> "$OUT"
done <<< "$rows"

total="$(printf '%s\n' "$rows" | awk -F, '{ s += $NF } END { print s+0 }')"
echo "Recorded $(printf '%s\n' "$rows" | wc -l | tr -d ' ') assets for $DATE — $total downloads in total."
