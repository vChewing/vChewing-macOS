# LibARCLite

此處置放了取自 Xcode 14.2 的 LibARCLite（`libarclite_macosx.a`）。

Xcode 14.3 起移除了該檔案。若 Deployment Target 低於 macOS 10.13 且需要建置 x86_64 架構，clang driver 會強制檢查 toolchain 內的 `usr/lib/arc/libarclite_macosx.a` 是否存在。

本專案已在 Xcode 專案層級指定 `LIBRARY_SEARCH_PATHS = $(SRCROOT)/ARCLite`（這足以應付 arm64 建置），並在 Makefile 內提供了 `setup-arc` 目標來自動建立 toolchain 內的符號連結：

```sh
make setup-arc
```

若直接使用 `make debug` 或 `make archive`，`setup-arc` 會在建置前自動執行。

## SDK 要求

若您使用的是 Xcode 15 開始的版本，還需手動將 macOS 13.x SDK 放入 Xcode 的 SDK 目錄：

```
/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/
```

- macOS 13.3 SDK 可取自 Xcode 14.3.1，也可從此處下載：
  https://github.com/alexey-lysiuk/macos-sdk/releases/tag/13.3

若使用 Xcode 16，還需額外安裝 Swift 5.10.1 Toolchain：
https://download.swift.org/swift-5.10.1-release/xcode/swift-5.10.1-RELEASE/swift-5.10.1-RELEASE-osx.pkg
