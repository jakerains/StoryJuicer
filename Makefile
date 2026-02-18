SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help doctor generate build build-release run run-release clean app-path

help:
	@echo "StoryJuicer commands:"
	@echo "  make doctor        Check local toolchain and SDK readiness"
	@echo "  make build         Generate project and build Debug app"
	@echo "  make run           Build and open Debug app"
	@echo "  make build-release Build Release app"
	@echo "  make run-release   Build and open Release app"
	@echo "  make clean         Clean Xcode build artifacts"
	@echo "  make app-path      Print built Debug .app bundle path"
	@echo ""
	@echo "Note: this is an Xcode project app target, so use make/xcodebuild (not swift run)."

doctor:
	./scripts/doctor.sh

generate:
	./scripts/generate.sh

build:
	./scripts/build.sh

build-release:
	./scripts/build.sh --release

run:
	./scripts/run.sh

run-release:
	./scripts/run.sh --release

clean:
	xcodebuild -project StoryJuicer.xcodeproj -scheme StoryJuicer -destination 'platform=macOS' clean

app-path:
	@xcodebuild \
		-project StoryJuicer.xcodeproj \
		-scheme StoryJuicer \
		-configuration Debug \
		-destination 'platform=macOS' \
		-showBuildSettings | awk -F' = ' '\
			/TARGET_BUILD_DIR = / { target=$$2 } \
			/WRAPPER_NAME = / { wrapper=$$2 } \
			END { if (target != "" && wrapper != "") print target "/" wrapper }'
