# Release process

This document describes how to release a new version of the Dynatrace OpenTelemetry Target Allocator.

## Release prerequisites

Before cutting a release tag, open a PR to verify and update the following:

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

## Making a production release

A production release is triggered by pushing a git tag that starts with `v` and is semver-compliant (for example `v0.1.0`).

1. Identify the git ref you want to release (usually `main`).
2. Check out and synchronize it locally:

   ```sh
   git fetch origin
   git checkout main
   git reset --hard origin/main
   ```

3. Confirm the `VERSION` value in `Makefile` exactly matches the intended release tag.
   - Example: if releasing `v0.1.0`, `Makefile` must contain `VERSION := v0.1.0`.
   - The release workflow validates this and fails if they do not match.

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
