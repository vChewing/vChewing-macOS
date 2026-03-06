// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

@_exported import IMKSwiftModernHeaders

// MARK: - IMKInputSessionController + IMKInputSessionControllerProtocol

extension IMKInputSessionController: IMKInputSessionControllerProtocol {}

// MARK: - IMKInputSessionControllerProtocol

/// A MainActor-isolated super-protocol that subsumes every method from
/// ``IMKStateSetting``, ``IMKMouseHandling``, ``IMKServerInput`` (informal),
/// plus the full ``IMKInputController`` surface.
///
/// Method signatures match the IMKSwift overlay's bridged types exactly.
/// Downstream code should subclass ``IMKInputSessionController`` (not
/// ``IMKInputController``) to pick up these refinements.
/// - Remark: This protocol is to help Swift developers designing
/// other protocols or generic-based types.
/// - Warning: Do not redefine this kind of protocols in Objective-C. Doing such
/// will let you face issues of naming conflicts against certain ObjC methods.
@objc
public protocol IMKInputSessionControllerProtocol: AnyObject {
  // -- IMKStateSetting surface --

  func activateServer(_ sender: any IMKTextInput)
  func deactivateServer(_ sender: any IMKTextInput)
  func value(forTag tag: Int, client sender: any IMKTextInput) -> Any?
  func setValue(_ value: Any?, forTag tag: Int, client sender: any IMKTextInput)
  func modes(_ sender: any IMKTextInput) -> [AnyHashable: Any]?
  func recognizedEvents(_ sender: any IMKTextInput) -> UInt
  func showPreferences(_ sender: (any IMKTextInput)?)

  // -- IMKInputController surface --

  func updateComposition()
  func cancelComposition()
  @objc(compositionAttributesAtRange:)
  func compositionAttributes(at range: NSRange) -> NSMutableDictionary
  func selectionRange() -> NSRange
  func replacementRange() -> NSRange
  @objc(markForStyle:atRange:)
  func mark(forStyle style: Int, at range: NSRange) -> [AnyHashable: Any]
  @objc(doCommandBySelector:commandDictionary:)
  func doCommand(by aSelector: Selector, command infoDictionary: [AnyHashable: Any])
  func hidePalettes()
  func menu() -> NSMenu?
  func delegate() -> Any?
  func setDelegate(_ newDelegate: Any?)
  func server() -> IMKServer
  func client() -> (any IMKTextInput)?

  @available(macOS 10.7, *)
  func inputControllerWillClose()

  func annotationSelected(_ annotationString: NSAttributedString?, forCandidate candidateString: NSAttributedString?)
  func candidateSelectionChanged(_ candidateString: NSAttributedString?)
  func candidateSelected(_ candidateString: NSAttributedString?)

  // -- IMKMouseHandling surface --

  func mouseDown(
    onCharacterIndex index: UInt,
    coordinate point: NSPoint,
    withModifier flags: UInt,
    continueTracking keepTracking: UnsafeMutablePointer<ObjCBool>,
    client sender: any IMKTextInput
  ) -> Bool
  func mouseUp(
    onCharacterIndex index: UInt,
    coordinate point: NSPoint,
    withModifier flags: UInt,
    client sender: any IMKTextInput
  ) -> Bool
  func mouseMoved(
    onCharacterIndex index: UInt,
    coordinate point: NSPoint,
    withModifier flags: UInt,
    client sender: any IMKTextInput
  ) -> Bool

  // -- IMKServerInput surface (informal protocol) --

  func inputText(_ string: String, key keyCode: Int, modifiers flags: UInt, client sender: any IMKTextInput) -> Bool
  func inputText(_ string: String, client sender: any IMKTextInput) -> Bool
  @objc(handleEvent:client:)
  func handle(_ event: NSEvent?, client sender: any IMKTextInput) -> Bool
  @objc(didCommandBySelector:client:)
  func didCommand(by aSelector: Selector, client sender: any IMKTextInput) -> Bool
  func composedString(_ sender: any IMKTextInput) -> Any?
  func originalString(_ sender: any IMKTextInput) -> NSAttributedString?
  func commitComposition(_ sender: any IMKTextInput)
  func candidates(_ sender: any IMKTextInput) -> [Any]?
}
