// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - FileOpenMethod

public enum FileOpenMethod: String {
  case finder = "Finder"
  case textEdit = "TextEdit"
  case safari = "Safari"

  // MARK: Public

  public var appName: String {
    let englishFallback: String = {
      switch self {
      case .finder: return "Finder"
      case .textEdit: return "TextEdit"
      case .safari: return "Safari"
      }
    }()
    let tag = Locale.preferredLanguages.first?.lowercased().replacingOccurrences(
      of: "_",
      with: "-"
    )
    guard let tag = tag else { return englishFallback }
    switch tag.prefix(2) {
    case "ja":
      switch self {
      case .finder: return "Finder"
      case .textEdit: return "テキストエディット"
      case .safari: return "Safari"
      }
    case "zh" where tag.hasSuffix("-cn") || tag.hasSuffix("-hans"):
      if #available(macOS 10.13.2, *) {
        switch self {
        case .finder: return "访达"
        case .textEdit: return "文本编辑"
        case .safari: return "Safari浏览器"
        }
      } else {
        switch self {
        case .finder: return "Finder"
        case .textEdit: return "文本编辑"
        case .safari: return "Safari"
        }
      }
    case "zh-hant" where tag.hasSuffix("-tw") || tag.hasSuffix("-hk") || tag.hasSuffix("-hant"):
      switch self {
      case .finder: return "Finder"
      case .textEdit: return "文字編輯"
      case .safari: return "Safari"
      }
    default:
      return englishFallback
    }
  }

  public var bundleIdentifier: String {
    switch self {
    case .finder: return "com.apple.finder"
    case .textEdit: return "com.apple.TextEdit"
    case .safari: return "com.apple.Safari"
    }
  }

  public func open(url: URL) {
    switch self {
    case .finder: NSWorkspace.shared.activateFileViewerSelecting([url])
    default:
      if #unavailable(macOS 10.15) {
        NSWorkspace.shared.openFile(url.path, withApplication: appName)
        return
      } else {
        let textEditURL = NSWorkspace.shared
          .urlForApplication(withBundleIdentifier: bundleIdentifier)
        guard let textEditURL = textEditURL else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.promptsUserIfNeeded = true
        NSWorkspace.shared.open(
          [url],
          withApplicationAt: textEditURL,
          configuration: configuration
        )
      }
    }
  }
}
