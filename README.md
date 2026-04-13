# Target Allocator for OpenTelemetry Collectors

A pseudo fork of the [OpenTelemetry Operator Target Allocator](https://github.com/open-telemetry/opentelemetry-operator/tree/main/cmd/otel-allocator).

## Overview

The Target Allocator (TA) is a component that decouples service discovery and metric collection in Prometheus so they can be scaled independently. It allows OTel Collectors to scrape Prometheus metrics without requiring a full Prometheus installation.

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

This component is currently in development and not supported by Dynatrace.
