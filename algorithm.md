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
- [關鍵檔案位置](#關鍵檔案位置)
- [延伸閱讀](#延伸閱讀)
- [文件版本與更新紀錄](#文件版本與更新紀錄)

---

## 整體架構與資料流

### 關鍵模組

- Packages/vChewing_MainAssembly：IMK 進入點與整合（SessionCtl → InputSession）。InputSession 也參與態械管理。
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
  - Packages/vChewing_MainAssembly/Sources/MainAssembly/SessionController/SessionCtl.swift
  - Packages/vChewing_MainAssembly/Sources/MainAssembly/SessionController/InputSession*.swift
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

## 延伸閱讀

- AGENTS.md（本庫工作流程與規範總覽）
- Packages/vChewing_Megrez/Sources/Megrez/2_PathFinder.swift（DAG 動規實作）
- Packages/vChewing_Tekkon/（注音組音與鍵盤邏輯）
- Packages/vChewing_LangModelAssembly/（語言模型匯流）

---

## 文件版本與更新紀錄

- 文件版本：1.0
- 最後更新：2025-10-12T20:05:00+08:00
- 適用版本：vChewing 4.x 及以上
