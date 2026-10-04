# 唯音輸入法配置助手（vChewing Configuration Assistant）

唯音輸入法（vChewing）的偏好設定項目繁多（現有 119 條），初次接觸者往往不知從何調起。本目錄是「**唯音輸入法配置助手**」的原始碼與建置來源：它是一個**單檔自足**的網頁小工具，以分支問卷問出使用者的打字背景與習慣，整理出一份「**配置包**」（JSON）；使用者把配置包匯入唯音，即可一次完成整組偏好的調整。

## 一、這是什麼

- **交付物**：`dist/assistant.html`——CSS 與 JavaScript 皆已內聯的單一 HTML 檔；可雙擊開啟（`file://`）、可部署到任何網頁空間，亦可直接嵌入網頁。
- **目錄入口頁**：`dist/index.html`——以 `<meta http-equiv="refresh">` 自動跳轉至 `assistant.html`，附手動連結後備；把整個 `dist/` 目錄丟上網即可使用。
- **使用者動線**：在助手內作答 → 於摘要頁按「複製」取得配置包（或下載 `vChewing_Preferences.json`）→ 切到唯音「偏好設定 → 一般設定」→ 按「點此從剪貼簿匯入（由配置助手生成的）配置資料」→ 核對清單 → 按「套用」。
- 助手完全在使用者的瀏覽器內運作：不會把使用者填入的內容帶離該部電腦，也不會讀取電腦上的任何設定（唯「深入說明 →」之連結會開啟官網頁面）。
- 助手之產物另有一份收錄於 `vChewing.app` 的 `Contents/Resources/assistant/`，供離線使用（見 §十）。
- `dist/core.js`（無 DOM 的純邏輯）與 `dist/app.js`（含 DOM 介面的完整程式）是中間產物，供測試與除錯使用；真正的交付物是上面兩個 HTML。

### 配置包之格式

配置包是一份 JSON，形如（示例取自 `tests/fixtures/minimal-sparse.json`）：

```json
{
  "__UserDefMeta": {
    "title": "極簡包（只表態一項）",
    "description": "由唯音輸入法配置助手生成：只調整了選字窗字號一項，其餘一概不動。"
  },
  "CandidateListTextSize": 32
}
```

- 根層的 `__UserDefMeta`（`title`／`description`）是唯音匯入時顯示於清單的中介資訊，置於最前。
- 其餘每一條鍵都是唯音 `UserDef` 的 `rawValue`（如 `CandidateListTextSize`）；值之型別與值域依唯音之後設資料。助手一律以 `rawValue` 為鍵（少數 case 之 `rawValue` 與其名稱略有出入，屬歷史遺留；一切以 `assets/userdef-metadata.json` 為準）。
- 配置包是**稀疏**的：只寫入使用者明確表態過的鍵；未出現的鍵，唯音匯入時一概不碰。
- 唯音之匯入語意是「**只寫入包內出現的鍵**」——助手如何為「多組配置互相殘留」把關，見 §五第 5 條。
- 助手能收得下的值，唯音必須也收得下：最終權威是唯音端的 `UserDef.importFromDictionary(_:)`（定義於 `Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/UserDef/UserDef.swift`）；助手端之驗證只是先驗，兩者之落差由 Swift 側契約測試守住（見 §七）。

## 二、使用者的流程

問卷有兩種路線，頁數即時可變：

- **快速路線（預設）**：歡迎 → 您的輸入習慣（背景）→ 起始配置 → 摘要與產生，共 4 頁。
- **逐項路線**：以上四頁，其後另有九頁逐項問題（打字方式、打字節奏與聲調、按鍵行為、選字窗、中英混打、標點數字與符號、辭典與智慧功能、通知與系統整合、進階選項），共 13 頁。於「起始配置」頁取消勾選「只套用起始配置」即可切換。

各頁概要：

- **背景頁**收兩個分支樞紐：「您原本用哪一款輸入法？」與「您主要用哪一種打字方式？」。兩題本身不輸出任何鍵，但決定後續的推薦值（`Profile`）。
- **起始配置頁**依所選 profile 給出一組現成配置：
  - 內容即推薦值表對該 profile 的**全集**（不另立一份題庫）；逐項頁上標示的推薦值與此處所寫入者恆為同組同值。
  - 該頁明示將寫入的兩段內容：「本組指名的項目」與「一併回歸唯音出廠預設的項目」。兩段皆為**逐項核取清單**（預設全選，可逐項取消，亦各有「全部勾選／全部取消勾選」連結）；取消某項即該鍵不予更動。
  - 取捨項預設為「套用這組起始配置」。套用之後即可直接前往摘要結束，除非想更細緻地逐項微調。
  - 使用者親自改過的鍵不會被覆蓋；取消套用只撤回助手寫入、且未被使用者改動過的鍵。
- **逐項頁**：每題之預設狀態為「維持不變」（＝不輸出該鍵），題下標示推薦值（若有）。每頁另有「以推薦值（或出廠預設值）補齊本頁未答之項目」開關——這是**逐頁、明示**的動作：只補上本頁尚未表態的鍵，不動已作答者。「維持不變」之註記亦會標明該鍵的出廠預設值。
- **摘要頁**：列出將寫入的鍵與值（值一律以題目自身的選項標籤呈現）、可編輯配置包之標題與說明、提供複製與下載；剪貼簿不可用時可展開 JSON 內文自行複製。
- **導覽**：底部「上一步／下一步／取消」；「跳到摘要 ＞」鈕自起始配置頁起、距摘要還有兩頁以上時才會出現（只差一頁者，按「下一步」即是）。鍵盤：`Alt+←` 上一步、`Enter` 下一步。
- **深層連結**（URL 參數）：`?lang=zh-Hant|zh-Hans|en|ja` 指定語言、`?express=0` 直接進逐項路線、`?step=N` 直接跳到第 N 步。

## 三、取得 `tsc`（唯一之外部相依）

建置鏈不需要 node，也不需要 npm：JS 宿主改用 macOS 內建的 **JXA**（`osascript -l JavaScript`），`tools/` 本身也是跑在 JXA 上的純 JS。整條鏈唯二的環境要求是：

- **macOS**（JXA 與 Foundation 皆為系統內建）。
- **`tsc`：TypeScript 7 之原生執行檔**（見下）。

取得方式（三條路，皆不需 node／npm）：

- **npm registry 的平台套件（推薦）**：純 HTTPS GET，數 MB。
- **GitHub Releases**：`microsoft/typescript-go` 之 `typescript/v7.0.x` tag，各平台之 `.tgz`。
- **NuGet**：`Microsoft.TypeScript.MSBuild`，體積較大。

以 arm64 macOS、版本 7.0.2 為例：

```sh
mkdir -p ~/.local/bin ~/.local/lib
curl -sSL -o /tmp/ts.tgz \
  https://registry.npmmirror.com/@typescript/typescript-darwin-arm64/-/typescript-darwin-arm64-7.0.2.tgz
tar xzf /tmp/ts.tgz -C /tmp
mv /tmp/package ~/.local/lib/tsc   # 若該路徑已存在，請先自行處置舊版
ln -sf ~/.local/lib/tsc/lib/tsc ~/.local/bin/tsc
```

（請按當前最新版與所在平台調整 URL；`~/.local/bin` 需在 `PATH` 內。）

```sh
tsc --version    # 應印出 7.x
make check-tsc   # 驗證「執行檔不是以 #! 起頭之啟動器」
```

**何以不能用 npm 版**：`npm i -g typescript@7` 裝到的 `bin/tsc` 其實是 `#!/usr/bin/env node` 的啟動器（再由其去找真正的原生編譯器）——**仍需 node 才能啟動**，而本鏈已免除 node。`make check-tsc` 即以「執行檔是否以 `#!` 起頭」判別，並已納入 `typecheck`／`build`。

另：`surface`／`metadata`／`version-check` 等目標會讀取 `Packages/` 與倉根檔案，故請在完整的 `vChewing-macOS` 檢出內執行本目錄之 Makefile；其中 `metadata*` 另需 Swift 工具鏈（會以 `swift run` 執行 `vChewingSharedCLI`）。

## 四、常用指令

```sh
cd vChewing-macOS/ValueAdd/WebConfigAssistant
make bundle   # 產出 dist/assistant.html（單檔自足）
make serve    # 本機預覽 http://127.0.0.1:8787/assistant.html（需 python3）
make audit    # 提交前總檢
```

完整目標（`make help` 亦可列出）：

- `make help`——列出可用目標。
- `make check-tsc`——驗證 `tsc` 為原生版（非 npm 之 node 啟動器）。
- `make typecheck`——只做型別檢查（不輸出）。
- `make build`——以 `tsc` 編譯 `src/` 至 `dist/js/`。
- `make bundle`——串接並產出 `dist/` 之全部產物（含單檔 HTML 與目錄入口頁）。
- `make es5`——只跑 ES5 產物守衛（見 §六）。
- `make test`——全部單元測試（現有 85 支；`test` 會先 `bundle`）。
- `make audit`——提交前總檢：型別檢查＋ES5 守衛＋單元測試＋後設資料防漂移＋i18n 稽核＋曝露面防漂移＋版本防漂移＋契約樣本防漂移。
- `make serve`——本機預覽（產物本身可雙擊開啟，故僅開發期需要）。
- `make deploy`——複製產物進官網倉（不自動提交；見 §十）。
- `make metadata`——自唯音重新導出後設資料，並與入庫版逐位元組比對（有差即失敗）。
- `make metadata-update`——重新導出後設資料並寫入 `assets/`（僅在 Swift 側確有變更時執行）。
- `make metadata-audit`——以 `--strict` 稽核 i18n：缺鍵或真欠譯即失敗。
- `make surface`——重新掃描設定介面之曝露面（見 §五第 2 條）。
- `make surface-check`——驗證曝露面與入庫版一致（防漂移）。
- `make fixtures`——由助手自身的核心邏輯重新生成契約測試樣本（見 §七）。
- `make fixtures-check`——驗證契約樣本與當前產物一致（防漂移）。
- `make version-check`——驗證 `version.txt` 與倉根 `Release-Version.plist` 一致。
- `make clean`——清理提示（本工作區不以 make 代刪檔案；請手動將 `dist/` 移入 `tmp/_filesToTrash`）。

常用之覆寫變數（以 `make <目標> VAR=值` 指定；詳見 Makefile）：`TSC`（自訂 `tsc` 路徑）、`DOC_BASE`、`PORT`、`HOMEPAGE_REPO`、`DEPLOY_SUBDIR`。

## 五、設計約束（改題庫或推薦值前必讀）

1. **不替使用者決定未表態之事。** 每個單選題之預設選項一律為「維持不變」；未表態即不輸出該鍵。推薦值之補齊是**逐頁、明示**的動作，不是全域預設。
2. **只問設定介面曝露過的選項。** 凡未出現於唯音設定介面（`Packages/vChewing_SettingsUI` 之 `SettingsUI/`（SwiftUI）或 `SettingsCocoa/`（AppKit））者，使用者即無從自行調整——助手問了也只會把人推進死巷。此集合由 `tools/settings-surface.js` 掃描那兩個目錄之源碼生成（`assets/settings-surface.json`），並由 `tests/questions.test.js` 以「題庫 ⊆ 曝露面」之不變式守住；設定介面增刪曝露項時跑 `make surface` 即可跟上。
3. **只寫唯音收得下的值。** 前端先驗（型別、值域、選項）一律從嚴：凡本目錄之驗證所接受者，唯音之匯入端亦須接受。此契約由 Swift 側契約測試守住（見 §七）。
4. **推薦值必須有依據。** 推薦值表是官網既有策展知識（`onboarding/*.md`、`manual/preferences.md` 一類）的可執行化，或唯音既有行為之對位；助手**不**為「讓起始配置看起來有用」而臆造值——無依據者寧可照實顯示（如「沒有需要先套用的項目」）。
5. **起始配置封閉於固定之鍵全集。** 唯音之匯入是「只寫入包內出現的鍵」，故稀疏的配置會互相殘留——極端例：`kCassetteEnabled`（磁帶）一旦為真會停用注音輸入，前一位使用者留下它，下一位注音使用者就當場壞掉。為此起始配置一律封閉於 `starterUniverse()`（現為 18 鍵；較舊系統另依 `minimumOS` 過濾，如 macOS 10.9 為 16 鍵）：全集內有推薦值者寫入該值（「指名」）、無者寫入唯音之**出廠預設值**（「回歸」）。於是任兩組配置之鍵集完全相同，同一台電腦上換人套用時後者必完整覆蓋前者；全集之外的一切偏好（選字窗字級、熱鍵、通知……）一概不碰。此封閉性由 `tests/questions.test.js` 以「任兩組配置之鍵集逐項相等」之不變式守住。
   - 全集另收「不出題、但同屬打字風格」之鍵（現僅 `kAssociatedPhrasesEnabled`：「關聯詞語模式」）。該鍵不在設定介面曝露面內，故不入題庫；其可復原路徑是輸入法選單（⌃⌘O）。
6. **使用者的表態優先。** 使用者親自改過的鍵不受起始配置覆蓋；取消套用只撤回助手寫入、且未被使用者改動過的鍵。
7. **文案不手抄。** 偏好選項的標題與說明一律取自唯音自己的 `.strings`（經後設資料導出），故助手的措辭永不與 app 分歧；助手自己的句子（步驟標題、按鈕、提示）才寫在 `src/i18n.ts`。

### 新增題目之檢查清單

1. 先確認該鍵**已於設定介面曝露**；若否，先在 Swift 側曝露它，再跑 `make surface` 更新 `assets/settings-surface.json`。
2. 於 `src/questions.ts` 登錄題目（分頁、分支、推薦值；推薦值須有依據）。
3. 新文案於 `src/i18n.ts` 之四語系補齊（偏好標籤本身不在此——見第 7 條）。
4. `make test`；若改動影響契約樣本（推薦值、題庫涵蓋、起始配置），跑 `make fixtures` 後提交——`make audit` 會驗證一致性。

## 六、專案結構與建置鏈

```text
ValueAdd/WebConfigAssistant/
├── Makefile                 ← 本目錄專用之 Makefile（主倉 Makefile 不呼叫本檔）
├── tsconfig.json            ← tsc 設定（target es2015／lib ES5+DOM／strict）
├── index.html               ← 單檔產物之外殼模板（{{LANG}}／{{STYLE}}／{{SCRIPT}}／{{BUILD_STAMP}}）
├── version.txt              ← 助手適配之輸入法版本（與倉根 Release-Version.plist 比對）
├── assets/
│   ├── assistant.css        ← 樣式（Windows 2000／ME 復古風）
│   ├── userdef-metadata.json← 唯音偏好之後設資料（導出物，入庫）
│   └── settings-surface.json← 設定介面之曝露鍵集（掃描物，入庫）
├── src/                     ← TypeScript 原始碼（全域 script、namespace VCA）
│   ├── globals.ts           ← 建置期注入之全域值（型別宣告）
│   ├── model.ts             ← 資料模型（與後設資料對位）
│   ├── i18n.ts              ← 助手之介面文案（zh-Hant／zh-Hans／en／ja）
│   ├── schema.ts            ← 後設資料查詢、型別正規化、前端先驗
│   ├── questions.ts         ← 題庫（分頁、排序、分支、推薦值）
│   ├── starter.ts           ← 起始配置（封閉鍵全集）
│   ├── preset.ts            ← 配置包之生成（純函式）
│   ├── widgets.ts           ← 表單控制項
│   ├── shell.ts             ← 外框（標題帶、左側水印區、按鈕列、模態對話框）
│   ├── exits.ts             ← 出口（剪貼簿、檔案下載）
│   └── main.ts              ← 進入點（狀態、流程、摘要、鍵盤導覽）
├── tests/                   ← 單元測試（5 支）＋ 契約樣本 ＋ DOM 替身
│   ├── core-loader.js       ← 載入 dist/core.js（無 DOM 之純邏輯）
│   ├── dom-shim.js          ← 極簡 DOM 替身
│   ├── metadata.test.js     ← 後設資料之契約與不變式
│   ├── i18n.test.js         ← 四語系完整性、佔位符一致、簡繁用詞紀律
│   ├── questions.test.js    ← 題庫完整性、值域、分支、頁序、起始配置
│   ├── preset.test.js       ← 配置包之稀疏／型別／黑名單／鍵序
│   ├── dom-smoke.test.js    ← 以 DOM 替身驅動完整產物之端到端冒煙
│   └── fixtures/*.json      ← 契約樣本（入庫）
└── tools/
    ├── build.js             ← 串接、投影後設資料、產出單檔 HTML 與入口頁
    ├── es5guard.js          ← ES5 語法／API 守衛
    ├── target-version.js    ← version.txt 之讀取與比對
    ├── settings-surface.js  ← 掃描設定介面之曝露面
    ├── fixtures.js          ← 由助手自身核心邏輯生成契約樣本
    ├── embed-into-bundle.sh ← 收錄進 vChewing.app（供三條建置路徑呼叫）
    └── host/                ← JXA 宿主（run.js／node.js／loader.js／tests.js）
```

`dist/`、`tmp/`、`*.local` 不入庫；`assets/*.json` 與 `tests/fixtures/*.json` 則**刻意入庫**（它們是防漂移比對的基準）。

### 建置管線

1. `make build` 以 `tsc` 把 `src/*.ts` 編譯到 `dist/js/`。
2. `make bundle` 執行 `tools/build.js`：
   - 由入庫的 `assets/userdef-metadata.json` 與 `assets/settings-surface.json` 投影出 `dist/metadata.js`（另注入 `version.txt` 之版本、`DOC_BASE`、鍵盤排列之 `keyboardParsers` 段與建置時間戳）；
   - 依 `CORE_ORDER`（`globals`→`model`→`i18n`→`schema`→`questions`→`starter`→`preset`）串成 `dist/core.js`，再與 `APP_ORDER`（`widgets`→`shell`→`exits`→`main`）串成 `dist/app.js`；
   - 串接後以 `tools/es5guard.js` 掃描產物（`dist/core.js` 與 `dist/app.js`）；
   - 套進 `index.html` 模板、內聯 `assets/assistant.css`，產出 `dist/assistant.html` 與跳轉頁 `dist/index.html`。

產物沒有模組系統：模組以 TypeScript 的 `namespace VCA` 合併，載入順序即執行順序。**新增或改名 `src/` 之檔案時，必須同步登錄 `tools/build.js` 之 `CORE_ORDER`／`APP_ORDER`**，否則建置會直接失敗（順序清單與 `src/` 不一致之檢查）。

### 宿主（JXA，取代 node）

`tools/host/` 讓工具與測試以 macOS 內建的 JXA 執行，故本鏈無需 node：`node.js` 提供所需之 node API 子集（`fs`／`path`／`vm`／`process`／`child_process`／`Buffer`／`node:test`／`node:assert`），`loader.js` 提供 CommonJS 載入器，`run.js` 是入口，`tests.js` 是測試宿主。用法：

```sh
osascript -l JavaScript tools/host/run.js <工具.js> [引數…]
osascript -l JavaScript tools/host/run.js --tests
```

**ES5 紀律只及於 `src/` 與其產物**；`tools/` 跑在 JXA 的現代引擎上，不受此限——此即 `tools/es5guard.js` 只掃 `dist/core.js`、`dist/app.js` 而不掃 `tools/*.js` 之理。

### 測試

5 支測試檔由 `tools/host/run.js --tests` 掃描執行（現合計 85 支）：

- `core-loader.js` 載入 `dist/core.js`（無 DOM 的純邏輯），供前四支測試使用；
- `dom-smoke.test.js` 以 `dom-shim.js` 驅動**完整產物**（`dist/app.js`）走完端到端冒煙：掛載、逐步導覽、作答反映到配置包、摘要產出合法 JSON、切換語言不重置答案、取消對話框可清空作答。

### ES5 紀律（目標環境含 macOS 10.9 之 Safari 7）

- 緣由：本機之 TypeScript 7 已移除 `target: es5` 與 `module: none`（`error TS5108`／`TS6046`），故採「**原始碼一律 ES5 寫法 ＋ 以 `target: es2015` 編譯**」為紀律。
- 原始碼一律 `var` ＋ `function` ＋ 字串相加；不用箭頭函式、樣板字串、`let`／`const`、解構、展開、`class`、物件簡寫、`for...of`、預設參數。這些限制不是風格偏好，而是產物能否在目標瀏覽器上執行的前提。
- `tsconfig.json` 之 `lib` 取 `ES5`＋`DOM`（刻意）：凡誤用 ES6+ 之標準庫 API（`Array.from`、`Object.assign`、`.includes`……），**編譯期即報錯**。
- `tools/es5guard.js` 掃描**產物**（而非原始碼）之 ES6+ 語法與標準庫 API——如此連 tsc 自行注入的語法也一併抓；有一項即建置失敗。
- 打包器（esbuild 一類）因此完全不必要：沒有相依要解析，串接即可。

### 版面與樣式之既有約定（改 CSS 前請讀）

- 外觀是刻意的 Windows 2000 安裝程式風格；控制項一律用**原生** `<input type="radio|checkbox">` 加上 CSS 重繪（語意、鍵盤、輔助技術皆免費；不支援該 CSS 的瀏覽器只會看到原生控制項，功能不受影響）。
- 內容區為**固定**高度（預設 490px；矮視窗與窄螢幕另有較短之固定值）：各頁等高，「上一步／下一步」按鈕不隨內容位移。由 `tests/dom-smoke.test.js` 以剖析 CSS 之方式守住。
- 小字註記（「推薦值：…」、「維持不變」之註記、首頁之版本標示）用色 `#114514`（於 `#C0C0C0` 上之對比約 6.1:1，合 WCAG AA）；**勿以 `opacity` 取代**（會把指定色沖淡、且幾乎看不出差異）。
- 標題帶右側之垂直置中靠 `display: inline-table` ＋ `table-cell`；**不要**改成 `inline-block` ＋ `vertical-align: middle`（那會按基線對位，把分段方塊推低而被裁切）。

## 七、資料之防漂移與契約測試

助手需要知道唯音全部偏好鍵之名稱、型別、值域、預設值與四語系標籤——這些**一律不手抄**，且以機器守住漂移。

- **後設資料（`assets/userdef-metadata.json`）**：由唯音自己導出（`vChewingSharedCLI dump-userdef-metadata`；四語系之 `.strings` ＋ 兩個 `--extra-label-prefix`，用以收錄「不在 `UserDef` 命名空間內、但助手也需要」之既有 i18n 標籤——如注音／拼音排列之選單名稱）。`make metadata` 重新導出並與入庫版**逐位元組**比對，有差即失敗；`make metadata-update` 更新入庫版；`make metadata-audit` 以 `--strict` 稽核缺鍵與真欠譯。建置一律只走本倉內那份 `Packages/vChewing_OSNeutral_LibVanguard`，不跨倉。
- **設定介面曝露面（`assets/settings-surface.json`）**：由 `tools/settings-surface.js` 掃描 `SettingsUI`／`SettingsCocoa` 之源碼生成（另含注音／拼音排列之順序、標籤與分組——皆取自 app 源碼，助手不手抄）。`make surface` 更新、`make surface-check` 防漂移。
- **契約樣本（`tests/fixtures/*.json`）**：由 `tools/fixtures.js` 以助手自己的核心邏輯（`dist/core.js`）實際生成，故樣本恆等於助手之真實產物（手抄必然漂移）。`make fixtures` 更新、`make fixtures-check` 防漂移。Swift 側之契約測試 `Packages/vChewing_SettingsUI/Tests/SettingsUITests/AssistantContractTests.swift` 讀取這批樣本，斷言「唯音一概收得下、且不含黑名單鍵」——助手一旦產出唯音不收的包，Swift 側測試即紅。該測試只做純查詢（`UserDef.destructureExchange(_:)` ＋ `UserDef.diffAgainstCurrent(_:)`），不呼叫 `importFromExchangeJSON(_:)`；其 fixture 之定位以 `#filePath` 為錨，故無須改動任何 `Package.swift`。
- **版本（`version.txt`）**：助手適配之輸入法版本（`key=value` 形制），於首頁顯示為「適配唯音輸入法 〈版本〉 (〈build〉)」。倉庫側之 SSOT 是倉根 `Release-Version.plist`；`make version-check` 比對兩者。發版時由 `Scripts/vchewing-update.swift` 一併更新 `version.txt`（並有驗收；沒寫入即發版流程中止）——平時無須手改。

## 八、語言與文案

- 四語系：`zh-Hant`／`zh-Hans`／`en`／`ja`。語言決定序：URL `?lang=` ＞ `navigator.language` ＞ `zh-Hant`；切換語言**不重置**答案。
- 助手自身的介面文案（步驟標題、按鈕、摘要……）為手寫之四語系表，置於 `src/i18n.ts`（缺鍵時回退 `zh-Hant`；完整性由 `tests/i18n.test.js` 守住）。偏好選項之標題與說明則**一律來自唯音已翻譯好的 `.strings`**（經後設資料導出）。
- `zh-Hant` 之語言名一律作「繁體中文」（不用「正體中文」）。
- `zh-Hans` 一律為「臺灣華語、簡體字形」（zh-Hans-TW）：只簡化字形，**不得改用大陸用語**——剪贴簿 ≠ 剪贴板、汇入 ≠ 导入、设定 ≠ 设置、资料 ≠ 数据、视窗 ≠ 窗口、软体 ≠ 软件、拷贝 ≠ 复制、使用者 ≠ 用户……此紀律由 `tests/i18n.test.js` 以禁用詞表守住。
- 產品名一律取 app l10n 之全稱（唯音輸入法配置助手／唯音输入法配置助手／vChewing Configuration Assistant／唯音入力アプリ配置助手）。若文稿中逐字引用 app 按鈕文案（如摘要頁之「由配置助手生成的」），不得逕改措辭。

## 九、目標環境與相容性

- **主要目標**：現行 Safari／Chrome／Edge／Firefox。
- **次要目標（進行中）**：macOS 10.9 內建之 Safari 7。已備妥：ES5 產物（由 `tools/es5guard.js` 守住）、table 版面（不用 flexbox／grid）、以 CSS2.1 之 `outset`／`inset`／`groove` 繪製控制項（不依賴 `box-shadow`）、`::-webkit-scrollbar` 捲軸著色、漸層之純色後備。
- **降級路線**：剪貼簿（`navigator.clipboard` ＞ `execCommand("copy")` ＞ 顯示 JSON 內文請使用者自行全選複製）；下載（`Blob` ＋ `<a download>` ＞ `data:` URL 另開視窗）。Safari 7 兩者皆不支援，故該環境之主要出口是「顯示 JSON → 自行複製」。
- **未竟事項**：真機（10.9 ＋ Safari 7）之實測；`input[type=radio|checkbox]` 自繪外觀、`placeholder` 屬性、`border-radius`（圓形無線電鈕用）、`:checked + span` 在該環境之表現。以上皆為**增益**：不支援時只失去部分外觀，功能不受影響。

## 十、部署與收錄進 app bundle

**官網**：`make deploy` 會把 `dist/assistant.html` 與 `dist/index.html` 複製到官網倉之 `assistant/`（`HOMEPAGE_REPO`，預設 `../../../vChewing-HomePage.io`；`DEPLOY_SUBDIR` 預設 `assistant`），**不自動提交**。

- 「深入說明 →」之目標由 `DOC_BASE` 決定：**預設為官網之絕對位址 `https://vchewing.github.io/`**——產物可雙擊開啟（`file://`），而相對路徑在 `file://` 下必為死鏈。若助手與官網同網域（部署於 `<站根>/assistant/`），可改用 `make deploy DOC_BASE=../`。文章路徑一律取官網各篇之實際 `permalink`（如 `manual/preferences.html`）。

**app bundle**：`tools/embed-into-bundle.sh` 把 `dist/assistant.html` 收錄到 `vChewing.app` 之 `Contents/Resources/assistant/`。**只收 `assistant.html`**：它是單檔自足之物，`dist/index.html`（目錄入口之跳轉頁）在此情境無用。三條建置路徑共用同一支腳本，且皆在**簽章之前**呼叫（資源受簽章封印，簽後追加會使簽章失效）：

- SwiftPM 現代側：`Plugins/BundleApps/plugin.swift` 之 `embedAssistant`（`make debug`／`release`／`archive`）。
- SwiftPM 5.10 legacy 側：`Plugins/BundleAppsLegacy/plugin.swift`（`make debugLegacy`／`releaseLegacy`／`archiveLegacy`）。
- Xcode：`vChewing.xcodeproj` 之 `vChewing` 目標上的 Run Script phase「Run Script (Embed Configuration Assistant)」。

**唯一的閘是 `tsc`**：當且僅當偵測到 `tsc` 時才編譯並收錄；未偵測到、或編譯失敗，一律只印警告、**絕不中斷輸入法之建置**（本步為選配）。

## 十一、授權與延伸閱讀

本目錄之內容以 **MulanPSL-2.0** 授權（與 `vChewing-macOS` 之自研內容一致）。

- 專案總覽與開發公約：`../../README.md`、`../../AGENTS.md`。
- 匯入端實作（交換格式之權威）：`Packages/vChewing_OSNeutral_LibVanguard/Sources/Shared/UserDef/UserDef.swift`。
- 契約測試：`Packages/vChewing_SettingsUI/Tests/SettingsUITests/AssistantContractTests.swift`。
