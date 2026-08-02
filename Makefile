GO_DIR := src
GO_PACKAGE := ./cmd/ii
BUILD_DIR := build
II_GO := $(BUILD_DIR)/ii-go
EXPORT_DIR := export/ii
VERSION := $(shell tr -d '\n' < VERSION)
GO_LDFLAGS := -s -w -X main.version=$(VERSION)
export GOCACHE := $(CURDIR)/$(BUILD_DIR)/.gocache

.PHONY: all build package package-linux-amd64 package-linux-arm64 package-arch fmt-check vet test test-go test-contract test-shell-operations test-ordinary-set-tmux test-payload-render-shared test-payload-routing test-combo-launch test-www test-entry-tmux test-variables-tmux test-variable-output-tmux test-variable-mutations-tmux test-set-tmux test-unset-all-tmux test-load-all-tmux test-get-tmux test-interactive-tmux test-clipboard-tmux test-tmux-install test-tmux-popup test-tmux-popup-interactive test-tmux-status test-payload-render-tmux test-payload-select-tmux test-payload-input-usage-tmux test-legacy test-legacy-tmux cross-build clean

all: package

build:
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && CGO_ENABLED=0 go build -trimpath \
		-ldflags "$(GO_LDFLAGS)" \
		-o ../$(II_GO) $(GO_PACKAGE)

package: build
	rm -rf $(EXPORT_DIR)
	mkdir -p $(EXPORT_DIR)/lib $(EXPORT_DIR)/ori-ii/script
	cp ii.plugin.zsh README.md VERSION $(EXPORT_DIR)/
	cp lib/ordinary_runtime.zsh lib/ordinary_variables.zsh lib/ordinary_read.zsh lib/ordinary_clipboard.zsh lib/ordinary_get.zsh lib/ordinary_interactive.zsh lib/ordinary_payload_render.zsh lib/ordinary_payload.zsh $(EXPORT_DIR)/lib/
	cp $(II_GO) $(EXPORT_DIR)/ii-go
	cp ori-ii/ii.plugin.zsh ori-ii/VERSION $(EXPORT_DIR)/ori-ii/
	cp -R ori-ii/lib ori-ii/payloads $(EXPORT_DIR)/ori-ii/
	cp ori-ii/script/ii-tmux-input ori-ii/script/ii-tmux-pice \
		ori-ii/script/ii-tmux-workflow $(EXPORT_DIR)/ori-ii/script/
	find $(EXPORT_DIR) -type f -name '.gitkeep' -delete
	printf 'ii %s\nruntime=ii-go\nlegacy_bridge=enabled\n' "$(VERSION)" > $(EXPORT_DIR)/RELEASE

package-linux-amd64:
	$(MAKE) package-arch ARCH=amd64

package-linux-arm64:
	$(MAKE) package-arch ARCH=arm64

package-arch:
	@test -n "$(ARCH)" || { printf 'ARCH is required\n' >&2; exit 2; }
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && CGO_ENABLED=0 GOOS=linux GOARCH=$(ARCH) go build -trimpath \
		-ldflags "$(GO_LDFLAGS)" \
		-o ../$(BUILD_DIR)/ii-go-linux-$(ARCH) $(GO_PACKAGE)
	rm -rf export/linux-$(ARCH)
	mkdir -p export/linux-$(ARCH)/ii/lib export/linux-$(ARCH)/ii/ori-ii/script
	cp ii.plugin.zsh README.md VERSION export/linux-$(ARCH)/ii/
	cp lib/ordinary_runtime.zsh lib/ordinary_variables.zsh lib/ordinary_read.zsh lib/ordinary_clipboard.zsh lib/ordinary_get.zsh lib/ordinary_interactive.zsh lib/ordinary_payload_render.zsh lib/ordinary_payload.zsh export/linux-$(ARCH)/ii/lib/
	cp $(BUILD_DIR)/ii-go-linux-$(ARCH) export/linux-$(ARCH)/ii/ii-go
	cp ori-ii/ii.plugin.zsh ori-ii/VERSION export/linux-$(ARCH)/ii/ori-ii/
	cp -R ori-ii/lib ori-ii/payloads export/linux-$(ARCH)/ii/ori-ii/
	cp ori-ii/script/ii-tmux-input ori-ii/script/ii-tmux-pice \
		ori-ii/script/ii-tmux-workflow export/linux-$(ARCH)/ii/ori-ii/script/
	find export/linux-$(ARCH)/ii -type f -name '.gitkeep' -delete
	printf 'ii %s\nruntime=ii-go\narchitecture=linux-$(ARCH)\nlegacy_bridge=enabled\n' \
		"$(VERSION)" > export/linux-$(ARCH)/ii/RELEASE

fmt-check:
	@test -z "$$(gofmt -l $$(find $(GO_DIR) -name '*.go' -type f))" || { \
		gofmt -d $$(find $(GO_DIR) -name '*.go' -type f); \
		exit 1; \
	}

vet:
	cd $(GO_DIR) && go vet ./...

test-go:
	cd $(GO_DIR) && go test ./...

test-contract: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/run both

test-shell-operations: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/shell-operations

test-ordinary-set-tmux:
	./test/contract/ordinary-set-tmux

test-payload-render-shared:
	./test/contract/payload-render-shared

test-payload-routing:
	./test/contract/payload-routing

test-combo-launch:
	./test/contract/combo-launch

test-www: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/www

test-entry-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/entrypoint-tmux

test-variables-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/variables-tmux

test-variable-output-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/variable-output-tmux

test-variable-mutations-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/variable-mutations-tmux

test-set-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/set-tmux

test-unset-all-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/unset-all-tmux

test-load-all-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/load-all-tmux

test-get-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/get-tmux

test-interactive-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/interactive-tmux

test-clipboard-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/clipboard-tmux

test-tmux-install: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/tmux-install

test-tmux-popup: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/tmux-popup

test-tmux-popup-interactive: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/tmux-popup-interactive

test-tmux-status: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/tmux-status

test-payload-render-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/payload-render-tmux

test-payload-select-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/payload-select-tmux

test-payload-input-usage-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/payload-input-usage-tmux

test: fmt-check vet test-go test-payload-render-shared test-payload-routing test-combo-launch test-contract test-shell-operations

test-legacy:
	cd ori-ii && zsh -n ii.plugin.zsh lib/*.zsh script/ii-tmux-* \
		&& ./script/help >/dev/null \
		&& ./script/test-color \
		&& ./script/test-workflow-parser \
		&& ./script/test-workflow \
		&& ./script/test-tmux-input

test-legacy-tmux:
	cd ori-ii && ./script/test-workflow-tmux \
		&& ./script/test-tmux-popup-input \
		&& ./script/test-tmux-integration

cross-build:
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath -ldflags "$(GO_LDFLAGS)" -o ../$(BUILD_DIR)/ii-go-linux-amd64 $(GO_PACKAGE)
	cd $(GO_DIR) && CGO_ENABLED=0 GOOS=linux GOARCH=arm64 go build -trimpath -ldflags "$(GO_LDFLAGS)" -o ../$(BUILD_DIR)/ii-go-linux-arm64 $(GO_PACKAGE)

clean:
	rm -rf $(BUILD_DIR) export
