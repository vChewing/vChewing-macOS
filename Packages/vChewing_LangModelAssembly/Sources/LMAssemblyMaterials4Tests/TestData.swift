// 下述詞頻資料取自先鋒語料庫 (https://github.com/vchewing/libvchewing-data)
// 部分權重內容有篡改（「年中」的權重）、以符合單元測試之目的。

import Foundation

public enum LMATestsData {
  // MARK: Public

  public static let textMapTestCoreLMData: String = {
    loadFixture(fileNameStem: "vanguardTextMap_test", ext: "txtMap")
  }()

  public static func getCINPath4Tests(_ fileNameStem: String, ext: String) -> String? {
    let url = Bundle.module.url(forResource: fileNameStem, withExtension: ext)
    guard let url else { return nil }
    return url.path
  }

  // MARK: Private

  private static func loadFixture(fileNameStem: String, ext: String) -> String {
    let url: URL?
    #if canImport(Darwin)
      if #available(macOS 12, *) {
        url = #bundle.url(forResource: fileNameStem, withExtension: ext)
      } else {
        url = Bundle.module.url(forResource: fileNameStem, withExtension: ext)
      }
    #else
      url = Bundle.module.url(forResource: fileNameStem, withExtension: ext)
    #endif
    guard let url else { return "" }
    return (try? String(contentsOf: url, encoding: .utf8)) ?? ""
  }
}
