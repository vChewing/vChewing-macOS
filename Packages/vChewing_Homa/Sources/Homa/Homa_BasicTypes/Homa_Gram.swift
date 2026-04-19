// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - Homa.Gram

extension Homa {
  /// 進階組字引擎專屬的語法單位類型，支援單元語法與雙元語法結構。
  /// - Remark: 進階組字引擎所運用的雙元語法資料 `previous` 不包含讀音資訊。
  public struct Gram: Codable, CustomStringConvertible, Equatable, Sendable, Hashable {
    // MARK: Lifecycle

    public init(_ rawTuple: GramRAW, backoff: Double = 0, id: FIUUID = .init()) {
      self.id = id
      self.keyArray = rawTuple.keyArray
      self.current = rawTuple.value
      if let previous = rawTuple.previous, !previous.isEmpty {
        self.previous = previous
      } else {
        self.previous = nil
      }
      self.probability = rawTuple.probability
      self.backoff = backoff
    }

    public init(
      keyArray: [String],
      current: String,
      previous: String? = nil,
      probability: Double = 0,
      backoff: Double = 0,
      id: FIUUID = .init()
    ) {
      self.id = id
      self.keyArray = keyArray
      if let previous, !previous.isEmpty {
        self.previous = previous
      } else {
        self.previous = nil
      }
      self.current = current
      self.probability = probability
      self.backoff = backoff
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.keyArray = try container.decode([String].self, forKey: .keyArray)
      self.current = try container.decode(String.self, forKey: .current)
      self.previous = try container.decodeIfPresent(String.self, forKey: .previous)
      self.probability = try container.decode(Double.self, forKey: .probability)
      self.backoff = try container.decode(Double.self, forKey: .backoff)
      self.id = .init()
    }

    // MARK: Public

    /// 元圖識別碼。
    public let id: FIUUID
    public let keyArray: [String]
    public let current: String
    public let previous: String?
    public let probability: Double
    public let backoff: Double // 最大單元圖機率

    public var isUnigram: Bool { previous == nil }

    public var description: String {
      describe(keySeparator: "-")
    }

    public var descriptionSansReading: String {
      guard let previous else {
        return "P(\(current))=\(probability), BOW('\(current)')=\(backoff)" // 單元圖
      }
      return "P(\(current)|\(previous))=\(probability)" // 雙元圖
    }

    public var asTuple: GramRAW {
      (
        keyArray: keyArray,
        value: current,
        probability: probability,
        previous: previous
      )
    }

    /// 檢查是否「讀音字長與候選字字長不一致」。
    public var isReadingMismatched: Bool {
      keyArray.count != current.count
    }

    /// 幅長。
    public var segLength: Int {
      keyArray.count
    }

    public static func == (lhs: Homa.Gram, rhs: Homa.Gram) -> Bool {
      lhs.keyArray == rhs.keyArray &&
        lhs.current == rhs.current &&
        lhs.previous == rhs.previous &&
        lhs.probability == rhs.probability &&
        lhs.backoff == rhs.backoff
    }

    public func describe(keySeparator: String) -> String {
      let header = "[\(isUnigram ? "Unigram" : "Bigram")]"
      let body = "'\(keyArray.joined(separator: keySeparator))', \(descriptionSansReading)"
      return "\(header) \(body)"
    }

    /// 預設雜湊函式。
    /// - Parameter hasher: 目前物件的雜湊碼。
    public func hash(into hasher: inout Hasher) {
      hasher.combine(keyArray)
      hasher.combine(current)
      hasher.combine(previous)
      hasher.combine(probability)
      hasher.combine(backoff)
    }

    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(keyArray, forKey: .keyArray)
      try container.encode(current, forKey: .current)
      try container.encodeIfPresent(previous, forKey: .previous)
      try container.encode(probability, forKey: .probability)
      try container.encode(backoff, forKey: .backoff)
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
      case keyArray = "keys"
      case current = "curr"
      case previous = "prev"
      case probability = "prob"
      case backoff = "bkof"
    }
  }
}

extension Array where Element == Homa.Gram {
  var asGramTypes: (unigrams: [Element], bigrams: [Element]) {
    reduce(into: ([Element](), [Element]())) { result, element in
      if element.isUnigram {
        result.0.append(element)
      } else {
        result.1.append(element)
      }
    }
  }

  var allBigramsMap: [String: [Element]] {
    var theMap = [String: [Element]]()
    filter { $0.previous != nil }
      .forEach { theMap[$0.previous!, default: []].append($0) }
    return theMap
  }
}
