# Feature Spec: 智慧中英文切換 — 連按兩次 SPACE 切回中文

> **適用專案**：ThomasHsieh/vChewing-macOS（fork 自 vChewing/vChewing-macOS）  
> **目標模組**：`vChewing_Typewriter`（InputHandler、SmartSwitchState）  
> **功能定位**：在臨時英文模式下，快速連按兩次 SPACE 可切回中文注音輸入，英文內容留存於組字區作為凍結前綴  
> **實作狀態**：✅ 已完成（含五個新測試案例 TC-050 ～ TC-054）

---

## 1. 功能概述

智慧中英文切換（Smart Chinese-English Switch）在偵測到英文輸入意圖後，會自動進入「臨時英文模式」（`isTempEnglishMode = true`），此時鍵盤輸入會流入英文緩衝區（`englishBuffer`）而非注音組字器。

**本功能新增的切換方式**：在英文模式期間，快速連按兩次 SPACE（間隔 ≤ 0.3 秒）即可切回中文注音輸入。

### 切換行為

| 步驟 | 動作 | 組字區狀態 |
|------|------|-----------|
| 1 | 第一下 SPACE | 在英文緩衝區尾端插入空格 |
| 2 | 第二下 SPACE（≤ 0.3 秒內） | 移除剛才插入的尾部空格；英文內容凍結為前綴；退出英文模式 |
| 3 | 切換完成 | 組字區短暫顯示 tooltip「中」（1.5 秒），提示已切回中文 |
| 4 | 繼續輸入注音 | 注音疊加在凍結英文前綴之後；tooltip 自動消失 |

### 典型使用情境

```
1. 輸入注音「你有看到我發出的」→ 智慧切換觸發，進入英文模式
2. 輸入 "Email" → 英文緩衝區：「Email」
3. 第一下 SPACE → 英文緩衝區：「Email 」（含尾部空格）
4. 第二下 SPACE（≤ 0.3 秒）→ 尾部空格移除，「Email」凍結為組字區前綴，切回中文
5. 組字區顯示「你有看到我發出的Email」+ tooltip「中」
6. 繼續輸入注音「ㄇㄚ？」→ 組字區：「你有看到我發出的Email嗎？」
7. 按 ENTER → 整段文字送出到輸入行
```

**注意**：英文內容**不會**在切換時提交到 OS，而是保留在組字區作為凍結前綴，與後續中文一起在最終 ENTER 時送出。

---

## 2. 切換逾時行為

| 情況 | 行為 |
|------|------|
| 第二下 SPACE 超過 0.3 秒 | 視為新的第一下，在英文緩衝區插入第二個空格，繼續留在英文模式 |
| 連按三次 SPACE | 第二下觸發切換；第三下已在中文模式，走正常 SPACE 路徑 |
| SPACE → Backspace → SPACE | Backspace 重置計時器；第二個 SPACE 視為乾淨的第一下，不觸發切換 |

---

## 3. Tooltip 行為

- **顯示條件**：雙擊 SPACE 切換成功後才出現
- **顯示內容**：「中」（顏色：`.prompt`）
- **顯示時間**：1.5 秒後自動消失
- **常駐狀態**：英文模式期間**不會**常駐顯示 tooltip

---

## 4. 實作概覽

### 新增至 `SmartSwitchState`（`InputHandler_CoreProtocol.swift`）

```swift
public var firstSpaceTimestamp: TimeInterval?
public let doubleTapSpaceInterval: TimeInterval = 0.3

public func recordFirstSpace() { ... }
public func tryConfirmDoubleSpace() -> Bool { ... }
```

`resetExceptFrozen()` 同步清除 `firstSpaceTimestamp`，避免狀態殘留。

### 雙擊邏輯（`Typewriter_Phonabet.swift`，`handleTempEnglishMode()`）

- **第一下 SPACE**：`recordFirstSpace()` + `appendEnglishChar(" ")` → 更新組字區顯示
- **第二下 SPACE（時間內）**：`tryConfirmDoubleSpace()` 回傳 true → 移除尾部空格 → `exitTempEnglishMode()` + `freezeSegment(englishText)` → `generateStateOfInputting()` + tooltip

### Backspace 重置（`handleBackspaceInTempEnglishMode()`）

所有三個刪除分支（括號配對、邊界退出、一般刪除）執行前均設定 `firstSpaceTimestamp = nil`，防止誤觸發。

---

## 5. 測試案例

| 測試 | 描述 |
|------|------|
| TC-050 | 雙擊 SPACE 後「test」凍結為前綴，無提交（`recentCommissions.isEmpty`，`frozenDisplayText == "test"`） |
| TC-051 | 緩衝區僅含空格時雙擊 SPACE → 乾淨切換，無提交，無 crash |
| TC-052 | 超過 0.3 秒後第二下 SPACE 視為新第一下，緩衝區含兩個空格（`async throws`） |
| TC-053 | 帶凍結漢字前綴「你好」+ 英文「hi」→ 合併為 `frozenDisplayText == "你好hi"`，無提交 |
| TC-054 | SPACE → Backspace → SPACE → 仍在英文模式（計時器已被 Backspace 重置） |

---

## 6. 其他切換方式（既有功能）

| 按鍵 | 行為 |
|------|------|
| ESC | 丟棄英文緩衝區，清除組字區，回到中文 |
| TAB | 提交英文緩衝區到 OS，回到中文 |
| ENTER | 提交凍結段落 + 英文緩衝區到 OS，回到中文 |
| Backspace（游標在最左側） | 退出英文模式，英文緩衝區仍保留為凍結前綴 |
| **SPACE × 2（≤ 0.3 秒）** | **（新）** 英文留存凍結，切回中文 |
