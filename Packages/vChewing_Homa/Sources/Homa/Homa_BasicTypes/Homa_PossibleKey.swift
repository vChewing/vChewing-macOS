// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Homa.PossibleKey

extension Homa {
  /// 代表組字器某一個位置的所有可能讀音。
  ///
  /// 用來取代語意模糊的 `[[String]]`，讓單一讀音與多讀音候選在型別層級就有區分。
  public enum PossibleKey: Hashable, Sendable {
    case singleKey(String)
    case multipleKeys([String])

    // MARK: Public

    /// 該鍵是否有效（不為空）。
    public var isValid: Bool {
      switch self {
      case let .singleKey(keyStr):
        return !keyStr.isEmpty
      case let .multipleKeys(possibleKeys):
        return !possibleKeys.isEmpty
      }
    }

    /// 回傳所有可能的讀音值。
    ///
    /// 對 `singleKey` 回傳單元素陣列；
    /// 對 `multipleKeys` 回傳其內容（若為空則回傳防呆字元）。
    public var allValues: [String] {
      switch self {
      case let .singleKey(keyStr):
        return [keyStr]
      case let .multipleKeys(possibleKeys):
        if possibleKeys.isEmpty {
          return [Self.pokayokeChar]
        }
        return possibleKeys
      }
    }

    /// 回傳第一個讀音值（作為代表值）。
    ///
    /// 對 `singleKey` 回傳該字串本身；
    /// 對 `multipleKeys` 回傳第一個元素（若為空則回傳防呆字元）。
    public var first: String {
      switch self {
      case let .singleKey(keyStr):
        return keyStr
      case let .multipleKeys(possibleKeys):
        return possibleKeys.first ?? Self.pokayokeChar
      }
    }

    /// 回傳該鍵包含的可能讀音數量。
    ///
    /// 對 `singleKey` 回傳 1；
    /// 對 `multipleKeys` 回傳其內容數量。
    public var count: Int {
      switch self {
      case .singleKey: return 1
      case let .multipleKeys(possibleKeys): return possibleKeys.count
      }
    }

    /// 該鍵是否包含多個可能讀音（即為 `multipleKeys` 且數量大於 1）。
    public var isMultiple: Bool {
      count > 1
    }

    // MARK: Private

    private static let pokayokeChar = "🛇"
  }
}

// MARK: - Homa.PossibleKey + Codable

extension Homa.PossibleKey: Codable {
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    // 先嘗試解碼為 String Array；若只有一個元素則視為 singleKey。
    if let array = try? container.decode([String].self) {
      if array.count == 1, let first = array.first {
        self = .singleKey(first)
      } else {
        self = .multipleKeys(array)
      }
      return
    }
    let string = try container.decode(String.self)
    self = .singleKey(string)
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .singleKey(keyStr):
      try container.encode(keyStr)
    case let .multipleKeys(possibleKeys):
      try container.encode(possibleKeys)
    }
  }
}
