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

## Support

The builds provided in this repository are supported by the Dynatrace Support team, in accordance with the Dynatrace [support policy].

For full support coverage, contact Dynatrace through the official support channels. Issues reported via GitHub are handled on a best‑effort basis; support contracts and SLAs don't apply.

Each minor version is supported for three months. Fixes are provided either as a patch release for the latest supported minor version or as part of a subsequent minor version release.

This distribution depends on components provided upstream by the OpenTelemetry community.
We plan to release a new version of the distribution with updated upstream components at least on a monthly cadence.
If the OpenTelemetry community decides to make a breaking change, it will be pulled into this distribution as we upgrade to newer versions of these upstream components.
For the complete list of changes, please refer to the changelogs provided in the [opentelemetry-operator releases] page (`target allocator` component).

[support policy]: https://support.dynatrace.com/
[opentelemetry-operator releases]: https://github.com/open-telemetry/opentelemetry-operator/releases

## Development Docs

- [Patch process](docs/patching.md)
- [Release process](docs/releasing.md)
