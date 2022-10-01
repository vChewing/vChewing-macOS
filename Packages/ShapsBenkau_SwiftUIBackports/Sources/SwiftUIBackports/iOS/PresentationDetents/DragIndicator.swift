// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(iOS, deprecated: 16)
@available(tvOS, deprecated: 16)
@available(macOS, deprecated: 13)
@available(watchOS, deprecated: 9)
extension Backport where Wrapped: View {
  /// Sets the visibility of the drag indicator on top of a sheet.
  ///
  /// You can show a drag indicator when it isn't apparent that a
  /// sheet can resize or when the sheet can't dismiss interactively.
  ///
  ///     struct ContentView: View {
  ///         @State private var showSettings = false
  ///
  ///         var body: some View {
  ///             Button("View Settings") {
  ///                 showSettings = true
  ///             }
  ///             .sheet(isPresented: $showSettings) {
  ///                 SettingsView()
  ///                     .presentationDetents:([.medium, .large])
  ///                     .presentationDragIndicator(.visible)
  ///             }
  ///         }
  ///     }
  ///
  /// - Parameter visibility: The preferred visibility of the drag indicator.
  @ViewBuilder
  public func presentationDragIndicator(_ visibility: Backport<Any>.Visibility) -> some View {
    #if os(iOS)
      if #available(iOS 15, *) {
        content.background(Backport<Any>.Representable(visibility: visibility))
      } else {
        content
      }
    #else
      content
    #endif
  }
}

#if os(iOS)
  @available(iOS 15, *)
  @available(macOS 10.15, *)
  extension Backport where Wrapped == Any {
    fileprivate struct Representable: UIViewControllerRepresentable {
      let visibility: Backport<Any>.Visibility

      func makeUIViewController(context _: Context) -> Backport.Representable.Controller {
        Controller(visibility: visibility)
      }

      func updateUIViewController(_ controller: Backport.Representable.Controller, context _: Context) {
        controller.update(visibility: visibility)
      }
    }
  }

  @available(macOS 10.15, *)
  @available(iOS 15, *)
  extension Backport.Representable {
    fileprivate final class Controller: UIViewController {
      var visibility: Backport<Any>.Visibility

      @available(macOS 10.15, *)
      init(visibility: Backport<Any>.Visibility) {
        self.visibility = visibility
        super.init(nibName: nil, bundle: nil)
      }

      @available(macOS 10.15, *)
      @available(*, unavailable)
      required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
      }

      @available(macOS 10.15, *)
      override func willMove(toParent parent: UIViewController?) {
        super.willMove(toParent: parent)
        update(visibility: visibility)
      }

      @available(macOS 10.15, *)
      func update(visibility: Backport<Any>.Visibility) {
        self.visibility = visibility

        if let controller = parent?.sheetPresentationController {
          controller.animateChanges {
            controller.prefersGrabberVisible = visibility == .visible
            controller.prefersScrollingExpandsWhenScrolledToEdge = true
          }
        }
      }
    }
  }
#endif
