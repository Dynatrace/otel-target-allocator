## Patch Pipeline

This repo uses a Debian-style patch strategy. The upstream source is never committed here — instead, local modifications live as ordered `.patch` files in `patches/`. During the build, the upstream source is cloned at the pinned version and patches are applied in sequence.

The pinned upstream version is defined in the `Makefile` as `UPSTREAM_VERSION` and is tracked by Renovate for automatic update PRs.

### Make targets

| Target | Description |
|---|---|
| `make setup` | Clone the upstream repo at `UPSTREAM_VERSION` into `build/` |
| `make patch` | Apply all `patches/*.patch` files in order |
| `make build` | Build the `target-allocator` binary for the current platform |
| `make test` | Run the upstream unit tests with local patches applied |
| `make smoke-test` | Verify the binary is functional |
| `make snapshot` | Build all binaries and container images locally (full snapshot) |
| `make check-patches` | Dry-run all patches to verify they apply cleanly |
| `make new-patch` | Generate a numbered patch file from the last commit in `build/` |
| `make clean` | Remove the `build/` working directory |

### Adding a downstream patch

1. Clone upstream at the pinned version and apply all existing patches:
   ```sh
   make setup patch
   ```
2. Make your change inside `build/` and stage it with `git add`.
3. Generate a numbered patch file from your last commit:
   ```sh
   make new-patch
   ```
   Rename the generated file to describe your change.
4. Commit the `.patch` file — **not** the modified `build/` directory (it is gitignored).

### Updating the upstream version

1. Update `UPSTREAM_VERSION` in the `Makefile`.
2. Run `make clean setup check-patches` to verify all patches still apply.
3. If a patch conflicts, rebase it or drop it if it has been merged upstream.
4. Commit the version bump and any patch adjustments together.
