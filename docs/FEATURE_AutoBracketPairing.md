# Feature Spec: 自動括號配對 (Auto Bracket Pairing)

> **適用專案**：ThomasHsieh/vChewing-macOS（fork 自 vChewing/vChewing-macOS）  
> **目標模組**：`vChewing_Typewriter`（InputHandler）、`vChewing_MainAssembly4Darwin`（SessionCtl）  
> **功能定位**：輸入左括號後自動補入對應右括號，游標停在括號內，可直接輸入內容  
> **實作狀態**：✅ Phase 1（全形，直接輸入）+ Phase 2（半形，英文緩衝區）+ Phase 3（候選窗確認）均已完成

---

## 1. 功能概述

自動括號配對（Auto Bracket Pairing）讓使用者輸入左括號時，系統自動在後方插入對應的右括號，並將游標定位在兩個括號之間，使用者可以直接輸入括號內的內容，不需要手動移動游標。

此功能分為三個作用範圍：
- **全形括號**：在中文組字區內有效，適用所有中文括號符號（直接鍵盤輸入時觸發）
- **半形括號**：僅在**智慧中英文模式的英文緩衝區內**有效，其他情況（純英文應用程式直接輸入）vChewing 無法攔截
- **候選窗確認**：透過候選窗（含符號選單）確認單一全形左括號字元時，同樣觸發自動配對

**典型使用情境**：
- 輸入 `『` → 組字區自動變成 `『|』`（`|` 代表游標位置）
- 輸入 `《` → 組字區自動變成 `《|》`
- 輸入 `【` → 組字區自動變成 `【|】`
- 智慧中英文模式下輸入 `(` → 英文緩衝區自動變成 `(|)`
- 智慧中英文模式下輸入 `[` → 英文緩衝區自動變成 `[|]`
- 括號內容輸入完畢後，按 `→` 或再次輸入右括號，游標跳出括號外繼續

---

## 2. 支援的括號對照表

### 2.1 全形括號（中文組字區內有效）

| 左括號 | 右括號 | 名稱 |
|--------|--------|------|
| `『` | `』` | 單書名號（台灣用法） |
| `「` | `」` | 單引號 |
| `《` | `》` | 雙書名號 |
| `〈` | `〉` | 單角括號 |
| `【` | `】` | 方括號 |
| `〔` | `〕` | 六角括號 |
| `｛` | `｝` | 全形花括號 |
| `（` | `）` | 全形圓括號 |
| `"` | `"` | 全形雙引號 |
| `'` | `'` | 全形單引號 |

### 2.2 半形括號（**僅在智慧中英文模式的英文緩衝區內有效**）

| 左括號 | 右括號 | 名稱 | 備註 |
|--------|--------|------|------|
| `(` | `)` | 半形圓括號 | Shift+9 在中文模式輸出全形 `（`，半形只在英文緩衝區出現 |
| `[` | `]` | 半形方括號 | 大千排列下需確認按鍵無衝突 |
| `{` | `}` | 半形花括號 | 大千排列下需確認按鍵無衝突 |

> **重要限制**：半形括號的自動配對**只在智慧中英文模式啟用、且使用者正在英文緩衝區輸入時**才觸發。在純英文應用程式（如 Terminal、Xcode）中直接輸入的括號，vChewing 無法攔截，不在此功能範圍內。

---

## 3. 觸發條件

### 3.1 全形括號的觸發時機（直接輸入）

| 條件 | 說明 |
|------|------|
| 觸發事件 | 左括號字元**已確認輸出、即將插入中文組字區**的時機 |
| 組字區狀態 | 任意（可以是空的，也可以已有其他字） |
| 輸入法模式 | 中文輸入模式（不限智慧中英文是否開啟） |
| 功能開關 | `autoBracketPairingEnabled` 為 `true`（預設開啟） |

### 3.2 半形括號的觸發時機

| 條件 | 說明 |
|------|------|
| 觸發事件 | `(`、`[`、`{` 字元進入**英文緩衝區**的時機 |
| 前提條件 | 智慧中英文模式已啟用（`smartChineseEnglishInputEnabled` 為 `true`） |
| 緩衝區狀態 | 使用者正在英文緩衝區輸入（`PhonabetTypewriter` 處於英文緩衝狀態） |
| 功能開關 | `autoBracketPairingEnabled` 為 `true` |

> **Agent 實作提示**：半形括號的攔截點應在 `InputHandler_HandleSmartChineseEnglish.swift`（或對應的智慧中英文處理檔案）中，於字元加入英文緩衝區後立即判斷。

### 3.3 候選窗確認的觸發時機（Phase 3）

| 條件 | 說明 |
|------|------|
| 觸發事件 | 使用者從候選窗（含符號選單）確認單一全形左括號字元 |
| 偵測方式 | `candidatePairSelectionConfirmed(at:)` 的 `.ofCandidates` case 完成 `consolidateNode` 後，檢查 `selectedValue.value` 是否為單一全形左括號 |
| 實作方法 | `InputHandlerProtocol.handleAutoBracketPairingForCandidateValue(_:)` |
| 功能開關 | `autoBracketPairingEnabled` 為 `true` |

此觸發路徑補全了「使用者不直接鍵入括號符號鍵、而是從符號選單或候選窗選取」的場景。

### 3.4 括號的來源（全形）

vChewing 中，全形括號通常透過以下方式輸入：
- **漢音風格標點符號**：Shift + 對應鍵（如 Shift+9 → `（`）
- **符號選單**：從候選窗選取括號字元
- **直接輸入**：使用者直接輸入全形標點

攔截點應在符號**已確認輸出、即將插入組字區**的時機，而非在按鍵層面攔截，以確保相容各種輸入來源。

---

## 4. 行為規格

### 4.1 基本插入流程

```
使用者輸入左括號（如 『）
        ↓
InputHandler 偵測到組字區即將插入的字元是左括號
        ↓
插入左括號到組字區
        ↓
立即插入對應右括號到組字區（游標前方）
        ↓
游標停在左右括號之間
        ↓
使用者可直接在游標位置繼續輸入
```

**組字區變化示意**：
```
輸入前：你好
輸入 『 後：你好『|』   （| = 游標）
繼續輸入：你好『世界|』
按 → 跳出：你好『世界』|
```

### 4.2 游標跳出括號的方式

| 操作 | 行為 |
|------|------|
| `→`（右方向鍵） | 游標右移一格，跳出右括號 |
| 輸入對應右括號字元（如 `』`） | **不重複插入**右括號，而是讓游標跳過已有的右括號（Smart Overwrite） |
| `Enter` 送出 | 整段含括號的文字一併送出 |
| `Esc` | 取消整個組字區內容（vChewing 現有行為，不受此功能影響） |

### 4.3 Smart Overwrite（智慧覆蓋）

當使用者輸入的字元與游標右側的字元相同（即右括號），不插入新字元，而是讓游標向右移動一格跳過，避免出現 `『世界』』` 的重複情況。

```
組字區：你好『世界|』
使用者輸入 』
結果：你好『世界』|   （游標跳過，不重複插入）
```

### 4.4 Backspace 行為

| 情況 | 行為 |
|------|------|
| 游標在空括號內（如 `『|』`），按 Backspace | 同時刪除左右兩個括號（配對刪除） |
| 游標在有內容的括號內，按 Backspace | 只刪除游標前一字元（正常行為） |

```
組字區：你好『|』
按 Backspace
結果：你好|           （左右括號一併刪除）
```

```
組字區：你好『世界|』
按 Backspace
結果：你好『世|』     （只刪除「界」）
```

---

## 5. 邊界情況處理

| 情況 | 處理方式 |
|------|---------|
| 巢狀括號（括號內再輸入括號） | 支援，獨立處理每一對括號 |
| 輸入右括號但游標前方無對應左括號 | 正常插入右括號，不做特殊處理 |
| 組字區已達最大長度 | 不插入右括號，只插入左括號（遵守現有組字區長度限制） |
| 全選後輸入左括號 | 先清空選取內容，再套用配對邏輯（遵守現有行為） |
| 複製貼上括號字元 | **不觸發**自動配對（此功能只在即時輸入時觸發） |

---

## 6. 偏好設定

在 `UserDef` 新增，並對應更新 `PrefMgrProtocol` 與 `PrefMgr`：

| UserDef Key | 型別 | 預設值 | 說明 |
|-------------|------|--------|------|
| `autoBracketPairingEnabled` | `Bool` | `true` | 是否啟用自動括號配對 |

設定 UI 位置：偏好設定 → 行為設定 → 「自動括號配對」核取方塊（建議放在智慧中英文切換附近）。

---

## 7. 架構與實作位置

### 7.1 新增常數定義

新增一個括號對照表（建議放在獨立檔案）：

```swift
// BracketPairingRules.swift
enum BracketPairingRules {

    // 全形括號：中文組字區內有效
    static let fullWidthPairs: [(left: Character, right: Character)] = [
        ("『", "』"),
        ("「", "」"),
        ("《", "》"),
        ("〈", "〉"),
        ("【", "】"),
        ("〔", "〕"),
        ("｛", "｝"),
        ("（", "）"),
        ("\u{201C}", "\u{201D}"),  // " "
        ("\u{2018}", "\u{2019}"),  // ' '
    ]

    // 半形括號：僅在智慧中英文英文緩衝區內有效
    static let halfWidthPairs: [(left: Character, right: Character)] = [
        ("(", ")"),
        ("[", "]"),
        ("{", "}"),
    ]

    // 合併查詢表
    static let allPairs = fullWidthPairs + halfWidthPairs

    static let fullWidthLeftSet: Set<Character> = Set(fullWidthPairs.map { $0.left })
    static let halfWidthLeftSet: Set<Character> = Set(halfWidthPairs.map { $0.left })

    static let rightOf: [Character: Character] = Dictionary(
        uniqueKeysWithValues: allPairs.map { ($0.left, $0.right) }
    )
    static let isRightBracket: Set<Character> = Set(allPairs.map { $0.right })
}
```

### 7.2 新增檔案

| 檔案路徑 | 用途 |
|----------|------|
| `Packages/vChewing_Typewriter/Sources/Typewriter/AutoBracket/BracketPairingRules.swift` | 括號對照表常數定義 |
| `Packages/vChewing_Typewriter/Sources/Typewriter/AutoBracket/InputHandler_HandleAutoBracket.swift` | 自動配對邏輯、Smart Overwrite、Backspace 配對刪除、候選確認配對 |

### 7.3 整合點（InputHandler — 直接輸入）

**全形括號**：在符號確認插入中文組字區後加入配對判斷：

```swift
func handleAutoBracketPairing(insertedChar: Character, inEnglishBuffer: Bool = false) -> Bool {
    guard PrefMgr.shared.autoBracketPairingEnabled else { return false }

    // 全形括號：在中文組字區觸發
    if !inEnglishBuffer && BracketPairingRules.fullWidthLeftSet.contains(insertedChar) {
        guard let right = BracketPairingRules.rightOf[insertedChar] else { return false }
        compositor.insertCharAtCursor(String(right), moveCursor: false)
        return true
    }

    // 半形括號：僅在英文緩衝區觸發
    if inEnglishBuffer && BracketPairingRules.halfWidthLeftSet.contains(insertedChar) {
        guard let right = BracketPairingRules.rightOf[insertedChar] else { return false }
        // 在英文緩衝區的游標位置插入右括號（不移動游標）
        englishBuffer.insertAtCursor(String(right), moveCursor: false)
        return true
    }

    return false
}
```

**半形括號**：在智慧中英文處理檔案（`InputHandler_HandleSmartChineseEnglish.swift`）中，於字元加入英文緩衝區後呼叫：

```swift
// 在英文緩衝區加入字元後
englishBuffer.append(char)
handleAutoBracketPairing(insertedChar: char, inEnglishBuffer: true)
```

**Backspace 配對刪除**（全形與半形通用）：

```swift
func handleBracketBackspace(inEnglishBuffer: Bool = false) -> Bool {
    guard PrefMgr.shared.autoBracketPairingEnabled else { return false }
    let charBefore = inEnglishBuffer
        ? englishBuffer.charBeforeCursor
        : compositor.charBeforeCursor
    let charAfter = inEnglishBuffer
        ? englishBuffer.charAfterCursor
        : compositor.charAfterCursor
    guard let left = charBefore,
          let expectedRight = BracketPairingRules.rightOf[left],
          charAfter == expectedRight else { return false }
    if inEnglishBuffer {
        englishBuffer.deleteCharBeforeCursor()
        englishBuffer.deleteCharAfterCursor()
    } else {
        compositor.deleteCharBeforeCursor()
        compositor.deleteCharAfterCursor()
    }
    return true
}
```

**Smart Overwrite**（全形與半形通用）：

```swift
func handleSmartOverwrite(inputChar: Character, inEnglishBuffer: Bool = false) -> Bool {
    guard PrefMgr.shared.autoBracketPairingEnabled else { return false }
    let charAfter = inEnglishBuffer
        ? englishBuffer.charAfterCursor
        : compositor.charAfterCursor
    guard charAfter == inputChar,
          BracketPairingRules.isRightBracket.contains(inputChar) else { return false }
    if inEnglishBuffer {
        englishBuffer.moveCursorRight()
    } else {
        compositor.moveCursorRight()
    }
    return true
}
```

### 7.4 整合點（InputHandler_TriageInput）

在 `handleInput()` 中的適當位置加入呼叫：

```swift
// 1. Backspace 時優先判斷配對刪除
if event.isBackspace {
    if handleBracketBackspace() { return .absorbed }
    // ... 原有 Backspace 邏輯
}

// 2. 一般字元輸入時，先判斷 Smart Overwrite
if let char = event.inputChar {
    if handleSmartOverwrite(inputChar: char) { return .absorbed }
    // ... 原有輸入邏輯
}

// 3. 符號插入後，呼叫自動配對
// （在符號確認輸出至組字區後）
handleAutoBracketPairing(insertedChar: insertedChar)
```

### 7.5 平台閘控

所有新檔案以 `#if canImport(Darwin)` 閘控。

---

## 8. 實作注意事項

### 8.1 組字區游標位置的實作

vChewing 的組字區（compositor）游標操作需使用現有 API，agent 需確認以下操作在現有架構中的對應方法：
- 在游標位置插入字元但**不移動游標**（插入後游標仍在插入點左側）
- 讀取游標前/後一字元
- 向右移動游標一格

若現有 compositor API 不支援「插入不移動游標」，可改用：插入右括號後立即呼叫 `moveCursorLeft()` 退回一格。

### 8.2 與現有標點輸入的相容性

vChewing 已有「漢音風格標點符號」功能（Shift + 數字/符號鍵輸出全形標點）。自動括號配對應**在此機制之後**介入，即：先讓漢音標點邏輯決定輸出哪個字元，再由自動配對邏輯判斷是否補入右括號。

### 8.3 與智慧中英文切換的相容性

若使用者在智慧中英文模式下輸入括號，自動配對邏輯應仍然生效（因為括號是從中文符號層輸出的）。

### 8.4 候選確認的整合點（Phase 3）

候選確認走 `candidatePairSelectionConfirmed(at:)` → `consolidateNode` 流程，不經過 `handlePunctuation`，因此需要獨立整合點。在兩處實作中加入：

```swift
// Production 端（InputSession_Delegates.swift）& Mock 端（MockedInputHandlerAndStates.swift）
// 在 consolidateNode(...) 之後、generateStateOfInputting() 之前：
inputHandler.handleAutoBracketPairingForCandidateValue(selectedValue.value)
```

`handleAutoBracketPairingForCandidateValue(_:)` 是一個 `public` 方法，直接接受已知 value 字串，不需再透過 LM key 查詢，實作位於 `InputHandler_HandleAutoBracket.swift`。

---

## 9. 測試案例

### 基本配對

| 操作 | 預期組字區 | 游標位置 |
|------|-----------|---------|
| 輸入 `『` | `『』` | `『` 後、`』` 前 |
| 繼續輸入「你好」 | `『你好』` | `好` 後、`』` 前 |
| 按 `→` | `『你好』` | `』` 後 |

### Smart Overwrite

| 操作 | 預期組字區 | 游標位置 |
|------|-----------|---------|
| 組字區為 `『你好|』`，輸入 `』` | `『你好』` | `』` 後（無重複） |

### 配對刪除

| 操作 | 預期組字區 | 游標位置 |
|------|-----------|---------|
| 組字區為 `『|』`，按 Backspace | `` | 原位 |
| 組字區為 `『你好|』`，按 Backspace | `『你|』` | `你` 後 |

### 巢狀括號

| 操作 | 預期組字區 |
|------|-----------|
| 輸入 `『`，再輸入 `《` | `『《|》』` |
| 在內層輸入「三體」 | `『《三體|》』` |
| 按 `→` 跳出內層 | `『《三體》|』` |
| 再按 `→` 跳出外層 | `『《三體》』|` |

### 半形括號（智慧中英文英文緩衝區）

| 操作 | 前提 | 預期英文緩衝區 | 游標位置 |
|------|------|--------------|---------|
| 輸入 `(` | 智慧中英文模式開啟，英文緩衝區作用中 | `()` | `(` 後、`)` 前 |
| 繼續輸入 `hello` | 同上 | `(hello)` | `o` 後、`)` 前 |
| 輸入 `)` | 游標在 `(hello|)` | `(hello)` | `)` 後（Smart Overwrite） |
| 輸入 `[` | 英文緩衝區作用中 | `[]` | `[` 後、`]` 前 |
| 輸入 `{` | 英文緩衝區作用中 | `{}` | `{` 後、`}` 前 |
| 空括號 `(|)` 按 Backspace | 英文緩衝區作用中 | `` | 原位（配對刪除） |

### 智慧中英文模式關閉時的半形括號

| 操作 | 預期行為 |
|------|---------|
| 關閉智慧中英文，輸入 `(` | 正常輸出 `(`，不自動補 `)` |

### 候選窗確認觸發配對（Phase 3 — TC-AB-041）

| 操作 | 前提 | 預期結果 |
|------|------|---------|
| 從候選窗選取 `｛` | `autoBracketPairingEnabled` 開啟 | 組字區為 `｛｝`，游標在兩括號之間 |
| 從候選窗選取 `（` | `autoBracketPairingEnabled` 開啟 | 組字區為 `（）`，游標在兩括號之間 |
| 從候選窗選取 `【` | `autoBracketPairingEnabled` 開啟 | 組字區為 `【】`，游標在兩括號之間 |
| 從候選窗選取 `｛` | `autoBracketPairingEnabled` 關閉 | 只插入 `｛`，不補右括號 |
| 從候選窗選取非括號字元（如 `你`） | 任意 | 正常插入，不觸發配對 |

---

## 10. 不在本次範圍內（Out of Scope）

- 純英文應用程式（Terminal、Xcode 等）直接輸入的半形括號（vChewing 無法攔截）
- 智慧中英文模式未開啟時的半形括號自動配對
- 已上屏文字的括號補全
- 跨段落的括號配對
- Markdown 格式括號（`*` `**` `_` 等）

---

## 11. Commit 訊息格式參考

```
Typewriter // AutoBracket: Add BracketPairingRules with full-width and half-width pairs.
Typewriter // AutoBracket: Implement auto-pairing for full-width brackets in compositor.
Typewriter // AutoBracket: Implement auto-pairing for half-width brackets in English buffer.
Typewriter // AutoBracket: Add Smart Overwrite for right bracket input.
Typewriter // AutoBracket: Add paired deletion on Backspace in empty brackets.
Typewriter // AutoBracket: Trigger bracket pairing on candidate confirmation.
LangModelAssembly // PrefMgr: Add autoBracketPairingEnabled preference key.
```
