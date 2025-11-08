// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

#if canImport(SwiftUI)

  import SwiftExtension
  import SwiftUI

  // MARK: - Add "didChange" support to bindings.

  // Ref: https://mjeld.com/swiftui-macos-10-15-toggle-onchange/

  @available(macOS 10.15, *)
  extension Binding {
    public func didChange(_ action: @escaping () -> ()) -> Binding {
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

  // MARK: - Tooltip

  // Ref: https://stackoverflow.com/a/63217861

  @available(macOS 10.15, *)
  struct Tooltip: NSViewRepresentable {
    let tooltip: String

    func makeNSView(context _: NSViewRepresentableContext<Self>) -> NSView {
      let view = NSView()
      view.toolTip = tooltip

      return view
    }

    func updateNSView(_: NSView, context _: NSViewRepresentableContext<Self>) {}
  }

  @available(macOS 10.15, *)
  extension View {
    public func help(_ tooltip: String) -> some View {
      overlay(Tooltip(tooltip: tooltip))
    }
  }

  // MARK: - VisualEffectView

  // Ref: https://stackoverflow.com/questions/62461957

  @available(macOS 10.15, *)
  public struct VisualEffectView: NSViewRepresentable {
    // MARK: Lifecycle

    public init(
      material: NSVisualEffectView.Material,
      blendingMode: NSVisualEffectView.BlendingMode
    ) {
      self.material = material
      self.blendingMode = blendingMode
    }

    // MARK: Public

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

    // MARK: Internal

    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode
  }

  // MARK: - TextEditorEX

  // Ref: https://stackoverflow.com/a/63761738/4162914

  @available(macOS 10.15, *)
  /// A much faster alternative than Apple official TextEditor.
  public struct TextEditorEX: NSViewRepresentable {
    // MARK: Lifecycle

    public init(text: Binding<String>) {
      _text = text
    }

    // MARK: Public

    public class Coordinator: NSObject, NSTextViewDelegate {
      // MARK: Lifecycle

      public init(text: Binding<String>) {
        self.text = text
      }

      // MARK: Public

      public var text: Binding<String>

      public func textView(
        _ textView: NSTextView,
        shouldChangeTextIn range: NSRange,
        replacementString text: String?
      )
        -> Bool {
        defer {
          self.text.wrappedValue = (textView.string as NSString).replacingCharacters(
            in: range,
            with: text!
          )
        }
        return true
      }

      public func createTextViewStack() -> NSScrollView {
        let scrollview = NSScrollView()
        let textView: NSTextView = {
          let result = NSTextView(frame: CGRect())
          result.font = NSFont.systemFont(ofSize: 13, weight: .regular)
          result.allowsUndo = true
          return result
        }()
        let contentSize = scrollview.contentSize

        if let n = textView.textContainer {
          n.containerSize = CGSize(width: contentSize.width, height: CGFloat.greatestFiniteMagnitude)
          n.widthTracksTextView = true
        }

        textView.minSize = CGSize(width: 0, height: 0)
        textView.maxSize = CGSize(
          width: CGFloat.greatestFiniteMagnitude,
          height: CGFloat.greatestFiniteMagnitude
        )
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

    // MARK: Internal

    @Binding
    var text: String
  }

  // MARK: - AppProperty + DynamicProperty

  #if hasFeature(RetroactiveAttribute)
    extension AppProperty: @retroactive DynamicProperty {}
  #else
    extension AppProperty: DynamicProperty {}
  #endif

  extension AppProperty {
    @available(macOS 10.15, *)
    public var projectedValue: Binding<Value> {
      .init(
        get: {
          self.wrappedValue
        },
        set: {
          self.container.set($0, forKey: self.key)
        }
      )
    }
  }

  // MARK: - AttributedLabel

  @available(macOS 10.15, *)
  public struct AttributedLabel: NSViewRepresentable {
    // MARK: Lifecycle

    public init(attributedString: NSAttributedString) {
      self.text = attributedString
    }

    // MARK: Public

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

    // MARK: Private

    private let text: NSAttributedString
  }

  // MARK: - PathControl

  @available(macOS 10.15, *)
  public struct PathControl: NSViewRepresentable {
    // MARK: Lifecycle

    public init(
      path: Binding<String>,
      configuration: @escaping (NSPathControl) -> () = { _ in }
    ) {
      _path = path
      self.configuration = configuration
    }

    public init(
      pathDroppable: Binding<String>,
      configuration: @escaping (NSPathControl) -> () = { _ in },
      acceptDrop: @escaping (NSPathControl, NSDraggingInfo) -> Bool
    ) {
      _path = pathDroppable
      self.configuration = configuration
      self.acceptDrop = acceptDrop
    }

    // MARK: Public

    public class Coordinator: NSObject, NSPathControlDelegate {
      // MARK: Lifecycle

      public init(
        acceptDrop: @escaping (NSPathControl, NSDraggingInfo) -> Bool
      ) {
        self.acceptDrop = acceptDrop
        super.init()
      }

      // MARK: Public

      @objc
      public func action(sender: NSPathControl) {
        guard let url = sender.url else { return }
        NSWorkspace.shared.activateFileViewerSelecting([url])
      }

      public func pathControl(_ pathControl: NSPathControl, acceptDrop info: NSDraggingInfo) -> Bool {
        acceptDrop(pathControl, info)
      }

      public func makeNSView() -> NSPathControl {
        let pathCtl = NSPathControl()
        pathCtl.allowsExpansionToolTips = true
        pathCtl.translatesAutoresizingMaskIntoConstraints = false
        pathCtl.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        pathCtl.controlSize = .small
        pathCtl.backgroundColor = .controlBackgroundColor
        pathCtl.target = self
        pathCtl.delegate = self
        pathCtl.doubleAction = #selector(Self.action)
        pathCtl.setContentHuggingPriority(.defaultHigh, for: .vertical)
        pathCtl.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        pathCtl.heightAnchor.constraint(equalToConstant: NSFont.smallSystemFontSize * 2).isActive = true
        return pathCtl
      }

      // MARK: Private

      private var acceptDrop: (NSPathControl, NSDraggingInfo) -> Bool
    }

    public func makeNSView(context: Context) -> NSPathControl {
      context.coordinator.makeNSView()
    }

    public func updateNSView(_ pathCtl: NSPathControl, context _: Context) {
      pathCtl.url = !path.isEmpty ? URL(fileURLWithPath: path) : nil
      configuration(pathCtl)
    }

    public func makeCoordinator() -> Coordinator {
      Coordinator(acceptDrop: acceptDrop)
    }

    // MARK: Private

    @Binding
    private var path: String

    private var configuration: (NSPathControl) -> () = { _ in }
    private var acceptDrop: (NSPathControl, NSDraggingInfo) -> Bool = { _, _ in false }
  }

#endif
