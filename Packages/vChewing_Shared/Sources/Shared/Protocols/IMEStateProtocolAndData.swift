// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - IMEStateProtocol

public typealias CandidateInState = (keyArray: [String], value: String)

// MARK: - IMEStateProtocol

// 所有 IMEState 均遵守該協定：
public protocol IMEStateProtocol {
  init(_ data: IMEStateData, type: StateType)
  init(_ data: IMEStateData, type: StateType, node: CandidateNode)
  var type: StateType { get }
  var data: IMEStateData { get set }
  var displayedTextConverted: String { get }
  var markedTargetIsCurrentlyFiltered: Bool { get }
  var node: CandidateNode { get set }

  static func ofDeactivated() -> Self
  static func ofEmpty() -> Self
  static func ofAbortion() -> Self
  static func ofCommitting(textToCommit: String) -> Self
  static func ofAssociates(candidates: [CandidateInState]) -> Self
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
    candidates: [CandidateInState],
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

  public var candidates: [CandidateInState] {
    get { data.candidates }
    set { data.candidates = newValue }
  }

  public var currentCandidate: CandidateInState? {
    data.currentCandidate
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

  public var highlightedCandidateIndex: Int? {
    get { data.highlightedCandidateIndex }
    set { data.highlightedCandidateIndex = newValue }
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
  public var candidates = [CandidateInState]()
  public var textToCommit: String = ""

  public var tooltip: String = ""
  public var tooltipDuration: Double = 1.0
  public var tooltipBackupForInputting: String = ""
  public var tooltipColorState: TooltipColorState = .normal

  public var highlightedCandidateIndex: Int? {
    didSet {
      guard let newValue = highlightedCandidateIndex else { return }
      // SymbolTable 的 members 會自動給 candidates 鏡照一份內容。
      if candidates.isEmpty || !candidates.indices.contains(newValue) {
        highlightedCandidateIndex = nil
      }
    }
  }

  public var currentCandidate: CandidateInState? {
    guard let idxCandidate = highlightedCandidateIndex else { return nil }
    guard !candidates.isEmpty else { return nil }
    guard candidates.indices.contains(idxCandidate) else { return nil }
    return candidates[idxCandidate]
  }

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

  public var userPhraseKVPair: CandidateInState {
    let key = markedReadings
    let value = displayedText.map(\.description)[markedRange].joined()
    return (key, value)
  }

  public static var allowedMarkLengthRange: ClosedRange<Int> {
    Self.minCandidateLength ... PrefMgr.sharedSansDidSetOps.maxCandidateLength
  }

  public static var minCandidateLength: Int {
    PrefMgr.sharedSansDidSetOps.allowRescoringSingleKanjiCandidates ? 1 : 2
  }
}

// MARK: - AttributedString 樣式組裝 API

extension IMEStateData {
  /// IMKInputController 的 `mark(forStyle:)` 只可能會標出這些值。
  /// 該值乃使用 hopper disassembler 分析 IMK 而得出。
  public enum AttrStrULStyle: Int {
    case none = 0
    /// #1, kTSMHiliteConvertedText & kTSMHiliteSelectedRawText
    case single = 1
    /// #2, kTSMHiliteSelectedConvertedText
    case thick = 2
    /// #3, 尚未被 TSM 使用。或可用給 kTSMHiliteSelectedRawText 與 1 區分。
    case double = 3

    // MARK: Public

    public typealias StyledPair = (string: String, style: Self)

    public static func pack(_ pairs: [StyledPair]) -> NSAttributedString {
      let result = NSMutableAttributedString(string: "")
      var clauseSegment = 0
      for (string, style) in pairs {
        guard !string.isEmpty else { continue }
        result.append(style.getMarkedAttrStr(string, clauseSegment: clauseSegment))
        clauseSegment += 1
      }
      return result
    }

    public func getDict(clauseSegment: Int? = nil) -> [NSAttributedString.Key: Any] {
      var result: [NSAttributedString.Key: Any] = [Self.keyName4UL: rawValue]
      result[Self.keyName4CS] = clauseSegment
      return result
    }

    public func getMarkedAttrStr(_ rawStr: String, clauseSegment: Int? = nil) -> NSAttributedString {
      let result = NSMutableAttributedString(string: rawStr)
      let rangeNow = NSRange(location: 0, length: rawStr.utf16.count)
      result.setAttributes(getDict(clauseSegment: clauseSegment), range: rangeNow)
      return result
    }

    // MARK: Private

    private static let keyName4UL = NSAttributedString.Key(
      rawValue: "NSUnderline"
    )

    private static let keyName4CS = NSAttributedString.Key(
      rawValue: "NSMarkedClauseSegment"
    )
  }

  public func getAttributedStringPlaceholder(_ char: Unicode.Scalar = " ") -> NSAttributedString {
    AttrStrULStyle.single.getMarkedAttrStr(
      char.description,
      clauseSegment: 0
    )
  }

  /// - Remark: Converter 為 nil 時不做追加漢字轉換。
  public func getAttributedStringNormal(
    _ converter: ((String) -> String)?
  )
    -> NSAttributedString {
    AttrStrULStyle.pack(
      displayTextSegments.map {
        (converter?($0) ?? $0, .single)
      }
    )
  }

  /// - Remark: Converter 為 nil 時不做追加漢字轉換。
  public func getAttributedStringMarking(
    _ converter: ((String) -> String)?
  )
    -> NSAttributedString {
    let converted = (converter?(displayedText) ?? displayedText).map(\.description)
    let range2 = markedRange
    let range1 = 0 ..< markedRange.lowerBound
    let range3 = markedRange.upperBound ..< converted.count
    let pairs: [AttrStrULStyle.StyledPair] = [
      (converted[range1].joined(), .single),
      (converted[range2].joined(), .thick),
      (converted[range3].joined(), .single),
    ]
    return AttrStrULStyle.pack(pairs)
  }
}
