// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Darwin
import Foundation

enum Reloc {
  // MARK: Internal

  /// 判斷位於 `bundlePath` 的應用程式套件是否從轉置位置執行。將 `conservative` 設為 `true` 以將
  /// `com.apple.quarantine` 的存在視為指示（適用於安裝程式中的保守檢查）。
  static func isAppBundleTranslocated(
    atPath bundlePath: String,
    conservative: Bool = false
  )
    -> Bool {
    // 解析符號連結以進行穩定比對
    let resolvedPath = (bundlePath as NSString).resolvingSymlinksInPath

    // 快速檢查：許多轉置路徑包含此哨兵
    if resolvedPath.contains("/AppTranslocation/") {
      return true
    }

    // 保守：隔離 xattr 的存在暗示套件來自網路，且可能在透過 Gatekeeper 啟動時 подвержен 轉置。
    if conservative && Self.hasQuarantineAttribute(atPath: resolvedPath) {
      return true
    }

    // 嘗試 statfs 以了解擁有該路徑的掛載
    var fs = statfs()
    if statfs(resolvedPath, &fs) != 0 {
      return false
    }

    // 安全地將 C 字串欄位轉換為 Swift String
    let mountOn = withUnsafeBytes(of: fs.f_mntonname) { buf -> String in
      buf.bindMemory(to: CChar.self).baseAddress.map { String(cString: $0) } ?? ""
    }
    let mountFrom = withUnsafeBytes(of: fs.f_mntfromname) { buf -> String in
      buf.bindMemory(to: CChar.self).baseAddress.map { String(cString: $0) } ?? ""
    }

    if mountOn.contains("AppTranslocation") || mountFrom.contains("AppTranslocation") {
      return true
    }

    // 若檔案系統為唯讀且位於 /private/var/folders 之下，則很可能為 Gatekeeper 使用的轉置臨時磁碟映像。
    let isReadOnly = (fs.f_flags & UInt32(MNT_RDONLY)) != 0
    if isReadOnly, mountOn.starts(with: "/private/var/folders/") {
      return true
    }

    return false
  }

  // MARK: Private

  // 判斷應用程式是否被 Gatekeeper 轉置到隨機路徑。
  // 改進對 App Translocation 的偵測。
  //
  // 背景：「App Translocation」（Gatekeeper 路徑隨機化）可能在啟動前將應用程式套件複製到臨時唯讀磁碟映像，路徑如
  // `/private/var/folders/.../AppTranslocation/...`。原始實作試圖比對掛載來源名稱然後呼叫
  // `statfs`，但比對了錯誤的 statfs 欄位，且回傳的值無法可靠地指示轉置。
  //
  // 此處使用的策略（穩健且保守）：
  // 1. 快速字串檢查：若解析後的套件路徑包含
  //    `/AppTranslocation/`，則回報為轉置。
  // 2. 在套件路徑上使用 `statfs` 並檢查掛載欄位
  //    (`f_mntonname` 與 `f_mntfromname`)。若任一包含
  //    `AppTranslocation`，則回報為轉置。
  // 3. 若掛載為唯讀且掛載點位於
  //    `/private/var/folders/` 之下，則視為很可能為轉置。
  //
  // 此避免依賴私有 API，並提供可讀、可維護的
  // 啟發式方法，涵蓋常見轉置案例同時最小化假陽性。

  // 輔助：檢查路徑是否有 com.apple.quarantine 擴充屬性。
  private static func hasQuarantineAttribute(atPath path: String) -> Bool {
    let name = "com.apple.quarantine"
    // getxattr 若存在則回傳大小（>=0），若不存在則回傳 -1 並設定 errno。
    let size = getxattr(path, name, nil, 0, 0, 0)
    return size >= 0
  }
}
