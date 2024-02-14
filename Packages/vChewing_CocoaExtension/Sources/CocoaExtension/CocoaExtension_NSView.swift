// (c) 2022 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import AppKit
import SwiftExtension

// MARK: - NSAlert

public extension NSAlert {
  func beginSheetModal(at window: NSWindow?, completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {
    if let window = window ?? NSApp.keyWindow {
      beginSheetModal(for: window, completionHandler: handler)
    } else {
      handler(runModal())
    }
  }
}

// MARK: - NSOpenPanel

public extension NSOpenPanel {
  func beginSheetModal(at window: NSWindow?, completionHandler handler: @escaping (NSApplication.ModalResponse) -> Void) {
    if let window = window ?? NSApp.keyWindow {
      beginSheetModal(for: window, completionHandler: handler)
    } else {
      handler(runModal())
    }
  }
}

// MARK: - NSButton

public extension NSButton {
  convenience init(verbatim title: String, target: AnyObject?, action: Selector?) {
    self.init()
    self.title = title
    self.target = target
    self.action = action
    bezelStyle = .rounded
  }

  convenience init(_ title: String, target: AnyObject?, action: Selector?) {
    self.init(verbatim: title.localized, target: target, action: action)
  }
}

// MARK: - Convenient Constructor for NSEdgeInsets.

public extension NSEdgeInsets {
  static func new(all: CGFloat? = nil, top: CGFloat? = nil, bottom: CGFloat? = nil, left: CGFloat? = nil, right: CGFloat? = nil) -> NSEdgeInsets {
    NSEdgeInsets(top: top ?? all ?? 0, left: left ?? all ?? 0, bottom: bottom ?? all ?? 0, right: right ?? all ?? 0)
  }
}

// MARK: - Constrains and Box Container Modifier.

public extension NSView {
  @discardableResult func makeSimpleConstraint(
    _ attribute: NSLayoutConstraint.Attribute,
    relation givenRelation: NSLayoutConstraint.Relation,
    value: CGFloat?
  ) -> NSView {
    translatesAutoresizingMaskIntoConstraints = false
    guard let givenValue = value, givenValue >= 0 else { return self }
    var handled = false
    constraints.forEach { constraint in
      guard constraint.firstAttribute == attribute else { return }
      switch (constraint.relation, givenRelation) {
      case (.lessThanOrEqual, .lessThanOrEqual):
        constraint.constant = Swift.min(givenValue, constraint.constant)
        handled = true
      case (.lessThanOrEqual, .equal):
        constraint.constant = Swift.max(givenValue, constraint.constant)
        handled = true
      case (.lessThanOrEqual, .greaterThanOrEqual):
        switch givenValue {
        case constraint.constant, ..<constraint.constant: // Smaller & Equal
          handled = false
        default: // Bigger
          removeConstraint(constraint)
          handled = false
        }
      case (.equal, .lessThanOrEqual):
        constraint.constant = Swift.min(givenValue, constraint.constant)
        handled = true
      case (.equal, .equal):
        constraint.constant = Swift.min(givenValue, constraint.constant) // 往往都是外圍容器最後賦值，所以取最小值。
        handled = true
      case (.equal, .greaterThanOrEqual):
        constraint.constant = Swift.max(givenValue, constraint.constant)
        handled = true
      case (.greaterThanOrEqual, .lessThanOrEqual):
        switch givenValue {
        case ..<constraint.constant: // Smaller
          removeConstraint(constraint)
          handled = false
        default: // Bigger & Equal
          handled = false
        }
      case (.greaterThanOrEqual, .equal):
        constraint.constant = Swift.max(givenValue, constraint.constant)
        handled = true
      case (.greaterThanOrEqual, .greaterThanOrEqual):
        constraint.constant = Swift.max(givenValue, constraint.constant)
        handled = true
      default: break
      }
    }
    guard !handled else { return self }
    let widthConstraint = NSLayoutConstraint(
      item: self, attribute: attribute, relatedBy: givenRelation, toItem: nil,
      attribute: NSLayoutConstraint.Attribute.notAnAttribute, multiplier: 1, constant: givenValue
    )
    addConstraint(widthConstraint)
    return self
  }

  func boxed(title: String = "") -> NSBox {
    let maxDimension = fittingSize
    let result = NSBox()
    result.title = title.localized
    if result.title.isEmpty {
      result.titlePosition = .noTitle
    }
    let minWidth = Swift.max(maxDimension.width + 12, result.intrinsicContentSize.width)
    let minHeight = Swift.max(maxDimension.height + result.titleRect.height + 14, result.intrinsicContentSize.height)
    result.makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: minWidth)
    result.makeSimpleConstraint(.height, relation: .greaterThanOrEqual, value: minHeight)
    result.contentView = self
    if let self = self as? NSStackView, self.orientation == .horizontal {
      self.spacing = 0
    }
    return result
  }
}

// MARK: - Stacks

public extension NSStackView {
  var requiresConstraintBasedLayout: Bool {
    true
  }

  static func buildSection(
    _ orientation: NSUserInterfaceLayoutOrientation = .vertical,
    spacing: CGFloat? = nil,
    width: CGFloat? = nil,
    withDividers: Bool = true,
    @ArrayBuilder<NSView?> views: () -> [NSView?]
  ) -> NSStackView? {
    let viewsRendered = views().compactMap {
      // 下述註解是用來協助偵錯的。
      // $0?.wantsLayer = true
      // $0?.layer?.backgroundColor = NSColor.red.cgColor
      $0
    }
    guard !viewsRendered.isEmpty else { return nil }
    var itemWidth = width
    var splitterDelta: CGFloat = 4
    splitterDelta = withDividers ? splitterDelta : 0
    if let width = width, orientation == .horizontal, viewsRendered.count > 0 {
      itemWidth = (width - splitterDelta) / CGFloat(viewsRendered.count) - 6
    }
    func giveViews() -> [NSView?] { viewsRendered }
    let result = build(orientation, divider: withDividers, spacing: spacing, width: itemWidth, views: giveViews)?
      .withInsets(.new(all: 4))
    return result
  }

  static func build(
    _ orientation: NSUserInterfaceLayoutOrientation,
    divider: Bool = false,
    spacing: CGFloat? = nil,
    width: CGFloat? = nil,
    height: CGFloat? = nil,
    insets: NSEdgeInsets? = nil,
    @ArrayBuilder<NSView?> views: () -> [NSView?]
  ) -> NSStackView? {
    let result = views().compactMap {
      $0?
        .makeSimpleConstraint(.width, relation: .equal, value: width)
        .makeSimpleConstraint(.height, relation: .equal, value: height)
    }
    guard !result.isEmpty else { return nil }
    return result.stack(orientation, divider: divider, spacing: spacing)?.withInsets(insets)
  }

  func withInsets(_ newValue: NSEdgeInsets?) -> NSStackView {
    edgeInsets = newValue ?? edgeInsets
    return self
  }
}

public extension Array where Element == NSView {
  func stack(
    _ orientation: NSUserInterfaceLayoutOrientation,
    divider: Bool = false,
    spacing: CGFloat? = nil,
    insets: NSEdgeInsets? = nil
  ) -> NSStackView? {
    guard !isEmpty else { return nil }
    let outerStack = NSStackView()
    if #unavailable(macOS 10.11) {
      outerStack.hasEqualSpacing = true
    } else {
      outerStack.distribution = .equalSpacing
    }
    outerStack.orientation = orientation

    if #unavailable(macOS 10.10) {
      outerStack.spacing = Swift.max(1, outerStack.spacing) - 1
    }
    outerStack.spacing = spacing ?? outerStack.spacing

    outerStack.setHuggingPriority(.fittingSizeCompression, for: .horizontal)
    outerStack.setHuggingPriority(.fittingSizeCompression, for: .vertical)

    forEach { subView in
      if divider, !outerStack.views.isEmpty {
        let divider = NSView()
        divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.gray.withAlphaComponent(0.2).cgColor
        switch orientation {
        case .horizontal:
          divider.makeSimpleConstraint(.width, relation: .equal, value: 1)
        case .vertical:
          divider.makeSimpleConstraint(.height, relation: .equal, value: 1)
        @unknown default: break
        }
        divider.translatesAutoresizingMaskIntoConstraints = false
        outerStack.addView(divider, in: orientation == .horizontal ? .leading : .top)
      }
      subView.layoutSubtreeIfNeeded()
      switch orientation {
      case .horizontal:
        subView.makeSimpleConstraint(.height, relation: .greaterThanOrEqual, value: subView.intrinsicContentSize.height)
        subView.makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: subView.intrinsicContentSize.width)
      case .vertical:
        subView.makeSimpleConstraint(.width, relation: .greaterThanOrEqual, value: subView.intrinsicContentSize.width)
        subView.makeSimpleConstraint(.height, relation: .greaterThanOrEqual, value: subView.intrinsicContentSize.height)
      @unknown default: break
      }
      subView.setContentCompressionResistancePriority(.defaultHigh, for: .horizontal)
      subView.setContentCompressionResistancePriority(.defaultHigh, for: .vertical)
      subView.translatesAutoresizingMaskIntoConstraints = false
      outerStack.addView(subView, in: orientation == .horizontal ? .leading : .top)
    }

    switch orientation {
    case .horizontal:
      outerStack.alignment = .centerY
    case .vertical:
      outerStack.alignment = .leading
    @unknown default: break
    }
    return outerStack.withInsets(insets)
  }
}

// MARK: - Make NSAttributedString into Label

public extension NSAttributedString {
  func makeNSLabel(fixWidth: CGFloat? = nil) -> NSTextField {
    let textField = NSTextField()
    textField.attributedStringValue = self
    textField.isEditable = false
    textField.isBordered = false
    textField.backgroundColor = .clear
    if let fixWidth = fixWidth {
      textField.preferredMaxLayoutWidth = fixWidth
    }
    return textField
  }
}

// MARK: - Make String into Label

public extension String {
  func makeNSLabel(descriptive: Bool = false, localized: Bool = true, fixWidth: CGFloat? = nil) -> NSTextField {
    let rawAttributedString = NSMutableAttributedString(string: localized ? self.localized : self)
    rawAttributedString.addAttributes([.kern: 0], range: .init(location: 0, length: rawAttributedString.length))
    let textField = rawAttributedString.makeNSLabel(fixWidth: fixWidth)
    if descriptive {
      if #available(macOS 10.10, *) {
        textField.textColor = .secondaryLabelColor
      } else {
        textField.textColor = .textColor.withAlphaComponent(0.55)
      }
      textField.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
    }
    return textField
  }
}

// MARK: - NSTabView

public extension NSTabView {
  struct TabPage {
    public let title: String
    public let view: NSView

    public init?(title: String, view: NSView?) {
      self.title = title
      guard let view = view else { return nil }
      self.view = view
    }

    public init(title: String, view: NSView) {
      self.title = title
      self.view = view
    }

    public init?(title: String, @ArrayBuilder<NSView?> views: () -> [NSView?]) {
      self.title = title
      let viewsRendered = views()
      guard !viewsRendered.isEmpty else { return nil }
      func giveViews() -> [NSView?] { viewsRendered }
      let result = NSStackView.build(.vertical, insets: .new(all: 14, top: 0), views: giveViews)
      guard let result = result else { return nil }
      view = result
    }
  }

  static func build(
    @ArrayBuilder<TabPage?> pages: () -> [TabPage?]
  ) -> NSTabView? {
    let tabPages = pages().compactMap { $0 }
    guard !tabPages.isEmpty else { return nil }
    let finalTabView = NSTabView()
    tabPages.forEach { currentPage in
      finalTabView.addTabViewItem({
        let currentItem = NSTabViewItem(identifier: UUID())
        currentItem.label = currentPage.title.localized
        let stacked = NSStackView.build(.vertical) {
          currentPage.view
        }
        stacked?.alignment = .centerX
        currentItem.view = stacked
        return currentItem
      }())
    }
    return finalTabView
  }
}

// MARK: - NSMenu

public extension NSMenu {
  @discardableResult func appendItems(_ target: AnyObject? = nil, @ArrayBuilder<NSMenuItem?> items: () -> [NSMenuItem?]) -> NSMenu {
    let theItems = items()
    for currentItem in theItems {
      guard let currentItem = currentItem else { continue }
      addItem(currentItem)
      guard let target = target else { continue }
      currentItem.target = target
      currentItem.submenu?.propagateTarget(target)
    }
    return self
  }

  @discardableResult func propagateTarget(_ obj: AnyObject?) -> NSMenu {
    for currentItem in items {
      currentItem.target = obj
      currentItem.submenu?.propagateTarget(obj)
    }
    return self
  }

  static func buildSubMenu(verbatim: String?, @ArrayBuilder<NSMenuItem?> items: () -> [NSMenuItem?]) -> NSMenuItem? {
    guard let verbatim = verbatim, !verbatim.isEmpty else { return nil }
    let newItem = NSMenu.Item(verbatim: verbatim)
    newItem?.submenu = .init(title: verbatim).appendItems(items: items)
    return newItem
  }

  static func buildSubMenu(_ title: String?, @ArrayBuilder<NSMenuItem?> items: () -> [NSMenuItem?]) -> NSMenuItem? {
    guard let title = title?.localized, !title.isEmpty else { return nil }
    return buildSubMenu(verbatim: title, items: items)
  }

  typealias Item = NSMenuItem
}

public extension Array where Element == NSMenuItem? {
  func propagateTarget(_ obj: AnyObject?) {
    forEach { currentItem in
      guard let currentItem = currentItem else { return }
      currentItem.target = obj
      currentItem.submenu?.propagateTarget(obj)
    }
  }
}

public extension NSMenuItem {
  convenience init?(verbatim: String?) {
    guard let verbatim = verbatim, !verbatim.isEmpty else { return nil }
    self.init(title: verbatim, action: nil, keyEquivalent: "")
  }

  convenience init?(_ title: String?) {
    guard let title = title?.localized, !title.isEmpty else { return nil }
    self.init(verbatim: title)
  }

  @discardableResult func hotkey(_ keyEquivalent: String, mask: NSEvent.ModifierFlags? = nil) -> NSMenuItem {
    keyEquivalentModifierMask = mask ?? keyEquivalentModifierMask
    self.keyEquivalent = keyEquivalent
    return self
  }

  @discardableResult func state(_ givenState: Bool) -> NSMenuItem {
    state = givenState ? .on : .off
    return self
  }

  @discardableResult func act(_ action: Selector) -> NSMenuItem {
    self.action = action
    return self
  }

  @discardableResult func nulled(_ condition: Bool) -> NSMenuItem? {
    condition ? nil : self
  }

  @discardableResult func mask(_ flags: NSEvent.ModifierFlags) -> NSMenuItem {
    keyEquivalentModifierMask = flags
    return self
  }

  @discardableResult func represent(_ object: Any?) -> NSMenuItem {
    representedObject = object
    return self
  }

  @discardableResult func tag(_ givenTag: Int?) -> NSMenuItem {
    guard let givenTag = givenTag else { return self }
    tag = givenTag
    return self
  }
}

// MARK: - NSFileDragRetrieverButton

@objcMembers public class NSFileDragRetrieverButton: NSButton {
  public var postDragHandler: ((URL) -> Void) = { url in
    NSSound.beep()
    print(url.description)
  }

  var allowedTypes: [String] = ["txt"]

  public init() {
    super.init(frame: .zero)
    bezelStyle = .rounded
    title = "DRAG FILE TO HERE"
    registerForDraggedTypes([.init(rawValue: kUTTypeFileURL as String)])
    target = self
  }

  required init?(coder: NSCoder) {
    super.init(coder: coder)
  }

  override public func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    checkExtension(sender) ? .copy : NSDragOperation()
  }

  fileprivate func checkExtension(_ drag: NSDraggingInfo) -> Bool {
    guard let pasteboard = drag.draggingPasteboard.propertyList(
      forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
    ) as? [String], let path = pasteboard.first else {
      return false
    }

    let suffix = URL(fileURLWithPath: path).pathExtension
    for ext in allowedTypes {
      if ext.lowercased() == suffix {
        return true
      }
    }
    return false
  }

  override public func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    guard let pasteboard = sender.draggingPasteboard.propertyList(
      forType: NSPasteboard.PasteboardType(rawValue: "NSFilenamesPboardType")
    ) as? [String], let path = pasteboard.first else {
      print("failure")
      return false
    }

    postDragHandler(URL(fileURLWithPath: path))
    return true
  }
}
