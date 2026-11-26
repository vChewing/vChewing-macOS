// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
import SwiftExtension

// MARK: - IMKHelper

public enum IMKHelper {
  public struct CarbonKeyboardLayout {
    var strName: String = ""
    var strValue: String = ""
  }

  /// 唯音有專門統計過，實際上會有差異的英數鍵盤佈局只有這幾種。
  /// 精簡成這種清單的話，不但節省 SwiftUI 的繪製壓力，也方便使用者做選擇。
  public static let arrWhitelistedKeyLayoutsASCII: [String] = {
    var results = LatinKeyboardMappings.allCases
    if #available(macOS 10.13, *) {
      results = results.filter {
        ![.qwertyUS, .qwertzGerman, .azertyFrench].contains($0)
      }
    }
    return results.map(\.rawValue)
  }()

  /// 輸入法本體之 bundle 識別碼。
  ///
  /// - Note: 不以 `Bundle.main` 代勞：`IMKHelper` 亦被安裝器行程連結，而那裡的主 bundle 是
  ///   安裝器、不是輸入法。此值與 entitlement／連線名所用者一致。
  public static let inputMethodBundleIdentifier = "org.atelierInmu.inputmethod.vChewing"

  /// 基礎鍵盤佈局選單之值域：私有佈局優先，其次為 Apple 之注音佈局與舊識別碼（僅作遷移後備）。
  ///
  /// - Important: 本表是**白名單閘門**——不入此表者不會出現在選單、亦不會被
  ///   `allowedBasicLayoutsAsTISInputSources` 收進解析集。
  public static let arrDynamicBasicKeyLayouts: [String] = [
    "com.apple.keylayout.ZhuyinBopomofo",
    "com.apple.keylayout.ZhuyinEten",
    "org.unknown.keylayout.vChewingDachen",
    "org.unknown.keylayout.vChewingSeigyou",
    "org.unknown.keylayout.vChewingFakeSeigyou",
    "org.unknown.keylayout.vChewingETen",
    "org.unknown.keylayout.vChewingIBM",
    "org.unknown.keylayout.vChewingMiTAC",
  ]

  /// 以輸入法本體之前綴推導之私有佈局識別碼。
  public static var bundledKeyLayoutIdentifiers: [String] {
    bundledKeyLayoutIdentifiers(prefix: inputMethodBundleIdentifier)
  }

  /// 唯音自帶之六個 Ukelele 佈局之「輸入法私有佈局」識別碼（P365）。
  ///
  /// 形制：六份 `.keylayout` 平鋪於 `vChewing.app/Contents/Resources/`，由 `TISRegisterInputSource`
  /// 隨輸入法一起登記；系統為私有佈局推導之識別碼即 `<bundleID>.keylayout.<佈局名去空白>`
  /// （見 `vChewing-DevLogs/Research/Phase365_PreResearch_BundledKeyLayouts.md` §2.4）。
  public static func bundledKeyLayoutIdentifiers(prefix: String) -> [String] {
    ["Dachen", "ETen", "IBM", "MiTAC", "FakeSeigyou", "Seigyou"].map { "\(prefix).keylayout.vChewing\($0)" }
  }

  /// 佈局識別碼之修復性遷移（P365）。
  ///
  /// 只做**單向**：把一度誤寫入偏好之「私有佈局識別碼」（`<bundleID>.keylayout.*`）映回鬆散檔
  /// 推導之舊識別碼——私有 ID 在**同一登入內**會令客體退回 ABC，須跨一次登入週期方可用
  /// （實測 2026-11-26）。其餘值
  /// （Apple 佈局、既有的舊識別碼、未知值）一律原樣返回：**不得**把使用者既有的舊識別碼
  /// 改寫成私有 ID，那會直接把可用的佈局換成客體認不得者。
  public static func migratedBasicKeyboardLayoutIdentifier(_ raw: String) -> String {
    let privatePrefix = "\(inputMethodBundleIdentifier).keylayout.vChewing"
    guard raw.hasPrefix(privatePrefix) else { return raw }
    let name = raw.dropFirst(privatePrefix.count)
    return "org.unknown.keylayout.vChewing\(name)"
  }
}

#if canImport(IMKSwift)

  import IMKSwift

  extension IMKHelper {
    /// 六個私有佈局之可用性摘要（供起動日誌與診斷；P365）。
    ///
    /// 大千／倚天尚有 Apple 之佈局可退，但 IBM／神通／偽精業／精業沒有——此六者若皆未登記，
    /// 客體之佈局就會靜默停在舊值，故須留一行可查。
    public static func bundledKeyLayoutAvailabilitySummary() -> String {
      let registered = Set(TISInputSource.getAllTISInputKeyboardLayoutMap().keys)
      return bundledKeyLayoutIdentifiers.map { id in
        let short = id.split(separator: ".").last.map(String.init) ?? id
        return "\(short)=\(registered.contains(id))"
      }.joined(separator: ", ")
    }

    public static var allowedAlphanumericalTISInputSources: [TISInputSource.KeyboardLayout] {
      let allTISKeyboardLayouts = TISInputSource.getAllTISInputKeyboardLayoutMap()
      return arrWhitelistedKeyLayoutsASCII.compactMap { allTISKeyboardLayouts[$0] }
    }

    public static var allowedBasicLayoutsAsTISInputSources: [TISInputSource.KeyboardLayout?] {
      let allTISKeyboardLayouts = TISInputSource.getAllTISInputKeyboardLayoutMap()
      // 為了保證清單順序，先弄幾個容器。
      var containerA: [TISInputSource.KeyboardLayout?] = []
      var containerB: [TISInputSource.KeyboardLayout?] = []
      var containerC: [TISInputSource.KeyboardLayout] = []

      let filterSet = Array(
        Set(arrWhitelistedKeyLayoutsASCII)
          .subtracting(Set(arrDynamicBasicKeyLayouts))
      )
      let matchedGroupBasic = (arrWhitelistedKeyLayoutsASCII + arrDynamicBasicKeyLayouts).compactMap {
        allTISKeyboardLayouts[$0]
      }
      matchedGroupBasic.forEach { neta in
        if filterSet.contains(neta.id) {
          containerC.append(neta)
        } else if neta.id.hasPrefix("com.apple") {
          containerA.append(neta)
        } else {
          containerB.append(neta)
        }
      }

      // 這裡的 nil 是用來讓選單插入分隔符用的。
      if !containerA.isEmpty { containerA.append(nil) }
      if !containerB.isEmpty { containerB.append(nil) }

      return containerA + containerB + containerC
    }
  }

  // MARK: - 與輸入法的具體的安裝過程有關的命令

  extension IMKHelper {
    @discardableResult
    public static func registerInputMethod() -> Int32 {
      TISInputSource.registerInputMethod() ? 0 : -1
    }
  }

#endif
