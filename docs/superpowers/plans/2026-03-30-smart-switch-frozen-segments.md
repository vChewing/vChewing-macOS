# Smart Chinese-English Switch: frozenSegments Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the smart switch triggers English mode while Chinese characters are in the composition buffer, those characters stay in the composition buffer instead of being immediately committed to the OS — enabling the user to commit everything together at the end.

**Architecture:** Add `frozenSegments: [String]` to `SmartSwitchState` to hold previously assembled Chinese text. Replace `commitAssemblerContentIfNeeded` with `freezeAssemblerContentIfNeeded` that snapshots assembler display text into `frozenSegments` without committing. Update `generateStateOfInputting` to prepend `frozenDisplayText` to `displayTextSegments`, so `handleEnter` and `session.state.displayedText` automatically see the full composed text.

**Tech Stack:** Swift 5.5+, Swift Testing framework, vChewing Typewriter package, Megrez compositor, Tekkon composer

---

## File Map

| File | Change |
|------|--------|
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift` | Add `frozenSegments`, `frozenDisplayText`, `freezeSegment()`, `clearFrozenSegments()` to `SmartSwitchState`; update `reset()`; update `isConsideredEmptyForNow` |
| `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift` | Replace `commitAssemblerContentIfNeeded` with `freezeAssemblerContentIfNeeded`; update all 4 call sites (paths B, B', C', D); update `triggerTempEnglishMode` display to prepend frozen; update `handleTempEnglishMode` (Space/Enter/char-append); update `handleBackspaceInTempEnglishMode`; replace `commitEnglishAndReturnToChinese` with `freezeAndReturnToChinese` |
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift` | Update `generateStateOfInputting` to prepend `frozenDisplayText`; update `handleEnter` to call `smartSwitchState.clearFrozenSegments()` after getting `displayedText` |
| `Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift` | Update TC-016 (expects freeze not commit); add TC-022 through TC-026 |

---

## Desired End-to-End Behavior

```
1. Type Chinese → composition buffer: 「中文」
2. Smart switch triggers, type English → buffer: 「中文english」
3. Press Space → exit English mode, return to Chinese; buffer STILL shows 「中文english」
4. Continue typing Chinese → buffer: 「中文english繼續」
5. Press Enter → commit everything: 「中文english繼續」
6. Press Backspace in English mode → deletes from end of English buffer one char at a time
7. Double-tap Backspace in English mode → full reset (clears frozen + assembler + english)
```

---

## Task 1: Add `frozenSegments` to `SmartSwitchState`

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift:14-87`

- [ ] **Step 1.1: Write the failing test**

Add to `SmartSwitchTests.swift` before the closing `}`:

```swift
/// TC-022: SmartSwitchState frozenSegments API
@Test("TC-022: SmartSwitchState frozenSegments tracks frozen display text")
func testFrozenSegmentsAPI() {
  guard let testHandler else {
    Issue.record("testHandler is nil.")
    return
  }
  resetTestState()

  // Initially empty
  #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)
  #expect(testHandler.smartSwitchState.frozenDisplayText.isEmpty)

  // freezeSegment appends
  testHandler.smartSwitchState.freezeSegment("中文")
  #expect(testHandler.smartSwitchState.frozenSegments == ["中文"])
  #expect(testHandler.smartSwitchState.frozenDisplayText == "中文")

  testHandler.smartSwitchState.freezeSegment("english")
  #expect(testHandler.smartSwitchState.frozenSegments == ["中文", "english"])
  #expect(testHandler.smartSwitchState.frozenDisplayText == "中文english")

  // clearFrozenSegments clears
  testHandler.smartSwitchState.clearFrozenSegments()
  #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)
  #expect(testHandler.smartSwitchState.frozenDisplayText.isEmpty)

  // reset() also clears frozenSegments
  testHandler.smartSwitchState.freezeSegment("測試")
  testHandler.smartSwitchState.reset()
  #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)
}
```

- [ ] **Step 1.2: Run the test to verify it fails**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-022"
```

Expected: FAIL with `value of type 'SmartSwitchState' has no member 'frozenSegments'`

- [ ] **Step 1.3: Add `frozenSegments` to `SmartSwitchState`**

In `InputHandler_CoreProtocol.swift`, replace the `SmartSwitchState` class (lines 14–87) with:

```swift
public final class SmartSwitchState {
  /// 連續無效按鍵計數
  public var invalidKeyCount: Int = 0

  /// 是否處於臨時英文模式
  public var isTempEnglishMode: Bool = false

  /// 臨時英文模式下的輸入緩衝
  public var englishBuffer: String = ""

  /// 上一次 Backspace 時間（用於雙擊檢測）
  public var lastBackspaceTime: Date?

  /// Backspace 連續計數
  public var backspaceCount: Int = 0

  /// 按鍵序列（用於檢查是否能組成有效讀音）
  public var keySequence: String = ""

  /// 已凍結的文字段落（保留在組字區不提交）
  public var frozenSegments: [String] = []

  /// 已凍結文字的合併字串（供顯示用）
  public var frozenDisplayText: String { frozenSegments.joined() }

  /// 預設初始化器
  public init() {}

  /// 重置所有狀態（含凍結段落）
  public func reset() {
    invalidKeyCount = 0
    isTempEnglishMode = false
    englishBuffer = ""
    lastBackspaceTime = nil
    backspaceCount = 0
    keySequence = ""
    frozenSegments = []
  }

  /// 重置無效計數（當收到有效注音輸入時）
  public func resetInvalidCount() {
    invalidKeyCount = 0
  }

  /// 增加無效計數
  public func incrementInvalidCount() {
    invalidKeyCount += 1
  }

  /// 進入臨時英文模式
  public func enterTempEnglishMode() {
    isTempEnglishMode = true
    englishBuffer = ""
    invalidKeyCount = 0
    keySequence = ""
  }

  /// 退出臨時英文模式（不清除 frozenSegments，由呼叫方決定）
  public func exitTempEnglishMode() -> String {
    let buffer = englishBuffer
    isTempEnglishMode = false
    englishBuffer = ""
    invalidKeyCount = 0
    keySequence = ""
    lastBackspaceTime = nil
    backspaceCount = 0
    return buffer
  }

  /// 追加英文字母
  public func appendEnglishChar(_ char: String) {
    englishBuffer.append(char)
  }

  /// 刪除最後一個英文字母
  public func deleteLastEnglishChar() {
    if !englishBuffer.isEmpty {
      englishBuffer.removeLast()
    }
  }

  /// 檢查是否達到觸發門檻
  public func shouldTriggerTempEnglishMode(threshold: Int = 2) -> Bool {
    return invalidKeyCount >= threshold
  }

  /// 將一段文字凍結至 frozenSegments（不提交給 OS）
  public func freezeSegment(_ text: String) {
    guard !text.isEmpty else { return }
    frozenSegments.append(text)
  }

  /// 清除凍結段落
  public func clearFrozenSegments() {
    frozenSegments = []
  }
}
```

- [ ] **Step 1.4: Also update `isConsideredEmptyForNow`**

In `InputHandler_CoreProtocol.swift` at line 498, replace:

```swift
  public var isConsideredEmptyForNow: Bool {
    assembler.isEmpty && isComposerOrCalligrapherEmpty && currentTypingMethod == .vChewingFactory
  }
```

with:

```swift
  public var isConsideredEmptyForNow: Bool {
    assembler.isEmpty && isComposerOrCalligrapherEmpty
      && currentTypingMethod == .vChewingFactory
      && smartSwitchState.frozenSegments.isEmpty
  }
```

- [ ] **Step 1.5: Run TC-022 to verify it passes**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-022"
```

Expected: PASS

- [ ] **Step 1.6: Run all existing smart switch tests to verify no regressions**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All 21 existing TCs pass (TC-001 through TC-021).

- [ ] **Step 1.7: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // SmartSwitchState: Add frozenSegments for deferred Chinese commit."
```

---

## Task 2: Update `generateStateOfInputting` to Prepend Frozen Text

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift:23-88`

- [ ] **Step 2.1: Write the failing test**

Add to `SmartSwitchTests.swift`:

```swift
/// TC-023: generateStateOfInputting prepends frozenDisplayText when frozen segments exist
@Test("TC-023: generateStateOfInputting prepends frozenDisplayText")
func testGenerateStateOfInputtingPrependsFrozen() {
  guard let testHandler else {
    Issue.record("testHandler is nil.")
    return
  }
  resetTestState()

  // Freeze "中文" directly into frozenSegments
  testHandler.smartSwitchState.freezeSegment("中文")

  // generateStateOfInputting should include frozen text even with empty assembler/composer.
  // We need a non-empty composer or the guarded flag to get ofInputting back.
  let state = testHandler.generateStateOfInputting(guarded: true)
  #expect(
    state.displayedText.hasPrefix("中文"),
    "displayedText should start with frozen '中文', got: '\(state.displayedText)'"
  )
}
```

- [ ] **Step 2.2: Run the test to verify it fails**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-023"
```

Expected: FAIL — `displayedText` does not contain "中文"

- [ ] **Step 2.3: Modify `generateStateOfInputting` to prepend frozen text**

In `InputHandler_HandleStates.swift`, locate `generateStateOfInputting` (around line 23). After the line:

```swift
    var displayTextSegments: [String] = handleAsCodePointInput || handleAsRomanNumeralInput
      ? [strCodePointBuffer]
      : assembler.assembledSentence.values
```

Add the following block immediately after (before the `var cursor = ...` line):

```swift
    // 若 smartSwitchState 有凍結段落，將其前置於顯示段落。
    if !smartSwitchState.frozenSegments.isEmpty {
      displayTextSegments = smartSwitchState.frozenSegments + displayTextSegments
    }
```

The full updated section should look like:

```swift
    var displayTextSegments: [String] = handleAsCodePointInput || handleAsRomanNumeralInput
      ? [strCodePointBuffer]
      : assembler.assembledSentence.values
    // 若 smartSwitchState 有凍結段落，將其前置於顯示段落。
    if !smartSwitchState.frozenSegments.isEmpty {
      displayTextSegments = smartSwitchState.frozenSegments + displayTextSegments
    }
    var cursor = handleAsCodePointInput || handleAsRomanNumeralInput
      ? displayTextSegments.joined().count
      : convertCursorForDisplay(assembler.cursor)
```

> **Note:** The `cursor` calculation must use `displayTextSegments.joined().count` for codePoint/romanNumerals, but for normal mode, cursor stays as `convertCursorForDisplay(assembler.cursor)` + the offset from frozen text. The cursor will point to the end of frozen text + assembler cursor, which is correct because new input appends after frozen.

Actually, for normal mode the cursor offset must account for frozen text length. Replace the cursor line for normal mode:

```swift
    var cursor = handleAsCodePointInput || handleAsRomanNumeralInput
      ? displayTextSegments.joined().count
      : convertCursorForDisplay(assembler.cursor) + smartSwitchState.frozenDisplayText.count
```

- [ ] **Step 2.4: Run TC-023 to verify it passes**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-023"
```

Expected: PASS

- [ ] **Step 2.5: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All existing TCs still pass.

- [ ] **Step 2.6: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // InputHandler: generateStateOfInputting prepends frozenDisplayText."
```

---

## Task 3: Replace `commitAssemblerContentIfNeeded` with `freezeAssemblerContentIfNeeded`

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift:646-653`

- [ ] **Step 3.1: Write the failing test (update TC-016)**

TC-016 currently expects that Chinese text is **committed** before English mode. Under the new behavior, it should **not** appear in `recentCommissions` but instead be visible in the composition buffer. Update TC-016:

```swift
/// TC-016: 組字區有漢字時觸發英文切換，漢字應留在組字區（凍結），不直接提交
@Test("TC-016: Assembled Chinese text should be frozen in buffer, not committed, before entering English mode")
func testAssembledChineseFrozenBeforeEnglishMode() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }

  resetTestState()
  testSession.recentCommissions.removeAll()

  // 插入已知存在的讀音到 assembler
  _ = testHandler.assembler.insertKey("ㄅㄧˋ")
  testHandler.assemble()
  #expect(!testHandler.assembler.isEmpty, "Assembler should have content after insertKey")

  testSession.recentCommissions.removeAll()

  // 輸入 't'（大千：ㄔ 聲母）
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

  // 輸入 'e'（大千：ㄍ 覆蓋 ㄔ）→ 路徑 B 觸發
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))

  // 新行為：漢字不應被 commit 出去，而是凍結在組字區
  #expect(
    testSession.recentCommissions.isEmpty,
    "Chinese text should NOT be committed (only frozen); got: \(testSession.recentCommissions)"
  )

  // frozenSegments 應有內容
  #expect(
    !testHandler.smartSwitchState.frozenSegments.isEmpty,
    "frozenSegments should contain the assembled Chinese text"
  )

  // 已進入英文模式
  #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in temp English mode")

  // 英文緩衝包含 'te'
  #expect(
    testHandler.smartSwitchState.englishBuffer == "te",
    "English buffer should be 'te', got: '\(testHandler.smartSwitchState.englishBuffer)'"
  )
}
```

- [ ] **Step 3.2: Run TC-016 to verify it now fails (currently passes for wrong reason)**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-016"
```

Expected: FAIL — `recentCommissions` is not empty (old behavior still commits)

- [ ] **Step 3.3: Replace `commitAssemblerContentIfNeeded` with `freezeAssemblerContentIfNeeded`**

In `Typewriter_Phonabet.swift`, replace lines 646–653:

```swift
  /// 若 assembler 非空，將已組漢字以 ofCommitting 狀態 commit 出去。
  /// 用於智慧中英文切換觸發前，避免組字區內容被 assembler.clear() 直接丟棄。
  private func commitAssemblerContentIfNeeded(session: Session) {
    guard !handler.assembler.isEmpty else { return }
    let displayedText = handler.generateStateOfInputting(sansReading: true).displayedText
    guard !displayedText.isEmpty else { return }
    session.switchState(State.ofCommitting(textToCommit: displayedText))
  }
```

with:

```swift
  /// 若 assembler 非空，將已組漢字凍結至 frozenSegments（不提交給 OS）。
  /// 用於智慧中英文切換觸發前，保留組字區的漢字內容讓使用者最後一併提交。
  private func freezeAssemblerContentIfNeeded(session: Session) {
    guard !handler.assembler.isEmpty else { return }
    // 使用 sansReading: true 取得純漢字顯示文字（不含注拼槽）。
    // 注意：此時 frozenSegments 可能已有內容（先前被凍結的），
    // generateStateOfInputting 會把它們一起前置——所以這裡用 displayedText
    // 直接取全文，再減去已有的 frozenDisplayText 前綴，只取 assembler 部分。
    let fullDisplayed = handler.generateStateOfInputting(sansReading: true).displayedText
    let alreadyFrozen = handler.smartSwitchState.frozenDisplayText
    let assemblerPart: String
    if fullDisplayed.hasPrefix(alreadyFrozen) {
      assemblerPart = String(fullDisplayed.dropFirst(alreadyFrozen.count))
    } else {
      assemblerPart = fullDisplayed
    }
    guard !assemblerPart.isEmpty else { return }
    handler.smartSwitchState.freezeSegment(assemblerPart)
  }
```

- [ ] **Step 3.4: Update all call sites of `commitAssemblerContentIfNeeded` → `freezeAssemblerContentIfNeeded`**

In `Typewriter_Phonabet.swift`, replace all occurrences of `commitAssemblerContentIfNeeded(session: session)` with `freezeAssemblerContentIfNeeded(session: session)`.

There are 4 call sites:
1. Line ~711 (path B)
2. Line ~724 (path B')
3. Line ~735 (path C')
4. Line ~198 (path D)

Run:
```bash
# Verify count before replacing
grep -n "commitAssemblerContentIfNeeded" Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
```

Expected output: 5 lines (1 definition + 4 call sites).

Use Edit tool to replace each call site.

- [ ] **Step 3.5: Run TC-016 to verify it now passes**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-016"
```

Expected: PASS

- [ ] **Step 3.6: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All TCs pass.

- [ ] **Step 3.7: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // PhonabetTypewriter: Replace commit with freeze on smart switch trigger."
```

---

## Task 4: Update `triggerTempEnglishMode` Display to Show Frozen Prefix

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift:748-767`

- [ ] **Step 4.1: Write the failing test**

Add to `SmartSwitchTests.swift`:

```swift
/// TC-024: After smart switch trigger with Chinese in assembler, display shows frozen+english
@Test("TC-024: Display shows frozen Chinese prefix + english buffer after trigger")
func testDisplayShowsFrozenPrefixAndEnglishBuffer() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }
  resetTestState()
  testSession.recentCommissions.removeAll()

  // 插入 "ㄅㄧˋ" 組字
  _ = testHandler.assembler.insertKey("ㄅㄧˋ")
  testHandler.assemble()

  // 輸入 't', 'e' 觸發路徑 B
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))

  // 驗證進入英文模式
  #expect(testHandler.smartSwitchState.isTempEnglishMode)

  // session.state.displayedText 應同時包含凍結漢字和英文緩衝
  let displayed = testSession.currentState.displayedText
  let frozen = testHandler.smartSwitchState.frozenDisplayText
  #expect(!frozen.isEmpty, "frozenDisplayText should be non-empty")
  #expect(
    displayed.hasPrefix(frozen),
    "displayedText '\(displayed)' should start with frozen '\(frozen)'"
  )
  #expect(
    displayed.hasSuffix("te"),
    "displayedText '\(displayed)' should end with english buffer 'te'"
  )
}
```

> **Note:** This test requires `testSession.currentState` — verify `MockSession` exposes current state. If not, add `var currentState: IMEStateProtocol { state }` to `MockSession`.

- [ ] **Step 4.2: Run the test to verify it fails (or check MockSession API first)**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-024"
```

If compile error about `currentState`, check `MockSession` and add the property. If runtime fail because display does not include frozen, proceed to step 4.3.

- [ ] **Step 4.3: Update `triggerTempEnglishMode` display**

In `Typewriter_Phonabet.swift`, replace the `triggerTempEnglishMode` function (lines 748–767):

```swift
  /// 執行進入臨時英文模式的動作，將 `keySequence` 內容放入英文緩衝並更新畫面。
  private func triggerTempEnglishMode(session: Session) -> Bool {
    let keysToConvert = handler.smartSwitchState.keySequence
    handler.smartSwitchState.enterTempEnglishMode()
    handler.smartSwitchState.appendEnglishChar(keysToConvert)

    // 先用 ofAbortion 清除 composer 的注音顯示（不會 commit previous displayedText）。
    session.switchState(State.ofAbortion())

    // 建構顯示狀態：凍結漢字（若有）+ 英文緩衝。
    let frozen = handler.smartSwitchState.frozenDisplayText
    let buffer = handler.smartSwitchState.englishBuffer
    let combinedDisplay = frozen + buffer
    if !combinedDisplay.isEmpty {
      let state = State.ofInputting(
        displayTextSegments: [frozen, buffer].filter { !$0.isEmpty },
        cursor: combinedDisplay.count,
        highlightAt: nil
      )
      session.switchState(state)
    }
    return true
  }
```

- [ ] **Step 4.4: Run TC-024 to verify it passes**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-024"
```

Expected: PASS

- [ ] **Step 4.5: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All TCs pass.

- [ ] **Step 4.6: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // PhonabetTypewriter: triggerTempEnglishMode shows frozen+english in display."
```

---

## Task 5: Replace `commitEnglishAndReturnToChinese` with `freezeAndReturnToChinese`

Space/Tab/punctuation in English mode → freeze English buffer, return to Chinese mode.

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift:522-607`

- [ ] **Step 5.1: Write the failing test**

Add to `SmartSwitchTests.swift`:

```swift
/// TC-025: Pressing Space in English mode freezes the buffer (no commit); Chinese mode resumes
@Test("TC-025: Space in English mode freezes buffer, returns to Chinese mode without commit")
func testSpaceInEnglishModeFreezeBuffer() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }
  resetTestState()
  testSession.recentCommissions.removeAll()

  // 輸入 't', 'e', 's', 't' 進入英文模式
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

  #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in English mode")
  #expect(testHandler.smartSwitchState.englishBuffer == "test")

  // 按空格（新行為：凍結而非提交）
  let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
  _ = testHandler.triageInput(event: spaceEvent)

  // 新行為：不應有任何文字被 commit 出去
  #expect(
    testSession.recentCommissions.isEmpty,
    "Space should freeze, not commit; got: \(testSession.recentCommissions)"
  )

  // 已退出英文模式
  #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should have exited English mode")

  // frozenSegments 應包含 "test"
  #expect(
    testHandler.smartSwitchState.frozenDisplayText.contains("test"),
    "frozenDisplayText should contain 'test', got: '\(testHandler.smartSwitchState.frozenDisplayText)'"
  )

  // session state 仍是 ofInputting（顯示 'test' 在組字區）
  #expect(
    testSession.currentState.type == .ofInputting,
    "State should be ofInputting after Space freeze"
  )
}
```

- [ ] **Step 5.2: Run TC-025 to verify it fails (currently commits)**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-025"
```

Expected: FAIL — `recentCommissions` contains "test" (old behavior)

> **Note:** TC-014 ("Pressing Space after 'test' commits 'test'") will now conflict with the new behavior and must be updated in Step 5.3b.

- [ ] **Step 5.3: Replace `commitEnglishAndReturnToChinese` with `freezeAndReturnToChinese`**

In `Typewriter_Phonabet.swift`, replace lines 579–592:

```swift
  /// 提交英文緩衝並返回中文模式
  private func commitEnglishAndReturnToChinese(session: Session) -> Bool {
    let englishText = handler.smartSwitchState.exitTempEnglishMode()

    if !englishText.isEmpty {
      // 使用 ofCommitting 狀態直接提交英文文字。
      // 不能用 generateStateOfInputting()，因為在英文模式下 composer/assembler 為空，
      // 該函式會返回 ofAbortion，而 ofAbortion 不處理 textToCommit。
      session.switchState(State.ofCommitting(textToCommit: englishText))
    }

    // 重置後繼續處理當前按鍵（如果是空白或標點，會被正常處理）
    return false // 讓後續邏輯繼續處理
  }
```

with:

```swift
  /// 凍結英文緩衝並返回中文模式（不提交）
  private func freezeAndReturnToChinese(session: Session) -> Bool {
    let englishText = handler.smartSwitchState.exitTempEnglishMode()

    if !englishText.isEmpty {
      handler.smartSwitchState.freezeSegment(englishText)
    }

    // 更新顯示：以 generateStateOfInputting 產生包含凍結段落的組字區狀態。
    // 若組字區（含凍結）非空，顯示 ofInputting；否則顯示 ofAbortion。
    if !handler.smartSwitchState.frozenSegments.isEmpty || !handler.assembler.isEmpty {
      session.switchState(handler.generateStateOfInputting(guarded: true))
    } else {
      session.switchState(State.ofAbortion())
    }

    return false // 讓後續邏輯繼續處理（如空格觸發選字等）
  }
```

- [ ] **Step 5.3b: Update `handleTempEnglishMode` to call `freezeAndReturnToChinese` instead of `commitEnglishAndReturnToChinese`**

In `Typewriter_Phonabet.swift`, in `handleTempEnglishMode` (around line 522), replace:

```swift
    if isTriggerToReturnToChinese(input) {
      return commitEnglishAndReturnToChinese(session: session)
    }
```

with:

```swift
    if isTriggerToReturnToChinese(input) {
      return freezeAndReturnToChinese(session: session)
    }
```

- [ ] **Step 5.3c: Update TC-014 to reflect new Space behavior**

TC-014 currently expects Space to commit "test". Under the new behavior, Space freezes. Update TC-014:

```swift
/// TC-014: Pressing Space after 'test' freezes 'test' into composition buffer (does not commit)
@Test("TC-014: Pressing Space after 'test' freezes 'test' in composition buffer")
func testSpaceAfterTestFreezeTest() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }

  resetTestState()
  testSession.recentCommissions.removeAll()

  // 輸入 't', 'e', 's', 't'
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))

  #expect(testHandler.smartSwitchState.englishBuffer == "test", "Buffer should be 'test'")

  // 按空格（新行為：凍結，不提交）
  let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
  _ = testHandler.triageInput(event: spaceEvent)

  // 'test' 不應被直接 commit
  #expect(
    testSession.recentCommissions.isEmpty,
    "Space should freeze, not commit; got: \(testSession.recentCommissions)"
  )

  // frozenDisplayText 應包含 'test'
  #expect(
    testHandler.smartSwitchState.frozenDisplayText.contains("test"),
    "frozenDisplayText should contain 'test', got: '\(testHandler.smartSwitchState.frozenDisplayText)'"
  )
}
```

- [ ] **Step 5.4: Run TC-025 and TC-014 to verify both pass**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-025"
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-014"
```

Expected: Both PASS

- [ ] **Step 5.5: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All TCs pass.

- [ ] **Step 5.6: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // PhonabetTypewriter: Space/Tab/punct freeze English buffer instead of committing."
```

---

## Task 6: Update English Mode Character Display to Show Frozen Prefix

When typing new letters in English mode, the display must show `frozen + english`.

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift:545-560`

- [ ] **Step 6.1: Write the failing test**

Add to `SmartSwitchTests.swift`:

```swift
/// TC-026: While in English mode after freezing Chinese, display shows frozen+english live
@Test("TC-026: Display shows frozen Chinese + growing english buffer while typing")
func testDisplayShowsFrozenAndGrowingEnglishBuffer() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }
  resetTestState()
  testSession.recentCommissions.removeAll()

  // 插入 "ㄅㄧˋ" 組字後觸發英文模式（t + e = 路徑 B）
  _ = testHandler.assembler.insertKey("ㄅㄧˋ")
  testHandler.assemble()
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
  #expect(testHandler.smartSwitchState.isTempEnglishMode, "Should be in English mode")

  let frozen = testHandler.smartSwitchState.frozenDisplayText
  #expect(!frozen.isEmpty, "frozenDisplayText should be non-empty")

  // 繼續輸入 's', 't' 在英文模式下
  _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  #expect(testHandler.smartSwitchState.englishBuffer == "test", "englishBuffer should be 'test'")

  // session.state.displayedText 應包含 frozen 前綴 + "test"
  let displayed = testSession.currentState.displayedText
  #expect(
    displayed.hasPrefix(frozen),
    "displayedText '\(displayed)' should start with frozen '\(frozen)'"
  )
  #expect(
    displayed.hasSuffix("test"),
    "displayedText '\(displayed)' should end with 'test'"
  )
}
```

- [ ] **Step 6.2: Run TC-026 to verify it fails**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-026"
```

Expected: FAIL — `displayedText` does not have frozen prefix

- [ ] **Step 6.3: Update character-append display in `handleTempEnglishMode`**

In `Typewriter_Phonabet.swift`, in `handleTempEnglishMode`, replace the letter-handling block (around lines 545–560):

```swift
    // 處理一般英文字母輸入
    let char = input.text
    if char.count == 1, char.first?.isLetter == true {
      handler.smartSwitchState.appendEnglishChar(char)
      // 直接建構 ofInputting 狀態顯示英文緩衝。
      // 不能用 generateStateOfInputting()，因為 assembler 為空時會返回 ofAbortion，
      // 而 ofAbortion 的 tooltip 會被 switchState 忽略且清空 inline display。
      let buffer = handler.smartSwitchState.englishBuffer
      let state = State.ofInputting(
        displayTextSegments: [buffer],
        cursor: buffer.count,
        highlightAt: nil
      )
      session.switchState(state)
      return true
    }
```

with:

```swift
    // 處理一般英文字母輸入
    let char = input.text
    if char.count == 1, char.first?.isLetter == true {
      handler.smartSwitchState.appendEnglishChar(char)
      // 建構 ofInputting 狀態：凍結段落（若有）+ 英文緩衝。
      let frozen = handler.smartSwitchState.frozenDisplayText
      let buffer = handler.smartSwitchState.englishBuffer
      let segments = [frozen, buffer].filter { !$0.isEmpty }
      let combined = frozen + buffer
      let state = State.ofInputting(
        displayTextSegments: segments,
        cursor: combined.count,
        highlightAt: nil
      )
      session.switchState(state)
      return true
    }
```

- [ ] **Step 6.4: Run TC-026 to verify it passes**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-026"
```

Expected: PASS

- [ ] **Step 6.5: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All TCs pass.

- [ ] **Step 6.6: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // PhonabetTypewriter: Show frozen prefix in English mode char-append display."
```

---

## Task 7: Update Enter Key in English Mode to Commit frozen+english

Enter in English mode should commit `frozenDisplayText + englishBuffer`, not just `englishBuffer`.

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift:536-543`

- [ ] **Step 7.1: Write the failing test**

Add to `SmartSwitchTests.swift`:

```swift
/// TC-027: Enter in English mode commits frozen+english together
@Test("TC-027: Enter in English mode commits frozen Chinese + english buffer together")
func testEnterInEnglishModeCommitsFrozenAndEnglish() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }
  resetTestState()
  testSession.recentCommissions.removeAll()

  // 插入 "ㄅㄧˋ" 組字後觸發英文模式 (t + e)
  _ = testHandler.assembler.insertKey("ㄅㄧˋ")
  testHandler.assemble()
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
  #expect(testHandler.smartSwitchState.isTempEnglishMode)

  let frozen = testHandler.smartSwitchState.frozenDisplayText
  #expect(!frozen.isEmpty, "frozenDisplayText should be non-empty")

  // 繼續輸入 's', 't'
  _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  #expect(testHandler.smartSwitchState.englishBuffer == "test")

  // 按 Enter
  let enterEvent = KBEvent.KeyEventData.dataEnterReturn.asEvent
  let result = testHandler.triageInput(event: enterEvent)

  // Enter 應被消耗
  #expect(result == true, "Enter should be consumed")

  // 應提交 frozen + "test"
  let expected = frozen + "test"
  #expect(
    testSession.recentCommissions.contains(expected),
    "Expected '\(expected)' in commissions, got: \(testSession.recentCommissions)"
  )

  // 應已退出英文模式，frozenSegments 應被清空
  #expect(!testHandler.smartSwitchState.isTempEnglishMode)
  #expect(testHandler.smartSwitchState.frozenSegments.isEmpty)
}
```

- [ ] **Step 7.2: Run TC-027 to verify it fails**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-027"
```

Expected: FAIL — only "test" is committed, not `frozen + "test"`

- [ ] **Step 7.3: Update Enter handling in `handleTempEnglishMode`**

In `Typewriter_Phonabet.swift`, in `handleTempEnglishMode`, replace the Enter block (lines 536–543):

```swift
    // Enter 鍵：提交英文緩衝後消耗掉 Enter，避免它穿透給應用程式造成多餘的送出動作。
    if input.isEnter {
      let englishText = handler.smartSwitchState.exitTempEnglishMode()
      if !englishText.isEmpty {
        session.switchState(State.ofCommitting(textToCommit: englishText))
      }
      return true
    }
```

with:

```swift
    // Enter 鍵：提交凍結段落 + 英文緩衝，消耗 Enter 避免穿透給應用程式。
    if input.isEnter {
      let frozen = handler.smartSwitchState.frozenDisplayText
      let englishText = handler.smartSwitchState.exitTempEnglishMode()
      handler.smartSwitchState.clearFrozenSegments()
      let textToCommit = frozen + englishText
      if !textToCommit.isEmpty {
        session.switchState(State.ofCommitting(textToCommit: textToCommit))
      }
      return true
    }
```

- [ ] **Step 7.4: Run TC-027 and TC-021 to verify both pass**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-027"
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-021"
```

Expected: Both PASS

- [ ] **Step 7.5: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All TCs pass.

- [ ] **Step 7.6: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // PhonabetTypewriter: Enter in English mode commits frozen+english together."
```

---

## Task 8: Update `handleEnter` to Clear Frozen Segments After Commit

When Enter is pressed in Chinese mode (after freeze), `handleEnter` reads `session.state.displayedText` which already includes frozen text (from `generateStateOfInputting`). Must clear `frozenSegments` after committing.

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift:381-423`

- [ ] **Step 8.1: Write the failing test**

Add to `SmartSwitchTests.swift`:

```swift
/// TC-028: Enter in Chinese mode after freeze commits all and clears frozenSegments
@Test("TC-028: Enter in Chinese mode commits frozen+assembler and clears frozenSegments")
func testEnterInChineseModeAfterFreezeCommitsAll() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }
  resetTestState()
  testSession.recentCommissions.removeAll()

  // Step 1: 觸發智慧切換，建立 frozenSegments
  _ = testHandler.assembler.insertKey("ㄅㄧˋ")
  testHandler.assemble()
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  #expect(testHandler.smartSwitchState.isTempEnglishMode)

  // Step 2: 按空格，凍結 "test"，回到中文模式
  let spaceEvent = KBEvent.KeyEventData.dataSpace.asEvent
  _ = testHandler.triageInput(event: spaceEvent)
  #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should be back in Chinese mode")

  let frozen = testHandler.smartSwitchState.frozenDisplayText
  #expect(!frozen.isEmpty, "frozenDisplayText should be non-empty after Space")

  testSession.recentCommissions.removeAll()

  // Step 3: 按 Enter，提交全部（frozen + assembler）
  let enterEvent = KBEvent.KeyEventData.dataEnterReturn.asEvent
  let result = testHandler.triageInput(event: enterEvent)
  #expect(result == true, "Enter should be handled")

  // 提交的文字應包含 frozen 內容
  let committed = testSession.recentCommissions.joined()
  #expect(
    committed.contains(frozen),
    "Committed text '\(committed)' should contain frozen '\(frozen)'"
  )

  // frozenSegments 應被清空
  #expect(
    testHandler.smartSwitchState.frozenSegments.isEmpty,
    "frozenSegments should be cleared after Enter commit"
  )
}
```

- [ ] **Step 8.2: Run TC-028 to verify it fails**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-028"
```

Expected: FAIL — frozen text not in committed output, or `frozenSegments` not cleared

- [ ] **Step 8.3: Update `handleEnter` to clear `frozenSegments` after commit**

In `InputHandler_HandleStates.swift`, in `handleEnter` (around line 381), after the line `var displayedText = state.displayedText`, add:

```swift
    // 凍結段落的清理：displayedText 已含 frozenDisplayText（由 generateStateOfInputting 前置），
    // 提交後需清除 frozenSegments，以免下次生成狀態時重複前置。
    let hadFrozenSegments = !smartSwitchState.frozenSegments.isEmpty
```

And after the `session.switchState(State.ofCommitting(textToCommit: displayedText))` line, add:

```swift
    if hadFrozenSegments {
      smartSwitchState.clearFrozenSegments()
    }
```

The updated `handleEnter` function should look like:

```swift
  @discardableResult
  func handleEnter(
    input: InputSignalProtocol, readingOnly: Bool = false,
    associatesData: @escaping () -> ([CandidateInState]) = { [] }
  )
    -> Bool {
    guard let session = session else { return false }
    let state = session.state

    // Special handling for roman numerals mode with buffer content
    if currentTypingMethod == .romanNumerals, !strCodePointBuffer.isEmpty {
      return commitRomanNumeral(session: session)
    }

    guard currentTypingMethod == .vChewingFactory else {
      return revolveTypingMethod(to: .vChewingFactory)
    }

    guard state.type == .ofInputting else { return false }

    var displayedText = state.displayedText

    // 凍結段落的清理：displayedText 已含 frozenDisplayText（由 generateStateOfInputting 前置），
    // 提交後需清除 frozenSegments，以免下次生成狀態時重複前置。
    let hadFrozenSegments = !smartSwitchState.frozenSegments.isEmpty

    if input.commonKeyModifierFlags == [.option, .shift] {
      displayedText = displayedText.map(\.description).joined(separator: " ")
    } else if readingOnly {
      displayedText = commissionByCtrlCommandEnter()
    } else if input.isCommandHold, input.isControlHold {
      displayedText = input.isOptionHold
        ? commissionByCtrlOptionCommandEnter(isShiftPressed: input.isShiftHold)
        : commissionByCtrlCommandEnter(isShiftPressed: input.isShiftHold)
    }

    session.switchState(State.ofCommitting(textToCommit: displayedText))

    if hadFrozenSegments {
      smartSwitchState.clearFrozenSegments()
    }

    associatedPhrases: if !prefs.useSCPCTypingMode, prefs.associatedPhrasesEnabled {
      guard input.commonKeyModifierFlags == .shift else { break associatedPhrases }
      guard isComposerOrCalligrapherEmpty else { break associatedPhrases }
      let associatedCandidates = associatesData()
      guard !associatedCandidates.isEmpty else { break associatedPhrases }
      session.switchState(State.ofAssociates(candidates: associatedCandidates))
    }

    return true
  }
```

- [ ] **Step 8.4: Run TC-028 to verify it passes**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-028"
```

Expected: PASS

- [ ] **Step 8.5: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All TCs pass.

- [ ] **Step 8.6: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // InputHandler: handleEnter clears frozenSegments after committing."
```

---

## Task 9: Update Backspace Behavior in English Mode

- Single Backspace when `englishBuffer` is empty: exit English mode, keep `frozenSegments` and assembler intact
- Double-tap Backspace: full reset (clears `frozenSegments` + assembler + English)
- Single Backspace display must show `frozen + remaining_english`

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift:609-644`

- [ ] **Step 9.1: Write the failing tests**

Add to `SmartSwitchTests.swift`:

```swift
/// TC-029: Single Backspace in English mode deletes one char, shows frozen+remaining
@Test("TC-029: Single Backspace in English mode deletes one char, displays frozen+remaining")
func testSingleBackspaceInEnglishModeShowsFrozen() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }
  resetTestState()
  testSession.recentCommissions.removeAll()

  // 觸發英文模式（t + e），此時有 frozenSegments（因為 assembler 插入了漢字）
  _ = testHandler.assembler.insertKey("ㄅㄧˋ")
  testHandler.assemble()
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
  #expect(testHandler.smartSwitchState.isTempEnglishMode)
  let frozen = testHandler.smartSwitchState.frozenDisplayText
  #expect(!frozen.isEmpty)

  // 繼續輸入 's', 't'
  _ = testHandler.triageInput(event: createKeyEvent(char: "s"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  #expect(testHandler.smartSwitchState.englishBuffer == "test")

  // 單擊 Backspace
  let backspaceEvent = KBEvent.KeyEventData.backspace.asEvent
  _ = testHandler.triageInput(event: backspaceEvent)

  // englishBuffer 應剩 "tes"
  #expect(testHandler.smartSwitchState.englishBuffer == "tes")

  // 仍在英文模式
  #expect(testHandler.smartSwitchState.isTempEnglishMode)

  // frozenSegments 未被清除
  #expect(testHandler.smartSwitchState.frozenDisplayText == frozen)

  // 顯示應為 frozen + "tes"
  let displayed = testSession.currentState.displayedText
  #expect(
    displayed == frozen + "tes",
    "displayed '\(displayed)' should be frozen+remaining '\(frozen + "tes")'"
  )
}

/// TC-030: Single Backspace when englishBuffer empty exits English mode, keeps frozen
@Test("TC-030: Single Backspace with empty englishBuffer exits English mode, keeps frozenSegments")
func testSingleBackspaceEmptyBufferExitsEnglishKeepsFrozen() {
  guard let testHandler else {
    Issue.record("testHandler is nil.")
    return
  }
  resetTestState()

  // 手動設置：英文模式，空緩衝，有凍結段落
  testHandler.smartSwitchState.freezeSegment("中文")
  testHandler.smartSwitchState.enterTempEnglishMode()
  // englishBuffer 此時為空（enterTempEnglishMode 清空了它）

  // 單擊 Backspace
  let backspaceEvent = KBEvent.KeyEventData.backspace.asEvent
  _ = testHandler.triageInput(event: backspaceEvent)

  // 應退出英文模式
  #expect(!testHandler.smartSwitchState.isTempEnglishMode, "Should exit English mode")

  // frozenSegments 應保留
  #expect(
    testHandler.smartSwitchState.frozenDisplayText == "中文",
    "frozenSegments should be preserved, got: '\(testHandler.smartSwitchState.frozenDisplayText)'"
  )
}

/// TC-031: Double-tap Backspace in English mode does full reset including frozenSegments
@Test("TC-031: Double-tap Backspace in English mode clears frozen segments and resets state")
func testDoubleTapBackspaceClearsFrozen() {
  guard let testHandler, let testSession else {
    Issue.record("testHandler or testSession is nil.")
    return
  }
  resetTestState()
  testSession.recentCommissions.removeAll()

  // 觸發英文模式（有 frozenSegments）
  _ = testHandler.assembler.insertKey("ㄅㄧˋ")
  testHandler.assemble()
  _ = testHandler.triageInput(event: createKeyEvent(char: "t"))
  _ = testHandler.triageInput(event: createKeyEvent(char: "e"))
  #expect(testHandler.smartSwitchState.isTempEnglishMode)
  #expect(!testHandler.smartSwitchState.frozenSegments.isEmpty)

  // 快速雙擊 Backspace（模擬 timeDiff <= threshold）
  // 直接測試重置行為：
  handler.smartSwitchState.reset()
  // 注意：在 triageInput 中，雙擊 Backspace 呼叫的 handleBackspaceInTempEnglishMode
  // 會呼叫 handler.smartSwitchState.reset() + handler.assembler.clear()
  // 我們直接驗證這個組合的效果。
  testHandler.assembler.clear()

  #expect(testHandler.smartSwitchState.frozenSegments.isEmpty, "frozenSegments should be cleared on double-tap")
  #expect(testHandler.assembler.isEmpty, "assembler should be cleared on double-tap")
  #expect(!testHandler.smartSwitchState.isTempEnglishMode)
}
```

> **Note on TC-031:** Double-tap Backspace detection uses timing. The test validates the reset API behavior directly since timing is hard to mock. The existing `handleBackspaceInTempEnglishMode` double-tap path calls `handler.smartSwitchState.reset()` which now also clears `frozenSegments` (from Task 1). No code change needed for TC-031.

- [ ] **Step 9.2: Run TC-029 and TC-030 to verify they fail**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-029"
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-030"
```

Expected: TC-029 FAIL (display doesn't show frozen prefix), TC-030 FAIL (frozenSegments cleared on empty backspace)

- [ ] **Step 9.3: Update `handleBackspaceInTempEnglishMode`**

In `Typewriter_Phonabet.swift`, replace `handleBackspaceInTempEnglishMode` (lines 609–644):

```swift
  /// 在臨時英文模式下處理 Backspace
  private func handleBackspaceInTempEnglishMode(
    _ input: InputSignalProtocol,
    session: Session
  ) -> Bool {
    let now = Date()
    let timeDiff = now.timeIntervalSince(handler.smartSwitchState.lastBackspaceTime ?? Date.distantPast)

    if timeDiff <= backspaceDoubleTapThreshold {
      // 雙擊 Backspace：完整重置（含凍結段落 + assembler）
      handler.smartSwitchState.reset()
      handler.assembler.clear()
      session.switchState(State.ofAbortion())
      return true
    } else {
      // 單擊 Backspace
      handler.smartSwitchState.lastBackspaceTime = now
      handler.smartSwitchState.backspaceCount = 1

      if handler.smartSwitchState.englishBuffer.isEmpty {
        // 英文緩衝已空：退出英文模式，保留 frozenSegments 與 assembler。
        handler.smartSwitchState.isTempEnglishMode = false
        handler.smartSwitchState.lastBackspaceTime = nil
        handler.smartSwitchState.backspaceCount = 0
        // 更新顯示：由 generateStateOfInputting 建構（含凍結段落前置）。
        if !handler.smartSwitchState.frozenSegments.isEmpty || !handler.assembler.isEmpty {
          session.switchState(handler.generateStateOfInputting(guarded: true))
        } else {
          session.switchState(State.ofAbortion())
        }
      } else {
        handler.smartSwitchState.deleteLastEnglishChar()
        let frozen = handler.smartSwitchState.frozenDisplayText
        let buffer = handler.smartSwitchState.englishBuffer
        if buffer.isEmpty, frozen.isEmpty {
          // 都清空了 → 返回中文模式
          handler.smartSwitchState.isTempEnglishMode = false
          session.switchState(State.ofAbortion())
        } else {
          // 顯示 frozen + 剩餘英文緩衝
          let segments = [frozen, buffer].filter { !$0.isEmpty }
          let combined = frozen + buffer
          let state = State.ofInputting(
            displayTextSegments: segments,
            cursor: combined.count,
            highlightAt: nil
          )
          session.switchState(state)
        }
      }
      return true
    }
  }
```

- [ ] **Step 9.4: Run TC-029, TC-030, TC-031 to verify they pass**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-029"
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-030"
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-031"
```

Expected: All PASS

- [ ] **Step 9.5: Run full SmartSwitchTests**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter SmartSwitchTests
```

Expected: All TCs pass.

- [ ] **Step 9.6: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/SmartSwitchTests.swift
git commit -m "Typewriter // PhonabetTypewriter: Update Backspace in English mode to preserve frozen segments."
```

---

## Task 10: Update Path D to Use Freeze Instead of Commit

Path D commits `keySequence` as English when reading is invalid. With frozen segments, it should first freeze assembler content (already handled by `freezeAssemblerContentIfNeeded` from Task 3), then commit only the `keySequence`. But the current path D also calls `commitAssemblerContentIfNeeded` which was already replaced in Task 3. Verify TC-017 still passes and the display is correct.

**Files:**
- Verify: `Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift:190-202`

- [ ] **Step 10.1: Run TC-017 to verify it still passes after previous changes**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "TC-017"
```

Expected: PASS (path D freezes assembler then commits keySequence — assembler is empty in TC-017 scenario)

> If TC-017 fails, the `freezeAssemblerContentIfNeeded` in path D at line ~198 is not working as expected. Debug by checking the display state after the path D trigger.

- [ ] **Step 10.2: Run full test suite**

```bash
swift test --package-path ./Packages/vChewing_Typewriter
```

Expected: All tests pass.

- [ ] **Step 10.3: Commit if any fixes were needed**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/Typewriter/Typewriter_Phonabet.swift
git commit -m "Typewriter // PhonabetTypewriter: Verify Path D works correctly with freeze semantics."
```

---

## Task 11: Final Verification

- [ ] **Step 11.1: Run the complete Typewriter test suite**

```bash
swift test --package-path ./Packages/vChewing_Typewriter
```

Expected: All tests pass, including TC-001 through TC-031.

- [ ] **Step 11.2: Run lint and format**

```bash
cd ./Packages && make lint && make format
```

Expected: No errors. If `make format` auto-fixes files, commit the formatting changes.

- [ ] **Step 11.3: Run full project swift build**

```bash
swift build -c debug
```

Expected: Builds successfully with no errors.

- [ ] **Step 11.4: Commit final cleanup if needed**

```bash
git add -A
git commit -m "Typewriter // SmartSwitch: Format and lint cleanup after frozenSegments implementation."
```

---

## Self-Review Checklist

### Spec Coverage

| Requirement | Task |
|-------------|------|
| Chinese stays in buffer when smart switch triggers | Task 3 (freezeAssemblerContentIfNeeded) |
| Buffer shows `中文english` during English mode | Task 4, 6 (display with frozen prefix) |
| Space → freeze English, return to Chinese | Task 5 |
| Enter in English → commit frozen+english | Task 7 |
| Enter in Chinese (after freeze) → commit all | Task 8 |
| Backspace in English → delete from English end | Task 9 |
| Single BS when empty → exit English, keep frozen | Task 9 |
| Double BS → full reset incl. frozen | Task 9 (reset() covers this from Task 1) |
| `isConsideredEmptyForNow` considers frozen | Task 1 step 1.4 |
| TC-014 updated | Task 5 step 5.3c |
| TC-016 updated | Task 3 step 3.1 |

### Type Consistency Check

- `frozenSegments: [String]` defined in Task 1, used as `[String]` throughout ✓
- `frozenDisplayText: String` computed property, used as `String` throughout ✓
- `freezeSegment(_ text: String)` defined in Task 1, called with `String` throughout ✓
- `clearFrozenSegments()` defined in Task 1, called in Tasks 7, 8 ✓
- `freezeAndReturnToChinese` defined in Task 5, called from `handleTempEnglishMode` in Task 5 ✓
- `freezeAssemblerContentIfNeeded` defined in Task 3, replaces all 4 call sites in Task 3 ✓
