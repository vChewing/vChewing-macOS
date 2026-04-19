# Upstream Merge 4.3.5/4.3.6 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Merge upstream vChewing/vChewing-macOS 4.3.5/4.3.6 into the fork, resolve 6 conflicts while preserving all fork-specific features, bump version to 2026.04.19, run tests, and write release notes.

**Architecture:** Use `git merge --no-ff upstream/main` to start, resolve conflicts per the rules in AGENTS.md (fork features take priority, upstream rawDisplayTextSegments tracking is added on top), keep date-based versioning scheme, run `swift test` to verify, then commit with release notes in README.md.

**Tech Stack:** Swift 6.2, Swift Testing framework, git, vChewing_Typewriter / vChewing_Shared / vChewing_Hotenka SPM packages.

---

## Upstream Changes Summary (for release notes)

From `a57eb5ee` → `a3c8ddd9` (11 commits, upstream 4.3.5 + 4.3.6):

| Commit | Content |
|--------|---------|
| `a57eb5ee` | IMEStateData: Add `rawDisplayTextSegments`/`rawDisplayedText` — prevent BPMFVS VS characters from leaking into marking-state `userPhraseKVPair` |
| `e611ca61` | LMAssembly: Single-kanji CNS-filtered unigrams now demoted (score -9.5) instead of removed; add CNS filter description i18n |
| `80b6106f` | Hotenka v2.0.0: Replace SQLite/JSON/Plist backend with StringMap format (massive perf/size improvement) |
| `22044a6d` | Update CNS11643 timestamp to 2026-03-18 |
| `0e9fc3db` | Patch `Scripts/vchewing-update.swift` |
| `0597ad37` | LMAssembly: Remove useless test case |
| `77810ce3` | DictionaryData 20260416 |
| `3ee58323` | VersionUp 4.3.5 (upstream versioning — we keep 2026.04.19) |
| `b2182f80` | BookmarkMgr: Fix hang when sandboxed iCloud Drive folder is open |
| `26549c8d` | Uninstaller: Improve UX (new uninstall confirmation flow, i18n strings) |
| `a3c8ddd9` | VersionUp 4.3.6 (upstream versioning — we keep 2026.04.19) |

---

## Conflict Files Map

| File | Our Change | Upstream Change | Resolution |
|------|-----------|----------------|-----------|
| `InputHandler_HandleStates.swift` | Added `committableDisplayText()` | Added `rawDisplayTextSegmentsIfNeeded`, `insertReadingIntoSegments()`, `rawDisplayTextSegments` tracking in generate functions | Keep both; merge `rawDisplayTextSegmentsIfNeeded` to include frozenSegments |
| `InputHandlerTests_Cases1.swift` | Added `test_IH103C` | Added `test_IH103D` + `test_IH103E` | Keep all three tests |
| `Release-Version.plist` | `2026.04.13` | `4.3.6` | Change to `2026.04.19` |
| `Update-Info.plist` | `2026.04.13` | `4.3.6` | Change to `2026.04.19` |
| `vChewing.pkgproj` | `2026.04.13` | `4.3.6` | Change to `2026.04.19` |
| `vChewing.xcodeproj/project.pbxproj` | `20260413` | `4360` | Change to `20260419` |

---

## Task 1: Start the Merge

**Files:** git working tree

- [ ] **Step 1: Begin merge**

```bash
git merge --no-commit --no-ff upstream/main
```

Expected output ends with: `Automatic merge failed; fix conflicts and then commit the result.`

Six files will show as conflicted in `git status`:
- `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift`
- `Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Cases1.swift`
- `Release-Version.plist`
- `Update-Info.plist`
- `vChewing.pkgproj`
- `vChewing.xcodeproj/project.pbxproj`

---

## Task 2: Resolve `InputHandler_HandleStates.swift`

**Files:**
- Modify: `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift`

This is the most complex conflict. Upstream adds `rawDisplayTextSegments` tracking to `generateStateOfInputting()`. Our fork adds `committableDisplayText()` and SmartSwitch cursor-offset logic. The resolved file must have all of:
1. Our SmartSwitch `frozenSegments` prepending in `generateStateOfInputting()`
2. Our `frozenDisplayText.count` cursor offset
3. Upstream's `rawSegments` tracking (with frozenSegments incorporated)
4. Our `committableDisplayText()` function (intact)

- [ ] **Step 1: Resolve the conflict in `generateStateOfInputting()`**

Find the `<<<<<<< HEAD` conflict marker in the file. The merged `generateStateOfInputting()` body should look like this (replace the entire conflict block):

```swift
public func generateStateOfInputting(
  sansReading: Bool = false,
  guarded: Bool = false
)
  -> State {
  if isConsideredEmptyForNow, !guarded { return State.ofAbortion() }
  restoreBackupCursor() // 只要叫了 Inputting 狀態，就盡可能還原游標備份。
  var segHighlightedAt: Int?
  let handleAsCodePointInput = currentTypingMethod == .codePoint && !sansReading
  let handleAsRomanNumeralInput = currentTypingMethod == .romanNumerals && !sansReading
  var displayTextSegments: [String] = handleAsCodePointInput || handleAsRomanNumeralInput
    ? [strCodePointBuffer]
    : compositionBufferDisplayTextSegments(reflectBPMFVS: !sansReading)
  // 原始（未經 BPMFVS 投影）的文字片段。僅在 BPMFVS 投影啟用時才需要額外追蹤。
  var rawSegments: [String]? = (!handleAsCodePointInput && !handleAsRomanNumeralInput && !sansReading)
    ? rawDisplayTextSegmentsIfNeeded
    : nil
  // 若 smartSwitchState 有凍結段落，將其前置於顯示段落。
  if !smartSwitchState.frozenSegments.isEmpty {
    displayTextSegments = smartSwitchState.frozenSegments + displayTextSegments
  }
  var cursor = handleAsCodePointInput || handleAsRomanNumeralInput
    ? strCodePointBuffer.count + smartSwitchState.frozenDisplayText.count
    : convertCursorForDisplay(assembler.cursor) + smartSwitchState.frozenDisplayText.count
  let cursorSansReading = cursor
  // 先提出來讀音資料，減輕運算負擔。
  let noReading = sansReading || [.codePoint, .romanNumerals].contains(currentTypingMethod)
  let reading: String = noReading ? "" : readingForDisplay
  if !reading.isEmpty {
    var newDisplayTextSegments = [String]()
    var temporaryNode = ""
    var charCounter = 0
    for node in displayTextSegments {
      for char in node {
        if charCounter == cursor {
          newDisplayTextSegments.append(temporaryNode)
          temporaryNode = ""
          // 處理在組字區中間或者最後方插入游標的情形。
          segHighlightedAt = newDisplayTextSegments.count
          newDisplayTextSegments.append(reading)
        }
        temporaryNode += String(char)
        charCounter += 1
      }
      newDisplayTextSegments.append(temporaryNode)
      temporaryNode = ""
    }
    if newDisplayTextSegments == displayTextSegments {
      // 處理在組字區最前方插入游標的情形。
      segHighlightedAt = newDisplayTextSegments.count
      newDisplayTextSegments.append(reading)
    }
    displayTextSegments = newDisplayTextSegments
    cursor += reading.count
    // 同步將讀音插入到原始文字片段。
    if let raw = rawSegments {
      rawSegments = Self.insertReadingIntoSegments(
        in: raw,
        reading: reading,
        at: cursorSansReading
      )
    }
  }
  for i in 0 ..< displayTextSegments.count {
    displayTextSegments[i] = displayTextSegments[i].trimmingCharacters(in: .newlines)
  }
  if var raw = rawSegments {
    for i in 0 ..< raw.count {
      raw[i] = raw[i].trimmingCharacters(in: .newlines)
    }
    rawSegments = raw
  }
  /// 這裡生成準備要拿來回呼的「正在輸入」狀態。
  var result = State.ofInputting(
    displayTextSegments: displayTextSegments,
    cursor: cursor, highlightAt: segHighlightedAt
  )
  result.marker = cursorSansReading
  result.data.rawDisplayTextSegments = rawSegments
  /// 特殊情形，否則方向鍵事件無法正常攔截。
  if guarded, result.displayTextSegments.joined().isEmpty {
    result.data.displayTextSegments = [" "]
    result.cursor = 0
    result.marker = 0
  }
  return result
}
```

- [ ] **Step 2: Add `rawDisplayTextSegmentsIfNeeded` (upstream new computed var, with frozenSegments support)**

After `compositionBufferDisplayTextSegments()` and before `committableDisplayText()`, insert:

```swift
/// 當 BPMFVS 投影處於啟用狀態時，回傳原始（未投影）的組字區文字片段（含凍結段落前綴）。否則回傳 nil。
var rawDisplayTextSegmentsIfNeeded: [String]? {
  guard prefs.reflectBPMFVSInCompositionBuffer,
        prefs.specifyCmdOptCtrlEnterBehavior == 4
  else { return nil }
  let raw = assembler.assembledSentence.values
  guard !smartSwitchState.frozenSegments.isEmpty else { return raw }
  return smartSwitchState.frozenSegments + raw
}

/// 將讀音插入到文字片段陣列的指定游標位置。
static func insertReadingIntoSegments(
  in segments: [String],
  reading: String,
  at cursor: Int
)
  -> [String] {
  var newSegments = [String]()
  var temporaryNode = ""
  var charCounter = 0
  for node in segments {
    for char in node {
      if charCounter == cursor {
        newSegments.append(temporaryNode)
        temporaryNode = ""
        newSegments.append(reading)
      }
      temporaryNode += String(char)
      charCounter += 1
    }
    newSegments.append(temporaryNode)
    temporaryNode = ""
  }
  if newSegments == segments {
    newSegments.append(reading)
  }
  return newSegments
}
```

- [ ] **Step 3: Verify `committableDisplayText()` is still intact**

Check that `committableDisplayText()` (our fork function) is present and unchanged — it should start with:
```swift
/// 組字區可以投影成 BPMFVS 顯示，但一般遞交流程只能吃原始內容。
/// 此函式同時處理 SmartSwitch 的凍結段落與暫時英文模式，確保遞交內容完整。
public func committableDisplayText(sansReading: Bool = false) -> String {
  // 暫時英文模式：直接回傳凍結段落 + 英文緩衝，不經由組字區。
  if smartSwitchState.isTempEnglishMode {
```

- [ ] **Step 4: Check remaining conflict markers in HandleStates.swift for `generateStateOfMarking`**

Upstream also adds `marking.data.rawDisplayTextSegments = rawDisplayTextSegmentsIfNeeded` in several `generateStateOfMarking` call sites. These should auto-merge. Verify no `<<<<` markers remain:

```bash
grep -n "<<<<<<\|>>>>>>>" Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift
```

Expected: no output (no remaining conflict markers).

- [ ] **Step 5: Stage the resolved file**

```bash
git add Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift
```

---

## Task 3: Resolve `InputHandlerTests_Cases1.swift`

**Files:**
- Modify: `Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Cases1.swift`

- [ ] **Step 1: Locate the conflict — both sides added tests after `test_IH103B`**

The conflict region will look like:

```
<<<<<<< HEAD
  @Test
  func test_IH103C_ButKoBPMFVSPlainEnterCommitsRawText() throws { ... our test ... }

=======
  @Test
  func test_IH103D_ButKoBPMFVSMarkingStateDoesNotPollute() throws { ... upstream test ... }

  @Test
  func test_IH103E_ButKoBPMFVSCandidatePreviewKeepsRawStateInSync() throws { ... upstream test ... }
>>>>>>> upstream/main
```

Keep ALL THREE tests. The final order should be: `test_IH103C` (ours), then `test_IH103D`, then `test_IH103E` (upstream), then continue with `test_IH104`.

- [ ] **Step 2: Remove conflict markers, keep all three tests**

Delete the `<<<<<<< HEAD`, `=======`, and `>>>>>>> upstream/main` lines. Keep `test_IH103C`, `test_IH103D`, and `test_IH103E` all in the file, in that order.

- [ ] **Step 3: Verify no conflict markers remain**

```bash
grep -n "<<<<<<\|>>>>>>>" Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Cases1.swift
```

Expected: no output.

- [ ] **Step 4: Stage**

```bash
git add Packages/vChewing_Typewriter/Tests/TypewriterTests/InputHandlerTests_Cases1.swift
```

---

## Task 4: Resolve Version Files (4 files)

Per fork policy: always keep date-based versioning. Update to `2026.04.19` / `20260419`.

**Files:**
- Modify: `Release-Version.plist`
- Modify: `Update-Info.plist`
- Modify: `vChewing.pkgproj`
- Modify: `vChewing.xcodeproj/project.pbxproj`

- [ ] **Step 1: Resolve `Release-Version.plist`**

Find and remove conflict markers. Final content should be:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleShortVersionString</key>
	<string>2026.04.19</string>
	<key>CFBundleVersion</key>
	<string>20260419</string>
</dict>
</plist>
```

Stage: `git add Release-Version.plist`

- [ ] **Step 2: Resolve `Update-Info.plist`**

Keep fork version, update to 2026.04.19:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleShortVersionString</key>
	<string>2026.04.19</string>
	<key>CFBundleVersion</key>
	<string>20260419</string>
	<key>IsMainStreamDistro</key>
	<true/>
	<key>UpdateInfoEndpoint</key>
```
(Keep the rest of the file unchanged — only replace the version strings.)

Stage: `git add Update-Info.plist`

- [ ] **Step 3: Resolve `vChewing.pkgproj`**

Find the `<key>VERSION</key>` line and set its string value to `2026.04.19` (remove conflict markers).

Stage: `git add vChewing.pkgproj`

- [ ] **Step 4: Resolve `vChewing.xcodeproj/project.pbxproj`**

There are 4 occurrences of `CURRENT_PROJECT_VERSION` and 4 of `MARKETING_VERSION` in conflict. For each conflict block:
- `CURRENT_PROJECT_VERSION` → `20260419`
- `MARKETING_VERSION` → `2026.04.19`

Note: upstream introduced extra tab indentation in these fields (`\t\t\t\t\tCURRENT_PROJECT_VERSION`). Use our existing indentation style (`\t\t\t\tCURRENT_PROJECT_VERSION`).

Stage: `git add vChewing.xcodeproj/project.pbxproj`

---

## Task 5: Verify Merge State and Commit

**Files:** git working tree

- [ ] **Step 1: Check no conflict markers remain anywhere**

```bash
git diff --check
```

Expected: no output (no whitespace errors or conflict markers).

- [ ] **Step 2: Check all files staged**

```bash
git status
```

Expected: all modified files under "Changes to be committed", nothing in "Unmerged paths".

- [ ] **Step 3: Commit the merge**

```bash
git commit -m "$(cat <<'EOF'
Merge: Sync upstream 4.3.5 + 4.3.6 — rawDisplayTextSegments + Hotenka v2 + BookmarkMgr fix.

- IMEStateData: Add rawDisplayTextSegments / rawDisplayedText to prevent BPMFVS VS chars
  from leaking into marking-state userPhraseKVPair (upstream a57eb5ee).
- LMAssembly: Single-kanji CNS-filtered unigrams demoted (score -9.5) instead of removed (e611ca61).
- Hotenka v2.0.0: Replace SQLite/JSON/Plist backend with StringMap format (80b6106f).
- BookmarkMgr: Fix hang with sandboxed iCloud Drive folder (b2182f80).
- Uninstaller: Improve UX with confirmation flow (26549c8d).
- DictionaryData 20260416 + CNS timestamp 2026-03-18 (77810ce3, 22044a6d).
- Fork: rawDisplayTextSegmentsIfNeeded includes frozenSegments prefix for SmartSwitch compat.
- Fork: committableDisplayText() preserved intact.
- Fork: test_IH103C + upstream test_IH103D + test_IH103E all retained.
- Version bumped to 2026.04.19 (fork date scheme; upstream 4.3.5/4.3.6 not adopted).

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Run Tests

**Files:** none (test-only step)

- [ ] **Step 1: Run Typewriter tests (SmartSwitch + BPMFVS + merge)**

```bash
swift test --package-path ./Packages/vChewing_Typewriter
```

Expected: all tests pass (including `test_IH103C`, `test_IH103D`, `test_IH103E`, all SmartSwitch tests).

- [ ] **Step 2: If any test fails, investigate before proceeding**

Check the failure message. Likely causes:
- `committableDisplayText()` missing or signature changed → check Task 2 Step 3
- `rawDisplayTextSegmentsIfNeeded` returns wrong segments → check that frozenSegments are included
- Cursor offset wrong in raw segment insertion → `cursorSansReading` already includes `frozenDisplayText.count`

Do NOT proceed to Task 7 if tests fail.

---

## Task 7: Update Version in Remaining Files

Some files may have been auto-merged with upstream's `4.3.6` version strings (e.g., in `Package.swift` for VanguardLexicon). Check:

- [ ] **Step 1: Verify VanguardLexicon version**

```bash
grep -r "VanguardLexicon" Packages/vChewing_MainAssembly4Darwin/Package.swift
```

Expected: `exact: "4.3.4"` (what we merged before). The upstream may update to `4.3.4` — this is fine since it's the lexicon data version, not the app version.

---

## Task 8: Write Release Notes

**Files:**
- Modify: `README.md`

- [ ] **Step 1: Insert new release notes section in `README.md`**

Find the `## Changelog（個人修改版）` section and insert a new `### 2026.04.19` block BEFORE the existing `### 2026.04.14` entry:

```markdown
### 2026.04.19

#### 🔄 上游同步（upstream/main @ vChewing/vChewing-macOS — 4.3.5 + 4.3.6 GM）

- **IMEStateData — BPMFVS 標記模式污染修復**：新增 `rawDisplayTextSegments` / `rawDisplayedText` 機制。在啟用 BPMFVS 組字區即時反映時，標記模式（`ofMarking`）的使用者加詞操作（`userPhraseKVPair`）現在保證寫入原始漢字，不再含有 Unicode Variation Selector（`0xE0100–0xE01EF`）。新增測試 `test_IH103D_ButKoBPMFVSMarkingStateDoesNotPollute` 與 `test_IH103E_ButKoBPMFVSCandidatePreviewKeepsRawStateInSync` 驗證此行為。
- **LMAssembly — 全字庫單字過濾策略調整**：在繁體中文模式下啟用 CNS11643 讀音過濾時，單個漢字（keyArray.count == 1）的不合規 Unigram 改為將分數降至 -9.5（降權），而非直接濾除，避免罕用字完全消失。新增 CNS 過濾選項的 i18n 描述字串。
- **Hotenka v2.0.0 — 轉換字典後端升級**：將簡繁轉換字典後端從 SQLite / JSON / Plist 全面改為 `.stringmap` 純文字格式，大幅改善載入速度與套件體積。
- **BookmarkMgr — iCloud Drive 沙盒掛起修復**：修正在沙盒環境下開啟 iCloud Drive 資料夾時造成 App 掛起的問題（新增 BookmarkManager 測試案例）。
- **Uninstaller — 卸載流程 UX 改善**：新增卸載確認對話框流程，更新多語系字串（en / ja / zh-Hans / zh-Hant）。
- **字典資料更新**：`vChewing-VanguardLexicon` 資料日期升至 `20260416`；CNS11643 時間戳更新至 `2026-03-18`。
- `Scripts/vchewing-update.swift` 更新腳本修補。

**衝突處理**：`rawDisplayTextSegmentsIfNeeded` 合併 fork 的 `frozenSegments` 前綴支援（SmartSwitch 相容）；`committableDisplayText()` 完整保留；`test_IH103C`（fork）與上游 `test_IH103D`、`test_IH103E` 全數保留；版本號維持 fork 日期制（`2026.04.19 / 20260419`）。

---
```

- [ ] **Step 2: Commit the release notes**

```bash
git add README.md
git commit -m "$(cat <<'EOF'
Docs // README: Add 2026.04.19 release notes for upstream 4.3.5/4.3.6 merge.

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>
EOF
)"
```

---

## Self-Review Checklist

- [x] **Spec coverage**: merge + conflict resolution + tests + version bump + release notes — all covered in 8 tasks
- [x] **No placeholders**: all steps have explicit commands, file content, or code
- [x] **Type consistency**: `rawDisplayTextSegmentsIfNeeded` is consistent between Task 2 Step 2 (definition) and Task 2 Step 1 (usage in `generateStateOfInputting`)
- [x] **Fork feature protection**: `committableDisplayText()`, `frozenSegments`, `isTempEnglishMode` all preserved
- [x] **Version scheme**: all 4 version files set to `2026.04.19` / `20260419`
- [x] **Tests must pass before docs commit**: Task 6 gates Task 7/8
