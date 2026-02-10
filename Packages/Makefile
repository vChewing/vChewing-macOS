+.PHONY: all

all: debug

debug:
	swift build -c debug --package-path ./vChewing_MainAssembly4Darwin/

release:
	swift build -c release --package-path ./vChewing_MainAssembly4Darwin/

clean:
	@for currentDir in $$(ls ./); do \
		if [ -d $$a ]; then \
			echo "processing folder $$currentDir"; \
			swift package clean --package-path ./$$currentDir || true; \
		fi; \
	done;

.PHONY: lint format

lintFormat: lint format

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

.PHONY: permission-check install-debug install-release
