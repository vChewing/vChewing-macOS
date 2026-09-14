// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
@testable import LibVanguard
import ResourceLocator
import Testing

// MARK: - ResourceProvisionAnchor

/// 查找器的錨定型別。
private final class ResourceProvisionAnchor {}

// MARK: - ResourceProvisionTests

@Suite("ResourceProvisionTests", .serialized)
struct ResourceProvisionTests {
  @Test("[ResourceProvision] BundledResourcesAreAvailable")
  func testBundledResourcesAreAvailable() {
    #expect(ResourceProvision.availabilityReport() == ["BPMFVS.phonic_table_Z": true])
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
    ResourceProvision.clearAllSpecifications()
    defer { ResourceProvision.clearAllSpecifications() }
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
