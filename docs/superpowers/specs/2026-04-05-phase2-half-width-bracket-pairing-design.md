# Design: Phase 2 — 半形括號自動配對 (Half-Width Auto Bracket Pairing)

**日期**：2026-04-05  
**適用專案**：vChewing-macOS  
**功能定位**：在智慧中英文模式的臨時英文緩衝區（temp English mode）內，輸入半形左括號時自動補入對應右括號，游標定位在兩括號之間。  
**前提**：Phase 1（全形括號 in compositor）已完成並 commit（`52df8912`）。

---

## 1. 範圍

| 支援 | 不支援 |
|------|--------|
| `(` → `(|)` in 英文緩衝區 | 純英文應用（Terminal、Xcode）的半形括號 |
| `[` → `[|]` in 英文緩衝區 | 智慧中英文模式關閉時的半形括號 |
| `{` → `{|}` in 英文緩衝區 | 已上屏文字的括號補全 |
| Smart Overwrite（游標前有 `)` 時，輸入 `)` 跳過） | |
| Paired Backspace（空括號 `(|)` 同時刪除兩側） | |
| 巢狀括號（如 `([|])`）| |

**觸發前提**（AND 關係）：
1. `autoBracketPairingEnabled == true`
2. `smartChineseEnglishSwitchEnabled == true`
3. `smartSwitchState.isTempEnglishMode == true`

---

## 2. 架構變更

### 2.1 SmartSwitchState 游標擴充

**檔案**：`Packages/vChewing_Shared/Sources/Shared/Protocols/` 中的 `InputHandler_CoreProtocol.swift`（`SmartSwitchState` 類別）

新增欄位與方法：

```swift
// 新增
var englishBufferCursor: Int = 0

// 游標感知插入（取代原本的 append）
// appendEnglishChar(_ char: String) → 改為在 cursor 位置插入，cursor += char.count
func appendEnglishChar(_ char: String)  // 修改既有方法

// 新增：插入但不移動游標（供右括號自動補入）
func insertEnglishAtCursor(_ char: String, moveCursor: Bool)

// 新增：游標右移一格（Smart Overwrite）
func moveEnglishCursorRight()

// 修改：游標感知刪除（取代 deleteLastEnglishChar）
func deleteEnglishCharBeforeCursor()  // 刪除 cursor-1 位置的字元，cursor -= 1

// 新增：刪除游標後一字元（配對刪除右括號用）
func deleteEnglishCharAfterCursor()

// 新增 computed properties（唯讀）
var englishCharBeforeCursor: Character?  // cursor > 0 時的前一字元
var englishCharAfterCursor: Character?   // cursor < buffer.count 時的後一字元
```

重置點（`resetExceptFrozen`、`enterTempEnglishMode`、`exitTempEnglishMode` 中加入 `englishBufferCursor = 0`）。

**向後相容**：`appendEnglishChar` 改為游標插入後，所有現有呼叫點（入場時游標在末端）行為不變。`deleteLastEnglishChar` 由 `deleteEnglishCharBeforeCursor` 取代，呼叫端一併更新。

### 2.2 括號邏輯擴充

**檔案**：`Packages/vChewing_Typewriter/Sources/Typewriter/AutoBracket/InputHandler_HandleAutoBracket.swift`

在 `extension InputHandlerProtocol` 中新增三個半形方法：

```swift
/// 半形左括號確認插入英文緩衝區後，自動補入右括號，游標留在兩括號之間。
/// 應在 appendEnglishChar(char) 成功後呼叫。
@discardableResult
func handleHalfWidthAutoBracketPairing(insertedChar: Character) -> Bool

/// 輸入半形右括號時，若游標右側已有相同右括號，游標跳過（不重複插入）。
/// 應在 appendEnglishChar(char) 之前呼叫；若回傳 true，跳過 append。
@discardableResult
func handleHalfWidthSmartOverwrite(inputChar: Character) -> Bool

/// 游標位於空半形括號內時，Backspace 同時刪除兩側括號。
/// 應在 handleBackspaceInTempEnglishMode 最前方呼叫；若回傳 true，直接更新 State。
@discardableResult
func handleHalfWidthBracketBackspace() -> Bool
```

### 2.3 Typewriter_Phonabet.swift 整合點

**檔案**：`Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift`

修改 4 處：

#### 處 1：ASCII 字元輸入（行 ~651–665）

```
原流程：
  appendEnglishChar(char) → build State (cursor = combinedDisplay.count)

新流程：
  1. if isHalfWidthRightBracket(char) && handleHalfWidthSmartOverwrite(char):
       build State (cursor = frozen.count + englishBufferCursor) → return true
  2. appendEnglishChar(char)
  3. handleHalfWidthAutoBracketPairing(char)  // 僅左括號觸發，其他字元無副作用
  4. build State (cursor = frozen.count + englishBufferCursor)
```

#### 處 2：空白鍵輸入（行 ~634–645）

```
State cursor 改為 frozen.count + englishBufferCursor
（空白鍵本身不觸發括號邏輯）
```

#### 處 3：Backspace 處理（handleBackspaceInTempEnglishMode，行 ~691–725）

```
原流程：
  if buffer.isEmpty → exit mode
  else deleteLastEnglishChar() → build State

新流程：
  1. if handleHalfWidthBracketBackspace():
       build State (cursor = frozen.count + englishBufferCursor) → return true
  2. if englishBufferCursor == 0:
       // 游標在最左端，無字元可刪 → 退出 temp English mode
       clearEnglishBuffer() → exit mode（與原 buffer.isEmpty 行為一致）
  3. deleteEnglishCharBeforeCursor()
  4. if buffer.isEmpty && frozen.isEmpty → Abortion
  5. else build State (cursor = frozen.count + englishBufferCursor)
```

#### 處 4：路徑 D 入場 / SmartSwitch 觸發入場（行 ~222–226、~861–865）

```
State cursor 改為 frozen.count + englishBufferCursor
（入場時游標在末端，值相同，改為使用 cursor 屬性保持一致）
```

---

## 3. 測試設計

**檔案**：`Packages/vChewing_Typewriter/Tests/TypewriterTests/AutoBracketTests.swift`（擴充既有檔案）

新增 Suite `HalfWidthAutoBracketTests`，9 個測試：

| TC | 情境 | 驗證重點 |
|----|------|---------|
| TC-AB-030 | `autoBracketPairingEnabled = false` | 不觸發 |
| TC-AB-031 | `smartChineseEnglishSwitchEnabled = false` | 不觸發 |
| TC-AB-032 | 輸入 `(` → `handleHalfWidthAutoBracketPairing` | buffer = `()`，cursor = 1 |
| TC-AB-033 | 輸入 `[` → `handleHalfWidthAutoBracketPairing` | buffer = `[]`，cursor = 1 |
| TC-AB-034 | 輸入非括號字元 `a` | 不觸發，buffer = `a`，cursor = 1 |
| TC-AB-035 | Smart Overwrite：buffer `()`，cursor 1，輸入 `)` | cursor = 2，buffer 不變 |
| TC-AB-036 | Smart Overwrite 不觸發（isTempEnglishMode = false） | 不觸發 |
| TC-AB-037 | Paired Backspace：buffer `()`，cursor 1 | buffer = ``，cursor = 0 |
| TC-AB-038 | Backspace 不觸發配對刪除：buffer `(hi)`，cursor 3 | buffer = `(h)`，cursor = 2 |

測試透過直接操作 `SmartSwitchState` 和呼叫 `InputHandlerProtocol` 方法驗證，不需要完整 IMK session。

---

## 4. 邊界情況

| 情況 | 處理方式 |
|------|---------|
| 巢狀括號（如 `([|])`） | 各自獨立處理，不衝突 |
| 游標在 position 0 時按 Backspace | 退出 temp English mode，buffer 清空 |
| 輸入右括號但游標前無對應左括號 | 正常 append，不觸發 Smart Overwrite |
| `autoBracketPairingEnabled` 動態切換 | 每次方法呼叫時即時檢查，不需額外狀態 |

---

## 5. 不在本次範圍內

- 方向鍵在英文緩衝區內移動游標（`←`/`→` 導覽）
- 英文緩衝區的選取（Shift + 方向鍵）
- 複製貼上觸發括號配對
