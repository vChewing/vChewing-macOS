// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Darwin
import Foundation
@testable import InstallerAssembly
import Testing

@Suite(.serialized)
struct RelocationDetectorTests {
  @Test
  func testPathContainingAppTranslocationDetected() {
    let path = "/private/var/folders/xx/AppTranslocation/abcd/MyApp.app"
    #expect(Reloc.isAppBundleTranslocated(atPath: path))
  }

  @Test
  func testNoTranslocationForNormalPath() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temp) }

    #expect(!Reloc.isAppBundleTranslocated(atPath: temp.path))
  }

  @Test
  func testConservativeModeDetectsQuarantineXattr() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    defer {
      // remove xattr and directory
      removexattr(temp.path, "com.apple.quarantine", 0)
      try? FileManager.default.removeItem(at: temp)
    }

    // set quarantine xattr
    let value = "0001;00000000;Test;".data(using: .utf8)!
    _ = value.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
      setxattr(temp.path, "com.apple.quarantine", ptr.baseAddress, value.count, 0, 0)
    }

    #expect(Reloc.isAppBundleTranslocated(atPath: temp.path, conservative: true))
    #expect(!Reloc.isAppBundleTranslocated(atPath: temp.path, conservative: false))
  }
}
