# AGENTS.md

AI coding assistant handbook for vChewing-macOS (唯音輸入法 macOS 版).

> **IMPORTANT — Fork Policy**: This repository (`ThomasHsieh/vChewing-macOS`) is a personal fork of the upstream project (`vChewing/vChewing-macOS`). All commits, pushes, and pull requests **must target the fork** (`origin` → `ThomasHsieh/vChewing-macOS`). Never push to or open PRs against the upstream repository (`upstream` → `vChewing/vChewing-macOS`) unless the owner explicitly instructs you to do so.

## Quick Commands

### Build
```bash
make release          # Universal binary (arm64+x86_64), signed, sandboxed
make debug            # Single-arch debug build (faster iteration)
make archive          # Release + dSYMs + .xcarchive for distribution
make update           # Fetch/generate lexicon assets (first-time setup)
swift build -c debug  # SPM debug build
```

### Test
```bash
# Run all tests
swift test
make test

# Run tests for specific package
swift test --package-path ./Packages/vChewing_Typewriter
swift test --package-path ./Packages/vChewing_Tekkon
swift test --package-path ./Packages/vChewing_Megrez

# Run single test file (Swift Testing framework)
swift test --package-path ./Packages/vChewing_Typewriter --filter InputHandlerTests
swift test --package-path ./Packages/vChewing_Tekkon --filter TekkonTests_Basic

# Run specific test case
swift test --package-path ./Packages/vChewing_Typewriter --filter "testCaseName"

# Linux Docker test
make spmLinuxTest-Typewriter
```

### Lint & Format
```bash
make lint             # SwiftLint with autocorrect
make format           # SwiftFormat
make spmLintFormat    # Lint + Format all packages

cd ./Packages && make lint && make format  # Manual package-level
```

## Project Structure

| Module | Purpose |
|--------|---------|
| **vChewing_MainAssembly4Darwin** | IMK front-end, SessionCtl, UI bridges |
| **vChewing_Typewriter** | Typing FSM, InputHandler, Tekkon integration (Linux-compatible) |
| **vChewing_Megrez** | DAG-DP compositor (sentence assembler) |
| **vChewing_Tekkon** | Zhuyin/Bopomofo composer, keyboard parsers |
| **vChewing_LangModelAssembly** | LM facade, user phrases, perception override |
| **vChewing_OSFrameworkImpl** | AppKit Result Builder DSL for UI |

## Code Style Guidelines

### Language & Comments
- **Documentation**: Use English or zh-Hant-TW (Traditional Chinese - Taiwan)
- **zh-Hans exception**: Only allowed in filename stems ending with `-CHS`
- **Terminology**: Use Taiwan-specific terms (程式, 資料, 螢幕, 視窗, 檔案)

### Imports
- Use `@_exported import` in dedicated files (e.g., `TypewriterSPM.swift`, `_ModuleReexport.swift`)
- Avoid scattering `import XXX` across files when dependency is already exported
- Standard pattern:
  ```swift
  // In ModuleSPM.swift
  @_exported import DependencyA
  @_exported import DependencyB
  
  // In other files - no need to import again
  // Just use the types directly
  ```

### Formatting (SwiftFormat)
- **Indent**: 2 spaces
- **Max width**: 120 characters
- **Braces**: K&R style (`else` on same line)
- **Wrapping**: `before-first` for arguments, parameters, collections
- **Swift version**: 5.5 minimum

### Naming Conventions
- **Types**: PascalCase (`InputHandler`, `SessionCtl`)
- **Functions/Variables**: camelCase (`handleKeyEvent`, `currentState`)
- **Protocols**: Suffix with `Protocol` when needed (`IMEStateProtocol`, `PrefMgrProtocol`)
- **Private**: Use `private` over `fileprivate`; use `strict_fileprivate` rule
- **Test files**: Suffix with `Tests` (`InputHandlerTests_Cases1.swift`)

### Types & Error Handling
- Use explicit types over implicit where clarity matters
- Gate APIs with availability checks:
  ```swift
  #if canImport(Darwin)
  @available(macOS 12, *)
  func modernAPI() { }
  #endif
  ```
- Avoid `!` force unwrap; use `guard let` or `if let`
- Prefer `Result` type or thrown errors over optional chains for complex errors

### Architecture Patterns

#### State Machine Flow
```
SessionCtl → InputSession → InputHandler → Megrez → IMEState
     ↑                                                      ↓
     └──────────────── UI Updates ← State Changes ←─────────┘
```

#### Adding New APIs
1. Add to protocol first (`InputHandlerProtocol`, `IMEStateProtocol`)
2. Implement in concrete type
3. Update state transitions explicitly (avoid boolean bypass flags)

#### UI Construction (AppKit DSL)
```swift
// Use OSFrameworkImpl Result Builder DSL
ContentView {
  VStack {
    HStack {
      TextField(title: "Label")
      Button(title: "Action")
    }
  }
}
```
- **NO** Interface Builder assets (`.xib`, `.storyboard`)
- SwiftUI only for About window and SettingsUI
- SettingsCocoa (AppKit DSL) for macOS 10.9-13.x support

## Testing Guidelines

### Test Structure
```swift
import Foundation
import Testing
@testable import Typewriter

@Test("Test description")
func testSpecificFeature() {
  // Arrange
  let handler = InputHandler(...)
  
  // Act
  let result = handler.handle(event)
  
  // Assert
  #expect(result == expected)
}
```

### Test Data
- Place test assets in `Tests/XXXTests/TestAssets/` or `TestComponents/`
- Use mocked components: `MockedInputHandler`, `MockedClient`
- Reset `PrefMgr` state before/after tests to avoid leakage

### Running Tests in Docker (Linux)
```bash
make spmLinuxTest-Typewriter
```

## Git Commit Convention

Use Conventional Commits format:
```
ModuleName // SubModuleName: Changes-described.
```

Examples:
- `Typewriter // InputHandler: Fix Shift key handling.`
- `Tekkon // Composer: Add pinyin arrangement support.`
- `MainAssembly4Darwin // SessionCtl: Refactor event dispatch.`

## Platform Compatibility

- **macOS target**: 12+ (main), legacy releases maintained separately
- **Linux support**: Typewriter package and dependencies only
- **Platform gating**:
  ```swift
  #if canImport(Darwin)
  // macOS-specific code
  #else
  // Linux/Windows fallback
  #endif
  ```

## Things to Avoid

1. **NO hardcoded user paths** (except in Swift Package test targets)
2. **NO manual edits** to generated lexicon assets (transient build artifacts)
3. **NO force unwrap** on production code
4. **NO async dispatch** for UI operations (use `@MainActor`)
5. **NO Python3 scripts** on macOS (prefer PowerShell, C#, or Swift)
6. **NO bridging headers** for Xcode builds

## License Headers

Preserve MIT-NTL license banner on new source files:
```swift
// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.
```

## Reference Docs

- `CLAUDE.md`: Claude-specific quick checklist
- `algorithm.md`: Technical algorithms (Tekkon, Megrez, LM) - zh-Hant-TW
- `.github/copilot-instructions.md`: Copilot shared guidelines
- `BUILD.md`: Detailed build instructions
