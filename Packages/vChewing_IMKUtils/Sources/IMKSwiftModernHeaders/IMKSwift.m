// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

/// @file IMKSwift.m
/// @brief Implementation file for `IMKInputSessionController`.
///
/// This file provides the `@implementation` block for `IMKInputSessionController`,
/// which is declared in `IMKSwift.h` as a subclass of `IMKInputController`.
///
/// Because `IMKInputSessionController` re-declares inherited methods from
/// `IMKInputController` (with refined nullability and `@MainActor` annotations),
/// the compiler would normally emit `-Wincomplete-implementation` warnings for
/// each method that lacks an explicit body.  The `#pragma clang diagnostic`
/// block suppresses these warnings — the actual implementations are inherited
/// from `IMKInputController` at runtime via the Objective-C message dispatch.
///
/// **Only** `-activateServer:` and `-deactivateServer:` are implemented here;
/// they invoke the block properties (`onActivateServer` / `onDeactivateServer`)
/// set by the Swift subclass and manage the deferred-dealloc timer.

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
}

// MARK: - Block Properties (MRC)

- (void)setOnActivateServer:(nullable void (^)(uintptr_t, uintptr_t))block {
    if (_onActivateServer != block) {
        [_onActivateServer release];
        _onActivateServer = [block copy];
    }
}

- (nullable void (^)(uintptr_t, uintptr_t))onActivateServer {
    return [[_onActivateServer retain] autorelease];
}

- (void)setOnDeactivateServer:(nullable void (^)(uintptr_t, uintptr_t))block {
    if (_onDeactivateServer != block) {
        [_onDeactivateServer release];
        _onDeactivateServer = [block copy];
    }
}

- (nullable void (^)(uintptr_t, uintptr_t))onDeactivateServer {
    return [[_onDeactivateServer retain] autorelease];
}

- (void)setOnDealloc:(nullable void (^)(uintptr_t))block {
    if (_onDealloc != block) {
        [_onDealloc release];
        _onDealloc = [block copy];
    }
}

- (nullable void (^)(uintptr_t))onDealloc {
    return [[_onDealloc retain] autorelease];
}

// MARK: - Lifecycle

- (void)dealloc {
    if (_onDealloc) _onDealloc((uintptr_t)self);
    [_onDealloc release];
    [_onActivateServer release];
    [_onDeactivateServer release];
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
