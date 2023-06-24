// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import CandidateWindow
import NSAttributedTextView
import Shared

// MARK: - Tooltip Display and Candidate Display Methods

public extension SessionCtl {
  // 有些 App 會濫用內文組字區的內容來預測使用者的輸入行為。
  // 對此類 App 有疑慮者，可以將這類 App 登記到客體管理員當中。
  // 這樣，不但強制使用（限制讀音 20 個的）浮動組字窗，而且內文組字區只會顯示一個空格。
  var attributedStringSecured: (value: NSAttributedString, range: NSRange) {
    clientMitigationLevel >= 2
      ? (state.data.attributedStringPlaceholder(for: self), NSRange(location: 0, length: 0))
      : (state.attributedString(for: self), NSRange(state.u16MarkedRange))
  }

  func lineHeightRect(zeroCursor: Bool = false) -> NSRect {
    var lineHeightRect = NSRect.seniorTheBeast
    guard let client = client() else {
      return lineHeightRect
    }
    var u16Cursor: Int = state.u16MarkedRange.lowerBound
    u16Cursor = max(min(state.displayedTextConverted.utf16.count, u16Cursor), 0)
    if zeroCursor { u16Cursor = 0 }
    // iMessage 的話，據此算出來的 lineHeightRect 結果的橫向座標起始點不準確。目前無解。
    while lineHeightRect.origin.x == 0, lineHeightRect.origin.y == 0, u16Cursor >= 0 {
      client.attributes(
        forCharacterIndex: u16Cursor, lineHeightRectangle: &lineHeightRect
      )
      u16Cursor -= 1
    }
    return lineHeightRect
  }

  func showTooltip(_ tooltip: String, duration: Double = 0) {
    guard client() != nil else { return }
    if tooltip.isEmpty {
      tooltipInstance.hide()
      return
    }
    updateVerticalTypingStatus()
    let lineHeightRect = lineHeightRect()
    var finalOrigin: NSPoint = lineHeightRect.origin
    let delta: Double = lineHeightRect.size.height + 4.0 // bottomOutOfScreenAdjustmentHeight
    if isVerticalTyping {
      finalOrigin = NSPoint(
        x: lineHeightRect.origin.x + lineHeightRect.size.width + 5, y: lineHeightRect.origin.y
      )
    }
    let tooltipContentDirection: NSAttributedTextView.writingDirection = {
      if PrefMgr.shared.alwaysShowTooltipTextsHorizontally { return .horizontal }
      return isVerticalTyping ? .vertical : .horizontal
    }()
    // 強制重新初期化，因為 NSAttributedTextView 有顯示滯後性。
    do {
      tooltipInstance.hide()
      tooltipInstance = .init()
      tooltipInstance.setColor(state: state.data.tooltipColorState)
    }
    // 再設定其文字顯示內容並顯示。
    tooltipInstance.show(
      tooltip: tooltip, at: finalOrigin, bottomOutOfScreenAdjustmentHeight: delta,
      direction: tooltipContentDirection, duration: duration
    )
  }

  func showCandidates() {
    guard client() != nil else { return }
    defer { keepIMKCandidatesShownUp() }
    updateVerticalTypingStatus()
    isVerticalCandidateWindow = (isVerticalTyping || !PrefMgr.shared.useHorizontalCandidateList)

    /// 無論是田所選字窗還是 IMK 選字窗，在這裡都有必要重新初期化。
    let candidateLayout: NSUserInterfaceLayoutOrientation =
      ((isVerticalTyping || !PrefMgr.shared.useHorizontalCandidateList)
          ? .vertical
          : .horizontal)

    let isInputtingWithCandidates = state.type == .ofInputting && state.isCandidateContainer
    /// 先取消既有的選字窗的內容顯示。否則可能會重複生成選字窗的 NSWindow()。
    candidateUI?.visible = false
    if #available(macOS 10.13, *) {
      /// 然後再重新初期化。
      let useIMK = PrefMgr.shared.useIMKCandidateWindow
      candidateUI = useIMK ? CtlCandidateIMK(candidateLayout) : CtlCandidateTDK(candidateLayout)
    } else {
      candidateUI = CtlCandidateTDK(candidateLayout)
    }
    var singleLine = isVerticalTyping || PrefMgr.shared.candidateWindowShowOnlyOneLine
    singleLine = singleLine || isInputtingWithCandidates
    (candidateUI as? CtlCandidateTDK)?.maxLinesPerPage = singleLine ? 1 : 4
    if isInputtingWithCandidates, candidateLayout == .horizontal {
      (candidateUI as? CtlCandidateIMK)?.setPanelType(kIMKSingleRowSteppingCandidatePanel)
    }

    candidateUI?.candidateFont = Self.candidateFont(
      name: PrefMgr.shared.candidateTextFontName, size: PrefMgr.shared.candidateListTextSize
    )

    if state.type == .ofAssociates {
      candidateUI?.tooltip =
        singleLine ? "⇧" : NSLocalizedString("Hold ⇧ to choose associates.", comment: "")
    } else if state.type == .ofInputting, state.isCandidateContainer {
      let useShift = LMMgr.currentLM.areCassetteCandidateKeysShiftHeld
      let theEmoji = useShift ? "⬆️" : "⚡️"
      candidateUI?.tooltip =
        singleLine ? theEmoji : "\(theEmoji) " + NSLocalizedString("Quick Candidates", comment: "")
    } else if PrefMgr.shared.cassetteEnabled {
      candidateUI?.tooltip =
        singleLine ? "📼" : "📼 " + NSLocalizedString("CIN Cassette Mode", comment: "")
    }

    candidateUI?.locale = {
      switch inputMode {
      case .imeModeCHS: return "zh-Hans"
      case .imeModeCHT:
        if !PrefMgr.shared.shiftJISShinjitaiOutputEnabled, !PrefMgr.shared.chineseConversionEnabled {
          return "zh-Hant"
        }
        return "ja"
      default: return ""
      }
    }()

    if let ctlCandidateCurrent = candidateUI as? CtlCandidateTDK {
      ctlCandidateCurrent.useMouseScrolling = PrefMgr.shared.enableMouseScrollingForTDKCandidatesCocoa
      if #available(macOS 10.15, *) {
        ctlCandidateCurrent.useCocoa = !PrefMgr.shared.enableSwiftUIForTDKCandidates
      }
    }

    candidateUI?.delegate = self // 會自動觸發田所選字窗的資料重載。
    candidateUI?.visible = true

    resetCandidateWindowOrigin()
  }

  func resetCandidateWindowOrigin() {
    if isVerticalTyping {
      candidateUI?.set(
        windowTopLeftPoint: NSPoint(
          x: lineHeightRect().origin.x + lineHeightRect().size.width + 4.0, y: lineHeightRect().origin.y - 4.0
        ),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect().size.height + 4.0,
        useGCD: true
      )
    } else {
      candidateUI?.set(
        windowTopLeftPoint: NSPoint(x: lineHeightRect().origin.x, y: lineHeightRect().origin.y - 4.0),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect().size.height + 4.0,
        useGCD: true
      )
    }
  }

  /// FB10978412: Since macOS 11 Big Sur, CTFontCreateUIFontForLanguage cannot
  /// distinguish zh-Hans and zh-Hant with correct adoptation of proper PingFang SC/TC variants.
  /// Update: This has been fixed in macOS 13.
  ///
  /// Instructions for Apple Developer relations to reveal this bug:
  ///
  /// 0) Disable IMK Candidate window in the vChewing preferences (disabled by default).
  ///    **REASON**: IMKCandidates has bug that it does not respect font attributes attached to the
  ///    results generated from `candidiates() -> [Any]!` function. IMKCandidates is plagued with
  ///    bugs which are not dealt in the recent decade, regardless Radar complaints from input method developers.
  /// 1) Make sure the usage of ".languageIdentifier" is disabled in the Dev Zone of the vChewing SSPreferences.
  /// 2) Run "make update" in the project folder to download the latest git-submodule of dictionary file.
  /// 3) Compile the target "vChewingInstaller", run it. It will install the input method into
  ///    "~/Library/Input Methods/" folder. Remember to ENABLE BOTH "vChewing-CHS"
  ///    and "vChewing-CHT" input sources in System Preferences / Settings.
  /// 4) Type Zhuyin "ej3" (ㄍㄨˇ) (or "gu3" in Pinyin if you enabled Pinyin typing in vChewing SSPreferences.)
  ///    using both "vChewing-CHS" and "vChewing-CHT", and check the candidate window by pressing SPACE key.
  /// 5) Do NOT enable either KangXi conversion mode nor JIS conversion mode. They are disabled by default.
  /// 6) Expecting the glyph differences of the candidate "骨" between PingFang SC and PingFang TC when rendering
  ///    the candidate window in different "vChewing-CHS" and "vChewing-CHT" input modes.
  static func candidateFont(name: String? = nil, size: Double) -> NSFont {
    let finalReturnFont: NSFont = {
      switch IMEApp.currentInputMode {
      case .imeModeCHS:
        return CTFontCreateUIFontForLanguage(.system, size, "zh-Hans" as CFString)
      case .imeModeCHT:
        return (PrefMgr.shared.shiftJISShinjitaiOutputEnabled || PrefMgr.shared.chineseConversionEnabled)
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
