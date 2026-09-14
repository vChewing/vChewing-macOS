# 唯音（vChewing）演算法說明

本文件說明唯音（vChewing）在 macOS 上的核心演算法與模組分工，涵蓋：注音符號（ㄅㄆㄇㄈ）與鍵盤配置、輸入態械（FSM）、組句引擎（Homa，採用 DAG 動態規劃），以及語言模型匯流（LexiconAssembly）和字典資料來源（VanguardLexicon）。

## 建置與測試

詳細建置與測試請見根目錄 AGENTS.md。
- 開發環境：Swift 6.2+（`Package.swift` 為 `swift-tools-version` 6.2；CI 於 `macos-26` 使用 Xcode 26.6）。
- 執行環境：本倉庫內之 Xcode 工程以 macOS 12+ 為目標；低版本 macOS (10.9 Mavericks) 支援則另有專案手動維護。
- 單元測試：各 Swift Package 於 Packages/ 下以 Swift Testing / XCTest 進行；Linux 上可直接在 LibVanguard、Homa 等套件執行 `swift test`。

---

## 目錄

- [整體架構與資料流](#整體架構與資料流)
  - [關鍵模組](#關鍵模組)
  - [事件到輸出的基本流程](#事件到輸出的基本流程)
- [注音組字：Tekkon](#注音組字tekkon)
  - [鍵盤配置與按鍵映射](#鍵盤配置與按鍵映射)
  - [音節合法化與組音規則](#音節合法化與組音規則)
- [打字管理器 LibVanguard 與輸入態械管理](#輸入態械osneutralassembly)
  - [KBEvent 轉換與分診](#kbevent-轉換與分診)
  - [IMEState 狀態與轉移](#imestate-狀態與轉移)
- [組句引擎：Homa（DAG 動態規劃）](#組句引擎homadag-動態規劃)
  - [資料模型](#資料模型)
  - [尋路演算法（PathFinder）](#演算法pathfinder)
  - [範例](#範例)
- [語言模型匯流：LexiconAssembly](#語言模型匯流lexiconassembly)
  - [子語言模型與分數](#子語言模型與分數)
  - [使用者選字與優先規則](#使用者選字與優先規則)
  - [關聯詞語與符號輸出](#關聯詞語與符號輸出)
- [字典與語料：VanguardLexicon](#字典與語料vanguardlexicon)
  - [生成工具與產物](#生成工具與產物)
- [關鍵檔案位置](#關鍵檔案位置)
- [延伸閱讀](#延伸閱讀)
- [文件版本與更新紀錄](#文件版本與更新紀錄)

---

## 整體架構與資料流

### 關鍵模組

- Packages/vChewing_MainAssembly4Darwin：IMK 進入點與整合。Sessions 體系（`InputSession` 等）已遷移至 LibVanguard 且 OS-independent；本套件僅保留 Darwin 表面（`InputSession_DarwinSurface.swift`：controller 綁定、NSEvent→KBEvent 轉換、IMKInputController surface、`toggleInputMode`）與 `SessionHostWiring.swift`（`SessionHost` 閉包注入）。InputSession 也參與態械管理。
- Packages/vChewing_OSNeutral_LibVanguard：輸入處理邏輯、態械與鍵盤事件分診；亦提供整個 OS-independent 會話體系（`Session` 子目錄）：`SessionCoreProtocol` 作為所有輸入法會話（含測試用 MockSession 與 Darwin SessionProtocol）的共用基底協定，另有 `SessionProtocol`＋`InputSession`（會話類別）、`IMEState` factories／`IMEStateParsed`、`SessionClientProxy`（跨平台客戶端 proxy 抽象）、`SessionHost`（OS-dependent 動作注入點，未注入＝無操作預設）。
- Packages/vChewing_OSNeutral_LibVanguard/Sources/Tekkon：注音（ㄅㄆㄇㄈ）鍵盤與音節組合。
- Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa：句子組裝（DAG-DP 動態規劃求最大分數路徑、候選覆寫與上下文鞏固）。
- Packages/vChewing_OSNeutral_LibVanguard/Sources/LexiconAssembly：語言模型匯流與資料來源整合。
- Lexicon 資料：由遠端 `vChewing-VanguardLexicon` 倉庫的 `VanguardTextMapPlugin` Swift Package plugin 於建置時編譯注入（非 git 子模組）。

### 事件到輸出的基本流程

1. NSEvent 抵達 → IMK 實例化的 `IMKInputSessionController`（vChewing_IMKUtils）經 `SessionControllerSputnik` 轉發至對應的 `InputSession`；Darwin 表面 `InputSession_DarwinSurface.handleNSEvent` 將 NSEvent 轉為 KBEvent 後交給 portable 會話核心。
2. InputSession 根據 KeyUp 與 KeyDown 的文脈關係事先決定某些行為（比如對 Shift 鍵的單擊行為的感知），然後將 KeyDown（KBEvent）交給 LibVanguard.InputHandler 分診。
3. Tekkon 組音（依使用者配置的鍵盤與容錯規則）得出合法注音鍵序列，由 InputHandler 將合法注音鍵序列塞入 Homa 引擎。
4. LexiconAssembly 依鍵序列回傳候選語元（unigram 為主，另附加帶前後文語境的 bigram／trigram 語元——POM n-gram 注入詳見後文），皆含分數。
5. Homa 以候選節點建立 DAG，用動態規劃求最大總分路徑，產出組句。此過程不依賴「Vertex Topological-Sort Relax」方法。
6. MainAssembly 依 IMEState 與結果更新 UI、提交輸出至目標應用。

---

## 注音組字：Tekkon

注拼並擊處理引擎「Tekkon (齊鐵恨)」提供鍵盤布局（如標準注音、倚天、許氏等）與音節組合規則，將鍵盤事件流轉為合法的注音鍵序列。

- 該引擎的並擊是指：聲母介母韻母可以亂序輸入，但聲調鍵確認音節組合。
- 非法鍵組會被拒收或等待補齊（如聲母後必須接介音/韻母；輕聲與聲調處理）。
- 支援多種鍵盤排列與使用者偏好（如「ㄓㄔㄕ」是否允許單獨作韻）。
- 產物是「鍵序列」，之後交由語言模型查詢。

> 關鍵檔案：Packages/vChewing_OSNeutral_LibVanguard/Sources/Tekkon/

---

## 打字管理器 LibVanguard 與輸入態械管理

LibVanguard 是可以在 Linux 系統下建置的 Swift Package，以一個比較小的工作範圍來集中處理輸入法的核心打字邏輯。其主要元件 `InputHandler` Protocol 把 UI 與輸入流程拆成可測的狀態與事件。

`SessionCoreProtocol` 亦定義於 LibVanguard（`Session/SessionCoreProtocol.swift`），為所有輸入法會話（包含測試用 MockSession 與 Darwin 生產環境的 `SessionProtocol`）提供共用的 `switchState()` 與 `resetInputHandler()` 預設實作，避免在 Shared/LibVanguard/MainAssembly 之間重複相同邏輯。整個會話體系（`SessionProtocol`、`InputSession`、`IMEState` factories、`IMEStateParsed`、`SessionClientProxy`、`SessionHost`）均位於 LibVanguard 的 `Session/` 子目錄且 OS-independent——所有 OS-dependent 動作（LXMgr、IMEApp、Notifier、AppDelegate、NS* 系列、IMKHelper 等）皆由 `SessionHost.shared` 的閉包屬性注入（MainAssembly 的 `SessionHostWiring.swift` 於啟動時呼叫 `wireUp()`），未注入時維持無操作預設值，使套件可在 Linux／Windows 直接編譯。

> 關鍵檔案：Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/

### KBEvent 轉換與分診

- Darwin 端 `InputSession_DarwinSurface` 將 NSEvent 轉 KBEvent，再交給 portable 會話核心（`handleEvent(KBEvent?)`）；
- InputHandler 根據 KBEvent 與目前 IMEState 決定：
  - 交由 Tekkon 組音、或
  - 觸發候選導覽、遞交（俗稱「上屏」）、撤銷等動作。

### IMEState 狀態與轉移

`SessionCoreProtocol`（定義於 LibVanguard）提供 `switchState()` 與 `resetInputHandler()` 的預設實作，各平台 Session 僅需實作五個抽象方法（`commit`、`toggleCandidateUIVisibility`、`showTooltip`、`getMitigatedState`、`updateCompositionBufferDisplay`）；OS-dependent 動作則經 `SessionHost` 閉包注入（Darwin 端見 `SessionHostWiring.swift`）。

- IMEState 是可序列化的邏輯狀態枚舉/結構，驅動：
  - 組字區內容與游標的記錄鏡照。
  - 候選視窗開關與列表。
  - 特殊模式（標點、數字小鍵盤、日期巨集）。
- 請以新增顯式狀態與轉移來擴展，不建議用旗標繞過既有流程。

---

## 組句引擎：Homa（DAG 動態規劃）

組句引擎「Homa」以 Swift 原生實作，將「鍵序列對應的所有候選語元」組成節點圖，使用動態規劃在 DAG 上找出最大總分路徑。2026 年 04 月下旬起，主線輸入流程已由 Megrez 遷移至 Homa；Homa 除了承接 DAG-DP 組句，亦直接提供候選覆寫、輪替、上下文鞏固與 POM 觀測資料生成 API。

### 資料模型

檔案位置：Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/
- Gram：單一候選（值＋機率分數；可選 previous／anterior 字段承載雙元／三元語法的前驅字詞值、不含讀音）。
- Node：某一段鍵序列對應的一組 Gram，含：
  - keyArray：覆蓋的鍵數。
  - grams：候選清單。
  - currentOverrideType / overridingScore：當前覆寫狀態與強制權重。
  - isExplicitlyOverridden：是否因使用者選字而覆寫。
  - getScore(previous:anterior:)：語境計分（見 PathFinder）——帶前驅字詞值時於 grams 中找相符的雙元／三元圖，僅當權重高於 unigram 基線時取代之；節點覆寫狀態優先於此計分。
- Segment：從某起點可用的多種節幅（length → Node）。
- GramInPath：回傳給外層的已選語元（值＋override 標記）。
- CandidatePair / CandidatePairWeighted：候選視圖與權重封裝。
- PerceptionIntel：POM 觀測資料，供 `LXPerceptor` 寫入記憶。

### 尋路演算法（PathFinder）

核心實作：Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/Homa_MainComponents/Homa_PathFinder.swift

- 令 keyCount 為鍵序列長度；建立陣列：
  - dp[i]：到達位置 i 的最佳分數（預設負無限，dp[0]=0）
  - parent[i]：到達 i 的最佳前驅節點（Node）與其幅節長度
- 對每個可達位置 i，枚舉該起點的所有節點（length, node）：
  - next = i + length；newScore = dp[i] + node.getScore(previous:anterior:)
  - previous／anterior 取自「最佳路徑前驅」：previous 為 parent[i] 節點的字詞值；anterior 為沿最佳路徑自 i 再往前跳 parent[i] 幅長後（前驅節點起點之前）的字詞值——bigram「最佳路徑前驅」近似的三元擴展，1D DP 結構不變
  - getScore 僅在 grams 中找到「previous（或連同 anterior）相符、且權重高於 unigram 基線」的雙元／三元圖時才取代 unigram 分數
  - 若 newScore > dp[next]，則更新 dp[next] 與 parent[next]
- 由尾端回溯 parent，依各前驅節點的幅節長度往回跳（非 gram.keyArray 長度——前綴匹配可能回傳更長的 gram），建立最終路徑（GramInPath 陣列）

此作法為典型 DAG 上的動態規劃，時間複雜度約為 O(N + E)（N 為節點位置，E 為可能邊數），記憶體使用量小且實作簡潔。

> 此作法不依賴「Vertex Topological-Sort Relax」方法。

### 範例

鍵序列長度為 4 時，若在位置 0 有單字節點「A」、位置 2 有雙字節點「CD」，則可能最佳路徑為「A → B → CD」，總分為各節點分數加總。Homa 會透過 dp/parent 自動回溯得到該輸出序列。更多範例請洽 Homa 與 LibVanguard 的單元測試。

---

## 語言模型匯流：LexiconAssembly

LexiconAssembly 對多個子語言模型進行匯整、去重、替換與增益調整，對外提供以「鍵序列」為鍵的 Homa Gram 陣列。

關鍵檔案：Packages/vChewing_OSNeutral_LibVanguard/Sources/LexiconAssembly/

### 子語言模型與分數

常見子 LM（可視專案配置有所變動）：
- lxPlainBopomofo：ㄅ半注音對應單字/詞，使用倚天中文 DOS 環境原版候選字陳列順序。
- lxCassette：磁帶模組，可以讀入 CIN2 格式的輸入法表格，也與 CIN1 相容。
- lxCoreEX：以「位元組範圍索引」承載純文字辭典資料的通用模組，用於使用者片語辭典等（本倉庫執行期字典載體為純文字／TextMap，已無 SQL 資料庫辭典）。
- lxReplacements：詞彙替換表（正規化、傳統/簡體外掛轉換之前後）
- lxAssociates：關聯詞語（含標點相依）
- LXPerceptor：漸退記憶（POM）感知模組——觀察使用者選字／遞交行為，以三層 ngramKey（head 讀音＋前後文值）寫入 LRU 記憶並隨時間衰減；帶前後文的記憶可作為 Homa 的 bigram／trigram 統計來源（見「使用者選字與優先規則」），另有建議查詢通道供 LibVanguard 自動套用。
- 擴充：日期時間等服務模式巨集、數字小鍵盤模式、符號表等（LXFacade_*）

各 gram 會帶有可加總的「分數」（通常是對數空間值或相容值），以利 Homa 做組句結果推算。

### 使用者選字與優先規則

- 使用者對某鍵序列手動選擇某候選時，LibVanguard 會要求 Homa 對該鍵序列上調該候選的優先級（或標記 explicit override），影響之後同鍵序列的排序。這期間可能會對任何影響該目的的 Node 使用指定的降權評分。
- POM（漸退記憶）亦以「Homa n-gram 統計來源」直接參與組句：`unigramsFor` 的注入路徑於 `kFetchSuggestionsFromPerceptionOverrideModel`（預設啟用）開啟時以 `perceptionsFor(headReading:)` 撈取記憶，僅將帶上下文（previous／anterior）者附加為 bigram／trigram gram（bare unigram 記憶不進引擎、由 LibVanguard 建議通道浮現）。讀音比對預設 `.exact`：查詢段帶聲調（具體讀音）時須與記憶逐字等值——避免「打『有』出『右』」類跨聲調錯位注入；查詢段不帶聲調（狂拼聲調桶代表鍵／前綴 partial）維持去聲調等值容錯。`.toneInsensitivePrefix` 則為全局去聲調等值、供狂拼建議查詢。另設注音錯位守衛：注音讀音記憶若「候選字數 ≠ head 讀音段數」（錯位髒資料，如「體式」誤記於單鍵 ㄕˊ 之下）一律不套用／不餵入。LibVanguard 的建議套用入口同樣受 `kFetchSuggestionsFromPerceptionOverrideModel` 把守。
- 單音節與多音節的相對優先可藉由分數基準或「POM 所帶來的微幅增益」維持體感合理性，又避免壓制更長詞彙的組句。

### 關聯詞語與符號輸出

- 在特定條件（如結尾為標點、或 UI 提示）下，lxAssociates 會給出與當前輸出語境相關的下一步候選（含標點）。
- 這類候選可由 UI 以候選窗或熱鍵導覽。
- 關聯詞語功能不使用組字區。

---

## 字典與語料：VanguardLexicon

本專案的字典與語料由外部倉庫 `vChewing-VanguardLexicon` 維護。工廠詞庫由遠端 Swift Package plugin `VanguardTextMapPlugin` 於建置時編譯為 Vanguard TextMap 格式（`.txtMap` + `.revlookup` 對）並注入至 `vChewing_MainAssembly4Darwin`（非 git 子模組）；執行期後端為 `VanguardTrie.TextMapTrie`。

開發者一般不建議在本倉庫中直接修改大型辭典腳本或編譯產物，除非有特定任務。

---

## 關鍵檔案位置

- MainAssembly：
  - Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_DarwinSurface.swift（IMK surface：controller 綁定、NSEvent→KBEvent 轉換、IMKInputController surface、`toggleInputMode` TIS 邏輯）
  - Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/SessionControllerSputnik.swift
  - Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/SessionHostWiring.swift（`SessionHost` 閉包注入）
- LibVanguard：
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/*.swift
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/Session/（OS-independent 會話體系：`SessionCoreProtocol`、`SessionProtocol`、`InputSession`、`IMEState` factories、`IMEStateParsed`、`SessionClientProxy`、`SessionHost`）
- Tekkon：
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/Tekkon/
- Homa：
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/Homa_MainComponents/Homa_Assembler.swift
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/Homa_MainComponents/Homa_PathFinder.swift
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/Homa_MainComponents/Homa_CandidateAPIs_FetchAndApply.swift
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/Homa_MainComponents/Homa_ConsolidatorAPIs.swift
- LexiconAssembly：
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/LexiconAssembly/LXConsolidator.swift
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/LexiconAssembly/LXFacade*.swift
  - Packages/vChewing_OSNeutral_LibVanguard/Sources/LexiconAssembly/SubLMs/*.swift
- VanguardLexicon（外部倉庫）：
  - `vChewing-VanguardLexicon`（詞庫編譯工具與語料來源，非本倉庫子模組）

---

## 延伸閱讀

- AGENTS.md（本庫工作流程與規範總覽）
- Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/Homa_MainComponents/Homa_PathFinder.swift（DAG 動規實作）
- Packages/vChewing_OSNeutral_LibVanguard/Sources/Tekkon/（注音組音與鍵盤邏輯）
- Packages/vChewing_OSNeutral_LibVanguard/Sources/LexiconAssembly/（語言模型匯流）

---

## 文件版本與更新紀錄

- 文件版本：1.6
- 最後更新：2026-09-06
- 適用版本：vChewing 4.7.3 SP1（Build 4731）及之後的版本
