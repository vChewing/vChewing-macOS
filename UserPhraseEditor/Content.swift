// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Cocoa
import Foundation

class Content: NSObject {
  @objc dynamic var contentString = ""

  public init(contentString: String) {
    self.contentString = contentString
  }
}

extension Content {
  func read(from data: Data) {
    contentString = String(bytes: data, encoding: .utf8)!
  }

  func data() -> Data? {
    contentString.data(using: .utf8)
  }
}
