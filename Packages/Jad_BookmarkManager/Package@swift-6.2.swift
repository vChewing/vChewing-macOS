// swift-tools-version: 6.2
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。**
//
// Swift 6.2／6.3 對「default-isolated 的下游型別遵循 default-isolated 的上游協定」會強制索求明文
// `@MainActor`（`#ConformanceIsolation`），本倉（default-isolation 為主）的依賴閉包因此無法在該兩版下
// 建置——即：本套件在該兩版下**不存在可用的產物形態**。此封堵是**全倉一致**的（見倉根 meta-manifest 與
// 聚合體的兩份同名封堵檔），不是逐套件的個別判斷。
//
// 生效機理：SwiftPM 之版本擇定規則為「於 `Package*.swift` 全集中取檔內宣言的 tools version 不高於
// toolchain 版本者之最高者」（故 6.2 toolchain 取本檔、6.3 toolchain 取 `Package@swift-6.3.swift`，
// 6.4 以上才取 `Package.swift`），而 `#error` 於 manifest 編譯期即中止載入。
//
// 可用的兩條路：Swift 5.10（見 `Package@swift-5.10.swift`：靜態產物、無測試靶、無平台限制）
// 或 Swift 6.4 以上（見 `Package.swift`）。
#error(
  """
  BookmarkManager 不支援 Swift 6.2 / 6.3 toolchain：Swift 6.x 僅支援 6.4+。
  6.2／6.3 對「default-isolated 下游型別遵循 default-isolated 協定」會強制索求明文 @MainActor
  （#ConformanceIsolation），故本依賴閉包在該兩版下不存在可用的產物形態。
  理由與實測見 vChewing-DevLogs/Research/Phase216_PostResearch.md §13.6。
  請改用 Swift 5.10（Package@swift-5.10.swift）或 Swift 6.4 以上（Package.swift）。
  """
)
