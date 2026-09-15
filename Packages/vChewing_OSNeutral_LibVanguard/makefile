# Pin LC_ALL so CJK collation stays identical regardless of the machine's locale settings.
.PHONY: lint format lintFormat lintFormatUncommitted spmClean test dockertest test-debug dockertest-debug build510 build510SwiftExtension clean510

# ---- Swift 5.10 側（macOS 10.9 / x86_64，靜態產物）----
#
# 版本擇定：SwiftPM 挑的是「檔內宣告的 tools version 不高於 toolchain 版本者之最高者」，故 5.10
# toolchain 自動取 `Package@swift-5.10.swift`、6.2 以上自動取 `Package.swift`、6.0／6.1 則由兩份
# 封堵檔接下。以下目標即「把 5.10 那條路徑跑起來」所需的全部環境配對，三項缺一不可：
#
# 1. **工具鏈**：須為 Swift 5.10（`LEGACY_TOOLCHAIN`，預設 open-source 5.10.1）。
# 2. **SDK**：須為 Xcode 15 之 SDK（`LEGACY_SDK`，預設其 MacOSX13.3.sdk）。Xcode 27 的
#    MacOSX27.0.sdk 對 5.10 的 Clang importer **不可用**——會炸在
#    `module '_c_standard_library_obsolete' requires feature 'found_incompatible_headers__check_search_paths'`
#    與 `unknown argument: '-target-arch-variant'`，且是 312 個錯誤的掩蓋式失敗，看不出真正原因。
#    注意 manifest 載入（`swift package dump-package`）在 SDK 27 下**照樣成功**，因為 manifest 不
#    import Foundation，故「manifest 載得動」不足以證明 SDK 可用。
# 3. **scratch path**：須與 6.2 以上側分離（`LEGACY_SCRATCH`，預設 `.build/.legacy`）。5.10 的
#    SwiftPM 讀不懂新版 `.build/workspace-state.json`（v7），會警告 "unable to restore workspace
#    state" 並就地覆寫，兩側互相踩。
#
# 部署目標：SwiftPM 5.10 會**丟掉 `--triple` 的版本部分**、一律抬到自身地板（x86_64 為 10.13；
# arm64 更被 linker 釘在 11.0），宣告 `platforms: [.macOS(.v10_10)]` 也一樣被抬上去。故須以
# `-Xswiftc -target` 覆寫（同一個 `-target` 後出現者勝）才能真正壓到 macOS 10.9。之所以能這樣
# 只改編譯期：本側產物一律是**靜態庫**，`.a` 不帶任何 load command，minOS 因此不進產物、只影響
# availability 檢查——而這正是我們要的（讓 5.10 側的可用性判定與 legacy app 的
# `MACOSX_DEPLOYMENT_TARGET` 一致）。
#
# **為何是 10.9**：10.9 即 legacy 發行版之部署地板（鐵則：legacy 分支存在的唯一意義就是支持
# macOS 10.9）。本檔早期記為「10.9 不可用，因 `Data` 標為 macOS 10.10 起可用」——該結論出自舊探針，
# 與正式路徑之實測不符：本檔這組配對（5.10 toolchain ＋ MacOSX13.3.sdk ＋
# `-Xswiftc -target x86_64-apple-macosx10.9`）冷啟建置得 `Build complete!`、0 筆 `error:`。
# 編譯期目標只影響 availability 檢查——本側產物一律靜態 `.a`，不帶 load command，minOS 不進產物。
# 5.10.1 工具鏈可能落在兩處：官方安裝器寫進 `/Library`，`swiftly` 則自管 `$HOME` 那份。兩者係同一
# 發行版、識別子相同，並存會令 Xcode 拒絕註冊而所有 `xcodebuild` 於套件解析前即敗。故自動擇一：
# 優先系統那份（不受 `swiftly uninstall` 影響），次取使用者空間那份。`?=` 仍可顯式覆寫。
LEGACY_TOOLCHAIN ?= $(firstword $(wildcard \
	/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	$(HOME)/Library/Developer/Toolchains/swift-5.10.1-RELEASE.xctoolchain \
	))
LEGACY_SDK ?= /Applications/Xcode-15.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX13.3.sdk
LEGACY_SCRATCH ?= .build/.legacy
LEGACY_SCRATCH_SWIFTEXTENSION ?= .build/.legacy-swiftExtension
LEGACY_TRIPLE ?= x86_64-apple-macosx10.9

build510:
	@export LC_ALL=C; \
	echo "Building with Swift 5.10 for $(LEGACY_TRIPLE)…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build \
		--package-path . \
		--scratch-path "$(LEGACY_SCRATCH)" \
		--triple "$(LEGACY_TRIPLE)" \
		--sdk "$(LEGACY_SDK)" \
		-Xswiftc -target -Xswiftc "$(LEGACY_TRIPLE)"

# 只建置巢狀子套件 `Deps/VanguardSwiftExtension`（即 `SwiftExtension` 模組本身）的 5.10 側。
#
# 為什麼要單獨一個入口：它是**獨立的 package**、有自己的一組 `Package*.swift`，故版本擇定與聚合體
# 各別進行；而它又位於整條依賴閉包的最底層（聚合體所有靶都倚賴它），因此出錯時把它單獨切出來驗，
# 遠比每次重跑整包 `build510` 快。它同時是目前唯一兩套 toolchain 皆可建置、且 5.10 側能產出
# 可用靜態庫的靶。
#
# scratch path 刻意與聚合體分開（`LEGACY_SCRATCH_SWIFTEXTENSION`）：兩份 manifest 的產物若共用同一個
# scratch，會互相踩。其餘環境配對與 `build510` 完全相同（同一組 `LEGACY_*`）。
build510SwiftExtension:
	@export LC_ALL=C; \
	echo "Building Deps/VanguardSwiftExtension with Swift 5.10 for $(LEGACY_TRIPLE)…"; \
	"$(LEGACY_TOOLCHAIN)/usr/bin/swift" build \
		--package-path Deps/VanguardSwiftExtension \
		--scratch-path "$(LEGACY_SCRATCH_SWIFTEXTENSION)" \
		--triple "$(LEGACY_TRIPLE)" \
		--sdk "$(LEGACY_SDK)" \
		-Xswiftc -target -Xswiftc "$(LEGACY_TRIPLE)"

clean510:
	@rm -rf "$(LEGACY_SCRATCH)" "$(LEGACY_SCRATCH_SWIFTEXTENSION)"

# 清建置快取。本倉為倉根套件（聚合體），其巢狀子套件另置於 `Deps/` 之下——
# 僅在「直接對子套件建置」時才會生成獨立 .build，故須一併清掃，否則殘留物件
# 會在下一次建置造成 `Undefined symbols` 之假失敗。另清 5.10 側的兩條 scratch path。
spmClean:
	swift package clean
	@rm -rf "$(LEGACY_SCRATCH)" "$(LEGACY_SCRATCH_SWIFTEXTENSION)"
	@for nestedDep in ./Deps/*; do \
		if [ -f "$$nestedDep/Package.swift" ]; then \
			echo "processing nested dep $$nestedDep"; \
			swift package clean --package-path "$$nestedDep" || true; \
		fi; \
	done;

format:
	@export LC_ALL=C; swiftformat --swiftversion 6.0 --indent 2 ./

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
		printf '%s\n' "$$files" | tr '\n' '\0' | xargs -0 swiftformat --swiftversion 6.0 --indent 2; \
	fi

test:
	swift test -c release --no-parallel $(filter-out $@,$(MAKECMDGOALS))

test-debug:
	swift test -c debug --no-parallel $(filter-out $@,$(MAKECMDGOALS))

dockertest:
	docker run --rm -v "$(shell pwd)":/workspace -w /workspace swift:latest swift test -c release --no-parallel $(filter-out $@,$(MAKECMDGOALS))

dockertest-debug:
	docker run --rm -v "$(shell pwd)":/workspace -w /workspace swift:latest swift test -c debug --no-parallel $(filter-out $@,$(MAKECMDGOALS))
