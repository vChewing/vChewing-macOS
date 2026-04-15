# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

vChewing (唯音) is a macOS input method built with AppKit/IMKit in Swift, backed by statistical language models. Main work lives in `Packages/`. The Linux environment only builds `vChewing_Typewriter` and its dependencies.

> **IMPORTANT — Fork Policy**: This repository (`ThomasHsieh/vChewing-macOS`) is a personal fork of the upstream project (`vChewing/vChewing-macOS`). All commits, pushes, and pull requests **must target the fork** (`origin` → `ThomasHsieh/vChewing-macOS`). Never push to or open PRs against the upstream repository (`upstream` → `vChewing/vChewing-macOS`) unless the owner explicitly instructs you to do so.

## Prerequisites

Before running `make` commands, configure Xcode so builds land in the project folder:

1. **Derived Data**: Xcode → Settings → Locations → set "Derived Data" to **Relative to Workspace**
2. **Project build path**: File → Project Settings → Advanced → Custom → **Relative to Workspace**

Without this, `make` commands will fail to locate build artifacts.

## Build & Test Commands

```bash
# Build
make release          # Universal binary (arm64+x86_64), signed, sandboxed
make debug            # Single-arch debug build (faster iteration)
make archive          # Release + dSYMs + .xcarchive for distribution
make update           # Fetch/generate lexicon assets (first-time setup)
swift build -c debug  # SPM debug build (alternative, no app bundle)

# Install
make install-release  # Build release and open installer
make install-debug    # Build debug and open installer

# Test
swift test                                                    # All tests
make test                                                     # Same via Makefile
swift test --package-path ./Packages/vChewing_Typewriter      # Single package (Typewriter)
swift test --package-path ./Packages/vChewing_Tekkon          # Single package (Tekkon)
swift test --package-path ./Packages/vChewing_Megrez          # Single package (Megrez)
swift test --package-path ./Packages/vChewing_Typewriter --filter InputHandlerTests  # Single suite
swift test --package-path ./Packages/vChewing_Typewriter --filter "testCaseName"     # Single test
make spmLinuxTest-Typewriter                                  # Linux Docker test

# Lint & Format
make lint             # SwiftLint with autocorrect
make format           # SwiftFormat
make spmLintFormat    # Both, across all packages

# Clean
make clean            # Clean main build artifacts
make clean-spm        # Clean SPM cache
make gitclean         # Remove all untracked files (use with care)
```

## Architecture

### Module Map

| Module | Purpose |
|--------|---------|
| **vChewing_MainAssembly4Darwin** | IMK front-end, SessionCtl, UI bridges |
| **vChewing_Typewriter** | Typing FSM, InputHandler, Tekkon integration (Linux-compatible) |
| **vChewing_Megrez** | DAG-DP compositor (sentence assembler) |
| **vChewing_Tekkon** | Zhuyin/Bopomofo composer, keyboard parsers |
| **vChewing_LangModelAssembly** | LM facade, user phrases, perception override |
| **vChewing_OSFrameworkImpl** | AppKit Result Builder DSL for UI |
| **vChewing_Shared** | Shared protocols: `IMEStateProtocol`, `StateType`, `KBEvent`, `PrefMgrProtocol` |

### State Machine Flow

```
SessionCtl → InputSession → InputHandler → Megrez → IMEState
     ↑                                                      ↓
     └──────────────── UI Updates ← State Changes ←─────────┘
```

- **SessionCtl** receives NSEvents and delegates to `InputSession`.
- **InputSession** handles KeyUp events and menu actions; passes KeyDown events as `KBEvent` to **InputHandler**.
- **InputHandler** triages events and drives state transitions via **IMEState**.
- When adding new APIs to InputSession/InputHandler, add to the protocol first (`InputHandlerProtocol`, `IMEStateProtocol`), then implement. Do not bypass state transitions using boolean flags.

### IMEState Types

Defined in `vChewing_Shared/Sources/Shared/Shared.swift` (`StateType` enum). Critical distinction:

| State | Behaviour |
|-------|-----------|
| `ofDeactivated` | IME is inactive |
| `ofEmpty` | Idle — if previous state had `hasComposition == true`, `switchState()` will **commit** its `displayedTextConverted` to the OS first |
| `ofAbortion` | Clears state **without committing** — use this when discarding composition |
| `ofCommitting` | Explicitly commits `textToCommit` to OS then transitions to `ofEmpty` |
| `ofInputting` | Active preedit composition visible to user |
| `ofMarking` | Text range selection mode |
| `ofCandidates` | Candidate picker open |
| `ofSymbolTable` / `ofSymbolTableGrid` | Symbol picker open |
| `ofNumberInput` | Number quick-input mode |
| `ofSimilarPhonetic` | Similar-phonetic candidate picker |
| `ofAssociates` | Associated phrase picker |

**Gotcha**: Switching to `ofEmpty` when the current state has `hasComposition == true` commits that state's text. To discard without committing, always switch to `ofAbortion` first.

### Key Entry Points

- `Packages/vChewing_MainAssembly4Darwin/.../SessionController/SessionCtl.swift` — IMK entry point; event handling, UI updates.
- `Packages/vChewing_MainAssembly4Darwin/.../LangModelManager/BundleAccessor.swift` — custom `Bundle.currentSPM` for factory lexicon resource lookup.
- `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/` — FSM, Tekkon/Megrez bridge.
- `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_CoreProtocol.swift` — `SmartSwitchState` class (smart Chinese-English switching, `frozenSegments`, double-tap Space); `InputHandlerProtocol`.
- `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/InputHandler_HandleStates.swift` — `generateStateOfInputting()` builds `ofInputting` state, prepending `frozenDisplayText` from `SmartSwitchState`.
- `Packages/vChewing_Tekkon/Sources/Tekkon/` — Zhuyin/pinyin parsing, stroke composition.
- `Packages/vChewing_Megrez/Sources/Megrez/` — DAG-DP sentence assembler, POM observation data.
- `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/` — LM facade, user phrases, POM memory.

### SmartSwitchState (Fork-Specific)

`SmartSwitchState` (in `InputHandler_CoreProtocol.swift`) manages smart Chinese-English switching:

- **`isTempEnglishMode`**: When `true`, keystrokes flow to `englishBuffer` instead of the Zhuyin composer.
- **`frozenSegments: [String]`**: Chinese/English text kept in preedit without committing to OS. Displayed as a prefix via `frozenDisplayText` in `generateStateOfInputting()`.
- **`freezeSegment(_:)`**: Appends text to `frozenSegments`; `clearFrozenSegments()` wipes them.
- **`exitTempEnglishMode()`**: Calls `resetExceptFrozen()`, preserving `frozenSegments` across the mode switch.
- **Double-tap Space**: `recordFirstSpace()` / `tryConfirmDoubleSpace()` detect two SPACE presses within 0.3s to switch back to Chinese while keeping English text as a frozen prefix.

### Lexicon

Lexicon assets are compiled at build-time by the remote SPM plugin `VanguardTextMapPlugin` (from `vChewing-VanguardLexicon`) and injected into `vChewing_MainAssembly4Darwin` as `.txtMap` / `.revlookup` pairs. The runtime backend is `FactoryTextMapLexicon` (sorted-array key index with binary search, on-demand VALUES parsing, bounded NSCache). Do not manually edit or commit these generated artifacts.

### UI

All AppKit windows use the `vChewing_OSFrameworkImpl` Result Builder DSL — no Interface Builder assets (`.xib`, `.storyboard`). SwiftUI is used only for the About window and SettingsUI. `SettingsCocoa` (AppKit DSL) covers macOS 10.9–13.x.

UI must not be dispatched to async threads; use `@MainActor`. Localize strings with `NSLocalizedString("…", comment: "")` and update the corresponding `.strings` localization files. User preferences go through `UserDef` enum → `PrefMgrProtocol` → `PrefMgr`; direct `UserDefaults` access is discouraged. When extending `UserDef`, also extend `PrefMgrProtocol` and `PrefMgr`.

## Code Conventions

### Language
- Documentation, comments, and reviews: **English or zh-Hant-TW only**.
- zh-Hans is allowed only in filename stems ending with `-CHS`.
- Use Taiwan IT terminology (程式, 資料, 螢幕, 視窗, 檔案).

### Commits
```
ModuleName // SubModuleName: Change described.
```
Examples: `Typewriter // InputHandler: Fix Shift key handling.` · `Tekkon // Composer: Add pinyin arrangement support.`

### Imports
Use `@_exported import` in a dedicated file per module (e.g., `TypewriterSPM.swift`, `_ModuleReexport.swift`). Do not scatter `import XXX` across files when the dependency is already re-exported.

### Naming Conventions
- Types: PascalCase. Protocols: suffix with `Protocol` (`IMEStateProtocol`, `PrefMgrProtocol`).
- Use `private` over `fileprivate`. Test files: suffix with `Tests` (e.g. `InputHandlerTests_Cases1.swift`).

### Formatting (SwiftFormat)
- 2-space indent, 120-char line width, K&R braces, `before-first` wrapping.

### Objective-C/C++
- Some SPM dependency targets include Obj-C(++) or C(++) for capabilities not achievable in pure Swift.
- Use Google Style Format for all Obj-C(++) and C(++) code.

### Platform Gating
```swift
#if canImport(Darwin)
// macOS-specific code
#else
// Linux fallback
#endif
```
Gate new APIs with `canImport(Darwin)` and `@available(macOS X, *)` so shared packages keep compiling on Linux.

### Testing
- Uses Swift Testing framework (`import Testing`, `@Test(...)`, `#expect(...)`).
- Reset `PrefMgr` state before/after tests to prevent leakage.
- Add a new test case to reproduce the bug before fixing it.
- Test assets go in `Tests/XXXTests/TestAssets/` or `TestComponents/`.

### License Header
Add on new source files (unless the package uses a different license):
```swift
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.
```

## Upstream Merge Policy

When merging commits from `upstream` (`vChewing/vChewing-macOS`) into this fork:

1. **Fork features must be preserved.** The highest priority is ensuring fork-specific behaviours (SmartSwitch / `SmartSwitchState`, date-based versioning, etc.) are not broken or silently overwritten.

2. **Discuss before overriding fork code.** If an upstream change touches the same lines as fork-specific logic — particularly around `committableDisplayText()`, `generateStateOfInputting()`, `frozenSegments`, `isTempEnglishMode`, or `englishBuffer` — pause and present the conflict to the user before resolving it. Do not silently take the upstream version.

3. **`committableDisplayText()` is fork-extended.** This function was added upstream in 4.3.4. The fork extends it to:
   - Return `frozenDisplayText + englishBuffer` when `smartSwitchState.isTempEnglishMode == true`.
   - Prepend `frozenSegments` to `displayTextSegments` before joining.
   - Offset the cursor by `smartSwitchState.frozenDisplayText.count`.
   Any upstream refactoring of this function must preserve these fork extensions.

4. **`kReflectBPMFVSInCompositionBuffer` default is `true` in this fork** (upstream default is `false`). Never silently change defaults when merging.

5. **Version scheme:** This fork uses date-based versioning (`YYYY.MM.DD` / `YYYYMMDD`). Always keep the fork's version — never adopt upstream's semantic version (`X.Y.Z` / `XYZZ`) during a merge.

6. **After resolving all conflicts**, run `swift test --package-path ./Packages/vChewing_Typewriter` to confirm SmartSwitch tests still pass before committing the merge.

## Things to Avoid

- Hardcoded user data paths (test targets excepted).
- Force unwrap (`!`) in production code; use `guard let` / `if let`.
- Manually editing or committing generated lexicon artifacts.
- `python3` scripts on macOS — prefer PowerShell, C#, or Swift scripts.
- Bridging headers for Xcode builds.
- Removing `platforms` from SPM manifests (breaks compatibility with early macOS targets).
- `@async` dispatch for UI operations outside `@MainActor`.

## Reference Docs

- `AGENTS.md` — full development handbook (build pipeline, detailed style guide).
- `algorithm.md` — Tekkon, Megrez, LM, lexicon algorithms (zh-Hant-TW).
- `.github/copilot-instructions.md` — shared guardrails.
- `BUILD.md` — detailed build instructions.
