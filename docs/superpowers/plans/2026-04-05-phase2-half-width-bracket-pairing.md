# Phase 2 — 半形括號自動配對 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在智慧中英文模式的臨時英文緩衝區內，輸入半形左括號時自動補入對應右括號並游標定位在兩括號之間，支援 Smart Overwrite 與 Paired Backspace。

**Architecture:** 在 `SmartSwitchState` 新增游標欄位與游標感知方法，使英文緩衝區具備完整游標語意；在 `InputHandler_HandleAutoBracket.swift` 新增三個半形括號方法；在 `Typewriter_Phonabet.swift` 的 `handleTempEnglishMode` 整合攔截點，並將所有 `State.ofInputting` 的游標值改用 `englishBufferCursor`。

**Tech Stack:** Swift 5.5+、Swift Testing framework、vChewing_Typewriter SPM package

**Worktree:** `.worktrees/feature-auto-bracket-pairing`（branch `feature/auto-bracket-pairing`）

**Run tests with:**
```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter AutoBracketTests
```

**Run all Typewriter tests (regression check):**
```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
swift test --package-path ./Packages/vChewing_Typewriter
```

---

## File Map

| 動作 | 檔案 |
|------|------|
| Modify | `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift` |
| Modify | `Packages/vChewing_Typewriter/Sources/Typewriter/AutoBracket/InputHandler_HandleAutoBracket.swift` |
| Modify | `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift` |
| Modify | `Packages/vChewing_Typewriter/Tests/TypewriterTests/AutoBracketTests.swift` |

---

## Task 1: SmartSwitchState 游標擴充

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift`
- Test: `Packages/vChewing_Typewriter/Tests/TypewriterTests/AutoBracketTests.swift`

---

- [ ] **Step 1.1: 在 AutoBracketTests.swift 末尾新增失敗測試 suite**

在檔案末尾（`// (End of file)` 之前）新增：

```swift
// MARK: - EnglishBufferCursorTests

/// SmartSwitchState 游標感知方法的單元測試（Task 1 — Phase 2）。
/// 這些測試直接操作 SmartSwitchState，不需要 MockInputHandler 或 session。
@Suite("EnglishBufferCursorTests")
struct EnglishBufferCursorTests {

  // MARK: - appendEnglishChar（游標感知插入）

  @Test("appendEnglishChar 在游標位置插入字元並推進游標")
  func testAppendInsertAtCursor() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    state.appendEnglishChar("b")
    // 游標在末端
    #expect(state.englishBuffer == "ab")
    #expect(state.englishBufferCursor == 2)
    // 手動退回游標後再 append
    state.englishBufferCursor = 1
    state.appendEnglishChar("X")
    // 插入點在 index 1，結果 "aXb"，游標 = 2
    #expect(state.englishBuffer == "aXb")
    #expect(state.englishBufferCursor == 2)
  }

  // MARK: - insertEnglishAtCursor

  @Test("insertEnglishAtCursor(moveCursor: false) 插入但不移動游標")
  func testInsertAtCursorNoMove() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    // cursor = 1, buffer = "("
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor 應仍為 1，buffer = "()"
    #expect(state.englishBuffer == "()")
    #expect(state.englishBufferCursor == 1)
  }

  @Test("insertEnglishAtCursor(moveCursor: true) 插入並移動游標")
  func testInsertAtCursorWithMove() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: true)
    // cursor = 2, buffer = "()"
    #expect(state.englishBuffer == "()")
    #expect(state.englishBufferCursor == 2)
  }

  // MARK: - moveEnglishCursorRight

  @Test("moveEnglishCursorRight 在範圍內推進游標")
  func testMoveRight() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor = 1, buffer = "()"
    state.moveEnglishCursorRight()
    #expect(state.englishBufferCursor == 2)
  }

  @Test("moveEnglishCursorRight 在末端時不越界")
  func testMoveRightAtEnd() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    // cursor = 1 = buffer.count
    state.moveEnglishCursorRight()
    #expect(state.englishBufferCursor == 1) // 不越界
  }

  // MARK: - deleteEnglishCharBeforeCursor

  @Test("deleteEnglishCharBeforeCursor 刪除游標前字元並退游標")
  func testDeleteBefore() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    state.appendEnglishChar("b")
    // cursor = 2, buffer = "ab"
    state.deleteEnglishCharBeforeCursor()
    #expect(state.englishBuffer == "a")
    #expect(state.englishBufferCursor == 1)
  }

  @Test("deleteEnglishCharBeforeCursor 在游標=0 時無副作用")
  func testDeleteBeforeAtStart() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    // cursor = 0, buffer = ""
    state.deleteEnglishCharBeforeCursor()
    #expect(state.englishBuffer == "")
    #expect(state.englishBufferCursor == 0)
  }

  // MARK: - deleteEnglishCharAfterCursor

  @Test("deleteEnglishCharAfterCursor 刪除游標後字元，游標不動")
  func testDeleteAfter() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor = 1, buffer = "()"
    state.deleteEnglishCharAfterCursor()
    #expect(state.englishBuffer == "(")
    #expect(state.englishBufferCursor == 1)
  }

  // MARK: - englishCharBeforeCursor / englishCharAfterCursor

  @Test("englishCharBeforeCursor 和 englishCharAfterCursor 回傳正確字元")
  func testCharAccessors() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    // cursor = 1, buffer = "()"
    #expect(state.englishCharBeforeCursor == "(")
    #expect(state.englishCharAfterCursor == ")")
  }

  @Test("游標在開頭時 englishCharBeforeCursor 為 nil")
  func testCharBeforeNilAtStart() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    #expect(state.englishCharBeforeCursor == nil)
  }

  @Test("游標在末端時 englishCharAfterCursor 為 nil")
  func testCharAfterNilAtEnd() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    // cursor = 1 = buffer.count
    #expect(state.englishCharAfterCursor == nil)
  }

  // MARK: - 重置行為

  @Test("enterTempEnglishMode 重置游標至 0")
  func testEnterResetscursor() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("a")
    state.appendEnglishChar("b")
    #expect(state.englishBufferCursor == 2)
    state.enterTempEnglishMode()
    #expect(state.englishBufferCursor == 0)
  }

  @Test("exitTempEnglishMode 重置游標至 0")
  func testExitResetsursor() {
    let state = SmartSwitchState()
    state.enterTempEnglishMode()
    state.appendEnglishChar("(")
    state.insertEnglishAtCursor(")", moveCursor: false)
    #expect(state.englishBufferCursor == 1)
    _ = state.exitTempEnglishMode()
    #expect(state.englishBufferCursor == 0)
  }
}
```

- [ ] **Step 1.2: 執行測試，確認失敗（新方法尚未存在）**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter EnglishBufferCursorTests
```

預期：編譯失敗，錯誤訊息類似 `value of type 'SmartSwitchState' has no member 'englishBufferCursor'`

- [ ] **Step 1.3: 實作 SmartSwitchState 游標擴充**

在 `InputHandler_CoreProtocol.swift` 中，找到 `SmartSwitchState` class 的屬性宣告區塊（行 ~14–35），在 `public var keySequence: String = ""` 之後，`public var frozenSegments` 之前新增：

```swift
  /// 英文緩衝區游標位置（0 = 字串開頭）
  public var englishBufferCursor: Int = 0
```

找到 `enterTempEnglishMode()` 方法（行 ~68），在 `keySequence = ""` 之後新增：

```swift
    englishBufferCursor = 0
```

找到 `resetExceptFrozen()` 方法（行 ~50），在 `keySequence = ""` 之後新增：

```swift
    englishBufferCursor = 0
```

找到 `appendEnglishChar(_ char: String)` 方法（行 ~76），將整個方法替換為游標感知版本：

```swift
  /// 在游標位置插入字元並推進游標（取代原本的 append）
  public func appendEnglishChar(_ char: String) {
    let idx = englishBuffer.index(englishBuffer.startIndex, offsetBy: englishBufferCursor)
    englishBuffer.insert(contentsOf: char, at: idx)
    englishBufferCursor += char.count
  }
```

找到 `deleteLastEnglishChar()` 方法（行 ~81），將整個方法替換為游標感知版本（重新命名）：

```swift
  /// 刪除游標前一字元，游標左移（取代 deleteLastEnglishChar）
  public func deleteEnglishCharBeforeCursor() {
    guard englishBufferCursor > 0 else { return }
    let idx = englishBuffer.index(englishBuffer.startIndex, offsetBy: englishBufferCursor - 1)
    englishBuffer.remove(at: idx)
    englishBufferCursor -= 1
  }
```

在 `deleteEnglishCharBeforeCursor()` 之後新增三個方法：

```swift
  /// 在游標位置插入字元，可選擇是否推進游標
  public func insertEnglishAtCursor(_ char: String, moveCursor: Bool) {
    let idx = englishBuffer.index(englishBuffer.startIndex, offsetBy: englishBufferCursor)
    englishBuffer.insert(contentsOf: char, at: idx)
    if moveCursor {
      englishBufferCursor += char.count
    }
  }

  /// 游標右移一格（Smart Overwrite 用），不超過字串末端
  public func moveEnglishCursorRight() {
    guard englishBufferCursor < englishBuffer.count else { return }
    englishBufferCursor += 1
  }

  /// 刪除游標後一字元（配對刪除右括號用），游標不動
  public func deleteEnglishCharAfterCursor() {
    guard englishBufferCursor < englishBuffer.count else { return }
    let idx = englishBuffer.index(englishBuffer.startIndex, offsetBy: englishBufferCursor)
    englishBuffer.remove(at: idx)
  }
```

在 `shouldTriggerTempEnglishMode(threshold:)` 之前新增兩個 computed properties：

```swift
  /// 游標前一字元（cursor > 0 時有效）
  public var englishCharBeforeCursor: Character? {
    guard englishBufferCursor > 0 else { return nil }
    let idx = englishBuffer.index(englishBuffer.startIndex, offsetBy: englishBufferCursor - 1)
    return englishBuffer[idx]
  }

  /// 游標後一字元（cursor < buffer.count 時有效）
  public var englishCharAfterCursor: Character? {
    guard englishBufferCursor < englishBuffer.count else { return nil }
    let idx = englishBuffer.index(englishBuffer.startIndex, offsetBy: englishBufferCursor)
    return englishBuffer[idx]
  }
```

- [ ] **Step 1.4: 修正 Typewriter_Phonabet.swift 中唯一的 deleteLastEnglishChar 呼叫**

在 `Typewriter_Phonabet.swift` 第 706 行，找到：

```swift
      handler.smartSwitchState.deleteLastEnglishChar()
```

替換為：

```swift
      handler.smartSwitchState.deleteEnglishCharBeforeCursor()
```

- [ ] **Step 1.5: 執行測試，確認全部通過**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter EnglishBufferCursorTests
```

預期：全部通過，無失敗。

- [ ] **Step 1.6: Commit**

```bash
git add \
  Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift \
  Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift \
  Packages/vChewing_Typewriter/Tests/TypewriterTests/AutoBracketTests.swift
git commit -m "Typewriter // SmartSwitchState: Add cursor support to English buffer."
```

---

## Task 2: 半形括號方法

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/AutoBracket/InputHandler_HandleAutoBracket.swift`
- Test: `Packages/vChewing_Typewriter/Tests/TypewriterTests/AutoBracketTests.swift`

---

- [ ] **Step 2.1: 在 AutoBracketTests.swift 新增半形括號測試 suite（失敗）**

在 `EnglishBufferCursorTests` struct 之後（檔案末尾前）新增：

```swift
// MARK: - HalfWidthAutoBracketTests

/// 半形括號自動配對功能的單元測試（Phase 2）。
/// 直接呼叫 handler 方法，不走完整鍵盤輸入流。
@Suite("HalfWidthAutoBracketTests", .serialized)
@MainActor
final class HalfWidthAutoBracketTests {

  // MARK: Lifecycle

  init() {
    UserDefaults.unitTests = .init(suiteName: "org.atelierInmu.vChewing.Typewriter.HalfWidthAutoBracketTests")
    UserDef.resetAll()
    UserDefaults.pendingUnitTests = true
    PrefMgr.sharedSansDidSetOps.autoBracketPairingEnabled = true
    PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = true

    let lm = LMAssembly.LMInstantiator(isCHS: false)
    let handler = MockInputHandler(lm: lm, pref: PrefMgr.sharedSansDidSetOps)
    let session = MockSession()
    handler.session = session
    session.inputHandler = handler
    self.testHandler = handler
    self.testSession = session
  }

  deinit {
    mainSync {
      self.testHandler?.errorCallback = nil
      self.testSession?.switchState(MockIMEState.ofAbortion())
      LMAssembly.resetSharedState()
    }
    UserDefaults.unitTests?.removeSuite(named: "org.atelierInmu.vChewing.Typewriter.HalfWidthAutoBracketTests")
    UserDef.resetAll()
    mainSync {
      PrefMgr.sharedSansDidSetOps.autoBracketPairingEnabled = true
      PrefMgr.sharedSansDidSetOps.smartChineseEnglishSwitchEnabled = true
    }
  }

  // MARK: Internal

  var testHandler: MockInputHandler?
  var testSession: MockSession?

  func resetTestState() {
    testHandler?.prefs.autoBracketPairingEnabled = true
    testHandler?.prefs.smartChineseEnglishSwitchEnabled = true
    testHandler?.smartSwitchState.reset()
    testHandler?.smartSwitchState.enterTempEnglishMode()
  }

  // MARK: - handleHalfWidthAutoBracketPairing

  /// TC-AB-030: autoBracketPairingEnabled = false 時不觸發
  @Test("TC-AB-030: Does not pair when feature is disabled")
  func testNoPairWhenDisabled() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.prefs.autoBracketPairingEnabled = false
    handler.smartSwitchState.appendEnglishChar("(")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "(")
    #expect(result == false)
    #expect(handler.smartSwitchState.englishBuffer == "(")
  }

  /// TC-AB-031: smartChineseEnglishSwitchEnabled = false 時不觸發
  @Test("TC-AB-031: Does not pair when smart switch is disabled")
  func testNoPairWhenSmartSwitchDisabled() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.prefs.smartChineseEnglishSwitchEnabled = false
    handler.smartSwitchState.appendEnglishChar("(")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "(")
    #expect(result == false)
    #expect(handler.smartSwitchState.englishBuffer == "(")
  }

  /// TC-AB-032: 輸入 '(' 自動補 ')'，游標在括號中間
  @Test("TC-AB-032: Auto-pairs ) after ( in English buffer")
  func testAutoPairParenthesis() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.appendEnglishChar("(")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "(")
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "()")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
  }

  /// TC-AB-033: 輸入 '[' 自動補 ']'，游標在括號中間
  @Test("TC-AB-033: Auto-pairs ] after [ in English buffer")
  func testAutoPairBracket() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.appendEnglishChar("[")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "[")
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "[]")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
  }

  /// TC-AB-034: 非括號字元不觸發
  @Test("TC-AB-034: Non-bracket char does not trigger pairing")
  func testNoPairForNonBracket() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.appendEnglishChar("a")
    let result = handler.handleHalfWidthAutoBracketPairing(insertedChar: "a")
    #expect(result == false)
    #expect(handler.smartSwitchState.englishBuffer == "a")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
  }

  // MARK: - handleHalfWidthSmartOverwrite

  /// TC-AB-035: 游標前方有 ')' 時，輸入 ')' 跳過（Smart Overwrite）
  @Test("TC-AB-035: Smart Overwrite skips ) in English buffer")
  func testSmartOverwrite() {
    guard let handler = testHandler else { return }
    resetTestState()
    // 設定 buffer = "()", cursor = 1
    handler.smartSwitchState.appendEnglishChar("(")
    handler.smartSwitchState.insertEnglishAtCursor(")", moveCursor: false)
    #expect(handler.smartSwitchState.englishBuffer == "()")
    #expect(handler.smartSwitchState.englishBufferCursor == 1)
    // Smart Overwrite
    let result = handler.handleHalfWidthSmartOverwrite(inputChar: ")")
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "()")
    #expect(handler.smartSwitchState.englishBufferCursor == 2)
  }

  /// TC-AB-036: isTempEnglishMode = false 時 Smart Overwrite 不觸發
  @Test("TC-AB-036: Smart Overwrite does not trigger outside temp English mode")
  func testSmartOverwriteNotInEnglishMode() {
    guard let handler = testHandler else { return }
    resetTestState()
    handler.smartSwitchState.isTempEnglishMode = false
    let result = handler.handleHalfWidthSmartOverwrite(inputChar: ")")
    #expect(result == false)
  }

  // MARK: - handleHalfWidthBracketBackspace

  /// TC-AB-037: 空括號 "(|)" 按 Backspace 同時刪除兩側括號
  @Test("TC-AB-037: Paired backspace deletes both brackets when cursor between empty brackets")
  func testPairedBackspace() {
    guard let handler = testHandler else { return }
    resetTestState()
    // 設定 buffer = "()", cursor = 1
    handler.smartSwitchState.appendEnglishChar("(")
    handler.smartSwitchState.insertEnglishAtCursor(")", moveCursor: false)
    let result = handler.handleHalfWidthBracketBackspace()
    #expect(result == true)
    #expect(handler.smartSwitchState.englishBuffer == "")
    #expect(handler.smartSwitchState.englishBufferCursor == 0)
  }

  /// TC-AB-038: 非空括號 "(hi|)" 按 Backspace 不觸發配對刪除
  @Test("TC-AB-038: Backspace does not pair-delete in non-empty brackets")
  func testNoPairedBackspaceWhenNonEmpty() {
    guard let handler = testHandler else { return }
    resetTestState()
    // 設定 buffer = "(hi)", cursor = 3
    handler.smartSwitchState.appendEnglishChar("(")
    handler.smartSwitchState.insertEnglishAtCursor(")", moveCursor: false)
    handler.smartSwitchState.appendEnglishChar("h")
    handler.smartSwitchState.appendEnglishChar("i")
    #expect(handler.smartSwitchState.englishBuffer == "(hi)")
    #expect(handler.smartSwitchState.englishBufferCursor == 3)
    // charBefore = "i", charAfter = ")" → "i" 不是左括號，不觸發
    let result = handler.handleHalfWidthBracketBackspace()
    #expect(result == false)
  }
}
```

- [ ] **Step 2.2: 執行測試，確認失敗（方法尚未存在）**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter HalfWidthAutoBracketTests
```

預期：編譯失敗，錯誤訊息類似 `value of type 'MockInputHandler' has no member 'handleHalfWidthAutoBracketPairing'`

- [ ] **Step 2.3: 在 InputHandler_HandleAutoBracket.swift 新增三個半形方法**

在 `extension InputHandlerProtocol` 的末尾（最後一個 `}` 之前），在 `handleBracketBackspace()` 之後新增：

```swift
  // MARK: - 半形括號自動配對（Phase 2 — 英文緩衝區）

  /// 半形左括號確認插入英文緩衝區後，自動補入對應右括號，游標留在兩括號之間。
  ///
  /// 應在 `smartSwitchState.appendEnglishChar(char)` 成功之後呼叫。
  /// 若回傳 `true`，右括號已插入游標位置（游標未移動）。
  ///
  /// 觸發條件：`autoBracketPairingEnabled` + `smartChineseEnglishSwitchEnabled` + `isTempEnglishMode`
  ///
  /// - Parameter insertedChar: 剛插入英文緩衝區的字元
  /// - Returns: 是否觸發自動配對
  @discardableResult
  func handleHalfWidthAutoBracketPairing(insertedChar: Character) -> Bool {
    guard prefs.autoBracketPairingEnabled else { return false }
    guard prefs.smartChineseEnglishSwitchEnabled else { return false }
    guard smartSwitchState.isTempEnglishMode else { return false }
    guard BracketPairingRules.halfWidthLeftSet.contains(insertedChar) else { return false }
    guard let rightChar = BracketPairingRules.rightOf[insertedChar] else { return false }
    smartSwitchState.insertEnglishAtCursor(String(rightChar), moveCursor: false)
    return true
  }

  /// 輸入半形右括號時，若游標右側已有由自動配對插入的相同右括號，游標跳過（不重複插入）。
  ///
  /// 應在 `appendEnglishChar(char)` 之前呼叫；若回傳 `true`，呼叫端應跳過 append，直接更新 State。
  ///
  /// - Parameter inputChar: 使用者即將輸入的字元
  /// - Returns: 是否執行了 Smart Overwrite
  @discardableResult
  func handleHalfWidthSmartOverwrite(inputChar: Character) -> Bool {
    guard prefs.autoBracketPairingEnabled else { return false }
    guard smartSwitchState.isTempEnglishMode else { return false }
    guard BracketPairingRules.isRightBracket.contains(inputChar) else { return false }
    guard smartSwitchState.englishCharAfterCursor == inputChar else { return false }
    smartSwitchState.moveEnglishCursorRight()
    return true
  }

  /// 游標位於空半形括號內時，Backspace 同時刪除兩側括號。
  ///
  /// 應在 `handleBackspaceInTempEnglishMode` 最前方呼叫；若回傳 `true`，呼叫端應立即更新 State。
  ///
  /// - Returns: 是否執行了配對刪除
  @discardableResult
  func handleHalfWidthBracketBackspace() -> Bool {
    guard prefs.autoBracketPairingEnabled else { return false }
    guard smartSwitchState.isTempEnglishMode else { return false }
    guard
      let charBefore = smartSwitchState.englishCharBeforeCursor,
      let charAfter = smartSwitchState.englishCharAfterCursor,
      BracketPairingRules.halfWidthLeftSet.contains(charBefore),
      let expectedRight = BracketPairingRules.rightOf[charBefore],
      charAfter == expectedRight
    else { return false }
    smartSwitchState.deleteEnglishCharBeforeCursor()
    smartSwitchState.deleteEnglishCharAfterCursor()
    return true
  }
```

- [ ] **Step 2.4: 執行測試，確認全部通過**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter HalfWidthAutoBracketTests
```

預期：9/9 通過。若有失敗，先修正再繼續。

- [ ] **Step 2.5: 同時確認 Phase 1 測試仍通過**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter AutoBracketTests
```

預期：全部通過（Phase 1 的 19 個 + Phase 2 新增的 tests）。

- [ ] **Step 2.6: Commit**

```bash
git add \
  Packages/vChewing_Typewriter/Sources/Typewriter/AutoBracket/InputHandler_HandleAutoBracket.swift \
  Packages/vChewing_Typewriter/Tests/TypewriterTests/AutoBracketTests.swift
git commit -m "Typewriter // AutoBracket: Add half-width bracket pairing methods (Phase 2)."
```

---

## Task 3: Typewriter_Phonabet.swift 整合

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift`

---

- [ ] **Step 3.1: 更新 ASCII 字元輸入處理（行 ~648–665）**

在 `Typewriter_Phonabet.swift`，找到以下程式碼區塊（大約在 `handleTempEnglishMode` 函式內的 "可印列 ASCII 字元" 段落）：

```swift
    let char = input.text
    if char.count == 1, let scalar = char.unicodeScalars.first,
       scalar.value >= 0x21, scalar.value <= 0x7E {
      handler.smartSwitchState.appendEnglishChar(char)
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      let combinedDisplay = frozen + buffer
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: combinedDisplay.count,
        highlightAt: nil
      )
      session.switchState(state)
      return true
    }
```

替換為：

```swift
    let char = input.text
    if char.count == 1, let scalar = char.unicodeScalars.first,
       scalar.value >= 0x21, scalar.value <= 0x7E {
      // 半形右括號：先檢查 Smart Overwrite（游標跳過，不重複插入）
      if let inputChar = char.first, handler.handleHalfWidthSmartOverwrite(inputChar: inputChar) {
        let frozen = handler.smartSwitchState.frozenDisplayText
        let buffer = handler.smartSwitchState.englishBuffer
        let state = State.ofInputting(
          displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
          cursor: frozen.count + handler.smartSwitchState.englishBufferCursor,
          highlightAt: nil
        )
        session.switchState(state)
        return true
      }
      // 一般字元：插入至游標位置
      handler.smartSwitchState.appendEnglishChar(char)
      // 半形左括號：自動補入右括號（游標停在兩括號之間）
      if let inputChar = char.first {
        handler.handleHalfWidthAutoBracketPairing(insertedChar: inputChar)
      }
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: frozen.count + handler.smartSwitchState.englishBufferCursor,
        highlightAt: nil
      )
      session.switchState(state)
      return true
    }
```

- [ ] **Step 3.2: 更新空白鍵輸入的 State cursor（行 ~634–645）**

找到空白鍵處理段落：

```swift
    if input.isSpace {
      handler.smartSwitchState.appendEnglishChar(" ")
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      let combinedDisplay = frozen + buffer
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: combinedDisplay.count,
        highlightAt: nil
      )
      session.switchState(state)
      return true
    }
```

替換為：

```swift
    if input.isSpace {
      handler.smartSwitchState.appendEnglishChar(" ")
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: frozen.count + handler.smartSwitchState.englishBufferCursor,
        highlightAt: nil
      )
      session.switchState(state)
      return true
    }
```

- [ ] **Step 3.3: 更新 handleBackspaceInTempEnglishMode（行 ~691–725）**

找到整個 `handleBackspaceInTempEnglishMode` 函式：

```swift
  private func handleBackspaceInTempEnglishMode(
    session: Session
  ) -> Bool {
    if handler.smartSwitchState.englishBuffer.isEmpty {
      // 英文緩衝已空：退出英文模式，保留 frozenSegments 與 assembler。
      handler.smartSwitchState.isTempEnglishMode = false
      // 更新顯示：由 generateStateOfInputting 建構（含凍結段落前置）。
      if !handler.smartSwitchState.frozenSegments.isEmpty || !handler.assembler.isEmpty {
        session.switchState(handler.generateStateOfInputting(guarded: true))
      } else {
        session.switchState(State.ofAbortion())
      }
    } else {
      // 英文緩衝非空：逐字刪除，不觸發雙擊計時（避免連按 Backspace 誤觸完整重置）。
      handler.smartSwitchState.deleteEnglishCharBeforeCursor()
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      if buffer.isEmpty, frozen.isEmpty {
        // 都清空了 → 返回中文模式（防禦性 fallback，正常情況下 frozen 不應為空）
        handler.smartSwitchState.isTempEnglishMode = false
        session.switchState(State.ofAbortion())
      } else {
        // 顯示 frozen + 剩餘英文緩衝
        let combinedDisplay = frozen + buffer
        let state = State.ofInputting(
          displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
          cursor: combinedDisplay.count,
          highlightAt: nil
        )
        session.switchState(state)
      }
    }
    return true
  }
```

替換為：

```swift
  private func handleBackspaceInTempEnglishMode(
    session: Session
  ) -> Bool {
    // 1. 半形空括號配對刪除（如 "(|)" → 同時刪除兩側括號）
    if handler.handleHalfWidthBracketBackspace() {
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      if buffer.isEmpty, frozen.isEmpty {
        handler.smartSwitchState.isTempEnglishMode = false
        session.switchState(State.ofAbortion())
      } else {
        let state = State.ofInputting(
          displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
          cursor: frozen.count + handler.smartSwitchState.englishBufferCursor,
          highlightAt: nil
        )
        session.switchState(state)
      }
      return true
    }

    // 2. 游標在最左端（無字元可刪）：退出英文模式，清除緩衝（含游標右側的右括號）
    if handler.smartSwitchState.englishBufferCursor == 0 {
      handler.smartSwitchState.englishBuffer = ""
      handler.smartSwitchState.englishBufferCursor = 0
      handler.smartSwitchState.isTempEnglishMode = false
      if !handler.smartSwitchState.frozenSegments.isEmpty || !handler.assembler.isEmpty {
        session.switchState(handler.generateStateOfInputting(guarded: true))
      } else {
        session.switchState(State.ofAbortion())
      }
      return true
    }

    // 3. 一般刪除：刪除游標前一字元
    handler.smartSwitchState.deleteEnglishCharBeforeCursor()
    let frozen = handler.smartSwitchState.frozenDisplayText
    let buffer = handler.smartSwitchState.englishBuffer
    if buffer.isEmpty, frozen.isEmpty {
      handler.smartSwitchState.isTempEnglishMode = false
      session.switchState(State.ofAbortion())
    } else {
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: frozen.count + handler.smartSwitchState.englishBufferCursor,
        highlightAt: nil
      )
      session.switchState(state)
    }
    return true
  }
```

- [ ] **Step 3.4: 更新路徑 D 入場的 State cursor（行 ~218–226）**

找到路徑 D 的 State.ofInputting 建構（位於 `if !handler.smartSwitchState.frozenSegments.isEmpty {` 分支內）：

```swift
          let newState = State.ofInputting(
            displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
            cursor: combinedDisplay.count,
            highlightAt: nil
          )
```

替換為（注意：`combinedDisplay` 這行也可一併移除，但若上方有其他用途則保留）：

```swift
          let newState = State.ofInputting(
            displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
            cursor: frozen.count + handler.smartSwitchState.englishBufferCursor,
            highlightAt: nil
          )
```

- [ ] **Step 3.5: 更新 SmartSwitch 觸發入場的 State cursor（行 ~861–865）**

找到 `triggerTempEnglishMode` 函式末尾的 State.ofInputting 建構：

```swift
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: combinedDisplay.count,
        highlightAt: nil
      )
```

替換為：

```swift
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: frozen.count + handler.smartSwitchState.englishBufferCursor,
        highlightAt: nil
      )
```

- [ ] **Step 3.6: 執行 AutoBracketTests 確認全部通過**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter AutoBracketTests
```

預期：全部通過。

- [ ] **Step 3.7: 執行 SmartSwitchTests 確認無退步**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

預期：全部通過（或與 Phase 1 前相同的 pre-existing flakiness）。

- [ ] **Step 3.8: Commit**

```bash
git add \
  Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git commit -m "Typewriter // PhonabetTypewriter: Integrate half-width bracket pairing in temp English mode."
```

---

## 最終驗證

- [ ] **Step F.1: 執行所有 AutoBracket 相關測試**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter AutoBracketTests
```

預期：全部通過（Task 1 + Task 2 + Phase 1 原有測試）。

- [ ] **Step F.2: 查看 git log 確認 3 個 commit**

```bash
git log --oneline -5
```

預期最近 3 個 commit：
```
Typewriter // PhonabetTypewriter: Integrate half-width bracket pairing in temp English mode.
Typewriter // AutoBracket: Add half-width bracket pairing methods (Phase 2).
Typewriter // SmartSwitchState: Add cursor support to English buffer.
```
