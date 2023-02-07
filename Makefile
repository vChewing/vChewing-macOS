+.PHONY: all

all: release
install: install-release
update:
	@git restore Source/Data/
	git submodule update --init --recursive --remote --force

ifdef ARCHS
BUILD_SETTINGS += ARCHS="$(ARCHS)"
BUILD_SETTINGS += ONLY_ACTIVE_ARCH=NO
endif

release: 
	xcodebuild -project vChewing.xcodeproj -scheme vChewingInstaller -configuration Release $(BUILD_SETTINGS) build

debug: 
	xcodebuild -project vChewing.xcodeproj -scheme vChewingInstaller -configuration Debug $(BUILD_SETTINGS) build

DSTROOT = /Library/Input Methods
VC_APP_ROOT = $(DSTROOT)/vChewing.app

.PHONY: lint format

format:
	@swiftformat --swiftversion 5.5 --indent 2 ./

lint:
	@git ls-files --exclude-standard | grep -E '\.swift$$' | swiftlint --fix --autocorrect

.PHONY: permission-check install-debug install-release

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(VC_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: permission-check
	open Build/Products/Debug/vChewingInstaller.app

install-release: permission-check
	open Build/Products/Release/vChewingInstaller.app

.PHONY: clean

clean:
	xcodebuild -scheme vChewingInstaller -configuration Debug $(BUILD_SETTINGS)  clean
	xcodebuild -scheme vChewingInstaller -configuration Release $(BUILD_SETTINGS) clean
	make clean --file=./Source/Data/Makefile || true

clean-spm:
	find . -name ".build" -exec rm -rf {} \;
	rm -rf ./Packages/Build

.PHONY: gc

gc:
	git reflog expire --expire=now --all && git gc --prune=now --aggressive

.PHONY: test

test:
	xcodebuild -project vChewing.xcodeproj -scheme vChewing -configuration Debug test
