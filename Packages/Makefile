+.PHONY: all

all: debug

debug:
	swift build -c debug --package-path ./vChewing_MainAssembly/

release:
	swift build -c release --package-path ./vChewing_MainAssembly/

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
	@git ls-files --exclude-standard | grep -E '\.swift$$' | swiftlint --fix --autocorrect

.PHONY: permission-check install-debug install-release
