# 智慧中英文切換功能設計規格

> **功能名稱：** Smart Chinese-English Switching（智慧中英文切換）
> **設計日期：** 2026-03-28
> **參考來源：** 自然輸入法智慧中英切換功能

---

## 1. 功能概述

智慧中英文切換是一個優化中文輸入體驗的功能。當使用者在中文模式下輸入時，如果連續輸入的按鍵無法組成有效的注音，系統會自動判斷使用者可能想要輸入英文，並臨時切換為英文模式。這樣使用者就不需要手動按 Shift 或 Caps Lock 來切換中英文。

### 1.1 核心概念

- **自動預測**：根據輸入的按鍵序列判斷是否為英文
- **臨時切換**：切換為英文模式是暫時性的，不影響原本的中文模式狀態
- **無縫切換**：回到中文模式不需要額外按鍵，輸入特定按鍵即可自動返回

---

## 2. 使用者故事與使用情境

### 情境 1：輸入中英混合句子

```
使用前：
你用过这个ㄇㄞㄌ（發現打錯了，按 Shift，輸入 mail，再按 Shift）嗎？

使用後：
你用过这个mail嗎？（無需按 Shift）
```

### 情境 2：快速輸入英文單字

使用者在中文模式下直接輸入 "app"，系統自動判斷為英文並輸出。

### 情境 3：大寫開頭的英文（如 "App"）

使用者先按 `Shift+A`（系統直接輸出大寫 "A"，輸入法不攔截），接著輸入 "pp"，系統偵測到 vowel 覆蓋 vowel（路徑 B'），自動切換為英文模式並輸出 "pp"，最終輸出 "App"。

### 情境 4：誤觸發處理

使用者不小心按錯鍵觸發了英文模式，連按 Backspace 可逐字刪除英文緩衝內容；清空後再按一次 Backspace 即返回中文模式。

---

## 3. 需求規格

### 3.1 功能需求

| 需求 ID | 描述 | 優先級 | 狀態 |
|---------|------|--------|------|
| REQ-001 | 支援標準大千排列（其他排列待後續擴展） | P0 | 已實作 |
| REQ-002 | 偵測英文輸入意圖（多條觸發路徑 A/B/B'/C/C'/D） | P0 | 已實作 |
| REQ-003 | 空白鍵返回中文模式 | P0 | 已實作 |
| REQ-004 | Tab 鍵返回中文模式 | P0 | 已實作 |
| REQ-005 | Backspace 逐字刪除英文緩衝，清空後返回中文模式 | P0 | 已實作 |
| REQ-006 | 輸入標點符號自動返回中文模式 | P0 | 已實作 |
| REQ-007 | 設定開關控制功能啟用/停用 | P0 | 已實作 |
| REQ-008 | 設定項位於「輸入設定」頁面 | P0 | 已實作 |
| REQ-009 | Enter 鍵在臨時英文模式下提交英文緩衝並消耗 Enter（不穿透給應用程式） | P0 | 已實作 |

### 3.2 觸發條件

**觸發臨時英文模式（六條觸發路徑）：**

| 路徑 | 名稱 | 條件 | 行為 |
|------|------|------|------|
| A | 無效鍵（排列限定） | 按鍵在當前排列中無對應注音（如倚天的 q/x） | 立即進入英文緩衝模式 |
| B | Consonant 覆蓋 | consonant slot 非空，且被另一個聲母覆蓋 | 立即進入英文緩衝模式 |
| B' | Vowel 覆蓋 Vowel | vowel slot 非空，且新按鍵又被解讀為 vowel（consonant slot 未改變） | 立即進入英文緩衝模式 |
| C | Semivowel 後接 Consonant | semivowel slot 非空且 consonant slot 空，接收後 consonant 變非空 | 立即進入英文緩衝模式 |
| C' | Vowel 後接 Consonant | vowel slot 非空（韻母在前）且 consonant slot 空，接收後 consonant 變非空 | 立即進入英文緩衝模式 |
| D | 讀音無效 | 組字時 `hasUnigramsFor` 回傳 false，且 keySequence 非空 | 直接 commit keySequence 為英文（不進入緩衝模式） |

**注意：** 目前實作**僅支援標準大千排列**。大千排列中所有 26 個字母均有有效映射，故路徑 A 永遠不觸發。

**返回中文模式：**
- 按下空白鍵（同時送出英文緩衝）
- 按下 Tab 鍵（同時送出英文緩衝）
- 按下 Enter 鍵（同時送出英文緩衝；Enter 本身被消耗，不穿透給應用程式）
- 按下 Backspace 逐字刪除英文緩衝，清空後再按一次返回中文模式
- 輸入標點符號（,.?! 等，同時送出英文緩衝）

### 3.3 觸發路徑詳述

**路徑 B 範例（test → 英文）：**
- 打 `t`（ㄔ 聲母）→ consonant slot = ㄔ，keySequence = "t"
- 打 `e`（ㄍ 聲母）→ ㄍ 覆蓋 ㄔ，consonantBefore ≠ consonantAfter → 路徑 B 觸發
- 進入英文緩衝 "te"

**路徑 B' 範例（app → 英文，有聲母）：**
- 打 `a`（ㄇ 聲母）→ consonant slot = ㄇ，keySequence = "a"
- 打 `p`（大千動態：consonant 存在時 → ㄡ 韻母）→ vowel slot = ㄡ，keySequence = "ap"
- 打第二個 `p`（vowel slot 已有 ㄡ，再次 vowel）→ vowelBefore 非空且 consonant 未改變 → 路徑 B' 觸發
- 進入英文緩衝 "app"

**路徑 B' 範例（pp → 英文，無聲母；對應 "App" 場景）：**
- `Shift+A` → 系統直接輸出 `A`，IME 不攔截，composer 保持為空
- 打 `p`（大千靜態：無聲母時 → ㄣ 韻母）→ vowel slot = ㄣ，keySequence = "p"
- 打第二個 `p`（vowel slot 已有 ㄣ，再次 vowel）→ 路徑 B' 觸發
- 進入英文緩衝 "pp"（最終輸出 "App"）

**路徑 C' 範例（is → 英文，非「の」）：**
- 打 `i`（ㄛ 韻母）→ vowel slot = ㄛ，keySequence = "i"
- 打 `s`（ㄋ 聲母）→ vowel 後接 consonant → 路徑 C' 觸發
- 進入英文緩衝 "is"（不會誤組為 ㄋㄛ → の）

**路徑 D 範例（to → commit 英文）：**
- 打 `t`（ㄔ 聲母）→ keySequence = "t"
- 打 `o`（ㄟ 韻母）→ keySequence = "to"（路徑 B/B'/C/C' 未觸發）
- 打 `space` → ㄔㄟ 在語彙庫無效，路徑 D 觸發，直接 commit "to"

---

## 4. 技術設計

### 4.1 架構概覽

```
┌─────────────────────────────────────────────┐
│               InputHandler                  │
│                   │                         │
│         ┌─────────┴─────────┐               │
│         ▼                   ▼               │
│  ┌─────────────┐    ┌─────────────────┐    │
│  │  Phonabet   │───▶│ SmartSwitch     │    │
│  │ Typewriter  │    │ (Extension)     │    │
│  └─────────────┘    └─────────────────┘    │
│                              │              │
│                              ▼              │
│                    ┌──────────────────┐    │
│                    │ TempEnglishMode  │    │
│                    │ State Management │    │
│                    └──────────────────┘    │
└─────────────────────────────────────────────┘
```

### 4.2 狀態機設計

```
                    ┌──────────────────┐
                    │   Chinese Mode   │
                    │ (Normal Typing)  │
                    └────────┬─────────┘
                             │
              ┌──────────────┼──────────────────────┐
              │ Path A/B/B'  │ Path D               │ Valid key
              │ /C/C'        │ (Space on invalid    │ (normal)
              │ (Immediate)  │  reading)            ▼
              ▼              │             ┌────────────────┐
      ┌───────────────┐      │             │ Normal phonabet│
      │ TempEnglish   │      ▼             │ processing     │
      │ Buffer Mode   │  ┌───────────────┐ └────────────────┘
      └───────┬───────┘  │ Commit keys   │
              │          │ as English    │
              │          └───────────────┘
    ┌─────────┼─────────────────┐
    │ Space/  │ Backspace×2     │ Punct/Tab
    │ Tab     │                 │
    ▼         ▼                 ▼
┌─────────┐ ┌─────────┐ ┌─────────────┐
│ Commit  │ │ Clear   │ │ Commit      │
│ English │ │ Buffer  │ │ English     │
│ Return  │ │ Return  │ │ Output Punct│
│ Chinese │ │ Chinese │ │ Return      │
└─────────┘ └─────────┘ │ Chinese     │
                        └─────────────┘
```

### 4.3 核心資料結構

```swift
// SmartSwitchState（class，在 InputHandler 中作為 reference type 管理）
final class SmartSwitchState {
    /// 連續無效按鍵計數（用於路徑 A 等需要計數的情境）
    var invalidKeyCount: Int = 0

    /// 是否處於臨時英文模式
    var isTempEnglishMode: Bool = false

    /// 臨時英文模式下的輸入緩衝
    var englishBuffer: String = ""

    /// 按鍵序列記錄（從 composer 進入非空狀態的第一個鍵開始累積）
    var keySequence: String = ""

    /// 上一次按 Backspace 的時間（用於雙擊 Backspace 偵測）
    var lastBackspaceTime: Date?

    /// Backspace 連續計數
    var backspaceCount: Int = 0

    func reset() { ... }
    func enterTempEnglishMode() { ... }
    func appendEnglishChar(_ char: String) { ... }
    func deleteLastEnglishChar() { ... }
    func exitTempEnglishMode() { ... }
}
```

### 4.4 演算法流程

**主處理流程（`handle` 方法中的智慧切換邏輯）：**

```
1. 檢查功能是否啟用（prefs.smartChineseEnglishSwitchEnabled）
   └─ 若未啟用，跳過所有智慧切換邏輯

2. 若處於臨時英文模式（isTempEnglishMode）：
   ├─ 英文字母 → 加入 englishBuffer，顯示緩衝
   ├─ Space / Tab → commit englishBuffer，返回中文模式
   ├─ Enter → commit englishBuffer，返回中文模式（Enter 被消耗，不穿透）
   ├─ 標點符號 → commit englishBuffer，輸出標點，返回中文模式
   └─ Backspace：
      ├─ 距上次 Backspace ≤ 門檻 → 雙擊：清空返回中文模式
      └─ 否則 → 單擊：刪最後一個字母

3. 若處於中文模式且是字母輸入：
   a. 在 composer 接收按鍵「之前」記錄狀態：
      consonantBefore, semivowelBefore, vowelBefore, composerValueBefore
   b. 讓 composer 接收按鍵
   c. 呼叫 evaluateSmartSwitch()：
      ├─ 路徑 A：按鍵在排列中無效 → triggerTempEnglishMode
      ├─ 路徑 B：consonantBefore 非空 且 consonantAfter ≠ consonantBefore → triggerTempEnglishMode
      ├─ 路徑 B'：vowelBefore 非空 且 consonantAfter == consonantBefore 且 vowelAfter 非空
      │          → triggerTempEnglishMode
      │          （涵蓋有聲母如 "app"、及無聲母如 Shift+A 後的 "pp" 兩種情況）
      ├─ 路徑 C/C'：(semivowelBefore 或 vowelBefore) 非空 且 consonantBefore 空 且 consonantAfter 非空
      │            → triggerTempEnglishMode
      └─ 否則：追加 keySequence，繼續正常處理

4. 路徑 D（在 composeReadingIfReady 內）：
   └─ hasUnigramsFor 回傳 false 且 keySequence 非空 → 直接 ofCommitting(keySequence)
```

### 4.5 觸發條件偵測

```swift
/// 檢查按鍵是否為有效注音輸入
private func isValidPhonabetInput(_ inputText: String) -> Bool {
    // 使用 composer 的 inputValidityCheck 方法
    return handler.composer.inputValidityCheck(charStr: inputText)
}

/// 檢查是否應該觸發臨時英文模式
private func shouldTriggerTempEnglishMode(
    invalidCount: Int,
    composerIsEmpty: Bool
) -> Bool {
    // 需要連續 2 個無效按鍵且注拼槽為空
    return invalidCount >= 2 && composerIsEmpty
}

/// 檢查是否為返回中文模式的觸發鍵
private func isReturnToChineseTrigger(_ input: InputSignalProtocol) -> Bool {
    return input.isSpace ||                    // 空白
           input.isTab ||                      // Tab
           input.isPunctuation ||              // 標點符號
           (input.isBackspace && isDoubleBackspace())  // Backspace 雙擊
}
```

---

## 5. 設定選項

### 5.1 設定項規格

| 屬性 | 值 |
|------|-----|
| UserDef Key | `kSmartChineseEnglishSwitchEnabled` |
| 預設值 | `false`（預設停用） |
| 資料型別 | Bool |
| 設定頁面 | 輸入設定（Behavior） |
| 頁籤位置 | Ｂ（與聲調鍵行為同頁） |

### 5.2 設定介面文案

**標題：**「智慧中英文切換」

**描述：**「在中文模式下，當連續輸入無法組成注音的按鍵時，自動切換為臨時英文模式。輸入空白鍵、Tab 鍵、標點符號，或連按兩次 Backspace 鍵即可返回中文模式。」

---

## 6. 測試策略

### 6.1 單元測試項目

| 測試案例 | 輸入 | 預期結果 |
|---------|------|---------|
| TC-001 | 在中文模式下輸入 "ab" | 進入臨時英文模式，輸出 "ab" |
| TC-002 | 在臨時英文模式下按空白鍵 | 提交 "ab"，返回中文模式 |
| TC-003 | 在臨時英文模式下按 Tab | 提交輸入，返回中文模式 |
| TC-004 | 在臨時英文模式下連按 Backspace 兩次 | 刪除所有英文字母，返回中文模式 |
| TC-005 | 在臨時英文模式下輸入 "," | 提交輸入，輸出 ","，返回中文模式 |
| TC-006 | 輸入有效注音 "ㄉ" | 正常處理注音，不觸發英文模式 |
| TC-007 | 輸入 "ㄉa" | 正常處理 "ㄉ"，重置計數器 |
| TC-008 | 在臨時英文模式下繼續輸入字母 | 持續累積英文字母 |
| TC-009 | 功能停用時輸入 "ab" | 不觸發英文模式，正常處理 |
| TC-010 | 注拼槽有內容時輸入 "ab" | 不觸發英文模式 |
| TC-011 | 輸入 "mail" + Enter | 路徑 B（m→a 聲母覆蓋）觸發，commit "mail" |
| TC-012 | 輸入 "test" + Enter | 路徑 B（t→e 聲母覆蓋）觸發，commit "test" |
| TC-013 | Backspace 單擊（英文模式） | 刪除最後一個英文字母 |
| TC-014 | Backspace 雙擊（英文模式） | 清空緩衝，返回中文模式 |
| TC-015 | 診斷 "test" + Enter 的逐步狀態 | 各步驟 commission 正確 |
| TC-016 | 組字區有漢字時觸發英文切換 | 漢字先 commit，再進入英文模式 |
| TC-017 | 路徑 D：打 "to" + Space（ㄔㄟ 無效） | 直接 commit "to" 為英文 |
| TC-018 | 路徑 C'：打 "is"（ㄛ→ㄋ） | 進入英文模式，緩衝 "is"，不輸出「の」 |
| TC-019 | 路徑 B'：打 "app"（聲母+韻母+再次韻母） | 進入英文模式，緩衝 "app" |
| TC-020 | 路徑 B'：打 "pp"（無聲母，Shift+A 後場景） | 進入英文模式，緩衝 "pp" |
| TC-021 | 臨時英文模式下按 Enter | Enter 被消耗（回傳 true）、英文緩衝提交、退出英文模式 |

### 6.2 不同鍵盤排列測試

需要測試的鍵盤排列：
- 大千注音（標準）
- 倚天傳統
- 倚天 26 鍵
- 許氏注音
- 漢語拼音

### 6.3 邊界條件測試

- 切換應用程式時的狀態保持
- 長時間未輸入後的狀態重置
- 與其他功能的相容性（逐字選字、聲調覆寫等）

---

## 7. 實作注意事項

### 7.1 重要提醒

1. **狀態管理**：智慧切換狀態需要與 InputHandler 的生命週期同步，在適當時機重置
2. **性能考量**：無效按鍵檢測應該輕量，不影響輸入響應速度
3. **相容性**：確保與現有的聲調覆寫、逐字選字等功能不衝突
4. **錯誤處理**：當語彙庫無法匹配時，應該優雅地處理而不是崩潰

### 7.2 已知限制

1. **聲調鍵限制**：聲調鍵（3, 4, 6, 7）在標準注音排列中會被視為有效鍵，因此輸入數字時可能需要先輸入至少兩個其他無效按鍵
2. **動態排列**：某些動態鍵盤排列的無效按鍵判斷可能較複雜，需要充分測試

---

## 8. 後續優化方向

### 8.1 可能的擴展

1. **觸發門檻調整**：允許使用者設定需要幾個無效按鍵才觸發（2-4 個）
2. **英文聯想**：在臨時英文模式下提供英文單字建議
3. **智慧返回**：根據上下文自動判斷何時返回中文模式
4. **統計資訊**：記錄使用統計，幫助優化觸發邏輯

### 8.2 與其他功能的整合

- 與「自動糾正讀音組合」功能的協同作用
- 與「語音朗讀」功能的整合（在切換時提供聲音回饋）

---

## 9. 修訂記錄

| 日期 | 版本 | 修訂內容 | 作者 |
|------|------|---------|------|
| 2026-03-28 | 1.0 | 初始設計文件 | AI Assistant |
| 2026-03-29 | 1.1 | 新增路徑 B'（vowel 覆蓋 vowel）、路徑 C'（vowel 後接 consonant）；新增情境 3（App 大寫開頭）；更新需求狀態為已實作；更新測試案例至 TC-020 | AI Assistant |
| 2026-03-29 | 1.2 | 新增 REQ-009（Enter 鍵在英文模式下消耗不穿透）；補充 Enter 路徑至狀態機流程說明；新增 TC-021 | AI Assistant |

---

## 10. 參考資料

1. [自然輸入法智慧中英切換教學](https://medium.com/goingpro/%E6%95%99%E5%AD%B8-%E6%99%BA%E6%85%A7%E4%B8%AD%E8%8B%B1%E5%88%87%E6%8F%9B-%E4%B8%8D%E7%94%A8%E6%8C%89%E5%88%87%E6%8F%9B%E9%8D%B5%E5%B0%B1%E8%83%BD%E5%B9%AB%E4%BD%A0%E5%88%87%E6%8F%9B%E6%88%90%E8%8B%B1%E6%96%87-72fe6da05acf)
2. vChewing-macOS AGENTS.md
3. vChewing Typewriter 模組架構文件
