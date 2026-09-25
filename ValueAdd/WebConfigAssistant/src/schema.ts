// 唯音輸入法配置助手 // 後設資料之查詢、型別正規化與前端先驗（與 Swift 側 `UserDef` 之驗證規則對位）。
//
// 前端先驗只是**體驗**：後端（唯音自己）才是權威。故本檔之驗證條件一律從嚴：
// 凡本檔接受者，`UserDef.importFromDictionary(_:)` 亦應接受。

namespace VCA {
  var entryIndex: { [caseName: string]: UserDefEntry } | null = null;
  var rawValueIndex: { [rawValue: string]: UserDefEntry } | null = null;

  /// 取後設資料（由建置器注入之 `VCA_METADATA`）。
  export function metadata(): MetadataFile {
    return VCA_METADATA;
  }

  export function allEntries(): UserDefEntry[] {
    return VCA_METADATA.entries;
  }

  function ensureIndex(): void {
    if (entryIndex !== null && rawValueIndex !== null) return;
    var byKey: { [caseName: string]: UserDefEntry } = {};
    var byRaw: { [rawValue: string]: UserDefEntry } = {};
    var entries = VCA_METADATA.entries;
    for (var i = 0; i < entries.length; i += 1) {
      byKey[entries[i].key] = entries[i];
      byRaw[entries[i].rawValue] = entries[i];
    }
    entryIndex = byKey;
    rawValueIndex = byRaw;
  }

  /// 以 case 名（如 `kUseRearCursorMode`）取後設資料。
  export function entryByKey(caseName: string): UserDefEntry | null {
    ensureIndex();
    var table = entryIndex as { [caseName: string]: UserDefEntry };
    return typeof table[caseName] === "undefined" ? null : table[caseName];
  }

  /// 以 rawValue（如 `UseRearCursorMode`）取後設資料。
  export function entryByRawValue(rawValue: string): UserDefEntry | null {
    ensureIndex();
    var table = rawValueIndex as { [rawValue: string]: UserDefEntry };
    return typeof table[rawValue] === "undefined" ? null : table[rawValue];
  }

  /// 該鍵是否「助手不應觸及」者：黑名單、或型別不受支援。
  export function isTouchable(entry: UserDefEntry): boolean {
    if (entry.exchangeBlacklisted) return false;
    return entry.type !== "dictionary";
  }

  /// 該鍵之可讀標題（取該語系之 `shortTitle`，退而求其次為 rawValue）。
  /// 標題尾端之冒號一律剃除——助手自有排版。
  export function shortTitleOf(entry: UserDefEntry, lang: string): string {
    var labels = entry.labels[lang] || entry.labels["zh-Hant"] || {};
    var title = typeof labels.shortTitle === "string" ? labels.shortTitle : "";
    if (!title) {
      var fallback = entry.labels["zh-Hant"] || {};
      title = typeof fallback.shortTitle === "string" ? fallback.shortTitle : "";
    }
    if (!title) return entry.rawValue;
    return trimTrailingColon(title);
  }

  /// 該鍵之說明（取該語系之 `description`；無者回 `null`）。
  export function descriptionOf(entry: UserDefEntry, lang: string): string | null {
    var labels = entry.labels[lang] || entry.labels["zh-Hant"] || {};
    var text = typeof labels.description === "string" ? labels.description : "";
    if (text) return text;
    var fallback = entry.labels["zh-Hant"] || {};
    var fallbackText = typeof fallback.description === "string" ? fallback.description : "";
    return fallbackText ? fallbackText : null;
  }

  /// 取「非 UserDef 命名空間、但助手也需要」之既有 i18n 標籤（如注音排列選單名稱）。
  export function extraLabel(i18nKey: string, lang: string): string | null {
    var table = VCA_METADATA.extraLabels || {};
    var perLocale = table[lang] || table["zh-Hant"];
    if (!perLocale) return null;
    return typeof perLocale[i18nKey] === "string" ? perLocale[i18nKey] : null;
  }

  /// 該鍵之選項中被 `validNumeralValueRange` 排除者。
  ///
  /// 動機（實測）：三條鍵之 `metaData.options` 超出 `validNumeralValueRange`——
  /// `kSpecifiedNotifyUIColorScheme`（-1 為淺色模式）、`kForceCassetteChineseConversion`（3）、
  /// `kNumPadCharInputBehavior`（3／4／5）。而後端之 `validateAndApply` 對整數一律以
  /// `validNumeralValueRange` 把關，故**產出這些值會令整包匯入失敗**。
  /// 助手一律以「選項 ∩ 值域」為可選集；被排除者不入題。
  export function optionsOutOfRange(entry: UserDefEntry): number[] {
    if (!entry.options || !entry.range) return [];
    var low = entry.range[0];
    var high = entry.range[1];
    var excluded: number[] = [];
    for (var i = 0; i < entry.options.length; i += 1) {
      var value = entry.options[i].value;
      if (value < low || value > high) excluded.push(value);
    }
    return excluded;
  }

  /// 助手可實際採用之選項（已與值域取交集）。
  export function usableOptions(entry: UserDefEntry): OptionEntry[] {
    if (!entry.options) return [];
    var out: OptionEntry[] = [];
    for (var i = 0; i < entry.options.length; i += 1) {
      var value = entry.options[i].value;
      if (entry.range && (value < entry.range[0] || value > entry.range[1])) continue;
      out.push(entry.options[i]);
    }
    return out;
  }

  /// 取某選項值於該語系之標籤。
  export function optionLabel(entry: UserDefEntry, value: number, lang: string): string {
    if (!entry.options) return String(value);
    for (var i = 0; i < entry.options.length; i += 1) {
      if (entry.options[i].value !== value) continue;
      var labels = entry.options[i].labels || {};
      var text = labels[lang];
      if (typeof text === "string" && text) return text;
      var fallback = labels["zh-Hant"];
      if (typeof fallback === "string" && fallback) return fallback;
      return String(value);
    }
    return String(value);
  }

  /// 該鍵之出廠預設值。
  export function defaultValueOf(entry: UserDefEntry): PrefValue | null {
    return entry.default;
  }

  /// 把外部輸入（JSON、表單字串……）正規化為該鍵之合法值；不可能者回 `null`。
  export function coerceValue(entry: UserDefEntry, raw: PrefValue | null | undefined): PrefValue | null {
    if (raw === null || typeof raw === "undefined") return null;
    if (entry.type === "bool") {
      if (typeof raw === "boolean") return raw;
      if (typeof raw === "number") {
        if (raw === 1) return true;
        if (raw === 0) return false;
      }
      return null;
    }
    if (entry.type === "integer") {
      if (typeof raw === "number" && isFinite(raw) && Math.floor(raw) === raw) return raw;
      if (typeof raw === "string" && isIntegerString(raw)) return parseInt(raw, 10);
      return null;
    }
    if (entry.type === "double") {
      if (typeof raw === "number" && isFinite(raw)) return raw;
      if (typeof raw === "string" && isFinite(parseFloat(raw))) return parseFloat(raw);
      return null;
    }
    if (entry.type === "string") {
      if (typeof raw === "string") return raw;
      return null;
    }
    if (entry.type === "arrayOfStrings") {
      if (typeof raw === "string") {
        var parts = raw.split(",");
        var list: string[] = [];
        for (var i = 0; i < parts.length; i += 1) {
          var item = trimSpace(parts[i]);
          if (item) list.push(item);
        }
        return list;
      }
      return null;
    }
    return null;
  }

  /// 驗證該鍵之值。合法回 `null`，否則回錯誤訊息（英文，與 Swift 側之失敗字串同構）。
  export function validateValue(entry: UserDefEntry, value: PrefValue): string | null {
    if (entry.exchangeBlacklisted) return "Blacklisted key";
    if (entry.type === "bool") {
      return typeof value === "boolean" ? null : "Must be a Boolean.";
    }
    if (entry.type === "integer") {
      if (typeof value !== "number" || !isFinite(value) || Math.floor(value) !== value) {
        return "Must be an Integer."
      }
      if (entry.range && (value < entry.range[0] || value > entry.range[1])) {
        return "Must be any Integer within this closed range: [" + entry.range[0] + "..." +
          entry.range[1] + "].";
      }
      return null;
    }
    if (entry.type === "double") {
      if (typeof value !== "number" || !isFinite(value)) return "Must be a Double.";
      if (entry.range && (value < entry.range[0] || value > entry.range[1])) {
        return "Must be any Double within this closed range: [" + entry.range[0] + "..." +
          entry.range[1] + "].";
      }
      return null;
    }
    if (entry.type === "string") {
      if (typeof value !== "string") return "Must be a String.";
      if (entry.key === "kCandidateKeys" && value.length === 0) return "Candidate keys cannot be empty";
      return null;
    }
    if (entry.type === "arrayOfStrings") {
      return isStringArray(value) ? null : "Must be an array of Strings.";
    }
    return "Unsupported type";
  }

  /// 供摘要表顯示之值（該語系）。
  export function formatValue(entry: UserDefEntry, value: PrefValue, lang: string): string {
    if (entry.type === "bool") {
      var boolValue = value === true;
      var options = usableOptions(entry);
      if (options.length > 0) {
        var wanted = boolValue ? 1 : 0;
        for (var i = 0; i < options.length; i += 1) {
          if (options[i].value === wanted) return optionLabel(entry, wanted, lang);
        }
      }
      return boolValue ? t("value.on") : t("value.off");
    }
    if (entry.type === "integer" || entry.type === "double") {
      var numberValue = typeof value === "number" ? value : 0;
      var available = usableOptions(entry);
      for (var j = 0; j < available.length; j += 1) {
        if (available[j].value === numberValue) return optionLabel(entry, numberValue, lang);
      }
      return String(numberValue);
    }
    if (entry.type === "arrayOfStrings") {
      return isStringArray(value) ? (value as string[]).join(", ") : String(value);
    }
    return String(value);
  }

  /// 版本碼：`major * 100 + minor`（macOS 10.9 ⇒ 1090、10.15 ⇒ 1015、12.6 ⇒ 1206）。
  ///
  /// **為何不用浮點數**：`10.9` 在數值上等於 10.90，**大於** 10.15——若以浮點比較，
  /// Catalina（10.15）會被判得比 Mavericks（10.9）還舊，而把幾乎所有選項誤判為
  /// 「需要較新系統」。此缺陷由 DOM 冒煙測試抓到，故一律以整數版本碼比較。
  export function osVersionCode(major: number, minor: number): number {
    return major * 100 + minor;
  }

  /// 把後設資料之 `minimumOS`（浮點字面值，如 `10.15`）轉為版本碼。
  ///
  /// 作法是**依字面值之字串**拆位，而非算術抽出小數：`10.9` 之 minor 是 9（⇒ 1009）、
  /// `10.15` 之 minor 是 15（⇒ 1015）——若以 `(value - floor) * 100` 取之，`10.9` 會得 90
  /// 而與 `10.15` 之 15 無法比較。
  export function osVersionCodeFromDouble(value: number): number {
    var text = String(value);
    var dot = text.indexOf(".");
    var major = parseInt(dot < 0 ? text : text.slice(0, dot), 10);
    var minor = dot < 0 ? 0 : parseInt(text.slice(dot + 1), 10);
    if (!isFinite(major)) return 0;
    if (!isFinite(minor)) minor = 0;
    return osVersionCode(major, minor);
  }

  /// 版本碼之顯示字串（供提示文案用）。
  export function formatOSCode(code: number): string {
    var major = Math.floor(code / 100);
    var minor = code % 100;
    return minor === 0 ? String(major) : major + "." + minor;
  }

  /// 由 `navigator.userAgent` 解析 macOS 版本碼；無法解析者回 `null`。
  export function osVersionFromUA(userAgent: string | null): number | null {
    if (!userAgent) return null;
    var marker = userAgent.indexOf("Mac OS X ");
    if (marker < 0) return null;
    var rest = userAgent.slice(marker + "Mac OS X ".length);
    var end = rest.search(/[;)]/);
    if (end >= 0) rest = rest.slice(0, end);
    var parts = rest.replace(/_/g, ".").split(".");
    if (parts.length < 2) return null;
    var major = parseInt(parts[0], 10);
    var minor = parseInt(parts[1], 10);
    if (!isFinite(major) || !isFinite(minor)) return null;
    return osVersionCode(major, minor);
  }

  // MARK: - 小工具（一律自寫，以符 ES5 之標準庫範圍）

  function trimTrailingColon(text: string): string {
    var result = text;
    while (result.length > 0) {
      var last = result.charAt(result.length - 1);
      if (last === ":" || last === "：" || last === " " || last === "　") {
        result = result.slice(0, -1);
        continue;
      }
      break;
    }
    return result;
  }

  function trimSpace(text: string): string {
    return text.replace(/^[\s\u3000]+/, "").replace(/[\s\u3000]+$/, "");
  }

  function isIntegerString(text: string): boolean {
    return /^-?[0-9]+$/.test(text);
  }

  function isStringArray(value: PrefValue): boolean {
    if (!isArray(value)) return false;
    var list = value as string[];
    for (var i = 0; i < list.length; i += 1) {
      if (typeof list[i] !== "string") return false;
    }
    return true;
  }

  function isArray(value: PrefValue): boolean {
    return Object.prototype.toString.call(value) === "[object Array]";
  }
}
