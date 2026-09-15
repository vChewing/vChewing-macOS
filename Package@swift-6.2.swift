// swift-tools-version: 6.2
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。**
//
// 本 manifest（`vChewingIME`）是倉根 meta-manifest：兩支執行檔 ＋ `BundleApps` 插件，其依賴閉包經
// `vChewing_MainAssembly4Darwin` 一路吃到 `vChewing_OSNeutral_LibVanguard`；該聚合體已於其
// `Package@swift-6.2.swift`／`Package@swift-6.3.swift` 明文拒絕該兩版，本 manifest 同步拒絕。
//
// 理由：Swift 6.2／6.3 對「default-isolated 的下游型別遵循 default-isolated 的上游協定」會強制索求
// 明文 `@MainActor`（`#ConformanceIsolation`）。生效機理：SwiftPM 之版本擇定規則為「於
// `Package*.swift` 全集中取檔內宣言的 tools version 不高於 toolchain 版本者之最高者」（故 6.2
// toolchain 取本檔、6.3 toolchain 取 `Package@swift-6.3.swift`，6.4 以上才取 `Package.swift`），
// 而 `#error` 於 manifest 編譯期即中止載入。
//
// 可用的路：Swift 6.4 以上（見 `Package.swift`）。本 manifest 不在 Swift 5.10 側（無 5.10 對位版）。
#error(
  """
  vChewingIME 不支援 Swift 6.2 / 6.3 toolchain：Swift 6.x 僅支援 6.4+。
  6.2／6.3 對「default-isolated 下游型別遵循 default-isolated 協定」會強制索求明文 @MainActor
  （#ConformanceIsolation），故本依賴閉包在該兩版下不存在可用的產物形態。
  理由與實測見 vChewing-DevLogs/Research/Phase216_PostResearch.md §13.6。
  請改用 Swift 6.4 以上（Package.swift）。
  """
)
