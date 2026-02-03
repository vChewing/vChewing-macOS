// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftExtension

#if canImport(AppKit)

  import AppKit

  extension NSWindowController {
    public func orderFront() {
      window?.orderFront(self)
    }

    /// 設定選字窗的顯示位置。
    ///
    /// 需注意：該函式會藉由設定選字窗左上角頂點的方式、使選字窗始終位於某個螢幕之內。
    ///
    /// - Parameters:
    ///   - windowTopLeftPoint: 給定的視窗顯示位置。
    ///   - heightDelta: 為了「防止選字窗抻出螢幕下方」而給定的預留高度。
    public func set(
      windowTopLeftPoint: CGPoint,
      bottomOutOfScreenAdjustmentHeight heightDelta: Double,
      useGCD: Bool
    ) {
      func doSet() {
        guard let window = window, var screenFrame = NSScreen.main?.visibleFrame else { return }
        let windowSize = window.frame.size

        var adjustedPoint = windowTopLeftPoint
        var delta = heightDelta
        for frame in NSScreen.screens.map(\.visibleFrame)
          .filter({ $0.contains(windowTopLeftPoint) }) {
          screenFrame = frame
          break
        }

        if delta > screenFrame.size.height / 2.0 { delta = 0.0 }

        if adjustedPoint.y < screenFrame.minY + windowSize.height {
          adjustedPoint.y = windowTopLeftPoint.y + windowSize.height + delta
        }
        adjustedPoint.y = min(adjustedPoint.y, screenFrame.maxY - 1.0)
        adjustedPoint.x = min(
          max(adjustedPoint.x, screenFrame.minX),
          screenFrame.maxX - windowSize.width - 1.0
        )

        window.setFrameTopLeftPoint(adjustedPoint)
      }

      if !useGCD { doSet() } else { asyncOnMain { doSet() } }
    }
  }

  extension NSWindow {
    @discardableResult
    public func callAlert(title: String, text: String? = nil) -> NSApplication
      .ModalResponse {
      (self as NSWindow?).callAlert(title: title, text: text)
    }
  }

  extension NSWindow? {
    @discardableResult
    public func callAlert(
      title: String, text: String? = nil
    )
      -> NSApplication.ModalResponse {
      mainSync {
        let alert = NSAlert()
        alert.messageText = title
        if let text = text { alert.informativeText = text }
        alert.addButton(withTitle: "OK".i18n)
        var result: NSApplication.ModalResponse = .alertFirstButtonReturn
        guard let this = self else { return alert.runModal() }
        alert.beginSheetModal(for: this) { theResponce in
          result = theResponce
        }
        return result
      }
    }
  }

#endif
