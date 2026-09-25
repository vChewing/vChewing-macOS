// 唯音輸入法配置助手 // 配置包之生成（純函式，核心可測件）。
//
// 產出規則（與唯音之 `UserDef` 交換格式契約對位）：
//   ① **稀疏**：只輸出使用者明確表態之鍵。
//   ② 型別、值域皆依後設資料；凡本檔接受者，後端亦應接受。
//   ③ 根層中介辭典 `__UserDefMeta`（`title`／`description`）置於最前。
//   ④ 鍵序依 `UserDef.allCases` 之宣告序（＝後設資料之 `entries` 序）。
//   ⑤ 黑名單鍵、未知鍵一律不輸出。

namespace VCA {
  /// 生成配置包之輸入。
  export interface PresetBuildInput {
    answers: AnswerMap;
    title: string;
    description: string;
  }

  /// 已接受之單筆設定。
  export interface AcceptedPreference {
    entry: UserDefEntry;
    value: PrefValue;
  }

  /// 被拒之單筆設定（正常情況下為空；有者即為助手之缺陷）。
  export interface RejectedPreference {
    key: string;
    reason: string;
  }

  /// 生成結果。
  export interface PresetBuildResult {
    object: { [key: string]: PrefValue | { [member: string]: string } };
    accepted: AcceptedPreference[];
    rejected: RejectedPreference[];
    json: string;
  }

  /// 中介辭典之鍵（與 Swift 側 `UserDef.jsonExchangeMetaKey` 同值）。
  export var META_KEY: string = "__UserDefMeta";

  /// 建構中介辭典。
  export function buildMetaDictionary(title: string, description: string): { [member: string]: string } {
    var meta: { [member: string]: string } = {};
    meta["title"] = title;
    meta["description"] = description;
    return meta;
  }

  /// 由答案集生成配置包（物件 ＋ 縮排 2 格之 JSON 字串）。
  export function buildPreset(input: PresetBuildInput): PresetBuildResult {
    var accepted: AcceptedPreference[] = [];
    var rejected: RejectedPreference[] = [];
    var object: { [key: string]: PrefValue | { [member: string]: string } } = {};

    object[META_KEY] = buildMetaDictionary(input.title, input.description);

    // 依宣告序輸出（＝後設資料之 entries 序），而非依答案之插入序。
    var entries = allEntries();
    for (var i = 0; i < entries.length; i += 1) {
      var entry = entries[i];
      if (typeof input.answers[entry.rawValue] === "undefined") continue;
      var raw = input.answers[entry.rawValue];
      if (entry.exchangeBlacklisted) {
        rejected.push({ key: entry.rawValue, reason: "Blacklisted key" });
        continue;
      }
      var coerced = coerceValue(entry, raw);
      if (coerced === null) {
        rejected.push({ key: entry.rawValue, reason: "Unsupported value" });
        continue;
      }
      var failure = validateValue(entry, coerced);
      if (failure !== null) {
        rejected.push({ key: entry.rawValue, reason: failure });
        continue;
      }
      object[entry.rawValue] = coerced;
      accepted.push({ entry: entry, value: coerced });
    }

    // 未知鍵（理論上不會發生）亦一併回報。
    var raws = Object.keys(input.answers);
    for (var j = 0; j < raws.length; j += 1) {
      if (entryByRawValue(raws[j])) continue;
      rejected.push({ key: raws[j], reason: "Unknown key" });
    }

    return {
      object: object,
      accepted: accepted,
      rejected: rejected,
      json: JSON.stringify(object, null, 2),
    };
  }

  /// 某一頁之「以推薦值補齊」所會加入之鍵值（純查詢，不修改任何狀態）。
  ///
  /// 判準：該題未被表態、且依 profile 有推薦值（無推薦值者以出廠預設值補之）。
  export function fillSuggestions(step: Step, state: AssistantState): { [rawValue: string]: PrefValue } {
    var additions: { [rawValue: string]: PrefValue } = {};
    for (var i = 0; i < step.questions.length; i += 1) {
      var question = step.questions[i];
      var entry = question.entry;
      if (!entry) continue;
      if (typeof state.answers[entry.rawValue] !== "undefined") continue;
      var recommended = effectiveRecommended(question, state.profile);
      if (recommended === null) recommended = defaultValueOf(entry);
      if (recommended === null) continue;
      var coerced = coerceValue(entry, recommended);
      if (coerced === null) continue;
      if (validateValue(entry, coerced) !== null) continue;
      additions[entry.rawValue] = coerced;
    }
    return additions;
  }

  /// 答案集之統計（供測試與除錯）。
  export function describeAnswers(answers: AnswerMap): { key: string; value: PrefValue }[] {
    var out: { key: string; value: PrefValue }[] = [];
    var entries = allEntries();
    for (var i = 0; i < entries.length; i += 1) {
      var entry = entries[i];
      if (typeof answers[entry.rawValue] === "undefined") continue;
      out.push({ key: entry.rawValue, value: answers[entry.rawValue] });
    }
    return out;
  }
}
