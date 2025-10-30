# VOSputnik Integration Guide

This guide provides specific code examples for integrating VOSputnik into the existing vChewing codebase.

## Integration Points

### 1. State Change Notification in InputSession

**File**: `Packages/vChewing_MainAssembly/Sources/MainAssembly/SessionController/InputSession_HandleStates.swift`

**Location**: In the `handle(state:replace:)` method, after state changes

Add VoiceOver notification at the end of state handling:

```swift
public func handle(state newState: State, replace: Bool) {
  // ... existing code ...
  
  // VoiceOver notification for state changes
  #if canImport(AppKit)
    updateVoiceOver()
  #endif
}
```

Or, more specifically, add it at the end of the method (around line 110):

```swift
  // 浮動組字窗的顯示判定
  // ... existing code ...
  
  // Notify VoiceOver of state changes
  #if canImport(AppKit)
    updateVoiceOver()
  #endif
}
```

### 2. Candidate Selection Notification

**File**: Look for where candidate selection index changes

This typically happens in:
- Arrow key handling in candidate window
- Mouse click handling in candidate window
- Keyboard shortcut handling for candidate selection

**Example integration in candidate selection handler**:

```swift
func selectCandidate(at index: Int) {
  // ... existing candidate selection code ...
  
  // Notify VoiceOver of candidate change
  #if canImport(AppKit)
    if let session = InputSession.current {
      session.updateVoiceOverForCandidateChange(highlightedIndex: index)
    }
  #endif
}
```

**Alternative**: If candidate index is stored in IMEStateData, update when it changes:

```swift
// In IMEStateData or wherever candidate index is tracked
var highlightedCandidateIndex: Int = 0 {
  didSet {
    #if canImport(AppKit)
      notifyVoiceOverOfIndexChange()
    #endif
  }
}
```

### 3. Composition Change Notification

**File**: `Packages/vChewing_MainAssembly/Sources/MainAssembly/InputHandler/InputHandler.swift`

**Location**: After composer updates

```swift
// After updating the composer (注拼槽)
func handlePhoneticInput(_ key: String) {
  composer.receiveKey(fromPhonabet: key)
  
  // ... existing state update code ...
  
  // Notify VoiceOver of composition change
  #if canImport(AppKit)
    notifyVoiceOverCompositionChange(
      text: composer.value,
      cursorPosition: composer.cursor
    )
  #endif
}
```

### 4. Candidate Window Configuration

**File**: Where candidate window is created (likely in `Packages/vChewing_CandidateWindow/`)

**Location**: In candidate window initialization

```swift
// In candidate window controller initialization
override func windowDidLoad() {
  super.windowDidLoad()
  
  // ... existing setup code ...
  
  // Configure VoiceOver exclusion
  #if canImport(AppKit)
    window?.configureForVoiceOverExclusion()
  #endif
}
```

Or if creating window programmatically:

```swift
func createCandidateWindow() -> NSWindow {
  let window = NSWindow(
    contentRect: rect,
    styleMask: [.borderless],
    backing: .buffered,
    defer: false
  )
  
  // ... existing window setup ...
  
  // Configure VoiceOver exclusion
  #if canImport(AppKit)
    window.configureForVoiceOverExclusion()
  #endif
  
  return window
}
```

### 5. Settings UI Integration

**For SwiftUI (SettingsUI)**

**File**: `Packages/vChewing_MainAssembly/Sources/MainAssembly/Settings/SettingsUI/VwrSettingsPaneGeneral.swift`

Add toggle in appropriate settings pane:

```swift
Section {
  Toggle("Enable VoiceOver announcements for input", isOn: $enableVoiceOverForCandidatesAndComposition)
    .help("Announces candidate selections and composition changes to VoiceOver. Automatically disabled in password fields.")
}
```

With binding:

```swift
@AppStorage(UserDef.kEnableVoiceOverForCandidatesAndComposition.rawValue)
private var enableVoiceOverForCandidatesAndComposition: Bool = true
```

**For Cocoa (SettingsCocoa)**

**File**: `Packages/vChewing_MainAssembly/Sources/MainAssembly/Settings/SettingsCocoa/VwrSettingsPaneCocoaGeneral.swift`

Add using DSL:

```swift
VStack {
  // ... existing controls ...
  
  UserDef.kEnableVoiceOverForCandidatesAndComposition.render(fixWidth: contentWidth)
}
```

## Complete Example: InputHandler Integration

Here's a complete example showing how to integrate into InputHandler:

```swift
// In InputHandler.swift

extension InputHandler {
  
  /// Handle state transition with VoiceOver notification
  func transitionToState(_ newState: IMEState) {
    // Update session state
    session?.switchState(newState)
    
    // Notify VoiceOver
    notifyVoiceOverStateChange()
  }
  
  /// Handle candidate selection with VoiceOver notification
  func selectCandidate(at index: Int) -> IMEState? {
    guard let state = getCandidateState(at: index) else { return nil }
    
    // Notify VoiceOver before returning
    notifyVoiceOverCandidateChange(highlightedIndex: index)
    
    return state
  }
  
  /// Handle composition update with VoiceOver notification
  func updateComposition() {
    // Update composer
    let compositionText = composer.value
    
    // Build new state
    let newState = buildInputtingState()
    
    // Transition to new state
    transitionToState(newState)
    
    // Notify VoiceOver of composition (this is redundant if transitionToState already calls notifyVoiceOverStateChange)
    // Only call if you want more specific composition announcements
    // notifyVoiceOverCompositionChange(text: compositionText, cursorPosition: composer.cursor)
  }
}
```

## Testing the Integration

### Manual Test Steps

1. **Enable VoiceOver**: Press Cmd+F5 or go to System Preferences > Accessibility > VoiceOver
2. **Launch vChewing**: Switch to vChewing input method
3. **Test in TextEdit**:
   - Open TextEdit
   - Type phonetic input (e.g., ㄘㄜˋ ㄕˋ)
   - Listen for VoiceOver announcements of composition
   - Press Space or arrow keys to show candidates
   - Navigate candidates with arrow keys
   - Listen for VoiceOver announcing each candidate with position
4. **Test Secure Input**:
   - Open a password field (e.g., in Safari or login screen)
   - Type with vChewing
   - Verify NO VoiceOver announcements are made
5. **Test Preference**:
   - Open vChewing preferences
   - Toggle "Enable VoiceOver announcements" off
   - Verify announcements stop
   - Toggle back on
   - Verify announcements resume

### Debug Logging

To add debug logging for testing:

```swift
extension VOSputnik {
  func debugLog(_ message: String) {
    #if DEBUG
      print("[VOSputnik] \(message)")
    #endif
  }
}
```

Add in key methods:

```swift
public func handle(session: InputSession) {
  debugLog("handle() called with state: \(session.state.type)")
  
  guard PrefMgr.shared.enableVoiceOverForCandidatesAndComposition else {
    debugLog("Feature disabled in preferences")
    return
  }
  
  // ... rest of method ...
}
```

## Troubleshooting

### VoiceOver not announcing

**Check**:
1. Is VoiceOver actually enabled? (Cmd+F5)
2. Is the preference enabled? (Check PrefMgr.shared.enableVoiceOverForCandidatesAndComposition)
3. Are you in a secure input field? (VOSputnik automatically disables)
4. Are the integration call sites added? (Check all 4 integration points above)

**Debug**:
- Add debug logging (see above)
- Check Console.app for any errors
- Verify `isVoiceOverEnabled` returns true

### Announcements too frequent

**Check**:
- Debounce interval might be too short (currently 200ms)
- Are you calling notification methods in a tight loop?

**Fix**:
- Increase debounce interval in VOSputnik.swift
- Ensure notifications only on actual state changes

### Candidate window still getting VoiceOver focus

**Check**:
- Was `configureForVoiceOverExclusion()` called on the window?
- Was it called after window is fully initialized?

**Fix**:
- Call `configureForVoiceOverExclusion()` in `windowDidLoad()` or after window creation
- Verify with Accessibility Inspector (Xcode > Open Developer Tool > Accessibility Inspector)

## Localization (Optional)

To add Chinese localization for the preference:

**File**: `Source/Resources/zh-Hant.lproj/Localizable.strings`

Add:

```
"Enable VoiceOver announcements for input" = "為輸入啟用 VoiceOver 播報";
"Announces candidate selections and composition changes to VoiceOver. Automatically disabled in password fields." = "向 VoiceOver 播報候選字選擇與組字內容變化。在密碼欄位中會自動停用。";
```

Then update metadata in UserDef.swift:

```swift
case .kEnableVoiceOverForCandidatesAndComposition: return .init(
    userDef: self, 
    shortTitle: NSLocalizedString("Enable VoiceOver announcements for input", comment: ""),
    description: NSLocalizedString("Announces candidate selections and composition changes to VoiceOver. Automatically disabled in password fields.", comment: "")
  )
```

## Performance Considerations

- Announcements are debounced (200ms), so rapid state changes won't spam VoiceOver
- All accessibility calls run on main thread via `asyncOnMain`
- Minimal CPU overhead when VoiceOver is disabled
- Zero overhead when preference is disabled

## Maintenance

When adding new IMEState types:
1. Update `generateAnnouncement(for:session:)` in VOSputnik.swift
2. Add test cases in VOSputnikTests.swift
3. Update documentation

When adding new emoji/special chars:
1. Update `processForSpeech(_:)` mapping tables
2. Consider adding to a separate data file for easier maintenance

## Summary

The integration requires:
1. ✅ Add `updateVoiceOver()` call after state transitions
2. ✅ Add `updateVoiceOverForCandidateChange(highlightedIndex:)` on candidate selection
3. ✅ Add `updateVoiceOverForComposition(compositionText:cursorPosition:)` on composition changes (optional if state changes cover this)
4. ✅ Add `configureForVoiceOverExclusion()` to candidate window initialization
5. ✅ Add preference toggle in Settings UI

All the core VOSputnik code is complete. These integration points connect it to the existing application flow.
