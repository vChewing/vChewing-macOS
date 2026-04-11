# 計畫：臨時英文模式雙擊 SPACE 切回中文 + 切換確認 tooltip「中」

> **實作狀態**：✅ 已完成並測試通過（2026-04-11）

## Context

智慧中英文切換功能（`smartChineseEnglishSwitchEnabled`）在偵測到英文輸入意圖後會進入「臨時英文模式」（`isTempEnglishMode = true`）。此前從英文模式切回中文注音的方式有：ESC（丟棄）、TAB（提交）、ENTER（提交）、Backspace 邊界退出。

本計畫新增：
1. **快速連按兩次 SPACE（≤ 0.3 秒內）** → 英文內容留存為凍結前綴，切回中文注音模式
2. **切換確認 tooltip「中」** → 雙擊 SPACE 切換成功後，短暫顯示「中」（1.5 秒），確認已切回中文注音

**設計決策**（由使用者確認）：
- 英文內容**不提交到 OS**，而是保留在組字區作為凍結前綴（frozenSegment）
- 英文模式期間**不常駐** tooltip；tooltip 只在切換瞬間出現 1.5 秒
- 第一下 SPACE 先在英文緩衝區插入空格；雙擊確認後移除尾部空格再凍結

---

## 關鍵檔案

| 檔案 | 修改內容 |
|------|---------|
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift` | `SmartSwitchState` 新增 `firstSpaceTimestamp`、`recordFirstSpace()`、`tryConfirmDoubleSpace()`；`resetExceptFrozen()` 清除 `firstSpaceTimestamp` |
| `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift` | `handleTempEnglishMode()` 中 `input.isSpace` 分支改為雙擊偵測邏輯；`handleBackspaceInTempEnglishMode()` 三個分支前各加 `firstSpaceTimestamp = nil` |
| `Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift` | 新增 TC-050 ～ TC-054 |

---

## 邊界情況處理

| 情況 | 處理 |
|------|------|
| 凍結段落 + 組字器均空時雙擊 | 呼叫 `session.switchState(State.ofAbortion())` 再切到帶 tooltip 的 `ofEmpty`，避免 `ofEmpty` 誤提交前一狀態的組字內容 |
| 連按三次 SPACE | 第二下觸發雙擊並切回中文；第三下在正常中文模式走正常路徑 |
| Backspace 後再按 SPACE | Backspace 重置 `firstSpaceTimestamp`，第二個 SPACE 是乾淨的第一下 |
| 超過 0.3 秒的第二下 | `tryConfirmDoubleSpace()` 回傳 false，重設計時並插入第二個空格 |

---

## 測試結果

```
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

TC-050 ～ TC-054 全數通過；全套 221 個測試無回歸。
