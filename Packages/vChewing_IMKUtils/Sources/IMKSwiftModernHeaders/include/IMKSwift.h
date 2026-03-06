// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

/// @file IMKSwift.h
/// @brief IMKSwift — Modernized InputMethodKit overlay for Swift 6 concurrency.
///
/// This header re-declares the InputMethodKit surface with:
///  - `@MainActor` isolation on every API.
///  - Explicit nullability annotations (`_Nullable` / `_Nonnull`).
///  - Concrete ObjC types in lieu of bare `id` where the SDK intends a specific
///    type (`NSString`, `NSAttributedString`, `NSDictionary`, `NSArray`, `NSEvent` …).
///
/// All enumerations, typedefs, extern constants, and protocols from
/// InputMethodKit and Carbon/HIToolbox are re-exported transitively through
/// the `#import <InputMethodKit/InputMethodKit.h>` below.
///
/// Downstream Swift modules should `import IMKSwift` instead of
/// `import InputMethodKit` to pick up these refinements.

#import <Carbon/Carbon.h>
#import <Cocoa/Cocoa.h>
#import <Foundation/Foundation.h>
#import <InputMethodKit/InputMethodKit.h>

// clang-format off

// ==========================================================================
// MARK: - @MainActor Scope for All Declarations Below
// ==========================================================================
//
// The pragma pushes @MainActor onto every ObjC method declared within the
// scope.  Enums, typedefs, and extern constants from the SDK imports above
// are unaffected.

#pragma clang attribute push(                                                  \
    __attribute__((swift_attr("@MainActor"))),                                 \
    apply_to = any(objc_method, objc_property))

// ==========================================================================
#pragma mark - IMKCandidates
// ==========================================================================

@class IMKServer;

/// An overlay category on `IMKCandidates` that re-exposes the candidate-window
/// API surface with `@MainActor` isolation and explicit nullability annotations.
///
/// `IMKCandidates` manages the system-provided **candidate window** (選字窗) that
/// an input method uses to present a list of character or word candidates to the
/// user.  The candidate window can be displayed as a vertical list, a horizontal
/// list, or in a grid layout, depending on the chosen `IMKCandidatePanelType`.
///
/// ### Typical lifecycle
/// 1. Create an `IMKCandidates` instance with ``initWithServer:panelType:`` (or its
///    `styleType:` variant).
/// 2. When the input method has candidates to show, call ``updateCandidates``
///    (which triggers a callback to the input controller's `candidates:` method),
///    then ``show:`` with a location hint.
/// 3. As the user navigates, the framework calls back into the controller via
///    ``candidateSelectionChanged:`` and ``candidateSelected:``.
/// 4. Call ``hide`` when the candidate window should disappear.
///
/// ### Threading
/// All methods in this category are isolated to `@MainActor` by the surrounding
/// `#pragma clang attribute push`.  Call them only from the main thread (or from
/// a Swift `@MainActor`-isolated context).
@interface IMKCandidates (IMKSwift)

// MARK: Initializers

/// Unavailable default initializer.
///
/// Use ``initWithServer:panelType:`` or ``initWithServer:panelType:styleType:``
/// instead.  This bare `init` is marked unavailable so that Swift callers are
/// directed to the designated initializers that require an `IMKServer`.
- (nonnull instancetype)init __attribute__((unavailable("Please use those constructors intentionally exposed to Swift.")));

/// Creates a candidate window associated with the given `IMKServer`.
///
/// The `panelType` determines the visual layout of the candidate list.
/// Possible values include:
/// - `kIMKSingleColumnScrollingCandidatePanel` — a vertical list with scroll.
/// - `kIMKSingleRowSteppingCandidatePanel`    — a horizontal row that pages.
/// - `kIMKScrollingGridCandidatePanel`         — a grid of candidates.
///
/// @param server    The `IMKServer` that owns this input method.
/// @param panelType The display style for the candidate panel.
/// @return A newly initialized candidate window.
- (nonnull instancetype)initWithServer:(nonnull IMKServer *)server
                             panelType:(IMKCandidatePanelType)panelType;

/// Creates a candidate window with an explicit style type.
///
/// In addition to the panel layout, `style` selects between the main candidate
/// window and an annotation-style sub-window.
///
/// @param server    The `IMKServer` that owns this input method.
/// @param panelType The panel layout type.
/// @param style     The window style (`kIMKMain` or `kIMKAnnotation`).
/// @return A newly initialized candidate window.
- (nonnull instancetype)initWithServer:(nonnull IMKServer *)server
                             panelType:(IMKCandidatePanelType)panelType
                             styleType:(IMKStyleType)style;

// MARK: Panel Configuration

/// Returns the current panel type of this candidate window.
///
/// @return The `IMKCandidatePanelType` that determines how candidates are laid out.
- (IMKCandidatePanelType)panelType;

/// Changes the panel type of this candidate window.
///
/// Switching the panel type at runtime causes the window to rebuild its layout
/// the next time ``updateCandidates`` or ``show:`` is called.
///
/// @param panelType The new panel layout type.
- (void)setPanelType:(IMKCandidatePanelType)panelType;

// MARK: Visibility

/// Shows the candidate window near the current insertion point.
///
/// The `locationHint` suggests where the window should appear relative to the
/// text being composed:
/// - `kIMKLocateCandidatesAboveHint`       — above the insertion point.
/// - `kIMKLocateCandidatesBelowHint`       — below the insertion point.
/// - `kIMKLocateCandidatesLeftHint`         — to the left.
/// - `kIMKLocateCandidatesRightHint`        — to the right.
///
/// The framework may adjust the actual position to keep the window on-screen.
///
/// @param locationHint A hint describing where to position the candidate window.
- (void)show:(IMKCandidatesLocationHint)locationHint;

/// Hides the candidate window.
///
/// After calling this method the window is no longer visible, but the
/// `IMKCandidates` object remains valid and can be shown again later.
- (void)hide;

/// Returns whether the candidate window is currently visible.
///
/// @return `YES` if the candidate window is on-screen; `NO` otherwise.
- (BOOL)isVisible;

// MARK: Candidate Data

/// Asks the current input controller to supply a fresh candidate list.
///
/// When this method is called, the framework invokes the input controller's
/// `candidates:` method (part of the `IMKServerInput` informal protocol).  The
/// returned array is used to populate the candidate window.
///
/// Call this method whenever the underlying candidate data changes — for
/// example, after the user types an additional character narrowing down the
/// candidate set.
- (void)updateCandidates;

/// Displays an annotation string for the currently highlighted candidate.
///
/// Annotations are typically used to show additional information about a
/// candidate — for example, the reading (pronunciation) or an explanatory note.
///
/// @param annotationString The attributed string to display as an annotation,
///                         or `nil` to hide any existing annotation.
- (void)showAnnotation:(nullable NSAttributedString *)annotationString;

/// Displays a sub-list of candidates, using a separate delegate to supply data.
///
/// This is useful for presenting a secondary disambiguation list (e.g., when
/// multiple characters map to the same reading).
///
/// @param candidates      The array of candidates to display in the sub-list.
/// @param delegate        The delegate object that manages the sub-list interaction.
///                        Must respond to the `IMKServerInput` informal protocol's
///                        candidate-related methods.
- (void)showSublist:(nonnull NSArray *)candidates
    subListDelegate:(nonnull id)delegate;

/// Returns the screen-coordinate frame of the candidate window.
///
/// If the window is not visible, the returned rectangle may be `NSZeroRect`.
///
/// @return The frame rectangle of the candidate window in screen coordinates.
- (NSRect)candidateFrame;

// MARK: Appearance

/// Sets the key codes used to select individual candidates from the list.
///
/// Each `NSNumber` in the array represents a virtual key code.  The number
/// of keys determines how many candidates are displayed per page.
///
/// @param keyCodes An array of `NSNumber` objects containing virtual key codes,
///                 typically corresponding to digits `1`–`9` or a similar range.
- (void)setSelectionKeys:(nonnull NSArray<NSNumber *> *)keyCodes;

/// Returns the current selection key codes.
///
/// @return An array of `NSNumber` objects containing the virtual key codes.
- (nonnull NSArray<NSNumber *> *)selectionKeys;

/// Sets the keyboard layout used to interpret selection key events.
///
/// Supply a `TISInputSourceRef` for the keyboard layout that should be used to
/// map selection key events to their corresponding key codes.
///
/// @param layout A `TISInputSourceRef` representing the desired keyboard layout.
- (void)setSelectionKeysKeylayout:(nonnull TISInputSourceRef)layout;

/// Returns the keyboard layout used for selection key interpretation.
///
/// @return The `TISInputSourceRef` currently used for selection key mapping.
- (nonnull TISInputSourceRef)selectionKeysKeylayout;

/// Sets visual attributes of the candidate window.
///
/// Supported attribute keys include:
/// - `NSFontAttributeName` — the font used for candidate text.
/// - `NSForegroundColorAttributeName` — the text colour.
/// - `NSBackgroundColorAttributeName` — the window background colour.
///
/// @param attributes A dictionary mapping `NSAttributedString` attribute keys
///                   to their values.
- (void)setAttributes:(nonnull NSDictionary<NSString *, id> *)attributes;

/// Returns the current visual attributes of the candidate window.
///
/// @return A dictionary of the current attributes.
- (nonnull NSDictionary<NSString *, id> *)attributes;

// MARK: Dismissal

/// Controls whether the candidate window hides automatically when the
/// user selects a candidate.
///
/// When set to `YES` (the default), the window dismisses itself after a
/// selection.  Set to `NO` if you need the window to remain visible so the
/// user can make additional selections.
///
/// @param flag `YES` to dismiss automatically; `NO` to keep the window visible.
- (void)setDismissesAutomatically:(BOOL)flag;

/// Returns whether the candidate window dismisses automatically on selection.
///
/// @return `YES` if automatic dismissal is enabled, `NO` otherwise.
- (BOOL)dismissesAutomatically;

// MARK: Selection & Identification (10.7+)

/// Returns the identifier of the currently selected (highlighted) candidate.
///
/// @return The integer identifier of the selected candidate, or `NSNotFound`
///         if no candidate is selected.
- (NSInteger)selectedCandidate API_AVAILABLE(macosx(10.07));

/// Sets the top-left corner of the candidate window's frame.
///
/// Use this to position the candidate window at a specific screen coordinate.
/// This is particularly useful when the default placement from ``show:`` is
/// not appropriate.
///
/// @param point The desired top-left corner in screen coordinates.
- (void)setCandidateFrameTopLeft:(NSPoint)point API_AVAILABLE(macosx(10.07));

/// Shows the child candidate window.
///
/// A child window is a secondary candidate panel attached to a specific
/// candidate in the parent window via ``attachChild:toCandidate:type:``.
- (void)showChild API_AVAILABLE(macosx(10.07));

/// Hides the child candidate window.
- (void)hideChild API_AVAILABLE(macosx(10.07));

/// Attaches a child candidate window to a specific candidate in this window.
///
/// Use this to build hierarchical candidate displays (e.g., showing variant
/// forms when a candidate is highlighted).
///
/// @param child               The child `IMKCandidates` instance to attach.
/// @param candidateIdentifier The identifier of the parent candidate to which
///                            the child should be attached.
/// @param theType             The visual style of the child window.
- (void)attachChild:(nonnull IMKCandidates *)child
        toCandidate:(NSInteger)candidateIdentifier
               type:(IMKStyleType)theType API_AVAILABLE(macosx(10.07));

/// Detaches and removes the child window from the specified candidate.
///
/// @param candidateIdentifier The identifier of the candidate whose child
///                            window should be detached.
- (void)detachChild:(NSInteger)candidateIdentifier API_AVAILABLE(macosx(10.07));

/// Directly sets the array of candidate data to display.
///
/// Unlike ``updateCandidates`` (which asks the input controller for data), this
/// method lets you supply the candidate array directly.  Each element can be an
/// `NSString` or an `NSAttributedString`.
///
/// @param candidatesArray An array of candidate objects to display.
- (void)setCandidateData:(nonnull NSArray *)candidatesArray
    API_AVAILABLE(macosx(10.07));

/// Selects the candidate with the given identifier.
///
/// @param candidateIdentifier The identifier of the candidate to select.
/// @return `YES` if the candidate was found and selected; `NO` otherwise.
- (BOOL)selectCandidateWithIdentifier:(NSInteger)candidateIdentifier
    API_AVAILABLE(macosx(10.07));

/// Selects and highlights the candidate at the given identifier.
///
/// This method differs from ``selectCandidateWithIdentifier:`` in being a
/// `void` variant.  It triggers the selection UI without returning success status.
///
/// @param candidateIdentifier The identifier of the candidate to select.
- (void)selectCandidate:(NSInteger)candidateIdentifier;

/// Shows candidates that were previously set via ``setCandidateData:``.
///
/// After populating the candidate window with ``setCandidateData:``, call this
/// method to make the window visible without going through ``updateCandidates``.
- (void)showCandidates API_AVAILABLE(macosx(10.07));

/// Returns the unique identifier for a given candidate string.
///
/// @param candidateString A candidate string (typically an `NSString` or
///                        `NSAttributedString`) whose identifier is desired.
/// @return The integer identifier associated with the candidate string.
- (NSInteger)candidateStringIdentifier:(nonnull id)candidateString
    API_AVAILABLE(macosx(10.07));

/// Returns the currently selected candidate as an attributed string.
///
/// @return The selected candidate as an `NSAttributedString`, or `nil` if
///         nothing is selected.
- (nullable NSAttributedString *)selectedCandidateString
    API_AVAILABLE(macosx(10.07));

/// Returns the candidate identifier at the given visual line number.
///
/// @param lineNumber The zero-based line number in the candidate panel.
/// @return The identifier of the candidate displayed at that line.
- (NSInteger)candidateIdentifierAtLineNumber:(NSInteger)lineNumber
    API_AVAILABLE(macosx(10.07));

/// Returns the visual line number for a candidate with the given identifier.
///
/// @param candidateIdentifier The identifier of the candidate.
/// @return The zero-based line number at which the candidate is displayed.
- (NSInteger)lineNumberForCandidateWithIdentifier:(NSInteger)candidateIdentifier
    API_AVAILABLE(macosx(10.07));

/// Clears the current selection in the candidate window.
///
/// After calling this method, no candidate is highlighted.
- (void)clearSelection API_AVAILABLE(macosx(10.07));

// MARK: Window Level & Font (10.14+, Force-Exposed)

/// Returns the window level of the candidate panel.
///
/// The window level determines the candidate window's z-ordering relative to
/// other windows.  Typical values are `CGWindowLevelKey` constants such as
/// `kCGPopUpMenuWindowLevelKey`.
///
/// > Note: This API was force-exposed starting macOS 10.14. It may have existed
/// > in earlier SDKs as a private/undocumented method.
///
/// @return The current window level as an unsigned 64-bit integer.
- (unsigned long long)windowLevel API_AVAILABLE(macosx(10.14));

/// Sets the window level of the candidate panel.
///
/// Raise the window level if the candidate window needs to appear above other
/// floating panels or full-screen windows.
///
/// @param level The desired window level.
- (void)setWindowLevel:(unsigned long long)level API_AVAILABLE(macosx(10.14));

/// Sets the font size used in the candidate window.
///
/// This adjusts the point size of the font used to render candidate text.
///
/// @param fontSize The desired font size in points.
- (void)setFontSize:(double)fontSize API_AVAILABLE(macosx(10.14));

@end

// ==========================================================================
#pragma mark - IMKServer
// ==========================================================================

@class IMKInputController;
@protocol IMKServerProxy;

/// An overlay category on `IMKServer` that re-exposes the server API with
/// `@MainActor` isolation and explicit nullability annotations.
///
/// `IMKServer` is the central object in an input method.  It sets up the
/// Mach connection between the input method process and the system's Text
/// Input framework, creates `IMKInputController` instances for each client
/// application, and routes events to the appropriate controller.
///
/// ### Typical usage
/// ```swift
/// let server = IMKServer(name: "MyIM_Connection", bundleIdentifier: Bundle.main.bundleIdentifier!)
/// ```
///
/// The `name` must match the `InputMethodConnectionName` key in the input
/// method's `Info.plist`.
@interface IMKServer (IMKSwift)

/// Unavailable default initializer.
///
/// Use ``initWithName:bundleIdentifier:`` or
/// ``initWithName:controllerClass:delegateClass:`` instead.
- (nonnull instancetype)init __attribute__((unavailable("Please use those constructors intentionally exposed to Swift.")));

/// Creates a server that connects using the given name and bundle identifier.
///
/// This is the preferred initializer when the input controller and delegate
/// classes are specified in `Info.plist` (via `InputMethodServerControllerClass`
/// and `InputMethodServerDelegateClass`).
///
/// @param name             The connection name.  Must match the
///                         `InputMethodConnectionName` key in `Info.plist`.
/// @param bundleIdentifier The bundle identifier of the input method.
/// @return A newly initialized server.
- (nonnull instancetype)initWithName:(nonnull NSString *)name
                    bundleIdentifier:(nonnull NSString *)bundleIdentifier;

/// Creates a server with explicit controller and delegate classes.
///
/// Use this initializer when you want to provide the controller and delegate
/// classes programmatically rather than via `Info.plist`.  The
/// `controllerClassID` must be a subclass of `IMKInputController`.
///
/// @param name              The connection name (must match `Info.plist`).
/// @param controllerClassID The class to use for input controllers.
/// @param delegateClassID   The class to use as the delegate, or `nil` if
///                          the controller handles all delegate duties.
/// @return A newly initialized server.
- (nonnull instancetype)initWithName:(nonnull NSString *)name
                     controllerClass:(nonnull Class)controllerClassID
                       delegateClass:(nullable Class)delegateClassID;

/// Returns the main bundle of the input method.
///
/// This is the `NSBundle` associated with the input method's `.app` wrapper.
///
/// @return The input method's main bundle.
- (nonnull NSBundle *)bundle;

/// Returns whether any palette (floating tool window) will terminate.
///
/// When the input method is being deactivated, this can be used to determine if
/// a palette should close itself.
///
/// @return `YES` if a palette will terminate; `NO` otherwise.
- (BOOL)paletteWillTerminate API_AVAILABLE(macosx(10.07));

/// Returns whether the most recent key event was a dead key.
///
/// A dead key is a key press that does not immediately produce a character but
/// modifies the next key press (e.g., accent marks on European keyboards).
///
/// @return `YES` if the last key event was a dead key; `NO` otherwise.
- (BOOL)lastKeyEventWasDeadKey API_AVAILABLE(macosx(10.07));

@end

// ==========================================================================
#pragma mark - IMKInputSessionController
// ==========================================================================

/// A concrete subclass of `IMKInputController` that consolidates the
/// `IMKStateSetting`, `IMKMouseHandling`, and `IMKServerInput` (informal)
/// protocol surfaces into a single class with `@MainActor` isolation.
///
/// ### Purpose
/// Apple's `IMKInputController` is designed to be subclassed, and it
/// informally implements several protocols.  However, the original SDK
/// headers use bare `id` types, lack nullability annotations, and do not
/// declare concurrency isolation.
///
/// `IMKInputSessionController` re-declares every method with:
/// - `@MainActor` isolation (via the surrounding `#pragma clang attribute`).
/// - Explicit `_Nonnull` / `_Nullable` annotations.
/// - Concrete Objective-C types (`NSString *`, `NSEvent *`, etc.).
///
/// **Downstream input methods should subclass `IMKInputSessionController`
/// rather than `IMKInputController`** to benefit from these refinements.
///
/// ### Conformance
/// In the companion Swift module, `IMKInputSessionController` is extended to
/// conform to `IMKInputSessionControllerProtocol`, a Swift-native `@MainActor`
/// protocol that mirrors its full API surface.
@interface IMKInputSessionController : IMKInputController

// MARK: Initializer

/// Unavailable default initializer.
///
/// Use ``initWithServer:delegate:client:`` instead.
- (nonnull instancetype)init __attribute__((unavailable("Please use those constructors intentionally exposed to Swift.")));

/// Designated initializer.
///
/// The framework calls this method automatically when a new input session is
/// created.  You typically do not call it yourself — `IMKServer` instantiates
/// controllers on your behalf.
///
/// - warning: `client()` on macOS 10.9 ~ 10.12 returns `nil` until this
/// constructor finishes, even though `super.init` has already been called.
/// It is recommended that you use the client object passed as a parameter instead.
///
/// @param server      The `IMKServer` that owns this controller.
/// @param delegate    An optional delegate object.  If `nil`, the controller
///                    itself handles all delegate duties.
/// @param inputClient The text-input client for this session.  The client
///                    conforms to `IMKTextInput` and represents the text view
///                    in the client application. If you are subclassing this
///                    class and you want to access the client during this
///                    construction process, please use this parameter prior to
///                    using `client()`. See `warning` section in the documentation.
/// @return A newly initialized input session controller.
- (nonnull instancetype)initWithServer:(nonnull IMKServer *)server
                              delegate:(nullable id)delegate
                                client:(nonnull id<IMKTextInput>)inputClient;

// MARK: Composition

/// Notifies the text-input client that the composition (preedit) has changed.
///
/// Call this method after modifying the internal composition buffer so that the
/// client application can update its inline display.  Internally, this triggers
/// a call to ``composedString:`` to obtain the current composition text.
- (void)updateComposition;

/// Cancels the current composition and clears the inline text in the client.
///
/// Call this when the user presses Escape or an equivalent key that should
/// discard the in-progress composition without committing any text.
- (void)cancelComposition;

/// Returns a mutable dictionary of composition attributes for the given range.
///
/// The returned dictionary typically contains `NSAttributedString` attribute
/// keys (e.g., `NSUnderlineStyleAttributeName`) that define how the composed
/// text is styled within the client's text view.
///
/// Override this method to customise the appearance of the inline composition.
///
/// @param range The range (within the composition string) for which to return
///              attributes.
/// @return A mutable dictionary of text attributes.
- (nonnull NSMutableDictionary *)compositionAttributesAtRange:(NSRange)range;

/// Returns the range of the current selection within the composition.
///
/// If there is no selection, the location indicates the cursor position and the
/// length is zero.
///
/// @return The selection range within the composed string.
- (NSRange)selectionRange;

/// Returns the range that should be replaced when committing text.
///
/// Return `{NSNotFound, 0}` to indicate that the framework should use its
/// default replacement behaviour.
///
/// @return The replacement range in document coordinates.
- (NSRange)replacementRange;

/// Returns a dictionary describing how to render a marked-text style.
///
/// The system calls this method to determine visual feedback for different
/// composition–phase styles (e.g., raw input, converted text, selected
/// converted text).
///
/// @param style The style constant (e.g., `kTSMHiliteRawText`,
///              `kTSMHiliteConvertedText`, `kTSMHiliteSelectedConvertedText`).
/// @param range The character range to which the style applies.
/// @return A dictionary containing mark/underline attributes for the given
///         style and range.
- (nonnull NSDictionary *)markForStyle:(NSInteger)style atRange:(NSRange)range;

// MARK: Commands & Palettes

/// Performs a command identified by a selector, with an accompanying
/// information dictionary.
///
/// This is a richer variant of `-doCommandBySelector:` that passes along
/// extra context (such as the originating menu item or key binding).
///
/// @param aSelector       The selector identifying the command.
/// @param infoDictionary  A dictionary of supplemental information about the
///                        command.
- (void)doCommandBySelector:(nonnull SEL)aSelector
         commandDictionary:(nonnull NSDictionary *)infoDictionary;

/// Hides all palette (floating tool) windows owned by this input method.
///
/// The framework may call this when the input method loses focus or the active
/// application changes.
- (void)hidePalettes;

/// Returns a context menu for the input method.
///
/// Override this method to provide a custom `NSMenu` that is shown when the
/// user right-clicks in the input area or uses the input-method menu-bar icon.
///
/// @return An `NSMenu` to display, or `nil` to show no menu.
- (nullable NSMenu *)menu;

// MARK: Delegate & Server

/// Returns the delegate of this input controller.
///
/// @return The delegate object, or `nil` if no delegate is set.
- (nullable id)delegate;

/// Sets the delegate of this input controller.
///
/// @param newDelegate The new delegate object, or `nil` to remove the delegate.
- (void)setDelegate:(nullable id)newDelegate;

/// Returns the `IMKServer` that owns this input controller.
///
/// @return The owning `IMKServer`.
- (nonnull IMKServer *)server;

/// Returns the text-input client for this input session.
///
/// The client conforms to `IMKTextInput` and `IMKUnicodeTextInput`, and
/// represents the text view in the active client application.
///
/// @return The current text-input client, or `nil` if none is connected.
- (nullable id<IMKTextInput>)client;

// MARK: Lifecycle (10.7+)

/// Called when the input controller is about to be deallocated.
///
/// Override this method to perform cleanup — release resources, unregister
/// observers, close auxiliary windows, etc.  Always call `super` in your
/// override.
- (void)inputControllerWillClose API_AVAILABLE(macosx(10.07));

// MARK: Candidate Callbacks

/// Called when the user selects an annotation attached to a candidate.
///
/// Override this to react when the user clicks or otherwise selects an
/// annotation string displayed alongside a candidate.
///
/// @param annotationString The annotation that was selected, or `nil`.
/// @param candidateString  The candidate to which the annotation belongs,
///                         or `nil`.
- (void)annotationSelected:(nullable NSAttributedString *)annotationString
              forCandidate:(nullable NSAttributedString *)candidateString;

/// Called when the highlighted candidate changes.
///
/// Override this to update auxiliary UI (e.g., a preview pane or annotation
/// window) in response to the user navigating through the candidate list.
///
/// @param candidateString The newly highlighted candidate, or `nil` if the
///                        selection was cleared.
- (void)candidateSelectionChanged:(nullable NSAttributedString *)candidateString;

/// Called when the user definitively selects (commits) a candidate.
///
/// Override this to commit the selected candidate to the client's text view
/// or perform any post-selection processing.
///
/// @param candidateString The selected candidate, or `nil`.
- (void)candidateSelected:(nullable NSAttributedString *)candidateString;

// MARK: IMKStateSetting

/// Called when the input method is activated for a text-input client.
///
/// This method is invoked each time the input method gains focus (e.g., the
/// user switches to this input method or the client application's window
/// becomes key).  Use it to restore state, update mode indicators, or show
/// palette windows.
///
/// @param sender The text-input client that activated this input method.
- (void)activateServer:(nonnull id<IMKTextInput>)sender;

/// Called when the input method is deactivated for a text-input client.
///
/// This method is invoked when the user switches away from this input method
/// or the client application resigns key-window status.  Use it to save state,
/// hide UI, or commit any pending composition.
///
/// @param sender The text-input client being deactivated.
- (void)deactivateServer:(nonnull id<IMKTextInput>)sender;

/// Returns a value associated with a given tag for the specified client.
///
/// Tags are integer identifiers defined by the `IMKStateSetting` protocol
/// (e.g., `kTextServiceInputModePropertyTag`).  The system uses this to query
/// the input method's current configuration.
///
/// @param tag    The tag identifying the requested value.
/// @param sender The text-input client making the request.
/// @return The value associated with the tag, or `nil` if none.
- (nullable id)valueForTag:(long)tag client:(nonnull id<IMKTextInput>)sender;

/// Sets a value for a given tag for the specified client.
///
/// The system calls this method to inform the input method about configuration
/// changes (e.g., the active input mode was changed by the user).
///
/// @param value  The new value, or `nil` to clear.
/// @param tag    The tag identifying the setting.
/// @param sender The text-input client.
- (void)setValue:(nullable id)value forTag:(long)tag client:(nonnull id<IMKTextInput>)sender;

/// Returns the set of input modes supported by this input method.
///
/// The returned dictionary maps a mode identifier (`NSString`) to a
/// human-readable name.  The framework uses this to populate the input-mode
/// submenu in the menu bar.
///
/// @param sender The text-input client requesting available modes.
/// @return A dictionary of mode identifiers to display names, or `nil`.
- (nullable NSDictionary *)modes:(nonnull id<IMKTextInput>)sender;

/// Returns a bitmask of event types that this input method wants to receive.
///
/// By default, input methods receive key-down events.  Override this to also
/// receive mouse events, flagsChanged events, or other `NSEvent` types.
///
/// The return value is a bitmask of `NSEventMask` values (e.g.,
/// `NSEventMaskKeyDown | NSEventMaskFlagsChanged`).
///
/// @param sender The text-input client.
/// @return A bitmask of recognised event types.
- (NSUInteger)recognizedEvents:(nonnull id<IMKTextInput>)sender;

/// Called when the user asks to see the input method's preferences UI.
///
/// Override this to open a preferences window or panel.  The default
/// implementation does nothing.
///
/// @param sender The text-input client, or `nil` if invoked from the menu bar.
- (void)showPreferences:(nullable id<IMKTextInput>)sender;

// MARK: IMKMouseHandling

/// Called when the user presses the mouse button on a character in the
/// composed text.
///
/// @param index        The zero-based character index in the composition that
///                     was clicked.
/// @param point        The click location in screen coordinates.
/// @param flags        Modifier flags at the time of the click
///                     (`NSEventModifierFlags`).
/// @param keepTracking On return, set `*keepTracking` to `YES` to continue
///                     receiving `mouseMovedOnCharacterIndex:…` and
///                     `mouseUpOnCharacterIndex:…` callbacks.
/// @param sender       The text-input client.
/// @return `YES` if the event was handled; `NO` to let the client process it.
- (BOOL)mouseDownOnCharacterIndex:(NSUInteger)index
                       coordinate:(NSPoint)point
                     withModifier:(NSUInteger)flags
                 continueTracking:(nonnull BOOL *)keepTracking
                           client:(nonnull id<IMKTextInput>)sender;

/// Called when the user releases the mouse button on a character in the
/// composed text.
///
/// This callback is only delivered if you set `*keepTracking = YES` in a
/// prior ``mouseDownOnCharacterIndex:coordinate:withModifier:continueTracking:client:``
/// call.
///
/// @param index  The character index under the mouse pointer.
/// @param point  The release location in screen coordinates.
/// @param flags  Modifier flags.
/// @param sender The text-input client.
/// @return `YES` if the event was handled; `NO` otherwise.
- (BOOL)mouseUpOnCharacterIndex:(NSUInteger)index
                     coordinate:(NSPoint)point
                   withModifier:(NSUInteger)flags
                         client:(nonnull id<IMKTextInput>)sender;

/// Called when the mouse moves over a character in the composed text while
/// tracking.
///
/// This callback is only delivered if you set `*keepTracking = YES` in a
/// prior ``mouseDownOnCharacterIndex:coordinate:withModifier:continueTracking:client:``
/// call.
///
/// @param index  The character index under the mouse pointer.
/// @param point  The current mouse location in screen coordinates.
/// @param flags  Modifier flags.
/// @param sender The text-input client.
/// @return `YES` if the event was handled; `NO` otherwise.
- (BOOL)mouseMovedOnCharacterIndex:(NSUInteger)index
                        coordinate:(NSPoint)point
                      withModifier:(NSUInteger)flags
                            client:(nonnull id<IMKTextInput>)sender;

// MARK: IMKServerInput (Informal Protocol)

/// Handles a key event expressed as a text string, key code, and modifier flags.
///
/// This is the most detailed key-handling entry point.  The framework calls it
/// when the user presses a key and passes the Unicode text (if any), the virtual
/// key code, and the modifier-flag bitmask.
///
/// Return `YES` if your input method consumed the event; `NO` to let the
/// client application process it normally.
///
/// @param string  The text generated by the key press (may be empty for
///                non-printable keys).
/// @param keyCode The virtual key code (e.g., `kVK_Return`).
/// @param flags   Modifier flags (`NSEventModifierFlags`).
/// @param sender  The text-input client.
/// @return `YES` if the event was handled; `NO` otherwise.
- (BOOL)inputText:(nonnull NSString *)string
              key:(NSInteger)keyCode
        modifiers:(NSUInteger)flags
           client:(nonnull id<IMKTextInput>)sender;

/// Handles a key event expressed only as a text string.
///
/// A simplified variant of ``inputText:key:modifiers:client:`` that receives
/// only the Unicode string.  The framework calls this when your input method
/// does not implement the full form, or when the key event can be fully
/// described by its text output.
///
/// @param string The text generated by the key press.
/// @param sender The text-input client.
/// @return `YES` if the event was handled; `NO` otherwise.
- (BOOL)inputText:(nonnull NSString *)string client:(nonnull id<IMKTextInput>)sender;

/// Handles a raw `NSEvent`.
///
/// If your input method declares additional event types via
/// ``recognizedEvents:``, those events arrive here.  This is the most general
/// event-handling hook.
///
/// @param event  The event to handle, or `nil` if the event could not be
///               constructed.
/// @param sender The text-input client.
/// @return `YES` if the event was handled; `NO` otherwise.
- (BOOL)handleEvent:(nullable NSEvent *)event client:(nonnull id<IMKTextInput>)sender;

/// Called when a command action (selector) should be performed.
///
/// The framework routes action messages (e.g., `moveLeft:`, `deleteBackward:`)
/// through this method before falling back to the standard responder chain.
///
/// @param aSelector The selector identifying the command.
/// @param sender    The text-input client.
/// @return `YES` if the command was handled; `NO` to let the client handle it.
- (BOOL)didCommandBySelector:(nonnull SEL)aSelector client:(nonnull id<IMKTextInput>)sender;

/// Returns the current composition (inline-edit) string.
///
/// The framework calls this method after ``updateComposition`` to obtain the
/// text that should be displayed inline in the client's text view.  The return
/// value can be an `NSString` or an `NSAttributedString`.
///
/// @param sender The text-input client.
/// @return The current composition string, or `nil` if there is no composition.
- (nullable id)composedString:(nonnull id<IMKTextInput>)sender;

/// Returns the original (pre-conversion) string for the current composition.
///
/// This is used to display the raw input before any conversion has been applied
/// (e.g., the romanized reading of a CJK composition).
///
/// @param sender The text-input client.
/// @return The original input string as an attributed string, or `nil`.
- (nullable NSAttributedString *)originalString:(nonnull id<IMKTextInput>)sender;

/// Commits the current composition to the client's text view.
///
/// Call this (or let the framework call it) to finalize the composition.  After
/// committing, the composition buffer is cleared.
///
/// @param sender The text-input client.
- (void)commitComposition:(nonnull id<IMKTextInput>)sender;

/// Returns the array of candidates for the current composition.
///
/// The `IMKCandidates` object calls this method (via ``updateCandidates``) to
/// populate the candidate window.  Each element should be an `NSString` or
/// `NSAttributedString`.
///
/// @param sender The text-input client.
/// @return An array of candidate objects, or `nil` if there are no candidates.
- (nullable NSArray *)candidates:(nonnull id<IMKTextInput>)sender;

@end

#pragma clang attribute pop

// clang-format on
