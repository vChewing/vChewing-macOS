// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import AppKit
import Shared_DarwinImpl

// MARK: - StatusUI

/// 打字模式提示專用的輔助工具提示視窗。
/// 繼承 TooltipUI：維持對 close-all（hidePalette 等）訊號的訂閱（繼承自 TooltipUI.init），
/// 定位語義為「給定點＝視窗左下角」；文字恆為粗體，外觀（文字／背景色）由
/// `sync(accent:locale:)` 依客體 accent 色彩推出——背景為實色、不透明，無
/// visualEffect／glassEffect。
public final class StatusUI: TooltipUI {
  // MARK: Public

  /// 依 accent 推出外觀（參考 PopupCompositionBuffer 的做法）：文字白色粗體、背景為
  /// accent（或依 locale 回退之主題色）混黑 0.5 的**深色實色**（配色恆為 dark mode、
  /// 不隨系統深淺切換；背景實色不透明、無 visualEffect／glassEffect）。
  /// locale 回退表與 PopupCompositionBuffer 的 themeColorCocoa 一致：
  /// zh-Hans 紅／zh-Hant 藍／ja 赭／default 藍。
  override public func sync(accent: HSBA?, locale: String) {
    usesBoldText = true
    let themeColor: NSColor
    if let accentColor = accent?.nsColor {
      themeColor = accentColor
    } else {
      switch locale {
      case "zh-Hans":
        themeColor = .init(red: 255 / 255, green: 64 / 255, blue: 53 / 255, alpha: 1)
      case "zh-Hant":
        themeColor = .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 1)
      case "ja":
        themeColor = .init(red: 167 / 255, green: 137 / 255, blue: 99 / 255, alpha: 1)
      default:
        themeColor = .init(red: 5 / 255, green: 127 / 255, blue: 255 / 255, alpha: 1)
      }
    }
    let backgroundColor = themeColor.blended(withFraction: 0.5, of: .black) ?? themeColor
    applyTextColor(.white)
    applyBackgroundColor(backgroundColor)
  }

  // MARK: Internal

  override func positionWindow(at point: CGPoint, heightDelta: Double) {
    guard let window else { return }
    let windowHeight = window.frame.size.height
    let topLeftPoint = CGPoint(x: point.x, y: point.y + windowHeight)
    set(windowTopLeftPoint: topLeftPoint, bottomOutOfScreenAdjustmentHeight: heightDelta, useGCD: false)
  }
}
