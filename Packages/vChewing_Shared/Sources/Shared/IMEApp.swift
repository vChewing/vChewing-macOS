// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - IMEApp

public enum IMEApp {
  // MARK: - 輸入法的當前的簡繁體中文模式

  /// 從 UserDefaults 直接讀取目前的輸入模式，避免每次存取都重新建構整個 PrefMgr()。
  /// 原先的寫法會在每次呼叫時觸發 PrefMgr 的 103 個 @AppProperty 初始化，
  /// 導致 103+ 次 UserDefaults 讀取，造成 CapsLock 切換遲滯。
  public static var currentInputMode: Shared.InputMode {
    .init(rawValue: PrefMgr.sharedSansDidSetOps.mostRecentInputMode) ?? .imeModeNULL
  }
}
