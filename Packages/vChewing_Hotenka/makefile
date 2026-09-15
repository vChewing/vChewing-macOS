.PHONY: format lint build510 clean510

format:
	@swiftformat --swiftversion 5.5 --indent 2 ./

lint:
	@git ls-files --exclude-standard | grep -E '\.swift$$' | swiftlint --fix --autocorrect

# ---- Swift 5.10 側（macOS 10.9 / x86_64，靜態產物）----
#
# 用途：於本套件目錄內 `make build510`，單獨驗證本套件的 5.10 **編譯**（compilation test）。這不是單元
# 測試——單元測試只在 6.2 以上側跑（本 makefile 刻意不提供任何 test 目標）。
#
# 環境配對三項缺一不可：
#
# 1. **工具鏈**須為 Swift 5.10（`LEGACY_TOOLCHAIN`）：只有它會挑到本套件的 `Package@swift-5.10.swift`。
# 2. **SDK** 須為 Xcode 15 之 `MacOSX13.3.sdk`（`LEGACY_SDK`）：Xcode 27 的 MacOSX27.0.sdk 對 5.10 的
#    Clang importer 不可用，會炸出 312 個掩蓋式錯誤（`_c_standard_library_obsolete` 等），無一條指向病灶。
# 3. **scratch path** 須與 6.2 以上側分離（`LEGACY_SCRATCH`）：5.10 的 SwiftPM 讀不懂新版
#    `.build/workspace-state.json`（v7），共用即互踩。
#
# 部署目標：SwiftPM 5.10 會**丟掉 `--triple` 的版本部分**、一律抬到自身地板（x86_64 為 10.13），故須以
# `-Xswiftc -target` 覆寫（同一個 `-target` 後出現者勝）才能真正壓到 macOS 10.9。之所以能只改編譯期：
# 本側產物是靜態 `.a`，不帶任何 load command，minOS 因此不進產物、只影響 availability 檢查。
#
# 機理與規範見 vChewing-DevLogs/Research/Phase217_SOP.md §二（環境配對）、§2.4（逐包 makefile）、
# §四（產物形態）。倉根另有批次入口：`make build510-all`（於 `Packages/` 內）。
# 5.10.1 工具鏈可能落在兩處：官方安裝器寫進 `/Library`，`swiftly` 則自管 `$HOME` 那份。兩者係同一
# 發行版、識別子相同，並存會令 Xcode 拒絕註冊而所有 `xcodebuild` 於套件解析前即敗。故自動擇一：
# 優先系統那份（不受 `swiftly uninstall` 影響），次取使用者空間那份。`?=` 仍可顯式覆寫。
LEGACY_TOOLCHAIN ?= $(firstword $(wildcard \
	/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	$(HOME)/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	))
LEGACY_SDK ?= /Applications/Xcode-15.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.3.sdk
LEGACY_TRIPLE ?= x86_64-apple-macosx10.9
# scratch path 逐套件獨立（各套件自己的 .build/.legacy）：共用會令兩份 manifest 的產物互踩。
LEGACY_SCRATCH ?= .build/.legacy

build510:
	@export LC_ALL=C; \
	echo "Building $(notdir $(CURDIR)) with Swift 5.10 for $(LEGACY_TRIPLE)…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build \
		--package-path . \
		--scratch-path "$(LEGACY_SCRATCH)" \
		--triple "$(LEGACY_TRIPLE)" \
		--sdk "$(LEGACY_SDK)" \
		-Xswiftc -target -Xswiftc "$(LEGACY_TRIPLE)"

clean510:
	@rm -rf "$(LEGACY_SCRATCH)"
