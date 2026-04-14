# Upstream repository
UPSTREAM_REPO    := https://github.com/open-telemetry/opentelemetry-operator

# renovate: datasource=github-releases depName=open-telemetry/opentelemetry-operator
UPSTREAM_VERSION := v0.148.0

# Downstream version — bump this manually when cutting a release
VERSION := v0.1.0

# Build directories
BUILD_DIR   := build
PATCHES_DIR := patches

# Binary output
GOOS        := $(shell go env GOOS 2>/dev/null || echo linux)
GOARCH      := $(shell go env GOARCH 2>/dev/null || echo amd64)
BINARY_NAME := targetallocator_$(GOOS)_$(GOARCH)

# Docker image
IMAGE_REPO  ?= target-allocator
IMAGE_TAG   ?= $(VERSION)

# Go test options
GOTEST_OPTS ?= -count=1 -race

# Sentinel files used to avoid redundant re-runs
CLONE_SENTINEL := $(BUILD_DIR)/.git
PATCH_SENTINEL := $(BUILD_DIR)/.patched

.DEFAULT_GOAL := build

##@ General

.PHONY: help
help: ## Display this help text
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Build pipeline

.PHONY: setup
setup: $(CLONE_SENTINEL) ## Clone upstream source at the pinned UPSTREAM_VERSION

$(CLONE_SENTINEL):
	@echo "==> Cloning upstream opentelemetry-operator $(UPSTREAM_VERSION)"
	git clone --depth 1 --branch $(UPSTREAM_VERSION) $(UPSTREAM_REPO) $(BUILD_DIR)

.PHONY: patch
patch: $(PATCH_SENTINEL) ## Apply all patches from patches/ onto the upstream source

$(PATCH_SENTINEL): $(CLONE_SENTINEL) $(wildcard $(PATCHES_DIR)/*.patch)
	@echo "==> Resetting upstream tree to clean state"
	@git -C $(BUILD_DIR) checkout -- .
	@git -C $(BUILD_DIR) clean -fd > /dev/null
	@patches=$$(ls -1 $(PATCHES_DIR)/*.patch 2>/dev/null | sort); \
	if [ -z "$$patches" ]; then \
		echo "==> No patches to apply"; \
	else \
		for p in $$patches; do \
			echo "==> Applying patch: $$p"; \
			git -C $(BUILD_DIR) apply --whitespace=fix "$$(pwd)/$$p" || exit 1; \
		done; \
	fi
	@touch $(PATCH_SENTINEL)
	@echo "==> Patching complete"

.PHONY: build
build: patch ## Build the target allocator binary
	@echo "==> Building $(BINARY_NAME)"
	cd $(BUILD_DIR) && \
		CGO_ENABLED=0 GOOS=$(GOOS) GOARCH=$(GOARCH) go build \
			-trimpath \
			-o bin/$(BINARY_NAME) \
			./cmd/otel-allocator
	@echo "==> Binary: $(BUILD_DIR)/bin/$(BINARY_NAME)"

.PHONY: image
image: build ## Build the container image using the upstream Dockerfile
	@echo "==> Building container image $(IMAGE_REPO):$(IMAGE_TAG)"
	docker buildx build \
		--platform linux/$(GOARCH) \
		--build-arg TARGETARCH=$(GOARCH) \
		-t $(IMAGE_REPO):$(IMAGE_TAG) \
		-f $(BUILD_DIR)/cmd/otel-allocator/Dockerfile \
		$(BUILD_DIR)

##@ Testing

.PHONY: test
test: patch ## Run the target allocator unit tests
	@echo "==> Running unit tests"
	cd $(BUILD_DIR) && go test $(GOTEST_OPTS) ./cmd/otel-allocator/...

.PHONY: smoke-test
smoke-test: build ## Verify the binary is functional
	@echo "==> Running smoke test"
	$(BUILD_DIR)/bin/$(BINARY_NAME) --help
	@echo "==> Smoke test passed"

##@ Maintenance

.PHONY: clean
clean: ## Remove the build working directory
	@echo "==> Cleaning build directory"
	rm -rf $(BUILD_DIR)

.PHONY: check-patches
check-patches: $(CLONE_SENTINEL) ## Verify all patches apply cleanly (without modifying the tree)
	@patches=$$(ls -1 $(PATCHES_DIR)/*.patch 2>/dev/null | sort); \
	if [ -z "$$patches" ]; then \
		echo "==> No patches to check"; \
	else \
		tmpdir=$$(mktemp -d) && \
		git -C $(BUILD_DIR) worktree add --detach $$tmpdir HEAD 2>/dev/null; \
		ok=0; \
		for p in $$patches; do \
			echo "==> Checking patch: $$p"; \
			git -C $$tmpdir apply --check "$$(pwd)/$$p" || { ok=1; break; }; \
		done; \
		git -C $(BUILD_DIR) worktree remove --force $$tmpdir; \
		if [ $$ok -eq 0 ]; then echo "==> All patches apply cleanly"; fi; \
		exit $$ok; \
	fi

.PHONY: new-patch
new-patch: ## Generate a numbered patch file from the last commit in build/ (rename to describe your change)
	@existing_count=$$(find $(PATCHES_DIR) -maxdepth 1 -name "*.patch" | wc -l | xargs); \
	next_seq=$$(printf "%04d" $$((existing_count + 1))); \
	output="$(PATCHES_DIR)/$$next_seq-describe-your-change.patch"; \
	git -C $(BUILD_DIR) format-patch HEAD~1 --stdout > "$$output"; \
	echo "==> Generated $$output"; \
	echo "    Rename it to describe your change, e.g. $$next_seq-fix-my-bug.patch"
