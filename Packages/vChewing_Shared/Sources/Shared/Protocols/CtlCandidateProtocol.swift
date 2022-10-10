// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public protocol CtlCandidateDelegate {
  func candidatePairs(conv: Bool) -> [(String, String)]
  func candidatePairSelected(at index: Int)
  func candidates(_ sender: Any!) -> [Any]!
  var selectionKeys: String { get }
}

public protocol CtlCandidateProtocol {
  var tooltip: String { get set }
  var locale: String { get set }
  var currentLayout: NSUserInterfaceLayoutOrientation { get set }
  var delegate: CtlCandidateDelegate? { get set }
  var selectedCandidateIndex: Int { get set }
  var visible: Bool { get set }
  var windowTopLeftPoint: NSPoint { get set }
  var candidateFont: NSFont { get set }
  var useLangIdentifier: Bool { get set }

  init(_ layout: NSUserInterfaceLayoutOrientation)
  func reloadData()
  func updateDisplay()
  func showNextPage() -> Bool
  func showPreviousPage() -> Bool
  func showNextLine() -> Bool
  func showPreviousLine() -> Bool
  func highlightNextCandidate() -> Bool
  func highlightPreviousCandidate() -> Bool
  func candidateIndexAtKeyLabelIndex(_: Int) -> Int
  func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: Double)
}
