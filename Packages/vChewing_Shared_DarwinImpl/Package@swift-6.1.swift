// swift-tools-version: 6.1
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。** 內容與理由同同目錄之 `Package@swift-6.0.swift`
// （6.0／6.1 兩版同屬「災星」，皆無 libArcLite 混編能力與 Approachable Concurrency）。之所以仍各寫一份，
// 是因為 SwiftPM 之比對基準是**檔內宣告的 tools version**，6.1 toolchain 只會挑到 tools version 6.1 這一檔。
#error(
  """
  Shared_DarwinImpl 不支援 Swift 6.0 / 6.1 toolchain（既不支援 libArcLite 混編，亦不支援 Approachable Concurrency）。
  請改用 Swift 5.10（Package@swift-5.10.swift）或 Swift 6.4 以上（Package.swift）。
  """
)
