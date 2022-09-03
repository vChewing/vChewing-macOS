// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// 用以讓每個狀態自描述的 enum。
public enum StateType {
  case ofDeactivated
  case ofEmpty
  case ofAbortion  // 該狀態會自動轉為 Empty
  case ofCommitting
  case ofAssociates
  case ofNotEmpty
  case ofInputting
  case ofMarking
  case ofCandidates
  case ofSymbolTable
}

// 所有 InputState 均遵守該協定：
public protocol InputStateProtocol {
  var type: StateType { get }
  var data: StateData { get }
  var hasBuffer: Bool { get }
  var isCandidateContainer: Bool { get }
  var displayedText: String { get }
  var textToCommit: String { get set }
  var tooltip: String { get set }
  var attributedString: NSAttributedString { get }
  var node: SymbolNode { get set }
}

public struct IMEState {
  public var type: StateType = .ofEmpty
  public var data: StateData = .init()
  init(_ data: StateData = .init(), type: StateType = .ofEmpty) {
    self.data = data
    self.type = type
  }
}

// MARK: - 針對不同的狀態，規定不同的構造器

extension IMEState {
  public static func Deactivated() -> IMEState { .init(type: .ofDeactivated) }
  public static func Empty() -> IMEState { .init(type: .ofEmpty) }
  public static func Abortion() -> IMEState { .init(type: .ofAbortion) }
  public static func Committing(textToCommit: String) -> IMEState {
    var result = IMEState(type: .ofCommitting)
    result.data.textToCommit = textToCommit
    ChineseConverter.ensureCurrencyNumerals(target: &result.data.textToCommit)
    return result
  }

  public static func Associates(candidates: [(String, String)]) -> IMEState {
    var result = IMEState(type: .ofAssociates)
    result.data.candidates = candidates
    return result
  }

  public static func NotEmpty(nodeValues: [String], reading: String = "", cursor: Int) -> IMEState {
    var result = IMEState(type: .ofNotEmpty)
    // 注意資料的設定順序：nodeValuesArray 必須比 reading 先設定。
    result.data.nodeValuesArray = nodeValues
    if !reading.isEmpty {
      result.data.reading = reading  // 會在被寫入資料值後自動更新 nodeValuesArray
    }
    // 此時 nodeValuesArray 已經被塞上讀音，直接使用即可。
    result.data.displayedText = result.data.nodeValuesArray.joined()
    result.data.cursor = cursor
    return result
  }

  public static func Inputting(nodeValues: [String], reading: String = "", cursor: Int) -> IMEState {
    var result = IMEState.NotEmpty(nodeValues: nodeValues, reading: reading, cursor: cursor)
    result.type = .ofInputting
    return result
  }

  public static func Marking(nodeValues: [String], nodeReadings: [String], cursor: Int, marker: Int) -> IMEState {
    var result = IMEState.NotEmpty(nodeValues: nodeValues, cursor: cursor)
    result.type = .ofMarking
    result.data.nodeReadingsArray = nodeReadings
    result.data.marker = marker
    StateData.Marking.updateParameters(&result.data)
    return result
  }

  public static func Candidates(candidates: [(String, String)], nodeValues: [String], cursor: Int) -> IMEState {
    var result = IMEState.NotEmpty(nodeValues: nodeValues, cursor: cursor)
    result.type = .ofCandidates
    result.data.candidates = candidates
    return result
  }

  public static func SymbolTable(node: SymbolNode, previous: SymbolNode? = nil) -> IMEState {
    let candidates = { node.children?.map(\.title) ?? [String]() }().map { ("", $0) }
    var result = IMEState.Candidates(candidates: candidates, nodeValues: [], cursor: 0)
    result.type = .ofSymbolTable
    result.data.node = node
    if let previous = previous {
      result.data.node.previous = previous
    }
    return result
  }
}

// MARK: - 規定一個狀態該怎樣返回自己的資料值

extension IMEState: InputStateProtocol {
  public var convertedToInputting: IMEState {
    if type == .ofInputting { return self }
    var result = IMEState.Inputting(nodeValues: data.nodeValuesArray, reading: data.reading, cursor: data.cursor)
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

  public var node: SymbolNode {
    get {
      data.node
    }
    set {
      data.node = newValue
    }
  }

  public var tooltipBackupForInputting: String {
    get {
      data.tooltipBackupForInputting
    }
    set {
      data.tooltipBackupForInputting = newValue
    }
  }

  public var hasBuffer: Bool {
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
