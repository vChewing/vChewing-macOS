// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation

// MARK: - IMEApp

public enum IMEApp {
  // MARK: - 輸入法的當前的簡繁體中文模式

  /// 從 UserDefaults 直接讀取目前的輸入模式，避免每次存取都重新建構整個 PrefMgr()。
  /// 原先的寫法會在每次呼叫時觸發 PrefMgr 的 103 個 @AppProperty 初期化，
  /// 導致 103+ 次 UserDefaults 讀取，造成 CapsLock 切換遲滯。
  public static var currentInputMode: Shared.InputMode {
    .init(rawValue: PrefMgr.sharedSansDidSetOps.mostRecentInputMode) ?? .imeModeNULL
  }
}
