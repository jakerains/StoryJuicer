SHELL := /bin/bash

.DEFAULT_GOAL := help

.PHONY: help doctor purge-image-cache generate build build-release run run-release clean app-path dmg build-ios run-ios sparkle-setup appcast sign-update

help:
	@echo "StoryFox commands:"
	@echo "  make doctor        Check local toolchain and SDK readiness"
	@echo "  make purge-image-cache  Remove local Diffusers runtime/model cache data"
	@echo "  make build         Generate project and build Debug app"
	@echo "  make run           Build and open Debug app"
	@echo "  make build-release Build Release app"
	@echo "  make run-release   Build and open Release app"
	@echo "  make dmg           Build, sign, notarize, and package a distributable DMG"
	@echo "  make build-ios     Build iOS Simulator Debug app"
	@echo "  make run-ios       Build and launch in iOS Simulator"
	@echo "  make clean         Clean Xcode build artifacts"
	@echo "  make app-path      Print built Debug .app bundle path"
	@echo ""
	@echo "Sparkle auto-update:"
	@echo "  make sparkle-setup Generate EdDSA key pair (one-time setup)"
	@echo "  make appcast       Regenerate appcast.xml from DMGs in dist/"
	@echo "  make sign-update   Print EdDSA signature for a DMG (usage: make sign-update DMG=dist/StoryFox.dmg)"
	@echo ""
	@echo "Note: this is an Xcode project app target, so use make/xcodebuild (not swift run)."

doctor:
	./scripts/doctor.sh

purge-image-cache:
	bash ./scripts/purge_diffusers_cache.sh

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
	xcodebuild -project StoryFox.xcodeproj -scheme StoryFox -destination 'platform=macOS' clean

app-path:
	@xcodebuild \
		-project StoryFox.xcodeproj \
		-scheme StoryFox \
		-configuration Debug \
		-destination 'platform=macOS' \
		-showBuildSettings | awk -F' = ' '\
			/TARGET_BUILD_DIR = / { target=$$2 } \
			/WRAPPER_NAME = / { wrapper=$$2 } \
			END { if (target != "" && wrapper != "") print target "/" wrapper }'

# ── iOS Targets ─────────────────────────────────────────────────────

IOS_SCHEME := StoryFox-iOS
IOS_SIM_DEST := platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0

build-ios: generate
	xcodebuild build \
		-project StoryFox.xcodeproj \
		-scheme $(IOS_SCHEME) \
		-destination '$(IOS_SIM_DEST)' \
		-configuration Debug

run-ios: build-ios
	@echo "──── Launching in iOS Simulator ────"
	@xcrun simctl boot "iPhone 16 Pro" 2>/dev/null || true
	@open -a Simulator
	@APP_PATH=$$(xcodebuild \
		-project StoryFox.xcodeproj \
		-scheme $(IOS_SCHEME) \
		-configuration Debug \
		-destination '$(IOS_SIM_DEST)' \
		-showBuildSettings 2>/dev/null | awk -F' = ' '\
			/TARGET_BUILD_DIR = / { target=$$2 } \
			/WRAPPER_NAME = / { wrapper=$$2 } \
			END { if (target != "" && wrapper != "") print target "/" wrapper }') && \
	xcrun simctl install booted "$$APP_PATH" && \
	xcrun simctl launch booted com.jakerains.StoryFox

# ── Distributable DMG ────────────────────────────────────────────────
# Signs with Developer ID, notarizes with Apple, staples the ticket,
# and packages into a DMG ready for distribution.
#
# Prerequisites (one-time):
#   xcrun notarytool store-credentials "StoryFox-Notarize" \
#     --apple-id <email> --team-id <team> --password <app-specific-pw>

SIGN_IDENTITY := "Developer ID Application: Jacob RAINS (47347VQHQV)"
TEAM_ID       := 47347VQHQV
NOTARY_PROFILE := StoryFox-Notarize
DMG_DIR       := dist
APP_NAME      := StoryFox

dmg:
	@echo "──── 1/7  Preparing output directory ────"
	@mkdir -p $(DMG_DIR)/export
	@rm -rf $(DMG_DIR)/$(APP_NAME).xcarchive $(DMG_DIR)/export/$(APP_NAME).app
	@echo ""
	@echo "──── 2/7  Regenerating Xcode project ────"
	xcodegen generate
	@# Restore entitlements (xcodegen overwrites them to empty <dict/>)
	@# PlistBuddy handles dotted keys; plutil treats dots as path separators
	@rm -f Resources/StoryFox.entitlements
	@/usr/libexec/PlistBuddy -c "Add :com.apple.security.network.client bool true" Resources/StoryFox.entitlements
	@/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.allow-jit bool true" Resources/StoryFox.entitlements
	@/usr/libexec/PlistBuddy -c "Add :com.apple.security.cs.allow-unsigned-executable-memory bool true" Resources/StoryFox.entitlements
	@echo "    Entitlements restored."
	@echo ""
	@echo "──── 3/7  Building Release archive ────"
	@echo "       (This may take several minutes for a full Release build)"
	xcodebuild archive \
		-project $(APP_NAME).xcodeproj \
		-scheme $(APP_NAME) \
		-destination 'generic/platform=macOS' \
		-archivePath $(DMG_DIR)/$(APP_NAME).xcarchive \
		DEVELOPMENT_TEAM=$(TEAM_ID) \
		CODE_SIGN_IDENTITY=$(SIGN_IDENTITY) \
		CODE_SIGN_STYLE=Manual \
		OTHER_CODE_SIGN_FLAGS="--timestamp --options runtime"
	@echo ""
	@echo "──── 4/7  Exporting signed app ────"
	@# Create ExportOptions plist using plutil (no fragile PlistBuddy/heredocs)
	@plutil -create xml1 $(DMG_DIR)/ExportOptions.plist
	@plutil -insert method -string developer-id $(DMG_DIR)/ExportOptions.plist
	@plutil -insert teamID -string $(TEAM_ID) $(DMG_DIR)/ExportOptions.plist
	@plutil -insert signingStyle -string manual $(DMG_DIR)/ExportOptions.plist
	@plutil -insert signingCertificate -string "Developer ID Application" $(DMG_DIR)/ExportOptions.plist
	xcodebuild -exportArchive \
		-archivePath $(DMG_DIR)/$(APP_NAME).xcarchive \
		-exportPath $(DMG_DIR)/export \
		-exportOptionsPlist $(DMG_DIR)/ExportOptions.plist
	@echo ""
	@echo "──── 5/7  Notarizing app with Apple ────"
	ditto -c -k --keepParent "$(DMG_DIR)/export/$(APP_NAME).app" "$(DMG_DIR)/$(APP_NAME).zip"
	xcrun notarytool submit "$(DMG_DIR)/$(APP_NAME).zip" \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	@echo ""
	@echo "──── 6/7  Stapling notarization ticket ────"
	xcrun stapler staple "$(DMG_DIR)/export/$(APP_NAME).app"
	@echo ""
	@echo "──── 7/7  Creating DMG with drag-to-Applications ────"
	@rm -f "$(DMG_DIR)/$(APP_NAME).dmg"
	@rm -rf /tmp/storyfox_dmg_staging
	@mkdir -p /tmp/storyfox_dmg_staging
	@cp -R "$(DMG_DIR)/export/$(APP_NAME).app" /tmp/storyfox_dmg_staging/
	@ln -s /Applications /tmp/storyfox_dmg_staging/Applications
	hdiutil create -volname "$(APP_NAME)" -srcfolder /tmp/storyfox_dmg_staging -ov -format UDZO "$(DMG_DIR)/$(APP_NAME).dmg"
	@rm -rf /tmp/storyfox_dmg_staging
	xcrun notarytool submit "$(DMG_DIR)/$(APP_NAME).dmg" \
		--keychain-profile "$(NOTARY_PROFILE)" \
		--wait
	xcrun stapler staple "$(DMG_DIR)/$(APP_NAME).dmg"
	@echo ""
	@echo "✅ Done! Distributable DMG: $(DMG_DIR)/$(APP_NAME).dmg"
	@rm -f "$(DMG_DIR)/$(APP_NAME).zip" "$(DMG_DIR)/ExportOptions.plist"

# ── Sparkle Auto-Update Tooling ─────────────────────────────────────
# Sparkle CLI tools (generate_keys, generate_appcast, sign_update)
# live inside the resolved SPM package in DerivedData.

SPARKLE_BIN_DIR = $(shell find ~/Library/Developer/Xcode/DerivedData -path "*/Sparkle/bin" -type d 2>/dev/null | head -1)
GITHUB_REPO_URL := https://github.com/jakerains/StoryFox/releases/download

sparkle-setup:
	@if [ -z "$(SPARKLE_BIN_DIR)" ]; then \
		echo "Error: Sparkle bin directory not found in DerivedData."; \
		echo "Run 'make build' first so SPM resolves the Sparkle package."; \
		exit 1; \
	fi
	@echo "──── Generating EdDSA key pair ────"
	@echo "The private key will be stored in your Keychain."
	@echo "Copy the public key printed below into project.yml as INFOPLIST_KEY_SUPublicEDKey."
	@echo ""
	"$(SPARKLE_BIN_DIR)/generate_keys"

appcast:
	@if [ -z "$(SPARKLE_BIN_DIR)" ]; then \
		echo "Error: Sparkle bin directory not found in DerivedData."; \
		echo "Run 'make build' first so SPM resolves the Sparkle package."; \
		exit 1; \
	fi
	@echo "──── Regenerating appcast.xml ────"
	"$(SPARKLE_BIN_DIR)/generate_appcast" \
		--download-url-prefix "$(GITHUB_REPO_URL)/v$$(plutil -extract CFBundleShortVersionString raw $(DMG_DIR)/export/$(APP_NAME).app/Contents/Info.plist)/" \
		-o appcast.xml \
		$(DMG_DIR)
	@echo "✅ appcast.xml updated. Commit and push to main."

sign-update:
	@if [ -z "$(SPARKLE_BIN_DIR)" ]; then \
		echo "Error: Sparkle bin directory not found in DerivedData."; \
		echo "Run 'make build' first so SPM resolves the Sparkle package."; \
		exit 1; \
	fi
	@if [ -z "$(DMG)" ]; then \
		echo "Usage: make sign-update DMG=dist/StoryFox.dmg"; \
		exit 1; \
	fi
	"$(SPARKLE_BIN_DIR)/sign_update" "$(DMG)"
