// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Tracks IMKInputSessionController instances by memory address.
///
/// Each controller receives a monotonically increasing generation number
/// at registration time, used by the parity-based double-buffered session
/// pool.  A dealloc sentinel object is attached via `objc_setAssociatedObject`
/// so that the tracker automatically unregisters entries when a controller
/// is deallocated, even if `-dealloc` does not fire (e.g. during forced
/// teardown or NSZombie instrumentation).
///
/// All query methods accept raw `uintptr_t` addresses — callers must verify
/// the address is alive via `-isAddressAlive:` before calling
/// `Unmanaged.takeUnretainedValue()` on it.
@interface IMKControllerLifetimeTracker : NSObject

/// The singleton tracker instance.
+ (instancetype)shared;

/// Register a controller for tracking.  Assigns a generation number and
/// attaches a dealloc sentinel so that `-untrackAddress:` is called
/// automatically on deallocation.
- (void)trackController:(id)controller;

/// Manually unregister an address (called by the dealloc sentinel).
- (void)untrackAddress:(uintptr_t)addr;

/// Returns `YES` if the given controller address is currently tracked
/// (i.e. the controller has not been deallocated).
- (BOOL)isAddressAlive:(uintptr_t)addr;

/// Returns the generation number assigned when the controller at `addr`
/// was first tracked.  Returns `0` if the address is unknown.
- (uint64_t)generationForAddress:(uintptr_t)addr;

/// Returns the current generation counter value (monotonically increasing,
/// incremented once per controller tracked).
- (uint64_t)currentGeneration;

/// The number of currently-tracked controllers.
@property (nonatomic, readonly) NSUInteger trackedControllerCount;

@end

NS_ASSUME_NONNULL_END
