# VOSputnik - VoiceOver Integration for vChewing

## Overview

VOSputnik is a singleton service that provides VoiceOver integration for vChewing IME. It announces input states, candidate selections, and composition changes to VoiceOver users.

## Features

- **Candidate Announcements**: Announces selected candidates with position information (e.g., "測 1 / 5")
- **Composition Announcements**: Announces text being composed with optional cursor position
- **State Change Announcements**: Announces IME state transitions
- **Privacy Protection**: Automatically disabled in secure input mode (password fields)
- **Debouncing**: Prevents announcement spam with 200ms debounce
- **Emoji Support**: Special handling for emoji and phonetic symbols
- **Accessibility Exclusion**: Candidate window excluded from VoiceOver focus

## Architecture

### Core Components

1. **VOCandidate**: Data structure for announcement content
   - `display`: Text shown in VoiceOver
   - `speechOverride`: Optional alternative speech text
   - `metadata`: Optional additional context

2. **VOSputnik**: Main singleton service
   - Manages all VoiceOver announcements
   - Handles debouncing and coalescing
   - Checks preferences and system status

3. **Integration Extensions**: Convenience methods on InputSession and InputHandler

## Usage

### Basic Integration

The VOSputnik is automatically integrated with the InputSession and InputHandler through extension methods:

```swift
// In InputSession or InputHandler
session.updateVoiceOver() // General state updates
session.updateVoiceOverForCandidateChange(highlightedIndex: 0) // Candidate selection
session.updateVoiceOverForComposition(compositionText: "測試", cursorPosition: 1)
```

### Candidate Window Integration

To exclude the candidate window from VoiceOver focus:

```swift
// When creating a candidate window
candidateWindow.configureForVoiceOverExclusion()
```

This ensures VoiceOver doesn't interfere with the candidate window while still announcing selections through VOSputnik.

## Privacy & Security

- Respects `kEnableVoiceOverForCandidatesAndComposition` preference
- Automatically disabled when `IsSecureEventInputEnabled()` returns true
- No announcements made in password fields or other secure contexts

## Preferences

### User Preference

- **Key**: `EnableVoiceOverForCandidatesAndComposition`
- **Type**: Boolean
- **Default**: `true`
- **Description**: Controls whether VoiceOver announcements are enabled

Users can toggle this in the vChewing preferences under accessibility settings.

## Debouncing

VOSputnik implements a 200ms debounce to prevent announcement spam:

- Multiple rapid state changes are coalesced
- Only the final state is announced
- Prevents VoiceOver from being overwhelmed during fast typing

## Special Character Handling

### Emoji Replacements

Common emojis are replaced with Chinese descriptions for better speech output:

- 😀 → "笑臉"
- ❤️ → "愛心"
- 👍 → "讚"
- etc.

### Phonetic Symbols (Zhuyin/Bopomofo)

When the entire composition is phonetic symbols, they are expanded for clearer pronunciation:

- ㄅ → "ㄅ玻"
- ㄆ → "ㄆ坡"
- ㄇ → "ㄇ摸"
- etc.

## Testing

Unit tests are provided in `VOSputnikTests.swift`:

- VOCandidate initialization and properties
- Singleton pattern verification
- Debouncing behavior
- Accessibility exclusion
- Edge case handling (empty lists, invalid indices, etc.)

## Compatibility

- **Minimum OS**: macOS 10.9 Mavericks
- **Platform**: macOS only (guarded with `#if canImport(AppKit)`)
- **Thread Safety**: All accessibility announcements run on main thread
- **No SPM Dependencies**: Pure Swift implementation

## Manual Testing Steps

1. **Enable VoiceOver** (Cmd+F5 or System Preferences)
2. **Launch vChewing** and activate in any text field
3. **Test Candidate Selection**:
   - Type some phonetic input
   - Use arrow keys to navigate candidates
   - Verify VoiceOver announces each selection with position
4. **Test Composition**:
   - Type phonetic symbols
   - Verify VoiceOver announces composition changes
5. **Test Secure Input**:
   - Switch to a password field
   - Verify no VoiceOver announcements are made
6. **Test Candidate Window**:
   - Verify VoiceOver doesn't focus on candidate window UI
   - Verify announcements still work

## Implementation Notes

### Why Not Couple with Candidate Window?

Unlike some implementations that tightly couple VoiceOver with the candidate window UI, VOSputnik is designed to be independent:

- **Separation of Concerns**: UI and accessibility are separate
- **State Machine Driven**: Announcements driven by IME states
- **Testable**: Can be tested without UI
- **Flexible**: Easy to adapt to different UI implementations

### Accessibility Exclusion

The candidate window and its subviews are explicitly excluded from VoiceOver focus:

```swift
window.isAccessibilityElement = false
// Recursively apply to all subviews
```

This prevents VoiceOver from trying to navigate the candidate window UI, which would be confusing. Instead, VOSputnik provides structured announcements.

## Future Enhancements

Potential improvements:

- [ ] Add more emoji/special character mappings
- [ ] Support for multiple languages in speech output
- [ ] Configurable debounce interval
- [ ] Announcement priority levels
- [ ] Context-aware announcement detail levels
- [ ] Integration with speech synthesizer settings

## License

MIT-NTL License (see main project license)

## References

- NSAccessibility Documentation: https://developer.apple.com/documentation/appkit/nsaccessibility
- VoiceOver Best Practices: https://developer.apple.com/accessibility/
