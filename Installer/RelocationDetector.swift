// (c) 2011 and onwards Lukhnos Liu and MJHsieh.
// Swiftified by Rob Mayoff.
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import Foundation

public enum Reloc {
  // Determines if an app is translocated by Gatekeeper to a randomized path.
  // See https://weblog.rogueamoeba.com/2016/06/29/sierra-and-gatekeeper-path-randomization/
  // Originally written by MJHsieh and Lukhnos Liu in Objective-C (MIT License).
  // Swiftified by: Rob Mayoff. Ref: https://forums.swift.org/t/58719/5
  public static func isAppBundleTranslocated(atPath bundlePath: String) -> Bool {
    var entryCount = getfsstat(nil, 0, 0)
    var entries: [statfs] = .init(repeating: .init(), count: Int(entryCount))
    let absPath = bundlePath.cString(using: .utf8)
    entryCount = getfsstat(&entries, entryCount * Int32(MemoryLayout<statfs>.stride), MNT_NOWAIT)
    for entry in entries.prefix(Int(entryCount)) {
      let isMatch = withUnsafeBytes(of: entry.f_mntfromname) { mntFromName in
        strcmp(absPath, mntFromName.baseAddress) == 0
      }
      if isMatch {
        var stat = statfs()
        let rc = statfs(absPath, &stat)
        return rc == 0
      }
    }
    return false
  }
}
