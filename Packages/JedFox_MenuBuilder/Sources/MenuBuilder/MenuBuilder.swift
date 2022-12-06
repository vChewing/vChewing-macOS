import Cocoa

/// A function builder type that produces an array of `NSMenuItem`s.
@resultBuilder
public enum MenuBuilder {
  public static func buildBlock(_ block: [NSMenuItem]...) -> [NSMenuItem] {
    block.flatMap { $0 }
  }

  public static func buildOptional(_ item: [NSMenuItem]?) -> [NSMenuItem] {
    item ?? []
  }

  public static func buildEither(first: [NSMenuItem]?) -> [NSMenuItem] {
    first ?? []
  }

  public static func buildEither(second: [NSMenuItem]?) -> [NSMenuItem] {
    second ?? []
  }

  public static func buildArray(_ components: [[NSMenuItem]]) -> [NSMenuItem] {
    components.flatMap { $0 }
  }

  public static func buildExpression(_ expr: [NSMenuItem]?) -> [NSMenuItem] {
    expr ?? []
  }

  public static func buildExpression(_ expr: NSMenuItem?) -> [NSMenuItem] {
    expr.map { [$0] } ?? []
  }
}

extension NSMenu {
  /// Create a new menu with the given title and items.
  public convenience init(title: String, @MenuBuilder _ items: () -> [NSMenuItem]) {
    self.init(title: title)
    replaceItems(with: items)
  }

  /// Create a new menu with the given items.
  public convenience init(@MenuBuilder _ items: () -> [NSMenuItem]) {
    self.init()
    replaceItems(with: items)
  }

  /// Remove all items in the menu and replace them with the provided list of menu items.
  public func replaceItems(@MenuBuilder with items: () -> [NSMenuItem]) {
    removeAllItems()
    for item in items() {
      addItem(item)
    }
    update()
  }
}
