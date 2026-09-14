# AGENTS.md

This handbook briefs AI coding assistants on the vChewing (唯音) macOS repository. Use only English or zh-Hant-TW for docs/comments/reviews; zh-Hans is allowed only in filename stems ending with -CHS.

## 1. Project Snapshot

- **Purpose**: Native Zhuyin / Bopomofo input method for macOS with optional phonetic and stroke keyboards, simplified ↔ traditional isolation, and sandboxed distribution installers.
- **Implementation**: Pure Swift modules layered on AppKit/IMK. C(++)/ObjC(++) bridges exist only where Swift cannot interface directly with legacy assets.
- **Primary packages**:
  - `vChewing_MainAssembly4Darwin`: IMK front-end (Darwin surface `InputSession_DarwinSurface`, session-controller bindings, `SessionHost` wiring, UI bridges, sandbox glue).
  - `vChewing_OSNeutral_LibVanguard`: Typing FSM, session core protocol (`SessionCoreProtocol`), Tekkon integration, user preference wiring, cassette/stroke handling.
  - `vChewing_Homa`（模組 `Homa`）: DAG-DP assembler (sentence assembler) with candidate override, consolidation, revolver, and perception hooks — a *target* of the `vChewing_OSNeutral_LibVanguard` package since the 2026-09-13 merge.
  - `vChewing_Tekkon`（模組 `Tekkon`）: Keyboard parsers, Zhuyin/Bopomofo composer, stroke cassette parser, phonabet utilities — likewise a target of `vChewing_OSNeutral_LibVanguard`.
  - `vChewing_LexiconAssembly`（模組 `LexiconAssembly`）: LM instantiation facade, user phrase memory, perception override, associated phrases — likewise a target of `vChewing_OSNeutral_LibVanguard`.
  - **That package also holds the whole typing closure**: since 2026-09-13 it carries the former `vChewing_Shared`、`vChewing_LexiconAssembly`、`vChewing_Homa`、`vChewing_Tekkon`、`vChewing_BPMFVS`、`vChewing_BrailleSputnik` packages as same-named targets, shipping as **one** dynamic library. Module names are unchanged, so `import Shared` / `import Tekkon` / … still work; only the package that vends them changed.
  - `Packages/vChewing_VanguardSwiftExtension`（模組 `SwiftExtension`）: general-purpose Swift/Foundation utilities. It was folded into the aggregate in the same 2026-09-13 merge, but was extracted again because the App-based installer needed only this module and was otherwise forced to carry the whole typing engine; see the *Dynamic products* note below. It ships as its own dynamic product — named `VanguardSwiftExtension` after its packaging role — while the module keeps its original name, so `import SwiftExtension` stays the spelling everywhere.
  - Packages that stay separate include `vChewing_OSFrameworkImpl` (AppKit result-builder DSL), `vChewing_SettingsUI`, `vChewing_CandidateWindow`, and the rest of the Darwin-side surface.
- **Lexicon assets**: Provided by remote Swift Package plugin `VanguardTextMapPlugin` (from `vChewing-VanguardLexicon` repository). Compiled factory lexicons (`.txtMap` + `.revlookup` pairs) are injected into `vChewing_MainAssembly4Darwin` during build-time. The runtime backend is `VanguardTrie.TextMapTrie` (sorted-array key index with binary search, on-demand VALUES parsing, bounded parsed-entry cache).

## 2. Environment & Build Paths

- **Authoritative toolchain**: Swift 6.2+ (`Package.swift` declares `swift-tools-version` 6.2; CI runs on `macos-26` with Xcode 26.6).
- **Runtime target**: macOS 12 Monterey and newer. Older macOS support lives in another repo.
- **Build system**: Swift Package Manager (SwiftPM, `swift-tools-version` 6.2) via `Package.swift` root manifest. App bundle assembly and universal binary scripting via `Makefile` with `BundleApps` CommandPlugin.
- **CLI builds**:
  - Universal binary release: `make release` (builds arm64 + x86_64, creates signed .app bundles in `Build/Products/Release/`).
  - Archive with dSYMs: `make archive` (creates `.xcarchive` in Xcode Archives folder).
  - Debug native build: `make debug` (single-arch; `.app` bundles output under `Build/Products/Debug/`).
  - Package-only tests: `cd Packages/vChewing_OSNeutral_LibVanguard && swift build && swift test`.
- **First-time setup**: `make update` (fetches/generates lexicons) then `make release`.
- **Xcode builds share `Build/Products/`**: `vChewing.xcodeproj` (schemes `vChewing`, `vChewingDebuggable`, `vChewingInstaller`) resolves its products into the repo's own `Build/Products/<Config>/` — identical to the plugin's output path. The location is NOT declared in the repo; it comes from a machine-level Xcode preference (`IDECustomBuildProductsPath` = `Build/Products`, `IDECustomBuildIntermediatesPath` = `Build/Intermediates.noindex`, `IDECustomBuildLocationType` = `RelativeToWorkspace`). Setting `SYMROOT` in the project instead is not an option: Xcode then falls back to a legacy build location and SPM integration stops working entirely (`Packages are not supported when using legacy build locations`). Because the two producers share one directory, `BundleApps` removes only the two app bundles it owns and leaves everything else (Xcode's `vChewingDebuggable.app`, per-target `.o`/`.swiftmodule` blobs, `.app.dSYM`) untouched.
- **Dynamic products**: the typing closure ships as **one** dynamic library from `Packages/vChewing_OSNeutral_LibVanguard` (`.library(name: "Vanguard", type: .dynamic, …)`, product file `libVanguard.dylib`; package named `LibVanguard`, aggregate target/module `LibVanguard` — that is the one the app-side packages `import`). The utility module `SwiftExtension` (shipped as the dynamic product `VanguardSwiftExtension`) is **deliberately not part of that closure**: it lives in its own package `Packages/vChewing_VanguardSwiftExtension` and ships as a *second* dynamic library (`libVanguardSwiftExtension.dylib`), which `vChewing.app` links alongside the first while `vChewingInstaller.app` links **only** the second. Two reasons: (a) the App-based installer needs nothing else from the closure, yet folding the module in forced it to carry the whole typing engine; (b) SwiftPM only links a product dynamically **across** package boundaries — a target belonging to a same-package dynamic product is still statically merged into same-package consumers, which would silently duplicate the module in one process. That duplicate is unacceptable here because `VanguardSwiftExtension` has types on `OSFrameworkImpl`'s public surface (`@ArrayBuilder` in a `public init`, plus a retroactive `DynamicProperty` conformance on `AppProperty`) and because `PrefMgr` carries ~103 `@AppProperty` properties inside the closure. On non-Darwin platforms that package's product is `.static`, so `libVanguard.dylib` embeds it there and no second library is produced. Both `vChewing.app` and `vChewingInstaller.app` are assembled through the shared `embedLinkedDylibs(of:into:availableDylibs:)`, which embeds **only the dylibs the executable actually links** (`otool -L` → `@rpath/*.dylib`) into `Contents/Frameworks/`, adds `@executable_path/../Frameworks` via `install_name_tool` before signing, and signs inner-out (dylib first, then the app) without `--deep`. Because ad-hoc signing leaves the process with no Team ID, the plugin injects `com.apple.security.cs.disable-library-validation` **only when frameworks are embedded**; the distribution path re-signs every nested binary with a real Team ID (`BuildPKG.sh`) and needs no such relaxation. Note that SwiftPM rejects any arrangement where a module is linked statically by both the app and the dynamic product (`duplication of library code`) — that is why the closure lives in a single package with a single dynamic product.
- **Xcode builds embed the same library differently**: Xcode resolves the SPM dynamic product as `Vanguard.framework` under `Build/Products/<Config>/PackageFrameworks/`, links it as `@rpath/Vanguard.framework/Versions/A/Vanguard`, and embeds it into `Contents/Frameworks/` on its own — nothing in the project requests this and no `BundleApps` phase is involved. Because the `vChewing` and `vChewingInstaller` targets build with `ENABLE_HARDENED_RUNTIME = YES` while this machine signs ad-hoc, that product would die at launch under library validation (`dyld: … different Team IDs`, exit 134), so both targets set `RUNTIME_EXCEPTION_DISABLE_LIBRARY_VALIDATION = YES` in Debug and Release — Xcode's build-setting form of the entitlement above. Xcode injects it at signing time and it never reaches `Sources/vChewingIME_macOS/Resources/vChewing.entitlements` or `Sources/Installer_macOS/Resources/vChewingInstaller.entitlements`, which is what `BuildPKG.sh` re-signs from, so distributed builds stay free of the relaxation. `vChewingDebuggable` needs no exception: it builds with `ENABLE_HARDENED_RUNTIME = NO`.

## 3. Repository Layout (quick map)

- `Packages/vChewing_MainAssembly4Darwin/.../SessionController/`: IMK-facing Darwin surface. `InputSession_DarwinSurface.swift` holds the IMK entry surface (`init(controller:)`, `recognizedEvents`, `showPreferences`, `handleNSEvent(NSEvent)` conversion, IMKInputController surface, `toggleInputMode` TIS logic); `SessionControllerSputnik.swift` binds `IMKInputSessionController` to the session and forwards callbacks; `SessionHostWiring.swift` wires `SessionHost` closures (called from `MainSputnik4IME.init`).
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/InputHandler/`: FSM split across triage, composition, candidate handling, and commissions; `InputHandler.swift` is the concrete handler class.
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/LibVanguard/Session/`: OS-independent session system — `SessionCoreProtocol` (shared session base protocol with `switchState()`/`resetInputHandler()` defaults), `SessionProtocol` + `InputSession` (the session class), `IMEState` factories / `IMEStateParsed`, `SessionHost` (host-injection point for all OS-dependent actions), `SessionClientProxy` (cross-platform client-proxy abstraction). Darwin-specific behavior lives in MainAssembly4Darwin via `SessionHost` wiring + the Darwin surface.
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/Homa/`: Assembler core (`Homa_Assembler.swift`, `Homa_PathFinder.swift`, candidate/consolidation APIs, etc.).
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/Tekkon/`: Keyboard parsers, composer, Zhuyin constants.
- `Packages/vChewing_OSNeutral_LibVanguard/Sources/LexiconAssembly/`: LM instantiators, perception override, associated phrase derivation.
- `Packages/vChewing_OSFrameworkImpl/`: AppKit result-builder DSL for SettingsCocoa window, etc.
- `Packages/vChewing_SettingsUI/`: Preferences UI as a standalone package — SwiftUI `SettingsUI` for macOS 14+ (incl. the phrase editor and the About pane) plus the AppKit `SettingsCocoa` alternate; host actions are injected via `SettingsUIHost` closures (`SettingsUIHostWiring.swift` in MainAssembly).
- `Packages/vChewing_CandidateWindow/`: The Candidate window.
- `Plugins/BundleApps/`: CommandPlugin that assembles `.app` bundles and optional `.xcarchive` archives (codesigning, entitlements, SPM bundle filtering).
- `Makefile`: Root-level automation for universal binary builds (`swift build --arch arm64/x86_64`, `lipo` merge), lexicon toolchain integration, and CommandPlugin invocation.
- `Sources/Installer_macOS/` + `Packages/vChewing_InstallerAssembly4Darwin/`: SwiftUI installer app (the `vChewingInstaller` executable) + pkg resources; `BuildPKG.sh` assembles the installer PKG.

## 4. Runtime Flow & Key Concepts

1. **Event capture**: IMK instantiates `IMKInputSessionController` (`vChewing_IMKUtils`); `SessionControllerSputnik` forwards its NSEvents to the bound `InputSession`, which converts NSEvent→KBEvent (`InputSession_DarwinSurface.handleNSEvent`) and marshals them into `KBEvent` structures for the portable session core.
2. **FSM triage**: `InputHandler` in LibVanguard interprets events, orchestrates Tekkon composer, updates the Homa assembler, and switches `IMEState` instances.
3. **Composer**: Tekkon manages Zhuyin/phonetic/stroke buffers, auto-correction, cassette mode, and exposes inline display strings.
4. **Assembler**: Homa Assembler builds DAG segments, snapshots perception intelligences, exposes candidate / consolidation / revolver APIs, and emits `assembledSentence` for UI rendering.
5. **Language Models**: `LXAssembly` merges factory lexicons (Vanguard TextMap format, served by `VanguardTrie.TextMapTrie` in the package-local `TrieKit` target), user phrases, exclusion lists, associated phrase suggestions, POM (perception / fading-memory) n-gram statistics, and perception override suggestions.
6. **UI update**: `InputSession` refreshes candidate window, composition buffer, tooltips, notifications, symbol menu.

Reference `algorithm.md` for the deep algorithm write-up (zh-Hant).

## 5. Development Guardrails

- **Language**: Code comments, docs, and commit messages in English or zh-Hant. (zh-Hans only in files if filenamestem ends with `-CHS`.)
- **UI**: AppKit by default — no Interface Builder nibs/storyboards, and AppKit windows are implemented with the AppKit Result Builder DSL (`vChewing_OSFrameworkImpl`). Exceptions: the SwiftUI settings surface (`vChewing_SettingsUI`, macOS 14+) and the SwiftUI installer app (`vChewing_InstallerAssembly4Darwin`). Keep UI work on the main actor.
- **Preferences**: Extend `UserDef`, `PrefMgrProtocol`, and `PrefMgr` together. Avoid naked `UserDefaults.standard` access except in constrained scenarios.
- **User data paths**: Avoid hard-coded user data paths except where necessary in package test targets.
- **State machine**: Prefer new `IMEState` enum cases and explicit transition APIs over boolean shortcuts. `SessionCoreProtocol` (LibVanguard) provides `switchState()`/`resetInputHandler()` default implementations shared by mock tests and production; extend `InputHandlerProtocol` for per-event triage logic.
- **Conditional APIs**: Guard platform-specific code (`#if canImport(Darwin)`) as needed; keep Linux compatibility in `LibVanguard` package and its local dependencies.
- **Bundle resources**: SPM `#bundle` / `Bundle.module` is avoided in the `LibVanguard` closure — SwiftPM's generated accessor calls `fatalError` when the resource bundle is missing, which breaks dynamic-library loading and relocated builds. Use `ResourceLocator` (target of the same name in `vChewing_OSNeutral_LibVanguard`) instead: it probes the host bundle, the anchor bundle, the sibling directory, and the loaded image's directory, and returns `nil` on failure. `Bundle.currentSPM` (MainAssembly4Darwin) is a nullable wrapper over it. Hosts may point the lookup at explicit locations via `ResourceProvision` (LibVanguard), `ResourceLocator.specifyResourceBundleURL(_:forBundleNamed:)`, or `BPMFVS.specifyDataURL(_:)`.
- **ObjC(++)/C(+=) style**: Follow Google Style Guide formatting for Objective-C(++) and C(++).
- **Licensing**: New source files carry the 3-line MulanPSL-2.0 banner, which cites only the SPDX identifier (``// (c) <year> and onwards The vChewing Project (MulanPSL-2.0 License).`` / ``// ====================`` / ``// This code is released under the SPDX-License-Identifier: `MulanPSL-2.0`.``); the license text itself lives in `./LICENSE.txt`. The `LibVanguard` dependency closure keeps its own LGPL v3.0 license files with the Swift static-linking exception, while `VanguardSwiftExtension` ships under MulanPSL-2.0; respect each module's own license and avoid mixing incompatible license assets.
- **Lexicon tooling**: Factory lexicons are compiled by remote `VanguardTextMapPlugin` (Swift Package plugin from `vChewing-VanguardLexicon` repository) and injected into `vChewing_MainAssembly4Darwin` at build-time via SPM build plugins. The runtime backend is `VanguardTrie.TextMapTrie` (sorted-array key index with binary search, on-demand VALUES parsing, bounded parsed-entry cache). Do not modify or commit generated lexicon assets; they are transient build artifacts.

## 6. Testing Expectations

- Unit tests live alongside each Swift package (`swift test`). Focus on deterministic cases that mirror reported issues.
- LibVanguard and MainAssembly packages host end-to-end style tests; consider snapshotting `PrefMgr` state before/after.
- When touching Tekkon or Homa, craft stress tests covering multi-syllable input, perception overrides, cursor edge cases.
- Use `swift test --filter` to run targeted suites when debugging CI regressions.

## 7. Contribution Workflow

- **Commit format**: `ModuleName // SubModuleName: Change.` (Conventional Commit semantics kept terse.) Example: `LibVanguard // FSM: Fix cursor guard.`
- **Reviews**: Highlight functional impact, state machine ramifications, and test coverage. Mention regression risk if tests are missing.
- **Dependencies**: Prefer SwiftPM-targeted adjustments. When external patches are unavoidable, document rationale in code comments and PR description.
- **Installer**: Keep pkg scripts idempotent. `pkgPreInstall.sh` / `pkgPostInstall.sh` must remain sandbox safe.

## 8. Quick Reference Checklist

- [ ] Honor language restrictions in new text.
- [ ] Update `.strings` when adding user-visible strings.
- [ ] Gate new APIs through protocols as needed.
- [ ] Run relevant `swift test` targets.
- [ ] Align new keyboard layouts with Tekkon parsers and symbol tables.

Questions from contributors should reference this file first; escalate only when guidance is missing or conflicting.
