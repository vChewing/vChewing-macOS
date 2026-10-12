// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

import Foundation
import Tekkon

// MARK: - DualpinValidationReport

/// 雙拼方案之校驗報告。
///
/// 本型別係 `DualpinParser.validate(inventory:conflictingRawIDs:)` 之輸出，內含錯誤、警訊、
/// 反向索引（碼 → 詞幹集合）與統計。`isUsable` 為 `errors.isEmpty`。
public struct DualpinValidationReport: Hashable, Sendable {
  /// 報告項目之級別。
  public enum Level: String, Hashable, Sendable {
    case error
    case warning
  }

  /// 報告項目之代號。編號一經公佈即不重編（W6 廢止後其號保留，以免他處引用漂移）。
  public enum Code: String, Hashable, Sendable, CaseIterable {
    case E1, E2, E3, E4, E5, E6, E7, E8, E9
    case W1, W2, W3, W4, W5, W7, W8
  }

  /// 單一報告項目。
  public struct Issue: Hashable, Sendable {
    public let level: Level
    public let code: Code
    public let detail: String
  }

  /// 統計。
  public struct Stats: Hashable, Sendable {
    /// 受校驗之詞幹總數（含 DIPE）。
    public var inventoryCount: Int = 0
    /// 得碼之詞幹數。
    public var codableCount: Int = 0
    /// 相異碼數。
    public var distinctCodeCount: Int = 0
    /// 碼長分布（碼長 → 條數）。
    public var codeLengthDistribution: [Int: Int] = [:]
    /// 實際用及之鍵。
    public var usedKeys: Set<Character> = []
    /// 自由槽位數＝`alphabet.count ^ codeLength − 相異碼數`。
    public var freeSlotCount: Int = 0
    /// 因屬 DIPE 而靜默略過之詞幹（不列 E3、不列 W1）。
    public var ignoredStems: Set<String> = []
    /// 重碼組（碼 → 多於一條之詞幹集合）。
    public var duplicateCodeGroups: [String: [String]] = [:]
  }

  /// 方案之 DNS 名唯一 ID。
  public let rawID: String
  /// 所有報告項目。
  public var issues: [Issue] = []
  /// 反向索引：碼 → 詞幹集合（不含 `aliases`）。
  public var codeToStems: [String: [String]] = [:]
  /// 正向索引：詞幹 → 碼。
  public var stemToCode: [String: String] = [:]
  /// 由 `aliases` 給出之額外解碼途徑：碼 → 詞幹集合。
  public var aliasCodeToStems: [String: [String]] = [:]
  /// 統計。
  public var stats = Stats()

  /// 錯誤項目。
  public var errors: [Issue] { issues.filter { $0.level == .error } }
  /// 警訊項目。
  public var warnings: [Issue] { issues.filter { $0.level == .warning } }
  /// 本方案是否可用（無錯誤即可用；警訊不影響可用性）。
  public var isUsable: Bool { errors.isEmpty }
}

// MARK: - DualpinParser

/// 一份雙拼方案之載入、檢證與編解碼。
///
/// 「雙拼方案」即本型別所描述之 **JSON 檔案格式**；內建方案與使用者自備者走**完全相同**之
/// decoder，故內建之 JSON 原文即使用者格式之範例。
///
/// 資料模型採「聲母表 ＋ 尾綴改寫表 ＋ 零聲母政策」而非 426 條全表：全表無從稽核其內部一致性，
/// 而聲母、尾綴、零聲母三者合計約 55 條即足以生成全部碼。
public struct DualpinParser: Codable, Hashable, Sendable {
  // MARK: Lifecycle

  /// 逐欄初始化。
  public init(
    rawID: String,
    rawTitle: String,
    localizedTitle: [String: String] = [:],
    initials: [String: Character],
    finals: [String: Character],
    nullOnset: NullOnsetPolicy,
    keyInterception: KeyInterception = .none,
    autochopPolicy: AutochopPolicy = .disabled,
    overrides: [String: String] = [:],
    aliases: [String: String] = [:],
    acknowledgedUnreachable: Set<String> = []
  ) {
    self.rawID = rawID
    self.rawTitle = rawTitle
    self.localizedTitle = localizedTitle
    self.initials = initials
    self.finals = finals
    self.nullOnset = nullOnset
    self.alphabet = Self.derivedAlphabet(initials: initials, finals: finals, nullOnset: nullOnset)
    self.keyInterception = keyInterception
    self.autochopPolicy = autochopPolicy
    self.overrides = overrides
    self.aliases = aliases
    self.acknowledgedUnreachable = acknowledgedUnreachable
    self.normalizationApplied = false
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    self.rawID = try container.decode(String.self, forKey: .rawID)
    self.rawTitle = try container.decode(String.self, forKey: .rawTitle)
    self.localizedTitle = try container.decodeIfPresent(
      [String: String].self, forKey: .localizedTitle
    ) ?? [:]
    let rawInitials = try container
      .decode([String: String].self, forKey: .initials)
      .compactMapValues(\.first)
    let rawFinals = try container.decode([String: String].self, forKey: .finals)
    let rawOverrides = try container.decodeIfPresent(
      [String: String].self, forKey: .overrides
    ) ?? [:]
    let rawAliases = try container.decodeIfPresent(
      [String: String].self, forKey: .aliases
    ) ?? [:]
    let rawUnreachable = try container.decodeIfPresent(
      Set<String>.self, forKey: .acknowledgedUnreachable
    ) ?? []
    let normalizedInitials = rawInitials.mapKeys(Self.normalizeSpelling)
    self.initials = normalizedInitials
    // 辭典形之值須逐條驗空：`[String: String]` 表達不了「鍵為空字元」之錯誤。
    var normalizedFinals: [String: Character] = [:]
    for (suffix, key) in rawFinals.sorted(by: { $0.key < $1.key }) {
      guard let character = key.first else {
        throw DecodingError.dataCorruptedError(
          forKey: .finals, in: container,
          debugDescription: "尾綴「\(suffix)」之鍵為空。"
        )
      }
      normalizedFinals[Self.normalizeSpelling(suffix)] = character
    }
    self.finals = normalizedFinals
    let nullOnset = try container.decode(NullOnsetPolicy.self, forKey: .nullOnset)
    self.nullOnset = nullOnset
    self.alphabet = Self.derivedAlphabet(
      initials: normalizedInitials, finals: normalizedFinals, nullOnset: nullOnset
    )
    self.keyInterception = try container.decodeIfPresent(
      KeyInterception.self, forKey: .keyInterception
    ) ?? .none
    self.autochopPolicy = try container.decodeIfPresent(
      AutochopPolicy.self, forKey: .autochopPolicy
    ) ?? .disabled
    self.overrides = rawOverrides.mapKeys(Self.normalizeSpelling)
    self.aliases = rawAliases.mapKeys(Self.normalizeSpelling)
    self.acknowledgedUnreachable = Set(rawUnreachable.map(Self.normalizeSpelling))
    // W4：任何一處之拼寫被改寫過，即須明示。
    let allRawSpellings = Array(rawInitials.keys) + Array(rawFinals.keys)
      + Array(rawOverrides.keys) + Array(rawAliases.keys) + Array(rawUnreachable)
    self.normalizationApplied = allRawSpellings.contains { Self.normalizeSpelling($0) != $0 }
  }

  // MARK: Public

  /// 零聲母（null onset）政策：不成聲母之音節如何取首鍵。
  public enum NullOnsetPolicy: Hashable, Sendable {
    /// ①固定一鍵作零聲母（GB/T 34947-2017＝`a`；微軟＝`o`）。
    case fixedKey(Character)
    /// ②以韻母首字母為零聲母（拼音加加）。
    case finalInitial
    /// ③單韻母與三韻母取首字母、雙韻母照原樣輸入（自然碼、小鶴）。
    case finalInitialOrVerbatimDigraph
  }

  /// 主機保留鍵之攔截政策：本方案之 `alphabet` 中，哪些鍵須先於主機既有處理序交本引擎。
  public enum KeyInterception: Hashable, Sendable {
    /// 不攔截（預設）。
    case none
    /// 僅攔截明列之鍵。
    case explicit(Set<Character>)
    /// 攔截 `alphabet` 內之全部鍵（最保守）。
    case schemeAlphabet
  }

  /// 未滿碼之殘段如何處置。本版只實作 `.disabled`；他形載入發 W7 而不拒收。
  public enum AutochopPolicy: String, Codable, Hashable, Sendable, CaseIterable {
    /// 不回溯、不猜：未成碼之鍵序列不進組音區。
    case disabled
    /// Apple 形：不成碼即退一鍵、固化為較短之合法音節。
    case backtrackToShorterReading
    /// 微信形：未滿碼者留置並列前綴候選。
    case prefixCandidates
    /// 搜狗形：切界＋殘段以原文 ASCII 出字。
    case passThroughVerbatim
  }

  /// 因屬 DIPE（Dualpin-Incompatible Pinyin Expression）而一律靜默忽略之詞幹。
  ///
  /// `eh`（孤立 ㄝ）係首例：其存在於漢語拼音之拼式空間、卻無從於雙拼之鍵位空間表達。
  /// 此類詞幹不列 E3、不列 W1、不進 `stemToCode`，僅記於 `stats.ignoredStems`。
  public static let dualpinIncompatiblePinyinExpressions: Set<String> = ["eh"]

  /// 雙拼之碼長：恆為 2（聲母鍵＋尾綴鍵，或零聲母鍵＋尾綴鍵）。
  ///
  /// 全表皆二鍵，故不設欄位。他日若真有三鍵方案，再於此處立 `minCodeLength`／`maxCodeLength`。
  public static let codeLength = 2

  /// 零聲母鍵於提示中之記號：表「此音節無聲母」，非鍵面之字元。
  public static let nullOnsetMarker = "∅"

  /// 方案之 DNS 名唯一 ID（反向域名形，如 `dualPin.Microsoft`）。
  public var rawID: String
  /// 方案之原文標題（可為簡體；不得為空）。
  public var rawTitle: String
  /// 語系標籤（Apple 形，如 `en`／`zh-Hant`）→ 該語系之標題。
  public var localizedTitle: [String: String]
  /// 可用之鍵（由兩表之值與零聲母政策推算，不載於 JSON）。
  public let alphabet: Set<Character>
  /// 聲母 → 鍵（含 `zh`／`ch`／`sh`；可含 `y`／`w`）。
  public var initials: [String: Character]
  /// 尾綴 → 鍵（全等匹配；與 `initials` 同制之辭典形）。
  public var finals: [String: Character]
  /// 零聲母（null onset）政策。
  public var nullOnset: NullOnsetPolicy
  /// 主機保留鍵之處置。
  public var keyInterception: KeyInterception
  /// 未滿碼之殘段處置。
  public var autochopPolicy: AutochopPolicy
  /// 詞幹 → 碼（最高優先）。
  public var overrides: [String: String]
  /// 額外可接受之碼 → 詞幹。
  public var aliases: [String: String]
  /// 可表達而刻意不表達之詞幹（DIPE 不列於此）。
  public var acknowledgedUnreachable: Set<String>
  /// 載入時是否對 ü／`v` 拼寫作過正規化改寫（決定 W4）。
  public var normalizationApplied: Bool

  /// 由兩表之值與零聲母政策推算可用之鍵。
  ///
  /// 非零聲母之音節一律取「聲母表之值＋尾綴表之值」，故兩表之值必在可編之列；零聲母之音節
  /// 則視政策而定：`.fixedKey` 另收該固定鍵；`.finalInitial` 以餘部首字元為鍵；而
  /// `.finalInitialOrVerbatimDigraph` 於雙字元餘部時逐字原樣輸出，故該二類鍵（首字元、雙字元
  /// 鍵之兩字元）亦須計入。如此推導方與 `code(forStem:)` 之實得鍵集相稱，E1 遂僅能由
  /// `overrides`／`aliases` 所載之表外鍵觸發。內建方案之兩表所給之鍵皆為某些碼所用到（即
  /// `usedKeys == alphabet`，W5 不觸發）。
  public static func derivedAlphabet(
    initials: [String: Character],
    finals: [String: Character],
    nullOnset: NullOnsetPolicy
  )
    -> Set<Character> {
    var keys = Set(initials.values).union(finals.values)
    switch nullOnset {
    case let .fixedKey(key):
      keys.insert(key)
    case .finalInitial:
      keys.formUnion(finals.keys.compactMap(\.first))
    case .finalInitialOrVerbatimDigraph:
      for suffix in finals.keys {
        keys.formUnion(suffix.prefix(1))
        if suffix.count == 2 { keys.formUnion(suffix) }
      }
    }
    return keys
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    try container.encode(rawID, forKey: .rawID)
    try container.encode(rawTitle, forKey: .rawTitle)
    try container.encode(localizedTitle, forKey: .localizedTitle)
    try container.encode(initials.mapValues(String.init), forKey: .initials)
    try container.encode(finals.mapValues(String.init), forKey: .finals)
    try container.encode(nullOnset, forKey: .nullOnset)
    try container.encode(keyInterception, forKey: .keyInterception)
    try container.encode(autochopPolicy, forKey: .autochopPolicy)
    if !overrides.isEmpty { try container.encode(overrides, forKey: .overrides) }
    if !aliases.isEmpty { try container.encode(aliases, forKey: .aliases) }
    if !acknowledgedUnreachable.isEmpty {
      try container.encode(acknowledgedUnreachable.sorted(), forKey: .acknowledgedUnreachable)
    }
  }

  // MARK: Internal

  // MARK: Codable

  enum CodingKeys: String, CodingKey {
    case rawID, rawTitle, localizedTitle
    case initials, finals, nullOnset, keyInterception, autochopPolicy
    case overrides, aliases, acknowledgedUnreachable
  }
}

// MARK: - 拼寫正規化

extension DualpinParser {
  /// 將 `n`／`l` 之後的 `ü` 正規化為 `v`。
  ///
  /// 本引擎內之 ü 有兩種拼寫：`n`／`l` 之後作 `v`（`nv`／`nve`／`lv`／`lve`／`lvan`），
  /// `j`／`q`／`x`／`y` 之後作 `u`。schema 載入時對前者一律正規化，並發 W4。
  public static func normalizeSpelling(_ raw: String) -> String {
    guard raw.contains("ü") else { return raw }
    return raw
      .replacingOccurrences(of: "nü", with: "nv")
      .replacingOccurrences(of: "lü", with: "lv")
  }
}

// MARK: - 編解碼

extension DualpinParser {
  /// 尾綴改寫：以「餘部與尾綴之**全等**」取鍵。
  ///
  /// 本引擎不採後綴吞噬（否則 `a` 會吞掉 `ua`）；`finals` 為辭典形，查表為常數時間，
  /// 且不受書寫次序影響。
  public func finalKey(forRemainder remainder: String) -> Character? {
    finals[remainder]
  }

  /// 以本方案將單一詞幹編為碼。`overrides` 優先。
  ///
  /// - Returns: 兩鍵之碼；無法編碼時回 `nil`。
  public func code(forStem stem: String) -> String? {
    if let overridden = overrides[stem] { return overridden }
    let normalized = Self.normalizeSpelling(stem)
    var initialKey: Character?
    var remainder = normalized
    for candidate in initials.keys.sorted(by: { $0.count > $1.count })
      where normalized.hasPrefix(candidate) {
      initialKey = initials[candidate]
      remainder = String(normalized.dropFirst(candidate.count))
      break
    }
    if let initialKey {
      guard let finalKey = finalKey(forRemainder: remainder) else { return nil }
      return String(initialKey) + String(finalKey)
    }
    switch nullOnset {
    case let .fixedKey(key):
      guard let finalKey = finalKey(forRemainder: remainder) else { return nil }
      return String(key) + String(finalKey)
    case .finalInitial:
      guard let finalKey = finalKey(forRemainder: remainder), let lead = remainder.first
      else { return nil }
      return String(lead) + String(finalKey)
    case .finalInitialOrVerbatimDigraph:
      if remainder.count == 2 { return remainder }
      guard let finalKey = finalKey(forRemainder: remainder), let lead = remainder.first
      else { return nil }
      return String(lead) + String(finalKey)
    }
  }

  /// 將詞幹編為碼（含 `aliases` 給出之別名碼）。
  public func encode(
    stem: String,
    inventory: [String] = Tekkon.allHanyuPinyinStems
  )
    -> [String] {
    let canonical = inventory.contains(stem) ? stem : Self.normalizeSpelling(stem)
    let aliasCodes = aliases.filter { $0.value == canonical }.map(\.key).sorted()
    guard let primary = code(forStem: canonical) else { return aliasCodes }
    return ([primary] + aliasCodes).deduplicated()
  }

  /// 將碼解為詞幹集合（含 `aliases`）。
  public func decode(
    code: String,
    inventory: [String] = Tekkon.allHanyuPinyinStems
  )
    -> [String] {
    var result: [String] = []
    if let aliasStem = aliases[code] { result.append(aliasStem) }
    for stem in inventory.sorted()
      where !DualpinParser.dualpinIncompatiblePinyinExpressions.contains(stem)
      && self.code(forStem: stem) == code {
      result.append(stem)
    }
    return result.deduplicated()
  }

  /// 給定一鍵，列出本方案之**首鍵**位置上該鍵所代表之意義。
  ///
  /// 首鍵之角色有二：其一為聲母（`initials` 中值等於該鍵之條目）；其二為零聲母音節之引鍵，
  /// 其義隨政策而異：
  /// - `.fixedKey`：該固定鍵不是表內單位，而是「此音節無聲母」之宣告，故予記號 `nullOnsetMarker`。
  /// - `.finalInitial`／`.finalInitialOrVerbatimDigraph`：零聲母之音節以韻母之首字元為首鍵，
  ///   故該鍵所代表者即「以該字元起首之諸韻母」。
  ///
  /// **不列**「值等於該鍵之韻母」——韻母於第二鍵位置方成其碼義（微軟雙拼之韻母 `u` 亦以 `u`
  /// 為鍵），若一併列入，首鍵 `u`（實為聲母 `sh`）將誤示為 `sh u`（事主 2026-10-14 以實機指正，
  /// 漢語拼音實無以 `u` 起首之音節）。亦不列「以該鍵為首之諸詞幹」——那是前綴窮舉
  /// （微軟雙拼 `v` 即 `zha`…`zhuo` 二十條），用之於提示寬到不可讀（同日首次指正）。
  ///
  /// - Returns: 記號（若有）在前，次為聲母、末為政策所定之韻母，各依拼式升序；皆無者回空。
  public func meanings(ofKey key: Character) -> [String] {
    var result: [String] = []
    if case let .fixedKey(fixedKey) = nullOnset, fixedKey == key {
      result.append(Self.nullOnsetMarker)
    }
    result += initials.filter { $0.value == key }.keys.sorted()
    switch nullOnset {
    case .fixedKey:
      break
    case .finalInitial, .finalInitialOrVerbatimDigraph:
      result += finals.keys.filter { $0.first == key }.sorted()
    }
    return result.deduplicated()
  }
}

// MARK: - 標題解析

extension DualpinParser {
  /// 以語系標籤字串解析本方案之標題。
  ///
  /// 解析序：①精確標籤 → ②同語言同文字系統、去區域（`zh-Hant-TW` → `zh-Hant`）→
  /// ③語言主標籤（`zh`）→ ④`en` → ⑤`rawTitle`。比對時大小寫不拘、`_` 與 `-` 等價。
  ///
  /// - Parameter tag: 語系標籤字串（如 `Locale.current.identifier`）。本模組之公開面不引
  ///   Foundation 型別，故不收 `Locale`。
  public func title(forLocaleTag tag: String) -> String {
    let table = localizedTitle.reduce(into: [String: String]()) { result, pair in
      result[Self.canonicalLocaleTag(pair.key)] = pair.value
    }
    for candidate in Self.localeTagCandidates(for: tag) {
      if let hit = table[Self.canonicalLocaleTag(candidate)], !hit.isEmpty { return hit }
    }
    return rawTitle
  }

  /// 將語系標籤正規化為比對形：小寫、`_` 改 `-`。
  public static func canonicalLocaleTag(_ tag: String) -> String {
    tag.replacingOccurrences(of: "_", with: "-").lowercased()
  }

  /// 依解析序給出候選標籤。
  public static func localeTagCandidates(for tag: String) -> [String] {
    let canonical = canonicalLocaleTag(tag)
    var candidates: [String] = [canonical]
    let segments = canonical.split(separator: "-").map(String.init)
    if segments.count >= 2 { candidates.append(segments.prefix(2).joined(separator: "-")) }
    if let primary = segments.first { candidates.append(primary) }
    candidates.append("en")
    return candidates.deduplicated()
  }
}

// MARK: - 校驗

extension DualpinParser {
  /// 主機保留鍵（波浪符號鍵、漢音符號熱鍵）。
  public static let hostReservedKeys: Set<Character> = ["`", "~", "¥", "\\"]

  /// 會與 Composer 之聲調語義相撞之鍵。
  public static let intonationCollidingKeys: Set<Character> =
    .init("12345 ").union(["ˊ", "ˇ", "ˋ", "˙"])

  /// 校驗本方案。
  ///
  /// - Parameters:
  ///   - inventory: 讀音清單（純值 `[String]`，426 條）。預設由 Tekkon 之公開 API 給出。
  ///   - conflictingRawIDs: 須視為已佔用之 `rawID`（含內建兩方案）。
  /// - Returns: 校驗報告。
  public func validate(
    inventory: [String] = Tekkon.allHanyuPinyinStems,
    conflictingRawIDs: Set<String> = []
  )
    -> DualpinValidationReport {
    var report = DualpinValidationReport(rawID: rawID)
    var issues: [DualpinValidationReport.Issue] = []
    func note(
      _ level: DualpinValidationReport.Level,
      _ code: DualpinValidationReport.Code,
      _ detail: String
    ) {
      issues.append(.init(level: level, code: code, detail: detail))
    }

    // E7：標題解析鏈之最終退路不得缺。
    if rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      note(.error, .E7, "rawTitle 為空。")
    }
    // E9：rawID 須為 DNS 名、且不與現存方案相衝。
    // 內建方案校驗自身時不算相衝（自身即「現存方案」之一）；惟自備方案冒用內建之
    // rawID 仍屬相衝。故整條相衝判定以「本體非內建」為前提。
    if rawID.isEmpty {
      note(.error, .E9, "rawID 為空。")
    } else if !Self.isReverseDomainName(rawID) {
      note(.error, .E9, "rawID「\(rawID)」非 DNS 名（反向域名）形。")
    } else if !DualpinParser.builtinParsers.contains(self),
              conflictingRawIDs.contains(rawID) || DualpinParser.builtinRawIDs.contains(rawID) {
      note(.error, .E9, "rawID「\(rawID)」與現存方案相衝。")
    }
    // E8：碼長一律 2；`overrides` 之碼亦不例外。
    for (stem, code) in overrides.sorted(by: { $0.key < $1.key })
      where code.count != Self.codeLength {
      note(.error, .E8, "overrides[\(stem)] 之碼「\(code)」長度非 \(Self.codeLength)。")
    }
    // E4：alphabet 不得含聲調鍵或不可列印字元。
    for key in alphabet.sorted() {
      if Self.intonationCollidingKeys.contains(key) {
        note(.error, .E4, "alphabet 含聲調鍵「\(key)」。")
      } else if !key.isLetter, !key.isNumber, !key.isPunctuation, !key.isSymbol {
        note(.error, .E4, "alphabet 含不可列印字元。")
      }
    }
    // E6：explicit 所列之鍵須在 alphabet 內。
    if case let .explicit(keys) = keyInterception {
      for key in keys.sorted() where !alphabet.contains(key) {
        note(.error, .E6, "keyInterception 所列之鍵「\(key)」不在 alphabet 內。")
      }
    }

    // 分解、取碼、反向建索引。
    report.stats.inventoryCount = inventory.count
    report.stats.ignoredStems = Set(inventory)
      .intersection(Self.dualpinIncompatiblePinyinExpressions)
    var unreachableStems: [String] = []
    for stem in inventory.sorted() {
      if Self.dualpinIncompatiblePinyinExpressions.contains(stem) { continue }
      guard let code = code(forStem: stem) else {
        if acknowledgedUnreachable.contains(stem) { unreachableStems.append(stem) } else {
          note(.error, .E3, "詞幹「\(stem)」無法得碼，且未列於 acknowledgedUnreachable。")
        }
        continue
      }
      let illegalKeys = Set(code).subtracting(alphabet)
      if !illegalKeys.isEmpty {
        note(.error, .E1, "詞幹「\(stem)」之碼「\(code)」含 alphabet 外之鍵：\(illegalKeys.sorted())。")
      }
      if code.count != Self.codeLength {
        note(.error, .E2, "詞幹「\(stem)」之碼「\(code)」長度非 \(Self.codeLength)。")
      }
      report.stemToCode[stem] = code
      report.codeToStems[code, default: []].append(stem)
    }
    for (code, stem) in aliases.sorted(by: { $0.key < $1.key }) {
      report.aliasCodeToStems[code, default: []].append(stem)
      // E5：碼之映射須為函式——別名不得與既有之不同詞幹之主碼相撞。
      if let existing = report.codeToStems[code], !existing.contains(stem) {
        note(.error, .E5, "碼「\(code)」同時對應 \(existing.sorted()) 與別名「\(stem)」。")
      }
    }

    // W1：明示「可表達而刻意不表達」之詞幹。
    if !unreachableStems.isEmpty {
      note(.warning, .W1, "acknowledgedUnreachable：\(unreachableStems.sorted())。")
    }
    // W2：重碼（雙拼之常態）。
    report.stats.duplicateCodeGroups = report.codeToStems.filter { $0.value.count > 1 }
    for (code, stems) in report.stats.duplicateCodeGroups.sorted(by: { $0.key < $1.key }) {
      note(.warning, .W2, "重碼「\(code)」：\(stems.sorted())。")
    }
    // W3：碼使用主機保留鍵而未於 keyInterception 明列。
    let interceptedKeys: Set<Character> = {
      switch keyInterception {
      case .none: return []
      case .schemeAlphabet: return alphabet
      case let .explicit(keys): return keys
      }
    }()
    let reservedInUse = Set(report.codeToStems.keys.flatMap { Set($0) })
      .intersection(Self.hostReservedKeys)
      .subtracting(interceptedKeys)
    if !reservedInUse.isEmpty {
      note(.warning, .W3, "碼用及主機保留鍵而未列於 keyInterception：\(reservedInUse.sorted())。")
    }
    // W4：載入時對 ü／v 拼寫作了正規化改寫。
    if normalizationApplied {
      note(.warning, .W4, "載入時對 n／l 之後的 ü 作了 v 化正規化。")
    }
    // W5：兩表所給之鍵未被任何碼用到（可用之鍵既由兩表推算，冗餘即「表列而不用」）。
    report.stats.usedKeys = Set(report.codeToStems.keys.flatMap { Set($0) })
    let unusedTableKeys = alphabet.subtracting(report.stats.usedKeys)
    if !unusedTableKeys.isEmpty {
      note(.warning, .W5, "兩表所給之鍵未被任何碼用到：\(unusedTableKeys.sorted())。")
    }
    // W7：autochopPolicy 非 .disabled（本版尚未支援他形）。
    if autochopPolicy != .disabled {
      note(.warning, .W7, "autochopPolicy 為「\(autochopPolicy.rawValue)」，本版僅支援 disabled。")
    }
    // W8：localizedTitle 缺 en。
    if !localizedTitle.keys.map(Self.canonicalLocaleTag).contains("en") {
      note(.warning, .W8, "localizedTitle 缺 en（fallback 鏈之第二級缺席）。")
    }

    // 結算。
    report.stats.codableCount = report.stemToCode.count
    report.stats.distinctCodeCount = report.codeToStems.count
    report.stats.codeLengthDistribution = report.codeToStems.keys
      .reduce(into: [Int: Int]()) { $0[$1.count, default: 0] += 1 }
    report.stats.freeSlotCount = Int(
      pow(Double(alphabet.count), Double(Self.codeLength))
    ) - report.stats.distinctCodeCount
    report.issues = issues.sorted {
      ($0.level == .warning ? 1 : 0, $0.code.rawValue, $0.detail)
        < ($1.level == .warning ? 1 : 0, $1.code.rawValue, $1.detail)
    }
    return report
  }

  /// `rawID` 是否為反向域名形。
  public static func isReverseDomainName(_ rawID: String) -> Bool {
    let pattern = #"^[A-Za-z][A-Za-z0-9-]*(\.[A-Za-z][A-Za-z0-9-]*)+$"#
    return rawID.range(of: pattern, options: .regularExpression) != nil
  }
}

// MARK: - DualpinParser.NullOnsetPolicy + Codable

extension DualpinParser.NullOnsetPolicy: Codable {
  public init(from decoder: Decoder) throws {
    if let single = try? decoder.singleValueContainer() {
      if let raw = try? single.decode(String.self) {
        switch raw {
        case "finalInitial": self = .finalInitial
        case "finalInitialOrVerbatimDigraph": self = .finalInitialOrVerbatimDigraph
        default:
          guard raw.count == 1, let key = raw.first else {
            throw DecodingError.dataCorruptedError(
              in: single, debugDescription: "無法辨識之 nullOnset：\(raw)"
            )
          }
          self = .fixedKey(key)
        }
        return
      }
      if let keyed = try? single.decode([String: String].self), let raw = keyed["fixedKey"],
         raw.count == 1, let key = raw.first {
        self = .fixedKey(key)
        return
      }
    }
    throw DecodingError.dataCorruptedError(
      in: try decoder.singleValueContainer(), debugDescription: "無法辨識之 nullOnset。"
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case let .fixedKey(key): try container.encode(String(key))
    case .finalInitial: try container.encode("finalInitial")
    case .finalInitialOrVerbatimDigraph: try container.encode("finalInitialOrVerbatimDigraph")
    }
  }
}

// MARK: - DualpinParser.KeyInterception + Codable

extension DualpinParser.KeyInterception: Codable {
  public init(from decoder: Decoder) throws {
    let single = try decoder.singleValueContainer()
    if let raw = try? single.decode(String.self) {
      switch raw {
      case "none": self = .none
      case "schemeAlphabet": self = .schemeAlphabet
      default: self = .explicit(Set(raw))
      }
      return
    }
    if let keyed = try? single.decode([String: [String]].self), let keys = keyed["explicit"] {
      self = .explicit(Set(keys.compactMap(\.first)))
      return
    }
    if let keyed = try? single.decode([String: String].self), let raw = keyed["explicit"] {
      self = .explicit(Set(raw))
      return
    }
    throw DecodingError.dataCorruptedError(
      in: single, debugDescription: "無法辨識之 keyInterception。"
    )
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .none: try container.encode("none")
    case .schemeAlphabet: try container.encode("schemeAlphabet")
    case let .explicit(keys): try container.encode(["explicit": String(keys.sorted())])
    }
  }
}

// MARK: - 私有工具

extension Dictionary {
  /// 以變換函式改寫全部鍵。
  fileprivate func mapKeys(_ transform: (Key) -> Key) -> [Key: Value] {
    reduce(into: [Key: Value]()) { $0[transform($1.key)] = $1.value }
  }
}

extension Array where Element: Hashable {
  /// 去重且保持首次出現之次序。
  fileprivate func deduplicated() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

// MARK: - 內建方案

extension DualpinParser {
  /// 內建預設方案：微軟雙拼。
  public static let mspy: DualpinParser = builtin(fromJSON: mspySchemaJSON, named: "Microsoft")
  /// 內建方案：GB/T 34947-2017。
  public static let gbt17: DualpinParser = builtin(fromJSON: gbt17SchemaJSON, named: "GBT17")
  /// 全部內建方案。
  public static let builtinParsers: [DualpinParser] = [mspy, gbt17]
  /// 全部內建方案之 `rawID`。
  public static let builtinRawIDs: Set<String> = Set(builtinParsers.map(\.rawID))

  /// 以內建 JSON 原文解碼。解碼失敗即大聲失敗——內建原文即格式之範例，不得默默損毀。
  public static func builtin(fromJSON json: String, named name: String) -> DualpinParser {
    do {
      return try JSONDecoder().decode(DualpinParser.self, from: Data(json.utf8))
    } catch {
      preconditionFailure("Arimitsu：內建方案「\(name)」之 JSON 原文無法解碼：\(error)")
    }
  }

  /// 以 `rawID` 指名內建方案。
  public static func builtinParser(forRawID rawID: String) -> DualpinParser? {
    builtinParsers.first { $0.rawID == rawID }
  }

  /// 微軟雙拼之 JSON 原文。
  public static let mspySchemaJSON = #"""
  {
    "rawID": "dualPin.Microsoft",
    "rawTitle": "Microsoft",
    "localizedTitle": {
      "en": "Microsoft",
      "zh-Hans": "微软双拼",
      "zh-Hant": "微軟雙拼",
      "ja": "Microsoft"
    },
    "initials": {
      "zh": "v",
      "ch": "i",
      "sh": "u",
      "b": "b",
      "p": "p",
      "m": "m",
      "f": "f",
      "d": "d",
      "t": "t",
      "n": "n",
      "l": "l",
      "g": "g",
      "k": "k",
      "h": "h",
      "j": "j",
      "q": "q",
      "x": "x",
      "r": "r",
      "z": "z",
      "c": "c",
      "s": "s",
      "y": "y",
      "w": "w"
    },
    "finals": {
      "iu": "q",
      "ia": "w",
      "ua": "w",
      "er": "r",
      "uan": "r",
      "van": "r",
      "ue": "t",
      "ve": "t",
      "v": "y",
      "uai": "y",
      "uo": "o",
      "un": "p",
      "vn": "p",
      "ong": "s",
      "iong": "s",
      "iang": "d",
      "uang": "d",
      "en": "f",
      "eng": "g",
      "ang": "h",
      "ian": "m",
      "an": "j",
      "iao": "c",
      "ao": "k",
      "ai": "l",
      "ei": "z",
      "ie": "x",
      "ui": "v",
      "ou": "b",
      "in": "n",
      "ing": ";",
      "a": "a",
      "o": "o",
      "e": "e",
      "i": "i",
      "u": "u"
    },
    "nullOnset": "o",
    "keyInterception": "none",
    "autochopPolicy": "disabled"
  }
  """#

  /// GB/T 34947-2017 之 JSON 原文。
  public static let gbt17SchemaJSON = #"""
  {
    "rawID": "dualPin.GBT17",
    "rawTitle": "GBT17",
    "localizedTitle": {
      "en": "GB/T 34947-2017",
      "zh-Hans": "GB/T 34947-2017",
      "zh-Hant": "GB/T 34947-2017",
      "ja": "GB/T 34947-2017"
    },
    "initials": {
      "zh": "v",
      "ch": "i",
      "sh": "u",
      "b": "b",
      "p": "p",
      "m": "m",
      "f": "f",
      "d": "d",
      "t": "t",
      "n": "n",
      "l": "l",
      "g": "g",
      "k": "k",
      "h": "h",
      "j": "j",
      "q": "q",
      "x": "x",
      "r": "r",
      "z": "z",
      "c": "c",
      "s": "s",
      "y": "y",
      "w": "w"
    },
    "finals": {
      "ia": "q",
      "ua": "q",
      "uan": "w",
      "van": "w",
      "en": "r",
      "ie": "t",
      "iu": "y",
      "uai": "y",
      "uo": "o",
      "ou": "p",
      "ong": "s",
      "iong": "s",
      "ian": "d",
      "an": "f",
      "ang": "g",
      "eng": "h",
      "ing": "j",
      "ai": "k",
      "in": "l",
      "er": "l",
      "un": "z",
      "vn": "z",
      "ue": "x",
      "ve": "x",
      "ao": "c",
      "ui": "v",
      "ei": "b",
      "iang": "n",
      "uang": "n",
      "iao": "m",
      "a": "a",
      "o": "o",
      "e": "e",
      "i": "i",
      "u": "u",
      "v": "v"
    },
    "nullOnset": "a",
    "keyInterception": "none",
    "autochopPolicy": "disabled"
  }
  """#
}
