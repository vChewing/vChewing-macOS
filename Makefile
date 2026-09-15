.PHONY: all

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
		if [ -d "./Packages/$$currentDir" ]; then \
			echo "processing folder $$currentDir"; \
			swift package clean --package-path "./Packages/$$currentDir" || true; \
		fi; \
	done;
	@# 聚合體目錄內之巢狀子套件（`<聚合體>/Deps/<子套件>`）：僅在直接對其建置時才會生成
	@# 獨立的 .build，故須一併清掃，否則殘留物件會在下一次建置造成假失敗。
	@for nestedDep in ./Packages/*/Deps/*; do \
		if [ -f "$$nestedDep/Package.swift" ]; then \
			echo "processing nested dep $$nestedDep"; \
			swift package clean --package-path "$$nestedDep" || true; \
		fi; \
	done;
	@# Swift 5.10 側的 scratch：逐包入口在套件目錄內建 `.build/.legacy*`，倉根入口（`build510-<pkg>`）
	@# 則建在倉根 `.build/.legacy-<pkg>`。此處只清 `.legacy*`，不動 `.build` 內其餘既有產物。
	@rm -rf ./.build/.legacy-* ./Packages/*/.build/.legacy* ./Packages/*/Deps/*/.build/.legacy*

spmLinuxTest-LibVanguard:
	docker run --rm -v '$(shell pwd):/workspace' -w /workspace/Packages/vChewing_OSNeutral_LibVanguard swift:latest swift test --filter InputHandlerTests

# ── Swift 5.10 (legacy) build entry points ───────────────────────────
#
# The per-package entry points live in each package's own `makefile`; `Packages/Makefile` carries
# the aggregate loop. This is only a thin forwarder so that `make build510` works at the repo root.

.PHONY: build510 clean510

build510:
	cd ./Packages/ && make build510-all --file=./Makefile

clean510:
	cd ./Packages/ && make clean510-all --file=./Makefile

# ── App Bundle Assembly (via SwiftPM CommandPlugin) ──────────────────

UNIVERSAL_DIR := .build/universal-release
ARM64_DIR     := .build/arm64-apple-macosx/release
X86_64_DIR    := .build/x86_64-apple-macosx/release
NEXUS_DIR     := .build/out/Products/release
# Active macOS SDK version, used to re-stamp LC_BUILD_VERSION.sdk on the universal executables.
# SwiftPM otherwise records the deployment target as the sdk, which makes macOS Tahoe treat the
# IME as a legacy app and disables the Liquid Glass appearance; bundle-apps re-signs afterward.
MACOS_SDK_VER := $(shell xcrun --sdk macosx --show-sdk-version 2>/dev/null)

universal-build:
	@# Remove previously-built binary artifacts from ARM64_DIR, X86_64_DIR, and NEXUS_DIR.
	@rm -f $(ARM64_DIR)/vChewing $(ARM64_DIR)/vChewingInstaller
	@rm -f $(X86_64_DIR)/vChewing $(X86_64_DIR)/vChewingInstaller
	@rm -f $(NEXUS_DIR)/vChewing $(NEXUS_DIR)/vChewingInstaller
	@# Dynamic products (`Product.library(type: .dynamic)`) are architecture-specific, so
	@# stale copies must go as well — a leftover dylib would otherwise be lipo'd and embedded.
	@rm -f $(ARM64_DIR)/*.dylib $(X86_64_DIR)/*.dylib
	@echo "Building arm64 (Release)..."
	@mkdir -p $(NEXUS_DIR)
	@touch $(NEXUS_DIR)/.pre-build-marker
	swift build -c release --arch arm64
	@# Check whether the built binary is at the Nexus path and its modified time is fresh. If these conditions are met, copy it to ARM64_DIR.
	@if [ -f $(NEXUS_DIR)/vChewing ] && [ $(NEXUS_DIR)/vChewing -nt $(NEXUS_DIR)/.pre-build-marker ]; then \
		mkdir -p $(ARM64_DIR); \
		cp -f $(NEXUS_DIR)/vChewing $(ARM64_DIR)/vChewing; \
	fi
	@if [ -f $(NEXUS_DIR)/vChewingInstaller ] && [ $(NEXUS_DIR)/vChewingInstaller -nt $(NEXUS_DIR)/.pre-build-marker ]; then \
		mkdir -p $(ARM64_DIR); \
		cp -f $(NEXUS_DIR)/vChewingInstaller $(ARM64_DIR)/vChewingInstaller; \
	fi
	@# Resource bundles are arch-independent but in Swift 6.4 also land only in the Nexus path; copy them to ARM64_DIR so the later bundle loop finds them.
	@for bundle in $(NEXUS_DIR)/*.bundle; do \
		if [ -d "$$bundle" ]; then \
			mkdir -p $(ARM64_DIR); \
			cp -R "$$bundle" $(ARM64_DIR)/; \
		fi; \
	done
	@# Dynamic products are architecture-specific: keep this arch's copies for the later lipo pass.
	@for dylib in $(NEXUS_DIR)/*.dylib; do \
		if [ -f "$$dylib" ]; then \
			mkdir -p $(ARM64_DIR); \
			cp -f "$$dylib" $(ARM64_DIR)/; \
		fi; \
	done
	@echo "Building x86_64 (Release)..."
	@touch $(NEXUS_DIR)/.pre-build-marker
	swift build -c release --arch x86_64
	@# Check whether the built binary is at the Nexus path and its modified time is fresh. If these conditions are met, copy it to X86_64_DIR.
	@if [ -f $(NEXUS_DIR)/vChewing ] && [ $(NEXUS_DIR)/vChewing -nt $(NEXUS_DIR)/.pre-build-marker ]; then \
		mkdir -p $(X86_64_DIR); \
		cp -f $(NEXUS_DIR)/vChewing $(X86_64_DIR)/vChewing; \
	fi
	@if [ -f $(NEXUS_DIR)/vChewingInstaller ] && [ $(NEXUS_DIR)/vChewingInstaller -nt $(NEXUS_DIR)/.pre-build-marker ]; then \
		mkdir -p $(X86_64_DIR); \
		cp -f $(NEXUS_DIR)/vChewingInstaller $(X86_64_DIR)/vChewingInstaller; \
	fi
	@for dylib in $(NEXUS_DIR)/*.dylib; do \
		if [ -f "$$dylib" ]; then \
			mkdir -p $(X86_64_DIR); \
			cp -f "$$dylib" $(X86_64_DIR)/; \
		fi; \
	done
	@echo "Creating universal binaries..."
	@mkdir -p $(UNIVERSAL_DIR)
	@lipo -create $(ARM64_DIR)/vChewing $(X86_64_DIR)/vChewing \
		-output $(UNIVERSAL_DIR)/vChewing
	@lipo -create $(ARM64_DIR)/vChewingInstaller $(X86_64_DIR)/vChewingInstaller \
		-output $(UNIVERSAL_DIR)/vChewingInstaller
	@# Dynamic products need their own per-arch lipo: the bundles below are arch-independent,
	@# the executables are handled above, and neither loop would carry a `.dylib` across.
	@for dylib in $(ARM64_DIR)/*.dylib; do \
		if [ -f "$$dylib" ]; then \
			name=$$(basename "$$dylib"); \
			if [ -f "$(X86_64_DIR)/$$name" ]; then \
				lipo -create "$(ARM64_DIR)/$$name" "$(X86_64_DIR)/$$name" \
					-output "$(UNIVERSAL_DIR)/$$name"; \
			else \
				echo "  ⚠️  dylib $$name has no x86_64 slice; copying arm64 only."; \
				cp -f "$(ARM64_DIR)/$$name" "$(UNIVERSAL_DIR)/$$name"; \
			fi; \
		fi; \
	done
	@for bundle in $(ARM64_DIR)/*.bundle; do \
		if [ -d "$$bundle" ]; then \
			rm -rf "$(UNIVERSAL_DIR)/$$(basename $$bundle)"; \
			cp -R "$$bundle" $(UNIVERSAL_DIR)/; \
		fi; \
	done
	@# Re-stamp LC_BUILD_VERSION so the sdk field reflects the real macOS SDK (e.g. 27.0) while
	@# preserving the deployment target as minos. SwiftPM writes the deployment target into sdk,
	@# which disables Liquid Glass on macOS Tahoe; bundle-apps re-signs the assembled apps afterward.
	@for bin in vChewing vChewingInstaller; do \
		minos=$$(otool -l -arch arm64 $(UNIVERSAL_DIR)/$$bin 2>/dev/null | awk '/LC_BUILD_VERSION/{f=1} f && /minos/{print $$2; exit}'); \
		vtool -set-build-version macos $$minos $(MACOS_SDK_VER) \
			-output $(UNIVERSAL_DIR)/$$bin.tmp $(UNIVERSAL_DIR)/$$bin && \
		mv $(UNIVERSAL_DIR)/$$bin.tmp $(UNIVERSAL_DIR)/$$bin; \
	done
	@echo "  ✓ Universal binaries ready."

release: universal-build
	@echo "Assembling app bundles..."
	swift package --allow-writing-to-package-directory bundle-apps -- --build-dir $(UNIVERSAL_DIR)

pkg: archive
	@echo "Building PKG installer..."
	./BuildPKG.sh

pkg-signed: archive
	@echo "Building signed and notarized PKG installer..."
	./BuildPKG.sh --sign

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

# Pin LC_ALL so CJK collation stays identical regardless of the machine's locale settings.
.PHONY: lint format lintFormat lintFormatUncommitted

format:
	@export LC_ALL=C; swiftformat --swiftversion 5.5 --indent 2 ./

lint:
	@export LC_ALL=C; \
	echo "Running SwiftLint on tracked Swift files..."; \
	files="$$(git ls-files -- '*.swift' ':!Build/**' ':!Packages/Build/**' ':!Packages/**/.build/')"; \
	if [ -z "$$files" ]; then \
		echo "No Swift files tracked by git."; \
	else \
		printf '%s\n' "$$files" | tr '\n' '\0' | \
		xargs -0 swiftlint lint --fix --autocorrect --config .swiftlint.yml --; \
	fi

lintFormat: lint format

lintFormatUncommitted:
	@export LC_ALL=C; \
	echo "Running SwiftFormat & SwiftLint on uncommitted tracked Swift files..."; \
	files="$$(git diff --name-only HEAD -- '*.swift' ':!Build/**' ':!Packages/Build/**' ':!Packages/**/.build/' | while IFS= read -r f; do [ -f "$$f" ] && printf '%s\n' "$$f"; done)"; \
	if [ -z "$$files" ]; then \
		echo "No uncommitted Swift files tracked by git."; \
	else \
		printf '%s\n' "$$files" | tr '\n' '\0' | xargs -0 swiftlint lint --fix --autocorrect --config .swiftlint.yml --; \
		printf '%s\n' "$$files" | tr '\n' '\0' | xargs -0 swiftformat --swiftversion 5.5 --indent 2; \
	fi

.PHONY: install-release

install-debug: debug
	open Build/Products/Debug/vChewingInstaller.app

install-release: release
	open Build/Products/Release/vChewingInstaller.app

.PHONY: clean

clean:
	cd ./Packages/ && make clean --file=./Makefile || true
	swift package clean || true
	rm -rf Build/Products || true
	rm -rf .build-universal || true

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

# 單元測試一律 `--no-parallel`：本倉的測試共用大量行程內靜態狀態
# （`LXFacade` 的 factoryTrie／卡匣、`PrefMgr`、`SessionHost` 等），並行執行即互相踩踏。
# 逐包入口（`cd Packages/<pkg> && make test`）同理。
test:
	swift test --no-parallel
	swift test --no-parallel --package-path ./Packages/vChewing_OSNeutral_LibVanguard

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
