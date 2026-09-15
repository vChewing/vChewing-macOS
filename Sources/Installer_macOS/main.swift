// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import InstallerAssembly4Darwin

// `asyncInit()` 需要 macOS 10.15 起的 concurrency 執行期，故以編譯器世代分流：6.2 以上走它、5.10（legacy 靜態
// 路徑）走純同步入口——免得 top-level `await` 讓執行檔在載入期就硬依賴 concurrency（`swift_task_*`），而 10.9
// 上並無該執行期。**`isLegacyDistro` 一律由本入口明示**：6.2 側＝現代發行版（`false`）、5.10 側＝legacy 發行版
// （`true`）；安裝程式類別不再由 bundle ID 猜測。真正的 AppKit／SwiftUI 抉擇仍由 `runNSApp(isLegacyDistro:)`
// 內按 `#available(macOS 12, *)` 自行處理。
#if compiler(>=6.2)
  await MainSputnik4Installer.asyncInit().runNSApp(isLegacyDistro: false)
#else
  MainSputnik4Installer().runNSApp(isLegacyDistro: true)
#endif
