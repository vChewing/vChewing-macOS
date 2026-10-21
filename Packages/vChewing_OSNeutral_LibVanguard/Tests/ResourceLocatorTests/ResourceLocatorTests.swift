// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation
@testable import ResourceLocator
import Testing

// MARK: - ResourceLocatorAnchor

/// 查找器的錨定型別。查找邏輯會由它推得編譯產物所在位置。
private final class ResourceLocatorAnchor {}

// MARK: - ResourceLocatorTests

/// 資源查找器之測試。
///
/// 查找設定是全域名狀態，而測試預設並行執行：別的用例一旦在「設定好、還沒查」之間呼叫
/// `clearSpecifiedResources()`，查詢就會落空。故每個用例都圈進
/// `withTemporarySpecifications(_:)`，讓整段設定與查詢獨佔該狀態。
@Suite("ResourceLocatorTests")
struct ResourceLocatorTests {
  // MARK: Internal

  @Test("[ResourceLocator] OwnResourceBundleIsFound")
  func testFindsOwnResourceBundle() throws {
    try ResourceLocator.withTemporarySpecifications {
      let bundle = try #require(
        ResourceLocator.resourceBundle(named: Self.ownBundleName, anchor: ResourceLocatorAnchor.self)
      )
      let url = try #require(bundle.url(forResource: "ResourceLocatorFixture", withExtension: "txt"))
      #expect(try String(contentsOf: url, encoding: .utf8).contains("ResourceLocator fixture"))
    }
  }

  @Test("[ResourceLocator] ResourceIsFoundThroughSwiftPMBundleName")
  func testFindsResourceThroughSwiftPMBundleName() throws {
    try ResourceLocator.withTemporarySpecifications {
      let url = try #require(
        ResourceLocator.url(
          forResource: "ResourceLocatorFixture",
          withExtension: "txt",
          inSwiftPMResourceBundleNamed: Self.ownBundleName,
          anchor: ResourceLocatorAnchor.self
        )
      )
      #expect(url.lastPathComponent == "ResourceLocatorFixture.txt")
    }
  }

  @Test("[ResourceLocator] MissingResourceReturnsNilInsteadOfTrapping")
  func testMissingResourceReturnsNil() {
    ResourceLocator.withTemporarySpecifications {
      #expect(
        ResourceLocator.resourceBundle(named: "NoSuchPackage_NoSuchTarget", anchor: ResourceLocatorAnchor.self)
          == nil
      )
      #expect(
        ResourceLocator.url(
          forResource: "no_such_resource_114514",
          withExtension: "txt",
          inSwiftPMResourceBundleNamed: "NoSuchPackage_NoSuchTarget",
          anchor: ResourceLocatorAnchor.self
        ) == nil
      )
    }
  }

  @Test("[ResourceLocator] ManualBundleSpecificationTakesPrecedence")
  func testManualBundleSpecificationTakesPrecedence() throws {
    try ResourceLocator.withTemporarySpecifications {
      let ownBundleURL = try #require(
        ResourceLocator.resourceBundle(named: Self.ownBundleName, anchor: ResourceLocatorAnchor.self)?.bundleURL
      )
      // 直接把某個資源 bundle 掛到另一個名稱之下：宿主無須讓資源 bundle 的實際名稱與
      // 呼叫端硬編的名字一致。
      ResourceLocator.specifyResourceBundleURL(ownBundleURL, forBundleNamed: Self.aliasBundleName)
      #expect(ResourceLocator.specifiedResourceBundleURL(forBundleNamed: Self.aliasBundleName) != nil)
      let url = try #require(
        ResourceLocator.url(
          forResource: "ResourceLocatorFixture",
          withExtension: "txt",
          inSwiftPMResourceBundleNamed: Self.aliasBundleName,
          anchor: ResourceLocatorAnchor.self
        )
      )
      #expect(url.lastPathComponent == "ResourceLocatorFixture.txt")
    }
  }

  @Test("[ResourceLocator] BundleInSpecifiedRootDirectoryIsFound")
  func testBundleInSpecifiedRootDirectoryIsFound() throws {
    let scratchURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("ResourceLocatorTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: scratchURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: scratchURL) }
    try ResourceLocator.withTemporarySpecifications {
      let ownBundleURL = try #require(
        ResourceLocator.resourceBundle(named: Self.ownBundleName, anchor: ResourceLocatorAnchor.self)?.bundleURL
      )
      try FileManager.default.copyItem(
        at: ownBundleURL,
        to: scratchURL.appendingPathComponent("\(Self.relocatedBundleName).bundle")
      )
      ResourceLocator.resourceRootURL = scratchURL
      let url = try #require(
        ResourceLocator.url(
          forResource: "ResourceLocatorFixture",
          withExtension: "txt",
          inSwiftPMResourceBundleNamed: Self.relocatedBundleName,
          anchor: ResourceLocatorAnchor.self
        )
      )
      #expect(url.path.hasPrefix(scratchURL.path))
    }
  }

  @Test("[ResourceLocator] ClearingSpecificationsRestoresLayoutDerivation")
  func testClearingSpecificationsRestoresLayoutDerivation() throws {
    try ResourceLocator.withTemporarySpecifications {
      let ownBundleURL = try #require(
        ResourceLocator.resourceBundle(named: Self.ownBundleName, anchor: ResourceLocatorAnchor.self)?.bundleURL
      )
      ResourceLocator.specifyResourceBundleURL(
        ownBundleURL.deletingLastPathComponent(),
        forBundleNamed: Self.clearedBundleName
      )
      #expect(
        ResourceLocator.resourceBundle(named: Self.clearedBundleName, anchor: ResourceLocatorAnchor.self) != nil
      )
      ResourceLocator.clearSpecifiedResources()
      #expect(
        ResourceLocator.resourceBundle(named: Self.clearedBundleName, anchor: ResourceLocatorAnchor.self) == nil
      )
    }
  }

  // MARK: Private

  private static let ownBundleName = "LibVanguard_ResourceLocatorTests"
  private static let aliasBundleName = "AliasedProbeBundle"
  private static let relocatedBundleName = "RelocatedProbeBundle"
  private static let clearedBundleName = "ClearedProbeBundle"
}
