# Feature Doc: 近音表選字 (Similar Phonetic Candidate Table)

> **適用專案**：ThomasHsieh/vChewing-macOS（fork 自 vChewing/vChewing-macOS）  
> **參考來源**：自然輸入法近音表截圖（ㄅㄛ、ㄇㄡ、ㄎㄨ、ㄘㄢ 四組實機截圖）  
> **目標模組**：`vChewing_Typewriter`、`vChewing_MainAssembly4Darwin`  
> **功能定位**：輸入完成後的「事後修正」工具，對組字區中的字進行同音/近音替換  
> **實作狀態**：✅ 已完成（2026.04.05）

---

## 1. 功能概述

近音表選字是一個**事後選字補正功能**。使用者在組字區輸入中文字後，按下【↑】（上方向鍵）觸發，系統針對游標所在位置的字，展開一個二維近音表候選視窗，列出：

- 該字的**同字同音、不同聲調**候選（同聲母韻母、各聲調）
- 該字的**近音字**（相似注音，如ㄘ↔ㄗ、ㄣ↔ㄥ、ㄡ↔ㄛ 等）

使用者可以用方向鍵或數字鍵選取正確的字，取代原本的字。

**典型使用情境**：
- 輸入「你幫我餐」，想換成「參」→ 按↑觸發近音表，從 ㄘㄢ 列選取「參」
- 輸入聲調打錯 → 從不同聲調列中找到正確字
- 方言口音（ㄇㄡ↔ㄇㄛ）導致選字不準，用近音表手動補正

---

## 2. 觸發機制

### 2.1 觸發條件

| 條件 | 說明 |
|------|------|
| 觸發鍵 | 【↑】上方向鍵（`NSUpArrowFunctionKey`） |
| 組字區狀態 | 組字區中至少有一個已組成的中文字（注音槽/筆根槽為空） |
| 游標位置 | 游標前一個字（即最後輸入的字） |
| 無效情況 | 組字區為空、注音槽未清空、或查詞庫查無任何候選時，↑鍵回歸正常行為 |
| 垂直打字模式 | 垂直模式下不觸發近音表（↑鍵回歸正常）|

### 2.2 觸發後狀態

- 組字區內容**保持不變**，不清空
- 在組字區上方彈出「近音表」浮動視窗
- IMEState 切換至 `.ofSimilarPhonetic`

---

## 3. 近音表 UI 規格

### 3.1 視窗標題列

```
近音表    1  2  3  4  5  6  7  8
```

- 左側：固定顯示 `近音表`
- 右側：數字 `1`–`8`，對應**當前藍底列**在當前頁的第幾個候選字

> **注意**：本實作採**逐列獨立翻頁**設計（見 3.3），非全表整頁翻頁，故標題列不顯示頁碼。

### 3.2 近音表主體（二維表格）

每一**列**代表一個注音讀音（含聲調），每一**欄**為該讀音的候選字：

**範例：輸入「波」（ㄅㄛ）**
```
近音表    1  2  3  4  5  6  7  8
ㄅㄛ [藍底]    擺 波 播 剝 玻 葡 缽 菠 >
ㄅㄛˊ          伯 博 薄 柏 泊 駁 搏 勃 >
ㄅㄛˇ          跛 簸 玻
ㄅㄛˋ          播 薄 擘 箟 毫 薛 鈐 紫 >
ㄅㄛ˙          葡 伯 膊 啵
```

**翻頁後（以 ㄅㄛˊ 列翻至第 2 頁為例）**
```
近音表    1  2  3  4  5  6  7  8
ㄅㄛ [藍底]    擺 波 播 剝 玻 葡 缽 菠 >
ㄅㄛˊ        < 亳 礴 鈸 鵓 渤 ...
ㄅㄛˇ          跛 簸 玻
...
```

- `<` 出現在注音欄右側，代表**有上一頁**（可按 `←` 返回）
- `>` 出現在第 8 欄右側，代表**有下一頁**（可按 `→` 前進）

**範例：輸入「謀」（ㄇㄡˊ）**
```
近音表    1  2  3  4  5  6  7  8
ㄇㄡˊ [藍底]  謀 牟 眸 繆 蝥 侔 蟊 喁 >
ㄇㄡ            某 冇 牡 畝 ...         >
ㄇㄡˇ          某 冇 跑 牡 畝 ...      >
ㄇㄡˋ          茂 表 貿 柵 督 戀 露 慾 >
ㄇㄡ˙          （無則省略）
ㄇㄛ            猙
ㄇㄛˊ          還
ㄇㄛˇ          某
ㄇㄛˋ          廢 嘿
ㄇㄛ˙          （無則省略）
```

**範例：輸入「苦」（ㄎㄨˇ）**
```
近音表    1  2
ㄎㄨˇ [藍底]  苦 楷
ㄎㄨ            哭 枯 窟 骷 刳 堀 掐 肽 >
ㄎㄨˋ          酷 庫 褲 ...            >
ㄍㄨ            古 骨 鼓 谷 ...        >
ㄍㄨˊ          孤 姑 菇 ...           >
...
```

### 3.3 重要 UI 細節

1. **藍底列永遠是當前字的精確注音+聲調**，固定在第一列
2. **候選字數量可為零或少量**：若某讀音只有 1–2 個字，只顯示那幾個
3. **`>` 符號**：該列候選字在當前頁後還有更多時，第 8 欄右側顯示 `>`（灰色）
4. **`<` 符號**：該列不在第 0 頁時，注音欄右側顯示 `<`（灰色）
5. **候選字為空的讀音列不顯示**：無候選字則整列省略
6. **逐列獨立翻頁**：每列有自己的 `currentPage`，翻頁只影響當前選中（藍底）列
7. **標題列的數字 1–8** 對應**藍底列當前頁**的候選字序號
8. **螢幕邊界自動翻轉**：視窗預設顯示於游標**下方**；若放置於下方會超出螢幕可見範圍（`visibleFrame.minY`），則自動翻轉至游標**上方**顯示

### 3.4 列的排列順序規則

**簡化實作**（已採用）：

```
排列順序：
1. 精確音（原始聲調）               ← 藍底，固定第一列
2. 精確音的其他聲調（1→2→3→4→˙）
3. 近音韻母組合的各聲調（1→2→3→4→˙）
4. 近音聲母組合的各聲調（1→2→3→4→˙）
```

空候選字的列整列省略（不顯示空行）。

---

## 4. 近音規則表

### 4.1 聲母近音對（白名單制）

| 聲母 A | 近音聲母 B | 說明 |
|--------|-----------|------|
| ㄓ | ㄗ | 捲舌↔平舌 |
| ㄔ | ㄘ | 捲舌↔平舌 |
| ㄕ | ㄙ | 捲舌↔平舌 |
| ㄋ | ㄌ | 鼻音混淆 |
| ㄈ | ㄏ | 唇齒音 |
| ㄎ | ㄍ | 送氣↔不送氣 |

> **未列出的聲母（ㄅㄆㄇ、ㄐㄑㄒ、ㄦ 等）無近音聲母**：白名單制，不在表中則不展開。
> **零聲母（如 ㄦ、ㄢ）無近音聲母**。

### 4.2 韻母近音對

| 韻母 A | 近音韻母 B | 說明 |
|--------|-----------|------|
| ㄣ | ㄥ | 前後鼻音 |
| ㄥ | ㄣ | 前後鼻音 |
| ㄢ | ㄤ | 前後鼻音 |
| ㄤ | ㄢ | 前後鼻音 |
| ㄧㄣ | ㄧㄥ | 前後鼻音（帶介音ㄧ） |
| ㄧㄥ | ㄧㄣ | 前後鼻音（帶介音ㄧ） |
| ㄨㄣ | ㄨㄥ | 前後鼻音（帶介音ㄨ） |
| ㄨㄥ | ㄨㄣ | 前後鼻音（帶介音ㄨ） |
| ㄡ | ㄛ | 圓唇韻母混淆 |
| ㄛ | ㄡ | 圓唇韻母混淆 |

> **注意**：無效的注音組合（如 ㄅㄡ）不會被加入結果（以 `invalidPhoneticBases` 黑名單控制）。

### 4.3 聲調展開規則

每個有效讀音組合展開全部 5 個聲調（1聲無標記、ˊ、ˇ、ˋ、˙）。有候選字才顯示，無候選字省略整列。

---

## 5. 操作方式

### 5.1 近音表開啟後的鍵盤操作

| 按鍵 | 行為 |
|------|------|
| `↑` | 藍底列上移（移至上一列） |
| `↓` | 藍底列下移（移至下一列） |
| `→` | **當前藍底列**翻至下一頁候選字（若有 `>`） |
| `←` | **當前藍底列**翻至上一頁候選字（若有 `<`） |
| `1`–`8` | 直接選取**當前藍底列當前頁**的第 N 個候選字並送出 |
| `Enter` / `Space` | 選取當前藍底列第 1 個候選字並送出 |
| `Esc` | 取消近音表，回到原始組字狀態（原字不變） |

> **翻頁為逐列獨立**：`←`/`→` 只影響目前藍底列的頁碼，其他列不受影響。

### 5.2 選字後的行為

1. 選取的近音字**取代**組字區中游標前一字
2. 近音表關閉，IMEState 回到 `.ofInputting`
3. 組字器游標維持原位（取代後的字之後）
4. 如插入新讀音失敗，組字器回退並顯示原始輸入狀態

---

## 6. 資料層規格

### 6.1 近音查詢流程

```
輸入：目前字的注音讀音 + 聲調（如 ㄘㄢ 一聲）
        ↓
Step 1：展開精確音各聲調（原聲調排第一）
        ㄘㄢ, ㄘㄢˊ, ㄘㄢˇ, ㄘㄢˋ, ㄘㄢ˙
        ↓
Step 2：依近音韻母規則展開近音韻母基底各聲調
        ㄘㄤ, ㄘㄤˊ, ㄘㄤˇ, ㄘㄤˋ, ㄘㄤ˙
        ↓
Step 3：依近音聲母規則展開近音聲母基底各聲調
        ㄔㄢ, ㄔㄢˊ, ㄔㄢˇ, ㄔㄢˋ, ㄔㄢ˙
        ↓
Step 4：對每個讀音查詢詞庫，過濾空列，組成結果
        ↓
輸出：[SimilarPhoneticRow]，第一列為藍底列（原聲調）
```

### 6.2 候選字來源

- 來源：`vChewing_LangModelAssembly` 詞庫的 `unigramsFor(keyArray:)` 查詢
- 以注音為 key，取得對應所有漢字
- 依詞頻由高到低排列

---

## 7. 架構與實作

### 7.1 新增 IMEState

**`SimilarPhoneticRow`**（位於 `IMEStateProtocolAndData.swift`）：

```swift
public struct SimilarPhoneticRow: Equatable {
  public let phonetic: String        // 注音讀音（含聲調，如 "ㄘㄢ"）
  public let candidates: [String]    // 候選字列表（依詞頻排序）
  public var currentPage: Int        // 目前頁碼（0-indexed）
  public static let pageSize = 8
  public var totalPages: Int
  public var candidatesOnCurrentPage: [String]
  public var hasNextPage: Bool
}
```

**`IMEState.ofSimilarPhonetic` factory**：

```swift
static func ofSimilarPhonetic(
  rows: [SimilarPhoneticRow],
  selectedRow: Int,
  displayTextSegments: [String],
  cursor: Int
) -> IMEState
```

### 7.2 新增 / 修改檔案

#### 新增檔案

| 檔案路徑 | 用途 |
|----------|------|
| `…/Typewriter/SimilarPhonetic/SimilarPhoneticRules.swift` | 近音規則：聲母對、韻母對、splitTone、allReadings |
| `…/Typewriter/SimilarPhonetic/SimilarPhoneticHandler.swift` | `buildRows(for:lm:)` 建立近音表列陣列 |
| `…/Typewriter/InputHandler/InputHandler_HandleSimilarPhonetic.swift` | ↑ 鍵觸發、列導航、翻頁、候選字取代 |
| `…/MainAssembly4Darwin/SimilarPhonetic/SimilarPhoneticUI.swift` | AppKit 浮動視窗，CoreText 繪製二維表格 |
| `…/TypewriterTests/SimilarPhoneticTests.swift` | SimilarPhoneticRules + Handler 單元測試 |

#### 修改檔案

| 檔案路徑 | 變更說明 |
|----------|---------|
| `Shared.swift` | 新增 `case ofSimilarPhonetic` 至 `StateType` |
| `IMEStateProtocolAndData.swift` | 新增 `SimilarPhoneticRow`、state fields、factory |
| `SessionUIProtocol.swift` | 新增 `SimilarPhoneticUIProtocol`（`show` 參數為 `CGRect` 以支援邊界翻轉）、`similarPhoneticUI` property |
| `IMEState.swift` | 實作 `ofSimilarPhonetic` constructor |
| `SessionUI.swift` | 加入 `similarPhoneticUI` 實例 |
| `InputSession_HandleStates.swift` | `.ofSimilarPhonetic` 加入 `switchState` 與 display 邏輯 |
| `InputHandler_TriageInput.swift` | 路由 `.ofSimilarPhonetic`、攔截 ↑ 鍵觸發 |
| `MockedInputHandlerAndStates.swift` | 測試用 `MockIMEState` 補上 `ofSimilarPhonetic` |

### 7.3 取代流程（`applyNearPhoneticReplacement`）

```
1. dropKey(direction: .rear)          ← 移除游標前一字讀音
2. assembler.insertKey(newPhonetic)   ← 插入新讀音
3. assemble()                         ← 重新組字
4. assembler.overrideCandidate(...)   ← 強制指定節點值（withSpecified）
5. assemble()                         ← 再次組字
6. session.switchState(ofInputting)   ← 回到輸入狀態
```

---

## 8. 測試案例

### 規則測試（`SimilarPhoneticRulesTests`）

| 測試 | 輸入 | 預期輸出 |
|------|------|---------|
| splitTone 一聲 | `"ㄘㄢ"` | base=`"ㄘㄢ"`, tone=`""` |
| splitTone 二聲 | `"ㄇㄡˊ"` | base=`"ㄇㄡ"`, tone=`"ˊ"` |
| allReadings | `"ㄘㄢ"` | 5 個，`"ㄘㄢ"` 排第一 |
| nearVowelBase ㄡ↔ㄛ | `"ㄇㄡ"` | `"ㄇㄛ"` |
| nearVowelBase ㄨㄣ↔ㄨㄥ | `"ㄙㄨㄣ"` | `"ㄙㄨㄥ"` |
| nearVowelBase 無效組合 | `"ㄅㄛ"` | `nil` |
| nearConsonantBase ㄘ↔ㄔ | `"ㄘㄢ"` | `"ㄔㄢ"` |
| nearConsonantBase ㄙ↔ㄕ | `"ㄙㄨㄣ"` | `"ㄕㄨㄣ"` |
| nearConsonantBase 零聲母 | `"ㄦ"` | `nil` |

### 邏輯測試（`SimilarPhoneticHandlerTests`）

| 測試 | 輸入 | 關鍵驗證 |
|------|------|---------|
| ㄅㄛ（無近音） | `"ㄅㄛ"` | 第一列 `"ㄅㄛ"`，無 ㄆ/ㄇ 列 |
| ㄇㄡˊ（近音韻母） | `"ㄇㄡˊ"` | 含 ㄇㄛ 系列 |
| ㄘㄢ（近音聲母） | `"ㄘㄢ"` | 含 ㄗㄢ 系列（ㄘ↔ㄗ） |
| 空列過濾 | 任意 | 所有列至少 1 個候選字 |

---

## 9. 不在本次範圍內（Out of Scope）

- 符號的近音/相似符號查詢
- 多字詞的近音替換（本次僅支援單字）
- 已上屏文字的近音替換（本次僅支援組字區內的字）
- 選了近音字後是否更新詞頻學習
- 偏好設定開關（目前預設永遠啟用）
