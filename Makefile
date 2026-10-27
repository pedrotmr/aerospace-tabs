PROJECT := AerospaceTabs.xcodeproj
SCHEME := AerospaceTabs
APP_NAME := $(shell sed -n 's/^PRODUCT_NAME = //p' Config/App.xcconfig)
APP_BUNDLE_ID := $(shell sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER = //p' Config/App.xcconfig)
APP_MIN_SYSTEM_VERSION := $(shell sed -n 's/^MACOSX_DEPLOYMENT_TARGET = //p' Config/Project.xcconfig)
SPARKLE_PUBLIC_ED_KEY := $(shell sed -n 's/^SPARKLE_PUBLIC_ED_KEY = //p' Config/App.xcconfig)
SPARKLE_ENABLED := $(shell sed -n 's/^SPARKLE_ENABLED = //p' Config/App.xcconfig)
RELEASE_OWNER := $(shell sed -n 's/^RELEASE_OWNER = //p' Config/App.xcconfig)
RELEASE_SLUG := $(shell sed -n 's/^RELEASE_SLUG = //p' Config/App.xcconfig)
SPARKLE_FEED_URL := https://github.com/$(RELEASE_OWNER)/$(RELEASE_SLUG)/releases/latest/download/appcast.xml
SPARKLE_KEYCHAIN_ACCOUNT := $(RELEASE_SLUG)
APP_VERSION := $(shell sed -n 's/^APP_MARKETING_VERSION = //p' Config/App.xcconfig)
APP_BUILD_NUMBER ?= $(shell sed -n 's/^APP_BUILD_NUMBER = //p' Config/App.xcconfig)
DERIVED_DATA := .build/DerivedData
DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app
XCODEBUILD ?= xcodebuild
PYTHON ?= python3

.PHONY: setup build run test bundle check release-check restore-gaps clean

setup:
	@XCODEBUILD='$(XCODEBUILD)' scripts/setup.sh '$(PROJECT)' '$(SCHEME)'

build:
	@$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED_DATA) APP_MARKETING_VERSION=$(APP_VERSION) \
		APP_BUILD_NUMBER=$(APP_BUILD_NUMBER) CODE_SIGNING_ALLOWED=NO build

run: build
	@if /usr/bin/pgrep -x '$(APP_NAME)' >/dev/null 2>&1; then \
		/usr/bin/osascript -e 'tell application id "$(APP_BUNDLE_ID)" to quit' >/dev/null 2>&1 || true; \
		attempt=0; \
		while /usr/bin/pgrep -x '$(APP_NAME)' >/dev/null 2>&1 && [ $$attempt -lt 50 ]; do \
			sleep 0.2; attempt=$$((attempt + 1)); \
		done; \
		if /usr/bin/pgrep -x '$(APP_NAME)' >/dev/null 2>&1; then \
			echo 'Aerospace Tabs did not quit. Close it before running the new build.' >&2; exit 1; \
		fi; \
	fi
	@open -n "$(DEBUG_APP)"

test:
	@$(XCODEBUILD) test -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED_DATA) APP_MARKETING_VERSION=$(APP_VERSION) \
		APP_BUILD_NUMBER=$(APP_BUILD_NUMBER) CODE_SIGNING_ALLOWED=NO
	@$(PYTHON) -m unittest discover -s scripts/tests -p 'test_*.py'

bundle:
	@$(XCODEBUILD) build -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=macOS' -derivedDataPath $(DERIVED_DATA) \
		APP_MARKETING_VERSION=$(APP_VERSION) APP_BUILD_NUMBER=$(APP_BUILD_NUMBER) \
		ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO
	@APP_BUNDLE_ID='$(APP_BUNDLE_ID)' APP_VERSION='$(APP_VERSION)' \
		APP_BUILD_NUMBER='$(APP_BUILD_NUMBER)' APP_MIN_SYSTEM_VERSION='$(APP_MIN_SYSTEM_VERSION)' \
		SPARKLE_ENABLED='$(SPARKLE_ENABLED)' SPARKLE_FEED_URL='$(SPARKLE_FEED_URL)' \
		SPARKLE_PUBLIC_ED_KEY='$(SPARKLE_PUBLIC_ED_KEY)' \
		scripts/check-app-bundle.sh '$(RELEASE_APP)'

check:
	@$(MAKE) setup
	@$(MAKE) test
	@$(MAKE) bundle

release-check:
	@env -u APPLE_NOTARY_KEY_P8_BASE64 -u APPLE_NOTARY_KEY_ID \
		-u APPLE_NOTARY_ISSUER_ID -u SPARKLE_PRIVATE_KEY $(MAKE) setup
	@if [ '$(origin APP_BUILD_NUMBER)' = file ]; then \
		echo 'Set APP_BUILD_NUMBER to a new, increasing numeric value for a signed release check.' >&2; exit 2; \
	fi
	@APP_PROJECT='$(PROJECT)' APP_SCHEME='$(SCHEME)' APP_NAME='$(APP_NAME)' \
		APP_BUNDLE_ID='$(APP_BUNDLE_ID)' APP_MIN_SYSTEM_VERSION='$(APP_MIN_SYSTEM_VERSION)' \
		APP_VERSION='$(APP_VERSION)' APP_BUILD_NUMBER='$(APP_BUILD_NUMBER)' \
		RELEASE_OWNER='$(RELEASE_OWNER)' RELEASE_SLUG='$(RELEASE_SLUG)' \
		SPARKLE_KEYCHAIN_ACCOUNT='$(SPARKLE_KEYCHAIN_ACCOUNT)' \
		SPARKLE_ENABLED='$(SPARKLE_ENABLED)' SPARKLE_FEED_URL='$(SPARKLE_FEED_URL)' \
		SPARKLE_PUBLIC_ED_KEY='$(SPARKLE_PUBLIC_ED_KEY)' \
		scripts/release-check.sh

restore-gaps: build
	@'$(DEBUG_APP)/Contents/MacOS/$(APP_NAME)' --restore-gaps

clean:
	@rm -rf '$(DERIVED_DATA)' .build/release
