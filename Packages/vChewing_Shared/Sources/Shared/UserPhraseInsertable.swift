// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

// MARK: - UserPhraseInsertable

public struct UserPhraseInsertable: Hashable {
  // MARK: Lifecycle

  public init(
    keyArray: [String],
    value: String,
    inputMode: Shared.InputMode,
    isConverted: Bool = false,
    weight: Double? = nil
  ) {
    self.keyArray = keyArray
    self.value = value
    self.inputMode = inputMode
    self.isConverted = isConverted
    self.weight = weight
  }

  // MARK: Public

  public let keyArray: [String]
  public let value: String
  public let inputMode: Shared.InputMode
  public let isConverted: Bool
  public var weight: Double?

  public var joinedKey: String {
    keyArray.joined(separator: "-")
  }

  public var isValid: Bool {
    !keyArray.isEmpty && keyArray.filter(\.isEmpty).isEmpty && !value.isEmpty
  }

  public var isSingleCharReadingPair: Bool {
    value.count == 1 && keyArray.count == 1 && keyArray.first?.first != "_"
  }
}
