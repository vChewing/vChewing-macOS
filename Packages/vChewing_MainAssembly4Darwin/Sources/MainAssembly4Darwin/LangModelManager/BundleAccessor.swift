// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import Foundation

// MARK: - _BundleFinder

/// Anchor class for `Bundle(for:)` resolution.
private class _BundleFinder {}

extension Foundation.Bundle {
  /// Resource bundle resolver that works in both SPM build directories
  /// and macOS `.app` bundles.
  ///
  /// SwiftPM's auto-generated `Bundle.module` only checks
  /// `Bundle.main.bundleURL` (the `.app/` root), but macOS code-signing
  /// forbids placing files there. Xcode's version also checks
  /// `Bundle.main.resourceURL` (`Contents/Resources/`).
  ///
  /// This property mirrors the Xcode-style lookup order so that the
  /// Makefile no longer needs to patch the auto-generated accessor.
  static let currentSPM: Bundle = {
    let bundleName = "MainAssembly4Darwin_MainAssembly4Darwin"
    let candidates: [URL?] = [
      // .app → Contents/Resources/ (standard macOS bundle location).
      Bundle.main.resourceURL,
      // Framework embedding.
      Bundle(for: _BundleFinder.self).resourceURL,
      // SPM build directory / command-line tools.
      Bundle.main.bundleURL,
    ]
    for candidate in candidates {
      guard let url = candidate?.appendingPathComponent(bundleName + ".bundle"),
            let bundle = Bundle(url: url) else { continue }
      return bundle
    }
    fatalError("unable to find bundle named \(bundleName)")
  }()
}
