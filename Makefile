APPLICATIONS_DIR ?= /Applications
BUILD_DIR ?= $(CURDIR)/build
APP := $(BUILD_DIR)/Build/Products/Release/JRectangle.app

.PHONY: build install

build:
	@echo "Building JRectangle..."
	@set -eu; \
	identity=$$(/bin/sh scripts/local-signing-identity.sh); \
	xcodebuild -quiet -project Rectangle.xcodeproj -scheme Rectangle \
		-configuration Release -destination "platform=macOS,arch=$$(uname -m)" \
		-derivedDataPath "$(BUILD_DIR)" build; \
	codesign --force --sign "$$identity" --timestamp=none --options runtime \
		--entitlements Rectangle/RectangleRelease.entitlements "$(APP)"; \
	codesign --verify --deep --strict "$(APP)"

install: build
	@set -eu; \
	target="$(APPLICATIONS_DIR)/JRectangle.app"; \
	if pgrep -f "$$target/Contents/MacOS/JRectangle" >/dev/null; then \
		echo "Quit JRectangle at $$target before installing." >&2; exit 1; \
	fi; \
	staging=$$(mktemp -d "$(APPLICATIONS_DIR)/.JRectangle-install.XXXXXX") || { \
		echo "Cannot write to $(APPLICATIONS_DIR). Check its permissions." >&2; exit 1; \
	}; \
	echo "Preparing installation in $$staging"; \
	ditto "$(APP)" "$$staging/JRectangle.app"; \
	codesign --verify --deep --strict "$$staging/JRectangle.app"; \
	backup=""; \
	if [ -e "$$target" ] || [ -L "$$target" ]; then \
		backup=$$(mktemp -d "$(APPLICATIONS_DIR)/JRectangle-backup.XXXXXX"); \
		mv "$$target" "$$backup/JRectangle.app"; \
		echo "Previous app backed up to $$backup/JRectangle.app"; \
	fi; \
	if ! mv "$$staging/JRectangle.app" "$$target"; then \
		if [ -n "$$backup" ]; then \
			mv "$$backup/JRectangle.app" "$$target" || \
				echo "Could not restore the previous app from $$backup/JRectangle.app" >&2; \
		fi; \
		echo "Installation failed; prepared app remains in $$staging." >&2; exit 1; \
	fi; \
	rmdir "$$staging"; \
	echo "Installed $$target"
