// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
#if canImport(CoreGraphics)
  import CoreGraphics
#endif
import LibVanguard

// MARK: - BenchStats

/// 一次量測之統計結果（單位：微秒）。
struct BenchStats {
  // MARK: Internal

  let samples: [Double]

  var count: Int { samples.count }
  var p50: Double { percentile(0.50) }
  var p90: Double { percentile(0.90) }
  var p99: Double { percentile(0.99) }
  var max: Double { samples.max() ?? 0 }

  // MARK: Private

  private func percentile(_ q: Double) -> Double {
    guard !samples.isEmpty else { return 0 }
    let sorted = samples.sorted()
    let index = Swift.min(sorted.count - 1, Int(Double(sorted.count - 1) * q))
    return sorted[index]
  }
}

// MARK: - BenchClientProxy

/// 客體替身：只把遞交／標記之內容留在記憶體，不接任何真實 App。
final class BenchClientProxy: SessionClientProxy {
  private(set) var committedText = ""
  private(set) var markedText = ""
  private(set) var markedTextSetupCount = 0
  var clientBundleID = "com.apple.TextEdit"

  func resetRecording() {
    committedText = ""
    markedText = ""
    markedTextSetupCount = 0
  }

  func hasClient() -> Bool { true }

  func clientTextInsertion(with text: String, replacementRange _: NSRange) {
    committedText += text
  }

  func clientMarkedTextSetup(
    with text: NSAttributedString,
    selectionRange _: NSRange,
    replacementRange _: NSRange
  ) {
    markedText = text.string
    markedTextSetupCount += 1
  }

  func clientBundleIdentifier() -> String? { clientBundleID }

  func clientSelectMode(withModeIdentifier _: String) {}

  func clientOverrideKeyboard(withName _: String) {}

  func clientAttributesForCharacterIndex(
    atU16Pos _: UInt,
    lineHeightRectangle _: UnsafeMutablePointer<CGRect>
  )
    -> [AnyHashable: Any]? { nil }

  func clientLineHeightRect(forU16CursorPos _: UInt) -> CGRect {
    .init(x: 0, y: 0, width: 1, height: 16)
  }
}

// MARK: - BenchCandidateUI

/// 選字窗替身：恆為可見。`InputHandler.handleCandidate` 的頭兩道守衛即「有無 controller」
/// 與「controller 是否可見」；少了它，選字狀態下的一切按鍵（含空白鍵）都會被當成未處理。
final class BenchCandidateUI: CtlCandidateProtocol {
  var delegate: CtlCandidateDelegate?
  var highlightedIndex: Int = 0
  var visible: Bool = true
  var expanded: Bool = false
  var currentLayout: UILayoutOrientation = .horizontal

  func showNextPage() -> Bool { true }
  func showPreviousPage() -> Bool { true }
  func showNextLine() -> Bool { true }
  func showPreviousLine() -> Bool { true }
  func highlightNextCandidate() -> Bool { true }
  func highlightPreviousCandidate() -> Bool { true }
  func candidateIndexAtKeyLabelIndex(_ index: Int) -> Int? { index }
  func set(
    windowTopLeftPoint _: CGPoint,
    bottomOutOfScreenAdjustmentHeight _: Double,
    useGCD _: Bool,
    animated _: Bool
  ) {}
}

// MARK: - BenchShiftKeyUpChecker

final class BenchShiftKeyUpChecker: ShiftKeyUpCheckerProtocol {
  var toggleWithLShift = false
  var toggleWithRShift = false

  func check(_: some InputSignalProtocol) -> Bool { false }
}

// MARK: - BenchNeverHitChecker

final class BenchNeverHitChecker: HitCheckerProtocol {
  func check(_: some InputSignalProtocol) -> Bool { false }
}

// MARK: - BenchCapsLockToggler

final class BenchCapsLockToggler: CapsLockTogglerProtocol {
  var isOn = false
}

// MARK: - BenchSessionUI

/// 會話 UI 之替身：只實作引擎會問到的部分。
final class BenchSessionUI: SessionUIProtocol {
  var currentSessionID = UUID()
  let shiftKeyUpChecker: (any ShiftKeyUpCheckerProtocol)? = BenchShiftKeyUpChecker()
  let capsLockHitChecker: (any HitCheckerProtocol)? = BenchNeverHitChecker()
  let capsLockToggler: (any CapsLockTogglerProtocol)? = BenchCapsLockToggler()
  let pcb: (any PCBProtocol)? = nil
  let tooltipUI: (any TooltipUIProtocol)? = nil
  let statusUI: (any TooltipUIProtocol)? = nil
  let candidateUI: (any CtlCandidateProtocol)? = BenchCandidateUI()
}
