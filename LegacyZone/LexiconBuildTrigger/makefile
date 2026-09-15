# 本套件只為觸發遠端語料庫套件的 build tool plug-ins，故只認 5.10 工具鏈：host-only、不分架構，
# 因此 `--triple` 與 `-Xswiftc -target` 一概不下（SwiftPM 5.10 的 host 預設即為本機架構）。
#
# `DEVELOPER_DIR` 必須釘在 Xcode 15：5.10 的 Clang importer 用不了 Xcode 27 的 macOS 27 SDK，
# 會炸出 `could not build Objective-C module 'Foundation'` 一類的掩蓋式錯誤。`--sdk` 不必另下，
# 因為 `DEVELOPER_DIR` 已把預設 SDK 導向 Xcode 15 自帶的 macOS SDK。
#
# scratch path 與 6.4 側分離（`.build/.legacy`）：5.10 的 SwiftPM 讀不懂新版
# `.build/workspace-state.json`（v7），共用即互踩。
# 5.10.1 工具鏈可能落在兩處：官方安裝器寫進 `/Library`，`swiftly` 則自管 `$HOME` 那份。兩者係同一
# 發行版、識別子相同，並存會令 Xcode 拒絕註冊而所有 `xcodebuild` 於套件解析前即敗。故自動擇一：
# 優先系統那份（不受 `swiftly uninstall` 影響），次取使用者空間那份。`?=` 仍可顯式覆寫。
LEGACY_TOOLCHAIN ?= $(firstword $(wildcard \
	/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	$(HOME)/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	))
LEGACY_XCODE ?= /Applications/Xcode-15.app/Contents/Developer
LEGACY_SCRATCH ?= .build/.legacy
# 預設 **release**：本套件的唯一工作是跑語料庫的 build tool plug-ins，而辭典產製（建 trie、掃全表）
# 是 CPU 密集的；debug 產物會讓整個 legacy 建置明顯變慢。產物落點不受此影響——lexicon plug-in 一律
# 寫進自己硬編的 `…/VanguardLexiconData/Build/Release/vanguard-textmap/`（見 `collect` 的 glob），
# 故這裡改的只會是「跑 plug-in 的那支執行檔的最佳化程度」。
#
# 變數名刻意不叫 `LEGACY_CONFIG`：倉根 `Makefile` 的 `LEGACY_CONFIG` 指的是**app 的**建置設定（並以
# target-specific 變數隨 sub-make 外洩到環境），兩者同名會讓 `debugLegacy` 把這份詞典建置一起拖回
# debug——它與 app 的 config 無關，不該被牽著走。
LEXICON_CONFIG ?= release
# plug-in 產物集中處：組裝 legacy `.app` 時由此固定路徑取用。`Build/` 一類目錄已被 `.gitignore`
# 既有的通用規則 `[Bb]uild` 蓋掉，故無需另加忽略條目。
COLLECT_DIR ?= Build

.PHONY: build510 clean510 collect

build510:
	@export LC_ALL=C; export DEVELOPER_DIR="$(LEGACY_XCODE)"; \
	echo "Building $(notdir $(CURDIR)) with Swift 5.10 (host-only, $(LEXICON_CONFIG))…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build \
		--package-path . \
		--scratch-path "$(LEGACY_SCRATCH)" \
		--configuration "$(LEXICON_CONFIG)"

clean510:
	@rm -rf "$(LEGACY_SCRATCH)" "$(COLLECT_DIR)"

# 集中產物。檔名逐一列出（而非整目錄複製），以免把 plug-in 的中間垃圾一併帶進固定產物目錄。
#
# 4.8.0 的實測產物位置（`<scratch>/plugins/outputs/<套件名小寫>/<靶名>/<plug-in 名>/…`）：
#   VanguardTextMapPlugin/VanguardLexiconData/Build/Release/vanguard-textmap/VanguardFactoryDict4Typing.txtMap
#   TextTemplateAssetInjectorPlugin/TextTemplateAssets/template-associatedPhrases-cht.txt
#   TextTemplateAssetInjectorPlugin/TextTemplateAssets/template-associatedPhrases-chs.txt
# 4.8.0 不產 `.revlookup`（該 builder 的 `shouldPrepareRevLookupTrie` 為 false，且會主動刪掉殘檔）；
# 該 glob 僅為日後 lexicon 版本恢復產出時預留。
collect: build510
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
		echo "未找到任何 plug-in 產物，請確認建置是否成功。"; exit 1; \
	fi; \
	echo "已集中 $$copied 個產物至 $(COLLECT_DIR)/。"
