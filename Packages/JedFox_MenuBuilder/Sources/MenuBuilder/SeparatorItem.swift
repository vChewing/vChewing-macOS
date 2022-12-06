import Cocoa

/// A separator item.
public struct SeparatorItem {
  public init() {}
}

extension MenuBuilder {
  public static func buildExpression(_ expr: SeparatorItem?) -> [NSMenuItem] {
    expr != nil ? [.separator()] : []
  }
}
