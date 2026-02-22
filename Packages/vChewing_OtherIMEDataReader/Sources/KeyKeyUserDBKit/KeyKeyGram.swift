// (c) 2025 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

// MARK: - KeyKeyUserDBKit.Gram

extension KeyKeyUserDBKit {
  /// This is the basic Gram type extracted from our Homa Assembler with no backoff support.
  public struct KeyKeyGram: Codable, CustomStringConvertible, Equatable, Sendable, Hashable {
    // MARK: Lifecycle

    /// 從原始元組初始化 Gram
    /// - Parameters:
    ///   - rawTuple: 原始資料元組
    ///   - isCandidateOverride: 是否為候選字覆蓋記錄
    public init(_ rawTuple: GramRAW, isCandidateOverride: Bool = false) {
      self.keyArray = rawTuple.keyArray
      self.current = rawTuple.value
      if let previous = rawTuple.previous, !previous.isEmpty {
        self.previous = previous
      } else {
        self.previous = nil
      }
      self.probability = rawTuple.probability
      self.isCandidateOverride = isCandidateOverride
    }

    /// 使用完整參數初始化 Gram
    /// - Parameters:
    ///   - keyArray: 讀音陣列（注音符號）
    ///   - current: 當前漢字
    ///   - previous: 前一個漢字（僅雙元圖使用）
    ///   - probability: 機率權重
    ///   - isCandidateOverride: 是否為候選字覆蓋記錄
    public init(
      keyArray: [String],
      current: String,
      previous: String? = nil,
      probability: Double = 0,
      isCandidateOverride: Bool = false
    ) {
      self.keyArray = keyArray
      if let previous, !previous.isEmpty {
        self.previous = previous
      } else {
        self.previous = nil
      }
      self.current = current
      self.probability = probability
      self.isCandidateOverride = isCandidateOverride
    }

    public init(from decoder: any Decoder) throws {
      let container = try decoder.container(keyedBy: CodingKeys.self)
      self.keyArray = try container.decode([String].self, forKey: .keyArray)
      self.current = try container.decode(String.self, forKey: .current)
      self.previous = try container.decodeIfPresent(String.self, forKey: .previous)
      self.probability = try container.decode(Double.self, forKey: .probability)
      self.isCandidateOverride =
        (try container.decodeIfPresent(Bool.self, forKey: .isCandidateOverride)) ?? false
    }

    // MARK: Public

    /// 原始資料元組類型
    public typealias GramRAW = (
      keyArray: [String],
      value: String,
      probability: Double,
      previous: String?
    )

    /// 元圖識別碼（讀音陣列）
    public let keyArray: [String]
    /// 當前漢字
    public let current: String
    /// 前一個漢字（僅雙元圖使用）
    public let previous: String?
    /// 機率權重
    public let probability: Double
    /// 是否為候選字覆蓋記錄
    public let isCandidateOverride: Bool

    /// 是否為單元圖（Unigram）
    public var isUnigram: Bool { previous == nil }

    /// 文字描述
    public var description: String {
      describe(keySeparator: "-")
    }

    /// 不含讀音的描述文字
    public var descriptionSansReading: String {
      guard !isCandidateOverride else {
        return "P(\(current))" // 雙元圖
      }
      guard let previous else {
        return "P(\(current))=\(probability)" // 單元圖
      }
      return "P(\(current)|\(previous))=\(probability)" // 雙元圖
    }

    /// 轉換為原始資料元組
    public var asTuple: GramRAW {
      (
        keyArray: keyArray,
        value: current,
        probability: probability,
        previous: previous
      )
    }

    /// 檢查是否「讀音字長與候選字字長不一致」
    public var isReadingMismatched: Bool {
      keyArray.count != current.count
    }

    /// 幅長（讀音數量）
    public var segLength: Int {
      keyArray.count
    }

    /// 判斷兩個 Gram 是否相等
    public static func == (lhs: Self, rhs: Self) -> Bool {
      lhs.keyArray == rhs.keyArray && lhs.current == rhs.current && lhs.previous == rhs.previous
        && lhs.probability == rhs.probability
    }

    /// 產生帶有指定分隔符的描述文字
    /// - Parameter keySeparator: 讀音分隔符
    /// - Returns: 格式化的描述文字
    public func describe(keySeparator: String) -> String {
      let header = isCandidateOverride ? "[CndOvrw]" : "[\(isUnigram ? "Unigram" : "Bigram")]"
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
      hasher.combine(isCandidateOverride)
    }

    /// 編碼至指定編碼器
    /// - Parameter encoder: 編碼器
    public func encode(to encoder: any Encoder) throws {
      var container = encoder.container(keyedBy: CodingKeys.self)
      try container.encode(keyArray, forKey: .keyArray)
      try container.encode(current, forKey: .current)
      try container.encodeIfPresent(previous, forKey: .previous)
      try container.encode(probability, forKey: .probability)
      try container.encode(isCandidateOverride, forKey: .isCandidateOverride)
    }

    // MARK: Internal

    enum CodingKeys: String, CodingKey {
      case keyArray = "keys"
      case current = "curr"
      case previous = "prev"
      case probability = "prob"
      case isCandidateOverride = "ovrw"
    }
  }
}
