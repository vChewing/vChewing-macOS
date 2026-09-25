# 唯音輸入法配置助手（vChewing Configuration Assistant）

> **名稱之來源**：產品名一律取 app l10n 之全稱（`i18n:Common.VChewing`）——zh-Hant「唯音輸入法」／
> zh-Hans「唯音输入法」／en「vChewing」／ja「唯音入力アプリ」，其後接「配置助手」。故助手自稱
> 「**唯音輸入法配置助手**」而非「唯音配置助手」。**唯一例外**：`summary.next3` 所引之字串係 app
> 按鈕文案之逐字引用（其作「由配置助手生成的」），不得改動。

以分支問卷的形式，替使用者整理出一份「配置包」的網頁小工具；使用者再把配置包匯入唯音的
偏好設定。本目錄是其**建置來源**，產物為**單檔自足之 HTML**。

- 產物：`dist/assistant.html`（CSS 與 JS 皆已內聯；可雙擊開啟、可上架、可直接嵌入官網）
- 使用者之動線：助手 →〔拷貝配置資料〕→ 唯音「偏好設定 → 一般設定」→
  〔點此從剪貼簿匯入（由配置助手生成的）配置資料〕→ 核對清單 →〔套用〕
- 契約之權威定義：`vChewing-DevLogs/Research/Phase239_Research.md` §三、§五

## 一、兩條硬性設計約束

1. **助手不得代使用者決定未表態之項目。** 每個單選題之預設選項一律為「維持不變」，
   未表態即不輸出該鍵；「以推薦值（或出廠預設值）補齊本頁未答之項目」是**逐頁、明示**的
   動作，非全域預設。
2. **助手不得產出唯音會拒收的值。** 前端先驗從嚴：凡本目錄之單元測試所接受者，
   `UserDef.importFromDictionary(_:)` 亦須接受（由 Swift 側之契約測試守住）。
3. **助手只問「設定介面曝露過」的選項**（事主 2026-09-24 立規）：凡未出現於
   `vChewing_SettingsUI` 之 `SettingsUI/`（SwiftUI）或 `SettingsCocoa/`（AppKit）者，使用者即無從
   於設定介面自行調整——助手問了也只會把人推進死巷。此集合由 `tools/settings-surface.mjs`
   掃描那兩個目錄之源碼生成（`assets/settings-surface.json`），並由 `tests/questions.test.js`
   以「題庫 ⊆ 曝露面」之不變式守住；設定介面增刪曝露項時跑 `make surface` 即可跟上。
   依此規移除者：`kCandidateTextFontName`（事主明示：使用者亂填字型名稱可能導致部分候選字
   無法正常顯示）、`kAssociatedPhrasesEnabled`、`kCurrencyNumeralsEnabled`、
   `kHalfWidthPunctuationEnabled`、`kPinyinTypingEnabled`。

## 二、零 npm 相依

本目錄**沒有任何 npm 相依**：`package.json` 的 `dependencies` 與 `devDependencies` 皆為空。
建置只需兩樣本機既有之物：`tsc`（TypeScript）與 `node`。

理由是實測出來的：**本機之 TypeScript 7.x（Go 原生版）已移除 `target: es5` 與
`module: none`**（`error TS5108`／`TS6046`）。既不能降到 ES5、又不能以「無模組系統之全域
script」編譯，於是有兩條路：

- 安裝舊版 TypeScript（引入相依與 `node_modules`）；
- **或**改以「原始碼一律 ES5 寫法 ＋ `target: es2015` 編譯」為紀律，並以機器守住該紀律。

本目錄採後者。作法是：

- 原始碼一律 `var` ＋ `function` ＋ 字串相加；不用箭頭函式、樣板字串、`let`／`const`、
  解構、展開、`class`、物件簡寫、`for...of`、預設參數……（**這些限制不是風格偏好，
  而是產物能否在目標瀏覽器上執行的前提**）。
- 型別檢查與編譯走 `tsc`（`tsconfig.json`：`target: es2015`、`module: commonjs`、
  `lib: ["ES5", "DOM"]`、`strict`）。`lib` 取 ES5 是刻意的：凡誤用 ES6+ 之標準庫 API
  （`Array.from`、`Object.assign`、`.includes`……），**編譯期即報錯**。
- 產物由 `tools/build.mjs` 依序串接為單一 script（無模組系統：模組以 TypeScript 之
  `namespace VCA` 合併），再以 `tools/es5guard.mjs` 掃描**產物**（而非原始碼）之
  ES6+ 語法與標準庫 API；有一項即建置失敗。
- 打包器（`esbuild` 一類）因此完全不必要：沒有相依要解析，串接即可。

## 三、目錄結構

```text
ValueAdd/WebConfigAssistant/
├── Makefile                 ← 本目錄專用；主倉 Makefile 不受影響、亦不呼叫本檔
├── package.json             ← 零相依（僅為專案標記與 npm script 之轉呼）
├── tsconfig.json
├── .gitignore               ← node_modules/、dist/、tmp/
├── index.html               ← 模板（含 {{STYLE}}／{{SCRIPT}}／{{BUILD_STAMP}} 佔位）
├── assets/
│   ├── assistant.css        ← Windows 2000 / ME 風格樣式表
│   ├── userdef-metadata.json← 由 vChewingSharedCLI 導出（**入庫**；防漂移見 §五）
│   └── settings-surface.json← 設定介面曝露之鍵集（**入庫**；由 tools/settings-surface.mjs 掃描生成）
├── src/                     ← 原始碼（TypeScript；namespace VCA）
│   ├── globals.ts           ← 建置期注入之全域值（型別宣告）
│   ├── model.ts             ← 資料模型（與後設資料 schema 對位）
│   ├── i18n.ts              ← 助手自身之介面文案（四語系）
│   ├── schema.ts            ← 後設資料查詢、型別正規化、前端先驗、版本碼
│   ├── questions.ts         ← 題庫（分頁、排序、分支、推薦值）
│   ├── preset.ts            ← 配置包之生成（純函式，核心可測件）
│   ├── widgets.ts           ← 控制項（含「維持不變」之單選、數值／文字欄）
│   ├── shell.ts             ← 外框（標題帶、左側水印區、按鈕列、模態對話框）
│   ├── exits.ts             ← 出口（剪貼簿、檔案下載）
│   └── main.ts              ← 進入點（狀態、流程、鍵盤導覽、摘要與出口）
├── tests/                   ← `node --test`（零額外相依）
│   ├── core-loader.js       ← 載入 dist/core.js（無 DOM 之純邏輯）
│   ├── dom-shim.js          ← 極簡 DOM 替身（供端到端冒煙測試）
│   ├── metadata.test.js     ← 後設資料之契約與不變式
│   ├── i18n.test.js         ← 四語系完整性、佔位符一致、zh-Hans-TW 語體
│   ├── questions.test.js    ← 題庫完整性、值域、分支、系統版本過濾
│   ├── preset.test.js       ← 配置包之稀疏／型別／黑名單／鍵序
│   ├── dom-smoke.test.js    ← 以 DOM 替身驅動完整產物之端到端冒煙
│   └── fixtures/*.json      ← 契約測試樣本（**入庫**；由 tools/fixtures.mjs 生成）
└── tools/
    ├── build.mjs            ← 串接、投影後設資料、產出單檔 HTML
    ├── es5guard.mjs         ← ES5 語法／API 守衛
    ├── settings-surface.mjs ← 掃描 SettingsUI／SettingsCocoa 之曝露面
    └── fixtures.mjs         ← 由助手自身之核心邏輯生成契約測試樣本
```

## 四、常用指令

```sh
make audit      # 提交前總檢：型別檢查 ＋ ES5 守衛 ＋ 單元測試 ＋ 後設資料防漂移 ＋ i18n 稽核 ＋ 曝露面防漂移 ＋ fixture 防漂移
make bundle     # 產出 dist/assistant.html（單檔自足）
make test       # 單元測試（node --test；50 支）
make serve      # 本機預覽（http://127.0.0.1:8787/assistant.html）
make deploy     # 複製產物進官網倉（DEPLOY_SUBDIR 預設 assistant；不自動提交）
make metadata-update  # 自 UserDef 重新導出後設資料並入庫
```

``make surface` 重新掃描設定介面之曝露面（`surface-check` 為防漂移比對，已納入 `make audit`）；
`make version-check` 比對 `version.txt` 與倉根 `Release-Version.plist`（亦已納入 `make audit`）。

**「深入說明 →」之目標**由 `DOC_BASE` 決定：**預設為官網之絕對位址 `https://vchewing.github.io/`**
——產物可雙擊開啟（`file://`），而相對路徑在 `file://` 之下必為死鏈。若助手與官網同網域
（部署於 `<站根>/assistant/`），可改用 `make deploy DOC_BASE=../`。文章路徑一律取官網各篇之
實際 `permalink`（如 `manual/preferences.html`、`manual/onboarding_kimo.html`、`onboarding/`）。

## 五、後設資料：防漂移

助手需要知道 118 條偏好鍵之名稱、型別、值域、預設值與四語系標籤。這些**一律不手抄**，而是由
唯音自己導出：

```sh
swift run --disable-sandbox -c release \
  --package-path ../../Packages/vChewing_OSNeutral_LibVanguard \
  vChewingSharedCLI dump-userdef-metadata \
  "zh-Hant=…/zh-Hant.lproj/Localizable.strings" … \
  --extra-label-prefix="i18n:KeyboardLayout." \
  --extra-label-prefix="i18n:TypingMethod." > assets/userdef-metadata.json
```

（`make metadata-update` 即上述命令。）

- **建置一律只走本倉內那份** `Packages/vChewing_OSNeutral_LibVanguard`，不跨倉。
- `make metadata` 會重新導出並與入庫版逐位元組比對，有差即失敗（＝「Swift 側已改、助手未跟上」
  會變成可偵測的紅燈）；`make metadata-audit` 另以 `--strict` 做 i18n 稽核（缺鍵或真欠譯即失敗）。
- `--extra-label-prefix` 收錄「不在 `UserDef` 命名空間內、但助手也需要」之既有 i18n 鍵：
  唯音之注音／拼音排列選單名稱係由 `KeyboardParser.localizedMenuName` 供出（`i18n:KeyboardLayout.*`
  ／`i18n:TypingMethod.*`），不經 `UserDef.metaData`。如此助手既不必手抄這 17 條標籤、亦不必
  為此令 CLI 相依 Tekkon。

## 六、契約測試（Swift 側）

`Packages/vChewing_SettingsUI/Tests/SettingsUITests/AssistantContractTests.swift` 會讀取
`tests/fixtures/*.json`（由 `tools/fixtures.mjs` 以助手自己的核心邏輯生成）並斷言
「唯音一概收得下」——助手一旦產出唯音不收的包，Swift 側測試即紅。

- fixture 之定位以 `#filePath` 為錨，故**無須**改動任何 `Package.swift`、亦不必把 fixture
  納入資源 bundle。
- 該測試只做**純查詢**（`destructureExchange` ＋ `diffAgainstCurrent`），不呼叫
  `importFromExchangeJSON`——後者會寫入 `UserDefaults`，在共用行程之測試之間會互相污染。

## 七、i18n 之紀律

- 助手自身之介面文案（步驟標題、按鈕、摘要頁……）為手寫之四語系表，置於 `src/i18n.ts`。
- **偏好選項之標題與說明則一律來自 app 自己已翻譯好的 `.strings`**（經後設資料導出），
  故助手之措辭永不與 app 分歧。
- 語言決定序：URL `?lang=` ＞ `navigator.language` ＞ `zh-Hant`；切換語言**不重置**答案。
- **`zh-Hant` 之語言名一律作「繁體中文」**（不用「正體中文」；事主 2026-09-24 定調）。
- **`zh-Hans` 一律為 `zh-Hans-TW`（臺灣華語、簡體字形）**：只簡化字形，不得改用大陸用語
  （剪贴簿 ≠ 剪贴板、汇入 ≠ 导入、设定 ≠ 设置、资料 ≠ 数据、视窗 ≠ 窗口、软体 ≠ 软件、
  拷贝 ≠ 复制、使用者 ≠ 用户……）。此紀律由 `tests/i18n.test.js` 以禁用詞表守住。

## 八、目標環境與相容性

- 主要目標：現行 Safari／Chrome／Edge／Firefox。
- **次要目標（進行中）：macOS 10.9 內建之 Safari 7。** 已作到：產物為 ES5 語法
  （由 `tools/es5guard.mjs` 守住）、版面以 table 佈局（不用 flexbox／grid）、
  控制項以 CSS2.1 之 `outset`／`inset`／`groove` 繪製（不依賴 `box-shadow`）、
  捲軸以 `::-webkit-scrollbar` 上色、漸層有純色後備。
- **已備妥之降級路線**：剪貼簿（`navigator.clipboard` ＞ `execCommand("copy")` ＞
  顯示內文區請使用者自行全選）；下載（`Blob` ＋ `<a download>` ＞ `data:` URL 另開視窗）。
  Safari 7 兩者皆不支援，故該環境之主要出口是「顯示 JSON → 使用者自行全選拷貝」。
- **未竟事項（留待 Phase 242 或更後續）**：真機（10.9 ＋ Safari 7）之實測；
  `input[type=radio|checkbox]` 之自繪外觀在該環境之退路確認；`placeholder` 屬性、
  `border-radius`（圓形無線電鈕用）、`:checked + span` 之表現。
  以上皆為**增益**：不支援時只失去部分外觀，功能不受影響。

## 九、施工中查得之 app 側落差（皆已修，2026-09-24 補記）

1. ~~**三條鍵之 `metaData.options` 超出 `validNumeralValueRange`**~~ ⇒ **已修**：
   `kSpecifiedNotifyUIColorScheme` 之值域由 `0...2` 改為 `-1...1`、
   `kForceCassetteChineseConversion` 由 `0...2` 改為 `0...3`、
   `kNumPadCharInputBehavior` 由 `0...2` 改為 `0...5`（皆與其 `options` 一致）。
   修前之病灶：`validateAndApply` 對整數一律以值域把關 ⇒ **app 自己匯出的偏好包，若這三條鍵
   之值落於值域之外（-1／3／4／5），匯入時會被拒**；且 `fixOddPreferencesCore()`
   會把這些值靜默夾成 2／0。修後由 Swift 側之
   `UserDefExchangeTests.testEveryDeclaredOptionIsAcceptedByValidator` 以「選項 ⊆ 值域」
   為不變式守住。助手端之「選項 ∩ 值域」機制**保留**作為防禦，但今日已無被排除者。
2. ~~**`isMetadataPendingManualUpdate` 對三條鍵誤報**~~ ⇒ **已修**：該述詞改以
   「凡以 `i18n:` 起頭者即為已遷移」為判準（不再要求鍵名恰等於
   `i18n:UserDef.<case>.<field>`），並另立「值即標籤之數字」為非欠譯；`i18nKeyConvMap`
   同步收斂（不再為 `"12"` 一類數字憑空生出 i18n 條目）。故 `list-pending-userdef` 不再誤報、
   `dump-userdef-metadata --strict` 只對真欠譯亮紅燈，且後設資料不再有
   `benignPendingMetadataKeys` 一欄。
3. **`kHalfWidthPunctuationEnabled` 之 rawValue 為 `HalfWidthPunctuationEnable`**（無尾端 `d`）——
   助手以 rawValue 為鍵，故不受影響；惟此為命名之歷史遺留，**未動**。

4. ~~**「深入說明 →」點了沒反應**~~ ⇒ **已修**（2026-09-24）：病灶有二——① 目標為相對路徑
   `../…`，在 `file://` 之下必為死鏈；② 文章路徑未取官網之實際 `permalink`（例如各篇
   `onboarding_*.md` 之 permalink 實為 `/manual/onboarding_*.html`，而非 `/onboarding/…`）。
   今以官網絕對位址為預設（見 §四末），並逐篇改用實查之 permalink。
5. **「維持不變」之標示**（事主 2026-09-24 選定「兩者並列」）：該選項現作
   「維持不變」＋小字註記「推薦；保留您目前在唯音內的設定值，出廠預設為：〈值〉」。
6. **說明文字之呈現**（事主 2026-09-24 指示）：短說明（≤ 60 字元）直接沿用到題目下方的註解欄位、
   不再收進折疊區；過長者維持折疊。**值域提示（「可輸入 x ～ y」）只對數值輸入顯示**——單選題
   之值域即其選項，寫「可輸入」只會令人困惑（事主原見之「數字小鍵盤：可輸入 0 ～ 2」即此）。

7. **值的顯示一律走「題目自身之選項標籤」**（2026-09-24）：`kKeyboardParser4Zhuyin`／
   `kKeyboardParser4Pinyin` 之標籤**不在** `UserDef.metaData.options` 內（那 17 條由
   `KeyboardParser.localizedMenuName` 供出，經 `--extra-label-prefix` 導出至 `extraLabels`），
   故若逕以 `formatValue` 呈現即為裸數字（`100`），使用者無從理解。凡顯示值之處
   （摘要表之「將寫入的值」、「推薦值：…」、以及「維持不變」之出廠預設值註記）一律先問
   `labelForValue(question, value, lang)`——它優先在**題目的選項**內找對應標籤，找不到才回退至
   後設資料之標籤／數字。新增題目若用 `extraLabels` 之標籤，即自動涵蓋。

8. **注音／拼音排列之順序、標籤與分組皆取自 app 源碼**（2026-09-24，事主指示「注音排列的 option
   順序請調整得跟輸入法 settingsUI 一致」）：該兩條鍵之標籤不在 `UserDef.metaData.options` 內，而設定
   介面是以 `KeyboardParser.allCases` 之**宣告序**列示（實查 `0,1,4,5,8,6,7,3,2,9,10`，非升冪），
   並在 rawValue 7 與 100 之前插分隔線。故 `tools/settings-surface.mjs` 除掃描曝露鍵集外，另解析
   `Shared.swift` 之 `KeyboardParser` 宣告序與其 `localizedMenuName` switch、暨設定介面之
   `Divider()` 條件，寫入 `assets/settings-surface.json` 之 `keyboardParsers` 段；`tools/build.mjs`
   將該段注入產物（`VCA_SURFACE`），`questions.ts` 之 `parserQuestion` 據以生成選項——**助手不再
   手抄這 17 條之順序或標籤**。**唯一例外**：清單首項之前的分隔線省略（清單之首無從標示分界）。

9. **標題帶**（2026-09-24 事主覆核）：右側為「第 n 步，共 N 步」＋一排分段方塊，兩者之間留
   10 px 間距；**不設關閉鈕**（取消已由底部按鈕承擔，故 `.vca-closebox` 之樣式與元素一併移除）。
   **垂直置中**：右側容器為 `display: inline-table`、其兩個子項為 `display: table-cell` ＋
   `vertical-align: middle`，且分段方塊之格位 `line-height: 11px`（恰等於方塊總高）、方塊本身
   `vertical-align: top`。**不得**改用 `inline-block` ＋ `vertical-align: middle` 之寫法：那會
   按「基線 ＋ 半 x-height」對位，兩層疊加後把方塊推低約 4 px（實測落於 20 px 帶之 6.7～17.7 px、
   底側僅餘 2.3 px 且被 `overflow: hidden` 裁切）——此即事主所指「過於貼近標題列的底側」。

10. **小字說明之色**（2026-09-24 事主指定 **`#114514`**）：`.vca-rec`（「推薦值：…」）與
    `.vca-opt-note`（「維持不變」右側之註記）皆設 `color: #114514`。**不得改以 `opacity` 代之**
    ——黑字壓在 `#C0C0C0` 上時 `opacity: 0.9` 幾乎無可見差異（事主實測反饋），且半透明會把指定色
    沖淡（0.9 之 alpha 疊在 `#C0C0C0` 上得約 `#22512A`，非原色）。該色於 `#C0C0C0` 上之對比為
    **6.12 : 1**（≥ 4.5:1，合 WCAG AA 之小字門檻）。該註記與「維持不變」之間另有 `margin-left: 8px`
    之間距（原 2px 過於貼近，事主 2026-09-24 指出）。
11. **窗體高度恆定**（2026-09-24 事主指出；同日覆核後 **+100px** ⇒ `height: 490px`）：
    `.vca-content` 為**固定** `height: 490px`（**非** `max-height`）——各頁窗體遂等高，底部「上一步／下一步」按鈕之位置不隨頁面內容位移，
    連續點擊者不必追逐按鈕；內容過長者於區內捲動。視口不夠高時（`max-height: 780px` ⇒ 430px、`max-height: 660px` ⇒
    340px）與窄螢幕（`max-width: 640px` ⇒ 420px）另有較短之**固定**高度（同樣已 +100px）。此約束由 `tests/dom-smoke.test.js` 之
    「靜態樣式：內容區為固定高度」以剖析 CSS 之方式守住（該測試以剃除註解後之比對為之）。

12. **macOS 內建注音之接待流程**（2026-09-24，官網新增
    `onboarding/onboarding_macOSZhuyinSinceSnowLeopard.md` 之後）：來源題新增
    「macOS 內建注音（10.6 Snow Leopard 起）」一項（置於清單之首——該來源最常見，且是「多半
    無須改動」之一支），其文章對位為 `manual/onboarding_macOSZhuyinSinceSnowLeopard.html`；
    選定後於該頁顯示**接待說明**（`.vca-note-box`：「唯音的預設值就是照 macOS 10.9 開始的內建注音的
    習慣來的…您多半不需要改任何設定」），並依該文所舉之兩項行為給推薦值——
    `kUseRearCursorMode = false`（選字游標置於詞語前方）與 `kSpecifyIntonationKeyBehavior = 0`
    （聲調鍵覆寫字音）；兩者恰為唯音之出廠預設，故勾「以推薦值補齊」等同「維持出廠預設」。
    來源清單與推薦值皆由 `tests/dom-smoke.test.js` 之「macOS 內建注音之接待流程」固化。

13. **首頁之隱私說明用語**（2026-09-24 事主指出「不會聯網」易引起誤讀）：`welcome.p3` 四語系
    改為「本助手完全在您的瀏覽器內運作，**不會擅自將您填入的偏好帶離這台電腦**，也不會讀取您電腦上的
    任何設定。」——原句「不會連網」與「深入說明 →」確實會開啟官網頁面之事實相衝，易被讀成「本頁
    不會有任何對外請求」；改後所言者為**助手自身不會把使用者填入的偏好送出本機**，此即實際保證。
    由 `tests/dom-smoke.test.js` 之「首頁之隱私說明」固化（含四語系皆不得再出現舊說法之斷言）。

14. **適配之輸入法版本**（2026-09-24 事主指示）：版本號與 build 編號存於本目錄之
    **`version.txt`**（助手側之單一事實來源；`key=value` 形制，`#` 起頭為註解），由
    `tools/build.mjs` 讀取並注入產物（`VCA_TARGET_VERSION`），於**首頁**以 `.vca-version`
    之小字（與推薦值、維持不變之註記**共用** `#114514`／11px 之規則）顯示為
    「適配唯音輸入法 4.8.4 (4840)」（`welcome.targetVersion`，四語系齊備；寫法沿用 app 既有之
    「版本 (Build)」慣例）。**防漂移**：`make version-check`（已納入 `make audit`）以
    `tools/target-version.mjs --check` 比對本檔與倉根之 **`Release-Version.plist`**——後者是
    本倉版本之 SSOT（`Plugins/BundleApps/plugin.swift` 明文如此稱之），不一致即失敗。
    改版時**無須手動同步**：本倉之版本落地點是倉根之 `BuildVersionSpecifier.swift`
    （`Scripts/vchewing-update.swift` 之發版流程會以 `/usr/bin/swift` 呼叫它），該腳本現已一併改寫
    `ValueAdd/WebConfigAssistant/version.txt`（第四個落地點）；`Scripts/vchewing-update.swift` 之
    `versionStampIsLanded()` 亦已把該檔納入驗收，故「txt 沒寫進去」會令發版流程以 exit code `6` 中止。
    `make version-check` 則是第二道防線（在任何時候由助手側自查）。

## 十、授權與著作## 十、授權與著作

本目錄之內容以 **MulanPSL-2.0** 授權（與 `vChewing-macOS` 之自研內容一致）。
