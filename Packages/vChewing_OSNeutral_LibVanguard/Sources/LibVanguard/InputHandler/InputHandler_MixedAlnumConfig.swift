// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.
import Foundation

// MARK: - MixedAlnumConfig

/// 中英混打（MixedAlnum）模式專用的執行期狀態容器。
///
/// 將該模式所需的暫存狀態收斂成單一值型別，其後由 `InputHandlerProtocol` 以單一屬性持有，
/// 各欄位再以薄存取器對外（比照 `Homa.Assembler.config` 之做法）。
///
/// - Important: **本型別提供兩個復位粒度，不可混用**：
///   - `resetContent()`：僅重設「內容」類狀態。**每次遞交都會經過此路徑**
///     （`switchState(.ofCommitting)` 會連帶呼叫 `InputHandlerProtocol.clear()`），
///     故**不得**在該處清除閂滯旗標，否則「每鍵即刻遞交」會在第一顆鍵就自我解除。
///   - `resetAll()`：連同閂滯旗標一併重設。**由 `InputHandlerProtocol.releaseLatchedAlnumState(announce:)`
///     呼叫**——該函式即「閂滯之解除」之唯一出口：使用者之明確解除鍵與會話邊界
///     （`resetInputHandler()`、`performServerActivation()`）皆經此。
public struct MixedAlnumConfig: Sendable, Equatable {
  // MARK: Lifecycle

  public init(buffer: String = "", isLatchedToAlnum: Bool = false) {
    self.buffer = buffer
    self.isLatchedToAlnum = isLatchedToAlnum
  }

  // MARK: Public

  /// 混輸暫存 ASCII 緩衝區（尚待辨識為英文抑或注音之內容）。
  public var buffer: String = ""

  /// 是否已「閂滯於英打」。
  ///
  /// 為真時，該模式下每一顆可列印 ASCII 按鍵皆即刻遞交、不進緩衝區。
  /// 僅在中英混打模式與英數閂滯開關皆啟用時才可能為真。
  public var isLatchedToAlnum: Bool = false

  /// 僅重設內容類狀態（緩衝區）。**不觸碰閂滯旗標。**
  public mutating func resetContent() {
    buffer.removeAll()
  }

  /// 重設全部狀態（含閂滯旗標）。
  /// 唯一呼叫點為 `InputHandlerProtocol.releaseLatchedAlnumState(announce:)`。
  public mutating func resetAll() {
    resetContent()
    isLatchedToAlnum = false
  }
}

// MARK: - InputHandlerProtocol（混打緩衝之讀音量測）

extension InputHandlerProtocol {
  /// 注音排列下單一音節之最大鍵數（聲／介／韻／調各一鍵為通例；動態排列另有例外）。
  ///
  /// - Note: 本值即「混打緩衝可否作為**一個**讀音被消化」之上界。大千26 之動態排列因
  ///   跨鍵改寫槽值而碼長不定（`qquu`＝ㄅㄚ 為 4 鍵），故其上限另計。
  public var maxSingleSyllableKeyCount: Int {
    switch composer.parser {
    case .ofDachen26: 6 // 這是酷音大千26鍵的顯著缺點。
    case .ofETen26: 5 // 僅一例：`ㄍㄧㄠˊ → vezf`。
    default: 4 // 其餘所有注音排列，無論動態還是靜態排列，最大碼長均為 4。
    }
  }

  /// 混打緩衝區所承載之注音讀音，無則 `nil`（回退與注音狂打並存時之「未完成讀音」）。
  ///
  /// **三個必要條件**：
  ///   ① 該緩衝自身**恰為一個依槽序鍵入之無調讀音**（＝打字機之 `enforceCSVTOrdering`
  ///      語義）。亂序之殘段縱令「各槽俱滿、可發音」，仍非一個讀音。
  ///   ② 該讀音**是某個讀音的起頭**（`isPrefix`，含完整音節）——擋掉前置之 ASCII 段落
  ///      （如 `fi`＝ㄑㄛ 可發音卻非任何讀音之起頭），亦擋掉「以別鍵補滿前三槽」之殘段。
  ///   ③ 取讀音之來源須與該緩衝**一致**（見下之二選一）。
  ///
  /// **來源二選一，皆須「與緩衝一致」**：
  ///   ① 注拼槽之投影仍在者 ⇒ 取該投影，**惟須與自緩衝重求之結果相同**。投影只是緩衝之
  ///      投影，而投影之存活條件比緩衝寬鬆——凡「聲介韻三槽已滿」時，打字機慣以逐鍵消化
  ///      就地補滿（實測 `us` 之投影為 ㄋㄠ，而該緩衝僅有 ㄧㄡ 一音節之鍵數）；不加此項
  ///      一致性核對，殘段即會被誤認為完整讀音。
  ///   ② 投影已空者 ⇒ 自緩衝重求。此路必要：凡「聲介韻三槽已滿、後續鍵無處可入」者，
  ///      打字機即清空注拼槽、只把該段留在緩衝（實測 `1u`＝ㄅㄧ、`su`＝ㄋㄧ 之投影皆已清空）。
  ///
  /// 全程以副本求值，**不動任何既有狀態**。
  public var mixedAlnumPendingReading: String? {
    guard mixedAlnumZhuyinFuriousInEffect else { return nil }
    let buffer = mixedAlphanumericalBuffer
    // 空緩衝恆不成立、亦免於「以空序列求值」之無謂運算。
    guard !buffer.isEmpty, buffer.count <= maxSingleSyllableKeyCount else { return nil }
    // 條件①：該緩衝**恰為**一個依槽序鍵入之無調讀音——「無冗餘鍵」之核對與
    // `mixedAlnumBufferIsTonelessReading` 同源（同一份量測，不另立第二套判準）。
    guard mixedAlnumBufferIsTonelessReading else { return nil }
    let canonical = canonicalTonelessZhuyinReading(ofBuffer: buffer) ?? ""
    // 條件③：投影須與緩衝之消化結果一致（不得取較寬鬆之投影——投影只是緩衝之投影，
    // 而投影之存活條件比緩衝寬鬆）。
    var candidate = canonical
    if composer.isPronounceable, composer.intonation.value.isEmpty {
      let projected = composer.consonant.value + composer.semivowel.value + composer.vowel.value
      if !projected.isEmpty, projected == canonical { candidate = projected }
    }
    let index = Tekkon.SyllableIndex.shared(parser: composer.parser)
    // 條件②：`isComplete` 亦須收——實測 ㄋㄧㄠ（鍵序 `sul`）在索引內是完整讀音、卻非任何
    // 讀音之前綴，單憑 `isPrefix` 會漏掉一整類完整音節。惟兩者皆以**整段**為判。
    guard index.isPrefix(candidate) || index.isComplete(candidate) else { return nil }
    return candidate
  }

  /// 混打緩衝是否為「**恰為**一個尚未鍵入聲調之讀音」——**不拘狂打開關**之量測。
  ///
  /// - Important: 判準之要旨在「**恰為**」：該緩衝之**全部**按鍵皆須為該讀音所消費
  ///   （＝「鍵數 == 聲介韻佔用槽數」）。缺此一核對，「以另一鍵補滿槽位」之殘段會被誤認
  ///   為讀音——實測 `us`（＝ㄧㄡ ＋ ㄋ，兩音節之鍵）若不加核對，即與 `su`＝ㄋㄧ 無從
  ///   分辨，空白鍵遂把該殘段當讀音固化而令 ASCII 遞交失效（事主實機回報）。
  ///
  /// 混打模式下，中文組字進行中之按鍵亦棲身於同一緩衝（`su`＝ㄋㄧ、`1u,`＝ㄅㄧㄝ、`s`＝ㄋ），
  /// 故「緩衝非空」不足以證成英文意圖。本屬性問的正是「該緩衝能否作為**一個**讀音被注拼槽
  /// 消化」，而**不問注拼槽之現況**——此點為實測所迫：凡「聲介韻三槽已滿、後續鍵無處可入」者，
  /// 打字機即清空注拼槽、只把該段留在緩衝（實測 `su` 之投影即已清空），故讀注拼槽會漏掉
  /// 整整一類形態。欲求「狂打之讀音素材」者應改用 `mixedAlnumPendingReading`（它另問
  /// 該讀音是否為某讀音之起頭，以免前置之 ASCII 段落被誤認）。
  ///
  /// - Important: 本屬性即 P270 之「待調讀音」判準之原位化身（該 phase 之判準係打字機內之
  ///   `isPendingTonelessReading`）；P273 令其歸位至此，俾狂打側與打字機側共用同一份量測。
  public var mixedAlnumBufferIsTonelessReading: Bool {
    let buffer = mixedAlphanumericalBuffer
    guard !buffer.isEmpty, buffer.count <= maxSingleSyllableKeyCount else { return false }
    guard let reading = canonicalTonelessZhuyinReading(ofBuffer: buffer) else { return false }
    // 「鍵數 == 聲介韻佔用槽數」＝無冗餘鍵：該緩衝**恰為**一個讀音，而非「以別鍵補滿槽位」
    // 之殘段（停用 `enforceCSVTOrdering` 時兩者無從分辨，見
    // `canonicalTonelessZhuyinReading(ofBuffer:)` 之註）。
    var trialComposer = composer
    trialComposer.clear()
    trialComposer.enforceCSVTOrdering = true
    trialComposer.receiveSequence(buffer, isRomaji: false)
    let occupied = [
      trialComposer.consonant.value, trialComposer.semivowel.value, trialComposer.vowel.value,
    ].filter { !$0.isEmpty }.count
    return !reading.isEmpty && occupied == buffer.count
  }

  /// 以試探用之注拼槽副本求「該緩衝**恰為**一個依槽序鍵入之無調讀音」，非者回 `nil`。
  ///
  /// - Important: **須啟用 `enforceCSVTOrdering`**。`receiveSequence` 於任何一鍵被拒時即
  ///   `break`，而**不還原已寫入之槽**——故停用該旗標時，「以別鍵補滿槽位」之殘段會被
  ///   就地吸納而看似合法（實測：`us` 之槽值成 ㄋㄧ、與 `su` 無從分辨）。該旗標使
  ///   「槽序倒退」之鍵被拒，`break` 後留在槽內者即「該緩衝之最長合法槽序前段」，
  ///   其鍵數自然小於緩衝 ⇒ 由呼叫端之「鍵數 == 槽數」判準分辨真偽（見
  ///   `mixedAlnumBufferIsTonelessReading`）。
  /// - Note: 本函式只回「該緩衝所消化出之讀音」，**不**判其是否為真讀音——後者由呼叫端
  ///   以音節索引（`isPrefix`／`isComplete`）把守。
  public func canonicalTonelessZhuyinReading(ofBuffer buffer: String) -> String? {
    var trialComposer = composer
    trialComposer.clear()
    trialComposer.enforceCSVTOrdering = true
    trialComposer.receiveSequence(buffer, isRomaji: false)
    guard trialComposer.isPronounceable, trialComposer.intonation.value.isEmpty else { return nil }
    let reading = trialComposer.consonant.value + trialComposer.semivowel.value
      + trialComposer.vowel.value
    return reading.isEmpty ? nil : reading
  }
}
