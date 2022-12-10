// Free to use
// Written by Alexis Bridoux - https://github.com/ABridoux
// Ref: https://gist.github.com/ABridoux/b935c21c7ead92033d39b357fae6366b

import Cocoa
import SwiftUI

// MARK: Model

extension NSWindow {
  public struct Position {
    public static let defaultPadding: CGFloat = 16

    public var vertical: Vertical
    public var horizontal: Horizontal
    public var padding = Self.defaultPadding
  }
}

extension NSWindow.Position {
  public enum Horizontal {
    case left, center, right
  }

  public enum Vertical {
    case top, center, bottom
  }
}

// MARK: Logic

extension NSWindow.Position {
  public func value(forWindow windowRect: CGRect, inScreen screenRect: CGRect) -> CGPoint {
    let xPosition = horizontal.valueFor(
      screenRange: screenRect.minX..<screenRect.maxX,
      width: windowRect.width,
      padding: padding
    )

    let yPosition = vertical.valueFor(
      screenRange: screenRect.minY..<screenRect.maxY,
      height: windowRect.height,
      padding: padding
    )

    return CGPoint(x: xPosition, y: yPosition)
  }
}

extension NSWindow.Position.Horizontal {
  public func valueFor(
    screenRange: Range<CGFloat>,
    width: CGFloat,
    padding: CGFloat
  )
    -> CGFloat
  {
    switch self {
      case .left: return screenRange.lowerBound + padding
      case .center: return (screenRange.upperBound + screenRange.lowerBound - width) / 2
      case .right: return screenRange.upperBound - width - padding
    }
  }
}

extension NSWindow.Position.Vertical {
  public func valueFor(
    screenRange: Range<CGFloat>,
    height: CGFloat,
    padding: CGFloat
  )
    -> CGFloat
  {
    switch self {
      case .top: return screenRange.upperBound - height - padding
      case .center: return (screenRange.upperBound + screenRange.lowerBound - height) / 2
      case .bottom: return screenRange.lowerBound + padding
    }
  }
}

// MARK: - AppKit extension

extension NSWindow {
  public func setPosition(_ position: Position, in screen: NSScreen?) {
    guard let visibleFrame = (screen ?? self.screen)?.visibleFrame else { return }
    let origin = position.value(forWindow: frame, inScreen: visibleFrame)
    setFrameOrigin(origin)
  }

  public func setPosition(
    vertical: Position.Vertical,
    horizontal: Position.Horizontal,
    padding: CGFloat = Position.defaultPadding,
    screen: NSScreen? = nil
  ) {
    setPosition(
      Position(vertical: vertical, horizontal: horizontal, padding: padding),
      in: screen
    )
  }
}

// MARK: - SwiftUI modifier

#if canImport(SwiftUI)

  /// - note: Idea from [LostMoa](https://lostmoa.com/blog/ReadingTheCurrentWindowInANewSwiftUILifecycleApp/)
  @available(macOS 10.15, *)
  public struct HostingWindowFinder: NSViewRepresentable {
    public var callback: (NSWindow?) -> Void

    public func makeNSView(context _: Self.Context) -> NSView {
      let view = NSView()
      DispatchQueue.main.async { self.callback(view.window) }
      return view
    }

    public func updateNSView(_ nsView: NSView, context _: Context) {
      DispatchQueue.main.async { self.callback(nsView.window) }
    }
  }

  @available(macOS 10.15, *)
  private struct WindowPositionModifier: ViewModifier {
    let position: NSWindow.Position
    let screen: NSScreen?

    func body(content: Content) -> some View {
      content.background(
        HostingWindowFinder {
          $0?.setPosition(position, in: screen)
        }
      )
    }
  }

  @available(macOS 10.15, *)
  extension View {
    public func hostingWindowPosition(
      vertical: NSWindow.Position.Vertical,
      horizontal: NSWindow.Position.Horizontal,
      padding: CGFloat = NSWindow.Position.defaultPadding,
      screen: NSScreen? = nil
    ) -> some View {
      modifier(
        WindowPositionModifier(
          position: NSWindow.Position(
            vertical: vertical,
            horizontal: horizontal,
            padding: padding
          ),
          screen: screen
        )
      )
    }
  }
#endif
