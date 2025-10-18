// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import AVFoundation
import Shared

// MARK: - SpeechSputnik

public final class SpeechSputnik: SpeechNarratorProtocol {
  // MARK: Public

  public static var shared: SpeechSputnik = .init()

  public func refreshStatus() {
    switch PrefMgr().readingNarrationCoverage {
    case 1, 2: narrate("　") // 讓語音引擎提前預熱。
    default: clear()
    }
  }

  // MARK: Private

  private static var tags: [String] = ["ting-ting", "zh-CN", "mei-jia", "zh-TW"]

  private var currentNarrator: NSObject?
  private var currentVoice: NSObject?

  private lazy var previouslyNarrated: String = ""

  private var narrator: NSObject? {
    get {
      currentNarrator = currentNarrator ?? generateNarrator()
      return currentNarrator
    }
    set {
      currentNarrator = newValue
    }
  }

  private var voiceSpecified: NSObject? {
    get {
      currentVoice = currentVoice ?? generateVoice()
      return currentVoice
    }
    set {
      currentVoice = newValue
    }
  }

  private func clear() {
    currentNarrator = nil
    currentVoice = nil
    previouslyNarrated = ""
  }
}

// MARK: - Generators.

extension SpeechSputnik {
  private func generateNarrator() -> NSObject? {
    guard #unavailable(macOS 14) else { return AVSpeechSynthesizer() }
    let voice = NSSpeechSynthesizer.availableVoices.first {
      // 這裡用 zh-CN 是因為 zh-TW 觸發的 voice 無法連讀某些注音。
      SpeechSputnik.tags.isOverlapped(with: $0.rawValue.components(separatedBy: "."))
    }
    guard let voice = voice else { return nil }
    let result = NSSpeechSynthesizer(voice: voice)
    result?.rate = 90
    return result
  }

  private func generateVoice() -> NSObject? {
    guard #available(macOS 14, *) else { return nil }
    // 這裡用 zh-CN 是因為 zh-TW 觸發的 voice 無法連讀某些注音。
    return AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.zh-CN.Binbin")
      ?? AVSpeechSynthesisVoice(identifier: "com.apple.voice.compact.zh-CN.Tingting")
      ?? .speechVoices().first {
        $0.identifier.contains("Tingting") || $0.language.contains("zh-CN") || $0.language
          .contains("zh-TW")
      }
  }
}

// MARK: - Public API.

extension SpeechSputnik {
  public func narrate(_ text: String, allowDuplicates: Bool = true) {
    defer { previouslyNarrated = text }
    guard !(!allowDuplicates && previouslyNarrated == text) else { return }
    if #available(macOS 14, *) {
      let utterance = AVSpeechUtterance(string: text)
      utterance.voice = voiceSpecified as? AVSpeechSynthesisVoice ?? utterance.voice
      utterance.rate = 0.55
      (narrator as? AVSpeechSynthesizer)?.stopSpeaking(at: .immediate)
      (narrator as? AVSpeechSynthesizer)?.speak(utterance)
    } else {
      (narrator as? NSSpeechSynthesizer)?.stopSpeaking(at: .immediateBoundary)
      (narrator as? NSSpeechSynthesizer)?.startSpeaking(text)
    }
  }
}
