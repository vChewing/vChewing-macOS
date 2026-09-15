// swift-tools-version: 6.2
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。** 理由同聚合體根部之 `Package@swift-6.2.swift`：
// Swift 6.2／6.3 對「default-isolated 的下游型別遵循 default-isolated 的上游協定」會強制索求明文
// `@MainActor`（`#ConformanceIsolation`），整個依賴閉包因此不存在於該兩版——本套件自身雖未中招
// （實測單獨建置 rc=0），但它是閉包的底層，出口須與閉包一致。
#error(
  """
  VanguardSwiftExtension 不支援 Swift 6.2 / 6.3 toolchain：Swift 6.x 僅支援 6.4+。
  6.2／6.3 對「default-isolated 下游型別遵循 default-isolated 協定」會強制索求明文 @MainActor
  （#ConformanceIsolation），故本依賴閉包在該兩版下不存在可用的產物形態。
  理由與實測見 vChewing-DevLogs/Research/Phase216_PostResearch.md §13.6。
  請改用 Swift 5.10（Package@swift-5.10.swift）或 Swift 6.4 以上（Package.swift）。
  """
)
