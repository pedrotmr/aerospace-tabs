PROJECT := AerospaceTabs.xcodeproj
SCHEME := AerospaceTabs
APP_NAME := $(shell sed -n 's/^PRODUCT_NAME = //p' Config/App.xcconfig)
APP_BUNDLE_ID := $(shell sed -n 's/^PRODUCT_BUNDLE_IDENTIFIER = //p' Config/App.xcconfig)
APP_MIN_SYSTEM_VERSION := $(shell sed -n 's/^MACOSX_DEPLOYMENT_TARGET = //p' Config/Project.xcconfig)
RELEASE_OWNER := $(shell sed -n 's/^RELEASE_OWNER = //p' Config/App.xcconfig)
RELEASE_SLUG := $(shell sed -n 's/^RELEASE_SLUG = //p' Config/App.xcconfig)
SPARKLE_KEYCHAIN_ACCOUNT := $(RELEASE_SLUG)
APP_VERSION := $(shell sed -n 's/^APP_MARKETING_VERSION = //p' Config/App.xcconfig)
APP_BUILD_NUMBER ?= 1
DERIVED_DATA := .build/DerivedData
DEBUG_APP := $(DERIVED_DATA)/Build/Products/Debug/$(APP_NAME).app
RELEASE_APP := $(DERIVED_DATA)/Build/Products/Release/$(APP_NAME).app
XCODEBUILD ?= xcodebuild

.PHONY: setup build run test bundle check release-check restore-gaps clean

setup:
	@XCODEBUILD='$(XCODEBUILD)' scripts/setup.sh '$(PROJECT)' '$(SCHEME)'

build:
	@$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED_DATA) APP_MARKETING_VERSION=$(APP_VERSION) \
		APP_BUILD_NUMBER=$(APP_BUILD_NUMBER) CODE_SIGNING_ALLOWED=NO build

run: build
	@open -n "$(DEBUG_APP)"

test:
	@$(XCODEBUILD) test -project $(PROJECT) -scheme $(SCHEME) -configuration Debug \
		-derivedDataPath $(DERIVED_DATA) APP_MARKETING_VERSION=$(APP_VERSION) \
		APP_BUILD_NUMBER=$(APP_BUILD_NUMBER) CODE_SIGNING_ALLOWED=NO

bundle:
	@$(XCODEBUILD) build -project $(PROJECT) -scheme $(SCHEME) -configuration Release \
		-destination 'generic/platform=macOS' -derivedDataPath $(DERIVED_DATA) \
		APP_MARKETING_VERSION=$(APP_VERSION) APP_BUILD_NUMBER=$(APP_BUILD_NUMBER) \
		ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO
	@APP_BUNDLE_ID='$(APP_BUNDLE_ID)' APP_VERSION='$(APP_VERSION)' \
		APP_BUILD_NUMBER='$(APP_BUILD_NUMBER)' APP_MIN_SYSTEM_VERSION='$(APP_MIN_SYSTEM_VERSION)' \
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
		scripts/release-check.sh

restore-gaps: build
	@'$(DEBUG_APP)/Contents/MacOS/$(APP_NAME)' --restore-gaps

clean:
	@rm -rf '$(DERIVED_DATA)' .build/release
