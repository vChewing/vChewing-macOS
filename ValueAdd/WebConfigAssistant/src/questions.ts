// 唯音輸入法配置助手 // 題庫（分支問卷）。
//
// 設計立場：題庫**不新造**，而是把官網既有的策展知識（`onboarding/*.md`、`manual/preferences.md`）
// 可執行化。每一題的標題與說明一律取自 app 自己的 `.strings`（經後設資料導出）；
// 本檔只負責「分頁、排序、分支、推薦值」。
//
// 兩條不可退讓之約束：
//   ① 每個單選題之預設選項一律為「維持不變」——未表態者不輸出任何鍵。
//   ② 助手不得產出後端會拒收的值（故選項一律與 `validNumeralValueRange` 取交集）。

namespace VCA {
  /// 單一選項：值 ＋ 標籤來源。
  export interface QuestionChoice {
    /// 實際會輸出之值。
    value: PrefValue;
    /// 若該選項源自後設資料之 `options`：其數值（供 `optionLabel` 查標籤）。
    optionValue: number | null;
    /// 助手自身 i18n 之鍵（如 `value.on`）。
    labelKey: string | null;
    /// app 既有 i18n 之鍵（如 `i18n:KeyboardLayout.IBM`，經 `extraLabels` 查表）。
    i18nKey: string | null;
    /// 是否於此選項之前插一條分隔線（與設定介面之分組一致）。
    separatorBefore: boolean;
  }

  /// 單一題目。
  export interface Question {
    id: string;
    /// 對應之 `UserDef`；分支樞紐之自訂題為 `null`（不輸出任何鍵）。
    entry: UserDefEntry | null;
    /// `custom`／`bool`／`enum`／`number`／`text`／`strings`
    kind: string;
    titleKey: string | null;
    helpKey: string | null;
    choices: QuestionChoice[];
    range: number[] | null;
    recommended: PrefValue | null;
    recommendedByTyping: { [typing: string]: PrefValue } | null;
    recommendedByOrigin: { [origin: string]: PrefValue } | null;
    /// 僅在這些打字方式下出題（`null` ＝ 一律出題；「unsure」一律出題）。
    showForTyping: string[] | null;
    minimumOS: number;
  }

  /// 一頁。
  export interface Step {
    id: string;
    glyph: string;
    titleKey: string;
    introKey: string;
    optional: boolean;
    docPath: string;
    questions: Question[];
    /// 因系統版本過舊而未出題之題數（供該頁說明用）。
    skippedByOS: number;
  }

  /// 版本碼之下限（macOS 10.9 ⇒ 1009）。見 schema.ts 之 `osVersionCode`。
  var MINIMUM_OS_FLOOR: number = 1009;

  /// **助手之題庫不得觸及「設定介面未曝露」之選項（事主 2026-09-24 立規）**。
  ///
  /// 判準：凡未出現於 `vChewing_SettingsUI` 之 `SettingsUI/`（SwiftUI）或 `SettingsCocoa/`
  /// （AppKit）者，即使用者無從於設定介面自行調整，助手亦不應過問——以免問出使用者
  /// 在設定介面內找不到、因而無法自行復原的項目。此清單由 `tools/settings-surface.mjs`
  /// 掃描那兩個目錄之源碼生成（`assets/settings-surface.json`），並由
  /// `tests/questions.test.js` 以「題庫 ⊆ 曝露面」之不變式守住。
  ///
  /// 依此規去過者（2026-09-24）：`kCandidateTextFontName`（事主明示：使用者亂填字型名稱
  /// 可能導致部分候選字無法正常顯示）、`kAssociatedPhrasesEnabled`、
  /// `kCurrencyNumeralsEnabled`、`kHalfWidthPunctuationEnabled`、`kPinyinTypingEnabled`
  /// ——此五者僅見於輸入法選單或其熱鍵開關，設定介面本身並不曝露。

  /// 各「原本使用之輸入法」對應之官網文章（`permalink` 之實查值；相對 `DOC_BASE`）。
  export var DOC_PATH_BY_ORIGIN: { [origin: string]: string } = {
    macoszhuyin: "manual/onboarding_macOSZhuyinSinceSnowLeopard.html",
    msnewphonetic: "manual/onboarding_msnewphonetic.html",
    kimo: "manual/onboarding_kimo.html",
    mcbpmf: "manual/onboarding_mcbpmf.html",
    ov: "manual/onboarding_ov.html",
    hanin: "manual/onboarding_hanin.html",
    goingime: "manual/onboarding_goingime.html",
    asus: "manual/onboarding_asus.html",
    cin: "manual/onboarding_array30.html",
    pinyin: "manual/onboarding_pinyinsimp.html",
    newbie: "onboarding/",
  };

  /// 各「原本使用之輸入法」於來源頁顯示之接待說明（`null` ＝ 不顯示）。
  ///
  /// macOS 內建注音一支取自〈寫給 macOS 10.6 開始的內建注音輸入法的使用者〉之要旨：
  /// **唯音的預設值即照 macOS 10.9 起之內建注音的習慣**，故該支多半無須改動任何設定。
  export var NOTE_KEY_BY_ORIGIN: { [origin: string]: string } = {
    macoszhuyin: "origin.note.macoszhuyin",
  };

  /// 該頁於當前狀態下之「深入說明 →」目標。
  export function docPathFor(step: Step, state: AssistantState): string {
    if (step.id === "background") {
      var byOrigin = DOC_PATH_BY_ORIGIN[state.profile.origin];
      if (byOrigin) return byOrigin;
    }
    return step.docPath;
  }

  /// 「您原本用哪一款輸入法？」之選項值（分支樞紐，本身不輸出任何鍵）。
  export var ORIGIN_VALUES: string[] = [
    "macoszhuyin", "msnewphonetic", "kimo", "mcbpmf", "ov", "hanin",
    "goingime", "asus", "cin", "pinyin", "newbie",
  ];

  /// 「您主要用哪一種打字方式？」之選項值。
  export var TYPING_VALUES: string[] = ["zhuyin", "scpc", "pinyin", "cin", "unsure"];

  // MARK: - 選項與題目之建構器

  function choiceOf(
    value: PrefValue,
    optionValue: number | null,
    labelKey: string | null,
    i18nKey: string | null,
    separatorBefore?: boolean
  )
    : QuestionChoice {
    return {
      value: value, optionValue: optionValue, labelKey: labelKey, i18nKey: i18nKey,
      separatorBefore: separatorBefore === true,
    };
  }

  function customQuestion(
    id: string,
    titleKey: string,
    helpKey: string,
    optionKeyPrefix: string,
    values: string[]
  )
    : Question {
    var choices: QuestionChoice[] = [];
    for (var i = 0; i < values.length; i += 1) {
      choices.push(choiceOf(values[i], null, optionKeyPrefix + values[i], null));
    }
    return {
      id: id, entry: null, kind: "custom",
      titleKey: titleKey, helpKey: helpKey, choices: choices, range: null,
      recommended: null, recommendedByTyping: null, recommendedByOrigin: null,
      showForTyping: null, minimumOS: MINIMUM_OS_FLOOR,
    };
  }

  function questionFor(
    entry: UserDefEntry,
    kind: string,
    choices: QuestionChoice[],
    recommendation: { value: PrefValue | null; typing: { [k: string]: PrefValue } | null; origin: { [k: string]: PrefValue } | null }
  )
    : Question {
    return {
      id: entry.key, entry: entry, kind: kind,
      titleKey: null, helpKey: null, choices: choices, range: entry.range,
      recommended: recommendation.value,
      recommendedByTyping: recommendation.typing,
      recommendedByOrigin: recommendation.origin,
      showForTyping: null, minimumOS: osVersionCodeFromDouble(entry.minimumOS),
    };
  }

  // MARK: - 推薦值
  //
  // 刻意**從嚴**：只收官網既有策展文章明載之兩條處方（《新手上路》之「逐字選字（ㄅ半派）」
  // 與「微軟新注音」），外加同篇分支所暗示之四條（拼音派開拼音、CIN 派開磁帶、漢音符號表）。
  // 其餘一律不推薦——助手不替他人生產沒有依據的立場；日後經事主核定題庫時再行擴充。

  function recommendationFor(key: string)
    : { value: PrefValue | null; typing: { [k: string]: PrefValue } | null; origin: { [k: string]: PrefValue } | null } {
    var none = { value: null, typing: null, origin: null };
    switch (key) {
    case "kUseSCPCTypingMode":
      return { value: null, typing: { scpc: true }, origin: null };
    case "kCandidateKeys":
      return { value: null, typing: { scpc: "123456789" }, origin: null };
    case "kUseHorizontalCandidateList":
      return { value: null, typing: { scpc: false }, origin: null };
    case "kCandidateWindowShowOnlyOneLine":
      return { value: null, typing: { scpc: true }, origin: null };
    case "kEnforceSingleLineCandidateWindowLayout4SCPC":
      return { value: null, typing: { scpc: true }, origin: null };
    case "kAlsoConfirmAssociatedCandidatesByEnter":
      return { value: null, typing: { scpc: true }, origin: null };
    // 選字游標之位置：微軟新注音派在後方；macOS 內建注音派在前方（與唯音預設同）。
    case "kUseRearCursorMode":
      return { value: null, typing: null, origin: { msnewphonetic: true, macoszhuyin: false } };
    // 聲調鍵覆寫字音：macOS 內建注音之習慣（值 0）；唯音預設亦為 0。
    case "kSpecifyIntonationKeyBehavior":
      return { value: null, typing: null, origin: { macoszhuyin: 0 } };
    case "kClassicHaninKeyboardSymbolModeShortcutEnabled":
      return { value: null, typing: null, origin: { hanin: true } };
    case "kCassetteEnabled":
      return { value: null, typing: { cin: true }, origin: null };
    default:
      return none;
    }
  }

  // MARK: - 逐鍵生成

  /// 由單一 `UserDef` 生成題目；回 `null` 者不出題（黑名單、型別不受支援、無值域之數值鍵）。
  function entryQuestion(caseName: string): Question | null {
    var entry = entryByKey(caseName);
    if (!entry || !isTouchable(entry)) return null;
    var recommendation = recommendationFor(caseName);
    if (entry.type === "bool") {
      var boolChoices: QuestionChoice[] = [];
      var options = usableOptions(entry);
      if (options.length === 2) {
        // bool 鍵之 option 值域為 0/1：0 ⇒ false、1 ⇒ true。
        boolChoices.push(choiceOf(options[0].value === 1, options[0].value, null, null));
        boolChoices.push(choiceOf(options[1].value === 1, options[1].value, null, null));
      } else {
        boolChoices.push(choiceOf(true, null, "value.on", null));
        boolChoices.push(choiceOf(false, null, "value.off", null));
      }
      return questionFor(entry, "bool", boolChoices, recommendation);
    }
    if (entry.type === "integer" || entry.type === "double") {
      var numericOptions = usableOptions(entry);
      if (numericOptions.length > 0) {
        var enumChoices: QuestionChoice[] = [];
        for (var i = 0; i < numericOptions.length; i += 1) {
          enumChoices.push(choiceOf(numericOptions[i].value, numericOptions[i].value, null, null));
        }
        return questionFor(entry, "enum", enumChoices, recommendation);
      }
      if (!entry.range) return null;
      return questionFor(entry, "number", [], recommendation);
    }
    if (entry.type === "string") return questionFor(entry, "text", [], recommendation);
    if (entry.type === "arrayOfStrings") return questionFor(entry, "strings", [], recommendation);
    return null;
  }

  /// 注音／拼音排列之題目。
  ///
  /// 該兩條鍵之標籤**不在** `UserDef.metaData.options` 內——其選單名稱由
  /// `KeyboardParser.localizedMenuName` 供出，且設定介面是以 `KeyboardParser.allCases`
  /// 之**宣告序**列示（並在特定值之前插分隔線）。故本函式一律取用
  /// `tools/settings-surface.mjs` 自 app 源碼抽出、經建置注入之 `VCA_SURFACE.keyboardParsers`：
  /// **順序、標籤、分隔線三者皆與設定介面同源**，助手不再手抄（事主 2026-09-24 指示：
  /// 「注音排列的 option 順序請調整得跟輸入法 settingsUI 一致」）。
  function parserQuestion(caseName: string, side: string): Question | null {
    var entry = entryByKey(caseName);
    if (!entry || !isTouchable(entry)) return null;
    var spec = VCA_SURFACE.keyboardParsers;
    var list: KeyboardParserEntry[] = side === "pinyin" ? spec.pinyin : spec.zhuyin;
    var choices: QuestionChoice[] = [];
    for (var i = 0; i < list.length; i += 1) {
      // 首項之前的分隔線省略——清單之首無從標示分界（設定介面之拼音清單即如此）。
      var separatorBefore = i > 0 && spec.dividerBefore.indexOf(list[i].value) >= 0;
      choices.push(choiceOf(list[i].value, list[i].value, null, list[i].i18nKey, separatorBefore));
    }
    return questionFor(entry, "enum", choices, recommendationFor(caseName));
  }

  function questionsWithOverrides(): { [caseName: string]: Question } {
    var table: { [caseName: string]: Question } = {};

    var zhuyin = parserQuestion("kKeyboardParser4Zhuyin", "zhuyin");
    if (zhuyin) {
      zhuyin.showForTyping = ["zhuyin", "scpc"];
      table["kKeyboardParser4Zhuyin"] = zhuyin;
    }

    var pinyin = parserQuestion("kKeyboardParser4Pinyin", "pinyin");
    if (pinyin) {
      pinyin.showForTyping = ["pinyin"];
      pinyin.recommendedByTyping = { pinyin: 100 };
      table["kKeyboardParser4Pinyin"] = pinyin;
    }

    // 逐題之分支限定。
    limitTyping(table, ["kCassetteEnabled", "kShowTranslatedStrokesInCompositionBuffer",
      "kAutoCompositeWithLongestPossibleCassetteKey", "kForceCassetteChineseConversion"], ["cin"]);
    limitTyping(table, ["kUseSCPCTypingMode", "kUseSpaceToCommitHighlightedCandidate4SCPC",
      "kEnforceSingleLineCandidateWindowLayout4SCPC"], ["scpc"]);

    return table;
  }

  /// 令指定之鍵只在特定打字方式下出題（表內無者即時生成）。
  function limitTyping(table: { [caseName: string]: Question }, keys: string[], typing: string[]): void {
    for (var i = 0; i < keys.length; i += 1) {
      var question = table[keys[i]];
      if (!question) {
        question = entryQuestion(keys[i]) as Question;
        if (!question) continue;
        table[keys[i]] = question;
      }
      question.showForTyping = typing;
    }
  }

  /// 取題目：自訂題以外一律走此表（含覆寫與分支限定）。
  function questionForCase(
    table: { [caseName: string]: Question }, caseName: string
  )
    : Question | null {
    if (typeof table[caseName] !== "undefined") return table[caseName];
    var generated = entryQuestion(caseName);
    if (generated) table[caseName] = generated;
    return generated;
  }

  // MARK: - 分頁定義

  interface StepSeed {
    id: string;
    glyph: string;
    docPath: string;
    optional: boolean;
    questions: Question[];
  }

  function stepSeeds(): StepSeed[] {
    var table = questionsWithOverrides();

    var origin = customQuestion("origin", "origin.title", "origin.intro", "origin.opt.", ORIGIN_VALUES);
    var typing = customQuestion("typing", "typing.title", "typing.intro", "typing.opt.", TYPING_VALUES);

    var seeds: StepSeed[] = [];
    seeds.push(seedOf("background", "問", "onboarding/", false, [origin]));
    seeds.push(seedOf("method", "打", "manual/preferences.html", false, [
      typing,
      questionForCase(table, "kKeyboardParser4Zhuyin"),
      questionForCase(table, "kKeyboardParser4Pinyin"),
      questionForCase(table, "kUseSCPCTypingMode"),
      questionForCase(table, "kUseSpaceToCommitHighlightedCandidate4SCPC"),
      questionForCase(table, "kCassetteEnabled"),
      questionForCase(table, "kShowTranslatedStrokesInCompositionBuffer"),
      questionForCase(table, "kAutoCompositeWithLongestPossibleCassetteKey"),
      questionForCase(table, "kForceCassetteChineseConversion"),
    ]));
    seeds.push(seedOf("rhythm", "調", "manual/preferences.html", false, questionsForCase(table, [
      "kAcceptLeadingIntonations", "kSpecifyIntonationKeyBehavior",
      "kSuppressTooltipForIntonationKeyOverrideEvents", "kAutoCorrectReadingCombination",
      "kEscToCleanInputBuffer", "kKeepReadingUponCompositionError",
      "kTrimUnfinishedReadingsOnCommit",
    ])));
    seeds.push(seedOf("keys", "按", "manual/preferences.html", false, questionsForCase(table, [
      "kSpecifyShiftBackSpaceKeyBehavior", "kSpecifyShiftTabKeyBehavior",
      "kSpecifyShiftSpaceKeyBehavior4CandidateWindow", "kSpecifyShiftSpaceKeyBehavior4EmptyState",
      "kSpecifyCmdOptCtrlEnterBehavior", "kUpperCaseLetterKeyBehavior",
      "kSpaceKeyBehaviorAgainstICB", "kShowHanyuPinyinInCompositionBuffer",
      "kInlineDumpPinyinInLieuOfZhuyin",
    ])));
    seeds.push(seedOf("candidate", "選", "manual/preferences.html", false, questionsForCase(table, [
      "kCandidateListTextSize", "kUseHorizontalCandidateList",
      "kCandidateWindowShowOnlyOneLine", "kAlwaysExpandCandidateWindow",
      "kEnforceSingleLineCandidateWindowLayout4SCPC", "kCandidateKeys", "kUseRearCursorMode",
      "kCursorPlacementAfterSelectingCandidate", "kShowReverseLookupInCandidateUI",
      "kShowCodePointInCandidateUI", "kUseDynamicCandidateWindowOrigin",
      "kDodgeInvalidEdgeCandidateCursorPosition", "kEnableCandidateWindowAnimation",
      "kCandidateStateJKHLBehavior", "kUseShiftQuestionToCallServiceMenu",
      "kUseFixedCandidateOrderOnSelection", "kConsolidateContextOnCandidateSelection",
    ])));
    seeds.push(seedOf("mixed", "英", "manual/preferences.html", false, questionsForCase(table, [
      "kMixedAlphanumericalEnabled", "kEnableLatchedAlnumStateInMixedAlnumMode",
      "kMixedAlnumJudgeReadingsBySequentialRawKeyOrder",
      "kTogglingAlphanumericalModeWithLShift", "kTogglingAlphanumericalModeWithRShift",
      "kFuriousTypingEnabled", "kShareAlphanumericalModeStatusAcrossClients",
    ])));
    seeds.push(seedOf("punctuation", "標", "manual/preferences.html", false, questionsForCase(table, [
      "kHardenVerticalPunctuations",
      "kRomanNumeralOutputFormat", "kSymbolInputEnabled",
      "kReplaceSymbolMenuNodeWithUserSuppliedData", "kNumPadCharInputBehavior",
      "kClassicHaninKeyboardSymbolModeShortcutEnabled",
    ])));
    seeds.push(seedOf("lexicon", "辭", "manual/preferences.html", false, questionsForCase(table, [
      "kKanjiConversionPreferences", "kCNS11643Enabled", "kFilterNonCNSReadingsForCHTInput",
      "kAlsoConfirmAssociatedCandidatesByEnter",
      "kPhraseReplacementEnabled", "kSuppressFactoryUnigramsOfKanaSyllables",
      "kEnforceETenDOSCandidateSequence", "kReducePOMLifetimeToNoMoreThan12Hours",
      "kFetchSuggestionsFromPerceptionOverrideModel", "kAllowRescoringSingleKanjiCandidates",
      "kReflectBPMFVSInCompositionBuffer", "kUseExternalFactoryDict",
      "kUserPhrasesDatabaseBypassed", "kShouldAutoReloadUserDataFiles",
      "kFilterFactoryKanjisOfNonCurrentInputMode", "kPreferredRevolverForceLevel",
    ])));
    seeds.push(seedOf("notify", "通", "manual/preferences.html", false, questionsForCase(table, [
      "kShowNotificationsWhenTogglingCapsLock", "kShowNotificationsWhenTogglingEisu",
      "kShowNotificationsWhenTogglingShift", "kSpecifiedNotifyUIColorScheme",
      "kCheckUpdateAutomatically", "kReadingNarrationCoverage", "kCandidateNarrationToggleType",
      "kBeepSoundPreference", "kShouldNotFartInLieuOfBeep",
      "kPhraseEditorAutoReloadExternalModifications", "kShowModeDescriptionOnActivatingServer",
      "kAlwaysShowTooltipTextsHorizontally", "kBypassNonAppleCapsLockHandling",
      "kShiftEisuToggleOffTogetherWithCapsLock", "kRespectClientAccentColor",
    ])));
    seeds.push(seedOf("advanced", "進", "manual/preferences.html", true, questionsForCase(table, [
      "kSecurityHardenedCompositionBuffer", "kAlwaysUsePCBWithElectronBasedClients",
      "kDisableSegmentedThickUnderlineInMarkingModeForManagedClients",
      "kCheckAbusersOfSecureEventInputAPI", "kIsDebugModeEnabled",
      "kUsingHotKeySCPC", "kUsingHotKeyAssociates", "kUsingHotKeyCNS",
      "kUsingHotKeyKanjiConversionMode", "kUsingHotKeyPinyinZhuyinTypingSwitch",
      "kUsingHotKeyHalfWidthPunctuation", "kUsingHotKeyCurrencyNumerals",
      "kUsingHotKeyCassette", "kUsingHotKeyRevLookup", "kUsingHotKeyInputMode",
    ])));
    return seeds;
  }

  function seedOf(id: string, glyph: string, docPath: string, optional: boolean, questions: (Question | null)[]): StepSeed {
    var list: Question[] = [];
    for (var i = 0; i < questions.length; i += 1) {
      var question = questions[i];
      if (question) list.push(question);
    }
    return { id: id, glyph: glyph, docPath: docPath, optional: optional, questions: list };
  }

  function questionsForCase(table: { [caseName: string]: Question }, keys: string[]): Question[] {
    var list: Question[] = [];
    for (var i = 0; i < keys.length; i += 1) {
      var question = questionForCase(table, keys[i]);
      if (question) list.push(question);
    }
    return list;
  }

  // MARK: - 對外

  /// 依 profile 過濾：分支題只在對應之打字方式下出題（「還不確定」一律出題）。
  function visibleForProfile(question: Question, profile: Profile): boolean {
    if (question.showForTyping && profile.typing !== "unsure") {
      var matched = false;
      for (var i = 0; i < question.showForTyping.length; i += 1) {
        if (question.showForTyping[i] === profile.typing) matched = true;
      }
      if (!matched) return false;
    }
    return true;
  }

  /// 該題之有效推薦值（依 profile）。
  export function effectiveRecommended(question: Question, profile: Profile): PrefValue | null {
    if (question.recommendedByTyping &&
      typeof question.recommendedByTyping[profile.typing] !== "undefined") {
      return question.recommendedByTyping[profile.typing];
    }
    if (question.recommendedByOrigin &&
      typeof question.recommendedByOrigin[profile.origin] !== "undefined") {
      return question.recommendedByOrigin[profile.origin];
    }
    return question.recommended;
  }

  /// 該題於該 profile 下是否必然不輸出任何鍵（純資訊用）。
  export function isBranchOnly(question: Question): boolean {
    return question.entry === null;
  }

  /// 組裝整份流程：歡迎頁 ＋ 各題組 ＋ 摘要頁。
  export function buildSteps(profile: Profile, osVersion: number | null): Step[] {
    var steps: Step[] = [];
    steps.push({
      id: "welcome", glyph: "音", titleKey: "app.title", introKey: "welcome.h1",
      optional: false, docPath: "onboarding/", questions: [], skippedByOS: 0,
    });

    var seeds = stepSeeds();
    for (var s = 0; s < seeds.length; s += 1) {
      var seed = seeds[s];
      var kept: Question[] = [];
      var skipped = 0;
      for (var q = 0; q < seed.questions.length; q += 1) {
        var question = seed.questions[q];
        if (!visibleForProfile(question, profile)) continue;
        if (osVersion !== null && question.minimumOS > osVersion) {
          skipped += 1;
          continue;
        }
        kept.push(question);
      }
      steps.push({
        id: seed.id, glyph: seed.glyph,
        titleKey: "step." + seed.id + ".title", introKey: "step." + seed.id + ".intro",
        optional: seed.optional, docPath: seed.docPath, questions: kept, skippedByOS: skipped,
      });
    }

    steps.push({
      id: "summary", glyph: "成", titleKey: "step.summary.title", introKey: "step.summary.intro",
      optional: false, docPath: "manual/preferences.html", questions: [], skippedByOS: 0,
    });
    return steps;
  }

  /// 題庫所觸及之全部 `UserDef` 鍵（供測試與文件稽核用）。
  export function allQuestionKeys(): string[] {
    var seeds = stepSeeds();
    var keys: string[] = [];
    for (var s = 0; s < seeds.length; s += 1) {
      for (var q = 0; q < seeds[s].questions.length; q += 1) {
        var entry = seeds[s].questions[q].entry;
        if (entry && keys.indexOf(entry.key) < 0) keys.push(entry.key);
      }
    }
    return keys;
  }
}
