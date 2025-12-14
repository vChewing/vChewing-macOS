// 下述詞頻資料取自先鋒語料庫 (https://github.com/vchewing/libvchewing-data)
// 部分權重內容有篡改（「年中」的權重）、以符合單元測試之目的。

import Foundation

public enum LMATestsData {
  public static let sqlTestCoreLMData: String = {
    let url = Bundle.module.url(forResource: "vanguardLegacy_test", withExtension: "sql")
    guard let url else { return "" }
    return (try? String(contentsOf: url)) ?? ""
  }()
}
