// Swiftified by (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// Rebranded from (c) Nick Chen's Obj-C library "NCChineseConverter" (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public enum HotenkaTestDictData {
  public static let testResourceURL: URL? = {
    let url: URL?
    #if canImport(Darwin)
      if #available(macOS 12, *) {
        url = #bundle.resourceURL
      } else {
        url = Bundle.module.resourceURL
      }
    #else
      url = Bundle.module.resourceURL
    #endif
    return url
  }()
}
