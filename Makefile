SHELL := /bin/bash

.PHONY: help preflight test version resolve-packages archive upload release clean-release

help:
	@./scripts/release.sh help

preflight test:
	@./scripts/release.sh preflight

version:
	@test -n "$(VERSION)" || (echo "Usage: make version VERSION=1.3.0 [BUILD=8]" >&2; exit 1)
	@./scripts/release.sh version "$(VERSION)" "$(BUILD)"

resolve-packages:
	@./scripts/release.sh resolve-packages

archive:
	@./scripts/release.sh archive

upload:
	@./scripts/release.sh upload

release:
	@./scripts/release.sh release

clean-release:
	@./scripts/release.sh clean
