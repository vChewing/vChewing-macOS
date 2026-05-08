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

  // Factory methods are no longer protocol requirements.
  // They are provided as protocol extension methods so that Darwin-specific
  // implementations (MainAssembly) can override the baseline (Shared) versions
  // without being shadowed by concrete struct implementations.
}

// MARK: - Factory Methods (protocol extension, baseline implementations)

extension IMEStateProtocol {
  public static func ofDeactivated() -> Self { .init(type: .ofDeactivated) }
  public static func ofEmpty() -> Self { .init(type: .ofEmpty) }
  public static func ofAbortion() -> Self { .init(type: .ofAbortion) }

  public static func ofCommitting(textToCommit: String) -> Self {
    var result = Self(type: .ofCommitting)
    result.textToCommit = textToCommit
    return result
  }

  public static func ofAssociates(candidates: [CandidateInState]) -> Self {
    var result = Self(type: .ofAssociates)
    result.candidates = candidates
    return result
  }

  public static func ofInputting(
    displayTextSegments: [String],
    cursor: Int,
    highlightAt highlightAtSegment: Int? = nil
  )
    -> Self {
    var result = Self(.init(), type: .ofInputting)
    result.data.displayTextSegments = displayTextSegments
    result.data.cursor = cursor
    result.data.marker = cursor
    if let seg = highlightAtSegment { result.data.highlightAtSegment = seg }
    return result
  }

  public static func ofMarking(
    displayTextSegments: [String],
    markedReadings: [String],
    cursor: Int,
    marker: Int
  )
    -> Self {
    var result = Self(.init(), type: .ofMarking)
    result.data.displayTextSegments = displayTextSegments
    result.data.cursor = cursor
    result.data.marker = marker
    result.data.markedReadings = markedReadings
    return result
  }

  public static func ofCandidates(
    candidates: [CandidateInState],
    displayTextSegments: [String],
    cursor: Int
  )
    -> Self {
    var result = Self(.init(), type: .ofCandidates)
    result.data.displayTextSegments = displayTextSegments
    result.data.cursor = cursor
    result.data.marker = cursor
    result.data.candidates = candidates
    return result
  }

  public static func ofSymbolTable(node: CandidateNode) -> Self {
    .init(IMEStateData(), type: .ofSymbolTable, node: node)
  }
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
    result.data.rawDisplayTextSegments = data.rawDisplayTextSegments
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
      let newDisplayTextSegments = [node.name]
      // hardenVerticalPunctuationsIfNeeded 已移至 IMEStateParsed4Darwin
      // factory method 的 call site 會在構造 state 之後手動呼叫
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

  // MARK: - Protocol conformance (Shared baseline; Darwin overrides in IMEState.swift)

  /// 預設實作：回傳原始顯示文字。Darwin 端可覆蓋為經 ChineseConverter 轉換後的文字。
  public var displayedTextConverted: String { data.displayedText }

  /// 預設實作：Darwin 端可覆蓋為實際的 LMMgr 查詢結果。
  public var markedTargetIsCurrentlyFiltered: Bool { false }
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

  /// 永遠儲存原始（未經 BPMFVS 投影）的文字資料。
  /// 當為 nil 時，退回至 displayTextSegments（即後者亦為原始資料）。
  public var rawDisplayTextSegments: [String]?

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

  /// 保證回傳未經 BPMFVS 投影的原始文字。
  public var rawDisplayedText: String {
    rawDisplayTextSegments?.joined() ?? displayedText
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
    let value = rawDisplayedText.map(\.description)[markedRange].joined()
    return (key, value)
  }

  public static var allowedMarkLengthRange: ClosedRange<Int> {
    Self.minCandidateLength ... PrefMgr.sharedSansDidSetOps.maxCandidateLength
  }

  public static var minCandidateLength: Int {
    PrefMgr.sharedSansDidSetOps.allowRescoringSingleKanjiCandidates ? 1 : 2
  }
}
