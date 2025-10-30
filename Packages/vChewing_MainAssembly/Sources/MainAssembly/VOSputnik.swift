// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(AppKit)
  import AppKit
  import Foundation

  // MARK: - VOCandidate

  /// Represents a VoiceOver candidate with display and speech content.
  public struct VOCandidate {
    /// The text to display in VoiceOver.
    public let display: String
    /// Optional override for speech output. If nil, uses display text.
    public let speechOverride: String?
    /// Optional metadata for additional context.
    public let metadata: [String: Any]?

    /// The effective speech text (using speechOverride if available, otherwise display).
    public var effectiveSpeech: String {
      speechOverride ?? display
    }

    public init(display: String, speechOverride: String? = nil, metadata: [String: Any]? = nil) {
      self.display = display
      self.speechOverride = speechOverride
      self.metadata = metadata
    }
  }

  // MARK: - VOSputnik

  /// VoiceOver integration singleton for vChewing.
  /// Manages all VoiceOver announcements for input states, candidates, and composition.
  public final class VOSputnik {
    // MARK: Lifecycle

    private init() {
      // Initialize debounce timer
      debounceTimer = nil
      lastAnnouncementTime = Date.distantPast
    }

    // MARK: Public

    /// Shared singleton instance.
    public static let shared = VOSputnik()

    /// Handle session state changes and announce appropriate content to VoiceOver.
    /// - Parameter session: The current input session.
    public func handle(session: InputSession) {
      // Check if feature is enabled in preferences
      guard PrefMgr.shared.enableVoiceOverForCandidatesAndComposition else { return }

      // Check if VoiceOver is enabled
      guard isVoiceOverEnabled else { return }

      // Check SecureEventInput status for privacy
      if isSecureInputActive {
        return
      }

      // Get the current state
      let state = session.state

      // Generate announcement based on state type
      let announcement = generateAnnouncement(for: state, session: session)

      if let announcement = announcement {
        scheduleAnnouncement(announcement)
      }
    }

    /// Announce candidate selection change.
    /// - Parameters:
    ///   - candidates: List of candidates with their keys and values.
    ///   - highlightedIndex: The index of the currently highlighted candidate.
    public func announceCandidateChange(
      candidates: [(keyArray: [String], value: String)],
      highlightedIndex: Int
    ) {
      guard PrefMgr.shared.enableVoiceOverForCandidatesAndComposition else { return }
      guard isVoiceOverEnabled else { return }
      guard !isSecureInputActive else { return }

      guard highlightedIndex >= 0 && highlightedIndex < candidates.count else { return }

      let candidate = candidates[highlightedIndex]
      let candidateText = candidate.value
      let position = "\(highlightedIndex + 1) / \(candidates.count)"

      let displayText = "\(candidateText), \(position)"
      let speechText = processForSpeech(candidateText) + ", " + position

      let voCandidate = VOCandidate(
        display: displayText,
        speechOverride: speechText,
        metadata: ["index": highlightedIndex, "total": candidates.count]
      )

      scheduleAnnouncement(voCandidate)
    }

    /// Announce composition content (phonabet or input).
    /// - Parameters:
    ///   - compositionText: The text being composed.
    ///   - cursorPosition: Optional cursor position within the composition.
    public func announceComposition(compositionText: String, cursorPosition: Int? = nil) {
      guard PrefMgr.shared.enableVoiceOverForCandidatesAndComposition else { return }
      guard isVoiceOverEnabled else { return }
      guard !isSecureInputActive else { return }

      let displayText: String
      let speechText: String

      if let cursorPosition = cursorPosition {
        displayText = "\(compositionText), cursor at \(cursorPosition)"
        speechText = processForSpeech(compositionText) + ", 游標在 \(cursorPosition)"
      } else {
        displayText = compositionText
        speechText = processForSpeech(compositionText)
      }

      let announcement = VOCandidate(
        display: displayText,
        speechOverride: speechText
      )

      scheduleAnnouncement(announcement)
    }

    // MARK: Internal

    /// Check if VoiceOver is currently enabled.
    var isVoiceOverEnabled: Bool {
      #if canImport(AppKit)
        return NSWorkspace.shared.isVoiceOverEnabled
      #else
        return false
      #endif
    }

    /// Check if SecureEventInput is active (e.g., password field).
    var isSecureInputActive: Bool {
      #if canImport(AppKit)
        return IsSecureEventInputEnabled()
      #else
        return false
      #endif
    }

    // MARK: Private

    private var debounceTimer: Timer?
    private var lastAnnouncementTime: Date
    private var pendingAnnouncement: VOCandidate?
    private let debounceInterval: TimeInterval = 0.2 // 200ms

    /// Generate announcement content based on state type.
    private func generateAnnouncement(for state: IMEState, session: InputSession) -> VOCandidate? {
      switch state.type {
      case .ofInputting:
        // Announce composition content
        let compositionText = state.displayedText
        if compositionText.isEmpty { return nil }

        return VOCandidate(
          display: compositionText,
          speechOverride: processForSpeech(compositionText)
        )

      case .ofCandidates:
        // This is handled by announceCandidateChange
        return nil

      case .ofCommitting:
        // Announce committed text
        let committedText = state.textToCommit
        if committedText.isEmpty { return nil }

        return VOCandidate(
          display: "Committed: \(committedText)",
          speechOverride: "已輸入: " + processForSpeech(committedText)
        )

      case .ofEmpty, .ofDeactivated, .ofAbortion:
        // No announcement needed
        return nil

      case .ofMarking:
        // Announce marking state
        let markedText = state.displayedText
        if markedText.isEmpty { return nil }

        return VOCandidate(
          display: "Marking: \(markedText)",
          speechOverride: "標記: " + processForSpeech(markedText)
        )

      case .ofAssociates:
        // Announce associate candidates available
        if state.candidates.isEmpty { return nil }
        return VOCandidate(
          display: "Associated phrases available",
          speechOverride: "有關聯詞組可選擇"
        )

      case .ofSymbolTable:
        // Announce symbol table available
        return VOCandidate(
          display: "Symbol table available",
          speechOverride: "符號表已開啟"
        )
      }
    }

    /// Process text for speech, handling special characters and emojis.
    private func processForSpeech(_ text: String) -> String {
      var result = text

      // Replace common emojis with descriptions
      let emojiReplacements: [String: String] = [
        "😀": "笑臉",
        "😊": "微笑",
        "😂": "笑哭",
        "❤️": "愛心",
        "👍": "讚",
        "👎": "不讚",
        "🎉": "慶祝",
        "🎊": "彩帶",
        "✅": "勾選",
        "❌": "叉號",
        "⭐": "星星",
        "🔥": "火焰",
        "💯": "一百分",
      ]

      for (emoji, description) in emojiReplacements {
        result = result.replacingOccurrences(of: emoji, with: description)
      }

      // Handle phonetic symbols (Zhuyin/Bopomofo)
      let phonticsMap: [String: String] = [
        "ㄅ": "ㄅ玻",
        "ㄆ": "ㄆ坡",
        "ㄇ": "ㄇ摸",
        "ㄈ": "ㄈ佛",
        "ㄉ": "ㄉ得",
        "ㄊ": "ㄊ特",
        "ㄋ": "ㄋ呢",
        "ㄌ": "ㄌ勒",
        "ㄍ": "ㄍ哥",
        "ㄎ": "ㄎ科",
        "ㄏ": "ㄏ喝",
        "ㄐ": "ㄐ基",
        "ㄑ": "ㄑ欺",
        "ㄒ": "ㄒ希",
        "ㄓ": "ㄓ知",
        "ㄔ": "ㄔ吃",
        "ㄕ": "ㄕ詩",
        "ㄖ": "ㄖ日",
        "ㄗ": "ㄗ資",
        "ㄘ": "ㄘ雌",
        "ㄙ": "ㄙ思",
        "ㄧ": "ㄧ衣",
        "ㄨ": "ㄨ烏",
        "ㄩ": "ㄩ迂",
        "ㄚ": "ㄚ啊",
        "ㄛ": "ㄛ喔",
        "ㄜ": "ㄜ鵝",
        "ㄝ": "ㄝ耶",
        "ㄞ": "ㄞ哀",
        "ㄟ": "ㄟ诶",
        "ㄠ": "ㄠ熬",
        "ㄡ": "ㄡ歐",
        "ㄢ": "ㄢ安",
        "ㄣ": "ㄣ恩",
        "ㄤ": "ㄤ昂",
        "ㄥ": "ㄥ亨的韻",
        "ㄦ": "ㄦ兒",
      ]

      // Only replace phonetics if the entire text is phonetic symbols
      if result.allSatisfy({ phonticsMap.keys.contains(String($0)) || "ˊˇˋ˙".contains($0) }) {
        var speechResult = ""
        for char in result {
          if let phonetic = phonticsMap[String(char)] {
            speechResult += phonetic
          } else {
            speechResult += String(char)
          }
        }
        result = speechResult
      }

      return result
    }

    /// Schedule an announcement with debouncing to prevent spam.
    private func scheduleAnnouncement(_ announcement: VOCandidate) {
      // Cancel existing timer
      debounceTimer?.invalidate()

      // Store pending announcement
      pendingAnnouncement = announcement

      // Create new timer
      debounceTimer = Timer.scheduledTimer(
        withTimeInterval: debounceInterval,
        repeats: false
      ) { [weak self] _ in
        self?.performAnnouncement()
      }
    }

    /// Perform the actual VoiceOver announcement.
    private func performAnnouncement() {
      guard let announcement = pendingAnnouncement else { return }

      // Ensure we're on main thread
      asyncOnMain {
        #if canImport(AppKit)
          // Post VoiceOver announcement
          NSAccessibility.post(
            element: NSApp,
            notification: .announcementRequested,
            userInfo: [
              .announcement: announcement.display,
              .priority: NSAccessibilityPriorityLevel.medium.rawValue,
            ]
          )
        #endif

        self.lastAnnouncementTime = Date()
        self.pendingAnnouncement = nil
      }
    }

    /// Configure candidate window and its subviews to be hidden from VoiceOver.
    public static func configureAccessibilityExclusion(for window: NSWindow) {
      asyncOnMain {
        // Hide window from VoiceOver focus
        window.isAccessibilityElement = false
        window.accessibilityRole = .unknown

        // Recursively hide all subviews
        func hideSubviews(_ view: NSView) {
          view.isAccessibilityElement = false
          for subview in view.subviews {
            hideSubviews(subview)
          }
        }

        if let contentView = window.contentView {
          hideSubviews(contentView)
        }
      }
    }
  }
#endif
