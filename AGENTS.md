# Agent Guidelines

This document captures working principles for AI agents contributing to this repository.

## Workflow Principles

### Clarify before acting

When a request is ambiguous or missing context, ask follow-up questions rather than making assumptions. A short clarifying conversation upfront saves significant rework later.

### Make small, focused commits

Break changes into logical, self-contained units and commit frequently. Each commit should represent a single coherent change that a code reviewer can easily understand and evaluate in isolation.

### Be consistent

Follow the existing naming conventions, code structure, and design patterns used throughout the repository. Consistency lowers the cognitive overhead for everyone working on the codebase and reduces the chance of introducing subtle bugs.

### Write for your teammates

Leave clear commit messages and documentation that explain the *why*, not just the *what*. A well-written summary helps the rest of the team understand the purpose of a change without having to reconstruct it from the diff.

## Repository Workflow

This repository is a pseudo-fork of the upstream [OTel Target Allocator](https://github.com/open-telemetry/opentelemetry-operator/tree/main/cmd/otel-allocator). Rather than maintaining a full source-code fork, it uses a **Debian-style patch strategy** to keep the amount of owned code minimal while still allowing hotfixes, vulnerability updates, and local modifications.

### How it works

1. The upstream TA source is **not copied into this repository**. Instead, the upstream version is pinned (e.g. via a version file or build script).
2. Local modifications live exclusively in the `patches/` directory as ordered `.patch` files.
3. During the build, the upstream source is pulled at the pinned version and each patch is applied in sequence to produce the final binary and container image.

### Adding a change

When a change cannot or should not be contributed back upstream, add it as a new patch file:

1. Apply all existing patches to a local checkout of the upstream source.
2. Make your change on top.
3. Generate a new `.patch` file (e.g. with `git format-patch`) and place it in `patches/` with a descriptive, ordered filename (e.g. `0003-fix-relabel-edge-case.patch`).
4. Commit the patch file — not the modified upstream source.

### Updating the upstream version

1. Update the pinned upstream version.
2. Verify that all existing patches in `patches/` still apply cleanly.
3. If a patch conflicts, either rebase it or drop it if it has been merged upstream.
4. Commit the version bump and any patch adjustments together.

### What belongs here vs. upstream

| Contribution type | Where it goes |
|---|---|
| Bug fixes useful to the wider community | Contribute upstream first, then optionally backport via patch until the next upstream release |
| Dynatrace-specific behaviour | `patches/` in this repo |
| Vulnerability / dependency updates | `patches/` until fixed upstream, then drop the patch |
