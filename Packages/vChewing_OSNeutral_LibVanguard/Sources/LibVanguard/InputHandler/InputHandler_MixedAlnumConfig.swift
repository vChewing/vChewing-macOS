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

// MARK: - MixedAlnumSpaceDuty

/// 中英混打（MixedAlnum）＋注音狂打並存時，一顆**空白鍵**在本拍之歸屬。
///
/// 並存態下空白鍵有兩種歸屬，二者互斥且**皆屬混打層**（故既有之「固化前方讀音」不得再
/// 插手其間）：
///   - `.levelToneConfirmation`：以**陰平**確認該待調讀音（不帶修飾鍵之空白鍵）；
///   - `.asciiCommitEscape`：放棄注音處理、整段混打緩衝以原文遞交（**Shift+Space**）。
///
/// 本型別即該判準之**單一正本**：分診早段（固化塊）與打字機（陰平確認分支）皆消費之。
/// 該二處原本各持一份「逐字相同」之運算式，於新增「修飾鍵」這一維時即生漂移
/// （早段讓位、打字機卻搶鍵 ⇒ 逃生口無從觸發）。
enum MixedAlnumSpaceDuty: Sendable {
  /// 本鍵非並存態之空白鍵 ⇒ 不屬混打層：交還既有流程處置
  /// （純狂打之固化、拼音側之無調確認等）。
  case none
  /// 混打層以陰平聲調確認該待調讀音（見 `confirmMixedAlnumReadingWithLevelTone`）。
  case levelToneConfirmation
  /// 混打層放棄注音處理：整段緩衝以原文遞交、其後附一個半形空格（即 Shift+Space 之逃生口）。
  case asciiCommitEscape

  // MARK: Internal

  /// 混打層是否已接管本拍之空白鍵（無論以陰平確認抑或以 ASCII 逃生口遞交）。
  var isOwnedByMixedAlnumLayer: Bool { self != .none }
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

  /// 混打緩衝區所承載之注音讀音，無則 `nil`——**不拘狂打開關**之量測。
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
  ///      打字機即清空注拼槽、只把該段留在緩衝（實測 `1u`＝ㄅㄧ、`su`／`su;` 之投影皆已清空）。
  ///
  /// - Important: 凡「該緩衝有讀音可示」之**顯示**路徑（如混打之 Tooltip 讀音預覽）應取本值
  ///   ——注拼槽之存亡只是打字機逐鍵消化之副作用（整段未被詞庫採納即被清空），不足為憑。
  ///   狂打之讀音素材則另問併存閘（見 `mixedAlnumPendingReading`）。
  /// 全程以副本求值，**不動任何既有狀態**。
  public var mixedAlnumBufferPendingReading: String? {
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

  /// 回退與注音狂打並存時之「未完成讀音」（狂打之讀音素材）＝`mixedAlnumBufferPendingReading`
  /// 加掛併存閘。
  ///
  /// - Important: 惟**顯示**路徑不得以本值為唯一來源——狂打關閉時本值恆 `nil`，而混打之
  ///   Tooltip 仍須示該緩衝之讀音（見 `mixedAlnumBufferPendingReading` 之註）。
  public var mixedAlnumPendingReading: String? {
    guard mixedAlnumZhuyinFuriousInEffect else { return nil }
    return mixedAlnumBufferPendingReading
  }

  /// 本拍之空白鍵於「中英混打＋注音狂打並存態」下之歸屬（判準之單一正本，見 `MixedAlnumSpaceDuty`）。
  ///
  /// - Important: **Shift 不在陰平確認之列**——Shift 是使用者明示之英文意圖，並存態下
  ///   Shift+Space 之既有語義為「放棄注音處理、逕遞交整段 ASCII ＋ 半形空格」（見
  ///   `MixedAlphanumericalTypewriter`）。若不設此修飾鍵之閘，陰平確認即搶先消費本鍵、
  ///   該逃生口無從觸發（事主實機回報：`su` 之後按 Shift+Space 得陰平確認，而非遞交 `su `）。
  /// - Note: 兩態皆以「緩衝非空 ∧ `mixedAlnumZhuyinFuriousInEffect`」為前提；`.none` 者不屬
  ///   混打層，故分診早段之固化、拼音側之無調確認等一概照舊。判準只問混打緩衝（
  ///   `mixedAlnumPendingReading`），**不問**注拼槽之投影——理由見該屬性之註。
  func mixedAlnumSpaceDuty(isShiftHeld: Bool) -> MixedAlnumSpaceDuty {
    guard mixedAlnumZhuyinFuriousInEffect else { return .none }
    // Shift+Space 之逃生口只以「並存態」為前提：緩衝縱非讀音（如殘段 `us`）亦得整段遞交，
    // 該情境本即既有語義（見 `MixedAlphanumericalTypewriter` 之
    // `commitsWholeMixedBufferOnSpace`）。
    if isShiftHeld { return .asciiCommitEscape }
    return mixedAlnumPendingReading != nil ? .levelToneConfirmation : .none
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
  ///   惟 P273 起該量測一度**無條件**啟用 `enforceCSVTOrdering`，遂令「依槽序鍵入判定讀音」
  ///   之偏好實質失效（always on）；P274 起該旗標**隨該偏好啟停**——停用即回到舊制之計數式
  ///   消化，亂序短令牌（`ls`／`us`）照舊被吸納為讀音。
  public var mixedAlnumBufferIsTonelessReading: Bool {
    let buffer = mixedAlphanumericalBuffer
    guard !buffer.isEmpty, buffer.count <= maxSingleSyllableKeyCount else { return false }
    guard let reading = canonicalTonelessZhuyinReading(ofBuffer: buffer) else { return false }
    // 「鍵數 == 聲介韻佔用槽數」＝無冗餘鍵：該緩衝**恰為**一個讀音，而非「以別鍵補滿槽位」
    // 之殘段。此核對之 `enforceCSVTOrdering` **隨「依槽序鍵入判定讀音」啟停**（見
    // `canonicalTonelessZhuyinReading(ofBuffer:)` 之註）：停用者回到舊制、亂序之鍵被就地吸納。
    var trialComposer = composer
    trialComposer.clear()
    trialComposer.enforceCSVTOrdering = prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder
    trialComposer.receiveSequence(buffer, isRomaji: false)
    let occupied = [
      trialComposer.consonant.value, trialComposer.semivowel.value, trialComposer.vowel.value,
    ].filter { !$0.isEmpty }.count
    return !reading.isEmpty && occupied == buffer.count
  }

  /// 以試探用之注拼槽副本求「該緩衝**恰為**一個依槽序鍵入之無調讀音」，非者回 `nil`。
  ///
  /// - Important: `enforceCSVTOrdering` **隨「依槽序鍵入判定讀音」之偏好啟停**（P274）：
  ///   - 啟用時（預設），`receiveSequence` 於任何一鍵被拒時即 `break`，而**不還原已寫入之槽**
  ///     ——故「以別鍵補滿槽位」之殘段會被就地拒收（實測：`us` 之槽值只餘 ㄧ、與 `su`＝ㄋㄧ
  ///     無從混淆）。「槽序倒退」之鍵被拒後，留在槽內者即「該緩衝之最長合法槽序前段」，
  ///     其鍵數自然小於緩衝 ⇒ 由呼叫端之「鍵數 == 槽數」判準分辨真偽（見
  ///     `mixedAlnumBufferIsTonelessReading`）。
  ///   - 停用時（回到舊制），該旗標**不設**：亂序之鍵就地吸納，「槽序倒退」不復存在
  ///     （`us` 與 `su` 皆消化為 ㄋㄧ），此即聲韻並擊使用者所仰賴之行為。
  /// - Note: 本函式只回「該緩衝所消化出之讀音」，**不**判其是否為真讀音——後者由呼叫端
  ///   以音節索引（`isPrefix`／`isComplete`）把守。
  public func canonicalTonelessZhuyinReading(ofBuffer buffer: String) -> String? {
    var trialComposer = composer
    trialComposer.clear()
    trialComposer.enforceCSVTOrdering = prefs.mixedAlnumJudgeReadingsBySequentialRawKeyOrder
    trialComposer.receiveSequence(buffer, isRomaji: false)
    guard trialComposer.isPronounceable, trialComposer.intonation.value.isEmpty else { return nil }
    let reading = trialComposer.consonant.value + trialComposer.semivowel.value
      + trialComposer.vowel.value
    return reading.isEmpty ? nil : reading
  }
}
