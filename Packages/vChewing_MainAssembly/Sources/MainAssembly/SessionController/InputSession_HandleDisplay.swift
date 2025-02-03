// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import CandidateWindow
import IMKUtils
import NSAttributedTextView
import Shared

// MARK: - Tooltip Display and Candidate Display Methods

extension SessionProtocol {
  // 有些 App 會濫用內文組字區的內容來預測使用者的輸入行為。
  // 對此類 App 有疑慮者，可以將這類 App 登記到客體管理員當中。
  // 這樣，不但強制使用（限制讀音 20 個的）浮動組字窗，而且內文組字區只會顯示一個空格。
  public var attributedStringSecured: (value: NSAttributedString, range: NSRange) {
    clientMitigationLevel >= 2
      ? (state.data.attributedStringPlaceholder(for: self), NSRange(location: 0, length: 0))
      : (state.attributedString(for: self), NSRange(state.u16MarkedRange))
  }

  public var u16Cursor: Int {
    var u16Cursor: Int = state.u16MarkedRange.lowerBound
    if !PrefMgr.shared.useDynamicCandidateWindowOrigin, state.isCandidateContainer {
      u16Cursor = state.u16Cursor
    }
    return max(min(state.displayedTextConverted.utf16.count, u16Cursor), 0)
  }

  public func lineHeightRect(zeroCursor: Bool = false) -> NSRect {
    guard let client = client() else { return .seniorTheBeast }
    return client.lineHeightRect(u16Cursor: zeroCursor ? 0 : u16Cursor)
  }

  public func showTooltip(_ tooltip: String, duration: Double = 0) {
    guard client() != nil else { return }
    if tooltip.isEmpty {
      tooltipInstance.hide()
      return
    }
    let lineHeightRect = updateVerticalTypingStatus()
    var finalOrigin: NSPoint = lineHeightRect.origin
    let delta: Double = lineHeightRect.size.height + 4.0 // bottomOutOfScreenAdjustmentHeight
    if isVerticalTyping {
      finalOrigin = NSPoint(
        x: lineHeightRect.origin.x + lineHeightRect.size.width + 5, y: lineHeightRect.origin.y
      )
    }
    let tooltipContentDirection: NSUserInterfaceLayoutOrientation = {
      if PrefMgr.shared.alwaysShowTooltipTextsHorizontally { return .horizontal }
      return isVerticalTyping ? .vertical : .horizontal
    }()
    // 強制重新初期化，因為有顯示滯後性。
    do {
      tooltipInstance.hide()
      tooltipInstance = Self.makeTooltipUI()
      tooltipInstance.setColor(state: state.data.tooltipColorState)
    }
    // 再設定其文字顯示內容並顯示。
    tooltipInstance.show(
      tooltip: tooltip, at: finalOrigin, bottomOutOfScreenAdjustmentHeight: delta,
      direction: tooltipContentDirection, duration: duration
    )
  }

  public func showCandidates() {
    guard client() != nil else { return }
    updateVerticalTypingStatus()
    let isServiceMenu = state.type == .ofSymbolTable && state.node.containsCandidateServices
    isVerticalCandidateWindow = isVerticalTyping || !PrefMgr.shared.useHorizontalCandidateList
    isVerticalCandidateWindow = isVerticalCandidateWindow || isServiceMenu

    /// 無論是田所選字窗還是 IMK 選字窗，在這裡都有必要重新初期化。
    let candidateLayout: NSUserInterfaceLayoutOrientation =
      (isVerticalCandidateWindow ? .vertical : .horizontal)

    let isInputtingWithCandidates = state.type == .ofInputting && state.isCandidateContainer
    /// 先取消既有的選字窗的內容顯示。否則可能會重複生成選字窗的 NSWindow()。
    candidateUI?.visible = false
    candidateUI = CtlCandidateTDK(candidateLayout)
    var singleLine = isVerticalTyping || PrefMgr.shared.candidateWindowShowOnlyOneLine
    singleLine = singleLine || isInputtingWithCandidates
    singleLine = singleLine || isServiceMenu

    (candidateUI as? CtlCandidateTDK)?.maxLinesPerPage = singleLine ? 1 : 4

    candidateUI?.candidateFont = Self.candidateFont(
      name: PrefMgr.shared.candidateTextFontName, size: PrefMgr.shared.candidateListTextSize
    )

    candidateUI?.locale = localeForFontFallbacks

    if let ctlCandidateCurrent = candidateUI as? CtlCandidateTDK {
      ctlCandidateCurrent.useMouseScrolling = PrefMgr.shared
        .enableMouseScrollingForTDKCandidatesCocoa
    }

    candidateUI?.delegate = self // 會自動觸發田所選字窗的資料重載。
    candidateUI?.visible = true

    resetCandidateWindowOrigin()
  }

  public func resetCandidateWindowOrigin() {
    let lhRect = lineHeightRect()
    var tlPoint = NSPoint(x: lhRect.origin.x, y: lhRect.origin.y - 4.0)
    tlPoint.x += isVerticalTyping ? (lhRect.size.width + 4.0) : 0
    candidateUI?.set(
      windowTopLeftPoint: tlPoint,
      bottomOutOfScreenAdjustmentHeight: lhRect.size.height + 4.0,
      useGCD: true
    )
  }

  public var localeForFontFallbacks: String {
    switch inputMode {
    case .imeModeCHS: return "zh-Hans"
    case .imeModeCHT:
      if !PrefMgr.shared.shiftJISShinjitaiOutputEnabled, !PrefMgr.shared.chineseConversionEnabled {
        return "zh-Hant"
      }
      return "ja"
    default: return ""
    }
  }

  /// FB10978412: Since macOS 11 Big Sur, CTFontCreateUIFontForLanguage cannot
  /// distinguish zh-Hans and zh-Hant with correct adoptation of proper PingFang SC/TC variants.
  /// Update: This has been fixed in macOS 13.
  ///
  /// Instructions for Apple Developer relations to reveal this bug:
  ///
  /// 0) Please go to Step 1. Reason: IMK Candidate Window support has been removed in this repo.
  /// 1) Make sure the usage of ".languageIdentifier" is disabled in the Dev Zone of the vChewing Preferences.
  /// 2) Run "make update" in the project folder to download the latest git-submodule of dictionary file.
  /// 3) Compile the target "vChewingInstaller", run it. It will install the input method into
  ///    "~/Library/Input Methods/" folder. Remember to ENABLE BOTH "vChewing-CHS"
  ///    and "vChewing-CHT" input sources in System Preferences / Settings.
  /// 4) Type Zhuyin "ej3" (ㄍㄨˇ) (or "gu3" in Pinyin if you enabled Pinyin typing in vChewing Preferences.)
  ///    using both "vChewing-CHS" and "vChewing-CHT", and check the candidate window by pressing SPACE key.
  /// 5) Do NOT enable either KangXi conversion mode nor JIS conversion mode. They are disabled by default.
  /// 6) Expecting the glyph differences of the candidate "骨" between PingFang SC and PingFang TC when rendering
  ///    the candidate window in different "vChewing-CHS" and "vChewing-CHT" input modes.
  public static func candidateFont(name: String? = nil, size: Double) -> NSFont {
    let finalReturnFont: NSFont = {
      switch IMEApp.currentInputMode {
      case .imeModeCHS:
        return CTFontCreateUIFontForLanguage(.system, size, "zh-Hans" as CFString)
      case .imeModeCHT:
        return (
          PrefMgr.shared.shiftJISShinjitaiOutputEnabled || PrefMgr.shared
            .chineseConversionEnabled
        )
          ? CTFontCreateUIFontForLanguage(.system, size, "ja" as CFString)
          : CTFontCreateUIFontForLanguage(.system, size, "zh-Hant" as CFString)
      default:
        return CTFontCreateUIFontForLanguage(.system, size, nil)
      }
    }()
      ?? NSFont.systemFont(ofSize: size)
    if let name = name, !name.isEmpty {
      return NSFont(name: name, size: size) ?? finalReturnFont
    }
    return finalReturnFont
  }
}
