// (c) 2022 and onwards The vChewing Project (MulanPSL-2.0 License).
// ====================
// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.

import Foundation

public enum OS {
  public static let currentOSVersionString: String = {
    if #available(macOS 10.10, *) {
      let strSet = ProcessInfo().operatingSystemVersion
      return "\(strSet.majorVersion).\(strSet.minorVersion).\(strSet.patchVersion)"
    }
    let strSet = ProcessInfo().operatingSystemVersionString.components(separatedBy: " ")
    guard strSet.count >= 2 else { return "10.9.0" }
    return strSet[1]
  }()

  public static func ifAvailable(_ givenOSVersion: Double) -> Bool {
    let rawResult = currentOSVersionString.versionCompare(givenOSVersion.description)
    return [.orderedDescending].contains(rawResult)
  }

  public static func ifUnavailable(_ givenOSVersion: Double) -> Bool {
    let rawResult = currentOSVersionString.versionCompare(givenOSVersion.description)
    return [.orderedSame, .orderedAscending].contains(rawResult)
  }
}
