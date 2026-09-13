// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Darwin
import Foundation
@testable import InstallerAssembly4Darwin
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
