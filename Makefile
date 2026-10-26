APP := AerospaceTabs.app
BIN := .build/release/AerospaceTabs
ARM64_BUILD_PATH := .build/release-arm64
INTEL_BUILD_PATH := .build/release-x86_64
UNIVERSAL_BIN := .build/release-universal/AerospaceTabs
APP_BINARY ?= $(BIN)
CODESIGN_FLAGS ?=
SIGNING_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk '/^[[:space:]]*[0-9]+[^0-9]/ && $$2 ~ /^[[:xdigit:]]+$$/ { print $$2; exit }')
ifeq ($(strip $(SIGNING_IDENTITY)),)
SIGNING_IDENTITY := -
endif

.PHONY: build build-universal assemble-app run kill restore-gaps

build:
	swift build -c release
	$(MAKE) assemble-app APP_BINARY="$(BIN)"

build-universal:
	swift build -c release --triple arm64-apple-macosx14.0 --scratch-path $(ARM64_BUILD_PATH)
	swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path $(INTEL_BUILD_PATH)
	mkdir -p .build/release-universal
	lipo -create \
		"$$(swift build -c release --triple arm64-apple-macosx14.0 --scratch-path $(ARM64_BUILD_PATH) --show-bin-path)/AerospaceTabs" \
		"$$(swift build -c release --triple x86_64-apple-macosx14.0 --scratch-path $(INTEL_BUILD_PATH) --show-bin-path)/AerospaceTabs" \
		-output "$(UNIVERSAL_BIN)"
	lipo "$(UNIVERSAL_BIN)" -verify_arch arm64 x86_64
	$(MAKE) assemble-app APP_BINARY="$(UNIVERSAL_BIN)"

assemble-app:
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$(APP_BINARY)" $(APP)/Contents/MacOS/AerospaceTabs
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	cp Resources/AerospaceTabs.icns $(APP)/Contents/Resources/AerospaceTabs.icns
	test "$$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconFile' $(APP)/Contents/Info.plist)" = "AerospaceTabs.icns"
	test -s "$(APP)/Contents/Resources/AerospaceTabs.icns"
ifdef APP_VERSION
	/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $(APP_VERSION)" $(APP)/Contents/Info.plist
endif
ifdef BUILD_NUMBER
	/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(BUILD_NUMBER)" $(APP)/Contents/Info.plist
endif
	codesign --force $(CODESIGN_FLAGS) --sign "$(SIGNING_IDENTITY)" --identifier com.pedrotmr.AerospaceTabs $(APP)

kill:
	-$(BIN) --restore-gaps 2>/dev/null || true
	-killall AerospaceTabs 2>/dev/null || true

restore-gaps:
	swift build -c release
	$(BIN) --restore-gaps

run: kill build
	open $(APP)
