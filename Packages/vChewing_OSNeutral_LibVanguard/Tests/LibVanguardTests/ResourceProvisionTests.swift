// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import LibVanguard
@testable import ResourceLocator
import Testing

// MARK: - ResourceProvisionAnchor

/// 查找器的錨定型別。
private final class ResourceProvisionAnchor {}

// MARK: - LibVanguardTestsRoot.ResourceProvisionTests

// 歸入本測試目標唯一根 suite（見 `LibVanguardTests_Root.swift`）；各 suite 自持 `TestEnvironment`（P316），故可並行。
extension LibVanguardTestsRoot {
  @Suite("ResourceProvisionTests")
  struct ResourceProvisionTests {
    @Test("[ResourceProvision] BundledResourcesAreAvailable")
    func testBundledResourcesAreAvailable() {
      let report = ResourceProvision.availabilityReport()
      #expect(
        report.keys.sorted() == [
          "BPMFVS.phonic_table_Z",
          "PunctuationData.pairedEntries",
          "PunctuationData.records",
        ]
      )
      #expect(report.values.allSatisfy { $0 })
    }

    /// 生產碼不得使用 SwiftPM 自動生成的 `Bundle.module`。
    ///
    /// 該 accessor 於 Swift 5.10 只探「`Bundle.main.bundleURL` ＋ 資源 bundle 名」與建置機上
    /// 那條絕對路徑；資源 bundle 實際住在 `.app/Contents/Resources/`，故換一台機器啟動即
    /// `fatalError`（5.10 legacy 之輸入法因此完全無法啟動）。資源查找一律走 `ResourceLocator`。
    @Test("[ResourceProvision] ShippingSourcesAvoidBundleModule")
    func testShippingSourcesAvoidBundleModule() throws {
      let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // LibVanguardTests/
        .deletingLastPathComponent() // Tests/
        .deletingLastPathComponent() // 套件根
      let sourcesRoot = packageRoot.appendingPathComponent("Sources")
      let enumerator = try #require(
        FileManager.default.enumerator(
          at: sourcesRoot, includingPropertiesForKeys: [.isRegularFileKey]
        )
      )
      var offenders = [String]()
      for case let url as URL in enumerator where url.pathExtension == "swift" {
        // 測試素材目標不在出貨閉包內：其 `Bundle.module` 只為載入測試資料。
        guard !url.pathComponents.contains("LXAssemblyMaterials4Tests") else { continue }
        let text = try String(contentsOf: url, encoding: .utf8)
        for line in text.split(whereSeparator: \.isNewline) {
          let trimmed = line.trimmingCharacters(in: .whitespaces)
          guard !trimmed.hasPrefix("//") else { continue }
          guard trimmed.contains("Bundle.module") else { continue }
          offenders.append(url.lastPathComponent)
        }
      }
      #expect(offenders.isEmpty, "生產碼不得使用 `Bundle.module`：\(offenders.sorted())")
    }

    @Test("[ResourceProvision] MissingResourceReturnsNilWithoutTrapping")
    func testMissingResourceReturnsNilWithoutTrapping() {
      #expect(
        ResourceLocator.resourceBundle(named: "NoSuchPackage_NoSuchTarget", anchor: ResourceProvisionAnchor.self)
          == nil
      )
      #expect(
        ResourceLocator.url(
          forResource: "no_such_resource_114514",
          withExtension: "txt",
          inSwiftPMResourceBundleNamed: "NoSuchPackage_NoSuchTarget",
          anchor: ResourceProvisionAnchor.self
        ) == nil
      )
    }

    @Test("[ResourceProvision] BPMFVSTableSpecificationIsForwarded")
    func testBPMFVSTableSpecificationIsForwarded() throws {
      ResourceProvision.clearAllSpecifications()
      defer { ResourceProvision.clearAllSpecifications() }
      // 指定成預設查找本來就會命中的那條路徑：對並行執行的其他測試無實質擾動。
      let bundledURL = try #require(BPMFVS.getBPMFVSDataURL())
      ResourceProvision.specifyBPMFVSTable(bundledURL)
      #expect(BPMFVS.dataURLOverride == bundledURL)
      #expect(BPMFVS.getBPMFVSDataURL() == bundledURL)
      ResourceProvision.clearAllSpecifications()
      #expect(BPMFVS.dataURLOverride == nil)
      #expect(BPMFVS.getBPMFVSDataURL() == bundledURL)
    }

    @Test("[ResourceProvision] ResourceRootAndBundleSpecificationsAreForwarded")
    func testResourceRootAndBundleSpecificationsAreForwarded() throws {
      // 這組設定是全域名狀態，需整段獨佔：否則並行執行的別支用例會把設定清掉。
      try ResourceLocator.withTemporarySpecifications {
        let probeRoot = URL(fileURLWithPath: "/nonexistent-vChewing/resource-root")
        ResourceProvision.specifyResourceRoot(probeRoot)
        #expect(ResourceLocator.resourceRootURL == probeRoot)
        ResourceProvision.specifyResourceBundle(probeRoot, forBundleNamed: "ProbeBundle")
        #expect(ResourceLocator.specifiedResourceBundleURL(forBundleNamed: "ProbeBundle") == probeRoot)
        ResourceProvision.clearAllSpecifications()
        #expect(ResourceLocator.resourceRootURL == nil)
        #expect(ResourceLocator.specifiedResourceBundleURL(forBundleNamed: "ProbeBundle") == nil)
      }
    }
  }
}
