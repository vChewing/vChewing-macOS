// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Shared
import Testing

@testable import MainAssembly4Darwin

// MARK: - SecurityAgentWarningAlertTests

/// 警示之版面：`NSAlert` 於模態呈現時會自行排版，本方不進模態故須自叫 `layout()`。
///
/// 少了那一步，拿到的是一份未經配置的視窗——三個按鈕槽全露（兩個空白）、抑制列以
/// `<Do not show this message again>` 之佔位字串現形、標題與內文各被壓成一行。此套房即釘住
/// 這三件事，免得日後有人把 `layout()` 挪走。
struct SecurityAgentWarningAlertTests {
  // MARK: Internal

  static let body = String(
    repeating: "唯音有偵測到下述後檯執行緒有在濫用 SecureEventInput，這種濫用會導致系統內的所有第三方輸入法全都無法正常使用。\n\n",
    count: 8
  )

  @Test
  func testAlertHasExactlyOneButton() {
    let alert = Self.makeAlert()
    #expect(alert.buttons.count == 1)
    #expect(alert.buttons.first?.title == "確定")
    // 未排版者會多出兩個空白按鈕槽。
    #expect(Self.allButtons(in: alert).count == 1)
  }

  @Test
  func testAlertShowsNoSuppressionPlaceholder() {
    let alert = Self.makeAlert()
    let titles = Self.allButtons(in: alert).map(\.title)
    #expect(!titles.contains { $0.localizedCaseInsensitiveContains("do not show") })
    #expect(!titles.contains { $0.contains("suppress") })
  }

  @Test
  func testAlertWindowAdoptsTheLaidOutWidth() {
    let alert = Self.makeAlert()
    // 未排版者之視窗寬為 260（系統預設種子值）；排版後依內文變寬。
    #expect(alert.window.frame.width > 400, "未呼叫 layout() 時此值停留於 260")
  }

  @Test
  func testAlertBodyIsNotClampedToOneLine() {
    let alert = Self.makeAlert()
    let tallest = Self.allTextFields(in: alert).map(\.frame.height).max() ?? 0
    // 未排版者之兩個文字欄皆為 16 點高（一行）；排版後內文欄隨內容長高。
    #expect(tallest > 100, "內文欄高 \(tallest) 點，似仍被壓成一行")
  }

  // MARK: Private

  private static func makeAlert() -> NSAlert {
    SecurityAgentHelper.makeWarningAlert(
      title: "偵測到對 SecureEventInput 的濫用行為",
      body: body,
      buttonTitle: "確定"
    )
  }

  private static func allButtons(in alert: NSAlert) -> [NSButton] {
    flattened(alert.window.contentView).compactMap { $0 as? NSButton }
  }

  private static func allTextFields(in alert: NSAlert) -> [NSTextField] {
    flattened(alert.window.contentView).compactMap { $0 as? NSTextField }
  }

  private static func flattened(_ view: NSView?) -> [NSView] {
    guard let view else { return [] }
    return [view] + view.subviews.flatMap { flattened($0) }
  }
}
