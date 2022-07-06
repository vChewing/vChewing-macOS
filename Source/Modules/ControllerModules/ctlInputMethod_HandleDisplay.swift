// Copyright (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Cocoa
import Foundation

// MARK: - Tooltip Display and Candidate Display Methods

extension ctlInputMethod {
  func show(tooltip: String, composingBuffer: String, cursorIndex: Int) {
    var lineHeightRect = NSRect(x: 0.0, y: 0.0, width: 16.0, height: 16.0)
    var cursor = cursorIndex
    if cursor == composingBuffer.count, cursor != 0 {
      cursor -= 1
    }
    while lineHeightRect.origin.x == 0, lineHeightRect.origin.y == 0, cursor >= 0 {
      client().attributes(
        forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect
      )
      cursor -= 1
    }
    ctlInputMethod.tooltipController.show(tooltip: tooltip, at: lineHeightRect.origin)
  }

  func show(candidateWindowWith state: InputStateProtocol) {
    var isTypingVertical: Bool {
      if let state = state as? InputState.ChoosingCandidate {
        return state.isTypingVertical
      } else if let state = state as? InputState.AssociatedPhrases {
        return state.isTypingVertical
      }
      return false
    }
    var isCandidateWindowVertical: Bool {
      var candidates: [String] = []
      if let state = state as? InputState.ChoosingCandidate {
        candidates = state.candidates
      } else if let state = state as? InputState.AssociatedPhrases {
        candidates = state.candidates
      }
      if isTypingVertical { return true }
      // 以上是通用情形。接下來決定橫排輸入時是否使用縱排選字窗。
      candidates.sort {
        $0.count > $1.count
      }
      // 測量每頁顯示候選字的累計總長度。如果太長的話就強制使用縱排候選字窗。
      // 範例：「屬實牛逼」（會有一大串各種各樣的「鼠食牛Beer」的 emoji）。
      let maxCandidatesPerPage = mgrPrefs.candidateKeys.count
      let firstPageCandidates = candidates[0..<min(maxCandidatesPerPage, candidates.count)]
      return firstPageCandidates.joined().count > Int(round(Double(maxCandidatesPerPage) * 1.8))
      // 上面這句如果是 true 的話，就會是縱排；反之則為橫排。
    }

    ctlCandidateCurrent.delegate = nil

    /// 下面這一段本可直接指定 currentLayout，但這樣的話翻頁按鈕位置無法精準地重新繪製。
    /// 所以只能重新初期化。壞處就是得在 ctlCandidate() 當中與 SymbolTable 控制有關的地方
    /// 新增一個空狀態請求、防止縱排與橫排選字窗同時出現。
    /// layoutCandidateView 在這裡無法起到糾正作用。
    /// 該問題徹底解決的價值並不大，直接等到 macOS 10.x 全線淘汰之後用 SwiftUI 重寫選字窗吧。

    if isCandidateWindowVertical {  // 縱排輸入時強制使用縱排選字窗
      ctlCandidateCurrent = .init(.vertical)
    } else if mgrPrefs.useHorizontalCandidateList {
      ctlCandidateCurrent = .init(.horizontal)
    } else {
      ctlCandidateCurrent = .init(.vertical)
    }

    // set the attributes for the candidate panel (which uses NSAttributedString)
    let textSize = mgrPrefs.candidateListTextSize
    let keyLabelSize = max(textSize / 2, mgrPrefs.minKeyLabelSize)

    func labelFont(name: String?, size: CGFloat) -> NSFont {
      if let name = name {
        return NSFont(name: name, size: size) ?? NSFont.systemFont(ofSize: size)
      }
      return NSFont.systemFont(ofSize: size)
    }

    func candidateFont(name: String?, size: CGFloat) -> NSFont {
      let currentMUIFont =
        (keyHandler.inputMode == InputMode.imeModeCHS)
        ? "Sarasa Term Slab SC" : "Sarasa Term Slab TC"
      var finalReturnFont =
        NSFont(name: currentMUIFont, size: size) ?? NSFont.systemFont(ofSize: size)
      // 對更紗黑體的依賴到 macOS 11 Big Sur 為止。macOS 12 Monterey 開始則依賴系統內建的函式使用蘋方來處理。
      if #available(macOS 12.0, *) { finalReturnFont = NSFont.systemFont(ofSize: size) }
      if let name = name {
        return NSFont(name: name, size: size) ?? finalReturnFont
      }
      return finalReturnFont
    }

    ctlCandidateCurrent.keyLabelFont = labelFont(
      name: mgrPrefs.candidateKeyLabelFontName, size: keyLabelSize
    )
    ctlCandidateCurrent.candidateFont = candidateFont(
      name: mgrPrefs.candidateTextFontName, size: textSize
    )

    let candidateKeys = mgrPrefs.candidateKeys
    let keyLabels =
      candidateKeys.count > 4 ? Array(candidateKeys) : Array(mgrPrefs.defaultCandidateKeys)
    let keyLabelSuffix = state is InputState.AssociatedPhrases ? "^" : ""
    ctlCandidateCurrent.keyLabels = keyLabels.map {
      CandidateKeyLabel(key: String($0), displayedText: String($0) + keyLabelSuffix)
    }

    ctlCandidateCurrent.delegate = self
    ctlCandidateCurrent.reloadData()

    ctlCandidateCurrent.visible = true

    var lineHeightRect = NSRect(x: 0.0, y: 0.0, width: 16.0, height: 16.0)
    var cursor = 0

    if let state = state as? InputState.ChoosingCandidate {
      cursor = state.cursorIndex
      if cursor == state.composingBuffer.count, cursor != 0 {
        cursor -= 1
      }
    }

    while lineHeightRect.origin.x == 0, lineHeightRect.origin.y == 0, cursor >= 0 {
      client().attributes(
        forCharacterIndex: cursor, lineHeightRectangle: &lineHeightRect
      )
      cursor -= 1
    }

    if isTypingVertical {
      ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(
          x: lineHeightRect.origin.x + lineHeightRect.size.width + 4.0, y: lineHeightRect.origin.y - 4.0
        ),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0
      )
    } else {
      ctlCandidateCurrent.set(
        windowTopLeftPoint: NSPoint(x: lineHeightRect.origin.x, y: lineHeightRect.origin.y - 4.0),
        bottomOutOfScreenAdjustmentHeight: lineHeightRect.size.height + 4.0
      )
    }
  }
}
