# Feature Spec: 智慧中英文切換 — Shift 鍵就地切換

> **適用專案**：ThomasHsieh/vChewing-macOS（fork 自 vChewing/vChewing-macOS）
> **目標模組**：`vChewing_Typewriter`、`vChewing_MainAssembly4Darwin`
> **功能定位**：在組字區有內容時，Shift 鍵可直接在中文模式與臨時英文模式之間切換，組字區內容全程保留不送出。
> **實作狀態**：✅ 已完成並驗證

---

## 1. 功能概述

在「智慧中英文切換」啟用時，Shift 鍵的行為依組字區狀態分兩種情境：

| 情境 | 行為 |
|------|------|
| **組字區有內容** | 就地切換臨時中英文模式，顯示 tooltip「英」或「中」，組字區不送出 |
| **組字區為空** | 維持原全域 `isASCIIMode` 切換（右上角通知照舊），並額外顯示 tooltip「英」或「中」 |

> **注意**：「智慧中英文切換」偏好設定關閉時，兩種情境均還原為原始 Shift 行為（僅全域切換，不顯示 tooltip）。

---

## 2. 組字區有內容時的 Shift 行為

### 2.1 中文模式 → 臨時英文模式

| 步驟 | 動作 | 組字區狀態 |
|------|------|-----------|
| 1 | 中文模式下輸入注音，組字區有文字 | e.g.「知道」在組字區 |
| 2 | 按下 Shift | 中文文字凍結為前綴，進入臨時英文模式 |
| 3 | 顯示 tooltip「英」（1.5 秒） | 提示已切換至英文輸入 |
| 4 | 繼續輸入英文 | 英文字元累積在英文緩衝區，顯示於凍結前綴之後 |
| 5 | 按 Enter | 「知道 + 英文」整段送出到輸入行 |

### 2.2 臨時英文模式 → 中文模式

| 步驟 | 動作 | 組字區狀態 |
|------|------|-----------|
| 1 | 英文模式下已輸入英文（e.g. "email"） | 英文緩衝區有內容 |
| 2 | 按下 Shift | 英文緩衝區內容凍結為新前綴，退出英文模式 |
| 3 | 顯示 tooltip「中」（1.5 秒） | 提示已切回中文輸入 |
| 4 | 繼續輸入注音 | 中文疊加在所有凍結前綴之後 |
| 5 | 按 Enter | 整段（含所有凍結前綴 + 中文）送出 |

### 2.3 典型使用情境

```
1. 注音輸入「知道你的」→ 組字區：「知道你的」
2. 按 Shift → tooltip「英」，組字區進入英文模式：「知道你的▏」
3. 輸入 "email" → 組字區：「知道你的email▏」
4. 按 Shift → tooltip「中」，組字區回到中文：「知道你的email▏」
5. 輸入注音「ㄇㄚ」→ 組字區：「知道你的email嗎」
6. 按 Enter → 整段「知道你的email嗎」送出
```

---

## 3. 組字區為空時的 Shift 行為（含 tooltip）

原有全域中英文切換行為完整保留：
- 切換 `isASCIIMode` 布林值
- 若偏好設定啟用，顯示右上角系統通知

新增：在「智慧中英文切換」啟用時，**額外**顯示 tooltip「英」或「中」（1.5 秒），與組字區有內容時的切換視覺回饋一致。

---

## 4. 實作細節

### 4.1 核心函式：`PhonabetTypewriter.handleShiftToggle()`

位於 `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift`

**中文 → 英文路徑**：
1. `freezeAssemblerContentIfNeeded()` — 將 assembler 顯示文字加入 `frozenSegments`
2. 儲存當前 `frozenSegments`
3. `session.switchState(State.ofAbortion())` — 清除 assembler/composer 與 smartSwitchState（與 `triggerTempEnglishMode` 一致，避免 assembler 重複顯示）
4. 重新設置 `frozenSegments`
5. `enterTempEnglishMode()` + 建構顯示狀態 + tooltip「英」

**英文 → 中文路徑**：
1. 儲存 `englishBuffer`
2. `exitTempEnglishMode()`
3. `freezeSegment(englishBuffer)` — 保留英文為凍結前綴
4. `generateStateOfInputting(guarded: true)` + tooltip「中」

### 4.2 修改的檔案

| 檔案 | 變更 |
|------|------|
| `Typewriter_Phonabet.swift` | 新增 `handleShiftToggle()` |
| `InputHandler_CoreProtocol.swift` | `InputHandlerProtocol` 新增 `handleShiftToggleForComposition()` |
| `InputHandler_HandleComposition.swift` | 實作 `handleShiftToggleForComposition()`（`public`，跨模組） |
| `InputSession_HandleEvent.swift` | Shift 偵測點：組字區有內容時優先走新路徑；空時走全域切換 + tooltip |

### 4.3 關鍵設計決策

**為何 `switchState(ofAbortion)` 是必要的？**

`freezeAssemblerContentIfNeeded()` 只將 assembler 的顯示文字複製到 `frozenSegments`，並不清除 assembler 本身。若直接進入英文模式後切回中文，`generateStateOfInputting()` 會同時顯示 `frozenSegments`（含已凍結的中文）與 assembler（仍有相同文字），造成重複。`switchState(ofAbortion)` 呼叫 `inputHandler.clear()`（含 `smartSwitchState.reset()`）完整清除狀態，再重設 `frozenSegments`，與 `triggerTempEnglishMode` 的實作模式一致。

---

## 5. 與其他切換方式的比較

| 觸發方式 | 適用情境 | 特點 |
|---------|---------|------|
| **自動觸發**（連續無效注音鍵） | 打字時自然流暢切換 | 無須手動介入 |
| **雙擊 Space**（≤ 0.3 秒） | 英文模式 → 中文 | 快速切回，英文留存凍結 |
| **Shift（新）** | 中文 ↔ 英文雙向 | 手動精確控制，即時顯示 tooltip |
| **ESC** | 英文模式 → 中文 | 丟棄英文緩衝區 |
| **Enter** | 任意模式 | 整段（凍結 + 當前輸入）送出 |
