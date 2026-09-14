// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Homa
import LexiconAssembly
@testable import LibVanguard
import Shared
import SwiftExtension
import Tekkon
import Testing

// MARK: - MockInputHandler

/// 專門用於單元測試的模擬 InputHandler 類型。
public final class MockInputHandler: @MainActor InputHandlerProtocol {
  // MARK: Lifecycle

  public init(
    lx: LXAssembly.LXFacade,
    pref: PrefMgrProtocol,
    errorCallback: ((_ message: String) -> ())? = nil,
    filterabilityChecker: ((_ state: IMEStateData) -> Bool)? = nil,
    notificationCallback: ((_ message: String) -> ())? = nil,
    pomSaveCallback: (() -> ())? = nil
  ) {
    self.prefs = pref
    self.currentLM = lx
    self.pomSaveCallback = pomSaveCallback
    self.errorCallback = errorCallback
    self.notificationCallback = notificationCallback
    self.filterabilityChecker = filterabilityChecker
    self.assembler = Assembler(
      gramQuerier: { _ in [] }
    )
    assembler.maxSegLength = prefs.maxCandidateLength
    assembler.gramQuerier = { [weak self] keyArray in
      guard let self else { return [] }
      return self.currentLM.lxQuerier.grams(for: keyArray)
    }
    ensureKeyboardParser()
  }

  // MARK: Public

  // typealias State removed (inherited from InputHandlerProtocol: State = IMEState)
  public typealias Session = MockSession

  public static var keySeparator: String { Assembler.theSeparator }

  public weak var session: Session?
  public var prefs: PrefMgrProtocol
  public var errorCallback: ((String) -> ())?
  public var notificationCallback: ((String) -> ())?
  public var pomSaveCallback: (() -> ())?
  public var filterabilityChecker: ((_ state: IMEStateData) -> Bool)?
  public var markingTooltipGenerator: ((_ state: State) -> (tooltip: String, colorState: TooltipColorState))?

  public var backupCursor: Int?
  public var currentTypingMethod: TypingMethod = .vChewingFactory

  public var strCodePointBuffer = ""
  public var calligrapher = ""
  public var mixedAlphanumericalBuffer = ""
  public var furiousTrail = [String]() // 狂拼模式：自動 chop 提交鍵對應的拼音字母 blob trail
  public var furiousHighlightOverride: CandidateInState? // 狂拼 copilot 窗高亮候選（當拍消費）
  public var furiousCoSegmentedOffers = [FuriousCoSegmentedOffer]() // 狂拼 copilot 窗聯合重切（P164）的替代切分 offers
  public var composer: Tekkon.Composer = .init()
  public var assembler: Homa.Assembler
  public var isJISKeyboard: (() -> Bool)? = { false }
  public var narrator: (any SpeechNarratorProtocol)?

  public var currentLM: LXAssembly.LXFacade {
    didSet {
      clear()
    }
  }
}

// MARK: - MockSession

/// 專門用於單元測試的模擬會話類型。
public final class MockSession: @MainActor SessionCoreProtocol {
  // MARK: Lifecycle

  public init() {
    self.state = IMEState()
  }

  // MARK: Public

  // typealias State removed (inherited from SessionCoreProtocol: State = IMEState)
  public typealias Handler = MockInputHandler

  public let id: UUID = .init()
  public var inputHandler: MockInputHandler?
  public var isASCIIMode: Bool = false
  public var clientMitigationLevel: Int = 0
  /// 預設為 nil（候選窗不存在）；測試需要模擬候選窗已顯示時才指派。
  public var mockCandidateController: MockCandidateController?
  public var isVerticalTyping: Bool = false
  public var showCodePointForCurrentCandidate: Bool = false
  public var shouldAutoExpandCandidates: Bool = false
  public var isCandidateContextMenuEnabled: Bool = false
  public var showReverseLookupResult: Bool = false
  public var ui: SessionUIProtocol?
  public var selectionKeys: String = "123456789"
  public var recentCommissions = [String]()
  public var clientAccentColor: HSBA?
  public var trieCacheFlushHandler: (() -> ())?

  public var state: IMEState = .init() {
    didSet {
      // 令「跟隨 Session 候選清單」的模擬選字窗即時同步：候選內容變更時把高亮重設回首項，
      // 與生產端選字窗於資料重載時的行為一致。未安裝控制器、或控制器未跟隨時為空操作。
      mockCandidateController?.syncCandidateList(state.candidates)
    }
  }

  public var isCandidateState: Bool { state.type == .ofCandidates }

  public var isCandidateWindowSingleLine: Bool { true }

  public var isVerticalCandidateWindow: Bool { false }

  public var localeForFontFallbacks: String { "zh-Hant" }

  public var unfinishedReading: String? {
    // 與生產端 InputSession_Delegates 對應：狂拼 copilot 窗的未完成讀音（頂部 pane 資料源）。
    guard let inputHandler = inputHandler else { return nil }
    guard isFuriousCopilotCandidateWindowVisible, inputHandler.hasFuriousFrontPending else {
      return nil
    }
    let romaji = inputHandler.composer.romajiBuffer
    return romaji.isEmpty ? nil : romaji
  }

  public func callError(_ logMessage: String) {
    vCLog(logMessage)
  }

  public func getCandidate(at index: Int) -> CandidateInState? {
    guard state.candidates.indices.contains(index) else { return nil }
    return state.candidates[index]
  }

  public func updateCompositionBufferDisplay() {}

  public func performUserPhraseOperation(addToFilter: Bool) -> Bool {
    guard let inputHandler = inputHandler, state.type == .ofMarking else { return false }
    let kvPair = state.data.userPhraseKVPair
    let userPhrase = UserPhraseInsertable(
      keyArray: kvPair.keyArray,
      value: kvPair.value,
      inputMode: IMEApp.currentInputMode
    )
    inputHandler.currentLM.insertTemporaryData(
      unigram: .init(
        keyArray: userPhrase.keyArray,
        value: userPhrase.value,
        score: userPhrase.weight ?? 0
      ),
      isFiltering: addToFilter
    )
    // 該單元測試僅測試當前函式是否有清除 POM 內部的相關資料。
    // 不然的話，該函式的目的與結果可能會被 POM 既有資料所干涉。
    var pomTargets = inputHandler.activePOMCandidateValues()
    pomTargets.append(userPhrase.value)
    let uniqueTargets = Array(Set(pomTargets.filter { !$0.isEmpty }))
    if !uniqueTargets.isEmpty {
      inputHandler.currentLM.bleachSpecifiedPOMSuggestions(targets: uniqueTargets)
    }
    let separator = inputHandler.keySeparator.isEmpty ? Homa.Assembler.theSeparator : inputHandler.keySeparator
    let headReading = userPhrase.keyArray.joined(separator: separator)
    if !headReading.isEmpty {
      inputHandler.currentLM.bleachSpecifiedPOMSuggestions(headReadings: [headReading])
    }
    // 清詞完畢
    return true
  }

  @discardableResult
  public func updateVerticalTypingStatus() -> CGRect {
    // `textFrame` 的尺寸不能是 0，否則 `attributes()` 在某些客體上的不良實作可能會炸掉客體。
    // 所以需要使用 `CGRect.seniorTheBeast` 作為基底資料值。
    .seniorTheBeast
  }

  // MARK: - CtlCandidateDelegate conformance

  public func candidateController() -> CtlCandidateProtocol? { mockCandidateController }

  /// 安裝一個可見、且會跟隨當前 Session 候選清單的模擬選字窗控制器。
  /// 控制器的 `candidateCount` 會隨 `state.candidates` 即時更新，故可以真實進行候選導航
  /// （方向鍵、選字鍵、翻頁），用於測試「必須經由選字窗完成」的流程。
  /// - Parameters:
  ///   - visible: 是否讓控制器處於可見狀態（`handleCandidate` 需要）。
  ///   - capacityPerPage: 每頁可容納的候選數量；在生產端選字窗即每行容量，對應
  ///     `selectionKeys` 的字元數（預設值為 `prefs.candidateKeys`，即 "123456"）。
  /// - Returns: 安裝完成的控制器，供測試斷言導航結果。
  @discardableResult
  public func installMockCandidateController(
    visible: Bool = true,
    capacityPerPage: Int = 9
  )
    -> MockCandidateController {
    let controller = MockCandidateController(
      visible: visible, capacityPerPage: capacityPerPage
    )
    controller.delegate = self
    controller.tracksSessionCandidateList = true
    controller.syncCandidateList(state.candidates)
    mockCandidateController = controller
    return controller
  }

  public func candidatePairs(conv _: Bool) -> [CandidateInState] {
    if !state.isCandidateContainer || state.candidates.isEmpty { return [] }
    return state.candidates
  }

  public func candidatePairSelectionConfirmed(at index: Int) {
    guard let inputHandler = inputHandler else { return }
    guard state.isCandidateContainer else { return }
    switch state.type {
    case .ofSymbolTable where (0 ..< state.node.members.count).contains(index):
      let node = state.node.members[index]
      if !node.members.isEmpty {
        switchState(.ofSymbolTable(node: node))
      } else if let serviceNode = node.asServiceMenuNode {
        let rawValue = serviceNode.service.rawValue
        print("Service Node is not available for Mocked Sessions. raw: \(rawValue)")
        switchState(.ofAbortion())
      } else {
        switchState(.ofCommitting(textToCommit: node.name))
      }
    case .ofCandidates where (0 ..< state.candidates.count).contains(index):
      let selectedValue = state.candidates[index]
      inputHandler.consolidateNode(
        candidate: selectedValue,
        respectCursorPushing: true,
        preConsolidate: inputHandler.prefs.consolidateContextOnCandidateSelection,
        skipObservation: !inputHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel,
        explicitlyChosen: true
      )
      var result: State = inputHandler.generateStateOfInputting()
      defer { switchState(result) } // 這是最終輸出結果。
      if inputHandler.prefs.useSCPCTypingMode {
        switchState(.ofCommitting(textToCommit: inputHandler.committableDisplayText(sansReading: true)))
        // 此時是逐字選字模式，所以「selectedValue.value」是單個字、不用追加處理。
        if inputHandler.prefs.associatedPhrasesEnabled {
          let associates = inputHandler.generateStateOfAssociates(
            withPair: .init(keyArray: selectedValue.keyArray, value: selectedValue.value)
          )
          result = associates.candidates.isEmpty ? .ofEmpty() : associates
        } else {
          result = .ofEmpty()
        }
      }
    case .ofAssociates where (0 ..< state.candidates.count).contains(index):
      let selectedValue = state.candidates[index]
      var result: State = .ofEmpty()
      defer { switchState(result) } // 這是最終輸出結果。
      switchState(.ofCommitting(textToCommit: selectedValue.value))
      guard inputHandler.prefs.associatedPhrasesEnabled else { return }
      // 此時是關聯詞語選字模式，所以「selectedValue.value」必須只保留最後一個字。
      // 不然的話，一旦你選中了由多個字組成的聯想候選詞，則連續聯想會被打斷。
      guard let valueKept = selectedValue.value.last?.description else { return }
      let associates = inputHandler.generateStateOfAssociates(
        withPair: .init(keyArray: selectedValue.keyArray, value: valueKept)
      )
      if !associates.candidates.isEmpty { result = associates }
    case .ofInputting where (0 ..< state.candidates.count).contains(index):
      // 狂拼模式：前方候選就地選字（與生產端 InputSession_Delegates 對應）。
      // 使用者顯式選字＝符合 POM 記憶的明確意志，故傳入 memorizePOM: true。
      if inputHandler.isFuriousTypingModeEffective {
        let selectedValue = state.candidates[index]
        inputHandler.confirmFuriousFrontCandidate(selectedValue, memorizePOM: true)
        switchState(inputHandler.generateStateOfInputting())
        return
      }
      let chosenStr = state.candidates[index].value
      guard !chosenStr.isEmpty, chosenStr != inputHandler.currentLM.nullCandidateInCassette else {
        vCTestLog("TEST SESSION ERROR: 907F9F64")
        return
      }
      let strToCommitFirst = inputHandler.committableDisplayText(sansReading: true)
      switchState(.ofCommitting(textToCommit: strToCommitFirst + chosenStr))
    default: return
    }
  }

  public func candidatePairHighlightChanged(at theIndex: Int?) {
    guard let inputHandler = inputHandler else { return }
    guard state.highlightedCandidateIndex != theIndex else { return }
    state.highlightedCandidateIndex = theIndex
    guard state.isCandidateContainer, let theIndex else { return }
    // 狂拼 copilot 窗：高亮即時反映到組字區（與生產端 InputSession_Delegates 對應）。
    if isFuriousCopilotCandidateWindowVisible,
       (0 ..< state.candidates.count).contains(theIndex) {
      let candidate = state.candidates[theIndex]
      inputHandler.furiousHighlightOverride = candidate
      inputHandler.previewFuriousHighlightedCandidate(candidate)
      return
    }
    switch state.type {
    case .ofCandidates where (0 ..< state.candidates.count).contains(theIndex):
      inputHandler.previewCurrentCandidateAtCompositionBuffer()
    case .ofSymbolTable where (0 ..< state.node.members.count).contains(theIndex):
      let node = state.node.members[theIndex]
      if node.members.isEmpty {
        // 與生產端 InputSession_Delegates 對應：葉節點以「顯示區段」承載預覽文字。
        state.data.displayTextSegments = [node.name]
        state.data.cursor = node.name.count
        state.data.marker = state.data.cursor
      } else {
        state.data.displayTextSegments.removeAll()
        state.data.cursor = 0
        state.data.marker = 0
      }
      updateCompositionBufferDisplay()
    default: break
    }
  }

  public func candidatePairContextMenuActionTriggered(
    at index: Int, action: CandidateContextMenuAction
  ) {}

  public func candidatePairManipulated(
    at index: Int,
    action: CandidateContextMenuAction
  ) {}

  public func candidateToolTip(shortened: Bool) -> String { "" }

  public func resetCandidateWindowOrigin() {}

  public func candidateWindowOriginInfo() -> (topLeft: CGPoint, heightDelta: Double) {
    (topLeft: CGPoint(x: 0, y: 0), heightDelta: 0)
  }

  public func checkIsMacroTokenResult(_ index: Int) -> Bool { false }

  @discardableResult
  public func reverseLookup(for value: String) -> [String] {
    // 與生產端 InputSession_Delegates 對應：狂拼讀音回顯已移交 unfinishedReading
    // 專用資料源，反查欄位自此只走一般守衛路徑。
    guard let inputHandler = inputHandler else { return [] }
    if !inputHandler.prefs.showReverseLookupInCandidateUI { return [] }
    if isVerticalTyping { return [] }
    return []
  }

  public func toggleCandidateUIVisibility(_: Bool, refresh _: Bool) {}
  public func commit(text: String, clearDisplayBeforeCommit _: Bool) {
    guard !text.isEmpty else { return }
    recentCommissions.append(text)
  }

  public func getMitigatedState(_ givenState: State) -> State { givenState }
  public func showTooltip(_: String?, colorState _: TooltipColorState, duration _: Double) {}

  // MARK: Internal

  /// 覆寫 SessionCoreProtocol 的 debugLogCondition，
  /// 維持單元測試既有的 log 輸出行為。
  var debugLogCondition: Bool {
    PrefMgr.sharedSansDidSetOps.isDebugModeEnabled
  }
}

// MARK: - MockCandidateController

/// 專門用於單元測試的模擬候選窗控制器。
///
/// 預設（未設定候選數量時）僅用來讓 `handleCandidate` 認定候選窗處於可見狀態，
/// 所有導航操作一律回傳 `false`、亦不移動高亮，與既有測試行為一致。
/// 一旦候選數量已知（`candidateCount > 0`，或由 `MockSession` 安裝後持續跟隨候選清單），
/// 導航操作便會實際移動 `highlightedIndex`，用於測試必須經由選字窗完成的流程。
public final class MockCandidateController: CtlCandidateProtocol {
  // MARK: Lifecycle

  public init(
    visible: Bool = true,
    candidateCount: Int = 0,
    capacityPerPage: Int = 9
  ) {
    self.visible = visible
    self.candidateCount = candidateCount
    self.capacityPerPage = capacityPerPage
  }

  // MARK: Public

  public weak var delegate: (any CtlCandidateDelegate)?
  public var visible: Bool
  public var expanded: Bool = false
  public var currentLayout: UILayoutOrientation = .horizontal
  /// 記錄高亮導航（highlightNext/Previous）被呼叫的次數，供測試斷言導航事件。
  public private(set) var highlightNavigationCount = 0
  /// 候選總數。為 0 時視為「未知」，所有導航操作一律回傳 `false`（與既有行為一致）。
  public var candidateCount: Int = 0
  /// 每頁可容納的候選數量；在生產端選字窗即「每行候選容量」（`selectionKeys` 的字元數），
  /// 故亦決定「翻一行」的位移量，以及選字鍵索引到候選總索引的換算。
  public var capacityPerPage: Int = 9
  /// 當前頁索引，於導航時隨高亮位置推算。
  public var pageIndex: Int = 0
  /// 是否跟隨 `MockSession.state.candidates`。由 `installMockCandidateController` 開啟。
  public var tracksSessionCandidateList: Bool = false

  /// 當前高亮候選索引。變更時同步通知 `delegate`。
  public var highlightedIndex: Int = 0 {
    didSet {
      guard highlightedIndex != oldValue else { return }
      delegate?.candidatePairHighlightChanged(at: highlightedIndex)
    }
  }

  /// 依當前候選清單同步內部狀態。
  /// 僅在 `tracksSessionCandidateList` 為真時生效；候選內容有變化時，
  /// 會把高亮與頁索引重設回首項（對應生產端選字窗 `reloadData` 的行為）。
  public func syncCandidateList(_ candidates: [CandidateInState]) {
    guard tracksSessionCandidateList else { return }
    candidateCount = candidates.count
    let newValues = candidates.map(\.value)
    guard newValues != lastSyncedCandidateValues else { return }
    lastSyncedCandidateValues = newValues
    pageIndex = 0
    highlightedIndex = 0
  }

  public func showNextPage() -> Bool { moveHighlight(by: max(capacityPerPage, 1)) }
  public func showPreviousPage() -> Bool { moveHighlight(by: -max(capacityPerPage, 1)) }
  public func showNextLine() -> Bool { moveToNeighborLine(isBackward: false) }
  public func showPreviousLine() -> Bool { moveToNeighborLine(isBackward: true) }
  public func highlightNextCandidate() -> Bool {
    highlightNavigationCount += 1
    return moveHighlight(by: 1)
  }

  public func highlightPreviousCandidate() -> Bool {
    highlightNavigationCount += 1
    return moveHighlight(by: -1)
  }

  /// 依當前高亮所在的行，將選字鍵的行內索引換算為候選總索引。
  /// 候選數量未知（= 0）時，維持既有行為直接回傳 `index`。
  public func candidateIndexAtKeyLabelIndex(_ index: Int) -> Int? {
    guard candidateCount > 0 else { return index }
    let candidate = currentLine * max(capacityPerPage, 1) + index
    guard (0 ..< candidateCount).contains(candidate) else { return nil }
    return candidate
  }

  public func set(
    windowTopLeftPoint _: CGPoint,
    bottomOutOfScreenAdjustmentHeight _: Double,
    useGCD _: Bool,
    animated _: Bool
  ) {}

  // MARK: Private

  /// 已同步過的候選值清單（用於偵測選字窗資料是否真的換了一批內容）。
  private var lastSyncedCandidateValues: [String]?

  /// 當前高亮所在的「行」（行內容量為 `capacityPerPage`）。
  private var currentLine: Int { highlightedIndex / max(capacityPerPage, 1) }

  /// 依位移量移動高亮；超出範圍時不移動並回傳 `false`。
  private func moveHighlight(by offset: Int) -> Bool {
    guard candidateCount > 0 else { return false }
    let target = highlightedIndex + offset
    guard (0 ..< candidateCount).contains(target) else { return false }
    highlightedIndex = target
    pageIndex = currentLine
    return true
  }

  /// 翻到相鄰的行（保留行內位置）；已在首/末行時不移動並回傳 `false`。
  private func moveToNeighborLine(isBackward: Bool) -> Bool {
    guard candidateCount > 0 else { return false }
    let step = max(capacityPerPage, 1)
    let subIndex = highlightedIndex % step
    let targetLine = currentLine + (isBackward ? -1 : 1)
    let target = targetLine * step + subIndex
    guard targetLine >= 0, (0 ..< candidateCount).contains(target) else { return false }
    highlightedIndex = target
    pageIndex = currentLine
    return true
  }
}

// MARK: - MockSpeechNarrator

/// 專門用於單元測試的模擬語音朗讀器，可記錄最後一次朗讀的文本。
public final class MockSpeechNarrator: SpeechNarratorProtocol {
  public static var shared: MockSpeechNarrator = .init()

  public private(set) var lastNarratedText: String?
  public private(set) var narrateCallCount: Int = 0

  public func refreshStatus() {}

  public func narrate(_ text: String, allowDuplicates: Bool = true) {
    narrateCallCount += 1
    lastNarratedText = text
  }

  public func reset() {
    lastNarratedText = nil
    narrateCallCount = 0
  }
}
