import Foundation
import PackagePlugin

// MARK: - LexiconAssetRelayPlugin

/// 只做「搬運」的 buildTool plugin：把 `make lexiconModern` 先行產出的語料庫資產複製進本建置目標的
/// 資源集，取代原本由 `vChewing-VanguardLexicon` 的兩支 plugin 直接編譯注入的做法。
///
/// 動機：那兩支 plugin 的 build command **無 `inputFiles`**，SwiftPM 因此對每個 destination 各跑一次，
/// `make release` 的 arm64 與 x86_64 兩個 slice 便各建一次原廠辭典（各約 35–49 秒）。改為由
/// `LexiconZone/LexiconBuildTrigger` 以 host-only 建置一次、集中產物後，本 plugin 僅做位元組複製，
/// 成本以毫秒計，且對兩個架構都是同一個輸出路徑下的同一份內容。
///
/// 副作用（刻意、且已寫進 `AGENTS.md`）：裸跑 `swift build`／`swift test`／Xcode 建置時，若資產尚未產出，
/// 本 plugin 會**明確報錯**並指出該跑哪一條命令——而不是讓 app 靜默地少掉原廠辭典。
@main
struct LexiconAssetRelayPlugin: BuildToolPlugin {
  // MARK: Internal

  func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
    // 本 plugin 位於 `Packages/<套件>/Plugins/LexiconAssetRelay`，故倉根往上兩層。
    let repository = context.package.directoryURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
    let assetsDirectory = repository.appendingPathComponent("LexiconZone").appendingPathComponent("Build")

    let sources = Self.assetNames.map { assetsDirectory.appendingPathComponent($0) }
    let missing = sources.filter { !FileManager.default.fileExists(atPath: $0.path) }
    guard missing.isEmpty else {
      throw LexiconAssetsUnavailableError(
        names: missing.map { $0.lastPathComponent },
        directory: assetsDirectory.path
      )
    }

    let outputs = Self.assetNames.map { context.pluginWorkDirectoryURL.appendingPathComponent($0) }
    let destination = context.pluginWorkDirectoryURL.path
    let script = [
      "mkdir -p \(Self.quoted(destination))",
      "cp -f \(sources.map { Self.quoted($0.path) }.joined(separator: " ")) \(Self.quoted(destination))/",
    ].joined(separator: " && ")

    return [
      .buildCommand(
        displayName: "Relaying the prepared lexicon assets into \(target.name)",
        executable: URL(fileURLWithPath: "/bin/sh"),
        arguments: ["-c", script],
        inputFiles: sources,
        outputFiles: outputs
      ),
    ]
  }

  // MARK: Private

  /// 語料庫資產的檔名。三檔缺一不可：前兩者缺任何一份，`Bundle.currentSPM` 端會取不到片語範本。
  private static let assetNames = [
    "VanguardFactoryDict4Typing.txtMap",
    "template-associatedPhrases-cht.txt",
    "template-associatedPhrases-chs.txt",
  ]

  /// 以單引號包住 shell 參數，並把內部的單引號依 `'\''` 慣例轉義。
  private static func quoted(_ path: String) -> String {
    "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
  }
}

// MARK: - LexiconAssetsUnavailableError

/// 資產缺席時的回報。訊息刻意寫出「該跑哪一條命令」，因為這是本設計唯一的外部前置條件。
struct LexiconAssetsUnavailableError: Error, CustomStringConvertible {
  let names: [String]
  let directory: String

  var description: String {
    """
    Lexicon assets are missing from \(directory): \(names.joined(separator: ", ")).
    They are produced out of band so that a universal build compiles the factory lexicon only once.
    Run `make lexiconModern` in the repository root first (or `make debug` / `make release` /
    `make archive`, which all depend on it).
    """
  }
}
