// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(iOS, deprecated: 14)
@available(macOS, deprecated: 11)
@available(tvOS, deprecated: 14.0)
@available(watchOS, deprecated: 7.0)
extension Backport where Wrapped == Any {
  /// A progress view that visually indicates its progress using a horizontal bar.
  ///
  /// You can also use ``ProgressViewStyle/linear`` to construct this style.
  public struct LinearProgressViewStyle: BackportProgressViewStyle {
    /// Creates a linear progress view style.
    public init() {}

    /// Creates a view representing the body of a progress view.
    ///
    /// - Parameter configuration: The properties of the progress view being
    ///   created.
    ///
    /// The view hierarchy calls this method for each progress view where this
    /// style is the current progress view style.
    ///
    /// - Parameter configuration: The properties of the progress view, such as
    ///  its preferred progress type.
    @available(macOS 10.15, *)
    public func makeBody(configuration: Configuration) -> some View {
      #if os(macOS)
        VStack(alignment: .leading, spacing: 0) {
          configuration.label
            .foregroundColor(.primary)

          LinearRepresentable(configuration: configuration)

          configuration.currentValueLabel
            .foregroundColor(.secondary)
        }
        .controlSize(.small)
      #else
        VStack(alignment: .leading, spacing: 5) {
          if configuration.fractionCompleted == nil {
            CircularProgressViewStyle().makeBody(configuration: configuration)
          } else {
            configuration.label?
              .foregroundColor(.primary)

            #if !os(watchOS)
              LinearRepresentable(configuration: configuration)
            #endif

            configuration.currentValueLabel?
              .foregroundColor(.secondary)
              .font(.caption)
          }
        }
      #endif
    }
  }
}

@available(macOS 10.15, *)
extension BackportProgressViewStyle where Self == Backport<Any>.LinearProgressViewStyle {
  public static var linear: Self { .init() }
}

#if os(macOS)
  @available(macOS 10.15, *)
  private struct LinearRepresentable: NSViewRepresentable {
    let configuration: Backport<Any>.ProgressViewStyleConfiguration

    @available(macOS 10.15, *)
    func makeNSView(context _: Context) -> NSProgressIndicator {
      .init()
    }

    @available(macOS 10.15, *)
    func updateNSView(_ view: NSProgressIndicator, context _: Context) {
      if let value = configuration.fractionCompleted {
        view.doubleValue = value
        view.maxValue = configuration.max

        view.display()
      }

      view.style = .bar
      view.isIndeterminate = configuration.fractionCompleted == nil
      view.isDisplayedWhenStopped = true
      view.startAnimation(nil)
    }
  }

#elseif !os(watchOS)
  @available(macOS 10.15, *)
  private struct LinearRepresentable: UIViewRepresentable {
    let configuration: Backport<Any>.ProgressViewStyleConfiguration

    @available(macOS 10.15, *)
    func makeUIView(context _: Context) -> UIProgressView {
      .init(progressViewStyle: .default)
    }

    @available(macOS 10.15, *)
    func updateUIView(_ view: UIProgressView, context _: Context) {
      view.progress = Float(configuration.fractionCompleted ?? 0)
    }
  }
#endif
