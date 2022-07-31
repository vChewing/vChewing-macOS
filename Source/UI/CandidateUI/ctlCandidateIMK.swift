// Copyright (c) 2021 and onwards The vChewing Project (MIT-NTL License).
/*
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

1. The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

2. No trademark license is granted to use the trade names, trademarks, service
marks, or product names of Contributor, except as required to fulfill notice
requirements above.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/

import Foundation
import InputMethodKit

public class ctlCandidateIMK: IMKCandidates, ctlCandidateProtocol {
  public var currentLayout: CandidateLayout = .horizontal

  public weak var delegate: ctlCandidateDelegate? {
    didSet {
      reloadData()
    }
  }

  public var selectedCandidateIndex: Int = .max

  public var visible: Bool = false {
    didSet {
      if visible {
        show()
      } else {
        hide()
      }
    }
  }

  public var windowTopLeftPoint: NSPoint = .init(x: 0, y: 0) {
    didSet {
      DispatchQueue.main.asyncAfter(deadline: DispatchTime.now()) {
        self.set(windowTopLeftPoint: self.windowTopLeftPoint, bottomOutOfScreenAdjustmentHeight: 0)
      }
    }
  }

  public var keyLabels: [CandidateKeyLabel] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    .map {
      CandidateKeyLabel(key: $0, displayedText: $0)
    }

  public var keyLabelFont: NSFont = NSFont.monospacedDigitSystemFont(
    ofSize: 14, weight: .medium
  )
  public var candidateFont: NSFont = NSFont.systemFont(ofSize: 18)
  public var tooltip: String = ""

  var keyCount = 0
  var displayedCandidates = [String]()

  public func specifyLayout(_ layout: CandidateLayout = .horizontal) {
    currentLayout = layout
    switch currentLayout {
      case .horizontal:
        setPanelType(kIMKScrollingGridCandidatePanel)
      case .vertical:
        setPanelType(kIMKSingleColumnScrollingCandidatePanel)
    }
    setAttributes([IMKCandidatesSendServerKeyEventFirst: false])
  }

  public required init(_ layout: CandidateLayout = .horizontal) {
    super.init(server: theServer, panelType: kIMKScrollingGridCandidatePanel)
    specifyLayout(layout)
    visible = false
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public func reloadData() {
    guard let delegate = delegate else { return }
    let candidates = delegate.candidatesForController(self).map { theCandidate -> String in
      let theConverted = IME.kanjiConversionIfRequired(theCandidate.1)
      return (theCandidate.1 == theConverted) ? theCandidate.1 : "\(theConverted)(\(theCandidate.1))"
    }
    setCandidateData(candidates)
    keyCount = selectionKeys().count
    selectedCandidateIndex = 0
    update()
  }

  public func showNextPage() -> Bool {
    if selectedCandidateIndex == candidates(self).count - 1 { return false }
    selectedCandidateIndex = min(selectedCandidateIndex + keyCount, candidates(self).count - 1)
    return selectCandidate(withIdentifier: selectedCandidateIndex)
  }

  public func showPreviousPage() -> Bool {
    if selectedCandidateIndex == 0 { return true }
    selectedCandidateIndex = max(selectedCandidateIndex - keyCount, 0)
    return selectCandidate(withIdentifier: selectedCandidateIndex)
  }

  public func highlightNextCandidate() -> Bool {
    if selectedCandidateIndex == candidates(self).count - 1 { return false }
    selectedCandidateIndex = min(selectedCandidateIndex + 1, candidates(self).count - 1)
    return selectCandidate(withIdentifier: selectedCandidateIndex)
  }

  public func highlightPreviousCandidate() -> Bool {
    if selectedCandidateIndex == 0 { return true }
    selectedCandidateIndex = max(selectedCandidateIndex - 1, 0)
    return selectCandidate(withIdentifier: selectedCandidateIndex)
  }

  public func candidateIndexAtKeyLabelIndex(_: Int) -> Int {
    selectedCandidateIndex
  }

  public func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight _: CGFloat = 0) {
    setCandidateFrameTopLeft(windowTopLeftPoint)
  }

  override public func handle(_ event: NSEvent!, client _: Any!) -> Bool {
    guard let delegate = delegate else { return false }
    return delegate.handleDelegateEvent(event)
  }
}
