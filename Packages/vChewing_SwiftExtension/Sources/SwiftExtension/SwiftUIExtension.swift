// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - Add "onChange" support.

// Ref: https://mjeld.com/swiftui-macos-10-15-toggle-onchange/

@available(macOS 10.15, *)
extension Binding {
  public func onChange(_ action: @escaping () -> Void) -> Binding {
    Binding(
      get: {
        wrappedValue
      },
      set: { newValue in
        wrappedValue = newValue
        action()
      }
    )
  }
}

// MARK: - Add ".tooltip" support.

// Ref: https://stackoverflow.com/a/63217861

@available(macOS 10.15, *)
@available(macOS, obsoleted: 11)
struct Tooltip: NSViewRepresentable {
  let tooltip: String

  func makeNSView(context _: NSViewRepresentableContext<Tooltip>) -> NSView {
    let view = NSView()
    view.toolTip = tooltip

    return view
  }

  func updateNSView(_: NSView, context _: NSViewRepresentableContext<Tooltip>) {}
}

@available(macOS 10.15, *)
@available(macOS, obsoleted: 11)
extension View {
  public func help(_ tooltip: String) -> some View {
    overlay(Tooltip(tooltip: tooltip))
  }
}

// MARK: - Windows Aero in Swift UI

// Ref: https://stackoverflow.com/questions/62461957

@available(macOS 10.15, *)
public struct VisualEffectView: NSViewRepresentable {
  let material: NSVisualEffectView.Material
  let blendingMode: NSVisualEffectView.BlendingMode
  public init(material: NSVisualEffectView.Material, blendingMode: NSVisualEffectView.BlendingMode) {
    self.material = material
    self.blendingMode = blendingMode
  }

  public func makeNSView(context _: Context) -> NSVisualEffectView {
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
    visualEffectView.state = NSVisualEffectView.State.active
    return visualEffectView
  }

  public func updateNSView(_ visualEffectView: NSVisualEffectView, context _: Context) {
    visualEffectView.material = material
    visualEffectView.blendingMode = blendingMode
  }
}
