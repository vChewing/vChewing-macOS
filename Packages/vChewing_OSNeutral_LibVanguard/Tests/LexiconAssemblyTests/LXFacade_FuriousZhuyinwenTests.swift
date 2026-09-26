// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import LXAssemblyMaterials4Tests
import Shared
import Testing

@testable import LexiconAssembly

/// 狂打（Furious Typing）啟用時抑制原廠注音文（zhuyinwen）資料的行為測試。
/// 測試樣本（vanguardTextMap_test.txtMap）中，讀音「ㄋㄟ-ㄋㄟ」的唯一注音文
/// 條目為「ㄋㄟㄋㄟ」（type 10）。
///
/// - Important: 本檔之測試分兩類。第一類（兩支既有靶）以 `setOptions` **直接驅動 config**，
///   驗的是「旗標為真即抑制」這條下游語義；第二類（四態與熱鍵）**必須經 `syncPrefs()`**，
///   因為它們驗的正是「偏好 → 旗標」這條上游推導——直接寫 config 會使它們恆真而失去意義。
@Suite(.serialized)
struct LXFacadeFuriousZhuyinwenTests {
  // MARK: Internal

  @Test
  func testFactoryZhuyinwenPresentByDefault() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: true)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )
    // 未啟用狂拼時，原廠注音文（ㄋㄟㄋㄟ）應照常供應。
    #expect(instance.unigramsFor(keyArray: Self.boobsKey).contains { $0.current == "ㄋㄟㄋㄟ" })
  }

  @Test
  func testFuriousTypingSuppressesFactoryZhuyinwen() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: true)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )
    instance.setOptions { config in
      config.shouldSuppressFactoryZhuyinwenData = true
    }
    // 狂拼啟用時，來自原廠辭典（TextMapTrie）的注音文資料應被抑制。
    #expect(!instance.unigramsFor(keyArray: Self.boobsKey).contains { $0.current == "ㄋㄟㄋㄟ" })
  }

  /// 四態：抑制旗標 ＝「**當前打字方式所屬那一側**之狂打開關」。
  ///
  /// 枚舉 `pinyinTypingEnabled` × 兩顆狂打開關之全部 8 種組合，逐組驗兩件事：
  /// ① `syncPrefs()` 寫入 config 之值即析取式之期望值；② 該值確實反映到查詢結果
  /// （注音文「ㄋㄟㄋㄟ」在抑制時不得出現）——只驗 ① 不足以證明旗標接得上下游。
  @Test
  func testZhuyinwenSuppressionTruthTableOverBothFuriousSwitches() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: true)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    Self.withIsolatedPrefs {
      for isPinyin in [true, false] {
        for furious4Pinyin in [true, false] {
          for furious4Zhuyin in [true, false] {
            let prefs = PrefMgr.sharedSansDidSetOps
            prefs.pinyinTypingEnabled = isPinyin
            prefs.furiousTypingEnabled4Pinyin = furious4Pinyin
            prefs.furiousTypingEnabled4Zhuyin = furious4Zhuyin
            instance.syncPrefs()

            let expected = (isPinyin && furious4Pinyin) || (!isPinyin && furious4Zhuyin)
            let context = """
            拼音打字＝\(isPinyin)、狂拼＝\(furious4Pinyin)、狂注＝\(furious4Zhuyin)
            """
            #expect(
              instance.config.shouldSuppressFactoryZhuyinwenData == expected,
              "旗標不符：\(context)"
            )
            let hasZhuyinwen = instance.unigramsFor(keyArray: Self.boobsKey)
              .contains { $0.current == "ㄋㄟㄋㄟ" }
            #expect(hasZhuyinwen != expected, "查詢結果不符：\(context)")
          }
        }
      }
    }
  }

  /// 打字方式熱鍵（`⌃⌘J`）之效果須在**下一拍**即反映：該熱鍵只改
  /// `pinyinTypingEnabled`（兩顆鍵盤排列槽不動），而 `syncPrefs()` 於每一次分診之
  /// 頂端執行 ⇒「切換後之下一拍」即「下一次 `syncPrefs()`」。
  ///
  /// 測資刻意令兩側狂打開關**相反**，使抑制旗標必然隨熱鍵反向翻轉——若實作誤把
  /// 「當前打字方式」換成別的判準（或只看拼音側），本靶即轉紅。
  @Test
  func testZhuyinwenSuppressionFollowsTypingModeHotKeyOnNextBeat() throws {
    defer {
      LXAssembly.LXFacade.disconnectFactoryDictionary()
    }

    let instance = LXAssembly.LXFacade(isCHS: true)
    #expect(
      LXAssembly.LXFacade
        .connectToTestFactoryDictionary(textMapData: LXATestsData.textMapTestCoreLXData)
    )

    Self.withIsolatedPrefs {
      let prefs = PrefMgr.sharedSansDidSetOps
      let parser4PinyinSaved = prefs.keyboardParser4Pinyin
      let parser4ZhuyinSaved = prefs.keyboardParser4Zhuyin
      defer {
        prefs.keyboardParser4Pinyin = parser4PinyinSaved
        prefs.keyboardParser4Zhuyin = parser4ZhuyinSaved
      }

      // 拼音側狂打關、注音側狂打開 ⇒ 抑制旗標應隨「當前打字方式」反向。
      prefs.furiousTypingEnabled4Pinyin = false
      prefs.furiousTypingEnabled4Zhuyin = true

      prefs.pinyinTypingEnabled = true
      instance.syncPrefs() // ＝下一拍之分診頂端。
      #expect(!instance.config.shouldSuppressFactoryZhuyinwenData)
      #expect(instance.unigramsFor(keyArray: Self.boobsKey).contains { $0.current == "ㄋㄟㄋㄟ" })

      // 熱鍵：只切換打字方式，不動兩顆鍵盤排列槽。
      prefs.pinyinTypingEnabled.toggle()
      #expect(!prefs.pinyinTypingEnabled)
      #expect(prefs.keyboardParser4Pinyin == parser4PinyinSaved)
      #expect(prefs.keyboardParser4Zhuyin == parser4ZhuyinSaved)
      instance.syncPrefs() // ＝切換後之下一拍。
      #expect(instance.config.shouldSuppressFactoryZhuyinwenData)
      #expect(!instance.unigramsFor(keyArray: Self.boobsKey).contains { $0.current == "ㄋㄟㄋㄟ" })

      // 反向再切一次：旗標須即時回復。
      prefs.pinyinTypingEnabled.toggle()
      instance.syncPrefs()
      #expect(!instance.config.shouldSuppressFactoryZhuyinwenData)
      #expect(instance.unigramsFor(keyArray: Self.boobsKey).contains { $0.current == "ㄋㄟㄋㄟ" })
    }
  }

  // MARK: Private

  private static let boobsKey: [String] = ["ㄋㄟ", "ㄋㄟ"]

  /// 於**隔離之偏好容器**內執行給定操作：以專用 suite 為 `UserDefaults.current`、
  /// 清空全部 `UserDef`（故各偏好回取出廠預設），事後還原容器與 `pendingUnitTests`。
  ///
  /// 之所以必要：`PrefMgr.sharedSansDidSetOps` 之值即 `UserDefaults.current` 之內容
  /// （`@AppProperty` 之 get／set 逐次讀寫容器），若直接在主容器上寫入，會把測試值
  /// 留在共用容器內而汙染同行程之其他 suite（P253 之跨 suite 汙染即此型）。
  private static func withIsolatedPrefs(_ body: () throws -> ()) rethrows {
    let suiteName = "org.atelierInmu.vChewing.LexiconAssembly.UnitTests"
    let savedPendingUnitTests = UserDefaults.pendingUnitTests
    UserDefaults.unitTests = .init(suiteName: suiteName)
    UserDefaults.pendingUnitTests = true
    UserDef.resetAll()
    defer {
      UserDef.resetAll()
      UserDefaults.unitTests?.removeSuite(named: suiteName)
      UserDefaults.pendingUnitTests = savedPendingUnitTests
    }
    try body()
  }
}
