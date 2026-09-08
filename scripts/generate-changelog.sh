#!/usr/bin/env bash
# Generates or refreshes the CHANGELOG.md section for the current release VERSION.
#
# The section combines:
#   * Downstream (Dynatrace) commits since the previous release tag, excluding
#     chore/docs/test conventional-commit types.
#   * The upstream Target Allocator changes for the pinned UPSTREAM_VERSION,
#     fetched from the opentelemetry-operator GitHub release.
#
# The result is inserted at the top of CHANGELOG.md (newest first). If a section
# for VERSION already exists it is replaced, so the target is idempotent.
#
# Environment variables:
#   VERSION           – e.g. v0.5.0   (falls back to reading Makefile)
#   UPSTREAM_VERSION  – e.g. v0.157.0 (falls back to reading Makefile)
#   GITHUB_TOKEN      – optional, avoids GitHub API rate-limiting
#   CHANGELOG_FILE    – optional, target file (defaults to CHANGELOG.md); handy
#                       for pointing at a scratch copy when testing locally
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT_DIR=$(cd "$SCRIPT_DIR/.." && pwd)
cd "$ROOT_DIR"

CHANGELOG_FILE="${CHANGELOG_FILE:-CHANGELOG.md}"
UPSTREAM_REPO="open-telemetry/opentelemetry-operator"

VERSION=${VERSION:-$(grep '^VERSION' Makefile | awk '{print $3}')}
UPSTREAM_VERSION=${UPSTREAM_VERSION:-$(grep '^UPSTREAM_VERSION' Makefile | awk '{print $3}')}

if [[ -z "$VERSION" ]]; then
  echo "ERROR: VERSION is not set and could not be read from Makefile" >&2
  exit 1
fi

# Fetches the Target Allocator entries from the upstream opentelemetry-operator
# release and prints them as a collapsible Markdown block. Upstream does not
# group Target Allocator changes under their own heading; each entry is a bullet
# prefixed with `target allocator`: inside the shared "Enhancements" / "Bug
# fixes" sections, so we extract those bullets (with continuation lines) while
# preserving the section they belong to. Prints nothing if there are none.
fetch_upstream_changelog() {
  local version="$1"

  local curl_args=(-sf -H "Accept: application/vnd.github+json")
  if [[ -n "${GITHUB_TOKEN:-}" ]]; then
    curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
  fi

  local response release_body
  response=$(curl "${curl_args[@]}" \
    "https://api.github.com/repos/${UPSTREAM_REPO}/releases/tags/${version}") || {
    echo "WARNING: Could not fetch upstream release ${version}" >&2
    return 0
  }

  release_body=$(echo "$response" | jq -r '.body')
  if [[ -z "$release_body" || "$release_body" == "null" ]]; then
    echo "WARNING: No release body found for upstream ${version}" >&2
    return 0
  fi

  local ta_section
  ta_section=$(echo "$release_body" | awk '
    /^### / { heading=$0; heading_printed=0; capturing=0; next }
    /^## / { heading=""; capturing=0; next }
    /^- / {
      if (tolower($0) ~ /^- `target allocator`/) {
        capturing=1
        if (heading != "" && !heading_printed) {
          if (printed_any) print ""
          print heading
          print ""
          heading_printed=1
        }
        print
        printed_any=1
      } else {
        capturing=0
      }
      next
    }
    capturing { print }
  ')

  if [[ -z "$(echo "$ta_section" | tr -d '[:space:]')" ]]; then
    echo "WARNING: No 'target allocator' entries found in upstream release ${version}" >&2
    return 0
  fi

  local upstream_url="https://github.com/${UPSTREAM_REPO}/releases/tag/${version}"
  cat <<HEADER
<details>
<summary>Target Allocator changes from upstream <a href="${upstream_url}">opentelemetry-operator ${version}</a></summary>

${ta_section}
</details>
HEADER
}

# Determine the previous release tag (highest v* tag that is not VERSION).
last_tag=$(git tag --list 'v*' --sort=-v:refname | grep -vx "$VERSION" | head -1 || true)
if [[ -n "$last_tag" ]]; then
  range="${last_tag}..HEAD"
  echo "==> Collecting commits since ${last_tag}" >&2
else
  range=""
  echo "==> No previous tag found; collecting all commits" >&2
fi

# Downstream commits, excluding chore/docs/test conventional-commit types.
downstream=$(git log ${range:+$range} --no-merges --reverse --pretty=format:'- %s' \
  | grep -Ev '^- (chore|docs|test)(\([^)]*\))?!?:' || true)

# Upstream Target Allocator changes.
upstream=$(fetch_upstream_changelog "$UPSTREAM_VERSION" || true)

# Assemble the new section into a temp file.
tmp_entry=$(mktemp)
trap 'rm -f "$tmp_entry"' EXIT

{
  echo "## ${VERSION}"
  echo ""
  echo "### Dynatrace distribution changelog"
  echo ""
  if [[ -n "$downstream" ]]; then
    echo "$downstream"
  else
    echo "- No downstream changes."
  fi
  if [[ -n "$upstream" ]]; then
    echo ""
    echo "$upstream"
  fi
} > "$tmp_entry"

# Ensure CHANGELOG.md exists with the expected structure.
if [[ ! -f "$CHANGELOG_FILE" ]]; then
  cat > "$CHANGELOG_FILE" <<'EOF'
# Changelog

All notable changes to the Dynatrace OpenTelemetry Target Allocator are documented in this file.

<!-- next -->
EOF
fi

if ! grep -q '<!-- next -->' "$CHANGELOG_FILE"; then
  echo "ERROR: CHANGELOG.md is missing the '<!-- next -->' insertion marker" >&2
  exit 1
fi

tmp_clean=$(mktemp)
trap 'rm -f "$tmp_entry" "$tmp_clean"' EXIT

# Pass 1: drop any existing section for this version from the current file.
awk -v version="$VERSION" '
  function is_ver_heading(line,   prefix) {
    prefix = "## " version
    return (line == prefix) || (substr(line, 1, length(prefix) + 1) == prefix " ")
  }
  is_ver_heading($0) { skip = 1; next }
  skip && /^## / { skip = 0 }
  skip { next }
  { print }
' "$CHANGELOG_FILE" > "$tmp_clean"

# Pass 2: insert the new entry immediately after the marker (newest first).
awk -v entryfile="$tmp_entry" '
  BEGIN {
    while ((getline line < entryfile) > 0) entry = entry line "\n"
    close(entryfile)
  }
  { print }
  /<!-- next -->/ && !done { print ""; printf "%s", entry; done = 1 }
' "$tmp_clean" > "$CHANGELOG_FILE"

rm -f "$tmp_entry" "$tmp_clean"
trap - EXIT

echo "==> Updated ${CHANGELOG_FILE} for ${VERSION}" >&2
