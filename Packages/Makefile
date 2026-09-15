.PHONY: all

all: debug

debug:
	swift build -c debug --package-path ./vChewing_MainAssembly4Darwin/

release:
	swift build -c release --package-path ./vChewing_MainAssembly4Darwin/

clean:
	@for currentDir in $$(ls ./); do \
		if [ -d "./$$currentDir" ]; then \
			echo "processing folder $$currentDir"; \
			swift package clean --package-path "./$$currentDir" || true; \
		fi; \
	done;
	@# 聚合體目錄內之巢狀子套件（`<聚合體>/Deps/<子套件>`）：僅在直接對其建置時才會生成
	@# 獨立的 .build，故須一併清掃，否則殘留物件會在下一次建置造成假失敗。
	@for nestedDep in ./*/Deps/*; do \
		if [ -f "$$nestedDep/Package.swift" ]; then \
			echo "processing nested dep $$nestedDep"; \
			swift package clean --package-path "$$nestedDep" || true; \
		fi; \
	done;
	@# Swift 5.10 側的 scratch（逐包 `makefile` 的 `LEGACY_SCRATCH`，含巢狀子套件者）：只清 `.legacy*`，
	@# 不動 `.build` 內其餘既有產物。
	@rm -rf ./*/.build/.legacy* ./*/Deps/*/.build/.legacy*

# ── Swift 5.10 側：逐包編譯性測試的總入口 ──────────────────────────────
#
# 逐包入口由各套件自己的 `makefile`（`make build510`）承擔，此處只做彙總，故不逐一列出各套件
# 目標。凡無 makefile 或其中無對應目標者，一律略過並列報；個別套件失敗亦不中斷整輪。

.PHONY: build510-all clean510-all

build510-all:
	@export LC_ALL=C; \
	failed=""; skipped=""; \
	for currentDir in $$(ls ./); do \
		if [ ! -d "./$$currentDir" ] || [ ! -f "./$$currentDir/Package.swift" ]; then continue; fi; \
		if [ ! -f "./$$currentDir/makefile" ] || ! grep -qE '^build510:' "./$$currentDir/makefile"; then \
			skipped="$$skipped $$currentDir"; \
			continue; \
		fi; \
		echo "== Swift 5.10 build: $$currentDir"; \
		if ( cd "./$$currentDir" && make build510 ); then \
			echo "   ✓ $$currentDir"; \
		else \
			rc=$$?; echo "   ✗ $$currentDir (rc=$$rc)"; failed="$$failed $$currentDir"; \
		fi; \
	done; \
	if [ -n "$$skipped" ]; then echo "未就位（無 makefile 或無 build510 目標）：$$skipped"; fi; \
	if [ -n "$$failed" ]; then echo "失敗：$$failed"; exit 1; fi; \
	echo "Swift 5.10 build pass finished."

clean510-all:
	@export LC_ALL=C; \
	skipped=""; \
	for currentDir in $$(ls ./); do \
		if [ ! -d "./$$currentDir" ] || [ ! -f "./$$currentDir/Package.swift" ]; then continue; fi; \
		if [ ! -f "./$$currentDir/makefile" ] || ! grep -qE '^clean510:' "./$$currentDir/makefile"; then \
			skipped="$$skipped $$currentDir"; \
			continue; \
		fi; \
		echo "== Swift 5.10 clean: $$currentDir"; \
		if ( cd "./$$currentDir" && make clean510 ); then \
			echo "   ✓ $$currentDir"; \
		else \
			echo "   ✗ $$currentDir"; \
		fi; \
	done; \
	if [ -n "$$skipped" ]; then echo "未就位（無 makefile 或無 clean510 目標）：$$skipped"; fi; \
	echo "Swift 5.10 clean pass finished."

# Pin LC_ALL so CJK collation stays identical regardless of the machine's locale settings.
.PHONY: lint format lintFormat

lintFormat: lint format

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

.PHONY: permission-check install-debug install-release
