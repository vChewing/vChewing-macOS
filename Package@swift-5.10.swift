// swift-tools-version: 5.10
import PackageDescription

// 本檔是 `Package.swift`（tools 6.4）的 **Swift 5.10 對位版**：同一份 `Sources/` 於 Swift 5.10 toolchain 下
// 以本 manifest 建置，於 Swift 6.4 以上以 `Package.swift` 建置。SwiftPM 之版本擇定規則為「於
// `Package*.swift` 全集中，取**檔內宣告**的 tools version 不高於 toolchain 版本者之**最高者**；同版時
// `Package.swift` 勝出」——故 5.10 toolchain 恆取本檔、6.0／6.1 因目錄內沒有任何不高於己身的宣告而無檔可
// 選、6.2／6.3 各由同目錄的封堵檔接下、6.4 以上取 `Package.swift`。
//
// 與 `Package.swift` 的刻意差異：
//
// 1. **`platforms` 填 `nil`**。PackageDescription 能宣告的 macOS 最低值只有 10.10，一旦宣告即被明文寫入
//    產物的 `LC_BUILD_VERSION`；本側索性不宣告平台限制，讓 SDK 之預設值說話。
// 2. **不使用 6.x 才有的設定**：`.defaultIsolation(MainActor.self)` 為 tools 6.2 起才存在；本側語言模式
//    即 5.10 toolchain 之預設（Swift 5），另以 `swiftLanguageVersions: [.v5]` 明示。
// 3. **兩支執行檔額外摻入 LibARCLite**（本側獨有；`Package.swift` 無此需要）：機理見下方
//    `libArcLite` 之註解。**該 link flag 已於 2026-09-16 移出本 manifest**——`releaseLegacy` 起
//    改出 universal 產物，其中 arm64 slice 不能摻它（該 archive 僅有 x86_64），而 manifest 看不到
//    目標 triple；故改由倉根 `makefile` 依 `LEGACY_X86_TRIPLE` 逐支線決定（見該檔「Swift 5.10
//    (legacy) build entry point」一節）。直接手動 `swift build` 而不經 makefile 者，須自行補
//    `-Xlinker -force_load -Xlinker ./LegacyZone/ARCLite/libarclite_macosx.a`。
// 4. **installer 的 target 與 executable 更名為 `vChewingInstallerLegacy`**（`Package.swift` 側仍為
//    `vChewingInstaller`）：同一份 `Sources/Installer_macOS/` 在 5.10 側是 macOS 10.9 專用的另一支
//    installer，不與 6.4 側的產物同名。
// 5. **build plugin 改宣告 `BundleAppsLegacy`**（`Package.swift` 側為 `BundleApps`）：現代 bundler 將
//    deployment target 寫死 macOS 12、並以 `vChewingInstaller` 之名取執行檔，對本側不適用；本側改由
//    `BundleAppsLegacy` 自各 Xcode 蒐集 back-deployment Swift 執行期動態庫，補鏈到兩支執行檔上、並於
//    `Build/Products/Legacy/` 組出兩份 `.app`（輸出目錄與現代側分開，因 IME bundle 恆名 `vChewing.app`）。
//
// 環境配對與各項差異的機理見 vChewing-DevLogs/Research/Phase217_SOP.md §三／§四。

// MARK: - LibARCLite

// 本側的兩支執行檔是這條建置路徑上唯二的「最終連結」產物（其餘套件只出靜態 `.a`，不帶 load command），
// ARC 執行期的後援因此也得在此處完成。
//
// 機理（2026-09-16 實測；Swift 5.10.1 ＋ `MacOSX13.3.sdk`，`x86_64-apple-macosx10.10`）：
//
// - clang driver 對「ObjC 執行期目標低於 macOS 10.13 且含 x86_64」者，會自行對 toolchain 內之
//   `usr/lib/arc/libarclite_macosx.a` 下一道 `-force_load`；Xcode 14.3 起該檔已自 toolchain 移除。
// - 但 SwiftPM 的執行檔連結走的是 **swift driver**，它**不做這道注入**（`-v` 實查：整條 link 指令只有
//   `libswiftCompatibility*.a`，無任何 arclite 痕跡）。故本側必須自己補上。
// - 補法必須是 **`-force_load`**：只給 `-L` ＋ `-larclite_macosx` 的話，ld 逕以 SDK 版 libobjc 的匯出
//   滿足 `objc_retainAutoreleasedReturnValue` 等符號、**一個 arclite 成員都不抽**（實測：產物內 arclite
//   符號計 0 個；改 `-force_load` 則 27～28 個），亦即 `-l` 形同虛設。
// - swift driver 不認得裸的 `-force_load`（`unknown argument`），須以 `-Xlinker` 轉交 ld——無論寫在
//   `linkerSettings` 還是下在建置指令上，都只有這一種表達法。
// - 路徑為相對路徑：SwiftPM 執行建置命令時之 cwd 即套件根（5.10 實測；由外部 cwd 下 `--package-path`
//   亦然），故相對路徑得予解析。
// - arm64 不需要本項（其 ARC 執行期自 macOS 11 起即在 libobjc 內）——而本檔不為 arm64 另立條件：
//   manifest 看不到目標 triple（`#if arch()` 反映的是**宿主**，而本機正是 arm64 宿主跨編 x86_64，用宿主
//   條件反而會把該有的 flags 濾掉）。故 2026-09-16 起本項**整條移交倉根 `makefile`**，由它以
//   `LEGACY_X86_TRIPLE` 逐支線下 `-Xlinker -force_load -Xlinker …`（arm64 支線不下）；該 flag 本身
//   無法在此表達為「非 arm64 才生效」，manifest 也無從得知 triple——這是移交的唯一原因。

#if os(macOS)
  let package = Package(
    name: "vChewingIME",
    platforms: nil,
    products: [
      .executable(
        name: "vChewing",
        targets: ["vChewing"]
      ),
      .executable(
        name: "vChewingInstallerLegacy",
        targets: ["vChewingInstallerLegacy"]
      ),
    ],
    dependencies: [
      .package(path: "./Packages/vChewing_InstallerAssembly4Darwin"),
      .package(path: "./Packages/vChewing_MainAssembly4Darwin"),
    ],
    targets: [
      // MARK: - Executable Targets

      .executableTarget(
        name: "vChewing",
        dependencies: [
          .product(name: "MainAssembly4Darwin", package: "vChewing_MainAssembly4Darwin"),
        ],
        path: "./Sources/vChewingIME_macOS",
        exclude: ["Resources"],
        sources: ["Modules"]
      ),
      .executableTarget(
        name: "vChewingInstallerLegacy",
        dependencies: [
          .product(name: "InstallerAssembly4Darwin", package: "vChewing_InstallerAssembly4Darwin"),
        ],
        path: "./Sources/Installer_macOS",
        exclude: ["Resources"]
      ),

      // MARK: - Build Plugin

      /// Re-points the two legacy executables at the back-deployment Swift runtime (`libswiftCore.dylib`,
      /// `libswiftFoundation.dylib`, …) collected from every Xcode bundle under `/Applications` — the
      /// Swift runtime the macOS 10.9 host has to carry, since it ships none of its own — and assembles
      /// the two `.app` bundles under `Build/Products/Legacy/`.
      ///
      /// Usage:
      /// ```
      /// swift package --allow-writing-to-package-directory bundle-apps-legacy -- --debug
      /// swift package --allow-writing-to-package-directory bundle-apps-legacy \
      ///   -- --build-dir .build/.legacy-root/x86_64-apple-macosx/release \
      ///      --sdk /Library/Developer/CommandLineTools/SDKs/MacOSX13.3.sdk
      /// ```
      ///
      /// `--build-dir` is needed whenever the legacy build used a custom `--scratch-path`
      /// (`make bundleLegacy` passes it). `--sdk` names the SDK the executables were linked
      /// against; `make bundleLegacy` passes its `LEGACY_SDK`, and the plugin reads that SDK's own
      /// platform to stamp the `DT*` build-environment keys into both Info.plists. Omit it and the
      /// bundles simply carry no such record. The plugin itself is compiled by the **host** SDK, which
      /// `--sdk` does not reach: run this with Xcode 15 as the active developer directory, or the
      /// Swift 5.10 compiler gets handed a macOS 27 SDK and dies on
      /// `could not build Objective-C module 'Foundation'`.
      .plugin(
        name: "BundleAppsLegacy",
        capability: .command(
          intent: .custom(
            verb: "bundle-apps-legacy",
            description: "Assemble the legacy .app bundles, embedding the Swift runtime dylibs collected from the installed Xcodes"
          ),
          permissions: [
            .writeToPackageDirectory(
              reason: "Copies the collected dylibs and the assembled bundles into the package directory and rewrites the executables' load commands"
            ),
          ]
        )
      ),
    ]
  )

#else

  let package = Package(
    name: "vChewingIME",
    targets: []
  )

#endif
