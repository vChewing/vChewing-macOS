# AGENTS.md

This handbook briefs AI coding assistants on the vChewing (唯音) macOS repository. Use only English or zh-Hant-TW for docs/comments/reviews; zh-Hans is allowed only in filename stems ending with -CHS.

## 1. Project Snapshot

- **Purpose**: Native Zhuyin / Bopomofo input method for macOS with optional phonetic and stroke keyboards, simplified ↔ traditional isolation, and sandboxed distribution installers.
- **Implementation**: Pure Swift modules layered on AppKit/IMK. C(++)/ObjC(++) bridges exist only where Swift cannot interface directly with legacy assets.
- **Primary packages**:
  - `vChewing_MainAssembly4Darwin`: IMK front-end (SessionCtl, InputSession, UI bridges, sandbox glue).
  - `vChewing_Typewriter`: Typing FSM, Tekkon integration, user preference wiring, cassette/stroke handling.
  - `vChewing_Megrez`: DAG-DP compositor (sentence assembler) with perception override hooks (POM).
  - `vChewing_Tekkon`: Keyboard parsers, Zhuyin/Bopomofo composer, stroke cassette parser, phonabet utilities.
  - `vChewing_LangModelAssembly`: LM instantiation facade, user phrase memory, perception override, associated phrases.
  - Shared dependencies (`vChewing_Shared`, `vChewing_SwiftExtension`, `vChewing_OSFrameworkImpl`, etc.) supply utilities, result-builder UI DSL, notifications, and AppKit wrappers.
- **Lexicon assets**: Submodule `Source/Data` (Swift-based tooling + generated blobs). Do not edit unless specifically asked.

## 2. Environment & Build Paths

- **Authoritative toolchain**: macOS 14.7+ (Sonoma recommended), Xcode 15.3+ with bundled Swift 5.10 or newer.
- **Runtime target**: macOS 12 Monterey and newer. Older macOS support lives in another repo.
- **Project entry**: `vChewing.xcodeproj` (scheme `vChewing`). Installer scaffolding: `vChewing.pkgproj`, SwiftUI installer app under `Installer/`.
- **CLI builds**:
  - `pwsh -NoLogo -Command "xcodebuild -project vChewing.xcodeproj -scheme vChewing -configuration Release build"`
  - Package-only builds/tests: `pwsh -NoLogo -Command "cd Packages/vChewing_Typewriter; swift build"`, same for `swift test`.
- **First-time setup**: `make update` (fetches/generated lexicons) then build. Ensure Xcode DerivedData location is set to “Relative to Workspace” to satisfy make recipes.

## 3. Repository Layout (quick map)

- `Packages/vChewing_MainAssembly4Darwin/.../SessionController/SessionCtl.swift`: IMK entry point. All NSEvent handling funnels through `InputSession*` files.
- `Packages/vChewing_Typewriter/Sources/Typewriter/InputHandler/`: FSM split across triage, composition, candidate handling, and commissions.
- `Packages/vChewing_Megrez/Sources/Megrez/`: Compositor core (`0_Megrez.swift`, `2_PathFinder.swift`, etc.).
- `Packages/vChewing_Tekkon/Sources/Tekkon/`: Keyboard parsers, composer, Zhuyin constants.
- `Packages/vChewing_LangModelAssembly/Sources/LangModelAssembly/`: LM instantiators, perception override, associated phrase derivation.
- `Packages/vChewing_OSFrameworkImpl/`: AppKit result-builder DSL for SettingsCocoa window, etc.
- `Packages/vChewing_CandidateWindow/`: The Candidate window.
- `Source/Data`: Submodule for lexicon tooling (`Makefile`, Swift build scripts, generated `Build/` assets).
- `Installer/`: SwiftUI installer app + pkg resources.

## 4. Runtime Flow & Key Concepts

1. **Event capture**: IMK `SessionCtl` receives NSEvents and marshals them into `KBEvent` structures.
2. **FSM triage**: `InputHandler` in Typewriter interprets events, orchestrates Tekkon composer, updates Megrez compositor, and switches `IMEState` instances.
3. **Composer**: Tekkon manages Zhuyin/phonetic/stroke buffers, auto-correction, cassette mode, and exposes inline display strings.
4. **Assembler**: Megrez Compositor (sentence assembler) builds DAG segments, snapshotting perception intelligences (will be fed to the perception override module in the `LMAssembly` package), emits `assembledSentence` for UI rendering.
5. **Language Models**: `LMAssembly` merges factory lexicons, user phrases, exclusion lists, associated phrase suggestions, and perception override data, etc.
6. **UI update**: `SessionCtl` refreshes candidate window, composition buffer, tooltips, notifications, symbol menu.

Reference `algorithm.md` for the deep algorithm write-up (zh-Hant).

## 5. Development Guardrails

- **Language**: Code comments, docs, and commit messages in English or zh-Hant. (zh-Hans only in files if filenamestem ends with `-CHS`.)
- **UI**: AppKit only. No Interface Builder nibs/storyboards. Keep UI work on the main actor. Most AppKit Window views are implemented using AppKit Result Builder DSL.
- **Preferences**: Extend `UserDef`, `PrefMgrProtocol`, and `PrefMgr` together. Avoid naked `UserDefaults.standard` access except in constrained scenarios.
- **User data paths**: Avoid hard-coded user data paths except where necessary in package test targets.
- **State machine**: Prefer new `IMEState` enum cases and explicit transition APIs over boolean shortcuts. Follow existing `InputSession`/`InputHandler` protocol surfaces.
- **Conditional APIs**: Guard platform-specific code (`#if canImport(Darwin)`) as needed; keep Linux compatibility in `Typewriter` package and its local dependnecies.
- **ObjC(++)/C(+=) style**: Follow Google Style Guide formatting for Objective-C(++) and C(++).
- **Licensing**: Preserve MIT-NTL banners. Respect LGPL for Megrez and Tekkon; avoid mixing incompatible license assets.
- **Lexicon tooling**: Generated data lives under `Source/Data/Build`. Scripts run via `make` or Swift command-line tools; do not check in regenerated blobs unless instructed.

## 6. Testing Expectations

- Unit tests live alongside each Swift package (`swift test`). Focus on deterministic cases that mirror reported issues.
- Typewriter and MainAssembly packages host end-to-end style tests; consider snapshotting `PrefMgr` state before/after.
- When touching Tekkon or Megrez, craft stress tests covering multi-syllable input, perception overrides, cursor edge cases.
- Use `swift test --filter` to run targeted suites when debugging CI regressions.

## 7. Contribution Workflow

- **Commit format**: `ModuleName // SubModuleName: Change.` (Conventional Commit semantics kept terse.) Example: `Typewriter // FSM: Fix cursor guard.`
- **Reviews**: Highlight functional impact, state machine ramifications, and test coverage. Mention regression risk if tests are missing.
- **Dependencies**: Prefer SwiftPM-targeted adjustments. When external patches are unavoidable, document rationale in code comments and PR description.
- **Installer**: Keep pkg scripts idempotent. `pkgPreInstall.sh` / `pkgPostInstall.sh` must remain sandbox safe.

## 8. Quick Reference Checklist

- [ ] Honor language restrictions in new text.
- [ ] Update `.strings` when adding user-visible strings.
- [ ] Gate new APIs through protocols as needed.
- [ ] Run relevant `swift test` targets.
- [ ] Avoid touching `Source/Data` unless lexicon work is explicitly requested.
- [ ] Align new keyboard layouts with Tekkon parsers and symbol tables.

Questions from contributors should reference this file first; escalate only when guidance is missing or conflicting.
