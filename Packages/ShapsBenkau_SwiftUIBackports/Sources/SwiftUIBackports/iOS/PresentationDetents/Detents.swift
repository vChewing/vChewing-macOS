// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
@available(tvOS, deprecated: 16)
@available(macOS, deprecated: 13)
@available(watchOS, deprecated: 9)
extension Backport where Wrapped: View {
  /// Sets the available detents for the enclosing sheet.
  ///
  /// By default, sheets support the ``PresentationDetent/large`` detent.
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
  ///                     .presentationDetents([.medium, .large])
  ///             }
  ///         }
  ///     }
  ///
  /// - Parameter detents: A set of supported detents for the sheet.
  ///   If you provide more than one detent, people can drag the sheet
  ///   to resize it.
  @ViewBuilder
  @available(iOS, introduced: 15, deprecated: 16, message: "Presentation detents are only supported in iOS 15+")
  public func presentationDetents(_ detents: Set<Backport<Any>.PresentationDetent>) -> some View {
    #if os(iOS)
      content.background(Backport<Any>.Representable(detents: detents, selection: nil, largestUndimmed: .large))
    #else
      content
    #endif
  }

  @available(macOS 10.15, *)
  /// Sets the available detents for the enclosing sheet, giving you
  /// programmatic control of the currently selected detent.
  ///
  /// By default, sheets support the ``PresentationDetent/large`` detent.
  ///
  ///     struct ContentView: View {
  ///         @State private var showSettings = false
  ///         @State private var settingsDetent = PresentationDetent.medium
  ///
  ///         var body: some View {
  ///             Button("View Settings") {
  ///                 showSettings = true
  ///             }
  ///             .sheet(isPresented: $showSettings) {
  ///                 SettingsView()
  ///                     .presentationDetents:(
  ///                         [.medium, .large],
  ///                         selection: $settingsDetent
  ///                      )
  ///             }
  ///         }
  ///     }
  ///
  /// - Parameters:
  ///   - detents: A set of supported detents for the sheet.
  ///     If you provide more that one detent, people can drag the sheet
  ///     to resize it.
  ///   - selection: A ``Binding`` to the currently selected detent.
  ///     Ensure that the value matches one of the detents that you
  ///     provide for the `detents` parameter.
  @ViewBuilder
  @available(iOS, introduced: 15, deprecated: 16, message: "Presentation detents are only supported in iOS 15+")
  public func presentationDetents(
    _ detents: Set<Backport<Any>.PresentationDetent>, selection: Binding<Backport<Any>.PresentationDetent>
  ) -> some View {
    #if os(iOS)
      content.background(Backport<Any>.Representable(detents: detents, selection: selection, largestUndimmed: .large))
    #else
      content
    #endif
  }

  @available(macOS 10.15, *)
  /// Sets the available detents for the enclosing sheet, giving you
  /// programmatic control of the currently selected detent.
  ///
  /// By default, sheets support the ``PresentationDetent/large`` detent.
  ///
  ///     struct ContentView: View {
  ///         @State private var showSettings = false
  ///         @State private var settingsDetent = PresentationDetent.medium
  ///
  ///         var body: some View {
  ///             Button("View Settings") {
  ///                 showSettings = true
  ///             }
  ///             .sheet(isPresented: $showSettings) {
  ///                 SettingsView()
  ///                     .presentationDetents:(
  ///                         [.medium, .large],
  ///                         selection: $settingsDetent
  ///                      )
  ///             }
  ///         }
  ///     }
  ///
  /// - Parameters:
  ///   - detents: A set of supported detents for the sheet.
  ///     If you provide more that one detent, people can drag the sheet
  ///     to resize it.
  ///   - selection: A ``Binding`` to the currently selected detent.
  ///     Ensure that the value matches one of the detents that you
  ///     provide for the `detents` parameter.
  @ViewBuilder
  @available(iOS, introduced: 15, deprecated: 16, message: "Presentation detents are only supported in iOS 15+")
  public func presentationDetents(
    _ detents: Set<Backport<Any>.PresentationDetent>, selection: Binding<Backport<Any>.PresentationDetent>,
    largestUndimmedDetent: Backport<Any>.PresentationDetent? = nil
  ) -> some View {
    #if os(iOS)
      content.background(
        Backport<Any>.Representable(detents: detents, selection: selection, largestUndimmed: largestUndimmedDetent))
    #else
      content
    #endif
  }
}

@available(macOS 10.15, *)
@available(iOS, deprecated: 16)
@available(tvOS, deprecated: 16)
@available(macOS, deprecated: 13)
@available(watchOS, deprecated: 9)
extension Backport where Wrapped == Any {
  /// A type that represents a height where a sheet naturally rests.
  public struct PresentationDetent: Hashable, Comparable {
    public struct Identifier: RawRepresentable, Hashable {
      public var rawValue: String
      public init(rawValue: String) {
        self.rawValue = rawValue
      }

      @available(macOS 10.15, *)
      public static var medium: Identifier {
        .init(rawValue: "com.apple.UIKit.medium")
      }

      @available(macOS 10.15, *)
      public static var large: Identifier {
        .init(rawValue: "com.apple.UIKit.large")
      }
    }

    @available(macOS 10.15, *)
    public let id: Identifier

    @available(macOS 10.15, *)
    /// The system detent for a sheet that's approximately half the height of
    /// the screen, and is inactive in compact height.
    public static var medium: PresentationDetent {
      .init(id: .medium)
    }

    @available(macOS 10.15, *)
    /// The system detent for a sheet at full height.
    public static var large: PresentationDetent {
      .init(id: .large)
    }

    @available(macOS 10.15, *)
    fileprivate static var none: PresentationDetent {
      .init(id: .init(rawValue: ""))
    }

    @available(macOS 10.15, *)
    public static func < (lhs: PresentationDetent, rhs: PresentationDetent) -> Bool {
      switch (lhs, rhs) {
        case (.large, .medium):
          return false
        default:
          return true
      }
    }
  }
}

#if os(iOS)
  @available(iOS 15, *)
  extension Backport where Wrapped == Any {
    fileprivate struct Representable: UIViewControllerRepresentable {
      let detents: Set<Backport<Any>.PresentationDetent>
      let selection: Binding<Backport<Any>.PresentationDetent>?
      let largestUndimmed: Backport<Any>.PresentationDetent?

      func makeUIViewController(context _: Context) -> Backport.Representable.Controller {
        Controller(detents: detents, selection: selection, largestUndimmed: largestUndimmed)
      }

      func updateUIViewController(_ controller: Backport.Representable.Controller, context _: Context) {
        controller.update(detents: detents, selection: selection, largestUndimmed: largestUndimmed)
      }
    }
  }

  @available(macOS 10.15, *)
  @available(iOS 15, *)
  extension Backport.Representable {
    fileprivate final class Controller: UIViewController, UISheetPresentationControllerDelegate {
      var detents: Set<Backport<Any>.PresentationDetent>
      var selection: Binding<Backport<Any>.PresentationDetent>?
      var largestUndimmed: Backport<Any>.PresentationDetent?
      weak var _delegate: UISheetPresentationControllerDelegate?

      @available(macOS 10.15, *)
      init(
        detents: Set<Backport<Any>.PresentationDetent>, selection: Binding<Backport<Any>.PresentationDetent>?,
        largestUndimmed: Backport<Any>.PresentationDetent?
      ) {
        self.detents = detents
        self.selection = selection
        self.largestUndimmed = largestUndimmed
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
        if let controller = parent?.sheetPresentationController {
          if controller.delegate !== self {
            _delegate = controller.delegate
            controller.delegate = self
          }
        }
        update(detents: detents, selection: selection, largestUndimmed: largestUndimmed)
      }

      @available(macOS 10.15, *)
      func update(
        detents: Set<Backport<Any>.PresentationDetent>, selection: Binding<Backport<Any>.PresentationDetent>?,
        largestUndimmed: Backport<Any>.PresentationDetent?
      ) {
        self.detents = detents
        self.selection = selection
        self.largestUndimmed = largestUndimmed

        if let controller = parent?.sheetPresentationController {
          controller.animateChanges {
            controller.detents = detents.sorted().map {
              switch $0 {
                case .medium:
                  return .medium()
                default:
                  return .large()
              }
            }

            controller.largestUndimmedDetentIdentifier = largestUndimmed.flatMap {
              .init(rawValue: $0.id.rawValue)
            }

            if let selection = selection {
              controller.selectedDetentIdentifier = .init(selection.wrappedValue.id.rawValue)
            }

            controller.prefersScrollingExpandsWhenScrolledToEdge = true
          }

          UIView.animate(withDuration: 0.25) {
            if let undimmed = largestUndimmed {
              controller.presentingViewController.view.tintAdjustmentMode =
                (selection?.wrappedValue ?? .large) >= undimmed ? .automatic : .normal
            } else {
              controller.presentingViewController.view.tintAdjustmentMode = .automatic
            }
          }
        }
      }

      @available(macOS 10.15, *)
      func sheetPresentationControllerDidChangeSelectedDetentIdentifier(
        _ sheetPresentationController: UISheetPresentationController
      ) {
        guard
          let selection = selection,
          let id = sheetPresentationController.selectedDetentIdentifier?.rawValue,
          selection.wrappedValue.id.rawValue != id
        else { return }

        selection.wrappedValue = .init(id: .init(rawValue: id))
      }

      @available(macOS 10.15, *)
      override func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) { return true }
        if _delegate?.responds(to: aSelector) ?? false { return true }
        return false
      }

      @available(macOS 10.15, *)
      override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if super.responds(to: aSelector) { return self }
        return _delegate
      }
    }
  }
#endif
