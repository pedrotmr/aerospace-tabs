APP := AerospaceTabs.app
BIN := .build/release/AerospaceTabs

.PHONY: build run kill restore-gaps

build:
	swift build -c release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS
	cp $(BIN) $(APP)/Contents/MacOS/AerospaceTabs
	cp Resources/Info.plist $(APP)/Contents/Info.plist

kill:
	-$(BIN) --restore-gaps 2>/dev/null || true
	-killall AerospaceTabs 2>/dev/null || true

restore-gaps:
	swift build -c release
	$(BIN) --restore-gaps

run: kill build
	open $(APP)
