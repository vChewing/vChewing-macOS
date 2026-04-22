// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftUI

// MARK: - ContentView

struct ContentView: View {
  // MARK: Internal

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("MainAssembly Profiling Harness")
        .font(.title2)
        .fontWeight(.semibold)

      Text("Runs the former pinyin profiling cases against the packaged factory lexicon without IMK client simulation.")
        .foregroundStyle(.secondary)

      Button(action: viewModel.runProfilingCases) {
        Text(viewModel.isRunning ? "Running..." : "Run Pinyin Profiling Cases")
          .frame(minWidth: 220)
      }
      .disabled(viewModel.isRunning)

      ScrollView {
        Text(viewModel.statusText)
          .font(.system(.body, design: .monospaced))
          .frame(maxWidth: .infinity, alignment: .leading)
          .textSelection(.enabled)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .padding(12)
      .background(Color(nsColor: .textBackgroundColor))
      .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
    .padding(20)
    .frame(minWidth: 640, minHeight: 360)
  }

  // MARK: Private

  @State
  private var viewModel = ProfilingViewModel()
}

// MARK: - ProfilingViewModel

@Observable
@MainActor
final class ProfilingViewModel {
  var isRunning = false
  var statusText = "Press the button to run the SHI control case and the YI hotspot case."

  func runProfilingCases() {
    guard !isRunning else { return }
    isRunning = true
    statusText = "Preparing profiling environment..."

    Task { @MainActor in
      defer {
        isRunning = false
        NSSound.beep()
      }

      do {
        let harness = PinyinProfilingHarness()
        let results = try harness.runAllScenarios()
        statusText = results.map(\.reportLine).joined(separator: "\n")
      } catch {
        statusText = error.localizedDescription
      }
    }
  }
}
