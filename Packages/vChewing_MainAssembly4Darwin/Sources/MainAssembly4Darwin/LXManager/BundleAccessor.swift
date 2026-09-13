// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import ResourceLocator

// MARK: - _BundleFinder

/// Anchor class for `Bundle(for:)` resolution.
private class _BundleFinder {}

extension Foundation.Bundle {
  /// 本專案原廠資源 bundle 的查找器。
  ///
  /// 資源 bundle 在 `.app` 內位於 `Contents/Resources/`，在 SwiftPM 建置產物目錄內則與
  /// 執行檔同層；其餘候選位置由 `ResourceLocator` 依序嘗試。全部落空時回傳 `nil`，
  /// 由呼叫端決定退避行為，不再以 `fatalError` 中斷宿主行程。
  ///
  /// 查找成功後快取結果；查找失敗則不快取，令宿主於啟動階段補做的手動指定仍然有效
  /// （見 `ResourceLocator.specifyResourceBundleURL(_:forBundleNamed:)`）。
  static var currentSPM: Bundle? {
    if let cached = cachedCurrentSPM { return cached }
    guard let resolved = ResourceLocator.resourceBundle(
      named: "MainAssembly4Darwin_MainAssembly4Darwin",
      anchor: _BundleFinder.self
    )
    else { return nil }
    cachedCurrentSPM = resolved
    return resolved
  }

  private static var cachedCurrentSPM: Bundle?
}
