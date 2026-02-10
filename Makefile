+.PHONY: all

all: release
install: install-release
update:
	@echo "Running lexicon update script for vChewing-macOS..."
	@chmod +x ./Scripts/vchewing-update-lexicon.swift || true
	@if [ "$(DRY_RUN)" = "true" ]; then \
		./Scripts/vchewing-update-lexicon.swift --path . --dry-run; \
	else \
		./Scripts/vchewing-update-lexicon.swift --path .; \
	fi

ifdef ARCHS
BUILD_SETTINGS += ARCHS="$(ARCHS)"
BUILD_SETTINGS += ONLY_ACTIVE_ARCH=NO
endif

# ── SPM-based build targets ──────────────────────────────────────────

spmDebug:
	swift build -c debug

spmRelease:
	swift build -c release

spmLintFormat:
	cd ./Packages/ && make lint --file=./Makefile || true
	cd ./Packages/ && make format --file=./Makefile || true

spmClean:
	swift package clean
	@for currentDir in $$(ls ./Packages/); do \
		if [ -d $$a ]; then \
			echo "processing folder $$currentDir"; \
			swift package clean --package-path ./Packages/$$currentDir || true; \
		fi; \
	done;

spmLinuxTest-Typewriter:
	docker run --rm -v '$(shell pwd):/workspace' -w /workspace/Packages/vChewing_Typewriter swift:latest swift test --filter InputHandlerTests

# ── App Bundle Assembly (via SwiftPM CommandPlugin) ──────────────────

UNIVERSAL_DIR := .build/universal-release
ARM64_DIR     := .build/arm64-apple-macosx/release
X86_64_DIR    := .build/x86_64-apple-macosx/release

universal-build:
	@echo "Building arm64 (Release)..."
	swift build -c release --arch arm64
	@echo "Building x86_64 (Release)..."
	swift build -c release --arch x86_64
	@echo "Creating universal binaries..."
	@mkdir -p $(UNIVERSAL_DIR)
	@lipo -create $(ARM64_DIR)/vChewing $(X86_64_DIR)/vChewing \
		-output $(UNIVERSAL_DIR)/vChewing
	@lipo -create $(ARM64_DIR)/vChewingInstaller $(X86_64_DIR)/vChewingInstaller \
		-output $(UNIVERSAL_DIR)/vChewingInstaller
	@for bundle in $(ARM64_DIR)/*.bundle; do \
		if [ -d "$$bundle" ]; then \
			rm -rf "$(UNIVERSAL_DIR)/$$(basename $$bundle)"; \
			cp -R "$$bundle" $(UNIVERSAL_DIR)/; \
		fi; \
	done
	@echo "  ✓ Universal binaries ready."

release: universal-build
	@echo "Assembling app bundles..."
	swift package --allow-writing-to-package-directory bundle-apps -- --build-dir $(UNIVERSAL_DIR)

archive: universal-build
	@echo "Assembling and archiving app bundles..."
	swift package --allow-writing-to-package-directory bundle-apps -- --build-dir $(UNIVERSAL_DIR) --archive
	@# Move the generated .xcarchive from Build/Products/ to Xcode Archives
	@mkdir -p "$(HOME)/Library/Developer/Xcode/Archives/$$(date +%Y-%m-%d)"
	@for f in Build/Products/*.xcarchive; do \
		if [ -d "$$f" ]; then \
			dest="$(HOME)/Library/Developer/Xcode/Archives/$$(date +%Y-%m-%d)/$$(basename $$f)"; \
			rm -rf "$$dest"; \
			mv "$$f" "$$dest"; \
			echo "  ✓ Moved to $$dest"; \
		fi; \
	done

debug:
	@echo "Building and assembling app bundles (Debug)..."
	swift package --allow-writing-to-package-directory bundle-apps -- --debug

# ── Xcode-based build targets (legacy, requires vChewing.xcodeproj) ──

# 定义日期和时间变量
DATE_DIR := $(shell date +%Y-%m-%d)
DATE_FILE := $(shell date +%Y-%-m-%-d)
TIME_FILE := $(shell date +%H.%M)
ARCHIVE_DIR := $(HOME)/Library/Developer/Xcode/Archives/$(DATE_DIR)
ARCHIVE_NAME := vChewingInstaller-$(DATE_FILE)-$(TIME_FILE).xcarchive
ARCHIVE_PATH := $(ARCHIVE_DIR)/$(ARCHIVE_NAME)

xcode-release:
	@echo "Creating directory: $(ARCHIVE_DIR)"
	@mkdir -p "$(ARCHIVE_DIR)"
	@echo "Archiving to: $(ARCHIVE_PATH)"
	xcodebuild archive \
	-project vChewing.xcodeproj \
	-scheme vChewingInstaller \
	-configuration Release \
	-archivePath "$(ARCHIVE_PATH)" \
	-allowProvisioningUpdates

xcode-debug:
	@echo "Building debug configuration"
	xcodebuild build \
	-project vChewing.xcodeproj \
	-scheme vChewingInstaller \
	-configuration Debug

DSTROOT = /Library/Input Methods
VC_APP_ROOT = $(DSTROOT)/vChewing.app

.PHONY: lint format

format:
	@swiftformat --swiftversion 5.5 --indent 2 ./

lint:
	@echo "Running SwiftLint on tracked Swift files..."
	@files="$$(git ls-files -- '*.swift' ':!Build/**' ':!Packages/Build/**' ':!Packages/**/.build/')"; \
	if [ -z "$$files" ]; then \
		echo "No Swift files tracked by git."; \
	else \
		printf '%s\n' "$$files" | tr '\n' '\0' | \
		xargs -0 swiftlint lint --fix --autocorrect --config .swiftlint.yml --; \
	fi

.PHONY: install-release

install-debug: debug
	open Build/Products/Debug/vChewingInstaller.app

install-release: release
	open Build/Products/Release/vChewingInstaller.app

.PHONY: clean

clean:
	make clean --file=./Packages/Makefile || true
	swift package clean || true
	rm -rf Build/Products || true
	rm -rf .build-universal || true
	make clean --file=./DictionaryData/Makefile || true

clean-spm:
	find . -name ".build" -exec rm -rf {} \;
	rm -rf ./Packages/Build

xcode-clean:
	xcodebuild -scheme vChewingInstaller -configuration Debug $(BUILD_SETTINGS) clean || true
	xcodebuild -scheme vChewingInstaller -configuration Release $(BUILD_SETTINGS) clean || true

gitclean:
	git clean -fdx

.PHONY: gc

gc:
	git reflog expire --expire=now --all && git gc --prune=now --aggressive

.PHONY: test

test:
	swift test
	swift test --package-path ./Packages/vChewing_Typewriter

xcode-test:
	xcodebuild -project vChewing.xcodeproj -scheme vChewing -configuration Debug test

.PHONY: gitrelease

gitrelease:
	@echo "Running git release script for vChewing-macOS..."
	@chmod +x ./Scripts/vchewing-update.swift || true
	@if [ "$(DRY_RUN)" = "true" ]; then \
		./Scripts/vchewing-update.swift --path . --dry-run; \
	else \
		./Scripts/vchewing-update.swift --path .; \
	fi
