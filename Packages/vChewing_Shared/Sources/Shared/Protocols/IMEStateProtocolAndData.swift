// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
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

  public var isMarkedLengthValid: Bool { data.isMarkedLengthValid }
  public var displayedText: String { data.displayedText }
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
      cursor: data.cursor,
      highlightAt: nil
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

extension IMEStateData {
  // MARK: Cursor & Marker & Range for UTF8

  public var markedRange: Range<Int> {
    min(cursor, marker) ..< max(cursor, marker)
  }

  // MARK: Cursor & Marker & Range for UTF16 (Read-Only)

  /// IMK 協定的內文組字區的游標長度與游標位置無法正確統計 UTF8 高萬字（比如 emoji）的長度，
  /// 所以在這裡必須做糾偏處理。因為在用 Swift，所以可以用「.utf16」取代「NSString.length()」。
  /// 這樣就可以免除不必要的類型轉換。
  public var u16Cursor: Int {
    let upperBound = max(0, min(cursor, displayedText.count))
    return displayedText.map(\.description)[0 ..< upperBound].joined().utf16.count
  }

  public var u16Marker: Int {
    let upperBound = max(0, min(marker, displayedText.count))
    return displayedText.map(\.description)[0 ..< upperBound].joined().utf16.count
  }

  public var u16MarkedRange: Range<Int> {
    min(u16Cursor, u16Marker) ..< max(u16Cursor, u16Marker)
  }

  public var isMarkedLengthValid: Bool {
    Self.allowedMarkLengthRange.contains(markedRange.count)
  }

  public var userPhraseKVPair: (keyArray: [String], value: String) {
    let key = markedReadings
    let value = displayedText.map(\.description)[markedRange].joined()
    return (key, value)
  }

  public static var allowedMarkLengthRange: ClosedRange<Int> {
    Self.minCandidateLength ... PrefMgr().maxCandidateLength
  }

  public static var minCandidateLength: Int {
    PrefMgr().allowBoostingSingleKanjiAsUserPhrase ? 1 : 2
  }
}
