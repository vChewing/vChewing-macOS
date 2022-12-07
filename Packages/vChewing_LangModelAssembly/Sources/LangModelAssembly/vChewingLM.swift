// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

public enum vChewingLM {
  enum FileErrors: Error {
    case fileHandleError(String)
  }

  public enum ReplacableUserDataType: String, CaseIterable, Identifiable {
    public var id: ObjectIdentifier { .init(rawValue as AnyObject) }

    case thePhrases
    case theFilter
    case theReplacements
    case theAssociates
    case theSymbols
  }
}
