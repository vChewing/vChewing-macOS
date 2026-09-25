// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit

// MARK: - AssistantLauncher

/// 配置助手（Configuration Assistant）之啟動器。
///
/// **何以需要「兩態」**：輸入法之 main bundle **未必**同捆配置助手。P246 之收錄步驟是**選配**的
/// ——當且僅當建置時偵測到 `tsc`，才編譯助手之產物並收錄為
/// `Contents/Resources/assistant/assistant.html`；未偵測到即僅給警告、不中斷建置。
/// 故「未同捆」是設計上之**常態之一**，而非例外；此時之唯一去路是官網之最新版。
///
/// 本型別即該判準之**唯一**出處——SwiftUI 面板與 AppKit 面板共用它，免得兩側各寫一份而漂移。
///
/// **判準之即時性**：`bundledURL`／`hasBundledAssistant` 一律**現求**，不得於面板載入時快取
/// ——使用者可能在同一台機器上換裝輸入法之 bundle。
public enum AssistantLauncher {
  /// 官網之配置助手（最新版）之網址字串。
  public static let onlineURLString = "https://vchewing.github.io/assistant/"

  /// 官網之配置助手（最新版）；字面量無法解析時為 `nil`。
  public static var onlineURL: URL? { URL(string: onlineURLString) }

  /// 當前輸入法 main bundle 內同捆之配置助手；未同捆時為 `nil`。
  ///
  /// 落點照 P246：`<vChewing.app>/Contents/Resources/assistant/assistant.html`
  /// ⇒ 以 `subdirectory:` 指名該子目錄（`Bundle` 之資源根即 `Contents/Resources`）。
  public static var bundledURL: URL? {
    Bundle.main.url(forResource: "assistant", withExtension: "html", subdirectory: "assistant")
  }

  /// 當前輸入法 main bundle 內是否同捆配置助手。
  public static var hasBundledAssistant: Bool { bundledURL != nil }

  /// 開啟同捆之配置助手（交給系統之預設瀏覽器）；未同捆時回 `false`。
  @discardableResult
  public static func openBundled() -> Bool {
    guard let url = bundledURL else { return false }
    return NSWorkspace.shared.open(url)
  }

  /// 開啟官網之配置助手；網址無法解析時回 `false`。
  @discardableResult
  public static func openOnline() -> Bool {
    guard let url = onlineURL else { return false }
    return NSWorkspace.shared.open(url)
  }
}
