// swift-tools-version: 6.0
import PackageDescription

// **本檔是封堵檔（blocker），不是建置設定檔。**
//
// Swift 6.0／6.1 是兩版「災星」toolchain：既不支援與 libArcLite 混編（macOS 10.9 側的 ARC 執行期），
// 亦不支援 Swift 6.2 起才有的 Approachable Concurrency（`defaultIsolation` 等）。換言之，本套件在該兩版下
// **不存在任何有意義的產物形態**——與其讓它以殘缺設定建置出看似成功、實則不可用的東西，不如在此明文擋下。
//
// 生效機理：SwiftPM 之版本擇定規則為「於 `Package*.swift` 全集中取檔內宣言的 tools version 不高於
// toolchain 版本者之最高者」（故 6.0／6.1 toolchain 會取本檔而非 `Package.swift` 的 6.4），而
// `#error` 於 manifest 編譯期即中止載入。
//
// 可用的兩條路：Swift 5.10（見 `Package@swift-5.10.swift`：靜態產物、無測試靶、無平台限制）
// 或 Swift 6.4 以上（見 `Package.swift`）。
#error(
  """
  CandidateWindow 不支援 Swift 6.0 / 6.1 toolchain（既不支援 libArcLite 混編，亦不支援 Approachable Concurrency）。
  請改用 Swift 5.10（Package@swift-5.10.swift）或 Swift 6.4 以上（Package.swift）。
  """
)
