// 唯音輸入法配置助手 // 起始配置（＝官網既有策展知識之一次套用）。
//
// 事主 2026-09-25（Phase 245）：使用者選妥自己熟悉的輸入法之後，助手應先給出一組
// 現成的「起始配置」供其套用，並在該頁提醒：套用之後即可結束助手，除非想要更細緻的配置。
//
// 設計立場：**起始配置不另立一份題庫**——其「指名」之內容即 `questions.ts` 之推薦值表
// （`recommendationFor`）對當前 profile 之全集。理由有二：
//   ① 單一真源：逐題頁面上標示的「推薦值」與起始配置所寫入者必然同值，不會出現
//      「起始配置寫了 A、題目卻推薦 B」之分歧（助手之措辭與值永不互斥）。
//   ② 可回溯：套用之後，使用者在逐題頁面看到的就是同一組值（已選中），可逐項改回
//      「維持不變」；取消套用則整組撤回。
//
// **封閉性（事主 2026-09-25 第二輪指示：同一台電腦上多人來回切換配置時不得互相干擾）**：
// 唯音之匯入語意是「**只寫入包內出現的鍵**」，故若 A 套用了某組配置、B 再套用另一組而
// 後者未提及 A 曾寫入之鍵，A 的值就會殘留給 B——實測最惡者為 `kCassetteEnabled`：A 是
// 行列三十（磁帶）使用者時它為 `true`，而該鍵一旦為真**會停用注音輸入**，B 為注音使用者
// 時即當場壞掉。故本檔之起始配置一律**封閉於一組固定的鍵全集**（`starterUniverse()`）：
//   · 全集內、本組配置有推薦值者 ⇒ 寫入該值（「指名」）；
//   · 全集內、本組配置無推薦值者 ⇒ 寫入**唯音之出廠預設值**（「回歸」）。
// 於是任兩組配置所寫入之鍵集**完全相同**（僅值有別），後套用者必然完整覆蓋先套用者；
// 而全集之外的一切偏好（選字窗字級、熱鍵、通知……）一概不碰——那屬於使用者自己，
// 不是「打字風格」之一部分。
//
// 兩條既有約束照舊：只收**真有依據**之推薦值（`effectiveRecommended` 非 `null` 者），
// 且一律經 `coerceValue` ＋ `validateValue` 過濾——故凡本檔產出者，唯音後端皆收得下。

namespace VCA {
  /// 一組起始配置。
  export interface StarterPreset {
    /// 依 profile 決定之識別碼（`origin|typing`）；供測試與除錯。
    id: string;
    origin: string;
    typing: string;
    /// 將寫入之鍵（rawValue），依題庫之頁序——**任兩組配置皆同此鍵集**（見檔首之封閉性）。
    keys: string[];
    /// 鍵值（rawValue → 值）。
    values: { [rawValue: string]: PrefValue };
    /// 其中由本組配置**指名**者（餘者為「回歸出廠預設」）。
    namedKeys: string[];
    /// 其中由本組配置**回歸唯音出廠預設**者。
    resetKeys: string[];
  }

  /// 起始配置之**鍵全集**：任何一組配置都可能指名之鍵的聯集（依題庫之頁序）。
  ///
  /// 一律以「還不確定」之題庫取之——分支題在該 profile 下一律出題，故其為超集；
  /// 來源不影響出題與否，故取任一來源即可。系統版本之過濾照舊（`minimumOS` 高於當前
  /// 系統者不入全集）：舊系統上根本不生效的鍵，寫了也只是噪音。
  export function starterUniverse(osVersion: number | null): Question[] {
    var questions = allQuestionsFor({ origin: "newbie", typing: "unsure" }, osVersion);
    var out: Question[] = [];
    for (var i = 0; i < questions.length; i += 1) {
      if (!questions[i].entry) continue;
      if (!hasAnyRecommendation(questions[i])) continue;
      out.push(questions[i]);
    }
    // 題庫之外、但起始配置得指名之鍵（見 questions.ts 之 `PRESET_ONLY_KEYS`）：
    // 它們不出題，卻同樣屬於「打字風格」而須納入封閉性——否則 app 內按過「我姓ㄅ」
    // 之後再由助手匯入注音組句之配置，關聯詞語模式即會殘留。
    var extras = presetOnlyQuestions();
    for (var j = 0; j < extras.length; j += 1) {
      if (osVersion !== null && extras[j].minimumOS > osVersion) continue;
      out.push(extras[j]);
    }
    return out;
  }

  /// 該題是否有**任何**一種 profile 會給出推薦值（＝該鍵是否屬全集）。
  function hasAnyRecommendation(question: Question): boolean {
    if (question.recommended !== null) return true;
    if (question.recommendedByTyping !== null) return true;
    if (question.recommendedByOrigin !== null) return true;
    return false;
  }

  /// 起始配置實際**寫入**之鍵：兩段中未被使用者逐項取消勾選者。
  ///
  /// `excludedNamed`／`excludedReset` 為使用者於起始配置頁逐項取消勾選之鍵（rawValue → true）；
  /// **預設皆為空**（＝全選），故不傳亦得全集。被取消者即不予更動——即回復「稀疏」之舉，
  /// 取捨之說明見 i18n 之 `starter.namedNoteOff`／`starter.resetNoteOff`。
  export function starterWrittenKeys(
    starter: StarterPreset,
    excludedNamed?: { [rawValue: string]: boolean },
    excludedReset?: { [rawValue: string]: boolean }
  )
    : string[] {
    var named = excludedNamed || {};
    var reset = excludedReset || {};
    var out: string[] = [];
    var i = 0;
    for (i = 0; i < starter.namedKeys.length; i += 1) {
      if (named[starter.namedKeys[i]] === true) continue;
      out.push(starter.namedKeys[i]);
    }
    for (i = 0; i < starter.resetKeys.length; i += 1) {
      if (reset[starter.resetKeys[i]] === true) continue;
      out.push(starter.resetKeys[i]);
    }
    return out;
  }

  /// 該段中已被使用者取消勾選之鍵數。
  export function excludedKeyCount(keys: string[], excluded?: { [rawValue: string]: boolean }): number {
    var table = excluded || {};
    var count = 0;
    for (var i = 0; i < keys.length; i += 1) {
      if (table[keys[i]] === true) count += 1;
    }
    return count;
  }

  /// 該 profile（含系統版本）之起始配置。
  export function starterFor(profile: Profile, osVersion: number | null): StarterPreset {
    var universe = starterUniverse(osVersion);
    var values: { [rawValue: string]: PrefValue } = {};
    var keys: string[] = [];
    var namedKeys: string[] = [];
    var resetKeys: string[] = [];
    for (var i = 0; i < universe.length; i += 1) {
      var entry = universe[i].entry as UserDefEntry;
      var recommended = effectiveRecommended(universe[i], profile);
      var isNamed = recommended !== null;
      // 未指名者回歸出廠預設（見檔首之封閉性）。
      if (!isNamed) recommended = defaultValueOf(entry);
      var coerced = coerceValue(entry, recommended);
      if (coerced === null) continue;
      if (validateValue(entry, coerced) !== null) continue;
      values[entry.rawValue] = coerced;
      keys.push(entry.rawValue);
      if (isNamed) {
        namedKeys.push(entry.rawValue);
      } else {
        resetKeys.push(entry.rawValue);
      }
    }
    return {
      id: profile.origin + "|" + profile.typing,
      origin: profile.origin,
      typing: profile.typing,
      keys: keys,
      values: values,
      namedKeys: namedKeys,
      resetKeys: resetKeys,
    };
  }
}
