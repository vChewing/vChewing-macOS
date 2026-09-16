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

# ── Swift 5.10 (legacy) build entry point: the repo-root package ─────
#
# `Package@swift-5.10.swift` at the repo root is the one 5.10 manifest that produces executables
# (`vChewing`, `vChewingInstallerLegacy`); the subpackages stop at static `.a`. Its scratch lives
# under `.build/.legacy-root`, which the `spmClean` loop above already sweeps.
#
# `DEVELOPER_DIR` is pinned because `--sdk` does not reach build-plugin compilation: with a newer
# Xcode active, the 5.10 compiler is handed its macOS 27 SDK and dies on
# `could not build Objective-C module 'Foundation'`.
#
# C／ObjC 靶（`IMKSwiftModernHeaders`／`OSFrameworkImplViaObjC`／`SwiftyCapsLockToggler`）另須 `-Xcc -target`：
# `-Xswiftc -target` 只管 Swift，clang 端仍照 SwiftPM 的地板產出（`ld: warning: object file … was built for
# newer 'macOS' version (10.13) than being linked (10.9)`）；而 `-Xcc -mmacosx-version-min=…` 會被 SwiftPM
# 自己那條 `-target …10.13` 壓住（clang 讓 `-target` 勝、與先後無關），故必須再下一條 `-target` 覆蓋
# （同一個 `-target` 後出現者勝——與 Swift 側同一個道理）。
#
# The two executables still have to be re-pointed at the back-deployment Swift runtime afterwards
# (they ship `@rpath/libswift*.dylib` records and macOS 10.9 has no Swift runtime of its own).
# `BundleAppsLegacy` (declared only in the 5.10 manifest) does that and then assembles the two
# `.app` bundles; `make bundleLegacy` runs it with the same Xcode 15 active.

# Swift 5.10.1 can live in either toolchain directory: the official installer writes to `/Library`,
# while `swiftly` manages its own set under `$HOME`. Both are the same release and carry the same
# bundle identifier, so having both present at once makes Xcode refuse to register either and
# every `xcodebuild` fails before it parses a single package. Prefer the system-wide copy — it is
# the one the official installer put there and it survives a `swiftly` uninstall — and fall back to
# the user-space one, so that removing either directory (the only way out of that Xcode conflict)
# does not also brick this target.
LEGACY_TOOLCHAIN ?= $(firstword $(wildcard \
	/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	$(HOME)/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	))
# 13.3 SDK 之**真身是 Command Line Tools 那份**（Xcode 15 內的同名目錄只是指過去的 symlink），故綁 CLT：
# 只要機器上備有這份 SDK，換 Xcode（或那份 Xcode 被搬走）都不影響本側之 targets 建置。SDK 內容＝Xcode 14.3
# 期（2023-03-29 建置）的原廠 macOS 13.3 SDK；**現行 CLT 已不再隨附它**（其元件已改成移除包
# `CLTools_macOS_DevSDK_Remove_macOS13.pkg`），故換機時得自行自舊 CLT／Xcode 14.3 取得後放進 CLT 的
# `SDKs/`。另：`LEGACY_XCODE` 仍須為一個「預設 macOS SDK 夠舊」的 Xcode——build plugin 之編譯取的是
# active developer dir 的預設 SDK，`--sdk` 到不了那裡（上開註解）；SDK 綁 CLT 並不會改變這一點。
LEGACY_SDK ?= /Library/Developer/CommandLineTools/SDKs/MacOSX13.3.sdk
LEGACY_XCODE ?= /Applications/Xcode-15.app/Contents/Developer
LEGACY_X86_TRIPLE ?= x86_64-apple-macosx10.9
LEGACY_ARM_TRIPLE ?= arm64-apple-macosx11.0
LEGACY_SCRATCH_ROOT ?= .build/.legacy-root
LEGACY_CONFIG ?= debug
LEGACY_ARCLITE ?= ./LegacyZone/ARCLite/libarclite_macosx.a
LEGACY_BUILD_FLAGS = --package-path . --scratch-path "$(LEGACY_SCRATCH_ROOT)" --sdk "$(LEGACY_SDK)"
# 鏈結期的 `-platform_version <platform> <min> <sdk>`。SwiftPM 5.10 不認得 `--sdk`，會把 triple 的版本段
# **同時**填進 min 與 sdk 兩格，於是產物之 `LC_VERSION_MIN_MACOSX` 記成 `version 10.9 sdk 10.9`——而實情
# 是以 13.3 的 SDK 鏈結的（`--sdk` 有生效，只是沒寫進這個欄位）。
#
# `sdk` 那一格不是裝飾：AppKit 用它判定「這個 app 是不是以 10.14 之後的 SDK 鏈出的」，據此決定要不要把
# app 鎖進 Aqua 外觀。填成 10.9 的後果實測為：`vChewingInstallerLegacy` 沒有暗色模式；而 `vChewing.app`
# 倖免，只因它的 Info.plist 另帶 `NSRequiresAquaSystemAppearance = No`（見
# `Sources/vChewingIME_macOS/Resources/Info.plist`），安裝程式的來源 plist 沒有這一鍵。
# 補上本旗標後兩支都記成 `sdk 13.3`，與 `vChewing-OSX-legacy` 以 Xcode 15.4 建出的參照產物一致。
#
# 版本值取自 `$(LEGACY_SDK)` 自己的 `SDKSettings.plist`，故換 SDK 不必另改一處。後出現者勝（同 `-target`
# 之理），SwiftPM 自己那條會被本旗標覆寫。
LEGACY_SDK_VERSION ?= $(shell /usr/libexec/PlistBuddy -c 'Print :Version' "$(LEGACY_SDK)/SDKSettings.plist" 2>/dev/null)
LEGACY_PLATFORM_VERSION_FLAG = $(if $(LEGACY_SDK_VERSION),-Xlinker -platform_version -Xlinker macos -Xlinker $(1) -Xlinker $(LEGACY_SDK_VERSION))
# 兩個架構的產物目錄：SwiftPM 收 `--triple x86_64-apple-macosx10.9` 之後，目錄名會把版本段去掉
# （`x86_64-apple-macosx`）；`bundle-apps-legacy` 找的是產物，故須用這個名字。universal 產物就地覆寫
# x86_64 那一份，故這裡對 debug 與 release 一體適用。
LEGACY_X86_DIR ?= $(LEGACY_SCRATCH_ROOT)/x86_64-apple-macosx/$(LEGACY_CONFIG)
LEGACY_ARM_DIR ?= $(LEGACY_SCRATCH_ROOT)/arm64-apple-macosx/$(LEGACY_CONFIG)
LEGACY_PRODUCTS_DIR ?= $(LEGACY_X86_DIR)

.PHONY: debugLegacy releaseLegacy cleanLegacy bundleLegacy lexiconLegacy archiveLegacy

# debug：單一 x86_64 slice。可動，但未最佳化、執行起來處處遲滯（辭典載入尤甚）——要試用請走
# `releaseLegacy`。收尾自動組 bundle（config=debug）。
debugLegacy: LEGACY_CONFIG := debug
debugLegacy:
	@export LC_ALL=C; export DEVELOPER_DIR="$(LEGACY_XCODE)"; set -e; \
	echo "Building vChewingIME at the repo root with Swift 5.10 ($(LEGACY_CONFIG), $(LEGACY_X86_TRIPLE))…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build $(LEGACY_BUILD_FLAGS) \
		--configuration "$(LEGACY_CONFIG)" \
		--triple "$(LEGACY_X86_TRIPLE)" \
		-Xswiftc -target -Xswiftc "$(LEGACY_X86_TRIPLE)" \
		-Xcc -target -Xcc "$(LEGACY_X86_TRIPLE)" \
		$(call LEGACY_PLATFORM_VERSION_FLAG,$(patsubst x86_64-apple-macosx%,%,$(LEGACY_X86_TRIPLE))) \
		-Xlinker -force_load -Xlinker "$(LEGACY_ARCLITE)"; \
	$(MAKE) bundleLegacy LEGACY_CONFIG=debug

# release：兩個 slice 各自建置後 lipo 成 universal 產物（Apple silicon 亦得跑）。
#
#   x86_64-apple-macosx10.9   — legacy 那一支，另 force-load libArcLite（見下）
#   arm64-apple-macosx11.0    — Apple silicon。arm64 沒有 11.0 以下的 macOS，且其 ARC 執行期自
#                               macOS 11 起即在 libobjc 內，故**不摻** libArcLite——該 archive 本身
#                               只有 x86_64 一個 slice，硬摻會直接令 arm64 連結失敗。
#
# 兩支的產物各落自己的 triple 目錄；lipo 之結果**就地覆寫 x86_64 那一份**，故 `LEGACY_PRODUCTS_DIR`
# 與 `bundleLegacy` 無須為 universal 另立一套路徑。**收尾自行組 bundle**（`bundleLegacy LEGACY_CONFIG=release`）：
# 從前得手動再接一句 `make bundleLegacy`，而那個目標的預設 config 是 `debug`——實測踩過一次
# 「release 建完卻把 debug 產物包進 .app」（辭典載入慢十幾倍）。`debugLegacy` 亦然（config=debug）。
releaseLegacy: LEGACY_CONFIG := release
releaseLegacy:
	@export LC_ALL=C; export DEVELOPER_DIR="$(LEGACY_XCODE)"; set -e; \
	echo "Building vChewingIME at the repo root with Swift 5.10 ($(LEGACY_CONFIG), $(LEGACY_X86_TRIPLE))…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build $(LEGACY_BUILD_FLAGS) \
		--configuration "$(LEGACY_CONFIG)" \
		--triple "$(LEGACY_X86_TRIPLE)" \
		-Xswiftc -target -Xswiftc "$(LEGACY_X86_TRIPLE)" \
		-Xcc -target -Xcc "$(LEGACY_X86_TRIPLE)" \
		$(call LEGACY_PLATFORM_VERSION_FLAG,$(patsubst x86_64-apple-macosx%,%,$(LEGACY_X86_TRIPLE))) \
		-Xlinker -force_load -Xlinker "$(LEGACY_ARCLITE)"; \
	echo "Building vChewingIME at the repo root with Swift 5.10 ($(LEGACY_CONFIG), $(LEGACY_ARM_TRIPLE))…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build $(LEGACY_BUILD_FLAGS) \
		--configuration "$(LEGACY_CONFIG)" \
		--triple "$(LEGACY_ARM_TRIPLE)" \
		-Xswiftc -target -Xswiftc "$(LEGACY_ARM_TRIPLE)" \
		-Xcc -target -Xcc "$(LEGACY_ARM_TRIPLE)" \
		$(call LEGACY_PLATFORM_VERSION_FLAG,$(patsubst arm64-apple-macosx%,%,$(LEGACY_ARM_TRIPLE))); \
	for exe in vChewing vChewingInstallerLegacy; do \
		echo "Merging $$exe into a universal binary…"; \
		lipo -create "$(LEGACY_ARM_DIR)/$$exe" "$(LEGACY_X86_DIR)/$$exe" -output "$(LEGACY_X86_DIR)/$$exe.universal"; \
		mv -f "$(LEGACY_X86_DIR)/$$exe.universal" "$(LEGACY_X86_DIR)/$$exe"; \
		lipo -archs "$(LEGACY_X86_DIR)/$$exe"; \
	done; \
	$(MAKE) bundleLegacy LEGACY_CONFIG=release

# Assembles the two legacy `.app` bundles under `Build/Products/Legacy/` — `vChewing.app` (the IME)
# and `vChewingInstallerLegacy.app` (the installer, embedding the IME).  Runs with Xcode 15 active
# like the two build targets: the plugin itself is compiled by the host SDK, and `actool` is taken
# from the active developer directory.
#
# It assembles whichever configuration `LEGACY_CONFIG` names (default `debug`).  Both build targets
# already call it with their own configuration, so it only needs naming explicitly when assembling a
# set by hand — `make bundleLegacy LEGACY_CONFIG=release`.  Naming the configuration matters: the
# debug and release product trees sit side by side and each target overwrites `Build/Products/Legacy/`,
# so getting it wrong silently ships unoptimised binaries.
#
# `LexiconBuildTrigger` has to have run first.  The 5.10 root manifest carries no lexicon
# dependency (its plugin products require macOS 10.15), so the factory lexicon and the two
# associated-phrase templates come from that separate package instead.  `lexiconLegacy` below runs
# it for you — both build targets end by calling this target, so nothing needs doing by hand.
bundleLegacy: lexiconLegacy
	@export LC_ALL=C; export DEVELOPER_DIR="$(LEGACY_XCODE)"; \
	echo "Assembling the legacy .app bundles from $(LEGACY_PRODUCTS_DIR)…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" package \
		--package-path . \
		--scratch-path "$(LEGACY_SCRATCH_ROOT)" \
		--allow-writing-to-package-directory bundle-apps-legacy \
		-- --build-dir "$(LEGACY_PRODUCTS_DIR)" --sdk "$(LEGACY_SDK)"

# 產出並集中辭典資產（原廠辭典 `.txtMap` ＋ 兩份使用者片語範本）。它是 `bundleLegacy` 的必經前置，
# 故 `debugLegacy`／`releaseLegacy` 一併自動滿足；單獨跑 `make -C LegacyZone/LexiconBuildTrigger
# build510 collect` 仍然可行，`bundleLegacy` 之 plugin 在資產缺席時也會明示這句話。
# 該套件以 `LEXICON_CONFIG`（預設 release）建置——辭典產製 CPU 密集，debug 產物慢上許多。該變數名與
# 本檔的 `LEGACY_CONFIG` 刻意不同：後者指 *app* 的 config，且會以 target-specific 變數外洩到 sub-make，
# 同名會讓 `make debugLegacy` 把詞典建置一起拖回 debug。
lexiconLegacy:
	@$(MAKE) --no-print-directory -C LegacyZone/LexiconBuildTrigger build510 collect

# ── archiveLegacy ───────────────────────────────────────────────────
#
# Produces the legacy distro's `.xcarchive`, the artifact to hand to Xcode Organizer for Developer
# ID signing and notarization — the modern distro's counterpart is `make archive`.  The archive
# holds `vChewingInstallerLegacy.app` (which embeds the IME) under `Products/Applications/` plus
# dSYMs for both executables, exactly the layout `BundleApps` writes on the modern side.
#
# It chains into `releaseLegacy` because an archive is a distribution artifact: a one-slice debug
# archive would be both unoptimised and x86_64-only.  `BundleAppsLegacy` is then asked for
# `--archive`, which writes the archive beside the bundles under `Build/Products/`; a command
# plugin may only write inside the package directory, so the move into
# `~/Library/Developer/Xcode/Archives/<date>/` — where Organizer lists archives — is done here, the
# same way the modern `archive` target does it.  The archive is **moved**, not copied, so nothing
# is left behind in `Build/Products/`.
archiveLegacy: LEGACY_CONFIG := release
archiveLegacy: releaseLegacy
	@export LC_ALL=C; export DEVELOPER_DIR="$(LEGACY_XCODE)"; set -e; \
	echo "Assembling the legacy .xcarchive from $(LEGACY_PRODUCTS_DIR)…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" package \
		--package-path . \
		--scratch-path "$(LEGACY_SCRATCH_ROOT)" \
		--allow-writing-to-package-directory bundle-apps-legacy \
		-- --build-dir "$(LEGACY_PRODUCTS_DIR)" --sdk "$(LEGACY_SDK)" --archive; \
	mkdir -p "$(ARCHIVE_DIR)"; \
	for f in Build/Products/*.xcarchive; do \
		if [ -d "$$f" ]; then \
			dest="$(ARCHIVE_DIR)/$$(basename "$$f")"; \
			rm -rf "$$dest"; \
			mv "$$f" "$$dest"; \
			echo "  ✓ Moved to $$dest"; \
		fi; \
	done

cleanLegacy:
	@rm -rf "$(LEGACY_SCRATCH_ROOT)" ./Build/Products/Legacy

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
