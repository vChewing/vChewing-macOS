// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit

// MARK: - 針對不同的狀態，規定不同的構造器

extension IMEStateProtocol {
  /// 內部專用初期化函式，僅用於生成「有輸入內容」的狀態。
  /// - Parameters:
  ///   - displayTextSegments: 用以顯示的文本的字詞字串陣列，其中包含正在輸入的讀音或字根。
  ///   - cursor: 要顯示的游標（UTF8）。
  fileprivate init(displayTextSegments: [String], cursor: Int) {
    self.init(.init(), type: .ofEmpty)
    // 注意資料的設定順序，一定得先設定 displayTextSegments。
    data.displayTextSegments = displayTextSegments
    data.cursor = cursor
    data.marker = cursor
  }
}

// Factory methods on concrete IMEState to shadow Shared baseline
// and provide Darwin-specific logic (hardenVerticalPunctuationsIfNeeded,
// generateTooltipForMarking, ChineseConverter.ensureCurrencyNumerals).
extension IMEState {
  public static func ofDeactivated() -> IMEState { .init(type: .ofDeactivated) }
  public static func ofEmpty() -> IMEState { .init(type: .ofEmpty) }
  public static func ofAbortion() -> IMEState { .init(type: .ofAbortion) }

  /// 用以手動遞交指定內容的狀態。
  /// - Remark: 直接切換至該狀態的話，會丟失上一個狀態的內容。
  /// 如不想丟失的話，請先切換至 `.ofEmpty()` 再切換至 `.ofCommitting()`。
  /// - Parameter textToCommit: 要遞交的文本。
  /// - Returns: 要切換到的狀態。
  public static func ofCommitting(textToCommit: String) -> IMEState {
    var result = IMEState(type: .ofCommitting)
    result.textToCommit = textToCommit
    ChineseConverter.ensureCurrencyNumerals(target: &result.data.textToCommit)
    return result
  }

  public static func ofAssociates(candidates: [CandidateInState]) -> IMEState {
    var result = IMEState(type: .ofAssociates)
    result.candidates = candidates
    return result
  }

  public static func ofInputting(
    displayTextSegments: [String],
    cursor: Int,
    highlightAt highlightAtSegment: Int? = nil
  )
    -> IMEState {
    var newDisplayTextSegments = displayTextSegments
    IMEStateParsed4Darwin.hardenVerticalPunctuationsIfNeeded(&newDisplayTextSegments)
    var result = IMEState(displayTextSegments: newDisplayTextSegments, cursor: cursor)
    result.type = .ofInputting
    if let readingAtSegment = highlightAtSegment {
      result.data.highlightAtSegment = readingAtSegment
    }
    return result
  }

  public static func ofMarking(
    displayTextSegments: [String],
    markedReadings: [String],
    cursor: Int,
    marker: Int
  )
    -> IMEState {
    var newDisplayTextSegments = displayTextSegments
    IMEStateParsed4Darwin.hardenVerticalPunctuationsIfNeeded(&newDisplayTextSegments)
    var result = IMEState(displayTextSegments: newDisplayTextSegments, cursor: cursor)
    result.type = .ofMarking
    result.data.marker = marker
    result.data.markedReadings = markedReadings
    let tooltipResult = IMEStateParsed4Darwin(result).generateTooltipForMarking()
    result.data.tooltip = tooltipResult.tooltip
    result.data.tooltipColorState = tooltipResult.colorState
    if PrefMgr.shared.phraseReplacementEnabled {
      result.data.tooltipColorState = .warning
      result.data.tooltip += "\n" + "⚠︎ Phrase replacement mode enabled, interfering user phrase entry.".i18n
    }
    return result
  }

  public static func ofCandidates(
    candidates: [CandidateInState],
    displayTextSegments: [String],
    cursor: Int
  )
    -> IMEState {
    var newDisplayTextSegments = displayTextSegments
    IMEStateParsed4Darwin.hardenVerticalPunctuationsIfNeeded(&newDisplayTextSegments)
    var result = IMEState(displayTextSegments: newDisplayTextSegments, cursor: cursor)
    result.type = .ofCandidates
    result.data.candidates = candidates
    return result
  }

  public static func ofSymbolTable(node: CandidateNode) -> IMEState {
    .init(IMEStateData(), type: .ofSymbolTable, node: node)
  }
}
