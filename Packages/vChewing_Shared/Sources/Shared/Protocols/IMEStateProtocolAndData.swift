// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import IMKUtils
import InputMethodKit

// MARK: - IMEStateProtocol

// 所有 IMEState 均遵守該協定：
public protocol IMEStateProtocol {
  init(_ data: IMEStateData, type: StateType)
  init(_ data: IMEStateData, type: StateType, node: CandidateNode)
  var type: StateType { get }
  var data: IMEStateData { get set }
  var candidates: [(keyArray: [String], value: String)] { get set }
  var hasComposition: Bool { get }
  var isCandidateContainer: Bool { get }
  var displayedText: String { get }
  var displayedTextConverted: String { get }
  var textToCommit: String { get set }
  var tooltip: String { get set }
  var tooltipDuration: Double { get set }
  var convertedToInputting: Self { get }
  var isFilterable: Bool { get }
  var isMarkedLengthValid: Bool { get }
  var markedTargetIsCurrentlyFiltered: Bool { get }
  var node: CandidateNode { get set }
  var displayTextSegments: [String] { get }
  var tooltipBackupForInputting: String { get set }
  var markedRange: Range<Int> { get }
  var u16MarkedRange: Range<Int> { get }
  var u16Cursor: Int { get }
  var cursor: Int { get set }
  var marker: Int { get set }
  func attributedString(for session: IMKInputControllerProtocol) -> NSAttributedString

  static func ofDeactivated() -> Self
  static func ofEmpty() -> Self
  static func ofAbortion() -> Self
  static func ofCommitting(textToCommit: String) -> Self
  static func ofAssociates(candidates: [(keyArray: [String], value: String)]) -> Self
  static func ofInputting(
    displayTextSegments: [String],
    cursor: Int,
    highlightAt highlightAtSegment: Int?
  ) -> Self
  static func ofMarking(
    displayTextSegments: [String],
    markedReadings: [String],
    cursor: Int,
    marker: Int
  ) -> Self
  static func ofCandidates(
    candidates: [(keyArray: [String], value: String)],
    displayTextSegments: [String],
    cursor: Int
  ) -> Self
  static func ofSymbolTable(node: CandidateNode) -> Self
}

extension IMEStateProtocol {
  public init(
    _ data: IMEStateData = .init(),
    type: StateType = .ofEmpty
  ) {
    self.init(data, type: type)
  }
}

// MARK: - IMEStateData

public struct IMEStateData {
  // MARK: Lifecycle

  public init() {}

  // MARK: Public

  public var highlightAtSegment: Int?
  public var reading: String = ""
  public var markedReadings = [String]()
  public var candidates = [(keyArray: [String], value: String)]()
  public var textToCommit: String = ""

  // MARK: Tooltip neta.

  public var tooltip: String = ""
  public var tooltipDuration: Double = 1.0
  public var tooltipBackupForInputting: String = ""
  public var tooltipColorState: TooltipColorState = .normal

  public var cursor: Int = 0 {
    didSet {
      cursor = min(max(cursor, 0), displayedText.count)
    }
  }

  public var marker: Int = 0 {
    didSet {
      marker = min(max(marker, 0), displayedText.count)
    }
  }

  public var displayTextSegments = [String]() {
    didSet {
      displayedText = displayTextSegments.joined()
    }
  }

  public var displayedText: String = "" {
    didSet {
      if displayedText.rangeOfCharacter(from: .newlines) != nil {
        displayedText = displayedText.trimmingCharacters(in: .newlines)
      }
    }
  }
}
