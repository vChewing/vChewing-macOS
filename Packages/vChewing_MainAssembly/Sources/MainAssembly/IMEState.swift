// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import IMKUtils
import InputMethodKit
import LangModelAssembly
import Shared

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

  /// 內部專用初期化函式，僅用於生成「有輸入內容」的狀態。
  /// - Parameters:
  ///   - displayTextSegments: 用以顯示的文本的字詞字串陣列，其中包含正在輸入的讀音或字根。
  ///   - cursor: 要顯示的游標（UTF8）。
  fileprivate init(displayTextSegments: [String], cursor: Int) {
    // 注意資料的設定順序，一定得先設定 displayTextSegments。
    data.displayTextSegments = displayTextSegments.map {
      if !InputSession.isVerticalTyping { return $0 }
      guard PrefMgr.shared.hardenVerticalPunctuations else { return $0 }
      var neta = $0
      ChineseConverter.hardenVerticalPunctuations(
        target: &neta,
        convert: InputSession.isVerticalTyping
      )
      return neta
    }
    data.cursor = cursor
    data.marker = cursor
  }

  /// 泛用初期化函式。
  /// - Parameters:
  ///   - data: 資料載體。
  ///   - type: 狀態類型。
  ///   - node: 節點。
  public init(
    _ data: IMEStateData,
    type: StateType = .ofEmpty,
    node: CandidateNode
  ) {
    self.data = data
    self.type = type
    self.node = node
    self.data.candidates = node.members.map { ([""], $0.name) }
  }

  // MARK: Public

  public var type: StateType = .ofEmpty
  public var data: IMEStateData = .init()
  public var node: CandidateNode = .init(name: "")
}

// MARK: - 針對不同的狀態，規定不同的構造器

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

  public static func ofAssociates(candidates: [(keyArray: [String], value: String)]) -> IMEState {
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
    candidates: [(keyArray: [String], value: String)],
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
    var result = Self(IMEStateData(), node: node)
    result.type = .ofSymbolTable
    return result
  }
}

// MARK: - 規定一個狀態該怎樣返回自己的資料值

extension IMEState {
  public var isFilterable: Bool { data.isFilterable }
  public var markedTargetIsCurrentlyFiltered: Bool { data.markedTargetIsCurrentlyFiltered }
  public var isMarkedLengthValid: Bool { data.isMarkedLengthValid }
  public var displayedText: String { data.displayedText }
  public var displayedTextConverted: String { data.displayedTextConverted }
  public var displayTextSegments: [String] { data.displayTextSegments }
  public var markedRange: Range<Int> { data.markedRange }
  public var u16MarkedRange: Range<Int> { data.u16MarkedRange }
  public var u16Cursor: Int { data.u16Cursor }

  public var cursor: Int {
    get { data.cursor }
    set { data.cursor = newValue }
  }

  public var marker: Int {
    get { data.marker }
    set { data.marker = newValue }
  }

  public var convertedToInputting: Self {
    if type == .ofInputting { return self }
    var result = Self.ofInputting(
      displayTextSegments: data.displayTextSegments,
      cursor: data.cursor
    )
    result.tooltip = data.tooltipBackupForInputting
    return result
  }

  public var candidates: [(keyArray: [String], value: String)] {
    get { data.candidates }
    set { data.candidates = newValue }
  }

  public var textToCommit: String {
    get { data.textToCommit }
    set { data.textToCommit = newValue }
  }

  public var tooltip: String {
    get { data.tooltip }
    set { data.tooltip = newValue }
  }

  public func attributedString(for session: IMKInputControllerProtocol) -> NSAttributedString {
    switch type {
    case .ofMarking: return data.attributedStringMarking(for: session)
    case .ofCandidates where cursor != marker: return data.attributedStringMarking(for: session)
    case .ofCandidates where cursor == marker: break
    case .ofAssociates: return data.attributedStringPlaceholder(for: session)
    case .ofSymbolTable where displayedText.isEmpty || node.containsCandidateServices:
      return data.attributedStringPlaceholder(for: session)
    case .ofSymbolTable where !displayedText.isEmpty: break
    default: break
    }
    return data.attributedStringNormal(for: session)
  }

  /// 該參數僅用作輔助判斷。在 InputHandler 內使用的話，必須再檢查 !compositor.isEmpty。
  public var hasComposition: Bool {
    switch type {
    case .ofCandidates, .ofInputting, .ofMarking: return true
    default: return false
    }
  }

  public var isCandidateContainer: Bool {
    switch type {
    case .ofSymbolTable: return !node.members.isEmpty
    case .ofAssociates, .ofCandidates, .ofInputting: return !candidates.isEmpty
    default: return false
    }
  }

  public var tooltipBackupForInputting: String {
    get { data.tooltipBackupForInputting }
    set { data.tooltipBackupForInputting = newValue }
  }

  public var tooltipDuration: Double {
    get { type == .ofMarking ? 0 : data.tooltipDuration }
    set { data.tooltipDuration = newValue }
  }
}
