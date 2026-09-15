// swift-tools-version: 6.1
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。** 理由同聚合體根部之 `Package@swift-6.0.swift`；
// 之所以與 6.0 那一份並存，是因為 SwiftPM 之比對基準是**檔內宣告的 tools version**，
// 6.1 toolchain 只會挑到 tools version 6.1 這一檔。
#error(
  """
  VanguardSwiftExtension 不支援 Swift 6.0 / 6.1 toolchain（既不支援 libArcLite 混編，亦不支援 Approachable Concurrency）。
  請改用 Swift 5.10（Package@swift-5.10.swift）或 Swift 6.2 以上（Package.swift）。
  """
)
