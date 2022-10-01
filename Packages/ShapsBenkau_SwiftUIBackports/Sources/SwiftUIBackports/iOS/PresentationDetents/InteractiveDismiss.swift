// (c) 2022 and onwards Shaps Benkau (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

import SwiftUI

@available(macOS 10.15, *)
extension Backport where Wrapped: View {
  /// Conditionally prevents interactive dismissal of a popover or a sheet.
  ///
  /// Users can dismiss certain kinds of presentations using built-in
  /// gestures. In particular, a user can dismiss a sheet by dragging it down,
  /// or a popover by clicking or tapping outside of the presented view. Use
  /// the `interactiveDismissDisabled(_:)` modifier to conditionally prevent
  /// this kind of dismissal. You typically do this to prevent the user from
  /// dismissing a presentation before providing needed data or completing
  /// a required action.
  ///
  /// For instance, suppose you have a view that displays a licensing
  /// agreement that the user must acknowledge before continuing:
  ///
  ///     struct TermsOfService: View {
  ///         @Binding var areTermsAccepted: Bool
  ///         @Environment(\.backportDismiss) private var dismiss
  ///
  ///         var body: some View {
  ///             Form {
  ///                 Text("License Agreement")
  ///                     .font(.title)
  ///                 Text("Terms and conditions go here.")
  ///                 Button("Accept") {
  ///                     areTermsAccepted = true
  ///                     dismiss()
  ///                 }
  ///             }
  ///         }
  ///     }
  ///
  /// If you present this view in a sheet, the user can dismiss it by either
  /// tapping the button --- which calls ``EnvironmentValues/backportDismiss``
  /// from its `action` closure --- or by dragging the sheet down. To
  /// ensure that the user accepts the terms by tapping the button,
  /// disable interactive dismissal, conditioned on the `areTermsAccepted`
  /// property:
  ///
  ///     struct ContentView: View {
  ///         @State private var isSheetPresented = false
  ///         @State private var areTermsAccepted = false
  ///
  ///         var body: some View {
  ///             Button("Use Service") {
  ///                 isSheetPresented = true
  ///             }
  ///             .sheet(isPresented: $isSheetPresented) {
  ///                 TermsOfService()
  ///                     .backport.interactiveDismissDisabled(!areTermsAccepted)
  ///             }
  ///         }
  ///     }
  ///
  /// You can apply the modifier to any view in the sheet's view hierarchy,
  /// including to the sheet's top level view, as the example demonstrates,
  /// or to any child view, like the ``Form`` or the Accept ``Button``.
  ///
  /// The modifier has no effect on programmatic dismissal, which you can
  /// invoke by updating the ``Binding`` that controls the presentation, or
  /// by calling the environment's ``EnvironmentValues/backportDismiss`` action.
  ///
  /// > This modifier currently has no effect on macOS, tvOS or watchOS.
  ///
  /// - Parameter isDisabled: A Boolean value that indicates whether to
  ///   prevent nonprogrammatic dismissal of the containing view hierarchy
  ///   when presented in a sheet or popover.
  @ViewBuilder
  @available(iOS, deprecated: 16)
  @available(tvOS, deprecated: 16)
  @available(macOS, deprecated: 13)
  @available(watchOS, deprecated: 9)
  public func interactiveDismissDisabled(_ isDisabled: Bool = true) -> some View {
    #if os(iOS)
      if #available(iOS 15, *) {
        content.background(Backport<Any>.Representable(isModal: isDisabled, onAttempt: nil))
      } else {
        content
      }
    #else
      content
    #endif
  }

  @available(macOS 10.15, *)
  /// Conditionally prevents interactive dismissal of a popover or a sheet. In addition, provides fine-grained control over the dismissal
  ///
  /// Users can dismiss certain kinds of presentations using built-in
  /// gestures. In particular, a user can dismiss a sheet by dragging it down,
  /// or a popover by clicking or tapping outside of the presented view. Use
  /// the `interactiveDismissDisabled(_:)` modifier to conditionally prevent
  /// this kind of dismissal. You typically do this to prevent the user from
  /// dismissing a presentation before providing needed data or completing
  /// a required action.
  ///
  /// For instance, suppose you have a view that displays a licensing
  /// agreement that the user must acknowledge before continuing:
  ///
  ///     struct TermsOfService: View {
  ///         @Binding var areTermsAccepted: Bool
  ///         @Environment(\.backportDismiss) private var dismiss
  ///
  ///         var body: some View {
  ///             Form {
  ///                 Text("License Agreement")
  ///                     .font(.title)
  ///                 Text("Terms and conditions go here.")
  ///                 Button("Accept") {
  ///                     areTermsAccepted = true
  ///                     dismiss()
  ///                 }
  ///             }
  ///         }
  ///     }
  ///
  /// If you present this view in a sheet, the user can dismiss it by either
  /// tapping the button --- which calls ``EnvironmentValues/backportDismiss``
  /// from its `action` closure --- or by dragging the sheet down. To
  /// ensure that the user accepts the terms by tapping the button,
  /// disable interactive dismissal, conditioned on the `areTermsAccepted`
  /// property:
  ///
  ///     struct ContentView: View {
  ///         @State private var isSheetPresented = false
  ///         @State private var areTermsAccepted = false
  ///
  ///         var body: some View {
  ///             Button("Use Service") {
  ///                 isSheetPresented = true
  ///             }
  ///             .sheet(isPresented: $isSheetPresented) {
  ///                 TermsOfService()
  ///                     .backport.interactiveDismissDisabled(!areTermsAccepted)
  ///             }
  ///         }
  ///     }
  ///
  /// You can apply the modifier to any view in the sheet's view hierarchy,
  /// including to the sheet's top level view, as the example demonstrates,
  /// or to any child view, like the ``Form`` or the Accept ``Button``.
  ///
  /// The modifier has no effect on programmatic dismissal, which you can
  /// invoke by updating the ``Binding`` that controls the presentation, or
  /// by calling the environment's ``EnvironmentValues/backportDismiss`` action.
  ///
  /// > This modifier currently has no effect on macOS, tvOS or watchOS.
  ///
  /// - Parameter isDisabled: A Boolean value that indicates whether to
  ///   prevent nonprogrammatic dismissal of the containing view hierarchy
  ///   when presented in a sheet or popover.
  /// - Parameter onAttempt: A closure that will be called when an interactive dismiss attempt occurs.
  ///   You can use this as an opportunity to present an confirmation or prompt to the user.
  @ViewBuilder
  public func interactiveDismissDisabled(_ isDisabled: Bool = true, onAttempt: @escaping () -> Void) -> some View {
    #if os(iOS)
      if #available(iOS 15, *) {
        content.background(Backport<Any>.Representable(isModal: isDisabled, onAttempt: onAttempt))
      } else {
        content
      }
    #else
      content
    #endif
  }
}

#if os(iOS)
  @available(macOS 10.15, *)
  extension Backport where Wrapped == Any {
    fileprivate struct Representable: UIViewControllerRepresentable {
      let isModal: Bool
      let onAttempt: (() -> Void)?

      @available(macOS 10.15, *)
      func makeUIViewController(context _: Context) -> Backport.Representable.Controller {
        Controller(isModal: isModal, onAttempt: onAttempt)
      }

      @available(macOS 10.15, *)
      func updateUIViewController(_ controller: Backport.Representable.Controller, context _: Context) {
        controller.update(isModal: isModal, onAttempt: onAttempt)
      }
    }
  }

  @available(macOS 10.15, *)
  extension Backport.Representable {
    fileprivate final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
      var isModal: Bool
      var onAttempt: (() -> Void)?
      weak var _delegate: UIAdaptivePresentationControllerDelegate?

      @available(macOS 10.15, *)
      init(isModal: Bool, onAttempt: (() -> Void)?) {
        self.isModal = isModal
        self.onAttempt = onAttempt
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
        if let controller = parent?.presentationController {
          if controller.delegate !== self {
            _delegate = controller.delegate
            controller.delegate = self
          }
        }
        update(isModal: isModal, onAttempt: onAttempt)
      }

      @available(macOS 10.15, *)
      func update(isModal: Bool, onAttempt: (() -> Void)?) {
        self.isModal = isModal
        self.onAttempt = onAttempt

        parent?.isModalInPresentation = isModal
      }

      @available(macOS 10.15, *)
      func presentationControllerDidAttemptToDismiss(_: UIPresentationController) {
        onAttempt?()
      }

      @available(macOS 10.15, *)
      func presentationControllerShouldDismiss(_: UIPresentationController) -> Bool {
        parent?.isModalInPresentation == false
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
