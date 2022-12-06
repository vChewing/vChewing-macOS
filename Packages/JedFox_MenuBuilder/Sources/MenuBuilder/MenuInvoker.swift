import Cocoa

/// A singleton class that calls the closure-based `onSelect` handlers of menu items
class MenuInvoker {
  static let shared = MenuInvoker()
  private init() {}
  @objc func run(_ item: NSMenuItem) {
    (item.representedObject as! () -> Void)()
  }
}
