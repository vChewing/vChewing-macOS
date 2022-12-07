#if canImport(SwiftUI)
  import Cocoa
  import SwiftUI

  @available(macOS 10.15, *)
  extension EnvironmentValues {
    private struct HighlightedKey: EnvironmentKey {
      static let defaultValue = false
    }

    /// Only updated inside of a `MenuItem(...).view { ... }` closure.
    /// Use this to adjust your content to look good in front of the selection background
    public var menuItemIsHighlighted: Bool {
      get {
        self[HighlightedKey.self]
      }
      set {
        self[HighlightedKey.self] = newValue
      }
    }
  }

  /// A custom menu item view that manages highlight state and renders
  /// an appropriate backdrop behind the view when highlighted
  @available(macOS 10.15, *)
  class MenuItemView<ContentView: View>: NSView {
    private var effectView: NSVisualEffectView
    let contentView: ContentView
    let hostView: NSHostingView<AnyView>
    let showsHighlight: Bool

    init(showsHighlight: Bool, _ view: ContentView) {
      effectView = NSVisualEffectView()
      effectView.state = .active
      effectView.material = .selection
      effectView.isEmphasized = true
      effectView.blendingMode = .behindWindow

      contentView = view
      hostView = NSHostingView(rootView: AnyView(contentView))

      self.showsHighlight = showsHighlight

      super.init(frame: CGRect(origin: .zero, size: hostView.intrinsicContentSize))
      addSubview(effectView)
      addSubview(hostView)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      if window != nil {
        frame = NSRect(
          origin: frame.origin,
          size: CGSize(width: enclosingMenuItem!.menu!.size.width, height: frame.height)
        )
        effectView.frame = frame
        hostView.frame = frame
      }
    }

    override func draw(_ dirtyRect: NSRect) {
      let highlighted = enclosingMenuItem!.isHighlighted
      effectView.isHidden = !showsHighlight || !highlighted
      hostView.rootView = AnyView(contentView.environment(\.menuItemIsHighlighted, highlighted))
      super.draw(dirtyRect)
    }
  }
#endif
