// (c) 2026 and onwards The vChewing Project (MIT License).
// ====================
// This code is released under the MIT license (SPDX-License-Identifier: MIT)

#import "include/IMKControllerLifetimeTracker.h"
#import <objc/runtime.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Dealloc Sentinel

/// A minimal NSObject whose sole purpose is to call a cleanup block on
/// `-dealloc`.  Attached to tracked controllers via `objc_setAssociatedObject`
/// with `OBJC_ASSOCIATION_RETAIN` so that sentinel lifetime is tied to the
/// controller.
@interface _IMKSentinel : NSObject
@property (nonatomic, copy) void (^onDealloc)(void);
@end

@implementation _IMKSentinel
- (void)dealloc {
    if (_onDealloc) _onDealloc();
    [_onDealloc release];
    [super dealloc];
}
@end

#pragma mark - Tracker Implementation

/// Thread-safe storage for tracked controller metadata.
@interface _IMKTrackedEntry : NSObject
@property (nonatomic, assign) uintptr_t addr;
@property (nonatomic, assign) uint64_t generation;
@end

@implementation _IMKTrackedEntry
@end

@interface IMKControllerLifetimeTracker () {
    NSMutableDictionary<NSNumber *, _IMKTrackedEntry *> *_registry; // keyed by @(addr)
    uint64_t _generationCounter;
    id _lock; // NSObject lock for @synchronized
}
@end

@implementation IMKControllerLifetimeTracker

// MARK: - Singleton

+ (instancetype)shared {
    static IMKControllerLifetimeTracker *shared = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _registry = [[NSMutableDictionary alloc] init];
        _lock = [[NSObject alloc] init];
        _generationCounter = 0;
    }
    return self;
}

- (void)dealloc {
    [_lock release];
    [_registry release];
    [super dealloc];
}

// MARK: - Tracking

static char kIMKSwiftTrackerSentinelKey;

- (void)trackController:(id)controller {
    uintptr_t addr = (uintptr_t)controller;
    @synchronized (_lock) {
        if (_registry[@(addr)]) return; // already tracked
    }

    // Create and store the entry.
    _IMKTrackedEntry *entry = [[_IMKTrackedEntry alloc] init];
    entry.addr = addr;
    @synchronized (_lock) {
        entry.generation = ++_generationCounter;
    }

    @synchronized (_lock) {
        _registry[@(addr)] = entry;
    }
    [entry release];

    // Attach a dealloc sentinel so this address is auto-untracked.
    // The tracker is a singleton that outlives all controllers, so
    // __unsafe_unretained is safe here.
    __unsafe_unretained IMKControllerLifetimeTracker *tracker = self;
    _IMKSentinel *sentinel = [[_IMKSentinel alloc] init];
    sentinel.onDealloc = ^{
        [tracker untrackAddress:addr];
    };
    objc_setAssociatedObject(
        controller,
        &kIMKSwiftTrackerSentinelKey,
        sentinel,
        OBJC_ASSOCIATION_RETAIN_NONATOMIC
    );
    [sentinel release];
}

- (void)untrackAddress:(uintptr_t)addr {
    @synchronized (_lock) {
        [_registry removeObjectForKey:@(addr)];
    }
}

// MARK: - Queries

- (BOOL)isAddressAlive:(uintptr_t)addr {
    @synchronized (_lock) {
        return _registry[@(addr)] != nil;
    }
}

- (uint64_t)generationForAddress:(uintptr_t)addr {
    @synchronized (_lock) {
        _IMKTrackedEntry *entry = _registry[@(addr)];
        return entry ? entry.generation : 0;
    }
}

- (uint64_t)currentGeneration {
    @synchronized (_lock) {
        return _generationCounter;
    }
}

- (NSUInteger)trackedControllerCount {
    @synchronized (_lock) {
        return _registry.count;
    }
}

@end

NS_ASSUME_NONNULL_END
