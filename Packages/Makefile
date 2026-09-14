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
