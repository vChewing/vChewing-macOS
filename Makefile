+.PHONY: all

# 定义日期和时间变量
DATE_DIR := $(shell date +%Y-%m-%d)
DATE_FILE := $(shell date +%Y-%-m-%-d)
TIME_FILE := $(shell date +%H.%M)
ARCHIVE_DIR := $(HOME)/Library/Developer/Xcode/Archives/$(DATE_DIR)
ARCHIVE_NAME := vChewingInstaller-$(DATE_FILE)-$(TIME_FILE).xcarchive
ARCHIVE_PATH := $(ARCHIVE_DIR)/$(ARCHIVE_NAME)

all: release
install: install-release
update:
	@git restore DictionaryData/
	git submodule update --init --recursive --remote --force

ifdef ARCHS
BUILD_SETTINGS += ARCHS="$(ARCHS)"
BUILD_SETTINGS += ONLY_ACTIVE_ARCH=NO
endif

spmDebug:
	swift build -c debug --package-path ./Packages/vChewing_MainAssembly/

spmRelease:
	swift build -c release --package-path ./Packages/vChewing_MainAssembly/

spmLintFormat:
	cd ./Packages/ && make lint --file=./Makefile || true
	cd ./Packages/ && make format --file=./Makefile || true

spmClean:
	@for currentDir in $$(ls ./Packages/); do \
		if [ -d $$a ]; then \
			echo "processing folder $$currentDir"; \
			swift package clean --package-path ./Packages/$$currentDir || true; \
		fi; \
	done;

spmLinuxTest-Typewriter:
	docker run --rm -v '$(shell pwd):/workspace' -w /workspace/Packages/vChewing_Typewriter swift:latest swift test --filter InputHandlerTests

release:
	@echo "Creating directory: $(ARCHIVE_DIR)"
	@mkdir -p "$(ARCHIVE_DIR)"
	@echo "Archiving to: $(ARCHIVE_PATH)"
	xcodebuild archive \
	-project vChewing.xcodeproj \
	-scheme vChewingInstaller \
	-configuration Release \
	-archivePath "$(ARCHIVE_PATH)" \
	-allowProvisioningUpdates

debug: 
	@echo "Building debug configuration"
	xcodebuild build \
	-project vChewing.xcodeproj \
	-scheme vChewingInstaller \
	-configuration Debug

DSTROOT = /Library/Input Methods
VC_APP_ROOT = $(DSTROOT)/vChewing.app

.PHONY: lint format

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

permission-check:
	[ -w "$(DSTROOT)" ] && [ -w "$(VC_APP_ROOT)" ] || sudo chown -R ${USER} "$(DSTROOT)"

install-debug: permission-check
	open Build/Products/Debug/vChewingInstaller.app

install-release: permission-check
	open Build/Products/Release/vChewingInstaller.app

.PHONY: clean

clean:
	make clean --file=./Packages/Makefile || true
	xcodebuild -scheme vChewingInstaller -configuration Debug $(BUILD_SETTINGS)  clean
	xcodebuild -scheme vChewingInstaller -configuration Release $(BUILD_SETTINGS) clean
	make clean --file=./DictionaryData/Makefile || true

clean-spm:
	find . -name ".build" -exec rm -rf {} \;
	rm -rf ./Packages/Build

gitclean:
	git clean -fdx

.PHONY: gc

gc:
	git reflog expire --expire=now --all && git gc --prune=now --aggressive

.PHONY: test

test:
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
