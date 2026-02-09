// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - CtlCandidateDelegate

public protocol CtlCandidateDelegate: AnyObject {
  func candidateController() -> CtlCandidateProtocol?
  func candidatePairs(conv: Bool) -> [CandidateInState]
  func callError(_: String)
  func getCandidate(at: Int) -> CandidateInState?
  func candidatePairSelectionConfirmed(at index: Int)
  func candidatePairHighlightChanged(at index: Int?)
  func candidatePairContextMenuActionTriggered(
    at index: Int, action: CandidateContextMenuAction
  )
  func candidatePairManipulated(at index: Int, action: CandidateContextMenuAction)
  func candidateToolTip(shortened: Bool) -> String
  func resetCandidateWindowOrigin()
  func checkIsMacroTokenResult(_ index: Int) -> Bool
  @discardableResult
  func reverseLookup(for value: String) -> [String]
  var selectionKeys: String { get }
  var isVerticalTyping: Bool { get }
  var isCandidateState: Bool { get }
  var isVerticalCandidateWindow: Bool { get }
  var localeForFontFallbacks: String { get }
  var isCandidateWindowSingleLine: Bool { get }
  var showCodePointForCurrentCandidate: Bool { get }
  var shouldAutoExpandCandidates: Bool { get }
  var isCandidateContextMenuEnabled: Bool { get }
  var showReverseLookupResult: Bool { get }
  var clientAccentColor: HSBA? { get }
}

// MARK: - CtlCandidateProtocol

public protocol CtlCandidateProtocol: AnyObject {
  var delegate: CtlCandidateDelegate? { get set }
  var highlightedIndex: Int { get set }
  var visible: Bool { get set }
  var currentLayout: UILayoutOrientation { get set }

  func showNextPage() -> Bool
  func showPreviousPage() -> Bool
  func showNextLine() -> Bool
  func showPreviousLine() -> Bool
  func highlightNextCandidate() -> Bool
  func highlightPreviousCandidate() -> Bool
  func candidateIndexAtKeyLabelIndex(_: Int) -> Int?
  func set(
    windowTopLeftPoint: CGPoint,
    bottomOutOfScreenAdjustmentHeight height: Double,
    useGCD: Bool
  )
}

// MARK: - CandidateContextMenuAction

public enum CandidateContextMenuAction {
  case toBoost
  case toNerf
  case toFilter
}
