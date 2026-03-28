# 智慧中英文切換功能實作計劃

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 vChewing 輸入法中實作智慧中英文切換功能，讓使用者在中文模式下輸入無效注音按鍵時自動切換為臨時英文模式，並可透過特定按鍵返回中文模式。

**Architecture:** 在現有的 PhonabetTypewriter 結構中新增智慧切換狀態管理，透過擴展（extension）方式加入臨時英文模式處理邏輯。使用計數器追蹤連續無效按鍵，當達到門檻時觸發模式切換。設定系統使用現有的 UserDef/PrefMgr 架構。

**Tech Stack:** Swift 5.5+, vChewing Typewriter 模組, AppKit/SwiftUI (設定介面)

---

## 檔案結構總覽

### 新增檔案
無需新增檔案，所有功能整合至現有檔案。

### 修改檔案

| 檔案路徑 | 說明 |
|---------|------|
| `Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift` | 新增設定鍵 `kSmartChineseEnglishSwitchEnabled` |
| `Packages/vChewing_Shared/Sources/Shared/PrefMgr_Core.swift` | 新增屬性 `smartChineseEnglishSwitchEnabled` |
| `Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift` | 新增協定屬性 |
| `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift` | 實作智慧切換核心邏輯 |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/Settings/SettingsCocoa/VwrSettingsPaneCocoaBehavior.swift` | 在設定頁面加入開關 |

---

## Task 1: 新增 UserDef 設定鍵

**Files:**
- Modify: `Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift`

**說明：** 在 UserDef enum 中新增 `kSmartChineseEnglishSwitchEnabled` case，定義資料型別為 bool（預設 false），並在 metaData 中提供設定介面顯示資訊。

- [ ] **Step 1: 在 UserDef enum 中加入新 case**

在 `case kFuzzyReadingEnEngEnabled` 附近加入：

```swift
case kSmartChineseEnglishSwitchEnabled = "SmartChineseEnglishSwitchEnabled"
```

- [ ] **Step 2: 在 dataType 計算屬性中加入對應處理**

找到 `case .kFuzzyReadingEnEngEnabled:` 並在其後加入：

```swift
case .kSmartChineseEnglishSwitchEnabled: return .bool(false)
```

- [ ] **Step 3: 在 metaData 計算屬性中加入對應處理**

找到 `case .kFuzzyReadingEnEngEnabled:` 的 metaData 並在其後加入：

```swift
case .kSmartChineseEnglishSwitchEnabled: return .init(
    userDef: self,
    shortTitle: "智慧中英文切換",
    description: "在中文模式下，當連續輸入無法組成注音的按鍵時，自動切換為臨時英文模式。輸入空白鍵、Tab 鍵、標點符號，或連按兩次 Backspace 鍵即可返回中文模式。"
  )
```

- [ ] **Step 4: 編譯確認無誤**

Run: `cd Packages/vChewing_Shared && swift build`
Expected: Build successful

- [ ] **Step 5: Commit**

```bash
git add Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift
git commit -m "Shared // UserDef: Add Smart Chinese-English switching preference key"
```

---

## Task 2: 新增 PrefMgrProtocol 協定屬性

**Files:**
- Modify: `Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift`

**說明：** 在協定中宣告 `smartChineseEnglishSwitchEnabled` 屬性，讓其他模組可以存取這個設定。

- [ ] **Step 1: 找到合適的位置加入協定屬性**

在協定中找到其他 Bool 屬性（如 `fuzzyReadingEnEngEnabled`）附近，加入：

```swift
var smartChineseEnglishSwitchEnabled: Bool { get set }
```

- [ ] **Step 2: 編譯確認**

Run: `cd Packages/vChewing_Shared && swift build`
Expected: Build successful (雖然還沒實作，但協定定義應該通過)

- [ ] **Step 3: Commit**

```bash
git add Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift
git commit -m "Shared // PrefMgrProtocol: Add smartChineseEnglishSwitchEnabled property"
```

---

## Task 3: 在 PrefMgr 中實作屬性

**Files:**
- Modify: `Packages/vChewing_Shared/Sources/Shared/PrefMgr_Core.swift`

**說明：** 使用 `@AppProperty` 包裝器實作 `smartChineseEnglishSwitchEnabled` 屬性。

- [ ] **Step 1: 在 Tier 2 Settings 區域加入屬性**

找到其他 Tier 2 設定（如 `fuzzyReadingEnEngEnabled`）附近，加入：

```swift
@AppProperty(userDef: .kSmartChineseEnglishSwitchEnabled)
public var smartChineseEnglishSwitchEnabled: Bool
```

建議放在 `fuzzyReadingEnEngEnabled` 屬性之後，因為它們是相關功能。

- [ ] **Step 2: 編譯確認**

Run: `cd Packages/vChewing_Shared && swift build`
Expected: Build successful

- [ ] **Step 3: 執行測試**

Run: `cd Packages/vChewing_Shared && swift test`
Expected: All tests pass

- [ ] **Step 4: Commit**

```bash
git add Packages/vChewing_Shared/Sources/Shared/PrefMgr_Core.swift
git commit -m "Shared // PrefMgr: Implement smartChineseEnglishSwitchEnabled property"
```

---

## Task 4: 在 PhonabetTypewriter 中實作智慧切換核心邏輯

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift`

**說明：** 這是最核心的任務。需要在 PhonabetTypewriter 中加入智慧切換狀態管理，並修改 `handle` 方法來處理模式切換。

### 步驟 4.1: 加入狀態結構定義

- [ ] **Step 1: 在 PhonabetTypewriter 中加入 SmartSwitchState 結構**

在 `PhonabetTypewriter` struct 定義結束後（約第 452 行，在 `IntonationKeyBehavior` enum 之後），加入：

```swift
// MARK: - SmartSwitchState

/// 智慧中英文切換的狀態追蹤
struct SmartSwitchState {
    /// 連續無效按鍵計數
    var invalidKeyCount: Int = 0
    
    /// 是否處於臨時英文模式
    var isTempEnglishMode: Bool = false
    
    /// 臨時英文模式下的輸入緩衝
    var englishBuffer: String = ""
    
    /// 上一次 Backspace 時間（用於雙擊檢測）
    var lastBackspaceTime: Date?
    
    /// Backspace 連續計數
    var backspaceCount: Int = 0
    
    /// 重置所有狀態
    mutating func reset() {
        invalidKeyCount = 0
        isTempEnglishMode = false
        englishBuffer = ""
        lastBackspaceTime = nil
        backspaceCount = 0
    }
    
    /// 重置無效計數（當收到有效注音輸入時）
    mutating func resetInvalidCount() {
        invalidKeyCount = 0
    }
    
    /// 增加無效計數
    mutating func incrementInvalidCount() {
        invalidKeyCount += 1
    }
    
    /// 進入臨時英文模式
    mutating func enterTempEnglishMode() {
        isTempEnglishMode = true
        englishBuffer = ""
        invalidKeyCount = 0
    }
    
    /// 退出臨時英文模式
    mutating func exitTempEnglishMode() -> String {
        let buffer = englishBuffer
        reset()
        return buffer
    }
    
    /// 追加英文字母
    mutating func appendEnglishChar(_ char: String) {
        englishBuffer.append(char)
    }
    
    /// 刪除最後一個英文字母
    mutating func deleteLastEnglishChar() {
        if !englishBuffer.isEmpty {
            englishBuffer.removeLast()
        }
    }
    
    /// 檢查是否達到觸發門檻
    func shouldTriggerTempEnglishMode(threshold: Int = 2) -> Bool {
        return invalidKeyCount >= threshold
    }
}
```

### 步驟 4.2: 修改 PhonabetTypewriter 結構

- [ ] **Step 2: 在 PhonabetTypewriter 中加入狀態屬性**

在 `handler` 屬性之後加入：

```swift
// MARK: Smart Switch State

/// 智慧中英文切換的狀態（非 Sendable，必須在主執行緒存取）
private var smartSwitchState = SmartSwitchState()

/// Backspace 雙擊的時間門檻（秒）
private let backspaceDoubleTapThreshold: TimeInterval = 0.3
```

### 步驟 4.3: 重構 handle 方法

- [ ] **Step 3: 在 handle 方法開頭加入智慧切換檢查**

修改現有的 `handle` 方法，在開頭加入：

```swift
public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }
    let prefs = handler.prefs
    
    // MARK: 智慧中英文切換處理
    if prefs.smartChineseEnglishSwitchEnabled {
        // 檢查是否處於臨時英文模式
        if smartSwitchState.isTempEnglishMode {
            if let result = handleTempEnglishMode(input, session: session) {
                return result
            }
        } else {
            // 檢查是否應該觸發臨時英文模式
            if let result = checkAndTriggerSmartSwitch(input, prefs: prefs) {
                return result
            }
        }
    }
    
    // 原有的 handle 方法繼續...
    // ... 保留原有程式碼 ...
}
```

### 步驟 4.4: 實作臨時英文模式處理

- [ ] **Step 4: 加入 handleTempEnglishMode 方法**

在 `PhonabetTypewriter` 中加入：

```swift
/// 處理臨時英文模式下的按鍵輸入
/// - Parameters:
///   - input: 輸入訊號
///   - session: 輸入會話
/// - Returns: 處理結果，若未處理則回傳 nil
private func handleTempEnglishMode(
    _ input: some InputSignalProtocol,
    session: Session
) -> Bool? {
    // 檢查是否為返回中文模式的觸發鍵
    if isTriggerToReturnToChinese(input) {
        return commitEnglishAndReturnToChinese(session: session)
    }
    
    // 處理 Backspace
    if input.isBackspace {
        return handleBackspaceInTempEnglishMode(input, session: session)
    }
    
    // 處理一般英文字母輸入
    if let char = input.text, char.count == 1, char.first?.isLetter == true {
        smartSwitchState.appendEnglishChar(char)
        // 更新狀態顯示
        var state = handler.generateStateOfInputting()
        state.tooltip = smartSwitchState.englishBuffer
        state.tooltipDuration = 0
        session.switchState(state)
        return true
    }
    
    // 其他按鍵直接提交並處理
    return commitEnglishAndProcess(input, session: session)
}

/// 檢查是否為返回中文模式的觸發鍵
private func isTriggerToReturnToChinese(_ input: InputSignalProtocol) -> Bool {
    return input.isSpace || input.isTab || isPunctuationKey(input)
}

/// 檢查是否為標點符號鍵
private func isPunctuationKey(_ input: InputSignalProtocol) -> Bool {
    guard let text = input.text, text.count == 1 else { return false }
    let punctuationChars = CharacterSet(charactersIn: ",.?!;:'\"[]{}()+-*/=<>@#$%^&~`|\\")
    return text.unicodeScalars.allSatisfy { punctuationChars.contains($0) }
}

/// 提交英文緩衝並返回中文模式
private func commitEnglishAndReturnToChinese(session: Session) -> Bool {
    let englishText = smartSwitchState.exitTempEnglishMode()
    
    if !englishText.isEmpty {
        // 建立提交狀態
        var state = handler.generateStateOfInputting()
        state.textToCommit = englishText
        session.switchState(state)
    }
    
    // 重置後繼續處理當前按鍵（如果是空白或標點，會被正常處理）
    return false // 讓後續邏輯繼續處理
}

/// 提交英文並處理當前按鍵
private func commitEnglishAndProcess(
    _ input: InputSignalProtocol,
    session: Session
) -> Bool {
    let englishText = smartSwitchState.exitTempEnglishMode()
    
    if !englishText.isEmpty {
        var state = handler.generateStateOfInputting()
        state.textToCommit = englishText
        session.switchState(state)
    }
    
    return false // 讓後續邏輯處理當前按鍵
}

/// 在臨時英文模式下處理 Backspace
private func handleBackspaceInTempEnglishMode(
    _ input: InputSignalProtocol,
    session: Session
) -> Bool {
    let now = Date()
    let timeDiff = now.timeIntervalSince(smartSwitchState.lastBackspaceTime ?? Date.distantPast)
    
    if timeDiff <= backspaceDoubleTapThreshold {
        // 雙擊 Backspace：刪除所有並返回中文模式
        smartSwitchState.reset()
        var state = handler.generateStateOfInputting()
        state.tooltip = "已返回中文模式".i18n
        state.tooltipDuration = 1
        session.switchState(state)
        return true
    } else {
        // 單擊 Backspace：刪除最後一個字母
        smartSwitchState.deleteLastEnglishChar()
        smartSwitchState.lastBackspaceTime = now
        smartSwitchState.backspaceCount = 1
        
        var state = handler.generateStateOfInputting()
        if smartSwitchState.englishBuffer.isEmpty {
            // 如果已經刪完，返回中文模式
            smartSwitchState.reset()
            state.tooltip = "已返回中文模式".i18n
            state.tooltipDuration = 1
        } else {
            state.tooltip = smartSwitchState.englishBuffer
            state.tooltipDuration = 0
        }
        session.switchState(state)
        return true
    }
}
```

### 步驟 4.5: 實作觸發檢查

- [ ] **Step 5: 加入 checkAndTriggerSmartSwitch 方法**

在 `PhonabetTypewriter` 中加入：

```swift
/// 檢查並觸發智慧中英文切換
/// - Parameters:
///   - input: 輸入訊號
///   - prefs: 偏好設定
/// - Returns: 若已處理則回傳 Bool，否則回傳 nil
private func checkAndTriggerSmartSwitch(
    _ input: some InputSignalProtocol,
    prefs: some PrefMgrProtocol
) -> Bool? {
    // 忽略特殊按鍵
    if input.isReservedKey || input.isNumericPadKey || input.isNonLaptopFunctionKey
        || input.isControlHold || input.isOptionHold || input.isCommandHold {
        return nil
    }
    
    // 忽略 Shift 組合（除非是單純的 Shift+字母）
    if input.isShiftHold && !input.isOptionHold && !input.isControlHold && !input.isCommandHold {
        // Shift+字母可能是大寫輸入，暫時忽略，讓後續邏輯處理
        return nil
    }
    
    // 取得輸入文字
    guard let inputText = input.text?.lowercased(),
          inputText.count == 1 else {
        // 多字元輸入不處理
        return nil
    }
    
    // 檢查是否為字母
    guard inputText.first?.isLetter == true else {
        // 非字母按鍵重置計數器
        smartSwitchState.resetInvalidCount()
        return nil
    }
    
    // 檢查是否為有效注音輸入
    let isValidPhonabet = handler.composer.inputValidityCheck(charStr: inputText)
    
    if isValidPhonabet {
        // 有效注音：重置計數器
        smartSwitchState.resetInvalidCount()
        return nil
    } else {
        // 無效按鍵：增加計數
        smartSwitchState.incrementInvalidCount()
        
        // 檢查是否達到觸發條件
        // 條件：連續 2 個無效按鍵且注拼槽為空
        if smartSwitchState.shouldTriggerTempEnglishMode(threshold: 2) && handler.composer.isEmpty {
            // 進入臨時英文模式
            smartSwitchState.enterTempEnglishMode()
            smartSwitchState.appendEnglishChar(inputText)
            
            // 顯示狀態
            guard let session = handler.session else { return true }
            var state = handler.generateStateOfInputting()
            state.tooltip = smartSwitchState.englishBuffer
            state.tooltipDuration = 0
            session.switchState(state)
            
            return true
        }
        
        // 未達觸發條件，讓後續邏輯決定是否處理
        return nil
    }
}
```

### 步驟 4.6: 在適當時機重置狀態

- [ ] **Step 6: 在關鍵位置加入狀態重置**

需要在以下情況重置智慧切換狀態：
1. 提交文字後
2. 清除輸入時

搜尋 `handler.composer.clear()` 的位置，在適當位置加入：

```swift
// 在 composer.clear() 附近重置智慧切換狀態
smartSwitchState.reset()
```

或者在 `handle` 方法的適當位置（如處理 Esc 鍵或提交後）加入重置邏輯。

建議在 `handle` 方法最前面加入：

```swift
public func handle(_ input: some InputSignalProtocol) -> Bool? {
    guard let session = handler.session else { return nil }
    let prefs = handler.prefs
    
    // 檢查是否需要重置狀態（例如：輸入非字母按鍵時）
    if shouldResetSmartSwitchState(input) {
        smartSwitchState.reset()
    }
    
    // ... 其餘程式碼
}

/// 檢查是否應該重置智慧切換狀態
private func shouldResetSmartSwitchState(_ input: InputSignalProtocol) -> Bool {
    // 當輸入 Enter、Esc 或其他特殊按鍵時重置
    return input.isEnter || input.isEsc || 
           (input.isControlHold || input.isCommandHold)
}
```

- [ ] **Step 7: 編譯確認**

Run: `cd Packages/vChewing_Typewriter && swift build`
Expected: Build successful (可能會有一些警告需要調整)

- [ ] **Step 8: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git commit -m "Typewriter // PhonabetTypewriter: Implement smart Chinese-English switching logic"
```

---

## Task 5: 在設定頁面加入 UI 控制項

**Files:**
- Modify: `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/Settings/SettingsCocoa/VwrSettingsPaneCocoaBehavior.swift`

**說明：** 在「輸入設定」頁面的 Ｂ 頁籤中加入智慧中英文切換的開關。

- [ ] **Step 1: 在 Behavior 頁面的 Ｂ 頁籤中加入設定控制項**

找到以下程式碼區塊（約第 45-54 行）：

```swift
NSTabView.TabPage(title: "Ｂ") {
  NSStackView.buildSection(width: innerContentWidth) {
    UserDef.kUpperCaseLetterKeyBehavior.render(fixWidth: innerContentWidth)
    UserDef.kNumPadCharInputBehavior.render(fixWidth: innerContentWidth)
  }?.boxed()
  NSStackView.buildSection(width: innerContentWidth) {
    UserDef.kSpecifyIntonationKeyBehavior.render(fixWidth: innerContentWidth)
    UserDef.kAcceptLeadingIntonations.render(fixWidth: innerContentWidth)
  }?.boxed()
  NSView()
}
```

修改為：

```swift
NSTabView.TabPage(title: "Ｂ") {
  NSStackView.buildSection(width: innerContentWidth) {
    UserDef.kUpperCaseLetterKeyBehavior.render(fixWidth: innerContentWidth)
    UserDef.kNumPadCharInputBehavior.render(fixWidth: innerContentWidth)
  }?.boxed()
  NSStackView.buildSection(width: innerContentWidth) {
    UserDef.kSpecifyIntonationKeyBehavior.render(fixWidth: innerContentWidth)
    UserDef.kAcceptLeadingIntonations.render(fixWidth: innerContentWidth)
    UserDef.kSmartChineseEnglishSwitchEnabled.render(fixWidth: innerContentWidth)
  }?.boxed()
  NSView()
}
```

- [ ] **Step 2: 編譯確認**

Run: `swift build`
Expected: Build successful

- [ ] **Step 3: Commit**

```bash
git add Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/Settings/SettingsCocoa/VwrSettingsPaneCocoaBehavior.swift
git commit -m "MainAssembly // Settings: Add Smart Chinese-English switching toggle in Behavior pane"
```

---

## Task 6: 撰寫單元測試

**Files:**
- Create: `Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift`

**說明：** 為智慧中英文切換功能撰寫全面的單元測試。

- [ ] **Step 1: 建立測試檔案**

```swift
// (c) 2026 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation
import Testing
@testable import Typewriter

// MARK: - SmartSwitchTests

/// 智慧中英文切換功能的單元測試
@Suite("SmartSwitchTests", .serialized)
final class SmartSwitchTests {
    // MARK: Lifecycle

    init() {
        PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = true
    }

    deinit {
        PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = false
    }

    // MARK: Tests

    @Test("TC-001: Trigger temp English mode with 2 invalid keys")
    func testTriggerTempEnglishMode() async throws {
        let lm = SimpleLM([
            "你": ["su3"],
            "好": ["ha3"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 輸入 "ab"（連續 2 個無效按鍵）
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "a"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "b"))
        }
        
        // 驗證：應該進入臨時英文模式並輸出 "ab"
        #expect(testSession.currentState?.textToCommit == "ab")
    }

    @Test("TC-002: Return to Chinese mode with Space")
    func testReturnToChineseWithSpace() async throws {
        let lm = SimpleLM([
            "你": ["su3"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 進入臨時英文模式
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "a"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "b"))
        }
        
        // 按空白鍵
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: " ", isSpace: true))
        }
        
        // 驗證：應該提交 "ab" 並返回中文模式
        #expect(testSession.currentState?.textToCommit?.contains("ab") == true)
    }

    @Test("TC-003: Return to Chinese mode with Tab")
    func testReturnToChineseWithTab() async throws {
        let lm = SimpleLM([
            "你": ["su3"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 進入臨時英文模式
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "x"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "y"))
        }
        
        // 按 Tab 鍵
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "\t", isTab: true))
        }
        
        // 驗證：應該提交 "xy"
        #expect(testSession.currentState?.textToCommit?.contains("xy") == true)
    }

    @Test("TC-004: Return to Chinese with double Backspace")
    func testReturnToChineseWithDoubleBackspace() async throws {
        let lm = SimpleLM([
            "你": ["su3"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 進入臨時英文模式
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "t"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "e"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "s"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "t"))
        }
        
        // 連按兩次 Backspace
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "", isBackspace: true))
        }
        try await Task.sleep(for: .milliseconds(50))
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "", isBackspace: true))
        }
        
        // 驗證：應該返回中文模式且不提交任何文字
        #expect(testSession.currentState?.textToCommit?.isEmpty != false)
    }

    @Test("TC-005: Return to Chinese with punctuation")
    func testReturnToChineseWithPunctuation() async throws {
        let lm = SimpleLM([
            "你": ["su3"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 進入臨時英文模式
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "m"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "a"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "i"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "l"))
        }
        
        // 輸入標點符號
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "?"))
        }
        
        // 驗證：應該提交 "mail" 和 "?"
        let committed = testSession.currentState?.textToCommit ?? ""
        #expect(committed.contains("mail"))
        #expect(committed.contains("?"))
    }

    @Test("TC-006: Valid phonabet should not trigger English mode")
    func testValidPhonabetDoesNotTrigger() async throws {
        let lm = SimpleLM([
            "的": ["de"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 輸入 "ㄉ"（有效注音）
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "2")) // 大千鍵盤的 "ㄉ"
        }
        
        // 驗證：應該正常處理注音，不觸發英文模式
        #expect(testSession.currentState?.composingBuffer?.contains("ㄉ") == true)
    }

    @Test("TC-007: Mixed input resets counter")
    func testMixedInputResetsCounter() async throws {
        let lm = SimpleLM([
            "的": ["de"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 輸入一個無效按鍵
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "x"))
        }
        
        // 輸入一個有效注音
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "2")) // ㄉ
        }
        
        // 再輸入一個無效按鍵（這時計數器應該重置了）
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "y"))
        }
        
        // 驗證：應該不會觸發英文模式（因為計數器只有 1）
        #expect(testSession.currentState?.composingBuffer?.contains("ㄉ") == true)
    }

    @Test("TC-008: Continue typing in English mode")
    func testContinueTypingInEnglishMode() async throws {
        let lm = SimpleLM([
            "你": ["su3"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 進入臨時英文模式
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "a"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "p"))
        }
        
        // 繼續輸入
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "p"))
        }
        
        // 按空白返回
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: " ", isSpace: true))
        }
        
        // 驗證：應該提交 "app"
        #expect(testSession.currentState?.textToCommit?.contains("app") == true)
    }

    @Test("TC-009: Disabled feature should not trigger")
    func testDisabledFeature() async throws {
        PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = false
        defer { PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = true }
        
        let lm = SimpleLM([
            "你": ["su3"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 輸入無效按鍵
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "a"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "b"))
        }
        
        // 驗證：應該不觸發英文模式
        #expect(testSession.currentState?.textToCommit?.isEmpty != false)
    }

    @Test("TC-010: Non-empty composer should not trigger")
    func testNonEmptyComposerDoesNotTrigger() async throws {
        let lm = SimpleLM([
            "的": ["de"],
        ])
        let testSession = InputHandlerTests.prepareHandler(lm: lm)
        defer { testSession.resetInputHandler(forceComposerCleanup: true) }
        
        // 先輸入一個有效注音
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "2")) // ㄉ
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "k")) // ㄜ
        }
        
        // 再輸入無效按鍵（此時 composer 不為空）
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "x"))
        }
        _ = await MainActor.run {
            testSession.inputHandler?.handle(generateKeyInput(char: "y"))
        }
        
        // 驗證：應該不觸發英文模式，因為 composer 有內容
        #expect(testSession.currentState?.composingBuffer?.contains("ㄉ") == true)
    }

    // MARK: Helpers

    private func generateKeyInput(
        char: String,
        isSpace: Bool = false,
        isTab: Bool = false,
        isBackspace: Bool = false,
        isEnter: Bool = false,
        isEsc: Bool = false
    ) -> InputSignalProtocol {
        // 使用測試用的 InputSignal 實作
        // 這裡需要根據實際的測試架構調整
        return MockedInputSignal(
            text: char,
            isSpace: isSpace,
            isTab: isTab,
            isBackspace: isBackspace,
            isEnter: isEnter,
            isEsc: isEsc
        )
    }
}

// MARK: - MockedInputSignal

/// 用於測試的 InputSignalProtocol 實作
private struct MockedInputSignal: InputSignalProtocol {
    var text: String?
    var isSpace: Bool
    var isTab: Bool
    var isBackspace: Bool
    var isEnter: Bool
    var isEsc: Bool
    
    var inputTextIgnoringModifiers: String? { text }
    var isReservedKey: Bool { false }
    var isNumericPadKey: Bool { false }
    var isNonLaptopFunctionKey: Bool { false }
    var isControlHold: Bool { false }
    var isOptionHold: Bool { false }
    var isShiftHold: Bool { false }
    var isCommandHold: Bool { false }
    var isInvalid: Bool { false }
}
```

- [ ] **Step 2: 編譯測試確認**

Run: `cd Packages/vChewing_Typewriter && swift build`
Expected: Build successful

- [ ] **Step 3: 執行測試**

Run: `cd Packages/vChewing_Typewriter && swift test --filter SmartSwitchTests`
Expected: All tests pass (如果失敗則需要調整實作)

- [ ] **Step 4: Commit**

```bash
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // Tests: Add comprehensive tests for Smart Chinese-English switching"
```

---

## Task 7: 整合測試與驗證

**Files:**
- All modified files

**說明：** 執行完整的建置和測試流程，確保所有功能正常運作。

- [ ] **Step 1: 執行完整建置**

```bash
make debug
```

Expected: Build successful

- [ ] **Step 2: 執行所有單元測試**

```bash
make test
```

Expected: All tests pass

- [ ] **Step 3: 執行 lint 檢查**

```bash
make lint
```

Expected: No lint errors (如果有則修正)

- [ ] **Step 4: 執行格式化**

```bash
make format
```

- [ ] **Step 5: 最終確認**

建立一個簡單的測試腳本或使用輸入法驗證：

1. 開啟設定視窗，確認「智慧中英文切換」選項出現在輸入設定 > Ｂ頁籤
2. 啟用功能
3. 在文字編輯器中測試：
   - 輸入 "ab" 應該看到 "ab"
   - 按空白鍵應該提交 "ab" 並返回中文
   - 輸入 "test" 然後連按兩次 Backspace 應該刪除所有字母並返回中文

- [ ] **Step 6: Commit 最終調整**

```bash
git add -A
git commit -m "SmartSwitch: Final integration and validation"
```

---

## 計劃摘要

### 檔案修改清單

1. ✅ `Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift`
   - 新增 `kSmartChineseEnglishSwitchEnabled` case
   - 定義資料型別和 metaData

2. ✅ `Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift`
   - 新增 `smartChineseEnglishSwitchEnabled` 協定屬性

3. ✅ `Packages/vChewing_Shared/Sources/Shared/PrefMgr_Core.swift`
   - 使用 `@AppProperty` 實作屬性

4. ✅ `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift`
   - 新增 `SmartSwitchState` 結構
   - 新增狀態屬性
   - 修改 `handle` 方法
   - 新增臨時英文模式處理方法
   - 新增觸發檢查方法
   - 新增狀態重置邏輯

5. ✅ `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/Settings/SettingsCocoa/VwrSettingsPaneCocoaBehavior.swift`
   - 在 Ｂ頁籤中加入設定控制項

6. ✅ `Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift` (新增)
   - 10 個測試案例涵蓋所有功能需求

### 實作重點

1. **狀態管理**：使用 `SmartSwitchState` 結構追蹤模式狀態，確保狀態在適當時機重置
2. **觸發邏輯**：連續 2 個無效按鍵 + 注拼槽為空才觸發
3. **返回機制**：支援空白、Tab、Backspace×2、標點符號
4. **設定整合**：完整整合現有的 UserDef/PrefMgr 設定系統
5. **測試覆蓋**：10 個測試案例涵蓋正常流程和邊界條件

### 風險與注意事項

1. **與現有功能衝突**：需要確保與聲調覆寫、逐字選字等功能相容
2. **效能考量**：無效按鍵檢測必須輕量，不影響輸入響應
3. **不同鍵盤排列**：需要測試所有支援的注音鍵盤排列
4. **狀態同步**：確保在應用程式切換、長時間未輸入等情況下正確重置狀態

---

**計劃完成時間預估：** 4-6 小時（熟悉程式碼後）

**審查檢查清單：**
- [ ] 所有步驟都能獨立執行
- [ ] 每個步驟都有明確的完成標準
- [ ] 程式碼符合 vChewing 風格規範
- [ ] 所有測試通過
- [ ] 設定介面正常運作
- [ ] 功能實際測試驗證
