import Cocoa

#if canImport(SwiftUI)
  import SwiftUI
#endif

/// Modifiers used to customize a ``MenuItem`` or ``CustomMenuItem``.
public protocol AnyMenuItem {
  associatedtype Item: NSMenuItem

  /// Calls the given `modifier` to prepare the menu item for display.
  func apply(_ modifier: @escaping (Item) -> Void) -> Self
}

extension AnyMenuItem {
  // MARK: Behavior

  /// Runs a closure when the menu item is selected.
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Click Me")
  ///     .onSelect {
  ///         print("Hello, world!")
  ///     }
  /// ```
  public func onSelect(_ handler: @escaping () -> Void) -> Self {
    set(\.representedObject, to: handler)
      .onSelect(target: MenuInvoker.shared, action: #selector(MenuInvoker.run(_:)))
  }

  /// Set the target and action of the menu item
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Show Tag")
  ///     .tag(42)
  ///     .onSelect(target: self, action: #selector(printSenderTag(_:)))
  /// ```
  public func onSelect(target: AnyObject, action: Selector) -> Self {
    apply {
      $0.target = target
      $0.action = action
    }
  }

  /// Set the action of the menu item
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Show About Panel")
  ///     .action(#selector(orderFrontStandardAboutPanel:))
  /// ```
  public func action(_ action: Selector) -> Self {
    set(\.action, to: action)
  }

  /// Set the tag of the menu item
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Find…")
  ///     .action(#selector(NSTextView.performFindPanelAction(_:)))
  ///     .tag(Int(NSFindPanelAction.showFindPanel.rawValue))
  /// ```
  public func tag(_ tag: Int) -> Self {
    set(\.tag, to: tag)
  }

  /// Sets the keyboard shortcut/key equivalent.
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Quit")
  ///     .shortcut("q")
  /// MenuItem("Commit…")
  ///     .shortcut("c", holding: [.option, .command])
  /// ```
  public func shortcut(_ shortcut: String, holding modifiers: NSEvent.ModifierFlags = .command) -> Self {
    apply {
      $0.keyEquivalent = shortcut
      $0.keyEquivalentModifierMask = modifiers
    }
  }

  /// Disables the menu item.
  ///
  /// Menu items without a `onSelect` handler or submenu are always disabled.
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Version 1.2.3")
  ///
  /// MenuItem("Go Forward")
  ///     .onSelect { ... }
  ///     .disabled(!canGoForward)
  ///
  /// MenuItem("Take Risky Action")
  ///     .onSelect { ... }
  ///     .disabled()
  /// ```
  public func disabled(_ disabled: Bool = true) -> Self {
    set(\.isEnabled, to: !disabled)
  }

  /// Sets the submenu for the given menu item using a menu builder.
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("New")
  ///     .submenu {
  ///     }
  /// ```
  public func submenu(@MenuBuilder _ items: @escaping () -> [NSMenuItem]) -> Self {
    apply {
      $0.submenu = NSMenu(title: $0.title, items)
    }
  }

  /// Set the tooltip displayed when hovering over the menu item.
  ///
  /// ## Example
  /// ```swift
  /// for file in folder {
  ///     MenuItem(file.name)
  ///         .onSelect { reveal(file) }
  ///         // allow the user to read the full name even if it overflows
  ///         .toolTip(file.name)
  /// }
  /// ```
  public func toolTip(_ toolTip: String?) -> Self {
    set(\.toolTip, to: toolTip)
  }

  // MARK: Appearance

  /// Sets the checked/unchecked/mixed state
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Show")
  ///     .submenu {
  ///         for filter in model.filters {
  ///             MenuItem(filter.name)
  ///               .onSelect { filter.isEnabled.toggle() }
  ///               .checked(filter.isEnabled)
  ///         }
  ///     }
  ///     .state(model.allFiltersEnabled
  ///         ? .on
  ///         : model.allFiltersDisabled ? .off : .mixed)
  /// ```
  public func state(_ state: NSControl.StateValue) -> Self {
    set(\.state, to: state)
  }

  /// Display a custom `NSView` instead of the title or attributed title.
  ///
  /// The title string must still be specified in order to enable type-to-select to work.
  /// You are responsible for drawing the highlighted state (based on `enclosingMenuItem.isHighlighted`).
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("\(server.name) is \(server.status.description)")
  ///     .view(ServerStatusView(server: server))
  /// ```
  public func view(_ view: NSView) -> Self {
    set(\.view, to: view)
  }

  #if canImport(SwiftUI)
    /// Display a custom SwiftUI `View` instead of the title or attributed title.
    ///
    /// The passed closure will only be called once.
    ///
    /// Any views inside a menu item can use the `\.menuItemIsHighlighted`
    /// environment value to alter their appearance when highlighted.
    ///
    /// By default, a selection material (`NSVisualEffectView.Material.selection`) will be drawn behind the view whenever `menuItemIsHighlighted` is `true`. You can disable this and handle highlighting yourself by passing `showsHighlight: false`
    ///
    /// ## Example
    /// ```swift
    /// MenuItem("\(server.name) is \(server.status.description)")
    ///     .view {
    ///         HStack {
    ///             Circle()
    ///                 .fill(server.status.color)
    ///                 .frame(height: 8)
    ///             Text(server.name)
    ///             Spacer()
    ///             Text(server.uptime)
    ///         }
    ///     }
    /// ```
    @available(macOS 10.15, *)
    public func view<Content: View>(showsHighlight: Bool = true, @ViewBuilder _ content: () -> Content) -> Self {
      view(MenuItemView(showsHighlight: showsHighlight, content()))
    }
  #endif

  /// Sets the image associated with this menu item.
  /// ## Example
  /// ```swift
  /// MenuItem(file.name)
  ///     .image(NSImage(named: file.iconName))
  /// ```
  public func image(_ image: NSImage) -> Self {
    set(\.image, to: image)
  }

  /// Sets an on/off/mixed-state-specific image.

  /// ## Example
  /// ```swift
  /// MenuItem(file.name)
  ///     .image(
  ///         NSImage(systemSymbolName: "line.horizontal.3.decrease.circle", accessibilityDescription: nil),
  ///         for: .off
  ///     )
  ///     .image(
  ///         NSImage(systemSymbolName: "line.horizontal.3.decrease.circle.fill", accessibilityDescription: nil),
  ///         for: .on
  ///     )
  /// ```
  public func image(_ image: NSImage, for state: NSControl.StateValue) -> Self {
    apply { item in
      switch state {
        case .off: item.offStateImage = image
        case .on: item.onStateImage = image
        case .mixed: item.mixedStateImage = image
        default: fatalError("Unsupported MenuItem state \(state)")
      }
    }
  }

  // MARK: Advanced Customizations

  /// Indent the menu item to the given level
  ///
  /// For simple indentation, use ``IndentGroup`` (which automatically handles nesting) instead.
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Hello, world!")
  ///     .indent(level: 2)
  /// ```
  ///
  /// ## See Also
  /// - ``IndentGroup``
  public func indent(level: Int) -> Self {
    set(\.indentationLevel, to: level)
  }

  /// Set an arbitrary `keyPath` on the menu item to a value of your choice.
  ///
  /// ## Example
  /// ```swift
  /// MenuItem("Save As…")
  ///     .set(\.isAlternate, to: true)
  /// ```
  public func set<Value>(_ keyPath: ReferenceWritableKeyPath<Item, Value>, to value: Value) -> Self {
    apply {
      $0[keyPath: keyPath] = value
    }
  }
}
