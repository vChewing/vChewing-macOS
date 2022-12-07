import Cocoa

/// A menu item made from a custom subclass of `NSMenuItem`.
///
/// Pass a closure to the ``CustomMenuItem/init(_:)`` initializer that returns a menu item of your desired class, or simply construct the menu item directly:
/// ```swift
/// CustomMenuItem {
///   let item = MyDelegateMenuItem()
///   item.delegate = self
///   return item
/// }
/// // or:
/// CustomMenuItem(MySimpleMenuItem())
/// ```
public struct CustomMenuItem<Item: NSMenuItem>: AnyMenuItem {
  public typealias Modifier = (Item) -> Void

  fileprivate let makeMenu: () -> Item
  fileprivate let modifiers: [Modifier]

  public init(_ makeMenu: @autoclosure @escaping () -> Item) {
    self.makeMenu = makeMenu
    modifiers = []
  }

  /// Calls the provided closure on the `NSMenuItem`, allowing you to apply arbitrary changes.
  public func apply(_ modifier: @escaping Modifier) -> Self {
    Self(makeMenu: makeMenu, modifiers: modifiers + [modifier])
  }

  private init(makeMenu: @escaping () -> Item, modifiers: [Modifier]) {
    self.makeMenu = makeMenu
    self.modifiers = modifiers
  }
}

extension MenuBuilder {
  public static func buildExpression<T: NSMenuItem>(_ expr: CustomMenuItem<T>?) -> [NSMenuItem] {
    if let description = expr {
      let item = description.makeMenu()
      description.modifiers.forEach { $0(item) }
      return [item]
    }
    return []
  }
}
