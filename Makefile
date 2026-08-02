APP_NAME = Espresso
APP_BUNDLE = $(APP_NAME).app
DIST_DIR = dist
ZIP = $(DIST_DIR)/$(APP_NAME).zip

# Release builds are tagged (v1.2.3); everything else is identified by its
# commit so a bug report from a dev build is still traceable.
VERSION ?= $(shell git describe --tags --exact-match 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo 0.0.0)
BUNDLE_VERSION = $(patsubst v%,%,$(VERSION))

# Empty ARCHS builds for the host only (fast local iteration); the release
# workflow passes ARCHS="arm64 x86_64" for a universal binary. SwiftPM writes
# multi-arch output to a different path than a native build.
ARCHS ?=
ifeq ($(strip $(ARCHS)),)
  ARCH_FLAGS =
  RELEASE_BINARY = .build/release/$(APP_NAME)
else
  ARCH_FLAGS = $(foreach arch,$(ARCHS),--arch $(arch))
  RELEASE_BINARY = .build/apple/Products/Release/$(APP_NAME)
endif

.PHONY: build test app dist install run clean

build:
	swift build -c release $(ARCH_FLAGS)

test:
	swift run EspressoCoreTests

# Wrap the release binary in a minimal .app bundle so macOS treats it as a
# proper menubar-only app (LSUIElement).
app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp $(RELEASE_BINARY) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(BUNDLE_VERSION)" $(APP_BUNDLE)/Contents/Info.plist
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUNDLE_VERSION)" $(APP_BUNDLE)/Contents/Info.plist
	codesign --force --sign - $(APP_BUNDLE)

# Release archive. `ditto -c -k --keepParent` is the only zip that reliably
# round-trips a bundle's symlinks and signature through Gatekeeper.
dist: app
	rm -rf $(DIST_DIR)
	mkdir -p $(DIST_DIR)
	ditto -c -k --sequesterRsrc --keepParent $(APP_BUNDLE) $(ZIP)
	cd $(DIST_DIR) && shasum -a 256 $(APP_NAME).zip > $(APP_NAME).zip.sha256

# Install to /Applications so Login Items registration survives repo rebuilds.
install: app
	rm -rf /Applications/$(APP_BUNDLE)
	ditto $(APP_BUNDLE) /Applications/$(APP_BUNDLE)

run: build
	$(RELEASE_BINARY)

clean:
	rm -rf .build $(APP_BUNDLE) $(DIST_DIR)
