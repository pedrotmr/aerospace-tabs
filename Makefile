APP := AerospaceTabs.app
BIN := .build/release/AerospaceTabs
SIGNING_IDENTITY ?= $(shell security find-identity -v -p codesigning 2>/dev/null | awk '/^[[:space:]]*[0-9]+[^0-9]/ && $$2 ~ /^[[:xdigit:]]+$$/ { print $$2; exit }')
ifeq ($(strip $(SIGNING_IDENTITY)),)
SIGNING_IDENTITY := -
endif

.PHONY: build run kill restore-gaps

build:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/AerospaceTabs
	cp Resources/Info.plist $(APP)/Contents/Info.plist
	codesign --force --sign "$(SIGNING_IDENTITY)" --identifier com.pedrotmr.AerospaceTabs $(APP)

kill:
	-$(BIN) --restore-gaps 2>/dev/null || true
	-killall AerospaceTabs 2>/dev/null || true

restore-gaps:
	swift build -c release
	$(BIN) --restore-gaps

run: kill build
	open $(APP)
