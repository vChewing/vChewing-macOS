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

extension SessionCtl {
  // 有些 App 會濫用內文組字區的內容來預測使用者的輸入行為。
  // 對此類 App 有疑慮者，可以將這類 App 登記到客體管理員當中。
  // 這樣，不但強制使用（限制讀音 20 個的）浮動組字窗，而且內文組字區只會顯示一個空格。
  var attributedStringSecured: (NSAttributedString, NSRange) {
    PrefMgr.shared.clientsIMKTextInputIncapable.contains(clientBundleIdentifier)
      ? (state.data.attributedStringPlaceholder, NSRange(location: 0, length: 0))
      : (state.attributedString, NSRange(state.u16MarkedRange))
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

  func show(tooltip: String) {
    guard client() != nil else { return }
    let lineHeightRect = lineHeightRect()
    var finalOrigin: NSPoint = lineHeightRect.origin
    let delta: Double = lineHeightRect.size.height + 4.0  // bottomOutOfScreenAdjustmentHeight
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
      Self.tooltipInstance.hide()
      Self.tooltipInstance = .init()
      if state.type == .ofMarking {
        Self.tooltipInstance.setColor(state: state.data.tooltipColorState)
      }
    }
    // 再設定其文字顯示內容並顯示。
    Self.tooltipInstance.show(
      tooltip: tooltip, at: finalOrigin,
      bottomOutOfScreenAdjustmentHeight: delta, direction: tooltipContentDirection
    )
  }

  func showCandidates() {
    guard let client = client() else { return }
    var isCandidateWindowVertical: Bool {
      // var candidates: [(String, String)] = .init()
      // if state.isCandidateContainer { candidates = state.candidates }
      if isVerticalTyping { return true }
      // 接下來的判斷並非適用於 IMK 選字窗，所以先插入排除語句。
      // guard Self.ctlCandidateCurrent is CtlCandidateUniversal else { return false }
      // 以上是通用情形。接下來決定橫排輸入時是否使用縱排選字窗。
      // 因為在拿候選字陣列時已經排序過了，所以這裡不用再多排序。
      // 測量每頁顯示候選字的累計總長度。如果太長的話就強制使用縱排候選字窗。
      // 範例：「屬實牛逼」（會有一大串各種各樣的「鼠食牛Beer」的 emoji）。
      // let maxCandidatesPerPage = PrefMgr.shared.candidateKeys.count
      // let firstPageCandidates = candidates[0..<min(maxCandidatesPerPage, candidates.count)].map(\.1)
      // return firstPageCandidates.joined().count > Int(round(Double(maxCandidatesPerPage) * 1.8))
      // 上面這句如果是 true 的話，就會是縱排；反之則為橫排。
      return false
    }

    state.isVerticalCandidateWindow = (isCandidateWindowVertical || !PrefMgr.shared.useHorizontalCandidateList)

    Self.ctlCandidateCurrent.delegate = nil

    /// 下面這一段本可直接指定 currentLayout，但這樣的話翻頁按鈕位置無法精準地重新繪製。
    /// 所以只能重新初期化。壞處就是得在 ctlCandidate() 當中與 SymbolTable 控制有關的地方
    /// 新增一個空狀態請求、防止縱排與橫排選字窗同時出現。
    /// layoutCandidateView 在這裡無法起到糾正作用。
    /// 該問題徹底解決的價值並不大，直接等到 macOS 10.x 全線淘汰之後用 SwiftUI 重寫選字窗吧。

    let candidateLayout: NSUserInterfaceLayoutOrientation =
      ((isCandidateWindowVertical || !PrefMgr.shared.useHorizontalCandidateList)
        ? .vertical
        : .horizontal)

    if #available(macOS 10.15, *) {
      Self.ctlCandidateCurrent =
        PrefMgr.shared.useIMKCandidateWindow
        ? CtlCandidateIMK(candidateLayout) : CtlCandidateTDK(candidateLayout)
    } else {
      Self.ctlCandidateCurrent = CtlCandidateIMK(candidateLayout)
    }

    // set the attributes for the candidate panel (which uses NSAttributedString)
    let textSize = PrefMgr.shared.candidateListTextSize
    let minimumKeyLabelSize: Double = 10
    let keyLabelSize = max(textSize / 2, minimumKeyLabelSize)

    func labelFont(name: String?, size: Double) -> NSFont {
      if let name = name {
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
      }
      return NSFont.systemFont(ofSize: size)
    }

    Self.ctlCandidateCurrent.keyLabelFont = labelFont(
      name: PrefMgr.shared.candidateKeyLabelFontName, size: keyLabelSize
    )
    Self.ctlCandidateCurrent.candidateFont = Self.candidateFont(
      name: PrefMgr.shared.candidateTextFontName, size: textSize
    )

    let candidateKeys = PrefMgr.shared.candidateKeys
    let keyLabels =
      candidateKeys.count > 4 ? Array(candidateKeys) : Array(CandidateKey.defaultKeys)
    let keyLabelSuffix = state.type == .ofAssociates ? "^" : ""
    Self.ctlCandidateCurrent.keyLabels = keyLabels.map {
      CandidateCellData(key: String($0), displayedText: String($0) + keyLabelSuffix)
    }

    if state.type == .ofAssociates {
      Self.ctlCandidateCurrent.hint = NSLocalizedString("Hold ⇧ to choose associates.", comment: "")
    }

    Self.ctlCandidateCurrent.useLangIdentifier = PrefMgr.shared.handleDefaultCandidateFontsByLangIdentifier
    Self.ctlCandidateCurrent.locale = {
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

    if #available(macOS 10.14, *) {
      // Spotlight 視窗會擋住 IMK 選字窗，所以需要特殊處理。
      if let ctlCandidateCurrent = Self.ctlCandidateCurrent as? CtlCandidateIMK {
        while ctlCandidateCurrent.windowLevel() <= client.windowLevel() {
          ctlCandidateCurrent.setWindowLevel(UInt64(max(0, client.windowLevel() + 1000)))
        }
      }
    }

    Self.ctlCandidateCurrent.delegate = self
    Self.ctlCandidateCurrent.visible = true

    if isVerticalTyping {
      Self.ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(
          x: lineHeightRect().origin.x + lineHeightRect().size.width + 4.0, y: lineHeightRect().origin.y - 4.0
        ),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect().size.height + 4.0
      )
    } else {
      Self.ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(x: lineHeightRect().origin.x, y: lineHeightRect().origin.y - 4.0),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect().size.height + 4.0
      )
    }
  }

  /// FB10978412: Since macOS 11 Big Sur, CTFontCreateUIFontForLanguage cannot
  /// distinguish zh-Hans and zh-Hant with correct adoptation of proper PingFang SC/TC variants.
  ///
  /// Instructions for Apple Developer relations to reveal this bug:
  ///
  /// 0) Disable IMK Candidate window in the vChewing preferences (disabled by default).
  ///    **REASON**: IMKCandidates has bug that it does not respect font attributes attached to the
  ///    results generated from `candidiates() -> [Any]!` function. IMKCandidates is plagued with
  ///    bugs which are not dealt in the recent decade, regardless Radar complaints from input method developers.
  /// 1) Make sure the usage of ".languageIdentifier" is disabled in the Dev Zone of the vChewing Preferences.
  /// 2) Run "make update" in the project folder to download the latest git-submodule of dictionary file.
  /// 3) Compile the target "vChewingInstaller", run it. It will install the input method into
  ///    "~/Library/Input Methods/" folder. Remember to ENABLE BOTH "vChewing-CHS"
  ///    and "vChewing-CHT" input sources in System Preferences / Settings.
  /// 4) Type Zhuyin "ej3" (ㄍㄨˇ) (or "gu3" in Pinyin if you enabled Pinyin typing in vChewing preferences.)
  ///    using both "vChewing-CHS" and "vChewing-CHT", and check the candidate window by pressing SPACE key.
  /// 5) Do NOT enable either KangXi conversion mode nor JIS conversion mode. They are disabled by default.
  /// 6) Expecting the glyph differences of the candidate "骨" between PingFang SC and PingFang TC when rendering
  ///    the candidate window in different "vChewing-CHS" and "vChewing-CHT" input modes.
  static func candidateFont(name: String? = nil, size: Double) -> NSFont {
    let finalReturnFont: NSFont =
      {
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
