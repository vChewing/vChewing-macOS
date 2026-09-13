// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import OSNeutralAssembly
import Shared
import SwiftExtension

// MARK: - MockClientProxy

/// `SessionClientProxy` 的跨平台替身：用來記錄遞交至客體的文字與標記文字。
///
/// 與 `MockSession` 的 `recentCommissions` 不同，本替身模擬的是「客體實際收到的內容」，
/// 因此可用來斷言 Session 層經過 `commit(text:clearDisplayBeforeCommit:)` 之後的結果。
/// 必須繼承 `NSObject`，因為 `SessionProtocol.performServerActivation()` 的快速路徑
/// 會以 `NSObject` 身分比對 client proxy 的記憶體位址。
final class MockClientProxy: NSObject, SessionClientProxy {
  private(set) var committedText: String = ""
  private(set) var markedTexts: [String] = []
  private(set) var overriddenKeyboardLayouts: [String] = []

  func toString() -> String { committedText }

  func clear() {
    committedText = ""
    markedTexts.removeAll()
    overriddenKeyboardLayouts.removeAll()
  }

  func hasClient() -> Bool { true }

  func clientTextInsertion(with text: String, replacementRange _: NSRange) {
    committedText += text
  }

  func clientMarkedTextSetup(with text: NSAttributedString, selectionRange _: NSRange, replacementRange _: NSRange) {
    markedTexts.append(text.string)
  }

  func clientBundleIdentifier() -> String? {
    "org.atelierInmu.vChewing.OSNeutralAssembly.UnitTests.MockedClient"
  }

  func clientSelectMode(withModeIdentifier _: String) {}

  func clientOverrideKeyboard(withName: String) {
    overriddenKeyboardLayouts.append(withName)
  }

  func clientAttributesForCharacterIndex(
    atU16Pos _: UInt, lineHeightRectangle _: UnsafeMutablePointer<CGRect>
  )
    -> [AnyHashable: Any]? { nil }

  func clientLineHeightRect(forU16CursorPos _: UInt) -> CGRect { .zeroValue }
}

// MARK: - MockSessionUI

/// `SessionUIProtocol` 的跨平台替身：所有面板皆可依測試需要指派。
final class MockSessionUI: SessionUIProtocol {
  var currentSessionID: UUID = .init()
  var shiftKeyUpChecker: (any ShiftKeyUpCheckerProtocol)?
  var capsLockHitChecker: (any HitCheckerProtocol)?
  var capsLockToggler: (any CapsLockTogglerProtocol)?
  var pcb: (any PCBProtocol)?
  var tooltipUI: (any TooltipUIProtocol)?
  var statusUI: (any TooltipUIProtocol)?
  var candidateUI: (any CtlCandidateProtocol)?
}

// MARK: - MockTooltipUI

/// `TooltipUIProtocol` 替身：記錄顯示內容、次數與座標。
final class MockTooltipUI: TooltipUIProtocol {
  var shownTooltip: String?
  var shownDuration: Double?
  var shownPoint: CGPoint?
  var showCount = 0
  var hideCount = 0
  var syncCount = 0
  var lastLocale: String?
  var isShown = false

  func sync(accent _: HSBA?, locale: String) {
    syncCount += 1
    lastLocale = locale
  }

  func show(
    tooltip: String,
    at point: CGPoint,
    bottomOutOfScreenAdjustmentHeight _: Double,
    direction _: UILayoutOrientation,
    duration: Double
  ) {
    shownTooltip = tooltip
    shownDuration = duration
    shownPoint = point
    showCount += 1
    isShown = true
  }

  func hide() {
    hideCount += 1
    isShown = false
  }

  func setColor(state _: TooltipColorState) {}
}

// MARK: - MockPCB

/// `PCBProtocol` 替身：可控顯示狀態與視窗 frame。
final class MockPCB: PCBProtocol {
  var isTypingDirectionVertical: Bool = false
  var isShown = false
  var frame: CGRect?
  var showCount = 0
  var hideCount = 0

  func show(state _: some IMEStateProtocol, at _: CGPoint) {
    showCount += 1
    isShown = true
  }

  func hide() {
    hideCount += 1
    isShown = false
  }

  func sync(accent _: HSBA?, locale _: String) {}
}

// MARK: - MockCapsLockToggler

/// `CapsLockTogglerProtocol` 替身。
final class MockCapsLockToggler: CapsLockTogglerProtocol {
  // MARK: Lifecycle

  init(isOn: Bool) {
    self.isOn = isOn
  }

  // MARK: Internal

  var isOn: Bool
}

// MARK: - MockNavigableCandidateController

/// `CtlCandidateProtocol` 替身：與 `MockCandidateController` 不同的是，
/// 本替身會實際移動高亮與翻頁／翻列，並在變動時通知 delegate，
/// 以便測試選字窗導航對組字區預覽的影響。
final class MockNavigableCandidateController: CtlCandidateProtocol {
  // MARK: Lifecycle

  init(visible: Bool = true, candidateCount: Int = 0) {
    self.visible = visible
    self.candidateCount = candidateCount
  }

  // MARK: Internal

  weak var delegate: (any CtlCandidateDelegate)?
  var visible: Bool
  var expanded: Bool = false
  var currentLayout: UILayoutOrientation = .horizontal

  /// 目前候選清單的項目總數；由測試在開啟選字窗前指定，供翻頁／翻列邊界判定使用。
  var candidateCount: Int = 0
  /// 每頁容納的候選數。
  var capacityPerPage: Int = 9
  /// 每列容納的候選數。
  var capacityPerLine: Int = 9

  private(set) var pageIndex: Int = 0
  private(set) var lineIndex: Int = 0
  private(set) var showNextPageCount: Int = 0
  private(set) var showPreviousPageCount: Int = 0
  private(set) var showNextLineCount: Int = 0
  private(set) var showPreviousLineCount: Int = 0

  var highlightedIndex: Int = 0 {
    didSet {
      guard highlightedIndex != oldValue else { return }
      delegate?.candidatePairHighlightChanged(at: highlightedIndex)
    }
  }

  func showNextPage() -> Bool {
    showNextPageCount += 1
    let lastPage = max(0, (candidateCount - 1) / max(1, capacityPerPage))
    guard pageIndex < lastPage else { return false }
    pageIndex += 1
    highlightedIndex = min(pageIndex * capacityPerPage, max(0, candidateCount - 1))
    return true
  }

  func showPreviousPage() -> Bool {
    showPreviousPageCount += 1
    guard pageIndex > 0 else { return false }
    pageIndex -= 1
    highlightedIndex = min(pageIndex * capacityPerPage, max(0, candidateCount - 1))
    return true
  }

  func showNextLine() -> Bool {
    showNextLineCount += 1
    let next = highlightedIndex + max(1, capacityPerLine)
    guard next < candidateCount else { return false }
    lineIndex += 1
    highlightedIndex = next
    return true
  }

  func showPreviousLine() -> Bool {
    showPreviousLineCount += 1
    let previous = highlightedIndex - max(1, capacityPerLine)
    guard previous >= 0 else { return false }
    lineIndex = max(0, lineIndex - 1)
    highlightedIndex = previous
    return true
  }

  func highlightNextCandidate() -> Bool {
    let next = highlightedIndex + 1
    guard next < candidateCount else { return false }
    pageIndex = next / max(1, capacityPerPage)
    highlightedIndex = next
    return true
  }

  func highlightPreviousCandidate() -> Bool {
    let previous = highlightedIndex - 1
    guard previous >= 0 else { return false }
    pageIndex = previous / max(1, capacityPerPage)
    highlightedIndex = previous
    return true
  }

  func candidateIndexAtKeyLabelIndex(_ index: Int) -> Int? { index }

  func set(
    windowTopLeftPoint _: CGPoint,
    bottomOutOfScreenAdjustmentHeight _: Double,
    useGCD _: Bool,
    animated _: Bool
  ) {}
}
