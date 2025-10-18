// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
