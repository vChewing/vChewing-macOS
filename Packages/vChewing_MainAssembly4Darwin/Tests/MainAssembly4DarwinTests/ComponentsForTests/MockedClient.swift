// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import IMKSwift

// MARK: - FakeClient

nonisolated final class FakeClient: NSObject, IMKTextInput {
  var attributedString: NSMutableAttributedString = .init(string: "")
  var selectedRangeStored: NSRange = .notFound
  var markedRangeStored: NSRange = .notFound
  var markedText: NSAttributedString = .init(string: "")

  var cursor = 0 {
    didSet {
      cursor = max(0, min(cursor, attributedString.length))
    }
  }

  func toString() -> String {
    attributedString.string
  }

  func clear() {
    cursor = 0
    attributedString = .init()
  }

  func insertText(_ string: Any!, replacementRange: NSRange) {
    guard let string = string as? String else { return }
    var insertionPoint = replacementRange.location
    if insertionPoint == NSNotFound {
      insertionPoint = cursor
    }
    cursor = insertionPoint
    attributedString.insert(.init(string: string), at: cursor)
    cursor += string.utf16.count
  }

  func setMarkedText(_ string: Any!, selectionRange _: NSRange, replacementRange: NSRange) {
    markedText = string as? NSAttributedString ?? .init(string: string as? String ?? "")
    var insertionPoint = replacementRange.location
    if insertionPoint == NSNotFound {
      insertionPoint = cursor
    }
    cursor = insertionPoint
  }

  func selectedRange() -> NSRange {
    NSIntersectionRange(selectedRangeStored, .init(location: 0, length: attributedString.length))
  }

  func markedRange() -> NSRange {
    NSIntersectionRange(markedRangeStored, .init(location: 0, length: attributedString.length))
  }

  func attributedSubstring(from range: NSRange) -> NSAttributedString! {
    let usableRange = NSIntersectionRange(
      range,
      .init(location: 0, length: attributedString.length)
    )
    return attributedString.attributedSubstring(from: usableRange)
  }

  func length() -> Int {
    attributedString.length
  }

  func characterIndex(
    for _: CGPoint,
    tracking _: IMKLocationToOffsetMappingMode,
    inMarkedRange _: UnsafeMutablePointer<ObjCBool>!
  )
    -> Int {
    cursor
  }

  func attributes(
    forCharacterIndex _: Int,
    lineHeightRectangle _: UnsafeMutablePointer<CGRect>!
  )
    -> [AnyHashable: Any]! {
    [:]
  }

  func validAttributesForMarkedText() -> [Any]! {
    []
  }

  func overrideKeyboard(withKeyboardNamed keyboardUniqueName: String!) {
    _ = keyboardUniqueName
  }

  func selectMode(_ modeIdentifier: String!) {
    _ = modeIdentifier
  }

  func supportsUnicode() -> Bool {
    true
  }

  func bundleIdentifier() -> String {
    "org.atelierInmu.vChewing.MainAssembly.UnitTests.MockedClient"
  }

  func windowLevel() -> CGWindowLevel {
    CGShieldingWindowLevel()
  }

  func supportsProperty(_: TSMDocumentPropertyTag) -> Bool {
    false
  }

  func uniqueClientIdentifierString() -> String {
    bundleIdentifier()
  }

  func string(from range: NSRange, actualRange: NSRangePointer!) -> String! {
    let actualNSRange = actualRange.move()
    var usableRange = NSIntersectionRange(actualNSRange, range)
    usableRange = NSIntersectionRange(
      usableRange,
      .init(location: 0, length: attributedString.length)
    )
    return attributedString.attributedSubstring(from: usableRange).string
  }

  func firstRect(forCharacterRange _: NSRange, actualRange _: NSRangePointer!) -> CGRect {
    .zero
  }
}

// MARK: IMKClientProxyProtocol

extension FakeClient: IMKClientProxyProtocol {
  func hasClient() -> Bool {
    true
  }

  func clientTextInsertion(with text: String, replacementRange: NSRange) {
    insertText(text, replacementRange: replacementRange)
  }

  func clientMarkedTextSetup(
    with text: NSAttributedString,
    selectionRange: NSRange,
    replacementRange: NSRange
  ) {
    setMarkedText(text, selectionRange: selectionRange, replacementRange: replacementRange)
  }

  func clientBundleIdentifier() -> String? {
    bundleIdentifier()
  }

  func clientSelectMode(withModeIdentifier modeIdentifier: String) {
    selectMode(modeIdentifier)
  }

  func clientOverrideKeyboard(withName keyboardName: String) {
    overrideKeyboard(withKeyboardNamed: keyboardName)
  }

  func clientAttributesForCharacterIndex(
    atU16Pos charIdx: UInt,
    lineHeightRectangle: UnsafeMutablePointer<NSRect>
  )
    -> [AnyHashable: Any]? {
    attributes(forCharacterIndex: Int(charIdx), lineHeightRectangle: lineHeightRectangle)
  }

  func clientLineHeightRect(forU16CursorPos cursorPos: UInt) -> CGRect {
    lineHeightRect(u16Cursor: Int(cursorPos))
  }
}

extension IMKTextInput {
  public func lineHeightRect(u16Cursor: Int) -> CGRect {
    // `lineHeightRect` 的尺寸不能是 0，否則 `attributes()` 在某些客體上的不良實作可能會炸掉客體。
    var lineHeightRect = CGRect.seniorTheBeast
    var u16Cursor = u16Cursor
    // iMessage 的話，據此算出來的 lineHeightRect 結果的橫向座標起始點不準確。目前無解。
    while lineHeightRect.origin == .zero, u16Cursor >= 0 {
      _ = attributes(
        forCharacterIndex: u16Cursor, lineHeightRectangle: &lineHeightRect
      )
      u16Cursor -= 1
    }
    return lineHeightRect
  }
}
