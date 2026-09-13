// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import SwiftExtension

#if canImport(Musl)
  import Musl
#elseif canImport(Glibc)
  import Glibc
#elseif canImport(Darwin)
  import Darwin
#elseif canImport(ucrt)
  import ucrt
#endif

// MARK: - ResourceLocator

/// 資源查找器。以「不假設編譯產物必定身處於某個 bundle 內」為前提查找資源。
///
/// SwiftPM 自動生成的 `Bundle.module` 在找不到資源 bundle 時會直接 `fatalError`；
/// 編譯產物一旦以動態庫（dylib）身分被裝載、或整包脫離原始佈局，
/// 這條路徑就會把宿主行程一起帶走。此處改為依序嘗試候選位置，
/// 全部落空則回傳 `nil`，由呼叫端自行實裝 fail-safe。
///
/// 查找順序：
/// 1. 呼叫端以 `specifyResourceBundleURL(_:forBundleNamed:)` 或 `resourceRootURL`
///    手動指定的位置（供無法從佈局推得資源所在的宿主使用）。
/// 2. `Bundle.main` 的資源目錄（`.app/Contents/Resources/`）。
/// 3. 呼叫端型別所屬 bundle 的資源目錄（framework、測試 bundle）。
/// 4. 呼叫端型別所屬 bundle 之同層目錄（`swift test` 的兄弟佈局）。
/// 5. 編譯產物（執行檔或 dylib）所在目錄、其父目錄、以及其 `Contents/Resources/`。
///
/// 每個候選位置都會依序試 `<名稱>.bundle`、`<名稱>.resources`（SwiftPM 在 Linux／Windows
/// 的產出）與不帶副檔名的 `<名稱>` 目錄三種變體；`Bundle(url:)` 落空時再直接以檔案系統查找。
public enum ResourceLocator {
  // MARK: Public

  /// 全域資源根目錄。指定後，所有資源 bundle 都會優先在此目錄下尋找。
  public static var resourceRootURL: URL? {
    get { mtxResourceRoot.withLockRead { $0 } }
    set { mtxResourceRoot.withLock { $0 = newValue } }
  }

  /// 為指定名稱的資源 bundle 手動指定位置。該位置可以是資源 bundle 本身、或其所在目錄。
  public static func specifyResourceBundleURL(_ url: URL?, forBundleNamed name: String) {
    mtxSpecifiedBundles.withLock { $0[name] = url }
  }

  /// 查詢指定名稱的資源 bundle 當前被指定的位置。
  public static func specifiedResourceBundleURL(forBundleNamed name: String) -> URL? {
    mtxSpecifiedBundles.withLockRead { $0[name] }
  }

  /// 清除所有手動指定，回復為純粹的佈局推導。
  public static func clearSpecifiedResources() {
    mtxResourceRoot.withLock { $0 = nil }
    mtxSpecifiedBundles.withLock { $0.removeAll() }
  }

  /// 查找指定的 SwiftPM 資源 bundle（名稱形如 `PackageName_TargetName`，不含 `.bundle`）。
  /// - Parameters:
  ///   - bundleName: 資源 bundle 名稱。
  ///   - anchor: 呼叫端所屬的型別，用於推得編譯產物所在位置。
  /// - Returns: 找到的資源 bundle；找不到則回傳 `nil`。
  public static func resourceBundle(named bundleName: String, anchor: AnyClass) -> Bundle? {
    for candidate in resourceBundleCandidates(named: bundleName, anchor: anchor) {
      if let bundle = Bundle(url: candidate) { return bundle }
    }
    return nil
  }

  /// 查找資源檔。找不到則回傳 `nil`。
  /// - Parameters:
  ///   - name: 資源檔主檔名（不含副檔名）。
  ///   - ext: 資源檔副檔名。
  ///   - bundleName: SwiftPM 資源 bundle 名稱。傳 `nil` 代表只查宿主 bundle。
  ///   - anchor: 呼叫端所屬的型別，用於推得編譯產物所在位置。
  public static func url(
    forResource name: String,
    withExtension ext: String,
    inSwiftPMResourceBundleNamed bundleName: String?,
    anchor: AnyClass
  )
    -> URL? {
    if let bundleName {
      if let bundle = resourceBundle(named: bundleName, anchor: anchor),
         let url = bundle.url(forResource: name, withExtension: ext) {
        return url
      }
      // `Bundle(url:)` 在 Linux／Windows 對 SwiftPM 的 `.resources` 目錄未必可行，
      // 故再直接以檔案系統在各候選位置查找一次。
      for directory in resourceBundleCandidates(named: bundleName, anchor: anchor) {
        let direct = directory.appendingPathComponent(name).appendingPathExtension(ext)
        if FileManager.default.fileExists(atPath: direct.path) { return direct }
      }
    }
    // 資源亦可能被直接攤平在宿主 bundle 的資源目錄內（Xcode 專案常見佈局）。
    if let url = Bundle.main.url(forResource: name, withExtension: ext) { return url }
    for directory in candidateDirectories(anchor: anchor) {
      let url = directory.appendingPathComponent(name).appendingPathExtension(ext)
      if FileManager.default.fileExists(atPath: url.path) { return url }
    }
    return nil
  }

  // MARK: Private

  private static let mtxResourceRoot = NSMutex<URL?>(nil)
  private static let mtxSpecifiedBundles = NSMutex([String: URL]())

  /// 資源 bundle 的三種候選名稱：Apple 平台為 `.bundle`，Linux／Windows 由 SwiftPM 產出為
  /// `.resources`，亦容許不帶副檔名的目錄（自訂佈局）。
  private static func resourceBundleCandidateNames(for name: String) -> [String] {
    ["\(name).bundle", "\(name).resources", name]
  }

  /// 把「一個目錄 + 一個 bundle 名稱」展開成三種候選 URL。
  private static func resourceBundleCandidateURLs(for name: String, in directory: URL) -> [URL] {
    resourceBundleCandidateNames(for: name).map { directory.appendingPathComponent($0) }
  }

  /// 依查找優先序排列的資源 bundle 候選位置（手動指定優先，其次資源根目錄，最後由佈局推得）。
  private static func resourceBundleCandidates(named bundleName: String, anchor: AnyClass) -> [URL] {
    var result = [URL]()
    if let specified = specifiedResourceBundleURL(forBundleNamed: bundleName) {
      // 呼叫端給的可能是資源 bundle 本身、也可能是其所在目錄；前者亦接受三種名稱變體。
      if resourceBundleCandidateNames(for: bundleName).contains(specified.lastPathComponent) {
        result.append(specified)
      } else {
        result.append(contentsOf: resourceBundleCandidateURLs(for: bundleName, in: specified))
        result.append(specified)
      }
    }
    if let root = resourceRootURL {
      result.append(contentsOf: resourceBundleCandidateURLs(for: bundleName, in: root))
    }
    for directory in candidateDirectories(anchor: anchor) {
      result.append(contentsOf: resourceBundleCandidateURLs(for: bundleName, in: directory))
    }
    return result
  }

  /// 依查找優先序排列的候選目錄。
  private static func candidateDirectories(anchor: AnyClass) -> [URL] {
    var result = [URL]()
    func append(_ url: URL?) {
      guard let url, !result.contains(url) else { return }
      result.append(url)
    }
    append(Bundle.main.resourceURL)
    append(Bundle(for: anchor).resourceURL)
    append(Bundle.main.bundleURL)
    append(Bundle(for: anchor).bundleURL.deletingLastPathComponent())
    if let imageDir = imageDirectory() {
      append(imageDir)
      append(imageDir.deletingLastPathComponent())
      append(imageDir.deletingLastPathComponent().appendingPathComponent("Resources"))
    }
    return result
  }

  /// 當前編譯產物（執行檔或 dylib）所在目錄。取不到時回傳 `nil`。
  private static func imageDirectory() -> URL? {
    #if canImport(Darwin)
      var info = Dl_info()
      guard dladdr(#dsohandle, &info) != 0, let imagePath = info.dli_fname else { return nil }
      return URL(fileURLWithPath: String(cString: imagePath)).deletingLastPathComponent()
    #else
      // Linux／Windows 沒有等價且可編譯的 API；改取宿主執行檔所在目錄。
      return Bundle.main.executableURL?.deletingLastPathComponent()
    #endif
  }
}
