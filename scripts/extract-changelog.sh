#!/usr/bin/env bash
# Prints the CHANGELOG.md body for a given release version, for use as
# goreleaser release notes (--release-notes).
#
# Usage: extract-changelog.sh vX.Y.Z
#
# Outputs everything under the "## vX.Y.Z" heading up to (but excluding) the
# next "## " heading. Exits non-zero if the version has no entry.
set -euo pipefail

VERSION=${1:?usage: extract-changelog.sh vX.Y.Z}
CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"

if [[ ! -f "$CHANGELOG_FILE" ]]; then
  echo "ERROR: ${CHANGELOG_FILE} not found" >&2
  exit 1
fi

section=$(awk -v version="$VERSION" '
  function is_ver_heading(line,   prefix) {
    prefix = "## " version
    return (line == prefix) || (substr(line, 1, length(prefix) + 1) == prefix " ")
  }
  is_ver_heading($0) { capture = 1; next }
  capture && /^## / { exit }
  capture { lines[++n] = $0 }
  END {
    start = 1; end = n
    while (start <= end && lines[start] ~ /^[[:space:]]*$/) start++
    while (end >= start && lines[end] ~ /^[[:space:]]*$/) end--
    for (i = start; i <= end; i++) print lines[i]
  }
' "$CHANGELOG_FILE")

if [[ -z "$section" ]]; then
  echo "ERROR: no CHANGELOG entry found for ${VERSION} in ${CHANGELOG_FILE}" >&2
  exit 1
fi

printf '%s\n' "$section"
