// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

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
