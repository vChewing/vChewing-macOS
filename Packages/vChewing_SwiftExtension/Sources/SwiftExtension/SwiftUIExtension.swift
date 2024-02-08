// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import SwiftUI

// MARK: - Add "didChange" support to bindings.

// Ref: https://mjeld.com/swiftui-macos-10-15-toggle-onchange/

@available(macOS 10.15, *)
public extension Binding {
  func didChange(_ action: @escaping () -> Void) -> Binding {
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
public extension View {
  func help(_ tooltip: String) -> some View {
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
      textView.isRichText = false
      textView.delegate = self

      scrollview.borderType = .noBorder
      scrollview.hasVerticalScroller = true
      scrollview.hasHorizontalScroller = true
      scrollview.documentView = textView
      scrollview.scrollerStyle = .legacy
      scrollview.autohidesScrollers = true

      return scrollview
    }
  }
}

// MARK: - Property Wrapper (Bindable Extension)

extension AppProperty: DynamicProperty {
  @available(macOS 10.15, *)
  public var projectedValue: Binding<Value> {
    .init(
      get: {
        wrappedValue
      },
      set: {
        container.set($0, forKey: key)
      }
    )
  }
}

// MARK: - Porting NSTextField (Label) to SwiftUI.

@available(macOS 10.15, *)
public struct AttributedLabel: NSViewRepresentable {
  private let text: NSAttributedString

  public init(attributedString: NSAttributedString) {
    text = attributedString
  }

  public func makeNSView(context _: Context) -> NSTextField {
    let textField = NSTextField(labelWithAttributedString: text)
    textField.isSelectable = false
    textField.allowsEditingTextAttributes = false
    textField.preferredMaxLayoutWidth = textField.frame.width
    return textField
  }

  public func updateNSView(_ nsView: NSTextField, context _: Context) {
    nsView.attributedStringValue = text
  }
}

// MARK: - Porting NSPathControl to SwiftUI.

@available(macOS 10.15, *)
public struct PathControl: NSViewRepresentable {
  private let pathCtl = NSPathControl()
  @Binding private var path: String
  private var configuration: (NSPathControl) -> Void = { _ in }
  private var acceptDrop: (NSPathControl, NSDraggingInfo) -> Bool = { _, _ in false }

  public init(
    path: Binding<String>,
    configuration: @escaping (NSPathControl) -> Void = { _ in }
  ) {
    _path = path
    self.configuration = configuration
  }

  public init(
    pathDroppable: Binding<String>,
    configuration: @escaping (NSPathControl) -> Void = { _ in },
    acceptDrop: @escaping (NSPathControl, NSDraggingInfo) -> Bool
  ) {
    _path = pathDroppable
    self.configuration = configuration
    self.acceptDrop = acceptDrop
  }

  public func makeNSView(context: Context) -> NSPathControl {
    pathCtl.allowsExpansionToolTips = true
    pathCtl.translatesAutoresizingMaskIntoConstraints = false
    pathCtl.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    pathCtl.controlSize = .small
    pathCtl.backgroundColor = .controlBackgroundColor
    pathCtl.target = context.coordinator
    pathCtl.doubleAction = #selector(Coordinator.action)
    pathCtl.setContentHuggingPriority(.defaultHigh, for: .vertical)
    pathCtl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
    pathCtl.heightAnchor.constraint(equalToConstant: NSFont.smallSystemFontSize * 2).isActive = true
    return pathCtl
  }

  public func updateNSView(_ pathCtl: NSPathControl, context _: Context) {
    pathCtl.url = !path.isEmpty ? URL(fileURLWithPath: path) : nil
    configuration(pathCtl)
  }

  public func makeCoordinator() -> Coordinator {
    Coordinator(target: pathCtl, acceptDrop: acceptDrop)
  }

  public class Coordinator: NSObject, NSPathControlDelegate {
    private var acceptDrop: (NSPathControl, NSDraggingInfo) -> Bool

    public init(target: NSPathControl, acceptDrop: @escaping (NSPathControl, NSDraggingInfo) -> Bool) {
      self.acceptDrop = acceptDrop
      super.init()
      target.delegate = self
    }

    @objc public func action(sender: NSPathControl) {
      guard let url = sender.url else { return }
      NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    public func pathControl(_ pathControl: NSPathControl, acceptDrop info: NSDraggingInfo) -> Bool {
      acceptDrop(pathControl, info)
    }
  }
}
