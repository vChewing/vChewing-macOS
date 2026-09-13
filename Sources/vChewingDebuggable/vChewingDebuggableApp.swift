// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import SwiftUI

@main
struct vChewingDebuggableApp: App {
  var body: some Scene {
    // 刻意使用單一 Window scene：WindowGroup 會讓本 app 變成可多開視窗/分頁的
    // 多實例應用，重複 `open` 會在同一個 process 內疊出多個 ContentView，
    // 使記憶體量測的 baseline 隨啟動次數累積。Window scene 只允許單一視窗。
    Window("vChewingDebuggable", id: "vChewingDebuggable.Main") {
      ContentView()
        .onOpenURL { url in
          DiagnosticsViewModel.shared.handle(url: url)
        }
    }
    .defaultSize(width: 760, height: 480)
  }
}
