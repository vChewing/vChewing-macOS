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

// MARK: - TextEditor for macOS 10.15 Catalina

// Ref: https://stackoverflow.com/a/63761738/4162914

@available(macOS 10.15, *)
/// A much faster alternative than Apple official TextEditor.
public struct TextEditorEX: NSViewRepresentable {
  @Binding var text: String

  public init(text: Binding<String>) {
    _text = text
  }

  public func makeNSView(context: Context) -> NSScrollView {
    context.coordinator.createTextViewStack()
  }

  public func updateNSView(_ nsView: NSScrollView, context _: Context) {
    if let textArea = nsView.documentView as? NSTextView, textArea.string != self.text {
      textArea.string = text
    }
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(text: $text)
  }

  public class Coordinator: NSObject, NSTextViewDelegate {
    public var text: Binding<String>

    public init(text: Binding<String>) {
      self.text = text
    }

    public func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?)
      -> Bool
    {
      defer {
        self.text.wrappedValue = (textView.string as NSString).replacingCharacters(in: range, with: text!)
      }
      return true
    }

    fileprivate lazy var textView: NSTextView = {
      let result = NSTextView(frame: CGRect())
      result.font = NSFont.systemFont(ofSize: 13, weight: .regular)
      result.allowsUndo = true
      return result
    }()

    fileprivate lazy var scrollview = NSScrollView()

    public func createTextViewStack() -> NSScrollView {
      let contentSize = scrollview.contentSize

      if let n = textView.textContainer {
        n.containerSize = CGSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
        n.widthTracksTextView = true
      }

      textView.minSize = CGSize(width: 0, height: 0)
      textView.maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
      textView.isVerticallyResizable = true
      textView.frame = CGRect(x: 0, y: 0, width: contentSize.width, height: contentSize.height)
      textView.autoresizingMask = [.width]
      textView.delegate = self

      scrollview.borderType = .noBorder
      scrollview.hasVerticalScroller = true
      scrollview.documentView = textView

      return scrollview
    }
  }
}
