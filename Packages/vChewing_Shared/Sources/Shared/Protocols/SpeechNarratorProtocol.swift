// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

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
