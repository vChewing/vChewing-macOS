import ObjectiveC
import SwiftUI

@available(macOS 10.15, *)
/// Provides a convenient method for backporting API,
/// including types, functions, properties, property wrappers and more.
///
/// To backport a SwiftUI Label for example, you could apply the
/// following extension:
///
///     extension Backport where Content == Any {
///         public struct Label<Title, Icon> { }
///     }
///
/// Now if we want to provide further extensions to our backport type,
/// we need to ensure we retain the `Content == Any` generic requirement:
///
///     extension Backport.Label where Content == Any, Title == Text, Icon == Image {
///         public init<S: StringProtocol>(_ title: S, systemName: String) { }
///     }
///
/// In addition to types, we can also provide backports for properties
/// and methods:
///
///     extension Backport.Label where Content: View {
///         func onChange<Value: Equatable>(of value: Value, perform action: (Value) -> Void) -> some View {
///             // `content` provides access to the extended type
///             content.modifier(OnChangeModifier(value, action))
///         }
///     }
///
public struct Backport<Wrapped> {
  /// The underlying content this backport represents.
  public let content: Wrapped

  @available(macOS 10.15, *)
  /// Initializes a new Backport for the specified content.
  /// - Parameter content: The content (type) that's being backported
  public init(_ content: Wrapped) {
    self.content = content
  }
}

@available(macOS 10.15, *)
extension View {
  /// Wraps a SwiftUI `View` that can be extended to provide backport functionality.
  public var backport: Backport<Self> { .init(self) }
}

@available(macOS 10.15, *)
extension NSObjectProtocol {
  /// Wraps an `NSObject` that can be extended to provide backport functionality.
  public var backport: Backport<Self> { .init(self) }
}

@available(macOS 10.15, *)
extension AnyTransition {
  /// Wraps an `AnyTransition` that can be extended to provide backport functionality.
  public static var backport: Backport<AnyTransition> {
    Backport(.identity)
  }
}