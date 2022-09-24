// (c) 2011 and onwards The OpenVanilla Project (MIT License).
// All possible vChewing-specific modifications are of:
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

public enum CandidateLayout {
  case horizontal
  case vertical
}

public class CandidateKeyLabel: NSObject {
  public private(set) var key: String
  public private(set) var displayedText: String

  public init(key: String, displayedText: String) {
    self.key = key
    self.displayedText = displayedText
    super.init()
  }
}

public protocol ctlCandidateDelegate: AnyObject {
  func candidateCountForController(_ controller: ctlCandidateProtocol) -> Int
  func candidatesForController(_ controller: ctlCandidateProtocol) -> [(String, String)]
  func ctlCandidate(_ controller: ctlCandidateProtocol, candidateAtIndex index: Int)
    -> (String, String)
  func candidateSelected(at index: Int)
}

public protocol ctlCandidateProtocol {
  var currentLayout: CandidateLayout { get set }
  var delegate: ctlCandidateDelegate? { get set }
  var selectedCandidateIndex: Int { get set }
  var visible: Bool { get set }
  var windowTopLeftPoint: NSPoint { get set }
  var keyLabels: [CandidateKeyLabel] { get set }
  var keyLabelFont: NSFont { get set }
  var candidateFont: NSFont { get set }
  var tooltip: String { get set }

  init(_ layout: CandidateLayout)
  func reloadData()
  func showNextPage() -> Bool
  func showPreviousPage() -> Bool
  func highlightNextCandidate() -> Bool
  func highlightPreviousCandidate() -> Bool
  func candidateIndexAtKeyLabelIndex(_: Int) -> Int
  func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: CGFloat)
}

public class ctlCandidate: NSWindowController, ctlCandidateProtocol {
  public var currentLayout: CandidateLayout = .horizontal
  public weak var delegate: ctlCandidateDelegate? {
    didSet {
      reloadData()
    }
  }

  public var selectedCandidateIndex: Int = .max
  public var visible = false {
    didSet {
      NSObject.cancelPreviousPerformRequests(withTarget: self)
      if visible {
        window?.perform(#selector(NSWindow.orderFront(_:)), with: self, afterDelay: 0.0)
      } else {
        window?.perform(#selector(NSWindow.orderOut(_:)), with: self, afterDelay: 0.0)
      }
    }
  }

  public var windowTopLeftPoint: NSPoint {
    get {
      guard let frameRect = window?.frame else {
        return NSPoint.zero
      }
      return NSPoint(x: frameRect.minX, y: frameRect.maxY)
    }
    set {
      DispatchQueue.main.async {
        self.set(windowTopLeftPoint: newValue, bottomOutOfScreenAdjustmentHeight: 0)
      }
    }
  }

  public required init(_: CandidateLayout = .horizontal) {
    super.init(window: .init())
    visible = false
  }

  @available(*, unavailable)
  required init?(coder _: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  public var keyLabels: [CandidateKeyLabel] = ["1", "2", "3", "4", "5", "6", "7", "8", "9"]
    .map {
      CandidateKeyLabel(key: $0, displayedText: $0)
    }

  public var keyLabelFont = NSFont.monospacedDigitSystemFont(
    ofSize: 14, weight: .medium
  )
  public var candidateFont = NSFont.systemFont(ofSize: 18)
  public var tooltip: String = ""

  public func reloadData() {}

  @discardableResult public func showNextPage() -> Bool {
    false
  }

  @discardableResult public func showPreviousPage() -> Bool {
    false
  }

  @discardableResult public func highlightNextCandidate() -> Bool {
    false
  }

  @discardableResult public func highlightPreviousCandidate() -> Bool {
    false
  }

  public func candidateIndexAtKeyLabelIndex(_: Int) -> Int {
    Int.max
  }

  /// Sets the location of the candidate window.
  ///
  /// Please note that the method has side effects that modifies
  /// `windowTopLeftPoint` to make the candidate window to stay in at least
  /// in a screen.
  ///
  /// - Parameters:
  ///   - windowTopLeftPoint: The given location.
  ///   - height: The height that helps the window not to be out of the bottom
  ///     of a screen.
  public func set(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight height: CGFloat) {
    DispatchQueue.main.async {
      self.doSet(
        windowTopLeftPoint: windowTopLeftPoint, bottomOutOfScreenAdjustmentHeight: height
      )
    }
  }

  func doSet(windowTopLeftPoint: NSPoint, bottomOutOfScreenAdjustmentHeight heightDelta: CGFloat) {
    guard let window = window else { return }
    let windowSize = window.frame.size

    var adjustedPoint = windowTopLeftPoint
    var delta = heightDelta
    var screenFrame = NSScreen.main?.visibleFrame ?? NSRect.seniorTheBeast
    for frame in NSScreen.screens.map(\.visibleFrame).filter({ $0.contains(windowTopLeftPoint) }) {
      screenFrame = frame
      break
    }

    if delta > screenFrame.size.height / 2.0 { delta = 0.0 }

    if adjustedPoint.y < screenFrame.minY + windowSize.height {
      adjustedPoint.y = windowTopLeftPoint.y + windowSize.height + delta
    }
    adjustedPoint.y = min(adjustedPoint.y, screenFrame.maxY - 1.0)
    adjustedPoint.x = min(max(adjustedPoint.x, screenFrame.minX), screenFrame.maxX - windowSize.width - 1.0)

    window.setFrameTopLeftPoint(adjustedPoint)
  }
}
