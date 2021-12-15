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
	xcodebuild -project McBopomofo.xcodeproj -scheme McBopomofoInstaller -configuration Release $(BUILD_SETTINGS) build

debug: 
	xcodebuild -project McBopomofo.xcodeproj -scheme McBopomofoInstaller -configuration Debug $(BUILD_SETTINGS) build

DSTROOT = /Library/Input Methods
VC_APP_ROOT = $(DSTROOT)/McBopomofo.app

.PHONY: permission-check install-debug install-release

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(VC_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: permission-check
	rm -rf "$(VC_APP_ROOT)"
	open Build/Products/Debug/McBopomofoInstaller.app

install-release: permission-check
	rm -rf "$(VC_APP_ROOT)"
	open Build/Products/Release/McBopomofoInstaller.app

.PHONY: clean

clean:
	xcodebuild -scheme McBopomofoInstaller -configuration Debug $(BUILD_SETTINGS)  clean
	xcodebuild -scheme McBopomofoInstaller -configuration Release $(BUILD_SETTINGS) clean
	make clean --file=./Source/Data/Makefile || true
