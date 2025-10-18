# GitHub Copilot Instructions

## Documentation Structure

This file provides GitHub Copilot-specific coding instructions. For comprehensive project documentation:

- **AGENTS.md**: Master documentation for all AI coding services (architecture, workflows, build pipelines, etc.)
- **algorithm.md**: Technical algorithm documentation (zh-Hant-TW)

**Note:** GitHub Copilot does not automatically read AGENTS.md files. Essential guidelines are included below.

---

## General Guidelines

- **Language restriction:** Use only English or zh-Hant-TW in all documentation, comments, and reviews. An exception is that `zh-Hans` is allowed in any file name stem ended with `-CHS`. Other exceptions may be given by the developer.

## Project Context
- Input method for macOS built with AppKit/IMKit in Swift, backed by statistic-based language models loaded into `./Packages/vChewing_LangModelAssembly` package.
- If you are on Linux, your only workspace is `./Packages/vChewing_Typewriter` and its dependencies situated in `./Packages`. If you are on Windows, you can also work with `./Packages/vChewing_MainAssembly` and its dependencies situated in `./Packages` folder.
- Lexicon assets and lexicon generator codes are in a git submodule situated in `./Source/Data`; compiled blobs are stored in `./Source/Data/Build`.
- Tests are written among local Swift Packages situated in `./Packages/` folder. Tests are usually implemented on a case-by-case basis when an issue case comes out: Write a new test case to confirm the bug exists. 
- Preserve the existing MIT-NTL license banner on any new source file, except certain local Swift Packages licensed with things other than MIT-NTL.

## OS Framework Guidelines
- All AppKit windows are supposed to be constructed using AppKit Result Builder DSL. You can find its definitions in `./Packages/vChewing_OSFrameworkImpl/`.
- Study the `UserDef` enum which manages raw UserDefaults keys with their data types and localization keys (used in the SettingsUI and SettingsCocoa window). If you extended `UserDef`, please also extend `PrefMgrProtocol` and `PrefMgr`. Direct access to UserDefaults are discouraged in most times unless really necessary.
- Localize UI strings with `NSLocalizedString("…", comment: "")` and update the localization assets (`.strings`) files. Note that `xcstring` assets can also be considered in the future if it is compatible with targets compiled for macOS 10.09.
- Follow the established flow: `SessionCtl` retrieves NSEvents and passing it to `InputSession` which also handles menu actions; `InputSession` handles the KeyUp events and let `InputHandler` triage KeyDown events (as KBEvent); `IMEState` models state transitions.
- Do not dispatch the UI-related things to an async thread unless it is on the main actor.

## FSM Design
- Convert incoming NSEvents to KBEvents and let them triaged by `InputHandler`. This allows state transitions happen pass places and UI response flow with state changes.
- In most cases you don't need to extend the state machine. If you really have to, you can extend the state machine by adding new `IMEState` type enum cases plus explicit state transition APIs; bypass the existing states using booleans is discouraged, and you only use it whenever really necessary.

## Objective-C(++) & C(++) Guidelines
- There are no bridging headers for Xcode. However, some Objective-C(++) & C(++) contents are used in some Swift Package dependency targets for purposes not-directly-achievable in Swift.
- Always use Google Format of Style for Objective-C(++) & C(++).

## Tests and Tooling
- GitHub Coding Agent can only access Linux devenv in most times. `./Packages/vChewing_Typewriter/` is the Linux-compilable target that the developer usually ask GitHub Coding Agent to work on. This package is the one to add test files.
- Dictionary files are managed manually by the developer in another repository and is used as a git submodule here. Regenerate lexicon assets via `make update` when explicitly instructed.

## Git Commit Convention

- Use Conventional Commits format for all commits and pull requests.
- Format: `ModuleName // SubModuleName: Changes-described.`
- Example: `Typewriter // Patch the codepoint converter for Linux.`
- Keep descriptions concise.
- Reference: https://www.conventionalcommits.org/

## Things to Beware / Avoid
- When implementing new APIs for InputSession and InputHandler, please put them onto the protocols if possible.
- Gate new APIs with availability checks (e.g. conditional compilation via `canImport(Darwin)` and Swift `@available` annotations) so shared packages keep compiling on Linux. The shipping Xcode target requires macOS 12+, but legacy macOS releases are maintained in a separate repository.
- This repo has no dependency of InterfaceBuilder assets. AppKit is used by default with self-crafted result builder DSLs to make the coding experience similar to SwiftUI. SwiftUI in this project is only used for About window and SettingsUI. On macOS 10.9 Mavericks till macOS 13 Ventura, this repo uses SettingsCocoa (AppKit Result Builder DSL).
- User data is not expected to be referred from hard-coded path, unless it is necessary in Test targets of a Swift package.
- This repository uses XCTest for unit tests used among Swift packages situated in `./Packages` folder.
- Only for local Copilot: Unless being specifically told, please Do Not Touch those lexicon scripts (and compiled lexicon targets) compiled in the git-submodule `libvchewing-data`.
- The platforms in Swift package manifest file is ignored on non-Darwin platforms. Swift FOSS Foundation APIs on Darwin can be unavailable on earlier macOS releases due to Apple's deliberate intention of never backporting new Foundation APIs. Your removal of platforms can make some of those components not able to be compiled against macOS releases earlier than macOS 11.
- Most vChewing-specific packages prefer to use a dedicated file to handle `@_exported import XXX` dependency definitions to avoid insertion of `import XXX` to all files having codes dependent to `XXX`. This makes code-mirroring tasks (to the legacy repository of vChewing) much easier. Try not to break this convention if possible.

## Reference Files and Folders
- `./Packages/vChewing_MainAssembly/Sources/MainAssembly/SessionController/`: `SessionCtl.swift` is the IMK entry point working with candidate window, IME settings, etc. However, most of its tasks are delegated to `InputSession*.swift` files in this folder.
- `./Packages/vChewing_Typewriter/`: The typing module `InputHandler` protocol working with the IMEStateProtocol-based finite state machine.
- `./Packages/vChewing_LangModelAssembly/`: Language model assembly (factory lexicon, user phrases, perception override, associated phrases).
- `./Packages/vChewing_Megrez/`: The sentence assembler.
- `./Packages/vChewing_Tekkon/`: The phonabet composer designed for Chinese Phonabet (Zhuyin, Bopomofo) pronunciation data.
- `./Packages/vChewing_MainAssembly/`: The sole module imported to the Xcode project. It integrates everything together. Real-simulation of typing experiences are handled in the unit tests of this package.
