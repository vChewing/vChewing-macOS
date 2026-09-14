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

@Suite("ResourceLocatorTests", .serialized)
struct ResourceLocatorTests {
  // MARK: Internal

  @Test("[ResourceLocator] OwnResourceBundleIsFound")
  func testFindsOwnResourceBundle() throws {
    ResourceLocator.clearSpecifiedResources()
    let bundle = try #require(
      ResourceLocator.resourceBundle(named: Self.ownBundleName, anchor: ResourceLocatorAnchor.self)
    )
    let url = try #require(bundle.url(forResource: "ResourceLocatorFixture", withExtension: "txt"))
    #expect(try String(contentsOf: url, encoding: .utf8).contains("ResourceLocator fixture"))
  }

  @Test("[ResourceLocator] ResourceIsFoundThroughSwiftPMBundleName")
  func testFindsResourceThroughSwiftPMBundleName() throws {
    ResourceLocator.clearSpecifiedResources()
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

  @Test("[ResourceLocator] MissingResourceReturnsNilInsteadOfTrapping")
  func testMissingResourceReturnsNil() {
    ResourceLocator.clearSpecifiedResources()
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

  @Test("[ResourceLocator] ManualBundleSpecificationTakesPrecedence")
  func testManualBundleSpecificationTakesPrecedence() throws {
    ResourceLocator.clearSpecifiedResources()
    defer { ResourceLocator.clearSpecifiedResources() }
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

  @Test("[ResourceLocator] BundleInSpecifiedRootDirectoryIsFound")
  func testBundleInSpecifiedRootDirectoryIsFound() throws {
    ResourceLocator.clearSpecifiedResources()
    defer { ResourceLocator.clearSpecifiedResources() }
    let scratchURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("ResourceLocatorTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: scratchURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: scratchURL) }
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

  @Test("[ResourceLocator] ClearingSpecificationsRestoresLayoutDerivation")
  func testClearingSpecificationsRestoresLayoutDerivation() throws {
    ResourceLocator.clearSpecifiedResources()
    defer { ResourceLocator.clearSpecifiedResources() }
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

  // MARK: Private

  private static let ownBundleName = "LibVanguard_ResourceLocatorTests"
  private static let aliasBundleName = "AliasedProbeBundle"
  private static let relocatedBundleName = "RelocatedProbeBundle"
  private static let clearedBundleName = "ClearedProbeBundle"
}
