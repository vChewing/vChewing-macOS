# Auto Phrase Learning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When a user explicitly selects the same word sequence 3 times via the candidate window, automatically promote it to the user phrase dictionary, eliminating POM same-reading-prefix pollution for proper names like 謝宇軒 vs 謝雨蒼.

**Architecture:** Use POM's existing `memorizePerception` infrastructure with a special `#PHRASE:readings:value` key format (which `parseDelimitedPerceptionKey` ignores since it lacks `&`), storing phrase-level usage counts. When a count crosses the threshold, fire a callback to the platform layer which writes the phrase to disk and inserts it into the live LM instance.

**Tech Stack:** Swift 5.5+, Swift Testing framework, vChewing_LangModelAssembly, vChewing_Typewriter, vChewing_Shared, vChewing_MainAssembly4Darwin

---

## File Map

| File | Change |
|------|--------|
| `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/SubLMs/lmPerceptionOverride.swift` | Add `pomCountForKey(_:candidate:)` method |
| `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/LMInstantiator_POMRepresentable.swift` | Expose `pomCountForKey` as public method on `LMInstantiator` |
| `Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift` | Add `kAutoLearnPhraseTriggerThreshold` case |
| `Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift` | Add `autoLearnPhraseTriggerThreshold: Int { get set }` |
| `Packages/vChewing_Shared/Sources/Shared/PrefMgr_Core.swift` | Add `@AppProperty` implementation |
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift` | Add `autoLearnPhraseCallback` to protocol + implement phrase tracking in `consolidateNode` |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/InputHandler/InputHandler.swift` | Add `autoLearnPhraseCallback` stored property |
| `Packages/vChewing_Typewriter/Tests/TypewriterTests/TestComponents/MockedInputHandlerAndStates.swift` | Add `autoLearnPhraseCallback` stored property |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_Delegates.swift` | Wire up `autoLearnPhraseCallback` |
| `Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Cases3.swift` | Add auto-learn tests |

---

## Task 1: Add `pomCountForKey` to `lmPerceptionOverride.swift`

**Files:**
- Modify: `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/SubLMs/lmPerceptionOverride.swift`

- [ ] **Step 1: Read the file to confirm insertion point**

Open `lmPerceptionOverride.swift` and look for the `memorizePerception` function at line 469. The new method should be inserted immediately after the closing `}` of `memorizePerception`. The `lock` property is an `NSLock`; use `.withLock` for thread safety.

- [ ] **Step 2: Add `pomCountForKey` method**

After the closing `}` of `memorizePerception` (around line 519+), insert:

```swift
/// 回傳特定 key + candidate 的累計次數（thread-safe）。
/// 若 key 或 candidate 不存在則回傳 0。
nonisolated public func pomCountForKey(_ key: String, candidate: String) -> Int {
  lock.withLock {
    guard let koPair = mutLRUMap[key] else { return 0 }
    return koPair.perception.overrides[candidate]?.count ?? 0
  }
}
```

- [ ] **Step 3: Verify the file still compiles**

```bash
swift build --package-path ./Packages/vChewing_LangModelAssembly -c debug 2>&1 | tail -20
```

Expected: `Build complete!` with no errors.

- [ ] **Step 4: Commit**

```bash
git add Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/SubLMs/lmPerceptionOverride.swift
git commit -m "LangModelAssembly // lmPerceptionOverride: Add pomCountForKey thread-safe accessor."
```

---

## Task 2: Expose `pomCountForKey` on `LMInstantiator`

**Files:**
- Modify: `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/LMInstantiator_POMRepresentable.swift`

- [ ] **Step 1: Read the file to find the insertion point**

Open `LMInstantiator_POMRepresentable.swift`. The file has ~82 lines. Find the last closing `}` of the extension. The new method should be appended just before that final `}`.

- [ ] **Step 2: Add the forwarding method**

Inside the `extension LMInstantiator` block (before the final `}`), add:

```swift
/// 查詢特定 POM 計數 key 下某候選字的累計次數。
public func pomCountForKey(_ key: String, candidate: String) -> Int {
  lmPerceptionOverride.pomCountForKey(key, candidate: candidate)
}
```

- [ ] **Step 3: Verify compilation**

```bash
swift build --package-path ./Packages/vChewing_LangModelAssembly -c debug 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/LMInstantiator_POMRepresentable.swift
git commit -m "LangModelAssembly // LMInstantiator: Expose pomCountForKey for phrase tracking."
```

---

## Task 3: Add `autoLearnPhraseTriggerThreshold` preference

**Files:**
- Modify: `Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift`
- Modify: `Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift`
- Modify: `Packages/vChewing_Shared/Sources/Shared/PrefMgr_Core.swift`

- [ ] **Step 1: Add the UserDef case**

In `UserDef.swift`, find the `case kDeltaOfCalendarYears = "DeltaOfCalendarYears"` line (around line 25). Add the new case **before** it (keep alphabetical order is not strictly required; just add it near similar IME logic keys):

Find the line:
```swift
case kFailureFlagForPOMObservation = "_FailureFlag_POMObservation"
```

Add after it:
```swift
case kAutoLearnPhraseTriggerThreshold = "AutoLearnPhraseTriggerThreshold"
```

- [ ] **Step 2: Add the default value in `dataType`**

In `UserDef.swift`, find the `dataType` computed var (line ~415). Find:
```swift
case .kFailureFlagForPOMObservation: return .bool(false)
```

Add after it:
```swift
case .kAutoLearnPhraseTriggerThreshold: return .integer(3)
```

- [ ] **Step 3: Add to `PrefMgrProtocol`**

In `PrefMgrProtocol.swift`, find:
```swift
var fetchSuggestionsFromPerceptionOverrideModel: Bool { get set }
```

Add after it:
```swift
var autoLearnPhraseTriggerThreshold: Int { get set }
```

- [ ] **Step 4: Add concrete implementation in `PrefMgr_Core.swift`**

In `PrefMgr_Core.swift`, find:
```swift
@AppProperty(userDef: .kDeltaOfCalendarYears)
public var deltaOfCalendarYears: Int
```

Add before it:
```swift
@AppProperty(userDef: .kAutoLearnPhraseTriggerThreshold)
public var autoLearnPhraseTriggerThreshold: Int
```

- [ ] **Step 5: Verify Shared package compilation**

```bash
swift build --package-path ./Packages/vChewing_Shared -c debug 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 6: Commit**

```bash
git add Packages/vChewing_Shared/Sources/Shared/UserDef/UserDef.swift
git add Packages/vChewing_Shared/Sources/Shared/Protocols/PrefMgrProtocol.swift
git add Packages/vChewing_Shared/Sources/Shared/PrefMgr_Core.swift
git commit -m "Shared // PrefMgr: Add autoLearnPhraseTriggerThreshold preference (default 3)."
```

---

## Task 4: Add `autoLearnPhraseCallback` to protocol and class

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift`
- Modify: `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/InputHandler/InputHandler.swift`
- Modify: `Packages/vChewing_Typewriter/Tests/TypewriterTests/TestComponents/MockedInputHandlerAndStates.swift`

- [ ] **Step 1: Add to `InputHandlerProtocol`**

In `InputHandler_CoreProtocol.swift`, find the protocol's existing callbacks (around line 127-132):
```swift
var pomSaveCallback: (() -> ())? { get set }
```

Add after it:
```swift
var autoLearnPhraseCallback: ((_ keyArray: [String], _ value: String) -> ())? { get set }
```

- [ ] **Step 2: Add stored property in `InputHandler.swift`**

In `InputHandler.swift` (MainAssembly4Darwin), find:
```swift
public var pomSaveCallback: (() -> ())?
```
(around line 54)

Add after it:
```swift
public var autoLearnPhraseCallback: ((_ keyArray: [String], _ value: String) -> ())?
```

- [ ] **Step 3: Add stored property in `MockedInputHandlerAndStates.swift`**

In `MockedInputHandlerAndStates.swift`, find:
```swift
public var pomSaveCallback: (() -> ())?
```
(around line 177)

Add after it:
```swift
public var autoLearnPhraseCallback: ((_ keyArray: [String], _ value: String) -> ())?
```

- [ ] **Step 4: Verify Typewriter package compilation**

```bash
swift build --package-path ./Packages/vChewing_Typewriter -c debug 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 5: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift
git add Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/InputHandler/InputHandler.swift
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/TestComponents/MockedInputHandlerAndStates.swift
git commit -m "Typewriter // InputHandler: Add autoLearnPhraseCallback to protocol and implementations."
```

---

## Task 5: Implement phrase tracking in `consolidateNode`

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift`

**Context:** `consolidateNode` is in `InputHandler_CoreProtocol.swift` as an `extension InputHandlerProtocol` method. The `pomProcessing` block ends at line 429. The full function ends at line 437 (before `previewCurrentCandidateAtCompositionBuffer`). We insert the phrase-tracking logic **after** the `pomProcessing` block closes (after line 429) but **before** the closing `} else {` of the outer `if !overrideTaskResult` block at line 430.

- [ ] **Step 1: Read the exact location again**

Read `InputHandler_CoreProtocol.swift` lines 415–437 to confirm the exact current line numbers.

- [ ] **Step 2: Add phrase tracking block**

After the closing `}` of `pomProcessing` (after line 429, i.e., the line that says `prefs.failureFlagForPOMObservation = false` followed by `}`), and before the `} else {` that starts the `overrideTaskResult == true` branch, insert:

```swift
      // 自動詞組學習：當使用者明確選字時，追蹤連續選用的詞組，達閾值後自動加入個人詞庫。
      if explicitlyChosen, prefs.fetchSuggestionsFromPerceptionOverrideModel {
        phraseTracking: do {
          let assembled = assembler.assembledSentence
          guard assembled.count >= 2 else { break phraseTracking }
          let windowStart = max(0, assembled.count - 5)
          let window = Array(assembled[windowStart...])
          guard window.count >= 2 else { break phraseTracking }
          for length in 2 ... window.count {
            let slice = Array(window.suffix(length))
            let readings = slice.flatMap {
              $0.joinedCurrentKey(by: Megrez.Compositor.theSeparator)
                .components(separatedBy: Megrez.Compositor.theSeparator)
                .filter { !$0.isEmpty }
            }
            let value = slice.map(\.value).joined()
            guard readings.count == value.count, readings.count >= 2, readings.count <= 5 else { continue }
            let countKey = "#PHRASE:\(readings.joined(separator: "-")):\(value)"
            currentLM.memorizePerception(
              (countKey, value),
              timestamp: Date().timeIntervalSince1970,
              saveCallback: pomSaveCallback
            )
            let count = currentLM.pomCountForKey(countKey, candidate: value)
            let threshold = prefs.autoLearnPhraseTriggerThreshold
            guard count >= threshold else { continue }
            guard !currentLM.hasKeyValuePairFor(keyArray: readings, value: value) else { continue }
            autoLearnPhraseCallback?(readings, value)
          }
        }
      }
```

The exact insertion point is: find the line `prefs.failureFlagForPOMObservation = false` that is inside `pomProcessing:`, then find its enclosing `}` (which closes the `pomProcessing: if ...` block). Insert the new block immediately after that `}`, before the `} else {` for the `overrideTaskResult` true branch.

- [ ] **Step 3: Verify Typewriter package compilation**

```bash
swift build --package-path ./Packages/vChewing_Typewriter -c debug 2>&1 | tail -30
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift
git commit -m "Typewriter // InputHandler: Implement auto phrase learning via consolidateNode phrase tracking."
```

---

## Task 6: Wire up callback in platform layer

**Files:**
- Modify: `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_Delegates.swift`

**Context:** The existing `performUserPhraseOperation` at line 30 and `candidatePairManipulated` at line 340 both call `LMMgr.writeUserPhrasesAtOnce` and `insertTemporaryData`. We need to find where `inputHandler` is first configured (its callbacks are typically set up around the session initialization) and wire up `autoLearnPhraseCallback` there.

- [ ] **Step 1: Find where other callbacks are set on inputHandler**

Search for where `pomSaveCallback` is assigned in MainAssembly4Darwin:

```bash
grep -rn "pomSaveCallback" Packages/vChewing_MainAssembly4Darwin/Sources/ 2>&1
```

This tells us the pattern for where to add `autoLearnPhraseCallback =`.

- [ ] **Step 2: Add callback wiring**

In the same location where `pomSaveCallback` is set, add:

```swift
inputHandler.autoLearnPhraseCallback = { [weak self] keyArray, value in
  guard let self else { return }
  var phrase = UserPhraseInsertable(
    keyArray: keyArray,
    value: value,
    inputMode: inputMode
  )
  LMMgr.writeUserPhrasesAtOnce(phrase, areWeFiltering: false) {
    // 寫入失敗時靜默忽略，下次達到閾值時會再試
  }
  self.inputHandler?.currentLM.insertTemporaryData(
    unigram: .init(keyArray: keyArray, value: value, score: 0),
    isFiltering: false
  )
}
```

- [ ] **Step 3: Verify MainAssembly4Darwin compilation**

```bash
swift build --package-path ./Packages/vChewing_MainAssembly4Darwin -c debug 2>&1 | tail -30
```

Expected: `Build complete!`

- [ ] **Step 4: Commit**

```bash
git add Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_Delegates.swift
git commit -m "MainAssembly4Darwin // InputSession: Wire autoLearnPhraseCallback to write user phrases on threshold."
```

---

## Task 7: Write tests

**Files:**
- Modify: `Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Cases3.swift`

**Context:** The test suite is `@Suite("InputHandlerTests", .serialized)`. Tests go in `extension InputHandlerTests`. Helper `clearTestPOM()` resets POM. `typeSentence(_:)` drives input. `MockInputHandler` now has `autoLearnPhraseCallback`.

The test LM is `LMInstantiator(isCHS: false)` with `connectToTestSQLDB`. The test LM contains standard factory data. For 謝宇軒 / 謝雨蒼, these are **not** in the factory LM — they will be single-char nodes. We verify that after 3 explicit selections, the callback fires (and not before), and that a 2nd distinct phrase doesn't interfere.

- [ ] **Step 1: Write the failing tests**

At the end of `InputHandlerTests_Cases3.swift` (before the final `}`), add the following test group:

```swift
  // MARK: - 自動詞組學習測試

  /// IH-312: 明確選字 3 次後觸發 autoLearnPhraseCallback
  @Test
  func test_IH312_AutoLearnPhrase_TriggersOnThreshold() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.autoLearnPhraseTriggerThreshold = 3
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    var learnedPhrases: [(keyArray: [String], value: String)] = []
    testHandler.autoLearnPhraseCallback = { keyArray, value in
      learnedPhrases.append((keyArray: keyArray, value: value))
    }
    defer {
      testHandler.autoLearnPhraseCallback = nil
    }

    // 三個讀音：ㄒㄧㄝˋ ㄩˇ ㄘㄤ → 謝雨蒼
    // 每次插入臨時資料模擬 3 個單字選字（無 3 字詞組節點）
    func typeXieyucang() {
      // 模擬依序選字：謝、雨、蒼
      let readings: [[String]] = [["ㄒㄧㄝˋ"], ["ㄩˇ"], ["ㄘㄤ"]]
      let values = ["謝", "雨", "蒼"]
      for (reading, value) in zip(readings, values) {
        testHandler.currentLM.insertTemporaryData(
          unigram: .init(keyArray: reading, value: value, score: -1),
          isFiltering: false
        )
      }
      defer {
        testHandler.currentLM.clearTemporaryData(isFiltering: false)
      }
      // 選字 謝
      let candidate1 = CandidateInState(keyArray: ["ㄒㄧㄝˋ"], value: "謝")
      testHandler.consolidateNode(
        candidate: candidate1,
        respectCursorPushing: true,
        preConsolidate: false,
        skipObservation: false,
        explicitlyChosen: true
      )
      // 選字 雨
      let candidate2 = CandidateInState(keyArray: ["ㄩˇ"], value: "雨")
      testHandler.consolidateNode(
        candidate: candidate2,
        respectCursorPushing: true,
        preConsolidate: false,
        skipObservation: false,
        explicitlyChosen: true
      )
      // 選字 蒼
      let candidate3 = CandidateInState(keyArray: ["ㄘㄤ"], value: "蒼")
      testHandler.consolidateNode(
        candidate: candidate3,
        respectCursorPushing: true,
        preConsolidate: false,
        skipObservation: false,
        explicitlyChosen: true
      )
    }

    // 第 1 次：不應觸發
    typeXieyucang()
    #expect(learnedPhrases.isEmpty, "第 1 次選字不應觸發 autoLearn")

    // 第 2 次：不應觸發
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeXieyucang()
    #expect(learnedPhrases.isEmpty, "第 2 次選字不應觸發 autoLearn")

    // 第 3 次：應觸發
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeXieyucang()
    #expect(!learnedPhrases.isEmpty, "第 3 次選字應觸發 autoLearn callback")
    let found = learnedPhrases.first { $0.value.contains("謝") && $0.value.contains("雨") && $0.value.contains("蒼") }
    #expect(found != nil, "應學到包含「謝雨蒼」的詞組")
  }

  /// IH-313: 兩個不同詞組（謝宇軒 vs 謝雨蒼）的計數互不干擾
  @Test
  func test_IH313_AutoLearnPhrase_DifferentPhrasesDontInterfere() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.autoLearnPhraseTriggerThreshold = 3
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    var learnedPhrases: [(keyArray: [String], value: String)] = []
    testHandler.autoLearnPhraseCallback = { keyArray, value in
      learnedPhrases.append((keyArray: keyArray, value: value))
    }
    defer {
      testHandler.autoLearnPhraseCallback = nil
    }

    func typeXieyuxuan() {
      let readings: [[String]] = [["ㄒㄧㄝˋ"], ["ㄩˇ"], ["ㄒㄩㄢ"]]
      let values = ["謝", "宇", "軒"]
      for (reading, value) in zip(readings, values) {
        testHandler.currentLM.insertTemporaryData(
          unigram: .init(keyArray: reading, value: value, score: -1),
          isFiltering: false
        )
      }
      defer { testHandler.currentLM.clearTemporaryData(isFiltering: false) }
      testHandler.consolidateNode(
        candidate: CandidateInState(keyArray: ["ㄒㄧㄝˋ"], value: "謝"),
        respectCursorPushing: true, preConsolidate: false, skipObservation: false, explicitlyChosen: true
      )
      testHandler.consolidateNode(
        candidate: CandidateInState(keyArray: ["ㄩˇ"], value: "宇"),
        respectCursorPushing: true, preConsolidate: false, skipObservation: false, explicitlyChosen: true
      )
      testHandler.consolidateNode(
        candidate: CandidateInState(keyArray: ["ㄒㄩㄢ"], value: "軒"),
        respectCursorPushing: true, preConsolidate: false, skipObservation: false, explicitlyChosen: true
      )
    }

    func typeXieyucang() {
      let readings: [[String]] = [["ㄒㄧㄝˋ"], ["ㄩˇ"], ["ㄘㄤ"]]
      let values = ["謝", "雨", "蒼"]
      for (reading, value) in zip(readings, values) {
        testHandler.currentLM.insertTemporaryData(
          unigram: .init(keyArray: reading, value: value, score: -1),
          isFiltering: false
        )
      }
      defer { testHandler.currentLM.clearTemporaryData(isFiltering: false) }
      testHandler.consolidateNode(
        candidate: CandidateInState(keyArray: ["ㄒㄧㄝˋ"], value: "謝"),
        respectCursorPushing: true, preConsolidate: false, skipObservation: false, explicitlyChosen: true
      )
      testHandler.consolidateNode(
        candidate: CandidateInState(keyArray: ["ㄩˇ"], value: "雨"),
        respectCursorPushing: true, preConsolidate: false, skipObservation: false, explicitlyChosen: true
      )
      testHandler.consolidateNode(
        candidate: CandidateInState(keyArray: ["ㄘㄤ"], value: "蒼"),
        respectCursorPushing: true, preConsolidate: false, skipObservation: false, explicitlyChosen: true
      )
    }

    // 交替輸入兩個名字各 1 次（共 2 次），均不應觸發
    typeXieyuxuan()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeXieyucang()
    testSession.resetInputHandler(forceComposerCleanup: true)
    #expect(learnedPhrases.isEmpty, "交替輸入後不應觸發任何 autoLearn")

    // 再輸入謝宇軒 2 次（共 3 次），應觸發謝宇軒但不觸發謝雨蒼
    typeXieyuxuan()
    testSession.resetInputHandler(forceComposerCleanup: true)
    typeXieyuxuan()
    #expect(learnedPhrases.contains { $0.value.contains("謝") && $0.value.contains("宇") && $0.value.contains("軒") },
            "謝宇軒輸入 3 次後應被學習")
    #expect(!learnedPhrases.contains { $0.value.contains("謝") && $0.value.contains("雨") && $0.value.contains("蒼") },
            "謝雨蒼只輸入 1 次不應被學習")
  }

  /// IH-314: 已在詞庫的詞組不會重複觸發 callback
  @Test
  func test_IH314_AutoLearnPhrase_SkipsIfAlreadyInLM() throws {
    guard let testHandler, let testSession else {
      Issue.record("testHandler or testSession is nil.")
      return
    }
    testHandler.prefs.useSCPCTypingMode = false
    testHandler.prefs.fetchSuggestionsFromPerceptionOverrideModel = true
    testHandler.prefs.autoLearnPhraseTriggerThreshold = 3
    clearTestPOM()
    testSession.resetInputHandler(forceComposerCleanup: true)

    // 預先插入「謝雨蒼」到 LM（模擬已在詞庫）
    let preloadKeyArray = ["ㄒㄧㄝˋ", "ㄩˇ", "ㄘㄤ"]
    testHandler.currentLM.insertTemporaryData(
      unigram: .init(keyArray: preloadKeyArray, value: "謝雨蒼", score: 0),
      isFiltering: false
    )
    defer {
      testHandler.currentLM.clearTemporaryData(isFiltering: false)
    }

    var callbackCount = 0
    testHandler.autoLearnPhraseCallback = { _, _ in callbackCount += 1 }
    defer { testHandler.autoLearnPhraseCallback = nil }

    // 選字 3 次，應不觸發 callback（因為已在詞庫）
    for _ in 0 ..< 3 {
      testSession.resetInputHandler(forceComposerCleanup: true)
      for (reading, value) in zip([["ㄒㄧㄝˋ"], ["ㄩˇ"], ["ㄘㄤ"]], ["謝", "雨", "蒼"]) {
        testHandler.currentLM.insertTemporaryData(
          unigram: .init(keyArray: reading, value: value, score: -1),
          isFiltering: false
        )
        testHandler.consolidateNode(
          candidate: CandidateInState(keyArray: reading, value: value),
          respectCursorPushing: true, preConsolidate: false, skipObservation: false, explicitlyChosen: true
        )
      }
    }
    #expect(callbackCount == 0, "已在詞庫的詞組不應重複觸發 callback")
  }
```

- [ ] **Step 2: Run the new tests (expect failures first)**

```bash
swift test --package-path ./Packages/vChewing_Typewriter --filter "test_IH312\|test_IH313\|test_IH314" 2>&1 | tail -40
```

Expected at this stage: either compile error (if Task 4/5 not yet done) or test failures.

- [ ] **Step 3: Run all tests and confirm no regressions**

```bash
swift test --package-path ./Packages/vChewing_Typewriter 2>&1 | tail -20
```

Expected: All previously passing tests still pass.

- [ ] **Step 4: Commit the test file**

```bash
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Cases3.swift
git commit -m "Typewriter // Tests: Add auto phrase learning coverage (IH-312/313/314)."
```

---

## Task 8: Integration verification

- [ ] **Step 1: Run the full Typewriter test suite**

```bash
swift test --package-path ./Packages/vChewing_Typewriter 2>&1 | tail -30
```

Expected: All tests pass, including the 3 new ones.

- [ ] **Step 2: Build the full project**

```bash
swift build -c debug 2>&1 | tail -20
```

Expected: `Build complete!`

- [ ] **Step 3: Verify no regressions in LangModelAssembly tests**

```bash
swift test --package-path ./Packages/vChewing_LangModelAssembly 2>&1 | tail -20
```

Expected: All tests pass.

---

## Notes

### Why `#PHRASE:` key format works safely
`parseDelimitedPerceptionKey` (line 872) requires `&` in the key. `#PHRASE:ㄒㄧㄝˋ-ㄩˇ-ㄘㄤ:謝雨蒼` has no `&`, so it returns `nil` → never participates in POM suggestions. It is purely a counter stored in the LRU map.

### Why readings.count == value.count guard
Chinese characters are always 1 codepoint per reading syllable in vChewing's model. If they don't match, the slice is malformed (e.g., an English word was selected). Skip those.

### LRU capacity concern
The default LRU capacity is 2048 entries. Each unique phrase (length 2–5) that the user selects gets its own key. For typical usage this is negligible. Phrase-counting keys will be evicted like normal POM keys when capacity is reached, resetting counts — acceptable behavior.

### Threshold default = 3
Matches the plan goal ("3 次即永久記憶"). Stored in UserDefaults under `"AutoLearnPhraseTriggerThreshold"` with default 3.
