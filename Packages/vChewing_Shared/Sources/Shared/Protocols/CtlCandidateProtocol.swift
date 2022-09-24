// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa

public protocol CtlCandidateDelegate: AnyObject {
  func candidatePairs() -> [(String, String)]
  func candidatePairAt(_ index: Int) -> (String, String)
  func candidatePairSelected(at index: Int)
  func buzz()
  func kanjiConversionIfRequired(_ target: String) -> String
}

public protocol CtlCandidateProtocol {
  var locale: String { get set }
  var currentLayout: CandidateLayout { get set }
  var delegate: CtlCandidateDelegate? { get set }
  var selectedCandidateIndex: Int { get set }
  var visible: Bool { get set }
  var windowTopLeftPoint: NSPoint { get set }
  var keyLabels: [CandidateKeyLabel] { get set }
  var keyLabelFont: NSFont { get set }
  var candidateFont: NSFont { get set }
  var tooltip: String { get set }
  var useLangIdentifier: Bool { get set }
  var showPageButtons: Bool { get set }

  init(_ layout: CandidateLayout)
  func reloadData()
  func showNextPage() -> Bool
  func showPreviousPage() -> Bool
  func highlightNextCandidate() -> Bool
  func highlightPreviousCandidate() -> Bool
  func candidateIndexAtKeyLabelIndex(_: Int) -> Int
  func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: Double)
}
