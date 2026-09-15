// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import MainAssembly4Darwin

// `asyncInit()` 需要 macOS 10.15 起的 concurrency 執行期，故以編譯器世代分流，5.10 側走純同步入口。
// **`isLegacyDistro` 一律由本入口明示**：6.2 側＝現代發行版（`false`）、5.10 側＝legacy 發行版（`true`）；
// 它同時決定 `UpdateSputnik` 之跨發行版判定與 `UpdateInfoEndpoint(Legacy)` 之取用。
#if compiler(>=6.2)
  await MainSputnik4IME.asyncInit().runNSApp(isLegacyDistro: false)
#else
  MainSputnik4IME().runNSApp(isLegacyDistro: true)
#endif
