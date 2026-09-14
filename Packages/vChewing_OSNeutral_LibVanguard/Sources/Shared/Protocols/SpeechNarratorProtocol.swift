// (c) 2022 and onwards The vChewing Project (LGPL v3.0 License or later).
// ====================
// This code is released under the SPDX-License-Identifier: `LGPL-3.0-or-later`.

/// A protocol defining the public interface for speech narration services.
public protocol SpeechNarratorProtocol {
  /// A shared instance of the speech narrator.
  static var shared: Self { get }

  /// Refreshes the status of the speech narrator, potentially pre-warming the engine based on preferences.
  func refreshStatus()

  /// Narrates the given text, optionally allowing duplicates.
  /// - Parameter text: The text to narrate.
  /// - Parameter allowDuplicates: Whether to allow narrating the same text consecutively (default: true).
  func narrate(_ text: String, allowDuplicates: Bool)
}
