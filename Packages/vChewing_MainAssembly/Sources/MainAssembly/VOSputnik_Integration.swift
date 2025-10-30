// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(AppKit)
  import Foundation

  // MARK: - InputSession VoiceOver Integration

  extension InputSession {
    /// Update VoiceOver with the current state.
    /// Call this method whenever the IME state changes.
    public func updateVoiceOver() {
      VOSputnik.shared.handle(session: self)
    }

    /// Update VoiceOver when candidate selection changes.
    /// - Parameter highlightedIndex: The newly highlighted candidate index.
    public func updateVoiceOverForCandidateChange(highlightedIndex: Int) {
      guard state.isCandidateContainer else { return }

      // Get candidates from state
      let candidates: [(keyArray: [String], value: String)]

      switch state.type {
      case .ofCandidates, .ofAssociates, .ofInputting:
        candidates = state.candidates
      case .ofSymbolTable:
        candidates = state.node.members.map { ([""], $0.name) }
      default:
        return
      }

      VOSputnik.shared.announceCandidateChange(
        candidates: candidates,
        highlightedIndex: highlightedIndex
      )
    }

    /// Update VoiceOver with composition content.
    /// - Parameters:
    ///   - compositionText: The current composition text.
    ///   - cursorPosition: Optional cursor position.
    public func updateVoiceOverForComposition(
      compositionText: String,
      cursorPosition: Int? = nil
    ) {
      VOSputnik.shared.announceComposition(
        compositionText: compositionText,
        cursorPosition: cursorPosition
      )
    }
  }

  // MARK: - InputHandler VoiceOver Integration

  extension InputHandler {
    /// Notify VoiceOver of state changes.
    /// This should be called after state transitions in the handler.
    public func notifyVoiceOverStateChange() {
      guard let session = session else { return }
      session.updateVoiceOver()
    }

    /// Notify VoiceOver of candidate changes.
    /// - Parameter highlightedIndex: The newly highlighted candidate index.
    public func notifyVoiceOverCandidateChange(highlightedIndex: Int) {
      guard let session = session else { return }
      session.updateVoiceOverForCandidateChange(highlightedIndex: highlightedIndex)
    }

    /// Notify VoiceOver of composition changes.
    /// - Parameters:
    ///   - text: The composition text from composer.
    ///   - cursorPosition: Optional cursor position.
    public func notifyVoiceOverCompositionChange(text: String, cursorPosition: Int? = nil) {
      guard let session = session else { return }
      session.updateVoiceOverForComposition(
        compositionText: text,
        cursorPosition: cursorPosition
      )
    }
  }

  // MARK: - Candidate Window VoiceOver Integration

  extension NSWindow {
    /// Configure this window to be excluded from VoiceOver focus.
    /// This should be called when initializing candidate windows.
    public func configureForVoiceOverExclusion() {
      VOSputnik.configureAccessibilityExclusion(for: self)
    }
  }
#endif
