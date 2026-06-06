APP_NAME = Espresso
APP_BUNDLE = $(APP_NAME).app
RELEASE_BINARY = .build/release/$(APP_NAME)

.PHONY: build test app install run clean

build:
	swift build -c release

test:
	swift run EspressoCoreTests

# Wrap the release binary in a minimal .app bundle so macOS treats it as a
# proper menubar-only app (LSUIElement).
app: build
	rm -rf $(APP_BUNDLE)
	mkdir -p $(APP_BUNDLE)/Contents/MacOS
	cp Resources/Info.plist $(APP_BUNDLE)/Contents/Info.plist
	cp $(RELEASE_BINARY) $(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)
	codesign --force --sign - $(APP_BUNDLE)

# Install to /Applications so Login Items registration survives repo rebuilds.
install: app
	rm -rf /Applications/$(APP_BUNDLE)
	ditto $(APP_BUNDLE) /Applications/$(APP_BUNDLE)

run: build
	$(RELEASE_BINARY)

clean:
	rm -rf .build $(APP_BUNDLE)
