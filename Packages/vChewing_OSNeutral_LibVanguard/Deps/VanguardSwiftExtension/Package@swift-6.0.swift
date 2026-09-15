// swift-tools-version: 6.0
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。** 理由同聚合體根部之 `Package@swift-6.0.swift`：
// Swift 6.0／6.1 既不支援 libArcLite 混編，亦不支援 Approachable Concurrency，本套件在該兩版下
// 不存在有意義的產物形態。
#error(
  """
  VanguardSwiftExtension 不支援 Swift 6.0 / 6.1 toolchain（既不支援 libArcLite 混編，亦不支援 Approachable Concurrency）。
  請改用 Swift 5.10（Package@swift-5.10.swift）或 Swift 6.2 以上（Package.swift）。
  """
)
