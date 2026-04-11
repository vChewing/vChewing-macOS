# Similar Phonetic (近音表) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement 近音表選字 — a post-correction tool that lets users press `↑` after typing to open a 2D floating table showing same/near-phonetic candidates for replacing the character before the cursor.

**Architecture:** New `SimilarPhoneticRow` type added to `IMEStateData` (Shared package); pure-logic `SimilarPhoneticHandler` and `SimilarPhoneticRules` in the Typewriter package (testable); AppKit `SimilarPhoneticUI` floating window in MainAssembly4Darwin; state routing follows the exact same pattern as `ofNumberInput`.

**Tech Stack:** Swift 6, AppKit (UI only), `LMAssembly.LMInstantiator` for unigram queries, `Megrez.Compositor` for key insertion/removal, Swift Testing framework for tests.

---

## File Map

### New Files
| File | Responsibility |
|------|---------------|
| `Packages/vChewing_Typewriter/Sources/Typewriter/SimilarPhonetic/SimilarPhoneticRules.swift` | Near-sound consonant/vowel pair tables; `splitTone`, `nearVowelBase`, `nearConsonantBase` pure functions |
| `Packages/vChewing_Typewriter/Sources/Typewriter/SimilarPhonetic/SimilarPhoneticHandler.swift` | `buildRows(for:lm:)` — expands a phonetic into ordered `[SimilarPhoneticRow]` by querying the LM |
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleSimilarPhonetic.swift` | `handleSimilarPhoneticState(input:)` extension on `InputHandlerProtocol`; also `triggerSimilarPhonetic(input:)` and `applyNearPhoneticReplacement(newPhonetic:value:)` |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SimilarPhonetic/SimilarPhoneticUI.swift` | `SimilarPhoneticUI: NSObject, SimilarPhoneticUIProtocol` — AppKit floating window with 2D table, blue-highlight row, header 1–8, `>` indicator |
| `Packages/vChewing_Typewriter/Tests/TypewriterTests/SimilarPhoneticTests.swift` | Swift Testing tests for `SimilarPhoneticRules` and `SimilarPhoneticHandler` |

### Modified Files
| File | Change |
|------|--------|
| `Packages/vChewing_Shared/Sources/Shared/Shared.swift` | Add `case ofSimilarPhonetic = "SimilarPhonetic"` to `StateType` |
| `Packages/vChewing_Shared/Sources/Shared/Protocols/IMEStateProtocolAndData.swift` | Add `SimilarPhoneticRow` struct; add `similarPhoneticRows: [SimilarPhoneticRow]` and `selectedSimilarPhoneticRow: Int` to `IMEStateData`; add `ofSimilarPhonetic(...)` factory to `IMEStateProtocol`; include `.ofSimilarPhonetic` in `hasComposition` |
| `Packages/vChewing_Shared/Sources/Shared/Protocols/SessionUIProtocol.swift` | Add `SimilarPhoneticUIProtocol`; add `var similarPhoneticUI: (any SimilarPhoneticUIProtocol)?` to `SessionUIProtocol` |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/IMEState.swift` | Implement `ofSimilarPhonetic(...)` constructor in `IMEStateProtocol` extension |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/SessionUI.swift` | Add `public let similarPhoneticUI: (any SimilarPhoneticUIProtocol)? = SimilarPhoneticUI()` |
| `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_HandleStates.swift` | Add `.ofSimilarPhonetic` case to `switchState` and `updateCompositionBufferDisplay` |
| `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_TriageInput.swift` | Add `case .ofSimilarPhonetic:` to `triageByState`; intercept `↑` key before `callCandidateState` to call `triggerSimilarPhonetic` |
| `Packages/vChewing_Typewriter/Tests/TypewriterTests/TestComponents/MockedInputHandlerAndStates.swift` | Add `ofSimilarPhonetic(...)` to `MockIMEState` |

---

## Task 1 — Add `ofSimilarPhonetic` to StateType and IMEStateData

**Files:**
- Modify: `Packages/vChewing_Shared/Sources/Shared/Shared.swift:68`
- Modify: `Packages/vChewing_Shared/Sources/Shared/Protocols/IMEStateProtocolAndData.swift`

- [ ] **Step 1.1: Add `SimilarPhoneticRow` struct to `IMEStateProtocolAndData.swift`**

  Insert after the `CandidateInState` typealias (line 13):

  ```swift
  // MARK: - SimilarPhoneticRow

  /// 近音表中的一列資料。
  public struct SimilarPhoneticRow: Equatable {
    /// 該列的注音讀音（含聲調，如 "ㄘㄢ"、"ㄘㄢˊ"）。
    public let phonetic: String
    /// 候選字列表（依詞頻排序）。
    public let candidates: [String]
    /// 目前顯示的頁碼（0-indexed）。
    public var currentPage: Int

    public init(phonetic: String, candidates: [String]) {
      self.phonetic = phonetic
      self.candidates = candidates
      self.currentPage = 0
    }

    /// 每頁最多 8 個候選字。
    public static let pageSize = 8

    public var totalPages: Int {
      max(1, (candidates.count + Self.pageSize - 1) / Self.pageSize)
    }

    /// 目前頁上的候選字（最多 8 個）。
    public var candidatesOnCurrentPage: [String] {
      let start = currentPage * Self.pageSize
      guard start < candidates.count else { return [] }
      let end = min(start + Self.pageSize, candidates.count)
      return Array(candidates[start ..< end])
    }

    /// 該列是否有更多頁（顯示 `>` 指示符）。
    public var hasNextPage: Bool { currentPage < totalPages - 1 }
  }
  ```

- [ ] **Step 1.2: Add fields to `IMEStateData` struct**

  In `IMEStateData`, after `public var numberBuffer: String = ""` (line 155):

  ```swift
  public var similarPhoneticRows: [SimilarPhoneticRow] = []
  public var selectedSimilarPhoneticRow: Int = 0
  ```

- [ ] **Step 1.3: Add `ofSimilarPhonetic` to `IMEStateProtocol`**

  In `IMEStateProtocol`, after `ofNumberInput` declaration (after line 54):

  ```swift
  static func ofSimilarPhonetic(
    rows: [SimilarPhoneticRow],
    selectedRow: Int,
    displayTextSegments: [String],
    cursor: Int
  ) -> Self
  ```

- [ ] **Step 1.4: Update `hasComposition` in `IMEStateProtocol` extension**

  Change:
  ```swift
  case .ofCandidates, .ofInputting, .ofMarking, .ofNumberInput: return true
  ```
  To:
  ```swift
  case .ofCandidates, .ofInputting, .ofMarking, .ofNumberInput, .ofSimilarPhonetic: return true
  ```

- [ ] **Step 1.5: Add `ofSimilarPhonetic` to `StateType` in `Shared.swift`**

  After `case ofNumberInput = "NumberInput"` (line 68):

  ```swift
  /// **近音表選字狀態 .ofSimilarPhonetic**: 使用者按下 ↑ 後，針對游標前一字展開近音表進行選字補正。
  case ofSimilarPhonetic = "SimilarPhonetic"
  ```

- [ ] **Step 1.6: Build Shared package to verify**

  ```bash
  swift build --package-path ./Packages/vChewing_Shared
  ```
  Expected: BUILD SUCCEEDED (zero errors).

- [ ] **Step 1.7: Commit**

  ```bash
  git add Packages/vChewing_Shared/
  git commit -m "Shared // IMEState: Add ofSimilarPhonetic state type and SimilarPhoneticRow data model."
  ```

---

## Task 2 — Implement `SimilarPhoneticRules.swift` and Tests

**Files:**
- Create: `Packages/vChewing_Typewriter/Sources/Typewriter/SimilarPhonetic/SimilarPhoneticRules.swift`
- Create: `Packages/vChewing_Typewriter/Tests/TypewriterTests/SimilarPhoneticTests.swift`

- [ ] **Step 2.1: Write failing tests first**

  Create `SimilarPhoneticTests.swift`:

  ```swift
  // (c) 2021 and onwards The vChewing Project (MIT-NTL License).
  // ====================
  // This code is released under the MIT license (SPDX-License-Identifier: MIT)
  // ... with NTL restriction stating that:
  // No trademark license is granted to use the trade names, trademarks, service
  // marks, or product names of Contributor, except as required to fulfill notice
  // requirements defined in MIT License.

  import Foundation
  import Testing
  @testable import Typewriter

  @Suite("SimilarPhoneticRules")
  struct SimilarPhoneticRulesTests {

    // MARK: - splitTone

    @Test("splitTone: 無聲調標記 → 視為一聲，tone = \"\"")
    func testSplitToneFirstTone() {
      let (base, tone) = SimilarPhoneticRules.splitTone("ㄘㄢ")
      #expect(base == "ㄘㄢ")
      #expect(tone == "")
    }

    @Test("splitTone: 帶 ˊ（二聲）")
    func testSplitToneSecondTone() {
      let (base, tone) = SimilarPhoneticRules.splitTone("ㄇㄡˊ")
      #expect(base == "ㄇㄡ")
      #expect(tone == "ˊ")
    }

    @Test("splitTone: 帶 ˇ（三聲）")
    func testSplitToneThirdTone() {
      let (base, tone) = SimilarPhoneticRules.splitTone("ㄎㄨˇ")
      #expect(base == "ㄎㄨ")
      #expect(tone == "ˇ")
    }

    @Test("splitTone: 帶 ˋ（四聲）")
    func testSplitToneFourthTone() {
      let (base, tone) = SimilarPhoneticRules.splitTone("ㄅㄛˋ")
      #expect(base == "ㄅㄛ")
      #expect(tone == "ˋ")
    }

    @Test("splitTone: 帶 ˙（輕聲）")
    func testSplitToneLightTone() {
      let (base, tone) = SimilarPhoneticRules.splitTone("ㄅㄛ˙")
      #expect(base == "ㄅㄛ")
      #expect(tone == "˙")
    }

    // MARK: - allReadings

    @Test("allReadings: ㄘㄢ → 五個聲調版本，ㄘㄢ 排第一")
    func testAllReadingsFirstTone() {
      let readings = SimilarPhoneticRules.allReadings(of: "ㄘㄢ")
      #expect(readings.first == "ㄘㄢ")
      #expect(readings.contains("ㄘㄢˊ"))
      #expect(readings.contains("ㄘㄢˇ"))
      #expect(readings.contains("ㄘㄢˋ"))
      #expect(readings.contains("ㄘㄢ˙"))
      #expect(readings.count == 5)
    }

    @Test("allReadings: ㄇㄡˊ → 五個，ㄇㄡˊ 排第一")
    func testAllReadingsSecondTone() {
      let readings = SimilarPhoneticRules.allReadings(of: "ㄇㄡˊ")
      #expect(readings.first == "ㄇㄡˊ")
      #expect(readings.contains("ㄇㄡ"))
      #expect(readings.count == 5)
    }

    // MARK: - nearVowelBase

    @Test("nearVowelBase: ㄇㄡ → ㄇㄛ (ㄡ↔ㄛ)")
    func testNearVowelMouMo() {
      #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄇㄡ") == "ㄇㄛ")
    }

    @Test("nearVowelBase: ㄇㄛ → ㄇㄡ (ㄛ↔ㄡ)")
    func testNearVowelMoMou() {
      #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄇㄛ") == "ㄇㄡ")
    }

    @Test("nearVowelBase: ㄙㄨㄣ → ㄙㄨㄥ (ㄨㄣ↔ㄨㄥ)")
    func testNearVowelSunSong() {
      #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄙㄨㄣ") == "ㄙㄨㄥ")
    }

    @Test("nearVowelBase: ㄧㄣ → ㄧㄥ (ㄧㄣ↔ㄧㄥ)")
    func testNearVowelYinYing() {
      #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄧㄣ") == "ㄧㄥ")
    }

    @Test("nearVowelBase: ㄘㄢ → ㄘㄤ (ㄢ↔ㄤ)")
    func testNearVowelCanCang() {
      #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄘㄢ") == "ㄘㄤ")
    }

    @Test("nearVowelBase: ㄅㄛ → nil (無韻母近音對)")
    func testNearVowelBoNil() {
      #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄅㄛ") == nil)
    }

    @Test("nearVowelBase: ㄦ → nil (無韻母對)")
    func testNearVowelErNil() {
      #expect(SimilarPhoneticRules.nearVowelBase(for: "ㄦ") == nil)
    }

    // MARK: - nearConsonantBase

    @Test("nearConsonantBase: ㄘㄢ → ㄔㄢ (ㄘ↔ㄔ)")
    func testNearConsonantCanChan() {
      #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄘㄢ") == "ㄔㄢ")
    }

    @Test("nearConsonantBase: ㄙㄨㄣ → ㄕㄨㄣ (ㄙ↔ㄕ)")
    func testNearConsonantSunShun() {
      #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄙㄨㄣ") == "ㄕㄨㄣ")
    }

    @Test("nearConsonantBase: ㄍㄣ → ㄎㄣ (ㄍ↔ㄎ)")
    func testNearConsonantGenKen() {
      #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄍㄣ") == "ㄎㄣ")
    }

    @Test("nearConsonantBase: ㄎㄨ → ㄍㄨ (ㄎ↔ㄍ)")
    func testNearConsonantKuGu() {
      #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄎㄨ") == "ㄍㄨ")
    }

    @Test("nearConsonantBase: ㄦ → nil（零聲母無近音聲母）")
    func testNearConsonantErNil() {
      #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄦ") == nil)
    }

    @Test("nearConsonantBase: ㄅ 系列 → nil（ㄅ不在白名單）")
    func testNearConsonantBoNil() {
      #expect(SimilarPhoneticRules.nearConsonantBase(for: "ㄅㄛ") == nil)
    }
  }
  ```

- [ ] **Step 2.2: Run tests to confirm they fail (type not found)**

  ```bash
  swift test --package-path ./Packages/vChewing_Typewriter --filter SimilarPhoneticRulesTests 2>&1 | tail -10
  ```
  Expected: compile error "cannot find type 'SimilarPhoneticRules'"

- [ ] **Step 2.3: Create `SimilarPhoneticRules.swift`**

  ```swift
  // (c) 2021 and onwards The vChewing Project (MIT-NTL License).
  // ====================
  // This code is released under the MIT license (SPDX-License-Identifier: MIT)
  // ... with NTL restriction stating that:
  // No trademark license is granted to use the trade names, trademarks, service
  // marks, or product names of Contributor, except as required to fulfill notice
  // requirements defined in MIT License.

  // MARK: - SimilarPhoneticRules

  /// 近音規則表：聲母對、韻母對以及注音展開工具函式。
  /// 所有函式均為 nonisolated pure functions，可在任意 actor context 呼叫。
  public enum SimilarPhoneticRules {

    // MARK: - 聲調展開

    /// 五個聲調標記：一聲（無標記）、二聲、三聲、四聲、輕聲。
    public static let allToneMarkers: [String] = ["", "ˊ", "ˇ", "ˋ", "˙"]

    /// 將注音字串拆分為「無聲調的基底」與「聲調標記」。
    /// - Parameter phonetic: 含聲調的注音字串，如 "ㄘㄢˊ"。
    /// - Returns: (base, tone)，例如 ("ㄘㄢ", "ˊ")。一聲 tone = ""。
    public static func splitTone(_ phonetic: String) -> (base: String, tone: String) {
      let toneSet: Set<Character> = ["ˊ", "ˇ", "ˋ", "˙"]
      if let last = phonetic.last, toneSet.contains(last) {
        return (String(phonetic.dropLast()), String(last))
      }
      return (phonetic, "")
    }

    /// 給定一個注音（含原聲調），返回同一基底的全部五個聲調版本，原聲調版本排第一。
    /// - Parameter phonetic: 原始注音（如 "ㄇㄡˊ"）。
    /// - Returns: 五個版本，原聲調第一。
    public static func allReadings(of phonetic: String) -> [String] {
      let (base, originalTone) = splitTone(phonetic)
      var result: [String] = [phonetic]
      for tone in allToneMarkers {
        guard tone != originalTone else { continue }
        result.append(base + tone)
      }
      return result
    }

    // MARK: - 聲母集合

    /// 注音聲母集合（用於判斷是否有聲母）。
    private static let consonants: Set<Character> = Set(
      "ㄅㄆㄇㄈㄉㄊㄋㄌㄍㄎㄏㄐㄑㄒㄓㄔㄕㄖㄗㄘㄙ"
    )

    /// 將注音基底（無聲調）拆分為「聲母」與「其餘（介音+韻母）」。
    /// - Parameter base: 無聲調注音基底，如 "ㄘㄢ"、"ㄧㄣ"（無聲母）。
    /// - Returns: (consonant, remainder)，如 ("ㄘ", "ㄢ") 或 ("", "ㄧㄣ")。
    static func splitConsonant(from base: String) -> (consonant: String, remainder: String) {
      guard let first = base.first, consonants.contains(first) else {
        return ("", base)
      }
      return (String(first), String(base.dropFirst()))
    }

    // MARK: - 近音聲母對（白名單制）

    /// 近音聲母對映表。僅白名單內的聲母才有近音聲母。
    /// ㄅㄆㄇㄈ（唇音）、ㄐㄑㄒ（舌面音）、ㄦ（特殊）均無近音聲母。
    private static let consonantPairMap: [String: String] = [
      "ㄓ": "ㄗ", "ㄗ": "ㄓ",
      "ㄔ": "ㄘ", "ㄘ": "ㄔ",
      "ㄕ": "ㄙ", "ㄙ": "ㄕ",
      "ㄋ": "ㄌ", "ㄌ": "ㄋ",
      "ㄈ": "ㄏ", "ㄏ": "ㄈ",
      "ㄎ": "ㄍ", "ㄍ": "ㄎ",
    ]

    /// 給定無聲調基底，返回近音聲母替換後的基底（無聲調）。
    /// 若聲母不在白名單或為零聲母，返回 nil。
    /// - Parameter base: 無聲調注音基底，如 "ㄘㄢ"。
    /// - Returns: 近音聲母版本，如 "ㄔㄢ"；若無近音聲母則 nil。
    public static func nearConsonantBase(for base: String) -> String? {
      let (consonant, remainder) = splitConsonant(from: base)
      guard !consonant.isEmpty else { return nil } // 零聲母無近音聲母
      guard let nearConsonant = consonantPairMap[consonant] else { return nil }
      return nearConsonant + remainder
    }

    // MARK: - 近音韻母對

    /// 近音韻母對映表。Key 為「介音+韻母」部分（聲母已去除）。
    /// 長的要先比對（如 "ㄧㄣ" 先於 "ㄣ"），避免短的誤比對。
    private static let vowelPairs: [(String, String)] = [
      ("ㄧㄣ", "ㄧㄥ"), ("ㄧㄥ", "ㄧㄣ"),
      ("ㄨㄣ", "ㄨㄥ"), ("ㄨㄥ", "ㄨㄣ"),
      ("ㄣ", "ㄥ"), ("ㄥ", "ㄣ"),
      ("ㄢ", "ㄤ"), ("ㄤ", "ㄢ"),
      ("ㄡ", "ㄛ"), ("ㄛ", "ㄡ"),
    ]

    /// 給定無聲調基底，返回近音韻母替換後的基底（無聲調）。
    /// 若韻母部分不在韻母對映表中，返回 nil。
    /// - Parameter base: 無聲調注音基底，如 "ㄇㄡ"、"ㄙㄨㄣ"、"ㄧㄣ"（無聲母）。
    /// - Returns: 近音韻母版本，如 "ㄇㄛ"、"ㄙㄨㄥ"；若無近音韻母則 nil。
    public static func nearVowelBase(for base: String) -> String? {
      let (consonant, remainder) = splitConsonant(from: base)
      for (vowelA, vowelB) in vowelPairs where remainder.hasSuffix(vowelA) {
        // 替換 remainder 尾部的 vowelA 為 vowelB
        let prefix = String(remainder.dropLast(vowelA.count))
        return consonant + prefix + vowelB
      }
      return nil
    }
  }
  ```

- [ ] **Step 2.4: Run tests to confirm they pass**

  ```bash
  swift test --package-path ./Packages/vChewing_Typewriter --filter SimilarPhoneticRulesTests 2>&1 | tail -15
  ```
  Expected: all tests PASS.

- [ ] **Step 2.5: Commit**

  ```bash
  git add Packages/vChewing_Typewriter/Sources/Typewriter/SimilarPhonetic/SimilarPhoneticRules.swift \
          Packages/vChewing_Typewriter/Tests/TypewriterTests/SimilarPhoneticTests.swift
  git commit -m "Typewriter // SimilarPhoneticRules: Add consonant/vowel near-sound pair tables and phonetic expansion logic."
  ```

---

## Task 3 — Implement `SimilarPhoneticHandler.swift` and Tests

**Files:**
- Create: `Packages/vChewing_Typewriter/Sources/Typewriter/SimilarPhonetic/SimilarPhoneticHandler.swift`
- Modify: `Packages/vChewing_Typewriter/Tests/TypewriterTests/SimilarPhoneticTests.swift` (add new suite)

- [ ] **Step 3.1: Add handler tests to `SimilarPhoneticTests.swift`**

  Append a new `@Suite("SimilarPhoneticHandler")` to the file.  These tests use `LMAssemblyMaterials4Tests` (already a test dependency) to query the real LM, so candidates will be real characters:

  ```swift
  import LangModelAssembly
  import LMAssemblyMaterials4Tests

  @Suite("SimilarPhoneticHandler")
  struct SimilarPhoneticHandlerTests {

    private func makeLM() -> LMAssembly.LMInstantiator {
      let lm = LMAssembly.LMInstantiator()
      lm.loadDefaultResources()  // loads bundled test dictionary
      return lm
    }

    @Test("buildRows(ㄅㄛ): 5列，第一列藍底，無近音聲母/韻母")
    func testBuildRowsBo() {
      let lm = makeLM()
      let rows = SimilarPhoneticHandler.buildRows(for: "ㄅㄛ", lm: lm)
      // First row = exact phonetic = blue row
      #expect(rows.first?.phonetic == "ㄅㄛ")
      // ㄅ has no near-consonant; ㄛ has no near-vowel → only exact 5 tones (minus empty ones)
      let phoneticSet = Set(rows.map(\.phonetic))
      #expect(!phoneticSet.contains(where: { $0.hasPrefix("ㄆ") || $0.hasPrefix("ㄇ") }))
      // All rows have at least 1 candidate
      #expect(rows.allSatisfy { !$0.candidates.isEmpty })
    }

    @Test("buildRows(ㄇㄡˊ): 第一列 ㄇㄡˊ，包含 ㄇㄛ 系列（ㄡ↔ㄛ 近音韻母）")
    func testBuildRowsMouSecondTone() {
      let lm = makeLM()
      let rows = SimilarPhoneticHandler.buildRows(for: "ㄇㄡˊ", lm: lm)
      #expect(rows.first?.phonetic == "ㄇㄡˊ")
      let phoneticSet = Set(rows.map(\.phonetic))
      // Should contain some ㄇㄛ variant
      #expect(phoneticSet.contains(where: { $0.hasPrefix("ㄇㄛ") }))
      // All rows non-empty
      #expect(rows.allSatisfy { !$0.candidates.isEmpty })
    }

    @Test("buildRows(ㄘㄢ): 第一列 ㄘㄢ，包含 ㄗㄢ 系列（ㄘ↔ㄗ 近音聲母）")
    func testBuildRowsCan() {
      let lm = makeLM()
      let rows = SimilarPhoneticHandler.buildRows(for: "ㄘㄢ", lm: lm)
      #expect(rows.first?.phonetic == "ㄘㄢ")
      let phoneticSet = Set(rows.map(\.phonetic))
      #expect(phoneticSet.contains(where: { $0.hasPrefix("ㄗㄢ") }))
      #expect(rows.allSatisfy { !$0.candidates.isEmpty })
    }

    @Test("buildRows(ㄦˊ): 無近音聲母列（ㄦ 為零聲母，不在白名單）")
    func testBuildRowsEr() {
      let lm = makeLM()
      let rows = SimilarPhoneticHandler.buildRows(for: "ㄦˊ", lm: lm)
      #expect(rows.first?.phonetic == "ㄦˊ")
      // No near-consonant rows
      let phoneticSet = Set(rows.map(\.phonetic))
      // ㄦ has no near-consonant (zero-onset), all rows must start with ㄦ
      #expect(phoneticSet.allSatisfy { $0.hasPrefix("ㄦ") })
    }

    @Test("buildRows: 無候選字的讀音不出現在結果中")
    func testBuildRowsEmptyOmitted() {
      let lm = makeLM()
      // 使用 ㄎㄨˇ：只有少數聲調有候選字
      let rows = SimilarPhoneticHandler.buildRows(for: "ㄎㄨˇ", lm: lm)
      // All returned rows must have at least 1 candidate
      #expect(rows.allSatisfy { !$0.candidates.isEmpty })
      // First row = ㄎㄨˇ
      #expect(rows.first?.phonetic == "ㄎㄨˇ")
    }
  }
  ```

  > **Note:** If `loadDefaultResources()` is not the correct API, check the existing `InputHandlerTests_Basics.swift` for how the LM is initialised in tests, and use the same pattern.

- [ ] **Step 3.2: Run tests to confirm `SimilarPhoneticHandler` tests fail**

  ```bash
  swift test --package-path ./Packages/vChewing_Typewriter --filter SimilarPhoneticHandlerTests 2>&1 | tail -10
  ```
  Expected: compile error "cannot find type 'SimilarPhoneticHandler'"

- [ ] **Step 3.3: Create `SimilarPhoneticHandler.swift`**

  ```swift
  // (c) 2021 and onwards The vChewing Project (MIT-NTL License).
  // ====================
  // This code is released under the MIT license (SPDX-License-Identifier: MIT)
  // ... with NTL restriction stating that:
  // No trademark license is granted to use the trade names, trademarks, service
  // marks, or product names of Contributor, except as required to fulfill notice
  // requirements defined in MIT License.

  import LangModelAssembly
  import Shared

  // MARK: - SimilarPhoneticHandler

  /// 近音表建立器。給定一個注音讀音，查詢詞庫並產生排列好的 `[SimilarPhoneticRow]`。
  public enum SimilarPhoneticHandler {

    /// 給定一個注音讀音（含聲調），建立排列好的近音表列陣列。
    ///
    /// 排列順序：
    /// 1. 精確音（原聲調）← 藍底，固定第一列
    /// 2. 精確音其他聲調（1→2→3→4→˙，跳過原聲調）
    /// 3. 近音韻母各聲調（1→2→3→4→˙）
    /// 4. 近音聲母各聲調（1→2→3→4→˙）
    ///
    /// 無候選字的讀音整列省略。
    ///
    /// - Parameters:
    ///   - phonetic: 原始注音讀音（如 "ㄘㄢ"、"ㄇㄡˊ"）。
    ///   - lm: 詞庫查詢物件。
    /// - Returns: 排列好的近音表列，第一列為藍底列（原聲調）。若詞庫查不到任何候選則返回空陣列。
    public static func buildRows(
      for phonetic: String,
      lm: LMAssembly.LMInstantiator
    ) -> [SimilarPhoneticRow] {
      let (base, _) = SimilarPhoneticRules.splitTone(phonetic)

      // Step 1: 精確音各聲調（原聲調先、其餘依序）
      var orderedReadings: [String] = SimilarPhoneticRules.allReadings(of: phonetic)

      // Step 2: 近音韻母各聲調
      if let nearVowelBase = SimilarPhoneticRules.nearVowelBase(for: base) {
        orderedReadings += SimilarPhoneticRules.allToneMarkers.map { nearVowelBase + $0 }
      }

      // Step 3: 近音聲母各聲調
      if let nearConsonantBase = SimilarPhoneticRules.nearConsonantBase(for: base) {
        orderedReadings += SimilarPhoneticRules.allToneMarkers.map { nearConsonantBase + $0 }
      }

      // Step 4: 查詢詞庫，過濾空列，組成結果
      var rows: [SimilarPhoneticRow] = []
      var seenPhonetics: Set<String> = []
      for reading in orderedReadings {
        guard !seenPhonetics.contains(reading) else { continue }
        seenPhonetics.insert(reading)
        let candidates = lm.unigramsFor(keyArray: [reading]).map(\.value)
        guard !candidates.isEmpty else { continue }
        rows.append(SimilarPhoneticRow(phonetic: reading, candidates: candidates))
      }

      return rows
    }
  }
  ```

- [ ] **Step 3.4: Check how LM is initialised in existing tests (reference step)**

  ```bash
  grep -n "LMInstantiator\|loadDefault\|lmInstantiator" \
    Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Basics.swift | head -20
  ```
  If the LM init pattern differs from `loadDefaultResources()`, update the test helper in Step 3.1 accordingly before running.

- [ ] **Step 3.5: Run handler tests**

  ```bash
  swift test --package-path ./Packages/vChewing_Typewriter --filter SimilarPhoneticHandlerTests 2>&1 | tail -20
  ```
  Expected: all tests PASS.

- [ ] **Step 3.6: Commit**

  ```bash
  git add Packages/vChewing_Typewriter/Sources/Typewriter/SimilarPhonetic/SimilarPhoneticHandler.swift \
          Packages/vChewing_Typewriter/Tests/TypewriterTests/SimilarPhoneticTests.swift
  git commit -m "Typewriter // SimilarPhoneticHandler: Add row builder with LM query and tone expansion."
  ```

---

## Task 4 — Implement `ofSimilarPhonetic` IMEState Constructor

**Files:**
- Modify: `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/IMEState.swift`
- Modify: `Packages/vChewing_Typewriter/Tests/TypewriterTests/TestComponents/MockedInputHandlerAndStates.swift`

- [ ] **Step 4.1: Implement `ofSimilarPhonetic` in `IMEState.swift`**

  After `ofNumberInput` (after line 199), still inside `extension IMEStateProtocol`:

  ```swift
  /// 近音表選字模式的狀態。
  /// - Parameters:
  ///   - rows: 近音表各列資料（第一列為藍底列）。
  ///   - selectedRow: 目前藍底列的索引（預設 0）。
  ///   - displayTextSegments: 組字區的文字段落（與 ofInputting 相同）。
  ///   - cursor: 組字區游標位置。
  public static func ofSimilarPhonetic(
    rows: [SimilarPhoneticRow],
    selectedRow: Int,
    displayTextSegments: [String],
    cursor: Int
  ) -> IMEState {
    var result = IMEState(displayTextSegments: displayTextSegments, cursor: cursor)
    result.type = .ofSimilarPhonetic
    result.data.similarPhoneticRows = rows
    result.data.selectedSimilarPhoneticRow = max(0, min(selectedRow, rows.count - 1))
    return result
  }
  ```

- [ ] **Step 4.2: Add `ofSimilarPhonetic` to `MockIMEState` in test components**

  After `ofNumberInput` in `MockedInputHandlerAndStates.swift` (after line 149):

  ```swift
  public static func ofSimilarPhonetic(
    rows: [SimilarPhoneticRow],
    selectedRow: Int,
    displayTextSegments: [String],
    cursor: Int
  ) -> MockIMEState {
    var result = MockIMEState(type: .ofSimilarPhonetic)
    result.data.similarPhoneticRows = rows
    result.data.selectedSimilarPhoneticRow = max(0, min(selectedRow, rows.count - 1))
    result.data.displayTextSegments = displayTextSegments
    result.data.cursor = cursor
    return result
  }
  ```

- [ ] **Step 4.3: Build Typewriter package to verify no regressions**

  ```bash
  swift build --package-path ./Packages/vChewing_Typewriter 2>&1 | tail -5
  ```
  Expected: BUILD SUCCEEDED.

- [ ] **Step 4.4: Commit**

  ```bash
  git add Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/IMEState.swift \
          Packages/vChewing_Typewriter/Tests/TypewriterTests/TestComponents/MockedInputHandlerAndStates.swift
  git commit -m "MainAssembly // IMEState: Implement ofSimilarPhonetic constructor."
  ```

---

## Task 5 — `SimilarPhoneticUIProtocol`, `SessionUI` and `SimilarPhoneticUI`

**Files:**
- Modify: `Packages/vChewing_Shared/Sources/Shared/Protocols/SessionUIProtocol.swift`
- Modify: `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/SessionUI.swift`
- Create: `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SimilarPhonetic/SimilarPhoneticUI.swift`

- [ ] **Step 5.1: Add `SimilarPhoneticUIProtocol` to `SessionUIProtocol.swift`**

  Append at end of file:

  ```swift
  // MARK: - SimilarPhoneticUIProtocol

  public protocol SimilarPhoneticUIProtocol: AnyObject {
    /// 顯示近音表視窗，依照 state 的 `similarPhoneticRows` 和 `selectedSimilarPhoneticRow` 渲染。
    /// - Parameters:
    ///   - state: 含有近音表資料的 `ofSimilarPhonetic` 狀態。
    ///   - point: 視窗顯示的基準點（組字區頂端左側）。
    func show(state: some IMEStateProtocol, at point: CGPoint)
    /// 更新近音表顯示（列選擇變動時呼叫，不需要重定位視窗）。
    func update(state: some IMEStateProtocol)
    /// 隱藏視窗。
    func hide()
  }
  ```

- [ ] **Step 5.2: Add `similarPhoneticUI` to `SessionUIProtocol`**

  In `SessionUIProtocol`, after `candidateUI` declaration (line 21):

  ```swift
  var similarPhoneticUI: (any SimilarPhoneticUIProtocol)? { get }
  ```

- [ ] **Step 5.3: Create `SimilarPhoneticUI.swift`**

  This is the AppKit implementation. The window uses `NSPanel` (floating, no title bar), draws a fixed-width monospace table. The design follows the dark-theme UI shown in the spec screenshots.

  ```swift
  // (c) 2021 and onwards The vChewing Project (MIT-NTL License).
  // ====================
  // This code is released under the MIT license (SPDX-License-Identifier: MIT)
  // ... with NTL restriction stating that:
  // No trademark license is granted to use the trade names, trademarks, service
  // marks, or product names of Contributor, except as required to fulfill notice
  // requirements defined in MIT License.

  #if canImport(Darwin)
    import AppKit
    import Shared

    // MARK: - SimilarPhoneticUI

    /// 近音表浮動視窗。顯示二維近音表格，藍底高亮當前選中列。
    public final class SimilarPhoneticUI: NSObject, SimilarPhoneticUIProtocol {

      // MARK: - Layout constants

      private let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
      private let columnWidth: CGFloat = 22
      private let phoneticColumnWidth: CGFloat = 64
      private let rowHeight: CGFloat = 22
      private let headerHeight: CGFloat = 22
      private let windowPadding: CGFloat = 6
      private let maxColumns = 8

      // MARK: - Window

      private lazy var panel: NSPanel = {
        let p = NSPanel(
          contentRect: .zero,
          styleMask: [.nonactivatingPanel, .borderless],
          backing: .buffered,
          defer: false
        )
        p.level = .floating
        p.backgroundColor = .clear
        p.isOpaque = false
        p.hasShadow = true
        return p
      }()

      private lazy var contentView: SimilarPhoneticContentView = {
        let v = SimilarPhoneticContentView()
        v.font = self.font
        v.columnWidth = self.columnWidth
        v.phoneticColumnWidth = self.phoneticColumnWidth
        v.rowHeight = self.rowHeight
        v.headerHeight = self.headerHeight
        v.windowPadding = self.windowPadding
        v.maxColumns = self.maxColumns
        return v
      }()

      public override init() {
        super.init()
        panel.contentView = contentView
      }

      // MARK: - SimilarPhoneticUIProtocol

      public func show(state: some IMEStateProtocol, at point: CGPoint) {
        guard state.type == .ofSimilarPhonetic else { return }
        contentView.rows = state.data.similarPhoneticRows
        contentView.selectedRow = state.data.selectedSimilarPhoneticRow
        contentView.needsDisplay = true

        let size = contentView.intrinsicContentSize
        let origin = NSPoint(x: point.x, y: point.y - size.height - 4)
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFront(nil)
      }

      public func update(state: some IMEStateProtocol) {
        guard state.type == .ofSimilarPhonetic else { return }
        contentView.rows = state.data.similarPhoneticRows
        contentView.selectedRow = state.data.selectedSimilarPhoneticRow
        contentView.needsDisplay = true
        // resize if row count changed (shouldn't happen in normal navigation, but safe)
        let size = contentView.intrinsicContentSize
        var frame = panel.frame
        frame.size = size
        panel.setFrame(frame, display: true)
      }

      public func hide() {
        panel.orderOut(nil)
      }
    }

    // MARK: - SimilarPhoneticContentView

    /// 近音表的內容繪製視圖。
    private final class SimilarPhoneticContentView: NSView {

      var rows: [SimilarPhoneticRow] = []
      var selectedRow: Int = 0
      var font: NSFont = .monospacedSystemFont(ofSize: 14, weight: .regular)
      var columnWidth: CGFloat = 22
      var phoneticColumnWidth: CGFloat = 64
      var rowHeight: CGFloat = 22
      var headerHeight: CGFloat = 22
      var windowPadding: CGFloat = 6
      var maxColumns: Int = 8

      // MARK: - Size

      private var totalWidth: CGFloat {
        windowPadding * 2 + phoneticColumnWidth + columnWidth * CGFloat(maxColumns) + columnWidth
        // +columnWidth for the `>` indicator slot
      }

      private var totalHeight: CGFloat {
        windowPadding * 2 + headerHeight + rowHeight * CGFloat(rows.count)
      }

      var intrinsicContentSize: NSSize {
        NSSize(width: totalWidth, height: totalHeight)
      }

      // MARK: - Colors & Attributes

      private let bgColor = NSColor(white: 0.12, alpha: 0.95)
      private let headerBgColor = NSColor(white: 0.18, alpha: 1)
      private let selectedRowColor = NSColor.systemBlue
      private let normalTextColor = NSColor.white
      private let dimTextColor = NSColor(white: 0.6, alpha: 1)
      private let headerNumberColor = NSColor(white: 0.7, alpha: 1)

      private var textAttrs: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: normalTextColor]
      }

      private var dimTextAttrs: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: dimTextColor]
      }

      private var headerNumberAttrs: [NSAttributedString.Key: Any] {
        [.font: font, .foregroundColor: headerNumberColor]
      }

      // MARK: - Drawing

      override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        // Background
        ctx.setFillColor(bgColor.cgColor)
        ctx.fill(bounds)

        let pad = windowPadding

        // Header row background
        let headerRect = CGRect(x: 0, y: bounds.height - pad - headerHeight, width: bounds.width, height: headerHeight)
        ctx.setFillColor(headerBgColor.cgColor)
        ctx.fill(headerRect)

        // Header: "近音表" label on left
        let headerLabelX = pad
        let headerLabelY = bounds.height - pad - headerHeight
        drawText("近音表", at: CGPoint(x: headerLabelX, y: headerLabelY), attrs: textAttrs, in: ctx)

        // Header: 1–8 column numbers aligned with candidate columns
        for col in 1 ... maxColumns {
          let x = pad + phoneticColumnWidth + columnWidth * CGFloat(col - 1)
          let y = bounds.height - pad - headerHeight
          drawText("\(col)", at: CGPoint(x: x, y: y), attrs: headerNumberAttrs, in: ctx)
        }

        // Data rows
        for (rowIdx, row) in rows.enumerated() {
          let y = bounds.height - pad - headerHeight - rowHeight * CGFloat(rowIdx + 1)
          let rowRect = CGRect(x: 0, y: y, width: bounds.width, height: rowHeight)

          if rowIdx == selectedRow {
            ctx.setFillColor(selectedRowColor.cgColor)
            ctx.fill(rowRect)
          }

          // Phonetic label
          drawText(row.phonetic, at: CGPoint(x: pad, y: y), attrs: textAttrs, in: ctx)

          // Candidates on current page
          let pageCandidates = row.candidatesOnCurrentPage
          for (colIdx, char) in pageCandidates.enumerated() {
            let x = pad + phoneticColumnWidth + columnWidth * CGFloat(colIdx)
            drawText(char, at: CGPoint(x: x, y: y), attrs: textAttrs, in: ctx)
          }

          // `>` indicator
          if row.hasNextPage {
            let x = pad + phoneticColumnWidth + columnWidth * CGFloat(maxColumns)
            drawText(">", at: CGPoint(x: x, y: y), attrs: dimTextAttrs, in: ctx)
          }
        }
      }

      private func drawText(
        _ text: String, at point: CGPoint,
        attrs: [NSAttributedString.Key: Any], in ctx: CGContext
      ) {
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let line = CTLineCreateWithAttributedString(attrStr)
        ctx.saveGState()
        ctx.translateBy(x: point.x, y: point.y + 4) // +4 for baseline offset
        ctx.textMatrix = .identity
        CTLineDraw(line, ctx)
        ctx.restoreGState()
      }
    }
  #endif
  ```

- [ ] **Step 5.4: Add `similarPhoneticUI` to `SessionUI.swift`**

  In `SessionUI`, after `candidateUI` (after line 37):

  ```swift
  /// 近音表視窗的副本。
  public let similarPhoneticUI: (any SimilarPhoneticUIProtocol)? = SimilarPhoneticUI()
  ```

- [ ] **Step 5.5: Build MainAssembly4Darwin package**

  ```bash
  swift build --package-path ./Packages/vChewing_MainAssembly4Darwin 2>&1 | tail -10
  ```
  Expected: BUILD SUCCEEDED.

- [ ] **Step 5.6: Commit**

  ```bash
  git add Packages/vChewing_Shared/Sources/Shared/Protocols/SessionUIProtocol.swift \
          Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/SessionUI.swift \
          Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SimilarPhonetic/SimilarPhoneticUI.swift
  git commit -m "MainAssembly // SimilarPhoneticUI: Add 2D candidate table window with blue-highlight row."
  ```

---

## Task 6 — Wire `switchState` and `updateCompositionBufferDisplay`

**Files:**
- Modify: `Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_HandleStates.swift`

- [ ] **Step 6.1: Add `ofSimilarPhonetic` to `switchState`**

  In `switchState`, find the `case .ofAssociates, .ofCandidates, .ofSymbolTable, .ofNumberInput:` line (line 52) and extend it:

  Change:
  ```swift
  case .ofAssociates, .ofCandidates, .ofSymbolTable, .ofNumberInput:
    showTooltip(nil)
  ```
  To:
  ```swift
  case .ofAssociates, .ofCandidates, .ofSymbolTable, .ofNumberInput:
    showTooltip(nil)
  case .ofSimilarPhonetic:
    showTooltip(nil)
    ui?.similarPhoneticUI?.show(state: next, at: lineHeightRect(zeroCursor: true).origin)
  ```

  Also, to hide the UI when leaving `ofSimilarPhonetic`, add at the start of `switchState` (just before `let previous = state`):

  > **Note:** The existing `switchState` already calls `toggleCandidateUIVisibility(state.isCandidateContainer)` at the end. Since `ofSimilarPhonetic` has `isCandidateContainer = false`, the standard candidate window will NOT be shown — this is correct. We only need to explicitly hide `similarPhoneticUI` when transitioning away. Do this by adding a guard before the `let previous = state` line:

  After the debug logging block (after line 29), add:
  ```swift
  // 離開近音表狀態時，關閉浮動視窗。
  if state.type == .ofSimilarPhonetic, newState.type != .ofSimilarPhonetic {
    ui?.similarPhoneticUI?.hide()
  }
  ```

- [ ] **Step 6.2: Add `ofSimilarPhonetic` to `updateCompositionBufferDisplay`**

  Change:
  ```swift
  case .ofAssociates, .ofCandidates, .ofSymbolTable, .ofNumberInput: true
  ```
  To:
  ```swift
  case .ofAssociates, .ofCandidates, .ofSymbolTable, .ofNumberInput, .ofSimilarPhonetic: true
  ```

- [ ] **Step 6.3: Build to verify**

  ```bash
  swift build --package-path ./Packages/vChewing_MainAssembly4Darwin 2>&1 | tail -5
  ```
  Expected: BUILD SUCCEEDED.

- [ ] **Step 6.4: Commit**

  ```bash
  git add Packages/vChewing_MainAssembly4Darwin/Sources/MainAssembly4Darwin/SessionController/InputSession_HandleStates.swift
  git commit -m "MainAssembly // SessionCtl: Wire ofSimilarPhonetic into switchState and updateCompositionBufferDisplay."
  ```

---

## Task 7 — Implement `InputHandler_HandleSimilarPhonetic.swift`

**Files:**
- Create: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleSimilarPhonetic.swift`

- [ ] **Step 7.1: Create the file**

  ```swift
  // (c) 2021 and onwards The vChewing Project (MIT-NTL License).
  // ====================
  // This code is released under the MIT license (SPDX-License-Identifier: MIT)
  // ... with NTL restriction stating that:
  // No trademark license is granted to use the trade names, trademarks, service
  // marks, or product names of Contributor, except as required to fulfill notice
  // requirements defined in MIT License.

  import Shared

  // MARK: - 近音表按鍵處理

  extension InputHandlerProtocol {

    // MARK: - 近音表觸發（↑ 鍵）

    /// 偵測 ↑ 鍵，若條件符合則建立近音表並切換至 `ofSimilarPhonetic` 狀態。
    /// - Parameter input: 輸入訊號。
    /// - Returns: 是否已處理（consumed）。
    func triggerSimilarPhonetic(input: InputSignalProtocol) -> Bool {
      guard let session else { return false }
      // 只在水平模式的 ↑ 鍵觸發
      guard KeyCode(rawValue: input.keyCode) == .kUpArrow else { return false }
      guard !session.isVerticalTyping else { return false }
      // 無修飾鍵
      guard input.commonKeyModifierFlags.isEmpty else { return false }
      // 組字器非空，且注音槽/筆根槽為空（代表已有組好的字）
      guard !assembler.isEmpty, isComposerOrCalligrapherEmpty else { return false }
      // 取得游標前一字的注音讀音
      guard let (phonetic, _, _) = previousParsableReading else { return false }
      // 建立近音表
      let rows = SimilarPhoneticHandler.buildRows(for: phonetic, lm: currentLM)
      guard !rows.isEmpty else { return false }
      // 建立顯示用的 ofInputting 基底
      let inputtingState = generateStateOfInputting()
      let newState = State.ofSimilarPhonetic(
        rows: rows,
        selectedRow: 0,
        displayTextSegments: inputtingState.data.displayTextSegments,
        cursor: inputtingState.data.cursor
      )
      session.switchState(newState)
      return true
    }

    // MARK: - 近音表鍵盤導航

    /// 處理 `ofSimilarPhonetic` 狀態下的按鍵輸入。
    /// - Parameter input: 輸入訊號。
    /// - Returns: 是否已處理（consumed）。
    func handleSimilarPhoneticState(input: InputSignalProtocol) -> Bool {
      guard let session else { return false }
      guard session.state.type == .ofSimilarPhonetic else { return false }

      var rows = session.state.data.similarPhoneticRows
      let selectedRow = session.state.data.selectedSimilarPhoneticRow
      let displayTextSegments = session.state.data.displayTextSegments
      let cursor = session.state.data.cursor

      /// 更新選中列，重新發送狀態。
      func updateSelectedRow(_ newRow: Int) {
        let clamped = max(0, min(newRow, rows.count - 1))
        let newState = State.ofSimilarPhonetic(
          rows: rows,
          selectedRow: clamped,
          displayTextSegments: displayTextSegments,
          cursor: cursor
        )
        session.switchState(newState)
      }

      /// 取出選中列的第 n 個候選字（1-indexed），套用取代。
      func selectCandidate(at oneBased: Int) {
        guard rows.indices.contains(selectedRow) else { return }
        let row = rows[selectedRow]
        let pageStart = row.currentPage * SimilarPhoneticRow.pageSize
        let zeroIndex = pageStart + (oneBased - 1)
        guard row.candidates.indices.contains(zeroIndex) else {
          errorCallback?("SPC_OUT_OF_RANGE")
          return
        }
        let value = row.candidates[zeroIndex]
        applyNearPhoneticReplacement(newPhonetic: row.phonetic, value: value)
      }

      switch KeyCode(rawValue: input.keyCode) {
      case .kUpArrow:
        if selectedRow > 0 {
          updateSelectedRow(selectedRow - 1)
        } else {
          errorCallback?("SPC_AT_TOP")
        }
        return true

      case .kDownArrow:
        if selectedRow < rows.count - 1 {
          updateSelectedRow(selectedRow + 1)
        } else {
          errorCallback?("SPC_AT_BOTTOM")
        }
        return true

      case .kEscape:
        // 取消：回到原本的 ofInputting 狀態
        session.switchState(generateStateOfInputting())
        return true

      case .kCarriageReturn, .kLineFeed, .kSpace:
        // 確認：選取選中列的第一個候選字
        selectCandidate(at: 1)
        return true

      default: break
      }

      // 數字鍵 1–8：直接選取選中列對應位置的候選字
      if input.commonKeyModifierFlags.isEmpty,
         let numChar = input.text.first,
         let num = Int(String(numChar)), (1 ... 8).contains(num)
      {
        selectCandidate(at: num)
        return true
      }

      // 其他按鍵：不處理（攔截，避免穿透）
      return true
    }

    // MARK: - 近音字取代

    /// 將組字器中游標前一字取代為指定注音讀音與字值。
    ///
    /// 流程：
    /// 1. `assembler.dropKey(direction: .rear)` — 移除游標前一字的讀音鍵
    /// 2. `assembler.insertKey(newPhonetic)` — 插入新讀音鍵
    /// 3. `assemble()` — 重新組字
    /// 4. `assembler.overrideCandidate(...)` — 強制指定節點值
    /// 5. `assemble()` — 再次組字
    /// 6. 切換回 `ofInputting` 狀態
    ///
    /// - Parameters:
    ///   - newPhonetic: 新讀音（如 "ㄗㄢˊ"）。
    ///   - value: 選取的字（如 "參"）。
    func applyNearPhoneticReplacement(newPhonetic: String, value: String) {
      guard let session else { return }
      guard !assembler.isEmpty, assembler.cursor > 0 else { return }
      // Step 1: 直接呼叫 Megrez API（不用包裝版，我們不保留舊節點的手動覆寫）
      guard assembler.dropKey(direction: .rear) else { return }
      // Step 2: 插入新讀音
      guard assembler.insertKey(newPhonetic) else {
        // 回退：重組現有狀態
        assemble()
        session.switchState(generateStateOfInputting())
        return
      }
      // Step 3 & 4: 組字後強制指定節點
      assemble()
      _ = assembler.overrideCandidate(
        .init(keyArray: [newPhonetic], value: value),
        at: actualNodeCursorPosition,
        overrideType: .withSpecified,
        isExplicitlyOverridden: true,
        enforceRetokenization: false
      )
      // Step 5: 再次組字
      assemble()
      // Step 6: 回到輸入狀態
      session.switchState(generateStateOfInputting())
    }
  }
  ```

- [ ] **Step 7.2: Build Typewriter package**

  ```bash
  swift build --package-path ./Packages/vChewing_Typewriter 2>&1 | tail -10
  ```
  Expected: BUILD SUCCEEDED. Fix any compile errors (likely API name mismatches in `assembler.overrideCandidate`).

  > **Note on `assembler.overrideCandidate` signature:** Check `InputHandler_CoreProtocol.swift` line ~360 for the exact overload used (some overloads have `overrideType:`, others don't). Match the signature used in `consolidateNode`. If `overrideType:` parameter doesn't exist, use the simpler overload:
  > ```swift
  > _ = assembler.overrideCandidate(
  >   .init(keyArray: [newPhonetic], value: value),
  >   at: actualNodeCursorPosition,
  >   isExplicitlyOverridden: true,
  >   enforceRetokenization: false
  > )
  > ```

- [ ] **Step 7.3: Commit**

  ```bash
  git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleSimilarPhonetic.swift
  git commit -m "Typewriter // SimilarPhonetic: Add trigger, keyboard navigation, and candidate replacement logic."
  ```

---

## Task 8 — Wire `TriageInput`

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_TriageInput.swift`

- [ ] **Step 8.1: Add `ofSimilarPhonetic` to `triageByState`**

  In `triageByState`, after `case .ofNumberInput:` (line 139):

  ```swift
  case .ofSimilarPhonetic:
    return handleSimilarPhoneticState(input: input)
  ```

- [ ] **Step 8.2: Intercept `↑` key before `callCandidateState`**

  In the `case .ofEmpty, .ofInputting:` branch, find `// 手動呼叫選字窗。` (line 177) and insert **before** it:

  ```swift
  // 偵測 ↑ 鍵觸發近音表（優先於選字窗呼叫）。
  if triggerSimilarPhonetic(input: input) { return true }

  // 手動呼叫選字窗。
  if callCandidateState(input: input) { return true }
  ```

- [ ] **Step 8.3: Build and run all Typewriter tests**

  ```bash
  swift build --package-path ./Packages/vChewing_Typewriter 2>&1 | tail -5
  swift test --package-path ./Packages/vChewing_Typewriter 2>&1 | tail -20
  ```
  Expected: BUILD SUCCEEDED, all tests PASS.

- [ ] **Step 8.4: Commit**

  ```bash
  git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_TriageInput.swift
  git commit -m "Typewriter // InputHandler: Route ofSimilarPhonetic state and intercept up-arrow trigger."
  ```

---

## Task 9 — Full Build Verification

- [ ] **Step 9.1: Build the full project (debug)**

  ```bash
  make debug 2>&1 | tail -20
  ```
  Expected: BUILD SUCCEEDED with no new warnings.

- [ ] **Step 9.2: Run full test suite**

  ```bash
  swift test --package-path ./Packages/vChewing_Typewriter 2>&1 | tail -20
  ```
  Expected: all tests PASS.

- [ ] **Step 9.3: Manual smoke test checklist**

  Open the input method in a text editor and verify:
  - [ ] Type a few characters (e.g., "波") → press `↑` → near-phonetic table opens with ㄅㄛ blue-highlighted
  - [ ] Press `↓` → blue highlight moves to second row
  - [ ] Press number `1` → first candidate of selected row replaces original, table closes
  - [ ] Reopen table → press `Esc` → table closes, original character unchanged
  - [ ] Press `Enter` → first candidate of selected row replaces original
  - [ ] Empty composition buffer → press `↑` → nothing happens (no table)
  - [ ] Type "謀" → press `↑` → table opens, ㄇㄛ rows appear (ㄡ↔ㄛ near-vowel)
  - [ ] Type "餐" → press `↑` → table opens, ㄗㄢ rows appear (ㄘ↔ㄗ near-consonant)
  - [ ] Type "根" → press `↑` → table opens, ㄎ rows appear (ㄍ↔ㄎ near-consonant)

---

## Key API Reference

### `previousParsableReading`
```swift
// InputHandler_CoreProtocol.swift:600
var previousParsableReading: (String, String, Bool)? {
  // Returns (fullReading, readingWithoutTone, hasTone)
  // e.g. ("ㄘㄢ", "ㄘㄢ", false) or ("ㄇㄡˊ", "ㄇㄡ", true)
}
```

### Megrez Compositor APIs used
```swift
assembler.dropKey(direction: .rear) -> Bool   // removes key at cursor-1, cursor--
assembler.insertKey(_ key: String) -> Bool    // inserts key at cursor, cursor++
assembler.overrideCandidate(_, at:, isExplicitlyOverridden:, enforceRetokenization:) -> Bool
assembler.cursor    // current cursor position (Int)
assembler.isEmpty   // Bool
```

### LM query
```swift
currentLM.unigramsFor(keyArray: ["ㄘㄢ"])  // -> [Megrez.Unigram], sorted by frequency
// .map(\.value) gives [String] of characters
```

### State data access
```swift
session.state.data.similarPhoneticRows        // [SimilarPhoneticRow]
session.state.data.selectedSimilarPhoneticRow // Int
```
