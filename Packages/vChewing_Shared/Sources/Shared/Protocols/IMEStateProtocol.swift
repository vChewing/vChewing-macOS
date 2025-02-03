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
  var type: StateType { get }
  var data: IMEStateDataProtocol { get set }
  var candidates: [(keyArray: [String], value: String)] { get set }
  var hasComposition: Bool { get }
  var isCandidateContainer: Bool { get }
  var displayedText: String { get }
  var displayedTextConverted: String { get }
  var textToCommit: String { get set }
  var tooltip: String { get set }
  var tooltipDuration: Double { get set }
  var convertedToInputting: IMEStateProtocol { get }
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
}

// MARK: - IMEStateDataProtocol

public protocol IMEStateDataProtocol {
  var cursor: Int { get set }
  var marker: Int { get set }
  var markedRange: Range<Int> { get }
  var u16MarkedRange: Range<Int> { get }
  var u16Cursor: Int { get }
  var textToCommit: String { get set }
  var markedReadings: [String] { get set }
  var displayTextSegments: [String] { get set }
  var highlightAtSegment: Int? { get set }
  var isFilterable: Bool { get }
  var isMarkedLengthValid: Bool { get }
  var markedTargetIsCurrentlyFiltered: Bool { get }
  var candidates: [(keyArray: [String], value: String)] { get set }
  var displayedText: String { get set }
  var displayedTextConverted: String { get }
  var tooltipBackupForInputting: String { get set }
  var tooltip: String { get set }
  var tooltipDuration: Double { get set }
  var userPhraseKVPair: (keyArray: [String], value: String) { get }
  var tooltipColorState: TooltipColorState { get set }
  mutating func updateTooltipForMarking()
  func attributedStringNormal(for session: IMKInputControllerProtocol) -> NSAttributedString
  func attributedStringMarking(for session: IMKInputControllerProtocol) -> NSAttributedString
  func attributedStringPlaceholder(for session: IMKInputControllerProtocol) -> NSAttributedString
}
