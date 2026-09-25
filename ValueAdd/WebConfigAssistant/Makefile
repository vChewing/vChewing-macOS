# 唯音輸入法配置助手（vChewing WebConfigAssistant）// 本目錄專用之 Makefile。
#
# 主倉（vChewing-macOS）之 Makefile 不受影響、亦不呼叫本檔。
# 本目錄之建置**不跨倉**：後設資料走本倉自己那份 SwiftPM 套件
# （`Packages/vChewing_OSNeutral_LibVanguard`），不觸及 vChewing-LibVanguard。
#
# 零 npm 相依：只用到 `tsc`（TypeScript，本機全域安裝即可）與 `node`。

TSC            ?= tsc
NODE           ?= node
PYTHON         ?= python3
PORT           ?= 8787
HOMEPAGE_REPO  ?= ../../../vChewing-HomePage.io
DEPLOY_SUBDIR  ?= assistant
# 「深入說明 →」之目標根。預設指向官網絕對位址（產物可雙擊開啟，相對路徑在 file:// 下必為死鏈）；
# 若助手與官網同網域（部署於 <站根>/assistant/），可改用 `make ... DOC_BASE=../`。
DOC_BASE       ?= https://vchewing.github.io/
CLI_PKG        ?= ../../Packages/vChewing_OSNeutral_LibVanguard
STRINGS_DIR    ?= ../../Sources/vChewingIME_macOS/Resources
METADATA       := assets/userdef-metadata.json
METADATA_TMP   := dist/userdef-metadata.json

LOCALE_ARGS = \
	"zh-Hant=$(abspath $(STRINGS_DIR))/zh-Hant.lproj/Localizable.strings" \
	"zh-Hans=$(abspath $(STRINGS_DIR))/zh-Hans.lproj/Localizable.strings" \
	"en=$(abspath $(STRINGS_DIR))/en.lproj/Localizable.strings" \
	"ja=$(abspath $(STRINGS_DIR))/ja.lproj/Localizable.strings"

# 助手需要、但不在 UserDef 命名空間內之既有 i18n 標籤（注音／拼音排列之選單名稱）。
EXTRA_ARGS = \
	--extra-label-prefix="i18n:KeyboardLayout." \
	--extra-label-prefix="i18n:TypingMethod."

DUMP = swift run --disable-sandbox -c release --package-path $(CLI_PKG) \
	vChewingSharedCLI dump-userdef-metadata $(LOCALE_ARGS) $(EXTRA_ARGS)

.PHONY: help typecheck build bundle test es5 metadata metadata-update metadata-audit surface surface-check version-check fixtures fixtures-check audit serve deploy clean

help:            ## 列出可用目標
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

typecheck:       ## 只做型別檢查（不輸出）
	$(TSC) --project tsconfig.json --noEmit

build:           ## 編譯 TypeScript 至 dist/js/
	$(TSC) --project tsconfig.json

bundle: build    ## 串接為 dist/core.js／dist/app.js／dist/assistant.html（單檔自足）
	$(NODE) tools/build.mjs "--doc-base=$(DOC_BASE)"

es5: bundle      ## 只跑 ES5 語法守衛（目標環境含 macOS 10.9 之 Safari）
	$(NODE) tools/es5guard.mjs dist/core.js dist/app.js

test: bundle     ## 單元測試（node:test；零額外相依）
	$(NODE) --test tests/*.test.js

metadata: bundle ## 自 UserDef 重新導出後設資料，並驗證與入庫版一致（防漂移）
	@mkdir -p dist
	@$(DUMP) > "$(METADATA_TMP)"
	@cmp -s "$(METADATA_TMP)" "$(METADATA)" || { \
		echo "後設資料已漂移。請以 dist/userdef-metadata.json 覆蓋 assets/userdef-metadata.json（或跑 make metadata-update）。"; exit 1; }

metadata-update: ## 重新導出後設資料並寫入 assets/（僅在 Swift 側確有變更時執行）
	@mkdir -p dist assets
	@$(DUMP) > "$(METADATA_TMP)"
	@cp "$(METADATA_TMP)" "$(METADATA)"
	@echo "已更新 $(METADATA)"

metadata-audit:  ## i18n 稽核：缺鍵或未遷移之標籤即失敗（--strict）
	@mkdir -p dist
	@$(DUMP) --strict > /dev/null

version-check:   ## 驗證 version.txt 與倉根 Release-Version.plist 一致（防漂移）
	$(NODE) tools/target-version.mjs --check

surface:         ## 掃描 SettingsUI／SettingsCocoa 之曝露面（助手之題庫不得越出此面）
	$(NODE) tools/settings-surface.mjs

surface-check:   ## 驗證曝露面與入庫版一致（防漂移）
	$(NODE) tools/settings-surface.mjs --check

fixtures: bundle  ## 由助手自身之核心邏輯重新生成契約測試用之 fixture
	$(NODE) tools/fixtures.mjs

fixtures-check: bundle ## 驗證 fixture 與助手產物一致（防漂移）
	$(NODE) tools/fixtures.mjs --check

audit: typecheck es5 test metadata metadata-audit surface-check version-check fixtures-check  ## 提交前總檢

serve: bundle    ## 本機預覽（產物本身可雙擊開啟，故僅開發期需要）
	cd dist && $(PYTHON) -m http.server $(PORT)

deploy: bundle   ## 複製產物進官網倉（不自動提交）
	@test -d "$(HOMEPAGE_REPO)" || { echo "找不到官網倉：$(HOMEPAGE_REPO)"; exit 1; }
	@mkdir -p "$(HOMEPAGE_REPO)/$(DEPLOY_SUBDIR)"
	@cp dist/assistant.html "$(HOMEPAGE_REPO)/$(DEPLOY_SUBDIR)/assistant.html"
	@cp dist/index.html "$(HOMEPAGE_REPO)/$(DEPLOY_SUBDIR)/index.html"
	@echo "已部署。請於官網倉提交 $(DEPLOY_SUBDIR)/index.html 與 $(DEPLOY_SUBDIR)/assistant.html（前者會自動跳轉至後者）"

clean:           ## 清理提示（本工作區紀律：不執行 rm -rf，請手動移入 tmp/_filesToTrash）
	@echo "請將 dist/ 與 node_modules/（若有）移入 tmp/_filesToTrash。"
