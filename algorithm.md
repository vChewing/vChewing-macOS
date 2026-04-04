# 唯音（vChewing）演算法說明

本文件說明唯音（vChewing）在 macOS 上的核心演算法與模組分工，涵蓋：注音符號（ㄅㄆㄇㄈ）與鍵盤配置、輸入態械（FSM）、組句引擎（Megrez，採用 DAG 動態規劃），以及語言模型匯流（LangModelAssembly）和字典資料來源（Source/Data 子模組）。

> 唯音的「威」取自「威而鋼」的「威」。

## 建置與測試

詳細建置與測試請見根目錄 AGENTS.md。
- 開發環境：macOS 14.7+、Xcode 15.3+（Swift toolchain）。
- 執行環境：本倉庫內之 Xcode 工程以 macOS 12+ 為目標；低版本 macOS (10.9 Mavericks) 支援則另有專案手動維護。
- 單元測試：各 Swift Package 於 Packages/ 下以 XCTest 進行；Linux 上可直接在 Typewriter、Megrez 等套件執行 `swift test`。

---

## 目錄

- [整體架構與資料流](#整體架構與資料流)
  - [關鍵模組](#關鍵模組)
  - [事件到輸出的基本流程](#事件到輸出的基本流程)
- [注音組字：Tekkon](#注音組字tekkon)
  - [鍵盤配置與按鍵映射](#鍵盤配置與按鍵映射)
  - [音節合法化與組音規則](#音節合法化與組音規則)
- [打字管理器 Typewriter 與輸入態械管理](#輸入態械typewriter)
  - [KBEvent 轉換與分診](#kbevent-轉換與分診)
  - [IMEState 狀態與轉移](#imestate-狀態與轉移)
- [組句引擎：Megrez（DAG 動態規劃）](#組句引擎megrezdag-動態規劃)
  - [資料模型](#資料模型)
  - [尋路演算法（PathFinder）](#演算法pathfinder)
  - [範例](#範例)
- [語言模型匯流：LangModelAssembly](#語言模型匯流langmodelassembly)
  - [子語言模型與分數](#子語言模型與分數)
  - [使用者選字與優先規則](#使用者選字與優先規則)
  - [關聯詞語與符號輸出](#關聯詞語與符號輸出)
- [字典與語料：Source/Data 子模組](#字典與語料sourcedata-子模組)
  - [生成工具與產物](#生成工具與產物)
- [智慧中英文切換（Smart Chinese/English Switching）](#智慧中英文切換smart-chineseenglish-switching)
  - [SmartSwitchState 資料結構](#smartswitchstate-資料結構)
  - [進入與離開臨時英文模式](#進入與離開臨時英文模式)
  - [displayedText 與 englishBuffer 的組合](#displayedtext-與-englishbuffer-的組合)
  - [resetInputHandler 的 englishBuffer 遺漏修正（2026.04.01）](#resetinputhandler-的-englishbuffer-遺漏修正20260401)
- [關鍵檔案位置](#關鍵檔案位置)
- [延伸閱讀](#延伸閱讀)
- [文件版本與更新紀錄](#文件版本與更新紀錄)

---

## 整體架構與資料流

### 關鍵模組

- Packages/vChewing_MainAssembly4Darwin：IMK 進入點與整合（SessionCtl → InputSession）。InputSession 也參與態械管理。
- Packages/vChewing_Typewriter：輸入處理邏輯、態械與鍵盤事件分診。
- Packages/vChewing_Tekkon：注音（ㄅㄆㄇㄈ）鍵盤與音節組合。
- Packages/vChewing_Megrez：句子組裝（DAG-DP 動態規劃求最大分數路徑）。
- Packages/vChewing_LangModelAssembly：語言模型匯流與資料來源整合。
- Source/Data：字典與語料的編譯器與產物（git 子模組）。

### 事件到輸出的基本流程

1. NSEvent 抵達 → MainAssembly 的 SessionCtl 收下並委派 InputSession。
2. InputSession 根據 KeyUp 與 KeyDown 的文脈關係事先決定某些行為（比如對 Shift 鍵的單擊行為的感知），然後將 KeyDown 轉 KBEvent 交給 Typewriter.InputHandler 分診。
3. Tekkon 組音（依使用者配置的鍵盤與容錯規則）得出合法注音鍵序列，由 InputHandler 將合法注音鍵序列塞入 Megrez 引擎。
4. LangModelAssembly 依鍵序列回傳候選語元（unigram，含分數）。
5. Megrez 以候選節點建立 DAG，用動態規劃求最大總分路徑，產出組句。此過程不依賴「Vertex Topological-Sort Relax」方法。
6. MainAssembly 依 IMEState 與結果更新 UI、提交輸出至目標應用。

---

## 注音組字：Tekkon

注拼並擊處理引擎「Tekkon (齊鐵恨)」提供鍵盤布局（如標準注音、倚天、許氏等）與音節組合規則，將鍵盤事件流轉為合法的注音鍵序列。

- 該引擎的並擊是指：聲母介母韻母可以亂序輸入，但聲調鍵確認音節組合。
- 非法鍵組會被拒收或等待補齊（如聲母後必須接介音/韻母；輕聲與聲調處理）。
- 支援多種鍵盤排列與使用者偏好（如「ㄓㄔㄕ」是否允許單獨作韻）。
- 產物是「鍵序列」，之後交由語言模型查詢。

> 關鍵檔案：Packages/vChewing_Tekkon/Sources/Tekkon/

---

## 打字管理器 Typewriter 與輸入態械管理

Typewriter 是可以在 Linux 系統下建置的 Swift Package，以一個比較小的工作範圍來集中處理輸入法的核心打字邏輯。其主要元件 `InputHandler` Protocol 把 UI 與輸入流程拆成可測的狀態與事件。

> 關鍵檔案：Packages/vChewing_Typewriter/Sources/Typewriter/

### KBEvent 轉換與分診

- SessionCtl 將 NSEvent 轉 KBEvent；
- InputHandler 根據 KBEvent 與目前 IMEState 決定：
  - 交由 Tekkon 組音、或
  - 觸發候選導覽、遞交（俗稱「上屏」）、撤銷等動作。

### IMEState 狀態與轉移

- IMEState 是可序列化的邏輯狀態枚舉/結構，驅動：
  - 組字區內容與游標的記錄鏡照。
  - 候選視窗開關與列表。
  - 特殊模式（標點、數字小鍵盤、日期巨集）。
- 請以新增顯式狀態與轉移來擴展，不建議用旗標繞過既有流程。

---

## 組句引擎：Megrez（DAG 動態規劃）

組句引擎「Megrez (天權星，璃月七星之首)」以 Swift 原生實作，將「鍵序列對應的所有候選語元」組成節點圖，使用動態規劃在 DAG 上找出最大總分路徑。

### 資料模型

檔案位置：Packages/vChewing_Megrez/Sources/Megrez/
- Unigram：單一候選（值＋分數）。
- Node：某一段鍵序列對應的一組 Unigram，含：
  - keyArray：覆蓋的鍵數。
  - unigrams：候選清單。
  - score：當前選中 unigram 的分數（通常為對數分數）。
  - isOverridden：是否因使用者選字而覆寫。
- Segment：從某起點可用的多種節幅（length → Node）。
- GramInPath：回傳給外層的已選語元（值＋override 標記）。

### 尋路演算法（PathFinder）

核心實作：Packages/vChewing_Megrez/Sources/Megrez/2_PathFinder.swift

- 令 keyCount 為鍵序列長度；建立陣列：
  - dp[i]：到達位置 i 的最佳分數（預設負無限，dp[0]=0）
  - parent[i]：到達 i 的最佳前驅節點（Node）
- 對每個可達位置 i，枚舉該起點的所有節點（length, node）：
  - next = i + length；newScore = dp[i] + node.score
  - 若 newScore > dp[next]，則更新 dp[next] 與 parent[next]
- 由尾端回溯 parent，依 Node 的 keyArray.count 往回跳，建立最終路徑（GramInPath 陣列）

此作法為典型 DAG 上的動態規劃，時間複雜度約為 O(N + E)（N 為節點位置，E 為可能邊數），記憶體使用量小且實作簡潔。

> 此作法不依賴「Vertex Topological-Sort Relax」方法。

### 範例

鍵序列長度為 4 時，若在位置 0 有單字節點「A」、位置 2 有雙字節點「CD」，則可能最佳路徑為「A → B → CD」，總分為各節點分數加總。Megrez 會透過 dp/parent 自動回溯得到該輸出序列。更多範例請洽 Megrez 的單元測試。

---

## 語言模型匯流：LangModelAssembly

LangModelAssembly 對多個子語言模型進行匯整、去重、替換與增益調整，對外提供以「鍵序列」為鍵的 Unigram 陣列。

關鍵檔案：Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/

### 子語言模型與分數

常見子 LM（可視專案配置有所變動）：
- lmPlainBopomofo：ㄅ半注音對應單字/詞，使用倚天中文 DOS 環境原版候選字陳列順序。
- lmCassette：磁帶模組，可以讀入 CIN2 格式的輸入法表格，也與 CIN1 相容。
- lmCoreEX / SQL 擴充：SQL/資料庫驅動的核心辭典。lmCoreEX 用於純文字格式的使用者辭典。
- lmReplacements：詞彙替換表（正規化、傳統/簡體外掛轉換之前後）
- lmAssociates：關聯詞語（含標點相依）
- lmPerceptionOverride：感知覆寫（根據使用者交互行為暫調排序、給出 ngram 建議結果。）
- 擴充：日期時間等服務模式巨集、數字小鍵盤模式、符號表等（LMInstantiator_*）

各 unigram 會帶有可加總的「分數」（通常是對數空間值或相容值），以利 Megrez 做組句結果推算。

### 使用者選字與優先規則

- 使用者對某鍵序列手動選擇某候選時，Typewriter 會要求 Megrez 對該鍵序列上調該候選的優先級（或標記 isOverridden），影響之後同鍵序列的排序。這期間可能會對任何影響該目的的 Node 使用指定的降權評分。
- 單音節與多音節的相對優先可藉由分數基準或「POM 所帶來的微幅增益」維持體感合理性，又避免壓制更長詞彙的組句。

### 關聯詞語與符號輸出

- 在特定條件（如結尾為標點、或 UI 提示）下，lmAssociates 會給出與當前輸出語境相關的下一步候選（含標點）。
- 這類候選可由 UI 以候選窗或快捷鍵導覽。
- 關聯詞語功能不使用組字區。

---

## 字典與語料：Source/Data 子模組

本專案的字典與語料由 git 子模組 Source/Data 維護與生成。此子模組包含：
- VCDataBuilder（Swift）：生成不同目標引擎格式的辭典與索引。
- VanguardTrieKit 等工具庫（用於其他專案）。
- 產物通常位於 Source/Data/Build，供 LangModelAssembly 載入（例如 SQL/Plist/Trie 或其他中介檔）。

開發者一般不建議在本倉庫中直接修改大型辭典腳本或編譯產物，除非有特定任務。

---

## 關鍵檔案位置

- MainAssembly：
  - Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly/SessionController/SessionCtl.swift
  - Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly/SessionController/InputSession*.swift
- Typewriter：
  - Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/*.swift
- Tekkon：
  - Packages/vChewing_Tekkon/Sources/Tekkon/
- Megrez：
  - Packages/vChewing_Megrez/Sources/Megrez/0_Megrez.swift
  - Packages/vChewing_Megrez/Sources/Megrez/2_PathFinder.swift
  - Packages/vChewing_Megrez/Sources/Megrez/6_LangModel.swift
  - Packages/vChewing_Megrez/Sources/Megrez/7_Unigram.swift
- LangModelAssembly：
  - Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/LMConsolidator.swift
  - Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/LMInstantiator*.swift
  - Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/SubLMs/*.swift
- Data submodule：
  - Source/Data/README.MD（VCDataBuilder 使用說明）
  - Source/Data/Sources/*（生成工具原始碼）

---

## 智慧中英文切換（Smart Chinese/English Switching）

本功能由偏好設定中的 `smartChineseEnglishSwitchEnabled` 控制，允許使用者在輸入中文時臨時切換至英文模式、追加英文字母，無需手動切換輸入語言。

### SmartSwitchState 資料結構

位置：`Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift`

關鍵屬性：
- `isTempEnglishMode`：是否正處於臨時英文模式。
- `frozenSegments`：凍結的中文已組句節點（進入臨時英文模式前暫存的 Megrez 路徑節點）。
- `englishBuffer`：臨時英文模式下輸入的英文字母緩衝。
- `frozenDisplayText`：由 `frozenSegments` 轉換而來的顯示文字（唯讀）。

### 進入與離開臨時英文模式

`triggerTempEnglishMode()`（`Typewriter_Phonabet.swift`）：
1. 將目前 Megrez 已組句節點存入 `frozenSegments`。
2. 呼叫 `switchState(.ofAbortion())` 清空組字區（此時 `frozenSegments` 會被暫存，待狀態切換後還原）。
3. 設定 `isTempEnglishMode = true`，之後的字母鍵全進 `englishBuffer`。

`exitTempEnglishMode()`：
- 提交 `frozenDisplayText + englishBuffer` 的完整組合為最終輸出。
- 重置整個 `SmartSwitchState`。

### displayedText 與 englishBuffer 的組合

在臨時英文模式下，組字區的顯示文字 (`displayedText`) 為：
```
frozenDisplayText + englishBuffer
```

這兩段在 `generateStateOfInputting()` 的回傳值中**並不包含** `englishBuffer`，因為 `generateStateOfInputting` 僅讀取 Megrez 組裝器 (`assembler`) 的內容，而 `englishBuffer` 是獨立於 Megrez 之外的緩衝。

### resetInputHandler 的 englishBuffer 遺漏修正（2026.04.01）

#### 問題根源

當使用者按下 CapsLock 鍵時，macOS 發出 `.flagsChanged` 事件，`InputSession_HandleEvent.swift` 中的 `capsLockHitChecker?.check(event)` 偵測到此事件，並在 `asyncOnMain` 區塊中呼叫 `resetInputHandler()`。

`resetInputHandler()`（`InputSession_CoreProtocol.swift`）原本使用：
```swift
textToCommit = inputHandler.generateStateOfInputting(sansReading:).displayedTextConverted
```

由於 `generateStateOfInputting()` 只包含 `frozenSegments` + Megrez 組裝器內容，**不包含 `englishBuffer`**，導致在臨時英文模式下按下 CapsLock 時，`englishBuffer` 中已輸入的英文字母會遺失。

#### 修正方案

修正後的 `resetInputHandler()` 會在臨時英文模式時，將 `frozenDisplayText + englishBuffer` 合併後提交：

```swift
if inputHandler.smartSwitchState.isTempEnglishMode {
    let frozen = inputHandler.smartSwitchState.frozenDisplayText
    let english = inputHandler.smartSwitchState.englishBuffer
    textToCommit = ChineseConverter.kanjiConversionIfRequired(frozen + english)
} else {
    textToCommit = inputHandler.generateStateOfInputting(sansReading:).displayedTextConverted
}
```

同樣修正也同步套用至測試用的 `MockedInputHandlerAndStates.swift`。

### 路徑 D 有漢字前綴時的修正（2026.04.01）

#### 問題根源

路徑 D 觸發場景：使用者先以注音輸入漢字（如「中文」，已組入 Megrez 組字器），再鍵入的字母形成無效注音讀音（如大千鍵盤的 `t`=ㄔ、`o`=ㄟ → ㄔㄟ，語彙庫查無此讀音），接著按 Space。

原有的路徑 D 行為：
1. 呼叫 `smartSwitchState.reset()`（清空 frozenSegments）。
2. 呼叫 `freezeAssemblerContentIfNeeded()`，將「中文」凍結至 `frozenSegments`。
3. 清空組字器。
4. 呼叫 `switchState(ofCommitting("to"))`，將 keySequence 輸出給客體軟體。

問題在於步驟 4 之後沒有後續的 `generateStateOfInputting()` 呼叫，`frozenSegments` 中的「中文」永遠不會再顯示，使用者看到的結果是：`to` 先被輸出，「中文」無聲無息地消失。

#### 修正方案

在 `freezeAssemblerContentIfNeeded()` 執行完畢後，檢查 `frozenSegments` 是否非空：

- **有凍結漢字**：改進入臨時英文模式，將 `keySequence + " "` 放入 `englishBuffer`，並以 `ofInputting` 狀態顯示「中文」(frozen) + `"to "` (英文緩衝)。使用者可繼續輸入字母或按 Enter 一次提交所有內容。
- **無凍結漢字**（組字器為空）：維持原行為，直接 commit keySequence。

```swift
if !handler.smartSwitchState.frozenSegments.isEmpty {
    handler.smartSwitchState.enterTempEnglishMode()
    handler.smartSwitchState.appendEnglishChar(keysToCommit + " ")
    let frozen = handler.smartSwitchState.frozenDisplayText
    let buffer = handler.smartSwitchState.englishBuffer
    let combinedDisplay = frozen + buffer
    let newState = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: combinedDisplay.count,
        highlightAt: nil
    )
    session.switchState(newState)
} else {
    session.switchState(State.ofCommitting(textToCommit: keysToCommit))
}
```

迴歸測試：TC-038（`SmartSwitchTests.swift`）。

### '/' 斜線特例（2026.04.04）

#### 問題根源

在大千等鍵盤排列中，`'/'` 對應注音 `ㄥ`（韻母 slot）。使用者在智慧中英文切換模式下輸入路徑（`/usr/bin`）或日期（`2026/04/04`）時，每次按 `'/'` 都會把 `ㄥ` 塞入注拼槽，造成注音符號干擾，無法直接輸入斜線字元。

#### 修正方案

在 `handle()` 函式的「臨時英文模式攔截」之後、正常注音處理之前，加入 `'/'` 特例判斷：

**觸發條件（全部滿足時才攔截）：**
1. `smartChineseEnglishSwitchEnabled == true`
2. 當前**未**在臨時英文模式（`!isTempEnglishMode`）
3. `input.text == "/"`（裸斜線，無 Ctrl/Cmd/Option 修飾）
4. **組字器為空**（`handler.composer.isEmpty`）

**攔截後行為：**
1. 呼叫 `freezeAssemblerContentIfNeeded()` 凍結組字區中的漢字（若有）。
2. 設定 `keySequence = "/"` 後呼叫 `triggerTempEnglishMode()`。
3. 進入臨時英文模式，`englishBuffer = "/"`，組字區顯示 `frozenDisplayText + "/"`.
4. 使用者可繼續輸入數字或字母（例如日期），按 Enter 一次提交全部。

**組字器非空時不攔截：**
使用者若已輸入聲母（如 `ㄌ`），再按 `'/'` 應組成 `ㄌㄥ`，維持正常注音行為。

```swift
// 攔截點在 Typewriter_Phonabet.swift handle() 函式
if prefs.smartChineseEnglishSwitchEnabled,
   !handler.smartSwitchState.isTempEnglishMode,
   input.text == "/",
   !input.isControlHold, !input.isCommandHold, !input.isOptionHold,
   handler.composer.isEmpty {
    freezeAssemblerContentIfNeeded()
    handler.smartSwitchState.keySequence = "/"
    return triggerTempEnglishMode(session: session)
}
```

迴歸測試：TC-040（空組字器）、TC-041（有漢字前綴）、TC-042（組字器非空不攔截）。

### '/' + ↓ 後悔鍵：切換為 ㄥ 選字（2026.04.04）

#### 情境描述

使用者按下 `'/'` 後，輸入法因斜線特例進入臨時英文模式（`englishBuffer = "/"`），但使用者其實是要輸入 `ㄥ` 讀音的漢字。此時再按 **↓（下箭頭）** 即可「後悔」，切換回 `ㄥ` 注音選字。

#### 觸發條件

在 `handleTempEnglishMode()` 函式內，滿足以下全部條件時攔截：

1. `input.isDown == true`（無 Ctrl/Cmd/Option/Shift 修飾）
2. `englishBuffer == "/"`（英文緩衝恰好只有斜線，即尚未繼續打其他字元）

#### 攔截後行為

**主路徑（語言模型有 ㄥ 記錄時）：**
1. 取消臨時英文模式（捨棄 `"/"`，不提交）。
2. 若有凍結漢字（`frozenDisplayText`），先以 `ofCommitting` 提交給 OS。
3. 合成 `ㄥ` 讀音索引鍵（直接從注音符號繞過鍵盤排列轉換），插入組字區。
4. 呼叫 `assemble()` / `retrievePOMSuggestions()` 重新組句，切換至 `ofInputting` 狀態。
5. **回傳 `nil`**：讓 `triageInput()` 繼續執行，`callCandidateState()` 偵測到下箭頭而自動開啟選字窗。

**降級路徑（語言模型無 ㄥ 記錄時）：**
1. 取消臨時英文模式（同上）。
2. 若有凍結漢字，先提交。
3. 將 `ㄥ` 直接放入注拼槽（composer），切換至 `ofInputting` 狀態（preedit 顯示 `ㄥ`）。
4. **回傳 `true`**：消費下箭頭，等使用者補按聲調鍵後再選字。

```swift
// handleTempEnglishMode() 內，Escape 之後、Tab 之前
if input.isDown, !input.isControlHold, !input.isCommandHold, !input.isOptionHold, !input.isShiftHold,
   handler.smartSwitchState.englishBuffer == "/" {
  let frozen = handler.smartSwitchState.frozenDisplayText
  _ = handler.smartSwitchState.exitTempEnglishMode()
  handler.smartSwitchState.clearFrozenSegments()
  if !frozen.isEmpty { session.switchState(State.ofCommitting(textToCommit: frozen)) }
  // 合成 ㄥ 讀音
  var tempComposer = handler.composer; tempComposer.clear()
  for scalar in "ㄥ".unicodeScalars { tempComposer.receiveKey(fromPhonabet: scalar) }
  if let key = tempComposer.phonabetKeyForQuery(pronounceableOnly: false),
     handler.currentLM.hasUnigramsFor(keyArray: [key]),
     handler.assembler.insertKey(key) {
    handler.assemble(); handler.retrievePOMSuggestions(apply: true)
    handler.composer.clear(); session.switchState(handler.generateStateOfInputting())
    return nil // triageInput() → callCandidateState() 開選字窗
  }
  // 降級：ㄥ 放入注拼槽
  handler.composer.clear()
  for scalar in "ㄥ".unicodeScalars { handler.composer.receiveKey(fromPhonabet: scalar) }
  session.switchState(handler.generateStateOfInputting())
  return true
}
```

迴歸測試：TC-043（空組字器）、TC-044（有凍結漢字）。

### 關鍵檔案

| 檔案 | 用途 |
|------|------|
| `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift` | SmartSwitchState、triggerTempEnglishMode、handleTempEnglishMode、composeReadingIfReady（路徑 D）、'/' 斜線特例、'/' + ↓ 後悔鍵 |
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift` | `clear()` — 須呼叫 `smartSwitchState.reset()` |
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_TriageInput.swift` | `triageInput` — Space/CapsLock/英文字母的分診邏輯 |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_CoreProtocol.swift` | `resetInputHandler()` — CapsLock 觸發的重置，須納入 englishBuffer |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_HandleEvent.swift` | capsLockHitChecker → resetInputHandler 的觸發點 |
| `Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift` | 45 個測試案例（TC-001 ~ TC-044） |

---

## 延伸閱讀

- AGENTS.md（本庫工作流程與規範總覽）
- Packages/vChewing_Megrez/Sources/Megrez/2_PathFinder.swift（DAG 動規實作）
- Packages/vChewing_Tekkon/（注音組音與鍵盤邏輯）
- Packages/vChewing_LangModelAssembly/（語言模型匯流）

---

## 文件版本與更新紀錄

- 文件版本：1.1
- 最後更新：2026-04-01T00:00:00+08:00
- 適用版本：vChewing 2026.04.01 及以上
