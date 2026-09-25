// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import Shared
import Testing

// MARK: - AssistantContractTests

/// 配置助手（`ValueAdd/WebConfigAssistant/`）之產物與唯音匯入端之間的**契約測試**。
///
/// 助手一旦產出唯音不收的包，本測試即紅——此為「助手與 `UserDef` 不漂移」之最強手段。
///
/// 兩項設計取捨：
/// ① **fixture 由助手自己生成**（`ValueAdd/WebConfigAssistant/tools/fixtures.js`，以助手之
///    核心邏輯實際產出配置包），故樣本恆等於助手之真實產物；手抄必然漂移。
/// ② **只做純查詢**：以 `UserDef.destructureExchange(_:)` ＋ `UserDef.diffAgainstCurrent(_:)`
///    驗證，**不**呼叫 `importFromExchangeJSON(_:)`——後者會寫入 `UserDefaults`，在共用行程內
///    的測試之間會互相污染。逐鍵之接受條件與失敗字串兩條路徑完全相同，故驗證力不受影響。
///
/// fixture 之定位以 `#filePath`（編譯期之原始碼路徑）為錨，故**無須**改動任何 `Package.swift`、
/// 亦不必把 fixture 納入資源 bundle。
@Suite(.serialized)
struct AssistantContractTests {
  /// 助手之 fixture 目錄。
  static var fixtureDirectory: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent() // SettingsUITests
      .deletingLastPathComponent() // Tests
      .deletingLastPathComponent() // vChewing_SettingsUI
      .deletingLastPathComponent() // Packages
      .deletingLastPathComponent() // vChewing-macOS
      .appendingPathComponent("ValueAdd/WebConfigAssistant/tests/fixtures")
  }

  static var fixtureURLs: [URL] {
    let contents = (try? FileManager.default.contentsOfDirectory(
      at: fixtureDirectory, includingPropertiesForKeys: nil
    )) ?? []
    return contents
      .filter { $0.pathExtension == "json" }
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  @Test("助手之 fixture 目錄存在且非空")
  func fixtureDirectoryIsPresent() {
    #expect(FileManager.default.fileExists(atPath: Self.fixtureDirectory.path))
    #expect(!Self.fixtureURLs.isEmpty)
  }

  @Test("助手產出之配置包，唯音一概收得下（逐鍵皆不被拒）")
  func assistantFixturesAreAccepted() throws {
    for url in Self.fixtureURLs {
      let data = try Data(contentsOf: url)
      let jsonObject = try JSONSerialization.jsonObject(with: data)
      let root = try #require(jsonObject as? [String: Any], "\(url.lastPathComponent)：根層不是辭典")

      // 中介辭典須存在、且無警告（＝形狀正常、成員皆為 String、未觸及 512 字元上限）。
      let destructured = UserDef.destructureExchange(root)
      let meta = try #require(destructured.meta, "\(url.lastPathComponent)：缺中介辭典")
      #expect(meta.warnings.isEmpty, "\(url.lastPathComponent)：中介辭典有警告 \(meta.warnings)")
      #expect(!(meta.title ?? "").isEmpty, "\(url.lastPathComponent)：缺 title")
      #expect(!(meta.description ?? "").isEmpty, "\(url.lastPathComponent)：缺 description")

      // 逐鍵驗證：凡助手輸出者，唯音皆須接受。
      let diff = UserDef.diffAgainstCurrent(destructured.payload)
      #expect(
        diff.result.failures.isEmpty,
        "\(url.lastPathComponent)：有被拒之鍵 \(diff.result.failures)"
      )
      #expect(diff.result.successes.count == destructured.payload.count)
      #expect(!destructured.payload.isEmpty, "\(url.lastPathComponent)：payload 為空")
    }
  }

  @Test("助手產出之配置包不含黑名單鍵、亦不殘留保留前綴")
  func assistantFixturesCarryNoReservedKeys() throws {
    for url in Self.fixtureURLs {
      let data = try Data(contentsOf: url)
      let jsonObject = try JSONSerialization.jsonObject(with: data)
      let root = try #require(jsonObject as? [String: Any])
      for key in root.keys {
        #expect(
          !key.hasPrefix(UserDef.jsonExchangeReservedKeyPrefix) ||
            key == UserDef.jsonExchangeMetaKey,
          "\(url.lastPathComponent)：殘留保留鍵 \(key)"
        )
        #expect(
          UserDef(rawValue: key) != nil || key == UserDef.jsonExchangeMetaKey,
          "\(url.lastPathComponent)：未知鍵 \(key)"
        )
        if let userDef = UserDef(rawValue: key) {
          #expect(
            !UserDef.jsonExchangeBlacklist.contains(userDef),
            "\(url.lastPathComponent)：含黑名單鍵 \(key)"
          )
        }
      }
      // 助手不得輸出「空包」卻又自稱有內容：payload 至少一項。
      let destructured = UserDef.destructureExchange(root)
      #expect(!destructured.payload.isEmpty)
    }
  }

  @Test("助手之題庫不觸及黑名單鍵（以 fixture 之鍵集反推）")
  func assistantNeverTouchesBlacklistedKeys() throws {
    var allKeys = Set<String>()
    for url in Self.fixtureURLs {
      let data = try Data(contentsOf: url)
      let jsonObject = try JSONSerialization.jsonObject(with: data)
      let root = try #require(jsonObject as? [String: Any])
      allKeys.formUnion(root.keys)
    }
    let blacklistedRawValues = Set(UserDef.jsonExchangeBlacklist.map(\.rawValue))
    #expect(allKeys.intersection(blacklistedRawValues).isEmpty)
  }
}
