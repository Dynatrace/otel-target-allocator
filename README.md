# Prometheus Target Allocator for OpenTelemetry Collectors

A Dynatrace-provided distribution of the [OpenTelemetry Operator Target Allocator](https://github.com/open-telemetry/opentelemetry-operator/tree/main/cmd/otel-allocator).

## Overview

The Target Allocator (TA) is a component that decouples service discovery and metric collection in Prometheus so they can be scaled independently.
It allows OpenTelemetry Collectors to scrape Prometheus metrics without requiring a full Prometheus installation.

The TA serves two main functions:

- **Even distribution of Prometheus targets** across a pool of OTel Collectors
- **Discovery of Prometheus Custom Resources** (ServiceMonitors, PodMonitors)

### How it works

```
Target Allocator  -->  discovers Metrics targets
Target Allocator  -->  discovers available OTel Collectors
Target Allocator  -->  assigns targets to Collectors
OTel Collectors   -->  query TA for their assigned scrape targets
OTel Collectors   -->  scrape assigned Metrics targets
```

The Prometheus Receiver config in each Collector is overridden with an `http_sd_config` pointing to the TA, which handles the load-balancing and sharding of targets.

## Documentation

Refer to the Dynatrace documentation on how to [Scrape Prometheus metrics with the OpenTelemetry Collector](https://docs.dynatrace.com/docs/shortlink/otel-collector-cases-prometheus-general)
to learn about the architecture, deployment and configuration, as well as for monitoring and troubleshooting instructions.

## Installation

### Container images

Container images for the Dynatrace OTel Target Allocator are available in:

- [GitHub Container Registry (GHCR)](https://github.com/Dynatrace/otel-target-allocator/pkgs/container/otel-target-allocator%2Ftarget-allocator)
- [Amazon Elastic Container Registry (Amazon ECR)](https://gallery.ecr.aws/dynatrace/otel-target-allocator)
- [Docker Hub Container Registry](https://hub.docker.com/r/dynatrace/otel-target-allocator)

### Verifying image signatures

All container images are signed using [cosign] keyless signing ([Sigstore]). No long-lived signing keys are used;
signatures are bound to the GitHub Actions release workflow via OIDC.

To verify an image, install [cosign] and run:

```sh
cosign verify \
  --certificate-identity-regexp "https://github.com/Dynatrace/otel-target-allocator/.github/workflows/release.yaml@refs/tags/.*" \
  --certificate-oidc-issuer "https://token.actions.githubusercontent.com" \
  ghcr.io/dynatrace/otel-target-allocator/target-allocator:<tag>
```

Replace `<tag>` with the image tag you want to verify (e.g. `0.1.0`).
The same command works for ECR (`public.ecr.aws/dynatrace/otel-target-allocator:<tag>`) and Docker Hub (`dynatrace/otel-target-allocator:<tag>`).

[cosign]: https://docs.sigstore.dev/cosign/system_config/installation/
[Sigstore]: https://www.sigstore.dev/

## Allocation Strategies

| Strategy | Description |
|---|---|
| `consistent-hashing` | (Default) Hashes the target URL to consistently assign targets to the same collector. Rebalances when collector count changes. |
| `least-weighted` | Assigns targets to the collector with the fewest current targets. More stable on collector count changes, less even distribution. |
| `per-node` | Assigns each target to the collector running on the same Node. Only suitable for DaemonSet deployments. |

## Configuration

The TA reads a config file at `/conf/targetallocator.yaml` by default.

Key configuration fields:

| Field | Description | Default |
|---|---|---|
| `collector_namespace` | Namespace to watch for collector deployments | `OTELCOL_NAMESPACE` env var |
| `collector_selector` | Kubernetes label selector to identify collectors | |
| `listen_addr` | Endpoint the TA exposes for collectors to query | `:8080` |
| `allocation_strategy` | Target distribution strategy | `consistent-hashing` |
| `filter_strategy` | Filter strategy for metrics | `relabel-config` |
| `prometheus_cr.enabled` | Watch for Prometheus CRs (ServiceMonitor/PodMonitor) | `false` |

## Prometheus Custom Resource Discovery

When `prometheus_cr.enabled` is set to `true`, the TA will watch for Prometheus Operator CRDs (`ServiceMonitor` and `PodMonitor`) and automatically add the discovered jobs to the scrape configuration of the connected Collectors.

> **Note:** Prometheus itself does not need to be installed, but the ServiceMonitor and PodMonitor CRDs must be present in the cluster. These can be installed standalone from the [kube-prometheus-stack Helm chart CRDs](https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack/charts).

## Upstream Reference

This repository is based on the upstream Target Allocator from the [opentelemetry-operator](https://github.com/open-telemetry/opentelemetry-operator/tree/main/cmd/otel-allocator). Refer to the upstream docs for the full API specification and advanced configuration options.

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

## Support

This component is currently in development and not supported by Dynatrace.

## Development Docs

- [Release process](docs/releasing.md)
