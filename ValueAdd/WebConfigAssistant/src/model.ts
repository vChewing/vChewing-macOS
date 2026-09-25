// 唯音輸入法配置助手 // 資料模型（與 assets/userdef-metadata.json 之 schema 對位）。

namespace VCA {
  /// 偏好值：與 `UserDef.DataType` 之六種載荷對位。
  export type PrefValue = boolean | number | string | string[] | { [key: string]: boolean };

  /// 每個 UserDef case 之可本地化欄位（由 app 之 `.strings` 導出）。
  export interface EntryLabels {
    shortTitle?: string;
    prompt?: string;
    inlinePrompt?: string;
    popupPrompt?: string;
    description?: string;
    toolTip?: string;
  }

  /// 單選題之選項：值 ＋ 各語系之已翻譯標籤。
  export interface OptionEntry {
    value: number;
    i18nKey: string;
    labels: { [locale: string]: string | null };
  }

  /// 一條 `UserDef` 之後設資料。
  export interface UserDefEntry {
    key: string;
    rawValue: string;
    type: string;
    defaultsType: string;
    default: PrefValue | null;
    range: number[] | null;
    minimumOS: number;
    exchangeBlacklisted: boolean;
    metadataPending: boolean;
    metadataPendingReason: string;
    options: OptionEntry[] | null;
    optionsKind: string | null;
    labels: { [locale: string]: EntryLabels };
  }

  /// 後設資料檔之根物件（`vChewingSharedCLI dump-userdef-metadata` 之產物）。
  export interface MetadataFile {
    schemaVersion: number;
    generator: string;
    locales: string[];
    count: number;
    entries: UserDefEntry[];
    missingI18nKeys: { locale: string; key: string }[];
    pendingMetadataKeys: string[];
    extraLabelPrefixes: string[];
    extraLabels: { [locale: string]: { [key: string]: string } };
  }

  /// 單一鍵盤排列（注音／拼音）。
  export interface KeyboardParserEntry {
    name: string;
    value: number;
    i18nKey: string;
  }

  /// 設定介面曝露面之執行期段落（其餘段落屬建置期與測試之用）。
  export interface SettingsSurface {
    keyboardParsers: {
      /// 設定介面在此些值之前插入分隔（如注音之 7 與拼音之 100）。
      dividerBefore: number[];
      zhuyin: KeyboardParserEntry[];
      pinyin: KeyboardParserEntry[];
    };
  }

  /// 助手所適配之輸入法版本（取自本目錄之 `version.txt`）。
  export interface TargetVersion {
    version: string;
    build: string;
    /// 顯示用（如 `4.8.4 (4840)`，與 app 既有之「版本 (Build)」寫法一致）。
    display: string;
  }

  /// 使用者於助手內之側寫（僅影響「推薦值」與出題與否，本身不輸出任何鍵）。
  export interface Profile {
    origin: string;
    typing: string;
  }

  /// 已表態之答案：rawValue → 值。
  export interface AnswerMap {
    [rawValue: string]: PrefValue;
  }

  /// 助手的整體狀態。
  export interface AssistantState {
    lang: string;
    stepIndex: number;
    profile: Profile;
    /// 將被輸出之答案：rawValue → 值（唯一真源）。
    answers: AnswerMap;
    /// 使用者**親自**表態過之鍵（供「以推薦值補齊」之撤銷判定）。
    manual: { [rawValue: string]: boolean };
    /// 每一頁曾由「以推薦值補齊」加入之鍵（供撤銷）。
    fillAdded: { [stepID: string]: string[] };
    /// 是否已套用該 profile 之「起始配置」（見 starter.ts）。
    ///
    /// **預設為真**（事主 2026-09-25：「使用者叫出這個配置畫面就是為了想切換配置的」）——
    /// 故該頁之取捨項預設選中「套用這組起始配置」，使用者若要稀疏之包須主動改選「不套用」。
    starterOn: boolean;
    /// 曾由起始配置寫入、且使用者尚未親自改過之鍵（供「取消套用」時撤回）。
    starterAdded: { [rawValue: string]: boolean };
    /// 起始配置之「指名」段中，被使用者**逐項取消勾選**之鍵（rawValue → true；預設為空＝全選）。
    starterNamedOff: { [rawValue: string]: boolean };
    /// 起始配置之「回歸出廠預設」段中，被使用者**逐項取消勾選**之鍵（rawValue → true）。
    ///
    /// **預設為空**（＝全選）：本組未指名之相關鍵一律一併寫入唯音之出廠預設值，以免同一台
    /// 電腦上他人（或自己先前）套用過之配置殘留；使用者可就任何一項取消勾選。
    starterResetOff: { [rawValue: string]: boolean };
    /// 是否只套用起始配置：勾選者跳過後面之逐項問題（全流程遂為四頁）。
    expressOnly: boolean;
    /// 由「跳到摘要」跳轉前所在之頁（-1 ＝ 非跳轉而來）；供「上一步」原路折返。
    skipFromIndex: number;
    metaTitle: string;
    metaDescription: string;
    fillRecommended: { [stepID: string]: boolean };
    jsonVisible: boolean;
  }

  /// 助手自身介面文案之字串表（四語系）。
  export interface UIStringTable {
    [key: string]: string;
  }
}
