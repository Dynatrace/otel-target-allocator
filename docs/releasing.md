# Release process

This document describes how to release a new version of the Dynatrace OpenTelemetry Target Allocator.

## Release prerequisites

Before cutting a release tag, open a **release preparation PR** that verifies and updates the following:

1. Ensure the downstream version in `Makefile` is set to the target release version:
   - `VERSION := vX.Y.Z`
2. Ensure the pinned upstream version is correct (if this release includes an upstream update, Renovate should have updated the version here already):
   - `UPSTREAM_VERSION := vX.Y.Z`
3. Ensure local patches still apply cleanly on top of the pinned upstream:
   ```sh
   make clean setup check-patches
   ```
4. Ensure tests pass with patches applied:
   ```sh
   make test
   make smoke-test
   ```
5. Generate the changelog entry for this version and review it:
   ```sh
   make changelog
   ```
   This updates `CHANGELOG.md` in place, adding (or refreshing) the `## vX.Y.Z`
   section. Review the generated content, adjust wording if needed, and commit
   `CHANGELOG.md` as part of the release preparation PR. See
   [Release notes](#release-notes) for details on what the entry contains.

Merge the release preparation PR before creating the tag.

## Making a production release

A production release is triggered by pushing a git tag that starts with `v` and is semver-compliant (for example `v0.1.0`).

1. Identify the git ref you want to release (usually `main`, after the release preparation PR is merged).
2. Check out and synchronize it locally:

   ```sh
   git fetch origin
   git checkout main
   git reset --hard origin/main
   ```

3. Confirm the `VERSION` value in `Makefile` exactly matches the intended release tag.
   - Example: if releasing `v0.1.0`, `Makefile` must contain `VERSION := v0.1.0`.
   - The release workflow validates this and fails if they do not match.
   - Confirm `CHANGELOG.md` contains a `## v0.1.0` section — the release workflow
     fails if it does not.

4. Create the release tag:

   ```sh
   git tag v0.1.0
   ```

5. Push the branch and the tag:

   ```sh
   git push origin main
   git push origin v0.1.0
   ```

6. Review and publish the draft release when ready.

## Release notes

Release notes live in `CHANGELOG.md` and are generated ahead of time by
`make changelog` (during the release preparation PR), **not** at release time.
This lets you review and edit the notes before tagging.

`make changelog` (via `scripts/generate-changelog.sh`) builds the `## vX.Y.Z`
section from two sources:

- **Dynatrace distribution changelog** — commits since the previous release tag,
  excluding `chore`, `docs`, and `test` conventional-commit types.
- **Upstream Target Allocator changes** — the Target Allocator entries from the
  pinned `UPSTREAM_VERSION` opentelemetry-operator GitHub release, embedded in a
  clearly labelled, collapsible block that links back to the upstream release.

The target is idempotent: re-running `make changelog` replaces the section for
the current `VERSION` rather than duplicating it.

At release time, the workflow runs `scripts/extract-changelog.sh <tag>` to pull
the matching `## vX.Y.Z` section out of `CHANGELOG.md` and passes it to
goreleaser via `--release-notes`. Goreleaser's own git-based changelog
generation is disabled, so the GitHub release body is exactly the reviewed
`CHANGELOG.md` section.

