// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// 用以讓每個狀態自描述的 enum。
public enum StateType: String {
  case ofDeactivated = "Deactivated"
  case ofEmpty = "Empty"
  case ofAbortion = "Abortion"  // 該狀態會自動轉為 Empty
  case ofCommitting = "Committing"
  case ofAssociates = "Associates"
  case ofNotEmpty = "NotEmpty"
  case ofInputting = "Inputting"
  case ofMarking = "Marking"
  case ofCandidates = "Candidates"
  case ofSymbolTable = "SymbolTable"
}

// 所有 IMEState 均遵守該協定：
public protocol IMEStateProtocol {
  var type: StateType { get }
  var data: StateData { get }
  var candidates: [(String, String)] { get }
  var hasComposition: Bool { get }
  var isCandidateContainer: Bool { get }
  var displayedText: String { get }
  var textToCommit: String { get set }
  var tooltip: String { get set }
  var attributedString: NSAttributedString { get }
  var convertedToInputting: IMEState { get }
  var isFilterable: Bool { get }
  var node: SymbolNode { get set }
}

/// 用以呈現輸入法控制器（ctlInputMethod）的各種狀態。
///
/// 從實際角度來看，輸入法屬於有限態械（Finite State Machine）。其藉由滑鼠/鍵盤
/// 等輸入裝置接收輸入訊號，據此切換至對應的狀態，再根據狀態更新使用者介面內容，
/// 最終生成文字輸出、遞交給接收文字輸入行為的客體應用。此乃單向資訊流序，且使用
/// 者介面內容與文字輸出均無條件地遵循某一個指定的資料來源。
///
/// IMEState 型別用以呈現輸入法控制器正在做的事情，且分狀態儲存各種狀態限定的
/// 常數與變數。對輸入法而言，使用狀態模式（而非策略模式）來做這種常數變數隔離，
/// 可能會讓新手覺得會有些牛鼎烹雞，卻實際上變相減少了在程式維護方面的管理難度、
/// 不需要再在某個狀態下為了該狀態不需要的變數與常數的處置策略而煩惱。
///
/// 對 IMEState 型別下的諸多狀態的切換，應以生成新副本來取代舊有副本的形式來完
/// 成。唯一例外是 IMEState.ofMarking、擁有可以將自身轉變為 IMEState.ofInputting
/// 的成員函式，但也只是生成副本、來交給輸入法控制器來處理而已。每個狀態都有
/// 各自的構造器 (Constructor)。
///
/// 輸入法控制器持下述狀態：
///
/// - .Deactivated: 使用者沒在使用輸入法。
/// - .AssociatedPhrases: 逐字選字模式內的聯想詞輸入狀態。因為逐字選字模式不需要在
///   組字區內存入任何東西，所以該狀態不受 .NotEmpty 的管轄。
/// - .Empty: 使用者剛剛切換至該輸入法、卻還沒有任何輸入行為。抑或是剛剛敲字遞交給
///   客體應用、準備新的輸入行為。
/// - .Abortion: 與 Empty 類似，但會扔掉上一個狀態的內容、不將這些
///   內容遞交給客體應用。該狀態在處理完畢之後會被立刻切換至 .Empty()。
/// - .Committing: 該狀態會承載要遞交出去的內容，讓輸入法控制器處理時代為遞交。
/// - .NotEmpty: 非空狀態，是一種狀態大類、用以派生且代表下述諸狀態。
/// - .Inputting: 使用者輸入了內容。此時會出現組字區（Compositor）。
/// - .Marking: 使用者在組字區內標記某段範圍，可以決定是添入新詞、還是將這個範圍的
///   詞音組合放入語彙濾除清單。
/// - .ChoosingCandidate: 叫出選字窗、允許使用者選字。
/// - .SymbolTable: 波浪鍵符號選單專用的狀態，有自身的特殊處理。
public struct IMEState: IMEStateProtocol {
  public var type: StateType = .ofEmpty
  public var data: StateData = .init()
  public var node: SymbolNode = .init("")
  init(_ data: StateData = .init(), type: StateType = .ofEmpty) {
    self.data = data
    self.type = type
  }

  init(_ data: StateData = .init(), type: StateType = .ofEmpty, node: SymbolNode) {
    self.data = data
    self.type = type
    self.node = node
    self.data.candidates = { node.children?.map(\.title) ?? [String]() }().map { ("", $0) }
  }
}

// MARK: - 針對不同的狀態，規定不同的構造器

extension IMEState {
  public static func ofDeactivated() -> IMEState { .init(type: .ofDeactivated) }
  public static func ofEmpty() -> IMEState { .init(type: .ofEmpty) }
  public static func ofAbortion() -> IMEState { .init(type: .ofAbortion) }
  public static func ofCommitting(textToCommit: String) -> IMEState {
    var result = IMEState(type: .ofCommitting)
    result.data.textToCommit = textToCommit
    ChineseConverter.ensureCurrencyNumerals(target: &result.data.textToCommit)
    return result
  }

  public static func ofAssociates(candidates: [(String, String)]) -> IMEState {
    var result = IMEState(type: .ofAssociates)
    result.data.candidates = candidates
    return result
  }

  public static func ofNotEmpty(displayTextSegments: [String], cursor: Int) -> IMEState {
    var result = IMEState(type: .ofNotEmpty)
    // 注意資料的設定順序，一定得先設定 displayTextSegments。
    result.data.displayTextSegments = displayTextSegments
    result.data.cursor = cursor
    return result
  }

  public static func ofInputting(displayTextSegments: [String], cursor: Int) -> IMEState {
    var result = IMEState.ofNotEmpty(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofInputting
    return result
  }

  public static func ofMarking(
    displayTextSegments: [String], markedReadings: [String], cursor: Int, marker: Int
  )
    -> IMEState
  {
    var result = IMEState.ofNotEmpty(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofMarking
    result.data.marker = marker
    result.data.markedReadings = markedReadings
    StateData.Marking.updateParameters(&result.data)
    return result
  }

  public static func ofCandidates(candidates: [(String, String)], displayTextSegments: [String], cursor: Int) -> IMEState
  {
    var result = IMEState.ofNotEmpty(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofCandidates
    result.data.candidates = candidates
    return result
  }

  public static func ofSymbolTable(node: SymbolNode) -> IMEState {
    var result = IMEState(type: .ofNotEmpty, node: node)
    result.type = .ofSymbolTable
    return result
  }
}

// MARK: - 規定一個狀態該怎樣返回自己的資料值

extension IMEState {
  public var isFilterable: Bool { data.isFilterable }
  public var candidates: [(String, String)] { data.candidates }
  public var convertedToInputting: IMEState {
    if type == .ofInputting { return self }
    var result = IMEState.ofInputting(displayTextSegments: data.displayTextSegments, cursor: data.cursor)
    result.tooltip = data.tooltipBackupForInputting
    return result
  }

  public var textToCommit: String {
    get {
      data.textToCommit
    }
    set {
      data.textToCommit = newValue
    }
  }

  public var tooltip: String {
    get {
      data.tooltip
    }
    set {
      data.tooltip = newValue
    }
  }

  public var attributedString: NSAttributedString {
    switch type {
      case .ofMarking: return data.attributedStringMarking
      case .ofAssociates, .ofSymbolTable: return data.attributedStringPlaceholder
      default: return data.attributedStringNormal
    }
  }

  public var hasComposition: Bool {
    switch type {
      case .ofNotEmpty, .ofInputting, .ofMarking, .ofCandidates: return true
      default: return false
    }
  }

  public var isCandidateContainer: Bool {
    switch type {
      case .ofCandidates, .ofAssociates, .ofSymbolTable: return true
      default: return false
    }
  }

  public var displayedText: String { data.displayedText }
}
