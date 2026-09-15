// swift-tools-version: 6.3
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。** 內容與理由同目錄之 `Package@swift-6.2.swift`
// （6.2／6.3 兩版同屬「災星」，其 `#ConformanceIsolation` 令本倉全體的依賴閉包無法建置）。
// 之所以仍各寫一份，是因為 SwiftPM 之比對基準是**檔內宣告的 tools version**，
// 6.3 toolchain 只會挑到 tools version 6.3 這一檔。
#error(
  """
  SettingsUI 不支援 Swift 6.2 / 6.3 toolchain：Swift 6.x 僅支援 6.4+。
  6.2／6.3 對「default-isolated 下游型別遵循 default-isolated 協定」會強制索求明文 @MainActor
  （#ConformanceIsolation），故本依賴閉包在該兩版下不存在可用的產物形態。
  理由與實測見 vChewing-DevLogs/Research/Phase216_PostResearch.md §13.6。
  請改用 Swift 5.10（Package@swift-5.10.swift）或 Swift 6.4 以上（Package.swift）。
  """
)
