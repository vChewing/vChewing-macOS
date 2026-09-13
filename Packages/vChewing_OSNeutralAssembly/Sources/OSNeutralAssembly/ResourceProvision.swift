// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import ResourceLocator

// MARK: - ResourceProvision

/// 本套件對宿主的資源指定介面。
///
/// 本套件與其依賴皆不假設自己的編譯產物必定落在某個 bundle 內：資源查找一律走
/// `ResourceLocator`，查找落空時回傳 `nil`，由各呼叫端自行實裝 fail-safe。
/// 當編譯產物以動態庫身分被裝載、或整包脫離原始佈局時，宿主可經由本介面手動指定資源位置。
///
/// 各依賴自身的資源指定 API（例如 `BPMFVS.specifyDataURL(_:)`）在此處統一轉曝露，
/// 令宿主只需認識本套件、不必逐一 import 底層模組。
public enum ResourceProvision {
  /// 全域資源根目錄。指定後，所有 SwiftPM 資源 bundle 都會優先在此目錄下尋找。
  public static func specifyResourceRoot(_ url: URL?) {
    ResourceLocator.resourceRootURL = url
  }

  /// 為指定名稱的 SwiftPM 資源 bundle 手動指定位置。
  /// - Parameters:
  ///   - url: 資源 bundle 本身、或其所在目錄。傳 `nil` 代表清除該項指定。
  ///   - name: 資源 bundle 名稱（形如 `PackageName_TargetName`，不含 `.bundle`）。
  public static func specifyResourceBundle(_ url: URL?, forBundleNamed name: String) {
    ResourceLocator.specifyResourceBundleURL(url, forBundleNamed: name)
  }

  /// 手動指定 BPMFVS 注音標記資料表的位置。傳 `nil` 代表清除指定、退回預設查找。
  public static func specifyBPMFVSTable(_ url: URL?) {
    BPMFVS.specifyDataURL(url)
  }

  /// 清除所有手動指定，回復為純粹的佈局推導。
  public static func clearAllSpecifications() {
    ResourceLocator.clearSpecifiedResources()
    BPMFVS.specifyDataURL(nil)
  }

  /// 當前各項資源的可用狀態，供宿主診斷部署問題。
  ///
  /// 本套件與其依賴在執行期需要的檔案資源僅此一項；
  /// 回報的是「該資源是否已成功載入」而非「路徑是否存在」。
  public static func availabilityReport() -> [String: Bool] {
    ["BPMFVS.phonic_table_Z": BPMFVS.isDataTableLoaded]
  }
}
