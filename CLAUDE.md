# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

vChewing (唯音) is a macOS input method built with AppKit/IMKit in Swift, backed by statistical language models. Main work lives in `Packages/`. The Linux environment only builds `vChewing_Typewriter` and its dependencies.

## Build & Test Commands

```bash
# Build
make release          # Universal binary (arm64+x86_64), signed, sandboxed
make debug            # Single-arch debug build (faster iteration)
make archive          # Release + dSYMs + .xcarchive for distribution
make update           # Fetch/generate lexicon assets (first-time setup)

# Test
swift test                                                    # All tests
swift test --package-path ./Packages/vChewing_Typewriter      # Single package
swift test --package-path ./Packages/vChewing_Typewriter --filter InputHandlerTests  # Single suite
swift test --package-path ./Packages/vChewing_Typewriter --filter "testCaseName"     # Single test
make spmLinuxTest-Typewriter                                  # Linux Docker test

# Lint & Format
make lint             # SwiftLint with autocorrect
make format           # SwiftFormat
make spmLintFormat    # Both, across all packages
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

### Key Entry Points

- `Packages/vChewing_MainAssembly4Darwin/.../SessionController/SessionCtl.swift` — IMK entry point; event handling, UI updates.
- `Packages/vChewing_MainAssembly4Darwin/.../LangModelManager/BundleAccessor.swift` — custom `Bundle.currentSPM` for factory lexicon resource lookup.
- `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/` — FSM, Tekkon/Megrez bridge.
- `Packages/vChewing_Tekkon/Sources/Tekkon/` — Zhuyin/pinyin parsing, stroke composition.
- `Packages/vChewing_Megrez/Sources/Megrez/` — DAG-DP sentence assembler, POM observation data.
- `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/` — LM facade, user phrases, POM memory.

### Lexicon

Lexicon assets are compiled at build-time by the remote SPM plugin `VanguardSQLLegacyPlugin` (from `vChewing-VanguardLexicon`) and injected into `vChewing_MainAssembly4Darwin`. Do not manually edit or commit these generated artifacts.

### UI

All AppKit windows use the `vChewing_OSFrameworkImpl` Result Builder DSL — no Interface Builder assets (`.xib`, `.storyboard`). SwiftUI is used only for the About window and SettingsUI. `SettingsCocoa` (AppKit DSL) covers macOS 10.9–13.x.

UI must not be dispatched to async threads; use `@MainActor`. Localize strings with `NSLocalizedString`. User preferences go through `UserDef` enum → `PrefMgrProtocol` → `PrefMgr`; direct `UserDefaults` access is discouraged.

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

### Formatting (SwiftFormat)
- 2-space indent, 120-char line width, K&R braces, `before-first` wrapping.

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
