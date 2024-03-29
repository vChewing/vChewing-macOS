// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import SwiftExtension

public enum OS {
  public static let currentOSVersionString: String = {
    let strSet = ProcessInfo().operatingSystemVersion
    return "\(strSet.majorVersion).\(strSet.minorVersion).\(strSet.patchVersion)"
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
