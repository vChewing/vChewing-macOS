// (c) 2021 and onwards The vChewing Project (MIT-NTL License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)
// ... with NTL restriction stating that:
// No trademark license is granted to use the trade names, trademarks, service
// marks, or product names of Contributor, except as required to fulfill notice
// requirements defined in MIT License.

import InputMethodKit

// MARK: - IMKInputController + IMKInputControllerProtocol

extension IMKInputController: IMKInputControllerProtocol {}

// MARK: - IMKInputControllerProtocol

public protocol IMKInputControllerProtocol: IMKStateSetting {
  /// Activates the input method.
  func activateServer(_ sender: Any!)

  /// Deactivates the input method.
  func deactivateServer(_ sender: Any!)

  /// Returns an object value whose key is tag. The returned object should be autoreleased.
  func value(forTag tag: Int, client sender: Any!) -> Any!

  /// Sets the tagged value to the object specified by value.
  func setValue(_ value: Any!, forTag tag: Int, client sender: Any!)

  /// This is called to obtain the input method's modes dictionary.
  /// Typically, this is called to build the text input menu. By calling the input method rather than reading the modes from the info.plist, the input method can dynamically modify the modes supported. The returned dictionary should be an autoreleased object.
  func modes(_ sender: Any!) -> [AnyHashable: Any]!

  /// Returns an unsigned integer containing a union of event masks (see NSEvent.h).
  /// A client will check with an input method to see if an event is supported by calling this method. The default implementation returns NSKeyDownMask. If your input method only handles key downs, the InputMethodKit provides default mouse handling.
  /// If there's an active composition area and the user clicks outside of it, the InputMethodKit will send your input method a `commitComposition:` message. This happens only for input methods returning just NSKeyDownMask.
  func recognizedEvents(_ sender: Any!) -> Int

  /// Looks for a nib file containing a windowController class and a preferences utility. If found, the panel is displayed.
  /// To use this method, include a menu item whose action is `showPreferences:` in your input method's menu. The method will be called automatically when the user selects the item in the Text Input Menu.
  /// The default implementation looks for a nib file named `preferences.nib`. If found, a `windowController` class is allocated and the nib is loaded.
  func showPreferences(_ sender: Any!)

  /// Called to inform the controller that the composition has changed.
  /// This method will call the protocol method `composedString:` to obtain the current composition and send it to the client using `setMarkedText:`.
  func updateComposition()

  /// Stops the current composition and replaces marked text with the original text.
  /// Calls the `originalString` method to obtain the original text and sends it to the client via `IMKInputSession`'s `insertText:`.
  func cancelComposition()

  /// Called to obtain a dictionary of text attributes.
  /// The default implementation returns an empty dictionary. You should override this method if your input method wants to provide font or glyph information. The returned object should be an autoreleased object.
  func compositionAttributes(at range: NSRange) -> NSMutableDictionary!

  /// Returns where the selection should be placed inside marked text.
  /// This method is called by `updateComposition:` to obtain the selection range for marked text. The default implementation sets the selection range at the end of the marked text.
  func selectionRange() -> NSRange

  /// Returns the range in the client document that text should replace.
  /// This method is called by `updateComposition` to obtain the range where marked text should be placed. The default implementation returns `NSNotFound`, indicating that the marked text should be placed at the current insertion point.
  /// Input methods wishing to insert marked text somewhere other than the insertion point should override this method.
  func replacementRange() -> NSRange

  /// Returns a dictionary of text attributes that can be used to mark a range of an attributed string that is going to be sent to a client.
  /// This utility function can be called by input methods to mark each range (i.e. clause) of marked text. The `style` parameter should be one of the following values: `kTSMHiliteSelectedRawText`, `kTSMHiliteConvertedText`, or `kTSMHiliteSelectedConvertedText`.
  /// The default implementation calls `compositionAttributesAtRange:` to obtain extra attributes and adds underline and underline color information for the specified style.
  func mark(forStyle style: Int, at range: NSRange) -> [AnyHashable: Any]!

  /// Called to pass commands that are not part of text input.
  /// The default implementation checks if the controller responds to the selector and sends the message `performSelector:withObject:` with the `infoDictionary`.
  func doCommand(by aSelector: Selector!, command infoDictionary: [AnyHashable: Any]!)

  /// Called to inform the input method that any visible UI should be closed.
  func hidePalettes()

  /// Returns a menu of input method specific commands.
  /// This method is called whenever the menu needs to be redrawn, allowing input methods to update the menu to reflect their current state.
  func menu() -> NSMenu!

  /// Returns the input controller's delegate object. The returned object is autoreleased.
  func delegate() -> Any!

  /// Sets the input controller's delegate object.
  func setDelegate(_ newDelegate: Any!)

  /// Returns the server object which is managing this input controller. The returned `IMKServer` is autoreleased.
  func server() -> IMKServer!

  /// Returns this controller's client object, which conforms to the `IMKTextInput` protocol. The returned object is autoreleased.
  func client() -> (any IMKTextInput & NSObjectProtocol)!

  /// Called to notify the input controller that it is about to be closed.
  @available(macOS 10.7, *)
  func inputControllerWillClose()

  /// Called when a user selects an annotation in a candidate window.
  /// When a candidate window is displayed and the user selects an annotation, the selected annotation is sent to the input controller along with the selected candidate string.
  func annotationSelected(_ annotationString: NSAttributedString!, forCandidate candidateString: NSAttributedString!)

  /// Informs the input controller that the current candidate selection has changed.
  /// The `candidateString` is the updated selection, but it's not the final selection yet.
  func candidateSelectionChanged(_ candidateString: NSAttributedString!)

  /// Called when a new candidate has been finally selected.
  /// The `candidateString` is the user's final choice, and the candidate window has been closed by the time this method is called.
  func candidateSelected(_ candidateString: NSAttributedString!)
}
