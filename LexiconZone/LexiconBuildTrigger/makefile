# 語料庫（原廠辭典＋兩份聯想詞模板）的**帶外產製入口**：一支只為承載遠端 lexicon 兩支 buildTool plugin
# 而存在的空殼套件，同時服務兩條建置鏈。
#
#   make build   collect      現代（Swift 6.4+）鏈：以**當前 shell 的 `swift`**、host-only 建置一次，
#                             產物集中到固定目錄，供 `Packages/vChewing_MainAssembly4Darwin` 的
#                             `LexiconAssetRelayPlugin` 純複製注入。
#   make build510 collect510  Swift 5.10 legacy 鏈：另備 toolchain 與 `DEVELOPER_DIR`，產物同樣集中，
#                             供 `bundleLegacy`（`Plugins/BundleAppsLegacy`）取用。
#
# 為什麼要 host-only：語料庫 plugin 的 build command **無 `inputFiles`**，SwiftPM 因此對每個
# destination 各跑一次。`make release` 的 arm64 與 x86_64 兩個 slice 若各自觸發一次，原廠辭典便被建置
# 兩次（實測各 35–49 秒）。本套件兩條入口都不下 `--arch`／`--triple`，故各鏈只建一次。
#
# 為什麼兩條鏈共用一個套件：manifest 停在 `swift-tools-version: 5.10`，5.10 與 6.4 兩顆工具鏈都讀得懂
#（本套件原始碼只有一個空 enum，沒有語言模式差異）；遠端 lexicon 自備 `Package.swift`（6.2）與
# `Package@swift-5.swift`，兩顆工具鏈各取所需。
LEXICON_CONFIG ?= release
# 兩條鏈的 scratch 必須分離：5.10 的 SwiftPM 讀不懂新版 `.build/workspace-state.json`（v7），共用即互踩。
MODERN_SCRATCH ?= .build/.modern
LEGACY_SCRATCH ?= .build/.legacy
# 產物集中處。倉根 `Makefile` 會顯式覆寫成固定路徑（現代鏈 `LexiconZone/Build`、legacy 鏈
# `LegacyZone/Build`）；單獨跑本檔時預設落在本目錄的 `Build/`（已被 `.gitignore` 的通用 `[Bb]uild` 規則涵蓋）。
COLLECT_DIR ?= Build
# manifest 快取一律落在本目錄內（`--cache-path`）：SwiftPM 預設寫 `~/Library/org.swift.swiftpm`，
# 在 CI 或受拘束的 shell 內不可寫，會退化成每個 manifest 都重編（並刷一整排
# `failed storing manifest … readonly database`）。落本地後既不碰使用者目錄，也不再受該限制牽連。
#
# 額外傳給 SwiftPM 的旗標（預設空）。典型用途是 `--disable-sandbox`：`swift build` 於部分環境
#（自身已受外層沙箱拘束者）會在 manifest 編譯那關失敗——`sandbox-exec: sandbox_apply: Operation not
# permitted`、繼而 `error: 'lexiconbuildtrigger': Invalid manifest`。倉根 `Makefile` 之 `lexiconModern`／
# `lexiconLegacy` 會把同名變數轉遞進來。預設不動：正常環境不該削弱 SwiftPM 之 manifest 沙箱。
MODERN_SWIFT_EXTRA_FLAGS ?=
LEGACY_SWIFT_EXTRA_FLAGS ?=

# 5.10 工具鏈可能落在兩處：官方安裝器寫進 `/Library`，`swiftly` 則自管 `$HOME` 那份。兩者係同一發行版、
# 識別子相同，並存會令 Xcode 拒絕註冊而所有 `xcodebuild` 於套件解析前即敗。故自動擇一：優先系統那份
#（不受 `swiftly uninstall` 影響），次取使用者空間那份。`?=` 仍可顯式覆寫。
LEGACY_TOOLCHAIN ?= $(firstword $(wildcard \
	/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	$(HOME)/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	))
# `DEVELOPER_DIR` 必須釘在 Xcode 15：5.10 的 Clang importer 用不了 Xcode 27 的 macOS 27 SDK，會炸出
# `could not build Objective-C module 'Foundation'` 一類的掩蓋式錯誤。`--sdk` 不必另下，因為
# `DEVELOPER_DIR` 已把預設 SDK 導向 Xcode 15 自帶的 macOS SDK。
LEGACY_XCODE ?= /Applications/Xcode-15.app/Contents/Developer

.PHONY: build collect build510 collect510 clean

build:
	@export LC_ALL=C; \
	echo "Building the lexicon assets with the active Swift toolchain (host-only, $(LEXICON_CONFIG))…"; \
	swift build \
		--package-path . \
		--scratch-path "$(MODERN_SCRATCH)" \
		--cache-path "$(CURDIR)/.build/cache" \
		--configuration "$(LEXICON_CONFIG)" \
		$(MODERN_SWIFT_EXTRA_FLAGS)

build510:
	@export LC_ALL=C; export DEVELOPER_DIR="$(LEGACY_XCODE)"; \
	echo "Building the lexicon assets with Swift 5.10 (host-only, $(LEXICON_CONFIG))…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build \
		--package-path . \
		--scratch-path "$(LEGACY_SCRATCH)" \
		--cache-path "$(CURDIR)/.build/cache" \
		--configuration "$(LEXICON_CONFIG)" \
		$(LEGACY_SWIFT_EXTRA_FLAGS)

clean:
	@rm -rf "$(MODERN_SCRATCH)" "$(LEGACY_SCRATCH)" "$(COLLECT_DIR)"

# 集中產物。檔名逐一列出（而非整目錄複製），以免把 plugin 的中間垃圾一併帶進固定產物目錄。
#
# 兩條鏈的 plugin 產物佈局不同，故有兩份 glob：
#   6.4 側（實測）：<scratch>/plugins/outputs/<套件名小寫>/<建置目標名>/destination/<plugin 名>/…
#        建置目標與 plugin 名之間多一層 `destination/`。
#   5.10 側：<scratch>/plugins/outputs/<套件名小寫>/<建置目標名>/<plugin 名>/…
# 兩側共同的產物：
#   VanguardTextMapPlugin/VanguardLexiconData/Build/Release/vanguard-textmap/VanguardFactoryDict4Typing.txtMap
#   TextTemplateAssetInjectorPlugin/TextTemplateAssets/template-associatedPhrases-cht.txt
#   TextTemplateAssetInjectorPlugin/TextTemplateAssets/template-associatedPhrases-chs.txt
# 4.8.0 起不產 `.revlookup`（該 builder 的 `shouldPrepareRevLookupTrie` 為 false，且會主動刪掉殘檔）；
# 該 glob 僅為日後 lexicon 版本恢復產出時預留。
collect: build
	@export LC_ALL=C; \
	set -e; \
	src="$(MODERN_SCRATCH)"; \
	rm -rf "$(COLLECT_DIR)"; mkdir -p "$(COLLECT_DIR)"; \
	copied=0; \
	for pattern in \
			'plugins/outputs/*/*/destination/VanguardTextMapPlugin/VanguardLexiconData/Build/*/vanguard-textmap/*.txtMap' \
			'plugins/outputs/*/*/destination/VanguardTextMapPlugin/VanguardLexiconData/Build/*/vanguard-textmap/*.revlookup' \
			'plugins/outputs/*/*/destination/TextTemplateAssetInjectorPlugin/TextTemplateAssets/template-associatedPhrases-*.txt'; do \
		for hit in $$src/$$pattern; do \
			[ -f "$$hit" ] || continue; \
			cp -f "$$hit" "$(COLLECT_DIR)/$$(basename "$$hit")"; \
			echo "  → $$(basename "$$hit")"; \
			copied=$$((copied+1)); \
		done; \
	done; \
	if [ "$$copied" -eq 0 ]; then \
		echo "未找到任何 plugin 產物，請確認建置是否成功。"; exit 1; \
	fi; \
	echo "已集中 $$copied 個產物至 $(COLLECT_DIR)/。"

collect510: build510
	@export LC_ALL=C; \
	set -e; \
	src="$(LEGACY_SCRATCH)"; \
	rm -rf "$(COLLECT_DIR)"; mkdir -p "$(COLLECT_DIR)"; \
	copied=0; \
	for pattern in \
			'plugins/outputs/*/*/VanguardTextMapPlugin/VanguardLexiconData/Build/*/vanguard-textmap/*.txtMap' \
			'plugins/outputs/*/*/VanguardTextMapPlugin/VanguardLexiconData/Build/*/vanguard-textmap/*.revlookup' \
			'plugins/outputs/*/*/TextTemplateAssetInjectorPlugin/TextTemplateAssets/template-associatedPhrases-*.txt'; do \
		for hit in $$src/$$pattern; do \
			[ -f "$$hit" ] || continue; \
			cp -f "$$hit" "$(COLLECT_DIR)/$$(basename "$$hit")"; \
			echo "  → $$(basename "$$hit")"; \
			copied=$$((copied+1)); \
		done; \
	done; \
	if [ "$$copied" -eq 0 ]; then \
		echo "未找到任何 plugin 產物，請確認建置是否成功。"; exit 1; \
	fi; \
	echo "已集中 $$copied 個產物至 $(COLLECT_DIR)/。"
