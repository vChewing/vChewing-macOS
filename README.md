語言：[简体中文](./README-CHS.md) | *繁體中文*

僅以此 README 紀念祁建華 (CHIEN-HUA CHI, 1921-2001)。

---

有關該倉庫及該輸入法的最新資訊，請洽產品主頁：https://vchewing.github.io/

因不可控原因，該倉庫只能保證在 Gitee 有最新的內容可用：

- 下載：https://gitee.com/vchewing/vChewing-macOS/releases
- 程式碼倉庫：https://gitee.com/vchewing/vChewing-macOS

# vChewing 唯音輸入法

唯音輸入法是一款為 macOS 平台開發的副廠**原生簡體中文、原生繁體中文注音輸入法**：

- 唯音是業界現階段支援注音排列種類數量與輸入用拼音種類數量最多的注音輸入法。
    - 受唯音自家的鐵恨注音並擊引擎加持。
- 唯音的原廠詞庫內不存在任何可以妨礙該輸入法在世界上任何地方傳播的內容。
- 相比中州韻（鼠須管）而言，唯音能夠做到真正的大千聲韻並擊。
- 擁有拼音並擊模式，不懂注音的人群也可以受益於該輸入法所帶來的穩定的平均輸入速度。
    - 相比小鶴雙拼等雙拼方案而言，唯音雙手聲韻分工明確、且重碼率只有雙拼的五分之一。
- 唯音對陸規審音完全相容：不熟悉台澎金馬審音的大陸用戶不會遇到與漢字讀音有關的不便。
    - 反之亦然。
- 唯音輸入法是最安全的 macOS 副廠中文輸入法：
    - 有啟用 Sandbox 特性，（相比其他沒有開 Sandbox 而言）唯音輸入法在原理上不可能拿到系統全局鍵盤權限。
    - 有「強化型組字區安全防護」模式，防止「接收打字的軟體」提前存取您的組字區的內容。

>唯音有很多特色功能。在此僅列舉部分：
>- 支援 macOS 螢幕模擬鍵盤（僅傳統大千與傳統倚天佈局）。
>- 可以將自己打的繁體中文自動轉成日本 JIS 新字體來輸出（包括基礎的字詞轉換）、也可以轉成康熙繁體來輸出。
>- 簡繁體中文語料庫彼此分離，徹底杜絕任何繁簡轉換過程可能造成的失誤。
>- 支援近年的全字庫漢字輸入。
>- 可以自動整理使用者語彙檔案格式、自訂關聯詞語。
>- ……
>
>**此 fork 新增之功能（個人修改版）：**
>- **智慧中英文切換**：注音輸入期間自動偵測英文詞彙，可流暢切換至英文緩衝區輸入；Shift 鍵可在組字區有內容時就地雙向切換中英輸入（顯示 tooltip「中」/「英」，組字區全程保留不送出）。
>- **近似音設定**：可獨立啟用多組聲母（ㄅ↔ㄆ、ㄈ↔ㄏ、ㄌ↔ㄋ、ㄗ↔ㄓ、ㄘ↔ㄔ、ㄙ↔ㄕ）與韻母（ㄣ↔ㄥ、ㄢ↔ㄤ、ㄧㄣ↔ㄧㄥ、ㄨㄣ↔ㄨㄥ）容錯規則，取代原先單一的 ㄣ/ㄥ 開關。
>- **數字快打**（連按兩次 `` ` `` 鍵觸發）：快速插入中文數字、大寫數字、日期、時間等格式。
>- **近音表選字**（↑ 鍵觸發）：展開二維近音／同音候選表，方便事後修改罕用字。
>- **自動括號配對**：全形與半形括號輸入時自動補完右括號。
>- **自動學習詞語**：選字達到門檻次數後自動寫入使用者辭典。
>- **二維分類符號表格**（單按 `` ` `` 鍵觸發）：啟用後可呼叫二維分類符號表格，提供常用、表情符號、標點、括號等多種分類，支援翻頁瀏覽；Ctrl+`` ` `` 則開啟舊式清單式符號表。

唯音分支專案及唯音詞庫（先鋒語料庫）由孫志貴（Shiki Suen）維護，其內容屬於可在 Gitee 公開展示的合法內容。但這些內容在被整理收入先鋒語料庫之前的原始資料的合規性不屬於維護者的負責範圍之內。

> 資安宣告：唯音輸入法的 Shift 按鍵監測功能僅藉由對 NSEvent 訊號資料流的上下文關係的觀測來實現，僅接觸藉由 macOS 系統內建的 InputMethodKit 當中的 IMKServer 傳來的 NSEvent 訊號資料流、而無須監聽系統全局鍵盤事件，也無須向使用者申請用以達成這類「可能會引發資安疑慮」的行為所需的輔助權限，更不會將您的電腦內的任何資料傳出去（本來就是這樣，且自唯音 2.3.0 版引入的 Sandbox 特性更杜絕了這種可能性）。請放心使用。Shift 中英模式切換功能要求至少 macOS 10.15 Catalina 才可以用。

## 系統需求

建置用系統需求：

- **Xcode 26+ (macOS 15.6+ required)** 或單獨安裝的 **Swift 6.2 open-source toolchain** + **macOS 26 SDK**。
    - 原因：Swift 6.2 成為必需版本（用於改進 concurrency 安全特性、SPM 6.2.4+ API 支援、CommandPlugin 改進等）。
- 請使用正式發行版 Xcode，且最小子版本號越高越好（因為 Bug 相對而言最少）。
    - 如果是某個大版本的 Xcode 的 Release Candidate 版本的話，我們可能會對此做相容性測試。

編譯出的成品對應系統需求：

- 至少 macOS 12 Monterey。
  - 如需要在更舊版的系統下運行的話，請前往[唯音輸入法主頁](https://vchewing.github.io/README.html)下載 Aqua 紀念版唯音輸入法，可支援自 macOS 10.9 開始至 macOS 12 Monterey 為止的系統版本。

- **推薦最低系統版本**：macOS 14 Sonoma。

  - 同時建議**系統記憶體應至少 4GB**。唯音輸入法佔用記憶體約 115MB 左右（簡繁雙模式）、75MB左右（單模式），供參考。
    - 請務必使用 SSD 硬碟，否則可能會影響每次開機之後輸入法首次載入的速度。從 10.10 Yosemite 開始，macOS 就已經是針對機械硬碟負優化的作業系統了。

- 關於全字庫支援，因下述事實而在理論上很難做到最完美：

  - 很可惜 GB18030-2005 並沒有官方提供的逐字讀音對照表，所以目前才用了全字庫。然而全字庫並不等於完美。
  - 有條件者可以安裝全字庫字型與花園明朝，否則全字庫等高萬國碼碼位漢字恐無法在輸入法的選字窗內完整顯示。
    - 全字庫漢字顯示支援會受到具體系統版本對萬國碼版本的支援的限制。
    - 有些全字庫漢字一開始會依賴萬國碼的私人造字區，且在之後被新版本萬國碼所支援。

## 建置流程

安裝 Xcode 之後，請先配置 Xcode 允許其直接構建在專案所在的資料夾下的 build 資料夾內。步驟：
```
「Xcode」->「Preferences...」->「Locations」；
「File」->「Project/WorkspaceSettings...」->「Advanced」；
選「Custom」->「Relative to Workspace」即可。不選的話，make 的過程會出錯。
```

在終端機內定位到唯音的克隆本地專案的本地倉庫的目錄之後，執行下列指令：

- `make update`：取得最新詞庫資源（使用遠端 Swift Package plugin）。
- `make release`：建置通用二進制版本（arm64 + x86_64），輸出至 `Build/Products/Release/`。
- `make archive`：建置通用版本並產生 `.xcarchive` 存檔（含 dSYM），存入 Xcode Archives 目錄。
- `make debug`：快速偵錯組建（單一架構）。

或者直接開啟 Xcode 專案，Product -> Scheme 選「vChewingInstaller」，編譯即可。

第一次安裝完之後，如有修改原廠辭典與程式碼的話，只要重覆上述流程重新安裝輸入法即可。

如果安裝若干次後，發現程式修改的結果並沒有出現、或甚至輸入法已無法再選用的話，請重新登入系統。

## 關於該倉庫的歷史記錄

該輸入法早於 4.1.3 版的記錄全部放在[vChewing-macOS-AncientArchive](https://github.com/vChewing/vChewing-macOS-AncientArchive)倉庫內。

## 應用授權

唯音輸入法 macOS 版以 MIT-NTL License 授權釋出 (與 MIT 相容)：© 2021-2022 vChewing 專案。

- 唯音輸入法 macOS 版程式維護：Shiki Suen。特別感謝 Isaac Xen 與 Hiraku Wong 等人的技術協力。
- 鐵恨注音並擊處理引擎：Shiki Suen (AGPL-3.0-or-later License)。
- 天權星語彙處理引擎：Shiki Suen (AGPL-3.0-or-later License)。
- 唯音詞庫（先鋒語料庫）由 Shiki Suen 維護，以 3-Clause BSD License 授權釋出。其中的詞頻資料[由 NAER 授權用於非商業用途](https://twitter.com/ShikiSuen/status/1479329302713831424)。

使用者可自由使用、散播本軟體，惟散播時必須完整保留版權聲明及軟體授權、且「一旦經過修改便不可以再繼續使用唯音的產品名稱」。換言之，這條相對上游 MIT 而言新增的規定就是：你 Fork 可以，但 Fork 成單獨發行的產品名稱時就必須修改產品名稱。

$ EOF.

---

## Changelog（個人修改版）

### 2026.04.19

#### 🔄 上游同步（upstream/main @ vChewing/vChewing-macOS — 4.3.5 + 4.3.6 GM）

- **IMEStateData — BPMFVS 標記模式污染修復**：新增 `rawDisplayTextSegments` / `rawDisplayedText` 機制。在啟用 BPMFVS 組字區即時反映時，標記模式（`ofMarking`）的使用者加詞操作（`userPhraseKVPair`）現在保證寫入原始漢字，不再含有 Unicode Variation Selector（`U+E0100–U+E01EF`）。新增 `rawDisplayTextSegmentsIfNeeded`、`insertReadingIntoSegments()` 輔助函式，並傳播至所有生成標記狀態的呼叫點。新增測試 `test_IH103D_ButKoBPMFVSMarkingStateDoesNotPollute` 與 `test_IH103E_ButKoBPMFVSCandidatePreviewKeepsRawStateInSync` 驗證此行為。
- **LMAssembly — 全字庫單字過濾策略調整**：在繁體中文模式下啟用 CNS11643 讀音過濾時，單個漢字（`keyArray.count == 1`）的不合規 Unigram 改為將分數降至 `-9.5`（降權），而非直接濾除，避免罕用字完全消失。新增 CNS 過濾選項的 i18n 描述字串。
- **Hotenka v2.0.0 — 轉換字典後端升級**：將簡繁轉換字典後端從 SQLite / JSON / Plist 全面改為 `.stringmap` 純文字格式，大幅改善載入速度與套件體積。測試檔案同步重寫為 `HotenkaTests_StringMap.swift`。
- **BookmarkMgr — iCloud Drive 沙盒掛起修復**：修正在沙盒環境下開啟 iCloud Drive 資料夾時造成 App 掛起的問題，新增對應測試案例。
- **Uninstaller — 卸載流程 UX 改善**：新增卸載確認對話框流程，更新多語系字串（en / ja / zh-Hans / zh-Hant）。
- **字典資料更新**：`vChewing-VanguardLexicon` 資料日期升至 `20260416`；CNS11643 時間戳更新至 `2026-03-18`。
- `Scripts/vchewing-update.swift` 更新腳本修補。

**衝突處理**：`rawDisplayTextSegmentsIfNeeded` 加入 `frozenSegments` 前綴支援（SmartSwitch 相容）；`committableDisplayText()` 完整保留；`test_IH103C`（fork）與上游 `test_IH103D`、`test_IH103E` 全數保留。版本號維持 fork 日期制（`2026.04.19 / 20260419`）。

---

### 2026.04.14

#### ✨ 新功能

- **智慧中英文切換 — Shift 鍵就地切換**：在「智慧中英文切換」啟用時，Shift 鍵依組字區狀態分兩種行為：
  - **組字區有內容**：就地切換臨時中英文模式。中文 → 英文時，原有注音文字凍結為前綴並進入英文緩衝區；英文 → 中文時，英文緩衝區內容凍結為新前綴並回到中文輸入。切換時顯示 tooltip「英」或「中」（1.5 秒），組字區全程不送出，按 Enter 才整段提交。
  - **組字區為空**：維持原有全域 `isASCIIMode` 切換（右上角通知照舊），並額外顯示 tooltip「英」或「中」與組字區有內容時的切換視覺一致。

#### 🐛 修復

- 修正 Shift 就地切換（中 → 英 → 中）時，組字區文字重複顯示的 bug。根本原因：`freezeAssemblerContentIfNeeded()` 只複製文字至 `frozenSegments` 但不清除 assembler；切回中文時 `generateStateOfInputting()` 同時展示兩者造成重複。修正方式：參照 `triggerTempEnglishMode` 的流程，於凍結後呼叫 `switchState(ofAbortion)` 完整清除狀態再重設 `frozenSegments`。
- 修正 Typewriter 套件測試檔案中呼叫已棄用 `connectToTestSQLDB` API 的問題（`AutoBracketTests`、`SimilarPhoneticTests`、`SmartSwitchTests`），更新為 `connectToTestFactoryDictionary(textMapData:)`。

#### 🔧 維護

- 修正所有 `Package.resolved` 中 `vChewing-VanguardLexicon` 版本鎖定不一致（4.3.2 → 4.3.3，revision `83b0f980`）。
- 修正 Xcode 專案 `project.pbxproj` 缺少 `XCLocalSwiftPackageReference` 造成「Missing package product」的問題，補齊 `vChewing_MainAssembly4Darwin` 與 `vChewing_InstallerAssembly4Darwin` 的本地套件參照。
- 更新 `CLAUDE.md`：補充 `vChewing_Shared` 模組說明、IMEState 類型對照表、SmartSwitchState fork-specific 說明。

---

### 2026.04.13

#### 🔄 上游同步 ②（upstream/main @ vChewing/vChewing-macOS — 4.3.4 GM）

- **BPMFVS 組字區即時反映**（`ButKo_BPMFVS`）：在 `CmdOptCtrlEnter = 4` 模式下啟用時，組字區顯示文字會即時替換為帶有 Unicode 異體字選擇子（Variation Selector）的注音符號字形，但實際遞交至客體軟體的文字仍為原始漢字（不含 VS），避免相容性問題。對應新設定項 `kReflectBPMFVSInCompositionBuffer`（本 fork 預設為 `true`；upstream 預設 `false`）。
- **`committableDisplayText()` API 新增**：分離「顯示用文字」與「遞交用文字」的取得方式，避免 BPMFVS 視覺符號被意外送出。本 fork 對此函式做了擴充，使其同時支援 SmartSwitch 的 `frozenSegments` 前置與 `isTempEnglishMode` 英文緩衝遞交，確保既有 SmartSwitch 功能不受影響。
- **字典資料更新**：`vChewing-VanguardLexicon` 資料日期升至 `20260415`（套件版本 4.3.4）。
- 新增測試 `test_IH103C_ButKoBPMFVSPlainEnterCommitsRawText`：驗證 Enter 鍵在 BPMFVS 顯示模式下遞交的是原始漢字而非 VS 字串。

**衝突處理**：`kReflectBPMFVSInCompositionBuffer` 預設值保留 fork 的 `true`；`committableDisplayText()` 加入 SmartSwitch 擴充；版本號維持 fork 日期制（`2026.04.13 / 20260413`）；上游同步原則補充至 `CLAUDE.md` 與 `AGENTS.md`。

---

#### 🔄 上游同步 ①（upstream/main @ vChewing/vChewing-macOS — 4.3.3 GM）

- **LMAssembly — 詞庫格式升級 SQL → VanguardTextMap**：原廠詞庫後端從 SQLite（`VanguardSQLLegacyPlugin`）全面改為 `.txtMap` 純文字格式（`VanguardTextMapPlugin`）。新後端採用有序陣列索引 + 二分搜尋 + NSCache，並於載入時自動生成反查表（`reverseLookupTable`），不再依賴獨立 `.revlookup` 檔案。
- **字典資料版本**：`vChewing-VanguardLexicon` 套件版本更新至 `4.3.3`（字典資料日期：20260411）。
- `.gitignore` 新增忽略 `./tmp` 目錄。

**衝突處理**：版本號維持 fork 日期制（`2026.04.06 / 20260406`）；`AGENTS.md` 保留 fork 擴充版；`CLAUDE.md` 更新詞庫 plugin 命名並保留 Fork Policy。

---

### 2026.04.11

#### ✨ 新功能

- **近似音設定**（Fuzzy Phonetic Settings）：將原先單一的「ㄣ/ㄥ 容錯輸入」開關擴充為完整的近似音系統。新增總開關「使用近似音」，以及可獨立勾選的 10 條規則：
  - 聲母：ㄅ↔ㄆ、ㄈ↔ㄏ、ㄌ↔ㄋ、ㄗ↔ㄓ、ㄘ↔ㄔ、ㄙ↔ㄕ
  - 韻母：ㄣ↔ㄥ、ㄢ↔ㄤ、ㄧㄣ↔ㄧㄥ、ㄨㄣ↔ㄨㄥ
  - 設定 UI 採二欄佈局（聲母左欄、韻母右欄），總開關關閉時子選項自動灰化
  - 向下相容：原本已開啟 ㄣ/ㄥ 開關的使用者，升級後自動遷移

#### 🐛 修復

- 修正 ESC 鍵無法關閉 `ofSymbolTableGrid`（二維符號表格）狀態的問題
- 修正設定說明文字中含有反引號（`` ` ``）時，在 AppKit 與 SwiftUI 介面均出現 Markdown 誤渲染的問題
- 修正 `TDKCandidateController` 多行候選窗格的行容量計算錯誤，並補足相關單元測試
- 修正 `shouldAutoExpandCandidates` 在特定情境下的判斷邏輯

#### ♻️ 重構

- `OSImpl`：以 `NSLabelView` 取代濫用的 `NSTextField` 靜態文字實作，新增多項 AppKit Result Builder DSL API
- `SettingsCocoa`：調整「服務與用戶端」設定頁的版面配置

---

### 2026.04.06

#### ✨ 新功能

- 二維分類符號表格（`ofSymbolTableGrid`）：單按 `` ` `` 鍵觸發，提供常用、表情符號、標點、括號等分類，支援翻頁瀏覽
- 自動括號配對：全形與半形括號輸入時自動補完右括號
- 自動學習詞語：選字達到門檻次數後自動寫入使用者辭典
- 近音表選字（↑ 鍵觸發）：展開二維近音／同音候選表
- 智慧中英文切換：注音輸入期間自動偵測英文詞彙並切換至英文緩衝區

#### 🐛 修復

- 上游同步（2026-03-08）
