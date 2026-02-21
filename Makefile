.PHONY: test bench examples clean help version release-notes release

VERSION := $(shell cat VERSION)
GIT_SHA := $(shell git rev-parse --short HEAD)
DEFINES := -define:VERSION=$(VERSION) -define:GIT_SHA=$(GIT_SHA)

PACKAGES := style table tree logger panel progress spinner term cli

EXAMPLES := cli_app_demo cli_demo hqsub_demo live_demo logger_demo \
            showcase style_demo table_demo \
            tutorial_01_basic tutorial_02_validation tutorial_03_commands \
            tutorial_04_advanced tutorial_05_custom_types

## help: Show this help message
help:
	@echo "Usage: make <target>"
	@echo ""
	@sed -n 's/^## //p' $(MAKEFILE_LIST) | column -t -s ':'

## version: Show version and git SHA
version:
	@echo "$(VERSION)+$(GIT_SHA)"

## release-notes: Extract release notes for current VERSION from CHANGELOG
release-notes:
	@awk '/^## \[$(VERSION)\]/{found=1; next} /^## \[/{if(found) exit} found' CHANGELOG.md

## release: Tag and create GitHub release for current VERSION
release:
	@if git rev-parse "$(VERSION)" >/dev/null 2>&1; then \
		echo "Error: tag $(VERSION) already exists"; exit 1; \
	fi
	git tag -a "$(VERSION)" -m "Release $(VERSION)"
	git push origin "$(VERSION)"
	$(MAKE) release-notes | gh release create "$(VERSION)" --title "$(VERSION)" --notes-file -

## test: Run all package tests
test:
	@fail=0; \
	for pkg in $(PACKAGES); do \
		echo "=== $$pkg ==="; \
		odin test $$pkg/test || fail=1; \
	done; \
	exit $$fail

## bench: Build and run benchmarks
bench:
	odin build bench -out:bench.bin -o:speed && ./bench.bin

## examples: Build all examples
examples:
	@fail=0; \
	for ex in $(EXAMPLES); do \
		echo "=== $$ex ==="; \
		odin build examples/$$ex -out:examples/$$ex/$$ex || fail=1; \
	done; \
	exit $$fail

## clean: Remove build artifacts
clean:
	rm -f bench.bin
	rm -rf bench.bin.dSYM
	rm -f showcase live_demo
	rm -rf showcase.dSYM live_demo.dSYM
	@for ex in $(EXAMPLES); do \
		rm -f examples/$$ex/$$ex; \
		rm -rf examples/$$ex/$$ex.dSYM; \
	done
