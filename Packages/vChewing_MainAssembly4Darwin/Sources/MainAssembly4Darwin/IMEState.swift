// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import IMKSwift

// MARK: - IMEState

/// 用以呈現輸入法控制器（SessionCtl）的各種狀態。
///
/// 從實際角度來看，輸入法屬於有限態械（Finite State Machine）。其藉由滑鼠/鍵盤
/// 等輸入裝置接收輸入訊號，據此切換至對應的狀態，再根據狀態更新使用者介面內容，
/// 最終生成文字輸出、遞交給接收文字輸入行為的客體應用。此乃單向資訊流序，且使用
/// 者介面內容與文字輸出均無條件地遵循某一個指定的資料來源。
///
/// IMEState 型別用以呈現輸入法控制器正在做的事情，且分狀態儲存各種狀態限定的
/// 常數與變數。
///
/// 對 IMEState 型別下的諸多狀態的切換，應以生成新副本來取代舊有副本的形式來完
/// 成。唯一例外是 IMEState.ofMarking、擁有可以將自身轉變為 IMEState.ofInputting
/// 的成員函式，但也只是生成副本、來交給輸入法控制器來處理而已。每個狀態都有
/// 各自的構造器 (Constructor)。
///
/// 輸入法控制器持下述狀態請洽 StateType Enum 的 Documentation。
public struct IMEState: IMEStateProtocol {
  // MARK: Lifecycle

  public init(
    _ data: IMEStateData = IMEStateData(),
    type: StateType = .ofEmpty
  ) {
    self.data = data
    self.type = type
  }

  /// 泛用初期化函式。
  /// - Parameters:
  ///   - data: 資料載體。
  ///   - type: 狀態類型。
  ///   - node: 節點。
  public init(
    _ data: IMEStateData,
    type: StateType = .ofSymbolTable,
    node: CandidateNode
  ) {
    self.data = data
    self.type = type
    self.node = node
    self.data.candidates = node.members.map { ([""], $0.name) }
    if node.members.isEmpty {
      var newDisplayTextSegments = [node.name]
      Self.hardenVerticalPunctuationsIfNeeded(&newDisplayTextSegments)
      self.data.displayTextSegments = newDisplayTextSegments
      self.data.cursor = self.data.displayTextSegments.first?.count ?? node.name.count
      self.data.marker = self.data.cursor
    } else {
      self.data.displayTextSegments.removeAll()
      self.data.cursor = 0
      self.data.marker = 0
    }
  }

  // MARK: Public

  public var type: StateType = .ofEmpty
  public var data: IMEStateData = .init()
  public var node: CandidateNode = .init(name: "")
}

// MARK: - 針對不同的狀態，規定不同的構造器

extension IMEStateProtocol {
  /// 內部專用初期化函式，僅用於生成「有輸入內容」的狀態。
  /// - Parameters:
  ///   - displayTextSegments: 用以顯示的文本的字詞字串陣列，其中包含正在輸入的讀音或字根。
  ///   - cursor: 要顯示的游標（UTF8）。
  fileprivate init(displayTextSegments: [String], cursor: Int) {
    self.init(.init(), type: .ofEmpty)
    // 注意資料的設定順序，一定得先設定 displayTextSegments。
    var newDisplayTextSegments = displayTextSegments
    Self.hardenVerticalPunctuationsIfNeeded(&newDisplayTextSegments)
    data.displayTextSegments = newDisplayTextSegments
    data.cursor = cursor
    data.marker = cursor
  }

  fileprivate static func hardenVerticalPunctuationsIfNeeded(_ target: inout [String]) {
    if !InputSession.isVerticalTyping || !PrefMgr.shared.hardenVerticalPunctuations { return }
    target.indices.forEach { i in
      ChineseConverter.hardenVerticalPunctuations(
        target: &target[i],
        convert: true
      )
    }
  }

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
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
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
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofMarking
    result.data.marker = marker
    result.data.markedReadings = markedReadings
    result.data.updateTooltipForMarking()
    return result
  }

  public static func ofCandidates(
    candidates: [CandidateInState],
    displayTextSegments: [String],
    cursor: Int
  )
    -> IMEState {
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofCandidates
    result.data.candidates = candidates
    return result
  }

  public static func ofSymbolTable(node: CandidateNode) -> IMEState {
    .init(IMEStateData(), type: .ofSymbolTable, node: node)
  }

  /// 數字快打模式的狀態。
  /// - Parameters:
  ///   - precedingText: 數字快打前方的已組中文（可為空字串）
  ///   - numberBuffer: 使用者輸入的數字/算式/日期/時間緩衝（可為空字串）
  ///   - candidates: 格式化後的候選清單
  ///   - displayHint: 即時計算結果預覽（如 "= 6000"），nil 表示無
  public static func ofNumberInput(
    precedingText: String,
    numberBuffer: String,
    candidates: [CandidateInState],
    displayHint: String?
  ) -> IMEState {
    var result = IMEState(type: .ofNumberInput)
    let hintSuffix = displayHint.map { " \($0)" } ?? ""
    let displayStr = numberBuffer.isEmpty ? "數字快打" : numberBuffer + hintSuffix
    var newSegments = precedingText.isEmpty ? [displayStr] : [precedingText, displayStr]
    Self.hardenVerticalPunctuationsIfNeeded(&newSegments)
    result.data.displayTextSegments = newSegments
    result.data.cursor = result.data.displayedText.count
    result.data.marker = result.data.cursor
    result.data.candidates = candidates
    result.data.numberBuffer = numberBuffer
    if candidates.isEmpty && !numberBuffer.isEmpty {
      // 正在輸入但尚無有效候選（格式不完整）
    } else if candidates.isEmpty {
      // 剛進入模式，顯示操作說明提示（tooltip 永久顯示）
      result.data.tooltip = "數字 例：123\n日期 例：2020.5.6\n時間 例：13:00\n算數 例：20*300"
      result.data.tooltipDuration = 0
      result.data.tooltipColorState = .prompt
    }
    return result
  }

  /// 近音表選字模式的狀態。
  /// - Parameters:
  ///   - rows: 近音表各列資料（第一列為藍底列）。
  ///   - selectedRow: 目前藍底列的索引（預設 0）。
  ///   - displayTextSegments: 組字區的文字段落（與 ofInputting 相同）。
  ///   - cursor: 組字區游標位置。
  public static func ofSimilarPhonetic(
    rows: [SimilarPhoneticRow],
    selectedRow: Int,
    displayTextSegments: [String],
    cursor: Int
  ) -> IMEState {
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofSimilarPhonetic
    result.data.similarPhoneticRows = rows
    result.data.selectedSimilarPhoneticRow = max(0, min(selectedRow, rows.count - 1))
    return result
  }
}

// MARK: - 規定一個狀態該怎樣返回自己的資料值

extension IMEStateProtocol {
  public var markedTargetIsCurrentlyFiltered: Bool { data.markedTargetIsCurrentlyFiltered }
  public var displayedTextConverted: String { data.displayedTextConverted }

  public var attributedString: NSAttributedString {
    switch type {
    case .ofMarking: return data.attributedStringMarking
    case .ofCandidates where cursor != marker: return data.attributedStringMarking
    case .ofCandidates where cursor == marker: break
    case .ofAssociates: return data.attributedStringPlaceholder
    case .ofSymbolTable where displayedText.isEmpty || node.containsCandidateServices:
      return data.attributedStringPlaceholder
    case .ofSymbolTable where !displayedText.isEmpty: break
    default: break
    }
    return data.attributedStringNormal
  }
}
