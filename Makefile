GO_DIR := src
GO_PACKAGE := ./cmd/ii
BUILD_DIR := build
II_GO := $(BUILD_DIR)/ii-go
EXPORT_DIR := export/ii
VERSION := $(shell tr -d '\n' < VERSION)
GO_LDFLAGS := -s -w
PACKAGE_LIBS := \
	lib/ordinary_runtime.zsh \
	lib/ordinary_variables.zsh \
	lib/ordinary_read.zsh \
	lib/ordinary_clipboard.zsh \
	lib/ordinary_get.zsh \
	lib/ordinary_interactive.zsh \
	lib/ordinary_payload_render.zsh \
	lib/ordinary_payload.zsh \
	lib/ordinary_web.zsh \
	lib/ordinary_tmux.zsh \
	lib/ordinary_help.zsh
export GOCACHE := $(CURDIR)/$(BUILD_DIR)/.gocache

.PHONY: all build package package-linux-amd64 fmt-check vet test test-go test-contract test-ordinary-set-tmux test-payload-render-shared test-payload-routing test-web-helpers test-combo-launch test-entry-tmux test-variables-tmux test-variable-output-tmux test-variable-mutations-tmux test-set-tmux test-unset-all-tmux test-load-all-tmux test-get-tmux test-clipboard-tmux test-tmux-install test-tmux-popup test-tmux-popup-interactive test-tmux-status test-payload-input-usage-tmux clean

all: package

build:
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && CGO_ENABLED=0 go build -trimpath \
		-ldflags "$(GO_LDFLAGS)" \
		-o ../$(II_GO) $(GO_PACKAGE)

package: build
	rm -rf $(EXPORT_DIR)
	mkdir -p $(EXPORT_DIR)/lib $(EXPORT_DIR)/script
	cp ii.plugin.zsh README.md VERSION $(EXPORT_DIR)/
	cp -R help $(EXPORT_DIR)/help
	cp $(PACKAGE_LIBS) $(EXPORT_DIR)/lib/
	cp $(II_GO) $(EXPORT_DIR)/ii-go
	cp -R payloads $(EXPORT_DIR)/payloads
	cp script/ii-tmux-popup $(EXPORT_DIR)/script/
	find $(EXPORT_DIR) -type f -name '.gitkeep' -delete
	printf 'ii %s\nruntime=zsh\ncombo_helper=ii-go\npayload_data=root\n' "$(VERSION)" > $(EXPORT_DIR)/RELEASE

package-linux-amd64:
	mkdir -p $(BUILD_DIR)
	cd $(GO_DIR) && CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -trimpath \
		-ldflags "$(GO_LDFLAGS)" \
		-o ../$(BUILD_DIR)/ii-go-linux-amd64 $(GO_PACKAGE)
	rm -rf export/linux-amd64
	mkdir -p export/linux-amd64/ii/lib export/linux-amd64/ii/script
	cp ii.plugin.zsh README.md VERSION export/linux-amd64/ii/
	cp -R help export/linux-amd64/ii/help
	cp $(PACKAGE_LIBS) export/linux-amd64/ii/lib/
	cp $(BUILD_DIR)/ii-go-linux-amd64 export/linux-amd64/ii/ii-go
	cp -R payloads export/linux-amd64/ii/payloads
	cp script/ii-tmux-popup export/linux-amd64/ii/script/
	find export/linux-amd64/ii -type f -name '.gitkeep' -delete
	printf 'ii %s\nruntime=zsh\ncombo_helper=ii-go\narchitecture=linux-amd64\npayload_data=root\n' \
		"$(VERSION)" > export/linux-amd64/ii/RELEASE

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

test-ordinary-set-tmux:
	./test/contract/ordinary-set-tmux

test-payload-render-shared:
	./test/contract/payload-render-shared

test-payload-routing:
	./test/contract/payload-routing

test-web-helpers:
	./test/contract/web-helpers

test-combo-launch:
	./test/contract/combo-launch

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

test-clipboard-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/clipboard-tmux

test-tmux-install: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/tmux-install

test-tmux-popup:
	./test/contract/tmux-popup

test-tmux-popup-interactive:
	./test/contract/tmux-popup-interactive

test-tmux-status: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/tmux-status

test-payload-input-usage-tmux: build
	II_GO_BIN="$(CURDIR)/$(II_GO)" ./test/contract/payload-input-usage-tmux

test: fmt-check vet test-go test-payload-render-shared test-payload-routing test-web-helpers test-combo-launch test-contract

clean:
	rm -rf $(BUILD_DIR) export
