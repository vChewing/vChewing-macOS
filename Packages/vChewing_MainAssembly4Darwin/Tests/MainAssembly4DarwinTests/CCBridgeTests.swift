// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Shared
import Testing

@testable import MainAssembly4Darwin

// MARK: - CCBridgeTests

/// 步天歌繁簡／康熙轉換橋接（`ChineseConverter` 於 Darwin 宿主的擴充）單元測試。
///
/// 該橋接的資料源是隨 App bundle 出貨的 `convdict.stringmap`；使用者若啟用「外部原廠辭典」，
/// 路徑會改走容器、內容未必與出貨版本一致——故本測試於執行期間顯式關閉該偏好，
/// 使斷言對象恆為出貨資料。轉換器本身是行程級的惰性單例，故本 Suite 不再另行重設全域狀態。
@Suite(.serialized)
final class CCBridgeTests {
  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.MainAssembly.UnitTests")
  }

  // MARK: Internal

  /// 康熙轉換的「一對多」攔截與字詞消歧：
  /// - 單字「才／參／核」直接原樣返回（各具多義，字典不再無條件取單一義項）。
  /// - 字詞層：常見義項詞（天才／參加／核心）維持原字；罕見義項詞（剛才／人參／核實）
  ///   仍轉古典字形（剛纔／人蔘／覈實）。
  /// - 對照組：異體字正寫（為→爲、吃→喫）仍正常轉換、資料庫仍生效。
  @Test
  func test506_KangXiConversionKeepsSingleCaiAsIs() throws {
    let prefs = PrefMgr.sharedSansDidSetOps
    let originalUseExternalFactoryDict = prefs.useExternalFactoryDict
    prefs.useExternalFactoryDict = false
    defer { prefs.useExternalFactoryDict = originalUseExternalFactoryDict }

    // 單字攔截
    #expect(ChineseConverter.cnvTradToKangXi("才") == "才")
    #expect(ChineseConverter.cnvTradToKangXi("參") == "參")
    #expect(ChineseConverter.cnvTradToKangXi("核") == "核")
    // 字詞層：常見義項維持原字（語料已移除破壞性單字對映）
    #expect(ChineseConverter.cnvTradToKangXi("天才") == "天才")
    #expect(ChineseConverter.cnvTradToKangXi("參加") == "參加")
    #expect(ChineseConverter.cnvTradToKangXi("核心") == "核心")
    // 字詞層：罕見義項仍轉古典字形（語料補消歧條目）
    #expect(ChineseConverter.cnvTradToKangXi("剛才") == "剛纔")
    #expect(ChineseConverter.cnvTradToKangXi("人參") == "人蔘")
    #expect(ChineseConverter.cnvTradToKangXi("核實") == "覈實")
    // 對照組：異體字正寫與資料庫仍生效
    #expect(ChineseConverter.cnvTradToKangXi("為") == "爲")
    #expect(ChineseConverter.cnvTradToKangXi("吃") == "喫")
  }
}
