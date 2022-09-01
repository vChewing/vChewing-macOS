// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

// MARK: - Tooltip Display and Candidate Display Methods

extension ctlInputMethod {
  func show(tooltip: String, composingBuffer: String, cursorIndex: Int) {
    guard let client = client() else { return }
    var lineHeightRect = NSRect(x: 0.0, y: 0.0, width: 16.0, height: 16.0)
    var cursor = cursorIndex
    if cursor == composingBuffer.count, cursor != 0 {
      cursor -= 1
    }
    while lineHeightRect.origin.x == 0, lineHeightRect.origin.y == 0, cursor >= 0 {
      client.attributes(
        forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect
      )
      cursor -= 1
    }
    var finalOrigin: NSPoint = lineHeightRect.origin
    if isVerticalTyping {
      finalOrigin = NSPoint(
        x: lineHeightRect.origin.x + lineHeightRect.size.width + 4.0, y: lineHeightRect.origin.y - 4.0
      )
      ctlInputMethod.tooltipController.direction = .vertical
    } else {
      ctlInputMethod.tooltipController.direction = .horizontal
    }
    ctlInputMethod.tooltipController.show(tooltip: tooltip, at: finalOrigin)
  }

  func show(candidateWindowWith state: InputStateProtocol) {
    guard let client = client() else { return }
    var isTypingVertical: Bool {
      if let state = state as? InputState.ChoosingCandidate {
        return state.isTypingVertical
      } else if let state = state as? InputState.AssociatedPhrases {
        return state.isTypingVertical
      }
      return false
    }
    var isCandidateWindowVertical: Bool {
      var candidates: [(String, String)] = .init()
      if let state = state as? InputState.ChoosingCandidate {
        candidates = state.candidates
      } else if let state = state as? InputState.AssociatedPhrases {
        candidates = state.candidates
      }
      if isTypingVertical { return true }
      // 接下來的判斷並非適用於 IMK 選字窗，所以先插入排除語句。
      guard ctlInputMethod.ctlCandidateCurrent is ctlCandidateUniversal else { return false }
      // 以上是通用情形。接下來決定橫排輸入時是否使用縱排選字窗。
      // 因為在拿候選字陣列時已經排序過了，所以這裡不用再多排序。
      // 測量每頁顯示候選字的累計總長度。如果太長的話就強制使用縱排候選字窗。
      // 範例：「屬實牛逼」（會有一大串各種各樣的「鼠食牛Beer」的 emoji）。
      let maxCandidatesPerPage = mgrPrefs.candidateKeys.count
      let firstPageCandidates = candidates[0..<min(maxCandidatesPerPage, candidates.count)].map(\.1)
      return firstPageCandidates.joined().count > Int(round(Double(maxCandidatesPerPage) * 1.8))
      // 上面這句如果是 true 的話，就會是縱排；反之則為橫排。
    }

    ctlInputMethod.ctlCandidateCurrent.delegate = nil

    /// 下面這一段本可直接指定 currentLayout，但這樣的話翻頁按鈕位置無法精準地重新繪製。
    /// 所以只能重新初期化。壞處就是得在 ctlCandidate() 當中與 SymbolTable 控制有關的地方
    /// 新增一個空狀態請求、防止縱排與橫排選字窗同時出現。
    /// layoutCandidateView 在這裡無法起到糾正作用。
    /// 該問題徹底解決的價值並不大，直接等到 macOS 10.x 全線淘汰之後用 SwiftUI 重寫選字窗吧。

    let candidateLayout: CandidateLayout =
      ((isCandidateWindowVertical || !mgrPrefs.useHorizontalCandidateList)
        ? CandidateLayout.vertical
        : CandidateLayout.horizontal)

    ctlInputMethod.ctlCandidateCurrent =
      mgrPrefs.useIMKCandidateWindow
      ? ctlCandidateIMK.init(candidateLayout) : ctlCandidateUniversal.init(candidateLayout)

    // set the attributes for the candidate panel (which uses NSAttributedString)
    let textSize = mgrPrefs.candidateListTextSize
    let keyLabelSize = max(textSize / 2, mgrPrefs.minKeyLabelSize)

    func labelFont(name: String?, size: CGFloat) -> NSFont {
      if let name = name {
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
      }
      return NSFont.systemFont(ofSize: size)
    }

    ctlInputMethod.ctlCandidateCurrent.keyLabelFont = labelFont(
      name: mgrPrefs.candidateKeyLabelFontName, size: keyLabelSize
    )
    ctlInputMethod.ctlCandidateCurrent.candidateFont = ctlInputMethod.candidateFont(
      name: mgrPrefs.candidateTextFontName, size: textSize
    )

    let candidateKeys = mgrPrefs.candidateKeys
    let keyLabels =
      candidateKeys.count > 4 ? Array(candidateKeys) : Array(mgrPrefs.defaultCandidateKeys)
    let keyLabelSuffix = state is InputState.AssociatedPhrases ? "^" : ""
    ctlInputMethod.ctlCandidateCurrent.keyLabels = keyLabels.map {
      CandidateKeyLabel(key: String($0), displayedText: String($0) + keyLabelSuffix)
    }

    ctlInputMethod.ctlCandidateCurrent.delegate = self
    ctlInputMethod.ctlCandidateCurrent.reloadData()

    // Spotlight 視窗會擋住 IMK 選字窗，所以需要特殊處理。
    if let ctlCandidateCurrent = ctlInputMethod.ctlCandidateCurrent as? ctlCandidateIMK {
      while ctlCandidateCurrent.windowLevel() <= client.windowLevel() {
        ctlCandidateCurrent.setWindowLevel(UInt64(max(0, client.windowLevel() + 1000)))
      }
    }

    ctlInputMethod.ctlCandidateCurrent.visible = true

    var lineHeightRect = NSRect(x: 0.0, y: 0.0, width: 16.0, height: 16.0)
    var cursor = 0

    if let state = state as? InputState.ChoosingCandidate {
      cursor = state.cursorIndex
      if cursor == state.composingBuffer.count, cursor != 0 {
        cursor -= 1
      }
    }

    while lineHeightRect.origin.x == 0, lineHeightRect.origin.y == 0, cursor >= 0 {
      client.attributes(
        forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect
      )
      cursor -= 1
    }

    if isTypingVertical {
      ctlInputMethod.ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(
          x: lineHeightRect.origin.x + lineHeightRect.size.width + 4.0, y: lineHeightRect.origin.y - 4.0
        ),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0
      )
    } else {
      ctlInputMethod.ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(x: lineHeightRect.origin.x, y: lineHeightRect.origin.y - 4.0),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0
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
  /// 1) Remove the usage of ".languageIdentifier" from ctlCandidateUniversal.swift (already done).
  /// 2) Run "make update" in the project folder to download the latest git-submodule of dictionary file.
  /// 3) Compile the target "vChewingInstaller", run it. It will install the input method into
  ///    "~/Library/Input Methods/" folder. Remember to ENABLE BOTH "vChewing-CHS"
  ///    and "vChewing-CHT" input sources in System Preferences / Settings.
  /// 4) Type Zhuyin "ej3" (ㄍㄨˇ) (or "gu3" in Pinyin if you enabled Pinyin typing in vChewing preferences.)
  ///    using both "vChewing-CHS" and "vChewing-CHT", and check the candidate window by pressing SPACE key.
  /// 5) Do NOT enable either KangXi conversion mode nor JIS conversion mode. They are disabled by default.
  /// 6) Expecting the glyph differences of the candidate "骨" between PingFang SC and PingFang TC when rendering
  ///    the candidate window in different "vChewing-CHS" and "vChewing-CHT" input modes.
  static func candidateFont(name: String? = nil, size: CGFloat) -> NSFont {
    let finalReturnFont: NSFont =
      {
        switch IME.currentInputMode {
          case InputMode.imeModeCHS:
            return CTFontCreateUIFontForLanguage(.system, size, "zh-Hans" as CFString)
          case InputMode.imeModeCHT:
            return (mgrPrefs.shiftJISShinjitaiOutputEnabled || mgrPrefs.chineseConversionEnabled)
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
