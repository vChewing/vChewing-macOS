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
import XCTest

final class RelocationDetectorTests: XCTestCase {
  func testPathContainingAppTranslocationDetected() {
    let path = "/private/var/folders/xx/AppTranslocation/abcd/MyApp.app"
    XCTAssertTrue(Reloc.isAppBundleTranslocated(atPath: path))
  }

  func testNoTranslocationForNormalPath() throws {
    let temp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: temp, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temp) }

    XCTAssertFalse(Reloc.isAppBundleTranslocated(atPath: temp.path))
  }

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

    XCTAssertTrue(Reloc.isAppBundleTranslocated(atPath: temp.path, conservative: true))
    XCTAssertFalse(Reloc.isAppBundleTranslocated(atPath: temp.path, conservative: false))
  }
}
