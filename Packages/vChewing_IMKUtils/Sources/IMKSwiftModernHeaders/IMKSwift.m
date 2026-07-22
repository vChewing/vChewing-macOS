// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

/// @file IMKSwift.m
/// @brief Implementation file for `IMKInputSessionController`.
///
/// This file provides the `@implementation` block for `IMKInputSessionController`,
/// which is declared in `IMKSwift.h` as a subclass of `IMKInputController`.
///
/// **All** `IMKInputController` overrides are implemented here; each invokes the
/// corresponding block property set by the Swift subclass.  The blocks receive
/// raw memory addresses (`uintptr_t`) instead of object references — no
/// retain/release is performed on the client or the controller itself.
///
/// The `-Wincomplete-implementation` pragma is still needed for the remaining
/// methods that are inherited from `IMKInputController` at runtime without
/// explicit bodies (e.g. `candidates:`, `doCommandBy:`).

#import <Foundation/Foundation.h>
#import <InputMethodKit/InputMethodKit.h>
#import "include/IMKSwift.h"

NS_ASSUME_NONNULL_BEGIN

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"

@implementation IMKInputSessionController {
    void (^_onActivateServer)(uintptr_t, uintptr_t);
    void (^_onDeactivateServer)(uintptr_t, uintptr_t);
    void (^_onDealloc)(uintptr_t);
    void (^_onShowingPreferences)(uintptr_t, uintptr_t);
    void (^_onHidingPallettes)(uintptr_t);
    void (^_onInputControllerWillClose)(uintptr_t);
    NSRange (^_onProvidingSelectionRange)(uintptr_t);
    NSMenu * _Nullable (^_onProvidingIMEMenu)(uintptr_t);
    id _Nullable (^_onProvidingComposedString)(uintptr_t, uintptr_t);
    void (^_onAutoCommittingComposition)(uintptr_t, uintptr_t);
    NSUInteger (^_onProvidingRecognizedEvents)(uintptr_t, uintptr_t);
    BOOL (^_onHandlingGivenNullableEvent)(uintptr_t, uintptr_t, uintptr_t);
    void (^_onSettingObjCValue)(uintptr_t, intptr_t, uintptr_t, uintptr_t);
}

// MARK: - Block Properties (MRC)

#define MRC_BLOCK_PROPERTY(_name, _sig) \
    - (void)set##_name:(nullable _sig)block { \
        if (_##_name != block) { \
            [_##_name release]; \
            _##_name = [block copy]; \
        } \
    } \
    - (nullable _sig)_name { \
        return [[_##_name retain] autorelease]; \
    }

MRC_BLOCK_PROPERTY(onActivateServer, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onDeactivateServer, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onDealloc, void (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onShowingPreferences, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onHidingPallettes, void (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onInputControllerWillClose, void (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingSelectionRange, NSRange (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingIMEMenu, NSMenu * _Nullable (^)(uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingComposedString, id _Nullable (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onAutoCommittingComposition, void (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onProvidingRecognizedEvents, NSUInteger (^)(uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onHandlingGivenNullableEvent, BOOL (^)(uintptr_t, uintptr_t, uintptr_t))
MRC_BLOCK_PROPERTY(onSettingObjCValue, void (^)(uintptr_t, intptr_t, uintptr_t, uintptr_t))

#undef MRC_BLOCK_PROPERTY

// MARK: - Lifecycle

- (void)dealloc {
    if (_onDealloc) _onDealloc((uintptr_t)self);
    [_onDealloc release];
    [_onActivateServer release];
    [_onDeactivateServer release];
    [_onShowingPreferences release];
    [_onHidingPallettes release];
    [_onInputControllerWillClose release];
    [_onProvidingSelectionRange release];
    [_onProvidingIMEMenu release];
    [_onProvidingComposedString release];
    [_onAutoCommittingComposition release];
    [_onProvidingRecognizedEvents release];
    [_onHandlingGivenNullableEvent release];
    [_onSettingObjCValue release];
    [self IMKSwift_cancelDelayedDealloc];
    [super dealloc];
}

// MARK: - IMKInputController Overrides

- (void)activateServer:(id)sender {
    [self IMKSwift_cancelDelayedDealloc];
    if (_onActivateServer) _onActivateServer((uintptr_t)sender, (uintptr_t)self);
}

- (void)deactivateServer:(id)sender {
    if (_onDeactivateServer) _onDeactivateServer((uintptr_t)sender, (uintptr_t)self);
    [self IMKSwift_scheduleDelayedDeallocAfterDelay:3.0];
}

- (void)showPreferences:(nullable id)sender {
    if (_onShowingPreferences) _onShowingPreferences((uintptr_t)sender, (uintptr_t)self);
}

- (void)hidePalettes {
    if (_onHidingPallettes) _onHidingPallettes((uintptr_t)self);
}

- (void)inputControllerWillClose {
    if (_onInputControllerWillClose) _onInputControllerWillClose((uintptr_t)self);
}

- (NSRange)selectionRange {
    if (_onProvidingSelectionRange) return _onProvidingSelectionRange((uintptr_t)self);
    return NSMakeRange(NSNotFound, 0);
}

- (nullable NSMenu *)menu {
    if (_onProvidingIMEMenu) return _onProvidingIMEMenu((uintptr_t)self);
    return [[NSMenu new] autorelease];
}

- (nullable id)composedString:(id)sender {
    if (_onProvidingComposedString) return _onProvidingComposedString((uintptr_t)sender, (uintptr_t)self);
    return nil;
}

- (void)commitComposition:(id)sender {
    if (_onAutoCommittingComposition) _onAutoCommittingComposition((uintptr_t)sender, (uintptr_t)self);
}

- (NSUInteger)recognizedEvents:(id)sender {
    if (_onProvidingRecognizedEvents) return _onProvidingRecognizedEvents((uintptr_t)sender, (uintptr_t)self);
    return 0;
}

- (BOOL)handleEvent:(nullable NSEvent *)event client:(id)sender {
    if (_onHandlingGivenNullableEvent) return _onHandlingGivenNullableEvent((uintptr_t)event, (uintptr_t)sender, (uintptr_t)self);
    return NO;
}

- (void)setValue:(nullable id)value forTag:(NSInteger)tag client:(id)sender {
    if (_onSettingObjCValue) _onSettingObjCValue((uintptr_t)value, (intptr_t)tag, (uintptr_t)sender, (uintptr_t)self);
}

// MARK: - Private: Deferred Dealloc

/// Schedules a delayed dealloc of this controller after `delay` seconds.
/// The `performSelector:withObject:afterDelay:` API retains `self` for the
/// duration of the delay.  When the timer fires, the timer releases its retain.
/// If no other objects hold a reference, `-dealloc` is triggered by the system.
- (void)IMKSwift_scheduleDelayedDeallocAfterDelay:(NSTimeInterval)delay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(IMKSwift_delayedDealloc)
                                               object:nil];
    [self performSelector:@selector(IMKSwift_delayedDealloc)
               withObject:nil
               afterDelay:delay];
}

/// Cancels any pending delayed dealloc.
- (void)IMKSwift_cancelDelayedDealloc {
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(IMKSwift_delayedDealloc)
                                               object:nil];
}

/// Intentionally empty — serves only as the target for the delayed
/// `-performSelector:withObject:afterDelay:` timer.
///
/// The timer retains `self` for the duration of the delay; when it fires
/// and this method returns, the timer releases its retain.  If no other
/// references exist at that point, `-dealloc` is triggered by the system.
/// The method body itself does not need to do anything.
- (void)IMKSwift_delayedDealloc {}

@end

#pragma clang diagnostic pop

NS_ASSUME_NONNULL_END
