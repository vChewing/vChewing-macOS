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
    /// 左側水印區之**職能說明**（助手 i18n 之 `left.<stepId>`）。
    ///
    /// 該欄原放助手全稱——與標題帶重複、對使用者無益（事主 2026-09-25 指出），
    /// 故改為「這一頁在替您做什麼」之一句話。
    noteKey: string;
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
  ///
  /// 「起始配置」一頁與「背景」頁同源：該組配置之依據即該來源之官網策展文章
  /// （`onboarding_*.md`），故「深入說明 →」一律指向它。
  export function docPathFor(step: Step, state: AssistantState): string {
    if (step.id === "background" || step.id === "starter") {
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
  ///
  /// `zhuyinmix` 為 `zhuyin` 之手足（事主 2026-09-25）：同樣是注音組句，但明示要中英混打
  /// ——故分支與 `zhuyin` 同進退，並帶出 `kMixedAlphanumericalEnabled` 之推薦值（見下）。
  export var TYPING_VALUES: string[] = ["zhuyin", "zhuyinmix", "scpc", "pinyin", "cin", "unsure"];

  /// **題庫之外、但起始配置得指名之鍵**（事主 2026-09-25 裁定）。
  ///
  /// 與題庫之分野：這些鍵**不出題**——使用者無從在助手內逐項調整（其可復原路徑是**輸入法
  /// 選單**，如「關聯詞語模式」⌃⌘O，或再次匯入另一份配置）。助手之**題庫**仍嚴守事主
  /// 2026-09-24 之「設定介面曝露面」規（故題庫 ⊆ 曝露面之不變式不受影響）；此處僅是
  /// **起始配置**之內容。凡增列於此者，須於 `presetOnlyRecommendation()` 給出依據。
  export var PRESET_ONLY_KEYS: string[] = ["kAssociatedPhrasesEnabled"];

  /// 上述諸鍵之推薦值（僅起始配置用之）。
  ///
  /// 現僅一條：`kAssociatedPhrasesEnabled`（關聯詞語模式）——事主 2026-09-25：
  /// 「ㄅ半模式請自動啟用關聯詞語」。此與 app 自身之既有處方一致：內建之「我姓ㄅ」按鈕
  ///（`VwrSettingsPaneCocoaGeneral`）亦將 `associatedPhrasesEnabled` 一併開啟。
  /// 非ㄅ半之各組配置則將其一併回歸出廠預設（`false`）——故在 app 內按過「我姓ㄅ」之後，
  /// 再由助手匯入注音組句之配置，該模式不會殘留。
  export function presetOnlyRecommendation(caseName: string)
    : { value: PrefValue | null; typing: { [k: string]: PrefValue } | null; origin: { [k: string]: PrefValue } | null } {
    switch (caseName) {
    case "kAssociatedPhrasesEnabled":
      return { value: null, typing: { scpc: true }, origin: null };
    default:
      return { value: null, typing: null, origin: null };
    }
  }

  /// 由題庫外之鍵合成題目（供起始配置之推算；其 `kind` 與選項皆不參與出題）。
  function presetOnlyQuestion(caseName: string): Question | null {
    var entry = entryByKey(caseName);
    if (!entry || !isTouchable(entry)) return null;
    var recommendation = presetOnlyRecommendation(caseName);
    return {
      id: caseName, entry: entry, kind: entry.type === "bool" ? "bool" : "enum",
      titleKey: null, helpKey: null, choices: [], range: entry.range,
      recommended: recommendation.value,
      recommendedByTyping: recommendation.typing,
      recommendedByOrigin: recommendation.origin,
      showForTyping: null, minimumOS: osVersionCodeFromDouble(entry.minimumOS),
    };
  }

  /// 取題庫外諸鍵之合成題目（依 `PRESET_ONLY_KEYS` 之序）。
  export function presetOnlyQuestions(): Question[] {
    var out: Question[] = [];
    for (var i = 0; i < PRESET_ONLY_KEYS.length; i += 1) {
      var question = presetOnlyQuestion(PRESET_ONLY_KEYS[i]);
      if (question) out.push(question);
    }
    return out;
  }

  /// 少數鍵之顯示名由**別的鍵**承載（其自身之標籤為空者）。
  ///
  /// 現僅 `kAssociatedPhrasesEnabled`：該鍵不出現在設定介面，其顯示名即輸入法選單內那一項
  /// ——而選單項之標籤取自 `kUsingHotKeyAssociates.shortTitle`（「關聯詞語模式」）。
  /// 此仍屬 app 既有之 l10n（讀自後設資料），非助手手抄。
  export var LABEL_ENTRY_ALIAS: { [caseName: string]: string } = {
    kAssociatedPhrasesEnabled: "kUsingHotKeyAssociates",
  };

  /// 少數來源之標籤過長（並列多款產品者）：其**短名**（供內文與配置名用）。
  ///
  /// 判準：僅在「全名長得不宜入句」時方立；無此對位者一律用題目之選項標籤。
  export var ORIGIN_SHORT_NAME_KEY: { [origin: string]: string } = {
    pinyin: "origin.short.pinyin",
  };

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
  // 刻意**從嚴**：一律以官網既有策展文章（`onboarding/*.md`）為據，並於此逐條註明出處。
  // 助手不替他人生產沒有依據的立場；凡文章未明示、或其所言僅屬描述者，一概不列。
  //
  // Phase 245（事主 2026-09-25）之擴充：起始配置一頁需要「選妥來源即能先套用」之內容，
  // 故按各篇 onboarding 文章逐句核對後補入若干條。三類**刻意不收**者（記於此，免得後人重蹈）：
  //   ① 值等於出廠預設者（如漢音之「維持左右 Shift 切換」、「狂拼模式」預設即開）——寫入
  //      等於無操作，徒增起始配置之篇幅；且「以出廠預設值補齊」是逐頁核取項之事，不是處方。
  //   ② 條件過窄者（如 asus 一文之 `kAcceptLeadingIntonations=false` 僅 v4.4.1 有效、ov 一文
  //      之 `kUseSCPCTypingMode=true` 僅對「嘸蝦米老用戶」而言）——以 origin 粗粒度落值會波及
  //      同源之其他使用者，與文章原意互斥。
  //   ③ 助手碰不到者（如 `kAssociatedPhrasesEnabled`／`kHalfWidthPunctuationEnabled` 不在設定
  //      介面曝露面內；`kCassettePath`／`kBasicKeyboardLayout` 需使用者自備檔案或 TIS 識別碼，
  //      助手不以自由文字欄收之）。

  function recommendationFor(key: string)
    : { value: PrefValue | null; typing: { [k: string]: PrefValue } | null; origin: { [k: string]: PrefValue } | null } {
    var none = { value: null, typing: null, origin: null };
    switch (key) {
    case "kUseSCPCTypingMode":
      // 逐字選字＝《新手上路》之「ㄅ半派」；〈寫給行列三十的使用者〉末段（「只勾選『模擬逐字
      // 選字輸入』一項，完工」）亦對行列派如此指示。
      return { value: null, typing: { scpc: true }, origin: { cin: true } };
    case "kCandidateKeys":
      // 選字鍵之預設值：**事主 2026-09-25 逐來源裁定**（並與《新手上路》之「我姓ㄅ」按鈕
      // 所列之 "123456789"、〈寫給行列三十的使用者〉之 "1234567890" 一致）：
      //   · 微軟新注音／小麥注音／奇摩／OpenVanilla／自然／華碩／ㄅ半 ⇒ "123456789"；
      //   · CIN（所有字根類；**來源或打字方式**為之皆然）⇒ "1234567890"（該派需用第 10 鍵）；
      //   · macOS 內建注音／漢音／狂拼流 ⇒ "123456"（狂拼流列舉到之輸入法在選字鍵數量上各異，
      //     故取唯音之出廠值）；
      //   · 其餘（含未列舉之來源）⇒ "123456"（＝`value` 之回退值）。
      // 兩級衝突時以**打字方式**為準（既有優先序）：故 CIN 來源而打字方式為 ㄅ半 者 ⇒
      // "123456789"（該人明示自己以注音逐字選字）。
      return {
        value: "123456",
        typing: { scpc: "123456789", cin: "1234567890" },
        origin: {
          msnewphonetic: "123456789", mcbpmf: "123456789", kimo: "123456789",
          ov: "123456789", goingime: "123456789", asus: "123456789",
          cin: "1234567890",
          // 以下三者與 `value` 之回退值同值，列出以便對照事主之清單。
          macoszhuyin: "123456", hanin: "123456", pinyin: "123456",
        },
      };
    case "kUseHorizontalCandidateList":
      return { value: null, typing: { scpc: false }, origin: null };
    // 註：`kCandidateWindowShowOnlyOneLine`（僅以單行/單列來陳列候選字）**刻意不收**
    //（事主 2026-09-25）——該鍵為全域偏好（其說明載明係為老花眼者以大字號顯示而設），
    // 而逐字選字模式之單行佈局已由 `kEnforceSingleLineCandidateWindowLayout4SCPC` 保證
    //（其說明：「啟用後，逐字選字模式（SCPC）將始終使用單行選字窗佈局。」）⇒ 於ㄅ半之
    // preset 內再指定前者，既是多餘、亦越權改動了與ㄅ半無關之全域排版偏好。
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
      // 〈寫給漢音輸入法的使用者〉：「漢音輸入法原版的「\」鍵功能得在輸入法偏好設定內手動啟用」。
      return { value: null, typing: null, origin: { hanin: true } };
    case "kCassetteEnabled":
      // 〈寫給行列三十的使用者〉：「您屆時可以使用唯音輸入法的磁帶模式載入表格」。
      return { value: null, typing: { cin: true }, origin: null };
    case "kMixedAlphanumericalEnabled":
      // 混打回退：〈寫給華碩輸入法的使用者〉明示「需要在『唯音偏好設定 -> 行為設定』頁面找到
      // 『啟用中英混合輸入回退』這個選項來啟用」。
      //
      // 其餘來源**刻意不推薦**（事主 2026-09-25 裁定：「原本用哪一款輸入法」除了華碩以外
      // 不要預設啟用中英文輸入回退）——此裁定**收窄**了先前依奇摩／自然／《新手上路》三篇
      // 文章所加之暗示級推薦值。
      //
      // 「打字方式」之兩支注音路線**雙向表態**（事主 2026-09-25 補示）：
      //   · `zhuyinmix`（注音組句＋中英混打）⇒ `true`；
      //   · `zhuyin`（純粹的注音組句）⇒ **`false`**——刻意停用，而非「不表態」：使用者既已
      //     明示只要組句，若其現行設定裡開著混打回退，助手即應照其表態關掉它。
      //     此為「值等於出廠預設者一律不收」之**經事主核定之例外**。
      // 兩者皆屬 typing 級，故優先於 origin 級（如華碩＋純注音組句 ⇒ `false`；該使用者若真要
      // 混打，改選 `zhuyinmix` 即可，屆時與華碩之 origin 級推薦值一致）。
      return {
        value: null, typing: { zhuyin: false, zhuyinmix: true }, origin: { asus: true },
      };
    case "kTogglingAlphanumericalModeWithLShift":
    case "kTogglingAlphanumericalModeWithRShift":
      // 事主 2026-09-25 裁定：下列五個來源**刻意啟用**左右 Shift 切換英數輸入模式
      //（微軟新注音、奇摩、自然、華碩、狂拼流拼音）——此五者之使用者多半養成過「Shift 切換
      // 中英」之肌肉記憶。兩鍵之出廠預設本即為「啟用」，故此處是**刻意釘住**該值，非改預設。
      return {
        value: null, typing: null,
        origin: { msnewphonetic: true, kimo: true, goingime: true, asus: true, pinyin: true },
      };
    case "kSuppressFactoryUnigramsOfKanaSyllables":
      // 〈寫給華碩輸入法的使用者〉：「出現了您本來不想打的日文？您或許會想在『唯音偏好設定 →
      // 辭典設定』畫面開啟『停用原廠假名音節資料』以確保某些超短英文單詞的順利鍵入。」
      return { value: null, typing: null, origin: { asus: true } };
    case "kCheckUpdateAutomatically":
      // 《新手上路》：「開啟更新檢查：在『一般設定』勾選『自動檢查軟體更新』」。
      // 只對「全新使用者」來源給此推薦——該文即 `newbie` 之來源文章。
      return { value: null, typing: null, origin: { newbie: true } };
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
      zhuyin.showForTyping = ["zhuyin", "zhuyinmix", "scpc"];
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
    // 起始配置之取捨（見 starter.ts）：`off` 即「維持不變」，故未表態者不輸出任何鍵。
    var starter = customQuestion("starter", "starter.title", "starter.intro", "starter.opt.", ["off", "on"]);

    var seeds: StepSeed[] = [];
    // 背景頁同時收「原本用哪一款輸入法」與「主要用哪一種打字方式」——兩者皆不輸出任何鍵，
    // 卻是**起始配置**之唯二依據（事主 2026-09-25：選完熟悉的輸入法即應能先套用 presets）。
    seeds.push(seedOf("background", "問", "onboarding/", false, [origin, typing]));
    seeds.push(seedOf("starter", "薦", "onboarding/", false, [starter]));
    seeds.push(seedOf("method", "打", "manual/preferences.html", false, [
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

  /// 依 profile 過濾：分支題只在對應之打字方式下出題。
  ///
  /// 「還不確定」與**未表態**（`typing === ""`）一律出題（超集）——後者尤其要緊：
  /// 打字方式一題已移往背景頁，使用者若略過它，逐項頁面不該因此唱空城。
  function visibleForProfile(question: Question, profile: Profile): boolean {
    if (question.showForTyping && profile.typing !== "unsure" && profile.typing !== "") {
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

  /// 「只套用起始配置」模式下所保留之頁面（餘者皆略過）。
  ///
  /// 事主 2026-09-25（Phase 245）：不必硬控使用者走完十二頁——選妥自己熟悉的輸入法、
  /// 套用起始配置之後即可直接產生配置包，全程四頁；想要更細緻的配置時再逐項回答。
  export var EXPRESS_STEP_IDS: string[] = ["welcome", "background", "starter", "summary"];

  /// 該頁是否屬「逐項微調」之頁面（＝快速模式下會被略過者）。
  export function isDetailStep(id: string): boolean {
    return EXPRESS_STEP_IDS.indexOf(id) < 0;
  }

  /// 組裝整份流程：歡迎頁 ＋ 各題組 ＋ 摘要頁。
  ///
  /// - Parameter expressOnly: `true` 者只留快速模式之四頁（見 `EXPRESS_STEP_IDS`）。
  export function buildSteps(profile: Profile, osVersion: number | null, expressOnly?: boolean): Step[] {
    var includeDetail = expressOnly !== true;
    var steps: Step[] = [];
    steps.push({
      id: "welcome", glyph: "音", titleKey: "app.title", noteKey: "left.welcome",
      introKey: "welcome.h1",
      optional: false, docPath: "onboarding/", questions: [], skippedByOS: 0,
    });

    var seeds = stepSeeds();
    for (var s = 0; s < seeds.length; s += 1) {
      var seed = seeds[s];
      if (!includeDetail && isDetailStep(seed.id)) continue;
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
        titleKey: "step." + seed.id + ".title", noteKey: "left." + seed.id,
        introKey: "step." + seed.id + ".intro",
        optional: seed.optional, docPath: seed.docPath, questions: kept, skippedByOS: skipped,
      });
    }

    steps.push({
      id: "summary", glyph: "成", titleKey: "step.summary.title", noteKey: "left.summary",
      introKey: "step.summary.intro",
      optional: false, docPath: "manual/preferences.html", questions: [], skippedByOS: 0,
    });
    return steps;
  }

  /// 題庫中之全部題目（不分頁；供起始配置與測試用）。已依 profile 與系統版本過濾。
  export function allQuestionsFor(profile: Profile, osVersion: number | null): Question[] {
    var steps = buildSteps(profile, osVersion, false);
    var out: Question[] = [];
    for (var s = 0; s < steps.length; s += 1) {
      for (var q = 0; q < steps[s].questions.length; q += 1) {
        out.push(steps[s].questions[q]);
      }
    }
    return out;
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
